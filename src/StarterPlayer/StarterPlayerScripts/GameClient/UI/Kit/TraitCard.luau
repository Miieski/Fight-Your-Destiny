--!strict
-- One Bonus Stats item of a pet as a card (Config/PetTraits, owner 2026-10-13, like the reference image):
-- the slot's picture on the left, "RARITY" in the rarity's colour, the item's name, and the stat as
-- picture + number ("+3.8%" next to the speed boot). The border takes the rarity colour.
--   TraitCard.new(parent, slot, trait, props?) -> Frame
--     props = { Size, Position, AnchorPoint, LayoutOrder, ZIndex, Name, Compact (smaller text) }
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetTraits = require(ReplicatedStorage.GameSystem.Config.PetTraits)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)

local TraitCard = {}

function TraitCard.new(parent: Instance?, slot: string, trait: PetTraits.Trait, props: { [string]: any }?): Frame
	local p = props or {}
	local tier = PetTraits.tier(trait)
	local rarity = Rarities.get(tier)
	local item = PetTraits.item(slot, trait)
	local stat = PetTraits.STATS[trait.stat]
	local compact = p.Compact == true
	local z = p.ZIndex or 3

	local card = Instance.new("Frame")
	card.Name = p.Name or slot
	card.Size = p.Size or UDim2.new(1, 0, 0, if compact then 48 else 58)
	card.Position = p.Position or UDim2.new()
	card.AnchorPoint = p.AnchorPoint or Vector2.zero
	card.BackgroundColor3 = if tier == #Rarities.List then Rarities.SECRET_CORE else Theme.Colors.WoodInset
	card.ZIndex = z
	if p.LayoutOrder then
		card.LayoutOrder = p.LayoutOrder
	end
	Theme.corner(card, 8)
	Theme.paintRarity(Theme.stroke(card, rarity.Color, 2.5), tier)
	-- a soft band of the rarity colour behind the picture
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.BackgroundColor3 = rarity.Color
	band.BackgroundTransparency = 0.72
	band.BorderSizePixel = 0
	band.Size = UDim2.new(0, if compact then 44 else 54, 1, 0)
	band.ZIndex = z
	Theme.corner(band, 8)
	band.Parent = card

	local side = if compact then 38 else 46
	Icons.create(PetTraits.SLOT_ICONS[slot] or "Star", card, { Size = UDim2.fromOffset(side, side), Position = UDim2.new(0, 4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = z + 1 })
	local x = side + 10
	local tierLabel = Theme.text({ Name = "Rarity", Font = "Button", Text = string.upper(rarity.Name), TextSize = if compact then 12 else 14, Align = "Left", Size = UDim2.new(1, -(x + 4), 0.34, 0), Position = UDim2.new(0, x, 0, 3), ZIndex = z + 1, Parent = card })
	Theme.paintRarity(tierLabel, tier)
	Theme.text({ Name = "Item", Font = "Title", Text = item.Name, TextSize = if compact then 15 else 19, Align = "Left", Size = UDim2.new(1, -(x + 4), 0.36, 0), Position = UDim2.new(0, x, 0.3, 0), ZIndex = z + 1, Parent = card })
	-- the stat: picture + number
	local statRow = Instance.new("Frame")
	statRow.Name = "Stat"
	statRow.BackgroundTransparency = 1
	statRow.Size = UDim2.new(1, -(x + 4), 0.34, 0)
	statRow.Position = UDim2.new(0, x, 0.64, 0)
	statRow.ZIndex = z + 1
	statRow.Parent = card
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 3)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = statRow
	local icon = Icons.create(stat.Icon, statRow, { Size = UDim2.new(0, 0, 1, 0), ZIndex = z + 1 })
	icon.LayoutOrder = 1
	local value = Theme.text({ Name = "Value", Font = "Number", Text = PetTraits.percentText(PetTraits.value(trait)), TextSize = if compact then 13 else 16, Color = Theme.Colors.Good, Align = "Left", Size = UDim2.new(0, 60, 1, 0), ZIndex = z + 1, Parent = statRow })
	value.LayoutOrder = 2
	card.Parent = parent
	return card
end

return TraitCard
