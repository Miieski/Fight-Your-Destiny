--!strict
-- The look of the whole UI (owner, Round 8 part 8: wood planks, gold, steel corners, no pirate theme). Kit/Theme reads the colors, fonts and
-- sizes here; the shared pieces in Kit (Panel, Button, Slot, Tabs, Bar, IconButton, SkillSlot, Components) use the images. The images are drawn by
-- tools/make_ui_textures.py (docs/ui_textures/): Slice = the Rect left, top, right, bottom of the 9-slice middle, in image pixels.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)

local rgb = Color3.fromRGB

local UITheme = {}

UITheme.Colors = {
	WoodTop = rgb(92, 56, 32),
	WoodBottom = rgb(58, 34, 18),
	WoodLight = rgb(126, 82, 50),
	WoodInset = rgb(40, 24, 14),
	WoodLine = rgb(22, 13, 6),
	GoldLight = rgb(240, 192, 92),
	GoldDark = rgb(170, 116, 40),
	GoldFace = rgb(255, 218, 124),
	GoldBase = rgb(122, 78, 20),
	Gold = rgb(255, 208, 86),
	Diamond = rgb(95, 212, 255),
	Health = rgb(217, 59, 59),
	HealthTrail = rgb(255, 196, 170),
	Text = rgb(252, 244, 228),
	TextDim = rgb(206, 186, 156),
	TextDark = rgb(52, 30, 12),
	Ink = rgb(30, 18, 8),
	SteelLight = rgb(178, 184, 196),
	SteelDark = rgb(112, 118, 130),
	SteelBase = rgb(62, 66, 76),
	DangerLight = rgb(232, 84, 74),
	DangerDark = rgb(164, 36, 36),
	DangerBase = rgb(96, 18, 18),
	DisabledLight = rgb(150, 144, 136),
	DisabledDark = rgb(112, 106, 100),
	DisabledBase = rgb(66, 62, 58),
	Good = rgb(91, 220, 110),
	Bad = rgb(255, 96, 96),
	Ruby = rgb(220, 40, 70),
	Sapphire = rgb(60, 120, 240),
	Amethyst = rgb(160, 80, 230),
	Badge = rgb(226, 38, 38),
	Black = rgb(0, 0, 0),
	TabTop = rgb(70, 42, 26),
	TabBottom = rgb(40, 22, 14),
	TabOnTop = rgb(150, 100, 48),
	TabOnBottom = rgb(98, 60, 26),
	SlotSelected = rgb(255, 230, 150),
}

-- font families and weights; Kit/Theme builds the Font objects
UITheme.Fonts = {
	Title = { "rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold },
	Button = { "rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold },
	Body = { "rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium },
	Number = { "rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold },
}

UITheme.Corner = 6 -- small boxes
UITheme.PanelCorner = 12 -- windows and popups
UITheme.Border = 4 -- gold edge of a plain panel
UITheme.Padding = 8
UITheme.TextStroke = 1.75

UITheme.Images = {
	WoodPanel = { Id = "rbxassetid://102876232092438", Tile = 256 },
	WoodInset = { Id = "rbxassetid://124175198489631", Tile = 256 },
	Frame = { Id = "rbxassetid://110475869186778", Slice = Rect.new(44, 44, 84, 84), Scale = 0.5, Outset = 4 },
	Bracket = { Id = "rbxassetid://83342804874146", Size = 44 },
	Banner = { Id = "rbxassetid://118708750547171", Slice = Rect.new(70, 30, 186, 66), Scale = 0.6 },
	Slot = { Id = "rbxassetid://79118367068486", Slice = Rect.new(40, 40, 88, 88), Scale = 0.5 },
	Tile = { Id = "rbxassetid://72299879823649", Slice = Rect.new(44, 44, 84, 84), Scale = 0.6 },
	Pill = { Id = "rbxassetid://74301498427630", Slice = Rect.new(24, 22, 104, 26), Scale = 1 },
	BarFrame = { Id = "rbxassetid://110255165840043", Slice = Rect.new(30, 20, 200, 28), Scale = 0.5, Left = 4, Top = 4, Right = 13 },
	Portrait = { Id = "rbxassetid://102233180375265", HoleX = 0.5, HoleY = 0.406, Hole = 0.547 }, -- the round hole, fractions of the image
	Gem = { Id = "rbxassetid://120974287333695" },
}

-- the color of a rarity (Config/Rarities stays the list of rarities)
function UITheme.rarityColor(tier: number?): Color3
	return Rarities.get(tier).Color
end

return UITheme
