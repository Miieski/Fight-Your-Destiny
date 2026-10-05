--!strict
-- Teleport menu (docs/ui_redo_teleport_brief.txt part 2).
-- Page 1: scrollable zone list on the left (Hub first) with a large preview on the right.
-- Page 2: the 4 sub-zones of the chosen zone (Teleport / Boss Gate / locked with its Gold price).
-- The server validates every teleport (Net "Teleport"); the screen fades to black around it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.Parent.State)
local Notifier = require(script.Parent.Parent.Notifier)
local Kit = script.Parent.Parent.Kit
local Button = require(Kit.Button)
local Fade = require(Kit.Fade)
local Icons = require(Kit.Icons)
local ZoneVisibility = require(Kit.ZoneVisibility)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local ZonesPage = {}

local HUB = "Hub"
local LIST_WIDTH = 0.44 -- share of the content width used by the zone list
local ROW_HEIGHT = 72 -- design units (57 px on the smallest phone scale)
local HEADER_HEIGHT = 60

type Row = { row: TextButton, stroke: UIStroke, gradient: UIGradient, icon: Frame, title: TextLabel, status: TextLabel, lock: Frame }
type Card = { frame: Frame, stroke: UIStroke, iconSlot: Frame, icon: Frame?, title: TextLabel, status: TextLabel, button: any, boss: Frame }

local rows: { [string]: Row } = {}
local cards: { Card } = {}
local listPage: Frame
local zonePage: Frame
local preview: { icon: Frame, iconId: string?, title: TextLabel, description: TextLabel, boss: TextLabel, bossRow: Frame }
local header: { icon: Frame, iconId: string?, title: TextLabel, info: TextLabel }
local shownZone: string? = nil
local pendingZone: string? = nil -- zone page to show once the window has opened (signals are deferred)
local busy = false

-- data -----------------------------------------------------------------------------------------------
local function iconFor(id: string): string
	return if Icons.asset(id) then id else "Zones"
end

local function currentZone(): string
	return Players.LocalPlayer:GetAttribute("CurrentZone") or HUB
end

local function zoneOpen(zoneId: string): boolean
	local zone = Zones.ById[zoneId]
	local open = State.get("Zones") or {}
	return zone ~= nil and (zone.Index == 1 or open[zoneId] == true)
end

local function subZoneOpen(zoneId: string, n: number): boolean
	local open = State.get("SubZones") or {}
	return n == 1 or open[Zones.subZoneId(zoneId, n)] == true
end

-- fade + request --------------------------------------------------------------------------------------
local function teleport(zoneId: string, n: number?)
	if busy then
		return
	end
	busy = true
	Fade.cover()
	local ok, message = Net.request("Teleport", zoneId, n)
	if ok then
		Sfx.play("PortalEnter")
		Window.close()
	end
	Notifier.push({ Kind = if ok then "info" else "error", Text = tostring(message or "Teleport failed"), Icon = if ok then "Zones" else nil })
	Fade.reveal(ok)
	busy = false
end

-- page 1: zone list + preview -------------------------------------------------------------------------
local function setPreview(id: string)
	local isHub = id == HUB
	local zone = Zones.ById[id]
	if preview.iconId ~= id then
		local parent = preview.icon.Parent
		preview.icon:Destroy()
		-- a locked zone is a black silhouette with "?" (ZoneVisibility, no spoilers)
		preview.icon = ZoneVisibility.icon(iconFor(id), if isHub then nil else id, parent, { Size = UDim2.fromScale(0.62, 0.5), Position = UDim2.fromScale(0.5, 0.04), AnchorPoint = Vector2.new(0.5, 0) })
		preview.iconId = id
	end
	preview.title.Text = if isHub then "Hub" else `Zone {zone.Index} - {ZoneVisibility.displayName(id)}`
	preview.description.Text = if isHub then UIConfig.Text.HubDescription elseif ZoneVisibility.isRevealed(id) then ZoneVisibility.description(id) else ZoneVisibility.requirement(id)
	preview.bossRow.Visible = not isHub
	preview.boss.Text = if zone then `Boss: {ZoneVisibility.bossName(id)}` else ""
end

