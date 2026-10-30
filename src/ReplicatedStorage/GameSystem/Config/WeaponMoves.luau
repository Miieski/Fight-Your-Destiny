--!strict
-- Weapon definitions, data only (docs/animation_system.md): every move of every category, read by the server (hits,
-- timings, validation) and by every client (Combat/AnimationController, VFX, Sfx). Adding a weapon = a new entry here,
-- its clips in Config/CombatAnimations; no new code.
-- Moves[category] = {
--   Class      "Melee" | "Bow" | "Staff" (input and server path)
--   Pair       true: the weapon is one in each hand (WeaponService adds the off-hand copy)
--   Speed      attribute that speeds the weapon up (Util/Stats, with the rarity; default Dexterity)
--   Dps        Common damage per second in zone 1, in tens: Sword 1.0 = 10 / s. WeaponCategories derives the category's
--              DamageMult from it, so tuning a timing never changes the DPS of a weapon
--   Shape      the category's hit shape, see below
--   Steps      the combo in order, the last one with Finisher = true
--   Heavy      the hold attack; Air the jump attack; Dash the dash strike; Skill the Z skill
-- }
-- Shape: Kind "Arc" / "Cone" (Angle in degrees, Radius), "Line" (Length x Width), "Projectile" (Speed, Range), "AoE" (cast
-- at the aim point within Range, Radius x (1 + Magic radius bonus)), "Circle" (Radius around the attacker). MaxTargets =
-- enemies per hit. A move's Shape fields replace the category's (false removes one: Heavy SlamRadius).
-- A move (times in seconds at attack speed x1; they shrink with Stats AttackSpeed):
--   Name       shown nowhere, the reference for clips, VFX and sounds
--   Clip       clip of Config/CombatAnimations (default <Category>_Attack<step> / _Heavy / _JumpAttack / _DashAttack)
--   Impact     press -> first damaging frame (= the clip's Hit marker)
--   Duration   press -> the next move may start. The server refuses anything faster (Combat.RateTolerance)
--   Damage     multiplier of the weapon's damage
--   Hits       extra impacts of the same move: { seconds after the press, ... }
--   Finisher   the end of the combo: bigger feedback, GuardBreakMult on a staggered enemy
--   Knockback  studs a normal enemy is pushed (mini-bosses and bosses resist); nil = EnemyService default
--   Stagger    seconds every enemy hit is staggered
--   Lunge      studs the attacker steps forward (heavy, jump, dash only: light steps never move the body),
--              LungeSeconds = its duration (default Combat.Feel.LungeSeconds)
--   Heavy: MaxCharge seconds of hold to the full charge, ChargeDamage and ChargeRadius = bonus at full charge
--   Skill: the Z move, its cooldown and cost are in Config/Skills
--   Air: Hang = seconds the body stays still before the dive / the shot; Shots, Spread (Ranged volley)
local WeaponMoves = {}

WeaponMoves.Input = {
	HoldThreshold = 0.22, -- a press still down after this long flows into the heavy / charged attack
	BufferWindow = 0.35, -- a press in the last 35% of a move queues the next one
	ComboReset = 0.8, -- seconds after a move's Duration without an attack: the combo restarts
	GuardBreakMult = 1.5, -- finisher or heavy on a staggered enemy (enemies have no guard: stagger = guard broken)
}

-- Attack speed bonus of the weapon's rarity tier (added to the attribute's; Attributes.Caps.AttackSpeed caps the sum).
WeaponMoves.RaritySpeed = { 0, 0.05, 0.1, 0.15, 0.2, 0.3, 0.4, 0.5 }

