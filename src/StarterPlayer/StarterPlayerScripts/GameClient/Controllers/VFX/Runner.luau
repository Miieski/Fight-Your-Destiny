--!strict
-- VFX core (docs/COMBAT_CONTRACTS.md; OWNER: the VFX sub-agent): the pool of clones of ReplicatedStorage.Assets.VFX
-- and the one per-frame runner that animates every active effect. One record table per clone, made once and reused:
-- no Instance.new / Destroy per hit and no table allocation per frame.
--   Runner.acquire(name) -> fx?      a parked clone record (nil at the global cap Config.MaxActive, at the asset's
--                                    pool max, or when the asset is missing). Always pass it to run() or release().
--   Runner.run(fx, delay, life, begin?, step?)
--                                    begin(fx) once at now + delay (delay <= 0: at once; return false to abort),
--                                    then step(fx, t) every frame (t = seconds since begin; return false to end)
--                                    until life is over; then fx.done(fx) if set, and a clone is parked (Parent nil).
--                                    Calling it again on a running record restarts it.
--   Runner.track(record)             makes a non-pooled record runnable (weapon trails, damage numbers, ghosts)
--   Runner.onMake(fn)                fn(fx) runs once for every new clone (prewarm included): per-clone setup
--   Runner.emit(fx, factor?)         Emit every ParticleEmitter of the clone (Config.Emit counts x factor x Low FX)
--   Runner.tint(fx, color?)          recolor the Config.Tint emitters (nil = their own color)
--   Runner.sequence(color)           cached ColorSequence of one color
--   Runner.template(name)            the asset under ReplicatedStorage.Assets.VFX (or nil)
--   Runner.near(position)  Runner.ground(position, up?, depth?)  Runner.folder()  Runner.lowFx()  Runner.measure(t0)
-- Dev hooks (Play, Client command bar), attributes set locally on workspace.VFX:
--   Freeze = true          pauses every effect (particles too) for a screenshot; false resumes
--   LowFx = true           behaves as if the Low FX setting were on (test without the settings window)
--   Profile = os.clock()   -> CostMs (average ms per frame of the runner + the VFX calls since the previous request),
--                             MaxMs (worst frame), Active, Peak, Clones, Frames, Emitted (particles emitted)
--                             (read them a frame later: attribute signals are deferred)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.GameSystem.Config.CombatVFX)
local Settings = require(script.Parent.Parent.SettingsController)

local Runner = {}

export type Fx = { [string]: any }

local templates: { [string]: Instance | false } = {}
local free: { [string]: { Fx } } = {}
local made: { [string]: number } = {}
local active: { Fx } = {}
local count = 0 -- records in active
local capped = 0 -- of them, the ones that count toward Config.MaxActive
local clock = 0
local timeScale = 1
local folder: Instance? = nil
local cost, frames, peak, clones = 0, 0, 0, 0
local frameCost, maxFrame, emitted = 0, 0, 0
local seqCache: { [number]: ColorSequence } = {}
local devLow = false
local makeHooks: { (Fx) -> () } = {}

function Runner.now(): number
	return clock
end

function Runner.lowFx(): boolean
	return devLow or Settings.get("LowFx") == true
end

function Runner.measure(started: number)
	local dt = os.clock() - started
	cost += dt
	frameCost += dt
end

