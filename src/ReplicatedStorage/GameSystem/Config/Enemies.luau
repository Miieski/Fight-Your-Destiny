--!strict
-- Enemies, mini-bosses and bosses (docs/enemy_database.txt is the source of truth).
-- Stats follow the database formulas, so only names are listed here. Zones 1-4 also have their look, rig, size,
-- loot and AI values (docs/enemies_npcs_pets_brief.txt Part B / Part F); the other zones are not playable yet.

local Rarities = require(script.Parent.Rarities)
local Zones = require(script.Parent.Zones)

export type Enemy = {
	Id: string, -- "<zone>_<name>", for example "plains_boar"
	Name: string,
	ZoneId: string,
	SubZone: number,
	Role: string, -- "Normal" | "MiniBoss" | "Boss"
	Tier: string, -- "normal" | "mini" | "boss" (same as Role, brief naming)
	MaxHP: number, -- HP of the database
	Damage: number, -- DMG of the database (one normal hit)
	Gold: number, -- COINS of the database (base Gold reward)
	-- zones 1-4 only (nil elsewhere):
	Rig: string?, -- rig family (Blender/Rigs): Quadruped, Biped, Bird, Arachnid, Serpent, Crustacean, Fish, Amphibian,
	-- Insect, Golem, Floater, Snowman, Gorilla, BossBiped
	Height: number?, -- studs (length for serpents and long quadrupeds)
	Bulky: boolean?, -- brute bipeds (wider body and arms)
	Color: Color3?, -- placeholder model colors (main, accent, eyes)
	Accent: Color3?,
	Eyes: Color3?,
	WalkSpeed: number?, -- studs / s
	Hover: number?, -- studs above the ground (flyers 4, fish and floaters lower)
	AggroRadius: number?,
	AttackType: string?, -- "melee" | "ranged"
	AttackRange: number?, -- studs from the body edge (melee) or from the center (ranged)
	AttackCooldown: number?,
	Telegraph: number?, -- seconds of wind-up before the hit
	Loot: { Name: string, Source: string, Kind: string }?, -- Source = database type; Kind = "Egg" | "Armor" | "Trophy"
	LootRarity: number?, -- tier 1..8 (database rule: b = ceil(zone / 2))
}

local Enemies = {}

-- Base value of a sub-zone: B = 100 x 10^(zone - 1) x 2^(subzone - 1)
Enemies.BASE = 100
Enemies.NORMAL_HP_MULT = { 0.8, 1.0, 1.2 } -- light, standard, heavy
Enemies.BOSS_ROOM_HP_MULT = { 1.0, 1.2 } -- the boss room only has the standard and heavy types
Enemies.NORMAL = { DamagePct = 0.05, GoldPct = 0.20 }
Enemies.MINI_BOSS = { HpMult = { 5, 7 }, DamagePct = 0.06, GoldPct = 0.30 }
Enemies.BOSS = { HpMult = 25, DamagePct = 0.07, GoldPct = 0.40 }
Enemies.RESPAWN_SECONDS = 2
Enemies.ALIVE_PER_SUBZONE = 10
Enemies.RESPAWN_MIN_PLAYER_DISTANCE = 12 -- a respawn point must be this far from every player

