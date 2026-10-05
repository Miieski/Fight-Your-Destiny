--!strict
-- The hatch screen (docs/menu_systems_brief.txt B1). The server already hatched (PetService); this only shows
-- it: the egg wobbles faster and faster, cracks, bursts, and the pet pops out with its rarity banner (the case
-- opening's effects, CaseOpening.burst), name, species, zone, stats and bonus. Buttons: Equip (when a slot is
-- free), the caller's "next" action (Hatch next / Buy again), Close. Several results (Hatch All) end on a
-- summary grid with Equip Best. A tap on the egg skips to the reveal. Fast Open shortens the wobble.
--   Hatching.play(results, { NextText?, OnNext? })   results = the "results" list of HatchEgg / HatchAll / BuyPremiumEgg
--   Hatching.isActive()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.GameSystem.Net)
local PetRarities = require(ReplicatedStorage.GameSystem.Config.PetRarities)
local Pets = require(ReplicatedStorage.GameSystem.Config.Pets)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.State)
local Settings = require(script.Parent.Parent.Controllers.SettingsController)
local CaseOpening = require(script.Parent.CaseOpening)
local Notifier = require(script.Parent.Notifier)
local Kit = script.Parent.Kit
local ZoneVisibility = require(Kit.ZoneVisibility)
local Button = require(Kit.Button)
local ModelIcon = require(Kit.ModelIcon)
local Panel = require(Kit.Panel)
local Theme = require(Kit.Theme)

local Hatching = {}

local DATA_KEYS = { "Attributes", "Rebirths", "RebirthUpgrades", "Weapons", "EquippedWeapon", "Pets", "EquippedPets", "Armor", "EquippedArmor", "Boosts", "Zones" }

type Options = { NextText: string?, OnNext: (() -> ())? }
type Show = {
	modal: Frame,
	stageHolder: GuiObject,
	stage: Frame,
	fx: Frame,
	cracks: Frame,
	info: Frame,
	buttons: { [string]: any },
	conn: RBXScriptConnection?,
	stopSpin: (() -> ())?,
	revealed: boolean,
	results: { any },
	best: any,
	options: Options,
}

local root: Frame? = nil
local current: Show? = nil

function Hatching.isActive(): boolean
	return current ~= nil
end

local function ensureRoot(): Frame
	if root then
		return root
	end
	local _, screenRoot = Theme.screen("Hatching", 31)
	root = screenRoot
	return screenRoot
end

-- the owner's pet effectiveness (Faith), as the server computes it
function Hatching.petEffect(): number
	local data = {}
	for _, key in ipairs(DATA_KEYS) do
		data[key] = State.get(key)
	end
	return Stats.compute(data, {}).PetEffectiveness or 1
end

function Hatching.slots(): number
	local passes = State.get("Passes") or {}
	return PetRarities.Slots + (if passes.ExtraPetSlots then PetRarities.ExtraSlots else 0)
end

local function close()
	local show = current
	if not show then
		return
	end
	current = nil
	if show.conn then
		show.conn:Disconnect()
	end
	if show.stopSpin then
		show.stopSpin()
	end
	show.modal:Destroy()
	Sfx.play("UIClose")
end

local function crackLines(show: Show, step: number)
	-- 2D cracks drawn over the egg, a few more at every step
	local rng = Random.new(step * 17 + 3)
	for _ = 1, 3 do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5 + rng:NextNumber(-0.12, 0.12), 0.45 + rng:NextNumber(-0.18, 0.14))
		line.Size = UDim2.new(0, 4, 0.1 + step * 0.03, 0)
		line.Rotation = rng:NextNumber(-70, 70)
		line.BackgroundColor3 = Color3.fromRGB(25, 15, 10)
		line.BorderSizePixel = 0
		line.ZIndex = 6
		line.Parent = show.cracks
	end
	Sfx.play("EggCrack")
end

local function info(show: Show, text: string, size: number, color: Color3?, order: number, font: string?): TextLabel
	return Theme.text({ Font = font or "Body", Text = text, TextSize = size, Wrapped = true, Color = color, Size = UDim2.new(1, 0, 0, size + 8), LayoutOrder = order, ZIndex = 4, Parent = show.info })
end

local function equippedCount(): number
	return #(State.get("EquippedPets") or {})
end

