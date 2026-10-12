--!strict
-- Player combat animations (docs/weapons_combat_brief.txt 4B, contract in docs/COMBAT_CONTRACTS.md).
-- OWNER: the Animation sub-agent. CombatController calls only the functions below; keep their names and arguments.
--   Animations.attack(character, category, step, speed) -> length   one combo step (Config/Combat Combos); the clip's
--                                                                   "Hit" marker lands at the step's Impact / speed;
--                                                                   returns the clip length in seconds at that speed
--   Animations.cancel(character)                 stops the attack clip quickly (Roll / Block cancels)
--   Animations.hitStop(character, seconds)       plays the character's clips at Combat.Feel.HitStopSpeed
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
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Combat = require(ReplicatedStorage.GameSystem.Config.Combat)
local Data = require(ReplicatedStorage.GameSystem.Config.CombatAnimations)

local Animations = {}
local STYLES: { [string]: string } = Data.Styles or {}

local RANGE = 150 -- studs from the camera
local REF_HIP = 2 -- HipHeight the clip positions are authored for
local REF_ARM = 1.14 -- shoulder -> wrist length the hand targets are authored for
local HIT_STOP_SPEED = Combat.Feel.HitStopSpeed
local CANCEL_FADE = 0.08
local STAND_FADE, RUN_FADE, STANCE_FADE = 0.12, 0.18, 0.2
local MOVE_SPEED = 1.5 -- studs / s: a character counts as moving above this (or with move input, local player)
local MOVE_LOCK = 0.35 -- seconds after an attack / roll start during which the lunge / dash speed is ignored
local SPAWN_WINDOW = 3 -- a new character plays Shared_Spawn if its joints are ready within this many seconds
local TWIST_MAX = math.rad(110) -- forearm twist toward the blade
local AIM_PITCH_MAX = math.rad(40) -- torso pitch toward the attack's aim (AimPitch clips)

local PI, TAU = math.pi, math.pi * 2
local ZERO = Vector3.zero
local HAND_BLADE = Vector3.new(0, 0, -1) -- weapon direction in the hand's frame until the Tool is measured
local R_POLE = Vector3.new(0.7, -0.6, 0.4).Unit
local L_POLE = Vector3.new(-0.7, -0.6, 0.4).Unit
local DOWN = Vector3.new(0, -1, 0)
local FACE_POINTS = { "MuzzleAttachment", "ImpactAttachment" }
local sin, cos, atan2, acos, asin, sqrt, clamp, abs = math.sin, math.cos, math.atan2, math.acos, math.asin, math.sqrt, math.clamp, math.abs

-- Channels: 1-15 joint rotations (radians, YXZ), then positions and IK goals.
local NAMES = {
	"Root", "Waist", "Neck", "RShoulder", "RElbow", "RWrist", "LShoulder", "LElbow", "LWrist",
	"RHip", "RKnee", "RAnkle", "LHip", "LKnee", "LAnkle",
	"RootP", "RFoot", "LFoot", "RFootYaw", "LFootYaw", "RHand", "RBlade", "RPole", "LHand", "LBlade", "LPole",
	"RFace", "LGrip",
}
local PARTS = {
	"LowerTorso", "UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm",
	"LeftHand", "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
}
local NJ, NCH = 15, #NAMES
local C_ROOTP, C_RFOOT, C_LFOOT, C_RYAW, C_LYAW = 16, 17, 18, 19, 20
local C_RHAND, C_RBLADE, C_RPOLE, C_LHAND, C_LBLADE, C_LPOLE = 21, 22, 23, 24, 25, 26
local C_RFACE, C_LGRIP = 27, 28 -- C_LGRIP is the last arm channel
local LEGS = { Upper = 0, Stand = 1, Own = 2 }
local EASE = { s = 0, l = 1, i = 2, o = 3, O = 4 }