-- AI (server, docs/enemies_npcs_pets_brief.txt Part B)
Enemies.AI = {
	TickSeconds = 0.1, -- 10 Hz
	LeashRadius = 60, -- the target farther than this from the enemy's spawn: go back and heal to full
	WanderRadius = 10,
	WanderEvery = { 3, 6 }, -- seconds between two idle walks
	WanderSpeedFactor = 0.4,
	LeashSpeedFactor = 1.3,
	RecoverSeconds = 0.35, -- pause after an attack
	MeleeCone = 120, -- degrees in front of the enemy hit by a melee attack
	MeleeReachBonus = 1.5, -- the player may be this much farther than AttackRange when the hit lands
	Knockback = 1.5, -- studs, normal enemies only
	ProjectileSpeed = 60,
	ProjectileRadius = 3.5, -- a shot hits players this close to its impact point
	StuckSeconds = 1.5, -- no progress for this long while chasing -> pathfinding fallback
	LookAhead = 0.25, -- seconds of movement given to the physics target each tick
	VisualRange = 160, -- players this close see shots and slams
	IdleWhenPausedAfter = 15, -- an empty sub-zone despawns its enemies after this many seconds (Playtest value)
}
Enemies.DEFAULTS = {
	AggroRadius = 30,
	MeleeRange = 2.5, -- studs from the body edge
	RangedRange = 40,
	AttackCooldown = 2,
	MeleeTelegraph = 0.4,
	RangedTelegraph = 0.5,
}
-- Default walk speeds (studs / s) per rig family; mini-bosses and bosses 10.
Enemies.SPEEDS = {
	Quadruped = 14, Biped = 12, Bird = 16, Serpent = 12, Arachnid = 15, Crustacean = 15, Insect = 15, Golem = 8,
	Snowman = 8, Fish = 12, Floater = 12, Amphibian = 12, Gorilla = 10, BossBiped = 10,
	mini = 10, boss = 10,
}
-- Mini-boss heavy attack and boss basic attack (Part C)
Enemies.MINI_ATTACK = { Telegraph = 0.5, Cooldown = 2, HeavyTelegraph = 1.0, HeavyMult = 1.5, HeavyCooldown = 6, HeavyRadius = 8 }
Enemies.BOSS_ATTACK = { Telegraph = 1.0, Cooldown = 3, Mult = 1.0, IntroSeconds = 2 }

-- LOOT (database section 2 and DESIGN.md section 5)
Enemies.LOOT_CHANCE = { normal = 0.02, mini = 0.04, boss = 0.06 } -- per kill, x Loot Luck (Stats LootMult)
Enemies.LOOT_KIND = { Egg = "Egg", Armor = "Armor", Weapon = "Armor", Corpse = "Trophy", Material = "Trophy", Trophy = "Trophy" }
Enemies.TROPHY_STORAGE = 100 -- head trophies kept; a new one when full is sold at once (toast)
Enemies.TROPHY_VALUE_BASE = 25 -- sale = 25 x enemy Gold x rarityMult x (1 + Trophy Value bonus)
-- diamonds (database section 3): mini-bosses 15% (2 + z, 3 + z), boss 40% (10 + 3z)
Enemies.DIAMONDS = { MiniChance = 0.15, BossChance = 0.40 }

-- Sale value of a head trophy: 25 x enemy Gold x rarityMult x (1 + Trophy Value bonus of the pets).
function Enemies.trophyValue(enemyId: string, tier: number, trophyBonus: number?): number
	local def = Enemies.ById[enemyId]
	if not def then
		return 0
	end
	return math.floor(Enemies.TROPHY_VALUE_BASE * def.Gold * Rarities.get(tier).DamageMult * (1 + (trophyBonus or 0)) + 0.5)
end

-- Loot rarity tier of an enemy (database section 2): b = ceil(zone / 2); sub-zones 1-2 b, 3-4 b + 1, mini b + 2,
-- boss b + 3, max 8 (Secret).
function Enemies.lootRarity(zoneIndex: number, subZone: number, tier: string): number
	local b = math.ceil(zoneIndex / 2)
	local value = if tier == "boss" then b + 3 elseif tier == "mini" then b + 2 elseif subZone >= 3 then b + 1 else b
	return math.min(8, value)
end

