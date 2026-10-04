--!strict
-- HUD 2: Gold and Diamonds, stacked at the top-right (order and sizes in Config/UI Currencies).
-- Each bar: a big round icon over the left end of a dark wooden pill, the amount in white with a
-- dark stroke (it shrinks to fit), and a "+" end cap; tapping the bar opens the Shop on its tab
-- (Diamonds tab for Diamonds). Every change counts up with a pop and a floating "+N" (green) /
-- "-N" (red) left of the bar, so the death penalty shows its Gold loss in red.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local State = require(script.Parent.Parent.State)
local Kit = script.Parent.Kit
local Icons = require(Kit.Icons)
local Screens = require(Kit.Screens)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local Currencies = { Priority = 10 }

local CONFIG: { [string]: any } = UIConfig.Currencies :: any
local MARGIN = 12 -- from the right edge of the screen
local ICON_OVERLAP = 0.42 -- the pill starts this fraction of the icon size from the bar's left edge
local TRACK_INSET = 0.3 -- the dark track starts under the icon, this fraction of the icon size into the pill
local PLUS_AREA = 40 -- light end cap of the pill that holds the "+"
local FLOAT_WIDTH = 140
local FLOAT_RISE = 18
local WHITE = Color3.new(1, 1, 1)

type Pill = {
	row: Frame,
	bar: Frame,
	track: Frame,
	label: TextLabel,
	icon: Frame,
	plus: Frame,
	value: NumberValue,
	pop: UIScale,
	target: number?,
	tween: Tween?,
}

local stack: Frame
local list: UIListLayout
local pills: { [string]: Pill } = {}

