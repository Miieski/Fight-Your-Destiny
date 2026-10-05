--!strict
-- Eggs and pets (docs/menu_systems_brief.txt B1, B2, B5). Every roll happens here.
--   Net.request("HatchEgg", uid)        -> true, { results = { Hatch } }  (a loot egg hatches for free)
--   Net.request("HatchAll")             -> true, { results = { Hatch }, left = eggs not hatched (pet storage full) }
--   Net.request("BuyPremiumEgg", zone)  -> Diamonds; the rarity is rolled with the shop odds, then it hatches
--   Net.request("EquipPet" | "UnequipPet" | "ReleasePet", uid), ("LockPet", uid, bool), ("EquipBestPets")
-- Hatch = { uid, petId, rarity, eggRarity, lucky (Egg Luck made it one tier rarer), zone }.
-- PetService:GiveEgg (loot, admin) auto-sells the egg when the egg storage is full.
-- The first equipped pets are listed in the player attribute "FollowPets" ("id:tier,id:tier") for the
-- client-side followers (GameClient/Controllers/PetFollowController).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local PetRarities = require(ReplicatedStorage.GameSystem.Config.PetRarities)
local Pets = require(ReplicatedStorage.GameSystem.Config.Pets)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local RebirthShop = require(ReplicatedStorage.GameSystem.Config.RebirthShop)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)
local RewardService = require(script.Parent.RewardService)

local PetService = { Priority = 5 }

export type Hatch = { uid: string, petId: string, rarity: number, eggRarity: number, lucky: boolean, zone: number }

local random = Random.new()
local MAX_TIER = #Rarities.List

local function count(map: { [any]: any }?): number
	local n = 0
	for _ in pairs(map or {}) do
		n += 1
	end
	return n
end

local function zoneByIndex(index: number): any
	return Zones.List[index]
end

local function zoneArg(value: any): any
	if typeof(value) == "number" and value % 1 == 0 then
		return zoneByIndex(value)
	elseif typeof(value) == "string" then
		return Zones.ById[value]
	end
	return nil
end

-- Equipped pet slots: 3, +2 with the Extra Pet Slots game pass.
function PetService.slots(profile: { [string]: any }): number
	local passes = profile.Passes or {}
	return PetRarities.Slots + (if passes.ExtraPetSlots then PetRarities.ExtraSlots else 0)
end

function PetService.eggLuck(profile: { [string]: any }): number
	return RebirthShop.bonus(profile.RebirthUpgrades, "EggLuck")
end

