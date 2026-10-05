--!strict
-- Enemies on the client (docs/enemies_npcs_pets_brief.txt Part B): HP bars, hit and telegraph flashes, the procedural
-- animation of the rigs, spawn fade-in, death fade and the kill reward pop. Nothing here decides anything: the server
-- (EnemyService) moves the enemies and sets their attributes (HP, MaxHP, State, Telegraph, AttackAt, HitAt, Dead).
-- Animation: every rig joint is a Motor6D named after its part (Body, Head, LegFL, ArmR, WingL, Seg2...); AnimPlayer
-- plays the family clips of Config/RigClips on them (the same clips the Blender files bake): locomotion from the speed,
-- attacks timed on the server telegraph, Hit, Death, Spawn, the boss Intro / Enrage. Imported Blender rigs use the
-- same joint names, so they animate the same way as the placeholders.
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
local AnimPlayer = require(script.Parent.AnimPlayer)

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

type Entry = {
	model: Model,
	root: BasePart,
	def: any,
	joints: { [string]: Motor6D },
	gui: BillboardGui,
	fill: Frame,
	hpLabel: TextLabel,
	anim: any,
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
		anim = AnimPlayer.new(model, def.Rig or "Biped", def.Height), flash = nil, flashUntil = 0, deadAt = nil, connections = {},
	}
	entries[model] = entry
	updateBar(entry)
	table.insert(entry.connections, model:GetAttributeChangedSignal("HP"):Connect(function()
		updateBar(entry)
	end))
	table.insert(entry.connections, model:GetAttributeChangedSignal("HitAt"):Connect(function()
		flash(entry, Color3.new(1, 1, 1), 0.35, 0.1)
		local current = entry.anim:ActionName()
		if not entry.deadAt and (current == nil or current == "Hit" or current == "Spawn") then
			entry.anim:Action("Hit")
		end
	end))
	table.insert(entry.connections, model:GetAttributeChangedSignal("Telegraph"):Connect(function()
		local at = model:GetAttribute("Telegraph")
		if typeof(at) == "number" and at > serverNow() and not entry.deadAt then
			entry.anim:Action(attackClip(entry), { impactAt = serverToClock(at) })
		end
	end))
	table.insert(entry.connections, model:GetAttributeChangedSignal("State"):Connect(function()
		if model:GetAttribute("State") == "Intro" then
			entry.anim:Action(if entry.anim:Has("Intro") then "Intro" else "Roar")
		end
	end))
	table.insert(entry.connections, model:GetAttributeChangedSignal("Enraged"):Connect(function()
		if model:GetAttribute("Enraged") and entry.anim:Has("Enrage") then
			entry.anim:Action("Enrage")
		end
	end))
	table.insert(entry.connections, model:GetAttributeChangedSignal("Dead"):Connect(function()
		if model:GetAttribute("Dead") and not entry.deadAt then
			entry.deadAt = os.clock()
			entry.gui.Enabled = false
			entry.anim:Action("Death", { hold = true })
			Sfx.play("EnemyDeath", root.Position)
		end
	end))
	-- spawn: pop in and fade in
	if model:GetAttribute("State") == "Intro" then
		entry.anim:Action(if entry.anim:Has("Intro") then "Intro" else "Roar")
	else
		entry.anim:Action("Spawn")
	end
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

local function serverToClock(serverTime: number): number
	return os.clock() + (serverTime - serverNow())
end

-- The attack clip for a telegraph: heavy -> Attack2, ranged -> Shoot, else Attack1 (when the rig has it).
local function attackClip(entry: Entry): string
	local anim = entry.anim
	if entry.model:GetAttribute("Heavy") and anim:Has("Attack2") then
		return "Attack2"
	elseif entry.def.AttackType == "ranged" and anim:Has("Shoot") then
		return "Shoot"
	end
	return "Attack1"
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
				local velocity = entry.root.AssemblyLinearVelocity
				local speed = if entry.deadAt then 0 else Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				entry.anim:SetLocomotion(speed, entry.def.WalkSpeed or 12)
				entry.anim:Update(dt)
				if entry.deadAt then
					setTransparency(model, math.clamp((now - entry.deadAt - 0.5) / 0.6, 0, 1))
				end
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
				-- boss room enemies use the top-of-screen bars (UI/BossRoom) instead
				entry.gui.Enabled = (hurt or near or entry.def.Tier ~= "normal") and not model:GetAttribute("ArenaKey")
			end
		end
	end)
end

return EnemyController
