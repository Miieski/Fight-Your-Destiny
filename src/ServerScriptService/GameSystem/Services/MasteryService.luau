--!strict
-- Weapon mastery and skill trees, server side (Config/WeaponMastery, Config/WeaponSkillTrees). Kept for life: RebirthService never
-- touches these keys. XP adds up in memory and reaches the profile every FLUSH_SECONDS (a patch per hit would be wasteful).
--   Net.request("MasteryUnlock", nodeId) / ("MasteryOpen", category) / ("MasteryEquip", category, { skillId, ... }) / ("MasteryRespec", category)
--   MasteryService:AddXP(player, category, amount), MasteryService:AddKill(player, tier)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local Skills = require(ReplicatedStorage.GameSystem.Config.Skills)
local WeaponMastery = require(ReplicatedStorage.GameSystem.Config.WeaponMastery)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Trees = require(ReplicatedStorage.GameSystem.Config.WeaponSkillTrees)
local DataService = require(script.Parent.DataService)

local MasteryService = { Priority = 5 }

local FLUSH_SECONDS = 3
local pending: { [Player]: { [string]: number } } = {}
local minute: { [Player]: { at: number, xp: number } } = {}

local function setEntry(player: Player, profile: { [string]: any }, category: string, entry: { [string]: any }, extra: { [string]: any }?)
	local all = table.clone(profile.Mastery or {})
	all[category] = entry
	local changes = extra or {}
	changes.Mastery = all
	DataService:SetMany(player, changes)
end

local function copyEntry(profile: { [string]: any }, category: string): { [string]: any }
	local entry = table.clone(WeaponMastery.entry(profile, category))
	entry.XP = entry.XP or 0
	entry.Nodes = table.clone(entry.Nodes or {})
	entry.Free = table.clone(entry.Free or {})
	return entry
end

local function refreshAura(player: Player)
	local profile = DataService:Get(player)
	local item = profile and profile.EquippedWeapon and profile.Weapons[profile.EquippedWeapon]
	local weapon = item and Weapons.ById[item.id]
	local bonus = if profile and weapon then WeaponMastery.bonuses(profile, weapon.Category) else {}
	player:SetAttribute("MasteryAura", if bonus.Aura and weapon then weapon.Category else nil)
end

function MasteryService:AddXP(player: Player, category: string, amount: number)
	local now = os.clock()
	local window = minute[player]
	if not window or now - window.at >= 60 then
		window = { at = now, xp = 0 }
		minute[player] = window
	end
	local allowed = math.min(amount, WeaponMastery.XP.PerMinuteCap - window.xp)
	if allowed <= 0 then
		return
	end
	window.xp += allowed
	local list = pending[player]
	if not list then
		list = {}
		pending[player] = list
	end
	list[category] = (list[category] or 0) + allowed
end

-- A kill: its XP goes to the type of the weapon in hand.
function MasteryService:AddKill(player: Player, tier: string?)
	local profile = DataService:Get(player)
	local item = profile and profile.EquippedWeapon and profile.Weapons[profile.EquippedWeapon]
	local weapon = item and Weapons.ById[item.id]
	if weapon then
		local xp = WeaponMastery.XP
		MasteryService:AddXP(player, weapon.Category, if tier == "boss" then xp.Boss elseif tier == "mini" then xp.MiniBoss else xp.Normal)
	end
end

local function flush(player: Player)
	local list = pending[player]
	local profile = DataService:Get(player)
	if not (list and profile) then
		return
	end
	pending[player] = nil
	local all = table.clone(profile.Mastery or {})
	for category, xp in pairs(list) do
		local entry = copyEntry(profile, category)
		local before = WeaponMastery.levelOf(entry.XP)
		entry.XP += xp
		all[category] = entry
		local after = WeaponMastery.levelOf(entry.XP)
		if after > before then
			Net.fire(player, "Notify", { Kind = "reward", Text = `{category} mastery level {after}!`, Icon = category })
		end
	end
	DataService:Set(player, "Mastery", all)
end

