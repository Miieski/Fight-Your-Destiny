--!strict
-- Rebirth Protection on this side (Config/RebirthProtection, Services/ProtectionService): the shield on each item card and the
-- purchase popup. Built on Kit/Components.
--   Protection.badge(cell, category, uid, item, position, anchor?)   grey open shield + price, or a golden shield when protected
--   Protection.isProtected(category, uid), Protection.WARNING        for the sell / release confirmations
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local RebirthProtection = require(ReplicatedStorage.GameSystem.Config.RebirthProtection)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local State = require(script.Parent.Parent.State)
local Notifier = require(script.Parent.Notifier)
local Kit = script.Parent.Kit
local Components = require(Kit.Components)
local Icons = require(Kit.Icons)
local Overlay = require(Kit.Overlay)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local Protection = {}

Protection.WARNING = "This item is PROTECTED: you paid Diamonds to keep it forever."

local SIZE = 44
local busy = false

function Protection.isProtected(category: string, uid: string): boolean
	local items = State.get(RebirthProtection.Keys[category]) or {}
	local item = items[uid]
	return item ~= nil and item.Protected == true
end

local function windowOf(gui: Instance): GuiObject?
	local q: Instance? = gui
	while q do
		if q:IsA("Frame") and string.sub(q.Name, -6) == "Window" then
			return q
		end
		q = q.Parent
	end
	return nil
end

local function buy(uid: string, name: string)
	if busy then
		return
	end
	busy = true
	local called, ok, result = pcall(Net.request, "ProtectItem", uid)
	busy = false
	if called and ok then
		Sfx.play("Purchase")
		Overlay.close()
		Notifier.push({ Kind = "reward", Text = `{name} is protected: it stays after every Rebirth`, Icon = "Defense" })
	else
		Sfx.play("Denied")
		Notifier.push({ Kind = "error", Text = if called and typeof(result) == "string" then result else "Could not protect", Icon = "Diamond" })
	end
end

function Protection.open(frame: GuiObject, category: string, uid: string, item: { [string]: any }, name: string)
	local price = RebirthProtection.price(category, item)
	local diamonds = tonumber(State.get("Diamonds")) or 0
	local rarity = Rarities.get(item.rarity or 1)
	local panel, body = Components.Popup(frame, "Keep Forever", Vector2.new(480, 330))
	panel.Name = "ProtectPopup"
	local z = 24
	local title = Theme.text({ Font = "Button", Text = `{rarity.Name} {name}`, TextSize = 22, Size = UDim2.new(1, 0, 0, 30), ZIndex = z, Parent = body })
	Theme.paintRarity(title, item.rarity or 1)
	Theme.text({ Text = "This item will be kept after every Rebirth", TextSize = 19, Wrapped = true, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 34), ZIndex = z, Parent = body })
	local row = Components.CounterRow(body, { Size = UDim2.new(1, 0, 0, 44), Align = "Center", ZIndex = z })
	row.Position = UDim2.fromOffset(0, 72)
	Components.Counter(row, "Diamond", Format.number(price), { Height = 40, LayoutOrder = 1, ZIndex = z, TextColor = if diamonds >= price then Theme.Colors.Good else Theme.Colors.Bad })
	local half = UDim2.new(0.5, -6, 0, Theme.TOUCH)
	if diamonds >= price then
		Components.Button({ Name = "Buy", Text = "Buy", Icon = "Diamond", Style = "primary", TextSize = 24, Size = half, Position = UDim2.new(0, 0, 1, -2), AnchorPoint = Vector2.new(0, 1), ZIndex = z, Parent = body, OnClick = function()
			buy(uid, name)
		end })
	else
		Theme.text({ Text = `{Format.number(price - diamonds)} Diamonds missing`, TextSize = 19, Color = Theme.Colors.Bad, Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 122), ZIndex = z, Parent = body })
		Components.Button({ Name = "DiamondShop", Text = "Diamonds", Icon = "Diamond", Style = "primary", TextSize = 22, Size = half, Position = UDim2.new(0, 0, 1, -2), AnchorPoint = Vector2.new(0, 1), ZIndex = z, Parent = body, OnClick = function()
			Overlay.close()
			Window.open("Shop", "Diamonds")
		end })
	end
	Components.Button({ Name = "Cancel", Text = "Cancel", Style = "secondary", TextSize = 24, Size = half, Position = UDim2.new(1, 0, 1, -2), AnchorPoint = Vector2.new(1, 1), ZIndex = z, Parent = body, OnClick = Overlay.close })
end

function Protection.badge(cell: GuiObject, category: string, uid: string, item: { [string]: any }, name: string, position: UDim2, anchor: Vector2?)
	local protected = item.Protected == true
	local z = cell.ZIndex + 3
	local button = Instance.new("TextButton")
	button.Name = "Protect"
	button.Text = ""
	button.AutoButtonColor = false
	button.Size = UDim2.fromOffset(SIZE, SIZE)
	button.Position = position
	button.AnchorPoint = anchor or Vector2.zero
	button.BackgroundColor3 = if protected then Theme.Colors.GoldBase else Theme.Colors.WoodInset
	button.BackgroundTransparency = if protected then 0.1 else 0.25
	button.ZIndex = z
	Theme.round(button)
	Theme.stroke(button, if protected then Theme.Colors.Gold else Theme.Colors.SteelDark, if protected then 2.5 else 1.5)
	local icon = Icons.create("Defense", button, { Size = UDim2.fromScale(0.74, 0.74), Position = UDim2.new(0.5, 0, if protected then 0.5 else 0.42, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z + 1 })
	if protected then
		local glow = Instance.new("UIStroke")
		glow.Color = Theme.Colors.GoldFace
		glow.Thickness = 1
		glow.Transparency = 0.4
		glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		glow.Parent = icon
	else
		Icons.setFaded(icon, 0.6)
		Theme.text({ Font = "Number", Text = Format.number(RebirthProtection.price(category, item)), TextSize = 13, Color = Theme.Colors.Diamond, Size = UDim2.new(1, 0, 0, 15), Position = UDim2.new(0.5, 0, 1, -1), AnchorPoint = Vector2.new(0.5, 1), ZIndex = z + 2, Parent = button })
	end
	button.Activated:Connect(function()
		Sfx.play("UIClick")
		if protected then
			Notifier.push({ Kind = "info", Text = "Protected: kept after every Rebirth", Icon = "Defense" })
			return
		end
		local frame = windowOf(cell)
		if frame then
			Protection.open(frame, category, uid, item, name)
		end
	end)
	button.Parent = cell
	return button
end

return Protection
