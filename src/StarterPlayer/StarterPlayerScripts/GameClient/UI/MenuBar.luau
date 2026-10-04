--!strict
-- HUD 6 + 8: menu buttons with red badges. Left column on PC, two columns on touch tablets
-- (clear of the joystick), and a single Menu button with a pop-up grid on phones.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local Badges = require(script.Parent.Badges)
local Kit = script.Parent.Kit
local IconButton = require(Kit.IconButton)
local Panel = require(Kit.Panel)
local Screens = require(Kit.Screens)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local MenuBar = { Priority = 11 }

local TILE = 58
local GAP = 5
local TOP = { Normal = 72, Compact = 66 } -- below the health bar
local POPUP_COLUMNS = 3
local BOTTOM_MARGIN = 12

local column: Frame
local grid: UIGridLayout
local popup: Frame
local popupGrid: Frame
local toggle: any
local tiles: { any } = {}
local counts: { [string]: number } = {}

local function updateToggleBadge()
	local total = 0
	for _, n in pairs(counts) do
		total += n
	end
	toggle.Badge:Set(total)
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
	local oneColumn = #tiles * TILE + (#tiles - 1) * GAP
	local columns = if Theme.isTouch() or TOP.Normal + oneColumn + BOTTOM_MARGIN > Theme.size().Y then 2 else 1
	local rows = math.ceil(#tiles / columns)
	grid.FillDirectionMaxCells = rows
	column.Size = UDim2.fromOffset(columns * TILE + (columns - 1) * GAP, rows * TILE + (rows - 1) * GAP)
	column.Position = UDim2.fromOffset(12, TOP.Normal)
	toggle.Instance.Position = UDim2.fromOffset(12, TOP.Compact)
	popup.Position = UDim2.fromOffset(12 + TILE + 10, TOP.Compact)
end

function MenuBar:Start()
	local root = Screens.hud()
	column = Instance.new("Frame")
	column.Name = "Menu"
	column.BackgroundTransparency = 1
	grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(TILE, TILE)
	grid.CellPadding = UDim2.fromOffset(GAP, GAP)
	grid.FillDirection = Enum.FillDirection.Vertical
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = column
	column.Parent = root

	local cells = math.ceil(#UIConfig.Menu / POPUP_COLUMNS)
	popup = Panel.new({ Name = "MenuPopup", Size = UDim2.fromOffset(POPUP_COLUMNS * (TILE + GAP) + 18, cells * (TILE + GAP) + 18), Parent = root })
	popup.Visible = false
	popupGrid = Instance.new("Frame")
	popupGrid.BackgroundTransparency = 1
	popupGrid.Position = UDim2.fromOffset(12, 12)
	popupGrid.Size = UDim2.new(1, -18, 1, -18)
	local popupLayout = Instance.new("UIGridLayout")
	popupLayout.CellSize = UDim2.fromOffset(TILE, TILE)
	popupLayout.CellPadding = UDim2.fromOffset(GAP, GAP)
	popupLayout.SortOrder = Enum.SortOrder.LayoutOrder
	popupLayout.Parent = popupGrid
	popupGrid.Parent = popup

	toggle = IconButton.new({ Name = "MenuToggle", Icon = "Menu", Label = "Menu", Size = Vector2.new(TILE, TILE), ShowLabel = false, Parent = root, OnClick = function()
		popup.Visible = not popup.Visible
	end })

	for index, entry in ipairs(UIConfig.Menu) do
		local tile = IconButton.new({ Name = entry.Id, Icon = entry.Icon, Label = entry.Label, Size = Vector2.new(TILE, TILE), LayoutOrder = index, Parent = column, OnClick = function()
			popup.Visible = false
			Window.toggle(entry.Id)
		end })
		table.insert(tiles, tile)
		Badges.watch(entry.Id, function(count)
			tile.Badge:Set(count)
			counts[entry.Id] = count
			updateToggleBadge()
		end)
	end
	layout()
	Theme.Changed:Connect(layout)
	Window.Opened:Connect(function()
		popup.Visible = false
	end)
end

return MenuBar
