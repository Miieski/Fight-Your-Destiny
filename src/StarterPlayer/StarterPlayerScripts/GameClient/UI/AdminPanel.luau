--!strict
-- Owner tools V2 (DESIGN.md section 13; owner 2026-10-13: "I want to test every possibility in game"). 8 tabs:
--   Resources  Gold, Diamonds, Rebirth Credits, boss keys, boosts, game passes
--   Weapons    give any weapon (zone x category x rarity), a zone's 7, all 84; shop: next rarity, pity, reset
--   Armor      give a piece / a set (zone x slot x rarity x count), every set, clear
--   Pets       give any pet (zone / premium x species x rarity x mutation x size x items), a zone's pets, eggs,
--              new items for every pet, clear, extra slots, egg simulation
--   Stats      points per attribute, all at once, Rebirths, Rebirth ready / wipe, Rebirth Shop upgrades, tests
--   World      teleports, zone locks, enemies (spawn, loot, trophies, kill simulation, kill all), health, god mode
--   Rewards    quests, play time, daily streak, Index, quest simulation
--   Tests      notifications, badges, fake equipment, checks, save, reset to a new player
-- Pickers are rows of buttons (the chosen one is gold); live lines show the current values. Opened with F2 or the
-- crown button, built only when the server flags IsAdmin; the server re-checks every command (AdminService).
-- An owner-only tool: plain text labels (the kid-friendly rules of the game UI do not apply here).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Admins = require(ReplicatedStorage.GameSystem.Config.Admins)
local Armor = require(ReplicatedStorage.GameSystem.Config.Armor)
local Attributes = require(ReplicatedStorage.GameSystem.Config.Attributes)
local Economy = require(ReplicatedStorage.GameSystem.Config.Economy)
local Enemies = require(ReplicatedStorage.GameSystem.Config.Enemies)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local PetMutations = require(ReplicatedStorage.GameSystem.Config.PetMutations)
local PetRarities = require(ReplicatedStorage.GameSystem.Config.PetRarities)
local Pets = require(ReplicatedStorage.GameSystem.Config.Pets)
local Products = require(ReplicatedStorage.GameSystem.Config.Products)
local Quests = require(ReplicatedStorage.GameSystem.Config.Quests)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local RebirthShop = require(ReplicatedStorage.GameSystem.Config.RebirthShop)
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

local CELL = Vector2.new(150, 52)
local SMALL = Vector2.new(104, 46)
local TOP = { Normal = 146, Compact = 130 } -- under the currency bars (right) / under the Menu button (left, phones)
local REQUEST_GAP = 0.07 -- the server takes one Admin request every 0.05 s

type Option = { Label: string, Value: any }
type Picker = { get: () -> any, set: (index: number) -> (), rebuild: (options: { Option }) -> () }

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
local function send(command: string, ...: any): boolean
	local called, ok, message = pcall(Net.request, "Admin", command, ...)
	if not called then
		Notifier.push({ Kind = "error", Text = "Admin: " .. tostring(ok) })
		return false
	end
	if message then
		Notifier.push({ Kind = if ok then "info" else "error", Text = "Admin: " .. tostring(message) })
	end
	return ok == true
end

