--!strict
-- Client-side effects of the upgraded map props (docs/model_upgrade_brief.txt section 7, Config/PropFX).
-- Tracks the models tagged "MapProp" whose MapPropId has Flicker / Emitters / Sway in Config/PropFX. CHECK_HZ times a
-- second it switches a prop on when the local character is within NEAR studs and off beyond FAR. On: its parts sway
-- (one looping tween each, created once), its lights flicker, its emitters run (only the MAX_EMITTER_PROPS nearest
-- props). Low FX: no particles, sway or flicker; the static lights stay. Far props cost nothing; the per-frame loop
-- only writes light brightness numbers and runs only while a flickering prop is on (no per-frame allocation).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.GameSystem.Config.PropFX)
local Settings = require(script.Parent.SettingsController)

local PropFXController = { Priority = 60 }

local TAG = "MapProp"
local EMITTER_CLASSES = { "ParticleEmitter", "Beam", "Fire", "Smoke", "Sparkles" }

type FlickerLight = { light: Light, base: number, amount: number, speed: number, phase: number }
type Swayer = { part: BasePart, home: CFrame, from: CFrame, tween: Tween }
type Prop = {
	model: Model,
	config: Config.Entry,
	position: Vector3,
	distance: number,
	active: boolean,
	flicker: { FlickerLight },
	emitters: { Instance },
	sways: { Swayer },
	emitting: boolean,
}

