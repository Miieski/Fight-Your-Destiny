--!strict
-- Combat visual effects: every number (docs/weapons_combat_brief.txt 4C, contract in docs/COMBAT_CONTRACTS.md).
-- DATA ONLY. OWNER: the VFX sub-agent. Read by GameClient/Controllers/VFX (client only: effects never decide damage).
-- Assets: ReplicatedStorage.Assets.VFX.<Category>_<Name> / Shared_<Name> (Studio instances, in the place file only).
-- Units: seconds, studs, degrees, Color3. Emit = ParticleEmitter:Emit count per play (x LowFx.EmitFactor with Low FX).
local rgb = Color3.fromRGB

local CombatVFX = {}

-- BUDGET ------------------------------------------------------------------------------------------------------------
CombatVFX.MaxActive = 48 -- pooled effects alive at once (sparks, arcs, rings, bubbles, ghosts, shots...); more are skipped
CombatVFX.CullDistance = 160 -- effects farther than this from the camera are skipped
CombatVFX.Pool = {
	-- clones made when the game starts (the rest are made on demand, then reused)
	Prewarm = {
		Shared_HitSpark = 8, Shared_CritBurst = 3, Shared_FinisherRing = 3, Sword_SlashArc = 3, Sword_SpinArc = 1,
		Shared_BlockBubble = 1, Shared_BlockSpark = 2, Shared_RollDust = 2, Shared_Projectile = 6, Shared_BurstDisc = 2,
		Shared_DeathDissolve = 4,
	},
	DefaultMax = 12, -- clones per asset at most (Max overrides)
	Max = { Shared_HitSpark = 24, Shared_Projectile = 24, Shared_DamageNumber = 24 },
}
CombatVFX.LowFx = {
	EmitFactor = 0.5, -- Emit counts x this (at least 1); FxController already scales the emitters' Rate
	Afterimages = false, -- roll ghosts with Low FX
}

-- EMIT COUNTS per asset and emitter (an emitter missing here uses its EmitCount attribute, else 4)
CombatVFX.Emit = {
	Shared_HitSpark = { Flash = 1, Star = 1, Shards = 8 },
	Shared_CritBurst = { Flash = 1, Star = 1, Shards = 12, Ring = 1 },
	Shared_FinisherRing = { Flash = 1, Ring = 1 },
	Shared_BlockSpark = { Flash = 1, Sparks = 8, Ring = 1 },
	Shared_RollDust = { Dust = 5, Pebbles = 4 },
	Shared_DeathDissolve = { Motes = 14, Puff = 3 },
	Sword_SpinArc = { Ring = 1, Dust = 8, Sparks = 10 },
}
-- emitters recolored when an effect is played with a color (VFX.play options.Color); the others keep their color
CombatVFX.Tint = {
	Shared_HitSpark = { Shards = true },
	Shared_CritBurst = {},
	Shared_BlockSpark = {},
}

-- WEAPON COLORS (trails and arcs) -----------------------------------------------------------------------------------
CombatVFX.Weapon = {
	TrailFromTier = 2, -- rarity tiers below this (Common) get no trail; their arc uses CommonColor
	CommonColor = rgb(222, 228, 238),
	ElementTint = 0.22, -- the zone element color (Config/Combat StyleColors) mixed into the rarity color
	HeadWhite = 0.45, -- the newest part of the trail is lightened this much toward white
	CoreWhite = 0.8, -- arc core = arc color lightened this much toward white
	SparkTint = 0.35, -- impact shards lightened from white toward the element color
}
CombatVFX.Trail = { -- applied on the Shared_WeaponTrail clone (one per equipped weapon, Base -> Tip attachments)
	Lifetime = 0.2,
	MinLength = 0.05,
	LightEmission = 0.3, -- low: the rarity color stays readable on bright ground (1 = additive, washes out)
	Brightness = 1.6,
	Transparency = { { 0, 0 }, { 0.5, 0.3 }, { 1, 1 } }, -- { time, value } over the trail's life
	WidthScale = { { 0, 1 }, { 1, 0.35 } },
}

