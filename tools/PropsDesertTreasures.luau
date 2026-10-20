--[[
	PropsDesertTreasures (dev tool, Edit mode only) - the owner's "DESERT ZONE PROP IMPROVEMENT - Props, furniture and
	treasures" (2026-10-20, PROMPT_05): the terracotta jar, amphora, rug, golden stand, throne and golden lamp rebuilt in
	the desert recipe (docs/prop_texture_guide.md sections A, B, B14), keeping each object's colours, place, size,
	glow, attachments and collision. Source of truth: tools/PropsDesertTreasures.luau. Inventory: docs/prop_inventory.md
	"Desert props".

	Collision: the visible unions never collide; invisible "Collision" parts are the kit's colliding parts (same shape,
	size and place), so no copy is more (or less) solid than today. The rug collides nowhere (as today).

	It uses DevTools.PropsDesertMonuments (its helpers, finish() and the SHAPES table) and registers its builders into
	PropsDesert's PropsBatch2 table:
		local T = require(game.ServerStorage.DevTools.PropsDesertTreasures:Clone())
		print(T.install("desert_rug"))   -- (re)builds ServerStorage.MapProps.desert_rug
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "desert_rug" } }), Sync.run({ only = { "desert_rug" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local M = require(ServerStorage.DevTools.PropsDesertMonuments:Clone()) :: any
local D = M.D -- the same PropsDesert / PropsBatch2 tables as the monuments (one bevel state, one install)
local B2 = D.B2
local H = B2.H
local C = D.PALETTE
local piece, chamfered = H.piece, H.chamfered
local soft = D.lib.soft
local STONE, FOOT = C.Sandstone, C.Footing
local Data = require(ServerStorage.DevTools.PropsDesertTreasuresData:Clone()) :: any -- Agent A's facet pieces
local finish = M.finish

local Treasures = {}

local rgb = Color3.fromRGB
local rad = math.rad

local LINEN = rgb(232, 226, 208)

---------------------------------------------------------------------
-- 03 RUG (kit MapAssets.Desert.Carpet_A, 6 parts, none collides; Desert_1 Camps x3, Desert_2 Village x7, BA x1)
---------------------------------------------------------------------
-- The rug (B14): today's footprint (the carpet 8 x 0.15 x 10 at z -1 and its 2 torn pieces), woven: a turquoise-blue
-- border band 0.6 wide inset 0.3 along both long sides with a gold chequer of 0.4 squares and linen lines; today's 2
-- cross stripes with a gold zigzag of small diamonds; today's gold diamond (same size and place) with a linen outline
-- and a red centre diamond 1.0 outlined in linen; faint weave rows; linen fringes (0.12 x 0.6) at the front short end
-- and on the far edges of the torn pieces; the front-left corner (+X, -Z) folded back over a 2 x 2 triangle, showing
-- the darker underside, with its fringe. Nothing collides (as today). Parts: Cloth, Pattern, Fringe.
function Treasures.desert_rug(): Model
	local m = Instance.new("Model")
	m.Name = "desert_rug"
	local rng = Random.new(20261220)
	H.setBevelSelf(true)
	local U = { Cloth = {}, Pattern = {}, Fringe = {} }
	local RED, RED2, STRIPE, GOLD = rgb(214, 74, 62), rgb(193, 66, 56), rgb(60, 150, 170), C.Gold
	-- the folded corner: everything with x - z > 8 is cut off (the fold line runs from (2, -6) to (4, -4))
	local function foldCut(): BasePart
		return piece("Part", Vector3.new(4, 2, 8), CFrame.new(5.414, 0, -5.414) * CFrame.Angles(0, rad(45), 0), RED)
	end
	local function folded(x: number, z: number): boolean
		return x - z > 7.9
	end
	-- the carpet and today's 2 cross stripes, cut at the fold
	table.insert(U.Cloth, H.subtractKeep(Vector3.new(8, 0.15, 10), CFrame.new(0, 0.075, -1), RED, { foldCut() }))
	for _, z in ipairs({ -5.4, 2.2 }) do
		local negs = if z < 0 then { foldCut() } else {}
		table.insert(U.Pattern, H.subtractKeep(Vector3.new(8.1, 0.18, 1), CFrame.new(0, 0.09, z), STRIPE, negs))
		for _, sz in ipairs({ -1, 1 }) do
			local x0, x1 = -4.0, if z < 0 then (if sz < 0 then 2.0 else 2.9) else 4.0
			table.insert(U.Pattern, piece("Part", Vector3.new(x1 - x0 - 0.1, 0.02, 0.08), CFrame.new((x0 + x1) / 2, 0.185, z + sz * 0.38), LINEN))
		end
		for i = -4, 4 do
			local x = i * 0.85
			if not folded(x + 0.25, z - 0.25) then
				table.insert(U.Pattern, piece("Part", Vector3.new(0.34, 0.02, 0.34), CFrame.new(x, 0.19, z) * CFrame.Angles(0, rad(45), 0), GOLD))
			end
		end
	end
	-- faint weave rows across the field
	for k = 0, 5 do
		local z = -4.4 + k * 1.1
		if z < 1.6 then
			table.insert(U.Cloth, piece("Part", Vector3.new(7.9, 0.01, 0.3), CFrame.new(0, 0.152, z), RED2))
		end
	end
	-- the long-side border bands (between the stripes) with a gold chequer and an inner linen line
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Pattern, piece("Part", Vector3.new(0.6, 0.03, 6.6), CFrame.new(sx * 3.4, 0.165, -1.6), STRIPE))
		table.insert(U.Pattern, piece("Part", Vector3.new(0.08, 0.02, 6.6), CFrame.new(sx * 2.98, 0.16, -1.6), LINEN))
		for k = 0, 7 do
			local z = -4.7 + k * 0.8 + 0.2
			local x = sx * 3.4 + (if k % 2 == 0 then -0.1 else 0.1)
			table.insert(U.Pattern, piece("Part", Vector3.new(0.4, 0.02, 0.4), CFrame.new(x, 0.185, z), GOLD))
		end
	end
	-- today's gold diamond (3.2, turned 45, at z -1.5) with a linen outline, a red centre diamond 1.0 outlined in linen
	local dc = CFrame.new(0, 0, -1.5) * CFrame.Angles(0, rad(45), 0)
	table.insert(U.Pattern, piece("Part", Vector3.new(3.5, 0.02, 3.5), dc * CFrame.new(0, 0.16, 0), LINEN))
	table.insert(U.Pattern, piece("Part", Vector3.new(3.2, 0.2, 3.2), dc * CFrame.new(0, 0.1, 0), GOLD))
	table.insert(U.Pattern, piece("Part", Vector3.new(1.3, 0.02, 1.3), dc * CFrame.new(0, 0.205, 0), LINEN))
	table.insert(U.Pattern, piece("Part", Vector3.new(1.0, 0.03, 1.0), dc * CFrame.new(0, 0.21, 0), RED))
	for _, e in ipairs({ { 0, -1.6 }, { 0, 1.6 }, { -1.6, 0 }, { 1.6, 0 } }) do
		table.insert(U.Pattern, piece("Part", Vector3.new(0.3, 0.02, 0.3), dc * CFrame.new(e[1], 0.21, e[2]), STRIPE))
	end
	-- today's 2 torn pieces (same size, place, turn, colour), fringed on their far edge
	local torn = {
		{ Vector3.new(4.5, 0.15, 2.6), CFrame.new(-1.9, 0.075, 5.2) * CFrame.Angles(0, rad(-14), 0), RED },
		{ Vector3.new(2.6, 0.15, 1.8), CFrame.new(2.6, 0.075, 5.6) * CFrame.Angles(0, rad(22), 0), RED2 },
	}
	local function strand(cf: CFrame)
		table.insert(U.Fringe, piece("Part", Vector3.new(0.12, 0.04, 0.6), cf * CFrame.Angles(0, rad(rng:NextNumber(-8, 8)), 0) * CFrame.new(0, 0, -0.3), if rng:NextNumber() < 0.5 then LINEN else rgb(216, 208, 186)))
	end
	for _, t in ipairs(torn) do
		table.insert(U.Cloth, piece("Part", t[1], t[2], t[3]))
		table.insert(U.Pattern, piece("Part", Vector3.new(t[1].X - 0.4, 0.02, 0.25), t[2] * CFrame.new(0, 0.085, t[1].Z / 2 - 0.45), STRIPE))
		local n = math.floor(t[1].X / 0.4)
		for k = 0, n - 1 do
			local x = -t[1].X / 2 + 0.2 + k * (t[1].X - 0.4) / math.max(n - 1, 1)
			strand(t[2] * CFrame.new(x, -0.055, t[1].Z / 2) * CFrame.Angles(0, math.pi, 0))
		end
	end
	-- the front fringe (z -6), up to the fold, with a linen knot band
	table.insert(U.Fringe, piece("Part", Vector3.new(5.9, 0.05, 0.12), CFrame.new(-1.05, 0.04, -5.97), LINEN))
	for k = 0, 14 do
		local x = -3.8 + k * 0.4
		if x < 1.85 then
			strand(CFrame.new(x, 0.02, -6.0))
		end
	end
	-- the folded corner: the flap (the corner (4, -6) turned over onto (2, -4)), its darker underside, the fold roll and
	-- the corner's fringe now lying on the rug pointing -X
	H.triangleParts(U.Cloth, Vector3.new(2, 0.21, -6), Vector3.new(4, 0.21, -4), Vector3.new(2, 0.21, -4), 0.12, CFrame.identity, H.scaled(RED, 0.86))
	table.insert(U.Cloth, piece("Part", Vector3.new(2.83, 0.24, 0.24), CFrame.new(3, 0.13, -5) * CFrame.Angles(0, rad(-45), 0), H.scaled(RED, 0.93), { shape = Enum.PartType.Cylinder }))
	table.insert(U.Fringe, piece("Part", Vector3.new(0.12, 0.05, 1.9), CFrame.new(2.03, 0.27, -5.0), LINEN))
	for k = 0, 3 do
		strand(CFrame.new(2.0, 0.28, -5.65 + k * 0.45) * CFrame.Angles(0, rad(90), 0))
	end
	finish(m, "desert_rug", U, "Cloth")
	return m
end

-- one of Agent A's facet pieces (DevTools.PropsDesertTreasuresData) as wedge pairs in `frame`, scaled by sc: the Neon
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
Treasures.facets = facets

-- a lathe body from a profile (Agent A's ring radii): rings = { { y, r (vertex radius), colours of the segment above } },
-- n-sided frustum segments (the face colours cycle: tone steps, painted bands); far cheaper than the facet pieces, so
-- the props with many copies (jars, amphorae, stands) use it
local function lathe(list: { BasePart }, n: number, rings: { any }, cf: CFrame?)
	local c = math.cos(math.pi / n)
	for i = 1, #rings - 1 do
		local a, b = rings[i], rings[i + 1]
		if b[1] - a[1] > 0.015 then
			table.insert(list, M.frustumN(n, math.max(a[2] * c, 0.02), math.max(b[2] * c, 0.02), a[1], b[1], cf or CFrame.identity, a[3]))
		end
	end
end
Treasures.lathe = lathe

local function shape(kind: string, sx: number, sy: number, sz: number, cf: CFrame): any
	return { kind, sx, sy, sz, { cf:GetComponents() } }
end
local AXIS_UP = CFrame.Angles(0, 0, rad(90)) -- a Cylinder standing up (its axis along Y)

-- a plain visual part outside the unions (it keeps its name: Embers, SpoutTip), never colliding
local function loosePart(m: Model, name: string, p: BasePart)
	p.Name = name
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = m
end

---------------------------------------------------------------------
-- 04 GOLDEN STAND (kit MapAssets.Desert.Brazier_A, 6 parts; Desert_2 x2, Desert_3 GateBraziers x2, Desert_4 x8, BA x10)
---------------------------------------------------------------------
M.SHAPES.golden_stand = { -- every part collides today
	shape("Block", 3.2, 1, 3.2, CFrame.new(0, 0.5, 0)), -- Base
	shape("Block", 1.5, 2.8, 1.5, CFrame.new(0, 2.4, 0)), -- Stem
	shape("Block", 3.2, 0.6, 3.2, CFrame.new(0, 4.1, 0)), -- Bowl
	shape("Block", 4.2, 0.9, 4.2, CFrame.new(0, 4.85, 0)), -- Bowl
	shape("Block", 4.2, 0.85, 4.2, CFrame.new(0, 4.825, 0) * CFrame.Angles(0, rad(45), 0)), -- Bowl
	shape("Block", 3, 0.4, 3, CFrame.new(0, 5.3, 0)), -- Embers
}

-- The golden stand (B14): a 2-step stone base (3.2 / 2.6, chamfered, block joints), a carved octagonal stone stem
-- with 2 engraved rings and a moulded collar, a gold lotus bowl on Agent A's profile (8 petals, tips curling out to
-- today's 8 star corners, engraved ring, lapis line) in place of today's 3 bowl blocks; today's Neon embers (#FF8C28, same place, now a round bed of coals with
-- small glowing chunks) keep the Attachment FirePoint at (0, 5.6, 0) (the Fire_Brazier VFX stand on it), plus a
-- PointLight #FF8C28 range 10 brightness 0.8. Parts: Stone, Gold, Embers (Neon, + FirePoint + PointLight), Collision x6.
function Treasures.golden_stand(): Model
	local m = Instance.new("Model")
	m.Name = "golden_stand"
	H.setBevelSelf(true)
	local Ht = 5.5
	local U = { Stone = {}, Gold = {} }
	table.insert(U.Stone, chamfered(Vector3.new(3.2, 0.6, 3.2), CFrame.new(0, 0.3, 0), soft(FOOT, 0.3, Ht, 0.95), { "vertical", "topFrontBack", "topSides" }, 0.15))
	table.insert(U.Stone, chamfered(Vector3.new(2.6, 0.4, 2.6), CFrame.new(0, 0.8, 0), soft(FOOT, 0.8, Ht, 1.05), { "vertical", "topFrontBack", "topSides" }, 0.12))
	for face = 0, 3 do
		local f = CFrame.Angles(0, face * math.pi / 2, 0) * CFrame.new(0, 0.3, -1.6)
		table.insert(U.Stone, piece("Part", Vector3.new(0.07, 0.45, 0.04), f * CFrame.new(if face % 2 == 0 then 0.35 else -0.35, 0, -0.005), H.scaled(FOOT, 0.72)))
	end
	-- the carved octagonal stem (1.0 .. 3.8) with a base moulding, 2 engraved rings and a collar under the bowl
	table.insert(U.Stone, H.octagon(1.5, 2.8, CFrame.new(0, 2.4, 0), soft(STONE, 2.4, Ht, 1.0)))
	table.insert(U.Stone, H.octagon(1.85, 0.25, CFrame.new(0, 1.12, 0), soft(STONE, 1.1, Ht, 0.95)))
	for _, y in ipairs({ 1.75, 3.2 }) do
		table.insert(U.Stone, H.octagon(1.52, 0.1, CFrame.new(0, y, 0), H.scaled(STONE, 0.72)))
	end
	table.insert(U.Gold, H.octagon(1.7, 0.18, CFrame.new(0, 3.72, 0), C.Gold))
	-- the lotus bowl (Agent A's profile, 16 sides): a foot cup, an engraved ring, the bowl of 8 petals (pairs of faces
	-- in 2 golds), a lapis line, 8 petal tips curling out to today's 8 star corners (r 2.9, every 45 degrees), a dark
	-- floor under the embers
	local G1, G2, G3 = C.Gold, rgb(229, 180, 53), rgb(213, 167, 49)
	local c16 = math.cos(math.pi / 16)
	lathe(U.Gold, 16, { { 3.8, 0.75, { G2, G3 } }, { 4.2, 1.2, { rgb(195, 153, 45) } }, { 4.28, 1.25, { G1, G2, G2, G1 } }, { 4.92, 1.9, { C.Lapis } }, { 5.0, 1.97, {} } })
	local function at(angle: number, r: number, y: number): Vector3
		return Vector3.new(math.cos(angle) * r, y, math.sin(angle) * r)
	end
	for k = 0, 7 do
		local th = k * math.pi / 4
		M.tri(U.Gold, at(th - math.pi / 8, 1.97, 4.98), at(th + math.pi / 8, 1.97, 4.98), at(th, 2.9, 5.32), 0.1, if k % 2 == 0 then rgb(255, 211, 63) else G2)
		M.tri(U.Gold, at(th - math.pi / 16, 1.93, 4.99), at(th + math.pi / 16, 1.93, 4.99), at(th, 2.55, 5.24), 0.06, H.scaled(G2, 0.85))
	end
	table.insert(U.Gold, M.drum16(3.7 * c16, 0.02, CFrame.new(0, 5.005, 0), rgb(110, 70, 30)))
	finish(m, "golden_stand", U, "Stone")
	-- today's embers: a Neon bed of coals at today's place (5.1 .. 5.5) with FirePoint and a soft light
	local embers = piece("Part", Vector3.new(0.4, 3.0, 3.0), CFrame.new(0, 5.3, 0) * AXIS_UP, rgb(255, 140, 40), { shape = Enum.PartType.Cylinder, material = Enum.Material.Neon })
	embers.CastShadow = false
	loosePart(m, "Embers", embers)
	local fp = Instance.new("Attachment")
	fp.Name = "FirePoint"
	fp.Parent = embers
	fp.WorldCFrame = CFrame.new(0, 5.6, 0)
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 140, 40)
	light.Range = 10
	light.Brightness = 0.8
	light.Shadows = false
	light.Parent = embers
	return m
end

---------------------------------------------------------------------
-- 05 THRONE (kit MapAssets.Desert.Throne_Gold, 21 parts; BossArenas.Desert x1 at 1.5)
---------------------------------------------------------------------
M.SHAPES.pharaoh_throne = { -- every part collides today
	shape("Block", 13, 1.2, 11, CFrame.new(0, 0.6, 0)), shape("Block", 11, 1.2, 9, CFrame.new(0, 1.8, 0.5)), -- Steps
	shape("Block", 7, 2.6, 6, CFrame.new(0, 3.7, 1)), shape("Block", 7.4, 0.7, 6.4, CFrame.new(0, 5.35, 1)), -- Seat, Cushion
	shape("Block", 8.4, 15, 1.6, CFrame.new(0, 9.9, 4.2)), shape("Block", 5, 9, 0.4, CFrame.new(0, 11.5, 3.3)), -- Back, Inlay
	shape("Cylinder", 0.5, 4.4, 4.4, CFrame.new(0, 18.4, 4) * CFrame.Angles(0, rad(90), 0)), -- SunDisc
}
for _, sx in ipairs({ -1, 1 }) do
	local cx = sx * 3.6
	for _, e in ipairs({ { -0.4, 0.4, 0 }, { 0.4, 0.4, 90 }, { 0.4, -0.4, 180 }, { -0.4, -0.4, -90 } }) do
		table.insert(M.SHAPES.pharaoh_throne, shape("CornerWedgePart", 0.8, 2.4, 0.8, CFrame.new(cx + e[1], 18.6, 4.2 + e[2]) * CFrame.Angles(0, rad(e[3]), 0))) -- Spikes
	end
	table.insert(M.SHAPES.pharaoh_throne, shape("Block", 1.5, 3.6, 6.4, CFrame.new(sx * 4.2, 4.2, 1))) -- Arm
	table.insert(M.SHAPES.pharaoh_throne, shape("Block", 1.8, 0.7, 6.8, CFrame.new(sx * 4.2, 6.35, 1))) -- ArmTop
	table.insert(M.SHAPES.pharaoh_throne, shape("Block", 1.9, 1.3, 1.6, CFrame.new(sx * 4.2, 7.35, -1.8))) -- ArmGem
end

-- The throne (B14): the dais (today's 2 steps, chamfered, a lapis band 0.3 on the upper step); the seat on 4 carved
-- legs with Agent A's gold lion paw feet, a carved front apron with inlays; today's red cushion with gold piping and 4
-- gold tassels on its front edge; Agent A's 2 lion armrests in place of the arm blocks, today's 2 Neon cyan arm gems at their place; the
-- high gold back with today's lapis panel in a gold frame 0.6 (0.15 proud) with 3 gold star inlays; today's glowing sun
-- disc with a 0.3 gold ring and 2 gold / lapis uraei beside it; today's 2 gold spikes as 4-faced pyramids.
-- Decoration only (no Seat, as today). Parts: Stone, Gold, Inlay, Cloth, Glow, Collision x21.
function Treasures.pharaoh_throne(): Model
	local m = Instance.new("Model")
	m.Name = "pharaoh_throne"
	H.setBevelSelf(true)
	local Ht = 20
	local U = { Stone = {}, Gold = {}, Inlay = {}, Cloth = {}, Glow = {} }
	local GOLD2 = rgb(229, 180, 53)
	-- the dais
	table.insert(U.Stone, chamfered(Vector3.new(13, 1.2, 11), CFrame.new(0, 0.6, 0), soft(FOOT, 0.6, Ht, 1.0), { "vertical", "topFrontBack", "topSides" }, 0.15))
	table.insert(U.Stone, chamfered(Vector3.new(11, 1.2, 9), CFrame.new(0, 1.8, 0.5), soft(STONE, 1.8, Ht, 1.0), { "vertical", "topFrontBack", "topSides" }, 0.15))
	table.insert(U.Inlay, piece("Part", Vector3.new(11.06, 0.3, 9.06), CFrame.new(0, 1.8, 0.5), C.Lapis))
	for i = -5, 5 do
		table.insert(U.Gold, piece("Part", Vector3.new(0.18, 0.18, 0.05), CFrame.new(i * 0.95, 1.8, -4.04) * CFrame.Angles(0, 0, rad(45)), C.Gold))
	end
	-- the seat: a gold box on 4 carved legs with lion paw feet, a carved front apron
	table.insert(U.Gold, chamfered(Vector3.new(7, 1.2, 6), CFrame.new(0, 4.4, 1), GOLD2, { "vertical", "bottomFrontBack", "bottomSides" }, 0.12))
	table.insert(U.Stone, piece("Part", Vector3.new(6.2, 1.3, 5.2), CFrame.new(0, 3.15, 1), H.scaled(GOLD2, 0.55)))
	for _, sx in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1.6, 3.6 }) do
			local x = sx * 3.1
			table.insert(U.Gold, chamfered(Vector3.new(0.8, 1.0, 0.8), CFrame.new(x, 3.3, z), C.Gold, { "vertical" }, 0.15))
			table.insert(U.Gold, H.octagon(0.95, 0.15, CFrame.new(x, 3.55, z), H.scaled(C.Gold, 0.9)))
			facets(U, Data.paw_foot, Vector3.one, CFrame.new(x, 2.4, z), "Gold")
		end
	end
	local apron = CFrame.new(0, 4.4, -2.02)
	table.insert(U.Gold, piece("Part", Vector3.new(5.6, 0.7, 0.04), apron, H.scaled(GOLD2, 0.85)))
	for i = -3, 3 do
		table.insert(U.Inlay, piece("Part", Vector3.new(0.4, 0.4, 0.05), apron * CFrame.new(i * 0.8, 0, -0.02) * CFrame.Angles(0, 0, rad(45)), if i % 2 == 0 then C.Lapis else C.Turquoise))
	end
	-- today's red cushion with gold piping and 4 tassels
	local RED = rgb(214, 74, 62)
	table.insert(U.Cloth, chamfered(Vector3.new(7.4, 0.7, 6.4), CFrame.new(0, 5.35, 1), RED, { "vertical", "topFrontBack", "topSides" }, 0.2))
	for _, e in ipairs({ { 0, -2.15, 7.3, 0.15 }, { 0, 4.15, 7.3, 0.15 } }) do
		table.insert(U.Gold, piece("Part", Vector3.new(e[3], 0.15, e[4]), CFrame.new(e[1], 5.62, e[2]), C.Gold))
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Gold, piece("Part", Vector3.new(0.15, 0.15, 6.0), CFrame.new(sx * 3.65, 5.62, 1), C.Gold))
		-- the 4 tassels hang from the front edge, between the lions
		for _, x in ipairs({ 1.1, 3.0 }) do
			table.insert(U.Gold, piece("Part", Vector3.new(0.12, 0.25, 0.12), CFrame.new(sx * x, 5.15, -2.28), C.Gold))
			table.insert(U.Gold, M.frustumN(6, 0.14, 0.08, 4.55, 5.05, CFrame.new(sx * x, 0, -2.3), { C.Gold, H.scaled(C.Gold, 0.9) }))
		end
	end
	-- Agent A's lion armrests; today's Neon arm gems
	facets(U, Data.lion_armrests, Vector3.one, CFrame.identity, "Gold")
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Glow, chamfered(Vector3.new(1.9, 1.3, 1.6), CFrame.new(sx * 4.2, 7.35, -1.8), rgb(64, 208, 196), { "vertical", "topFrontBack", "topSides" }, 0.2))
	end
	-- the high back: today's gold back (2.4 .. 17.4) with side rolls, the lapis panel (keep) in a gold frame, star inlays
	table.insert(U.Gold, chamfered(Vector3.new(8.4, 15, 1.6), CFrame.new(0, 9.9, 4.2), C.Gold, { "vertical", "topFrontBack", "topSides" }, 0.2))
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Gold, H.octagon(0.7, 15, CFrame.new(sx * 4.0, 9.9, 3.45), GOLD2))
	end
	table.insert(U.Inlay, piece("Part", Vector3.new(5, 9, 0.4), CFrame.new(0, 11.5, 3.3), C.Lapis))
	for _, e in ipairs({ { 0, 16.3, 6.2, 0.6 }, { 0, 6.7, 6.2, 0.6 }, { -2.8, 11.5, 0.6, 9 }, { 2.8, 11.5, 0.6, 9 } }) do
		table.insert(U.Gold, chamfered(Vector3.new(e[3], e[4], 0.45), CFrame.new(e[1], e[2], 3.175), GOLD2, { "frontFace" }, 0.08))
	end
	for _, y in ipairs({ 8.7, 11.5, 14.3 }) do
		table.insert(U.Gold, piece("Part", Vector3.new(0.75, 0.75, 0.06), CFrame.new(0, y, 3.08) * CFrame.Angles(0, 0, rad(45)), C.Gold))
		table.insert(U.Gold, piece("Part", Vector3.new(1.6, 0.14, 0.05), CFrame.new(0, y, 3.07), C.Gold))
		table.insert(U.Gold, piece("Part", Vector3.new(0.14, 1.6, 0.05), CFrame.new(0, y, 3.07), C.Gold))
		table.insert(U.Inlay, piece("Part", Vector3.new(0.3, 0.3, 0.05), CFrame.new(0, y, 3.03) * CFrame.Angles(0, 0, rad(45)), C.Turquoise))
	end
	-- today's sun disc (Neon) with a 0.3 gold ring, and 2 uraei beside it
	table.insert(U.Glow, piece("Part", Vector3.new(0.5, 4.4, 4.4), CFrame.new(0, 18.4, 4) * CFrame.Angles(0, rad(90), 0), rgb(255, 201, 60), { shape = Enum.PartType.Cylinder }))
	M.around(16, 0, 2.35, 0, function(cf: CFrame)
		table.insert(U.Gold, piece("Part", Vector3.new(0.95, 0.6, 0.3), CFrame.new(0, 18.4, 4) * CFrame.Angles(math.pi / 2, 0, 0) * cf, C.Gold))
	end)
	for _, sx in ipairs({ -1, 1 }) do
		local base = CFrame.new(sx * 2.75, 17.4, 4.1)
		table.insert(U.Gold, M.frustumN(8, 0.22, 0.16, 0, 0.8, base, { C.Gold, H.scaled(C.Gold, 0.9) }))
		table.insert(U.Gold, chamfered(Vector3.new(0.6, 0.55, 0.22), base * CFrame.new(0, 0.95, -0.05), C.Gold, { "vertical", "topFrontBack" }, 0.1))
		table.insert(U.Inlay, piece("Part", Vector3.new(0.18, 0.35, 0.05), base * CFrame.new(0, 0.95, -0.18), C.Lapis))
		table.insert(U.Gold, chamfered(Vector3.new(0.28, 0.25, 0.4), base * CFrame.new(0, 1.12, -0.2), C.Gold, { "vertical" }, 0.06))
	end
	-- today's 2 spikes as 4-faced gold pyramids (0.8 x 2.4 x 0.8 each quarter: 1.6 square, y 17.4 .. 19.8)
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Gold, M.frustumN(4, 0.8, 0.02, 17.4, 19.8, CFrame.new(sx * 3.6, 0, 4.2) * CFrame.Angles(0, rad(45), 0), { C.Gold, GOLD2, H.scaled(C.Gold, 1.05), H.scaled(GOLD2, 0.95) }))
	end
	finish(m, "pharaoh_throne", U, "Stone", { Glow = M.GLOW })
	return m
