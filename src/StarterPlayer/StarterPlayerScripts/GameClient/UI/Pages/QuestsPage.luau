--!strict
-- The Quests window (docs/menu_systems_brief.txt D4), 4 tabs; every claim is a server request (RewardService):
--   Quests: today's 3 quests (same for everyone, new ones at 00:00 UTC) with progress, reward and Claim; the 3rd
--     claim adds the all-done bonus.
--   Daily Reward: the 7-day streak, today's reward to claim (missing a day restarts at day 1).
--   Playtime Gifts: 6 gifts by minutes played today.
--   Codes: a text box and Redeem.
-- Days and timers use the server clock (workspace:GetServerTimeNow()).
--   QuestsPage.build(ctx)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Quests = require(ReplicatedStorage.GameSystem.Config.Quests)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local State = require(script.Parent.Parent.Parent.State)
local Notifier = require(script.Parent.Parent.Notifier)
local Kit = script.Parent.Parent.Kit
local Button = require(Kit.Button)
local Icons = require(Kit.Icons)
local Theme = require(Kit.Theme)

local QuestsPage = {}

local busy = false
local playtimeSeen = os.clock() -- when the replicated play time last changed (the display adds the time since)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = seconds // 3600, (seconds // 60) % 60, seconds % 60
	return if h > 0 then string.format("%d:%02d:%02d", h, m, s) else string.format("%d:%02d", m, s)
end

local function g(): number
	return Quests.G(Stats.highestZone({ Zones = State.get("Zones") or {} }))
end

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

local function rewardText(reward: { [string]: any }): string
	local parts = {}
	if reward.Gold then
		table.insert(parts, `{Format.number(reward.Gold * g())} Gold`)
	end
	if reward.Diamonds then
		table.insert(parts, `{reward.Diamonds} Diamonds`)
	end
	if reward.PremiumEgg then
		table.insert(parts, "Premium egg")
	end
	if reward.Boost then
		table.insert(parts, `Gold x2 {reward.BoostMinutes or reward.Minutes} min`)
	end
	return table.concat(parts, " + ")
end

local function rewardIcon(reward: { [string]: any }): string
	if reward.PremiumEgg then
		return "Egg"
	elseif reward.Boost then
		return "Boost"
	elseif reward.Diamonds and not reward.Gold then
		return "Diamond"
	end
	return "Gold"
end

