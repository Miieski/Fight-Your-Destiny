--!strict
-- Player combat numbers (docs/enemies_npcs_pets_brief.txt Part A, DESIGN.md section 2). The server decides every
-- hit with these shapes; the client only sends "Attack" with its aim and shows the result.
--   Kind: "Arc" / "Cone" (Angle in degrees, Radius), "Line" (Length x Width), "Projectile" (Speed, Range),
--   "AoE" (cast at the aim point within Range, Radius x (1 + Magic radius bonus)).
-- Impact = seconds between the request and the hit (the swing's impact moment). MaxTargets = enemies per hit.
local Combat = {}

Combat.Shapes = {
	Sword = { Kind = "Arc", Angle = 120, Radius = 6, MaxTargets = 3, Impact = 0.15, Anim = "Slash" },
	Spear = { Kind = "Line", Length = 10, Width = 3, MaxTargets = 4, Impact = 0.18, Anim = "Lunge" },
	Heavy = { Kind = "Arc", Angle = 90, Radius = 6, MaxTargets = 6, Impact = 0.35, Anim = "Slash", SlamRadius = 6, Stagger = 0.3 },
	Dagger = { Kind = "Arc", Angle = 60, Radius = 4, MaxTargets = 1, Impact = 0.08, Anim = "Lunge", BonusCrit = 0.20 },
	Gauntlet = { Kind = "Cone", Angle = 90, Radius = 5, MaxTargets = 3, Impact = 0.1, Anim = "Lunge", Combo = 3, ComboReset = 1.4, FinisherMult = 2 },
	Ranged = { Kind = "Projectile", Speed = 120, Range = 60, MaxTargets = 1, Impact = 0.05, Anim = "Lunge" },
	Magic = { Kind = "AoE", Range = 35, Radius = 6, MaxTargets = 20, Impact = 0.3, Anim = "Lunge" },
	Whip = { Kind = "Cone", Angle = 100, Radius = 12, MaxTargets = 6, Impact = 0.2, Anim = "Slash" },
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
Combat.AutoAttackTick = 0.1 -- seconds between Auto-Attack target checks (client)
Combat.AutoAttackReachBonus = 1 -- studs added to the weapon reach when Auto-Attack looks for a target
Combat.AimAssistBonus = 4 -- studs added to the reach for the touch / gamepad aim assist
Combat.ShotBuffer = 0.25 -- a Ranged / Magic press this early is kept until the weapon is ready

return Combat
