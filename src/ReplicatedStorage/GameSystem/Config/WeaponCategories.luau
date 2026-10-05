--!strict
-- The 8 weapon categories (docs/weapon_system_document.txt section 2). The multipliers keep the DPS of
-- every category close; they differ in reach, area, speed and safety. Shape / Special are shop texts.
-- Muzzle = the Tool gets a MuzzleAttachment (projectiles start there).
export type Category = {
	Id: string,
	Name: string,
	DamageMult: number,
	HitsPerSecond: number,
	Range: number, -- studs
	Melee: boolean,
	Muzzle: boolean,
	Shape: string,
	Special: string,
}

local WeaponCategories = {}

WeaponCategories.List = {
	{ Id = "Sword", Name = "Sword", DamageMult = 1.0, HitsPerSecond = 1.0, Range = 6, Melee = true, Muzzle = false, Shape = "Sweeping arc", Special = "Hits up to 3 enemies" },
	{ Id = "Spear", Name = "Spear", DamageMult = 1.2, HitsPerSecond = 0.9, Range = 10, Melee = true, Muzzle = false, Shape = "Long thrust", Special = "Pierces up to 4 enemies in a line" },
	{ Id = "Heavy", Name = "Heavy", DamageMult = 2.5, HitsPerSecond = 0.4, Range = 6, Melee = true, Muzzle = false, Shape = "Slam", Special = "Small area slam and a short stagger" },
	{ Id = "Dagger", Name = "Dagger", DamageMult = 0.4, HitsPerSecond = 2.5, Range = 4, Melee = true, Muzzle = false, Shape = "Fast stabs", Special = "+20% crit chance (crit = x2 damage)" },
	{ Id = "Gauntlet", Name = "Gauntlet", DamageMult = 0.6, HitsPerSecond = 1.8, Range = 5, Melee = true, Muzzle = false, Shape = "3-hit combo", Special = "The 3rd hit does x2 damage" },
	{ Id = "Ranged", Name = "Ranged", DamageMult = 0.8, HitsPerSecond = 1.2, Range = 60, Melee = false, Muzzle = true, Shape = "Projectile", Special = "Safe, single target" },
	{ Id = "Magic", Name = "Magic", DamageMult = 0.8, HitsPerSecond = 1.0, Range = 35, Melee = false, Muzzle = true, Shape = "Area burst", Special = "Area damage in a small radius around the target" },
	{ Id = "Whip", Name = "Whip & Chain", DamageMult = 0.9, HitsPerSecond = 1.1, Range = 12, Melee = true, Muzzle = false, Shape = "Wide cone", Special = "Hits everything in a wide frontal cone" },
} :: { Category }

WeaponCategories.ById = {} :: { [string]: Category }
for _, category in ipairs(WeaponCategories.List) do
	WeaponCategories.ById[category.Id] = category
end

return WeaponCategories
