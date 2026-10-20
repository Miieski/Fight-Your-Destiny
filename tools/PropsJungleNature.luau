--[[
	PropsJungleNature (dev tool, Edit mode only) - the owner's "JUNGLE ZONE PROP IMPROVEMENT - Rocks and plants"
	(2026-10-20, jungle PROMPT_06): the large, small and round mossy rocks, the rocks with the cyan block (a small
	waterfall), the lily pads, the bamboo cluster, the thin bamboo and the flowering bush rebuilt in the jungle recipe
	(docs/prop_texture_guide.md sections A, C1, C2, C7), keeping each object's colours, place, size, function and
	collision. Source of truth: tools/PropsJungleNature.luau. Inventory: docs/prop_inventory.md "Jungle nature".

	These kits have MANY copies (the bush 227, the small rock 71): every copy is cheap (convex faceted rocks of about
	30 faces, part-built plants, Agent A's facets only where they pay).

	Collision: the visible unions never collide. The kits' colliding parts are cloned from the kit as invisible
	"Collision" parts (the rocks' Toolbox MeshParts keep their mesh and Hull collision; the bamboo stalks stay
	cylinders), so no copy is more (or less) solid than today. None of the eight has a script, prompt, tag or sound.

	The rocks: Agent A's facet bodies and moss (guide C7: angular stacked strata, cracks, soft layered moss cushions
	with grass) sit in today's Rock boxes; they are built as convex solids (DevTools.PropsJungleNatureSolids: one solid
	per facet shell, about 2 triangles per face) instead of wedge pairs (about 30 per face). Today's Rock MeshParts stay
	as the invisible colliders. Pebbles and tufts at the foot are placed on today's hull outline (measured with ray grids
	along about 30 directions).

	It uses DevTools.PropsJungleDecor (and through it the totems / ruins / gates / buildings / desert helpers, finish()
	and the SHAPES table) and registers its builders into the same PropsBatch2 table:
		local N = require(game.ServerStorage.DevTools.PropsJungleNature:Clone())
		print(N.install("jungle_rock_large"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.run({ only = { "jungle_rock_large" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local Dc = require(ServerStorage.DevTools.PropsJungleDecor:Clone()) :: any
local T = Dc.T
local R = T.R
local G = R.G
local J = G.J
local M, B2, H = J.M, J.B2, J.H
local piece, chamfered = H.piece, H.chamfered
local finish = M.finish
local P = J.PALETTE
local MOSS = P.MOSS
local RData = require(ServerStorage.DevTools.PropsJungleRuinsData:Clone()) :: any -- the ruins' tuft and fern
local ND = require(ServerStorage.DevTools.PropsJungleNatureData:Clone()) :: any -- Agent A's nature facets (faces)
local NS = require(ServerStorage.DevTools.PropsJungleNatureSolids:Clone()) :: any -- his rocks / moss as convex solids

local Nature = {}

local rgb = Color3.fromRGB
local rad = math.rad

local STONE = rgb(132, 138, 124) -- #848A7C
local STONE_DARK = rgb(92, 100, 92) -- #5C645C
local RECESS = rgb(41, 45, 41) -- #292D29

---------------------------------------------------------------------
-- kit helpers
---------------------------------------------------------------------
local function kitOf(name: string): Model
	local kit = ServerStorage:FindFirstChild("MapAssets") and ServerStorage.MapAssets:FindFirstChild("Jungle") and ServerStorage.MapAssets.Jungle:FindFirstChild(name)
	assert(kit, `PropsJungleNature: the kit MapAssets.Jungle.{name} is needed`)
	return kit :: Model
end

-- the kit's parts named `name` with their CFrame in the kit's pivot space, largest first. Once the kit itself is
-- synced (it becomes a copy of the template), today's colliding parts live on as its "Collision" parts: those are used
-- (same meshes, sizes and places), so the template can be rebuilt at any time
local function kitParts(kit: Model, name: string): { { part: BasePart, cf: CFrame } }
	local piv = kit:GetPivot()
	local list = {}
	for _, want in ipairs({ name, "Collision" }) do
		for _, p in ipairs(kit:GetChildren()) do
			if p:IsA("BasePart") and p.Name == want then
				table.insert(list, { part = p, cf = piv:ToObjectSpace(p.CFrame) })
			end
		end
		if #list > 0 then
			break
		end
	end
	table.sort(list, function(a, b)
		return a.part.Size.Magnitude > b.part.Size.Magnitude
	end)
	return list
end
Nature.kitParts = kitParts

-- today's colliding parts of the kit, cloned as invisible "Collision" parts (mesh, shape, size, place and
-- CollisionFidelity kept); returns how many
local function kitColliders(m: Model, kit: Model): number
	local piv = kit:GetPivot()
	local n = 0
	for _, p in ipairs(kit:GetChildren()) do
		if p:IsA("BasePart") and p.CanCollide then
			local c = p:Clone()
			c:ClearAllChildren()
			for key in pairs(c:GetAttributes()) do
				c:SetAttribute(key, nil)
			end
			c.Name = "Collision"
			c.CFrame = piv:ToObjectSpace(p.CFrame)
			c.Anchored = true
			c.CanCollide = true
			c.CanQuery = true
			c.CastShadow = false
			c.Transparency = 1
			if c:IsA("MeshPart") then
				c.TextureID = ""
			end
			c.Parent = m
			n += 1
		end
	end
	return n
end
Nature.kitColliders = kitColliders

---------------------------------------------------------------------
-- today's rock hulls (the pebbles and tufts sit on their outline; extra moss lies on their top facets)
---------------------------------------------------------------------
-- unit directions on a sphere (Fibonacci), jittered a little (rng), more of them on the upper half (the visible part)
local function directions(rng: Random, n: number): { Vector3 }
	local list = {}
	local golden = math.pi * (3 - math.sqrt(5))
	for i = 0, n - 1 do
		local y = 1 - (i + 0.5) / n * 1.6 -- 1 .. -0.6: the underside (in the ground) needs few planes
		local r = math.sqrt(math.max(0, 1 - y * y))
		local a = i * golden + rng:NextNumber(-0.15, 0.15)
		table.insert(list, Vector3.new(math.cos(a) * r, y, math.sin(a) * r).Unit)
	end
	table.insert(list, Vector3.new(0, -1, 0))
	return list
end

-- The support planes of a kit part's collision (its convex hull): for each direction d, a ray grid shot along -d
-- across the part; the largest p . d of the hits is the support distance. The part is cloned for a moment into
-- workspace (far away) to be hit; returns { { normal, distance } } in the template space (the part's own cf there).
local SAMPLE_AT = CFrame.new(0, 20000, 0)
local function supportPlanes(part: BasePart, cf: CFrame, dirs: { Vector3 }): { any }
	local probe = part:Clone()
	probe:ClearAllChildren()
	probe.Anchored = true
	probe.CanCollide = true
	probe.CanQuery = true
	probe.Transparency = 1
	probe.CFrame = SAMPLE_AT * cf
	probe.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { probe }
	local c = probe.Position
	local radius = probe.Size.Magnitude / 2 + 1
	local planes = {}
	local N = 13
	for _, d in ipairs(dirs) do
		local helper = if math.abs(d.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
		local u = helper:Cross(d).Unit
		local v = d:Cross(u).Unit
		local best = -math.huge
		for i = 0, N - 1 do
			for j = 0, N - 1 do
				local o = c + d * radius + u * ((i / (N - 1) * 2 - 1) * radius) + v * ((j / (N - 1) * 2 - 1) * radius)
				local hit = workspace:Raycast(o, -d * radius * 2, params)
				if hit then
					best = math.max(best, (hit.Position - c):Dot(d))
				end
			end
		end
		if best > -math.huge then
			-- the plane in template space: normal d, through (centre + d * best) of the template copy
			local centre = (SAMPLE_AT:Inverse() * CFrame.new(c)).Position
			table.insert(planes, { n = d, d = centre:Dot(d) + best + 0.02, centre = centre })
		end
	end
	probe:Destroy()
	return planes
end
Nature.supportPlanes = supportPlanes

-- inside test helpers on a plane set
local function surfaceAlong(planes: { any }, from: Vector3, dir: Vector3): Vector3
	local t = math.huge
	for _, pl in ipairs(planes) do
		local nd = pl.n:Dot(dir)
		if nd > 1e-6 then
			t = math.min(t, (pl.d - pl.n:Dot(from)) / nd)
		end
	end
	return from + dir * t
end
Nature.surfaceAlong = surfaceAlong

-- the plane a surface point lies on (the one it touches)
local function normalAt(planes: { any }, p: Vector3): Vector3
	local best, n = math.huge, Vector3.yAxis
	for _, pl in ipairs(planes) do
		local gap = math.abs(pl.d - pl.n:Dot(p))
		if gap < best then
			best, n = gap, pl.n
		end
	end
	return n
end
Nature.normalAt = normalAt

-- soft layered moss on a rock's top: `count` mats on top facets (normal y > 0.5) round (x, z) points near the
-- top, each laid on its facet; a few grass tufts in it
local function topMoss(list: { BasePart }, rng: Random, planes: { any }, spots: { any })
	for _, s in ipairs(spots) do
		local p = surfaceAlong(planes, Vector3.new(s[1], -50, s[2]), Vector3.yAxis) -- the top surface over (x, z)
		local n = normalAt(planes, p)
		if n.Y < 0.35 then
			n = Vector3.yAxis
		end
		local x = Vector3.new(math.cos(s[5] or 0), 0, math.sin(s[5] or 0))
		x = (x - n * x:Dot(n)).Unit
		R.mossMat(list, rng, CFrame.fromMatrix(p - n * 0.05, x, n), s[3], s[4], s[6])
	end
end
Nature.topMoss = topMoss

-- grass tufts and pebbles round a rock's foot (on the ground, just outside its outline at y 0.3)
local function footDetails(U: any, key: string, rng: Random, planes: { any }, tufts: number, pebbles: number, sc: number)
	local centre = planes[1].centre
	local from = Vector3.new(centre.X, 0.3, centre.Z)
	for k = 1, tufts + pebbles do
		local a = rng:NextNumber(0, 2 * math.pi)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local edge = surfaceAlong(planes, from, dir)
		if k <= tufts then
			J.facets(U, RData.plant_tuft, Vector3.one * sc * rng:NextNumber(0.8, 1.1), CFrame.new(edge.X + dir.X * 0.15 * sc, 0, edge.Z + dir.Z * 0.15 * sc) * CFrame.Angles(0, rng:NextNumber(0, 6.3), 0), key)
		else
			local s = sc * rng:NextNumber(0.35, 0.6)
			R.looseStone(U[key], rng, Vector3.new(s * 1.2, s * 0.6, s), CFrame.new(edge.X + dir.X * s, s * 0.22, edge.Z + dir.Z * s) * CFrame.Angles(0, rng:NextNumber(0, 6.3), 0), H.scaled(STONE, rng:NextNumber(0.85, 1.05)))
		end
	end
end
Nature.footDetails = footDetails

-- one of Agent A's pieces from PropsJungleNatureSolids into U[key]: its convex solids (each plane keeps its face
-- colour) and its loose faces (grass blades, cracks) as wedge pairs; `frame` places it (default: the kit pivot);
-- maxY: loose faces reaching above it (grass blades) are shortened from their foot so their tips stay under it
local function solidPiece(U: any, key: string, data: any, frame: CFrame?, maxY: number?)
	local f = frame or CFrame.identity
	U[key] = U[key] or {}
	for _, sd in ipairs(data.solids) do
		table.insert(U[key], H.convexSolid(sd.lo, sd.hi, f, Color3.fromHex(sd.planes[1][5]), sd.planes))
	end
	local faces = data.faces
	if maxY then
		faces = { palette = data.faces.palette, tris = {} }
		for _, t in ipairs(data.faces.tris) do
			local lo, hi = math.min(t[2], t[5], t[8]), math.max(t[2], t[5], t[8])
			local k = if hi > maxY and hi > lo then math.max(0, (maxY - lo) / (hi - lo)) else 1
			local c = table.clone(t)
			for _, i in ipairs({ 2, 5, 8 }) do
				c[i] = lo + (t[i] - lo) * k
			end
			table.insert(faces.tris, c)
		end
	end
	J.facets(U, faces, Vector3.one, f, key)
end
Nature.solidPiece = solidPiece

-- the plane set of one of those solids (for surfaceAlong / normalAt / topMoss on Agent A's own rock surfaces)
local function planesOf(sd: any): { any }
	local centre = (sd.lo + sd.hi) / 2
	local list = {}
	for _, pl in ipairs(sd.planes) do
		table.insert(list, { n = Vector3.new(pl[1], pl[2], pl[3]), d = pl[4], centre = centre })
	end
	return list
end
Nature.planesOf = planesOf

---------------------------------------------------------------------
-- 01 LARGE MOSSY ROCK (kit MapAssets.Jungle.Mossy_Rock_L, 2 Rock MeshParts + 2 Moss MeshParts, 28 x 15.9 x 24.7;
-- 15 copies: test, kit, Jungle_1 x5, Jungle_2 x4, Jungle_3 x4; scales 0.7 / 0.9 / 1.0 baked into the parts)
---------------------------------------------------------------------
-- The large mossy rock (guide C7): Agent A's 2 angular rocks (stacked tilted strata, the big one #848A7C and the darker
-- #5C645C one leaning on it, tone steps, cracks) in today's 2 Rock boxes; his soft layered moss cushions with grass on
-- their tops (today's 2 moss places), with 4 more soft mats on the strata ledges so the moss covers about today's top
-- third; tufts and pebbles round the foot on today's hull outline.
-- Parts: Moss, Stone, Collision x2 (today's 2 Rock MeshParts).
function Nature.jungle_rock_large(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_rock_large"
	local rng = Random.new(20261281)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Moss = {} }
	local kit = kitOf("Mossy_Rock_L")
	local rocks = kitParts(kit, "Rock")
	local big = supportPlanes(rocks[1].part, rocks[1].cf, directions(rng, 30))
	local small = supportPlanes(rocks[2].part, rocks[2].cf, directions(rng, 22))
	solidPiece(U, "Stone", NS.rock_l_body)
	solidPiece(U, "Moss", NS.rock_l_moss)
	-- more soft moss where the strata step out under the top layers (the left, back and front ledges), so the moss
	-- covers about today's top third
	topMoss(U.Moss, rng, planesOf(NS.rock_l_body.solids[3]), { { -8.3, 0.5, 3.2, 1.8, 1.6, 0.8 }, { -0.5, 6.9, 3.6, 1.5, 0.2, 0.8 }, { -7.6, 5.2, 2.2, 1.3, 2.4, 0.7 } })
	topMoss(U.Moss, rng, planesOf(NS.rock_l_body.solids[2]), { { -0.5, -6.9, 3.0, 1.2, 0.1, 0.7 } })
	footDetails(U, "Stone", rng, big, 3, 4, 1.8)
	footDetails(U, "Stone", rng, small, 1, 2, 1.4)
	finish(m, "jungle_rock_large", U, "Stone")
	kitColliders(m, kit)
	return m
end

---------------------------------------------------------------------
-- 02 SMALL MOSSY ROCK (kit MapAssets.Jungle.Mossy_Rock_S, Rock + Moss MeshParts, 5 x 3.2 x 4.9; 71 copies: test, kit,
-- Jungle_1 x22, Jungle_2 x24, Jungle_3 x22, BossArenas x1; scales 0.8 .. 1.3 baked into the parts)
---------------------------------------------------------------------
-- The small mossy rock (guide C7): Agent A's angular rock (2 tilted strata, a crack) in today's Rock box, his soft moss
-- cushion with short grass on its top (today's moss place), a small mat on the lower ledge; a pebble and a tuft at the
-- foot.
-- Parts: Moss, Stone, Collision (today's Rock MeshPart).
function Nature.jungle_rock_small(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_rock_small"
	local rng = Random.new(20261282)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Moss = {} }
	local kit = kitOf("Mossy_Rock_S")
	local rocks = kitParts(kit, "Rock")
	local hull = supportPlanes(rocks[1].part, rocks[1].cf, directions(rng, 18))
	solidPiece(U, "Stone", NS.rock_s_body)
	solidPiece(U, "Moss", NS.rock_s_moss, nil, 3.55) -- (the grass tips under 3.55: today's rock is 3.25 tall)
	topMoss(U.Moss, rng, planesOf(NS.rock_s_body.solids[1]), { { -1.0, 0.1, 1.0, 0.6, 1.5, 0.45 } })
	footDetails(U, "Stone", rng, hull, 1, 1, 0.7)
	finish(m, "jungle_rock_small", U, "Stone")
	kitColliders(m, kit)
	return m
end

---------------------------------------------------------------------
-- 03 ROUND MOSSY ROCK (kit MapAssets.Jungle.Mossy_Rock_M, Rock + Moss MeshParts, 12.4 x 9.7 x 12.3; 39 copies: test, kit,
-- Jungle_1 x12, Jungle_2 x12, Jungle_3 x12, BossArenas x1; scales 0.8 / 1.0 / 1.2 baked into the parts)
---------------------------------------------------------------------
-- The round mossy rock (guide C7): Agent A's rock (3 stacked tilted strata, the middle one widest so it reads round,
-- today's #5C645C in tone steps, cracks) in today's tilted Rock box, his layered moss cushion with grass on its top
-- (today's moss place), 2 soft mats on the middle stratum's ledges so the moss covers about today's top third; a
-- pebble and a tuft at the foot.
-- Parts: Moss, Stone, Collision (today's Rock MeshPart).
function Nature.jungle_rock_round(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_rock_round"
	local rng = Random.new(20261283)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Moss = {} }
	local kit = kitOf("Mossy_Rock_M")
	local rocks = kitParts(kit, "Rock")
	local hull = supportPlanes(rocks[1].part, rocks[1].cf, directions(rng, 24))
	solidPiece(U, "Stone", NS.rock_m_body)
	solidPiece(U, "Moss", NS.rock_m_moss)
	topMoss(U.Moss, rng, planesOf(NS.rock_m_body.solids[2]), { { -3.0, 0.6, 3.4, 1.4, 1.6, 0.7 }, { 0.6, 2.8, 3.6, 1.3, 0.1, 0.7 } })
	footDetails(U, "Stone", rng, hull, 1, 1, 1.1)
	finish(m, "jungle_rock_round", U, "Stone")
	kitColliders(m, kit)
	return m
end

---------------------------------------------------------------------
-- 04 ROCKS WITH THE CYAN BLOCK = a small waterfall (kit MapAssets.Jungle.Waterfall_Rock_Set, 2 Rock + 2 Moss MeshParts,
-- Step, WaterTop, WaterFall, Foam; 28 x 9.7 x 13.7; 4 copies: test, kit, Jungle_2 x2)
---------------------------------------------------------------------
local WATER = rgb(48, 196, 190) -- #30C4BE (today's water)
local WATER_LIGHT = rgb(127, 227, 222) -- #7FE3DE
local FOAM = rgb(245, 246, 250) -- #F5F6FA
local WATER_LINES = "rbxassetid://92684887585956" -- PropTextures water_lines (the fountain / well "Ripples")

-- a "Ripples" water_lines Texture on a face of `part`
local function ripples(part: BasePart, face: Enum.NormalId)
	local tex = Instance.new("Texture")
	tex.Name = "Ripples"
	tex.Face = face
	tex.Texture = WATER_LINES
	tex.StudsPerTileU = 4
	tex.StudsPerTileV = 4
	tex.Parent = part
end

-- The rocks with the cyan block (guide C7; the cyan block is a small decorative waterfall, nothing scripted): the
-- composition is kept exactly. Agent A's 2 angular rocks with their moss cushions and grass in today's 2 Rock boxes;
-- today's Step (8 x 4.6 x 8) as cut stone in 2 courses (joints over a dark core, chamfers, tones) with a capstone row;
-- today's WaterTop as a bevelled water block (today's size, place and #30C4BE) with the fountain / well Ripples and 2
-- lighter streaks, a rounded lip with a foam line over the front edge; today's WaterFall sheet (size, place, tilt,
-- #30C4BE, Transparency 0.15) with Ripples sliding down and 4 lighter streaks; today's pale Foam slab (#F5F6FA, T 0.3)
-- with foam blobs where the sheet lands; a soft cyan light in the falls (#7FE3DE, range 8, brightness 0.4); pebbles
-- and tufts at the rock feet. The water, the foam and the light never collide (as today); the 2 Rock MeshParts and
-- the Step stay the invisible colliders. PropFX scrolls the Ripples (entry jungle_waterfall_rocks).
-- Parts: Stone, WaterTop, WaterFall, WaterDetail, Foam, Collision x3.
function Nature.jungle_waterfall_rocks(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_waterfall_rocks"
	local rng = Random.new(20261284)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, WaterDetail = {} }
	local kit = kitOf("Waterfall_Rock_Set")
	local rocks = {}
	for _, r in ipairs(kitParts(kit, "Rock")) do
		if r.part:IsA("MeshPart") then
			table.insert(rocks, r)
		end
	end
	solidPiece(U, "Stone", NS.waterfall_rocks)
	for _, r in ipairs(rocks) do
		footDetails(U, "Stone", rng, supportPlanes(r.part, r.cf, directions(rng, 20)), 1, 2, 1.1)
	end
	-- today's Step (8 x 4.6 x 8 at (0, 2.3, 2)): 2 courses of cut stone over a dark core, a capstone row
	R.stoneCourses(U.Stone, rng, -4, 4, 0, 4.1, 2, 8, 2.05, STONE_DARK, rgb(62, 69, 62), 1)
	local x = -4
	for _, len in ipairs({ 2.7, 2.6, 2.7 }) do
		table.insert(U.Stone, chamfered(Vector3.new(len - 0.08, 0.5, 8), CFrame.new(x + len / 2, 4.35, 2), H.scaled(STONE_DARK, H.TONES[rng:NextInteger(1, 3)] * 1.08), { "vertical", "topFrontBack", "topSides" }, 0.15))
		x += len
	end
	-- the rounded lip over the front edge of the water (#30C4BE x1.08) with a foam line on it; 2 lighter streaks on the
	-- top; 4 lighter streaks down the sheet (all as one detail union, not colliding)
	local XAX = CFrame.Angles(0, 0, rad(90))
	table.insert(U.WaterDetail, M.frustumN(8, 0.24, 0.24, -3.6, 3.6, CFrame.new(0, 4.7, -1.95) * XAX, { H.scaled(WATER, 1.08), WATER }))
	table.insert(U.WaterDetail, M.frustumN(8, 0.1, 0.1, -3.4, 3.4, CFrame.new(0, 4.92, -2.0) * XAX, { FOAM }))
	for _, s in ipairs({ { -1.6, 2.6 }, { 1.4, 1.6 } }) do
		table.insert(U.WaterDetail, piece("Part", Vector3.new(0.16, 0.02, s[2]), CFrame.new(s[1], 4.91, 2.6), WATER_LIGHT))
	end
	local sheet = CFrame.new(0, 2.3, -2.2) * CFrame.Angles(rad(6), 0, 0)
	for _, s in ipairs({ { -2.6, 3.6 }, { -0.9, 4.4 }, { 0.8, 3.2 }, { 2.5, 4.0 } }) do
		table.insert(U.WaterDetail, piece("Part", Vector3.new(0.18, s[2], 0.04), sheet * CFrame.new(s[1], 2.5 - s[2] / 2, -0.32), WATER_LIGHT))
	end
	-- foam blobs where the sheet lands, on today's Foam slab
	for _, b in ipairs({ { -2.4, -2.9, 0.9 }, { -0.4, -3.1, 1.1 }, { 1.7, -2.9, 0.8 }, { 3.0, -3.3, 0.6 } }) do
		table.insert(U.WaterDetail, chamfered(Vector3.new(b[3], 0.22, b[3] * 0.7), CFrame.new(b[1], 0.42, b[2]) * CFrame.Angles(0, rad(rng:NextNumber(-30, 30)), 0), FOAM, { "vertical", "topFrontBack", "topSides" }, b[3] * 0.25))
	end
	finish(m, "jungle_waterfall_rocks", U, "Stone", { WaterDetail = { shadow = false } })
	local detail = m:FindFirstChild("WaterDetail") :: BasePart
	detail.Transparency = 0.15
	-- today's WaterTop as a bevelled block (size, place and colour kept, not colliding) with Ripples on top
	local top = chamfered(Vector3.new(7.4, 0.4, 8.1), CFrame.new(0, 4.7, 2), WATER, { "vertical", "topFrontBack", "topSides" }, 0.12)
	local wt = H.merge(m, "WaterTop", { top }, { single = WATER, shadow = false })
	wt.CanCollide, wt.CanQuery, wt.CanTouch = false, false, false
	ripples(wt, Enum.NormalId.Top)
	-- today's WaterFall sheet (kept: size, place, tilt, colour, Transparency 0.15) with Ripples on both faces, the light
	local wf = G.exact(m, "Part", "WaterFall", Vector3.new(7.2, 5, 0.6), sheet, WATER, { shadow = false })
	wf.Transparency = 0.15
	ripples(wf, Enum.NormalId.Front)
	ripples(wf, Enum.NormalId.Back)
	local light = Instance.new("PointLight")
	light.Color = WATER_LIGHT
	light.Range = 8
	light.Brightness = 0.4
	light.Shadows = false
	light.Parent = wf
	-- today's pale Foam slab (kept: size, place, colour, Transparency 0.3)
	local foam = G.exact(m, "Part", "Foam", Vector3.new(8.4, 0.3, 3), CFrame.new(0, 0.2, -3.6), FOAM, { shadow = false })
	foam.Transparency = 0.3
	kitColliders(m, kit)
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table as the jungle decor; its install() builds them
---------------------------------------------------------------------
Nature.BUILDERS = { jungle_rock_large = true, jungle_rock_small = true, jungle_rock_round = true, jungle_waterfall_rocks = true }
for id in pairs(Nature.BUILDERS) do
	B2[id] = (Nature :: any)[id]
	B2.BUILDERS[id] = true
end
Nature.install = B2.install
Nature.SHAPES = M.SHAPES
Nature.Dc = Dc

return Nature
