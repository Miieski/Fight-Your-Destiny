--!strict
-- The (i) button (kid-friendly UI, owner 2026-10-13): advanced details (full stat lists, odds, pity counters,
-- descriptions) are not shown on the screen any more; a small blue (i) opens them in a popup over the window.
--   Info.button({ Parent, Frame (the window frame, ctx.Frame), Title, Lines = { string } | () -> { string },
--                 Size?, Position?, AnchorPoint?, ZIndex?, LayoutOrder?, PopupSize?: Vector2 }) -> TextButton
--   Info.show(frame, title, lines, size?)   opens the same popup directly
local Button = require(script.Parent.Button)
local Overlay = require(script.Parent.Overlay)
local Theme = require(script.Parent.Theme)

local Info = {}

function Info.show(frame: GuiObject, title: string, lines: { string }, size: Vector2?)
	local panel = Overlay.open(frame, size or Vector2.new(620, 460))
	Theme.text({ Font = "Title", Text = title, TextSize = 30, Color = Theme.Colors.Gold, Size = UDim2.new(1, -140, 0, 40), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 23, Parent = panel })
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(18, 60)
	scroll.Size = UDim2.new(1, -36, 1, -74)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Theme.Colors.GoldLight
	scroll.ZIndex = 23
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	scroll.Parent = panel
	for i, line in ipairs(lines) do
		local label = Theme.text({ Text = line, TextSize = 19, Wrapped = true, Align = "Left", Size = UDim2.new(1, -8, 0, 24), LayoutOrder = i, ZIndex = 24, Parent = scroll })
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.TextScaled = false
		label.TextSize = 19
	end
end

function Info.button(props: { [string]: any }): TextButton
	local size = props.Size or 40
	local button = Button.new({
		Name = "Info",
		Icon = "Info",
		Style = "wood",
		Size = UDim2.fromOffset(size, size),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex or 4,
		LayoutOrder = props.LayoutOrder,
		Depth = 3,
		Parent = props.Parent,
		OnClick = function()
			local lines = props.Lines
			local resolved = if typeof(lines) == "function" then lines() else lines
			Info.show(props.Frame, props.Title or "", resolved or {}, props.PopupSize)
		end,
	})
	return button.Instance
end

return Info
