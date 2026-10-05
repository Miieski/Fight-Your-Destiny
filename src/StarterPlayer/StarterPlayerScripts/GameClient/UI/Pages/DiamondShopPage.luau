--!strict
-- Shop > Diamonds (docs/menu_systems_brief.txt D1). Diamonds are spent here; Robux packs are sold only in the hub.
--   Premium Eggs: one per unlocked zone (10 + 4 x zone Diamonds), hatched at once (PetsPage.buyPremium).
--   Weapon Reroll: pick an owned weapon, 5 + 2 x zone Diamonds, the case opening shows the new rarity, then
--     Keep new / Keep old (Diamonds spent either way; ShopService "RerollWeapon" / "RerollChoice").
--   Gold Boost x2: 15 / 30 / 60 min packs (Config/Boosts Packs), time stacks, HUD timer (UI/BoostTimer).
--   Skins: "Coming soon" silhouettes.   Get Diamonds: offers a trip to the hub.
--   DiamondShopPage.build(page, ctx)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boosts = require(ReplicatedStorage.GameSystem.Config.Boosts)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local PetRarities = require(ReplicatedStorage.GameSystem.Config.PetRarities)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local WeaponRarities = require(ReplicatedStorage.GameSystem.Config.WeaponRarities)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.Parent.State)
local CaseOpening = require(script.Parent.Parent.CaseOpening)
local Notifier = require(script.Parent.Parent.Notifier)
local PetsPage = require(script.Parent.PetsPage)
local Kit = script.Parent.Parent.Kit
local ZoneVisibility = require(Kit.ZoneVisibility)
local Button = require(Kit.Button)
local Icons = require(Kit.Icons)
local ModelIcon = require(Kit.ModelIcon)
local Overlay = require(Kit.Overlay)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local DiamondShopPage = {}

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

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = seconds // 3600, (seconds // 60) % 60, seconds % 60
	return if h > 0 then string.format("%d:%02d:%02d", h, m, s) else string.format("%d:%02d", m, s)
end
DiamondShopPage.clock = clock

