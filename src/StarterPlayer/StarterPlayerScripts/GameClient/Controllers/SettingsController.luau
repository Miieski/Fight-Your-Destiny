--!strict
-- The player's settings on the client: every change is applied at once and saved a moment later
-- (Net.request "SetSetting", debounced; the server validates). Volumes drive the SoundGroups,
-- UI Scale the screens, Camera Zoom and First Person the camera; other settings are read where they
-- are used (Settings.get / Settings.changed).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = require(ReplicatedStorage.GameSystem.Config.Audio)
local Net = require(ReplicatedStorage.GameSystem.Net)
local SettingsConfig = require(ReplicatedStorage.GameSystem.Config.Settings)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.UI.Kit.Theme)

local Settings = { Priority = 2 }

local values: { [string]: any } = SettingsConfig.defaults()
local pending: { [string]: number } = {}
local listeners: { [string]: { (any) -> () } } = {}

local function applyZoom(distance: number)
	local player = Players.LocalPlayer
	if not player.Character or values.FirstPerson == true then
		return
	end
	player.CameraMinZoomDistance = distance
	player.CameraMaxZoomDistance = distance
	task.delay(0.2, function()
		player.CameraMinZoomDistance = UIConfig.Fx.CameraMinZoom
		player.CameraMaxZoomDistance = UIConfig.Fx.CameraMaxZoom
	end)
end

-- LockFirstPerson keeps the camera in the eyes; back to Classic, the camera returns to the default zoom.
local function applyFirstPerson(on: boolean, pullOut: boolean)
	Players.LocalPlayer.CameraMode = if on then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic
	if not on and pullOut then
		applyZoom(values.CameraZoom)
	end
end

local function apply(key: string, fromServer: boolean?)
	local value = values[key]
	for group, settingKey in pairs(Audio.VolumeSetting) do
		if settingKey == key then
			Sfx.group(group).Volume = value / 100
		end
	end
	if key == "UiScale" then
		Theme.setUserScale(value)
	elseif key == "CameraZoom" and not fromServer then
		applyZoom(value)
	elseif key == "FirstPerson" then
		applyFirstPerson(value == true, not fromServer)
	end
	for _, fn in ipairs(listeners[key] or {}) do
		task.spawn(fn, value)
	end
end

function Settings.get(key: string): any
	return values[key]
end

-- Calls fn(value) when the setting changes. Returns a disconnect function.
function Settings.changed(key: string, fn: (any) -> ()): () -> ()
	local list = listeners[key]
	if not list then
		list = {}
		listeners[key] = list
	end
	table.insert(list, fn)
	return function()
		local index = table.find(list, fn)
		if index then
			table.remove(list, index)
		end
	end
end

-- Applies at once, saves after SAVE_DEBOUNCE_SECONDS without further change. Returns ok, value|error.
function Settings.set(key: string, value: any): (boolean, any)
	local ok, clean = SettingsConfig.validate(key, value, State.get("Passes"))
	if not ok then
		return false, clean
	end
	values[key] = clean
	apply(key)
	local token = (pending[key] or 0) + 1
	pending[key] = token
	task.delay(SettingsConfig.SAVE_DEBOUNCE_SECONDS, function()
		if pending[key] ~= token then
			return
		end
		local saved, result, serverValue = Net.request("SetSetting", key, clean)
		if pending[key] == token then
			pending[key] = nil
		end
		if not saved then
			warn(`Settings: "{key}" was not saved ({tostring(result)})`)
			if serverValue ~= nil and pending[key] == nil then
				values[key] = serverValue
				apply(key)
			end
		end
	end)
	return true, clean
end

function Settings:Init()
	for key in pairs(values) do
		apply(key, true)
	end
	State.observe("Settings", function(server: any)
		if typeof(server) ~= "table" then
			return
		end
		for key, value in pairs(server) do
			if pending[key] == nil and SettingsConfig.ById[key] and values[key] ~= value then
				values[key] = value
				apply(key, true)
			end
		end
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.5)
		applyZoom(values.CameraZoom)
	end)
	if Players.LocalPlayer.Character then
		applyZoom(values.CameraZoom)
	end
end

return Settings
