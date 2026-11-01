--!strict
-- Rebirth (DESIGN.md section 4, rules in Config/Rebirth). Net.request("Rebirth") from the Rebirth tab of the Rebirth
-- window: the server checks everything (next Rebirth r <= Max, key of the zone-r boss, Gold >= cost, not in a fight),
-- then a staged sequence (Round 8, root cause of the old grey screen in docs/NIGHT_LOG.md):
--   commit   the new values are built on copies, then written in one step (DataService:SetMany, one client patch):
--            Rebirths = r, +3 Rebirth Credits, Gold / weapons / armor / attribute points / eggs / non-premium pets /
--            trophies reset, the gates of zone r reset, a free Common sword of that zone.
--            A failure before this step changes nothing. The request answers right after it.
--   respawn  in the background: out of any boss room, Hub streamed in, a new character on the Hub spawn, the save with
--            retries (nothing waits for it), then Net "RebirthDone" (the client's cover comes off).
-- Zone r + 1 is then bought with zone r's key + Gold (Config/RebirthZoneUnlock). Kept: Diamonds, keys, credits and Rebirth
-- Shop upgrades, premium pets, Index, boosts, passes, settings, unlocked zones.
--   RebirthService:Wipe(player) -> premium pets kept   the reset alone (also the admin command wipeForRebirth)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

-- The reset as new values, on copies: nothing here touches the profile. Returns changes, cleared keys, premium pets kept.
local function planReset(profile: { [string]: any }): ({ [string]: any }, { string }, number)
	local pets, kept = {}, 0
	for uid, pet in pairs(profile.Pets or {}) do
		if pet.premium then
			pets[uid] = pet
			kept += 1
		end
	end
	local equipped = {}
	for _, uid in ipairs(profile.EquippedPets or {}) do
		if pets[uid] then
			table.insert(equipped, uid)
		end
	end
	local changes = {
		Gold = 0,
		Attributes = Attributes.empty(),
		Weapons = {},
		Armor = {},
		EquippedArmor = {},
		Eggs = {},
		Trophies = {},
		Pets = pets,
		EquippedPets = equipped,
	}
	return changes, { "EquippedWeapon" }, kept
end

-- The Rebirth reset: Gold, attribute points, weapons, armor, eggs, trophies, non-premium pets and whatever was
-- equipped from them. Returns the number of premium pets kept.
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
