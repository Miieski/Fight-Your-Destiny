--!strict
-- Client mirror of the player's profile. The server sends patches { key = wholeValue } on Net "Data".
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("GameSystem"):WaitForChild("Net"))

local State = {}

local data: { [string]: any } = {}
local changed = Instance.new("BindableEvent")

-- Fires (key, newValue, oldValue).
State.Changed = changed.Event

function State.get(key: string): any
	return data[key]
end

Net.event("Data").OnClientEvent:Connect(function(patch: { [string]: any })
	for key, value in pairs(patch) do
		local old = data[key]
		data[key] = value
		changed:Fire(key, value, old)
	end
end)

return State
