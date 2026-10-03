--!strict
-- PLACEHOLDER world flow: hub portals, return pads, sub-zone gates (paid with Gold, per player),
-- location tracking, respawn at the current sub-zone, and a solo boss-arena visit.
-- Everything relies on the world markers of DESIGN.md section 12.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Playtest = require(ReplicatedStorage.GameSystem.Config.Playtest)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)

local ZoneService = { Priority = 4 }

type SubZone = { id: string, zoneId: string, n: number, folder: Instance, area: BasePart, entrance: BasePart }
type Arena = { model: Model, key: string, zoneId: string, slot: number }

local subZones: { SubZone } = {}
local byId: { [string]: SubZone } = {}
local lastTeleport: { [Player]: number } = {}
local arenas: { [Player]: Arena } = {}
local usedSlots: { [number]: boolean } = {}

local function notify(player: Player, text: string, kind: string?)
	Net.event("Notify"):FireClient(player, text, kind or "info")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid and humanoid.Health > 0 then
		return character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	return nil
end

local function canTeleport(player: Player): boolean
	return os.clock() - (lastTeleport[player] or 0) > Playtest.TeleportCooldown
end

local function teleport(player: Player, cframe: CFrame)
	local character = player.Character
	local root = rootOf(player)
	if not (character and root) then
		return
	end
	lastTeleport[player] = os.clock()
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(cframe.Position)
		end)
		if character.Parent then
			root.AssemblyLinearVelocity = Vector3.zero
			character:PivotTo(cframe + Vector3.new(0, 4, 0))
		end
	end)
end

local function hasGround(position: Vector3): boolean
	return workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -60, 0)) ~= nil
end

local function inside(area: BasePart, position: Vector3): boolean
	local rel = area.CFrame:PointToObjectSpace(position)
	local half = area.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

local function isUnlocked(player: Player, subZone: SubZone): boolean
	local profile = DataService:Get(player)
	return subZone.n == 1 or (profile ~= nil and profile.SubZones[subZone.id] == true)
end

local function setLocation(player: Player, zoneId: string, subZoneId: string)
	if player:GetAttribute("SubZoneId") ~= subZoneId then
		player:SetAttribute("ZoneId", zoneId)
		player:SetAttribute("SubZoneId", subZoneId)
		DataService:Set(player, "CurrentZone", zoneId)
	end
end

function ZoneService:ToHub(player: Player)
	local hub = workspace:FindFirstChild("Hub")
	local spawn = hub and hub:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		player:SetAttribute("RespawnSubZone", nil)
		teleport(player, spawn.CFrame)
	end
end

function ZoneService:EnterZone(player: Player, zoneId: string)
	if not canTeleport(player) then
		return
	end
	local subZone = byId[Zones.subZoneId(zoneId, 1)]
	if subZone and hasGround(subZone.entrance.Position) then
		teleport(player, subZone.entrance.CFrame)
	else
		lastTeleport[player] = os.clock()
		local zone = Zones.ById[zoneId]
		notify(player, `{if zone then zone.Name else zoneId} is not built yet`, "bad")
	end
end

local function tryUnlock(player: Player, subZone: SubZone)
	local profile = DataService:Get(player)
	local root = rootOf(player)
	local gate = subZone.folder:FindFirstChild("Gate") :: Model?
	if not (profile and root and gate and gate.PrimaryPart) or profile.SubZones[subZone.id] then
		return
	end
	if (root.Position - gate.PrimaryPart.Position).Magnitude > 40 then
		return
	end
	if subZone.n > 2 and not profile.SubZones[Zones.subZoneId(subZone.zoneId, subZone.n - 1)] then
		notify(player, "Open the previous gate first", "bad")
		return
	end
	local price = if Playtest.FreeGates then 0 else Zones.subZonePrice(subZone.zoneId, subZone.n)
	if profile.Gold < price then
		notify(player, `Not enough Gold: {Format.number(price)} needed`, "bad")
		return
	end
	DataService:AddGold(player, -price)
	local unlocked = table.clone(profile.SubZones)
	unlocked[subZone.id] = true
	DataService:Set(player, "SubZones", unlocked)
	notify(player, `{Zones.ById[subZone.zoneId].SubZones[subZone.n]} unlocked!`, "good")
