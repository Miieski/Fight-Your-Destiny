--!strict
-- Quests window rewards (docs/menu_systems_brief.txt D4), all validated here (Config/Quests, Config/Codes):
--   Net.request("ClaimQuest", i)   i = 1..3, a finished quest of today; the 3rd claim adds the all-done bonus
--   Net.request("ClaimDaily")      the 7-day streak reward of today (missing a day restarts at day 1)
--   Net.request("ClaimGift", i)    a playtime gift once its minutes are reached today
--   Net.request("RedeemCode", code)   once per player, optional expiry
-- RewardService.progress(player, kind, n) is called by the game systems (enemies, shop, eggs, gates, attributes).
-- Daily quests, play time and the daily reward use UTC days: they reset at 00:00 UTC.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Codes = require(ReplicatedStorage.GameSystem.Config.Codes)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Quests = require(ReplicatedStorage.GameSystem.Config.Quests)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local DataService = require(script.Parent.DataService)

local RewardService = { Priority = 7 }

local MAX_CODE_LENGTH = 30
local lastTick: { [Player]: number } = {}

local function services(): any
	-- required when used (PetService -> ShopService -> RewardService would loop at load time)
	local folder = ServerScriptService.GameSystem.Services
	return {
		Pet = require(folder.PetService) :: any,
		Boost = require(folder.BoostService) :: any,
		Shop = require(folder.ShopService) :: any,
	}
end

local function today(): number
	return Quests.day(os.time())
end

local function zoneOf(profile: { [string]: any }): number
	return Stats.highestZone(profile)
end

-- Today's quests: regenerated on a new UTC day.
local function ensureQuests(player: Player, profile: { [string]: any }): { [string]: any }
	local quests = profile.Quests
	local day = today()
	if typeof(quests) == "table" and quests.Day == day and typeof(quests.List) == "table" and #quests.List == Quests.PerDay then
		return quests
	end
	local zone = zoneOf(profile)
	local list = {}
	for _, id in ipairs(Quests.forDay(day)) do
		table.insert(list, { Id = id, Progress = 0, Target = Quests.target(id, zone), Claimed = false })
	end
	local fresh = { Day = day, List = list, Bonus = false }
	DataService:Set(player, "Quests", fresh)
	return fresh
end

local function ensurePlaytime(player: Player, profile: { [string]: any }): { [string]: any }
	local playtime = profile.Playtime
	local day = today()
	if typeof(playtime) == "table" and playtime.Day == day then
		return playtime
	end
	local fresh = { Day = day, Seconds = 0, Claimed = {} }
	DataService:Set(player, "Playtime", fresh)
	return fresh
end

-- Pays a reward table { Gold (in G), Diamonds, PremiumEgg, Boost + Minutes / BoostMinutes }; returns a text.
local function pay(player: Player, profile: { [string]: any }, reward: { [string]: any }, goldIsG: boolean): string
	local parts = {}
	local zone = zoneOf(profile)
	if reward.Gold then
		local gold = if goldIsG then reward.Gold * Quests.G(zone) else reward.Gold
		DataService:AddGold(player, gold)
		table.insert(parts, `{Format.number(gold)} Gold`)
	end
	if reward.Diamonds then
		DataService:AddDiamonds(player, reward.Diamonds)
		table.insert(parts, `{reward.Diamonds} Diamonds`)
	end
	if reward.PremiumEgg then
		local s = services()
		local tier = s.Shop.rollTier(Random.new(), 1)
		s.Pet:GiveEgg(player, zone, tier)
		table.insert(parts, `a premium {Zones.List[zone].Name} egg`)
	end
	if reward.Boost then
		local minutes = reward.BoostMinutes or reward.Minutes or 0
		services().Boost:Add(player, reward.Boost, minutes * 60)
		table.insert(parts, `Gold Boost x2 ({minutes} min)`)
	end
	return table.concat(parts, " + ")
end

-- Called by the game systems: adds n to today's quests of this kind (capped at their target).
function RewardService.progress(player: Player, kind: string, n: number?)
	local profile = DataService:Get(player)
	if not profile or not Quests.ById[kind] then
		return
	end
	local amount = tonumber(n) or 1
	if amount <= 0 then
		return
	end
	local quests = ensureQuests(player, profile)
	local changed = false
	local list = table.clone(quests.List)
	for i, quest in ipairs(list) do
		if quest.Id == kind and not quest.Claimed and quest.Progress < quest.Target then
			local copy = table.clone(quest)
			copy.Progress = math.min(copy.Target, copy.Progress + amount)
			list[i] = copy
			changed = true
			if copy.Progress >= copy.Target then
				Net.fire(player, "Notify", { Kind = "reward", Text = `Quest done: {Quests.describe(kind, copy.Target, Format.number)}`, Icon = "Quests" })
			end
		end
	end
	if changed then
		DataService:Set(player, "Quests", { Day = quests.Day, List = list, Bonus = quests.Bonus })
	end
end

