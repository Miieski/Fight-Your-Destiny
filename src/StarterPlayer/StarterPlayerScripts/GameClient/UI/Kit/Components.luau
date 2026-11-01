--!strict
-- The one door to the UI pieces (owner, Round 8): every new screen is built from these, so the wood + metal restyle changes them
-- here once. They are the Kit's own pieces, plus the few that were missing.
--   Components.Panel(props), Button(props), Tabs(props), TabButton(props), Slot(props), IconButton(props), Bar(props)
--   Components.TitleBanner(parent, text, props?) -> Frame
--   Components.Card(parent, name, height, order) -> Frame     a framed block of a page
--   Components.Counter(parent, icon, text, props?) -> chip    (chip:Set(text, color?))     Components.CounterRow(parent, props?)
--   Components.Popup(frame, title, size) -> panel, body       a panel over a window (Overlay: tap outside or X to close)
--   Components.Tooltip(parent, props?) -> tip                 tip:Show(title, lines), tip:Hide()
--   Components.Confirm(props)                                 the modal question (Window.confirm)
local Bar = require(script.Parent.Bar)
local Button = require(script.Parent.Button)
local Chips = require(script.Parent.Chips)
local IconButton = require(script.Parent.IconButton)
local Overlay = require(script.Parent.Overlay)
local Panel = require(script.Parent.Panel)
local Slot = require(script.Parent.Slot)
local Tabs = require(script.Parent.Tabs)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local Components = {}

Components.Panel = function(props: { [string]: any })
	return Panel.new(props)
end
Components.Button = Button.new
Components.Tabs = Tabs.new
Components.Slot = Slot.new
Components.IconButton = IconButton.new
Components.Bar = Bar.new
Components.Counter = Chips.chip
Components.CounterRow = Chips.row
Components.Confirm = Window.confirm

-- one tab of a custom layout; Selected picks its style
function Components.TabButton(props: { [string]: any })
	local copy = table.clone(props)
	copy.Style = if props.Selected then "primary" else "secondary"
	copy.Selected = nil
	return Button.new(copy)
end

function Components.TitleBanner(parent: Instance, text: string, props: { [string]: any }?): Frame
	local p = props or {}
	local banner = Panel.new({ Name = p.Name or "Banner", Size = p.Size or UDim2.new(1, -16, 0, 44), Position = p.Position or UDim2.fromOffset(8, 6), AnchorPoint = p.AnchorPoint, Gems = false, BorderThickness = 3, ZIndex = p.ZIndex, LayoutOrder = p.LayoutOrder, Parent = parent })
	Theme.text({ Name = "Title", Font = "Title", Text = text, TextSize = p.TextSize or 26, Color = Theme.Colors.Gold, Size = UDim2.new(1, -16, 0.86, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = (p.ZIndex or 1) + 2, Parent = banner })
	return banner
end

function Components.Card(parent: Instance, name: string, height: number, order: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Theme.Colors.WoodTop
	frame.Size = UDim2.new(1, -8, 0, height)
	frame.LayoutOrder = order
	Theme.corner(frame, 8)
	Theme.stroke(frame, Theme.Colors.GoldDark, 2)
	frame.Parent = parent
	return frame
end

function Components.Popup(frame: GuiObject, title: string, size: Vector2): (Frame, Frame)
	local panel = Overlay.open(frame, size)
	Theme.text({ Font = "Title", Text = title, TextSize = 28, Color = Theme.Colors.Gold, Size = UDim2.new(1, -(Theme.TOUCH + 32), 0, 40), Position = UDim2.fromOffset(16, 12), Align = "Left", ZIndex = 24, Parent = panel })
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(16, 58)
	body.Size = UDim2.new(1, -32, 1, -70)
	body.ZIndex = 24
	body.Parent = panel
	return panel, body
end

export type Tooltip = { Instance: Frame, Show: (Tooltip, string, { string }) -> (), Hide: (Tooltip) -> () }

function Components.Tooltip(parent: Instance, props: { [string]: any }?): Tooltip
	local p = props or {}
	local z = p.ZIndex or 30
	local frame = Panel.new({ Name = "Tooltip", Size = p.Size or UDim2.fromOffset(300, 180), Position = p.Position or UDim2.fromOffset(8, 8), AnchorPoint = p.AnchorPoint, Gems = false, BorderThickness = 3, ZIndex = z, Parent = parent })
	frame.Visible = false
	local title = Theme.text({ Font = "Title", Text = "", TextSize = 22, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 6), ZIndex = z + 1, Parent = frame })
	local body = Theme.text({ Text = "", TextSize = 17, Align = "Left", Wrapped = true, Size = UDim2.new(1, -20, 1, -40), Position = UDim2.fromOffset(10, 36), ZIndex = z + 1, Parent = frame })
	body.TextYAlignment = Enum.TextYAlignment.Top
	local tip = {} :: any
	tip.Instance = frame
	function tip.Show(_, heading: string, lines: { string })
		title.Text = heading
		body.Text = table.concat(lines, "\n")
		frame.Visible = true
	end
	function tip.Hide()
		frame.Visible = false
	end
	return tip
end

return Components