local function card(parent: Instance, size: UDim2, order: number, highlight: boolean?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = if highlight then Theme.Colors.WoodLight else Theme.Colors.WoodTop
	frame.Size = size
	frame.LayoutOrder = order
	frame.ZIndex = 2
	Theme.corner(frame, 8)
	Theme.stroke(frame, if highlight then Theme.Colors.GoldLight else Theme.Colors.GoldDark, 2)
	frame.Parent = parent
	return frame
end

local function clear(frame: Instance)
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function gridOf(page: Instance, order: number, cell: Vector2): Frame
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, -8, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.LayoutOrder = order
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	grid.Parent = page
	return grid
end

----------------------------------------------------------------------------------------------------
-- tabs
----------------------------------------------------------------------------------------------------
local function buildQuests(page: ScrollingFrame): () -> ()
	local small = Theme.isCompact()
	local header = Theme.text({ Font = "Number", Text = "", TextSize = 19, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -8, 0, 28), LayoutOrder = 0, Parent = page })
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, -8, 0, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.LayoutOrder = 1
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	list.Parent = page
	local bonus = Theme.text({ Font = "Button", Text = "", TextSize = 20, Size = UDim2.new(1, -8, 0, 30), LayoutOrder = 2, Parent = page })
	local function refresh()
		clear(list)
		local quests = State.get("Quests") or {}
		local today = Quests.day(now())
		local current = quests.Day == today and typeof(quests.List) == "table"
		if not current then
			Theme.text({ Text = "Getting today's quests...", TextSize = 20, Color = Theme.Colors.TextDim, Size = UDim2.new(1, 0, 0, 40), Parent = list })
			bonus.Text = ""
			return
		end
		local zone = Stats.highestZone({ Zones = State.get("Zones") or {} })
		local rowH = if small then 84 else 100
		for i, quest in ipairs(quests.List) do
			local kind = Quests.ById[quest.Id]
			if kind then
				local done = quest.Progress >= quest.Target
				local row = card(list, UDim2.new(1, 0, 0, rowH), i, done and not quest.Claimed)
				Icons.create(kind.Icon, row, { Size = UDim2.fromOffset(rowH - 20, rowH - 20), Position = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.zero, ZIndex = 3 })
				local x = rowH
				Theme.text({ Font = "Button", Text = Quests.describe(quest.Id, quest.Target, Format.number), TextSize = if small then 19 else 22, Align = "Left", Size = UDim2.new(0.62, -x, 0, 28), Position = UDim2.fromOffset(x, 8), ZIndex = 3, Parent = row })
				local bar = Instance.new("Frame")
				bar.BackgroundColor3 = Theme.Colors.WoodLine
				bar.Size = UDim2.new(0.62, -x - 70, 0, 16)
				bar.Position = UDim2.fromOffset(x, 42)
				bar.ZIndex = 3
				Theme.corner(bar, 8)
				bar.Parent = row
				local fill = Instance.new("Frame")
				fill.BackgroundColor3 = if done then Theme.Colors.Good else Theme.Colors.Gold
				fill.Size = UDim2.fromScale(math.clamp(quest.Progress / math.max(quest.Target, 1), 0, 1), 1)
				fill.ZIndex = 4
				Theme.corner(fill, 8)
				fill.Parent = bar
				Theme.text({ Font = "Number", Text = `{Format.number(math.floor(quest.Progress))} / {Format.number(quest.Target)}`, TextSize = 16, Align = "Left", Size = UDim2.new(0, 130, 0, 18), Position = UDim2.new(0.62, -64, 0, 41), ZIndex = 3, Parent = row })
				local reward = Quests.questReward(quest.Id, zone)
				Theme.text({ Text = `Reward: {rewardText(if reward.Gold then { Gold = reward.Gold / g() } else reward)}`, TextSize = 16, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(0.62, -x, 0, 20), Position = UDim2.fromOffset(x, 64), ZIndex = 3, Parent = row })
				local text, style = "In progress", "disabled"
				if quest.Claimed then
					text, style = "Claimed", "disabled"
				elseif done then
					text, style = "Claim", "go"
				end
				local button = Button.new({ Text = text, Style = style, TextSize = 22, Size = UDim2.new(0.3, -16, 0, Theme.TOUCH), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 3, Parent = row, OnClick = function()
					if quest.Claimed or not done then
						return
					end
					local ok, result = request("ClaimQuest", i)
					if ok then
						Sfx.play("Purchase")
						Notifier.push({ Kind = "reward", Text = `Quest reward: {result.text}`, Icon = "Quests" })
					end
				end })
				button.Instance.Name = "Claim" .. i
			end
		end
		local claimedAll = quests.Bonus == true
		bonus.Text = if claimedAll then `All 3 quests done: +{Quests.AllDoneDiamonds} Diamonds received` else `Finish and claim all 3 quests: +{Quests.AllDoneDiamonds} Diamonds`
		bonus.TextColor3 = if claimedAll then Theme.Colors.Good else Theme.Colors.Gold
	end
	refresh()
	State.changed("Quests", refresh)
	State.changed("Zones", refresh)
	return function()
		header.Text = `New quests in {clock(Quests.secondsToReset(now()))} (00:00 UTC)`
		local quests = State.get("Quests") or {}
		if quests.Day ~= Quests.day(now()) then
			refresh()
		end
	end
end

