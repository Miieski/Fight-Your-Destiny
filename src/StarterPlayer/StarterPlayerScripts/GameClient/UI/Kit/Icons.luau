--!strict
-- Icons. Placeholder shapes for now; put a real image asset id in Icons.Assets and that id is used
-- instead (ids are shared with Config/UI Menu, weapon categories and toast kinds).
local Theme = require(script.Parent.Theme)

local rgb = Color3.fromRGB

local Icons = {}

Icons.Assets = {
	Inventory = "", Training = "", Shop = "", RebirthShop = "", Pets = "", Index = "", Quests = "",
	Team = "", Settings = "", Gold = "", Diamond = "", Heart = "", Plus = "", Close = "", Menu = "",
	Sword = "", Spear = "", Heavy = "", Dagger = "", Gauntlet = "", Ranged = "", Magic = "", Whip = "",
	Pet = "", Egg = "", Armor = "", Info = "", Warning = "", Skull = "", Gift = "", Admin = "", Boost = "",
}

local C = {
	Gold = rgb(255, 201, 60), GoldDark = rgb(196, 140, 30), Silver = rgb(220, 226, 236), Steel = rgb(150, 156, 168),
	Wood = rgb(160, 104, 58), WoodDark = rgb(104, 66, 38), Leather = rgb(176, 112, 64), Paper = rgb(242, 228, 192),
	Red = rgb(217, 59, 59), Diamond = rgb(95, 212, 255), DiamondLight = rgb(210, 244, 255), Purple = rgb(168, 96, 236),
	Green = rgb(91, 200, 110), Blue = rgb(70, 130, 235), Bone = rgb(238, 230, 208), Dark = rgb(40, 26, 16),
	White = rgb(250, 250, 250), Orange = rgb(255, 150, 40),
}

