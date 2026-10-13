--!strict
-- Inventory > Weapons (docs/weapon_shop_brief.txt part 5, minimum): every owned copy as a slot with its rarity
-- border, best first; the equipped one is marked. Tapping a copy equips it (Net "EquipWeapon"). The red trash
-- button sells a copy for Gold (Net "SellWeapon", owner 2026-10-13); Epic and better ask first.
--   InventoryPage.buildWeapons(page)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local WeaponRarities = require(ReplicatedStorage.GameSystem.Config.WeaponRarities)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local State = require(script.Parent.Parent.Parent.State)
local Notifier = require(script.Parent.Parent.Notifier)
local Kit = script.Parent.Parent.Kit
local Button = require(Kit.Button)
local Icons = require(Kit.Icons)
local Slot = require(Kit.Slot)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local InventoryPage = {}

local CELL = Vector2.new(150, 196)
local SLOT = 104
local CONFIRM_FROM = 4 -- Epic and better: "Sell?" first

type Entry = { uid: string, id: string, rarity: number }

local function sorted(): { Entry }
	local list = {}
	for uid, item in pairs(State.get("Weapons") or {}) do
		if Weapons.ById[item.id] then
			table.insert(list, { uid = uid, id = item.id, rarity = item.rarity })
		end
	end
	table.sort(list, function(a, b)
		if a.rarity ~= b.rarity then
			return a.rarity > b.rarity
		end
		local wa, wb = Weapons.ById[a.id], Weapons.ById[b.id]
		if wa.Zone ~= wb.Zone then
			return wa.Zone > wb.Zone
		end
		if a.id ~= b.id then
			return a.id < b.id
		end
		return a.uid < b.uid
	end)
	return list
end

function InventoryPage.buildWeapons(page: ScrollingFrame)
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(CELL.X, CELL.Y)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = page
	local busy = false

	local function rebuild()
		for _, child in ipairs(page:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local list = sorted()
		local equipped = State.get("EquippedWeapon")
		if #list == 0 then
			local empty = Instance.new("Frame")
			empty.BackgroundTransparency = 1
			empty.Size = UDim2.fromOffset(CELL.X * 3, CELL.Y)
			Icons.create("Sword", empty, { Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0) })
			Button.new({ Name = "OpenShop", Icon = "Shop", Style = "primary", Size = UDim2.fromOffset(150, Theme.TOUCH + 16), Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), Parent = empty, OnClick = function()
				Window.open("Shop", "Weapons")
			end })
			empty.Parent = page
			return
		end
		for index, entry in ipairs(list) do
			local weapon = Weapons.ById[entry.id]
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
			if entry.uid ~= equipped then
				-- sell: trash + its Gold value (the equipped weapon cannot be sold)
				local value = Weapons.sellValue(entry.id, entry.rarity)
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
				local _ = trash
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
				local list = Instance.new("UIListLayout")
				list.FillDirection = Enum.FillDirection.Horizontal
				list.VerticalAlignment = Enum.VerticalAlignment.Center
				list.Padding = UDim.new(0, 2)
				list.Parent = price
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
			cell.Parent = page
		end
	end
	rebuild()
	State.changed("Weapons", rebuild)
	State.changed("EquippedWeapon", rebuild)
end

return InventoryPage
