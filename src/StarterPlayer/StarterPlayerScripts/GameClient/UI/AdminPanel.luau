--!strict
-- Owner tools (DESIGN.md section 13): money, teleports and the UI test commands of
-- docs/ui_hud_brief.txt (notify, equip fakes, damage, badges). Opened with F2 or the crown button,
-- built only when the server flags IsAdmin; the server re-checks every command.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Admins = require(ReplicatedStorage.GameSystem.Config.Admins)
local Economy = require(ReplicatedStorage.GameSystem.Config.Economy)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local Notifier = require(script.Parent.Notifier)
local State = require(script.Parent.Parent.State)
local Kit = script.Parent.Kit
local Button = require(Kit.Button)
local IconButton = require(Kit.IconButton)
local Screens = require(Kit.Screens)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local AdminPanel = { Priority = 13 }

local CELL = Vector2.new(150, 56)
local TOP = { Normal = 146, Compact = 130 } -- under the currency bars (right) / under the Menu button (left, phones)

local function send(command: string, ...: any)
	local ok, message = Net.request("Admin", command, ...)
	if message then
		Notifier.push({ Kind = if ok then "info" else "error", Text = "Admin: " .. tostring(message) })
	end
end

local function currentZone(): string
	local zoneId = Players.LocalPlayer:GetAttribute("CurrentZone")
	return if Zones.ById[zoneId or ""] then zoneId else "Plains"
end

local sectionCount = 0
local function section(page: Instance, title: string, cell: Vector2?): Frame
	sectionCount += 1
	Theme.text({ Font = "Title", Text = title, TextSize = 26, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(1, 0, 0, 32), LayoutOrder = sectionCount * 2 - 1, Parent = page })
	local grid = Instance.new("Frame")
	grid.Name = title
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.LayoutOrder = sectionCount * 2
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset((cell or CELL).X, (cell or CELL).Y)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	grid.Parent = page
	return grid
end

local function button(parent: Instance, text: string, style: string?, onClick: () -> ())
	return Button.new({ Text = text, Style = style or "secondary", TextSize = 20, Size = UDim2.fromScale(1, 1), Parent = parent, OnClick = onClick })
end

local function amountBox(parent: Instance): TextBox
	local box = Instance.new("TextBox")
	box.Name = "Amount"
	box.Text = ""
	box.PlaceholderText = "2500, 2.5M, 1T..."
	box.ClearTextOnFocus = false
	box.BackgroundColor3 = Theme.Colors.WoodLine
	box.TextColor3 = Theme.Colors.Text
	box.PlaceholderColor3 = Theme.Colors.TextDim
	box.FontFace = Theme.Fonts.Body
	box.TextScaled = true
	Theme.limit(box, 20)
	Theme.corner(box, 6)
	Theme.stroke(box, Theme.Colors.GoldDark, 2)
	box.Parent = parent
	return box
end

local function moneyPage(page: Instance)
	for _, money in ipairs({ { "Gold", "Gold", { 1e3, 1e6, 1e9, 1e12 } }, { "Diamonds", "Diamonds", { 10, 100, 1000 } } }) do
		local name, suffix, presets = money[1], money[2], money[3]
		local grid = section(page, name)
		for _, value in ipairs(presets) do
			button(grid, "+" .. Format.number(value), "primary", function()
				send("add" .. suffix, value)
			end)
		end
		button(grid, "Set 0", "danger", function()
			send("set" .. suffix, 0)
		end)
		local box = amountBox(grid)
		local function custom(command: string)
			local value = Format.parse(box.Text)
			if value and value <= Admins.MaxAmount then
				send(command .. suffix, value)
			else
				Notifier.push({ Kind = "error", Text = "Enter an amount like 2500, 2.5M or 1T" })
			end
		end
		button(grid, "Add", "primary", function() custom("add") end)
		button(grid, "Set", "secondary", function() custom("set") end)
	end
end

local function teleportPage(page: Instance)
	local target = 1
	local picker = section(page, "Where in the zone", Vector2.new(100, 56))
	local choices = {}
	for index, label in ipairs({ "1", "2", "3", "4", "Boss" }) do
		choices[index] = button(picker, label, "secondary", function()
			target = index
			for i, choice in ipairs(choices) do
				choice:SetStyle(if i == index then "primary" else "secondary")
			end
		end)
	end
	choices[1]:SetStyle("primary")
	local zones = section(page, "Zones")
	for _, zone in ipairs(Zones.List) do
		button(zones, zone.Name, "wood", function()
			send("setZone", zone.Id, target)
		end)
	end
	local world = section(page, "World")
	button(world, "Hub", "primary", function() send("setZone", "Hub") end)
	button(world, "Unlock all gates", "secondary", function() send("unlockAll") end)
end

