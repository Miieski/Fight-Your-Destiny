--!strict
-- Enemy loot and head trophies (DESIGN.md section 5, docs/enemies_npcs_pets_brief.txt Part B).
--   LootService.chance(def, lootMult) -> probability of the enemy's one loot item (2% normal, 4% mini, 6% boss x Loot Luck)
--   LootService:Roll(player, def, lootMult) -> granted?   rolled on the kill for the top damage dealer
--   LootService:Grant(player, def) -> kind               Egg -> an egg of the zone | Armor / Weapon -> an armor piece of the
--                                                        zone (random slot) | Corpse / Material / Trophy -> a head trophy
--   LootService:GiveTrophy(player, enemyId, tier, quiet?) full storage (Enemies.TROPHY_STORAGE) -> sold at once (toast)
--   Net.request("SellTrophy", uid) / Net.request("SellAllTrophies") -> true, { gold, count }
-- Trophy value = 25 x enemy Gold x rarityMult x (1 + Trophy Value bonus of the pets).
-- profile.Trophies = { [uid] = { id = enemyId, rarity = tier } } (reset on Rebirth).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Armor = require(ReplicatedStorage.GameSystem.Config.Armor)
local Enemies = require(ReplicatedStorage.GameSystem.Config.Enemies)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local ArmorService = require(script.Parent.ArmorService)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local RewardService = require(script.Parent.RewardService)

local LootService = { Priority = 4 }

local rng = Random.new()

local function count(map: { [any]: any }?): number
	local n = 0
	for _ in pairs(map or {}) do
		n += 1
	end
	return n
end

function LootService.chance(def: any, lootMult: number?): number
	local base = Enemies.LOOT_CHANCE[def.Tier or "normal"] or Enemies.LOOT_CHANCE.normal
	return math.min(1, base * math.max(0, lootMult or 1))
end

function LootService.trophyName(enemyId: string): string
	local def = Enemies.ById[enemyId]
	return `{if def then def.Name else "Unknown"} Head Trophy`
end

LootService.trophyValue = Enemies.trophyValue

local function trophyBonus(profile: { [string]: any }): number
	return Stats.compute(profile, { now = os.time() }).TrophyValue or 0
end

function LootService:GiveTrophy(player: Player, enemyId: string, tier: number, quiet: boolean?): string?
	local profile = DataService:Get(player)
	if not profile or not Enemies.ById[enemyId] then
		return nil
	end
	tier = math.clamp(math.floor(tier), 1, #Rarities.List)
	local name = `{Rarities.get(tier).Name} {LootService.trophyName(enemyId)}`
	if count(profile.Trophies) >= Enemies.TROPHY_STORAGE then
		local gold = LootService.trophyValue(enemyId, tier, trophyBonus(profile))
		DataService:AddGold(player, gold)
		Net.fire(player, "Notify", { Kind = "info", Text = `Trophy storage full: {name} sold for {Format.number(gold)} Gold`, Icon = "Trophy" })
		return nil
	end
	local uid = HttpService:GenerateGUID(false)
	local trophies = table.clone(profile.Trophies or {})
	trophies[uid] = { id = enemyId, rarity = tier }
	DataService:Set(player, "Trophies", trophies)
	RewardService.progress(player, "CollectTrophies", 1)
	if not quiet then
		Net.fire(player, "Notify", { Kind = "loot", Text = `Obtained {name}`, Rarity = tier, Icon = "Trophy" })
	end
	return uid
end

-- The enemy's loot item, straight into the inventory (full storages sell it at once with a toast).
function LootService:Grant(player: Player, def: any, tier: number?): string?
	local loot = def.Loot
	if not loot then
		return nil
	end
	local rarity = tier or def.LootRarity or 1
	local zone = Zones.ById[def.ZoneId]
	if loot.Kind == "Egg" then
		PetService:GiveEgg(player, zone.Index, rarity)
	elseif loot.Kind == "Armor" then
		local slot = Armor.SLOTS[rng:NextInteger(1, #Armor.SLOTS)]
		ArmorService:GiveArmor(player, `{string.lower(zone.Id)}_{string.lower(slot)}`, rarity)
	else
		LootService:GiveTrophy(player, def.Id, rarity)
	end
	return loot.Kind
end

function LootService:Roll(player: Player, def: any, lootMult: number?): boolean
	if rng:NextNumber() >= LootService.chance(def, lootMult) then
		return false
	end
	LootService:Grant(player, def)
	return true
end

local function sell(player: Player, uid: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	if typeof(uid) ~= "string" or #uid > 64 then
		return false, "Bad request"
	end
	local trophy = profile.Trophies and profile.Trophies[uid]
	if not trophy then
		return false, "Trophy not found"
	end
	local gold = LootService.trophyValue(trophy.id, trophy.rarity, trophyBonus(profile))
	local trophies = table.clone(profile.Trophies)
	trophies[uid] = nil
	DataService:Set(player, "Trophies", trophies)
	DataService:AddGold(player, gold) -- (not counted for the "Gold from enemies" quest)
	DataService:Save(player)
	return true, { gold = gold, count = 1 }
end

local function sellAll(player: Player): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local bonus = trophyBonus(profile)
	local gold, n = 0, 0
	for _, trophy in pairs(profile.Trophies or {}) do
		gold += LootService.trophyValue(trophy.id, trophy.rarity, bonus)
		n += 1
	end
	if n == 0 then
		return false, "You have no trophies"
	end
	DataService:Set(player, "Trophies", {})
	DataService:AddGold(player, gold) -- (not counted for the "Gold from enemies" quest)
	DataService:Save(player)
	return true, { gold = gold, count = n }
end

function LootService:Init()
	Net.handle("SellTrophy", sell, 0.15)
	Net.handle("SellAllTrophies", sellAll, 1)
end

return LootService
