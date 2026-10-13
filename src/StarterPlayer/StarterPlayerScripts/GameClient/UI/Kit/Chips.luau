--!strict
-- Icon + number chips (kid-friendly UI, owner 2026-10-13): a picture and a number instead of a sentence
-- ("Max HP: 107" -> heart 107, "Reward: 6K Gold" -> coin 6K).
--   Chips.chip(parent, icon, text, props?) -> Chip   props = { Size, Height, Color, TextColor, LayoutOrder, ZIndex,
--                                                             Position, AnchorPoint, Name }
--   chip:Set(text, color?)          chip.Instance, chip.Label
--   Chips.row(parent, props?) -> Frame   a horizontal, wrapping row to put chips in (props = { Size, LayoutOrder,
--                                        ZIndex, Align = "Left" | "Center", Name })
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)

local Chips = {}
Chips.__index = Chips

export type Chip = typeof(setmetatable({} :: { Instance: Frame, Label: TextLabel }, Chips))

function Chips.chip(parent: Instance?, icon: string, text: string, props: { [string]: any }?): Chip
	local p = props or {}
	local h = p.Height or 40
	local frame = Instance.new("Frame")
	frame.Name = p.Name or "Chip"
	frame.BackgroundColor3 = p.Color or Theme.Colors.WoodLine
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.AutomaticSize = if p.Size then Enum.AutomaticSize.None else Enum.AutomaticSize.X
	frame.Size = p.Size or UDim2.fromOffset(0, h)
	frame.Position = p.Position or UDim2.new()
	frame.AnchorPoint = p.AnchorPoint or Vector2.zero
	frame.ZIndex = p.ZIndex or 3
	if p.LayoutOrder then
		frame.LayoutOrder = p.LayoutOrder
	end
	Theme.corner(frame, math.floor(h / 2))
	Theme.stroke(frame, Theme.Colors.GoldDark, 1.5)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = frame
	local iconHolder = Icons.create(icon, frame, { Size = UDim2.fromOffset(h - 4, h - 4), ZIndex = frame.ZIndex + 1 })
	iconHolder.LayoutOrder = 1
	local label = Theme.text({ Name = "Value", Font = "Number", Text = text, TextSize = math.floor(h * 0.62), Color = p.TextColor, Align = "Left", Size = UDim2.fromOffset(0, h - 6), ZIndex = frame.ZIndex + 1, Parent = frame })
	label.AutomaticSize = Enum.AutomaticSize.X
	label.TextScaled = false
	label.TextSize = math.floor(h * 0.62)
	label.LayoutOrder = 2
	frame.Parent = parent
	return setmetatable({ Instance = frame, Label = label }, Chips)
end

function Chips.Set(self: Chip, text: string, color: Color3?)
	self.Label.Text = text
	if color then
		self.Label.TextColor3 = color
	end
end

function Chips.row(parent: Instance?, props: { [string]: any }?): Frame
	local p = props or {}
	local row = Instance.new("Frame")
	row.Name = p.Name or "Chips"
	row.BackgroundTransparency = 1
	row.Size = p.Size or UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.ZIndex = p.ZIndex or 3
	if p.LayoutOrder then
		row.LayoutOrder = p.LayoutOrder
	end
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Wraps = true
	list.HorizontalAlignment = Enum.HorizontalAlignment[p.Align or "Left"]
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	row.Parent = parent
	return row
end

return Chips
