--!strict
-- The Quests window (docs/menu_systems_brief.txt D4), 4 tabs; every claim is a server request (RewardService):
--   Quests: today's 3 quests (same for everyone, new ones at 00:00 UTC) with progress, reward and Claim; the 3rd
--     claim adds the all-done bonus.
--   Daily Reward: the 7-day streak, today's reward to claim (missing a day restarts at day 1).
--   Playtime Gifts: 6 gifts by minutes played today.
--   Codes: a text box and Redeem.
-- Kid-friendly UI (owner 2026-10-13: "avoid text, more visual"): rewards are icon + number chips, timers are a clock
-- + time, claim buttons show a picture (gift = claim now, grey gift = not yet, check = claimed, clock = wait); a
-- quest's sentence shows when its picture is tapped; the rules are behind an (i).
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
local Chips = require(Kit.Chips)
local Icons = require(Kit.Icons)
local Info = require(Kit.Info)
local Theme = require(Kit.Theme)

local QuestsPage = {}

local busy = false
local playtimeSeen = os.clock() -- when the replicated play time last changed (the display adds the time since)
local windowFrame: GuiObject? = nil

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

-- The reward as icon + number chips. goldMult: Daily / Gifts store Gold as a multiple of the zone's G.
local function rewardChips(parent: Instance, reward: { [string]: any }, height: number, goldMult: number, props: { [string]: any }?): Frame
	local p = props or {}
	local row = Chips.row(parent, { Name = "Reward", Align = p.Align or "Center", ZIndex = 3, LayoutOrder = p.LayoutOrder })
	row.Size = p.Size or UDim2.new(1, -8, 0, 0)
	if p.Position then
		row.Position = p.Position
		row.AnchorPoint = p.AnchorPoint or Vector2.zero
	end
	local list = row:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	list.Padding = UDim.new(0, 4)
	local order = 0
	local function chip(icon: string, text: string)
		order += 1
		Chips.chip(row, icon, text, { Height = height, LayoutOrder = order, ZIndex = 3 })
	end
	if reward.Gold then
		chip("Gold", Format.number(reward.Gold * goldMult))
	end
	if reward.Diamonds then
		chip("Diamond", tostring(reward.Diamonds))
	end
	if reward.PremiumEgg then
		chip("Egg", "1")
	end
	if reward.Boost then
		chip("Boost", `{reward.BoostMinutes or reward.Minutes}m`)
	end
	return row
end

-- A claim button that shows a picture: "claim" = gift (green), "locked" = grey gift (not yet), "done" = check,
-- "wait" = clock + time left.
type ClaimButton = { button: any, set: (state: string, text: string?) -> () }
local function claimButton(props: { [string]: any }): ClaimButton
	props.Text = ""
	props.Style = "disabled"
	props.TextSize = props.TextSize or 26
	local button = Button.new(props)
	local z = button.Instance.ZIndex
	local pics = {
		Gift = Icons.create("Gift", button.Face, { Size = UDim2.new(0, 0, 0.72, 0), ZIndex = z }),
		Check = Icons.create("Check", button.Face, { Size = UDim2.new(0, 0, 0.72, 0), ZIndex = z }),
		Clock = Icons.create("Clock", button.Face, { Size = UDim2.new(0, 0, 0.66, 0), Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = z }),
	}
	button.Label.Size = UDim2.new(1, -52, 0.78, 0)
	button.Label.Position = UDim2.new(0, 44, 0.5, 0)
	button.Label.AnchorPoint = Vector2.new(0, 0.5)
	local function set(state: string, text: string?)
		pics.Gift.Visible = state == "claim" or state == "locked"
		pics.Check.Visible = state == "done"
		pics.Clock.Visible = state == "wait"
		button:SetText(if state == "wait" then text or "" else "")
		button:SetStyle(if state == "claim" then "go" else "disabled")
	end
	set("locked")
	return { button = button, set = set }
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

