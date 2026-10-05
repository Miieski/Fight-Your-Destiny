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
local Economy = require(ReplicatedStorage.GameSystem.Config.Economy)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)

local ZoneService = { Priority = 4 }

type SubZone = { id: string, zoneId: string, n: number, folder: Instance, area: BasePart, entrance: BasePart }
type Arena = { model: Model, key: string, zoneId: string, slot: number }

local subZones: { SubZone } = {}
local byId: { [string]: SubZone } = {}
local lastTeleport: { [Player]: number } = {}
local lastMenuTeleport: { [Player]: number } = {} -- teleport menu cooldown
local lastDamage: { [Player]: number } = {} -- "in combat" = took damage recently
local arenas: { [Player]: Arena } = {}
local usedSlots: { [number]: boolean } = {}

-- kind: "info" | "reward" | "error" | "loot" | "death" (see GameClient/UI/Notifier)
local function notify(player: Player, text: string, kind: string?)
	Net.fire(player, "Notify", { Kind = kind or "info", Text = text })
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
	if player:GetAttribute("CurrentSubZone") ~= subZoneId then
		player:SetAttribute("CurrentZone", zoneId)
		player:SetAttribute("CurrentSubZone", subZoneId)
		DataService:Set(player, "CurrentZone", zoneId)
	end
end

function ZoneService:ToHub(player: Player)
	local hub = workspace:FindFirstChild("Hub")
	local spawn = hub and hub:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		ZoneService:LeaveArena(player, true)
		player:SetAttribute("RespawnSubZone", nil)
		teleport(player, spawn.CFrame)
	end
end

-- Test/admin teleport straight to the Entrance of a sub-zone. It does not check unlocks: the caller
-- (AdminService) unlocks the sub-zones first, otherwise the location loop sends the player back.
function ZoneService:TeleportTo(player: Player, zoneId: string, n: number): boolean
	local subZone = byId[Zones.subZoneId(zoneId, n)]
	if not (subZone and hasGround(subZone.entrance.Position)) then
		local zone = Zones.ById[zoneId]
		notify(player, `{if zone then zone.Name else zoneId} is not built yet`, "error")
		return false
	end
	ZoneService:LeaveArena(player, true)
	teleport(player, subZone.entrance.CFrame)
	return true
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
		notify(player, `{if zone then zone.Name else zoneId} is not built yet`, "error")
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
		notify(player, "Open the previous gate first", "error")
		return
	end
	local price = if Playtest.FreeGates then 0 else Zones.subZonePrice(subZone.zoneId, subZone.n)
	if profile.Gold < price then
		notify(player, `Not enough Gold: {Format.number(price)} needed`, "error")
		return
	end
	DataService:AddGold(player, -price)
	local unlocked = table.clone(profile.SubZones)
	unlocked[subZone.id] = true
	DataService:Set(player, "SubZones", unlocked)
	notify(player, `{Zones.ById[subZone.zoneId].SubZones[subZone.n]} unlocked!`, "reward")
end

