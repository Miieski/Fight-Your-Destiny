--!strict
-- Attributes, Elden Ring style (docs/menu_systems_brief.txt Part A, rebalanced 2026-10-12). 8 attributes,
-- 0..MaxPoints points each, bought one at a time with Gold. Effects use the EFFECTIVE points (soft cap) times
-- RebirthPower; hard caps are absolute (never multiplied). Every derived number is computed in Util/Stats.compute.
--
-- Price (owner 2026-10-12: "max at the very end of the game"): the next point costs CostBase x CostGrowth ^ L, L = the
-- attribute level (total points bought). It does NOT follow the zone: Gold income grows x10 per zone, so the level a
-- player can afford grows with the zones. Calibration (docs/NIGHT_LOG.md): spending about one Rebirth cost of a zone
-- (x the Rebirth Gold multiplier, x1.5 for the other Gold bonuses) brings the level to ~26 in zone 1, ~160 in zone 6,
-- ~314 in zone 12: the last points (320 = every attribute at 40) come at the very end of the game.
export type Attribute = { Id: string, Name: string, Icon: string, Short: string, Effects: { string } }

local Attributes = {}

Attributes.MaxPoints = 40 -- per attribute
Attributes.SoftCap = 20 -- points above this count half (Peff)
Attributes.SoftCapRate = 0.5
Attributes.RebirthPowerPerRebirth = 0.25 -- RebirthPower = 1 + 0.25 x Rebirths

-- Cost of the next point: round(CostBase x CostGrowth ^ L), L = total points already bought (x10 every ~24 levels).
Attributes.CostBase = 400
Attributes.CostGrowth = 1.1
-- Respec: every point back to 0 for RespecBase + RespecPerZone x Z Diamonds; the Gold the points cost is given back
-- (owner 2026-10-13: "When you reset stat with diamond you have to get back your money spend").
Attributes.RespecBase = 5
Attributes.RespecPerZone = 2

-- Per EFFECTIVE point (before RebirthPower). Fractions: 0.10 = +10%.
Attributes.PerPoint = {
	VigorHP = 0.10,
	VigorRegen = 0.001, -- of Max HP per second, out of combat
	MindGold = 0.06,
	MindRoll = 0.012,
	EnduranceDefense = 2.0, -- Defense points
	EnduranceBlock = 0.01,
	EnduranceSpeed = 0.008,
	DexterityAttackSpeed = 0.005,
	IntelligenceCastSpeed = 0.005,
	IntelligenceProc = 0.008,
	IntelligenceRadius = 0.01,
	FaithPets = 0.03,
	FaithHealing = 0.03,
	ArcaneCrit = 0.005,
	ArcaneCritDamage = 0.03,
	ArcaneLoot = 0.01,
	DamageScaling = 0.08, -- AttributeDamageMult = 1 + 0.08 x RP x sum(weight x Peff)
}

-- Base values and absolute hard caps.
Attributes.Base = {
	HP = 100,
	RegenDelay = 5, -- seconds after the last damage
	RollCooldown = 1.2,
	Block = 0.60,
	CritChance = 0.05,
	CritDamage = 2.0,
	WalkSpeed = 16,
}
Attributes.Caps = {
	RollCooldownFloor = 0.6,
	Block = 0.85,
	MoveSpeed = 0.40, -- attributes + pets together
	AttackSpeed = 1.0, -- attribute + weapon rarity together (Config/WeaponMoves RaritySpeed): at most 2x
	ElementProc = 0.16,
	MagicRadius = 0.25,
	CritChance = 0.60,
}
Attributes.DefenseConstant = 100 -- damage reduction = Def / (Def + 100)

-- Weapon damage scaling weights per category (A3) and the grade letters shown in the UI.
Attributes.Scaling = {
	Sword = { Strength = 0.6, Dexterity = 0.6 },
	Spear = { Strength = 0.5, Dexterity = 0.7 },
	Heavy = { Strength = 1.2 },
	Dagger = { Dexterity = 0.8, Arcane = 0.4 },
	Ranged = { Dexterity = 1.2 },
	Magic = { Intelligence = 1.2 },
} :: { [string]: { [string]: number } }
Attributes.Grades = { { Min = 1.0, Letter = "S" }, { Min = 0.7, Letter = "A" }, { Min = 0.5, Letter = "B" }, { Min = 0.3, Letter = "C" }, { Min = 0, Letter = "D" } }

