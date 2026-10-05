--!strict
-- Timed boosts (profile.Boosts = { [boostId] = expiresAt os.time() }). Buying more time extends it.
local Boosts = {}

Boosts.List = {
	{ Id = "GoldX2", Name = "Gold Boost x2", Icon = "Gold", GoldBonus = 1.0 }, -- +100% Gold gain while active
}
-- Shop > Diamonds: Gold Boost x2 packs (docs/menu_systems_brief.txt D1). Buying more time extends it.
Boosts.Packs = {
	{ Boost = "GoldX2", Minutes = 15, Price = 25 },
	{ Boost = "GoldX2", Minutes = 30, Price = 45 },
	{ Boost = "GoldX2", Minutes = 60, Price = 80 },
}
Boosts.MaxStackHours = 24 -- stacking stops at this much time left

Boosts.ById = {}
for _, boost in ipairs(Boosts.List) do
	Boosts.ById[boost.Id] = boost
end

-- Seconds left (0 when not active).
function Boosts.remaining(boosts: { [string]: number }?, id: string, now: number?): number
	local expires = boosts and boosts[id]
	return if typeof(expires) == "number" then math.max(0, expires - (now or os.time())) else 0
end

function Boosts.isActive(boosts: { [string]: number }?, id: string, now: number?): boolean
	local expires = boosts and boosts[id]
	return typeof(expires) == "number" and expires > (now or os.time())
end

return Boosts