type Track = { times: { number }, values: { Vector3 }, eases: { number }, n: number }
type Clip = {
	name: string, length: number, loop: boolean, legs: number, additive: boolean, hold: boolean,
	fadeIn: number, fadeOut: number, hit: number?, legIK: boolean, rArm: boolean, lArm: boolean, aimPitch: boolean,
	tracks: { Track | false },
}
type Slot = { clip: Clip?, t: number, w: number, fade: number, stopping: boolean, rate1: number, rate2: number, kind: string, dir: Vector3?, frozen: boolean }
type Leg = { hipLocal: Vector3, rest: Vector3, l1: number, l2: number, goal: number, yaw: number, hip: number, knee: number, ankle: number }
type Arm = {
	shoulder: Vector3, l1: number, l2: number, invF1: CFrame, invF2: CFrame, scale: number, axis2: Vector3, palm: number,
	wristInHand: Vector3, blade: Vector3, face: Vector3, weaponInv: CFrame, gripOffset: Vector3, grip: boolean,
}
type State = {
	character: Model, isLocal: boolean, humanoid: Humanoid?, root: BasePart?,
	joints: { any }, legs: { Leg }, rArm: Arm, lArm: Arm, pivot: CFrame, scale: number,
	dirty: boolean, retryAt: number, ready: boolean, toolDirty: boolean, diedConn: RBXScriptConnection?, watched: Humanoid?,
	category: string?, style: string?, idle: Clip?, run: Clip?, stanceOn: boolean, aimPitch: number,
	stanceW: number, standF: number, runF: number, idleT: number, runT: number,
	act: Slot, prev: Slot, add: Slot,
	hitStopUntil: number, blocking: boolean, dead: boolean, spawnUntil: number,
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
					vec = Vector3.new(v[1], v[2], v[3]).Unit
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
		legIK = not rawLegs,
		rArm = tracks[C_RHAND] ~= false,
		lArm = tracks[C_LHAND] ~= false or tracks[C_LGRIP] ~= false,
		aimPitch = def.AimPitch == true,
		tracks = tracks,
	}
end

for name, def in pairs(Data.Clips) do
	clips[name] = compile(name, def)
end

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
			return values[i - 1]:Lerp(values[i], ease((t - a) / (b - a), track.eases[i]))
		end
	end
	return values[n]
end

local function wrap(a: number): number
	return (a + PI) % TAU - PI
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
	local y = -v.Unit
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
	end
	perp = perp.Unit
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
		local axis = fa.Unit
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
local list: { State } = {}

local scratchA: { Vector3 } = table.create(NCH, ZERO)
local scratchB: { Vector3 } = table.create(NCH, ZERO)
local acc: { Vector3 } = table.create(NCH, ZERO)

local function newSlot(): Slot
	return { clip = nil, t = 0, w = 0, fade = 0.1, stopping = false, rate1 = 1, rate2 = 1, kind = "", dir = nil, frozen = false }
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
-- crossbow top, gun side, gauntlet back of the hand) and the Handle's origin from the wrist.
local function measureTool(S: State)
	S.toolDirty = false
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
	local hand = character:FindFirstChild("RightHand")
	local grip = hand and hand:FindFirstChild("RightGrip")
	if not (grip and grip:IsA("JointInstance")) then
		S.toolDirty = true -- the grip weld comes a moment after the Tool
		return
	end
	local inHand = grip.C0 * grip.C1:Inverse()
	arm.gripOffset = inHand.Position - arm.wristInHand
	arm.grip = true
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
	local idle = if id then styled(S, "_Idle") else nil
	S.stanceOn = idle ~= nil
	if idle then
		if S.idle ~= idle then
			S.idleT = 0
		end
		S.idle = idle
		S.run = styled(S, "_Run")
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
		aimPitch = 0,
		idle = nil,
		run = nil,
		stanceOn = false,
		stanceW = 0,
		standF = 1,
		runF = 0,
		idleT = 0,
		runT = 0,
		act = newSlot(),
		prev = newSlot(),
		add = newSlot(),
		hitStopUntil = 0,
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

