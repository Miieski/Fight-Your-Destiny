--!strict
-- The 36 armor pieces (docs/menu_systems_brief.txt C1): Helmet, Chest and Legs for each of the 12 zones.
--   Piece HP = 100 x 10^(zone-1) x slotShare x rarityMult; Defense = 3 x rarity tier.
--   In the piece's own zone its rarity's Zone Boost (+5% .. +120%) multiplies both.
--   Set bonus: the 3 pieces of the SAME zone -> +10% Max HP (Util/Stats) and +10% Zone Boost effectiveness.
-- Ids "<zone lower>_helmet|_chest|_legs". Items in profile.Armor = { [uid] = { id, rarity, locked? } },
-- equipped in profile.EquippedArmor = { Helmet = uid, Chest = uid, Legs = uid }.
-- Palette = the in-world look (GameSystem/Util/ArmorLook): Main, Second, Accent, Glow (accent is neon).
local Rarities = require(script.Parent.Rarities)
local Zones = require(script.Parent.Zones)

export type Piece = { Id: string, Name: string, ZoneId: string, Zone: number, Slot: string, Palette: { [string]: any } }

local Armor = {}

Armor.SLOTS = { "Helmet", "Chest", "Legs" }
Armor.SlotShare = { Helmet = 0.25, Chest = 0.45, Legs = 0.30 }
Armor.BaseHP = 100
Armor.DefensePerTier = 3
Armor.Storage = 100
Armor.SellBase = 200 -- sell value = rarityMult x 200 x 10^(zone-1) Gold
Armor.SetSize = 3
Armor.SetHPBonus = 0.10 -- read by Util/Stats (Max HP)
Armor.SetBoostBonus = 0.10 -- Zone Boost x 1.10 with a full set
Armor.ShimmerFrom = 4 -- Epic and rarer pieces shimmer in the world
Armor.SLOT_ICONS = { Helmet = "Helmet", Chest = "Chest", Legs = "Legs" }

local NAMES = {
	Plains = { "Ranger Helm", "Ranger Chestplate", "Ranger Greaves" },
	Desert = { "Nomad Headwrap", "Nomad Cuirass", "Nomad Leggings" },
	Jungle = { "Tribal Mask", "Tribal Vest", "Tribal Leg Wraps" },
	Tundra = { "Frostguard Helm", "Frostguard Plate", "Frostguard Greaves" },
	Swamp = { "Bogwitch Hat", "Bogwitch Robe", "Bog Waders" },
	Volcano = { "Magma Helm", "Magma Cuirass", "Magma Greaves" },
	Hell = { "Infernal Horned Helm", "Infernal Plate", "Infernal Greaves" },
	Heaven = { "Radiant Halo Helm", "Radiant Breastplate", "Radiant Greaves" },
	Dead = { "Deathbound Skull Helm", "Deathbound Cuirass", "Deathbound Greaves" },
	Abyss = { "Coral Crown Helm", "Tidal Scale Mail", "Tidal Greaves" },
	Mechanical = { "Cyber Visor", "Cyber Chassis", "Cyber Leg Servos" },
	Void = { "Voidforged Helm", "Voidforged Cuirass", "Voidforged Greaves" },
}

-- C4 palettes. Helmet = the head feature (ArmorLook builds it).
local hex = Color3.fromHex
local PALETTES = {
	Plains = { Main = hex("#9AA0A8"), Second = hex("#5E8A3A"), Accent = hex("#C9CED6"), Glow = false, Helmet = "Crest" },
	Desert = { Main = hex("#D9B77A"), Second = hex("#E2B04A"), Accent = hex("#1FA59A"), Glow = false, Helmet = "Wrap" },
	Jungle = { Main = hex("#2E7A3A"), Second = hex("#6E4A2A"), Accent = hex("#EFE6CC"), Glow = false, Helmet = "Mask" },
	Tundra = { Main = hex("#7CC8EE"), Second = hex("#F2F6FA"), Accent = hex("#C8E8FF"), Glow = false, Helmet = "Fur" },
	Swamp = { Main = hex("#5A6E3A"), Second = hex("#7A4AA0"), Accent = hex("#E8D84A"), Glow = false, Helmet = "Hat" },
	Volcano = { Main = hex("#2A2224"), Second = hex("#4A3A38"), Accent = hex("#FF6A1F"), Glow = true, Helmet = "Horns" },
	Hell = { Main = hex("#8A1A1A"), Second = hex("#1A0E0E"), Accent = hex("#FF8A2A"), Glow = false, Helmet = "BigHorns" },
	Heaven = { Main = hex("#F5F5F5"), Second = hex("#E8C25A"), Accent = hex("#FFE070"), Glow = true, Helmet = "Halo" },
	Dead = { Main = hex("#B8B0A0"), Second = hex("#5A5A66"), Accent = hex("#7CFFB0"), Glow = true, Helmet = "Skull" },
	Abyss = { Main = hex("#1FA59A"), Second = hex("#FF7FAB"), Accent = hex("#5FFFF0"), Glow = false, Helmet = "Coral" },
	Mechanical = { Main = hex("#9AA4B2"), Second = hex("#3A3F48"), Accent = hex("#FF8A2A"), Glow = true, Helmet = "Visor" },
	Void = { Main = hex("#1E1428"), Second = hex("#3A2850"), Accent = hex("#B05BFF"), Glow = true, Helmet = "Crest" },
}

