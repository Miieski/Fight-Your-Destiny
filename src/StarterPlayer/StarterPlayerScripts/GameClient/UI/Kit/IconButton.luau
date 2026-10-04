--!strict
-- Menu tile: wood button with an icon, an optional label under it, and a red Badge slot.
--   IconButton.new({ Icon, Label, Size = Vector2, Parent, LayoutOrder, OnClick, ShowLabel = true })
--   tile.Instance, tile.Badge, tile:SetLabelVisible(bool)
local Badge = require(script.Parent.Badge)
local Button = require(script.Parent.Button)
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)

local IconButton = {}
IconButton.__index = IconButton

export type IconButton = typeof(setmetatable({} :: {
	Instance: TextButton,
	Button: any,
	Badge: any,
	Icon: Frame,
	Caption: TextLabel,
}, IconButton))

function IconButton.new(props: { [string]: any }): IconButton
	local size: Vector2 = props.Size or Vector2.new(Theme.TOUCH, Theme.TOUCH)
	local button = Button.new({
		Name = props.Name or props.Icon,
		Style = props.Style or "wood",
		Text = "",
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		OnClick = props.OnClick,
		Parent = props.Parent,
	})
	button.Label.Visible = false
	local icon = Icons.create(props.Icon, button.Face, { Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.5, 0.42) })
	local caption = Theme.text({
		Name = "Caption",
		Font = "Button",
		Text = props.Label or "",
		TextSize = 15,
		Color = Theme.Colors.Gold,
		Size = UDim2.new(1, -4, 0.26, 0),
		Position = UDim2.new(0.5, 0, 1, -2),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = button.Face,
	})
	local self = setmetatable({
		Instance = button.Instance,
		Button = button,
		Badge = Badge.new(button.Instance),
		Icon = icon,
		Caption = caption,
	}, IconButton)
	self:SetLabelVisible(props.ShowLabel ~= false and props.Label ~= nil)
	return self
end

function IconButton.SetLabelVisible(self: IconButton, visible: boolean)
	self.Caption.Visible = visible
	self.Icon.Size = if visible then UDim2.fromScale(0.56, 0.56) else UDim2.fromScale(0.64, 0.64)
	self.Icon.Position = if visible then UDim2.fromScale(0.5, 0.4) else UDim2.fromScale(0.5, 0.5)
end

return IconButton
