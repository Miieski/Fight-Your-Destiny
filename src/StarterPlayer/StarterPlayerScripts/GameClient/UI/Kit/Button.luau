--!strict
-- Beveled button: a darker base under the face; pressing moves the face down 2 px and scales to 0.96.
--   local button = Button.new({ Text, Style = "primary"|"secondary"|"danger"|"wood"|"go", Size, Position,
--       AnchorPoint, Parent, LayoutOrder, Icon (Icons id), TextSize, OnClick, Name, ZIndex, Depth })
--   button.Instance, button.Face, button.Label, button:SetText(), :SetEnabled(), :SetStyle()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)

local Button = {}
Button.__index = Button

local DEPTH = 4
local PRESS_SCALE = 0.96

local function styles()
	local c = Theme.Colors
	return {
		primary = { Top = c.GoldFace, Bottom = c.GoldDark, Base = c.GoldBase, Text = c.TextDark, Border = c.Ink, TextStroke = false },
		secondary = { Top = c.SteelLight, Bottom = c.SteelDark, Base = c.SteelBase, Text = c.Text, Border = c.Ink, TextStroke = true },
		danger = { Top = c.DangerLight, Bottom = c.DangerDark, Base = c.DangerBase, Text = c.Text, Border = c.GoldLight, TextStroke = true },
		go = { Top = Color3.fromRGB(112, 226, 104), Bottom = Color3.fromRGB(44, 156, 60), Base = Color3.fromRGB(26, 92, 34), Text = c.Text, Border = c.Ink, TextStroke = true },
		wood = { Top = c.WoodLight, Bottom = c.WoodBottom, Base = c.WoodLine, Text = c.Gold, Border = c.GoldDark, TextStroke = true },
		disabled = { Top = c.DisabledLight, Bottom = c.DisabledDark, Base = c.DisabledBase, Text = c.TextDim, Border = c.Ink, TextStroke = true },
	}
end

export type Button = typeof(setmetatable({} :: {
	Instance: TextButton,
	Face: Frame,
	Base: Frame,
	Label: TextLabel,
	Enabled: boolean,
	Style: string,
	_gradient: UIGradient,
	_stroke: UIStroke,
	_textStroke: UIStroke?,
	_press: UIScale,
	_onClick: (() -> ())?,
}, Button))

function Button.new(props: { [string]: any }): Button
	local depth = props.Depth or DEPTH
	local root = Instance.new("TextButton")
	root.Name = props.Name or "Button"
	root.Text = ""
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.Size = props.Size or UDim2.fromOffset(160, Theme.TOUCH)
	root.Position = props.Position or UDim2.new()
	root.AnchorPoint = props.AnchorPoint or Vector2.zero
	root.ZIndex = props.ZIndex or 1
	if props.LayoutOrder then
		root.LayoutOrder = props.LayoutOrder
	end
	local press = Instance.new("UIScale")
	press.Name = "Press"
	press.Parent = root

	local base = Instance.new("Frame")
	base.Name = "Base"
	base.Size = UDim2.fromScale(1, 1)
	base.BorderSizePixel = 0
	base.ZIndex = root.ZIndex
	Theme.corner(base, Theme.CORNER)
	base.Parent = root

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, -depth)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.ZIndex = root.ZIndex
	Theme.corner(face, Theme.CORNER)
	local gradient = Theme.gradient(face, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	local stroke = Theme.stroke(face, Theme.Colors.Ink, 2)
	face.Parent = root

	local hasIcon = props.Icon ~= nil
	local hasText = props.Text ~= nil and props.Text ~= ""
	if hasIcon then
		Icons.create(props.Icon, face, {
			Size = if hasText then UDim2.new(0, 0, 0.66, 0) else UDim2.fromScale(0.62, 0.62),
			Position = if hasText then UDim2.new(0, 8, 0.5, 0) else UDim2.fromScale(0.5, 0.5),
			AnchorPoint = if hasText then Vector2.new(0, 0.5) else Vector2.new(0.5, 0.5),
			ZIndex = root.ZIndex,
		})
	end
	local label = Theme.text({
		Name = "Label",
		Font = "Button",
		Text = props.Text or "",
		TextSize = props.TextSize or 24,
		Size = if hasIcon and hasText then UDim2.new(1, -52, 0.78, 0) else UDim2.new(1, -14, 0.78, 0),
		Position = if hasIcon and hasText then UDim2.new(0, 44, 0.5, 0) else UDim2.fromScale(0.5, 0.5),
		AnchorPoint = if hasIcon and hasText then Vector2.new(0, 0.5) else Vector2.new(0.5, 0.5),
		ZIndex = root.ZIndex,
		Parent = face,
	})

	local self = setmetatable({
		Instance = root,
		Face = face,
		Base = base,
		Label = label,
		Enabled = props.Enabled ~= false,
		Style = props.Style or "primary",
		_gradient = gradient,
		_stroke = stroke,
		_textStroke = label:FindFirstChildOfClass("UIStroke"),
		_press = press,
		_onClick = props.OnClick,
	}, Button)
	self:_paint()

	local tweenInfo = TweenInfo.new(Theme.PRESS_SECONDS)
	local function setPressed(pressed: boolean)
		TweenService:Create(face, tweenInfo, { Position = UDim2.fromOffset(0, if pressed then 2 else 0) }):Play()
		TweenService:Create(press, tweenInfo, { Scale = if pressed then PRESS_SCALE else 1 }):Play()
	end
	root.InputBegan:Connect(function(input)
		if self.Enabled and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			setPressed(true)
		end
	end)
	root.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setPressed(false)
		end
	end)
	root.MouseLeave:Connect(function()
		setPressed(false)
	end)
	root.Activated:Connect(function()
		if self.Enabled then
			Sfx.play("UIClick")
			if self._onClick then
				self._onClick()
			end
		end
	end)
	root.Parent = props.Parent
	return self
end

function Button._paint(self: Button)
	local all = styles()
	local style = all[if self.Enabled then self.Style else "disabled"] or all.primary
	self.Base.BackgroundColor3 = style.Base
	self._gradient.Color = ColorSequence.new(style.Top, style.Bottom)
	self._stroke.Color = style.Border
	self._stroke.Thickness = if self.Style == "danger" and self.Enabled then 2.5 else 2
	self.Label.TextColor3 = style.Text
	if self._textStroke then
		self._textStroke.Enabled = style.TextStroke
	end
end

function Button.SetText(self: Button, text: string)
	self.Label.Text = text
end

function Button.SetEnabled(self: Button, enabled: boolean)
	self.Enabled = enabled
	self:_paint()
end

function Button.SetStyle(self: Button, style: string)
	self.Style = style
	self:_paint()
end

function Button.OnClick(self: Button, fn: () -> ())
	self._onClick = fn
end

function Button.Destroy(self: Button)
	self.Instance:Destroy()
end

return Button
