--!strict
-- The hatch screen (docs/menu_systems_brief.txt B1). The server already hatched (PetService); this only shows
-- it: the egg wobbles faster and faster, cracks, bursts, and the pet pops out with its rarity banner (the case
-- opening's effects, CaseOpening.burst), name, species, zone, stats and bonus; a mutation / size (Pets V2,
-- Config/PetMutations) gets its own callout ("GOLDEN!", "HUGE RAINBOW!") and look. Buttons: Equip (when a slot is
-- free), the caller's "next" action (Hatch next / Buy again), Close. Several results (Hatch All) end on a
-- summary grid with Equip Best. A tap on the egg skips to the reveal. Fast Open shortens the wobble.
-- Big and flashy (owner 2026-10-13): the egg drops in and bounces, shakes harder and harder while the light inside
-- builds up, shell chips fly at every crack, then a white flash, the rarity burst, confetti (more for rarer pets)
-- and a screen shake from Legendary; the pet pops in and its 3 Bonus Stats items (Config/PetTraits) pop in one by
-- one. Low FX: no chips, confetti or shake.
-- Real cracking (owner 2026-10-18: "the egg skin should crack bit by bit and then break, just like a real egg"):
-- UI/EggCrack draws the cracks on the egg's own mesh in bursts (a starburst at the hit, then around the middle, up
-- and around the cap), light in the pet's rarity colour shines through them at the end, then the shell breaks into
-- skinned pieces (cap pops off, shards fall, the cup fades) and the pet appears. Without the mesh APIs (the place
-- setting "Allow Mesh & Image APIs" off) the flat 2D cracks below are used instead.
-- The pet's light inside the egg (owner 2026-10-18, UI/EggLight): it grows from almost nothing to its brightest at
-- the break, a warm white turning into the pet's rarity colour, then bursts out and settles behind the pet. The
-- egg is shown alone, without its rarity ring (owner: the ring gave the rarity away).
--   Hatching.play(results, { NextText?, OnNext? })   results = the "results" list of HatchEgg / HatchAll / BuyPremiumEgg
--   Hatching.isActive()
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.GameSystem.Net)
local PetMutations = require(ReplicatedStorage.GameSystem.Config.PetMutations)
local PetRarities = require(ReplicatedStorage.GameSystem.Config.PetRarities)
local Pets = require(ReplicatedStorage.GameSystem.Config.Pets)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local PetTraits = require(ReplicatedStorage.GameSystem.Config.PetTraits)
local State = require(script.Parent.Parent.State)
local Settings = require(script.Parent.Parent.Controllers.SettingsController)
local CaseOpening = require(script.Parent.CaseOpening)
local EggCrack = require(script.Parent.EggCrack)
local EggLight = require(script.Parent.EggLight)
local Notifier = require(script.Parent.Notifier)
local Kit = script.Parent.Kit
local ZoneVisibility = require(Kit.ZoneVisibility)
local Button = require(Kit.Button)
local Chips = require(Kit.Chips)
local TraitCard = require(Kit.TraitCard)
local ModelIcon = require(Kit.ModelIcon)
local Panel = require(Kit.Panel)
local Theme = require(Kit.Theme)
local STAT_ICONS = { Gold = "GoldGain", HP = "MaxHP", Attack = "Attack", Speed = "Speed", Defense = "Defense" }

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
	shell: EggCrack.Shell?, -- the real cracks (nil: flat 2D cracks)
	light: EggLight.Light?, -- the pet's light inside the egg
	eggView: ViewportFrame?,
	breaking: boolean,
	panel: GuiObject,
	stageBase: UDim2,
	revealed: boolean,
	results: { any },
	best: any,
	options: Options,
}

