--!strict
-- Plays sounds by name (DESIGN.md section 10) and routes every sound to its SoundGroup
-- (Config/Audio): Master > Music, PlayerFX, EnemyFX, UI, Ambient. Sounds live in
-- ReplicatedStorage.Assets.Sounds (any sub-folder). Unknown names are ignored silently.
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Audio = require(ReplicatedStorage.GameSystem.Config.Audio)
local WeaponMoves = require(ReplicatedStorage.GameSystem.Config.WeaponMoves)
local CombatSfx = require(ReplicatedStorage.GameSystem.Config.CombatSfx)
local CombatStyles = require(ReplicatedStorage.GameSystem.Config.CombatStyles)
local CombatVFX = require(ReplicatedStorage.GameSystem.Config.CombatVFX) -- read only: the zone styles' beat timing

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
--   Sfx.combat(event, ctx?)   event = "Swing" | "Land" | "Impact" | "Shot" | "Cast" | "Burst" | "Roll" | "Block"
--                             | "BlockHit" | "BlockBreak" | "Hurt" | "Death" | "Equip"
--                             ctx = { Category?, Step?, Variant? (Swing: nil | "Air" jump attack | "Dash" dash strike),
--                                     Finisher?, Crit?, Material? ("flesh" | "metal" | "stone"), Speed?,
--                                     Tool? (Swing: the WeaponId picks bow / crossbow / gun / blowgun),
--                                     Character? (Swing: its Magic cast / Ranged release times the Burst / Shot),
--                                     Element? (Swing: Magic BlinkBlast's burst), Style? (Burst), Enemy? / Own? /
--                                     Shooter? (Shot), Rarity? (Equip), Radius? (Land), Zone? (1..12), IsLocal?,
--                                     Position? (3D sound there; nil = heard at full volume) }
--                             "Land" (combat V3) = a melee jump attack hits the ground (ctx as VFX.land)
-- Config/CombatSfx maps event / category / step / variant / weapon style / burst style to sets of variants (no variant
-- twice in a row, pitch +-5 %), times the Swing sounds to the step's hit, the Magic area burst to the cast's release +
-- the bolt's flight and another player's arrow whiz to its release (as Controllers/VFX draws them), layers crit /
-- finisher / rarity sounds. The Sound copies are pooled (no Clone once warm), at most CombatSfx.Cap play at once (a
-- new one stops the oldest), each one leaves SoundService / the workspace when it has faded. Every sound goes through
-- its Config/Audio group (PlayerFX; enemy launches EnemyFX, the rarity chime UI). Unknown events and missing sounds
-- are ignored silently. Client only.
-- Dev hook (Play, Client command bar): SoundService:SetAttribute("CombatSfxDebug", true) -> every combat sound
-- appends "time event name pitch volume delay skip 2D|3D" to the SoundService attribute "CombatSfxLog" (last 40) and
-- writes the count playing to "CombatSfxActive".
-- Zone fighting styles (2026-10-14): ctx.Zone (the weapon's zone, 1..12) on Swing / Impact / Land adds the zone's
-- accent layer (Config/CombatSfx Zones: a light layer on ordinary steps, finishers / dash strikes / jump attacks, the
-- signature beats timed as the animation's Style_<Zone> overlays, impacts, landings). Accents count in the cap and are
-- stopped first ("CombatSfxAccents" = accents playing, log lines "<event>+<Zone>"). Dev hook:
-- SoundService:SetAttribute("CombatSfxZone", "<ZoneId>") forces that zone's accent for every combat sound.
-- ------------------------------------------------------------------------------------------------
type Variant = { Name: string, Peak: number, Length: number, Start: number? }
type Voice = { sound: Sound?, name: string, anchor: Attachment?, serial: number, accent: boolean }
type Release = { time: number, release: number, grand: boolean }

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
local ACCENT = CombatSfx.ZoneAccent
local accentCount = 0 -- zone accent voices in active
local impactAt, impactCount = -math.huge, 0 -- impact accents of the current ZoneAccent.ImpactWindow
-- the last Magic cast / Ranged shot of each character (from its Swing): when its release comes
local casts: { [Instance]: Release } = setmetatable({}, { __mode = "k" }) :: any
local shots: { [Instance]: Release } = setmetatable({}, { __mode = "k" }) :: any

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
		if voice.accent then
			accentCount -= 1
		end
	end
	voice.accent = false
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
		SoundService:SetAttribute("CombatSfxAccents", accentCount)
	end
end

local function expire(voice: Voice, serial: number)
	if voice.serial == serial then
		release(voice)
	end
end

-- The oldest zone accent playing (the first one stopped when the cap is full).
local function oldestAccent(): Voice?
	if accentCount > 0 then
		for _, voice in ipairs(active) do
			if voice.accent then
				return voice
			end
		end
	end
	return nil
end

-- One variant, now. volume / pitch already include the spec's multipliers and the random pitch; extra = seconds of
-- the file skipped on top of the variant's Start (a whoosh that would peak too late for a fast hit).
-- accent = the zone of a zone style accent layer (nil: a category sound).
local function start(variant: Variant, setName: string, volume: number, pitch: number, position: Vector3?, event: string, delay: number, extra: number, accent: string?)
	local now = os.clock()
	local at = stackAt[setName]
	if accent then
		-- zone accents have their own limits (ZoneAccent: Cap, ImpactMax): the signature beats of one move may start
		-- several variants of a set in the same frame
	elseif at and now - at < CombatSfx.StackWindow then
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
	if accent then
		-- zone accents count in the cap: at most ZoneAccent.Cap of them, and one never stops a category sound
		local oldest = if accentCount >= ACCENT.Cap then oldestAccent() else nil
		if oldest then
			release(oldest)
		end
		if #active >= CombatSfx.Cap and accentCount == 0 then
			return
		end
	end
	local sound = acquire(name)
	if not sound then
		return
	end
	while #active >= CombatSfx.Cap do
		release(oldestAccent() or active[1])
	end
	local voice = table.remove(spareVoices) or { sound = nil, name = name, anchor = nil, serial = 0, accent = false }
	voice.sound = sound
	voice.name = name
	voice.accent = accent ~= nil
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
	if accent then
		accentCount += 1
	end
	local length = if variant.Length and variant.Length > 0 then variant.Length else math.max(sound.TimeLength, 1)
	task.delay(math.max(0.05, (length - skip) / pitch), expire, voice, voice.serial)
	if SoundService:GetAttribute("CombatSfxDebug") == true then
		SoundService:SetAttribute("CombatSfxActive", #active)
		SoundService:SetAttribute("CombatSfxAccents", accentCount)
		debugLog(string.format("%.3f %s %s p=%.3f v=%.2f d=%.3f s=%.3f %s", now, if accent then event .. "+" .. accent else event, name, pitch, sound.Volume, delay, skip, if position then "3D" else "2D"))
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

-- Plays a spec and its layers. hitIn = seconds from now until the hit the spec is timed to (nil: at once), lead = how
-- long before that hit the variant's Peak lands (delayed, or with the start of the file skipped when the hit comes
-- sooner than the peak; 0.05 s stay before it), speed divides the spec's own Hit / At times. Layers inherit hitIn and
-- lead unless they set their own Hit / Lead / At. accent = the zone of a zone style accent layer (nil: a category sound).
local function playSpec(spec: { [string]: any }, volume: number, pitch: number, position: Vector3?, hitIn: number?, lead: number, speed: number, event: string, accent: string?)
	local setName = spec.Set
	local myLead = if typeof(spec.Lead) == "number" then spec.Lead else lead
	local myHit = if typeof(spec.Hit) == "number" then spec.Hit / speed else hitIn
	local at = if typeof(spec.At) == "number" then spec.At / speed else nil
	local set = if typeof(setName) == "string" then SETS[setName] else nil
	if set and #set > 0 then
		local variant = pick(setName, set)
		local p = pitch * (spec.Pitch or 1) * (1 + rng:NextNumber(-CombatSfx.PitchRange, CombatSfx.PitchRange))
		local v = volume * (spec.Volume or 1)
		local delay, extra = 0, 0
		if at then
			delay = at
		elseif myHit then
			local toPeak = variant.Peak - (variant.Start or 0)
			local wait = myHit - myLead - toPeak / p
			if wait >= 0 then
				delay = wait
			else
				extra = math.min(-wait * p, math.max(0, toPeak - 0.05))
			end
		end
		if delay > 0.01 then
			task.delay(delay, start, variant, setName, v, p, position, event, delay, extra, accent)
		else
			start(variant, setName, v, p, position, event, 0, extra, accent)
		end
	end
	local also = spec.Also
	if typeof(also) == "table" then
		for _, layer in ipairs(also) do
			playSpec(layer, volume, pitch, position, myHit, myLead, speed, event, accent)
		end
	end
end

local function inRange(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return not camera or (camera.CFrame.Position - position).Magnitude <= CombatSfx.Range
end

-- A Burst / Shot this close to the local character is the player's own (its slam, its magic area, a shot at it).
local function nearLocal(position: Vector3): boolean
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and (root.Position - position).Magnitude <= CombatSfx.NearLocal
end

-- Remembers when this character's cast / shot is released (seconds from now).
local function remember(list: { [Instance]: Release }, character: Instance, release: number, grand: boolean)
	local now = os.clock()
	local entry = list[character]
	if entry then
		entry.time, entry.release, entry.grand = now, now + release, grand
	else
		list[character] = { time = now, release = now + release, grand = grand }
	end
end

-- The latest Magic cast of the last CastLink.Window s whose caster stands within CastLink.Range (flat) of a Burst
-- (one Burst per cast), and the caster's root.
local function linkCast(at: Vector3): (Release?, BasePart?)
	local link = CombatSfx.CastLink
	local now = os.clock()
	local best: Release?, bestRoot: BasePart? = nil, nil
	for character, cast in pairs(casts) do
		if now - cast.time < link.Window and (not best or cast.time > best.time) then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local d = root.Position - at
				if Vector3.new(d.X, 0, d.Z).Magnitude <= link.Range then
					best, bestRoot = cast, root
				end
			end
		end
	end
	if best then
		best.time = -math.huge
	end
	return best, bestRoot
end

-- The Burst spec of a style (an element, "Arcane", "Slam", "Enemy").
local function burstStyle(entry: { [string]: any }, style: string): { [string]: any }?
	local styles = entry.Styles
	if typeof(styles) ~= "table" then
		return nil
	end
	return styles[style] or styles[CombatSfx.StyleGroups[style] or ""] or styles[entry.Default or ""]
end

-- ------------------------------------------------------------------------------------------------
-- Zone fighting styles: the accent layer of the weapon's zone (Config/CombatSfx Zones / ZoneAccent)
-- ------------------------------------------------------------------------------------------------
local ZONE_TIMING = CombatVFX.ZoneTiming
local FIN_HIT = 0.5 -- the overlays' markers (Config/CombatAnimations; Controllers/VFX/Styles)
local JUMP_DIVE, JUMP_HIT = 0.35, 0.6

-- The zone id and accent entry of a ctx (the CombatSfxZone dev hook forces one); nil for Plains / no zone.
local function zoneOf(info: { [string]: any }): (string?, { [string]: any }?)
	local zone = SoundService:GetAttribute("CombatSfxZone")
	if zone == nil or zone == "" then
		zone = info.Zone
	end
	local style = CombatStyles.get(zone)
	if not style then
		return nil, nil
	end
	return style.Id, CombatSfx.Zones[style.Id]
end

-- Seconds (at x1) from the attack call to a signature beat at overlay time `at`, as the animation times its
-- Style_<Zone>_Finisher / _Jump overlay on the clip (mirrors Controllers/VFX/Styles.beatTime); nil = a melee jump beat
-- after the dive starts (the landing is the Land event).
local function beatTime(category: string, at: number, impact: number, air: boolean, late: boolean): number?
	if air then
		local dive = ZONE_TIMING.JumpDive[category]
		if dive then
			return if at <= JUMP_DIVE then at / JUMP_DIVE * dive else nil
		end
		-- Ranged / Magic hover: [0, Hit] then the recovery
		local length = ZONE_TIMING.JumpLength[category] or impact * 2
		if at <= JUMP_HIT then
			return at / JUMP_HIT * impact
		end
		return impact + (at - JUMP_HIT) / (1 - JUMP_HIT) * math.max(0, length - impact)
	end
	local span = math.max(0, (ZONE_TIMING.FinisherLength[category] or impact * 2) - impact)
	if late then
		-- the whole signature in the recovery: its wind-up part over the first LateSplit of it
		local split = ZONE_TIMING.LateSplit
		if at <= FIN_HIT then
			return impact + at / FIN_HIT * split * span
		end
		return impact + (split + (at - FIN_HIT) / (1 - FIN_HIT) * (1 - split)) * span
	end
	if at <= FIN_HIT then
		return at / FIN_HIT * impact
	end
	return impact + (at - FIN_HIT) / (1 - FIN_HIT) * span
end

-- The signature beats of a move: each beat's variant Peak lands Lead (default 0) before its overlay time.
local function playBeats(beats: { any }, category: string, impact1: number, speed: number, air: boolean, late: boolean, volume: number, position: Vector3?, zoneId: string): boolean
	local played = false
	for _, beat in ipairs(beats) do
		local at = if typeof(beat.Beat) == "number" then beatTime(category, beat.Beat, impact1, air, late) else nil
		if at then
			playSpec(beat, volume, 1, position, at / speed, if typeof(beat.Lead) == "number" then beat.Lead else 0, speed, "Swing", zoneId)
			played = true
		end
	end
	return played
end

-- The zone's accent on a swing (after the category's own sounds): impact1 = the move's hit at x1.
local function swingAccent(info: { [string]: any }, category: string, variant: string?, step: number, impact1: number, speed: number, volume: number, position: Vector3?)
	local zoneId, accent = zoneOf(info)
	if not (zoneId and accent) then
		return
	end
	local look = CombatVFX.Zones[zoneId] -- LateOk / JumpSkip, as the animation and the VFX
	local beats = accent.Beats
	local impact = impact1 / speed
	local v = volume * ACCENT.Volume
	local spec: { [string]: any }? = nil
	if variant == "Air" then
		local played = false
		if beats and beats.Jump and not (look and look.JumpSkip and look.JumpSkip[category]) then
			played = playBeats(beats.Jump, category, impact1, speed, true, false, v, position, zoneId)
		end
		spec = accent.Air or (if played then nil else accent.Swing)
	elseif variant == "Dash" then
		spec = accent.Dash or accent.Swing
	elseif info.Finisher == true then
		spec = accent.Finisher or accent.Swing
		if beats and beats.Finisher then
			local late = look ~= nil and look.LateOk == true and impact < ZONE_TIMING.LateWindup
			playBeats(beats.Finisher, category, impact1, speed, false, late, v, position, zoneId)
		end
	elseif (step - 1) % (ACCENT.LightEvery[category] or 2) == 0 then
		spec = accent.Light
	end
	if spec then
		playSpec(spec, v, 1, position, impact, CombatSfx.HitLead, speed, "Swing", zoneId)
	end
end

-- The zone's accent on a confirmed hit (at most ImpactMax per ImpactWindow) or a landing: it peaks at once (the
-- start of the file is skipped up to 0.05 s before its peak).
local function hitAccent(event: string, info: { [string]: any }, volume: number, position: Vector3?)
	local zoneId, accent = zoneOf(info)
	local spec = if accent then accent[event] else nil
	if not (zoneId and spec) then
		return
	end
	local v = volume * ACCENT.Volume
	if event == "Impact" then
		local now = os.clock()
		if now - impactAt > ACCENT.ImpactWindow then
			impactAt, impactCount = now, 0
		end
		if impactCount >= ACCENT.ImpactMax then
			return
		end
		impactCount += 1
		if info.Finisher == true then
			v *= ACCENT.FinisherImpact
		end
	end
	playSpec(spec, v, 1, position, 0, 0, 1, event, zoneId)
end

local EMPTY = table.freeze({})
local CHIME = table.freeze({ Set = "RarityChime", Volume = CombatSfx.EquipChime.Volume })
local CHIME_LEGENDARY = table.freeze({ Set = "RarityChimeLegendary", Volume = CombatSfx.EquipChime.Volume })

function Sfx.combat(event: string, ctx: { [string]: any }?)
	if not IS_CLIENT or typeof(event) ~= "string" then
		return
	end
	local info = ctx or EMPTY :: any
	local position: Vector3? = nil
	local volume = 1
	if info.IsLocal ~= true and typeof(info.Position) == "Vector3" then
		position = info.Position
		if not inRange(info.Position) then
			return
		end
		if info.IsLocal == false or not ((event == "Burst" or event == "Shot") and nearLocal(info.Position)) then
			volume = CombatSfx.RemoteVolume
		end
	end
	local lead = CombatSfx.HitLead
	local requested = if typeof(info.Category) == "string" then info.Category else CombatSfx.DefaultCategory
	local category = CombatSfx.Categories[requested] or CombatSfx.Categories[CombatSfx.DefaultCategory]
	local entry = (category and category[event]) or CombatSfx.Shared[event]
	if typeof(entry) ~= "table" then
		return
	end
	if event == "Swing" then
		local swing = entry
		local styles = entry.Styles
		if styles then
			local tool = info.Tool
			local weaponId = if typeof(tool) == "Instance" then tool:GetAttribute("WeaponId") else nil
			local style = if typeof(weaponId) == "string" then CombatSfx.WeaponStyles[weaponId] else nil
			if style and styles[style] then
				swing = styles[style]
			end
		end
		local variant = if info.Variant == "Air" or info.Variant == "Dash" or info.Variant == "Heavy" then info.Variant else nil
		local step = if typeof(info.Step) == "number" then math.max(1, math.floor(info.Step)) else 1
		local spec: { [string]: any }? = nil
		local def: { [string]: any }? = nil
		if variant then
			-- jump attack / dash strike / heavy: its own spec (the weapon style's, else the category's; a heavy without one
			-- sounds like the finisher), timed on its Config/WeaponMoves move
			spec = swing[variant] or entry[variant]
			def = WeaponMoves.move(requested, step, variant) or WeaponMoves.move(CombatSfx.DefaultCategory, step, variant)
		end
		if not spec then
			spec = swing.Finisher
			if info.Finisher ~= true or not spec then
				local steps = swing.Steps
				spec = steps and steps[(step - 1) % #steps + 1]
			end
		end
		if spec then
			if not def then
				def = WeaponMoves.move(requested, step) or WeaponMoves.move(CombatSfx.DefaultCategory, 1)
			end
			local speed = if typeof(info.Speed) == "number" and info.Speed > 0 then info.Speed else 1
			local impact1 = if def and typeof(def.Impact) == "number" then def.Impact else 0.15
			local impact = impact1 / speed
			playSpec(spec, volume, 1, position, impact, lead, speed, event)
			local burst = spec.Burst
			if typeof(burst) == "table" then
				-- a blast drawn at the hit with no Burst from the server (Magic BlinkBlast): the element's burst sound
				local shared = CombatSfx.Shared.Burst
				local layer = if shared then burstStyle(shared, if typeof(info.Element) == "string" then info.Element else "") else nil
				if layer then
					playSpec(layer, volume * (burst.Volume or 1), burst.Pitch or 1, position, impact, 0, speed, event)
				end
			end
			-- the server sends the cast's Burst / the arrows at the request: they are timed on this release
			local character = info.Character
			if typeof(character) == "Instance" then
				if requested == "Magic" and variant ~= "Dash" then
					remember(casts, character, impact, variant == "Air" or info.Finisher == true)
				elseif requested == "Ranged" then
					remember(shots, character, impact, false)
				end
			end
			-- zone fighting styles: the accent of the weapon's zone
			swingAccent(info, requested, variant, step, impact1, speed, volume, position)
		end
	elseif event == "Impact" then
		local materials = entry.Materials or EMPTY
		local shared = CombatSfx.Shared.Impact
		local sharedMaterials = if shared and shared.Materials then shared.Materials else EMPTY
		local material = if typeof(info.Material) == "string" then info.Material else CombatSfx.DefaultMaterial
		local default = CombatSfx.DefaultMaterial
		local spec = materials[material] or sharedMaterials[material] or materials[default] or sharedMaterials[default]
		local base = volume
		local pitch = 1
		local finisher = if info.Finisher == true then entry.Finisher else nil
		if finisher then
			volume *= finisher.Volume or 1
			pitch = finisher.Pitch or 1
			if finisher.Also then
				for _, layer in ipairs(finisher.Also) do
					playSpec(layer, volume, 1, position, nil, lead, 1, event)
				end
			end
		end
		if spec then
			playSpec(spec, volume, pitch, position, nil, lead, 1, event)
		end
		if info.Crit == true and entry.Crit then
			playSpec(entry.Crit, base, 1, position, nil, lead, 1, event)
		end
		hitAccent(event, info, base, position)
	elseif event == "Shot" then
		-- the player's own shot is heard through its Swing (release / fire)
		local spec = if info.Own == true then nil elseif info.Enemy == true then entry.Enemy else entry.Player
		if spec then
			-- another player's arrow leaves at the release of its swing (the drawn arrow waits for it too)
			local hitIn: number? = nil
			local shooter = info.Shooter
			local character = if typeof(shooter) == "Instance" and shooter:IsA("Player") then shooter.Character else nil
			local shot = if character then shots[character] else nil
			if shot then
				local wait = shot.release - os.clock()
				if wait > 0 and wait <= CombatSfx.CastLink.ShotHold then
					hitIn = wait
				end
			end
			playSpec(spec, volume, 1, position, hitIn, lead, 1, event)
		end
	elseif event == "Burst" then
		local style = if typeof(info.Style) == "string" then info.Style else ""
		local spec = burstStyle(entry, style)
		if spec then
			local hitIn: number? = nil
			local grand = false
			if style ~= "Slam" and style ~= "Enemy" and typeof(info.Position) == "Vector3" then
				-- a Magic area (sent at the cast start): it explodes where the cast's bolt lands = the release + the
				-- bolt's flight from the caster (Controllers/VFX Casts), else BurstHit s from now
				local cast, root = linkCast(info.Position)
				if cast and root then
					local link = CombatSfx.CastLink
					local flight = ((info.Position + Vector3.new(0, 0.8, 0)) - (root.Position + Vector3.new(0, 2, 0))).Magnitude / link.BoltSpeed
					hitIn = math.max(0, cast.release - os.clock()) + math.clamp(flight, link.MinTravel, link.MaxTravel)
					grand = cast.grand
				else
					hitIn = CombatSfx.BurstHit
				end
			end
			playSpec(spec, volume, 1, position, hitIn, lead, 1, event)
			if grand and typeof(entry.Grand) == "table" then
				playSpec(entry.Grand, volume, 1, position, hitIn, lead, 1, event)
			end
		end
	else
		playSpec(entry, volume, 1, position, nil, lead, 1, event)
		if event == "Land" then
			hitAccent(event, info, volume, position)
		end
		local rarity = info.Rarity
		local chime = CombatSfx.EquipChime
		if event == "Equip" and typeof(rarity) == "number" and rarity >= chime.From then
			playSpec(if rarity >= chime.Legendary then CHIME_LEGENDARY else CHIME, volume, 1, position, nil, lead, 1, event)
		end
	end
end

-- Counts for tests: playing now, idle pooled copies, copies cloned since start.
function Sfx.combatStats(): { [string]: number }
	local pooled = 0
	for _, list in pairs(idle) do
		pooled += #list
	end
	return { Active = #active, Accents = accentCount, Pooled = pooled, Created = created, Anchors = #anchors }
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
