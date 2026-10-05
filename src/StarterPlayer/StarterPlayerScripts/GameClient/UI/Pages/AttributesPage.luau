--!strict
-- Stats button -> Attributes window (docs/menu_systems_brief.txt A5), inspired by the Elden Ring status screen.
-- Left: the 8 attributes (points, bar to 40 with the soft-cap marker at 20, [-] [+] that change PENDING points,
-- hold to repeat, tap the name for its effects). Right: every derived stat "before -> after" (green = better)
-- and the equipped weapon's damage and scaling grades. Bottom: Confirm (cost), Reset pending, Respec.
-- The server decides everything (Net "TrainAttributes" / "RespecAttributes"); the numbers shown come from the
-- shared Util/Stats.compute, so they match the server.
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
local Icons = require(Kit.Icons)
local Panel = require(Kit.Panel)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local AttributesPage = {}

local ROW_HEIGHT = 64
local HEADER_HEIGHT = 46
local GREEN = Color3.fromRGB(110, 235, 120)
local RED = Color3.fromRGB(255, 110, 100)
local REPEAT_DELAY = 0.4
local REPEAT_EVERY = 0.08
local DATA_KEYS = { "Attributes", "Rebirths", "RebirthUpgrades", "Weapons", "EquippedWeapon", "Pets", "EquippedPets", "Armor", "EquippedArmor", "Boosts", "Zones" }

type Row = { points: TextLabel, fill: Frame, pendingFill: Frame, cost: TextLabel, minus: any, plus: any }
type Line = { value: TextLabel }

local pending: { [string]: number } = Attributes.empty()
local rows: { [string]: Row } = {}
local lines: { [string]: Line } = {}
local weaponTitle: TextLabel
local weaponLine: TextLabel
local gradesLine: TextLabel
local levelLabel: TextLabel
local goldLabel: TextLabel
local confirm: any
local reset: any
local respec: any
local busy = false
local root: Frame
local left: ScrollingFrame
local right: ScrollingFrame
local statusToggle: any
local showStatus = false -- phones: one column at a time
local overlay: Frame? = nil

-- data ------------------------------------------------------------------------------------------------
local function snapshot(): { [string]: any }
	local data = {}
	for _, key in ipairs(DATA_KEYS) do
		data[key] = State.get(key)
	end
	return data
end

local function pendingCount(): number
	local n = 0
	for _, v in pairs(pending) do
		n += v
	end
	return n
end

local function current(id: string): number
	return ((State.get("Attributes") or {})[id] or 0)
end

local function pct(x: number, decimals: number?): string
	local text = string.format(`%.{decimals or 1}f`, x * 100)
	text = string.gsub(text, "%.0+$", "")
	return text .. "%"
end

-- { key, label, format(stats) -> string, value(stats) -> number, higherIsBetter }
local STATUS = {
	{ "MaxHP", "Max HP", function(s) return Format.number(math.floor(s.MaxHP + 0.5)) end, function(s) return s.MaxHP end, true },
	{ "Regen", "HP regen (out of combat)", function(s) return Format.number(math.floor(s.RegenPerSecond * 10 + 0.5) / 10) .. "/s" end, function(s) return s.RegenPerSecond end, true },
	{ "Defense", "Defense", function(s) return `{Format.number(math.floor(s.Defense * 10 + 0.5) / 10)} ({pct(s.DamageReduction)} less damage)` end, function(s) return s.Defense end, true },
	{ "Block", "Block reduction", function(s) return pct(s.Block) end, function(s) return s.Block end, true },
	{ "MoveSpeed", "Move speed", function(s) return "+" .. pct(s.MoveSpeed) end, function(s) return s.MoveSpeed end, true },
	{ "Roll", "Roll cooldown", function(s) return string.format("%.2f s", s.RollCooldown) end, function(s) return -s.RollCooldown end, true },
	{ "AttackSpeed", "Attack speed", function(s) return "+" .. pct(s.AttackSpeed) end, function(s) return s.AttackSpeed end, true },
	{ "Gold", "Gold gain", function(s) return "x" .. string.format("%.2f", s.GoldMult) end, function(s) return s.GoldMult end, true },
	{ "Crit", "Crit chance", function(s) return pct(s.CritChance, 2) end, function(s) return s.CritChance end, true },
	{ "CritDamage", "Crit damage", function(s) return "x" .. string.format("%.2f", s.CritDamage) end, function(s) return s.CritDamage end, true },
	{ "Loot", "Loot luck", function(s) return "+" .. pct(s.LootMult - 1) end, function(s) return s.LootMult end, true },
	{ "Proc", "Element proc", function(s) return "+" .. pct(s.ElementProcBonus) end, function(s) return s.ElementProcBonus end, true },
	{ "Radius", "Magic radius", function(s) return "+" .. pct(s.MagicRadius) end, function(s) return s.MagicRadius end, true },
	{ "PetEffect", "Pet effectiveness", function(s) return "+" .. pct(s.PetEffectiveness - 1) end, function(s) return s.PetEffectiveness end, true },
	{ "Healing", "Lifesteal & healing", function(s) return "+" .. pct(s.HealingBonus) end, function(s) return s.HealingBonus end, true },
}

