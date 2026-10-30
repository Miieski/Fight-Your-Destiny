--!strict
-- The 6 weapon categories (docs/weapon_system_document.txt section 2): they differ in reach, area, speed and safety.
-- Shape / Special are shop texts. HitsPerSecond and AvgDamage come from the combo in Config/WeaponMoves; DamageMult is
-- derived so that DamageMult x AvgDamage x HitsPerSecond = the category's Dps: tuning a timing never moves the DPS.
-- Muzzle = the Tool gets a MuzzleAttachment (projectiles start there).
export type Category = {
	Id: string,
	Name: string,
	DamageMult: number,
	HitsPerSecond: number,
	AvgDamage: number,
	Range: number, -- studs
	Melee: boolean,
	Muzzle: boolean,
	Shape: string,
	Special: string,
}

local WeaponMoves = require(script.Parent.WeaponMoves)

local WeaponCategories = {}

WeaponCategories.List = {
	{ Id = "Sword", Name = "Sword", Range = 6, Melee = true, Muzzle = false, Shape = "Sweeping arc", Special = "Hits up to 3 enemies, a spinning finisher" },
	{ Id = "Spear", Name = "Spear", Range = 10, Melee = true, Muzzle = false, Shape = "Long thrusts and sweeps", Special = "Hits up to 4 enemies, strong against guards" },
	{ Id = "Heavy", Name = "Heavy", Range = 6, Melee = true, Muzzle = false, Shape = "Wide sweeps and slams", Special = "Hold for a slam: the longer, the bigger the shockwave" },
	{ Id = "Dagger", Name = "Dagger", Range = 4, Melee = true, Muzzle = false, Shape = "A pair, fast cuts", Special = "+20% crit chance, a flurry finisher" },
	{ Id = "Ranged", Name = "Ranged", Range = 60, Melee = false, Muzzle = true, Shape = "Aimed shots", Special = "Hold for a charged shot that pierces 3 enemies" },
	{ Id = "Magic", Name = "Magic", Range = 35, Melee = false, Muzzle = true, Shape = "Fireballs", Special = "Area damage and burn, uses mana. Block heals" },
} :: { any }

WeaponCategories.ById = {} :: { [string]: Category }
for _, category in ipairs(WeaponCategories.List) do
	local hits, damage = WeaponMoves.rate(category.Id)
	category.HitsPerSecond = math.round(hits * 100) / 100
	category.AvgDamage = damage
	category.DamageMult = WeaponMoves.Moves[category.Id].Dps / (hits * damage)
	WeaponCategories.ById[category.Id] = category
end

return WeaponCategories
