--!strict
-- The Index window (docs/menu_systems_brief.txt D3). Tabs Weapons / Armor / Pets / Enemies, grouped by zone
-- (Config/IndexBook). Undiscovered entries: black silhouette with "?" and no name. Discovered: 3D icon, name and
-- the best rarity owned as colored pips. Completion per tab and per zone, with claim buttons for the rewards
-- (2 + zone Diamonds per zone, 100 per tab; Net "ClaimIndexReward"). Each tab is built the first time it is shown
-- and rebuilt when the Index changes while it is visible.
--   IndexPage.build(ctx)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IndexBook = require(ReplicatedStorage.GameSystem.Config.IndexBook)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local State = require(script.Parent.Parent.Parent.State)
local Notifier = require(script.Parent.Parent.Notifier)
local Kit = script.Parent.Parent.Kit
local Button = require(Kit.Button)
local Icons = require(Kit.Icons)
local ModelIcon = require(Kit.ModelIcon)
local Theme = require(Kit.Theme)

local IndexPage = {}

local busy = false

local function claim(rewardId: string)
	if busy then
		return
	end
	busy = true
	local called, ok, result = pcall(Net.request, "ClaimIndexReward", rewardId)
	busy = false
	if called and ok then
		Sfx.play("Purchase")
		Notifier.push({ Kind = "reward", Text = `Index reward: +{result.diamonds} Diamonds`, Icon = "Diamond" })
	else
		Sfx.play("Denied")
		Notifier.push({ Kind = "error", Text = if called and typeof(result) == "string" then result else "Could not claim" })
	end
end

local function rewardButton(parent: Instance, reward: any, size: UDim2, position: UDim2, anchor: Vector2)
	local text, style
	if reward.Claimed then
		text, style = "Claimed", "disabled"
	elseif reward.Complete then
		text, style = `Claim {reward.Diamonds}`, "go"
	else
		text, style = `{reward.Diamonds}`, "disabled"
	end
	local button = Button.new({ Text = text, Icon = "Diamond", Style = style, TextSize = 20, Size = size, Position = position, AnchorPoint = anchor, ZIndex = 3, Parent = parent, OnClick = function()
		if reward.Complete and not reward.Claimed then
			claim(reward.Id)
		elseif not reward.Complete then
			Notifier.push({ Kind = "info", Text = `Find all {reward.Total} entries to claim {reward.Diamonds} Diamonds ({reward.Have}/{reward.Total})`, Icon = "Index" })
		end
	end })
	button.Instance.Name = "Claim"
end

local function percent(have: number, total: number): string
	return `{have}/{total} ({math.floor(have / math.max(total, 1) * 100)}%)`
end

local function pips(parent: Instance, best: number)
	local row = Instance.new("Frame")
	row.Name = "Pips"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -10, 0, 8)
	row.Position = UDim2.new(0.5, 0, 1, -6)
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.ZIndex = 4
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 2)
	list.Parent = row
	for tier = 1, #Rarities.List do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(8, 8)
		pip.BackgroundColor3 = if tier <= best then Rarities.get(tier).Color else Theme.Colors.WoodLine
		pip.BackgroundTransparency = if tier <= best then 0 else 0.3
		pip.ZIndex = 4
		Theme.round(pip)
		pip.Parent = row
	end
	row.Parent = parent
end

