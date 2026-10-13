--!strict
-- One funnel button for every filter and sort (kid-friendly UI, owner 2026-10-13: "filters behind one icon").
-- It opens a popup over the window with one row of picture choices per group; the funnel shows a dot while a
-- group is not on its first ("all") choice.
--   Filter.button({ Parent, Frame (window frame), Groups = { Group }, OnChange = fn, Size?, Position?,
--                   AnchorPoint?, ZIndex?, LayoutOrder? }) -> { Instance, Refresh = fn }
--   Group = { Icon (row picture), Options = { { Value, Icon?, Color?, Text? } }, Get = () -> any, Set = (v) -> () }
local Button = require(script.Parent.Button)
local Icons = require(script.Parent.Icons)
local Overlay = require(script.Parent.Overlay)
local Theme = require(script.Parent.Theme)

local Filter = {}

local TILE = 66

local function tile(parent: Instance, option: { [string]: any }, selected: boolean, order: number, onClick: () -> ())
	local cell = Instance.new("TextButton")
	cell.Name = "Option"
	cell.Text = ""
	cell.AutoButtonColor = false
	cell.Size = UDim2.fromOffset(TILE, TILE)
	cell.BackgroundColor3 = if selected then Theme.Colors.GoldDark else Theme.Colors.WoodInset
	cell.BorderSizePixel = 0
	cell.LayoutOrder = order
	cell.ZIndex = 24
	Theme.corner(cell, 8)
	Theme.stroke(cell, if selected then Theme.Colors.GoldFace else Theme.Colors.WoodLine, if selected then 3 else 1.5)
	local hasText = option.Text ~= nil and option.Text ~= ""
	if option.Icon then
		Icons.create(option.Icon, cell, { Size = UDim2.fromScale(if hasText then 0.62 else 0.78, if hasText then 0.62 else 0.78), Position = UDim2.fromScale(0.5, if hasText then 0.38 else 0.5), ZIndex = 25 })
	elseif option.Color then
		local swatch = Instance.new("Frame")
		swatch.AnchorPoint = Vector2.new(0.5, 0.5)
		swatch.Position = UDim2.fromScale(0.5, if hasText then 0.4 else 0.5)
		swatch.Size = UDim2.fromScale(0.5, 0.5)
		swatch.BackgroundColor3 = option.Color
		swatch.Rotation = 45
		swatch.ZIndex = 25
		Theme.corner(swatch, 4)
		Theme.stroke(swatch, Theme.Colors.Ink, 2)
		swatch.Parent = cell
	end
	if hasText and not option.Icon and not option.Color then
		-- a word on its own ("All"): big, in the middle
		Theme.text({ Font = "Button", Text = option.Text, TextSize = 24, Size = UDim2.new(1, -8, 0.6, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 25, Parent = cell })
	elseif hasText then
		Theme.text({ Font = "Button", Text = option.Text, TextSize = 14, Size = UDim2.new(1, -4, 0.3, 0), Position = UDim2.new(0.5, 0, 1, -2), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 25, Parent = cell })
	end
	cell.Activated:Connect(onClick)
	cell.Parent = parent
end

function Filter.button(props: { [string]: any }): { Instance: TextButton, Refresh: () -> () }
	local groups = props.Groups :: { any }
	local size = props.Size or Theme.TOUCH
	local dot: Frame
	local function refresh()
		local active = false
		for _, group in ipairs(groups) do
			if group.Options[1] and group.Get() ~= group.Options[1].Value then
				active = true
			end
		end
		dot.Visible = active
	end
	local function open()
		local panel = Overlay.open(props.Frame, Vector2.new(760, 120 + #groups * (TILE + 24)))
		Icons.create("Funnel", panel, { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 23 })
		local body = Instance.new("Frame")
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromOffset(16, 66)
		body.Size = UDim2.new(1, -32, 1, -76)
		body.ZIndex = 23
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 10)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = body
		body.Parent = panel
		local function draw()
			for _, child in ipairs(body:GetChildren()) do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end
			for g, group in ipairs(groups) do
				local row = Instance.new("Frame")
				row.BackgroundTransparency = 1
				row.Size = UDim2.new(1, 0, 0, TILE + 6)
				row.LayoutOrder = g
				row.ZIndex = 23
				Icons.create(group.Icon, row, { Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0, 26, 0.5, 0), ZIndex = 24 })
				local options = Instance.new("ScrollingFrame")
				options.BackgroundTransparency = 1
				options.BorderSizePixel = 0
				options.Position = UDim2.fromOffset(64, 0)
				options.Size = UDim2.new(1, -64, 1, 0)
				options.CanvasSize = UDim2.new()
				options.AutomaticCanvasSize = Enum.AutomaticSize.X
				options.ScrollingDirection = Enum.ScrollingDirection.X
				options.ScrollBarThickness = 4
				options.ZIndex = 23
				local layout = Instance.new("UIListLayout")
				layout.FillDirection = Enum.FillDirection.Horizontal
				layout.Padding = UDim.new(0, 6)
				layout.SortOrder = Enum.SortOrder.LayoutOrder
				layout.Parent = options
				options.Parent = row
				local current = group.Get()
				for i, option in ipairs(group.Options) do
					tile(options, option, option.Value == current, i, function()
						group.Set(option.Value)
						refresh()
						if props.OnChange then
							props.OnChange()
						end
						draw()
					end)
				end
				row.Parent = body
			end
		end
		draw()
	end
	local button = Button.new({ Name = "Filter", Icon = "Funnel", Style = "secondary", Size = UDim2.fromOffset(size, size), Position = props.Position, AnchorPoint = props.AnchorPoint, ZIndex = props.ZIndex or 3, LayoutOrder = props.LayoutOrder, Parent = props.Parent, OnClick = open })
	dot = Instance.new("Frame")
	dot.Name = "Active"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -4, 0, 4)
	dot.Size = UDim2.fromOffset(14, 14)
	dot.BackgroundColor3 = Theme.Colors.Badge
	dot.ZIndex = button.Instance.ZIndex + 2
	Theme.round(dot)
	Theme.stroke(dot, Theme.Colors.Text, 2)
	dot.Parent = button.Instance
	refresh()
	return { Instance = button.Instance, Refresh = refresh }
end

return Filter
