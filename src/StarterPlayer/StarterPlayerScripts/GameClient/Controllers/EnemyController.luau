--!strict
-- Enemies on the client (docs/enemies_npcs_pets_brief.txt Part B): HP bars, hit and telegraph flashes, the procedural
-- animation of the rigs, spawn fade-in, death fade and the kill reward pop. Nothing here decides anything: the server
-- (EnemyService) moves the enemies and sets their attributes (HP, MaxHP, State, Telegraph, AttackAt, HitAt, Dead).
-- Animation: every rig joint is a Motor6D named after its part (Body, Head, LegFL, ArmR, WingL, Seg2...), posed here
-- through Motor6D.Transform from the movement speed and the attack timings. The imported Blender rigs use the same
-- joint names, so they animate the same way until their own clips are played.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Enemies = require(ReplicatedStorage.GameSystem.Config.Enemies)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Settings = require(script.Parent.SettingsController)

local EnemyController = {}

local player = Players.LocalPlayer
local BAR_RANGE = 30 -- studs: the bar shows within this distance, or once the enemy is hurt
local ANIMATE_RANGE = 150
local TIER_COLORS = {
	normal = Color3.new(1, 1, 1),
	mini = Color3.fromRGB(255, 160, 40),
	boss = Color3.fromRGB(255, 70, 60),
}
local FILL_COLOR = Color3.fromRGB(230, 60, 60)
local GOLD_COLOR = Color3.fromRGB(255, 205, 60)
local LEG_SIGNS = { LegFL = 1, LegBR = 1, LegFR = -1, LegBL = -1, LegL = 1, LegR = -1 } -- walk cycle: diagonal pairs

type Entry = {
	model: Model,
	root: BasePart,
	def: any,
	joints: { [string]: Motor6D },
	gui: BillboardGui,
	fill: Frame,
	hpLabel: TextLabel,
	phase: number,
	seed: number,
	flash: Highlight?,
	flashUntil: number,
	deadAt: number?,
	connections: { RBXScriptConnection },
}

local entries: { [Model]: Entry } = {}
local barsFolder: Folder

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function setTransparency(model: Model, value: number)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "Root" then
			part.LocalTransparencyModifier = value
		end
	end
end

local function updateBar(entry: Entry)
	local hp = entry.model:GetAttribute("HP") or 0
	local maxHP = math.max(1, entry.model:GetAttribute("MaxHP") or 1)
	entry.fill.Size = UDim2.fromScale(math.clamp(hp / maxHP, 0, 1), 1)
	entry.hpLabel.Text = Format.number(math.max(0, math.ceil(hp)))
end

local function flash(entry: Entry, color: Color3, transparency: number, seconds: number)
	local highlight = entry.flash
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.OutlineTransparency = 1
		highlight.Adornee = entry.model
		highlight.Parent = barsFolder
		entry.flash = highlight
	end
	local h = highlight :: Highlight
	h.FillColor = color
	h.FillTransparency = transparency
	h.Enabled = true
	entry.flashUntil = math.max(entry.flashUntil, os.clock() + seconds)
end

local function makeBar(model: Model, root: BasePart, def: any): (BillboardGui, Frame, TextLabel)
	local halfHeight = model:GetAttribute("HalfHeight") or root.Size.Y / 2
	local gui = Instance.new("BillboardGui")
	gui.Name = model.Name
	gui.Adornee = root
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, halfHeight + 1.4, 0)
	gui.MaxDistance = 140
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local name = Instance.new("TextLabel")
	name.Name = "EnemyName"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 18)
	name.Font = Enum.Font.FredokaOne
	name.TextSize = 17
	name.TextColor3 = TIER_COLORS[def.Tier or "normal"] or TIER_COLORS.normal
	name.TextStrokeTransparency = 0.2
	name.Text = def.Name
	name.Parent = gui
	local back = Instance.new("Frame")
	back.Name = "Bar"
	back.Position = UDim2.new(0.1, 0, 0, 21)
	back.Size = UDim2.new(0.8, 0, 0, 14)
	back.BackgroundColor3 = Color3.fromRGB(30, 22, 22)
	back.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(15, 10, 10)
	stroke.Thickness = 1.5
	stroke.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = FILL_COLOR
	fill.BorderSizePixel = 0
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 5)
	fillCorner.Parent = fill
	fill.Parent = back
	local hp = Instance.new("TextLabel")
	hp.Name = "HP"
	hp.BackgroundTransparency = 1
	hp.Size = UDim2.fromScale(1, 1)
	hp.Font = Enum.Font.GothamBold
	hp.TextSize = 11
	hp.TextColor3 = Color3.new(1, 1, 1)
	hp.TextStrokeTransparency = 0.4
	hp.ZIndex = 2
	hp.Parent = back
	back.Parent = gui
	gui.Parent = barsFolder
	return gui, fill, hp