local function buildDaily(page: ScrollingFrame): () -> ()
	local small = Theme.isCompact()
	Theme.text({ Text = "Claim a reward every day. Missing a day restarts the streak at Day 1.", TextSize = 18, Wrapped = true, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -8, 0, 28), LayoutOrder = 0, Parent = page })
	-- the 7 days on one row
	local grid = gridOf(page, 1, if small then Vector2.new(88, 138) else Vector2.new(108, 172))
	local footer = Instance.new("Frame")
	footer.BackgroundTransparency = 1
	footer.Size = UDim2.new(1, -8, 0, Theme.TOUCH)
	footer.LayoutOrder = 2
	footer.Parent = page
	local claimButton = Button.new({ Name = "ClaimDaily", Text = "Claim", Style = "go", TextSize = 22, Size = UDim2.fromOffset(320, Theme.TOUCH), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0), Parent = footer, OnClick = function()
		local ok, result = request("ClaimDaily")
		if ok then
			Sfx.play("Purchase")
			Notifier.push({ Kind = "reward", Text = `Day {result.day}: {result.text}`, Icon = "Rewards" })
		end
	end })
	local function refresh()
		clear(grid)
		local today = Quests.day(now())
		local daily = State.get("Daily") or {}
		local nextIndex = Quests.nextDaily(daily, today)
		local streak = if nextIndex then nextIndex - 1 else (tonumber(daily.Streak) or 0)
		for i, reward in ipairs(Quests.Daily) do
			local isNext = nextIndex == i
			local claimed = i <= streak
			local c = card(grid, UDim2.new(), i, isNext)
			Theme.text({ Font = "Title", Text = `Day {i}`, TextSize = 22, Color = Theme.Colors.Gold, Size = UDim2.new(1, -8, 0, 28), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3, Parent = c })
			Icons.create(rewardIcon(reward), c, { Size = UDim2.fromOffset(if small then 44 else 58, if small then 44 else 58), Position = UDim2.new(0.5, 0, 0, if small then 32 else 36), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3 })
			Theme.text({ Text = rewardText(reward), TextSize = 15, Wrapped = true, Size = UDim2.new(1, -8, 0, 40), Position = UDim2.new(0.5, 0, 1, -30), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 3, Parent = c })
			if claimed then
				local dot = Instance.new("Frame")
				dot.Size = UDim2.fromOffset(30, 30)
				dot.Position = UDim2.new(1, -4, 0, 4)
				dot.AnchorPoint = Vector2.new(1, 0)
				dot.BackgroundColor3 = Theme.Colors.Good
				dot.ZIndex = 4
				Theme.round(dot)
				Icons.create("Check", dot, { Size = UDim2.fromScale(0.8, 0.8), ZIndex = 5 })
				dot.Parent = c
			end
			Theme.text({ Font = "Button", Text = if claimed then "Claimed" elseif isNext then "Today" else "", TextSize = 15, Color = if isNext then Theme.Colors.Good else Theme.Colors.TextDim, Size = UDim2.new(1, -8, 0, 20), Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 3, Parent = c })
		end
	end
	refresh()
	State.changed("Daily", refresh)
	State.changed("Zones", refresh)
	local lastDay = Quests.day(now())
	return function()
		local today = Quests.day(now())
		if today ~= lastDay then
			lastDay = today
			refresh()
		end
		local nextIndex = Quests.nextDaily(State.get("Daily"), today)
		if nextIndex then
			claimButton:SetText(`Claim Day {nextIndex}`)
			claimButton:SetStyle("go")
		else
			claimButton:SetText(`Next reward in {clock(Quests.secondsToReset(now()))}`)
			claimButton:SetStyle("disabled")
		end
	end
end

local function playedSeconds(): number
	local playtime = State.get("Playtime") or {}
	if playtime.Day ~= Quests.day(now()) then
		return 0
	end
	return (tonumber(playtime.Seconds) or 0) + math.min(Quests.PlaytimeTickSeconds, os.clock() - playtimeSeen)
end

local function buildGifts(page: ScrollingFrame): () -> ()
	local small = Theme.isCompact()
	local header = Theme.text({ Font = "Number", Text = "", TextSize = 20, Color = Theme.Colors.Gold, Size = UDim2.new(1, -8, 0, 28), LayoutOrder = 0, Parent = page })
	-- the 6 gifts on one row
	local grid = gridOf(page, 1, if small then Vector2.new(104, 160) else Vector2.new(128, 196))
	local timers: { [number]: { label: TextLabel, button: any } } = {}
	local function refresh()
		clear(grid)
		table.clear(timers)
		for i, gift in ipairs(Quests.Gifts) do
			local c = card(grid, UDim2.new(), i)
			Theme.text({ Font = "Title", Text = `{gift.Minutes} min`, TextSize = 22, Color = Theme.Colors.Gold, Size = UDim2.new(1, -8, 0, 28), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3, Parent = c })
			Icons.create(if gift.Boost then "Boost" elseif gift.Diamonds and not gift.Gold then "Diamond" else "Rewards", c, { Size = UDim2.fromOffset(50, 50), Position = UDim2.new(0.5, 0, 0, 34), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3 })
			local label = Theme.text({ Text = rewardText(gift), TextSize = 15, Wrapped = true, Size = UDim2.new(1, -8, 0, 36), Position = UDim2.new(0.5, 0, 0, 88), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3, Parent = c })
			local button = Button.new({ Text = "", Style = "disabled", TextSize = 18, Size = UDim2.new(1, -12, 0, Theme.TOUCH), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 3, Parent = c, OnClick = function()
				local ok, result = request("ClaimGift", i)
				if ok then
					Sfx.play("Purchase")
					Notifier.push({ Kind = "reward", Text = `Gift: {result.text}`, Icon = "Rewards" })
				end
			end })
			button.Instance.Name = "Gift" .. i
			timers[i] = { label = label, button = button }
		end
	end
	refresh()
	State.changed("Zones", refresh)
	return function()
		local played = playedSeconds()
		header.Text = `Played today: {clock(played)}`
		local playtime = State.get("Playtime") or {}
		local claimed = if playtime.Day == Quests.day(now()) then playtime.Claimed or {} else {}
		for i, gift in ipairs(Quests.Gifts) do
			local entry = timers[i]
			if entry then
				if table.find(claimed, i) then
					entry.button:SetText("Claimed")
					entry.button:SetStyle("disabled")
				elseif played >= gift.Minutes * 60 then
					entry.button:SetText("Claim")
					entry.button:SetStyle("go")
				else
					entry.button:SetText(clock(gift.Minutes * 60 - played))
					entry.button:SetStyle("disabled")
				end
			end
		end
	end