-- [zoneId] = { sub-zone 1 names, sub-zone 2 names, sub-zone 3 names, sub-zone 4 names, minis = {..}, boss = ".." }
local NAMES = {
	Plains = {
		{ "Boar", "Wild Wolf", "Field Bandit" },
		{ "Giant Crab", "Shipwrecked Pirate", "Aggressive Seagull" },
		{ "Brown Bear", "Forest Archer", "Giant Spider" },
		{ "Bat", "Miner Skeleton" },
		minis = { "Cave Troll", "Crystal Spider Matriarch" }, boss = "Golem",
	},
	Desert = {
		{ "Scorpion", "Sand Snake", "Vulture" },
		{ "Jackal", "Desert Crocodile", "Nomad Bandit" },
		{ "Sandstone Golem", "Royal Eagle", "Cliff Bandit" },
		{ "Mummy", "Giant Scarab" },
		minis = { "Anubis Guard", "Sandstorm Djinn" }, boss = "Cursed Pharaoh",
	},
	Jungle = {
		{ "Monkey", "Green Snake", "Venomous Spider" },
		{ "Piranha", "Toxic Frog", "Tribal Warrior" },
		{ "Jaguar", "Animated Statue", "Tribal Archer" },
		{ "Shaman", "Temple Guard" },
		minis = { "Elder Jaguar", "Tribal Warlord" }, boss = "Ancestral Gorilla",
	},
	Tundra = {
		{ "White Wolf", "Arctic Fox", "Cursed Snowman" },
		{ "Ice Spirit", "Polar Bear", "Swordfish" },
		{ "Yeti", "Furious Ibex", "Ice Eagle" },
		{ "Ice Knight", "Frost Golem" },
		minis = { "Frost Wolf Alpha", "Ice Knight Captain" }, boss = "Frost King",
	},
	Swamp = {
		{ "Giant Frog", "Leech", "Giant Mosquito" },
		{ "Living Tree", "Will-o'-Wisp", "Crow" },
		{ "Witch Apprentice", "Black Cat", "Scarecrow" },
		{ "Sorcerer Toad", "Mud Golem" },
		minis = { "Giant Toad Shaman", "Rotting Treant" }, boss = "Swamp Witch",
	},
	Volcano = {
		{ "Ash Lizard", "Fire Bat", "Charred Miner" },
		{ "Magma Dwarf", "Basalt Golem", "Rock Worm" },
		{ "Salamander", "Flame Spirit", "Lava Crab" },
		{ "Fire Elemental", "Obsidian Guardian" },
		minis = { "Magma Brute", "Lava Serpent" }, boss = "Magma Titan",
	},
	Hell = {
		{ "Imp", "Hellhound", "Scorched Zombie" },
		{ "Demon Guard", "Succubus", "Burning Skeleton" },
		{ "Infernal Knight", "Gargoyle", "Demon Archer" },
		{ "Elite Infernal Guard", "Demonic Mage" },
		minis = { "Hellhound Alpha", "Infernal Executioner" }, boss = "Supreme Demon",
	},
	Heaven = {
		{ "Glowing Bird", "Wind Spirit", "Celestial Deer" },
		{ "Storm Cloud", "Guardian Cherub", "Griffin" },
		{ "Celestial Soldier", "Winged Archer", "Sacred Statue" },
		{ "Celestial Paladin", "Light Priest" },
		minis = { "Seraph Knight", "Storm Griffin Lord" }, boss = "Supreme Angel",
	},
	Dead = {
		{ "Zombie", "Ghost", "Ghoul" },
		{ "Skeleton Warrior", "Bone Rat", "Novice Necromancer" },
		{ "Haunted Monk", "Wailing Spectre", "Cursed Gargoyle" },
		{ "Undead Knight", "Royal Skeleton Guard" },
		minis = { "Skeleton General", "Banshee Queen" }, boss = "Lich King",
	},
	Abyss = {
		{ "Jellyfish", "Reef Shark", "Moray Eel" },
		{ "Drowned Pirate", "Octopus", "Armor Crab" },
		{ "Lanternfish", "Giant Squid", "Electric Eel" },
		{ "Triton Guard", "Corrupted Siren" },
		minis = { "Kraken Spawn", "Triton Captain" }, boss = "Leviathan",
	},
	Mechanical = {
		{ "Drone", "Assembly Robot", "Mechanical Rat" },
		{ "Cleaner Robot", "Mechanical Spider", "Toxic Slime" },
		{ "Laser Turret", "Guardian Robot", "Combat Drone" },
		{ "Soldier Robot", "Steel Golem" },
		minis = { "War Mech", "Sentinel Prime" }, boss = "Colossal Robot",
	},
	Void = {
		{ "Wandering Shadow", "Void Stalker", "Obsidian Sentinel" },
		{ "Crystal Golem", "Spectral Butterfly", "Void Spirit" },
		{ "Lost Voyager", "Phantom Archer", "Fallen Guardian" },
		{ "Void Knight", "Void Mage" },
		minis = { "Void Reaper", "Crystal Warden" }, boss = "Void Dragon",
	},
}