-- one pet: the model pops out, rarity banner, values
local function revealOne(show: Show, result: any)
	local species = Pets.ById[result.petId]
	local rarity = Rarities.get(result.rarity)
	local view = ModelIcon.pet(result.petId, { Size = UDim2.fromScale(0.92, 0.92), ZIndex = 4, Parent = show.stage })
	local pop = Instance.new("UIScale")
	pop.Scale = 0.2
	pop.Parent = view
	TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	show.stopSpin = ModelIcon.turntable(view, 7)
	local banner = info(show, rarity.Name, if Theme.isCompact() then 30 else 40, nil, 1, "Title")
	Theme.paintRarity(banner, result.rarity)
	local zone = Zones.List[result.zone]
	info(show, species.Name, if Theme.isCompact() then 24 else 30, Theme.Colors.Gold, 2, "Title")
	info(show, `{species.Role} - {if species.Premium then "Premium" else (zone and ZoneVisibility.displayName(zone.Id) or "")}`, 18, Theme.Colors.TextDim, 3)
	local lines, bonus = Pets.describe(result.petId, result.rarity, Hatching.petEffect())
	info(show, table.concat(lines, "   "), 20, nil, 4)
	info(show, `Bonus: {bonus}`, 19, Theme.Colors.Good, 5)
	if result.lucky then
		info(show, "Lucky! Egg Luck made it one rarity higher", 17, Theme.Colors.Gold, 6, "Button")
	end
	local equip = show.buttons.Equip
	equip.Instance.Visible = true
	if equippedCount() >= Hatching.slots() then
		equip:SetText("Slots full")
		equip:SetStyle("disabled")
	end
end

-- several pets: a grid, best first
local function revealMany(show: Show)
	local compact = Theme.isCompact()
	-- the summary uses the whole panel: no single pet on the stage
	show.stageHolder.Visible = false
	local top = show.stageHolder.Position.Y.Offset
	show.info.Position = UDim2.fromOffset(16, top)
	show.info.Size = UDim2.new(1, -32, 1, -(top + Theme.TOUCH + 18))
	local infoList = show.info:FindFirstChildOfClass("UIListLayout")
	if infoList then
		infoList.VerticalAlignment = Enum.VerticalAlignment.Top
	end
	local banner = info(show, `{#show.results} pets hatched!`, if compact then 26 else 34, Theme.Colors.Gold, 1, "Title")
	banner.LayoutOrder = 1
	local best = Rarities.get(show.best.rarity)
	local bestLine = info(show, `Best: {best.Name} {Pets.ById[show.best.petId].Name}`, 20, nil, 2, "Button")
	Theme.paintRarity(bestLine, show.best.rarity)
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Summary"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Size = UDim2.new(1, 0, 1, -(if compact then 64 else 84))
	grid.LayoutOrder = 3
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = Theme.Colors.GoldLight
	grid.ZIndex = 4
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(if compact then 74 else 92, if compact then 92 else 112)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = grid
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = grid
	grid.Parent = show.info
	local sorted = table.clone(show.results)
	table.sort(sorted, function(a, b)
		return a.rarity > b.rarity
	end)
	for index, result in ipairs(sorted) do
		local cell = Instance.new("Frame")
		cell.BackgroundColor3 = if result.rarity == #Rarities.List then Rarities.SECRET_CORE else Theme.Colors.WoodInset
		cell.LayoutOrder = index
		cell.ZIndex = 4
		Theme.corner(cell, 6)
		local stroke = Theme.stroke(cell, Theme.Colors.GoldDark, 2.5)
		Theme.paintRarity(stroke, result.rarity)
		ModelIcon.pet(result.petId, { Size = UDim2.new(1, -6, 1, -26), Position = UDim2.new(0.5, 0, 0, 3), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 5, Parent = cell })
		local name = Theme.text({ Font = "Button", Text = Rarities.get(result.rarity).Name, TextSize = 14, Size = UDim2.new(1, -4, 0, 20), Position = UDim2.new(0.5, 0, 1, -2), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 5, Parent = cell })
		Theme.paintRarity(name, result.rarity)
		cell.Parent = grid
	end
	local equip = show.buttons.Equip
	equip:SetText("Equip Best")
	equip.Instance.Visible = true
end

local function reveal(show: Show)
	if show.revealed then
		return
	end
	show.revealed = true
	if show.conn then
		show.conn:Disconnect()
		show.conn = nil
	end
	show.stage:ClearAllChildren()
	show.cracks:ClearAllChildren()
	local tier = show.best.rarity
	Sfx.play("PetHatch")
	Sfx.play(if tier >= Rarities.LEGENDARY_SOUND_FROM then "RarityLegendary" else "RarityReveal")
	CaseOpening.burst(show.fx, show.modal, tier)
	if #show.results == 1 then
		revealOne(show, show.results[1])
	else
		revealMany(show)
	end
	show.buttons.Skip.Instance.Visible = false
	show.buttons.Close.Instance.Visible = true
	if show.options.OnNext then
		show.buttons.Next.Instance.Visible = true
	end
end