local root: Frame? = nil
local DROP_SECONDS = 0.45 -- the egg's fall at the start
-- real cracks: how far they have spread (0..1) along the wobble (0..1); bursts with short pauses = "bit by bit"
local CRACK_KEYS = { { 0, 0 }, { 0.2, 0 }, { 0.28, 0.12 }, { 0.4, 0.14 }, { 0.5, 0.42 }, { 0.58, 0.45 }, { 0.7, 0.75 }, { 0.76, 0.78 }, { 0.88, 1 } }
local CRACK_BURSTS = { 0.2, 0.4, 0.58, 0.76 } -- a crack sound and a few chips at the start of each burst
local OPEN_FROM = 0.9 -- the cracks widen and glow from here to the break
local BREAK_REVEAL = 0.15 -- seconds between the shell breaking and the pet's reveal
local BREAK_ROOM = 1.9 -- the egg's viewport grows by this at the break (camera widened) so the pieces can fly out
local EGG_ZOOM = 1.25 -- the egg's framing (as Kit/ModelIcon frames the egg icons)
-- effects (defined below reveal's helpers)
local whiteFlash: (any, number) -> ()
local confetti: (any, number) -> ()
local shake: (GuiObject, number, number) -> ()
local itemCards: (any, { [string]: any }, number) -> ()
local itemDots: (GuiObject, { [string]: any }) -> ()
local breakEgg: (any) -> ()
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
	if show.shell then
		show.shell:destroy()
	end
	if show.light then
		show.light:destroy()
	end
	show.modal:Destroy()
	Sfx.play("UIClose")
end

local function crackLines(show: Show, step: number, flat: boolean)
	-- 2D cracks drawn over the egg, a few more at every step (only without the real cracks)
	local rng = Random.new(step * 17 + 3)
	for _ = 1, if flat then 3 else 0 do
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
	-- the real cracks tick with short crack sounds (3 variants), the flat ones keep the long crunch
	local small = `EggCrackSmall{(step - 1) % 3 + 1}`
	Sfx.play(if not flat and Sfx.find(small) then small else "EggCrack")
	-- shell chips fly off
	if Settings.get("LowFx") ~= true then
		for _ = 1, 3 + step do
			local chip = Instance.new("Frame")
			chip.AnchorPoint = Vector2.new(0.5, 0.5)
			chip.Position = UDim2.fromScale(0.5 + rng:NextNumber(-0.1, 0.1), 0.45 + rng:NextNumber(-0.15, 0.1))
			chip.Size = UDim2.fromOffset(rng:NextInteger(7, 13), rng:NextInteger(6, 11))
			chip.Rotation = rng:NextNumber(0, 360)
			chip.BackgroundColor3 = Color3.fromRGB(250, 240, 220)
			chip.BorderSizePixel = 0
			chip.ZIndex = 7
			Theme.corner(chip, 3)
			chip.Parent = show.cracks
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = rng:NextNumber(70, 140)
			local tween = TweenService:Create(chip, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(chip.Position.X.Scale, math.cos(angle) * distance, chip.Position.Y.Scale, math.sin(angle) * distance + 40),
				Rotation = chip.Rotation + rng:NextNumber(-240, 240),
				BackgroundTransparency = 1,
			})
			tween.Completed:Connect(function()
				chip:Destroy()
			end)
			tween:Play()
		end
	end
end

local function info(show: Show, text: string, size: number, color: Color3?, order: number, font: string?): TextLabel
	return Theme.text({ Font = font or "Body", Text = text, TextSize = size, Wrapped = true, Color = color, Size = UDim2.new(1, 0, 0, size + 8), LayoutOrder = order, ZIndex = 4, Parent = show.info })
end

local function equippedCount(): number
	return #(State.get("EquippedPets") or {})
end

-- the stored-pet shape of a hatch result (Config/PetMutations helpers read it)
local function asPet(result: any): { [string]: any }
	return { id = result.petId, rarity = result.rarity, mutation = result.mutation, size = result.size, traits = result.traits }
end

-- "HUGE GOLDEN! x2.4" over the bottom of the pet picture, in the mutation's color (size only: gold), with a
-- bounce; nil for a plain pet
local function callout(show: Show, result: any): TextLabel?
	local prefix = PetMutations.prefix(asPet(result))
	if prefix == "" then
		return nil
	end
	local mutation = PetMutations.get(result.mutation)
	local size = if Theme.isCompact() then 24 else 32
	local label = Theme.text({ Name = "Callout", Font = "Title", Text = `{string.upper(prefix)}! {PetMutations.multText(asPet(result))}`, TextSize = size, Color = if mutation then mutation.Color else Theme.Colors.Gold, StrokeThickness = 2, Size = UDim2.new(1.4, 0, 0, size + 8), Position = UDim2.new(0.5, 0, 1, -2), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 8, Parent = show.stageHolder })
	local bounce = Instance.new("UIScale")
	bounce.Scale = 1.6
	bounce.Parent = label
	TweenService:Create(bounce, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if mutation and mutation.Id == "Rainbow" then
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 90)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 220, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 100, 255)),
		})
		gradient.Parent = label
		label.TextColor3 = Color3.new(1, 1, 1)
	end
	return label