local function testPage(page: Instance)
	local notes = section(page, "Notifications")
	local tests = {
		{ "Loot: Rare", { "loot", "Obtained Rare Wolf Pup Egg", 3 } },
		{ "Loot: Legendary", { "loot", "Obtained Legendary Golem Core Gauntlets", 5 } },
		{ "Loot: Divine", { "loot", "Obtained Divine Supreme Angel's Halo", 7 } },
		{ "Loot: Secret", { "loot", "Obtained Secret Void Dragon Egg", 8 } },
		{ "Reward", { "reward", "Daily reward claimed: +500 Gold" } },
		{ "No Gold", { "error", "Not enough Gold: 3,125 needed" } },
		{ "No Diamonds", { "error", "Not enough Diamonds: 50 needed" } },
		{ "Info", { "info", "Welcome to Fight Your Destiny!" } },
	}
	for _, test in ipairs(tests) do
		button(notes, test[1], "secondary", function()
			send("notify", table.unpack(test[2]))
		end)
	end
	button(notes, "Die (penalty)", "danger", function() send("damageSelf", 1e9) end)

	local health = section(page, "Health")
	button(health, "Damage 10", "secondary", function() send("damageSelf", 10) end)
	button(health, "Damage 40", "secondary", function() send("damageSelf", 40) end)
	button(health, "Heal", "primary", function() send("heal") end)

	local gear = section(page, "Equipment (current zone)", Vector2.new(110, 56))
	local categoryIndex = 0
	for _, rarity in ipairs(Rarities.List) do
		button(gear, rarity.Name, "secondary", function()
			categoryIndex = categoryIndex % #Weapons.Categories + 1
			send("equipWeaponFake", currentZone(), rarity.Tier, Weapons.Categories[categoryIndex].Id)
		end)
	end
	for _, slot in ipairs(Economy.ArmorSlots) do
		button(gear, slot, "secondary", function()
			send("equipArmorFake", slot, currentZone(), math.random(1, #Rarities.List))
		end)
	end
	for index = 1, Economy.PetSlots do
		button(gear, "Pet " .. index, "secondary", function()
			send("equipPetFake", index, math.random(1, #Rarities.List))
		end)
	end
	button(gear, "Clear", "danger", function() send("clearEquipment") end)

	local badges = section(page, "Badges")
	local counts: { [string]: number } = {}
	for _, id in ipairs(UIConfig.BadgeIds) do
		button(badges, id .. " +1", "secondary", function()
			counts[id] = (counts[id] or 0) + 1
			send("setBadge", id, counts[id])
		end)
	end
	button(badges, "Clear badges", "danger", function()
		for _, id in ipairs(UIConfig.BadgeIds) do
			counts[id] = 0
			send("setBadge", id, 0)
		end
	end)
end

-- Weapon shop tests (docs/weapon_shop_brief.txt): forced rarity, pity, reset, zone locks.
local function weaponsPage(page: Instance)
	local force = section(page, "Next purchase rarity", Vector2.new(110, 56))
	for _, rarity in ipairs(Rarities.List) do
		button(force, rarity.Name, "secondary", function()
			send("forceRarity", rarity.Tier)
		end)
	end
	button(force, "Normal", "primary", function()
		send("forceRarity", 0)
	end)
	local pity = section(page, "Pity counters (Epic 30 / Legendary 100)", Vector2.new(110, 56))
	for _, n in ipairs({ 0, 29, 30, 99, 100 }) do
		button(pity, `Pity {n}`, "secondary", function()
			send("setPity", n)
		end)
	end
	local tools = section(page, "Weapons & Gold")
	button(tools, "Reset weapons", "danger", function()
		send("resetWeapons")
	end)
	button(tools, "Gold +1T", "primary", function()
		send("addGold", 1e12)
	end)
	button(tools, "Gold = 0", "danger", function()
		send("setGold", 0)
	end)
	local zones = section(page, "Zones (tap to lock / unlock)")
	local zoneButtons = {}
	for index, zone in ipairs(Zones.List) do
		if index > 1 then
			zoneButtons[zone.Id] = button(zones, zone.Name, "secondary", function()
				local open = (State.get("Zones") or {})[zone.Id]
				send(if open then "lockZone" else "unlockZone", zone.Id)
			end)
		end
	end
	State.observe("Zones", function(open)
		for zoneId, zoneButton in pairs(zoneButtons) do
			local isOpen = (open or {})[zoneId] == true
			zoneButton:SetStyle(if isOpen then "go" else "secondary")
			zoneButton:SetText(`{Zones.ById[zoneId].Name}: {if isOpen then "open" else "locked"}`)
		end
	end)
end

local function build()
	local def = UIConfig.Windows.Admin
	Window.define("Admin", { Title = def.Title, Tabs = def.Tabs, Size = def.Size, Build = function(ctx)
		moneyPage(ctx.Pages.Money)
		teleportPage(ctx.Pages.Teleport)
		testPage(ctx.Pages["UI Test"])
		weaponsPage(ctx.Pages.Weapons)
	end })
	local crown = IconButton.new({ Name = "AdminToggle", Icon = "Admin", Label = "Admin", Size = Vector2.new(Theme.TOUCH, Theme.TOUCH), ShowLabel = false, AnchorPoint = Vector2.new(1, 0), Parent = Screens.hud(), OnClick = function()
		Window.toggle("Admin")
	end })
	local function layout()
		if Theme.isCompact() then
			crown.Instance.AnchorPoint = Vector2.zero
			crown.Instance.Position = UDim2.fromOffset(12, TOP.Compact)
		else
			crown.Instance.AnchorPoint = Vector2.new(1, 0)
			crown.Instance.Position = UDim2.new(1, -12, 0, TOP.Normal)
		end
	end
	layout()
	Theme.Changed:Connect(layout)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F2 then
			Window.toggle("Admin")
		end
	end)
end

function AdminPanel:Start()
	local player = Players.LocalPlayer
	if player:GetAttribute("IsAdmin") == nil then
		player:GetAttributeChangedSignal("IsAdmin"):Wait()
	end
	if player:GetAttribute("IsAdmin") then
		build()
	end
end

return AdminPanel
