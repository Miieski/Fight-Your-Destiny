--!strict
-- Plays sounds by name (DESIGN.md section 10). Sounds live in ReplicatedStorage.Assets.Sounds
-- (any sub-folder); see docs/SOUND_KIT.md for the list. Unknown names are ignored silently so a
-- missing sound never breaks gameplay.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sfx = {}

local cache: { [string]: Sound | false } = {}

local function find(name: string): Sound?
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
	local source = find(name)
	if not source then
		return
	end
	local sound = source:Clone()
	sound.Looped = false
	if position then
		local anchor = Instance.new("Attachment")
		anchor.WorldPosition = position
		anchor.Parent = workspace.Terrain
		sound.Parent = anchor
		Debris:AddItem(anchor, sound.TimeLength + 1)
	else
		sound.Parent = SoundService
		Debris:AddItem(sound, sound.TimeLength + 1)
	end
	sound:Play()
end

return Sfx
