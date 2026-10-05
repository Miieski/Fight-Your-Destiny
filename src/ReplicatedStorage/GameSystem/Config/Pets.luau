--!strict
-- The 72 zone pets (6 per zone) and 4 premium pets (docs/menu_systems_brief.txt B2-B4). Slot roles are the same
-- in every zone (stats + bonus); Body / colors / accessories drive the procedural models
-- (ServerStorage.DevTools.PetModels -> ReplicatedStorage.Assets.Pets.<PetId>). Ids: "<zone lower>_pet<slot>".
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
		{ "Boar Piglet", "Quadruped", "#E8A3A3", "#8A5A33", { "Tusks", "Snout" }, 1 },
		{ "Wolf Pup", "Quadruped", "#9AA0A8", "#E8E8E8", { "Ears", "Tail" }, 1 },
		{ "Baby Bear", "Quadruped", "#8A5A33", "#D9B48A", { "Ears" }, 1.1 },
		{ "Seagull Chick", "Bird", "#F2F2F2", "#F5C542", {}, 0.9 },
		{ "Crab Buddy", "Insect", "#E0503A", "#F5D0B0", { "Claws" }, 0.9 },
		{ "Spider Hatchling", "Insect", "#3A3036", "#B04A4A", { "Spots" }, 0.85 },
	},
	Desert = {
		{ "Jackal Pup", "Quadruped", "#D9A45A", "#7A5230", { "BigEars", "Tail" }, 1 },
		{ "Scorpion Cub", "Insect", "#E0A030", "#7A3E16", { "Claws", "Stinger" }, 0.95 },
		{ "Baby Croc", "Quadruped", "#5E8A3A", "#C9D98A", { "LongSnout", "Spikes" }, 1 },
		{ "Desert Eaglet", "Bird", "#8A5A33", "#F2E2C0", {}, 1 },
		{ "Scarab Beetle", "Insect", "#1FA59A", "#E2B04A", { "Shell" }, 0.85 },
		{ "Sand Snake", "Fish", "#D9B77A", "#8A5A33", { "Spots" }, 1 },
	},
	Jungle = {
		{ "Monkey", "Biped", "#8A5A33", "#E8C9A0", { "Ears", "Tail" }, 1 },
		{ "Jaguar Cub", "Quadruped", "#E09A2E", "#3A2414", { "Ears", "Spots", "Tail" }, 1 },
		{ "Frog Prince", "Blob", "#5ACB4A", "#F1C40F", { "Crown" }, 0.9 },
		{ "Piranha Pal", "Fish", "#C0392B", "#9AA0A8", { "Teeth", "Fins" }, 0.9 },
		{ "Green Viper", "Fish", "#2E8B3A", "#9AD94A", { "Teeth" }, 1 },
		{ "Totem Spirit", "Biped", "#A0703F", "#1FA59A", { "Mask", "Glow" }, 1 },
	},
	Tundra = {
		{ "Snow Owl", "Bird", "#F2F4F8", "#C9D3DC", { "Ears" }, 1 },
		{ "Arctic Fox", "Quadruped", "#F2F4F8", "#9FB4C6", { "BigEars", "Tail" }, 1 },
		{ "Polar Bear Cub", "Quadruped", "#F5F5F0", "#C9D3DC", { "Ears" }, 1.1 },
		{ "Baby Yeti", "Biped", "#E8F0F8", "#7CC8EE", { "Horns" }, 1.1 },
		{ "Ice Eaglet", "Bird", "#7CC8EE", "#E8F0F8", { "Crystal" }, 1 },
		{ "White Wolf Pup", "Quadruped", "#E8EEF2", "#7CC8EE", { "Ears", "Tail" }, 1 },
	},
	Swamp = {
		{ "Leech Buddy", "Blob", "#3E5A2E", "#8A9A4A", { "Teeth" }, 0.85 },
		{ "Black Kitten", "Quadruped", "#26222A", "#F1C40F", { "Ears", "Tail" }, 0.9 },
		{ "Mud Golemite", "Biped", "#5A4630", "#6E9A3A", { "Leaves" }, 1.1 },
		{ "Baby Treant", "Biped", "#6E4A2A", "#5ACB4A", { "Leaves", "Antlers" }, 1.1 },
		{ "Crow", "Bird", "#26222A", "#7A4AA0", {}, 1 },
		{ "Little Wisp", "Blob", "#9AFF6A", "#F1FF8A", { "Glow" }, 0.8 },
	},
	Volcano = {
		{ "Ash Lizard", "Quadruped", "#6A6A70", "#FF6A1F", { "Spikes", "Tail" }, 1 },
		{ "Fire Bat", "Bird", "#3A2428", "#FF6A1F", { "BatWings", "Ears" }, 0.9 },
		{ "Rock Worm", "Fish", "#5A4834", "#FF6A1F", { "Spikes" }, 1 },
		{ "Lava Crab", "Insect", "#2A2224", "#FF6A1F", { "Claws", "Glow" }, 0.95 },
		{ "Salamander", "Quadruped", "#E04A2A", "#FFC23A", { "Spots", "Tail" }, 1 },
		{ "Ember Sprite", "Blob", "#FF8A2A", "#FFE070", { "Flame" }, 0.8 },
	},
	Hell = {
		{ "Cinder Imp", "Biped", "#C0302A", "#2A1A1A", { "Horns", "BatWings", "Tail" }, 1 },
		{ "Hellhound Pup", "Quadruped", "#2A1A1A", "#E0302A", { "Horns", "Flame" }, 1.05 },
		{ "Baby Gargoyle", "Biped", "#6A6A70", "#3A3A40", { "Horns", "BatWings" }, 1.05 },
		{ "Flame Skull", "Blob", "#EFE6CC", "#FF5A20", { "Flame" }, 0.85 },
		{ "Infernal Kitten", "Quadruped", "#8A1A1A", "#FF8A2A", { "Ears", "Horns", "Tail" }, 0.9 },
		{ "Brimstone Beetle", "Insect", "#2A2224", "#F1C40F", { "Shell", "Horns" }, 0.9 },
	},
	Heaven = {
		{ "Glowing Bird", "Bird", "#FFE070", "#FFFFFF", { "Glow" }, 1 },
		{ "Cherub", "Biped", "#FFE8D8", "#FFFFFF", { "Wings", "Halo" }, 1 },
		{ "Baby Griffin", "Quadruped", "#E8C25A", "#FFFFFF", { "Wings", "Tail" }, 1.1 },
		{ "Celestial Fawn", "Quadruped", "#F2E2C0", "#FFE070", { "Antlers", "Spots" }, 1.05 },
		{ "Cloud Puff", "Blob", "#FFFFFF", "#BFE6FF", {}, 0.9 },
		{ "Halo Bunny", "Quadruped", "#FFFFFF", "#FFB0D0", { "BigEars", "Halo" }, 0.9 },
	},
	Dead = {
		{ "Little Ghost", "Blob", "#E8F0F0", "#7CFFB0", { "Glow" }, 0.9 },
		{ "Bone Rat", "Quadruped", "#E6DCC0", "#3A3440", { "Ears", "Tail" }, 0.85 },
		{ "Mini Skeleton", "Biped", "#EFE6CC", "#7CFFB0", {}, 1 },
		{ "Baby Ghoul", "Biped", "#8A9A8A", "#3A3440", { "Teeth" }, 1 },
		{ "Grave Kitten", "Quadruped", "#5A5A66", "#7CFFB0", { "Ears", "Tail" }, 0.9 },
		{ "Spooky Bat", "Bird", "#3A2A4A", "#B05BFF", { "BatWings", "Ears" }, 0.9 },
	},
	Abyss = {
		{ "Jellyfish", "Fish", "#FF8AC8", "#5FFFF0", { "Tentacles", "Glow" }, 0.9 },
		{ "Baby Shark", "Fish", "#7A8A9A", "#F2F4F8", { "Fins", "Teeth" }, 1 },
		{ "Armor Crab", "Insect", "#1FA59A", "#FF7FAB", { "Claws", "Shell" }, 1 },
		{ "Octopus", "Blob", "#9A4AC0", "#FF8AC8", { "Tentacles" }, 0.95 },
		{ "Seahorse", "Fish", "#F1C40F", "#FF8A2A", { "Fins" }, 0.9 },
		{ "Anglerfish", "Fish", "#1F2A4A", "#5FFFF0", { "Lure", "Teeth" }, 1 },
	},
	Mechanical = {
		{ "Mini Drone", "Mech", "#9AA4B2", "#3FE6FF", { "Antennae" }, 0.9 },
		{ "Robo Rat", "Mech", "#6A7480", "#FF8A2A", { "Ears", "Tail" }, 0.85 },
		{ "Clockwork Spider", "Insect", "#B08A4A", "#3A3F48", { "Gear" }, 0.9 },
		{ "Slime Bot", "Blob", "#5ACB4A", "#9AA4B2", { "Antennae", "Glow" }, 0.9 },
		{ "Gear Cat", "Mech", "#C9A04A", "#3A3F48", { "Ears", "Gear" }, 0.95 },
		{ "Laser Bot", "Mech", "#3A3F48", "#FF3030", { "Laser" }, 1 },
	},
	Void = {
		{ "Shadow Wisp", "Blob", "#2A1E3D", "#B05BFF", { "Glow" }, 0.85 },
		{ "Void Stalker Pup", "Quadruped", "#2A1E3D", "#B05BFF", { "Ears", "Spikes", "Tail" }, 1.05 },
		{ "Obsidian Golemite", "Biped", "#2A2224", "#B05BFF", { "Crystal" }, 1.1 },
		{ "Crystal Butterfly", "Insect", "#B05BFF", "#5FFFF0", { "Wings", "Antennae" }, 0.9 },
		{ "Rift Cat", "Quadruped", "#4A2A6A", "#FF5AD8", { "Ears", "Tail", "Glow" }, 0.95 },
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

-- Equip Best score (in % points): main stats x weights + bonus x 0.5.
function Pets.powerScore(id: string, tier: number): number
	local species = Pets.ById[id]
	if not species then
		return 0
	end
	local main = Pets.mainValue(tier) * 100
	local score = 0
	for _, stat in ipairs(species.Stats) do
		score += main * (PetRarities.PowerWeights[stat] or 1)
	end
	return score + Pets.bonusValue(tier) * 100 * PetRarities.BonusWeight
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

-- Gold for releasing a pet / auto-selling an egg (zone 0 = premium -> zone 1 values).
function Pets.releaseValue(id: string, tier: number): number
	local species = Pets.ById[id]
	local zone = math.max(1, species and species.Zone or 1)
	return Rarities.get(tier).DamageMult * PetRarities.ReleaseBase * 10 ^ (zone - 1)
end

function Pets.eggSellValue(zone: number, tier: number): number
	return Rarities.get(tier).DamageMult * PetRarities.EggSellBase * 10 ^ (zone - 1)
end

return Pets
