--!strict
-- Rebirth (DESIGN.md section 4, rules in Config/Rebirth). Net.request("Rebirth") from the Rebirth tab of the Rebirth
-- window: the server checks everything (next Rebirth r <= Max, key of the zone-r boss, Gold >= cost, not in a fight),
-- then a staged sequence (Round 8, root cause of the old grey screen in docs/NIGHT_LOG.md):
--   commit   the new values are built on copies, then written in one step (DataService:SetMany, one client patch):
--            Rebirths = r, +3 Rebirth Credits, Gold / unprotected weapons, armor and pets / attribute points / eggs /
--            trophies reset, the gates of zone r reset, a free Common sword of that zone.
--            A failure before this step changes nothing. The request answers right after it.
--   respawn  in the background: out of any boss room, Hub streamed in, a new character on the Hub spawn, the save with
--            retries (nothing waits for it), then Net "RebirthDone" (the client's cover comes off).
-- Zone r + 1 is then bought with zone r's key + Gold (Config/RebirthZoneUnlock). Kept: Diamonds, keys, credits and Rebirth
-- Shop upgrades, protected items (Config/RebirthProtection), Index, boosts, passes, settings, unlocked zones.
--   RebirthService:Wipe(player) -> protected items kept   the reset alone (also the admin command wipeForRebirth)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.GameSystem.Config.Attributes)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Rebirth = require(ReplicatedStorage.GameSystem.Config.Rebirth)
local RebirthProtection = require(ReplicatedStorage.GameSystem.Config.RebirthProtection)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local WeaponService = require(script.Parent.WeaponService)
local ZoneService = require(script.Parent.ZoneService)

local RebirthService = { Priority = 6 }

local busy: { [Player]: boolean } = {}

local function protectedOf(items: { [string]: any }?): ({ [string]: any }, number)
	local kept, count = {}, 0
	for uid, item in pairs(items or {}) do
		if item.Protected then
			kept[uid] = item
			count += 1
		end
	end
	return kept, count
end

-- The reset as new values, on copies: nothing here touches the profile. Returns changes, cleared keys, protected items kept.
local function planReset(profile: { [string]: any }): ({ [string]: any }, { string }, number)
	local weapons, keptWeapons = protectedOf(profile.Weapons)
	local armor, keptArmor = protectedOf(profile.Armor)
	local pets, keptPets = protectedOf(profile.Pets)
	local keepEquipped = RebirthProtection.KeepEquippedState
	local equippedPets = {}
	local equippedArmor = {}
	for _, uid in ipairs(profile.EquippedPets or {}) do
		if keepEquipped and pets[uid] then
			table.insert(equippedPets, uid)
		end
	end
	for slot, uid in pairs(profile.EquippedArmor or {}) do
		if keepEquipped and armor[uid] then
			equippedArmor[slot] = uid
		end
	end
	local changes = {
		Gold = 0,
		Attributes = Attributes.empty(),
		Weapons = weapons,
		Armor = armor,
		EquippedArmor = equippedArmor,
		Eggs = {},
		Trophies = {},
		Pets = pets,
		EquippedPets = equippedPets,
	}
	local keepsWeapon = keepEquipped and profile.EquippedWeapon ~= nil and weapons[profile.EquippedWeapon] ~= nil
	return changes, if keepsWeapon then {} else { "EquippedWeapon" }, keptWeapons + keptArmor + keptPets
end

-- After the commit: a protected weapon in hand when the equipped one went (the starter sword covers "no weapon at all").
local function equipSomething(player: Player)
	local profile = DataService:Get(player)
	if profile and not profile.EquippedWeapon then
		local best, bestRarity = nil, -1
		for uid, item in pairs(profile.Weapons or {}) do
			if (item.rarity or 1) > bestRarity then
				best, bestRarity = uid, item.rarity or 1
			end
		end
		if best then
			WeaponService:Equip(player, best)
		end
	end
end

-- The Rebirth reset: Gold, attribute points, eggs, trophies, the unprotected weapons, armor and pets. Returns the number of
-- protected items kept.
function RebirthService:Wipe(player: Player): number
	local profile = DataService:Get(player)
	if not profile then
		return 0
	end
	local changes, cleared, kept = planReset(profile)
	DataService:SetMany(player, changes, cleared)
	WeaponService:Refresh(player)
	return kept
end

-- In the background once the Rebirth is committed: back in the Hub, whatever happens.
local function finish(player: Player, result: { [string]: any })
	local settings = Rebirth.Transition
	local ok, err = pcall(function()
		ZoneService:RespawnInHub(player, settings.StreamTimeout)
	end)
	if not ok then
		warn(`RebirthService: respawn failed for {player.UserId}: {err}`)
		pcall(function()
			ZoneService:ToHub(player)
		end)
	end
	DataService:SaveSoon(player, settings.SaveRetries, settings.SaveRetrySeconds)
	busy[player] = nil
	if RunService:IsStudio() and player:GetAttribute("RebirthTestStall") then
		return -- test of the client watchdog: the end of the sequence never arrives
	end
	if player.Parent then
		Net.fire(player, "RebirthDone", { Ok = ok, Rebirth = result.rebirth, Credits = result.credits })
	end
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
	if ZoneService:InCombat(player) then
		return false, "You can't Rebirth during a fight"
	end
	local status = Rebirth.status(profile)
	if not status.ready then
		return false, status.reason or "Not available"
	end
	local r = status.next
	local zone = status.zone :: Zones.Zone
	-- the plan: copies only, an error here leaves the profile as it was
	local subZones = table.clone(profile.SubZones or {})
	for n = 2, Zones.SUBZONE_COUNT do -- the zone being redone: its gates close again, the "redone" marks start over
		subZones[Zones.subZoneId(zone.Id, n)] = nil
	end
	local changes, cleared = planReset(profile)
	changes.SubZones = subZones
	changes.Rebirths = r
	changes.RebirthCredits = math.floor(tonumber(profile.RebirthCredits) or 0) + Rebirth.CreditsPerRebirth
	-- the commit: one step, no yield
	busy[player] = true
	DataService:SetMany(player, changes, cleared)
	local result = { rebirth = r, credits = Rebirth.CreditsPerRebirth, zone = zone.Id }
	-- the fresh start after the commit; an error here must not stop the respawn
	local ok, err = pcall(function()
		WeaponService:Refresh(player)
		CombatService:EnsureStarterWeapon(player, zone.Id) -- a free Common sword of the zone to redo
		equipSomething(player)
	end)
	if not ok then
		warn(`RebirthService: fresh start failed for {player.UserId}: {err}`)
	end
	task.spawn(finish, player, result)
	return true, result
end

function RebirthService:Init()
	Net.handle("Rebirth", rebirth, 1)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return RebirthService
