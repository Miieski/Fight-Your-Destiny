--!strict
-- Placeholder enemy models built from parts, one design per rig family ("Placeholder_<RigFamily>",
-- docs/enemies_npcs_pets_brief.txt Part E), so gameplay never waits for the Blender models.
--   EnemyRigs.template(def) -> Model   neutral template of the def's family / variant (cached)
--   EnemyRigs.build(def)    -> Model   a clone colored with the def's colors and scaled to def.Height
-- Model contract (the same for the future imported models in ServerStorage.Enemies.<id>):
--   PrimaryPart "Root": invisible hitbox, the physics root moved by EnemyService (attachment "RootAttachment").
--   Visible parts are joined to their parent part by a Motor6D named after the child part (Body, Head, LegFL, ArmR,
--   WingL, Seg2...), so the client animates them with Motor6D.Transform (Controllers/EnemyController).
--   Faces -Z, pivot at the center of the feet. Attributes: Rig, HalfHeight (root center above the feet).
local EnemyRigs = {}

local v = Vector3.new
local LOW_EYES = 0.25 -- eye colors darker than this stay plain, brighter ones glow (Neon)

-- { name, parent, size, center, joint?, role, shape? }   role = main | accent | eyes | dark | light | red
type Spec = { any }

local function legs(list: { Spec }, count: number, zs: { number }, reachX: number, bodyX: number, y: number, footHeight: number, thick: number, role: string?)
	for i = 1, count do
		local z = zs[i]
		for side = -1, 1, 2 do
			local tag = if side < 0 then "L" else "R"
			local legName = `Leg{tag}{i}`
			local legLength = reachX - bodyX
			table.insert(list, { legName, "Body", v(legLength, thick, thick), v(side * (bodyX + legLength / 2), y, z), v(side * bodyX, y, z), role or "main" })
			table.insert(list, { `Foot{tag}{i}`, legName, v(thick, footHeight, thick), v(side * reachX, y - footHeight / 2 + thick / 2, z), nil, role or "main" })
		end
	end
end

local function eyes(list: { Spec }, parent: string, x: number, y: number, z: number, size: number, ball: boolean?)
	table.insert(list, { "EyeL", parent, v(size, size, 0.12), v(-x, y, z), nil, "eyes", if ball then "Ball" else nil })
	table.insert(list, { "EyeR", parent, v(size, size, 0.12), v(x, y, z), nil, "eyes", if ball then "Ball" else nil })
end

local BUILDERS: { [string]: (any) -> { Spec } } = {}

