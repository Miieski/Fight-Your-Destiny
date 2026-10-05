--!strict
-- Animation clips per rig family (Blender/README.txt): the Luau twin of tools/blender/fyd_creature_clips.py, which
-- bakes the same clips into every .blend. Change both together; RigClips.checksum(family) must equal the value printed
-- by `python tools/blender/check_rig_clips.py` (admin command checkRigClips compares them).
-- Roblox joint space: r = radians for CFrame.Angles(x, y, z), p = studs at RigClips.RefSize[family]
-- (the player scales p by the model size / RefSize). clip = { Length, Loop, Impact?, Tracks = { [joint] = { r?, p? } } },
-- key = { time, { x, y, z } }.
local RigClips = {}

type Keys = { { any } }
type Tracks = { [string]: { r: Keys?, p: Keys? } }
export type Clip = { Length: number, Loop: boolean, Impact: number?, Tracks: Tracks }

local TAU = math.pi * 2
local sin, cos, abs, max = math.sin, math.cos, math.abs, math.max

RigClips.RefSize = {
	Quadruped = 3, Biped = 5.5, BossBiped = 17, Bird = 3, Serpent = 6, Arachnid = 4.5, Crustacean = 4,
	Insect = 4, Fish = 2.5, Amphibian = 3.5, Golem = 8, Snowman = 5, Floater = 4, Gorilla = 18,
}

-- offset + amp * kind(2 pi cycles t / length + phase) on one axis (0 = x, 1 = y, 2 = z), steps samples per cycle
local function wave(length: number, amp: number, axis: number, o: { [string]: any }?): Keys
	local opts = o or {}
	local phase, cycles, steps = opts.phase or 0, opts.cycles or 1, opts.steps or 8
	local offset = opts.offset or { 0, 0, 0 }
	local kind = opts.kind or sin
	local out = {}
	local n = steps * cycles
	for i = 0, n do
		local t = length * i / n
		local v = { offset[1], offset[2], offset[3] }
		v[axis + 1] += amp * kind(TAU * cycles * t / length + phase)
		table.insert(out, { t, v })
	end
	return out
end

local function K(...: { number }): Keys
	local out = {}
	for _, k in ipairs({ ... }) do
		table.insert(out, { k[1], { k[2], k[3], k[4] } })
	end
	return out
end

local function merge(...: Tracks): Tracks
	local out = {}
	for _, tracks in ipairs({ ... }) do
		for joint, channels in pairs(tracks) do
			out[joint] = out[joint] or {}
			for kind, keys in pairs(channels) do
				(out[joint] :: any)[kind] = keys
			end
		end
	end
	return out
end

local function clip(length: number, loop: boolean, tracks: Tracks, impact: number?): Clip
	return { Length = length, Loop = loop, Tracks = tracks, Impact = impact }
end

local function legs4(length: number, amp: number): Tracks
	return {
		LegFL = { r = wave(length, amp, 0) }, LegBR = { r = wave(length, amp, 0) },
		LegFR = { r = wave(length, -amp, 0) }, LegBL = { r = wave(length, -amp, 0) },
	}
end

local function manyLegs(length: number, pairs: number, amp: number, lift: number): Tracks
	local out = {}
	local steps = 8
	for i = 1, pairs do
		for _, side in ipairs({ "L", "R" }) do
			local sign = if side == "L" then 1 else -1
			local phase = if (i % 2 == 1) == (side == "L") then 0 else math.pi
			local ks = {}
			for k = 0, steps do
				local t = length * k / steps
				local a = TAU * t / length + phase
				local up = max(0, cos(a)) * lift
				table.insert(ks, { t, { 0, amp * sign * sin(a), if side == "L" then -up else up } })
			end
			out[`Leg{side}{i}`] = { r = ks }
		end
	end
	return out
end

local function curlLegs(pairs: number, amount: number?): Tracks
	local a = amount or 0.9
	local out = {}
	for i = 1, pairs do
		out[`LegL{i}`] = { r = K({ 0, 0, 0, 0 }, { 0.5, 0, 0, -a }, { 1.0, 0, 0, -a }) }
		out[`LegR{i}`] = { r = K({ 0, 0, 0, 0 }, { 0.5, 0, 0, a }, { 1.0, 0, 0, a }) }
	end
	return out
end

local function hit(joint: string, pitch: number?, push: number?, extra: Tracks?): Tracks
	local t = { [joint] = {
		r = K({ 0, 0, 0, 0 }, { 0.08, pitch or 0.2, 0, 0 }, { 0.3, 0, 0, 0 }),
		p = K({ 0, 0, 0, 0 }, { 0.08, 0, 0, push or 0.25 }, { 0.3, 0, 0, 0 }),
	} }
	return merge(t, extra or {})
end

local function spawn(joint: string, depth: number): Tracks
	return { [joint] = { p = K({ 0, 0, -depth, 0 }, { 0.35, 0, depth * 0.12, 0 }, { 0.5, 0, 0, 0 }) } }
end