end

local function remove(model: Model)
	local entry = entries[model]
	if not entry then
		return
	end
	entries[model] = nil
	for _, connection in ipairs(entry.connections) do
		connection:Disconnect()
	end
	entry.gui:Destroy()
	if entry.flash then
		entry.flash:Destroy()
	end
end

local function add(model: Instance)
	if not model:IsA("Model") or entries[model] then
		return
	end
	local id = model:GetAttribute("EnemyId")
	local def = typeof(id) == "string" and Enemies.ById[id]
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not (def and root and root:IsA("BasePart")) or model:GetAttribute("Dead") then
		return -- not streamed in yet: the periodic scan adds it later
	end
	local joints: { [string]: Motor6D } = {}
	for _, joint in ipairs(model:GetDescendants()) do
		if joint:IsA("Motor6D") and joint.Part1 then
			joints[joint.Part1.Name] = joint
		end
	end
	local gui, fill, hpLabel = makeBar(model, root, def)
	local entry: Entry = {
		model = model, root = root, def = def, joints = joints, gui = gui, fill = fill, hpLabel = hpLabel,
		phase = math.random() * 10, seed = math.random() * 100, flash = nil, flashUntil = 0, deadAt = nil, connections = {},
	}
	entries[model] = entry
	updateBar(entry)
	table.insert(entry.connections, model:GetAttributeChangedSignal("HP"):Connect(function()
		updateBar(entry)
	end))
	table.insert(entry.connections, model:GetAttributeChangedSignal("HitAt"):Connect(function()
		flash(entry, Color3.new(1, 1, 1), 0.35, 0.1)
	end))
	table.insert(entry.connections, model:GetAttributeChangedSignal("Dead"):Connect(function()
		if model:GetAttribute("Dead") and not entry.deadAt then
			entry.deadAt = os.clock()
			entry.gui.Enabled = false
			Sfx.play("EnemyDeath", root.Position)
		end
	end))
	-- spawn: fade in
	setTransparency(model, 1)
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local k = math.clamp((os.clock() - start) / 0.35, 0, 1)
		if not model.Parent or entry.deadAt then
			connection:Disconnect()
			return
		end
		setTransparency(model, 1 - k)
		if k >= 1 then
			connection:Disconnect()
		end
	end)
	table.insert(entry.connections, connection)
end

local function angles(x: number, y: number, z: number): CFrame
	return CFrame.Angles(x, y, z)
end

