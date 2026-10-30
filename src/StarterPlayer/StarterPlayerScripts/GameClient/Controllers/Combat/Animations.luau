--!strict
-- Player combat animations (docs/weapons_combat_brief.txt 4B, contract in docs/COMBAT_CONTRACTS.md).
-- Combat/AnimationController is the single caller of the attack functions; keep their names and arguments.
--   Animations.attack(character, category, step, speed, aim?, variant?) -> length
--                                                one move of Config/WeaponMoves; the clip's "Hit" marker lands at the
--                                                move's Impact / speed; returns the clip length in seconds at that
--                                                speed. variant "Air" = <Category>_JumpAttack, "Dash" =
--                                                <Category>_DashAttack, "Heavy" = <Category>_Heavy, "Skill" =
--                                                <Category>_Skill (the move's Clip wins); a missing clip falls back to the step's clip (stretched to
--                                                the variant's Impact). After Animations.charge a "Heavy" attack
--                                                releases the held wind-up instead of restarting it
--   Animations.charge(character, category, speed)  plays the heavy clip and holds it at its Charge marker
--   Animations.aim(character, direction)         the aim pitch of AimPitch clips while a shot is drawn
--   Animations.cancel(character)                 stops the attack clip quickly (the dodge cancels the recovery)
--   Animations.block(character, on)              guard pose while Block is held
--   Animations.blockHit(character)               a hit taken while blocking
--   Animations.roll(character, direction)        the dash (world direction)
--   Animations.hurt(character)                   a hit taken
-- Automatic, for every player's character on this client: the stance of the equipped Tool's "Category" (Idle / Run,
-- Equip when a weapon appears), Death on Humanoid.Died, Spawn on a new character.
--
-- Pipeline (docs/NIGHT_LOG.md, option 2): the clips are keyframe data (Config/CombatAnimations). Each frame, in
-- RunService.PreSimulation (after the default Animator's step), the joints' Transform (Motor6D or the avatar joint
-- upgrade's AnimationConstraint) is read back (= the Animator's pose of this frame) and blended with ours.
-- Layers: base = the category stance (Idle / Run by movement; root + legs only while standing still on the ground,
-- so the default walk / run / jump legs stay), action = one clip (attack, equip, block, roll, death, spawn) with a
-- cross-fade from the previous one, additive = hit reactions on top. Feet goals (legs) and hand targets (arms) are
-- solved with two-bone IK per character, so the clips fit any R15 body. Characters farther than RANGE studs from the
-- camera are not posed. No table is allocated per frame (CFrames only).
-- Weapons: the held weapon's axis (Handle Base -> Tip), face (bows: toward the Muzzle, else the Handle's -Z) and grip
-- are measured per Tool; clips aim them (RBlade, RFace) and can put the left hand on the weapon (LGrip: two hands).
-- Clip sets per weapon style (Config/CombatAnimations Styles[WeaponId]: RangedCrossbow, RangedGun) fall back to the
-- category; placeholder Tools (attribute Placeholder) always use the category's clips.
-- attack's optional 5th argument aim (Vector3, the 3D aim direction) pitches the torso of AimPitch clips (Ranged, Magic).
-- Jump attacks (combat V3): the client hangs the body, then dives it to land at Impact (CombatController plunge). For
-- the local player the clip follows the body: it waits at Markers.Dive while the body still hangs, waits just before
-- Hit while it is still in the air (high falls), and catches up once it has landed. Other players: by time only.
-- Airborne stance: <Category>_Air (upper body) replaces Idle / Run while the Humanoid jumps or falls.
-- Zone fighting styles (docs/COMBAT_CONTRACTS.md section 9): the held Tool's "Zone" (1..12, Config/CombatStyles) picks
-- Config/CombatAnimations ZoneStyles[zoneId], applied to every clip of the category (Shared_ clips excepted) of any
-- player's character: Posture offsets (lean, crouch, hunch, stance width, free hand), the attack's swing size around its
-- first pose (Amp torso / arms / legs, Follow = overshoot after the hit), a time warp of the wind-up [0, Hit] and of the
-- recovery [Hit, end] (the Hit pose stays exactly at the Hit time: warp(Hit) = Hit; the clip length is unchanged), Linear
-- easing / a stepped idle (Mechanical), waves added to the idle (hover, rocking, breathing, servo ticks, twitches) and to
-- attacks, and a signature overlay (Style_<Zone>_Finisher on combo finishers, Style_<Zone>_Jump on jump attacks) timed on
-- the attack clip's own Dive / Hit markers: its joint rotations and Lift (whole body) are multiplied on at write time,
-- its hand / blade / grip / feet / RootP offsets go into the IK targets. Plains (and no zone) = the clips as authored.
-- Ground guard (2026-10-14): the held Tool's lowest corner (from last frame's pose) is kept above the ground in the idle /
-- run stances (any zone) and at most ACTION_DEPTH x its reach under it in styled attacks, by lifting the blade elevation
-- (or the hand when the pommel side is lowest); the lifts relax once the weapon is clear. No allocation per frame.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatStyles = require(ReplicatedStorage.GameSystem.Config.CombatStyles)
local Data = require(ReplicatedStorage.GameSystem.Config.CombatAnimations)
local WeaponMoves = require(ReplicatedStorage.GameSystem.Config.WeaponMoves)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)

local Animations = {}
local STYLES: { [string]: string } = Data.Styles or {}