local function float(pill: Pill, delta: number)
	local up = delta > 0
	local text = Theme.text({
		Font = "Number",
		Text = (if up then "+" else "") .. Format.number(delta),
		TextSize = 22,
		Color = if up then Theme.Colors.Good else Theme.Colors.Bad,
		Align = "Right",
		Size = UDim2.fromOffset(FLOAT_WIDTH, 26),
		Position = UDim2.new(0, -6, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		ZIndex = 7,
		Parent = pill.row,
	})
	local stroke = text:FindFirstChildOfClass("UIStroke") :: UIStroke
	local info = TweenInfo.new(UIConfig.Hud.FloatSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(text, info, { Position = UDim2.new(0, -6, 0.5, -FLOAT_RISE), TextTransparency = 1 }):Play()
	local fade = TweenService:Create(stroke, info, { Transparency = 1 })
	fade.Completed:Connect(function()
		text:Destroy()
	end)
	fade:Play()
end

local function update(pill: Pill, value: any, sound: string?)
	local amount = tonumber(value) or 0
	local previous = pill.target
	pill.target = amount
	if previous == nil then
		pill.value.Value = amount
		return
	end
	local delta = amount - previous
	if delta == 0 then
		return
	end
	if pill.tween then
		pill.tween:Cancel()
	end
	pill.tween = TweenService:Create(pill.value, TweenInfo.new(UIConfig.Hud.CountUpSeconds, Enum.EasingStyle.Quad), { Value = amount })
	pill.tween:Play()
	pill.pop.Scale = UIConfig.Hud.PopScale
	TweenService:Create(pill.pop, TweenInfo.new(UIConfig.Hud.CountUpSeconds, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	float(pill, delta)
	if delta > 0 and sound then
		Sfx.play(sound)
	end
end

-- Sizes one bar for the current layout (dims = CONFIG.Normal or CONFIG.Compact).
local function size(pill: Pill, dims: any, width: number)
	local iconSize, barHeight = dims.Icon, dims.Bar
	local barLeft = math.floor(iconSize * ICON_OVERLAP)
	local trackLeft = math.floor(iconSize * TRACK_INSET)
	pill.row.Size = UDim2.fromOffset(width, iconSize)
	pill.icon.Size = UDim2.fromOffset(iconSize, iconSize)
	pill.bar.Position = UDim2.new(0, barLeft, 0.5, 0)
	pill.bar.Size = UDim2.new(1, -barLeft, 0, barHeight)
	pill.track.Position = UDim2.new(0, trackLeft, 0.5, 0)
	pill.track.Size = UDim2.new(1, -(trackLeft + PLUS_AREA), 1, -10)
	-- the amount starts right of the icon
	local textLeft = iconSize + 4 - barLeft - trackLeft
	pill.label.Position = UDim2.new(0, textLeft, 0.5, 0)
	pill.label.Size = UDim2.new(1, -(textLeft + 8), 1, -4)
	local plusSize = math.floor(barHeight * 0.55)
	pill.plus.Size = UDim2.fromOffset(plusSize, plusSize)
end

local function makePill(id: string, order: number): Pill
	local config = CONFIG[id]
	local row = Instance.new("Frame")
	row.Name = id
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	local pop = Instance.new("UIScale")
	pop.Parent = row

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.BackgroundColor3 = WHITE
	bar.BorderSizePixel = 0
	bar.ZIndex = 1
	Theme.gradient(bar, Theme.Colors.WoodLight, Theme.Colors.WoodTop)
	Theme.round(bar)
	Theme.stroke(bar, Theme.Colors.Ink, 2.5)
	bar.Parent = row

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.BackgroundColor3 = Theme.Colors.WoodInset
	track.BorderSizePixel = 0
	track.ZIndex = 2
	Theme.round(track)
	Theme.stroke(track, Theme.Colors.WoodLine, 1.5)
	track.Parent = bar

	local label = Theme.text({ Name = "Amount", Font = "Number", Text = "0", TextSize = 28, Color = WHITE, StrokeThickness = 2, Align = "Right", AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3, Parent = track })
	local plus = Icons.create("Plus", bar, { Position = UDim2.new(1, -PLUS_AREA / 2, 0.5, 0), Color = WHITE, ZIndex = 3 })
	plus.Name = "Plus"
	local icon = Icons.create(config.Icon, row, { Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 4 })

	local tap = Instance.new("TextButton")
	tap.Name = "Tap"
	tap.Text = ""
	tap.AutoButtonColor = false
	tap.BackgroundTransparency = 1
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 6
	tap.Activated:Connect(function()
		Sfx.play("UIClick")
		Window.open("Shop", config.ShopTab)
	end)
	tap.Parent = row

	local value = Instance.new("NumberValue")
	value.Parent = row
	value.Changed:Connect(function(v)
		label.Text = Format.number(v)
	end)
	row.Parent = stack
	return { row = row, bar = bar, track = track, label = label, icon = icon, plus = plus, value = value, pop = pop, target = nil, tween = nil }
end

local function layout()
	local compact = Theme.isCompact()
	local dims = if compact then CONFIG.Compact else CONFIG.Normal
	list.Padding = UDim.new(0, dims.Gap)
	local widest = 0
	for _, id in ipairs(CONFIG.Order) do
		local width = if compact then CONFIG[id].CompactWidth else CONFIG[id].Width
		size(pills[id], dims, width)
		widest = math.max(widest, width)
	end
	local count = #CONFIG.Order
	stack.Size = UDim2.fromOffset(widest, count * dims.Icon + (count - 1) * dims.Gap)
	stack.Position = UDim2.new(1, -MARGIN, 0, dims.Top)
end

function Currencies:Start()
	stack = Instance.new("Frame")
	stack.Name = "Currencies"
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(1, 0)
	list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = stack
	stack.Parent = Screens.hud()
	for order, id in ipairs(CONFIG.Order) do
		pills[id] = makePill(id, order)
	end
	layout()
	Theme.Changed:Connect(layout)
	for _, id in ipairs(CONFIG.Order) do
		State.observe(id, function(value)
			update(pills[id], value, CONFIG[id].Sound)
		end)
	end
end

return Currencies