local function entryCell(entry: any, order: number, cell: Vector2): Frame
	local index = State.get("Index") or {}
	local best = IndexBook.best(index, entry.Id)
	local found = best ~= nil
	local frame = Instance.new("Frame")
	frame.Name = entry.Id
	frame.BackgroundColor3 = Theme.Colors.WoodInset
	frame.LayoutOrder = order
	frame.ZIndex = 3
	Theme.corner(frame, 6)
	local stroke = Theme.stroke(frame, Theme.Colors.GoldDark, 2)
	if found and best and best > 0 then
		Theme.paintRarity(stroke, best)
	end
	local iconSize = UDim2.new(1, -10, 1, -(if entry.Kind == "enemy" then 30 else 38))
	local iconPos = UDim2.new(0.5, 0, 0, 4)
	if entry.Kind == "pet" then
		ModelIcon.pet(entry.Id, { Size = iconSize, Position = iconPos, AnchorPoint = Vector2.new(0.5, 0), ZIndex = 4, Silhouette = not found, Parent = frame })
	elseif entry.Kind == "armor" then
		ModelIcon.armor(entry.Id, if found and best and best > 0 then best else 1, { Size = iconSize, Position = iconPos, AnchorPoint = Vector2.new(0.5, 0), ZIndex = 4, Silhouette = not found, Parent = frame })
	else
		local iconId = if entry.Kind == "weapon" then (Weapons.ById[entry.Id].Icon or Weapons.ById[entry.Id].Category) elseif entry.Role == "Boss" then "Crown" else "Skull"
		local icon = Icons.create(iconId, frame, { Size = iconSize, Position = iconPos, AnchorPoint = Vector2.new(0.5, 0), ZIndex = 4 })
		local image = icon:FindFirstChild("Image") :: ImageLabel?
		if image and not found then
			image.ImageColor3 = Color3.new(0, 0, 0)
		end
	end
	if not found then
		Theme.text({ Font = "Title", Text = "?", TextSize = 34, Size = UDim2.new(1, 0, 1, -30), Position = UDim2.fromOffset(0, 4), StrokeThickness = 2, ZIndex = 5, Parent = frame })
	end
	local name = Theme.text({ Font = "Button", Text = if found then entry.Name else "???", TextSize = 13, Wrapped = true, Size = UDim2.new(1, -6, 0, 18), Position = UDim2.new(0.5, 0, 1, if entry.Kind == "enemy" then -4 else -14), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 4, Parent = frame })
	if not found then
		name.TextColor3 = Theme.Colors.TextDim
	elseif entry.Role == "Boss" or entry.Role == "MiniBoss" then
		name.TextColor3 = if entry.Role == "Boss" then Theme.Colors.Gold else Theme.Colors.Bad
	end
	if entry.Kind ~= "enemy" then
		pips(frame, if found and best then best else 0)
	end
	return frame
end

