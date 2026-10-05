--!strict
-- Timed boosts (profile.Boosts = { [boostId] = expiresAt os.time() }). Buying more time extends it.
local Boosts = {}

Boosts.List = {
	{ Id = "GoldX2", Name = "Gold Boost x2", Icon = "Gold", GoldBonus = 1.0 }, -- +100% Gold gain while active
}
Boosts.ById = {}
for _, boost in ipairs(Boosts.List) do
	Boosts.ById[boost.Id] = boost
end

function Boosts.isActive(boosts: { [string]: number }?, id: string, now: number?): boolean
	local expires = boosts and boosts[id]
	return typeof(expires) == "number" and expires > (now or os.time())
end

return Boosts
