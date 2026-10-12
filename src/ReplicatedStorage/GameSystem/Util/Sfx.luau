--!strict
-- Plays sounds by name (DESIGN.md section 10) and routes every sound to its SoundGroup
-- (Config/Audio): Master > Music, PlayerFX, EnemyFX, UI, Ambient. Sounds live in
-- ReplicatedStorage.Assets.Sounds (any sub-folder). Unknown names are ignored silently.
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Audio = require(ReplicatedStorage.GameSystem.Config.Audio)
local Combat = require(ReplicatedStorage.GameSystem.Config.Combat)
local CombatSfx = require(ReplicatedStorage.GameSystem.Config.CombatSfx)

local Sfx = {}

local cache: { [string]: Sound | false } = {}
local groups: { [string]: SoundGroup } = {}

-- The SoundGroup of that name, created on first use (client side).
function Sfx.group(name: string): SoundGroup
	local group = groups[name]
	if group and group.Parent then
		return group
	end
	local master = SoundService:FindFirstChild(Audio.MASTER) :: SoundGroup?
	if not master then
		master = Instance.new("SoundGroup")
		master.Name = Audio.MASTER
		master.Parent = SoundService
	end
	if name == Audio.MASTER then
		groups[name] = master :: SoundGroup
		return master :: SoundGroup
	end
	local child = (master :: SoundGroup):FindFirstChild(name) :: SoundGroup?
	if not child then
		child = Instance.new("SoundGroup")
		child.Name = name
		child.Parent = master
	end
	groups[name] = child :: SoundGroup
	return child :: SoundGroup
end

function Sfx.groupOf(soundName: string): string
	return Audio.GroupOfSound[soundName] or Audio.DefaultGroup
end

function Sfx.find(name: string): Sound?
	local cached = cache[name]
	if cached == nil then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local sounds = assets and assets:FindFirstChild("Sounds")
		local found = sounds and sounds:FindFirstChild(name, true)
		cached = if found and found:IsA("Sound") then found else false
		cache[name] = cached
	end
	return cached or nil
end

-- Plays a sound once. With a position the sound is 3D, otherwise it is heard at full volume.
function Sfx.play(name: string, position: Vector3?)
	local source = Sfx.find(name)
	if not source then
		return
	end
	local sound = source:Clone()
	sound.Looped = false
	sound.SoundGroup = Sfx.group(Sfx.groupOf(name))
	local lifetime = math.max(sound.TimeLength, 1) + 1
	if position then
		local anchor = Instance.new("Attachment")
		anchor.WorldPosition = position
		anchor.Parent = workspace.Terrain
		sound.Parent = anchor
		Debris:AddItem(anchor, lifetime)
	else
		sound.Parent = SoundService
		Debris:AddItem(sound, lifetime)
	end
	sound:Play()
end

-- ------------------------------------------------------------------------------------------------
-- Combat sounds (docs/weapons_combat_brief.txt 4D, contract in docs/COMBAT_CONTRACTS.md). OWNER: the SFX sub-agent
-- (this section, Config/CombatSfx, the sounds in ReplicatedStorage.Assets.Sounds.Combat). CombatController calls only:
--   Sfx.combat(event, ctx?)   event = "Swing" | "Impact" | "Shot" | "Cast" | "Burst" | "Roll" | "Block" | "BlockHit"
--                             | "BlockBreak" | "Hurt" | "Death" | "Equip"
--                             ctx = { Category?, Step?, Finisher?, Crit?, Material? ("flesh" | "metal" | "stone"),
--                                     Speed? (Swing), IsLocal?, Position? (3D sound there; nil = heard at full volume) }
-- Config/CombatSfx maps event / category / step to sets of variants (no variant twice in a row, pitch +-5 %), times
-- the Swing whoosh to the step's hit, layers crit / finisher sounds. The Sound copies are pooled (no Clone once
-- warm), at most CombatSfx.Cap play at once (a new one stops the oldest), each one leaves SoundService / the
-- workspace when it has faded. Every sound goes through its Config/Audio group (PlayerFX). Unknown events and
-- missing sounds are ignored silently. Client only.
-- Dev hook (Play, Client command bar): SoundService:SetAttribute("CombatSfxDebug", true) -> every combat sound
-- appends "time event name pitch volume delay skip 2D|3D" to the SoundService attribute "CombatSfxLog" (last 40) and
-- writes the count playing to "CombatSfxActive".
-- ------------------------------------------------------------------------------------------------
type Variant = { Name: string, Peak: number, Length: number, Start: number? }
type Voice = { sound: Sound?, name: string, anchor: Attachment?, serial: number }

local IS_CLIENT = RunService:IsClient()
local SETS = CombatSfx.Sets
local rng = Random.new()

local active: { Voice } = {} -- playing, oldest first
local spareVoices: { Voice } = {}
local idle: { [string]: { Sound } } = {} -- pooled copies per sound name
local anchors: { Attachment } = {} -- pooled 3D anchors
local baseVolume: { [string]: number } = {}
local lastVariant: { [string]: number } = {}
local stackAt: { [string]: number } = {}
local stackCount: { [string]: number } = {}
local created = 0 -- copies cloned since start (Sfx.combatStats)