function ZoneService:LeaveArena(player: Player, stay: boolean?)
	local arena = arenas[player]
	if not arena then
		return
	end
	arenas[player] = nil
	EnemyService:EndArena(arena.key)
	local back = byId[Zones.subZoneId(arena.zoneId, Zones.BOSS_SUBZONE)]
	if player.Parent and back and not stay then
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
		notify(player, "The boss arena is not built yet", "error")
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
		notify(player, `{Zones.ById[zoneId].Boss} defeated!`, "reward")
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
			-- docs/menu_systems_brief.txt section 1: a hub portal sends the player straight to sub-zone 1 of its
			-- zone. The touch is detected on the client (Controllers/PortalController), which asks "UsePortal";
			-- the server validates it below. The Zones menu is the only place to pick another sub-zone.
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

	-- "Get diamonds" in the Shop offers a trip to the hub's Diamond Shop.
	Net.handle("GoToHub", function(player: Player)
		ZoneService:ToHub(player)
		return true
	end, 2)

	-- Hub portal: straight to the Entrance of sub-zone 1. Same rules as the Teleport menu (zone unlocked,
	-- not in a boss arena, no damage in the last CombatSeconds, shared cooldown); admins skip the arena,
	-- combat and cooldown checks, not the unlocks.
	Net.handle("UsePortal", function(player: Player, zoneId: any)
		local rules = Zones.TELEPORT
		local admin = player:GetAttribute("IsAdmin") == true
		local zone = if typeof(zoneId) == "string" then Zones.ById[zoneId] else nil
		if not zone then
			return false, "Bad request"
		end
		if Zones.NOT_BUILT[zone.Id] then
			return false, `{zone.Name} is coming soon`
		end
		local profile = DataService:Get(player)
		if not (profile and rootOf(player)) then
			return false, "Not ready yet"
		end
		if zone.Index > 1 and not profile.Zones[zone.Id] then
			return false, `{zone.Name} locked: {Zones.requirementText(zone.Id)}`
		end
		if not admin then
			if arenas[player] then
				return false, "Leave the boss arena first"
			end
			if os.clock() - (lastDamage[player] or -math.huge) < rules.CombatSeconds then
				return false, "You can't teleport during a fight"
			end
			if os.clock() - (lastMenuTeleport[player] or -math.huge) < rules.Cooldown then
				return false, "Teleport is recharging"
			end
		end
		local subZone = byId[Zones.subZoneId(zone.Id, 1)]
		if not (subZone and hasGround(subZone.entrance.Position)) then
			return false, `{zone.Name} is not built yet`
		end
		lastMenuTeleport[player] = os.clock()
		ZoneService:LeaveArena(player, true)
		teleport(player, subZone.entrance.CFrame)
		return true, `Welcome to {zone.Name}!`
	end, 0.5)

	-- Teleport menu: every request is validated here (unlocks, boss arena, combat, cooldown).
	-- Admins skip the arena, combat and cooldown checks, not the unlocks.
	Net.handle("Teleport", function(player: Player, zoneId: any, n: any)
		local rules = Zones.TELEPORT
		local admin = player:GetAttribute("IsAdmin") == true
		if typeof(zoneId) ~= "string" then
			return false, "Bad request"
		end
		if arenas[player] and not admin then
			return false, "Leave the boss arena first"
		end
		if not admin then
			if os.clock() - (lastDamage[player] or -math.huge) < rules.CombatSeconds then
				return false, "You can't teleport during a fight"
			end
			if os.clock() - (lastMenuTeleport[player] or -math.huge) < rules.Cooldown then
				return false, "Teleport is recharging"
			end
		end
		local profile = DataService:Get(player)
		if not (profile and rootOf(player)) then
			return false, "Not ready yet"
		end
		if zoneId == "Hub" then
			lastMenuTeleport[player] = os.clock()
			ZoneService:ToHub(player)
			return true, "Teleported to the Hub"
		end
		local zone = Zones.ById[zoneId]
		if not zone or typeof(n) ~= "number" or n % 1 ~= 0 or n < 1 or n > Zones.SUBZONE_COUNT then
			return false, "Bad request"
		end
		if Zones.NOT_BUILT[zone.Id] then
			return false, `{zone.Name} is coming soon`
		end
		if zone.Index > 1 and not profile.Zones[zone.Id] then
			return false, `{zone.Name} locked: {Zones.requirementText(zone.Id)}`
		end
		local id = Zones.subZoneId(zone.Id, n)
		if n > 1 and not profile.SubZones[id] then
			return false, `{zone.SubZones[n]} locked: open its gate for {Format.number(Zones.subZonePrice(zone.Id, n))} Gold`
		end
		local subZone = byId[id]
		if not (subZone and hasGround(subZone.entrance.Position)) then
			return false, `{zone.Name} is not built yet`
		end
		lastMenuTeleport[player] = os.clock()
		ZoneService:LeaveArena(player, true)
		teleport(player, subZone.entrance.CFrame)
		return true, `Teleported to {zone.SubZones[n]}`
	end, 0.5)

	local function onPlayer(player: Player)
		player:SetAttribute("CurrentZone", "Hub")
		player:SetAttribute("CurrentSubZone", "Hub")
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
			if humanoid then
				local health = humanoid.Health
				humanoid.HealthChanged:Connect(function(value)
					if value < health then
						lastDamage[player] = os.clock()
					end
					health = value
				end)
				humanoid.Died:Connect(function()
					ZoneService:LeaveArena(player)
					-- Death penalty (DESIGN.md section 2): lose a share of the Gold.
					local profile = DataService:Get(player)
					local loss = if profile then math.floor(profile.Gold * Economy.DeathGoldLoss) else 0
					if loss > 0 then
						DataService:AddGold(player, -loss)
						Net.fire(player, "Notify", {
							Kind = "death",
							Text = string.format(UIConfig.Text.DeathGold, math.floor(Economy.DeathGoldLoss * 100 + 0.5), Format.number(loss)),
						})
					end
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
		lastMenuTeleport[player] = nil
		lastDamage[player] = nil
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
						notify(player, "This area is still locked", "error")
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
