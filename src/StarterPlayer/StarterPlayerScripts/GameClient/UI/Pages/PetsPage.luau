--!strict
-- The Pets window (docs/menu_systems_brief.txt B5). Tabs:
--   Pets: equipped slots (3, +2 with the Extra Pet Slots pass; extra slots show a lock), Equip Best, the
--         storage count, filters (zone, rarity) and sort (rarity, zone, power) and the grid. A tap opens the
--         detail panel: live 3D preview, values with Faith, Equip / Unequip, Lock, Release (confirm popup).
--   Eggs: owned eggs stacked by zone and rarity, Hatch / Hatch All (free) -> the hatch screen (UI/Hatching).
--   Premium Eggs: one egg per zone for Diamonds (locked zones: black silhouette with "?"), Odds, the species.
-- Every action is a server request (PetService); the pages redraw from the replicated profile.
-- Phones: one header row (slots, Best, Filters popup) so the grid keeps most of the height.
--   PetsPage.build(ctx)   (Windows.luau)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local PetRarities = require(ReplicatedStorage.GameSystem.Config.PetRarities)
local Pets = require(ReplicatedStorage.GameSystem.Config.Pets)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local RebirthShop = require(ReplicatedStorage.GameSystem.Config.RebirthShop)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local WeaponRarities = require(ReplicatedStorage.GameSystem.Config.WeaponRarities)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.Parent.State)
local Hatching = require(script.Parent.Parent.Hatching)
local Notifier = require(script.Parent.Parent.Notifier)
local Kit = script.Parent.Parent.Kit
local Button = require(Kit.Button)
local Icons = require(Kit.Icons)
local ModelIcon = require(Kit.ModelIcon)
local Panel = require(Kit.Panel)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local PetsPage = {}

local SLOT_MAX = PetRarities.Slots + PetRarities.ExtraSlots
local SORTS = { "Rarity", "Zone", "Power" }
local PREMIUM_ZONE = -1

local overlayParent: GuiObject? = nil
local overlay: Frame? = nil
local overlayStop: (() -> ())? = nil
local busy = false
local filter = { zone = 0, rarity = 0, sort = 1 } -- zone 0 = all, -1 = premium pets; rarity 0 = all
local refreshPets: () -> () = function() end

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------
local function request(action: string, ...: any): (boolean, any)
	if busy then
		return false, nil
	end
	busy = true
	local called, ok, result = pcall(Net.request, action, ...)
	busy = false
	if called and ok then
		return true, result
	end
	Sfx.play("Denied")
	Notifier.push({ Kind = "error", Text = if called and typeof(result) == "string" then result else "Something went wrong" })
	return false, nil
end

local function count(map: any): number
	local n = 0
	for _ in pairs(map or {}) do
		n += 1
	end
	return n
end

local function zoneName(zone: number): string
	local def = Zones.List[zone]
	return if def then def.Name else ""
end

local function fixedPage(page: ScrollingFrame)
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	page.ScrollingEnabled = false
	page.AutomaticCanvasSize = Enum.AutomaticSize.None
	page.CanvasSize = UDim2.new()
	page.ScrollBarThickness = 0
end

local function gridFrame(parent: Instance, top: number, cell: Vector2): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Name = "Grid"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Position = UDim2.fromOffset(0, top)
	frame.Size = UDim2.new(1, 0, 1, -top)
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.ScrollBarThickness = 6
	frame.ScrollBarImageColor3 = Theme.Colors.GoldLight
	frame.ZIndex = 2
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = frame
	frame.Parent = parent
	return frame
end

local function clearGrid(grid: ScrollingFrame)
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function emptyNote(grid: ScrollingFrame, icon: string, text: string, size: Vector2)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = 1
	holder.Size = UDim2.fromOffset(size.X, size.Y)
	Icons.create(icon, holder, { Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3 })
	Theme.text({ Text = text, TextSize = 20, Wrapped = true, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -20, 0, 52), Position = UDim2.new(0.5, 0, 0, 74), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3, Parent = holder })
	holder.Parent = grid
	-- a lone wide cell: let the grid show it centered
	local layout = grid:FindFirstChildOfClass("UIGridLayout")
	if layout then
		layout.CellSize = UDim2.fromOffset(size.X, size.Y)
	end
end

local function badge(parent: Instance, icon: string, color: Color3, position: UDim2, anchor: Vector2)
	local dot = Instance.new("Frame")
	dot.Name = icon .. "Badge"
	dot.Size = UDim2.fromOffset(26, 26)
	dot.Position = position
	dot.AnchorPoint = anchor
	dot.BackgroundColor3 = color
	dot.ZIndex = 5
	Theme.round(dot)
	Theme.stroke(dot, Theme.Colors.Ink, 1.5)
	Icons.create(icon, dot, { Size = UDim2.fromScale(0.78, 0.78), ZIndex = 6 })
	dot.Parent = parent
end

----------------------------------------------------------------------------------------------------
-- overlays inside the window (detail, filters, odds, species)
----------------------------------------------------------------------------------------------------
local function closeOverlay()
	if overlayStop then
		overlayStop()
		overlayStop = nil
	end
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
end