-- One hatch (pure; the simulation uses it): a uniform species of the zone, the egg's tier, then Egg Luck.
function PetService.hatchRoll(rng: Random, zone: number, eggTier: number, eggLuck: number): (string, number, boolean)
	local pool = Pets.ByZone[zoneByIndex(zone).Id]
	local species = pool[rng:NextInteger(1, #pool)]
	local tier = math.clamp(math.floor(eggTier), 1, MAX_TIER)
	local lucky = tier < MAX_TIER and rng:NextNumber() < eggLuck
	if lucky then
		tier += 1
	end
	return species.Id, tier, lucky
end

-- Players see the first pets of their equipped list following them.
function PetService:UpdateFollowers(player: Player)
	local profile = DataService:Get(player)
	local list = {}
	if profile then
		for _, uid in ipairs(profile.EquippedPets or {}) do
			local pet = profile.Pets[uid]
			if pet and Pets.ById[pet.id] then
				table.insert(list, `{pet.id}:{pet.rarity}`)
				if #list >= PetRarities.MaxFollowing then
					break
				end
			end
		end
	end
	player:SetAttribute("FollowPets", table.concat(list, ","))
end

local function markIndex(player: Player, profile: { [string]: any }, petId: string, tier: number)
	local best = profile.Index[petId]
	if typeof(best) ~= "number" or best < tier then
		local index = table.clone(profile.Index)
		index[petId] = tier
		DataService:Set(player, "Index", index)
	end
end

-- Adds a hatched pet (storage already checked by the caller).
local function addPet(player: Player, profile: { [string]: any }, petId: string, tier: number, premium: boolean?): string
	local uid = HttpService:GenerateGUID(false)
	local owned = table.clone(profile.Pets)
	owned[uid] = { id = petId, rarity = tier, premium = premium == true, locked = false }
	DataService:Set(player, "Pets", owned)
	markIndex(player, profile, petId, tier)
	return uid
end

local function hatchOne(player: Player, profile: { [string]: any }, eggUid: string): Hatch
	local egg = profile.Eggs[eggUid]
	local petId, tier, lucky = PetService.hatchRoll(random, egg.zone, egg.rarity, PetService.eggLuck(profile))
	local eggs = table.clone(profile.Eggs)
	eggs[eggUid] = nil
	DataService:Set(player, "Eggs", eggs)
	local uid = addPet(player, profile, petId, tier)
	RewardService.progress(player, "HatchEggs", 1)
	return { uid = uid, petId = petId, rarity = tier, eggRarity = egg.rarity, lucky = lucky, zone = egg.zone }
end

local function validEgg(egg: any): boolean
	return typeof(egg) == "table" and typeof(egg.zone) == "number" and zoneByIndex(egg.zone) ~= nil
		and typeof(egg.rarity) == "number" and egg.rarity >= 1 and egg.rarity <= MAX_TIER
end

local function storageFull(profile: { [string]: any }): boolean
	return count(profile.Pets) >= PetRarities.PetStorage
end

local FULL_TEXT = `Pet storage full ({PetRarities.PetStorage}). Release pets to hatch more.`

local function hatchEgg(player: Player, eggUid: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	if typeof(eggUid) ~= "string" or not validEgg(profile.Eggs[eggUid]) then
		return false, "Egg not found"
	end
	if storageFull(profile) then
		return false, FULL_TEXT
	end
	local result = hatchOne(player, profile, eggUid)
	DataService:Save(player)
	return true, { results = { result } }
end

local function hatchAll(player: Player): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local order = {}
	for uid, egg in pairs(profile.Eggs) do
		if validEgg(egg) then
			table.insert(order, { uid = uid, egg = egg })
		end
	end
	if #order == 0 then
		return false, "No eggs to hatch"
	end
	if storageFull(profile) then
		return false, FULL_TEXT
	end
	-- rarest eggs first, so a nearly full storage keeps the best ones
	table.sort(order, function(a, b)
		if a.egg.rarity ~= b.egg.rarity then
			return a.egg.rarity > b.egg.rarity
		end
		return a.egg.zone > b.egg.zone
	end)
	local room = PetRarities.PetStorage - count(profile.Pets)
	local results = {}
	for i = 1, math.min(room, #order) do
		table.insert(results, hatchOne(player, profile, order[i].uid))
	end
	DataService:Save(player)
	return true, { results = results, left = #order - #results }
end

local function buyPremiumEgg(player: Player, zoneValue: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local zone = zoneArg(zoneValue)
	if not zone then
		return false, "Unknown zone"
	end
	if not profile.Zones[zone.Id] then
		return false, `Unlock {zone.Name} first`
	end
	if storageFull(profile) then
		return false, FULL_TEXT
	end
	local price = PetRarities.premiumEggPrice(zone.Index)
	if typeof(profile.Diamonds) ~= "number" or profile.Diamonds < price then
		return false, "Not enough Diamonds"
	end
	-- nothing below yields: the Diamonds and the pet change together
	DataService:Set(player, "Diamonds", profile.Diamonds - price)
	local eggTier = ShopService.rollTier(random, 1)
	local petId, tier, lucky = PetService.hatchRoll(random, zone.Index, eggTier, PetService.eggLuck(profile))
	local uid = addPet(player, profile, petId, tier)
	RewardService.progress(player, "HatchEggs", 1)
	DataService:Save(player)
	return true, { results = { { uid = uid, petId = petId, rarity = tier, eggRarity = eggTier, lucky = lucky, zone = zone.Index, premiumEgg = true } }, cost = price }
end

local function setEquipped(player: Player, list: { string })
	DataService:Set(player, "EquippedPets", list)
	PetService:UpdateFollowers(player)
end

local function equipPet(player: Player, uid: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	if typeof(uid) ~= "string" or not profile.Pets[uid] then
		return false, "Pet not found"
	end
	local list = table.clone(profile.EquippedPets or {})
	if table.find(list, uid) then
		return true, list
	end
	if #list >= PetService.slots(profile) then
		return false, "All pet slots are full"
	end
	table.insert(list, uid)
	setEquipped(player, list)
	return true, list
end

local function unequipPet(player: Player, uid: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local list = table.clone(profile.EquippedPets or {})
	local at = if typeof(uid) == "string" then table.find(list, uid) else nil
	if not at then
		return false, "Pet not equipped"
	end
	table.remove(list, at)
	setEquipped(player, list)
	return true, list
end

local function lockPet(player: Player, uid: any, locked: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	if typeof(uid) ~= "string" or not profile.Pets[uid] or typeof(locked) ~= "boolean" then
		return false, "Bad request"
	end
	local owned = table.clone(profile.Pets)
	local pet = table.clone(owned[uid])
	pet.locked = locked
	owned[uid] = pet
	DataService:Set(player, "Pets", owned)
	return true, locked
end

local function releasePet(player: Player, uid: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local pet = if typeof(uid) == "string" then profile.Pets[uid] else nil
	if not pet then
		return false, "Pet not found"
	end
	if pet.locked then
		return false, "This pet is locked"
	end
	if pet.premium then
		return false, "Premium pets cannot be released"
	end
	local gold = Pets.releaseValue(pet.id, pet.rarity)
	local owned = table.clone(profile.Pets)
	owned[uid] = nil
	local list = table.clone(profile.EquippedPets or {})
	local at = table.find(list, uid)
	if at then
		table.remove(list, at)
		setEquipped(player, list)
	end
	DataService:Set(player, "Pets", owned)
	DataService:AddGold(player, gold)
	DataService:Save(player)
	return true, { gold = gold }
end

-- The pets with the best powerScore (ties: rarer first, then the higher zone).
function PetService.bestPets(profile: { [string]: any }, slots: number): { string }
	local all = {}
	for uid, pet in pairs(profile.Pets or {}) do
		if Pets.ById[pet.id] then
			table.insert(all, { uid = uid, score = Pets.powerScore(pet.id, pet.rarity), rarity = pet.rarity, zone = Pets.ById[pet.id].Zone })
		end
	end
	table.sort(all, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		elseif a.rarity ~= b.rarity then
			return a.rarity > b.rarity
		elseif a.zone ~= b.zone then
			return a.zone > b.zone
		end
		return a.uid < b.uid
	end)
	local list = {}
	for i = 1, math.min(slots, #all) do
		table.insert(list, all[i].uid)
	end
	return list
end

local function equipBest(player: Player): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local list = PetService.bestPets(profile, PetService.slots(profile))
	if #list == 0 then
		return false, "You have no pets yet"
	end
	setEquipped(player, list)
	return true, list
end

-- Loot / admin: a new egg { zone, rarity }. Full storage -> sold at once for Gold (with a toast).
function PetService:GiveEgg(player: Player, zone: number, tier: number, quiet: boolean?): (boolean, string?)
	local profile = DataService:Get(player)
	if not profile or not zoneByIndex(zone) then
		return false, nil
	end
	tier = math.clamp(math.floor(tier), 1, MAX_TIER)
	local name = `{Rarities.get(tier).Name} {zoneByIndex(zone).Name} Egg`
	if count(profile.Eggs) >= PetRarities.EggStorage then
		local gold = Pets.eggSellValue(zone, tier)
		DataService:AddGold(player, gold)
		Net.fire(player, "Notify", { Kind = "info", Text = `Egg storage full: {name} sold for {Format.number(gold)} Gold`, Icon = "Egg" })
		return true, "sold"
	end
	local eggs = table.clone(profile.Eggs)
	eggs[HttpService:GenerateGUID(false)] = { zone = zone, rarity = tier }
	DataService:Set(player, "Eggs", eggs)
	if not quiet then
		Net.fire(player, "Notify", { Kind = "loot", Text = `Obtained {name}`, Rarity = tier, Icon = "Egg" })
	end
	return true, "added"
end

-- Admin / tests: a pet straight into the storage (ignores the storage limit).
function PetService:GivePet(player: Player, petId: string, tier: number?): string?
	local profile = DataService:Get(player)
	local species = Pets.ById[petId]
	if not profile or not species then
		return nil
	end
	local rarity = if species.Premium then species.Rarity :: number else math.clamp(math.floor(tier or 1), 1, MAX_TIER)
	return addPet(player, profile, petId, rarity, species.Premium)
end

-- Robux purchase of a premium pet (MarketplaceService receipt handler): always granted, even when the storage
-- is full. Returns the new pet's uid.
function PetService.grantPremium(player: Player, petId: string): string?
	local species = Pets.ById[petId]
	if not species or not species.Premium then
		return nil
	end
	local uid = PetService:GivePet(player, petId)
	if uid then
		Net.fire(player, "Notify", { Kind = "loot", Text = `Obtained {Rarities.get(species.Rarity).Name} {species.Name}!`, Rarity = species.Rarity, Icon = "Pets" })
		DataService:Save(player)
	end
	return uid
end

function PetService:Init()
	Net.handle("HatchEgg", hatchEgg, 0.25)
	Net.handle("HatchAll", hatchAll, 1)
	Net.handle("BuyPremiumEgg", buyPremiumEgg, 0.5)
	Net.handle("EquipPet", equipPet, 0.1)
	Net.handle("UnequipPet", unequipPet, 0.1)
	Net.handle("LockPet", lockPet, 0.1)
	Net.handle("ReleasePet", releasePet, 0.1)
	Net.handle("EquipBestPets", equipBest, 0.5)
	DataService.Loaded:Connect(function(player: Player)
		-- drop equipped uids that no longer exist, keep the slot count
		local profile = DataService:Get(player)
		if profile then
			local list = {}
			for _, uid in ipairs(profile.EquippedPets or {}) do
				if profile.Pets[uid] and #list < PetService.slots(profile) and not table.find(list, uid) then
					table.insert(list, uid)
				end
			end
			if #list ~= #(profile.EquippedPets or {}) then
				DataService:Set(player, "EquippedPets", list)
			end
		end
		PetService:UpdateFollowers(player)
	end)
	DataService.Changed:Connect(function(player: Player, key: string)
		if key == "EquippedPets" or key == "Pets" then
			PetService:UpdateFollowers(player)
		end
	end)
end

function PetService:Start()
	-- the hub Egg Station opens the Pets window on its Eggs tab
	local hub = workspace:FindFirstChild("Hub")
	local station = hub and hub:FindFirstChild("EggStation")
	if not station then
		warn("PetService: workspace.Hub.EggStation not found")
		return
	end
	-- the map's prompt lives on the invisible "Interact" part
	local prompt = station:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		local anchor = station:FindFirstChild("Interact") or station:FindFirstChildWhichIsA("BasePart", true)
		if not anchor then
			return
		end
		local new = Instance.new("ProximityPrompt")
		new.HoldDuration = 0
		new.RequiresLineOfSight = false
		new.Parent = anchor
		prompt = new
	end
	(prompt :: ProximityPrompt).ActionText = "Hatch eggs";
	(prompt :: ProximityPrompt).ObjectText = "Egg Station";
	(prompt :: ProximityPrompt).Triggered:Connect(function(player: Player)
		Net.fire(player, "OpenWindow", "Pets", "Eggs")
	end)
	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("FollowPets", nil)
	end)
end

return PetService
