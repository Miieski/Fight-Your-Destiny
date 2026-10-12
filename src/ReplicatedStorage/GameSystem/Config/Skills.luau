--!strict
-- Skills (docs/weapons_combat_brief.txt Phase 2). Only the framework exists: 3 slots on the HUD (keys Z / X / C
-- on PC, editable in Settings > Keys; LB / RB / Y on a gamepad; touch buttons next to Attack on mobile). The list
-- is empty and SkillService answers "not available" until the skills are built.
-- profile.EquippedSkills = { [slot 1..3] = skillId } (empty for now).
--
-- Schema of a skill entry (for later):
--   {
--     Id = "sword_whirlwind",       -- unique id, the value stored in profile.EquippedSkills
--     Name = "Whirlwind",           -- display name
--     Icon = "rbxassetid://...",    -- 3D icon (Icons/Skills/<Id>_icon.png); nil = a generic icon
--     Cooldown = 8,                 -- seconds, checked on the server
--     Category = "Sword",           -- the weapon category that can use it (nil = any weapon)
--     Animation = "Sword_Skill1",   -- clip of Config/CombatAnimations
--     VFX = "Sword_Whirlwind",      -- effect in ReplicatedStorage.Assets.VFX
--     SFX = "SkillWhirlwind",       -- sound of Util/Sfx
--     Cost = nil,                   -- optional resource cost (the slot shakes when it is missing)
--     Element = nil,                -- optional element: tints the slot frame (Config/Skills ELEMENT_COLORS)
--   }
local Skills = {}

Skills.SLOT_COUNT = 3
Skills.USE_INTERVAL = 0.2 -- seconds between two UseSkill requests of a player (server rate limit)
Skills.RESOURCE_ERROR = "resource" -- UseSkill answer when the cost is missing: the slot shakes

Skills.Text = {
	ComingSoon = "Skills are coming soon",
	NotAvailable = "not available",
	InvalidSlot = "invalid slot",
}

-- Frame color of a slot whose skill has an element (zone elements, weapon doc section 4).
Skills.ELEMENT_COLORS = {
	Nature = Color3.fromRGB(110, 200, 90),
	Sand = Color3.fromRGB(232, 196, 110),
	Poison = Color3.fromRGB(150, 220, 60),
	Frost = Color3.fromRGB(150, 210, 255),
} :: { [string]: Color3 }

Skills.List = {} :: { { [string]: any } }

Skills.ById = {} :: { [string]: { [string]: any } }
for _, skill in ipairs(Skills.List) do
	Skills.ById[skill.Id] = skill
end

function Skills.validSlot(slot: any): boolean
	return typeof(slot) == "number" and slot == math.floor(slot) and slot >= 1 and slot <= Skills.SLOT_COUNT
end

return Skills