-- the same command several times (the server's rate limit is respected)
local function repeatSend(times: number, command: string, ...: any)
	local args = table.pack(...)
	task.spawn(function()
		for _ = 1, times do
			send(command, table.unpack(args, 1, args.n))
			task.wait(REQUEST_GAP)
		end
	end)
end

local function currentZone(): string
	local zoneId = Players.LocalPlayer:GetAttribute("CurrentZone")
	return if Zones.ById[zoneId or ""] then zoneId else "Plains"
end

local function count(map: any): number
	local n = 0
	for _ in pairs(if typeof(map) == "table" then map else {}) do
		n += 1
	end
	return n
end

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function heading(page: Instance, title: string)
	Theme.text({ Font = "Title", Text = title, TextSize = 26, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(1, -8, 0, 32), LayoutOrder = nextOrder(), Parent = page })
end

local function grid(page: Instance, cell: Vector2?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, -8, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = nextOrder()
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset((cell or CELL).X, (cell or CELL).Y)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	frame.Parent = page
	return frame
end

local function section(page: Instance, title: string, cell: Vector2?): Frame
	heading(page, title)
	return grid(page, cell)
end

local function button(parent: Instance, text: string, style: string?, onClick: () -> ()): any
	return Button.new({ Text = text, Style = style or "secondary", TextSize = 22, Size = UDim2.fromScale(1, 1), Parent = parent, OnClick = onClick })
end

-- a small label line ("Gold 1.2M   Diamonds 50") refreshed when the given State keys change
local function liveLine(page: Instance, keys: { string }, text: () -> string)
	local label = Theme.text({ Font = "Number", Text = "", TextSize = 18, Color = Theme.Colors.TextDim, Align = "Left", Size = UDim2.new(1, -8, 0, 24), LayoutOrder = nextOrder(), Parent = page })
	local function refresh()
		label.Text = text()
	end
	for _, key in ipairs(keys) do
		State.changed(key, refresh)
	end
	refresh()
end

-- a row of choices; the chosen one is gold. onChange(value) after every choice.
local function picker(page: Instance, title: string, options: { Option }, cell: Vector2?, onChange: ((any) -> ())?): Picker
	Theme.text({ Font = "Button", Text = title, TextSize = 20, Color = Theme.Colors.Text, Align = "Left", Size = UDim2.new(1, -8, 0, 24), LayoutOrder = nextOrder(), Parent = page })
	local holder = grid(page, cell or SMALL)
	local current = 1
	local list: { Option } = options
	local buttons: { any } = {}
	local self: Picker
	local function paint()
		for i, b in ipairs(buttons) do
			b:SetStyle(if i == current then "primary" else "secondary")
		end
	end
	local function rebuild(newOptions: { Option })
		for _, b in ipairs(buttons) do
			b.Instance:Destroy()
		end
		table.clear(buttons)
		list = newOptions
		current = math.clamp(current, 1, math.max(#list, 1))
		for i, option in ipairs(list) do
			local b = button(holder, option.Label, "secondary", function()
				current = i
				paint()
				if onChange then
					onChange(list[i].Value)
				end
			end)
			b.Instance.LayoutOrder = i
			buttons[i] = b
		end
		paint()
	end
	self = {
		get = function()
			local option = list[current]
			return if option then option.Value else nil
		end,
		set = function(index: number)
			current = math.clamp(index, 1, math.max(#list, 1))
			paint()
		end,
		rebuild = rebuild,
	}
	rebuild(options)
	return self
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

local function confirm(title: string, text: string, onYes: () -> ())
	Window.confirm({ Title = title, Text = text, ConfirmText = "Yes", CancelText = "Cancel", OnConfirm = onYes })
end

-- option lists
local function rarityOptions(): { Option }
	local list = {}
	for _, rarity in ipairs(Rarities.List) do
		table.insert(list, { Label = rarity.Name, Value = rarity.Tier })
	end
	return list
end

local function zoneOptions(): { Option }
	local list = {}
	for _, zone in ipairs(Zones.List) do
		table.insert(list, { Label = `{zone.Index} {zone.Name}`, Value = zone.Id })
	end
	return list
end

----------------------------------------------------------------------------------------------------
-- Resources
----------------------------------------------------------------------------------------------------
local function resourcesPage(page: Instance)
	liveLine(page, { "Gold", "Diamonds", "RebirthCredits", "Keys", "Boosts" }, function()
		return `Gold {Format.number(State.get("Gold") or 0)}    Diamonds {Format.number(State.get("Diamonds") or 0)}    Rebirth Credits {State.get("RebirthCredits") or 0}    Keys {count(State.get("Keys"))}/12`
	end)
	for _, money in ipairs({ { "Gold", "Gold", Admins.GoldButtons }, { "Diamonds", "Diamonds", Admins.DiamondButtons } }) do
		local name, suffix, presets = money[1], money[2], money[3]
		local g = section(page, name)
		for _, value in ipairs(presets) do
			button(g, "+" .. Format.number(value), "primary", function()
				send("add" .. suffix, value)
			end)
		end
		button(g, "Set 0", "danger", function()
			send("set" .. suffix, 0)
		end)
		local box = amountBox(g)
		local function custom(command: string)
			local value = Format.parse(box.Text)
			if value and value <= Admins.MaxAmount then
				send(command .. suffix, value)
			else
				Notifier.push({ Kind = "error", Text = "Enter an amount like 2500, 2.5M or 1T" })
			end
		end
		button(g, "Add", "primary", function() custom("add") end)
		button(g, "Set", "secondary", function() custom("set") end)
	end

	local credits = section(page, "Rebirth Credits")
	for _, n in ipairs({ 3, 10, 100 }) do
		button(credits, `+{n}`, "primary", function()
			send("setCredits", math.min(1000, (State.get("RebirthCredits") or 0) + n))
		end)
	end
	button(credits, "Set 0", "danger", function() send("setCredits", 0) end)

	local keys = section(page, "Boss keys", SMALL)
	button(keys, "All 12", "primary", function() send("giveAllKeys") end)
	button(keys, "Clear", "danger", function() send("clearKeys") end)
	for _, zone in ipairs(Zones.List) do
		button(keys, `{zone.Index} {zone.Name}`, "wood", function() send("giveKey", zone.Index) end)
	end

	local boosts = section(page, "Gold Boost x2")
	for _, entry in ipairs({ { "+15 min", 900 }, { "+1 hour", 3600 }, { "+24 hours", 86400 } }) do
		button(boosts, entry[1], "primary", function() send("giveBoost", "GoldX2", entry[2]) end)
	end
	button(boosts, "Clear boosts", "danger", function() send("clearBoosts") end)

	local passes = section(page, "Game passes (tap = on / off)")
	local names = {}
	for name in pairs(Products.Passes) do
		table.insert(names, name)
	end
	table.sort(names)
	local passButtons = {}
	for _, name in ipairs(names) do
		passButtons[name] = button(passes, name, "secondary", function()
			local owned = (State.get("Passes") or {})[name] == true
			send("setPass", name, not owned)
		end)
	end
	State.observe("Passes", function(owned)
		for name, b in pairs(passButtons) do
			local on = (owned or {})[name] == true
			b:SetText(`{name}: {if on then "ON" else "off"}`)
			b:SetStyle(if on then "go" else "secondary")
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- Weapons
----------------------------------------------------------------------------------------------------
local function weaponsPage(page: Instance)
	liveLine(page, { "Weapons", "PityCounter", "PityLegendary" }, function()
		return `Weapons owned {count(State.get("Weapons"))}    Pity Epic {State.get("PityCounter") or 0}/30    Pity Legendary {State.get("PityLegendary") or 0}/100`
	end)
	heading(page, "Give a weapon")
	local zone = picker(page, "Zone", zoneOptions(), CELL)
	local categories = {}
	for _, category in ipairs(Weapons.Categories) do
		table.insert(categories, { Label = category.Name, Value = category.Id })
	end
	local category = picker(page, "Category", categories)
	local rarity = picker(page, "Rarity", rarityOptions())
	local give = grid(page)
	local function weaponId(): string
		return Weapons.idOf(zone.get(), category.get())
	end
	button(give, "Give 1", "go", function() send("giveWeapon", weaponId(), rarity.get()) end)
	button(give, "Give 5", "go", function() repeatSend(5, "giveWeapon", weaponId(), rarity.get()) end)
	button(give, "Zone's 7 weapons", "primary", function() send("giveWeapons", zone.get(), rarity.get()) end)
	button(give, "All 84 weapons", "primary", function() send("giveWeapons", "All", rarity.get()) end)
	button(give, "Every rarity (8)", "primary", function()
		task.spawn(function()
			for tier = 1, #Rarities.List do
				send("giveWeapon", weaponId(), tier)
				task.wait(REQUEST_GAP)
			end
		end)
	end)
	button(give, "Reset weapons", "danger", function()
		confirm("Reset weapons?", "Every weapon is removed, nothing equipped, pity counters back to 0.", function()
			send("resetWeapons")
		end)
	end)

	local force = section(page, "Shop: next purchase rarity", SMALL)
	for _, r in ipairs(Rarities.List) do
		button(force, r.Name, "secondary", function() send("forceRarity", r.Tier) end)
	end
	button(force, "Normal", "primary", function() send("forceRarity", 0) end)
	local pity = section(page, "Shop: pity counters (Epic 30 / Legendary 100)", SMALL)
	for _, n in ipairs({ 0, 29, 30, 99, 100 }) do
		button(pity, `Pity {n}`, "secondary", function() send("setPity", n) end)
	end
end

----------------------------------------------------------------------------------------------------
-- Armor
----------------------------------------------------------------------------------------------------
local function armorPage(page: Instance)
	liveLine(page, { "Armor", "EquippedArmor" }, function()
		return `Armor pieces {count(State.get("Armor"))}/{Armor.Storage}    Worn {count(State.get("EquippedArmor"))}/3`
	end)
	heading(page, "Give armor")
	local zone = picker(page, "Zone", zoneOptions(), CELL)
	local slots = { { Label = "Full set", Value = "Set" } }
	for _, slot in ipairs(Armor.SLOTS) do
		table.insert(slots, { Label = slot, Value = slot })
	end
	local slot = picker(page, "Piece", slots)
	local rarity = picker(page, "Rarity", rarityOptions())
	local amount = picker(page, "Count", { { Label = "x1", Value = 1 }, { Label = "x5", Value = 5 }, { Label = "x10", Value = 10 } })
	local give = grid(page)
	button(give, "Give", "go", function()
		local what = if slot.get() == "Set" then zone.get() else `{string.lower(zone.get())}_{string.lower(slot.get())}`
		send("giveArmor", what, rarity.get(), amount.get())
	end)
	button(give, "Sets of all 12 zones", "primary", function()
		task.spawn(function()
			for _, z in ipairs(Zones.List) do
				send("giveArmor", z.Id, rarity.get(), 1)
				task.wait(REQUEST_GAP)
			end
		end)
	end)
	button(give, "Every rarity (8)", "primary", function()
		task.spawn(function()
			for tier = 1, #Rarities.List do
				local what = if slot.get() == "Set" then zone.get() else `{string.lower(zone.get())}_{string.lower(slot.get())}`
				send("giveArmor", what, tier, 1)
				task.wait(REQUEST_GAP)
			end
		end)
	end)
	button(give, "Clear armor", "danger", function()
		confirm("Clear armor?", "Every armor piece is removed (worn ones too).", function()
			send("clearArmor")
		end)
	end)
end

----------------------------------------------------------------------------------------------------
-- Pets
----------------------------------------------------------------------------------------------------
local function petsPage(page: Instance)
	liveLine(page, { "Pets", "Eggs", "EquippedPets", "Passes" }, function()
		local passes = State.get("Passes") or {}
		local slots = PetRarities.Slots + (if passes.ExtraPetSlots then PetRarities.ExtraSlots else 0)
		return `Pets {count(State.get("Pets"))}/{PetRarities.PetStorage}    Eggs {count(State.get("Eggs"))}/{PetRarities.EggStorage}    Equipped {#(State.get("EquippedPets") or {})}/{slots}`
	end)
	heading(page, "Give a pet")
	local zones = zoneOptions()
	table.insert(zones, { Label = "Premium", Value = "Premium" })
	local species: Picker
	local function speciesOptions(zoneId: any): { Option }
		local list = {}
		for _, s in ipairs(Pets.List) do
			if (zoneId == "Premium" and s.Premium) or (not s.Premium and s.ZoneId == zoneId) then
				table.insert(list, { Label = s.Name, Value = s.Id })
			end
		end
		return list
	end
	local zone = picker(page, "Zone", zones, CELL, function(value)
		species.rebuild(speciesOptions(value))
	end)
	species = picker(page, "Pet", speciesOptions(zone.get()), CELL)
	local rarity = picker(page, "Rarity (premium pets keep theirs)", rarityOptions())
	local mutations = { { Label = "None", Value = "" } }
	for _, m in ipairs(PetMutations.List) do
		table.insert(mutations, { Label = m.Name, Value = m.Id })
	end
	local mutation = picker(page, "Mutation", mutations)
	local size = picker(page, "Size", { { Label = "Normal", Value = "" }, { Label = "Big", Value = "Big" }, { Label = "Huge", Value = "Huge" } })
	local items = { { Label = "Random", Value = 0 } }
	for _, r in ipairs(rarityOptions()) do
		table.insert(items, r)
	end
	local itemTier = picker(page, "Bonus Stats items (Crown, Accessory, Aura)", items)
	local function itemArg(): number?
		local v = itemTier.get()
		return if v and v > 0 then v else nil
	end
	local give = grid(page)
	button(give, "Give pet", "go", function()
		send("givePet", species.get(), rarity.get(), mutation.get(), size.get(), itemArg())
	end)
	button(give, "Give 5", "go", function()
		repeatSend(5, "givePet", species.get(), rarity.get(), mutation.get(), size.get(), itemArg())
	end)
	button(give, "Zone's pets", "primary", function() send("givePets", zone.get(), rarity.get(), itemArg()) end)
	button(give, "Every rarity (8)", "primary", function()
		task.spawn(function()
			for tier = 1, #Rarities.List do
				send("givePet", species.get(), tier, mutation.get(), size.get(), itemArg())
				task.wait(REQUEST_GAP)
			end
		end)
	end)
	button(give, "Every mutation", "primary", function()
		task.spawn(function()
			for _, option in ipairs(mutations) do
				send("givePet", species.get(), rarity.get(), option.Value, size.get(), itemArg())
				task.wait(REQUEST_GAP)
			end
		end)
	end)
	button(give, "Items 1..8 (8 pets)", "primary", function()
		task.spawn(function()
			for tier = 1, #Rarities.List do
				send("givePet", species.get(), rarity.get(), mutation.get(), size.get(), tier)
				task.wait(REQUEST_GAP)
			end
		end)
	end)

	local itemsTools = section(page, "Items of every owned pet (uses the items picker)")
	button(itemsTools, "New items", "primary", function() send("rerollItems", itemArg()) end)

	heading(page, "Eggs")
	local eggRarity = picker(page, "Egg rarity (zone = the pet zone above)", rarityOptions())
	local eggs = grid(page)
	for _, n in ipairs({ 1, 5, 30 }) do
		button(eggs, `Give {n} egg{if n == 1 then "" else "s"}`, "go", function()
			local z = zone.get()
			if z == "Premium" then
				Notifier.push({ Kind = "error", Text = "Premium eggs are bought in the shop: pick a zone" })
				return
			end
			send("giveEgg", z, eggRarity.get(), n)
		end)
	end

	local tools = section(page, "Tools")
	button(tools, "Equip best", "primary", function()
		pcall(Net.request, "EquipBestPets")
	end)
	button(tools, "Simulate 100K eggs", "secondary", function() send("simulateEggs", 100000) end)
	button(tools, "Clear pets + eggs", "danger", function()
		confirm("Clear pets?", "Every pet and egg is removed.", function()
			send("clearPets")
		end)
	end)
end

----------------------------------------------------------------------------------------------------
-- Stats
----------------------------------------------------------------------------------------------------
local function statsPage(page: Instance)
	heading(page, "Attribute points (0..40)")
	local labels: { [string]: any } = {}
	for _, attribute in ipairs(Attributes.List) do
		local row = grid(page, SMALL)
		labels[attribute.Id] = button(row, attribute.Name, "wood", function() end)
		for _, n in ipairs({ 0, 10, 20, 30, 40 }) do
			button(row, tostring(n), "secondary", function() send("setPoints", attribute.Id, n) end)
		end
	end
	State.observe("Attributes", function(values)
		for id, b in pairs(labels) do
			b:SetText(`{Attributes.ById[id].Name} {(values or {})[id] or 0}`)
		end
	end)
	local all = section(page, "Every attribute", SMALL)
	for _, n in ipairs({ 0, 10, 20, 30, 40 }) do
		button(all, `All {n}`, if n == 40 then "go" else "secondary", function() send("setAllPoints", n) end)
	end

	liveLine(page, { "Rebirths", "RebirthCredits" }, function()
		return `Rebirths {State.get("Rebirths") or 0}/12    Rebirth Credits {State.get("RebirthCredits") or 0}`
	end)
	local rebirths = section(page, "Rebirths", SMALL)
	for _, n in ipairs({ 0, 1, 2, 3, 6, 9, 12 }) do
		button(rebirths, `Set {n}`, "secondary", function() send("setRebirths", n) end)
	end
	local rebirthTools = section(page, "Rebirth tests")
	button(rebirthTools, "Rebirth ready", "go", function() send("rebirthReady") end)
	button(rebirthTools, "Wipe for Rebirth", "danger", function()
		confirm("Wipe?", "The Rebirth reset without the reward (Gold, points, weapons, armor, eggs, pets).", function()
			send("wipeForRebirth")
		end)
	end)

	heading(page, "Rebirth Shop upgrades")
	local upgradeLabels: { [string]: any } = {}
	for _, upgrade in ipairs(RebirthShop.List) do
		local row = grid(page, SMALL)
		upgradeLabels[upgrade.Id] = button(row, upgrade.Name, "wood", function() end)
		local levels = { 0, math.floor(upgrade.Max / 2), upgrade.Max }
		for _, n in ipairs(levels) do
			button(row, if n == upgrade.Max then `Max {n}` else tostring(n), "secondary", function() send("setUpgrade", upgrade.Id, n) end)
		end
	end
	State.observe("RebirthUpgrades", function(levels)
		for id, b in pairs(upgradeLabels) do
			b:SetText(`{RebirthShop.ById[id].Name} {(levels or {})[id] or 0}`)
		end
	end)
	local upgradesAll = section(page, "Every upgrade")
	button(upgradesAll, "All max", "go", function() send("setUpgrades", true) end)
	button(upgradesAll, "All 0", "danger", function() send("setUpgrades", false) end)

	local tests = section(page, "Checks")
	button(tests, "Stats tests", "secondary", function() send("runStatsTests") end)
end

----------------------------------------------------------------------------------------------------
-- World
----------------------------------------------------------------------------------------------------
local function worldPage(page: Instance)
	heading(page, "Teleport")
	local where = picker(page, "Where in the zone", { { Label = "1", Value = 1 }, { Label = "2", Value = 2 }, { Label = "3", Value = 3 }, { Label = "4", Value = 4 }, { Label = "Boss", Value = 5 } })
	local zones = grid(page)
	button(zones, "Hub", "primary", function() send("setZone", "Hub") end)
	for _, zone in ipairs(Zones.List) do
		button(zones, zone.Name, "wood", function() send("setZone", zone.Id, where.get()) end)
	end

	local locks = section(page, "Zones (tap = lock / unlock)")
	button(locks, "Unlock all", "go", function() send("unlockAll") end)
	button(locks, "New player locks", "danger", function() send("lockAll") end)
	local zoneButtons = {}
	for index, zone in ipairs(Zones.List) do
		if index > 1 then
			zoneButtons[zone.Id] = button(locks, zone.Name, "secondary", function()
				local open = (State.get("Zones") or {})[zone.Id]
				send(if open then "lockZone" else "unlockZone", zone.Id, 4)
			end)
		end
	end
	State.observe("Zones", function(open)
		for zoneId, b in pairs(zoneButtons) do
			local isOpen = (open or {})[zoneId] == true
			b:SetStyle(if isOpen then "go" else "secondary")
			b:SetText(`{Zones.ById[zoneId].Name}: {if isOpen then "open" else "locked"}`)
		end
	end)

	heading(page, "Enemies")
	local enemy: Picker
	local function enemyOptions(zoneId: any): { Option }
		local list = {}
		for n = 1, Zones.SUBZONE_COUNT do
			for _, e in ipairs(Enemies.BySubZone[Zones.subZoneId(zoneId, n)] or {}) do
				table.insert(list, { Label = `{n}: {e.Name}`, Value = e.Id })
			end
		end
		local room = Enemies.BossRoom[zoneId]
		if room then
			table.insert(list, { Label = `Mini: {room.Mini1.Name}`, Value = room.Mini1.Id })
			table.insert(list, { Label = `Mini: {room.Mini2.Name}`, Value = room.Mini2.Id })
			table.insert(list, { Label = `BOSS: {room.Boss.Name}`, Value = room.Boss.Id })
		end
		return list
	end
	local enemyZone = picker(page, "Zone (spawning works in zones 1-4: their enemies have models)", zoneOptions(), CELL, function(value)
		enemy.rebuild(enemyOptions(value))
	end)
	enemy = picker(page, "Enemy", enemyOptions(enemyZone.get()), Vector2.new(190, 46))
	local trophyRarity = picker(page, "Trophy rarity", rarityOptions())
	local actions = grid(page)
	button(actions, "Spawn here", "go", function() send("spawnEnemy", enemy.get()) end)
	button(actions, "Spawn 5", "go", function() repeatSend(5, "spawnEnemy", enemy.get()) end)
	button(actions, "Drop its loot", "primary", function() send("dropLoot", enemy.get()) end)
	button(actions, "Trophy x1", "primary", function() send("giveTrophy", enemy.get(), trophyRarity.get(), 1) end)
	button(actions, "Trophy x10", "primary", function() send("giveTrophy", enemy.get(), trophyRarity.get(), 10) end)
	button(actions, "Simulate 10K kills", "secondary", function() send("simulateKills", enemy.get(), 10000) end)
	button(actions, "Kill all enemies", "danger", function() send("killAll") end)
	button(actions, "Check enemy data", "secondary", function() send("validateEnemies") end)

	local health = section(page, "Health and combat")
	button(health, "God mode ON", "go", function() send("godMode", true) end)
	button(health, "God mode OFF", "secondary", function() send("godMode", false) end)
	button(health, "Heal", "go", function() send("heal") end)
	button(health, "Damage 10", "secondary", function() send("damageSelf", 10) end)
	button(health, "Damage 40", "secondary", function() send("damageSelf", 40) end)
	button(health, "Enemy hit 50", "secondary", function() send("enemyHit", 50) end)
	button(health, "Enemy hit 500", "secondary", function() send("enemyHit", 500) end)
	button(health, "Die", "danger", function() send("damageSelf", 1e9) end)
end

----------------------------------------------------------------------------------------------------
-- Rewards
----------------------------------------------------------------------------------------------------
local function rewardsPage(page: Instance)
	liveLine(page, { "Quests", "Daily", "Playtime" }, function()
		local quests = State.get("Quests") or {}
		local done = 0
		for _, quest in ipairs(quests.List or {}) do
			if quest.Progress >= quest.Target then
				done += 1
			end
		end
		local daily = State.get("Daily") or {}
		local playtime = State.get("Playtime") or {}
		return `Quests done {done}/{#(quests.List or {})}    Daily streak {daily.Streak or 0}    Played today {math.floor((tonumber(playtime.Seconds) or 0) / 60)} min`
	end)
	-- today's 3 quests are green (the others only count on the days they come up)
	local quests = section(page, "Complete a quest (green = one of today's)", Vector2.new(190, 46))
	local questButtons = {}
	for _, kind in ipairs(Quests.Pool) do
		questButtons[kind.Id] = button(quests, kind.Id, "secondary", function() send("progressQuest", kind.Id, 1e15) end)
	end
	State.observe("Quests", function(today)
		for id, b in pairs(questButtons) do
			local quest
			for _, q in ipairs((today or {}).List or {}) do
				if q.Id == id then
					quest = q
				end
			end
			b:SetStyle(if quest and quest.Progress < quest.Target then "go" elseif quest then "primary" else "secondary")
			b:SetText(if quest and quest.Progress >= quest.Target then `{id} (done)` else id)
		end
	end)
	local questTools = section(page, "Quests")
	button(questTools, "Reset quests", "danger", function() send("resetQuests") end)
	button(questTools, "Simulate quests", "secondary", function() send("simulateQuests") end)

	local playtime = section(page, "Play time (gifts)", SMALL)
	for _, n in ipairs({ 5, 15, 30, 60 }) do
		button(playtime, `+{n} min`, "primary", function() send("addPlaytime", n) end)
	end

	local daily = section(page, "Daily reward")
	button(daily, "Day 1 ready", "secondary", function() send("setDaily", 0, 5) end)
	button(daily, "Day 3 ready", "secondary", function() send("setDaily", 2, 1) end)
	button(daily, "Day 7 ready", "secondary", function() send("setDaily", 6, 1) end)
	button(daily, "Claimed today", "secondary", function() send("setDaily", 1, 0) end)
	button(daily, "Streak lost", "danger", function() send("setDaily", 4, 3) end)

	local index = section(page, "Index")
	button(index, "Find everything", "go", function() send("discover", "All") end)
	for _, tab in ipairs({ "Weapons", "Armor", "Pets", "Enemies" }) do
		button(index, `All {tab}`, "primary", function() send("discover", `{tab}:All`) end)
	end
	button(index, "Plains only", "secondary", function()
		task.spawn(function()
			for _, tab in ipairs({ "Weapons", "Armor", "Pets", "Enemies" }) do
				send("discover", `{tab}:Plains`)
				task.wait(REQUEST_GAP)
			end
		end)
	end)
	button(index, "Clear Index", "danger", function() send("clearIndex") end)
end

----------------------------------------------------------------------------------------------------
-- Tests
----------------------------------------------------------------------------------------------------
local function testsPage(page: Instance)
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

	local gear = section(page, "Fake equipment (current zone, not saved)", SMALL)
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

	local badges = section(page, "Menu badges")
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

	local checks = section(page, "Checks (results in the output)")
	button(checks, "Stats tests", "secondary", function() send("runStatsTests") end)
	button(checks, "Enemy data", "secondary", function() send("validateEnemies") end)
	button(checks, "Egg odds 100K", "secondary", function() send("simulateEggs", 100000) end)
	button(checks, "Quest days", "secondary", function() send("simulateQuests") end)

	local data = section(page, "Profile")
	button(data, "Save now", "go", function() send("save") end)
	button(data, "Reset to new player", "danger", function()
		confirm("Reset everything?", "Your profile goes back to a brand new player (settings kept). This cannot be undone.", function()
			send("resetProfile")
		end)
	end)
end

----------------------------------------------------------------------------------------------------
local function build()
	local def = UIConfig.Windows.Admin
	Window.define("Admin", { Title = def.Title, Icon = def.Icon, Tabs = def.Tabs, TabIcons = def.TabIcons, TabLabels = def.TabLabels, Size = def.Size, Build = function(ctx)
		resourcesPage(ctx.Pages.Resources)
		weaponsPage(ctx.Pages.Weapons)
		armorPage(ctx.Pages.Armor)
		petsPage(ctx.Pages.Pets)
		statsPage(ctx.Pages.Stats)
		worldPage(ctx.Pages.World)
		rewardsPage(ctx.Pages.Rewards)
		testsPage(ctx.Pages.Tests)
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
