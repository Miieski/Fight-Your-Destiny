--!strict
-- Inventory > Weapons (docs/weapon_shop_brief.txt part 5, minimum): every owned copy as a slot with its rarity
-- border, best first; the equipped one is marked. Tapping a copy equips it (Net "EquipWeapon"). The red trash
-- button sells a copy for Gold (Net "SellWeapon", owner 2026-10-13); Epic and better ask first.
-- Header (owner 2026-10-15: "create a filter and a select option to sell many items at the same time"): the funnel
-- (category, rarity, zone, sort), the weapon count, and select mode (Kit/SellBar, Net "SellWeapons"); the equipped
-- copy is never sold.
--   InventoryPage.buildWeapons(page, ctx)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local WeaponCategories = require(ReplicatedStorage.GameSystem.Config.WeaponCategories)
local WeaponRarities = require(ReplicatedStorage.GameSystem.Config.WeaponRarities)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local State = require(script.Parent.Parent.Parent.State)
local Notifier = require(script.Parent.Parent.Notifier)
local Kit = script.Parent.Parent.Kit
local Button = require(Kit.Button)
local Chips = require(Kit.Chips)
local Filter = require(Kit.Filter)
local Icons = require(Kit.Icons)
local Overlay = require(Kit.Overlay)
local SellBar = require(Kit.SellBar)
local Slot = require(Kit.Slot)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local InventoryPage = {}

local CELL = Vector2.new(150, 196)
local SLOT = 104
local CONFIRM_FROM = 4 -- Epic and better: "Sell?" first
local SORTS = { "Rarity", "Zone", "Damage" }

type Entry = { uid: string, id: string, rarity: number, weapon: any, dps: number }

-- category / zone 0 = all, rarity 0 = all, sort = index in SORTS
local filter = { category = "", rarity = 0, zone = 0 :: any, sort = 1 }
local zoneOptions: { { [string]: any } } = {}

local function filterGroups(): { any }
	local categories: { { [string]: any } } = { { Value = "", Text = "All" } }
	for _, category in ipairs(WeaponCategories.List) do
		table.insert(categories, { Value = category.Id, Icon = category.Id })
	end
	return {
		{ Icon = "Sword", Options = categories, Get = function() return filter.category end, Set = function(v) filter.category = v end },
		{ Icon = "Star", Options = Filter.rarityOptions(), Get = function() return filter.rarity end, Set = function(v) filter.rarity = v end },
		{ Icon = "Zones", Options = zoneOptions, Get = function() return filter.zone end, Set = function(v) filter.zone = v end },
		{ Icon = "Sort", Options = { { Value = 1, Icon = "Star" }, { Value = 2, Icon = "Zones" }, { Value = 3, Icon = "Attack" } }, Get = function() return filter.sort end, Set = function(v) filter.sort = v end },
	}
end

-- The owned copies that pass the filter, sorted; also the zones the player has weapons from and the total count.
local function sorted(): ({ Entry }, { [string]: boolean }, number)
	local list, present, total = {}, {}, 0
	for uid, item in pairs(State.get("Weapons") or {}) do
		local weapon = Weapons.ById[item.id]
		if weapon then
			total += 1
			present[weapon.ZoneId] = true
			if (filter.category == "" or weapon.Category == filter.category)
				and (filter.rarity == 0 or item.rarity == filter.rarity)
				and (filter.zone == 0 or weapon.ZoneId == filter.zone)
			then
				table.insert(list, { uid = uid, id = item.id, rarity = item.rarity, weapon = weapon, dps = Stats.weaponDps(item.id, item.rarity) })
			end
		end
	end
	local sort = SORTS[filter.sort]
	table.sort(list, function(a, b)
		if sort == "Zone" and a.weapon.Zone ~= b.weapon.Zone then
			return a.weapon.Zone > b.weapon.Zone
		elseif sort == "Damage" and a.dps ~= b.dps then
			return a.dps > b.dps
		end
		if a.rarity ~= b.rarity then
			return a.rarity > b.rarity
		end
		if a.weapon.Zone ~= b.weapon.Zone then
			return a.weapon.Zone > b.weapon.Zone
		end
		if a.id ~= b.id then
			return a.id < b.id
		end
		return a.uid < b.uid
	end)
	return list, present, total
end

