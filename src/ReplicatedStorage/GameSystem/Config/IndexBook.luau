--!strict
-- The Index catalog (docs/menu_systems_brief.txt D3): every collectable entry by tab and zone, discovery and the
-- rewards. profile.Index = { [entryId] = best rarity tier } (enemies: 1; old weapon entries `true` = discovered),
-- profile.IndexClaimed = { [rewardId] = true }. Shared by IndexService (claims) and the Index window.
--   Rewards: all entries of a zone in a tab -> 2 + zone Diamonds ("<Tab>:<ZoneId>"); a whole tab -> 100 Diamonds
--   ("<Tab>:All"). The 4 premium pets are listed but not needed for the Pets tab reward (Robux only).
local Armor = require(script.Parent.Armor)
local Enemies = require(script.Parent.Enemies)
local Pets = require(script.Parent.Pets)
local Weapons = require(script.Parent.Weapons)
local Zones = require(script.Parent.Zones)

export type Entry = { Id: string, Name: string, Tab: string, Kind: string, ZoneId: string?, Zone: number, Role: string? }
export type Group = { Key: string, ZoneId: string?, Zone: number, Name: string, Entries: { Entry }, Rewarded: boolean }
export type Reward = { Id: string, Tab: string, ZoneId: string?, Diamonds: number, Have: number, Total: number, Complete: boolean, Claimed: boolean }

local IndexBook = {}

IndexBook.TABS = { "Weapons", "Armor", "Pets", "Enemies" }
IndexBook.TabReward = 100
function IndexBook.zoneReward(zone: number): number
	return 2 + zone
end

IndexBook.Groups = {} :: { [string]: { Group } }
IndexBook.ById = {} :: { [string]: Entry }

local function add(tab: string, group: Group, entry: Entry)
	assert(not IndexBook.ById[entry.Id], "duplicate Index id " .. entry.Id)
	IndexBook.ById[entry.Id] = entry
	table.insert(group.Entries, entry)
end

for _, tab in ipairs(IndexBook.TABS) do
	IndexBook.Groups[tab] = {}
	for _, zone in ipairs(Zones.List) do
		local group: Group = { Key = zone.Id, ZoneId = zone.Id, Zone = zone.Index, Name = zone.Name, Entries = {}, Rewarded = true }
		if tab == "Weapons" then
			for _, weapon in ipairs(Weapons.List) do
				if weapon.ZoneId == zone.Id then
					add(tab, group, { Id = weapon.Id, Name = weapon.Name, Tab = tab, Kind = "weapon", ZoneId = zone.Id, Zone = zone.Index })
				end
			end
		elseif tab == "Armor" then
			for _, slot in ipairs(Armor.SLOTS) do
				local piece = Armor.ById[`{string.lower(zone.Id)}_{string.lower(slot)}`]
				add(tab, group, { Id = piece.Id, Name = piece.Name, Tab = tab, Kind = "armor", ZoneId = zone.Id, Zone = zone.Index, Role = slot })
			end
		elseif tab == "Pets" then
			for _, species in ipairs(Pets.ByZone[zone.Id]) do
				add(tab, group, { Id = species.Id, Name = species.Name, Tab = tab, Kind = "pet", ZoneId = zone.Id, Zone = zone.Index, Role = species.Role })
			end
		else
			for sub = 1, Zones.SUBZONE_COUNT do
				for _, enemy in ipairs(Enemies.BySubZone[Zones.subZoneId(zone.Id, sub)] or {}) do
					add(tab, group, { Id = enemy.Id, Name = enemy.Name, Tab = tab, Kind = "enemy", ZoneId = zone.Id, Zone = zone.Index, Role = "Normal" })
				end
			end
			local room = Enemies.BossRoom[zone.Id]
			if room then
				for _, enemy in ipairs({ room.Mini1, room.Mini2, room.Boss }) do
					add(tab, group, { Id = enemy.Id, Name = enemy.Name, Tab = tab, Kind = "enemy", ZoneId = zone.Id, Zone = zone.Index, Role = enemy.Role })
				end
			end
		end
		table.insert(IndexBook.Groups[tab], group)
	end
	if tab == "Pets" then
		local group: Group = { Key = "Premium", ZoneId = nil, Zone = 0, Name = "Premium", Entries = {}, Rewarded = false }
		for _, species in ipairs(Pets.Premium) do
			add(tab, group, { Id = species.Id, Name = species.Name, Tab = tab, Kind = "pet", ZoneId = nil, Zone = 0, Role = "Premium" })
		end
		table.insert(IndexBook.Groups[tab], group)
	end
end

-- Best rarity owned (0 = discovered without a rarity, nil = not discovered).
function IndexBook.best(index: { [string]: any }?, id: string): number?
	local value = index and index[id]
	if typeof(value) == "number" then
		return value
	elseif value == true then
		return 0
	end
	return nil
end

function IndexBook.count(index: { [string]: any }?, entries: { Entry }): number
	local n = 0
	for _, entry in ipairs(entries) do
		if IndexBook.best(index, entry.Id) ~= nil then
			n += 1
		end
	end
	return n
end

-- Entries counted for a tab's progress / reward (the premium group is not).
function IndexBook.tabEntries(tab: string): { Entry }
	local list = {}
	for _, group in ipairs(IndexBook.Groups[tab] or {}) do
		if group.Rewarded then
			for _, entry in ipairs(group.Entries) do
				table.insert(list, entry)
			end
		end
	end
	return list
end

-- Every reward with its state.
function IndexBook.rewards(index: { [string]: any }?, claimed: { [string]: any }?): { Reward }
	local list = {}
	for _, tab in ipairs(IndexBook.TABS) do
		for _, group in ipairs(IndexBook.Groups[tab]) do
			if group.Rewarded then
				local id = `{tab}:{group.Key}`
				local have, total = IndexBook.count(index, group.Entries), #group.Entries
				table.insert(list, { Id = id, Tab = tab, ZoneId = group.ZoneId, Diamonds = IndexBook.zoneReward(group.Zone), Have = have, Total = total, Complete = have >= total, Claimed = claimed ~= nil and claimed[id] == true })
			end
		end
		local entries = IndexBook.tabEntries(tab)
		local id = `{tab}:All`
		local have = IndexBook.count(index, entries)
		table.insert(list, { Id = id, Tab = tab, ZoneId = nil, Diamonds = IndexBook.TabReward, Have = have, Total = #entries, Complete = have >= #entries, Claimed = claimed ~= nil and claimed[id] == true })
	end
	return list
end

function IndexBook.reward(index: { [string]: any }?, claimed: { [string]: any }?, rewardId: string): Reward?
	for _, reward in ipairs(IndexBook.rewards(index, claimed)) do
		if reward.Id == rewardId then
			return reward
		end
	end
	return nil
end

function IndexBook.claimable(index: { [string]: any }?, claimed: { [string]: any }?): number
	local n = 0
	for _, reward in ipairs(IndexBook.rewards(index, claimed)) do
		if reward.Complete and not reward.Claimed then
			n += 1
		end
	end
	return n
end

return IndexBook
