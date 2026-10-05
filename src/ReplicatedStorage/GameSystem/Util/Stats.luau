--!strict
-- Derived numbers shared by the server and the UI (DESIGN.md section 10, docs/menu_systems_brief.txt A4).
-- Stats.compute(data, context) turns a profile (attributes, rebirths, upgrades, equipped weapon / armor / pets,
-- boosts) into every derived stat; the server and the client run the same code, so the UI always shows what the
-- server uses. Weapon damage per hit = ZoneBase x CategoryMult x RarityMult (x (1 + Zone Boost) in the home zone).
local Config = script.Parent.Parent.Config
local Attributes = require(Config.Attributes)
local Boosts = require(Config.Boosts)
local Rarities = require(Config.Rarities)
local RebirthShop = require(Config.RebirthShop)
local Weapons = require(Config.Weapons)

local Stats = {}

export type Data = { [string]: any }
export type Context = { zoneId: string?, now: number? }

-- Damage per hit of a Common Sword of that zone: 10, 100, ... 1T.
function Stats.zoneBase(zone: number): number
	return Weapons.ZONE_BASE_DAMAGE * 10 ^ (zone - 1)
end

-- Damage per hit of a weapon at a rarity tier; inHomeZone applies the rarity's Zone Boost.
function Stats.weaponDamage(weaponId: string, tier: number?, inHomeZone: boolean?): number
	local weapon = Weapons.ById[weaponId]
	if not weapon then
		return 0
	end
	local rarity = Rarities.get(tier)
	local damage = Stats.zoneBase(weapon.Zone) * Weapons.CategoryById[weapon.Category].DamageMult * rarity.DamageMult
	if inHomeZone then
		damage *= 1 + rarity.ZoneBoost
	end
	return damage
end

-- Damage per second outside the home zone; used to compare two copies ("Better than equipped!").
function Stats.weaponDps(weaponId: string, tier: number?): number
	local weapon = Weapons.ById[weaponId]
	if not weapon then
		return 0
	end
	return Stats.weaponDamage(weaponId, tier) * Weapons.CategoryById[weapon.Category].HitsPerSecond
end

-- Highest zone index the profile has unlocked (1..12): sets attribute point and respec prices.
function Stats.highestZone(data: Data): number
	local best = 1
	local Zones = require(Config.Zones) :: any
	for zoneId, open in pairs(data.Zones or {}) do
		local zone = Zones.ById[zoneId]
		if open and zone and zone.Index > best then
			best = zone.Index
		end
	end
	return best
end

-- Pet totals before Faith, as fractions (0.16 = +16%): main stats and unique bonuses of the EQUIPPED pets.
-- Filled by Config/Pets (Part B); zero when that config does not exist.
function Stats.petTotals(data: Data): { [string]: number }
	local totals = { Gold = 0, HP = 0, Attack = 0, Speed = 0, Defense = 0, TrophyValue = 0, CritDamage = 0, Regeneration = 0, BossSlayer = 0, LootLuck = 0, DiamondLuck = 0 }
	local module = Config:FindFirstChild("Pets")
	if not module then
		return totals
	end
	local Pets = require(module) :: any
	local owned = data.Pets or {}
	for _, uid in ipairs(data.EquippedPets or {}) do
		local pet = owned[uid]
		local species = pet and Pets.ById[pet.id]
		if species then
			local main = Pets.mainValue(pet.rarity)
			for _, stat in ipairs(species.Stats) do
				totals[stat] += main
			end
			totals[species.Bonus] += Pets.bonusValue(pet.rarity)
		end
	end
	return totals
end

