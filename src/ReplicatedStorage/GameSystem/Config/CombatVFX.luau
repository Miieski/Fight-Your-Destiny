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
		Shared_BlockBubble = 1, Shared_BlockSpark = 2, Shared_RollDust = 2, Shared_Projectile = 4, Shared_BurstDisc = 2,
		Shared_DeathDissolve = 4,
		Spear_PierceStreak = 2, Spear_ThrustLines = 2, Spear_PierceRing = 1,
		Heavy_SmashArc = 1, Heavy_GroundCrack = 1, Heavy_SlamRing = 1,
		Dagger_SlashArc = 3, Dagger_StabStreak = 3, Dagger_StabRing = 2,
		Gauntlet_PunchRing = 2, Gauntlet_PunchLines = 2,
		Ranged_MuzzleFlash = 2, Ranged_ShotRing = 2, Ranged_Arrow = 3, Ranged_Bolt = 1, Ranged_Bullet = 1,
		Magic_CastCircle = 2, Magic_ChargeOrb = 1, Magic_Bolt = 1, Magic_AreaBurst = 1,
		-- combat V3: jump attack landings, dives, dash strikes
		Shared_LandRing = 2, Shared_DustRing = 1, Shared_LandDust = 1, Shared_LandFlash = 1, Shared_DiveLines = 1, Shared_WindRing = 1,
		Shared_DashLines = 1, Shared_DashStreak = 1,
	},
	DefaultMax = 12, -- clones per asset at most (Max overrides)
	Max = { Shared_HitSpark = 24, Shared_Projectile = 24, Ranged_Arrow = 16, Ranged_Bolt = 16, Ranged_Bullet = 16 },
}
CombatVFX.LowFx = {
	EmitFactor = 0.5, -- Emit counts x this (at least 1); FxController already scales the emitters' Rate
	Afterimages = false, -- roll ghosts with Low FX (speed lines and ground chunks are halved too)
}

-- EMIT COUNTS per asset and emitter (an emitter missing here uses its EmitCount attribute, else 4)
CombatVFX.Emit = {
	Shared_HitSpark = { Flash = 1, Star = 1, Shards = 8 },
	Shared_CritBurst = { Flash = 1, Star = 1, Shards = 12, Ring = 1 },
	Shared_FinisherRing = { Flash = 1, Ring = 1 },
	Shared_BlockSpark = { Flash = 1, Sparks = 8, Ring = 1 },
	Shared_RollDust = { Dust = 7, Pebbles = 4 },
	Shared_LandDust = { Dust = 14, Plume = 5, Debris = 10 }, -- x the landing radius / Land.RadiusRef
	Shared_LandFlash = { Flash = 1, Star = 1, Sparks = 12 },
	Dagger_ShadowPuff = { Smoke = 10, Wisps = 8 },
	Spear_SweepArc = { Dust = 8 },
	Shared_DeathDissolve = { Motes = 14, Puff = 3 },
	Sword_SpinArc = { Ring = 1, Dust = 8, Sparks = 10 },
	Spear_PierceRing = { Flash = 1 },
	Heavy_GroundCrack = { Dust = 8, Pebbles = 8 },
	Heavy_SlamRing = { Dust = 10 },
	Gauntlet_PunchRing = { Flash = 1, Puff = 3 },
	Magic_CastCircle = { Runes = 5 },
	Magic_ChargeOrb = { Motes = 0, Glow = 0 }, -- continuous while charging (Rate in the asset)
	Magic_AreaBurst = { Flash = 1, Column = 10, Motes = 12 },
}
-- emitters recolored when an effect is played with a color; the others keep their color
CombatVFX.Tint = {
	Shared_RollDust = { Dust = true }, -- the ground color (VFX.roll)
	Shared_LandDust = { Dust = true, Plume = true }, -- the ground color (VFX.land, Slam bursts)
	Shared_LandFlash = { Star = true, Sparks = true }, -- the weapon glow (VFX.land)
	Shared_HitSpark = { Shards = true },
	Shared_CritBurst = {},
	Shared_BlockSpark = {},
	Magic_ChargeOrb = { Motes = true, Glow = true },
	Magic_AreaBurst = { Flash = true, Column = true, Motes = true },
}