local RANGE = 150 -- studs from the camera
local REF_HIP = 2 -- HipHeight the clip positions are authored for
local REF_ARM = 1.14 -- shoulder -> wrist length the hand targets are authored for
local CANCEL_FADE = 0.08
local STAND_FADE, RUN_FADE, STANCE_FADE = 0.12, 0.18, 0.2
local MOVE_SPEED = 1.5 -- studs / s: a character counts as moving above this (or with move input, local player)
local MOVE_LOCK = 0.35 -- seconds after an attack / roll start during which the lunge / dash speed is ignored
local SPAWN_WINDOW = 3 -- a new character plays Shared_Spawn if its joints are ready within this many seconds
local TWIST_MAX = math.rad(110) -- forearm twist toward the blade
local AIM_PITCH_MAX = math.rad(55) -- torso pitch toward the attack's aim (AimPitch clips)
-- jump attack sync (local player): falling faster than this = diving; total wait; lead before Hit; catch-up rate
local DIVE_VY, SYNC_HOLD_MAX, LAND_LEAD, CATCH_UP = 8, 1.3, 0.025, 3
local AIR_FADE = 0.15 -- airborne stance blend
-- zone styles: a finisher whose wind-up is shorter than this (seconds) plays a LateOk signature (spins, twirls) in its
-- recovery instead (LATE_SPLIT of the recovery = the signature's wind-up part); lowest RootP.Y the posture / swing size
-- may reach (deeper only if the clip itself goes deeper: landings)
local LATE_WINDUP, LATE_SPLIT, CROUCH_FLOOR = 0.15, 0.55, -1.2
local ROLE_ACTION, ROLE_IDLE, ROLE_STANCE = 0, 1, 2
-- ground guard: in the idle / run stances (no action clip) the held weapon's lowest corner is kept at least GROUND_MARGIN
-- studs above the ground under the character (a "dragging" blade may touch it): when it is lower, the stance's blade
-- elevation is lifted (tip side lowest) or the hand raised (pommel / butt side lowest); the lift relaxes slowly once
-- the weapon is GROUND_SLACK above the margin. Maximum lift, per-frame step limits, relax rates (per second).
local GROUND_MARGIN, GROUND_SLACK = 0.06, 0.2
local CLEAR_HOLD = 1.5 -- seconds the stance weapon must stay clear before its lift relaxes (longer than a run / idle cycle)
local BLEND_RELAX = 3 -- rad (studs) per second: the transient lift of an idle <-> run blend fades fast once it is over (while clear)
local BLEND_LEAD, RUN_LEAD = 0.2, 0.1 -- studs of extra clearance aimed at during an idle <-> run blend / while running
local LIFT_EL_MAX, LIFT_H_MAX, LIFT_EL_STEP, LIFT_H_STEP, LIFT_EL_RELAX, LIFT_H_RELAX = math.rad(80), 1.2, 0.35, 0.3, 0.5, 0.3
-- styled attacks (zone styles): the weapon may go at most ACTION_DEPTH x its reach under the ground (about the authored
-- depth of the jump attack landings' ground stabs); deeper, the attack's own lift raises it (relaxes at ACTION_RELAX)
local ACTION_DEPTH, ACTION_RELAX = 0.45, 1.5
local BLADE_MIN = 1.2 -- studs past the hand: shorter weapons are lifted by the hand only
local VARIANTS: { [string]: string } = { Air = "_JumpAttack", Dash = "_DashAttack", Heavy = "_Heavy", Skill = "_Skill" } -- clip name suffix
local CHARGE_POINT = 0.6 -- a heavy clip without a Charge marker holds at this fraction of its wind-up

local PI, TAU = math.pi, math.pi * 2
local ZERO = Vector3.zero
local HAND_BLADE = Vector3.new(0, 0, -1) -- weapon direction in the hand's frame until the Tool is measured
local R_POLE = Vector3.new(0.7, -0.6, 0.4).Unit
local L_POLE = Vector3.new(-0.7, -0.6, 0.4).Unit
local DOWN = Vector3.new(0, -1, 0)

-- v.Unit, or `fallback` when v is (almost) zero: a zero vector's .Unit is NaN, and a NaN written to a joint hides the
-- whole body (bug 2026-10-12: the character vanished during attacks).
local function unit(v: Vector3, fallback: Vector3): Vector3
	local m = v.Magnitude
	return if m > 1e-6 then v / m else fallback
end
local FACE_POINTS = { "MuzzleAttachment", "ImpactAttachment" }
local sin, cos, atan2, acos, asin, sqrt, clamp, abs = math.sin, math.cos, math.atan2, math.acos, math.asin, math.sqrt, math.clamp, math.abs

-- Channels: 1-15 joint rotations (radians, YXZ), then positions and IK goals.
local NAMES = {
	"Root", "Waist", "Neck", "RShoulder", "RElbow", "RWrist", "LShoulder", "LElbow", "LWrist",
	"RHip", "RKnee", "RAnkle", "LHip", "LKnee", "LAnkle",
	"RootP", "RFoot", "LFoot", "RFootYaw", "LFootYaw", "RHand", "RBlade", "RPole", "LHand", "LBlade", "LPole",
	"RFace", "LGrip", "Lift",
}
local PARTS = {
	"LowerTorso", "UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm",
	"LeftHand", "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
}
local NJ, NCH = 15, #NAMES
local C_ROOTP, C_RFOOT, C_LFOOT, C_RYAW, C_LYAW = 16, 17, 18, 19, 20
local C_RHAND, C_RBLADE, C_RPOLE, C_LHAND, C_LBLADE, C_LPOLE = 21, 22, 23, 24, 25, 26
local C_RFACE, C_LGRIP = 27, 28 -- C_LGRIP is the last arm channel
local C_LIFT = 29 -- style overlays only: whole-body offset (studs) added at write time
local LEGS = { Upper = 0, Stand = 1, Own = 2 }
local EASE = { s = 0, l = 1, i = 2, o = 3, O = 4 }
local CHANNEL: { [string]: number } = {}
for c, name in ipairs(NAMES) do
	CHANNEL[name] = c
end
-- signature overlay channels that go into the IK targets (the joint channels 1..15 and Lift are applied at write time)
local SIG_PRE = { C_ROOTP, C_RFOOT, C_LFOOT, C_RHAND, C_RBLADE, C_LHAND, C_LBLADE, C_LGRIP }
local LOWER_CH: { [number]: boolean } = { [1] = true, [C_ROOTP] = true, [C_RFOOT] = true, [C_LFOOT] = true, [C_RYAW] = true, [C_LYAW] = true }

type Track = { times: { number }, values: { Vector3 }, eases: { number }, n: number }
type Clip = {
	name: string, length: number, loop: boolean, legs: number, additive: boolean, hold: boolean,
	fadeIn: number, fadeOut: number, hit: number?, dive: number?, charge: number?, legIK: boolean, rArm: boolean, lArm: boolean, aimPitch: boolean,
	tracks: { Track | false },
	-- zone styles: values at t = 0 (the swing size is scaled around them), the root turns a full spin / flip (no
	-- root swing size), styled (not Shared_ / Style_), signature gain per category and LateOk (see LATE_WINDUP)
	base: { Vector3 }, spinX: boolean, spinY: boolean, styled: boolean, gain: { [string]: number }?, lateOk: boolean,
}
type Slot = {
	clip: Clip?, t: number, w: number, fade: number, stopping: boolean, rate1: number, rate2: number, kind: string, dir: Vector3?,
	frozen: boolean, sync: boolean, held: number,
	holdAt: number?, -- a heavy's wind-up waits at this clip time until the release (Animations.attack "Heavy")
	-- zone styles: phase 0 = unstyled, 1 = combo step / dash strike (time warp), 2 = jump attack (no wind-up warp: the
	-- dive sync); fin = combo finisher; sig = signature overlay (gain sigW, late = played in the recovery)
	phase: number, fin: boolean, sig: Clip?, sigW: number, late: boolean, started: number,
	-- ground guard of a styled attack: blade elevation / hand height lift keeping the weapon at most ACTION_DEPTH x its
	-- reach under the ground (the authored ground stabs of the landings stay, the style may not bury the weapon deeper)
	lift: number, liftH: number,
}
type Term = { c: number, axis: number, amp: number, freq: number, phase: number, bias: number, kind: number, steps: { number }? }
type ZStyle = {
	id: string, rootRot: Vector3, rootP: Vector3, waist: Vector3, neck: Vector3, rHand: Vector3, lHand: Vector3,
	rFoot: Vector3, lFoot: Vector3, kt: number, ka: number, kl: number, follow: number,
	windup: { number }?, recovery: { number }?, finWindup: { number }?, linear: boolean, idleRate: number, idleStep: number,
	idle: { Term }, attack: { Term }, finisher: string?, jump: string?,
	guardRHand: Vector3, guardRBlade: Vector3, guardLHand: Vector3, guardGain: { [string]: number },
}
type Leg = { hipLocal: Vector3, rest: Vector3, l1: number, l2: number, goal: number, yaw: number, hip: number, knee: number, ankle: number }
type Arm = {
	shoulder: Vector3, l1: number, l2: number, invF1: CFrame, invF2: CFrame, scale: number, axis2: Vector3, palm: number,
	wristInHand: Vector3, blade: Vector3, face: Vector3, weaponInv: CFrame, gripOffset: Vector3, grip: boolean,
}
type State = {
	character: Model, isLocal: boolean, humanoid: Humanoid?, root: BasePart?,
	joints: { any }, legs: { Leg }, rArm: Arm, lArm: Arm, pivot: CFrame, scale: number,
	dirty: boolean, retryAt: number, ready: boolean, toolDirty: boolean, diedConn: RBXScriptConnection?, watched: Humanoid?,
	category: string?, style: string?, idle: Clip?, run: Clip?, air: Clip?, stanceOn: boolean, aimPitch: number,
	zstyle: ZStyle?, styleT: number,
	-- ground guard (stances): the held Tool's bounding-box corners in its Handle's frame (tipSide = on the blade's side
	-- of the hand), and the lift applied to the stance's blade elevation (radians) / hand height (studs)
	handle: BasePart?, corners: { Vector3 }, tipSide: { boolean }, toolReach: number, liftEl: number, liftH: number,
	runEl: number, runH: number, -- the same lifts for the run / air stances (kept apart: the run holds weapons lower)
	blendEl: number, blendH: number, -- transient lift while the idle and run stances blend (their targets cross over)
	upper: BasePart?, upT: Vector3, -- UpperTorso, and the world's up in its frame (last frame): the lifts go straight up
	clearT: number, -- seconds the stance weapon has been clear of the ground (see CLEAR_HOLD)
	stanceW: number, standF: number, runF: number, airF: number, idleT: number, runT: number, airT: number,
	act: Slot, prev: Slot, add: Slot,
	blocking: boolean, dead: boolean, spawnUntil: number,
	moving: boolean, moveLockUntil: number,
	conns: { RBXScriptConnection },
}

-- ------------------------------------------------------------------------------------------------
-- Clips
-- ------------------------------------------------------------------------------------------------
local clips: { [string]: Clip } = {}

local function compile(name: string, def: { [string]: any }): Clip
	local tracks: { Track | false } = table.create(NCH, false)
	for c = 1, NCH do
		local key = NAMES[c]
		local source = if c == C_RYAW then "RFoot" elseif c == C_LYAW then "LFoot" else key
		local times, values, eases = {}, {}, {}
		for _, pose in ipairs(def.Poses) do
			local v = pose[source]
			if v then
				local vec
				if c <= NJ then
					vec = Vector3.new(math.rad(v[1]), math.rad(v[2]), math.rad(v[3]))
				elseif c == C_RYAW or c == C_LYAW then
					vec = Vector3.new(0, math.rad(v[4] or 0), 0)
				elseif c == C_RHAND or c == C_LHAND then
					vec = Vector3.new(math.rad(v[1]), v[2], v[3])
				elseif c == C_RBLADE or c == C_LBLADE or c == C_RFACE then
					vec = Vector3.new(math.rad(v[1]), math.rad(v[2]), 0)
				elseif c == C_RPOLE or c == C_LPOLE then
					vec = unit(Vector3.new(v[1], v[2], v[3]), DOWN)
				else
					vec = Vector3.new(v[1] or 0, v[2] or 0, v[3] or 0)
				end
				table.insert(times, pose[1])
				table.insert(values, vec)
				table.insert(eases, EASE[pose[2] or "s"] or 0)
			end
		end
		if #times > 0 then
			tracks[c] = { times = times, values = values, eases = eases, n = #times }
		end
	end
	local rawLegs = false
	for c = 10, 15 do
		if tracks[c] then
			rawLegs = true
		end
	end
	local base: { Vector3 } = table.create(NCH, ZERO)
	for c = 1, NCH do
		local tr = tracks[c]
		if tr then
			base[c] = tr.values[1]
		end
	end
	local spinX, spinY = false, false
	local rootTrack = tracks[1]
	if rootTrack then
		local loX, hiX, loY, hiY = math.huge, -math.huge, math.huge, -math.huge
		for _, v in ipairs(rootTrack.values) do
			loX, hiX, loY, hiY = math.min(loX, v.X), math.max(hiX, v.X), math.min(loY, v.Y), math.max(hiY, v.Y)
		end
		spinX, spinY = hiX - loX > math.rad(200), hiY - loY > math.rad(200)
	end
	return {
		name = name,
		length = def.Length,
		loop = def.Loop == true,
		legs = LEGS[def.Legs or "Stand"] or 1,
		additive = def.Additive == true,
		hold = def.Hold == true,
		fadeIn = math.max(0.01, def.FadeIn or 0.1),
		fadeOut = math.max(0.01, def.FadeOut or 0.15),
		hit = def.Markers and def.Markers.Hit or nil,
		dive = def.Markers and def.Markers.Dive or nil,
		charge = def.Markers and def.Markers.Charge or nil,
		legIK = not rawLegs,
		rArm = tracks[C_RHAND] ~= false,
		lArm = tracks[C_LHAND] ~= false or tracks[C_LGRIP] ~= false,
		aimPitch = def.AimPitch == true,
		tracks = tracks,
		base = base,
		spinX = spinX,
		spinY = spinY,
		styled = string.sub(name, 1, 7) ~= "Shared_" and string.sub(name, 1, 6) ~= "Style_",
		gain = if typeof(def.Gain) == "table" then def.Gain else nil,
		lateOk = def.LateOk == true,
	}
end

-- Zone styles: Config/CombatAnimations ZoneStyles[zoneId] -> runtime numbers (radians, studs, channel indices).
local zstyles: { [string]: ZStyle } = {}

local function offset(c: number, v: any): Vector3
	if typeof(v) ~= "table" then
		return ZERO
	end
	local x, y, z = v[1] or 0, v[2] or 0, v[3] or 0
	if c <= NJ then
		return Vector3.new(math.rad(x), math.rad(y), math.rad(z))
	elseif c == C_RHAND or c == C_LHAND then
		return Vector3.new(math.rad(x), y, z)
	elseif c == C_RBLADE or c == C_LBLADE or c == C_RFACE then
		return Vector3.new(math.rad(x), math.rad(y), 0)
	end
	return Vector3.new(x, y, z)
end

local function terms(list: any): { Term }
	local out: { Term } = {}
	if typeof(list) ~= "table" then
		return out
	end
	for _, def in ipairs(list) do
		local c = CHANNEL[def[1]]
		local axis = def[2] or 1
		if c and axis >= 1 and axis <= 3 then
			-- degrees for joints, hand azimuths and blades; studs for the rest
			local angle = c <= NJ or ((c == C_RHAND or c == C_LHAND) and axis == 1) or c == C_RBLADE or c == C_LBLADE
			local k = if angle then math.rad(1) else 1
			local wave = def[7]
			table.insert(out, {
				c = c, axis = axis, amp = (def[3] or 0) * k, freq = def[4] or 1, phase = def[5] or 0, bias = (def[6] or 0) * k,
				kind = if typeof(wave) == "table" then 1 elseif wave == "pulse" then 2 else 0,
				steps = if typeof(wave) == "table" then wave else nil,
			})
		end
	end
	return out
end

local function knots(v: any): { number }?
	return if typeof(v) == "table" and #v >= 2 then v else nil
end

local function compileStyles(data: { [string]: any })
	table.clear(zstyles)
	for id, def in pairs(data.ZoneStyles or {}) do
		local post = def.Posture or {}
		local guard = def.Guard or {}
		local amp = def.Amp or {}
		zstyles[id] = {
			guardRHand = offset(C_RHAND, guard.RHand), guardRBlade = offset(C_RBLADE, guard.RBlade), guardLHand = offset(C_LHAND, guard.LHand),
			guardGain = if typeof(def.GuardGain) == "table" then def.GuardGain else {},
			id = id,
			rootRot = offset(1, post.Root), rootP = offset(C_ROOTP, post.RootP), waist = offset(2, post.Waist), neck = offset(3, post.Neck),
			rHand = offset(C_RHAND, post.RHand), lHand = offset(C_LHAND, post.LHand),
			rFoot = offset(C_RFOOT, post.RFoot), lFoot = offset(C_LFOOT, post.LFoot),
			kt = amp[1] or 1, ka = amp[2] or 1, kl = amp[3] or 1, follow = def.Follow or 1,
			windup = knots(def.Windup), recovery = knots(def.Recovery), finWindup = knots(def.FinisherWindup),
			linear = def.Linear == true, idleRate = def.IdleRate or 1, idleStep = def.IdleStep or 0,
			idle = terms(def.Idle), attack = terms(def.Attack),
			finisher = def.Finisher, jump = def.Jump,
		}
	end
end

local function compileAll(data: { [string]: any })
	table.clear(clips)
	for name, def in pairs(data.Clips) do
		clips[name] = compile(name, def)
	end
	STYLES = data.Styles or {}
	compileStyles(data)
end
compileAll(Data)

local function ease(k: number, kind: number): number
	if kind == 0 then
		return k * k * (3 - 2 * k)
	elseif kind == 1 then
		return k
	elseif kind == 2 then
		return k * k
	elseif kind == 3 then
		local u = 1 - k
		return 1 - u * u
	end
	local u = 1 - k
	return 1 - u * u * u
end

local linearEase = false -- zone style Linear (Mechanical): every key eased linearly while sampling a styled clip

local function sample(track: Track, t: number): Vector3
	local times, values = track.times, track.values
	local n = track.n
	if t <= times[1] then
		return values[1]
	elseif t >= times[n] then
		return values[n]
	end
	for i = 2, n do
		local b = times[i]
		if t < b then
			local a = times[i - 1]
			return values[i - 1]:Lerp(values[i], ease((t - a) / (b - a), if linearEase then 1 else track.eases[i]))
		end
	end
	return values[n]
end

local function wrap(a: number): number
	return (a + PI) % TAU - PI
end

local function smooth(k: number): number
	k = clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

-- Time warp knots { u1, v1, u2, v2, ... } (0 < u < 1, increasing), implicit (0, 0) and (1, 1): piecewise linear.
local function warpKnots(k: { number }, u: number): number
	local pu, pv = 0, 0
	for i = 1, #k - 1, 2 do
		local ku, kv = k[i], k[i + 1]
		if u < ku then
			return pv + (kv - pv) * (u - pu) / (ku - pu)
		end
		pu, pv = ku, kv
	end
	return if pu < 1 then pv + (1 - pv) * (u - pu) / (1 - pu) else 1
end

-- The clip time a styled attack slot samples at clip time t: the wind-up and the recovery are warped separately so
-- the Hit pose stays at the Hit time and the clip ends on time.
local function warpTime(Z: ZStyle, clip: Clip, t: number, slot: Slot): number
	local hit = clip.hit
	if not hit or hit <= 0 then
		return t
	end
	if t < hit then
		local k = if slot.phase == 2 then nil elseif slot.fin and Z.finWindup then Z.finWindup else Z.windup
		return if k then warpKnots(k, t / hit) * hit else t
	end
	local k = Z.recovery
	local span = clip.length - hit
	if not k or span <= 1e-3 then
		return t
	end
	return hit + warpKnots(k, math.min(1, (t - hit) / span)) * span
end

-- The signature overlay's time for the attack clip at time t: its Dive / Hit markers line up with the clip's (the
-- local jump attack holds at Dive while the body hangs: the overlay holds too); late = all of it in the recovery.
local function sigTime(slot: Slot, clip: Clip, sig: Clip, t: number): number
	local hit = clip.hit or clip.length
	local ohit = sig.hit or sig.length * 0.5
	local span = math.max(1e-3, clip.length - hit)
	if slot.late then
		if t <= hit then
			return 0
		end
		local v = (t - hit) / span
		if v < LATE_SPLIT then
			return v / LATE_SPLIT * ohit
		end
		return ohit + math.min(1, (v - LATE_SPLIT) / (1 - LATE_SPLIT)) * (sig.length - ohit)
	end
	if t <= hit then
		if hit <= 0 then
			return ohit
		end
		local dive, odive = clip.dive, sig.dive
		if dive and odive and dive > 0 and dive < hit then
			if t <= dive then
				return t / dive * odive
			end
			return odive + (t - dive) / (hit - dive) * (ohit - odive)
		end
		return t / hit * ohit
	end
	return ohit + math.min(1, (t - hit) / span) * (sig.length - ohit)
end

-- Style waves (idle / attack) added into out at style clock T, weight W; lower = root and legs are sampled.
local function applyTerms(list: { Term }, out: { Vector3 }, T: number, W: number, lower: boolean)
	for _, term in ipairs(list) do
		local c = term.c
		if lower or not LOWER_CH[c] then
			local x = T * term.freq + term.phase
			local v
			if term.kind == 0 then
				v = term.amp * sin(TAU * x)
			elseif term.kind == 1 then
				local steps = term.steps :: { number }
				v = term.amp * steps[math.floor(x) % #steps + 1]
			else
				local f = x % 1 -- a twitch: up fast, down a little slower, then still for the rest of the period
				v = term.amp * (if f < 0.04 then f / 0.04 elseif f < 0.14 then 1 - (f - 0.04) / 0.1 else 0)
			end
			v = (v + term.bias) * W
			local o = out[c]
			local axis = term.axis
			out[c] = if axis == 1 then Vector3.new(o.X + v, o.Y, o.Z) elseif axis == 2 then Vector3.new(o.X, o.Y + v, o.Z) else Vector3.new(o.X, o.Y, o.Z + v)
		end
	end
end

local function approach(value: number, target: number, step: number): number
	if value < target then
		return math.min(target, value + step)
	end
	return math.max(target, value - step)
end

-- ------------------------------------------------------------------------------------------------
-- IK (all attachment / C0 / C1 rotations are identity on R15 rigs; only their positions are used)
-- ------------------------------------------------------------------------------------------------
-- Frame whose -Y runs along v and whose X is the hinge axis.
local function frame(v: Vector3, axis: Vector3): CFrame
	local y = -unit(v, DOWN)
	local x = axis - y * axis:Dot(y)
	local m = x.Magnitude
	x = if m > 1e-4 then x / m else Vector3.xAxis
	return CFrame.fromMatrix(ZERO, x, y, x:Cross(y))
end

local function solveLegs(S: State, out: { Vector3 })
	local s = S.scale
	local r = out[1]
	local rootCF = CFrame.fromEulerAnglesYXZ(r.X, r.Y, r.Z) + out[C_ROOTP] * s
	local pivot = S.pivot
	local cy, sy = cos(r.Y), sin(r.Y)
	for side = 1, 2 do
		local leg = S.legs[side]
		local hip = pivot:PointToWorldSpace(rootCF:PointToWorldSpace(leg.hipLocal))
		local g = leg.rest + out[leg.goal] * s
		local target = Vector3.new(g.X * cy + g.Z * sy, g.Y, -g.X * sy + g.Z * cy)
		local v = rootCF:VectorToObjectSpace(pivot:VectorToObjectSpace(target - hip))
		local yaw = out[leg.yaw].Y
		local cyaw, syaw = cos(yaw), sin(yaw)
		local vx, vy, vz = v.X * cyaw - v.Z * syaw, v.Y, v.X * syaw + v.Z * cyaw
		local len = math.max(1e-4, sqrt(vx * vx + vy * vy + vz * vz))
		local l1, l2 = leg.l1, leg.l2
		local d = clamp(len, abs(l1 - l2) + 0.01, (l1 + l2) * 0.999)
		local knee = acos(clamp((l1 * l1 + l2 * l2 - d * d) / (2 * l1 * l2), -1, 1)) - PI
		local a = acos(clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1))
		local pitch = asin(clamp(-vz / len, -1, 1)) + a
		local roll = atan2(vx / len, -vy / len)
		local hipCF = CFrame.fromEulerAngles(pitch, yaw, roll, Enum.RotationOrder.YZX)
		local kneeCF = CFrame.Angles(knee, 0, 0)
		local ankleCF = (rootCF * hipCF * kneeCF):Inverse() * CFrame.Angles(0, r.Y + yaw, 0)
		out[leg.hip] = Vector3.new(hipCF:ToEulerAnglesYXZ())
		out[leg.knee] = Vector3.new(knee, 0, 0)
		out[leg.ankle] = Vector3.new(ankleCF:ToEulerAnglesYXZ())
	end
end

-- Direction from { azimuth, elevation } (radians, UpperTorso frame: 0 = forward, +azimuth = left).
local function direction(v: Vector3): Vector3
	local ce = cos(v.Y)
	return Vector3.new(-ce * sin(v.X), sin(v.Y), -ce * cos(v.X))
end

-- Wrist target from { azimuth, height above the shoulder joint, radius } around the UpperTorso axis.
local function wristTarget(arm: Arm, hp: Vector3): Vector3
	local k = arm.scale
	return Vector3.new(-hp.Z * k * sin(hp.X), arm.shoulder.Y + hp.Y * k, -hp.Z * k * cos(hp.X))
end

-- Ground guard lifts toward the world's up (S.upT, in the UpperTorso frame: right even when the torso bends far): the
-- right hand target rises `height` studs, the blade direction turns `angle` radians up (never past straight up).
local function liftTargets(S: State, out: { Vector3 }, angle: number, height: number)
	local upT = S.upT
	if height > 0 then
		local arm = S.rArm
		local hp = out[C_RHAND]
		local w = wristTarget(arm, hp) + upT * height
		local k = arm.scale
		-- azimuths stay continuous with the clip's (the idle / run targets are blended after this)
		out[C_RHAND] = Vector3.new(hp.X + wrap(atan2(-w.X, -w.Z) - hp.X), (w.Y - arm.shoulder.Y) / k, sqrt(w.X * w.X + w.Z * w.Z) / k)
	end
	if angle > 0 then
		local b = out[C_RBLADE]
		local d = direction(b)
		local cosUp = d:Dot(upT)
		local perp = upT - d * cosUp
		local m = perp.Magnitude
		if m > 1e-3 then
			local a = math.min(angle, acos(clamp(cosUp, -1, 1)))
			d = d * cos(a) + perp * (sin(a) / m)
			out[C_RBLADE] = Vector3.new(b.X + wrap(atan2(-d.X, -d.Z) - b.X), asin(clamp(d.Y, -1, 1)), 0)
		end
	end
end

-- One arm, UpperTorso frame: wrist target w, elbow pole, optional aim (direction of the held weapon's axis arm.blade)
-- and face (direction of its face axis arm.face, i.e. the roll around aim). The forearm takes the twist (up to
-- TWIST_MAX), the wrist the rest. Writes the three joint rotations from firstJ; returns the hand rotation and the
-- wrist position reached.
local function solveArm(arm: Arm, out: { Vector3 }, firstJ: number, w: Vector3, pole: Vector3, aim: Vector3?, face: Vector3?): (CFrame, Vector3)
	local sp = arm.shoulder
	local sw = w - sp
	local dist = math.max(1e-4, sw.Magnitude)
	local dir = sw / dist
	local l1, l2 = arm.l1, arm.l2
	local d = clamp(dist, abs(l1 - l2) + 0.01, (l1 + l2) * 0.999)
	local perp = pole - dir * pole:Dot(dir)
	if perp.Magnitude < 1e-3 then
		perp = Vector3.new(0, 0, 1) - dir * dir.Z
		if perp.Magnitude < 1e-3 then
			perp = Vector3.xAxis - dir * dir.X -- the pole AND the wrist both straight ahead / behind
		end
	end
	perp = unit(perp, Vector3.xAxis)
	local a = acos(clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1))
	local e = sp + dir * (l1 * cos(a)) + perp * (l1 * sin(a))
	local wrist = sp + dir * d
	local fa = wrist - e
	local hinge = perp:Cross(dir)
	local rua = frame(e - sp, hinge) * arm.invF1
	local rla = frame(fa, hinge) * arm.invF2
	local hand = rla
	local fd = if aim and face and arm.face ~= ZERO then face - aim * face:Dot(aim) else ZERO
	if aim and fd.Magnitude > 1e-3 then
		-- full orientation (weapon axis on aim, face toward face); swing / twist split around the forearm
		fd = fd.Unit
		hand = CFrame.fromMatrix(ZERO, aim, fd, aim:Cross(fd)) * arm.weaponInv
		local axis, angle = (rla:Inverse() * hand):ToAxisAngle()
		local twist = wrap(2 * atan2(axis:Dot(arm.axis2) * sin(angle / 2), cos(angle / 2)))
		rla *= CFrame.fromAxisAngle(arm.axis2, clamp(twist, -TWIST_MAX, TWIST_MAX))
	elseif aim then
		local axis = unit(fa, DOWN)
		local b0 = rla:VectorToWorldSpace(arm.blade)
		local pb = aim - axis * aim:Dot(axis)
		local pb0 = b0 - axis * b0:Dot(axis)
		if pb.Magnitude > 0.05 and pb0.Magnitude > 0.05 then
			local twist = clamp(atan2(axis:Dot(pb0:Cross(pb)), pb0:Dot(pb)), -TWIST_MAX, TWIST_MAX)
			rla = CFrame.fromAxisAngle(axis, twist) * rla
			b0 = rla:VectorToWorldSpace(arm.blade)
		end
		local cross = b0:Cross(aim)
		local m = cross.Magnitude
		hand = if m > 1e-4 then CFrame.fromAxisAngle(cross / m, atan2(m, b0:Dot(aim))) * rla else rla
	end
	out[firstJ] = Vector3.new(rua:ToEulerAnglesYXZ())
	out[firstJ + 1] = Vector3.new((rua:Inverse() * rla):ToEulerAnglesYXZ())
	out[firstJ + 2] = Vector3.new((rla:Inverse() * hand):ToEulerAnglesYXZ())
	return hand, wrist
end

-- ------------------------------------------------------------------------------------------------
-- Per-character state
-- ------------------------------------------------------------------------------------------------
local states: { [Model]: State } = {}
local nanSkips = 0 -- joints writes refused because of a NaN (debug attribute AnimNaNSkips)
local list: { State } = {}

local scratchA: { Vector3 } = table.create(NCH, ZERO)
local scratchB: { Vector3 } = table.create(NCH, ZERO)
local acc: { Vector3 } = table.create(NCH, ZERO)
local sigJ: { Vector3 } = table.create(NJ, ZERO) -- signature joint offsets of the character being written

local function newSlot(): Slot
	return {
		clip = nil, t = 0, w = 0, fade = 0.1, stopping = false, rate1 = 1, rate2 = 1, kind = "", dir = nil, frozen = false, sync = false, held = 0, holdAt = nil,
		phase = 0, fin = false, sig = nil, sigW = 1, late = false, started = 0, lift = 0, liftH = 0,
	}
end

local function newLeg(goal: number, yaw: number, hip: number): Leg
	return { hipLocal = ZERO, rest = ZERO, l1 = 1, l2 = 1, goal = goal, yaw = yaw, hip = hip, knee = hip + 1, ankle = hip + 2 }
end

local function newArm(): Arm
	return {
		shoulder = ZERO, l1 = 0.5, l2 = 0.6, invF1 = CFrame.identity, invF2 = CFrame.identity, scale = 1, axis2 = DOWN, palm = 0.25,
		wristInHand = ZERO, blade = HAND_BLADE, face = ZERO, weaponInv = CFrame.identity, gripOffset = ZERO, grip = false,
	}
end

local function c0(joint: any): CFrame
	return if joint:IsA("Motor6D") then joint.C0 else joint.Attachment0.CFrame
end

local function c1(joint: any): CFrame
	return if joint:IsA("Motor6D") then joint.C1 else joint.Attachment1.CFrame
end

local onDied: (S: State) -> ()
local debugAttribute: (S: State) -> ()
local profileAttribute: (character: Model) -> ()
local reloadAttribute: () -> ()

local function rebuild(S: State)
	S.dirty = false
	local character = S.character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	S.humanoid = humanoid
	S.root = if root and root:IsA("BasePart") then root else nil
	local byPart: { [string]: Instance } = {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Motor6D") then
			local p1 = d.Part1
			if p1 and p1.Parent == character then
				byPart[p1.Name] = d
			end
		elseif d:IsA("AnimationConstraint") then
			local a0, a1 = d.Attachment0, d.Attachment1
			local p1 = a1 and a1.Parent
			if a0 and p1 and p1.Parent == character then
				byPart[p1.Name] = d
			end
		end
	end
	local complete = humanoid ~= nil and S.root ~= nil
	for i = 1, NJ do
		local joint = byPart[PARTS[i]]
		S.joints[i] = joint or false
		if not joint then
			complete = false
		end
	end
	S.ready = complete
	if not complete or not humanoid then
		return
	end
	local j = S.joints
	S.scale = math.max(0.3, humanoid.HipHeight / REF_HIP)
	local upper = character:FindFirstChild("UpperTorso")
	S.upper = if upper and upper:IsA("BasePart") then upper else nil
	S.pivot = c0(j[1])
	local a1r = c1(j[1])
	for side = 1, 2 do
		local base = if side == 1 then 10 else 13
		local leg = S.legs[side]
		local hipLocal = a1r:PointToObjectSpace(c0(j[base]).Position)
		local d1 = c1(j[base]):PointToObjectSpace(c0(j[base + 1]).Position)
		local d2 = c1(j[base + 1]):PointToObjectSpace(c0(j[base + 2]).Position)
		leg.hipLocal = hipLocal
		leg.rest = S.pivot:PointToWorldSpace(hipLocal + d1 + d2)
		leg.l1 = math.max(0.05, d1.Magnitude)
		leg.l2 = math.max(0.05, d2.Magnitude)
	end
	for side = 1, 2 do
		local base = if side == 1 then 4 else 7
		local arm = if side == 1 then S.rArm else S.lArm
		local d1 = c1(j[base]):PointToObjectSpace(c0(j[base + 1]).Position)
		local d2 = c1(j[base + 1]):PointToObjectSpace(c0(j[base + 2]).Position)
		arm.shoulder = c0(j[base]).Position
		arm.l1 = math.max(0.05, d1.Magnitude)
		arm.l2 = math.max(0.05, d2.Magnitude)
		arm.invF1 = frame(d1, Vector3.xAxis):Inverse()
		arm.invF2 = frame(d2, Vector3.xAxis):Inverse()
		arm.scale = (arm.l1 + arm.l2) / REF_ARM
		arm.axis2 = if d2.Magnitude > 1e-4 then d2.Unit else DOWN
		arm.wristInHand = c1(j[base + 2]).Position
		local handPart = character:FindFirstChild(PARTS[base + 2])
		local gripAt = handPart and handPart:FindFirstChild(if side == 1 then "RightGripAttachment" else "LeftGripAttachment")
		arm.palm = if gripAt and gripAt:IsA("Attachment") then (gripAt.Position - arm.wristInHand).Magnitude else 0.25
	end
	S.toolDirty = true
	if S.watched ~= humanoid then
		if S.diedConn then
			S.diedConn:Disconnect()
		end
		S.watched = humanoid
		S.diedConn = humanoid.Died:Connect(function()
			onDied(S)
		end)
	end
	if humanoid.Health <= 0 and not S.dead then
		onDied(S)
	end
end

-- The held weapon in the right hand's frame (through the RightGrip weld): its axis (Handle Base -> Tip), its face
-- (toward a Muzzle / Impact attachment beside the axis: bow arrow side, axe edge; else the Handle's front -Z:
-- crossbow top, gun side) and the Handle's origin from the wrist.
local function measureTool(S: State)
	S.toolDirty = false
	S.handle = nil
	S.liftEl, S.liftH, S.runEl, S.runH, S.clearT = 0, 0, 0, 0, 0 -- a new weapon starts from its style's own pose
	S.blendEl, S.blendH = 0, 0
	S.lArm.blade = HAND_BLADE
	local arm = S.rArm
	arm.blade = HAND_BLADE
	arm.face = ZERO
	arm.grip = false
	local character = S.character
	local tool = character:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	if not handle then
		return
	end
	-- a pair's left copy (WeaponService): LBlade aims its axis
	local off = (tool :: Tool):FindFirstChild("OffHand")
	local leftGrip = off and off:FindFirstChild("LeftGrip")
	local offTip = off and off:FindFirstChild("OffTipAttachment")
	local offBase = off and off:FindFirstChild("OffBaseAttachment")
	if leftGrip and leftGrip:IsA("Weld") and offTip and offBase and offTip:IsA("Attachment") and offBase:IsA("Attachment") then
		S.lArm.blade = unit((leftGrip.C0 * leftGrip.C1:Inverse()):VectorToWorldSpace(offTip.Position - offBase.Position), HAND_BLADE)
	elseif off then
		S.toolDirty = true -- it replicates a moment after the Tool
	end
	local hand = character:FindFirstChild("RightHand")
	local grip = hand and hand:FindFirstChild("RightGrip")
	if not (grip and grip:IsA("JointInstance")) then
		S.toolDirty = true -- the grip weld comes a moment after the Tool
		return
	end
	local inHand = grip.C0 * grip.C1:Inverse()
	arm.gripOffset = inHand.Position - arm.wristInHand
	arm.grip = true
	-- the clips drive weapons into the ground (jump attack landings): a colliding weapon would bounce its owner up
	-- (seen 2026-10-14: the spawn-time starter sword's Handle read CanCollide = true on the client)
	-- ground guard: the bounding box of the Tool's visible parts in the Handle's frame (welded: fixed)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	local handleCF = (handle :: BasePart).CFrame
	for _, part in ipairs((tool :: Tool):GetDescendants()) do
		if part:IsA("BasePart") then
			if part.CanCollide then
				part.CanCollide = false
			end
			if part.Transparency < 1 and part.Name ~= "OffHand" then
				local rel = handleCF:ToObjectSpace(part.CFrame)
				local s = part.Size * 0.5
				for i = 0, 7 do
					local corner = rel:PointToWorldSpace(Vector3.new(if i % 2 == 0 then -s.X else s.X, if i % 4 < 2 then -s.Y else s.Y, if i < 4 then -s.Z else s.Z))
					lo, hi = lo:Min(corner), hi:Max(corner)
				end
			end
		end
	end
	if lo.X <= hi.X then
		local reach = 0
		local handOrigin = inHand:PointToObjectSpace(ZERO)
		for i = 0, 7 do
			local corner = Vector3.new(if i % 2 == 0 then lo.X else hi.X, if i % 4 < 2 then lo.Y else hi.Y, if i < 4 then lo.Z else hi.Z)
			S.corners[i + 1] = corner
			S.tipSide[i + 1] = true
			reach = math.max(reach, (corner - handOrigin).Magnitude)
		end
		S.toolReach = math.max(0.5, reach)
		S.handle = handle :: BasePart
	end
	local tip = handle:FindFirstChild("TipAttachment")
	local base = handle:FindFirstChild("BaseAttachment")
	if not (tip and base and tip:IsA("Attachment") and base:IsA("Attachment")) then
		return
	end
	local axis = tip.Position - base.Position
	if axis.Magnitude < 1e-3 then
		return
	end
	axis = axis.Unit
	-- corners beyond the hand along the weapon's axis are on the blade's side (lifting the blade raises them); a short
	-- weapon (under BLADE_MIN studs past the hand) is only lifted by the hand
	local handAlong = (inHand:PointToObjectSpace(ZERO) - base.Position):Dot(axis)
	local bladeLen = 0
	for i = 1, 8 do
		bladeLen = math.max(bladeLen, (S.corners[i] - base.Position):Dot(axis) - handAlong)
	end
	for i = 1, 8 do
		S.tipSide[i] = bladeLen >= BLADE_MIN and (S.corners[i] - base.Position):Dot(axis) > handAlong
	end
	local front = Vector3.new(0, 0, -1)
	for _, name in ipairs(FACE_POINTS) do
		local point = handle:FindFirstChild(name)
		if point and point:IsA("Attachment") then
			local side = point.Position - base.Position
			side -= axis * side:Dot(axis)
			if side.Magnitude > 0.05 then
				front = side
				break
			end
		end
	end
	front -= axis * front:Dot(axis)
	arm.blade = inHand:VectorToWorldSpace(axis)
	if front.Magnitude > 1e-3 then
		arm.face = inHand:VectorToWorldSpace(front.Unit)
		arm.weaponInv = CFrame.fromMatrix(ZERO, arm.blade, arm.face, arm.blade:Cross(arm.face)):Inverse()
	end
end

local function play(S: State, clip: Clip, rate1: number, rate2: number, kind: string, dir: Vector3?)
	local act = S.act
	if act.clip and act.w > 0 then
		-- the current action stays under the new one while it fades in
		S.act, S.prev = S.prev, act
		act = S.act
	end
	act.clip = clip
	act.t = 0
	act.w = 0
	act.fade = clip.fadeOut
	act.stopping = false
	act.rate1 = rate1
	act.rate2 = rate2
	act.kind = kind
	act.dir = dir
	act.frozen = false
	act.sync = false
	act.held = 0
	act.holdAt = nil
	act.phase = 0
	act.fin = false
	act.sig = nil
	act.sigW = 1
	act.late = false
	act.started = os.clock()
	act.lift = 0
	act.liftH = 0
	if kind == "attack" or kind == "roll" then
		S.moveLockUntil = os.clock() + MOVE_LOCK
	end
end

local function stopKind(slot: Slot, a: string, b: string?, fade: number?)
	local clip = slot.clip
	if clip and (slot.kind == a or slot.kind == b) and not slot.stopping then
		slot.stopping = true
		slot.fade = fade or clip.fadeOut
	end
end

local function playAdditive(S: State, clip: Clip)
	local add = S.add
	add.clip = clip
	add.t = 0
	add.w = 1
	add.stopping = false
	add.rate1 = 1
	add.rate2 = 1
	add.frozen = false
end

onDied = function(S: State)
	if S.dead then
		return
	end
	S.dead = true
	S.add.clip = nil
	local clip = clips.Shared_Death
	if clip and S.ready then
		play(S, clip, 1, 1, "death")
	end
end

-- A clip of the held weapon's style (Styles[WeaponId], e.g. RangedRifle), else of its category.
local function styled(S: State, suffix: string): Clip?
	local style, category = S.style, S.category
	return (if style then clips[style .. suffix] else nil) or (if category then clips[category .. suffix] else nil)
end

-- Equipped Tool -> category (and style) stance; a new weapon plays its Equip clip.
local function refreshTool(S: State, added: boolean)
	local tool = S.character:FindFirstChildOfClass("Tool")
	local category = tool and tool:GetAttribute("Category")
	local weaponId = tool and tool:GetAttribute("WeaponId")
	local id: string? = if typeof(category) == "string" then category else nil
	S.category = id
	local placeholder = tool and tool:GetAttribute("Placeholder") == true
	S.style = if id and not placeholder and typeof(weaponId) == "string" then STYLES[weaponId] else nil
	-- zone fighting style: the Tool's "Zone" (else its weapon's zone); dev override: local character attribute AnimZone
	local zone = S.character:GetAttribute("AnimZone")
	if typeof(zone) ~= "number" and typeof(zone) ~= "string" then
		zone = tool and tool:GetAttribute("Zone")
		if typeof(zone) ~= "number" and typeof(weaponId) == "string" then
			local def = Weapons.ById[weaponId]
			zone = def and def.Zone
		end
	end
	local zoneStyle = if id then CombatStyles.get(zone) else nil
	S.zstyle = if zoneStyle then zstyles[zoneStyle.Id] else nil
	local idle = if id then styled(S, "_Idle") else nil
	S.stanceOn = idle ~= nil
	if idle then
		if S.idle ~= idle then
			S.idleT = 0
		end
		S.idle = idle
		S.run = styled(S, "_Run")
		S.air = styled(S, "_Air")
	end
	S.toolDirty = true
	if added and id and S.ready and not S.dead then
		local equip = styled(S, "_Equip")
		local kind = if S.act.clip then S.act.kind else ""
		if equip and kind ~= "spawn" and kind ~= "death" and kind ~= "attack" and kind ~= "roll" then
			play(S, equip, 1, 1, "equip")
		end
	end
end

-- Zone style of an attack slot (after play): phase, finisher, signature overlay (Style_<Zone>_Finisher / _Jump).
local function styleSlot(S: State, slot: Slot, category: string, finisher: boolean, air: boolean)
	local Z = S.zstyle
	local clip = slot.clip
	if not Z or not clip or not clip.styled or not clip.hit then
		return
	end
	slot.phase = if air then 2 else 1
	slot.fin = finisher
	local name = if air then Z.jump elseif finisher then Z.finisher else nil
	local sig = if name then clips[name] else nil
	local gain = if sig and sig.gain then (sig.gain[category] or 1) else 1
	if sig and gain > 0 then
		slot.sig = sig
		slot.sigW = gain
		-- too short a wind-up for a spin before the strike: LateOk signatures play in the recovery
		slot.late = sig.lateOk and not air and (clip.hit :: number) / math.max(1e-3, slot.rate1) < LATE_WINDUP
	end
end

local function remove(character: Model)
	local S = states[character]
	if not S then
		return
	end
	states[character] = nil
	for _, conn in ipairs(S.conns) do
		conn:Disconnect()
	end
	if S.diedConn then
		S.diedConn:Disconnect()
	end
	local i = table.find(list, S)
	if i then
		list[i] = list[#list]
		list[#list] = nil
	end
end

local function add(character: Model, spawned: boolean)
	if states[character] then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	local S: State = {
		character = character,
		isLocal = player == Players.LocalPlayer,
		humanoid = nil,
		root = nil,
		joints = table.create(NJ, false),
		legs = { newLeg(C_RFOOT, C_RYAW, 10), newLeg(C_LFOOT, C_LYAW, 13) },
		rArm = newArm(),
		lArm = newArm(),
		pivot = CFrame.identity,
		scale = 1,
		dirty = true,
		retryAt = 0,
		ready = false,
		toolDirty = true,
		diedConn = nil,
		watched = nil,
		category = nil,
		style = nil,
		zstyle = nil,
		styleT = math.random() * 10, -- style waves: characters of one style do not bob in sync
		handle = nil,
		corners = table.create(8, ZERO),
		tipSide = table.create(8, true),
		toolReach = 1,
		liftEl = 0,
		liftH = 0,
		runEl = 0,
		runH = 0,
		blendEl = 0,
		blendH = 0,
		upper = nil,
		upT = Vector3.yAxis,
		clearT = 0,
		aimPitch = 0,
		idle = nil,
		run = nil,
		air = nil,
		stanceOn = false,
		stanceW = 0,
		standF = 1,
		runF = 0,
		airF = 0,
		idleT = 0,
		runT = 0,
		airT = 0,
		act = newSlot(),
		prev = newSlot(),
		add = newSlot(),
		blocking = false,
		dead = false,
		spawnUntil = if spawned then os.clock() + SPAWN_WINDOW else 0,
		moving = false,
		moveLockUntil = 0,
		conns = {},
	}
	states[character] = S
	table.insert(list, S)
	local function joint(d: Instance)
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") or d:IsA("Humanoid") or d.Name == "HumanoidRootPart" then
			S.dirty = true
			S.retryAt = 0 -- rebuild next frame (appearance loading adds the joints one by one)
		elseif d.Name == "RightGrip" then
			S.toolDirty = true
		end
	end
	table.insert(S.conns, character.DescendantAdded:Connect(joint))
	table.insert(S.conns, character.DescendantRemoving:Connect(joint))
	table.insert(S.conns, character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			refreshTool(S, true)
		end
	end))
	table.insert(S.conns, character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			refreshTool(S, false)
		end
	end))
	table.insert(S.conns, character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(game) then
			remove(character)
		end
	end))
	-- dev hooks (attributes set locally from the command bar, see the end of this file)
	table.insert(S.conns, character:GetAttributeChangedSignal("AnimDebug"):Connect(function()
		debugAttribute(S)
	end))
	table.insert(S.conns, character:GetAttributeChangedSignal("AnimProfile"):Connect(function()
		profileAttribute(character)
	end))
	table.insert(S.conns, character:GetAttributeChangedSignal("AnimReload"):Connect(function()
		reloadAttribute()
	end))
	table.insert(S.conns, character:GetAttributeChangedSignal("AnimZone"):Connect(function()
		refreshTool(S, false)
	end))
	refreshTool(S, false)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		add(character, true)
	end)
	player.CharacterRemoving:Connect(remove)
	if player.Character then
		add(player.Character, false)
	end
end

-- ------------------------------------------------------------------------------------------------
-- Frame update
-- ------------------------------------------------------------------------------------------------
local ALLOWED: { [Enum.HumanoidStateType]: boolean } = {
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
	[Enum.HumanoidStateType.Landed] = true,
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Freefall] = true,
	[Enum.HumanoidStateType.GettingUp] = true,
	[Enum.HumanoidStateType.Flying] = true,
	[Enum.HumanoidStateType.StrafingNoPhysics] = true,
	[Enum.HumanoidStateType.None] = true,
}
local GROUNDED: { [Enum.HumanoidStateType]: boolean } = {
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
	[Enum.HumanoidStateType.Landed] = true,
	[Enum.HumanoidStateType.None] = true,
}

-- air: 0 on the ground, 1 in the air and not diving, 2 diving (only computed for a synced jump attack)
local function advance(slot: Slot, dt: number, air: number)
	local clip = slot.clip
	if not clip then
		return
	end
	if slot.frozen then
		slot.w = 1
		return
	end
	if slot.stopping then
		slot.w -= dt / slot.fade
		if slot.w <= 0 then
			slot.clip = nil
			slot.w = 0
			return
		end
	elseif slot.w < 1 then
		slot.w = math.min(1, slot.w + dt / clip.fadeIn)
	end
	local t = slot.t
	local hit = clip.hit
	local holdAt = slot.holdAt
	if holdAt and t >= holdAt then
		slot.t = holdAt
		return
	end
	if hit and t < hit then
		local rate = slot.rate1
		local dive = clip.dive
		if slot.sync and dive and slot.held < SYNC_HOLD_MAX then
			-- local jump attack: the dive follows the body (wait while it hangs / is still in the air, catch up on landing)
			if air == 0 then
				if t >= 0.06 then
					rate *= CATCH_UP -- landed (the first frames may still read the floor under the jump)
				end
				t += dt * rate
			else
				local stop = if air == 1 then dive else hit - LAND_LEAD
				t += dt * rate
				if slot.t <= stop and t > stop then
					t = stop
					slot.held += dt
				end
			end
		else
			t += dt * rate
		end
		if t > hit then
			t = hit + (t - hit) / rate * slot.rate2
		end
	else
		t += dt * slot.rate2
	end
	if clip.loop then
		t %= clip.length
	elseif t >= clip.length then
		t = clip.length
		if clip.additive then
			slot.clip = nil
			slot.w = 0
		elseif not clip.hold and not slot.stopping then
			slot.stopping = true
			slot.fade = clip.fadeOut
		end
	end
	slot.t = t
end

local function solveArms(S: State, clip: Clip, out: { Vector3 })
	local tracks = clip.tracks
	local rArm, lArm = S.rArm, S.lArm
	local hand: CFrame?, wrist: Vector3? = nil, nil
	if clip.rArm then
		hand, wrist = solveArm(rArm, out, 4, wristTarget(rArm, out[C_RHAND]), if tracks[C_RPOLE] then out[C_RPOLE] else R_POLE,
			if tracks[C_RBLADE] then direction(out[C_RBLADE]) else nil, if tracks[C_RFACE] then direction(out[C_RFACE]) else nil)
	end
	if clip.lArm then
		local w = if tracks[C_LHAND] then wristTarget(lArm, out[C_LHAND]) else lArm.shoulder + DOWN
		local aim = if tracks[C_LBLADE] then direction(out[C_LBLADE]) else nil
		local g = out[C_LGRIP]
		local weight = clamp(g.Y, 0, 1)
		if hand and wrist and rArm.grip and weight > 0 then
			-- left hand on the weapon, g.X studs along its axis from the right hand's grip
			local axis = hand:VectorToWorldSpace(rArm.blade)
			local point = wrist + hand:VectorToWorldSpace(rArm.gripOffset) + axis * g.X
			w = w:Lerp(point + unit(lArm.shoulder - point, DOWN) * lArm.palm, weight)
			aim = if aim then unit(aim:Lerp(axis, weight), axis) else axis -- aim opposite to the axis: zero at weight 0.5
		end
		solveArm(lArm, out, 7, w, if tracks[C_LPOLE] then out[C_LPOLE] else L_POLE, aim, nil)
	end
end

-- Swing size of a styled attack around the clip's first pose: kt torso (root twist / lean unless the clip spins or
-- flips, waist, neck), ka arms (hand azimuth / height, blade directions), kl legs (steps, body shift; crouch at half
-- strength and never below CROUCH_FLOOR unless the clip goes there).
local function amplify(clip: Clip, out: { Vector3 }, lower: boolean, kt: number, ka: number, kl: number)
	local base = clip.base
	if kt ~= 1 then
		for c = 2, 3 do
			local b = base[c]
			out[c] = b + (out[c] - b) * kt
		end
		if lower then
			local r, b = out[1], base[1]
			out[1] = Vector3.new(if clip.spinX then r.X else b.X + (r.X - b.X) * kt, if clip.spinY then r.Y else b.Y + (r.Y - b.Y) * kt, r.Z)
		end
	end
	if ka ~= 1 then
		for pass = 1, 2 do
			local c = if pass == 1 then C_RHAND else C_LHAND
			local v, b = out[c], base[c]
			out[c] = Vector3.new(b.X + (v.X - b.X) * ka, b.Y + (v.Y - b.Y) * ka, v.Z)
			c = if pass == 1 then C_RBLADE else C_LBLADE
			v, b = out[c], base[c]
			out[c] = Vector3.new(b.X + (v.X - b.X) * ka, clamp(b.Y + (v.Y - b.Y) * ka, -1.9, 3.3), 0)
		end
	end
	if lower and kl ~= 1 then
		local v, b = out[C_ROOTP], base[C_ROOTP]
		local y = b.Y + (v.Y - b.Y) * (1 + (kl - 1) * 0.5)
		out[C_ROOTP] = Vector3.new(b.X + (v.X - b.X) * kl, math.max(y, math.min(v.Y, CROUCH_FLOOR)), b.Z + (v.Z - b.Z) * kl)
		for c = C_RFOOT, C_LFOOT do
			v, b = out[c], base[c]
			out[c] = Vector3.new(b.X + (v.X - b.X) * kl, math.max(b.Y + (v.Y - b.Y) * kl, math.min(v.Y, 0)), b.Z + (v.Z - b.Z) * kl)
		end
	end