WeaponMoves.Moves = {
	Sword = {
		Class = "Melee", Dps = 1.0,
		Shape = { Kind = "Arc", Angle = 120, Radius = 6, MaxTargets = 3 },
		Steps = {
			{ Name = "RightSlash", Impact = 0.1, Duration = 0.34, Damage = 1.0 },
			{ Name = "LeftSlash", Impact = 0.1, Duration = 0.34, Damage = 1.0 },
			{ Name = "RisingSlash", Impact = 0.1, Duration = 0.34, Damage = 1.05 },
			{ Name = "DownCut", Impact = 0.11, Duration = 0.36, Damage = 1.15 },
			{ Name = "SpinSlash", Impact = 0.14, Duration = 0.62, Damage = 1.9, Finisher = true, Knockback = 10,
				Shape = { Kind = "Circle", Radius = 7, MaxTargets = 6 } },
		},
		Heavy = { Name = "HeavyCleave", Impact = 0.12, Duration = 0.6, Damage = 3.2, Lunge = 2.5, MaxCharge = 0.6, ChargeDamage = 0.5,
			Knockback = 10, Stagger = 0.35, Shape = { Angle = 150, Radius = 7.5, MaxTargets = 5 } },
		Air = { Name = "PlungeStrike", Impact = 0.32, Duration = 0.85, Hang = 0.1, Damage = 2.6, Lunge = 2, Knockback = 8,
			Shape = { Kind = "Circle", Radius = 7, MaxTargets = 6 } },
		Dash = { Name = "DashSlash", Impact = 0.14, Duration = 0.5, Damage = 1.8, Lunge = 6, LungeSeconds = 0.16, Knockback = 7,
			Shape = { Kind = "Line", Length = 9, Width = 4, MaxTargets = 4 } },
		Skill = { Name = "DashSlashSkill", Clip = "Sword_DashAttack", Impact = 0.14, Duration = 0.5, Damage = 6, Lunge = 11, LungeSeconds = 0.2, Knockback = 10,
			Shape = { Kind = "Line", Length = 14, Width = 5, MaxTargets = 6 } },
	},
	Spear = {
		Class = "Melee", Dps = 1.08,
		Shape = { Kind = "Line", Length = 10, Width = 3, MaxTargets = 4 },
		Steps = {
			{ Name = "Thrust", Impact = 0.18, Duration = 1.11, Damage = 0.9 },
			{ Name = "Thrust2", Impact = 0.18, Duration = 1.11, Damage = 0.9 },
			{ Name = "Sweep", Impact = 0.22, Duration = 1.11, Damage = 0.95, Knockback = 6,
				Shape = { Kind = "Arc", Angle = 180, Radius = 8.5, MaxTargets = 6 } },
			{ Name = "PiercingLunge", Impact = 0.24, Duration = 1.11, Damage = 1.25, Finisher = true, Knockback = 8,
				Shape = { Length = 14, MaxTargets = 6 } },
		},
		Heavy = { Name = "HeavyThrust", Clip = "Spear_Attack4", Impact = 0.24, Duration = 0.8, Damage = 2.0, Lunge = 3, MaxCharge = 0.6, ChargeDamage = 0.5,
			Knockback = 9, Stagger = 0.35, Shape = { Length = 14, MaxTargets = 6 } },
		Air = { Name = "DragoonDive", Impact = 0.34, Duration = 0.95, Hang = 0.12, Damage = 1.3, Lunge = 3, Knockback = 8,
			Shape = { Kind = "Circle", Radius = 6.5, MaxTargets = 6 } },
		Dash = { Name = "ChargeThrust", Impact = 0.16, Duration = 0.65, Damage = 1.3, Lunge = 8, LungeSeconds = 0.18, Knockback = 9,
			Shape = { Length = 13, MaxTargets = 6 } },
	},
	Heavy = {
		Class = "Melee", Dps = 1.0,
		Shape = { Kind = "Arc", Angle = 90, Radius = 6, MaxTargets = 6, SlamRadius = 6, Stagger = 0.3 },
		Steps = {
			{ Name = "OverheadSlam", Impact = 0.45, Duration = 2.5, Damage = 0.85 },
			{ Name = "WideSmash", Impact = 0.4, Duration = 2.5, Damage = 0.95, Knockback = 6,
				Shape = { Angle = 200, Radius = 7.5, MaxTargets = 8, SlamRadius = false } },
			{ Name = "GroundBreaker", Impact = 0.55, Duration = 2.5, Damage = 1.2, Finisher = true, Knockback = 12,
				Shape = { Kind = "Circle", Radius = 8, MaxTargets = 10, SlamRadius = 9, Stagger = 0.6 } },
		},
		Heavy = { Name = "ChargedSlam", Clip = "Heavy_Attack3", Impact = 0.3, Duration = 1.0, Damage = 2.0, Lunge = 2, MaxCharge = 1.2, ChargeDamage = 1.0, ChargeRadius = 0.8,
			Knockback = 12, Shape = { Kind = "Circle", Radius = 8, MaxTargets = 10, SlamRadius = 9, Stagger = 0.6 } },
		Air = { Name = "MeteorSmash", Impact = 0.45, Duration = 1.3, Hang = 0.16, Damage = 1.5, Lunge = 2, Knockback = 12, Stagger = 0.6,
			Shape = { Kind = "Circle", Radius = 9, MaxTargets = 10, SlamRadius = false } },
		Dash = { Name = "RushingSmash", Impact = 0.3, Duration = 0.9, Damage = 1.3, Lunge = 5, LungeSeconds = 0.2, Knockback = 11, Stagger = 0.4,
			Shape = { Angle = 150, Radius = 7, SlamRadius = false } },
	},
	Dagger = {
		Class = "Melee", Dps = 1.0, Pair = true,
		Shape = { Kind = "Arc", Angle = 70, Radius = 4.5, MaxTargets = 2, BonusCrit = 0.20 },
		Steps = {
			{ Name = "CutR", Impact = 0.08, Duration = 0.22, Damage = 1.0 },
			{ Name = "CutL", Impact = 0.08, Duration = 0.22, Damage = 1.0 },
			{ Name = "StabR", Impact = 0.08, Duration = 0.22, Damage = 1.0 },
			{ Name = "StabL", Impact = 0.08, Duration = 0.22, Damage = 1.0 },
			{ Name = "SpinCut", Impact = 0.08, Duration = 0.3, Damage = 1.15, Shape = { Kind = "Circle", Radius = 5, MaxTargets = 3 } },
			{ Name = "Flurry", Impact = 0.08, Hits = { 0.16, 0.24, 0.32, 0.4 }, Duration = 0.68, Damage = 0.8, Finisher = true, Knockback = 6 },
		},
		Heavy = { Name = "CrossRend", Impact = 0.1, Duration = 0.5, Damage = 3.4, Lunge = 2.5, MaxCharge = 0.45, ChargeDamage = 0.5,
			Knockback = 6, Stagger = 0.3 },
		Air = { Name = "ShadowDrop", Impact = 0.26, Duration = 0.62, Hang = 0.06, Damage = 3.0, Lunge = 2, Knockback = 4,
			Shape = { Kind = "Circle", Radius = 5, MaxTargets = 3 } },
		Dash = { Name = "ShadowStep", Impact = 0.1, Hits = { 0.18 }, Duration = 0.45, Damage = 1.2, Lunge = 6, LungeSeconds = 0.14, Knockback = 3,
			Shape = { Kind = "Line", Length = 7, Width = 3, MaxTargets = 2 } },
		Skill = { Name = "BladeStorm", Impact = 0.08, Hits = { 0.16, 0.24, 0.32, 0.4 }, Duration = 0.62, Damage = 1.7, Knockback = 3,
			Shape = { Kind = "Circle", Radius = 6, MaxTargets = 4 } },
	},
	Ranged = {
		Class = "Bow", Dps = 0.96,
		Shape = { Kind = "Projectile", Speed = 120, Range = 60, MaxTargets = 1 },
		Steps = {
			{ Name = "Shot", Impact = 0.05, Duration = 0.833, Damage = 0.9 },
			{ Name = "QuickShot", Impact = 0.05, Duration = 0.833, Damage = 0.9 },
			{ Name = "PowerShot", Impact = 0.12, Duration = 0.833, Damage = 1.2, Finisher = true, Knockback = 6, Shape = { Speed = 170 } },
		},
		Air = { Name = "AirVolley", Impact = 0.12, Duration = 0.8, Hang = 0.25, Damage = 0.6, Shots = 3, Spread = 14 },
		Dash = { Name = "SlideShot", Impact = 0.08, Duration = 0.6, Damage = 1.2 },
	},
	Magic = {
		Class = "Staff", Dps = 0.8, Speed = "Intelligence",
		Shape = { Kind = "AoE", Range = 35, Radius = 6, MaxTargets = 20 },
		Steps = {
			{ Name = "Cast", Impact = 0.3, Duration = 1.0, Damage = 0.9 },
			{ Name = "Cast2", Impact = 0.28, Duration = 1.0, Damage = 0.9 },
			{ Name = "GrandCast", Impact = 0.4, Duration = 1.0, Damage = 1.2, Finisher = true, Shape = { Radius = 8.5 } },
		},
		Air = { Name = "MeteorDrop", Impact = 0.4, Duration = 1.0, Hang = 0.3, Damage = 1.5, Shape = { Radius = 9 } },
		Dash = { Name = "BlinkBlast", Impact = 0.2, Duration = 0.7, Damage = 1.2, Knockback = 8,
			Shape = { Kind = "Circle", Radius = 6, MaxTargets = 10 } },
	},
} :: { [string]: { [string]: any } }

