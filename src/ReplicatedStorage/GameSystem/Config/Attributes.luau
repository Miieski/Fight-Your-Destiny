--!strict
-- Attributes, Elden Ring style (docs/menu_systems_brief.txt Part A). 8 attributes, 0..MaxPoints points each,
-- bought one at a time with Gold. Effects use the EFFECTIVE points (soft cap) times RebirthPower; hard caps are
-- absolute (never multiplied). Every derived number is computed in Util/Stats.compute.
export type Attribute = { Id: string, Name: string, Icon: string, Short: string, Effects: { string } }

local Attributes = {}

Attributes.MaxPoints = 40 -- per attribute
Attributes.SoftCap = 20 -- points above this count half (Peff)
Attributes.SoftCapRate = 0.5
Attributes.RebirthPowerPerRebirth = 0.25 -- RebirthPower = 1 + 0.25 x Rebirths

-- Cost of the next point: round(CostBase x 10^(Z-1) x (1 + L / CostDivisor) ^ CostExponent)
-- L = total points already bought, Z = highest zone unlocked.
Attributes.CostBase = 100
Attributes.CostDivisor = 10
Attributes.CostExponent = 1.5
-- Respec: every point back to 0 (no Gold refund) for RespecBase + RespecPerZone x Z Diamonds.
Attributes.RespecBase = 5
Attributes.RespecPerZone = 2

Attributes.List = {
	{ Id = "Vigor", Name = "Vigor", Icon = "MaxHP", Short = "Health", Effects = { "Max HP +4%", "HP regeneration out of combat +0.05% of Max HP per second" } },
	{ Id = "Mind", Name = "Mind", Icon = "GoldGain", Short = "Fortune", Effects = { "Gold Gain +2.5%", "Roll cooldown -0.7% (base 1.5 s, floor 0.6 s)" } },
	{ Id = "Endurance", Name = "Endurance", Icon = "Defense", Short = "Toughness", Effects = { "Defense +1", "Block reduction +0.5 pts (base 60%, cap 85%)", "Move speed +0.4% (cap +40% with pets)" } },
	{ Id = "Strength", Name = "Strength", Icon = "Attack", Short = "Power", Effects = { "Damage of Strength weapons (Heavy S, Gauntlet A, Sword B, Spear B)" } },
	{ Id = "Dexterity", Name = "Dexterity", Icon = "Speed", Short = "Skill", Effects = { "Damage of Dexterity weapons (Ranged S, Dagger A, Spear A, Sword B, Gauntlet B, Whip B)", "Attack speed +0.3% (cap +15%)" } },
	{ Id = "Intelligence", Name = "Intelligence", Icon = "Magic", Short = "Sorcery", Effects = { "Damage of Magic weapons (S)", "Element proc chance +0.4 pts (cap +16 pts)", "Magic area radius +0.5% (cap +25%)" } },
	{ Id = "Faith", Name = "Faith", Icon = "Star", Short = "Devotion", Effects = { "Pet bonus effectiveness +1.2%", "Lifesteal and healing effects +1.5%" } },
	{ Id = "Arcane", Name = "Arcane", Icon = "Crit", Short = "Luck", Effects = { "Crit chance +0.25 pts (base 5%, cap 60%)", "Crit damage +1.5% (base x2)", "Loot drop chance +0.5%", "Damage of Arcane weapons (Dagger C, Whip B)" } },
} :: { Attribute }

Attributes.ById = {} :: { [string]: Attribute }
Attributes.Ids = {} :: { string }
for _, attribute in ipairs(Attributes.List) do
	Attributes.ById[attribute.Id] = attribute
	table.insert(Attributes.Ids, attribute.Id)
end
Attributes.MaxLevel = #Attributes.List * Attributes.MaxPoints -- 320

-- Per EFFECTIVE point (before RebirthPower). Fractions: 0.04 = +4%.
Attributes.PerPoint = {
	VigorHP = 0.04,
	VigorRegen = 0.0005, -- of Max HP per second, out of combat
	MindGold = 0.025,
	MindRoll = 0.007,
	EnduranceDefense = 1.0, -- Defense points
	EnduranceBlock = 0.005,
	EnduranceSpeed = 0.004,
	DexterityAttackSpeed = 0.003,
	IntelligenceProc = 0.004,
	IntelligenceRadius = 0.005,
	FaithPets = 0.012,
	FaithHealing = 0.015,
	ArcaneCrit = 0.0025,
	ArcaneCritDamage = 0.015,
	ArcaneLoot = 0.005,
	DamageScaling = 0.03, -- AttributeDamageMult = 1 + 0.03 x RP x sum(weight x Peff)
}

-- Base values and absolute hard caps.
Attributes.Base = {
	HP = 100,
	RegenDelay = 5, -- seconds after the last damage
	RollCooldown = 1.5,
	Block = 0.60,
	CritChance = 0.05,
	CritDamage = 2.0,
	WalkSpeed = 16,
}
Attributes.Caps = {
	RollCooldownFloor = 0.6,
	Block = 0.85,
	MoveSpeed = 0.40, -- attributes + pets together
	AttackSpeed = 0.15,
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
	Gauntlet = { Strength = 0.7, Dexterity = 0.5 },
	Ranged = { Dexterity = 1.2 },
	Magic = { Intelligence = 1.2 },
	Whip = { Dexterity = 0.6, Arcane = 0.6 },
} :: { [string]: { [string]: number } }
Attributes.Grades = { { Min = 1.0, Letter = "S" }, { Min = 0.7, Letter = "A" }, { Min = 0.5, Letter = "B" }, { Min = 0.3, Letter = "C" }, { Min = 0, Letter = "D" } }

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

function Attributes.pointCost(level: number, zone: number): number
	return math.round(Attributes.CostBase * 10 ^ (zone - 1) * (1 + level / Attributes.CostDivisor) ^ Attributes.CostExponent)
end

-- Total Gold for `count` more points starting at level L.
function Attributes.costOf(level: number, count: number, zone: number): number
	local total = 0
	for i = 0, count - 1 do
		total += Attributes.pointCost(level + i, zone)
	end
	return total
end

function Attributes.respecCost(zone: number): number
	return Attributes.RespecBase + Attributes.RespecPerZone * zone
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
