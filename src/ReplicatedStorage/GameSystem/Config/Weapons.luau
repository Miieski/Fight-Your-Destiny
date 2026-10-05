--!strict
-- 8 categories x 12 zones = 96 weapons (docs/weapon_system_document.txt). Ids: "<zone lower>_<category lower>".
local Zones = require(script.Parent.Zones)

export type Category = { Id: string, Name: string, DamageMult: number, HitsPerSecond: number, Range: number, Melee: boolean }
export type Weapon = { Id: string, Name: string, ZoneId: string, Category: string, Icon: string? }

local Weapons = {}

Weapons.ZONE_BASE_DAMAGE = 10 -- x 10^(zone - 1)
Weapons.SHOP_BASE_PRICE = 1000 -- x 10^(zone - 1)

Weapons.Categories = {
	{ Id = "Sword", Name = "Sword", DamageMult = 1.0, HitsPerSecond = 1.0, Range = 6, Melee = true },
	{ Id = "Spear", Name = "Spear", DamageMult = 1.2, HitsPerSecond = 0.9, Range = 10, Melee = true },
	{ Id = "Heavy", Name = "Heavy", DamageMult = 2.5, HitsPerSecond = 0.4, Range = 6, Melee = true },
	{ Id = "Dagger", Name = "Dagger", DamageMult = 0.4, HitsPerSecond = 2.5, Range = 4, Melee = true },
	{ Id = "Gauntlet", Name = "Gauntlet", DamageMult = 0.6, HitsPerSecond = 1.8, Range = 5, Melee = true },
	{ Id = "Ranged", Name = "Ranged", DamageMult = 0.8, HitsPerSecond = 1.2, Range = 60, Melee = false },
	{ Id = "Magic", Name = "Magic", DamageMult = 0.8, HitsPerSecond = 1.0, Range = 35, Melee = false },
	{ Id = "Whip", Name = "Whip & Chain", DamageMult = 0.9, HitsPerSecond = 1.1, Range = 12, Melee = true },
} :: { Category }

-- ICONS BEGIN
-- Weapon icons (Icons/Weapons/<Category>/<NN>_<id>_icon.png), filled in as each category is made.
local ICONS: { [string]: string } = {
	abyss_dagger = "rbxassetid://121352156006496",
	abyss_gauntlet = "rbxassetid://105544516655870",
	abyss_heavy = "rbxassetid://127217505712705",
	abyss_magic = "rbxassetid://124411550949391",
	abyss_ranged = "rbxassetid://97995107822512",
	abyss_spear = "rbxassetid://102828414148654",
	abyss_sword = "rbxassetid://140705468541573",
	dead_dagger = "rbxassetid://79263806196546",
	dead_gauntlet = "rbxassetid://117388436835380",
	dead_heavy = "rbxassetid://136226146917964",
	dead_magic = "rbxassetid://125919149275111",
	dead_ranged = "rbxassetid://112356627800092",
	dead_spear = "rbxassetid://115971354260490",
	dead_sword = "rbxassetid://86350187699042",
	desert_dagger = "rbxassetid://80769431678520",
	desert_gauntlet = "rbxassetid://140513919785351",
	desert_heavy = "rbxassetid://91449788324392",
	desert_magic = "rbxassetid://125583414576401",
	desert_ranged = "rbxassetid://82800104861443",
	desert_spear = "rbxassetid://130304382924941",
	desert_sword = "rbxassetid://127203537657986",
	heaven_dagger = "rbxassetid://125500276175834",
	heaven_gauntlet = "rbxassetid://80021136948391",
	heaven_heavy = "rbxassetid://133423625377016",
	heaven_magic = "rbxassetid://82264301837554",
	heaven_ranged = "rbxassetid://138020324207787",
	heaven_spear = "rbxassetid://125293223326464",
	heaven_sword = "rbxassetid://115117176295789",
	hell_dagger = "rbxassetid://114379121679101",
	hell_gauntlet = "rbxassetid://109593543598583",
	hell_heavy = "rbxassetid://73260158876105",
	hell_magic = "rbxassetid://97405863103612",
	hell_ranged = "rbxassetid://72252551214812",
	hell_spear = "rbxassetid://77484183713373",
	hell_sword = "rbxassetid://115568529523971",
	jungle_dagger = "rbxassetid://80365365646322",
	jungle_gauntlet = "rbxassetid://79543148939645",
	jungle_heavy = "rbxassetid://71687581202589",
	jungle_magic = "rbxassetid://115098708827011",
	jungle_ranged = "rbxassetid://100020057417066",
	jungle_spear = "rbxassetid://120336713062825",
	jungle_sword = "rbxassetid://73574132420956",
	mechanical_dagger = "rbxassetid://84907284765428",
	mechanical_gauntlet = "rbxassetid://108198929546310",
	mechanical_heavy = "rbxassetid://74200144440698",
	mechanical_magic = "rbxassetid://115166658245698",
	mechanical_ranged = "rbxassetid://118602386622794",
	mechanical_spear = "rbxassetid://120270748769824",
	mechanical_sword = "rbxassetid://125746837454794",
	plains_dagger = "rbxassetid://104697896741545",
	plains_gauntlet = "rbxassetid://123020380647015",
	plains_heavy = "rbxassetid://130534127780120",
	plains_magic = "rbxassetid://104650324095907",
	plains_ranged = "rbxassetid://70685182438815",
	plains_spear = "rbxassetid://71400183932637",
	plains_sword = "rbxassetid://75894377351246",
	swamp_dagger = "rbxassetid://71273846124406",
	swamp_gauntlet = "rbxassetid://125594295636505",
	swamp_heavy = "rbxassetid://111414243163616",
	swamp_magic = "rbxassetid://124875548378639",
	swamp_ranged = "rbxassetid://83084086676562",
	swamp_spear = "rbxassetid://107865546779607",
	swamp_sword = "rbxassetid://128484317854811",
	tundra_dagger = "rbxassetid://82139952524102",
	tundra_gauntlet = "rbxassetid://104829630921097",
	tundra_heavy = "rbxassetid://85980397077175",
	tundra_magic = "rbxassetid://122111764115214",
	tundra_ranged = "rbxassetid://136169629960694",
	tundra_spear = "rbxassetid://113434317061374",
	tundra_sword = "rbxassetid://104079839321876",
	void_dagger = "rbxassetid://110930016138754",
	void_gauntlet = "rbxassetid://84333124268760",
	void_heavy = "rbxassetid://136104271834738",
	void_magic = "rbxassetid://133994291514591",
	void_ranged = "rbxassetid://80946372819099",
	void_spear = "rbxassetid://103041162156233",
	void_sword = "rbxassetid://114683905930446",
	volcano_dagger = "rbxassetid://90066620308550",
	volcano_gauntlet = "rbxassetid://75830267899586",
	volcano_heavy = "rbxassetid://131757062024385",
	volcano_magic = "rbxassetid://132900539392146",
	volcano_ranged = "rbxassetid://78939561471445",
	volcano_spear = "rbxassetid://103125123734578",
	volcano_sword = "rbxassetid://94960393474724",
}
-- ICONS END