-- ------------------------------------------------------------------------------------------------
local function quadruped(): { [string]: Clip }
	return {
		Idle = clip(2.0, true, merge(
			{ Body = { p = wave(2.0, 0.04, 1, { phase = -math.pi / 2, offset = { 0, 0.02, 0 }, steps = 6 }) } },
			{ Head = { r = K({ 0, 0, 0, 0 }, { 0.7, 0.08, 0.16, 0 }, { 1.4, 0.03, -0.12, 0 }, { 2.0, 0, 0, 0 }) } },
			{ Tail = { r = wave(2.0, 0.35, 1, { cycles = 2, steps = 6 }) } }
		)),
		Walk = clip(0.8, true, merge(
			legs4(0.8, 0.45),
			{ Body = { p = wave(0.8, 0.07, 1, { cycles = 2, offset = { 0, 0.04, 0 }, steps = 4 }), r = wave(0.8, 0.03, 2) } },
			{ Head = { r = wave(0.8, 0.05, 0, { cycles = 2, steps = 4 }) } },
			{ Tail = { r = wave(0.8, 0.3, 1) } }
		)),
		Run = clip(0.5, true, merge(
			legs4(0.5, 0.75),
			{ Body = { p = wave(0.5, 0.12, 1, { cycles = 2, offset = { 0, 0.08, 0 }, steps = 4 }), r = wave(0.5, 0.08, 0) } },
			{ Head = { r = wave(0.5, 0.08, 0, { phase = math.pi }) } },
			{ Tail = { r = K({ 0, 0.5, 0, 0 }, { 0.5, 0.5, 0, 0 }) } }
		)),
		Attack1 = clip(0.8, false, {
			Body = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.22, 0, 0 }, { 0.5, -0.18, 0, 0 }, { 0.8, 0, 0, 0 }),
				p = K({ 0, 0, 0, 0 }, { 0.4, 0, 0.1, 0.35 }, { 0.5, 0, 0, -0.9 }, { 0.8, 0, 0, 0 }) },
			Head = { r = K({ 0, 0, 0, 0 }, { 0.4, -0.35, 0, 0 }, { 0.55, 0.45, 0, 0 }, { 0.8, 0, 0, 0 }) },
			LegFL = { r = K({ 0, 0, 0, 0 }, { 0.4, -0.4, 0, 0 }, { 0.5, 0.45, 0, 0 }, { 0.8, 0, 0, 0 }) },
			LegFR = { r = K({ 0, 0, 0, 0 }, { 0.4, -0.4, 0, 0 }, { 0.5, 0.45, 0, 0 }, { 0.8, 0, 0, 0 }) },
			LegBL = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.3, 0, 0 }, { 0.5, -0.4, 0, 0 }, { 0.8, 0, 0, 0 }) },
			LegBR = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.3, 0, 0 }, { 0.5, -0.4, 0, 0 }, { 0.8, 0, 0, 0 }) },
		}, 0.5),
		Hit = clip(0.3, false, hit("Body", nil, nil, { Head = { r = K({ 0, 0, 0, 0 }, { 0.08, 0.25, 0, 0 }, { 0.3, 0, 0, 0 }) } })),
		Death = clip(1.0, false, {
			Body = { r = K({ 0, 0, 0, 0 }, { 0.6, 0, 0, 1.45 }, { 1.0, 0, 0, 1.5 }),
				p = K({ 0, 0, 0, 0 }, { 0.6, 0, -0.7, 0 }, { 1.0, 0, -0.8, 0 }) },
			Head = { r = K({ 0, 0, 0, 0 }, { 0.7, 0.35, 0, 0 }, { 1.0, 0.35, 0, 0 }) },
			LegFL = { r = K({ 0, 0, 0, 0 }, { 0.6, -0.35, 0, 0 }) }, LegFR = { r = K({ 0, 0, 0, 0 }, { 0.6, -0.3, 0, 0 }) },
			LegBL = { r = K({ 0, 0, 0, 0 }, { 0.6, 0.35, 0, 0 }) }, LegBR = { r = K({ 0, 0, 0, 0 }, { 0.6, 0.3, 0, 0 }) },
		}),
		Spawn = clip(0.5, false, spawn("Body", 1.2)),
		Attack2 = clip(1.2, false, {
			Body = { r = K({ 0, 0, 0, 0 }, { 0.7, 0.35, 0, 0 }, { 0.9, -0.25, 0, 0 }, { 1.2, 0, 0, 0 }),
				p = K({ 0, 0, 0, 0 }, { 0.7, 0, -0.3, 0.6 }, { 0.85, 0, 1.2, -1.5 }, { 0.95, 0, 0, -2.0 }, { 1.2, 0, 0, 0 }) },
			LegFL = { r = K({ 0, 0, 0, 0 }, { 0.7, -0.5, 0, 0 }, { 0.85, 1.0, 0, 0 }, { 1.2, 0, 0, 0 }) },
			LegFR = { r = K({ 0, 0, 0, 0 }, { 0.7, -0.5, 0, 0 }, { 0.85, 1.0, 0, 0 }, { 1.2, 0, 0, 0 }) },
			Head = { r = K({ 0, 0, 0, 0 }, { 0.7, -0.3, 0, 0 }, { 0.9, 0.3, 0, 0 }, { 1.2, 0, 0, 0 }) },
		}, 0.9),
		Roar = clip(1.4, false, {
			Body = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.35, 0, 0 }, { 1.1, 0.35, 0, 0 }, { 1.4, 0, 0, 0 }),
				p = K({ 0, 0, 0, 0 }, { 0.4, 0, 0.3, 0.2 }, { 1.1, 0, 0.3, 0.2 }, { 1.4, 0, 0, 0 }) },
			Head = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.5, 0, 0 }, { 0.6, 0.45, 0.1, 0 }, { 0.8, 0.5, -0.1, 0 }, { 1.1, 0.5, 0, 0 }, { 1.4, 0, 0, 0 }) },
			LegFL = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.5, 0, 0 }, { 1.1, 0.5, 0, 0 }, { 1.4, 0, 0, 0 }) },
			LegFR = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.4, 0, 0 }, { 1.1, 0.4, 0, 0 }, { 1.4, 0, 0, 0 }) },
		}),
	}
end