-- 0.1 -> "10%", 0.012 -> "1.2%", 0.0005 -> "0.05%"
local function pct(fraction: number): string
	local text = string.format("%.2f", fraction * 100)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return text .. "%"
end

-- 2 -> "2", 2.5 -> "2.5"; percentage points: 0.005 -> "0.5"
local function num(value: number): string
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	return (string.gsub(text, "%.$", ""))
end

Attributes.pct = pct

-- "Heavy +9.6%, Sword +4.8%, ..." for one attribute (per point, before the soft cap and RebirthPower)
local function damageList(id: string, k: number): string
	local list = {}
	for category, weights in pairs(Attributes.Scaling) do
		if weights[id] then
			table.insert(list, { category, weights[id] })
		end
	end
	table.sort(list, function(a, b)
		return if a[2] == b[2] then a[1] < b[1] else a[2] > b[2]
	end)
	local parts = {}
	for _, pair in ipairs(list) do
		table.insert(parts, `{pair[1]} +{pct(Attributes.PerPoint.DamageScaling * pair[2] * k)}`)
	end
	return table.concat(parts, ", ")
end

-- The effects of ONE point (per point, before the soft cap and RebirthPower), built from the numbers above.
local function effectsOf(id: string): { string }
	local p, base, caps = Attributes.PerPoint, Attributes.Base, Attributes.Caps
	if id == "Vigor" then
		return { `Max HP +{pct(p.VigorHP)}`, `HP regeneration out of combat +{pct(p.VigorRegen)} of Max HP per second` }
	elseif id == "Mind" then
		return { `Gold Gain +{pct(p.MindGold)}`, `Roll cooldown -{pct(p.MindRoll)} (base {num(base.RollCooldown)} s, floor {num(caps.RollCooldownFloor)} s)` }
	elseif id == "Endurance" then
		return {
			`Defense +{num(p.EnduranceDefense)}`,
			`Block reduction +{num(p.EnduranceBlock * 100)} pts (base {pct(base.Block)}, cap {pct(caps.Block)})`,
			`Move speed +{pct(p.EnduranceSpeed)} (cap +{pct(caps.MoveSpeed)} with pets)`,
		}
	elseif id == "Strength" then
		return { `Weapon damage: {damageList(id, 1)}` }
	elseif id == "Dexterity" then
		return { `Weapon damage: {damageList(id, 1)}`, `Attack speed +{pct(p.DexterityAttackSpeed)} (cap +{pct(caps.AttackSpeed)} with the weapon's rarity)` }
	elseif id == "Intelligence" then
		return {
			`Weapon damage: {damageList(id, 1)}`,
			`Element proc chance +{num(p.IntelligenceProc * 100)} pts (cap +{num(caps.ElementProc * 100)} pts)`,
			`Magic area radius +{pct(p.IntelligenceRadius)} (cap +{pct(caps.MagicRadius)})`,
			`Staff cast speed +{pct(p.IntelligenceCastSpeed)} (cap +{pct(caps.AttackSpeed)} with the weapon's rarity)`,
		}
	elseif id == "Faith" then
		return { `Pet bonus effectiveness +{pct(p.FaithPets)}`, `Lifesteal and healing effects +{pct(p.FaithHealing)}` }
	end
	return {
		`Crit chance +{num(p.ArcaneCrit * 100)} pts (base {pct(base.CritChance)}, cap {pct(caps.CritChance)})`,
		`Crit damage +{pct(p.ArcaneCritDamage)} (base x{num(base.CritDamage)})`,
		`Loot drop chance +{pct(p.ArcaneLoot)}`,
		`Weapon damage: {damageList(id, 1)}`,
	}
end

