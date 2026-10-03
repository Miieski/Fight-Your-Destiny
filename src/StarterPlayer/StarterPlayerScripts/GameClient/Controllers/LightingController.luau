--!strict
-- Switches the lighting preset when the player changes zone or sub-zone.
-- Presets: ReplicatedStorage.Assets.Lighting.<name> (attributes = Lighting properties, children =
-- Atmosphere / Sky / post effects). Lookup: "<Zone>_<n>", then "<Zone>", then "Hub". See docs/VFX_KIT.md.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LightingController = {}

local FADE = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local CLASSES = { "Atmosphere", "Sky", "ColorCorrectionEffect", "BloomEffect", "SunRaysEffect" }

local current: Instance? = nil

local function find(zoneId: string, subZoneId: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local presets = assets and assets:FindFirstChild("Lighting")
	if not presets then
		return nil
	end
	-- A boss arena uses the look of its boss room.
	local roomId = string.gsub(subZoneId, "_Arena$", "_4")
	return presets:FindFirstChild(roomId) or presets:FindFirstChild(zoneId) or presets:FindFirstChild("Hub")
end

local function apply(preset: Instance)
	if preset == current then
		return
	end
	current = preset
	local tweened = {}
	for name, value in pairs(preset:GetAttributes()) do
		if typeof(value) == "number" or typeof(value) == "Color3" then
			tweened[name] = value
		else
			pcall(function()
				(Lighting :: any)[name] = value
			end)
		end
	end
	pcall(function()
		TweenService:Create(Lighting, FADE, tweened):Play()
	end)
	for _, className in ipairs(CLASSES) do
		local source = preset:FindFirstChildOfClass(className)
		if source then
			local existing = Lighting:FindFirstChildOfClass(className)
			local clone = source:Clone()
			if existing then
				existing:Destroy()
			end
			clone.Parent = Lighting
		end
	end
end

function LightingController:Start()
	local player = Players.LocalPlayer
	local function update()
		local preset = find(player:GetAttribute("ZoneId") or "Hub", player:GetAttribute("SubZoneId") or "Hub")
		if preset then
			apply(preset)
		end
	end
	player:GetAttributeChangedSignal("SubZoneId"):Connect(update)
	update()
end

return LightingController
