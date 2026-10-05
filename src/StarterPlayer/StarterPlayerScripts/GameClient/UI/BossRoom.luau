--!strict
-- HUD of the boss rooms (docs/enemies_npcs_pets_brief.txt Part C): phase banners (lobby countdown, mini-bosses,
-- boss name with its roar, victory / defeat), the HP bars of the room's mini-bosses and boss at the top of the
-- screen, and the rewards screen (items received, countdown, "Leave now").
-- Server events: Net "BossRoom" { Phase, Seconds?, Name?, ZoneId } and Net "BossRewards" { Boss, Items, Seconds }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Enemies = require(ReplicatedStorage.GameSystem.Config.Enemies)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Notifier = require(script.Parent.Notifier)
local Kit = script.Parent.Kit
local Bar = require(Kit.Bar)
local Button = require(Kit.Button)
local Icons = require(Kit.Icons)
local Panel = require(Kit.Panel)
local Screens = require(Kit.Screens)
local Theme = require(Kit.Theme)

local BossRoom = { Priority = 13 }

local player = Players.LocalPlayer
local STACK_BOTTOM = "TopCenterBottom" -- the toasts stack under this (ZoneBanner)
local BAR_WIDTH = { Normal = 520, Compact = 360 }
local BAR_HEIGHT = { Boss = 54, Mini = 40 }
local TIER_COLORS = { mini = Color3.fromRGB(255, 160, 40), boss = Color3.fromRGB(255, 70, 60) }

type BarEntry = { model: Model, frame: Frame, bar: any, label: TextLabel }

local root: Frame
local barColumn: Frame
local bars: { [Model]: BarEntry } = {}
local banner: TextLabel
local bannerSub: TextLabel
local bannerToken = 0
local rewards: Frame?
local savedStack: number? = nil
local countdownToken = 0

local function showBanner(title: string, subtitle: string?, seconds: number?, color: Color3?)
	bannerToken += 1
	local token = bannerToken
	banner.Text = title
	banner.TextColor3 = color or Theme.Colors.Gold
	bannerSub.Text = subtitle or ""
	banner.Visible = true
	bannerSub.Visible = subtitle ~= nil
	banner.TextTransparency = 1
	TweenService:Create(banner, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	task.delay(seconds or 2.5, function()
		if token == bannerToken then
			banner.Visible = false
			bannerSub.Visible = false
		end
	end)
end

local function countdown(prefix: string, seconds: number)
	countdownToken += 1
	local token = countdownToken
	task.spawn(function()
		for left = math.floor(seconds), 1, -1 do
			if token ~= countdownToken then
				return
			end
			showBanner(tostring(left), prefix, 1.1)
			Sfx.play("UIClick")
			task.wait(1)
		end
	end)
end

local function layoutBars()
	local count = 0
	for _ in pairs(bars) do
		count += 1
	end
	local hud = Screens.hud()
	if count > 0 then
		if savedStack == nil then
			local value = hud:GetAttribute(STACK_BOTTOM)
			savedStack = if typeof(value) == "number" then value else 8
		end
		local top = (savedStack :: number) + 6
		barColumn.Position = UDim2.new(0.5, 0, 0, top)
		barColumn.Visible = true
		task.defer(function()
			hud:SetAttribute(STACK_BOTTOM, top + barColumn.AbsoluteSize.Y / math.max(0.01, Theme.getScale()))
		end)
	else
		barColumn.Visible = false
		if savedStack ~= nil then
			hud:SetAttribute(STACK_BOTTOM, savedStack)
			savedStack = nil
		end
	end
end

local function addBar(model: Model)
	local def = Enemies.ById[model:GetAttribute("EnemyId") or ""]
	if not def or bars[model] then
		return
	end
	local isBoss = def.Tier == "boss"
	local width = if Theme.isCompact() then BAR_WIDTH.Compact else BAR_WIDTH.Normal
	local height = if isBoss then BAR_HEIGHT.Boss else BAR_HEIGHT.Mini
	local frame = Instance.new("Frame")
	frame.Name = def.Id
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(if isBoss then width else width * 0.8, height)
	frame.LayoutOrder = if isBoss then 0 else 1
	local label = Theme.text({ Font = "Title", Text = def.Name, TextSize = if isBoss then 24 else 19, Color = TIER_COLORS[def.Tier] or Theme.Colors.Gold, Size = UDim2.new(1, 0, 0, if isBoss then 24 else 18), Parent = frame })
	local bar = Bar.new({ Size = UDim2.new(1, 0, 0, height - (if isBoss then 28 else 21)), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), Color = TIER_COLORS[def.Tier], Segments = if isBoss then 10 else 5, ShowText = true, Parent = frame })
	frame.Parent = barColumn
	local entry: BarEntry = { model = model, frame = frame, bar = bar, label = label }
	bars[model] = entry
	local function refresh()
		local hp = model:GetAttribute("HP") or 0
		local maxHP = model:GetAttribute("MaxHP") or 1
		bar:Set(math.max(0, hp), maxHP)
		label.Text = def.Name .. (if model:GetAttribute("Enraged") then "  (enraged)" else "")
	end
	refresh()
	model:GetAttributeChangedSignal("HP"):Connect(refresh)
	model:GetAttributeChangedSignal("Enraged"):Connect(refresh)
	layoutBars()
