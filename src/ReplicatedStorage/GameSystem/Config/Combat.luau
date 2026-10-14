--!strict
-- Player combat numbers (docs/enemies_npcs_pets_brief.txt Part A, DESIGN.md section 2). The server decides every
-- hit with these shapes; the client only sends "Attack" with its aim and shows the result.
--   Kind: "Arc" / "Cone" (Angle in degrees, Radius), "Line" (Length x Width), "Projectile" (Speed, Range),
--   "AoE" (cast at the aim point within Range, Radius x (1 + Magic radius bonus)), "Circle" (Radius around the
--   attacker: Sword spin finisher).
-- Impact = seconds between the request and the hit when a combo step gives none (Combat.Combos below).
-- MaxTargets = enemies per hit. Anim = the default Animate tool animation (fallback when Controllers/Combat/Animations
-- has no clip).
local Combat = {}

Combat.Shapes = {
	Sword = { Kind = "Arc", Angle = 120, Radius = 6, MaxTargets = 3, Impact = 0.15, Anim = "Slash" },
	Spear = { Kind = "Line", Length = 10, Width = 3, MaxTargets = 4, Impact = 0.18, Anim = "Lunge" },
	Heavy = { Kind = "Arc", Angle = 90, Radius = 6, MaxTargets = 6, Impact = 0.35, Anim = "Slash", SlamRadius = 6, Stagger = 0.3 },
	Dagger = { Kind = "Arc", Angle = 60, Radius = 4, MaxTargets = 1, Impact = 0.08, Anim = "Lunge", BonusCrit = 0.20 },
	Gauntlet = { Kind = "Cone", Angle = 90, Radius = 5, MaxTargets = 3, Impact = 0.1, Anim = "Lunge" },
	Ranged = { Kind = "Projectile", Speed = 120, Range = 60, MaxTargets = 1, Impact = 0.05, Anim = "Lunge" },
	Magic = { Kind = "AoE", Range = 35, Radius = 6, MaxTargets = 20, Impact = 0.3, Anim = "Lunge" },
}

-- An enemy closer than this counts as "in front" whatever the angle (hugging enemies).
Combat.CloseRange = 2.5
-- The server accepts an attack this fraction of the weapon's interval after the previous one (lag tolerance).
Combat.RateTolerance = 0.82
-- Without a weapon (should not happen: starter weapon) the player punches with this damage.
Combat.UnarmedDamage = 5

-- Roll: i-frames, distance, cooldown (Stats.compute RollCooldown: 1.5 s, Mind reduces, floor 0.6 s).
Combat.Roll = { IFrames = 0.35, Distance = 12, Duration = 0.3 }
-- Block: Stats.compute Block = damage reduction (60%, Endurance raises it, cap 85%); speed while blocking.
Combat.Block = { SpeedFactor = 0.5 }

-- Starter weapon: a player who owns no weapon gets a free Common sword of the zone they are in (Plains for new players).
Combat.StarterRarity = 1

-- Projectiles and bursts are drawn by clients within this distance of the shooter.
Combat.VisualRange = 160
-- Colors of shots and bursts (client): weapon element of its zone, plus the special styles.
Combat.StyleColors = {
	Physical = Color3.fromRGB(235, 235, 235),
	Nature = Color3.fromRGB(120, 225, 90),
	Sand = Color3.fromRGB(245, 205, 110),
	Poison = Color3.fromRGB(160, 235, 60),
	Frost = Color3.fromRGB(150, 220, 255),
	Curse = Color3.fromRGB(170, 90, 220),
	Burn = Color3.fromRGB(255, 130, 40),
	Hellfire = Color3.fromRGB(255, 60, 30),
	Holy = Color3.fromRGB(255, 240, 160),
	["Soul Drain"] = Color3.fromRGB(120, 255, 200),
	Tidal = Color3.fromRGB(60, 160, 255),
	Shock = Color3.fromRGB(255, 255, 90),
	Gravity = Color3.fromRGB(150, 80, 255),
	Arcane = Color3.fromRGB(190, 130, 255),
	Slam = Color3.fromRGB(190, 160, 120),
	Enemy = Color3.fromRGB(255, 70, 50),
}