-- Zones 1-4 (Part F content list): rig, height, colors (main, accent, eyes), loot item and type of the database,
-- and the special behaviour flags (ranged attackers, flyers, fish and floaters hover).
local rgb = Color3.fromRGB
local EYES = rgb(20, 18, 24)
local LOOKS: { [string]: { any } } = {
	-- id = { Rig, Height, Color, Accent, LootName, LootType, flags? }
	plains_boar = { "Quadruped", 3, rgb(115, 78, 52), rgb(240, 230, 210), "Boar Corpse", "Corpse" },
	plains_wild_wolf = { "Quadruped", 4, rgb(130, 132, 142), rgb(225, 225, 230), "Wolf Pup Egg", "Egg" },
	plains_field_bandit = { "Biped", 5.5, rgb(64, 122, 62), rgb(124, 86, 54), "Rusty Sword", "Weapon" },
	plains_giant_crab = { "Crustacean", 4, rgb(232, 104, 52), rgb(252, 186, 128), "Crab Shell Shield", "Armor" },
	plains_shipwrecked_pirate = { "Biped", 5.5, rgb(206, 64, 60), rgb(44, 42, 52), "Cracked Cutlass", "Weapon" },
	plains_aggressive_seagull = { "Bird", 3, rgb(236, 238, 242), rgb(250, 160, 40), "Seagull Egg", "Egg", { Hover = 4 } },
	plains_brown_bear = { "Quadruped", 6, rgb(112, 72, 42), rgb(72, 46, 26), "Bear Corpse", "Corpse" },
	plains_forest_archer = { "Biped", 5.5, rgb(52, 112, 52), rgb(132, 92, 52), "Hunter's Shortbow", "Weapon", { Ranged = true } },
	plains_giant_spider = { "Arachnid", 4.5, rgb(72, 46, 72), rgb(150, 110, 90), "Spider Egg", "Egg", { Eyes = rgb(235, 40, 40) } },
	plains_bat = { "Bird", 2.5, rgb(52, 42, 62), rgb(150, 100, 140), "Bat Wing Cape", "Armor", { Hover = 4, Ranged = true } },
	plains_miner_skeleton = { "Biped", 5.5, rgb(232, 226, 206), rgb(232, 182, 42), "Miner's Pickaxe", "Weapon" },
	plains_cave_troll = { "Biped", 10, rgb(112, 132, 112), rgb(152, 122, 92), "Troll Club", "Weapon", { Bulky = true } },
	plains_crystal_spider_matriarch = { "Arachnid", 9, rgb(62, 52, 72), rgb(60, 222, 210), "Crystal Spider Egg", "Egg", { Eyes = rgb(80, 255, 240) } },
	plains_golem = { "Golem", 18, rgb(122, 92, 72), rgb(92, 162, 62), "Golem Core Gauntlets", "Weapon", { Eyes = rgb(90, 255, 120) } },

	desert_scorpion = { "Arachnid", 3.5, rgb(212, 172, 102), rgb(122, 82, 42), "Scorpion Stinger", "Weapon" },
	desert_sand_snake = { "Serpent", 6, rgb(226, 196, 112), rgb(92, 72, 42), "Sand Snake Egg", "Egg" },
	desert_vulture = { "Bird", 4, rgb(92, 62, 42), rgb(222, 172, 162), "Vulture Corpse", "Corpse", { Hover = 4 } },
	desert_jackal = { "Quadruped", 4, rgb(202, 162, 102), rgb(42, 36, 32), "Jackal Pelt Cloak", "Armor" },
	desert_crocodile = { "Quadruped", 7, rgb(132, 142, 82), rgb(212, 202, 152), "Crocodile Egg", "Egg", { Long = true } },
	desert_nomad_bandit = { "Biped", 5.5, rgb(232, 222, 192), rgb(172, 62, 52), "Curved Scimitar", "Weapon" },
	desert_sandstone_golem = { "Golem", 8, rgb(212, 172, 112), rgb(255, 202, 62), "Sandstone Fist", "Weapon", { Eyes = rgb(255, 210, 80) } },
	desert_royal_eagle = { "Bird", 4, rgb(162, 112, 52), rgb(62, 112, 232), "Eagle Egg", "Egg", { Hover = 4 } },
	desert_cliff_bandit = { "Biped", 5.5, rgb(142, 102, 62), rgb(202, 182, 142), "Bandit's Dagger Set", "Weapon" },
	desert_mummy = { "Biped", 5.5, rgb(232, 222, 192), rgb(182, 162, 122), "Mummy Wrappings", "Armor", { Eyes = rgb(255, 222, 62) } },
	desert_giant_scarab = { "Insect", 4, rgb(42, 142, 132), rgb(232, 192, 62), "Scarab Egg", "Egg" },
	desert_anubis_guard = { "Biped", 10, rgb(32, 32, 38), rgb(232, 182, 52), "Anubis Spear", "Weapon", { Eyes = rgb(255, 210, 70) } },
	desert_sandstorm_djinn = { "Floater", 9, rgb(112, 92, 222), rgb(242, 202, 92), "Djinn Lamp", "Trophy", { Hover = 1, Eyes = rgb(255, 240, 150) } },
	desert_cursed_pharaoh = { "BossBiped", 17, rgb(232, 182, 52), rgb(42, 82, 202), "Pharaoh's Scepter", "Weapon", { Eyes = rgb(80, 220, 255) } },

	jungle_monkey = { "Biped", 3.5, rgb(122, 82, 52), rgb(212, 172, 132), "Monkey Tail Whip", "Weapon" },
	jungle_green_snake = { "Serpent", 5, rgb(62, 202, 62), rgb(232, 232, 82), "Green Snake Egg", "Egg" },
	jungle_venomous_spider = { "Arachnid", 4, rgb(32, 62, 32), rgb(232, 212, 42), "Venom Fang Dagger", "Weapon", { Eyes = rgb(240, 230, 60) } },
	jungle_piranha = { "Fish", 2.5, rgb(192, 192, 202), rgb(212, 52, 52), "Piranha Jaw Blade", "Weapon", { Hover = 1.5 } },
	jungle_toxic_frog = { "Amphibian", 3.5, rgb(82, 212, 62), rgb(152, 62, 202), "Toxic Frog Egg", "Egg", { Ranged = true } },
	jungle_tribal_warrior = { "Biped", 5.5, rgb(152, 102, 72), rgb(222, 62, 52), "Tribal Spear", "Weapon" },
	jungle_jaguar = { "Quadruped", 5, rgb(222, 172, 62), rgb(42, 32, 22), "Jaguar Corpse", "Corpse" },
	jungle_animated_statue = { "Golem", 7, rgb(122, 132, 112), rgb(82, 255, 122), "Statue Fragment", "Material", { Eyes = rgb(82, 255, 122) } },
	jungle_tribal_archer = { "Biped", 5.5, rgb(142, 96, 66), rgb(62, 142, 62), "Poison Blowgun", "Weapon", { Ranged = true } },
	jungle_shaman = { "Biped", 6, rgb(122, 82, 62), rgb(232, 202, 82), "Shaman Totem", "Trophy", { Ranged = true } },
	jungle_temple_guard = { "Biped", 6.5, rgb(162, 122, 72), rgb(132, 132, 122), "Temple Guard Shield", "Armor" },
	jungle_elder_jaguar = { "Quadruped", 10, rgb(36, 32, 36), rgb(255, 202, 62), "Elder Jaguar Egg", "Egg", { Eyes = rgb(255, 202, 62) } },
	jungle_tribal_warlord = { "Biped", 10, rgb(132, 86, 62), rgb(202, 42, 42), "Warlord War Axe", "Weapon", { Bulky = true } },
	jungle_ancestral_gorilla = { "Gorilla", 18, rgb(76, 66, 62), rgb(232, 182, 62), "Ancestral Gorilla Egg", "Egg", { Eyes = rgb(255, 170, 40) } },

	tundra_white_wolf = { "Quadruped", 4, rgb(226, 236, 246), rgb(142, 172, 222), "White Wolf Egg", "Egg" },
	tundra_arctic_fox = { "Quadruped", 3, rgb(246, 246, 250), rgb(182, 202, 222), "Arctic Fox Pelt", "Armor" },
	tundra_cursed_snowman = { "Snowman", 5, rgb(242, 246, 255), rgb(122, 82, 52), "Cursed Snowman Corpse", "Corpse", { Eyes = rgb(170, 70, 240) } },
	tundra_ice_spirit = { "Floater", 4, rgb(152, 212, 255), rgb(222, 246, 255), "Ice Spirit Shard", "Material", { Hover = 1.5, Ranged = true, Eyes = rgb(230, 250, 255) } },
	tundra_polar_bear = { "Quadruped", 6.5, rgb(242, 242, 236), rgb(62, 62, 72), "Polar Bear Egg", "Egg" },
	tundra_swordfish = { "Fish", 4, rgb(72, 112, 172), rgb(202, 222, 242), "Frozen Swordfish", "Weapon", { Hover = 1.5, Bill = true } },
	tundra_yeti = { "Biped", 8, rgb(236, 242, 246), rgb(92, 142, 222), "Yeti Corpse", "Corpse", { Bulky = true } },
	tundra_furious_ibex = { "Quadruped", 5, rgb(172, 142, 112), rgb(222, 212, 192), "Ibex Horn Spear", "Weapon" },
	tundra_ice_eagle = { "Bird", 4.5, rgb(202, 226, 246), rgb(122, 172, 232), "Ice Eagle Egg", "Egg", { Hover = 4 } },
	tundra_ice_knight = { "Biped", 6, rgb(152, 202, 242), rgb(222, 242, 255), "Frostforged Blade", "Weapon" },
	tundra_frost_golem = { "Golem", 9, rgb(172, 212, 242), rgb(82, 182, 255), "Frost Golem Core", "Material", { Eyes = rgb(120, 220, 255) } },
	tundra_frost_wolf_alpha = { "Quadruped", 10, rgb(232, 242, 252), rgb(122, 202, 255), "Alpha Frost Wolf Egg", "Egg", { Eyes = rgb(120, 220, 255) } },
	tundra_ice_knight_captain = { "Biped", 10, rgb(122, 172, 222), rgb(242, 250, 255), "Captain's Ice Shield", "Armor" },
	tundra_frost_king = { "BossBiped", 18, rgb(112, 162, 222), rgb(232, 246, 255), "Crown of Frost", "Armor", { Eyes = rgb(150, 230, 255) } },
}
Enemies.LOOKS = LOOKS

