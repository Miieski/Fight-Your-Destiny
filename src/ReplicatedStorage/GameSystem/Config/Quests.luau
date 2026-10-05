--!strict
-- Quests window numbers (docs/menu_systems_brief.txt D4). G = 2000 x 10^(Z-1) Gold, Z = highest zone unlocked;
-- rewards written in G are paid with the player's G at claim time. Days are UTC days (os.time() // 86400):
-- everything resets at 00:00 UTC.
local Weapons = require(script.Parent.Weapons)

local Quests = {}

Quests.SECONDS_PER_DAY = 86400
Quests.PerDay = 3
Quests.GoldRewardG = 3 -- a normal quest pays 3 G
Quests.HardDiamonds = 2 -- a hard quest pays 2 Diamonds instead
Quests.AllDoneDiamonds = 5 -- claiming the 3rd quest of the day adds this bonus

export type Kind = { Id: string, Text: string, Icon: string, Target: number?, TargetG: number?, TargetDamage: number?, Hard: boolean? }

-- The pool of 10 kinds. Text: "{n}" = the target. Kinds whose system is not built yet still exist: they
-- progress through RewardService.progress(player, kind, n) once that system calls it.
Quests.Pool = {
	{ Id = "KillEnemies", Text = "Defeat {n} enemies", Icon = "Skull", Target = 40 },
	{ Id = "EarnGold", Text = "Earn {n} Gold from enemies", Icon = "Gold", TargetG = 20 },
	{ Id = "OpenSubZone", Text = "Open a new sub-zone gate", Icon = "Key", Target = 1 },
	{ Id = "HatchEggs", Text = "Hatch {n} eggs", Icon = "Egg", Target = 2 },
	{ Id = "BuyWeapon", Text = "Buy a weapon in the Shop", Icon = "Shop", Target = 1 },
	{ Id = "SpendAttributes", Text = "Spend {n} Gold on attributes", Icon = "Stats", TargetG = 10 },
	{ Id = "DealDamage", Text = "Deal {n} damage", Icon = "Attack", TargetDamage = 500 },
	{ Id = "KillMiniBoss", Text = "Defeat a mini-boss", Icon = "Skull", Target = 1, Hard = true },
	{ Id = "BeatBoss", Text = "Beat a boss", Icon = "Crown", Target = 1, Hard = true },
	{ Id = "CollectTrophies", Text = "Collect {n} trophies", Icon = "Trophy", Target = 3, Hard = true },
} :: { Kind }
Quests.ById = {} :: { [string]: Kind }
for _, kind in ipairs(Quests.Pool) do
	Quests.ById[kind.Id] = kind
end

-- 7-day streak (missing a day restarts at day 1). Gold in G; PremiumEgg = an egg of the highest unlocked zone with
-- the shop odds; Boost minutes of Gold Boost x2.
Quests.Daily = {
	{ Gold = 1 },
	{ Gold = 2 },
	{ Diamonds = 5 },
	{ Gold = 4 },
	{ PremiumEgg = true },
	{ Boost = "GoldX2", Minutes = 30 },
	{ Diamonds = 15, Gold = 8 },
}

-- Playtime gifts (minutes played today).
Quests.Gifts = {
	{ Minutes = 5, Gold = 1 },
	{ Minutes = 10, Gold = 1 },
	{ Minutes = 20, Diamonds = 2 },
	{ Minutes = 30, Gold = 2 },
	{ Minutes = 45, Boost = "GoldX2", BoostMinutes = 15 },
	{ Minutes = 60, Diamonds = 3, Gold = 3 },
}
Quests.PlaytimeTickSeconds = 15 -- the server adds play time (and replicates it) this often

function Quests.G(zone: number): number
	return 2000 * 10 ^ (math.max(1, zone) - 1)
end

function Quests.day(time: number): number
	return time // Quests.SECONDS_PER_DAY
end

function Quests.secondsToReset(time: number): number
	return Quests.SECONDS_PER_DAY - (time % Quests.SECONDS_PER_DAY)
end

-- The 3 kinds of a UTC day: the same for everyone.
function Quests.forDay(day: number): { string }
	local rng = Random.new(day * 7919 + 13)
	local ids = {}
	for _, kind in ipairs(Quests.Pool) do
		table.insert(ids, kind.Id)
	end
	for i = #ids, 2, -1 do
		local j = rng:NextInteger(1, i)
		ids[i], ids[j] = ids[j], ids[i]
	end
	return { ids[1], ids[2], ids[3] }
end

function Quests.target(id: string, zone: number): number
	local kind = Quests.ById[id]
	if kind.TargetG then
		return kind.TargetG * Quests.G(zone)
	elseif kind.TargetDamage then
		return kind.TargetDamage * Weapons.ZONE_BASE_DAMAGE * 10 ^ (math.max(1, zone) - 1)
	end
	return kind.Target or 1
end

function Quests.describe(id: string, target: number, format: (number) -> string): string
	local kind = Quests.ById[id]
	return (string.gsub(kind.Text, "{n}", format(target)))
end

-- { Gold = n, Diamonds = n } of a finished quest (Gold already multiplied by G).
function Quests.questReward(id: string, zone: number): { [string]: number }
	local kind = Quests.ById[id]
	if kind.Hard then
		return { Diamonds = Quests.HardDiamonds }
	end
	return { Gold = Quests.GoldRewardG * Quests.G(zone) }
end

-- The next daily reward index for a { Streak, LastDay } record on `today` (nil = already claimed today).
function Quests.nextDaily(daily: { [string]: any }?, today: number): number?
	local last = daily and tonumber(daily.LastDay) or 0
	local streak = daily and tonumber(daily.Streak) or 0
	if last == today then
		return nil
	end
	if last == today - 1 and streak >= 1 then
		return streak % #Quests.Daily + 1
	end
	return 1
end

return Quests