-- refresh ---------------------------------------------------------------------------------------------
local function refresh()
	if not root then
		return
	end
	local data = snapshot()
	local zone = Stats.highestZone(data)
	local level = Attributes.level(data.Attributes)
	local count = pendingCount()
	local context = { zoneId = Players.LocalPlayer:GetAttribute("CurrentZone"), now = os.time() }
	local before = Stats.compute(data, context)
	local planned = table.clone(data.Attributes or Attributes.empty())
	for id, v in pairs(pending) do
		planned[id] = (planned[id] or 0) + v
	end
	local afterData = table.clone(data)
	afterData.Attributes = planned
	local after = Stats.compute(afterData, context)

	levelLabel.Text = if count > 0 then `Attribute Level: {level} -> {level + count} / {Attributes.MaxLevel}` else `Attribute Level: {level} / {Attributes.MaxLevel}`
	local gold = State.get("Gold") or 0
	goldLabel.Text = Format.number(gold)
	local nextCost = Attributes.pointCost(level + count, zone)
	for _, attribute in ipairs(Attributes.List) do
		local row = rows[attribute.Id]
		local have, add = current(attribute.Id), pending[attribute.Id]
		row.points.Text = if add > 0 then `{have} -> {have + add}` else tostring(have)
		row.points.TextColor3 = if add > 0 then GREEN else Theme.Colors.Text
		row.fill.Size = UDim2.fromScale(have / Attributes.MaxPoints, 1)
		row.pendingFill.Position = UDim2.fromScale(have / Attributes.MaxPoints, 0)
		row.pendingFill.Size = UDim2.fromScale(add / Attributes.MaxPoints, 1)
		local full = have + add >= Attributes.MaxPoints
		row.cost.Text = if full then "MAX" else `Next: {Format.number(nextCost)}`
		row.plus:SetEnabled(not full and not busy)
		row.minus:SetEnabled(add > 0 and not busy)
	end
	for _, spec in ipairs(STATUS) do
		local line = lines[spec[1]]
		local a, b = spec[3](before), spec[3](after)
		local va, vb = spec[4](before), spec[4](after)
		if a == b then
			line.value.Text = a
			line.value.TextColor3 = Theme.Colors.Text
		else
			line.value.Text = `{a}  ->  {b}`
			line.value.TextColor3 = if (vb > va) == spec[5] then GREEN else RED
		end
	end
	-- equipped weapon
	if before.WeaponId then
		local weapon = Weapons.ById[before.WeaponId]
		weaponTitle.Text = `Equipped weapon: {Rarities.get(before.WeaponRarity).Name} {weapon.Name}`
		local a, b = Format.number(before.WeaponDamage), Format.number(after.WeaponDamage)
		weaponLine.Text = if a == b then `Damage per hit: {a}` else `Damage per hit: {a}  ->  {b}`
		weaponLine.TextColor3 = if after.WeaponDamage > before.WeaponDamage + 1e-9 then GREEN else Theme.Colors.Text
		local parts = {}
		for _, pair in ipairs(Stats.grades(weapon.Category)) do
			table.insert(parts, `{pair[1]} {pair[2]}`)
		end
		gradesLine.Text = `Scaling: {table.concat(parts, "  /  ")}`
	else
		weaponTitle.Text = "Equipped weapon: none"
		weaponLine.Text = "Equip a weapon to see its damage here"
		weaponLine.TextColor3 = Theme.Colors.TextDim
		gradesLine.Text = ""
	end
	local cost = Attributes.costOf(level, count, zone)
	confirm:SetText(if count > 0 then `Confirm ({Format.number(cost)} Gold)` else "Confirm")
	confirm:SetEnabled(count > 0 and not busy)
	if count > 0 and not busy then
		confirm:SetStyle(if gold >= cost then "go" else "disabled") -- still pressable: it explains why
	end
	reset:SetEnabled(count > 0 and not busy)
	respec:SetText(`Respec ({Attributes.respecCost(zone)} Diamonds)`)
	respec:SetEnabled(level > 0 and not busy)