local function openOverlay(size: Vector2): Frame
	closeOverlay()
	local holder = Instance.new("Frame")
	holder.Name = "PetsOverlay"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 20
	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = Theme.Colors.Black
	dim.BackgroundTransparency = 0.4
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 20
	Theme.corner(dim, 8)
	dim.Activated:Connect(closeOverlay)
	dim.Parent = holder
	local parentSize = (overlayParent :: GuiObject).AbsoluteSize / Theme.getScale()
	local w, h = math.min(size.X, parentSize.X - 24), math.min(size.Y, parentSize.Y - 24)
	local panel = Panel.new({ Name = "Panel", Size = UDim2.fromOffset(w, h), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 21, Parent = holder })
	panel.Active = true -- clicks on the panel must not reach the dim behind it (which closes the overlay)
	Button.new({ Name = "Close", Style = "wood", Icon = "Close", Size = UDim2.fromOffset(Theme.TOUCH, Theme.TOUCH), Position = UDim2.new(1, -8, 0, 8), AnchorPoint = Vector2.new(1, 0), ZIndex = 24, OnClick = closeOverlay, Parent = panel })
	holder.Parent = overlayParent
	overlay = holder
	Sfx.play("UIOpen")
	return panel
end

local function column(parent: Instance, position: UDim2, size: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Position = position
	frame.Size = size
	frame.ZIndex = 22
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 3)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	frame.Parent = parent
	return frame
end

local function line(parent: Instance, text: string, order: number, color: Color3?, size: number?, font: string?): TextLabel
	return Theme.text({ Font = font or "Body", Text = text, TextSize = size or 19, Wrapped = true, Align = "Left", Color = color, Size = UDim2.new(1, 0, 0, (size or 19) + 8), LayoutOrder = order, ZIndex = 23, Parent = parent })
end

local detail: (uid: string) -> ()

detail = function(uid: string)
	local pet = (State.get("Pets") or {})[uid]
	local species = pet and Pets.ById[pet.id]
	if not species then
		closeOverlay()
		return
	end
	local small = Theme.isCompact()
	local panel = openOverlay(Vector2.new(800, 470))
	local h = panel.AbsoluteSize.Y / Theme.getScale()
	local side = math.min(h - 32, if small then 230 else 320)
	local holder = Instance.new("Frame")
	holder.Name = "Preview"
	holder.BackgroundColor3 = if pet.rarity == #Rarities.List then Rarities.SECRET_CORE else Theme.Colors.WoodInset
	holder.Size = UDim2.fromOffset(side, side)
	holder.Position = UDim2.fromOffset(16, 16)
	holder.ZIndex = 22
	Theme.corner(holder, 8)
	Theme.paintRarity(Theme.stroke(holder, Theme.Colors.GoldDark, 3), pet.rarity)
	holder.Parent = panel
	local view = ModelIcon.pet(pet.id, { Size = UDim2.fromScale(0.94, 0.94), ZIndex = 23, Parent = holder })
	overlayStop = ModelIcon.turntable(view, 9)
	Theme.text({ Text = "Drag to turn", TextSize = 15, Color = Theme.Colors.TextDim, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 24, Parent = holder })

	local text = if small then 16 else 19
	local info = column(panel, UDim2.fromOffset(side + 32, 14), UDim2.new(1, -(side + 48 + Theme.TOUCH), 1, -(Theme.TOUCH + 36)))
	line(info, species.Name, 1, Theme.Colors.Gold, if small then 24 else 30, "Title")
	Theme.paintRarity(line(info, Rarities.get(pet.rarity).Name, 2, nil, if small then 18 else 22, "Button"), pet.rarity)
	line(info, `{species.Role} - {if species.Premium then "Premium pet" else zoneName(species.Zone)}`, 3, Theme.Colors.TextDim, text - 2)
	local mult = Hatching.petEffect()
	local lines, bonus = Pets.describe(pet.id, pet.rarity, mult)
	for i, stat in ipairs(lines) do
		line(info, stat, 3 + i, nil, text)
	end
	line(info, `Bonus: {bonus}`, 6, Theme.Colors.Good, text)
	line(info, `({Pets.BONUS_TEXT[species.Bonus]})`, 7, Theme.Colors.TextDim, text - 3)
	if mult > 1.0001 then
		line(info, string.format("Faith makes your pets %.1f%% stronger (included).", (mult - 1) * 100), 8, Theme.Colors.TextDim, text - 3)
	end
	line(info, if species.Premium then "Premium: kept on Rebirth, cannot be released." else `Release value: {Format.number(Pets.releaseValue(pet.id, pet.rarity))} Gold`, 9, Theme.Colors.Gold, text - 2)

	-- buttons
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -(side + 48), 0, Theme.TOUCH)
	row.Position = UDim2.new(1, -16, 1, -12)
	row.AnchorPoint = Vector2.new(1, 1)
	row.ZIndex = 22
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	row.Parent = panel
	local equipped = table.find(State.get("EquippedPets") or {}, uid) ~= nil
	local width = if small then 130 else 160
	Button.new({ Text = if equipped then "Unequip" else "Equip", Style = if equipped then "secondary" else "go", Size = UDim2.fromOffset(width, Theme.TOUCH), LayoutOrder = 1, ZIndex = 23, Parent = row, OnClick = function()
		local ok = request(if equipped then "UnequipPet" else "EquipPet", uid)
		if ok then
			Sfx.play("UIClick")
			detail(uid)
		end
	end })
	Button.new({ Text = if pet.locked then "Unlock" else "Lock", Icon = "Lock", Style = "secondary", Size = UDim2.fromOffset(width, Theme.TOUCH), LayoutOrder = 2, ZIndex = 23, Parent = row, OnClick = function()
		local ok = request("LockPet", uid, not pet.locked)
		if ok then
			Sfx.play("UIClick")
			detail(uid)
		end
	end })
	local release = Button.new({ Text = "Release", Style = if pet.locked or species.Premium then "disabled" else "danger", Size = UDim2.fromOffset(width, Theme.TOUCH), LayoutOrder = 3, ZIndex = 23, Parent = row, OnClick = function()
		if pet.locked then
			Notifier.push({ Kind = "error", Text = "Unlock this pet first" })
			return
		elseif species.Premium then
			Notifier.push({ Kind = "error", Text = "Premium pets cannot be released" })
			return
		end
		Window.confirm({
			Title = "Release pet?",
			Text = `Release {Rarities.get(pet.rarity).Name} {species.Name} for {Format.number(Pets.releaseValue(pet.id, pet.rarity))} Gold? This cannot be undone.`,
			ConfirmText = "Release",
			CancelText = "Keep",
			OnConfirm = function()
				local ok, result = request("ReleasePet", uid)
				if ok then
					Sfx.play("Purchase")
					closeOverlay()
					Notifier.push({ Kind = "reward", Text = `Released {species.Name}: +{Format.number(result.gold)} Gold`, Icon = "Gold" })
				end
			end,
		})
	end })
	release.Instance.Visible = true
