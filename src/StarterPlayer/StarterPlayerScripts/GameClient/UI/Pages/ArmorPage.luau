--!strict
-- Inventory > Armor (docs/menu_systems_brief.txt C1-C3): every owned piece as a 3D icon with its rarity border
-- (filter by slot, sort by rarity / zone / score, storage count, Equip Best). A tap opens the detail panel (3D
-- preview, HP / Defense with and without the Zone Boost, sell value, Equip / Unequip, Lock, Sell with a confirm).
-- ArmorPage.picker(slot) is the Equipment screen's slot list: the compatible pieces with a comparison against the
-- worn one (green up / red down arrows for HP and Defense in the current zone) and Equip / Unequip.
--   ArmorPage.build(page, ctx), ArmorPage.picker(slot), ArmorPage.detail(uid)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Armor = require(ReplicatedStorage.GameSystem.Config.Armor)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.Parent.State)
local Notifier = require(script.Parent.Parent.Notifier)
local Kit = script.Parent.Parent.Kit
local Button = require(Kit.Button)
local Icons = require(Kit.Icons)
local ModelIcon = require(Kit.ModelIcon)
local Overlay = require(Kit.Overlay)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local ArmorPage = {}

local SORTS = { "Rarity", "Zone", "Score" }
local UP, DOWN = "▲", "▼"
local filter = { slot = 0, sort = 1 } -- slot 0 = all, else index in Armor.SLOTS
local overlayParent: GuiObject? = nil
local busy = false

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

local function currentZone(): string?
	local zone = Players.LocalPlayer:GetAttribute("CurrentZone")
	return if typeof(zone) == "string" then zone else nil
end

local function zoneName(id: string): string
	local zone = Zones.ById[id]
	return if zone then zone.Name else id
end

function ArmorPage.equippedSlot(uid: string): string?
	for slot, equippedUid in pairs(State.get("EquippedArmor") or {}) do
		if equippedUid == uid then
			return slot
		end
	end
	return nil
end

local function count(map: any): number
	local n = 0
	for _ in pairs(map or {}) do
		n += 1
	end
	return n
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

local function line(parent: Instance, text: string, order: number, color: Color3?, size: number?, font: string?): TextLabel
	return Theme.text({ Font = font or "Body", Text = text, TextSize = size or 19, Wrapped = true, Align = "Left", Color = color, Size = UDim2.new(1, 0, 0, (size or 19) + 8), LayoutOrder = order, ZIndex = 23, Parent = parent })
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
ArmorPage.fixedPage = fixedPage

