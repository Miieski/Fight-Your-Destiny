--!strict
-- HUD 6 + 8: menu buttons with red badges, in a grid MenuGrid.Columns wide filled row by row
-- (8 buttons -> 4 rows) at the vertical middle of the left edge, with bigger tiles on PC (PcTile). Entries marked Apart
-- in Config/UI Menu (Settings) are separate icon buttons right of the health bar. On phones the grid
-- lives in a pop-up opened by a single Menu button, with the Apart buttons beside that button.
-- Apart entries with PcCorner (Zones) become a wide button in the bottom-right corner on PC.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local Badges = require(script.Parent.Badges)
local Kit = script.Parent.Kit
local Button = require(Kit.Button)
local IconButton = require(Kit.IconButton)
local Panel = require(Kit.Panel)
local Screens = require(Kit.Screens)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local MenuBar = { Priority = 11 }

local GRID = UIConfig.MenuGrid
local MARGIN = 12 -- from the left edge of the screen
local SPACING = 8 -- between the health bar (or the Menu button) and the Apart buttons
local TOP = { Normal = 72, Compact = 66 } -- below the health bar
local POPUP_PADDING = 12

local column: Frame
local columnGrid: UIGridLayout
local gridCount = 0
local popup: Frame
local popupGrid: Frame
local toggle: any
local tiles: { any } = {}
local apart: { any } = {}
local apartLabels: { boolean } = {} -- Apart entries with ShowLabel keep their label (not on phones)
local corner: { [number]: any } = {} -- index in `apart` -> its wide bottom-right button (PC)
local CORNER = UIConfig.CornerButton
local counts: { [string]: number } = {}

local function updateToggleBadge()
	local total = 0
	for _, n in pairs(counts) do
		total += n
	end
	toggle.Badge:Set(total)
end

local function gridSize(count: number, tile: number, gap: number): Vector2
	local rows = math.ceil(count / GRID.Columns)
	return Vector2.new(GRID.Columns * tile + (GRID.Columns - 1) * gap, rows * tile + (rows - 1) * gap)
end

local function addGridLayout(parent: Instance): UIGridLayout
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(GRID.Tile, GRID.Tile)
	grid.CellPadding = UDim2.fromOffset(GRID.Gap, GRID.Gap)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.FillDirectionMaxCells = GRID.Columns
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = parent
	return grid
end

local function layout()
	local compact = Theme.isCompact()
	column.Visible = not compact
	toggle.Instance.Visible = compact
	if not compact then
		popup.Visible = false
	end
	for _, tile in ipairs(tiles) do
		tile.Instance.Parent = if compact then popupGrid else column
		tile:SetLabelVisible(not compact)
	end
	local pc = not Theme.isTouch()
	local tile = if pc then GRID.PcTile else GRID.Tile
	local gap = if pc then GRID.PcGap else GRID.Gap
	local size = gridSize(gridCount, tile, gap)
	columnGrid.CellSize = UDim2.fromOffset(tile, tile)
	columnGrid.CellPadding = UDim2.fromOffset(gap, gap)
	column.Size = UDim2.fromOffset(size.X, size.Y)
	-- vertical middle of the left edge, never above the spot under the health bar
	local top = math.max(TOP.Normal, math.floor((Theme.size().Y - size.Y) / 2))
	column.Position = UDim2.fromOffset(MARGIN, top)
	toggle.Instance.Position = UDim2.fromOffset(MARGIN, TOP.Compact)
	-- Apart buttons: a column right of the health bar (the first one centered on it), or right of the
	-- Menu button on phones
	local health = UIConfig.Hud.Health
	local x = if compact then MARGIN + GRID.Tile + SPACING else MARGIN + health.Normal.X + SPACING
	local y = if compact then TOP.Compact else health.Top + (health.Normal.Y - GRID.Tile) / 2
	for index, button in ipairs(apart) do
		local wide = corner[index]
		local inCorner = wide ~= nil and pc and not compact
		button.Instance.Visible = not inCorner
		if wide then
			wide.Instance.Visible = inCorner
		end
		if not inCorner then
			button.Instance.Position = UDim2.fromOffset(x, y)
			button:SetLabelVisible(apartLabels[index] and not compact)
			y += GRID.Tile + SPACING
		end
	end
	popup.Position = UDim2.fromOffset(if compact then x + GRID.Tile + SPACING else MARGIN, TOP.Compact)