end

local function odds()
	local panel = openOverlay(Vector2.new(700, 500))
	Theme.text({ Font = "Title", Text = "Premium Egg Odds", TextSize = 32, Color = Theme.Colors.Gold, Size = UDim2.new(1, -140, 0, 40), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 23, Parent = panel })
	local body = Instance.new("ScrollingFrame")
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(16, 58)
	body.Size = UDim2.new(1, -32, 1, -72)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ScrollBarThickness = 6
	body.ScrollBarImageColor3 = Theme.Colors.GoldLight
	body.ZIndex = 22
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	body.Parent = panel
	local function row(order: number, a: string, b: string, c: string, tier: number?)
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = if order % 2 == 0 then Theme.Colors.WoodInset else Theme.Colors.WoodTop
		frame.BackgroundTransparency = if tier then 0.2 else 1
		frame.Size = UDim2.new(1, -8, 0, 32)
		frame.LayoutOrder = order
		frame.ZIndex = 22
		Theme.corner(frame, 4)
		local first = Theme.text({ Font = if tier then "Button" else "Button", Text = a, TextSize = 19, Align = "Left", Color = if tier then nil else Theme.Colors.Gold, Size = UDim2.new(0.36, -8, 1, 0), Position = UDim2.fromOffset(10, 0), ZIndex = 23, Parent = frame })
		if tier then
			Theme.paintRarity(first, tier)
		end
		Theme.text({ Text = b, TextSize = 19, Color = if tier then nil else Theme.Colors.Gold, Size = UDim2.new(0.28, 0, 1, 0), Position = UDim2.fromScale(0.36, 0), ZIndex = 23, Parent = frame })
		Theme.text({ Text = c, TextSize = 19, Color = if tier then nil else Theme.Colors.Gold, Size = UDim2.new(0.36, 0, 1, 0), Position = UDim2.fromScale(0.64, 0), ZIndex = 23, Parent = frame })
		frame.Parent = body
	end
	row(0, "Rarity", "Chance", "Each main stat", nil)
	for tier, rarity in ipairs(WeaponRarities.List) do
		row(tier, rarity.Name, WeaponRarities.percentText(rarity.ShopOdds), `+{math.round(Pets.mainValue(tier) * 100)}%`, tier)
	end
	local luck = RebirthShop.bonus(State.get("RebirthUpgrades"), "EggLuck")
	local note = `Each zone egg holds that zone's 6 pets (same chance each). Egg Luck (Rebirth Shop) gives a chance that the pet is one rarity higher. Yours: {math.round(luck * 100)}%.`
	Theme.text({ Text = note, TextSize = 18, Wrapped = true, Align = "Left", Color = Theme.Colors.TextDim, Size = UDim2.new(1, -8, 0, 70), LayoutOrder = 20, ZIndex = 23, Parent = body })
end

-- the 6 species of a zone egg (premium egg card tap)
local function speciesList(zone: any)
	local small = Theme.isCompact()
	local panel = openOverlay(Vector2.new(820, 470))
	Theme.text({ Font = "Title", Text = `{zone.Name} Egg - 6 pets`, TextSize = if small then 26 else 32, Color = Theme.Colors.Gold, Size = UDim2.new(1, -140, 0, 40), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 23, Parent = panel })
	local body = Instance.new("ScrollingFrame")
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(12, 58)
	body.Size = UDim2.new(1, -24, 1, -70)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ScrollBarThickness = 6
	body.ScrollBarImageColor3 = Theme.Colors.GoldLight
	body.ZIndex = 22
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(if small then 200 else 240, if small then 150 else 176)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body
	body.Parent = panel
	for slot, species in ipairs(Pets.ByZone[zone.Id]) do
		local cell = Instance.new("Frame")
		cell.BackgroundColor3 = Theme.Colors.WoodInset
		cell.LayoutOrder = slot
		cell.ZIndex = 22
		Theme.corner(cell, 6)
		Theme.stroke(cell, Theme.Colors.GoldDark, 2)
		ModelIcon.pet(species.Id, { Size = UDim2.new(1, -8, 1, -64), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 23, Parent = cell })
		Theme.text({ Font = "Button", Text = species.Name, TextSize = 19, Color = Theme.Colors.Gold, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.new(0.5, 0, 1, -40), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 23, Parent = cell })
		local stats = {}
		for _, stat in ipairs(species.Stats) do
			table.insert(stats, Pets.STAT_NAMES[stat])
		end
		Theme.text({ Text = `{table.concat(stats, " + ")} | {Pets.BONUS_NAMES[species.Bonus]}`, TextSize = 15, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -8, 0, 34), Wrapped = true, Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 23, Parent = cell })
		cell.Parent = body
	end
