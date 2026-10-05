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
local Attributes = require(ReplicatedStorage.GameSystem.Config.Attributes)
local ServerStorage = game:GetService("ServerStorage")
local Economy = require(ReplicatedStorage.GameSystem.Config.Economy)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Products = require(ReplicatedStorage.GameSystem.Config.Products)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local RebirthShop = require(ReplicatedStorage.GameSystem.Config.RebirthShop)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local ArmorService = require(script.Parent.ArmorService)
local BoostService = require(script.Parent.BoostService)
local IndexService = require(script.Parent.IndexService)
local RewardService = require(script.Parent.RewardService)
local Quests = require(ReplicatedStorage.GameSystem.Config.Quests)
local IndexBook = require(ReplicatedStorage.GameSystem.Config.IndexBook)
local Armor = require(ReplicatedStorage.GameSystem.Config.Armor)
local Pets = require(ReplicatedStorage.GameSystem.Config.Pets)
local ShopService = require(script.Parent.ShopService)
local WeaponService = require(script.Parent.WeaponService)
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
		local profile = DataService:Get(player)
		if profile and not profile.Zones[zone.Id] then
			local open = table.clone(profile.Zones)
			open[zone.Id] = true
			DataService:Set(player, "Zones", open)
		end
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
		local open = {}
		for _, zone in ipairs(Zones.List) do
			open[zone.Id] = true
		end
		DataService:Set(player, "Zones", open)
		return true, "All zones and gates unlocked"
	end,
	-- lockAll: back to a new player's unlocks (Plains only, no gates), to test the teleport menu
	lockAll = function(player)
		DataService:Set(player, "Zones", { [Zones.List[1].Id] = true })
		DataService:Set(player, "SubZones", {})
		return true, "Zones and gates locked"
	end,
	-- unlockZone(zoneId, gates?): opens one zone and its gates up to `gates` (1-4)
	unlockZone = function(player, zoneId, gates)
		local zone = zoneOf(zoneId)
		local profile = DataService:Get(player)
		if not zone or not profile then
			return false, "unlockZone(zoneId, gates?)"
		end
		local open = table.clone(profile.Zones)
		open[zone.Id] = true
		DataService:Set(player, "Zones", open)
		unlockUpTo(player, zone.Id, math.clamp(math.floor(tonumber(gates) or 1), 1, Zones.SUBZONE_COUNT))
		return true, `{zone.Name} unlocked`
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
		return WeaponService:Equip(player, uid)
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
		WeaponService:Equip(player, nil)
		DataService:Set(player, "EquippedArmor", {})
		DataService:Set(player, "EquippedPets", {})
		return true, "Equipment cleared"
	end,
	-- lockZone(zoneId): closes one zone again (not the first one), to test the shop's locked cards
	lockZone = function(player, zoneId)
		local zone = zoneOf(zoneId)
		local profile = DataService:Get(player)
		if not zone or not profile or zone.Index == 1 then
			return false, "lockZone(zoneId) - the first zone stays open"
		end
		local open = table.clone(profile.Zones)
		open[zone.Id] = nil
		DataService:Set(player, "Zones", open)
		return true, `{zone.Name} locked`
	end,
	-- giveWeapon(weaponId, rarity): adds a copy for free (no pity change)
	giveWeapon = function(player, weaponId, rarity)
		local profile = DataService:Get(player)
		if not profile or typeof(weaponId) ~= "string" or not Weapons.ById[weaponId] then
			return false, "giveWeapon(weaponId, rarity)"
		end
		local owned = table.clone(profile.Weapons)
		owned[HttpService:GenerateGUID(false)] = { id = weaponId, rarity = tier(rarity) }
		DataService:Set(player, "Weapons", owned)
		return true, `Gave {Rarities.get(tier(rarity)).Name} {Weapons.ById[weaponId].Name}`
	end,
	-- forceRarity(rarity): the next BuyWeapon of this player rolls exactly this tier (0 = off)
	forceRarity = function(player, rarity)
		local n = math.floor(tonumber(rarity) or 0)
		if n < 0 or n > #Rarities.List then
			return false, "forceRarity(1-8, 0 = off)"
		end
		ShopService:ForceNext(player, if n > 0 then n else nil)
		return true, if n > 0 then `Next purchase: {Rarities.get(n).Name}` else "Next purchase: normal odds"
	end,
	-- setPity(n): both pity counters (Epic at 30, Legendary at 100) = n
	setPity = function(player, value)
		local n = math.floor(tonumber(value) or -1)
		if n < 0 or n > 1000 then
			return false, "setPity(0-1000)"
		end
		DataService:Set(player, "PityCounter", n)
		DataService:Set(player, "PityLegendary", n)
		return true, `Pity counters = {n}`
	end,
	-- resetWeapons(): no weapons, nothing equipped, pity counters 0
	resetWeapons = function(player)
		if not DataService:Get(player) then
			return false, nil
		end
		DataService:Set(player, "Weapons", {})
		DataService:Set(player, "PityCounter", 0)
		DataService:Set(player, "PityLegendary", 0)
		WeaponService:Equip(player, nil)
		return true, "Weapons reset"
	end,
	-- setPoints(attr, n): points of one attribute (0..40), free
	setPoints = function(player, attribute, value)
		local profile = DataService:Get(player)
		local n = math.floor(tonumber(value) or -1)
		if not profile or typeof(attribute) ~= "string" or not Attributes.ById[attribute] or n < 0 or n > Attributes.MaxPoints then
			return false, "setPoints(attribute, 0-40)"
		end
		local values = table.clone(profile.Attributes or Attributes.empty())
		values[attribute] = n
		DataService:Set(player, "Attributes", values)
		return true, `{attribute} = {n}`
	end,
	setRebirths = function(player, value)
		local n = math.floor(tonumber(value) or -1)
		if n < 0 or n > 12 then return false, "setRebirths(0-12)" end
		DataService:Set(player, "Rebirths", n)
		return true, `Rebirths = {n}`
	end,
	setCredits = function(player, value)
		local n = math.floor(tonumber(value) or -1)
		if n < 0 or n > 1000 then return false, "setCredits(0-1000)" end
		DataService:Set(player, "RebirthCredits", n)
		return true, `Rebirth Credits = {n}`
	end,
	-- wipeForRebirth(): the Rebirth reset of docs/menu_systems_brief.txt section 7, to test the rules before the
	-- Rebirth system exists. Reset: Gold, Attributes, Weapons, Armor, Eggs, non-premium Pets and whatever was
	-- equipped from them. Kept: Diamonds, Keys, premium pets, Index, Credits, Rebirth upgrades, boosts, settings,
	-- passes (everything else is untouched).
	wipeForRebirth = function(player)
		local profile = DataService:Get(player)
		if not profile then return false, nil end
		DataService:Set(player, "Gold", 0)
		DataService:Set(player, "Attributes", Attributes.empty())
		DataService:Set(player, "Weapons", {})
		DataService:Set(player, "EquippedWeapon", nil)
		DataService:Set(player, "Armor", {})
		DataService:Set(player, "EquippedArmor", {})
		DataService:Set(player, "Eggs", {})
		local pets, kept = {}, 0
		for uid, pet in pairs(profile.Pets or {}) do
			if pet.premium then
				pets[uid] = pet
				kept += 1
			end
		end
		DataService:Set(player, "Pets", pets)
		local equipped = {}
		for _, uid in ipairs(profile.EquippedPets or {}) do
			if pets[uid] then
				table.insert(equipped, uid)
			end
		end
		DataService:Set(player, "EquippedPets", equipped)
		WeaponService:Refresh(player)
		return true, `Rebirth wipe done ({kept} premium pet{if kept == 1 then "" else "s"} kept)`
	end,
	-- giveEgg(zone, rarity, count?): zone = 1..12 or a zone id; loot eggs (auto-sold when the storage is full)
	giveEgg = function(player, zoneValue, rarity, howMany)
		local zone = if typeof(zoneValue) == "number" then Zones.List[zoneValue] else zoneOf(zoneValue)
		local n = math.floor(tonumber(howMany) or 1)
		if not zone or n < 1 or n > 100 then return false, "giveEgg(zone, rarity, count?)" end
		local sold = 0
		for i = 1, n do
			local _, what = PetService:GiveEgg(player, zone.Index, tier(rarity), n > 1)
			if what == "sold" then
				sold += 1
			end
		end
		return true, `{n} {Rarities.get(tier(rarity)).Name} {zone.Name} egg{if n == 1 then "" else "s"}` .. (if sold > 0 then ` ({sold} auto-sold)` else "")
	end,
	-- givePet(petId, rarity): premium pets keep their fixed rarity
	givePet = function(player, petId, rarity)
		if typeof(petId) ~= "string" or not Pets.ById[petId] then return false, "givePet(petId, rarity)" end
		local uid = PetService:GivePet(player, petId, tier(rarity))
		return uid ~= nil, `{Pets.ById[petId].Name} added`
	end,
	-- giveArmor(id, rarity, count?) or giveArmor(zone, rarity) = the full set of a zone (zone = 1..12 or a zone id)
	giveArmor = function(player, what, rarity, howMany)
		local n = math.floor(tonumber(howMany) or 1)
		if n < 1 or n > 100 then return false, "giveArmor(id | zone, rarity, count?)" end
		local ids = {}
		if typeof(what) == "string" and Armor.ById[what] then
			ids = { what }
		else
			local zone = if typeof(what) == "number" then Zones.List[what] else zoneOf(what)
			if not zone then return false, "giveArmor(id | zone, rarity, count?)" end
			for _, slot in ipairs(Armor.SLOTS) do
				table.insert(ids, `{string.lower(zone.Id)}_{string.lower(slot)}`)
			end
		end
		local given = 0
		for _ = 1, n do
			for _, id in ipairs(ids) do
				if ArmorService:GiveArmor(player, id, tier(rarity), #ids * n > 1) then
					given += 1
				end
			end
		end
		return true, `{given} armor piece{if given == 1 then "" else "s"} given`
	end,
	-- discover(entryId | "<Tab>:<ZoneId>" | "<Tab>:All" | "All", rarity?): marks Index entries as found
	discover = function(player, what, rarity)
		if typeof(what) ~= "string" then return false, "discover(entryId | Tab:Zone | Tab:All | All, rarity?)" end
		local ids = {}
		if IndexBook.ById[what] then
			ids = { what }
		else
			local tabName, key = string.match(what, "^(%a+):(%a+)$")
			for _, tab in ipairs(IndexBook.TABS) do
				for _, group in ipairs(IndexBook.Groups[tab]) do
					if what == "All" or (tab == tabName and (key == "All" or key == group.Key)) then
						for _, entry in ipairs(group.Entries) do
							table.insert(ids, entry.Id)
						end
					end
				end
			end
		end
		if #ids == 0 then return false, "Nothing matches " .. what end
		for _, id in ipairs(ids) do
			IndexService:Discover(player, id, tier(rarity))
		end
		return true, `{#ids} Index entr{if #ids == 1 then "y" else "ies"} discovered`
	end,
	-- progressQuest(kind, n): quest progress as if the game system had reported it
	progressQuest = function(player, kind, n)
		if typeof(kind) ~= "string" or not Quests.ById[kind] then return false, "progressQuest(kind, n)" end
		RewardService.progress(player, kind, tonumber(n) or 1)
		return true, nil
	end,
	-- addPlaytime(minutes): play time of today (playtime gifts)
	addPlaytime = function(player, minutes)
		local n = tonumber(minutes)
		if not n or n <= 0 or n > 1440 then return false, "addPlaytime(minutes)" end
		RewardService:AddPlaytime(player, n * 60)
		return true, `+{n} min played`
	end,
	-- setDaily(streak, daysAgo): the daily reward record (daysAgo 1 = claimed yesterday, so today continues the streak)
	setDaily = function(player, streak, daysAgo)
		local s, d = math.floor(tonumber(streak) or -1), math.floor(tonumber(daysAgo) or -1)
		if s < 0 or s > #Quests.Daily or d < 0 then return false, "setDaily(streak 0..7, daysAgo)" end
		DataService:Set(player, "Daily", { Streak = s, LastDay = if s == 0 then 0 else Quests.day(os.time()) - d })
		return true, `Daily streak {s}, last claim {d} day(s) ago`
	end,
	-- resetQuests(): today's quests, play time and codes start again (tests)
	resetQuests = function(player)
		DataService:Set(player, "Quests", { Day = 0, List = {} })
		DataService:Set(player, "Playtime", { Day = 0, Seconds = 0, Claimed = {} })
		DataService:Set(player, "Codes", {})
		return true, "Quests, play time and codes reset (quests regenerate on the next tick or claim)"
	end,
	-- simulateQuests(day?): the 3 quests of a UTC day (default today) and how often each kind comes in 365 days
	simulateQuests = function(player, day)
		local d = math.floor(tonumber(day) or Quests.day(os.time()))
		local counts = {}
		for i = 0, 364 do
			for _, id in ipairs(Quests.forDay(d + i)) do
				counts[id] = (counts[id] or 0) + 1
			end
		end
		local lines = { `Day {d}: {table.concat(Quests.forDay(d), ", ")}` }
		for _, kind in ipairs(Quests.Pool) do
			table.insert(lines, `  {kind.Id}: {counts[kind.Id] or 0} / 365 days`)
		end
		print(table.concat(lines, "\n"))
		return true, lines[1]
	end,
	-- clearIndex(): empties the Index and its claimed rewards (tests)
	clearIndex = function(player)
		DataService:Set(player, "Index", {})
		DataService:Set(player, "IndexClaimed", {})
		return true, "Index cleared"
	end,
	-- giveBoost(id, seconds): adds time to a boost (GoldX2)
	giveBoost = function(player, id, seconds)
		local n = tonumber(seconds)
		if typeof(id) ~= "string" or not n or n <= 0 or n > 86400 then return false, "giveBoost(id, seconds)" end
		local expires = BoostService:Add(player, id, n)
		return expires ~= nil, if expires then `{id} active for {math.floor((expires - os.time()) / 60)} min` else "Unknown boost"
	end,
	-- clearPets(): removes every pet and egg (tests)
	clearPets = function(player)
		DataService:Set(player, "Pets", {})
		DataService:Set(player, "EquippedPets", {})
		DataService:Set(player, "Eggs", {})
		PetService:UpdateFollowers(player)
		return true, "Pets and eggs cleared"
	end,
	-- simulateEggs(n): the egg odds and Egg Luck check (ServerStorage.DevTools.EggSim), printed in the output
	simulateEggs = function(player, howMany)
		local sim = ServerStorage:FindFirstChild("DevTools") and ServerStorage.DevTools:FindFirstChild("EggSim")
		local n = math.floor(tonumber(howMany) or 100000)
		if not sim or n < 1000 or n > 1000000 then return false, "simulateEggs(n = 1000..1000000)" end
		local report, maxZ = require(sim :: ModuleScript)(n)
		print(report)
		return maxZ < 4, string.format("Egg simulation: largest gap %.2f sd (see the output)", maxZ)
	end,
	-- setPass(name, on): a game pass flag in the profile (tests: ExtraPetSlots, AutoAttack...)
	setPass = function(player, name, on)
		local profile = DataService:Get(player)
		if not profile or typeof(name) ~= "string" or Products.Passes[name] == nil then return false, "setPass(name, on)" end
		local passes = table.clone(profile.Passes)
		passes[name] = if on == false then nil else true
		DataService:Set(player, "Passes", passes)
		return true, `{name} {if on == false then "removed" else "given"}`
	end,
	-- setUpgrade(id, level): a Rebirth Shop upgrade level (tests: EggLuck)
	setUpgrade = function(player, id, level)
		local profile = DataService:Get(player)
		local upgrade = if typeof(id) == "string" then RebirthShop.ById[id] else nil
		local n = math.floor(tonumber(level) or -1)
		if not profile or not upgrade or n < 0 or n > upgrade.Max then return false, "setUpgrade(id, level)" end
		local levels = table.clone(profile.RebirthUpgrades)
		levels[id] = if n > 0 then n else nil
		DataService:Set(player, "RebirthUpgrades", levels)
		return true, `{upgrade.Name} level {n}`
	end,
	-- runStatsTests(): the Util/Stats sample profiles (ServerStorage.DevTools.StatsTests)
	runStatsTests = function(player)
		local tests = ServerStorage:FindFirstChild("DevTools") and ServerStorage.DevTools:FindFirstChild("StatsTests")
		if not tests then return false, "StatsTests not found" end
		local passed, total, report = require(tests :: ModuleScript)()
		print(report)
		return passed == total, `Stats tests: {passed}/{total} passed`
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
	-- godMode(on): enemies and bosses deal no damage to this player (not saved)
	godMode = function(player, on)
		player:SetAttribute("GodMode", on == true or on == "true" or on == 1)
		return true, if player:GetAttribute("GodMode") then "God mode on" else "God mode off"
	end,
	-- enemyHit(raw): an enemy-style hit through CombatService:DamagePlayer (tests roll / block / defense)
	enemyHit = function(player, value)
		local n = amount(value)
		if not n then return false, "enemyHit(amount)" end
		local CombatService = require(script.Parent.CombatService) :: any
		return true, `dealt {CombatService:DamagePlayer(player, n)}`
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
