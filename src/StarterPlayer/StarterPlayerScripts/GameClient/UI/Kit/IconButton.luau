--!strict
-- Menu tile: square wooden button with a raised base, a big 3D icon (gently bobbing, squashed while
-- pressed) above a bold label with a thick dark stroke, and a red Badge slot. The label is hidden on
-- small phones (icon only).
--   IconButton.new({ Icon, Label, Size = Vector2, Parent, LayoutOrder, OnClick, ShowLabel = true, Bob = true })
--   tile.Instance, tile.Badge, tile:SetLabelVisible(bool)
local TweenService = game:GetService("TweenService")

local Badge = require(script.Parent.Badge)
local Button = require(script.Parent.Button)
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)

local IconButton = {}
IconButton.__index = IconButton

local DEPTH = 6 -- raised base under the face
local BOB = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local BOB_HEIGHT = 0.035 -- fraction of the tile
local SQUASH = 0.86
local SQUASH_IN = TweenInfo.new(0.08, Enum.EasingStyle.Quad)
local SQUASH_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

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
		Depth = DEPTH,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		OnClick = props.OnClick,
		Parent = props.Parent,
	})
	button.Label.Visible = false
	-- the holder bobs; the icon inside keeps the size/position set by SetLabelVisible
	local holder = Instance.new("Frame")
	holder.Name = "IconHolder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = button.Face
	local icon = Icons.create(props.Icon, holder, { Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.5, 0.4) })
	local squash = Instance.new("UIScale")
	squash.Parent = icon
	local caption = Theme.text({
		Name = "Caption",
		Font = "Button",
		Text = props.Label or "",
		TextSize = 20,
		Color = Theme.Colors.Text,
		StrokeThickness = 2.5,
		Size = UDim2.new(1, -4, 0.27, 0),
		Position = UDim2.new(0.5, 0, 1, -2),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 2,
		Parent = button.Face,
	})
	if props.Bob ~= false then
		task.delay(math.random() * 1.5, function()
			if holder.Parent then
				TweenService:Create(holder, BOB, { Position = UDim2.fromScale(0, -BOB_HEIGHT) }):Play()
			end
		end)
	end
	button.Instance.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(squash, SQUASH_IN, { Scale = SQUASH }):Play()
		end
	end)
	local function release()
		TweenService:Create(squash, SQUASH_OUT, { Scale = 1 }):Play()
	end
	button.Instance.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			release()
		end
	end)
	button.Instance.MouseLeave:Connect(release)
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
	self.Icon.Size = if visible then UDim2.fromScale(0.7, 0.7) else UDim2.fromScale(0.84, 0.84)
	self.Icon.Position = if visible then UDim2.fromScale(0.5, 0.4) else UDim2.fromScale(0.5, 0.5)
end

return IconButton