-- Pose of one enemy for this frame.
local function animate(entry: Entry, dt: number, now: number, serverTime: number)
	local model, joints = entry.model, entry.joints
	local velocity = entry.root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local walk = math.clamp(speed / 10, 0, 1.3)
	entry.phase += dt * (3 + speed * 0.55)
	local phase = entry.phase
	local t = now + entry.seed
	local rig = entry.def.Rig or "Biped"

	-- attack timings from the server attributes
	local telegraphAt = model:GetAttribute("Telegraph")
	local windup = 0
	if typeof(telegraphAt) == "number" and serverTime < telegraphAt then
		local total = math.max(0.2, entry.def.Telegraph or 0.4)
		windup = math.clamp(1 - (telegraphAt - serverTime) / total, 0, 1)
	end
	local attackAt = model:GetAttribute("AttackAt")
	local strike = 0
	if typeof(attackAt) == "number" then
		local since = serverTime - attackAt
		if since >= 0 and since < 0.3 then
			strike = 1 - since / 0.3
		end
	end
	local hitAt = model:GetAttribute("HitAt")
	local recoil = 0
	if typeof(hitAt) == "number" then
		local since = serverTime - hitAt
		if since >= 0 and since < 0.15 then
			recoil = 1 - since / 0.15
		end
	end
	local dying = 0
	if entry.deadAt then
		dying = math.clamp((now - entry.deadAt) / 0.6, 0, 1)
	end

	local swing = math.sin(phase) * walk
	local bodyPitch = windup * 0.3 - strike * 0.35 + recoil * 0.2
	local bob = math.sin(phase * 2) * 0.08 * walk + math.sin(t * 2) * 0.03
	local body = joints.Body or joints.Torso
	if body then
		local fall = CFrame.new(0, -dying * 0.6, 0) * angles(0, 0, dying * math.rad(80))
		local float = if rig == "Floater" then math.sin(t * 2) * 0.25 else 0
		body.Transform = fall * CFrame.new(0, bob + float, -strike * 0.5) * angles(bodyPitch, 0, 0)
	end
	local head = joints.Head
	if head then
		head.Transform = angles(math.sin(t * 1.3) * 0.06 - windup * 0.15, math.sin(t * 0.7) * 0.12, 0)
	end
	-- four legs, two legs, arms
	for name, sign in pairs(LEG_SIGNS) do
		local joint = joints[name]
		if joint then
			joint.Transform = angles(swing * 0.6 * sign, 0, 0)
		end
	end
	local armL, armR = joints.ArmL, joints.ArmR
	local raise = windup * 2.2 - strike * 1.4
	if armR then
		armR.Transform = angles(-swing * 0.5 + (if rig == "Crustacean" then -raise * 0.3 else -raise), 0, 0)
	end
	if armL then
		local both = rig == "Golem" or rig == "Gorilla" or rig == "Crustacean" or rig == "Snowman"
		armL.Transform = angles(swing * 0.5 + (if both then -raise * (if rig == "Crustacean" then 0.3 else 1) else 0), 0, 0)
	end
	-- many-legged rigs: legs sweep in turn
	for i = 1, 4 do
		local left, right = joints[`LegL{i}`], joints[`LegR{i}`]
		local sweep = math.sin(phase * 1.6 + i * 1.3) * 0.3 * walk
		if left then
			left.Transform = angles(0, sweep, math.max(0, -sweep) * 0.6)
		end
		if right then
			right.Transform = angles(0, -sweep, -math.max(0, -sweep) * 0.6)
		end
	end
	-- wings
	local flap = math.sin(t * (if speed > 1 then 14 else 9)) * 0.55 + windup * 0.4
	if joints.WingL then
		joints.WingL.Transform = angles(0, 0, -flap)
	end
	if joints.WingR then
		joints.WingR.Transform = angles(0, 0, flap)
	end
	-- tails and serpent segments
	if joints.Tail then
		joints.Tail.Transform = angles(0, math.sin(t * 3) * 0.3, 0)
	end
	for i = 2, 6 do
		local segment = joints[`Seg{i}`]
		if segment then
			segment.Transform = angles(0, math.sin(phase * 0.9 - i * 0.9) * 0.35 * (0.4 + walk), 0)
		end
	end
	if joints.Seg1 then
		joints.Seg1.Transform = CFrame.new(0, 0, -strike * 0.8) * angles(windup * 0.25, 0, 0)
	end
	if joints.Tail2 then
		joints.Tail2.Transform = angles(math.sin(t * 2.5) * 0.25, 0, 0)
	end
	if joints.FinL then
		joints.FinL.Transform = angles(0, 0, math.sin(t * 6) * 0.3)
	end
	if joints.FinR then
		joints.FinR.Transform = angles(0, 0, -math.sin(t * 6) * 0.3)
	end
	if joints.Jaw then
		joints.Jaw.Transform = angles(math.max(windup, strike) * 0.5, 0, 0)
	end
	-- death fade
	if entry.deadAt then
		setTransparency(model, math.clamp((now - entry.deadAt - 0.3) / 0.6, 0, 1))
	end
