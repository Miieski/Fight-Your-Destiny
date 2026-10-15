--!strict
-- Inventory > Trophies (docs/enemies_npcs_pets_brief.txt Part B): the head trophies dropped by enemies, best value first,
-- each with its sale value and a Sell button; "Sell All" sells everything (asks once more first).
-- Value = 25 x enemy Gold x rarityMult x (1 + Trophy Value bonus) (Config/Enemies.trophyValue, the server pays the same).
-- Owner 2026-10-15: a funnel (rarity, zone) and select mode (Kit/SellBar, Net "SellTrophies") to sell many at once.
--   TrophiesPage.build(page, ctx)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enemies = require(ReplicatedStorage.GameSystem.Config.Enemies)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
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

local TrophiesPage = {}

local CELL = Vector2.new(150, 238)
local SLOT = 96
local HEADER = 64
local STAT_KEYS = { "Attributes", "Rebirths", "RebirthUpgrades", "Weapons", "EquippedWeapon", "Pets", "EquippedPets", "Armor", "EquippedArmor", "Boosts" }
local CONFIRM_SECONDS = 3

type Entry = { uid: string, id: string, rarity: number, value: number }

local filter = { rarity = 0, zone = 0 :: any } -- 0 = all
local zoneOptions: { { [string]: any } } = {}

local function trophyBonus(): number
	local data = {}
	for _, key in ipairs(STAT_KEYS) do
		data[key] = State.get(key)
	end
	local ok, out = pcall(Stats.compute, data, { now = os.time() })
	return if ok then out.TrophyValue or 0 else 0
end

-- The trophies that pass the filter (best value first), the zones the player has trophies from, and the count and
-- value of every trophy.
local function sorted(): ({ Entry }, { [string]: boolean }, number, number)
	local bonus = trophyBonus()
	local list, present, count, total = {}, {}, 0, 0
	for uid, item in pairs(State.get("Trophies") or {}) do
		local def = if typeof(item) == "table" then Enemies.ById[item.id] else nil
		if def then
			local value = Enemies.trophyValue(item.id, item.rarity, bonus)
			count += 1
			total += value
			present[def.ZoneId] = true
			if (filter.rarity == 0 or item.rarity == filter.rarity) and (filter.zone == 0 or def.ZoneId == filter.zone) then
				table.insert(list, { uid = uid, id = item.id, rarity = item.rarity, value = value })
			end
		end
	end
	table.sort(list, function(a, b)
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.uid < b.uid
	end)
	return list, present, count, total
end

