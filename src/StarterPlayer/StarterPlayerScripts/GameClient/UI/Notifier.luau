--!strict
-- Notifications (docs/ui_hud_brief.txt section 5): toasts stacked at top-center below the zone
-- banner, at most MaxVisible at once (extras wait in a queue), Seconds each. Identical messages
-- merge ("Obtained Rare Wolf Pup Egg x2"). Epic+ loot has a glow and a reveal sound; errors shake.
--   Notifier.push({ Kind = "loot"|"reward"|"error"|"info"|"death", Text, Icon?, Rarity? })
-- The server sends the same table on Net "Notify".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.GameSystem.Net)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local Screens = require(script.Parent.Kit.Screens)
local Theme = require(script.Parent.Kit.Theme)
local Toast = require(script.Parent.Kit.Toast)

local Notifier = { Priority = 3 }

local TOP = { Normal = 124, Compact = 112 } -- below the zone banner and the Zone Boost badge
local BOTTOM_RESERVED = 140 -- the weapon and pet slots (with the weapon name) at the bottom
local DISPLAY_ORDER = 30 -- above the windows (20), so "Not enough Gold" shows over the Shop
local SHAKE = 8

type Entry = { key: string, data: { [string]: any }, count: number, token: number, card: Frame?, label: TextLabel?, pop: UIScale? }

local visible: { Entry } = {}
local queue: { Entry } = {}
local holder: Frame? = nil

local function getHolder(): Frame
	if not holder then
		holder = Screens.get("Toasts", DISPLAY_ORDER)
	end
	return holder :: Frame
end

-- As many toasts as fit between the banner and the slots, at most MaxVisible.
local function maxVisible(): number
	local config = UIConfig.Toast
	local top = if Theme.isCompact() then TOP.Compact else TOP.Normal
	local fits = math.floor((Theme.size().Y - top - BOTTOM_RESERVED + config.Gap) / (config.Height + config.Gap))
	return math.clamp(fits, 1, config.MaxVisible)
end

local function targetY(index: number): number
	local config = UIConfig.Toast
	return (if Theme.isCompact() then TOP.Compact else TOP.Normal) + (index - 1) * (config.Height + config.Gap)
end

local function textOf(entry: Entry): string
	return if entry.count > 1 then `{entry.data.Text} x{entry.count}` else entry.data.Text
end

local function relayout()
	for index, entry in ipairs(visible) do
		if entry.card then
			TweenService:Create(entry.card, TweenInfo.new(UIConfig.Toast.SlideSeconds, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, 0, 0, targetY(index)) }):Play()
		end
	end
end

local pump: () -> ()

local function hide(entry: Entry)
	local index = table.find(visible, entry)
	if not index then
		return
	end
	table.remove(visible, index)
	local card, pop = entry.card, entry.pop
	if card and pop then
		local info = TweenInfo.new(UIConfig.Toast.SlideSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(pop, info, { Scale = 0.6 }):Play()
		local tween = TweenService:Create(card, info, { Position = card.Position + UDim2.fromOffset(0, -24) })
		tween.Completed:Connect(function()
			card:Destroy()
		end)
		tween:Play()
	end
	relayout()
	pump()
end

local function schedule(entry: Entry)
	entry.token += 1
	local token = entry.token
	task.delay(UIConfig.Toast.Seconds, function()
		if entry.token == token then
			hide(entry)
		end
	end)
end

local function playSound(data: { [string]: any })
	local kind = data.Kind
	if kind == "error" then
		Sfx.play("Denied")
	elseif kind == "death" then
		Sfx.play("Hurt")
	elseif kind == "reward" then
		Sfx.play("Purchase")
	elseif kind == "loot" and data.Rarity then
		local tier = Rarities.get(data.Rarity).Tier
		if tier >= Rarities.LEGENDARY_SOUND_FROM then
			Sfx.play("RarityLegendary")
		elseif tier >= Rarities.SPECIAL_SOUND_FROM then
			Sfx.play("RarityReveal")
		end
	end
end

local function show(entry: Entry)
	local width = if Theme.isCompact() then UIConfig.Toast.CompactWidth else UIConfig.Toast.Width
	local card, label = Toast.create(entry.data, width)
	local pop = Instance.new("UIScale")
	pop.Scale = 0.85
	pop.Parent = card
	label.Text = textOf(entry)
	table.insert(visible, entry)
	local y = targetY(#visible)
	card.Position = UDim2.new(0.5, 0, 0, y - 18)
	card.Parent = getHolder()
	entry.card, entry.label, entry.pop = card, label, pop
	local info = TweenInfo.new(UIConfig.Toast.SlideSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(pop, info, { Scale = 1 }):Play()
	TweenService:Create(card, info, { Position = UDim2.new(0.5, 0, 0, y) }):Play()
	if entry.data.Kind == "error" then
		task.delay(UIConfig.Toast.SlideSeconds, function()
			if card.Parent then
				local base = card.Position
				local step = TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true)
				TweenService:Create(card, step, { Position = base + UDim2.fromOffset(SHAKE, 0) }):Play()
			end
		end)
	end
	playSound(entry.data)
	schedule(entry)
end

pump = function()
	while #visible < maxVisible() and #queue > 0 do
		show(table.remove(queue, 1) :: Entry)
	end
end

function Notifier.push(data: { [string]: any })
	if typeof(data) ~= "table" or typeof(data.Text) ~= "string" then
		return
	end
	local key = `{data.Kind or "info"}|{data.Text}|{tostring(data.Rarity)}`
	for _, entry in ipairs(visible) do
		if entry.key == key then
			entry.count += 1
			if entry.label then
				entry.label.Text = textOf(entry)
			end
			if entry.pop then
				entry.pop.Scale = 1.08
				TweenService:Create(entry.pop, TweenInfo.new(0.15), { Scale = 1 }):Play()
			end
			playSound(entry.data)
			schedule(entry)
			return
		end
	end
	for _, entry in ipairs(queue) do
		if entry.key == key then
			entry.count += 1
			return
		end
	end
	local entry: Entry = { key = key, data = data, count = 1, token = 0 }
	if #visible < maxVisible() then
		show(entry)
	else
		table.insert(queue, entry)
	end
end

function Notifier:Start()
	getHolder()
	Net.on("Notify", Notifier.push)
	Theme.Changed:Connect(relayout)
end

return Notifier
