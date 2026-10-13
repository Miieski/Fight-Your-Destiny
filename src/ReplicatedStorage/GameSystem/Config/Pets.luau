--!strict
-- The 72 zone pets (6 per zone) and 4 premium pets (docs/menu_systems_brief.txt B2-B4; species list V2 after
-- Steal an Egg, docs/pets_v2_plan.md, owner 2026-10-12). Slot roles are the same in every zone (stats + bonus).
-- Models: ReplicatedStorage.Assets.Pets.<PetId> - the AI-generated rigs of DevTools/PetRigBuilder; Body / colors /
-- accessories only drive the procedural placeholders (DevTools/PetModels). Ids: "<zone lower>_pet<slot>".
-- A stored pet is { id, rarity, premium, locked, mutation?, size?, traits? } (Config/PetMutations, Config/PetTraits).
local PetMutations = require(script.Parent.PetMutations)
local PetTraits = require(script.Parent.PetTraits)
local PetRarities = require(script.Parent.PetRarities)
local Rarities = require(script.Parent.Rarities)
local Zones = require(script.Parent.Zones)

export type Species = {
	Id: string,
	Name: string,
	ZoneId: string?, -- nil for premium pets
	Zone: number, -- 0 for premium pets
	Slot: number,
	Role: string,
	Stats: { string },
	Bonus: string,
	Body: string,
	Colors: { Color3 },
	Accessories: { string },
	Scale: number,
	Premium: boolean,
	Rarity: number?, -- premium pets have a fixed rarity
}

local Pets = {}

Pets.STAT_NAMES = { Gold = "Gold Gain", HP = "Max HP", Attack = "Damage", Speed = "Move Speed", Defense = "Defense" }
Pets.BONUS_NAMES = {
	TrophyValue = "Trophy Value", CritDamage = "Crit Damage", Regeneration = "Regeneration",
	BossSlayer = "Boss Slayer", LootLuck = "Loot Luck", DiamondLuck = "Diamond Luck",
}
Pets.BONUS_TEXT = {
	TrophyValue = "more Gold when selling trophies", CritDamage = "more crit damage",
	Regeneration = "HP regeneration (x 0.05% Max HP per second)", BossSlayer = "more damage to mini-bosses and bosses",
	LootLuck = "loot drop chance (multiplicative)", DiamondLuck = "diamond drop chance (relative)",
}
Pets.STAT_ICONS = { Gold = "GoldGain", HP = "MaxHP", Attack = "Attack", Speed = "Speed", Defense = "Defense" }

-- Slot roles 1..6 (the same in every zone).
Pets.ROLES = {
	{ Role = "Fortune", Stats = { "Gold", "HP" }, Bonus = "TrophyValue" },
	{ Role = "Hunter", Stats = { "Attack", "Speed" }, Bonus = "CritDamage" },
	{ Role = "Guardian", Stats = { "HP", "Defense" }, Bonus = "Regeneration" },
	{ Role = "Berserker", Stats = { "Attack", "Defense" }, Bonus = "BossSlayer" },
	{ Role = "Scout", Stats = { "Speed", "Gold" }, Bonus = "LootLuck" },
	{ Role = "Lucky", Stats = { "Attack", "Gold" }, Bonus = "DiamondLuck" },
}

