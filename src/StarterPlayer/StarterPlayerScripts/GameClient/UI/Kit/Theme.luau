--!strict
-- Wood-fantasy theme (DESIGN.md section 1, docs/ui_hud_brief.txt section 2) and screen scaling.
-- Every ScreenGui is created with Theme.screen(); its "Root" frame is measured in design units
-- (Config/UI Scale), so one layout fits a phone and a 1080p monitor.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)

local rgb = Color3.fromRGB

local Theme = {}

Theme.Colors = {
	WoodTop = rgb(74, 48, 32),
	WoodBottom = rgb(51, 32, 15),
	WoodLight = rgb(104, 70, 44),
	WoodInset = rgb(34, 21, 10),
	WoodLine = rgb(22, 13, 6),
	GoldLight = rgb(232, 180, 74),
	GoldDark = rgb(176, 122, 34),
	GoldFace = rgb(255, 212, 108),
	GoldBase = rgb(122, 78, 20),
	Gold = rgb(255, 201, 60),
	Diamond = rgb(95, 212, 255),
	Health = rgb(217, 59, 59),
	HealthTrail = rgb(255, 196, 170),
	Text = rgb(250, 240, 220),
	TextDim = rgb(196, 176, 146),
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
}

local GRENZE = "rbxasset://fonts/families/GrenzeGotisch.json"
local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
Theme.Fonts = {
	Title = Font.new(GRENZE, Enum.FontWeight.Bold),
	Button = Font.new(GRENZE, Enum.FontWeight.SemiBold),
	Body = Font.new(BUILDER, Enum.FontWeight.Medium),
	Number = Font.new(BUILDER, Enum.FontWeight.Bold),
}

Theme.CORNER = 6
Theme.BORDER = 4
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
		stroke.Thickness = props.StrokeThickness or 1.75
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

function Theme.setUserScale(value: number)
	if value ~= userScale then
		userScale = value
		recompute()
	end
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
