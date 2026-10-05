--!strict
-- Armor (docs/menu_systems_brief.txt C1, C3). Requests, all validated:
--   Net.request("EquipArmor", uid)        the piece goes to its slot; the old piece goes back to the inventory
--   Net.request("UnequipArmor", slot)     "Helmet" | "Chest" | "Legs" | "All"
--   Net.request("EquipBestArmor")         best score per slot = pieceHP x (1 + Defense / 100) in the CURRENT zone
--   Net.request("LockArmor", uid, bool), Net.request("SellArmor", uid)   (a locked or equipped piece is not sold)
-- ArmorService:GiveArmor (loot, admin): storage 100; a piece that drops while full is sold at once (toast).
-- The worn pieces are listed in the player attribute "ArmorLook" ("Helmet=id:tier;Chest=id:tier;Legs=id:tier")
-- for the client-side visuals (GameClient/Controllers/ArmorVisualsController, Util/ArmorLook).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Armor = require(ReplicatedStorage.GameSystem.Config.Armor)
local ArmorLook = require(ReplicatedStorage.GameSystem.Util.ArmorLook)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local DataService = require(script.Parent.DataService)

local ArmorService = { Priority = 5 }

local function count(map: { [any]: any }?): number
	local n = 0
	for _ in pairs(map or {}) do
		n += 1
	end
	return n
end

function ArmorService:UpdateLook(player: Player)
	local profile = DataService:Get(player)
	local items = {}
	if profile then
		for slot, item in pairs(Armor.equipped(profile)) do
			items[slot] = { id = item.id, tier = item.rarity }
		end
	end
	player:SetAttribute("ArmorLook", ArmorLook.encode(items))
end

local function setEquipped(player: Player, equipped: { [string]: string })
	DataService:Set(player, "EquippedArmor", equipped)
	ArmorService:UpdateLook(player)
end

local function markIndex(player: Player, profile: { [string]: any }, id: string, tier: number)
	local best = profile.Index[id]
	if typeof(best) ~= "number" or best < tier then
		local index = table.clone(profile.Index)
		index[id] = tier
		DataService:Set(player, "Index", index)
	end
end

local function equip(player: Player, uid: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local item = if typeof(uid) == "string" then profile.Armor[uid] else nil
	local piece = item and Armor.ById[item.id]
	if not piece then
		return false, "Armor not found"
	end
	local equipped = table.clone(profile.EquippedArmor or {})
	equipped[piece.Slot] = uid
	setEquipped(player, equipped)
	return true, equipped
end

local function unequip(player: Player, slot: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	if slot == "All" then
		setEquipped(player, {})
		return true, {}
	end
	if typeof(slot) ~= "string" or not Armor.SlotShare[slot] then
		return false, "Bad request"
	end
	local equipped = table.clone(profile.EquippedArmor or {})
	if not equipped[slot] then
		return false, "Nothing equipped there"
	end
	equipped[slot] = nil
	setEquipped(player, equipped)
	return true, equipped
end

-- The best piece per slot for this zone (ties: rarer, higher zone).
function ArmorService.best(profile: { [string]: any }, zoneId: string?): { [string]: string }
	local best: { [string]: { uid: string, score: number, rarity: number, zone: number } } = {}
	for uid, item in pairs(profile.Armor or {}) do
		local piece = Armor.ById[item.id]
		if piece then
			local score = Armor.score(item.id, item.rarity, zoneId)
			local current = best[piece.Slot]
			if not current or score > current.score or (score == current.score and (item.rarity > current.rarity or (item.rarity == current.rarity and (piece.Zone > current.zone or (piece.Zone == current.zone and uid < current.uid))))) then
				best[piece.Slot] = { uid = uid, score = score, rarity = item.rarity, zone = piece.Zone }
			end
		end
	end
	local out = {}
	for slot, entry in pairs(best) do
		out[slot] = entry.uid
	end
	return out
end

local function equipBest(player: Player): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local equipped = ArmorService.best(profile, player:GetAttribute("CurrentZone"))
	if next(equipped) == nil then
		return false, "You have no armor yet"
	end
	setEquipped(player, equipped)
	return true, equipped
end

local function lock(player: Player, uid: any, locked: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	if typeof(uid) ~= "string" or not profile.Armor[uid] or typeof(locked) ~= "boolean" then
		return false, "Bad request"
	end
	local owned = table.clone(profile.Armor)
	local item = table.clone(owned[uid])
	item.locked = locked
	owned[uid] = item
	DataService:Set(player, "Armor", owned)
	return true, locked
end

local function sell(player: Player, uid: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local item = if typeof(uid) == "string" then profile.Armor[uid] else nil
	if not item or not Armor.ById[item.id] then
		return false, "Armor not found"
	end
	if item.locked then
		return false, "This piece is locked"
	end
	for _, equippedUid in pairs(profile.EquippedArmor or {}) do
		if equippedUid == uid then
			return false, "Unequip it first"
		end
	end
	local gold = Armor.sellValue(item.id, item.rarity)
	local owned = table.clone(profile.Armor)
	owned[uid] = nil
	DataService:Set(player, "Armor", owned)
	DataService:AddGold(player, gold)
	DataService:Save(player)
	return true, { gold = gold }
end

-- Loot / admin: a new piece. Full storage -> sold at once for Gold (with a toast). Returns the uid or nil.
function ArmorService:GiveArmor(player: Player, id: string, tier: number, quiet: boolean?): string?
	local profile = DataService:Get(player)
	local piece = Armor.ById[id]
	if not profile or not piece then
		return nil
	end
	tier = math.clamp(math.floor(tier), 1, #Rarities.List)
	local name = `{Rarities.get(tier).Name} {piece.Name}`
	if count(profile.Armor) >= Armor.Storage then
		local gold = Armor.sellValue(id, tier)
		DataService:AddGold(player, gold)
		Net.fire(player, "Notify", { Kind = "info", Text = `Armor storage full: {name} sold for {Format.number(gold)} Gold`, Icon = Armor.SLOT_ICONS[piece.Slot] })
		return nil
	end
	local uid = HttpService:GenerateGUID(false)
	local owned = table.clone(profile.Armor)
	owned[uid] = { id = id, rarity = tier, locked = false }
	DataService:Set(player, "Armor", owned)
	markIndex(player, profile, id, tier)
	if not quiet then
		Net.fire(player, "Notify", { Kind = "loot", Text = `Obtained {name}`, Rarity = tier, Icon = Armor.SLOT_ICONS[piece.Slot] })
	end
	return uid
end

function ArmorService:Init()
	Net.handle("EquipArmor", equip, 0.1)
	Net.handle("UnequipArmor", unequip, 0.1)
	Net.handle("EquipBestArmor", equipBest, 0.5)
	Net.handle("LockArmor", lock, 0.1)
	Net.handle("SellArmor", sell, 0.1)
	DataService.Loaded:Connect(function(player: Player)
		ArmorService:UpdateLook(player)
	end)
	-- profiles loaded before this service started listening (Studio play solo)
	for _, player in ipairs(Players:GetPlayers()) do
		if DataService:Get(player) then
			ArmorService:UpdateLook(player)
		end
	end
	DataService.Changed:Connect(function(player: Player, key: string)
		if key == "Armor" or key == "EquippedArmor" then
			ArmorService:UpdateLook(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("ArmorLook", nil)
	end)
end

return ArmorService
