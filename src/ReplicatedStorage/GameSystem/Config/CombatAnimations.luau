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
		for _, key in ipairs({ "RBlade", "LBlade" }) do
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
return CombatAnimations