-- WEAPON COLORS (trails and arcs) -----------------------------------------------------------------------------------
CombatVFX.Weapon = {
	TrailFromTier = 2, -- rarity tiers below this (Common) get no trail; their arc uses CommonColor
	CommonColor = rgb(222, 228, 238),
	ElementTint = 0.22, -- the zone element color (Config/Combat StyleColors) mixed into the rarity color
	HeadWhite = 0.45, -- the newest part of the trail is lightened this much toward white
	CoreWhite = 0.8, -- arc core = arc color lightened this much toward white
	SparkTint = 0.35, -- impact shards lightened from white toward the element color
	GlowWhite = 0.5, -- the landing flash sparks: the weapon color lightened this much toward white
}
CombatVFX.Trail = { -- applied on the Shared_WeaponTrail clone (one per equipped weapon, Base -> Tip attachments)
	Lifetime = 0.2,
	MinLength = 0.05,
	LightEmission = 0.3, -- low: the rarity color stays readable on bright ground (1 = additive, washes out)
	Brightness = 1.6,
	Transparency = { { 0, 0 }, { 0.5, 0.3 }, { 1, 1 } }, -- { time, value } over the trail's life
	WidthScale = { { 0, 1 }, { 1, 0.35 } },
}
-- per category (the Tool's Category attribute); the trail spans the weapon's Base -> Tip attachments, measured on the V2
-- weapons (ServerStorage.DevTools.WeaponPoints): Sword 3.4-3.6, Spear head 1.3-2, Heavy head 0.9-1.7, Dagger 1.1-1.3,
-- Gauntlet fist 0.6-0.8 studs (the placeholders match); Ranged and Magic have no trail
CombatVFX.TrailByCategory = {
	Spear = { Lifetime = 0.16 },
	Heavy = { Lifetime = 0.3 },
	Dagger = { Lifetime = 0.12 },
	Gauntlet = { Lifetime = 0.1 },
}

-- ARCS (Arcs: beam crescents, rings and straight streaks) -----------------------------------------------------------
-- Per effect: Asset, Shape ("Circle" default | "Line"), Radius / Start + Length, Width, From / To (circle, degrees:
-- 0 = ahead, +90 = right; drawn from From to To), Profile ("Crescent" | "Ring" | "Full" | "Spike" | "Spindle" |
-- "Scallop"), Reveal (s, tail -> head); optional Hold, Fade, Grow (circle: fraction of the radius; line: fraction of
-- the length it moves forward; eased out), Core, Spin (degrees / s), Ground = true (the asset's Ground emitters at
-- the feet). Frame: Anchor ("Root" default | "Feet" | "Hand" | Tool attachment "Tip" | "Base" | "Muzzle" |
-- "Impact"), Height (world up), Offset { right, up, back }, Yaw (+ = left), Pitch (+ = up; 90 = a ring facing
-- forward), Roll (+ raises the right side; 90 = a vertical arc).
CombatVFX.Arc = {
	FadeIn = 0.025, -- each point appears over this
	Hold = 0.05, -- stays at full width this long after it appeared
	Fade = 0.16, -- then thins out (tail first)
	Grow = 0.12,
	Core = 0.32, -- white core width / outer width
	-- look of the beams (applied once per clone): Transparency = { tail, head }
	OuterLook = { LightEmission = 0.35, Brightness = 1.6, Transparency = { 0.45, 0.05 } },
	CoreLook = { LightEmission = 1, Brightness = 1.5, Transparency = { 0.4, 0 } },
}
-- per asset look overrides (Outer / Core like OuterLook / CoreLook, + LightInfluence): matte, lit like the ground
CombatVFX.ArcLook = {
	Shared_DustRing = {
		Outer = { LightEmission = 0, Brightness = 1, LightInfluence = 1, Transparency = { 0.55, 0.3 } },
		Core = { LightEmission = 0, Brightness = 1, LightInfluence = 1, Transparency = { 1, 1 } },
	},
}

-- SWINGS per category and combo step (Config/Combat Combos). TrailOn = fraction of the time to the hit
-- (Combos[category][step].Impact / speed) when the weapon trail starts (= the end of the wind-up of the clip);
-- TrailOff = seconds after the hit (at speed x1, divided by the speed) when it stops; no TrailOn = no trail.
-- Effects: each timed on Hit (0 = the attack call, 1 = Combos Impact (default), 2 = Combos Hits[1]) + Delay (s at x1),
-- Kind = "Arc" (default, see ARCS) | "Lines" (speed lines: Count, Spread { x, y }, Start, Length, Width, Extend, Hold,
-- Fade, Jitter, Solid) | "Ground" (cracks + chunks) | "Flash" (a particle burst on an anchor: muzzle flash with Counts
-- per weapon type, or any particle asset, Emit = count multiplier) | "Charge" (Magic orb; Hand = "LeftHand");
-- Palette = "Element" (the weapon element's color; it also tints the asset's Tint emitters) or Color = Color3 instead
-- of the rarity palette. Magic steps: Grand = true (the bigger area burst, Magic.Grand), Hand = "LeftHand" (the bolt
-- leaves the left hand). A melee category without an entry gets Default (trail only). A missing step uses step 1.
CombatVFX.Swing = {
	Default = { TrailOn = 0.45, TrailOff = 0.12 },
	Sword = {
		-- RightSlash: high right -> low left across the front
		{ TrailOn = 0.45, TrailOff = 0.11, Effects = {
			{ Asset = "Sword_SlashArc", Radius = 4.6, Width = 1.6, Height = 0.5, From = 105, To = -80, Roll = 32, Reveal = 0.06, Profile = "Crescent" },
		} },
		-- LeftSlash: backhand from the left, flat across the front, out to the right
		{ TrailOn = 0.45, TrailOff = 0.11, Effects = {
			{ Asset = "Sword_SlashArc", Radius = 4.6, Width = 1.5, Height = 0.6, From = -105, To = 95, Roll = -10, Reveal = 0.06, Profile = "Crescent" },
		} },
		-- RisingSlash: from the ground in front up over the head (vertical plane, slightly from the right)
		{ TrailOn = 0.45, TrailOff = 0.11, Effects = {
			{ Asset = "Sword_SlashArc", Radius = 4.3, Width = 1.5, Height = 0.4, From = -60, To = 85, Roll = 100, Reveal = 0.06, Profile = "Crescent" },
		} },
		-- SpinSlash finisher: a full circle around the player (380 degrees, turning left like the clip), bigger, brighter
		{ TrailOn = 0.55, TrailOff = 0.22, Effects = {
			{ Asset = "Sword_SpinArc", Radius = 6.4, Width = 2.4, Height = 0.2, From = 90, To = -290, Roll = 0, Reveal = 0.12, Hold = 0.07, Fade = 0.2, Core = 0.4, Profile = "Ring", Ground = true },
		} },
	},
	Spear = {
		-- every effect sits on the spear's TipAttachment at the hit; the thrust runs away from the camera behind the
		-- player, so a ring just past the tip (facing the thrust = the camera) reads as a circle, and the streak and
		-- lines carry the reach
		-- Thrust: driven straight forward right of the body
		{ TrailOn = 0.5, TrailOff = 0.1, Effects = {
			{ Asset = "Spear_PierceStreak", Shape = "Line", Anchor = "Tip", Start = -2.5, Length = 8, Width = 1.1, Reveal = 0.05, Hold = 0.03, Fade = 0.14, Grow = 0.15, Profile = "Spike", Core = 0.35, Delay = -0.02 },
			{ Kind = "Lines", Asset = "Spear_ThrustLines", Anchor = "Tip", Count = 3, Spread = { 1.8, 1.4 }, Start = -2, Length = 6, Width = 0.18, Extend = 0.06, Hold = 0.03, Fade = 0.12, Jitter = 0.03 },
			{ Asset = "Spear_PierceRing", Anchor = "Tip", Offset = { 0, 0, -1.2 }, Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 0.8, Grow = 3, Width = 0.65, Reveal = 0, Hold = 0.02, Fade = 0.16, Core = 0.38 },
		} },
		-- Thrust2: overhand, from above the right shoulder stabbing down-forward
		{ TrailOn = 0.5, TrailOff = 0.1, Effects = {
			{ Asset = "Spear_PierceStreak", Shape = "Line", Anchor = "Tip", Pitch = -10, Start = -2.5, Length = 8, Width = 1.1, Reveal = 0.05, Hold = 0.03, Fade = 0.14, Grow = 0.15, Profile = "Spike", Core = 0.35, Delay = -0.02 },
			{ Kind = "Lines", Asset = "Spear_ThrustLines", Anchor = "Tip", Pitch = -10, Count = 3, Spread = { 1.8, 1.4 }, Start = -2, Length = 6, Width = 0.18, Extend = 0.06, Hold = 0.03, Fade = 0.12, Jitter = 0.03 },
			{ Asset = "Spear_PierceRing", Anchor = "Tip", Pitch = 80, Offset = { 0, 0, -1.2 }, Profile = "Full", From = 0, To = 360, Radius = 0.8, Grow = 3, Width = 0.65, Reveal = 0, Hold = 0.02, Fade = 0.16, Core = 0.38 },
		} },
		-- Sweep (combat V3): the shaft swept flat and low from the far right through the front (Arc 180, radius 8.5): a
		-- wide low crescent and dust kicked up under it
		{ TrailOn = 0.5, TrailOff = 0.14, Effects = {
			{ Asset = "Spear_SweepArc", Radius = 6.8, Width = 2.0, Height = -0.7, From = 105, To = -100, Roll = -4, Reveal = 0.08, Hold = 0.05, Fade = 0.2, Profile = "Crescent", Core = 0.36, Delay = -0.03, Ground = true },
		} },
		-- PiercingLunge finisher (step 4 since combat V3): a longer, brighter streak, more lines, two pierce rings along
		-- the reach (Line 14 studs)
		{ TrailOn = 0.5, TrailOff = 0.18, Effects = {
			{ Asset = "Spear_PierceStreak", Shape = "Line", Anchor = "Tip", Start = -3, Length = 12, Width = 1.7, Reveal = 0.07, Hold = 0.06, Fade = 0.2, Grow = 0.2, Profile = "Spike", Core = 0.45, Delay = -0.02 },
			{ Kind = "Lines", Asset = "Spear_ThrustLines", Anchor = "Tip", Count = 4, Spread = { 2.2, 1.7 }, Start = -2.5, Length = 10, Width = 0.22, Extend = 0.07, Hold = 0.04, Fade = 0.16, Jitter = 0.04 },
			{ Asset = "Spear_PierceRing", Anchor = "Tip", Offset = { 0, 0, -1.5 }, Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 1.0, Grow = 3, Width = 0.85, Reveal = 0, Hold = 0.03, Fade = 0.22, Core = 0.42 },
			{ Asset = "Spear_PierceRing", Anchor = "Tip", Offset = { 0, 0, -6 }, Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 1.2, Grow = 2.6, Width = 0.6, Reveal = 0, Hold = 0.03, Fade = 0.22, Core = 0.38, Delay = 0.04 },
		} },
	},
	Heavy = {
		-- OverheadSlam: a vertical arc from over the head into the ground in front, then cracks, flying chunks and dust
		-- where the head (ImpactAttachment) lands; the server's "Slam" burst adds the shockwave ring
		{ TrailOn = 0.8, TrailOff = 0.1, Effects = {
			{ Asset = "Heavy_SmashArc", Delay = -0.05, Radius = 4.2, Width = 2.4, Height = 1.2, Offset = { 0.4, 0, 0 }, From = 130, To = -58, Roll = 62, Reveal = 0.07, Hold = 0.06, Fade = 0.22, Profile = "Crescent", Core = 0.36 },
			{ Kind = "Ground", Asset = "Heavy_GroundCrack", Anchor = "Impact", Cracks = 6, CrackLength = { 3.5, 6 }, CrackWidth = 0.42, Grow = 0.1, Hold = 1.1, Fade = 0.6, CrackColor = rgb(45, 36, 30),
				Chunks = 6, ChunkSize = { 0.35, 0.7 }, ChunkUp = { 14, 22 }, ChunkOut = { 4, 9 }, Gravity = 70, ChunkLife = 0.75 },
		} },
		-- WideSmash: a full flat sweep from far right across the front to the left, big and bright
		{ TrailOn = 0.75, TrailOff = 0.18, Effects = {
			{ Asset = "Heavy_SmashArc", Delay = -0.06, Radius = 5.8, Width = 2.8, Height = 0.4, From = 150, To = -140, Roll = -6, Reveal = 0.1, Hold = 0.07, Fade = 0.26, Core = 0.4, Profile = "Crescent" },
		} },
		-- GroundBreaker finisher (combat V3): the jump with the weapon over the head, a two-handed slam straight down in
		-- front: a vertical arc into the ground, cracks and chunks where the head lands (the server's "Slam" burst,
		-- radius 9, adds the shockwave and the dust ring)
		{ TrailOn = 0.7, TrailOff = 0.2, Effects = {
			{ Asset = "Heavy_SmashArc", Delay = -0.07, Radius = 4.8, Width = 2.8, Height = 1.6, From = 150, To = -62, Roll = 90, Reveal = 0.08, Hold = 0.07, Fade = 0.26, Profile = "Crescent", Core = 0.4 },
			{ Kind = "Ground", Asset = "Heavy_GroundCrack", Anchor = "Impact", Cracks = 6, CrackLength = { 4.5, 8 }, CrackWidth = 0.5, Grow = 0.1, Hold = 0.9, Fade = 0.5, CrackColor = rgb(45, 36, 30),
				Chunks = 6, ChunkSize = { 0.4, 0.8 }, ChunkUp = { 16, 26 }, ChunkOut = { 5, 10 }, Gravity = 70, ChunkLife = 0.75 },
			{ Kind = "Flash", Asset = "Shared_LandFlash", Anchor = "Impact", Emit = 0.8 },
		} },
	},
	Dagger = {
		-- SlashR / SlashL: small fast arcs alternating sides
		{ TrailOn = 0.5, TrailOff = 0.07, Effects = {
			{ Asset = "Dagger_SlashArc", Radius = 3.6, Width = 1.4, Height = 0.5, From = 110, To = -70, Roll = 14, Reveal = 0.035, Hold = 0.02, Fade = 0.1, Profile = "Crescent" },
		} },
		{ TrailOn = 0.5, TrailOff = 0.07, Effects = {
			{ Asset = "Dagger_SlashArc", Radius = 3.6, Width = 1.4, Height = 0.5, From = -110, To = 70, Roll = -14, Reveal = 0.035, Hold = 0.02, Fade = 0.1, Profile = "Crescent" },
		} },
		-- StabR: a straight stab on the right / StabL: overhand, down on the left
		{ TrailOn = 0.5, TrailOff = 0.07, Effects = {
			{ Asset = "Dagger_StabStreak", Shape = "Line", Anchor = "Tip", Start = -1, Length = 4, Width = 0.7, Reveal = 0.03, Hold = 0.02, Fade = 0.09, Grow = 0.25, Profile = "Spike", Core = 0.4 },
			{ Asset = "Dagger_StabRing", Anchor = "Tip", Offset = { 0, 0, -0.6 }, Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 0.6, Grow = 2.8, Width = 0.5, Reveal = 0, Hold = 0.02, Fade = 0.13, Core = 0.4 },
		} },
		{ TrailOn = 0.5, TrailOff = 0.07, Effects = {
			{ Asset = "Dagger_StabStreak", Shape = "Line", Anchor = "Tip", Yaw = 25, Pitch = -35, Start = -1, Length = 3.8, Width = 0.7, Reveal = 0.03, Hold = 0.02, Fade = 0.09, Grow = 0.25, Profile = "Spike", Core = 0.4 },
			{ Asset = "Dagger_StabRing", Anchor = "Tip", Yaw = 25, Pitch = 55, Offset = { 0, 0, -0.5 }, Profile = "Full", From = 0, To = 360, Radius = 0.6, Grow = 2.8, Width = 0.5, Reveal = 0, Hold = 0.02, Fade = 0.13, Core = 0.4 },
		} },
		-- DoubleSlash finisher: an X, high right down to the left at the hit, high left down to the right at Hits[1]
		{ TrailOn = 0.5, TrailOff = 0.19, Effects = {
			{ Asset = "Dagger_SlashArc", Radius = 3.7, Width = 1.5, Height = 0.6, From = 115, To = -65, Roll = 42, Reveal = 0.035, Hold = 0.03, Fade = 0.12, Profile = "Crescent", Core = 0.42 },
			{ Asset = "Dagger_SlashArc", Hit = 2, Radius = 3.7, Width = 1.5, Height = 0.6, From = -115, To = 65, Roll = -42, Reveal = 0.035, Hold = 0.03, Fade = 0.12, Profile = "Crescent", Core = 0.42 },
		} },
	},
	Gauntlet = {
		-- Jab / Cross: a shockwave ring just in front of the fist, facing the punch (the punch runs along the camera axis,
		-- so the ring reads as a circle), plus short speed lines
		{ TrailOn = 0.5, TrailOff = 0.06, Effects = {
			{ Asset = "Gauntlet_PunchRing", Anchor = "Tip", Offset = { 0, 0, -0.7 }, Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 0.7, Grow = 3, Width = 0.6, Reveal = 0, Hold = 0.02, Fade = 0.15, Core = 0.4 },
			{ Kind = "Lines", Asset = "Gauntlet_PunchLines", Anchor = "Tip", Offset = { 0, 0, 0.6 }, Count = 3, Spread = { 0.6, 0.5 }, Start = 0, Length = 2.4, Width = 0.1, Extend = 0.04, Hold = 0.02, Fade = 0.1, Jitter = 0.02 },
		} },
		{ TrailOn = 0.5, TrailOff = 0.06, Effects = {
			{ Asset = "Gauntlet_PunchRing", Anchor = "Tip", Offset = { 0, 0, -0.7 }, Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 0.8, Grow = 3.3, Width = 0.7, Reveal = 0, Hold = 0.02, Fade = 0.17, Core = 0.4 },
			{ Kind = "Lines", Asset = "Gauntlet_PunchLines", Anchor = "Tip", Offset = { 0, 0, 0.6 }, Count = 4, Spread = { 0.7, 0.6 }, Start = 0, Length = 2.8, Width = 0.11, Extend = 0.04, Hold = 0.02, Fade = 0.1, Jitter = 0.02 },
		} },
		-- Uppercut finisher: flat rings above the rising fist (beside the head) and speed lines going up
		{ TrailOn = 0.5, TrailOff = 0.1, Effects = {
			{ Asset = "Gauntlet_PunchRing", Anchor = "Tip", Offset = { 0, 0.5, 0 }, Profile = "Full", From = 0, To = 360, Radius = 0.8, Grow = 3, Width = 0.8, Reveal = 0, Hold = 0.03, Fade = 0.2, Core = 0.45 },
			{ Asset = "Gauntlet_PunchRing", Anchor = "Tip", Offset = { 0, 1.1, 0 }, Delay = 0.04, Profile = "Full", From = 0, To = 360, Radius = 1.1, Grow = 2.6, Width = 0.55, Reveal = 0, Hold = 0.02, Fade = 0.2, Core = 0.4 },
			{ Kind = "Lines", Asset = "Gauntlet_PunchLines", Anchor = "Tip", Pitch = 90, Count = 4, Spread = { 0.6, 0.6 }, Start = -0.8, Length = 3.2, Width = 0.12, Extend = 0.05, Hold = 0.03, Fade = 0.12, Jitter = 0.02 },
		} },
	},
	Ranged = {
		-- Shot: the muzzle flash at the release (bows: a light snap, crossbows: snap + sparks, guns: fire + smoke) and a
		-- small ring past the muzzle facing the shot (reads as a circle from the camera behind)
		{ Effects = {
			{ Asset = "Ranged_ShotRing", Anchor = "Muzzle", Offset = { 0, 0, -3 }, Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 0.6, Grow = 2.6, Width = 0.5, Reveal = 0, Hold = 0.02, Fade = 0.14, Core = 0.45 },
			{ Kind = "Flash", Asset = "Ranged_MuzzleFlash", Anchor = "Muzzle", Counts = {
				Bow = { Flash = 1, Snap = 5 },
				Crossbow = { Flash = 1, Snap = 6, Sparks = 3 },
				Gun = { Flash = 2, Sparks = 7, Smoke = 3 },
			} },
		} },
		-- QuickShot (combat V3): a snap shot, a smaller ring and flash
		{ Effects = {
			{ Asset = "Ranged_ShotRing", Anchor = "Muzzle", Offset = { 0, 0, -2.5 }, Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 0.5, Grow = 2.4, Width = 0.42, Reveal = 0, Hold = 0.02, Fade = 0.12, Core = 0.45 },
			{ Kind = "Flash", Asset = "Ranged_MuzzleFlash", Anchor = "Muzzle", Counts = {
				Bow = { Flash = 1, Snap = 4 },
				Crossbow = { Flash = 1, Snap = 5, Sparks = 2 },
				Gun = { Flash = 2, Sparks = 5, Smoke = 2 },
			} },
		} },
		-- PowerShot finisher (combat V3; faster arrow): a bigger flash, two rings along the shot, a bright streak shooting
		-- ahead of the arrow and dust kicked back under the feet (the recoil step)
		{ Effects = {
			{ Asset = "Ranged_ShotRing", Anchor = "Muzzle", Offset = { 0, 0, -3 }, Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 0.8, Grow = 3, Width = 0.7, Reveal = 0, Hold = 0.03, Fade = 0.18, Core = 0.5 },
			{ Asset = "Ranged_ShotRing", Anchor = "Muzzle", Offset = { 0, 0, -7 }, Delay = 0.03, Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 0.7, Grow = 2.6, Width = 0.5, Reveal = 0, Hold = 0.02, Fade = 0.16, Core = 0.45 },
			{ Asset = "Shared_DashStreak", Shape = "Line", Anchor = "Muzzle", Start = 0.5, Length = 14, Width = 0.9, Reveal = 0.05, Hold = 0.03, Fade = 0.16, Grow = 0.3, Profile = "Spike", Core = 0.55, Color = rgb(255, 236, 190) },
			{ Kind = "Flash", Asset = "Ranged_MuzzleFlash", Anchor = "Muzzle", Counts = {
				Bow = { Flash = 2, Snap = 10 },
				Crossbow = { Flash = 2, Snap = 10, Sparks = 6 },
				Gun = { Flash = 3, Sparks = 12, Smoke = 5 },
			} },
			{ Kind = "Flash", Asset = "Shared_RollDust", Anchor = "Feet", Height = 0.2, Yaw = 180, Emit = 0.8 },
		} },
	},
	Magic = {
		-- Cast: two counter-spinning circles under the caster from the cast start to the release, the charge orb at the
		-- staff head until the release; the bolt and the area burst come with the server's Burst (Casts)
		{ Effects = {
			{ Hit = 0, Asset = "Magic_CastCircle", Anchor = "Feet", Height = 0.12, Profile = "Scallop", From = 0, To = 360, Radius = 2.6, Grow = 0, Width = 0.32, Reveal = 0.14, Hold = 0.05, HoldToHit = true, Fade = 0.25, Spin = 80, Palette = "Element", Core = 0.45 },
			{ Hit = 0, Asset = "Magic_CastCircle", Anchor = "Feet", Height = 0.14, Profile = "Scallop", From = 0, To = 360, Radius = 1.6, Grow = 0, Width = 0.26, Reveal = 0.1, Hold = 0.05, HoldToHit = true, Fade = 0.25, Spin = -140, Palette = "Element", Core = 0.45 },
			{ Kind = "Charge", Hit = 0, Asset = "Magic_ChargeOrb", Size = { 0.3, 1.0 }, Pulse = 0.12, PulseSpeed = 28, Transparency = 0.05, Linger = 0.35, Continuous = { Motes = true, Glow = true } },
		} },
		-- Cast2 (combat V3): the other hand: circles turning the other way, the orb gathers in the left palm and the bolt
		-- leaves it
		{ Hand = "LeftHand", Effects = {
			{ Hit = 0, Asset = "Magic_CastCircle", Anchor = "Feet", Height = 0.12, Profile = "Scallop", From = 0, To = 360, Radius = 2.6, Grow = 0, Width = 0.32, Reveal = 0.14, Hold = 0.05, HoldToHit = true, Fade = 0.25, Spin = -80, Palette = "Element", Core = 0.45 },
			{ Hit = 0, Asset = "Magic_CastCircle", Anchor = "Feet", Height = 0.14, Profile = "Scallop", From = 0, To = 360, Radius = 1.6, Grow = 0, Width = 0.26, Reveal = 0.1, Hold = 0.05, HoldToHit = true, Fade = 0.25, Spin = 140, Palette = "Element", Core = 0.45 },
			{ Kind = "Charge", Hit = 0, Asset = "Magic_ChargeOrb", Hand = "LeftHand", Size = { 0.25, 0.85 }, Pulse = 0.12, PulseSpeed = 30, Transparency = 0.05, Linger = 0.3, Continuous = { Motes = true, Glow = true } },
		} },
		-- GrandCast finisher (combat V3; radius 8.5): bigger circles plus a slow outer rune ring, a bigger orb, and the
		-- grand area burst (Magic.Grand)
		{ Grand = true, Effects = {
			{ Hit = 0, Asset = "Magic_CastCircle", Anchor = "Feet", Height = 0.12, Profile = "Scallop", From = 0, To = 360, Radius = 3.4, Grow = 0, Width = 0.38, Reveal = 0.16, Hold = 0.05, HoldToHit = true, Fade = 0.3, Spin = 70, Palette = "Element", Core = 0.45 },
			{ Hit = 0, Asset = "Magic_CastCircle", Anchor = "Feet", Height = 0.14, Profile = "Scallop", From = 0, To = 360, Radius = 2.2, Grow = 0, Width = 0.3, Reveal = 0.12, Hold = 0.05, HoldToHit = true, Fade = 0.3, Spin = -130, Palette = "Element", Core = 0.45 },
			{ Hit = 0, Delay = 0.1, Asset = "Magic_CastCircle", Anchor = "Feet", Height = 0.1, Profile = "Scallop", From = 0, To = 360, Radius = 4.4, Grow = 0, Width = 0.22, Reveal = 0.16, Hold = 0.04, HoldToHit = true, Fade = 0.3, Spin = 40, Palette = "Element", Core = 0.4 },
			{ Kind = "Charge", Hit = 0, Asset = "Magic_ChargeOrb", Size = { 0.4, 1.6 }, Pulse = 0.14, PulseSpeed = 26, Transparency = 0.05, Linger = 0.4, Continuous = { Motes = true, Glow = true } },
		} },
	},
}

-- JUMP ATTACKS (combat V3, VFX.swing Variant "Air"; timed on Config/Combat AirAttacks, same spec as a Swing step).
-- Melee: Dive (Dives) = while the body dives: streaks from the dive start down to the body, a wind ring at the dive
-- start, the weapon trail on for the whole dive; the landing itself is VFX.land (LAND below). Spec: Asset, Count,
-- Spread (studs), Top / Bottom { min, max } (studs above the dive start / the root), Width, Fade (s, after the
-- landing), MinFall (studs / s: the dive starts), LandGap (studs between the feet and the ground: landed), Timeout,
-- Color? + Solid?, Ring + RingHeight, TrailOff.
local DIVE_RING = { Asset = "Shared_WindRing", Profile = "Full", From = 0, To = 360, Radius = 1.1, Grow = 2.4, Width = 0.55, Reveal = 0, Hold = 0.03, Fade = 0.2, Core = 0.45 }
CombatVFX.AirSwing = {
	Sword = { Dive = { Asset = "Shared_DiveLines", Count = 6, Spread = 1.3, Top = { 0.5, 2.5 }, Bottom = { 0.4, 2.2 }, Width = 0.3, Fade = 0.14, MinFall = 18, LandGap = 0.6, Timeout = 1.8, TrailOff = 0.12, Ring = DIVE_RING, RingHeight = -0.5 } },
	Spear = { Dive = { Asset = "Shared_DiveLines", Count = 6, Spread = 1.2, Top = { 0.5, 2.5 }, Bottom = { 0.4, 2.4 }, Width = 0.28, Fade = 0.14, MinFall = 18, LandGap = 0.6, Timeout = 1.8, TrailOff = 0.12, Ring = DIVE_RING, RingHeight = -0.5 } },
	Heavy = { Dive = { Asset = "Shared_DiveLines", Count = 8, Spread = 1.6, Top = { 0.5, 3 }, Bottom = { 0.3, 2.4 }, Width = 0.4, Fade = 0.18, MinFall = 18, LandGap = 0.6, Timeout = 1.9, TrailOff = 0.16, Ring = DIVE_RING, RingHeight = -0.5 } },
	-- ShadowDrop: dark violet streaks (a shadow falling), no wind ring
	Dagger = { Dive = { Asset = "Shared_DiveLines", Count = 5, Spread = 1.0, Top = { 0.3, 2 }, Bottom = { 0.4, 2 }, Width = 0.24, Fade = 0.12, MinFall = 18, LandGap = 0.6, Timeout = 1.6, TrailOff = 0.1, Color = rgb(110, 70, 185), Solid = true } },
	Gauntlet = { Dive = { Asset = "Shared_DiveLines", Count = 6, Spread = 1.3, Top = { 0.5, 2.5 }, Bottom = { 0.4, 2.2 }, Width = 0.32, Fade = 0.14, MinFall = 18, LandGap = 0.6, Timeout = 1.8, TrailOff = 0.1, Ring = DIVE_RING, RingHeight = -0.5 } },
	-- AirVolley: the body hovers (a wind ring under the feet), the volley is released aimed down (a ring past the muzzle
	-- tilted along the shot, a bigger flash); the 3 arrows are VFX.shot
	Ranged = { Effects = {
		{ Hit = 0, Asset = "Shared_WindRing", Anchor = "Root", Height = -2.7, Profile = "Full", From = 0, To = 360, Radius = 1.0, Grow = 2.4, Width = 0.5, Reveal = 0, Hold = 0.04, Fade = 0.24, Core = 0.45 },
		{ Asset = "Ranged_ShotRing", Anchor = "Muzzle", Offset = { 0, -1.6, -1.9 }, Pitch = 50, Profile = "Full", From = 0, To = 360, Radius = 0.7, Grow = 2.8, Width = 0.55, Reveal = 0, Hold = 0.02, Fade = 0.16, Core = 0.45 },
		{ Kind = "Flash", Asset = "Ranged_MuzzleFlash", Anchor = "Muzzle", Counts = {
			Bow = { Flash = 2, Snap = 8 },
			Crossbow = { Flash = 2, Snap = 8, Sparks = 5 },
			Gun = { Flash = 3, Sparks = 10, Smoke = 4 },
		} },
	} },
	-- MeteorDrop: two circles under the hovering feet and one at the raised staff head until the release, a big orb;
	-- the server's Burst (radius 9) plays the grand area burst where the bolt lands
	Magic = { Grand = true, Effects = {
		{ Hit = 0, Asset = "Magic_CastCircle", Anchor = "Root", Height = -2.9, Profile = "Scallop", From = 0, To = 360, Radius = 3.0, Grow = 0, Width = 0.36, Reveal = 0.14, Hold = 0.05, HoldToHit = true, Fade = 0.25, Spin = 90, Palette = "Element", Core = 0.45 },
		{ Hit = 0, Asset = "Magic_CastCircle", Anchor = "Root", Height = -2.85, Profile = "Scallop", From = 0, To = 360, Radius = 1.9, Grow = 0, Width = 0.28, Reveal = 0.1, Hold = 0.05, HoldToHit = true, Fade = 0.25, Spin = -150, Palette = "Element", Core = 0.45 },
		{ Hit = 0, Delay = 0.18, Asset = "Magic_CastCircle", Anchor = "Muzzle", Offset = { 0, 0, -0.6 }, Pitch = 90, Profile = "Scallop", From = 0, To = 360, Radius = 1.3, Grow = 0, Width = 0.22, Reveal = 0.08, Hold = 0.04, HoldToHit = true, Fade = 0.2, Spin = 160, Palette = "Element", Core = 0.45 },
		{ Kind = "Charge", Hit = 0, Asset = "Magic_ChargeOrb", Size = { 0.4, 1.4 }, Pulse = 0.14, PulseSpeed = 30, Transparency = 0.05, Linger = 0.35, Continuous = { Motes = true, Glow = true } },
	} },
}

-- DASH STRIKES (combat V3, VFX.swing Variant "Dash"; timed on Config/Combat DashAttacks, same spec as a Swing step).
-- Melee: the lunge's wake (speed lines running with the body from where it started, Extend = LungeSeconds, Length =
-- Lunge + ~2.5; a straight streak revealed along the path over the lunge) + the category's strike at the hit.
CombatVFX.DashSwing = {
	-- DashSlash (lunge 6 in 0.16 s, line 9): a flat slash through the front to the left
	Sword = { TrailOn = 0.3, TrailOff = 0.14, Effects = {
		{ Kind = "Lines", Hit = 0, Asset = "Shared_DashLines", Height = -0.2, Count = 5, Spread = { 1.3, 1.5 }, Start = -1.5, Length = 8.5, Width = 0.2, Extend = 0.16, Hold = 0.04, Fade = 0.16, Jitter = 0.03 },
		{ Hit = 0, Asset = "Shared_DashStreak", Shape = "Line", Height = -0.1, Start = -1.2, Length = 7.5, Width = 1.6, Reveal = 0.16, Hold = 0.02, Fade = 0.16, Grow = 0, Profile = "Spike", Core = 0.25 },
		{ Asset = "Sword_SlashArc", Delay = -0.02, Radius = 5.2, Width = 1.9, Height = 0.2, From = 115, To = -100, Roll = -6, Reveal = 0.06, Hold = 0.05, Fade = 0.18, Profile = "Crescent", Core = 0.42 },
	} },
	-- ChargeThrust (lunge 8 in 0.18 s, line 13): the PiercingLunge look, longer
	Spear = { TrailOn = 0.3, TrailOff = 0.16, Effects = {
		{ Kind = "Lines", Hit = 0, Asset = "Shared_DashLines", Height = -0.2, Count = 5, Spread = { 1.3, 1.5 }, Start = -1.5, Length = 10.5, Width = 0.2, Extend = 0.18, Hold = 0.04, Fade = 0.16, Jitter = 0.03 },
		{ Hit = 0, Asset = "Shared_DashStreak", Shape = "Line", Height = -0.1, Start = -1.2, Length = 9.5, Width = 1.5, Reveal = 0.18, Hold = 0.02, Fade = 0.16, Grow = 0, Profile = "Spike", Core = 0.25 },
		{ Asset = "Spear_PierceStreak", Shape = "Line", Anchor = "Tip", Start = -3, Length = 13, Width = 1.8, Reveal = 0.07, Hold = 0.06, Fade = 0.2, Grow = 0.2, Profile = "Spike", Core = 0.45, Delay = -0.02 },
		{ Kind = "Lines", Asset = "Spear_ThrustLines", Anchor = "Tip", Count = 4, Spread = { 2.2, 1.7 }, Start = -2.5, Length = 11, Width = 0.22, Extend = 0.07, Hold = 0.04, Fade = 0.16, Jitter = 0.04 },
		{ Asset = "Spear_PierceRing", Anchor = "Tip", Offset = { 0, 0, -1.5 }, Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 1.0, Grow = 3, Width = 0.85, Reveal = 0, Hold = 0.03, Fade = 0.22, Core = 0.42 },
		{ Asset = "Spear_PierceRing", Anchor = "Tip", Offset = { 0, 0, -7 }, Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 1.3, Grow = 2.6, Width = 0.6, Reveal = 0, Hold = 0.03, Fade = 0.22, Core = 0.38, Delay = 0.04 },
	} },
	-- RushingSmash (lunge 5 in 0.20 s, arc 150): dust kicked back at the start, a rising diagonal smash from low right
	-- to high left
	Heavy = { TrailOn = 0.55, TrailOff = 0.18, Effects = {
		{ Kind = "Flash", Hit = 0, Asset = "Shared_RollDust", Anchor = "Feet", Height = 0.2, Yaw = 180, Emit = 1.4 },
		{ Kind = "Lines", Hit = 0, Asset = "Shared_DashLines", Height = -0.2, Count = 5, Spread = { 1.5, 1.6 }, Start = -1.5, Length = 7.5, Width = 0.26, Extend = 0.2, Hold = 0.04, Fade = 0.18, Jitter = 0.03 },
		{ Hit = 0, Asset = "Shared_DashStreak", Shape = "Line", Height = -0.1, Start = -1.2, Length = 6.5, Width = 2.0, Reveal = 0.2, Hold = 0.02, Fade = 0.18, Grow = 0, Profile = "Spike", Core = 0.25 },
		{ Asset = "Heavy_SmashArc", Delay = -0.06, Radius = 5.4, Width = 2.6, Height = 0.6, From = 125, To = -45, Roll = -38, Reveal = 0.1, Hold = 0.06, Fade = 0.24, Profile = "Crescent", Core = 0.38 },
	} },
	-- ShadowStep (lunge 6 in 0.14 s, hits 0.10 + 0.18): a shadow puff where it vanishes, dark wake, forehand then
	-- backhand slashes
	Dagger = { TrailOn = 0.4, TrailOff = 0.1, Effects = {
		{ Kind = "Flash", Hit = 0, Asset = "Dagger_ShadowPuff", Anchor = "Feet", Height = 0.3, Emit = 0.6 },
		{ Kind = "Lines", Hit = 0, Asset = "Shared_DashLines", Height = -0.2, Count = 5, Spread = { 1.1, 1.3 }, Start = -1.5, Length = 8.5, Width = 0.22, Extend = 0.14, Hold = 0.04, Fade = 0.16, Jitter = 0.03, Color = rgb(110, 70, 185), Solid = true },
		{ Hit = 0, Asset = "Shared_DashStreak", Shape = "Line", Height = -0.1, Start = -1.2, Length = 7.5, Width = 1.3, Reveal = 0.14, Hold = 0.02, Fade = 0.16, Grow = 0, Profile = "Spike", Core = 0.2, Color = rgb(120, 80, 200) },
		{ Asset = "Dagger_SlashArc", Radius = 3.8, Width = 1.5, Height = 0.4, From = 110, To = -75, Roll = 12, Reveal = 0.035, Hold = 0.03, Fade = 0.12, Profile = "Crescent", Core = 0.42 },
		{ Asset = "Dagger_SlashArc", Hit = 2, Radius = 3.8, Width = 1.5, Height = 0.5, From = -110, To = 75, Roll = -12, Reveal = 0.035, Hold = 0.03, Fade = 0.12, Profile = "Crescent", Core = 0.42 },
	} },
	-- RocketPunch (lunge 6 in 0.16 s, line 8): wake, a big ring at the fist, a second one ahead, lines and a thrust
	-- streak past the fist
	Gauntlet = { TrailOn = 0.3, TrailOff = 0.08, Effects = {
		{ Kind = "Lines", Hit = 0, Asset = "Shared_DashLines", Height = -0.2, Count = 5, Spread = { 1.3, 1.5 }, Start = -1.5, Length = 8.5, Width = 0.2, Extend = 0.16, Hold = 0.04, Fade = 0.16, Jitter = 0.03 },
		{ Hit = 0, Asset = "Shared_DashStreak", Shape = "Line", Height = -0.1, Start = -1.2, Length = 7.5, Width = 1.5, Reveal = 0.16, Hold = 0.02, Fade = 0.16, Grow = 0, Profile = "Spike", Core = 0.25 },
		{ Asset = "Gauntlet_PunchRing", Anchor = "Tip", Offset = { 0, 0, -0.8 }, Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 1.0, Grow = 3.4, Width = 0.8, Reveal = 0, Hold = 0.03, Fade = 0.2, Core = 0.45 },
		{ Asset = "Gauntlet_PunchRing", Anchor = "Tip", Offset = { 0, 0, -4 }, Delay = 0.03, Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 1.2, Grow = 2.8, Width = 0.6, Reveal = 0, Hold = 0.02, Fade = 0.2, Core = 0.4 },
		{ Kind = "Lines", Asset = "Gauntlet_PunchLines", Anchor = "Tip", Offset = { 0, 0, 0.8 }, Count = 4, Spread = { 0.8, 0.7 }, Start = 0, Length = 5, Width = 0.14, Extend = 0.05, Hold = 0.03, Fade = 0.12, Jitter = 0.02 },
		{ Asset = "Shared_DashStreak", Shape = "Line", Anchor = "Tip", Start = -1, Length = 7, Width = 1.0, Reveal = 0.04, Hold = 0.03, Fade = 0.14, Grow = 0.3, Profile = "Spike", Core = 0.45 },
	} },
	-- SlideShot (no lunge): dust under the sliding knee, the shot ring and flash
	Ranged = { Effects = {
		{ Kind = "Flash", Hit = 0, Asset = "Shared_RollDust", Anchor = "Feet", Height = 0.2, Emit = 1.3 },
		{ Asset = "Ranged_ShotRing", Anchor = "Muzzle", Offset = { 0, 0, -3 }, Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 0.7, Grow = 2.8, Width = 0.6, Reveal = 0, Hold = 0.02, Fade = 0.16, Core = 0.45 },
		{ Kind = "Flash", Asset = "Ranged_MuzzleFlash", Anchor = "Muzzle", Counts = {
			Bow = { Flash = 1, Snap = 7 },
			Crossbow = { Flash = 1, Snap = 8, Sparks = 4 },
			Gun = { Flash = 2, Sparks = 9, Smoke = 4 },
		} },
	} },
	-- BlinkBlast (a radius 6 blast around the caster at the hit, no Burst from the server): a quick circle and orb,
	-- then the area burst sized to 6 (Radius 1.5 x (1 + Grow 3)) and a ring
	Magic = { Effects = {
		{ Hit = 0, Asset = "Magic_CastCircle", Anchor = "Feet", Height = 0.12, Profile = "Scallop", From = 0, To = 360, Radius = 2.2, Grow = 0.5, Width = 0.32, Reveal = 0.08, Hold = 0.04, HoldToHit = true, Fade = 0.2, Spin = 140, Palette = "Element", Core = 0.45 },
		{ Kind = "Charge", Hit = 0, Asset = "Magic_ChargeOrb", Size = { 0.3, 1.1 }, Pulse = 0.12, PulseSpeed = 30, Transparency = 0.05, Linger = 0.25, Continuous = { Motes = true, Glow = true } },
		{ Asset = "Magic_AreaBurst", Anchor = "Feet", Height = 0.2, Profile = "Full", From = 0, To = 360, Radius = 1.5, Grow = 3, Width = 1.4, Reveal = 0, Hold = 0.06, Fade = 0.3, Core = 0.4, Palette = "Element" },
		{ Asset = "Shared_LandRing", Anchor = "Feet", Height = 0.25, Delay = 0.04, Profile = "Full", From = 0, To = 360, Radius = 1.2, Grow = 3.6, Width = 0.6, Reveal = 0, Hold = 0.03, Fade = 0.28, Core = 0.5, Palette = "Element" },
	} },
}