local function debugLog(text: string)
	local log = SoundService:GetAttribute("CombatSfxLog")
	local lines = if typeof(log) == "string" and log ~= "" then string.split(log, "\n") else {}
	table.insert(lines, text)
	while #lines > 40 do
		table.remove(lines, 1)
	end
	SoundService:SetAttribute("CombatSfxLog", table.concat(lines, "\n"))
end

local function newCopy(name: string): Sound?
	local source = Sfx.find(name)
	if not source then
		return nil
	end
	if not baseVolume[name] then
		baseVolume[name] = source.Volume
	end
	local sound = source:Clone()
	sound.Looped = false
	sound.PlayOnRemove = false
	sound.SoundGroup = Sfx.group(Sfx.groupOf(name))
	created += 1
	return sound
end

local function acquire(name: string): Sound?
	local list = idle[name]
	local n = if list then #list else 0
	if list and n > 0 then
		local sound = list[n]
		list[n] = nil
		return sound
	end
	return newCopy(name)
end

local function release(voice: Voice)
	local index = table.find(active, voice)
	if index then
		table.remove(active, index)
	end
	voice.serial += 1
	local sound = voice.sound
	voice.sound = nil
	if sound then
		sound:Stop()
		sound.Parent = nil
		local list = idle[voice.name]
		if not list then
			list = {}
			idle[voice.name] = list
		end
		if #list < CombatSfx.PoolMax then
			table.insert(list, sound)
		else
			sound:Destroy()
		end
	end
	local anchor = voice.anchor
	voice.anchor = nil
	if anchor then
		anchor.Parent = nil
		table.insert(anchors, anchor)
	end
	table.insert(spareVoices, voice)
	if SoundService:GetAttribute("CombatSfxDebug") == true then
		SoundService:SetAttribute("CombatSfxActive", #active)
	end
end

local function expire(voice: Voice, serial: number)
	if voice.serial == serial then
		release(voice)
	end
end

-- One variant, now. volume / pitch already include the spec's multipliers and the random pitch; extra = seconds of
-- the file skipped on top of the variant's Start (a whoosh that would peak too late for a fast hit).
local function start(variant: Variant, setName: string, volume: number, pitch: number, position: Vector3?, event: string, delay: number, extra: number)
	local now = os.clock()
	local at = stackAt[setName]
	if at and now - at < CombatSfx.StackWindow then
		local n = (stackCount[setName] or 0) + 1
		if n > (CombatSfx.StackMaxOf[setName] or CombatSfx.StackMax) then
			return
		end
		stackCount[setName] = n
	else
		stackAt[setName] = now
		stackCount[setName] = 1
	end
	local name = variant.Name
	local sound = acquire(name)
	if not sound then
		return
	end
	while #active >= CombatSfx.Cap do
		release(active[1])
	end
	local voice = table.remove(spareVoices) or { sound = nil, name = name, anchor = nil, serial = 0 }
	voice.sound = sound
	voice.name = name
	sound.Volume = (baseVolume[name] or sound.Volume) * volume
	sound.PlaybackSpeed = pitch
	local skip = (variant.Start or 0) + extra
	sound.TimePosition = skip
	if position then
		local anchor = table.remove(anchors)
		if not anchor then
			anchor = Instance.new("Attachment")
			anchor.Name = "CombatSfx"
		end
		anchor.Position = position -- Terrain sits at the origin: local = world
		anchor.Parent = workspace.Terrain
		voice.anchor = anchor
		sound.Parent = anchor
	else
		sound.Parent = SoundService
	end
	sound:Play()
	table.insert(active, voice)
	local length = if variant.Length and variant.Length > 0 then variant.Length else math.max(sound.TimeLength, 1)
	task.delay(math.max(0.05, (length - skip) / pitch), expire, voice, voice.serial)
	if SoundService:GetAttribute("CombatSfxDebug") == true then
		SoundService:SetAttribute("CombatSfxActive", #active)
		debugLog(string.format("%.3f %s %s p=%.3f v=%.2f d=%.3f s=%.3f %s", now, event, name, pitch, sound.Volume, delay, skip, if position then "3D" else "2D"))
	end
end

-- A variant of the set, never the one played last time (per set).
local function pick(setName: string, set: { Variant }): Variant
	local n = #set
	if n <= 1 then
		return set[1]
	end
	local last = lastVariant[setName]
	local i
	if last then
		i = rng:NextInteger(1, n - 1)
		if i >= last then
			i += 1
		end
	else
		i = rng:NextInteger(1, n)
	end
	lastVariant[setName] = i
	return set[i]
end

-- Plays a spec (and its layers). hitIn = seconds until the hit (Swing): the variant's Peak lands HitLead before it
-- (delayed, or with the start of the file skipped when the hit comes sooner than the peak; 0.05 s stay before it).
local function playSpec(spec: { [string]: any }, volume: number, pitch: number, position: Vector3?, hitIn: number?, event: string)
	local setName = spec.Set
	local set = if typeof(setName) == "string" then SETS[setName] else nil
	if set and #set > 0 then
		local variant = pick(setName, set)
		local p = pitch * (spec.Pitch or 1) * (1 + rng:NextNumber(-CombatSfx.PitchRange, CombatSfx.PitchRange))
		local v = volume * (spec.Volume or 1)
		local delay, extra = 0, 0
		if hitIn then
			local toPeak = variant.Peak - (variant.Start or 0)
			local lead = hitIn - CombatSfx.HitLead - toPeak / p
			if lead >= 0 then
				delay = lead
			else
				extra = math.min(-lead * p, math.max(0, toPeak - 0.05))
			end
		end
		if delay > 0.01 then
			task.delay(delay, start, variant, setName, v, p, position, event, delay, extra)
		else
			start(variant, setName, v, p, position, event, 0, extra)
		end
	end
	local also = spec.Also
	if typeof(also) == "table" then
		for _, layer in ipairs(also) do
			playSpec(layer, volume, pitch, position, hitIn, event)
		end
	end
end

local function inRange(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return not camera or (camera.CFrame.Position - position).Magnitude <= CombatSfx.Range
end

function Sfx.combat(event: string, ctx: { [string]: any }?)
	if not IS_CLIENT or typeof(event) ~= "string" then
		return
	end
	local info = ctx or {}
	local position: Vector3? = nil
	if info.IsLocal ~= true and typeof(info.Position) == "Vector3" then
		position = info.Position
		if not inRange(info.Position) then
			return
		end
	end
	local volume = if position then CombatSfx.RemoteVolume else 1
	local categoryId = if typeof(info.Category) == "string" then info.Category else CombatSfx.DefaultCategory
	local category = CombatSfx.Categories[categoryId] or CombatSfx.Categories[CombatSfx.DefaultCategory]
	local entry = (category and category[event]) or CombatSfx.Shared[event]
	if typeof(entry) ~= "table" then
		return
	end
	if event == "Swing" then
		local spec = entry.Finisher
		if info.Finisher ~= true or not spec then
			local steps = entry.Steps
			local step = if typeof(info.Step) == "number" then math.max(1, math.floor(info.Step)) else 1
			spec = steps and steps[(step - 1) % #steps + 1]
		end
		if spec then
			local combo = Combat.Combos[categoryId] or Combat.Combos[CombatSfx.DefaultCategory]
			local def = combo and (combo[if typeof(info.Step) == "number" then info.Step else 1] or combo[1])
			local speed = if typeof(info.Speed) == "number" and info.Speed > 0 then info.Speed else 1
			local impact = if def and typeof(def.Impact) == "number" then def.Impact else 0.15
			playSpec(spec, volume, 1, position, impact / speed, event)
		end
	elseif event == "Impact" then
		local materials = entry.Materials or {}
		local material = if typeof(info.Material) == "string" then info.Material else CombatSfx.DefaultMaterial
		local spec = materials[material] or materials[CombatSfx.DefaultMaterial]
		local pitch = 1
		local finisher = if info.Finisher == true then entry.Finisher else nil
		if finisher then
			volume *= finisher.Volume or 1
			pitch = finisher.Pitch or 1
			if finisher.Also then
				for _, layer in ipairs(finisher.Also) do
					playSpec(layer, volume, 1, position, nil, event)
				end
			end
		end
		if spec then
			playSpec(spec, volume, pitch, position, nil, event)
		end
		if info.Crit == true and entry.Crit then
			playSpec(entry.Crit, if position then CombatSfx.RemoteVolume else 1, 1, position, nil, event)
		end
	else
		playSpec(entry, volume, 1, position, nil, event)
	end
end

-- Counts for tests: playing now, idle pooled copies, copies cloned since start.
function Sfx.combatStats(): { [string]: number }
	local pooled = 0
	for _, list in pairs(idle) do
		pooled += #list
	end
	return { Active = #active, Pooled = pooled, Created = created, Anchors = #anchors }
end

-- Client start: load every combat sound, then warm the pool (the first swing must not wait for a download).
if IS_CLIENT and RunService:IsRunning() then
	task.defer(function()
		local assets = ReplicatedStorage:WaitForChild("Assets", 30)
		local sounds = assets and assets:WaitForChild("Sounds", 30)
		local folder = sounds and sounds:WaitForChild("Combat", 30)
		if not folder then
			return
		end
		local list = {}
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Sound") then
				table.insert(list, child)
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
		for _, source in ipairs(list) do
			local pool = idle[source.Name]
			if not pool then
				pool = {}
				idle[source.Name] = pool
			end
			while #pool < CombatSfx.Prewarm do
				local copy = newCopy(source.Name)
				if not copy then
					break
				end
				table.insert(pool, copy)
			end
		end
	end)
end

return Sfx
