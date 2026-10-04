--!strict
-- HUD 3: zone and sub-zone banner (top-center), a large title card for 2 s when the player enters
-- a new sub-zone, and the Zone Boost badge (equipped weapon / armor from the current zone).
-- Reads the player attributes CurrentZone / CurrentSubZone (set by ZoneService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.State)
local Notifier = require(script.Parent.Notifier)
local Kit = script.Parent.Kit
local Icons = require(Kit.Icons)
local Panel = require(Kit.Panel)
local Screens = require(Kit.Screens)
local Theme = require(Kit.Theme)

local ZoneBanner = { Priority = 10 }

local SIZE = { Normal = Vector2.new(380, 62), Compact = Vector2.new(300, 52) }
local BOOST_SIZE = Vector2.new(300, 40)
-- Widest top-corner block (the health bar on the left: 12 + 300; the currency bars on the right
-- are 12 + 270) plus a gap; on narrow screens (4:3 tablets) the banner shrinks to stay clear.
local SIDE_RESERVED = 322
local MIN_WIDTH = 200

local banner: Frame
local zoneLabel: TextLabel
local subLabel: TextLabel
local boost: TextButton
local boostLabel: TextLabel
local card: Frame
local cardTitle: TextLabel
local cardSub: TextLabel
local cardToken = 0
local boostText = ""

local function zoneIdOfItem(itemId: string): string?
	local prefix = string.match(itemId, "^(%a+)_")
	for _, zone in ipairs(Zones.List) do
		if string.lower(zone.Id) == prefix then
			return zone.Id
		end
	end
	return nil
end

local function describe(zoneId: string, subZoneId: string): (string, string, string?)
	local zone = Zones.ById[zoneId]
	if not zone then
		return UIConfig.Text.HubZone, UIConfig.Text.HubSubZone, nil
	end
	local title = `Zone {zone.Index} - {zone.Name}`
	if string.sub(subZoneId, -6) == "_Arena" then
		return title, `{UIConfig.Text.ArenaSubZone}: {zone.Boss}`, `{zone.Boss}'s Lair`
	end
	local _, n = Zones.parseSubZoneId(subZoneId)
	if not n then
		return title, "", nil
	end
	return title, `Sub-zone {n}: {zone.SubZones[n]}`, zone.SubZones[n]
end

