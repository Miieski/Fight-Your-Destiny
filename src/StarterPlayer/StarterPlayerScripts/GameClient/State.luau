--!strict
-- Client mirror of the player's profile (DESIGN.md section 11). UI code reads it here and never
-- writes the server's data: the server sends patches { key = wholeValue } on Net "Data".
-- setLocal is only for instant feedback on the player's own settings (the server stays the authority).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("GameSystem"):WaitForChild("Net"))

local State = {}

local data: { [string]: any } = {}
local fromPatch: { [string]: boolean } = {}
local listeners: { [string]: { (any, any) -> () } } = {}
local ready = false
local readyEvent = Instance.new("BindableEvent")

local function set(key: string, value: any)
	local old = data[key]
	data[key] = value
	local list = listeners[key]
	if list then
		for _, fn in ipairs(table.clone(list)) do
			task.spawn(fn, value, old)
		end
	end
end

function State.get(key: string): any
	return data[key]
end

-- Calls fn(newValue, oldValue) whenever key changes. Returns a function that disconnects it.
function State.changed(key: string, fn: (any, any) -> ()): () -> ()
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

-- Same as changed, but also calls fn right away with the current value.
function State.observe(key: string, fn: (any, any) -> ()): () -> ()
	task.spawn(fn, data[key], nil)
	return State.changed(key, fn)
end

function State.setLocal(key: string, value: any)
	set(key, value)
end

function State.isReady(): boolean
	return ready
end

function State.waitReady()
	if not ready then
		readyEvent.Event:Wait()
	end
end

Net.on("Data", function(patch: { [string]: any })
	for key, value in pairs(patch) do
		fromPatch[key] = true
		set(key, value)
	end
	if not ready then
		ready = true
		readyEvent:Fire()
	end
end)

task.spawn(function()
	local snapshot = Net.request("GetProfile")
	if typeof(snapshot) == "table" then
		for key, value in pairs(snapshot) do
			-- A patch received meanwhile is newer than the snapshot.
			if not fromPatch[key] then
				set(key, value)
			end
		end
	end
	if not ready then
		ready = true
		readyEvent:Fire()
	end
end)

return State
