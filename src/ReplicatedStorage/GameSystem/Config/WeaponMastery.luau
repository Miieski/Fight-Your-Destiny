--!strict
-- Weapon mastery (Round 8 part 6): XP per weapon type, points for its tree, kept for life (never touched by a Rebirth). Rules shared by
-- Services/MasteryService and UI/Pages/SkillTreePage; the server decides. Stats that count: Util/Stats.compute.
--   profile.Mastery[category] = { XP, Open, Nodes, Free }, profile.FreePicks, profile.FreePickAt, profile.EquippedSkills[category]
local Trees = require(script.Parent.WeaponSkillTrees)

local Mastery = {}

Mastery.XP = { Hit = 1, Normal = 6, MiniBoss = 40, Boss = 120, PerMinuteCap = 900 }
Mastery.MaxLevel = 60 -- a full tree costs 53 points
Mastery.StartTree = "Sword" -- open from the start: the starter weapon's type
Mastery.OpenPrice = { Sword = 0, Spear = 500, Dagger = 1500, Heavy = 5000, Ranged = 15000, Magic = 50000 } -- Gold, once
Mastery.FreePicks = 3
Mastery.FreeRespecSeconds = 600 -- after the first free pick
Mastery.RespecGold = 2000 -- per tree, after that window
Mastery.MaxEquipped = 3

-- XP to go from level - 1 to level.
function Mastery.xpFor(level: number): number
	return math.floor(60 * level ^ 1.4)
end

-- level, XP into it, XP of the next level (0 at the top)
function Mastery.levelOf(xp: number): (number, number, number)
	local level, left = 0, math.floor(xp or 0)
	while level < Mastery.MaxLevel do
		local need = Mastery.xpFor(level + 1)
		if left < need then
			return level, left, need
		end
		left -= need
		level += 1
	end
	return level, 0, 0
end

function Mastery.entry(data: { [string]: any }, category: string): { [string]: any }
	local all = data.Mastery
	return (if typeof(all) == "table" then all[category] else nil) or { XP = 0, Nodes = {}, Free = {} }
end

function Mastery.isOpen(data: { [string]: any }, category: string): boolean
	if category == Mastery.StartTree then
		return true
	end
	local entry = Mastery.entry(data, category)
	return entry.Open == true or next(entry.Free or {}) ~= nil
end

function Mastery.pointsSpent(entry: { [string]: any }): number
	local spent = 0
	for id in pairs(entry.Nodes or {}) do
		local node = Trees.Nodes[id]
		if node and not (entry.Free or {})[id] then
			spent += node.Cost
		end
	end
	return spent
end

function Mastery.pointsLeft(data: { [string]: any }, category: string): number
	local entry = Mastery.entry(data, category)
	return Mastery.levelOf(entry.XP or 0) - Mastery.pointsSpent(entry)
end

function Mastery.available(entry: { [string]: any }, node: { [string]: any }): boolean
	local nodes = entry.Nodes or {}
	for _, id in ipairs(node.Requires) do
		if not nodes[id] then
			return false
		end
	end
	if #node.Any == 0 then
		return true
	end
	for _, id in ipairs(node.Any) do
		if nodes[id] then
			return true
		end
	end
	return false
end

-- The sum of a tree's unlocked nodes: { [stat] = total }, and Aura = true.
function Mastery.bonuses(data: { [string]: any }, category: string?): { [string]: any }
	local out: { [string]: any } = {}
	if not category then
		return out
	end
	for id in pairs(Mastery.entry(data, category).Nodes or {}) do
		local node = Trees.Nodes[id]
		if node then
			if node.Stat then
				out[node.Stat] = (out[node.Stat] or 0) + node.Value
			end
			if node.Passive == "Aura" then
				out.Aura = true
			end
		end
	end
	return out
end

-- Is that special attack unlocked in its tree?
function Mastery.hasSkill(data: { [string]: any }, category: string, skillId: string): boolean
	for id in pairs(Mastery.entry(data, category).Nodes or {}) do
		local node = Trees.Nodes[id]
		if node and node.Skill == skillId then
			return true
		end
	end
	return false
end

return Mastery