local function paintRow(id: string)
	local entry = rows[id]
	local colors = Theme.Colors
	local here = currentZone() == id
	local state, text
	if id == HUB then
		state, text = if here then "here" else "open", if here then UIConfig.Text.YouAreHere else "Safe zone"
	elseif Zones.NOT_BUILT[id] then
		state, text = "soon", UIConfig.Text.ComingSoon
	elseif not zoneOpen(id) then
		state, text = "locked", ZoneVisibility.requirement(id, true)
	else
		state, text = if here then "here" else "open", if here then UIConfig.Text.YouAreHere else "Unlocked"
	end
	local dim = state == "locked" or state == "soon"
	entry.stroke.Color = if state == "here" then colors.Gold else colors.GoldDark
	entry.stroke.Thickness = if state == "here" then 3.5 else 2
	entry.gradient.Color = if dim then ColorSequence.new(colors.WoodInset, colors.WoodLine) else ColorSequence.new(colors.WoodLight, colors.WoodTop)
	entry.title.TextColor3 = if dim then colors.TextDim else colors.Gold
	entry.status.Text = text
	entry.status.TextColor3 = if state == "here" then colors.Good elseif state == "locked" then colors.Bad else colors.TextDim
	entry.lock.Visible = state == "locked"
	if id ~= HUB then
		entry.title.Text = ZoneVisibility.displayName(id)
		local hidden = not ZoneVisibility.isRevealed(id)
		if entry.hidden ~= hidden then
			entry.hidden = hidden
			if hidden then
				ZoneVisibility.applySilhouette(entry.icon)
			else
				ZoneVisibility.removeSilhouette(entry.icon)
			end
		end
	end
	Icons.setFaded(entry.icon, if dim and not entry.hidden then 0.45 else 0)
	if preview.iconId == id then
		preview.iconId = nil -- redraw the preview (it may have been revealed)
		setPreview(id)
	end
end

local function refreshList()
	for id in pairs(rows) do
		paintRow(id)
	end
end

