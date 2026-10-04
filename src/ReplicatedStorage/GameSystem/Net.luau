--!strict
-- All remotes of the game live here (DESIGN.md section 10). Never create RemoteEvents by hand:
-- add the name to EVENTS and use Net.event(name).
local RunService = game:GetService("RunService")

local Net = {}

local EVENTS = {
	"Data", -- server -> client: { [profileKey] = wholeValue }
	"Attack", -- client -> server: attack request (no arguments; the server decides everything)
	"Hit", -- server -> client: position, damage, isCrit (damage numbers)
	"Notify", -- server -> client: text, kind ("info" | "good" | "bad")
	"Admin", -- client -> server: command name, amount (admins only, checked on the server)
}

local folder: Instance
if RunService:IsServer() then
	folder = script:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in ipairs(EVENTS) do
		if not folder:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	end
	folder.Parent = script
else
	folder = script:WaitForChild("Remotes")
end

function Net.event(name: string): RemoteEvent
	assert(table.find(EVENTS, name), `unknown remote "{name}" (add it to Net.EVENTS)`)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
