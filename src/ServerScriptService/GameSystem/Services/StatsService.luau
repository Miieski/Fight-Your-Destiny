--!strict
-- Attributes (docs/menu_systems_brief.txt Part A) and the derived stats on the character.
--   Net.request("TrainAttributes", { Vigor = 2, ... }) buys points: keys, integers, caps, total cost point by
--   point, Gold; charged and applied together, saved, answered true, { Attributes, Cost }.
--   Net.request("RespecAttributes") -> every point back to 0 for Diamonds (Gold not refunded).
-- The Humanoid gets Max HP and walk speed from Util/Stats.compute (no combat logic here).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.GameSystem.Config.Attributes)
local Combat = require(ReplicatedStorage.GameSystem.Config.Combat)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)

local StatsService = { Priority = 3 }

local TRAIN_INTERVAL = 0.3
-- profile keys that change the derived stats: the character is refreshed when one of them changes
StatsService.WATCHED = { "Attributes", "Rebirths", "RebirthUpgrades", "Pets", "EquippedPets", "Armor", "EquippedArmor", "Weapons", "EquippedWeapon", "Boosts" }

function StatsService:Compute(player: Player): { [string]: any }?
	local profile = DataService:Get(player)
	if not profile then
		return nil
	end
	return Stats.compute(profile, { zoneId = player:GetAttribute("CurrentZone"), now = os.time() })
end

-- Max HP and walk speed on the Humanoid (keeps the same health fraction when Max HP changes).
function StatsService:Apply(player: Player)
	local stats = StatsService:Compute(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (stats and humanoid) or humanoid.Health <= 0 then
		return
	end
	local maxHP = math.max(1, math.floor(stats.MaxHP + 0.5))
	if humanoid.MaxHealth ~= maxHP then
		local fraction = humanoid.Health / math.max(1, humanoid.MaxHealth)
		humanoid.MaxHealth = maxHP
		humanoid.Health = math.min(maxHP, math.max(1, fraction * maxHP))
	end
	-- blocking halves the speed (CombatService sets the Blocking attribute)
	humanoid.WalkSpeed = stats.WalkSpeed * (if player:GetAttribute("Blocking") then Combat.Block.SpeedFactor else 1)
end

local function train(player: Player, plan: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	if typeof(plan) ~= "table" then
		return false, "Bad request"
	end
	local current = profile.Attributes or Attributes.empty()
	local adds, count = {}, 0
	for key, value in pairs(plan) do
		if typeof(key) ~= "string" or not Attributes.ById[key] then
			return false, "Bad request"
		end
		if typeof(value) ~= "number" or value ~= value or value % 1 ~= 0 or value < 0 or value > Attributes.MaxPoints then
			return false, "Bad request"
		end
		if (current[key] or 0) + value > Attributes.MaxPoints then
			return false, `{key} is already at its maximum`
		end
		adds[key] = value
		count += value
	end
	if count == 0 then
		return false, "Nothing to train"
	end
	local level = Attributes.level(current)
	local cost = Attributes.costOf(level, count, Stats.highestZone(profile))
	if typeof(profile.Gold) ~= "number" or profile.Gold < cost then
		return false, "Not enough Gold"
	end
	-- nothing below yields: Gold and points change together
	local nextValues = table.clone(current)
	for key, value in pairs(adds) do
		nextValues[key] = (nextValues[key] or 0) + value
	end
	DataService:Set(player, "Gold", profile.Gold - cost)
	DataService:Set(player, "Attributes", nextValues)
	StatsService:Apply(player)
	DataService:Save(player)
	RewardService.progress(player, "SpendAttributes", cost)
	return true, { Attributes = nextValues, Cost = cost }
end

local function respec(player: Player): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	if Attributes.level(profile.Attributes) == 0 then
		return false, "You have no points to reset"
	end
	local cost = Attributes.respecCost(Stats.highestZone(profile))
	if typeof(profile.Diamonds) ~= "number" or profile.Diamonds < cost then
		return false, "Not enough Diamonds"
	end
	DataService:Set(player, "Diamonds", profile.Diamonds - cost)
	DataService:Set(player, "Attributes", Attributes.empty())
	StatsService:Apply(player)
	DataService:Save(player)
	return true, { Cost = cost }
end

function StatsService:Init()
	Net.handle("TrainAttributes", train, TRAIN_INTERVAL)
	Net.handle("RespecAttributes", respec, 1)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			task.wait() -- after the default character scripts
			StatsService:Apply(player)
		end)
		player:GetAttributeChangedSignal("CurrentZone"):Connect(function()
			StatsService:Apply(player) -- armor Zone Boost depends on the zone
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	DataService.Loaded:Connect(function(player: Player)
		StatsService:Apply(player)
	end)
	DataService.Changed:Connect(function(player: Player, key: string)
		if table.find(StatsService.WATCHED, key) then
			StatsService:Apply(player)
		end
	end)
end

return StatsService