end

-- tooltip ---------------------------------------------------------------------------------------------
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
	local top = Theme.TOUCH + 16 -- the title row holds the close (X) button
	local height = top + 14 + 34 * #attribute.Effects
	local panel = Panel.new({ Size = UDim2.fromOffset(math.min(520, root.AbsoluteSize.X / Theme.getScale() - 20), height), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 31, Parent = holder })
	panel.Active = true -- a tap on the panel itself keeps it open; the X or a tap outside closes it
	Icons.create(attribute.Icon, panel, { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(14, 12), AnchorPoint = Vector2.zero, ZIndex = 32 })
	Theme.text({ Font = "Title", Text = attribute.Name, TextSize = 28, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(1, -(66 + Theme.TOUCH + 16), 0, 40), Position = UDim2.fromOffset(66, 14), ZIndex = 32, Parent = panel })
	Button.new({ Name = "Close", Style = "wood", Icon = "Close", Size = UDim2.fromOffset(Theme.TOUCH, Theme.TOUCH), Position = UDim2.new(1, -8, 0, 8), AnchorPoint = Vector2.new(1, 0), ZIndex = 33, OnClick = closeOverlay, Parent = panel })
	for i, effect in ipairs(attribute.Effects) do
		Theme.text({ Text = "- " .. effect, TextSize = 19, Wrapped = true, Align = "Left", Size = UDim2.new(1, -32, 0, 32), Position = UDim2.fromOffset(18, top + (i - 1) * 34), ZIndex = 32, Parent = panel })
	end
	Sfx.play("UIClick")
end

-- actions ---------------------------------------------------------------------------------------------
local function change(id: string, delta: number)
	if busy then
		return
	end
	local have = current(id)
	local nextValue = math.clamp(pending[id] + delta, 0, Attributes.MaxPoints - have)
	if nextValue ~= pending[id] then
		pending[id] = nextValue
		Sfx.play("UIClick")
		refresh()
	end
end