function TrophiesPage.build(page: ScrollingFrame, ctx: any)
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, -8, 0, HEADER)
	header.LayoutOrder = 1
	header.Parent = page
	local headerList = Instance.new("UIListLayout")
	headerList.FillDirection = Enum.FillDirection.Horizontal
	headerList.VerticalAlignment = Enum.VerticalAlignment.Center
	headerList.Padding = UDim.new(0, 8)
	headerList.SortOrder = Enum.SortOrder.LayoutOrder
	headerList.Parent = header
	local rebuild: () -> ()
	-- rarity and zone behind one funnel (owner: "filters behind one icon")
	local funnel = Filter.button({ Parent = header, Frame = ctx.Frame, Groups = {
		{ Icon = "Star", Options = Filter.rarityOptions(), Get = function() return filter.rarity end, Set = function(v) filter.rarity = v end },
		{ Icon = "Zones", Options = zoneOptions, Get = function() return filter.zone end, Set = function(v) filter.zone = v end },
	}, OnChange = function()
		rebuild()
	end, Size = Theme.TOUCH, LayoutOrder = 1, ZIndex = 3 })
	-- trophy count and total value as pictures + numbers (kid-friendly UI)
	local countChip = Chips.chip(header, "Trophy", "0", { Height = 42, LayoutOrder = 2 })
	local valueChip = Chips.chip(header, "Gold", "0", { Height = 42, LayoutOrder = 3 })
	local busy = false
	local confirmUntil = 0
	local trophies = 0
	local sellAll = Button.new({ Name = "SellAll", Text = "All", Icon = "Gold", Style = "go", Size = UDim2.fromOffset(170, Theme.TOUCH), LayoutOrder = 20, Parent = header })
	-- select mode: "sell everything" makes room for the sell buttons
	local bar = SellBar.new({ Parent = header, LayoutOrder = 10, ZIndex = 3, Page = page, Request = "SellTrophies", Noun = { "trophy", "trophies" }, OnMode = function(on)
		sellAll.Instance.Visible = not on and trophies > 0
	end })

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, -8, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.LayoutOrder = 2
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(CELL.X, CELL.Y)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	grid.Parent = page

	local function sell(uid: string?)
		if busy then
			return
		end
		busy = true
		local called, ok, result
		if uid then
			called, ok, result = pcall(Net.request, "SellTrophy", uid)
		else
			called, ok, result = pcall(Net.request, "SellAllTrophies")
		end
		busy = false
		if called and ok and typeof(result) == "table" then
			Sfx.play("Purchase")
			local count = result.count or 1
			Notifier.push({ Kind = "reward", Text = `Sold {count} troph{if count == 1 then "y" else "ies"} for {Format.number(result.gold or 0)} Gold`, Icon = "Gold" })
		else
			Notifier.push({ Kind = "error", Text = if called and typeof(result) == "string" then result else "Could not sell" })
		end
	end

	rebuild = function()
		for _, child in ipairs(grid:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		layout.CellSize = UDim2.fromOffset(CELL.X, CELL.Y)
		local list, present, count, total = sorted()
		if filter.zone ~= 0 and not present[filter.zone] then
			filter.zone = 0 -- the last trophy of that zone is gone
			list, present, count, total = sorted()
		end
		trophies = count
		Filter.zoneOptions(zoneOptions, present)
		funnel.Refresh()
		countChip:Set(`{count}/{Enemies.TROPHY_STORAGE}`)
		valueChip:Set(Format.number(total))
		sellAll.Instance.Visible = count > 0 and not bar:IsOn()
		bar:Begin()
		if #list == 0 then
			local empty = Instance.new("Frame")
			empty.BackgroundTransparency = 1
			layout.CellSize = UDim2.fromOffset(CELL.X * 3, CELL.Y * 0.7)
			Icons.create("Trophy", empty, { Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0) })
			if count > 0 then
				Theme.text({ Text = "No trophy matches this filter.", TextSize = 20, Wrapped = true, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -20, 0, 52), Position = UDim2.new(0.5, 0, 0, 90), AnchorPoint = Vector2.new(0.5, 0), Parent = empty })
			end
			empty.Parent = grid
			bar:Finish()
			return
		end
		for index, entry in ipairs(list) do
			local def = Enemies.ById[entry.id]
			local rarity = Rarities.get(entry.rarity)
			local cell = Instance.new("Frame")
			cell.Name = entry.uid
			cell.BackgroundTransparency = 1
			cell.LayoutOrder = index
			local slot = Slot.new({ Name = "Slot", Size = SLOT, Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), Parent = cell })
			slot:Set({ Icon = "Trophy", Tier = entry.rarity })
			Theme.text({ Font = "Button", Text = `{def.Name} Head`, TextSize = 16, Wrapped = true, Size = UDim2.new(1, -4, 0, 36), Position = UDim2.fromOffset(2, SLOT + 8), Parent = cell })
			local tier = Theme.text({ Text = rarity.Name, TextSize = 15, Size = UDim2.new(1, -4, 0, 18), Position = UDim2.fromOffset(2, SLOT + 44), Parent = cell })
			Theme.paintRarity(tier, entry.rarity)
			local sellButton = Button.new({ Text = Format.number(entry.value), Icon = "Gold", Style = "secondary", Size = UDim2.new(1, -8, 0, Theme.TOUCH), Position = UDim2.new(0.5, 0, 1, -2), AnchorPoint = Vector2.new(0.5, 1), Parent = cell, OnClick = function()
				sell(entry.uid)
			end })
			bar:Attach(cell, { uid = entry.uid, value = entry.value, rarity = entry.rarity, hide = { sellButton.Instance }, ringAt = UDim2.new(0.5, -SLOT / 2 + 4, 0, 8) })
			cell.Parent = grid
		end
		bar:Finish()
	end

	sellAll.Instance.Activated:Connect(function()
		if os.clock() < confirmUntil then
			confirmUntil = 0
			sellAll:SetText("All")
			sell(nil)
		else
			confirmUntil = os.clock() + CONFIRM_SECONDS
			sellAll:SetText("OK?")
			task.delay(CONFIRM_SECONDS, function()
				if os.clock() >= confirmUntil then
					sellAll:SetText("All")
				end
			end)
		end
	end)
	rebuild()
	State.changed("Trophies", rebuild)
	State.changed("EquippedPets", rebuild)
	page:GetPropertyChangedSignal("Visible"):Connect(function()
		if not page.Visible then
			Overlay.close() -- another tab closes this tab's filter popup
		end
	end)
end

return TrophiesPage
