--!strict
-- Zone music and ambience. Sounds live in ReplicatedStorage.Assets.Sounds; the first name that
-- exists is used:  music    "Music_<ZoneId>"      -> "MusicZone"   ("MusicHub" in the hub)
--                  ambience "Ambience_<SubZoneId>" -> "Ambience_<ZoneId>"
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local AudioController = {}

local FADE = TweenInfo.new(1.5)
local channels: { [string]: Sound? } = {}

local function pick(names: { string }): Sound?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local sounds = assets and assets:FindFirstChild("Sounds")
	for _, name in ipairs(names) do
		local sound = sounds and sounds:FindFirstChild(name, true)
		if sound and sound:IsA("Sound") then
			return sound
		end
	end
	return nil
end

local function play(channel: string, source: Sound?)
	local playing = channels[channel]
	if playing and source and playing:GetAttribute("Source") == source.Name then
		return
	end
	if playing then
		local tween = TweenService:Create(playing, FADE, { Volume = 0 })
		tween.Completed:Connect(function()
			playing:Destroy()
		end)
		tween:Play()
	end
	channels[channel] = nil
	if source then
		local sound = source:Clone()
		sound:SetAttribute("Source", source.Name)
		sound.Looped = true
		local volume = sound.Volume
		sound.Volume = 0
		sound.Parent = SoundService
		sound:Play()
		TweenService:Create(sound, FADE, { Volume = volume }):Play()
		channels[channel] = sound
	end
end

function AudioController:Start()
	local player = Players.LocalPlayer
	local function update()
		local zoneId = player:GetAttribute("ZoneId") or "Hub"
		local subZoneId = player:GetAttribute("SubZoneId") or "Hub"
		if zoneId == "Hub" then
			play("Music", pick({ "Music_Hub", "MusicHub" }))
			play("Ambience", pick({ "Ambience_Hub" }))
		else
			play("Music", pick({ "Music_" .. zoneId, "MusicZone" }))
			play("Ambience", pick({ "Ambience_" .. subZoneId, "Ambience_" .. zoneId }))
		end
	end
	player:GetAttributeChangedSignal("SubZoneId"):Connect(update)
	update()
end

return AudioController