end

---------------------------------------------------------------------
-- 01 TERRACOTTA JAR (kit MapAssets.Desert.ClayJar_A, 3 parts; Desert_1 x3, Desert_2 x32, Desert_4 x4)
---------------------------------------------------------------------
M.SHAPES.terracotta_jar = { -- every part collides today
	shape("Cylinder", 2.6, 2.4, 2.4, CFrame.new(0, 1.3, 0) * AXIS_UP), -- Body
	shape("Cylinder", 0.7, 1.4, 1.4, CFrame.new(0, 2.95, 0) * AXIS_UP), -- Neck
	shape("Cylinder", 0.35, 1.9, 1.9, CFrame.new(0, 3.475, 0) * AXIS_UP), -- Rim
}

-- The terracotta jar (B14): the wheel-thrown jar on Agent A's lathe profile (14 sides in 3 clay tones: foot ring,
-- round belly 2.6 wide, shoulder, neck, rolled rim, top y 3.65), a dark painted band (#533E28) on the belly and a
-- cream line on the shoulder, 2 small chips on the rim; its lid with a cream line and a knob (new: the photo shows a
-- lid; top y 4.0). Built as lathe segments (cheap: 41 copies). Parts: Clay, Collision x3.
function Treasures.terracotta_jar(): Model
	local m = Instance.new("Model")
	m.Name = "terracotta_jar"
	H.setBevelSelf(true)
	local U = { Clay = {} }
	local T = { rgb(204, 96, 62), rgb(190, 89, 58), rgb(175, 83, 53) }
	local N = { rgb(188, 88, 57), rgb(175, 82, 53), rgb(162, 76, 49) }
	local DARK, CREAM = rgb(83, 62, 40), rgb(232, 226, 208)
	lathe(U.Clay, 14, {
		{ 0, 0.8, T }, { 0.12, 0.98, T }, { 0.55, 1.2, T }, { 1.15, 1.3, T }, { 1.45, 1.3, { DARK } }, { 1.7, 1.29, T },
		{ 2.05, 1.22, { CREAM } }, { 2.12, 1.18, T }, { 2.55, 0.95, N }, { 2.78, 0.7, N }, { 3.2, 0.66, T },
		{ 3.32, 0.9, T }, { 3.5, 0.96, T }, { 3.65, 0.84, {} },
	})
	for _, a in ipairs({ 0.7, 3.6 }) do
		table.insert(U.Clay, piece("Part", Vector3.new(0.22, 0.12, 0.16), CFrame.new(math.cos(a) * 0.93, 3.6, math.sin(a) * 0.93) * CFrame.Angles(0, -a, rad(30)), rgb(150, 70, 45)))
	end
	-- the lid
	lathe(U.Clay, 14, { { 3.65, 0.95, N }, { 3.75, 0.95, { CREAM } }, { 3.82, 0.7, N }, { 3.86, 0.32, N }, { 3.88, 0.22, N }, { 3.95, 0.26, N }, { 4.0, 0.02, {} } })
	finish(m, "terracotta_jar", U, "Clay")
	return m
end

---------------------------------------------------------------------
-- 02 AMPHORA (kit MapAssets.Desert.ClayJar_B, 7 parts; Desert_2 x7, Desert_4 x6, BA x4)
---------------------------------------------------------------------
M.SHAPES.amphora = { -- every part collides today
	shape("Cylinder", 0.8, 2, 2, CFrame.new(0, 0.4, 0) * AXIS_UP), -- Foot
	shape("Cylinder", 3, 3.4, 3.4, CFrame.new(0, 2.3, 0) * AXIS_UP), -- Body
	shape("Cylinder", 0.6, 3.5, 3.5, CFrame.new(0, 2.3, 0) * AXIS_UP), -- Band
	shape("Cylinder", 1, 1.8, 1.8, CFrame.new(0, 4.3, 0) * AXIS_UP), -- Neck
	shape("Cylinder", 0.4, 2.4, 2.4, CFrame.new(0, 5, 0) * AXIS_UP), -- Rim
	shape("Block", 0.5, 1.6, 0.5, CFrame.new(-1.5, 4, 0)), -- Handle
	shape("Block", 0.5, 1.6, 0.5, CFrame.new(1.5, 4, 0)), -- Handle
}

-- The amphora (B14): on Agent A's lathe profile (14 sides in 3 clay tones, today's sizes: ring foot, waist, belly 3.5
-- wide, shoulder, neck, rolled rim, top y 5.2, a dark mouth): a dark line and today's turquoise band (y 2.0 .. 2.6) on
-- the belly, a dark / cream chequer band on the shoulder, 2 rim chips; 2 curved loop handles (0.35 thick) from the
-- shoulder out 0.45 and back under the rim at today's x +-1.5. Built as lathe segments and bars
-- (cheap: 19 copies). Parts: Clay, Collision x7.
function Treasures.amphora(): Model
	local m = Instance.new("Model")
	m.Name = "amphora"
	H.setBevelSelf(true)
	local U = { Clay = {} }
	local T = { rgb(222, 164, 110), rgb(206, 153, 102), rgb(191, 141, 95) }
	local N = { rgb(206, 152, 102), rgb(192, 141, 95), rgb(177, 131, 88) }
	local DARK, CREAM, TURQ = rgb(83, 62, 40), rgb(232, 226, 208), rgb(64, 208, 196)
	lathe(U.Clay, 14, {
		{ 0, 0.95, T }, { 0.22, 1.0, T }, { 0.45, 0.7, T }, { 0.8, 0.85, T }, { 1.35, 1.45, T }, { 1.85, 1.7, { DARK } },
		{ 2.0, 1.75, { TURQ } }, { 2.6, 1.75, T }, { 2.95, 1.68, T }, { 3.25, 1.55, { DARK, CREAM } }, { 3.45, 1.42, T },
		{ 3.75, 1.18, T }, { 4.05, 0.85, N }, { 4.65, 0.8, N }, { 4.8, 1.12, T }, { 5.0, 1.2, T }, { 5.2, 1.05, {} },
	})
	table.insert(U.Clay, M.drum16(1.75, 0.02, CFrame.new(0, 5.205, 0), rgb(70, 50, 32)))
	for _, a in ipairs({ 1.1, 4.0 }) do
		table.insert(U.Clay, piece("Part", Vector3.new(0.24, 0.12, 0.16), CFrame.new(math.cos(a) * 1.13, 5.14, math.sin(a) * 1.13) * CFrame.Angles(0, -a, rad(30)), rgb(170, 120, 78)))
	end
	-- the 2 loop handles: overlapping bars along a curve (out to x +-1.9: the width stays within +10 %)
	local path = { Vector2.new(1.25, 3.62), Vector2.new(1.6, 3.76), Vector2.new(1.71, 4.2), Vector2.new(1.6, 4.62), Vector2.new(1.28, 4.78), Vector2.new(0.92, 4.74) }
	for _, sx in ipairs({ -1, 1 }) do
		for i = 1, #path - 1 do
			local a = Vector3.new(sx * path[i].X, path[i].Y, 0)
			local b = Vector3.new(sx * path[i + 1].X, path[i + 1].Y, 0)
			table.insert(U.Clay, H.bar(a, b, 0.35, if i % 2 == 0 then T[1] else T[2]))
		end
	end
	finish(m, "amphora", U, "Clay")
	return m
