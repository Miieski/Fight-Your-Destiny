--!strict
-- Diamonds for each victory over a mini-boss or a boss, every time, not only the first (owner prompt "ROUND 9" part 6, table in
-- docs/boss_rewards.md). Mini-boss 3 x zone index, boss 10 x zone index, read from Config/Zones, so all 12 zones are here and a
-- zone that opens later pays with no code change. Everyone who qualifies gets the full amount: it is never split.
-- Pure: no service, no Instance. BossService decides who qualifies and pays; settle() is what makes a payout happen only once.
local Zones = require(script.Parent.Zones)

local BossRewards = {}

BossRewards.MiniPerZone = 3
BossRewards.BossPerZone = 10

-- [zoneId] = { Mini = diamonds, Boss = diamonds }
BossRewards.Diamonds = {} :: { [string]: { Mini: number, Boss: number } }
for _, zone in ipairs(Zones.List) do
	BossRewards.Diamonds[zone.Id] = { Mini = BossRewards.MiniPerZone * zone.Index, Boss = BossRewards.BossPerZone * zone.Index }
end

-- Diamonds of one defeated enemy. tier = the enemy's def.Tier, "mini" or "boss"; anything else pays 0.
function BossRewards.amount(zoneId: string, tier: string): number
	local row = BossRewards.Diamonds[zoneId]
	if not row then
		return 0
	end
	return if tier == "boss" then row.Boss elseif tier == "mini" then row.Mini else 0
end

-- [participant] = diamonds, for those not yet in `paid`, and marks them there. `paid` lives with one enemy of one fight:
-- a second call with the same table returns nothing for the same participants.
function BossRewards.settle(paid: { [any]: boolean }, zoneId: string, tier: string, participants: { any }): { [any]: number }
	local amount = BossRewards.amount(zoneId, tier)
	local out = {}
	for _, participant in ipairs(participants) do
		if not paid[participant] then
			paid[participant] = true
			out[participant] = amount
		end
	end
	return out
end

-- Self-check, from the Server or Edit command bar: print(require(game.ReplicatedStorage.GameSystem.Config.BossRewards).selfCheck())
function BossRewards.selfCheck(): (boolean, string)
	local count = 0
	for _, zone in ipairs(Zones.List) do
		if BossRewards.amount(zone.Id, "mini") ~= 3 * zone.Index or BossRewards.amount(zone.Id, "boss") ~= 10 * zone.Index then
			return false, `wrong amount in {zone.Id}`
		end
		count += 1
	end
	if BossRewards.amount("Nowhere", "boss") ~= 0 or BossRewards.amount("Plains", "normal") ~= 0 then
		return false, "an unknown zone or tier must pay 0"
	end
	for size = 1, 5 do
		local team = {}
		for i = 1, size do
			team[i] = `player{i}`
		end
		local paid = {}
		local first = BossRewards.settle(paid, "Desert", "boss", team)
		for _, name in ipairs(team) do
			if first[name] ~= 20 then
				return false, `{name} of {size} did not get the full amount`
			end
		end
		if next(BossRewards.settle(paid, "Desert", "boss", team)) ~= nil then
			return false, `second payout for a team of {size}`
		end
		table.insert(team, "late")
		local second = BossRewards.settle(paid, "Desert", "boss", team)
		if second.late ~= 20 or second.player1 ~= nil then
			return false, "a retry must pay only who was not paid"
		end
	end
	return true, `{count} zones, teams of 1 to 5 paid in full, second payout empty`
end

return BossRewards
