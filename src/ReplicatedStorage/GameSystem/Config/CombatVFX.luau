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
	Shared_RollDust = { Dust = 5, Pebbles = 4 },
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

-- SWINGS per category and combo step (Config/Combat Combos). TrailOn = fraction of the time to the hit
-- (Combos[category][step].Impact / speed) when the weapon trail starts (= the end of the wind-up of the clip);
-- TrailOff = seconds after the hit (at speed x1, divided by the speed) when it stops; no TrailOn = no trail.
-- Effects: each timed on Hit (0 = the attack call, 1 = Combos Impact (default), 2 = Combos Hits[1]) + Delay (s at x1),
-- Kind = "Arc" (default, see ARCS) | "Lines" (speed lines: Count, Spread { x, y }, Start, Length, Width, Extend, Hold,
-- Fade, Jitter) | "Ground" (cracks + chunks) | "Flash" (muzzle flash, Counts per weapon type) | "Charge" (Magic orb);
-- Palette = "Element" (the weapon element's color) or Color = Color3 instead of the rarity palette.
-- A melee category without an entry gets Default (trail only).
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
		-- PiercingLunge finisher: a longer, brighter streak, more lines, two pierce rings along the reach (Line 14 studs)
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
		-- WideSmash finisher: a full flat sweep from far right across the front to the left, big and bright
		{ TrailOn = 0.75, TrailOff = 0.18, Effects = {
			{ Asset = "Heavy_SmashArc", Delay = -0.06, Radius = 5.8, Width = 2.8, Height = 0.4, From = 150, To = -140, Roll = -6, Reveal = 0.1, Hold = 0.07, Fade = 0.26, Core = 0.4, Profile = "Crescent" },
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
	},
	Magic = {
		-- Cast: two counter-spinning circles under the caster from the cast start to the release, the charge orb at the
		-- staff head until the release; the bolt and the area burst come with the server's Burst (Casts)
		{ Effects = {
			{ Hit = 0, Asset = "Magic_CastCircle", Anchor = "Feet", Height = 0.12, Profile = "Scallop", From = 0, To = 360, Radius = 2.6, Grow = 0, Width = 0.32, Reveal = 0.14, Hold = 0.05, HoldToHit = true, Fade = 0.25, Spin = 80, Palette = "Element", Core = 0.45 },
			{ Hit = 0, Asset = "Magic_CastCircle", Anchor = "Feet", Height = 0.14, Profile = "Scallop", From = 0, To = 360, Radius = 1.6, Grow = 0, Width = 0.26, Reveal = 0.1, Hold = 0.05, HoldToHit = true, Fade = 0.25, Spin = -140, Palette = "Element", Core = 0.45 },
			{ Kind = "Charge", Hit = 0, Asset = "Magic_ChargeOrb", Size = { 0.3, 1.0 }, Pulse = 0.12, PulseSpeed = 28, Transparency = 0.05, Linger = 0.35, Continuous = { Motes = true, Glow = true } },
		} },
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
CombatVFX.Shot = { MinTime = 0.05, TrailLife = 0.2 }
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
}

-- BURSTS (VFX.burst) -----------------------------------------------------------------------------------------------
-- "Slam" (Heavy OverheadSlam, from the server at the hit): a dust-colored shockwave ring over the slam radius
CombatVFX.Slam = {
	Ring = { Asset = "Heavy_SlamRing", Profile = "Full", From = 0, To = 360, Radius = 0.25, Grow = 3, Width = 1.9, Reveal = 0, Hold = 0.05, Fade = 0.32, Core = 0.3 },
	Color = rgb(240, 175, 95),
	Lift = 0.2,
}
-- "Enemy" (enemy heavy attacks): a neon disc + spark
CombatVFX.Burst = { Asset = "Shared_BurstDisc", Grow = 0.22, Fade = 0.3, Transparency = 0.3, Spark = "Shared_HitSpark" }

-- ENEMY DEATH (extra dissolve on top of EnemyController's death fade, from workspace.Enemies "Dead") -----------------
CombatVFX.Death = { Asset = "Shared_DeathDissolve", Delay = 0.45, MaxSize = 14 }

return CombatVFX
