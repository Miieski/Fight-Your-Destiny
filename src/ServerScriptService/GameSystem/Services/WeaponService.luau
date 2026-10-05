--!strict
-- The equipped weapon (docs/weapon_shop_brief.txt part 5). Net.request("EquipWeapon", uid) checks that the
-- player owns that copy; the player then holds a clone of ReplicatedStorage.Assets.Weapons.<WeaponId> with
-- the attributes Uid and Rarity and a rarity tint (light from Uncommon, outline from Epic). The Tool is given
-- again after every respawn. No combat logic here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
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

function WeaponService:Init()
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
