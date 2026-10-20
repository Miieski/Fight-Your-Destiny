--[[
	PropsJungleGates (dev tool, Edit mode only) - the owner's "JUNGLE ZONE PROP IMPROVEMENT - Gates and entrances"
	(2026-10-20, jungle PROMPT_02): the palisade gate with its 2 totem guards (the Jungle_2 gate), the stone vine
	barricade (the Jungle_3 gate), the totem arch (Jungle_1's entry arch), the root arch and the rock cave rebuilt in the
	jungle recipe (docs/prop_texture_guide.md sections A, B, C), keeping each object's colours, place, size, function
	and collision. Source of truth: tools/PropsJungleGates.luau. Inventory: docs/prop_inventory.md "Jungle gates".

	Collision: the visible unions never collide; invisible "Collision" parts are the kit's colliding parts (same shape,
	size and place), so no copy is more (or less) solid than today. The gates' Barrier (and its children), PriceSign,
	NameSign and the palisade's 2 totem guards stay today's exact parts.

	It uses DevTools.PropsJungleBuildings (its helpers, palette and facet data, and through it the desert monuments
	helpers, finish() and the SHAPES table) and registers its builders into the same PropsBatch2 table:
		local G = require(game.ServerStorage.DevTools.PropsJungleGates:Clone())
		print(G.install("root_arch"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.run({ only = { "root_arch" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local J = require(ServerStorage.DevTools.PropsJungleBuildings:Clone()) :: any
local M, B2, H, D = J.M, J.B2, J.H, J.D
local piece, chamfered = H.piece, H.chamfered
local finish = M.finish
local P = J.PALETTE
local GData = require(ServerStorage.DevTools.PropsJungleGatesData:Clone()) :: any -- Agent A's gate facet pieces
local MOSS = P.MOSS

local Gates = {}

local rgb = Color3.fromRGB
local rad = math.rad

-- jungle accents (guide C): flower pink, mushroom red / tan, bright leaf greens
local PINK, YELLOW, WHITE = rgb(232, 74, 156), rgb(255, 201, 60), rgb(240, 236, 224)
local LEAF = { rgb(126, 217, 87), rgb(63, 168, 74), rgb(93, 187, 70) } -- #7ED957, #3FA84A, #5DBB46

---------------------------------------------------------------------
-- shared organic helpers
---------------------------------------------------------------------
-- a Catmull-Rom curve through the control points, `per` samples per span (the last point included)
local function spline(ctrl: { Vector3 }, per: number): { Vector3 }
	local out = {}
	for i = 1, #ctrl - 1 do
		local p0, p1, p2, p3 = ctrl[math.max(i - 1, 1)], ctrl[i], ctrl[i + 1], ctrl[math.min(i + 2, #ctrl)]
		for k = 0, per - 1 do
			local t = k / per
			local t2, t3 = t * t, t * t * t
			table.insert(out, 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3))
		end
	end
	table.insert(out, ctrl[#ctrl])
	return out
end
Gates.spline = spline

-- a frame at p with its Y axis along u
local function axisFrame(p: Vector3, u: Vector3): CFrame
	local helper = if math.abs(u.Z) < 0.9 then Vector3.zAxis else Vector3.xAxis
	local x = helper:Cross(u).Unit
	return CFrame.fromMatrix(p, x, u)
end

-- a tapering n-sided log along the polyline pts (radius rs[i] at pts[i]); the faces take `colors` in turn, which reads
-- as bark lines along the wood; the segments overlap a little so the bends stay closed
local function strand(list: { BasePart }, pts: { Vector3 }, rs: { number }, n: number, colors: { Color3 })
	for i = 1, #pts - 1 do
		local p, q = pts[i], pts[i + 1]
		local d = q - p
		local len = d.Magnitude
		if len > 0.05 then
			local ov = math.min(rs[i], rs[i + 1]) * 0.35
			table.insert(list, M.frustumN(n, rs[i], rs[i + 1], -ov, len + ov, axisFrame(p, d.Unit), colors))
		end
	end
end
Gates.strand = strand

-- a small knot (n = 6 bump) or a broken stub with a light cut end, at `at` pointing along `dir`
local function knot(list: { BasePart }, at: Vector3, dir: Vector3, r: number, len: number, color: Color3, cutEnd: Color3?)
	local cf = axisFrame(at, dir.Unit)
	table.insert(list, M.frustumN(6, r, if cutEnd then r * 0.8 else r * 0.3, -r * 0.5, len, cf, { color, H.scaled(color, 0.85) }))
	if cutEnd then
		table.insert(list, M.frustumN(6, r * 0.72, r * 0.72, len - 0.02, len + 0.06, cf, { cutEnd }))
	end
end

-- a cluster of `n` leaves (rounded diamond plates, 3 greens) round `at`, tilted at random
local function leafCluster(list: { BasePart }, rng: Random, at: Vector3, n: number, size: number)
	for k = 1, n do
		local off = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 0.5), rng:NextNumber(-1, 1)) * size * 0.6
		local cf = CFrame.new(at + off) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0) * CFrame.Angles(rad(rng:NextNumber(-35, 35)), 0, rad(rng:NextNumber(-25, 25)))
		local s = size * rng:NextNumber(0.75, 1.15)
		table.insert(list, chamfered(Vector3.new(s * 1.5, 0.14, s * 0.8), cf, H.scaled(LEAF[(k % 3) + 1], rng:NextNumber(0.93, 1.05)), { "vertical" }, s * 0.36))
	end
end
Gates.leafCluster = leafCluster

-- a mushroom on the ground at `at` (stem h tall, cap radius r) with 3 white spots
local function mushroom(list: { BasePart }, rng: Random, at: Vector3, h: number, r: number, cap: Color3)
	table.insert(list, piece("Part", Vector3.new(h, r * 0.55, r * 0.55), CFrame.new(at + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, rad(90)), WHITE, { shape = Enum.PartType.Cylinder }))
	local cf = CFrame.new(at) * CFrame.Angles(rad(rng:NextNumber(-8, 8)), 0, rad(rng:NextNumber(-8, 8)))
	table.insert(list, M.frustumN(8, r, r * 0.35, h * 0.85, h * 0.85 + r * 0.65, cf, { cap, H.scaled(cap, 0.9) }))
	for k = 0, 2 do
		local a = k * 2.1 + rng:NextNumber(0, 0.5)
		local sp = cf * CFrame.new(math.cos(a) * r * 0.55, h * 0.85 + r * 0.42, math.sin(a) * r * 0.55) * CFrame.Angles(0, a, rad(-30))
		table.insert(list, piece("Part", Vector3.new(r * 0.3, r * 0.1, r * 0.3), sp, WHITE))
	end
end
Gates.mushroom = mushroom

-- a small flower at `at`: a green stem, 5 pink petals round a yellow heart
local function flower(list: { BasePart }, rng: Random, at: Vector3, h: number, color: Color3?)
	local f = math.max(h / 0.9, 1) -- petals grow with the stem
	table.insert(list, piece("Part", Vector3.new(0.12 * f, h, 0.12 * f), CFrame.new(at + Vector3.new(0, h / 2, 0)), LEAF[2]))
	local top = CFrame.new(at + Vector3.new(0, h, 0)) * CFrame.Angles(rad(rng:NextNumber(-15, 15)), rng:NextNumber(0, 6.3), 0)
	for k = 0, 4 do
		table.insert(list, chamfered(Vector3.new(0.5 * f, 0.08 * f, 0.32 * f), top * CFrame.Angles(0, k * 2 * math.pi / 5, 0) * CFrame.new(0.3 * f, 0, 0) * CFrame.Angles(0, 0, rad(12)), color or PINK, { "vertical" }, 0.12 * f))
	end
	table.insert(list, M.frustumN(6, 0.14 * f, 0.06 * f, -0.02, 0.14 * f, top, { YELLOW }))
end
Gates.flower = flower

-- moss lying on a curved surface: `at` on the surface, `normal` out of it, `along` the surface direction
local function mossOn(list: { BasePart }, rng: Random, at: Vector3, normal: Vector3, along: Vector3, w: number, d: number, hMul: number?)
	local x = along.Unit
	local y = normal.Unit
	J.mossPatch(list, rng, CFrame.fromMatrix(at, x, y), w, d, hMul)
end
Gates.mossOn = mossOn

---------------------------------------------------------------------
-- 04 ROOT ARCH (kit MapAssets.Jungle.Root_Arch_A, 19 parts, 45 x 26.9 x 8.6; Jungle_1 Props x2, Jungle_3 Ruins x2)
---------------------------------------------------------------------
M.SHAPES.root_arch = { -- today's colliding parts: 9 Roots, 2 RootFeet, 2 RootSmall
	{ "Block", 10.2156, 6, 5.8, { 15.75, 3, 0.2, 0.0624, -0.9981, 0, 0.9981, 0.0624, 0, 0, 0, 1 } },
	{ "Block", 8.7765, 5, 5.6, { 15.5, 10.25, -0.2, -0.1521, -0.9884, 0, 0.9884, -0.1521, 0, 0, 0, 1 } },
	{ "Block", 8.7192, 5, 4.8, { 13.25, 16.25, 0.2, -0.5369, -0.8437, 0, 0.8437, -0.5369, 0, 0, 0, 1 } },
	{ "Block", 9.1642, 5, 5.6, { 8.25, 20.25, -0.2, -0.9333, -0.359, 0, 0.359, -0.9333, 0, 0, 0, 1 } },
	{ "Block", 12.2, 4.4, 4.2, { 0, 21.5, 0.2, -1, 0, 0, 0, -1, 0, 0, 0, 1 } },
	{ "Block", 9.1642, 5, 5.6, { -8.25, 20.25, -0.2, -0.9333, 0.359, 0, -0.359, -0.9333, 0, 0, 0, 1 } },
	{ "Block", 8.7192, 5, 4.8, { -13.25, 16.25, 0.2, -0.5369, 0.8437, 0, -0.8437, -0.5369, 0, 0, 0, 1 } },
	{ "Block", 8.7765, 5, 5.6, { -15.5, 10.25, -0.2, -0.1521, 0.9884, 0, -0.9884, -0.1521, 0, 0, 0, 1 } },
	{ "Block", 10.2156, 6, 5.8, { -15.75, 3, 0.2, 0.0624, 0.9981, 0, -0.9981, 0.0624, 0, 0, 0, 1 } },
	{ "WedgePart", 3, 5, 6, { 19.5, 2.5, 0.4, 0, 0, -1, 0, 1, 0, 1, 0, 0 } },
	{ "WedgePart", 3, 5, 6, { -19.5, 2.5, -0.4, 0, 0, 1, 0, 1, 0, -1, 0, 0 } },
	{ "Block", 14, 1.8, 1.8, { 15.5, 12, -3, 0.371, -0.9182, 0.1392, 0.9272, 0.3746, 0, -0.0521, 0.129, 0.9903 } },
	{ "Block", 12, 1.6, 1.6, { -16.5, 9, 3, 0.3043, 0.9366, -0.1736, -0.9511, 0.309, 0, 0.0537, 0.1651, 0.9848 } },
}

-- The root arch (guide C3): today's arch of 9 root blocks as a twisted root: a main root along today's curve (radius
-- 3.0 at the feet -> 2.2 at the crown) with 2 thinner roots twisting round it (8- and 6-sided tapering logs whose faces
-- alternate bark tones: bark lines), knots and 3 broken stubs with light cut ends; each foot spreads into 4 tapering
-- roots that sink into the soil (today's RootFeet); today's 2 side roots (RootSmall) as thinner tapering roots; soft
-- moss mounds on the crown and both shoulders (today's 3 moss slabs) with leaf clusters and 2 of Agent A's moss drapes;
-- part vines at today's 3 vines (6 copies: the facet strands cost too much here); mushrooms (#C44632, white dots) and
-- pink flowers at both feet. Passage kept: 25.5 wide at the ground, 19.3 tall in the middle.
-- Parts: Flora, Moss, Roots, Collision x13.
function Gates.root_arch(): Model
	local m = Instance.new("Model")
	m.Name = "root_arch"
	local rng = Random.new(20261241)
	H.setBevelSelf(true)
	local U: any = { Roots = {}, Moss = {}, Flora = {} }
	local BARK_A = { rgb(79, 51, 34), rgb(62, 40, 28), rgb(94, 62, 40), rgb(62, 40, 28) }
	local BARK_B = { rgb(99, 64, 41), rgb(74, 48, 34), rgb(110, 74, 48), rgb(74, 48, 34) }
	local BARK_C = { rgb(68, 44, 31), rgb(90, 58, 38) }
	local CUT = rgb(176, 132, 86)
	-- today's curve through the 9 root blocks (feet a little into the soil)
	local ctrl = {
		Vector3.new(-16.3, -0.8, 0), Vector3.new(-15.9, 3, 0), Vector3.new(-15.5, 10.25, 0), Vector3.new(-13.25, 16.25, 0),
		Vector3.new(-8.25, 20.25, 0), Vector3.new(0, 21.55, 0), Vector3.new(8.25, 20.25, 0), Vector3.new(13.25, 16.25, 0),
		Vector3.new(15.5, 10.25, 0), Vector3.new(15.9, 3, 0), Vector3.new(16.3, -0.8, 0),
	}
	local c = spline(ctrl, 3)
	local n = #c
	local tangents, normals, arc = {}, {}, { 0 }
	for i = 1, n do
		local t = (c[math.min(i + 1, n)] - c[math.max(i - 1, 1)]).Unit
		tangents[i] = t
		local nn = Vector3.zAxis:Cross(t).Unit -- in the arch plane, pointing out of the curve
		if nn:Dot(c[i] - Vector3.new(0, 5, 0)) < 0 then
			nn = -nn
		end
		normals[i] = nn
		if i > 1 then
			arc[i] = arc[i - 1] + (c[i] - c[i - 1]).Magnitude
		end
	end
	local total = arc[n]
	-- the strands: offset round the curve (amplitude a, turns per stud w, phase), radius from the foot to the crown
	local function twisted(a: number, w: number, phase: number, rFoot: number, rTop: number, colors: { Color3 }, sides: number)
		local pts, rs = {}, {}
		for i = 1, n do
			local u = arc[i] / total
			local ang = phase + arc[i] * w
			table.insert(pts, c[i] + normals[i] * (a * math.cos(ang)) + Vector3.zAxis * (a * math.sin(ang)))
			table.insert(rs, rFoot + (rTop - rFoot) * math.sin(math.pi * u))
		end
		strand(U.Roots, pts, rs, sides, colors)
		return pts, rs
	end
	-- the main root (radius 3.0 at the feet -> 2.2 at the crown) and 2 thinner roots twisting round it
	local pa, ra = twisted(0, 0, 0, 3.0, 2.2, BARK_A, 8)
	twisted(2.75, 0.3, 0, 0.95, 0.65, BARK_B, 6)
	twisted(2.6, 0.3, math.pi, 0.85, 0.6, BARK_C, 6)
	-- knots and broken stubs on the main root
	for k = 1, 9 do
		local i = rng:NextInteger(4, n - 4)
		local pts, rs = pa, ra
		local out = (normals[i] * rng:NextNumber(-0.3, 1) + Vector3.zAxis * rng:NextNumber(-1, 1)).Unit
		local stub = k <= 3
		knot(U.Roots, pts[i] + out * (rs[i] - 0.25), out, if stub then 0.5 else rng:NextNumber(0.4, 0.6), if stub then 1.4 else 0.55, BARK_A[3], if stub then CUT else nil)
	end
	-- the feet: 4 tapering roots each, spreading out and sinking into the soil (today's RootFeet)
	for _, sx in ipairs({ -1, 1 }) do
		local base = Vector3.new(sx * 16.1, 3.2, 0)
		for k, e in ipairs({ { sx * 1, 0.15, 5.4 }, { sx * 0.75, -0.6, 4.6 }, { sx * 0.7, 0.6, 4.4 }, { -sx * 0.2, sx * 0.95, 2.6 } }) do -- (within today's depth +10 %)
			local h = Vector3.new(e[1], 0, e[2]).Unit
			local pts, rs = {}, {}
			for s = 0, 5 do
				local f = s / 5
				table.insert(pts, base + h * (1.6 + e[3] * f) + Vector3.new(0, 3.2 * (1 - f) ^ 1.6 - 3.2 - 0.3 * f, 0))
				table.insert(rs, 1.75 - 1.45 * f)
			end
			strand(U.Roots, pts, rs, 7, if k % 2 == 0 then BARK_A else BARK_B)
		end
	end
	-- today's 2 side roots (RootSmall, 14 and 12 long): thinner tapering roots, the thick end down
	for _, e in ipairs({ { CFrame.new(15.5, 12, -3) * CFrame.fromOrientation(0, rad(8), rad(68)), 14, 0.9 }, { CFrame.new(-16.5, 9, 3) * CFrame.fromOrientation(0, rad(-10), rad(-72)), 12, 0.8 } }) do
		local a, b = e[1] * Vector3.new(-e[2] / 2, 0, 0), e[1] * Vector3.new(e[2] / 2, 0, 0)
		if b.Y < a.Y then
			a, b = b, a
		end
		local q1 = a:Lerp(b, 0.33) + Vector3.new(0, 0, if e[1].Z < 0 then -0.6 else 0.6) + (a - b).Unit:Cross(Vector3.zAxis) * 0.5
		local q2 = a:Lerp(b, 0.7) + Vector3.new(0, 0, if e[1].Z < 0 then 0.2 else -0.2) - (a - b).Unit:Cross(Vector3.zAxis) * 0.4
		local pts = spline({ a, q1, q2, b }, 3)
		local rs = {}
		for i = 1, #pts do
			table.insert(rs, e[3] * (1.05 - 0.75 * (i - 1) / (#pts - 1)))
		end
		strand(U.Roots, pts, rs, 7, BARK_C)
	end
	-- moss: mounds on the crown and both shoulders (today's 3 slabs), leaf clusters, 2 drapes over the crown edges
	local function at(x: number): number
		local best = 1
		for i = 1, n do
			if math.abs(c[i].X - x) < math.abs(c[best].X - x) and c[i].Y > 8 then
				best = i
			end
		end
		return best
	end
	for _, e in ipairs({ { 0, 10, 4.6, 2 }, { -13.3, 6.5, 4.2, 1.8 }, { 13.6, 5.5, 4.2, 1.8 }, { 7.5, 5, 3.8, 1.6 }, { -7, 5, 3.8, 1.6 } }) do
		local i = at(e[1])
		mossOn(U.Moss, rng, c[i] + normals[i] * (ra[i] - 0.15), normals[i], tangents[i], e[2], e[3], e[4])
	end
	for _, x in ipairs({ -5, 2.5, 9.5, -10.5, 14.5, -1, 6 }) do
		local i = at(x)
		leafCluster(U.Moss, rng, c[i] + normals[i] * (ra[i] + 0.35), rng:NextInteger(6, 7), 1.35)
	end
	-- fuller leaf clusters on the crown top (they read from the ground), leaning over the front and back edges
	for _, e in ipairs({ { -3.5, -1.2 }, { 1, 1.1 }, { 4.5, -1.0 }, { -7.5, 0.9 } }) do
		local i = at(e[1])
		leafCluster(U.Moss, rng, c[i] + normals[i] * (ra[i] + 0.3) + Vector3.new(0, 0, e[2]), 9, 1.55)
	end
	J.mossFacet(U, "A", Vector3.new(-3, 23.3, -1.55), Vector3.new(0, 0, -1), 1.4)
	J.mossFacet(U, "C", Vector3.new(1.5, 23.3, 1.55), Vector3.new(0, 0, 1), 1.2)
	-- vines where today's 3 vines hang (from under the arch): tapering stems with leaves (part vines: 6 copies)
	J.vineGroup(U.Moss, rng, Vector3.new(5, 19.4, -1.5), Vector3.new(0, 0, -1), Vector3.xAxis, { 5.4, 3.8 })
	J.vineGroup(U.Moss, rng, Vector3.new(-3, 19.6, 1.6), Vector3.new(0, 0, 1), Vector3.xAxis, { 3.5 })
	J.vineGroup(U.Moss, rng, Vector3.new(-7.5, 18.9, -1.2), Vector3.new(0, 0, -1), Vector3.xAxis, { 4.3, 2.6 })
	-- mushrooms and flowers at both feet
	local RED = rgb(196, 70, 50) -- #C44632
	for _, sx in ipairs({ -1, 1 }) do
		mushroom(U.Flora, rng, Vector3.new(sx * 19.8, 0, -3.4), 1.3, 0.8, RED)
		mushroom(U.Flora, rng, Vector3.new(sx * 21.0, 0, -2.4), 0.9, 0.55, rgb(216, 160, 96))
		mushroom(U.Flora, rng, Vector3.new(sx * 13.4, 0, 3.8), 1.1, 0.65, RED)
		flower(U.Flora, rng, Vector3.new(sx * 18.4, 0, 3.6), 1.3)
		flower(U.Flora, rng, Vector3.new(sx * 13.2, 0, -3.4), 1.1)
		flower(U.Flora, rng, Vector3.new(sx * 20.2, 0, 2.2), 0.9, rgb(255, 170, 40))
	end
	finish(m, "root_arch", U, "Roots")
	return m
end

---------------------------------------------------------------------
-- shared gate helpers: exact parts (kept parts keep their name, size, place, colour and flags)
---------------------------------------------------------------------
-- an exact part: class, name, size, cf, colour; flags = { collide, query, touch, shadow, neon }
local function exact(parent: Instance, class: string, name: string, size: Vector3, cf: CFrame, color: Color3, flags: any): BasePart
	local p = piece(class, size, cf, color, if flags.neon then { material = Enum.Material.Neon } else nil)
	p.Name = name
	p.Anchored = true
	p.CanCollide = flags.collide == true
	p.CanQuery = flags.query == true
	p.CanTouch = flags.touch == true
	p.CastShadow = flags.shadow ~= false
	p.Parent = parent
	return p
end
Gates.exact = exact
local COLLIDE = { collide = true, query = true, touch = true }
local DECOR = { touch = true } -- today's non-colliding decoration parts: CanQuery off, CanTouch on
local EMBER = { touch = false, shadow = false, neon = true }

-- door / barricade pieces merged into unions UNDER the Barrier (they vanish with it when the gate opens)
local function underBarrier(m: Model, barrier: BasePart, name: string, list: { BasePart }, opts: any?)
	if #list == 0 then
		return
	end
	local u = H.merge(m, name, list, opts or {})
	u.CanCollide = false
	u.CanQuery = false
	u.CanTouch = true
	u.Parent = barrier
end

-- the Barrier: PrimaryPart, colliding, attribute BarrierDecorIsChildOfBarrier; the model pivot stays at the origin
local function makeBarrier(m: Model, size: Vector3, cf: CFrame, color: Color3): BasePart
	local barrier = exact(m, "Part", "Barrier", size, cf, color, COLLIDE)
	barrier:SetAttribute("BarrierDecorIsChildOfBarrier", true)
	H.setBevelSelf(true) -- (finish() turned it off: the door pieces' bevels take their own colour too)
	return barrier
end
local function setPrimary(m: Model, barrier: BasePart)
	H.setBevelSelf(false)
	m.PrimaryPart = barrier
	barrier.PivotOffset = barrier.CFrame:Inverse()
end

-- an n-sided ring (a rope turn or an iron collar) of apothem r and width w round the axis `u` at `at`
local function ring(list: { BasePart }, at: Vector3, u: Vector3, r: number, w: number, colors: { Color3 })
	table.insert(list, M.frustumN(8, r, r, -w / 2, w / 2, axisFrame(at, u), colors))
end
Gates.ring = ring

-- a flat board from a to b (in the XY plane), w wide and t thick, at depth z
local function board(list: { BasePart }, a: Vector2, b: Vector2, w: number, t: number, z: number, color: Color3)
	local d = b - a
	local mid = (a + b) / 2
	table.insert(list, piece("Part", Vector3.new(w, d.Magnitude, t), CFrame.new(mid.X, mid.Y, z) * CFrame.Angles(0, 0, math.atan2(-d.X, d.Y)), color))
end

---------------------------------------------------------------------
-- 01 PALISADE GATE WITH 2 TOTEM GUARDS = THE JUNGLE_2 GATE (kit MapAssets.Gates.Gate_Jungle_2, 70 parts;
-- Zones.Jungle.Jungle_2.Gate)
---------------------------------------------------------------------
M.SHAPES.jungle_palisade_gate = { -- today's colliding parts except the Barrier, the PriceSign and the 2 guards (kept)
	{ "Block", 32, 3, 3.4, { 0, 17.5, 0.2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Lintel
	{ "Block", 13.4, 5.2, 0.6, { 0, 21.7, -1.2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- SignBack
}
local PAL_LOGS = { -- today's 10 logs: x, height, z, colour
	{ -14.6, 20, 0.5, "#a35f36" }, { -17.75, 23, 0, "#714a30" }, { -20.9, 19, 0.5, "#a15e35" }, { -24.05, 22, 0, "#63412a" }, { -27.2, 18, 0.5, "#a66137" },
	{ 14.6, 20, 0.5, "#a46036" }, { 17.75, 23, 0, "#65422a" }, { 20.9, 19, 0.5, "#a76137" }, { 24.05, 22, 0, "#66432b" }, { 27.2, 18, 0.5, "#a96338" },
}
for _, L in ipairs(PAL_LOGS) do
	table.insert(M.SHAPES.jungle_palisade_gate, { "Block", 3, L[2], 3, { L[1], L[2] / 2, L[3], 1, 0, 0, 0, 1, 0, 0, 0, 1 } }) -- Log
	table.insert(M.SHAPES.jungle_palisade_gate, { "Block", 2.1, 2.1, 3, { L[1], L[2], L[3], 0.7071, -0.7071, 0, 0.7071, 0.7071, 0, 0, 0, 1 } }) -- LogTip
end
for _, sx in ipairs({ -1, 1 }) do
	for _, y in ipairs({ 6, 14 }) do
		table.insert(M.SHAPES.jungle_palisade_gate, { "Block", 16.6, 1.2, 0.8, { sx * 20.9, y, -1.6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }) -- Band
	end
	table.insert(M.SHAPES.jungle_palisade_gate, { "Block", 0.8, 8, 0.8, { sx * 13.4, 4, -7.4, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }) -- TorchPole
end

-- today's 2 totem guards (18 parts), copied unchanged: name, class, size, place, colour, flags
local function palisadeGuards(m: Model)
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 16.2
		exact(m, "Part", "TotemHead", Vector3.new(3.6, 3.6, 3.6), CFrame.new(x, 1.8, -4.6), rgb(196, 70, 50), COLLIDE)
		exact(m, "Part", "TotemHead", Vector3.new(3.6, 3.6, 3.6), CFrame.new(x, 5.4, -4.6), rgb(60, 170, 190), COLLIDE)
		exact(m, "Part", "TotemHead", Vector3.new(3.6, 3.6, 3.6), CFrame.new(x, 9, -4.6), rgb(214, 150, 92), COLLIDE)
		for _, ex in ipairs({ -0.9, 0.9 }) do
			exact(m, "Part", "Eye", Vector3.new(0.8, 0.8, 0.3), CFrame.new(x + ex, 2.4, -6.45), rgb(232, 226, 208), DECOR)
			exact(m, "Part", "Eye", Vector3.new(0.8, 1, 0.3), CFrame.new(x + ex, 9.5, -6.45), rgb(74, 48, 34), DECOR)
		end
		exact(m, "WedgePart", "Beak", Vector3.new(1.4, 1.6, 2), CFrame.new(x, 5.2, -7.3), rgb(255, 201, 60), DECOR)
		exact(m, "Part", "Wing", Vector3.new(8.4, 2, 0.7), CFrame.new(x, 9.2, -4.2), rgb(196, 70, 50), COLLIDE)
	end
end

-- The palisade gate (guide C3): today's 10 logs as octagonal posts (corner chamfers 0.5, today's sizes and two-tone
-- colours) with sharpened 4-facet points 2.4 tall, dark bark strips and knots; today's 4 Bands as dark rails with an
-- iron strap and 2 rivets per log, 3 rope turns round every log above each band; the lintel as an octagonal log beam
-- with light cut ends, bark strips and today's 2 rope wraps as 3 rope turns; 2 torches on today's poles (octagonal
-- pole, rope wrap, iron bowl and a 4-bar cage, today's Neon Ember and its FirePoint kept); the sign as 3 planks
-- behind today's PriceSign (kept, its GUIs move onto it) in a carved frame; Agent A's horned skull over it with 2
-- crossed bones and a hanging rope. THE DOOR (all children of today's Barrier 24 x 16 x 1.4, PrimaryPart, colliding):
-- 2 leaves of vertical planks (front and back, 3 tones, a centre split), Z-braces, 3 strap hinges per leaf, iron studs,
-- today's teal Mask (kept) in a raised rim with brows, today's gold MaskEyes and red MaskMouth (kept) with 3 teeth.
-- THE 2 TOTEM GUARDS: today's 18 parts unchanged. Parts: Bone, Iron, Logs, Rope, Wood, Barrier (+ DoorPlanks,
-- DoorIron, Mask, MaskEye x2, MaskMouth, MaskCarving), PriceSign, Ember x2 (+ FirePoint), TotemHead x6, Eye x8,
-- Beak x2, Wing x2, Collision x28.
function Gates.jungle_palisade_gate(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_palisade_gate"
	local rng = Random.new(20261242)
	H.setBevelSelf(true)
	local U: any = { Logs = {}, Wood = {}, Iron = {}, Rope = {}, Bone = {} }
	local DARK = rgb(112, 62, 38) -- #703E26
	local IRON = rgb(92, 98, 110) -- #5C626E
	local ROPE = { rgb(196, 160, 104), rgb(172, 140, 90) } -- #C4A068
	local CUT = rgb(196, 150, 100)
	-- the logs: octagonal posts with a sharpened point, bark strips and knots
	for _, L in ipairs(PAL_LOGS) do
		local x, h, z = L[1], L[2], L[3]
		local c = Color3.fromHex(L[4])
		table.insert(U.Logs, chamfered(Vector3.new(3, h, 3), CFrame.new(x, h / 2, z), c, { "vertical" }, 0.5))
		table.insert(U.Logs, M.frustumN(4, 1.5, 0.06, h - 0.02, h + 2.4, CFrame.new(x, 0, z) * CFrame.Angles(0, rad(45), 0), { H.scaled(c, 1.08), H.scaled(c, 0.92) }))
		for _, f in ipairs({ { 0, -1 }, { 0, 1 }, { 1, 0 }, { -1, 0 } }) do
			for k = 1, (if f[2] ~= 0 then 2 else 1) do
				local len = h * rng:NextNumber(0.35, 0.7)
				local y = rng:NextNumber(len / 2 + 0.3, h - len / 2 - 0.3)
				local off = (if k == 1 then -0.5 else 0.45) + rng:NextNumber(-0.15, 0.15)
				local cf = CFrame.new(x + f[1] * 1.51 + (if f[2] ~= 0 then off else 0), y, z + f[2] * 1.51 + (if f[1] ~= 0 then off else 0))
				table.insert(U.Logs, piece("Part", Vector3.new(if f[2] ~= 0 then 0.1 else 0.05, len, if f[2] ~= 0 then 0.05 else 0.1), cf, H.scaled(c, 0.72)))
			end
		end
		for _ = 1, 2 do
			local y = rng:NextNumber(1.5, h - 2)
			table.insert(U.Logs, piece("Part", Vector3.new(0.12, 0.5, 0.5), CFrame.new(x + rng:NextNumber(-0.7, 0.7), y, z - 1.52) * CFrame.Angles(0, rad(90), 0), H.scaled(c, 0.82), { shape = Enum.PartType.Cylinder }))
		end
		-- 3 rope turns above each band
		for _, by in ipairs({ 6, 14 }) do
			for t = 0, 2 do
				ring(U.Rope, Vector3.new(x, by + 0.85 + t * 0.27, z), Vector3.yAxis, 1.62, 0.24, ROPE)
			end
		end
	end
	-- today's 4 Bands: dark rails with an iron strap and 2 rivets per log
	for _, sx in ipairs({ -1, 1 }) do
		for _, by in ipairs({ 6, 14 }) do
			table.insert(U.Wood, chamfered(Vector3.new(16.6, 1.2, 0.8), CFrame.new(sx * 20.9, by, -1.6), DARK, { "vertical", "topFrontBack", "bottomFrontBack" }, 0.15))
			table.insert(U.Iron, piece("Part", Vector3.new(16.8, 0.3, 0.1), CFrame.new(sx * 20.9, by, -2.04), IRON))
			for _, L in ipairs(PAL_LOGS) do
				if L[1] * sx > 0 then
					for _, dx in ipairs({ -0.55, 0.55 }) do
						table.insert(U.Iron, piece("Part", Vector3.new(0.25, 0.25, 0.12), CFrame.new(L[1] + dx, by, -2.12), H.scaled(IRON, 0.8)))
					end
				end
			end
		end
	end
	-- the lintel (32 x 3 x 3.4): an octagonal log beam with light cut ends, bark strips, 2 rope lashings of 3 turns
	table.insert(U.Wood, chamfered(Vector3.new(32, 3, 3.4), CFrame.new(0, 17.5, 0.2), DARK, { "topFrontBack", "bottomFrontBack" }, 0.75))
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Wood, M.frustumN(8, 1.25, 1.25, -0.04, 0.04, axisFrame(Vector3.new(sx * 16.0, 17.5, 0.2), Vector3.xAxis), { CUT }))
		for t = -1, 1 do
			ring(U.Rope, Vector3.new(sx * 9.5 + t * 0.32, 17.5, 0.2), Vector3.xAxis, 1.86, 0.26, ROPE)
		end
	end
	for _, e in ipairs({ { -11, 0.4, 7 }, { 2, -0.5, 9 }, { 12, 0.3, 5 } }) do
		table.insert(U.Wood, piece("Part", Vector3.new(e[3], 0.1, 0.05), CFrame.new(e[1], 17.5 + e[2], -1.52), H.scaled(DARK, 0.7)))
	end
	-- the torches on today's poles (0.8 x 8 at (+-13.4, 4, -7.4)): octagonal pole, rope wrap, iron bowl and cage
	for _, sx in ipairs({ -1, 1 }) do
		local tx = sx * 13.4
		table.insert(U.Wood, chamfered(Vector3.new(0.8, 8, 0.8), CFrame.new(tx, 4, -7.4), DARK, { "vertical" }, 0.2))
		for t = 0, 2 do
			ring(U.Rope, Vector3.new(tx, 5.6 + t * 0.26, -7.4), Vector3.yAxis, 0.48, 0.22, ROPE)
		end
		table.insert(U.Iron, M.frustumN(8, 0.5, 0.95, 7.95, 8.75, CFrame.new(tx, 0, -7.4), { rgb(74, 78, 87), rgb(62, 66, 74) }))
		ring(U.Iron, Vector3.new(tx, 8.8, -7.4), Vector3.yAxis, 1.02, 0.12, { rgb(92, 98, 110) })
		for k = 0, 3 do
			local a = k * math.pi / 2 + math.pi / 4
			local p0 = Vector3.new(tx + math.cos(a) * 0.85, 8.8, -7.4 + math.sin(a) * 0.85)
			local p1 = Vector3.new(tx + math.cos(a) * 0.62, 9.85, -7.4 + math.sin(a) * 0.62)
			table.insert(U.Iron, H.bar(p0, p1, 0.12, rgb(74, 78, 87)))
		end
		ring(U.Iron, Vector3.new(tx, 9.85, -7.4), Vector3.yAxis, 0.66, 0.1, { rgb(74, 78, 87) })
	end
	-- the sign: 3 planks behind today's PriceSign, a carved frame round it
	for k, y in ipairs({ 19.97, 21.7, 23.43 }) do
		table.insert(U.Wood, chamfered(Vector3.new(13.4, 1.68, 0.6), CFrame.new(rng:NextNumber(-0.1, 0.1), y, -1.2), H.scaled(DARK, ({ 1.0, 1.08, 0.94 })[k]), { "frontFace" }, 0.08))
	end
	for _, e in ipairs({ { 0, 2.25, 13.0, 0.5 }, { 0, -2.25, 13.0, 0.5 }, { -6.25, 0, 0.5, 4.0 }, { 6.25, 0, 0.5, 4.0 } }) do
		table.insert(U.Wood, chamfered(Vector3.new(e[3], e[4], 0.55), CFrame.new(e[1], 21.7 + e[2], -1.78), H.scaled(DARK, 1.15), { "frontFace" }, 0.15))
	end
	-- Agent A's horned skull (on the kit pivot) over the sign, 2 crossed bones behind it, a short hanging rope
	J.facets(U, GData.skull_horned, Vector3.one, CFrame.identity, "Bone")
	local BONE = rgb(232, 226, 208)
	for _, sx in ipairs({ -1, 1 }) do
		local cf = CFrame.new(0, 25.2, -0.5) * CFrame.Angles(0, 0, rad(sx * 38))
		table.insert(U.Bone, piece("Part", Vector3.new(0.4, 5.2, 0.4), cf, H.scaled(BONE, 0.95)))
		for _, e in ipairs({ -1, 1 }) do
			table.insert(U.Bone, M.frustumN(6, 0.32, 0.32, -0.3, 0.3, cf * CFrame.new(0, e * 2.6, 0), { BONE, H.scaled(BONE, 0.9) }))
		end
	end
	table.insert(U.Rope, H.bar(Vector3.new(1.6, 24.1, -1.55), Vector3.new(1.75, 22.6, -1.6), 0.15, ROPE[1]))
	finish(m, "jungle_palisade_gate", U, "Logs")
	-- today's torch embers (Neon) with their FirePoint attachments, kept
	for _, sx in ipairs({ -1, 1 }) do
		local ember = exact(m, "Part", "Ember", Vector3.new(1.3, 0.5, 1.3), CFrame.new(sx * 13.4, 9, -7.4), rgb(255, 140, 40), EMBER)
		local fp = Instance.new("Attachment")
		fp.Name = "FirePoint"
		fp.Position = Vector3.new(0, 0.3, 0)
		fp.Parent = ember
	end
	-- today's PriceSign (colliding; its SurfaceGuis move onto it at the sync)
	exact(m, "Part", "PriceSign", Vector3.new(12, 4, 0.5), CFrame.new(0, 21.7, -1.75), rgb(168, 98, 56), COLLIDE)
	-- today's 2 totem guards, unchanged
	palisadeGuards(m)
	-- THE DOOR: today's Barrier and its children (planks, braces, hinges, the carved teal face)
	local barrier = makeBarrier(m, Vector3.new(24, 16, 1.4), CFrame.new(0, 8, 0), rgb(74, 48, 34))
	local planks, iron, carving = {}, {}, {}
	local PL = { rgb(168, 98, 56), rgb(156, 90, 51), rgb(180, 106, 62) } -- #A86238 tones
	for _, side in ipairs({ -1, 1 }) do
		local w = (11.85 - 5 * 0.08) / 6
		for k = 0, 5 do
			local x = side * (0.15 + w / 2 + k * (w + 0.08))
			local h = 15.9 - rng:NextNumber(0, 0.15)
			local col = PL[rng:NextInteger(1, 3)]
			for _, zf in ipairs({ -1, 1 }) do
				local turn = if zf > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
				table.insert(planks, chamfered(Vector3.new(w, h, 0.24), CFrame.new(x, 0.05 + h / 2, zf * 0.82) * turn, H.scaled(col, if zf > 0 then 0.92 else 1), { "frontFace" }, 0.06))
			end
		end
		-- the Z-brace: 2 battens on today's CrossBand heights (front and back) and a diagonal (front)
		for _, by in ipairs({ 3.4, 12.6 }) do
			for _, zf in ipairs({ -1, 1 }) do
				local turn = if zf > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
				table.insert(planks, chamfered(Vector3.new(11.3, 1.0, 0.24), CFrame.new(side * 6.0, by, zf * 1.06) * turn, H.scaled(DARK, 1.12), { "frontFace" }, 0.08))
			end
			for k = 0, 5 do
				local x = side * (0.15 + 0.95 + k * 1.98)
				table.insert(iron, piece("Part", Vector3.new(0.22, 0.22, 0.1), CFrame.new(x, by, -1.22), H.scaled(IRON, 0.85)))
			end
		end
		board(planks, Vector2.new(side * 10.8, 4.0), Vector2.new(side * 4.4, 12.0), 0.95, 0.24, -1.06, H.scaled(DARK, 1.12))
		-- 3 strap hinges (0.5 x 3.5 with a round end) and a hinge knuckle at the outer edge
		for _, hy in ipairs({ 1.9, 8.0, 14.1 }) do
			table.insert(iron, piece("Part", Vector3.new(3.5, 0.5, 0.08), CFrame.new(side * 10.1, hy, -0.98), IRON))
			table.insert(iron, piece("Part", Vector3.new(0.08, 0.75, 0.75), CFrame.new(side * 8.35, hy, -0.98) * CFrame.Angles(0, rad(90), 0), IRON, { shape = Enum.PartType.Cylinder }))
			table.insert(iron, piece("Part", Vector3.new(1.0, 0.45, 0.45), CFrame.new(side * 11.95, hy, -0.8) * CFrame.Angles(0, 0, rad(90)), H.scaled(IRON, 0.85), { shape = Enum.PartType.Cylinder }))
		end
	end
	-- the carved teal face: a raised rim round today's Mask, brows, 3 teeth under today's mouth
	local TEAL = rgb(60, 170, 190)
	local rimCF = CFrame.new(0, 8, -1.05) * CFrame.Angles(0, 0, rad(45))
	for _, e in ipairs({ { 0, 2.65, 5.6, 0.3 }, { 0, -2.65, 5.6, 0.3 }, { -2.65, 0, 0.3, 5.0 }, { 2.65, 0, 0.3, 5.0 } }) do
		table.insert(carving, piece("Part", Vector3.new(e[3], e[4], 0.42), rimCF * CFrame.new(e[1], e[2], 0), H.scaled(TEAL, 0.78)))
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(carving, piece("Part", Vector3.new(1.25, 0.26, 0.16), CFrame.new(sx * 1.1, 9.25, -1.24) * CFrame.Angles(0, 0, rad(sx * -14)), H.scaled(TEAL, 0.55)))
	end
	for _, tx in ipairs({ -0.65, 0, 0.65 }) do
		table.insert(carving, piece("Part", Vector3.new(0.36, 0.3, 0.1), CFrame.new(tx, 6.92, -1.39), rgb(232, 226, 208)))
	end
	underBarrier(m, barrier, "DoorPlanks", planks)
	underBarrier(m, barrier, "DoorIron", iron)
	underBarrier(m, barrier, "MaskCarving", carving)
	exact(barrier, "Part", "Mask", Vector3.new(5, 5, 0.5), CFrame.new(0, 8, -0.9) * CFrame.Angles(0, 0, rad(45)), TEAL, DECOR)
	for _, sx in ipairs({ -1, 1 }) do
		exact(barrier, "Part", "MaskEye", Vector3.new(1, 1, 0.3), CFrame.new(sx * 1.1, 8.5, -1.2), rgb(255, 201, 60), DECOR)
	end
	exact(barrier, "Part", "MaskMouth", Vector3.new(2.4, 0.6, 0.3), CFrame.new(0, 6.8, -1.2), rgb(196, 70, 50), DECOR)
	setPrimary(m, barrier)
	return m
end

---------------------------------------------------------------------
-- 02 STONE VINE BARRICADE = THE JUNGLE_3 GATE (kit MapAssets.Gates.Gate_Jungle_3, 54 parts; Zones.Jungle.Jungle_3.Gate)
---------------------------------------------------------------------
M.SHAPES.jungle_barricade_gate = { -- today's colliding parts except the Barrier and the PriceSign
	{ "Block", 26, 5.6, 7.6, { 0, 18.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Lintel
	{ "Block", 5, 6.4, 8.4, { 0, 19.2, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Keystone
	{ "Block", 24, 3, 7, { -9, 23.1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- UpperCourse
	{ "Block", 13, 2, 7, { 13, 22.6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- UpperCourse
	{ "Block", 34, 2.6, 2.6, { 3, 25.6, -1.4, 0.9948, -0.087, 0.0523, 0.0872, 0.9962, 0, -0.0521, 0.0046, 0.9986 } }, -- RootTop
	{ "Block", 13.2, 5, 0.5, { 0, 19, -4.05, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- SignBack
}
for _, sx in ipairs({ -1, 1 }) do
	for _, e in ipairs({
		{ "Block", 12, 20, 8, { sx * 18.2, 10, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Pier
		{ "Block", 13, 2, 9, { sx * 18.2, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- PierBase
		{ "Block", 13, 1.6, 9, { sx * 18.2, 20.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- PierCap
		{ "Block", 3, 25, 3, { sx * 24.6, 11.5, -3.6, 0.9848, sx * 0.1736, 0, -sx * 0.1736, 0.9848, 0, 0, 0, 1 } }, -- Root (beam)
	}) do
		table.insert(M.SHAPES.jungle_barricade_gate, e)
	end
end
-- today's barricade logs (Barrier children): width, length, x, z, turn about Z, colour
local BAR_ROOTS = {
	{ 2.3, 16.08, -10, -2.1, 14, "#513423" }, { 1.8, 16.5, -6.4, -1.6, -22, "#6c462d" }, { 2.8, 15.79, -2.5, -2.1, 9, "#64412c" },
	{ 2.3, 16.08, 1.5, -1.6, -14, "#624029" }, { 1.8, 16.5, 5.2, -2.1, 24, "#5b3b27" }, { 2.8, 15.75, 9.6, -1.6, -8, "#734b31" },
	{ 2.3, 16.5, -0.5, -2.1, 36, "#543725" },
}
local BAR_CROSS = { { 22, 2, 0, 4.2, -2.5, 6 }, { 21, 1.8, 0.5, 11.6, -2.6, -8 } } -- length, height, x, y, z, turn

-- a face of cut stone blocks on a side of a pier: the plane x = xf (outward sx), z0 .. z1, y0 .. y1
local function sideStones(list: { BasePart }, rng: Random, xf: number, sx: number, z0: number, z1: number, y0: number, y1: number, ch: number, color: Color3)
	local n = math.max(1, math.floor((y1 - y0) / ch + 0.5))
	local h = (y1 - y0) / n
	local turn = CFrame.Angles(0, rad(if sx < 0 then 90 else -90), 0)
	for row = 0, n - 1 do
		local yc = y0 + (row + 0.5) * h
		local z = z0 - (if row % 2 == 0 then 0 else rng:NextNumber(0.8, 1.6))
		while z < z1 - 0.05 do
			local len = rng:NextNumber(2.4, 4.0)
			local a, b = math.max(z, z0), math.min(z + len, z1)
			if b - a > 0.3 then
				local c = H.scaled(color, H.TONES[H.toneIndex(rng, nil)] * (0.92 + 0.1 * (yc - y0) / (y1 - y0)))
				table.insert(list, chamfered(Vector3.new(b - a - 0.1, h - 0.1, 0.24), CFrame.new(xf + sx * 0.12, yc, (a + b) / 2) * turn, c, { "frontFace" }, 0.13))
			end
			z += len
		end
	end
end
Gates.sideStones = sideStones

-- leaves lying on a wall (the face looks -Z): n rounded leaves round `at`, size s
local function wallLeaves(list: { BasePart }, rng: Random, at: Vector3, n: number, s: number)
	for k = 1, n do
		local off = Vector3.new(rng:NextNumber(-1, 1) * s * 0.7, rng:NextNumber(-1, 1) * s * 0.5, -rng:NextNumber(0, 0.15))
		local cf = CFrame.new(at + off) * CFrame.Angles(0, 0, rng:NextNumber(0, 2 * math.pi)) * CFrame.Angles(rad(90 + rng:NextNumber(-25, 25)), 0, 0)
		local z = s * rng:NextNumber(0.8, 1.15)
		table.insert(list, chamfered(Vector3.new(z * 1.5, 0.12, z * 0.8), cf, H.scaled(LEAF[(k % 3) + 1], rng:NextNumber(0.93, 1.05)), { "vertical" }, z * 0.36))
	end
end
Gates.wallLeaves = wallLeaves

-- a flower lying on a wall (the face looks -Z): 5 rounded petals round a gold heart
local function wallFlower(list: { BasePart }, at: Vector3, r: number, color: Color3)
	for k = 0, 4 do
		local cf = CFrame.new(at) * CFrame.Angles(0, 0, k * 2 * math.pi / 5) * CFrame.new(r * 0.55, 0, 0)
		table.insert(list, chamfered(Vector3.new(r * 0.95, r * 0.6, 0.14), cf, color, { "vertical" }, r * 0.22))
	end
	table.insert(list, M.frustumN(6, r * 0.28, r * 0.16, 0, 0.18, axisFrame(at + Vector3.new(0, 0, -0.06), Vector3.new(0, 0, -1)), { YELLOW }))
end
Gates.wallFlower = wallFlower

-- The stone vine barricade (guide C3): today's 2 piers (12 x 20 x 8) of cut stone courses (front, back and sides,
-- joints, chamfers, cracks) on a jointed chamfered base and cap; today's 2 dark plates as carved panels; a carved
-- diamond frame round today's Neon glyphs (kept); the lintel of cut stone, today's keystone and upper courses as
-- chamfered jointed blocks; today's top root as an octagonal log with knots and vine wraps; moss mounds on the upper
-- courses, Agent A's moss drapes over the courses, a pier cap and a pier base (today's 4 moss slabs); vines on the pier
-- fronts; today's 2 side roots as octagonal braced beams with rope ties; the sign as planks behind today's PriceSign
-- (kept, its GUIs move onto it) in a carved frame. THE BARRICADE (all children of today's Barrier 24 x 16 x 3,
-- PrimaryPart, colliding): today's 7 logs and 2 cross logs as octagonal logs with sawn light ends, rope lashings at
-- every crossing, Agent A's vine strands at today's 4 vines, leaf clusters at today's 8 leaves, today's 3 flowers as
-- 5-petal flowers (#FF508C, #BE5AFF, #FFAA28), 3 small glowing gems. Parts: Moss, Stone, Trim, Wood, Barrier (+
-- BarricadeLogs, BarricadeGreen, BarricadeGems), PriceSign, Glyph x2, Collision x14.
function Gates.jungle_barricade_gate(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_barricade_gate"
	local rng = Random.new(20261243)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Trim = {}, Wood = {}, Moss = {} }
	local STONE, STONE_DARK = P.STONE, P.STONE_DARK
	local ROOT = rgb(104, 68, 44) -- #68442C
	local ROPE = { rgb(196, 160, 104), rgb(172, 140, 90) }
	local CUT = rgb(184, 140, 92)
	local FRONT = Vector3.new(0, 0, -1)
	-- the piers: a dark core, cut stone courses on the 4 faces, a jointed base and cap
	for _, sx in ipairs({ -1, 1 }) do
		local px = sx * 18.2
		table.insert(U.Stone, piece("Part", Vector3.new(11.8, 18, 7.8), CFrame.new(px, 11, 0), STONE_DARK))
		local function nearGlyph(x: number, y: number): boolean
			return math.abs(x - px) < 1.7 and math.abs(y - 12.5) < 1.7
		end
		J.stoneFace(U.Stone, rng, px - 6, px + 6, 2, 20, -4, true, 1.8, STONE, nearGlyph, 2, 1.2)
		J.stoneFace(U.Stone, rng, px - 6, px + 6, 2, 20, 4, false, 1.8, STONE, nil, 1, 1.2)
		for _, side in ipairs({ -1, 1 }) do
			sideStones(U.Stone, rng, px + side * 6, side, -4, 4, 2, 20, 1.8, STONE)
		end
		for k, len in ipairs({ 4.2, 4.6, 4.2 }) do
			local x = px - 6.5 + ({ 0, 4.2, 8.8 })[k] + len / 2
			table.insert(U.Trim, chamfered(Vector3.new(len - 0.1, 2, 9), CFrame.new(x, 1, 0), H.scaled(STONE_DARK, H.TONES[H.toneIndex(rng, nil)]), { "vertical", "topFrontBack", "topSides" }, 0.22))
			table.insert(U.Trim, chamfered(Vector3.new(len - 0.1, 1.6, 9), CFrame.new(x, 20.8, 0), H.scaled(STONE_DARK, H.TONES[H.toneIndex(rng, nil)]), { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.2))
		end
		-- today's dark plates as carved panels, a carved diamond frame round today's glyph
		for _, e in ipairs({ { 1.3, 6.5, 4, rgb(88, 96, 88) }, { -1.7, 16.5, 3.4, rgb(98, 106, 98) } }) do
			table.insert(U.Trim, chamfered(Vector3.new(e[3], 2, 0.34), CFrame.new(px + sx * e[1], e[2], -4.17), e[4], { "frontFace" }, 0.12))
		end
		local dcf = CFrame.new(px, 12.5, -4.2) * CFrame.Angles(0, 0, rad(45))
		for _, e in ipairs({ { 0, 1.2, 2.75, 0.35 }, { 0, -1.2, 2.75, 0.35 }, { -1.2, 0, 0.35, 2.05 }, { 1.2, 0, 0.35, 2.05 } }) do
			table.insert(U.Trim, piece("Part", Vector3.new(e[3], e[4], 0.42), dcf * CFrame.new(e[1], e[2], 0), STONE_DARK))
		end
		-- today's side root as an octagonal braced beam (3 x 25, leaning 10 degrees) with rope ties and a sawn top
		local bcf = CFrame.new(sx * 24.6, 11.5, -3.6) * CFrame.Angles(0, 0, rad(sx * 10))
		table.insert(U.Wood, chamfered(Vector3.new(2.8, 25, 2.8), bcf, ROOT, { "vertical" }, 0.55))
		table.insert(U.Wood, M.frustumN(8, 1.15, 1.15, 12.5, 12.56, bcf, { CUT }))
		for _, ly in ipairs({ -5.5, 4.5 }) do
			for t = 0, 2 do
				ring(U.Wood, (bcf * CFrame.new(0, ly + t * 0.28, 0)).Position, bcf.UpVector, 1.55, 0.24, ROPE)
			end
		end
		-- vines on the pier front (today's 2 vine sticks per pier), hanging from under the cap
		J.vineGroup(U.Moss, rng, Vector3.new(sx * 13.5, 19.95, -4.45), FRONT, Vector3.xAxis, { 6.5, 4.5 })
		J.vineGroup(U.Moss, rng, Vector3.new(sx * 21, 19.95, -4.45), FRONT, Vector3.xAxis, { 9.5, 7 })
	end
	-- the lintel (26 x 5.6 x 7.6, y 16 .. 21.6): a core, cut stone on the front (beside the sign) and the back
	table.insert(U.Stone, piece("Part", Vector3.new(25.8, 5.5, 7.4), CFrame.new(0, 18.8, 0), STONE_DARK))
	J.stoneFace(U.Stone, rng, -13, 13, 16, 21.6, -3.8, true, 1.87, STONE, function(x: number, y: number): boolean
		return math.abs(x) < 6.8
	end, 0, 1.2)
	J.stoneFace(U.Stone, rng, -13, 13, 16, 21.6, 3.8, false, 1.87, STONE, nil, 1, 1.2)
	table.insert(U.Trim, chamfered(Vector3.new(5, 6.4, 8.4), CFrame.new(0, 19.2, 0), STONE_DARK, { "vertical", "topFrontBack", "topSides", "bottomFrontBack" }, 0.3))
	-- the upper courses as jointed chamfered blocks
	local x = -21
	for _, len in ipairs({ 7.6, 8.6, 7.8 }) do
		table.insert(U.Trim, chamfered(Vector3.new(len - 0.12, 3, 7), CFrame.new(x + len / 2, 23.1, 0), H.scaled(STONE, H.TONES[H.toneIndex(rng, nil)]), { "vertical", "topFrontBack", "topSides" }, 0.3))
		x += len
	end
	x = 6.5
	for _, len in ipairs({ 6.2, 6.8 }) do
		table.insert(U.Trim, chamfered(Vector3.new(len - 0.12, 2, 7), CFrame.new(x + len / 2, 22.6, 0), H.scaled(STONE, H.TONES[H.toneIndex(rng, nil)] * 1.02), { "vertical", "topFrontBack", "topSides" }, 0.25))
		x += len
	end
	-- today's top root (34 x 2.6): an octagonal log with knots, sawn ends and 3 vine wraps
	local tcf = CFrame.new(3, 25.6, -1.4) * CFrame.fromOrientation(0, rad(3), rad(5))
	table.insert(U.Wood, chamfered(Vector3.new(34, 2.6, 2.6), tcf, rgb(74, 48, 34), { "topFrontBack", "bottomFrontBack" }, 0.55))
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Wood, M.frustumN(8, 1.05, 1.05, -0.04, 0.04, axisFrame((tcf * CFrame.new(sx * 17, 0, 0)).Position, tcf.RightVector), { CUT }))
	end
	for _, lx in ipairs({ -9, 4, 12 }) do
		for t = 0, 1 do
			ring(U.Moss, (tcf * CFrame.new(lx + t * 0.5, 0, 0)).Position, tcf.RightVector, 1.42, 0.3, { rgb(70, 170, 60), rgb(96, 196, 72) })
		end
	end
	for _, lx in ipairs({ -13, -2, 8 }) do
		knot(U.Wood, (tcf * CFrame.new(lx, 0.6, -1.1)).Position, -tcf.LookVector + tcf.UpVector * 0.3, 0.45, 0.5, rgb(90, 60, 40))
	end
	-- moss: mounds on the upper courses, Agent A's drapes over the courses, the left pier cap and the right pier base
	J.mossPatch(U.Moss, rng, CFrame.new(-11, 24.6, 0.4), 13, 5.5, 1.6)
	J.mossPatch(U.Moss, rng, CFrame.new(14, 23.6, 0.4), 7.5, 5, 1.5)
	J.mossPatch(U.Moss, rng, CFrame.new(-20, 21.6, 0), 6, 6, 1.4)
	J.mossFacet(U, "C", Vector3.new(-14, 24.6, -3.44), FRONT, 1.7)
	J.mossFacet(U, "B", Vector3.new(14, 23.6, -3.44), FRONT, 1.4)
	J.mossFacet(U, "C", Vector3.new(-20, 21.6, -4.44), FRONT, 2.4)
	J.mossFacet(U, "A", Vector3.new(16, 2, -4.44), FRONT, 2.0)
	-- the sign: 3 planks (today's SignBack) behind today's PriceSign, a carved frame round it
	for k, y in ipairs({ 17.33, 19, 20.67 }) do
		table.insert(U.Wood, chamfered(Vector3.new(13.2, 1.62, 0.5), CFrame.new(rng:NextNumber(-0.1, 0.1), y, -4.05), H.scaled(rgb(112, 62, 38), ({ 1.0, 1.08, 0.94 })[k]), { "frontFace" }, 0.08))
	end
	for _, e in ipairs({ { 0, 2.25, 13.0, 0.5 }, { 0, -2.25, 13.0, 0.5 }, { -6.25, 0, 0.5, 4.0 }, { 6.25, 0, 0.5, 4.0 } }) do
		table.insert(U.Wood, chamfered(Vector3.new(e[3], e[4], 0.5), CFrame.new(e[1], 19 + e[2], -4.7), H.scaled(rgb(112, 62, 38), 1.15), { "frontFace" }, 0.15))
	end
	finish(m, "jungle_barricade_gate", U, "Stone")
	-- today's Neon glyphs and PriceSign, kept
	for _, sx in ipairs({ -1, 1 }) do
		exact(m, "Part", "Glyph", Vector3.new(2, 2, 0.3), CFrame.new(sx * 18.2, 12.5, -4.1) * CFrame.Angles(0, 0, rad(45)), rgb(120, 255, 190), { touch = false, shadow = false, neon = true })
	end
	exact(m, "Part", "PriceSign", Vector3.new(12, 4, 0.5), CFrame.new(0, 19, -4.5), rgb(168, 98, 56), COLLIDE)
	-- THE BARRICADE: today's Barrier and its children
	local barrier = makeBarrier(m, Vector3.new(24, 16, 3), CFrame.new(0, 8, 0), rgb(74, 48, 34))
	local logs, green, gems = {}, {}, {}
	local axes = {}
	for _, r in ipairs(BAR_ROOTS) do
		local cf = CFrame.new(r[3], 8, r[4]) * CFrame.Angles(0, 0, rad(r[5]))
		local c = Color3.fromHex(r[6])
		table.insert(logs, chamfered(Vector3.new(r[1], r[2], 1.6), cf, c, { "vertical" }, math.min(r[1], 1.6) * 0.3))
		for _, e in ipairs({ -1, 1 }) do
			table.insert(logs, chamfered(Vector3.new(r[1] * 0.86, 0.08, 1.4), cf * CFrame.new(0, e * r[2] / 2, 0), CUT, { "vertical" }, math.min(r[1], 1.6) * 0.25))
		end
		table.insert(axes, { Vector2.new(r[3], 8), Vector2.new(-math.sin(rad(r[5])), math.cos(rad(r[5]))) })
	end
	for _, r in ipairs(BAR_CROSS) do
		local cf = CFrame.new(r[3], r[4], r[5]) * CFrame.Angles(0, 0, rad(r[6]))
		table.insert(logs, chamfered(Vector3.new(r[1], r[2], 1.4), cf, ROOT, { "topFrontBack", "bottomFrontBack" }, 0.4))
		for _, e in ipairs({ -1, 1 }) do
			table.insert(logs, M.frustumN(8, 0.62, 0.62, -0.04, 0.04, axisFrame((cf * CFrame.new(e * r[1] / 2, 0, 0)).Position, cf.RightVector), { CUT }))
		end
		-- rope lashings where it crosses each log
		local o = Vector2.new(r[3], r[4])
		local d = Vector2.new(math.cos(rad(r[6])), math.sin(rad(r[6])))
		for _, a in ipairs(axes) do
			local det = d.X * (-a[2].Y) - d.Y * (-a[2].X)
			if math.abs(det) > 0.1 then
				local w = a[1] - o
				local s = (w.X * (-a[2].Y) - w.Y * (-a[2].X)) / det
				if math.abs(s) < r[1] / 2 - 0.5 then
					local p = o + d * s
					for t = -1, 1, 2 do
						ring(logs, Vector3.new(p.X, p.Y, r[5]) + cf.RightVector * (t * 0.95), cf.RightVector, 1.06, 0.22, ROPE)
					end
				end
			end
		end
	end
	-- Agent A's vine strands where today's 4 vines hang, leaf clusters at today's 8 leaves, today's 3 flowers
	local VU: any = { Moss = {} }
	for _, v in ipairs({ { -8.5, 1.75 }, { -3.5, 2.0 }, { 3, 1.45 }, { 8, 1.85 } }) do
		J.vineFacets(VU, Vector3.new(v[1], 15.9, -3.35), FRONT, Vector3.xAxis, { v[2] })
	end
	for _, p in ipairs(VU.Moss) do
		table.insert(green, p)
	end
	for _, l in ipairs({ { -9.5, 12 }, { -5, 5.5 }, { -1.5, 13.5 }, { 2.5, 7 }, { 6.5, 12.5 }, { 10, 4.5 }, { -8, 2.6 }, { 4.5, 2.4 } }) do
		wallLeaves(green, rng, Vector3.new(l[1], l[2], -3.4), 5, 1.0)
	end
	for _, f in ipairs({ { -6.5, 9.5, rgb(255, 80, 140), 0.75 }, { 4, 10.5, rgb(190, 90, 255), 0.75 }, { 8.5, 6.5, rgb(255, 170, 40), 0.65 } }) do
		wallFlower(green, Vector3.new(f[1], f[2], -3.55), f[4], f[3])
	end
	for _, g in ipairs({ { -10.3, 5.5, -2.95, rgb(120, 255, 190) }, { 1.9, 10.2, -2.45, rgb(190, 90, 255) }, { 10.2, 13.2, -2.45, rgb(120, 255, 190) } }) do
		table.insert(gems, piece("Part", Vector3.new(0.5, 0.5, 0.22), CFrame.new(g[1], g[2], g[3]) * CFrame.Angles(0, 0, rad(45)), g[4]))
	end
	underBarrier(m, barrier, "BarricadeLogs", logs)
	underBarrier(m, barrier, "BarricadeGreen", green)
	underBarrier(m, barrier, "BarricadeGems", gems, { material = Enum.Material.Neon, shadow = false })
	setPrimary(m, barrier)
	return m
end

---------------------------------------------------------------------
-- 03 TOTEM ARCH = JUNGLE_1's ENTRY ARCH (kit MapAssets.Gates.EntryArch_Jungle, 54 parts; Zones.Jungle.Jungle_1.EntryArch)
---------------------------------------------------------------------
M.SHAPES.jungle_totem_arch = { -- today's colliding parts except the NameSign (kept)
	{ "Block", 37, 3, 3, { 0, 20.6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Beam
	{ "Block", 15.2, 5, 0.6, { 0, 24.6, -0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- SignBack
}
-- today's 4 heads per totem (bottom to top): width, centre y, colour, eye colour, mouth, beak
local TOTEM_HEADS = {
	{ 4.3, 3.7, rgb(196, 70, 50), rgb(232, 226, 208), true, false },
	{ 4.6, 8.1, rgb(214, 150, 92), rgb(74, 48, 34), false, true },
	{ 4.3, 12.5, rgb(60, 170, 190), rgb(232, 226, 208), true, false },
	{ 4.6, 16.9, rgb(104, 68, 44), rgb(255, 201, 60), false, false },
}
for _, sx in ipairs({ -1, 1 }) do
	table.insert(M.SHAPES.jungle_totem_arch, { "Block", 6.2, 1.5, 6.2, { sx * 15.5, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }) -- Base
	for _, h in ipairs(TOTEM_HEADS) do
		table.insert(M.SHAPES.jungle_totem_arch, { "Block", h[1], 4.4, h[1], { sx * 15.5, h[2], 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }) -- TotemHead
	end
	local c, s = math.cos(rad(sx * 16)), math.sin(rad(sx * 16))
	table.insert(M.SHAPES.jungle_totem_arch, { "Block", 5.4, 2.6, 0.7, { sx * 20.1, 12.6, 0, c, -s, 0, s, c, 0, 0, 0, 1 } }) -- Wing
end

-- The totem arch (guide C3): 2 carved totems on today's places: each of today's 4 heads (sizes and colours kept) a
-- chamfered block with a brow ridge, eye sockets round today's eyes (kept), a carved nose (today's beak kept on the tan
-- head), today's mouths (kept) with teeth, cheek plates and ear blocks, a darker joint ring between the heads; Agent A's
-- carved feathered wings (today's wing places, kept as colliders); a headdress of 3 feather plumes and a gold band on
-- the top head; a stepped base plinth; today's beam as 3 jointed timbers with pegs, today's 4 vine wraps as vine
-- turns, Agent A's vine strands hanging from it, leaf clusters and today's 2 flowers; today's bowls (with today's Neon
-- Embers and their FirePoints kept) as carved wooden bowls on the beam; the sign as planks behind today's NameSign
-- (kept, its GUIs move onto it) in a carved frame; today's gold Mask diamond (kept) in a carved frame with gold studs.
-- Passage kept: 26.4 wide (the totems' inner faces) x 19.1 tall. Parts: Carving, Gold, Moss, Totems, Wood, Ember x2
-- (+ FirePoint), NameSign, Mask, Eye x16, Mouth x4, Beak x2, Collision x14.
function Gates.jungle_totem_arch(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_totem_arch"
	local rng = Random.new(20261244)
	H.setBevelSelf(true)
	local U: any = { Totems = {}, Carving = {}, Wood = {}, Gold = {}, Moss = {} }
	local DARK = rgb(112, 62, 38) -- #703E26
	local BASE = rgb(74, 48, 34) -- #4A3022
	local GOLD = rgb(255, 201, 60)
	local TEETH = rgb(232, 226, 208)
	local FRONT = Vector3.new(0, 0, -1)
	for _, sx in ipairs({ -1, 1 }) do
		local tx = sx * 15.5
		-- the stepped base plinth (today's Base 6.2 x 1.5)
		table.insert(U.Wood, chamfered(Vector3.new(6.2, 0.8, 6.2), CFrame.new(tx, 0.4, 0), H.scaled(BASE, 0.92), { "vertical", "topFrontBack", "topSides" }, 0.25))
		table.insert(U.Wood, chamfered(Vector3.new(5.4, 0.7, 5.4), CFrame.new(tx, 1.15, 0), BASE, { "vertical", "topFrontBack", "topSides" }, 0.2))
		-- the 4 carved heads
		for i, h in ipairs(TOTEM_HEADS) do
			local s, y, c = h[1], h[2], h[3]
			local fz = -s / 2
			table.insert(U.Totems, chamfered(Vector3.new(s, 4.4, s), CFrame.new(tx, y, 0), c, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.22))
			-- brow ridge, eye sockets, cheek plates, ear blocks
			table.insert(U.Carving, chamfered(Vector3.new(s * 0.86, 0.45, 0.4), CFrame.new(tx, y + 1.45, fz - 0.15), H.scaled(c, 0.82), { "topFrontBack", "bottomFrontBack" }, 0.12))
			for _, ex in ipairs({ -1.1, 1.1 }) do
				table.insert(U.Carving, piece("Part", Vector3.new(1.4, 1.4, 0.14), CFrame.new(tx + ex, y + 0.6, fz - 0.06), H.scaled(c, 0.55)))
				table.insert(U.Carving, chamfered(Vector3.new(0.8, 1.0, 0.22), CFrame.new(tx + ex * 1.55, y - 0.65, fz - 0.1), H.scaled(c, 1.1), { "frontFace" }, 0.08))
				table.insert(U.Carving, chamfered(Vector3.new(0.3, 1.6, 1.3), CFrame.new(tx + math.sign(ex) * (s / 2 + 0.15), y + 0.3, 0), H.scaled(c, 0.85), { "vertical" }, 0.08))
			end
			if not h[6] then
				-- a carved nose (the tan head keeps today's beak)
				table.insert(U.Carving, piece("WedgePart", Vector3.new(0.9, 1.1, 0.55), CFrame.new(tx, y - 0.1, fz - 0.27), H.scaled(c, 0.9)))
			end
			if h[5] then
				for t = -1.5, 1.5 do
					table.insert(U.Carving, piece("Part", Vector3.new(0.42, 0.32, 0.1), CFrame.new(tx + t * 0.62, y - 1.08, fz - 0.37), TEETH))
				end
			else
				table.insert(U.Carving, chamfered(Vector3.new(2.2, 0.35, 0.18), CFrame.new(tx, y - 1.25, fz - 0.08), H.scaled(c, 0.6), { "frontFace" }, 0.08))
			end
			-- a darker joint ring above the head
			if i < #TOTEM_HEADS then
				table.insert(U.Wood, chamfered(Vector3.new(s + 0.22, 0.3, s + 0.22), CFrame.new(tx, y + 2.2, 0), H.scaled(BASE, 0.85), { "vertical" }, 0.15))
			end
		end
		-- the headdress on the top head: a gold band and 3 feather plumes in front of the beam
		table.insert(U.Gold, chamfered(Vector3.new(4.82, 0.45, 4.82), CFrame.new(tx, 18.75, 0), GOLD, { "vertical" }, 0.18))
		for k, f in ipairs({ { -1.1, -14, rgb(196, 70, 50) }, { 0, 0, rgb(60, 170, 190) }, { 1.1, 14, GOLD } }) do
			local cf = CFrame.new(tx + f[1], 19.0, -2.55) * CFrame.Angles(0, 0, rad(f[2])) * CFrame.new(0, 1.3, 0)
			table.insert(U.Carving, chamfered(Vector3.new(0.8, 2.8, 0.16), cf, f[3], { "vertical" }, 0.3))
			table.insert(U.Carving, piece("Part", Vector3.new(0.12, 2.3, 0.08), cf * CFrame.new(0, -0.1, -0.1), H.scaled(f[3], 0.7)))
			if k == 2 then
				table.insert(U.Gold, piece("Part", Vector3.new(0.5, 0.5, 0.2), CFrame.new(tx, 18.75, -2.5) * CFrame.Angles(0, 0, rad(45)), H.scaled(GOLD, 0.85)))
			end
		end
		-- today's bowl as a carved wooden bowl on the beam
		table.insert(U.Wood, M.frustumN(8, 0.85, 1.25, 22.1, 22.95, CFrame.new(tx, 0, 0), { rgb(104, 68, 44), rgb(90, 58, 38) }))
		ring(U.Wood, Vector3.new(tx, 22.98, 0), Vector3.yAxis, 1.3, 0.12, { rgb(84, 54, 36) })
		-- Agent A's vine strands hanging from the beam, today's vine wraps as vine turns
		J.vineFacets(U, Vector3.new(sx * 11.5, 19.2, -1.55), FRONT, Vector3.xAxis, { 0.75, 0.5 })
		J.vineFacets(U, Vector3.new(sx * 9.8, 19.2, 1.55), Vector3.new(0, 0, 1), Vector3.xAxis, { 0.45 })
		for _, wx in ipairs({ 11.5, 8.4 }) do
			for t = -1, 1 do
				ring(U.Moss, Vector3.new(sx * wx + t * 0.36, 20.6, 0), Vector3.xAxis, 1.62, 0.3, { rgb(70, 170, 60), rgb(120, 210, 70) })
			end
		end
		-- today's leaf tuft and flower beside the sign
		leafCluster(U.Moss, rng, Vector3.new(sx * 9.0, 22.9, -0.4), 11, 1.6)
		leafCluster(U.Moss, rng, Vector3.new(sx * 12.6, 22.5, 0.3), 7, 1.3)
		wallFlower(U.Moss, Vector3.new(sx * 9.0, 21.7, -1.62), 0.75, if sx < 0 then rgb(255, 170, 40) else rgb(255, 80, 140))
	end
	-- the beam (37 x 3 x 3): 3 jointed timbers with pegs
	for k = -1, 1 do
		table.insert(U.Wood, chamfered(Vector3.new(12.25, 3, 3), CFrame.new(k * 12.33, 20.6, 0), H.scaled(DARK, ({ 0.96, 1.04, 0.98 })[k + 2]), { "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }, 0.4))
	end
	for _, jx in ipairs({ -6.17, 6.17 }) do
		for _, dx in ipairs({ -0.55, 0.55 }) do
			for _, py in ipairs({ 19.8, 21.4 }) do
				table.insert(U.Wood, piece("Part", Vector3.new(0.12, 0.34, 0.34), CFrame.new(jx + dx, py, -1.52) * CFrame.Angles(0, rad(90), 0), H.scaled(DARK, 0.7), { shape = Enum.PartType.Cylinder }))
			end
		end
	end
	-- the sign: planks behind today's NameSign, a carved frame round it
	for k, y in ipairs({ 22.93, 24.6, 26.27 }) do
		table.insert(U.Wood, chamfered(Vector3.new(15.2, 1.62, 0.6), CFrame.new(rng:NextNumber(-0.1, 0.1), y, -0.5), H.scaled(DARK, ({ 1.0, 1.08, 0.94 })[k]), { "frontFace" }, 0.08))
	end
	for _, e in ipairs({ { 0, 2.25, 15.0, 0.5 }, { 0, -2.25, 15.0, 0.5 }, { -7.25, 0, 0.5, 4.0 }, { 7.25, 0, 0.5, 4.0 } }) do
		table.insert(U.Wood, chamfered(Vector3.new(e[3], e[4], 0.5), CFrame.new(e[1], 24.6 + e[2], -0.95), H.scaled(DARK, 1.15), { "frontFace" }, 0.15))
	end
	-- the gold emblem: a carved frame round today's Mask diamond, 4 gold studs
	local mcf = CFrame.new(0, 28.3, -0.5) * CFrame.Angles(0, 0, rad(45))
	for _, e in ipairs({ { 0, 1.75, 4.0, 0.5 }, { 0, -1.75, 4.0, 0.5 }, { -1.75, 0, 0.5, 3.0 }, { 1.75, 0, 0.5, 3.0 } }) do
		table.insert(U.Wood, chamfered(Vector3.new(e[3], e[4], 0.7), mcf * CFrame.new(e[1], e[2], 0), H.scaled(DARK, 1.12), { "frontFace" }, 0.12))
	end
	for _, e in ipairs({ { 0, 2.2 }, { 0, -2.2 }, { -2.2, 0 }, { 2.2, 0 } }) do
		table.insert(U.Gold, piece("Part", Vector3.new(0.4, 0.4, 0.2), mcf * CFrame.new(e[1], e[2], -0.3), GOLD))
	end
	-- Agent A's feathered wings (on the kit pivot)
	J.facets(U, GData.totem_wing_L, Vector3.one, CFrame.identity, "Carving")
	J.facets(U, GData.totem_wing_R, Vector3.one, CFrame.identity, "Carving")
	finish(m, "jungle_totem_arch", U, "Totems")
	-- today's eyes, mouths, beaks, Embers (+ FirePoint), NameSign and Mask, kept
	for _, sx in ipairs({ -1, 1 }) do
		local tx = sx * 15.5
		for _, h in ipairs(TOTEM_HEADS) do
			for _, ex in ipairs({ -1.1, 1.1 }) do
				exact(m, "Part", "Eye", Vector3.new(1, 1, 0.3), CFrame.new(tx + ex, h[2] + 0.6, -2.35), h[4], DECOR)
			end
			if h[5] then
				exact(m, "Part", "Mouth", Vector3.new(2.8, 0.7, 0.3), CFrame.new(tx, h[2] - 1.2, -2.35), rgb(74, 48, 34), DECOR)
			end
		end
		exact(m, "WedgePart", "Beak", Vector3.new(1.6, 1.8, 2.2), CFrame.new(tx, 7.6, -3.3), GOLD, DECOR)
		local ember = exact(m, "Part", "Ember", Vector3.new(1.6, 0.5, 1.6), CFrame.new(tx, 23.3, 0), rgb(255, 140, 40), EMBER)
		local fp = Instance.new("Attachment")
		fp.Name = "FirePoint"
		fp.Position = Vector3.new(0, 0.3, 0)
		fp.Parent = ember
	end
	exact(m, "Part", "NameSign", Vector3.new(14, 4, 0.5), CFrame.new(0, 24.6, -1), rgb(168, 98, 56), COLLIDE)
	exact(m, "Part", "Mask", Vector3.new(3, 3, 0.6), CFrame.new(0, 28.3, -0.5) * CFrame.Angles(0, 0, rad(45)), GOLD, DECOR)
	return m
end

---------------------------------------------------------------------
-- 05 ROCK CAVE ENTRANCE (kit MapAssets.Jungle.Jaguar_Den_Rocks, 9 parts, a Toolbox asset; Jungle_3 Ruins x1, BA x1)
---------------------------------------------------------------------
-- Today's colliders are MeshParts (Hull collision) that a script cannot rebuild: they are cloned from the kit (today's
-- Rock / Roof MeshParts, or the Collision MeshParts of an earlier build of this template).
local CAVE_BACK_MESH = "rbxassetid://9420263160" -- today's back rock (behind the dark opening): kept visible, as it is

-- The rock cave (guide C3): Agent A's layered faceted rocks (left and right, 3 tone steps, cracks) and the layered top
-- slab with its soft moss cap and grass tufts in place of today's 2 side rocks, roof and moss; a moss lip of 3
-- layered moss mats on the slab's bevel / crest (gaps of grey rock), 4 soft drapes and 2 vines down its front, grass tufts; today's back rock and today's
-- dark Shadow (the opening 14 x 11, front at z 2.5) kept; a worn threshold stone 14 x 0.6 x 1.2 at the front;
-- 3 bones (shafts with knuckle ends) and Agent A's small skull at today's places. Collision: today's 3 colliding
-- rock / roof MeshParts kept as invisible Collision parts, the back rock as it is. Parts: Bones, Drapes, Moss, Rocks, Slab, Rock (back), Shadow, Collision x3.
function Gates.rock_cave(): Model
	local m = Instance.new("Model")
	m.Name = "rock_cave"
	local rng = Random.new(20261245)
	H.setBevelSelf(true)
	local U: any = { Rocks = {}, Slab = {}, Bones = {}, Moss = {} }
	local BONE = rgb(232, 226, 208)
	J.facets(U, GData.cave_rock_L, Vector3.one, CFrame.identity, "Rocks")
	J.facets(U, GData.cave_rock_R, Vector3.one, CFrame.identity, "Rocks")
	J.facets(U, GData.cave_top_slab, Vector3.one, CFrame.identity, "Slab")
	-- the moss lip along the slab's front (measured on Agent A's slab with rays: per x, the front-most point z / y of
	-- the edge and the crest height 0.8 behind it), between x -11.5 and 11.5 (it stops before the front corners):
	-- 3 layered moss mats on the bevel / crest with gaps of grey rock; never more than ~0.4 in front of the rock
	local SLAB_EDGE = { -- x, front z, front y, crest y
		{ -12, -3.3, 13.76, 15.35 }, { -11, -3.5, 13.8, 15.94 }, { -10, -3.8, 13.5, 15.95 }, { -9, -4.0, 13.51, 15.93 },
		{ -8, -4.2, 13.52, 15.9 }, { -7, -4.4, 13.53, 15.88 }, { -6, -4.6, 13.54, 15.85 }, { -5, -4.8, 13.55, 15.83 },
		{ -4, -4.9, 13.73, 15.88 }, { -3, -5.1, 13.52, 15.86 }, { -2, -5.2, 13.62, 15.91 }, { -1, -5.2, 14.04, 16.03 },
		{ 0, -5.3, 14.14, 16.06 }, { 1, -5.3, 14.56, 16.07 }, { 2, -5.3, 14.98, 16.08 }, { 3, -5.4, 15.08, 16.09 },
		{ 4, -5.4, 15.49, 16.1 }, { 5, -5.4, 15.91, 16.11 }, { 6, -5.4, 16.12, 16.12 }, { 7, -5.2, 15.89, 16.11 },
		{ 8, -4.9, 15.54, 16.08 }, { 9, -4.6, 15.19, 16.0 }, { 10, -4.3, 14.84, 15.88 }, { 11, -4.1, 14.36, 15.4 },
		{ 12, -3.8, 14.02, 15.06 },
	}
	local function edgeAt(x: number): (number, number, number)
		local i = math.clamp(math.floor(x) + 13, 1, #SLAB_EDGE - 1)
		local a, b = SLAB_EDGE[i], SLAB_EDGE[i + 1]
		local f = math.clamp(x - a[1], 0, 1)
		return a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f, a[4] + (b[4] - a[4]) * f
	end
	-- the lip: 3 moss mats with grey rock between them, layered like the guide's 2-3 layer moss. Each layer of a mat is
	-- a run of overlapping low 7-sided domes merged into one flat patch with a soft, wavy outline (they lie on the
	-- bevel, or on the crest rolling over the edge where the front is steep): a broad dark base (#589642, 0.3-0.5 tall,
	-- 1.5-2.5 deep), a lighter second layer on it (#60C448, 60-70 % of its length), 2 small highlight bumps (#78D246)
	local function lipPoint(fx: number, t: number): (Vector3, Vector3, Vector3)
		local z, ye, yc = edgeAt(fx)
		local z2 = edgeAt(fx + 0.5)
		local along = Vector3.new(0.5, 0, z2 - z).Unit
		local out = Vector3.new(along.Z, 0, -along.X)
		if yc - ye > 0.8 then
			return Vector3.new(fx, ye + t * (yc - ye), z + t * 0.8), (out * (yc - ye) + Vector3.yAxis * 0.8).Unit, along
		end
		return Vector3.new(fx, yc - 0.15, z + 0.55 + t * 0.8), (out * 1.2 + Vector3.yAxis).Unit, along
	end
	local function patch(x0: number, x1: number, r: number, h: number, t: number, lift: number, color: Color3)
		local x = x0
		while x <= x1 + 0.01 do
			local pos, n, along = lipPoint(x, t + rng:NextNumber(-0.12, 0.12))
			local rr = r * rng:NextNumber(0.85, 1.1)
			local cf = CFrame.fromMatrix(pos + n * lift, along, n) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			table.insert(U.Moss, M.frustumN(7, rr, rr * 0.62, -0.15, h * rng:NextNumber(0.85, 1.1), cf, { H.scaled(color, rng:NextNumber(0.97, 1.03)), H.scaled(color, 0.93) }))
			x += r * rng:NextNumber(0.85, 1.05)
		end
	end
	for _, mat in ipairs({ { -10.6, -5.4 }, { -3.4, 0.9 }, { 3.0, 8.6 } }) do
		local a, b = mat[1], mat[2]
		patch(a, b, rng:NextNumber(1.05, 1.25), rng:NextNumber(0.32, 0.45), 0.55, 0, H.scaled(MOSS[1], rng:NextNumber(0.96, 1.04)))
		local len = (b - a) * rng:NextNumber(0.6, 0.7)
		local s0 = a + rng:NextNumber(0, (b - a) - len)
		patch(s0, s0 + len, rng:NextNumber(0.72, 0.85), rng:NextNumber(0.25, 0.32), 0.6, 0.22, H.scaled(MOSS[2], rng:NextNumber(0.96, 1.04)))
		for _ = 1, 2 do
			local hx = s0 + rng:NextNumber(0.3, len - 0.3)
			local pos, n, along = lipPoint(hx, 0.62)
			table.insert(U.Moss, M.frustumN(6, rng:NextNumber(0.35, 0.48), 0.2, -0.1, 0.22, CFrame.fromMatrix(pos + n * 0.42, along, n), { MOSS[3], H.scaled(MOSS[3], 0.93) }))
		end
	end
	-- 4 soft drapes of different lengths running down the front face (Agent A's, thin: <= 0.4 out) and 2 thin vines
	for _, d in ipairs({ { "A", -8, 1.3 }, { "C", -3, 1.1 }, { "A", 3.5, 0.9 }, { "C", 8, 0.65 } }) do
		local z, ye = edgeAt(d[2])
		local z2 = edgeAt(d[2] + 0.5)
		local tangent = Vector3.new(0.5, 0, z2 - z).Unit
		local out = Vector3.new(tangent.Z, 0, -tangent.X)
		local at = Vector3.new(d[2], ye - 0.05, z + 0.06)
		J.facets(U, J.Data["moss_drape_" .. d[1]], Vector3.one * d[3], CFrame.lookAt(at, at + out), "Drapes") -- (own union: the Moss one is full)
	end
	for _, v in ipairs({ { -5.6, 2.8 }, { 6.1, 2.2 } }) do -- (thin part vines: lighter than the facet strands here)
		local z, ye = edgeAt(v[1])
		J.vineGroup(U.Moss, rng, Vector3.new(v[1], ye - 0.1, z - 0.04), Vector3.new(0, 0, -1), Vector3.xAxis, { v[2] })
	end
	-- grass tufts on the crest behind the lip
	for _, gx in ipairs({ -9.5, -4.2, 0.8, 5.2, 9.3 }) do
		local z, _, yc = edgeAt(gx)
		for k = 0, 2 do
			local cf = CFrame.new(gx + (k - 1) * 0.22, yc + 0.4, z + 1.5) * CFrame.Angles(rad(rng:NextNumber(-12, 12)), 0, rad((k - 1) * 22))
			table.insert(U.Slab, piece("Part", Vector3.new(0.12, rng:NextNumber(0.9, 1.3), 0.05), cf, if k == 1 then rgb(120, 210, 70) else rgb(96, 196, 72)))
		end
	end
	-- the worn threshold stone at the front of the opening
	table.insert(U.Rocks, chamfered(Vector3.new(14, 0.6, 1.2), CFrame.new(0, 0.3, 2.2), rgb(92, 100, 92), { "topFrontBack", "topSides" }, 0.22))
	for k = -2, 2 do
		table.insert(U.Rocks, piece("Part", Vector3.new(0.06, 0.5, 1.05), CFrame.new(k * 2.8 + rng:NextNumber(-0.4, 0.4), 0.33, 2.2), rgb(70, 76, 70)))
	end
	-- 3 bones (a shaft and 2 knuckle ends) and Agent A's small skull at today's places
	for _, b in ipairs({ { -3, -6, 30, 3 }, { 2.5, -7.5, -50, 2.4 }, { -0.6, -5.0, 80, 1.6 } }) do
		local cf = CFrame.new(b[1], 0.22, b[2]) * CFrame.Angles(0, rad(b[3]), 0)
		table.insert(U.Bones, piece("Part", Vector3.new(b[4], 0.35, 0.35), cf, H.scaled(BONE, 0.96), { shape = Enum.PartType.Cylinder }))
		for _, e in ipairs({ -1, 1 }) do
			table.insert(U.Bones, M.frustumN(6, 0.3, 0.3, -0.2, 0.2, axisFrame((cf * CFrame.new(e * b[4] / 2, 0.05, 0)).Position, cf.RightVector), { BONE, H.scaled(BONE, 0.9) }))
		end
	end
	J.facets(U, GData.skull_small, Vector3.one, CFrame.new(4.5, 0, -4.5) * CFrame.Angles(0, rad(25), 0), "Bones")
	finish(m, "rock_cave", U, "Rocks")
	-- today's dark Shadow (the opening), kept
	exact(m, "Part", "Shadow", Vector3.new(14, 11, 6), CFrame.new(0, 5.5, 5.5), rgb(41, 45, 41), DECOR)
	-- today's colliding MeshParts: the back rock kept as it is, the 2 side rocks and the roof as invisible colliders
	local kit = ServerStorage:FindFirstChild("MapAssets") and ServerStorage.MapAssets:FindFirstChild("Jungle") and ServerStorage.MapAssets.Jungle:FindFirstChild("Jaguar_Den_Rocks")
	assert(kit, "rock_cave: the kit MapAssets.Jungle.Jaguar_Den_Rocks is needed (its MeshParts are today's colliders)")
	local piv = kit:GetPivot()
	local count = 0
	for _, p in ipairs(kit:GetChildren()) do
		if p:IsA("MeshPart") and p.CanCollide and (p.Name == "Rock" or p.Name == "Roof" or p.Name == "Collision") then
			local c = p:Clone()
			c:ClearAllChildren()
			c.CFrame = piv:ToObjectSpace(p.CFrame)
			c.Anchored = true
			c.CanCollide = true
			c.CanQuery = true
			if c.MeshId == CAVE_BACK_MESH then
				c.Name = "Rock"
				c.Transparency = 0
				c.CanTouch = true
				c.CastShadow = true
			else
				c.Name = "Collision"
				c.Transparency = 1
				c.CanTouch = false
				c.CastShadow = false
			end
			c.Parent = m
			count += 1
		end
	end
	assert(count == 4, `rock_cave: expected today's 4 colliding MeshParts in the kit, found {count}`)
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table as the jungle buildings; its install() builds them
---------------------------------------------------------------------
Gates.BUILDERS = { root_arch = true, jungle_palisade_gate = true, jungle_barricade_gate = true, jungle_totem_arch = true, rock_cave = true }
for id in pairs(Gates.BUILDERS) do
	B2[id] = (Gates :: any)[id]
	B2.BUILDERS[id] = true
end
Gates.install = B2.install
Gates.SHAPES = M.SHAPES
Gates.J = J

return Gates
