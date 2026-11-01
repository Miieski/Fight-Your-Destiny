--!strict
-- Rebirth Protection ("Keep Forever", Round 8 part 5): the player pays Diamonds once for one item (a weapon, an armor piece or a
-- pet: the item instance, its uid, not its type) and keeps it through every Rebirth. No limit on the number of items.
-- Stored on the item: Protected = true, ProtectedPricePaid = n. Services/ProtectionService does the purchase, RebirthService the keep.
--   Price (Diamonds) = ceil(RarityBase[rarity] x ValueFactor(item) x CategoryMultiplier[category])
--   ValueFactor = 1 + PerZone x (zone of the item - 1). Review table: docs/rebirth_protection_prices.md.
local Armor = require(script.Parent.Armor)
local Pets = require(script.Parent.Pets)
local Weapons = require(script.Parent.Weapons)

local RebirthProtection = {}

-- one per rarity tier of Config/Rarities (the 8 real ones), about x2.5 per step
RebirthProtection.RarityBase = { 5, 12, 30, 75, 190, 475, 1200, 3000 } -- Common .. Secret
RebirthProtection.PerZone = 0.15
RebirthProtection.CategoryMultiplier = { Weapon = 1, Armor = 1, Pet = 1 }
RebirthProtection.KeepEquippedState = true

-- category -> the profile key of its items
RebirthProtection.Keys = { Weapon = "Weapons", Armor = "Armor", Pet = "Pets" }
RebirthProtection.Categories = { "Weapon", "Armor", "Pet" }

function RebirthProtection.zoneOf(category: string, item: { [string]: any }): number
	local def: any = nil
	if category == "Weapon" then
		def = Weapons.ById[item.id]
	elseif category == "Armor" then
		def = Armor.ById[item.id]
	elseif category == "Pet" then
		def = Pets.ById[item.id]
	end
	return math.max(1, tonumber(def and def.Zone) or 1) -- the special pets have no zone: zone 1
end

function RebirthProtection.priceOf(rarity: number, zone: number, category: string): number
	local base = RebirthProtection.RarityBase[rarity] or RebirthProtection.RarityBase[#RebirthProtection.RarityBase]
	local value = 1 + RebirthProtection.PerZone * (zone - 1)
	return math.ceil(base * value * (RebirthProtection.CategoryMultiplier[category] or 1) - 1e-9)
end

function RebirthProtection.price(category: string, item: { [string]: any }): number
	return RebirthProtection.priceOf(item.rarity or 1, RebirthProtection.zoneOf(category, item), category)
end

-- Which item of a profile-like table a uid is: category, profile key, item (nil when it is not owned).
function RebirthProtection.find(data: { [string]: any }, uid: any): (string?, string?, { [string]: any }?)
	if typeof(uid) ~= "string" then
		return nil, nil, nil
	end
	for _, category in ipairs(RebirthProtection.Categories) do
		local key = RebirthProtection.Keys[category]
		local item = (data[key] or {})[uid]
		if typeof(item) == "table" then
			return category, key, item
		end
	end
	return nil, nil, nil
end

return RebirthProtection