local props: { [Model]: Prop } = {}
local list: { Prop } = {}
local flickering: { FlickerLight } = {}
local baseBrightness: { [Light]: number } = setmetatable({}, { __mode = "k" }) :: any
local homeOf: { [BasePart]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local low = false
local heartbeat: RBXScriptConnection? = nil
local rng = Random.new()

local function isEmitter(inst: Instance): boolean
	for _, className in ipairs(EMITTER_CLASSES) do
		if inst:IsA(className) then
			return true
		end
	end
	return false
end

local function partsNamed(model: Model, name: string): { BasePart }
	local found = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d.Name == name and d:IsA("BasePart") then
			table.insert(found, d)
		end
	end
	return found
end

local function setEmitters(prop: Prop, on: boolean)
	if prop.emitting == on then
		return
	end
	prop.emitting = on
	for _, emitter in ipairs(prop.emitters) do
		(emitter :: any).Enabled = on
	end
end

-- (re)reads the prop's lights, emitters and swaying parts (on activation only: streamed parts may arrive late)
local function scan(prop: Prop)
	local config = prop.config
	table.clear(prop.flicker)
	table.clear(prop.emitters)
	for _, spec in ipairs(config.Flicker or {}) do
		for _, part in ipairs(partsNamed(prop.model, spec.Part)) do
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("Light") then
					local base = baseBrightness[child] or child.Brightness
					baseBrightness[child] = base
					table.insert(prop.flicker, { light = child, base = base, amount = spec.Amount, speed = 2 * math.pi * spec.Hz, phase = rng:NextNumber(0, 2 * math.pi) })
				end
			end
		end
	end
	for _, name in ipairs(config.Emitters or {}) do
		for _, part in ipairs(partsNamed(prop.model, name)) do
			for _, d in ipairs(part:GetDescendants()) do
				if isEmitter(d) then
					table.insert(prop.emitters, d)
				end
			end
		end
	end
	prop.emitting = true
	setEmitters(prop, false)
	if #prop.sways == 0 then
		for _, spec in ipairs(config.Sway or {}) do
			for _, part in ipairs(partsNamed(prop.model, spec.Part)) do
				local home = homeOf[part] or part.CFrame
				homeOf[part] = home
				local angle = math.rad(spec.Degrees)
				local axis = if spec.Axis == "X" then Vector3.xAxis else Vector3.zAxis
				-- Hinge "Top": turn around the top edge (cloth hanging from a bar), else around the centre
				local hinge = if spec.Hinge == "Top" then CFrame.new(0, part.Size.Y / 2, 0) else CFrame.identity
				local function turned(a: number): CFrame
					return home * hinge * CFrame.fromAxisAngle(axis, a) * hinge:Inverse()
				end
				local info = TweenInfo.new(spec.Seconds / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
				local tween = TweenService:Create(part, info, { CFrame = turned(angle) })
				table.insert(prop.sways, { part = part, home = home, from = turned(-angle), tween = tween })
			end
		end
	end
end

local function onHeartbeat()
	local t = os.clock()
	for _, f in ipairs(flickering) do
		local wave = 0.6 * math.sin(t * f.speed + f.phase) + 0.4 * math.sin(t * f.speed * 1.63 + f.phase * 2.1)
		f.light.Brightness = f.base * (1 + f.amount * wave)
	end
end

-- the flicker list = the lights of the active props (rebuilt when a prop turns on or off, or Low FX changes)
local function rebuildFlicker()
	for _, f in ipairs(flickering) do
		f.light.Brightness = f.base
	end
	table.clear(flickering)
	if not low then
		for _, prop in ipairs(list) do
			if prop.active then
				for _, f in ipairs(prop.flicker) do
					table.insert(flickering, f)
				end
			end
		end
	end
	if #flickering > 0 and not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(onHeartbeat)
	elseif #flickering == 0 and heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local function setSway(prop: Prop, on: boolean)
	for _, s in ipairs(prop.sways) do
		s.tween:Cancel()
		if on then
			s.part.CFrame = s.from
			s.tween:Play()
		else
			s.part.CFrame = s.home
		end
	end
end

local function setActive(prop: Prop, on: boolean)
	if prop.active == on then
		return
	end
	prop.active = on
	if on then
		scan(prop)
	else
		setEmitters(prop, false)
	end
	setSway(prop, on and not low)
end

local function add(inst: Instance)
	if not inst:IsA("Model") or props[inst] then
		return
	end
	local id = inst:GetAttribute("MapPropId")
	local config = if type(id) == "string" then Config.Props[id] else nil
	if not config or not (config.Flicker or config.Emitters or config.Sway) then
		return -- no client effect for this prop
	end
	local prop: Prop = {
		model = inst, config = config, position = inst:GetPivot().Position, distance = math.huge, active = false,
		flicker = {}, emitters = {}, sways = {}, emitting = false,
	}
	props[inst] = prop
	table.insert(list, prop)
end

local function remove(inst: Instance)
	local prop = props[inst :: Model]
	if not prop then
		return
	end
	setActive(prop, false)
	props[inst :: Model] = nil
	local index = table.find(list, prop)
	if index then
		table.remove(list, index)
	end
	rebuildFlicker()
end

local function focusPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character.PrimaryPart
	if root then
		return root.Position
	end
	local camera = workspace.CurrentCamera
	return camera and camera.Focus.Position
end

local byDistance = function(a: Prop, b: Prop): boolean
	return a.distance < b.distance
end
local withEmitters: { Prop } = {}

local function check()
	local focus = focusPosition()
	if not focus then
		return
	end
	local changed = false
	for _, prop in ipairs(list) do
		prop.distance = (prop.position - focus).Magnitude
		local want = if prop.active then prop.distance <= Config.FAR else prop.distance <= Config.NEAR
		if want ~= prop.active then
			setActive(prop, want)
			changed = true
		end
	end
	if changed then
		rebuildFlicker()
	end
	-- particles: only the nearest active props
	table.clear(withEmitters)
	for _, prop in ipairs(list) do
		if prop.active and #prop.emitters > 0 then
			table.insert(withEmitters, prop)
		end
	end
	table.sort(withEmitters, byDistance)
	for i, prop in ipairs(withEmitters) do
		setEmitters(prop, not low and i <= Config.MAX_EMITTER_PROPS)
	end
	-- debug counters for a Play check (client): workspace.CurrentCamera:GetAttributes()
	local camera = workspace.CurrentCamera
	if camera then
		local active, sways, emitting = 0, 0, 0
		for _, prop in ipairs(list) do
			if prop.active then
				active += 1
				if not low then
					sways += #prop.sways
				end
				if prop.emitting then
					emitting += 1
				end
			end
		end
		camera:SetAttribute("PropFX_Tracked", #list)
		camera:SetAttribute("PropFX_Active", active)
		camera:SetAttribute("PropFX_Flicker", #flickering)
		camera:SetAttribute("PropFX_Sway", sways)
		camera:SetAttribute("PropFX_Emitting", emitting)
		camera:SetAttribute("PropFX_LowFx", low)
	end
end

local function setLow(value: boolean)
	if value == low then
		return
	end
	low = value
	for _, prop in ipairs(list) do
		if prop.active then
			setSway(prop, not low)
			if low then
				setEmitters(prop, false)
			end
		end
	end
	rebuildFlicker()
	check()
end

function PropFXController:Start()
	low = Settings.get("LowFx") == true
	Settings.changed("LowFx", function(value)
		setLow(value == true)
	end)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
		task.defer(add, inst)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
		add(inst)
	end
	task.spawn(function()
		while true do
			check()
			task.wait(1 / Config.CHECK_HZ)
		end
	end)
end

return PropFXController