end

-- Zone style on a freshly sampled styled clip (before the IK): swing size, attack waves and the signature's target
-- offsets (attack slots), posture (every clip), idle waves (the idle).
local function shape(S: State, Z: ZStyle, clip: Clip, t: number, out: { Vector3 }, lower: boolean, slot: Slot?, role: number)
	if slot and slot.phase > 0 then
		local hit = clip.hit :: number
		local m, g = 1, 1 -- follow-through multiplier, fade back to the clip's own size at the end
		if t > hit then
			local v = (t - hit) / math.max(1e-3, clip.length - hit)
			m = 1 + (Z.follow - 1) * smooth(v / 0.25)
			g = 1 - smooth((v - 0.5) / 0.5)
		end
		amplify(clip, out, lower, 1 + (Z.kt * m - 1) * g, 1 + (Z.ka * m - 1) * g, 1 + (Z.kl - 1) * g)
		if slot.lift > 0 or slot.liftH > 0 then
			liftTargets(S, out, slot.lift, slot.liftH) -- ground guard of the styled attack (see ACTION_DEPTH)
		end
		if #Z.attack > 0 then
			applyTerms(Z.attack, out, S.styleT, 1, lower)
		end
		local sig = slot.sig
		if sig then
			local st = sigTime(slot, clip, sig, t)
			local w = slot.sigW
			local tracks = sig.tracks
			for _, c in ipairs(SIG_PRE) do
				local tr = tracks[c]
				if tr and (lower or not LOWER_CH[c]) then
					out[c] += sample(tr, st) * w
				end
			end
		end
	end
	-- posture
	out[2] += Z.waist
	out[3] += Z.neck
	out[C_RHAND] += Z.rHand
	out[C_LHAND] += Z.lHand
	if lower then
		out[1] += Z.rootRot
		local p, d = out[C_ROOTP], Z.rootP
		out[C_ROOTP] = Vector3.new(p.X + d.X, math.max(p.Y + d.Y, math.min(p.Y, CROUCH_FLOOR)), p.Z + d.Z)
		out[C_RFOOT] += Z.rFoot
		out[C_LFOOT] += Z.lFoot
	end
	if role == ROLE_IDLE then
		-- the style's own guard (how the weapon is held at rest; the attacks start from the clip's guard)
		local k = if S.category then Z.guardGain[S.category] or 1 else 1
		out[C_RHAND] += Z.guardRHand * k
		out[C_RBLADE] += Z.guardRBlade * k
		out[C_LHAND] += Z.guardLHand * k
		if #Z.idle > 0 then
			applyTerms(Z.idle, out, S.styleT, 1, lower)
		end
	end
