--!strict
-- Client-side effects of the upgraded map props (docs/model_upgrade_brief.txt section 7, Config/PropFX).
-- Tracks the models tagged "MapProp" whose MapPropId has Flicker / Emitters / Sway / Spin / Scroll in Config/PropFX.
-- CHECK_HZ times a second it switches a prop on when the local character is within NEAR studs and off beyond FAR.
-- On: its parts sway / spin (looping tweens, created once), its lights flicker, its water textures scroll, and its
-- emitters run: at most MAX_EMITTERS emitters in total, given to the nearest props first. Low FX: no particles, sway,
-- spin, scroll or flicker; the static lights stay. Far props cost nothing; the per-frame loop only writes light
-- brightness and texture offset numbers and runs only while a flickering / scrolling prop is on (no per-frame
-- allocation).
-- StreamingEnabled: parts of a prop can stream out and come back as NEW instances (or arrive after the prop turned
-- on). Every VALIDATE_EVERY checks an active prop checks its references and the count of its effect parts, and
-- rebuilds what changed (old tweens cancelled).
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
type Scroller = { tex: Texture, u: number, v: number, su: number, sv: number, u0: number, v0: number }
-- a moving part: back at `home` when off; on: placed at `from`, then its looping tweens play
type Mover = { part: BasePart, home: CFrame, from: CFrame, tweens: { Tween } }
type Prop = {
	model: Model,
	config: Config.Entry,
	position: Vector3,
	distance: number,
	active: boolean,
	flicker: { FlickerLight },
	scrolls: { Scroller },
	emitters: { Instance },
	movers: { Mover },
	enabled: number, -- emitters switched on (the first `enabled` of `emitters`)
	expected: number, -- effect instances found by the last scan (flicker lights + textures + emitters + movers)
	tick: number, -- checks since the last validation
}

