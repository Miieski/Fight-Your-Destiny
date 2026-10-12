--!strict
-- Rebirth rules (DESIGN.md section 4). Pure data + pure checks, shared by RebirthService (server) and the Rebirth
-- tab of the Rebirth window (UI/Pages/RebirthPage).
--   Rebirth r (1..Max) needs the key of the zone-r boss, Rebirths == r - 1 and Gold >= Rebirth.cost(r) (10 x the price
--   of zone r's boss-room gate). The key is not consumed. Zone r is "the zone being redone": its gates reset, and
--   reopening its boss room afterwards (ZoneService) opens zone r + 1 (key r + r Rebirths + zone r redone).
local Attributes = require(script.Parent.Attributes)
local RebirthShop = require(script.Parent.RebirthShop)
local Zones = require(script.Parent.Zones)

local Rebirth = {}

Rebirth.Max = 12 -- one per boss key (DESIGN.md section 16, question 3)
Rebirth.CreditsPerRebirth = 3

-- What the Rebirth tab lists (the reset itself is RebirthService:Wipe).
Rebirth.Lost = { "Gold", "Weapons", "Armor", "Attribute points", "Eggs", "Pets (premium pets are kept)", "Trophies" }
Rebirth.Kept = { "Diamonds", "Boss keys", "Rebirth Credits and upgrades", "Premium pets", "Index", "Boosts and passes", "Unlocked zones" }

-- The zone of Rebirth r (its boss key is needed, it is the zone redone afterwards).
function Rebirth.zoneOf(r: number): Zones.Zone?
	return Zones.List[r]
end

-- Gold cost of Rebirth r: 10 x the price of zone r's boss-room gate.
function Rebirth.cost(r: number): number
	local zone = Zones.List[r]
	return if zone then Zones.REBIRTH_COST_MULT * Zones.subZonePrice(zone.Id, Zones.BOSS_SUBZONE) else math.huge
end

-- Total Gold multiplier after `rebirths` Rebirths (1 + the sum of the Rebirth bonuses).
function Rebirth.goldMultiplier(rebirths: number): number
	return 1 + RebirthShop.rebirthGoldBonus(rebirths)
end

-- Attribute power after `rebirths` Rebirths (every attribute point is this much stronger).
function Rebirth.power(rebirths: number): number
	return Attributes.rebirthPower(rebirths)
end

export type Status = {
	next: number, -- the Rebirth number that comes next (Max + 1 when all are done)
	maxed: boolean,
	zone: Zones.Zone?, -- zone of the next Rebirth
	cost: number,
	gold: number,
	hasKey: boolean,
	enoughGold: boolean,
	ready: boolean,
	reason: string?, -- why it is not ready (nil when ready)
}

-- The next Rebirth for a profile-like table { Rebirths, Gold, Keys } (server profile or client State).
function Rebirth.status(data: { [string]: any }): Status
	local rebirths = math.max(0, math.floor(tonumber(data.Rebirths) or 0))
	local r = rebirths + 1
	local gold = tonumber(data.Gold) or 0
	if r > Rebirth.Max then
		return { next = r, maxed = true, zone = nil, cost = 0, gold = gold, hasKey = false, enoughGold = false, ready = false, reason = "All Rebirths are done" }
	end
	local zone = Zones.List[r]
	local keys = data.Keys
	local hasKey = zone ~= nil and typeof(keys) == "table" and keys[zone.Id] == true
	local cost = Rebirth.cost(r)
	local enoughGold = gold >= cost
	local reason: string? = nil
	if not hasKey then
		reason = if zone then `Defeat the {zone.Boss} to get its key` else "Not available"
	elseif not enoughGold then
		reason = "Not enough Gold"
	end
	return { next = r, maxed = false, zone = zone, cost = cost, gold = gold, hasKey = hasKey, enoughGold = enoughGold, ready = reason == nil, reason = reason }
end

return Rebirth