local hex = Color3.fromHex
-- [zone] = 6 species in slot order: { name, body, main color, second color, accessories, scale }
-- Bodies: Quadruped, Bird, Blob, Insect, Fish, Biped, Mech. Accessories: Ears, BigEars, Horns, Antlers, Wings,
-- BatWings, Antennae, Halo, Flame, Spikes, Tusks, Claws, Stinger, Crown, Spots, Tail, Tails, Fins, Lure, Leaves,
-- Crystal, Glow, Gear, Laser, Teeth, Tentacles, Shell, Mask, Snout.
local SPECIES = {
	Plains = {
		{ "Puppy", "Quadruped", "#D9A066", "#FFFFFF", { "Ears", "Tail" }, 1 },
		{ "Fox Kit", "Quadruped", "#F07F2A", "#FFFFFF", { "BigEars", "Tail" }, 1 },
		{ "Bear Cub", "Quadruped", "#8A5A33", "#D9B48A", { "Ears" }, 1.1 },
		{ "Boar Piglet", "Quadruped", "#E8A3A3", "#8A5A33", { "Tusks", "Snout" }, 1 },
		{ "Raccoon", "Quadruped", "#8C8C94", "#2A2A30", { "Ears", "Tail" }, 0.95 },
		{ "Owl", "Bird", "#9A7048", "#F2E2C0", { "Ears" }, 1 },
	},
	Desert = {
		{ "Fennec Fox", "Quadruped", "#E8C48A", "#FFF4E0", { "BigEars", "Tail" }, 0.95 },
		{ "Scorpion", "Insect", "#E0A030", "#7A3E16", { "Claws", "Stinger" }, 0.95 },
		{ "Baby Camel", "Quadruped", "#D9A45A", "#F2E2C0", { "Ears" }, 1.1 },
		{ "Sand Snake", "Fish", "#D9B77A", "#8A5A33", { "Spots" }, 1 },
		{ "Jerboa", "Quadruped", "#E0B880", "#FFFFFF", { "BigEars", "Tail" }, 0.85 },
		{ "Royal Sphinx", "Quadruped", "#E8C25A", "#1FA59A", { "Ears", "Crown" }, 1.05 },
	},
	Jungle = {
		{ "Monkey", "Biped", "#8A5A33", "#E8C9A0", { "Ears", "Tail" }, 1 },
		{ "Tiger Cub", "Quadruped", "#F08A2A", "#2A1A10", { "Ears", "Spots", "Tail" }, 1 },
		{ "Baby Gorilla", "Biped", "#3A3A40", "#8A8A90", {}, 1.1 },
		{ "Crocodile", "Quadruped", "#5E8A3A", "#C9D98A", { "LongSnout", "Spikes" }, 1.05 },
		{ "Toucan", "Bird", "#26222A", "#FF9A2A", {}, 1 },
		{ "Chameleon", "Quadruped", "#5ACB4A", "#F1C40F", { "Spikes", "Tail" }, 0.95 },
	},
	Tundra = {
		{ "Penguin", "Biped", "#26262E", "#FFFFFF", {}, 0.95 },
		{ "Sabertooth Cub", "Quadruped", "#E0B070", "#FFFFFF", { "Ears", "Tusks", "Tail" }, 1.05 },
		{ "Polar Bear Cub", "Quadruped", "#F5F5F0", "#C9D3DC", { "Ears" }, 1.1 },
		{ "Baby Mammoth", "Quadruped", "#8A5A3A", "#F2E8D8", { "BigEars", "Tusks" }, 1.15 },
		{ "Snow Hare", "Quadruped", "#F2F4F8", "#FFB0C0", { "BigEars" }, 0.85 },
		{ "Baby Yeti", "Biped", "#E8F0F8", "#7CC8EE", { "Horns" }, 1.1 },
	},
	Swamp = {
		{ "Duckling", "Bird", "#F5D442", "#FF9A2A", {}, 0.85 },
		{ "Frog", "Blob", "#5ACB4A", "#F1E08A", {}, 0.9 },
		{ "Turtle", "Quadruped", "#6E9A3A", "#8A6A3A", { "Shell" }, 1 },
		{ "Catfish", "Fish", "#6A7A6A", "#C9C0A0", { "Fins" }, 1 },
		{ "Firefly", "Insect", "#3A3A2A", "#F1FF8A", { "Wings", "Glow" }, 0.8 },
		{ "Axolotl", "Quadruped", "#FFB0D0", "#FF5A9A", { "Tail", "Spots" }, 0.95 },
	},
	Volcano = {
		{ "Lava Frog", "Blob", "#3A2A2A", "#FF6A1F", { "Spots" }, 0.9 },
		{ "Lava Gecko", "Quadruped", "#E04A2A", "#FFC23A", { "Spots", "Tail" }, 0.95 },
		{ "Baby Triceratops", "Quadruped", "#6A8A4A", "#E8D8B0", { "Horns", "Tail" }, 1.1 },
		{ "Baby T-Rex", "Biped", "#5E8A3A", "#E8D8A0", { "Teeth", "Tail" }, 1.1 },
		{ "Pterodactyl", "Bird", "#C0603A", "#F2C8A0", {}, 1 },
		{ "Phoenix Chick", "Bird", "#FF5A3A", "#FFD040", { "Flame" }, 0.95 },
	},
	Hell = {
		{ "Imp", "Biped", "#C0302A", "#2A1A1A", { "Horns", "BatWings", "Tail" }, 1 },
		{ "Hellhound Pup", "Quadruped", "#2A1A1A", "#E0302A", { "Horns", "Flame" }, 1.05 },
		{ "Gargoyle", "Biped", "#6A6A70", "#3A3A40", { "Horns", "BatWings" }, 1.05 },
		{ "Flaming Bull", "Quadruped", "#8A2A1A", "#FF8A2A", { "Horns", "Flame" }, 1.1 },
		{ "Fire Bat", "Bird", "#3A2428", "#FF6A1F", { "BatWings", "Ears" }, 0.9 },
		{ "Baby Cerberus", "Quadruped", "#2A1A1A", "#FF5A20", { "Ears", "Spikes", "Tail" }, 1.1 },
	},
	Heaven = {
		{ "Halo Bunny", "Quadruped", "#FFFFFF", "#FFB0D0", { "BigEars", "Halo" }, 0.9 },
		{ "Baby Griffin", "Quadruped", "#E8C25A", "#FFFFFF", { "Wings", "Tail" }, 1.1 },
		{ "Cloud Lamb", "Quadruped", "#FFFFFF", "#BFE6FF", { "Ears" }, 1 },
		{ "Pegasus Foal", "Quadruped", "#FFFFFF", "#BFE6FF", { "Wings", "Tail" }, 1.1 },
		{ "Swan", "Bird", "#FFFFFF", "#FF9A2A", {}, 1 },
		{ "Unicorn Foal", "Quadruped", "#FFFFFF", "#FF9AD8", { "Horns", "Tail", "Glow" }, 1.1 },
	},
	Dead = {
		{ "Little Ghost", "Blob", "#E8F0F0", "#7CFFB0", { "Glow" }, 0.9 },
		{ "Bone Pup", "Quadruped", "#E6DCC0", "#3A3440", { "Ears", "Tail" }, 0.95 },
		{ "Mummy Cat", "Quadruped", "#E8E0C8", "#7CFFB0", { "Ears", "Tail" }, 0.95 },
		{ "Zombie Bear", "Quadruped", "#6A8A5A", "#3A3440", { "Ears", "Teeth" }, 1.1 },
		{ "Raven", "Bird", "#26222A", "#7A4AA0", {}, 1 },
		{ "Spectral Stag", "Quadruped", "#BFE8FF", "#7CFFB0", { "Antlers", "Glow" }, 1.1 },
	},
	Abyss = {
		{ "Clownfish", "Fish", "#FF8A2A", "#FFFFFF", { "Fins" }, 0.85 },
		{ "Swordfish", "Fish", "#3A6AA0", "#C9D3DC", { "Fins" }, 1 },
		{ "Pufferfish", "Fish", "#F1D06A", "#FFFFFF", { "Spikes" }, 0.9 },
		{ "Baby Shark", "Fish", "#7A8A9A", "#F2F4F8", { "Fins", "Teeth" }, 1 },
		{ "Baby Orca", "Fish", "#1A1A22", "#FFFFFF", { "Fins" }, 1.05 },
		{ "Baby Kraken", "Blob", "#9A4AC0", "#FF8AC8", { "Tentacles" }, 1 },
	},
	Mechanical = {
		{ "Robo Pup", "Mech", "#9AA4B2", "#3FE6FF", { "Ears", "Tail" }, 0.95 },
		{ "Clockwork Spider", "Insect", "#B08A4A", "#3A3F48", { "Gear" }, 0.9 },
		{ "Steam Golem", "Biped", "#8A6A4A", "#3A3F48", { "Gear" }, 1.1 },
		{ "Mecha Rex", "Mech", "#6A7480", "#FF3030", { "Teeth", "Tail" }, 1.1 },
		{ "Mini Drone", "Mech", "#9AA4B2", "#3FE6FF", { "Antennae" }, 0.9 },
		{ "Gear Cat", "Mech", "#C9A04A", "#3A3F48", { "Ears", "Gear" }, 0.95 },
	},
	Void = {
		{ "Galaxy Cat", "Quadruped", "#2A1E5D", "#FF5AD8", { "Ears", "Tail", "Glow" }, 0.95 },
		{ "Void Stalker", "Quadruped", "#2A1E3D", "#B05BFF", { "Ears", "Spikes", "Tail" }, 1.05 },
		{ "Cosmic Gorilla", "Biped", "#3A2A6A", "#5FFFF0", { "Glow" }, 1.15 },
		{ "Cosmic Gecko", "Quadruped", "#4A2A8A", "#5FFFF0", { "Spots", "Tail" }, 1 },
		{ "Nebula Jellyfish", "Fish", "#B05BFF", "#5FFFF0", { "Tentacles", "Glow" }, 0.9 },
		{ "Baby Void Dragon", "Quadruped", "#2A1E3D", "#B05BFF", { "Horns", "BatWings", "Tail", "Spikes" }, 1.15 },
	},
}