BUILDERS.Quadruped = function(def)
	local list: { Spec } = {}
	if def.Long then
		table.insert(list, { "Body", "Root", v(2.2, 1.1, 5.0), v(0, 1.2, 0), nil, "main" })
		table.insert(list, { "Head", "Body", v(1.5, 0.8, 2.4), v(0, 1.3, -3.6), v(0, 1.3, -2.5), "main" })
		table.insert(list, { "Teeth", "Head", v(1.3, 0.15, 2.0), v(0, 0.95, -3.8), nil, "accent" })
		eyes(list, "Head", 0.45, 1.8, -3.0, 0.32, true)
		for i, z in ipairs({ -1.6, 1.6 }) do
			table.insert(list, { if i == 1 then "LegFL" else "LegBL", "Body", v(0.6, 0.7, 0.6), v(-1.1, 0.35, z), v(-1.1, 0.7, z), "main" })
			table.insert(list, { if i == 1 then "LegFR" else "LegBR", "Body", v(0.6, 0.7, 0.6), v(1.1, 0.35, z), v(1.1, 0.7, z), "main" })
		end
		table.insert(list, { "Tail", "Body", v(1.0, 0.7, 3.2), v(0, 1.1, 4.1), v(0, 1.1, 2.5), "main" })
		table.insert(list, { "Ridge", "Body", v(0.5, 0.3, 4.4), v(0, 1.9, 0.2), nil, "accent" })
		return list
	end
	table.insert(list, { "Body", "Root", v(2.2, 1.6, 3.6), v(0, 1.9, 0), nil, "main" })
	table.insert(list, { "Belly", "Body", v(1.8, 0.5, 2.8), v(0, 1.25, 0), nil, "light" })
	table.insert(list, { "Head", "Body", v(1.6, 1.4, 1.5), v(0, 2.45, -2.3), v(0, 2.2, -1.6), "main" })
	table.insert(list, { "Snout", "Head", v(0.95, 0.7, 0.8), v(0, 2.05, -3.3), nil, "light" })
	table.insert(list, { "Nose", "Snout", v(0.4, 0.3, 0.1), v(0, 2.3, -3.72), nil, "dark" })
	table.insert(list, { "TuskL", "Snout", v(0.15, 0.45, 0.15), v(-0.42, 1.85, -3.5), nil, "accent" })
	table.insert(list, { "TuskR", "Snout", v(0.15, 0.45, 0.15), v(0.42, 1.85, -3.5), nil, "accent" })
	table.insert(list, { "EarL", "Head", v(0.4, 0.6, 0.25), v(-0.55, 3.4, -2.15), nil, "main" })
	table.insert(list, { "EarR", "Head", v(0.4, 0.6, 0.25), v(0.55, 3.4, -2.15), nil, "main" })
	eyes(list, "Head", 0.42, 2.7, -3.06, 0.3, true)
	table.insert(list, { "LegFL", "Body", v(0.55, 1.3, 0.55), v(-0.7, 0.65, -1.2), v(-0.7, 1.3, -1.2), "main" })
	table.insert(list, { "LegFR", "Body", v(0.55, 1.3, 0.55), v(0.7, 0.65, -1.2), v(0.7, 1.3, -1.2), "main" })
	table.insert(list, { "LegBL", "Body", v(0.55, 1.3, 0.55), v(-0.7, 0.65, 1.2), v(-0.7, 1.3, 1.2), "main" })
	table.insert(list, { "LegBR", "Body", v(0.55, 1.3, 0.55), v(0.7, 0.65, 1.2), v(0.7, 1.3, 1.2), "main" })
	table.insert(list, { "Tail", "Body", v(0.35, 0.35, 1.2), v(0, 2.35, 2.35), v(0, 2.35, 1.8), "main" })
	table.insert(list, { "Mane", "Body", v(0.5, 0.35, 2.6), v(0, 2.85, -0.2), nil, "accent" })
	return list
end

local function biped(def, bulky: boolean, boss: boolean): { Spec }
	local list: { Spec } = {}
	local tw, th, td = if bulky then 2.6 else 1.8, if bulky then 2.3 else 2.0, if bulky then 1.5 else 1.0
	local ax = tw / 2 + (if bulky then 0.45 else 0.3)
	local arm = if bulky then v(0.9, 2.3, 0.9) else v(0.6, 1.9, 0.6)
	local leg = if bulky then v(0.9, 2.0, 0.9) else v(0.7, 2.0, 0.7)
	local lx = if bulky then 0.6 else 0.45
	local torsoY = 2.0 + th / 2
	local headSize = if bulky then 1.4 else 1.55
	local headY = 2.0 + th + headSize / 2
	table.insert(list, { "Torso", "Root", v(tw, th, td), v(0, torsoY, 0), nil, "main" })
	table.insert(list, { "Belt", "Torso", v(tw + 0.1, 0.35, td + 0.1), v(0, 2.2, 0), nil, "accent" })
	table.insert(list, { "Head", "Torso", v(headSize, headSize, headSize * 0.92), v(0, headY, 0), v(0, 2.0 + th, 0), "light" })
	eyes(list, "Head", headSize * 0.22, headY + 0.1, -headSize * 0.47, 0.26, true)
	table.insert(list, { "Hat", "Head", v(headSize + 0.2, 0.45, headSize + 0.1), v(0, headY + headSize / 2 + 0.15, 0), nil, "accent" })
	if boss then
		table.insert(list, { "Crown", "Head", v(headSize + 0.4, 0.8, headSize + 0.3), v(0, headY + headSize / 2 + 0.7, 0), nil, "accent" })
		table.insert(list, { "Cape", "Torso", v(tw + 0.4, th + 1.4, 0.25), v(0, torsoY - 0.5, td / 2 + 0.2), nil, "accent" })
	end
	table.insert(list, { "ArmL", "Torso", arm, v(-ax, torsoY - 0.1, 0), v(-ax, torsoY + arm.Y / 2 - 0.4, 0), "main" })
	table.insert(list, { "ArmR", "Torso", arm, v(ax, torsoY - 0.1, 0), v(ax, torsoY + arm.Y / 2 - 0.4, 0), "main" })
	if def.AttackType == "ranged" then
		table.insert(list, { "Weapon", "ArmL", v(0.15, 2.2, 0.35), v(-ax, torsoY - 0.6, -0.55), nil, "dark" })
	elseif boss then
		table.insert(list, { "Weapon", "ArmR", v(0.35, 5.2, 0.35), v(ax, torsoY - 0.4, -0.7), nil, "accent" })
		table.insert(list, { "WeaponTop", "Weapon", v(0.9, 0.9, 0.9), v(ax, torsoY + 2.3, -0.7), nil, "eyes", "Ball" })
	else
		table.insert(list, { "Weapon", "ArmR", v(0.22, 0.22, if bulky then 2.8 else 2.2), v(ax, torsoY - 1.0, -1.0), nil, "dark" })
	end
	table.insert(list, { "LegL", "Torso", leg, v(-lx, 1.0, 0), v(-lx, 2.0, 0), "dark" })
	table.insert(list, { "LegR", "Torso", leg, v(lx, 1.0, 0), v(lx, 2.0, 0), "dark" })
	return list