end

function ZoneService:LeaveArena(player: Player)
	local arena = arenas[player]
	if not arena then
		return
	end
	arenas[player] = nil
	EnemyService:EndArena(arena.key)
	local back = byId[Zones.subZoneId(arena.zoneId, Zones.BOSS_SUBZONE)]
	if player.Parent and back then
		teleport(player, back.entrance.CFrame)
	end
	task.delay(2, function()
		arena.model:Destroy()
		usedSlots[arena.slot] = nil
	end)
end

function ZoneService:EnterArena(player: Player, zoneId: string)
	if arenas[player] or not canTeleport(player) then
		return
	end
	local template = ServerStorage.BossArenas:FindFirstChild(zoneId)
	if not (template and template:IsA("Model") and template.PrimaryPart) then
		lastTeleport[player] = os.clock()
		notify(player, "The boss arena is not built yet", "bad")
		return
	end
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	local model = template:Clone()
	model:PivotTo(CFrame.new(Playtest.ArenaOrigin + Vector3.new(slot * Playtest.ArenaSpacing, 0, 0)))
	model.Parent = workspace.BossArenas
	local key = `arena_{player.UserId}`
	arenas[player] = { model = model, key = key, zoneId = zoneId, slot = slot }

	local pads = (model:FindFirstChild("PlayerSpawns") :: Instance):GetChildren()
	local pad = pads[1] :: BasePart
	local bossPad = model:FindFirstChild("BossSpawn") :: BasePart
	teleport(player, CFrame.lookAt(pad.Position, Vector3.new(bossPad.Position.X, pad.Position.Y, bossPad.Position.Z)))

	local door = model:FindFirstChild("Door")
	local doorPart = if door and door:IsA("Model") then door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart", true) else door
	if doorPart and doorPart:IsA("BasePart") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Leave"
		prompt.ObjectText = "Boss arena"
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 18
		prompt.RequiresLineOfSight = false
		prompt.Parent = doorPart
		prompt.Triggered:Connect(function(who)
			ZoneService:LeaveArena(who)
		end)
	end

	EnemyService:StartArena(key, model, zoneId, function()
		notify(player, `{Zones.ById[zoneId].Boss} defeated!`, "good")
		task.delay(Playtest.ArenaCleanupSeconds, function()
			if arenas[player] and arenas[player].model == model then
				ZoneService:LeaveArena(player)
			end
		end)
	end)
end

local function hookWorld()
	local hub = workspace:FindFirstChild("Hub")
	local portals = hub and hub:FindFirstChild("Portals")
	for _, portal in ipairs(if portals then portals:GetChildren() else {}) do
		local zoneId = portal:GetAttribute("ZoneId")
		if portal:IsA("BasePart") and zoneId then
			portal.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player then
					ZoneService:EnterZone(player, zoneId)
				end
			end)
		end
	end
	for _, subZone in ipairs(subZones) do
		local zone = Zones.ById[subZone.zoneId]
		local hubReturn = subZone.folder:FindFirstChild("HubReturn")
		if hubReturn and hubReturn:IsA("BasePart") then
			hubReturn.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player and canTeleport(player) then
					ZoneService:ToHub(player)
				end
			end)
		end
		local gate = subZone.folder:FindFirstChild("Gate")
		if gate and gate:IsA("Model") and gate.PrimaryPart then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "GatePrompt"
			prompt.ObjectText = zone.SubZones[subZone.n]
			prompt.ActionText = `Open ({Format.number(Zones.subZonePrice(subZone.zoneId, subZone.n))} Gold)`
			prompt.HoldDuration = 0.4
			prompt.MaxActivationDistance = 18
			prompt.RequiresLineOfSight = false
			prompt.Parent = gate.PrimaryPart
			prompt.Triggered:Connect(function(player)
				tryUnlock(player, subZone)
			end)
		end
		local bossGate = subZone.folder:FindFirstChild("BossGate")
		local interact = bossGate and bossGate:FindFirstChild("Interact", true)
		local bossPrompt = interact and interact:FindFirstChildOfClass("ProximityPrompt")
		if bossPrompt then
			bossPrompt.Triggered:Connect(function(player)
				ZoneService:EnterArena(player, subZone.zoneId)
			end)
		end
	end
