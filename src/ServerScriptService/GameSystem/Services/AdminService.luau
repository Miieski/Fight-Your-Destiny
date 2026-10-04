--!strict
-- Owner-only commands (DESIGN.md section 13, docs/ui_hud_brief.txt section 3). Every command is
-- checked here: the admin button on the client grants nothing. Fake equipment and badges exist only
-- to test the UI before the real systems are built.
--   Net.request("Admin", command, ...) -> ok, message
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Admins = require(ReplicatedStorage.GameSystem.Config.Admins)
local Economy = require(ReplicatedStorage.GameSystem.Config.Economy)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local DataService = require(script.Parent.DataService)
local ZoneService = require(script.Parent.ZoneService)

local AdminService = { Priority = 6 }

local NOTIFY_KINDS = { loot = true, reward = true, error = true, info = true, death = true }
local MAX_TEXT = 120

local function amount(value: any, allowNegative: boolean?): number?
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	local limit = Admins.MaxAmount
	if value > limit or value < (if allowNegative then -limit else 0) then
		return nil
	end
	return value
end

local function tier(value: any): number
	return Rarities.get(tonumber(value) or 1).Tier
end

local function zoneOf(value: any): any
	return if typeof(value) == "string" then Zones.ById[value] else nil
end

local function unlockUpTo(player: Player, zoneId: string, n: number)
	local profile = DataService:Get(player)
	if profile then
		local unlocked = table.clone(profile.SubZones)
		for i = 2, math.min(n, Zones.SUBZONE_COUNT) do
			unlocked[Zones.subZoneId(zoneId, i)] = true
		end
		DataService:Set(player, "SubZones", unlocked)
	end
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

type Command = (Player, ...any) -> (boolean, string?)

