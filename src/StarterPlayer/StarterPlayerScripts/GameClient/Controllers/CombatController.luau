--!strict
-- Player combat on the client (docs/enemies_npcs_pets_brief.txt Part A, docs/weapons_combat_brief.txt 4A): inputs,
-- aim, the hack & slash feel and the feedback. The server decides every hit and every damage (CombatService).
--   Melee weapons: hold Attack to chain the category's combo (Config/Combat Combos) at the weapon's rate; the combo
--   restarts after Combat.ComboReset s without attacking. Ranged and Magic: one press = one shot (holding repeats
--   only with the Auto-Attack pass). Aim: the mouse on PC; melee turns toward the nearest enemy within
--   Combat.Feel.AimAssistRange (on PC only within AimAssistAngle of the mouse); ranged on touch / gamepad: the
--   nearest enemy in reach. Each attack lunges forward (step Lunge).
--   Feel on a confirmed hit (Net "Hit"): hit-stop, camera shake, FOV pulse on finishers, combo counter.
--   Roll: 12-stud dash (i-frames on the server); cancels the attack recovery; no attack during the roll.
--   Jump attack (combat V3, Config/Combat AirAttacks): attacking in the air hangs a moment, then dives so the body
--   lands exactly at the hit (melee: shockwave around the landing point; Ranged: a volley; Magic: a big blast).
--   Dash strike (Config/Combat DashAttacks): an attack pressed during a roll or within DashAttack.Window after it.
--   Block: shield bubble, half speed, no attacks; cancels the attack recovery except after a finisher.
-- Hooks: Combat/Animations (animation sub-agent), VFX/VFX (VFX sub-agent), Sfx.combat (SFX sub-agent); contract in
-- docs/COMBAT_CONTRACTS.md. Other players' swings and hits come as Net "Swing" / "Impact".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Combat = require(ReplicatedStorage.GameSystem.Config.Combat)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local WeaponCategories = require(ReplicatedStorage.GameSystem.Config.WeaponCategories)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)

local State = require(script.Parent.Parent.State)
local Controls = require(script.Parent.ControlsController)
local Fx = require(script.Parent.FxController)
local Settings = require(script.Parent.SettingsController)
local Animations = require(script.Parent.Combat.Animations)
local VFX = require(script.Parent.VFX.VFX)
local Kit = script.Parent.Parent.UI.Kit
local Icons = require(Kit.Icons)
local Screens = require(Kit.Screens)
local Theme = require(Kit.Theme)

local CombatController = {}

local player = Players.LocalPlayer
local FEEL = Combat.Feel
local AIR = Combat.AirAttack
-- zone (fighting style) of a weapon element: other players' impacts only carry the element
local ZONE_OF_ELEMENT: { [string]: number } = {}
for _, zone in ipairs(Zones.List) do
	ZONE_OF_ELEMENT[zone.Element] = zone.Index
end
local STAT_KEYS = { "Attributes", "Rebirths", "RebirthUpgrades", "Weapons", "EquippedWeapon", "Pets", "EquippedPets", "Armor", "EquippedArmor", "Boosts" }
local HIT_STOP_GAP = 0.05 -- several enemies hit by one swing give one hit-stop
local LUNGE_KEEP_DISTANCE = 2.5 -- the lunge stops this far from the aimed enemy
local AIR_AIM_AHEAD = 14 -- Ranged / Magic jump attacks without an enemy in front aim at the ground this far ahead
local COMBO_COUNTER = { Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromOffset(220, 46), PopScale = 1.25, PopSeconds = 0.12, FadeSeconds = 0.3 }

