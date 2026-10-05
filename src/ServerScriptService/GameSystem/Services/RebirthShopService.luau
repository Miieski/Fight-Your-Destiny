--!strict
-- Rebirth Shop (docs/menu_systems_brief.txt D2): Net.request("BuyRebirthUpgrade", id) spends Rebirth Credits on
-- one level of an upgrade (Config/RebirthShop: cost per level, max level). Upgrades and credits are kept on Rebirth;
-- Util/Stats.compute reads the levels. Credits come from the Rebirth system (later; admin setCredits now).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local RebirthShop = require(ReplicatedStorage.GameSystem.Config.RebirthShop)
local DataService = require(script.Parent.DataService)

local RebirthShopService = { Priority = 5 }

local function buy(player: Player, id: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local upgrade = if typeof(id) == "string" then RebirthShop.ById[id] else nil
	if not upgrade then
		return false, "Unknown upgrade"
	end
	local levels = profile.RebirthUpgrades or {}
	local level = math.floor(tonumber(levels[id]) or 0)
	if level >= upgrade.Max then
		return false, `{upgrade.Name} is at its maximum`
	end
	local credits = math.floor(tonumber(profile.RebirthCredits) or 0)
	if credits < RebirthShop.CostPerLevel then
		return false, "Not enough Rebirth Credits"
	end
	local nextLevels = table.clone(levels)
	nextLevels[id] = level + 1
	DataService:Set(player, "RebirthCredits", credits - RebirthShop.CostPerLevel)
	DataService:Set(player, "RebirthUpgrades", nextLevels)
	DataService:Save(player)
	return true, { id = id, level = level + 1 }
end

function RebirthShopService:Init()
	Net.handle("BuyRebirthUpgrade", buy, 0.2)
end

return RebirthShopService
