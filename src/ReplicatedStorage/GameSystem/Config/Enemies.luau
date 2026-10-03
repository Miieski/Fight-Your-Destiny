--!strict
-- Enemies, mini-bosses and bosses (docs/enemy_database.txt is the source of truth).
-- Stats follow the database formulas, so only names are listed here.

local Zones = require(script.Parent.Zones)

export type Enemy = {
	Id: string, -- "<zone>_<name>", for example "plains_boar"
	Name: string,
	ZoneId: string,
	SubZone: number,
	Role: string, -- "Normal" | "MiniBoss" | "Boss"
	MaxHP: number,
	Damage: number,
	Gold: number,
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
	local enemy: Enemy = {
		Id = makeId(zoneId, name), Name = name, ZoneId = zoneId, SubZone = subZone, Role = role,
		MaxHP = hp, Damage = hp * damagePct, Gold = hp * goldPct,
	}
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
