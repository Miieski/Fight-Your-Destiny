--!strict
-- Shop > Weapons (docs/weapon_shop_brief.txt part 2): 8 category tabs (a column on the left; a scrolling row on
-- top on phones), the category's 12 weapons as cards in zone order, a header with Gold, the pity counter and
-- the Odds button. A weapon of a locked zone is a black silhouette with "?" marks: no name, price, stats or
-- model. Buy asks the server (BuyWeapon) and plays the case opening (UI/CaseOpening) with its answer.
--   WeaponShopPage.build(page, ctx)   (Windows.luau, Shop window, "Weapons" tab)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local WeaponCategories = require(ReplicatedStorage.GameSystem.Config.WeaponCategories)
local WeaponRarities = require(ReplicatedStorage.GameSystem.Config.WeaponRarities)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.Parent.State)
local CaseOpening = require(script.Parent.Parent.CaseOpening)
local Notifier = require(script.Parent.Parent.Notifier)
local Kit = script.Parent.Parent.Kit
local Button = require(Kit.Button)
local Icons = require(Kit.Icons)
local Panel = require(Kit.Panel)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local WeaponShopPage = {}

local CONFIG = UIConfig.WeaponShop
local LOCKED = CONFIG.Locked
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local IMAGE_SIZE = UDim2.fromScale(1.14, 1.14) -- Icons IMAGE_BLEED

type Card = {
	weapon: any,
	frame: TextButton,
	iconBox: Frame,
	zoneRow: Frame,
	priceRow: Frame,
	image: ImageLabel?,
	marks: Frame,
	name: TextLabel,
	price: TextLabel,
	owned: TextLabel,
	ownedBadge: Frame,
	unlock: TextLabel,
	buy: any,
	locked: boolean?,
}

local cards: { [string]: Card } = {}
local grids: { [string]: ScrollingFrame } = {}
local tabs: { [string]: { frame: TextButton, gradient: UIGradient, stroke: UIStroke } } = {}
local selected = WeaponCategories.List[1].Id
local requesting = false
local lastRequest = -math.huge
local pendingReveal: { [string]: boolean } = {}
local knownZones: { [string]: boolean } = {}
local container: Frame? = nil
local overlayParent: Instance? = nil
local overlay: Frame? = nil
local previewConn: RBXScriptConnection? = nil

local function zoneOpen(weapon: any): boolean
	local zones = State.get("Zones") or {}
	return zones[weapon.ZoneId] == true
end

local function ownedCount(weaponId: string): number
	local count = 0
	for _, item in pairs(State.get("Weapons") or {}) do
		if item.id == weaponId then
			count += 1
		end
	end
	return count
end

----------------------------------------------------------------------------------------------------
-- overlays inside the Shop window (preview, odds, locked tooltip)
----------------------------------------------------------------------------------------------------
local function closeOverlay()
	if previewConn then
		previewConn:Disconnect()
		previewConn = nil
	end
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
end

local function openOverlay(size: Vector2): Frame
	closeOverlay()
	local holder = Instance.new("Frame")
	holder.Name = "ShopOverlay"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 20
	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = BLACK
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

local function line(parent: Instance, text: string, order: number, color: Color3?, size: number?): TextLabel
	return Theme.text({ Text = text, TextSize = size or 19, Wrapped = true, Align = "Left", Color = color, Size = UDim2.new(1, 0, 0, (size or 19) + 9), LayoutOrder = order, ZIndex = 23, Parent = parent })
end

