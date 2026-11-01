--!strict
-- Wood-fantasy theme (DESIGN.md section 1, docs/ui_hud_brief.txt section 2) and screen scaling.
-- Every ScreenGui is created with Theme.screen(); its "Root" frame is measured in design units
-- (Config/UI Scale), so one layout fits a phone and a 1080p monitor.
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local UITheme = require(ReplicatedStorage.GameSystem.Config.UITheme)

local Theme = {}

Theme.Colors = UITheme.Colors
Theme.Images = UITheme.Images

Theme.Fonts = {}
for name, font in pairs(UITheme.Fonts) do
	Theme.Fonts[name] = Font.new(font[1], font[2])
end

Theme.CORNER = UITheme.Corner
Theme.PANEL_CORNER = UITheme.PanelCorner
Theme.BORDER = UITheme.Border
Theme.TOUCH = UIConfig.TOUCH
Theme.PRESS_SECONDS = 0.08

----------------------------------------------------------------------------------------------------
-- Small builders
----------------------------------------------------------------------------------------------------
function Theme.corner(parent: Instance, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.CORNER)
	corner.Parent = parent
	return corner
end

function Theme.round(parent: Instance): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = parent
	return corner
end

function Theme.stroke(parent: Instance, color: Color3, thickness: number?, border: boolean?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1.5
	if border ~= false and parent:IsA("GuiObject") and not parent:IsA("TextLabel") then
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	stroke.Parent = parent
	return stroke
end

function Theme.gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

-- A 9-slice (or plain) image of Config/UITheme.Images filling its parent, or props.Size.
function Theme.image(parent: Instance, key: string, props: { [string]: any }?): ImageLabel
	local info = UITheme.Images[key]
	local p = props or {}
	local image = Instance.new("ImageLabel")
	image.Name = p.Name or key
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Image = info.Id
	image.Size = p.Size or UDim2.fromScale(1, 1)
	image.Position = p.Position or UDim2.new()
	image.AnchorPoint = p.AnchorPoint or Vector2.zero
	image.ZIndex = p.ZIndex or 1
	if info.Slice then
		image.ScaleType = Enum.ScaleType.Slice
		image.SliceCenter = info.Slice
		image.SliceScale = p.SliceScale or info.Scale or 1
	end
	image.Parent = parent
	return image
end

-- A transparent TextLabel with the theme's text stroke.
-- props: Font ("Title"|"Button"|"Body"|"Number"), Size, Position, AnchorPoint, Text, TextSize
-- (max size, the text scales down to fit), Color, Align ("Left"|"Center"|"Right"), Parent, ...
function Theme.text(props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.FontFace = Theme.Fonts[props.Font or "Body"]
	label.TextColor3 = props.Color or Theme.Colors.Text
	-- TextWrapped must be set before TextScaled: writing TextWrapped afterwards turns TextScaled off.
	label.TextWrapped = props.Wrapped == true
	label.TextScaled = true
	label.Text = props.Text or ""
	label.Size = props.Size or UDim2.fromScale(1, 1)
	label.Position = props.Position or UDim2.new()
	label.AnchorPoint = props.AnchorPoint or Vector2.zero
	label.TextXAlignment = Enum.TextXAlignment[props.Align or "Center"]
	label.TextYAlignment = Enum.TextYAlignment[props.VAlign or "Center"]
	label.ZIndex = props.ZIndex or 1
	if props.Name then
		label.Name = props.Name
	end
	if props.LayoutOrder then
		label.LayoutOrder = props.LayoutOrder
	end
	Theme.limit(label, props.TextSize or 22, props.MinTextSize)
	if props.Stroke ~= false then
		local stroke = Instance.new("UIStroke")
		stroke.Color = props.StrokeColor or Theme.Colors.Ink
		stroke.Thickness = props.StrokeThickness or UITheme.TextStroke
		stroke.Parent = label
	end
	label.Parent = props.Parent
	return label
end

-- Loops a gradient's rotation forever; the tween is cancelled when the gradient goes away.
function Theme.spin(gradient: UIGradient, seconds: number?)
	gradient.Rotation = 0
	local tween = TweenService:Create(gradient, TweenInfo.new(seconds or Rarities.GRADIENT_SPIN_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 })
	tween:Play()
	gradient.Destroying:Connect(function()
		tween:Cancel()
	end)
end

-- Colors a UIStroke (or a frame's background, or a label's text) with a rarity, animated for
-- Divine and Secret.
function Theme.paintRarity(target: Instance, tier: number?)
	local rarity = Rarities.get(tier)
	local old = target:FindFirstChild("RarityGradient")
	if old then
		old:Destroy()
	end
	if target:IsA("UIStroke") then
		target.Color = if rarity.Gradient then Color3.new(1, 1, 1) else rarity.Color
	elseif target:IsA("TextLabel") then
		target.TextColor3 = if rarity.Gradient then Color3.new(1, 1, 1) else rarity.Color
	elseif target:IsA("GuiObject") then
		target.BackgroundColor3 = if rarity.Gradient then Color3.new(1, 1, 1) else rarity.Color
	end
	if rarity.Gradient then
		local gradient = Instance.new("UIGradient")
		gradient.Name = "RarityGradient"
		gradient.Color = rarity.Gradient
		gradient.Parent = target
		Theme.spin(gradient)
	end
end

----------------------------------------------------------------------------------------------------
-- Screens and scaling
----------------------------------------------------------------------------------------------------
type Screen = { gui: ScreenGui, root: Frame, uiScale: UIScale }

local screens: { Screen } = {}
local scale, compact, userScale = 1, false, 1
local changed = Instance.new("BindableEvent")
local measure: ScreenGui? = nil
-- UITextSizeConstraint sizes are screen pixels, not design units, so they follow the scale.
local TEXT_LIMIT_TAG = "UiTextLimit"
local MAX_TEXT_SIZE = 100

local function applyLimit(limit: UITextSizeConstraint)
	local max = limit:GetAttribute("DesignMax") :: number? or 22
	local min = limit:GetAttribute("DesignMin") :: number? or 8
	limit.MaxTextSize = math.clamp(math.round(max * scale), 1, MAX_TEXT_SIZE)
	limit.MinTextSize = math.clamp(math.round(min * scale), 1, limit.MaxTextSize)
end

-- Fires after the scale or the compact flag changed (viewport resize, UI Scale setting).
Theme.Changed = changed.Event

local function playerGui(): PlayerGui
	return Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
end

local function recompute()
	local size = if measure then measure.AbsoluteSize else Vector2.zero
	if size.Y <= 0 then
		return
	end
	local config = UIConfig.Scale
	local s = math.clamp(size.Y / config.BaseHeight, config.Min, config.Max) * userScale
	if UserInputService.TouchEnabled then
		s = math.max(s, config.TouchMin)
	end
	scale = s
	compact = size.Y / s < config.CompactHeight
	for _, screen in ipairs(screens) do
		screen.root.Size = UDim2.fromScale(1 / s, 1 / s)
		screen.uiScale.Scale = s
	end
	for _, limit in ipairs(CollectionService:GetTagged(TEXT_LIMIT_TAG)) do
		applyLimit(limit :: UITextSizeConstraint)
	end
	changed:Fire()
end

local function ensureMeasure()
	if measure then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "_Measure"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = playerGui()
	measure = gui
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(recompute)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(recompute)
end

function Theme.getScale(): number
	return scale
end

function Theme.isCompact(): boolean
	return compact
end

function Theme.isTouch(): boolean
	return UserInputService.TouchEnabled
end

-- Size of a screen root in design units.
function Theme.size(): Vector2
	local size = if measure then measure.AbsoluteSize else Vector2.new(1280, 660)
	return size / scale
end

-- Caps a scaled text (label or box) at a size given in design units.
function Theme.limit(target: GuiObject, max: number, min: number?): UITextSizeConstraint
	local limit = Instance.new("UITextSizeConstraint")
	limit:SetAttribute("DesignMax", max)
	limit:SetAttribute("DesignMin", min or 8)
	applyLimit(limit)
	limit:AddTag(TEXT_LIMIT_TAG)
	limit.Parent = target
	return limit
end

-- Phones (compact layout) lift top-center and top-right HUD pieces into the Roblox top bar strip,
-- which is free right of the Roblox buttons (GuiService.TopbarInset). Returns how far up, in design
-- units, a piece whose left edge is at leftX (design units) may move: 0 when the layout is not
-- compact or when the piece would reach the Roblox buttons.
local TOPBAR_GAP = 8 -- pixels kept between a lifted piece and the Roblox buttons

function Theme.topbarLift(leftX: number): number
	local inset = GuiService.TopbarInset
	if not compact or inset.Height <= 0 or leftX * scale < inset.Min.X + TOPBAR_GAP then
		return 0
	end
	return inset.Height / scale
end

function Theme.setUserScale(value: number)
	if value ~= userScale then
		userScale = value
		recompute()
	end
end

local lastPress = Vector2.zero
UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		lastPress = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

local function isOver(panel: GuiObject, at: Vector2): boolean
	for _, object in ipairs(playerGui():GetGuiObjectsAtPosition(at.X, at.Y)) do
		if object == panel or object:IsDescendantOf(panel) then
			return true
		end
	end
	return false
end

-- The rule of every "click outside closes it": from a dim button's Activated, true only if the press started AND ended outside
-- panel (Roblox fires Activated on the dim for a press held on the panel). A gamepad has no pointer: always true.
function Theme.clickedOutside(panel: GuiObject, input: InputObject): boolean
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return true
	end
	return not isOver(panel, lastPress) and not isOver(panel, Vector2.new(input.Position.X, input.Position.Y))
end

-- A ScreenGui with a scaled "Root" frame filling the safe area. Returns (gui, root).
function Theme.screen(name: string, displayOrder: number?): (ScreenGui, Frame)
	ensureMeasure()
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = displayOrder or 0
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1 / scale, 1 / scale)
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = scale
	uiScale.Parent = root
	root.Parent = gui
	gui.Parent = playerGui()
	table.insert(screens, { gui = gui, root = root, uiScale = uiScale })
	recompute()
	return gui, root
end

return Theme