local holding = false
local blocking = false
local blockHeld = false
local nextAttack = 0
local nextRoll = 0
local rollingUntil = 0
local rollStartedAt = -math.huge -- dash strikes: an attack within DashAttack.Window after the roll
local plungeUntil = 0 -- a jump attack is under way (no roll, no other attack)
local airUsed = false -- one jump attack per jump (reset on landing)
local lastAir = -math.huge
local finisherUntil = 0
local comboStep = 0
local comboAt = -math.huge
local comboCategory: string? = nil
local lastHitStop = 0
local lastSent = -math.huge -- mirrors the server's booking of my last attack (CombatService rate check)
local sentAt = 0
local pendingAttacks = 0 -- attack requests not answered yet (Net "Combo")
local RATE_MARGIN = 0.02
local statsCache: { [string]: any }? = nil

local comboLabel: TextLabel? = nil
local comboScale: UIScale? = nil
local comboHits = 0
local comboLastHit = 0

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

-- The equipped weapon: category id, its shape, the inventory item and the weapon definition.
local function weapon(): (string, any, any, any)
	local weapons = State.get("Weapons")
	local uid = State.get("EquippedWeapon")
	local item = typeof(weapons) == "table" and uid and weapons[uid]
	local def = item and Weapons.ById[item.id]
	local id = if def and Combat.Combos[def.Category] then def.Category else "Sword"
	return id, Combat.Shapes[id] or Combat.Shapes.Sword, item, def
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

-- The nearest living enemy (a model with an EnemyId attribute in workspace.Enemies) within range; enemies behind
-- count 50% farther. minDot: only enemies within that cone around forward.
local function nearestEnemy(origin: Vector3, range: number, forward: Vector3?, minDot: number?): (Model?, Vector3?)
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
				local dot = if forward and distance > 0.1 then f.Unit:Dot(forward) else 1
				if not minDot or distance < Combat.CloseRange or dot >= minDot then
					local score = if dot < 0 then distance * 1.5 else distance
					if score < bestScore then
						best, bestScore, bestPosition = model, score, position
					end
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

-- Attack direction and aim point. Melee: aim assist toward the nearest enemy within FEEL.AimAssistRange.
local function aim(root: BasePart, shape: any, forced: Vector3?): (Vector3, Vector3?, boolean)
	local point = forced
	local mouse = point == nil and usesMouse()
	if not point and mouse then
		point = mousePoint(root)
	end
	local assisted = false
	if isMelee(shape) and not forced then
		local wanted = if point then flat(point - root.Position) else flat(root.CFrame.LookVector)
		local minDot = if mouse and point then math.cos(math.rad(FEEL.AimAssistAngle)) else nil
		local _, position = nearestEnemy(root.Position, FEEL.AimAssistRange, wanted, minDot)
		if position then
			point = position
			assisted = true
		end
	elseif not point then
		local _, position = nearestEnemy(root.Position, reach(shape) + Combat.AimAssistBonus, flat(root.CFrame.LookVector))
		point = position
		assisted = position ~= nil
	end
	if point then
		local offset = point - root.Position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude > 0.5 then
			return flat(offset), point, assisted or forced ~= nil
		end
	end
	return flat(root.CFrame.LookVector), point, false
end

-- A short step forward with the swing (LinearVelocity impulse); it stops short of the aimed enemy.
local function lunge(root: BasePart, dir: Vector3, studs: number, target: Vector3?, seconds: number?)
	if studs <= 0 then
		return
	end
	if target then
		local distance = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z).Magnitude
		studs = math.min(studs, math.max(0, distance - LUNGE_KEEP_DISTANCE))
		if studs <= 0.1 then
			return
		end
	end
	local attachment = root:FindFirstChild("RootAttachment") :: Attachment?
	if not attachment then
		return
	end
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "AttackLunge"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	local duration = seconds or FEEL.LungeSeconds
	local speed = studs / duration
	velocity.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
	velocity.MaxForce = 1e6
	velocity.Parent = root
	task.delay(duration, function()
		velocity:Destroy()
		if root.Parent then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
		end
	end)
end