local function biped(): { [string]: Clip }
	return {
		Idle = clip(2.4, true, merge(
			{ Torso = { p = wave(2.4, 0.05, 1, { phase = -math.pi / 2, offset = { 0, 0.03, 0 }, steps = 6 }) } },
			{ Head = { r = K({ 0, 0, 0, 0 }, { 0.8, 0.04, 0.2, 0 }, { 1.6, 0.0, -0.15, 0 }, { 2.4, 0, 0, 0 }) } },
			{ ArmL = { r = wave(2.4, 0.05, 2, { offset = { 0, 0, -0.06 }, steps = 6 }) } },
			{ ArmR = { r = wave(2.4, -0.05, 2, { offset = { 0, 0, 0.06 }, steps = 6 }) } }
		)),
		Walk = clip(0.9, true, merge(
			{ LegL = { r = wave(0.9, 0.6, 0) }, LegR = { r = wave(0.9, -0.6, 0) } },
			{ ArmL = { r = wave(0.9, -0.45, 0) }, ArmR = { r = wave(0.9, 0.45, 0) } },
			{ Torso = { p = wave(0.9, 0.08, 1, { cycles = 2, offset = { 0, 0.04, 0 }, steps = 4 }), r = wave(0.9, 0.06, 1) } }
		)),
		Run = clip(0.6, true, merge(
			{ LegL = { r = wave(0.6, 0.9, 0) }, LegR = { r = wave(0.6, -0.9, 0) } },
			{ ArmL = { r = wave(0.6, -0.7, 0, { offset = { 0.2, 0, 0 } }) }, ArmR = { r = wave(0.6, 0.7, 0, { offset = { 0.2, 0, 0 } }) } },
			{ Torso = { p = wave(0.6, 0.12, 1, { cycles = 2, offset = { 0, 0.06, 0 }, steps = 4 }), r = K({ 0, -0.15, 0, 0 }, { 0.6, -0.15, 0, 0 }) } }
		)),
		Attack1 = clip(0.8, false, {
			ArmR = { r = K({ 0, 0, 0, 0 }, { 0.4, 2.5, 0, 0.2 }, { 0.55, -0.4, 0, 0.1 }, { 0.8, 0, 0, 0 }) },
			ArmL = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.4, 0, -0.3 }, { 0.55, -0.2, 0, -0.1 }, { 0.8, 0, 0, 0 }) },
			Torso = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.15, -0.3, 0 }, { 0.55, -0.2, 0.25, 0 }, { 0.8, 0, 0, 0 }),
				p = K({ 0, 0, 0, 0 }, { 0.55, 0, -0.15, -0.3 }, { 0.8, 0, 0, 0 }) },
			LegL = { r = K({ 0, 0, 0, 0 }, { 0.45, 0.35, 0, 0 }, { 0.8, 0, 0, 0 }) },
			LegR = { r = K({ 0, 0, 0, 0 }, { 0.45, -0.25, 0, 0 }, { 0.8, 0, 0, 0 }) },
		}, 0.5),
		Shoot = clip(0.8, false, {
			ArmL = { r = K({ 0, 0, 0, 0 }, { 0.3, 1.5, 0, 0 }, { 0.6, 1.5, 0, 0 }, { 0.8, 0, 0, 0 }) },
			ArmR = { r = K({ 0, 0, 0, 0 }, { 0.3, 1.4, 0.0, -0.3 }, { 0.45, 1.3, 0.5, -0.2 }, { 0.5, 1.5, 0, 0 }, { 0.8, 0, 0, 0 }) },
			Torso = { r = K({ 0, 0, 0, 0 }, { 0.3, 0, 0.35, 0 }, { 0.5, 0.05, 0.35, 0 }, { 0.8, 0, 0, 0 }) },
			Head = { r = K({ 0, 0, 0, 0 }, { 0.3, 0, -0.3, 0 }, { 0.6, 0, -0.3, 0 }, { 0.8, 0, 0, 0 }) },
		}, 0.5),
		Hit = clip(0.3, false, hit("Torso", nil, nil, { Head = { r = K({ 0, 0, 0, 0 }, { 0.08, 0.25, 0, 0 }, { 0.3, 0, 0, 0 }) } })),
		Death = clip(1.2, false, {
			Torso = { r = K({ 0, 0, 0, 0 }, { 0.8, 1.45, 0, 0 }, { 1.2, 1.5, 0, 0 }),
				p = K({ 0, 0, 0, 0 }, { 0.8, 0, -1.7, 0.9 }, { 1.2, 0, -1.8, 1.0 }) },
			LegL = { r = K({ 0, 0, 0, 0 }, { 0.8, -1.2, 0, 0 }) }, LegR = { r = K({ 0, 0, 0, 0 }, { 0.8, -1.0, 0, 0 }) },
			ArmL = { r = K({ 0, 0, 0, 0 }, { 0.6, 0.6, 0, -0.9 }) }, ArmR = { r = K({ 0, 0, 0, 0 }, { 0.6, 0.5, 0, 0.9 }) },
			Head = { r = K({ 0, 0, 0, 0 }, { 0.8, 0.3, 0.2, 0 }) },
		}),
		Spawn = clip(0.5, false, spawn("Torso", 2.0)),
		Attack2 = clip(1.2, false, {
			ArmL = { r = K({ 0, 0, 0, 0 }, { 0.7, 2.8, 0, 0.2 }, { 0.85, -0.3, 0, 0.1 }, { 1.2, 0, 0, 0 }) },
			ArmR = { r = K({ 0, 0, 0, 0 }, { 0.7, 2.8, 0, -0.2 }, { 0.85, -0.3, 0, -0.1 }, { 1.2, 0, 0, 0 }) },
			Torso = { r = K({ 0, 0, 0, 0 }, { 0.7, 0.25, 0, 0 }, { 0.85, -0.45, 0, 0 }, { 1.2, 0, 0, 0 }),
				p = K({ 0, 0, 0, 0 }, { 0.85, 0, -0.45, -0.4 }, { 1.2, 0, 0, 0 }) },
			LegL = { r = K({ 0, 0, 0, 0 }, { 0.85, 0.5, 0, 0 }, { 1.2, 0, 0, 0 }) },
			LegR = { r = K({ 0, 0, 0, 0 }, { 0.85, -0.4, 0, 0 }, { 1.2, 0, 0, 0 }) },
		}, 0.85),
		Roar = clip(1.6, false, {
			Torso = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.28, 0, 0 }, { 1.3, 0.28, 0, 0 }, { 1.6, 0, 0, 0 }),
				p = K({ 0, 0, 0, 0 }, { 0.5, 0.05, 0, 0 }, { 0.6, -0.05, 0, 0 }, { 0.7, 0.05, 0, 0 }, { 0.8, -0.05, 0, 0 }, { 1.6, 0, 0, 0 }) },
			ArmL = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.5, 0, -1.1 }, { 1.3, 0.5, 0, -1.1 }, { 1.6, 0, 0, 0 }) },
			ArmR = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.5, 0, 1.1 }, { 1.3, 0.5, 0, 1.1 }, { 1.6, 0, 0, 0 }) },
			Head = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.45, 0, 0 }, { 1.3, 0.45, 0, 0 }, { 1.6, 0, 0, 0 }) },
		}),
		Wave = clip(1.6, true, {
			ArmR = { r = K({ 0, 0, 0, 0 }, { 0.3, 0.2, 0, 2.5 }, { 0.55, 0.2, 0.3, 2.8 }, { 0.8, 0.2, -0.2, 2.4 },
				{ 1.05, 0.2, 0.3, 2.8 }, { 1.3, 0.2, 0, 2.5 }, { 1.6, 0, 0, 0 }) },
			Head = { r = K({ 0, 0, 0, 0 }, { 0.3, 0.05, 0, 0.12 }, { 1.3, 0.05, 0, 0.12 }, { 1.6, 0, 0, 0 }) },
			Torso = { r = K({ 0, 0, 0, 0 }, { 0.3, 0, 0, -0.05 }, { 1.3, 0, 0, -0.05 }, { 1.6, 0, 0, 0 }) },
		}),
		Talk = clip(2.0, true, {
			ArmR = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.7, 0, 0.15 }, { 0.8, 0.95, -0.2, 0.2 }, { 1.2, 0.6, 0, 0.1 }, { 1.6, 0.85, 0.1, 0.2 }, { 2.0, 0, 0, 0 }) },
			ArmL = { r = K({ 0, 0, 0, 0 }, { 0.6, 0.3, 0, -0.1 }, { 1.4, 0.45, 0, -0.15 }, { 2.0, 0, 0, 0 }) },
			Head = { r = wave(2.0, 0.07, 0, { cycles = 3, steps = 4 }) },
			Torso = { r = wave(2.0, 0.05, 1, { steps = 6 }) },
		}),
	}
end

local function bossBiped(): { [string]: Clip }
	local clips = biped()
	local roar = clips.Roar
	clips.Intro = { Length = 2.0, Loop = roar.Loop, Tracks = roar.Tracks, Impact = roar.Impact }
	clips.Enrage = roar
	local heavy = clips.Attack2
	clips.Attack1 = { Length = heavy.Length, Loop = heavy.Loop, Tracks = heavy.Tracks, Impact = 0.85 }
	return clips
end