end
BUILDERS.Biped = function(def)
	return biped(def, def.Bulky == true or def.Tier == "mini", false)
end
BUILDERS.BossBiped = function(def)
	return biped(def, true, true)
end

BUILDERS.Gorilla = function(def)
	local list: { Spec } = {}
	table.insert(list, { "Body", "Root", v(3.2, 2.6, 2.2), v(0, 3.2, 0.2), nil, "main" })
	table.insert(list, { "Chest", "Body", v(2.4, 1.6, 0.4), v(0, 3.3, -0.95), nil, "light" })
	table.insert(list, { "Head", "Body", v(1.6, 1.5, 1.5), v(0, 4.4, -1.3), v(0, 4.1, -0.8), "main" })
	table.insert(list, { "Face", "Head", v(1.1, 0.9, 0.2), v(0, 4.25, -2.1), nil, "light" })
	eyes(list, "Head", 0.33, 4.55, -2.22, 0.24, true)
	table.insert(list, { "Markings", "Body", v(2.0, 0.35, 2.3), v(0, 4.1, 0.2), nil, "accent" })
	table.insert(list, { "ArmL", "Body", v(1.0, 3.4, 1.0), v(-2.15, 2.2, -0.6), v(-2.15, 3.9, -0.6), "main" })
	table.insert(list, { "ArmR", "Body", v(1.0, 3.4, 1.0), v(2.15, 2.2, -0.6), v(2.15, 3.9, -0.6), "main" })
	table.insert(list, { "BracerL", "ArmL", v(1.15, 0.6, 1.15), v(-2.15, 1.1, -0.6), nil, "accent" })
	table.insert(list, { "BracerR", "ArmR", v(1.15, 0.6, 1.15), v(2.15, 1.1, -0.6), nil, "accent" })
	table.insert(list, { "LegL", "Body", v(0.9, 1.9, 0.9), v(-0.85, 0.95, 0.8), v(-0.85, 1.9, 0.8), "main" })
	table.insert(list, { "LegR", "Body", v(0.9, 1.9, 0.9), v(0.85, 0.95, 0.8), v(0.85, 1.9, 0.8), "main" })
	return list
end