-- LANDING (VFX.land, combat V3) -----------------------------------------------------------------------------------
-- A melee jump attack hits the ground: every effect sits in the landing frame (the ground point, looking along the
-- attacker's facing) + Offset { right, up, back } + Lift (studs up), turned by Yaw / Pitch / Roll; Delay (s).
-- Kind = "Ring" (default: an Arcs spec laid flat; Scale = true: Radius / Length x the hit radius, so Radius x
-- (1 + Grow) = 1 reaches the hit circle exactly; Palette = "Ground": the dust color) | "Line" (an Arcs Line, Pitch 90 =
-- straight up) | "Burst" (the particles of Asset; Emit x the hit radius / RadiusRef unless Fixed; Tint = "Ground" (the
-- dust color) | "Weapon" (the weapon glow)) | "Ground" (cracks + chunks, see the Heavy swing's Ground spec). Short:
-- everything is gone within 0.8 s. Low FX halves the particles and chunks.
local LAND_SWORD = { Effects = {
	{ Asset = "Shared_LandRing", Scale = true, Lift = 0.25, Profile = "Full", From = 0, To = 360, Radius = 0.25, Grow = 3, Width = 1.5, Reveal = 0, Hold = 0.05, Fade = 0.28, Core = 0.42 },
	{ Asset = "Shared_DustRing", Scale = true, Palette = "Ground", Delay = 0.04, Lift = 0.2, Profile = "Full", From = 0, To = 360, Radius = 0.2, Grow = 3.3, Width = 2.4, Reveal = 0, Hold = 0.03, Fade = 0.38, Core = 0.05 },
	{ Kind = "Burst", Asset = "Shared_LandFlash", Tint = "Weapon", Offset = { 0.8, 0.5, -2 }, Fixed = true },
	{ Kind = "Burst", Asset = "Shared_LandDust", Tint = "Ground", Lift = 0.3 },
} }
CombatVFX.Land = {
	Probe = 4, -- studs above / below the sent point searched for the ground
	DefaultRadius = 6,
	RadiusRef = 7, -- "Burst" Emit counts x radius / RadiusRef, clamped to EmitScale
	EmitScale = { 0.7, 1.4 },
	DustColor = rgb(185, 165, 135), -- the dust, mixed with the ground's color
	RingColor = rgb(170, 148, 118), -- the dust rings (Palette = "Ground", matte Shared_DustRing), mixed with the ground
	GroundTint = 0.2,
	-- PlungeStrike (r 7): weapon-colored shockwave + a dust ring, flash where the point goes in (front right), dust
	Sword = LAND_SWORD,
	-- DragoonDive (r 6.5): a sharp thin bright ring, a spike shooting up from the spear point, a small pierce ring
	Spear = { Effects = {
		{ Asset = "Shared_LandRing", Scale = true, Lift = 0.25, Profile = "Full", From = 0, To = 360, Radius = 0.25, Grow = 3, Width = 0.8, Reveal = 0, Hold = 0.03, Fade = 0.2, Core = 0.6 },
		{ Asset = "Shared_LandRing", Scale = true, Delay = 0.05, Lift = 0.25, Profile = "Full", From = 0, To = 360, Radius = 0.15, Grow = 3.6, Width = 0.5, Reveal = 0, Hold = 0.02, Fade = 0.18, Core = 0.6 },
		{ Kind = "Line", Asset = "Spear_PierceStreak", Shape = "Line", Offset = { 0.8, 0, -2.2 }, Pitch = 90, Start = -0.5, Length = 7, Width = 1.1, Reveal = 0.05, Hold = 0.04, Fade = 0.16, Grow = 0.25, Profile = "Spike", Core = 0.5 },
		{ Asset = "Spear_PierceRing", Offset = { 0.8, 0, -2.2 }, Lift = 0.3, Profile = "Full", From = 0, To = 360, Radius = 0.6, Grow = 3.5, Width = 0.6, Reveal = 0, Hold = 0.02, Fade = 0.16, Core = 0.45 },
		{ Kind = "Burst", Asset = "Shared_LandDust", Tint = "Ground", Lift = 0.3, Emit = 0.7 },
	} },
	-- MeteorSmash (r 9): the biggest: wide shockwave, a dust ring, long cracks and flying chunks where the head
	-- crashes (ahead), a big flash, lots of dust
	Heavy = { Effects = {
		{ Asset = "Shared_LandRing", Scale = true, Lift = 0.25, Profile = "Full", From = 0, To = 360, Radius = 0.25, Grow = 3, Width = 2.4, Reveal = 0, Hold = 0.06, Fade = 0.34, Core = 0.4 },
		{ Asset = "Shared_DustRing", Scale = true, Palette = "Ground", Delay = 0.05, Lift = 0.2, Profile = "Full", From = 0, To = 360, Radius = 0.2, Grow = 3.4, Width = 3.2, Reveal = 0, Hold = 0.04, Fade = 0.42, Core = 0.05 },
		{ Kind = "Ground", Asset = "Shared_LandCrack", Offset = { 0.6, 0, -2.4 }, Cracks = 9, CrackLength = { 4, 7.5 }, CrackWidth = 0.5, Grow = 0.09, Hold = 0.3, Fade = 0.35, CrackColor = rgb(45, 36, 30),
			Chunks = 10, ChunkSize = { 0.4, 0.85 }, ChunkUp = { 16, 26 }, ChunkOut = { 5, 11 }, Gravity = 75, ChunkLife = 0.7 },
		{ Kind = "Burst", Asset = "Shared_LandFlash", Tint = "Weapon", Offset = { 0.6, 0.5, -2.4 }, Emit = 1.3, Fixed = true },
		{ Kind = "Burst", Asset = "Shared_LandDust", Tint = "Ground", Lift = 0.3, Emit = 1.2 },
	} },
	-- ShadowDrop (r 5): lighter and shadowy: a dark matte shadow wave, a thin violet ring, a dark smoke ring with wisps,
	-- a small flash at the blade
	Dagger = { Effects = {
		{ Asset = "Shared_DustRing", Scale = true, Color = rgb(55, 35, 85), Lift = 0.2, Profile = "Full", From = 0, To = 360, Radius = 0.22, Grow = 3.5, Width = 2.2, Reveal = 0, Hold = 0.04, Fade = 0.3, Core = 0 },
		{ Asset = "Shared_LandRing", Scale = true, Color = rgb(140, 95, 220), Lift = 0.25, Profile = "Full", From = 0, To = 360, Radius = 0.25, Grow = 3, Width = 0.45, Reveal = 0, Hold = 0.03, Fade = 0.2, Core = 0.3 },
		{ Kind = "Burst", Asset = "Dagger_ShadowPuff", Lift = 0.3, Emit = 1.3 },
		{ Kind = "Burst", Asset = "Shared_LandFlash", Tint = "Weapon", Offset = { 0.7, 0.3, -1.6 }, Emit = 0.5, Fixed = true },
	} },
	-- GroundPound (r 7.5): shockwave + dust ring, short cracks and chunks where both fists hit (in front), flash, dust
	Gauntlet = { Effects = {
		{ Asset = "Shared_LandRing", Scale = true, Lift = 0.25, Profile = "Full", From = 0, To = 360, Radius = 0.25, Grow = 3, Width = 1.8, Reveal = 0, Hold = 0.05, Fade = 0.3, Core = 0.42 },
		{ Asset = "Shared_DustRing", Scale = true, Palette = "Ground", Delay = 0.04, Lift = 0.2, Profile = "Full", From = 0, To = 360, Radius = 0.2, Grow = 3.3, Width = 2.6, Reveal = 0, Hold = 0.03, Fade = 0.38, Core = 0.05 },
		{ Kind = "Ground", Asset = "Shared_LandCrack", Offset = { 0, 0, -1.6 }, Cracks = 6, CrackLength = { 2.5, 4.5 }, CrackWidth = 0.4, Grow = 0.08, Hold = 0.3, Fade = 0.35, CrackColor = rgb(45, 36, 30),
			Chunks = 6, ChunkSize = { 0.3, 0.6 }, ChunkUp = { 14, 22 }, ChunkOut = { 4, 8 }, Gravity = 75, ChunkLife = 0.6 },
		{ Kind = "Burst", Asset = "Shared_LandFlash", Tint = "Weapon", Offset = { 0, 0.4, -1.6 }, Fixed = true },
		{ Kind = "Burst", Asset = "Shared_LandDust", Tint = "Ground", Lift = 0.3 },
	} },
	Default = LAND_SWORD,
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
	CategoryEmit = { Dagger = 0.7, Heavy = 1.5, Gauntlet = 1.2 }, -- normal sparks x this (Dagger hits 2.5 times a second)
	CritEmit = { Dagger = 0.85 },
	-- crits of these categories also flash a quick X slash mark facing the camera (Dagger crits often)
	CritCross = {
		Dagger = { Asset = "Dagger_StabStreak", Shape = "Line", Start = -1.4, Length = 2.8, Width = 0.45, Profile = "Spindle", Reveal = 0.03, Hold = 0.03, Fade = 0.1, Grow = 0, Core = 0.5, Second = 0.04 },
	},
	CritCrossColor = rgb(255, 215, 80),
	EnemyMatch = 4, -- studs (horizontal): the hit position is matched to the enemy root within this
	TowardCamera = 0.7, -- the spark sits this fraction of the enemy root's half width toward the camera
	FallbackDrop = 1.5, -- no enemy found: the spark goes this far below the hit position (sent above the head)
	-- zone accents on impacts (ZONE STYLES below): crits x ZoneCritK particles; at most ZoneMax accents per ZoneWindow s
	ZoneCritK = 1.5,
	ZoneMax = 3,
	ZoneWindow = 0.1,
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
	DustColor = rgb(200, 186, 160), -- the dust puff (Dust emitter), mixed with the ground's color
	DustGroundTint = 0.3, -- fraction of the ground color (terrain material / part color) in the dust
	DustLift = 0.2, -- studs above the ground
	-- afterimages (combat V3 dodge fix: they used to be Neon at 0.4 and the curled roll pose sank them into the ground:
	-- a blue glow on the ground and a flickering ground texture)
	Ghost = "Shared_Afterimage", -- material of the afterimages (SmoothPlastic: no bloom)
	GhostColor = Color3.fromRGB(120, 190, 255),
	GhostFrom = 0.5, -- transparency of a fresh afterimage (fades to 1)
	Ghosts = 3, -- afterimages per roll (none with Low FX)
	Interval = 0.06, -- seconds between two snapshots of the pose
	Fade = 0.25, -- each ghost fades out over this
	GroundMargin = 0.12, -- studs: a ghost is lifted until its lowest part is this far above the ground under the body
	MaxLift = 1.6, -- studs at most (the roll clip sinks the body up to ~1.2)
	HideBelow = 0.04, -- after the lift, parts whose bottom is still under this height above the ground are hidden
	GroundProbe = 8, -- studs below HumanoidRootPart searched for the ground
	FeetDrop = 3, -- the dust goes this far below HumanoidRootPart when no ground is found
	PrepareEvery = 1, -- s between two checks of the afterimage watcher (one character prepared per check)
	PrepareAfter = 2, -- s a character must exist before its afterimages are prepared (its appearance loads first)
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

-- SHOTS (VFX.shot, Shots) ------------------------------------------------------------------------------------------
CombatVFX.Shot = {
	MinTime = 0.05,
	TrailLife = 0.2,
	MaxHold = 0.3, -- s: a player's arrow waits at most this long for the release of its swing (Shots.record)
}
CombatVFX.Ranged = {
	Default = "Bow", -- weapon type of a Ranged Tool missing from Kinds
	Kinds = { -- Ranged WeaponId -> weapon type (bows, crossbows, guns / blowgun)
		plains_ranged = "Bow", desert_ranged = "Bow", swamp_ranged = "Bow", volcano_ranged = "Bow", heaven_ranged = "Bow", void_ranged = "Bow",
		tundra_ranged = "Crossbow", hell_ranged = "Crossbow", dead_ranged = "Crossbow",
		jungle_ranged = "Gun", abyss_ranged = "Gun", mechanical_ranged = "Gun",
	},
	ShooterRange = 4, -- studs: a player root this close to the server muzzle (minus its lift) is the shooter
	-- projectile per weapon type (Orb: Magic tools / unknown shooters, Enemy: enemy shots); Size = ball diameter
	Looks = {
		Bow = { Asset = "Ranged_Arrow", Spark = "Shared_HitSpark", SparkEmit = 0.8 },
		Crossbow = { Asset = "Ranged_Bolt", Spark = "Shared_HitSpark", SparkEmit = 0.9 },
		Gun = { Asset = "Ranged_Bullet", Spark = "Shared_HitSpark", SparkEmit = 0.7 },
		Orb = { Asset = "Shared_Projectile", Size = 0.9, Spark = "Shared_HitSpark" },
		Enemy = { Asset = "Shared_Projectile", Size = 1.4, Spark = "Shared_HitSpark" },
	},
}

-- MAGIC (Casts) ----------------------------------------------------------------------------------------------------
CombatVFX.Magic = {
	LinkWindow = 0.6, -- s: a Burst this soon after a Magic cast belongs to it
	LinkRange = 45, -- studs between the caster and the burst
	-- the bolt from the staff head to the area at the release
	Bolt = { Asset = "Magic_Bolt", Speed = 220, MinTravel = 0.04, MaxTravel = 0.12, Height = 0.8 },
	-- the area burst: a ring that grows to the burst radius (Radius x radius x (1 + Grow)), + flash, column, motes
	Area = { Asset = "Magic_AreaBurst", Profile = "Full", From = 0, To = 360, Radius = 0.25, Grow = 3, Width = 1.4, Reveal = 0, Hold = 0.06, Fade = 0.3, Core = 0.4, Lift = 0.2 },
	-- grand casts (GrandCast, MeteorDrop: Swing / AirSwing Grand = true): the area burst + these, sized to the radius
	-- like Area (Radius x radius x (1 + Grow)): a second shockwave ring just after, a rune ring turning inside
	Grand = { Extra = {
		{ Asset = "Shared_LandRing", Profile = "Full", From = 0, To = 360, Radius = 0.2, Grow = 4, Width = 0.8, Reveal = 0, Hold = 0.04, Fade = 0.35, Core = 0.5, Delay = 0.06, Lift = 0.3 },
		{ Asset = "Magic_CastCircle", Profile = "Scallop", From = 0, To = 360, Radius = 0.78, Grow = 0.1, Width = 0.35, Reveal = 0.08, Hold = 0.2, Fade = 0.3, Spin = 60, Core = 0.45, Lift = 0.15 },
	} },
}

-- BURSTS (VFX.burst) -----------------------------------------------------------------------------------------------
-- "Slam" (Heavy OverheadSlam radius 6, GroundBreaker radius 9, from the server at the hit): a dust-colored shockwave
-- ring over the slam radius + a ground-colored dust ring (Shared_LandDust)
CombatVFX.Slam = {
	Ring = { Asset = "Heavy_SlamRing", Profile = "Full", From = 0, To = 360, Radius = 0.25, Grow = 3, Width = 1.9, Reveal = 0, Hold = 0.05, Fade = 0.32, Core = 0.3 },
	Color = rgb(240, 175, 95),
	Lift = 0.2,
	Dust = "Shared_LandDust", -- a dust ring over the slam (ground colored, Land.DustColor), Emit x radius / DustRadius
	DustRadius = 8,
}
-- "Enemy" (enemy heavy attacks): a neon disc + spark
CombatVFX.Burst = { Asset = "Shared_BurstDisc", Grow = 0.22, Fade = 0.3, Transparency = 0.3, Spark = "Shared_HitSpark" }

-- ENEMY DEATH (extra dissolve on top of EnemyController's death fade, from workspace.Enemies "Dead") -----------------
CombatVFX.Death = { Asset = "Shared_DeathDissolve", Delay = 0.45, MaxSize = 14 }

-- ZONE STYLES (zone fighting styles 2026-10-14, docs/COMBAT_CONTRACTS.md section 9; the brief of each zone is the Look
-- line of Config/CombatStyles) --------------------------------------------------------------------------------------
-- Every weapon adds its zone's accent (ctx.Zone 1..12 = the held Tool's zone; other players' impacts: from the
-- element) on top of the rarity color + element tint. Plains (the base style) only sheds a few leaves. Per zone id:
--   Asset     the zone's particles: ReplicatedStorage.Assets.VFX.Zone_<Zone> (an invisible Part, emitters on its Center
--             attachment; Void's Implode emitter sits on the Part itself: a sphere shell converging inward). Every use
--             names its emitter counts (Emitters / Impact / Release tables: emitter name -> Emit count, halved by Low FX)
--   Shed      Zone_<Zone>_Shed, a ParticleEmitter cloned once on each weapon's TipAttachment and enabled from TrailOn to
--             TrailOff of every melee swing and dash strike, Common weapons too (they have no trail): the swing sheds
--             sand, leaves, embers... along its path (its Rate is cut by FxController with Low FX)
--   Arc       how the zone draws arcs, rings and streaks (Arcs modifiers; slashes, the spin ring, rings, landing rings):
--             Hard = straight segments (no curve), Spiral = the radius grows along a slash (x 1 +- Spiral), Wave = a
--             rolling ripple (fraction of the radius), Saw = every other point thinner (serrated ice), Stutter = s: the
--             arc is drawn in jerks, CoreColor = a dark core instead of the white one (not on colored effects), Jag =
--             studs: straight streaks (Shape "Line") become flickering bolts, WidthK = width multiplier, Claws = extra
--             thinner copies of every Crescent slash { RadiusAdd (studs), WidthK, Delay (s at x1) }
--   Release   Ranged / Magic (no trail): Asset's emitter counts at the muzzle at the release
--   Impact    Asset's emitter counts on every confirmed hit (x Impact.CategoryEmit, x ZoneCritK on crits), at most
--             ZoneMax per ZoneWindow s; ImpactArcs: arcs at the hit, Face = "Camera" (a ring facing the camera) or
--             "Radial" (Count lines from the hit in random directions across the view)
--   DiveColor the jump attack's dive streaks and wind ring (Dives)
--   Land      extra landing effects (VFX.land), same kinds and frame as LANDING (a "Burst" uses Emitters of its Asset)
--   Finisher  signature beats layered on the combo finishers (the animation's Style_<Zone>_Finisher), Jump on the jump
--             attacks (the hang: At <= 0.35; the dive is Dives, the landing Land): effects as in SWINGS (Kind "Arc" |
--             "Lines" | "Ground" | "Flash"; a Flash uses Emitters of its Asset; Color = Color3) timed by At = the
--             signature overlay's time (finisher 0..1 with the hit at 0.5; jump: dive 0.35, landing 0.6), converted with
--             the category's clip in ZoneTiming. LateOk = true: on a finisher whose wind-up is shorter than
--             ZoneTiming.LateWindup (Dagger, Ranged) the whole signature plays in the recovery, as the animation does.
--             JumpSkip = { [category] = true }: no jump signature (the animation's Gain 0)
CombatVFX.ZoneTiming = {
	-- the attack clips the signature overlays are timed on (Config/CombatAnimations, seconds at x1): finisher clip
	-- lengths (their Hit = the Combos finisher Impact), jump attack Dive markers and lengths (Hit = AirAttacks Impact)
	FinisherLength = { Sword = 0.95, Spear = 0.95, Heavy = 1.9, Dagger = 0.38, Gauntlet = 0.52, Ranged = 0.78, Magic = 0.98 },
	JumpDive = { Sword = 0.2, Spear = 0.22, Heavy = 0.3, Dagger = 0.17, Gauntlet = 0.2 },
	JumpLength = { Sword = 0.85, Spear = 0.95, Heavy = 1.3, Dagger = 0.62, Gauntlet = 0.75, Ranged = 0.8, Magic = 1.0 },
	LateWindup = 0.15, -- s (Animations LATE_WINDUP)
	LateSplit = 0.55, -- fraction of the recovery holding the late signature's wind-up part (Animations LATE_SPLIT)
}
local SAND, TOXIC = rgb(236, 202, 128), rgb(165, 240, 60)
local ICE, FROST = rgb(175, 228, 255), rgb(225, 244, 255)
local CURSE, CURSE_DARK = rgb(160, 85, 220), rgb(62, 30, 88)
local EMBER, CHAR, LAVA = rgb(255, 135, 40), rgb(48, 34, 28), rgb(255, 105, 20)
local HELLFIRE, HELL_DARK, HELL_CRACK = rgb(235, 45, 20), rgb(32, 8, 6), rgb(190, 20, 8)
local GOLD, SOUL, SOUL_DARK = rgb(255, 222, 120), rgb(120, 255, 205), rgb(22, 64, 58)
local WATER, FOAM = rgb(70, 165, 255), rgb(205, 238, 255)
local VOLT, VOID, VOID_DARK = rgb(255, 238, 110), rgb(155, 85, 255), rgb(22, 6, 40)
local NEON = Enum.Material.Neon
-- a small ring at the feet (stomps, ripples)
local function feetRing(asset: string, color: Color3, at: number, radius: number, grow: number, width: number, fade: number): { [string]: any }
	return { Kind = "Arc", At = at, Asset = asset, Anchor = "Feet", Height = 0.18, Profile = "Full", From = 0, To = 360, Radius = radius,
		Grow = grow, Width = width, Reveal = 0, Hold = 0.04, Fade = fade, Core = if asset == "Shared_DustRing" then 0 else 0.5, Color = color }
end
-- a burst of the zone's particles at an anchor of the attacker
local function puff(asset: string, at: number, anchor: string, emitters: { [string]: number }, height: number?, offset: { number }?): { [string]: any }
	return { Kind = "Flash", At = at, Asset = asset, Anchor = anchor, Height = height, Offset = offset, Emitters = emitters }
end

CombatVFX.Zones = {
	-- Squire: the base style; a few leaves and grass blades shed by the swing, leaves kicked up by a landing
	Plains = {
		Asset = "Zone_Plains", Shed = "Zone_Plains_Shed",
		Land = { { Kind = "Burst", Asset = "Zone_Plains", Lift = 0.3, Emitters = { Leaves = 8 } } },
	},
	-- Dune Dancer: sand swirls shed by the swing, spiral slashes, sand bursts; the finisher whirl spins a sand crescent
	-- around the feet (0.2 -> the hit) and kicks sand up as it completes; the corkscrew jump spins one around the body
	Desert = {
		Asset = "Zone_Desert", Shed = "Zone_Desert_Shed",
		Arc = { Spiral = 0.3 },
		Release = { Grains = 6, Swirl = 1 },
		Impact = { Grains = 10, Cloud = 2, Swirl = 1 },
		DiveColor = SAND,
		LateOk = true, JumpSkip = { Ranged = true },
		Finisher = {
			{ Kind = "Arc", At = 0.2, Asset = "Shared_WindRing", Anchor = "Feet", Height = 0.6, Profile = "Crescent", From = 0, To = 260, Radius = 2.4,
				Grow = 0.3, Width = 0.9, Reveal = 0.06, Hold = 0.08, Fade = 0.18, Core = 0.35, Spin = 1100, Color = SAND },
			puff("Zone_Desert", 0.44, "Feet", { Grains = 10, Cloud = 3, Swirl = 1 }, 0.3),
		},
		Jump = {
			{ Kind = "Arc", At = 0.05, Asset = "Shared_WindRing", Anchor = "Root", Height = -1.2, Profile = "Crescent", From = 0, To = 300, Radius = 1.8,
				Grow = 0.3, Width = 0.7, Reveal = 0.06, Hold = 0.1, Fade = 0.18, Core = 0.35, Spin = 900, Color = SAND },
			puff("Zone_Desert", 0.2, "Root", { Grains = 6, Swirl = 1 }),
		},
		Land = {
			{ Asset = "Shared_WindRing", Scale = true, Lift = 0.4, Profile = "Crescent", From = 0, To = 300, Radius = 0.3, Grow = 2.2, Width = 1.2,
				Reveal = 0.05, Hold = 0.05, Fade = 0.3, Core = 0.3, Spin = 500, Color = SAND },
			{ Kind = "Burst", Asset = "Zone_Desert", Lift = 0.3, Emitters = { Grains = 16, Cloud = 5, Swirl = 1 } },
		},
	},
	-- Feral: leaves shed by the swing, claw-like triple slashes, leaf bursts and toxic droplets; the pounce finisher kicks
	-- leaves at the take-off crouch and the landing crouch; the pounce jump lands on claw marks
	Jungle = {
		Asset = "Zone_Jungle", Shed = "Zone_Jungle_Shed",
		Arc = { WidthK = 0.55, Claws = { { RadiusAdd = -0.7, WidthK = 0.4, Delay = 0.012 }, { RadiusAdd = 0.7, WidthK = 0.4, Delay = 0.024 } } },
		Release = { Leaves = 5, Drops = 6 },
		Impact = { Leaves = 5, Drops = 8, Splat = 1 },
		DiveColor = TOXIC,
		Finisher = {
			puff("Zone_Jungle", 0.2, "Feet", { Leaves = 8 }, 0.3),
			puff("Zone_Jungle", 0.6, "Feet", { Leaves = 8, Drops = 6 }, 0.3),
		},
		Jump = { puff("Zone_Jungle", 0.12, "Root", { Leaves = 8 }) },
		Land = {
			{ Kind = "Line", Asset = "Dagger_StabStreak", Shape = "Line", Offset = { -0.65, 0, -0.6 }, Lift = 0.15, Yaw = 8, Start = 0, Length = 3.4, Width = 0.4,
				Profile = "Spike", Reveal = 0.04, Hold = 0.2, Fade = 0.25, Core = 0.3, Color = TOXIC },
			{ Kind = "Line", Asset = "Dagger_StabStreak", Shape = "Line", Offset = { 0, 0, -0.9 }, Lift = 0.15, Start = 0, Length = 3.8, Width = 0.45,
				Profile = "Spike", Reveal = 0.04, Hold = 0.2, Fade = 0.25, Core = 0.3, Color = TOXIC, Delay = 0.015 },
			{ Kind = "Line", Asset = "Dagger_StabStreak", Shape = "Line", Offset = { 0.65, 0, -0.6 }, Lift = 0.15, Yaw = -8, Start = 0, Length = 3.4, Width = 0.4,
				Profile = "Spike", Reveal = 0.04, Hold = 0.2, Fade = 0.25, Core = 0.3, Color = TOXIC, Delay = 0.03 },
			{ Kind = "Burst", Asset = "Zone_Jungle", Lift = 0.3, Emitters = { Leaves = 14, Drops = 10, Splat = 2 } },
		},
	},
	-- Glacier: frost glitter shed by the swing, serrated (icy) arcs, frost shards and crystals; the finisher's frozen
	-- pause gathers frost on the blade, an icy crack ring just before the crushing release, frost at the feet after it;
	-- the frozen hang of the jump, then a frost ring on the landing
	Tundra = {
		Asset = "Zone_Tundra", Shed = "Zone_Tundra_Shed",
		Arc = { Saw = 0.65 },
		Release = { Shards = 6, Crystals = 3 },
		Impact = { Shards = 10, Crystals = 3, Mist = 1 },
		DiveColor = ICE,
		Finisher = {
			puff("Zone_Tundra", 0.12, "Tip", { Crystals = 3, Mist = 1 }),
			puff("Zone_Tundra", 0.3, "Tip", { Crystals = 3 }),
			puff("Zone_Tundra", 0.43, "Tip", { Shards = 10, Crystals = 3 }),
			{ Kind = "Arc", At = 0.43, Asset = "Spear_PierceRing", Anchor = "Tip", Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 0.5, Grow = 2.6,
				Width = 0.4, Reveal = 0, Hold = 0.02, Fade = 0.14, Core = 0.5, Color = ICE },
			puff("Zone_Tundra", 0.62, "Feet", { Mist = 4, Shards = 6 }, 0.3),
		},
		Jump = {
			puff("Zone_Tundra", 0.08, "Root", { Crystals = 5, Mist = 3 }),
			{ Kind = "Arc", At = 0.08, Asset = "Shared_WindRing", Anchor = "Root", Height = -2.4, Profile = "Full", From = 0, To = 360, Radius = 1.3,
				Grow = 0.6, Width = 0.4, Reveal = 0, Hold = 0.15, Fade = 0.2, Core = 0.5, Color = ICE },
		},
		Land = {
			{ Asset = "Shared_LandRing", Scale = true, Lift = 0.3, Profile = "Full", From = 0, To = 360, Radius = 0.25, Grow = 3, Width = 1.0, Reveal = 0,
				Hold = 0.08, Fade = 0.4, Core = 0.5, Color = ICE },
			{ Asset = "Shared_DustRing", Scale = true, Delay = 0.02, Lift = 0.22, Profile = "Full", From = 0, To = 360, Radius = 0.5, Grow = 1.2, Width = 2.6,
				Reveal = 0, Hold = 0.25, Fade = 0.5, Core = 0, Color = FROST },
			{ Kind = "Burst", Asset = "Zone_Tundra", Lift = 0.3, Emitters = { Shards = 14, Crystals = 6, Mist = 5 } },
		},
	},
	-- Hexblade: curse smoke shed by the swing, purple-cored slashes, purple wisps, bubbles on impacts; the finisher
	-- twirl spins a curse ring at the hand, wisps fly off the blade at the hit, smoke on the late body turn; a smoke ring
	-- on landings
	Swamp = {
		Asset = "Zone_Swamp", Shed = "Zone_Swamp_Shed",
		Arc = { CoreColor = rgb(120, 50, 170) },
		Release = { Wisps = 6, Smoke = 1 },
		Impact = { Bubbles = 6, Smoke = 1, Wisps = 4 },
		DiveColor = CURSE,
		LateOk = true,
		Finisher = {
			{ Kind = "Arc", At = 0.1, Asset = "Shared_WindRing", Anchor = "Hand", Yaw = 90, Pitch = 90, Profile = "Crescent", From = 0, To = 280, Radius = 1.4,
				Grow = 0.1, Width = 0.45, Reveal = 0.05, Hold = 0.2, Fade = 0.15, Core = 0.3, Spin = -1600, Color = CURSE },
			puff("Zone_Swamp", 0.4, "Tip", { Wisps = 6, Smoke = 1 }),
			puff("Zone_Swamp", 0.72, "Root", { Smoke = 2, Wisps = 4 }),
		},
		Jump = { puff("Zone_Swamp", 0.15, "Root", { Smoke = 2, Wisps = 5 }) },
		Land = {
			{ Asset = "Shared_DustRing", Scale = true, Lift = 0.22, Profile = "Full", From = 0, To = 360, Radius = 0.25, Grow = 3, Width = 2.2, Reveal = 0,
				Hold = 0.05, Fade = 0.45, Core = 0, Color = CURSE_DARK },
			{ Kind = "Burst", Asset = "Zone_Swamp", Lift = 0.3, Emitters = { Bubbles = 10, Smoke = 4, Wisps = 8 } },
		},
	},
	-- Berserker: embers shed by the swing, lava sparks on impacts; the finisher's roar flares, both stomps crack a
	-- scorched ring at the feet, the overshoot throws lava; the explosive leap of the jump, a scorch mark with glowing
	-- lava cracks on the landing
	Volcano = {
		Asset = "Zone_Volcano", Shed = "Zone_Volcano_Shed",
		Release = { Lava = 5, Flame = 1, Embers = 4 },
		Impact = { Lava = 8, Embers = 5, Flame = 1 },
		DiveColor = EMBER,
		Finisher = {
			puff("Zone_Volcano", 0.12, "Root", { Embers = 6, Flame = 1 }, 1.2),
			puff("Zone_Volcano", 0.24, "Feet", { Embers = 5, Smoke = 2 }, 0.2),
			feetRing("Shared_DustRing", CHAR, 0.24, 0.6, 2.2, 1.0, 0.3),
			puff("Zone_Volcano", 0.45, "Feet", { Embers = 5, Smoke = 2 }, 0.2),
			feetRing("Shared_DustRing", CHAR, 0.45, 0.6, 2.2, 1.0, 0.3),
			puff("Zone_Volcano", 0.6, "Tip", { Lava = 8, Flame = 1 }),
		},
		Jump = { puff("Zone_Volcano", 0.1, "Feet", { Flame = 2, Embers = 8, Smoke = 3 }, 0.2) },
		Land = {
			{ Asset = "Shared_DustRing", Scale = true, Lift = 0.2, Profile = "Full", From = 0, To = 360, Radius = 0.3, Grow = 1.6, Width = 3, Reveal = 0,
				Hold = 0.35, Fade = 0.5, Core = 0, Color = CHAR },
			{ Kind = "Ground", Asset = "Shared_LandCrack", Offset = { 0, 0, -0.5 }, Cracks = 7, CrackLength = { 2.5, 5 }, CrackWidth = 0.32, Grow = 0.08,
				Hold = 0.35, Fade = 0.4, CrackColor = LAVA, CrackMaterial = NEON, Chunks = 0, ChunkSize = { 0.3, 0.5 }, ChunkUp = { 10, 14 }, ChunkOut = { 2, 4 },
				Gravity = 60, ChunkLife = 0.3 },
			{ Kind = "Burst", Asset = "Zone_Volcano", Lift = 0.3, Emitters = { Lava = 14, Embers = 10, Flame = 3, Smoke = 4 } },
		},
	},
	-- Demon: hellfire shed by the swing, red-black arcs (a dark core), flames and black smoke; the finisher's savage
	-- spin rings hellfire around the feet, the rip-down tears red-black cracks under the blade; the crater landing
	Hell = {
		Asset = "Zone_Hell", Shed = "Zone_Hell_Shed",
		Arc = { CoreColor = rgb(60, 6, 0) },
		Release = { Flames = 2, Sparks = 5 },
		Impact = { Flames = 2, Smoke = 2, Sparks = 6 },
		DiveColor = HELLFIRE,
		LateOk = true,
		Finisher = {
			{ Kind = "Arc", At = 0.06, Asset = "Shared_WindRing", Anchor = "Feet", Height = 0.5, Profile = "Crescent", From = 0, To = 300, Radius = 2.2,
				Grow = 0.3, Width = 0.9, Reveal = 0.05, Hold = 0.18, Fade = 0.2, Core = 0.3, Spin = -1300, Color = HELLFIRE },
			puff("Zone_Hell", 0.2, "Feet", { Flames = 4, Smoke = 2 }, 0.3),
			{ Kind = "Ground", At = 0.55, Asset = "Shared_LandCrack", Anchor = "Tip", Cracks = 5, CrackLength = { 2, 4 }, CrackWidth = 0.3, Grow = 0.08,
				Hold = 0.3, Fade = 0.35, CrackColor = HELL_CRACK, CrackMaterial = NEON, Chunks = 0, ChunkSize = { 0.3, 0.5 }, ChunkUp = { 10, 14 },
				ChunkOut = { 2, 4 }, Gravity = 60, ChunkLife = 0.3 },
			puff("Zone_Hell", 0.62, "Tip", { Smoke = 3, Sparks = 6 }),
		},
		Jump = { puff("Zone_Hell", 0.12, "Root", { Flames = 5, Smoke = 3 }) },
		Land = {
			{ Asset = "Shared_DustRing", Scale = true, Lift = 0.2, Profile = "Full", From = 0, To = 360, Radius = 0.3, Grow = 1.8, Width = 3, Reveal = 0,
				Hold = 0.3, Fade = 0.5, Core = 0, Color = HELL_DARK },
			{ Kind = "Ground", Asset = "Shared_LandCrack", Offset = { 0, 0, -0.5 }, Cracks = 8, CrackLength = { 3, 6 }, CrackWidth = 0.35, Grow = 0.08,
				Hold = 0.4, Fade = 0.4, CrackColor = HELL_CRACK, CrackMaterial = NEON, Chunks = 0, ChunkSize = { 0.3, 0.5 }, ChunkUp = { 10, 14 },
				ChunkOut = { 2, 4 }, Gravity = 60, ChunkLife = 0.3 },
			{ Kind = "Burst", Asset = "Zone_Hell", Lift = 0.3, Emitters = { Flames = 6, Smoke = 6, Sparks = 10 } },
			{ Kind = "Burst", Asset = "Zone_Hell", Lift = 1.5, Delay = 0.33, Emitters = { Smoke = 3 } },
		},
	},
	-- Seraph: light feathers shed by the swing, golden rays on impacts; the finisher's wings open in a burst of feathers
	-- and rays behind the back with a halo over the held beat; the jump's halo pause, a halo ring and a beam of light
	-- on the landing
	Heaven = {
		Asset = "Zone_Heaven", Shed = "Zone_Heaven_Shed",
		Release = { Rays = 6, Feathers = 3 },
		Impact = { Rays = 8, Feathers = 3, Glow = 1 },
		DiveColor = GOLD,
		Finisher = {
			puff("Zone_Heaven", 0.3, "Root", { Feathers = 10, Rays = 8, Glow = 1 }, 0.8, { 0, 0, 0.8 }),
			{ Kind = "Arc", At = 0.3, Asset = "Shared_WindRing", Anchor = "Root", Height = 2.6, Profile = "Full", From = 0, To = 360, Radius = 0.7, Grow = 0.15,
				Width = 0.22, Reveal = 0, Hold = 0.2, Fade = 0.2, Core = 0.6, Color = GOLD },
			puff("Zone_Heaven", 0.65, "Tip", { Feathers = 5 }),
		},
		Jump = {
			{ Kind = "Arc", At = 0.12, Asset = "Shared_WindRing", Anchor = "Root", Height = 2.5, Profile = "Full", From = 0, To = 360, Radius = 0.75, Grow = 0.1,
				Width = 0.25, Reveal = 0, Hold = 0.22, Fade = 0.2, Core = 0.6, Color = GOLD },
			puff("Zone_Heaven", 0.12, "Root", { Feathers = 6, Glow = 1 }),
		},
		Land = {
			{ Asset = "Shared_LandRing", Scale = true, Lift = 0.3, Profile = "Full", From = 0, To = 360, Radius = 0.3, Grow = 2.6, Width = 0.6, Reveal = 0,
				Hold = 0.1, Fade = 0.4, Core = 0.7, Color = GOLD },
			{ Asset = "Shared_LandRing", Scale = true, Delay = 0.06, Lift = 0.35, Profile = "Full", From = 0, To = 360, Radius = 0.15, Grow = 3.4, Width = 0.35,
				Reveal = 0, Hold = 0.05, Fade = 0.35, Core = 0.7, Color = GOLD },
			{ Kind = "Line", Asset = "Spear_PierceStreak", Shape = "Line", Pitch = 90, Start = -0.5, Length = 12, Width = 1.4, Reveal = 0.04, Hold = 0.08,
				Fade = 0.25, Grow = 0.1, Profile = "Full", Core = 0.6, Color = GOLD },
			{ Kind = "Burst", Asset = "Zone_Heaven", Lift = 0.3, Emitters = { Rays = 12, Feathers = 8, Glow = 1 } },
		},
	},
	-- Revenant: ghost wisps shed by the swing, arcs drawn in jerks (stutter), soul flames on impacts; the finisher leaves
	-- a soul puff where the body was at each snap; the drift of the jump, a soul burst on the landing
	Dead = {
		Asset = "Zone_Dead", Shed = "Zone_Dead_Shed",
		Arc = { Stutter = 0.035 },
		Release = { Souls = 2, Motes = 4 },
		Impact = { Souls = 2, Wisps = 2, Motes = 5 },
		DiveColor = SOUL,
		Finisher = {
			puff("Zone_Dead", 0.05, "Root", { Wisps = 2 }),
			puff("Zone_Dead", 0.31, "Root", { Wisps = 3, Motes = 4 }),
			puff("Zone_Dead", 0.41, "Root", { Wisps = 3, Motes = 4, Souls = 2 }),
			puff("Zone_Dead", 0.72, "Root", { Wisps = 3 }),
		},
		Jump = {
			puff("Zone_Dead", 0.15, "Root", { Wisps = 4, Motes = 4 }),
			puff("Zone_Dead", 0.33, "Root", { Souls = 3 }),
		},
		Land = {
			{ Asset = "Shared_DustRing", Scale = true, Lift = 0.22, Profile = "Full", From = 0, To = 360, Radius = 0.25, Grow = 3, Width = 2.4, Reveal = 0,
				Hold = 0.1, Fade = 0.45, Core = 0, Color = SOUL_DARK },
			{ Asset = "Shared_LandRing", Scale = true, Lift = 0.3, Profile = "Full", From = 0, To = 360, Radius = 0.25, Grow = 3, Width = 1.2, Reveal = 0,
				Hold = 0.06, Fade = 0.35, Core = 0.3, Color = SOUL },
			{ Kind = "Burst", Asset = "Zone_Dead", Lift = 0.3, Emitters = { Souls = 12, Wisps = 8, Motes = 14 } },
			{ Kind = "Burst", Asset = "Zone_Dead", Lift = 1.5, Delay = 0.25, Emitters = { Motes = 5 } },
		},
	},
	-- Tidecaller: bubbles shed by the swing, rippling water arcs, splashes on impacts; the finisher's rolling wave
	-- ripples the water at the feet (start, then the second ripples) and bubbles off the blade; a splash ring on landings
	Abyss = {
		Asset = "Zone_Abyss", Shed = "Zone_Abyss_Shed",
		Arc = { Wave = 0.1 },
		Release = { Bubbles = 6, Splash = 4 },
		Impact = { Splash = 10, Bubbles = 5, Spray = 1 },
		DiveColor = WATER,
		Finisher = {
			feetRing("Shared_WindRing", WATER, 0.1, 1.0, 2.0, 0.4, 0.3),
			puff("Zone_Abyss", 0.4, "Tip", { Bubbles = 5, Splash = 4 }),
			feetRing("Shared_WindRing", WATER, 0.65, 1.0, 2.0, 0.4, 0.3),
			feetRing("Shared_WindRing", FOAM, 0.8, 0.8, 1.8, 0.3, 0.3),
		},
		Jump = { puff("Zone_Abyss", 0.15, "Root", { Splash = 8, Bubbles = 4 }) },
		Land = {
			{ Asset = "Shared_LandRing", Scale = true, Lift = 0.3, Profile = "Full", From = 0, To = 360, Radius = 0.25, Grow = 3, Width = 1.2, Reveal = 0,
				Hold = 0.05, Fade = 0.35, Core = 0.6, Color = WATER },
			{ Asset = "Shared_WindRing", Scale = true, Delay = 0.08, Lift = 0.25, Profile = "Full", From = 0, To = 360, Radius = 0.2, Grow = 3.2, Width = 0.5,
				Reveal = 0, Hold = 0.04, Fade = 0.35, Core = 0.7, Color = FOAM },
			{ Kind = "Burst", Asset = "Zone_Abyss", Lift = 0.3, Emitters = { Splash = 18, Bubbles = 8, Spray = 4 } },
		},
	},
	-- Automaton: electric sparks shed by the swing, hard-edged (polygonal) arcs and rings, streaks become bolts, bolts on
	-- impacts; the finisher's ratchet clicks tick sparks and a hexagonal click ring at the hand, the piston release
	-- flashes; the locked jump, a polygonal shockwave and bolts along the ground on the landing
	Mechanical = {
		Asset = "Zone_Mechanical", Shed = "Zone_Mechanical_Shed",
		Arc = { Hard = true, Jag = 0.35 },
		Release = { Sparks = 8, Flash = 1 },
		Impact = { Sparks = 12, Flash = 1 },
		ImpactArcs = {
			{ Face = "Radial", Count = 2, Asset = "Dagger_StabStreak", Shape = "Line", Start = 0.3, Length = 2.6, Width = 0.3, Profile = "Full", Reveal = 0.02,
				Hold = 0.04, Fade = 0.1, Grow = 0, Core = 0.6, Color = VOLT },
		},
		DiveColor = VOLT,
		Finisher = {
			puff("Zone_Mechanical", 0.12, "Hand", { Sparks = 3 }),
			{ Kind = "Arc", At = 0.12, Asset = "Spear_PierceRing", Anchor = "Hand", Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 0.35, Grow = 1.5,
				Width = 0.18, Reveal = 0, Hold = 0.02, Fade = 0.08, Core = 0.6, Color = VOLT },
			puff("Zone_Mechanical", 0.24, "Hand", { Sparks = 3 }),
			{ Kind = "Arc", At = 0.24, Asset = "Spear_PierceRing", Anchor = "Hand", Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 0.35, Grow = 1.5,
				Width = 0.18, Reveal = 0, Hold = 0.02, Fade = 0.08, Core = 0.6, Color = VOLT },
			puff("Zone_Mechanical", 0.36, "Hand", { Sparks = 3 }),
			{ Kind = "Arc", At = 0.36, Asset = "Spear_PierceRing", Anchor = "Hand", Pitch = 90, Profile = "Full", From = 0, To = 360, Radius = 0.35, Grow = 1.5,
				Width = 0.18, Reveal = 0, Hold = 0.02, Fade = 0.08, Core = 0.6, Color = VOLT },
			puff("Zone_Mechanical", 0.5, "Tip", { Sparks = 8, Flash = 1 }),
			puff("Zone_Mechanical", 0.62, "Hand", { Sparks = 2 }),
			puff("Zone_Mechanical", 0.8, "Hand", { Sparks = 2 }),
		},
		Jump = { puff("Zone_Mechanical", 0.04, "Root", { Sparks = 6, Flash = 1 }) },
		Land = {
			{ Kind = "Line", Asset = "Spear_PierceStreak", Shape = "Line", Lift = 0.3, Yaw = 45, Start = 0.8, Length = 4.5, Width = 0.5, Reveal = 0.03,
				Hold = 0.06, Fade = 0.15, Grow = 0, Profile = "Full", Core = 0.6, Color = VOLT },
			{ Kind = "Line", Asset = "Spear_PierceStreak", Shape = "Line", Lift = 0.3, Yaw = 135, Start = 0.8, Length = 4.5, Width = 0.5, Reveal = 0.03,
				Hold = 0.06, Fade = 0.15, Grow = 0, Profile = "Full", Core = 0.6, Color = VOLT },
			{ Kind = "Line", Asset = "Spear_PierceStreak", Shape = "Line", Lift = 0.3, Yaw = -135, Start = 0.8, Length = 4.5, Width = 0.5, Reveal = 0.03,
				Hold = 0.06, Fade = 0.15, Grow = 0, Profile = "Full", Core = 0.6, Color = VOLT },
			{ Kind = "Line", Asset = "Spear_PierceStreak", Shape = "Line", Lift = 0.3, Yaw = -45, Start = 0.8, Length = 4.5, Width = 0.5, Reveal = 0.03,
				Hold = 0.06, Fade = 0.15, Grow = 0, Profile = "Full", Core = 0.6, Color = VOLT },
			{ Kind = "Burst", Asset = "Zone_Mechanical", Lift = 0.3, Emitters = { Sparks = 18, Flash = 1 } },
			{ Kind = "Burst", Asset = "Zone_Mechanical", Lift = 1.2, Delay = 0.2, Emitters = { Sparks = 3 } },
			{ Kind = "Burst", Asset = "Zone_Mechanical", Lift = 1.2, Delay = 0.35, Emitters = { Sparks = 3 } },
		},
	},
	-- Voidwalker: stars shed by the swing, arcs with a dark distorted core, stars and imploding gravity rings on impacts;
	-- the finisher's float and slow spin (a slow purple crescent around the body), the snap implodes a gravity ring, the
	-- slam leaves a black hole at the feet; the weightless flip of the jump, a black-hole ring on the landing
	Void = {
		Asset = "Zone_Void", Shed = "Zone_Void_Shed",
		Arc = { CoreColor = rgb(25, 5, 45) },
		Release = { Stars = 6, Distort = 1 },
		Impact = { Stars = 6, Distort = 1, Implode = 6 },
		ImpactArcs = {
			{ Face = "Camera", Asset = "Spear_PierceRing", Profile = "Full", From = 0, To = 360, Radius = 1.6, Grow = -0.75, Width = 0.35, Reveal = 0,
				Hold = 0.02, Fade = 0.14, Core = 0.4, Color = VOID },
		},
		DiveColor = VOID,
		LateOk = true, JumpSkip = { Ranged = true },
		Finisher = {
			puff("Zone_Void", 0.05, "Root", { Stars = 6 }),
			{ Kind = "Arc", At = 0.05, Asset = "Shared_WindRing", Anchor = "Root", Height = -1.6, Profile = "Crescent", From = 0, To = 300, Radius = 2.0,
				Grow = 0.1, Width = 0.6, Reveal = 0.12, Hold = 0.18, Fade = 0.2, Core = 0.3, Spin = 500, Color = VOID },
			{ Kind = "Arc", At = 0.4, Asset = "Shared_WindRing", Anchor = "Root", Profile = "Full", From = 0, To = 360, Radius = 2.4, Grow = -0.8, Width = 0.5,
				Reveal = 0, Hold = 0.02, Fade = 0.12, Core = 0.4, Color = VOID },
			puff("Zone_Void", 0.4, "Tip", { Implode = 8, Distort = 1 }),
			feetRing("Shared_DustRing", VOID_DARK, 0.6, 2.2, -0.7, 1.4, 0.25),
		},
		Jump = {
			{ Kind = "Arc", At = 0.02, Asset = "Shared_WindRing", Anchor = "Root", Roll = 90, Profile = "Full", From = 0, To = 360, Radius = 1.6, Grow = 0.2,
				Width = 0.35, Reveal = 0, Hold = 0.18, Fade = 0.2, Core = 0.4, Color = VOID },
			puff("Zone_Void", 0.05, "Root", { Stars = 8, Distort = 1 }),
		},
		Land = {
			{ Asset = "Shared_DustRing", Scale = true, Lift = 0.25, Profile = "Full", From = 0, To = 360, Radius = 1.0, Grow = -0.8, Width = 2.2, Reveal = 0,
				Hold = 0.06, Fade = 0.3, Core = 0, Color = VOID_DARK },
			{ Asset = "Shared_LandRing", Scale = true, Delay = 0.12, Lift = 0.3, Profile = "Full", From = 0, To = 360, Radius = 0.15, Grow = 3.5, Width = 0.7,
				Reveal = 0, Hold = 0.04, Fade = 0.3, Core = 0.4, Color = VOID },
			{ Kind = "Burst", Asset = "Zone_Void", Lift = 0.3, Emitters = { Stars = 12, Distort = 2, Implode = 12 } },
		},
	},
}

return CombatVFX
