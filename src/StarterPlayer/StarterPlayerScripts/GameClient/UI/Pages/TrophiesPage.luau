--!strict
-- Inventory > Trophies (docs/enemies_npcs_pets_brief.txt Part B): the head trophies dropped by enemies, best value first,
-- each with its sale value and a Sell button; "Sell All" sells everything (asks once more first).
-- Value = 25 x enemy Gold x rarityMult x (1 + Trophy Value bonus) (Config/Enemies.trophyValue, the server pays the same).
--   TrophiesPage.build(page)
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
local Icons = require(Kit.Icons)
local Slot = require(Kit.Slot)
local Theme = require(Kit.Theme)

local TrophiesPage = {}

local CELL = Vector2.new(150, 238)
local SLOT = 96
local HEADER = 64
local STAT_KEYS = { "Attributes", "Rebirths", "RebirthUpgrades", "Weapons", "EquippedWeapon", "Pets", "EquippedPets", "Armor", "EquippedArmor", "Boosts" }
local CONFIRM_SECONDS = 3

type Entry = { uid: string, id: string, rarity: number, value: number }

local function trophyBonus(): number
	local data = {}
	for _, key in ipairs(STAT_KEYS) do
		data[key] = State.get(key)
	end
	local ok, out = pcall(Stats.compute, data, { now = os.time() })
	return if ok then out.TrophyValue or 0 else 0
end

local function sorted(): { Entry }
	local bonus = trophyBonus()
	local list = {}
	for uid, item in pairs(State.get("Trophies") or {}) do
		if typeof(item) == "table" and Enemies.ById[item.id] then
			table.insert(list, { uid = uid, id = item.id, rarity = item.rarity, value = Enemies.trophyValue(item.id, item.rarity, bonus) })
		end
	end
	table.sort(list, function(a, b)
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.uid < b.uid
	end)
	return list
end

function TrophiesPage.build(page: ScrollingFrame)
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
	local summary = Theme.text({ Name = "Summary", Text = "", TextSize = 22, Align = "Left", Wrapped = true, Size = UDim2.new(1, -250, 1, 0), Parent = header })
	local busy = false
	local confirmUntil = 0
	local sellAll = Button.new({ Name = "SellAll", Text = "Sell All", Icon = "Gold", Style = "go", Size = UDim2.fromOffset(230, Theme.TOUCH), Position = UDim2.new(1, 0, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = header })

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

	local function rebuild()
		for _, child in ipairs(grid:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local list = sorted()
		local total = 0
		for _, entry in ipairs(list) do
			total += entry.value
		end
		summary.Text = `Trophies: {#list} / {Enemies.TROPHY_STORAGE}   Total value: {Format.number(total)} Gold`
		sellAll.Instance.Visible = #list > 0
		if #list == 0 then
			local empty = Instance.new("Frame")
			empty.BackgroundTransparency = 1
			empty.Size = UDim2.fromOffset(CELL.X * 3, CELL.Y * 0.7)
			Icons.create("Trophy", empty, { Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0) })
			Theme.text({ Text = "No trophies yet. Enemies sometimes drop their head trophy; sell them here or at the Trophy Merchant.", TextSize = 20, Wrapped = true, Color = Theme.Colors.TextDim, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 86), Parent = empty })
			empty.Parent = grid
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
			Button.new({ Text = Format.number(entry.value), Icon = "Gold", Style = "secondary", Size = UDim2.new(1, -8, 0, Theme.TOUCH), Position = UDim2.new(0.5, 0, 1, -2), AnchorPoint = Vector2.new(0.5, 1), Parent = cell, OnClick = function()
				sell(entry.uid)
			end })
			cell.Parent = grid
		end
	end

	sellAll.Instance.Activated:Connect(function()
		if os.clock() < confirmUntil then
			confirmUntil = 0
			sellAll:SetText("Sell All")
			sell(nil)
		else
			confirmUntil = os.clock() + CONFIRM_SECONDS
			sellAll:SetText("Tap to confirm")
			task.delay(CONFIRM_SECONDS, function()
				if os.clock() >= confirmUntil then
					sellAll:SetText("Sell All")
				end
			end)
		end
	end)
	rebuild()
	State.changed("Trophies", rebuild)
	State.changed("EquippedPets", rebuild)
end

return TrophiesPage