BUILDERS.Bird = function(def)
	local list: { Spec } = {}
	table.insert(list, { "Body", "Root", v(1.2, 1.1, 1.8), v(0, 1.5, 0), nil, "main" })
	table.insert(list, { "Head", "Body", v(0.95, 0.9, 0.95), v(0, 2.15, -1.0), v(0, 1.9, -0.8), "main" })
	table.insert(list, { "Beak", "Head", v(0.32, 0.26, 0.7), v(0, 2.02, -1.8), nil, "accent" })
	eyes(list, "Head", 0.3, 2.3, -1.45, 0.2, true)
	table.insert(list, { "WingL", "Body", v(1.9, 0.15, 1.1), v(-1.55, 1.75, 0.05), v(-0.6, 1.75, 0.05), "main" })
	table.insert(list, { "WingR", "Body", v(1.9, 0.15, 1.1), v(1.55, 1.75, 0.05), v(0.6, 1.75, 0.05), "main" })
	table.insert(list, { "Tail", "Body", v(0.8, 0.15, 0.8), v(0, 1.55, 1.25), v(0, 1.55, 0.9), "accent" })
	table.insert(list, { "LegL", "Body", v(0.15, 0.6, 0.15), v(-0.3, 0.7, 0.1), v(-0.3, 1.0, 0.1), "accent" })
	table.insert(list, { "LegR", "Body", v(0.15, 0.6, 0.15), v(0.3, 0.7, 0.1), v(0.3, 1.0, 0.1), "accent" })
	return list
end

BUILDERS.Serpent = function(def)
	local list: { Spec } = {}
	table.insert(list, { "Seg1", "Root", v(1.0, 0.9, 1.4), v(0, 0.45, -1.0), nil, "main" })
	table.insert(list, { "Head", "Seg1", v(1.25, 0.9, 1.35), v(0, 0.75, -2.3), v(0, 0.6, -1.7), "main" })
	eyes(list, "Head", 0.4, 1.0, -2.8, 0.24, true)
	table.insert(list, { "Tongue", "Head", v(0.15, 0.06, 0.6), v(0, 0.45, -3.2), nil, "red" })
	local sizes = { v(0.95, 0.8, 1.4), v(0.85, 0.7, 1.3), v(0.7, 0.6, 1.2), v(0.5, 0.45, 1.0) }
	local z = -1.0
	for i, size in ipairs(sizes) do
		local prev = if i == 1 then "Seg1" else `Seg{i}`
		local front = z + 0.7
		z = front + size.Z / 2 + 0.05
		table.insert(list, { `Seg{i + 1}`, prev, size, v(0, size.Y / 2, z), v(0, size.Y / 2, front), if i % 2 == 1 then "accent" else "main" })
		z += size.Z / 2 - 0.7
	end
	return list
end

BUILDERS.Arachnid = function(def)
	local list: { Spec } = {}
	table.insert(list, { "Body", "Root", v(1.5, 1.0, 1.5), v(0, 1.6, -0.6), nil, "main" })
	table.insert(list, { "Abdomen", "Body", v(2.2, 1.7, 2.3), v(0, 2.0, 1.2), v(0, 1.8, 0.2), "main" })
	table.insert(list, { "Mark", "Abdomen", v(1.0, 0.45, 1.2), v(0, 2.95, 1.2), nil, "accent" })
	eyes(list, "Body", 0.32, 1.85, -1.37, 0.22, true)
	table.insert(list, { "EyeC", "Body", v(0.18, 0.18, 0.1), v(0, 2.02, -1.37), nil, "eyes", "Ball" })
	table.insert(list, { "FangL", "Body", v(0.2, 0.55, 0.2), v(-0.25, 0.95, -1.3), nil, "accent" })
	table.insert(list, { "FangR", "Body", v(0.2, 0.55, 0.2), v(0.25, 0.95, -1.3), nil, "accent" })
	legs(list, 4, { -1.1, -0.6, -0.1, 0.4 }, 2.55, 0.7, 1.75, 1.75, 0.25)
	if def.Id == "desert_scorpion" then
		table.insert(list, { "Tail", "Abdomen", v(0.5, 0.5, 1.5), v(0, 2.6, 2.8), v(0, 2.4, 2.2), "main" })
		table.insert(list, { "Tail2", "Tail", v(0.45, 1.4, 0.45), v(0, 3.4, 3.4), nil, "main" })
		table.insert(list, { "Stinger", "Tail2", v(0.3, 0.6, 0.6), v(0, 4.1, 3.0), nil, "accent" })
		table.insert(list, { "ArmL", "Body", v(0.5, 0.5, 1.2), v(-0.9, 1.4, -1.6), v(-0.7, 1.4, -1.1), "main" })
		table.insert(list, { "ArmR", "Body", v(0.5, 0.5, 1.2), v(0.9, 1.4, -1.6), v(0.7, 1.4, -1.1), "main" })
		table.insert(list, { "ClawL", "ArmL", v(0.7, 0.5, 0.8), v(-0.95, 1.4, -2.5), nil, "accent" })
		table.insert(list, { "ClawR", "ArmR", v(0.7, 0.5, 0.8), v(0.95, 1.4, -2.5), nil, "accent" })
	end
	return list
