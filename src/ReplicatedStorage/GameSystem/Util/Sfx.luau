--!strict
-- Plays sounds by name (DESIGN.md section 10) and routes every sound to its SoundGroup
-- (Config/Audio): Master > Music, PlayerFX, EnemyFX, UI, Ambient. Sounds live in
-- ReplicatedStorage.Assets.Sounds (any sub-folder). Unknown names are ignored silently.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Audio = require(ReplicatedStorage.GameSystem.Config.Audio)

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

-- Combat sounds (docs/weapons_combat_brief.txt 4D, contract in docs/COMBAT_CONTRACTS.md). OWNER of the mapping: the
-- SFX sub-agent (Config/CombatSfx + the sounds in ReplicatedStorage.Assets.Sounds). CombatController calls only this.
--   Sfx.combat(event, ctx?)   event = "Swing" | "Impact" | "Shot" | "Cast" | "Burst" | "Roll" | "Block" | "BlockHit"
--                             | "BlockBreak" | "Hurt" | "Death" | "Equip"
--                             ctx = { Category?, Step?, Finisher?, Crit?, Material? ("flesh" | "metal" | "stone"),
--                                     Position? (3D sound there; nil = heard at full volume) }
-- STUB until the SFX sub-agent delivers: the sounds the game already had.
local STUB_SOUNDS = { Swing = "SwordSwing", Roll = "Roll", Block = "Block", BlockHit = "Block", Hurt = "Hurt" }

function Sfx.combat(event: string, ctx: { [string]: any }?)
	local info = ctx or {}
	local name = if event == "Impact" then (if info.Crit then "Crit" else "Hit") else STUB_SOUNDS[event]
	if name then
		Sfx.play(name, info.Position)
	end
end

return Sfx
