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
	abyss_sword = "rbxassetid://140705468541573",
	dead_sword = "rbxassetid://86350187699042",
	desert_sword = "rbxassetid://127203537657986",
	heaven_sword = "rbxassetid://115117176295789",
	hell_sword = "rbxassetid://115568529523971",
	jungle_sword = "rbxassetid://73574132420956",
	mechanical_sword = "rbxassetid://125746837454794",
	plains_sword = "rbxassetid://75894377351246",
	swamp_sword = "rbxassetid://128484317854811",
	tundra_sword = "rbxassetid://104079839321876",
	void_sword = "rbxassetid://114683905930446",
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