end

local function killPop(position: any, gold: any)
	if typeof(position) ~= "Vector3" or typeof(gold) ~= "number" then
		return
	end
	Sfx.play("GoldPickup", position)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 2)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "+" .. Format.number(gold)
	label.TextColor3 = GOLD_COLOR
	label.TextStrokeTransparency = 0
	label.Parent = gui
	anchor.Parent = workspace
	TweenService:Create(gui, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1.1)
	if Settings.get("LowFx") then
		return
	end
	for i = 1, 4 do
		local coin = Instance.new("Part")
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.15, 0.8, 0.8)
		coin.Material = Enum.Material.Neon
		coin.Color = GOLD_COLOR
		coin.Anchored = true
		coin.CanCollide, coin.CanQuery, coin.CanTouch = false, false, false
		coin.CastShadow = false
		coin.CFrame = CFrame.new(position)
		coin.Parent = workspace
		local angle = i * math.pi / 2 + math.random()
		local goal = position + Vector3.new(math.cos(angle) * 2, 2.5 + math.random(), math.sin(angle) * 2)
		TweenService:Create(coin, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(goal) * CFrame.Angles(0, angle, math.rad(90)), Transparency = 0.2 }):Play()
		task.delay(0.45, function()
			TweenService:Create(coin, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(0.05, 0.2, 0.2) }):Play()
		end)
		Debris:AddItem(coin, 0.8)
	end
end

function EnemyController:Start()
	barsFolder = Instance.new("Folder")
	barsFolder.Name = "EnemyBars"
	barsFolder.Parent = player:WaitForChild("PlayerGui")
	local folder = workspace:WaitForChild("Enemies")
	folder.ChildAdded:Connect(function(child)
		task.defer(add, child) -- attributes and parts arrive with the model
	end)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			remove(child)
		end
	end)
	-- StreamingEnabled: models can arrive before their parts, and parts can stream out; rescan every second
	task.spawn(function()
		while true do
			for _, child in ipairs(folder:GetChildren()) do
				local entry = entries[child :: Model]
				if entry and not entry.root.Parent then
					remove(child :: Model)
				elseif not entry then
					add(child)
				end
			end
			task.wait(1)
		end
	end)
	Net.on("EnemyKilled", killPop)

	local barCheck = 0
	RunService.PreRender:Connect(function(dt: number)
		local now = os.clock()
		local serverTime = serverNow()
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local character = player.Character
		local myRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		barCheck += dt
		local checkBars = barCheck > 0.2
		if checkBars then
			barCheck = 0
		end
		local highContrast = Settings.get("HighContrastTelegraphs") == true
		for model, entry in pairs(entries) do
			if not model.Parent then
				remove(model)
				continue
			end
			local position = entry.root.Position
			if (position - eye).Magnitude < ANIMATE_RANGE or entry.deadAt then
				animate(entry, dt, now, serverTime)
			end
			-- telegraph: red pulse until the hit
			local telegraphAt = model:GetAttribute("Telegraph")
			if typeof(telegraphAt) == "number" and serverTime < telegraphAt and not entry.deadAt then
				local pulse = 0.5 + 0.5 * math.sin(now * 25)
				flash(entry, Color3.fromRGB(255, 40, 30), (if highContrast then 0.05 else 0.35) + pulse * 0.25, 0.05)
			end
			if entry.flash and entry.flash.Enabled and now > entry.flashUntil then
				entry.flash.Enabled = false
			end
			if checkBars and not entry.deadAt then
				local hurt = (model:GetAttribute("HP") or 0) < (model:GetAttribute("MaxHP") or 0)
				local near = myRoot ~= nil and (myRoot.Position - position).Magnitude <= BAR_RANGE + entry.root.Size.X / 2
				entry.gui.Enabled = hurt or near or entry.def.Tier ~= "normal"
			end
		end
	end)
end

return EnemyController
