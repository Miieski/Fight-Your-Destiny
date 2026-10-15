--!strict
-- Weapon shop (docs/weapon_shop_brief.txt part 3) and armor shop (owner 2026-10-15: "a shop for Armors too, same as
-- the weapon shop"). Net.request("BuyWeapon", weaponId) / Net.request("BuyArmor", armorId):
--   1. validates (known item, its zone unlocked, no opening running, rate limit, enough Gold; armor: storage not full),
--   2. takes the Gold, 3. rolls the rarity (shop odds + pity, Config/WeaponRarities; the armor shop has its own pity
--   counters, Config/Armor PITY_KEYS), 4. stores the item under a new GUID, marks the Index, 5. saves, then answers
--   true, { uid, weaponId | armorId, kind = "Weapon" | "Armor", rarity, pity, pityReason? }.
-- A first weapon / the first piece of an empty armor slot is equipped when the opening ends.
-- The roll is final when the server answers; the client's case opening only shows it. Anything that would
-- spoil the reel (the "Obtained" toast, the server-wide announcement, the auto-equip of a first weapon) waits
-- until the opening ends: Net.send("OpeningDone") from the client, or the opening time running out.
-- If anything fails after the Gold was taken, every change is undone and the Gold is given back.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Armor = require(ReplicatedStorage.GameSystem.Config.Armor)
local Net = require(ReplicatedStorage.GameSystem.Net)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local WeaponRarities = require(ReplicatedStorage.GameSystem.Config.WeaponRarities)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local DataService = require(script.Parent.DataService)
local WeaponService = require(script.Parent.WeaponService)
local RewardService = require(script.Parent.RewardService)

local ShopService = { Priority = 5 }

type Pending = { kind: string, id: string, tier: number, uid: string, equip: boolean }

-- What each shop sells. store = the profile key of the owned items, pity = Config/WeaponRarities Pity key -> profile key.
type Kind = { name: string, label: string, idField: string, store: string, pity: { [string]: string }, interval: number }
local WEAPON: Kind = { name = "Weapon", label = "weapon", idField = "weaponId", store = "Weapons", pity = { PityCounter = "PityCounter", PityLegendary = "PityLegendary" }, interval = Weapons.BUY_INTERVAL }
local ARMOR: Kind = { name = "Armor", label = "armor piece", idField = "armorId", store = "Armor", pity = Armor.PITY_KEYS, interval = Armor.BUY_INTERVAL }

local function lookup(kind: Kind, id: any): any
	if typeof(id) ~= "string" then
		return nil
	end
	return if kind == ARMOR then Armor.ById[id] else Weapons.ById[id]
end

local function priceOf(kind: Kind, item: any): number
	return if kind == ARMOR then Armor.price(item.Zone) else Weapons.price(item.Zone)
end

local function iconOf(kind: Kind, item: any): string
	return if kind == ARMOR then Armor.SLOT_ICONS[item.Slot] else item.Icon or item.Category
end

local function count(map: { [any]: any }?): number
	local n = 0
	for _ in pairs(map or {}) do
		n += 1
	end
	return n
end

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

local function nameFor(viewer: Player, kind: Kind, id: string): string
	local item = lookup(kind, id)
	local profile = DataService:Get(viewer)
	-- never reveal a locked item's name, not even through someone else's announcement
	if item and profile and profile.Zones[item.ZoneId] then
		return item.Name
	end
	return "mystery " .. kind.label
end

local function announce(player: Player, kind: Kind, id: string, tier: number)
	local now = os.clock()
	if tier < WeaponRarities.ANNOUNCE_FROM or now - lastAnnounce < WeaponRarities.ANNOUNCE_COOLDOWN then
		return
	end
	lastAnnounce = now
	local rarity = WeaponRarities.get(tier)
	for _, viewer in ipairs(Players:GetPlayers()) do
		if viewer ~= player then
			Net.fire(viewer, "Notify", { Kind = "loot", Text = `{player.DisplayName} opened a {rarity.Name} {nameFor(viewer, kind, id)}!`, Rarity = tier })
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
	local kind = if done.kind == ARMOR.name then ARMOR else WEAPON
	local rarity = WeaponRarities.get(done.tier)
	local item = lookup(kind, done.id)
	if not item then
		return
	end
	Net.fire(player, "Notify", { Kind = "loot", Text = `Obtained {rarity.Name} {item.Name}`, Rarity = done.tier, Icon = iconOf(kind, item) })
	if done.equip then
		local profile = DataService:Get(player)
		if kind == WEAPON then
			if profile and profile.EquippedWeapon == done.uid and profile.Weapons[done.uid] then
				WeaponService:Equip(player, done.uid)
			end
		elseif profile and profile.Armor[done.uid] and Armor.equipped(profile)[item.Slot] == nil then
			-- the slot is still empty: the piece goes in now (not at purchase, where the new look and Max HP
			-- would show the rarity during the spin)
			local equipped = table.clone(profile.EquippedArmor or {})
			equipped[item.Slot] = done.uid
			DataService:Set(player, "EquippedArmor", equipped)
		end
	end
	announce(player, kind, done.id, done.tier)
end

local function buy(player: Player, kind: Kind, itemId: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local item = lookup(kind, itemId)
	if not item then
		return false, "Unknown " .. kind.label
	end
	if not profile.Zones[item.ZoneId] then
		return false, `This {kind.label}'s zone is locked. {Zones.HIDDEN_REQUIREMENT}`
	end
	if busy[player] or (openingUntil[player] or 0) > os.clock() then
		return false, "Finish the current opening first"
	end
	if kind == ARMOR and count(profile.Armor) >= Armor.Storage then
		return false, "Armor storage full: sell some pieces first"
	end
	local price = priceOf(kind, item)
	if typeof(profile.Gold) ~= "number" or profile.Gold < price then
		return false, "Not enough Gold"
	end

	-- From here to the item's creation nothing yields, so two requests can never both pass the checks.
	busy[player] = true
	local charged = false
	-- what the purchase changes, to put everything back if it fails half-way (never a free item)
	local restore = { kind.store, kind.pity.PityCounter, kind.pity.PityLegendary, "Index" }
	local before: { [string]: any } = {
		EquippedWeapon = profile.EquippedWeapon,
	}
	for _, key in ipairs(restore) do
		before[key] = profile[key]
	end
	local ok, result = pcall(function()
		DataService:Set(player, "Gold", profile.Gold - price)
		charged = true
		local counters = { PityCounter = profile[kind.pity.PityCounter] or 0, PityLegendary = profile[kind.pity.PityLegendary] or 0 }
		local tier, nextCounters, pityReason = ShopService.roll(random, counters, forced[player])
		forced[player] = nil
		local uid = HttpService:GenerateGUID(false)
		local owned = table.clone(profile[kind.store])
		owned[uid] = if kind == ARMOR then { id = item.Id, rarity = tier, locked = false } else { id = item.Id, rarity = tier }
		DataService:Set(player, kind.store, owned)
		local pity = {}
		for key, value in pairs(nextCounters) do
			DataService:Set(player, kind.pity[key], value)
			pity[kind.pity[key]] = value
		end
		local best = profile.Index[item.Id]
		if typeof(best) ~= "number" or best < tier then
			local index = table.clone(profile.Index)
			index[item.Id] = tier -- best rarity owned (docs/menu_systems_brief.txt D3)
			DataService:Set(player, "Index", index)
		end
		-- a first weapon is equipped in the saved profile right away (so leaving mid-opening keeps it equipped);
		-- the client is told when the opening ends. A piece for an empty armor slot is equipped when the opening
		-- ends (finish), because the worn look and Max HP change at once.
		local equip = false
		if kind == WEAPON then
			equip = not (profile.EquippedWeapon ~= nil and owned[profile.EquippedWeapon] ~= nil)
			if equip then
				profile.EquippedWeapon = uid
			end
		else
			equip = Armor.equipped(profile)[item.Slot] == nil
		end
		pending[player] = { kind = kind.name, id = item.Id, tier = tier, uid = uid, equip = equip }
		local reply = { uid = uid, kind = kind.name, rarity = tier, pity = pity, pityReason = pityReason, equip = equip }
		reply[kind.idField] = item.Id
		return reply
	end)
	if not ok then
		if charged then
			pcall(function()
				for _, key in ipairs(restore) do
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
		warn(`ShopService: purchase of {item.Id} failed for {player.UserId}: {result}`)
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
	if kind == WEAPON then
		RewardService.progress(player, "BuyWeapon", 1)
	end
	return true, result
end

-- Admin (AdminService): the next purchase of this player gets this tier.
function ShopService:ForceNext(player: Player, tier: number?)
	forced[player] = tier
end

function ShopService:IsOpening(player: Player): boolean
	return (openingUntil[player] or 0) > os.clock()
end

function ShopService:Init()
	Net.handle("BuyWeapon", function(player: Player, weaponId: any)
		return buy(player, WEAPON, weaponId)
	end, WEAPON.interval)
	Net.handle("BuyArmor", function(player: Player, armorId: any)
		return buy(player, ARMOR, armorId)
	end, ARMOR.interval)
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
	end)
end

return ShopService
