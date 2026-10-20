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
-- 05 LILY PADS WITH THE PINK CUBE (kit MapAssets.Jungle.LilyPad_A: 2 Pad cylinders + the Bloom cube; 37 copies: test,
-- kit, Jungle_2 x30, Jungle_3 x2, Jungle_4 x3; scales 1.0 / 1.3 / 1.4 baked into the parts; nothing collides)
---------------------------------------------------------------------
-- one round pad (guide C7) in `frame` (its centre on the water, Y up): an n-sided disc w across whose sides flare out a
-- little toward the top (an upturned rim band, x0.86), a V notch to the centre, a low dome at the centre, 5 lighter
-- veins (+22 % white); top at 0.25 like today
local function lilyPad(list: { BasePart }, rng: Random, frame: CFrame, w: number, n: number, color: Color3)
	local r = w / 2
	local planes = { { 0, 1, 0, 0.25, color }, { 0, -1, 0, 0, H.scaled(color, 0.7) } }
	for k = 0, n - 1 do
		local a = (k + 0.5) * 2 * math.pi / n
		local nrm = Vector3.new(math.cos(a), -0.35, math.sin(a)).Unit -- flaring out toward the top: the upturned rim
		table.insert(planes, { nrm.X, nrm.Y, nrm.Z, nrm:Dot(Vector3.new(math.cos(a) * r, 0.25, math.sin(a) * r)), H.scaled(color, 0.86) })
	end
	-- the V notch from the rim to the centre (a triangle prism cut through the pad)
	local notch = rng:NextNumber(0, 2 * math.pi)
	local negs = {}
	local tip = Vector3.zero
	local e1 = Vector3.new(math.cos(notch - 0.22), 0, math.sin(notch - 0.22)) * (r + 0.3)
	local e2 = Vector3.new(math.cos(notch + 0.22), 0, math.sin(notch + 0.22)) * (r + 0.3)
	H.triangleParts(negs, tip, e1, e2, 1, frame * CFrame.new(0, 0.12, 0), H.scaled(color, 0.8))
	table.insert(list, H.convexSolid(Vector3.new(-r - 0.2, 0, -r - 0.2), Vector3.new(r + 0.2, 0.25, r + 0.2), frame, color, planes, nil, negs))
	-- the dome at the centre and 5 lighter veins (none in the notch)
	table.insert(list, M.frustumN(8, r * 0.18, r * 0.05, 0.2, 0.31, frame, { H.scaled(color, 1.05), color }))
	local vein = color:Lerp(Color3.new(1, 1, 1), 0.22)
	for k = 1, 5 do
		local a = notch + k * 2 * math.pi / 6
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local p0, p1 = d * r * 0.15, d * r * 0.82
		table.insert(list, piece("Part", Vector3.new(0.08, 0.03, (p1 - p0).Magnitude), frame * CFrame.lookAt((p0 + p1) / 2 + Vector3.new(0, 0.255, 0), p1 + Vector3.new(0, 0.255, 0)), vein))
	end
end

