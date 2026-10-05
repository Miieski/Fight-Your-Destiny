--!strict
-- Inventory > Weapons (docs/weapon_shop_brief.txt part 5, minimum): every owned copy as a slot with its rarity
-- border, best first; the equipped one is marked. Tapping a copy equips it (Net "EquipWeapon").
--   InventoryPage.buildWeapons(page)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
			Theme.text({ Text = "No weapons yet", TextSize = 24, Color = Theme.Colors.TextDim, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 86), Parent = empty })
			Button.new({ Text = "Open the Shop", Icon = "Shop", Style = "primary", Size = UDim2.fromOffset(230, Theme.TOUCH), Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), Parent = empty, OnClick = function()
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
			if entry.uid == equipped then
				local badge = Instance.new("Frame")
				badge.BackgroundColor3 = Theme.Colors.Good
				badge.Size = UDim2.fromOffset(92, 22)
				badge.Position = UDim2.new(0.5, 0, 0, 0)
				badge.AnchorPoint = Vector2.new(0.5, 0)
				badge.ZIndex = 4
				Theme.corner(badge, 11)
				Theme.stroke(badge, Theme.Colors.Ink, 1.5)
				Theme.text({ Font = "Button", Text = "Equipped", TextSize = 15, Size = UDim2.new(1, -6, 1, -2), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5, Parent = badge })
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
