--!strict
-- Player combat on the client (docs/enemies_npcs_pets_brief.txt Part A): inputs with the aim, the swing and the
-- feedback. The server decides every hit and every damage (CombatService).
--   Melee weapons: hold Attack to swing at the weapon's rate. Ranged and Magic: one press = one shot (holding
--   repeats only with the Auto-Attack pass). Aim: the mouse on PC; the nearest enemy in reach on touch / gamepad.
--   Auto-Attack (pass + HUD toggle): attacks the nearest enemy in reach by itself.
--   Roll: a 12-stud dash (i-frames on the server). Block: shield bubble, half speed, no attacks.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Combat = require(ReplicatedStorage.GameSystem.Config.Combat)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local WeaponCategories = require(ReplicatedStorage.GameSystem.Config.WeaponCategories)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)

local State = require(script.Parent.Parent.State)
local Controls = require(script.Parent.ControlsController)
local Settings = require(script.Parent.SettingsController)
local Kit = script.Parent.Parent.UI.Kit
local Icons = require(Kit.Icons)
local Screens = require(Kit.Screens)
local Theme = require(Kit.Theme)

local CombatController = {}

local player = Players.LocalPlayer
local NUMBER_TIME = 0.7
local STAT_KEYS = { "Attributes", "Rebirths", "RebirthUpgrades", "Weapons", "EquippedWeapon", "Pets", "EquippedPets", "Armor", "EquippedArmor", "Boosts" }
local COLORS = {
	Hurt = Color3.fromRGB(255, 80, 70),
	Block = Color3.fromRGB(130, 200, 255),
	Dodge = Color3.fromRGB(200, 255, 200),
	Bubble = Color3.fromRGB(120, 200, 255),
}
local rng = Random.new()

local holding = false
local blocking = false
local nextAttack = 0
local nextRoll = 0
local statsCache: { [string]: any }? = nil
local bubbles: { [Player]: BasePart } = {}

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

local function stats(): { [string]: any }
	if not statsCache then
		local data = {}
		for _, key in ipairs(STAT_KEYS) do
			data[key] = State.get(key)
		end
		local ok, out = pcall(Stats.compute, data, { now = os.time() })
		statsCache = if ok then out else {}
	end
	return statsCache :: any
end

local function weapon(): (string, any)
	local weapons = State.get("Weapons")
	local uid = State.get("EquippedWeapon")
	local item = typeof(weapons) == "table" and uid and weapons[uid]
	local def = item and Weapons.ById[item.id]
	local id = if def then def.Category else "Sword"
	return id, Combat.Shapes[id] or Combat.Shapes.Sword
end

local function interval(): number
	local id = weapon()
	local category = WeaponCategories.ById[id]
	return 1 / ((if category then category.HitsPerSecond else 1) * (1 + (stats().AttackSpeed or 0)))
end

local function reach(shape: any): number
	if shape.Kind == "Projectile" or shape.Kind == "AoE" then
		return shape.Range
	elseif shape.Kind == "Line" then
		return shape.Length
	end
	return shape.Radius
end

local function isMelee(shape: any): boolean
	return shape.Kind ~= "Projectile" and shape.Kind ~= "AoE"
end

local function autoOn(): boolean
	local passes = State.get("Passes")
	return Settings.get("AutoAttack") == true and typeof(passes) == "table" and passes.AutoAttack == true
end