local function bird(): { [string]: Clip }
	local function flapL(length: number, amp: number): Keys
		return wave(length, amp, 2, { offset = { 0, 0, -0.1 } })
	end
	local function flapR(length: number, amp: number): Keys
		return wave(length, -amp, 2, { offset = { 0, 0, 0.1 } })
	end
	return {
		Idle = clip(0.6, true, merge(
			{ WingL = { r = flapL(0.6, 0.6) }, WingR = { r = flapR(0.6, 0.6) } },
			{ Body = { p = wave(0.6, 0.15, 1, { phase = math.pi }) } },
			{ Tail = { r = wave(0.6, 0.08, 0) } },
			{ Head = { r = K({ 0, 0, 0, 0 }, { 0.3, 0.05, 0.1, 0 }, { 0.6, 0, 0, 0 }) } }
		)),
		Walk = clip(0.45, true, merge(
			{ WingL = { r = flapL(0.45, 0.8) }, WingR = { r = flapR(0.45, 0.8) } },
			{ Body = { p = wave(0.45, 0.2, 1, { phase = math.pi }), r = K({ 0, -0.15, 0, 0 }, { 0.45, -0.15, 0, 0 }) } }
		)),
		Attack1 = clip(0.7, false, {
			Body = { r = K({ 0, 0, 0, 0 }, { 0.3, 0.3, 0, 0 }, { 0.45, -0.5, 0, 0 }, { 0.7, 0, 0, 0 }),
				p = K({ 0, 0, 0, 0 }, { 0.3, 0, 0.4, 0.4 }, { 0.45, 0, -0.6, -1.0 }, { 0.7, 0, 0, 0 }) },
			WingL = { r = K({ 0, 0, 0, -0.1 }, { 0.3, 0, 0, 0.7 }, { 0.45, 0, 0.4, -0.3 }, { 0.7, 0, 0, -0.1 }) },
			WingR = { r = K({ 0, 0, 0, 0.1 }, { 0.3, 0, 0, -0.7 }, { 0.45, 0, -0.4, 0.3 }, { 0.7, 0, 0, 0.1 }) },
			Head = { r = K({ 0, 0, 0, 0 }, { 0.3, 0.3, 0, 0 }, { 0.45, -0.4, 0, 0 }, { 0.7, 0, 0, 0 }) },
		}, 0.45),
		Shoot = clip(0.7, false, {
			Head = { r = K({ 0, 0, 0, 0 }, { 0.3, 0.35, 0, 0 }, { 0.45, -0.3, 0, 0 }, { 0.7, 0, 0, 0 }) },
			Body = { p = K({ 0, 0, 0, 0 }, { 0.3, 0, 0, 0.3 }, { 0.45, 0, 0, -0.2 }, { 0.7, 0, 0, 0 }) },
			WingL = { r = flapL(0.7, 0.7) }, WingR = { r = flapR(0.7, 0.7) },
		}, 0.45),
		Hit = clip(0.3, false, hit("Body", 0.3, 0.3)),
		Death = clip(1.0, false, {
			Body = { r = K({ 0, 0, 0, 0 }, { 0.6, 0.4, 0, 1.2 }, { 1.0, 0.4, 0, 1.4 }),
				p = K({ 0, 0, 0, 0 }, { 0.8, 0, -3.5, 0 }, { 1.0, 0, -3.6, 0 }) },
			WingL = { r = K({ 0, 0, 0, 0 }, { 0.5, 0, 0, 0.8 }) }, WingR = { r = K({ 0, 0, 0, 0 }, { 0.5, 0, 0, -0.3 }) },
		}),
		Spawn = clip(0.5, false, merge(spawn("Body", 1.5), { WingL = { r = flapL(0.5, 0.7) }, WingR = { r = flapR(0.5, 0.7) } })),
	}
end

local function serpent(): { [string]: Clip }
	local function slither(length: number, amp: number, steps: number?): Tracks
		local out: Tracks = {}
		for i = 2, 6 do
			out[`Seg{i}`] = { r = wave(length, amp, 1, { phase = -i * 0.9, steps = steps or 8 }) }
		end
		out.Seg1 = { r = wave(length, amp * 0.5, 1, { phase = -0.9, steps = steps or 8 }) }
		out.Head = { r = wave(length, -amp * 0.4, 1, { steps = steps or 8 }) }
		return out
	end
	local deathTracks: Tracks = {}
	for i = 2, 6 do
		deathTracks[`Seg{i}`] = { r = K({ 0, 0, 0, 0 }, { 0.7, 0, 0.3 * (-1) ^ i, 0 }) }
	end
	return {
		Idle = clip(2.0, true, merge(slither(2.0, 0.12, 6),
			{ Head = { r = K({ 0, 0, 0, 0 }, { 0.6, 0.12, 0.1, 0 }, { 1.3, 0.05, -0.1, 0 }, { 2.0, 0, 0, 0 }) } })),
		Walk = clip(0.8, true, slither(0.8, 0.4)),
		Attack1 = clip(0.6, false, {
			Seg1 = { r = K({ 0, 0, 0, 0 }, { 0.3, 0.55, 0, 0 }, { 0.4, -0.25, 0, 0 }, { 0.6, 0, 0, 0 }),
				p = K({ 0, 0, 0, 0 }, { 0.3, 0, 0.6, 0.3 }, { 0.4, 0, 0.1, -1.3 }, { 0.6, 0, 0, 0 }) },
			Head = { r = K({ 0, 0, 0, 0 }, { 0.3, -0.45, 0, 0 }, { 0.4, 0.2, 0, 0 }, { 0.6, 0, 0, 0 }) },
			Seg2 = { r = K({ 0, 0, 0, 0 }, { 0.3, -0.3, 0, 0 }, { 0.4, 0.1, 0, 0 }, { 0.6, 0, 0, 0 }) },
		}, 0.4),
		Hit = clip(0.3, false, hit("Seg1", 0.3, 0.3)),
		Death = clip(1.0, false, merge(
			{ Seg1 = { r = K({ 0, 0, 0, 0 }, { 0.6, 0, 0, 1.4 }, { 1.0, 0, 0, 1.5 }) } },
			deathTracks,
			{ Head = { r = K({ 0, 0, 0, 0 }, { 0.7, 0.3, 0, 0 }) } }
		)),
		Spawn = clip(0.5, false, spawn("Seg1", 1.0)),
	}
end