end

-- Samples a clip into out (upper body + arm IK unless arms = false; root, legs and leg IK when lower). slot = the
-- action slot playing it (nil for the stance), role = ROLE_ACTION / ROLE_IDLE / ROLE_STANCE (run, air): the zone style.
local function sampleInto(S: State, clip: Clip, t: number, out: { Vector3 }, lower: boolean, wrapRoot: boolean, yawAdd: number, arms: boolean, slot: Slot?, role: number)
	local tracks = clip.tracks
	local Z = if clip.styled then S.zstyle else nil
	local ts = t
	if Z then
		if slot and slot.phase > 0 then
			ts = warpTime(Z, clip, t, slot)
			linearEase = Z.linear
		elseif role == ROLE_IDLE then
			if Z.idleStep > 0 then
				ts = t - t % Z.idleStep
			end
			linearEase = Z.linear
		end
	end
	for c = 2, 9 do
		local tr = tracks[c]
		out[c] = if tr then sample(tr, ts) else ZERO
	end
	for c = C_RHAND, C_LGRIP do
		local tr = tracks[c]
		out[c] = if tr then sample(tr, ts) else ZERO
	end
	if lower then
		local tr = tracks[1]
		out[1] = if tr then sample(tr, ts) else ZERO
		for c = 10, C_LYAW do
			local track = tracks[c]
			out[c] = if track then sample(track, ts) else ZERO
		end
	end
	linearEase = false
	if Z then
		shape(S, Z, clip, t, out, lower, slot, role)
	end
	if role ~= ROLE_ACTION then
		-- ground guard: lift the stance's weapon out of the ground
		local el = (if role == ROLE_IDLE then S.liftEl else S.runEl) + S.blendEl
		local height = (if role == ROLE_IDLE then S.liftH else S.runH) + S.blendH
		if el > 0 or height > 0 then
			liftTargets(S, out, el, height)
		end
	end
	if arms then
		solveArms(S, clip, out)
	end
	if not lower then
		return
	end
	if wrapRoot then
		local r = out[1]
		out[1] = Vector3.new(wrap(r.X), wrap(r.Y + yawAdd), wrap(r.Z))
	end
	if clip.legIK then
		solveLegs(S, out)
	end
