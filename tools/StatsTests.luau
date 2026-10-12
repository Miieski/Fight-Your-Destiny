--!strict
-- Util/Stats checks (docs/menu_systems_brief.txt A4, values of the 2026-10-12 rebalance in Config/Attributes): sample
-- profiles with hand-computed expected results,
-- plus the attribute point cost examples and the soft cap. Admin command "runStatsTests" (or the command bar):
--   print(require(game.ServerStorage.DevTools.StatsTests)())
-- Returns passed, total, report. Parts B / C add pet and armor cases (StatsTests.cases).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.GameSystem.Config.Attributes)
local Balance = require(ReplicatedStorage.GameSystem.Config.Balance)
local ZB = Balance.ZoneBoostEnabled -- the zone-boost cases expect the boost only while it is enabled
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
		expected = { MaxHP = 300, GoldMult = 1.6, RollCooldown = 1.32, Defense = 60, DamageReduction = 60 / 160, Block = 0.85, MoveSpeed = 0.24, Level = 70 },
	},
	{
		name = "3 Rebirths 4 (RP 2): hard caps on Block, Move speed and Attack speed",
		data = { Attributes = attrs({ Endurance = 40, Arcane = 40, Dexterity = 40 }), Rebirths = 4 },
		context = { now = NOW },
		expected = { RebirthPower = 2, Block = 0.85, MoveSpeed = 0.40, AttackSpeed = 0.15, CritChance = 0.35, CritDamage = 5.6, LootMult = 1.60, GoldMult = 1 + (0.5 + (0.5 + 0.5 / 11) + (0.5 + 1 / 11) + (0.5 + 1.5 / 11)), Defense = 120, DamageReduction = 120 / 220 },
	},
	{
		name = "4 Legendary Volcano hammer, Strength 30, Damage Boost 3",
		data = { Attributes = attrs({ Strength = 30 }), Rebirths = 0, RebirthUpgrades = { DamageBoost = 3 }, Weapons = { w1 = { id = "volcano_heavy", rarity = 5 } }, EquippedWeapon = "w1" },
		context = { now = NOW, zoneId = "Volcano" },
		expected = { AttributeDamageMult = 3.4, WeaponDamage = 1e6 * 2.5 * 5.5 * (if ZB then 1.4 else 1) * 3.4 * 1.3 },
		alsoOutside = 1e6 * 2.5 * 5.5 * 3.4 * 1.3,
	},
	{
		name = "5 Mind/Int 40, Faith 20, Gold Boost 5, Health Boost 2, Gold x2 active, Rebirths 1",
		data = { Attributes = attrs({ Mind = 40, Intelligence = 40, Faith = 20 }), Rebirths = 1, RebirthUpgrades = { GoldBoost = 5, HealthBoost = 2 }, Boosts = { GoldX2 = NOW + 600 } },
		context = { now = NOW },
		expected = { GoldMult = (1 + 2.25 + 0.5 + 1.0) * 1.5, RollCooldown = 0.825, ElementProcBonus = 0.16, MagicRadius = 0.25, PetEffectiveness = 1.75, HealingBonus = 0.75, MaxHP = 120 },
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
		name = "7 Faith 40 (soft cap), Rebirths 2: pets x2.35, speed hits the 40% cap",
		data = {
			Attributes = attrs({ Faith = 40 }), Rebirths = 2,
			Pets = { a = { id = "jungle_pet2", rarity = 8 }, b = { id = "desert_pet5", rarity = 8 }, c = { id = "void_pet4", rarity = 6 } },
			EquippedPets = { "a", "b", "c" },
		},
		context = { now = NOW },
		expected = {
			PetEffectiveness = 2.35, MoveSpeed = 0.40, DamageBonus = (0.45 + 0.23) * 2.35, BossDamage = 0.0575 * 2.35,
			LootMult = 1 + 0.1125 * 2.35, CritDamage = 2 * (1 + 0.1125 * 2.35),
			GoldMult = (1 + 0.45 * 2.35) * (1 + 0.5 + 0.5 + 0.5 / 11),
		},
	},
	{
		name = "8 premium Diamond Golem (Divine, Defense + HP, Boss Slayer), Endurance 10",
		data = { Attributes = attrs({ Endurance = 10 }), Rebirths = 0, Pets = { g = { id = "premium_golem", rarity = 7, premium = true } }, EquippedPets = { "g" } },
		context = { now = NOW },
		expected = { Defense = 26.4, DamageReduction = 26.4 / 126.4, MaxHP = 132, BossDamage = 0.08 },
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
		expected = if ZB
			then { ArmorHP = 550 * 1.44, ArmorDefense = 45 * 1.44, SetCount = 3, MaxHP = (100 + 792) * 1.1, Defense = 64.8, DamageReduction = 64.8 / 164.8 }
			else { ArmorHP = 550, ArmorDefense = 45, SetCount = 3, MaxHP = 650 * 1.1, Defense = 45, DamageReduction = 45 / 145 },
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
		expected = if ZB
			then { ArmorHP = 1575 * 1.25 + 25, ArmorDefense = 12 * 1.25 + 3, SetCount = 1, MaxHP = (100 + 1575 * 1.25 + 25) * 2.0 }
			else { ArmorHP = 1575 + 25, ArmorDefense = 15, SetCount = 1, MaxHP = (100 + 1575 + 25) * 2.0 },
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
		-- point price examples (round(400 x 1.1 ^ L), no zone factor since 2026-10-12) and the soft cap
		for _, example in ipairs({ { 0, 400 }, { 10, 1037 }, { 100, 5512245 }, { 319, 6402160488815438 } }) do
			check(`PointCost(L {example[1]})`, Attributes.pointCost(example[1]), example[2])
		end
		check("CostOf(L 0, 3 points)", Attributes.costOf(0, 3), 1324)
		check("Peff(40)", Attributes.effective(40), 30)
		check("Peff(25)", Attributes.effective(25), 22.5)
		check("Respec cost Z5", Attributes.respecCost(5), 15)
		table.insert(lines, 1, `Stats tests: {passed}/{total} passed`)
		return passed, total, table.concat(lines, "\n")
	end,
}) :: any