local function arachnid(): { [string]: Clip }
	return {
		Idle = clip(1.6, true, merge(
			{ Abdomen = { r = wave(1.6, 0.05, 0, { steps = 6 }) } },
			{ Body = { p = wave(1.6, 0.03, 1, { steps = 6 }) } },
			{ Tail = { r = wave(1.6, 0.1, 0, { steps = 6 }) } }
		)),
		Walk = clip(0.6, true, merge(manyLegs(0.6, 4, 0.35, 0.35), { Body = { p = wave(0.6, 0.05, 1, { cycles = 2, steps = 4 }) } })),
		Attack1 = clip(0.7, false, {
			Body = { r = K({ 0, 0, 0, 0 }, { 0.35, 0.4, 0, 0 }, { 0.45, -0.15, 0, 0 }, { 0.7, 0, 0, 0 }),
				p = K({ 0, 0, 0, 0 }, { 0.35, 0, 0.3, 0.2 }, { 0.45, 0, 0, -0.6 }, { 0.7, 0, 0, 0 }) },
			LegL1 = { r = K({ 0, 0, 0, 0 }, { 0.35, 0, 0.3, -0.8 }, { 0.45, 0, -0.2, 0.2 }, { 0.7, 0, 0, 0 }) },
			LegR1 = { r = K({ 0, 0, 0, 0 }, { 0.35, 0, -0.3, 0.8 }, { 0.45, 0, 0.2, -0.2 }, { 0.7, 0, 0, 0 }) },
			Tail = { r = K({ 0, 0, 0, 0 }, { 0.35, 0.35, 0, 0 }, { 0.45, -0.9, 0, 0 }, { 0.7, 0, 0, 0 }) },
			ArmL = { r = K({ 0, 0, 0, 0 }, { 0.35, 0, 0.4, 0 }, { 0.45, 0, -0.2, 0 }, { 0.7, 0, 0, 0 }) },
			ArmR = { r = K({ 0, 0, 0, 0 }, { 0.35, 0, -0.4, 0 }, { 0.45, 0, 0.2, 0 }, { 0.7, 0, 0, 0 }) },
		}, 0.45),
		Hit = clip(0.3, false, hit("Body", 0.2, 0.25)),
		Death = clip(1.0, false, merge(curlLegs(4), {
			Body = { r = K({ 0, 0, 0, 0 }, { 0.5, 0, 0, 2.8 }, { 1.0, 0, 0, 3.1 }), p = K({ 0, 0, 0, 0 }, { 0.5, 0, 0.6, 0 }, { 1.0, 0, 0.3, 0 }) } })),
		Spawn = clip(0.5, false, spawn("Body", 1.2)),
		Attack2 = clip(1.2, false, {
			Body = { r = K({ 0, 0, 0, 0 }, { 0.7, 0.7, 0, 0 }, { 0.9, -0.25, 0, 0 }, { 1.2, 0, 0, 0 }),
				p = K({ 0, 0, 0, 0 }, { 0.7, 0, 0.8, 0.3 }, { 0.9, 0, -0.2, -0.6 }, { 1.2, 0, 0, 0 }) },
			LegL1 = { r = K({ 0, 0, 0, 0 }, { 0.7, 0, 0.4, -1.0 }, { 0.9, 0, 0, 0.3 }, { 1.2, 0, 0, 0 }) },
			LegR1 = { r = K({ 0, 0, 0, 0 }, { 0.7, 0, -0.4, 1.0 }, { 0.9, 0, 0, -0.3 }, { 1.2, 0, 0, 0 }) },
			LegL2 = { r = K({ 0, 0, 0, 0 }, { 0.7, 0, 0.2, -0.6 }, { 0.9, 0, 0, 0.2 }, { 1.2, 0, 0, 0 }) },
			LegR2 = { r = K({ 0, 0, 0, 0 }, { 0.7, 0, -0.2, 0.6 }, { 0.9, 0, 0, -0.2 }, { 1.2, 0, 0, 0 }) },
		}, 0.9),
		Roar = clip(1.4, false, {
			Body = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.5, 0, 0 }, { 1.1, 0.5, 0, 0 }, { 1.4, 0, 0, 0 }) },
			LegL1 = { r = K({ 0, 0, 0, 0 }, { 0.4, 0, 0.3, -0.9 }, { 0.6, 0, 0.5, -0.7 }, { 0.8, 0, 0.3, -0.9 }, { 1.4, 0, 0, 0 }) },
			LegR1 = { r = K({ 0, 0, 0, 0 }, { 0.4, 0, -0.3, 0.9 }, { 0.6, 0, -0.5, 0.7 }, { 0.8, 0, -0.3, 0.9 }, { 1.4, 0, 0, 0 }) },
		}),
	}
end

local function crustacean(): { [string]: Clip }
	return {
		Idle = clip(1.6, true, merge(
			{ ArmL = { r = wave(1.6, 0.1, 0, { steps = 6 }) }, ArmR = { r = wave(1.6, -0.1, 0, { steps = 6 }) } },
			{ Body = { p = wave(1.6, 0.04, 1, { steps = 6 }) } }
		)),
		Walk = clip(0.5, true, merge(manyLegs(0.5, 3, 0.3, 0.35), { Body = { r = wave(0.5, 0.06, 2) } })),
		Attack1 = clip(0.6, false, {
			ArmR = { r = K({ 0, 0, 0, 0 }, { 0.3, 0.9, 0, 0 }, { 0.4, -0.4, 0, 0 }, { 0.6, 0, 0, 0 }) },
			ArmL = { r = K({ 0, 0, 0, 0 }, { 0.33, 0.7, 0, 0 }, { 0.45, -0.3, 0, 0 }, { 0.6, 0, 0, 0 }) },
			Body = { p = K({ 0, 0, 0, 0 }, { 0.3, 0, 0.1, 0.2 }, { 0.4, 0, 0, -0.5 }, { 0.6, 0, 0, 0 }) },
		}, 0.4),
		Hit = clip(0.3, false, hit("Body", 0.15, 0.25)),
		Death = clip(1.0, false, merge(curlLegs(3), {
			Body = { r = K({ 0, 0, 0, 0 }, { 0.5, 0, 0, 2.8 }, { 1.0, 0, 0, 3.1 }), p = K({ 0, 0, 0, 0 }, { 0.5, 0, 0.5, 0 }, { 1.0, 0, 0.2, 0 }) },
			ArmL = { r = K({ 0, 0, 0, 0 }, { 0.5, 0.6, 0, 0 }) }, ArmR = { r = K({ 0, 0, 0, 0 }, { 0.5, 0.6, 0, 0 }) } })),
		Spawn = clip(0.5, false, spawn("Body", 1.0)),
	}
end

local function insect(): { [string]: Clip }
	return {
		Idle = clip(1.6, true, { Head = { r = wave(1.6, 0.08, 1, { steps = 6 }) }, Body = { p = wave(1.6, 0.03, 1, { steps = 6 }) } }),
		Walk = clip(0.5, true, merge(manyLegs(0.5, 3, 0.3, 0.3), { Body = { p = wave(0.5, 0.04, 1, { cycles = 2, steps = 4 }) } })),
		Attack1 = clip(0.7, false, {
			Body = { r = K({ 0, 0, 0, 0 }, { 0.35, 0.2, 0, 0 }, { 0.45, -0.2, 0, 0 }, { 0.7, 0, 0, 0 }),
				p = K({ 0, 0, 0, 0 }, { 0.35, 0, 0, 0.4 }, { 0.45, 0, 0, -0.9 }, { 0.7, 0, 0, 0 }) },
			Head = { r = K({ 0, 0, 0, 0 }, { 0.35, 0.4, 0, 0 }, { 0.45, -0.3, 0, 0 }, { 0.7, 0, 0, 0 }) },
		}, 0.45),
		Hit = clip(0.3, false, hit("Body", 0.15, 0.25)),
		Death = clip(1.0, false, merge(curlLegs(3), {
			Body = { r = K({ 0, 0, 0, 0 }, { 0.5, 0, 0, 2.8 }, { 1.0, 0, 0, 3.1 }), p = K({ 0, 0, 0, 0 }, { 0.5, 0, 0.6, 0 }, { 1.0, 0, 0.3, 0 }) } })),
		Spawn = clip(0.5, false, spawn("Body", 1.0)),
	}
