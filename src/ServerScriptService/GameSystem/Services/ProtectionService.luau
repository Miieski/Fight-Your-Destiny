--!strict
-- Rebirth Protection (Config/RebirthProtection). Net.request("ProtectItem", uid) -> true, { Diamonds, Price, Category } or false, reason.
-- Net.request("GetProtectionPrice", uid) -> a price to show; the real one is computed again at purchase. Nothing between
-- the checks and the commit yields, so a double click finds the item protected; the profile is then saved at once.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local RebirthProtection = require(ReplicatedStorage.GameSystem.Config.RebirthProtection)
local DataService = require(script.Parent.DataService)

local ProtectionService = { Priority = 6 }

local function protect(player: Player, uid: any): (boolean, any)
	local profile = DataService:Get(player)
	if not profile then
		return false, "Not ready yet"
	end
	local category, key, item = RebirthProtection.find(profile, uid)
	if not (category and key and item) then
		return false, "You don't own this item"
	end
	if item.Protected then
		return false, "This item is already protected"
	end
	local price = RebirthProtection.price(category, item)
	if typeof(profile.Diamonds) ~= "number" or profile.Diamonds < price then
		return false, "Not enough Diamonds"
	end
	local owned = table.clone(profile[key])
	local copy = table.clone(item)
	copy.Protected = true
	copy.ProtectedPricePaid = price
	owned[uid] = copy
	DataService:SetMany(player, { Diamonds = profile.Diamonds - price, [key] = owned })
	DataService:Save(player)
	return true, { Diamonds = profile.Diamonds, Price = price, Category = category }
end

local function priceOf(player: Player, uid: any): (boolean, any)
	local profile = DataService:Get(player)
	local category, _, item = RebirthProtection.find(profile or {}, uid)
	if not (category and item) then
		return false, "You don't own this item"
	end
	return true, RebirthProtection.price(category, item)
end

function ProtectionService:Init()
	Net.handle("ProtectItem", protect, 0.25)
	Net.handle("GetProtectionPrice", priceOf, 0.1)
end

return ProtectionService
