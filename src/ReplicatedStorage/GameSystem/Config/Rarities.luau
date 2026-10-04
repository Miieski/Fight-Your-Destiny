--!strict
-- The 8 rarity tiers (docs/weapon_system_document.txt section 3; colors from DESIGN.md section 1).
local rgb = Color3.fromRGB

export type Rarity = {
	Tier: number,
	Name: string,
	Color: Color3, -- border / text color (animated tiers use Gradient on top of it)
	DamageMult: number,
	ZoneBoost: number, -- bonus in the item's home zone (0.4 = +40%)
	ElementProc: number,
	ShopOdds: number,
	Gradient: ColorSequence?, -- animated tiers only
}

local Rarities = {}

Rarities.GLOW_FROM = 4 -- Epic and above get a glow
Rarities.SPECIAL_SOUND_FROM = 4 -- Epic and above get a reveal sound
Rarities.LEGENDARY_SOUND_FROM = 5
Rarities.GRADIENT_SPIN_SECONDS = 3

Rarities.List = {
	{ Tier = 1, Name = "Common", Color = rgb(196, 206, 218), DamageMult = 1.0, ZoneBoost = 0.05, ElementProc = 0.05, ShopOdds = 0.50 },
	{ Tier = 2, Name = "Uncommon", Color = rgb(91, 220, 110), DamageMult = 1.5, ZoneBoost = 0.10, ElementProc = 0.08, ShopOdds = 0.28 },
	{ Tier = 3, Name = "Rare", Color = rgb(60, 150, 255), DamageMult = 2.2, ZoneBoost = 0.15, ElementProc = 0.11, ShopOdds = 0.13 },
	{ Tier = 4, Name = "Epic", Color = rgb(170, 80, 255), DamageMult = 3.5, ZoneBoost = 0.25, ElementProc = 0.14, ShopOdds = 0.06 },
	{ Tier = 5, Name = "Legendary", Color = rgb(255, 170, 30), DamageMult = 5.5, ZoneBoost = 0.40, ElementProc = 0.17, ShopOdds = 0.022 },
	{ Tier = 6, Name = "Mythic", Color = rgb(255, 60, 110), DamageMult = 9.0, ZoneBoost = 0.60, ElementProc = 0.20, ShopOdds = 0.007 },
	{
		Tier = 7, Name = "Divine", Color = rgb(255, 255, 255), DamageMult = 15.0, ZoneBoost = 0.85, ElementProc = 0.23, ShopOdds = 0.0009,
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 255, 255)),
			ColorSequenceKeypoint.new(0.3, rgb(120, 240, 255)),
			ColorSequenceKeypoint.new(0.6, rgb(255, 150, 220)),
			ColorSequenceKeypoint.new(0.85, rgb(255, 214, 90)),
			ColorSequenceKeypoint.new(1, rgb(255, 255, 255)),
		}),
	},
	{
		Tier = 8, Name = "Secret", Color = rgb(235, 90, 255), DamageMult = 25.0, ZoneBoost = 1.20, ElementProc = 0.26, ShopOdds = 0.0001,
		Gradient = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 60, 60)),
			ColorSequenceKeypoint.new(0.17, rgb(255, 170, 30)),
			ColorSequenceKeypoint.new(0.34, rgb(255, 240, 60)),
			ColorSequenceKeypoint.new(0.5, rgb(70, 230, 110)),
			ColorSequenceKeypoint.new(0.67, rgb(60, 150, 255)),
			ColorSequenceKeypoint.new(0.84, rgb(170, 80, 255)),
			ColorSequenceKeypoint.new(1, rgb(255, 60, 60)),
		}),
	},
} :: { Rarity }

Rarities.SECRET_CORE = rgb(18, 12, 26) -- Secret items show a dark core behind the rainbow border

function Rarities.get(tier: number?): Rarity
	local index = math.clamp(math.floor(tonumber(tier) or 1), 1, #Rarities.List)
	return Rarities.List[index]
end

return Rarities
