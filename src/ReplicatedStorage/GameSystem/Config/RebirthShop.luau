--!strict
-- Rebirth Shop upgrades (DESIGN.md section 4): bought with Rebirth Credits, 1 credit per level, kept on Rebirth.
-- PerLevel is the bonus of one level (0.10 = +10%); Util/Stats.compute reads them.
export type Upgrade = { Id: string, Name: string, Icon: string, PerLevel: number, Max: number, Effect: string }

local RebirthShop = {}

RebirthShop.CostPerLevel = 1 -- credits

RebirthShop.List = {
	{ Id = "GoldBoost", Name = "Gold Boost", Icon = "Gold", PerLevel = 0.10, Max = 10, Effect = "+10% Gold per level" },
	{ Id = "DamageBoost", Name = "Damage Boost", Icon = "Attack", PerLevel = 0.10, Max = 10, Effect = "+10% damage per level" },
	{ Id = "LootLuck", Name = "Loot Luck", Icon = "Chest", PerLevel = 0.08, Max = 8, Effect = "+8% loot drop chance per level" },
	{ Id = "EggLuck", Name = "Egg Luck", Icon = "Egg", PerLevel = 0.05, Max = 6, Effect = "+5% chance per level that a hatched pet is one rarity higher" },
	{ Id = "HealthBoost", Name = "Health Boost", Icon = "MaxHP", PerLevel = 0.10, Max = 8, Effect = "+10% Max HP per level" },
	{ Id = "DiamondLuck", Name = "Diamond Luck", Icon = "Diamond", PerLevel = 0.05, Max = 6, Effect = "+5% diamond drop chance from bosses per level" },
} :: { Upgrade }

RebirthShop.ById = {} :: { [string]: Upgrade }
for _, upgrade in ipairs(RebirthShop.List) do
	RebirthShop.ById[upgrade.Id] = upgrade
end

-- Bonus of an upgrade at the profile's level (0 when not bought).
function RebirthShop.bonus(levels: { [string]: number }?, id: string): number
	local upgrade = RebirthShop.ById[id]
	local level = math.clamp(math.floor((levels and levels[id]) or 0), 0, upgrade.Max)
	return upgrade.PerLevel * level
end

-- Gold multiplier from Rebirths (DESIGN.md section 4): bonus(r) = 0.5 + 0.5 x (r - 1) / 11, summed.
function RebirthShop.rebirthGoldBonus(rebirths: number): number
	local total = 0
	for r = 1, math.clamp(math.floor(rebirths or 0), 0, 12) do
		total += 0.5 + 0.5 * (r - 1) / 11
	end
	return total
end

return RebirthShop