local function unlock(player: Player, nodeId: any): (boolean, any)
	local profile = DataService:Get(player)
	local node = if typeof(nodeId) == "string" then Trees.Nodes[nodeId] else nil
	if not (profile and node) then
		return false, "Bad request"
	end
	local category = node.Category
	local entry = copyEntry(profile, category)
	if entry.Nodes[nodeId] then
		return false, "Already unlocked"
	end
	if not WeaponMastery.available(entry, node) then
		return false, "Unlock what leads to it first"
	end
	local free = (profile.FreePicks or 0) > 0
	if not free then
		if not WeaponMastery.isOpen(profile, category) then
			return false, "Open this tree first"
		end
		if WeaponMastery.pointsLeft(profile, category) < node.Cost then
			return false, "Not enough mastery points"
		end
	end
	entry.Nodes[nodeId] = true
	local extra: { [string]: any } = {}
	if free then
		entry.Free[nodeId] = true
		extra.FreePicks = profile.FreePicks - 1
		if (profile.FreePickAt or 0) == 0 then
			extra.FreePickAt = os.time()
		end
	end
	setEntry(player, profile, category, entry, extra)
	refreshAura(player)
	DataService:SaveSoon(player, 3, 3)
	return true, { Free = free }
end

local function open(player: Player, category: any): (boolean, any)
	local profile = DataService:Get(player)
	local price = if typeof(category) == "string" then WeaponMastery.OpenPrice[category] else nil
	if not (profile and price) then
		return false, "Bad request"
	end
	if WeaponMastery.isOpen(profile, category) then
		return false, "Already open"
	end
	if (profile.Gold or 0) < price then
		return false, "Not enough Gold"
	end
	local entry = copyEntry(profile, category)
	entry.Open = true
	setEntry(player, profile, category, entry, { Gold = profile.Gold - price })
	DataService:SaveSoon(player, 3, 3)
	return true, { Cost = price }
end

local function equip(player: Player, category: any, list: any): (boolean, any)
	local profile = DataService:Get(player)
	if not (profile and typeof(category) == "string" and Trees.ByCategory[category] and typeof(list) == "table") then
		return false, "Bad request"
	end
	if #list > WeaponMastery.MaxEquipped then
		return false, `At most {WeaponMastery.MaxEquipped} special attacks`
	end
	local seen, clean = {}, {}
	for _, id in ipairs(list) do
		local skill = if typeof(id) == "string" then Skills.ById[id] else nil
		if not (skill and skill.Move and skill.Category == category) or seen[id] or not WeaponMastery.hasSkill(profile, category, id) then
			return false, "Not unlocked"
		end
		seen[id] = true
		table.insert(clean, id)
	end
	local equipped = table.clone(profile.EquippedSkills or {})
	equipped[category] = clean
	DataService:Set(player, "EquippedSkills", equipped)
	return true, clean
end

local function respec(player: Player, category: any): (boolean, any)
	local profile = DataService:Get(player)
	if not (profile and typeof(category) == "string" and Trees.ByCategory[category]) then
		return false, "Bad request"
	end
	local entry = copyEntry(profile, category)
	if next(entry.Nodes) == nil then
		return false, "Nothing to reset"
	end
	local at = profile.FreePickAt or 0
	local freeWindow = at > 0 and os.time() - at < WeaponMastery.FreeRespecSeconds
	local cost = if freeWindow then 0 else WeaponMastery.RespecGold
	if (profile.Gold or 0) < cost then
		return false, "Not enough Gold"
	end
	local picks = 0
	for _ in pairs(entry.Free) do
		picks += 1
	end
	entry.Nodes, entry.Free = {}, {}
	if category ~= WeaponMastery.StartTree and picks > 0 then
		entry.Open = true -- a free pick opened this tree: it stays open
	end
	local equipped = table.clone(profile.EquippedSkills or {})
	equipped[category] = {}
	setEntry(player, profile, category, entry, { Gold = profile.Gold - cost, FreePicks = (profile.FreePicks or 0) + picks, EquippedSkills = equipped })
	refreshAura(player)
	DataService:SaveSoon(player, 3, 3)
	return true, { Cost = cost, Picks = picks }
end

function MasteryService:Init()
	Net.handle("MasteryUnlock", unlock, 0.15)
	Net.handle("MasteryOpen", open, 0.5)
	Net.handle("MasteryEquip", equip, 0.15)
	Net.handle("MasteryRespec", respec, 0.5)
	DataService.Loaded:Connect(refreshAura)
	DataService.Changed:Connect(function(player: Player, key: string)
		if key == "EquippedWeapon" or key == "Weapons" then
			refreshAura(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		flush(player)
		pending[player] = nil
		minute[player] = nil
	end)
end

function MasteryService:Start()
	while true do
		task.wait(FLUSH_SECONDS)
		for player in pairs(pending) do
			flush(player)
		end
	end
end

return MasteryService