-- Premium pets (Robux only): fixed rarity, kept on Rebirth, never from eggs.
local PREMIUM = {
	{ Id = "premium_dragonling", Name = "Golden Dragonling", Rarity = 5, Stats = { "Gold", "Attack" }, Bonus = "DiamondLuck", Body = "Quadruped", Colors = { "#E8B84A", "#FFF0B0" }, Accessories = { "Horns", "Wings", "Tail", "Glow" }, Scale = 1.15 },
	{ Id = "premium_phoenix", Name = "Rainbow Phoenix", Rarity = 6, Stats = { "HP", "Speed" }, Bonus = "Regeneration", Body = "Bird", Colors = { "#FF5A3A", "#FFD040" }, Accessories = { "Flame", "Glow" }, Scale = 1.1 },
	{ Id = "premium_golem", Name = "Diamond Golem", Rarity = 7, Stats = { "Defense", "HP" }, Bonus = "BossSlayer", Body = "Biped", Colors = { "#7FE8FF", "#FFFFFF" }, Accessories = { "Crystal", "Glow" }, Scale = 1.2 },
	{ Id = "premium_kitsune", Name = "Celestial Kitsune", Rarity = 8, Stats = { "Attack", "Gold" }, Bonus = "LootLuck", Body = "Quadruped", Colors = { "#FFFFFF", "#FF7FD8" }, Accessories = { "BigEars", "Tails", "Glow", "Halo" }, Scale = 1.1 },
}

