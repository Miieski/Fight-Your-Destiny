--!strict
-- Weapon shop roll check (docs/weapon_shop_brief.txt, acceptance): runs the server's real roll function
-- (ShopService.roll) many times and compares the frequencies with Config/WeaponRarities, then checks the
-- pity rules. Run on the server (Play > Server, or the command bar in a test server):
--   print(require(game.ServerStorage.DevTools.WeaponRollSim)(100000))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local WeaponRarities = require(ReplicatedStorage.GameSystem.Config.WeaponRarities)
local ShopService = require(ServerScriptService.GameSystem.Services.ShopService)

return function(count: number?, seed: number?): string
	local n = count or 100000
	local rng = Random.new(seed or 1)
	local list = WeaponRarities.List
	local lines = {}
	local function line(text: string)
		table.insert(lines, text)
	end

	-- 1. raw odds: no pity (counters always 0)
	local raw = table.create(#list, 0)
	for _ = 1, n do
		local tier = ShopService.roll(rng, { PityCounter = 0, PityLegendary = 0 })
		raw[tier] += 1
	end
	-- 2. one player's purchases in a row: the counters carry over
	local seq = table.create(#list, 0)
	local counters = { PityCounter = 0, PityLegendary = 0 }
	local epicTriggers, legendaryTriggers, wrongTriggers = 0, 0, 0
	local longestNoEpic, longestNoLegendary, streakEpic, streakLegendary = 0, 0, 0, 0
	for _ = 1, n do
		local before = counters
		local tier, nextCounters, reason = ShopService.roll(rng, counters)
		if reason == "Epic or better" then
			epicTriggers += 1
			if before.PityCounter ~= 30 then
				wrongTriggers += 1
			end
		elseif reason == "Legendary or better" then
			legendaryTriggers += 1
			if before.PityLegendary ~= 100 then
				wrongTriggers += 1
			end
		end
		seq[tier] += 1
		streakEpic = if tier >= 4 then 0 else streakEpic + 1
		streakLegendary = if tier >= 5 then 0 else streakLegendary + 1
		longestNoEpic = math.max(longestNoEpic, streakEpic)
		longestNoLegendary = math.max(longestNoLegendary, streakLegendary)
		counters = nextCounters
	end

	line(string.format("%d rolls (seed %d)   expected     no pity               with pity (in a row)", n, seed or 1))
	local maxZ = 0
	for tier, rarity in ipairs(list) do
		local expected = rarity.ShopOdds
		local observed = raw[tier] / n
		local se = math.sqrt(expected * (1 - expected) / n) -- binomial standard error
		local z = if se > 0 then (observed - expected) / se else 0
		maxZ = math.max(maxZ, math.abs(z))
		line(string.format("  %-9s  %8.3f%%   %8.3f%% (%+.1f sd)   %8.3f%%", rarity.Name, expected * 100, observed * 100, z, seq[tier] / n * 100))
	end
	line(string.format("Largest gap without pity: %.2f standard errors (|z| < 3 expected).", maxZ))
	line(string.format("In a row: Epic pity used %d times, Legendary pity %d times, %d at a wrong count; longest run without Epic+ %d, without Legendary+ %d.",
		epicTriggers, legendaryTriggers, wrongTriggers, longestNoEpic, longestNoLegendary))

	-- 3. exact thresholds: pity applies at 30 / 100, never one purchase earlier
	local function lowest(c: { [string]: number }, tries: number): number
		local low = math.huge
		for _ = 1, tries do
			low = math.min(low, (ShopService.roll(rng, c)))
		end
		return low
	end
	line(string.format("Lowest tier in 20000 rolls: Epic counter 29 -> %d, 30 -> %d; Legendary counter 99 -> %d, 100 -> %d.",
		lowest({ PityCounter = 29, PityLegendary = 0 }, 20000), lowest({ PityCounter = 30, PityLegendary = 0 }, 20000),
		lowest({ PityCounter = 0, PityLegendary = 99 }, 20000), lowest({ PityCounter = 0, PityLegendary = 100 }, 20000)))
	local _, reset = ShopService.roll(rng, { PityCounter = 30, PityLegendary = 100 })
	line(string.format("After the Legendary pity both counters reset: PityCounter %d, PityLegendary %d.", reset.PityCounter, reset.PityLegendary))
	return table.concat(lines, "\n")
end