-- Jump attacks: in the air (falling or rising) with at least AIR.MinHeight studs between the feet and the ground.
local airParams = RaycastParams.new()
airParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundBelow(root: BasePart, depth: number): RaycastResult?
	-- enemies under the player do not count as ground (the dive goes for the real ground)
	airParams.FilterDescendantsInstances = { root.Parent :: Instance, workspace:FindFirstChild("Enemies") :: Instance }
	return workspace:Raycast(root.Position, Vector3.new(0, -depth, 0), airParams)
end

local function inAir(root: BasePart, humanoid: Humanoid): boolean
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		return false
	end
	return groundBelow(root, humanoid.HipHeight + root.Size.Y / 2 + AIR.MinHeight) == nil
end

-- Holds the body still in the air for `seconds` (Ranged / Magic jump attacks shoot from the top of the jump).
local function hover(root: BasePart, seconds: number)
	local attachment = root:FindFirstChild("RootAttachment") :: Attachment?
	if not attachment then
		return
	end
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "AirHover"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.VectorVelocity = Vector3.zero
	velocity.MaxForce = 1e6
	velocity.Parent = root
	task.delay(seconds, function()
		velocity:Destroy()
	end)
end

-- The melee jump attack's body motion: hang at least Hang s (a small drift toward the aim), then dive so the feet touch
-- the ground at Impact: the body keeps hanging until a dive at AIR.DiveSpeed would land on time (low jumps hang longer),
-- faster up to AIR.DiveMaxSpeed from high up. onLand(groundPoint) once on landing.
local function plunge(root: BasePart, humanoid: Humanoid, dir: Vector3, step: { [string]: any }, speed: number, target: Vector3?, onLand: (Vector3) -> ())
	local attachment = root:FindFirstChild("RootAttachment") :: Attachment?
	if not attachment then
		return
	end
	local hang = (step.Hang or 0) / speed
	local impact = math.max(hang + 0.05, step.Impact / speed)
	local drift = step.Lunge or 0
	if target then
		local distance = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z).Magnitude
		drift = math.min(drift, math.max(0, distance - LUNGE_KEEP_DISTANCE))
	end
	local driftSpeed = drift / impact
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "AirDive"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.VectorVelocity = Vector3.new(dir.X * driftSpeed, 0, dir.Z * driftSpeed)
	velocity.MaxForce = 1e6
	velocity.Parent = root
	local started = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		local landedAt: Vector3? = nil
		local stop = not root.Parent or humanoid.Health <= 0 or t > impact + AIR.LandTimeout
		if not stop and t >= hang then
			local reach = humanoid.HipHeight + root.Size.Y / 2
			local hit = groundBelow(root, reach + 200)
			local height = if hit then root.Position.Y - hit.Position.Y - reach else math.huge
			if height <= 0.25 or (t > hang + 0.05 and humanoid.FloorMaterial ~= Enum.Material.Air) then
				landedAt = if hit then hit.Position else root.Position - Vector3.new(0, reach, 0)
			else
				local left = impact - t
				local need = if left > 0.02 then height / left else math.huge
				local fall = if need >= AIR.DiveSpeed then math.min(need, AIR.DiveMaxSpeed) else 0
				velocity.VectorVelocity = Vector3.new(dir.X * driftSpeed, -fall, dir.Z * driftSpeed)
			end
		end
		if stop or landedAt then
			conn:Disconnect()
			velocity:Destroy()
			if root.Parent then
				root.AssemblyLinearVelocity = Vector3.new(0, math.min(0, root.AssemblyLinearVelocity.Y), 0)
			end
			plungeUntil = 0
			if landedAt then
				onLand(landedAt)
			end
		end
	end)
end

-- The held weapon: Tool, rarity, element and zone (1..12: the zone fighting style, Config/CombatStyles).
local function toolInfo(character: Model): (Tool?, number?, string?, number?)
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		return nil, nil, nil, nil
	end
	local def = Weapons.ById[tool:GetAttribute("WeaponId") or ""]
	local rarity = tool:GetAttribute("Rarity")
	local zone = tool:GetAttribute("Zone")
	return tool, if typeof(rarity) == "number" then rarity else nil, if def then def.Element else nil, if typeof(zone) == "number" then zone elseif def then def.Zone else nil
