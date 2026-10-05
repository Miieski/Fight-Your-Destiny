--!strict
-- Weapon shop (docs/weapon_shop_brief.txt part 3). Net.request("BuyWeapon", weaponId):
--   1. validates (known weapon, its zone unlocked, no opening running, rate limit, enough Gold),
--   2. takes the Gold, 3. rolls the rarity (shop odds + pity, Config/WeaponRarities), 4. stores the item
--   { id, rarity } under a new GUID, marks the Index, 5. saves, then answers
--   true, { uid, weaponId, rarity, pity = { PityCounter, PityLegendary }, pityReason? }.
-- The roll is final when the server answers; the client's case opening only shows it. Anything that would
-- spoil the reel (the "Obtained" toast, the server-wide announcement, the auto-equip of a first weapon) waits
-- until the opening ends: Net.send("OpeningDone") from the client, or the opening time running out.
-- If anything fails after the Gold was taken, every change is undone and the Gold is given back.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local WeaponRarities = require(ReplicatedStorage.GameSystem.Config.WeaponRarities)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local DataService = require(script.Parent.DataService)
local WeaponService = require(script.Parent.WeaponService)

local ShopService = { Priority = 5 }

-- Weapon Reroll (docs/menu_systems_brief.txt D1): the Diamonds are taken and the new rarity rolled at once (shop
-- odds, no pity); it replaces the old one only when the player answers "Keep new" (RerollChoice). No answer
-- (closed, left the game) = the old rarity stays.
type Reroll = { uid: string, tier: number }
local rerolls: { [Player]: Reroll } = {}

type Pending = { weaponId: string, tier: number, uid: string, equip: boolean }

local random = Random.new()
local busy: { [Player]: boolean } = {} -- a purchase is between validation and answer
local openingUntil: { [Player]: number } = {} -- os.clock() when the current opening ends at the latest
local pending: { [Player]: Pending } = {}
local forced: { [Player]: number } = {} -- admin forceRarity for the next purchase
local lastAnnounce = -math.huge

-- Rolls a tier >= minTier with the shop odds renormalised over those tiers.
function ShopService.rollTier(rng: Random, minTier: number): number
	local list = WeaponRarities.List
	local total = 0
	for tier = minTier, #list do
		total += list[tier].ShopOdds
	end
	local x = rng:NextNumber() * total
	for tier = minTier, #list do
		x -= list[tier].ShopOdds
		if x < 0 then
			return tier
		end
	end
	return #list
end

-- One purchase roll with the pity rules (pure: the simulation in ServerStorage.DevTools uses it too).
-- counters = { PityCounter = n, PityLegendary = n }; returns tier, the new counters, the pity label used.
function ShopService.roll(rng: Random, counters: { [string]: number }, forcedTier: number?): (number, { [string]: number }, string?)
	local minTier, reason = 1, nil
	for _, pity in ipairs(WeaponRarities.Pity) do
		if (counters[pity.Key] or 0) >= pity.After and pity.MinTier > minTier then
			minTier, reason = pity.MinTier, pity.Label
		end
	end
	local tier = forcedTier or ShopService.rollTier(rng, minTier)
	local nextCounters = {}
	for _, pity in ipairs(WeaponRarities.Pity) do
		nextCounters[pity.Key] = if tier >= pity.MinTier then 0 else (counters[pity.Key] or 0) + 1
	end
	return tier, nextCounters, if forcedTier then "forced" else reason
end

local function openingSeconds(profile: { [string]: any }): number
	local config = UIConfig.CaseOpening
	local spin = if profile.Settings and profile.Settings.FastOpen then config.FastSpinSeconds else config.SpinSeconds
	return spin + config.ServerGraceSeconds
end

local function weaponNameFor(viewer: Player, weaponId: string): string
	local weapon = Weapons.ById[weaponId]
	local profile = DataService:Get(viewer)
	-- never reveal a locked weapon's name, not even through someone else's announcement
	if profile and profile.Zones[weapon.ZoneId] then
		return weapon.Name
	end
	return "mystery weapon"