-- The top line of a tab: chips on the left, an (i) with the rules on the right.
local function topRow(page: Instance, title: string, lines: { string }?): Frame
	local row = Instance.new("Frame")
	row.Name = "Top"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -8, 0, 44)
	row.LayoutOrder = 0
	row.Parent = page
	if lines and windowFrame then
		Info.button({ Parent = row, Frame = windowFrame, Title = title, Lines = lines, Size = 40, Position = UDim2.new(1, -4, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 3, PopupSize = Vector2.new(560, 260) })
	end
	return row
end

----------------------------------------------------------------------------------------------------
-- tabs
----------------------------------------------------------------------------------------------------
local function buildQuests(page: ScrollingFrame): () -> ()
	local small = Theme.isCompact()
	local top = topRow(page, "Quests", { "3 new quests every day at 00:00 UTC.", `Finish and claim all 3 quests: +{Quests.AllDoneDiamonds} Diamonds.`, "Tap a quest's picture to see what to do." })
	local timer = Chips.chip(top, "Clock", "", { Height = 40, Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
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
	-- the all-done bonus: 3 checks -> Diamonds
	local bonus = Chips.row(page, { Name = "Bonus", Align = "Center", LayoutOrder = 2 })
	local bonusDone = Chips.chip(bonus, "Check", "0/3", { Height = 40, LayoutOrder = 1 })
	Icons.create("Arrow", bonus, { Size = UDim2.fromOffset(30, 30), ZIndex = 3 }).LayoutOrder = 2
	local bonusReward = Chips.chip(bonus, "Diamond", `+{Quests.AllDoneDiamonds}`, { Height = 40, LayoutOrder = 3 })
	local function refresh()
		clear(list)
		local quests = State.get("Quests") or {}
		local today = Quests.day(now())
		local current = quests.Day == today and typeof(quests.List) == "table"
		if not current then
			Icons.create("Clock", list, { Size = UDim2.fromOffset(56, 56), ZIndex = 3 }) -- getting today's quests
			bonus.Visible = false
			return
		end
		bonus.Visible = true
		local zone = Stats.highestZone({ Zones = State.get("Zones") or {} })
		local rowH = if small then 76 else 92
		local claimedCount = 0
		for i, quest in ipairs(quests.List) do
			local kind = Quests.ById[quest.Id]
			if kind then
				local done = quest.Progress >= quest.Target
				if quest.Claimed then
					claimedCount += 1
				end
				local row = card(list, UDim2.new(1, 0, 0, rowH), i, done and not quest.Claimed)
				-- the quest's picture: tap = what to do
				local pic = Instance.new("TextButton")
				pic.Name = "Picture"
				pic.Text = ""
				pic.AutoButtonColor = false
				pic.BackgroundTransparency = 1
				pic.Size = UDim2.fromOffset(rowH - 16, rowH - 16)
				pic.Position = UDim2.fromOffset(8, 8)
				pic.ZIndex = 3
				pic.Parent = row
				Icons.create(kind.Icon, pic, { ZIndex = 3 })
				local sentence = Quests.describe(quest.Id, quest.Target, Format.number)
				pic.Activated:Connect(function()
					Sfx.play("UIClick")
					Notifier.push({ Kind = "info", Text = sentence, Icon = kind.Icon })
				end)
				local x = rowH
				-- progress bar with the numbers inside
				local bar = Instance.new("Frame")
				bar.BackgroundColor3 = Theme.Colors.WoodLine
				bar.Size = UDim2.new(0.6, -x, 0, 30)
				bar.Position = UDim2.fromOffset(x, 10)
				bar.ZIndex = 3
				Theme.corner(bar, 10)
				Theme.stroke(bar, Theme.Colors.GoldDark, 1.5)
				bar.Parent = row
				local fill = Instance.new("Frame")
				fill.BackgroundColor3 = if done then Theme.Colors.Good else Theme.Colors.Gold
				fill.Size = UDim2.fromScale(math.clamp(quest.Progress / math.max(quest.Target, 1), 0, 1), 1)
				fill.ZIndex = 4
				Theme.corner(fill, 10)
				fill.Parent = bar
				Theme.text({ Font = "Number", Text = `{Format.number(math.floor(quest.Progress))}/{Format.number(quest.Target)}`, TextSize = 18, Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5, Parent = bar })
				local reward = Quests.questReward(quest.Id, zone)
				rewardChips(row, reward, if small then 28 else 32, 1, { Align = "Left", Size = UDim2.new(0.6, -x, 0, 0), Position = UDim2.fromOffset(x, 46) })
				local claim = claimButton({ Name = "Claim" .. i, Size = UDim2.new(0.3, -16, 0, Theme.TOUCH), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 3, Parent = row, OnClick = function()
					if quest.Claimed or not done then
						return
					end
					local ok, result = request("ClaimQuest", i)
					if ok then
						Sfx.play("Purchase")
						Notifier.push({ Kind = "reward", Text = `Quest reward: {result.text}`, Icon = "Quests" })
					end
				end })
				claim.set(if quest.Claimed then "done" elseif done then "claim" else "locked")
			end
		end
		local claimedAll = quests.Bonus == true
		bonusDone:Set(`{claimedCount}/3`, if claimedAll then Theme.Colors.Good else nil)
		bonusReward:Set(`+{Quests.AllDoneDiamonds}`, if claimedAll then Theme.Colors.Good else Theme.Colors.Gold)
	end
	refresh()
	State.changed("Quests", refresh)
	State.changed("Zones", refresh)
	return function()
		timer:Set(clock(Quests.secondsToReset(now())))
		local quests = State.get("Quests") or {}
		if quests.Day ~= Quests.day(now()) then
			refresh()
		end
	end
end

local function buildDaily(page: ScrollingFrame): () -> ()
	local small = Theme.isCompact()
	local top = topRow(page, "Daily Reward", { "Claim a reward every day.", "Missing a day restarts the streak at Day 1." })
	Icons.create("Calendar", top, { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
	-- the 7 days on one row
	local grid = gridOf(page, 1, if small then Vector2.new(88, 138) else Vector2.new(108, 172))
	local footer = Instance.new("Frame")
	footer.BackgroundTransparency = 1
	footer.Size = UDim2.new(1, -8, 0, Theme.TOUCH)
	footer.LayoutOrder = 2
	footer.Parent = page
	local claim = claimButton({ Name = "ClaimDaily", TextSize = 22, Size = UDim2.fromOffset(240, Theme.TOUCH), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0), Parent = footer, OnClick = function()
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
			Theme.text({ Font = "Title", Text = tostring(i), TextSize = 26, Color = Theme.Colors.Gold, Size = UDim2.new(1, -8, 0, 30), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3, Parent = c })
			if reward.Gold and reward.Diamonds then
				-- two rewards: their chips one above the other, no big picture
				rewardChips(c, reward, if small then 26 else 30, g(), { Position = UDim2.new(0.5, 0, 0, if small then 40 else 50), AnchorPoint = Vector2.new(0.5, 0) })
			else
				Icons.create(rewardIcon(reward), c, { Size = UDim2.fromOffset(if small then 44 else 58, if small then 44 else 58), Position = UDim2.new(0.5, 0, 0, if small then 34 else 38), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3 })
				rewardChips(c, reward, if small then 26 else 30, g(), { Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1) })
			end
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
		if Quests.nextDaily(State.get("Daily"), today) then
			claim.set("claim")
		else
			claim.set("wait", clock(Quests.secondsToReset(now())))
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
	local top = topRow(page, "Playtime Gifts", { "Play to open the gifts: each one has a time.", "The timer starts again every day." })
	local played = Chips.chip(top, "Clock", "0:00", { Height = 40, Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
	-- the 6 gifts on one row
	local grid = gridOf(page, 1, if small then Vector2.new(104, 160) else Vector2.new(128, 196))
	local buttons: { [number]: ClaimButton } = {}
	local function refresh()
		clear(grid)
		table.clear(buttons)
		for i, gift in ipairs(Quests.Gifts) do
			local c = card(grid, UDim2.new(), i)
			Chips.chip(c, "Clock", `{gift.Minutes}m`, { Height = 30, Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3 })
			local iconSize = if small then 40 else 50
			local parts = (if gift.Gold then 1 else 0) + (if gift.Diamonds then 1 else 0) + (if gift.PremiumEgg then 1 else 0) + (if gift.Boost then 1 else 0)
			if parts > 1 then
				-- two rewards: their chips one above the other, no big picture
				rewardChips(c, gift, if small then 26 else 30, g(), { Position = UDim2.fromOffset(4, 42) })
			else
				Icons.create(if gift.Boost then "Boost" elseif gift.Diamonds and not gift.Gold then "Diamond" else "Rewards", c, { Size = UDim2.fromOffset(iconSize, iconSize), Position = UDim2.new(0.5, 0, 0, 40), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3 })
				rewardChips(c, gift, if small then 26 else 30, g(), { Position = UDim2.fromOffset(4, 44 + iconSize) })
			end
			buttons[i] = claimButton({ Name = "Gift" .. i, TextSize = 24, Size = UDim2.new(1, -12, 0, Theme.TOUCH), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 3, Parent = c, OnClick = function()
				local ok, result = request("ClaimGift", i)
				if ok then
					Sfx.play("Purchase")
					Notifier.push({ Kind = "reward", Text = `Gift: {result.text}`, Icon = "Rewards" })
				end
			end })
		end
	end
	refresh()
	State.changed("Zones", refresh)
	return function()
		local seconds = playedSeconds()
		played:Set(clock(seconds))
		local playtime = State.get("Playtime") or {}
		local claimed = if playtime.Day == Quests.day(now()) then playtime.Claimed or {} else {}
		for i, gift in ipairs(Quests.Gifts) do
			local entry = buttons[i]
			if entry then
				if table.find(claimed, i) then
					entry.set("done")
				elseif seconds >= gift.Minutes * 60 then
					entry.set("claim")
				else
					entry.set("wait", clock(gift.Minutes * 60 - seconds))
				end
			end
		end
	end
end

local function buildCodes(page: ScrollingFrame)
	local top = topRow(page, "Codes", { "Enter a code to get a reward.", "Each code works once per player." })
	Icons.create("Ticket", top, { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
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
	Button.new({ Name = "Redeem", Icon = "Check", Style = "go", Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), Parent = row, OnClick = redeem })
	box.FocusLost:Connect(function(enter)
		if enter then
			redeem()
		end
	end)
end

function QuestsPage.build(ctx: any)
	windowFrame = ctx.Frame
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
