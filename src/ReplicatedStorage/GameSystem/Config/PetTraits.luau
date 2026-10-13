--!strict
-- Pet Bonus Stats (owner 2026-10-13, after the "Rare Celestial Axolotl" card of the reference image): at hatching
-- every pet rolls 3 items - a Crown, an Accessory and an Aura. Each item has its own rarity (the 8 tiers of
-- Config/Rarities, rolled with ODDS, independent of the pet's rarity), one stat and a roll inside its rarity's
-- range. The item is the slot's item of that rarity (a Common crown is a Leaf Crown, a Divine one an Angel Halo),
-- so the look on the pet tells the rarity (Util/PetGear). Pets owned before the update get theirs once on join.
-- Stored on the pet: pet.traits = { Crown = { rarity, stat, roll }, Accessory = {...}, Aura = {...} }
--   roll in [0, 1]: value = BASE[stat] x TIER_MULT[rarity] x (0.8 + 0.4 x roll); the value is computed from the
--   config, so rebalancing changes every pet at once.
-- Stats: Attack, HP, Defense, Speed, Gold, LootLuck, CritDamage (the Util/Stats pet keys) and All (= Attack, HP,
-- Defense, Speed, Gold and LootLuck at once, a smaller value). Traits are not multiplied by the mutation / size;
-- Faith makes them stronger like every pet value (Util/Stats).
local Rarities = require(script.Parent.Rarities)

local PetTraits = {}

PetTraits.SLOTS = { "Crown", "Accessory", "Aura" }
PetTraits.SLOT_ICONS = { Crown = "Crown", Accessory = "Collar", Aura = "Aura" }

-- the item of each slot for each rarity tier 1..8 (Common .. Secret); Gear = ReplicatedStorage.Assets.PetGear child
PetTraits.ITEMS = {
	Crown = {
		{ Id = "LeafCrown", Name = "Leaf Crown" },
		{ Id = "FlowerCrown", Name = "Flower Crown" },
		{ Id = "SilverCirclet", Name = "Silver Circlet" },
		{ Id = "HermitsCrescent", Name = "Hermit's Crescent" },
		{ Id = "GoldenCrown", Name = "Golden Crown" },
		{ Id = "RubyCrown", Name = "Ruby Crown" },
		{ Id = "AngelHalo", Name = "Angel Halo" },
		{ Id = "RainbowCrown", Name = "Rainbow Crown" },
	},
	Accessory = {
		{ Id = "Bandana", Name = "Bandana" },
		{ Id = "BellCollar", Name = "Bell Collar" },
		{ Id = "BowTie", Name = "Bow Tie" },
		{ Id = "Scarf", Name = "Cozy Scarf" },
		{ Id = "GoldMedal", Name = "Gold Medal" },
		{ Id = "PearlNecklace", Name = "Pearl Necklace" },
		{ Id = "DiamondCollar", Name = "Diamond Collar" },
		{ Id = "StarPendant", Name = "Star Pendant" },
	},
	Aura = {
		{ Id = "DustAura", Name = "Aura of Dust" },
		{ Id = "LeafAura", Name = "Leaf Aura" },
		{ Id = "BubbleAura", Name = "Bubble Aura" },
		{ Id = "FrostAura", Name = "Frost Aura" },
		{ Id = "EmberAura", Name = "Ember Aura" },
		{ Id = "ThunderAura", Name = "Thunder Aura" },
		{ Id = "HolyAura", Name = "Holy Aura" },
		{ Id = "CosmicAura", Name = "Cosmic Aura" },
	},
}

-- rarity odds of one item (add up to 1)
PetTraits.ODDS = { 0.5, 0.25, 0.13, 0.07, 0.033, 0.012, 0.004, 0.001 }
-- value multiplier of each rarity tier
PetTraits.TIER_MULT = { 1, 1.6, 2.4, 3.5, 5, 7, 10, 14 }

-- the stats an item can give: value of a Common item (fraction), name, icon, roll weight
PetTraits.STATS = {
	Attack = { Base = 0.02, Name = "Damage", Icon = "Attack", Weight = 1 },
	HP = { Base = 0.02, Name = "Max HP", Icon = "MaxHP", Weight = 1 },
	Defense = { Base = 0.02, Name = "Defense", Icon = "Defense", Weight = 1 },
	Speed = { Base = 0.015, Name = "Speed", Icon = "Speed", Weight = 1 },
	Gold = { Base = 0.025, Name = "Gold", Icon = "GoldGain", Weight = 1 },
	LootLuck = { Base = 0.02, Name = "Luck", Icon = "Clover", Weight = 1 },
	CritDamage = { Base = 0.03, Name = "Crit Damage", Icon = "Crit", Weight = 0.8 },
	All = { Base = 0.007, Name = "All", Icon = "AllStats", Weight = 0.4 },
}
PetTraits.STAT_ORDER = { "Attack", "HP", "Defense", "Speed", "Gold", "LootLuck", "CritDamage", "All" }
PetTraits.ALL_STATS = { "Attack", "HP", "Defense", "Speed", "Gold", "LootLuck" }

-- Worth (release value): every item above Common adds 10% per tier (a Divine item: +60%).
PetTraits.WORTH_PER_TIER = 0.1

export type Trait = { rarity: number, stat: string, roll: number }

local function rollTier(rng: Random): number
	local x = rng:NextNumber()
	for tier, chance in ipairs(PetTraits.ODDS) do
		if x < chance then
			return tier
		end
		x -= chance
	end
	return 1
end

local function rollStat(rng: Random): string
	local total = 0
	for _, id in ipairs(PetTraits.STAT_ORDER) do
		total += PetTraits.STATS[id].Weight
	end
	local x = rng:NextNumber() * total
	for _, id in ipairs(PetTraits.STAT_ORDER) do
		x -= PetTraits.STATS[id].Weight
		if x <= 0 then
			return id
		end
	end
	return PetTraits.STAT_ORDER[1]
end

-- The 3 items of a new pet. forcedTier (admin / tests): every item of that rarity.
function PetTraits.roll(rng: Random, forcedTier: number?): { [string]: Trait }
	local traits = {}
	for _, slot in ipairs(PetTraits.SLOTS) do
		local tier = if forcedTier then math.clamp(math.floor(forcedTier), 1, #PetTraits.ODDS) else rollTier(rng)
		traits[slot] = { rarity = tier, stat = rollStat(rng), roll = math.floor(rng:NextNumber() * 1000 + 0.5) / 1000 }
	end
	return traits
end

-- A stored trait, checked (nil when broken).
function PetTraits.get(pet: { [string]: any }, slot: string): Trait?
	local traits = pet.traits
	local trait = if typeof(traits) == "table" then traits[slot] else nil
	if typeof(trait) ~= "table" or typeof(trait.rarity) ~= "number" or not PetTraits.STATS[trait.stat] then
		return nil
	end
	return trait
end

function PetTraits.has(pet: { [string]: any }): boolean
	return PetTraits.get(pet, "Crown") ~= nil
end

function PetTraits.tier(trait: Trait): number
	return math.clamp(math.floor(trait.rarity), 1, #PetTraits.TIER_MULT)
end

function PetTraits.item(slot: string, trait: Trait): { Id: string, Name: string }
	return PetTraits.ITEMS[slot][PetTraits.tier(trait)]
end

-- The trait's bonus as a fraction (0.034 = +3.4%).
function PetTraits.value(trait: Trait): number
	local stat = PetTraits.STATS[trait.stat]
	local roll = math.clamp(tonumber(trait.roll) or 0.5, 0, 1)
	return stat.Base * PetTraits.TIER_MULT[PetTraits.tier(trait)] * (0.8 + 0.4 * roll)
end

-- The pet's item bonuses by Util/Stats key ("All" spread over its stats): { Attack = 0.03, Gold = 0.05, ... }
function PetTraits.totals(pet: { [string]: any }): { [string]: number }
	local out: { [string]: number } = {}
	for _, slot in ipairs(PetTraits.SLOTS) do
		local trait = PetTraits.get(pet, slot)
		if trait then
			local value = PetTraits.value(trait)
			if trait.stat == "All" then
				for _, stat in ipairs(PetTraits.ALL_STATS) do
					out[stat] = (out[stat] or 0) + value
				end
			else
				out[trait.stat] = (out[trait.stat] or 0) + value
			end
		end
	end
	return out
end

-- Release value multiplier from the items.
function PetTraits.worthMult(pet: { [string]: any }): number
	local mult = 1
	for _, slot in ipairs(PetTraits.SLOTS) do
		local trait = PetTraits.get(pet, slot)
		if trait then
			mult += (PetTraits.tier(trait) - 1) * PetTraits.WORTH_PER_TIER
		end
	end
	return mult
end

-- "+3.4%" (one decimal under 10%).
function PetTraits.percentText(value: number): string
	local percent = value * 100
	local text = if percent >= 10 then string.format("%d", math.floor(percent + 0.5)) else string.format("%.1f", percent)
	text = string.gsub(text, "%.0$", "")
	return `+{text}%`
end

-- "425" = the items' tiers (Crown, Accessory, Aura) for the FollowPets attribute; "" without items.
function PetTraits.gearKey(pet: { [string]: any }): string
	local parts = {}
	for _, slot in ipairs(PetTraits.SLOTS) do
		local trait = PetTraits.get(pet, slot)
		if not trait then
			return ""
		end
		table.insert(parts, tostring(PetTraits.tier(trait)))
	end
	return table.concat(parts)
end

-- "425" -> { Crown = 4, Accessory = 2, Aura = 5 } (nil when empty or malformed)
function PetTraits.parseGearKey(key: string?): { [string]: number }?
	if typeof(key) ~= "string" or not string.match(key, "^[1-8][1-8][1-8]$") then
		return nil
	end
	local out = {}
	for i, slot in ipairs(PetTraits.SLOTS) do
		out[slot] = tonumber(string.sub(key, i, i)) :: number
	end
	return out
end

-- the rarity of a tier, for the UI (name, color)
function PetTraits.rarity(tier: number): any
	return Rarities.get(tier)
end

return PetTraits