-- { centerX, centerY, width, height, color, rotation, cornerFraction } in fractions of the icon
local PAW = { { 0.5, 0.66, 0.44, 0.36, "Paper", 0, 0.5 }, { 0.24, 0.42, 0.17, 0.2, "Paper", 0, 0.5 }, { 0.4, 0.26, 0.17, 0.2, "Paper", 0, 0.5 }, { 0.6, 0.26, 0.17, 0.2, "Paper", 0, 0.5 }, { 0.76, 0.42, 0.17, 0.2, "Paper", 0, 0.5 } }
local SHAPES: { [string]: { { any } } } = {
	Gold = { { 0.5, 0.5, 0.9, 0.9, "GoldDark", 0, 0.5 }, { 0.5, 0.5, 0.72, 0.72, "Gold", 0, 0.5 }, { 0.5, 0.5, 0.3, 0.3, "GoldDark", 0, 0.12 }, { 0.5, 0.5, 0.3, 0.3, "GoldDark", 45, 0.12 } },
	Diamond = { { 0.5, 0.5, 0.66, 0.66, "Diamond", 45, 0.08 }, { 0.41, 0.41, 0.22, 0.22, "DiamondLight", 45, 0.05 } },
	Heart = { { 0.34, 0.4, 0.38, 0.38, "Red", 0, 0.5 }, { 0.66, 0.4, 0.38, 0.38, "Red", 0, 0.5 }, { 0.5, 0.56, 0.46, 0.46, "Red", 45, 0.06 } },
	Plus = { { 0.5, 0.5, 0.62, 0.16, "Gold", 0, 0.3 }, { 0.5, 0.5, 0.16, 0.62, "Gold", 0, 0.3 } },
	Close = { { 0.5, 0.5, 0.72, 0.15, "White", 45, 0.3 }, { 0.5, 0.5, 0.72, 0.15, "White", -45, 0.3 } },
	Menu = { { 0.5, 0.28, 0.68, 0.13, "Gold", 0, 0.5 }, { 0.5, 0.5, 0.68, 0.13, "Gold", 0, 0.5 }, { 0.5, 0.72, 0.68, 0.13, "Gold", 0, 0.5 } },
	Sword = { { 0.57, 0.43, 0.13, 0.68, "Silver", 45, 0.1 }, { 0.33, 0.67, 0.44, 0.1, "Gold", 45, 0.3 }, { 0.23, 0.77, 0.09, 0.2, "Leather", 45, 0.3 }, { 0.15, 0.85, 0.12, 0.12, "Gold", 0, 0.5 } },
	Spear = { { 0.46, 0.54, 0.07, 0.86, "Wood", 45, 0.3 }, { 0.8, 0.2, 0.2, 0.2, "Silver", 45, 0.08 } },
	Heavy = { { 0.42, 0.58, 0.1, 0.72, "Wood", 45, 0.3 }, { 0.66, 0.34, 0.5, 0.26, "Steel", 45, 0.1 } },
	Dagger = { { 0.58, 0.42, 0.12, 0.46, "Silver", 45, 0.15 }, { 0.4, 0.6, 0.3, 0.09, "Gold", 45, 0.3 }, { 0.3, 0.7, 0.09, 0.18, "Leather", 45, 0.3 } },
	Gauntlet = { { 0.5, 0.56, 0.56, 0.46, "Steel", 0, 0.25 }, { 0.5, 0.33, 0.56, 0.14, "Silver", 0, 0.3 }, { 0.5, 0.84, 0.44, 0.14, "Leather", 0, 0.2 } },
	Ranged = { { 0.36, 0.22, 0.08, 0.34, "Wood", -30, 0.4 }, { 0.3, 0.5, 0.08, 0.3, "Wood", 0, 0.4 }, { 0.36, 0.78, 0.08, 0.34, "Wood", 30, 0.4 }, { 0.46, 0.5, 0.03, 0.78, "Paper", 0, 0 }, { 0.62, 0.5, 0.62, 0.05, "Silver", 0, 0 }, { 0.9, 0.5, 0.12, 0.12, "Silver", 45, 0 } },
	Magic = { { 0.44, 0.58, 0.08, 0.78, "Wood", 20, 0.3 }, { 0.58, 0.2, 0.32, 0.32, "Purple", 0, 0.5 }, { 0.55, 0.17, 0.12, 0.12, "White", 0, 0.5 } },
	Whip = { { 0.3, 0.78, 0.09, 0.3, "Leather", 30, 0.3 }, { 0.42, 0.55, 0.07, 0.34, "WoodDark", -20, 0.3 }, { 0.6, 0.4, 0.06, 0.3, "WoodDark", 40, 0.3 }, { 0.75, 0.22, 0.05, 0.26, "WoodDark", -10, 0.3 } },
	Inventory = { { 0.5, 0.62, 0.72, 0.6, "Leather", 0, 0.35 }, { 0.5, 0.3, 0.34, 0.16, "Leather", 0, 0.2 }, { 0.5, 0.38, 0.42, 0.08, "Gold", 0, 0.3 }, { 0.5, 0.64, 0.16, 0.16, "Gold", 0, 0.5 } },
	Training = { { 0.5, 0.5, 0.72, 0.1, "Steel", 0, 0.3 }, { 0.26, 0.5, 0.14, 0.52, "Dark", 0, 0.2 }, { 0.74, 0.5, 0.14, 0.52, "Dark", 0, 0.2 }, { 0.13, 0.5, 0.1, 0.34, "Steel", 0, 0.2 }, { 0.87, 0.5, 0.1, 0.34, "Steel", 0, 0.2 } },
	Shop = { { 0.5, 0.76, 0.62, 0.14, "GoldDark", 0, 0.3 }, { 0.5, 0.62, 0.62, 0.14, "Gold", 0, 0.3 }, { 0.5, 0.48, 0.62, 0.14, "GoldDark", 0, 0.3 }, { 0.64, 0.28, 0.34, 0.34, "Gold", 0, 0.5 } },
	RebirthShop = { { 0.5, 0.5, 0.6, 0.6, "Purple", 0, 0.08 }, { 0.5, 0.5, 0.6, 0.6, "Purple", 45, 0.08 }, { 0.5, 0.5, 0.32, 0.32, "Gold", 0, 0.5 } },
	Pets = PAW,
	Pet = PAW,
	Index = { { 0.5, 0.5, 0.64, 0.8, "Red", 0, 0.1 }, { 0.24, 0.5, 0.1, 0.8, "Dark", 0, 0 }, { 0.76, 0.5, 0.08, 0.7, "Paper", 0, 0 }, { 0.52, 0.42, 0.22, 0.22, "Gold", 45, 0.1 } },
	Quests = { { 0.5, 0.5, 0.58, 0.62, "Paper", 0, 0.05 }, { 0.5, 0.18, 0.72, 0.14, "GoldDark", 0, 0.5 }, { 0.5, 0.82, 0.72, 0.14, "GoldDark", 0, 0.5 }, { 0.5, 0.42, 0.38, 0.05, "Dark", 0, 0 }, { 0.5, 0.54, 0.38, 0.05, "Dark", 0, 0 }, { 0.46, 0.66, 0.3, 0.05, "Dark", 0, 0 } },
	Team = { { 0.34, 0.32, 0.24, 0.24, "Paper", 0, 0.5 }, { 0.34, 0.7, 0.38, 0.36, "Blue", 0, 0.3 }, { 0.66, 0.3, 0.24, 0.24, "Paper", 0, 0.5 }, { 0.66, 0.68, 0.38, 0.36, "Green", 0, 0.3 } },
	Settings = { { 0.5, 0.5, 0.2, 0.86, "Steel", 0, 0.1 }, { 0.5, 0.5, 0.86, 0.2, "Steel", 0, 0.1 }, { 0.5, 0.5, 0.2, 0.86, "Steel", 45, 0.1 }, { 0.5, 0.5, 0.86, 0.2, "Steel", 45, 0.1 }, { 0.5, 0.5, 0.6, 0.6, "Steel", 0, 0.5 }, { 0.5, 0.5, 0.24, 0.24, "Dark", 0, 0.5 } },
	Egg = { { 0.5, 0.54, 0.56, 0.74, "Paper", 0, 0.5 }, { 0.42, 0.46, 0.12, 0.12, "Green", 0, 0.5 }, { 0.6, 0.66, 0.1, 0.1, "Green", 0, 0.5 } },
	Armor = { { 0.5, 0.48, 0.62, 0.62, "Steel", 0, 0.45 }, { 0.5, 0.58, 0.5, 0.1, "Dark", 0, 0.3 }, { 0.5, 0.36, 0.08, 0.4, "Silver", 0, 0.3 } },
	Info = { { 0.5, 0.5, 0.8, 0.8, "Blue", 0, 0.5 }, { 0.5, 0.3, 0.12, 0.12, "White", 0, 0.5 }, { 0.5, 0.6, 0.12, 0.34, "White", 0, 0.3 } },
	Warning = { { 0.5, 0.52, 0.64, 0.64, "Orange", 45, 0.12 }, { 0.5, 0.46, 0.1, 0.3, "Dark", 0, 0.3 }, { 0.5, 0.7, 0.1, 0.1, "Dark", 0, 0.5 } },
	Skull = { { 0.5, 0.44, 0.66, 0.56, "Bone", 0, 0.45 }, { 0.5, 0.74, 0.38, 0.2, "Bone", 0, 0.2 }, { 0.38, 0.44, 0.16, 0.16, "Dark", 0, 0.5 }, { 0.62, 0.44, 0.16, 0.16, "Dark", 0, 0.5 }, { 0.5, 0.58, 0.06, 0.1, "Dark", 0, 0.3 } },
	Gift = { { 0.5, 0.62, 0.66, 0.5, "Red", 0, 0.1 }, { 0.5, 0.36, 0.74, 0.16, "Red", 0, 0.1 }, { 0.5, 0.56, 0.12, 0.62, "Gold", 0, 0 }, { 0.4, 0.22, 0.18, 0.14, "Gold", 30, 0.5 }, { 0.6, 0.22, 0.18, 0.14, "Gold", -30, 0.5 } },
	Admin = { { 0.5, 0.66, 0.68, 0.22, "Gold", 0, 0.1 }, { 0.24, 0.44, 0.2, 0.2, "Gold", 45, 0.05 }, { 0.5, 0.38, 0.24, 0.24, "Gold", 45, 0.05 }, { 0.76, 0.44, 0.2, 0.2, "Gold", 45, 0.05 }, { 0.5, 0.66, 0.12, 0.12, "Red", 0, 0.5 } },
	Boost = { { 0.57, 0.31, 0.18, 0.48, "Gold", 25, 0.1 }, { 0.43, 0.69, 0.18, 0.48, "Gold", 25, 0.1 }, { 0.5, 0.5, 0.42, 0.12, "Gold", -20, 0.1 } },
}