Attributes.List = {
	{ Id = "Vigor", Name = "Vigor", Icon = "MaxHP", Short = "Health", Effects = {} },
	{ Id = "Mind", Name = "Mind", Icon = "GoldGain", Short = "Fortune", Effects = {} },
	{ Id = "Endurance", Name = "Endurance", Icon = "Defense", Short = "Toughness", Effects = {} },
	{ Id = "Strength", Name = "Strength", Icon = "Attack", Short = "Power", Effects = {} },
	{ Id = "Dexterity", Name = "Dexterity", Icon = "Speed", Short = "Skill", Effects = {} },
	{ Id = "Intelligence", Name = "Intelligence", Icon = "Magic", Short = "Sorcery", Effects = {} },
	{ Id = "Faith", Name = "Faith", Icon = "Star", Short = "Devotion", Effects = {} },
	{ Id = "Arcane", Name = "Arcane", Icon = "Crit", Short = "Luck", Effects = {} },
} :: { Attribute }

Attributes.ById = {} :: { [string]: Attribute }
Attributes.Ids = {} :: { string }
for _, attribute in ipairs(Attributes.List) do
	attribute.Effects = effectsOf(attribute.Id)
	Attributes.ById[attribute.Id] = attribute
	table.insert(Attributes.Ids, attribute.Id)
end
Attributes.MaxLevel = #Attributes.List * Attributes.MaxPoints -- 320

function Attributes.grade(weight: number): string
	for _, grade in ipairs(Attributes.Grades) do
		if weight >= grade.Min - 1e-9 then
			return grade.Letter
		end
	end
	return "D"
end

-- Effective points after the soft cap: 40 points -> 30.
function Attributes.effective(points: number): number
	local cap = Attributes.SoftCap
	return math.min(points, cap) + Attributes.SoftCapRate * math.max(0, points - cap)
end

function Attributes.rebirthPower(rebirths: number): number
	return 1 + Attributes.RebirthPowerPerRebirth * (rebirths or 0)
end

-- Gold price of the next point at attribute level L.
function Attributes.pointCost(level: number): number
	return math.round(Attributes.CostBase * Attributes.CostGrowth ^ level)
end

-- Total Gold for `count` more points starting at level L.
function Attributes.costOf(level: number, count: number): number
	local total = 0
	for i = 0, count - 1 do
		total += Attributes.pointCost(level + i)
	end
	return total
end

-- What point number `nextPoint` (1..MaxPoints) of an attribute gives, for the row of the Attributes window: its
-- main effect after the soft cap and RebirthPower. category = the equipped weapon's category (damage scaling).
function Attributes.pointGain(id: string, nextPoint: number, rebirths: number, category: string?): string
	if nextPoint > Attributes.MaxPoints then
		return "Maxed"
	end
	local p = Attributes.PerPoint
	local k = Attributes.rebirthPower(rebirths) * (if nextPoint > Attributes.SoftCap then Attributes.SoftCapRate else 1)
	local weight = if category and Attributes.Scaling[category] then Attributes.Scaling[category][id] else nil
	if weight then
		return `+{pct(p.DamageScaling * weight * k)} damage`
	elseif id == "Vigor" then
		return `+{pct(p.VigorHP * k)} Max HP`
	elseif id == "Mind" then
		return `+{pct(p.MindGold * k)} Gold`
	elseif id == "Endurance" then
		return `+{num(p.EnduranceDefense * k)} Defense`
	elseif id == "Dexterity" then
		return `+{pct(p.DexterityAttackSpeed * k)} attack speed`
	elseif id == "Intelligence" then
		return `+{num(p.IntelligenceProc * k * 100)} pts element proc`
	elseif id == "Faith" then
		return `+{pct(p.FaithPets * k)} pet power`
	elseif id == "Arcane" then
		return `+{num(p.ArcaneCrit * k * 100)} pts crit`
	end
	return if category then "Your weapon does not scale with it" else "Damage of Strength weapons"
end

function Attributes.respecCost(zone: number): number
	return Attributes.RespecBase + Attributes.RespecPerZone * zone
end

-- The Gold a respec gives back: what every point bought cost (points 1..L; the price only depends on the level).
function Attributes.refundOf(values: { [string]: number }?): number
	return Attributes.costOf(0, Attributes.level(values))
end

function Attributes.empty(): { [string]: number }
	local values = {}
	for _, id in ipairs(Attributes.Ids) do
		values[id] = 0
	end
	return values
end

function Attributes.level(values: { [string]: number }?): number
	local total = 0
	for _, id in ipairs(Attributes.Ids) do
		total += (values and values[id]) or 0
	end
	return total
end

return Attributes