local function advance(slot: Slot, dt: number, sdt: number)
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
	if hit and t < hit then
		t += sdt * slot.rate1
		if t > hit then
			t = hit + (t - hit) / slot.rate1 * slot.rate2
		end
	else
		t += sdt * slot.rate2
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
			w = w:Lerp(point + (lArm.shoulder - point).Unit * lArm.palm, weight)
			aim = if aim then aim:Lerp(axis, weight).Unit else axis
		end
		solveArm(lArm, out, 7, w, if tracks[C_LPOLE] then out[C_LPOLE] else L_POLE, aim, nil)
	end
end

-- Samples a clip into out (upper body + arm IK unless arms = false; root, legs and leg IK when lower).
local function sampleInto(S: State, clip: Clip, t: number, out: { Vector3 }, lower: boolean, wrapRoot: boolean, yawAdd: number, arms: boolean)
	local tracks = clip.tracks
	for c = 2, 9 do
		local tr = tracks[c]
		out[c] = if tr then sample(tr, t) else ZERO
	end
	for c = C_RHAND, C_LGRIP do
		local tr = tracks[c]
		out[c] = if tr then sample(tr, t) else ZERO
	end
	if arms then
		solveArms(S, clip, out)
	end
	if not lower then
		return
	end
	local tr = tracks[1]
	local r = if tr then sample(tr, t) else ZERO
	if wrapRoot then
		r = Vector3.new(wrap(r.X), wrap(r.Y + yawAdd), wrap(r.Z))
	end
	out[1] = r
	for c = 10, C_LYAW do
		local track = tracks[c]
		out[c] = if track then sample(track, t) else ZERO
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
			acc[c] = acc[c]:Lerp(out[c], k)
		end
		covU = nc
	end
	if wL > 0 then
		local nc = 1 - (1 - covL) * (1 - wL)
		local k = wL / nc
		acc[1] = acc[1]:Lerp(out[1], k)
		for c = 10, C_ROOTP do
			acc[c] = acc[c]:Lerp(out[c], k)
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
	sampleInto(S, clip, slot.t, scratchA, wL > 0, true, yawAdd, true)
	local pitch = S.aimPitch
	if clip.aimPitch and pitch ~= 0 then
		-- aim up / down: the torso leans (the arms follow, their targets are torso-relative)
		scratchA[2] += Vector3.new(pitch * 0.75, 0, 0)
		scratchA[3] += Vector3.new(pitch * 0.25, 0, 0)
	end
	layer(scratchA, w, wL)
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
	local standing = GROUNDED[state] == true and humanoid.FloorMaterial ~= Enum.Material.Air and not moving
	S.standF = approach(S.standF, if standing then 1 else 0, dt / STAND_FADE)
	S.runF = approach(S.runF, if moving then 1 else 0, dt / RUN_FADE)
	S.stanceW = approach(S.stanceW, if S.stanceOn and allowed and not S.dead then 1 else 0, dt / STANCE_FADE)
	-- clocks (hit-stop slows every clip of this character)
	local sdt = if now < S.hitStopUntil then dt * HIT_STOP_SPEED else dt
	advance(S.act, dt, sdt)
	advance(S.prev, dt, sdt)
	advance(S.add, dt, sdt)
	if S.act.clip and S.act.w >= 1 then
		S.prev.clip = nil
	end
	local idle, run = S.idle, S.run
	if idle then
		S.idleT = (S.idleT + sdt) % idle.length
	end
	if run then
		S.runT = (S.runT + sdt) % run.length
	end
	if (root.Position - camPos).Magnitude > RANGE then
		return
	end
	-- layers
	covU, covL = 0, 0
	local stanceW = S.stanceW
	if stanceW > 0 and idle then
		local wL = stanceW * S.standF
		local runF = S.runF
		if runF > 0 and run then
			-- idle -> run: blend the IK targets (hands, blade) when both clips use them, then solve once
			local targets = idle.rArm == run.rArm and idle.lArm == run.lArm
			sampleInto(S, idle, S.idleT, scratchA, wL > 0, false, 0, not targets)
			sampleInto(S, run, S.runT, scratchB, false, false, 0, not targets)
			for c = 2, 9 do
				scratchA[c] = scratchA[c]:Lerp(scratchB[c], runF)
			end
			if targets then
				for c = C_RHAND, C_LGRIP do
					scratchA[c] = scratchA[c]:Lerp(scratchB[c], runF)
				end
				solveArms(S, idle, scratchA)
			end
		else
			sampleInto(S, idle, S.idleT, scratchA, wL > 0, false, 0, true)
		end
		layer(scratchA, stanceW, wL)
	end
	actionLayer(S, S.prev)
	actionLayer(S, S.act)
	-- write (blend with the Animator's pose of this frame), additive on top
	local addClip = S.add.clip
	local addT, addW = S.add.t, S.add.w
	local joints = S.joints
	local scale = S.scale
	for c = 1, NJ do
		local cov = if c >= 2 and c <= 9 then covU else covL
		local addTrack = addClip and (addClip.tracks[c] or (c == 1 and addClip.tracks[C_ROOTP]))
		if cov > 0.001 or addTrack then
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
			joint.Transform = cf
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
-- The default Animate tool animation, for a category without clips yet.
local function fallback(character: Model, category: string)
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		local shape = Combat.Shapes[category] or Combat.Shapes.Sword
		local value = Instance.new("StringValue")
		value.Name = "toolanim"
		value.Value = shape.Anim or "Slash"
		value.Parent = tool
		Debris:AddItem(value, 0.5)
	end
end

function Animations.attack(character: Model, category: string, step: number, speed: number, aim: Vector3?): number
	local S = states[character]
	local style = if S and S.category == category then S.style else nil
	local clip = (if style then clips[`{style}_Attack{step}`] else nil) or clips[`{category}_Attack{step}`]
	if not clip then
		fallback(character, category)
		return 0
	end
	local sp = if typeof(speed) == "number" and speed > 0 then speed else 1
	local combo = Combat.Combos[category]
	local def = combo and combo[step]
	local hit = clip.hit
	local impact = (if def and typeof(def.Impact) == "number" then def.Impact else hit or 0) / sp
	local rate1 = if hit and impact > 0 then hit / impact else sp
	local length = if hit then impact + (clip.length - hit) / sp else clip.length / sp
	if S and S.ready and not S.dead then
		local unit = if typeof(aim) == "Vector3" and aim.Magnitude > 1e-3 then aim.Unit else nil
		S.aimPitch = if unit then clamp(asin(clamp(unit.Y, -1, 1)), -AIM_PITCH_MAX, AIM_PITCH_MAX) else 0
		play(S, clip, rate1, sp, "attack")
	end
	return length
end

function Animations.cancel(character: Model)
	local S = states[character]
	if S then
		stopKind(S.act, "attack", "equip", CANCEL_FADE)
		stopKind(S.prev, "attack", "equip", CANCEL_FADE)
	end
end

function Animations.hitStop(character: Model, seconds: number)
	local S = states[character]
	if S and typeof(seconds) == "number" then
		S.hitStopUntil = math.max(S.hitStopUntil, os.clock() + seconds)
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
	local clip = clips.Shared_Hit
	if S and clip and S.ready and not S.dead then
		playAdditive(S, clip)
	end
end

-- Dev hooks (Play, Client command bar; local attributes on a character, never replicated):
--   character:SetAttribute("AnimDebug", "Sword_Attack1@0.16")  holds that clip at that time ("" or nil releases);
--                                                   "Ranged_Attack1@0.3@20" also pitches AimPitch clips by 20 deg
--   character:SetAttribute("AnimProfile", os.clock())  -> attributes AnimCostMs (average update of ALL characters,
--                                                        ms per frame since the previous request) and AnimChars
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

return Animations