local function rootPart(): (BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root, humanoid
	end
	return nil, nil
end

-- The nearest living enemy (a model with an EnemyId attribute in workspace.Enemies) within range;
-- enemies behind count 50% farther.
local function nearestEnemy(origin: Vector3, range: number, forward: Vector3?): (Model?, Vector3?)
	local folder = workspace:FindFirstChild("Enemies")
	if not folder then
		return nil, nil
	end
	local best, bestScore, bestPosition = nil, math.huge, nil
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("EnemyId") and not model:GetAttribute("Dead") then
			local position = model:GetPivot().Position
			local offset = position - origin
			local f = Vector3.new(offset.X, 0, offset.Z)
			local distance = f.Magnitude
			if distance <= range and math.abs(offset.Y) < 14 then
				local score = if forward and distance > 0.1 and f.Unit:Dot(forward) < 0 then distance * 1.5 else distance
				if score < bestScore then
					best, bestScore, bestPosition = model, score, position
				end
			end
		end
	end
	return best, bestPosition
end

local function usesMouse(): boolean
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch or string.find(last.Name, "Gamepad") then
		return false
	end
	return UserInputService.MouseEnabled
end

-- The world point under the mouse (PC), or nil.
local function mousePoint(root: BasePart): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local location = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(location.X, location.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	if result then
		return result.Position
	end
	if math.abs(ray.Direction.Y) > 1e-3 then
		local t = (root.Position.Y - 3 - ray.Origin.Y) / ray.Direction.Y
		if t > 0 then
			return ray.Origin + ray.Direction * t
		end
	end
	return nil
end

local function aim(root: BasePart, shape: any, forced: Vector3?): (Vector3, Vector3?)
	local point = forced
	if not point and usesMouse() then
		point = mousePoint(root)
	end
	if not point then
		local _, position = nearestEnemy(root.Position, reach(shape) + Combat.AimAssistBonus, flat(root.CFrame.LookVector))
		point = position
	end
	if point then
		local offset = point - root.Position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude > 0.5 then
			return flat(offset), point
		end
	end
	return flat(root.CFrame.LookVector), point
end

local function swing(shape: any)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool then
		-- the default Animate script plays toolslash / toollunge when this value appears in the tool
		local value = Instance.new("StringValue")
		value.Name = "toolanim"
		value.Value = shape.Anim
		value.Parent = tool
		Debris:AddItem(value, 0.5)
	end
	Sfx.play("SwordSwing")
end

-- One attack now if the weapon is ready. Returns true when it was sent.
local function attackOnce(forced: Vector3?): boolean
	local root = rootPart()
	if not root or blocking or player:GetAttribute("Spectating") then
		return false
	end
	local now = os.clock()
	if now < nextAttack then
		return false
	end
	local _, shape = weapon()
	local dir, point = aim(root, shape, forced)
	nextAttack = now + interval()
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	swing(shape)
	Net.send("Attack", dir, point)
	return true
end

local function floating(position: Vector3, text: string, color: Color3, big: boolean)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
	local gui = Instance.new("BillboardGui")
	gui.Size = if big then UDim2.fromScale(7, 2.6) else UDim2.fromScale(5, 1.8)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Fantasy
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = gui
	anchor.Parent = workspace
	TweenService:Create(gui, TweenInfo.new(NUMBER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(NUMBER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, NUMBER_TIME + 0.1)
end

local function burst(name: string, position: Vector3)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local vfx = assets and assets.VFX:FindFirstChild(name)
	if vfx and vfx:IsA("BasePart") then
		local clone = vfx:Clone()
		clone.CFrame = CFrame.new(position)
		clone.Parent = workspace
		for _, emitter in ipairs(clone:GetDescendants()) do
			if emitter:IsA("ParticleEmitter") then
				emitter:Emit(emitter:GetAttribute("EmitCount") or 8)
			end
		end
		Debris:AddItem(clone, 1.5)
	end
end

local function styleColor(style: any): Color3
	return Combat.StyleColors[style] or Combat.StyleColors.Physical
end

local function groundBelow(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(ignore, enemies)
	end
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -24, 0), params)
	return if result then result.Position else position
end

local function shot(origin: any, dir: any, speed: any, distance: any, style: any)
	if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" or typeof(speed) ~= "number" or typeof(distance) ~= "number" or speed <= 0 then
		return
	end
	local color = styleColor(style)
	local enemy = style == "Enemy"
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * (if enemy then 1.4 else 0.9)
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Anchored = true
	ball.CanCollide, ball.CanQuery, ball.CanTouch = false, false, false
	ball.CastShadow = false
	ball.CFrame = CFrame.new(origin)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = ball
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = ball
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.18
	trail.LightEmission = 1
	trail.Parent = ball
	ball.Parent = workspace
	local seconds = math.max(0.05, distance / speed)
	local finish = origin + dir.Unit * distance
	TweenService:Create(ball, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { CFrame = CFrame.new(finish) }):Play()
	task.delay(seconds, function()
		burst("Hit_Spark", finish)
		ball.Transparency = 1
	end)
	Debris:AddItem(ball, seconds + 0.3)
end

local function area(position: any, radius: any, style: any)
	if typeof(position) ~= "Vector3" or typeof(radius) ~= "number" then
		return
	end
	local ground = groundBelow(position)
	local disc = Instance.new("Part")
	disc.Shape = Enum.PartType.Cylinder
	disc.Material = Enum.Material.Neon
	disc.Color = styleColor(style)
	disc.Transparency = 0.3
	disc.Anchored = true
	disc.CanCollide, disc.CanQuery, disc.CanTouch = false, false, false
	disc.CastShadow = false
	disc.Size = Vector3.new(0.2, 1, 1)
	disc.CFrame = CFrame.new(ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disc.Parent = workspace
	TweenService:Create(disc, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, radius * 2, radius * 2) }):Play()
	task.delay(0.22, function()
		TweenService:Create(disc, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(disc, 0.6)
	burst("Hit_Spark", ground + Vector3.new(0, 1, 0))
end

local function setBubble(target: Player, on: boolean)
	local current = bubbles[target]
	if current then
		current:Destroy()
		bubbles[target] = nil
	end
	local character = target.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (on and root and root:IsA("BasePart")) then
		return
	end
	local ball = Instance.new("Part")
	ball.Name = "BlockBubble"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 7
	ball.Material = Enum.Material.ForceField
	ball.Color = COLORS.Bubble
	ball.CanCollide, ball.CanQuery, ball.CanTouch = false, false, false
	ball.Massless = true
	ball.CastShadow = false
	ball.CFrame = root.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, ball
	weld.Parent = ball
	ball.Parent = character
	bubbles[target] = ball
end

local function setBlocking(down: boolean)
	if down == blocking then
		return
	end
	if down and not rootPart() then
		return
	end
	blocking = down
	Net.send("Block", down)
	setBubble(player, down)
	if down then
		Sfx.play("Block")
	end
end

local function dash(root: BasePart, dir: Vector3)
	local attachment = root:FindFirstChild("RootAttachment") :: Attachment?
	if not attachment then
		return
	end
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "RollDash"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	local speed = Combat.Roll.Distance / Combat.Roll.Duration
	velocity.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
	velocity.MaxForce = 1e6
	velocity.Parent = root
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	Debris:AddItem(velocity, Combat.Roll.Duration)
	-- the body fades while invulnerable
	local character = root.Parent
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "BlockBubble" then
				part.LocalTransparencyModifier = 0.5
			end
		end
		task.delay(Combat.Roll.IFrames, function()
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.LocalTransparencyModifier = 0
				end
			end
		end)
	end
end

local function roll()
	local root, humanoid = rootPart()
	if not (root and humanoid) or blocking then
		return
	end
	local now = os.clock()
	if now < nextRoll then
		return
	end
	nextRoll = now + (stats().RollCooldown or 1.5)
	local move = humanoid.MoveDirection
	local dir = if move.Magnitude > 0.1 then flat(move) else flat(root.CFrame.LookVector)
	Net.send("Roll", dir)
	Sfx.play("Roll")
	dash(root, dir)
end

-- HUD toggle for the Auto-Attack pass: above the touch Attack button, or right of the hotbar on PC.
local function autoToggle()
	local button = Instance.new("TextButton")
	button.Name = "AutoAttack"
	button.Text = ""
	button.AutoButtonColor = false
	button.Size = UDim2.fromOffset(Theme.TOUCH + 8, Theme.TOUCH + 8)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = Theme.Colors.WoodTop
	button.BackgroundTransparency = 0.15
	button.Visible = false
	Theme.round(button)
	local ring = Theme.stroke(button, Theme.Colors.GoldLight, 3)
	Icons.create("Sword", button, { Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4) })
	local label = Theme.text({ Font = "Button", Text = "AUTO", TextSize = 17, Color = Theme.Colors.Gold, Size = UDim2.fromScale(0.9, 0.3), Position = UDim2.fromScale(0.5, 0.8), AnchorPoint = Vector2.new(0.5, 0.5), Parent = button })
	local function paint()
		local on = autoOn()
		ring.Color = if on then Theme.Colors.Good else Theme.Colors.GoldLight
		ring.Thickness = if on then 5 else 3
		label.TextColor3 = if on then Theme.Colors.Good else Theme.Colors.Gold
		local passes = State.get("Passes")
		button.Visible = typeof(passes) == "table" and passes.AutoAttack == true
	end
	button.Activated:Connect(function()
		Settings.set("AutoAttack", not (Settings.get("AutoAttack") == true))
		paint()
	end)
	State.observe("Passes", paint)
	Settings.changed("AutoAttack", paint)

	local touchRoot: Instance? = nil
	local controls = player:WaitForChild("PlayerGui"):WaitForChild("Controls", 10)
	if controls then
		touchRoot = controls:FindFirstChild("TouchButtons", true)
	end
	local attack = touchRoot and touchRoot:FindFirstChild("Attack") :: GuiObject?
	if UserInputService.TouchEnabled and touchRoot and attack then
		local function follow()
			button.Position = UDim2.new(attack.Position.X.Scale, 0, attack.Position.Y.Scale, -(attack.Size.Y.Offset / 2 + Theme.TOUCH / 2 + 12))
		end
		follow()
		attack:GetPropertyChangedSignal("Position"):Connect(follow)
		attack:GetPropertyChangedSignal("Size"):Connect(follow)
		button.Parent = touchRoot
	else
		local hud = Screens.hud()
		local equipment = hud:WaitForChild("Equipment", 10) :: GuiObject?
		local half = if equipment then equipment.Size.X.Offset / 2 else 200
		button.Position = UDim2.new(0.5, half + 16 + (Theme.TOUCH + 8) / 2, 1, -10 - (Theme.TOUCH + 8) / 2)
		button.Parent = hud
	end
	paint()
end

function CombatController:Start()
	Net.on("Hit", function(position: Vector3, amount: number, crit: boolean)
		if Settings.get("DamageNumbers") ~= false then
			floating(position, Format.number(amount) .. (if crit then "!" else ""), if crit then Color3.fromRGB(255, 201, 60) else Color3.new(1, 1, 1), crit)
		end
		Sfx.play(if crit then "Crit" else "Hit", position)
		burst(if crit then "Crit_Spark" else "Hit_Spark", position - Vector3.new(0, 1.5, 0))
	end)
	Net.on("Projectile", shot)
	Net.on("Burst", area)
	Net.on("Hurt", function(amount: number, kind: string)
		local root = rootPart()
		if not root then
			return
		end
		local at = root.Position + Vector3.new(0, 3, 0)
		if kind == "dodge" then
			floating(at, "Dodge", COLORS.Dodge, false)
		elseif kind == "block" then
			Sfx.play("Block")
			floating(at, "-" .. Format.number(amount), COLORS.Block, false)
		else
			Sfx.play("Hurt")
			floating(at, "-" .. Format.number(amount), COLORS.Hurt, false)
		end
	end)

	for _, key in ipairs(STAT_KEYS) do
		State.changed(key, function()
			statsCache = nil
		end)
	end

	Controls.Attack:Connect(function(down: boolean)
		if down and not holding then
			holding = true
			local _, shape = weapon()
			if not isMelee(shape) and not autoOn() then
				-- one press = one shot, kept for a moment if the weapon is not ready yet
				task.spawn(function()
					local deadline = os.clock() + Combat.ShotBuffer
					while not attackOnce() and os.clock() < deadline do
						task.wait()
					end
				end)
				return
			end
			task.spawn(function()
				while holding do
					attackOnce()
					task.wait(math.max(0.03, nextAttack - os.clock()))
				end
			end)
		elseif not down then
			holding = false
		end
	end)
	Controls.Roll:Connect(roll)
	Controls.Block:Connect(setBlocking)

	-- Auto-Attack: the nearest enemy in the weapon's reach
	task.spawn(function()
		while true do
			task.wait(Combat.AutoAttackTick)
			if autoOn() and not holding and not blocking and os.clock() >= nextAttack then
				local root = rootPart()
				if root then
					local _, shape = weapon()
					local _, position = nearestEnemy(root.Position, reach(shape) + Combat.AutoAttackReachBonus, nil)
					if position then
						attackOnce(position)
					end
				end
			end
		end
	end)

	-- block bubbles of the other players (the local one is drawn on input)
	local function watch(other: Player)
		if other == player then
			return
		end
		other:GetAttributeChangedSignal("Blocking"):Connect(function()
			setBubble(other, other:GetAttribute("Blocking") == true)
		end)
	end
	for _, other in ipairs(Players:GetPlayers()) do
		watch(other)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(other)
		bubbles[other] = nil
	end)
	player.CharacterAdded:Connect(function()
		holding = false
		blocking = false
		bubbles[player] = nil
	end)

	task.spawn(autoToggle)
end

return CombatController