end

BUILDERS.Crustacean = function(def)
	local list: { Spec } = {}
	table.insert(list, { "Body", "Root", v(2.8, 1.1, 2.0), v(0, 1.3, 0), nil, "main" })
	table.insert(list, { "Shell", "Body", v(2.2, 0.35, 1.6), v(0, 1.95, 0.05), nil, "accent" })
	table.insert(list, { "StalkL", "Body", v(0.2, 0.6, 0.2), v(-0.45, 2.1, -0.8), nil, "main" })
	table.insert(list, { "StalkR", "Body", v(0.2, 0.6, 0.2), v(0.45, 2.1, -0.8), nil, "main" })
	eyes(list, "Body", 0.45, 2.5, -0.8, 0.3, true)
	table.insert(list, { "ArmL", "Body", v(0.8, 0.7, 1.3), v(-1.7, 1.5, -1.4), v(-1.2, 1.4, -0.8), "main" })
	table.insert(list, { "ArmR", "Body", v(0.8, 0.7, 1.3), v(1.7, 1.5, -1.4), v(1.2, 1.4, -0.8), "main" })
	table.insert(list, { "ClawL", "ArmL", v(1.1, 1.0, 1.0), v(-1.9, 1.6, -2.45), nil, "accent" })
	table.insert(list, { "ClawR", "ArmR", v(1.1, 1.0, 1.0), v(1.9, 1.6, -2.45), nil, "accent" })
	legs(list, 3, { -0.2, 0.35, 0.9 }, 2.6, 1.3, 1.1, 1.1, 0.22)
	return list
end

BUILDERS.Insect = function(def)
	local list: { Spec } = {}
	table.insert(list, { "Body", "Root", v(2.2, 1.3, 2.6), v(0, 1.3, 0.3), nil, "main" })
	table.insert(list, { "Trim", "Body", v(2.32, 0.22, 2.72), v(0, 1.0, 0.3), nil, "accent" })
	table.insert(list, { "Line", "Body", v(0.12, 0.1, 2.5), v(0, 1.97, 0.3), nil, "accent" })
	table.insert(list, { "Head", "Body", v(1.2, 0.8, 0.9), v(0, 1.05, -1.35), v(0, 1.05, -1.0), "main" })
	table.insert(list, { "Horn", "Head", v(0.25, 0.9, 0.25), v(0, 1.6, -1.7), nil, "accent" })
	eyes(list, "Head", 0.35, 1.2, -1.81, 0.2, true)
	legs(list, 3, { -0.6, 0.2, 1.0 }, 2.1, 1.0, 0.9, 0.9, 0.2)
	return list
end

BUILDERS.Fish = function(def)
	local list: { Spec } = {}
	table.insert(list, { "Body", "Root", v(0.9, 1.5, 2.4), v(0, 1.2, 0), nil, "main" })
	table.insert(list, { "Belly", "Body", v(0.95, 0.5, 1.8), v(0, 0.65, -0.1), nil, "accent" })
	table.insert(list, { "Tail", "Body", v(0.15, 1.3, 1.0), v(0, 1.2, 1.65), v(0, 1.2, 1.2), "main" })
	table.insert(list, { "FinTop", "Body", v(0.12, 0.6, 1.0), v(0, 2.15, 0.1), nil, "main" })
	table.insert(list, { "FinL", "Body", v(0.6, 0.12, 0.5), v(-0.7, 1.0, -0.2), v(-0.45, 1.0, -0.2), "main" })
	table.insert(list, { "FinR", "Body", v(0.6, 0.12, 0.5), v(0.7, 1.0, -0.2), v(0.45, 1.0, -0.2), "main" })
	eyes(list, "Body", 0.46, 1.5, -0.8, 0.26, true)
	if def.Bill then
		table.insert(list, { "Bill", "Body", v(0.18, 0.18, 2.0), v(0, 1.35, -2.2), nil, "accent" })
	else
		table.insert(list, { "Jaw", "Body", v(0.8, 0.45, 0.6), v(0, 0.85, -1.35), v(0, 0.95, -1.1), "accent" })
		table.insert(list, { "Teeth", "Jaw", v(0.7, 0.15, 0.15), v(0, 1.12, -1.6), nil, "light" })
	end
	return list
