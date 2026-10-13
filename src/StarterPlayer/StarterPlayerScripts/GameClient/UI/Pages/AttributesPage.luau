--!strict
-- Stats window (docs/menu_systems_brief.txt A5), kid-friendly version (owner 2026-10-13: "understandable for a 5 years
-- old, avoid text"; "+ buys at once"; advanced details behind the (i)).
-- Top: level chip, Gold chip, (i) = the full stat list + weapon scaling, Respec (reset icon + Diamond price).
-- Then the key stats as icon + number chips. Then one card per attribute: big icon (tap = what it does), points,
-- bar to 40 with the soft-cap marker, and a big green "+ (coin) price" button that trains ONE point right away
-- (hold to repeat; quick taps are sent together so the server is not flooded).
-- The server decides everything (Net "TrainAttributes" / "RespecAttributes"); numbers come from Util/Stats.compute.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Attributes = require(ReplicatedStorage.GameSystem.Config.Attributes)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local State = require(script.Parent.Parent.Parent.State)
local Notifier = require(script.Parent.Parent.Notifier)
local Kit = script.Parent.Parent.Kit
local Button = require(Kit.Button)
local Chips = require(Kit.Chips)
local Icons = require(Kit.Icons)
local Info = require(Kit.Info)
local Panel = require(Kit.Panel)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local AttributesPage = {}

local TOP = 52
local GREEN = Color3.fromRGB(110, 235, 120)
local REPEAT_DELAY = 0.4
local REPEAT_EVERY = 0.12
local SEND_DELAY = 0.25 -- taps within this time are trained together
local SEND_GAP = 0.35 -- the server takes one TrainAttributes every 0.3 s
local DATA_KEYS = { "Attributes", "Rebirths", "RebirthUpgrades", "Weapons", "EquippedWeapon", "Pets", "EquippedPets", "Armor", "EquippedArmor", "Boosts", "Zones" }

type Card = { points: TextLabel, gain: TextLabel, fill: Frame, plus: any }

local queued: { [string]: number } = Attributes.empty() -- bought, not sent yet
local target: { [string]: number } = {} -- sent: the points the server will show once it has trained them
local sending = false
local sendScheduled = false
local lastSent = -math.huge
local cards: { [string]: Card } = {}
local chips: { [string]: any } = {}
local levelChip: any
local goldChip: any
local respec: any
local root: Frame
local grid: ScrollingFrame
local overlay: Frame? = nil
local windowFrame: GuiObject

-- data ------------------------------------------------------------------------------------------------
local function snapshot(): { [string]: any }
	local data = {}
	for _, key in ipairs(DATA_KEYS) do
		data[key] = State.get(key)
	end
	return data
end

local function count(t: { [string]: number }): number
	local n = 0
	for _, v in pairs(t) do
		n += v
	end
	return n
end

local function have(id: string): number
	return ((State.get("Attributes") or {})[id] or 0)
end

-- points bought on this screen that the saved data does not show yet
local function waiting(id: string): number
	return queued[id] + math.max(0, (target[id] or 0) - have(id))
end

local function waitingCount(): number
	local n = 0
	for _, attribute in ipairs(Attributes.List) do
		n += waiting(attribute.Id)
	end
	return n
end

-- Gold left once the waiting points are paid
local function goldLeft(): number
	return (State.get("Gold") or 0) - Attributes.costOf(Attributes.level(State.get("Attributes")), waitingCount())
end

local function pct(x: number, decimals: number?): string
	local text = string.format(`%.{decimals or 1}f`, x * 100)
	text = string.gsub(text, "%.0+$", "")
	return text .. "%"
end

local function context()
	return { zoneId = Players.LocalPlayer:GetAttribute("CurrentZone"), now = os.time() }
end

-- the stats as the player will have them once the queued points land
local function planned(): ({ [string]: any }, any)
	local data = snapshot()
	local plan = table.clone(data.Attributes or Attributes.empty())
	for _, attribute in ipairs(Attributes.List) do
		plan[attribute.Id] = (plan[attribute.Id] or 0) + waiting(attribute.Id)
	end
	data.Attributes = plan
	return data, Stats.compute(data, context())
end

-- chips: { key, icon, value(stats) -> string }
local CHIPS = {
	{ "MaxHP", "MaxHP", function(s) return Format.number(math.floor(s.MaxHP + 0.5)) end },
	{ "Defense", "Defense", function(s) return Format.number(math.floor(s.Defense * 10 + 0.5) / 10) end },
	{ "Damage", "Attack", function(s) return if s.WeaponId then Format.number(s.WeaponDamage) else "-" end },
	{ "Speed", "Speed", function(s) return "+" .. pct(s.MoveSpeed) end },
	{ "Gold", "GoldGain", function(s) return "x" .. string.format("%.2f", s.GoldMult) end },
	{ "Crit", "Crit", function(s) return pct(s.CritChance, 1) end },
}

-- the full list, behind the (i)
local function detailLines(): { string }
	local _, s = planned()
	local lines = {
		`Max HP: {Format.number(math.floor(s.MaxHP + 0.5))}`,
		`HP regen (out of combat): {Format.number(math.floor(s.RegenPerSecond * 10 + 0.5) / 10)}/s`,
		`Defense: {Format.number(math.floor(s.Defense * 10 + 0.5) / 10)} ({pct(s.DamageReduction)} less damage)`,
		`Block reduction: {pct(s.Block)}`,
		`Move speed: +{pct(s.MoveSpeed)}`,
		`Roll cooldown: {string.format("%.2f s", s.RollCooldown)}`,
		`Attack speed: +{pct(s.AttackSpeed)}`,
		`Gold gain: x{string.format("%.2f", s.GoldMult)}`,
		`Crit chance: {pct(s.CritChance, 2)}`,
		`Crit damage: x{string.format("%.2f", s.CritDamage)}`,
		`Loot luck: +{pct(s.LootMult - 1)}`,
		`Element proc: +{pct(s.ElementProcBonus)}`,
		`Magic radius: +{pct(s.MagicRadius)}`,
		`Pet effectiveness: +{pct(s.PetEffectiveness - 1)}`,
		`Lifesteal and healing: +{pct(s.HealingBonus)}`,
	}
	if s.WeaponId then
		local weapon = Weapons.ById[s.WeaponId]
		table.insert(lines, `Weapon: {Rarities.get(s.WeaponRarity).Name} {weapon.Name}, {Format.number(s.WeaponDamage)} per hit`)
		local parts = {}
		for _, pair in ipairs(Stats.grades(weapon.Category)) do
			table.insert(parts, `{pair[1]} {pair[2]}`)
		end
		table.insert(lines, `Scaling: {table.concat(parts, " / ")}`)
	end
	table.insert(lines, `Each point costs more Gold than the last. Points above {Attributes.SoftCap} count half.`)
	return lines
end

-- refresh ---------------------------------------------------------------------------------------------
local function refresh()
	if not root then
		return
	end
	for id, points in pairs(target) do
		if have(id) >= points then
			target[id] = nil -- the server has it
		end
	end
	local data, stats = planned()
	local level = Attributes.level(data.Attributes)
	levelChip:Set(`{level}/{Attributes.MaxLevel}`)
	local gold = goldLeft()
	goldChip:Set(Format.number(math.max(0, gold)))
	local price = Attributes.pointCost(level)
	local equipped = (data.Weapons or {})[data.EquippedWeapon or ""]
	local weaponDef = equipped and Weapons.ById[equipped.id]
	local category = if weaponDef then weaponDef.Category else nil
	for _, attribute in ipairs(Attributes.List) do
		local card = cards[attribute.Id]
		local points = data.Attributes[attribute.Id] or 0
		card.points.Text = tostring(points)
		card.points.TextColor3 = if waiting(attribute.Id) > 0 then GREEN else Theme.Colors.Text
		card.gain.Text = Attributes.pointGain(attribute.Id, points + 1, data.Rebirths or 0, category)
		card.fill.Size = UDim2.fromScale(points / Attributes.MaxPoints, 1)
		local full = points >= Attributes.MaxPoints
		if full then
			card.plus:SetText("MAX")
			card.plus:SetEnabled(false)
		else
			card.plus:SetText(Format.number(price))
			card.plus:SetEnabled(true)
			card.plus:SetStyle(if gold >= price then "go" else "disabled")
		end
	end
	for _, spec in ipairs(CHIPS) do
		chips[spec[1]]:Set(spec[3](stats))
	end
	respec:SetText(tostring(Attributes.respecCost(Stats.highestZone(data))))
	respec:SetEnabled(level > 0)
end

-- tooltip (tap on an attribute's picture) ---------------------------------------------------------------
local function closeOverlay()
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
end

local function tooltip(attribute: any)
	closeOverlay()
	local holder = Instance.new("TextButton")
	holder.Name = "Tooltip"
	holder.Text = ""
	holder.AutoButtonColor = false
	holder.BackgroundColor3 = Theme.Colors.Black
	holder.BackgroundTransparency = 0.45
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 30
	holder.Activated:Connect(closeOverlay)
	holder.Parent = root
	overlay = holder -- remembered, so the X, a tap outside or closing the window removes it
	local top = Theme.TOUCH + 16
	local height = top + 14 + 34 * (#attribute.Effects + 1)
	local panel = Panel.new({ Size = UDim2.fromOffset(math.min(520, root.AbsoluteSize.X / Theme.getScale() - 20), height), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 31, Parent = holder })
	panel.Active = true
	Icons.create(attribute.Icon, panel, { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(14, 8), AnchorPoint = Vector2.zero, ZIndex = 32 })
	Theme.text({ Font = "Title", Text = attribute.Name, TextSize = 28, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(1, -(74 + Theme.TOUCH + 16), 0, 40), Position = UDim2.fromOffset(74, 14), ZIndex = 32, Parent = panel })
	Button.new({ Name = "Close", Style = "wood", Icon = "Close", Size = UDim2.fromOffset(Theme.TOUCH, Theme.TOUCH), Position = UDim2.new(1, -8, 0, 8), AnchorPoint = Vector2.new(1, 0), ZIndex = 33, OnClick = closeOverlay, Parent = panel })
	for i, effect in ipairs(attribute.Effects) do
		Theme.text({ Text = "- " .. effect, TextSize = 19, Wrapped = true, Align = "Left", Size = UDim2.new(1, -32, 0, 32), Position = UDim2.fromOffset(18, top + (i - 1) * 34), ZIndex = 32, Parent = panel })
	end
	local power = string.gsub(string.gsub(string.format("%.2f", Attributes.rebirthPower(State.get("Rebirths") or 0)), "0+$", ""), "%.$", "")
	Theme.text({ Text = `Per point. Points above {Attributes.SoftCap} count half. Rebirth power: every point x{power}`, TextSize = 17, Wrapped = true, Color = Theme.Colors.TextDim, Align = "Left", Size = UDim2.new(1, -32, 0, 32), Position = UDim2.fromOffset(18, top + #attribute.Effects * 34), ZIndex = 32, Parent = panel })
	Sfx.play("UIClick")
end

-- training (+ buys at once) -----------------------------------------------------------------------------
local send: () -> ()

local function schedule()
	if sendScheduled then
		return
	end
	sendScheduled = true
	task.delay(math.max(SEND_DELAY, SEND_GAP - (os.clock() - lastSent)), send)
end

send = function()
	sendScheduled = false
	if sending or count(queued) == 0 then
		return
	end
	sending = true
	lastSent = os.clock()
	local plan = {}
	for _, attribute in ipairs(Attributes.List) do
		local id = attribute.Id
		if queued[id] > 0 then
			plan[id] = queued[id]
			target[id] = have(id) + waiting(id)
		end
	end
	queued = Attributes.empty()
	local called, ok, result = pcall(Net.request, "TrainAttributes", plan)
	sending = false
	if not (called and ok) then
		target = {}
		Sfx.play("Denied")
		Notifier.push({ Kind = "error", Text = if called and typeof(result) == "string" then result else "Training failed" })
	end
	refresh()
	if count(queued) > 0 then
		schedule()
	end
end

local function buy(id: string): boolean
	if have(id) + waiting(id) >= Attributes.MaxPoints then
		return false
	end
	local price = Attributes.pointCost(Attributes.level(State.get("Attributes")) + waitingCount())
	if goldLeft() < price then
		Sfx.play("Denied")
		Notifier.push({ Kind = "error", Text = "Not enough Gold", Icon = "Gold" })
		return false
	end
	queued[id] += 1
	Sfx.play("LevelUp")
	refresh()
	schedule()
	return true
end

local function holdRepeat(button: any, fn: () -> boolean)
	local token = 0
	local lastPointer = -math.huge
	button:OnClick(function()
		if os.clock() - lastPointer > 0.6 then
			fn()
		end
	end)
	button.Instance.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			lastPointer = os.clock()
			token += 1
			local mine = token
			if not fn() then
				return
			end
			task.delay(REPEAT_DELAY, function()
				while token == mine and button.Instance.Parent do
					if not fn() then
						break
					end
					task.wait(REPEAT_EVERY)
				end
			end)
		end
	end)
	button.Instance.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			token += 1
		end
	end)
	button.Instance.MouseLeave:Connect(function()
		token += 1
	end)
end

local function doRespec()
	local data = snapshot()
	local cost = Attributes.respecCost(Stats.highestZone(data))
	Window.confirm({
		Title = "Start over?",
		Text = `All points back to 0 for {cost} Diamonds. You get back the {Format.number(Attributes.refundOf(data.Attributes))} Gold you spent.`,
		ConfirmText = "Yes",
		CancelText = "No",
		OnConfirm = function()
			if (State.get("Diamonds") or 0) < cost then
				Sfx.play("Denied")
				Notifier.push({ Kind = "error", Text = "Not enough Diamonds", Icon = "Diamond" })
				return
			end
			local called, ok, result = pcall(Net.request, "RespecAttributes")
			if called and ok then
				queued = Attributes.empty()
				target = {}
				Notifier.push({ Kind = "reward", Text = `Points reset: +{Format.number(result.Refund or 0)} Gold`, Icon = "Gold" })
			else
				Notifier.push({ Kind = "error", Text = if called and typeof(result) == "string" then result else "Respec failed" })
			end
			refresh()
		end,
	})
end

-- layout ----------------------------------------------------------------------------------------------
local function layout()
	if not root then
		return
	end
	local compact = Theme.isCompact()
	local gridLayout = grid:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
	local width = grid.AbsoluteSize.X / Theme.getScale() - 18
	local columns = if compact then 2 else 4
	gridLayout.CellSize = UDim2.fromOffset(math.floor((width - (columns - 1) * 10) / columns), if compact then 150 else 170)
end

local function makeCard(attribute: any, order: number)
	local card = Instance.new("Frame")
	card.Name = attribute.Id
	card.BackgroundColor3 = Theme.Colors.WoodInset
	card.LayoutOrder = order
	Theme.corner(card, 8)
	Theme.stroke(card, Theme.Colors.GoldDark, 2)
	card.Parent = grid
	-- the picture: tap for what it does
	local pic = Instance.new("TextButton")
	pic.Name = "Picture"
	pic.Text = ""
	pic.AutoButtonColor = false
	pic.BackgroundTransparency = 1
	pic.Size = UDim2.fromOffset(70, 70)
	pic.Position = UDim2.fromOffset(6, 6)
	pic.ZIndex = 3
	pic.Parent = card
	Icons.create(attribute.Icon, pic, { ZIndex = 3 })
	pic.Activated:Connect(function()
		tooltip(attribute)
	end)
	local points = Theme.text({ Name = "Points", Font = "Number", Text = "0", TextSize = 40, Size = UDim2.new(1, -86, 0, 44), Position = UDim2.fromOffset(80, 8), ZIndex = 3, Parent = card })
	local gain = Theme.text({ Name = "Gain", Text = "", TextSize = 15, Color = Theme.Colors.Good, Size = UDim2.new(1, -86, 0, 20), Position = UDim2.fromOffset(80, 52), ZIndex = 3, Parent = card })
	-- bar 0..40 with the soft-cap marker
	local track = Instance.new("Frame")
	track.Name = "Bar"
	track.BackgroundColor3 = Theme.Colors.WoodLine
	track.Size = UDim2.new(1, -16, 0, 12)
	track.Position = UDim2.new(0, 8, 0, 84)
	track.ZIndex = 3
	Theme.corner(track, 6)
	track.Parent = card
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Theme.Colors.GoldLight
	fill.BorderSizePixel = 0
	fill.ZIndex = 3
	Theme.corner(fill, 6)
	fill.Parent = track
	local marker = Instance.new("Frame")
	marker.Name = "SoftCap"
	marker.BackgroundColor3 = Theme.Colors.Text
	marker.BorderSizePixel = 0
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(Attributes.SoftCap / Attributes.MaxPoints, 0.5)
	marker.Size = UDim2.new(0, 3, 1, 8)
	marker.ZIndex = 4
	marker.Parent = track
	-- + (coin) price: buys one point now
	local plus = Button.new({ Name = "Plus", Text = "0", Icon = "Plus", Style = "go", TextSize = 32, Size = UDim2.new(1, -16, 0, Theme.TOUCH), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 3, Parent = card })
	plus.Label.Size = UDim2.new(1, -88, 0.78, 0) -- room for the coin on the right
	Icons.create("Gold", plus.Face, { Size = UDim2.new(0, 0, 0.7, 0), Position = UDim2.new(1, -8, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 4 })
	holdRepeat(plus, function()
		return buy(attribute.Id)
	end)
	cards[attribute.Id] = { points = points, gain = gain, fill = fill, plus = plus }
end

function AttributesPage.build(page: ScrollingFrame, ctx: any?)
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	windowFrame = if ctx then ctx.Frame else page
	page.ScrollingEnabled = false
	page.AutomaticCanvasSize = Enum.AutomaticSize.None
	page.CanvasSize = UDim2.new()
	page.ScrollBarThickness = 0
	root = Instance.new("Frame")
	root.Name = "Attributes"
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(1, -12, 1, -12)
	root.Position = UDim2.fromOffset(6, 6)
	root.Parent = page

	-- top: level, Gold, (i), respec
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, TOP)
	header.Parent = root
	local left = Instance.new("UIListLayout")
	left.FillDirection = Enum.FillDirection.Horizontal
	left.VerticalAlignment = Enum.VerticalAlignment.Center
	left.Padding = UDim.new(0, 10)
	left.SortOrder = Enum.SortOrder.LayoutOrder
	left.Parent = header
	levelChip = Chips.chip(header, "Up", "0/0", { Height = 44, LayoutOrder = 1 })
	goldChip = Chips.chip(header, "Gold", "0", { Height = 44, LayoutOrder = 2 })
	local actions = Instance.new("Frame")
	actions.BackgroundTransparency = 1
	actions.AnchorPoint = Vector2.new(1, 0)
	actions.Position = UDim2.new(1, 0, 0, 0)
	actions.Size = UDim2.new(0, 260, 1, 0)
	actions.Parent = root
	local right = Instance.new("UIListLayout")
	right.FillDirection = Enum.FillDirection.Horizontal
	right.HorizontalAlignment = Enum.HorizontalAlignment.Right
	right.VerticalAlignment = Enum.VerticalAlignment.Center
	right.Padding = UDim.new(0, 8)
	right.SortOrder = Enum.SortOrder.LayoutOrder
	right.Parent = actions
	actions.Size = UDim2.new(0, 260, 0, TOP)
	respec = Button.new({ Name = "Respec", Text = "7", Icon = "Reset", Style = "danger", TextSize = 30, Size = UDim2.fromOffset(130, Theme.TOUCH), LayoutOrder = 1, Parent = actions, OnClick = doRespec })
	respec.Label.Size = UDim2.new(1, -84, 0.78, 0)
	Icons.create("Diamond", respec.Face, { Size = UDim2.new(0, 0, 0.66, 0), Position = UDim2.new(1, -6, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 2 })
	Info.button({ Parent = actions, Frame = windowFrame, Title = "All stats", Lines = detailLines, Size = Theme.TOUCH, LayoutOrder = 2, PopupSize = Vector2.new(640, 520) })

	-- stats as icon + number
	local chipRow = Chips.row(root, { Name = "Stats", ZIndex = 3 })
	chipRow.Position = UDim2.fromOffset(0, TOP + 4)
	for i, spec in ipairs(CHIPS) do
		chips[spec[1]] = Chips.chip(chipRow, spec[2], "", { Height = 40, LayoutOrder = i })
	end

	-- one card per attribute
	grid = Instance.new("ScrollingFrame")
	grid.Name = "Cards"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = Theme.Colors.GoldLight
	local top = TOP + 56
	grid.Position = UDim2.fromOffset(0, top)
	grid.Size = UDim2.new(1, 0, 1, -top)
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.fromOffset(10, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = grid
	grid.Parent = root
	for index, attribute in ipairs(Attributes.List) do
		makeCard(attribute, index)
	end
	-- the chip row wraps on small screens: the cards start under it
	chipRow:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local h = chipRow.AbsoluteSize.Y / Theme.getScale()
		grid.Position = UDim2.fromOffset(0, TOP + h + 12)
		grid.Size = UDim2.new(1, 0, 1, -(TOP + h + 12))
	end)
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	layout()
	Theme.Changed:Connect(layout)
	for _, key in ipairs({ "Gold", "Diamonds", "Attributes", "Rebirths", "RebirthUpgrades", "Weapons", "EquippedWeapon", "Pets", "EquippedPets", "Armor", "EquippedArmor", "Zones" }) do
		State.changed(key, refresh)
	end
	Window.Closed:Connect(function(id)
		if id == "Stats" then
			closeOverlay()
		end
	end)
	refresh()
end

return AttributesPage
