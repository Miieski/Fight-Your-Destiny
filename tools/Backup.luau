--[[
	Studio backup module (dev tool, Edit mode only). Source of truth: tools/backup_studio.luau in the repo.
	Usage (execute_luau, Edit):  return require(game.ServerStorage.DevTools.Backup)("label")
	then on disk:                python tools/collect_backup.py --wait 10
	Terrain voxels and the Camera are NOT included: the map is built from parts only.
]]
local SerializationService = game:GetService("SerializationService")
local EncodingService = game:GetService("EncodingService")

-- Studio log lines are cut at about 1020 characters including the log prefix.
local CHUNK = 800
local SERVICES = {
	"Workspace", "Lighting", "ReplicatedStorage", "ServerStorage", "ServerScriptService",
	"StarterGui", "StarterPack", "StarterPlayer", "SoundService", "ReplicatedFirst", "MaterialService",
}

return function(label: string, onlyServices: { string }?): string
	label = string.gsub(label or "manual", "[^%w_%-]", "_")
	local stamp = os.date("%Y-%m-%d_%H%M%S")
	local report = {}
	for _, serviceName in ipairs(onlyServices or SERVICES) do
		local service = game:GetService(serviceName)
		local instances = {}
		for _, child in ipairs(service:GetChildren()) do
			if child.Archivable and not child:IsA("Terrain") and not child:IsA("Camera") then
				table.insert(instances, child)
			end
		end
		if #instances > 0 then
			local id = `FightYourDestiny_{stamp}_{label}_{serviceName}`
			local ok, result = pcall(function()
				return SerializationService:SerializeInstancesAsync(instances)
			end)
			if ok then
				local b64 = buffer.tostring(EncodingService:Base64Encode(result))
				local count = math.ceil(#b64 / CHUNK)
				print(`FYDBAK|{id}|HEAD|{count}|{#b64}|{buffer.len(result)}`)
				for i = 1, count do
					print(`FYDBAK|{id}|{i}|{string.sub(b64, (i - 1) * CHUNK + 1, i * CHUNK)}`)
					if i % 200 == 0 then
						task.wait()
					end
				end
				print(`FYDBAK|{id}|TAIL`)
				table.insert(report, `{id}.rbxm {buffer.len(result)} bytes, {count} chunks`)
			else
				table.insert(report, `FAILED {id}: {result}`)
			end
		end
	end
	return table.concat(report, "\n")
end
