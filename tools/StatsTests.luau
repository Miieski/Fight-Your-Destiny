--!strict
-- Util/Stats checks (docs/menu_systems_brief.txt A4): 5 sample profiles with hand-computed expected results,
-- plus the attribute point cost examples and the soft cap. Admin command "runStatsTests" (or the command bar):
--   print(require(game.ServerStorage.DevTools.StatsTests)())
-- Returns passed, total, report. Parts B / C add pet and armor cases (StatsTests.cases).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.GameSystem.Config.Attributes)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)

local StatsTests = {}

local NOW = 1_800_000_000

local function attrs(values: { [string]: number }): { [string]: number }
	local all = Attributes.empty()
	for k, v in pairs(values) do
		all[k] = v
	end
	return all
end

-- { name, data, context, expected = { [stat] = value } }
StatsTests.cases = {
	{
		name = "1 fresh profile",
		data = { Attributes = attrs({}), Rebirths = 0 },
		context = { now = NOW },
		expected = { MaxHP = 100, Defense = 0, Block = 0.60, RollCooldown = 1.5, CritChance = 0.05, CritDamage = 2.0, GoldMult = 1.0, MoveSpeed = 0, LootMult = 1 },
	},
	{
		name = "2 Vigor 20, Mind 10, Endurance 40 (soft cap)",
		data = { Attributes = attrs({ Vigor = 20, Mind = 10, Endurance = 40 }), Rebirths = 0 },
		context = { now = NOW },
		expected = { MaxHP = 180, GoldMult = 1.25, RollCooldown = 1.395, Defense = 30, DamageReduction = 30 / 130, Block = 0.75, MoveSpeed = 0.12, Level = 70 },
	},
	{
		name = "3 Rebirths 4 (RP 2): hard caps on Block and Attack speed",
		data = { Attributes = attrs({ Endurance = 40, Arcane = 40, Dexterity = 40 }), Rebirths = 4 },
		context = { now = NOW },
		expected = { RebirthPower = 2, Block = 0.85, MoveSpeed = 0.24, AttackSpeed = 0.15, CritChance = 0.20, CritDamage = 3.8, LootMult = 1.30, GoldMult = 1 + (0.5 + (0.5 + 0.5 / 11) + (0.5 + 1 / 11) + (0.5 + 1.5 / 11)), Defense = 60, DamageReduction = 0.375 },
	},
	{
		name = "4 Legendary Volcano hammer, Strength 30, Damage Boost 3",
		data = { Attributes = attrs({ Strength = 30 }), Rebirths = 0, RebirthUpgrades = { DamageBoost = 3 }, Weapons = { w1 = { id = "volcano_heavy", rarity = 5 } }, EquippedWeapon = "w1" },
		context = { now = NOW, zoneId = "Volcano" },
		expected = { AttributeDamageMult = 1.9, WeaponDamage = 1e6 * 2.5 * 5.5 * 1.4 * 1.9 * 1.3 },
		alsoOutside = 1e6 * 2.5 * 5.5 * 1.9 * 1.3,
	},
	{
		name = "5 Mind/Int 40, Faith 20, Gold Boost 5, Health Boost 2, Gold x2 active, Rebirths 1",
		data = { Attributes = attrs({ Mind = 40, Intelligence = 40, Faith = 20 }), Rebirths = 1, RebirthUpgrades = { GoldBoost = 5, HealthBoost = 2 }, Boosts = { GoldX2 = NOW + 600 } },
		context = { now = NOW },
		expected = { GoldMult = (1 + 0.9375 + 0.5 + 1.0) * 1.5, RollCooldown = 1.10625, ElementProcBonus = 0.15, MagicRadius = 0.1875, PetEffectiveness = 1.30, HealingBonus = 0.375, MaxHP = 120 },
	},
	-- Part B: pets (main value per rarity 2/4/7/11/16/23/32/45 %, bonus = 25% of it, Faith multiplies all)
	{
		name = "6 pets: Secret Fortune, Legendary Hunter, Epic Guardian (+ an unequipped Lucky)",
		data = {
			Attributes = attrs({}), Rebirths = 0,
			Pets = { a = { id = "plains_pet1", rarity = 8 }, b = { id = "plains_pet2", rarity = 5 }, c = { id = "plains_pet3", rarity = 4 }, d = { id = "plains_pet6", rarity = 8 } },
			EquippedPets = { "a", "b", "c" },
		},
		context = { now = NOW },
		expected = { MaxHP = 156, GoldMult = 1.45, MoveSpeed = 0.16, DamageBonus = 0.16, CritDamage = 2.08, TrophyValue = 0.1125, RegenFraction = 0.001375, PetEffectiveness = 1, Defense = 0 },
	},
	{
		name = "7 Faith 40 (soft cap), Rebirths 2: pets x1.54, speed hits the 40% cap",
		data = {
			Attributes = attrs({ Faith = 40 }), Rebirths = 2,
			Pets = { a = { id = "jungle_pet2", rarity = 8 }, b = { id = "desert_pet5", rarity = 8 }, c = { id = "void_pet4", rarity = 6 } },
			EquippedPets = { "a", "b", "c" },
		},
		context = { now = NOW },
		expected = {
			PetEffectiveness = 1.54, MoveSpeed = 0.40, DamageBonus = (0.45 + 0.23) * 1.54, BossDamage = 0.0575 * 1.54,
			LootMult = 1 + 0.1125 * 1.54, CritDamage = 2 * (1 + 0.1125 * 1.54),
			GoldMult = (1 + 0.45 * 1.54) * (1 + 0.5 + 0.5 + 0.5 / 11),
		},
	},
	{
		name = "8 premium Diamond Golem (Divine, Defense + HP, Boss Slayer), Endurance 10",
		data = { Attributes = attrs({ Endurance = 10 }), Rebirths = 0, Pets = { g = { id = "premium_golem", rarity = 7, premium = true } }, EquippedPets = { "g" } },
		context = { now = NOW },
		expected = { Defense = 13.2, DamageReduction = 13.2 / 113.2, MaxHP = 132, BossDamage = 0.08 },
	},
	-- Part C: armor (HP = 100 x 10^(Z-1) x share x rarityMult, Defense 3 x tier, Zone Boost in its zone, set +10%)
	{
		name = "9 Legendary Plains set (3/3) standing in Plains: Zone Boost 40% x 1.1",
		data = {
			Attributes = attrs({}), Rebirths = 0,
			Armor = { h = { id = "plains_helmet", rarity = 5 }, c = { id = "plains_chest", rarity = 5 }, l = { id = "plains_legs", rarity = 5 } },
			EquippedArmor = { Helmet = "h", Chest = "c", Legs = "l" },
		},
		context = { now = NOW, zoneId = "Plains" },
		expected = { ArmorHP = 550 * 1.44, ArmorDefense = 45 * 1.44, SetCount = 3, MaxHP = (100 + 792) * 1.1, Defense = 64.8, DamageReduction = 64.8 / 164.8 },
		alsoOutsideStats = { ArmorHP = 550, ArmorDefense = 45, MaxHP = 650 * 1.1 },
	},
	{
		name = "10 Epic Desert chest + Common Plains helmet in Desert (no set)",
		data = {
			Attributes = attrs({ Vigor = 10 }), Rebirths = 0,
			Armor = { c = { id = "desert_chest", rarity = 4 }, h = { id = "plains_helmet", rarity = 1 }, x = { id = "void_legs", rarity = 8 } },
			EquippedArmor = { Chest = "c", Helmet = "h" },
		},
		context = { now = NOW, zoneId = "Desert" },
		expected = { ArmorHP = 1575 * 1.25 + 25, ArmorDefense = 12 * 1.25 + 3, SetCount = 1, MaxHP = (100 + 1575 * 1.25 + 25) * 1.4 },
	},
}

