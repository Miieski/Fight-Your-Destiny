--!strict
-- Index (docs/menu_systems_brief.txt D3): discovery and rewards (Config/IndexBook).
--   Net.request("ClaimIndexReward", rewardId) -> complete and not claimed yet -> Diamonds, saved, once only.
--   IndexService:Discover(player, entryId, tier?) keeps the best rarity (enemies: on the first kill, later).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IndexBook = require(ReplicatedStorage.GameSystem.Config.IndexBook)
local Net = require(ReplicatedStorage.GameSystem.Net)
local DataService = require(script.Parent.DataService)

local IndexService = { Priority = 5 }

function IndexService:Discover(player: Player, id: string, tier: number?): boolean
	local profile = DataService:Get(player)
	if not profile or not IndexBook.ById[id] then
		return false
	end
	local best = IndexBook.best(profile.Index, id)
	local value = math.max(1, math.floor(tier or 1))
	if best == nil or best < value then
		local index = table.clone(profile.Index)
		index[id] = value
		DataService:Set(player, "Index", index)
	end
	return true
end

local function claim(player: Player, rewardId: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Profile not loaded"
	end
	if typeof(rewardId) ~= "string" then
		return false, "Bad request"
	end
	local reward = IndexBook.reward(profile.Index, profile.IndexClaimed, rewardId)
	if not reward then
		return false, "Unknown reward"
	end
	if reward.Claimed then
		return false, "Already claimed"
	end
	if not reward.Complete then
		return false, `Not complete yet ({reward.Have}/{reward.Total})`
	end
	local claimed = table.clone(profile.IndexClaimed or {})
	claimed[rewardId] = true
	DataService:Set(player, "IndexClaimed", claimed)
	DataService:AddDiamonds(player, reward.Diamonds)
	DataService:Save(player)
	return true, { diamonds = reward.Diamonds }
end

function IndexService:Init()
	Net.handle("ClaimIndexReward", claim, 0.3)
end

return IndexService
