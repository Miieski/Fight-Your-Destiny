--[[
	PropsJungleBuildings (dev tool, Edit mode only) - the owner's "JUNGLE ZONE PROP IMPROVEMENT - Buildings and temples"
	(2026-10-20, jungle PROMPT_01): the stone face temple (the Jungle_4 gate), the stone head, the ruined stone
	building, the six-slot wall and the stilt hut rebuilt in the jungle recipe (docs/prop_texture_guide.md sections A,
	B, C), keeping each object's colours, place, size, glow, function and collision. Source of truth:
	tools/PropsJungleBuildings.luau. Inventory: docs/prop_inventory.md "Jungle buildings".

	Collision: the visible unions never collide; invisible "Collision" parts are the kit's colliding parts (same shape,
	size and place), so no copy is more (or less) solid than today.

	It uses DevTools.PropsDesertMonuments (its helpers, finish() and the SHAPES table) and registers its builders into
	PropsDesert's PropsBatch2 table:
		local J = require(game.ServerStorage.DevTools.PropsJungleBuildings:Clone())
		print(J.install("jungle_ruin_building"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "jungle_ruin_building" } }), Sync.run({ only = { "jungle_ruin_building" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local M = require(ServerStorage.DevTools.PropsDesertMonuments:Clone()) :: any
local D = M.D
local B2 = D.B2
local H = B2.H
local piece, chamfered = H.piece, H.chamfered
local finish = M.finish
local Data = require(ServerStorage.DevTools.PropsJungleBuildingsData:Clone()) :: any -- Agent A's facet pieces

local Jungle = {}

local rgb = Color3.fromRGB
local rad = math.rad

-- the jungle palette (guide C): today's stone colours kept, moss and vine greens
local STONE, STONE_MID, STONE_DARK, RECESS = rgb(132, 138, 124), rgb(123, 129, 116), rgb(92, 100, 92), rgb(41, 45, 41)
local MOSS = { rgb(88, 150, 66), rgb(96, 196, 72), rgb(120, 210, 70) } -- #589642 -> #60C448 -> #78D246
local VINE = rgb(70, 170, 60) -- #46AA3C

local function shape(kind: string, sx: number, sy: number, sz: number, cf: CFrame): any
	return { kind, sx, sy, sz, { cf:GetComponents() } }
end
Jungle.shape = shape

-- a face of cut stone blocks on the plane z = zf (front: the face looks -Z) between x0 .. x1 and y0 .. y1 (guide C2):
-- courses of about `ch`, blocks 2 .. 4 long in running bond, 0.09 joints over the dark core, a 0.12 chamfer, 3 tone
-- steps and the gradient, 15 % of the blocks greener; `cracks` zig-zag cracks (#292D29, 0.08) over 1-2 blocks;
-- skip(x, y) leaves a block out (a slot, a frame); lenMul scales the blocks, joints and chamfer (the temple face: 2)
local function stoneFace(list: { BasePart }, rng: Random, x0: number, x1: number, y0: number, y1: number, zf: number, front: boolean, ch: number, color: Color3, skip: any?, cracks: number?, lenMul: number?)
	local n = math.max(1, math.floor((y1 - y0) / ch + 0.5))
	local h = (y1 - y0) / n
	local dir = if front then -1 else 1
	local prev = nil
	for row = 0, n - 1 do
		local yc = y0 + (row + 0.5) * h
		local lm = lenMul or 1
		local x = x0 - (if row % 2 == 0 then 0 else rng:NextNumber(0.8, 1.6) * lm)
		while x < x1 - 0.05 do
			local len = rng:NextNumber(2.0, 4.0) * lm
			local a, b = math.max(x, x0), math.min(x + len, x1)
			if b - a > 0.3 and not (skip and skip((a + b) / 2, yc)) then
				local ti = H.toneIndex(rng, prev)
				prev = ti
				local c = H.scaled(color, H.TONES[ti] * (0.92 + 0.1 * (yc - y0) / math.max(y1 - y0, 1)))
				if rng:NextNumber() < 0.15 then
					c = c:Lerp(MOSS[1], 0.15)
				end
				local th = 0.24 * math.max(1, lm * 0.6)
				table.insert(list, chamfered(Vector3.new(b - a - 0.09 * lm, h - 0.09 * lm, th), CFrame.new((a + b) / 2, yc, zf + dir * th / 2), c, { "frontFace" }, 0.12 * lm))
			end
			x += len
		end
	end
	-- zig-zag cracks
	for _ = 1, cracks or 0 do
		local cx, cy = rng:NextNumber(x0 + 1, x1 - 1), rng:NextNumber(y0 + h, y1 - h)
		if not (skip and skip(cx, cy)) then
			local p = Vector2.new(cx, cy)
			for _ = 1, rng:NextInteger(3, 4) do
				local q = p + Vector2.new(rng:NextNumber(-0.35, 0.35), -rng:NextNumber(0.35, 0.6))
				local mid, d = (p + q) / 2, q - p
				table.insert(list, piece("Part", Vector3.new(0.08, d.Magnitude + 0.06, 0.04), CFrame.new(mid.X, mid.Y, zf + dir * (0.24 * math.max(1, (lenMul or 1) * 0.6) + 0.01)) * CFrame.Angles(0, 0, math.atan2(-d.X, d.Y)), RECESS))
				p = q
			end
		end
	end
end
Jungle.stoneFace = stoneFace

-- soft moss lying ON a surface (`frame` at the surface centre, Y out of it), over a w x d area: 2-4 low mounds of
-- different sizes and outlines that run together, each 2-3 stacked rounded layers (#589642 -> #60C448 -> #78D246,
-- each about 70 % of the one below), 0.3 .. 0.6 tall in all (times hMul), turned at random so no two outlines match
local function mossPatch(list: { BasePart }, rng: Random, frame: CFrame, w: number, d: number, hMul: number?)
	local count = math.clamp(math.floor(w * d / 2.5) + 1, 2, 4)
	for k = 1, count do
		local cx = if count > 1 then -w / 2 + w * (k - 0.5) / count + rng:NextNumber(-0.15, 0.15) * w / count else 0
		local cz = rng:NextNumber(-0.15, 0.15) * d
		local mw = math.min(w / count * rng:NextNumber(1.25, 1.6), w)
		local md = d * rng:NextNumber(0.6, 0.95)
		local yaw = rad(rng:NextNumber(-30, 30))
		local h = rng:NextNumber(0.3, 0.6) * (hMul or 1)
		local layers = { { 1.0, MOSS[1], 0.45 }, { 0.7, MOSS[2], 0.33 }, { 0.48, MOSS[3], 0.22 } }
		local y = 0
		for li, l in ipairs(layers) do
			if li == 3 and rng:NextNumber() < 0.35 then
				break
			end
			local lw, ld, t = mw * l[1], md * l[1], h * l[3]
			local off = if li > 1 then Vector3.new(rng:NextNumber(-0.12, 0.12) * mw, 0, rng:NextNumber(-0.12, 0.12) * md) else Vector3.zero
			local cf = frame * CFrame.new(cx + off.X, y + t / 2, cz + off.Z) * CFrame.Angles(0, yaw + rad(rng:NextNumber(-12, 12)), 0)
			table.insert(list, chamfered(Vector3.new(lw, t, ld), cf, H.scaled(l[2], rng:NextNumber(0.95, 1.05)), { "vertical" }, math.min(lw, ld) * rng:NextNumber(0.28, 0.4)))
			y += t * 0.85
		end
	end
end
Jungle.mossPatch = mossPatch

-- moss DRAPING over an edge (guide C2): frame at the edge (X along the edge, Y up, the face below looks -Z); low
-- mounds on the top (w wide, `depth` back from the edge), a rounded roll over the edge, and 2 thin curtains following
-- the face (the first `drop` long and dark, the second 70 % and lighter, both starting under the edge, never above it)
-- with a scalloped foot of 2-3 rounded lobes and a thin drip lip
local function mossDrape(list: { BasePart }, rng: Random, frame: CFrame, w: number, depth: number, drop: number)
	mossPatch(list, rng, frame * CFrame.new(0, 0, depth / 2 - 0.05), w, depth)
	table.insert(list, piece("Part", Vector3.new(w * 0.85, 0.26, 0.26), frame * CFrame.new(0, -0.04, -0.03), MOSS[1], { shape = Enum.PartType.Cylinder }))
	-- a thin rounded plate on the face (its thin axis into the wall)
	local function blob(x: number, yTop: number, bw: number, bh: number, z: number, t: number, color: Color3)
		local cf = frame * CFrame.new(x, yTop - bh / 2, z) * CFrame.Angles(rad(90), 0, 0)
		table.insert(list, chamfered(Vector3.new(bw, t, bh), cf, color, { "vertical" }, math.min(bw, bh) * 0.32))
	end
	local layers = { { 1.0, MOSS[1], 0.08, -0.04 }, { 0.7, MOSS[2], 0.06, -0.09 } }
	for _, l in ipairs(layers) do
		local lw, ld = w * l[1] * rng:NextNumber(0.85, 1.0), drop * l[1]
		local x0 = rng:NextNumber(-0.1, 0.1) * w
		blob(x0, -0.05, lw, ld * 0.72, l[4], l[3], l[2])
		local lobes = rng:NextInteger(2, 3)
		for k = 1, lobes do
			local bw = lw / lobes * rng:NextNumber(0.9, 1.2)
			local x = x0 - lw / 2 + (k - 0.5) * lw / lobes
			blob(x, -0.05 - ld * 0.55, bw, ld * rng:NextNumber(0.3, 0.5), l[4], l[3], l[2])
		end
	end
	table.insert(list, piece("Part", Vector3.new(w * 0.5, 0.16, 0.16), frame * CFrame.new(rng:NextNumber(-0.15, 0.15) * w, -drop * 0.95, -0.06), H.scaled(MOSS[1], 0.92), { shape = Enum.PartType.Cylinder }))
end
Jungle.mossDrape = mossDrape

-- a hanging vine (guide C2) from `top` (world, on the face; `out` = the face normal), `length` long: a tapering stem
-- (0.18 -> 0.06) of swaying segments, leaves 0.5 x 0.3 every 0.8 .. 1.2 on alternating sides (#78D246 / #60C448)
local function vine(list: { BasePart }, rng: Random, top: Vector3, out: Vector3, length: number)
	local side = Vector3.yAxis:Cross(out).Unit
	local phase = rng:NextNumber(0, 6)
	local p = top
	local y = 0
	local nextLeaf = rng:NextNumber(0.4, 0.8)
	local sgn = 1
	while y < length - 0.05 do
		local step = math.min(rng:NextNumber(0.6, 0.9), length - y)
		local yy = y + step
		local q = top + Vector3.new(0, -yy, 0) + side * math.sin(yy * 1.3 + phase) * 0.22 + out * 0.04
		table.insert(list, H.bar(p, q, 0.18 - 0.12 * (y + step / 2) / length, H.scaled(VINE, 0.92 + 0.08 * math.sin(yy))))
		while nextLeaf <= yy do
			local f = (nextLeaf - y) / step
			local at = p:Lerp(q, f)
			local leafPos = at + side * sgn * 0.22 + out * 0.04
			table.insert(list, piece("Part", Vector3.new(0.3, 0.5, 0.05), CFrame.lookAt(leafPos, leafPos + out) * CFrame.Angles(0, 0, rad(sgn * 40)), if sgn > 0 then MOSS[3] else MOSS[2]))
			sgn = -sgn
			nextLeaf += rng:NextNumber(0.8, 1.2)
		end
		p = q
		y = yy
	end
end
-- a group of 2-3 vines of different lengths hanging from `top` along the face
local function vineGroup(list: { BasePart }, rng: Random, top: Vector3, out: Vector3, along: Vector3, lengths: { number })
	for i, l in ipairs(lengths) do
		vine(list, rng, top + along * ((i - (#lengths + 1) / 2) * 0.55), out, l)
	end
end
Jungle.vineGroup = vineGroup

-- one of Agent A's facet pieces (DevTools.PropsJungleBuildingsData) as wedge pairs in `frame`, scaled by sc: the Neon
-- colours go to U.Glow, every other colour to U[key] (colours kept)
local function facets(U: any, data: any, sc: Vector3, frame: CFrame, key: string)
	local ts = math.min(sc.X, sc.Y, sc.Z)
	local colors, lists = {}, {}
	for i, entry in ipairs(data.palette) do
		local hex, mat = string.match(entry, "^(#%x+)|?(%a*)$")
		colors[i] = Color3.fromHex(hex :: string)
		local dest = if mat == "Neon" then "Glow" else key
		U[dest] = U[dest] or {}
		lists[i] = U[dest]
	end
	for _, t in ipairs(data.tris) do
		local a = Vector3.new(t[1], t[2], t[3]) * sc
		local b = Vector3.new(t[4], t[5], t[6]) * sc
		local c = Vector3.new(t[7], t[8], t[9]) * sc
		H.triangleParts(lists[t[11]], a, b, c, t[10] * ts, frame, colors[t[11]])
	end
end
Jungle.facets = facets

-- Agent A's moss drape (variant "A" / "B" / "C") anchored on a top-front edge: `edge` = a point on the edge, `out` =
-- the face's outward normal (horizontal); the patch goes back over the top and down the face; uniform scale 0.7-1.6
local function mossFacet(U: any, variant: string, edge: Vector3, out: Vector3, scale: number)
	-- (CFrame.lookAt points the frame's -Z along `out`: the facet's -Z faces outward)
	facets(U, Data["moss_drape_" .. variant], Vector3.one * scale, CFrame.lookAt(edge, edge + out), "Moss")
end
Jungle.mossFacet = mossFacet

-- Agent A's vine strand hanging from `top` on a face (`out` = the outward normal), uniform scale 0.6-1.2 (6.35 long at
-- 1.0); a group of 2-3 strands of different lengths spread along the face
local function vineFacets(U: any, top: Vector3, out: Vector3, along: Vector3, scales: { number })
	for i, sc in ipairs(scales) do
		local p = top + along * ((i - (#scales + 1) / 2) * 0.55)
		facets(U, Data.vine_strand, Vector3.one * sc, CFrame.lookAt(p, p + out), "Moss")
	end
end
Jungle.vineFacets = vineFacets
Jungle.vine = vine

---------------------------------------------------------------------
-- 03 RUINED STONE BUILDING (kit MapAssets.Jungle.Ruin_Wall_A, 10 parts; Jungle_3 Decor.Ruins x4)
---------------------------------------------------------------------
M.SHAPES.jungle_ruin_building = { -- the 5 colliding parts
	shape("Block", 20, 10, 3.6, CFrame.new(0, 5, 0)), -- Wall
	shape("Block", 20.8, 1.6, 4.4, CFrame.new(0, 0.8, 0)), -- Base
	shape("Block", 20.6, 1.4, 4.2, CFrame.new(0, 10.7, 0)), -- Cap
	shape("Block", 4, 1.8, 3.6, CFrame.new(-6, 12.3, 0)), -- Merlon
	shape("Block", 4, 1.8, 3.6, CFrame.new(3, 12.3, 0)), -- Merlon
}

-- The ruined stone building (guide C): today's wall (20 x 10 x 3.6) as cut stone blocks in courses with staggered
-- joints, tone steps and cracks on both faces and the ends; a wider base of 2 steps (a footing and today's plinth,
-- jointed slabs); today's cap as a capped parapet of jointed capstones with chipped corners and today's 2 merlons;
-- today's 3 front plaques at their places as 2 dark window slots in stone frames with a lintel and a carved glyph
-- plaque; today's moss (top and front) as soft layered patches draping over the edges; 4 hanging vines.
-- Parts: Stone, Trim, Moss, Collision x5.
function Jungle.jungle_ruin_building(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_ruin_building"
	local rng = Random.new(20261230)
	H.setBevelSelf(true)
	local U = { Stone = {}, Trim = {}, Moss = {} }
	-- the core (the joint colour) and the 2 faces of cut blocks; the 3 front plaques keep their place
	table.insert(U.Stone, piece("Part", Vector3.new(19.8, 8.6, 3.3), CFrame.new(0, 5.9, 0), STONE_DARK))
	local slots = { { -5, 6, 3, 1.6 }, { 4, 3.6, 3.4, 1.6 }, { 6.5, 7.8, 2.6, 1.6 } }
	local function inSlot(x: number, y: number): boolean
		for _, s in ipairs(slots) do
			if math.abs(x - s[1]) < s[3] / 2 + 0.5 and math.abs(y - s[2]) < s[4] / 2 + 0.5 then
				return true
			end
		end
		return false
	end
	stoneFace(U.Stone, rng, -10, 10, 1.6, 10, -1.65, true, 1.4, STONE, inSlot, 3)
	stoneFace(U.Stone, rng, -10, 10, 1.6, 10, 1.65, false, 1.4, STONE, nil, 2)
	for _, sx in ipairs({ -1, 1 }) do
		for row = 0, 5 do
			local y = 1.6 + (row + 0.5) * 1.4
			local split = if row % 2 == 0 then 0.3 else -0.4
			for _, e in ipairs({ { -1.8, split }, { split, 1.8 } }) do
				table.insert(U.Stone, chamfered(Vector3.new(0.24, 1.31, e[2] - e[1] - 0.09), CFrame.new(sx * 9.92, y, (e[1] + e[2]) / 2), H.scaled(STONE, H.TONES[H.toneIndex(rng, nil)]), { "vertical" }, 0.08))
			end
		end
	end
	-- the stone patches round the slots (blocks left out by the courses)
	for _, s in ipairs(slots) do
		table.insert(U.Stone, chamfered(Vector3.new(s[3] + 1.0, s[4] + 1.0, 0.22), CFrame.new(s[1], s[2], -1.76), H.scaled(STONE, 0.96), { "frontFace" }, 0.06))
	end
	-- 2 dark window slots in stone frames with a lintel; the light plaque as a carved glyph panel (today's places)
	for i, s in ipairs(slots) do
		local cf = CFrame.new(s[1], s[2], -1.9)
		if i < 3 then
			table.insert(U.Trim, piece("Part", Vector3.new(s[3], s[4], 0.3), cf * CFrame.new(0, 0, 0.02), RECESS))
			for _, e in ipairs({ { 0, s[4] / 2 + 0.15, s[3] + 0.6, 0.3 }, { 0, -s[4] / 2 - 0.15, s[3] + 0.6, 0.3 }, { -s[3] / 2 - 0.15, 0, 0.3, s[4] }, { s[3] / 2 + 0.15, 0, 0.3, s[4] } }) do
				table.insert(U.Trim, chamfered(Vector3.new(e[3], e[4], 0.3), cf * CFrame.new(e[1], e[2], -0.08), STONE_DARK, { "frontFace" }, 0.06))
			end
			table.insert(U.Trim, chamfered(Vector3.new(s[3] + 1.0, 0.45, 0.45), cf * CFrame.new(0, s[4] / 2 + 0.5, -0.12), H.scaled(STONE_DARK, 1.06), { "frontFace", "vertical" }, 0.08))
			table.insert(U.Trim, piece("Part", Vector3.new(s[3] + 0.5, 0.18, 0.4), cf * CFrame.new(0, -s[4] / 2 - 0.36, -0.1), H.scaled(STONE_DARK, 0.92)))
		else
			table.insert(U.Trim, chamfered(Vector3.new(s[3], s[4], 0.3), cf, STONE_MID, { "frontFace" }, 0.1))
			for _, g in ipairs({ { -0.8, 0, 0.12, 0.9 }, { -0.4, 0.3, 0.5, 0.12 }, { 0.2, -0.1, 0.4, 0.4 }, { 0.8, 0, 0.12, 0.9 } }) do
				table.insert(U.Trim, piece("Part", Vector3.new(g[3], g[4], 0.06), cf * CFrame.new(g[1], g[2], -0.15), rgb(70, 76, 68)))
			end
		end
	end
	-- the wider base: a footing (21.2 x 0.6 x 4.6) and today's plinth (20.8 x 1.6 x 4.4) as jointed slabs
	table.insert(U.Trim, chamfered(Vector3.new(21.2, 0.6, 4.6), CFrame.new(0, 0.3, 0), H.scaled(STONE_DARK, 0.9), { "vertical", "topFrontBack", "topSides" }, 0.12))
	local bx = -10.4
	for _, len in ipairs({ 4.6, 5.4, 5.0, 5.8 }) do
		table.insert(U.Trim, chamfered(Vector3.new(len - 0.08, 1.0, 4.4), CFrame.new(bx + len / 2, 1.1, 0), H.scaled(STONE_DARK, H.TONES[H.toneIndex(rng, nil)]), { "vertical", "topFrontBack", "topSides" }, 0.12))
		bx += len
	end
	-- the capped parapet: today's cap (20.6 x 1.4 x 4.2) as 5 capstones with chipped corners, a drip course under it
	local cx = -10.3
	for i, len in ipairs({ 4.0, 4.4, 3.8, 4.2, 4.2 }) do
		local negs = {}
		if i == 1 then
			table.insert(negs, piece("Part", Vector3.new(0.8, 0.8, 0.8), CFrame.new(-10.3, 11.4, -2.1) * CFrame.Angles(0, rad(45), 0), STONE_DARK))
		elseif i == 5 then
			table.insert(negs, piece("Part", Vector3.new(0.7, 0.7, 0.7), CFrame.new(10.3, 11.4, 2.1) * CFrame.Angles(0, rad(45), 0), STONE_DARK))
		elseif i == 3 then
			table.insert(negs, piece("Part", Vector3.new(0.6, 0.6, 0.6), CFrame.new(cx + len / 2, 11.4, -2.1) * CFrame.Angles(rad(45), 0, 0), STONE_DARK))
		end
		table.insert(U.Trim, chamfered(Vector3.new(len - 0.08, 1.1, 4.2), CFrame.new(cx + len / 2, 10.85, 0), H.scaled(STONE_DARK, H.TONES[H.toneIndex(rng, nil)]), { "vertical", "topFrontBack", "topSides" }, 0.15, negs))
		cx += len
	end
	table.insert(U.Trim, piece("Part", Vector3.new(20.3, 0.3, 3.9), CFrame.new(0, 10.15, 0), H.scaled(STONE_DARK, 0.85)))
	-- today's 2 merlons (4 x 1.8 x 3.6 at x -6 and 3), chamfered, one chipped
	for i, x in ipairs({ -6, 3 }) do
		local negs = if i == 2 then { piece("Part", Vector3.new(0.9, 0.9, 0.9), CFrame.new(x + 2, 13.2, -1.8) * CFrame.Angles(0, rad(45), 0), STONE) } else {}
		table.insert(U.Stone, chamfered(Vector3.new(4, 1.8, 3.6), CFrame.new(x, 12.3, 0), H.scaled(STONE, 1.03), { "vertical", "topFrontBack", "topSides" }, 0.15, negs))
		table.insert(U.Stone, piece("Part", Vector3.new(4.04, 0.06, 3.64), CFrame.new(x, 12.3, 0), STONE_DARK))
	end
	-- today's 2 flat moss slabs as drape patches (guide C2): the top slab (7 x 4.4 at x -4.5) as a layered patch on the
	-- cap and the merlon with 2 drapes down the front and 1 down the back; the front slab (5 x 4 at (6.5, 9.4)) as 2
	-- drapes over the cap edge reaching today's patch bottom; a patch in the foot corner
	-- (low mounds lying on the cap, running together; Agent A's drape patches over the front / back edges)
	mossPatch(U.Moss, rng, CFrame.new(-4.5, 11.4, 0), 6.0, 3.0)
	mossPatch(U.Moss, rng, CFrame.new(-6.3, 13.2, 0.2), 2.6, 2.2)
	local FRONT, BACK = Vector3.new(0, 0, -1), Vector3.new(0, 0, 1)
	-- (4 drapes: each costs about 2,500 triangles; the anchors sit 0.06 inside the edge so the depth stays within +10 %)
	mossFacet(U, "C", Vector3.new(-6.4, 11.4, -2.04), FRONT, 1.25)
	mossFacet(U, "A", Vector3.new(-4.8, 11.4, 2.04), BACK, 1.2)
	mossFacet(U, "C", Vector3.new(6.2, 11.4, -2.04), FRONT, 1.2)
	mossFacet(U, "B", Vector3.new(-8.6, 1.6, -2.14), FRONT, 0.8)
	-- 2 groups of hanging vines from the parapet edge (part strands: cheaper than the facet strand)
	vineGroup(U.Moss, rng, Vector3.new(-8.8, 11.3, -2.12), FRONT, Vector3.xAxis, { 4.2, 2.8, 5.6 })
	vineGroup(U.Moss, rng, Vector3.new(1.6, 11.3, -2.12), FRONT, Vector3.xAxis, { 3.2, 5.0 })
	finish(m, "jungle_ruin_building", U, "Stone")
	return m
end

---------------------------------------------------------------------
-- 04 STONE WALL, SIX SLOTS (kit MapAssets.Jungle.ArrowTrap_Wall, 15 parts; Jungle_3 Ruins x4, Jungle_4 Props x4)
---------------------------------------------------------------------
M.SHAPES.six_slot_wall = { -- the 3 colliding parts
	shape("Block", 12, 10, 2.6, CFrame.new(0, 5, 0.2)), -- Wall
	shape("Block", 12.6, 1.2, 3.2, CFrame.new(0, 10, 0.2)), -- Frame
	shape("Block", 12.6, 1.2, 3.2, CFrame.new(0, 0.6, 0.2)), -- Frame
}
-- today's 6 holes, 2 arrows (one with its tip) and the lamp glyph, kept exactly: { name, size, CFrame, colour, neon }
local SLOT_PARTS = {}
for _, x in ipairs({ -3, 0, 3 }) do
	for _, y in ipairs({ 3.8, 6.6 }) do
		table.insert(SLOT_PARTS, { "Hole", Vector3.new(1.2, 1.2, 0.3), CFrame.new(x, y, -1.45), rgb(41, 45, 41), false })
	end
end
table.insert(SLOT_PARTS, { "Arrow", Vector3.new(0.25, 0.25, 3.2), CFrame.new(-3, 3.8, -2.6) * CFrame.fromOrientation(rad(4), 0, 0), rgb(214, 150, 92), false })
table.insert(SLOT_PARTS, { "ArrowTip", Vector3.new(0.5, 0.5, 0.7), CFrame.new(-3, 3.67, -4.4) * CFrame.fromOrientation(rad(4), 0, rad(45)), rgb(92, 98, 110), false })
table.insert(SLOT_PARTS, { "Arrow", Vector3.new(0.25, 0.25, 2.6), CFrame.new(3, 6.6, -2.3) * CFrame.fromOrientation(rad(-3), 0, 0), rgb(214, 150, 92), false })
table.insert(SLOT_PARTS, { "Glyph", Vector3.new(1.6, 0.6, 0.3), CFrame.new(0, 8.9, -1.25), rgb(120, 255, 190), true })
Jungle.SLOT_PARTS = SLOT_PARTS

-- The six-slot wall (guide C2): today's wall (12 x 10 x 2.6) as cut stone blocks; today's 2 frames as a jointed
-- capstone course (chamfered, a drip course) and a jointed plinth; today's dark panel (kept in place) in a carved stone
-- frame 0.6 wide, 0.2 proud; each of today's 6 holes in a bevelled frame (4 strips 0.25 wide with 45-degree corners);
-- today's 6 holes, 2 arrows (+ tip) and the Neon lamp glyph kept as separate parts, exactly (same names, sizes,
-- places, turns, colours); the 2 arrows get a fletching (linen / red); the lamp sits in a stone bracket (a base with a
-- chamfered underside, a hood, 2 stone bars in front) with a PointLight #78FFBE range 10; today's top moss as low mounds
-- on the capstones with Agent A's moss drapes; a group of vines. Parts: Stone, Trim, Moss, Hole x6, Arrow x2, ArrowTip, Glyph
-- (+ PointLight), Collision x3.
function Jungle.six_slot_wall(): Model
	local m = Instance.new("Model")
	m.Name = "six_slot_wall"
	local rng = Random.new(20261231)
	H.setBevelSelf(true)
	local U = { Stone = {}, Trim = {}, Moss = {} }
	-- the wall core and its 3 faces of cut blocks (the panel + frame area left out on the front)
	table.insert(U.Stone, piece("Part", Vector3.new(11.8, 8.2, 2.3), CFrame.new(0, 5.3, 0.2), STONE_DARK))
	local function inPanel(x: number, y: number): boolean
		return math.abs(x) < 5.6 and y > 1.4 and y < 9.0
	end
	stoneFace(U.Stone, rng, -6, 6, 1.2, 9.4, -1.0, true, 1.37, STONE, inPanel, 1)
	stoneFace(U.Stone, rng, -6, 6, 1.2, 9.4, 1.4, false, 1.37, STONE, nil, 2)
	for _, sx in ipairs({ -1, 1 }) do
		for row = 0, 5 do
			local y = 1.2 + (row + 0.5) * 1.367
			local split = if row % 2 == 0 then 0.4 else -0.3
			for _, e in ipairs({ { -1.1, split }, { split, 1.5 } }) do
				table.insert(U.Stone, chamfered(Vector3.new(0.24, 1.28, e[2] - e[1] - 0.09), CFrame.new(sx * 5.92, y, (e[1] + e[2]) / 2), H.scaled(STONE, H.TONES[H.toneIndex(rng, nil)]), { "vertical" }, 0.08))
			end
		end
	end
	-- the stone round the panel frame (the strip between the frame and the wall edge)
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Stone, chamfered(Vector3.new(0.38, 7.6, 0.24), CFrame.new(sx * 5.79, 5.2, -1.12), H.scaled(STONE, 0.97), { "frontFace" }, 0.08))
	end
	-- today's frames: the top (9.4 .. 10.6) as 4 capstones with a drip course, the bottom (0 .. 1.2) as a jointed plinth
	local x = -6.3
	for i, len in ipairs({ 3.0, 3.4, 3.0, 3.2 }) do
		local negs = if i == 4 then { piece("Part", Vector3.new(0.7, 0.7, 0.7), CFrame.new(6.3, 10.6, -1.4) * CFrame.Angles(0, rad(45), 0), STONE_DARK) } else {}
		table.insert(U.Trim, chamfered(Vector3.new(len - 0.08, 1.0, 3.2), CFrame.new(x + len / 2, 10.1, 0.2), H.scaled(STONE_DARK, H.TONES[H.toneIndex(rng, nil)]), { "vertical", "topFrontBack", "topSides" }, 0.15, negs))
		table.insert(U.Trim, chamfered(Vector3.new(len - 0.08, 1.2, 3.2), CFrame.new(x + len / 2, 0.6, 0.2), H.scaled(STONE_DARK, 0.92 * H.TONES[H.toneIndex(rng, nil)]), { "vertical", "topFrontBack", "topSides" }, 0.15))
		x += len
	end
	table.insert(U.Trim, piece("Part", Vector3.new(12.3, 0.25, 2.9), CFrame.new(0, 9.5, 0.2), H.scaled(STONE_DARK, 0.85)))
	-- today's panel (9.4 x 6.2 x 0.4 at (0, 5.2, -1.2)) and its carved stone frame 0.6 wide, 0.2 proud (the top bar
	-- opens round the lamp bracket)
	table.insert(U.Trim, piece("Part", Vector3.new(9.4, 6.2, 0.4), CFrame.new(0, 5.2, -1.2), STONE_DARK))
	for _, e in ipairs({ { 0, 1.8, 10.6, 0.6 }, { -5.0, 5.2, 0.6, 6.2 }, { 5.0, 5.2, 0.6, 6.2 }, { -3.15, 8.6, 4.3, 0.6 }, { 3.15, 8.6, 4.3, 0.6 } }) do
		table.insert(U.Trim, chamfered(Vector3.new(e[3], e[4], 0.6), CFrame.new(e[1], e[2], -1.3), H.scaled(STONE_DARK, 1.08), { "frontFace" }, 0.12))
	end
	-- a bevelled frame round each hole (4 strips 0.25 wide, mitred corners as 45-degree caps)
	for _, xh in ipairs({ -3, 0, 3 }) do
		for _, yh in ipairs({ 3.8, 6.6 }) do
			local cf = CFrame.new(xh, yh, -1.525)
			for _, e in ipairs({ { 0, 0.725, 1.45, 0.25 }, { 0, -0.725, 1.45, 0.25 }, { -0.725, 0, 0.25, 1.2 }, { 0.725, 0, 0.25, 1.2 } }) do
				table.insert(U.Trim, chamfered(Vector3.new(e[3], e[4], 0.25), cf * CFrame.new(e[1], e[2], 0), STONE_MID, { "frontFace" }, 0.08))
			end
		end
	end
	-- the arrows' fletchings (2 small quads each, linen / red): the tipped arrow points out of its hole (fletching at the
	-- hole mouth), the plain one has its fletching at its outer end
	local fletch = {
		{ CFrame.new(-3, 3.8, -2.6) * CFrame.fromOrientation(rad(4), 0, 0) * CFrame.new(0, 0, 1.15) },
		{ CFrame.new(3, 6.6, -2.3) * CFrame.fromOrientation(rad(-3), 0, 0) * CFrame.new(0, 0, -1.05) },
	}
	for i, f in ipairs(fletch) do
		local base = f[1]
		table.insert(U.Trim, piece("Part", Vector3.new(0.05, 0.4, 0.55), base * CFrame.new(0, 0.18, 0), if i == 1 then rgb(232, 226, 208) else rgb(196, 70, 50)))
		table.insert(U.Trim, piece("Part", Vector3.new(0.4, 0.05, 0.55), base * CFrame.new(0.18, 0, 0), if i == 1 then rgb(196, 70, 50) else rgb(232, 226, 208)))
		table.insert(U.Trim, piece("Part", Vector3.new(0.3, 0.3, 0.08), base * CFrame.new(0, 0, 0.35), rgb(196, 160, 104)))
	end
	-- the lamp's stone bracket round today's glyph (0, 8.9, -1.25): a base with a chamfered underside, a hood, 2 bars
	table.insert(U.Trim, chamfered(Vector3.new(2.2, 0.4, 1.0), CFrame.new(0, 8.4, -1.6), STONE_DARK, { "bottomFrontBack", "bottomSides" }, 0.18))
	table.insert(U.Trim, chamfered(Vector3.new(2.2, 0.3, 1.0), CFrame.new(0, 9.35, -1.6), STONE_DARK, { "topFrontBack", "topSides" }, 0.1))
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Trim, chamfered(Vector3.new(0.22, 0.9, 0.22), CFrame.new(sx * 0.42, 8.9, -1.95), STONE_MID, { "vertical" }, 0.05))
		table.insert(U.Trim, chamfered(Vector3.new(0.3, 1.25, 1.0), CFrame.new(sx * 0.95, 8.9, -1.6), STONE_DARK, { "vertical" }, 0.06))
	end
	-- today's top moss (5 x 0.5 x 3.4 at x -3) as low mounds on the capstones with Agent A's drapes over the front and
	-- back edges; a group of vines
	mossPatch(U.Moss, rng, CFrame.new(-3.0, 10.6, 0.2), 4.4, 2.6)
	mossFacet(U, "A", Vector3.new(-3.6, 10.6, -1.36), Vector3.new(0, 0, -1), 1.05)
	mossFacet(U, "C", Vector3.new(-3.0, 10.6, 1.76), Vector3.new(0, 0, 1), 0.9)
	mossFacet(U, "B", Vector3.new(4.6, 1.2, -1.36), Vector3.new(0, 0, -1), 0.7)
	vineGroup(U.Moss, rng, Vector3.new(4.3, 10.0, -1.42), Vector3.new(0, 0, -1), Vector3.xAxis, { 3.4, 5.2 })
	finish(m, "six_slot_wall", U, "Stone")
	-- today's holes, arrows and lamp glyph, exactly (not colliding, as today)
	for _, e in ipairs(SLOT_PARTS) do
		local p = piece("Part", e[2], e[3], e[4], if e[5] then { material = Enum.Material.Neon } else nil)
		p.Name = e[1]
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = m
		if e[1] == "Glyph" then
			p.CastShadow = false
			local light = Instance.new("PointLight")
			light.Color = e[4]
			light.Range = 10
			light.Brightness = 0.8
			light.Shadows = false
			light.Parent = p
		end
	end
	return m
end

---------------------------------------------------------------------
-- 01 STONE FACE TEMPLE = THE JUNGLE_4 GATE (kit MapAssets.Gates.Gate_Jungle_4, 52 parts; Zones.Jungle.Jungle_4.Gate)
---------------------------------------------------------------------
M.SHAPES.face_temple_gate = { -- today's colliding parts, except the Barrier and the PriceSign (they stay themselves)
	shape("Block", 56, 22, 11, CFrame.new(0, 29, 1.5)), -- Face
	shape("Block", 58, 3.4, 12.6, CFrame.new(0, 41.6, 1.5)), -- Forehead
	shape("Block", 30, 5.4, 10, CFrame.new(0, 46, 2)), -- Crown
	shape("Block", 14, 4, 9, CFrame.new(0, 50.7, 2)), -- CrownTop
	shape("Block", 28, 5, 13, CFrame.new(0, 18.5, 0.5)), -- UpperLip
	shape("WedgePart", 8, 10, 5, CFrame.new(0, 26.5, -6.5)), -- Nose
}
for _, sx in ipairs({ -1, 1 }) do
	for _, e in ipairs({
		shape("Block", 16, 18, 12, CFrame.new(sx * 20, 9, 1)), -- Cheek
		shape("Block", 17, 2, 13, CFrame.new(sx * 20, 1, 1)), -- CheekBase
		shape("Block", 9, 6, 10, CFrame.new(sx * 22.5, 45, 2)), -- CrownSide
		shape("Block", 5, 15, 8, CFrame.new(sx * 30.4, 27, 2)), -- Ear
		shape("Block", 3.6, 3.6, 3.6, CFrame.new(sx * 30.4, 17.4, 0)), -- Earring
		shape("Block", 13.5, 2.6, 3.4, CFrame.new(sx * 13, 35.8, -5) * CFrame.Angles(0, 0, rad(sx * 9))), -- Brow
	}) do
		table.insert(M.SHAPES.face_temple_gate, e)
	end
end

-- The stone face temple (guide C2; the Jungle_4 gate): today's face (56 x 22) and cheeks of large cut stone blocks with
-- joints and cracks, the forehead as a cornice of 6 jointed stones with a drip moulding, a stone-block crown (today's
-- Crown, CrownSides and CrownTop as capped blocks) with today's gold gem in a gold rim; Agent A's heavy temple brows and
-- carved nose; a bevelled stone rim round today's eye sockets (today's Neon glyph eyes and dark pupils kept); the upper
-- lip with rounded rolls; jointed cheek plinths; carved spiral rings on today's ears, today's gold earrings chamfered;
-- today's 2 fangs as tapered points; low moss mounds, Agent A's moss drapes and vine strands in place of today's 4 moss
-- slabs and 4 vine sticks.
-- THE MOUTH IS THE GATE (kept exactly): the Barrier (24 x 16 x 3 at (0, 8, 0), PrimaryPart, colliding, attribute
-- BarrierDecorIsChildOfBarrier) and only its children (they vanish when the gate opens): today's MouthDark and Neon
-- Glyph, the 2 Lips as rounded rolls, today's 11 Teeth chamfered, of slightly different lengths. Today's PriceSign (its
-- GUIs move onto it at the sync) in a carved frame; SubZoneId stays on the game copy (an instance attribute).
-- Parts: Carving, Glow, Gold, Moss, Stone, Barrier (+ Lip x2, Tooth x11, MouthDark, Glyph), PriceSign, Socket x2,
-- GlyphEye x2, Pupil x2, Collision x18.
function Jungle.face_temple_gate(): Model
	local m = Instance.new("Model")
	m.Name = "face_temple_gate"
	local rng = Random.new(20261232)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Carving = {}, Gold = {}, Moss = {}, Glow = {} }
	local GOLD = D.PALETTE.Gold
	local TEETH = rgb(232, 226, 208)
	-- the face: a dark core, the front and back faces of large cut blocks (today's sockets and nose cover the front)
	table.insert(U.Stone, piece("Part", Vector3.new(55.6, 21.8, 10.4), CFrame.new(0, 29, 1.5), STONE_DARK))
	stoneFace(U.Stone, rng, -28, 28, 18, 40, -4, true, 2.75, STONE, nil, 4, 2)
	stoneFace(U.Stone, rng, -28, 28, 18, 40, 7, false, 2.75, STONE, nil, 3, 2)
	-- the eye sockets: a bevelled stone rim 1.0 wide, 0.7 proud, round today's dark sockets (kept below)
	for _, sx in ipairs({ -1, 1 }) do
		local cf = CFrame.new(sx * 13, 31, -4.3)
		for _, e in ipairs({ { 0, 3.5, 12, 1.0 }, { 0, -3.5, 12, 1.0 }, { -5.5, 0, 1.0, 6 }, { 5.5, 0, 1.0, 6 } }) do
			table.insert(U.Carving, chamfered(Vector3.new(e[3], e[4], 1.4), cf * CFrame.new(e[1], e[2], -0.45), H.scaled(STONE_DARK, 1.05), { "frontFace" }, 0.35))
		end
	end
	-- the forehead (58 x 3.4 x 12.6 at y 41.6) as a cornice of 6 jointed stones, a drip moulding under its front
	local x = -29
	for _, len in ipairs({ 9.0, 10.4, 9.6, 9.6, 10.4, 9.0 }) do
		table.insert(U.Stone, chamfered(Vector3.new(len - 0.18, 3.4, 12.6), CFrame.new(x + len / 2, 41.6, 1.5), H.scaled(STONE_DARK, H.TONES[H.toneIndex(rng, nil)]), { "vertical", "topFrontBack", "topSides", "bottomFrontBack" }, 0.4))
		x += len
	end
	table.insert(U.Carving, piece("Part", Vector3.new(57, 0.6, 0.8), CFrame.new(0, 39.8, -4.3), H.scaled(STONE_DARK, 0.85)))
	-- the stone-block crown: today's Crown (30 x 5.4 x 10) as 3 capped blocks, the 2 CrownSides and the CrownTop capped
	x = -15
	for _, len in ipairs({ 9.6, 10.8, 9.6 }) do
		table.insert(U.Stone, chamfered(Vector3.new(len - 0.18, 5.4, 10), CFrame.new(x + len / 2, 46, 2), H.scaled(STONE, H.TONES[H.toneIndex(rng, nil)]), { "vertical", "topFrontBack", "topSides" }, 0.4))
		x += len
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Stone, chamfered(Vector3.new(9, 5.2, 10), CFrame.new(sx * 22.5, 44.6, 2), H.scaled(STONE, 0.96), { "vertical" }, 0.45))
		table.insert(U.Carving, chamfered(Vector3.new(9.4, 0.8, 10.4), CFrame.new(sx * 22.5, 47.6, 2), H.scaled(STONE_DARK, 1.04), { "vertical", "topFrontBack", "topSides" }, 0.25))
	end
	table.insert(U.Stone, chamfered(Vector3.new(14, 3.3, 9), CFrame.new(0, 50.35, 2), STONE_DARK, { "vertical" }, 0.45))
	table.insert(U.Carving, chamfered(Vector3.new(14.6, 0.7, 9.6), CFrame.new(0, 52.35, 2), H.scaled(STONE_DARK, 1.08), { "vertical", "topFrontBack", "topSides" }, 0.2))
	-- today's gold gem (5 x 5 x 1 turned 45 at (0, 45.2, -3.2)) in a gold rim 0.3 wide
	table.insert(U.Gold, piece("Part", Vector3.new(5, 5, 1), CFrame.new(0, 45.2, -3.2) * CFrame.Angles(0, 0, rad(45)), GOLD))
	for _, e in ipairs({ { 0, 2.65, 5.6, 0.3 }, { 0, -2.65, 5.6, 0.3 }, { -2.65, 0, 0.3, 5.0 }, { 2.65, 0, 0.3, 5.0 } }) do
		table.insert(U.Gold, piece("Part", Vector3.new(e[3], e[4], 0.5), CFrame.new(0, 45.2, -3.1) * CFrame.Angles(0, 0, rad(45)) * CFrame.new(e[1], e[2], 0), H.scaled(GOLD, 0.85)))
	end
	-- Agent A's temple brows and carved nose (over today's Brow and Nose places)
	facets(U, Data.temple_brow, Vector3.one, CFrame.identity, "Carving")
	facets(U, Data.temple_nose, Vector3.one, CFrame.identity, "Carving")
	-- the upper lip (28 x 5 x 13 at y 18.5): a chamfered block, a rounded roll each side of the PriceSign
	table.insert(U.Stone, chamfered(Vector3.new(28, 5, 13), CFrame.new(0, 18.5, 0.5), STONE_DARK, { "vertical", "topFrontBack", "bottomFrontBack" }, 0.5))
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Carving, piece("Part", Vector3.new(5.0, 1.6, 1.6), CFrame.new(sx * 9.5, 16.9, -5.6), H.scaled(STONE_DARK, 1.06), { shape = Enum.PartType.Cylinder }))
	end
	-- the cheeks: today's blocks (16 x 18 x 12) of cut stone on the front, a jointed plinth (today's CheekBase)
	for _, sx in ipairs({ -1, 1 }) do
		local cx = sx * 20
		table.insert(U.Stone, chamfered(Vector3.new(15.8, 15.8, 11.8), CFrame.new(cx, 10, 1), STONE_DARK, { "vertical", "topFrontBack", "topSides" }, 0.5))
		stoneFace(U.Stone, rng, cx - 8, cx + 8, 2, 18, -5, true, 2.3, STONE, nil, 2, 1.6)
		for k, len in ipairs({ 8.4, 8.6 }) do
			local px = cx - 8.5 + (if k == 1 then 4.2 else 8.4 + 4.3)
			table.insert(U.Stone, chamfered(Vector3.new(len - 0.15, 2, 13), CFrame.new(px, 1, 1), H.scaled(STONE_DARK, H.TONES[H.toneIndex(rng, nil)]), { "vertical", "topFrontBack", "topSides" }, 0.3))
		end
		-- today's ear (5 x 15 x 8) with a carved spiral ring on its outer face; today's gold earring, chamfered
		local ex = sx * 30.4
		table.insert(U.Stone, chamfered(Vector3.new(5, 15, 8), CFrame.new(ex, 27, 2), STONE_DARK, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.5))
		local ring = CFrame.new(ex + sx * 2.5, 28.5, 2) * CFrame.Angles(0, 0, rad(90))
		M.around(12, 0, 2.6, 0, function(cf: CFrame)
			table.insert(U.Carving, piece("Part", Vector3.new(1.45, 0.5, 0.5), ring * cf, H.scaled(STONE_DARK, 1.12)))
		end)
		M.around(8, 0, 1.3, 0.2, function(cf: CFrame)
			table.insert(U.Carving, piece("Part", Vector3.new(1.0, 0.4, 0.4), ring * cf, H.scaled(STONE_DARK, 1.12)))
		end)
		table.insert(U.Gold, chamfered(Vector3.new(3.6, 3.6, 3.6), CFrame.new(ex, 17.4, 0), GOLD, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.6))
		-- today's fang (2.2 x 5 at (13.2, 13.2, -5.4)) as a tapered point
		table.insert(U.Carving, M.frustumN(6, 0.12, 1.1, 10.7, 15.7, CFrame.new(sx * 13.2, 0, -5.4), { TEETH, H.scaled(TEETH, 0.92) }))
	end
	-- moss and vines where today's green is (today's 4 moss slabs: the forehead at x -24 .. -6, the crown top at x 4 ..
	-- 14, the 2 cheek fronts 8 x 6 at the jaw corners; today's 4 vine sticks), at about today's size: low mounds (0.6 ..
	-- 1.2 tall) lying on the forehead ledge, a CrownSide, the crown, the CrownTop, the 2 brows and the 2 cheek ledges;
	-- Agent A's drapes (2 .. 7 wide) hanging off those edges down the face; Agent A's vine strands from the forehead
	local FRONT = Vector3.new(0, 0, -1)
	mossPatch(U.Moss, rng, CFrame.new(-15, 43.3, -3.9), 18, 1.7, 2)
	mossPatch(U.Moss, rng, CFrame.new(-22.5, 48, 2), 8, 8, 2)
	mossPatch(U.Moss, rng, CFrame.new(9.5, 48.7, 1.4), 9, 8, 2)
	mossPatch(U.Moss, rng, CFrame.new(-3.5, 52.7, 2), 6, 6, 1.5)
	mossPatch(U.Moss, rng, CFrame.new(-14, 37.3, -4.3) * CFrame.Angles(0, 0, rad(-9)), 7, 1.3, 1.5)
	mossPatch(U.Moss, rng, CFrame.new(14.5, 37.25, -4.3) * CFrame.Angles(0, 0, rad(9)), 4.5, 1.3, 1.5)
	mossFacet(U, "C", Vector3.new(-20, 43.3, -4.74), FRONT, 2.6)
	mossFacet(U, "A", Vector3.new(-11, 43.3, -4.74), FRONT, 2.2)
	mossFacet(U, "C", Vector3.new(9.5, 48.7, -2.94), FRONT, 2.4)
	mossFacet(U, "B", Vector3.new(-22.5, 48, -2.94), FRONT, 2.0)
	for _, sx in ipairs({ -1, 1 }) do
		mossPatch(U.Moss, rng, CFrame.new(sx * 21.5, 18, -4.75), 10, 1.0, 1.5)
		mossFacet(U, if sx < 0 then "C" else "A", Vector3.new(sx * 23.6, 18, -5.24), FRONT, if sx < 0 then 3.0 else 2.8)
		mossFacet(U, if sx < 0 then "A" else "C", Vector3.new(sx * 19.0, 18, -5.24), FRONT, if sx < 0 then 2.6 else 2.4)
		mossFacet(U, if sx < 0 then "B" else "C", Vector3.new(sx * (if sx < 0 then 20.5 else 22.5), 15.2, -5.24), FRONT, 2.6)
		vineFacets(U, Vector3.new(sx * 5.6, 39.9, -4.5), FRONT, Vector3.xAxis, { 1.3, 0.9 })
		vineFacets(U, Vector3.new(sx * 26.5, 39.9, -4.5), FRONT, Vector3.xAxis, { 2.0, 1.5, 1.1 })
	end
	-- a carved stone frame round today's PriceSign (12 x 4)
	for _, e in ipairs({ { 0, 2.35, 13.4, 0.7 }, { 0, -2.35, 13.4, 0.7 }, { -6.35, 0, 0.7, 4.0 }, { 6.35, 0, 0.7, 4.0 } }) do
		table.insert(U.Carving, chamfered(Vector3.new(e[3], e[4], 0.8), CFrame.new(e[1], 18.5 + e[2], -6.2), H.scaled(STONE_DARK, 1.1), { "frontFace" }, 0.2))
	end
	if #U.Glow == 0 then
		U.Glow = nil
	end
	finish(m, "face_temple_gate", U, "Stone", { Glow = M.GLOW })
	-- today's sockets, Neon glyph eyes and pupils, exactly (not colliding)
	local function exact(name: string, size: Vector3, cf: CFrame, color: Color3, neon: boolean, parent: Instance, collide: boolean?): BasePart
		local p = piece("Part", size, cf, color, if neon then { material = Enum.Material.Neon } else nil)
		p.Name = name
		p.Anchored = true
		p.CanCollide = collide == true
		p.CanQuery = collide == true
		p.CanTouch = collide == true
		if neon then
			p.CastShadow = false
		end
		p.Parent = parent
		return p
	end
	for _, sx in ipairs({ -1, 1 }) do
		exact("Socket", Vector3.new(10, 6, 1), CFrame.new(sx * 13, 31, -4.3), RECESS, false, m)
		exact("GlyphEye", Vector3.new(7.4, 3.4, 0.6), CFrame.new(sx * 13, 31, -4.8), rgb(120, 255, 190), true, m)
		exact("Pupil", Vector3.new(1.8, 3.4, 0.7), CFrame.new(sx * 13, 31.05, -4.9), RECESS, false, m)
	end
	-- today's PriceSign, exactly (colliding as today; its SurfaceGuis move onto it at the sync)
	exact("PriceSign", Vector3.new(12, 4, 0.5), CFrame.new(0, 18.5, -6.25), STONE, false, m, true)
	-- THE GATE: today's Barrier (PrimaryPart, colliding) and its children (they vanish when the gate opens)
	local barrier = exact("Barrier", Vector3.new(24, 16, 3), CFrame.new(0, 8, 0), STONE_DARK, false, m, true)
	barrier:SetAttribute("BarrierDecorIsChildOfBarrier", true)
	exact("MouthDark", Vector3.new(24.1, 5, 0.5), CFrame.new(0, 8, -1.6), RECESS, false, barrier)
	exact("Glyph", Vector3.new(3.4, 1.2, 0.3), CFrame.new(0, 8, -1.95), rgb(120, 255, 190), true, barrier)
	for _, y in ipairs({ 15.65, 0.4 }) do
		exact("Lip", Vector3.new(24.1, 1.2, 1.2), CFrame.new(0, y, -1.8), STONE, false, barrier).Shape = Enum.PartType.Cylinder
	end
	local teeth = { { -8, 3.1 }, { -4, 3.1 }, { 0, 3.1 }, { 4, 3.1 }, { 8, 3.1 }, { -10, 12.9 }, { -6, 12.9 }, { -2, 12.9 }, { 2, 12.9 }, { 6, 12.9 }, { 10, 12.9 } }
	for i, t in ipairs(teeth) do
		local lower = t[2] < 8
		local len = 5.2 + ((i * 7) % 5 - 2) * 0.15
		local cy = if lower then t[2] - 2.6 + len / 2 else t[2] + 2.6 - len / 2
		local tooth = chamfered(Vector3.new(3.0, len, 0.9), CFrame.new(t[1], cy, -1.9), H.scaled(TEETH, 0.97 + 0.03 * (i % 3)), if lower then { "topFrontBack", "topSides" } else { "bottomFrontBack", "bottomSides" }, 0.5)
		tooth.Name = "Tooth"
		tooth.Anchored = true
		tooth.CanCollide = false
		tooth.CanQuery = false
		tooth.CanTouch = false
		tooth.Parent = barrier
	end
	-- the Barrier is the PrimaryPart (GateController and SyncMapProps use it), the model pivot at the origin
	m.PrimaryPart = barrier
	barrier.PivotOffset = barrier.CFrame:Inverse()
	return m
end

---------------------------------------------------------------------
-- 02 STONE HEAD (kit MapAssets.Jungle.Carved_Face_Block, 21 parts; Jungle_3 Ruins x5, Jungle_4 Props x4 + BossGate x2)
---------------------------------------------------------------------
M.SHAPES.stone_head = { -- today's colliding parts
	shape("Block", 10, 12, 5, CFrame.new(0, 6, 0.5)), -- Head
	shape("Block", 9, 1.4, 1, CFrame.new(0, 8.9, -2.3)), -- Brow
	shape("Block", 1.4, 4, 3, CFrame.new(-5.6, 7, 0.5)), -- Ear
	shape("Block", 1.4, 4, 3, CFrame.new(5.6, 7, 0.5)), -- Ear
	shape("Block", 11, 2, 5.6, CFrame.new(0, 12.9, 0.5)), -- Headdress
	shape("Block", 4.4, 1.8, 5, CFrame.new(0, 14.7, 0.5)), -- Crest
}

-- The stone head (guide C2): today's head (10 x 12 x 5) of cut stone blocks (front, back and sides, joints, a crack);
-- Agent A's heavy brow and carved nose with lips; a bevelled stone rim round today's eye sockets; today's ears with a
-- carved spiral ring and today's gold earrings (chamfered); today's headdress as a chamfered band with a carved row of
-- diamonds, today's crest stepped, today's gold gem in a gold rim; low moss mounds on the headdress, Agent A's moss
-- drapes over its front edge and on the cheek (today's 2 moss slabs), a short vine pair.
-- Kept exactly as separate parts (not colliding, as today): today's 2 sockets, 2 Neon glyph eyes, the mouth and its 4
-- teeth. No part is called "Interact" (BossService looks that name up inside BossGate).
-- Parts: Carving, Gold, Moss, Stone, Socket x2, GlyphEye x2, Mouth, Tooth x4, Collision x6.
function Jungle.stone_head(): Model
	local m = Instance.new("Model")
	m.Name = "stone_head"
	local rng = Random.new(20261233)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Carving = {}, Gold = {}, Moss = {} }
	local GOLD = D.PALETTE.Gold
	-- the head: a dark core, cut stone blocks on the front and the back, 2 courses of side blocks under the ears
	table.insert(U.Stone, chamfered(Vector3.new(9.8, 11.9, 4.8), CFrame.new(0, 5.95, 0.5), STONE_DARK, { "vertical" }, 0.3))
	stoneFace(U.Stone, rng, -5, 5, 0, 11.9, -2, true, 1.98, STONE, nil, 1, 1.25)
	stoneFace(U.Stone, rng, -5, 5, 0, 11.9, 3, false, 1.98, STONE, nil, 1, 1.25)
	for _, sx in ipairs({ -1, 1 }) do
		for row = 0, 5 do
			local y = (row + 0.5) * 1.983
			local split = if row % 2 == 0 then 0.9 else 0.1
			for _, e in ipairs({ { -2, split }, { split, 3 } }) do
				table.insert(U.Stone, chamfered(Vector3.new(0.24, 1.9, e[2] - e[1] - 0.1), CFrame.new(sx * 4.92, y, (e[1] + e[2]) / 2), H.scaled(STONE, H.TONES[H.toneIndex(rng, nil)]), { "vertical" }, 0.1))
			end
		end
	end
	-- Agent A's brow (over today's Brow) and nose with lips (over today's Nose, round today's mouth)
	facets(U, Data.face_brow, Vector3.one, CFrame.identity, "Carving")
	facets(U, Data.face_nose_lips, Vector3.one, CFrame.identity, "Carving")
	-- a bevelled stone rim 0.3 wide round each of today's sockets (2.8 x 2)
	for _, sx in ipairs({ -1, 1 }) do
		local cf = CFrame.new(sx * 2.3, 7.3, -2.2)
		for _, e in ipairs({ { 0, -1.15, 3.4, 0.3 }, { -1.55, 0, 0.3, 2.0 }, { 1.55, 0, 0.3, 2.0 } }) do
			table.insert(U.Carving, chamfered(Vector3.new(e[3], e[4], 0.4), cf * CFrame.new(e[1], e[2], 0), H.scaled(STONE_DARK, 1.05), { "frontFace" }, 0.1))
		end
	end
	-- today's ears (1.4 x 4 x 3) chamfered, a carved spiral ring on the outer face; today's gold earrings, chamfered
	for _, sx in ipairs({ -1, 1 }) do
		local ex = sx * 5.6
		table.insert(U.Stone, chamfered(Vector3.new(1.4, 4, 3), CFrame.new(ex, 7, 0.5), STONE_DARK, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.25))
		local ring = CFrame.new(ex + sx * 0.7, 7.4, 0.5) * CFrame.Angles(0, 0, rad(90))
		M.around(8, 0, 0.85, 0, function(cf: CFrame)
			table.insert(U.Carving, piece("Part", Vector3.new(0.7, 0.2, 0.2), ring * cf, H.scaled(STONE_DARK, 1.12)))
		end)
		table.insert(U.Carving, piece("Part", Vector3.new(0.45, 0.15, 0.45), ring, H.scaled(STONE_DARK, 0.8)))
		table.insert(U.Gold, chamfered(Vector3.new(1.2, 1.2, 1.2), CFrame.new(ex, 4.4, 0.2), GOLD, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.22))
	end
	-- today's headdress (11 x 2 x 5.6): a chamfered band, a carved row of diamonds on its front; today's crest stepped;
	-- today's gold gem (1.3, turned 45) in a gold rim
	table.insert(U.Stone, chamfered(Vector3.new(11, 2, 5.6), CFrame.new(0, 12.9, 0.5), STONE_DARK, { "vertical", "topFrontBack", "topSides", "bottomFrontBack" }, 0.3))
	for i = -4, 4 do
		if math.abs(i) > 1 then
			table.insert(U.Carving, piece("Part", Vector3.new(0.6, 0.6, 0.2), CFrame.new(i * 1.15, 12.9, -2.25) * CFrame.Angles(0, 0, rad(45)), H.scaled(STONE_DARK, if i % 2 == 0 then 1.15 else 0.8)))
		end
	end
	for _, y in ipairs({ 12.05, 13.75 }) do
		table.insert(U.Carving, piece("Part", Vector3.new(10.6, 0.18, 0.2), CFrame.new(0, y, -2.25), H.scaled(STONE_DARK, 1.12)))
	end
	table.insert(U.Stone, chamfered(Vector3.new(4.4, 1.1, 5), CFrame.new(0, 14.35, 0.5), STONE, { "vertical", "topFrontBack", "topSides" }, 0.2))
	table.insert(U.Stone, chamfered(Vector3.new(3.2, 0.7, 4.0), CFrame.new(0, 15.25, 0.5), STONE, { "vertical", "topFrontBack", "topSides" }, 0.2))
	table.insert(U.Gold, piece("Part", Vector3.new(1.3, 1.3, 0.5), CFrame.new(0, 12.9, -2.45) * CFrame.Angles(0, 0, rad(45)), GOLD))
	for _, e in ipairs({ { 0, 0.75, 1.6, 0.2 }, { 0, -0.75, 1.6, 0.2 }, { -0.75, 0, 0.2, 1.3 }, { 0.75, 0, 0.2, 1.3 } }) do
		table.insert(U.Gold, piece("Part", Vector3.new(e[3], e[4], 0.3), CFrame.new(0, 12.9, -2.4) * CFrame.Angles(0, 0, rad(45)) * CFrame.new(e[1], e[2], 0), H.scaled(GOLD, 0.85)))
	end
	-- moss where today's green is (the top slab at x -3.2, the cheek slab 3 x 3.6 at x 3.4) and on the brow top: low
	-- mounds on the headdress and the brow, Agent A's drapes over the headdress front edge and down the right cheek
	-- (about today's patch size); 2 short vines from the headdress
	local FRONT = Vector3.new(0, 0, -1)
	mossPatch(U.Moss, rng, CFrame.new(-3.7, 13.9, 0.6), 3.4, 4.8)
	mossPatch(U.Moss, rng, CFrame.new(-2.4, 9.62, -2.35), 3.0, 0.8)
	mossFacet(U, "A", Vector3.new(-3.6, 13.9, -2.24), FRONT, 1.4)
	mossFacet(U, "C", Vector3.new(3.55, 4.6, -2.26), FRONT, 1.4)
	vineGroup(U.Moss, rng, Vector3.new(-4.7, 11.95, -2.36), FRONT, Vector3.xAxis, { 2.2, 3.4 })
	finish(m, "stone_head", U, "Stone")
	-- today's sockets, glyph eyes, mouth and teeth, exactly (not colliding)
	local function exact(name: string, size: Vector3, cf: CFrame, color: Color3, neon: boolean)
		local p = piece("Part", size, cf, color, if neon then { material = Enum.Material.Neon } else nil)
		p.Name = name
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		if neon then
			p.CastShadow = false
		end
		p.Parent = m
	end
	for _, sx in ipairs({ -1, 1 }) do
		exact("Socket", Vector3.new(2.8, 2, 0.5), CFrame.new(sx * 2.3, 7.3, -2.05), RECESS, false)
		exact("GlyphEye", Vector3.new(1.8, 1.1, 0.4), CFrame.new(sx * 2.3, 7.3, -2.25), rgb(120, 255, 190), true)
	end
	exact("Mouth", Vector3.new(5.6, 1.4, 0.5), CFrame.new(0, 2.5, -2.05), RECESS, false)
	for _, x in ipairs({ -1.8, -0.6, 0.6, 1.8 }) do
		exact("Tooth", Vector3.new(0.8, 0.8, 0.4), CFrame.new(x, 2.8, -2.3), rgb(232, 226, 208), false)
	end
	return m
end

---------------------------------------------------------------------
-- 05 STILT HUT (kit MapAssets.Jungle.TribalHut_A, 14 parts; Jungle_2 Props x3, BossArenas x1)
---------------------------------------------------------------------
local LADDER_CF = CFrame.new(0, 2.7, -8.6) * CFrame.Angles(rad(-28), 0, 0)
M.SHAPES.stilt_hut = { -- today's colliding parts (all but the Door and the DoorMask)
	shape("Block", 14, 0.8, 14, CFrame.new(0, 5, 0)), -- Platform
	shape("Block", 11, 7, 11, CFrame.new(0, 8.9, 0)), -- Body
	shape("Block", 11.4, 0.6, 11.4, CFrame.new(0, 6, 0)), -- Band
	shape("Block", 11.4, 0.6, 11.4, CFrame.new(0, 12.1, 0)), -- Band
	shape("WedgePart", 15.5, 7, 7.75, CFrame.new(0, 15.9, -3.875)), -- Roof (front)
	shape("WedgePart", 15.5, 7, 7.75, CFrame.new(0, 15.9, 3.875) * CFrame.Angles(0, math.pi, 0)), -- Roof (back)
	shape("Block", 16, 0.8, 1.2, CFrame.new(0, 19.5, 0)), -- Ridge
	shape("Block", 3, 7.4, 0.5, LADDER_CF), -- Ladder
}
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		table.insert(M.SHAPES.stilt_hut, shape("Block", 1.1, 5, 1.1, CFrame.new(sx * 5.6, 2.5, sz * 5.6))) -- Stilt
	end
end

-- The stilt hut (guide C2): today's 4 stilts as 8-sided logs with rope ties and cross braces; today's platform as a
-- plank deck on 2 rim beams with a low railing (open at the door); today's body as framed plank walls (corner posts,
-- vertical planks) with today's 2 bands as lashed beams; today's door and red mask kept exactly, in a wooden frame with a
-- rolled hide over it; Agent A's thatch over today's 2 roof wedges (kept as the core), today's ridge as a lashed beam;
-- today's ladder as 2 rails with rungs; 2 gourds on the deck, a hanging lantern (warm light) and a few vines.
-- Parts: Deck, Roof, Walls, Wood, Glow, Door, DoorMask, Collision x12.
function Jungle.stilt_hut(): Model
	local m = Instance.new("Model")
	m.Name = "stilt_hut"
	local rng = Random.new(20261234)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Deck = {}, Walls = {}, Roof = {}, Glow = {} }
	local DARK = rgb(112, 62, 38) -- #703E26
	local PLANK = rgb(168, 98, 56) -- #A86238
	local WALL = rgb(214, 150, 92) -- #D6965C
	local THATCH = rgb(196, 160, 104) -- #C4A068
	local ROPE = rgb(176, 144, 93)
	local function tone(c: Color3): Color3
		return H.scaled(c, H.TONES[H.toneIndex(rng, nil)])
	end
	-- the stilts: 8-sided logs (today's 1.1 x 5) with a rope tie under the deck; cross braces on 3 sides
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Wood, M.frustumN(8, 0.55, 0.5, 0, 4.62, CFrame.new(sx * 5.6, 0, sz * 5.6), { tone(DARK), H.scaled(DARK, 0.9) }))
			table.insert(U.Wood, M.frustumN(8, 0.6, 0.6, 3.7, 4.1, CFrame.new(sx * 5.6, 0, sz * 5.6), { ROPE, H.scaled(ROPE, 0.88) }))
		end
	end
	for _, e in ipairs({
		{ Vector3.new(-5.6, 0.6, -5.3), Vector3.new(-5.6, 4.3, 5.3) },
		{ Vector3.new(5.6, 0.6, 5.3), Vector3.new(5.6, 4.3, -5.3) },
		{ Vector3.new(-5.3, 0.6, 5.6), Vector3.new(5.3, 4.3, 5.6) },
		{ Vector3.new(-5.3, 1.6, -5.6), Vector3.new(5.3, 1.6, -5.6) },
	}) do
		table.insert(U.Wood, H.bar(e[1], e[2], 0.32, H.scaled(DARK, 1.08)))
	end
	-- the platform (14 x 0.8 x 14, y 4.6 .. 5.4): 2 rim beams and a dark bed under 14 planks running along X
	table.insert(U.Deck, piece("Part", Vector3.new(13.6, 0.5, 13.6), CFrame.new(0, 4.85, 0), H.scaled(DARK, 0.9)))
	for _, sz in ipairs({ -1, 1 }) do
		table.insert(U.Deck, chamfered(Vector3.new(14, 0.55, 0.5), CFrame.new(0, 4.88, sz * 6.75), DARK, { "vertical" }, 0.1))
	end
	for i = 0, 13 do
		local z = -7 + (i + 0.5)
		table.insert(U.Deck, piece("Part", Vector3.new(14 - rng:NextNumber(0, 0.3), 0.3, 0.92), CFrame.new(rng:NextNumber(-0.12, 0.12), 5.25, z), tone(PLANK)))
	end
	-- a low railing round the deck edge (open in front of the door): posts and a rail
	local function post(x: number, z: number)
		table.insert(U.Wood, piece("Part", Vector3.new(0.3, 1.8, 0.3), CFrame.new(x, 6.3, z), tone(DARK)))
	end
	local R = 6.75
	for _, sx in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -R, 0, R }) do
			post(sx * R, z)
		end
		table.insert(U.Wood, H.bar(Vector3.new(sx * R, 7.1, -R), Vector3.new(sx * R, 7.1, R), 0.22, H.scaled(DARK, 1.1)))
		post(sx * 2.2, -R)
		table.insert(U.Wood, H.bar(Vector3.new(sx * R, 7.1, -R), Vector3.new(sx * 2.2, 7.1, -R), 0.22, H.scaled(DARK, 1.1)))
	end
	post(0, R)
	table.insert(U.Wood, H.bar(Vector3.new(-R, 7.1, R), Vector3.new(R, 7.1, R), 0.22, H.scaled(DARK, 1.1)))
	-- the body (11 x 7 x 11, y 5.4 .. 12.4): a core, vertical planks on the 4 walls (none behind the door), corner posts
	table.insert(U.Walls, piece("Part", Vector3.new(10.7, 7, 10.7), CFrame.new(0, 8.9, 0), H.scaled(WALL, 0.8)))
	for side = 0, 3 do
		local frame = CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, 0, -5.42)
		for i = 0, 10 do
			local x = -5 + i
			if not (side == 0 and math.abs(x) < 2.3) then
				local h = 7 - rng:NextNumber(0, 0.25)
				table.insert(U.Walls, piece("Part", Vector3.new(0.9, h, 0.16), frame * CFrame.new(x, 5.4 + h / 2, 0), tone(WALL)))
			end
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Wood, chamfered(Vector3.new(0.6, 7, 0.6), CFrame.new(sx * 5.45, 8.9, sz * 5.45), tone(DARK), { "vertical" }, 0.12))
		end
	end
	-- today's 2 bands (11.4 x 0.6) as 4 lashed beams each, with rope ties at the corners
	for _, y in ipairs({ 6, 12.1 }) do
		for side = 0, 3 do
			local frame = CFrame.Angles(0, side * math.pi / 2, 0)
			table.insert(U.Wood, chamfered(Vector3.new(11.4, 0.6, 0.4), frame * CFrame.new(0, y, -5.5), tone(DARK), { "vertical", "topFrontBack", "bottomFrontBack" }, 0.1))
			table.insert(U.Wood, piece("Part", Vector3.new(0.75, 0.75, 0.75), frame * CFrame.new(-5.5, y, -5.5), ROPE))
		end
	end
	-- today's door (kept below) in a wooden frame, a rolled hide over it, 2 fold strips
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Wood, chamfered(Vector3.new(0.4, 5.8, 0.35), CFrame.new(sx * 2.2, 8.3, -5.65), DARK, { "frontFace" }, 0.08))
	end
	table.insert(U.Wood, chamfered(Vector3.new(4.8, 0.4, 0.35), CFrame.new(0, 11.2, -5.62), DARK, { "frontFace" }, 0.08))
	table.insert(U.Wood, piece("Part", Vector3.new(4.2, 0.55, 0.55), CFrame.new(0, 10.82, -5.95), rgb(138, 90, 58), { shape = Enum.PartType.Cylinder }))
	for _, x in ipairs({ -0.9, 0.8 }) do
		table.insert(U.Wood, piece("Part", Vector3.new(0.22, 4.9, 0.08), CFrame.new(x, 8.1, -5.84), rgb(62, 40, 28)))
	end
	-- the roof: today's 2 wedges kept as the core, Agent A's thatch over them, today's ridge as a lashed beam
	table.insert(U.Roof, piece("WedgePart", Vector3.new(15.4, 6.95, 7.7), CFrame.new(0, 15.9, -3.875), H.scaled(THATCH, 0.78)))
	table.insert(U.Roof, piece("WedgePart", Vector3.new(15.4, 6.95, 7.7), CFrame.new(0, 15.9, 3.875) * CFrame.Angles(0, math.pi, 0), H.scaled(THATCH, 0.78)))
	facets(U, Data.thatch_roof, Vector3.one, CFrame.identity, "Roof")
	table.insert(U.Wood, chamfered(Vector3.new(16, 0.8, 1.2), CFrame.new(0, 19.5, 0), DARK, { "vertical", "topFrontBack", "topSides" }, 0.15))
	for _, x in ipairs({ -6.5, 0, 6.5 }) do
		table.insert(U.Wood, piece("Part", Vector3.new(0.5, 0.95, 1.35), CFrame.new(x, 19.5, 0), ROPE))
	end
	-- today's ladder (3 x 7.4, leaning 28 degrees): 2 rails and 6 rungs
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Wood, chamfered(Vector3.new(0.32, 7.4, 0.4), LADDER_CF * CFrame.new(sx * 1.34, 0, 0), tone(PLANK), { "vertical" }, 0.08))
	end
	for k = 0, 5 do
		table.insert(U.Wood, piece("Part", Vector3.new(2.7, 0.24, 0.24), LADDER_CF * CFrame.new(0, -3.0 + k * 1.15, 0), H.scaled(PLANK, 0.9), { shape = Enum.PartType.Cylinder }))
	end
	-- 2 gourds on the deck (front right), a lantern hanging from the front eave (warm glow), vines from the deck edge
	for i, g in ipairs({ { 4.9, -6.0, 0.55, rgb(196, 154, 80) }, { 5.6, -5.3, 0.42, rgb(168, 122, 60) } }) do
		local cf = CFrame.new(g[1], 5.4 + g[3] * 0.9, g[2])
		table.insert(U.Deck, piece("Part", Vector3.one * g[3] * 2, cf, g[4], { shape = Enum.PartType.Ball }))
		table.insert(U.Deck, piece("Part", Vector3.one * g[3] * 1.3, cf * CFrame.new(0, g[3] * 1.15, 0), H.scaled(g[4], 0.95), { shape = Enum.PartType.Ball }))
		table.insert(U.Deck, piece("Part", Vector3.new(0.12, 0.35, 0.12), cf * CFrame.new(0, g[3] * 1.9, 0) * CFrame.Angles(0, 0, rad(i * 12)), rgb(92, 70, 40)))
	end
	local lx, lz = -4.2, -6.3
	table.insert(U.Wood, piece("Part", Vector3.new(0.06, 1.1, 0.06), CFrame.new(lx, 11.75, lz), rgb(62, 40, 28)))
	table.insert(U.Wood, chamfered(Vector3.new(0.75, 0.18, 0.75), CFrame.new(lx, 11.15, lz), DARK, { "vertical" }, 0.12))
	table.insert(U.Wood, chamfered(Vector3.new(0.75, 0.18, 0.75), CFrame.new(lx, 10.17, lz), DARK, { "vertical" }, 0.12))
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Wood, piece("Part", Vector3.new(0.08, 0.82, 0.08), CFrame.new(lx + sx * 0.3, 10.66, lz + sz * 0.3), DARK))
		end
	end
	table.insert(U.Glow, piece("Part", Vector3.new(0.45, 0.7, 0.45), CFrame.new(lx, 10.66, lz), rgb(255, 184, 74)))
	vineGroup(U.Wood, rng, Vector3.new(-5.8, 4.65, -7.05), Vector3.new(0, 0, -1), Vector3.xAxis, { 2.0, 3.0 })
	finish(m, "stilt_hut", U, "Walls", { Glow = M.GLOW })
	local glow = m:FindFirstChild("Glow")
	if glow then
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 184, 74)
		light.Range = 8
		light.Brightness = 0.6
		light.Shadows = false
		light.Parent = glow
	end
	-- today's door and door mask, exactly (not colliding, touchable as today)
	for _, e in ipairs({
		{ "Door", Vector3.new(4, 5.6, 0.4), CFrame.new(0, 8.2, -5.6), rgb(74, 48, 34) },
		{ "DoorMask", Vector3.new(1.6, 1.6, 0.4), CFrame.new(0, 11.2, -5.7) * CFrame.Angles(0, 0, rad(45)), rgb(196, 70, 50) },
	}) do
		local p = piece("Part", e[2], e[3], e[4])
		p.Name = e[1]
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = true
		p.Parent = m
	end
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into PropsDesert's fresh PropsBatch2 table; its install() builds them
---------------------------------------------------------------------
Jungle.BUILDERS = { jungle_ruin_building = true, six_slot_wall = true, face_temple_gate = true, stone_head = true, stilt_hut = true }
for id in pairs(Jungle.BUILDERS) do
	B2[id] = (Jungle :: any)[id]
	B2.BUILDERS[id] = true
end
Jungle.install = B2.install
Jungle.stats = B2.stats
Jungle.SHAPES = M.SHAPES

return Jungle