local function near(a: number, b: number): boolean
	return math.abs(a - b) <= 1e-6 * math.max(1, math.abs(b))
end

return setmetatable(StatsTests, {
	__call = function(): (number, number, string)
		local passed, total, lines = 0, 0, {}
		local function check(label: string, got: number, want: number)
			total += 1
			if near(got, want) then
				passed += 1
			else
				table.insert(lines, string.format("FAIL %s: got %.6f, expected %.6f", label, got, want))
			end
		end
		for _, case in ipairs(StatsTests.cases) do
			local out = Stats.compute(case.data, case.context)
			for stat, want in pairs(case.expected) do
				check(`{case.name} - {stat}`, out[stat] or 0, want)
			end
			if case.alsoOutsideStats then
				local outside = Stats.compute(case.data, { now = NOW, zoneId = "Hub" })
				for stat, want in pairs(case.alsoOutsideStats) do
					check(`{case.name} - {stat} outside its zone`, outside[stat] or 0, want)
				end
			end
			if case.alsoOutside then
				local outside = Stats.compute(case.data, { now = NOW, zoneId = "Hub" })
				check(`{case.name} - WeaponDamage outside its zone`, outside.WeaponDamage, case.alsoOutside)
			end
		end
		-- point cost examples (brief A1) and the soft cap. The brief prints 18,870 for L 319: the formula gives
		-- 18,870.9, so round() -> 18,871 (the formula wins; logged in docs/NIGHT_LOG.md).
		for _, example in ipairs({ { 0, 1, 100 }, { 10, 1, 283 }, { 100, 1, 3648 }, { 319, 1, 18871 }, { 0, 3, 10000 } }) do
			check(`PointCost(L {example[1]}, Z {example[2]})`, Attributes.pointCost(example[1], example[2]), example[3])
		end
		check("Peff(40)", Attributes.effective(40), 30)
		check("Peff(25)", Attributes.effective(25), 22.5)
		check("Respec cost Z5", Attributes.respecCost(5), 15)
		table.insert(lines, 1, `Stats tests: {passed}/{total} passed`)
		return passed, total, table.concat(lines, "\n")
	end,
}) :: any