end

BUILDERS.Amphibian = function(def)
	local list: { Spec } = {}
	table.insert(list, { "Body", "Root", v(2.0, 1.3, 2.0), v(0, 1.0, 0.3), nil, "main" })
	table.insert(list, { "Head", "Body", v(1.9, 0.9, 1.5), v(0, 1.55, -0.9), v(0, 1.4, -0.3), "main" })
	table.insert(list, { "Mouth", "Head", v(1.6, 0.12, 0.2), v(0, 1.25, -1.62), nil, "dark" })
	eyes(list, "Head", 0.6, 2.1, -1.0, 0.62, true)
	table.insert(list, { "Spot1", "Body", v(0.6, 0.15, 0.6), v(-0.4, 1.66, 0.5), nil, "accent" })
	table.insert(list, { "Spot2", "Body", v(0.5, 0.15, 0.5), v(0.5, 1.66, 0.0), nil, "accent" })
	table.insert(list, { "Spot3", "Body", v(0.4, 0.15, 0.4), v(0.3, 1.66, 0.9), nil, "accent" })
	table.insert(list, { "LegBL", "Body", v(0.8, 0.6, 1.5), v(-1.15, 0.35, 0.6), v(-0.9, 0.6, 0.4), "main" })
	table.insert(list, { "LegBR", "Body", v(0.8, 0.6, 1.5), v(1.15, 0.35, 0.6), v(0.9, 0.6, 0.4), "main" })
	table.insert(list, { "LegFL", "Body", v(0.35, 0.75, 0.35), v(-0.7, 0.38, -0.8), v(-0.7, 0.75, -0.8), "main" })
	table.insert(list, { "LegFR", "Body", v(0.35, 0.75, 0.35), v(0.7, 0.38, -0.8), v(0.7, 0.75, -0.8), "main" })
	return list
end

BUILDERS.Golem = function(def)
	local list: { Spec } = {}
	table.insert(list, { "Body", "Root", v(3.2, 2.8, 2.1), v(0, 4.1, 0), nil, "main" })
	table.insert(list, { "Head", "Body", v(1.4, 1.2, 1.3), v(0, 6.0, -0.3), v(0, 5.5, -0.2), "main" })
	table.insert(list, { "EyeL", "Head", v(0.32, 0.2, 0.12), v(-0.3, 6.1, -0.97), nil, "eyes" })
	table.insert(list, { "EyeR", "Head", v(0.32, 0.2, 0.12), v(0.3, 6.1, -0.97), nil, "eyes" })
	table.insert(list, { "ShoulderL", "Body", v(1.7, 1.7, 1.7), v(-2.0, 5.4, 0), nil, "main", "Ball" })
	table.insert(list, { "ShoulderR", "Body", v(1.7, 1.7, 1.7), v(2.0, 5.4, 0), nil, "main", "Ball" })
	table.insert(list, { "Moss", "Body", v(2.2, 0.3, 1.6), v(-0.3, 5.55, 0.2), nil, "accent" })
	table.insert(list, { "Crystal", "Body", v(0.6, 1.3, 0.6), v(0.6, 5.9, 0.85), nil, "eyes" })
	table.insert(list, { "Crystal2", "Body", v(0.45, 0.9, 0.45), v(-0.55, 5.7, 0.95), nil, "eyes" })
	table.insert(list, { "ArmL", "Body", v(1.3, 2.6, 1.3), v(-2.4, 3.6, 0), v(-2.2, 5.0, 0), "main" })
	table.insert(list, { "ArmR", "Body", v(1.3, 2.6, 1.3), v(2.4, 3.6, 0), v(2.2, 5.0, 0), "main" })
	table.insert(list, { "FistL", "ArmL", v(1.8, 1.8, 1.8), v(-2.4, 1.9, 0), nil, "main", "Ball" })
	table.insert(list, { "FistR", "ArmR", v(1.8, 1.8, 1.8), v(2.4, 1.9, 0), nil, "main", "Ball" })
	table.insert(list, { "Rune", "ArmR", v(0.12, 0.9, 0.9), v(3.06, 3.7, 0), nil, "eyes" })
	table.insert(list, { "LegL", "Body", v(1.3, 2.7, 1.3), v(-0.9, 1.35, 0), v(-0.9, 2.7, 0), "main" })
	table.insert(list, { "LegR", "Body", v(1.3, 2.7, 1.3), v(0.9, 1.35, 0), v(0.9, 2.7, 0), "main" })
	return list