Armor.ById = {} :: { [string]: Piece }
Armor.List = {} :: { Piece }
Armor.BySlot = { Helmet = {}, Chest = {}, Legs = {} } :: { [string]: { Piece } }
for _, zone in ipairs(Zones.List) do
	for i, slot in ipairs(Armor.SLOTS) do
		local piece: Piece = {
			Id = `{string.lower(zone.Id)}_{string.lower(slot)}`,
			Name = NAMES[zone.Id][i],
			ZoneId = zone.Id,
			Zone = zone.Index,
			Slot = slot,
			Palette = PALETTES[zone.Id],
		}
		Armor.ById[piece.Id] = piece
		table.insert(Armor.List, piece)
		table.insert(Armor.BySlot[slot], piece)
	end
end

-- HP and Defense of one piece, without and with its Zone Boost.
function Armor.baseHP(id: string, tier: number): number
	local piece = Armor.ById[id]
	if not piece then
		return 0
	end
	return Armor.BaseHP * 10 ^ (piece.Zone - 1) * Armor.SlotShare[piece.Slot] * Rarities.get(tier).DamageMult
end

function Armor.baseDefense(tier: number): number
	return Armor.DefensePerTier * Rarities.get(tier).Tier
end

-- { hp, defense, boosted } of a piece standing in zoneId (setActive = full set of its zone worn).
function Armor.pieceStats(id: string, tier: number, zoneId: string?, setActive: boolean?): (number, number, boolean)
	local piece = Armor.ById[id]
	if not piece then
		return 0, 0, false
	end
	local hp, defense = Armor.baseHP(id, tier), Armor.baseDefense(tier)
	local boosted = zoneId ~= nil and zoneId == piece.ZoneId
	if boosted then
		local boost = Rarities.get(tier).ZoneBoost * (if setActive then 1 + Armor.SetBoostBonus else 1)
		hp *= 1 + boost
		defense *= 1 + boost
	end
	return hp, defense, boosted
end

-- Equip Best score in the current zone: pieceHP x (1 + Defense / 100).
function Armor.score(id: string, tier: number, zoneId: string?): number
	local hp, defense = Armor.pieceStats(id, tier, zoneId, false)
	return hp * (1 + defense / 100)
end

function Armor.sellValue(id: string, tier: number): number
	local piece = Armor.ById[id]
	local zone = if piece then piece.Zone else 1
	return Rarities.get(tier).DamageMult * Armor.SellBase * 10 ^ (zone - 1)
end

-- The equipped pieces that exist in the inventory, by slot: { [slot] = { uid, id, rarity } }.
function Armor.equipped(data: { [string]: any }): { [string]: { uid: string, id: string, rarity: number } }
	local out = {}
	local owned = data.Armor or {}
	for slot, uid in pairs(data.EquippedArmor or {}) do
		local item = owned[uid]
		local piece = item and Armor.ById[item.id]
		if piece and piece.Slot == slot then
			out[slot] = { uid = uid, id = item.id, rarity = item.rarity }
		end
	end
	return out
end

-- Totals for Util/Stats: HP, Defense (Zone Boost included), set zone / count, which slots are boosted, and the
-- per-slot numbers for the Equipment screen.
function Armor.totals(data: { [string]: any }, zoneId: string?): { [string]: any }
	local worn = Armor.equipped(data)
	local counts: { [string]: number } = {}
	local setZone, setCount = nil :: string?, 0
	for _, slot in ipairs(Armor.SLOTS) do
		local item = worn[slot]
		if item then
			local zid = Armor.ById[item.id].ZoneId
			counts[zid] = (counts[zid] or 0) + 1
			if counts[zid] > setCount then
				setZone, setCount = zid, counts[zid]
			end
		end
	end
	local setActive = setCount >= Armor.SetSize
	local totals = { HP = 0, Defense = 0, SetZone = setZone, SetCount = setCount, Boosted = {} :: { [string]: boolean }, PerSlot = {} :: { [string]: any } }
	for _, slot in ipairs(Armor.SLOTS) do
		local item = worn[slot]
		if item then
			local full = setActive and Armor.ById[item.id].ZoneId == setZone
			local hp, defense, boosted = Armor.pieceStats(item.id, item.rarity, zoneId, full)
			totals.HP += hp
			totals.Defense += defense
			totals.Boosted[slot] = boosted
			totals.PerSlot[slot] = { HP = hp, Defense = defense, Boosted = boosted }
		end
	end
	return totals
end

return Armor
