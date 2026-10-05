--!strict
-- CS:GO-style case opening (docs/weapon_shop_brief.txt part 4). The server already decided the rarity
-- (ShopService); this only shows it. A strip of TileCount rarity tiles slides under a fixed center marker and
-- stops on the server's tier (tile WinIndex, at a random spot inside it) after SpinSeconds (FastSpinSeconds
-- with the Fast Open setting). Skip (button or a tap on the reel) jumps to the reveal; the reveal always plays.
--   CaseOpening.play(result, onAgain)  result = the BuyWeapon reply; onAgain(weaponId) buys the same again
--   CaseOpening.isActive(), CaseOpening.Changed (fires with the new active flag)
-- One tween moves the strip. The per-frame check (tick sound, tile under the marker) recomputes the strip
-- position from the clock with the same easing, so it only works with numbers: no allocation per frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local WeaponRarities = require(ReplicatedStorage.GameSystem.Config.WeaponRarities)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.State)
local Settings = require(script.Parent.Parent.Controllers.SettingsController)
local Notifier = require(script.Parent.Notifier)
local Kit = script.Parent.Kit
local Button = require(Kit.Button)
local Icons = require(Kit.Icons)
local Panel = require(Kit.Panel)
local Theme = require(Kit.Theme)

local CaseOpening = {}

local CONFIG = UIConfig.CaseOpening
local TICK_POOL = 4
local changedEvent = Instance.new("BindableEvent")
CaseOpening.Changed = changedEvent.Event

local active = false
local root: Frame? = nil
local ticks: { Sound } = {}
local nextTick = 1

-- Everything of the current opening (destroyed on close).
type Opening = {
	result: { [string]: any },
	weapon: any,
	modal: Frame,
	tiles: { Frame },
	scales: { UIScale },
	strip: Frame,
	tween: Tween,
	conn: RBXScriptConnection?,
	goldConn: (() -> ())?,
	revealed: boolean,
	endX: number,
	equippedBefore: string?,
	onAgain: ((string) -> ())?,
	buttons: { [string]: any },
	fx: Frame,
	result_: Frame,
}
local current: Opening? = nil

local function setActive(value: boolean)
	if active ~= value then
		active = value
		changedEvent:Fire(value)
	end
end

function CaseOpening.isActive(): boolean
	return active
end

local function ensureRoot(): Frame
	if root then
		return root
	end
	local _, screenRoot = Theme.screen("CaseOpening", 30)
	root = screenRoot
	return screenRoot
end

local function ensureTicks()
	if #ticks > 0 then
		return
	end
	local source = Sfx.find("ReelTick") or Sfx.find("UIClick")
	if not source then
		return
	end
	for _ = 1, TICK_POOL do
		local sound = source:Clone()
		sound.Looped = false
		sound.SoundGroup = Sfx.group(Sfx.groupOf("UIClick"))
		sound.Parent = SoundService
		table.insert(ticks, sound)
	end
end

local function playTick(speed: number)
	local sound = ticks[nextTick]
	if not sound then
		return
	end
	nextTick = nextTick % #ticks + 1
	sound.PlaybackSpeed = 1 + (CONFIG.TickMaxPitch - 1) * speed
	sound.TimePosition = 0
	sound:Play()
end

-- Tiles chosen "visually" from the odds: weights = odds ^ 0.6 so commons dominate but rare tiles flash by.
local VISUAL_POWER = 0.6
local visualWeights: { number } = {}
local visualTotal = 0
for tier, rarity in ipairs(WeaponRarities.List) do
	visualWeights[tier] = rarity.ShopOdds ^ VISUAL_POWER
	visualTotal += visualWeights[tier]
