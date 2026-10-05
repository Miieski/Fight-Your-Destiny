--!strict
-- All remotes of the game live here (DESIGN.md section 10). Never create remotes by hand.
--
--   client -> server   Net.request(action, ...)  waits for the server's answer (RemoteFunction)
--                      Net.send(action, ...)     fire-and-forget (RemoteEvent)
--                      The server answers both with Net.handle(action, fn, minInterval).
--   server -> client   Net.fire(player, event, ...), Net.fireAll(event, ...); the client listens
--                      with Net.on(event, fn). Events must be listed in Net.EVENTS.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Net = {}

Net.EVENTS = {
	"Data", -- { [profileKey] = wholeValue }: patches of the player's own profile
	"Notify", -- { Kind, Text, Icon?, Rarity? }: a toast (see GameClient/UI/Notifier)
	"Hit", -- position, damage, isCrit: damage numbers
	"OpenWindow", -- windowId, arg?: the server asks the client to open a window (hub portals -> Zones)
	"Team", -- { Id, Leader = userId, Members = { userId } } or nil: the player's team (TeamService)
	"TeamInvite", -- { Id, From = userId, FromName, Seconds }: an invite to answer (TeamService)
}

local IS_SERVER = RunService:IsServer()

type Handler = { fn: (Player, ...any) -> ...any, minInterval: number }

local handlers: { [string]: Handler } = {}
local lastCall: { [Player]: { [string]: number } } = {}
local folder: Instance

local function dispatch(player: Player, action: any, ...: any): ...any
	if typeof(action) ~= "string" then
		return false, "Bad request"
	end
	local handler = handlers[action]
	if not handler then
		return false, "Unknown action"
	end
	local calls = lastCall[player]
	if not calls then
		calls = {}
		lastCall[player] = calls
	end
	local now = os.clock()
	if now - (calls[action] or -math.huge) < handler.minInterval then
		return false, "Too fast"
	end
	calls[action] = now
	return handler.fn(player, ...)
end

local existing = if IS_SERVER then script:FindFirstChild("Remotes") else nil
if existing then
	-- A second copy of this module (required from the Studio command bar or a plugin) reuses the
	-- live remotes for Net.fire and leaves the game's handlers alone.
	folder = existing
elseif IS_SERVER then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in ipairs(Net.EVENTS) do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
	local request = Instance.new("RemoteFunction")
	request.Name = "Request"
	request.Parent = folder
	local send = Instance.new("RemoteEvent")
	send.Name = "Send"
	send.Parent = folder
	folder.Parent = script

	request.OnServerInvoke = function(player: Player, action: any, ...: any)
		local result = table.pack(pcall(dispatch, player, action, ...))
		if not result[1] then
			warn(`Net: request "{tostring(action)}" failed: {result[2]}`)
			return false, "Server error"
		end
		return table.unpack(result, 2, result.n)
	end
	send.OnServerEvent:Connect(function(player: Player, action: any, ...: any)
		local ok, err = pcall(dispatch, player, action, ...)
		if not ok then
			warn(`Net: send "{tostring(action)}" failed: {err}`)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)
else
	folder = script:WaitForChild("Remotes")
end

local function remote(name: string): Instance
	return folder:WaitForChild(name)
end

-- Server: answers Net.request / Net.send for this action. Calls closer than minInterval seconds
-- (per player) are refused with false, "Too fast". The handler must validate every argument.
function Net.handle(action: string, fn: (Player, ...any) -> ...any, minInterval: number?)
	assert(IS_SERVER, "Net.handle is server only")
	handlers[action] = { fn = fn, minInterval = minInterval or 0 }
end

function Net.request(action: string, ...: any): ...any
	assert(not IS_SERVER, "Net.request is client only")
	return (remote("Request") :: RemoteFunction):InvokeServer(action, ...)
end

function Net.send(action: string, ...: any)
	assert(not IS_SERVER, "Net.send is client only")
	local send = remote("Send") :: RemoteEvent
	send:FireServer(action, ...)
end

function Net.fire(player: Player, event: string, ...: any)
	assert(table.find(Net.EVENTS, event), `unknown event "{event}" (add it to Net.EVENTS)`)
	local remoteEvent = remote(event) :: RemoteEvent
	remoteEvent:FireClient(player, ...)
end

function Net.fireAll(event: string, ...: any)
	assert(table.find(Net.EVENTS, event), `unknown event "{event}" (add it to Net.EVENTS)`)
	local remoteEvent = remote(event) :: RemoteEvent
	remoteEvent:FireAllClients(...)
end

function Net.on(event: string, fn: (...any) -> ()): RBXScriptConnection
	assert(table.find(Net.EVENTS, event), `unknown event "{event}" (add it to Net.EVENTS)`)
	return (remote(event) :: RemoteEvent).OnClientEvent:Connect(fn)
end

return Net