local function column(parent: Instance, position: UDim2, size: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Position = position
	frame.Size = size
	frame.ZIndex = 22
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	frame.Parent = parent
	return frame
end

local buy: (any) -> ()

-- A rotating 3D model of the weapon (drag to turn it) and its stats. Only for unlocked weapons.
local function preview(weapon: any)
	local panel = openOverlay(Vector2.new(820, 470))
	local h = panel.AbsoluteSize.Y / Theme.getScale()
	local view = Instance.new("ViewportFrame")
	view.Name = "Model"
	view.BackgroundColor3 = Theme.Colors.WoodInset
	view.Ambient = Color3.fromRGB(170, 160, 150)
	view.LightColor = Color3.fromRGB(255, 244, 230)
	view.LightDirection = Vector3.new(-1, -1, -1)
	local side = math.min(h - 32, 330)
	view.Size = UDim2.fromOffset(side, side)
	view.Position = UDim2.fromOffset(16, 16)
	view.ZIndex = 22
	Theme.corner(view, 8)
	Theme.stroke(view, Theme.Colors.GoldDark, 2)
	view.Parent = panel
	Theme.text({ Text = "Drag to turn", TextSize = 16, Color = Theme.Colors.TextDim, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 23, Parent = view })

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local source = assets and assets:FindFirstChild("Weapons") and assets.Weapons:FindFirstChild(weapon.Id)
	local model = Instance.new("Model")
	local radius = 3
	if source then
		for _, child in ipairs(source:GetChildren()) do
			child:Clone().Parent = model
		end
		local cf, size = model:GetBoundingBox()
		radius = math.max(size.Magnitude / 2, 0.5)
		model.WorldPivot = CFrame.new(cf.Position) -- turn around the middle of the weapon
		model:PivotTo(CFrame.new())
	end
	model.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -radius * 2.9), Vector3.zero)
	camera.Parent = view
	view.CurrentCamera = camera
	local base = model:GetPivot()
	local yaw, dragging, lastX = 0, false, 0
	view.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, lastX = true, input.Position.X
		end
	end)
	view.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	view.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			yaw += (input.Position.X - lastX) * 0.012
			lastX = input.Position.X
		end
	end)
	previewConn = RunService.RenderStepped:Connect(function(dt)
		if not dragging then
			yaw += dt * math.pi * 2 / CONFIG.PreviewSpinSeconds
		end
		model:PivotTo(CFrame.Angles(0, yaw, 0) * base)
	end)

	local category = WeaponCategories.ById[weapon.Category]
	local common, best = WeaponRarities.get(1), WeaponRarities.get(#WeaponRarities.List)
	local zone = Zones.ById[weapon.ZoneId]
	local small = Theme.isCompact() -- phones: smaller lines so the Buy button keeps its own space
	local text = if small then 15 else 19
	local info = column(panel, UDim2.fromOffset(side + 32, 14), UDim2.new(1, -side - 48 - Theme.TOUCH, 1, -Theme.TOUCH - 40))
	line(info, weapon.Name, 1, Theme.Colors.Gold, if small then 24 else 30).FontFace = Theme.Fonts.Title
	line(info, `{category.Name} - {category.Shape}: {category.Special}`, 2, Theme.Colors.TextDim, text - 1)
	line(info, `Damage per hit (Common): {Format.number(Stats.weaponDamage(weapon.Id, 1))}`, 3, nil, text)
	line(info, `Hits per second: {category.HitsPerSecond}   |   Range: {category.Range} studs`, 4, nil, text)
	line(info, `Element: {weapon.Element} - {Weapons.ELEMENT_EFFECTS[weapon.Element] or ""}`, 5, nil, text)
	line(info, `Proc chance: {math.round(common.ElementProc * 100)}% (Common) to {math.round(best.ElementProc * 100)}% (Secret)`, 6, Theme.Colors.TextDim, text - 2)
	line(info, `Zone Boost in {zone.Name}: +{math.round(common.ZoneBoost * 100)}% (Common) to +{math.round(best.ZoneBoost * 100)}% (Secret)`, 7, nil, text)
	line(info, `Price: {Format.number(Weapons.price(weapon.Zone))} Gold - rarity rolled on purchase`, 8, Theme.Colors.Gold, text)
	local buyButton = Button.new({ Name = "Buy", Text = "Buy", Icon = "Gold", Style = "primary", Size = UDim2.fromOffset(if small then 180 else 220, Theme.TOUCH), Position = UDim2.new(1, -16, 1, -14), AnchorPoint = Vector2.new(1, 1), ZIndex = 23, Parent = panel, OnClick = function()
		buy(weapon)
	end })
	if (State.get("Gold") or 0) < Weapons.price(weapon.Zone) then
		buyButton:SetStyle("disabled")
	end
end

-- The odds of every rarity and the pity rules (Config/WeaponRarities).
local function odds()
	local panel = openOverlay(Vector2.new(760, 520))
	Theme.text({ Font = "Title", Text = "Odds", TextSize = 34, Color = Theme.Colors.Gold, Size = UDim2.new(1, -140, 0, 42), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 23, Parent = panel })
	local tableFrame = Instance.new("ScrollingFrame")
	tableFrame.BackgroundTransparency = 1
	tableFrame.BorderSizePixel = 0
	tableFrame.Position = UDim2.fromOffset(16, 60)
	tableFrame.Size = UDim2.new(1, -32, 1, -76)
	tableFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tableFrame.CanvasSize = UDim2.new()
	tableFrame.ScrollBarThickness = 6
	tableFrame.ScrollBarImageColor3 = Theme.Colors.GoldLight
	tableFrame.ZIndex = 22
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = tableFrame
	tableFrame.Parent = panel
	local COLUMNS = { { "Rarity", 0.3 }, { "Chance", 0.17 }, { "Damage", 0.17 }, { "Zone Boost", 0.18 }, { "Element", 0.18 } }
	local function row(order: number, values: { string }, tier: number?)
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = if order % 2 == 0 then Theme.Colors.WoodInset else Theme.Colors.WoodTop
		frame.BackgroundTransparency = if tier then 0.2 else 1
		frame.Size = UDim2.new(1, -8, 0, 34)
		frame.LayoutOrder = order
		frame.ZIndex = 22
		Theme.corner(frame, 4)
		local x = 0
		for i, column_ in ipairs(COLUMNS) do
			local label = Theme.text({ Font = if tier then "Body" else "Button", Text = values[i], TextSize = 19, Align = if i == 1 then "Left" else "Center", Color = if tier then nil else Theme.Colors.Gold, Size = UDim2.new(column_[2], -8, 1, 0), Position = UDim2.new(x, if i == 1 then 34 else 4, 0, 0), ZIndex = 23, Parent = frame })
			if tier and i == 1 then
				Theme.paintRarity(label, tier)
				local swatch = Instance.new("Frame")
				swatch.Size = UDim2.fromOffset(20, 20)
				swatch.Position = UDim2.new(0, 8, 0.5, 0)
				swatch.AnchorPoint = Vector2.new(0, 0.5)
				swatch.ZIndex = 23
				Theme.corner(swatch, 4)
				Theme.paintRarity(swatch, tier)
				swatch.Parent = frame
			end
			x += column_[2]
		end
		frame.Parent = tableFrame
	end
	row(0, { "Rarity", "Chance", "Damage", "Zone Boost", "Element proc" }, nil)
	for tier, rarity in ipairs(WeaponRarities.List) do
		row(tier, { rarity.Name, WeaponRarities.percentText(rarity.ShopOdds), `x{rarity.DamageMult}`, `+{math.round(rarity.ZoneBoost * 100)}%`, `{math.round(rarity.ElementProc * 100)}%` }, tier)
	end
	local order = 20
	for _, pity in ipairs(WeaponRarities.Pity) do
		order += 1
		local mine = State.get(pity.Key) or 0
		local text = `Pity: after {pity.After} purchases in a row without {pity.Label}, the next one is guaranteed {pity.Label}. You: {math.min(mine, pity.After)}/{pity.After}.`
		local label = Theme.text({ Text = text, TextSize = 18, Wrapped = true, Align = "Left", Color = Theme.Colors.TextDim, Size = UDim2.new(1, -8, 0, 46), LayoutOrder = order, ZIndex = 23, Parent = tableFrame })
		label.LayoutOrder = order
	end
end

-- Tapping a locked card: only the zone's requirements, never the weapon.
local function lockedTip(weapon: any)
	local panel = openOverlay(Vector2.new(480, 230))
	local zone = Zones.ById[weapon.ZoneId]
	Theme.text({ Font = "Title", Text = `{LOCKED} - {zone.Name}`, TextSize = 30, Color = Theme.Colors.Gold, Size = UDim2.new(1, -140, 0, 40), Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 23, Parent = panel })
	Theme.text({ Text = `Unlock {zone.Name} to reveal this weapon.\n{Zones.requirementText(zone.Id)}`, TextSize = 20, Wrapped = true, Size = UDim2.new(1, -40, 1, -80), Position = UDim2.new(0.5, 0, 0, 62), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 23, Parent = panel })
end

----------------------------------------------------------------------------------------------------
-- cards
----------------------------------------------------------------------------------------------------
local function refreshCard(card: Card)
	local weapon = card.weapon
	local open = zoneOpen(weapon)
	card.locked = not open
	if card.image then
		card.image.ImageColor3 = if open then WHITE else BLACK
	end
	card.marks.Visible = not open
	card.name.Text = if open then weapon.Name else LOCKED
	card.price.Text = if open then Format.number(Weapons.price(weapon.Zone)) else LOCKED
	local count = if open then ownedCount(weapon.Id) else 0
	card.ownedBadge.Visible = count > 0
	card.owned.Text = `Owned: {count}`
	card.unlock.Visible = not open
	card.buy.Instance.Visible = open
	if open then
		local busy = requesting or CaseOpening.isActive()
		card.buy:SetEnabled(not busy)
		if not busy then
			-- not enough Gold: grey but still pressable, so the player gets the "Not enough Gold" toast
			card.buy:SetStyle(if (State.get("Gold") or 0) >= Weapons.price(weapon.Zone) then "primary" else "disabled")
		end
	end
end

local function refreshAll()
	for _, card in pairs(cards) do
		refreshCard(card)
	end
end

-- The silhouette flips to the colored icon (a zone was just unlocked).
local function flip(card: Card)
	local image = card.image
	Sfx.play("Unlock")
	if not image then
		refreshCard(card)
		return
	end
	local close = TweenService:Create(image, TweenInfo.new(CONFIG.RevealSeconds / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromScale(0, IMAGE_SIZE.Y.Scale) })
	close.Completed:Connect(function()
		refreshCard(card)
		TweenService:Create(image, TweenInfo.new(CONFIG.RevealSeconds / 2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = IMAGE_SIZE }):Play()
	end)
	card.marks.Visible = false
	close:Play()
end

-- Normal card: icon on top, then name / zone / price, Buy at the bottom. Phones: a wide, short card with the
-- icon on the left and the texts on its right, so a whole row (with its Buy buttons) fits on the screen.
local function layoutCard(card: Card)
	local compact = Theme.isCompact()
	local iconBox, name, zoneRow, priceRow = card.iconBox, card.name, card.zoneRow, card.priceRow
	if compact then
		local icon = 84
		iconBox.SizeConstraint = Enum.SizeConstraint.RelativeXY
		iconBox.AnchorPoint = Vector2.zero
		iconBox.Position = UDim2.fromOffset(8, 6)
		iconBox.Size = UDim2.fromOffset(icon, icon)
		local x = icon + 14
		name.AnchorPoint, zoneRow.AnchorPoint, priceRow.AnchorPoint = Vector2.zero, Vector2.zero, Vector2.zero
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Position, name.Size = UDim2.fromOffset(x, 8), UDim2.new(1, -(x + 6), 0, 24)
		zoneRow.Position, zoneRow.Size = UDim2.fromOffset(x, 34), UDim2.new(1, -(x + 6), 0, 22)
		priceRow.Position, priceRow.Size = UDim2.fromOffset(x, 58), UDim2.new(1, -(x + 6), 0, 24)
		card.ownedBadge.Position = UDim2.fromOffset(4, 4)
		card.ownedBadge.AnchorPoint = Vector2.zero
	else
		iconBox.SizeConstraint = Enum.SizeConstraint.RelativeYY
		iconBox.AnchorPoint = Vector2.new(0.5, 0)
		iconBox.Position = UDim2.new(0.5, 0, 0, 8)
		iconBox.Size = UDim2.fromScale(0.39, 0.39)
		name.AnchorPoint, zoneRow.AnchorPoint, priceRow.AnchorPoint = Vector2.new(0.5, 0), Vector2.new(0.5, 0), Vector2.new(0.5, 0)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.Position, name.Size = UDim2.new(0.5, 0, 1, -(Theme.TOUCH + 88)), UDim2.new(1, -12, 0, 24)
		zoneRow.Position, zoneRow.Size = UDim2.new(0.5, 0, 1, -(Theme.TOUCH + 62)), UDim2.new(1, -12, 0, 22)
		priceRow.Position, priceRow.Size = UDim2.new(0.5, 0, 1, -(Theme.TOUCH + 38)), UDim2.new(1, -12, 0, 24)
		card.ownedBadge.Position = UDim2.new(1, -6, 0, 6)
		card.ownedBadge.AnchorPoint = Vector2.new(1, 0)
	end
end

local function makeCard(weapon: any, parent: Instance, order: number): Card
	local frame = Instance.new("TextButton")
	frame.Name = weapon.Id
	frame.Text = ""
	frame.AutoButtonColor = false
	frame.BackgroundColor3 = WHITE
	frame.LayoutOrder = order
	Theme.corner(frame, 8)
	Theme.gradient(frame, Theme.Colors.WoodLight, Theme.Colors.WoodBottom)
	Theme.stroke(frame, Theme.Colors.GoldDark, 2)
	local W = CONFIG.CardSize.X

	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.BackgroundTransparency = 1
	iconBox.Parent = frame
	-- a soft light disc behind the icon (it keeps the black silhouette of a locked weapon readable)
	local spot = Instance.new("Frame")
	spot.Name = "Spot"
	spot.AnchorPoint = Vector2.new(0.5, 0.5)
	spot.Position = UDim2.fromScale(0.5, 0.5)
	spot.Size = UDim2.fromScale(1.05, 1.05)
	spot.BackgroundColor3 = Theme.Colors.TextDim
	spot.BackgroundTransparency = 0.55
	Theme.round(spot)
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) })
	fade.Rotation = 90
	fade.Parent = spot
	spot.Parent = iconBox
	local icon = Icons.create(weapon.Icon or weapon.Category, iconBox, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	local image = icon:FindFirstChild("Image") :: ImageLabel?

	local marks = Instance.new("Frame")
	marks.Name = "Marks"
	marks.BackgroundTransparency = 1
	marks.Size = UDim2.fromScale(1, 1)
	marks.Parent = iconBox
	marks.ZIndex = 3
	Theme.text({ Font = "Title", Text = "?", TextSize = 70, Size = UDim2.fromScale(0.7, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 3, Parent = marks })
	local small1 = Theme.text({ Font = "Title", Text = "?", TextSize = 34, Size = UDim2.fromScale(0.35, 0.4), Position = UDim2.fromScale(0.12, 0.16), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 2, Parent = marks })
	small1.Rotation = -18
	local small2 = Theme.text({ Font = "Title", Text = "?", TextSize = 34, Size = UDim2.fromScale(0.35, 0.4), Position = UDim2.fromScale(0.9, 0.82), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 2, Parent = marks })
	small2.Rotation = 16

	local ownedBadge = Instance.new("Frame")
	ownedBadge.Name = "Owned"
	ownedBadge.BackgroundColor3 = Theme.Colors.WoodLine
	ownedBadge.Size = UDim2.fromOffset(84, 24)
	ownedBadge.Position = UDim2.new(1, -6, 0, 6)
	ownedBadge.AnchorPoint = Vector2.new(1, 0)
	ownedBadge.ZIndex = 3
	Theme.corner(ownedBadge, 12)
	Theme.stroke(ownedBadge, Theme.Colors.GoldDark, 1.5)
	ownedBadge.Parent = frame
	local owned = Theme.text({ Font = "Button", Text = "", TextSize = 15, Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4, Parent = ownedBadge })

	-- name, zone and price rows sit right above the Buy button
	local name = Theme.text({ Name = "WeaponName", Font = "Button", Text = "", TextSize = 19, Parent = frame })
	local zoneRow = Instance.new("Frame")
	zoneRow.BackgroundTransparency = 1
	zoneRow.Parent = frame
	Icons.create(weapon.ZoneId, zoneRow, { Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	Theme.text({ Text = Zones.ById[weapon.ZoneId].Name, TextSize = 16, Color = Theme.Colors.TextDim, Align = "Left", Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(30, 0), Parent = zoneRow })
	local priceRow = Instance.new("Frame")
	priceRow.BackgroundTransparency = 1
	priceRow.Parent = frame
	Icons.create("Gold", priceRow, { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	local price = Theme.text({ Font = "Number", Text = "", TextSize = 20, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(1, -32, 1, 0), Position = UDim2.fromOffset(32, 0), Parent = priceRow })

	local unlock = Theme.text({ Text = `Unlock {Zones.ById[weapon.ZoneId].Name} to reveal`, TextSize = 16, Wrapped = true, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -16, 0, Theme.TOUCH), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), Parent = frame })
	local buyButton = Button.new({ Name = "Buy", Text = "Buy", Style = "primary", Size = UDim2.new(1, -16, 0, Theme.TOUCH), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), Parent = frame, OnClick = function()
		buy(weapon)
	end })
	local card: Card = { weapon = weapon, frame = frame, iconBox = iconBox, zoneRow = zoneRow, priceRow = priceRow, image = image, marks = marks, name = name, price = price, owned = owned, ownedBadge = ownedBadge, unlock = unlock, buy = buyButton, locked = nil }
	frame.Activated:Connect(function()
		if card.locked then
			lockedTip(weapon)
		else
			preview(weapon)
		end
	end)
	frame.Parent = parent
	cards[weapon.Id] = card
	layoutCard(card)
	refreshCard(card)
	return card
end

----------------------------------------------------------------------------------------------------
-- buying
----------------------------------------------------------------------------------------------------
buy = function(weapon: any)
	if requesting or CaseOpening.isActive() or not zoneOpen(weapon) then
		return
	end
	if (State.get("Gold") or 0) < Weapons.price(weapon.Zone) then
		Sfx.play("Denied")
		Notifier.push({ Kind = "error", Text = "Not enough Gold" })
		return
	end
	requesting = true
	refreshAll()
	-- the server refuses requests closer than BUY_INTERVAL: wait instead of failing ("Open again")
	local wait = Weapons.BUY_INTERVAL + 0.05 - (os.clock() - lastRequest)
	if wait > 0 then
		task.wait(wait)
	end
	lastRequest = os.clock()
	local called, ok, payload = pcall(Net.request, "BuyWeapon", weapon.Id)
	requesting = false
	if not called or ok ~= true or typeof(payload) ~= "table" then
		Sfx.play("Denied")
		Notifier.push({ Kind = "error", Text = if called and typeof(payload) == "string" then payload else "Purchase failed" })
		refreshAll()
		return
	end
	Sfx.play("Purchase")
	closeOverlay()
	CaseOpening.play(payload, function(weaponId: string)
		buy(Weapons.ById[weaponId])
	end)
	refreshAll()
end

----------------------------------------------------------------------------------------------------
-- layout
----------------------------------------------------------------------------------------------------
local function paintTab(id: string)
	for tabId, tab in pairs(tabs) do
		local on = tabId == id
		tab.gradient.Color = if on then ColorSequence.new(Theme.Colors.GoldFace, Theme.Colors.GoldDark) else ColorSequence.new(Theme.Colors.WoodLight, Theme.Colors.WoodBottom)
		tab.stroke.Color = if on then Theme.Colors.Ink else Theme.Colors.GoldDark
		local label = tab.frame:FindFirstChild("Label") :: TextLabel?
		if label then
			label.TextColor3 = if on then Theme.Colors.TextDark else Theme.Colors.Text
			local stroke = label:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Enabled = not on
			end
		end
	end
end

local function gridFor(categoryId: string): ScrollingFrame
	local existing = grids[categoryId]
	if existing then
		return existing
	end
	local grid = Instance.new("ScrollingFrame")
	grid.Name = categoryId
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Size = UDim2.fromScale(1, 1)
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = Theme.Colors.GoldLight
	grid.Visible = false
	local layout = Instance.new("UIGridLayout")
	local cardSize = if Theme.isCompact() then CONFIG.CompactCardSize else CONFIG.CardSize
	layout.CellSize = UDim2.fromOffset(cardSize.X, cardSize.Y)
	layout.CellPadding = UDim2.fromOffset(CONFIG.CardGap, CONFIG.CardGap)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = grid
	grid.Parent = (container :: Frame):FindFirstChild("Grids")
	for index, weapon in ipairs(Weapons.ByCategory[categoryId]) do
		makeCard(weapon, grid, index)
	end
	grids[categoryId] = grid
	return grid
end

local function selectCategory(categoryId: string)
	selected = categoryId
	paintTab(categoryId)
	local grid = gridFor(categoryId)
	for id, other in pairs(grids) do
		other.Visible = id == categoryId
	end
	-- reveal the cards of zones unlocked while this category was not on screen
	for _, weapon in ipairs(Weapons.ByCategory[categoryId]) do
		if pendingReveal[weapon.Id] then
			pendingReveal[weapon.Id] = nil
			task.delay(0.15, flip, cards[weapon.Id])
		end
	end
	grid.CanvasPosition = Vector2.zero
end

local function layout()
	local root = container
	if not root then
		return
	end
	local compact = Theme.isCompact()
	local header = CONFIG.HeaderHeight
	local tabsFrame = root:FindFirstChild("Tabs") :: ScrollingFrame
	local gridsFrame = root:FindFirstChild("Grids") :: Frame
	local headerFrame = root:FindFirstChild("Header") :: Frame
	local odds = headerFrame:FindFirstChild("Odds") :: GuiObject
	local list = tabsFrame:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	local cardSize = if compact then CONFIG.CompactCardSize else CONFIG.CardSize
	for _, grid in pairs(grids) do
		local gridLayout = grid:FindFirstChildOfClass("UIGridLayout")
		if gridLayout then
			gridLayout.CellSize = UDim2.fromOffset(cardSize.X, cardSize.Y)
		end
	end
	for _, card in pairs(cards) do
		layoutCard(card)
	end
	for _, child in ipairs(headerFrame:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "Odds" and child.Name ~= "Info" then
			child.Visible = not compact
		end
	end
	local info = headerFrame:FindFirstChild("Info") :: TextLabel
	info.Visible = compact
	local border = headerFrame:FindFirstChildOfClass("UIStroke")
	if border then
		border.Enabled = not compact
	end
	if compact then
		-- row 1: category tabs (scrolling) + Odds; row 2: one info line; then the cards
		local oddsWidth = 120
		headerFrame.BackgroundTransparency = 1
		headerFrame.Size = UDim2.new(1, 0, 0, Theme.TOUCH)
		odds.Size = UDim2.fromOffset(oddsWidth, Theme.TOUCH)
		odds.Position = UDim2.new(1, 0, 0, 0)
		odds.AnchorPoint = Vector2.new(1, 0)
		tabsFrame.Position = UDim2.fromOffset(0, 0)
		tabsFrame.Size = UDim2.new(1, -(oddsWidth + 8), 0, Theme.TOUCH + 8)
		tabsFrame.ScrollingDirection = Enum.ScrollingDirection.X
		tabsFrame.AutomaticCanvasSize = Enum.AutomaticSize.X
		list.FillDirection = Enum.FillDirection.Horizontal
		info.Position = UDim2.fromOffset(4, Theme.TOUCH + 10)
		info.Size = UDim2.new(1, -8, 0, CONFIG.CompactInfoHeight)
		local top = Theme.TOUCH + 12 + CONFIG.CompactInfoHeight
		gridsFrame.Position = UDim2.fromOffset(0, top)
		gridsFrame.Size = UDim2.new(1, 0, 1, -top)
	else
		headerFrame.BackgroundTransparency = 0
		headerFrame.Size = UDim2.new(1, 0, 0, header)
		odds.Size = UDim2.fromOffset(150, header - 8)
		odds.Position = UDim2.new(1, -4, 0.5, 0)
		odds.AnchorPoint = Vector2.new(1, 0.5)
		tabsFrame.Position = UDim2.fromOffset(0, header + 6)
		tabsFrame.Size = UDim2.new(0, CONFIG.TabWidth, 1, -(header + 6))
		tabsFrame.ScrollingDirection = Enum.ScrollingDirection.Y
		tabsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.FillDirection = Enum.FillDirection.Vertical
		gridsFrame.Position = UDim2.fromOffset(CONFIG.TabWidth + 10, header + 6)
		gridsFrame.Size = UDim2.new(1, -(CONFIG.TabWidth + 10), 1, -(header + 6))
	end
	for _, tab in pairs(tabs) do
		tab.frame.Size = if compact then UDim2.fromOffset(146, Theme.TOUCH) else UDim2.new(1, -10, 0, CONFIG.TabHeight)
	end
	-- the tab row sits on top of the header row on phones
	tabsFrame.ZIndex = if compact then 2 else 1
end

function WeaponShopPage.build(page: ScrollingFrame, ctx: any)
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	page.ScrollingEnabled = false
	page.AutomaticCanvasSize = Enum.AutomaticSize.None
	page.CanvasSize = UDim2.new()
	page.ScrollBarThickness = 0
	overlayParent = ctx.Frame

	local root = Instance.new("Frame")
	root.Name = "WeaponShop"
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(1, -16, 1, -12)
	root.Position = UDim2.fromOffset(8, 6)
	root.Parent = page
	container = root

	-- header: Gold, pity, Odds
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = Theme.Colors.WoodTop
	header.Size = UDim2.new(1, 0, 0, CONFIG.HeaderHeight)
	Theme.corner(header, 6)
	Theme.stroke(header, Theme.Colors.WoodLine, 1.5)
	header.Parent = root
	local goldBox = Instance.new("Frame")
	goldBox.BackgroundColor3 = Theme.Colors.WoodInset
	goldBox.Size = UDim2.new(0, 210, 0, 38)
	goldBox.Position = UDim2.new(0, 26, 0.5, 0)
	goldBox.AnchorPoint = Vector2.new(0, 0.5)
	Theme.corner(goldBox, 19)
	Theme.stroke(goldBox, Theme.Colors.GoldDark, 2)
	goldBox.Parent = header
	Icons.create("Gold", goldBox, { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, -22, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 2 })
	local goldLabel = Theme.text({ Font = "Number", Text = "", TextSize = 22, Align = "Right", Size = UDim2.new(1, -40, 1, -6), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = goldBox })
	local pityLabel = Theme.text({ Font = "Button", Text = "", TextSize = 20, Color = Theme.Colors.Text, Size = UDim2.new(1, -520, 0, 26), Position = UDim2.new(0.5, 0, 0.5, -9), AnchorPoint = Vector2.new(0.5, 0.5), Parent = header })
	local pity2Label = Theme.text({ Text = "", TextSize = 15, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -520, 0, 18), Position = UDim2.new(0.5, 0, 0.5, 13), AnchorPoint = Vector2.new(0.5, 0.5), Parent = header })
	local infoLabel = Theme.text({ Name = "Info", Font = "Button", Text = "", TextSize = 17, Align = "Left", Parent = header })
	infoLabel.Visible = false
	Button.new({ Name = "Odds", Text = "Odds", Icon = "Info", Style = "secondary", Size = UDim2.fromOffset(150, CONFIG.HeaderHeight - 8), Position = UDim2.new(1, -4, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = header, OnClick = odds })
	local epic, legendary = WeaponRarities.Pity[1], WeaponRarities.Pity[2]
	local function pityText()
		local a = `{math.min(State.get(epic.Key) or 0, epic.After)}/{epic.After}`
		local b = `{math.min(State.get(legendary.Key) or 0, legendary.After)}/{legendary.After}`
		pityLabel.Text = `Your pity: {a}`
		pity2Label.Text = `{legendary.Label}: {b}`
		infoLabel.Text = `Gold {Format.number(State.get("Gold") or 0)}    |    Your pity: {a}    |    {legendary.Label}: {b}`
	end
	State.observe("Gold", function(value)
		goldLabel.Text = Format.number(value or 0)
		pityText()
		refreshAll()
	end)
	State.observe(epic.Key, pityText)
	State.observe(legendary.Key, pityText)

	-- category tabs
	local tabsFrame = Instance.new("ScrollingFrame")
	tabsFrame.Name = "Tabs"
	tabsFrame.BackgroundTransparency = 1
	tabsFrame.BorderSizePixel = 0
	tabsFrame.CanvasSize = UDim2.new()
	tabsFrame.ScrollBarThickness = 4
	tabsFrame.ScrollBarImageColor3 = Theme.Colors.GoldLight
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = tabsFrame
	local tabPadding = Instance.new("UIPadding")
	tabPadding.PaddingTop = UDim.new(0, 2)
	tabPadding.PaddingLeft = UDim.new(0, 2)
	tabPadding.PaddingBottom = UDim.new(0, 4)
	tabPadding.Parent = tabsFrame
	tabsFrame.Parent = root
	for index, category in ipairs(WeaponCategories.List) do
		local tab = Instance.new("TextButton")
		tab.Name = category.Id
		tab.Text = ""
		tab.AutoButtonColor = false
		tab.BackgroundColor3 = WHITE
		tab.LayoutOrder = index
		Theme.corner(tab, 6)
		local gradient = Theme.gradient(tab, Theme.Colors.WoodLight, Theme.Colors.WoodBottom)
		local stroke = Theme.stroke(tab, Theme.Colors.GoldDark, 2)
		Icons.create(category.Id, tab, { Size = UDim2.new(0, 0, 0.82, 0), Position = UDim2.new(0, 4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 2 })
		Theme.text({ Name = "Label", Font = "Button", Text = category.Name, TextSize = 19, Align = "Left", Size = UDim2.new(1, -60, 0.8, 0), Position = UDim2.new(0, 54, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 2, Parent = tab })
		tab.Activated:Connect(function()
			if selected ~= category.Id then
				Sfx.play("UIClick")
				closeOverlay()
				selectCategory(category.Id)
			end
		end)
		tab.Parent = tabsFrame
		tabs[category.Id] = { frame = tab, gradient = gradient, stroke = stroke }
	end

	local gridsFrame = Instance.new("Frame")
	gridsFrame.Name = "Grids"
	gridsFrame.BackgroundTransparency = 1
	gridsFrame.Parent = root

	layout()
	Theme.Changed:Connect(layout)
	selectCategory(selected)

	-- a newly unlocked zone: its cards flip from silhouette to colors
	knownZones = table.clone(State.get("Zones") or {})
	State.changed("Zones", function(zones)
		zones = zones or {}
		for zoneId in pairs(zones) do
			if not knownZones[zoneId] then
				for _, category in ipairs(WeaponCategories.List) do
					local id = Weapons.idOf(zoneId, category.Id)
					local card = cards[id]
					local visible = card and grids[category.Id] and grids[category.Id].Visible and Window.isOpen("Shop")
					if visible then
						flip(card :: Card)
					elseif card then
						pendingReveal[id] = true
					end
				end
			end
		end
		knownZones = table.clone(zones)
		refreshAll()
	end)
	State.changed("Weapons", refreshAll)
	CaseOpening.Changed:Connect(refreshAll)
	Window.Closed:Connect(function(id)
		if id == "Shop" then
			closeOverlay()
		end
	end)
	Window.Opened:Connect(function(id)
		if id == "Shop" then
			selectCategory(selected)
		end
	end)
end

return WeaponShopPage
