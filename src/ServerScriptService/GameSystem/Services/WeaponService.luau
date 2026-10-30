--!strict
-- The equipped weapon (docs/weapon_shop_brief.txt part 5). Net.request("EquipWeapon", uid) checks that the
-- player owns that copy; the player then holds a clone of ReplicatedStorage.Assets.Weapons.<WeaponId> with
-- the attributes Uid and Rarity and a rarity tint (light from Uncommon, outline from Epic). A pair weapon (Config/WeaponMoves
-- Pair: daggers) also gets an off-hand copy inside the Tool, welded to the left hand here so every player sees it: one item
-- everywhere else. The Tool is given again after every respawn. No combat logic here.
-- Net.request("SellWeapon", uid) sells one copy for Weapons.sellValue Gold (not the equipped one).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local WeaponMoves = require(ReplicatedStorage.GameSystem.Config.WeaponMoves)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local DataService = require(script.Parent.DataService)

local WeaponService = { Priority = 4 }

local EQUIP_INTERVAL = 0.3 -- seconds between two EquipWeapon requests
local LIGHT_FROM = 2 -- Uncommon and better: a small light in the rarity color
local OUTLINE_FROM = Rarities.GLOW_FROM -- Epic and better: an outline (Highlight)

local function template(weaponId: string): Tool?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Weapons")
	local tool = folder and folder:FindFirstChild(weaponId)
	return if tool and tool:IsA("Tool") then tool else nil
end

local function removeTools(player: Player)
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") } :: { Instance? }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("WeaponId") then
					child:Destroy()
				end
			end
		end
	end
end

local function applyRarity(tool: Tool, tier: number)
	local rarity = Rarities.get(tier)
	tool:SetAttribute("Rarity", rarity.Tier)
	local handle = tool:FindFirstChild("Handle")
	if handle and rarity.Tier >= LIGHT_FROM then
		local light = Instance.new("PointLight")
		light.Name = "RarityLight"
		light.Color = rarity.Color
		light.Range = 4 + rarity.Tier
		light.Brightness = 0.4 + 0.25 * rarity.Tier
		light.Shadows = false
		light.Parent = handle
	end
	if rarity.Tier >= OUTLINE_FROM then
		local outline = Instance.new("Highlight")
		outline.Name = "RarityOutline"
		outline.FillTransparency = 1
		outline.OutlineColor = rarity.Color
		outline.OutlineTransparency = 0.15
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = tool
	end
end

-- The left-hand copy of a pair: the Handle, turned half a turn around the blade (a mesh cannot be mirrored, this puts the
-- same side of the blade outward). Its attachments get their own names: the Tool's Tip / Base stay the right hand's.
local function addOffHand(tool: Tool, character: Model)
	local moves = WeaponMoves.Moves[tool:GetAttribute("Category")]
	local handle = tool:FindFirstChild("Handle")
	local hand = character:FindFirstChild("LeftHand")
	local grip = hand and hand:FindFirstChild("LeftGripAttachment")
	if not (moves and moves.Pair and handle and hand and grip and grip:IsA("Attachment")) then
		return
	end
	local off = handle:Clone() :: BasePart
	off.Name = "OffHand"
	off.Massless = true
	off.CanCollide = false
	for _, child in ipairs(off:GetChildren()) do
		if child.Name == "TipAttachment" or child.Name == "BaseAttachment" then
			child.Name = "Off" .. child.Name
		elseif child:IsA("PointLight") then
			child:Destroy()
		end
	end
	local weld = Instance.new("Weld")
	weld.Name = "LeftGrip"
	weld.Part0 = hand :: BasePart
	weld.Part1 = off
	weld.C0 = grip.CFrame
	weld.C1 = tool.Grip * CFrame.Angles(0, math.pi, 0)
	weld.Parent = off
	off.Parent = tool
end