end
local function visualTier(rng: Random): number
	local x = rng:NextNumber() * visualTotal
	for tier, weight in ipairs(visualWeights) do
		x -= weight
		if x < 0 then
			return tier
		end
	end
	return 1
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function makeTile(parent: Instance, weapon: any, tier: number, width: number, height: number, x: number): (Frame, UIScale)
	local rarity = WeaponRarities.get(tier)
	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.AnchorPoint = Vector2.new(0.5, 0.5)
	tile.Size = UDim2.fromOffset(width, height)
	tile.Position = UDim2.new(0, x + width / 2, 0.5, 0)
	tile.BackgroundColor3 = if rarity.Gradient then Color3.new(1, 1, 1) else rarity.Color
	tile.BorderSizePixel = 0
	Theme.corner(tile, 8)
	if rarity.Gradient then
		Theme.paintRarity(tile, tier)
	else
		local shade = Instance.new("UIGradient")
		shade.Color = ColorSequence.new(darker(rarity.Color, 0.72), darker(rarity.Color, 0.1))
		shade.Rotation = 90
		shade.Parent = tile
	end
	local stroke = Theme.stroke(tile, Theme.Colors.Ink, 2.5)
	stroke.Transparency = 0.1
	local scale = Instance.new("UIScale")
	scale.Parent = tile
	Icons.create(weapon.Icon or weapon.Category, tile, { Size = UDim2.fromOffset(width * 0.7, width * 0.7), Position = UDim2.new(0.5, 0, 0, width * 0.06), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 2 })
	Theme.text({ Font = "Button", Text = rarity.Name, TextSize = 20, Size = UDim2.new(1, -8, 0, height * 0.2), Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 2, Parent = tile })
	tile.Parent = parent
	return tile, scale
end

local function zoneName(weapon: any): string
	return Zones.ById[weapon.ZoneId].Name
end

local function close()
	local opening = current
	if not opening then
		return
	end
	current = nil
	if opening.conn then
		opening.conn:Disconnect()
	end
	if opening.goldConn then
		opening.goldConn()
	end
	opening.tween:Cancel()
	opening.modal:Destroy()
	setActive(false)
	Sfx.play("UIClose")
end