end

local function fish(): { [string]: Clip }
	return {
		Idle = clip(1.2, true, {
			Tail = { r = wave(1.2, 0.35, 1) }, FinL = { r = wave(1.2, 0.3, 2, { steps = 6 }) }, FinR = { r = wave(1.2, -0.3, 2, { steps = 6 }) },
			Body = { p = wave(1.2, 0.1, 1, { phase = math.pi / 2 }), r = wave(1.2, -0.06, 1) },
		}),
		Walk = clip(0.6, true, { Tail = { r = wave(0.6, 0.6, 1) }, Body = { r = wave(0.6, -0.12, 1) },
			FinL = { r = wave(0.6, 0.35, 2) }, FinR = { r = wave(0.6, -0.35, 2) } }),
		Attack1 = clip(0.6, false, {
			Body = { p = K({ 0, 0, 0, 0 }, { 0.3, 0, 0, 0.5 }, { 0.4, 0, 0, -1.4 }, { 0.6, 0, 0, 0 }),
				r = K({ 0, 0, 0, 0 }, { 0.3, 0.15, 0, 0 }, { 0.4, -0.1, 0, 0 }, { 0.6, 0, 0, 0 }) },
			Jaw = { r = K({ 0, 0, 0, 0 }, { 0.3, 0.6, 0, 0 }, { 0.42, 0, 0, 0 }, { 0.6, 0, 0, 0 }) },
			Tail = { r = K({ 0, 0, 0, 0 }, { 0.3, 0, 0.6, 0 }, { 0.4, 0, -0.6, 0 }, { 0.6, 0, 0, 0 }) },
		}, 0.4),
		Hit = clip(0.3, false, hit("Body", 0.2, 0.3)),
		Death = clip(1.0, false, { Body = { r = K({ 0, 0, 0, 0 }, { 0.6, 0, 0, 3.0 }, { 1.0, 0, 0, 3.1 }),
			p = K({ 0, 0, 0, 0 }, { 1.0, 0, -1.2, 0 }) },
			Tail = { r = K({ 0, 0, 0, 0 }, { 0.3, 0, 0.5, 0 }, { 0.6, 0, -0.3, 0 }, { 1.0, 0, 0, 0 }) } }),
		Spawn = clip(0.5, false, spawn("Body", 0.8)),
	}
end

local function amphibian(): { [string]: Clip }
	return {
		Idle = clip(2.0, true, { Body = { p = wave(2.0, 0.04, 1, { cycles = 2, steps = 4 }) },
			Head = { r = K({ 0, 0, 0, 0 }, { 0.7, 0.06, 0.1, 0 }, { 1.4, 0.02, -0.1, 0 }, { 2.0, 0, 0, 0 }) } }),
		Walk = clip(0.6, true, {
			Body = { p = K({ 0, 0, 0, 0 }, { 0.15, 0, 0.5, 0 }, { 0.3, 0, 0.8, 0 }, { 0.45, 0, 0.4, 0 }, { 0.6, 0, 0, 0 }),
				r = K({ 0, 0, 0, 0 }, { 0.15, 0.15, 0, 0 }, { 0.45, -0.1, 0, 0 }, { 0.6, 0, 0, 0 }) },
			LegBL = { r = K({ 0, 0, 0, 0 }, { 0.15, -0.9, 0, 0 }, { 0.45, 0.2, 0, 0 }, { 0.6, 0, 0, 0 }) },
			LegBR = { r = K({ 0, 0, 0, 0 }, { 0.15, -0.9, 0, 0 }, { 0.45, 0.2, 0, 0 }, { 0.6, 0, 0, 0 }) },
			LegFL = { r = K({ 0, 0, 0, 0 }, { 0.3, 0.5, 0, 0 }, { 0.6, 0, 0, 0 }) },
			LegFR = { r = K({ 0, 0, 0, 0 }, { 0.3, 0.5, 0, 0 }, { 0.6, 0, 0, 0 }) },
		}),
		Shoot = clip(0.7, false, {
			Head = { r = K({ 0, 0, 0, 0 }, { 0.35, 0.35, 0, 0 }, { 0.45, -0.2, 0, 0 }, { 0.7, 0, 0, 0 }) },
			Body = { p = K({ 0, 0, 0, 0 }, { 0.35, 0, 0.2, 0.15 }, { 0.45, 0, 0, -0.2 }, { 0.7, 0, 0, 0 }) },
		}, 0.45),
		Hit = clip(0.3, false, hit("Body", 0.2, 0.25)),
		Death = clip(1.0, false, { Body = { r = K({ 0, 0, 0, 0 }, { 0.5, 0, 0, 2.9 }, { 1.0, 0, 0, 3.1 }),
			p = K({ 0, 0, 0, 0 }, { 0.4, 0, 0.6, 0 }, { 1.0, 0, 0.3, 0 }) },
			LegBL = { r = K({ 0, 0, 0, 0 }, { 0.6, -0.8, 0, 0 }) }, LegBR = { r = K({ 0, 0, 0, 0 }, { 0.6, -0.8, 0, 0 }) } }),
		Spawn = clip(0.5, false, spawn("Body", 1.0)),
	}
end