end

local function buildCodes(page: ScrollingFrame)
	Theme.text({ Text = "Enter a code to get a reward. Each code works once per player.", TextSize = 20, Wrapped = true, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 0, Parent = page })
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -8, 0, Theme.TOUCH)
	row.LayoutOrder = 1
	row.Parent = page
	local box = Instance.new("TextBox")
	box.Name = "CodeBox"
	box.PlaceholderText = "Code"
	box.Text = ""
	box.ClearTextOnFocus = false
	box.FontFace = Theme.Fonts.Number
	box.TextSize = 24
	box.TextColor3 = Theme.Colors.Text
	box.PlaceholderColor3 = Theme.Colors.TextDim
	box.BackgroundColor3 = Theme.Colors.WoodInset
	box.Size = UDim2.new(0.6, -8, 1, 0)
	Theme.corner(box, 8)
	Theme.stroke(box, Theme.Colors.GoldDark, 2)
	box.Parent = row
	local result = Theme.text({ Text = "", TextSize = 20, Wrapped = true, Size = UDim2.new(1, -8, 0, 50), LayoutOrder = 2, Parent = page })
	local function redeem()
		local code = box.Text
		if #code == 0 then
			return
		end
		local called, ok, message = pcall(Net.request, "RedeemCode", code)
		local text = if called and typeof(message) == "string" then message else "Could not redeem"
		result.Text = text
		result.TextColor3 = if called and ok then Theme.Colors.Good else Theme.Colors.Bad
		if called and ok then
			Sfx.play("Purchase")
			Notifier.push({ Kind = "reward", Text = text, Icon = "Rewards" })
			box.Text = ""
		else
			Sfx.play("Denied")
		end
	end
	Button.new({ Name = "Redeem", Text = "Redeem", Style = "go", TextSize = 22, Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), Parent = row, OnClick = redeem })
	box.FocusLost:Connect(function(enter)
		if enter then
			redeem()
		end
	end)
end

function QuestsPage.build(ctx: any)
	local tickers = {
		buildQuests(ctx.Pages.Quests),
		buildDaily(ctx.Pages["Daily Reward"]),
		buildGifts(ctx.Pages["Playtime Gifts"]),
	}
	buildCodes(ctx.Pages.Codes)
	State.changed("Playtime", function()
		playtimeSeen = os.clock()
	end)
	task.spawn(function()
		while true do
			if ctx.Frame.Visible then
				for _, fn in ipairs(tickers) do
					fn()
				end
			end
			task.wait(1)
		end
	end)
end

-- Claimable count for the menu badge (quests, today's daily reward, playtime gifts).
function QuestsPage.claimable(): number
	local n = 0
	local today = Quests.day(now())
	local quests = State.get("Quests") or {}
	if quests.Day == today then
		for _, quest in ipairs(quests.List or {}) do
			if not quest.Claimed and quest.Progress >= quest.Target then
				n += 1
			end
		end
	end
	if State.get("Daily") ~= nil and Quests.nextDaily(State.get("Daily"), today) then
		n += 1
	end
	local playtime = State.get("Playtime") or {}
	if playtime.Day == today then
		local played = playedSeconds()
		for i, gift in ipairs(Quests.Gifts) do
			if played >= gift.Minutes * 60 and not table.find(playtime.Claimed or {}, i) then
				n += 1
			end
		end
	end
	return n
end

return QuestsPage