function InventoryPage.buildWeapons(page: ScrollingFrame, ctx: any)
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
	page.ScrollingEnabled = false
	page.AutomaticCanvasSize = Enum.AutomaticSize.None
	page.CanvasSize = UDim2.new()
	page.ScrollBarThickness = 0

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, Theme.TOUCH)
	header.ZIndex = 2
	header.Parent = page
	local headerList = Instance.new("UIListLayout")
	headerList.FillDirection = Enum.FillDirection.Horizontal
	headerList.VerticalAlignment = Enum.VerticalAlignment.Center
	headerList.Padding = UDim.new(0, 8)
	headerList.SortOrder = Enum.SortOrder.LayoutOrder
	headerList.Parent = header

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(0, Theme.TOUCH + 8)
	grid.Size = UDim2.new(1, 0, 1, -(Theme.TOUCH + 8))
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = Theme.Colors.GoldLight
	grid.ZIndex = 2
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(CELL.X, CELL.Y)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = grid
	grid.Parent = page

	local busy = false
	local rebuild: () -> ()
	-- every filter and sort behind one funnel (owner: "filters behind one icon")
	local funnel = Filter.button({ Parent = header, Frame = ctx.Frame, Groups = filterGroups(), OnChange = function()
		rebuild()
	end, Size = Theme.TOUCH, LayoutOrder = 1, ZIndex = 3 })
	local countChip = Chips.chip(header, "Sword", "0", { Height = Theme.TOUCH - 8, LayoutOrder = 2, ZIndex = 3 })
	local bar = SellBar.new({ Parent = header, LayoutOrder = 10, ZIndex = 3, Page = page, Request = "SellWeapons", Noun = { "weapon", "weapons" } })

	rebuild = function()
		local scroll = grid.CanvasPosition
		for _, child in ipairs(grid:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		layout.CellSize = UDim2.fromOffset(CELL.X, CELL.Y)
		local list, present, total = sorted()
		if filter.zone ~= 0 and not present[filter.zone] then
			filter.zone = 0 -- the last weapon of that zone is gone
			list, present, total = sorted()
		end
		Filter.zoneOptions(zoneOptions, present)
		funnel.Refresh()
		countChip:Set(tostring(total))
		local equipped = State.get("EquippedWeapon")
		bar:Begin()
		if #list == 0 then
			layout.CellSize = UDim2.fromOffset(CELL.X * 3, CELL.Y)
			local empty = Instance.new("Frame")
			empty.BackgroundTransparency = 1
			Icons.create("Sword", empty, { Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0) })
			if total > 0 then
				Theme.text({ Text = "No weapon matches this filter.", TextSize = 20, Wrapped = true, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -20, 0, 52), Position = UDim2.new(0.5, 0, 0, 90), AnchorPoint = Vector2.new(0.5, 0), Parent = empty })
			else
				Button.new({ Name = "OpenShop", Icon = "Shop", Style = "primary", Size = UDim2.fromOffset(150, Theme.TOUCH + 16), Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), Parent = empty, OnClick = function()
					Window.open("Shop", "Weapons")
				end })
			end
			empty.Parent = grid
			bar:Finish()
			return
		end
		for index, entry in ipairs(list) do
			local weapon = entry.weapon
			local rarity = WeaponRarities.get(entry.rarity)
			local cell = Instance.new("Frame")
			cell.Name = entry.uid
			cell.BackgroundTransparency = 1
			cell.LayoutOrder = index
			local slot = Slot.new({ Name = "Slot", Size = SLOT, Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), Parent = cell, OnClick = function()
				if busy or entry.uid == State.get("EquippedWeapon") then
					return
				end
				busy = true
				local called, ok, message = pcall(Net.request, "EquipWeapon", entry.uid)
				busy = false
				if called and ok then
					Sfx.play("UIClick")
					Notifier.push({ Kind = "info", Text = `Equipped {rarity.Name} {weapon.Name}`, Icon = weapon.Icon or weapon.Category })
				else
					Notifier.push({ Kind = "error", Text = if called and typeof(message) == "string" then message else "Could not equip" })
				end
			end })
			slot:Set({ Icon = weapon.Icon or weapon.Category, Tier = entry.rarity })
			local name = Theme.text({ Font = "Button", Text = weapon.Name, TextSize = 17, Size = UDim2.new(1, -4, 0, 22), Position = UDim2.fromOffset(2, SLOT + 14), Parent = cell })
			local tier = Theme.text({ Text = rarity.Name, TextSize = 16, Size = UDim2.new(1, -4, 0, 20), Position = UDim2.fromOffset(2, SLOT + 38), Parent = cell })
			Theme.paintRarity(tier, entry.rarity)
			local value = Weapons.sellValue(entry.id, entry.rarity)
			local own: { GuiObject } = {} -- the copy's own sell buttons (hidden in select mode)
			if entry.uid ~= equipped then
				-- sell: trash + its Gold value (the equipped weapon cannot be sold)
				local function sell()
					if busy then
						return
					end
					busy = true
					local called, ok, result = pcall(Net.request, "SellWeapon", entry.uid)
					busy = false
					if called and ok then
						Sfx.play("Purchase")
						Notifier.push({ Kind = "reward", Text = `+{Format.number(result.gold)} Gold`, Icon = "Gold" })
					else
						Sfx.play("Denied")
						Notifier.push({ Kind = "error", Text = if called and typeof(result) == "string" then result else "Could not sell" })
					end
				end
				local trash = Button.new({ Name = "Sell", Icon = "Trash", Style = "danger", Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -2, 0, 2), AnchorPoint = Vector2.new(1, 0), ZIndex = 6, Depth = 3, Parent = cell, OnClick = function()
					if entry.rarity >= CONFIRM_FROM then
						Window.confirm({
							Title = "Sell?",
							Text = `Sell {rarity.Name} {weapon.Name} for {Format.number(value)} Gold?`,
							ConfirmText = "Sell",
							CancelText = "Keep",
							OnConfirm = sell,
						})
					else
						sell()
					end
				end })
				local price = Instance.new("Frame")
				price.Name = "SellValue"
				price.BackgroundColor3 = Theme.Colors.WoodLine
				price.BackgroundTransparency = 0.15
				price.AutomaticSize = Enum.AutomaticSize.X
				price.Size = UDim2.fromOffset(0, 22)
				price.Position = UDim2.new(1, -4, 0, 44)
				price.AnchorPoint = Vector2.new(1, 0)
				price.ZIndex = 6
				Theme.corner(price, 11)
				local list_ = Instance.new("UIListLayout")
				list_.FillDirection = Enum.FillDirection.Horizontal
				list_.VerticalAlignment = Enum.VerticalAlignment.Center
				list_.Padding = UDim.new(0, 2)
				list_.Parent = price
				local pad = Instance.new("UIPadding")
				pad.PaddingRight = UDim.new(0, 6)
				pad.Parent = price
				Icons.create("Gold", price, { Size = UDim2.fromOffset(20, 20), ZIndex = 7 })
				local label = Theme.text({ Font = "Number", Text = Format.number(value), TextSize = 14, Size = UDim2.fromOffset(0, 18), ZIndex = 7, Parent = price })
				label.AutomaticSize = Enum.AutomaticSize.X
				label.TextScaled = false
				label.TextSize = 14
				label.LayoutOrder = 2
				price.Parent = cell
				own = { trash.Instance, price }
			end
			if entry.uid == equipped then
				local badge = Instance.new("Frame")
				badge.BackgroundColor3 = Theme.Colors.Good
				badge.Size = UDim2.fromOffset(30, 30) -- a green check (kid-friendly UI)
				badge.Position = UDim2.new(0.5, 0, 0, 0)
				badge.AnchorPoint = Vector2.new(0.5, 0)
				badge.ZIndex = 4
				Theme.corner(badge, 15)
				Theme.stroke(badge, Theme.Colors.Ink, 1.5)
				Icons.create("Check", badge, { Size = UDim2.fromScale(0.8, 0.8), ZIndex = 5 })
				badge.Parent = cell
				name.TextColor3 = Theme.Colors.Gold
			end
			bar:Attach(cell, { uid = entry.uid, value = value, rarity = entry.rarity, blocked = if entry.uid == equipped then "The equipped weapon cannot be sold" else nil,
				hide = own, ringAt = UDim2.new(1, -38, 0, 6) })
			cell.Parent = grid
		end
		bar:Finish()
		grid.CanvasPosition = scroll
	end
	rebuild()
	State.changed("Weapons", rebuild)
	State.changed("EquippedWeapon", rebuild)
	page:GetPropertyChangedSignal("Visible"):Connect(function()
		if not page.Visible then
			Overlay.close() -- another tab closes this tab's filter popup
		end
	end)
end

return InventoryPage