end

local function announce(player: Player, weaponId: string, tier: number)
	local now = os.clock()
	if tier < WeaponRarities.ANNOUNCE_FROM or now - lastAnnounce < WeaponRarities.ANNOUNCE_COOLDOWN then
		return
	end
	lastAnnounce = now
	local rarity = WeaponRarities.get(tier)
	for _, viewer in ipairs(Players:GetPlayers()) do
		if viewer ~= player then
			Net.fire(viewer, "Notify", { Kind = "loot", Text = `{player.DisplayName} opened a {rarity.Name} {weaponNameFor(viewer, weaponId)}!`, Rarity = tier })
		end
	end
end

-- Ends the current opening: the deferred toast, auto-equip and announcement happen now.
local function finish(player: Player)
	openingUntil[player] = nil
	local done = pending[player]
	pending[player] = nil
	if not done or not player.Parent then
		return
	end
	local rarity = WeaponRarities.get(done.tier)
	local weapon = Weapons.ById[done.weaponId]
	Net.fire(player, "Notify", { Kind = "loot", Text = `Obtained {rarity.Name} {weapon.Name}`, Rarity = done.tier, Icon = weapon.Icon or weapon.Category })
	if done.equip then
		local profile = DataService:Get(player)
		if profile and profile.EquippedWeapon == done.uid and profile.Weapons[done.uid] then
			WeaponService:Equip(player, done.uid)
		end
	end
	announce(player, done.weaponId, done.tier)
end