----------------------------------------------------------------------------------------------------
-- detail
----------------------------------------------------------------------------------------------------
function ArmorPage.detail(uid: string)
	local item = (State.get("Armor") or {})[uid]
	local piece = item and Armor.ById[item.id]
	if not piece or not overlayParent then
		Overlay.close()
		return
	end
	local small = Theme.isCompact()
	local panel = Overlay.open(overlayParent :: GuiObject, Vector2.new(800, 470))
	local h = panel.AbsoluteSize.Y / Theme.getScale()
	local side = math.min(h - 32, if small then 230 else 320)
	local holder = Instance.new("Frame")
	holder.Name = "Preview"
	holder.BackgroundColor3 = if item.rarity == #Rarities.List then Rarities.SECRET_CORE else Theme.Colors.WoodInset
	holder.Size = UDim2.fromOffset(side, side)
	holder.Position = UDim2.fromOffset(16, 16)
	holder.ZIndex = 22
	Theme.corner(holder, 8)
	Theme.paintRarity(Theme.stroke(holder, Theme.Colors.GoldDark, 3), item.rarity)
	holder.Parent = panel
	local view = ModelIcon.armor(item.id, item.rarity, { Size = UDim2.fromScale(0.94, 0.94), ZIndex = 23, Parent = holder })
	Overlay.onClose(ModelIcon.turntable(view, 9))

	local rarity = Rarities.get(item.rarity)
	local text = if small then 16 else 19
	local info = column(panel, UDim2.fromOffset(side + 32, 14), UDim2.new(1, -(side + 48 + Theme.TOUCH), 1, -(Theme.TOUCH + 36)))
	line(info, piece.Name, 1, Theme.Colors.Gold, if small then 24 else 30, "Title")
	Theme.paintRarity(line(info, rarity.Name, 2, nil, if small then 18 else 22, "Button"), item.rarity)
	line(info, `{piece.Slot} - {zoneName(piece.ZoneId)}`, 3, Theme.Colors.TextDim, text - 2)
	local hp, defense = Armor.baseHP(item.id, item.rarity), Armor.baseDefense(item.rarity)
	line(info, `Max HP +{Format.number(math.floor(hp + 0.5))}   |   Defense +{defense}`, 4, nil, text)
	local boost = rarity.ZoneBoost
	line(info, `In {zoneName(piece.ZoneId)}: Zone Boost +{math.round(boost * 100)}% -> +{Format.number(math.floor(hp * (1 + boost) + 0.5))} HP, +{math.floor(defense * (1 + boost) * 10 + 0.5) / 10} Defense`, 5, Theme.Colors.Good, text - 1)
	line(info, `Full {zoneName(piece.ZoneId)} set: +10% Max HP and +10% Zone Boost`, 6, Theme.Colors.TextDim, text - 3)
	line(info, `Sell value: {Format.number(Armor.sellValue(item.id, item.rarity))} Gold`, 7, Theme.Colors.Gold, text - 2)

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
	local worn = ArmorPage.equippedSlot(uid)
	local width = if small then 130 else 160
	Button.new({ Text = if worn then "Unequip" else "Equip", Style = if worn then "secondary" else "go", Size = UDim2.fromOffset(width, Theme.TOUCH), LayoutOrder = 1, ZIndex = 23, Parent = row, OnClick = function()
		local ok = if worn then request("UnequipArmor", worn) else request("EquipArmor", uid)
		if ok then
			Sfx.play("UIClick")
			ArmorPage.detail(uid)
		end
	end })
	Button.new({ Text = if item.locked then "Unlock" else "Lock", Icon = "Lock", Style = "secondary", Size = UDim2.fromOffset(width, Theme.TOUCH), LayoutOrder = 2, ZIndex = 23, Parent = row, OnClick = function()
		local ok = request("LockArmor", uid, not item.locked)
		if ok then
			Sfx.play("UIClick")
			ArmorPage.detail(uid)
		end
	end })
	Button.new({ Text = "Sell", Icon = "Gold", Style = if item.locked or worn then "disabled" else "danger", Size = UDim2.fromOffset(width, Theme.TOUCH), LayoutOrder = 3, ZIndex = 23, Parent = row, OnClick = function()
		if item.locked then
			Notifier.push({ Kind = "error", Text = "Unlock this piece first" })
			return
		elseif worn then
			Notifier.push({ Kind = "error", Text = "Unequip it first" })
			return
		end
		Window.confirm({
			Title = "Sell armor?",
			Text = `Sell {rarity.Name} {piece.Name} for {Format.number(Armor.sellValue(item.id, item.rarity))} Gold? This cannot be undone.`,
			ConfirmText = "Sell",
			CancelText = "Keep",
			OnConfirm = function()
				local ok, result = request("SellArmor", uid)
				if ok then
					Sfx.play("Purchase")
					Overlay.close()
					Notifier.push({ Kind = "reward", Text = `Sold {piece.Name}: +{Format.number(result.gold)} Gold`, Icon = "Gold" })
				end
			end,
		})
	end })
end

----------------------------------------------------------------------------------------------------
-- picker (Equipment screen slots)
----------------------------------------------------------------------------------------------------
local function compare(parent: Instance, label: string, value: number, against: number?, position: UDim2, size: UDim2)
	local text = `{label} {Format.number(math.floor(value * 10 + 0.5) / 10)}`
	local color = Theme.Colors.Text
	if against then
		if value > against + 1e-6 then
			text ..= " " .. UP
			color = Theme.Colors.Good
		elseif value < against - 1e-6 then
			text ..= " " .. DOWN
			color = Theme.Colors.Bad
		end
	end
	Theme.text({ Font = "Number", Text = text, TextSize = 18, Align = "Left", Color = color, Size = size, Position = position, ZIndex = 23, Parent = parent })
end