-- results: { { uid, petId, rarity, eggRarity, lucky, zone } }
function Hatching.play(results: { any }, options: Options?)
	if #results == 0 then
		return
	end
	if current then
		close()
	end
	local opts = options or {}
	local best = results[1]
	for _, result in ipairs(results) do
		if result.rarity > best.rarity then
			best = result
		end
	end
	local parent = ensureRoot()
	local screen = Theme.size()
	local compact = Theme.isCompact()

	local modal = Instance.new("Frame")
	modal.Name = "Hatch"
	modal.BackgroundTransparency = 1
	modal.Size = UDim2.fromScale(1, 1)
	modal.Parent = parent
	local dim = Instance.new("TextButton") -- blocks the HUD and windows behind while hatching
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.AnchorPoint = Vector2.new(0.5, 0.5)
	dim.Position = UDim2.fromScale(0.5, 0.5)
	dim.Size = UDim2.fromScale(4, 4)
	dim.BackgroundColor3 = Theme.Colors.Black
	dim.BackgroundTransparency = 0.3
	dim.Parent = modal

	local width = math.min(if compact then 760 else 820, screen.X * 0.96)
	local height = math.min(if compact then 360 else 600, screen.Y * 0.96)
	local panel = Panel.new({ Name = "Panel", Size = UDim2.fromOffset(width, height), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2, Parent = modal })
	local popIn = Instance.new("UIScale")
	popIn.Scale = 0.9
	popIn.Parent = panel
	TweenService:Create(popIn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local zone = Zones.List[best.zone]
	local zoneText = if zone then ZoneVisibility.displayName(zone.Id) else ""
	local eggName = if best.premiumEgg then `Premium {zoneText} Egg` else `{Rarities.get(best.eggRarity).Name} {zoneText} Egg`
	local title = if #results > 1 then `Hatching {#results} eggs` else `Hatching: {eggName}`
	Theme.text({ Name = "Title", Font = "Title", Text = title, TextSize = if compact then 26 else 34, Color = Theme.Colors.Gold, Size = UDim2.new(1, -40, 0, if compact then 32 else 42), Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3, Parent = panel })

	-- the stage (egg, then pet) and the info column: side by side on phones, stacked otherwise
	local top = if compact then 44 else 58
	local buttonsH = Theme.TOUCH + 16
	local stageSide = if compact then math.min(height - top - buttonsH - 4, width * 0.42) else math.min(height - top - buttonsH - 205, 290)
	local stageHolder = Instance.new("TextButton") -- a tap skips the wobble
	stageHolder.Name = "Stage"
	stageHolder.Text = ""
	stageHolder.AutoButtonColor = false
	stageHolder.BackgroundTransparency = 1
	stageHolder.Size = UDim2.fromOffset(stageSide, stageSide)
	stageHolder.Position = if compact then UDim2.fromOffset(16, top) else UDim2.new(0.5, 0, 0, top)
	stageHolder.AnchorPoint = if compact then Vector2.zero else Vector2.new(0.5, 0)
	stageHolder.ZIndex = 3
	stageHolder.Parent = panel
	local halo = Instance.new("Frame")
	halo.Name = "Halo"
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.fromScale(0.95, 0.95)
	halo.BackgroundColor3 = Theme.Colors.GoldFace
	halo.BackgroundTransparency = 0.8
	halo.ZIndex = 3
	Theme.round(halo)
	halo.Parent = stageHolder
	local stage = Instance.new("Frame")
	stage.Name = "Model"
	stage.BackgroundTransparency = 1
	stage.Size = UDim2.fromScale(1, 1)
	stage.ZIndex = 4
	stage.Parent = stageHolder
	local cracks = Instance.new("Frame")
	cracks.Name = "Cracks"
	cracks.BackgroundTransparency = 1
	cracks.AnchorPoint = Vector2.new(0.5, 0.5)
	cracks.Position = UDim2.fromScale(0.5, 0.5)
	cracks.Size = UDim2.fromScale(0.6, 0.8)
	cracks.ZIndex = 6
	cracks.Parent = stageHolder
	local fx = Instance.new("Frame")
	fx.Name = "Fx"
	fx.BackgroundTransparency = 1
	fx.AnchorPoint = Vector2.new(0.5, 0.5)
	fx.Position = UDim2.fromScale(0.5, 0.5)
	fx.Size = UDim2.fromOffset(10, 10)
	fx.ZIndex = 7
	fx.Parent = stageHolder

	local infoFrame = Instance.new("Frame")
	infoFrame.Name = "Info"
	infoFrame.BackgroundTransparency = 1
	if compact then
		infoFrame.Position = UDim2.fromOffset(stageSide + 28, top)
		infoFrame.Size = UDim2.new(1, -(stageSide + 44), 1, -(top + buttonsH))
	else
		infoFrame.Position = UDim2.fromOffset(20, top + stageSide + 6)
		infoFrame.Size = UDim2.new(1, -40, 1, -(top + stageSide + 6 + buttonsH))
	end
	infoFrame.ZIndex = 3
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = if compact then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top
	list.Padding = UDim.new(0, 2)
	list.Parent = infoFrame
	infoFrame.Parent = panel

	-- buttons
	local row = Instance.new("Frame")
	row.Name = "Buttons"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -28, 0, Theme.TOUCH)
	row.Position = UDim2.new(0.5, 0, 1, -10)
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.ZIndex = 3
	row.Parent = panel
	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowList.Padding = UDim.new(0, 12)
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Parent = row
	local buttonW = if compact then 170 else 200
	local show: Show
	local buttons = {}
	buttons.Skip = Button.new({ Name = "Skip", Text = "Skip", Style = "secondary", Size = UDim2.fromOffset(buttonW, Theme.TOUCH), LayoutOrder = 1, ZIndex = 4, Parent = row, OnClick = function()
		reveal(show)
	end })
	buttons.Equip = Button.new({ Name = "Equip", Text = "Equip", Style = "go", Size = UDim2.fromOffset(buttonW, Theme.TOUCH), LayoutOrder = 2, ZIndex = 4, Parent = row, OnClick = function()
		if #show.results > 1 then
			local ok, message = Net.request("EquipBestPets")
			if ok then
				buttons.Equip:SetText("Equipped")
				buttons.Equip:SetEnabled(false)
				Notifier.push({ Kind = "info", Text = "Best pets equipped", Icon = "Pets" })
			else
				Notifier.push({ Kind = "error", Text = tostring(message or "Could not equip") })
			end
			return
		end
		local result = show.results[1]
		local ok, message = Net.request("EquipPet", result.uid)
		if ok then
			buttons.Equip:SetText("Equipped")
			buttons.Equip:SetEnabled(false)
			Notifier.push({ Kind = "info", Text = `Equipped {Pets.ById[result.petId].Name}`, Icon = "Pets" })
		else
			Sfx.play("Denied")
			Notifier.push({ Kind = "error", Text = tostring(message or "Could not equip") })
		end
	end })
	buttons.Next = Button.new({ Name = "Next", Text = opts.NextText or "Hatch next", Style = "primary", Size = UDim2.fromOffset(buttonW, Theme.TOUCH), LayoutOrder = 3, ZIndex = 4, Parent = row, OnClick = function()
		close()
		if opts.OnNext then
			opts.OnNext()
		end
	end })
	buttons.Close = Button.new({ Name = "Close", Text = "Close", Style = "secondary", Size = UDim2.fromOffset(buttonW, Theme.TOUCH), LayoutOrder = 4, ZIndex = 4, Parent = row, OnClick = close })
	for _, name in ipairs({ "Equip", "Next", "Close" }) do
		buttons[name].Instance.Visible = false
	end

	show = { modal = modal, stageHolder = stageHolder, stage = stage, fx = fx, cracks = cracks, info = infoFrame, buttons = buttons, conn = nil, stopSpin = nil, revealed = false, results = results, best = best, options = opts }
	current = show
	stageHolder.Activated:Connect(function()
		reveal(show)
	end)

	-- the egg: rocks around its base, faster and wider, cracks at 35 / 60 / 82 %
	local eggView = ModelIcon.egg(best.zone, if best.premiumEgg then nil else best.eggRarity, { Size = UDim2.fromScale(0.86, 0.86), ZIndex = 4, Parent = stage })
	local egg = eggView:FindFirstChildOfClass("Model")
	local base = egg and egg:GetPivot()
	local duration = if Settings.get("FastOpen") then PetRarities.FastHatchSeconds else PetRarities.HatchSeconds
	local start = os.clock()
	local phase = 0
	local crackSteps = { 0.35, 0.6, 0.82 }
	local nextCrack = 1
	show.conn = RunService.RenderStepped:Connect(function(dt)
		local u = math.min((os.clock() - start) / duration, 1)
		phase += dt * (2 + 9 * u) * math.pi * 2
		if egg and base then
			local angle = math.sin(phase) * (0.06 + 0.3 * u)
			egg:PivotTo(base * CFrame.Angles(0, 0, angle))
		end
		if nextCrack <= #crackSteps and u >= crackSteps[nextCrack] then
			crackLines(show, nextCrack)
			nextCrack += 1
		end
		if u >= 1 then
			reveal(show)
		end
	end)
	Sfx.play("UIOpen")
end

return Hatching