local function golem(): { [string]: Clip }
	local roar = clip(2.0, false, {
		Body = { r = K({ 0, 0, 0, 0 }, { 0.5, 0.3, 0, 0 }, { 1.6, 0.3, 0, 0 }, { 2.0, 0, 0, 0 }),
			p = K({ 0, 0, 0, 0 }, { 0.6, 0.08, 0, 0 }, { 0.7, -0.08, 0, 0 }, { 0.8, 0.08, 0, 0 }, { 0.9, -0.08, 0, 0 }, { 2.0, 0, 0, 0 }) },
		ArmL = { r = K({ 0, 0, 0, 0 }, { 0.6, 0.4, 0, -1.0 }, { 1.6, 0.4, 0, -1.0 }, { 2.0, 0, 0, 0 }) },
		ArmR = { r = K({ 0, 0, 0, 0 }, { 0.6, 0.4, 0, 1.0 }, { 1.6, 0.4, 0, 1.0 }, { 2.0, 0, 0, 0 }) },
		Head = { r = K({ 0, 0, 0, 0 }, { 0.6, 0.4, 0, 0 }, { 1.6, 0.4, 0, 0 }, { 2.0, 0, 0, 0 }) },
	})
	return {
		Idle = clip(3.0, true, {
			Body = { p = wave(3.0, 0.08, 1, { steps = 6 }) },
			ArmL = { r = wave(3.0, 0.05, 0, { steps = 6 }) }, ArmR = { r = wave(3.0, -0.05, 0, { steps = 6 }) },
			Head = { r = K({ 0, 0, 0, 0 }, { 1.0, 0.03, 0.12, 0 }, { 2.0, 0, -0.1, 0 }, { 3.0, 0, 0, 0 }) },
		}),
		Walk = clip(1.2, true, {
			LegL = { r = wave(1.2, 0.45, 0) }, LegR = { r = wave(1.2, -0.45, 0) },
			ArmL = { r = wave(1.2, -0.3, 0) }, ArmR = { r = wave(1.2, 0.3, 0) },
			Body = { r = wave(1.2, 0.06, 2), p = wave(1.2, 0.15, 1, { cycles = 2, offset = { 0, 0.08, 0 }, steps = 4 }) },
		}),
		Attack1 = clip(1.0, false, {
			ArmR = { r = K({ 0, 0, 0, 0 }, { 0.5, 2.4, 0, 0.2 }, { 0.62, -0.3, 0, 0 }, { 1.0, 0, 0, 0 }) },
			ArmL = { r = K({ 0, 0, 0, 0 }, { 0.5, -0.3, 0, 0 }, { 0.62, 0.2, 0, 0 }, { 1.0, 0, 0, 0 }) },
			Body = { r = K({ 0, 0, 0, 0 }, { 0.5, 0.15, -0.3, 0 }, { 0.62, -0.25, 0.3, 0 }, { 1.0, 0, 0, 0 }),
				p = K({ 0, 0, 0, 0 }, { 0.62, 0, -0.3, -0.3 }, { 1.0, 0, 0, 0 }) },
		}, 0.6),
		Attack2 = clip(1.4, false, {
			ArmL = { r = K({ 0, 0, 0, 0 }, { 0.75, 2.8, 0, 0.2 }, { 0.9, -0.4, 0, 0 }, { 1.4, 0, 0, 0 }) },
			ArmR = { r = K({ 0, 0, 0, 0 }, { 0.75, 2.8, 0, -0.2 }, { 0.9, -0.4, 0, 0 }, { 1.4, 0, 0, 0 }) },
			Body = { r = K({ 0, 0, 0, 0 }, { 0.75, 0.25, 0, 0 }, { 0.9, -0.35, 0, 0 }, { 1.4, 0, 0, 0 }),
				p = K({ 0, 0, 0, 0 }, { 0.9, 0, -0.5, -0.3 }, { 1.4, 0, 0, 0 }) },
		}, 0.9),
		Roar = roar,
		Hit = clip(0.3, false, hit("Body", 0.12, 0.2)),
		Death = clip(1.6, false, {
			Body = { r = K({ 0, 0, 0, 0 }, { 1.2, -1.35, 0, 0 }, { 1.6, -1.45, 0, 0 }),
				p = K({ 0, 0, 0, 0 }, { 1.2, 0, -2.4, -1.6 }, { 1.6, 0, -2.6, -1.7 }) },
			ArmL = { r = K({ 0, 0, 0, 0 }, { 1.0, 1.4, 0, 0 }) }, ArmR = { r = K({ 0, 0, 0, 0 }, { 1.0, 1.2, 0, 0 }) },
			LegL = { r = K({ 0, 0, 0, 0 }, { 1.0, 0.6, 0, 0 }) }, LegR = { r = K({ 0, 0, 0, 0 }, { 1.0, 0.4, 0, 0 }) },
		}),
		Spawn = clip(0.6, false, { Body = { p = K({ 0, 0, -3.0, 0 }, { 0.45, 0, 0.3, 0 }, { 0.6, 0, 0, 0 }) } }),
		Intro = roar,
		Enrage = roar,
	}
end

local function snowman(): { [string]: Clip }
	return {
		Idle = clip(2.0, true, { Middle = { r = wave(2.0, 0.05, 2, { steps = 6 }) }, Head = { r = wave(2.0, 0.15, 1, { steps = 6 }) },
			ArmL = { r = wave(2.0, 0.08, 1, { steps = 6 }) }, ArmR = { r = wave(2.0, -0.08, 1, { steps = 6 }) } }),
		Walk = clip(0.8, true, {
			Body = { p = wave(0.8, 0.3, 1, { cycles = 2, steps = 4, kind = function(x: number): number return abs(sin(x / 2)) end }) },
			Middle = { r = wave(0.8, 0.1, 2) }, Head = { r = wave(0.8, -0.1, 2) },
			ArmL = { r = wave(0.8, 0.3, 1) }, ArmR = { r = wave(0.8, 0.3, 1) },
		}),
		Attack1 = clip(0.8, false, {
			ArmR = { r = K({ 0, 0, 0, 0 }, { 0.4, 0, -0.9, 0.3 }, { 0.55, 0, 1.2, 0 }, { 0.8, 0, 0, 0 }) },
			Middle = { r = K({ 0, 0, 0, 0 }, { 0.4, 0, -0.35, 0 }, { 0.55, 0, 0.4, 0 }, { 0.8, 0, 0, 0 }) },
			Head = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.2, 0, 0 }, { 0.55, -0.15, 0, 0 }, { 0.8, 0, 0, 0 }) },
		}, 0.5),
		Hit = clip(0.3, false, hit("Middle", 0.2, 0.3)),
		Death = clip(1.2, false, {
			Head = { p = K({ 0, 0, 0, 0 }, { 0.3, 0, 0.6, 0 }, { 0.9, 1.6, -3.2, 0.5 }, { 1.2, 1.7, -3.3, 0.5 }),
				r = K({ 0, 0, 0, 0 }, { 0.9, 0.5, 0, 1.8 }) },
			Middle = { r = K({ 0, 0, 0, 0 }, { 0.9, 0, 0, -1.0 }), p = K({ 0, 0, 0, 0 }, { 0.9, -0.8, -1.4, 0 }) },
		}),
		Spawn = clip(0.5, false, spawn("Body", 1.5)),
	}
end