local function buy(player: Player, weaponId: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local weapon = if typeof(weaponId) == "string" then Weapons.ById[weaponId] else nil
	if not weapon then
		return false, "Unknown weapon"
	end
	if not profile.Zones[weapon.ZoneId] then
		return false, `Unlock {Zones.ById[weapon.ZoneId].Name} first`
	end
	if busy[player] or (openingUntil[player] or 0) > os.clock() then
		return false, "Finish the current opening first"
	end
	local price = Weapons.price(weapon.Zone)
	if typeof(profile.Gold) ~= "number" or profile.Gold < price then
		return false, "Not enough Gold"
	end

	-- From here to the item's creation nothing yields, so two requests can never both pass the checks.
	busy[player] = true
	local charged = false
	-- what the purchase changes, to put everything back if it fails half-way (never a free weapon)
	local before = {
		Weapons = profile.Weapons,
		PityCounter = profile.PityCounter,
		PityLegendary = profile.PityLegendary,
		Index = profile.Index,
		EquippedWeapon = profile.EquippedWeapon,
	}
	local ok, result = pcall(function()
		DataService:Set(player, "Gold", profile.Gold - price)
		charged = true
		local counters = { PityCounter = profile.PityCounter or 0, PityLegendary = profile.PityLegendary or 0 }
		local tier, nextCounters, pityReason = ShopService.roll(random, counters, forced[player])
		forced[player] = nil
		local uid = HttpService:GenerateGUID(false)
		local owned = table.clone(profile.Weapons)
		owned[uid] = { id = weapon.Id, rarity = tier }
		DataService:Set(player, "Weapons", owned)
		for key, value in pairs(nextCounters) do
			DataService:Set(player, key, value)
		end
		local best = profile.Index[weapon.Id]
		if typeof(best) ~= "number" or best < tier then
			local index = table.clone(profile.Index)
			index[weapon.Id] = tier -- best rarity owned (docs/menu_systems_brief.txt D3)
			DataService:Set(player, "Index", index)
		end
		-- a first weapon is equipped in the saved profile right away (so leaving mid-opening keeps it
		-- equipped); the client is told when the opening ends
		local hasWeapon = profile.EquippedWeapon ~= nil and owned[profile.EquippedWeapon] ~= nil
		if not hasWeapon then
			profile.EquippedWeapon = uid
		end
		pending[player] = { weaponId = weapon.Id, tier = tier, uid = uid, equip = not hasWeapon }
		return { uid = uid, weaponId = weapon.Id, rarity = tier, pity = nextCounters, pityReason = pityReason }
	end)
	if not ok then
		if charged then
			pcall(function()
				for _, key in ipairs({ "Weapons", "PityCounter", "PityLegendary", "Index" }) do
					if profile[key] ~= before[key] then
						DataService:Set(player, key, before[key])
					end
				end
				profile.EquippedWeapon = before.EquippedWeapon
			end)
			pending[player] = nil
			DataService:AddGold(player, price)
		end
		busy[player] = nil
		warn(`ShopService: purchase of {weapon.Id} failed for {player.UserId}: {result}`)
		return false, "Purchase failed. Your Gold was given back."
	end

	local seconds = openingSeconds(profile)
	openingUntil[player] = os.clock() + seconds
	busy[player] = nil
	local this = pending[player]
	task.delay(seconds, function()
		if pending[player] == this then
			finish(player)
		end
	end)
	DataService:Save(player)
	return true, result
end

local function reroll(player: Player, uid: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local item = if typeof(uid) == "string" then profile.Weapons[uid] else nil
	local weapon = item and Weapons.ById[item.id]
	if not weapon then
		return false, "Weapon not found"
	end
	if busy[player] or (openingUntil[player] or 0) > os.clock() then
		return false, "Finish the current opening first"
	end
	local price = Weapons.rerollPrice(weapon.Zone)
	if typeof(profile.Diamonds) ~= "number" or profile.Diamonds < price then
		return false, "Not enough Diamonds"
	end
	DataService:Set(player, "Diamonds", profile.Diamonds - price)
	local tier = forced[player] or ShopService.rollTier(random, 1)
	forced[player] = nil
	rerolls[player] = { uid = uid, tier = tier }
	DataService:Save(player)
	return true, { uid = uid, weaponId = weapon.Id, rarity = tier, oldRarity = item.rarity, cost = price, reroll = true }
end

local function rerollChoice(player: Player, uid: any, keepNew: any): (boolean, any)
	local pending = rerolls[player]
	if not pending or pending.uid ~= uid or typeof(keepNew) ~= "boolean" then
		return false, "Nothing to choose"
	end
	rerolls[player] = nil
	local profile = DataService:Get(player)
	local item = profile and profile.Weapons[pending.uid]
	if not item then
		return false, "Weapon not found"
	end
	if keepNew and pending.tier ~= item.rarity then
		local owned = table.clone(profile.Weapons)
		local changed = table.clone(item)
		changed.rarity = pending.tier
		owned[pending.uid] = changed
		DataService:Set(player, "Weapons", owned)
		local best = profile.Index[item.id]
		if typeof(best) ~= "number" or best < pending.tier then
			local index = table.clone(profile.Index)
			index[item.id] = pending.tier
			DataService:Set(player, "Index", index)
		end
		if profile.EquippedWeapon == pending.uid then
			WeaponService:Equip(player, pending.uid) -- the Tool gets its new rarity look
		end
		DataService:Save(player)
	end
	return true, if keepNew then pending.tier else item.rarity
end

-- Admin (AdminService): the next purchase of this player gets this tier.
function ShopService:ForceNext(player: Player, tier: number?)
	forced[player] = tier
end

function ShopService:IsOpening(player: Player): boolean
	return (openingUntil[player] or 0) > os.clock()
end

function ShopService:Init()
	Net.handle("BuyWeapon", buy, Weapons.BUY_INTERVAL)
	Net.handle("RerollWeapon", reroll, Weapons.BUY_INTERVAL)
	Net.handle("RerollChoice", rerollChoice, 0.2)
	-- the client's reveal is showing: the next purchase is allowed and the deferred messages go out
	Net.handle("OpeningDone", function(player: Player)
		if pending[player] or openingUntil[player] then
			finish(player)
		end
	end, 0.2)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		openingUntil[player] = nil
		pending[player] = nil
		forced[player] = nil
		rerolls[player] = nil
	end)
end

return ShopService