-- ARCS (beam crescents on a circle around the attacker, in the swing's plane) ------------------------------------
-- Per arc: Asset, Radius, Width, Height (above HumanoidRootPart), From / To (degrees along the circle: 0 = ahead,
-- +90 = right, -90 = left; the arc is drawn from From to To), Roll (degrees around the forward axis: + raises the
-- right side, 90 = vertical), Reveal (s: tail -> head), Profile ("Crescent" | "Ring" | "Full"); optional Hold, Fade, Grow,
-- Core (override the Arc defaults), Ground = true (the asset's Ground emitters fire at the attacker's feet).
CombatVFX.Arc = {
	FadeIn = 0.025, -- each point of the arc appears over this
	Hold = 0.05, -- stays at full width this long after it appeared
	Fade = 0.16, -- then thins out (tail first)
	Grow = 0.12, -- the radius grows this fraction over the arc's life
	Core = 0.32, -- white core width / outer width
	-- look of the beams (applied once per clone): Transparency = { tail, head }
	OuterLook = { LightEmission = 0.35, Brightness = 1.6, Transparency = { 0.45, 0.05 } },
	CoreLook = { LightEmission = 1, Brightness = 1.5, Transparency = { 0.4, 0 } },
}

-- SWINGS per category and combo step (Config/Combat Combos). TrailOn = fraction of the time to the hit
-- (Combos[category][step].Impact / speed) when the trail starts (= the end of the wind-up of the animation clip);
-- TrailOff = seconds after the hit (at speed x1, divided by the speed) when it stops (end of the follow-through).
-- The arc appears at the hit. A melee category without an entry gets Default (trail only).
CombatVFX.Swing = {
	Default = { TrailOn = 0.45, TrailOff = 0.12 },
	Sword = {
		-- RightSlash: high right -> low left across the front
		{ TrailOn = 0.45, TrailOff = 0.11,
			Arc = { Asset = "Sword_SlashArc", Radius = 4.6, Width = 1.6, Height = 0.5, From = 105, To = -80, Roll = 32, Reveal = 0.06, Profile = "Crescent" } },
		-- LeftSlash: backhand from the left, flat across the front, out to the right
		{ TrailOn = 0.45, TrailOff = 0.11,
			Arc = { Asset = "Sword_SlashArc", Radius = 4.6, Width = 1.5, Height = 0.6, From = -105, To = 95, Roll = -10, Reveal = 0.06, Profile = "Crescent" } },
		-- RisingSlash: from the ground in front up over the head (vertical plane, slightly from the right)
		{ TrailOn = 0.45, TrailOff = 0.11,
			Arc = { Asset = "Sword_SlashArc", Radius = 4.3, Width = 1.5, Height = 0.4, From = -60, To = 85, Roll = 100, Reveal = 0.06, Profile = "Crescent" } },
		-- SpinSlash finisher: a full circle around the player (380 degrees, turning left like the clip), bigger, brighter
		{ TrailOn = 0.55, TrailOff = 0.22,
			Arc = { Asset = "Sword_SpinArc", Radius = 6.4, Width = 2.4, Height = 0.2, From = 90, To = -290, Roll = 0, Reveal = 0.12, Hold = 0.07, Fade = 0.2, Core = 0.4, Profile = "Ring", Ground = true } },
	},
}

-- IMPACTS (VFX.impact) -------------------------------------------------------------------------------------------
CombatVFX.Impact = {
	Normal = "Shared_HitSpark",
	Crit = "Shared_CritBurst",
	-- finisher hit (with Normal / Crit): a beam ring (an arc spec, see ARCS) expanding around the enemy, gold mixed
	-- with the weapon element (Tint), + the asset's Center emitters
	Finisher = { Asset = "Shared_FinisherRing", Radius = 1.2, Grow = 3.2, Width = 1.1, From = 0, To = 360, Roll = 0,
		Reveal = 0, Hold = 0.04, Fade = 0.22, Core = 0.35, Profile = "Full", Color = rgb(255, 214, 110), Tint = 0.3 },
	FinisherMax = 3, -- finisher rings at most within FinisherWindow s (a spin that hits 6 enemies would blow out to white)
	FinisherWindow = 0.1,
	EnemyMatch = 4, -- studs (horizontal): the hit position is matched to the enemy root within this
	TowardCamera = 0.7, -- the spark sits this fraction of the enemy root's half width toward the camera
	FallbackDrop = 1.5, -- no enemy found: the spark goes this far below the hit position (sent above the head)
}

-- BLOCK (VFX.block / VFX.blockHit) ---------------------------------------------------------------------------------
CombatVFX.Block = {
	Asset = "Shared_BlockBubble",
	Size = 6.2, -- bubble diameter
	Height = 0.2, -- bubble center above HumanoidRootPart
	PopFrom = 0.55, -- size fraction when it appears
	PopTime = 0.14,
	FlashFrom = 0.65, -- neon shell transparency at the raise and on a blocked hit (fades to 1)
	FlashTime = 0.2,
	OffTime = 0.12, -- shrink and fade when the guard drops
	HitAsset = "Shared_BlockSpark",
	HitPulse = 1.1, -- bubble size kick on a blocked hit
	HitPulseTime = 0.16,
	EnemyRange = 14, -- the block spark faces the nearest enemy within this (else the character's front)
}

-- ROLL (VFX.roll) ---------------------------------------------------------------------------------------------------
CombatVFX.Roll = {
	Dust = "Shared_RollDust",
	Ghost = "Shared_Afterimage", -- material of the afterimages
	GhostColor = Color3.fromRGB(130, 195, 255),
	GhostFrom = 0.4, -- transparency of a fresh afterimage (fades to 1)
	Ghosts = 3, -- afterimages per roll (none with Low FX)
	Interval = 0.06, -- seconds between two snapshots of the pose
	Fade = 0.25, -- each ghost fades out over this
	FeetDrop = 3, -- the dust goes this far below HumanoidRootPart when no ground is found
}

-- DAMAGE NUMBERS (VFX.damageNumber) -----------------------------------------------------------------------------
CombatVFX.Numbers = {
	Template = "Shared_DamageNumber",
	Max = 24, -- pooled numbers (the oldest is reused beyond)
	Prewarm = 8, -- made when the game starts
	Life = 0.75,
	Rise = 3.2, -- studs over the life
	Spread = 1.4, -- random horizontal offset
	PopFrom = 0.35, -- scale when it appears, then an overshoot back to 1
	PopTime = 0.16,
	Overshoot = 1.9, -- back-out ease strength (crit: x1.5)
	FadeFrom = 0.55, -- fraction of the life where it starts fading
	ShakeTime = 0.22, -- crits shake this long
	Shake = 0.25, -- studs
	Scale = { normal = 1, crit = 1.45, hurt = 0.95, block = 0.85, dodge = 0.9 },
	Colors = {
		normal = rgb(255, 255, 255),
		crit = rgb(255, 205, 50),
		hurt = rgb(255, 80, 70),
		block = rgb(130, 200, 255),
		dodge = rgb(200, 255, 200),
	},
}

-- SHOTS AND BURSTS (VFX.shot / VFX.burst) --------------------------------------------------------------------------
CombatVFX.Shot = { Asset = "Shared_Projectile", Size = 0.9, EnemySize = 1.4, MinTime = 0.05, TrailLife = 0.2, Spark = "Shared_HitSpark" }
CombatVFX.Burst = { Asset = "Shared_BurstDisc", Grow = 0.22, Fade = 0.3, Transparency = 0.3, Spark = "Shared_HitSpark" }

-- ENEMY DEATH (extra dissolve on top of EnemyController's death fade, from workspace.Enemies "Dead") -----------------
CombatVFX.Death = { Asset = "Shared_DeathDissolve", Delay = 0.45, MaxSize = 14 }

return CombatVFX