-- The lily pads (guide C7): today's 2 pads (5.2 and 3.2 across, today's places and greens #289642 / #78D246) as round
-- pads with a V notch, a low dome, an upturned rim band and lighter veins; today's pink Bloom cube (a plain part, no
-- pickup, no script) as Agent A's pink lotus in the Bloom's box (6 outer + 5 inner petals folded on their midribs, a gold
-- centre). Nothing collides, is queried or touched (as today); each copy keeps its own place on the water.
-- Parts: Pads, Lotus.
function Nature.jungle_lily_pads(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_lily_pads"
	local rng = Random.new(20261285)
	H.setBevelSelf(true)
	local U: any = { Pads = {}, Lotus = {} }
	lilyPad(U.Pads, rng, CFrame.new(0, 0, 0), 5.2, 14, rgb(40, 150, 66))
	lilyPad(U.Pads, rng, CFrame.new(3.4, -0.02, 1.8), 3.2, 11, rgb(120, 210, 70))
	J.facets(U, ND.lily_lotus, Vector3.one, CFrame.identity, "Lotus")
	finish(m, "jungle_lily_pads", U, "Pads")
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		end
	end
	return m
end

---------------------------------------------------------------------
-- shared bamboo helpers (06 and 07)
---------------------------------------------------------------------
local LEAVES = { rgb(120, 210, 70), rgb(96, 196, 72), rgb(40, 150, 66) } -- #78D246, #60C448, #289642
local STRAW = rgb(216, 192, 128) -- #D8C080

-- a bamboo cane (guide C7) from `foot` along `u` (unit), `len` long, r thick: `segs` long segments (n-sided) stepping
-- from x0.86 of `color` at the foot to x1.05 at the top (the lowest one 10 % straw), and a node ring (r + 0.06, one tone
-- darker) every `step`; returns the node points (bottom to top)
local function cane(list: { BasePart }, foot: Vector3, u: Vector3, len: number, r: number, color: Color3, segs: number, step: number, n: number): { Vector3 }
	local helper = if math.abs(u.Z) < 0.9 then Vector3.zAxis else Vector3.xAxis
	local x = helper:Cross(u).Unit
	local frame = CFrame.fromMatrix(foot, x, u)
	for k = 0, segs - 1 do
		local t = if segs > 1 then k / (segs - 1) else 1
		local c = H.scaled(color, 0.86 + 0.19 * t)
		if k == 0 then
			c = c:Lerp(STRAW, 0.1)
		end
		table.insert(list, M.frustumN(n, r, r * 0.97, len * k / segs - 0.02, len * (k + 1) / segs, frame, { c, H.scaled(c, 0.93) }))
	end
	local nodes = {}
	local y = step * 0.8
	while y < len - 0.3 do
		table.insert(list, M.frustumN(6, r + 0.06, r + 0.06, y - 0.07, y + 0.07, frame, { H.scaled(color, 0.82), H.scaled(color, 0.76) }))
		table.insert(nodes, foot + u * y)
		y += step
	end
	table.insert(nodes, foot + u * len)
	return nodes
end

-- a bamboo leaf spray (guide C7, after Agent A's bamboo__leaf_spray, as cheap parts): `n` lance leaves (2.0 x 0.4 at
-- scale 1, plain thin parts: hundreds of copies) fanning down and out along `dir` from a point just off the cane at
-- `at` (no twig: the leaves start inside the cane); sc = scale, wide = an extra width factor (default 1)
local function leafSpray(list: { BasePart }, rng: Random, at: Vector3, dir: Vector3, sc: number, n: number, wide: number?)
	local d = Vector3.new(dir.X, 0, dir.Z).Unit
	local tip = at + d * 0.2 * sc + Vector3.new(0, 0.1 * sc, 0)
	local yaw0 = math.atan2(-d.X, -d.Z)
	for k = 1, n do
		local spread = (k - (n + 1) / 2) / n * rad(110)
		local cf = CFrame.new(tip) * CFrame.Angles(0, yaw0 + spread + rad(rng:NextNumber(-8, 8)), 0) * CFrame.Angles(rad(-rng:NextNumber(15, 32)), 0, 0)
		local L = 2.0 * sc * rng:NextNumber(0.85, 1.05)
		local c = LEAVES[(k % 3) + 1]
		table.insert(list, piece("Part", Vector3.new(0.38 * sc * (wide or 1), 0.05, L), cf * CFrame.new(0, 0, -L / 2), H.scaled(c, rng:NextNumber(0.94, 1.04))))
	end
end

---------------------------------------------------------------------
-- 06 BAMBOO CLUSTER (kit MapAssets.Jungle.Bamboo_Cluster_A: 5 Stalk cylinders + 3 BambooLeaf blocks, 7.2 x 21 x 5.8;
-- 29 copies: test, kit, Jungle_1 x12, Jungle_2 x8, Jungle_3 x7; scales 0.9 / 1.15 / 1.3 baked into the parts)
---------------------------------------------------------------------
-- The bamboo cluster (guide C7): today's 5 stalks (heights 12 .. 21, tilts, colours kept) as bamboo canes: 2 segments
-- each in a green gradient (darker and a touch straw at the foot, lighter at the top) with darker node rings every
-- 3.4; 2 leaf sprays at the top nodes of the 3 tallest canes (replacing today's 3 leaf blocks), a side spray on the 2
-- others; a small base of dark soil mounds with splayed roots (WedgeParts) and a grass tuft. The 5 stalks stay
-- the colliders (invisible cylinders, exact); nothing new collides.
-- Parts: Canes, Leaves, Base, Collision x5.
function Nature.jungle_bamboo(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_bamboo"
	local rng = Random.new(20261286)
	H.setBevelSelf(true)
	local U: any = { Canes = {}, Leaves = {}, Base = {} }
	local kit = kitOf("Bamboo_Cluster_A")
	local stalks = kitParts(kit, "Stalk") -- largest first: the tallest canes first
	local feet = {}
	for i, s in ipairs(stalks) do
		local cf, size = s.cf, s.part.Size
		local u = cf.RightVector -- a Cylinder part's axis
		if u.Y < 0 then
			u = -u
		end
		local foot = cf.Position - u * size.X / 2
		table.insert(feet, foot)
		local nodes = cane(U.Canes, foot, u, size.X, size.Y / 2, s.part.Color, 2, 3.4, 6)
		local a = rng:NextNumber(0, 2 * math.pi)
		if i <= 3 then
			-- the top cluster: 2 sprays at the top node
			leafSpray(U.Leaves, rng, nodes[#nodes], Vector3.new(math.cos(a), 0, math.sin(a)), 1.1, 3)
			leafSpray(U.Leaves, rng, nodes[#nodes], Vector3.new(math.cos(a + 2.4), 0, math.sin(a + 2.4)), 1.0, 3)
		else
			leafSpray(U.Leaves, rng, nodes[math.max(1, #nodes - 1)], Vector3.new(math.cos(a), 0, math.sin(a)), 0.85, 3)
		end
	end
	-- the base: 2 low dark soil mounds round the feet, 5 splayed roots and 2 grass tufts
	local c = Vector3.zero
	for _, f in ipairs(feet) do
		c += f / #feet
	end
	local SOIL = rgb(74, 48, 34) -- #4A3022
	table.insert(U.Base, M.frustumN(7, 2.2, 1.3, -0.1, 0.32, CFrame.new(c.X, 0, c.Z) * CFrame.Angles(0, rad(20), 0), { SOIL, H.scaled(SOIL, 0.9) }))
	table.insert(U.Base, M.frustumN(7, 1.4, 0.8, -0.1, 0.42, CFrame.new(c.X + 0.9, 0, c.Z - 0.6) * CFrame.Angles(0, rad(70), 0), { H.scaled(SOIL, 1.08), SOIL }))
	local ROOT = rgb(104, 68, 44) -- #68442C
	for k = 1, 5 do
		local f = feet[(k - 1) % #feet + 1]
		local a = rng:NextNumber(0, 2 * math.pi)
		local w = Instance.new("WedgePart")
		w.Size = Vector3.new(0.25, 0.3, 0.9)
		w.CFrame = CFrame.lookAt(Vector3.new(f.X, 0.12, f.Z) + Vector3.new(math.cos(a), 0, math.sin(a)) * 0.75, Vector3.new(f.X, 0.12, f.Z) + Vector3.new(math.cos(a), 0, math.sin(a)) * 2)
		w.Color = H.scaled(ROOT, rng:NextNumber(0.9, 1.05))
		w.Material = Enum.Material.SmoothPlastic
		w.Anchored = true
		table.insert(U.Base, w)
	end
	-- 2 grass tufts of 5 thin wedge blades each, apart from each other and off the mound so the union does not split
	-- them (a facet tuft costs 380 triangles here)
	for _, spot in ipairs({ { -2.1, 1.1, 1.0 }, { 2.4, 0.3, 0.85 } }) do
		for k = 1, 5 do
			local h = spot[3] * rng:NextNumber(0.9, 1.4)
			local blade = Instance.new("WedgePart")
			blade.Size = Vector3.new(0.1, h, 0.35)
			blade.CFrame = CFrame.new(c.X + spot[1], -0.05, c.Z + spot[2]) * CFrame.Angles(0, k * 2 * math.pi / 5 + rad(rng:NextNumber(-10, 10)), 0) * CFrame.new(0, 0, 0.32) * CFrame.Angles(rad(rng:NextNumber(14, 30)), 0, 0) * CFrame.new(0, h / 2, 0)
			blade.Color = H.scaled(LEAVES[(k % 3) + 1], rng:NextNumber(0.9, 1.02))
			blade.Material = Enum.Material.SmoothPlastic
			blade.Anchored = true
			table.insert(U.Base, blade)
		end
	end
	finish(m, "jungle_bamboo", U, "Canes")
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("PartOperation") then
			p.CanQuery = false
		end
	end
	kitColliders(m, kit)
	return m
end

---------------------------------------------------------------------
-- 07 THIN BAMBOO (kit MapAssets.Jungle.Vine_Hanging_A: 3 Vine sticks 0.5 square, 14 / 9.5 / 12 long, their tops all at
-- 14, and 3 VineLeaf blocks on their +X side; model attribute Height = 14; 28 copies: test, kit, Jungle_4 x21 hanging
-- from the ceilings at 48 / 24, Jungle_3 x7 grounded (raycast: the stick feet sit 1.1 .. 1.5 under the ground or the
-- ruin stone, the ground 1.5 over the pivot); scales 0.6 / 1.6 baked into the parts; nothing collides, is queried or
-- touched, as today)
---------------------------------------------------------------------
-- today's 3 sticks: foot (pivot space), length, colour, today's leaf height and the spray direction (yaw)
local THIN = {
	{ foot = Vector3.new(-1.7, 0, 0.6), len = 14, color = rgb(70, 170, 60), leaf = 6.3, yaw = rad(-5), low = rad(0) }, -- #46AA3C
	{ foot = Vector3.new(0, 4.5, 0), len = 9.5, color = rgb(22, 100, 56), leaf = 8.775, yaw = rad(35) }, -- #166438
	{ foot = Vector3.new(1.7, 2, 0.6), len = 12, color = rgb(70, 170, 60), leaf = 7.4, yaw = rad(-5), low = rad(180) },
}

-- The thin bamboo (guide C7): today's 3 sticks (places, lengths, tops at 14, colours kept) as thin bamboo canes, 2
-- segments each in a green gradient with node rings every 3.2; today's 3 leaf blocks as 3-leaf sprays at the same
-- heights on the same side, and a 2-leaf spray lower on the 2 outer canes turned inward (the box stays within +10 %). No ground base: most copies hang.
-- The grounded variant (Jungle_3 x7 and its own test copy): the 2 sticks that start in the air today (feet at 2 and
-- 4.5, the ground at 1.5) reach 0.5 under the ground line (their tops stay at 14; node rings every 3.6), and each
-- cane gets a small root flare and 2 grass blades at the ground line. Parts: Canes, Leaves (+ Base for the grounded variant).
local function thinBamboo(grounded: boolean): Model
	local id = if grounded then "jungle_thin_bamboo_grounded" else "jungle_thin_bamboo"
	local m = Instance.new("Model")
	m.Name = id
	local rng = Random.new(if grounded then 20261288 else 20261287)
	H.setBevelSelf(true)
	local U: any = { Canes = {}, Leaves = {} }
	if grounded then
		U.Base = {}
	end
	local GROUND = 1.5
	for _, s in ipairs(THIN) do
		local foot, len = s.foot, s.len
		if grounded and foot.Y > GROUND - 0.5 then
			len += foot.Y - (GROUND - 0.5)
			foot = Vector3.new(foot.X, GROUND - 0.5, foot.Z)
		end
		local nodes = cane(U.Canes, foot, Vector3.yAxis, len, 0.27, s.color, 2, if grounded then 3.6 else 3.2, 6)
		leafSpray(U.Leaves, rng, Vector3.new(foot.X, s.leaf, foot.Z), Vector3.new(math.cos(s.yaw), 0, math.sin(s.yaw)), 0.7, 3, 1.6)
		-- the lower spray (the 2 outer canes): the node nearest 3.4 under today's leaf
		if s.low then
			local best = nodes[1]
			for _, p in ipairs(nodes) do
				if math.abs(p.Y - (s.leaf - 3.4)) < math.abs(best.Y - (s.leaf - 3.4)) then
					best = p
				end
			end
			leafSpray(U.Leaves, rng, best, Vector3.new(math.cos(s.low), 0, math.sin(s.low)), 0.5, 2, 1.6)
		end
		if grounded then
			local SOIL = rgb(74, 48, 34) -- #4A3022
			table.insert(U.Base, M.frustumN(5, 0.44, 0.3, GROUND - 0.12, GROUND + 0.16, CFrame.new(foot.X, 0, foot.Z) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), { SOIL, H.scaled(SOIL, 0.9) }))
			for k = 1, 2 do
				local h = rng:NextNumber(0.6, 0.95)
				local blade = Instance.new("WedgePart")
				blade.Size = Vector3.new(0.08, h, 0.28)
				blade.CFrame = CFrame.new(foot.X, GROUND - 0.05, foot.Z) * CFrame.Angles(0, k * math.pi + rng:NextNumber(-0.4, 0.4), 0) * CFrame.new(0, 0, 0.52) * CFrame.Angles(rad(rng:NextNumber(10, 22)), 0, 0) * CFrame.new(0, h / 2, 0)
				blade.Color = H.scaled(LEAVES[(k % 3) + 1], rng:NextNumber(0.9, 1.02))
				blade.Material = Enum.Material.SmoothPlastic
				blade.Anchored = true
				table.insert(U.Base, blade)
			end
		end
	end
	finish(m, id, U, "Canes")
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		end
	end
	return m
end

function Nature.jungle_thin_bamboo(): Model
	return thinBamboo(false)
end

function Nature.jungle_thin_bamboo_grounded(): Model
	return thinBamboo(true)
end

---------------------------------------------------------------------
-- 08 FLOWERING BUSH (kit MapAssets.Jungle.Bush_Jungle_A: 2 Leaves MeshParts (mesh 9299837325, #289642 8.5 x 5 x 8 and
-- #78D246 5.4 x 3.6 x 5.4) and the pink Flowers MeshPart (6.5 x 2.3 x 6.5); attributes SourceAssetId / SourceCreator;
-- 226 copies: test, kit, Jungle_1 x85, Jungle_2 x70, Jungle_3 x70; scales 0.8 / 1.0 / 1.3 baked into the parts;
-- nothing collides or is queried; the Leaves are touchable, as today)
---------------------------------------------------------------------
-- where the flowers sit (kit pivot space): on the 2 leaf clumps read as ellipsoids (big: 8.5 x 5 x 8 at (0, 2.4, 0)
-- yaw 47; small: 5.4 x 3.6 x 5.4 at (1.6, 4.4, -1.2) yaw 120; a marker profile showed the leaf mesh surface at
-- 1.0 of the ellipsoid), spread round the bush, none inside the other clump: surface point, outward normal
local BUSH_FLOWERS = {
	{ 0.831, 4.007, 3.000, 0.188, 0.806, 0.561 }, -- big clump (az 120, el 40)
	{ -3.254, 3.834, 1.088, -0.626, 0.761, 0.173 }, -- big clump (az 210, el 35)
	{ -1.590, 4.007, -2.635, -0.323, 0.803, -0.501 }, -- big clump (az 285, el 40)
	{ 2.583, 3.574, 2.409, 0.557, 0.648, 0.519 }, -- big clump (az 90, el 28)
	{ 3.668, 5.557, -1.200, 0.622, 0.783, 0.000 }, -- small clump (az 120, el 40)
	{ 0.732, 5.779, 0.303, -0.244, 0.873, 0.423 }, -- small clump (az 240, el 50)
}
local BUSH_BUDS = {
	{ -1.851, 3.457, 3.361, -0.358, 0.620, 0.699 }, -- big clump (az 165, el 25)
	{ -2.202, 4.370, -1.127, -0.383, 0.899, -0.211 }, -- big clump (az 255, el 52)
	{ 1.600, 5.300, -3.538, 0.000, 0.655, -0.756 }, -- small clump (az 30, el 30)
}
local PINK = { rgb(255, 80, 140), rgb(255, 112, 161) } -- #FF508C, #FF70A1
local GOLD = rgb(255, 201, 60) -- #FFC93C
local STEM = rgb(40, 150, 66) -- #289642

-- one open flower (after Agent A's bush__flowers): 5 diamond petals in 2 pinks, cupped 18 degrees, round a gold
-- centre, facing `n` 0.08 off the clump surface point `c`; and a short green stem back into the clump. The petals do
-- not touch each other and the gold centre sits just over them (overlapping parts split into many triangles)
local function bushFlower(flowers: { BasePart }, stems: { BasePart }, rng: Random, c: Vector3, n: Vector3, size: number)
	local t1 = (if math.abs(n.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis):Cross(n).Unit
	local t2 = n:Cross(t1)
	local at = c + n * 0.08
	local D = 0.5 * size -- a petal's diagonal
	local s = D / math.sqrt(2)
	local rc = 0.46 * size -- the petal centres' radius: 5 diamonds this far out do not touch
	local phase = rng:NextNumber(0, 2 * math.pi)
	local cup = rad(18)
	for k = 0, 4 do
		local a = phase + k * 2 * math.pi / 5
		local r = t1 * math.cos(a) + t2 * math.sin(a)
		local dir = (r * math.cos(cup) + n * math.sin(cup)).Unit
		local pn = (n * math.cos(cup) - r * math.sin(cup)).Unit
		local side = pn:Cross(dir).Unit
		-- a square turned 45 degrees in the petal plane: its corner points along dir
		table.insert(flowers, piece("Part", Vector3.new(s, 0.05, s), CFrame.fromMatrix(at + dir * rc, (dir + side).Unit, pn), PINK[k % 2 + 1]))
	end
	table.insert(flowers, M.frustumN(5, 0.17 * size, 0.12 * size, 0.035, 0.13, CFrame.fromMatrix(at, t1, n), { GOLD, H.scaled(GOLD, 1.05) }))
	table.insert(stems, H.bar(c - n * 0.6, at - n * 0.03, 0.09, STEM))
end

-- The flowering bush (guide C7): today's 2 leaf clumps kept (the same meshes, places, sizes, colours; touchable, not
-- colliding); today's pink Flowers mesh replaced by 6 open flowers (Agent A's flower: 5 diamond petals in 2 pinks
-- round a gold centre) and 3 closed buds, spread round both clumps on short stems; Agent A's base leaves round the
-- foot. Parts: Leaves x2 (MeshParts), Flowers, BaseLeaves.
function Nature.jungle_flower_bush(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_flower_bush"
	local rng = Random.new(20261289)
	H.setBevelSelf(true)
	local U: any = { Flowers = {}, BaseLeaves = {} }
	for _, f in ipairs(BUSH_FLOWERS) do
		bushFlower(U.Flowers, U.BaseLeaves, rng, Vector3.new(f[1], f[2], f[3]), Vector3.new(f[4], f[5], f[6]).Unit, rng:NextNumber(0.9, 1.1))
	end
	for _, b in ipairs(BUSH_BUDS) do
		-- a closed bud: a 5-sided pink point, its foot 0.1 in the clump
		local c, n = Vector3.new(b[1], b[2], b[3]), Vector3.new(b[4], b[5], b[6]).Unit
		local t1 = (if math.abs(n.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis):Cross(n).Unit
		table.insert(U.Flowers, M.frustumN(5, 0.18, 0.03, -0.1, 0.5, CFrame.fromMatrix(c, t1, n), { rgb(242, 76, 133), rgb(204, 64, 112) })) -- #F24C85, #CC4070
	end
	J.facets(U, ND.bush_base_leaves, Vector3.one, CFrame.identity, "BaseLeaves")
	finish(m, "jungle_flower_bush", U, "Flowers")
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		end
	end
	-- today's 2 leaf clumps (the kit's, or the synced kit's: the template keeps them), as they are
	local kit = kitOf("Bush_Jungle_A")
	for _, s in ipairs(kitParts(kit, "Leaves")) do
		local leaf = s.part:Clone()
		leaf.CFrame = s.cf
		leaf.Anchored = true
		leaf.Parent = m
	end
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table as the jungle decor; its install() builds them
---------------------------------------------------------------------
Nature.BUILDERS = { jungle_rock_large = true, jungle_rock_small = true, jungle_rock_round = true, jungle_waterfall_rocks = true, jungle_lily_pads = true, jungle_bamboo = true,
	jungle_thin_bamboo = true, jungle_thin_bamboo_grounded = true, jungle_flower_bush = true }
for id in pairs(Nature.BUILDERS) do
	B2[id] = (Nature :: any)[id]
	B2.BUILDERS[id] = true
end
Nature.install = B2.install
Nature.SHAPES = M.SHAPES
Nature.Dc = Dc

return Nature