end

BUILDERS.Snowman = function(def)
	local list: { Spec } = {}
	table.insert(list, { "Body", "Root", v(2.6, 2.6, 2.6), v(0, 1.3, 0), nil, "main", "Ball" })
	table.insert(list, { "Middle", "Body", v(2.0, 2.0, 2.0), v(0, 3.1, 0), v(0, 2.4, 0), "main", "Ball" })
	table.insert(list, { "Head", "Middle", v(1.5, 1.5, 1.5), v(0, 4.45, 0), v(0, 3.9, 0), "main", "Ball" })
	eyes(list, "Head", 0.3, 4.6, -0.7, 0.28, true)
	table.insert(list, { "Nose", "Head", v(0.2, 0.2, 0.6), v(0, 4.4, -0.95), nil, "red" })
	table.insert(list, { "ArmL", "Middle", v(1.8, 0.18, 0.18), v(-1.75, 3.4, 0), v(-0.9, 3.3, 0), "accent" })
	table.insert(list, { "ArmR", "Middle", v(1.8, 0.18, 0.18), v(1.75, 3.4, 0), v(0.9, 3.3, 0), "accent" })
	table.insert(list, { "Hat", "Head", v(1.0, 0.9, 1.0), v(0, 5.45, 0), nil, "dark" })
	table.insert(list, { "Brim", "Hat", v(1.5, 0.12, 1.5), v(0, 5.05, 0), nil, "dark" })
	return list
end

BUILDERS.Floater = function(def)
	local list: { Spec } = {}
	table.insert(list, { "Body", "Root", v(1.8, 1.8, 1.8), v(0, 2.6, 0), nil, "main", "Ball" })
	table.insert(list, { "Tail", "Body", v(1.0, 1.6, 1.0), v(0, 1.1, 0), v(0, 1.9, 0), "main" })
	table.insert(list, { "Tail2", "Tail", v(0.55, 0.8, 0.55), v(0, 0.4, 0), nil, "main" })
	table.insert(list, { "EyeL", "Body", v(0.3, 0.38, 0.12), v(-0.35, 2.8, -0.88), nil, "eyes" })
	table.insert(list, { "EyeR", "Body", v(0.3, 0.38, 0.12), v(0.35, 2.8, -0.88), nil, "eyes" })
	table.insert(list, { "ArmL", "Body", v(0.4, 1.3, 0.4), v(-1.2, 2.4, 0), v(-1.0, 2.9, 0), "main" })
	table.insert(list, { "ArmR", "Body", v(0.4, 1.3, 0.4), v(1.2, 2.4, 0), v(1.0, 2.9, 0), "main" })
	table.insert(list, { "Crown", "Body", v(1.0, 0.5, 1.0), v(0, 3.65, 0), nil, "accent" })
	return list
end

local function variant(def: any): string
	local rig = def.Rig or "Biped"
	local tags = {}
	if def.Long then table.insert(tags, "Long") end
	if def.Bill then table.insert(tags, "Bill") end
	if rig == "Biped" and (def.Bulky or def.Tier == "mini") then table.insert(tags, "Bulky") end
	if def.AttackType == "ranged" and (rig == "Biped") then table.insert(tags, "Ranged") end
	if def.Id == "desert_scorpion" then table.insert(tags, "Scorpion") end
	return if #tags > 0 then rig .. "_" .. table.concat(tags, "_") else rig
end
EnemyRigs.variant = variant

local templates: { [string]: Model } = {}