end

-- The landing of my jump attack: shockwave, sound, shake (the damage comes from the server's "Hit").
local function landed(character: Model, categoryId: string, groundPoint: Vector3, radius: number)
	local tool, rarity, element, zone = toolInfo(character)
	local ctx = { Character = character, Tool = tool, Category = categoryId, Position = groundPoint, Radius = radius, Rarity = rarity, Element = element, Zone = zone, IsLocal = true }
	if VFX.land then
		VFX.land(ctx)
	end
	Sfx.combat("Land", ctx)
	Fx.shake(if categoryId == "Heavy" then FEEL.Shake.Heavy else FEEL.Shake.Finisher)
	Fx.fovPulse(FEEL.FovPulse.Degrees, FEEL.FovPulse.Seconds)
end

-- One attack now if the weapon is ready. Returns true when it was sent.
local function attackOnce(forced: Vector3?): boolean
	local root, humanoid = rootPart()
	if not (root and humanoid) or blocking or player:GetAttribute("Spectating") then
		return false
	end
	local now = os.clock()
	if now < nextAttack or now < rollingUntil or now < plungeUntil then
		return false
	end
	local categoryId, shape = weapon()
	local steps = Combat.Combos[categoryId]
	local gap = interval()
	if now - lastSent < gap * Combat.RateTolerance + RATE_MARGIN then
		return false
	end
	-- jump attack / dash strike / the same combo step the server will pick (CombatService nextStep)
	local variant: string? = nil
	if Combat.AirAttacks[categoryId] and not airUsed and now - lastAir >= AIR.MinGap and inAir(root, humanoid) then
		variant = "Air"
	elseif Combat.DashAttacks[categoryId] and now - rollStartedAt <= Combat.Roll.Duration + Combat.DashAttack.Window then
		variant = "Dash"
	end
	local step: { [string]: any }, index: number
	if variant then
		step = if variant == "Air" then Combat.AirAttacks[categoryId] else Combat.DashAttacks[categoryId]
		index = 1
		comboStep = 0 -- the combo restarts after it
		rollStartedAt = -math.huge
	else
		if comboCategory ~= categoryId or now - comboAt > gap + Combat.ComboReset then
			comboStep = 0
		end
		comboStep = comboStep % #steps + 1
		step = steps[comboStep]
		index = comboStep
	end
	comboAt = now
	comboCategory = categoryId
	local dir, point, assisted = aim(root, shape, forced)
	if variant == "Air" and not isMelee(shape) and not forced then
		-- shooting / casting down from the air: the nearest enemy in front, else the ground a little ahead
		local _, position = nearestEnemy(root.Position, reach(shape), dir, math.cos(math.rad(FEEL.AimAssistAngle)))
		if position then
			point = position
			dir = flat(position - root.Position)
		else
			local ahead = root.Position + dir * AIR_AIM_AHEAD
			local ground = workspace:Raycast(ahead, Vector3.new(0, -60, 0), airParams)
			point = if ground then ground.Position else ahead - Vector3.new(0, humanoid.HipHeight + root.Size.Y, 0)
		end
	end
	nextAttack = now + gap
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	local character = root.Parent :: Model
	local speed = 1 + (stats().AttackSpeed or 0)
	local finisher = step.Finisher == true or variant == "Air"
	if variant == "Air" then
		airUsed = true
		lastAir = now
		if isMelee(shape) then
			plungeUntil = now + step.Impact / speed + AIR.LandTimeout
			local radius = (step.Shape and step.Shape.Radius) or shape.Radius or 6
			plunge(root, humanoid, dir, step, speed, if assisted then point else nil, function(groundPoint: Vector3)
				landed(character, categoryId, groundPoint, radius)
			end)
		else
			hover(root, math.max(step.Hang or 0, step.Impact) / speed + 0.05)
		end
	else
		lunge(root, dir, step.Lunge or 0, if assisted then point else nil, step.LungeSeconds)
	end
	local length = Animations.attack(character, categoryId, index, speed, if point then point - (root.Position + Vector3.new(0, 1.5, 0)) else nil, variant)
	finisherUntil = if finisher then now + math.max(length, step.Impact / speed) else 0
	local tool, rarity, element, zone = toolInfo(character)
	local ctx = {
		Character = character,
		Tool = tool,
		Category = categoryId,
		Step = index,
		Variant = variant,
		Finisher = finisher,
		Direction = dir,
		Rarity = rarity,
		Element = element,
		Zone = zone,
		Speed = speed,
		IsLocal = true,
	}
	VFX.swing(ctx)
	Sfx.combat("Swing", ctx)
	if now - sentAt > 1.5 then
		pendingAttacks = 0 -- an answer lost (death, respawn): start counting again
	end
	pendingAttacks += 1
	sentAt = now
	lastSent = math.max(now, lastSent + gap)
	Net.send("Attack", dir, point, variant)
	return true
end

-- The server's answer to an attack request: the step it ran, or its current step when it refused (blocked, rolling,
-- too fast). Once no other request is in flight the prediction follows the server again.
local function onCombo(category: string, step: number, accepted: boolean)
	pendingAttacks = math.max(0, pendingAttacks - 1)
	if accepted ~= true then
		finisherUntil = 0
	end
	if pendingAttacks == 0 and typeof(step) == "number" then
		comboStep = step
		if typeof(category) == "string" and category ~= "" then
			comboCategory = category
		end
	end
