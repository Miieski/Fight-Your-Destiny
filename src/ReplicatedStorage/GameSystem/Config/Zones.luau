--!strict
-- Zones, sub-zones and prices (DESIGN.md sections 4 and 12, docs/zone_design_document.txt).
-- Pure data: no logic besides the price formulas.

export type Zone = {
	Id: string, -- used in instance names: workspace.Zones.<Id>.<Id>_<n>
	Index: number, -- 1..12, order of progression
	Name: string, -- display name
	SubZones: { string }, -- display names of sub-zones 1..4 (4 = boss room)
	Boss: string,
	Element: string,
}

local Zones = {}

Zones.SUBZONE_COUNT = 4
Zones.BOSS_SUBZONE = 4

Zones.List = {
	{ Id = "Plains", Index = 1, Name = "Plains", SubZones = { "Plains", "Beach", "Forest", "Cave" }, Boss = "Golem", Element = "Nature" },
	{ Id = "Desert", Index = 2, Name = "Desert", SubZones = { "Dunes", "Oasis", "Canyon", "Pyramid" }, Boss = "Cursed Pharaoh", Element = "Sand" },
	{ Id = "Jungle", Index = 3, Name = "Jungle", SubZones = { "Jungle Edge", "River", "Lost Temple", "Temple Heart" }, Boss = "Ancestral Gorilla", Element = "Poison" },
	{ Id = "Tundra", Index = 4, Name = "Tundra", SubZones = { "Snowy Plains", "Frozen Lake", "Mountain", "Ice Citadel" }, Boss = "Frost King", Element = "Frost" },
	{ Id = "Swamp", Index = 5, Name = "Cursed Swamp", SubZones = { "Marsh", "Dead Forest", "Witch Village", "Giant Cauldron" }, Boss = "Swamp Witch", Element = "Curse" },
	{ Id = "Volcano", Index = 6, Name = "Volcano", SubZones = { "Volcano Foot", "Magma Mine", "Lava River", "Crater" }, Boss = "Magma Titan", Element = "Burn" },
	{ Id = "Hell", Index = 7, Name = "Hell", SubZones = { "Hellish Plains", "Hell City", "Castle Entrance", "Throne Room" }, Boss = "Supreme Demon", Element = "Hellfire" },
	{ Id = "Heaven", Index = 8, Name = "Heaven", SubZones = { "Sky Island", "Cloud Bridge", "Castle Entrance", "Throne Room" }, Boss = "Supreme Angel", Element = "Holy" },
	{ Id = "Dead", Index = 9, Name = "Realm of the Dead", SubZones = { "Graveyard", "Catacombs", "Haunted Cathedral", "Royal Sarcophagus Room" }, Boss = "Lich King", Element = "Soul Drain" },
	{ Id = "Abyss", Index = 10, Name = "Abyss", SubZones = { "Coral Reef", "Shipwreck", "Abyssal Trench", "Sunken Palace" }, Boss = "Leviathan", Element = "Tidal" },
	{ Id = "Mechanical", Index = 11, Name = "Mechanical City", SubZones = { "Abandoned Factory", "Industrial Sewers", "Control Center", "Reactor Core" }, Boss = "Colossal Robot", Element = "Shock" },
	{ Id = "Void", Index = 12, Name = "The Void", SubZones = { "Void Island", "Crystal Forest", "Voyagers' City", "Heart of the Void" }, Boss = "Void Dragon", Element = "Gravity" },
} :: { Zone }

Zones.ById = {} :: { [string]: Zone }
for _, zone in ipairs(Zones.List) do
	Zones.ById[zone.Id] = zone
end

-- Sub-zone price multipliers for sub-zones 2..4 (sub-zone 1 is free): x2.5 per sub-zone.
Zones.SUBZONE_BASE_PRICE = { [2] = 500, [3] = 1250, [4] = 3125 }
Zones.REBIRTH_COST_MULT = 10

function Zones.subZoneId(zoneId: string, n: number): string
	return `{zoneId}_{n}`
end