-- Rarity effects, bigger for rarer tiers (Low FX keeps only the flash).
local function burst(opening: Opening, tier: number)
	local rarity = WeaponRarities.get(tier)
	local fx = opening.fx
	local low = Settings.get("LowFx") == true
	local flash = Instance.new("Frame")
	flash.AnchorPoint = Vector2.new(0.5, 0.5)
	flash.Position = UDim2.fromScale(0.5, 0.5)
	flash.Size = UDim2.fromOffset(40, 40)
	flash.BackgroundColor3 = rarity.Color
	flash.BackgroundTransparency = 0.3
	Theme.round(flash)
	flash.Parent = fx
	TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(260 + 40 * tier, 260 + 40 * tier), BackgroundTransparency = 1 }):Play()
	if low or tier < 3 then
		return
	end
	-- Rare / Epic: sparkles; Legendary and better: rays; Divine / Secret: a glow over the whole screen
	local sparkles = if tier >= CONFIG.BurstFrom then 16 else 10
	for i = 1, sparkles do
		local star = Instance.new("Frame")
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(0.5, 0.5)
		star.Size = UDim2.fromOffset(10, 10)
		star.Rotation = 45
		star.BackgroundColor3 = if rarity.Gradient then Color3.new(1, 1, 1) else rarity.Color:Lerp(Color3.new(1, 1, 1), 0.35)
		star.BorderSizePixel = 0
		if rarity.Gradient then
			Theme.paintRarity(star, tier)
		end
		star.Parent = fx
		local angle = (i / sparkles) * math.pi * 2 + math.random() * 0.4
		local distance = 110 + math.random() * 90 + (if tier >= CONFIG.BurstFrom then 60 else 0)
		TweenService:Create(star, TweenInfo.new(0.7 + math.random() * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance),
			BackgroundTransparency = 1,
			Rotation = 225,
		}):Play()
	end
	if tier < CONFIG.BurstFrom then
		return
	end
	local rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromOffset(10, 10)
	rays.BackgroundTransparency = 1
	rays.ZIndex = 0
	rays.Parent = fx
	for i = 1, 12 do
		-- GUI objects turn around their own middle: each ray is twice as long, centered on the burst, and
		-- only its upper half is drawn, so all rays start at the center of the winning tile
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromOffset(18, 640)
		ray.Rotation = i * 30
		ray.BackgroundColor3 = if rarity.Gradient then Color3.new(1, 1, 1) else rarity.Color
		ray.BackgroundTransparency = 0.45
		ray.BorderSizePixel = 0
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 0.25),
			NumberSequenceKeypoint.new(0.499, 0.1),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Rotation = 90
		if rarity.Gradient then
			fade.Color = rarity.Gradient
		end
		fade.Parent = ray
		ray.Parent = rays
	end
	local spin = if tier == #WeaponRarities.List then CONFIG.SecretStingSeconds + 1 else 1.6
	TweenService:Create(rays, TweenInfo.new(spin, Enum.EasingStyle.Linear), { Rotation = 90 }):Play()
	task.delay(spin - 0.5, function()
		for _, ray in ipairs(rays:GetChildren()) do
			if ray:IsA("Frame") then
				TweenService:Create(ray, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			end
		end
	end)
	if tier >= #WeaponRarities.List - 1 then
		local glow = Instance.new("Frame")
		glow.Name = "ScreenGlow"
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.Size = UDim2.fromScale(4, 4)
		glow.BackgroundColor3 = Color3.new(1, 1, 1)
		glow.BackgroundTransparency = 0.45
		glow.ZIndex = 50
		glow.Active = false
		Theme.paintRarity(glow, tier)
		glow.Parent = opening.modal
		local seconds = if tier == #WeaponRarities.List then CONFIG.SecretStingSeconds else 1.1
		TweenService:Create(glow, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		task.delay(seconds, function()
			glow:Destroy()
		end)
	end
end

local function reveal(opening: Opening)
	if opening.revealed then
		return
	end
	opening.revealed = true
	if opening.conn then
		opening.conn:Disconnect()
		opening.conn = nil
	end
	opening.tween:Cancel()
	local win = CONFIG.WinIndex
	opening.strip.Position = UDim2.fromOffset(opening.endX, 0)
	for _, scale in ipairs(opening.scales) do
		scale.Scale = 1
	end
	Net.send("OpeningDone") -- the server may now send the toast / auto-equip and accept the next purchase

	local tier = opening.result.rarity
	local rarity = WeaponRarities.get(tier)
	local weapon = opening.weapon
	local winScale = opening.scales[win]
	TweenService:Create(winScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = CONFIG.RevealScale }):Play()
	Sfx.play(if tier >= Rarities.LEGENDARY_SOUND_FROM then "RarityLegendary" else "RarityReveal")
	if tier == #WeaponRarities.List then
		task.delay(0.6, function()
			Sfx.play("RarityReveal")
		end)
	end
	burst(opening, tier)

	-- result texts
	local panel = opening.result_
	panel.Visible = true
	local banner = panel:FindFirstChild("Banner") :: TextLabel
	banner.Text = rarity.Name
	Theme.paintRarity(banner, tier)
	local damage = Stats.weaponDamage(weapon.Id, tier)
	local details = panel:FindFirstChild("Details") :: TextLabel
	details.Text = string.format("%s damage per hit   |   Zone Boost +%d%% in %s   |   %s %d%% proc",
		Format.number(damage), math.round(rarity.ZoneBoost * 100), zoneName(weapon), weapon.Element, math.round(rarity.ElementProc * 100))
	local hint = panel:FindFirstChild("Hint") :: TextLabel
	local weapons = State.get("Weapons") or {}
	local equipped = opening.equippedBefore and weapons[opening.equippedBefore]
	local parts = {}
	if not equipped then
		table.insert(parts, "Equipped automatically - your first weapon!")
	elseif Stats.weaponDps(weapon.Id, tier) > Stats.weaponDps(equipped.id, equipped.rarity) then
		table.insert(parts, "Better than equipped!")
	end
	local pity = opening.result.pityReason
	if pity and pity ~= "forced" then
		table.insert(parts, `Pity: guaranteed {pity}`)
	end
	hint.Text = table.concat(parts, "   -   ")
	hint.TextColor3 = if #parts > 0 and (not equipped or string.find(parts[1], "Better")) then Theme.Colors.Good else Theme.Colors.Gold

	-- buttons
	local buttons = opening.buttons
	buttons.Skip.Instance.Visible = false
	for _, name in ipairs({ "Equip", "Again", "Close" }) do
		buttons[name].Instance.Visible = true
	end
	if not equipped then
		buttons.Equip:SetText("Equipped")
		buttons.Equip:SetEnabled(false)
	end
	local price = Weapons.price(weapon.Zone)
	buttons.Again:SetStyle(if (State.get("Gold") or 0) >= price then "primary" else "disabled")
end

-- Shows the opening of `result` (the server's BuyWeapon reply). onAgain(weaponId) is called by "Open again".
function CaseOpening.play(result: { [string]: any }, onAgain: ((string) -> ())?)
	if current then
		close()
	end
	local weapon = Weapons.ById[result.weaponId]
	if not weapon then
		return
	end
	setActive(true)
	ensureTicks()
	local parent = ensureRoot()
	local screen = Theme.size()
	local compact = Theme.isCompact()

	local modal = Instance.new("Frame")
	modal.Name = "Opening"
	modal.BackgroundTransparency = 1
	modal.Size = UDim2.fromScale(1, 1)
	modal.Parent = parent
	-- dim: a plain Frame does not take clicks, so the HUD around the panel stays usable
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.AnchorPoint = Vector2.new(0.5, 0.5)
	dim.Position = UDim2.fromScale(0.5, 0.5)
	dim.Size = UDim2.fromScale(4, 4)
	dim.BackgroundColor3 = Theme.Colors.Black
	dim.BackgroundTransparency = 0.35
	dim.Active = false
	dim.Parent = modal

	local tileW = if compact then CONFIG.CompactTileWidth else CONFIG.TileWidth
	local tileH = math.floor(tileW * 1.22)
	local gap = CONFIG.TileGap
	local width = math.min(1000, screen.X * 0.96)
	local resultH = if compact then 74 else 112
	local reelTop = if compact then 52 else 78 -- phones: title and zone share one line
	local height = math.min(reelTop + tileH + 24 + 8 + resultH + Theme.TOUCH + 22, screen.Y * 0.98)
	local panel = Panel.new({ Name = "Panel", Size = UDim2.fromOffset(width, height), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2, Parent = modal })
	local pop = Instance.new("UIScale")
	pop.Scale = 0.92
	pop.Parent = panel
	TweenService:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	-- title, zone, Gold
	if compact then
		Theme.text({ Name = "Title", Font = "Title", Text = `Opening: {weapon.Name}  -  {zoneName(weapon)}`, TextSize = 26, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(1, -200, 0, 34), Position = UDim2.fromOffset(16, 10), ZIndex = 3, Parent = panel })
	else
		Theme.text({ Name = "Title", Font = "Title", Text = `Opening: {weapon.Name}`, TextSize = 34, Color = Theme.Colors.Gold, Size = UDim2.new(1, -260, 0, 40), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3, Parent = panel })
		Theme.text({ Name = "Zone", Text = zoneName(weapon), TextSize = 20, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -260, 0, 24), Position = UDim2.new(0.5, 0, 0, 50), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3, Parent = panel })
	end
	local goldBox = Instance.new("Frame")
	goldBox.Name = "Gold"
	goldBox.BackgroundColor3 = Theme.Colors.WoodInset
	goldBox.Size = UDim2.fromOffset(if compact then 150 else 190, if compact then 34 else 40)
	goldBox.Position = UDim2.new(1, -14, 0, if compact then 10 else 14)
	goldBox.AnchorPoint = Vector2.new(1, 0)
	goldBox.ZIndex = 3
	Theme.corner(goldBox, 20)
	Theme.stroke(goldBox, Theme.Colors.GoldDark, 2)
	goldBox.Parent = panel
	Icons.create("Gold", goldBox, { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, -6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 4 })
	local goldLabel = Theme.text({ Font = "Number", Text = "", TextSize = 22, Align = "Right", Size = UDim2.new(1, -50, 1, -6), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 4, Parent = goldBox })
	local goldConn = State.observe("Gold", function(value)
		goldLabel.Text = Format.number(value or 0)
	end)

	-- reel window
	local reel = Instance.new("TextButton") -- a tap on the reel skips the spin
	reel.Name = "Reel"
	reel.Text = ""
	reel.AutoButtonColor = false
	reel.ClipsDescendants = true
	reel.BackgroundColor3 = Theme.Colors.WoodInset
	reel.Size = UDim2.new(1, -28, 0, tileH + 24)
	reel.Position = UDim2.fromOffset(14, reelTop)
	reel.ZIndex = 3
	Theme.corner(reel, 6)
	Theme.stroke(reel, Theme.Colors.GoldDark, 2)
	reel.Parent = panel
	local reelWidth = width - 28
	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(0, CONFIG.TileCount * (tileW + gap), 1, 0)
	strip.ZIndex = 4
	strip.Parent = reel

	local rng = Random.new()
	local tiles, scales = {}, {}
	for index = 1, CONFIG.TileCount do
		local tier = if index == CONFIG.WinIndex then result.rarity else visualTier(rng)
		local tile, scale = makeTile(strip, weapon, tier, tileW, tileH, (index - 1) * (tileW + gap))
		tile.ZIndex = 4
		tiles[index] = tile
		scales[index] = scale
	end
	-- side shades and the center marker
	for _, side in ipairs({ 0, 1 }) do
		local shade = Instance.new("Frame")
		shade.BackgroundColor3 = Theme.Colors.Black
		shade.BorderSizePixel = 0
		shade.Size = UDim2.new(0.22, 0, 1, 0)
		shade.Position = UDim2.fromScale(side, 0)
		shade.AnchorPoint = Vector2.new(side, 0)
		shade.ZIndex = 6
		local fade = Instance.new("UIGradient")
		fade.Transparency = if side == 0 then NumberSequence.new(0.2, 1) else NumberSequence.new(1, 0.2)
		fade.Parent = shade
		shade.Parent = reel
	end
	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0)
	marker.Position = UDim2.fromScale(0.5, 0)
	marker.Size = UDim2.new(0, 4, 1, 0)
	marker.BackgroundColor3 = Theme.Colors.Gold
	marker.BorderSizePixel = 0
	marker.ZIndex = 7
	marker.Parent = reel
	for _, y in ipairs({ 0, 1 }) do
		local arrow = Instance.new("Frame")
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.Position = UDim2.fromScale(0.5, y)
		arrow.Size = UDim2.fromOffset(20, 20)
		arrow.Rotation = 45
		arrow.BackgroundColor3 = Theme.Colors.Gold
		arrow.BorderSizePixel = 0
		arrow.ZIndex = 7
		Theme.stroke(arrow, Theme.Colors.Ink, 1.5)
		arrow.Parent = reel
	end
	-- effects layer centered on the marker (not clipped by the reel)
	local fx = Instance.new("Frame")
	fx.Name = "Fx"
	fx.BackgroundTransparency = 1
	fx.AnchorPoint = Vector2.new(0.5, 0.5)
	fx.Position = UDim2.new(0.5, 0, 0, reelTop + (tileH + 24) / 2)
	fx.Size = UDim2.fromOffset(10, 10)
	fx.ZIndex = 8
	fx.Parent = panel

	-- result area (hidden until the reveal)
	local resultFrame = Instance.new("Frame")
	resultFrame.Name = "Result"
	resultFrame.BackgroundTransparency = 1
	resultFrame.Size = UDim2.new(1, -28, 0, resultH)
	resultFrame.Position = UDim2.fromOffset(14, reelTop + tileH + 30)
	resultFrame.Visible = false
	resultFrame.ZIndex = 3
	resultFrame.Parent = panel
	Theme.text({ Name = "Banner", Font = "Title", Text = "", TextSize = if compact then 30 else 44, Size = UDim2.new(1, 0, 0, if compact then 32 else 48), ZIndex = 4, Parent = resultFrame })
	Theme.text({ Name = "Details", Text = "", TextSize = if compact then 17 else 20, Wrapped = true, Size = UDim2.new(1, 0, 0, if compact then 22 else 34), Position = UDim2.fromOffset(0, if compact then 32 else 50), ZIndex = 4, Parent = resultFrame })
	Theme.text({ Name = "Hint", Font = "Button", Text = "", TextSize = if compact then 16 else 20, Size = UDim2.new(1, 0, 0, if compact then 20 else 24), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), ZIndex = 4, Parent = resultFrame })

	-- buttons
	local row = Instance.new("Frame")
	row.Name = "Buttons"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -28, 0, Theme.TOUCH)
	row.Position = UDim2.new(0.5, 0, 1, if compact then -10 else -14)
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.ZIndex = 3
	row.Parent = panel
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 12)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	local buttonW = if compact then 170 else 200
	local opening: Opening
	local buttons = {}
	buttons.Skip = Button.new({ Name = "Skip", Text = "Skip", Style = "secondary", Size = UDim2.fromOffset(buttonW, Theme.TOUCH), LayoutOrder = 1, ZIndex = 4, Parent = row, OnClick = function()
		reveal(opening)
	end })
	buttons.Equip = Button.new({ Name = "Equip", Text = "Equip", Style = "go", Size = UDim2.fromOffset(buttonW, Theme.TOUCH), LayoutOrder = 2, ZIndex = 4, Parent = row, OnClick = function()
		local ok, message = Net.request("EquipWeapon", result.uid)
		if ok then
			buttons.Equip:SetText("Equipped")
			buttons.Equip:SetEnabled(false)
			Notifier.push({ Kind = "info", Text = `Equipped {WeaponRarities.get(result.rarity).Name} {weapon.Name}`, Icon = weapon.Icon or weapon.Category })
		else
			Notifier.push({ Kind = "error", Text = tostring(message or "Could not equip") })
		end
	end })
	buttons.Again = Button.new({ Name = "Again", Text = "Open again", Style = "primary", Size = UDim2.fromOffset(buttonW, Theme.TOUCH), LayoutOrder = 3, ZIndex = 4, Parent = row, OnClick = function()
		if (State.get("Gold") or 0) < Weapons.price(weapon.Zone) then
			Sfx.play("Denied")
			Notifier.push({ Kind = "error", Text = "Not enough Gold" })
			return
		end
		close()
		if onAgain then
			onAgain(weapon.Id)
		end
	end })
	buttons.Close = Button.new({ Name = "Close", Text = "Close", Style = "secondary", Size = UDim2.fromOffset(buttonW, Theme.TOUCH), LayoutOrder = 4, ZIndex = 4, Parent = row, OnClick = close })
	for _, name in ipairs({ "Equip", "Again", "Close" }) do
		buttons[name].Instance.Visible = false
	end

	-- motion: one tween; the stop lands at a random spot inside the winning tile, like CS:GO
	local pitch = tileW + gap
	local startX = 0
	local landing = (CONFIG.WinIndex - 1) * pitch + tileW * (0.12 + rng:NextNumber() * 0.76)
	local endX = reelWidth / 2 - landing
	local duration = if Settings.get("FastOpen") then CONFIG.FastSpinSeconds else CONFIG.SpinSeconds
	local tween = TweenService:Create(strip, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(endX, 0) })
	opening = {
		result = result,
		weapon = weapon,
		modal = modal,
		tiles = tiles,
		scales = scales,
		strip = strip,
		tween = tween,
		conn = nil,
		goldConn = goldConn,
		revealed = false,
		endX = endX,
		equippedBefore = State.get("EquippedWeapon"),
		onAgain = onAgain,
		buttons = buttons,
		fx = fx,
		result_ = resultFrame,
	}
	current = opening
	reel.Activated:Connect(function()
		reveal(opening)
	end)
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			reveal(opening)
		end
	end)

	-- per frame: which tile is under the marker (numbers only), tick + enlarge it
	local center = reelWidth / 2
	local distance = endX - startX
	local startTime = os.clock()
	local lastIndex = 0
	opening.conn = RunService.RenderStepped:Connect(function()
		local u = math.min((os.clock() - startTime) / duration, 1)
		local x = startX + distance * TweenService:GetValue(u, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		local index = math.floor((center - x) / pitch) + 1
		if index ~= lastIndex and index >= 1 and index <= CONFIG.TileCount then
			if lastIndex >= 1 then
				scales[lastIndex].Scale = 1
			end
			scales[index].Scale = CONFIG.MarkerScale
			lastIndex = index
			playTick((1 - u) ^ 4) -- normalised speed of an ease-out quint
		end
	end)
	tween:Play()
	Sfx.play("UIOpen")
end



return CaseOpening