local COMMANDS: { [string]: Command } = {
	setGold = function(player, value)
		local n = amount(value)
		if not n then return false, "Invalid amount" end
		DataService:Set(player, "Gold", n)
		return true, "Gold = " .. Format.number(n)
	end,
	addGold = function(player, value)
		local n = amount(value, true)
		if not n then return false, "Invalid amount" end
		DataService:AddGold(player, n)
		return true, "Gold " .. (if n >= 0 then "+" else "") .. Format.number(n)
	end,
	setDiamonds = function(player, value)
		local n = amount(value)
		if not n then return false, "Invalid amount" end
		DataService:Set(player, "Diamonds", math.floor(n))
		return true, "Diamonds = " .. Format.number(n)
	end,
	addDiamonds = function(player, value)
		local n = amount(value, true)
		if not n then return false, "Invalid amount" end
		DataService:AddDiamonds(player, n)
		return true, "Diamonds " .. (if n >= 0 then "+" else "") .. Format.number(n)
	end,
	-- notify(kind, text, rarity?): sends a toast through the real server -> client path.
	notify = function(player, kind, text, rarity)
		if not NOTIFY_KINDS[kind] or typeof(text) ~= "string" or #text == 0 or #text > MAX_TEXT then
			return false, "notify(kind, text, rarity)"
		end
		Net.fire(player, "Notify", { Kind = kind, Text = text, Rarity = if rarity ~= nil then tier(rarity) else nil })
		return true, nil
	end,
	-- setZone(zoneId, n): n = 1..4 sub-zone, 5 = boss arena; zoneId "Hub" = hub. Moves the player
	-- there (unlocking the gates on the way), so CurrentZone / CurrentSubZone update the normal way.
	setZone = function(player, zoneId, n)
		if zoneId == "Hub" then
			ZoneService:ToHub(player)
			return true, nil
		end
		local zone = zoneOf(zoneId)
		local sub = math.floor(tonumber(n) or 1)
		if not zone or sub < 1 or sub > Zones.SUBZONE_COUNT + 1 then
			return false, "setZone(zoneId, 1-5)"
		end
		unlockUpTo(player, zone.Id, sub)
		if sub > Zones.SUBZONE_COUNT then
			ZoneService:EnterArena(player, zone.Id)
		else
			ZoneService:TeleportTo(player, zone.Id, sub)
		end
		return true, nil
	end,
	unlockAll = function(player)
		local unlocked = {}
		for _, zone in ipairs(Zones.List) do
			for i = 2, Zones.SUBZONE_COUNT do
				unlocked[Zones.subZoneId(zone.Id, i)] = true
			end
		end
		DataService:Set(player, "SubZones", unlocked)
		return true, "All gates unlocked"
	end,
	-- equipWeaponFake(zoneId, rarity, category?)
	equipWeaponFake = function(player, zoneId, rarity, category)
		local zone = zoneOf(zoneId)
		local categoryId = if typeof(category) == "string" and Weapons.CategoryById[category] then category else "Sword"
		local profile = DataService:Get(player)
		if not zone or not profile then return false, "equipWeaponFake(zoneId, rarity, category?)" end
		local uid = HttpService:GenerateGUID(false)
		local owned = table.clone(profile.Weapons)
		owned[uid] = { id = Weapons.idOf(zone.Id, categoryId), rarity = tier(rarity) }
		DataService:Set(player, "Weapons", owned)
		DataService:Set(player, "EquippedWeapon", uid)
		return true, nil
	end,
	-- equipArmorFake(slot, zoneId, rarity)
	equipArmorFake = function(player, slot, zoneId, rarity)
		local zone = zoneOf(zoneId)
		local profile = DataService:Get(player)
		if not table.find(Economy.ArmorSlots, slot) or not zone or not profile then return false, "equipArmorFake(slot, zoneId, rarity)" end
		local uid = HttpService:GenerateGUID(false)
		local owned = table.clone(profile.Armor)
		owned[uid] = { id = string.lower(zone.Id) .. "_" .. string.lower(slot), slot = slot, rarity = tier(rarity) }
		local equipped = table.clone(profile.EquippedArmor)
		equipped[slot] = uid
		DataService:Set(player, "Armor", owned)
		DataService:Set(player, "EquippedArmor", equipped)
		return true, nil
	end,
	-- equipPetFake(slot, rarity): slot 1..PetSlots
	equipPetFake = function(player, slot, rarity)
		local index = math.floor(tonumber(slot) or 0)
		local profile = DataService:Get(player)
		if index < 1 or index > Economy.PetSlots or not profile then return false, "equipPetFake(slot 1-" .. Economy.PetSlots .. ", rarity)" end
		local uid = HttpService:GenerateGUID(false)
		local pets = table.clone(profile.Pets)
		pets[uid] = { id = "plains_pet1", rarity = tier(rarity), premium = false }
		local equipped = table.clone(profile.EquippedPets)
		equipped[math.min(index, #equipped + 1)] = uid
		DataService:Set(player, "Pets", pets)
		DataService:Set(player, "EquippedPets", equipped)
		return true, nil
	end,
	clearEquipment = function(player)
		local profile = DataService:Get(player)
		if not profile then return false, nil end
		DataService:Set(player, "EquippedWeapon", nil)
		DataService:Set(player, "EquippedArmor", {})
		DataService:Set(player, "EquippedPets", {})
		return true, "Equipment cleared"
	end,
	damageSelf = function(player, value)
		local humanoid = humanoidOf(player)
		local n = amount(value)
		if not humanoid or not n then return false, "damageSelf(amount)" end
		humanoid:TakeDamage(n)
		return true, nil
	end,
	heal = function(player)
		local humanoid = humanoidOf(player)
		if not humanoid then return false, nil end
		humanoid.Health = humanoid.MaxHealth
		return true, nil
	end,
	-- setBadge(id, count): fake red badge counts (not saved).
	setBadge = function(player, id, count)
		local n = math.floor(tonumber(count) or 0)
		if not table.find(UIConfig.BadgeIds, id) or n < 0 or n > 999 then return false, "setBadge(id, count)" end
		local badges = table.clone(DataService:GetTransient(player, "DebugBadges") or {})
		badges[id] = if n > 0 then n else nil
		DataService:SetTransient(player, "DebugBadges", badges)
		return true, nil
	end,
}

function AdminService:IsAdmin(player: Player): boolean
	if Admins.AllowInStudio and RunService:IsStudio() then
		return true
	end
	if Admins.AllowCreator and game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return table.find(Admins.UserIds, player.UserId) ~= nil
end

function AdminService:Init()
	local function flag(player: Player)
		-- Only tells the client whether to show the admin window; it grants nothing.
		player:SetAttribute("IsAdmin", AdminService:IsAdmin(player))
	end
	Players.PlayerAdded:Connect(flag)
	for _, player in ipairs(Players:GetPlayers()) do
		flag(player)
	end
	Net.handle("Admin", function(player: Player, command: any, ...: any)
		if not AdminService:IsAdmin(player) then
			return false, "Not allowed"
		end
		local handler = if typeof(command) == "string" then COMMANDS[command] else nil
		if not handler then
			return false, "Unknown command"
		end
		return handler(player, ...)
	end, 0.05)
end

return AdminService