-- "Plains_3" -> "Plains", 3
function Zones.parseSubZoneId(subZoneId: string): (string?, number?)
	local zoneId, n = string.match(subZoneId, "^(%a+)_(%d)$")
	if zoneId and Zones.ById[zoneId] then
		return zoneId, tonumber(n)
	end
	return nil, nil
end

-- Teleport menu (docs/ui_redo_teleport_brief.txt part 2), in seconds.
Zones.TELEPORT = {
	Cooldown = 3, -- between two menu teleports
	CombatSeconds = 5, -- no teleport within this time after taking damage
	PortalRetry = 2, -- a refused hub portal (locked zone) tries again / shows its toast at most this often
}

-- Zones whose world is not built yet: the teleport menu shows them as "Coming soon".
Zones.NOT_BUILT = {} :: { [string]: boolean }

-- One-line description for the teleport menu preview.
Zones.Descriptions = {
	Plains = "Green hills, a windy beach and a quiet forest hiding the Golem's cave.",
	Desert = "Endless dunes, a lonely oasis and a red canyon leading to the Cursed Pharaoh's pyramid.",
	Jungle = "Thick vines, a wild river and a lost temple guarded by the Ancestral Gorilla.",
	Tundra = "Snowy plains, a frozen lake and an icy peak crowned by the Frost King's citadel.",
	Swamp = "Murky marshes, a dead forest and a witch village around a giant cauldron.",
	Volcano = "Ash fields, a magma mine and rivers of lava below the Magma Titan's crater.",
	Hell = "Burning plains and a demon city below the Supreme Demon's horned castle.",
	Heaven = "Floating islands and cloud bridges up to the Supreme Angel's golden throne.",
	Dead = "A haunted graveyard, endless catacombs and the Lich King's royal tomb.",
	Abyss = "Coral reefs, sunken ships and a dark trench leading to the Leviathan's palace.",
	Mechanical = "A rusty factory, toxic sewers and the reactor core of the Colossal Robot.",
	Void = "Floating obsidian islands and crystal forests at the heart of the Void Dragon's realm.",
} :: { [string]: string }

-- Why a zone is locked (DESIGN.md section 4: key of the previous boss, Rebirths, previous zone
-- redone since the last Rebirth). short = true gives the compact form for list rows.
-- No spoilers for locked zones (docs/enemies_npcs_pets_brief.txt 1A): what every UI and server message shows for a
-- zone the player has not unlocked. Clients go through GameClient/UI/Kit/ZoneVisibility.
Zones.HIDDEN_NAME = "???"
Zones.HIDDEN_REQUIREMENT = "Defeat the boss of the previous zone and Rebirth to reveal"
Zones.HIDDEN_SHORT = "Locked: defeat the previous boss and Rebirth"

-- Is the zone unlocked in this profile's Zones table (zone 1 always is)?
function Zones.isUnlocked(zonesTable: { [string]: any }?, zoneId: string?): boolean
	if zoneId == nil or zoneId == "Hub" then
		return true
	end
	local zone = Zones.ById[zoneId]
	return zone ~= nil and (zone.Index == 1 or (zonesTable ~= nil and zonesTable[zoneId] == true))
end

function Zones.requirementText(zoneId: string, short: boolean?): string
	local zone = Zones.ById[zoneId]
	local previous = zone and Zones.List[zone.Index - 1]
	if not (zone and previous) then
		return "Locked"
	end
	local rebirths = zone.Index - 1
	local plural = if rebirths == 1 then "" else "s"
	if short then
		return `Needs {previous.Boss} key + {rebirths} Rebirth{plural}`
	end
	return `Needs the {previous.Boss} key, {rebirths} Rebirth{plural} and {previous.Name} redone`
end

-- Gold price to open sub-zone n of a zone (0 for sub-zone 1).
function Zones.subZonePrice(zoneId: string, n: number): number
	local base = Zones.SUBZONE_BASE_PRICE[n]
	if not base then
		return 0
	end
	return base * 10 ^ (Zones.ById[zoneId].Index - 1)
end

return Zones
