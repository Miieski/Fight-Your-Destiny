--!strict
-- Timed boosts (Config/Boosts; profile.Boosts = { [boostId] = expiresAt }). Util/Stats.compute reads them.
--   Net.request("BuyBoost", packIndex)   Shop > Diamonds Gold Boost x2 packs: Diamonds, time added (stacks)
--   BoostService:Add(player, boostId, seconds)   rewards (daily, playtime gifts) and admin giveBoost
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boosts = require(ReplicatedStorage.GameSystem.Config.Boosts)
local Net = require(ReplicatedStorage.GameSystem.Net)
local DataService = require(script.Parent.DataService)

local BoostService = { Priority = 5 }

-- Adds time to a boost (from now if it is not active). Returns the new expiry, or nil.
function BoostService:Add(player: Player, id: string, seconds: number): number?
	local profile = DataService:Get(player)
	if not profile or not Boosts.ById[id] or typeof(seconds) ~= "number" or seconds <= 0 then
		return nil
	end
	local now = os.time()
	local boosts = table.clone(profile.Boosts or {})
	local current = boosts[id]
	local start = if typeof(current) == "number" and current > now then current else now
	local expires = math.min(start + math.floor(seconds), now + Boosts.MaxStackHours * 3600)
	boosts[id] = expires
	-- drop expired entries
	for key, value in pairs(boosts) do
		if typeof(value) ~= "number" or value <= now then
			boosts[key] = nil
		end
	end
	boosts[id] = expires
	DataService:Set(player, "Boosts", boosts)
	return expires
end

local function buy(player: Player, index: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	local pack = if typeof(index) == "number" and index % 1 == 0 then Boosts.Packs[index] else nil
	if not pack then
		return false, "Bad request"
	end
	if Boosts.remaining(profile.Boosts, pack.Boost) + pack.Minutes * 60 > Boosts.MaxStackHours * 3600 then
		return false, `A boost can stack up to {Boosts.MaxStackHours} hours`
	end
	if typeof(profile.Diamonds) ~= "number" or profile.Diamonds < pack.Price then
		return false, "Not enough Diamonds"
	end
	DataService:Set(player, "Diamonds", profile.Diamonds - pack.Price)
	local expires = BoostService:Add(player, pack.Boost, pack.Minutes * 60)
	DataService:Save(player)
	return true, { expires = expires, cost = pack.Price }
end

function BoostService:Init()
	Net.handle("BuyBoost", buy, 0.5)
end

return BoostService
