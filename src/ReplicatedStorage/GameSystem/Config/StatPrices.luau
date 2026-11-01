--!strict
-- Price of the attribute points (Round 8 part 4). The next point costs Base x Growth ^ L x rebirthMultiplier(Rebirths), rounded;
-- L = the attribute level (total points bought, every stat shares it). The server computes it (StatsService); the Stats
-- window shows the same formula. Review table: docs/stat_prices.md.
--   Base: the first points are paid with the first fights of zone 1 (a Plains_1 enemy gives 16-24 Gold; docs/NIGHT_LOG.md).
--   Growth: a little above the old 1.1, so that the last points still come at the very end of the game.
--   Per Rebirth (owner): the price grows 5 points less than the Gold gain, compounded, never below 0. The Gold bonus of the
--   game is additive on the base (RebirthShop.rebirthGoldBonus: +50% for the first, up to +100% for the 12th), so the gain
--   of Rebirth r is its real step: goldMultiplier(r) / goldMultiplier(r - 1) - 1 (+50% ... +11%).
local RebirthShop = require(script.Parent.RebirthShop)

local StatPrices = {}

StatPrices.Base = 15
StatPrices.Growth = 1.105
StatPrices.PointsLessThanGold = 0.05

local function gold(r: number): number
	return 1 + RebirthShop.rebirthGoldBonus(r)
end

-- The Gold gain of Rebirth r, as a fraction of the Gold before it.
function StatPrices.goldStep(r: number): number
	return gold(r) / gold(r - 1) - 1
end

-- The price step of Rebirth r.
function StatPrices.priceStep(r: number): number
	return math.max(0, StatPrices.goldStep(r) - StatPrices.PointsLessThanGold)
end

function StatPrices.rebirthMultiplier(rebirths: number?): number
	local total = 1
	for r = 1, math.max(0, math.floor(rebirths or 0)) do
		total *= 1 + StatPrices.priceStep(r)
	end
	return total
end

-- Gold price of the next point at attribute level L after that many Rebirths.
function StatPrices.cost(level: number, rebirths: number?): number
	return math.max(1, math.round(StatPrices.Base * StatPrices.Growth ^ level * StatPrices.rebirthMultiplier(rebirths)))
end

return StatPrices