-- A square-ish holder (fills its parent by default) with the icon drawn inside.
function Icons.create(id: string, parent: Instance?, props: { [string]: any }?): Frame
	local options = props or {}
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.Size = options.Size or UDim2.fromScale(1, 1)
	holder.Position = options.Position or UDim2.fromScale(0.5, 0.5)
	holder.AnchorPoint = options.AnchorPoint or Vector2.new(0.5, 0.5)
	holder.ZIndex = options.ZIndex or 1
	-- An icon sized by height only (width 0) is a square measured on the parent's height.
	if holder.Size.X.Scale == 0 and holder.Size.X.Offset == 0 then
		holder.Size = UDim2.new(holder.Size.Y.Scale, holder.Size.Y.Offset, holder.Size.Y.Scale, holder.Size.Y.Offset)
		holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
	else
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = holder
	end
	local asset = Icons.Assets[id]
	if asset and asset ~= "" then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Image = asset
		image.ZIndex = holder.ZIndex
		image.Parent = holder
	else
		for _, shape in ipairs(SHAPES[id] or SHAPES.Info) do
			local part = Instance.new("Frame")
			part.BorderSizePixel = 0
			part.AnchorPoint = Vector2.new(0.5, 0.5)
			part.Position = UDim2.fromScale(shape[1], shape[2])
			part.Size = UDim2.fromScale(shape[3], shape[4])
			part.BackgroundColor3 = if options.Color then options.Color else C[shape[5]]
			part.Rotation = shape[6] or 0
			part.ZIndex = holder.ZIndex
			if (shape[7] or 0) > 0 then
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(shape[7], 0)
				corner.Parent = part
			end
			local stroke = Instance.new("UIStroke")
			stroke.Color = Theme.Colors.Ink
			stroke.Thickness = 1
			stroke.Transparency = 0.25
			stroke.Parent = part
			part.Parent = holder
		end
	end
	holder.Parent = parent
	return holder
end

return Icons