-- "Desert Crocodile" in Desert -> "desert_crocodile"; "Will-o'-Wisp" in Swamp -> "swamp_will_o_wisp"
local function makeId(zoneId: string, name: string): string
	local slug = string.lower(name)
	slug = string.gsub(slug, "'", "")
	slug = string.gsub(slug, "[^%w]+", "_")
	local zonePrefix = string.lower(zoneId) .. "_"
	if string.sub(slug, 1, #zonePrefix) == zonePrefix then
		slug = string.sub(slug, #zonePrefix + 1)
	end
	return zonePrefix .. slug
end

Enemies.ById = {} :: { [string]: Enemy }
Enemies.BySubZone = {} :: { [string]: { Enemy } } -- normal enemies only, in database order
Enemies.BossRoom = {} :: { [string]: { Boss: Enemy, Mini1: Enemy, Mini2: Enemy } }

local function add(zoneId: string, subZone: number, name: string, role: string, hp: number, damagePct: number, goldPct: number): Enemy
	local tier = if role == "Boss" then "boss" elseif role == "MiniBoss" then "mini" else "normal"
	local enemy: Enemy = {
		Id = makeId(zoneId, name), Name = name, ZoneId = zoneId, SubZone = subZone, Role = role, Tier = tier,
		MaxHP = hp, Damage = hp * damagePct, Gold = hp * goldPct,
	}
	local look = LOOKS[enemy.Id]
	if look then
		local flags = look[7] or {}
		local d = Enemies.DEFAULTS
		local ranged = flags.Ranged == true
		enemy.Rig = look[1]
		enemy.Height = look[2]
		enemy.Color = look[3]
		enemy.Accent = look[4]
		enemy.Eyes = flags.Eyes or EYES
		enemy.Bulky = flags.Bulky
		enemy.Hover = flags.Hover or 0
		enemy.WalkSpeed = if tier ~= "normal" then Enemies.SPEEDS[tier] else Enemies.SPEEDS[look[1]] or 12
		enemy.AggroRadius = d.AggroRadius
		enemy.AttackType = if ranged then "ranged" else "melee"
		enemy.AttackRange = if ranged then d.RangedRange else d.MeleeRange
		enemy.AttackCooldown = if tier == "boss" then Enemies.BOSS_ATTACK.Cooldown else d.AttackCooldown
		enemy.Telegraph = if tier == "boss" then Enemies.BOSS_ATTACK.Telegraph
			elseif tier == "mini" then Enemies.MINI_ATTACK.Telegraph
			elseif ranged then d.RangedTelegraph
			else d.MeleeTelegraph
		enemy.Loot = { Name = look[5], Source = look[6], Kind = Enemies.LOOT_KIND[look[6]] or "Trophy" }
		enemy.LootRarity = Enemies.lootRarity(Zones.ById[zoneId].Index, subZone, tier)
		;(enemy :: any).Long = flags.Long
		;(enemy :: any).Bill = flags.Bill
	end
	assert(not Enemies.ById[enemy.Id], "duplicate enemy id " .. enemy.Id)
	Enemies.ById[enemy.Id] = enemy
	return enemy
end

for _, zone in ipairs(Zones.List) do
	local names = NAMES[zone.Id]
	for subZone = 1, Zones.SUBZONE_COUNT do
		local base = Enemies.BASE * 10 ^ (zone.Index - 1) * 2 ^ (subZone - 1)
		local mults = if subZone == Zones.BOSS_SUBZONE then Enemies.BOSS_ROOM_HP_MULT else Enemies.NORMAL_HP_MULT
		local list = {}
		for i, name in ipairs(names[subZone]) do
			table.insert(list, add(zone.Id, subZone, name, "Normal", base * mults[i], Enemies.NORMAL.DamagePct, Enemies.NORMAL.GoldPct))
		end
		Enemies.BySubZone[Zones.subZoneId(zone.Id, subZone)] = list
		if subZone == Zones.BOSS_SUBZONE then
			local mini = Enemies.MINI_BOSS
			Enemies.BossRoom[zone.Id] = {
				Mini1 = add(zone.Id, subZone, names.minis[1], "MiniBoss", base * mini.HpMult[1], mini.DamagePct, mini.GoldPct),
				Mini2 = add(zone.Id, subZone, names.minis[2], "MiniBoss", base * mini.HpMult[2], mini.DamagePct, mini.GoldPct),
				Boss = add(zone.Id, subZone, names.boss, "Boss", base * Enemies.BOSS.HpMult, Enemies.BOSS.DamagePct, Enemies.BOSS.GoldPct),
			}
		end
	end
end

return Enemies