Pets.ById = {} :: { [string]: Species }
Pets.List = {} :: { Species } -- 72 zone pets (zone order, then slot), then the 4 premium pets
Pets.ByZone = {} :: { [string]: { Species } }
for _, zone in ipairs(Zones.List) do
	local list = {}
	for slot, spec in ipairs(SPECIES[zone.Id]) do
		local role = Pets.ROLES[slot]
		local species: Species = {
			Id = string.lower(zone.Id) .. "_pet" .. slot,
			Name = spec[1],
			ZoneId = zone.Id,
			Zone = zone.Index,
			Slot = slot,
			Role = role.Role,
			Stats = role.Stats,
			Bonus = role.Bonus,
			Body = spec[2],
			Colors = { hex(spec[3]), hex(spec[4]) },
			Accessories = spec[5],
			Scale = spec[6],
			Premium = false,
		}
		Pets.ById[species.Id] = species
		table.insert(list, species)
		table.insert(Pets.List, species)
	end
	Pets.ByZone[zone.Id] = list
end
Pets.Premium = {} :: { Species }
for _, spec in ipairs(PREMIUM) do
	local species: Species = {
		Id = spec.Id, Name = spec.Name, ZoneId = nil, Zone = 0, Slot = 0, Role = "Premium",
		Stats = spec.Stats, Bonus = spec.Bonus, Body = spec.Body, Colors = { hex(spec.Colors[1]), hex(spec.Colors[2]) },
		Accessories = spec.Accessories, Scale = spec.Scale, Premium = true, Rarity = spec.Rarity,
	}
	Pets.ById[species.Id] = species
	table.insert(Pets.Premium, species)
	table.insert(Pets.List, species)