-- workspace.VFX: the one folder of active effects (the place's folder when it exists, else a client-side one)
function Runner.folder(): Instance
	local f = folder
	if f and f.Parent == workspace then
		return f
	end
	local found = workspace:FindFirstChild("VFX")
	if not found then
		found = Instance.new("Folder")
		found.Name = "VFX"
		found.Parent = workspace
	end
	folder = found
	return found :: Instance
end

function Runner.template(name: string): Instance?
	local t = templates[name]
	if t == nil then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local vfx = assets and assets:FindFirstChild("VFX")
		local found = vfx and vfx:FindFirstChild(name)
		t = found or false
		templates[name] = t
		if not found then
			warn(`VFX: asset ReplicatedStorage.Assets.VFX.{name} is missing`)
		end
	end
	return if t then t else nil
end

function Runner.sequence(color: Color3): ColorSequence
	local key = math.floor(color.R * 255 + 0.5) * 65536 + math.floor(color.G * 255 + 0.5) * 256 + math.floor(color.B * 255 + 0.5)
	local s = seqCache[key]
	if not s then
		s = ColorSequence.new(color)
		seqCache[key] = s
	end
	return s
end

local function make(name: string): Fx?
	local source = Runner.template(name)
	if not source then
		return nil
	end
	local inst = source:Clone()
	local part: BasePart? = nil
	if inst:IsA("BasePart") then
		part = inst
	elseif inst:IsA("Model") then
		part = inst.PrimaryPart
	end
	local counts = Config.Emit[name]
	local tints = Config.Tint[name]
	local fx: Fx = {
		name = name, inst = inst, part = part, child = {}, emitters = {}, counts = {}, tinted = {}, baseColors = {},
		pooled = true, capped = true, slot = 0, begun = false, startAt = 0, endAt = 0, begin = false, step = false,
		done = false, particleLife = 0, tintColor = false,
	}
	local longest = 0
	for _, d in ipairs(inst:GetDescendants()) do
		fx.child[d.Name] = d
		if d:IsA("ParticleEmitter") then
			table.insert(fx.emitters, d)
			local n = counts and counts[d.Name] or d:GetAttribute("EmitCount")
			table.insert(fx.counts, if typeof(n) == "number" then n else 4)
			if tints and tints[d.Name] then
				table.insert(fx.tinted, d)
				table.insert(fx.baseColors, d.Color)
			end
			longest = math.max(longest, d.Lifetime.Max)
		end
	end
	fx.particleLife = longest
	made[name] = (made[name] or 0) + 1
	clones += 1
	for _, hook in ipairs(makeHooks) do
		hook(fx)
	end
	return fx
end

function Runner.onMake(fn: (Fx) -> ())
	table.insert(makeHooks, fn)
end

local function park(fx: Fx)
	fx.inst.Parent = nil
	local list = free[fx.name]
	if not list then
		list = {}
		free[fx.name] = list
	end
	list[#list + 1] = fx
end

function Runner.acquire(name: string): Fx?
	if capped >= Config.MaxActive then
		return nil
	end
	local list = free[name]
	if list then
		local n = #list
		if n > 0 then
			local fx = list[n]
			list[n] = nil
			return fx
		end
	end
	if (made[name] or 0) >= (Config.Pool.Max[name] or Config.Pool.DefaultMax) then
		return nil
	end
	return make(name)
end

-- An acquired clone that will not be run after all.
function Runner.release(fx: Fx)
	if fx.slot == 0 and fx.pooled then
		park(fx)
	end
end

function Runner.track(record: Fx): Fx
	record.pooled = false
	record.capped = record.capped == true
	record.slot = 0
	record.begun = false
	record.startAt = 0
	record.endAt = 0
	record.begin = record.begin or false
	record.step = record.step or false
	record.done = record.done or false
	return record
end

local function finish(fx: Fx)
	local i = fx.slot
	local last = active[count]
	active[i] = last
	last.slot = i
	active[count] = nil
	count -= 1
	fx.slot = 0
	if fx.capped then
		capped -= 1
	end
	if fx.done then
		local ok, err = pcall(fx.done, fx)
		if not ok then
			warn("VFX done: " .. tostring(err))
		end
	end
	if fx.pooled then
		park(fx)
	end
end

local function start(fx: Fx): boolean
	fx.begun = true
	if fx.pooled then
		fx.inst.Parent = Runner.folder()
		if timeScale == 0 then
			for _, e in ipairs(fx.emitters) do
				e.TimeScale = 0
			end
		end
	end
	if fx.begin then
		local ok, result = pcall(fx.begin, fx)
		if not ok then
			warn("VFX begin: " .. tostring(result))
			return false
		end
		return result ~= false
	end
	return true
end

function Runner.run(fx: Fx, delay: number, life: number, begin: any?, step: any?)
	fx.startAt = clock + math.max(0, delay)
	fx.endAt = fx.startAt + math.max(0, life)
	fx.begun = false
	fx.begin = begin or false
	fx.step = step or false
	if fx.slot == 0 then
		count += 1
		active[count] = fx
		fx.slot = count
		if fx.capped then
			capped += 1
		end
		if count > peak then
			peak = count
		end
	end
	if delay <= 0 and not start(fx) then
		finish(fx)
	end
end

-- Ends a running record now (its done() runs).
function Runner.stop(fx: Fx)
	if fx.slot ~= 0 then
		finish(fx)
	end
end

function Runner.emit(fx: Fx, factor: number?)
	local k = (factor or 1) * (if devLow or Settings.get("LowFx") == true then Config.LowFx.EmitFactor else 1)
	local emitters, counts = fx.emitters, fx.counts
	for i = 1, #emitters do
		local n = counts[i] * k
		if n > 0 then
			local m = math.max(1, math.floor(n + 0.5))
			emitters[i]:Emit(m)
			emitted += m
		end
	end
end

function Runner.tint(fx: Fx, color: Color3?)
	if fx.tintColor == (color or false) then
		return
	end
	fx.tintColor = color or false
	local tinted = fx.tinted
	for i = 1, #tinted do
		tinted[i].Color = if color then Runner.sequence(color) else fx.baseColors[i]
	end
end

function Runner.near(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	if not camera then
		return true
	end
	return (camera.CFrame.Position - position).Magnitude <= Config.CullDistance
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
params.RespectCanCollide = true
local filterAt = -math.huge

-- Ground point below position (characters, enemies and effects ignored), or nil.
function Runner.ground(position: Vector3, up: number?, depth: number?): Vector3?
	local now = os.clock()
	if now - filterAt > 2 then
		filterAt = now
		local list: { Instance } = { Runner.folder() }
		local enemies = workspace:FindFirstChild("Enemies")
		if enemies then
			table.insert(list, enemies)
		end
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				table.insert(list, player.Character)
			end
		end
		params.FilterDescendantsInstances = list
	end
	local top = up or 1
	local result = workspace:Raycast(position + Vector3.new(0, top, 0), Vector3.new(0, -(top + (depth or 10)), 0), params)
	return if result then result.Position else nil
end

local function update(dt: number)
	local started = os.clock()
	clock += dt * timeScale
	local now = clock
	local i = 1
	while i <= count do
		local fx = active[i]
		local alive = true
		if not fx.begun and now >= fx.startAt then
			alive = start(fx)
		end
		if alive and fx.begun then
			if now >= fx.endAt then
				alive = false
			elseif fx.step then
				local ok, result = pcall(fx.step, fx, now - fx.startAt)
				if not ok then
					warn("VFX step: " .. tostring(result))
					alive = false
				else
					alive = result ~= false
				end
			end
		end
		if alive then
			i += 1
		else
			finish(fx)
		end
	end
	local spent = os.clock() - started
	cost += spent
	frameCost += spent
	if frameCost > maxFrame then
		maxFrame = frameCost
	end
	frameCost = 0
	frames += 1
end

local function setFreeze(on: boolean)
	timeScale = if on then 0 else 1
	for i = 1, count do
		local fx = active[i]
		if fx.emitters then
			for _, e in ipairs(fx.emitters) do
				e.TimeScale = timeScale
			end
		end
	end
end

-- Clones made up front (a few per frame).
function Runner.prewarm()
	for name, n in pairs(Config.Pool.Prewarm) do
		local list = free[name]
		if not list then
			list = {}
			free[name] = list
		end
		for _ = #list + 1, n do
			local fx = make(name)
			if not fx then
				break
			end
			list[#list + 1] = fx
		end
		task.wait()
	end
end

function Runner.start()
	RunService.PreRender:Connect(update)
	local f = Runner.folder()
	f:GetAttributeChangedSignal("Freeze"):Connect(function()
		setFreeze(f:GetAttribute("Freeze") == true)
	end)
	f:GetAttributeChangedSignal("LowFx"):Connect(function()
		devLow = f:GetAttribute("LowFx") == true
	end)
	f:GetAttributeChangedSignal("Profile"):Connect(function()
		f:SetAttribute("CostMs", if frames > 0 then cost / frames * 1000 else 0)
		f:SetAttribute("Active", count)
		f:SetAttribute("Peak", peak)
		f:SetAttribute("Clones", clones)
		f:SetAttribute("Frames", frames)
		f:SetAttribute("MaxMs", maxFrame * 1000)
		f:SetAttribute("Emitted", emitted)
		cost, frames, peak, maxFrame, emitted = 0, 0, count, 0, 0
	end)
	task.spawn(Runner.prewarm)
end

return Runner