end

-- "Over" compositing of one layer into acc: group weights wU (upper body) and wL (root + legs).
local covU, covL = 0, 0
local function layer(out: { Vector3 }, wU: number, wL: number)
	if wU > 0 then
		local nc = 1 - (1 - covU) * (1 - wU)
		local k = wU / nc
		for c = 2, 9 do
			acc[c] = if covU == 0 then out[c] else acc[c]:Lerp(out[c], k)
		end
		covU = nc
	end
	if wL > 0 then
		local nc = 1 - (1 - covL) * (1 - wL)
		local k = wL / nc
		local first = covL == 0
		acc[1] = if first then out[1] else acc[1]:Lerp(out[1], k)
		for c = 10, C_ROOTP do
			acc[c] = if first then out[c] else acc[c]:Lerp(out[c], k)
		end
		covL = nc
	end
end

local function actionLayer(S: State, slot: Slot)
	local clip = slot.clip
	if not clip or slot.w <= 0 or clip.additive then
		return
	end
	local w = slot.w
	local wL = if clip.legs == 2 then w elseif clip.legs == 1 then w * S.standF else 0
	local yawAdd = 0
	local root = S.root
	local dir = slot.dir
	if dir and root then
		local lv = root.CFrame:VectorToObjectSpace(dir)
		yawAdd = atan2(-lv.X, -lv.Z)
	end
	sampleInto(S, clip, slot.t, scratchA, wL > 0, true, yawAdd, true, slot, ROLE_ACTION)
	local pitch = S.aimPitch
	if clip.aimPitch and pitch ~= 0 then
		-- aim up / down: the torso leans (the arms follow, their targets are torso-relative)
		scratchA[2] += Vector3.new(pitch * 0.75, 0, 0)
		scratchA[3] += Vector3.new(pitch * 0.25, 0, 0)
	end
	layer(scratchA, w, wL)