local function buildTab(page: ScrollingFrame, tab: string)
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local small = Theme.isCompact()
	local index = State.get("Index") or {}
	local claimed = State.get("IndexClaimed") or {}
	local cell = if small then Vector2.new(84, 104) else Vector2.new(100, 124)
	-- tab summary
	local tabReward = IndexBook.reward(index, claimed, `{tab}:All`) :: any
	local summary = Instance.new("Frame")
	summary.Name = "Summary"
	summary.BackgroundColor3 = Theme.Colors.WoodTop
	summary.Size = UDim2.new(1, -8, 0, Theme.TOUCH + 12)
	summary.LayoutOrder = 0
	summary.ZIndex = 2
	Theme.corner(summary, 8)
	Theme.stroke(summary, Theme.Colors.GoldLight, 2)
	summary.Parent = page
	Theme.text({ Font = "Title", Text = `{tab}: {percent(tabReward.Have, tabReward.Total)}`, TextSize = if small then 22 else 28, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(0.5, 0, 0, 30), Position = UDim2.fromOffset(14, 6), ZIndex = 3, Parent = summary })
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Theme.Colors.WoodLine
	bar.Size = UDim2.new(0.5, -20, 0, 12)
	bar.Position = UDim2.new(0, 14, 1, -18)
	bar.ZIndex = 3
	Theme.corner(bar, 6)
	bar.Parent = summary
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Theme.Colors.Good
	fill.Size = UDim2.fromScale(tabReward.Have / math.max(tabReward.Total, 1), 1)
	fill.ZIndex = 4
	Theme.corner(fill, 6)
	fill.Parent = bar
	Theme.text({ Text = `Whole tab: {IndexBook.TabReward} Diamonds`, TextSize = 16, Color = Theme.Colors.TextDim, Align = "Right", Size = UDim2.new(0.25, 0, 0, 24), Position = UDim2.new(0.75, -16, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 3, Parent = summary })
	rewardButton(summary, tabReward, UDim2.new(0.24, 0, 0, Theme.TOUCH), UDim2.new(1, -8, 0.5, 0), Vector2.new(1, 0.5))

	-- zone groups
	for order, group in ipairs(IndexBook.Groups[tab]) do
		local section = Instance.new("Frame")
		section.Name = group.Key
		section.BackgroundColor3 = Theme.Colors.WoodTop
		section.BackgroundTransparency = 0.3
		section.Size = UDim2.new(1, -8, 0, 0)
		section.AutomaticSize = Enum.AutomaticSize.Y
		section.LayoutOrder = order
		section.ZIndex = 2
		Theme.corner(section, 8)
		Theme.stroke(section, Theme.Colors.GoldDark, 1.5)
		section.Parent = page
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 6)
		list.Parent = section
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 6)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.Parent = section
		local head = Instance.new("Frame")
		head.BackgroundTransparency = 1
		head.Size = UDim2.new(1, 0, 0, Theme.TOUCH)
		head.LayoutOrder = 0
		head.ZIndex = 3
		head.Parent = section
		if group.ZoneId then
			Icons.create(group.ZoneId, head, { Size = UDim2.fromOffset(38, 38), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 4 })
		else
			Icons.create("Crown", head, { Size = UDim2.fromOffset(38, 38), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 4 })
		end
		local have = IndexBook.count(index, group.Entries)
		Theme.text({ Font = "Title", Text = group.Name, TextSize = 24, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(0.4, -46, 1, 0), Position = UDim2.fromOffset(46, 0), ZIndex = 4, Parent = head })
		Theme.text({ Font = "Number", Text = percent(have, #group.Entries), TextSize = 18, Color = if have >= #group.Entries then Theme.Colors.Good else Theme.Colors.Text, Size = UDim2.new(0.28, 0, 1, 0), Position = UDim2.fromScale(0.4, 0), ZIndex = 4, Parent = head })
		if group.Rewarded then
			local reward = IndexBook.reward(index, claimed, `{tab}:{group.Key}`)
			if reward then
				rewardButton(head, reward, UDim2.new(0.28, 0, 1, 0), UDim2.new(1, 0, 0, 0), Vector2.new(1, 0))
			end
		else
			Theme.text({ Text = "Robux pets (no reward)", TextSize = 15, Color = Theme.Colors.TextDim, Align = "Right", Size = UDim2.new(0.3, 0, 1, 0), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), ZIndex = 4, Parent = head })
		end
		local grid = Instance.new("Frame")
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, 0, 0, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.LayoutOrder = 1
		grid.ZIndex = 3
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(cell.X, cell.Y)
		layout.CellPadding = UDim2.fromOffset(6, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		grid.Parent = section
		for i, entry in ipairs(group.Entries) do
			entryCell(entry, i, cell).Parent = grid
		end
	end
end

function IndexPage.build(ctx: any)
	local built: { [string]: boolean } = {}
	local dirty: { [string]: boolean } = {}
	for _, tab in ipairs(IndexBook.TABS) do
		local page = ctx.Pages[tab]
		local function show()
			if page.Visible and (not built[tab] or dirty[tab]) then
				built[tab] = true
				dirty[tab] = false
				local scroll = page.CanvasPosition
				buildTab(page, tab)
				page.CanvasPosition = scroll
			end
		end
		page:GetPropertyChangedSignal("Visible"):Connect(show)
		local function changed()
			dirty[tab] = true
			show()
		end
		State.changed("Index", changed)
		State.changed("IndexClaimed", changed)
		task.defer(show)
	end
end

return IndexPage
