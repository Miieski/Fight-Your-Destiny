--!strict
-- Shop > Diamonds (docs/menu_systems_brief.txt D1). Diamonds are spent here; Robux packs are sold only in the hub.
--   Premium Eggs: one per unlocked zone (10 + 4 x zone Diamonds), hatched at once (PetsPage.buyPremium).
--   (The Weapon Reroll was removed on 2026-10-13: weapons are sold for Gold in Inventory > Weapons instead.)
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
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.Parent.State)
local Notifier = require(script.Parent.Parent.Notifier)
local PetsPage = require(script.Parent.PetsPage)
local Kit = script.Parent.Parent.Kit
local ZoneVisibility = require(Kit.ZoneVisibility)
local Button = require(Kit.Button)
local Chips = require(Kit.Chips)
local Icons = require(Kit.Icons)
local Info = require(Kit.Info)
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

-- A section: its picture and title; the explaining sentence is behind an (i) (kid-friendly UI, owner 2026-10-13).
local windowFrame: GuiObject? = nil
local function section(page: Instance, order: number, title: string, text: string?, height: number, icon: string?): Frame
	local frame = Instance.new("Frame")
	frame.Name = title
	frame.BackgroundColor3 = Theme.Colors.WoodTop
	frame.Size = UDim2.new(1, -8, 0, height)
	frame.LayoutOrder = order
	frame.ZIndex = 2
	Theme.corner(frame, 8)
	Theme.stroke(frame, Theme.Colors.GoldDark, 2)
	local x = 14
	if icon then
		Icons.create(icon, frame, { Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(10, 3), AnchorPoint = Vector2.zero, ZIndex = 3 })
		x = 54
	end
	Theme.text({ Font = "Title", Text = title, TextSize = 26, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(0.5, 0, 0, 32), Position = UDim2.fromOffset(x, 6), ZIndex = 3, Parent = frame })
	if text and windowFrame then
		Info.button({ Parent = frame, Frame = windowFrame, Title = title, Lines = { text }, Size = 36, Position = UDim2.new(1, -8, 0, 5), AnchorPoint = Vector2.new(1, 0), ZIndex = 3, PopupSize = Vector2.new(560, 240) })
	end
	frame.Parent = page
	return frame
end

function DiamondShopPage.build(page: ScrollingFrame, ctx: any)
	local small = Theme.isCompact()
	windowFrame = ctx.Frame
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
	-- "+ Diamonds" (the Robux packs are sold in the hub; the confirm dialog says it)
	Button.new({ Name = "GetDiamonds", Text = "+", Icon = "Diamond", Style = "go", TextSize = 34, Size = UDim2.fromOffset(110, Theme.TOUCH), Position = UDim2.new(1, -4, 0, 0), AnchorPoint = Vector2.new(1, 0), ZIndex = 3, Parent = top, OnClick = function()
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
	local eggs = section(page, 2, "Premium Eggs", "A random pet of the zone, rarity rolled like the weapon shop.", eggH + 48, "Egg")
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

	-- gold boost
	local boost = section(page, 3, "Gold Boost x2", "Double Gold for a while. Buying more adds time.", Theme.TOUCH + 108, "GoldGain")
	local status = Chips.chip(boost, "Clock", "-", { Height = 42, Position = UDim2.new(0, 14, 0, 90 + Theme.TOUCH / 2), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
	local packs = Instance.new("Frame")
	packs.BackgroundTransparency = 1
	packs.Size = UDim2.new(0.7, -14, 0, Theme.TOUCH + 44)
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
		local cell = Instance.new("Frame")
		cell.BackgroundTransparency = 1
		cell.Size = UDim2.new(1 / #Boosts.Packs, -8, 1, 0)
		cell.LayoutOrder = index
		cell.ZIndex = 4
		cell.Parent = packs
		Chips.chip(cell, "Clock", `{pack.Minutes}m`, { Height = 36, Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 4 })
		packButtons[index] = Button.new({ Text = `{pack.Price}`, Icon = "Diamond", Style = "primary", TextSize = 24, Size = UDim2.new(1, 0, 0, Theme.TOUCH), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), ZIndex = 4, Parent = cell, OnClick = function()
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
	local skins = section(page, 4, "Skins", "Weapon and character skins are coming soon.", skinsH + 48, "Star")
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
		Icons.create("Clock", card, { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 4 }) -- coming soon
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
				-- lock + skull (beat the boss) + Rebirth pictures instead of a sentence
				for i, iconId in ipairs({ "Lock", "Skull", "RebirthShop" }) do
					Icons.create(iconId, card, { Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0.5, (i - 2) * 38, 1, -10), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 4 })
				end
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
				status:Set(if left > 0 then clock(left) else "-", if left > 0 then Theme.Colors.Good else Theme.Colors.TextDim)
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
