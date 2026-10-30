--!strict
-- Player combat animation clips (docs/weapons_combat_brief.txt 4B, contract in docs/COMBAT_CONTRACTS.md). DATA ONLY.
-- OWNER: the Animation sub-agent. Played on every client by GameClient/Controllers/Combat/Animations (procedural
-- keyframes written to the R15 joints after the default Animator, docs/NIGHT_LOG.md option 2).
--
-- Clip names: <Category>_Idle, <Category>_Run, <Category>_Equip, <Category>_Attack1..N, <Category>_Block,
-- <Category>_BlockHit, Shared_Roll, Shared_Hit, Shared_Death, Shared_Spawn.
-- Combat V3 (docs/COMBAT_CONTRACTS.md section 8): <Category>_JumpAttack (Hit = Config/Combat AirAttacks Impact, the
-- landing for melee; Markers.Dive = where the clip waits while the client still holds the body in the air),
-- <Category>_DashAttack (Hit = DashAttacks Impact), <Category>_Air (upper-body stance while jumping / falling),
-- Shared_Hit2 (a second flinch, picked at random).
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
--     arrow side, heavy heads: the striking side, crossbows: the top, guns: the side).
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

-- Combo clips (Config/WeaponMoves Sword, overhaul 2026-10-30): the Hit marker = the step's Impact (0.10), the next step can
-- start at 0.34. Each swing starts where the last one ended, so the chain flows: right -> left -> low -> high -> down -> spin.
-- Attack 1, RightSlash: cocked behind the right shoulder -> diagonal down across the front -> low left.
Clips.Sword_Attack1 = {
	Length = 0.5, Legs = "Stand", FadeIn = 0.05, FadeOut = 0.1, Markers = { Hit = 0.1 },
	Poses = {
		P(0, nil, SWORD_GUARD, { Root = { 0, -20, 0 }, RootP = { 0, -0.3, 0 }, Waist = { -2, -40, 0 }, Neck = { 6, 45, 0 },
			RHand = { -110, 0.6, 0.85 }, RBlade = { -140, 55 }, LHand = { 15, -0.1, 1.0 },
			RFoot = { 0.15, 0, -0.55, -10 }, LFoot = { -0.15, 0, 0.45, 25 } }),
		P(0.1, "i", SWORD_GUARD, { Root = { 0, 10, 0 }, RootP = { 0, -0.34, -0.05 }, Waist = { -8, 12, 0 }, Neck = { 6, -18, 0 },
			RHand = { -12, -0.1, 1.5 }, RBlade = { 40, -5 }, LHand = { 70, -0.45, 0.6 },
			RFoot = { 0.15, 0, -0.75, -10 }, LFoot = { -0.15, 0, 0.45, 25 } }),
		P(0.19, "O", SWORD_GUARD, { Root = { 0, 25, 0 }, RootP = { 0, -0.36, -0.05 }, Waist = { -10, 35, 0 }, Neck = { 8, -45, 0 },
			RHand = { 75, -0.2, 1.45 }, RBlade = { 110, -5 }, LHand = { 120, -0.4, 0.55 },
			RFoot = { 0.15, 0, -0.75, -10 }, LFoot = { -0.15, 0, 0.45, 25 } }),
		P(0.34, "s", SWORD_GUARD, { Root = { 0, 25, 0 }, RootP = { 0, -0.34, -0.05 }, Waist = { -9, 33, 0 }, Neck = { 8, -43, 0 },
			RHand = { 72, -0.25, 1.4 }, RBlade = { 105, -2 }, LHand = { 115, -0.4, 0.55 },
			RFoot = { 0.15, 0, -0.75, -10 }, LFoot = { -0.15, 0, 0.45, 25 } }),
		P(0.5, "s", SWORD_GUARD),
	},
}

-- Attack 2, LeftSlash: backhand from over the left shoulder, flat across the front, out to the right.
Clips.Sword_Attack2 = {
	Length = 0.5, Legs = "Stand", FadeIn = 0.06, FadeOut = 0.1, Markers = { Hit = 0.1 },
	Poses = {
		P(0, nil, SWORD_GUARD, { Root = { 0, 28, 0 }, RootP = { 0, -0.28, 0 }, Waist = { -4, 35, 0 }, Neck = { 6, -55, 0 },
			RHand = { 75, 0.45, 0.7 }, RBlade = { 150, 50 }, LHand = { 40, -0.7, 0.5 } }),
		P(0.1, "i", SWORD_GUARD, { Root = { 0, 0, 0 }, RootP = { 0, -0.32, -0.05 }, Waist = { -6, -12, 0 }, Neck = { 4, 10, 0 },
			RHand = { 0, -0.05, 1.5 }, RBlade = { -45, 0 }, LHand = { 55, -0.4, 0.9 },
			RFoot = { 0.2, 0, -0.75, -10 } }),
		P(0.19, "O", SWORD_GUARD, { Root = { 0, -15, 0 }, RootP = { 0, -0.34, -0.05 }, Waist = { -8, -35, 0 }, Neck = { 6, 45, 0 },
			RHand = { -95, -0.1, 1.45 }, RBlade = { -115, 5 }, LHand = { 45, -0.3, 0.9 },
			RFoot = { 0.2, 0, -0.75, -10 } }),
		P(0.34, "s", SWORD_GUARD, { Root = { 0, -13, 0 }, RootP = { 0, -0.32, -0.05 }, Waist = { -8, -33, 0 }, Neck = { 6, 43, 0 },
			RHand = { -92, -0.15, 1.4 }, RBlade = { -112, 8 }, LHand = { 45, -0.32, 0.88 },
			RFoot = { 0.2, 0, -0.75, -10 } }),
		P(0.5, "s", SWORD_GUARD),
	},
}

-- Attack 3, RisingSlash: low crouch, the blade rises through the front and ends overhead on the toes.
Clips.Sword_Attack3 = {
	Length = 0.5, Legs = "Stand", FadeIn = 0.06, FadeOut = 0.1, Markers = { Hit = 0.1 },
	Poses = {
		P(0, nil, SWORD_GUARD, { Root = { 0, -10, 0 }, RootP = { 0, -0.45, 0.05 }, Waist = { -24, -12, 0 }, Neck = { 20, 10, 0 },
			RHand = { -30, -0.85, 0.95 }, RBlade = { -20, -5 }, LHand = { 30, -0.3, 1.0 },
			RFoot = { 0.25, 0, -0.6, -15 }, LFoot = { -0.2, 0, 0.5, 25 } }),
		P(0.1, "i", SWORD_GUARD, { Root = { 0, 4, 0 }, RootP = { 0, -0.2, -0.08 }, Waist = { -4, 0, 0 }, Neck = { 6, 0, 0 },
			RHand = { -10, -0.05, 1.35 }, RBlade = { -5, 55 }, LHand = { 70, -0.7, 0.5 },
			RFoot = { 0.25, 0, -0.65, -15 }, LFoot = { -0.2, 0, 0.5, 25 } }),
		P(0.19, "O", SWORD_GUARD, { Root = { 0, 8, 0 }, RootP = { 0, 0.08, -0.08 }, Waist = { 8, 4, 0 }, Neck = { -10, 0, 0 },
			RHand = { -5, 1.05, 0.7 }, RBlade = { 0, 130 }, LHand = { 100, -0.6, 0.5 },
			RFoot = { 0.25, 0, -0.65, -15 }, LFoot = { -0.2, 0, 0.5, 25 } }),
		P(0.34, "s", SWORD_GUARD, { Root = { 0, 8, 0 }, RootP = { 0, -0.02, -0.05 }, Waist = { 6, 4, 0 }, Neck = { -8, 0, 0 },
			RHand = { -8, 0.95, 0.75 }, RBlade = { -2, 120 }, LHand = { 95, -0.6, 0.5 },
			RFoot = { 0.25, 0, -0.65, -15 }, LFoot = { -0.2, 0, 0.5, 25 } }),
		P(0.5, "s", SWORD_GUARD),
	},
}

-- Attack 4, DownCut: from overhead straight down the center line, driving forward onto the front foot.
Clips.Sword_Attack4 = {
	Length = 0.52, Legs = "Stand", FadeIn = 0.06, FadeOut = 0.1, Markers = { Hit = 0.11 },
	Poses = {
		P(0, nil, SWORD_GUARD, { Root = { 0, 8, 0 }, RootP = { 0, 0.02, -0.05 }, Waist = { 8, 4, 0 }, Neck = { -10, 0, 0 },
			RHand = { -6, 1.0, 0.72 }, RBlade = { -2, 125 }, LHand = { 90, -0.6, 0.5 },
			RFoot = { 0.25, 0, -0.65, -15 }, LFoot = { -0.2, 0, 0.5, 25 } }),
		P(0.11, "i", SWORD_GUARD, { Root = { 0, 4, 0 }, RootP = { 0, -0.38, -0.12 }, Waist = { -18, 2, 0 }, Neck = { 14, 0, 0 },
			RHand = { -4, -0.1, 1.5 }, RBlade = { -3, -8 }, LHand = { 70, -0.5, 0.6 },
			RFoot = { 0.2, 0, -0.85, -12 }, LFoot = { -0.2, 0, 0.55, 25 } }),
		P(0.2, "O", SWORD_GUARD, { Root = { 0, 2, 0 }, RootP = { 0, -0.46, -0.14 }, Waist = { -24, 0, 0 }, Neck = { 20, 0, 0 },
			RHand = { -8, -0.62, 1.2 }, RBlade = { -5, -38 }, LHand = { 75, -0.55, 0.6 },
			RFoot = { 0.2, 0, -0.85, -12 }, LFoot = { -0.2, 0, 0.55, 25 } }),
		P(0.36, "s", SWORD_GUARD, { Root = { 0, 2, 0 }, RootP = { 0, -0.42, -0.12 }, Waist = { -22, 0, 0 }, Neck = { 18, 0, 0 },
			RHand = { -10, -0.58, 1.18 }, RBlade = { -6, -34 }, LHand = { 75, -0.55, 0.6 },
			RFoot = { 0.2, 0, -0.85, -12 }, LFoot = { -0.2, 0, 0.55, 25 } }),
		P(0.52, "s", SWORD_GUARD),
	},
}

-- Attack 5, SpinSlash (finisher): a deep twist, a full jumping turn with the blade straight out, heavy landing.
-- The spin poses keep the arm in the torso frame (Torso = true) so the blade turns with the body.
Clips.Sword_Attack5 = {
	Length = 0.78, Legs = "Own", FadeIn = 0.05, FadeOut = 0.1, Markers = { Hit = 0.14 },
	Poses = {
		P(0, nil, SWORD_GUARD, { Root = { 0, -50, 0 }, RootP = { 0, -0.45, 0 }, Waist = { -10, -25, 0 }, Neck = { 8, 55, 0 },
			RHand = { -120, -0.1, 1.2 }, RBlade = { -150, 0 }, LHand = { 20, -0.1, 1.0 },
			RFoot = { 0.3, 0, -0.5, -20 }, LFoot = { -0.25, 0, 0.45, 30 } }),
		P(0.03, "l", SWORD_GUARD, { Torso = true, Root = { 0, -35, 0 }, RootP = { 0, -0.35, 0 }, Waist = { -8, 0, 0 }, Neck = { 0, 0, 0 },
			RHand = { -90, 0.0, 1.45 }, RBlade = { -95, 3 }, LHand = { 80, -0.3, 0.6 },
			RFoot = { 0.3, 0, -0.5, -20 }, LFoot = { -0.25, 0, 0.45, 30 } }),
		P(0.13, "l", SWORD_GUARD, { Torso = true, Root = { 0, 130, 0 }, RootP = { 0, 0.6, 0 }, Waist = { -8, 0, 0 }, Neck = { 0, 0, 0 },
			RHand = { -90, 0.02, 1.45 }, RBlade = { -92, 4 }, LHand = { 85, -0.3, 0.55 },
			RFoot = { 0.25, 0.7, -0.3, -20 }, LFoot = { -0.25, 0.65, 0.3, 30 } }),
		P(0.24, "l", SWORD_GUARD, { Torso = true, Root = { 0, 290, 0 }, RootP = { 0, 0.0, 0 }, Waist = { -10, 4, 0 }, Neck = { 2, -4, 0 },
			RHand = { -95, -0.1, 1.42 }, RBlade = { -100, 0 }, LHand = { 75, -0.25, 0.75 },
			RFoot = { 0.28, 0.1, -0.45, -20 }, LFoot = { -0.28, 0.1, 0.45, 30 } }),
		P(0.3, "O", SWORD_GUARD, { Torso = true, Root = { 0, 330, 0 }, RootP = { 0, -0.5, 0 }, Waist = { -14, 10, 0 }, Neck = { 8, -10, 0 },
			RHand = { -100, -0.25, 1.4 }, RBlade = { -110, -5 }, LHand = { 60, -0.2, 0.9 },
			RFoot = { 0.3, 0, -0.5, -20 }, LFoot = { -0.3, 0, 0.5, 30 } }),
		P(0.5, "s", SWORD_GUARD, { Torso = true, Root = { 0, 345, 0 }, RootP = { 0, -0.45, 0 }, Waist = { -13, 10, 0 }, Neck = { 8, -12, 0 },
			RHand = { -98, -0.25, 1.38 }, RBlade = { -108, -3 }, LHand = { 58, -0.22, 0.88 },
			RFoot = { 0.3, 0, -0.5, -20 }, LFoot = { -0.3, 0, 0.5, 30 } }),
		P(0.78, "s", SWORD_SPIN_END),
	},
}