end

function ZoneService:Init()
	for _, zone in ipairs(Zones.List) do
		local zoneFolder = workspace.Zones:FindFirstChild(zone.Id)
		for n = 1, Zones.SUBZONE_COUNT do
			local id = Zones.subZoneId(zone.Id, n)
			local folder = zoneFolder and zoneFolder:FindFirstChild(id)
			local area = folder and folder:FindFirstChild("Area")
			local entrance = folder and folder:FindFirstChild("Entrance")
			if folder and area and area:IsA("BasePart") and entrance and entrance:IsA("BasePart") then
				local subZone: SubZone = { id = id, zoneId = zone.Id, n = n, folder = folder, area = area, entrance = entrance }
				table.insert(subZones, subZone)
				byId[id] = subZone
			end
		end
	end
	hookWorld()

	local function onPlayer(player: Player)
		player:SetAttribute("ZoneId", "Hub")
		player:SetAttribute("SubZoneId", "Hub")
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
			if humanoid then
				humanoid.Died:Connect(function()
					ZoneService:LeaveArena(player)
				end)
			end
			-- Respawn at the start of the current sub-zone (DESIGN.md section 2, Death).
			local subZone = byId[player:GetAttribute("RespawnSubZone") or ""]
			if subZone and character:WaitForChild("HumanoidRootPart", 10) then
				task.wait(0.3)
				teleport(player, subZone.entrance.CFrame)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ZoneService:LeaveArena(player)
		lastTeleport[player] = nil
	end)
end

-- Location loop: where is each player, are they allowed there, which sub-zones need enemies.
function ZoneService:Start()
	while true do
		local occupied: { [string]: boolean } = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local root = rootOf(player)
			local arena = arenas[player]
			if root and arena then
				setLocation(player, arena.zoneId, arena.zoneId .. "_Arena")
				player:SetAttribute("RespawnSubZone", Zones.subZoneId(arena.zoneId, Zones.BOSS_SUBZONE))
			elseif root then
				local position = root.Position
				local found: SubZone? = nil
				for _, subZone in ipairs(subZones) do
					if inside(subZone.area, position) then
						found = subZone
						break
					end
				end
				if found and isUnlocked(player, found) then
					occupied[found.id] = true
					setLocation(player, found.zoneId, found.id)
					player:SetAttribute("RespawnSubZone", found.id)
				elseif found then
					-- Inside a sub-zone that is still locked for this player: send them back.
					local n = found.n - 1
					while n > 1 and not isUnlocked(player, byId[Zones.subZoneId(found.zoneId, n)]) do
						n -= 1
					end
					if canTeleport(player) then
						teleport(player, byId[Zones.subZoneId(found.zoneId, n)].entrance.CFrame)
						notify(player, "This area is still locked", "bad")
					end
				elseif Vector3.new(position.X, 0, position.Z).Magnitude < Playtest.HubRadius then
					setLocation(player, "Hub", "Hub")
					player:SetAttribute("RespawnSubZone", nil)
				end
			end
		end
		EnemyService:SetOccupied(occupied)
		task.wait(Playtest.ZoneCheckInterval)
	end
end

return ZoneService
