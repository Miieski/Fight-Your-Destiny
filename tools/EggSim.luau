--!strict
-- Egg hatch check (docs/menu_systems_brief.txt B1, acceptance): runs the server's real functions
-- (ShopService.rollTier for premium egg rarities, PetService.hatchRoll for species and Egg Luck) many times.
--   print(require(game.ServerStorage.DevTools.EggSim)(100000))      -- or admin simulateEggs(n)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Pets = require(ReplicatedStorage.GameSystem.Config.Pets)
local RebirthShop = require(ReplicatedStorage.GameSystem.Config.RebirthShop)
local WeaponRarities = require(ReplicatedStorage.GameSystem.Config.WeaponRarities)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local PetService = require(ServerScriptService.GameSystem.Services.PetService)
local ShopService = require(ServerScriptService.GameSystem.Services.ShopService)

local function zScore(observed: number, expected: number, n: number): number
	local se = math.sqrt(expected * (1 - expected) / n)
	return if se > 0 then (observed - expected) / se else 0
end

return function(count: number?, seed: number?): (string, number)
	local n = count or 100000
	local rng = Random.new(seed or 7)
	local list = WeaponRarities.List
	local lines = {}
	local maxZ = 0
	local function line(text: string)
		table.insert(lines, text)
	end

	-- 1. premium eggs without Egg Luck: shop odds, uniform species over the zone's 6
	for _, luckLevel in ipairs({ 0, RebirthShop.ById.EggLuck.Max }) do
		local luck = RebirthShop.ById.EggLuck.PerLevel * luckLevel
		local tiers = table.create(#list, 0)
		local slots = table.create(6, 0)
		local zone = 1 + (luckLevel % #Zones.List)
		for _ = 1, n do
			local eggTier = ShopService.rollTier(rng, 1)
			local petId, tier = PetService.hatchRoll(rng, zone, eggTier, luck)
			tiers[tier] += 1
			slots[Pets.ById[petId].Slot] += 1
		end
		line(string.format("Premium %s eggs, Egg Luck level %d (%d%%), %d hatches:", Zones.List[zone].Name, luckLevel, luck * 100, n))
		for tier, rarity in ipairs(list) do
			-- expected: the shop odds, then a share `luck` of each tier moves one tier up (Secret stays)
			local base = rarity.ShopOdds
			local fromBelow = if tier > 1 then list[tier - 1].ShopOdds * luck else 0
			local stays = if tier < #list then base * (1 - luck) else base
			local expected = stays + fromBelow
			local observed = tiers[tier] / n
			local z = zScore(observed, expected, n)
			maxZ = math.max(maxZ, math.abs(z))
			line(string.format("  %-9s expected %8.3f%%  observed %8.3f%%  (%+.1f sd)", rarity.Name, expected * 100, observed * 100, z))
		end
		local parts = {}
		for slot = 1, 6 do
			local z = zScore(slots[slot] / n, 1 / 6, n)
			maxZ = math.max(maxZ, math.abs(z))
			table.insert(parts, string.format("%s %.2f%%", Pets.ByZone[Zones.List[zone].Id][slot].Name, slots[slot] / n * 100))
		end
		line("  species (16.67% each): " .. table.concat(parts, ", "))
	end

	-- 2. loot eggs keep their rarity; Egg Luck moves exactly `luck` of them one tier up, never above Secret
	for _, luckLevel in ipairs({ 0, 1, 3, 6 }) do
		local luck = RebirthShop.ById.EggLuck.PerLevel * luckLevel
		local shifted, wrong, secretUp = 0, 0, 0
		for i = 1, n do
			local eggTier = 1 + (i % 7) -- Common .. Divine
			local _, tier, lucky = PetService.hatchRoll(rng, 1 + (i % 12), eggTier, luck)
			if lucky then
				shifted += 1
			end
			if tier ~= eggTier + (if lucky then 1 else 0) then
				wrong += 1
			end
			local _, secretTier = PetService.hatchRoll(rng, 12, 8, luck)
			if secretTier ~= 8 then
				secretUp += 1
			end
		end
		local z = zScore(shifted / n, luck, n)
		maxZ = math.max(maxZ, math.abs(z))
		line(string.format("Loot eggs, Egg Luck level %d: %.2f%% one tier rarer (expected %.0f%%, %+.1f sd), %d wrong tiers, %d Secret eggs above Secret.",
			luckLevel, shifted / n * 100, luck * 100, z, wrong, secretUp))
	end
	line(string.format("Largest gap: %.2f standard errors (|z| < 4 expected over all lines).", maxZ))
	return table.concat(lines, "\n"), maxZ
end