local function showCard(title: string, subtitle: string)
	cardToken += 1
	local token = cardToken
	cardTitle.Text = title
	cardSub.Text = subtitle
	for _, label in ipairs({ cardTitle, cardSub }) do
		label.TextTransparency = 0;
		(label:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = 0
	end
	card.Visible = true
	task.delay(UIConfig.Hud.TitleCardSeconds, function()
		if token ~= cardToken then
			return
		end
		local info = TweenInfo.new(0.5)
		for _, label in ipairs({ cardTitle, cardSub }) do
			TweenService:Create(label, info, { TextTransparency = 1 }):Play()
			TweenService:Create(label:FindFirstChildOfClass("UIStroke") :: UIStroke, info, { Transparency = 1 }):Play()
		end
		task.delay(0.5, function()
			if token == cardToken then
				card.Visible = false
			end
		end)
	end)
end

local function updateBoost()
	local zoneId = Players.LocalPlayer:GetAttribute("CurrentZone")
	local weapons = State.get("Weapons") or {}
	local armor = State.get("Armor") or {}
	local weapon = weapons[State.get("EquippedWeapon") or ""]
	local weaponDef = weapon and Weapons.ById[weapon.id]
	local weaponMatch = weaponDef ~= nil and weaponDef.ZoneId == zoneId
	local armorMatches, armorBoosts = 0, {}
	for _, uid in pairs(State.get("EquippedArmor") or {}) do
		local piece = armor[uid]
		if piece and zoneIdOfItem(piece.id) == zoneId then
			armorMatches += 1
			table.insert(armorBoosts, Format.bonus(Rarities.get(piece.rarity).ZoneBoost))
		end
	end
	boost.Visible = weaponMatch or armorMatches > 0
	local parts = {}
	if weaponMatch then
		table.insert(parts, "Weapon")
	end
	if armorMatches > 0 then
		table.insert(parts, `{armorMatches}/3 Armor`)
	end
	boostLabel.Text = `{UIConfig.Text.ZoneBoost}: {table.concat(parts, " + ")}`
	local details = {}
	if weaponMatch then
		table.insert(details, `Weapon {Format.bonus(Rarities.get(weapon.rarity).ZoneBoost)} damage`)
	end
	if armorMatches > 0 then
		table.insert(details, `Armor {table.concat(armorBoosts, " / ")} HP & Defense`)
	end
	boostText = "Zone Boost: " .. table.concat(details, ", ")
end

local function updateLocation(withCard: boolean)
	local player = Players.LocalPlayer
	local title, subtitle, cardName = describe(player:GetAttribute("CurrentZone") or "Hub", player:GetAttribute("CurrentSubZone") or "Hub")
	zoneLabel.Text = title
	subLabel.Text = subtitle
	if withCard then
		showCard(cardName or title, if cardName then title else subtitle)
	end
	updateBoost()
end

local function layout()
	local compact = Theme.isCompact()
	local size = if compact then SIZE.Compact else SIZE.Normal
	local width = if compact then size.X else math.clamp(Theme.size().X - 2 * SIDE_RESERVED, MIN_WIDTH, size.X)
	banner.Size = UDim2.fromOffset(width, size.Y)
	boost.Position = UDim2.new(0.5, 0, 0, size.Y + 14)
end

function ZoneBanner:Start()
	local root = Screens.hud()
	banner = Panel.new({ Name = "ZoneBanner", Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0), BorderThickness = 3, Parent = root })
	zoneLabel = Theme.text({ Name = "Zone", Font = "Title", TextSize = 28, Color = Theme.Colors.Gold, Size = UDim2.new(1, -24, 0.56, 0), Position = UDim2.new(0.5, 0, 0, 3), AnchorPoint = Vector2.new(0.5, 0), Parent = banner })
	subLabel = Theme.text({ Name = "SubZone", TextSize = 18, Size = UDim2.new(1, -24, 0.38, 0), Position = UDim2.new(0.5, 0, 1, -3), AnchorPoint = Vector2.new(0.5, 1), Parent = banner })

	boost = Instance.new("TextButton")
	boost.Name = "ZoneBoost"
	boost.Text = ""
	boost.AutoButtonColor = false
	boost.AnchorPoint = Vector2.new(0.5, 0)
	boost.Size = UDim2.fromOffset(BOOST_SIZE.X, BOOST_SIZE.Y)
	boost.BackgroundColor3 = Color3.new(1, 1, 1)
	boost.Visible = false
	Theme.gradient(boost, Theme.Colors.GoldFace, Theme.Colors.GoldDark)
	Theme.corner(boost, 20)
	local glow = Theme.stroke(boost, Theme.Colors.Gold, 3)
	TweenService:Create(glow, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.7 }):Play()
	Icons.create("Boost", boost, { Size = UDim2.new(0, 0, 0.8, 0), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	boostLabel = Theme.text({ Font = "Button", TextSize = 20, Color = Theme.Colors.TextDark, Stroke = false, Size = UDim2.new(1, -46, 0.8, 0), Position = UDim2.new(0, 38, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = boost })
	boost.Activated:Connect(function()
		Notifier.push({ Kind = "info", Text = boostText, Icon = "Boost" })
	end)
	boost.Parent = root

	card = Instance.new("Frame")
	card.Name = "TitleCard"
	card.BackgroundTransparency = 1
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.36)
	card.Size = UDim2.fromOffset(640, 130)
	card.Visible = false
	cardTitle = Theme.text({ Font = "Title", TextSize = 72, Color = Theme.Colors.Gold, StrokeThickness = 3, Size = UDim2.fromScale(1, 0.66), Parent = card })
	cardSub = Theme.text({ Font = "Button", TextSize = 28, StrokeThickness = 2, Size = UDim2.fromScale(1, 0.32), Position = UDim2.fromScale(0, 0.68), Parent = card })
	card.Parent = root

	layout()
	Theme.Changed:Connect(layout)
	local player = Players.LocalPlayer
	updateLocation(false)
	player:GetAttributeChangedSignal("CurrentSubZone"):Connect(function()
		updateLocation(true)
	end)
	for _, key in ipairs({ "Weapons", "EquippedWeapon", "Armor", "EquippedArmor" }) do
		State.changed(key, updateBoost)
	end
end

return ZoneBanner
