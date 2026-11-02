--!strict
-- After a Rebirth, the next zone is bought (Round 8 part 4): the BOSS KEY of the previous zone + GOLD. The player no longer walks
-- through the whole zone again. ZoneService handles Net "BuyZoneUnlock" with these rules; the Zones menu shows them (a
-- locked portal shows nothing, Round 9 part 12). A zone bought this way gives its entry and first area; its other sub-zones keep their prices.
-- Price = (price of the LAST purchasable sub-zone of the previous zone + price of the 2nd sub-zone of this zone) / 2, floored
-- to 2 significant digits. Review table: docs/rebirth_zone_unlock_prices.md.
local Zones = require(script.Parent.Zones)

local RebirthZoneUnlock = {}

RebirthZoneUnlock.SignificantDigits = 2

local function floorTo(value: number, digits: number): number
	if value <= 0 then
		return 0
	end
	local unit = 10 ^ (math.floor(math.log10(value)) - digits + 1)
	return math.floor(value / unit + 1e-9) * unit
end

function RebirthZoneUnlock.priceOf(zoneId: string): number?
	local zone = Zones.ById[zoneId]
	local previous = zone and Zones.List[zone.Index - 1]
	if not (zone and previous) then
		return nil
	end
	local average = (Zones.subZonePrice(previous.Id, Zones.SUBZONE_COUNT) + Zones.subZonePrice(zone.Id, 2)) / 2
	return floorTo(average, RebirthZoneUnlock.SignificantDigits)
end

-- [zoneId] = price, every zone transition (zone 1 is free)
RebirthZoneUnlock.Prices = {} :: { [string]: number }
for _, zone in ipairs(Zones.List) do
	RebirthZoneUnlock.Prices[zone.Id] = RebirthZoneUnlock.priceOf(zone.Id)
end

export type Status = { eligible: boolean, open: boolean, hasKey: boolean, enoughGold: boolean, ready: boolean, price: number, previous: any, reason: string? }

-- For a profile-like table { Zones, Keys, Rebirths, Gold } (server profile or client State).
-- eligible: this is the zone to buy now (the previous one is open and enough Rebirths are done).
function RebirthZoneUnlock.status(data: { [string]: any }, zoneId: string): Status
	local zone = Zones.ById[zoneId]
	local previous = zone and Zones.List[zone.Index - 1]
	local price = RebirthZoneUnlock.Prices[zoneId] or 0
	local result: Status = { eligible = false, open = false, hasKey = false, enoughGold = false, ready = false, price = price, previous = previous, reason = "Not available" }
	if not (zone and previous) then
		result.open = zone ~= nil
		return result
	end
	result.open = Zones.isUnlocked(data.Zones, zoneId)
	local rebirths = math.floor(tonumber(data.Rebirths) or 0)
	result.eligible = not result.open and not Zones.NOT_BUILT[zoneId] and Zones.isUnlocked(data.Zones, previous.Id) and rebirths >= zone.Index - 1
	result.hasKey = typeof(data.Keys) == "table" and data.Keys[previous.Id] == true
	result.enoughGold = (tonumber(data.Gold) or 0) >= price
	result.ready = result.eligible and result.hasKey and result.enoughGold
	if result.open then
		result.reason = "Already open"
	elseif not result.eligible then
		result.reason = Zones.requirementText(zoneId)
	elseif not result.hasKey then
		result.reason = "You need the boss key of the previous zone"
	elseif not result.enoughGold then
		result.reason = "Not enough Gold"
	else
		result.reason = nil
	end
	return result
end

return RebirthZoneUnlock
