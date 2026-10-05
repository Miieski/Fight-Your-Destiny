--!strict
-- Derived numbers shared by the server and the UI (DESIGN.md section 10).
-- Weapon damage per hit = ZoneBase x CategoryMult x RarityMult (docs/weapon_system_document.txt section 1),
-- x (1 + Zone Boost) in the weapon's home zone. Other bonuses (rebirth, upgrades) come later.
local Config = script.Parent.Parent.Config
local Rarities = require(Config.Rarities)
local Weapons = require(Config.Weapons)

local Stats = {}

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

return Stats