function ArmorPage.picker(slot: string)
	if not overlayParent then
		return
	end
	local small = Theme.isCompact()
	local panel = Overlay.open(overlayParent :: GuiObject, Vector2.new(760, 520))
	Theme.text({ Font = "Title", Text = `Choose: {slot}`, TextSize = if small then 26 else 32, Color = Theme.Colors.Gold, Size = UDim2.new(1, -140, 0, 40), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 23, Parent = panel })
	local zone = currentZone()
	local owned = State.get("Armor") or {}
	local wornUid = (State.get("EquippedArmor") or {})[slot]
	local worn = wornUid and owned[wornUid]
	local wornHP, wornDef
	if worn then
		wornHP, wornDef = Armor.pieceStats(worn.id, worn.rarity, zone, false)
	end
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(14, 58)
	list.Size = UDim2.new(1, -28, 1, -70)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Theme.Colors.GoldLight
	list.ZIndex = 22
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	list.Parent = panel
	local entries = {}
	for uid, item in pairs(owned) do
		local piece = Armor.ById[item.id]
		if piece and piece.Slot == slot then
			table.insert(entries, { uid = uid, item = item, piece = piece })
		end
	end
	table.sort(entries, function(a, b)
		if a.uid == wornUid then
			return true
		elseif b.uid == wornUid then
			return false
		end
		if a.piece.Zone ~= b.piece.Zone then
			return a.piece.Zone > b.piece.Zone
		end
		if a.item.rarity ~= b.item.rarity then
			return a.item.rarity > b.item.rarity
		end
		return a.uid < b.uid
	end)
	if #entries == 0 then
		Theme.text({ Text = `No {string.lower(slot)} yet. Armor drops from enemies.`, TextSize = 22, Color = Theme.Colors.TextDim, Size = UDim2.new(1, 0, 0, 60), ZIndex = 23, Parent = list })
		return
	end
	local rowH = if small then 70 else 84
	for index, entry in ipairs(entries) do
		local isWorn = entry.uid == wornUid
		local row = Instance.new("Frame")
		row.BackgroundColor3 = if isWorn then Theme.Colors.WoodLight else Theme.Colors.WoodInset
		row.Size = UDim2.new(1, -10, 0, rowH)
		row.LayoutOrder = index
		row.ZIndex = 22
		Theme.corner(row, 6)
		Theme.paintRarity(Theme.stroke(row, Theme.Colors.GoldDark, 2), entry.item.rarity)
		ModelIcon.armor(entry.item.id, entry.item.rarity, { Size = UDim2.fromOffset(rowH - 8, rowH - 8), Position = UDim2.fromOffset(4, 4), AnchorPoint = Vector2.zero, ZIndex = 23, Parent = row })
		local x = rowH + 4
		local name = Theme.text({ Font = "Button", Text = `{entry.piece.Name}{if isWorn then "  (worn)" else ""}`, TextSize = 19, Align = "Left", Size = UDim2.new(0.42, -x, 0, 26), Position = UDim2.fromOffset(x, 6), ZIndex = 23, Parent = row })
		Theme.paintRarity(name, entry.item.rarity)
		Theme.text({ Text = `{Rarities.get(entry.item.rarity).Name} - {zoneName(entry.piece.ZoneId)}{if entry.item.locked then "  (locked)" else ""}`, TextSize = 15, Align = "Left", Color = Theme.Colors.TextDim, Size = UDim2.new(0.42, -x, 0, 20), Position = UDim2.fromOffset(x, 34), ZIndex = 23, Parent = row })
		local hp, defense = Armor.pieceStats(entry.item.id, entry.item.rarity, zone, false)
		compare(row, "HP", hp, if isWorn then nil else wornHP, UDim2.new(0.42, 6, 0, 8), UDim2.new(0.28, 0, 0, 24))
		compare(row, "Def", defense, if isWorn then nil else wornDef, UDim2.new(0.42, 6, 0, 36), UDim2.new(0.28, 0, 0, 24))
		local button = Button.new({ Text = if isWorn then "Unequip" else "Equip", Style = if isWorn then "secondary" else "go", TextSize = 20, Size = UDim2.new(0.26, -10, 0, Theme.TOUCH), Position = UDim2.new(1, -8, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 23, Parent = row, OnClick = function()
			local ok = if isWorn then request("UnequipArmor", slot) else request("EquipArmor", entry.uid)
			if ok then
				Sfx.play("UIClick")
				Overlay.close()
			end
		end })
		button.Instance.Name = "Choose"
		row.Parent = list
	end
end

----------------------------------------------------------------------------------------------------
-- Armor tab
----------------------------------------------------------------------------------------------------
local function slotLabel(): string
	return if filter.slot == 0 then "Slot: All" else `Slot: {Armor.SLOTS[filter.slot]}`
end

function ArmorPage.build(page: ScrollingFrame, ctx: any)
	overlayParent = ctx.Frame
	fixedPage(page)
	local small = Theme.isCompact()
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, Theme.TOUCH)
	header.ZIndex = 2
	header.Parent = page
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = header
	local refresh: () -> ()
	local slotButton = Button.new({ Text = slotLabel(), Style = "secondary", TextSize = 20, Size = UDim2.fromOffset(if small then 150 else 200, Theme.TOUCH), LayoutOrder = 1, ZIndex = 3, Parent = header, OnClick = function()
		filter.slot = (filter.slot + 1) % (#Armor.SLOTS + 1)
		refresh()
	end })
	local sortButton = Button.new({ Text = `Sort: {SORTS[filter.sort]}`, Style = "secondary", TextSize = 20, Size = UDim2.fromOffset(if small then 150 else 200, Theme.TOUCH), LayoutOrder = 2, ZIndex = 3, Parent = header, OnClick = function()
		filter.sort = filter.sort % #SORTS + 1
		refresh()
	end })
	local storage = Theme.text({ Font = "Number", Text = "", TextSize = 20, Size = UDim2.fromOffset(if small then 80 else 110, 28), LayoutOrder = 3, ZIndex = 3, Parent = header })
	Button.new({ Text = if small then "Best" else "Equip Best", Icon = "Star", Style = "go", Size = UDim2.fromOffset(if small then 120 else 190, Theme.TOUCH), LayoutOrder = 4, ZIndex = 3, Parent = header, OnClick = function()
		if request("EquipBestArmor") then
			Sfx.play("UIClick")
			Notifier.push({ Kind = "info", Text = "Best armor equipped for this zone", Icon = "Chest" })
		end
	end })

	local cell = if small then Vector2.new(100, 124) else Vector2.new(118, 146)
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
	layout.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = grid
	grid.Parent = page

	refresh = function()
		slotButton:SetText(slotLabel())
		sortButton:SetText(`Sort: {SORTS[filter.sort]}`)
		local owned = State.get("Armor") or {}
		storage.Text = `{count(owned)}/{Armor.Storage}`
		local scroll = grid.CanvasPosition
		for _, child in ipairs(grid:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		layout.CellSize = UDim2.fromOffset(cell.X, cell.Y)
		local zone = currentZone()
		local entries = {}
		for uid, item in pairs(owned) do
			local piece = Armor.ById[item.id]
			if piece and (filter.slot == 0 or piece.Slot == Armor.SLOTS[filter.slot]) then
				table.insert(entries, { uid = uid, item = item, piece = piece, score = Armor.score(item.id, item.rarity, zone), worn = ArmorPage.equippedSlot(uid) ~= nil })
			end
		end
		local sort = SORTS[filter.sort]
		table.sort(entries, function(a, b)
			if a.worn ~= b.worn then
				return a.worn
			end
			if sort == "Zone" and a.piece.Zone ~= b.piece.Zone then
				return a.piece.Zone > b.piece.Zone
			elseif sort == "Score" and a.score ~= b.score then
				return a.score > b.score
			end
			if a.item.rarity ~= b.item.rarity then
				return a.item.rarity > b.item.rarity
			end
			if a.piece.Zone ~= b.piece.Zone then
				return a.piece.Zone > b.piece.Zone
			end
			if a.piece.Slot ~= b.piece.Slot then
				return (table.find(Armor.SLOTS, a.piece.Slot) or 0) < (table.find(Armor.SLOTS, b.piece.Slot) or 0)
			end
			return a.uid < b.uid
		end)
		if #entries == 0 then
			layout.CellSize = UDim2.fromOffset(440, 140)
			local empty = Instance.new("Frame")
			empty.BackgroundTransparency = 1
			Icons.create("Chest", empty, { Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3 })
			Theme.text({ Text = if count(owned) > 0 then "No armor matches this filter." else "No armor yet. Enemies drop armor pieces.", TextSize = 20, Wrapped = true, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -20, 0, 52), Position = UDim2.new(0.5, 0, 0, 74), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3, Parent = empty })
			empty.Parent = grid
			return
		end
		for index, entry in ipairs(entries) do
			local button = Instance.new("TextButton")
			button.Name = entry.uid
			button.Text = ""
			button.AutoButtonColor = false
			button.BackgroundColor3 = if entry.item.rarity == #Rarities.List then Rarities.SECRET_CORE else Theme.Colors.WoodInset
			button.LayoutOrder = index
			button.ZIndex = 3
			Theme.corner(button, 8)
			Theme.paintRarity(Theme.stroke(button, Theme.Colors.GoldDark, 3), entry.item.rarity)
			ModelIcon.armor(entry.item.id, entry.item.rarity, { Size = UDim2.new(1, -8, 1, -34), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 4, Parent = button })
			local name = Theme.text({ Font = "Button", Text = entry.piece.Name, TextSize = 15, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.new(0.5, 0, 1, -5), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 4, Parent = button })
			Theme.paintRarity(name, entry.item.rarity)
			if entry.worn then
				badge(button, "Check", Theme.Colors.Good, UDim2.fromOffset(4, 4), Vector2.zero)
			end
			if entry.item.locked then
				badge(button, "Lock", Theme.Colors.WoodLight, UDim2.new(1, -4, 0, 4), Vector2.new(1, 0))
			end
			button.Activated:Connect(function()
				Sfx.play("UIClick")
				ArmorPage.detail(entry.uid)
			end)
			button.Parent = grid
		end
		grid.CanvasPosition = scroll
	end
	refresh()
	page:GetPropertyChangedSignal("Visible"):Connect(function()
		if not page.Visible then
			Overlay.close() -- another tab closes this tab's detail panel
		end
	end)
	State.changed("Armor", function()
		refresh()
	end)
	State.changed("EquippedArmor", function()
		refresh()
	end)
	Window.Closed:Connect(function(id: string)
		if id == "Inventory" then
			Overlay.close()
		end
	end)
end

function ArmorPage.setParent(frame: GuiObject)
	overlayParent = frame
end

return ArmorPage
