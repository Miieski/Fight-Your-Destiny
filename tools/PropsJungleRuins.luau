--[[
	PropsJungleRuins (dev tool, Edit mode only) - the owner's "JUNGLE ZONE PROP IMPROVEMENT - Ruins and stonework"
	(2026-10-20, jungle PROMPT_03): the stepped ruin block, the stone stairs, the broken pillar and blocks, the mossy
	slabs and the glowing floor pad rebuilt in the jungle recipe (docs/prop_texture_guide.md sections A, B, C), keeping
	each object's colours, place, size, function and collision. Source of truth: tools/PropsJungleRuins.luau.
	Inventory: docs/prop_inventory.md "Jungle ruins".

	Collision: the visible unions never collide; invisible "Collision" parts are the kit's colliding parts (same shape,
	size and place), so no copy is more (or less) solid than today. These kits have many copies (ruin decor): the
	triangle cost per copy is kept modest (parts and low domes; Agent A's facets only where they pay).

	It uses DevTools.PropsJungleGates (and through it the jungle buildings and desert monuments helpers, finish() and
	the SHAPES table) and registers its builders into the same PropsBatch2 table:
		local R = require(game.ServerStorage.DevTools.PropsJungleRuins:Clone())
		print(R.install("jungle_ruin_block"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.run({ only = { "jungle_ruin_block" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local G = require(ServerStorage.DevTools.PropsJungleGates:Clone()) :: any
local J = G.J
local M, B2, H = J.M, J.B2, J.H
local piece, chamfered = H.piece, H.chamfered
local finish = M.finish
local P = J.PALETTE
local MOSS = P.MOSS
local RData = require(ServerStorage.DevTools.PropsJungleRuinsData:Clone()) :: any -- Agent A's ruins facet pieces

local Ruins = {}

local rgb = Color3.fromRGB
local rad = math.rad

---------------------------------------------------------------------
-- shared helpers
---------------------------------------------------------------------
-- a soft layered moss mat lying on a surface (`frame` at the surface centre, Y out of it, X along the mat), the cave
-- recipe: a broad dark base (#589642, 0.3-0.5 tall) of overlapping low 7-sided domes merged into one patch with a
-- wavy outline, a lighter second layer (#60C448) over 60-70 % of it, 1-2 small highlight bumps (#78D246)
local function mossMat(list: { BasePart }, rng: Random, frame: CFrame, len: number, depth: number, hMul: number?)
	local hm = hMul or 1
	local function run(x0: number, x1: number, r: number, h: number, lift: number, color: Color3)
		local x = x0
		repeat
			local rr = r * rng:NextNumber(0.85, 1.1)
			local cf = frame * CFrame.new(math.min(x, x1), lift, rng:NextNumber(-0.15, 0.15) * depth) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			table.insert(list, M.frustumN(7, rr, rr * 0.62, -0.15, h * rng:NextNumber(0.85, 1.1), cf, { H.scaled(color, rng:NextNumber(0.97, 1.03)), H.scaled(color, 0.93) }))
			x += r * rng:NextNumber(0.85, 1.05)
		until x > x1 + 0.01
	end
	local r0 = math.max(depth * 0.5, 0.45)
	local a, b = -len / 2 + r0 * 0.8, len / 2 - r0 * 0.8
	run(a, math.max(a, b), r0, rng:NextNumber(0.32, 0.45) * hm, 0, H.scaled(MOSS[1], rng:NextNumber(0.96, 1.04)))
	local l2 = (b - a) * rng:NextNumber(0.6, 0.7)
	local s0 = a + rng:NextNumber(0, math.max((b - a) - l2, 0))
	run(s0, s0 + l2, r0 * 0.72, rng:NextNumber(0.25, 0.32) * hm, 0.22 * hm, H.scaled(MOSS[2], rng:NextNumber(0.96, 1.04)))
	for _ = 1, (if len > 2.5 then 2 else 1) do
		local cf = frame * CFrame.new(s0 + rng:NextNumber(0, l2), 0.42 * hm, rng:NextNumber(-0.1, 0.1) * depth)
		table.insert(list, M.frustumN(6, rng:NextNumber(0.3, 0.45), 0.18, -0.1, 0.22 * hm, cf, { MOSS[3], H.scaled(MOSS[3], 0.93) }))
	end
end
Ruins.mossMat = mossMat

-- a course-built wall block (x0 .. x1, y0 .. y1, depth d centred on z = zc; in `frame`, default the model's own): cut
-- stone blocks in running bond through the full depth (chamfered, tones per block, 0.1 joints over a dark core), a few
-- chipped top corners
local function stoneCourses(list: { BasePart }, rng: Random, x0: number, x1: number, y0: number, y1: number, zc: number, d: number, ch: number, color: Color3, dark: Color3, chips: number, frame: CFrame?)
	local fr = frame or CFrame.identity
	table.insert(list, piece("Part", Vector3.new(x1 - x0 - 0.12, y1 - y0 - 0.06, d - 0.12), fr * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, zc), dark))
	local n = math.max(1, math.floor((y1 - y0) / ch + 0.5))
	local h = (y1 - y0) / n
	local chipLeft = chips
	for row = 0, n - 1 do
		local yc = y0 + (row + 0.5) * h
		local x = x0 - (if row % 2 == 0 then 0 else rng:NextNumber(0.7, 1.4))
		while x < x1 - 0.05 do
			local len = rng:NextNumber(2.2, 3.6)
			local a, b = math.max(x, x0), math.min(x + len, x1)
			if b - a > 0.4 then
				local c = H.scaled(color, H.TONES[H.toneIndex(rng, nil)] * (0.93 + 0.08 * (yc - y0) / math.max(y1 - y0, 1)))
				if rng:NextNumber() < 0.12 then
					c = c:Lerp(MOSS[1], 0.12)
				end
				local size = Vector3.new(b - a - 0.1, h - 0.1, d)
				local cf = fr * CFrame.new((a + b) / 2, yc, zc)
				local negs = {}
				if row == n - 1 and chipLeft > 0 and rng:NextNumber() < 0.5 then
					local sx = if rng:NextNumber() < 0.5 then -1 else 1
					local sz = if rng:NextNumber() < 0.5 then -1 else 1
					table.insert(negs, piece("Part", Vector3.one * rng:NextNumber(0.7, 1.0), cf * CFrame.new(sx * size.X / 2, size.Y / 2, sz * size.Z / 2) * CFrame.Angles(rad(35), rad(45), 0), dark))
					chipLeft -= 1
				end
				table.insert(list, chamfered(size, cf, c, { "vertical", "topFrontBack", "topSides" }, 0.14, negs))
			end
			x += len
		end
	end
end
Ruins.stoneCourses = stoneCourses

-- a loose cut stone (chamfered, maybe chipped) at cf
local function looseStone(list: { BasePart }, rng: Random, size: Vector3, cf: CFrame, color: Color3)
	local negs = {}
	if rng:NextNumber() < 0.6 then
		table.insert(negs, piece("Part", Vector3.one * math.min(size.X, size.Y, size.Z) * 0.45, cf * CFrame.new(size.X / 2, size.Y / 2, -size.Z / 2) * CFrame.Angles(rad(35), rad(45), 0), color))
	end
	table.insert(list, chamfered(size, cf, color, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, math.min(size.X, size.Y, size.Z) * 0.12, negs))
end
Ruins.looseStone = looseStone

-- a part-built moss drape (the jungle buildings' mossDrape: low mounds on the top, a roll over the edge, 2 thin
-- curtains down the face) on the edge point `edge` of a face looking `out`; far cheaper than a facet drape (about
-- 300 triangles against 2500-3800), so it is the one used on the many-copy ruins
local function partDrape(list: { BasePart }, rng: Random, edge: Vector3, out: Vector3, w: number, depth: number, drop: number)
	J.mossDrape(list, rng, CFrame.lookAt(edge, edge + out), w, depth, drop)
end
Ruins.partDrape = partDrape

---------------------------------------------------------------------
-- 01 STEPPED RUIN BLOCK (kit MapAssets.Jungle.Ruin_Wall_Broken, 9 parts, 20.8 x 10.4 x 8.7; Jungle_3 Ruins x6)
---------------------------------------------------------------------
M.SHAPES.jungle_ruin_block = { -- today's colliding parts: Base, 3 Walls, 2 Rubble
	{ "Block", 20.8, 1.2, 4.4, { 0, 0.6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 7, 10, 3.6, { -6.5, 5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 6, 6.5, 3.6, { 0, 3.25, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 7, 3.2, 3.6, { 6.5, 1.6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 3, 2.4, 2.6, { 5, 1.1, -4.6, 0.8975, -0.1261, 0.4226, 0.1392, 0.9903, 0, -0.4185, 0.0588, 0.9063 } },
	{ "Block", 2.6, 2, 2.4, { 8.6, 0.9, -3.8, 0.5, 0, 0.866, 0.1504, 0.9848, -0.0868, -0.8529, 0.1736, 0.4924 } },
}

-- The stepped ruin block (guide C4): today's 3 stepped wall blocks (10 / 6.5 / 3.2 tall) of cut stone courses (blocks
-- through the full depth, running bond, joints, a stone tone per block, a few greener blocks, chipped top corners);
-- today's base as 4 jointed chamfered plinth slabs; today's 2 rubble blocks as Agent A's chipped rubble, a small rubble
-- stone and 2 pebbles at the foot, 2 plant tufts in the joints and a fern; soft layered moss mats on the 3 tops (today's
-- 3 moss slabs: the middle top, the low top and the tall block's face, there one of Agent A's drapes over the tall
-- block's front edge); 2 thin vines.
-- Parts: Moss, Stone, Trim, Collision x6.
function Ruins.jungle_ruin_block(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_ruin_block"
	local rng = Random.new(20261251)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Trim = {}, Moss = {} }
	local DARK = rgb(92, 100, 92) -- #5C645C
	local STONE = rgb(132, 138, 124) -- #848A7C
	local MIDS = rgb(141, 147, 132) -- #8D9384 (today's middle block)
	local CORE = rgb(60, 66, 60)
	-- the 3 stepped blocks (today's colours kept: the middle one a touch lighter)
	stoneCourses(U.Stone, rng, -10, -3, 1.2, 10, 0, 3.6, 1.75, STONE, CORE, 2)
	stoneCourses(U.Stone, rng, -3, 3, 1.2, 6.5, 0, 3.6, 1.75, MIDS, CORE, 1)
	stoneCourses(U.Stone, rng, 3, 10, 1.2, 3.2, 0, 3.6, 1.0, STONE, CORE, 1)
	-- today's base (20.8 x 1.2 x 4.4) as 4 jointed plinth slabs
	local x = -10.4
	for _, len in ipairs({ 5.0, 5.6, 4.8, 5.4 }) do
		table.insert(U.Trim, chamfered(Vector3.new(len - 0.1, 1.2, 4.4), CFrame.new(x + len / 2, 0.6, 0), H.scaled(DARK, H.TONES[H.toneIndex(rng, nil)]), { "vertical", "topFrontBack", "topSides" }, 0.2))
		x += len
	end
	-- today's 2 rubble blocks as Agent A's chipped rubble stones (on today's exact places), a small one and 2 pebbles
	J.facets(U, RData.rubble_B, Vector3.one, CFrame.new(5, 1.1, -4.6, 0.8975, -0.1261, 0.4226, 0.1392, 0.9903, 0, -0.4185, 0.0588, 0.9063), "Stone")
	J.facets(U, RData.rubble_A, Vector3.one, CFrame.new(8.6, 0.9, -3.8, 0.5, 0, 0.866, 0.1504, 0.9848, -0.0868, -0.8529, 0.1736, 0.4924), "Stone")
	J.facets(U, RData.rubble_C, Vector3.one * 0.9, CFrame.new(-8.6, 0.45, -3.2) * CFrame.Angles(0, rad(30), rad(6)), "Trim")
	for _, s in ipairs({ { -2.0, -2.9, 0.75 }, { 10.8, -2.0, 0.7 } }) do
		looseStone(U.Trim, rng, Vector3.new(s[3] * 1.2, s[3] * 0.8, s[3]), CFrame.new(s[1], s[3] * 0.35, s[2]) * CFrame.Angles(rad(rng:NextNumber(-10, 10)), rng:NextNumber(0, 6.3), rad(rng:NextNumber(-10, 10))), H.scaled(DARK, rng:NextNumber(0.9, 1.15)))
	end
	-- moss: soft mats on today's moss places (the middle top, the low top, the tall top), a drape and 2 vines on the
	-- tall block's front (where today's face moss is)
	mossMat(U.Moss, rng, CFrame.new(0.3, 6.5, 0.1) * CFrame.Angles(0, rad(4), 0), 5.0, 2.6)
	mossMat(U.Moss, rng, CFrame.new(6.2, 3.2, -0.1) * CFrame.Angles(0, rad(-5), 0), 5.6, 2.4)
	mossMat(U.Moss, rng, CFrame.new(-7.2, 10, 0.2), 3.6, 2.2)
	J.mossFacet(U, "A", Vector3.new(-6.5, 10, -1.74), Vector3.new(0, 0, -1), 1.5)
	J.vineGroup(U.Moss, rng, Vector3.new(-4.6, 9.9, -1.86), Vector3.new(0, 0, -1), Vector3.xAxis, { 3.2, 4.6 })
	-- Agent A's small plants in the joints at the foot (on the plinth's front strip) and a fern on the ground
	for _, t in ipairs({ { RData.plant_tuft, -3.1, 1.2, -2.0, 0.75 }, { RData.plant_tuft, 3.2, 1.2, -2.0, 0.6 }, { RData.fern, -10.2, 0, -2.9, 0.9 } }) do
		J.facets(U, t[1], Vector3.one * t[5], CFrame.new(t[2], t[3], t[4]) * CFrame.Angles(0, rng:NextNumber(0, 6.3), 0), "Moss")
	end
	finish(m, "jungle_ruin_block", U, "Stone")
	return m
end

---------------------------------------------------------------------
-- 03 BROKEN PILLAR AND BLOCKS (kit MapAssets.Jungle.Ruin_Pillar_Broken, 6 parts; 13 copies, 8 baked at 0.8)
---------------------------------------------------------------------
local PILLAR_DRUM = CFrame.new(7.5, 2.1, 2, 0.866, 0, 0.5, 0, 1, 0, -0.5, 0, 0.866):Orthonormalize()
local PILLAR_CHUNK = CFrame.new(4.5, 1.1, -5, 0.6428, 0, 0.766, 0.1066, 0.9903, -0.0895, -0.7586, 0.1392, 0.6365):Orthonormalize()
M.SHAPES.jungle_broken_pillar = { -- today's colliding parts: Base, Stump, Break (wedge), Drum, Chunk
	{ "Block", 6, 1.6, 6, { 0, 0.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 4.2, 6.5, 4.2, { 0, 4.85, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "WedgePart", 4.2, 2.6, 4.2, { 0, 9.4, 0, 0.8192, 0, 0.5736, 0, 1, 0, -0.5736, 0, 0.8192 } },
	{ "Block", 4.2, 4.2, 6, { 7.5, 2.1, 2, 0.866, 0, 0.5, 0, 1, 0, -0.5, 0, 0.866 } },
	{ "Block", 3, 2.4, 3, { 4.5, 1.1, -5, 0.6428, 0, 0.766, 0.1066, 0.9903, -0.0895, -0.7586, 0.1392, 0.6365 } },
}

-- The broken pillar (guide C4): today's stump as a 0.3-chamfered shaft in 2 drums (a joint between them) with 2 carved
-- bands (a proud band between 2 dark grooves, a row of carved notches) and Agent A's jagged break on top (its crack
-- runs down the front); today's base as a 2-tier chamfered plinth with 2 chipped corners; today's fallen drum as an
-- 8-sided drum (fluted tones) with a chamfered end, a carved band and a broken end; today's chunk as Agent A's chipped
-- rubble; 2 small loose stones; moss: a soft mat on the low side of the break (today's top moss) with 2 part-built
-- drapes, a mat and a drape on the plinth; a plant tuft and a fern at the foot.
-- Parts: Moss, Stone, Trim, Collision x5.
function Ruins.jungle_broken_pillar(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_broken_pillar"
	local rng = Random.new(20261253)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Trim = {}, Moss = {} }
	local DARK = rgb(92, 100, 92) -- #5C645C (today's base and chunk)
	local STONE = rgb(132, 138, 124) -- #848A7C (today's stump and break)
	local DRUM = rgb(128, 134, 120) -- #808678 (today's drum)
	local GROOVE = rgb(60, 66, 60)
	-- the plinth (today's base 6 x 1.6 x 6): a 6 x 0.9 x 6 slab with 2 chipped corners under a 5.2 x 0.7 x 5.2 slab
	local negs = {}
	for _, c in ipairs({ { -1, -1 }, { 1, 1 } }) do
		table.insert(negs, piece("Part", Vector3.one * 0.9, CFrame.new(c[1] * 3, 0.9, c[2] * 3) * CFrame.Angles(rad(35), rad(45), 0), DARK))
	end
	table.insert(U.Trim, chamfered(Vector3.new(6, 0.9, 6), CFrame.new(0, 0.45, 0), DARK, { "vertical", "topFrontBack", "topSides" }, 0.22, negs))
	table.insert(U.Trim, chamfered(Vector3.new(5.2, 0.7, 5.2), CFrame.new(0, 1.25, 0), H.scaled(DARK, 1.06), { "vertical", "topFrontBack", "topSides" }, 0.18))
	-- the shaft (1.6 .. 8.0, Agent A's break continues it to the top): 2 drums with a dark joint, corners chamfered 0.3
	table.insert(U.Stone, piece("Part", Vector3.new(4.0, 6.4, 4.0), CFrame.new(0, 4.8, 0), GROOVE))
	table.insert(U.Stone, chamfered(Vector3.new(4.2, 3.24, 4.2), CFrame.new(0, 3.22, 0), H.scaled(STONE, 0.97):Lerp(MOSS[1], 0.06), { "vertical" }, 0.3))
	table.insert(U.Stone, chamfered(Vector3.new(4.2, 3.08, 4.2), CFrame.new(0, 6.46, 0), STONE, { "vertical" }, 0.3))
	-- 2 carved bands: a proud band (0.08 out) between 2 dark grooves, carved notches on its 4 faces
	for _, y in ipairs({ 2.55, 7.35 }) do
		table.insert(U.Trim, chamfered(Vector3.new(4.36, 0.42, 4.36), CFrame.new(0, y, 0), H.scaled(STONE, 1.05), { "vertical" }, 0.32))
		for _, dy in ipairs({ -0.3, 0.3 }) do
			table.insert(U.Trim, chamfered(Vector3.new(4.24, 0.07, 4.24), CFrame.new(0, y + dy, 0), GROOVE, { "vertical" }, 0.3))
		end
		for side = 0, 3 do
			local face = CFrame.Angles(0, side * math.pi / 2, 0)
			for k = -1, 1 do
				table.insert(U.Trim, piece("Part", Vector3.new(0.34, 0.18, 0.06), face * CFrame.new(k * 1.1, y, -2.17) * CFrame.Angles(0, 0, rad(45)), GROOVE))
			end
		end
	end
	-- Agent A's jagged break (the crack runs down the front face)
	J.facets(U, RData.pillar_break, Vector3.one, CFrame.identity, "Stone")
	-- the fallen drum (today's 4.2 x 4.2 x 6 lying drum): an 8-sided drum along its length, a chamfered end, a carved
	-- band and a broken end (a lighter jagged stub, a chip knocked off the rim)
	local axis = PILLAR_DRUM * CFrame.Angles(rad(90), 0, 0) -- Y along today's drum length
	local tones = { DRUM, H.scaled(DRUM, 0.93), H.scaled(DRUM, 1.04), H.scaled(DRUM, 0.96) }
	table.insert(U.Stone, M.frustumN(8, 1.86, 2.1, -3.0, -2.62, axis, tones))
	table.insert(U.Stone, M.frustumN(8, 2.1, 2.1, -2.62, 2.45, axis, tones))
	table.insert(U.Trim, M.frustumN(8, 2.16, 2.16, -1.75, -1.35, axis, { H.scaled(DRUM, 1.06), H.scaled(DRUM, 0.98) }))
	table.insert(U.Trim, M.frustumN(8, 1.98, 1.98, -1.85, -1.25, axis, { GROOVE }))
	table.insert(U.Stone, M.frustumN(8, 2.1, 1.7, 2.45, 2.72, axis * CFrame.Angles(rad(6), 0, rad(-4)), { H.scaled(DRUM, 1.12), H.scaled(DRUM, 1.05) }))
	table.insert(U.Stone, M.frustumN(6, 1.2, 0.55, 2.6, 2.98, axis * CFrame.new(0.5, 0, -0.3) * CFrame.Angles(rad(-9), 0, rad(7)), { H.scaled(DRUM, 1.16), H.scaled(DRUM, 1.08) }))
	-- today's chunk as Agent A's chipped rubble (its box scaled to today's 3 x 2.4 x 3), 2 small loose stones
	J.facets(U, RData.rubble_B, Vector3.new(1, 1, 3 / 2.6), PILLAR_CHUNK, "Trim")
	looseStone(U.Trim, rng, Vector3.new(1.0, 0.65, 0.85), CFrame.new(-3.9, 0.3, -2.6) * CFrame.Angles(0, rad(40), rad(5)), H.scaled(DARK, 1.05))
	looseStone(U.Trim, rng, Vector3.new(0.8, 0.5, 0.7), CFrame.new(3.4, 0.24, 4.6) * CFrame.Angles(rad(4), rad(-70), 0), H.scaled(DRUM, 0.95))
	-- moss: a soft mat on the low (back-left) side of the break with 2 drapes over its edges; the plinth's front-left
	-- corner (a mat and a drape)
	mossMat(U.Moss, rng, CFrame.new(-1.0, 8.42, 1.25) * CFrame.Angles(rad(9), rad(-30), rad(11)), 2.2, 1.6, 0.8)
	partDrape(U.Moss, rng, Vector3.new(-0.9, 8.38, 2.12), Vector3.new(0, 0, 1), 1.7, 0.7, 1.5)
	partDrape(U.Moss, rng, Vector3.new(-2.12, 8.45, 0.7), Vector3.new(-1, 0, 0), 1.4, 0.6, 1.1)
	mossMat(U.Moss, rng, CFrame.new(-1.2, 1.6, -2.55), 2.6, 0.9, 0.7)
	partDrape(U.Moss, rng, Vector3.new(-1.4, 1.6, -2.62), Vector3.new(0, 0, -1), 1.8, 0.5, 0.65)
	-- Agent A's plant tuft and fern at the foot
	J.facets(U, RData.plant_tuft, Vector3.one * 0.8, CFrame.new(3.3, 0, -1.6) * CFrame.Angles(0, rad(20), 0), "Moss")
	J.facets(U, RData.fern, Vector3.one * 0.8, CFrame.new(-3.6, 0, 2.6) * CFrame.Angles(0, rad(130), 0), "Moss")
	finish(m, "jungle_broken_pillar", U, "Stone")
	return m
end

---------------------------------------------------------------------
-- 04 MOSSY SLABS (kit MapAssets.Jungle.SteppingStone_A, 3 parts; 5 copies, Jungle_2 river crossing) - WALKABLE
---------------------------------------------------------------------
M.SHAPES.mossy_slabs = { -- today's colliding Stone (the Skirt is a MeshPart: cloned from the kit below)
	{ "Block", 6.4, 1.6, 6, { 0, 0.8, 0, 0.9511, 0, 0.309, 0, 1, 0, -0.309, 0, 0.9511 } },
}
local SLAB_SKIRT_MESH = "7231644778"

-- The mossy slabs (guide C4): a stepping stone players walk on. Agent A's upper slab (today's Stone + Moss: an
-- irregular chipped outline, the FLAT top exactly at today's 1.6 with a 0.15 bevel, 2 cracks, a soft 2-layer moss
-- patch at most 0.16 proud) over Agent A's lower slab (today's Skirt); a small moss mat, 2 plant tufts and a small fern
-- on the lower slab's ledge, all below the top. Collision: today's Stone box and today's Skirt MeshPart (cloned from the
-- kit, invisible), so the walk surface is exactly today's.
-- Parts: Stone, Collision x2.
function Ruins.mossy_slabs(): Model
	local m = Instance.new("Model")
	m.Name = "mossy_slabs"
	local rng = Random.new(20261254)
	H.setBevelSelf(true)
	local U: any = { Stone = {} }
	J.facets(U, RData.slab_top, Vector3.one, CFrame.identity, "Stone")
	J.facets(U, RData.slab_low, Vector3.one, CFrame.identity, "Stone")
	-- on the lower slab's ledge (its top at 1.15): a small moss mat, 2 tufts and a fern (all under the walk top)
	mossMat(U.Stone, rng, CFrame.new(-3.9, 1.15, 0.2) * CFrame.Angles(0, rad(95), 0), 1.6, 0.6, 0.5)
	for _, t in ipairs({ { RData.plant_tuft, 3.9, 1.13, 0.2, 0.55 }, { RData.plant_tuft, -0.3, 1.1, -4.1, 0.45 }, { RData.fern, 0.2, 1.1, 4.15, 0.4 } }) do
		J.facets(U, t[1], Vector3.one * t[5], CFrame.new(t[2], t[3], t[4]) * CFrame.Angles(0, rng:NextNumber(0, 6.3), 0), "Stone")
	end
	finish(m, "mossy_slabs", U, "Stone")
	-- today's Skirt MeshPart as an invisible collider (from the kit: its Skirt, or the Collision MeshPart of an earlier
	-- build of this template)
	local kit = ServerStorage:FindFirstChild("MapAssets") and ServerStorage.MapAssets:FindFirstChild("Jungle") and ServerStorage.MapAssets.Jungle:FindFirstChild("SteppingStone_A")
	assert(kit, "mossy_slabs: the kit MapAssets.Jungle.SteppingStone_A is needed (its Skirt MeshPart is today's collider)")
	local piv = kit:GetPivot()
	local count = 0
	for _, p in ipairs(kit:GetChildren()) do
		if p:IsA("MeshPart") and p.CanCollide and string.find(p.MeshId, SLAB_SKIRT_MESH, 1, true) then
			local c = p:Clone()
			c:ClearAllChildren()
			c.Name = "Collision"
			c.CFrame = piv:ToObjectSpace(p.CFrame)
			c.Anchored = true
			c.CanCollide = true
			c.CanQuery = true
			c.CanTouch = false
			c.CastShadow = false
			c.Transparency = 1
			c.Parent = m
			count += 1
		end
	end
	assert(count == 1, `mossy_slabs: expected today's 1 colliding Skirt MeshPart in the kit, found {count}`)
	return m
end

---------------------------------------------------------------------
-- 05 GLOWING FLOOR PAD (kit MapAssets.Jungle.Glyph_Tile, 6 parts; 36 copies, 1 baked at 1.6 in BossArenas)
---------------------------------------------------------------------
-- The glowing floor pad (guide C4): pure floor decoration (no script, tag or touch handler anywhere; today nothing in
-- it collides, is queried, touched or casts a shadow, and that stays so). Today's tile as a bevelled stone tile with a
-- chipped corner and 2 hairline cracks; a darker groove under the glowing frame (the frame sits in it); a raised,
-- lighter setting round the diamond; soft moss in 2 corners and a tuft. Today's 5 Neon #78FFBE Glyph parts are kept
-- as they are (same names, sizes and places; the diamond 0.05 higher to sit on its setting). No lights (one template
-- for all 36 copies: none, as allowed).
-- Parts: Stone, Glyph x5.
function Ruins.glyph_floor_pad(): Model
	local m = Instance.new("Model")
	m.Name = "glyph_floor_pad"
	local rng = Random.new(20261255)
	H.setBevelSelf(true)
	local U: any = { Stone = {} }
	local DARK = rgb(92, 100, 92) -- #5C645C (today's tile)
	local GROOVE = rgb(41, 45, 41)
	local SETTING = rgb(132, 138, 124)
	-- the tile (8 x 0.3 x 8): bevelled, a chipped corner, 2 hairline cracks
	local negs = { piece("Part", Vector3.one * 0.9, CFrame.new(4, 0.3, 4) * CFrame.Angles(rad(30), rad(45), 0), DARK) }
	table.insert(U.Stone, chamfered(Vector3.new(8, 0.3, 8), CFrame.new(0, 0.15, 0), DARK, { "vertical", "topFrontBack", "topSides" }, 0.18, negs))
	for _, c in ipairs({ { -3.0, -3.3, 1.3, 25 }, { 3.2, -2.6, 1.0, -40 } }) do
		table.insert(U.Stone, piece("Part", Vector3.new(c[3], 0.02, 0.06), CFrame.new(c[1], 0.3, c[2]) * CFrame.Angles(0, rad(c[4]), 0), GROOVE))
	end
	-- the groove under the glowing frame (0.2 wider each side, flush with the tile top)
	for _, g in ipairs({ { 0, -2.2, 5.4, 1.0 }, { 0, 2.2, 5.4, 1.0 }, { -2.2, 0, 1.0, 3.4 }, { 2.2, 0, 1.0, 3.4 } }) do
		table.insert(U.Stone, piece("Part", Vector3.new(g[3], 0.04, g[4]), CFrame.new(g[1], 0.29, g[2]), GROOVE))
	end
	-- the raised setting round the diamond: a lighter chamfered plate turned 45 deg with a dark rim
	table.insert(U.Stone, chamfered(Vector3.new(2.3, 0.06, 2.3), CFrame.new(0, 0.3, 0) * CFrame.Angles(0, rad(45), 0), GROOVE, { "vertical" }, 0.3))
	table.insert(U.Stone, chamfered(Vector3.new(2.0, 0.12, 2.0), CFrame.new(0, 0.33, 0) * CFrame.Angles(0, rad(45), 0), SETTING, { "vertical", "topFrontBack", "topSides" }, 0.05))
	-- soft moss in 2 corners and a small tuft
	mossMat(U.Stone, rng, CFrame.new(-2.95, 0.3, 3.0) * CFrame.Angles(0, rad(-45), 0), 2.4, 1.0, 0.5)
	mossMat(U.Stone, rng, CFrame.new(3.1, 0.3, -3.05) * CFrame.Angles(0, rad(-40), 0), 1.9, 0.85, 0.45)
	J.facets(U, RData.plant_tuft, Vector3.one * 0.45, CFrame.new(3.55, 0.28, -3.6), "Stone")
	finish(m, "glyph_floor_pad", U, "Stone")
	for _, u in ipairs(m:GetChildren()) do
		if u:IsA("BasePart") then
			u.CanCollide = false
			u.CanQuery = false
			u.CanTouch = false
			u.CastShadow = false
		end
	end
	-- today's 5 glowing Glyph parts, kept
	local GLOW = rgb(120, 255, 190) -- #78FFBE
	local flags = { collide = false, query = false, touch = false, shadow = false, neon = true }
	G.exact(m, "Part", "Glyph", Vector3.new(5, 0.1, 0.6), CFrame.new(0, 0.31, -2.2), GLOW, flags)
	G.exact(m, "Part", "Glyph", Vector3.new(0.6, 0.1, 3.8), CFrame.new(-2.2, 0.31, 0), GLOW, flags)
	G.exact(m, "Part", "Glyph", Vector3.new(5, 0.1, 0.6), CFrame.new(0, 0.31, 2.2), GLOW, flags)
	G.exact(m, "Part", "Glyph", Vector3.new(0.6, 0.1, 3.8), CFrame.new(2.2, 0.31, 0), GLOW, flags)
	G.exact(m, "Part", "Glyph", Vector3.new(1.5, 0.1, 1.5), CFrame.new(0, 0.36, 0) * CFrame.Angles(0, rad(45), 0), GLOW, flags)
	return m
end

---------------------------------------------------------------------
-- 02 STONE STAIRS (kit MapAssets.Jungle.Ruin_Stairs, 10 parts; 2 copies, Jungle_3 Ruins) - WALKABLE
---------------------------------------------------------------------
-- today's 5 steps: x0, x1, the tread top, the front z (each 3 deep), today's colour
local STAIR_STEPS = {
	{ -7, 7, 1.5, -7.5, rgb(98, 106, 98) }, -- #626A62
	{ -7, 7, 3.0, -4.5, rgb(131, 137, 123) }, -- #83897B
	{ -7, 7, 4.5, -1.5, rgb(87, 95, 87) }, -- #575F57
	{ -7, 5, 6.0, 1.5, rgb(131, 137, 123) },
	{ -7, 2, 7.5, 4.5, rgb(87, 95, 87) },
}
local STAIR_RUBBLE = CFrame.new(9.5, 1, 4.5, 0.8013, -0.1703, 0.5736, 0.2079, 0.9781, 0, -0.561, 0.1193, 0.8192):Orthonormalize()
M.SHAPES.jungle_ruin_stairs = { -- today's colliding parts: 5 Steps, 2 Cheeks, Rubble
	{ "Block", 14, 1.5, 3, { 0, 0.75, -6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 14, 3, 3, { 0, 1.5, -3, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 14, 4.5, 3, { 0, 2.25, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 12, 6, 3, { -1, 3, 3, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 9, 7.5, 3, { -2.5, 3.75, 6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 2, 4.6, 15, { -8, 2.3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 2, 2.6, 8, { 8, 1.3, -3.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 3, 2.2, 2.6, { 9.5, 1, 4.5, 0.8013, -0.1703, 0.5736, 0.2079, 0.9781, 0, -0.561, 0.1193, 0.8192 } },
}

-- thin moss on a tread (never more than 0.13 above it) creeping over the nose and a little down the riser: `frame` at
-- the nose (X along it, Y up, the riser looking -Z); w wide, `depth` back over the tread, `drop` down the riser
local function treadMoss(list: { BasePart }, rng: Random, frame: CFrame, w: number, depth: number, drop: number)
	local n = math.max(2, math.floor(w / 1.2 + 0.5))
	for k = 1, n do
		local x = -w / 2 + (k - 0.5) * w / n + rng:NextNumber(-0.15, 0.15)
		local pw, pd = w / n * rng:NextNumber(1.2, 1.5), depth * rng:NextNumber(0.6, 1.0)
		local cf = frame * CFrame.new(x, 0.04, pd / 2 - 0.02) * CFrame.Angles(0, rad(rng:NextNumber(-15, 15)), 0)
		table.insert(list, chamfered(Vector3.new(pw, 0.08, pd), cf, H.scaled(MOSS[1], rng:NextNumber(0.96, 1.04)), { "vertical" }, math.min(pw, pd) * 0.35))
		if rng:NextNumber() < 0.7 then
			local cf2 = frame * CFrame.new(x + rng:NextNumber(-0.2, 0.2), 0.1, pd * 0.45) * CFrame.Angles(0, rad(rng:NextNumber(-25, 25)), 0)
			table.insert(list, chamfered(Vector3.new(pw * 0.6, 0.05, pd * 0.55), cf2, H.scaled(MOSS[2], rng:NextNumber(0.96, 1.04)), { "vertical" }, math.min(pw, pd) * 0.2))
		end
	end
	-- the curtain down the riser (a thin rounded plate on the face, its foot in 2 lobes)
	local cw = w * rng:NextNumber(0.55, 0.75)
	local cx = rng:NextNumber(-0.15, 0.15) * w
	table.insert(list, chamfered(Vector3.new(cw, 0.07, drop * 0.7), frame * CFrame.new(cx, -drop * 0.35, -0.03) * CFrame.Angles(rad(90), 0, 0), MOSS[1], { "vertical" }, math.min(cw, drop) * 0.25))
	for k = -1, 1, 2 do
		local lw = cw * rng:NextNumber(0.35, 0.5)
		table.insert(list, chamfered(Vector3.new(lw, 0.07, drop * 0.5), frame * CFrame.new(cx + k * cw * 0.22, -drop * 0.7, -0.03) * CFrame.Angles(rad(90), 0, 0), H.scaled(MOSS[1], 0.95), { "vertical" }, lw * 0.4))
	end
end

-- one step's column (x0 .. x1, 0 .. top, z0 .. z0 + 3): courses of cut stone 1.5 tall in running bond over a dark core;
-- the top course is the tread: its top EXACTLY at `top` (today's tread), its front-top edge (the nose) bevelled 0.15,
-- 2 worn notches (0.4 x 0.15) in the nose; the lower courses a little darker (seen on the sides and the back)
local function stepColumn(list: { BasePart }, rng: Random, x0: number, x1: number, top: number, z0: number, color: Color3, dark: Color3)
	table.insert(list, piece("Part", Vector3.new(x1 - x0 - 0.16, top - 0.12, 2.84), CFrame.new((x0 + x1) / 2, (top - 0.12) / 2, z0 + 1.5), dark))
	local rows = math.floor(top / 1.5 + 0.5)
	local notches = 2
	for row = rows, 1, -1 do
		local yTop = if row == rows then top else row * 1.5 - 0.04
		local yBot = (row - 1) * 1.5 + (if row == 1 then 0 else 0.04)
		local isTread = row == rows
		local x = x0 - (if row % 2 == 0 then rng:NextNumber(0.8, 1.6) else 0)
		while x < x1 - 0.05 do
			local len = rng:NextNumber(2.6, 4.2)
			local a, b = math.max(x, x0), math.min(x + len, x1)
			if b - a > 0.5 then
				local c = H.scaled(color, H.TONES[H.toneIndex(rng, nil)] * (if isTread then 1 else 0.92))
				local size = Vector3.new(b - a - 0.08, yTop - yBot, 3)
				local cf = CFrame.new((a + b) / 2, (yTop + yBot) / 2, z0 + 1.5)
				local negs = {}
				if isTread and notches > 0 and size.X > 1.4 and rng:NextNumber() < 0.6 then
					local nx = rng:NextNumber(-size.X / 2 + 0.5, size.X / 2 - 0.5)
					table.insert(negs, piece("Part", Vector3.new(0.4, 0.2, 0.2), cf * CFrame.new(nx, size.Y / 2, -1.5) * CFrame.Angles(rad(45), 0, 0), dark))
					notches -= 1
				end
				table.insert(list, chamfered(size, cf, c, if isTread then { "topFrontBack", "vertical" } else { "vertical" }, if isTread then 0.15 else 0.1, negs))
			end
			x += len
		end
	end
end

-- The stone stairs (guide C4): players walk on them, so today's 5 treads keep their exact tops (1.5 / 3 / 4.5 / 6 /
-- 7.5), fronts and widths, and today's 8 colliding parts (5 steps, 2 cheeks, the rubble) stay as invisible colliders.
-- Each step is a column of cut stone courses (running bond, tones per block, today's step colour) whose top course is
-- the tread with a 0.15 bevelled nose and 2 small worn notches; the 2 cheek walls as coursed stone with chipped top
-- corners; today's rubble as Agent A's chipped rubble; thin moss on 2 treads (at most 0.13 above them) creeping over the
-- nose, a soft mat and 2 part-built drapes on the left cheek (today's moss); 2 loose stones and 3 tufts on the ground
-- beside. Nothing visible rises above a tread top except that thin moss.
-- Parts: Moss, Stone, Trim, Collision x8.
function Ruins.jungle_ruin_stairs(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_ruin_stairs"
	local rng = Random.new(20261252)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Trim = {}, Moss = {} }
	local CHEEK = rgb(92, 100, 92) -- #5C645C
	local CORE = rgb(52, 58, 52)
	for _, st in ipairs(STAIR_STEPS) do
		stepColumn(U.Stone, rng, st[1], st[2], st[3], st[4], st[5], CORE)
	end
	-- the cheek walls (left 2 x 4.6 x 15, right 2 x 2.6 x 8) as coursed stone along their length
	stoneCourses(U.Trim, rng, -7.5, 7.5, 0, 4.6, 0, 2, 1.53, CHEEK, CORE, 2, CFrame.new(-8, 0, 0) * CFrame.Angles(0, rad(90), 0))
	stoneCourses(U.Trim, rng, -4, 4, 0, 2.6, 0, 2, 1.3, CHEEK, CORE, 1, CFrame.new(8, 0, -3.5) * CFrame.Angles(0, rad(90), 0))
	-- today's rubble as Agent A's chipped rubble (its box scaled to today's 3 x 2.2 x 2.6), 2 loose stones
	J.facets(U, RData.rubble_B, Vector3.new(1, 2.2 / 2.4, 1), STAIR_RUBBLE, "Trim")
	looseStone(U.Trim, rng, Vector3.new(1.1, 0.7, 0.9), CFrame.new(10.2, 0.32, 1.6) * CFrame.Angles(0, rad(25), rad(4)), H.scaled(CHEEK, 1.1))
	looseStone(U.Trim, rng, Vector3.new(0.8, 0.5, 0.7), CFrame.new(-9.6, 0.24, -6.6) * CFrame.Angles(rad(5), rad(-50), 0), H.scaled(CHEEK, 1.05))
	-- moss: thin on the 3rd tread's left half (today's tread moss) and the 1st tread's left corner, over their noses;
	-- a soft mat on the left cheek's top (today's cheek moss) with drapes over its outer face and its front end
	treadMoss(U.Moss, rng, CFrame.new(-4.3, 4.5, -1.5), 3.4, 1.9, 0.8)
	treadMoss(U.Moss, rng, CFrame.new(-5.7, 1.5, -7.5), 1.6, 1.0, 0.55)
	mossMat(U.Moss, rng, CFrame.new(-8, 4.55, 2.2) * CFrame.Angles(0, rad(90), 0), 5.2, 1.7)
	partDrape(U.Moss, rng, Vector3.new(-9.02, 4.55, 1.2), Vector3.new(-1, 0, 0), 2.4, 0.8, 1.7)
	partDrape(U.Moss, rng, Vector3.new(-8.1, 4.55, -7.52), Vector3.new(0, 0, -1), 1.5, 0.7, 1.4)
	-- Agent A's tufts on the ground beside the stairs (inside today's footprint)
	for _, t in ipairs({ { RData.plant_tuft, 7.4, 0, 1.4, 0.8 }, { RData.plant_tuft, 3.4, 0, 6.9, 0.7 }, { RData.plant_tuft, -9.45, 0, 5.8, 0.6 } }) do
		J.facets(U, t[1], Vector3.one * t[5], CFrame.new(t[2], t[3], t[4]) * CFrame.Angles(0, rng:NextNumber(0, 6.3), 0), "Moss")
	end
	finish(m, "jungle_ruin_stairs", U, "Stone")
	return m
end
Ruins.STAIR_STEPS = STAIR_STEPS

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table as the jungle gates; its install() builds them
---------------------------------------------------------------------
Ruins.BUILDERS = { jungle_ruin_block = true, jungle_broken_pillar = true, mossy_slabs = true, glyph_floor_pad = true, jungle_ruin_stairs = true }
for id in pairs(Ruins.BUILDERS) do
	B2[id] = (Ruins :: any)[id]
	B2.BUILDERS[id] = true
end
Ruins.install = B2.install
Ruins.SHAPES = M.SHAPES
Ruins.G = G

return Ruins