end

-- One ground guard update from the gaps of the weapon's blade side (tip) and pommel side (butt) to the allowed level
-- (negative = too low): the blade elevation lifts a low tip, the hand rises for a low butt, when both ends are low or
-- when the elevation is spent; both relax once clear. Returns elevation, height.
local function guardStep(gapT: number, gapB: number, el: number, height: number, reach: number, relaxEl: number, relaxH: number, dt: number): (number, number)
	if gapT < 0 and gapB < 0 then
		height = math.min(LIFT_H_MAX, height + math.min(LIFT_H_STEP, -math.min(gapT, gapB)))
	elseif gapT < 0 then
		if el < LIFT_EL_MAX then
			el = math.min(LIFT_EL_MAX, el + math.min(LIFT_EL_STEP, -gapT / reach))
		else
			height = math.min(LIFT_H_MAX, height + math.min(LIFT_H_STEP, -gapT))
		end
	elseif gapB < 0 then
		height = math.min(LIFT_H_MAX, height + math.min(LIFT_H_STEP, -gapB))
	elseif math.min(gapT, gapB) > GROUND_SLACK then
		el = math.max(0, el - dt * relaxEl)
		height = math.max(0, height - dt * relaxH)
	end
	return el, height
end

local function step(S: State, dt: number, now: number, camPos: Vector3)
	if S.dirty and now >= S.retryAt then
		rebuild(S)
		if not S.ready then
			S.dirty = true
			S.retryAt = now + 0.5
		end
	end
	if not S.ready then
		return
	end
	local humanoid = S.humanoid :: Humanoid
	local root = S.root :: BasePart
	if not root.Parent or not humanoid.Parent then
		S.dirty = true
		return
	end
	if S.spawnUntil > 0 then
		if now < S.spawnUntil and not S.dead and clips.Shared_Spawn then
			play(S, clips.Shared_Spawn, 1, 1, "spawn")
		end
		S.spawnUntil = 0
	end
	if S.toolDirty then
		measureTool(S)
	end
	-- movement factors
	local state = humanoid:GetState()
	local allowed = ALLOWED[state] == true
	local moving = S.moving
	if now >= S.moveLockUntil then
		local v = root.AssemblyLinearVelocity
		moving = v.X * v.X + v.Z * v.Z > MOVE_SPEED * MOVE_SPEED
	end
	if S.isLocal and humanoid.MoveDirection.Magnitude > 0.05 then
		moving = true
	end
	S.moving = moving
	local floorAir = humanoid.FloorMaterial == Enum.Material.Air
	local standing = GROUNDED[state] == true and not floorAir and not moving
	local airborne = floorAir and (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping)
	S.standF = approach(S.standF, if standing then 1 else 0, dt / STAND_FADE)
	S.runF = approach(S.runF, if moving then 1 else 0, dt / RUN_FADE)
	S.airF = approach(S.airF, if airborne then 1 else 0, dt / AIR_FADE)
	S.stanceW = approach(S.stanceW, if S.stanceOn and allowed and not S.dead then 1 else 0, dt / STANCE_FADE)
	local air = 0
	if S.act.sync and floorAir then
		air = if root.AssemblyLinearVelocity.Y < -DIVE_VY then 2 else 1
	end
	local act = S.act
	local before, hitClip = act.t, act.clip
	advance(act, dt, air)
	advance(S.prev, dt, air)
	advance(S.add, dt, 0)
	if hitClip and hitClip.hit and act.kind == "attack" and act.clip == hitClip and before < hitClip.hit and act.t >= hitClip.hit
		and S.character:GetAttribute("AnimHitDebug") == true then
		-- dev check (attribute AnimHitDebug = true): real seconds from the attack call to the frame the clip reached Hit,
		-- and the clip time the styled pose shows there (= Hit: the style keeps the Hit pose on the Hit time)
		local Z = if hitClip.styled then S.zstyle else nil
		S.character:SetAttribute("AnimHitAt", now - act.started)
		S.character:SetAttribute("AnimHitPose", if Z and act.phase > 0 then warpTime(Z, hitClip, hitClip.hit, act) else hitClip.hit)
		S.character:SetAttribute("AnimHitClip", `{hitClip.name} {if Z then Z.id else "-"}{if act.sig then " " .. act.sig.name else ""}{if act.late then " late" else ""}`)
	end
	if act.clip and act.w >= 1 then
		S.prev.clip = nil
	end
	local Z = S.zstyle
	S.styleT = (S.styleT + dt) % 3600
	local idle, run, airClip = S.idle, S.run, S.air
	if idle then
		S.idleT = (S.idleT + dt * (if Z and idle.styled then Z.idleRate else 1)) % idle.length
	end
	if run then
		S.runT = (S.runT + dt) % run.length
	end
	if airClip then
		S.airT = (S.airT + dt) % airClip.length
	end
	if (root.Position - camPos).Magnitude > RANGE then
		return
	end
	local upper = S.upper
	if upper then
		S.upT = upper.CFrame:VectorToObjectSpace(Vector3.yAxis)
	end
	-- ground guard (from last frame's pose, ground = under the standing character): the stance alone (no action clip)
	-- keeps the weapon above the ground; a styled attack keeps it at most ACTION_DEPTH x its reach under it
	local handle = S.handle
	local stanceOnly = S.stanceW > 0.5 and not (act.clip and act.w > 0.01) and not (S.prev.clip and S.prev.w > 0.01)
	local styledAct = act.clip ~= nil and act.phase > 0 and act.w > 0.5
	if handle and not floorAir and (stanceOnly or styledAct) then
		local groundY = root.Position.Y - root.Size.Y * 0.5 - humanoid.HipHeight
		local cf = handle.CFrame
		local corners, tipSide = S.corners, S.tipSide
		local tipLow, buttLow = math.huge, math.huge
		for i = 1, 8 do
			local y = cf:PointToWorldSpace(corners[i]).Y
			if tipSide[i] then
				tipLow = math.min(tipLow, y)
			else
				buttLow = math.min(buttLow, y)
			end
		end
		if stanceOnly then
			local level = groundY + GROUND_MARGIN
			-- relax only after CLEAR_HOLD clear seconds: the run cycle and the idle waves dip the weapon periodically
			S.clearT = if math.min(tipLow, buttLow) - level > GROUND_SLACK then S.clearT + dt else 0
			local relax = S.clearT > CLEAR_HOLD
			local relaxEl, relaxH = if relax then LIFT_EL_RELAX else 0, if relax then LIFT_H_RELAX else 0
			if S.runF > 0.05 and S.runF < 0.95 then
				-- the blend moves the weapon fast: aim BLEND_LEAD higher (this lift fades once the blend is over)
				S.blendEl, S.blendH = guardStep(tipLow - level - BLEND_LEAD, buttLow - level - BLEND_LEAD, S.blendEl, S.blendH, S.toolReach, BLEND_RELAX, BLEND_RELAX, dt)
			elseif S.runF > 0.5 or S.airF > 0.5 then
				-- the run cycle swings the weapon fast: keep RUN_LEAD more clearance
				S.runEl, S.runH = guardStep(tipLow - level - RUN_LEAD, buttLow - level - RUN_LEAD, S.runEl, S.runH, S.toolReach, relaxEl, relaxH, dt)
			else
				S.liftEl, S.liftH = guardStep(tipLow - level, buttLow - level, S.liftEl, S.liftH, S.toolReach, relaxEl, relaxH, dt)
			end
			if (S.runF <= 0.05 or S.runF >= 0.95) and (S.blendEl > 0 or S.blendH > 0) and math.min(tipLow, buttLow) - level > GROUND_SLACK then
				-- after the blend its lift fades, but only while the weapon is clear (it never drops the weapon in)
				S.blendEl = math.max(0, S.blendEl - dt * BLEND_RELAX)
				S.blendH = math.max(0, S.blendH - dt * BLEND_RELAX)
			end
		else
			local level = groundY - ACTION_DEPTH * S.toolReach
			act.lift, act.liftH = guardStep(tipLow - level, buttLow - level, act.lift, act.liftH, S.toolReach, ACTION_RELAX, ACTION_RELAX, dt)
		end
	end
	-- layers
	covU, covL = 0, 0
	local stanceW = S.stanceW
	if stanceW > 0 and idle then
		local wL = stanceW * S.standF
		local runF, airF = S.runF, S.airF
		local useRun = runF > 0 and run ~= nil
		local useAir = airF > 0 and airClip ~= nil
		if useRun or useAir then
			-- idle -> run -> air (upper body): blend the IK targets (hands, blade) when the clips all use them, then
			-- solve once; else blend the solved joints
			local targets = (not run or not useRun or (idle.rArm == run.rArm and idle.lArm == run.lArm))
				and (not airClip or not useAir or (idle.rArm == airClip.rArm and idle.lArm == airClip.lArm))
			sampleInto(S, idle, S.idleT, scratchA, wL > 0, false, 0, not targets, nil, ROLE_IDLE)
			for pass = 1, 2 do
				local clip = if pass == 1 then (if useRun then run else nil) else (if useAir then airClip else nil)
				if clip then
					local f = if pass == 1 then runF else airF
					sampleInto(S, clip, if pass == 1 then S.runT else S.airT, scratchB, false, false, 0, not targets, nil, ROLE_STANCE)
					for c = 2, 9 do
						scratchA[c] = scratchA[c]:Lerp(scratchB[c], f)
					end
					if targets then
						for c = C_RHAND, C_LGRIP do
							scratchA[c] = scratchA[c]:Lerp(scratchB[c], f)
						end
					end
				end
			end
			if targets then
				solveArms(S, idle, scratchA)
			end
		else
			sampleInto(S, idle, S.idleT, scratchA, wL > 0, false, 0, true, nil, ROLE_IDLE)
		end
		layer(scratchA, stanceW, wL)
	end
	actionLayer(S, S.prev)
	actionLayer(S, S.act)
	-- zone style signature: joint rotations and the whole-body Lift of the attack slots' overlays (weighted by the slot)
	local sigOn = false
	local sigP = ZERO
	for pass = 1, 2 do
		local slot = if pass == 1 then S.act else S.prev
		local sig, clip = slot.sig, slot.clip
		if sig and clip and slot.w > 0 then
			local st = sigTime(slot, clip, sig, slot.t)
			local w = slot.w * slot.sigW
			local tracks = sig.tracks
			if not sigOn then
				sigOn = true
				for c = 1, NJ do
					sigJ[c] = ZERO
				end
			end
			for c = 1, NJ do
				local tr = tracks[c]
				if tr then
					local v = sample(tr, st)
					sigJ[c] += Vector3.new(wrap(v.X), wrap(v.Y), wrap(v.Z)) * w
				end
			end
			local lt = tracks[C_LIFT]
			if lt then
				sigP += sample(lt, st) * w
			end
		end
	end
	-- write (blend with the Animator's pose of this frame), additive on top
	local addClip = S.add.clip
	local addT, addW = S.add.t, S.add.w
	local joints = S.joints
	local scale = S.scale
	for c = 1, NJ do
		local cov = if c >= 2 and c <= 9 then covU else covL
		local addTrack = addClip and (addClip.tracks[c] or (c == 1 and addClip.tracks[C_ROOTP]))
		local sj = if sigOn then sigJ[c] else ZERO
		local lift = if c == 1 then sigP else ZERO
		if cov > 0.001 or addTrack or sj ~= ZERO or lift ~= ZERO then
			local joint = joints[c]
			local cf
			if cov > 0.001 then
				local r = acc[c]
				cf = CFrame.fromEulerAnglesYXZ(r.X, r.Y, r.Z)
				if c == 1 then
					cf += acc[C_ROOTP] * scale
				end
				if cov < 0.999 then
					cf = joint.Transform:Lerp(cf, cov)
				end
			else
				cf = joint.Transform
			end
			if addTrack and addClip then
				local rt = addClip.tracks[c]
				local a = if rt then sample(rt, addT) * addW else ZERO
				local offset = CFrame.fromEulerAnglesYXZ(a.X, a.Y, a.Z)
				if c == 1 then
					local pt = addClip.tracks[C_ROOTP]
					if pt then
						offset += sample(pt, addT) * (addW * scale)
					end
				end
				cf *= offset
			end
			if sj ~= ZERO then
				cf *= CFrame.fromEulerAnglesYXZ(sj.X, sj.Y, sj.Z)
			end
			if lift ~= ZERO then
				cf += lift * scale -- in the root's parent frame: straight up / ahead whatever the lean
			end
			-- never write a NaN: it would make the body vanish (the Animator's pose stays for this frame)
			local p, l, r = cf.Position, cf.LookVector, cf.RightVector
			local check = p.X + p.Y + p.Z + l.X + l.Y + l.Z + r.X + r.Y + r.Z
			if check == check then
				joint.Transform = cf
			else
				nanSkips += 1
				S.character:SetAttribute("AnimNaNSkips", nanSkips) -- debug: should stay absent
				if nanSkips == 1 then
					warn(`Animations: refused a NaN pose (joint {PARTS[c]}, clip {if S.act.clip then S.act.clip.name else "stance"}) - please report`)
				end
			end
		end
	end
end

local cost, frames = 0, 0
RunService.PreSimulation:Connect(function(dt: number)
	local started = os.clock()
	local camera = workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else ZERO
	for i = #list, 1, -1 do
		local S = list[i]
		if S then
			step(S, dt, started, camPos)
		end
	end
	cost += os.clock() - started
	frames += 1
end)

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)

-- ------------------------------------------------------------------------------------------------
-- API (docs/COMBAT_CONTRACTS.md)
-- ------------------------------------------------------------------------------------------------
-- The clip of a move: its own Clip, the variant's clip of the weapon style or category; own = false: the step's clip.
local function moveClip(S: State?, category: string, step: number, variant: string?, def: { [string]: any }?): (Clip?, boolean)
	local style = if S and S.category == category then S.style else nil
	local suffix = if variant then VARIANTS[variant] else nil
	local clip = if def and def.Clip then clips[def.Clip] else nil
	if not clip and suffix and def then
		clip = (if style then clips[style .. suffix] else nil) or clips[category .. suffix]
	end
	if clip then
		return clip, true
	end
	return (if style then clips[`{style}_Attack{step}`] else nil) or clips[`{category}_Attack{step}`], false
end

function Animations.attack(character: Model, category: string, step: number, speed: number, aim: Vector3?, variant: string?): number
	local S = states[character]
	local known = if typeof(variant) == "string" and VARIANTS[variant] then variant else nil
	local def = WeaponMoves.move(category, step, known)
	local clip, own = moveClip(S, category, step, known, def)
	if not clip then
		return 0
	end
	local sp = if typeof(speed) == "number" and speed > 0 then speed else 1
	if not def then
		def = WeaponMoves.move(category, step)
	end
	local hit = clip.hit
	local impact = (if def and typeof(def.Impact) == "number" then def.Impact else hit or 0) / sp
	local rate1 = if hit and hit > 0 and impact > 0 then hit / impact else sp
	local length = if hit then impact + (clip.length - hit) / sp else clip.length / sp
	local act = if S then S.act else nil
	if act and known == "Heavy" and act.clip == clip and act.holdAt and hit then
		-- the release of a charged wind-up: what is left of it lands on the Impact
		act.holdAt = nil
		act.rate1 = if impact > 0 then math.max(0.01, hit - act.t) / impact else sp
		return length
	end
	if S and S.ready and not S.dead then
		local unit = if typeof(aim) == "Vector3" and aim.Magnitude > 1e-3 then aim.Unit else nil
		S.aimPitch = if unit then clamp(asin(clamp(unit.Y, -1, 1)), -AIM_PITCH_MAX, AIM_PITCH_MAX) else 0
		play(S, clip, rate1, sp, "attack")
		S.act.sync = own and S.isLocal and variant == "Air" and clip.dive ~= nil
		local air = known == "Air"
		styleSlot(S, S.act, category, air or known == "Heavy" or (known == nil and def ~= nil and def.Finisher == true), air)
	end
	return length
end

function Animations.charge(character: Model, category: string, speed: number)
	local S = states[character]
	local def = WeaponMoves.move(category, 1, "Heavy")
	local clip = moveClip(S, category, 1, "Heavy", def)
	if S and clip and S.ready and not S.dead then
		local sp = if typeof(speed) == "number" and speed > 0 then speed else 1
		play(S, clip, sp, sp, "attack")
		S.act.holdAt = clip.charge or (clip.hit or clip.length) * CHARGE_POINT
	end
end

function Animations.aim(character: Model, direction: Vector3)
	local S = states[character]
	if S and direction.Magnitude > 1e-3 then
		S.aimPitch = clamp(asin(clamp(direction.Unit.Y, -1, 1)), -AIM_PITCH_MAX, AIM_PITCH_MAX)
	end
end

function Animations.cancel(character: Model)
	local S = states[character]
	if S then
		stopKind(S.act, "attack", "equip", CANCEL_FADE)
		stopKind(S.prev, "attack", "equip", CANCEL_FADE)
	end
end

function Animations.block(character: Model, on: boolean)
	local S = states[character]
	if not S then
		return
	end
	S.blocking = on == true
	if S.blocking then
		local clip = styled(S, "_Block")
		if clip and S.ready and not S.dead then
			play(S, clip, 1, 1, "block")
		end
	else
		stopKind(S.act, "block")
		stopKind(S.prev, "block")
	end
end

function Animations.blockHit(character: Model)
	local S = states[character]
	local clip = if S then styled(S, "_BlockHit") else nil
	if S and clip and S.ready and not S.dead then
		playAdditive(S, clip)
	end
end

function Animations.roll(character: Model, direction: Vector3)
	local S = states[character]
	local clip = clips.Shared_Roll
	if S and clip and S.ready and not S.dead then
		local flat = if typeof(direction) == "Vector3" then Vector3.new(direction.X, 0, direction.Z) else ZERO
		play(S, clip, 1, 1, "roll", if flat.Magnitude > 1e-3 then flat.Unit else nil)
	end
end

function Animations.hurt(character: Model)
	local S = states[character]
	-- two flinches picked at random (Shared_Hit2 optional)
	local clip = if clips.Shared_Hit2 and math.random() < 0.5 then clips.Shared_Hit2 else clips.Shared_Hit
	if S and clip and S.ready and not S.dead then
		playAdditive(S, clip)
	end
end

-- Filmstrip capture and other dev hooks (Play, Client command bar; local attributes on a character, never replicated):
--   character:SetAttribute("AnimDebug", "Sword_Attack1@0.16")  holds that clip at that time ("" or nil releases);
--                                                   "Ranged_Attack1@0.3@20" also pitches AimPitch clips by 20 deg
--   character:SetAttribute("AnimProfile", os.clock())  -> attributes AnimCostMs (average update of ALL characters,
--                                                        ms per frame since the previous request) and AnimChars
--   character:SetAttribute("AnimReload", os.clock())   recompiles every clip from a fresh copy of
--                                                        Config/CombatAnimations (tuning in Play after its Source
--                                                        was replaced from the command line); AnimReloaded = clip count
--   character:SetAttribute("AnimZone", "Void")          plays the held weapon in that zone's style (index or id; nil =
--                                                        the Tool's zone): AnimDebug poses then show that style
--   character:SetAttribute("AnimHitDebug", true)        each attack sets AnimHitAt (seconds from the call to the frame
--                                                        the clip reached Hit), AnimHitPose (clip time the styled pose
--                                                        shows then: = Hit) and AnimHitClip (clip, style, signature)
debugAttribute = function(S: State)
	local value = S.character:GetAttribute("AnimDebug")
	local name, at, pitch = string.match(if typeof(value) == "string" then value else "", "^([%w_]+)@?([%d%.]*)@?(%-?[%d%.]*)$")
	local clip = if name then clips[name] else nil
	if clip and S.ready then
		refreshTool(S, false) -- re-reads the Tool (style, grip) for tests that change it locally
		S.aimPitch = math.rad(tonumber(pitch) or 0)
		play(S, clip, 1, 1, "debug")
		S.act.w = 1
		S.act.t = tonumber(at) or 0
		S.act.frozen = true
		S.prev.clip = nil
		-- the zone style of the held weapon as in a real attack (<Category>_AttackN / _JumpAttack / _DashAttack)
		local rest = string.match(name, "^%a+_(%a+%d*)$") or ""
		local stepIndex = tonumber(string.match(rest, "^Attack(%d+)$"))
		local category = S.category
		local def = if category and stepIndex then WeaponMoves.move(category, stepIndex) else nil
		local finisher = def ~= nil and def.Finisher == true
		if category and (stepIndex or rest == "JumpAttack" or rest == "DashAttack" or rest == "Heavy") then
			styleSlot(S, S.act, category, finisher or rest == "JumpAttack" or rest == "Heavy", rest == "JumpAttack")
		end
	elseif S.act.kind == "debug" then
		S.act.clip = nil
		S.prev.clip = nil
	end
end

profileAttribute = function(character: Model)
	character:SetAttribute("AnimCostMs", if frames > 0 then cost / frames * 1000 else 0)
	character:SetAttribute("AnimChars", #list)
	cost, frames = 0, 0
end

reloadAttribute = function()
	local source = ReplicatedStorage.GameSystem.Config:FindFirstChild("CombatAnimations")
	if not (source and source:IsA("ModuleScript")) then
		return
	end
	local copy = source:Clone()
	copy.Name = "CombatAnimationsReload"
	copy.Parent = source.Parent
	local ok, data = pcall(require, copy)
	copy:Destroy()
	if not ok or typeof(data) ~= "table" or typeof(data.Clips) ~= "table" then
		warn("Animations: reload failed", data)
		return
	end
	compileAll(data)
	local count = 0
	for _ in pairs(clips) do
		count += 1
	end
	for _, S in ipairs(list) do
		S.act.clip, S.prev.clip, S.add.clip = nil, nil, nil
		S.idle, S.run, S.air = nil, nil, nil
		refreshTool(S, false)
		S.character:SetAttribute("AnimReloaded", count)
	end
end

return Animations