end

local function removeBar(model: Model)
	local entry = bars[model]
	if entry then
		bars[model] = nil
		entry.frame:Destroy()
		layoutBars()
	end
end

local function scan()
	local key = player:GetAttribute("ArenaKey")
	local folder = workspace:FindFirstChild("Enemies")
	local seen = {}
	if key and folder then
		for _, model in ipairs(folder:GetChildren()) do
			if model:IsA("Model") and model:GetAttribute("ArenaKey") == key and not model:GetAttribute("Dead") then
				seen[model] = true
				addBar(model)
			end
		end
	end
	for model in pairs(bars) do
		if not seen[model] then
			removeBar(model)
		end
	end
end

local function closeRewards()
	if rewards then
		rewards:Destroy()
		rewards = nil
	end
end

local function showRewards(data: any)
	closeRewards()
	if typeof(data) ~= "table" then
		return
	end
	local items = if typeof(data.Items) == "table" then data.Items else {}
	local compact = Theme.isCompact()
	local width = if compact then 420 else 520
	local rows = math.max(1, #items)
	local height = 150 + math.min(rows, 7) * 40
	local frame = Panel.new({ Name = "BossRewards", Size = UDim2.fromOffset(width, height), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = root })
	rewards = frame
	Theme.text({ Font = "Title", Text = "Victory!", TextSize = 34, Color = Theme.Colors.Gold, Size = UDim2.new(1, -20, 0, 38), Position = UDim2.fromOffset(10, 8), Parent = frame })
	Theme.text({ Text = `{tostring(data.Boss)} defeated - your rewards:`, TextSize = 19, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 46), Parent = frame })
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.new(1, -24, 0, math.min(rows, 7) * 40)
	list.Position = UDim2.fromOffset(12, 74)
	list.CanvasSize = UDim2.fromOffset(0, rows * 40)
	list.ScrollBarThickness = 6
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list
	list.Parent = frame
	if #items == 0 then
		Theme.text({ Text = "No reward: deal at least 5% of an enemy's HP to share its rewards.", TextSize = 18, Wrapped = true, Color = Theme.Colors.TextDim, Size = UDim2.new(1, 0, 0, 36), Parent = list })
	end
	for _, item in ipairs(items) do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -8, 0, 36)
		Icons.create(tostring(item.Icon or "Star"), row, { Size = UDim2.fromOffset(32, 32), Position = UDim2.new(0, 2, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
		local text = Theme.text({ Text = tostring(item.Text), TextSize = 19, Align = "Left", Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(42, 0), Parent = row })
		if typeof(item.Rarity) == "number" then
			text.TextColor3 = Rarities.get(item.Rarity).Color
		end
		row.Parent = list
	end
	local seconds = if typeof(data.Seconds) == "number" then data.Seconds else 15
	local info = Theme.text({ Text = "", TextSize = 17, Color = Theme.Colors.TextDim, Size = UDim2.new(0.5, -10, 0, Theme.TOUCH), Position = UDim2.new(0, 12, 1, -10), AnchorPoint = Vector2.new(0, 1), Align = "Left", Parent = frame })
	Button.new({ Text = "Leave now", Style = "go", Size = UDim2.fromOffset(200, Theme.TOUCH), Position = UDim2.new(1, -12, 1, -10), AnchorPoint = Vector2.new(1, 1), Parent = frame, OnClick = function()
		local ok, result = pcall(Net.request, "LeaveBossRoom")
		if not ok or result == false then
			closeRewards()
		end
	end })
	task.spawn(function()
		local endAt = os.clock() + seconds
		while rewards == frame and os.clock() < endAt do
			info.Text = `Back to the zone in {math.ceil(endAt - os.clock())} s`
			task.wait(0.25)
		end
	end)
end

local function onPhase(data: any)
	if typeof(data) ~= "table" then
		return
	end
	local phase = data.Phase
	if phase == "Lobby" then
		closeRewards()
		countdown(`{tostring(data.Name or "Boss")} - the fight starts`, data.Seconds or 5)
	elseif phase == "Minis" then
		countdownToken += 1
		showBanner("Mini-bosses!", tostring(data.Name or ""), 2.5, TIER_COLORS.mini)
		Sfx.play("TelegraphWarn")
	elseif phase == "Boss" then
		showBanner(tostring(data.Name or "Boss"), "BOSS", 2.6, TIER_COLORS.boss)
		Sfx.play("BossRoar")
	elseif phase == "Victory" then
		showBanner("Victory!", nil, 2.5, Theme.Colors.Good)
	elseif phase == "Failed" then
		countdownToken += 1
		showBanner("Defeated...", "Back to the zone", 3, TIER_COLORS.boss)
	elseif phase == "Left" then
		countdownToken += 1
		closeRewards()
		banner.Visible = false
		bannerSub.Visible = false
	end
end

function BossRoom:Start()
	local _, screen = Theme.screen("BossRoom", 8)
	root = screen
	barColumn = Instance.new("Frame")
	barColumn.Name = "BossBars"
	barColumn.BackgroundTransparency = 1
	barColumn.AnchorPoint = Vector2.new(0.5, 0)
	barColumn.Size = UDim2.fromOffset(BAR_WIDTH.Normal, 0)
	barColumn.AutomaticSize = Enum.AutomaticSize.Y
	barColumn.Visible = false
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = barColumn
	barColumn.Parent = Screens.hud()
	banner = Theme.text({ Name = "BossBanner", Font = "Title", Text = "", TextSize = 72, Size = UDim2.new(0.9, 0, 0, 80), Position = UDim2.fromScale(0.5, 0.3), AnchorPoint = Vector2.new(0.5, 0.5), Parent = root })
	banner.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Theme.Colors.Ink
	stroke.Parent = banner
	bannerSub = Theme.text({ Name = "BossBannerSub", Text = "", TextSize = 26, Size = UDim2.new(0.9, 0, 0, 32), Position = UDim2.new(0.5, 0, 0.3, 46), AnchorPoint = Vector2.new(0.5, 0), Parent = root })
	bannerSub.Visible = false
	Net.on("BossRoom", onPhase)
	Net.on("BossRewards", showRewards)
	player:GetAttributeChangedSignal("ArenaKey"):Connect(function()
		if not player:GetAttribute("ArenaKey") then
			closeRewards()
		end
		scan()
	end)
	task.spawn(function()
		while true do
			if player:GetAttribute("ArenaKey") or next(bars) ~= nil then
				scan()
			end
			task.wait(0.3)
		end
	end)
end

return BossRoom
