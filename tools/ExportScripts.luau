--[[
	Prints every script of the mapped roots to Output so tools/pull_scripts.py can write them to disk
	(Studio is where scripts are edited through the MCP; the repo mirrors them).
	Usage (execute_luau, Edit):  return require(game.ServerStorage.DevTools.ExportScripts)()
	then on disk:                python tools/pull_scripts.py --wait 10
]]
local EncodingService = game:GetService("EncodingService")

local CHUNK = 800
-- { root instance path, folder on disk }
local ROOTS = {
	{ { "ServerStorage", "DevTools" }, "tools" },
	{ { "ReplicatedStorage", "GameSystem" }, "src/ReplicatedStorage/GameSystem" },
	{ { "ServerScriptService", "GameSystem" }, "src/ServerScriptService/GameSystem" },
	{ { "StarterPlayer", "StarterPlayerScripts", "GameClient" }, "src/StarterPlayer/StarterPlayerScripts/GameClient" },
}

local function extension(inst: Instance): string
	if inst:IsA("LocalScript") or (inst:IsA("Script") and inst.RunContext == Enum.RunContext.Client) then
		return ".client.luau"
	elseif inst:IsA("Script") then
		return ".server.luau"
	end
	return ".luau"
end

return function(): string
	local session = os.date("%Y%m%d%H%M%S")
	local count = 0
	for _, entry in ipairs(ROOTS) do
		local root: Instance? = game:GetService(entry[1][1])
		for i = 2, #entry[1] do
			root = root and root:FindFirstChild(entry[1][i])
		end
		if root then
			for _, inst in ipairs(root:GetDescendants()) do
				if inst:IsA("LuaSourceContainer") then
					local parts = {}
					local node = inst
					while node ~= root do
						table.insert(parts, 1, node.Name)
						node = node.Parent
					end
					local path = entry[2] .. "/" .. table.concat(parts, "/") .. extension(inst)
					local b64 = buffer.tostring(EncodingService:Base64Encode(buffer.fromstring((inst :: any).Source)))
					local n = math.max(1, math.ceil(#b64 / CHUNK))
					print(`FYDSRC|{session}|{path}|HEAD|{n}|{#b64}`)
					for i = 1, n do
						print(`FYDSRC|{session}|{path}|{i}|{string.sub(b64, (i - 1) * CHUNK + 1, i * CHUNK)}`)
					end
					count += 1
				end
			end
		end
	end
	print(`FYDSRC|{session}|*|DONE|{count}`)
	return `exported {count} scripts (session {session})`
end
