--!strict
-- Weapon rarities (docs/weapon_system_document.txt sections 3 and 5): the 8 tiers of Config/Rarities
-- (name, color, damage multiplier, Zone Boost, element proc, shop odds) plus the shop's pity rules and the
-- server-wide announcements. The odds add up to 1.
local Rarities = require(script.Parent.Rarities)

export type Pity = { Key: string, MinTier: number, After: number, Label: string }

local WeaponRarities = {}

WeaponRarities.List = Rarities.List
WeaponRarities.get = Rarities.get

-- Pity: after `After` purchases in a row without a weapon of tier >= MinTier, the NEXT purchase is
-- guaranteed to be MinTier or better (rolled with the normal odds among those tiers). A counter resets
-- whenever a weapon of its tier or better comes out, by luck or by pity. Key = profile field.
WeaponRarities.Pity = {
	{ Key = "PityCounter", MinTier = 4, After = 30, Label = "Epic or better" },
	{ Key = "PityLegendary", MinTier = 5, After = 100, Label = "Legendary or better" },
} :: { Pity }

WeaponRarities.ANNOUNCE_FROM = 6 -- Mythic or better: a toast for everyone in the server
WeaponRarities.ANNOUNCE_COOLDOWN = 3 -- seconds between two announcements (server-wide)

-- Shop odds of a tier as a fraction (0.5 = 50%).
function WeaponRarities.odds(tier: number): number
	return Rarities.get(tier).ShopOdds
end

-- "50%", "2.2%", "0.09%": percent text with the precision the odds need.
function WeaponRarities.percentText(fraction: number): string
	local percent = fraction * 100
	if percent >= 10 then
		return string.format("%d%%", math.round(percent))
	elseif percent >= 1 then
		return (string.gsub(string.format("%.1f%%", percent), "%.0%%", "%%"))
	elseif percent >= 0.1 then
		return string.format("%.1f%%", percent)
	end
	return string.format("%.2f%%", percent)
end

return WeaponRarities