end

----------------------------------------------------------------------------------------------------
-- Pets tab
----------------------------------------------------------------------------------------------------
type Entry = { uid: string, pet: any, species: any, score: number, equipped: boolean }

local function zoneOptions(): { number }
	local present: { [number]: boolean } = {}
	local premium = false
	for _, pet in pairs(State.get("Pets") or {}) do
		local species = Pets.ById[pet.id]
		if species then
			if species.Premium then
				premium = true
			else
				present[species.Zone] = true
			end
		end
	end
	local options = { 0 }
	for index = 1, #Zones.List do
		if present[index] then
			table.insert(options, index)
		end
	end
	if premium then
		table.insert(options, PREMIUM_ZONE)
	end
	return options
end

local function zoneLabel(): string
	if filter.zone == 0 then
		return "Zone: All"
	elseif filter.zone == PREMIUM_ZONE then
		return "Zone: Premium"
	end
	return `Zone: {zoneName(filter.zone)}`
end

local function rarityLabel(): string
	return if filter.rarity == 0 then "Rarity: All" else `Rarity: {Rarities.get(filter.rarity).Name}`
end

local function sortLabel(): string
	return `Sort: {SORTS[filter.sort]}`
end

local function cycleZone()
	local options = zoneOptions()
	local at = table.find(options, filter.zone) or 0
	filter.zone = options[at % #options + 1]
end

local function entries(): { Entry }
	local equippedList = State.get("EquippedPets") or {}
	local list = {}
	for uid, pet in pairs(State.get("Pets") or {}) do
		local species = Pets.ById[pet.id]
		if species then
			local zoneOk = filter.zone == 0 or (filter.zone == PREMIUM_ZONE and species.Premium) or (not species.Premium and species.Zone == filter.zone)
			local rarityOk = filter.rarity == 0 or pet.rarity == filter.rarity
			if zoneOk and rarityOk then
				table.insert(list, { uid = uid, pet = pet, species = species, score = Pets.powerScore(pet.id, pet.rarity), equipped = table.find(equippedList, uid) ~= nil })
			end
		end
	end
	local sort = SORTS[filter.sort]
	table.sort(list, function(a, b)
		if a.equipped ~= b.equipped then
			return a.equipped
		end
		if sort == "Zone" then
			local za = if a.species.Premium then 99 else a.species.Zone
			local zb = if b.species.Premium then 99 else b.species.Zone
			if za ~= zb then
				return za > zb
			end
			if a.species.Slot ~= b.species.Slot then
				return a.species.Slot < b.species.Slot
			end
		elseif sort == "Power" then
			if a.score ~= b.score then
				return a.score > b.score
			end
		end
		if a.pet.rarity ~= b.pet.rarity then
			return a.pet.rarity > b.pet.rarity
		end
		if a.score ~= b.score then
			return a.score > b.score
		end
		if a.pet.id ~= b.pet.id then
			return a.pet.id < b.pet.id
		end
		return a.uid < b.uid
	end)
	return list
end

local function petCell(entry: Entry, order: number): TextButton
	local cell = Instance.new("TextButton")
	cell.Name = entry.uid
	cell.Text = ""
	cell.AutoButtonColor = false
	cell.BackgroundColor3 = if entry.pet.rarity == #Rarities.List then Rarities.SECRET_CORE else Theme.Colors.WoodInset
	cell.LayoutOrder = order
	cell.ZIndex = 3
	Theme.corner(cell, 8)
	Theme.paintRarity(Theme.stroke(cell, Theme.Colors.GoldDark, 3), entry.pet.rarity)
	ModelIcon.pet(entry.pet.id, { Size = UDim2.new(1, -8, 1, -34), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 4, Parent = cell })
	local name = Theme.text({ Font = "Button", Text = entry.species.Name, TextSize = 16, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.new(0.5, 0, 1, -5), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 4, Parent = cell })
	Theme.paintRarity(name, entry.pet.rarity)
	if entry.equipped then
		badge(cell, "Check", Theme.Colors.Good, UDim2.fromOffset(4, 4), Vector2.zero)
	end
	if entry.pet.locked then
		badge(cell, "Lock", Theme.Colors.WoodLight, UDim2.new(1, -4, 0, 4), Vector2.new(1, 0))
	elseif entry.species.Premium then
		badge(cell, "Crown", Theme.Colors.WoodLight, UDim2.new(1, -4, 0, 4), Vector2.new(1, 0))
	end
	cell.Activated:Connect(function()
		Sfx.play("UIClick")
		detail(entry.uid)
	end)
	return cell
end

local function filtersPopup()
	local panel = openOverlay(Vector2.new(420, 300))
	Theme.text({ Font = "Title", Text = "Filters", TextSize = 30, Color = Theme.Colors.Gold, Size = UDim2.new(1, -140, 0, 40), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 23, Parent = panel })
	local list = column(panel, UDim2.fromOffset(20, 60), UDim2.new(1, -40, 1, -70))
	local layout = list:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	layout.Padding = UDim.new(0, 8)
	local buttons = {}
	local function sync()
		buttons.zone:SetText(zoneLabel())
		buttons.rarity:SetText(rarityLabel())
		buttons.sort:SetText(sortLabel())
	end
	buttons.zone = Button.new({ Text = zoneLabel(), Style = "secondary", Size = UDim2.new(1, 0, 0, Theme.TOUCH), LayoutOrder = 1, ZIndex = 23, Parent = list, OnClick = function()
		cycleZone()
		sync()
		refreshPets()
	end })
	buttons.rarity = Button.new({ Text = rarityLabel(), Style = "secondary", Size = UDim2.new(1, 0, 0, Theme.TOUCH), LayoutOrder = 2, ZIndex = 23, Parent = list, OnClick = function()
		filter.rarity = (filter.rarity + 1) % (#Rarities.List + 1)
		sync()
		refreshPets()
	end })
	buttons.sort = Button.new({ Text = sortLabel(), Style = "secondary", Size = UDim2.new(1, 0, 0, Theme.TOUCH), LayoutOrder = 3, ZIndex = 23, Parent = list, OnClick = function()
		filter.sort = filter.sort % #SORTS + 1
		sync()
		refreshPets()
	end })
end

local function buildPets(page: ScrollingFrame)
	fixedPage(page)
	local small = Theme.isCompact()
	local slotSize = if small then 48 else 64
	local rowH = math.max(slotSize, Theme.TOUCH)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, if small then rowH else rowH + 8 + Theme.TOUCH)
	header.ZIndex = 2
	header.Parent = page

	-- equipped slots
	local slotsRow = Instance.new("Frame")
	slotsRow.Name = "Slots"
	slotsRow.BackgroundTransparency = 1
	slotsRow.Size = UDim2.fromOffset(SLOT_MAX * (slotSize + 6), rowH)
	slotsRow.ZIndex = 2
	local slotList = Instance.new("UIListLayout")
	slotList.FillDirection = Enum.FillDirection.Horizontal
	slotList.VerticalAlignment = Enum.VerticalAlignment.Center
	slotList.Padding = UDim.new(0, 6)
	slotList.SortOrder = Enum.SortOrder.LayoutOrder
	slotList.Parent = slotsRow
	slotsRow.Parent = header
	local slotButtons: { TextButton } = {}
	for i = 1, SLOT_MAX do
		local slot = Instance.new("TextButton")
		slot.Name = "Slot" .. i
		slot.Text = ""
		slot.AutoButtonColor = false
		slot.Size = UDim2.fromOffset(slotSize, slotSize)
		slot.BackgroundColor3 = Theme.Colors.WoodInset
		slot.LayoutOrder = i
		slot.ZIndex = 3
		Theme.corner(slot, 8)
		Theme.stroke(slot, Theme.Colors.GoldDark, 2)
		slot.Parent = slotsRow
		slotButtons[i] = slot
	end

	local bestW = if small then 112 else 190
	Button.new({ Name = "EquipBest", Text = if small then "Best" else "Equip Best", Icon = "Star", Style = "go", Size = UDim2.fromOffset(bestW, Theme.TOUCH), Position = UDim2.new(1, 0, 0, (rowH - Theme.TOUCH) / 2), AnchorPoint = Vector2.new(1, 0), ZIndex = 3, Parent = header, OnClick = function()
		local ok = request("EquipBestPets")
		if ok then
			Sfx.play("UIClick")
			Notifier.push({ Kind = "info", Text = "Best pets equipped", Icon = "Pets" })
		end
	end })
	local storage = Theme.text({ Name = "Storage", Font = "Number", Text = "", TextSize = 20, Align = "Right", Size = UDim2.fromOffset(110, 28), Position = UDim2.new(1, -(bestW + 10), 0, rowH / 2), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 3, Parent = header })

	local filterButtons: { [string]: any } = {}
	if small then
		filterButtons.popup = Button.new({ Name = "Filters", Text = "Filters", Style = "secondary", Size = UDim2.fromOffset(110, Theme.TOUCH), Position = UDim2.new(1, -(bestW + 8), 0, (rowH - Theme.TOUCH) / 2), AnchorPoint = Vector2.new(1, 0), ZIndex = 3, Parent = header, OnClick = filtersPopup })
		storage.Position = UDim2.new(1, -(bestW + 8 + 110 + 8), 0, rowH / 2)
		storage.Size = UDim2.fromOffset(70, 26)
		storage.TextSize = 18
	else
		local row = Instance.new("Frame")
		row.Name = "Filters"
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, Theme.TOUCH)
		row.Position = UDim2.fromOffset(0, rowH + 8)
		row.ZIndex = 2
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, 8)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = row
		row.Parent = header
		filterButtons.zone = Button.new({ Text = zoneLabel(), Style = "secondary", TextSize = 20, Size = UDim2.fromOffset(220, Theme.TOUCH), LayoutOrder = 1, ZIndex = 3, Parent = row, OnClick = function()
			cycleZone()
			refreshPets()
		end })
		filterButtons.rarity = Button.new({ Text = rarityLabel(), Style = "secondary", TextSize = 20, Size = UDim2.fromOffset(220, Theme.TOUCH), LayoutOrder = 2, ZIndex = 3, Parent = row, OnClick = function()
			filter.rarity = (filter.rarity + 1) % (#Rarities.List + 1)
			refreshPets()
		end })
		filterButtons.sort = Button.new({ Text = sortLabel(), Style = "secondary", TextSize = 20, Size = UDim2.fromOffset(200, Theme.TOUCH), LayoutOrder = 3, ZIndex = 3, Parent = row, OnClick = function()
			filter.sort = filter.sort % #SORTS + 1
			refreshPets()
		end })
	end

	local cellSize = if small then Vector2.new(100, 124) else Vector2.new(118, 146)
	local grid = gridFrame(page, header.Size.Y.Offset + 6, cellSize)

	local function paintSlots()
		local owned = State.get("Pets") or {}
		local equipped = State.get("EquippedPets") or {}
		local open = Hatching.slots()
		for i, slot in ipairs(slotButtons) do
			for _, child in ipairs(slot:GetChildren()) do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			local stroke = slot:FindFirstChildOfClass("UIStroke") :: UIStroke
			local old = stroke:FindFirstChild("RarityGradient")
			if old then
				old:Destroy()
			end
			stroke.Color = Theme.Colors.GoldDark
			local uid = equipped[i]
			local pet = uid and owned[uid]
			if i > open then
				Icons.create("Lock", slot, { Size = UDim2.fromScale(0.55, 0.55), ZIndex = 4 })
				slot.BackgroundColor3 = Theme.Colors.WoodLine
			elseif pet then
				slot.BackgroundColor3 = if pet.rarity == #Rarities.List then Rarities.SECRET_CORE else Theme.Colors.WoodInset
				Theme.paintRarity(stroke, pet.rarity)
				ModelIcon.pet(pet.id, { Size = UDim2.fromScale(0.92, 0.92), ZIndex = 4, Parent = slot })
			else
				slot.BackgroundColor3 = Theme.Colors.WoodInset
				Icons.create("Plus", slot, { Size = UDim2.fromScale(0.4, 0.4), ZIndex = 4 })
			end
		end
	end
	for i, slot in ipairs(slotButtons) do
		slot.Activated:Connect(function()
			local equipped = State.get("EquippedPets") or {}
			if i > Hatching.slots() then
				Notifier.push({ Kind = "info", Text = "2 more pet slots with the Extra Pet Slots game pass (coming soon)", Icon = "Lock" })
			elseif equipped[i] then
				detail(equipped[i])
			else
				Notifier.push({ Kind = "info", Text = "Tap a pet below to equip it", Icon = "Pets" })
			end
		end)
	end

	refreshPets = function()
		paintSlots()
		storage.Text = `{count(State.get("Pets"))}/{PetRarities.PetStorage}`
		if filterButtons.zone then
			filterButtons.zone:SetText(zoneLabel())
			filterButtons.rarity:SetText(rarityLabel())
			filterButtons.sort:SetText(sortLabel())
		end
		local scroll = grid.CanvasPosition
		clearGrid(grid)
		local layout = grid:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
		layout.CellSize = UDim2.fromOffset(cellSize.X, cellSize.Y)
		local list = entries()
		if #list == 0 then
			local any = count(State.get("Pets")) > 0
			emptyNote(grid, "Pets", if any then "No pet matches these filters." else "No pets yet. Hatch eggs at the Egg Station or in the Eggs tab!", Vector2.new(420, 140))
			return
		end
		for index, entry in ipairs(list) do
			petCell(entry, index).Parent = grid
		end
		grid.CanvasPosition = scroll
	end
	refreshPets()
	State.changed("Pets", function()
		refreshPets()
	end)
	State.changed("EquippedPets", function()
		refreshPets()
	end)
	State.changed("Passes", function()
		refreshPets()
	end)
end

----------------------------------------------------------------------------------------------------
-- Eggs tab
----------------------------------------------------------------------------------------------------
type Stack = { zone: number, rarity: number, uids: { string } }

local function stacks(): { Stack }
	local byKey: { [string]: Stack } = {}
	local list = {}
	for uid, egg in pairs(State.get("Eggs") or {}) do
		if typeof(egg) == "table" and Zones.List[egg.zone] then
			local key = `{egg.zone}:{egg.rarity}`
			local stack = byKey[key]
			if not stack then
				stack = { zone = egg.zone, rarity = egg.rarity, uids = {} }
				byKey[key] = stack
				table.insert(list, stack)
			end
			table.insert(stack.uids, uid)
		end
	end
	for _, stack in ipairs(list) do
		table.sort(stack.uids)
	end
	table.sort(list, function(a, b)
		if a.rarity ~= b.rarity then
			return a.rarity > b.rarity
		end
		return a.zone > b.zone
	end)
	return list
end

local hatchStack: (zone: number?, rarity: number?) -> ()

hatchStack = function(zone: number?, rarity: number?)
	if Hatching.isActive() or busy then
		return
	end
	local list = stacks()
	if #list == 0 then
		Notifier.push({ Kind = "info", Text = "No more eggs", Icon = "Egg" })
		return
	end
	local pick = list[1]
	for _, stack in ipairs(list) do
		if stack.zone == zone and stack.rarity == rarity then
			pick = stack
			break
		end
	end
	local ok, result = request("HatchEgg", pick.uids[1])
	if ok and typeof(result) == "table" then
		Window.close()
		Hatching.play(result.results, { NextText = "Hatch next", OnNext = function()
			hatchStack(pick.zone, pick.rarity)
		end })
	end
end

local function hatchAll()
	if Hatching.isActive() or busy then
		return
	end
	local ok, result = request("HatchAll")
	if ok and typeof(result) == "table" then
		Window.close()
		Hatching.play(result.results)
		if (result.left or 0) > 0 then
			Notifier.push({ Kind = "info", Text = `Pet storage full: {result.left} egg{if result.left == 1 then "" else "s"} left`, Icon = "Egg" })
		end
	end
end

local function buildEggs(page: ScrollingFrame)
	fixedPage(page)
	local small = Theme.isCompact()
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, Theme.TOUCH)
	header.ZIndex = 2
	header.Parent = page
	Icons.create("Egg", header, { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
	local countLabel = Theme.text({ Font = "Number", Text = "", TextSize = 22, Align = "Left", Size = UDim2.fromOffset(150, 30), Position = UDim2.new(0, 46, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3, Parent = header })
	if not small then
		Theme.text({ Text = "Eggs drop from enemies. Hatching is free.", TextSize = 18, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -460, 0, 26), Position = UDim2.new(0.5, -20, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = header })
	end
	local all = Button.new({ Name = "HatchAll", Text = "Hatch All", Icon = "Egg", Style = "primary", Size = UDim2.fromOffset(if small then 170 else 210, Theme.TOUCH), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), ZIndex = 3, Parent = header, OnClick = hatchAll })
	-- phones: wide cards (egg on the left, names on its right, Hatch under them) so a whole card fits the height
	local cellSize = if small then Vector2.new(196, 134) else Vector2.new(150, 206)
	local grid = gridFrame(page, Theme.TOUCH + 8, cellSize)

	local function refresh()
		local list = stacks()
		countLabel.Text = `{count(State.get("Eggs"))}/{PetRarities.EggStorage}`
		all:SetStyle(if #list > 0 then "primary" else "disabled")
		clearGrid(grid)
		local layout = grid:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
		layout.CellSize = UDim2.fromOffset(cellSize.X, cellSize.Y)
		if #list == 0 then
			emptyNote(grid, "Egg", "No eggs yet. Enemies drop eggs; premium eggs are in the Premium Eggs tab.", Vector2.new(440, 140))
			return
		end
		local iconH = if small then 66 else 100
		for index, stack in ipairs(list) do
			local rarity = Rarities.get(stack.rarity)
			local cell = Instance.new("Frame")
			cell.Name = `{stack.zone}_{stack.rarity}`
			cell.BackgroundColor3 = Theme.Colors.WoodInset
			cell.LayoutOrder = index
			cell.ZIndex = 3
			Theme.corner(cell, 8)
			Theme.paintRarity(Theme.stroke(cell, Theme.Colors.GoldDark, 3), stack.rarity)
			if small then
				ModelIcon.egg(stack.zone, stack.rarity, { Size = UDim2.fromOffset(iconH, iconH), Position = UDim2.fromOffset(6, 4), AnchorPoint = Vector2.zero, ZIndex = 4, Parent = cell })
				local tierLabel = Theme.text({ Font = "Button", Text = rarity.Name, TextSize = 18, Align = "Left", Size = UDim2.new(1, -(iconH + 16), 0, 22), Position = UDim2.fromOffset(iconH + 10, 12), ZIndex = 4, Parent = cell })
				Theme.paintRarity(tierLabel, stack.rarity)
				Theme.text({ Text = `{zoneName(stack.zone)} Egg`, TextSize = 16, Align = "Left", Wrapped = true, Size = UDim2.new(1, -(iconH + 16), 0, 36), Position = UDim2.fromOffset(iconH + 10, 34), ZIndex = 4, Parent = cell })
			else
				ModelIcon.egg(stack.zone, stack.rarity, { Size = UDim2.fromOffset(iconH, iconH), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 4, Parent = cell })
				local tierLabel = Theme.text({ Font = "Button", Text = rarity.Name, TextSize = 16, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.new(0.5, 0, 0, iconH + 6), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 4, Parent = cell })
				Theme.paintRarity(tierLabel, stack.rarity)
				Theme.text({ Text = `{zoneName(stack.zone)} Egg`, TextSize = 16, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.new(0.5, 0, 0, iconH + 24), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 4, Parent = cell })
			end
			if #stack.uids > 1 then
				local tag = Instance.new("Frame")
				tag.BackgroundColor3 = Theme.Colors.WoodLine
				tag.Size = UDim2.fromOffset(44, 24)
				tag.Position = UDim2.new(1, -4, 0, 4)
				tag.AnchorPoint = Vector2.new(1, 0)
				tag.ZIndex = 5
				Theme.corner(tag, 12)
				Theme.stroke(tag, Theme.Colors.GoldDark, 1.5)
				Theme.text({ Font = "Number", Text = `x{#stack.uids}`, TextSize = 16, Size = UDim2.new(1, -6, 1, -4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6, Parent = tag })
				tag.Parent = cell
			end
			Button.new({ Text = "Hatch", Style = "go", TextSize = 20, Size = UDim2.new(1, -12, 0, Theme.TOUCH), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 4, Parent = cell, OnClick = function()
				hatchStack(stack.zone, stack.rarity)
			end })
			cell.Parent = grid
		end
	end
	refresh()
	State.changed("Eggs", function()
		refresh()
	end)
end

----------------------------------------------------------------------------------------------------
-- Premium Eggs tab
----------------------------------------------------------------------------------------------------
local buyPremium: (zone: any) -> ()

buyPremium = function(zone: any)
	if Hatching.isActive() or busy then
		return
	end
	local price = PetRarities.premiumEggPrice(zone.Index)
	if (State.get("Diamonds") or 0) < price then
		Sfx.play("Denied")
		Notifier.push({ Kind = "error", Text = "Not enough Diamonds" })
		return
	end
	local ok, result = request("BuyPremiumEgg", zone.Index)
	if ok and typeof(result) == "table" then
		Sfx.play("Purchase")
		Window.close()
		Hatching.play(result.results, { NextText = `Buy again ({price})`, OnNext = function()
			buyPremium(zone)
		end })
	end
end

local function buildPremium(page: ScrollingFrame)
	fixedPage(page)
	local small = Theme.isCompact()
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, Theme.TOUCH)
	header.ZIndex = 2
	header.Parent = page
	local box = Instance.new("Frame")
	box.BackgroundColor3 = Theme.Colors.WoodInset
	box.Size = UDim2.fromOffset(if small then 150 else 180, 40)
	box.Position = UDim2.new(0, 10, 0.5, 0)
	box.AnchorPoint = Vector2.new(0, 0.5)
	box.ZIndex = 3
	Theme.corner(box, 20)
	Theme.stroke(box, Theme.Colors.GoldDark, 2)
	box.Parent = header
	Icons.create("Diamond", box, { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, -8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 4 })
	local diamonds = Theme.text({ Font = "Number", Text = "", TextSize = 22, Align = "Right", Size = UDim2.new(1, -48, 1, -6), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 4, Parent = box })
	if not small then
		Theme.text({ Text = "Rarity rolled like the weapon shop. Tap an egg to see its pets.", TextSize = 18, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -440, 0, 26), Position = UDim2.new(0.5, 10, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = header })
	end
	Button.new({ Name = "Odds", Text = "Odds", Icon = "Info", Style = "secondary", Size = UDim2.fromOffset(150, Theme.TOUCH), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), ZIndex = 3, Parent = header, OnClick = odds })
	local cellSize = if small then Vector2.new(150, 176) else Vector2.new(176, 226)
	local grid = gridFrame(page, Theme.TOUCH + 8, cellSize)

	local function refresh()
		local zones = State.get("Zones") or {}
		local have = State.get("Diamonds") or 0
		diamonds.Text = Format.number(have)
		clearGrid(grid)
		local iconH = if small then 74 else 110
		for _, zone in ipairs(Zones.List) do
			local open = zones[zone.Id] == true
			local price = PetRarities.premiumEggPrice(zone.Index)
			local card = Instance.new("TextButton")
			card.Name = zone.Id
			card.Text = ""
			card.AutoButtonColor = false
			card.BackgroundColor3 = Color3.new(1, 1, 1)
			card.LayoutOrder = zone.Index
			card.ZIndex = 3
			Theme.corner(card, 8)
			Theme.gradient(card, Theme.Colors.WoodLight, Theme.Colors.WoodBottom)
			Theme.stroke(card, Theme.Colors.GoldDark, 2)
			local spot = Instance.new("Frame")
			spot.AnchorPoint = Vector2.new(0.5, 0)
			spot.Position = UDim2.new(0.5, 0, 0, 4)
			spot.Size = UDim2.fromOffset(iconH, iconH)
			spot.BackgroundColor3 = Theme.Colors.TextDim
			spot.BackgroundTransparency = 0.7
			spot.ZIndex = 3
			Theme.round(spot)
			spot.Parent = card
			ModelIcon.egg(zone.Index, nil, { Size = UDim2.fromOffset(iconH, iconH), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 4, Silhouette = not open, Parent = card })
			if not open then
				Theme.text({ Font = "Title", Text = "?", TextSize = 54, Size = UDim2.fromOffset(iconH, iconH), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), StrokeThickness = 3, ZIndex = 5, Parent = card })
			end
			Theme.text({ Font = "Button", Text = if open then `{zone.Name} Egg` else "???", TextSize = 18, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.new(0.5, 0, 0, iconH + 6), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 4, Parent = card })
			if open then
				local buy = Button.new({ Text = `{price}`, Icon = "Diamond", Style = if have >= price then "primary" else "disabled", TextSize = 28, Size = UDim2.new(1, -12, 0, Theme.TOUCH), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 4, Parent = card, OnClick = function()
					buyPremium(zone)
				end })
				buy.Instance.Name = "Buy"
			else
				Theme.text({ Text = `Unlock {zone.Name}`, TextSize = 16, Wrapped = true, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -12, 0, Theme.TOUCH), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 4, Parent = card })
			end
			card.Activated:Connect(function()
				if open then
					speciesList(zone)
				else
					Notifier.push({ Kind = "info", Text = `Unlock {zone.Name} to buy its egg. {Zones.requirementText(zone.Id)}`, Icon = "Lock" })
				end
			end)
			card.Parent = grid
		end
	end
	refresh()
	State.changed("Zones", function()
		refresh()
	end)
	State.changed("Diamonds", function()
		refresh()
	end)
end

-- Shop > Diamonds uses the same purchase (hatch screen with "Buy again").
function PetsPage.buyPremium(zone: any)
	buyPremium(zone)
end

function PetsPage.build(ctx: any)
	overlayParent = ctx.Frame
	buildPets(ctx.Pages.Pets)
	buildEggs(ctx.Pages.Eggs)
	buildPremium(ctx.Pages["Premium Eggs"])
	for _, page in pairs(ctx.Pages) do
		page:GetPropertyChangedSignal("Visible"):Connect(function()
			if not page.Visible then
				closeOverlay() -- another tab closes the open panel
			end
		end)
	end
	Window.Closed:Connect(function(id: string)
		if id == "Pets" then
			closeOverlay()
		end
	end)
end

return PetsPage