end

---------------------------------------------------------------------
-- 06 GOLDEN LAMP (kit MapAssets.Desert.Lamp_Djinn, 12 parts; BossArenas.Desert x1 at 1.5)
---------------------------------------------------------------------
M.SHAPES.golden_lamp = { -- every part collides today
	shape("Block", 3, 0.8, 3, CFrame.new(0, 0.4, 0) * CFrame.Angles(0, rad(45), 0)), -- Foot
	shape("Block", 1.4, 1, 1.4, CFrame.new(0, 1.3, 0)), -- Stem
	shape("Block", 7, 2.6, 4, CFrame.new(0, 3.1, 0)), shape("Block", 5.4, 1, 3.2, CFrame.new(0, 1.5, 0)), -- Body x2
	shape("Block", 5, 0.9, 3, CFrame.new(0, 4.85, 0)), -- Lid
	shape("Block", 1, 1, 1, CFrame.new(0, 5.8, 0) * CFrame.fromOrientation(rad(45), 0, rad(45))), -- Knob
	shape("Block", 4.6, 1.1, 1.4, CFrame.new(-5, 3.75, 0) * CFrame.Angles(0, 0, rad(-28))), -- Spout
	shape("Block", 1.2, 1, 1.5, CFrame.new(-7.1, 4.9, 0) * CFrame.Angles(0, 0, rad(-28))), -- SpoutTip
	shape("Block", 0.7, 3.4, 0.9, CFrame.new(4.6, 3.5, 0)), -- Handle
	shape("Block", 1.6, 0.7, 0.9, CFrame.new(3.9, 4.95, 0)), shape("Block", 1.6, 0.7, 0.9, CFrame.new(3.9, 2.05, 0)), -- Handle x2
	shape("Block", 7.06, 0.5, 4.06, CFrame.new(0, 3.15, 0)), -- Band
}