-- Armor totals (Part C): HP (Zone Boost included in the piece's home zone), Defense, set bonus. Zero without
-- Config/Armor.
function Stats.armorTotals(data: Data, zoneId: string?): { HP: number, Defense: number, SetZone: string?, SetCount: number, Boosted: { [string]: boolean } }
	local totals = { HP = 0, Defense = 0, SetZone = nil :: string?, SetCount = 0, Boosted = {} :: { [string]: boolean } }
	local module = Config:FindFirstChild("Armor")
	if not module then
		return totals
	end
	local Armor = require(module) :: any
	return Armor.totals(data, zoneId)
end

-- Every derived stat of a profile. context.zoneId = where the player stands (Zone Boosts), context.now = os.time().
function Stats.compute(data: Data, context: Context?): { [string]: any }
	local ctx = context or {}
	local zoneId = ctx.zoneId
	local now = ctx.now or os.time()
	local per = Attributes.PerPoint
	local base = Attributes.Base
	local caps = Attributes.Caps
	local points = data.Attributes or {}
	local rp = Attributes.rebirthPower(data.Rebirths or 0)
	local function peff(id: string): number
		return Attributes.effective(math.clamp(math.floor(points[id] or 0), 0, Attributes.MaxPoints))
	end
	local upgrades = data.RebirthUpgrades or {}
	local pets = Stats.petTotals(data)
	local armor = Stats.armorTotals(data, zoneId)
	-- Faith makes every pet value stronger
	local petEffect = 1 + per.FaithPets * rp * peff("Faith")
	local function pet(stat: string): number
		return (pets[stat] or 0) * petEffect
	end

	local out = {}
	out.RebirthPower = rp
	out.Level = Attributes.level(points)
	out.PetEffectiveness = petEffect
	out.HealingBonus = per.FaithHealing * rp * peff("Faith") -- lifesteal and healing effects

	-- health
	local setBonus = if armor.SetCount >= 3 then 0.10 else 0
	out.MaxHP = (base.HP + armor.HP) * (1 + per.VigorHP * rp * peff("Vigor") + pet("HP") + RebirthShop.bonus(upgrades, "HealthBoost") + setBonus)
	out.RegenFraction = per.VigorRegen * rp * peff("Vigor") + pet("Regeneration") * 0.0005 * 100 -- of Max HP / second
	out.RegenPerSecond = out.MaxHP * out.RegenFraction
	out.RegenDelay = base.RegenDelay

	-- defense
	out.Defense = (armor.Defense + per.EnduranceDefense * rp * peff("Endurance")) * (1 + pet("Defense"))
	out.DamageReduction = out.Defense / (out.Defense + Attributes.DefenseConstant)
	out.Block = math.min(caps.Block, base.Block + per.EnduranceBlock * rp * peff("Endurance"))
	out.MoveSpeed = math.min(caps.MoveSpeed, per.EnduranceSpeed * rp * peff("Endurance") + pet("Speed"))
	out.WalkSpeed = base.WalkSpeed * (1 + out.MoveSpeed)
	out.RollCooldown = math.max(caps.RollCooldownFloor, base.RollCooldown * (1 - per.MindRoll * rp * peff("Mind")))
	out.AttackSpeed = math.min(caps.AttackSpeed, per.DexterityAttackSpeed * rp * peff("Dexterity"))

	-- offense
	out.CritChance = math.min(caps.CritChance, base.CritChance + per.ArcaneCrit * rp * peff("Arcane"))
	out.CritDamage = base.CritDamage * (1 + per.ArcaneCritDamage * rp * peff("Arcane") + pet("CritDamage"))
	out.ElementProcBonus = math.min(caps.ElementProc, per.IntelligenceProc * rp * peff("Intelligence"))
	out.MagicRadius = math.min(caps.MagicRadius, per.IntelligenceRadius * rp * peff("Intelligence"))
	out.BossDamage = pet("BossSlayer")
	out.DamageBonus = pet("Attack") + RebirthShop.bonus(upgrades, "DamageBoost") -- (1 + this) on every hit

	-- economy
	local boostGold = 0
	for _, boost in ipairs(Boosts.List) do
		if Boosts.isActive(data.Boosts, boost.Id, now) then
			boostGold += boost.GoldBonus or 0
		end
	end
	out.GoldMult = (1 + per.MindGold * rp * peff("Mind") + pet("Gold") + RebirthShop.bonus(upgrades, "GoldBoost") + boostGold)
		* (1 + RebirthShop.rebirthGoldBonus(data.Rebirths or 0))
	out.LootMult = (1 + per.ArcaneLoot * rp * peff("Arcane")) * (1 + pet("LootLuck")) * (1 + RebirthShop.bonus(upgrades, "LootLuck"))
	out.TrophyValue = pet("TrophyValue")
	out.DiamondLuck = pet("DiamondLuck") + RebirthShop.bonus(upgrades, "DiamondLuck")
	out.EggLuck = RebirthShop.bonus(upgrades, "EggLuck")

	-- armor info for the Equipment screen
	out.ArmorHP = armor.HP
	out.ArmorDefense = armor.Defense
	out.SetZone = armor.SetZone
	out.SetCount = armor.SetCount
	out.ArmorBoosted = armor.Boosted

	-- equipped weapon (A3)
	local item = (data.Weapons or {})[data.EquippedWeapon or ""]
	local weapon = item and Weapons.ById[item.id]
	out.AttributeDamageMult = 1
	out.WeaponDamage = 0
	if weapon then
		local scaling = Attributes.Scaling[weapon.Category] or {}
		local sum = 0
		for attribute, weight in pairs(scaling) do
			sum += weight * peff(attribute)
		end
		out.AttributeDamageMult = 1 + per.DamageScaling * rp * sum
		out.WeaponDamage = Stats.weaponDamage(weapon.Id, item.rarity, weapon.ZoneId == zoneId) * out.AttributeDamageMult * (1 + out.DamageBonus)
		out.WeaponId = weapon.Id
		out.WeaponRarity = item.rarity
	end
	return out
end

-- Scaling grades of a weapon category, e.g. { { "Strength", "B" }, { "Dexterity", "B" } } (UI order).
function Stats.grades(category: string): { { string } }
	local list = {}
	local scaling = Attributes.Scaling[category] or {}
	for _, id in ipairs(Attributes.Ids) do
		if scaling[id] then
			table.insert(list, { id, Attributes.grade(scaling[id]) })
		end
	end
	return list
end

return Stats