local function claimQuest(player: Player, i: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	if typeof(i) ~= "number" or i % 1 ~= 0 or i < 1 or i > Quests.PerDay then
		return false, "Bad request"
	end
	local quests = ensureQuests(player, profile)
	local quest = quests.List[i]
	if quest.Claimed then
		return false, "Already claimed"
	end
	if quest.Progress < quest.Target then
		return false, "Not finished yet"
	end
	local list = table.clone(quests.List)
	local copy = table.clone(quest)
	copy.Claimed = true
	list[i] = copy
	local allDone = true
	for _, q in ipairs(list) do
		if not q.Claimed then
			allDone = false
		end
	end
	local bonus = quests.Bonus == true
	local giveBonus = allDone and not bonus
	DataService:Set(player, "Quests", { Day = quests.Day, List = list, Bonus = bonus or giveBonus })
	local text = pay(player, profile, Quests.questReward(quest.Id, zoneOf(profile)), false)
	if giveBonus then
		DataService:AddDiamonds(player, Quests.AllDoneDiamonds)
		text ..= ` + all quests bonus {Quests.AllDoneDiamonds} Diamonds`
	end
	DataService:Save(player)
	return true, { text = text, bonus = giveBonus }
end

local function claimDaily(player: Player): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local day = today()
	local index = Quests.nextDaily(profile.Daily, day)
	if not index then
		return false, "Already claimed today. Come back tomorrow!"
	end
	DataService:Set(player, "Daily", { Streak = index, LastDay = day })
	local text = pay(player, profile, Quests.Daily[index], true)
	DataService:Save(player)
	return true, { day = index, text = text }
end

local function claimGift(player: Player, i: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local gift = if typeof(i) == "number" and i % 1 == 0 then Quests.Gifts[i] else nil
	if not gift then
		return false, "Bad request"
	end
	local playtime = ensurePlaytime(player, profile)
	if table.find(playtime.Claimed, i) then
		return false, "Already claimed"
	end
	-- count the time since the last tick too
	local seconds = playtime.Seconds + (if lastTick[player] then os.clock() - lastTick[player] else 0)
	if seconds < gift.Minutes * 60 then
		return false, `Play {math.ceil((gift.Minutes * 60 - seconds) / 60)} more minute(s)`
	end
	local claimed = table.clone(playtime.Claimed)
	table.insert(claimed, i)
	DataService:Set(player, "Playtime", { Day = playtime.Day, Seconds = playtime.Seconds, Claimed = claimed })
	local text = pay(player, profile, gift, true)
	DataService:Save(player)
	return true, { text = text }
end

local function redeem(player: Player, code: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	if typeof(code) ~= "string" or #code == 0 or #code > MAX_CODE_LENGTH then
		return false, "Enter a code"
	end
	local key = string.upper((string.gsub(code, "%s", "")))
	local reward = (Codes :: any)[key]
	if not reward then
		return false, "Unknown code"
	end
	if reward.Expires and os.time() > reward.Expires then
		return false, "This code has expired"
	end
	if profile.Codes[key] then
		return false, "Code already used"
	end
	local used = table.clone(profile.Codes)
	used[key] = true
	DataService:Set(player, "Codes", used)
	local text = pay(player, profile, reward, true)
	DataService:Save(player)
	return true, `Code redeemed: {text}`
end

-- Play time: added every tick for every player, replicated with the profile.
local function tick()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataService:Get(player)
		if profile then
			local playtime = ensurePlaytime(player, profile)
			local last = lastTick[player] or now
			lastTick[player] = now
			local add = math.max(0, now - last)
			if add > 0 then
				DataService:Set(player, "Playtime", { Day = playtime.Day, Seconds = playtime.Seconds + add, Claimed = playtime.Claimed })
			end
			ensureQuests(player, profile)
		end
	end
end

-- Admin / tests
function RewardService:AddPlaytime(player: Player, seconds: number)
	local profile = DataService:Get(player)
	if profile then
		local playtime = ensurePlaytime(player, profile)
		DataService:Set(player, "Playtime", { Day = playtime.Day, Seconds = playtime.Seconds + seconds, Claimed = playtime.Claimed })
	end
end

function RewardService:Init()
	Net.handle("ClaimQuest", claimQuest, 0.3)
	Net.handle("ClaimDaily", claimDaily, 0.5)
	Net.handle("ClaimGift", claimGift, 0.3)
	Net.handle("RedeemCode", redeem, 1)
	local function loaded(player: Player)
		local profile = DataService:Get(player)
		if profile then
			ensureQuests(player, profile)
			ensurePlaytime(player, profile)
			lastTick[player] = lastTick[player] or os.clock()
		end
	end
	DataService.Loaded:Connect(loaded)
	-- profiles loaded before this service started listening (Studio play solo)
	for _, player in ipairs(Players:GetPlayers()) do
		loaded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTick[player] = nil
	end)
end

function RewardService:Start()
	while true do
		task.wait(Quests.PlaytimeTickSeconds)
		tick()
	end
end

return RewardService