-- HACK & SLASH COMBOS (docs/weapons_combat_brief.txt 4A). One step per attack input; the server picks the step
-- (the client predicts the same one), the combo resets when no attack comes within ComboReset seconds after the
-- weapon's interval. Per step (times in seconds at attack speed x1; they shrink with Stats AttackSpeed):
--   Impact    when the hit lands after the attack request (= the "Hit" marker of the step's animation)
--   Damage    damage multiplier of the step (the average over a combo stays close to 1, so the DPS of the weapon
--             document holds; the Gauntlet keeps its x2 third hit)
--   Hits      extra impacts of the same step (Dagger finisher double slash): { seconds after the request, ... }
--   Finisher  the last hit: bigger effect, more knockback, longer hit-stop, cannot be cancelled by Block
--   Shape     fields that replace the category shape for this step (Combat.Shapes)
--   Knockback studs a normal enemy is pushed (mini-bosses and bosses are never pushed); nil = EnemyService default
--   Lunge     studs the attacker steps forward (client, LinearVelocity impulse)
-- The animation clips (Config/CombatAnimations) are authored with their "Hit" marker at Impact and a length that
-- fits in the weapon's interval (1 / HitsPerSecond).
Combat.ComboReset = 0.8
Combat.Combos = {
	Sword = {
		{ Name = "RightSlash", Impact = 0.16, Damage = 0.85, Lunge = 2.5 },
		{ Name = "LeftSlash", Impact = 0.16, Damage = 0.85, Lunge = 2.5 },
		{ Name = "RisingSlash", Impact = 0.18, Damage = 1.0, Lunge = 2.5 },
		{ Name = "SpinSlash", Impact = 0.22, Damage = 1.3, Lunge = 3, Finisher = true, Knockback = 9,
			Shape = { Kind = "Circle", Radius = 7, MaxTargets = 6 } },
	},
	Spear = {
		{ Name = "Thrust", Impact = 0.18, Damage = 0.9, Lunge = 4 },
		{ Name = "Thrust2", Impact = 0.18, Damage = 0.9, Lunge = 4 },
		-- combat V3 (2026-10-14): a wide sweep with the shaft before the lunge
		{ Name = "Sweep", Impact = 0.22, Damage = 0.95, Lunge = 2, Knockback = 6,
			Shape = { Kind = "Arc", Angle = 180, Radius = 8.5, MaxTargets = 6 } },
		{ Name = "PiercingLunge", Impact = 0.24, Damage = 1.25, Lunge = 6, Finisher = true, Knockback = 8,
			Shape = { Length = 14, MaxTargets = 6 } },
	},
	Heavy = {
		{ Name = "OverheadSlam", Impact = 0.45, Damage = 0.85, Lunge = 3 },
		{ Name = "WideSmash", Impact = 0.4, Damage = 0.95, Lunge = 3, Knockback = 6,
			Shape = { Angle = 200, Radius = 7.5, MaxTargets = 8, SlamRadius = false } },
		-- combat V3: a jumping two-handed slam that cracks the ground all around
		{ Name = "GroundBreaker", Impact = 0.55, Damage = 1.2, Lunge = 3, Finisher = true, Knockback = 12,
			Shape = { Kind = "Circle", Radius = 8, MaxTargets = 10, SlamRadius = 9, Stagger = 0.6 } },
	},
	Dagger = {
		{ Name = "SlashR", Impact = 0.08, Damage = 0.9, Lunge = 1.5 },
		{ Name = "SlashL", Impact = 0.08, Damage = 0.9, Lunge = 1.5 },
		{ Name = "StabR", Impact = 0.08, Damage = 0.9, Lunge = 1.5 },
		{ Name = "StabL", Impact = 0.08, Damage = 0.9, Lunge = 1.5 },
		{ Name = "DoubleSlash", Impact = 0.08, Hits = { 0.2 }, Damage = 0.7, Lunge = 1.5, Finisher = true, Knockback = 5 },
	},
	Gauntlet = {
		{ Name = "Jab", Impact = 0.1, Damage = 1.0, Lunge = 2 },
		{ Name = "Cross", Impact = 0.1, Damage = 1.0, Lunge = 2 },
		{ Name = "Uppercut", Impact = 0.16, Damage = 2.0, Lunge = 2, Finisher = true, Knockback = 8 },
	},
	-- combat V3: three shots / casts, the third one stronger
	Ranged = {
		{ Name = "Shot", Impact = 0.05, Damage = 0.9, Lunge = 0 },
		{ Name = "QuickShot", Impact = 0.05, Damage = 0.9, Lunge = 0 },
		{ Name = "PowerShot", Impact = 0.12, Damage = 1.2, Lunge = 0, Finisher = true, Knockback = 6, Shape = { Speed = 170 } },
	},
	Magic = {
		{ Name = "Cast", Impact = 0.3, Damage = 0.9, Lunge = 0 },
		{ Name = "Cast2", Impact = 0.28, Damage = 0.9, Lunge = 0 },
		{ Name = "GrandCast", Impact = 0.4, Damage = 1.2, Lunge = 0, Finisher = true, Shape = { Radius = 8.5 } },
	},
} :: { [string]: { { [string]: any } } }

-- JUMP ATTACKS (owner 2026-10-14: "a special animation when the character jump+attack"). An attack while airborne:
-- melee weapons hang a moment at the top, dive and slam the ground (a circle around the landing point); Ranged fires a
-- volley at the aim point; Magic drops a big blast at the aim point. Same fields as a combo step, plus:
--   Impact  seconds after the request when the hit lands (melee: the landing; the client times its dive on it)
--   Hang    seconds the attacker stays still in the air before the dive / the shot
--   Stagger seconds every enemy hit is staggered
--   Shots, Spread (Ranged: projectiles and the angle between two of them, degrees)
-- Every jump attack counts as a finisher (bigger feedback). The combo restarts after it.
Combat.AirAttacks = {
	Sword = { Name = "PlungeStrike", Impact = 0.32, Hang = 0.1, Damage = 1.3, Lunge = 2, Knockback = 8,
		Shape = { Kind = "Circle", Radius = 7, MaxTargets = 6 } },
	Spear = { Name = "DragoonDive", Impact = 0.34, Hang = 0.12, Damage = 1.3, Lunge = 3, Knockback = 8,
		Shape = { Kind = "Circle", Radius = 6.5, MaxTargets = 6 } },
	Heavy = { Name = "MeteorSmash", Impact = 0.45, Hang = 0.16, Damage = 1.5, Lunge = 2, Knockback = 12, Stagger = 0.6,
		Shape = { Kind = "Circle", Radius = 9, MaxTargets = 10, SlamRadius = false } },
	Dagger = { Name = "ShadowDrop", Impact = 0.26, Hang = 0.06, Damage = 1.5, Lunge = 2, Knockback = 4,
		Shape = { Kind = "Circle", Radius = 5, MaxTargets = 3 } },
	Gauntlet = { Name = "GroundPound", Impact = 0.32, Hang = 0.1, Damage = 1.6, Lunge = 1.5, Knockback = 10, Stagger = 0.3,
		Shape = { Kind = "Circle", Radius = 7.5, MaxTargets = 6 } },
	Ranged = { Name = "AirVolley", Impact = 0.12, Hang = 0.25, Damage = 0.6, Lunge = 0, Shots = 3, Spread = 14 },
	Magic = { Name = "MeteorDrop", Impact = 0.4, Hang = 0.3, Damage = 1.5, Lunge = 0, Shape = { Radius = 9 } },
} :: { [string]: { [string]: any } }
Combat.AirAttack = {
	MinHeight = 1.2, -- studs between the feet and the ground for an attack to count as a jump attack
	MinGap = 0.6, -- seconds between two jump attacks (at least)
	DiveSpeed = 50, -- studs / s: the body hangs until a dive at this speed lands right at Impact (higher = faster)
	DiveMaxSpeed = 140,
	LandTimeout = 1.2, -- seconds after Impact: the dive gives up (stuck on something)
}

-- DASH ATTACKS (combat V3, Iron Soul style dash strike): an attack within Window seconds after a roll ends (or pressed
-- during the roll) is the category's dash strike: a long lunge out of the roll. Same fields as a combo step;
-- LungeSeconds = the lunge's duration (default Feel.LungeSeconds). The combo restarts after it.
Combat.DashAttack = { Window = 0.35, Tolerance = 0.15 }
Combat.DashAttacks = {
	Sword = { Name = "DashSlash", Impact = 0.14, Damage = 1.25, Lunge = 6, LungeSeconds = 0.16, Knockback = 7,
		Shape = { Kind = "Line", Length = 9, Width = 4, MaxTargets = 4 } },
	Spear = { Name = "ChargeThrust", Impact = 0.16, Damage = 1.3, Lunge = 8, LungeSeconds = 0.18, Knockback = 9,
		Shape = { Length = 13, MaxTargets = 6 } },
	Heavy = { Name = "RushingSmash", Impact = 0.3, Damage = 1.3, Lunge = 5, LungeSeconds = 0.2, Knockback = 11, Stagger = 0.4,
		Shape = { Angle = 150, Radius = 7, SlamRadius = false } },
	Dagger = { Name = "ShadowStep", Impact = 0.1, Hits = { 0.18 }, Damage = 0.9, Lunge = 6, LungeSeconds = 0.14, Knockback = 3,
		Shape = { Kind = "Line", Length = 7, Width = 3, MaxTargets = 2 } },
	Gauntlet = { Name = "RocketPunch", Impact = 0.12, Damage = 1.4, Lunge = 6, LungeSeconds = 0.16, Knockback = 10,
		Shape = { Kind = "Line", Length = 8, Width = 3.5, MaxTargets = 3 } },
	Ranged = { Name = "SlideShot", Impact = 0.08, Damage = 1.2, Lunge = 0 },
	Magic = { Name = "BlinkBlast", Impact = 0.2, Damage = 1.2, Lunge = 0, Knockback = 8,
		Shape = { Kind = "Circle", Radius = 6, MaxTargets = 10 } },
} :: { [string]: { [string]: any } }

-- Client feel (never decides damage). Low FX turns off the shakes and the afterimages (Controllers/VFX halves the
-- particles).
Combat.Feel = {
	AimAssistRange = 15, -- melee turns toward the nearest enemy within this many studs
	AimAssistAngle = 70, -- PC with a mouse: only enemies within this angle of the mouse direction
	HitStopSpeed = 0.05, -- the attacker's animation speed during a hit-stop
	HitStop = { Normal = 0.06, Finisher = 0.12, Heavy = 0.12 }, -- seconds
	Shake = { Normal = 0.18, Finisher = 0.45, Heavy = 0.6 }, -- Fx.shake strength on a confirmed hit
	FovPulse = { Degrees = 6, Seconds = 0.25 }, -- finishers
	LungeSeconds = 0.12,
	ComboCounterSeconds = 2, -- the combo hit counter fades after this long without a hit
}

Combat.AutoAttackTick = 0.1 -- seconds between Auto-Attack target checks (client)
Combat.AutoAttackReachBonus = 1 -- studs added to the weapon reach when Auto-Attack looks for a target
Combat.AimAssistBonus = 4 -- studs added to the reach for the touch / gamepad aim assist
Combat.ShotBuffer = 0.25 -- a Ranged / Magic press this early is kept until the weapon is ready

return Combat