-- Names per zone, in the category order above.
local NAMES = {
	Plains = { "Iron Shortsword", "Hunter's Spear", "Stone Hammer", "Hunter's Knife", "Leather Knuckles", "Hunting Bow", "Apprentice Staff", "Vine Whip" },
	Desert = { "Sand Scimitar", "Nomad Pike", "Obelisk Hammer", "Scorpion Dagger", "Desert Wraps", "Desert Recurve Bow", "Sandstorm Staff", "Scarab Whip" },
	Jungle = { "Jungle Machete", "Tribal Spear", "Totem Club", "Venom Fang", "Jaguar Claws", "Poison Blowgun", "Shaman Totem Staff", "Liana Whip" },
	Tundra = { "Frostbrand Blade", "Icicle Lance", "Glacier Axe", "Ice Shard Dagger", "Frost Knuckles", "Frostbite Crossbow", "Blizzard Staff", "Frozen Chain" },
	Swamp = { "Rotwood Sword", "Witch Hunter Spear", "Swamp Maul", "Toad Tooth Dagger", "Mud Fists", "Plague Bow", "Cauldron Staff", "Leech Whip" },
	Volcano = { "Magma Blade", "Obsidian Spear", "Lava Hammer", "Ember Dagger", "Magma Gauntlets", "Flame Bow", "Eruption Staff", "Lava Chain" },
	Hell = { "Demon Blade", "Infernal Halberd", "Doom Axe", "Imp Claw Dagger", "Demon Fists", "Soulfire Crossbow", "Infernal Tome Staff", "Soul Chain" },
	Heaven = { "Radiant Longsword", "Celestial Lance", "Judgment Hammer", "Feather Dagger", "Angelic Gauntlets", "Dawn Bow", "Seraph Staff", "Radiant Whip" },
	Dead = { "Deathbringer Sword", "Grave Pike", "Gravedigger's Maul", "Ghoul Fang", "Bone Knuckles", "Bone Crossbow", "Lich Staff", "Spine Whip" },
	Abyss = { "Tidal Sword", "Deepsea Trident", "Kraken Anchor", "Angler Dagger", "Pearl Gauntlets", "Harpoon Gun", "Tidecaller Staff", "Tentacle Whip" },
	Mechanical = { "Plasma Sword", "Electro Lance", "Hydraulic Hammer", "Nano Dagger", "Power Gauntlets", "Pulse Rifle", "Tesla Coil Staff", "Electro Whip" },
	Void = { "Voidforged Blade", "Void Piercer", "Void Maul", "Rift Dagger", "Singularity Gauntlets", "Starfall Bow", "Void Staff", "Rift Chain" },
}

function Weapons.idOf(zoneId: string, categoryId: string): string
	return string.lower(zoneId) .. "_" .. string.lower(categoryId)
end

Weapons.ById = {} :: { [string]: Weapon }
Weapons.CategoryById = {} :: { [string]: Category }
for _, category in ipairs(Weapons.Categories) do
	Weapons.CategoryById[category.Id] = category
end
for _, zone in ipairs(Zones.List) do
	for i, category in ipairs(Weapons.Categories) do
		local id = Weapons.idOf(zone.Id, category.Id)
		Weapons.ById[id] = { Id = id, Name = NAMES[zone.Id][i], ZoneId = zone.Id, Category = category.Id, Icon = ICONS[id] }
	end
end

return Weapons
