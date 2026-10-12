--!strict
-- Rebirth (DESIGN.md section 4, rules in Config/Rebirth). Net.request("Rebirth") from the Rebirth tab of the Rebirth
-- window: the server checks everything (next Rebirth r <= Max, key of the zone-r boss, Gold >= cost, not in a boss
-- arena, not in a fight), then:
--   Rebirths = r, +3 Rebirth Credits, Gold / weapons / armor / attribute points / eggs / non-premium pets / trophies
--   reset (RebirthService:Wipe), the gates of zone r reset and RedoneSinceRebirth cleared, the player is sent to the
--   start of zone r with a free Common sword of that zone (the starter weapon rule). Reopening zone r's boss room
--   then opens zone r + 1 (ZoneService). Kept: Diamonds, keys, credits and Rebirth Shop upgrades, premium pets,
--   Index, boosts, passes, settings, unlocked zones.
--   RebirthService:Wipe(player) -> premium pets kept   the reset alone (also the admin command wipeForRebirth)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.GameSystem.Config.Attributes)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Rebirth = require(ReplicatedStorage.GameSystem.Config.Rebirth)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local WeaponService = require(script.Parent.WeaponService)
local ZoneService = require(script.Parent.ZoneService)

local RebirthService = { Priority = 6 }

local busy: { [Player]: boolean } = {}

-- The Rebirth reset: Gold, attribute points, weapons, armor, eggs, trophies, non-premium pets and whatever was
-- equipped from them. Returns the number of premium pets kept.
function RebirthService:Wipe(player: Player): number
	local profile = DataService:Get(player)
	if not profile then
		return 0
	end
	DataService:Set(player, "Gold", 0)
	DataService:Set(player, "Attributes", Attributes.empty())
	DataService:Set(player, "Weapons", {})
	DataService:Set(player, "EquippedWeapon", nil)
	DataService:Set(player, "Armor", {})
	DataService:Set(player, "EquippedArmor", {})
	DataService:Set(player, "Eggs", {})
	DataService:Set(player, "Trophies", {})
	local pets, kept = {}, 0
	for uid, pet in pairs(profile.Pets or {}) do
		if pet.premium then
			pets[uid] = pet
			kept += 1
		end
	end
	DataService:Set(player, "Pets", pets)
	local equipped = {}
	for _, uid in ipairs(profile.EquippedPets or {}) do
		if pets[uid] then
			table.insert(equipped, uid)
		end
	end
	DataService:Set(player, "EquippedPets", equipped)
	WeaponService:Refresh(player)
	return kept
end

local function rebirth(player: Player): (boolean, any)
	if busy[player] then
		return false, "Rebirth already in progress"
	end
	local profile = DataService:Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (profile and humanoid and humanoid.Health > 0) then
		return false, "Not ready yet"
	end
	if player:GetAttribute("ArenaKey") then
		return false, "Leave the boss arena first"
	end
	if ZoneService:InCombat(player) then
		return false, "You can't Rebirth during a fight"
	end
	local status = Rebirth.status(profile)
	if not status.ready then
		return false, status.reason or "Not available"
	end
	local r = status.next
	local zone = status.zone :: Zones.Zone
	busy[player] = true
	-- the zone being redone: its gates close again, and the "redone" marks start over
	local subZones = table.clone(profile.SubZones or {})
	for n = 2, Zones.SUBZONE_COUNT do
		subZones[Zones.subZoneId(zone.Id, n)] = nil
	end
	DataService:Set(player, "SubZones", subZones)
	DataService:Set(player, "RedoneSinceRebirth", {})
	DataService:Set(player, "Rebirths", r)
	DataService:Set(player, "RebirthCredits", math.floor(tonumber(profile.RebirthCredits) or 0) + Rebirth.CreditsPerRebirth)
	RebirthService:Wipe(player)
	-- a fresh start in the zone to redo, with its free Common sword (CombatService starter weapon rule)
	CombatService:EnsureStarterWeapon(player, zone.Id)
	busy[player] = nil
	DataService:Save(player)
	if not ZoneService:TeleportTo(player, zone.Id, 1) then
		ZoneService:ToHub(player)
	end
	return true, { rebirth = r, credits = Rebirth.CreditsPerRebirth, zone = zone.Id }
end

function RebirthService:Init()
	Net.handle("Rebirth", rebirth, 1)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return RebirthService