local props: { [Model]: Prop } = {}
local list: { Prop } = {}
local flickering: { FlickerLight } = {}
local scrolling: { Scroller } = {}
local baseBrightness: { [Light]: number } = setmetatable({}, { __mode = "k" }) :: any
local homeOf: { [BasePart]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local low = false
local heartbeat: RBXScriptConnection? = nil
local rng = Random.new()
local enabledTotal = 0

local function isEmitter(inst: Instance): boolean
	for _, className in ipairs(EMITTER_CLASSES) do
		if inst:IsA(className) then
			return true
		end
	end
	return false
end

-- the parts named `name`, or the Blender glow name `name`_Glow
local function partsNamed(model: Model, name: string): { BasePart }
	local found = {}
	local glow = name .. "_Glow"
	for _, d in ipairs(model:GetDescendants()) do
		if (d.Name == name or d.Name == glow) and d:IsA("BasePart") then
			table.insert(found, d)
		end
	end
	return found
end

-- the hosts of a Flicker spec: the parts named Part, or the attachments named Attachment
local function hostsOf(model: Model, spec: Config.Flicker): { Instance }
	if spec.Attachment then
		local found = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d.Name == spec.Attachment and d:IsA("Attachment") then
				table.insert(found, d)
			end
		end
		return found
	end
	return partsNamed(model, spec.Part or "") :: any
end

-- switches on the first n emitters of the prop and off the others (writes only what changes)
local function setEmitters(prop: Prop, n: number)
	if prop.enabled == n then
		return
	end
	prop.enabled = n
	for i, emitter in ipairs(prop.emitters) do
		local on = i <= n
		if (emitter :: any).Enabled ~= on then
			(emitter :: any).Enabled = on
		end
	end
end

local function addMover(prop: Prop, part: BasePart, from: CFrame, tweens: { Tween })
	table.insert(prop.movers, { part = part, home = homeOf[part], from = from, tweens = tweens })
end

-- the number of effect instances the prop's config finds in the model right now (same matching as scan)
local function countTargets(prop: Prop): number
	local config, model = prop.config, prop.model
	local n = 0
	for _, spec in ipairs(config.Flicker or {}) do
		for _, host in ipairs(hostsOf(model, spec)) do
			for _, child in ipairs(host:GetChildren()) do
				if child:IsA("Light") then
					n += 1
				end
			end
		end
	end
	for _, spec in ipairs(config.Scroll or {}) do
		for _, part in ipairs(partsNamed(model, spec.Part)) do
			for _, tex in ipairs(part:GetChildren()) do
				if tex:IsA("Texture") then
					n += 1
				end
			end
		end
	end
	for _, name in ipairs(config.Emitters or {}) do
		for _, part in ipairs(partsNamed(model, name)) do
			for _, d in ipairs(part:GetDescendants()) do
				if isEmitter(d) then
					n += 1
				end
			end
		end
	end
	for _, spec in ipairs(config.Sway or {}) do
		n += #partsNamed(model, spec.Part)
	end
	for _, spec in ipairs(config.Spin or {}) do
		n += #partsNamed(model, spec.Part)
	end
	return n
end

-- (re)reads the prop's lights, textures, emitters and moving parts (movers only when it has none)
local function scan(prop: Prop)
	local config = prop.config
	table.clear(prop.flicker)
	table.clear(prop.scrolls)
	table.clear(prop.emitters)
	for _, spec in ipairs(config.Flicker or {}) do
		for _, host in ipairs(hostsOf(prop.model, spec)) do
			for _, child in ipairs(host:GetChildren()) do
				if child:IsA("Light") then
					local base = baseBrightness[child] or child.Brightness
					baseBrightness[child] = base
					table.insert(prop.flicker, { light = child, base = base, amount = spec.Amount, speed = 2 * math.pi * spec.Hz, phase = rng:NextNumber(0, 2 * math.pi) })
				end
			end
		end
	end
	for _, spec in ipairs(config.Scroll or {}) do
		for _, part in ipairs(partsNamed(prop.model, spec.Part)) do
			for _, tex in ipairs(part:GetChildren()) do
				if tex:IsA("Texture") then
					table.insert(prop.scrolls, {
						tex = tex, u = spec.U or 0, v = spec.V or 0, su = math.max(tex.StudsPerTileU, 0.01), sv = math.max(tex.StudsPerTileV, 0.01),
						u0 = tex.OffsetStudsU, v0 = tex.OffsetStudsV,
					})
				end
			end
		end
	end
	for _, name in ipairs(config.Emitters or {}) do
		for _, part in ipairs(partsNamed(prop.model, name)) do
			for _, d in ipairs(part:GetDescendants()) do
				if isEmitter(d) then
					(d :: any).Enabled = false
					table.insert(prop.emitters, d)
				end
			end
		end
	end
	prop.enabled = 0
	if #prop.movers == 0 then
		for _, spec in ipairs(config.Sway or {}) do
			for _, part in ipairs(partsNamed(prop.model, spec.Part)) do
				local home = homeOf[part] or part.CFrame
				homeOf[part] = home
				local angle = math.rad(spec.Degrees)
				local axis = if spec.Axis == "X" then Vector3.xAxis else Vector3.zAxis
				-- Hinge "Top": around the top edge (cloth hanging from a bar); "Pivot": around the part's pivot (the
				-- hinge / hat / straw pivots of the Blender meshes); else around the centre
				local hinge = if spec.Hinge == "Top" then CFrame.new(0, part.Size.Y / 2, 0)
					elseif spec.Hinge == "Pivot" then CFrame.new(part.PivotOffset.Position)
					else CFrame.identity
				local function turned(a: number): CFrame
					return home * hinge * CFrame.fromAxisAngle(axis, a) * hinge:Inverse()
				end
				local info = TweenInfo.new(spec.Seconds / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
				addMover(prop, part, turned(-angle), { TweenService:Create(part, info, { CFrame = turned(angle) }) })
			end
		end
		-- Spin: one full turn of the Orientation (the Y component goes +360, so it really turns) and a float of the
		-- Position; the two tweens write different properties, so they run together
		for _, spec in ipairs(config.Spin or {}) do
			for _, part in ipairs(partsNamed(prop.model, spec.Part)) do
				local home = homeOf[part] or part.CFrame
				homeOf[part] = home
				local tweens = {}
				if spec.Seconds and spec.Seconds > 0 then
					local o = part.Orientation
					local info = TweenInfo.new(spec.Seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
					table.insert(tweens, TweenService:Create(part, info, { Orientation = o + Vector3.new(0, 360, 0) }))
				end
				local from = home
				if spec.Bob and spec.Bob > 0 then
					-- floats UP from its place and back (never below it: the diamond sits on its post)
					local info = TweenInfo.new((spec.BobSeconds or 3) / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
					table.insert(tweens, TweenService:Create(part, info, { Position = home.Position + Vector3.new(0, spec.Bob, 0) }))
				end
				addMover(prop, part, from, tweens)
			end
		end
	end
	prop.expected = #prop.flicker + #prop.scrolls + #prop.emitters + #prop.movers
end

-- are the prop's references still its parts, and is nothing new there? (allocates: called every VALIDATE_EVERY
-- checks per active prop, never per frame)
local function stillValid(prop: Prop): boolean
	local model = prop.model
	for _, f in ipairs(prop.flicker) do
		if not f.light:IsDescendantOf(model) then
			return false
		end
	end
	for _, s in ipairs(prop.scrolls) do
		if not s.tex:IsDescendantOf(model) then
			return false
		end
	end
	for _, e in ipairs(prop.emitters) do
		if not e:IsDescendantOf(model) then
			return false
		end
	end
	for _, m in ipairs(prop.movers) do
		if not m.part:IsDescendantOf(model) then
			return false
		end
	end
	return countTargets(prop) == prop.expected
end

local function onHeartbeat()
	local t = os.clock()
	for _, f in ipairs(flickering) do
		local wave = 0.6 * math.sin(t * f.speed + f.phase) + 0.4 * math.sin(t * f.speed * 1.63 + f.phase * 2.1)
		f.light.Brightness = f.base * (1 + f.amount * wave)
	end
	for _, s in ipairs(scrolling) do
		s.tex.OffsetStudsU = (s.u0 + t * s.u) % s.su
		s.tex.OffsetStudsV = (s.v0 + t * s.v) % s.sv
	end
end

-- the per-frame lists = the lights / textures of the active props (rebuilt when a prop turns on or off, is
-- rescanned, or Low FX changes)
local function rebuildLoop()
	for _, f in ipairs(flickering) do
		f.light.Brightness = f.base
	end
	table.clear(flickering)
	table.clear(scrolling)
	if not low then
		for _, prop in ipairs(list) do
			if prop.active then
				for _, f in ipairs(prop.flicker) do
					table.insert(flickering, f)
				end
				for _, s in ipairs(prop.scrolls) do
					table.insert(scrolling, s)
				end
			end
		end
	end
	local busy = #flickering > 0 or #scrolling > 0
	if busy and not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(onHeartbeat)
	elseif not busy and heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local function setMovers(prop: Prop, on: boolean)
	for _, m in ipairs(prop.movers) do
		for _, tween in ipairs(m.tweens) do
			tween:Cancel()
		end
		if on then
			m.part.CFrame = m.from
			for _, tween in ipairs(m.tweens) do
				tween:Play()
			end
		else
			m.part.CFrame = m.home
		end
	end
end

-- drops the movers (tweens cancelled and destroyed, the parts still there put home)
local function dropMovers(prop: Prop)
	for _, m in ipairs(prop.movers) do
		for _, tween in ipairs(m.tweens) do
			tween:Cancel()
			tween:Destroy()
		end
		if m.part:IsDescendantOf(prop.model) then
			m.part.CFrame = m.home
		end
	end
	table.clear(prop.movers)
end

-- rebuilds everything of an active prop from its current parts
local function rescan(prop: Prop)
	dropMovers(prop)
	scan(prop)
	setMovers(prop, prop.active and not low)
end

local function setActive(prop: Prop, on: boolean)
	if prop.active == on then
		return
	end
	prop.active = on
	prop.tick = 0
	if on then
		scan(prop)
		if not stillValid(prop) then
			-- movers kept from an earlier activation point at parts that streamed out (or new ones arrived)
			dropMovers(prop)
			scan(prop)
		end
	else
		setEmitters(prop, 0)
	end
	setMovers(prop, on and not low)
end

local function add(inst: Instance)
	if not inst:IsA("Model") or props[inst] then
		return
	end
	local id = inst:GetAttribute("MapPropId")
	local config = if type(id) == "string" then Config.Props[id] else nil
	if not config or not (config.Flicker or config.Emitters or config.Sway or config.Spin or config.Scroll) then
		return -- no client effect for this prop
	end
	local prop: Prop = {
		model = inst, config = config, position = inst:GetPivot().Position, distance = math.huge, active = false,
		flicker = {}, scrolls = {}, emitters = {}, movers = {}, enabled = 0, expected = 0, tick = 0,
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
	rebuildLoop()
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
		elseif prop.active then
			-- streaming: references that left the model, or effect parts that arrived late
			prop.tick += 1
			if prop.tick >= Config.VALIDATE_EVERY then
				prop.tick = 0
				if not stillValid(prop) then
					rescan(prop)
					changed = true
				end
			end
		end
	end
	if changed then
		rebuildLoop()
	end
	-- particles: at most MAX_EMITTERS emitters in total, the nearest active props first
	table.clear(withEmitters)
	for _, prop in ipairs(list) do
		if prop.active and #prop.emitters > 0 then
			table.insert(withEmitters, prop)
		end
	end
	table.sort(withEmitters, byDistance)
	local budget = if low then 0 else Config.MAX_EMITTERS
	enabledTotal = 0
	for _, prop in ipairs(withEmitters) do
		local n = math.min(#prop.emitters, budget)
		setEmitters(prop, n)
		budget -= n
		enabledTotal += n
	end
	-- debug counters for a Play check (client): workspace.CurrentCamera:GetAttributes()
	local camera = workspace.CurrentCamera
	if camera then
		local active, movers = 0, 0
		for _, prop in ipairs(list) do
			if prop.active then
				active += 1
				if not low then
					movers += #prop.movers
				end
			end
		end
		camera:SetAttribute("PropFX_Tracked", #list)
		camera:SetAttribute("PropFX_Active", active)
		camera:SetAttribute("PropFX_Flicker", #flickering)
		camera:SetAttribute("PropFX_Sway", movers)
		camera:SetAttribute("PropFX_Scroll", #scrolling)
		camera:SetAttribute("PropFX_Emitting", enabledTotal)
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
			setMovers(prop, not low)
			if low then
				setEmitters(prop, 0)
			end
		end
	end
	rebuildLoop()
	check()
end

function PropFXController:Start()
	-- Low FX = the setting, or (tests only, e.g. from the MCP Client datamodel) the LocalPlayer attribute
	-- PropFX_TestLowFx = true
	local player = Players.LocalPlayer
	local function wantLow(): boolean
		return Settings.get("LowFx") == true or player:GetAttribute("PropFX_TestLowFx") == true
	end
	low = wantLow()
	Settings.changed("LowFx", function()
		setLow(wantLow())
	end)
	player:GetAttributeChangedSignal("PropFX_TestLowFx"):Connect(function()
		setLow(wantLow())
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