end

-- Combo hit counter (center of the screen), fades FEEL.ComboCounterSeconds after the last hit.
local function countHit()
	local label, scale = comboLabel, comboScale
	if not (label and scale) then
		return
	end
	local now = os.clock()
	if now - comboLastHit > FEEL.ComboCounterSeconds then
		comboHits = 0
	end
	comboHits += 1
	comboLastHit = now
	if comboHits < 2 then
		return
	end
	label.Text = `{comboHits} HITS`
	label.TextTransparency = 0
	label.Visible = true
	scale.Scale = COMBO_COUNTER.PopScale
	TweenService:Create(scale, TweenInfo.new(COMBO_COUNTER.PopSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local hits = comboHits
	task.delay(FEEL.ComboCounterSeconds, function()
		if comboHits == hits and label.Visible then
			local fade = TweenService:Create(label, TweenInfo.new(COMBO_COUNTER.FadeSeconds), { TextTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			if comboHits == hits then
				label.Visible = false
			end
		end
	end)
end

local function makeComboCounter()
	local label = Theme.text({ Name = "ComboCounter", Font = "Title", Text = "", TextSize = 40, Color = Theme.Colors.Gold, Size = COMBO_COUNTER.Size, Position = COMBO_COUNTER.Position, AnchorPoint = Vector2.new(0.5, 0.5), Parent = Screens.hud() })
	label.Visible = false
	local scale = Instance.new("UIScale")
	scale.Parent = label
	comboLabel, comboScale = label, scale
end

-- A confirmed hit of mine: number, impact effects and sounds, hit-stop, shake, FOV pulse, combo counter.
local function onHit(position: Vector3, amount: number, crit: boolean, finisher: boolean?, category: string?)
	if Settings.get("DamageNumbers") ~= false then
		VFX.damageNumber(position, Format.number(amount) .. (if crit then "!" else ""), if crit then "crit" else "normal")
	end
	local mine = player.Character
	local element, zone = nil, nil
	if mine then
		element, zone = select(3, toolInfo(mine))
	end
	local ctx = { Position = position, Category = category, Crit = crit, Finisher = finisher == true, Element = element, Zone = zone, IsLocal = true }
	VFX.impact(ctx)
	Sfx.combat("Impact", ctx)
	countHit()
	local now = os.clock()
	if now - lastHitStop < HIT_STOP_GAP then
		return
	end
	lastHitStop = now
	local heavy = category == "Heavy"
	local character = player.Character
	if character then
		Animations.hitStop(character, if finisher then FEEL.HitStop.Finisher elseif heavy then FEEL.HitStop.Heavy else FEEL.HitStop.Normal)
	end
	Fx.shake(if finisher then FEEL.Shake.Finisher elseif heavy then FEEL.Shake.Heavy else FEEL.Shake.Normal)
	if finisher then
		Fx.fovPulse(FEEL.FovPulse.Degrees, FEEL.FovPulse.Seconds)
	end
end

-- Another player's swing (Net "Swing"): animation, trail and whoosh only.
local function onSwing(attacker: Player, category: string, step: number, dir: Vector3, speed: number, aim: Vector3?, variant: string?)
	local character = attacker.Character
	if attacker == player or not character or typeof(category) ~= "string" or typeof(step) ~= "number" then
		return
	end
	local kind = if variant == "Air" or variant == "Dash" then variant else nil
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	Animations.attack(character, category, step, if typeof(speed) == "number" then speed else 1, if typeof(aim) == "Vector3" then aim else nil, kind)
	local steps = Combat.Combos[category]
	local tool, rarity, element, zone = toolInfo(character)
	local ctx = {
		Character = character,
		Tool = tool,
		Category = category,
		Step = step,
		Variant = kind,
		Zone = zone,
		Finisher = kind == "Air" or (steps and steps[step] and steps[step].Finisher == true and kind == nil) or false,
		Direction = if typeof(dir) == "Vector3" then dir else Vector3.new(0, 0, -1),
		Rarity = rarity,
		Element = element,
		Speed = speed,
		IsLocal = false,
		Position = if root then root.Position else nil,
	}
	VFX.swing(ctx)
	Sfx.combat("Swing", ctx)
end

local function onImpact(position: Vector3, category: string?, crit: boolean, finisher: boolean, element: string?)
	if typeof(position) ~= "Vector3" then
		return
	end
	local ctx = {
		Position = position,
		Category = category,
		Crit = crit == true,
		Finisher = finisher == true,
		Element = if typeof(element) == "string" then element else nil,
		Zone = if typeof(element) == "string" then ZONE_OF_ELEMENT[element] else nil,
		IsLocal = false,
	}
	VFX.impact(ctx)
	Sfx.combat("Impact", ctx)
end

-- Another player's jump attack hit the ground (Net "AirSlam"): shockwave and sound.
local function onAirSlam(attacker: Player, category: string, position: Vector3, radius: number, element: string?)
	if attacker == player or typeof(position) ~= "Vector3" then
		return
	end
	local character = attacker.Character
	local tool: Tool?, rarity: number?, zone: number? = nil, nil, nil
	if character then
		local _
		tool, rarity, _, zone = toolInfo(character)
	end
	local ctx = {
		Character = character,
		Tool = tool,
		Category = if typeof(category) == "string" then category else nil,
		Position = position,
		Radius = if typeof(radius) == "number" then radius else 6,
		Rarity = rarity,
		Element = if typeof(element) == "string" then element else nil,
		Zone = zone,
		IsLocal = false,
	}
	if VFX.land then
		VFX.land(ctx)
	end
	Sfx.combat("Land", ctx)
end

-- Another player's roll or hit reaction (Net "Motion"): animation, effects and sound only.
local function onMotion(other: Player, kind: string, dir: Vector3?)
	local character = other.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if other == player or not character or not (root and root:IsA("BasePart")) then
		return
	end
	if kind == "Roll" then
		local d = if typeof(dir) == "Vector3" then dir else root.CFrame.LookVector
		Animations.cancel(character)
		Animations.roll(character, d)
		local ctx = { Character = character, Direction = d, IsLocal = false, Position = root.Position }
		VFX.roll(ctx)
		Sfx.combat("Roll", ctx)
	elseif kind == "BlockHit" then
		Animations.blockHit(character)
		VFX.blockHit({ Character = character, Position = root.Position + Vector3.new(0, 3, 0) })
		Sfx.combat("BlockHit", { Position = root.Position })
	elseif kind == "Hurt" then
		Animations.hurt(character)
		Sfx.combat("Hurt", { Position = root.Position })
	end
end

local function applyBlock(down: boolean)
	if down == blocking then
		return
	end
	if down and not rootPart() then
		return
	end
	blocking = down
	Net.send("Block", down)
	local character = player.Character
	if character then
		if down then
			Animations.cancel(character)
		end
		Animations.block(character, down)
		VFX.block({ Character = character, On = down })
	end
	if down then
		Sfx.combat("Block", {})
	end
end

-- Block cancels the attack recovery, except a finisher's: then it starts when the finisher is over.
local function setBlocking(down: boolean)
	blockHeld = down
	if not down then
		applyBlock(false)
		return
	end
	local wait = finisherUntil - os.clock()
	if wait <= 0 then
		applyBlock(true)
		return
	end
	task.delay(wait, function()
		if blockHeld then
			applyBlock(true)
		end
	end)
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
	task.delay(Combat.Roll.Duration, function()
		velocity:Destroy()
		if root.Parent then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
		end
	end)
	-- the body fades while invulnerable, then gets its own value back (1 = hidden in first person)
	local character = root.Parent
	if character then
		local before: { [BasePart]: number } = {}
		local faded: { [BasePart]: number } = {}
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Name ~= "BlockBubble" then
				before[part] = part.LocalTransparencyModifier
				part.LocalTransparencyModifier = math.max(part.LocalTransparencyModifier, 0.5)
				faded[part] = part.LocalTransparencyModifier
			end
		end
		task.delay(Combat.Roll.IFrames, function()
			for part, value in pairs(before) do
				-- undo only our own fade: if the camera changed it meanwhile (zoom in / out), the camera's value stays
				-- (restoring a stale 1 used to leave the body hidden)
				if part.Parent and part.LocalTransparencyModifier == faded[part] then
					part.LocalTransparencyModifier = value
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
	if now < nextRoll or now < plungeUntil then
		return
	end
	nextRoll = now + (stats().RollCooldown or 1.5)
	rollingUntil = now + Combat.Roll.Duration
	rollStartedAt = now
	finisherUntil = 0
	local move = humanoid.MoveDirection
	local dir = if move.Magnitude > 0.1 then flat(move) else flat(root.CFrame.LookVector)
	Net.send("Roll", dir)
	local character = root.Parent :: Model
	Animations.cancel(character)
	Animations.roll(character, dir)
	local ctx = { Character = character, Direction = dir, IsLocal = true }
	VFX.roll(ctx)
	Sfx.combat("Roll", ctx)
	dash(root, dir)
end

local function onHurt(amount: number, kind: string)
	local root = rootPart()
	if not root then
		return
	end
	local character = root.Parent :: Model
	local at = root.Position + Vector3.new(0, 3, 0)
	if kind == "dodge" then
		VFX.damageNumber(at, "Dodge", "dodge")
	elseif kind == "block" then
		Animations.blockHit(character)
		VFX.blockHit({ Character = character, Position = at })
		Sfx.combat("BlockHit", {})
		VFX.damageNumber(at, "-" .. Format.number(amount), "block")
	else
		Animations.hurt(character)
		Sfx.combat("Hurt", {})
		VFX.damageNumber(at, "-" .. Format.number(amount), "hurt")
	end
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
	Net.on("Hit", onHit)
	Net.on("Combo", onCombo)
	Net.on("Swing", onSwing)
	Net.on("Impact", onImpact)
	Net.on("AirSlam", onAirSlam)
	Net.on("Projectile", function(origin: Vector3, dir: Vector3, speed: number, distance: number, style: string, shooter: Player?)
		local from = if typeof(shooter) == "Instance" and shooter:IsA("Player") then shooter else nil
		VFX.shot({ Origin = origin, Direction = dir, Speed = speed, Distance = distance, Style = style, Shooter = from })
		-- the shooter's own release / fire sound is the Swing; Shot is the projectile itself (enemy shots included)
		Sfx.combat("Shot", {
			Position = origin,
			Style = style,
			Speed = speed,
			Distance = distance,
			Enemy = style == "Enemy",
			Shooter = from,
			Own = from == player,
		})
	end)
	Net.on("Burst", function(position: Vector3, radius: number, style: string)
		VFX.burst({ Position = position, Radius = radius, Style = style })
		Sfx.combat("Burst", { Position = position, Radius = radius, Style = style })
	end)
	Net.on("Hurt", onHurt)
	Net.on("Motion", onMotion)

	for _, key in ipairs(STAT_KEYS) do
		State.changed(key, function()
			statsCache = nil
		end)
	end

	Controls.Attack:Connect(function(down: boolean)
		if down and not holding then
			holding = true
			local untilRollEnd = rollingUntil - os.clock()
			if untilRollEnd > 0 then
				-- pressed during the roll: the dash strike comes out at the end of it, even after a quick tap
				task.delay(untilRollEnd + 0.01, function()
					if not holding then
						attackOnce()
					end
				end)
			end
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
					task.wait(math.max(0.03, math.max(nextAttack, rollingUntil) - os.clock()))
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

	-- guard poses and block bubbles (VFX.block) of the other players (the local one is drawn on input)
	local function watch(other: Player)
		if other == player then
			return
		end
		local function apply()
			local on = other:GetAttribute("Blocking") == true
			if other.Character then
				Animations.block(other.Character, on)
				VFX.block({ Character = other.Character, On = on })
			end
		end
		other:GetAttributeChangedSignal("Blocking"):Connect(apply)
		if other:GetAttribute("Blocking") == true then
			task.defer(apply)
		end
	end
	for _, other in ipairs(Players:GetPlayers()) do
		watch(other)
	end
	Players.PlayerAdded:Connect(watch)

	-- draw (a weapon Tool appears in the character) and death sounds of every player (the local one at full volume)
	local function watchCharacter(owner: Player, character: Model)
		local isLocal = owner == player
		local function play(event: string, category: any, rarity: any)
			local root = character:FindFirstChild("HumanoidRootPart")
			local position = if root and root:IsA("BasePart") then root.Position else nil
			if isLocal or position then
				Sfx.combat(event, {
					Category = if typeof(category) == "string" then category else nil,
					Rarity = if typeof(rarity) == "number" then rarity else nil,
					IsLocal = isLocal,
					Position = position,
				})
			end
		end
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				play("Equip", child:GetAttribute("Category"), child:GetAttribute("Rarity"))
			end
		end)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				play("Death", nil, nil)
			end)
		end
	end
	local function watchCharacters(owner: Player)
		owner.CharacterAdded:Connect(function(character)
			task.spawn(watchCharacter, owner, character)
		end)
		if owner.Character then
			task.spawn(watchCharacter, owner, owner.Character)
		end
	end
	for _, other in ipairs(Players:GetPlayers()) do
		watchCharacters(other)
	end
	Players.PlayerAdded:Connect(watchCharacters)
	local function watchLanding(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running or new == Enum.HumanoidStateType.RunningNoPhysics then
					airUsed = false
				end
			end)
		end
	end
	if player.Character then
		task.spawn(watchLanding, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		holding = false
		blocking = false
		blockHeld = false
		comboStep = 0
		finisherUntil = 0
		rollingUntil = 0
		rollStartedAt = -math.huge
		plungeUntil = 0
		airUsed = false
		pendingAttacks = 0
		task.spawn(watchLanding, character)
	end)

	makeComboCounter()
	task.spawn(autoToggle)
end

return CombatController
