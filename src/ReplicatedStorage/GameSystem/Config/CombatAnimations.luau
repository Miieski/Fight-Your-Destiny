--!strict
-- Player combat animation clips (docs/weapons_combat_brief.txt 4B, contract in docs/COMBAT_CONTRACTS.md). DATA ONLY.
-- OWNER: the Animation sub-agent. Played on every client by GameClient/Controllers/Combat/Animations (procedural
-- keyframes written to the R15 joints after the default Animator, docs/NIGHT_LOG.md option 2).
--
-- Clip names: <Category>_Idle, <Category>_Run, <Category>_Equip, <Category>_Attack1..N, <Category>_Block,
-- <Category>_BlockHit, Shared_Roll, Shared_Hit, Shared_Death, Shared_Spawn.
-- clip = {
--   Length    seconds at speed x1
--   Loop      true for Idle / Run
--   Legs      "Upper": never touches the root and the legs (the default walk / run / jump legs stay)
--             "Stand": root + legs only while standing still on the ground (else the default legs)
--             "Own":   root + legs always (roll, death, spawn, spin finisher)
--   Additive  true: the values are added on top of everything (hit reactions; raw rotations only)
--   Hold      true: the last pose stays until the clip is stopped (Block, Death)
--   FadeIn / FadeOut  seconds
--   Markers   { Hit = seconds }: attack clips; the engine stretches the wind-up so Hit lands exactly at
--             Config/Combat Combos[category][step].Impact / speed, the rest plays at speed
--   Poses     key poses in time order: { time, ease?, Channel = {...}, ... } (helper P below)
-- }
-- Channels (a channel missing from a pose is interpolated between the poses that have it; missing from the
-- whole clip = rest pose):
--   Rotations (degrees, CFrame.fromEulerAnglesYXZ(x, y, z) in the parent's frame: x right, y up, z back):
--     Root (LowerTorso: whole body) Waist Neck RShoulder RElbow RWrist LShoulder LElbow LWrist
--     RHip RKnee RAnkle LHip LKnee LAnkle (raw legs: only in clips without feet goals)
--     limbs hanging down: +x = forward / up; torso, head: -x = lean forward; +y = turn left;
--     right arm +z = out to the side, left arm -z = out to the side.
--   RootP = { x, y, z } studs: body offset (y < 0 crouches), scaled by HipHeight / 2.
--   RFoot / LFoot = { x, y, z, yaw }: feet goals (two-bone IK, any body proportions) = offset in studs from the
--     rest ankle in the frame turned by the Root yaw (y = lift, -z = forward), yaw in degrees (toes out).
--     Used whenever the clip has no raw leg rotation; no goal = feet planted at the rest spot.
--   RHand / LHand = { azimuth, height, radius }: wrist target (two-bone IK) around the UpperTorso's vertical
--     axis: azimuth degrees (0 = forward, +90 = left, -90 = right), height studs above the shoulder joint,
--     radius studs from the axis (scaled by the arm length). Replaces RShoulder / RElbow / RWrist (L...).
--   RBlade / LBlade = { azimuth, elevation }: direction of the weapon held in that hand (Handle Base -> Tip
--     attachments); the forearm twists and the wrist bends to aim it. el > 90 goes over the top (pointing back).
--   Hands and blades are written relative to the character's facing: P() turns blade directions by the inverse
--     of the pose's torso rotation (Root * Waist) and hand azimuths by its yaw, so the engine gets UpperTorso-frame
--     values (hand heights stay torso-relative). A pose with Torso = true keeps the torso frame (the arm turns
--     with the body: spins).
--   RPole / LPole = { x, y, z }: where the elbow points (UpperTorso frame), default out / down / back.
--   RFace = { azimuth, elevation }: direction of the held weapon's face axis, i.e. its roll around RBlade (bows: the
--     arrow side, heavy heads: the striking side, crossbows: the top, guns: the side, gauntlets: the back of the hand).
--   LGrip = { along, weight }: the left hand on the weapon, `along` studs from the right hand's grip along the weapon's
--     axis (negative: toward the pommel); weight 0..1 blends from LHand to that grip (two-handed weapons).
-- More clip fields: AimPitch = true (Ranged / Magic attacks: the torso follows the attack's aim pitch), Markers.Hit2
-- (Dagger DoubleSlash's second impact, Config/Combat Combos Hits; for reference). Styles (end of file): per WeaponId, a
-- clip prefix tried before the category's (RangedCrossbow_*, RangedGun_*).
-- ease (into this pose): "s" smooth (default), "l" linear, "i" accelerate, "o" decelerate, "O" strong decelerate.
local CombatAnimations = {}

type Pose = { [any]: any }

local function with(base: Pose, changes: Pose?): Pose
	local out = {}
	for k, v in pairs(base) do
		out[k] = v
	end
	if changes then
		for k, v in pairs(changes) do
			out[k] = v
		end
	end
	return out
end

local function wrap180(a: number): number
	return (a + 180) % 360 - 180
end

local function euler(v: { number }?): CFrame
	return if v then CFrame.fromEulerAnglesYXZ(math.rad(v[1]), math.rad(v[2]), math.rad(v[3])) else CFrame.identity
end

-- Blade { az, el } from the character's facing into the torso frame; of the two equivalent answers (az, el) and
-- (az + 180, 180 - el) it keeps the one closest to the written azimuth, so "over the top" keys stay continuous.
local function bladeToTorso(v: { number }, torso: CFrame): { number }
	local az, el = math.rad(v[1]), math.rad(v[2])
	local dir = Vector3.new(-math.cos(el) * math.sin(az), math.sin(el), -math.cos(el) * math.cos(az))
	local d = torso:VectorToObjectSpace(dir)
	local az2, el2 = math.deg(math.atan2(-d.X, -d.Z)), math.deg(math.asin(math.clamp(d.Y, -1, 1)))
	local twist = math.deg(math.atan2(-torso.LookVector.X, -torso.LookVector.Z))
	local want = v[1] - twist
	local a = wrap180(az2 - want) + want
	local b = wrap180(az2 + 180 - want) + want
	if math.abs(b - want) < math.abs(a - want) then
		return { b, 180 - el2 }
	end
	return { a, el2 }
end

-- A key pose: time, ease, a base pose and the channels that change. Hands / blades go from the character's
-- facing to the torso frame (unless Torso = true).
local function P(t: number, ease: string?, base: Pose, changes: Pose?): Pose
	local out = with(base, changes)
	out[1] = t
	out[2] = ease
	if not out.Torso and (out.Root or out.Waist) then
		local torso = euler(out.Root) * euler(out.Waist)
		local twist = (if out.Root then out.Root[2] else 0) + (if out.Waist then out.Waist[2] else 0)
		for _, key in ipairs({ "RHand", "LHand" }) do
			local v = out[key]
			if v then
				local copy = table.clone(v)
				copy[1] = wrap180(v[1] - twist)
				out[key] = copy
			end
		end
		for _, key in ipairs({ "RBlade", "LBlade", "RFace" }) do
			local v = out[key]
			if v then
				out[key] = bladeToTorso(v, torso)
			end
		end
	end
	out.Torso = nil
	return out
end

-- Rest poses with explicit zero keys (a channel needs a key at both ends of a clip to ease back).
local REST: Pose = {
	Root = { 0, 0, 0 }, RootP = { 0, 0, 0 }, Waist = { 0, 0, 0 }, Neck = { 0, 0, 0 },
	RShoulder = { 0, 0, 0 }, RElbow = { 0, 0, 0 }, RWrist = { 0, 0, 0 },
	LShoulder = { 0, 0, 0 }, LElbow = { 0, 0, 0 }, LWrist = { 0, 0, 0 },
}
local REST_LEGS: Pose = with(REST, { -- raw legs (no feet IK)
	RHip = { 0, 0, 0 }, RKnee = { 0, 0, 0 }, RAnkle = { 0, 0, 0 }, LHip = { 0, 0, 0 }, LKnee = { 0, 0, 0 }, LAnkle = { 0, 0, 0 },
})
local REST_FEET: Pose = with(REST, { RFoot = { 0, 0, 0, 0 }, LFoot = { 0, 0, 0, 0 } }) -- feet IK goals at rest

-- ------------------------------------------------------------------------------------------------
-- SWORD: one-handed, fluid and balanced (4-hit combo, 1.0 s interval at speed x1)
-- ------------------------------------------------------------------------------------------------
-- Guard stance: right side forward, knees bent, sword out on the right pointing forward-up (it reads from the
-- camera behind the player), left hand up in front.
local SWORD_GUARD: Pose = {
	Root = { 0, 15, 0 }, RootP = { 0, -0.22, 0 },
	Waist = { -6, -5, 0 }, Neck = { 4, -10, 0 },
	RHand = { -62, -0.6, 1.0 }, RBlade = { -35, 30 },
	LHand = { 30, -0.45, 0.8 },
	RFoot = { 0.12, 0, -0.5, -12 }, LFoot = { -0.12, 0, 0.45, 25 },
}
local SWORD_GUARD_IN: Pose = with(SWORD_GUARD, {
	RootP = { 0, -0.26, 0 }, Waist = { -8, -5, 0 },
	RHand = { -62, -0.65, 1.0 }, RBlade = { -35, 26 }, LHand = { 30, -0.5, 0.8 },
})
local SWORD_SPIN_END: Pose = with(SWORD_GUARD, { Root = { 0, 378, 0 } }) -- the guard after a full turn

local Clips: { [string]: { [string]: any } } = {}

Clips.Sword_Idle = {
	Length = 2.4, Loop = true, Legs = "Stand", FadeIn = 0.2, FadeOut = 0.2,
	Poses = {
		P(0, nil, SWORD_GUARD),
		P(1.2, nil, SWORD_GUARD_IN),
		P(2.4, nil, SWORD_GUARD),
	},
}

-- Upper body over the default run legs: torso forward, sword trailing behind on the right.
local SWORD_RUN: Pose = {
	Waist = { -14, 0, 0 }, Neck = { 10, 0, 0 },
	RHand = { -62, -0.75, 0.75 }, RBlade = { -160, 12 },
	LHand = { 38, -0.55, 0.75 },
}
Clips.Sword_Run = {
	Length = 0.7, Loop = true, Legs = "Upper", FadeIn = 0.15, FadeOut = 0.15,
	Poses = {
		P(0, nil, SWORD_RUN),
		P(0.35, nil, SWORD_RUN, { Waist = { -16, 0, 0 }, RHand = { -62, -0.8, 0.75 }, LHand = { 45, -0.62, 0.7 } }),
		P(0.7, nil, SWORD_RUN),
	},
}

-- Draw: from the left hip, up through a high flourish, into the guard.
Clips.Sword_Equip = {
	Length = 0.5, Legs = "Stand", FadeIn = 0.06, FadeOut = 0.15,
	Poses = {
		P(0, nil, SWORD_GUARD, { Root = { 0, 10, 0 }, Waist = { -4, 22, 0 }, Neck = { 4, -25, 0 },
			RHand = { 60, -1.0, 0.55 }, RBlade = { 150, -20 }, LHand = { 30, -0.8, 0.5 } }),
		P(0.16, "o", SWORD_GUARD, { Root = { 0, 5, 0 }, Waist = { -2, -18, 0 }, Neck = { 2, 10, 0 },
			RHand = { -40, 0.75, 0.9 }, RBlade = { -30, 75 }, LHand = { 40, -0.4, 0.8 } }),
		P(0.3, "s", SWORD_GUARD, { Waist = { -8, -10, 0 }, RHand = { -55, -0.4, 1.05 }, RBlade = { -30, 45 } }),
		P(0.5, "s", SWORD_GUARD),
	},
}

-- Attack 1, RightSlash: cocked behind the right shoulder -> diagonal down across the front -> low left.
Clips.Sword_Attack1 = {
	Length = 0.8, Legs = "Stand", FadeIn = 0.05, FadeOut = 0.15, Markers = { Hit = 0.16 },
	Poses = {
		P(0, nil, SWORD_GUARD),
		P(0.08, "o", SWORD_GUARD, { Root = { 0, -20, 0 }, RootP = { 0, -0.3, 0 }, Waist = { -2, -40, 0 }, Neck = { 6, 45, 0 },
			RHand = { -110, 0.6, 0.85 }, RBlade = { -140, 55 }, LHand = { 15, -0.1, 1.0 },
			RFoot = { 0.15, 0, -0.55, -10 }, LFoot = { -0.15, 0, 0.45, 25 } }),
		P(0.16, "i", SWORD_GUARD, { Root = { 0, 10, 0 }, RootP = { 0, -0.34, -0.05 }, Waist = { -8, 12, 0 }, Neck = { 6, -18, 0 },
			RHand = { -12, -0.1, 1.5 }, RBlade = { 40, -5 }, LHand = { 70, -0.45, 0.6 },
			RFoot = { 0.15, 0, -0.75, -10 }, LFoot = { -0.15, 0, 0.45, 25 } }),
		P(0.27, "O", SWORD_GUARD, { Root = { 0, 25, 0 }, RootP = { 0, -0.36, -0.05 }, Waist = { -10, 35, 0 }, Neck = { 8, -45, 0 },
			RHand = { 75, -0.2, 1.45 }, RBlade = { 110, -5 }, LHand = { 120, -0.4, 0.55 },
			RFoot = { 0.15, 0, -0.75, -10 }, LFoot = { -0.15, 0, 0.45, 25 } }),
		P(0.45, "s", SWORD_GUARD, { Root = { 0, 25, 0 }, RootP = { 0, -0.34, -0.05 }, Waist = { -9, 33, 0 }, Neck = { 8, -43, 0 },
			RHand = { 72, -0.25, 1.4 }, RBlade = { 105, -2 }, LHand = { 115, -0.4, 0.55 },
			RFoot = { 0.15, 0, -0.75, -10 }, LFoot = { -0.15, 0, 0.45, 25 } }),
		P(0.8, "s", SWORD_GUARD),
	},
}

-- Attack 2, LeftSlash: backhand from over the left shoulder, flat across the front, out to the right.
Clips.Sword_Attack2 = {
	Length = 0.8, Legs = "Stand", FadeIn = 0.05, FadeOut = 0.15, Markers = { Hit = 0.16 },
	Poses = {
		P(0, nil, SWORD_GUARD),
		P(0.08, "o", SWORD_GUARD, { Root = { 0, 28, 0 }, RootP = { 0, -0.28, 0 }, Waist = { -4, 35, 0 }, Neck = { 6, -55, 0 },
			RHand = { 75, 0.45, 0.7 }, RBlade = { 150, 50 }, LHand = { 40, -0.7, 0.5 } }),
		P(0.16, "i", SWORD_GUARD, { Root = { 0, 0, 0 }, RootP = { 0, -0.32, -0.05 }, Waist = { -6, -12, 0 }, Neck = { 4, 10, 0 },
			RHand = { 0, -0.05, 1.5 }, RBlade = { -45, 0 }, LHand = { 55, -0.4, 0.9 },
			RFoot = { 0.2, 0, -0.75, -10 } }),
		P(0.27, "O", SWORD_GUARD, { Root = { 0, -15, 0 }, RootP = { 0, -0.34, -0.05 }, Waist = { -8, -35, 0 }, Neck = { 6, 45, 0 },
			RHand = { -95, -0.1, 1.45 }, RBlade = { -115, 5 }, LHand = { 45, -0.3, 0.9 },
			RFoot = { 0.2, 0, -0.75, -10 } }),
		P(0.45, "s", SWORD_GUARD, { Root = { 0, -13, 0 }, RootP = { 0, -0.32, -0.05 }, Waist = { -8, -33, 0 }, Neck = { 6, 43, 0 },
			RHand = { -92, -0.15, 1.4 }, RBlade = { -112, 8 }, LHand = { 45, -0.32, 0.88 },
			RFoot = { 0.2, 0, -0.75, -10 } }),
		P(0.8, "s", SWORD_GUARD),
	},
}

-- Attack 3, RisingSlash: low crouch, the blade rises through the front and ends overhead on the toes.
Clips.Sword_Attack3 = {
	Length = 0.85, Legs = "Stand", FadeIn = 0.05, FadeOut = 0.15, Markers = { Hit = 0.18 },
	Poses = {
		P(0, nil, SWORD_GUARD),
		P(0.09, "o", SWORD_GUARD, { Root = { 0, -10, 0 }, RootP = { 0, -0.45, 0.05 }, Waist = { -24, -12, 0 }, Neck = { 20, 10, 0 },
			RHand = { -30, -0.85, 0.95 }, RBlade = { -20, -5 }, LHand = { 30, -0.3, 1.0 },
			RFoot = { 0.25, 0, -0.6, -15 }, LFoot = { -0.2, 0, 0.5, 25 } }),
		P(0.18, "i", SWORD_GUARD, { Root = { 0, 4, 0 }, RootP = { 0, -0.2, -0.08 }, Waist = { -4, 0, 0 }, Neck = { 6, 0, 0 },
			RHand = { -10, -0.05, 1.35 }, RBlade = { -5, 55 }, LHand = { 70, -0.7, 0.5 },
			RFoot = { 0.25, 0, -0.65, -15 }, LFoot = { -0.2, 0, 0.5, 25 } }),
		P(0.29, "O", SWORD_GUARD, { Root = { 0, 8, 0 }, RootP = { 0, 0.08, -0.08 }, Waist = { 8, 4, 0 }, Neck = { -10, 0, 0 },
			RHand = { -5, 1.05, 0.7 }, RBlade = { 0, 130 }, LHand = { 100, -0.6, 0.5 },
			RFoot = { 0.25, 0, -0.65, -15 }, LFoot = { -0.2, 0, 0.5, 25 } }),
		P(0.5, "s", SWORD_GUARD, { Root = { 0, 8, 0 }, RootP = { 0, -0.02, -0.05 }, Waist = { 6, 4, 0 }, Neck = { -8, 0, 0 },
			RHand = { -8, 0.95, 0.75 }, RBlade = { -2, 120 }, LHand = { 95, -0.6, 0.5 },
			RFoot = { 0.25, 0, -0.65, -15 }, LFoot = { -0.2, 0, 0.5, 25 } }),
		P(0.85, "s", SWORD_GUARD),
	},
}

-- Attack 4, SpinSlash (finisher): deep twist, a full jumping turn with the blade straight out, heavy landing.
-- The spin poses keep the arm in the torso frame (Torso = true) so the blade turns with the body.
Clips.Sword_Attack4 = {
	Length = 0.95, Legs = "Own", FadeIn = 0.05, FadeOut = 0.15, Markers = { Hit = 0.22 },
	Poses = {
		P(0, nil, SWORD_GUARD),
		P(0.1, "o", SWORD_GUARD, { Root = { 0, -50, 0 }, RootP = { 0, -0.45, 0 }, Waist = { -10, -25, 0 }, Neck = { 8, 55, 0 },
			RHand = { -120, -0.1, 1.2 }, RBlade = { -150, 0 }, LHand = { 20, -0.1, 1.0 },
			RFoot = { 0.3, 0, -0.5, -20 }, LFoot = { -0.25, 0, 0.45, 30 } }),
		P(0.13, "l", SWORD_GUARD, { Torso = true, Root = { 0, -35, 0 }, RootP = { 0, -0.35, 0 }, Waist = { -8, 0, 0 }, Neck = { 0, 0, 0 },
			RHand = { -90, 0.0, 1.45 }, RBlade = { -95, 3 }, LHand = { 80, -0.3, 0.6 },
			RFoot = { 0.3, 0, -0.5, -20 }, LFoot = { -0.25, 0, 0.45, 30 } }),
		P(0.25, "l", SWORD_GUARD, { Torso = true, Root = { 0, 130, 0 }, RootP = { 0, 0.6, 0 }, Waist = { -8, 0, 0 }, Neck = { 0, 0, 0 },
			RHand = { -90, 0.02, 1.45 }, RBlade = { -92, 4 }, LHand = { 85, -0.3, 0.55 },
			RFoot = { 0.25, 0.7, -0.3, -20 }, LFoot = { -0.25, 0.65, 0.3, 30 } }),
		P(0.38, "l", SWORD_GUARD, { Torso = true, Root = { 0, 290, 0 }, RootP = { 0, 0.0, 0 }, Waist = { -10, 4, 0 }, Neck = { 2, -4, 0 },
			RHand = { -95, -0.1, 1.42 }, RBlade = { -100, 0 }, LHand = { 75, -0.25, 0.75 },
			RFoot = { 0.28, 0.1, -0.45, -20 }, LFoot = { -0.28, 0.1, 0.45, 30 } }),
		P(0.44, "O", SWORD_GUARD, { Torso = true, Root = { 0, 330, 0 }, RootP = { 0, -0.5, 0 }, Waist = { -14, 10, 0 }, Neck = { 8, -10, 0 },
			RHand = { -100, -0.25, 1.4 }, RBlade = { -110, -5 }, LHand = { 60, -0.2, 0.9 },
			RFoot = { 0.3, 0, -0.5, -20 }, LFoot = { -0.3, 0, 0.5, 30 } }),
		P(0.62, "s", SWORD_GUARD, { Torso = true, Root = { 0, 345, 0 }, RootP = { 0, -0.45, 0 }, Waist = { -13, 10, 0 }, Neck = { 8, -12, 0 },
			RHand = { -98, -0.25, 1.38 }, RBlade = { -108, -3 }, LHand = { 58, -0.22, 0.88 },
			RFoot = { 0.3, 0, -0.5, -20 }, LFoot = { -0.3, 0, 0.5, 30 } }),
		P(0.95, "s", SWORD_SPIN_END),
	},
}

-- Guard while Block is held: blade flat across the face, pointing left; left hand supports it.
Clips.Sword_Block = {
	Length = 0.13, Hold = true, Legs = "Stand", FadeIn = 0.05, FadeOut = 0.12,
	Poses = {
		P(0, nil, SWORD_GUARD),
		P(0.13, "O", SWORD_GUARD, { Root = { 0, 8, 0 }, RootP = { 0, -0.32, 0 }, Waist = { -4, -5, 0 }, Neck = { 6, 0, 0 },
			RHand = { -25, 0.45, 0.95 }, RBlade = { 95, 10 }, LHand = { 22, 0.35, 0.95 },
			RFoot = { 0.2, 0, -0.45, -15 }, LFoot = { -0.2, 0, 0.45, 25 } }),
	},
}

-- A hit taken on the guard: pushed back, arms jolt (added on top of the guard).
Clips.Sword_BlockHit = {
	Length = 0.28, Additive = true, Legs = "Upper", FadeIn = 0.01, FadeOut = 0.01,
	Poses = {
		P(0, nil, REST),
		P(0.05, "O", REST, { Root = { 5, 0, 0 }, RootP = { 0, 0, 0.15 }, Waist = { 9, 0, 0 }, Neck = { 6, 0, 0 },
			RShoulder = { -12, 0, 0 }, RElbow = { 12, 0, 0 }, LShoulder = { -10, 0, 0 } }),
		P(0.28, "s", REST),
	},
}

-- A hit taken on the guard (every category): pushed back, arms jolt, added on top of the guard.
local function blockHitClip(): { [string]: any }
	return {
		Length = 0.28, Additive = true, Legs = "Upper", FadeIn = 0.01, FadeOut = 0.01,
		Poses = {
			P(0, nil, REST),
			P(0.05, "O", REST, { Root = { 5, 0, 0 }, RootP = { 0, 0, 0.15 }, Waist = { 9, 0, 0 }, Neck = { 6, 0, 0 },
				RShoulder = { -12, 0, 0 }, RElbow = { 12, 0, 0 }, LShoulder = { -10, 0, 0 } }),
			P(0.28, "s", REST),
		},
	}
end

-- A looping stance: the guard and a breathing pose in the middle.
local function stance(length: number, guard: Pose, breath: Pose): { [string]: any }
	return {
		Length = length, Loop = true, Legs = "Stand", FadeIn = 0.2, FadeOut = 0.2,
		Poses = { P(0, nil, guard), P(length / 2, nil, breath), P(length, nil, guard) },
	}
end

-- ------------------------------------------------------------------------------------------------
-- SPEAR: two hands on the shaft, long reach, forward lunges (3 steps, 1.11 s interval at speed x1)
-- ------------------------------------------------------------------------------------------------
-- Guard: left side forward, rear (right) hand out at the hip, the point raised toward the target (the shaft passes
-- right of the body so it reads from the camera behind), left hand forward on the shaft.
local SPEAR_GUARD: Pose = {
	Root = { 0, -25, 0 }, RootP = { 0, -0.25, 0 },
	Waist = { -5, 5, 0 }, Neck = { 4, 18, 0 },
	RHand = { -70, -0.6, 0.75 }, RBlade = { -4, 18 },
	LHand = { 25, -0.4, 0.9 }, LGrip = { 1.3, 1 },
	RFoot = { 0.15, 0, 0.45, -30 }, LFoot = { -0.1, 0, -0.5, 10 },
}
Clips.Spear_Idle = stance(2.4, SPEAR_GUARD, with(SPEAR_GUARD, { RootP = { 0, -0.28, 0 }, Waist = { -6, 5, 0 },
	RHand = { -70, -0.64, 0.75 }, RBlade = { -4, 16 } }))

local SPEAR_RUN: Pose = {
	Waist = { -12, 0, 0 }, Neck = { 8, 0, 0 },
	RHand = { -60, -0.65, 0.6 }, RBlade = { -5, 25 }, LHand = { 30, -0.4, 0.8 }, LGrip = { 1.1, 1 },
}
Clips.Spear_Run = {
	Length = 0.7, Loop = true, Legs = "Upper", FadeIn = 0.15, FadeOut = 0.15,
	Poses = { P(0, nil, SPEAR_RUN), P(0.35, nil, SPEAR_RUN, { Waist = { -14, 0, 0 }, RBlade = { -5, 21 } }), P(0.7, nil, SPEAR_RUN) },
}

-- Draw: the spear comes down from upright, the left hand takes the shaft.
Clips.Spear_Equip = {
	Length = 0.5, Legs = "Stand", FadeIn = 0.06, FadeOut = 0.15,
	Poses = {
		P(0, nil, SPEAR_GUARD, { RHand = { -60, -0.3, 0.55 }, RBlade = { -20, 80 }, LGrip = { 1.3, 0 }, LHand = { 30, -0.7, 0.5 } }),
		P(0.2, "o", SPEAR_GUARD, { RHand = { -50, -0.5, 0.7 }, RBlade = { -10, 35 }, LGrip = { 1.3, 0.6 } }),
		P(0.5, "s", SPEAR_GUARD),
	},
}

-- Attack 1, Thrust: pull back, both arms drive the point forward with a step.
Clips.Spear_Attack1 = {
	Length = 0.8, Legs = "Stand", FadeIn = 0.05, FadeOut = 0.15, Markers = { Hit = 0.18 },
	Poses = {
		P(0, nil, SPEAR_GUARD),
		P(0.09, "o", SPEAR_GUARD, { Root = { 0, -32, 0 }, RootP = { 0, -0.3, 0.12 }, Waist = { -2, 0, 0 }, Neck = { 4, 25, 0 },
			RHand = { -78, -0.55, 0.45 }, RBlade = { -4, 14 }, LGrip = { 1.1, 1 } }),
		P(0.18, "i", SPEAR_GUARD, { Root = { 0, -15, 0 }, RootP = { 0, -0.36, -0.15 }, Waist = { -12, 8, 0 }, Neck = { 8, 8, 0 },
			RHand = { -52, -0.3, 1.15 }, RBlade = { 3, 6 }, LGrip = { 1.7, 1 }, LFoot = { -0.1, 0, -0.75, 10 } }),
		P(0.32, "O", SPEAR_GUARD, { Root = { 0, -14, 0 }, RootP = { 0, -0.37, -0.15 }, Waist = { -13, 8, 0 }, Neck = { 8, 8, 0 },
			RHand = { -51, -0.3, 1.2 }, RBlade = { 3, 6 }, LGrip = { 1.75, 1 }, LFoot = { -0.1, 0, -0.75, 10 } }),
		P(0.8, "s", SPEAR_GUARD),
	},
}

-- Attack 2, Thrust2: overhand, the spear raised over the right shoulder stabs down-forward.
Clips.Spear_Attack2 = {
	Length = 0.8, Legs = "Stand", FadeIn = 0.05, FadeOut = 0.15, Markers = { Hit = 0.18 },
	Poses = {
		P(0, nil, SPEAR_GUARD),
		P(0.09, "o", SPEAR_GUARD, { Root = { 0, -30, 0 }, RootP = { 0, -0.26, 0.08 }, Waist = { 6, 0, 0 }, Neck = { 0, 22, 0 },
			RHand = { -78, 0.5, 0.75 }, RBlade = { -3, -2 }, LGrip = { 1.4, 1 } }),
		P(0.18, "i", SPEAR_GUARD, { Root = { 0, -12, 0 }, RootP = { 0, -0.38, -0.15 }, Waist = { -14, 10, 0 }, Neck = { 10, 6, 0 },
			RHand = { -52, 0.2, 1.1 }, RBlade = { 5, -10 }, LGrip = { 1.8, 1 }, LFoot = { -0.1, 0, -0.75, 10 } }),
		P(0.32, "O", SPEAR_GUARD, { Root = { 0, -11, 0 }, RootP = { 0, -0.39, -0.15 }, Waist = { -15, 10, 0 }, Neck = { 10, 6, 0 },
			RHand = { -51, 0.17, 1.15 }, RBlade = { 5, -11 }, LGrip = { 1.85, 1 }, LFoot = { -0.1, 0, -0.75, 10 } }),
		P(0.8, "s", SPEAR_GUARD),
	},
}

-- Attack 3, PiercingLunge (finisher): deep coil, a long one-handed lunge, the left arm thrown back for balance.
Clips.Spear_Attack3 = {
	Length = 0.95, Legs = "Stand", FadeIn = 0.05, FadeOut = 0.15, Markers = { Hit = 0.24 },
	Poses = {
		P(0, nil, SPEAR_GUARD),
		P(0.12, "o", SPEAR_GUARD, { Root = { 0, -40, 0 }, RootP = { 0, -0.42, 0.2 }, Waist = { 0, -5, 0 }, Neck = { 4, 35, 0 },
			RHand = { -88, -0.45, 0.45 }, RBlade = { -6, 14 }, LGrip = { 1.0, 1 },
			RFoot = { 0.2, 0, 0.6, -30 }, LFoot = { -0.1, 0, -0.45, 10 } }),
		P(0.24, "i", SPEAR_GUARD, { Root = { 0, -5, 0 }, RootP = { 0, -0.6, -0.35 }, Waist = { -18, 15, 0 }, Neck = { 14, -5, 0 },
			RHand = { -45, -0.1, 1.35 }, RBlade = { 3, 2 }, LGrip = { 1.6, 0 }, LHand = { 150, -0.3, 0.75 },
			RFoot = { 0.2, 0, 0.75, -30 }, LFoot = { -0.1, 0, -1.0, 10 } }),
		P(0.42, "O", SPEAR_GUARD, { Root = { 0, -5, 0 }, RootP = { 0, -0.62, -0.35 }, Waist = { -19, 15, 0 }, Neck = { 14, -5, 0 },
			RHand = { -44, -0.08, 1.38 }, RBlade = { 3, 2 }, LGrip = { 1.6, 0 }, LHand = { 155, -0.3, 0.75 },
			RFoot = { 0.2, 0, 0.75, -30 }, LFoot = { -0.1, 0, -1.0, 10 } }),
		P(0.95, "s", SPEAR_GUARD),
	},
}

-- Block: the shaft held level across the chest, hands wide.
Clips.Spear_Block = {
	Length = 0.13, Hold = true, Legs = "Stand", FadeIn = 0.05, FadeOut = 0.12,
	Poses = {
		P(0, nil, SPEAR_GUARD),
		P(0.13, "O", SPEAR_GUARD, { RootP = { 0, -0.32, 0 }, Waist = { -4, 5, 0 },
			RHand = { -40, 0.05, 0.8 }, RBlade = { 95, 8 }, LGrip = { 1.6, 1 } }),
	},
}
Clips.Spear_BlockHit = blockHitClip()

-- ------------------------------------------------------------------------------------------------
-- HEAVY: two hands, slow and heavy, big anticipation (2 steps, 2.5 s interval)
-- RFace = the striking face of the head (ImpactAttachment side), turned toward the swing.
-- ------------------------------------------------------------------------------------------------
local HEAVY_GUARD: Pose = {
	Root = { 0, 10, 0 }, RootP = { 0, -0.3, 0 },
	Waist = { -6, -5, 0 }, Neck = { 4, -5, 0 },
	RHand = { -35, -0.6, 0.75 }, RBlade = { -30, 55 }, RFace = { -30, -35 },
	LHand = { 20, -0.7, 0.6 }, LGrip = { -0.8, 1 },
	RFoot = { 0.28, 0, -0.2, -15 }, LFoot = { -0.28, 0, 0.3, 20 },
}
Clips.Heavy_Idle = stance(2.8, HEAVY_GUARD, with(HEAVY_GUARD, { RootP = { 0, -0.34, 0 }, Waist = { -8, -5, 0 },
	RHand = { -35, -0.65, 0.75 }, RBlade = { -30, 52 }, RFace = { -30, -38 } }))

-- Run: the weapon on the right shoulder, head behind.
local HEAVY_RUN: Pose = {
	Waist = { -12, 0, 0 }, Neck = { 8, 0, 0 },
	RHand = { -40, 0.15, 0.4 }, RBlade = { -170, 45 }, RFace = { -170, -45 },
	LHand = { 35, -0.55, 0.75 }, LGrip = { -0.8, 0 },
}
Clips.Heavy_Run = {
	Length = 0.7, Loop = true, Legs = "Upper", FadeIn = 0.15, FadeOut = 0.15,
	Poses = { P(0, nil, HEAVY_RUN), P(0.35, nil, HEAVY_RUN, { Waist = { -14, 0, 0 }, RHand = { -40, 0.1, 0.4 } }), P(0.7, nil, HEAVY_RUN) },
}

-- Draw: hauled up from the ground into the guard.
Clips.Heavy_Equip = {
	Length = 0.6, Legs = "Stand", FadeIn = 0.06, FadeOut = 0.15,
	Poses = {
		P(0, nil, HEAVY_GUARD, { RootP = { 0, -0.4, 0 }, Waist = { -15, -5, 0 },
			RHand = { -45, -1.0, 0.45 }, RBlade = { -25, -50 }, RFace = { -25, -140 }, LGrip = { -0.8, 0 }, LHand = { 20, -0.9, 0.4 } }),
		P(0.3, "o", HEAVY_GUARD, { RHand = { -30, -0.3, 0.8 }, RBlade = { -25, 75 }, RFace = { -25, -15 }, LGrip = { -0.8, 0.8 } }),
		P(0.6, "s", HEAVY_GUARD),
	},
}

-- Attack 1, OverheadSlam: a long lift over the head (lean back), a beat at the top, crashes into the ground in front.
Clips.Heavy_Attack1 = {
	Length = 1.7, Legs = "Stand", FadeIn = 0.08, FadeOut = 0.2, Markers = { Hit = 0.45 },
	Poses = {
		P(0, nil, HEAVY_GUARD),
		P(0.28, "o", HEAVY_GUARD, { Root = { 0, 5, 0 }, RootP = { 0, -0.12, 0.05 }, Waist = { 12, 0, 0 }, Neck = { -8, 0, 0 },
			RHand = { -10, 0.85, 0.35 }, RBlade = { 0, 145 }, RFace = { 0, 55 } }),
		P(0.36, "s", HEAVY_GUARD, { Root = { 0, 5, 0 }, RootP = { 0, -0.1, 0.06 }, Waist = { 14, 0, 0 }, Neck = { -9, 0, 0 },
			RHand = { -10, 0.9, 0.3 }, RBlade = { 0, 150 }, RFace = { 0, 60 } }),
		P(0.45, "i", HEAVY_GUARD, { Root = { 0, 0, 0 }, RootP = { 0, -0.6, -0.1 }, Waist = { -30, 0, 0 }, Neck = { 20, 0, 0 },
			RHand = { -5, -0.5, 1.1 }, RBlade = { 0, -22 }, RFace = { 0, -112 },
			RFoot = { 0.3, 0, -0.3, -15 }, LFoot = { -0.3, 0, 0.35, 20 } }),
		P(0.62, "O", HEAVY_GUARD, { Root = { 0, 0, 0 }, RootP = { 0, -0.62, -0.1 }, Waist = { -32, 0, 0 }, Neck = { 22, 0, 0 },
			RHand = { -5, -0.52, 1.1 }, RBlade = { 0, -24 }, RFace = { 0, -114 },
			RFoot = { 0.3, 0, -0.3, -15 }, LFoot = { -0.3, 0, 0.35, 20 } }),
		P(1.0, "s", HEAVY_GUARD, { Root = { 0, 4, 0 }, RootP = { 0, -0.5, -0.05 }, Waist = { -20, 0, 0 }, Neck = { 14, 0, 0 },
			RHand = { -15, -0.55, 0.95 }, RBlade = { -10, -10 }, RFace = { -10, -100 } }),
		P(1.7, "s", HEAVY_GUARD),
	},
}

-- Attack 2, WideSmash (finisher): coiled far to the right, a full flat sweep across the front to the left.
Clips.Heavy_Attack2 = {
	Length = 1.8, Legs = "Stand", FadeIn = 0.08, FadeOut = 0.2, Markers = { Hit = 0.4 },
	Poses = {
		P(0, nil, HEAVY_GUARD),
		P(0.3, "o", HEAVY_GUARD, { Root = { 0, -55, 0 }, RootP = { 0, -0.4, 0 }, Waist = { -5, -35, 0 }, Neck = { 6, 60, 0 },
			RHand = { -120, -0.2, 0.8 }, RBlade = { -150, 15 }, RFace = { -60, 0 },
			RFoot = { 0.3, 0, -0.25, -20 }, LFoot = { -0.3, 0, 0.3, 25 } }),
		P(0.4, "i", HEAVY_GUARD, { Root = { 0, 10, 0 }, RootP = { 0, -0.45, -0.05 }, Waist = { -10, 20, 0 }, Neck = { 6, -20, 0 },
			RHand = { -10, -0.3, 1.2 }, RBlade = { 20, 0 }, RFace = { 110, 0 },
			RFoot = { 0.3, 0, -0.25, -20 }, LFoot = { -0.3, 0, 0.3, 25 } }),
		P(0.55, "O", HEAVY_GUARD, { Root = { 0, 35, 0 }, RootP = { 0, -0.45, -0.05 }, Waist = { -12, 40, 0 }, Neck = { 8, -50, 0 },
			RHand = { 80, -0.4, 1.0 }, RBlade = { 130, -10 }, RFace = { 220, 0 },
			RFoot = { 0.3, 0, -0.25, -20 }, LFoot = { -0.3, 0, 0.3, 25 } }),
		P(0.95, "s", HEAVY_GUARD, { Root = { 0, 32, 0 }, RootP = { 0, -0.42, -0.05 }, Waist = { -10, 36, 0 }, Neck = { 8, -45, 0 },
			RHand = { 75, -0.45, 0.95 }, RBlade = { 125, -12 }, RFace = { 215, 0 } }),
		P(1.8, "s", HEAVY_GUARD, { RFace = { 330, -35 } }),
	},
}

-- Block: the haft held level across the chest, hands wide.
Clips.Heavy_Block = {
	Length = 0.15, Hold = true, Legs = "Stand", FadeIn = 0.06, FadeOut = 0.15,
	Poses = {
		P(0, nil, HEAVY_GUARD),
		P(0.15, "O", HEAVY_GUARD, { RootP = { 0, -0.35, 0 }, Waist = { -4, 0, 0 },
			RHand = { -30, -0.05, 0.85 }, RBlade = { 95, 10 }, RFace = { 0, 90 }, LGrip = { 1.4, 1 } }),
	},
}
Clips.Heavy_BlockHit = blockHitClip()

-- ------------------------------------------------------------------------------------------------
-- DAGGER: very fast, low stance, tiny lunges (5 steps, 0.4 s interval). The one dagger is in the right hand: the
-- steps alternate sides (forehand / backhand, right / cross-body stab) while the left hand counters.
-- ------------------------------------------------------------------------------------------------
local DAGGER_GUARD: Pose = {
	Root = { 0, 15, 0 }, RootP = { 0, -0.38, 0 },
	Waist = { -14, -5, 0 }, Neck = { 10, -10, 0 },
	RHand = { -35, -0.65, 0.95 }, RBlade = { -10, 15 },
	LHand = { 35, -0.45, 0.85 },
	RFoot = { 0.15, 0, -0.45, -12 }, LFoot = { -0.15, 0, 0.45, 25 },
}
Clips.Dagger_Idle = stance(1.6, DAGGER_GUARD, with(DAGGER_GUARD, { RootP = { 0, -0.43, 0 }, Waist = { -15, -5, 0 },
	RHand = { -35, -0.7, 0.95 }, LHand = { 35, -0.5, 0.85 } }))

local DAGGER_RUN: Pose = {
	Waist = { -18, 0, 0 }, Neck = { 12, 0, 0 },
	RHand = { -60, -0.75, 0.6 }, RBlade = { -170, -15 }, LHand = { 40, -0.5, 0.7 },
}
Clips.Dagger_Run = {
	Length = 0.6, Loop = true, Legs = "Upper", FadeIn = 0.12, FadeOut = 0.12,
	Poses = { P(0, nil, DAGGER_RUN), P(0.3, nil, DAGGER_RUN, { Waist = { -20, 0, 0 } }), P(0.6, nil, DAGGER_RUN) },
}

-- Draw: a flip from point-up to the forward grip.
Clips.Dagger_Equip = {
	Length = 0.3, Legs = "Stand", FadeIn = 0.04, FadeOut = 0.1,
	Poses = {
		P(0, nil, DAGGER_GUARD, { RHand = { -45, -0.2, 0.6 }, RBlade = { -30, 85 } }),
		P(0.12, "o", DAGGER_GUARD, { RHand = { -35, -0.5, 0.9 }, RBlade = { -10, -30 } }),
		P(0.3, "s", DAGGER_GUARD),
	},
}

-- Attack 1, SlashR: forehand from the right across the front.
Clips.Dagger_Attack1 = {
	Length = 0.36, Legs = "Stand", FadeIn = 0.03, FadeOut = 0.08, Markers = { Hit = 0.08 },
	Poses = {
		P(0, nil, DAGGER_GUARD),
		P(0.04, "o", DAGGER_GUARD, { Root = { 0, 0, 0 }, Waist = { -10, -25, 0 }, Neck = { 8, 15, 0 },
			RHand = { -85, -0.3, 0.85 }, RBlade = { -120, 5 } }),
		P(0.08, "i", DAGGER_GUARD, { Root = { 0, 25, 0 }, RootP = { 0, -0.42, -0.1 }, Waist = { -14, 10, 0 }, Neck = { 10, -25, 0 },
			RHand = { -5, -0.4, 1.3 }, RBlade = { 50, -5 } }),
		P(0.15, "O", DAGGER_GUARD, { Root = { 0, 30, 0 }, RootP = { 0, -0.42, -0.1 }, Waist = { -14, 22, 0 }, Neck = { 10, -35, 0 },
			RHand = { 50, -0.5, 1.1 }, RBlade = { 110, -10 } }),
		P(0.36, "s", DAGGER_GUARD),
	},
}

-- Attack 2, SlashL: backhand from the left across the front.
Clips.Dagger_Attack2 = {
	Length = 0.36, Legs = "Stand", FadeIn = 0.03, FadeOut = 0.08, Markers = { Hit = 0.08 },
	Poses = {
		P(0, nil, DAGGER_GUARD),
		P(0.04, "o", DAGGER_GUARD, { Root = { 0, 30, 0 }, Waist = { -10, 25, 0 }, Neck = { 8, -35, 0 },
			RHand = { 45, -0.15, 0.7 }, RBlade = { 125, 15 } }),
		P(0.08, "i", DAGGER_GUARD, { Root = { 0, 5, 0 }, RootP = { 0, -0.42, -0.1 }, Waist = { -14, -10, 0 }, Neck = { 10, 5, 0 },
			RHand = { -5, -0.35, 1.3 }, RBlade = { -45, -5 } }),
		P(0.15, "O", DAGGER_GUARD, { Root = { 0, 0, 0 }, RootP = { 0, -0.42, -0.1 }, Waist = { -14, -22, 0 }, Neck = { 10, 20, 0 },
			RHand = { -80, -0.45, 1.1 }, RBlade = { -115, -5 } }),
		P(0.36, "s", DAGGER_GUARD),
	},
}

-- Attack 3, StabR: a straight stab on the right, the left hand pulled back.
Clips.Dagger_Attack3 = {
	Length = 0.36, Legs = "Stand", FadeIn = 0.03, FadeOut = 0.08, Markers = { Hit = 0.08 },
	Poses = {
		P(0, nil, DAGGER_GUARD),
		P(0.04, "o", DAGGER_GUARD, { RootP = { 0, -0.4, 0.06 }, Waist = { -10, -12, 0 }, RHand = { -60, -0.55, 0.5 }, RBlade = { -15, 5 } }),
		P(0.08, "i", DAGGER_GUARD, { Root = { 0, 25, 0 }, RootP = { 0, -0.45, -0.15 }, Waist = { -18, 10, 0 }, Neck = { 14, -15, 0 },
			RHand = { -50, -0.3, 1.35 }, RBlade = { -25, 0 }, LHand = { 60, -0.5, 0.5 }, RFoot = { 0.15, 0, -0.65, -12 } }),
		P(0.16, "O", DAGGER_GUARD, { Root = { 0, 25, 0 }, RootP = { 0, -0.45, -0.15 }, Waist = { -18, 10, 0 }, Neck = { 14, -15, 0 },
			RHand = { -50, -0.3, 1.37 }, RBlade = { -25, 0 }, LHand = { 62, -0.5, 0.5 }, RFoot = { 0.15, 0, -0.65, -12 } }),
		P(0.36, "s", DAGGER_GUARD),
	},
}

-- Attack 4, StabL: an overhand stab down on the left side, the body turned in, the left hand drawn back.
Clips.Dagger_Attack4 = {
	Length = 0.36, Legs = "Stand", FadeIn = 0.03, FadeOut = 0.08, Markers = { Hit = 0.08 },
	Poses = {
		P(0, nil, DAGGER_GUARD),
		P(0.04, "o", DAGGER_GUARD, { Root = { 0, 20, 0 }, Waist = { -4, 10, 0 },
			RHand = { 10, 0.6, 0.55 }, RBlade = { 20, 30 }, LHand = { 40, -0.35, 1.0 } }),
		P(0.08, "i", DAGGER_GUARD, { Root = { 0, 30, 0 }, RootP = { 0, -0.45, -0.15 }, Waist = { -20, 22, 0 }, Neck = { 16, -35, 0 },
			RHand = { 30, -0.15, 1.3 }, RBlade = { 30, -40 }, LHand = { 90, -0.5, 0.45 } }),
		P(0.16, "O", DAGGER_GUARD, { Root = { 0, 30, 0 }, RootP = { 0, -0.45, -0.15 }, Waist = { -20, 22, 0 }, Neck = { 16, -35, 0 },
			RHand = { 31, -0.18, 1.3 }, RBlade = { 31, -42 }, LHand = { 92, -0.5, 0.45 } }),
		P(0.36, "s", DAGGER_GUARD),
	},
}

-- Attack 5, DoubleSlash (finisher): an X - high right down to the left (Hit), high left down to the right (Hit2).
Clips.Dagger_Attack5 = {
	Length = 0.38, Legs = "Stand", FadeIn = 0.03, FadeOut = 0.08, Markers = { Hit = 0.08, Hit2 = 0.2 },
	Poses = {
		P(0, nil, DAGGER_GUARD),
		P(0.04, "o", DAGGER_GUARD, { Root = { 0, 0, 0 }, Waist = { -8, -20, 0 }, RHand = { -60, 0.45, 0.75 }, RBlade = { -60, 60 } }),
		P(0.08, "i", DAGGER_GUARD, { Root = { 0, 20, 0 }, RootP = { 0, -0.45, -0.1 }, Waist = { -16, 15, 0 },
			RHand = { 15, -0.4, 1.2 }, RBlade = { 40, -35 } }),
		P(0.14, "o", DAGGER_GUARD, { Root = { 0, 25, 0 }, RootP = { 0, -0.4, -0.1 }, Waist = { -8, 20, 0 },
			RHand = { 50, 0.4, 0.8 }, RBlade = { 70, 55 } }),
		P(0.2, "i", DAGGER_GUARD, { Root = { 0, 5, 0 }, RootP = { 0, -0.48, -0.15 }, Waist = { -18, -12, 0 },
			RHand = { -20, -0.45, 1.25 }, RBlade = { -45, -35 } }),
		P(0.27, "O", DAGGER_GUARD, { Root = { 0, 0, 0 }, RootP = { 0, -0.48, -0.15 }, Waist = { -18, -20, 0 },
			RHand = { -60, -0.55, 1.05 }, RBlade = { -90, -30 } }),
		P(0.38, "s", DAGGER_GUARD),
	},
}

-- Block: arms crossed in front of the face, the blade out to the left.
Clips.Dagger_Block = {
	Length = 0.1, Hold = true, Legs = "Stand", FadeIn = 0.04, FadeOut = 0.1,
	Poses = {
		P(0, nil, DAGGER_GUARD),
		P(0.1, "O", DAGGER_GUARD, { Waist = { -10, 0, 0 }, RHand = { 10, 0.35, 0.75 }, RBlade = { 80, 35 }, LHand = { -15, 0.25, 0.75 } }),
	},
}
Clips.Dagger_BlockHit = blockHitClip()

-- ------------------------------------------------------------------------------------------------
-- GAUNTLET: punchy, rhythmic (3 steps, 0.556 s interval). One right-hand gauntlet: RBlade = where the knuckles
-- point, RFace = the back of the hand. Southpaw stance (right side forward), the left fist guards the chin.
-- ------------------------------------------------------------------------------------------------
local GAUNT_GUARD: Pose = {
	Root = { 0, 25, 0 }, RootP = { 0, -0.28, 0 },
	Waist = { -8, -10, 0 }, Neck = { 6, -15, 0 },
	RHand = { -25, -0.15, 0.75 }, RBlade = { -5, 20 }, RFace = { -5, 110 },
	LHand = { 25, -0.05, 0.6 }, LBlade = { 5, 25 },
	RFoot = { 0.15, 0, -0.45, -15 }, LFoot = { -0.15, 0, 0.45, 25 },
}
Clips.Gauntlet_Idle = stance(1.0, GAUNT_GUARD, with(GAUNT_GUARD, { RootP = { 0, -0.34, 0 }, Waist = { -9, -10, 0 },
	RHand = { -25, -0.2, 0.75 }, LHand = { 25, -0.1, 0.6 } }))

local GAUNT_RUN: Pose = {
	Waist = { -14, 0, 0 }, Neck = { 10, 0, 0 },
	RHand = { -30, -0.3, 0.65 }, RBlade = { 0, 45 }, RFace = { 0, 135 }, LHand = { 30, -0.3, 0.6 }, LBlade = { 0, 45 },
}
Clips.Gauntlet_Run = {
	Length = 0.6, Loop = true, Legs = "Upper", FadeIn = 0.12, FadeOut = 0.12,
	Poses = { P(0, nil, GAUNT_RUN), P(0.3, nil, GAUNT_RUN, { RHand = { -30, -0.38, 0.65 }, LHand = { 30, -0.22, 0.6 } }), P(0.6, nil, GAUNT_RUN) },
}

-- Draw: the fists knock together, then up into the guard.
Clips.Gauntlet_Equip = {
	Length = 0.4, Legs = "Stand", FadeIn = 0.05, FadeOut = 0.12,
	Poses = {
		P(0, nil, GAUNT_GUARD, { RHand = { -8, -0.3, 0.8 }, RBlade = { 30, 0 }, RFace = { 30, 90 }, LHand = { 8, -0.3, 0.8 }, LBlade = { -30, 0 } }),
		P(0.12, "O", GAUNT_GUARD, { RHand = { -6, -0.3, 0.72 }, RBlade = { 35, 0 }, RFace = { 35, 90 }, LHand = { 6, -0.3, 0.72 }, LBlade = { -35, 0 } }),
		P(0.4, "s", GAUNT_GUARD),
	},
}

-- Attack 1, Jab: a quick straight from the lead (right) fist.
Clips.Gauntlet_Attack1 = {
	Length = 0.42, Legs = "Stand", FadeIn = 0.04, FadeOut = 0.1, Markers = { Hit = 0.1 },
	Poses = {
		P(0, nil, GAUNT_GUARD),
		P(0.05, "o", GAUNT_GUARD, { Waist = { -8, -12, 0 }, RHand = { -25, -0.2, 0.6 } }),
		P(0.1, "i", GAUNT_GUARD, { Root = { 0, 20, 0 }, RootP = { 0, -0.3, -0.08 }, Waist = { -8, 8, 0 },
			RHand = { -30, 0.0, 1.4 }, RBlade = { -8, 0 }, RFace = { -8, 90 } }),
		P(0.17, "O", GAUNT_GUARD, { Root = { 0, 20, 0 }, RootP = { 0, -0.3, -0.08 }, Waist = { -8, 8, 0 },
			RHand = { -30, 0.0, 1.38 }, RBlade = { -8, 0 }, RFace = { -8, 90 } }),
		P(0.42, "s", GAUNT_GUARD),
	},
}

-- Attack 2, Cross: the hips turn through, a full power straight; the left fist comes back to the chin.
Clips.Gauntlet_Attack2 = {
	Length = 0.5, Legs = "Stand", FadeIn = 0.04, FadeOut = 0.1, Markers = { Hit = 0.1 },
	Poses = {
		P(0, nil, GAUNT_GUARD),
		P(0.05, "o", GAUNT_GUARD, { Root = { 0, 40, 0 }, Waist = { -6, 15, 0 }, RHand = { -40, -0.15, 0.55 } }),
		P(0.1, "i", GAUNT_GUARD, { Root = { 0, 0, 0 }, RootP = { 0, -0.34, -0.12 }, Waist = { -12, -15, 0 }, Neck = { 8, 15, 0 },
			RHand = { -15, 0.05, 1.45 }, RBlade = { -3, 0 }, RFace = { -3, 90 }, LHand = { 30, 0.0, 0.45 },
			RFoot = { 0.15, 0, -0.6, -15 } }),
		P(0.2, "O", GAUNT_GUARD, { Root = { 0, 0, 0 }, RootP = { 0, -0.34, -0.12 }, Waist = { -12, -15, 0 }, Neck = { 8, 15, 0 },
			RHand = { -15, 0.05, 1.43 }, RBlade = { -3, 0 }, RFace = { -3, 90 }, LHand = { 30, 0.0, 0.45 },
			RFoot = { 0.15, 0, -0.6, -15 } }),
		P(0.5, "s", GAUNT_GUARD),
	},
}

-- Attack 3, Uppercut (finisher, x2): dip low and coil, drive up onto the toes, the fist rising high on the right
-- (beside the head, so it reads from the camera behind).
Clips.Gauntlet_Attack3 = {
	Length = 0.52, Legs = "Stand", FadeIn = 0.04, FadeOut = 0.1, Markers = { Hit = 0.16 },
	Poses = {
		P(0, nil, GAUNT_GUARD),
		P(0.09, "o", GAUNT_GUARD, { Root = { 0, 35, 0 }, RootP = { 0, -0.5, 0 }, Waist = { -20, 25, 0 }, Neck = { 16, -25, 0 },
			RHand = { -30, -0.85, 0.6 }, RBlade = { -10, -20 }, RFace = { -10, 70 } }),
		P(0.16, "i", GAUNT_GUARD, { Root = { 0, 5, 0 }, RootP = { 0, 0.3, -0.1 }, Waist = { 6, -10, 16 }, Neck = { -6, 5, -10 },
			RHand = { -70, 1.05, 0.75 }, RBlade = { -40, 80 }, RFace = { -40, -10 }, LHand = { 30, -0.2, 0.5 } }),
		P(0.26, "O", GAUNT_GUARD, { Root = { 0, 5, 0 }, RootP = { 0, 0.32, -0.1 }, Waist = { 6, -10, 17 }, Neck = { -6, 5, -10 },
			RHand = { -70, 1.08, 0.74 }, RBlade = { -40, 82 }, RFace = { -40, -8 }, LHand = { 30, -0.2, 0.5 } }),
		P(0.52, "s", GAUNT_GUARD),
	},
}

-- Block: both forearms up in front of the face.
Clips.Gauntlet_Block = {
	Length = 0.1, Hold = true, Legs = "Stand", FadeIn = 0.04, FadeOut = 0.1,
	Poses = {
		P(0, nil, GAUNT_GUARD),
		P(0.1, "O", GAUNT_GUARD, { RootP = { 0, -0.35, 0 }, Waist = { -12, 0, 0 },
			RHand = { -12, 0.35, 0.55 }, RBlade = { 0, 85 }, RFace = { 0, -5 }, LHand = { 12, 0.35, 0.55 }, LBlade = { 0, 85 } }),
	},
}
Clips.Gauntlet_BlockHit = blockHitClip()

-- ------------------------------------------------------------------------------------------------
-- RANGED (1 step, 0.833 s interval; AimPitch: the torso follows the aim up / down)
-- Bows (style Ranged, the default): the bow in the right hand, side-on archer, the left hand draws to the face.
-- RBlade = the upper limb, RFace = the arrow side (Muzzle) toward the target.
-- ------------------------------------------------------------------------------------------------
local BOW_AIM: Pose = {
	Root = { 0, 45, 0 }, RootP = { 0, -0.2, 0 },
	Waist = { -2, 10, 0 }, Neck = { 2, -50, 0 },
	RHand = { -22, -0.05, 1.2 }, RBlade = { -60, 45 }, RFace = { 0, 0 },
	LHand = { 5, 0.3, 0.4 },
	RFoot = { 0, 0, -0.38, -10 }, LFoot = { 0, 0, 0.38, 10 },
}
Clips.Ranged_Idle = stance(2.0, BOW_AIM, with(BOW_AIM, { RootP = { 0, -0.23, 0 }, Waist = { -3, 15, 0 },
	RHand = { -22, -0.08, 1.2 }, LHand = { 5, 0.27, 0.4 } }))

local BOW_RUN: Pose = {
	Waist = { -12, 0, 0 }, Neck = { 8, 0, 0 },
	RHand = { -55, -0.75, 0.65 }, RBlade = { -20, 65 }, RFace = { 0, -25 }, LHand = { 40, -0.5, 0.75 },
}
Clips.Ranged_Run = {
	Length = 0.7, Loop = true, Legs = "Upper", FadeIn = 0.15, FadeOut = 0.15,
	Poses = { P(0, nil, BOW_RUN), P(0.35, nil, BOW_RUN, { Waist = { -14, 0, 0 } }), P(0.7, nil, BOW_RUN) },
}

-- Draw: the bow comes up from the hip, the left hand takes the string.
Clips.Ranged_Equip = {
	Length = 0.45, Legs = "Stand", FadeIn = 0.06, FadeOut = 0.15,
	Poses = {
		P(0, nil, BOW_AIM, { Root = { 0, 20, 0 }, Waist = { -6, 5, 0 }, Neck = { 4, -20, 0 },
			RHand = { -50, -0.8, 0.6 }, RBlade = { -20, 60 }, RFace = { 0, -30 }, LHand = { 50, -0.6, 0.6 } }),
		P(0.25, "o", BOW_AIM, { LHand = { -15, 0.0, 1.0 } }),
		P(0.45, "s", BOW_AIM),
	},
}

-- Attack 1, Shot: release (the drawing hand flies back, the bow kicks), nock again at the bow, draw back to the face.
Clips.Ranged_Attack1 = {
	Length = 0.65, Legs = "Stand", AimPitch = true, FadeIn = 0.04, FadeOut = 0.15, Markers = { Hit = 0.05 },
	Poses = {
		P(0, nil, BOW_AIM),
		P(0.05, "O", BOW_AIM, { RHand = { -22, 0.0, 1.15 }, RBlade = { -62, 50 }, LHand = { 110, 0.3, 0.5 } }),
		P(0.14, "O", BOW_AIM, { LHand = { 120, 0.25, 0.5 } }),
		P(0.34, "s", BOW_AIM, { LHand = { -15, 0.0, 1.0 } }),
		P(0.6, "s", BOW_AIM),
	},
}

-- Block: the bow held up flat in front.
Clips.Ranged_Block = {
	Length = 0.12, Hold = true, Legs = "Stand", FadeIn = 0.05, FadeOut = 0.12,
	Poses = {
		P(0, nil, BOW_AIM),
		P(0.12, "O", BOW_AIM, { Root = { 0, 10, 0 }, Waist = { -4, 0, 0 }, Neck = { 4, -10, 0 },
			RHand = { -20, 0.3, 0.9 }, RBlade = { 90, 10 }, RFace = { 0, 80 }, LHand = { 25, 0.2, 0.75 } }),
	},
}
Clips.Ranged_BlockHit = blockHitClip()

-- Crossbows (style RangedCrossbow: RFace = the top, up) and guns / blowgun (style RangedGun: RFace = the side, so the
-- pistol grip hangs down): shouldered, the left hand forward on the weapon, recoil on the shot.
local function rifleClips(prefix: string, face: { number }, blockFace: { number })
	local aim: Pose = {
		Root = { 0, 35, 0 }, RootP = { 0, -0.22, 0 },
		Waist = { -6, 5, 0 }, Neck = { 4, -35, 0 },
		RHand = { -25, -0.05, 0.55 }, RBlade = { 0, 0 }, RFace = face,
		LHand = { 20, -0.2, 0.9 }, LGrip = { 1.4, 1 },
		RFoot = { 0.1, 0, -0.4, -15 }, LFoot = { -0.1, 0, 0.4, 20 },
	}
	Clips[prefix .. "_Idle"] = stance(2.0, aim, with(aim, { RootP = { 0, -0.25, 0 }, Waist = { -7, 5, 0 }, RBlade = { 0, -2 } }))
	local run: Pose = {
		Waist = { -12, 0, 0 }, Neck = { 8, 0, 0 },
		RHand = { -30, -0.35, 0.55 }, RBlade = { -20, -25 }, RFace = face, LHand = { 20, -0.4, 0.8 }, LGrip = { 1.3, 1 },
	}
	Clips[prefix .. "_Run"] = {
		Length = 0.7, Loop = true, Legs = "Upper", FadeIn = 0.15, FadeOut = 0.15,
		Poses = { P(0, nil, run), P(0.35, nil, run, { Waist = { -14, 0, 0 } }), P(0.7, nil, run) },
	}
	Clips[prefix .. "_Equip"] = {
		Length = 0.45, Legs = "Stand", FadeIn = 0.06, FadeOut = 0.15,
		Poses = {
			P(0, nil, aim, { RHand = { -40, -0.6, 0.6 }, RBlade = { -15, -45 }, LGrip = { 1.4, 0 }, LHand = { 30, -0.6, 0.6 } }),
			P(0.25, "o", aim, { RBlade = { 0, 8 }, LGrip = { 1.4, 0.8 } }),
			P(0.45, "s", aim),
		},
	}
	Clips[prefix .. "_Attack1"] = {
		Length = 0.6, Legs = "Stand", AimPitch = true, FadeIn = 0.04, FadeOut = 0.15, Markers = { Hit = 0.05 },
		Poses = {
			P(0, nil, aim),
			P(0.05, "O", aim, { RootP = { 0, -0.2, 0.08 }, Waist = { 2, 5, 0 }, Neck = { 0, -35, 0 },
				RHand = { -25, 0.05, 0.45 }, RBlade = { 0, 14 }, LGrip = { 1.4, 1 } }),
			P(0.2, "s", aim, { RootP = { 0, -0.21, 0.03 }, Waist = { -3, 5, 0 }, RBlade = { 0, 4 } }),
			P(0.6, "s", aim),
		},
	}
	Clips[prefix .. "_Block"] = {
		Length = 0.12, Hold = true, Legs = "Stand", FadeIn = 0.05, FadeOut = 0.12,
		Poses = {
			P(0, nil, aim),
			P(0.12, "O", aim, { Root = { 0, 10, 0 }, Waist = { -4, 0, 0 }, Neck = { 4, -10, 0 },
				RHand = { -30, 0.15, 0.75 }, RBlade = { 95, 5 }, RFace = blockFace, LGrip = { 1.6, 1 } }),
		},
	}
end
rifleClips("RangedCrossbow", { 0, 90 }, { 0, 90 })
rifleClips("RangedGun", { 90, 0 }, { 0, 0 })

-- ------------------------------------------------------------------------------------------------
-- MAGIC: a staff in the right hand, readable casting pose (1 step, 1.0 s interval; AimPitch)
-- ------------------------------------------------------------------------------------------------
local STAFF_GUARD: Pose = {
	Root = { 0, 15, 0 }, RootP = { 0, -0.2, 0 },
	Waist = { -4, -5, 0 }, Neck = { 2, -10, 0 },
	RHand = { -55, -0.6, 0.85 }, RBlade = { -10, 85 },
	LHand = { 30, -0.5, 0.7 },
	RFoot = { 0.12, 0, -0.4, -12 }, LFoot = { -0.12, 0, 0.4, 20 },
}
Clips.Magic_Idle = stance(2.6, STAFF_GUARD, with(STAFF_GUARD, { RootP = { 0, -0.23, 0 }, Waist = { -5, -5, 0 },
	RBlade = { -6, 82 }, LHand = { 30, -0.45, 0.72 } }))

local STAFF_RUN: Pose = {
	Waist = { -12, 0, 0 }, Neck = { 8, 0, 0 },
	RHand = { -50, -0.6, 0.75 }, RBlade = { -25, 50 }, LHand = { 35, -0.5, 0.75 },
}
Clips.Magic_Run = {
	Length = 0.7, Loop = true, Legs = "Upper", FadeIn = 0.15, FadeOut = 0.15,
	Poses = { P(0, nil, STAFF_RUN), P(0.35, nil, STAFF_RUN, { Waist = { -14, 0, 0 } }), P(0.7, nil, STAFF_RUN) },
}

-- Draw: the staff swings from level to upright.
Clips.Magic_Equip = {
	Length = 0.5, Legs = "Stand", FadeIn = 0.06, FadeOut = 0.15,
	Poses = {
		P(0, nil, STAFF_GUARD, { Waist = { -4, 10, 0 }, RHand = { -50, -0.5, 0.8 }, RBlade = { 60, 5 } }),
		P(0.22, "o", STAFF_GUARD, { RHand = { -45, 0.1, 0.8 }, RBlade = { -20, 100 } }),
		P(0.5, "s", STAFF_GUARD),
	},
}

-- Attack 1, Cast: raise the staff high with the left palm out (a beat), then thrust the orb at the target.
Clips.Magic_Attack1 = {
	Length = 0.9, Legs = "Stand", AimPitch = true, FadeIn = 0.06, FadeOut = 0.15, Markers = { Hit = 0.3 },
	Poses = {
		P(0, nil, STAFF_GUARD),
		P(0.15, "o", STAFF_GUARD, { Root = { 0, 10, 0 }, RootP = { 0, -0.12, 0 }, Waist = { 6, -8, 0 }, Neck = { -4, -5, 0 },
			RHand = { -35, 0.55, 0.75 }, RBlade = { -5, 100 }, LHand = { 35, 0.15, 0.85 } }),
		P(0.22, "s", STAFF_GUARD, { Root = { 0, 10, 0 }, RootP = { 0, -0.1, 0 }, Waist = { 8, -8, 0 }, Neck = { -5, -5, 0 },
			RHand = { -33, 0.62, 0.72 }, RBlade = { -5, 105 }, LHand = { 35, 0.18, 0.85 } }),
		P(0.3, "i", STAFF_GUARD, { Root = { 0, 5, 0 }, RootP = { 0, -0.32, -0.1 }, Waist = { -12, 5, 0 }, Neck = { 8, -5, 0 },
			RHand = { -40, 0.15, 1.2 }, RBlade = { -25, 38 }, LHand = { 25, 0.0, 1.0 }, RFoot = { 0.12, 0, -0.6, -12 } }),
		P(0.45, "O", STAFF_GUARD, { Root = { 0, 5, 0 }, RootP = { 0, -0.33, -0.1 }, Waist = { -13, 5, 0 }, Neck = { 8, -5, 0 },
			RHand = { -40, 0.13, 1.22 }, RBlade = { -25, 36 }, LHand = { 25, -0.02, 1.0 }, RFoot = { 0.12, 0, -0.6, -12 } }),
		P(0.9, "s", STAFF_GUARD),
	},
}

-- Block: the staff held level in front, both hands on it.
Clips.Magic_Block = {
	Length = 0.13, Hold = true, Legs = "Stand", FadeIn = 0.05, FadeOut = 0.12,
	Poses = {
		P(0, nil, STAFF_GUARD, { LGrip = { 1.2, 0 } }),
		P(0.13, "O", STAFF_GUARD, { RootP = { 0, -0.3, 0 }, RHand = { -30, 0.1, 0.85 }, RBlade = { 95, 5 }, LGrip = { 1.2, 1 } }),
	},
}
Clips.Magic_BlockHit = blockHitClip()

-- ------------------------------------------------------------------------------------------------
-- SHARED (every category)
-- ------------------------------------------------------------------------------------------------
-- Forward roll (the engine turns it toward the dash direction): tucked, one full turn in 0.3 s, back up.
local ROLL_TUCK: Pose = {
	Waist = { -40, 0, 0 }, Neck = { -30, 0, 0 },
	RShoulder = { 70, 0, 12 }, RElbow = { 110, 0, 0 }, LShoulder = { 70, 0, -12 }, LElbow = { 110, 0, 0 },
	RHip = { 115, 0, 0 }, RKnee = { -135, 0, 0 }, RAnkle = { 40, 0, 0 },
	LHip = { 115, 0, 0 }, LKnee = { -135, 0, 0 }, LAnkle = { 40, 0, 0 },
}
Clips.Shared_Roll = {
	Length = 0.42, Legs = "Own", FadeIn = 0.04, FadeOut = 0.1,
	Poses = {
		P(0, nil, ROLL_TUCK, { Root = { -15, 0, 0 }, RootP = { 0, -0.5, 0 }, Waist = { -25, 0, 0 },
			RHip = { 60, 0, 0 }, RKnee = { -90, 0, 0 }, RAnkle = { 30, 0, 0 }, LHip = { 40, 0, 0 }, LKnee = { -80, 0, 0 }, LAnkle = { 40, 0, 0 } }),
		P(0.04, "l", ROLL_TUCK, { Root = { -60, 0, 0 }, RootP = { 0, -1.05, 0 } }),
		P(0.08, "l", ROLL_TUCK, { Root = { -120, 0, 0 }, RootP = { 0, -0.6, 0 } }),
		P(0.13, "l", ROLL_TUCK, { Root = { -180, 0, 0 }, RootP = { 0, -0.15, 0 } }),
		P(0.18, "l", ROLL_TUCK, { Root = { -240, 0, 0 }, RootP = { 0, -0.5, 0 } }),
		P(0.23, "l", ROLL_TUCK, { Root = { -300, 0, 0 }, RootP = { 0, -1.05, 0 } }),
		P(0.28, "l", ROLL_TUCK, { Root = { -345, 0, 0 }, RootP = { 0, -1.2, 0 },
			RHip = { 90, 0, 0 }, RKnee = { -120, 0, 0 }, LHip = { 70, 0, 0 }, LKnee = { -110, 0, 0 } }),
		P(0.34, "o", ROLL_TUCK, { Root = { -360, 0, 0 }, RootP = { 0, -0.7, 0 }, Waist = { -15, 0, 0 }, Neck = { -5, 0, 0 },
			RShoulder = { 40, 0, 20 }, RElbow = { 50, 0, 0 }, LShoulder = { 40, 0, -20 }, LElbow = { 50, 0, 0 },
			RHip = { 60, 0, 0 }, RKnee = { -95, 0, 0 }, RAnkle = { 35, 0, 0 }, LHip = { 30, 0, 0 }, LKnee = { -70, 0, 0 }, LAnkle = { 40, 0, 0 } }),
		P(0.42, "s", REST, { Root = { -360, 0, 0 }, RootP = { 0, -0.2, 0 }, Waist = { -8, 0, 0 },
			RShoulder = { 20, 0, 15 }, RElbow = { 30, 0, 0 }, LShoulder = { 20, 0, -15 }, LElbow = { 30, 0, 0 },
			RHip = { 18, 0, 0 }, RKnee = { -35, 0, 0 }, RAnkle = { 17, 0, 0 }, LHip = { 18, 0, 0 }, LKnee = { -35, 0, 0 }, LAnkle = { 17, 0, 0 } }),
	},
}

-- Hit taken: short flinch added on top of whatever plays (no interruption of the attack).
Clips.Shared_Hit = {
	Length = 0.3, Additive = true, Legs = "Upper", FadeIn = 0.01, FadeOut = 0.01,
	Poses = {
		P(0, nil, REST),
		P(0.06, "O", REST, { Root = { 5, 0, 0 }, Waist = { 10, 0, 5 }, Neck = { 12, 0, -6 },
			RShoulder = { -8, 0, 6 }, LShoulder = { -8, 0, -6 } }),
		P(0.3, "s", REST),
	},
}

-- Death: the body topples physically (BreakJointsOnDeath off); the clip staggers, then goes limp and holds.
Clips.Shared_Death = {
	Length = 0.6, Hold = true, Legs = "Own", FadeIn = 0.05, FadeOut = 0.2,
	Poses = {
		P(0, nil, REST_LEGS),
		P(0.1, "O", REST_LEGS, { Waist = { 12, 0, 6 }, Neck = { 18, 0, -10 },
			RShoulder = { 25, 0, 40 }, RElbow = { 20, 0, 0 }, LShoulder = { 25, 0, -45 }, LElbow = { 25, 0, 0 },
			RHip = { 25, 0, 0 }, RKnee = { -35, 0, 0 }, RAnkle = { 10, 0, 0 }, LHip = { 10, 0, 0 }, LKnee = { -20, 0, 0 } }),
		P(0.6, "s", REST_LEGS, { Waist = { -25, 0, 8 }, Neck = { -20, 15, 0 },
			RShoulder = { 60, 0, 70 }, RElbow = { 35, 0, 0 }, LShoulder = { 100, 0, -50 }, LElbow = { 50, 0, 0 },
			RHip = { 45, 0, 0 }, RKnee = { -70, 0, 0 }, RAnkle = { 20, 0, 0 }, LHip = { 15, 0, 0 }, LKnee = { -30, 0, 0 }, LAnkle = { 10, 0, 0 } }),
	},
}

-- Spawn: crouched landing, rises with the arms opening, then fades into the stance.
local SPAWN_LOW: Pose = {
	Root = { -25, 0, 0 }, RootP = { 0, -0.95, 0 }, Waist = { -20, 0, 0 }, Neck = { 25, 0, 0 },
	RShoulder = { 45, 0, 15 }, RElbow = { 20, 0, 0 }, LShoulder = { -15, 0, -40 }, LElbow = { 10, 0, 0 },
	RFoot = { 0.25, 0, -0.35, -10 }, LFoot = { -0.25, 0, 0.4, 20 },
}
Clips.Shared_Spawn = {
	Length = 0.6, Legs = "Own", FadeIn = 0.01, FadeOut = 0.25,
	Poses = {
		P(0, nil, SPAWN_LOW),
		P(0.3, "s", SPAWN_LOW, { RootP = { 0, -0.85, 0 } }),
		P(0.6, "O", REST_FEET, { RootP = { 0, -0.12, 0 }, Waist = { 4, 0, 0 }, Neck = { -4, 0, 0 },
			RShoulder = { 25, 0, 35 }, RElbow = { 15, 0, 0 }, LShoulder = { 25, 0, -35 }, LElbow = { 15, 0, 0 } }),
	},
}

CombatAnimations.Clips = Clips

-- Weapon styles: a clip prefix tried before the category's (Ranged crossbows and guns; tools/WeaponTools WEAPON_GRIPS).
-- Not used while the Tool is a placeholder (Placeholder attribute: every placeholder Ranged is a bow on the bow grip).
CombatAnimations.Styles = {
	tundra_ranged = "RangedCrossbow", hell_ranged = "RangedCrossbow", dead_ranged = "RangedCrossbow",
	jungle_ranged = "RangedGun", abyss_ranged = "RangedGun", mechanical_ranged = "RangedGun",
}
return CombatAnimations