local function makeRow(parent: Instance, id: string, name: string, order: number)
	local row = Instance.new("TextButton")
	row.Name = id
	row.Text = ""
	row.AutoButtonColor = false
	row.Size = UDim2.new(1, -14, 0, ROW_HEIGHT)
	row.LayoutOrder = order
	row.BackgroundColor3 = Color3.new(1, 1, 1)
	Theme.corner(row, 8)
	local gradient = Theme.gradient(row, Theme.Colors.WoodLight, Theme.Colors.WoodTop)
	local stroke = Theme.stroke(row, Theme.Colors.GoldDark, 2)
	local icon = Icons.create(iconFor(id), row, { Size = UDim2.fromOffset(ROW_HEIGHT - 8, ROW_HEIGHT - 8), Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	local textLeft = ROW_HEIGHT + 4
	local title = Theme.text({ Name = "Title", Font = "Title", Text = name, TextSize = 26, Align = "Left", Color = Theme.Colors.Gold, Size = UDim2.new(1, -(textLeft + 44), 0.48, 0), Position = UDim2.new(0, textLeft, 0, 6), Parent = row })
	local status = Theme.text({ Name = "Status", Text = "", TextSize = 18, Align = "Left", Color = Theme.Colors.TextDim, Size = UDim2.new(1, -(textLeft + 44), 0.34, 0), Position = UDim2.new(0, textLeft, 0.56, 0), Parent = row })
	local lock = Icons.create("Lock", row, { Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -8, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) })
	row.MouseEnter:Connect(function()
		setPreview(id)
	end)
	row.Activated:Connect(function()
		Sfx.play("UIClick")
		if id == HUB then
			teleport(HUB, nil)
		elseif Zones.NOT_BUILT[id] then
			Notifier.push({ Kind = "info", Text = `{ZoneVisibility.displayName(id)}: {UIConfig.Text.ComingSoon}` })
		elseif not ZoneVisibility.isRevealed(id) then
			-- no sub-zone page for a hidden zone: it would show its names
			Sfx.play("Denied")
			Notifier.push({ Kind = "error", Text = ZoneVisibility.requirement(id), Icon = "Lock" })
		else
			ZonesPage.showZone(id)
		end
	end)
	row.Parent = parent
	rows[id] = { row = row, stroke = stroke, gradient = gradient, icon = icon, title = title, status = status, lock = lock }
end

-- page 2: sub-zone cards ------------------------------------------------------------------------------
local function paintCard(card: Card, zoneId: string, n: number)
	local zone = Zones.ById[zoneId]
	local colors = Theme.Colors
	local id = Zones.subZoneId(zoneId, n)
	local isBoss = n == Zones.BOSS_SUBZONE
	local here = Players.LocalPlayer:GetAttribute("CurrentSubZone") == id
	local open = zoneOpen(zoneId) and subZoneOpen(zoneId, n)
	if card.icon then
		card.icon:Destroy()
	end
	card.icon = Icons.create(iconFor(id), card.iconSlot)
	card.title.Text = ZoneVisibility.subZoneName(zoneId, n)
	card.boss.Visible = isBoss
	card.stroke.Color = if isBoss then colors.DangerLight elseif here then colors.Gold else colors.GoldDark
	card.stroke.Thickness = if isBoss or here then 3.5 else 2.5
	local button = card.button
	if not zoneOpen(zoneId) then
		card.status.Text = UIConfig.Text.ZoneLocked
		card.status.TextColor3 = colors.Bad
		button:SetText("Locked")
		button:SetStyle("secondary")
		button:SetEnabled(false)
	elseif here then
		card.status.Text = UIConfig.Text.YouAreHere
		card.status.TextColor3 = colors.Good
		button:SetText(UIConfig.Text.YouAreHere)
		button:SetStyle("primary")
		button:SetEnabled(false)
	elseif open then
		card.status.Text = if isBoss then "Boss room entrance" else "Unlocked"
		card.status.TextColor3 = colors.TextDim
		button:SetText(if isBoss then UIConfig.Text.BossGate else UIConfig.Text.Teleport)
		button:SetStyle(if isBoss then "danger" else "go")
		button:SetEnabled(true)
	else
		card.status.Text = `Gate: {Format.number(Zones.subZonePrice(zoneId, n))} Gold`
		card.status.TextColor3 = colors.Bad
		button:SetText("Locked")
		button:SetStyle("secondary")
		button:SetEnabled(false)
	end
	Icons.setFaded(card.icon :: Frame, if open then 0 else 0.5)
end

local function makeCard(parent: Instance, n: number): Card
	local frame = Instance.new("Frame")
	frame.Name = "SubZone" .. n
	frame.Size = UDim2.new(0.25, -9, 1, 0)
	frame.LayoutOrder = n
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	Theme.corner(frame, 8)
	Theme.gradient(frame, Theme.Colors.WoodLight, Theme.Colors.WoodBottom)
	local stroke = Theme.stroke(frame, Theme.Colors.GoldDark, 2.5)
	local iconSlot = Instance.new("Frame")
	iconSlot.Name = "IconSlot"
	iconSlot.BackgroundTransparency = 1
	iconSlot.AnchorPoint = Vector2.new(0.5, 0)
	iconSlot.Position = UDim2.fromScale(0.5, 0.04)
	iconSlot.Size = UDim2.fromScale(0.86, 0.44)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = iconSlot
	iconSlot.Parent = frame
	local title = Theme.text({ Name = "Title", Font = "Title", Text = "", TextSize = 24, Wrapped = true, Color = Theme.Colors.Gold, Size = UDim2.new(1, -12, 0.15, 0), Position = UDim2.new(0.5, 0, 0.49, 0), AnchorPoint = Vector2.new(0.5, 0), Parent = frame })
	local status = Theme.text({ Name = "Status", Text = "", TextSize = 17, Size = UDim2.new(1, -12, 0.09, 0), Position = UDim2.new(0.5, 0, 0.65, 0), AnchorPoint = Vector2.new(0.5, 0), Parent = frame })
	local boss = Instance.new("Frame")
	boss.Name = "BossTag"
	boss.BackgroundColor3 = Theme.Colors.DangerDark
	boss.Size = UDim2.fromOffset(74, 26)
	boss.Position = UDim2.fromOffset(6, 6)
	Theme.corner(boss, 6)
	Theme.stroke(boss, Theme.Colors.GoldLight, 1.5)
	Theme.text({ Font = "Button", Text = "BOSS", TextSize = 18, Size = UDim2.fromScale(1, 0.9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = boss })
	boss.Parent = frame
	local card: Card
	local button = Button.new({ Text = UIConfig.Text.Teleport, Style = "go", TextSize = 22, Size = UDim2.new(1, -14, 0, Theme.TOUCH), Position = UDim2.new(0.5, 0, 1, -7), AnchorPoint = Vector2.new(0.5, 1), Parent = frame, OnClick = function()
		if shownZone then
			teleport(shownZone, n)
		end
	end })
	frame.Parent = parent
	card = { frame = frame, stroke = stroke, iconSlot = iconSlot, icon = nil, title = title, status = status, button = button, boss = boss }
	return card
end

local function refreshZone()
	local zoneId = shownZone
	if not zoneId then
		return
	end
	local zone = Zones.ById[zoneId]
	if header.iconId ~= zoneId then
		local parent = header.icon.Parent
		header.icon:Destroy()
		header.icon = Icons.create(iconFor(zoneId), parent, { Size = UDim2.fromOffset(HEADER_HEIGHT, HEADER_HEIGHT), Position = UDim2.new(0.5, -150, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) })
		header.iconId = zoneId
	end
	header.title.Text = `Zone {zone.Index} - {ZoneVisibility.displayName(zoneId)}`
	header.info.Text = if zoneOpen(zoneId) then `Boss: {ZoneVisibility.bossName(zoneId)}` else ZoneVisibility.requirement(zoneId)
	header.info.TextColor3 = if zoneOpen(zoneId) then Theme.Colors.TextDim else Theme.Colors.Bad
	for n, card in ipairs(cards) do
		paintCard(card, zoneId, n)
	end
end

function ZonesPage.showList()
	shownZone = nil
	zonePage.Visible = false
	listPage.Visible = true
	refreshList()
	setPreview(if Zones.ById[currentZone()] then currentZone() else HUB)
end

function ZonesPage.showZone(zoneId: string)
	if not Zones.ById[zoneId] then
		return
	end
	shownZone = zoneId
	listPage.Visible = false
	zonePage.Visible = true
	refreshZone()
end

-- Opens the window (on a zone's sub-zones when zoneId is given), e.g. from a hub portal.
function ZonesPage.open(zoneId: string?)
	pendingZone = if zoneId and Zones.ById[zoneId] and not Zones.NOT_BUILT[zoneId] then zoneId else nil
	if Window.isOpen("Zones") then
		if pendingZone then
			ZonesPage.showZone(pendingZone)
			pendingZone = nil
		end
		return
	end
	Window.open("Zones")
end

function ZonesPage.build(ctx: any)
	-- the Main page becomes a plain container for the two pages
	local main = ctx.Pages.Main :: ScrollingFrame
	for _, child in ipairs(main:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	main.ScrollingEnabled = false
	main.AutomaticCanvasSize = Enum.AutomaticSize.None
	main.CanvasSize = UDim2.new()
	main.ScrollBarThickness = 0

	listPage = Instance.new("Frame")
	listPage.Name = "ZoneList"
	listPage.BackgroundTransparency = 1
	listPage.Size = UDim2.fromScale(1, 1)
	listPage.Parent = main
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(8, 8)
	list.Size = UDim2.new(LIST_WIDTH, -12, 1, -16)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = Theme.Colors.GoldLight
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 2)
	pad.Parent = list
	list.Parent = listPage
	makeRow(list, HUB, "Hub", 0)
	for _, zone in ipairs(Zones.List) do
		makeRow(list, zone.Id, ZoneVisibility.displayName(zone.Id), zone.Index)
	end

	local side = Instance.new("Frame")
	side.Name = "Preview"
	side.Position = UDim2.new(LIST_WIDTH, 2, 0, 8)
	side.Size = UDim2.new(1 - LIST_WIDTH, -10, 1, -16)
	side.BackgroundColor3 = Theme.Colors.WoodLine
	side.BackgroundTransparency = 0.35
	Theme.corner(side, 8)
	Theme.stroke(side, Theme.Colors.GoldDark, 2)
	side.Parent = listPage
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = side
	local bossRow = Instance.new("Frame")
	bossRow.Name = "Boss"
	bossRow.BackgroundTransparency = 1
	bossRow.AnchorPoint = Vector2.new(0.5, 0)
	bossRow.Position = UDim2.fromScale(0.5, 0.86)
	bossRow.Size = UDim2.fromScale(0.9, 0.11)
	local bossLayout = Instance.new("UIListLayout")
	bossLayout.FillDirection = Enum.FillDirection.Horizontal
	bossLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bossLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	bossLayout.Padding = UDim.new(0, 8)
	bossLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bossLayout.Parent = bossRow
	bossRow.Parent = side
	local skullIcon = Icons.create("Skull", bossRow, { Size = UDim2.new(0, 0, 1, 0) })
	skullIcon.LayoutOrder = 1
	preview = {
		icon = Icons.create("Zones", holder, { Size = UDim2.fromScale(0.62, 0.5), Position = UDim2.fromScale(0.5, 0.04), AnchorPoint = Vector2.new(0.5, 0) }),
		iconId = nil,
		title = Theme.text({ Font = "Title", Text = "", TextSize = 32, Color = Theme.Colors.Gold, Size = UDim2.new(0.92, 0, 0.1, 0), Position = UDim2.new(0.5, 0, 0.56, 0), AnchorPoint = Vector2.new(0.5, 0), Parent = side }),
		description = Theme.text({ Text = "", TextSize = 20, Wrapped = true, Size = UDim2.new(0.9, 0, 0.18, 0), Position = UDim2.new(0.5, 0, 0.67, 0), AnchorPoint = Vector2.new(0.5, 0), Parent = side }),
		boss = Theme.text({ Font = "Button", Text = "", TextSize = 24, Color = Theme.Colors.DangerLight, Size = UDim2.new(0.75, 0, 0.85, 0), LayoutOrder = 2, Parent = bossRow }),
		bossRow = bossRow,
	}

	zonePage = Instance.new("Frame")
	zonePage.Name = "SubZones"
	zonePage.BackgroundTransparency = 1
	zonePage.Size = UDim2.fromScale(1, 1)
	zonePage.Visible = false
	zonePage.Parent = main
	local top = Instance.new("Frame")
	top.Name = "Header"
	top.BackgroundTransparency = 1
	top.Position = UDim2.fromOffset(8, 6)
	top.Size = UDim2.new(1, -16, 0, HEADER_HEIGHT)
	top.Parent = zonePage
	Button.new({ Name = "Back", Text = UIConfig.Text.Back, Icon = "Arrow", Style = "wood", TextSize = 22, Size = UDim2.fromOffset(140, Theme.TOUCH), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = top, OnClick = ZonesPage.showList })
	local back = top:FindFirstChild("Back")
	local arrow = back and back:FindFirstChild("Icon", true)
	if arrow and arrow:IsA("GuiObject") then
		arrow.Rotation = 180
	end
	header = {
		icon = Icons.create("Zones", top, { Size = UDim2.fromOffset(HEADER_HEIGHT, HEADER_HEIGHT), Position = UDim2.new(0.5, -150, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) }),
		iconId = nil,
		title = Theme.text({ Font = "Title", Text = "", TextSize = 30, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(0.5, 140, 0.56, 0), Position = UDim2.new(0.5, -140, 0, 2), Parent = top }),
		info = Theme.text({ Text = "", TextSize = 18, Align = "Left", Size = UDim2.new(0.5, 140, 0.36, 0), Position = UDim2.new(0.5, -140, 0.6, 0), Parent = top }),
	}
	local row = Instance.new("Frame")
	row.Name = "Cards"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(8, HEADER_HEIGHT + 14)
	row.Size = UDim2.new(1, -16, 1, -(HEADER_HEIGHT + 22))
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Horizontal
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardLayout.Padding = UDim.new(0, 12)
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Parent = row
	row.Parent = zonePage
	for n = 1, Zones.SUBZONE_COUNT do
		cards[n] = makeCard(row, n)
	end

	-- keep both pages current
	local function refresh()
		if zonePage.Visible then
			refreshZone()
		else
			refreshList()
		end
	end
	State.changed("Zones", refresh)
	State.changed("SubZones", refresh)
	Players.LocalPlayer:GetAttributeChangedSignal("CurrentSubZone"):Connect(refresh)
	Window.Opened:Connect(function(id)
		if id == "Zones" then
			if pendingZone then
				ZonesPage.showZone(pendingZone)
				pendingZone = nil
			else
				ZonesPage.showList()
			end
		end
	end)
	ZonesPage.showList()
end

return ZonesPage