-- Neutral template (white main, gray accent...) of a rig family / variant, built once.
function EnemyRigs.template(def: any): Model
	local key = variant(def)
	if templates[key] then
		return templates[key]
	end
	local builder = BUILDERS[def.Rig or "Biped"] or BUILDERS.Biped
	local specs = builder(def)
	local model = Instance.new("Model")
	model.Name = "Placeholder_" .. key
	local parts: { [string]: BasePart } = {}
	local minV, maxV = v(math.huge, math.huge, math.huge), v(-math.huge, -math.huge, -math.huge)
	for _, spec in ipairs(specs) do
		local name, size, center, role, shape = spec[1], spec[3], spec[4], spec[6], spec[7]
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = CFrame.new(center)
		if shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		end
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.CanCollide, part.CanTouch = false, false
		part.CanQuery = true
		part.Massless = true
		part.CastShadow = true
		part:SetAttribute("ColorRole", role)
		part.Parent = model
		parts[name] = part
		local half = size / 2
		minV = minV:Min(center - half)
		maxV = maxV:Max(center + half)
	end
	minV = Vector3.new(minV.X, 0, minV.Z)
	local bounds = maxV - minV
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = v(math.max(1, bounds.X), math.max(1, bounds.Y), math.max(1, bounds.Z))
	root.CFrame = CFrame.new((minV + maxV) / 2)
	root.Transparency = 1
	root.CanCollide, root.CanTouch = false, false
	root.CanQuery = true
	root.Parent = model
	local attachment = Instance.new("Attachment")
	attachment.Name = "RootAttachment"
	attachment.Parent = root
	parts.Root = root
	for _, spec in ipairs(specs) do
		local part, parent = parts[spec[1]], parts[spec[2]] or root
		local joint = CFrame.new(spec[5] or spec[4])
		local motor = Instance.new("Motor6D")
		motor.Name = spec[1]
		motor.Part0 = parent
		motor.Part1 = part
		motor.C0 = parent.CFrame:Inverse() * joint
		motor.C1 = part.CFrame:Inverse() * joint
		motor.Parent = part
	end
	model.PrimaryPart = root
	root.PivotOffset = CFrame.new(0, -root.Size.Y / 2, 0)
	model:SetAttribute("Rig", def.Rig or "Biped")
	model:SetAttribute("HalfHeight", root.Size.Y / 2)
	model:SetAttribute("RefHeight", if def.Rig == "Serpent" or def.Long then root.Size.Z else root.Size.Y)
	templates[key] = model
	return model
end

local function luminance(c: Color3): number
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

-- A colored, scaled copy for one enemy: main / accent / eyes from the config, the rest derived.
function EnemyRigs.build(def: any): Model
	local template = EnemyRigs.template(def)
	local model = template:Clone()
	model.Name = def.Id
	local main: Color3 = def.Color or Color3.fromRGB(200, 200, 200)
	local accent: Color3 = def.Accent or main
	local eyeColor: Color3 = def.Eyes or Color3.fromRGB(20, 18, 24)
	local h, s, val = main:ToHSV()
	local colors = {
		main = main,
		accent = accent,
		eyes = eyeColor,
		dark = Color3.fromHSV(h, s, math.max(0, val * 0.55)),
		light = Color3.fromHSV(h, s * 0.6, math.min(1, val * 1.18 + 0.05)),
		red = Color3.fromRGB(210, 50, 60),
	}
	local glow = luminance(eyeColor) > LOW_EYES
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "Root" then
			local role = part:GetAttribute("ColorRole") or "main"
			part.Color = colors[role] or main
			if role == "eyes" and glow then
				part.Material = Enum.Material.Neon
			end
			if def.Rig == "Floater" and role == "main" then
				part.Transparency = 0.15
			end
		end
	end
	local reference = model:GetAttribute("RefHeight") or 1
	local scale = (def.Height or reference) / reference
	model:ScaleTo(scale)
	local root = model.PrimaryPart :: BasePart
	root.PivotOffset = CFrame.new(0, -root.Size.Y / 2, 0) -- pivot at the feet
	model:SetAttribute("HalfHeight", root.Size.Y / 2)
	return model
end

return EnemyRigs