-- Gives the player a fresh copy of the equipped weapon (removes the old one).
function WeaponService:Give(player: Player)
	removeTools(player)
	local profile = DataService:Get(player)
	local character = player.Character
	local uid = profile and profile.EquippedWeapon
	local item = uid and profile.Weapons[uid]
	if not (item and character) then
		return
	end
	local source = template(item.id)
	if not source then
		warn(`WeaponService: no Tool for {item.id} in ReplicatedStorage.Assets.Weapons`)
		return
	end
	local tool = source:Clone()
	tool:SetAttribute("Uid", uid)
	tool.CanBeDropped = false
	applyRarity(tool, item.rarity)
	-- the Roblox backpack bar is hidden: the weapon goes straight into the hand
	tool.Parent = character
	addOffHand(tool, character)
end

-- Equips one owned copy (uid) or nothing (uid = nil). Returns ok, message.
function WeaponService:Equip(player: Player, uid: string?): (boolean, string?)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	if uid ~= nil then
		local item = profile.Weapons[uid]
		if not (item and Weapons.ById[item.id]) then
			return false, "You don't own this weapon"
		end
	end
	DataService:Set(player, "EquippedWeapon", uid)
	WeaponService:Give(player)
	return true, nil
end

-- Drops EquippedWeapon if that copy no longer exists (after a reset), then refreshes the Tool.
function WeaponService:Refresh(player: Player)
	local profile = DataService:Get(player)
	if profile and profile.EquippedWeapon and not profile.Weapons[profile.EquippedWeapon] then
		DataService:Set(player, "EquippedWeapon", nil)
	end
	WeaponService:Give(player)
end

-- Sells one owned copy for Gold (owner 2026-10-13). The equipped weapon cannot be sold.
local function sell(player: Player, uid: any): (boolean, any)
	if typeof(uid) ~= "string" then
		return false, "Bad request"
	end
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local item = profile.Weapons[uid]
	if not (item and Weapons.ById[item.id]) then
		return false, "You don't own this weapon"
	end
	if profile.EquippedWeapon == uid then
		return false, "Equip another weapon first"
	end
	local gold = Weapons.sellValue(item.id, item.rarity)
	local owned = table.clone(profile.Weapons)
	owned[uid] = nil
	DataService:Set(player, "Weapons", owned)
	DataService:AddGold(player, gold)
	DataService:Save(player)
	return true, { gold = gold }
end

-- Several copies at once (Inventory select mode, owner 2026-10-15): Net.request("SellWeapons", { uid, ... }) ->
-- true, { gold, count }. The equipped copy and unknown uids are skipped.
local MAX_BATCH = 300
local function sellMany(player: Player, uids: any): (boolean, any)
	if typeof(uids) ~= "table" or #uids == 0 or #uids > MAX_BATCH then
		return false, "Bad request"
	end
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local owned = table.clone(profile.Weapons)
	local gold, count = 0, 0
	for _, uid in ipairs(uids) do
		local item = if typeof(uid) == "string" then owned[uid] else nil
		if item and Weapons.ById[item.id] and uid ~= profile.EquippedWeapon then
			gold += Weapons.sellValue(item.id, item.rarity)
			owned[uid] = nil
			count += 1
		end
	end
	if count == 0 then
		return false, "Nothing to sell"
	end
	DataService:Set(player, "Weapons", owned)
	DataService:AddGold(player, gold)
	DataService:Save(player)
	return true, { gold = gold, count = count }
end

function WeaponService:Init()
	Net.handle("SellWeapon", sell, 0.1)
	Net.handle("SellWeapons", sellMany, 0.5)
	Net.handle("EquipWeapon", function(player: Player, uid: any)
		if uid ~= nil and typeof(uid) ~= "string" then
			return false, "Bad request"
		end
		return WeaponService:Equip(player, uid)
	end, EQUIP_INTERVAL)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			if character.Parent then
				WeaponService:Give(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	DataService.Loaded:Connect(function(player: Player)
		if player.Character then
			WeaponService:Give(player)
		end
	end)
end

return WeaponService
