--!strict
-- One skill tree per weapon type (Round 8 part 6): 25 nodes each, the same map, its content per type. Generated here, listed in
-- docs/weapon_skill_trees.md. A root, 3 paths that split and re-join, two bridges, a keystone, 3 ultimate nodes.
--   node = { Id, Name, Kind = "Stat" | "Special" | "Passive", Stat?, Value?, Skill?, Passive?, Cost (points), Requires = { all of },
--            Any = { one of }, X, Y (map position), Ultimate? }
local Specials = require(script.Parent.WeaponSpecials)

local Trees = {}

-- stat -> how it reads and how much one node gives
Trees.Stats = {
	Damage = { Label = "Damage", Value = 0.04, Text = "+%d%% damage" },
	AttackSpeed = { Label = "Attack speed", Value = 0.03, Text = "+%d%% attack speed" },
	CritChance = { Label = "Crit chance", Value = 0.02, Text = "+%d%% crit chance" },
	CritDamage = { Label = "Crit damage", Value = 0.08, Text = "+%d%% crit damage" },
	Cooldown = { Label = "Cooldowns", Value = 0.05, Text = "-%d%% skill cooldowns" },
	FinisherPower = { Label = "Finisher", Value = 0.08, Text = "+%d%% finisher damage" },
	Guard = { Label = "Guard", Value = 0.02, Text = "+%d%% block" },
	Reach = { Label = "Reach", Value = 0.04, Text = "+%d%% attack reach" },
	ProjectileSpeed = { Label = "Arrow speed", Value = 0.08, Text = "+%d%% projectile speed" },
	ManaMax = { Label = "Mana", Value = 0.08, Text = "+%d%% max mana" },
	ManaRegen = { Label = "Mana flow", Value = 0.08, Text = "+%d%% mana regen" },
	ManaCost = { Label = "Mana thrift", Value = 0.05, Text = "-%d%% mana costs" },
} :: { [string]: { Label: string, Value: number, Text: string } }

-- the third path of each type
local MELEE = { "Guard", "Reach", "Guard", "Reach", "Cooldown" }
local THIRD = {
	Sword = MELEE, Spear = MELEE, Heavy = MELEE, Dagger = MELEE,
	Ranged = { "ProjectileSpeed", "ProjectileSpeed", "Cooldown", "CritChance", "ProjectileSpeed" },
	Magic = { "ManaMax", "ManaRegen", "ManaMax", "ManaCost", "ManaRegen" },
}
local FIRST = { "Damage", "Damage", "CritDamage", "Damage", "FinisherPower" }
local SECOND = { "AttackSpeed", "AttackSpeed", "Cooldown", "CritChance", "AttackSpeed" }
local PATHS = { { Name = "A", X = -5 }, { Name = "B", X = 0 }, { Name = "C", X = 5 } }

Trees.ByCategory = {} :: { [string]: { any } }
Trees.Nodes = {} :: { [string]: any } -- [nodeId] = node
Trees.Order = { "Sword", "Spear", "Heavy", "Dagger", "Ranged", "Magic" }

local function build(category: string)
	local nodes = {}
	local counts: { [string]: number } = {}
	local function add(node: { [string]: any })
		node.Id = `{category}_{node.Id}`
		node.Category = category
		node.Requires = node.Requires or {}
		node.Any = node.Any or {}
		for i, id in ipairs(node.Requires) do
			node.Requires[i] = `{category}_{id}`
		end
		for i, id in ipairs(node.Any) do
			node.Any[i] = `{category}_{id}`
		end
		table.insert(nodes, node)
		Trees.Nodes[node.Id] = node
	end
	local function stat(id: string, name: string, cost: number, x: number, y: number, requires: { string }?, any: { string }?)
		local def = Trees.Stats[name]
		counts[name] = (counts[name] or 0) + 1
		add({ Id = id, Name = `{def.Label} {counts[name]}`, Kind = "Stat", Stat = name, Value = def.Value, Cost = cost, X = x, Y = y, Requires = requires, Any = any })
	end
	local function special(id: string, index: number, cost: number, x: number, y: number, requires: { string }?, any: { string }?, ultimate: boolean?)
		local info = Specials[category][index]
		add({ Id = id, Name = info.Name, Kind = "Special", Skill = info.Key, Cost = cost, X = x, Y = y, Requires = requires, Any = any, Ultimate = ultimate })
	end
	stat("Root", "Damage", 1, 0, 0)
	local stats = { FIRST, SECOND, THIRD[category] }
	for p, path in ipairs(PATHS) do
		local n, x, list = path.Name, path.X, stats[p]
		stat(n .. "1", list[1], 1, x, 1, { "Root" })
		stat(n .. "2", list[2], 1, x - 1.5, 2, { n .. "1" })
		stat(n .. "3", list[3], 1, x + 1.5, 2, { n .. "1" })
		special(n .. "4", p, 2, x, 3, nil, { n .. "2", n .. "3" })
		stat(n .. "5", list[4], 2, x - 1.5, 4, { n .. "4" })
		stat(n .. "6", list[5], 2, x + 1.5, 4, { n .. "4" })
	end
	stat("J1", "Damage", 3, -2.5, 5, nil, { "A6", "B5" })
	stat("J2", "CritChance", 3, 2.5, 5, nil, { "B6", "C5" })
	special("M", 4, 4, 0, 6, nil, { "J1", "J2" })
	add({ Id = "U1", Name = "Aura of Mastery", Kind = "Passive", Passive = "Aura", Cost = 5, X = -3, Y = 7, Requires = { "M" }, Ultimate = true })
	special("U2", 5, 5, 0, 7, { "M" }, nil, true)
	add({ Id = "U3", Name = "Final Form", Kind = "Passive", Passive = "Finisher", Stat = "FinisherPower", Value = 0.25, Cost = 5, X = 3, Y = 7, Requires = { "M" }, Ultimate = true })
	Trees.ByCategory[category] = nodes
end

for _, category in ipairs(Trees.Order) do
	build(category)
end

-- What a node gives, in words.
function Trees.effect(node: { [string]: any }): string
	if node.Kind == "Special" then
		return "Special attack: equip it on the skill bar"
	elseif node.Passive == "Aura" then
		return "A glowing aura while this weapon type is in hand"
	elseif node.Passive == "Finisher" then
		return string.format(Trees.Stats.FinisherPower.Text, math.round(node.Value * 100)) .. ", a stronger last hit"
	end
	return string.format(Trees.Stats[node.Stat].Text, math.round(node.Value * 100))
end

return Trees