local function floater(): { [string]: Clip }
	return {
		Idle = clip(2.0, true, {
			Body = { p = wave(2.0, 0.3, 1, { steps = 6 }) },
			Tail = { r = wave(2.0, 0.2, 2, { steps = 6 }) }, Tail2 = { r = wave(2.0, 0.3, 0, { phase = 1.0, steps = 6 }) },
			ArmL = { r = wave(2.0, 0.2, 2, { offset = { 0, 0, -0.1 }, steps = 6 }) }, ArmR = { r = wave(2.0, -0.2, 2, { offset = { 0, 0, 0.1 }, steps = 6 }) },
		}),
		Walk = clip(1.2, true, {
			Body = { p = wave(1.2, 0.25, 1, { steps = 6 }), r = K({ 0, -0.2, 0, 0 }, { 1.2, -0.2, 0, 0 }) },
			Tail = { r = wave(1.2, 0.3, 2, { offset = { 0.3, 0, 0 }, steps = 6 }) }, Tail2 = { r = wave(1.2, 0.4, 0, { offset = { 0.3, 0, 0 }, steps = 6 }) },
		}),
		Shoot = clip(0.8, false, {
			ArmL = { r = K({ 0, 0, 0, 0 }, { 0.4, 1.3, 0, 0.2 }, { 0.5, 1.7, 0, 0.1 }, { 0.8, 0, 0, 0 }) },
			ArmR = { r = K({ 0, 0, 0, 0 }, { 0.4, 1.3, 0, -0.2 }, { 0.5, 1.7, 0, -0.1 }, { 0.8, 0, 0, 0 }) },
			Body = { p = K({ 0, 0, 0, 0 }, { 0.4, 0, 0.2, 0.3 }, { 0.5, 0, 0, -0.3 }, { 0.8, 0, 0, 0 }) },
		}, 0.5),
		Hit = clip(0.3, false, hit("Body", 0.2, 0.35)),
		Death = clip(1.0, false, { Body = { p = K({ 0, 0, 0, 0 }, { 1.0, 0, -1.5, 0 }), r = K({ 0, 0, 0, 0 }, { 1.0, 0.5, 0.6, 0 }) },
			Tail = { r = K({ 0, 0, 0, 0 }, { 1.0, 0.6, 0, 0 }) } }),
		Spawn = clip(0.5, false, spawn("Body", 1.5)),
	}
end

local function gorilla(): { [string]: Clip }
	local roar = clip(2.0, false, {
		Body = { r = K({ 0, 0, 0, 0 }, { 0.35, 0.35, 0, 0 }, { 1.6, 0.35, 0, 0 }, { 2.0, 0, 0, 0 }),
			p = K({ 0, 0, 0, 0 }, { 0.35, 0, 0.6, 0.2 }, { 1.6, 0, 0.6, 0.2 }, { 2.0, 0, 0, 0 }) },
		ArmL = { r = K({ 0, 0, 0, 0 }, { 0.4, 1.3, 0, 0.5 }, { 0.55, 0.9, 0, 0.3 }, { 0.7, 1.3, 0, 0.5 }, { 0.85, 0.9, 0, 0.3 },
			{ 1.0, 1.3, 0, 0.5 }, { 1.15, 0.9, 0, 0.3 }, { 1.6, 1.0, 0, 0.3 }, { 2.0, 0, 0, 0 }) },
		ArmR = { r = K({ 0, 0, 0, 0 }, { 0.4, 0.9, 0, -0.3 }, { 0.55, 1.3, 0, -0.5 }, { 0.7, 0.9, 0, -0.3 }, { 0.85, 1.3, 0, -0.5 },
			{ 1.0, 0.9, 0, -0.3 }, { 1.15, 1.3, 0, -0.5 }, { 1.6, 1.0, 0, -0.3 }, { 2.0, 0, 0, 0 }) },
		Head = { r = K({ 0, 0, 0, 0 }, { 0.35, 0.45, 0, 0 }, { 1.6, 0.45, 0, 0 }, { 2.0, 0, 0, 0 }) },
	})
	return {
		Idle = clip(2.6, true, {
			Body = { p = wave(2.6, 0.08, 1, { steps = 6 }) },
			Head = { r = K({ 0, 0, 0, 0 }, { 0.9, 0.05, 0.15, 0 }, { 1.8, 0, -0.12, 0 }, { 2.6, 0, 0, 0 }) },
			ArmL = { r = wave(2.6, 0.05, 0, { steps = 6 }) }, ArmR = { r = wave(2.6, -0.05, 0, { steps = 6 }) },
		}),
		Walk = clip(1.0, true, {
			ArmL = { r = wave(1.0, 0.45, 0) }, ArmR = { r = wave(1.0, -0.45, 0) },
			LegL = { r = wave(1.0, -0.4, 0) }, LegR = { r = wave(1.0, 0.4, 0) },
			Body = { r = wave(1.0, 0.07, 2), p = wave(1.0, 0.12, 1, { cycles = 2, offset = { 0, 0.06, 0 }, steps = 4 }) },
		}),
		Attack1 = clip(1.0, false, {
			ArmR = { r = K({ 0, 0, 0, 0 }, { 0.5, 2.2, 0, 0.1 }, { 0.62, -0.4, 0, 0 }, { 1.0, 0, 0, 0 }) },
			ArmL = { r = K({ 0, 0, 0, 0 }, { 0.5, 0.6, 0, 0 }, { 0.62, -0.2, 0, 0 }, { 1.0, 0, 0, 0 }) },
			Body = { r = K({ 0, 0, 0, 0 }, { 0.5, 0.2, -0.2, 0 }, { 0.62, -0.3, 0.2, 0 }, { 1.0, 0, 0, 0 }),
				p = K({ 0, 0, 0, 0 }, { 0.62, 0, -0.3, -0.4 }, { 1.0, 0, 0, 0 }) },
		}, 0.6),
		Roar = roar,
		Hit = clip(0.3, false, hit("Body", 0.12, 0.2)),
		Death = clip(1.6, false, {
			Body = { r = K({ 0, 0, 0, 0 }, { 1.2, 0, 0, 1.35 }, { 1.6, 0, 0, 1.45 }),
				p = K({ 0, 0, 0, 0 }, { 1.2, 0, -1.6, 0 }, { 1.6, 0, -1.7, 0 }) },
			ArmL = { r = K({ 0, 0, 0, 0 }, { 1.0, 0.8, 0, -0.8 }) }, ArmR = { r = K({ 0, 0, 0, 0 }, { 1.0, 0.6, 0, 0.6 }) },
		}),
		Spawn = clip(0.6, false, spawn("Body", 3.0)),
		Intro = roar,
		Enrage = roar,
	}
end

RigClips.Families = {
	Quadruped = quadruped(), Biped = biped(), BossBiped = bossBiped(), Bird = bird(), Serpent = serpent(),
	Arachnid = arachnid(), Crustacean = crustacean(), Insect = insect(), Fish = fish(), Amphibian = amphibian(),
	Golem = golem(), Snowman = snowman(), Floater = floater(), Gorilla = gorilla(),
} :: { [string]: { [string]: Clip } }

-- Sum of every number of a family's clips (lengths, impacts, key times and values): compare with
-- tools/blender/check_rig_clips.py (the Python side rounds keys to 4 decimals, so allow a small difference).
function RigClips.checksum(family: string): number
	local total = 0
	for _, c in pairs(RigClips.Families[family] or {}) do
		total += c.Length + (c.Impact or 0)
		for _, channels in pairs(c.Tracks) do
			for _, keys in pairs(channels :: any) do
				for _, key in ipairs(keys) do
					total += key[1] + key[2][1] + key[2][2] + key[2][3]
				end
			end
		end
	end
	return math.floor(total * 1000 + 0.5) / 1000
end

return RigClips