local function holdRepeat(button: any, fn: () -> ())
	local token = 0
	local lastPointer = -math.huge
	-- keyboard / gamepad: the button's normal click (a mouse or touch press is already handled below)
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
			fn()
			task.delay(REPEAT_DELAY, function()
				while token == mine and button.Instance.Parent do
					fn()
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

local function doConfirm()
	local count = pendingCount()
	if busy or count == 0 then
		return
	end
	local data = snapshot()
	local cost = Attributes.costOf(Attributes.level(data.Attributes), count, Stats.highestZone(data))
	if (State.get("Gold") or 0) < cost then
		Sfx.play("Denied")
		Notifier.push({ Kind = "error", Text = "Not enough Gold" })
		return
	end
	busy = true
	refresh()
	local plan = {}
	for id, v in pairs(pending) do
		if v > 0 then
			plan[id] = v
		end
	end
	local called, ok, result = pcall(Net.request, "TrainAttributes", plan)
	busy = false
	if called and ok then
		pending = Attributes.empty()
		Sfx.play("LevelUp")
		Notifier.push({ Kind = "reward", Text = `Trained {count} point{if count == 1 then "" else "s"} for {Format.number(result.Cost)} Gold`, Icon = "Stats" })
	else
		Sfx.play("Denied")
		Notifier.push({ Kind = "error", Text = if called and typeof(result) == "string" then result else "Training failed" })
	end
	refresh()
end

local function doRespec()
	local zone = Stats.highestZone(snapshot())
	local cost = Attributes.respecCost(zone)
	Window.confirm({
		Title = "Respec",
		Text = `Reset every attribute to 0 for {cost} Diamonds? The Gold you spent is NOT refunded.`,
		ConfirmText = "Respec",
		CancelText = "Cancel",
		OnConfirm = function()
			if (State.get("Diamonds") or 0) < cost then
				Sfx.play("Denied")
				Notifier.push({ Kind = "error", Text = "Not enough Diamonds" })
				return
			end
			local called, ok, result = pcall(Net.request, "RespecAttributes")
			if called and ok then
				pending = Attributes.empty()
				Notifier.push({ Kind = "info", Text = `Attributes reset for {result.Cost} Diamonds`, Icon = "Stats" })
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
	local header = root:FindFirstChild("Header") :: Frame
	local bottom = root:FindFirstChild("Bottom") :: Frame
	if compact then
		-- phones: the buttons share the header row; one column at a time (Status button swaps)
		header.Size = UDim2.new(1, 0, 0, Theme.TOUCH)
		bottom.Position = UDim2.new(1, 0, 0, 0)
		bottom.AnchorPoint = Vector2.new(1, 0)
		bottom.Size = UDim2.new(0.66, 0, 0, Theme.TOUCH)
		levelLabel.Size = UDim2.new(0.34, -8, 0.5, 0)
		levelLabel.Position = UDim2.fromOffset(6, 0)
		goldLabel.Parent.Position = UDim2.new(0, 6, 0.5, 2)
		goldLabel.Parent.AnchorPoint = Vector2.zero
		goldLabel.Parent.Size = UDim2.new(0.3, -8, 0.5, -4)
		local top = Theme.TOUCH + 8
		for _, column in ipairs({ left, right }) do
			column.Position = UDim2.fromOffset(0, top)
			column.Size = UDim2.new(1, 0, 1, -top)
		end
		left.Visible = not showStatus
		right.Visible = showStatus
		statusToggle.Instance.Visible = true
		statusToggle:SetText(if showStatus then "Points" else "Status")
		statusToggle.Instance.Size = UDim2.new(0.2, -6, 1, 0)
		respec.Instance.Size = UDim2.new(0.28, -6, 1, 0)
		reset.Instance.Size = UDim2.new(0.2, -6, 1, 0)
		confirm.Instance.Size = UDim2.new(0.32, -6, 1, 0)
		respec:SetText(respec.Label.Text)
	else
		header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
		bottom.Position = UDim2.new(0, 0, 1, 0)
		bottom.AnchorPoint = Vector2.new(0, 1)
		bottom.Size = UDim2.new(1, 0, 0, Theme.TOUCH)
		levelLabel.Size = UDim2.new(0.6, 0, 1, -8)
		levelLabel.Position = UDim2.fromOffset(10, 4)
		goldLabel.Parent.Position = UDim2.new(1, -8, 0.5, 0)
		goldLabel.Parent.AnchorPoint = Vector2.new(1, 0.5)
		goldLabel.Parent.Size = UDim2.fromOffset(220, 36)
		local top = HEADER_HEIGHT + 8
		local below = Theme.TOUCH + 10
		left.Position = UDim2.fromOffset(0, top)
		left.Size = UDim2.new(0.56, -6, 1, -(top + below))
		right.Position = UDim2.new(0.56, 6, 0, top)
		right.Size = UDim2.new(0.44, -6, 1, -(top + below))
		left.Visible = true
		right.Visible = true
		statusToggle.Instance.Visible = false
		respec.Instance.Size = UDim2.new(0.3, -6, 1, 0)
		reset.Instance.Size = UDim2.new(0.22, -6, 1, 0)
		confirm.Instance.Size = UDim2.new(0.3, -6, 1, 0)
	end
end

local function column(name: string): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.BackgroundColor3 = Theme.Colors.WoodTop
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.ScrollBarThickness = 6
	frame.ScrollBarImageColor3 = Theme.Colors.GoldLight
	Theme.corner(frame, 6)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = frame
	frame.Parent = root
	return frame
end

local function makeRow(attribute: any, order: number)
	local row = Instance.new("Frame")
	row.Name = attribute.Id
	row.BackgroundColor3 = Theme.Colors.WoodInset
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.LayoutOrder = order
	Theme.corner(row, 6)
	Theme.stroke(row, Theme.Colors.WoodLine, 1.5)
	row.Parent = left
	-- name: tap for the effects
	local name = Instance.new("TextButton")
	name.Name = "Name"
	name.Text = ""
	name.AutoButtonColor = false
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(0.34, 0, 1, 0)
	name.Parent = row
	Icons.create(attribute.Icon, name, { Size = UDim2.new(0, 0, 0.76, 0), Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	Theme.text({ Font = "Title", Text = attribute.Name, TextSize = 24, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(1, -60, 0.55, 0), Position = UDim2.fromOffset(56, 4), Parent = name })
	Theme.text({ Text = attribute.Short .. "  (i)", TextSize = 15, Color = Theme.Colors.TextDim, Align = "Left", Size = UDim2.new(1, -60, 0.32, 0), Position = UDim2.new(0, 56, 0.62, 0), Parent = name })
	name.Activated:Connect(function()
		tooltip(attribute)
	end)
	local points = Theme.text({ Name = "Points", Font = "Number", Text = "0", TextSize = 26, Size = UDim2.new(0.17, 0, 0.7, 0), Position = UDim2.new(0.34, 0, 0.15, 0), Parent = row })
	-- bar 0..40 with the soft-cap marker
	local track = Instance.new("Frame")
	track.Name = "Bar"
	track.BackgroundColor3 = Theme.Colors.WoodLine
	track.Size = UDim2.new(0.49, -(2 * Theme.TOUCH + 22), 0, 14)
	track.Position = UDim2.new(0.51, 4, 0.5, -10)
	track.AnchorPoint = Vector2.new(0, 0.5)
	Theme.corner(track, 7)
	track.Parent = row
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Theme.Colors.GoldLight
	fill.BorderSizePixel = 0
	Theme.corner(fill, 7)
	fill.Parent = track
	local pendingFill = Instance.new("Frame")
	pendingFill.Name = "Pending"
	pendingFill.BackgroundColor3 = GREEN
	pendingFill.BorderSizePixel = 0
	pendingFill.Parent = track
	local marker = Instance.new("Frame")
	marker.Name = "SoftCap"
	marker.BackgroundColor3 = Theme.Colors.Text
	marker.BorderSizePixel = 0
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(Attributes.SoftCap / Attributes.MaxPoints, 0.5)
	marker.Size = UDim2.new(0, 3, 1, 8)
	marker.ZIndex = 2
	marker.Parent = track
	local cost = Theme.text({ Name = "Cost", Text = "", TextSize = 15, Color = Theme.Colors.TextDim, Align = "Left", Size = UDim2.new(0.49, -(2 * Theme.TOUCH + 22), 0, 18), Position = UDim2.new(0.51, 4, 0.5, 6), Parent = row })
	local minus = Button.new({ Name = "Minus", Text = "-", Style = "secondary", TextSize = 34, Size = UDim2.fromOffset(Theme.TOUCH, Theme.TOUCH), Position = UDim2.new(1, -(Theme.TOUCH + 10), 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = row })
	local plus = Button.new({ Name = "Plus", Text = "+", Style = "primary", TextSize = 34, Size = UDim2.fromOffset(Theme.TOUCH, Theme.TOUCH), Position = UDim2.new(1, -4, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = row })
	holdRepeat(minus, function()
		change(attribute.Id, -1)
	end)
	holdRepeat(plus, function()
		change(attribute.Id, 1)
	end)
	rows[attribute.Id] = { points = points, fill = fill, pendingFill = pendingFill, cost = cost, minus = minus, plus = plus }
end

local function statusLine(key: string, label: string, order: number)
	local line = Instance.new("Frame")
	line.Name = key
	line.BackgroundTransparency = 1
	line.Size = UDim2.new(1, 0, 0, 26)
	line.LayoutOrder = order
	line.Parent = right
	Theme.text({ Text = label, TextSize = 18, Color = Theme.Colors.TextDim, Align = "Left", Size = UDim2.new(0.46, 0, 1, 0), Parent = line })
	local value = Theme.text({ Font = "Number", Text = "", TextSize = 18, Align = "Right", Size = UDim2.new(0.54, 0, 1, 0), Position = UDim2.fromScale(0.46, 0), Parent = line })
	lines[key] = { value = value }
end

function AttributesPage.build(page: ScrollingFrame)
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") then
			child:Destroy()
		end
	end
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

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = Theme.Colors.WoodTop
	Theme.corner(header, 6)
	header.Parent = root
	levelLabel = Theme.text({ Name = "Level", Font = "Title", Text = "", TextSize = 28, Color = Theme.Colors.Gold, Align = "Left", Parent = header })
	local goldBox = Instance.new("Frame")
	goldBox.Name = "Gold"
	goldBox.BackgroundColor3 = Theme.Colors.WoodInset
	Theme.corner(goldBox, 18)
	Theme.stroke(goldBox, Theme.Colors.GoldDark, 2)
	goldBox.Parent = header
	Icons.create("Gold", goldBox, { Size = UDim2.new(0, 0, 1.1, 0), Position = UDim2.new(0, -6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 2 })
	goldLabel = Theme.text({ Font = "Number", Text = "", TextSize = 22, Align = "Right", Size = UDim2.new(1, -44, 1, -6), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = goldBox })

	left = column("Points")
	right = column("Status")
	for index, attribute in ipairs(Attributes.List) do
		makeRow(attribute, index)
	end
	Theme.text({ Font = "Title", Text = "Status", TextSize = 26, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 0, Parent = right })
	for index, spec in ipairs(STATUS) do
		statusLine(spec[1], spec[2], index)
	end
	local divider = Instance.new("Frame")
	divider.BackgroundColor3 = Theme.Colors.GoldDark
	divider.BorderSizePixel = 0
	divider.Size = UDim2.new(1, 0, 0, 2)
	divider.LayoutOrder = 50
	divider.Parent = right
	weaponTitle = Theme.text({ Font = "Button", Text = "", TextSize = 19, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 51, Parent = right })
	weaponLine = Theme.text({ Font = "Number", Text = "", TextSize = 18, Align = "Left", Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 52, Parent = right })
	gradesLine = Theme.text({ Text = "", TextSize = 17, Color = Theme.Colors.TextDim, Align = "Left", Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 53, Parent = right })

	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.BackgroundTransparency = 1
	bottom.Parent = root
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = bottom
	statusToggle = Button.new({ Name = "StatusToggle", Text = "Status", Style = "wood", TextSize = 20, Size = UDim2.new(0.22, -6, 1, 0), LayoutOrder = 0, Parent = bottom, OnClick = function()
		showStatus = not showStatus
		layout()
	end })
	respec = Button.new({ Name = "Respec", Text = "Respec", Icon = "Diamond", Style = "danger", TextSize = 20, Size = UDim2.new(0.3, -6, 1, 0), LayoutOrder = 1, Parent = bottom, OnClick = doRespec })
	reset = Button.new({ Name = "Reset", Text = "Reset pending", Style = "secondary", TextSize = 20, Size = UDim2.new(0.22, -6, 1, 0), LayoutOrder = 2, Parent = bottom, OnClick = function()
		pending = Attributes.empty()
		Sfx.play("UIClick")
		refresh()
	end })
	confirm = Button.new({ Name = "Confirm", Text = "Confirm", Icon = "Gold", Style = "go", TextSize = 20, Size = UDim2.new(0.3, -6, 1, 0), LayoutOrder = 3, Parent = bottom, OnClick = doConfirm })

	layout()
	Theme.Changed:Connect(layout)
	for _, key in ipairs({ "Gold", "Diamonds", "Attributes", "Rebirths", "RebirthUpgrades", "Weapons", "EquippedWeapon", "Pets", "EquippedPets", "Armor", "EquippedArmor", "Zones" }) do
		State.changed(key, refresh)
	end
	Window.Closed:Connect(function(id)
		if id == "Stats" then
			closeOverlay()
			pending = Attributes.empty() -- pending points are only a plan: closing drops them
			refresh()
		end
	end)
	refresh()
end

return AttributesPage