end

function MenuBar:Start()
	local root = Screens.hud()
	for _, entry in ipairs(UIConfig.Menu) do
		if not entry.Apart then
			gridCount += 1
		end
	end
	local size = gridSize(gridCount, GRID.Tile, GRID.Gap) -- the phone pop-up; the side grid is sized in layout()

	column = Instance.new("Frame")
	column.Name = "Menu"
	column.BackgroundTransparency = 1
	columnGrid = addGridLayout(column)
	column.Parent = root

	popup = Panel.new({ Name = "MenuPopup", Size = UDim2.fromOffset(size.X + 2 * POPUP_PADDING, size.Y + 2 * POPUP_PADDING), Parent = root })
	popup.Visible = false
	popupGrid = Instance.new("Frame")
	popupGrid.Name = "Grid"
	popupGrid.BackgroundTransparency = 1
	popupGrid.Position = UDim2.fromOffset(POPUP_PADDING, POPUP_PADDING)
	popupGrid.Size = UDim2.fromOffset(size.X, size.Y)
	addGridLayout(popupGrid)
	popupGrid.Parent = popup

	toggle = IconButton.new({ Name = "MenuToggle", Icon = "Menu", Label = "Menu", Size = Vector2.new(GRID.Tile, GRID.Tile), ShowLabel = false, Parent = root, OnClick = function()
		popup.Visible = not popup.Visible
	end })

	for index, entry in ipairs(UIConfig.Menu) do
		local button = IconButton.new({
			Name = entry.Id,
			Icon = entry.Icon,
			Label = entry.Label,
			Size = Vector2.new(GRID.Tile, GRID.Tile),
			ShowLabel = not entry.Apart or entry.ShowLabel == true,
			LayoutOrder = index,
			Parent = if entry.Apart then root else column,
			OnClick = function()
				popup.Visible = false
				Window.toggle(entry.Id)
			end,
		})
		table.insert(if entry.Apart then apart else tiles, button)
		if entry.Apart then
			table.insert(apartLabels, entry.ShowLabel == true)
		end
		if entry.Apart and entry.PcCorner then
			-- wide wooden button: big icon on the left, the name on the right
			local wide = Button.new({
				Name = entry.Id .. "Corner",
				Text = entry.Label,
				Icon = entry.Icon,
				Style = "wood",
				TextSize = CORNER.TextSize,
				Depth = 6,
				Size = UDim2.fromOffset(CORNER.Size.X, CORNER.Size.Y),
				Position = UDim2.new(1, -CORNER.Margin, 1, -CORNER.Margin),
				AnchorPoint = Vector2.new(1, 1),
				Parent = root,
				OnClick = function()
					popup.Visible = false
					Window.toggle(entry.Id)
				end,
			})
			local icon = wide.Face:FindFirstChild("Icon") :: Frame?
			if icon then
				icon.Size = UDim2.fromScale(0.92, 0.92) -- the holder is sized on the button's height (RelativeYY)
				icon.Position = UDim2.new(0, 6, 0.5, 0)
			end
			wide.Label.Size = UDim2.new(1, -(CORNER.Size.Y + 10), 0.7, 0)
			wide.Label.Position = UDim2.new(0, CORNER.Size.Y + 2, 0.5, 0)
			wide.Instance.Visible = false
			corner[#apart] = wide
		end
		Badges.watch(entry.Id, function(count)
			button.Badge:Set(count)
			-- the Menu button sums the badges hidden in its pop-up only
			if not entry.Apart then
				counts[entry.Id] = count
				updateToggleBadge()
			end
		end)
	end
	layout()
	Theme.Changed:Connect(layout)
	Window.Opened:Connect(function()
		popup.Visible = false
	end)
end

return MenuBar