end

-- one pet: the model pops out, rarity banner, values
local function revealOne(show: Show, result: any)
	local species = Pets.ById[result.petId]
	local rarity = Rarities.get(result.rarity)
	local view = ModelIcon.pet(result.petId, { Size = UDim2.fromScale(0.92, 0.92), ZIndex = 4, Parent = show.stage, Mutation = result.mutation, Gear = PetTraits.gearKey(asPet(result)) })
	local pop = Instance.new("UIScale")
	pop.Scale = 0.1
	pop.Parent = view
	TweenService:Create(pop, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- a happy hop once it is out
	task.delay(0.55, function()
		if view.Parent then
			local up = TweenService:Create(view, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.5, -18) })
			up.Completed:Connect(function()
				if view.Parent then
					TweenService:Create(view, TweenInfo.new(0.3, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
				end
			end)
			up:Play()
		end
	end)
	show.stopSpin = ModelIcon.turntable(view, 7)
	local banner = info(show, rarity.Name, if Theme.isCompact() then 30 else 40, nil, 1, "Title")
	Theme.paintRarity(banner, result.rarity)
	callout(show, result)
	local zone = Zones.List[result.zone]
	info(show, Pets.displayName(asPet(result)), if Theme.isCompact() then 24 else 30, Theme.Colors.Gold, 2, "Title")
	local _ = zone
	-- the values include the mutation x size boost; shown as pictures + numbers (kid-friendly UI)
	local lines, bonus = Pets.describe(result.petId, result.rarity, Hatching.petEffect() * PetMutations.mult(asPet(result)))
	local chipRow = Chips.row(show.info, { Align = "Center", LayoutOrder = 4, ZIndex = 4 })
	for i, stat in ipairs(species.Stats) do
		Chips.chip(chipRow, STAT_ICONS[stat] or "Star", string.match(lines[i] or "", "^(%S+)") or "", { Height = 40, LayoutOrder = i, ZIndex = 4 })
	end
	Chips.chip(chipRow, "Star", string.match(bonus, "^(%S+)") or "", { Height = 40, LayoutOrder = 10, ZIndex = 4, TextColor = Theme.Colors.Good })
	if result.lucky then
		info(show, "Lucky!", 22, Theme.Colors.Gold, 6, "Button") -- Egg Luck made it one rarity higher
	end
	itemCards(show, asPet(result), 5)
	local equip = show.buttons.Equip
	equip.Instance.Visible = true
	if equippedCount() >= Hatching.slots() then
		equip:SetStyle("disabled") -- every slot is full
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
	local banner = info(show, `x{#show.results}`, if compact then 26 else 34, Theme.Colors.Gold, 1, "Title")
	banner.LayoutOrder = 1
	local best = Rarities.get(show.best.rarity)
	local bestLine = info(show, `{best.Name} {Pets.displayName(asPet(show.best))}`, 20, nil, 2, "Button")
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
		if a.rarity ~= b.rarity then
			return a.rarity > b.rarity
		end
		return PetMutations.rank(asPet(a)) > PetMutations.rank(asPet(b))
	end)
	for index, result in ipairs(sorted) do
		local cell = Instance.new("Frame")
		cell.BackgroundColor3 = if result.rarity == #Rarities.List then Rarities.SECRET_CORE else Theme.Colors.WoodInset
		cell.LayoutOrder = index
		cell.ZIndex = 4
		Theme.corner(cell, 6)
		local stroke = Theme.stroke(cell, Theme.Colors.GoldDark, 2.5)
		Theme.paintRarity(stroke, result.rarity)
		ModelIcon.pet(result.petId, { Size = UDim2.new(1, -6, 1, -26), Position = UDim2.new(0.5, 0, 0, 3), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 5, Parent = cell, Mutation = result.mutation, Gear = PetTraits.gearKey(asPet(result)) })
		local name = Theme.text({ Font = "Button", Text = Rarities.get(result.rarity).Name, TextSize = 14, Size = UDim2.new(1, -4, 0, 20), Position = UDim2.new(0.5, 0, 1, -2), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 5, Parent = cell })
		Theme.paintRarity(name, result.rarity)
		local prefix = PetMutations.prefix(asPet(result))
		if prefix ~= "" then
			local mutation = PetMutations.get(result.mutation)
			Theme.text({ Font = "Button", Text = prefix, TextSize = 12, Color = if mutation then mutation.Color else Theme.Colors.Gold, Size = UDim2.new(1, -4, 0, 16), Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 6, Parent = cell })
		end
		itemDots(cell, asPet(result))
		local cellPop = Instance.new("UIScale")
		cellPop.Scale = 0
		cellPop.Parent = cell
		task.delay(0.05 * (index - 1), function()
			TweenService:Create(cellPop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
		cell.Parent = grid
	end
	local equip = show.buttons.Equip
	equip.Instance.Visible = true -- the check equips the best pets
end

-- a white flash over the whole screen (stronger for rarer pets)
whiteFlash = function(show: Show, tier: number)
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.AnchorPoint = Vector2.new(0.5, 0.5)
	flash.Position = UDim2.fromScale(0.5, 0.5)
	flash.Size = UDim2.fromScale(4, 4)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = if tier >= Rarities.GLOW_FROM then 0 else 0.35
	flash.BorderSizePixel = 0
	flash.ZIndex = 40
	flash.Parent = show.modal
	local tween = TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	tween.Completed:Connect(function()
		flash:Destroy()
	end)
	tween:Play()
end

-- confetti falling over the panel (more for rarer pets)
local CONFETTI_COLORS = { Color3.fromRGB(255, 90, 100), Color3.fromRGB(255, 200, 60), Color3.fromRGB(90, 220, 120), Color3.fromRGB(80, 170, 255), Color3.fromRGB(200, 110, 255), Color3.new(1, 1, 1) }
confetti = function(show: Show, tier: number)
	local rng = Random.new()
	local rarityColor = Rarities.get(tier).Color
	for _ = 1, 24 + tier * 10 do
		local piece = Instance.new("Frame")
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		local x = rng:NextNumber(0.05, 0.95)
		piece.Position = UDim2.fromScale(x, rng:NextNumber(-0.25, -0.02))
		piece.Size = UDim2.fromOffset(rng:NextInteger(7, 12), rng:NextInteger(12, 20))
		piece.Rotation = rng:NextNumber(0, 360)
		piece.BackgroundColor3 = if rng:NextNumber() < 0.35 then rarityColor else CONFETTI_COLORS[rng:NextInteger(1, #CONFETTI_COLORS)]
		piece.BorderSizePixel = 0
		piece.ZIndex = 30
		piece.Parent = show.panel
		local time = rng:NextNumber(1.4, 2.4)
		local tween = TweenService:Create(piece, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(x + rng:NextNumber(-0.12, 0.12), 1.08),
			Rotation = piece.Rotation + rng:NextNumber(-540, 540),
		})
		tween.Completed:Connect(function()
			piece:Destroy()
		end)
		task.delay(rng:NextNumber(0, 0.35), function()
			tween:Play()
		end)
	end
end

-- a short shake of a frame
shake = function(target: GuiObject, power: number, seconds: number)
	local base = target.Position
	local rng = Random.new()
	task.spawn(function()
		local stop = os.clock() + seconds
		while os.clock() < stop and target.Parent do
			local k = (stop - os.clock()) / seconds
			target.Position = base + UDim2.fromOffset(rng:NextNumber(-power, power) * k, rng:NextNumber(-power, power) * k)
			task.wait(0.03)
		end
		target.Position = base
	end)
end

-- the 3 Bonus Stats items as cards in a row, popping in one after the other (rarer items: a sound and a flash)
itemCards = function(show: Show, pet: { [string]: any }, order: number)
	if not PetTraits.has(pet) then
		return
	end
	local compact = Theme.isCompact()
	local row = Instance.new("Frame")
	row.Name = "Items"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, if compact then 48 else 60)
	row.LayoutOrder = order
	row.ZIndex = 4
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	row.Parent = show.info
	for i, slot in ipairs(PetTraits.SLOTS) do
		local trait = PetTraits.get(pet, slot)
		if trait then
			local card = TraitCard.new(row, slot, trait, { Size = UDim2.new(1 / 3, -6, 1, 0), Compact = compact, ZIndex = 5, LayoutOrder = i })
			local scale = Instance.new("UIScale")
			scale.Scale = 0
			scale.Parent = card
			task.delay(0.45 + (i - 1) * 0.3, function()
				if not card.Parent then
					return
				end
				local tier = PetTraits.tier(trait)
				Sfx.play(if tier >= Rarities.GLOW_FROM then "RarityReveal" else "UIClick")
				TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end)
		end
	end
end

-- the 3 items as small dots in their rarity colours (summary cells)
itemDots = function(parent: GuiObject, pet: { [string]: any })
	local dots = Instance.new("Frame")
	dots.Name = "Items"
	dots.BackgroundTransparency = 1
	dots.Size = UDim2.fromOffset(40, 11)
	dots.Position = UDim2.new(0.5, 0, 0, 3)
	dots.AnchorPoint = Vector2.new(0.5, 0)
	dots.ZIndex = 6
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 3)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = dots
	for i, slot in ipairs(PetTraits.SLOTS) do
		local trait = PetTraits.get(pet, slot)
		if trait then
			local dot = Instance.new("Frame")
			dot.Size = UDim2.fromOffset(10, 10)
			dot.LayoutOrder = i
			dot.ZIndex = 7
			Theme.round(dot)
			Theme.stroke(dot, Theme.Colors.Ink, 1)
			Theme.paintRarity(dot, PetTraits.tier(trait))
			dot.Parent = dots
		end
	end
	dots.Parent = parent
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
	if show.shell and not show.breaking then
		-- skipped before the break: no pieces
		show.shell:destroy()
		show.shell = nil
	end
	show.stage:ClearAllChildren()
	show.cracks:ClearAllChildren()
	show.stageHolder.Position = show.stageBase
	local tier = show.best.rarity
	local low = Settings.get("LowFx") == true
	whiteFlash(show, tier)
	if not low then
		confetti(show, tier)
		if tier >= Rarities.LEGENDARY_SOUND_FROM then
			shake(show.panel, 6 + tier, 0.4)
		end
	end
	-- the light bursts out (if the egg did not break) and settles into a calm glow behind the pet; with several
	-- pets (summary grid) it fades away
	if show.light then
		show.light:reveal(#show.results == 1)
	end
	Sfx.play("PetHatch")
	-- a mutation always gets the big reveal sound
	local mutated = PetMutations.get(show.best.mutation) ~= nil
	Sfx.play(if tier >= Rarities.LEGENDARY_SOUND_FROM or mutated then "RarityLegendary" else "RarityReveal")
	-- the egg's own light (UI/EggLight) is the burst of light here: no flat flash disc or hard rays from the case
	-- opening (they would double it); its sparkles and the Divine / Secret screen glow stay
	CaseOpening.burst(show.fx, show.modal, tier, { NoLight = true })
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

-- The shell breaks along its cracks; the pet is revealed a moment later while the pieces still fly.
breakEgg = function(show: Show)
	local shell, view = show.shell, show.eggView
	if show.revealed or show.breaking or not shell or not view then
		reveal(show)
		return
	end
	show.breaking = true
	if show.conn then
		show.conn:Disconnect()
		show.conn = nil
	end
	if show.light then
		show.light:burst() -- the light bursts out as the shell gives way (before the view grows)
	end
	-- room for the pieces: a bigger viewport with a wider camera, so the egg keeps its size on screen; it moves out
	-- of the stage (cleared by the reveal) and stays above the pet until the pieces are gone
	local camera = view.CurrentCamera
	if camera then
		camera.FieldOfView = math.deg(2 * math.atan(math.tan(math.rad(camera.FieldOfView / 2)) * BREAK_ROOM))
		view.Size = UDim2.fromScale(view.Size.X.Scale * BREAK_ROOM, view.Size.Y.Scale * BREAK_ROOM)
	end
	view.ZIndex = 5
	view.Parent = show.stageHolder
	show.stageHolder.Position = show.stageBase
	Sfx.play("EggShellBreak")
	shell:shatter(view)
	task.delay(BREAK_REVEAL, function()
		if current == show then
			reveal(show)
		end
	end)
	task.delay(1.4, function()
		view:Destroy()
	end)
end

-- The hatch screen shows the egg alone: its rarity ring goes (owner 2026-10-18: it gave the pet's rarity away and
-- looked ugly) and the camera is framed on the egg only (the view is a fresh clone of the icon template).
local function eggOnly(view: ViewportFrame)
	local model = view:FindFirstChildOfClass("Model")
	if not model then
		return
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("RarityRing") then
			part:Destroy()
		end
	end
	local egg = model:FindFirstChild("Egg", true)
	local camera = view.CurrentCamera
	if camera and egg and egg:IsA("BasePart") then
		local radius = math.max(egg.Size.X, egg.Size.Y, egg.Size.Z) * 0.5
		local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * EGG_ZOOM
		camera.CFrame = CFrame.lookAt(egg.Position + Vector3.new(0, radius * 0.45, -distance), egg.Position)
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
		if result.rarity > best.rarity or (result.rarity == best.rarity and PetMutations.rank(asPet(result)) > PetMutations.rank(asPet(best))) then
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
	local height = math.min(if compact then 360 else 660, screen.Y * 0.96)
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
	-- kid-friendly UI: pictures (check = equip, egg = again, X = close)
	buttons.Skip = Button.new({ Name = "Skip", Text = "Skip", Style = "secondary", Size = UDim2.fromOffset(buttonW, Theme.TOUCH), LayoutOrder = 1, ZIndex = 4, Parent = row, OnClick = function()
		reveal(show)
	end })
	buttons.Equip = Button.new({ Name = "Equip", Icon = "Check", Style = "go", Size = UDim2.fromOffset(buttonW, Theme.TOUCH), LayoutOrder = 2, ZIndex = 4, Parent = row, OnClick = function()
		if #show.results > 1 then
			local ok, message = Net.request("EquipBestPets")
			if ok then
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
			buttons.Equip:SetEnabled(false)
			Notifier.push({ Kind = "info", Text = `Equipped {Pets.ById[result.petId].Name}`, Icon = "Pets" })
		else
			Sfx.play("Denied")
			Notifier.push({ Kind = "error", Text = tostring(message or "Could not equip") })
		end
	end })
	buttons.Next = Button.new({ Name = "Next", Text = opts.NextText, Icon = "Egg", Style = "primary", Size = UDim2.fromOffset(buttonW, Theme.TOUCH), LayoutOrder = 3, ZIndex = 4, Parent = row, OnClick = function()
		close()
		if opts.OnNext then
			opts.OnNext()
		end
	end })
	buttons.Close = Button.new({ Name = "Close", Icon = "Close", Style = "secondary", Size = UDim2.fromOffset(buttonW, Theme.TOUCH), LayoutOrder = 4, ZIndex = 4, Parent = row, OnClick = close })
	for _, name in ipairs({ "Equip", "Next", "Close" }) do
		buttons[name].Instance.Visible = false
	end

	show = { modal = modal, stageHolder = stageHolder, stage = stage, fx = fx, cracks = cracks, info = infoFrame, buttons = buttons, conn = nil, stopSpin = nil, shell = nil, light = nil, eggView = nil, breaking = false, panel = panel, stageBase = stageHolder.Position, revealed = false, results = results, best = best, options = opts }
	current = show
	stageHolder.Activated:Connect(function()
		reveal(show)
	end)

	-- the egg drops in and bounces, then rocks around its base, faster and wider, cracks at 35 / 60 / 82 %
	local eggView = ModelIcon.egg(best.zone, if best.premiumEgg then nil else best.eggRarity, { Size = UDim2.fromScale(0.86, 0.86), ZIndex = 4, Parent = stage })
	eggOnly(eggView)
	show.eggView = eggView
	local fast = Settings.get("FastOpen") == true
	local low = Settings.get("LowFx") == true
	-- the pet's light inside the egg: the glow and beams behind it, the egg's lighting and the cracks' glow
	local light = EggLight.new({ Holder = stageHolder, View = eggView, Tier = best.rarity, Low = low })
	show.light = light
	-- the real cracks are prepared while the egg drops in (the mesh loads once per zone)
	local eggModel = eggView:FindFirstChildOfClass("Model")
	local eggPart = eggModel and eggModel:FindFirstChild("Egg", true)
	if eggPart and eggPart:IsA("MeshPart") then
		task.spawn(function()
			local shell = EggCrack.new(eggPart, { Camera = eggView.CurrentCamera, Low = low })
			if not shell then
				return
			end
			if current ~= show or show.revealed then
				shell:destroy()
				return
			end
			show.shell = shell
		end)
	end
	local drop = if fast then 0 else DROP_SECONDS
	if drop > 0 then
		eggView.Position = UDim2.fromScale(0.5, -0.6)
		TweenService:Create(eggView, TweenInfo.new(drop, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	end
	local squash = Instance.new("UIScale")
	squash.Parent = eggView
	local egg = eggView:FindFirstChildOfClass("Model")
	local base = egg and egg:GetPivot()
	local duration = if fast then PetRarities.FastHatchSeconds else PetRarities.HatchSeconds
	local start = os.clock() + drop
	local phase = 0
	local crackSteps = { 0.35, 0.6, 0.82 }
	local nextCrack = 1
	local nextBurst = 1
	local shakeRng = Random.new()
	show.conn = RunService.RenderStepped:Connect(function(dt)
		local u = math.clamp((os.clock() - start) / duration, 0, 1)
		phase += dt * (2 + 11 * u) * math.pi * 2
		if egg and base then
			local angle = math.sin(phase) * (0.08 + 0.38 * u)
			egg:PivotTo(base * CFrame.Angles(0, 0, angle))
		end
		squash.Scale = 1 + math.sin(phase * 0.5) * 0.05 * u
		-- the whole stage trembles more and more
		if not low and u > 0.2 then
			local power = (u - 0.2) * (u - 0.2) * 10
			stageHolder.Position = show.stageBase + UDim2.fromOffset(shakeRng:NextNumber(-power, power), shakeRng:NextNumber(-power, power))
		end
		-- how far the real cracks have spread (in bursts); the light grows with it too
		local spread = 1
		for i = 2, #CRACK_KEYS do
			local a, b = CRACK_KEYS[i - 1], CRACK_KEYS[i]
			if u <= b[1] then
				spread = a[2] + (b[2] - a[2]) * (u - a[1]) / (b[1] - a[1])
				break
			end
		end
		local shell = show.shell
		if shell then
			-- the real cracks spread, then widen just before the break (the light colours them)
			shell:setCracks(spread)
			if u > OPEN_FROM then
				shell:open((u - OPEN_FROM) / (1 - OPEN_FROM))
			end
			if nextBurst <= #CRACK_BURSTS and u >= CRACK_BURSTS[nextBurst] then
				crackLines(show, nextBurst, false)
				nextBurst += 1
			end
		elseif nextCrack <= #crackSteps and u >= crackSteps[nextCrack] then
			crackLines(show, nextCrack, true)
			nextCrack += 1
		end
		-- the pet's light inside: faint, then growing with the cracks, pulsing faster and faster
		light:update(u, spread, dt, shell)
		if u >= 1 then
			if shell then
				breakEgg(show)
			else
				reveal(show)
			end
		end
	end)
	Sfx.play("UIOpen")
end

-- the crack and break sounds are loaded ahead, so the first crack of the first hatch is not late
task.spawn(function()
	local sounds = {}
	for _, name in ipairs({ "EggCrackSmall1", "EggCrackSmall2", "EggCrackSmall3", "EggShellBreak" }) do
		local sound = Sfx.find(name)
		if sound then
			table.insert(sounds, sound)
		end
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, sounds)
end)

return Hatching