-- Heavy, HeavyCleave: both hands bring the sword up behind the head and the weight rocks back (Charge: the wind-up waits
-- here while the button is held), then a full diagonal cleave stepping through. The release takes Impact to reach Hit.
Clips.Sword_Heavy = {
	Length = 0.86, Legs = "Stand", FadeIn = 0.08, FadeOut = 0.12, Markers = { Charge = 0.16, Hit = 0.24 },
	Poses = {
		P(0, nil, SWORD_GUARD, { LGrip = { -0.35, 0 } }),
		P(0.16, "o", SWORD_GUARD, { Root = { 6, -28, 0 }, RootP = { 0, -0.36, 0.1 }, Waist = { 8, -32, 0 }, Neck = { -4, 40, 0 },
			RHand = { -30, 1.0, 0.45 }, RBlade = { -40, 140 }, LHand = { 0, 0.9, 0.4 }, LGrip = { -0.35, 1 },
			RFoot = { 0.2, 0, -0.35, -15 }, LFoot = { -0.2, 0, 0.7, 30 } }),
		P(0.24, "i", SWORD_GUARD, { Root = { -8, 18, 0 }, RootP = { 0, -0.5, -0.2 }, Waist = { -18, 22, 0 }, Neck = { 12, -24, 0 },
			RHand = { 8, -0.2, 1.45 }, RBlade = { 22, -20 }, LHand = { 20, -0.2, 1.2 }, LGrip = { -0.35, 1 },
			RFoot = { 0.2, 0, -0.95, -12 }, LFoot = { -0.2, 0, 0.75, 30 } }),
		P(0.38, "O", SWORD_GUARD, { Root = { -10, 32, 0 }, RootP = { 0, -0.56, -0.22 }, Waist = { -22, 32, 0 }, Neck = { 16, -36, 0 },
			RHand = { 62, -0.62, 1.2 }, RBlade = { 95, -32 }, LHand = { 60, -0.6, 1.0 }, LGrip = { -0.35, 0.7 },
			RFoot = { 0.2, 0, -0.95, -12 }, LFoot = { -0.2, 0, 0.75, 30 } }),
		P(0.6, "s", SWORD_GUARD, { Root = { -8, 30, 0 }, RootP = { 0, -0.5, -0.2 }, Waist = { -18, 30, 0 }, Neck = { 14, -34, 0 },
			RHand = { 58, -0.55, 1.18 }, RBlade = { 90, -28 }, LHand = { 70, -0.5, 0.8 }, LGrip = { -0.35, 0 },
			RFoot = { 0.2, 0, -0.9, -12 }, LFoot = { -0.2, 0, 0.7, 30 } }),
		P(0.86, "s", SWORD_GUARD, { LGrip = { -0.35, 0 } }),
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

-- Jump attack, PlungeStrike (combat V3; Impact 0.32 = the landing, Hang 0.10): in the air the legs tuck and the sword
-- goes up over the head in both hands (point up-back, it stands out above the head from the camera behind); the body
-- waits there (Dive) while the client holds it, pitches forward and chops down as it dives, then lands on one knee
-- with the point driven into the ground in front (Hit), and rises back to the guard.
local SWORD_AIR_UP: Pose = {
	Root = { 14, 5, 0 }, RootP = { 0, 0.15, 0 }, Waist = { 10, -5, 0 }, Neck = { -8, -5, 0 },
	RHand = { -12, 0.95, 0.35 }, RBlade = { -5, 140 }, LHand = { 10, 0.85, 0.35 }, LGrip = { -0.35, 1 },
	RFoot = { 0.15, 0.95, -0.35, -10 }, LFoot = { -0.15, 0.75, 0.5, 15 },
}
local SWORD_LAND: Pose = {
	Root = { -15, 10, 0 }, RootP = { 0, -1.15, -0.05 }, Waist = { -20, -10, 0 }, Neck = { 22, 0, 0 },
	RHand = { -35, -0.55, 1.3 }, RBlade = { -25, -32 }, LHand = { 130, -0.35, 0.95 }, LGrip = { -0.35, 0 },
	RFoot = { 0.25, 0, -0.6, -10 }, LFoot = { -0.22, 0.05, 0.9, 20 },
}
Clips.Sword_JumpAttack = {
	Length = 0.85, Legs = "Own", FadeIn = 0.05, FadeOut = 0.15, Markers = { Hit = 0.32, Dive = 0.2 },
	Poses = {
		P(0, nil, SWORD_GUARD, { LGrip = { -0.35, 0 }, RFoot = { 0.12, 0.4, -0.3, -12 }, LFoot = { -0.12, 0.3, 0.4, 25 } }),
		P(0.11, "o", SWORD_AIR_UP),
		P(0.2, "s", SWORD_AIR_UP, { Root = { 18, 5, 0 }, Waist = { 13, -5, 0 }, RBlade = { -5, 150 }, RHand = { -12, 1.0, 0.3 } }),
		P(0.26, "i", SWORD_AIR_UP, { Root = { -28, 5, 0 }, RootP = { 0, 0.1, 0 }, Waist = { -12, -5, 0 }, Neck = { 14, -5, 0 },
			RHand = { -8, 0.45, 1.0 }, RBlade = { -5, 35 }, LHand = { 8, 0.4, 0.95 },
			RFoot = { 0.18, 0.45, -0.3, -10 }, LFoot = { -0.18, 0.55, 0.6, 15 } }),
		P(0.295, "l", SWORD_LAND, { Root = { -32, 8, 0 }, RootP = { 0, -0.2, 0 }, Waist = { -16, -8, 0 }, Neck = { 20, 0, 0 },
			RHand = { -28, -0.15, 1.3 }, RBlade = { -22, -8 }, LHand = { 60, -0.2, 0.9 }, LGrip = { -0.35, 0.3 },
			RFoot = { 0.2, 0.15, -0.4, -10 }, LFoot = { -0.2, 0.3, 0.7, 20 } }),
		P(0.32, "O", SWORD_LAND),
		P(0.52, "s", SWORD_LAND, { RootP = { 0, -1.2, -0.05 }, Waist = { -22, -10, 0 }, RHand = { -35, -0.6, 1.28 }, RBlade = { -25, -34 } }),
		P(0.85, "s", SWORD_GUARD, { LGrip = { -0.35, 0 } }),
	},
}

-- Dash strike, DashSlash (Impact 0.14, the lunge carries the body 6 studs in 0.16 s): out of the roll, low and coiled
-- with the sword trailing behind on the right, a long lunge with a flat slash through the front to the left.
Clips.Sword_DashAttack = {
	Length = 0.8, Legs = "Own", FadeIn = 0.04, FadeOut = 0.15, Markers = { Hit = 0.14 },
	Poses = {
		P(0, nil, SWORD_GUARD, { Root = { -8, -35, 0 }, RootP = { 0, -0.7, 0 }, Waist = { -14, -20, 0 }, Neck = { 10, 45, 0 },
			RHand = { -125, -0.55, 0.9 }, RBlade = { -165, -5 }, LHand = { 40, -0.3, 0.85 },
			RFoot = { 0.25, 0, -0.6, -15 }, LFoot = { -0.25, 0, 0.6, 25 } }),
		P(0.07, "o", SWORD_GUARD, { Root = { -14, -40, 0 }, RootP = { 0, -0.8, -0.15 }, Waist = { -16, -22, 0 }, Neck = { 12, 50, 0 },
			RHand = { -135, -0.5, 0.95 }, RBlade = { -170, 0 }, LHand = { 35, -0.25, 0.95 },
			RFoot = { 0.28, 0, -0.95, -12 }, LFoot = { -0.28, 0.1, 0.9, 25 } }),
		P(0.14, "i", SWORD_GUARD, { Root = { -14, 12, 0 }, RootP = { 0, -0.9, -0.3 }, Waist = { -14, 18, 0 }, Neck = { 12, -25, 0 },
			RHand = { 5, -0.25, 1.55 }, RBlade = { 35, -5 }, LHand = { 125, -0.3, 0.6 },
			RFoot = { 0.3, 0, -1.25, -10 }, LFoot = { -0.3, 0.15, 1.1, 25 } }),
		P(0.25, "O", SWORD_GUARD, { Root = { -10, 38, 0 }, RootP = { 0, -0.88, -0.3 }, Waist = { -12, 32, 0 }, Neck = { 10, -50, 0 },
			RHand = { 80, -0.3, 1.35 }, RBlade = { 125, -10 }, LHand = { 150, -0.3, 0.6 },
			RFoot = { 0.3, 0, -1.25, -10 }, LFoot = { -0.3, 0.1, 1.1, 25 } }),
		P(0.45, "s", SWORD_GUARD, { Root = { -8, 36, 0 }, RootP = { 0, -0.75, -0.25 }, Waist = { -10, 30, 0 }, Neck = { 8, -46, 0 },
			RHand = { 76, -0.35, 1.3 }, RBlade = { 120, -8 }, LHand = { 145, -0.3, 0.6 },
			RFoot = { 0.3, 0, -1.1, -10 }, LFoot = { -0.3, 0, 1.0, 25 } }),
		P(0.8, "s", SWORD_GUARD),
	},
}

-- Airborne stance (jumping / falling, upper body over the default jump legs): arms out for balance, the sword held
-- out to the right.
local SWORD_AIR: Pose = {
	Waist = { 4, 0, 0 }, Neck = { -2, 0, 0 },
	RHand = { -80, -0.15, 0.9 }, RBlade = { -110, 35 },
	LHand = { 75, -0.1, 0.85 },
}
Clips.Sword_Air = {
	Length = 0.8, Loop = true, Legs = "Upper", FadeIn = 0.12, FadeOut = 0.12,
	Poses = { P(0, nil, SWORD_AIR), P(0.4, nil, SWORD_AIR, { RHand = { -80, -0.05, 0.9 }, LHand = { 75, 0.0, 0.85 } }), P(0.8, nil, SWORD_AIR) },
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
-- SPEAR: two hands on the shaft, long reach, forward lunges (4 steps, 1.11 s interval at speed x1)
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

-- Attack 3, Sweep (combat V3; Impact 0.22, a 180 deg arc): coiled far to the right with both hands, the shaft swept
-- flat and low through the front one-handed (the full 8-stud reach), the left arm out for balance, then regrip.
Clips.Spear_Attack3 = {
	Length = 0.95, Legs = "Stand", FadeIn = 0.05, FadeOut = 0.15, Markers = { Hit = 0.22 },
	Poses = {
		P(0, nil, SPEAR_GUARD),
		P(0.11, "o", SPEAR_GUARD, { Root = { 0, -70, 0 }, RootP = { 0, -0.45, 0 }, Waist = { -6, -25, 0 }, Neck = { 6, 70, 0 },
			RHand = { -105, -0.35, 0.75 }, RBlade = { -160, -4 }, LGrip = { 1.2, 1 },
			RFoot = { 0.35, 0, 0.3, -30 }, LFoot = { -0.3, 0, -0.4, 10 } }),
		P(0.22, "i", SPEAR_GUARD, { Root = { 0, -5, 0 }, RootP = { 0, -0.6, -0.05 }, Waist = { -10, 10, 0 }, Neck = { 8, -5, 0 },
			RHand = { -25, -0.4, 1.3 }, RBlade = { 15, -6 }, LGrip = { 1.2, 0 }, LHand = { 150, -0.3, 0.8 },
			RFoot = { 0.35, 0, 0.3, -30 }, LFoot = { -0.3, 0, -0.45, 10 } }),
		P(0.34, "O", SPEAR_GUARD, { Root = { 0, 35, 0 }, RootP = { 0, -0.6, -0.05 }, Waist = { -10, 35, 0 }, Neck = { 8, -45, 0 },
			RHand = { 65, -0.4, 1.25 }, RBlade = { 115, -4 }, LGrip = { 1.2, 0 }, LHand = { 170, -0.3, 0.8 },
			RFoot = { 0.35, 0, 0.3, -30 }, LFoot = { -0.3, 0, -0.45, 10 } }),
		P(0.55, "s", SPEAR_GUARD, { Root = { 0, 32, 0 }, RootP = { 0, -0.55, -0.05 }, Waist = { -9, 32, 0 }, Neck = { 8, -40, 0 },
			RHand = { 60, -0.42, 1.2 }, RBlade = { 110, -2 }, LGrip = { 1.2, 0.2 }, LHand = { 165, -0.3, 0.8 },
			RFoot = { 0.35, 0, 0.3, -30 }, LFoot = { -0.3, 0, -0.45, 10 } }),
		P(0.95, "s", SPEAR_GUARD),
	},
}

-- Attack 4, PiercingLunge (finisher; was Attack 3 before combat V3): deep coil, a long one-handed lunge, the left arm
-- thrown back for balance.
Clips.Spear_Attack4 = {
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

-- Jump attack, DragoonDive (Impact 0.34 = the landing, Hang 0.12): high over the head in both hands, the point aimed
-- down ahead (a diagonal line above the head from behind), legs tucked; it dives point first and lands crouched with
-- the point driven into the ground at the front right, both hands still on the shaft.
local SPEAR_AIR_UP: Pose = {
	Root = { 10, -10, 0 }, RootP = { 0, 0.2, 0 }, Waist = { 8, 0, 0 }, Neck = { -6, 10, 0 },
	RHand = { -20, 1.0, 0.45 }, RBlade = { -5, -50 }, LGrip = { 1.3, 1 },
	RFoot = { 0.15, 1.0, -0.3, -10 }, LFoot = { -0.15, 0.8, 0.45, 15 },
}
local SPEAR_LAND: Pose = {
	Root = { -10, -20, 0 }, RootP = { 0, -1.1, 0 }, Waist = { -15, 0, 0 }, Neck = { 15, 20, 0 },
	RHand = { -30, 0.3, 0.85 }, RBlade = { -22, -76 }, LGrip = { 1.0, 1 },
	RFoot = { 0.25, 0.05, 0.85, -25 }, LFoot = { -0.25, 0, -0.55, 10 },
}
Clips.Spear_JumpAttack = {
	Length = 0.95, Legs = "Own", FadeIn = 0.05, FadeOut = 0.15, Markers = { Hit = 0.34, Dive = 0.22 },
	Poses = {
		P(0, nil, SPEAR_GUARD, { RFoot = { 0.15, 0.4, 0.3, -30 }, LFoot = { -0.1, 0.3, -0.3, 10 } }),
		P(0.12, "o", SPEAR_AIR_UP),
		P(0.22, "s", SPEAR_AIR_UP, { Root = { 14, -10, 0 }, Waist = { 10, 0, 0 }, RHand = { -20, 1.1, 0.4 }, RBlade = { -5, -45 } }),
		P(0.29, "i", SPEAR_AIR_UP, { Root = { -22, -15, 0 }, RootP = { 0, 0.1, 0 }, Waist = { -10, 0, 0 }, Neck = { 12, 15, 0 },
			RHand = { -25, 0.55, 0.7 }, RBlade = { -15, -78 }, LGrip = { 1.1, 1 },
			RFoot = { 0.15, 0.35, 0.3, -20 }, LFoot = { -0.15, 0.5, 0.1, 10 } }),
		P(0.315, "l", SPEAR_LAND, { Root = { -25, -18, 0 }, RootP = { 0, -0.2, 0 }, Waist = { -12, 0, 0 },
			RHand = { -28, 0.4, 0.8 }, RBlade = { -20, -80 }, RFoot = { 0.2, 0.2, 0.6, -25 }, LFoot = { -0.2, 0.15, -0.4, 10 } }),
		P(0.34, "O", SPEAR_LAND),
		P(0.56, "s", SPEAR_LAND, { RootP = { 0, -1.15, 0 }, Waist = { -17, 0, 0 }, RHand = { -30, 0.28, 0.85 } }),
		P(0.95, "s", SPEAR_GUARD),
	},
}

-- Dash strike, ChargeThrust (Impact 0.16, the lunge carries the body 8 studs in 0.18 s): couched low under the arm out
-- of the roll, then a full one-handed extension in a very long lunge, the left arm thrown back.
Clips.Spear_DashAttack = {
	Length = 0.9, Legs = "Own", FadeIn = 0.04, FadeOut = 0.15, Markers = { Hit = 0.16 },
	Poses = {
		P(0, nil, SPEAR_GUARD, { Root = { -10, -35, 0 }, RootP = { 0, -0.65, 0.1 }, Waist = { -10, 0, 0 }, Neck = { 8, 30, 0 },
			RHand = { -85, -0.5, 0.45 }, RBlade = { -3, 5 }, LGrip = { 1.1, 1 },
			RFoot = { 0.2, 0, 0.6, -30 }, LFoot = { -0.15, 0, -0.5, 10 } }),
		P(0.08, "o", SPEAR_GUARD, { Root = { -12, -38, 0 }, RootP = { 0, -0.72, 0.15 }, Waist = { -12, 0, 0 }, Neck = { 10, 32, 0 },
			RHand = { -92, -0.45, 0.35 }, RBlade = { -3, 4 }, LGrip = { 1.0, 1 },
			RFoot = { 0.2, 0, 0.7, -30 }, LFoot = { -0.15, 0, -0.7, 10 } }),
		P(0.16, "i", SPEAR_GUARD, { Root = { -15, -5, 0 }, RootP = { 0, -0.85, -0.45 }, Waist = { -20, 15, 0 }, Neck = { 16, -5, 0 },
			RHand = { -40, -0.1, 1.45 }, RBlade = { 3, 0 }, LGrip = { 1.6, 0 }, LHand = { 155, -0.2, 0.8 },
			RFoot = { 0.2, 0.1, 1.1, -30 }, LFoot = { -0.1, 0, -1.2, 10 } }),
		P(0.32, "O", SPEAR_GUARD, { Root = { -15, -5, 0 }, RootP = { 0, -0.87, -0.45 }, Waist = { -21, 15, 0 }, Neck = { 16, -5, 0 },
			RHand = { -39, -0.08, 1.47 }, RBlade = { 3, 1 }, LGrip = { 1.6, 0 }, LHand = { 158, -0.2, 0.8 },
			RFoot = { 0.2, 0.1, 1.1, -30 }, LFoot = { -0.1, 0, -1.2, 10 } }),
		P(0.5, "s", SPEAR_GUARD, { Root = { -10, -10, 0 }, RootP = { 0, -0.7, -0.35 }, Waist = { -16, 12, 0 }, Neck = { 12, 0, 0 },
			RHand = { -45, -0.2, 1.3 }, RBlade = { 2, 4 }, LGrip = { 1.5, 0.3 }, LHand = { 140, -0.25, 0.8 },
			RFoot = { 0.2, 0.05, 0.95, -30 }, LFoot = { -0.1, 0, -1.0, 10 } }),
		P(0.9, "s", SPEAR_GUARD),
	},
}

-- Airborne stance: the spear held level in both hands, point forward, upper body upright.
local SPEAR_AIR: Pose = {
	Waist = { 4, 0, 0 }, Neck = { -2, 0, 0 },
	RHand = { -60, -0.2, 0.7 }, RBlade = { -5, 28 }, LHand = { 30, -0.1, 0.8 }, LGrip = { 1.1, 1 },
}
Clips.Spear_Air = {
	Length = 0.8, Loop = true, Legs = "Upper", FadeIn = 0.12, FadeOut = 0.12,
	Poses = { P(0, nil, SPEAR_AIR), P(0.4, nil, SPEAR_AIR, { RHand = { -60, -0.12, 0.7 }, RBlade = { -5, 32 } }), P(0.8, nil, SPEAR_AIR) },
}

-- ------------------------------------------------------------------------------------------------
-- HEAVY: two hands, slow and heavy, big anticipation (3 steps, 2.5 s interval)
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

-- Attack 3, GroundBreaker (combat V3 finisher; Impact 0.55, Legs Own): squat with the weapon dragged low behind, a
-- jump with the weapon swung up over the head (arched back at the top), a two-handed slam that drops into a deep
-- squat, then the long heave back to the guard. The jump is the clip's own (RootP), the client only lunges forward.
Clips.Heavy_Attack3 = {
	Length = 1.9, Legs = "Own", FadeIn = 0.08, FadeOut = 0.2, Markers = { Hit = 0.55 },
	Poses = {
		P(0, nil, HEAVY_GUARD),
		P(0.2, "o", HEAVY_GUARD, { Root = { 0, -10, 0 }, RootP = { 0, -0.85, 0.1 }, Waist = { -24, -10, 0 }, Neck = { 18, 10, 0 },
			RHand = { -60, -0.6, 0.6 }, RBlade = { -170, -15 }, RFace = { -170, -105 },
			RFoot = { 0.38, 0, -0.1, -15 }, LFoot = { -0.38, 0, 0.2, 20 } }),
		P(0.38, "o", HEAVY_GUARD, { Root = { 12, 0, 0 }, RootP = { 0, 1.3, 0.1 }, Waist = { 14, 0, 0 }, Neck = { -10, 0, 0 },
			RHand = { -8, 0.95, 0.35 }, RBlade = { 0, 155 }, RFace = { 0, 65 },
			RFoot = { 0.25, 1.55, -0.2, -15 }, LFoot = { -0.25, 1.45, 0.3, 20 } }),
		P(0.47, "s", HEAVY_GUARD, { Root = { 15, 0, 0 }, RootP = { 0, 1.4, 0.05 }, Waist = { 16, 0, 0 }, Neck = { -11, 0, 0 },
			RHand = { -8, 1.0, 0.3 }, RBlade = { 0, 162 }, RFace = { 0, 72 },
			RFoot = { 0.3, 1.45, -0.25, -15 }, LFoot = { -0.3, 1.35, 0.3, 20 } }),
		P(0.55, "i", HEAVY_GUARD, { Root = { -10, 12, 0 }, RootP = { 0, -0.9, -0.15 }, Waist = { -28, -5, 0 }, Neck = { 22, -8, 0 },
			RHand = { -38, 0.05, 1.35 }, RBlade = { -33, -28 }, RFace = { -33, -118 },
			RFoot = { 0.4, 0, -0.3, -15 }, LFoot = { -0.4, 0, 0.3, 20 } }),
		P(0.8, "O", HEAVY_GUARD, { Root = { -10, 12, 0 }, RootP = { 0, -0.95, -0.15 }, Waist = { -30, -5, 0 }, Neck = { 23, -8, 0 },
			RHand = { -38, 0.03, 1.35 }, RBlade = { -33, -30 }, RFace = { -33, -120 },
			RFoot = { 0.4, 0, -0.3, -15 }, LFoot = { -0.4, 0, 0.3, 20 } }),
		P(1.2, "s", HEAVY_GUARD, { Root = { 4, 4, 0 }, RootP = { 0, -0.55, -0.05 }, Waist = { -20, 0, 0 }, Neck = { 14, 0, 0 },
			RHand = { -15, -0.55, 0.95 }, RBlade = { -10, -10 }, RFace = { -10, -100 } }),
		P(1.9, "s", HEAVY_GUARD),
	},
}

-- Jump attack, MeteorSmash (Impact 0.45 = the landing, Hang 0.16): arched far back with the weapon over the head in
-- both hands, legs tucked; the whole body whips forward as it dives and the head crashes into the ground ahead on the
-- landing, deep on one knee.
local HEAVY_AIR_UP: Pose = {
	Root = { 16, 0, 0 }, RootP = { 0, 0.2, 0 }, Waist = { 14, 0, 0 }, Neck = { -10, 0, 0 },
	RHand = { -8, 1.0, 0.3 }, RBlade = { 0, 160 }, RFace = { 0, 70 }, LGrip = { -0.8, 1 },
	RFoot = { 0.25, 0.9, -0.2, -15 }, LFoot = { -0.25, 0.8, 0.35, 20 },
}
local HEAVY_LAND: Pose = {
	Root = { -12, 15, 0 }, RootP = { 0, -1.15, -0.1 }, Waist = { -30, -5, 0 }, Neck = { 25, -10, 0 },
	RHand = { -40, 0.05, 1.35 }, RBlade = { -35, -28 }, RFace = { -35, -118 }, LGrip = { -0.8, 1 },
	RFoot = { 0.35, 0, -0.45, -15 }, LFoot = { -0.3, 0.05, 0.75, 20 },
}
Clips.Heavy_JumpAttack = {
	Length = 1.3, Legs = "Own", FadeIn = 0.06, FadeOut = 0.2, Markers = { Hit = 0.45, Dive = 0.3 },
	Poses = {
		P(0, nil, HEAVY_GUARD, { RFoot = { 0.28, 0.4, -0.2, -15 }, LFoot = { -0.28, 0.3, 0.3, 20 } }),
		P(0.16, "o", HEAVY_AIR_UP),
		P(0.3, "s", HEAVY_AIR_UP, { Root = { 22, 0, 0 }, Waist = { 16, 0, 0 }, RBlade = { 0, 168 }, RFace = { 0, 78 } }),
		P(0.38, "i", HEAVY_AIR_UP, { Root = { -25, 0, 0 }, RootP = { 0, 0.1, 0 }, Waist = { -15, 0, 0 }, Neck = { 12, 0, 0 },
			RHand = { -5, 0.5, 0.9 }, RBlade = { 0, 60 }, RFace = { 0, -30 },
			RFoot = { 0.28, 0.45, -0.3, -15 }, LFoot = { -0.28, 0.55, 0.5, 20 } }),
		P(0.425, "l", HEAVY_LAND, { Root = { -35, 0, 0 }, RootP = { 0, -0.2, 0 }, Waist = { -20, 0, 0 }, Neck = { 18, 0, 0 },
			RHand = { -30, -0.05, 1.2 }, RBlade = { -25, -5 }, RFace = { -25, -95 },
			RFoot = { 0.3, 0.15, -0.4, -15 }, LFoot = { -0.3, 0.3, 0.6, 20 } }),
		P(0.45, "O", HEAVY_LAND),
		P(0.75, "s", HEAVY_LAND, { RootP = { 0, -1.2, -0.1 }, Waist = { -32, -5, 0 }, RHand = { -40, 0.03, 1.35 } }),
		P(1.3, "s", HEAVY_GUARD),
	},
}

-- Dash strike, RushingSmash (Impact 0.30, the lunge carries the body 5 studs in 0.20 s): out of the roll the weapon
-- drags low behind on the right, then a rising diagonal smash through the front up to the left (150 deg arc).
Clips.Heavy_DashAttack = {
	Length = 1.5, Legs = "Own", FadeIn = 0.05, FadeOut = 0.2, Markers = { Hit = 0.3 },
	Poses = {
		P(0, nil, HEAVY_GUARD, { Root = { -12, -30, 0 }, RootP = { 0, -0.6, 0 }, Waist = { -15, -20, 0 }, Neck = { 10, 40, 0 },
			RHand = { -120, -0.5, 0.75 }, RBlade = { -165, -25 }, RFace = { -165, -110 },
			RFoot = { 0.3, 0, -0.5, -15 }, LFoot = { -0.3, 0.1, 0.6, 20 } }),
		P(0.18, "o", HEAVY_GUARD, { Root = { -12, -45, 0 }, RootP = { 0, -0.65, -0.1 }, Waist = { -15, -30, 0 }, Neck = { 10, 55, 0 },
			RHand = { -135, -0.55, 0.8 }, RBlade = { -175, -30 }, RFace = { -175, -115 },
			RFoot = { 0.3, 0, -0.8, -15 }, LFoot = { -0.3, 0.1, 0.8, 20 } }),
		P(0.3, "i", HEAVY_GUARD, { Root = { -5, 15, 0 }, RootP = { 0, -0.55, -0.25 }, Waist = { -6, 20, 0 }, Neck = { 6, -20, 0 },
			RHand = { -10, 0.0, 1.25 }, RBlade = { 15, 15 }, RFace = { 105, 15 },
			RFoot = { 0.3, 0, -1.0, -15 }, LFoot = { -0.3, 0.1, 0.9, 20 } }),
		P(0.45, "O", HEAVY_GUARD, { Root = { 0, 40, 0 }, RootP = { 0, -0.45, -0.25 }, Waist = { 6, 35, 0 }, Neck = { -4, -45, 0 },
			RHand = { 75, 0.6, 0.85 }, RBlade = { 120, 55 }, RFace = { 200, 30 },
			RFoot = { 0.3, 0, -1.0, -15 }, LFoot = { -0.3, 0.05, 0.9, 20 } }),
		P(0.8, "s", HEAVY_GUARD, { Root = { 0, 36, 0 }, RootP = { 0, -0.4, -0.2 }, Waist = { 4, 32, 0 }, Neck = { -2, -40, 0 },
			RHand = { 70, 0.5, 0.85 }, RBlade = { 115, 48 }, RFace = { 195, 25 },
			RFoot = { 0.3, 0, -0.8, -15 }, LFoot = { -0.3, 0, 0.7, 20 } }),
		P(1.5, "s", HEAVY_GUARD, { RFace = { 330, -35 } }),
	},
}

-- Airborne stance: the weapon on the right shoulder, upper body upright.
local HEAVY_AIR: Pose = {
	Waist = { 4, 0, 0 }, Neck = { -2, 0, 0 },
	RHand = { -45, 0.15, 0.4 }, RBlade = { -165, 50 }, RFace = { -165, -40 },
	LHand = { 45, -0.3, 0.8 }, LGrip = { -0.8, 0 },
}
Clips.Heavy_Air = {
	Length = 0.8, Loop = true, Legs = "Upper", FadeIn = 0.12, FadeOut = 0.12,
	Poses = { P(0, nil, HEAVY_AIR), P(0.4, nil, HEAVY_AIR, { RHand = { -45, 0.2, 0.4 }, LHand = { 45, -0.22, 0.8 } }), P(0.8, nil, HEAVY_AIR) },
}

-- ------------------------------------------------------------------------------------------------
-- DAGGER: a pair, one in each hand (WeaponService adds the off-hand copy): very fast, low stance, alternating hands, a spin
-- and a flurry finisher (5 steps + finisher, 0.22 s steps). LBlade = the direction of the left dagger.
-- ------------------------------------------------------------------------------------------------
local DAGGER_GUARD: Pose = {
	Root = { 0, 15, 0 }, RootP = { 0, -0.38, 0 },
	Waist = { -14, -5, 0 }, Neck = { 10, -10, 0 },
	RHand = { -35, -0.65, 0.95 }, RBlade = { -10, 15 },
	LHand = { 35, -0.5, 0.9 }, LBlade = { 12, 15 },
	RFoot = { 0.15, 0, -0.45, -12 }, LFoot = { -0.15, 0, 0.45, 25 },
}
Clips.Dagger_Idle = stance(1.6, DAGGER_GUARD, with(DAGGER_GUARD, { RootP = { 0, -0.43, 0 }, Waist = { -15, -5, 0 },
	RHand = { -35, -0.7, 0.95 }, LHand = { 35, -0.5, 0.85 } }))

local DAGGER_RUN: Pose = {
	Waist = { -18, 0, 0 }, Neck = { 12, 0, 0 },
	RHand = { -60, -0.75, 0.6 }, RBlade = { -170, -15 }, LHand = { 60, -0.75, 0.6 }, LBlade = { 170, -15 },
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

-- Attack 1, CutR: the right dagger, forehand across the front.
Clips.Dagger_Attack1 = {
	Length = 0.3, Legs = "Stand", FadeIn = 0.03, FadeOut = 0.08, Markers = { Hit = 0.08 },
	Poses = {
		P(0, nil, DAGGER_GUARD, { Root = { 0, 0, 0 }, Waist = { -10, -25, 0 }, Neck = { 8, 15, 0 },
			RHand = { -85, -0.3, 0.85 }, RBlade = { -120, 5 } }),
		P(0.08, "i", DAGGER_GUARD, { Root = { 0, 25, 0 }, RootP = { 0, -0.42, -0.1 }, Waist = { -14, 10, 0 }, Neck = { 10, -25, 0 },
			RHand = { -5, -0.4, 1.3 }, RBlade = { 50, -5 }, LHand = { 70, -0.5, 0.65 }, LBlade = { 60, 25 } }),
		P(0.15, "O", DAGGER_GUARD, { Root = { 0, 30, 0 }, RootP = { 0, -0.42, -0.1 }, Waist = { -14, 22, 0 }, Neck = { 10, -35, 0 },
			RHand = { 50, -0.5, 1.1 }, RBlade = { 110, -10 }, LHand = { 85, -0.5, 0.6 }, LBlade = { 95, 25 } }),
		P(0.3, "s", DAGGER_GUARD),
	},
}

-- Attack 2, CutL: the left dagger answers, forehand the other way.
Clips.Dagger_Attack2 = {
	Length = 0.3, Legs = "Stand", FadeIn = 0.04, FadeOut = 0.08, Markers = { Hit = 0.08 },
	Poses = {
		P(0, nil, DAGGER_GUARD, { Root = { 0, 30, 0 }, Waist = { -10, 25, 0 }, Neck = { 8, -20, 0 },
			LHand = { 85, -0.3, 0.85 }, LBlade = { 120, 5 }, RHand = { -70, -0.5, 0.7 } }),
		P(0.08, "i", DAGGER_GUARD, { Root = { 0, 0, 0 }, RootP = { 0, -0.42, -0.1 }, Waist = { -14, -12, 0 }, Neck = { 10, 10, 0 },
			LHand = { 5, -0.4, 1.3 }, LBlade = { -50, -5 }, RHand = { -80, -0.55, 0.6 }, RBlade = { -60, 25 } }),
		P(0.15, "O", DAGGER_GUARD, { Root = { 0, -8, 0 }, RootP = { 0, -0.42, -0.1 }, Waist = { -14, -24, 0 }, Neck = { 10, 22, 0 },
			LHand = { -50, -0.5, 1.1 }, LBlade = { -110, -10 }, RHand = { -90, -0.55, 0.6 }, RBlade = { -95, 25 } }),
		P(0.3, "s", DAGGER_GUARD),
	},
}

-- Attack 3, StabR: a straight stab on the right, the left dagger pulled back.
Clips.Dagger_Attack3 = {
	Length = 0.3, Legs = "Stand", FadeIn = 0.04, FadeOut = 0.08, Markers = { Hit = 0.08 },
	Poses = {
		P(0, nil, DAGGER_GUARD, { RootP = { 0, -0.4, 0.06 }, Waist = { -10, -12, 0 }, RHand = { -60, -0.55, 0.5 }, RBlade = { -15, 5 } }),
		P(0.08, "i", DAGGER_GUARD, { Root = { 0, 25, 0 }, RootP = { 0, -0.45, -0.15 }, Waist = { -18, 10, 0 }, Neck = { 14, -15, 0 },
			RHand = { -50, -0.3, 1.35 }, RBlade = { -25, 0 }, LHand = { 60, -0.5, 0.5 }, LBlade = { 30, 20 }, RFoot = { 0.15, 0, -0.65, -12 } }),
		P(0.16, "O", DAGGER_GUARD, { Root = { 0, 25, 0 }, RootP = { 0, -0.45, -0.15 }, Waist = { -18, 10, 0 }, Neck = { 14, -15, 0 },
			RHand = { -50, -0.3, 1.37 }, RBlade = { -25, 0 }, LHand = { 62, -0.5, 0.5 }, LBlade = { 30, 20 }, RFoot = { 0.15, 0, -0.65, -12 } }),
		P(0.3, "s", DAGGER_GUARD),
	},
}

-- Attack 4, StabL: the mirror stab with the left dagger, stepping through.
Clips.Dagger_Attack4 = {
	Length = 0.3, Legs = "Stand", FadeIn = 0.04, FadeOut = 0.08, Markers = { Hit = 0.08 },
	Poses = {
		P(0, nil, DAGGER_GUARD, { RootP = { 0, -0.4, 0.06 }, Waist = { -10, 12, 0 }, LHand = { 60, -0.55, 0.5 }, LBlade = { 15, 5 } }),
		P(0.08, "i", DAGGER_GUARD, { Root = { 0, -5, 0 }, RootP = { 0, -0.45, -0.15 }, Waist = { -18, -10, 0 }, Neck = { 14, 15, 0 },
			LHand = { 50, -0.3, 1.35 }, LBlade = { 25, 0 }, RHand = { -60, -0.5, 0.5 }, RBlade = { -30, 20 }, LFoot = { -0.15, 0, -0.4, 10 }, RFoot = { 0.15, 0, 0.35, -12 } }),
		P(0.16, "O", DAGGER_GUARD, { Root = { 0, -5, 0 }, RootP = { 0, -0.45, -0.15 }, Waist = { -18, -10, 0 }, Neck = { 14, 15, 0 },
			LHand = { 50, -0.3, 1.37 }, LBlade = { 25, 0 }, RHand = { -62, -0.5, 0.5 }, RBlade = { -30, 20 }, LFoot = { -0.15, 0, -0.4, 10 }, RFoot = { 0.15, 0, 0.35, -12 } }),
		P(0.3, "s", DAGGER_GUARD),
	},
}

-- Attack 5, SpinCut: a full turn with both blades straight out (a small circle around the player).
local DAGGER_SPIN: Pose = {
	Torso = true, RootP = { 0, -0.2, 0 }, Waist = { -8, 0, 0 }, Neck = { 0, 0, 0 },
	RHand = { -90, -0.1, 1.35 }, RBlade = { -92, 0 }, LHand = { 90, -0.1, 1.35 }, LBlade = { 92, 0 },
}
local DAGGER_SPIN_END: Pose = with(DAGGER_GUARD, { Root = { 0, 375, 0 } })
Clips.Dagger_Attack5 = {
	Length = 0.4, Legs = "Own", FadeIn = 0.03, FadeOut = 0.08, Markers = { Hit = 0.08 },
	Poses = {
		P(0, nil, DAGGER_SPIN, { Root = { 0, -30, 0 }, RootP = { 0, -0.42, 0 } }),
		P(0.08, "l", DAGGER_SPIN, { Root = { 0, 120, 0 } }),
		P(0.16, "l", DAGGER_SPIN, { Root = { 0, 260, 0 } }),
		P(0.24, "O", DAGGER_SPIN, { Root = { 0, 375, 0 }, RootP = { 0, -0.4, 0 } }),
		P(0.4, "s", DAGGER_SPIN_END),
	},
}

-- Attack 6, Flurry (finisher): five cuts, hands in turn, ending on a big X. The Hits times = Config/WeaponMoves.
local DAGGER_HIGH: Pose = with(DAGGER_GUARD, { RootP = { 0, -0.42, -0.08 }, Waist = { -12, 0, 0 }, Neck = { 10, 0, 0 },
	RHand = { -45, 0.35, 0.8 }, RBlade = { -50, 50 }, LHand = { 45, 0.35, 0.8 }, LBlade = { 50, 50 } })
Clips.Dagger_Attack6 = {
	Length = 0.74, Legs = "Stand", FadeIn = 0.03, FadeOut = 0.1, Markers = { Hit = 0.08 },
	Poses = {
		P(0, nil, DAGGER_HIGH),
		P(0.08, "i", DAGGER_HIGH, { Root = { 0, 22, 0 }, Waist = { -16, 12, 0 }, RHand = { 20, -0.4, 1.25 }, RBlade = { 60, -25 } }),
		P(0.12, "o", DAGGER_HIGH, { Root = { 0, 12, 0 } }),
		P(0.16, "i", DAGGER_HIGH, { Root = { 0, 4, 0 }, Waist = { -16, -12, 0 }, LHand = { -20, -0.4, 1.25 }, LBlade = { -60, -25 } }),
		P(0.2, "o", DAGGER_HIGH, { Root = { 0, 12, 0 } }),
		P(0.24, "i", DAGGER_HIGH, { Root = { 0, 24, 0 }, Waist = { -14, 14, 0 }, RHand = { 15, -0.1, 1.3 }, RBlade = { 70, 0 } }),
		P(0.28, "o", DAGGER_HIGH, { Root = { 0, 12, 0 } }),
		P(0.32, "i", DAGGER_HIGH, { Root = { 0, 2, 0 }, Waist = { -14, -14, 0 }, LHand = { -15, -0.1, 1.3 }, LBlade = { -70, 0 } }),
		P(0.36, "o", DAGGER_HIGH, { RootP = { 0, -0.3, -0.05 }, RHand = { -55, 0.55, 0.75 }, RBlade = { -60, 65 }, LHand = { 55, 0.55, 0.75 }, LBlade = { 60, 65 } }),
		P(0.4, "i", DAGGER_HIGH, { RootP = { 0, -0.6, -0.15 }, Waist = { -20, 0, 0 }, RHand = { 25, -0.5, 1.3 }, RBlade = { 70, -30 }, LHand = { -25, -0.5, 1.3 }, LBlade = { -70, -30 } }),
		P(0.54, "s", DAGGER_HIGH, { RootP = { 0, -0.58, -0.15 }, Waist = { -18, 0, 0 }, RHand = { 22, -0.5, 1.25 }, RBlade = { 68, -28 }, LHand = { -22, -0.5, 1.25 }, LBlade = { -68, -28 } }),
		P(0.74, "s", DAGGER_GUARD),
	},
}

-- Heavy, CrossRend: both blades drawn far back (Charge), then a lunging stab with both, crossing in front.
Clips.Dagger_Heavy = {
	Length = 0.56, Legs = "Stand", FadeIn = 0.05, FadeOut = 0.1, Markers = { Charge = 0.12, Hit = 0.18 },
	Poses = {
		P(0, nil, DAGGER_GUARD),
		P(0.12, "o", DAGGER_GUARD, { Root = { 0, 15, 0 }, RootP = { 0, -0.55, 0.15 }, Waist = { -20, 0, 0 }, Neck = { 16, 0, 0 },
			RHand = { -100, 0.15, 0.8 }, RBlade = { -150, 30 }, LHand = { 100, 0.15, 0.8 }, LBlade = { 150, 30 },
			RFoot = { 0.2, 0, -0.5, -12 }, LFoot = { -0.2, 0, 0.6, 25 } }),
		P(0.18, "i", DAGGER_GUARD, { Root = { 0, 10, 0 }, RootP = { 0, -0.5, -0.3 }, Waist = { -22, 0, 0 }, Neck = { 18, 0, 0 },
			RHand = { -15, -0.1, 1.45 }, RBlade = { 12, -5 }, LHand = { 15, -0.1, 1.45 }, LBlade = { -12, -5 },
			RFoot = { 0.2, 0, -0.95, -12 }, LFoot = { -0.2, 0, 0.7, 25 } }),
		P(0.3, "O", DAGGER_GUARD, { Root = { 0, 10, 0 }, RootP = { 0, -0.52, -0.3 }, Waist = { -22, 0, 0 }, Neck = { 18, 0, 0 },
			RHand = { 40, -0.4, 1.3 }, RBlade = { 70, -12 }, LHand = { -40, -0.4, 1.3 }, LBlade = { -70, -12 },
			RFoot = { 0.2, 0, -0.95, -12 }, LFoot = { -0.2, 0, 0.7, 25 } }),
		P(0.56, "s", DAGGER_GUARD),
	},
}

-- Skill, BladeStorm (Z): two fast turns with both blades out, cutting all around. The Hits times = Config/WeaponMoves.
Clips.Dagger_Skill = {
	Length = 0.74, Legs = "Own", FadeIn = 0.03, FadeOut = 0.1, Markers = { Hit = 0.08 },
	Poses = {
		P(0, nil, DAGGER_SPIN, { Root = { 0, -30, 0 }, RootP = { 0, -0.45, 0 } }),
		P(0.08, "l", DAGGER_SPIN, { Root = { 0, 90, 0 }, RootP = { 0, 0.1, 0 } }),
		P(0.24, "l", DAGGER_SPIN, { Root = { 0, 360, 0 }, RootP = { 0, 0.3, 0 } }),
		P(0.4, "l", DAGGER_SPIN, { Root = { 0, 630, 0 }, RootP = { 0, 0.05, 0 } }),
		P(0.5, "O", DAGGER_SPIN, { Root = { 0, 735, 0 }, RootP = { 0, -0.4, 0 } }),
		P(0.74, "s", with(DAGGER_GUARD, { Root = { 0, 735, 0 } })),
	},
}

-- Block: arms crossed in front of the face, the two blades crossed.
Clips.Dagger_Block = {
	Length = 0.1, Hold = true, Legs = "Stand", FadeIn = 0.04, FadeOut = 0.1,
	Poses = {
		P(0, nil, DAGGER_GUARD),
		P(0.1, "O", DAGGER_GUARD, { Waist = { -10, 0, 0 }, RHand = { 15, 0.35, 0.75 }, RBlade = { 80, 35 }, LHand = { -15, 0.35, 0.75 }, LBlade = { -80, 35 } }),
	},
}
Clips.Dagger_BlockHit = blockHitClip()

-- Jump attack, ShadowDrop (Impact 0.26 = the landing, Hang 0.06): a tucked front flip (the arms turn with the body),
-- out of it the dagger high over the right shoulder in a reverse grip (blade down), then the drop into a three-point
-- "hero" landing: very low, the blade stabbed down at the front right, the left hand down by the ground. Root keys
-- stay one turn ahead (-360) after the flip so nothing unwinds (the engine wraps the root).
local DAGGER_AIR_UP: Pose = {
	Root = { -350, 5, 0 }, RootP = { 0, 0.25, 0 }, Waist = { 6, 0, 0 }, Neck = { -4, 0, 0 },
	RHand = { -40, 0.75, 0.45 }, RBlade = { -10, -75 }, LHand = { 40, 0.75, 0.45 }, LBlade = { 10, -75 },
	RFoot = { 0.15, 1.05, -0.2, -12 }, LFoot = { -0.15, 0.95, 0.25, 25 },
}
local DAGGER_LAND: Pose = {
	Root = { -375, 10, 0 }, RootP = { 0, -1.35, -0.1 }, Waist = { -25, -5, 0 }, Neck = { 25, 0, 0 },
	RHand = { -75, -0.55, 1.05 }, RBlade = { -65, -80 }, LHand = { 70, -0.9, 0.95 }, LBlade = { 60, -80 },
	RFoot = { 0.3, 0, -0.5, -15 }, LFoot = { -0.3, 0.05, 0.6, 25 },
}
local DAGGER_TUCK: Pose = {
	RootP = { 0, 0.35, 0 }, Waist = { -30, 0, 0 }, Neck = { -20, 0, 0 },
	RHand = { -30, -0.35, 0.55 }, RBlade = { -20, -60 }, LHand = { 30, -0.35, 0.55 }, LBlade = { 20, -60 },
	RFoot = { 0.15, 1.2, -0.45, -12 }, LFoot = { -0.15, 1.2, -0.35, 25 },
}
Clips.Dagger_JumpAttack = {
	Length = 0.62, Legs = "Own", FadeIn = 0.03, FadeOut = 0.12, Markers = { Hit = 0.26, Dive = 0.17 },
	Poses = {
		P(0, nil, DAGGER_GUARD, { RFoot = { 0.15, 0.5, -0.3, -12 }, LFoot = { -0.15, 0.4, 0.3, 25 } }),
		P(0.04, "l", DAGGER_TUCK, { Torso = true, Root = { -90, 0, 0 } }),
		P(0.09, "l", DAGGER_TUCK, { Torso = true, Root = { -210, 0, 0 } }),
		P(0.13, "o", DAGGER_TUCK, { Torso = true, Root = { -320, 0, 0 } }),
		P(0.17, "s", DAGGER_AIR_UP),
		P(0.235, "l", DAGGER_LAND, { Root = { -385, 5, 0 }, RootP = { 0, -0.1, 0 }, Waist = { -10, 0, 0 }, Neck = { 12, 0, 0 },
			RHand = { -30, 0.3, 0.7 }, RBlade = { -10, -82 }, LHand = { 40, -0.4, 0.8 },
			RFoot = { 0.2, 0.25, -0.3, -12 }, LFoot = { -0.2, 0.35, 0.4, 25 } }),
		P(0.26, "O", DAGGER_LAND),
		P(0.42, "s", DAGGER_LAND, { RootP = { 0, -1.3, -0.1 }, Waist = { -24, -5, 0 }, LHand = { 70, -0.85, 0.95 } }),
		P(0.62, "s", DAGGER_GUARD, { Root = { -360, 15, 0 } }),
	},
}

-- Dash strike, ShadowStep (Hit 0.10 and Hit2 0.18 = Config/Combat DashAttacks Hits, the lunge carries the body 6 studs
-- in 0.14 s): very low out of the roll, a forehand slash through to the left, then the backhand back to the right.
Clips.Dagger_DashAttack = {
	Length = 0.55, Legs = "Own", FadeIn = 0.03, FadeOut = 0.1, Markers = { Hit = 0.1, Hit2 = 0.18 },
	Poses = {
		P(0, nil, DAGGER_GUARD, { Root = { -15, -20, 0 }, RootP = { 0, -0.8, 0 }, Waist = { -20, -15, 0 }, Neck = { 15, 20, 0 },
			RHand = { -95, -0.4, 0.9 }, RBlade = { -135, 0 }, LHand = { 80, -0.5, 0.6 },
			RFoot = { 0.25, 0, -0.7, -12 }, LFoot = { -0.25, 0.1, 0.8, 25 } }),
		P(0.1, "i", DAGGER_GUARD, { Root = { -15, 25, 0 }, RootP = { 0, -0.85, -0.2 }, Waist = { -18, 20, 0 }, Neck = { 14, -25, 0 },
			RHand = { 40, -0.3, 1.35 }, RBlade = { 95, -5 }, LHand = { 140, -0.4, 0.6 },
			RFoot = { 0.25, 0, -1.0, -12 }, LFoot = { -0.25, 0.15, 0.95, 25 } }),
		P(0.14, "o", DAGGER_GUARD, { Root = { -15, 30, 0 }, RootP = { 0, -0.85, -0.2 }, Waist = { -16, 24, 0 }, Neck = { 14, -30, 0 },
			RHand = { 60, 0.05, 1.0 }, RBlade = { 115, 20 }, LHand = { 140, -0.4, 0.6 },
			RFoot = { 0.25, 0, -1.0, -12 }, LFoot = { -0.25, 0.15, 0.95, 25 } }),
		P(0.18, "i", DAGGER_GUARD, { Root = { -15, -15, 0 }, RootP = { 0, -0.88, -0.2 }, Waist = { -18, -20, 0 }, Neck = { 14, 20, 0 },
			RHand = { -70, -0.3, 1.35 }, RBlade = { -105, -10 }, LHand = { 60, -0.4, 0.7 },
			RFoot = { 0.25, 0, -1.0, -12 }, LFoot = { -0.25, 0.1, 0.95, 25 } }),
		P(0.27, "O", DAGGER_GUARD, { Root = { -15, -22, 0 }, RootP = { 0, -0.85, -0.2 }, Waist = { -18, -25, 0 }, Neck = { 14, 25, 0 },
			RHand = { -95, -0.35, 1.2 }, RBlade = { -130, -12 }, LHand = { 55, -0.4, 0.7 },
			RFoot = { 0.25, 0, -1.0, -12 }, LFoot = { -0.25, 0.05, 0.95, 25 } }),
		P(0.55, "s", DAGGER_GUARD),
	},
}

-- Airborne stance: arms out low and wide, the dagger trailing behind.
local DAGGER_AIR: Pose = {
	Waist = { 2, 0, 0 }, Neck = { -2, 0, 0 },
	RHand = { -75, -0.2, 0.8 }, RBlade = { -125, -25 }, LHand = { 75, -0.2, 0.8 }, LBlade = { 125, -25 },
}
Clips.Dagger_Air = {
	Length = 0.6, Loop = true, Legs = "Upper", FadeIn = 0.1, FadeOut = 0.1,
	Poses = { P(0, nil, DAGGER_AIR), P(0.3, nil, DAGGER_AIR, { RHand = { -75, -0.1, 0.8 }, LHand = { 75, 0.05, 0.8 } }), P(0.6, nil, DAGGER_AIR) },
}

-- ------------------------------------------------------------------------------------------------
-- RANGED (3 steps, 0.833 s interval; AimPitch: the torso follows the aim up / down)
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

-- Attack 2, QuickShot (combat V3; Hit 0.05): a snap shot with the bow canted flat (it reads as a different shot), the
-- drawing hand flicks back, then the bow comes upright again for the next nock.
Clips.Ranged_Attack2 = {
	Length = 0.62, Legs = "Stand", AimPitch = true, FadeIn = 0.03, FadeOut = 0.15, Markers = { Hit = 0.05 },
	Poses = {
		P(0, nil, BOW_AIM),
		P(0.05, "O", BOW_AIM, { Waist = { -5, 12, -6 }, RHand = { -22, -0.08, 1.2 }, RBlade = { -88, 12 }, LHand = { 95, 0.15, 0.5 } }),
		P(0.16, "O", BOW_AIM, { Waist = { -5, 12, -7 }, RHand = { -22, -0.1, 1.18 }, RBlade = { -90, 14 }, LHand = { 108, 0.1, 0.5 } }),
		P(0.36, "s", BOW_AIM, { LHand = { -15, 0.0, 1.0 } }),
		P(0.62, "s", BOW_AIM),
	},
}

-- Attack 3, PowerShot (finisher; Hit 0.12): braced wide and leaning back, the string pulled far past the ear, then a
-- release that kicks the bow up and rocks the body back a step.
Clips.Ranged_Attack3 = {
	Length = 0.78, Legs = "Stand", AimPitch = true, FadeIn = 0.04, FadeOut = 0.15, Markers = { Hit = 0.12 },
	Poses = {
		P(0, nil, BOW_AIM),
		P(0.1, "o", BOW_AIM, { Root = { 0, 52, 0 }, RootP = { 0, -0.38, 0.05 }, Waist = { 4, 14, 0 }, Neck = { 2, -58, 0 },
			RHand = { -22, 0.0, 1.25 }, RBlade = { -60, 48 }, LHand = { 55, 0.35, 0.45 },
			RFoot = { 0, 0, -0.5, -10 }, LFoot = { 0, 0, 0.5, 10 } }),
		P(0.12, "i", BOW_AIM, { Root = { 6, 50, 0 }, RootP = { 0, -0.36, 0.15 }, Waist = { 6, 14, 0 }, Neck = { 0, -56, 0 },
			RHand = { -22, 0.1, 1.2 }, RBlade = { -62, 56 }, LHand = { 120, 0.3, 0.55 },
			RFoot = { 0, 0, -0.5, -10 }, LFoot = { 0, 0, 0.5, 10 } }),
		P(0.26, "O", BOW_AIM, { Root = { 8, 47, 0 }, RootP = { 0, -0.3, 0.25 }, Waist = { 8, 12, 0 }, Neck = { -2, -52, 0 },
			RHand = { -22, 0.15, 1.15 }, RBlade = { -62, 62 }, LHand = { 132, 0.25, 0.55 },
			RFoot = { 0, 0, -0.45, -10 }, LFoot = { 0, 0, 0.55, 10 } }),
		P(0.48, "s", BOW_AIM, { LHand = { -15, 0.0, 1.0 } }),
		P(0.78, "s", BOW_AIM),
	},
}

-- Jump attack, AirVolley (Hit 0.12, Hang 0.25: the client holds the body still in the air): legs tucked, a draw aimed
-- down (AimPitch leans the torso toward the ground ahead), the release, then a backflip out of it (the arms turn with
-- the body) and the legs reach down for the landing.
local BOW_AIR_DRAW: Pose = with(BOW_AIM, {
	Root = { 12, 45, 0 }, RootP = { 0, 0.2, 0 }, Waist = { 4, 10, 0 },
	RFoot = { 0, 0.95, -0.35, -10 }, LFoot = { 0, 0.85, 0.3, 10 },
})
local BOW_FLIP: Pose = {
	RootP = { 0, 0.35, 0 }, Waist = { -25, 0, 0 }, Neck = { -15, 0, 0 },
	RHand = { -45, -0.2, 0.6 }, RBlade = { -30, 60 }, RFace = { 0, -20 }, LHand = { 40, -0.3, 0.55 },
	RFoot = { 0.12, 1.2, -0.45, -10 }, LFoot = { -0.12, 1.2, -0.35, 10 },
}
Clips.Ranged_JumpAttack = {
	Length = 0.8, Legs = "Own", AimPitch = true, FadeIn = 0.04, FadeOut = 0.15, Markers = { Hit = 0.12 },
	Poses = {
		P(0, nil, BOW_AIM, { RFoot = { 0, 0.5, -0.38, -10 }, LFoot = { 0, 0.4, 0.38, 10 } }),
		P(0.1, "o", BOW_AIR_DRAW, { LHand = { 20, 0.35, 0.35 } }),
		P(0.12, "O", BOW_AIR_DRAW, { LHand = { 110, 0.3, 0.5 }, RBlade = { -62, 50 } }),
		P(0.18, "o", BOW_AIR_DRAW, { LHand = { 120, 0.25, 0.5 }, RBlade = { -62, 52 } }),
		P(0.26, "l", BOW_FLIP, { Torso = true, Root = { 110, 0, 0 } }),
		P(0.34, "l", BOW_FLIP, { Torso = true, Root = { 230, 0, 0 } }),
		P(0.42, "o", BOW_FLIP, { Torso = true, Root = { 340, 0, 0 } }),
		P(0.52, "s", BOW_AIM, { Root = { 365, 45, 0 }, RootP = { 0, -0.05, 0 }, RFoot = { 0, 0.3, -0.4, -10 }, LFoot = { 0, 0.25, 0.4, 10 } }),
		P(0.8, "s", BOW_AIM, { Root = { 360, 45, 0 } }),
	},
}

-- Dash strike, SlideShot (Hit 0.08, no lunge): out of the roll straight into a one-knee shot, then up into the stance.
local BOW_KNEEL: Pose = with(BOW_AIM, {
	RootP = { 0, -1.0, 0 }, Waist = { -4, 10, 0 },
	RFoot = { 0.1, 0, -0.6, -10 }, LFoot = { -0.1, 0.05, 0.85, 10 },
})
Clips.Ranged_DashAttack = {
	Length = 0.7, Legs = "Own", AimPitch = true, FadeIn = 0.03, FadeOut = 0.15, Markers = { Hit = 0.08 },
	Poses = {
		P(0, nil, BOW_KNEEL, { RootP = { 0, -0.9, 0 } }),
		P(0.08, "O", BOW_KNEEL, { RootP = { 0, -1.0, 0.1 }, RHand = { -22, 0.0, 1.15 }, RBlade = { -62, 50 }, LHand = { 110, 0.3, 0.5 } }),
		P(0.2, "O", BOW_KNEEL, { RootP = { 0, -1.0, 0.12 }, LHand = { 120, 0.25, 0.5 } }),
		P(0.42, "s", BOW_KNEEL, { RootP = { 0, -0.6, 0.05 }, LHand = { -15, 0.0, 1.0 } }),
		P(0.7, "s", BOW_AIM),
	},
}

-- Airborne stance: the bow held up and out, the free hand open.
local BOW_AIR: Pose = {
	Waist = { 2, 0, 0 }, Neck = { -2, 0, 0 },
	RHand = { -50, -0.35, 0.75 }, RBlade = { -20, 70 }, RFace = { 0, -20 }, LHand = { 55, -0.2, 0.8 },
}
Clips.Ranged_Air = {
	Length = 0.8, Loop = true, Legs = "Upper", FadeIn = 0.12, FadeOut = 0.12,
	Poses = { P(0, nil, BOW_AIR), P(0.4, nil, BOW_AIR, { RHand = { -50, -0.28, 0.75 }, LHand = { 55, -0.12, 0.8 } }), P(0.8, nil, BOW_AIR) },
}

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
	-- combat V3. Attack 2, QuickShot (Hit 0.05): a hip-level snap shot, small kick.
	Clips[prefix .. "_Attack2"] = {
		Length = 0.55, Legs = "Stand", AimPitch = true, FadeIn = 0.03, FadeOut = 0.15, Markers = { Hit = 0.05 },
		Poses = {
			P(0, nil, aim),
			P(0.05, "O", aim, { Root = { 0, 30, 0 }, RootP = { 0, -0.25, 0.05 }, Waist = { -2, 8, 0 }, Neck = { 2, -32, 0 },
				RHand = { -28, -0.2, 0.6 }, RBlade = { 0, 9 }, LGrip = { 1.4, 1 } }),
			P(0.18, "s", aim, { Root = { 0, 30, 0 }, RootP = { 0, -0.24, 0.02 }, Waist = { -4, 8, 0 },
				RHand = { -28, -0.18, 0.6 }, RBlade = { 0, 2 } }),
			P(0.55, "s", aim),
		},
	}
	-- Attack 3, PowerShot (finisher, Hit 0.12): braced low, a heavy recoil that throws the muzzle up and the body back.
	Clips[prefix .. "_Attack3"] = {
		Length = 0.75, Legs = "Stand", AimPitch = true, FadeIn = 0.04, FadeOut = 0.15, Markers = { Hit = 0.12 },
		Poses = {
			P(0, nil, aim),
			P(0.1, "o", aim, { RootP = { 0, -0.4, -0.05 }, Waist = { -10, 5, 0 }, Neck = { 6, -35, 0 },
				RFoot = { 0.15, 0, -0.5, -15 }, LFoot = { -0.15, 0, 0.5, 20 } }),
			P(0.12, "i", aim, { Root = { 6, 35, 0 }, RootP = { 0, -0.35, 0.2 }, Waist = { 6, 5, 0 }, Neck = { -2, -35, 0 },
				RHand = { -25, 0.12, 0.42 }, RBlade = { 0, 28 }, LGrip = { 1.4, 1 },
				RFoot = { 0.15, 0, -0.5, -15 }, LFoot = { -0.15, 0, 0.5, 20 } }),
			P(0.26, "O", aim, { Root = { 8, 35, 0 }, RootP = { 0, -0.32, 0.3 }, Waist = { 8, 5, 0 }, Neck = { -4, -35, 0 },
				RHand = { -25, 0.15, 0.4 }, RBlade = { 0, 34 }, LGrip = { 1.4, 1 },
				RFoot = { 0.15, 0, -0.45, -15 }, LFoot = { -0.15, 0, 0.55, 20 } }),
			P(0.5, "s", aim, { RootP = { 0, -0.25, 0.1 }, RBlade = { 0, 6 } }),
			P(0.75, "s", aim),
		},
	}
	-- Jump attack, AirVolley (Hit 0.12, hovering): legs tucked, the weapon shouldered and aimed down (AimPitch), a
	-- burst recoil, then a backflip with the weapon held tight and the legs reaching down.
	local airAim: Pose = with(aim, { Root = { 12, 35, 0 }, RootP = { 0, 0.2, 0 }, Waist = { 0, 5, 0 },
		RFoot = { 0.1, 0.95, -0.35, -15 }, LFoot = { -0.1, 0.85, 0.3, 20 } })
	local flip: Pose = {
		RootP = { 0, 0.35, 0 }, Waist = { -25, 0, 0 }, Neck = { -15, 0, 0 },
		RHand = { -25, -0.3, 0.5 }, RBlade = { 0, 40 }, RFace = face, LHand = { 20, -0.3, 0.6 }, LGrip = { 1.3, 1 },
		RFoot = { 0.12, 1.2, -0.45, -15 }, LFoot = { -0.12, 1.2, -0.35, 20 },
	}
	Clips[prefix .. "_JumpAttack"] = {
		Length = 0.8, Legs = "Own", AimPitch = true, FadeIn = 0.04, FadeOut = 0.15, Markers = { Hit = 0.12 },
		Poses = {
			P(0, nil, aim, { RFoot = { 0.1, 0.5, -0.4, -15 }, LFoot = { -0.1, 0.4, 0.4, 20 } }),
			P(0.1, "o", airAim),
			P(0.12, "O", airAim, { Root = { 16, 35, 0 }, RHand = { -25, 0.1, 0.45 }, RBlade = { 0, 16 } }),
			P(0.2, "o", airAim, { Root = { 18, 35, 0 }, RHand = { -25, 0.12, 0.42 }, RBlade = { 0, 20 } }),
			P(0.28, "l", flip, { Torso = true, Root = { 120, 0, 0 } }),
			P(0.36, "l", flip, { Torso = true, Root = { 240, 0, 0 } }),
			P(0.44, "o", flip, { Torso = true, Root = { 345, 0, 0 } }),
			P(0.54, "s", aim, { Root = { 365, 35, 0 }, RootP = { 0, -0.05, 0 }, RFoot = { 0.1, 0.3, -0.4, -15 }, LFoot = { -0.1, 0.25, 0.4, 20 } }),
			P(0.8, "s", aim, { Root = { 360, 35, 0 } }),
		},
	}
	-- Dash strike, SlideShot (Hit 0.08): a one-knee shot out of the roll.
	local kneel: Pose = with(aim, { RootP = { 0, -1.0, 0 }, Waist = { -6, 5, 0 },
		RFoot = { 0.1, 0, -0.6, -15 }, LFoot = { -0.1, 0.05, 0.85, 20 } })
	Clips[prefix .. "_DashAttack"] = {
		Length = 0.7, Legs = "Own", AimPitch = true, FadeIn = 0.03, FadeOut = 0.15, Markers = { Hit = 0.08 },
		Poses = {
			P(0, nil, kneel, { RootP = { 0, -0.9, 0 } }),
			P(0.08, "O", kneel, { RootP = { 0, -1.0, 0.12 }, RHand = { -25, 0.05, 0.45 }, RBlade = { 0, 14 } }),
			P(0.2, "s", kneel, { RootP = { 0, -1.0, 0.08 }, RBlade = { 0, 4 } }),
			P(0.42, "s", kneel, { RootP = { 0, -0.6, 0.03 } }),
			P(0.7, "s", aim),
		},
	}
	-- Airborne stance: the weapon held across the chest.
	local air: Pose = {
		Waist = { 2, 0, 0 }, Neck = { -2, 0, 0 },
		RHand = { -30, -0.3, 0.55 }, RBlade = { -20, -10 }, RFace = face, LHand = { 20, -0.3, 0.8 }, LGrip = { 1.3, 1 },
	}
	Clips[prefix .. "_Air"] = {
		Length = 0.8, Loop = true, Legs = "Upper", FadeIn = 0.12, FadeOut = 0.12,
		Poses = { P(0, nil, air), P(0.4, nil, air, { RHand = { -30, -0.24, 0.55 } }), P(0.8, nil, air) },
	}
end
rifleClips("RangedCrossbow", { 0, 90 }, { 0, 90 })
rifleClips("RangedGun", { 90, 0 }, { 0, 0 })

-- ------------------------------------------------------------------------------------------------
-- MAGIC: a staff in the right hand, readable casting pose (3 steps, 1.0 s interval; AimPitch)
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

-- Attack 2, Cast2 (combat V3; Hit 0.28): the other hand: the staff swings up and back on the right while the left
-- hand gathers at the chest, then the left palm is thrust at the target with a step.
Clips.Magic_Attack2 = {
	Length = 0.9, Legs = "Stand", AimPitch = true, FadeIn = 0.06, FadeOut = 0.15, Markers = { Hit = 0.28 },
	Poses = {
		P(0, nil, STAFF_GUARD),
		P(0.14, "o", STAFF_GUARD, { Root = { 0, -15, 0 }, RootP = { 0, -0.16, 0.03 }, Waist = { 4, -15, 0 }, Neck = { -2, 15, 0 },
			RHand = { -70, 0.35, 0.7 }, RBlade = { -40, 100 }, LHand = { 30, 0.0, 0.35 } }),
		P(0.21, "s", STAFF_GUARD, { Root = { 0, -18, 0 }, RootP = { 0, -0.15, 0.04 }, Waist = { 5, -16, 0 }, Neck = { -3, 17, 0 },
			RHand = { -72, 0.4, 0.7 }, RBlade = { -45, 105 }, LHand = { 32, 0.02, 0.3 } }),
		P(0.28, "i", STAFF_GUARD, { Root = { 0, 25, 0 }, RootP = { 0, -0.32, -0.1 }, Waist = { -10, 20, 0 }, Neck = { 8, -25, 0 },
			RHand = { -100, 0.15, 0.8 }, RBlade = { -120, 60 }, LHand = { 0, 0.12, 1.3 },
			RFoot = { 0.12, 0, -0.35, -12 }, LFoot = { -0.12, 0, 0.45, 20 } }),
		P(0.42, "O", STAFF_GUARD, { Root = { 0, 26, 0 }, RootP = { 0, -0.33, -0.1 }, Waist = { -11, 21, 0 }, Neck = { 8, -26, 0 },
			RHand = { -102, 0.13, 0.8 }, RBlade = { -122, 58 }, LHand = { 0, 0.1, 1.32 },
			RFoot = { 0.12, 0, -0.35, -12 }, LFoot = { -0.12, 0, 0.45, 20 } }),
		P(0.9, "s", STAFF_GUARD),
	},
}

-- Attack 3, GrandCast (finisher; Hit 0.40): both hands lift the staff high over the head (arched back, a beat at the
-- top), then drive it forward and down at the target in a wide stance.
Clips.Magic_Attack3 = {
	Length = 0.98, Legs = "Stand", AimPitch = true, FadeIn = 0.06, FadeOut = 0.15, Markers = { Hit = 0.4 },
	Poses = {
		P(0, nil, STAFF_GUARD, { LGrip = { 1.0, 0 } }),
		P(0.22, "o", STAFF_GUARD, { Root = { 10, 0, 0 }, RootP = { 0, -0.1, 0.05 }, Waist = { 14, 0, 0 }, Neck = { -10, 0, 0 },
			RHand = { -20, 1.0, 0.4 }, RBlade = { 0, 120 }, LGrip = { 1.0, 1 } }),
		P(0.32, "s", STAFF_GUARD, { Root = { 12, 0, 0 }, RootP = { 0, -0.08, 0.06 }, Waist = { 16, 0, 0 }, Neck = { -11, 0, 0 },
			RHand = { -20, 1.05, 0.35 }, RBlade = { 0, 130 }, LGrip = { 1.0, 1 } }),
		P(0.4, "i", STAFF_GUARD, { Root = { -8, 0, 0 }, RootP = { 0, -0.5, -0.15 }, Waist = { -20, 0, 0 }, Neck = { 14, 0, 0 },
			RHand = { -12, 0.0, 1.2 }, RBlade = { 0, 10 }, LGrip = { 1.0, 1 },
			RFoot = { 0.25, 0, -0.55, -12 }, LFoot = { -0.25, 0, 0.45, 20 } }),
		P(0.6, "O", STAFF_GUARD, { Root = { -8, 0, 0 }, RootP = { 0, -0.52, -0.15 }, Waist = { -21, 0, 0 }, Neck = { 14, 0, 0 },
			RHand = { -12, -0.02, 1.2 }, RBlade = { 0, 8 }, LGrip = { 1.0, 1 },
			RFoot = { 0.25, 0, -0.55, -12 }, LFoot = { -0.25, 0, 0.45, 20 } }),
		P(0.98, "s", STAFF_GUARD, { LGrip = { 1.0, 0 } }),
	},
}

-- Jump attack, MeteorDrop (Hit 0.40, Hang 0.30: the client holds the body in the air): levitating with the knees drawn
-- up and the staff raised high (orb up, the left arm open), then both hands drive the staff down at the aim point
-- (AimPitch), and the legs reach down for the fall.
Clips.Magic_JumpAttack = {
	Length = 1.0, Legs = "Own", AimPitch = true, FadeIn = 0.06, FadeOut = 0.15, Markers = { Hit = 0.4 },
	Poses = {
		P(0, nil, STAFF_GUARD, { LGrip = { 1.0, 0 }, RFoot = { 0.12, 0.4, -0.3, -12 }, LFoot = { -0.12, 0.3, 0.35, 20 } }),
		P(0.2, "o", STAFF_GUARD, { Root = { 8, 0, 0 }, RootP = { 0, 0.25, 0 }, Waist = { 10, 0, 0 }, Neck = { -12, 0, 0 },
			RHand = { -15, 1.1, 0.35 }, RBlade = { 0, 95 }, LHand = { 85, 0.3, 0.9 }, LGrip = { 1.0, 0 },
			RFoot = { 0.1, 0.85, 0.45, 0 }, LFoot = { -0.1, 0.75, 0.55, 0 } }),
		P(0.32, "s", STAFF_GUARD, { Root = { 10, 0, 0 }, RootP = { 0, 0.3, 0 }, Waist = { 12, 0, 0 }, Neck = { -14, 0, 0 },
			RHand = { -15, 1.15, 0.3 }, RBlade = { 0, 100 }, LHand = { 88, 0.35, 0.9 }, LGrip = { 1.0, 0 },
			RFoot = { 0.1, 0.9, 0.45, 0 }, LFoot = { -0.1, 0.8, 0.55, 0 } }),
		P(0.4, "i", STAFF_GUARD, { Root = { -10, 10, 0 }, RootP = { 0, 0.15, 0 }, Waist = { -15, -5, 0 }, Neck = { 12, -5, 0 },
			RHand = { -35, -0.05, 1.3 }, RBlade = { -25, -35 }, LHand = { 10, -0.1, 1.0 }, LGrip = { 1.0, 1 },
			RFoot = { 0.1, 0.4, 0.1, 0 }, LFoot = { -0.1, 0.5, 0.3, 0 } }),
		P(0.55, "O", STAFF_GUARD, { Root = { -10, 10, 0 }, RootP = { 0, 0.15, 0 }, Waist = { -16, -5, 0 }, Neck = { 12, -5, 0 },
			RHand = { -35, -0.07, 1.3 }, RBlade = { -25, -37 }, LHand = { 10, -0.1, 1.0 }, LGrip = { 1.0, 1 },
			RFoot = { 0.1, 0.35, 0.1, 0 }, LFoot = { -0.1, 0.45, 0.3, 0 } }),
		P(0.75, "s", STAFF_GUARD, { LGrip = { 1.0, 0.3 }, RFoot = { 0.12, 0.15, -0.3, -12 }, LFoot = { -0.12, 0.1, 0.35, 20 } }),
		P(1.0, "s", STAFF_GUARD, { LGrip = { 1.0, 0 } }),
	},
}

-- Dash strike, BlinkBlast (Hit 0.20, a blast around the caster): out of the roll the staff goes up in both hands, then
-- it is stamped down upright into the ground in a deep wide crouch.
Clips.Magic_DashAttack = {
	Length = 0.85, Legs = "Own", FadeIn = 0.04, FadeOut = 0.15, Markers = { Hit = 0.2 },
	Poses = {
		P(0, nil, STAFF_GUARD, { RootP = { 0, -0.6, 0 }, RHand = { -40, 0.6, 0.7 }, RBlade = { -10, 95 }, LHand = { 40, 0.3, 0.8 }, LGrip = { 1.0, 0 } }),
		P(0.12, "o", STAFF_GUARD, { Root = { 6, 0, 0 }, RootP = { 0, -0.2, 0 }, Waist = { 8, 0, 0 }, Neck = { -6, 0, 0 },
			RHand = { -15, 1.0, 0.5 }, RBlade = { 0, 90 }, LGrip = { 1.0, 1 } }),
		P(0.2, "i", STAFF_GUARD, { Root = { -5, 0, 0 }, RootP = { 0, -1.0, 0 }, Waist = { -18, 0, 0 }, Neck = { 14, 0, 0 },
			RHand = { -20, -0.2, 0.9 }, RBlade = { -5, 88 }, LGrip = { 1.0, 1 },
			RFoot = { 0.4, 0, -0.1, -25 }, LFoot = { -0.4, 0, 0.1, 25 } }),
		P(0.4, "O", STAFF_GUARD, { Root = { -5, 0, 0 }, RootP = { 0, -1.02, 0 }, Waist = { -19, 0, 0 }, Neck = { 14, 0, 0 },
			RHand = { -20, -0.22, 0.9 }, RBlade = { -5, 88 }, LGrip = { 1.0, 1 },
			RFoot = { 0.4, 0, -0.1, -25 }, LFoot = { -0.4, 0, 0.1, 25 } }),
		P(0.85, "s", STAFF_GUARD, { LGrip = { 1.0, 0 } }),
	},
}

-- Airborne stance: the staff held out to the right, the left arm open.
local STAFF_AIR: Pose = {
	Waist = { 4, 0, 0 }, Neck = { -2, 0, 0 },
	RHand = { -60, -0.15, 0.8 }, RBlade = { -25, 70 }, LHand = { 65, 0.0, 0.8 },
}
Clips.Magic_Air = {
	Length = 0.8, Loop = true, Legs = "Upper", FadeIn = 0.12, FadeOut = 0.12,
	Poses = { P(0, nil, STAFF_AIR), P(0.4, nil, STAFF_AIR, { RHand = { -60, -0.08, 0.8 }, LHand = { 65, 0.08, 0.8 } }), P(0.8, nil, STAFF_AIR) },
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
-- combat V3: the tuck stays higher (RootP x0.6) so the rolling body does not sink into the ground
Clips.Shared_Roll = {
	Length = 0.42, Legs = "Own", FadeIn = 0.04, FadeOut = 0.1,
	Poses = {
		P(0, nil, ROLL_TUCK, { Root = { -15, 0, 0 }, RootP = { 0, -0.3, 0 }, Waist = { -25, 0, 0 },
			RHip = { 60, 0, 0 }, RKnee = { -90, 0, 0 }, RAnkle = { 30, 0, 0 }, LHip = { 40, 0, 0 }, LKnee = { -80, 0, 0 }, LAnkle = { 40, 0, 0 } }),
		P(0.04, "l", ROLL_TUCK, { Root = { -60, 0, 0 }, RootP = { 0, -0.63, 0 } }),
		P(0.08, "l", ROLL_TUCK, { Root = { -120, 0, 0 }, RootP = { 0, -0.36, 0 } }),
		P(0.13, "l", ROLL_TUCK, { Root = { -180, 0, 0 }, RootP = { 0, -0.09, 0 } }),
		P(0.18, "l", ROLL_TUCK, { Root = { -240, 0, 0 }, RootP = { 0, -0.3, 0 } }),
		P(0.23, "l", ROLL_TUCK, { Root = { -300, 0, 0 }, RootP = { 0, -0.63, 0 } }),
		P(0.28, "l", ROLL_TUCK, { Root = { -345, 0, 0 }, RootP = { 0, -0.72, 0 },
			RHip = { 90, 0, 0 }, RKnee = { -120, 0, 0 }, LHip = { 70, 0, 0 }, LKnee = { -110, 0, 0 } }),
		P(0.34, "o", ROLL_TUCK, { Root = { -360, 0, 0 }, RootP = { 0, -0.42, 0 }, Waist = { -15, 0, 0 }, Neck = { -5, 0, 0 },
			RShoulder = { 40, 0, 20 }, RElbow = { 50, 0, 0 }, LShoulder = { 40, 0, -20 }, LElbow = { 50, 0, 0 },
			RHip = { 60, 0, 0 }, RKnee = { -95, 0, 0 }, RAnkle = { 35, 0, 0 }, LHip = { 30, 0, 0 }, LKnee = { -70, 0, 0 }, LAnkle = { 40, 0, 0 } }),
		P(0.42, "s", REST, { Root = { -360, 0, 0 }, RootP = { 0, -0.12, 0 }, Waist = { -8, 0, 0 },
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

-- Second hit taken (picked at random with Shared_Hit): the shoulders twist away to the side, the head snaps the other
-- way.
Clips.Shared_Hit2 = {
	Length = 0.32, Additive = true, Legs = "Upper", FadeIn = 0.01, FadeOut = 0.01,
	Poses = {
		P(0, nil, REST),
		P(0.06, "O", REST, { Root = { 3, 0, -4 }, Waist = { 6, -14, -8 }, Neck = { 8, 12, 6 },
			RShoulder = { -12, 0, 10 }, LShoulder = { 10, 0, -6 } }),
		P(0.32, "s", REST),
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

-- ------------------------------------------------------------------------------------------------
-- ZONE FIGHTING STYLES (docs/COMBAT_CONTRACTS.md section 9; the brief of each style: Config/CombatStyles). Every weapon
-- of a zone moves in its zone's style, whatever its category: the engine reshapes the category's clips (no clip per
-- zone). Plains (Squire) has no entry: the clips as authored.
-- ZoneStyles[zoneId] = {
--   Posture   offsets added to every clip of the held category (Shared_ clips excepted): Root / Waist / Neck = { x, y, z }
--             degrees (x < 0 leans forward; the Neck's x > 0 lifts the chin), RootP = { x, y, z } studs (y < 0 crouches),
--             RFoot / LFoot = { x, y, z } studs (stance width / lift), RHand / LHand = { azimuth, height, radius }
--   Guard     offsets of RHand / RBlade / LHand in the idle only: how the style holds the weapon at rest (the attacks
--             start from the clip's own guard); GuardGain = { [category] = factor } (bows and staffs: less)
--   Amp       { torso, arms, legs }: swing size of the attacks around their first pose (the guard): root twist / lean,
--             waist and neck; hand azimuth / height and blade directions; steps and body shift (crouch at half)
--   Follow    multiplier of the torso / arms size just after the Hit (> 1 = overshoot), back to the clip's own size
--             at the end of the clip
--   Windup / Recovery / FinisherWindup   time warp knots { u1, v1, u2, v2, ... }: at the fraction u of the wind-up
--             [0, Hit] (of the recovery [Hit, end]) the clip shows its pose of fraction v (implicit 0 -> 0 and 1 -> 1, so
--             the Hit pose stays exactly at the Hit time); equal v = a held pose, a short u step = a snap, v going back
--             = a hitch. FinisherWindup replaces Windup on combo finishers. Jump attacks keep their wind-up (dive sync).
--   Linear    true: no easing between keys (attacks and idle); IdleStep = seconds: the idle pose jumps in steps
--   IdleRate  speed of the idle loop (breathing)
--   Idle / Attack   waves added to the idle / to every attack: { channel, axis 1..3, amplitude, frequency Hz, phase
--             (turns), bias?, wave? } (degrees for rotations, hand azimuths and blades, studs otherwise); wave nil =
--             sine, "pulse" = a short twitch once per period, a table = steps (amplitude x step value: servo ticks)
--   Finisher / Jump   signature overlay clips layered on combo finishers / jump attacks
-- }
-- Signature overlays (Style_<Zone>_Finisher / Style_<Zone>_Jump): offsets, not poses, timed on the attack clip's own
-- markers: their Hit lines up with the clip's Hit (and their Dive with a jump attack's Dive), the parts before / after
-- are stretched over the clip's wind-up / recovery. Joint channels (Root, Waist, Neck, hips, knees, RWrist ...: degrees)
-- are multiplied on at write time (a Root yaw of 360 = a full spin of the whole body, arms and legs included); Lift =
-- { x, y, z } studs moves the whole body (feet too: leaps) in the root's parent frame; RootP / RFoot / LFoot / RHand /
-- LHand / RBlade / LBlade / LGrip are added to the clip's IK targets (LGrip { 0, -1 } lets go of a two-handed grip).
-- Gain = { [category] = factor } (0 = not on that category); LateOk = true: on a finisher whose wind-up is shorter than
-- 0.15 s (Dagger, Ranged) the whole signature plays in the recovery instead (spins after the strike).
-- ------------------------------------------------------------------------------------------------
-- An overlay: every channel used starts and ends at zero unless the first / last key sets it.
local function overlay(length: number, markers: { [string]: number }, keys: { Pose }, extra: { [string]: any }?): { [string]: any }
	local poses: { Pose } = {}
	if keys[1][1] > 0 then
		table.insert(poses, { 0 })
	end
	for _, key in ipairs(keys) do
		table.insert(poses, key)
	end
	if keys[#keys][1] < length then
		table.insert(poses, { length })
	end
	local first, last = poses[1], poses[#poses]
	for _, key in ipairs(keys) do
		for name in pairs(key) do
			if typeof(name) == "string" then
				if first[name] == nil then
					first[name] = { 0, 0, 0, 0 }
				end
				if last[name] == nil then
					last[name] = { 0, 0, 0, 0 }
				end
			end
		end
	end
	local clip: { [string]: any } = { Length = length, Overlay = true, Legs = "Upper", Markers = markers, Poses = poses }
	for k, v in pairs(extra or {}) do
		clip[k] = v
	end
	return clip
end
-- A key: time, ease, channels (a held pose = the same channels again later).
local function K(t: number, ease: string?, channels: Pose): Pose
	local out = table.clone(channels)
	out[1] = t
	out[2] = ease
	return out
end
local FIN = { Hit = 0.5 } -- finisher overlays: wind-up 0 -> 0.5, recovery 0.5 -> 1
local JUMP = { Dive = 0.35, Hit = 0.6 } -- jump overlays: hang 0 -> 0.35, dive 0.35 -> 0.6 (landing), recovery -> 1

local ZoneStyles: { [string]: { [string]: any } } = {}

-- DESERT, Dune Dancer: flowing and wide, big torso twist, low sweeping steps; the follow-through lingers (the body keeps
-- turning); idle sways like heat haze. Finisher: a whirling full-body spin into the strike. Jump: a corkscrew.
ZoneStyles.Desert = {
	Posture = { RootP = { 0, -0.12, 0 }, Waist = { -2, 0, 0 }, RFoot = { 0.08, 0, 0 }, LFoot = { -0.08, 0, 0.06 }, LHand = { 12, 0.12, 0.15 } },
	Guard = { RHand = { 55, -0.05, 0.05 }, RBlade = { 160, -45 }, LHand = { 50, 0.6, 0.2 } },
	GuardGain = { Ranged = 0.35, Magic = 0.7 },
	Amp = { 1.5, 1.15, 1.3 }, Follow = 1.2,
	Windup = { 0.5, 0.42 }, Recovery = { 0.6, 0.42 },
	IdleRate = 0.8,
	Idle = {
		{ "Waist", 3, 5, 0.3, 0 }, { "Root", 3, -3, 0.3, 0 }, { "Root", 2, 8, 0.15, 0.25 }, { "Neck", 3, -4, 0.3, 0.1 },
		{ "RHand", 1, 6, 0.3, 0 }, { "LHand", 2, 0.1, 0.3, 0.5 }, { "LHand", 1, 10, 0.15, 0 },
	},
	Finisher = "Style_Desert_Finisher", Jump = "Style_Desert_Jump",
}
Clips.Style_Desert_Finisher = overlay(1, FIN, {
	K(0.08, "o", { Root = { 0, -25, 0 }, RootP = { 0, -0.12, 0 }, LHand = { 15, 0.1, 0.1 } }),
	K(0.2, "i", { Root = { 0, 50, 0 }, Waist = { 0, 0, -6 }, LHand = { 35, 0.35, 0.25 } }),
	K(0.42, "l", { Root = { 0, 300, 0 }, Waist = { 0, 0, -8 }, RootP = { 0, -0.18, 0 }, LHand = { 35, 0.35, 0.25 } }),
	K(0.5, "o", { Root = { 0, 360, 0 }, Waist = { 0, 0, 0 }, RootP = { 0, -0.15, 0 }, LHand = { 20, 0.15, 0.15 } }),
	K(0.7, "s", { Root = { 0, 360, 0 }, RootP = { 0, -0.05, 0 }, LHand = { 10, 0.05, 0.05 } }),
	K(1, "s", { Root = { 0, 360, 0 } }),
}, { LateOk = true })
Clips.Style_Desert_Jump = overlay(1, JUMP, {
	K(0.05, "o", { Root = { 0, 20, 8 } }),
	K(0.18, "l", { Root = { 0, 180, 18 }, LHand = { 40, 0.3, 0.2 }, LGrip = { 0, -1 }, RFoot = { 0, -0.4, 0, 0 }, LFoot = { 0, -0.4, 0, 0 } }),
	K(0.33, "l", { Root = { 0, 340, 6 }, LHand = { 40, 0.3, 0.2 }, LGrip = { 0, -1 } }),
	K(0.42, "o", { Root = { 0, 360, 0 }, LHand = { 0, 0, 0 }, LGrip = { 0, 0 }, RFoot = { 0, 0, 0, 0 }, LFoot = { 0, 0, 0, 0 } }),
	K(1, "s", { Root = { 0, 360, 0 } }),
}, { Gain = { Ranged = 0 } })

-- JUNGLE, Feral: a low crouched hunter, leaning in, head forward; fast snappy wind-ups (a quick coil, a tense beat, the
-- snap), quick recoveries back into the crouch; idle prowls. Finisher: a pouncing leap into the strike. Jump: a pounce
-- with the arms spread like claws, landing on all fours.
ZoneStyles.Jungle = {
	Posture = { Root = { -14, 0, 0 }, RootP = { 0, -0.42, 0.05 }, Waist = { -14, 0, 0 }, Neck = { 22, 0, 0 },
		RFoot = { 0.1, 0, -0.05 }, LFoot = { -0.1, 0, 0.15 }, LHand = { 5, -0.12, 0.2 } },
	Guard = { RHand = { 15, -0.15, 0.1 }, RBlade = { 20, -35 }, LHand = { -10, -0.15, 0.25 } },
	GuardGain = { Ranged = 0.35, Magic = 0.7 },
	Amp = { 1.15, 0.95, 1.35 }, Follow = 0.95,
	Windup = { 0.25, 0.5, 0.6, 0.56 }, Recovery = { 0.3, 0.72 },
	Idle = {
		{ "Waist", 3, 4, 0.4, 0 }, { "Root", 2, 6, 0.2, 0 }, { "RootP", 2, 0.05, 0.8, 0 }, { "Neck", 2, 12, 0.25, 0.3 },
		{ "Waist", 1, 2.5, 0.8, 0.1 }, { "RHand", 2, 0.05, 0.4, 0 }, { "LHand", 2, 0.06, 0.4, 0.5 },
	},
	Finisher = "Style_Jungle_Finisher", Jump = "Style_Jungle_Jump",
}
Clips.Style_Jungle_Finisher = overlay(1, FIN, {
	K(0.2, "o", { RootP = { 0, -0.3, 0 }, Lift = { 0, 0, 0.35 }, Waist = { -14, 0, 0 }, Neck = { 12, 0, 0 }, LHand = { 10, -0.2, 0.2 } }),
	K(0.4, "o", { RootP = { 0, 0.05, 0 }, Lift = { 0, 0.85, 0.15 }, Root = { -18, 0, 0 }, Waist = { -6, 0, 0 }, Neck = { 6, 0, 0 },
		RHip = { 40, 0, 0 }, RKnee = { -55, 0, 0 }, LHip = { 55, 0, 0 }, LKnee = { -65, 0, 0 }, LHand = { 30, 0.4, 0.25 } }),
	K(0.5, "i", { RootP = { 0, -0.1, 0 }, Lift = { 0, 0.15, 0 }, Root = { -24, 0, 0 }, Waist = { -10, 0, 0 }, Neck = { 10, 0, 0 },
		RHip = { 15, 0, 0 }, RKnee = { -20, 0, 0 }, LHip = { 20, 0, 0 }, LKnee = { -25, 0, 0 }, LHand = { 20, -0.15, 0.3 } }),
	K(0.6, "O", { RootP = { 0, -0.35, 0 }, Lift = { 0, 0, 0 }, Root = { -8, 0, 0 }, Waist = { -12, 0, 0 }, Neck = { 10, 0, 0 },
		RHip = { 0, 0, 0 }, RKnee = { 0, 0, 0 }, LHip = { 0, 0, 0 }, LKnee = { 0, 0, 0 }, LHand = { 15, -0.3, 0.3 } }),
	K(0.85, "s", { RootP = { 0, -0.15, 0 }, Root = { -2, 0, 0 }, Waist = { -5, 0, 0 }, Neck = { 4, 0, 0 }, LHand = { 5, -0.1, 0.1 } }),
})
Clips.Style_Jungle_Jump = overlay(1, JUMP, {
	K(0.12, "o", { Root = { -10, 0, 0 }, RHip = { -25, 0, 0 }, LHip = { -15, 0, 0 },
		LHand = { 60, 0.35, 0.3 }, RHand = { -30, 0.2, 0.1 }, LGrip = { 0, -1 } }),
	K(0.35, "s", { Root = { -12, 0, 0 }, RHip = { -30, 0, 0 }, LHip = { -20, 0, 0 },
		LHand = { 65, 0.4, 0.3 }, RHand = { -35, 0.25, 0.1 }, LGrip = { 0, -1 } }),
	K(0.5, "i", { Root = { -20, 0, 0 }, Waist = { -10, 0, 0 }, RHip = { -10, 0, 0 }, LHip = { -5, 0, 0 },
		LHand = { 30, -0.1, 0.4 }, RHand = { -15, 0, 0.1 }, LGrip = { 0, -1 } }),
	K(0.6, "O", { Root = { -6, 0, 0 }, Waist = { -26, 0, 0 }, Neck = { 22, 0, 0 }, RootP = { 0, -0.1, 0 },
		RHip = { 0, 0, 0 }, LHip = { 0, 0, 0 }, LHand = { 10, -0.75, 0.45 }, RHand = { 0, -0.1, 0 }, LGrip = { 0, -1 } }),
	K(0.8, "s", { Root = { -4, 0, 0 }, Waist = { -22, 0, 0 }, Neck = { 18, 0, 0 }, RootP = { 0, -0.1, 0 },
		LHand = { 10, -0.7, 0.4 }, LGrip = { 0, -1 } }),
	K(1, "s", { LGrip = { 0, 0 } }),
})

-- TUNDRA, Glacier: heavy and deliberate, a wide low stance, a stiff upper body (small twist); the wind-up snaps to the
-- coil, freezes there, then a hard release; the follow-through stops dead, then a deliberate return; a slow frosty
-- breath. Finisher: a frozen pause at the top, then a crushing release. Jump: a long frozen hang, then a straight drop
-- like an icicle.
ZoneStyles.Tundra = {
	Posture = { RootP = { 0, -0.3, 0 }, Waist = { 3, 0, 0 }, Neck = { -2, 0, 0 }, RFoot = { 0.22, 0, 0 }, LFoot = { -0.22, 0, 0 } },
	Guard = { RHand = { 45, 0.1, 0.1 }, RBlade = { 35, 15 }, LHand = { -20, 0, 0.1 } },
	GuardGain = { Ranged = 0.35, Magic = 0.7 },
	Amp = { 0.75, 1.05, 1.15 }, Follow = 0.9,
	Windup = { 0.22, 0.52, 0.72, 0.56 }, FinisherWindup = { 0.18, 0.55, 0.85, 0.6 }, Recovery = { 0.15, 0.25, 0.5, 0.3 },
	IdleRate = 0.6,
	Idle = { { "RootP", 2, 0.03, 0.22, 0 }, { "Waist", 1, 1.5, 0.22, 0.25 }, { "Neck", 2, 6, 0.08, 0 } },
	Finisher = "Style_Tundra_Finisher", Jump = "Style_Tundra_Jump",
}
Clips.Style_Tundra_Finisher = overlay(1, FIN, {
	K(0.12, "o", { RootP = { 0, 0.08, 0 }, Root = { 6, 0, 0 }, Waist = { 6, 0, 0 }, RHand = { 0, 0.25, 0 }, RBlade = { 0, 15 } }),
	K(0.42, "s", { RootP = { 0, 0.1, 0 }, Root = { 7, 0, 0 }, Waist = { 7, 0, 0 }, RHand = { 0, 0.28, 0 }, RBlade = { 0, 17 } }),
	K(0.5, "i", { RootP = { 0, -0.3, -0.05 }, Root = { -6, 0, 0 }, Waist = { -14, 0, 0 }, RHand = { 0, -0.15, 0.05 }, RBlade = { 0, -15 } }),
	K(0.62, "O", { RootP = { 0, -0.35, -0.05 }, Root = { -7, 0, 0 }, Waist = { -16, 0, 0 }, RHand = { 0, -0.18, 0.05 }, RBlade = { 0, -18 } }),
	K(0.8, "s", { RootP = { 0, -0.3, 0 }, Root = { -6, 0, 0 }, Waist = { -14, 0, 0 } }),
})
Clips.Style_Tundra_Jump = overlay(1, JUMP, {
	K(0.08, "o", { Root = { -14, 0, 0 }, Waist = { -6, 0, 0 }, RFoot = { 0, -0.6, 0.15, 0 }, LFoot = { 0, -0.55, -0.15, 0 } }),
	K(0.35, "s", { Root = { -15, 0, 0 }, Waist = { -6, 0, 0 }, RFoot = { 0, -0.6, 0.15, 0 }, LFoot = { 0, -0.55, -0.15, 0 } }),
	K(0.47, "i", { Root = { 20, 0, 0 }, Waist = { 8, 0, 0 }, RFoot = { 0, -0.5, 0, 0 }, LFoot = { 0, -0.5, 0, 0 } }),
	K(0.6, "O", { Root = { 5, 0, 0 }, Waist = { 0, 0, 0 }, RootP = { 0, -0.1, 0 }, RFoot = { 0, 0, 0, 0 }, LFoot = { 0, 0, 0, 0 } }),
	K(0.8, "s", { Root = { 2, 0, 0 }, RootP = { 0, -0.1, 0 } }),
}, { Gain = { Ranged = 0.6, Magic = 0.6 } })

-- SWAMP, Hexblade: loose and unsettling, hunched and tilted off-balance; off-beat wind-ups (a hitch back before the
-- swing), late lingering follow-throughs; idle rocks like a witch with wrist flicks. Finisher: the weapon twirls in the
-- hand before the hit. Jump: a crooked, off-balance drop with a twist.
ZoneStyles.Swamp = {
	Posture = { Root = { 0, 0, 6 }, RootP = { 0, -0.15, 0 }, Waist = { -16, 0, -6 }, Neck = { 14, 0, 10 },
		RFoot = { 0.05, 0, 0 }, LFoot = { -0.05, 0, 0 }, LHand = { 15, 0.05, 0.15 } },
	Guard = { RHand = { 0, -0.1, -0.1 }, RBlade = { 10, -70 }, LHand = { 10, 0.45, 0.1 } },
	GuardGain = { Ranged = 0.35, Magic = 0.7 },
	Amp = { 0.95, 1.1, 1.0 }, Follow = 1.2,
	Windup = { 0.2, 0.32, 0.38, 0.22 }, Recovery = { 0.4, 0.14 },
	IdleRate = 1.1,
	Idle = {
		{ "Root", 3, 6, 0.45, 0 }, { "Waist", 3, -5, 0.45, 0.15 }, { "Root", 1, 3, 0.225, 0 }, { "Neck", 3, 6, 0.45, 0.3 },
		{ "RBlade", 1, 14, 0.9, 0 }, { "LHand", 1, 10, 0.6, 0 }, { "LHand", 2, 0.06, 0.6, 0.25 },
	},
	Finisher = "Style_Swamp_Finisher", Jump = "Style_Swamp_Jump",
}
Clips.Style_Swamp_Finisher = overlay(1, FIN, {
	K(0.08, "o", { RWrist = { 0, 0, 0 }, Root = { 0, 0, -5 }, Waist = { 0, 0, 8 } }),
	K(0.38, "l", { RWrist = { -360, 0, 0 }, Root = { 0, 0, 4 }, Waist = { 0, 0, -6 }, LHand = { 20, 0.2, 0.25 } }),
	K(0.5, "s", { RWrist = { -360, 0, 0 }, Root = { 0, 0, 0 }, Waist = { 0, 0, 0 }, LHand = { 10, 0.1, 0.1 } }),
	K(0.72, "s", { RWrist = { -360, 0, 0 }, Waist = { 0, 14, 0 }, Neck = { 0, 0, 10 }, LHand = { 25, 0.15, 0.2 } }),
	K(1, "s", { RWrist = { -360, 0, 0 } }),
}, { LateOk = true })
Clips.Style_Swamp_Jump = overlay(1, JUMP, {
	K(0.15, "o", { Root = { 0, -35, 22 }, Waist = { 0, 15, -10 }, LHand = { 50, 0.1, 0.2 }, LGrip = { 0, -1 } }),
	K(0.35, "s", { Root = { 0, -40, 26 }, Waist = { 0, 18, -12 }, LHand = { 55, 0.15, 0.2 }, LGrip = { 0, -1 } }),
	K(0.5, "i", { Root = { 0, 15, -14 }, Waist = { 0, -5, 6 }, LHand = { 30, 0, 0.1 }, LGrip = { 0, -0.5 } }),
	K(0.6, "O", { Root = { 0, 0, 8 }, Waist = { 0, 0, 10 }, RootP = { 0, -0.05, 0 }, LHand = { 0, 0, 0 }, LGrip = { 0, 0 } }),
	K(0.8, "s", { Root = { 0, 0, 4 }, Waist = { 0, 0, 5 } }),
})

-- VOLCANO, Berserker: aggressive, leaning in, big swings with an overshoot after the hit, stomping steps, a heavier lift
-- then a fast smash; idle heaves (heavy breathing, faster loop). Finisher: a roaring two-step charge into an overshooting
-- smash. Jump: a high explosive leap and a meteor-like crash.
ZoneStyles.Volcano = {
	Posture = { Root = { -8, 0, 0 }, RootP = { 0, -0.18, 0 }, Waist = { -6, 0, 0 }, Neck = { 6, 0, 0 },
		RFoot = { 0.12, 0, 0 }, LFoot = { -0.12, 0, 0 }, RHand = { 0, 0.08, 0 }, LHand = { 0, 0.1, 0.05 } },
	Guard = { RHand = { 20, 0.6, -0.35 }, RBlade = { -140, 15 }, LHand = { 0, 0.1, 0.1 } },
	GuardGain = { Ranged = 0.35, Magic = 0.7 },
	Amp = { 1.35, 1.25, 1.3 }, Follow = 1.4,
	Windup = { 0.55, 0.45 },
	IdleRate = 1.5,
	Idle = {
		{ "RootP", 2, 0.07, 0.7, 0 }, { "Waist", 1, 4, 0.7, 0.1 }, { "Neck", 1, -3, 0.7, 0.1 },
		{ "RHand", 2, 0.06, 0.7, 0.1 }, { "LHand", 2, 0.06, 0.7, 0.1 }, { "Root", 2, 4, 0.25, 0 },
	},
	Finisher = "Style_Volcano_Finisher", Jump = "Style_Volcano_Jump",
}
Clips.Style_Volcano_Finisher = overlay(1, FIN, {
	K(0.12, "o", { Root = { 10, 0, 0 }, Neck = { 16, 0, 0 }, Waist = { 8, 0, 0 }, RHand = { 0, 0.35, -0.1 }, RBlade = { 0, 25 },
		LHand = { 30, 0.3, 0.1 }, RHip = { 30, 0, 0 }, RKnee = { -40, 0, 0 }, Lift = { 0, 0.12, 0 } }),
	K(0.24, "i", { Root = { 8, 0, 0 }, Neck = { 14, 0, 0 }, Waist = { 8, 0, 0 }, RHand = { 0, 0.38, -0.1 }, RBlade = { 0, 28 },
		LHand = { 30, 0.3, 0.1 }, RHip = { 0, 0, 0 }, RKnee = { 0, 0, 0 }, Lift = { 0, -0.05, 0 }, RootP = { 0, -0.12, 0 } }),
	K(0.34, "o", { Root = { 6, 0, 0 }, Neck = { 12, 0, 0 }, Waist = { 8, 0, 0 }, RHand = { 0, 0.42, -0.12 }, RBlade = { 0, 30 },
		LHand = { 30, 0.3, 0.1 }, LHip = { 30, 0, 0 }, LKnee = { -40, 0, 0 }, Lift = { 0, 0.12, 0 }, RootP = { 0, 0, 0 } }),
	K(0.45, "i", { Root = { 6, 0, 0 }, Neck = { 10, 0, 0 }, Waist = { 8, 0, 0 }, RHand = { 0, 0.45, -0.15 }, RBlade = { 0, 32 },
		LHand = { 30, 0.3, 0.1 }, LHip = { 0, 0, 0 }, LKnee = { 0, 0, 0 }, Lift = { 0, 0, 0 } }),
	K(0.5, "i", { Root = { -14, 0, 0 }, Neck = { -6, 0, 0 }, Waist = { -12, 0, 0 }, RHand = { 0, -0.2, 0.1 }, RBlade = { 0, -25 },
		LHand = { 10, 0, 0.1 }, RootP = { 0, -0.3, 0 } }),
	K(0.6, "O", { Root = { -22, 0, 0 }, Neck = { -4, 0, 0 }, Waist = { -18, 0, 0 }, RHand = { 0, -0.3, 0.1 }, RBlade = { 0, -35 },
		LHand = { 0, -0.1, 0.1 }, RootP = { 0, -0.4, 0 } }),
	K(0.8, "s", { Root = { -8, 0, 0 }, Waist = { -6, 0, 0 }, RootP = { 0, -0.15, 0 }, RHand = { 0, -0.1, 0 }, RBlade = { 0, -10 } }),
})
Clips.Style_Volcano_Jump = overlay(1, JUMP, {
	K(0.1, "o", { Lift = { 0, 0.6, 0 }, Root = { 16, 0, 0 }, Waist = { 10, 0, 0 }, LHand = { 60, 0.4, 0.2 }, LGrip = { 0, -1 },
		RFoot = { 0.25, -0.3, 0, 0 }, LFoot = { -0.25, -0.3, 0, 0 } }),
	K(0.35, "s", { Lift = { 0, 0.65, 0 }, Root = { 18, 0, 0 }, Waist = { 12, 0, 0 }, LHand = { 65, 0.45, 0.2 }, LGrip = { 0, -1 },
		RFoot = { 0.28, -0.3, 0, 0 }, LFoot = { -0.28, -0.3, 0, 0 } }),
	K(0.48, "i", { Lift = { 0, 0.2, 0 }, Root = { -25, 0, 0 }, Waist = { -12, 0, 0 }, LHand = { 20, 0.2, 0.3 }, LGrip = { 0, -0.5 },
		RFoot = { 0, 0.2, 0, 0 }, LFoot = { 0, 0.2, 0, 0 } }),
	K(0.6, "O", { Lift = { 0, 0, 0 }, Root = { -6, 0, 0 }, Waist = { -16, 0, 0 }, RootP = { 0, -0.2, 0 }, LHand = { 0, -0.3, 0.1 },
		LGrip = { 0, 0 }, RFoot = { 0, 0, 0, 0 }, LFoot = { 0, 0, 0, 0 } }),
	K(0.75, "s", { Root = { -8, 0, 0 }, Waist = { -20, 0, 0 }, RootP = { 0, -0.25, 0 } }),
}, { Gain = { Ranged = 0.5, Magic = 0.7 } })

-- HELL, Demon: brutal and menacing, hunched shoulders, head tilted; a fast brutal wind-up, a heavy savage follow-through
-- (big overshoot) and a slow menacing return; idle looms and twitches. Finisher: a savage spin with a downward rip.
-- Jump: a demonic dive with the arms flung wide, a crater landing.
ZoneStyles.Hell = {
	Posture = { Root = { -6, 0, 0 }, RootP = { 0, -0.22, 0 }, Waist = { -18, 0, 0 }, Neck = { 12, 0, 12 },
		RFoot = { 0.1, 0, 0 }, LFoot = { -0.1, 0, 0 }, RHand = { 0, 0.05, 0 }, LHand = { 5, 0.15, 0.2 } },
	Guard = { RHand = { -40, -0.35, -0.05 }, RBlade = { -110, -70 }, LHand = { -5, 0.3, 0.3 } },
	GuardGain = { Ranged = 0.35, Magic = 0.7 },
	Amp = { 1.25, 1.2, 1.15 }, Follow = 1.5,
	Windup = { 0.45, 0.6 }, Recovery = { 0.25, 0.45, 0.5, 0.55 },
	IdleRate = 0.8,
	Idle = {
		{ "Root", 2, 5, 0.12, 0 }, { "Waist", 3, 3, 0.18, 0 }, { "RootP", 2, 0.04, 0.35, 0 },
		{ "Neck", 2, 18, 0.52, 0, 0, "pulse" }, { "Waist", 3, 6, 0.37, 0.4, 0, "pulse" }, { "LHand", 1, 12, 0.61, 0.2, 0, "pulse" },
	},
	Finisher = "Style_Hell_Finisher", Jump = "Style_Hell_Jump",
}
Clips.Style_Hell_Finisher = overlay(1, FIN, {
	K(0.06, "o", { Root = { 0, 20, 0 }, Waist = { -6, 0, 0 } }),
	K(0.42, "l", { Root = { 0, -330, 0 }, Waist = { -10, 0, 0 }, RHand = { 0, 0.35, 0 }, RBlade = { 0, 30 }, LHand = { -20, 0.3, 0.2 },
		RootP = { 0, -0.1, 0 } }),
	K(0.5, "O", { Root = { -12, -360, 0 }, Waist = { -18, 0, 0 }, Neck = { 10, 0, 12 }, RHand = { 0, -0.25, 0.05 }, RBlade = { 0, -30 },
		LHand = { 0, 0, 0 }, RootP = { 0, -0.3, 0 } }),
	K(0.62, "s", { Root = { -16, -360, 0 }, Waist = { -22, 0, 0 }, Neck = { 10, 0, 12 }, RHand = { 0, -0.3, 0.05 }, RBlade = { 0, -40 },
		RootP = { 0, -0.4, 0 } }),
	K(1, "s", { Root = { 0, -360, 0 } }),
}, { LateOk = true })
Clips.Style_Hell_Jump = overlay(1, JUMP, {
	K(0.12, "o", { LHand = { 95, 0.3, 0.4 }, RHand = { -60, 0.3, 0.2 }, RBlade = { -40, -50 }, LGrip = { 0, -1 }, Root = { -4, 0, 0 },
		Waist = { 2, 0, 0 }, Neck = { 4, 0, 0 } }),
	K(0.35, "s", { LHand = { 100, 0.35, 0.4 }, RHand = { -65, 0.35, 0.2 }, RBlade = { -45, -55 }, LGrip = { 0, -1 }, Root = { -4, 0, 0 },
		Waist = { 3, 0, 0 }, Neck = { 5, 0, 0 } }),
	K(0.5, "i", { LHand = { 95, 0.1, 0.35 }, RHand = { -50, 0.1, 0.15 }, RBlade = { -20, -20 }, LGrip = { 0, -1 }, Root = { -20, 0, 0 },
		Waist = { 0, 0, 0 }, Neck = { 0, 0, 0 } }),
	K(0.6, "O", { LHand = { 30, -0.6, 0.3 }, RHand = { 0, 0, 0 }, LGrip = { 0, -1 }, Root = { -4, 0, 0 }, Waist = { -20, 0, 0 },
		Neck = { 14, 0, 10 }, RootP = { 0, -0.2, 0 } }),
	K(0.85, "s", { LHand = { 20, -0.4, 0.2 }, LGrip = { 0, -0.6 }, Waist = { -14, 0, 0 }, Neck = { 10, 0, 6 }, RootP = { 0, -0.12, 0 } }),
})

-- HEAVEN, Seraph: graceful and upright, chin up, light on the feet; slow-in / fast-out wind-ups and a long graceful
-- settle; idle floats (a soft hover bob, feet off the ground). Finisher: a radiant overhead flourish, the arms opening
-- like wings, before the strike. Jump: a gentle hover with a halo-like pause, then a beam-like vertical strike.
ZoneStyles.Heaven = {
	Posture = { Root = { 3, 0, 0 }, RootP = { 0, 0.08, 0 }, Waist = { 6, 0, 0 }, Neck = { 4, 0, 0 },
		RFoot = { 0, 0.08, 0 }, LFoot = { 0, 0.08, 0 }, LHand = { 15, 0.15, 0.1 } },
	Guard = { RHand = { 45, 0.35, -0.15 }, RBlade = { 35, 50 }, LHand = { 70, 0.35, 0.3 } },
	GuardGain = { Ranged = 0.35, Magic = 0.7 },
	Amp = { 1.0, 1.2, 0.8 }, Follow = 1.1,
	Windup = { 0.5, 0.28, 0.8, 0.62 }, Recovery = { 0.25, 0.4, 0.6, 0.8 },
	IdleRate = 0.8,
	Idle = {
		{ "RootP", 2, 0.07, 0.4, 0, 0.22 }, { "RFoot", 2, 0.07, 0.4, 0, 0.22 }, { "LFoot", 2, 0.07, 0.4, 0.03, 0.24 },
		{ "LHand", 2, 0.06, 0.4, 0.15 }, { "RHand", 2, 0.04, 0.4, 0.15 }, { "Waist", 1, 2, 0.4, 0.2 },
	},
	Finisher = "Style_Heaven_Finisher", Jump = "Style_Heaven_Jump",
}
Clips.Style_Heaven_Finisher = overlay(1, FIN, {
	K(0.08, "o", { Lift = { 0, 0.05, 0 } }),
	K(0.3, "o", { RHand = { -25, 0.6, -0.1 }, RBlade = { 0, 45 }, LHand = { 60, 0.7, 0.25 }, LGrip = { 0, -1 }, Root = { 6, 0, 0 },
		Waist = { 8, 0, 0 }, Neck = { 12, 0, 0 }, Lift = { 0, 0.25, 0 } }),
	K(0.42, "s", { RHand = { -28, 0.65, -0.1 }, RBlade = { 0, 48 }, LHand = { 65, 0.75, 0.25 }, LGrip = { 0, -1 }, Root = { 7, 0, 0 },
		Waist = { 9, 0, 0 }, Neck = { 13, 0, 0 }, Lift = { 0, 0.28, 0 } }),
	K(0.5, "i", { RHand = { 0, 0, 0 }, RBlade = { 0, 0 }, LHand = { 20, 0.2, 0.15 }, LGrip = { 0, -0.6 }, Root = { 0, 0, 0 },
		Waist = { 0, 0, 0 }, Neck = { 0, 0, 0 }, Lift = { 0, 0.05, 0 } }),
	K(0.65, "O", { LHand = { 35, 0.25, 0.2 }, LGrip = { 0, -0.5 }, Lift = { 0, 0, 0 } }),
	K(1, "s", { LGrip = { 0, 0 } }),
})
Clips.Style_Heaven_Jump = overlay(1, JUMP, {
	K(0.12, "o", { Root = { -12, 0, 0 }, RFoot = { 0, -0.55, 0, 0 }, LFoot = { 0, -0.6, 0, 0 }, LHand = { 75, 0.35, 0.3 },
		RHand = { -35, 0.2, 0.1 }, LGrip = { 0, -1 }, Neck = { 12, 0, 0 }, Lift = { 0, 0.3, 0 } }),
	K(0.35, "s", { Root = { -13, 0, 0 }, RFoot = { 0, -0.55, 0, 0 }, LFoot = { 0, -0.6, 0, 0 }, LHand = { 80, 0.4, 0.3 },
		RHand = { -38, 0.22, 0.1 }, LGrip = { 0, -1 }, Neck = { 13, 0, 0 }, Lift = { 0, 0.32, 0 } }),
	K(0.5, "i", { Root = { 15, 0, 0 }, RFoot = { 0, -0.4, 0, 0 }, LFoot = { 0, -0.4, 0, 0 }, LHand = { 0, 0.1, 0 },
		RHand = { 0, 0, 0 }, LGrip = { 0, 0 }, Neck = { 0, 0, 0 }, Lift = { 0, 0.1, 0 } }),
	K(0.6, "O", { Root = { 0, 0, 0 }, RFoot = { 0, 0, 0, 0 }, LFoot = { 0, 0, 0, 0 }, Lift = { 0, 0, 0 }, RootP = { 0, 0.3, 0 },
		Waist = { 6, 0, 0 } }),
}, { Gain = { Ranged = 0.6 } })

-- DEAD, Revenant: ghostly, hunched with the head lolling, arms hanging; stuttering strikes (held frames, sudden snaps)
-- in the wind-up and the recovery; a slow drifting idle with a twitch. Finisher: a stutter-step teleport-like lunge.
-- Jump: a slow ghostly drift, then a sudden fall.
ZoneStyles.Dead = {
	Posture = { Root = { -4, 0, 0 }, RootP = { 0, -0.1, 0 }, Waist = { -12, 0, 0 }, Neck = { -4, 0, 16 },
		RHand = { 0, -0.12, -0.05 }, LHand = { -10, -0.2, -0.1 } },
	Guard = { RHand = { 0, -0.35, -0.2 }, RBlade = { 0, -75 }, LHand = { -5, -0.25, -0.15 } },
	GuardGain = { Ranged = 0.35, Magic = 0.7 },
	Amp = { 0.9, 1.05, 0.9 }, Follow = 1.0,
	Windup = { 0.26, 0.04, 0.3, 0.42, 0.56, 0.46, 0.6, 0.82, 0.88, 0.85 },
	Recovery = { 0.06, 0.3, 0.3, 0.33, 0.35, 0.66, 0.62, 0.7, 0.68, 1 },
	IdleRate = 0.5,
	Idle = {
		{ "Root", 2, 9, 0.1, 0 }, { "RootP", 1, 0.12, 0.1, 0.25 }, { "Neck", 3, 12, 0.17, 0 }, { "Root", 3, 3, 0.14, 0.3 },
		{ "RootP", 2, 0.04, 0.2, 0, 0.06 }, { "RFoot", 2, 0.04, 0.2, 0, 0.06 }, { "LFoot", 2, 0.04, 0.2, 0, 0.06 },
		{ "LHand", 2, 0.05, 0.2, 0.4 }, { "Neck", 1, 10, 0.43, 0, 0, "pulse" },
	},
	Finisher = "Style_Dead_Finisher", Jump = "Style_Dead_Jump",
}
Clips.Style_Dead_Finisher = overlay(1, FIN, {
	K(0.25, "o", { Lift = { 0, 0.05, 0.5 }, Neck = { 0, 0, 20 }, Waist = { -8, 0, 0 }, LHand = { 0, -0.2, -0.1 } }),
	K(0.3, "l", { Lift = { 0, 0.05, 0.5 }, Neck = { 0, 0, 20 }, Waist = { -8, 0, 0 }, LHand = { 0, -0.2, -0.1 } }),
	K(0.32, "l", { Lift = { 0, 0, 0.1 }, Neck = { 0, 0, -10 }, Waist = { -10, 0, 0 }, LHand = { 20, 0, 0 } }),
	K(0.4, "l", { Lift = { 0, 0, 0.1 }, Neck = { 0, 0, -10 }, Waist = { -10, 0, 0 }, LHand = { 20, 0, 0 } }),
	K(0.42, "l", { Lift = { 0, 0, -0.35 }, Neck = { 6, 0, 8 }, Root = { -10, 0, 0 }, Waist = { -10, 0, 0 }, LHand = { 40, 0.2, 0.3 } }),
	K(0.5, "l", { Lift = { 0, 0, -0.4 }, Neck = { 6, 0, 8 }, Root = { -12, 0, 0 }, Waist = { -10, 0, 0 }, LHand = { 40, 0.2, 0.3 } }),
	K(0.7, "s", { Lift = { 0, 0, -0.4 }, Neck = { 0, 0, 14 }, Root = { -6, 0, 0 }, Waist = { -6, 0, 0 }, LHand = { 10, -0.1, 0 } }),
})
Clips.Style_Dead_Jump = overlay(1, JUMP, {
	K(0.15, "o", { Root = { 0, 15, 12 }, Neck = { 10, 0, 25 }, LHand = { 20, -0.3, -0.1 }, LGrip = { 0, -1 },
		RFoot = { 0, -0.4, 0, 0 }, LFoot = { 0, -0.45, 0, 0 } }),
	K(0.35, "s", { Root = { 0, -10, -8 }, Neck = { 10, 0, -15 }, LHand = { 25, -0.35, -0.1 }, LGrip = { 0, -1 },
		RFoot = { 0, -0.45, 0, 0 }, LFoot = { 0, -0.4, 0, 0 } }),
	K(0.4, "l", { Root = { -15, 0, 0 }, Neck = { -15, 0, 0 }, LHand = { 40, 0.4, 0.2 }, LGrip = { 0, -1 },
		RFoot = { 0, 0, 0, 0 }, LFoot = { 0, 0, 0, 0 } }),
	K(0.6, "O", { Root = { 0, 0, 0 }, Waist = { -18, 0, 0 }, Neck = { 15, 0, -20 }, RootP = { 0, -0.1, 0 }, LHand = { 20, -0.4, 0 }, LGrip = { 0, -1 } }),
	K(0.8, "l", { Waist = { -18, 0, 0 }, Neck = { 15, 0, -20 }, RootP = { 0, -0.1, 0 }, LHand = { 20, -0.4, 0 }, LGrip = { 0, -1 } }),
	K(0.84, "l", { Waist = { -8, 0, 0 }, Neck = { 0, 0, 10 }, RootP = { 0, -0.05, 0 }, LHand = { 0, -0.1, 0 }, LGrip = { 0, -0.3 } }),
}, { Gain = { Ranged = 0.6 } })

-- ABYSS, Tidecaller: fluid like water, smooth even wind-ups, follow-throughs that carry on, a rolling wave through the
-- torso during every attack; idle drifts like seaweed. Finisher: a rolling wave from the feet up to the blade. Jump: a
-- dive like a breaching whale (arched, then head first), a splash landing with the arms flung out.
ZoneStyles.Abyss = {
	Posture = { RootP = { 0, -0.12, 0 }, Waist = { -4, 0, 0 }, LHand = { 20, 0, 0.1 } },
	Guard = { RHand = { -15, 0.1, 0.1 }, RBlade = { -55, -25 }, LHand = { 40, 0.15, 0.2 } },
	GuardGain = { Ranged = 0.35, Magic = 0.7 },
	Amp = { 1.2, 1.15, 1.1 }, Follow = 1.25,
	Windup = { 0.5, 0.44 }, Recovery = { 0.5, 0.36 },
	Attack = { { "Root", 3, 4, 1.4, 0 }, { "Waist", 3, -5, 1.4, 0.15 }, { "Neck", 3, 4, 1.4, 0.3 }, { "Waist", 1, 3, 1.4, 0.1 } },
	IdleRate = 0.7,
	Idle = {
		{ "Waist", 3, 5, 0.28, 0 }, { "Neck", 3, 4, 0.28, 0.12 }, { "Root", 3, -2.5, 0.28, -0.12 }, { "RHand", 1, 7, 0.28, 0.2 },
		{ "LHand", 1, 9, 0.28, 0.3 }, { "LHand", 2, 0.06, 0.28, 0.4 }, { "Waist", 1, 2, 0.14, 0 },
	},
	Finisher = "Style_Abyss_Finisher", Jump = "Style_Abyss_Jump",
}
Clips.Style_Abyss_Finisher = overlay(1, FIN, {
	K(0.1, "s", { RootP = { 0, -0.25, 0 }, Root = { -6, 0, 4 } }),
	K(0.2, "s", { RootP = { 0, 0.08, 0 }, Root = { 8, 0, -4 }, Waist = { -12, 0, 6 } }),
	K(0.3, "s", { RootP = { 0, -0.05, 0 }, Root = { -4, 0, 2 }, Waist = { 10, 0, -6 }, Neck = { -10, 0, 4 }, RHand = { 0, -0.15, 0 } }),
	K(0.4, "s", { RootP = { 0, 0, 0 }, Root = { 0, 0, 0 }, Waist = { -6, 0, 0 }, Neck = { 10, 0, -4 }, RHand = { 0, 0.35, 0 }, RBlade = { 0, 25 },
		LHand = { 40, 0.2, 0.2 } }),
	K(0.5, "i", { RootP = { 0, -0.1, 0 }, Waist = { 0, 0, 0 }, Neck = { 0, 0, 0 }, RHand = { 0, -0.1, 0.1 }, RBlade = { 0, -15 },
		LHand = { 60, 0.1, 0.25 } }),
	K(0.65, "s", { RootP = { 0, -0.15, 0 }, Waist = { -8, 0, 4 }, Root = { 4, 0, -4 }, RHand = { 0, 0, 0 }, RBlade = { 0, 0 }, LHand = { 50, 0, 0.2 } }),
	K(0.8, "s", { RootP = { 0, -0.05, 0 }, Waist = { 6, 0, -4 }, Neck = { -6, 0, 4 }, Root = { -2, 0, 3 }, LHand = { 30, 0, 0.1 } }),
})
Clips.Style_Abyss_Jump = overlay(1, JUMP, {
	K(0.15, "o", { Root = { 22, 0, 0 }, Waist = { 14, 0, 0 }, Neck = { 14, 0, 0 }, LHand = { 150, 0.2, 0.3 }, LGrip = { 0, -1 },
		RFoot = { 0, -0.3, 0.3, 0 }, LFoot = { 0, -0.3, 0.3, 0 } }),
	K(0.35, "s", { Root = { 26, 0, 0 }, Waist = { 16, 0, 0 }, Neck = { 15, 0, 0 }, LHand = { 155, 0.2, 0.3 }, LGrip = { 0, -1 },
		RFoot = { 0, -0.3, 0.35, 0 }, LFoot = { 0, -0.3, 0.35, 0 } }),
	K(0.5, "i", { Root = { -30, 0, 0 }, Waist = { -10, 0, 0 }, Neck = { 0, 0, 0 }, LHand = { 20, 0.3, 0.4 }, LGrip = { 0, -0.5 },
		RFoot = { 0, 0, 0, 0 }, LFoot = { 0, 0, 0, 0 } }),
	K(0.6, "O", { Root = { 0, 0, 0 }, Waist = { -12, 0, 0 }, RootP = { 0, -0.1, 0 }, LHand = { 90, -0.1, 0.4 }, LGrip = { 0, -1 } }),
	K(0.8, "s", { Waist = { -6, 0, 0 }, LHand = { 60, -0.2, 0.3 }, LGrip = { 0, -0.6 } }),
	K(1, "s", { LGrip = { 0, 0 } }),
}, { Gain = { Ranged = 0.6 } })

-- MECHANICAL, Automaton: robotic and precise, upright and stiff; linear moves between held poses (a ratchet wind-up in
-- three clicks, a snap strike, a stepped return); idle ticks like servos. Finisher: a ratchet wind-up in clicks and a
-- piston release. Jump: a rigid locked pose in the air, a piston-straight drop.
ZoneStyles.Mechanical = {
	Posture = { Root = { 2, 0, 0 }, RootP = { 0, -0.04, 0 }, Waist = { 4, 0, 0 }, Neck = { -2, 0, 0 } },
	Guard = { RHand = { 50, 0.15, 0.2 }, RBlade = { 35, -30 }, LHand = { -20, -0.1, -0.2 } },
	GuardGain = { Ranged = 0.35, Magic = 0.7 },
	Amp = { 1.0, 1.0, 0.9 }, Follow = 1.0,
	Linear = true, IdleStep = 0.3,
	Windup = { 0.18, 0, 0.22, 0.3, 0.42, 0.3, 0.46, 0.6, 0.8, 0.62 },
	Recovery = { 0.1, 0.33, 0.32, 0.35, 0.37, 0.68, 0.6, 0.7, 0.65, 1 },
	Idle = {
		{ "Neck", 2, 1, 0.8, 0, 0, { 0, 12, 12, 0, -10, -10 } }, { "Waist", 2, 1, 0.55, 0.3, 0, { 0, -5, 0, 6 } },
		{ "RootP", 2, 1, 0.9, 0, 0, { 0, -0.02, -0.04, -0.02 } }, { "LHand", 2, 1, 0.45, 0.5, 0, { 0, 0.05, 0, -0.05 } },
	},
	Finisher = "Style_Mechanical_Finisher", Jump = "Style_Mechanical_Jump",
}
Clips.Style_Mechanical_Finisher = overlay(1, FIN, {
	K(0.1, "l", { Root = { 0, 0, 0 }, Waist = { 0, 0, 0 }, RHand = { 0, 0, 0 } }),
	K(0.12, "l", { Root = { 0, -10, 0 }, Waist = { 0, -3, 0 }, RHand = { 0, 0, -0.08 } }),
	K(0.22, "l", { Root = { 0, -10, 0 }, Waist = { 0, -3, 0 }, RHand = { 0, 0, -0.08 } }),
	K(0.24, "l", { Root = { 0, -20, 0 }, Waist = { 0, -6, 0 }, RHand = { 0, 0, -0.16 } }),
	K(0.34, "l", { Root = { 0, -20, 0 }, Waist = { 0, -6, 0 }, RHand = { 0, 0, -0.16 } }),
	K(0.36, "l", { Root = { 0, -30, 0 }, Waist = { 0, -8, 0 }, RHand = { 0, 0, -0.24 } }),
	K(0.46, "l", { Root = { 0, -30, 0 }, Waist = { 0, -8, 0 }, RHand = { 0, 0, -0.24 }, RootP = { 0, 0, 0 } }),
	K(0.5, "l", { Root = { 0, 5, 0 }, Waist = { 0, 4, 0 }, RHand = { 0, 0, 0.3 }, RootP = { 0, -0.05, -0.3 } }),
	K(0.6, "l", { Root = { 0, 5, 0 }, Waist = { 0, 4, 0 }, RHand = { 0, 0, 0.3 }, RootP = { 0, -0.05, -0.3 } }),
	K(0.62, "l", { Root = { 0, 2, 0 }, Waist = { 0, 2, 0 }, RHand = { 0, 0, 0.15 }, RootP = { 0, -0.03, -0.15 } }),
	K(0.78, "l", { Root = { 0, 2, 0 }, Waist = { 0, 2, 0 }, RHand = { 0, 0, 0.15 }, RootP = { 0, -0.03, -0.15 } }),
	K(0.8, "l", { Root = { 0, 0, 0 }, Waist = { 0, 0, 0 }, RHand = { 0, 0, 0 }, RootP = { 0, 0, 0 } }),
})
Clips.Style_Mechanical_Jump = overlay(1, JUMP, {
	K(0.04, "l", { Root = { 0, 0, 0 }, LHand = { 0, 0, 0 }, LGrip = { 0, 0 }, RFoot = { 0, 0, 0, 0 }, LFoot = { 0, 0, 0, 0 } }),
	K(0.08, "l", { Root = { -14, 0, 0 }, LHand = { 90, 0, 0.35 }, LGrip = { 0, -1 }, RFoot = { 0, -0.6, 0, 0 }, LFoot = { 0, -0.6, 0, 0 },
		Neck = { 0, 0, 0 } }),
	K(0.35, "l", { Root = { -14, 0, 0 }, LHand = { 90, 0, 0.35 }, LGrip = { 0, -1 }, RFoot = { 0, -0.6, 0, 0 }, LFoot = { 0, -0.6, 0, 0 } }),
	K(0.4, "l", { Root = { 20, 0, 0 }, LHand = { 0, -0.2, 0.2 }, LGrip = { 0, -1 }, RFoot = { 0, -0.5, 0, 0 }, LFoot = { 0, -0.5, 0, 0 } }),
	K(0.6, "l", { Root = { 0, 0, 0 }, LHand = { 20, -0.3, 0 }, LGrip = { 0, -1 }, RFoot = { 0, 0, 0, 0 }, LFoot = { 0, 0, 0, 0 }, RootP = { 0, -0.15, 0 } }),
	K(0.75, "l", { LHand = { 20, -0.3, 0 }, LGrip = { 0, -1 }, RootP = { 0, -0.15, 0 } }),
	K(0.78, "l", { LHand = { 10, -0.15, 0 }, LGrip = { 0, -0.5 }, RootP = { 0, -0.08, 0 } }),
	K(0.9, "l", { LHand = { 10, -0.15, 0 }, LGrip = { 0, -0.5 }, RootP = { 0, -0.08, 0 } }),
	K(0.92, "l", { LHand = { 0, 0, 0 }, LGrip = { 0, 0 }, RootP = { 0, 0, 0 } }),
})

-- VOID, Voidwalker: warped and floating; elastic timing (slow-motion wind-ups, then a snap; a fast follow-through that
-- then floats back); the idle hovers above the ground with dangling feet. Finisher: a slow-motion spin that snaps into the
-- strike. Jump: a weightless float with a full flip, then a gravity-crushing slam.
ZoneStyles.Void = {
	Posture = { RootP = { 0, 0.04, 0 }, Waist = { -3, 0, 0 }, RFoot = { 0, 0.04, 0 }, LFoot = { 0, 0.04, 0 }, LHand = { 35, 0.1, 0.2 } },
	Guard = { RHand = { -35, 0.15, 0.1 }, RBlade = { -65, -80 }, LHand = { 60, 0.15, 0.3 } },
	GuardGain = { Ranged = 0.35, Magic = 0.7 },
	Amp = { 1.15, 1.15, 1.0 }, Follow = 1.2,
	Windup = { 0.55, 0.12, 0.82, 0.42 }, Recovery = { 0.12, 0.5, 0.35, 0.56 },
	IdleRate = 0.6,
	Idle = {
		{ "RootP", 2, 0.08, 0.3, 0, 0.35 }, { "RFoot", 2, 0.08, 0.3, 0, 0.35 }, { "LFoot", 2, 0.08, 0.3, 0.05, 0.37 },
		{ "RFoot", 3, 0.1, 0.3, 0 }, { "LFoot", 3, -0.1, 0.3, 0 }, { "Root", 1, 2.5, 0.15, 0 }, { "Waist", 2, 8, 0.12, 0 },
		{ "LHand", 2, 0.08, 0.3, 0.2 },
	},
	Finisher = "Style_Void_Finisher", Jump = "Style_Void_Jump",
}
Clips.Style_Void_Finisher = overlay(1, FIN, {
	K(0.05, "o", { Lift = { 0, 0.15, 0 } }),
	K(0.38, "i", { Root = { 0, 190, 0 }, Lift = { 0, 0.3, 0 }, LHand = { 50, 0.25, 0.2 }, Waist = { 0, 0, -8 } }),
	K(0.5, "l", { Root = { 0, 360, 0 }, Lift = { 0, 0, 0 }, LHand = { 0, 0, 0 }, Waist = { 0, 0, 0 } }),
	K(0.6, "O", { Root = { -8, 360, 0 }, RootP = { 0, -0.2, 0 } }),
	K(1, "s", { Root = { 0, 360, 0 }, RootP = { 0, 0, 0 } }),
}, { LateOk = true })
Clips.Style_Void_Jump = overlay(1, JUMP, {
	K(0.3, "s", { Root = { -360, 0, 0 }, Lift = { 0, 0.35, 0 }, LHand = { 40, 0.2, 0.2 }, LGrip = { 0, -1 } }),
	K(0.35, "s", { Root = { -360, 0, 0 }, Lift = { 0, 0.35, 0 }, LHand = { 40, 0.2, 0.2 }, LGrip = { 0, -1 } }),
	K(0.5, "i", { Root = { -372, 0, 0 }, Lift = { 0, 0.1, 0 }, LHand = { 0, 0, 0 }, LGrip = { 0, 0 } }),
	K(0.6, "O", { Root = { -366, 0, 0 }, Lift = { 0, 0, 0 }, RootP = { 0, -0.25, 0 }, Waist = { -16, 0, 0 } }),
	K(0.8, "s", { Root = { -362, 0, 0 }, RootP = { 0, -0.15, 0 }, Waist = { -10, 0, 0 } }),
	K(1, "s", { Root = { -360, 0, 0 } }),
}, { Gain = { Ranged = 0 } })

CombatAnimations.ZoneStyles = ZoneStyles

-- Weapon styles: a clip prefix tried before the category's (Ranged crossbows and guns; tools/WeaponTools WEAPON_GRIPS).
-- Not used while the Tool is a placeholder (Placeholder attribute: every placeholder Ranged is a bow on the bow grip).
CombatAnimations.Styles = {
	tundra_ranged = "RangedCrossbow", hell_ranged = "RangedCrossbow", dead_ranged = "RangedCrossbow",
	jungle_ranged = "RangedGun", abyss_ranged = "RangedGun", mechanical_ranged = "RangedGun",
}
return CombatAnimations