end

-- Value of each main stat of a pet of that rarity (before Faith).
function Pets.mainValue(tier: number): number
	return PetRarities.MainValue[math.clamp(math.floor(tier or 1), 1, #PetRarities.MainValue)]
end

function Pets.bonusValue(tier: number): number
	return Pets.mainValue(tier) * PetRarities.BonusShare
end

-- Equip Best score (in % points): main stats x weights + bonus x 0.5. mult = PetMutations.mult(pet) (1 if omitted).
function Pets.powerScore(id: string, tier: number, mult: number?): number
	local species = Pets.ById[id]
	if not species then
		return 0
	end
	local m = mult or 1
	local main = Pets.mainValue(tier) * 100 * m
	local score = 0
	for _, stat in ipairs(species.Stats) do
		score += main * (PetRarities.PowerWeights[stat] or 1)
	end
	return score + Pets.bonusValue(tier) * 100 * m * PetRarities.BonusWeight
end

-- Equip Best score of a stored pet (mutation, size and Bonus Stats items included).
function Pets.petScore(pet: { [string]: any }): number
	local score = Pets.powerScore(pet.id, pet.rarity, PetMutations.mult(pet))
	for stat, value in pairs(PetTraits.totals(pet)) do
		score += value * 100 * (PetRarities.PowerWeights[stat] or PetRarities.BonusWeight)
	end
	return score
end

-- The "Power" number shown on the pet card (Equip Best score x 10).
function Pets.power(pet: { [string]: any }): number
	return math.floor(Pets.petScore(pet) * 10 + 0.5)
end

-- The "Worth" of a stored pet: its release value with the mutation / size and the Bonus Stats items.
function Pets.worth(pet: { [string]: any }): number
	return math.floor(Pets.releaseValue(pet.id, pet.rarity, PetMutations.mult(pet)) * PetTraits.worthMult(pet) + 0.5)
end

-- "Huge Golden Fox Kit" (size and mutation before the species name).
function Pets.displayName(pet: { [string]: any }): string
	local species = Pets.ById[pet.id]
	local name = if species then species.Name else tostring(pet.id)
	local prefix = PetMutations.prefix(pet)
	return if prefix ~= "" then `{prefix} {name}` else name
end

local function percent(value: number): string
	local text = string.format("%.2f", value * 100)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return text
end

-- Texts of a pet's values: { "+16% Damage", "+16% Move Speed" }, "+4% Crit Damage".
-- mult = the owner's pet effectiveness (Faith, Util/Stats PetEffectiveness), 1 when omitted.
function Pets.describe(id: string, tier: number, mult: number?): ({ string }, string)
	local species = Pets.ById[id]
	if not species then
		return {}, ""
	end
	local m = mult or 1
	local lines = {}
	for _, stat in ipairs(species.Stats) do
		table.insert(lines, `+{percent(Pets.mainValue(tier) * m)}% {Pets.STAT_NAMES[stat]}`)
	end
	return lines, `+{percent(Pets.bonusValue(tier) * m)}% {Pets.BONUS_NAMES[species.Bonus]}`
end

-- Gold for releasing a pet / auto-selling an egg (zone 0 = premium -> zone 1 values). mult = PetMutations.mult(pet).
function Pets.releaseValue(id: string, tier: number, mult: number?): number
	local species = Pets.ById[id]
	local zone = math.max(1, species and species.Zone or 1)
	return Rarities.get(tier).DamageMult * PetRarities.ReleaseBase * 10 ^ (zone - 1) * (mult or 1)
end

function Pets.eggSellValue(zone: number, tier: number): number
	return Rarities.get(tier).DamageMult * PetRarities.EggSellBase * 10 ^ (zone - 1)
end

return Pets
