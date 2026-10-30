--!strict
-- Player combat numbers shared by every weapon (DESIGN.md section 2). The moves, shapes and timings of each weapon are
-- in Config/WeaponMoves. The server decides every hit; the client only sends its inputs and shows the result.
local Combat = {}

-- An enemy closer than this counts as "in front" whatever the angle (hugging enemies).
Combat.CloseRange = 2.5
-- The server accepts an attack this fraction of the previous move's Duration after it (lag tolerance); same for rolls.
Combat.RateTolerance = 0.82
-- Without a weapon (should not happen: starter weapon) the player punches with this damage.
Combat.UnarmedDamage = 5

-- Roll (the dodge): Stats.compute RollCooldown = 1.2 s, Mind reduces it, floor 0.6 s. It may only cancel the recovery
-- of an attack: a press during the start-up is held until the impact (client), the server refuses a roll ImpactTolerance
-- seconds or more before the impact.
Combat.Roll = { IFrames = 0.25, Distance = 12, Duration = 0.3, ImpactTolerance = 0.03 }
-- Block: Stats.compute Block = damage reduction at full guard (60%, Endurance raises it, cap 85%). The guard meter goes
-- from GuardMax down by GuardPerHit per blocked hit; the reduction scales from 100% (full) to MinStrength of itself (empty
-- soon); at 0 the block breaks (no block for GuardBreakLock s). It refills GuardRegen per second while not blocking.
-- Perfect parry: a hit within ParryWindow s after the block press: no damage, the source is staggered ParryStagger s (not
-- bosses), the guard is refilled. A new press only opens the window ParryCooldown s after the previous one (no spam).
Combat.Block = {
	SpeedFactor = 0.5, -- walk speed while blocking
	GuardMax = 100,
	GuardPerHit = 25,
	GuardRegen = 30,
	GuardBreakLock = 1.5,
	MinStrength = 0.4,
	ParryWindow = 0.2,
	ParryStagger = 1.0,
	ParryCooldown = 0.5,
}

-- Staff: Stats.compute MaxMana and ManaRegen come from Mind. Regen x OutOfCombat after OutOfCombatDelay s without casting or
-- being hit. Services/ManaService ticks every Tick s; attributes Mana / MaxMana change by at least 1 (no network spam).
Combat.Mana = { Tick = 0.25, OutOfCombat = 2.5, OutOfCombatDelay = 4 }
-- Heal channel (the staff's Block): up to Fraction of max HP (x (1 + Faith healing)) over Seconds, ManaPerSecond drained; the
-- walk speed x SpeedFactor; allies within AllyRange studs get AllyShare of it; a dodge or running out of mana stops it;
-- Cooldown s after it ends. Burn: Stacks at most, each deals DamageFraction of the weapon's damage every Tick s for Seconds s.
Combat.Heal = { Fraction = 0.2, Seconds = 3, ManaPerSecond = 15, SpeedFactor = 0.5, AllyRange = 20, AllyShare = 0.5, Cooldown = 2 }
Combat.Burn = { Stacks = 3, DamageFraction = 0.1, Tick = 0.5, Seconds = 3 }

-- Lock-on (client only, Controllers/LockOnController; the server only ever receives a direction): the nearest enemy
-- within ConeDegrees of the camera's center and Range studs. CameraSpeed / FaceSpeed = exponential turn rates (per s).
-- A hit from a boss worth BreakFraction of the player's max HP or more breaks it (Net "LockBreak").
Combat.LockOn = { Range = 60, ConeDegrees = 30, CameraSpeed = 7, FaceSpeed = 14, BreakFraction = 0.15, TargetHeight = 2 }

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

-- Jump attacks (Config/WeaponMoves Air): the attack pressed in the air.
Combat.AirAttack = {
	MinHeight = 1.2, -- studs between the feet and the ground for an attack to count as a jump attack
	MinGap = 0.6, -- seconds between two jump attacks (at least)
	DiveSpeed = 50, -- studs / s: the body hangs until a dive at this speed lands right at Impact (higher = faster)
	DiveMaxSpeed = 140,
	LandTimeout = 1.2, -- seconds after Impact: the dive gives up (stuck on something)
}

-- Dash strikes (Config/WeaponMoves Dash): an attack within Window seconds after a roll ends (or pressed during it).
Combat.DashAttack = { Window = 0.35, Tolerance = 0.15 }

-- Client feel (never decides damage). Low FX turns off the shakes and the afterimages (Controllers/VFX halves the
-- particles).
Combat.Feel = {
	AimAssistRange = 0, -- studs: melee turns toward the nearest enemy within this range (0 = the camera direction decides)
	AimAssistAngle = 70, -- only enemies within this angle of the aim
	TurnSeconds = 0.09, -- the body turns toward the aim this fast when an attack starts (no snap)
	Shake = { Finisher = 0.45, Heavy = 0.6 }, -- Fx.shake strength on a confirmed finisher / heavy hit, slams; none on light hits
	FovPulse = { Degrees = 6, Seconds = 0.25 }, -- finishers
	LungeSeconds = 0.12,
	AimOffset = Vector3.new(1.8, 0.6, 0), -- camera over the shoulder with a bow or a staff, so the crosshair is not on the body
	AimOffsetRate = 10, -- per second
	ComboCounterSeconds = 2, -- the combo hit counter fades after this long without a hit
}

Combat.AutoAttackTick = 0.1 -- seconds between Auto-Attack target checks (client)
Combat.AutoAttackReachBonus = 1 -- studs added to the weapon reach when Auto-Attack looks for a target
Combat.ShotBuffer = 0.25 -- a Ranged / Magic press this early is kept until the weapon is ready

return Combat