local shapes: { [any]: { [string]: any } } = {}

-- The hit shape of a move: the category's with the move's overrides (false removes a field), shared and cached.
function WeaponMoves.shape(category: string, move: { [string]: any }?): { [string]: any }
	local base = (WeaponMoves.Moves[category] or WeaponMoves.Moves.Sword).Shape
	if not (move and move.Shape) then
		return base
	end
	local shape = shapes[move]
	if not shape then
		shape = table.clone(base)
		for key, value in pairs(move.Shape) do
			shape[key] = value
		end
		shapes[move] = shape
	end
	return shape :: { [string]: any }
end

-- A move by attack state: variant "Heavy" | "Air" | "Dash" (nil = the combo step). Nil when the category has none.
function WeaponMoves.move(category: string, step: number?, variant: string?): { [string]: any }?
	local moves = WeaponMoves.Moves[category]
	if not moves then
		return nil
	end
	if variant then
		return moves[variant]
	end
	return moves.Steps[step or 1]
end

-- Hits per second and average step Damage of a full combo at speed x1 (shop text, DPS).
function WeaponMoves.rate(category: string): (number, number)
	local seconds, damage, hits = 0, 0, 0
	for _, step in ipairs(WeaponMoves.Moves[category].Steps) do
		local count = 1 + (if step.Hits then #step.Hits else 0)
		seconds += step.Duration
		damage += step.Damage * count
		hits += count
	end
	return hits / seconds, damage / hits
end

return WeaponMoves
