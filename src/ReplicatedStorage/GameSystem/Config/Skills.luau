--!strict
-- Skills: 3 slots on the HUD (keys Z / X / C on PC, editable in Settings > Keys; LB / RB / Y on a gamepad; touch buttons
-- next to Attack on mobile). Slot 1 (Z) is the basic skill of the equipped weapon's category (Skills.Basic); slots 2 and 3
-- come from profile.EquippedSkills = { [slot 2..3] = skillId } (none exist yet).
-- A skill entry:
--   {
--     Id = "sword_dash_slash",      -- unique id
--     Name = "Dash Slash",          -- display name
--     Icon = "Sword",               -- icon name of UI/Kit/Icons or an asset id; nil = a generic icon
--     Cooldown = 8,                 -- seconds, checked on the server
--     Category = "Sword",           -- the weapon category it belongs to; its move is Config/WeaponMoves Moves[Category].Skill
--     Cost = nil,                   -- mana cost (the slot shakes when it is missing)
--     Element = nil,                -- optional element: tints the slot frame (Config/Skills ELEMENT_COLORS)
--   }
local Skills = {}

Skills.SLOT_COUNT = 3
Skills.USE_INTERVAL = 0.2 -- seconds between two UseSkill requests of a player (server rate limit)
Skills.COOLDOWN_TOLERANCE = 0.15 -- seconds a skill may come early (network jitter)
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

Skills.List = {
	{ Id = "sword_dash_slash", Name = "Dash Slash", Icon = "Sword", Cooldown = 8, Category = "Sword" },
	{ Id = "dagger_blade_storm", Name = "Blade Storm", Icon = "Dagger", Cooldown = 8, Category = "Dagger" },
	{ Id = "spear_cyclone_sweep", Name = "Cyclone Sweep", Icon = "Spear", Cooldown = 9, Category = "Spear" },
	{ Id = "heavy_earthbreaker", Name = "Earthbreaker", Icon = "Heavy", Cooldown = 10, Category = "Heavy" },
} :: { { [string]: any } }

Skills.ById = {} :: { [string]: { [string]: any } }
Skills.Basic = {} :: { [string]: { [string]: any } } -- [category] = its slot 1 skill
for _, skill in ipairs(Skills.List) do
	Skills.ById[skill.Id] = skill
	Skills.Basic[skill.Category] = skill
end

-- The skill in a slot for this weapon category and these equipped skills.
function Skills.at(slot: number, category: string?, equipped: any): { [string]: any }?
	if slot == 1 then
		return if category then Skills.Basic[category] else nil
	end
	local id = if typeof(equipped) == "table" then equipped[slot] else nil
	return if typeof(id) == "string" then Skills.ById[id] else nil
end

function Skills.validSlot(slot: any): boolean
	return typeof(slot) == "number" and slot == math.floor(slot) and slot >= 1 and slot <= Skills.SLOT_COUNT
end

return Skills