local function section(page: Instance, order: number, title: string, text: string?, height: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = title
	frame.BackgroundColor3 = Theme.Colors.WoodTop
	frame.Size = UDim2.new(1, -8, 0, height)
	frame.LayoutOrder = order
	frame.ZIndex = 2
	Theme.corner(frame, 8)
	Theme.stroke(frame, Theme.Colors.GoldDark, 2)
	Theme.text({ Font = "Title", Text = title, TextSize = 26, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(0.4, 0, 0, 32), Position = UDim2.fromOffset(14, 6), ZIndex = 3, Parent = frame })
	if text then
		Theme.text({ Text = text, TextSize = 17, Color = Theme.Colors.TextDim, Align = "Left", Wrapped = true, Size = UDim2.new(0.6, -24, 0, 34), Position = UDim2.new(0.4, 0, 0, 4), ZIndex = 3, Parent = frame })
	end
	frame.Parent = page
	return frame
end

-- the weapon list for a reroll
local function chooseWeapon(parent: GuiObject)
	local small = Theme.isCompact()
	local panel = Overlay.open(parent, Vector2.new(760, 520))
	Theme.text({ Font = "Title", Text = "Reroll a weapon", TextSize = if small then 26 else 32, Color = Theme.Colors.Gold, Size = UDim2.new(1, -140, 0, 40), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 23, Parent = panel })
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
	for uid, item in pairs(State.get("Weapons") or {}) do
		local weapon = Weapons.ById[item.id]
		if weapon then
			table.insert(entries, { uid = uid, item = item, weapon = weapon })
		end
	end
	table.sort(entries, function(a, b)
		if a.weapon.Zone ~= b.weapon.Zone then
			return a.weapon.Zone > b.weapon.Zone
		end
		if a.item.rarity ~= b.item.rarity then
			return a.item.rarity > b.item.rarity
		end
		return a.uid < b.uid
	end)
	if #entries == 0 then
		Theme.text({ Text = "No weapons yet. Buy one in the Weapons tab.", TextSize = 22, Color = Theme.Colors.TextDim, Size = UDim2.new(1, 0, 0, 60), ZIndex = 23, Parent = list })
		return
	end
	local rowH = if small then 64 else 76
	for index, entry in ipairs(entries) do
		local rarity = WeaponRarities.get(entry.item.rarity)
		local price = Weapons.rerollPrice(entry.weapon.Zone)
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Theme.Colors.WoodInset
		row.Size = UDim2.new(1, -10, 0, rowH)
		row.LayoutOrder = index
		row.ZIndex = 22
		Theme.corner(row, 6)
		Theme.paintRarity(Theme.stroke(row, Theme.Colors.GoldDark, 2), entry.item.rarity)
		Icons.create(entry.weapon.Icon or entry.weapon.Category, row, { Size = UDim2.fromOffset(rowH - 12, rowH - 12), Position = UDim2.fromOffset(8, 6), AnchorPoint = Vector2.zero, ZIndex = 23 })
		local x = rowH + 4
		local name = Theme.text({ Font = "Button", Text = entry.weapon.Name, TextSize = 20, Align = "Left", Size = UDim2.new(0.5, -x, 0, 26), Position = UDim2.fromOffset(x, 6), ZIndex = 23, Parent = row })
		Theme.paintRarity(name, entry.item.rarity)
		Theme.text({ Text = `{rarity.Name} - {ZoneVisibility.displayName(entry.weapon.ZoneId)}{if State.get("EquippedWeapon") == entry.uid then "  (equipped)" else ""}`, TextSize = 15, Align = "Left", Color = Theme.Colors.TextDim, Size = UDim2.new(0.5, -x, 0, 20), Position = UDim2.fromOffset(x, 34), ZIndex = 23, Parent = row })
		Button.new({ Text = `Reroll  {price}`, Icon = "Diamond", Style = if (State.get("Diamonds") or 0) >= price then "primary" else "disabled", TextSize = 20, Size = UDim2.new(0.34, 0, 0, Theme.TOUCH), Position = UDim2.new(1, -8, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 23, Parent = row, OnClick = function()
			if CaseOpening.isActive() then
				return
			end
			if (State.get("Diamonds") or 0) < price then
				Sfx.play("Denied")
				Notifier.push({ Kind = "error", Text = "Not enough Diamonds" })
				return
			end
			local ok, result = request("RerollWeapon", entry.uid)
			if ok and typeof(result) == "table" then
				Sfx.play("Purchase")
				Overlay.close()
				CaseOpening.play(result)
			end
		end })
		row.Parent = list
	end
end

function DiamondShopPage.build(page: ScrollingFrame, ctx: any)
	local small = Theme.isCompact()
	-- top: Diamonds + Get Diamonds
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.BackgroundTransparency = 1
	top.Size = UDim2.new(1, -8, 0, Theme.TOUCH)
	top.LayoutOrder = 1
	top.Parent = page
	local box = Instance.new("Frame")
	box.BackgroundColor3 = Theme.Colors.WoodInset
	box.Size = UDim2.fromOffset(190, 40)
	box.Position = UDim2.new(0, 10, 0.5, 0)
	box.AnchorPoint = Vector2.new(0, 0.5)
	box.ZIndex = 3
	Theme.corner(box, 20)
	Theme.stroke(box, Theme.Colors.GoldDark, 2)
	box.Parent = top
	Icons.create("Diamond", box, { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, -8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 4 })
	local diamonds = Theme.text({ Font = "Number", Text = "", TextSize = 22, Align = "Right", Size = UDim2.new(1, -48, 1, -6), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 4, Parent = box })
	if not small then
		Theme.text({ Text = "Robux diamond packs are sold in the hub.", TextSize = 18, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -520, 0, 26), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = top })
	end
	Button.new({ Name = "GetDiamonds", Text = UIConfig.Text.GetDiamonds, Icon = "Diamond", Style = "primary", Size = UDim2.fromOffset(240, Theme.TOUCH), Position = UDim2.new(1, -4, 0, 0), AnchorPoint = Vector2.new(1, 0), ZIndex = 3, Parent = top, OnClick = function()
		Window.confirm({
			Title = UIConfig.Text.GetDiamonds,
			Text = UIConfig.Text.GetDiamondsInfo,
			ConfirmText = "Go to hub",
			CancelText = "Not now",
			OnConfirm = function()
				Window.close()
				Net.request("GoToHub")
			end,
		})
	end })

	-- premium eggs
	local eggH = if small then 176 else 206
	local eggs = section(page, 2, "Premium Eggs", "A random pet of the zone, rarity rolled like the weapon shop.", eggH + 48)
	local strip = Instance.new("ScrollingFrame")
	strip.BackgroundTransparency = 1
	strip.BorderSizePixel = 0
	strip.Position = UDim2.fromOffset(10, 42)
	strip.Size = UDim2.new(1, -20, 0, eggH)
	strip.AutomaticCanvasSize = Enum.AutomaticSize.X
	strip.CanvasSize = UDim2.new()
	strip.ScrollingDirection = Enum.ScrollingDirection.X
	strip.ScrollBarThickness = 6
	strip.ScrollBarImageColor3 = Theme.Colors.GoldLight
	strip.ZIndex = 3
	local stripList = Instance.new("UIListLayout")
	stripList.FillDirection = Enum.FillDirection.Horizontal
	stripList.Padding = UDim.new(0, 8)
	stripList.SortOrder = Enum.SortOrder.LayoutOrder
	stripList.Parent = strip
	strip.Parent = eggs

	-- weapon reroll
	local reroll = section(page, 3, "Weapon Reroll", "Pay 5 + 2 x zone Diamonds for a new rarity roll. Keep the new one or the old one.", Theme.TOUCH + 56)
	Button.new({ Name = "ChooseWeapon", Text = "Choose a weapon", Icon = "Sword", Style = "primary", Size = UDim2.fromOffset(280, Theme.TOUCH), Position = UDim2.new(0, 14, 0, 44), ZIndex = 3, Parent = reroll, OnClick = function()
		chooseWeapon(ctx.Frame)
	end })

	-- gold boost
	local boost = section(page, 4, "Gold Boost x2", "Double Gold for a while. Buying more adds time.", Theme.TOUCH + 64)
	local status = Theme.text({ Font = "Number", Text = "", TextSize = 19, Align = "Left", Color = Theme.Colors.Good, Size = UDim2.new(0.3, 0, 0, Theme.TOUCH), Position = UDim2.new(0, 14, 0, 46), ZIndex = 3, Parent = boost })
	local packs = Instance.new("Frame")
	packs.BackgroundTransparency = 1
	packs.Size = UDim2.new(0.7, -14, 0, Theme.TOUCH)
	packs.Position = UDim2.new(1, -10, 0, 46)
	packs.AnchorPoint = Vector2.new(1, 0)
	packs.ZIndex = 3
	local packList = Instance.new("UIListLayout")
	packList.FillDirection = Enum.FillDirection.Horizontal
	packList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	packList.Padding = UDim.new(0, 8)
	packList.SortOrder = Enum.SortOrder.LayoutOrder
	packList.Parent = packs
	packs.Parent = boost
	local packButtons = {}
	for index, pack in ipairs(Boosts.Packs) do
		packButtons[index] = Button.new({ Text = `{pack.Minutes} min  {pack.Price}`, Icon = "Diamond", Style = "primary", TextSize = 20, Size = UDim2.new(1 / #Boosts.Packs, -8, 1, 0), LayoutOrder = index, ZIndex = 4, Parent = packs, OnClick = function()
			if (State.get("Diamonds") or 0) < pack.Price then
				Sfx.play("Denied")
				Notifier.push({ Kind = "error", Text = "Not enough Diamonds" })
				return
			end
			local ok = request("BuyBoost", index)
			if ok then
				Sfx.play("Purchase")
				Notifier.push({ Kind = "reward", Text = `Gold Boost x2: +{pack.Minutes} min`, Icon = "Gold" })
			end
		end })
	end

	-- skins
	local skinsH = if small then 120 else 150
	local skins = section(page, 5, "Skins", "Weapon and character skins are coming soon.", skinsH + 48)
	local skinRow = Instance.new("Frame")
	skinRow.BackgroundTransparency = 1
	skinRow.Position = UDim2.fromOffset(10, 44)
	skinRow.Size = UDim2.new(1, -20, 0, skinsH)
	skinRow.ZIndex = 3
	local skinList = Instance.new("UIListLayout")
	skinList.FillDirection = Enum.FillDirection.Horizontal
	skinList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	skinList.Padding = UDim.new(0, 10)
	skinList.Parent = skinRow
	skinRow.Parent = skins
	for i = 1, (if small then 4 else 6) do
		local card = Instance.new("Frame")
		card.BackgroundColor3 = Theme.Colors.WoodInset
		card.Size = UDim2.fromOffset(skinsH - 20, skinsH)
		card.LayoutOrder = i
		card.ZIndex = 3
		Theme.corner(card, 8)
		Theme.stroke(card, Theme.Colors.GoldDark, 2)
		local shape = Icons.create(if i % 2 == 0 then "Sword" else "Helmet", card, { Size = UDim2.fromScale(0.62, 0.5), Position = UDim2.fromScale(0.5, 0.42), ZIndex = 4 })
		local image = shape:FindFirstChild("Image") :: ImageLabel?
		if image then
			image.ImageColor3 = Color3.new(0, 0, 0)
		end
		Theme.text({ Font = "Title", Text = "?", TextSize = 34, Size = UDim2.fromScale(0.5, 0.4), Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5, StrokeThickness = 2, Parent = card })
		Theme.text({ Text = UIConfig.Text.ComingSoon, TextSize = 15, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -6, 0, 20), Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 4, Parent = card })
		card.Parent = skinRow
	end

	local function refreshEggs()
		for _, child in ipairs(strip:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local zones = State.get("Zones") or {}
		local have = State.get("Diamonds") or 0
		local iconH = if small then 80 else 104
		for _, zone in ipairs(Zones.List) do
			local open = zones[zone.Id] == true
			local price = PetRarities.premiumEggPrice(zone.Index)
			local card = Instance.new("Frame")
			card.Name = zone.Id
			card.BackgroundColor3 = Theme.Colors.WoodInset
			card.Size = UDim2.fromOffset(if small then 128 else 150, eggH - 10)
			card.LayoutOrder = zone.Index
			card.ZIndex = 3
			Theme.corner(card, 8)
			Theme.stroke(card, Theme.Colors.GoldDark, 2)
			ModelIcon.egg(zone.Index, nil, { Size = UDim2.fromOffset(iconH, iconH), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 4, Silhouette = not open, Parent = card })
			if not open then
				Theme.text({ Font = "Title", Text = "?", TextSize = 46, Size = UDim2.fromOffset(iconH, iconH), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), StrokeThickness = 3, ZIndex = 5, Parent = card })
			end
			Theme.text({ Font = "Button", Text = if open then `{ZoneVisibility.displayName(zone.Id)} Egg` else "???", TextSize = 16, Size = UDim2.new(1, -8, 0, 20), Position = UDim2.new(0.5, 0, 0, iconH + 6), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 4, Parent = card })
			if open then
				Button.new({ Text = `{price}`, Icon = "Diamond", Style = if have >= price then "primary" else "disabled", TextSize = 24, Size = UDim2.new(1, -12, 0, Theme.TOUCH), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 4, Parent = card, OnClick = function()
					PetsPage.buyPremium(zone)
				end })
			else
				Theme.text({ Text = ZoneVisibility.requirement(zone.Id, true), TextSize = 15, Wrapped = true, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -12, 0, Theme.TOUCH), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 4, Parent = card })
			end
			card.Parent = strip
		end
	end

	local function refresh()
		local have = State.get("Diamonds") or 0
		diamonds.Text = Format.number(have)
		for index, pack in ipairs(Boosts.Packs) do
			packButtons[index]:SetStyle(if have >= pack.Price then "primary" else "disabled")
		end
		refreshEggs()
	end
	refresh()
	State.changed("Diamonds", refresh)
	State.changed("Zones", refreshEggs)
	-- boost status, once a second while the page is shown
	task.spawn(function()
		while true do
			if page.Visible then
				local left = Boosts.remaining(State.get("Boosts"), "GoldX2", os.time())
				status.Text = if left > 0 then `Active: {clock(left)} left` else "Not active"
				status.TextColor3 = if left > 0 then Theme.Colors.Good else Theme.Colors.TextDim
			end
			task.wait(1)
		end
	end)
	page:GetPropertyChangedSignal("Visible"):Connect(function()
		if not page.Visible then
			Overlay.close()
		end
	end)
	Window.Closed:Connect(function(id: string)
		if id == "Shop" then
			Overlay.close()
		end
	end)
end

return DiamondShopPage
