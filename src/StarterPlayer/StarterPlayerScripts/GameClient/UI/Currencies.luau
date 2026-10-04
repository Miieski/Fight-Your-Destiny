--!strict
-- HUD 2: Gold and Diamonds. Count-up tween, pop and a floating "+N" (green) / "-N" (red) on every
-- change (so the death penalty shows its Gold loss in red). Tapping Diamonds opens Shop > Diamonds.
-- Top-right on large screens, under the health bar on phones.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local State = require(script.Parent.Parent.State)
local Kit = script.Parent.Kit
local Icons = require(Kit.Icons)
local Panel = require(Kit.Panel)
local Screens = require(Kit.Screens)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local Currencies = { Priority = 10 }

local WIDTH = { Gold = 176, Diamonds = 144 }
local COMPACT_WIDTH = { Gold = 140, Diamonds = 118 }
local GAP = 8

type Pill = { frame: Frame, label: TextLabel, value: NumberValue, pop: UIScale, target: number?, color: Color3, tween: Tween? }

local row: Frame
local pills: { [string]: Pill } = {}

local function float(pill: Pill, delta: number)
	local up = delta > 0
	local text = Theme.text({
		Font = "Number",
		Text = (if up then "+" else "") .. Format.number(delta),
		TextSize = 22,
		Color = if up then Theme.Colors.Good else Theme.Colors.Bad,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0.5, 0, 1, 4),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 5,
		Parent = pill.frame,
	})
	local stroke = text:FindFirstChildOfClass("UIStroke") :: UIStroke
	local info = TweenInfo.new(UIConfig.Hud.FloatSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(text, info, { Position = UDim2.new(0.5, 0, 1, 34), TextTransparency = 1 }):Play()
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

local function makePill(id: string, icon: string, color: Color3, order: number, onClick: (() -> ())?): Pill
	local frame = Panel.new({ Name = id, Size = UDim2.fromOffset(WIDTH[id], Theme.TOUCH), Gems = false, BorderThickness = 3, LayoutOrder = order, Parent = row })
	local pop = Instance.new("UIScale")
	pop.Parent = frame
	Icons.create(icon, frame, { Size = UDim2.new(0, 0, 0.7, 0), Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	local label = Theme.text({ Name = "Amount", Font = "Number", TextSize = 28, Color = color, Align = "Left", Size = UDim2.new(1, -56, 0.72, 0), Position = UDim2.new(0, 48, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = frame })
	local value = Instance.new("NumberValue")
	value.Parent = frame
	value.Changed:Connect(function(v)
		label.Text = Format.number(v)
	end)
	label.Text = "0"
	if onClick then
		local hit = Instance.new("TextButton")
		hit.Name = "Tap"
		hit.Text = ""
		hit.BackgroundTransparency = 1
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 4
		hit.Activated:Connect(function()
			Sfx.play("UIClick")
			onClick()
		end)
		hit.Parent = frame
	end
	return { frame = frame, label = label, value = value, pop = pop, target = nil, color = color, tween = nil }
end

local function layout()
	local compact = Theme.isCompact()
	if compact then
		row.AnchorPoint = Vector2.zero
		row.Position = UDim2.fromOffset(12, 66)
	else
		row.AnchorPoint = Vector2.new(1, 0)
		row.Position = UDim2.new(1, -12, 0, 10)
	end
	for id, pill in pairs(pills) do
		pill.frame.Size = UDim2.fromOffset(if compact then COMPACT_WIDTH[id] else WIDTH[id], Theme.TOUCH)
	end
end

function Currencies:Start()
	row = Instance.new("Frame")
	row.Name = "Currencies"
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.XY
	row.Size = UDim2.fromOffset(0, Theme.TOUCH)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, GAP)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	row.Parent = Screens.hud()
	pills.Gold = makePill("Gold", "Gold", Theme.Colors.Gold, 1, nil)
	pills.Diamonds = makePill("Diamonds", "Diamond", Theme.Colors.Diamond, 2, function()
		Window.open("Shop", "Diamonds")
	end)
	layout()
	Theme.Changed:Connect(layout)
	State.observe("Gold", function(value)
		update(pills.Gold, value, "GoldPickup")
	end)
	State.observe("Diamonds", function(value)
		update(pills.Diamonds, value, "GoldPickup")
	end)
end

return Currencies