-- The golden lamp (B14): today's foot (turned 45) and stem, chamfered, with gold and lapis mouldings; Agent A's genie
-- lamp body (12-sided lathe stretched along X, today's lapis band as a ring, engraved rings, the curved tapered spout to
-- today's tip, the loop handle, a domed lid with a collar and a 4-prong setting) holding Agent A's cut turquoise gem
-- (Neon, today's knob place). The SpoutTip part (invisible, today's place and turn) keeps the Attachment SmokePoint.
-- Parts: Gold, Glow, SpoutTip (+ SmokePoint), Collision x12.
function Treasures.golden_lamp(): Model
	local m = Instance.new("Model")
	m.Name = "golden_lamp"
	H.setBevelSelf(true)
	local U = { Gold = {} }
	local GOLD2 = rgb(229, 180, 53)
	table.insert(U.Gold, chamfered(Vector3.new(3, 0.8, 3), CFrame.new(0, 0.4, 0) * CFrame.Angles(0, rad(45), 0), GOLD2, { "vertical", "topFrontBack", "topSides" }, 0.2))
	table.insert(U.Gold, piece("Part", Vector3.new(3.04, 0.14, 3.04), CFrame.new(0, 0.45, 0) * CFrame.Angles(0, rad(45), 0), C.Lapis))
	table.insert(U.Gold, H.octagon(1.4, 1.0, CFrame.new(0, 1.3, 0), C.Gold))
	table.insert(U.Gold, H.octagon(1.7, 0.16, CFrame.new(0, 0.88, 0), H.scaled(C.Gold, 0.9)))
	facets(U, Data.lamp_body, Vector3.one, CFrame.identity, "Gold")
	facets(U, Data.lamp_gem, Vector3.one, CFrame.identity, "Gold")
	finish(m, "golden_lamp", U, "Gold", { Glow = M.GLOW })
	local tip = piece("Part", Vector3.new(0.4, 0.4, 0.4), CFrame.new(-7.1, 4.9, 0) * CFrame.Angles(0, 0, rad(-28)), GOLD2)
	tip.Transparency = 1
	tip.CastShadow = false
	loosePart(m, "SpoutTip", tip)
	local sp = Instance.new("Attachment")
	sp.Name = "SmokePoint"
	sp.Parent = tip
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into PropsDesert's fresh PropsBatch2 table; its install() builds them
---------------------------------------------------------------------
Treasures.BUILDERS = { desert_rug = true, golden_stand = true, pharaoh_throne = true, terracotta_jar = true, amphora = true, golden_lamp = true }
for id in pairs(Treasures.BUILDERS) do
	B2[id] = (Treasures :: any)[id]
	B2.BUILDERS[id] = true
end
Treasures.install = B2.install
Treasures.SHAPES = M.SHAPES
Treasures.stats = B2.stats

return Treasures
