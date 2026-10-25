--[[
	PropsSwampTrees (dev tool, Edit mode only) - the owner's "CURSED SWAMP PROP IMPROVEMENT - Trees and nature"
	(2026-10-25): 01 the mangrove tree A (SwampTree_A; its far copies in Swamp_1.Decor.Backdrop are the separate
	swamp_mangrove_a_far), 02 the mangrove tree B (SwampTree_B), 03 the dead tree with the face (TwistedTree_A), 04 the
	twisted dead tree with the hollow (TwistedTree_C), 05 the hanging vine curtain (Hanging_Moss_A), 06 the hollow magic
	stump (Rotten_Trunk_Glow), to the fountain / well quality in the cursed swamp look (docs/prop_texture_guide.md
	sections A and F), keeping each kit's size, collisions, glows and copies.
	Source of truth: tools/PropsSwampTrees.luau. Data: tools/PropsSwampTreesData.luau (today's kit parts).
	Inventory: docs/prop_inventory.md "Swamp trees".

	Many copies (40 + 40 far / 27 / 34 / 47 / 36): every piece is cheap (8-sided logs, faceted convex leaf clusters,
	folded convex leaves, part vines) and merged into a few unions per tree (budgets: mangrove A 3.5k triangles, far
	1.2k, B 4.5k, face tree 3k, hollow tree 2.5k, vine curtain 0.6k, magic stump 8k). Collision: today's colliding parts
	as invisible "Collision" copies (the stump's trunk mesh keeps its mesh and Hull); the visible pieces never collide.

		local ST = require(game.ServerStorage.DevTools.PropsSwampTrees:Clone())
		print(ST.install("swamp_mangrove_a"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "swamp_mangrove_a" } }), Sync.run({ only = { "swamp_mangrove_a" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local SH = require(ServerStorage.DevTools.PropsSwampHuts:Clone()) :: any
local TB, B2, H, M = SH.TB, SH.B2, SH.H, SH.M
local GD = require(ServerStorage.DevTools.PropsSwampTreesData:Clone()) :: any
local piece = H.piece
local scaled = H.scaled
local frustumN = M.frustumN
local lump = TB.lump
local C = SH.COLORS

local ST = {}

local rgb = Color3.fromRGB
local rad = math.rad
local UP = Vector3.yAxis

-- swamp accents (guide F1); the kits' own colours come from the rows
local BARK_LINE = rgb(34, 24, 18) -- #221812 the dark grooves between bark ridges
local KNOT = rgb(46, 34, 26)
local MUD = C.MUD_DARK -- #3A2A1C
local MUD_WET = rgb(44, 34, 26)
local MOSS, MOSS_MID, OLIVE = C.MOSS, C.MOSS_MID, C.OLIVE
local MOSS_TOP = MOSS:Lerp(OLIVE, 0.3) -- #5B852D
local WET = rgb(30, 74, 79) -- #1E4A4F: the teal that the wet leaf undersides lean to
local FERN = { rgb(52, 104, 46), rgb(66, 122, 52), rgb(44, 90, 42) } -- #34682E #427A34 #2C5A2A
local LEAF_VINE = { rgb(63, 122, 44), rgb(76, 138, 51), rgb(92, 130, 58) } -- #3F7A2C #4C8A33 #5C823A

---------------------------------------------------------------------
-- rows and colliders
---------------------------------------------------------------------
local function rows(kit: string, name: string?): { any }
	return GD.rows(kit, name)
end
ST.rows = rows

-- a MeshPart with this MeshId and collision fidelity to clone (CollisionFidelity cannot be set from a script)
local function meshSource(meshId: string, fidelity: string): MeshPart?
	local roots = { ServerStorage:FindFirstChild("MapAssets"), ServerStorage:FindFirstChild("MapProps"), ServerStorage:FindFirstChild("BossArenas"), workspace:FindFirstChild("_Staging"), workspace:FindFirstChild("Zones") }
	for _, root in ipairs(roots) do
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("MeshPart") and d.MeshId == meshId and d.CollisionFidelity.Name == fidelity then
					return d
				end
			end
		end
	end
	return nil
end

-- a bare part (or mesh clone) with a row's class, shape, size and place
local function rowPart(r: any): BasePart
	local p: BasePart
	if r.class == "MeshPart" then
		local src = meshSource(r.meshId, r.fidelity)
		assert(src, `PropsSwampTrees: no MeshPart with {r.meshId} ({r.fidelity}) to clone`)
		p = src:Clone()
		p:ClearAllChildren()
		for key in pairs(p:GetAttributes()) do
			p:SetAttribute(key, nil)
		end
		for _, tag in ipairs(p:GetTags()) do
			p:RemoveTag(tag)
		end
	else
		p = Instance.new(r.class) :: BasePart
		if r.shape ~= "" and p:IsA("Part") then
			p.Shape = (Enum.PartType :: any)[r.shape]
		end
	end
	p.Size = r.size
	p.CFrame = r.cf
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- an exact copy of a row (name, size, place, colour, material, transparency, flags)
local function exactRow(parent: Instance, r: any): BasePart
	local p = rowPart(r)
	p.Name = r.name
	p.Color = r.color
	p.Material = (Enum.Material :: any)[r.material]
	p.Transparency = r.transparency
	p.CanCollide = r.collide
	p.CanQuery = r.query
	p.CanTouch = true
	p.Parent = parent
	return p
end
ST.exactRow = exactRow

-- an invisible "Collision" copy of a colliding row (meshes keep their mesh and collision fidelity)
local function collider(m: Model, r: any, name: string?): BasePart
	local p = rowPart(r)
	p.Name = name or "Collision"
	p.Color = r.color
	p.Transparency = 1
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = true
	p.CastShadow = false
	if p:IsA("MeshPart") then
		(p :: MeshPart).TextureID = ""
	end
	p.Parent = m
	return p
end

-- every colliding row of a kit as a Collision part; returns how many
local function colliders(m: Model, kit: string): number
	local n = 0
	for _, r in ipairs(rows(kit)) do
		if r.collide then
			collider(m, r)
			n += 1
		end
	end
	return n
end

-- the ends of a block row's long axis: (low end, high end, length, thickness)
local function ends(r: any): (Vector3, Vector3, number, number)
	local s = r.size
	local axis, len, thick
	if s.X >= s.Y and s.X >= s.Z then
		axis, len, thick = r.cf.XVector, s.X, math.min(s.Y, s.Z)
	elseif s.Y >= s.Z then
		axis, len, thick = r.cf.YVector, s.Y, math.min(s.X, s.Z)
	else
		axis, len, thick = r.cf.ZVector, s.Z, math.min(s.X, s.Y)
	end
	local a, b = r.cf.Position - axis * len / 2, r.cf.Position + axis * len / 2
	if a.Y > b.Y then
		a, b = b, a
	end
	return a, b, len, thick
end
ST.ends = ends

---------------------------------------------------------------------
-- shared pieces
---------------------------------------------------------------------
local function tone(rng: Random, c: Color3): Color3
	return scaled(c, H.TONES[H.toneIndex(rng, nil)])
end

-- a cheap faceted blob (an ellipsoid a x b x c circumscribed by 18 jittered planes: 6 faces, 8 corners, 4 horizontal
-- edges; about 45 triangles against about 90 for the 26 planes of TB.lump) at frame; flat: a flat bottom that far
-- under the centre
local BLOB_DIRS = {}
for _, d in ipairs({ { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 }, { 1, 0, 1 }, { 1, 0, -1 }, { -1, 0, 1 }, { -1, 0, -1 } }) do
	table.insert(BLOB_DIRS, Vector3.new(d[1], d[2], d[3]).Unit)
end
for _, sx in ipairs({ -1, 1 }) do
	for _, sy in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(BLOB_DIRS, Vector3.new(sx, sy * 0.8, sz).Unit)
		end
	end
end
local function blob(list: { BasePart }, rng: Random, frame: CFrame, a: number, b: number, c: number, toneOf: (Vector3) -> Color3, flat: number?)
	local planes = {}
	for _, d0 in ipairs(BLOB_DIRS) do
		local d = (d0 + Vector3.new(rng:NextNumber(-0.12, 0.12), rng:NextNumber(-0.12, 0.12), rng:NextNumber(-0.12, 0.12))).Unit
		table.insert(planes, { n = d, d = math.sqrt((a * d.X) ^ 2 + (b * d.Y) ^ 2 + (c * d.Z) ^ 2) })
	end
	if flat then
		table.insert(planes, { n = -UP, d = flat })
	end
	local e = Vector3.new(a, b, c) * 1.5
	TB.solidOf(list, frame, -e, e, planes, toneOf)
end
ST.blob = blob

-- a square stem segment from a to b, t thick, ending exactly at both points (no overlap: cheaper unions)
local function stemBar(a: Vector3, b: Vector3, t: number, color: Color3): BasePart
	return piece("Part", Vector3.new(t, t, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color)
end

-- a twisted bark log from a to b (8-sided, apothem r0 -> r1): segments about 3.6 long, each turned 17 degrees further
-- round the axis with a tone step, and 2 dark bark grooves per segment that wind with the twist (lines may be nil)
local function twistedLog(list: { BasePart }, lines: { BasePart }?, rng: Random, a: Vector3, b: Vector3, r0: number, r1: number, color: Color3, twist0: number?, step: number?)
	local L = (b - a).Magnitude
	local segs = math.max(1, math.round(L / 3.6))
	local base = H.frameY(a, b - a)
	local ang0 = twist0 or rng:NextNumber(0, 1)
	for k = 0, segs - 1 do
		local t0, t1 = k / segs, (k + 1) / segs
		local ra, rb = r0 + (r1 - r0) * t0, r0 + (r1 - r0) * t1
		local ang = ang0 + k * (step or rad(17))
		local cf = base * CFrame.Angles(0, ang, 0)
		local c = tone(rng, color)
		table.insert(list, frustumN(8, ra, rb, L * t0 - (if k > 0 then 0.06 else 0), L * t1 + 0.06, cf, { c, scaled(c, 1.08), scaled(c, 0.9), scaled(c, 0.97) }))
		if lines then
			for j = 0, 1 do
				local th = ang + (j * 4 + 1 + k % 2) * math.pi / 4 + rng:NextNumber(-0.12, 0.12)
				local p0 = base * CFrame.Angles(0, th, 0) * CFrame.new(ra * 1.0, L * t0 + 0.15, 0)
				local p1 = base * CFrame.Angles(0, th - rad(14), 0) * CFrame.new(rb * 1.0, L * t1 - 0.15, 0)
				table.insert(lines, H.bar(p0.Position, p1.Position, math.max(0.08, 0.07 * (ra + rb)), BARK_LINE))
			end
		end
	end
end
ST.twistedLog = twistedLog

-- a point on a quadratic curve
local function bez(p0: Vector3, p1: Vector3, p2: Vector3, t: number): Vector3
	local u = 1 - t
	return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
end

-- an arching prop root from `top` (at the trunk) to `foot` (in the mud): a quadratic arch that rises `rise` over the
-- straight line and bulges outward, 3 tapering 5-sided segments (r -> 0.55 r), a tone step each
local function archRoot(list: { BasePart }, rng: Random, top: Vector3, foot: Vector3, r: number, rise: number, color: Color3): Vector3
	local out = Vector3.new(foot.X - top.X, 0, foot.Z - top.Z)
	out = if out.Magnitude > 1e-3 then out.Unit else Vector3.xAxis
	local ctrl = (top + foot) / 2 + UP * rise + out * rise * 0.35
	local n = 3
	local prev = top
	for k = 1, n do
		local q = bez(top, ctrl, foot, k / n)
		local ra, rb = r * (1 - 0.45 * (k - 1) / n), r * (1 - 0.45 * k / n)
		local cf = H.frameY(prev, q - prev) * CFrame.Angles(0, rng:NextNumber(0, 1), 0)
		local len = (q - prev).Magnitude
		local c = tone(rng, color)
		table.insert(list, frustumN(5, ra, rb, -0.08, len + 0.08, cf, { c, scaled(c, 1.08), scaled(c, 0.9) }))
		prev = q
	end
	return ctrl
end

-- where an arch (top, ctrl, foot) comes down through height y (searched along the curve's lower half)
local function archAt(top: Vector3, ctrl: Vector3, foot: Vector3, y: number): Vector3
	local best, bp = math.huge, foot
	for k = 10, 40 do
		local p = bez(top, ctrl, foot, k / 40)
		local d = math.abs(p.Y - y)
		if d < best then
			best, bp = d, p
		end
	end
	return bp
end

-- a faceted leaf cluster: a flattened blob (a x b x c, 18 jittered planes) whose faces run from a lit top to a dark,
-- wet (teal-leaning) underside: a soft gradient by the face normal
local function leafTone(base: Color3): (Vector3) -> Color3
	return function(n: Vector3): Color3
		local t = (n.Y + 1) / 2
		local c = scaled(base, 0.62 + 0.5 * t)
		return c:Lerp(WET, 0.18 * (1 - t))
	end
end
ST.leafTone = leafTone

local function leafCluster(list: { BasePart }, rng: Random, frame: CFrame, a: number, b: number, c: number, base: Color3)
	blob(list, rng, frame, a, b, c, leafTone(base))
end

-- one folded leaf (a flat rhombus L long, W wide, with a mid-rib ridge: lighter and darker halves, a darker back)
-- from `at` along `dir`; `up` = roughly where its face looks
local function leaf(list: { BasePart }, at: Vector3, dir: Vector3, L: number, W: number, color: Color3, up: Vector3?)
	local y = dir.Unit
	local helper = up or UP
	if math.abs(helper.Unit:Dot(y)) > 0.95 then
		helper = Vector3.xAxis
	end
	local x = helper:Cross(y).Unit -- across the leaf
	local cf = CFrame.fromMatrix(at, x, y) -- its face normal = x:Cross(y)
	local T = math.max(0.06, W * 0.1)
	local wx, wy = W / 2, L * 0.38
	local planes = {}
	local function edge(ax: number, ay: number, bx: number, by: number)
		local nx, ny = by - ay, -(bx - ax)
		local len = math.sqrt(nx * nx + ny * ny)
		nx, ny = nx / len, ny / len
		local d = nx * ax + ny * ay
		if ny * wy > d then -- the leaf's middle must be inside
			nx, ny, d = -nx, -ny, -d
		end
		table.insert(planes, { nx, ny, 0, d, color })
	end
	edge(0, 0, wx, wy)
	edge(wx, wy, 0, L)
	edge(0, L, -wx, wy)
	edge(-wx, wy, 0, 0)
	local s = 0.75 * T / wx
	local nA = Vector3.new(s, 0, 1).Unit
	local nB = Vector3.new(-s, 0, 1).Unit
	table.insert(planes, { nA.X, 0, nA.Z, nA.Z * T, scaled(color, 1.1) })
	table.insert(planes, { nB.X, 0, nB.Z, nB.Z * T, scaled(color, 0.94) })
	table.insert(planes, { 0, 0, -1, 0, scaled(color, 0.78) })
	table.insert(list, H.convexSolid(Vector3.new(-wx - 0.1, -0.1, -0.1), Vector3.new(wx + 0.1, L + 0.1, T + 0.1), cf, color, planes))
end
ST.leaf = leaf

-- a leafy vine hanging from `top`, `len` long: a tapering stem (w -> 0.45 w) of swaying segments 1.2-1.5 long, a folded
-- leaf at every joint on alternating sides, drooping, and a leaf at the tip; flat: it sways and leafs in the XY plane only
-- (a thin curtain keeps its depth)
local function leafyVine(stem: { BasePart }, leaves: { BasePart }, rng: Random, top: Vector3, len: number, w: number, stemColor: Color3, flat: boolean?)
	local phase = rng:NextNumber(0, 6.28)
	local side = if flat then Vector3.xAxis else Vector3.new(math.cos(phase), 0, math.sin(phase))
	local fwd = if flat then Vector3.zero else side:Cross(UP)
	local p = top
	local y = 0
	local sgn = 1
	local k = 0
	while y < len - 0.05 do
		local step = math.min(rng:NextNumber(1.2, 1.5), len - y)
		if len - y - step < 0.5 then
			step = len - y
		end
		local yy = y + step
		local q = top - UP * yy + side * math.sin(yy * 0.8 + phase) * 0.22 + fwd * math.cos(yy * 0.6 + phase) * 0.12
		table.insert(stem, stemBar(p, q, w * (1 - 0.55 * yy / len), scaled(stemColor, 0.95 + 0.08 * math.sin(yy))))
		if yy < len - 0.2 then
			local d = (side * sgn + fwd * rng:NextNumber(-0.35, 0.35) - UP * 0.55).Unit
			local ls = 1 - 0.35 * yy / len
			leaf(leaves, q, d, 1.05 * ls, 0.62 * ls, LEAF_VINE[k % #LEAF_VINE + 1], if flat then Vector3.zAxis else side * sgn + UP)
		end
		sgn = -sgn
		k += 1
		p, y = q, yy
	end
	leaf(leaves, p, (-UP + side * 0.25).Unit, 0.9, 0.5, LEAF_VINE[2], if flat then Vector3.zAxis else side)
end
ST.leafyVine = leafyVine

-- a fern at `base`: n arching fronds (2 folded leaf segments each: up and out, then out and down)
local function fern(list: { BasePart }, rng: Random, base: Vector3, n: number, len: number)
	local a0 = rng:NextNumber(0, 6.28)
	for k = 1, n do
		local a = a0 + k * 2 * math.pi / n + rng:NextNumber(-0.25, 0.25)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local l = len * rng:NextNumber(0.8, 1.1)
		local d1 = (out * 0.75 + UP * 0.85).Unit
		local mid = base + d1 * l * 0.55
		local col = FERN[(k % #FERN) + 1]
		leaf(list, base, d1, l * 0.62, l * 0.34, col, UP)
		leaf(list, mid - d1 * 0.08, (out - UP * 0.35).Unit, l * 0.55, l * 0.28, scaled(col, 1.06), UP)
	end
end
ST.fern = fern

-- a mud collar where a root or trunk meets the ground: a low 7-sided cone, wet and dark at its foot
local function mudCollar(list: { BasePart }, rng: Random, at: Vector3, r: number)
	local cf = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	table.insert(list, frustumN(7, r * 1.6, r * 0.7, -0.2, 0.34, cf, { MUD, scaled(MUD, 1.08), MUD_WET, scaled(MUD, 0.95) }))
end
ST.mudCollar = mudCollar

-- a small moss cushion on a surface (frame Y = the surface normal): a dark swamp-moss blob with a lighter top
local function mossTone2(n: Vector3): Color3
	if n.Y > 0.6 then
		return MOSS_TOP
	elseif n.Y > -0.2 then
		return MOSS
	end
	return scaled(MOSS, 0.75)
end
local function mossCushion(list: { BasePart }, rng: Random, frame: CFrame, w: number)
	blob(list, rng, frame * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), w * 0.5, w * 0.17, w * 0.36, mossTone2, w * 0.05)
end
ST.mossCushion = mossCushion

-- a cheap ghost mushroom (5-sided bone stem, 6-sided cap #BFF5F0 with a paler underside) at `base`, cap width s
local GHOST_UNDER = rgb(143, 216, 208)
local function ghostMushroom(list: { BasePart }, rng: Random, base: Vector3, s: number)
	local h = s * rng:NextNumber(0.75, 1.1)
	local cf = CFrame.new(base) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2))
	table.insert(list, frustumN(5, 0.12 * s, 0.09 * s, -0.1, h, cf, { C.BONE, scaled(C.BONE, 0.92) }))
	table.insert(list, frustumN(6, 0.5 * s, 0.12 * s, h - 0.04, h + 0.32 * s, cf, { C.GHOST, scaled(C.GHOST, 0.94), GHOST_UNDER }))
end
local function ghostMushrooms(list: { BasePart }, rng: Random, base: Vector3, n: number, s: number)
	for k = 1, n do
		local off = if k == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5)) * s
		ghostMushroom(list, rng, base + off, s * (if k == 1 then 1 else rng:NextNumber(0.55, 0.8)))
	end
end
ST.ghostMushrooms = ghostMushrooms

-- a cheap hanging moss strand from `top`, `len` long: 4 tapering swaying segments in 2 swamp greens (or 2 tones of
-- `color`) and a wet drip
local function mossStrand(list: { BasePart }, rng: Random, top: Vector3, len: number, color: Color3?)
	local phase = rng:NextNumber(0, 6.28)
	local p = top
	for k = 1, 4 do
		local y = len * k / 4
		local q = top + Vector3.new(math.sin(y * 1.9 + phase) * 0.12, -y, math.cos(y * 1.5 + phase) * 0.12)
		local c = if color then (if k % 2 == 0 then color else scaled(color, 0.88)) elseif k % 2 == 0 then MOSS else MOSS_MID
		table.insert(list, stemBar(p, q, 0.26 - 0.04 * k, c))
		p = q
	end
	table.insert(list, piece("Part", Vector3.one * 0.14, CFrame.new(p - Vector3.new(0, 0.06, 0)) * CFrame.Angles(rad(45), rad(45), 0), scaled(WET, 1.3)))
end
ST.mossStrand = mossStrand

-- the point on a log row's axis at height y (clamped to its ends) and the outward unit direction from it towards `p`
local function onAxis(a: Vector3, b: Vector3, y: number): Vector3
	local t = math.clamp((y - a.Y) / math.max(b.Y - a.Y, 1e-3), 0, 1)
	return a:Lerp(b, t)
end

---------------------------------------------------------------------
-- 01 / 02 MANGROVES (kits MapAssets.Swamp.SwampTree_A: 5 root blocks + 2 trunk blocks (collide), 2 Canopy MeshParts,
-- 3 MossStrips, 26 x 35.5 x 26; SwampTree_B: 6 roots + 3 trunk blocks, 3 canopies, 4 strips, 35 x 42.1 x 30)
---------------------------------------------------------------------
-- From today's parts: the trunk blocks as one twisted bark trunk (8-sided segments turned 17 degrees each, bark grooves
-- that wind with it, a knuckle at each bend, 2 knots), today's roots as arching prop roots of different thicknesses
-- (today's top and foot, an arch over the line between; A has 5, B 6: the owner's 4-6), mud collars at the feet;
-- today's canopy discs as layered faceted leaf clusters (a centre cluster and a ring of 5-9 per disc, the disc's size,
-- place and colour, lit tops to dark wet undersides) with drooping leaf tips at the rims; today's moss
-- strips as leafy vines (place, length, colour); moss cushions on the roots and the trunk; ferns and ghost mushrooms at
-- the foot. Colliders: today's root and trunk blocks (invisible). Parts: Trunk (PrimaryPart), Bark, Roots, Mud,
-- Leaves, LeafTips, Vines, VineLeaves, Moss, Fern, Mush, Collision x7 / x9
-- opts (B's budget): maxRing = the most ring clusters per disc, tipMinW = leaf tips only on discs at least this wide,
-- ferns = how many ferns at the foot
local function mangrove(propId: string, kit: string, seed: number, far: boolean?, opts: any?): Model
	local o = opts or {}
	local m = Instance.new("Model")
	m.Name = propId
	local rng = Random.new(seed)
	H.setBevelSelf(true)
	local U: any = { Trunk = {}, Bark = {}, Roots = {}, Mud = {}, Leaves = {}, LeafTips = {}, Vines = {}, VineLeaves = {}, Moss = {}, Fern = {}, Mush = {} }
	local roots, trunks = {}, {}
	for _, r in ipairs(rows(kit, "Part")) do
		if r.collide then
			local a = ends(r)
			table.insert(if a.Y < 1 then roots else trunks, r)
		end
	end
	table.sort(trunks, function(p: any, q: any): boolean
		return p.cf.Y < q.cf.Y
	end)
	-- the trunk: one twisted log per trunk block, knuckles where they meet, 2 knots
	local axis = {}
	for i, r in ipairs(trunks) do
		local a, b, _, thick = ends(r)
		axis[i] = { a, b, thick }
		local r0 = thick / 2 * 0.98
		twistedLog(U.Trunk, if far then nil else U.Bark, rng, a, b, r0, r0 * 0.9, r.color, i * 0.6)
		if i > 1 then
			local pa = axis[i - 1]
			local j = (pa[2] + a) / 2
			local c = tone(rng, r.color)
			table.insert(U.Trunk, frustumN(8, thick * 0.5, thick * 0.5, -thick * 0.45, thick * 0.45, H.frameY(j, (b - pa[1]).Unit) * CFrame.Angles(0, rad(11), 0), { c, scaled(c, 1.06), scaled(c, 0.92) }))
		end
	end
	if not far then
		-- knots: 2 dark rounded bumps with a darker centre on the lower trunk
		local a, b, _, thick = axis[1][1], axis[1][2], 0, axis[1][3]
		for k = 1, 2 do
			local y = a.Y + (b.Y - a.Y) * (0.45 + 0.3 * k / 2)
			local c = onAxis(a, b, y)
			local ang = rng:NextNumber(0, 6.28)
			local out = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local at = c + out * thick * 0.48
			table.insert(U.Bark, frustumN(6, thick * 0.17, thick * 0.1, -0.1, thick * 0.08, H.frameY(at, out), { KNOT, scaled(KNOT, 1.1), scaled(KNOT, 0.9) }))
			table.insert(U.Bark, frustumN(6, thick * 0.07, thick * 0.05, thick * 0.07, thick * 0.1, H.frameY(at, out), { BARK_LINE }))
		end
	end
	-- the prop roots: today's top (at the trunk) to today's foot (in the mud), arched; different thicknesses
	if not far then
		local feet = {}
		local thickMul = { 1.15, 0.85, 1.0, 1.25, 0.9, 1.1, 0.95 }
		local trunkBase = axis[1][1]
		for i, r in ipairs(roots) do
			local foot, top, _, thick = ends(r)
			local rr = thick / 2 * thickMul[(i - 1) % #thickMul + 1]
			local ctrl = archRoot(U.Roots, rng, top, foot, rr, 2.6 + rng:NextNumber(0, 0.9), r.color)
			table.insert(feet, { foot = foot, top = top, ctrl = ctrl, r = rr, ang = math.atan2(foot.Z - trunkBase.Z, foot.X - trunkBase.X) })
			local g = archAt(top, ctrl, foot, 0.25)
			mudCollar(U.Mud, rng, Vector3.new(g.X, 0.12, g.Z), rr * 1.1)
		end
		table.sort(feet, function(p: any, q: any): boolean
			return p.ang < q.ang
		end)
		-- moss cushions on 3 root arches and on the trunk; ferns and ghost mushrooms at the foot
		for i = 1, math.min(3, #feet) do
			local f = feet[(i * 2) % #feet + 1]
			local p = bez(f.top, f.ctrl, f.foot, 0.45)
			mossCushion(U.Moss, rng, H.frameY(p + UP * f.r * 0.85, UP), 1.3 + f.r)
		end
		local a, b, thick = axis[1][1], axis[1][2], axis[1][3]
		for k = 1, 2 do
			local y = a.Y + (b.Y - a.Y) * (0.2 + 0.25 * k)
			local ang = rng:NextNumber(0, 6.28)
			local out = Vector3.new(math.cos(ang), 0.35, math.sin(ang)).Unit
			mossCushion(U.Moss, rng, H.frameY(onAxis(a, b, y) + out * thick * 0.47, out), thick * 0.75)
		end
		for i = 1, o.ferns or 2 do
			local f, g = feet[(i * 3) % #feet + 1], feet[(i * 3 + 1) % #feet + 1]
			local ang = (f.ang + g.ang) / 2 + (if math.abs(g.ang - f.ang) > math.pi then math.pi else 0)
			local at = Vector3.new(trunkBase.X + math.cos(ang) * (thick * 0.9 + 1.2), 0.1, trunkBase.Z + math.sin(ang) * (thick * 0.9 + 1.2))
			fern(U.Fern, rng, at, 4, 2.4 + rng:NextNumber(0, 0.5))
		end
		for i = 1, 2 do
			local f = feet[(i * 2 + 1) % #feet + 1]
			local p = bez(f.top, f.ctrl, f.foot, 0.78)
			ghostMushrooms(U.Mush, rng, p + UP * f.r * 0.55, 2, 0.6)
		end
	end
	-- the canopy: each of today's discs as a layer of faceted clusters (its size, place and colour)
	for _, r in ipairs(rows(kit, "Canopy")) do
		local W, Hh, D = r.size.X, r.size.Y, r.size.Z
		local c = r.cf.Position
		local base = scaled(r.color, 0.94)
		local ring = if far then math.max(5, math.round(W / 6)) else math.clamp(math.round(W / 4) + 1, 5, o.maxRing or 9)
		leafCluster(U.Leaves, rng, CFrame.new(c + UP * Hh * 0.1) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), W * 0.3, Hh * 0.3, D * 0.3, base)
		local a0 = rng:NextNumber(0, 6.28)
		for k = 1, ring do
			local ang = a0 + k * 2 * math.pi / ring + rng:NextNumber(-0.15, 0.15)
			local out = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local at = c + Vector3.new(out.X * W * 0.29, -Hh * 0.12 + rng:NextNumber(-0.06, 0.06) * Hh, out.Z * D * 0.29)
			local f = CFrame.lookAt(at, at + out) * CFrame.Angles(rad(-14), 0, 0) -- -Z outward, tipped down 14 degrees
			local col = if k % 3 == 0 then scaled(base, 1.06) elseif k % 3 == 1 then base else scaled(base, 0.93)
			leafCluster(U.Leaves, rng, f, W * 0.17, Hh * 0.21, math.max(W, D) * 0.2, col)
			if not far and W >= (o.tipMinW or 0) then
				-- 2 drooping leaf tips under the cluster's outer rim
				for j = 1, 2 do
					local s = (j - 1.5) * 0.32
					local side = UP:Cross(out).Unit
					local rim = c + out * (math.max(W, D) * 0.43) + side * s * W * 0.18 - UP * (Hh * 0.22)
					local d = (out * 0.6 - UP * 0.8 + side * s * 0.4).Unit
					leaf(U.LeafTips, rim, d, Hh * 0.32, Hh * 0.17, scaled(col, 0.9), out + UP)
				end
			end
		end
	end
	-- today's moss strips as leafy vines (top, length, colour), each from a small moss knot under the canopy
	if not far then
		for _, r in ipairs(rows(kit, "MossStrip")) do
			local top = r.cf.Position + UP * r.size.Y / 2
			table.insert(U.Vines, frustumN(6, 0.32, 0.18, -0.2, 0.25, CFrame.new(top), { MOSS, scaled(MOSS, 0.85), MOSS_TOP }))
			leafyVine(U.Vines, U.VineLeaves, rng, top, r.size.Y, 0.3, r.color)
		end
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	if not far then
		colliders(m, kit)
	end
	M.finish(m, propId, U, "Trunk")
	return m
end
ST.mangrove = mangrove

function ST.swamp_mangrove_a(): Model
	return mangrove("swamp_mangrove_a", "SwampTree_A", 20261101)
end

function ST.swamp_mangrove_b(): Model
	return mangrove("swamp_mangrove_b", "SwampTree_B", 20261102, false, { maxRing = 6, tipMinW = 25, ferns = 1 })
end

-- the far copies (Swamp_1.Decor.Backdrop, sunk 6.5 into the mud bed, greyed colours): the same trunk and canopy at
-- lower detail (no grooves, roots, tips, vines or foot details: none of today's far trees has them). No colliders in
-- the template: the 40 copies' trunk blocks differ from each other by up to 0.001 (their own scaling), so each copy
-- keeps its own 2 trunk blocks, invisible, in a "TrunkCollision" folder (MapPropKeep; ST.prepFarColliders() makes it
-- from the untagged before-stash ServerStorage._TreeOld_swamp_mangrove_a_far)
function ST.swamp_mangrove_a_far(): Model
	return mangrove("swamp_mangrove_a_far", "SwampTree_A_Far", 20261103, true)
end

---------------------------------------------------------------------
-- 03 DEAD TREE WITH THE FACE (kit MapAssets.Swamp.TwistedTree_A: 3 trunk blocks + 5 branch blocks (collide), 2 Eye
-- sockets, 2 Neon Pupils #FFE860, 2 Mouth blocks; 18.7 x 28.2 x 5.3; 34 copies: test, kit, Swamp_1 x2, Swamp_2 x20,
-- Swamp_3 x10; decor only: no script, prompt, tag or attribute)
---------------------------------------------------------------------
-- A gnarled 6-sided limb along a branch row (a -> b), 2 segments turned against each other, tapering to 0.55; 2-3 forked
-- twigs at its tip (4-sided, kept in the tree's flat XY plane so the depth stays) and one from its middle
local function gnarledBranch(list: { BasePart }, twigs: { BasePart }, rng: Random, a: Vector3, b: Vector3, r: number, color: Color3, maxX: number?)
	local mid = (a + b) / 2 + Vector3.new(rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.15, 0.25), 0)
	local c1, c2 = tone(rng, color), tone(rng, color)
	table.insert(list, frustumN(6, r, r * 0.8, -0.05, (mid - a).Magnitude + 0.1, H.frameY(a, mid - a) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), { c1, scaled(c1, 1.08), scaled(c1, 0.9) }))
	table.insert(list, frustumN(6, r * 0.8, r * 0.55, -0.1, (b - mid).Magnitude, H.frameY(mid, b - mid) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), { c2, scaled(c2, 1.08), scaled(c2, 0.9) }))
	local d = (b - mid).Unit
	local side = Vector3.new(-d.Y, d.X, 0)
	side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
	local function twig(from: Vector3, dir: Vector3, len: number, tr: number)
		-- (clipped at today's width: the tip stays within |x| <= maxX)
		if maxX and math.abs(dir.X) > 1e-3 and math.abs(from.X + dir.X * len) > maxX then
			len = math.max(0.3, (math.sign(dir.X) * maxX - from.X) / dir.X)
		end
		local cf = H.frameY(from, dir) * CFrame.Angles(0, rad(45), 0)
		local c = scaled(color, rng:NextNumber(0.9, 1.08))
		table.insert(twigs, frustumN(4, tr, tr * 0.2, -0.05, len, cf, { c, scaled(c, 0.88) }))
		return from + dir * len
	end
	local tr = math.max(0.12, r * 0.42)
	local t1 = twig(b - d * 0.1, (d + side * 0.6 + UP * 0.45).Unit, rng:NextNumber(1.2, 1.7), tr)
	twig(t1, (d + side * 1.1 + UP * 0.5).Unit, rng:NextNumber(0.5, 0.8), tr * 0.5)
	twig(b - d * 0.1, (d - side * 0.55 + UP * 0.4).Unit, rng:NextNumber(1.0, 1.5), tr * 0.9)
	twig(mid, (d * 0.5 + side * (if rng:NextNumber() < 0.5 then 1 else -1)).Unit, rng:NextNumber(0.9, 1.3), tr * 0.75)
end
ST.gnarledBranch = gnarledBranch

-- THE DEAD-TREE RECIPE (round 2, shared by the face tree and the wooden gate's 2 dead trees): a tapered trunk along the
-- control points P (radius R[i] at each), each span in `sub` 8-sided segments with a slight wobble and a twist,
-- raised bark ridges (6 a segment, lighter) and dark grooves between them following the twist (`skip(dir, y)`: leave a
-- sector bare, e.g. for a face), a knuckle at each inner control point. Returns the segment points.
local function deadTrunk(list: { BasePart }, ridges: { BasePart }, rng: Random, P: { Vector3 }, Rr: { number }, color: Color3, sub: number, skip: ((Vector3, number) -> boolean)?): { Vector3 }
	local pts, rad0 = {}, {}
	for i = 1, #P - 1 do
		for s = 0, sub - 1 do
			local t = s / sub
			local p = P[i]:Lerp(P[i + 1], t)
			local inner = not (i == 1 and s == 0)
			if inner and s > 0 then
				p += Vector3.new(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.1, 0.1))
			end
			table.insert(pts, p)
			table.insert(rad0, Rr[i] + (Rr[i + 1] - Rr[i]) * t)
		end
	end
	table.insert(pts, P[#P])
	table.insert(rad0, Rr[#Rr])
	for k = 1, #pts - 1 do
		local p, q = pts[k], pts[k + 1]
		local r0, r1 = rad0[k], rad0[k + 1]
		local frame = H.frameY(p, q - p) * CFrame.Angles(0, k * 0.3, 0)
		local c = tone(rng, color)
		table.insert(list, frustumN(8, r0, r1, -0.06, (q - p).Magnitude + 0.06, frame, { c, scaled(c, 1.08), scaled(c, 0.9) }))
		for j = 0, 5 do
			local f = frame * CFrame.Angles(0, j * math.pi / 3 + 0.2, 0)
			local d0 = f.XVector
			local y = (p.Y + q.Y) / 2
			if skip and skip(d0, y) then
				continue
			end
			local isRidge = j % 2 == 0
			local a = p + d0 * (r0 + (if isRidge then 0.04 else 0.01))
			local b = q + d0 * (r1 + (if isRidge then 0.04 else 0.01))
			table.insert(ridges, stemBar(a, b, if isRidge then math.max(0.12, r0 * 0.14) else 0.1, if isRidge then scaled(c, 1.18) else BARK_LINE))
		end
	end
	for i = 2, #P - 1 do
		local c = tone(rng, color)
		blob(list, rng, CFrame.new(P[i]), Rr[i] * 1.08, Rr[i] * 0.5, Rr[i] * 1.06, function(n: Vector3): Color3
			return scaled(c, 0.9 + 0.15 * math.max(n.Y, 0))
		end)
	end
	return pts
end
ST.deadTrunk = deadTrunk

-- a finer dead branch (round 2): a gnarled limb at 70 % of today's thickness with its forked twigs, and 2 more small
-- twigs along it
local function fineBranch(list: { BasePart }, twigs: { BasePart }, rng: Random, a: Vector3, b: Vector3, r: number, color: Color3, maxX: number?)
	gnarledBranch(list, twigs, rng, a, b, r * 0.7, color, maxX)
	local d = (b - a).Unit
	local side = Vector3.new(-d.Y, d.X, 0)
	side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
	for k, t in ipairs({ 0.35, 0.7 }) do
		local from = a:Lerp(b, t)
		local dir = (d * 0.6 + side * (if k == 1 then 1 else -1) * 0.7 + UP * 0.5).Unit
		local len = rng:NextNumber(0.8, 1.3)
		if maxX and math.abs(dir.X) > 1e-3 and math.abs(from.X + dir.X * len) > maxX then
			len = math.max(0.3, (math.sign(dir.X) * maxX - from.X) / dir.X)
		end
		table.insert(twigs, frustumN(4, math.max(0.1, r * 0.25), 0.03, -0.05, len, H.frameY(from, dir) * CFrame.Angles(0, rad(45), 0), { scaled(color, 1.05), scaled(color, 0.88) }))
	end
end
ST.fineBranch = fineBranch

-- Round 2 (the owner: "a carved face integrated in the trunk ... more spooky-cute than ugly"): the 3 trunk blocks as
-- one tapered bark trunk (THE DEAD-TREE RECIPE: 8-sided segments, ridges and grooves, knuckles; the face's sector left
-- bare on a flat bark face plate); today's 5 branches as finer gnarled limbs with more twigs, moss cushions and hanging
-- moss; THE FACE: today's 2 eye sockets, 2 Neon pupils (the glow) and the 2 crooked mouth blocks kept exactly, carved
-- round: deep sockets (a dark recess and a shadow ring), heavy rounded brow ridges, cheek knobs, a round knot nose, lips
-- with 3 pale teeth, bark folds framing the face, a moss beard under the chin; 2 roots flaring left and right, 2 at the
-- back and 2 short root toes in front, mud collars. Colliders: today's 8 blocks (invisible). Parts: Trunk (PrimaryPart),
-- Bark, Branches, Twigs, FaceCarve, Teeth, Roots, Mud, Moss, Eye x2, Pupil x2, Mouth x2, Collision x8
function ST.swamp_face_tree(): Model
	local kit = "TwistedTree_A"
	local m = Instance.new("Model")
	m.Name = "swamp_face_tree"
	local rng = Random.new(20261104)
	H.setBevelSelf(true)
	local U: any = { Trunk = {}, Bark = {}, Branches = {}, Twigs = {}, FaceCarve = {}, Teeth = {}, Roots = {}, Mud = {}, Moss = {} }
	local trunks, branches = {}, {}
	for _, r in ipairs(rows(kit, "Part")) do
		local _, _, _, thick = ends(r)
		table.insert(if thick >= 2.4 then trunks else branches, r)
	end
	table.sort(trunks, function(p: any, q: any): boolean
		return p.cf.Y < q.cf.Y
	end)
	local axis = {}
	for i, r in ipairs(trunks) do
		local a, b, _, thick = ends(r)
		axis[i] = { a, b, thick }
	end
	local wood = trunks[1].color
	local eyes = rows(kit, "Eye")
	local mouth = rows(kit, "Mouth")
	local faceTop = eyes[1].cf.Y + 1.9
	local faceBot = mouth[1].cf.Y - 1.4
	-- the tapered trunk through today's 3 blocks
	local P = {
		Vector3.new(axis[1][1].X, -0.3, axis[1][1].Z),
		(axis[1][2] + axis[2][1]) / 2,
		(axis[2][2] + axis[3][1]) / 2,
		axis[3][2],
	}
	local Rr = { axis[1][3] / 2 * 0.95, axis[2][3] / 2 * 1.02, axis[3][3] / 2 * 1.02, axis[3][3] / 2 * 0.55 }
	deadTrunk(U.Trunk, U.Bark, rng, P, Rr, wood, 3, function(d: Vector3, y: number): boolean
		return d.Z < -0.55 and y > faceBot - 0.5 and y < faceTop + 0.3
	end)
	-- the face plate: a flat bark face over the front of the lowest block
	local fz = eyes[1].cf.Z - 0.05 -- the face plate's front: today's sockets stand 0.25 proud of it
	table.insert(U.FaceCarve, H.chamfered(Vector3.new(axis[1][3] * 0.86, faceTop - faceBot, 0.6), CFrame.new(0.25, (faceTop + faceBot) / 2, fz + 0.3), scaled(wood, 1.04), { "vertical", "topFrontBack", "bottomFrontBack" }, 0.25))
	-- bark folds framing the face
	for _, sx in ipairs({ -1, 1 }) do
		local pts = {}
		for k = 0, 4 do
			local t = k / 4
			local y = faceTop - 0.2 - t * (faceTop - faceBot - 0.4)
			local x = 0.25 + sx * (axis[1][3] * 0.43 + 0.25 * math.sin(t * math.pi))
			table.insert(pts, Vector3.new(x, y, fz + 0.08 - 0.15 * math.sin(t * math.pi)))
		end
		for i = 1, #pts - 1 do
			table.insert(U.FaceCarve, stemBar(pts[i], pts[i + 1], 0.32, scaled(wood, 1.16)))
		end
	end
	-- the branches: finer gnarled limbs with more twigs; moss cushions, hanging moss
	local maxX = 0
	for _, r in ipairs(rows(kit, "Part")) do
		local a, b = ends(r)
		maxX = math.max(maxX, math.abs(a.X), math.abs(b.X))
	end
	maxX += 0.6
	for i, r in ipairs(branches) do
		local a, b, _, thick = ends(r)
		fineBranch(U.Branches, U.Twigs, rng, a, b, thick / 2 * 0.98, r.color, maxX)
		if i <= 3 then
			mossCushion(U.Moss, rng, H.frameY(a + (b - a) * 0.12 + UP * thick * 0.35, UP), 1.0)
			mossStrand(U.Moss, rng, a + (b - a) * 0.55 - UP * thick * 0.3, rng:NextNumber(1.6, 2.6))
		end
	end
	-- THE FACE: today's parts exactly, and the carving round them
	for _, r in ipairs(eyes) do
		exactRow(m, r)
		local x, y = r.cf.X, r.cf.Y
		local inward = if x < 0.35 then 1 else -1
		-- the deep socket: a dark recess larger than today's socket and a shadow ring round it
		table.insert(U.FaceCarve, piece("Part", Vector3.new(1.6, 1.8, 0.12), CFrame.new(x, y, fz - 0.02) * CFrame.Angles(0, 0, rad(-inward * 22)), rgb(18, 13, 11)))
		table.insert(U.FaceCarve, frustumN(8, 1.1, 1.05, -0.05, 0.08, H.frameY(Vector3.new(x, y, fz - 0.04), -Vector3.zAxis), { scaled(wood, 0.62) }))
		-- the heavy rounded brow: an arc of 4 bark lumps over the socket
		for k = 0, 3 do
			local a = rad(150 - k * 40)
			local p = Vector3.new(x + math.cos(a) * 0.85, y + 0.55 + math.sin(a) * 0.45, fz - 0.28)
			blob(U.FaceCarve, rng, CFrame.new(p), 0.36, 0.26, 0.26, function(n: Vector3): Color3
				return scaled(wood, 1.05 + 0.15 * math.max(n.Y, 0))
			end)
		end
		-- a cheek knob under the eye
		blob(U.FaceCarve, rng, CFrame.new(x, y - 1.05, fz - 0.2), 0.5, 0.34, 0.26, function(n: Vector3): Color3
			return scaled(wood, 0.98 + 0.15 * math.max(n.Y, 0))
		end)
	end
	for _, r in ipairs(rows(kit, "Pupil")) do
		exactRow(m, r)
	end
	for _, r in ipairs(mouth) do
		exactRow(m, r)
	end
	do
		local mm = mouth[1]
		local cf = CFrame.new(mm.cf.X, mm.cf.Y, fz - 0.05) * (mm.cf - mm.cf.Position)
		local lipC = scaled(wood, 1.08)
		table.insert(U.FaceCarve, H.chamfered(Vector3.new(mm.size.X + 0.3, 0.26, 0.4), cf * CFrame.new(0.1, mm.size.Y / 2 + 0.12, -0.12), lipC, { "topFrontBack" }, 0.08))
		table.insert(U.FaceCarve, H.chamfered(Vector3.new(mm.size.X - 0.2, 0.3, 0.42), cf * CFrame.new(0.15, -mm.size.Y / 2 - 0.14, -0.12), scaled(lipC, 0.95), { "bottomFrontBack" }, 0.08))
		-- 3 pale teeth hanging from the upper lip (a crooked grin)
		for k, tx in ipairs({ -0.75, 0.05, 0.7 }) do
			local tcf = cf * CFrame.new(tx, mm.size.Y / 2 - 0.12, -0.33) * CFrame.Angles(0, 0, rad((k - 2) * 8))
			table.insert(U.Teeth, piece("WedgePart", Vector3.new(0.26, 0.34, 0.14), tcf * CFrame.Angles(rad(180), 0, 0), rgb(214, 196, 150)))
		end
		-- the round knot nose between the eyes and the mouth
		local nx = (eyes[1].cf.X + eyes[2].cf.X) / 2 + 0.05
		local ny = (eyes[1].cf.Y + mm.cf.Y) / 2 + 0.1
		blob(U.FaceCarve, rng, CFrame.new(nx, ny, fz - 0.35), 0.42, 0.38, 0.36, function(n: Vector3): Color3
			return scaled(wood, 1.02 + 0.18 * math.max(n.Y, 0))
		end)
		table.insert(U.FaceCarve, frustumN(6, 0.14, 0.1, 0.3, 0.42, H.frameY(Vector3.new(nx, ny - 0.05, fz - 0.35), Vector3.new(0, -0.3, -1).Unit), { BARK_LINE }))
		-- the moss beard under the chin
		for k = 0, 4 do
			local bx = mm.cf.X - 1.0 + k * 0.5
			mossStrand(U.Moss, rng, Vector3.new(bx, mm.cf.Y - mm.size.Y / 2 - 0.3, fz - 0.3), rng:NextNumber(0.8, 1.5), MOSS_MID)
		end
	end
	-- roots: 2 flaring left and right, 2 small flares at the back, 2 short root toes in front; mud collars
	do
		local a, thick = axis[1][1], axis[1][3]
		local base = Vector3.new(a.X, 0, a.Z)
		for _, e in ipairs({ { Vector3.new(-1, 0, 0.15), 4.6, 1.0 }, { Vector3.new(1, 0, -0.1), 4.4, 0.95 }, { Vector3.new(-0.45, 0, 1), 2.55, 0.6 }, { Vector3.new(0.5, 0, 1), 2.5, 0.55 }, { Vector3.new(-0.55, 0, -1), 2.75, 0.5 }, { Vector3.new(0.6, 0, -1), 2.7, 0.45 } }) do
			local d = e[1].Unit
			local top = base + d * thick * 0.3 + UP * (if d.Z < -0.5 then 1.2 else 2.0)
			local foot = base + Vector3.new(d.X * e[2], -0.5, math.clamp(d.Z * e[2], -2.9, 2.55))
			local ctrl = archRoot(U.Roots, rng, top, foot, e[3] * 0.62, 0.7, wood)
			local g = archAt(top, ctrl, foot, 0.3)
			mudCollar(U.Mud, rng, Vector3.new(g.X, 0.12, math.clamp(g.Z, -2.6, 2.3)), e[3] * 0.55)
		end
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	colliders(m, kit)
	M.finish(m, "swamp_face_tree", U, "Trunk")
	return m
end

---------------------------------------------------------------------
-- 04 TWISTED DEAD TREE WITH THE HOLLOW (kit MapAssets.Swamp.TwistedTree_C: 3 trunk blocks + 4 branch blocks (collide),
-- the dark Knot = the hollow, 1 MossStrip; 17.6 x 22.1 x 5.3; 47 copies: test, kit, Swamp_1 x8, Swamp_2 x29, Swamp_3 x7,
-- BossArenas.Swamp x1; decor only)
---------------------------------------------------------------------
-- From today's parts: the 3 trunk blocks as one bark trunk (the lowest untwisted with a flat front for the hollow, the
-- upper ones twisted with winding grooves, knuckles at the bends); today's 4 branches as gnarled limbs with forked twigs
-- (clipped at today's width); THE HOLLOW: today's dark Knot kept exactly, a deeper black shadow behind it and a bevelled
-- bark lip round it (4 rounded pieces, the lower one a sill) so it reads as a hole with depth; today's moss strip as a
-- leafy hanging vine (place, length, colour); a moss cushion and a strand on a branch; 2 roots flaring left and right
-- and one at the back (the depth stays 5.3), mud collars. Colliders: today's 7 blocks (invisible). Parts: Trunk
-- (PrimaryPart), Bark, Branches, Twigs, Hollow, Vines, VineLeaves, Roots, Mud, Moss, Knot, Collision x7
function ST.swamp_hollow_tree(): Model
	local kit = "TwistedTree_C"
	local m = Instance.new("Model")
	m.Name = "swamp_hollow_tree"
	local rng = Random.new(20261105)
	H.setBevelSelf(true)
	local U: any = { Trunk = {}, Bark = {}, Branches = {}, Twigs = {}, Hollow = {}, Vines = {}, VineLeaves = {}, Roots = {}, Mud = {}, Moss = {} }
	local trunks, branches = {}, {}
	local maxX = 0
	for _, r in ipairs(rows(kit, "Part")) do
		local a, b, _, thick = ends(r)
		table.insert(if thick >= 1.9 then trunks else branches, r)
		maxX = math.max(maxX, math.abs(a.X), math.abs(b.X))
	end
	maxX += 0.6
	table.sort(trunks, function(p: any, q: any): boolean
		return p.cf.Y < q.cf.Y
	end)
	local axis = {}
	for i, r in ipairs(trunks) do
		local a, b, _, thick = ends(r)
		axis[i] = { a, b, thick }
		local r0 = thick / 2 * 0.98
		if i == 1 then
			twistedLog(U.Trunk, nil, rng, a, b, r0, r0 * 0.97, r.color, rad(22.5), 0)
		else
			twistedLog(U.Trunk, U.Bark, rng, a, b, r0, r0 * 0.88, r.color, i * 0.9)
			local pa = axis[i - 1]
			local j = (pa[2] + a) / 2
			local c = tone(rng, r.color)
			table.insert(U.Trunk, frustumN(8, thick * 0.52, thick * 0.5, -thick * 0.45, thick * 0.45, H.frameY(j, (b - pa[1]).Unit) * CFrame.Angles(0, rad(11), 0), { c, scaled(c, 1.06), scaled(c, 0.92) }))
		end
	end
	-- grooves on the sides and the back of the lowest block
	do
		local a, b, thick = axis[1][1], axis[1][2], axis[1][3]
		for _, x in ipairs({ -thick * 0.5, thick * 0.5 }) do
			table.insert(U.Bark, H.bar(Vector3.new(a.X + x, a.Y + 1.2, 0.2), Vector3.new(b.X + x, b.Y - 0.6, 0.45), 0.13, BARK_LINE))
		end
		for k = -1, 1, 2 do
			table.insert(U.Bark, H.bar(Vector3.new(a.X + k * 0.8, a.Y + 1.2, thick * 0.5), Vector3.new(b.X + k * 0.8 + 0.15, b.Y - 0.6, thick * 0.5), 0.13, BARK_LINE))
		end
	end
	-- the branches; moss on the first, a strand
	for i, r in ipairs(branches) do
		local a, b, _, thick = ends(r)
		gnarledBranch(U.Branches, U.Twigs, rng, a, b, thick / 2 * 0.98, r.color, maxX)
		if i == 1 then
			mossCushion(U.Moss, rng, H.frameY(a + (b - a) * 0.2 + UP * thick * 0.45, UP), 1.1)
			mossStrand(U.Moss, rng, a + (b - a) * 0.45 - UP * thick * 0.4, rng:NextNumber(1.4, 2.0))
		end
	end
	-- THE HOLLOW: today's Knot exactly; a deeper shadow behind it; a bevelled bark lip round it
	for _, r in ipairs(rows(kit, "Knot")) do
		exactRow(m, r)
		local c = r.cf.Position
		local w, h = r.size.X, r.size.Y
		local front = c.Z - r.size.Z / 2 -- the knot's front face
		table.insert(U.Hollow, piece("Part", Vector3.new(w + 0.16, h + 0.16, 0.1), CFrame.new(c.X, c.Y, front + 0.32), rgb(12, 9, 8)))
		local lipC = scaled(trunks[1].color, 1.12)
		local t = 0.34
		table.insert(U.Hollow, H.chamfered(Vector3.new(w + 2 * t, t, 0.42), CFrame.new(c.X, c.Y + h / 2 + t / 2 - 0.04, front + 0.08), lipC, { "topFrontBack", "frontFace" }, 0.1))
		table.insert(U.Hollow, H.chamfered(Vector3.new(w + 2 * t + 0.2, t + 0.1, 0.5), CFrame.new(c.X + 0.05, c.Y - h / 2 - t / 2 + 0.02, front + 0.06), scaled(lipC, 0.95), { "topFrontBack", "frontFace" }, 0.1))
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(U.Hollow, H.chamfered(Vector3.new(t, h + 0.1, 0.42), CFrame.new(c.X + sx * (w / 2 + t / 2 - 0.04), c.Y, front + 0.08) * CFrame.Angles(0, 0, rad(sx * 3)), scaled(lipC, if sx < 0 then 1.04 else 0.96), { "frontFace" }, 0.1))
		end
	end
	-- today's moss strip as a leafy vine
	for _, r in ipairs(rows(kit, "MossStrip")) do
		local top = r.cf.Position + UP * r.size.Y / 2
		table.insert(U.Vines, frustumN(6, 0.3, 0.16, -0.2, 0.22, CFrame.new(top), { MOSS, scaled(MOSS, 0.85), MOSS_TOP }))
		leafyVine(U.Vines, U.VineLeaves, rng, top, r.size.Y, 0.28, r.color)
	end
	-- roots: left, right and back; mud collars
	do
		local a, thick = axis[1][1], axis[1][3]
		local base = Vector3.new(a.X, 0, a.Z)
		for _, e in ipairs({ { Vector3.new(-1, 0, 0.2), 4.0, 0.95 }, { Vector3.new(1, 0, -0.15), 3.8, 0.9 }, { Vector3.new(0.3, 0, 1), 2.45, 0.6 } }) do
			local d = e[1].Unit
			local top = base + d * thick * 0.3 + UP * 1.8
			local foot = base + Vector3.new(d.X * e[2], -0.5, math.clamp(d.Z * e[2], -2.45, 2.45))
			local ctrl = archRoot(U.Roots, rng, top, foot, e[3] * 0.6, 0.6, trunks[1].color)
			local g = archAt(top, ctrl, foot, 0.3)
			mudCollar(U.Mud, rng, Vector3.new(g.X, 0.12, math.clamp(g.Z, -2.2, 2.2)), e[3] * 0.5)
		end
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	colliders(m, kit)
	M.finish(m, "swamp_hollow_tree", U, "Trunk")
	return m
end

---------------------------------------------------------------------
-- 05 HANGING VINE CURTAIN (kit MapAssets.Swamp.Hanging_Moss_A: a bar 6.5 x 0.5 x 0.8 and 5 strips 0.9 wide, 4-8 long,
-- tops at 8; nothing collides, is queried or touched; attribute Height = 8; 36 copies at scale 1 / 1.6 / 2 / 2.5: test,
-- kit, Swamp_1-4 Landmark / Dressing x25, BossArenas.Swamp x9; static: no PropFX sway today, so none here)
---------------------------------------------------------------------
-- From today's parts: the bar as a slightly bowed bark branch (2 6-sided segments, 2 moss pads on top) with 2 rope ties
-- (a wrap and a short hanging end); today's 5 strips (place, length, tone) as a curtain: the 3 longest as flat leafy
-- vines, the 2 shortest as moss strands; everything stays in the strip plane (depth 0.8). Nothing collides (as today).
-- Parts: Branch (PrimaryPart), Rope, Moss, Vines, VineLeaves
local ROPE = rgb(150, 122, 80) -- #967A50
function ST.swamp_vine_curtain(): Model
	local kit = "Hanging_Moss_A"
	local m = Instance.new("Model")
	m.Name = "swamp_vine_curtain"
	local rng = Random.new(20261106)
	H.setBevelSelf(true)
	local U: any = { Branch = {}, Rope = {}, Moss = {}, Vines = {}, VineLeaves = {} }
	local rs = rows(kit, "Part")
	local bar = rs[1]
	for _, r in ipairs(rs) do
		if r.size.X > bar.size.X then
			bar = r
		end
	end
	local L = bar.size.X
	local c = bar.cf.Position
	local r0 = bar.size.Y * 0.6
	local wood = rgb(78, 58, 44) -- #4E3A2C the swamp bark
	local a0, a1, a2 = c - Vector3.new(L / 2, 0.02, 0), c + Vector3.new(0.3, 0.05, 0), c + Vector3.new(L / 2, -0.03, 0)
	local c1, c2 = tone(rng, wood), tone(rng, wood)
	table.insert(U.Branch, frustumN(6, r0, r0 * 0.92, 0, (a1 - a0).Magnitude + 0.05, H.frameY(a0, a1 - a0), { c1, scaled(c1, 1.08), scaled(c1, 0.9) }))
	table.insert(U.Branch, frustumN(6, r0 * 0.92, r0 * 0.8, -0.05, (a2 - a1).Magnitude, H.frameY(a1, a2 - a1) * CFrame.Angles(0, rad(20), 0), { c2, scaled(c2, 1.08), scaled(c2, 0.9) }))
	-- moss on top in today's bar colour
	for _, x in ipairs({ -L * 0.22, L * 0.25 }) do
		local mc = scaled(bar.color, 1.05)
		table.insert(U.Moss, frustumN(6, 0.36, 0.22, r0 * 0.55, r0 * 0.55 + 0.2, CFrame.new(c + Vector3.new(x, 0, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), { mc, scaled(mc, 0.86), scaled(mc, 0.95) }))
	end
	-- 2 rope ties
	for _, x in ipairs({ -L * 0.36, L * 0.38 }) do
		local p = c + Vector3.new(x, 0, 0)
		table.insert(U.Rope, frustumN(8, r0 + 0.06, r0 + 0.06, -0.11, 0.11, H.frameY(p, Vector3.xAxis), { ROPE, scaled(ROPE, 0.9) }))
		table.insert(U.Rope, stemBar(p - Vector3.new(0, r0 + 0.04, 0), p + Vector3.new(0.12, -r0 - 0.5, 0), 0.09, scaled(ROPE, 0.94)))
	end
	-- the curtain: today's strips (place, length, tone)
	local strips = {}
	for _, r in ipairs(rs) do
		if r ~= bar then
			table.insert(strips, r)
		end
	end
	table.sort(strips, function(p: any, q: any): boolean
		return p.size.Y > q.size.Y
	end)
	for i, r in ipairs(strips) do
		local bottom = r.cf.Y - r.size.Y / 2
		local top = Vector3.new(r.cf.X, c.Y - r0 * 0.7, r.cf.Z * 0.6)
		local len = top.Y - bottom
		if i <= 3 then
			-- (0.75 shorter: the tip leaf ends at today's strip end)
			leafyVine(U.Vines, U.VineLeaves, rng, top, len - 0.75, 0.3, r.color, true)
		else
			mossStrand(U.Moss, rng, top, len, r.color)
		end
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, "swamp_vine_curtain", U, "Branch")
	m.PrimaryPart.CanQuery = false
	return m
end

---------------------------------------------------------------------
-- 06 HOLLOW MAGIC STUMP (kit MapAssets.Swamp.Rotten_Trunk_Glow: the Trunk mesh 6349136797 (Hull, collides), 4 Root
-- blocks + 2 branch Parts (collide), 5 Neon Sap strips + the Neon SapPool #8CFF5A (the yellow runes), 2 Neon crystal
-- Parts #78FFD2; 18.6 x 25.3 x 18.6; 4 copies: test, kit, BossArenas.Swamp x2 (one with a PointLight under its SapPool,
-- kept on that copy by an invisible "SapLight" part, MapPropKeep: ST.prepStumpLight()); no prompt or script)
---------------------------------------------------------------------
-- the stump mesh's surface, measured once by rays at a far-away probe clone: surface(angle, y) -> point, normal (kit
-- space; nil if missed) and top(x, z) -> the height of its top cap
local function meshProbe(r: any): ((number, number) -> (Vector3?, Vector3?), (number, number) -> number?)
	local OFF = Vector3.new(0, 6000, 0)
	local p = rowPart(r)
	p.CFrame = CFrame.new(OFF) * r.cf
	p.Parent = workspace
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { p }
	local function surface(a: number, y: number): (Vector3?, Vector3?)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local hit = workspace:Raycast(OFF + Vector3.new(0, y, 0) + d * 20, -d * 20, rp)
		if not hit then
			return nil, nil
		end
		return hit.Position - OFF, hit.Normal
	end
	local function top(x: number, z: number): number?
		local hit = workspace:Raycast(OFF + Vector3.new(x, 40, z), Vector3.new(0, -50, 0), rp)
		return if hit then hit.Position.Y - OFF.Y else nil
	end
	-- every query is made before the probe goes: build tables up front
	local S, T = {}, {}
	for k = 0, 47 do
		S[k] = {}
		for yi = 0, 40 do
			local pos, n = surface(k * math.pi / 24, yi * 0.5)
			S[k][yi] = if pos then { pos, n } else false
		end
	end
	for xi = -16, 16 do
		T[xi] = {}
		for zi = -16, 16 do
			T[xi][zi] = top(xi * 0.5, zi * 0.5) or false
		end
	end
	p:Destroy()
	local function surfaceAt(a: number, y: number): (Vector3?, Vector3?)
		local k = math.round(a / (math.pi / 24)) % 48
		local yi = math.clamp(math.round(y / 0.5), 0, 40)
		local e = S[k][yi]
		if not e then
			return nil, nil
		end
		return e[1], e[2]
	end
	local function topAt(x: number, z: number): number?
		local e = T[math.clamp(math.round(x / 0.5), -16, 16)][math.clamp(math.round(z / 0.5), -16, 16)]
		return if e then e else nil
	end
	return surfaceAt, topAt
end

-- Round 2 (the owner: "currently a plain dark cylinder"): the stump is now a faceted bark trunk of 22 vertical staves
-- (ridges and grooves, every other stave proud) on a radius profile flaring into buttresses at the foot and tapering to
-- the top, a dark core inside; today's trunk mesh only collides (its Hull copy, invisible). THE RUNES: today's 5 Neon
-- Sap strips kept exactly, each now CARVED into the bark: set in a dark channel between 2 raised bark ridges that follow
-- the strip's own lean, with 2 short Neon rune ticks cut into the ridges; the SapPool kept exactly with small glowing
-- toadstools round it (a lantern-like glow at the foot). THE HOLLOW TOP: a rough rim of bark lumps, a glowing toxic
-- liquid (Neon, the sap's colour) with dark swirl arcs, a faint pale mist over it. Today's 2 crystals kept exactly with
-- shards; today's 4 roots as arching buttress roots with mud collars; today's 2 branches as curved dead limbs with twigs;
-- 3 knots, moss, ghost mushrooms at the foot. Colliders: today's Trunk (mesh, Hull), 4 roots and 2 branches
-- (invisible). Parts: Roots (PrimaryPart), Bark, Rim, Liquid, Swirl, Mist, Runes, Grooves, Crystals, Branches, Twigs,
-- Mud, Moss, Mush, Glow, Sap x5, SapPool, Part x2 (crystals), Collision x7
function ST.swamp_magic_stump(): Model
	local kit = "Rotten_Trunk_Glow"
	local m = Instance.new("Model")
	m.Name = "swamp_magic_stump"
	local rng = Random.new(20261107)
	H.setBevelSelf(true)
	local U: any = { Roots = {}, Bark = {}, Rim = {}, Liquid = {}, Swirl = {}, Mist = {}, Runes = {}, Grooves = {}, Crystals = {}, Branches = {}, Twigs = {}, Mud = {}, Moss = {}, Mush = {}, Glow = {} }
	local trunk = rows(kit, "Trunk")[1]
	local wood = trunk.color
	local TOP = trunk.cf.Y + trunk.size.X / 2 - 0.3
	-- the radius profile: buttress flare at the foot, a gentle taper to the top
	local function R(y: number): number
		if y <= 2.6 then
			local t = math.clamp(y / 2.6, 0, 1)
			return 7.4 + (5.95 - 7.4) * (1 - (1 - t) * (1 - t))
		elseif y <= 11 then
			return 5.95 + (5.55 - 5.95) * (y - 2.6) / 8.4
		end
		return 5.55 + (5.05 - 5.55) * (y - 11) / (TOP - 11)
	end
	-- the bark: 22 staves in 6 segments each, every other one proud (a ridge), 3 tones; a dark core
	local N = 22
	local ys = { 0, 1.2, 2.6, 6.5, 11, 15, TOP }
	local prevTone = nil
	for i = 0, N - 1 do
		local a = (i + 0.5) * 2 * math.pi / N
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local ridge = if i % 2 == 0 then 0.22 else 0
		local ti = H.toneIndex(rng, prevTone)
		prevTone = ti
		local base = scaled(wood, ({ 1.06, 0.96, 0.88 })[ti] * (if ridge > 0 then 1.06 else 0.9))
		for k = 1, #ys - 1 do
			local y0, y1 = ys[k], ys[k + 1]
			local p0 = d * (R(y0) + ridge - 0.35) + Vector3.new(0, y0, 0)
			local p1 = d * (R(y1) + ridge - 0.35) + Vector3.new(0, y1, 0)
			local up = (p1 - p0).Unit
			local out = (d - up * d:Dot(up)).Unit
			local x = up:Cross(out)
			local w = 2 * (R((y0 + y1) / 2) + ridge) * math.tan(math.pi / N) + 0.08
			table.insert(U.Bark, piece("Part", Vector3.new(w, (p1 - p0).Magnitude + 0.04, 0.7), CFrame.fromMatrix((p0 + p1) / 2, x, up), scaled(base, 0.96 + 0.08 * k / #ys)))
		end
	end
	table.insert(U.Bark, frustumN(12, R(11) - 0.5, R(TOP) - 0.6, 0.2, TOP - 0.2, CFrame.new(), { BARK_LINE }))
	-- 3 knots on the bark
	for k = 1, 3 do
		local a = k * 2.1 + 0.4
		local y = 4 + k * 4
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = d * (R(y) + 0.2) + Vector3.new(0, y, 0)
		table.insert(U.Bark, frustumN(6, 0.45, 0.28, -0.1, 0.24, H.frameY(p, d), { KNOT, scaled(KNOT, 1.1), scaled(KNOT, 0.9) }))
		table.insert(U.Bark, frustumN(6, 0.18, 0.12, 0.22, 0.28, H.frameY(p, d), { BARK_LINE }))
	end
	-- THE HOLLOW TOP: a rim of bark lumps, the glowing toxic liquid with dark swirls, the mist
	local rimR = R(TOP) - 0.35
	for k = 0, 11 do
		local a = k * math.pi / 6 + rng:NextNumber(-0.08, 0.08)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = d * rimR + Vector3.new(0, TOP + 0.15, 0)
		local c = tone(rng, scaled(wood, 1.08))
		blob(U.Rim, rng, CFrame.lookAt(p, p + d) * CFrame.Angles(rad(rng:NextNumber(-8, 8)), 0, 0), 1.0, 0.6, 0.7, function(nrm: Vector3): Color3
			return scaled(c, 0.85 + 0.25 * math.max(nrm.Y, 0))
		end, 0.3)
	end
	local sap = rows(kit, "Sap")[1].color
	local liqR = rimR - 0.75
	table.insert(U.Liquid, frustumN(14, liqR, liqR, TOP - 0.4, TOP + 0.05, CFrame.new(), { sap }))
	for arm = 0, 2 do
		local prev = nil
		for k = 0, 5 do
			local t = k / 5
			local a = arm * 2.09 + t * 2.4
			local rr = liqR * (0.15 + 0.7 * t)
			local q = Vector3.new(math.cos(a) * rr, TOP + 0.08, math.sin(a) * rr)
			if prev then
				table.insert(U.Swirl, H.bar(prev, q, 0.16 - 0.06 * t, rgb(46, 92, 34)))
			end
			prev = q
		end
	end
	local MIST = rgb(200, 240, 220) -- #C8F0DC
	for k = 1, 3 do
		local a = k * 2.1
		blob(U.Mist, rng, CFrame.new(math.cos(a) * rimR * 0.35, TOP + 0.75 + k * 0.28, math.sin(a) * rimR * 0.35), rimR * 0.42, 0.22, rimR * 0.32, function(): Color3
			return MIST
		end)
	end
	mossCushion(U.Moss, rng, H.frameY(Vector3.new(rimR * 0.9, TOP + 0.55, rimR * 0.3), UP), 1.2)
	mossCushion(U.Moss, rng, H.frameY(Vector3.new(-rimR * 0.5, TOP + 0.55, -rimR * 0.8), UP), 1.1)
	-- THE RUNES: today's Sap strips exactly, each carved into the bark: a dark channel behind it between 2 raised
	-- bark ridges following its lean (its local X points out of the trunk), 2 rune ticks cut into the ridges
	for _, r in ipairs(rows(kit, "Sap")) do
		exactRow(m, r)
		local L = r.size.Y
		table.insert(U.Grooves, piece("Part", Vector3.new(0.5, L + 0.3, r.size.Z + 0.3), r.cf * CFrame.new(-0.3, 0, 0), rgb(27, 20, 16)))
		for _, sz in ipairs({ -1, 1 }) do
			local rc = scaled(wood, 1.12)
			table.insert(U.Bark, H.chamfered(Vector3.new(1.0, L + 0.1, 0.55), r.cf * CFrame.new(-0.45, 0, sz * (r.size.Z / 2 + 0.45)), rc, { "vertical" }, 0.1))
			local tick = r.cf * CFrame.new(0.06, sz * L * 0.18, sz * (r.size.Z / 2 + 0.38)) * CFrame.Angles(rad(sz * 40), 0, 0)
			table.insert(U.Runes, piece("Part", Vector3.new(0.2, 0.8, 0.2), tick, r.color))
		end
	end
	-- the SapPool exactly, small glowing toadstools round it (the glow at the foot)
	for _, r in ipairs(rows(kit, "SapPool")) do
		exactRow(m, r)
		local c = r.cf.Position
		for k = 0, 2 do
			local a = k * 2.2 + 0.6
			local p = Vector3.new(c.X + math.cos(a) * (r.size.Y / 2 + 0.5), 0, c.Z + math.sin(a) * (r.size.Y / 2 + 0.5))
			local h = 0.5 + 0.2 * k
			table.insert(U.Mush, frustumN(5, 0.09, 0.07, 0, h, CFrame.new(p), { rgb(230, 225, 205) }))
			table.insert(U.Glow, frustumN(6, 0.32, 0.06, h - 0.04, h + 0.24, CFrame.new(p), { r.color }))
		end
	end
	-- the crystals: today's 2 exactly, small shards round them
	for _, r in ipairs(rows(kit, "Part")) do
		if r.material == "Neon" then
			exactRow(m, r)
			local out = Vector3.new(r.cf.X, 0, r.cf.Z).Unit
			for j = 1, 4 do
				local a = j * 1.57 + rng:NextNumber(-0.3, 0.3)
				local side = Vector3.new(-out.Z, 0, out.X)
				local base = r.cf.Position + side * math.cos(a) * r.size.X * 0.55 + UP * (math.sin(a) * r.size.Y * 0.4 - 0.1)
				local dir = (out * 0.8 + UP * 0.7 + side * math.cos(a) * 0.4).Unit
				local len = rng:NextNumber(0.5, 0.95)
				table.insert(U.Crystals, frustumN(5, 0.16, 0.02, -0.05, len, H.frameY(base, dir) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), { r.color, scaled(r.color, 0.9) }))
			end
		end
	end
	-- the roots: arching buttress roots, mud collars, moss on 2
	for i, r in ipairs(rows(kit, "Root")) do
		local foot, top, _, thick = ends(r)
		local ctrl = archRoot(U.Roots, rng, top, foot, thick / 2, 1.2, r.color)
		local g = archAt(top, ctrl, foot, 0.25)
		mudCollar(U.Mud, rng, Vector3.new(g.X, 0.12, g.Z), thick * 0.5)
		if i % 2 == 0 then
			mossCushion(U.Moss, rng, H.frameY(bez(top, ctrl, foot, 0.4) + UP * thick * 0.4, UP), 1.3)
		end
	end
	-- the 2 branches: curved dead limbs with twigs, a moss strand
	for i, r in ipairs(rows(kit, "Part")) do
		if r.collide then
			local a, b, _, thick = ends(r)
			gnarledBranch(U.Branches, U.Twigs, rng, a, b, thick / 2 * 0.98, r.color, 9.6)
			if i == 1 then
				mossStrand(U.Moss, rng, a + (b - a) * 0.5 - UP * thick * 0.4, 1.6)
			end
		end
	end
	-- moss at the foot between the roots, ghost mushrooms
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4 + 0.35
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		mossCushion(U.Moss, rng, H.frameY(d * (R(0.3) - 0.2) + Vector3.new(0, 0.35, 0), UP), 1.4)
	end
	for k = 1, 2 do
		local a = k * 2.6 + 1.0
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		ghostMushrooms(U.Mush, rng, d * (R(0) + 0.6) + Vector3.new(0, 0.1, 0), 3, 0.75)
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	colliders(m, kit)
	M.finish(m, "swamp_magic_stump", U, "Roots", {
		Mist = { transparency = 0.55, shadow = false },
		Runes = { material = Enum.Material.Neon },
		Crystals = { material = Enum.Material.Neon },
		Liquid = { material = Enum.Material.Neon },
		Glow = { material = Enum.Material.Neon },
	})
	return m
end

-- the one BossArenas stump with a PointLight under its SapPool (and any other copy with one) keeps it: an invisible
-- "SapLight" part (MapPropKeep) in the SapPool's place carries that copy's light; run once before the sync
function ST.prepStumpLight(): string
	local Sync = require(ServerStorage.DevTools.SyncMapProps:Clone()) :: any
	local stash = ServerStorage:FindFirstChild("_TreeOld_swamp_magic_stump")
	assert(stash, "PropsSwampTrees: no before-stash _TreeOld_swamp_magic_stump")
	local n = 0
	for _, m in ipairs(Sync.find("swamp_magic_stump")) do
		local old = nil
		for _, o in ipairs(stash:GetChildren()) do
			if ((o :: Model):GetPivot().Position - m:GetPivot().Position).Magnitude < 0.01 then
				old = o
			end
		end
		local pool = old and old:FindFirstChild("SapPool")
		local light = pool and pool:FindFirstChildWhichIsA("Light")
		local prev = m:FindFirstChild("SapLight")
		if prev then
			prev:Destroy()
		end
		if light then
			local p = Instance.new("Part")
			p.Name = "SapLight"
			p.Size = (pool :: BasePart).Size
			p.CFrame = (pool :: BasePart).CFrame
			p.Anchored = true
			p.Transparency = 1
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p:SetAttribute("MapPropKeep", true)
			light:Clone().Parent = p
			p.Parent = m
			n += 1
		end
	end
	return `prepStumpLight: {n} copy(s) keep their SapPool light`
end

-- every far copy (matched by pivot with its untagged before-stash clone) gets its own today's colliding trunk blocks,
-- invisible, in a folder "TrunkCollision" (MapPropKeep), and loses any template Collision part; run once before the sync
function ST.prepFarColliders(): string
	local Sync = require(ServerStorage.DevTools.SyncMapProps:Clone()) :: any
	local stash = ServerStorage:FindFirstChild("_TreeOld_swamp_mangrove_a_far")
	assert(stash, "PropsSwampTrees: no before-stash _TreeOld_swamp_mangrove_a_far")
	local n, parts = 0, 0
	for _, m in ipairs(Sync.find("swamp_mangrove_a_far")) do
		local old = nil
		for _, o in ipairs(stash:GetChildren()) do
			if ((o :: Model):GetPivot().Position - m:GetPivot().Position).Magnitude < 0.01 then
				old = o
			end
		end
		assert(old, "PropsSwampTrees: no stash copy for " .. m:GetFullName())
		local prev = m:FindFirstChild("TrunkCollision")
		if prev then
			prev:Destroy()
		end
		for _, c in ipairs(m:GetChildren()) do
			if c.Name == "Collision" and c:IsA("BasePart") then
				c:Destroy()
			end
		end
		local folder = Instance.new("Folder")
		folder.Name = "TrunkCollision"
		folder:SetAttribute("MapPropKeep", true)
		for _, p in ipairs(old:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then
				local q = p:Clone()
				q:ClearAllChildren()
				q.Name = "Collision"
				q.Transparency = 1
				q.CastShadow = false
				q.Parent = folder
				parts += 1
			end
		end
		folder.Parent = m
		n += 1
	end
	return `prepFarColliders: {n} far copies, {parts} kept trunk blocks`
end

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table; its install() builds them
---------------------------------------------------------------------
ST.BUILDERS = { swamp_mangrove_a = true, swamp_mangrove_b = true, swamp_mangrove_a_far = true, swamp_face_tree = true, swamp_hollow_tree = true, swamp_vine_curtain = true, swamp_magic_stump = true }
for id in pairs(ST.BUILDERS) do
	B2[id] = (ST :: any)[id]
	B2.BUILDERS[id] = true
end
ST.install = B2.install
ST.stats = B2.stats

return ST
