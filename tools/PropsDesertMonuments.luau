--[[
	PropsDesertMonuments (dev tool, Edit mode only) - the owner's "DESERT ZONE PROP IMPROVEMENT - Monuments, statues and
	columns" (2026-10-20, PROMPT_04): the desert column, fallen columns, obelisk, Anubis statue, golden guardian,
	hieroglyph tablet and golden altar rebuilt in the desert recipe (docs/prop_texture_guide.md sections A, B, B13),
	keeping each object's colours, place, size, glow and collision. Source of truth: tools/PropsDesertMonuments.luau.
	Inventory: docs/prop_inventory.md "Desert monuments".

	Collision: the visible unions never collide; invisible "Collision" parts are the kit's colliding parts (same shape,
	size and place), so no copy is more (or less) solid than today.

	It uses DevTools.PropsDesert (its fresh PropsBatch2 table and helpers) and registers its builders there:
		local M = require(game.ServerStorage.DevTools.PropsDesertMonuments:Clone())
		print(M.install("desert_column"))   -- (re)builds ServerStorage.MapProps.desert_column
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "desert_column" } }), Sync.run({ only = { "desert_column" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local D = require(ServerStorage.DevTools.PropsDesert:Clone()) :: any
local Data = require(ServerStorage.DevTools.PropsDesertMonumentsData:Clone()) :: any -- Agent A's facet pieces
local B2 = D.B2
local H = B2.H
local L = D.lib
local C = D.PALETTE
local TONES = H.TONES
local scaled, toneIndex = H.scaled, H.toneIndex
local piece, chamfered, merge = H.piece, H.chamfered, H.merge
local soft = L.soft

local Monuments = {}

local rgb = Color3.fromRGB
local rad = math.rad
local UP = Vector3.yAxis

local SAND = rgb(244, 208, 124)
local STONE, FOOT = C.Sandstone, C.Footing

Monuments.SHAPES = {} -- propId -> the kit's colliding parts { shape, sx, sy, sz, {12 CFrame components} }

-- the kit's colliding parts as separate invisible "Collision" parts
local function collisionParts(m: Model, propId: string)
	for _, e in ipairs(Monuments.SHAPES[propId]) do
		local cf = CFrame.new(table.unpack(e[5])):Orthonormalize()
		local class = if e[1] == "WedgePart" or e[1] == "CornerWedgePart" then e[1] else "Part"
		local p = piece(class, Vector3.new(e[2], e[3], e[4]), cf, STONE, if class == "Part" then { shape = (Enum.PartType :: any)[e[1]] } else nil)
		p.Name = "Collision"
		p.Transparency = 1
		p.CanCollide = true
		p.CanQuery = true
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = m
	end
end

-- merge the lists (sorted names), collision parts, the PrimaryPart `root`, MapPropId
local function finish(m: Model, propId: string, U: any, root: string, extra: any?)
	local opts: any = extra or {}
	if Monuments.SHAPES[propId] then
		collisionParts(m, propId)
	end
	local names = {}
	for name in pairs(U) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local o = { query = name == root }
		if opts[name] then
			for k, v in pairs(opts[name]) do
				o[k] = v
			end
		end
		merge(m, name, U[name], o)
		task.wait()
	end
	local r = m:FindFirstChild(root) :: BasePart
	m.PrimaryPart = r
	r.PivotOffset = r.CFrame:Inverse()
	m:SetAttribute("MapPropId", propId)
	H.setBevelSelf(false)
end

-- a 16-sided drum (w across the flats, h tall) centred at cf
local function drum16(w: number, h: number, cf: CFrame, color: Color3): BasePart
	return H.prism16(w, h, cf * CFrame.Angles(0, rad(11.25), 0), color)
end

-- a frame whose Y axis runs from a to b
local function axisFrame(a: Vector3, b: Vector3): CFrame
	local dir = (b - a).Unit
	local side = if math.abs(dir.Y) > 0.9 then Vector3.xAxis else UP
	local vx = (side - dir * side:Dot(dir)).Unit
	return CFrame.fromMatrix((a + b) / 2, vx, dir)
end

-- a triangle (a wedge pair t thick)
local function tri(list: { BasePart }, a: Vector3, b: Vector3, c: Vector3, t: number, color: Color3)
	H.triangleParts(list, a, b, c, t, CFrame.identity, color)
end

-- one of Agent A's facet pieces (DevTools.PropsDesertMonumentsData) as wedge pairs, scaled by sc in `frame`: each
-- colour goes to U.Glow (a Neon colour), U.Gold (gold hues), U.Inlay (lapis / turquoise) or U[key] (the rest); t
-- scales with the smallest axis. recolor: the colour the piece's first colour becomes (the other U[key] colours keep
-- their ratio to it)
local function facetPiece(U: any, data: any, sc: Vector3, frame: CFrame, key: string, recolor: Color3?)
	local ts = math.min(sc.X, sc.Y, sc.Z)
	local colors, lists = {}, {}
	local base = Color3.fromHex((string.match(data.palette[1], "^(#%x+)")) :: string)
	for i, entry in ipairs(data.palette) do
		local hex, mat = string.match(entry, "^(#%x+)|?(%a*)$")
		local c = Color3.fromHex(hex :: string)
		local r, b = c.R * 255, c.B * 255
		local dest = if mat == "Neon" then "Glow" elseif b > r then "Inlay" elseif r > 120 and b < 0.45 * r then "Gold" else key
		if dest == key and recolor then
			c = Color3.new(math.min(c.R * recolor.R / base.R, 1), math.min(c.G * recolor.G / base.G, 1), math.min(c.B * recolor.B / base.B, 1))
		end
		colors[i] = c
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
local GLOW = { material = Enum.Material.Neon, shadow = false }

-- n pieces around a ring at height y (radius r): fn(list, cf at the ring point facing out (-Z out), k)
local function around(n: number, y: number, r: number, phase: number, fn: any)
	for k = 0, n - 1 do
		local a = phase + k * 2 * math.pi / n
		local cf = CFrame.new(0, y, 0) * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0, -r)
		fn(cf, k)
	end
end

---------------------------------------------------------------------
-- 01 COLUMN (kit MapAssets.Desert.Sandstone_Column, 7 parts, 5.6 x 25 x 5.6; Desert_3 Decor.Ruins x2)
---------------------------------------------------------------------
Monuments.SHAPES.desert_column = { -- every part collides today
	{ "Block", 5.4, 1.6, 5.4, { 0, 0.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Base
	{ "Block", 4.6, 0.8, 4.6, { 0, 2, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Base
	{ "Cylinder", 20, 3.6, 3.6, { 0, 12.4, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1 } }, -- Shaft
	{ "Cylinder", 0.8, 3.9, 3.9, { 0, 6.4, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1 } }, -- Band (gold)
	{ "Cylinder", 0.8, 3.9, 3.9, { 0, 19.4, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1 } }, -- Band (lapis)
	{ "Block", 4.6, 1, 4.6, { 0, 22.9, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Capital
	{ "Block", 5.6, 1.6, 5.6, { 0, 24.2, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Capital (top slab)
}

-- a patterned inlay band round the shaft (16 sides, w across, h tall at y): body colour, gold rules, 16 small
-- accents (diamonds or squares) in the accent colour
local function shaftBand(U: any, y: number, w: number, h: number, body: Color3, accent: Color3, diamonds: boolean)
	local list = if body == C.Gold then U.Gold else U.Inlay
	table.insert(list, drum16(w, h, CFrame.new(0, y, 0), body))
	for _, sy in ipairs({ -1, 1 }) do
		table.insert(U.Gold, drum16(w + 0.12, 0.12, CFrame.new(0, y + sy * (h / 2 + 0.04), 0), scaled(C.Gold, 1.05)))
	end
	local r = w / 2
	around(12, y, r + 0.02, math.pi / 12, function(cf: CFrame, k: number)
		local s = h * (if diamonds then 0.42 else 0.36)
		local pc = cf * CFrame.new(0, 0, -0.01)
		if diamonds then
			pc *= CFrame.Angles(0, 0, rad(45))
		end
		table.insert(if accent == C.Gold then U.Gold else U.Inlay, piece("Part", Vector3.new(s, s, 0.08), pc, if k % 2 == 0 then accent else scaled(accent, 0.9)))
	end)
end

-- an n-sided frustum from apothem r0 at y0 to r1 at y1 (centred on cf's Y axis); colors = the face colours, cycled
local function frustumN(n: number, r0: number, r1: number, y0: number, y1: number, cf: CFrame, colors: { Color3 }): BasePart
	local planes = { { 0, -1, 0, -y0 }, { 0, 1, 0, y1 } }
	for k = 0, n - 1 do
		local a = (k + 0.5) * 2 * math.pi / n
		local nrm = Vector3.new(math.cos(a), (r0 - r1) / (y1 - y0), math.sin(a)).Unit
		table.insert(planes, { nrm.X, nrm.Y, nrm.Z, nrm:Dot(Vector3.new(math.cos(a) * r0, y0, math.sin(a) * r0)), colors[k % #colors + 1] })
	end
	local r = math.max(r0, r1) / math.cos(math.pi / n) + 0.02
	return H.convexSolid(Vector3.new(-r, y0, -r), Vector3.new(r, y1, r), cf, colors[1], planes)
end
Monuments.frustumN = frustumN

-- The column (B13): a carved square base (a chamfered footing, a die with sunk panels and lapis corner diamonds, a
-- top slab, a round plinth with a torus roll 0.4); a fluted 16-sided shaft (2.4 .. 19.0) in drums of 4-4.3 with 0.08
-- joints, tone steps and a slight taper 3.6 -> 3.5, 16 flutes as sunk lines; today's gold band (y 6.4) with 12 lapis
-- diamonds and today's lapis band (y 19.4) with 12 gold squares, both 0.15 proud with gold rules; Agent A's papyrus
-- bell capital facet (19.8 .. 23.4: r 1.85 -> 2.75, 12 petal ribs, 3 gold binding rings, lapis / turquoise petal
-- row, gold lip) in place of today's 4.6 x 1 x 4.6 Capital block; the top slab (today's 5.6 x 1.6)
-- as a chamfered abacus with a turquoise inlay band, lapis diamonds and gold dots; sand drifts at the foot.
-- Parts: Stone, Inlay, Gold, Sand, Collision x7.
function Monuments.desert_column(): Model
	local m = Instance.new("Model")
	m.Name = "desert_column"
	local rng = Random.new(20261210)
	H.setBevelSelf(true)
	local Ht = 25
	local U = { Stone = {}, Inlay = {}, Gold = {}, Sand = {} }
	-- the square base: footing (0 .. 0.5), die with sunk panels (0.5 .. 1.3), top slab (1.3 .. 1.6)
	table.insert(U.Stone, chamfered(Vector3.new(5.4, 0.5, 5.4), CFrame.new(0, 0.25, 0), soft(FOOT, 0.25, Ht, 0.95), { "vertical", "topFrontBack", "topSides" }, 0.15))
	table.insert(U.Stone, chamfered(Vector3.new(5.0, 0.8, 5.0), CFrame.new(0, 0.9, 0), soft(FOOT, 0.9, Ht, 1.0), { "vertical" }, 0.12))
	for face = 0, 3 do
		local f = CFrame.Angles(0, face * math.pi / 2, 0) * CFrame.new(0, 0.9, -2.5)
		table.insert(U.Stone, piece("Part", Vector3.new(3.6, 0.42, 0.04), f * CFrame.new(0, 0, -0.005), scaled(FOOT, 0.78)))
		for _, e in ipairs({ { 0, 0.25, 3.8, 0.08 }, { 0, -0.25, 3.8, 0.08 }, { -1.86, 0, 0.08, 0.5 }, { 1.86, 0, 0.08, 0.5 } }) do
			table.insert(U.Stone, piece("Part", Vector3.new(e[3], e[4], 0.06), f * CFrame.new(e[1], e[2], -0.02), scaled(FOOT, 1.1)))
		end
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(U.Inlay, piece("Part", Vector3.new(0.3, 0.3, 0.05), f * CFrame.new(sx * 2.2, 0, -0.02) * CFrame.Angles(0, 0, rad(45)), C.Lapis))
		end
	end
	table.insert(U.Stone, chamfered(Vector3.new(5.4, 0.3, 5.4), CFrame.new(0, 1.45, 0), soft(FOOT, 1.45, Ht, 1.05), { "vertical", "topFrontBack", "topSides" }, 0.1))
	-- the round plinth (today's 4.6 x 0.8 at 1.6 .. 2.4): a chamfered square, a torus roll 0.4, a fillet
	table.insert(U.Stone, chamfered(Vector3.new(4.6, 0.3, 4.6), CFrame.new(0, 1.75, 0), soft(STONE, 1.75, Ht, 0.96), { "vertical", "topFrontBack", "topSides" }, 0.15))
	table.insert(U.Stone, drum16(4.2, 0.4, CFrame.new(0, 2.1, 0), soft(STONE, 2.0, Ht, 1.04)))
	table.insert(U.Stone, drum16(3.8, 0.1, CFrame.new(0, 2.35, 0), soft(STONE, 2.3, Ht, 0.94)))
	-- the shaft: drums of 4-4.3 with 0.08 joints and tone steps, tapering 3.6 -> 3.45
	local function width(y: number): number
		return 3.6 - 0.15 * (y - 2.4) / 17.8
	end
	local drums = { { 2.4, 6.0 }, { 6.8, 10.9 }, { 10.9, 15.0 }, { 15.0, 19.0 } }
	local prev = nil
	for _, d in ipairs(drums) do
		local y0, y1 = d[1], d[2]
		local ti = toneIndex(rng, prev)
		prev = ti
		local yc = (y0 + y1) / 2
		table.insert(U.Stone, drum16(width(yc), y1 - y0 - 0.06, CFrame.new(0, yc, 0), soft(STONE, yc, Ht, TONES[ti])))
		table.insert(U.Stone, drum16(width(y0) - 0.12, 0.1, CFrame.new(0, y0, 0), scaled(STONE, 0.7)))
	end
	-- 16 flutes: sunk lines on the 16 faces, between the bands
	for _, seg in ipairs({ { 2.6, 5.9 }, { 6.95, 18.85 } }) do
		local y0, y1 = seg[1], seg[2]
		local yc = (y0 + y1) / 2
		around(16, yc, width(yc) / 2 + 0.005, 0, function(cf: CFrame)
			table.insert(U.Stone, piece("Part", Vector3.new(0.14, y1 - y0, 0.04), cf, scaled(STONE, 0.78)))
		end)
	end
	-- today's bands: gold (6.0 .. 6.8) with lapis diamonds, lapis (19.0 .. 19.8) with gold squares
	shaftBand(U, 6.4, 3.9, 0.8, C.Gold, C.Lapis, true)
	shaftBand(U, 19.4, 3.9, 0.8, C.Lapis, C.Gold, false)
	-- the papyrus bell capital (19.8 .. 23.4): Agent A's facet piece (12 petal ribs, 3 gold binding rings, the top
	-- petal row lapis / turquoise, a gold lip), at the kit pivot
	facetPiece(U, Data.column_capital, Vector3.one, CFrame.identity, "Stone")
	-- the top slab (today's 5.6 x 1.6 at 23.4 .. 25): a chamfered abacus with a turquoise inlay band
	table.insert(U.Stone, chamfered(Vector3.new(5.6, 1.6, 5.6), CFrame.new(0, 24.2, 0), soft(FOOT, 24.2, Ht, 1.04), { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.15))
	for face = 0, 3 do
		local f = CFrame.Angles(0, face * math.pi / 2, 0) * CFrame.new(0, 24.2, -2.8)
		table.insert(U.Inlay, piece("Part", Vector3.new(4.9, 0.5, 0.06), f * CFrame.new(0, 0, -0.02), C.Turquoise))
		for i = -4, 4 do
			if i % 2 == 0 then
				table.insert(U.Inlay, piece("Part", Vector3.new(0.32, 0.32, 0.05), f * CFrame.new(i * 0.55, 0, -0.05) * CFrame.Angles(0, 0, rad(45)), C.Lapis))
			else
				table.insert(U.Gold, piece("Part", Vector3.new(0.14, 0.14, 0.05), f * CFrame.new(i * 0.55, 0, -0.05), C.Gold))
			end
		end
		for _, sy in ipairs({ -1, 1 }) do
			table.insert(U.Gold, piece("Part", Vector3.new(4.95, 0.07, 0.06), f * CFrame.new(0, sy * 0.29, -0.03), C.Gold))
		end
	end
	-- sand drifts against two sides of the base
	for _, e in ipairs({ { 0, -2.95, 0 }, { 2.95, 0, -90 } }) do
		table.insert(U.Sand, piece("WedgePart", Vector3.new(4.6, 0.4, 0.5), CFrame.new(e[1], 0.2, e[2]) * CFrame.Angles(0, rad(e[3]), 0), SAND))
	end
	finish(m, "desert_column", U, "Stone")
	return m
end

---------------------------------------------------------------------
-- 02 FALLEN COLUMNS (kit MapAssets.Desert.Sandstone_Column_Broken, 6 parts; Desert_2 Village x1, Desert_3 Ruins x2)
---------------------------------------------------------------------
Monuments.SHAPES.fallen_columns = { -- every part collides today
	{ "Block", 5.4, 1.6, 5.4, { 0, 0.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Base
	{ "Block", 4.6, 0.8, 4.6, { 0, 2, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Base
	{ "Cylinder", 7, 3.6, 3.6, { 0, 5.9, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1 } }, -- Shaft (standing)
	{ "Cylinder", 2.2, 3.5, 3.5, { 0.3, 10, 0.2, 0.208, -0.978, 0, 0.978, 0.208, 0, 0, 0, 1 } }, -- Shaft (broken piece)
	{ "Cylinder", 7, 3.6, 3.6, { 5.5, 1.8, 2.5, 0.819, 0, 0.574, 0, 1, 0, -0.574, 0, 0.819 } }, -- Drum
	{ "Cylinder", 3, 3.6, 3.6, { -4, 1.75, -3.5, 0.499, -0.035, -0.866, 0.07, 0.998, 0, 0.864, -0.06, 0.5 } }, -- Drum
}

-- a fluted 16-sided shaft piece along frame's Y axis from y0 to y1 (w across the flats): drums split at `joints`
-- (0.08 joints with a dark bed ring), tone steps, 16 flutes as sunk lines; tone(yc, factor) gives each drum's colour
local function flutedShaft(list: { BasePart }, frame: CFrame, w: number, y0: number, y1: number, joints: { number }, color: Color3, rng: Random, tone: any)
	local cuts = { y0 }
	for _, j in ipairs(joints) do
		table.insert(cuts, j)
	end
	table.insert(cuts, y1)
	local prev = nil
	for i = 1, #cuts - 1 do
		local a, b = cuts[i], cuts[i + 1]
		local ga = if i > 1 then 0.04 else 0
		local gb = if i < #cuts - 1 then 0.04 else 0
		local ti = toneIndex(rng, prev)
		prev = ti
		table.insert(list, drum16(w, b - a - ga - gb, frame * CFrame.new(0, (a + ga + b - gb) / 2, 0), tone((a + b) / 2, TONES[ti])))
		if i > 1 then
			table.insert(list, drum16(w - 0.12, 0.1, frame * CFrame.new(0, a, 0), scaled(color, 0.7)))
		end
	end
	for k = 0, 15 do
		local cf = frame * CFrame.new(0, (y0 + y1) / 2, 0) * CFrame.Angles(0, -k * math.pi / 8, 0) * CFrame.new(0, 0, -(w / 2 + 0.005))
		table.insert(list, piece("Part", Vector3.new(0.14, y1 - y0 - 0.16, 0.04), cf, scaled(color, 0.78)))
	end
end
Monuments.flutedShaft = flutedShaft

-- The fallen columns (B13): today's 6 pieces in place. The plinth: the lower base split into 2 slabs with a joint and
-- chipped corners, the upper base as a chipped slab, a torus roll; the standing shaft (7 tall) and the 2 fallen drums
-- fluted with drum joints every 3.5; Agent A's broken-end facet on the shaft top, both ends of the tilted broken piece
-- and one end of each fallen drum (the other end shows a flat drum bed); 5 rubble chips and sand drifts against the
-- base and the drums. Parts: Stone, Sand, Collision x6.
function Monuments.fallen_columns(): Model
	local m = Instance.new("Model")
	m.Name = "fallen_columns"
	local rng = Random.new(20261211)
	H.setBevelSelf(true)
	local Ht = 11.1
	local U = { Stone = {}, Sand = {} }
	local LIGHT, DARK = STONE, rgb(213, 179, 124)
	local function chip(x: number, y: number, z: number, s: number): BasePart
		return piece("Part", Vector3.new(s, s * 1.1, s), CFrame.new(x, y, z) * CFrame.Angles(0, rad(45), 0), FOOT)
	end
	-- the lower base (today's 5.4 x 1.6 x 5.4): 2 slabs (x -2.7 .. -0.34 and -0.26 .. 2.7), chipped corners
	table.insert(U.Stone, chamfered(Vector3.new(2.36, 1.6, 5.4), CFrame.new(-1.52, 0.8, 0), soft(FOOT, 0.8, Ht, 0.97), { "vertical", "topFrontBack", "topSides" }, 0.15, { chip(-2.7, 1.6, -2.7, 0.8), chip(-2.7, 0.4, 2.7, 0.5) }))
	table.insert(U.Stone, chamfered(Vector3.new(2.96, 1.6, 5.4), CFrame.new(1.22, 0.8, 0), soft(FOOT, 0.8, Ht, 1.03), { "vertical", "topFrontBack", "topSides" }, 0.15, { chip(2.7, 1.6, 2.7, 0.7) }))
	table.insert(U.Stone, piece("Part", Vector3.new(0.1, 1.4, 5.2), CFrame.new(-0.3, 0.75, 0), scaled(FOOT, 0.7)))
	-- the upper base (today's 4.6 x 0.8 x 4.6 at 1.6 .. 2.4): a chipped slab, a torus roll, a fillet
	table.insert(U.Stone, chamfered(Vector3.new(4.6, 0.3, 4.6), CFrame.new(0, 1.75, 0), soft(STONE, 1.75, Ht, 0.96), { "vertical", "topFrontBack", "topSides" }, 0.15, { chip(2.3, 1.9, -2.3, 0.6) }))
	table.insert(U.Stone, drum16(4.2, 0.4, CFrame.new(0, 2.1, 0), soft(STONE, 2.0, Ht, 1.04)))
	table.insert(U.Stone, drum16(3.8, 0.1, CFrame.new(0, 2.35, 0), soft(STONE, 2.3, Ht, 0.94)))
	-- a broken end (Agent A's facet) at the end of a drum: frame's Y = the drum axis, y = the end, dir = +1 / -1
	local endSc = function(w: number): Vector3
		return Vector3.new(w / 3.6, 1, w / 3.6)
	end
	local function brokenEnd(frame: CFrame, y: number, dir: number, w: number, color: Color3)
		local cf = frame * CFrame.new(0, y, 0) * (if dir < 0 then CFrame.Angles(math.pi, 0, 0) else CFrame.identity)
		facetPiece(U, Data.drum_broken_end, endSc(w), cf, "Stone", color)
	end
	local function flatEnd(frame: CFrame, y: number, dir: number, w: number, color: Color3)
		table.insert(U.Stone, drum16(w - 0.3, 0.06, frame * CFrame.new(0, y + dir * 0.02, 0), scaled(color, 0.88)))
	end
	-- the standing shaft (today's 7 tall, y 2.4 .. 9.4): 2 drums (joint at 5.9), broken top
	local up = CFrame.identity
	flutedShaft(U.Stone, up, 3.6, 2.4, 9.15, { 5.9 }, LIGHT, rng, function(y: number, t: number): Color3
		return soft(LIGHT, y, Ht, t)
	end)
	brokenEnd(up, 9.15, 1, 3.6, LIGHT)
	-- the tilted broken piece (today's 2.2 x 3.5 at (0.3, 10, 0.2), its axis 12 degrees off vertical): broken at both ends
	local axis = Vector3.new(0.208, 0.978, 0)
	local c0 = Vector3.new(0.3, 10, 0.2)
	local f1 = axisFrame(c0 - axis * 1.1, c0 + axis * 1.1)
	flutedShaft(U.Stone, f1, 3.5, -0.85, 0.85, {}, DARK, rng, function(_: number, t: number): Color3
		return soft(DARK, 10, Ht, t)
	end)
	brokenEnd(f1, 0.85, 1, 3.5, DARK)
	brokenEnd(f1, -0.85, -1, 3.5, DARK)
	-- the fallen drums: 7.0 long (joint at the middle; broken toward +axis) and 3.0 long (broken toward +axis)
	local drums = {
		{ Vector3.new(5.5, 1.8, 2.5), Vector3.new(0.819, 0, -0.574), 7, LIGHT, { 0 } },
		{ Vector3.new(-4, 1.75, -3.5), Vector3.new(0.499, 0.07, 0.864), 3, DARK, {} },
	}
	for _, d in ipairs(drums) do
		local half = d[3] / 2
		local f = axisFrame(d[1] - d[2] * half, d[1] + d[2] * half)
		local col = d[4]
		flutedShaft(U.Stone, f, 3.6, -half, half - 0.25, d[5], col, rng, function(_: number, t: number): Color3
			return soft(col, 1.8, Ht, t)
		end)
		brokenEnd(f, half - 0.25, 1, 3.6, col)
		flatEnd(f, -half, -1, 3.6, col)
		-- a sand drift tucked under the drum on its -side
		local side = UP:Cross(d[2]).Unit
		local mid = Vector3.new(d[1].X, 0, d[1].Z)
		for _, sgn in ipairs({ -1, 1 }) do
			local o = mid + side * sgn * 1.25
			table.insert(U.Sand, piece("WedgePart", Vector3.new(d[3] * 0.7, 0.42, 0.8), CFrame.lookAt(Vector3.new(o.X, 0.21, o.Z), Vector3.new(mid.X, 0.21, mid.Z)) * CFrame.Angles(0, math.pi, 0), SAND))
		end
	end
	-- 5 rubble chips (0.4 .. 1.2) round the base and the drums
	for _, e in ipairs({ { 3.2, -1.6, 0.9, 20 }, { -3.1, 1.2, 0.6, 50 }, { 1.4, -3.3, 0.5, 10 }, { -1.2, 3.4, 1.1, 70 }, { 2.6, 4.3, 0.45, 35 } }) do
		local s = e[3]
		table.insert(U.Stone, chamfered(Vector3.new(s, s * 0.6, s * 0.8), CFrame.new(e[1], s * 0.3, e[2]) * CFrame.Angles(0, rad(e[4]), rad(8)), soft(FOOT, 0.3, Ht, TONES[toneIndex(rng, nil)]), { "vertical", "topSides" }, math.min(0.12, s * 0.15)))
	end
	-- sand drifts against the base (front and left)
	for _, e in ipairs({ { 0, -2.95, 0 }, { -2.95, 0, 90 } }) do
		table.insert(U.Sand, piece("WedgePart", Vector3.new(4.4, 0.4, 0.5), CFrame.new(e[1], 0.2, e[2]) * CFrame.Angles(0, rad(e[3]), 0), SAND))
	end
	finish(m, "fallen_columns", U, "Stone")
	return m
end

---------------------------------------------------------------------
-- 03 OBELISK (kit MapAssets.Desert.Obelisk_A, 15 parts; Desert_3 Ruins x1, Desert_4 Props x2 at 0.8)
---------------------------------------------------------------------
local OBELISK_GLYPHS = { -- today's 6 glyphs, kept exactly: { y, sx, sy, z, neon }
	{ 5.9, 0.7, 1.8, -1.95, false },
	{ 8.8, 1.6, 0.6, -1.95, false },
	{ 14.9, 0.7, 1.8, -1.7, true }, -- the glowing yellow mark
	{ 17.8, 1.6, 0.6, -1.7, false },
	{ 23.9, 0.7, 1.8, -1.45, false },
	{ 26.3, 1.6, 0.6, -1.45, false },
}
Monuments.SHAPES.obelisk = { -- every part collides today
	{ "Block", 6.5, 1.5, 6.5, { 0, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Base
	{ "Block", 5, 1.5, 5, { 0, 2.25, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Base
	{ "Block", 3.8, 9, 3.8, { 0, 7.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Shaft
	{ "Block", 3.3, 9, 3.3, { 0, 16.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Shaft
	{ "Block", 2.8, 8, 2.8, { 0, 25, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Shaft
	{ "CornerWedgePart", 1.4, 3, 1.4, { -0.7, 30.5, 0.7, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Tip
	{ "CornerWedgePart", 1.4, 3, 1.4, { 0.7, 30.5, 0.7, 0, 0, 1, 0, 1, 0, -1, 0, 0 } }, -- Tip
	{ "CornerWedgePart", 1.4, 3, 1.4, { 0.7, 30.5, -0.7, -1, 0, 0, 0, 1, 0, 0, 0, -1 } }, -- Tip
	{ "CornerWedgePart", 1.4, 3, 1.4, { -0.7, 30.5, -0.7, 0, 0, -1, 0, 1, 0, 1, 0, 0 } }, -- Tip
}
for _, g in ipairs(OBELISK_GLYPHS) do -- the glyphs collide today too
	table.insert(Monuments.SHAPES.obelisk, { "Block", g[2], g[3], 0.3, { 0, g[1], g[4], 1, 0, 0, 0, 1, 0, 0, 0, 1 } })
end

-- a square frustum (w0 at y0 to w1 at y1, faces toward +-X / +-Z) and a frame on one of its faces: face k (0 = -Z,
-- 1 = -X, 2 = +Z, 3 = +X), at height y, `out` studs off the face, local -Z = out of the face, Y = up the face
local function squareFrustum(w0: number, w1: number, y0: number, y1: number, colors: { Color3 }): BasePart
	return frustumN(4, w0 / 2, w1 / 2, y0, y1, CFrame.Angles(0, rad(45), 0), colors)
end
local function onFace(k: number, w0: number, w1: number, y0: number, y1: number, y: number, out: number): CFrame
	local tilt = math.atan((w0 - w1) / 2 / (y1 - y0))
	local w = w0 + (w1 - w0) * (y - y0) / (y1 - y0)
	return CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, y, -w / 2) * CFrame.Angles(tilt, 0, 0) * CFrame.new(0, 0, -out)
end

-- The obelisk (B13): a 3-step base (a new low step 7.1 x 0.6, today's 6.5 and 5 steps) with block joints every 2.5;
-- today's 3 shaft blocks, each tapering (3.8 -> 3.6, 3.3 -> 3.1, 2.8 -> 2.6) with joint beds between them; a carved
-- glyph column down the front (a shaded band 1.0 wide between raised lips) holding today's 6 glyphs, kept as separate
-- "Glyph" parts (same size, place, colour; the Neon gold mark at y 14.9 stays the glowing mark); plain cartouche frames
-- on the other 3 faces; a 0.3 gold collar and a gold pyramidion whose top 40 % is Neon gold with a warm PointLight.
-- Parts: Stone, Inlay, Gold, Glow (+ PointLight), Glyph x6, Collision x15.
function Monuments.obelisk(): Model
	local m = Instance.new("Model")
	m.Name = "obelisk"
	local rng = Random.new(20261212)
	H.setBevelSelf(true)
	local Ht = 32
	local U = { Stone = {}, Gold = {}, Glow = {} }
	-- the stepped base with block joints every ~2.5
	local steps = { { 7.1, 0, 0.6, FOOT, 0.92 }, { 6.5, 0.6, 1.5, FOOT, 1.0 }, { 5, 1.5, 3, STONE, 0.97 } }
	for _, st in ipairs(steps) do
		local w, y0, y1 = st[1], st[2], st[3]
		local h = y1 - y0
		table.insert(U.Stone, chamfered(Vector3.new(w, h, w), CFrame.new(0, (y0 + y1) / 2, 0), soft(st[4], (y0 + y1) / 2, Ht, st[5]), { "vertical", "topFrontBack", "topSides" }, 0.15))
		local n = math.max(2, math.floor(w / 2.5 + 0.5))
		for face = 0, 3 do
			local f = CFrame.Angles(0, face * math.pi / 2, 0) * CFrame.new(0, (y0 + y1) / 2, -w / 2)
			for i = 1, n - 1 do
				local x = -w / 2 + i * w / n + (if face % 2 == 0 then 0.2 else -0.2)
				table.insert(U.Stone, piece("Part", Vector3.new(0.08, h - 0.2, 0.04), f * CFrame.new(x, -0.05, -0.005), scaled(st[4], 0.72)))
			end
		end
	end
	-- the shaft: 3 tapering blocks with joint beds
	local blocks = { { 3.8, 3.6, 3, 12, STONE }, { 3.3, 3.1, 12, 21, rgb(233, 196, 136) }, { 2.8, 2.6, 21, 29, STONE } }
	for i, b in ipairs(blocks) do
		local w0, w1, y0, y1, col = b[1], b[2], b[3], b[4], b[5]
		local yc = (y0 + y1) / 2
		local ti = toneIndex(rng, nil)
		local c = soft(col, yc, Ht, TONES[ti])
		table.insert(U.Stone, squareFrustum(w0, w1, y0 + (if i > 1 then 0.04 else 0), y1 - 0.04, { scaled(c, 0.97), c, scaled(c, 1.03), scaled(c, 0.95) }))
		if i > 1 then
			table.insert(U.Stone, piece("Part", Vector3.new(w0 - 0.15, 0.1, w0 - 0.15), CFrame.new(0, y0, 0), scaled(col, 0.68)))
		end
		-- the glyph column on the front: a shaded band 1.0 wide (its face just in front of the glyphs' backs) between
		-- 2 raised lips 0.12 wide
		local glyphBack = OBELISK_GLYPHS[i * 2][4] + 0.15
		local bandH = y1 - y0 - 0.7
		table.insert(U.Stone, piece("Part", Vector3.new(1.0, bandH, 0.3), CFrame.new(0, yc, glyphBack - 0.02 + 0.15), scaled(c, 0.86)))
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(U.Stone, piece("Part", Vector3.new(0.12, bandH + 0.2, 0.1), onFace(0, w0, w1, y0, y1, yc, 0.03) * CFrame.new(sx * 0.58, 0, 0), scaled(c, 1.08)))
		end
		for _, sy in ipairs({ -1, 1 }) do
			table.insert(U.Stone, piece("Part", Vector3.new(1.28, 0.12, 0.1), onFace(0, w0, w1, y0, y1, yc + sy * (bandH / 2 + 0.04), 0.03), scaled(c, 1.08)))
		end
		-- plain cartouche frames (0.1 proud) on the other faces
		for k = 1, 3 do
			local fw, fh = w0 * 0.42, bandH * 0.8
			for _, sx in ipairs({ -1, 1 }) do
				table.insert(U.Stone, piece("Part", Vector3.new(0.12, fh, 0.1), onFace(k, w0, w1, y0, y1, yc, 0.03) * CFrame.new(sx * fw / 2, 0, 0), scaled(c, 1.07)))
			end
			for _, sy in ipairs({ -1, 1 }) do
				table.insert(U.Stone, piece("Part", Vector3.new(fw + 0.12, 0.12, 0.1), onFace(k, w0, w1, y0, y1, yc + sy * fh / 2, 0.03), scaled(c, 1.07)))
			end
		end
	end
	-- the gold collar (0.3) and the pyramidion: gold lower 60 %, Neon gold top 40 %
	table.insert(U.Gold, squareFrustum(2.76, 2.74, 28.72, 29.02, { C.Gold, scaled(C.Gold, 0.94) }))
	table.insert(U.Gold, squareFrustum(2.8, 1.12, 29, 30.8, { C.Gold, scaled(C.Gold, 0.95), scaled(C.Gold, 1.04), scaled(C.Gold, 0.9) }))
	table.insert(U.Glow, squareFrustum(1.12, 0.04, 30.8, 32, { C.Gold }))
	-- today's 6 glyphs, exact
	finish(m, "obelisk", U, "Stone", { Glow = GLOW })
	for _, g in ipairs(OBELISK_GLYPHS) do
		local p = piece("Part", Vector3.new(g[2], g[3], 0.3), CFrame.new(0, g[1], g[4]), if g[5] then C.Gold else FOOT, if g[5] then { material = Enum.Material.Neon } else nil)
		p.Name = "Glyph"
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = m
	end
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 214, 120)
	light.Range = 10
	light.Brightness = 1
	light.Shadows = false
	light.Parent = m:FindFirstChild("Glow")
	return m
end
Monuments.OBELISK_GLYPHS = OBELISK_GLYPHS

---------------------------------------------------------------------
-- 06 HIEROGLYPH TABLET (kit MapAssets.Desert.Hieroglyph_Panel, 22 parts, none collides; Desert_3 x1, Desert_4 x24,
-- BossArenas.Desert x20)
---------------------------------------------------------------------
local TABLET_GLYPHS = { -- today's 17 glyph parts (the 12 symbols), kept exactly: { shape, sx, sy, x, y, neon, turn }
	{ "Block", 1.8, 0.5, -3.9, 2.95, false }, -- 1: the bottom-row "PI" (bar + 2 legs)
	{ "Block", 0.5, 1.4, -4.55, 2, false },
	{ "Block", 0.5, 1.4, -3.25, 2, false },
	{ "Cylinder", 1.6, 1.6, -1.3, 2.3, true }, -- 2: gold circle
	{ "Cylinder", 1.6, 1.6, 1.3, 2.3, false }, -- 3: circle
	{ "Block", 1.8, 0.5, 3.9, 2.95, false }, -- 4: "PI"
	{ "Block", 0.5, 1.4, 3.25, 2, false },
	{ "Block", 0.5, 1.4, 4.55, 2, false },
	{ "Cylinder", 1.6, 1.6, -3.9, 5.1, false }, -- 5: circle
	{ "Cylinder", 1.6, 1.6, -1.3, 5.1, false }, -- 6: circle
	{ "Block", 1.3, 1.3, 1.3, 5.05, true, 45 }, -- 7: gold diamond
	{ "Block", 0.5, 2, 3.9, 5.1, false }, -- 8: vertical bar
	{ "Block", 1.8, 0.5, -3.9, 7.35, false }, -- 9: inverted T (bar + stem)
	{ "Block", 0.5, 1.4, -3.9, 8.3, false },
	{ "Block", 0.5, 2, -1.3, 7.9, false }, -- 10: vertical bar
	{ "Block", 0.5, 2, 1.3, 7.9, false }, -- 11: vertical bar
	{ "Cylinder", 1.6, 1.6, 3.9, 7.9, true }, -- 12: gold circle
}
-- a glyph part's CFrame (kit space): circles are Cylinders with their axis along Z (orientation 0, 90, 0)
local function glyphFrame(g: any, z: number): CFrame
	local cf = CFrame.new(g[4], g[5], z)
	if g[1] == "Cylinder" then
		return cf * CFrame.fromOrientation(0, rad(90), 0)
	end
	return cf * CFrame.Angles(0, 0, rad(g[7] or 0))
end
local function glyphSize(g: any, grow: number, t: number): Vector3
	if g[1] == "Cylinder" then
		return Vector3.new(t, g[2] + grow, g[3] + grow)
	end
	return Vector3.new(g[2] + grow, g[3] + grow, t)
end

-- The hieroglyph tablet (B13): the slab 12 x 10 thickened to 1.0 (backwards: the front stays at z -0.5) with a 0.15
-- front chamfer; today's 17 glyph parts (the 12 symbols) kept exactly as separate "Glyph" parts,
-- each now carved: a dark sunk outline 0.06 round it; a carved gold frame in today's border places (0.5 wide, 0.15
-- proud, chamfered, an inner bevel strip 0.1, gold corner rosettes 0.6 with turquoise studs); a dark sandstone stand:
-- a sill 13 x 0.6 x 1.2 under the slab and 2 side pilasters 0.5 x 10.6 x 1.15 with capitals. Nothing collides (as
-- today). Parts: Stone, Carve, Gold, Inlay, Glyph x17.
function Monuments.hieroglyph_tablet(): Model
	local m = Instance.new("Model")
	m.Name = "hieroglyph_tablet"
	H.setBevelSelf(true)
	local Ht = 10
	local U = { Stone = {}, Carve = {}, Gold = {}, Inlay = {} }
	local PANEL = STONE
	-- the slab, front chamfered
	table.insert(U.Stone, chamfered(Vector3.new(12, 10, 1.0), CFrame.new(0, 5, 0), soft(PANEL, 5, Ht, 1.0), { "frontFace" }, 0.15))
	-- each glyph's carved outline: a dark sunk rim 0.06 round it
	for _, g in ipairs(TABLET_GLYPHS) do
		local dark = if g[6] then rgb(138, 106, 30) else scaled(FOOT, 0.62)
		table.insert(U.Carve, piece("Part", glyphSize(g, 0.12, 0.04), glyphFrame(g, -0.51), dark, if g[1] == "Cylinder" then { shape = Enum.PartType.Cylinder } else nil))
	end
	-- the carved gold frame in today's border places (12 x 0.5 at y 0.25 / 9.75, 0.5 x 9 at x +-5.75)
	local bars = { { 0, 0.25, 12, 0.5, 1 }, { 0, 9.75, 12, 0.5, -1 }, { -5.75, 5, 0.5, 9, 1 }, { 5.75, 5, 0.5, 9, -1 } }
	for i, b in ipairs(bars) do
		local horizontal = i <= 2
		table.insert(U.Gold, chamfered(Vector3.new(b[3], b[4], 0.15), CFrame.new(b[1], b[2], -0.575), if horizontal then C.Gold else scaled(C.Gold, 0.96), { "frontFace" }, 0.05))
		-- the inner bevel strip (toward the glyph field)
		local cf = if horizontal then CFrame.new(b[1], b[2] + b[5] * 0.3, -0.54) else CFrame.new(b[1] + b[5] * 0.3, b[2], -0.54)
		local size = if horizontal then Vector3.new(b[3] - 1.0, 0.1, 0.08) else Vector3.new(0.1, b[4] - 0.2, 0.08)
		table.insert(U.Gold, piece("Part", size, cf, scaled(C.Gold, 0.8)))
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, y in ipairs({ 0.25, 9.75 }) do
			table.insert(U.Gold, piece("Part", Vector3.new(0.08, 0.6, 0.6), CFrame.new(sx * 5.75, y, -0.69) * CFrame.fromOrientation(0, rad(90), 0), scaled(C.Gold, 1.05), { shape = Enum.PartType.Cylinder }))
			table.insert(U.Inlay, piece("Part", Vector3.new(0.06, 0.22, 0.22), CFrame.new(sx * 5.75, y, -0.74) * CFrame.fromOrientation(0, rad(90), 0), C.Turquoise, { shape = Enum.PartType.Cylinder }))
		end
	end
	-- the stand: a sill under the slab and 2 side pilasters with capitals (dark sandstone)
	table.insert(U.Stone, chamfered(Vector3.new(13, 0.6, 1.2), CFrame.new(0, -0.3, -0.1), soft(FOOT, 0.2, Ht, 0.95), { "vertical", "topFrontBack", "topSides" }, 0.12))
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Stone, chamfered(Vector3.new(0.5, 9.7, 1.15), CFrame.new(sx * 6.25, 4.85, -0.075), soft(FOOT, 4.85, Ht, 1.02), { "vertical" }, 0.08))
		table.insert(U.Stone, chamfered(Vector3.new(0.62, 0.3, 1.25), CFrame.new(sx * 6.25, 9.85, -0.075), soft(FOOT, 9.85, Ht, 1.06), { "vertical", "topFrontBack", "topSides" }, 0.06))
		for k = 1, 3 do
			table.insert(U.Stone, piece("Part", Vector3.new(0.52, 0.06, 1.17), CFrame.new(sx * 6.25, k * 2.4, -0.075), scaled(FOOT, 0.72)))
		end
	end
	finish(m, "hieroglyph_tablet", U, "Stone")
	-- today's glyph parts, exact (not colliding, queryable, as today)
	for _, g in ipairs(TABLET_GLYPHS) do
		local p = piece("Part", glyphSize(g, 0, 0.2), glyphFrame(g, -0.6), if g[6] then C.Gold else FOOT, {
			shape = if g[1] == "Cylinder" then Enum.PartType.Cylinder else nil,
			material = if g[6] then Enum.Material.Neon else nil,
		})
		p.Name = "Glyph"
		p.CanCollide = false
		p.CanQuery = true
		p.CanTouch = false
		p.Parent = m
	end
	return m
end
Monuments.TABLET_GLYPHS = TABLET_GLYPHS

---------------------------------------------------------------------
-- 07 GOLDEN PYRAMID ALTAR (kit MapAssets.Desert.GoldPile_A, 11 parts; Desert_4 x8, Jungle_4 x2, BossArenas.Desert x11)
---------------------------------------------------------------------
local COIN = { 0, -1, 0, 1, 0, 0, 0, 0, 1 }
local function comps(x: number, y: number, z: number, r: { number }): { number }
	return { x, y, z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9] }
end
Monuments.SHAPES.golden_altar = { -- every part collides today
	{ "Block", 8, 1, 7.4, { 0, 0.5, 0, 0.978, 0, 0.208, 0, 1, 0, -0.208, 0, 0.978 } }, -- Heap (tier 1, turned 12)
	{ "Block", 5.6, 1.1, 5.2, { 0.3, 1.45, -0.2, 0.94, 0, -0.342, 0, 1, 0, 0.342, 0, 0.94 } }, -- Heap (tier 2, -20)
	{ "Block", 3.2, 1.1, 3, { -0.2, 2.45, 0.2, 0.866, 0, 0.5, 0, 1, 0, -0.5, 0, 0.866 } }, -- Heap (tier 3, 30)
	{ "Cylinder", 0.25, 1.1, 1.1, comps(3.6, 0.145, -2.6, COIN) }, -- Coins
	{ "Cylinder", 0.25, 1.1, 1.1, comps(-3.4, 0.145, 2.8, COIN) },
	{ "Cylinder", 0.25, 1.1, 1.1, comps(-3.8, 0.145, -2.2, COIN) },
	{ "Cylinder", 0.25, 1.1, 1.1, comps(2.6, 1.145, 2.2, COIN) },
	{ "Cylinder", 0.25, 1.1, 1.1, comps(-1.2, 3.045, 0, COIN) },
	{ "Block", 1, 1, 1, { 1.4, 2.5, -1.4, 0.866, 0, 0.5, 0.354, 0.707, -0.612, -0.354, 0.707, 0.612 } }, -- Gem
	{ "Block", 0.8, 0.8, 0.8, { -1.8, 1.6, 1.6, 0.985, 0, 0.174, 0.123, 0.707, -0.696, -0.123, 0.707, 0.696 } }, -- Gem
	{ "Cylinder", 1.6, 1.4, 1.4, comps(2.2, 1.7, 0.6, COIN) }, -- Goblet
}

-- The golden pyramid altar (B13): today's 3 tiers (sizes and turns kept) as sandstone steps plated with gold (a gold
-- top plate 0.2 and a gold edge band 0.3 on chamfered sandstone, sunk panels on the faces), 2 front risers 0.4 up to
-- the second tier, gold corner pyramids 0.6; on the top tier Agent A's cut cyan gem in a gold cup with 4 prongs and
-- a cyan PointLight (range 8); today's 2 gems as smaller cut gems at their places (turquoise / cyan); today's 5 coins
-- (embossed) and the goblet (foot, stem, cup with a lapis band) on the second tier. Parts: Stone, Gold, Inlay, Glow
-- (+ PointLight), Collision x11.
function Monuments.golden_altar(): Model
	local m = Instance.new("Model")
	m.Name = "golden_altar"
	H.setBevelSelf(true)
	local Ht = 3.7
	local U = { Stone = {}, Gold = {}, Inlay = {}, Glow = {} }
	local tiers = {
		{ Vector3.new(0, 0, 0), 12, 8, 1, 7.4, FOOT, rgb(234, 184, 55) },
		{ Vector3.new(0.3, 0.9, -0.2), -20, 5.6, 1.1, 5.2, STONE, C.Gold },
		{ Vector3.new(-0.2, 1.9, 0.2), 30, 3.2, 1.1, 3, STONE, rgb(255, 201, 59) },
	}
	local frames = {}
	for i, t in ipairs(tiers) do
		local f = CFrame.new(t[1]) * CFrame.Angles(0, rad(t[2]), 0)
		frames[i] = f
		local w, h, d, stone, gold = t[3], t[4], t[5], t[6], t[7]
		local core = h - 0.2
		table.insert(U.Stone, chamfered(Vector3.new(w - 0.06, core, d - 0.06), f * CFrame.new(0, core / 2, 0), soft(stone, t[1].Y + core / 2, Ht, 1.0), { "vertical" }, 0.15))
		table.insert(U.Gold, chamfered(Vector3.new(w, 0.2, d), f * CFrame.new(0, h - 0.1, 0), gold, { "vertical", "topFrontBack", "topSides" }, 0.08))
		-- the gold edge band 0.3 under the plate, and sunk panels on the stone faces below it
		for face = 0, 3 do
			local along = if face % 2 == 0 then w else d
			local depth = if face % 2 == 0 then d else w
			local ff = f * CFrame.Angles(0, face * math.pi / 2, 0) * CFrame.new(0, 0, -depth / 2 + 0.03)
			table.insert(U.Gold, piece("Part", Vector3.new(along - 0.34, 0.3, 0.06), ff * CFrame.new(0, core - 0.15, -0.02), scaled(gold, 0.9)))
			local ph = core - 0.55
			if ph > 0.15 then
				table.insert(U.Stone, piece("Part", Vector3.new(along - 1.0, ph, 0.03), ff * CFrame.new(0, 0.2 + ph / 2, -0.005), scaled(stone, 0.86)))
			end
		end
	end
	-- 2 front risers 0.4 up to the second tier (on the first tier, in the second tier's frame), gold nosings
	local f2 = frames[2]
	for i, e in ipairs({ { 0.7, 1.0 }, { 0.35, 1.4 } }) do
		local depth, y = e[1], e[2]
		local cf = f2 * CFrame.new(0, y + 0.2 - 0.9, -2.6 - depth / 2 + 0.02)
		table.insert(U.Stone, chamfered(Vector3.new(1.6, 0.4, depth), cf, soft(STONE, y, Ht, 0.95 + 0.05 * i), { "vertical" }, 0.06))
		table.insert(U.Gold, piece("Part", Vector3.new(1.62, 0.06, 0.1), cf * CFrame.new(0, 0.2, -depth / 2 + 0.04), C.Gold))
	end
	-- gold corner pyramids 0.6 on the first tier
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Gold, frustumN(4, 0.3, 0.02, 0, 0.6, frames[1] * CFrame.new(sx * 3.6, 1.0, sz * 3.3) * CFrame.Angles(0, rad(45), 0), { C.Gold, scaled(C.Gold, 0.9) }))
		end
	end
	-- the main gem (Agent A's cut gem, x0.75) in a gold cup with 4 prongs, on the top tier
	local gc = Vector3.new(-0.2, 3.38, 0.2)
	local gs = 0.75
	facetPiece(U, Data.altar_gem, Vector3.one * gs, CFrame.new(gc) * CFrame.Angles(0, rad(22.5), 0), "Glow")
	table.insert(U.Gold, frustumN(8, 0.36, 0.44, 2.98, 3.18, CFrame.new(gc.X, 0, gc.Z) * CFrame.Angles(0, rad(22.5), 0), { C.Gold, scaled(C.Gold, 0.9) }))
	for k = 0, 3 do
		local a = rad(22.5 + 45 + k * 90)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		table.insert(U.Gold, H.bar(gc + dir * 0.4 + Vector3.new(0, -0.3, 0), gc + dir * 0.47 + Vector3.new(0, 0.12, 0), 0.15, scaled(C.Gold, 1.05)))
	end
	-- today's 2 gems as smaller cut gems at their places
	facetPiece(U, Data.altar_gem, Vector3.one * 0.7, CFrame.new(1.4, 2.42, -1.4) * CFrame.Angles(0, rad(40), 0), "Glow", rgb(64, 208, 196))
	facetPiece(U, Data.altar_gem, Vector3.one * 0.55, CFrame.new(-1.8, 2.24, 1.6) * CFrame.Angles(0, rad(10), 0), "Glow", rgb(95, 212, 255))
	-- today's 5 coins, embossed
	for _, p in ipairs({ { 3.6, 0.145, -2.6 }, { -3.4, 0.145, 2.8 }, { -3.8, 0.145, -2.2 }, { 2.6, 1.145, 2.2 }, { -1.2, 3.045, 0 } }) do
		local cf = CFrame.new(p[1], p[2], p[3])
		table.insert(U.Gold, drum16(1.1, 0.25, cf, rgb(255, 201, 59)))
		table.insert(U.Gold, drum16(0.72, 0.04, cf * CFrame.new(0, 0.13, 0), rgb(219, 173, 52)))
		table.insert(U.Gold, piece("Part", Vector3.new(0.28, 0.05, 0.28), cf * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, rad(45), 0), rgb(255, 214, 90)))
	end
	-- the goblet on the second tier (today's at (2.2, 0.6)): foot, stem with a knop, cup with a lapis band, rim
	local gob = CFrame.new(2.2, 2.0, 0.6)
	local GOB = rgb(242, 190, 56)
	table.insert(U.Gold, drum16(0.9, 0.1, gob * CFrame.new(0, 0.05, 0), scaled(GOB, 0.92)))
	table.insert(U.Gold, drum16(0.24, 0.3, gob * CFrame.new(0, 0.25, 0), GOB))
	table.insert(U.Gold, drum16(0.42, 0.1, gob * CFrame.new(0, 0.26, 0), scaled(GOB, 1.06)))
	table.insert(U.Gold, frustumN(12, 0.14, 0.32, 0.4, 0.86, gob, { GOB, scaled(GOB, 0.93) }))
	table.insert(U.Inlay, frustumN(12, 0.235, 0.27, 0.58, 0.68, gob, { C.Lapis }))
	table.insert(U.Gold, frustumN(12, 0.33, 0.33, 0.84, 0.9, gob, { scaled(GOB, 1.08) }))
	table.insert(U.Gold, drum16(0.56, 0.02, gob * CFrame.new(0, 0.9, 0), scaled(GOB, 0.6)))
	finish(m, "golden_altar", U, "Stone", { Glow = GLOW })
	local light = Instance.new("PointLight")
	light.Color = rgb(95, 212, 255)
	light.Range = 8
	light.Brightness = 1
	light.Shadows = false
	light.Parent = m:FindFirstChild("Glow")
	return m
end

---------------------------------------------------------------------
-- 04 ANUBIS STATUE (kit MapAssets.Desert.JackalStatue, 34 parts; Desert_3 x2, Desert_4 x6, Desert_4 BossGate x2,
-- BossArenas.Desert x4)
---------------------------------------------------------------------
local function box(sx: number, sy: number, sz: number, x: number, y: number, z: number, rz: number?): any
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, 0, rad(rz or 0))
	return { "Block", sx, sy, sz, { cf:GetComponents() } }
end
Monuments.SHAPES.anubis_statue = { -- every part collides today (34 blocks)
	box(8, 2, 11, 0, 1, 0), box(7, 0.6, 10, 0, 2.3, 0), -- Plinth
	box(5.2, 4.2, 4.6, 0, 4.7, 2.2), box(5.6, 8, 1.2, 0, 6.6, 4.6), -- Seat, SeatBack
	box(4.6, 6.2, 2.6, 0, 10.3, 2.1), box(4.2, 1.4, 2.9, 0, 7.9, 2.1), box(1.6, 2.6, 0.4, 0, 7.3, 0.7), -- Torso, Belt, Kilt
	box(5.2, 1, 3.2, 0, 13.5, 2.1), box(3.6, 0.6, 2.9, 0, 12.8, 2), box(1.6, 1.2, 1.6, 0, 14.6, 2.1), -- Collar x2, Neck
	box(2.8, 2.8, 3, 0, 16.4, 2.1), box(1.5, 1.3, 2.8, 0, 15.85, -0.4), box(1.6, 0.5, 0.5, 0, 15.45, -1.9), -- Head, Snout, Nose
	box(3, 0.7, 3.2, 0, 17.75, 2.2), -- Crown
}
for _, sx in ipairs({ -1, 1 }) do
	for _, b in ipairs({
		box(1.8, 1.7, 4.8, sx * 1.3, 7.65, 0.2), box(1.6, 4.3, 1.6, sx * 1.3, 4.75, -1.6), box(1.8, 0.8, 2.6, sx * 1.3, 3, -2.2), -- Thigh, Shin, Foot
		box(1.3, 3.8, 1.3, sx * 2.9, 11.1, 1.9), box(1.3, 1.2, 3.6, sx * 2.9, 9, 0.3), -- Arm, Forearm
		box(1.4, 0.7, 1.4, sx * 2.9, 10.75, 1.9), box(1.5, 0.6, 1.5, sx * 1.3, 3.9, -1.6), -- Armband, Anklet
		box(0.7, 2.6, 0.7, sx * 0.95, 18.9, 2.2, -sx * 6), box(0.5, 0.4, 0.3, sx * 0.7, 16.8, 0.55), box(0.9, 4.4, 2.2, sx * 1.85, 14.8, 2.4), -- Ear, Eye, Nemes
	}) do
		table.insert(Monuments.SHAPES.anubis_statue, b)
	end
end

-- a gold ring 0.1 proud round a square limb (w across) at y, h tall, with one lapis stripe
local function limbRing(U: any, x: number, y: number, z: number, w: number, h: number)
	table.insert(U.Gold, chamfered(Vector3.new(w + 0.2, h, w + 0.2), CFrame.new(x, y, z), C.Gold, { "vertical" }, 0.06))
	table.insert(U.Inlay, piece("Part", Vector3.new(w + 0.24, 0.12, w + 0.24), CFrame.new(x, y, z), C.Lapis))
end

-- The Anubis statue (B13): today's seated pose, sizes and places. A 2-step plinth (chamfered, corner notches, a front
-- inscription panel recessed with a gold frame and carved signs); the throne (seat with sunk side panels and a gold /
-- lapis band, the back with a cornice); the body in #8C6844 with tone steps: thighs with knee caps, shins tapering
-- 1.6 -> 1.3 to the ankle, feet on sandals (sole #966840 0.2, a gold strap over the toes, toe grooves), gold anklets
-- and arm bands with a lapis stripe, forearms on the thighs with hands (3 finger grooves), a torso with pectorals, the
-- gold belt with a buckle panel, the lapis pleated kilt (6 fanning pleats, a gold hem); the nemes lappets with 4 gold
-- stripes; Agent A's `anubis__head` (skull, long snout, gold nose, almond Neon eyes, tall ears with gold inner faces,
-- the gold crown band) and `anubis__collar` (3 beaded rings) facets. No part is named "Interact" (BossService).
-- Parts: Stone, Body, Inlay, Gold, Glow, Collision x34.
function Monuments.anubis_statue(): Model
	local m = Instance.new("Model")
	m.Name = "anubis_statue"
	local rng = Random.new(20261214)
	H.setBevelSelf(true)
	local Ht = 20.2
	local U = { Stone = {}, Body = {}, Inlay = {}, Gold = {}, Glow = {} }
	local BODY, DARK, SOLE = rgb(140, 104, 68), rgb(83, 62, 40), rgb(150, 104, 64)
	local function body(y: number): Color3
		return soft(BODY, y, Ht, TONES[toneIndex(rng, nil)])
	end
	local function notch(x: number, y: number, z: number, s: number): BasePart
		return piece("Part", Vector3.new(s, s * 1.2, s), CFrame.new(x, y, z) * CFrame.Angles(0, rad(45), 0), FOOT)
	end
	-- the plinth: 2 chamfered steps with corner notches
	table.insert(U.Stone, chamfered(Vector3.new(8, 2, 11), CFrame.new(0, 1, 0), soft(FOOT, 1, Ht, 1.0), { "vertical", "topFrontBack", "topSides" }, 0.15, { notch(4, 2, -5.5, 0.6), notch(-4, 2, 5.5, 0.5) }))
	table.insert(U.Stone, chamfered(Vector3.new(7, 0.6, 10), CFrame.new(0, 2.3, 0), soft(STONE, 2.3, Ht, 0.98), { "vertical", "topFrontBack", "topSides" }, 0.12))
	-- the front inscription panel (recessed 0.1) with a gold frame 0.15 and carved signs
	local pf = CFrame.new(0, 1.0, -5.5)
	table.insert(U.Stone, piece("Part", Vector3.new(5.2, 1.2, 0.04), pf * CFrame.new(0, 0, -0.01), scaled(FOOT, 0.8)))
	for _, e in ipairs({ { 0, 0.68, 5.6, 0.15 }, { 0, -0.68, 5.6, 0.15 }, { -2.73, 0, 0.15, 1.5 }, { 2.73, 0, 0.15, 1.5 } }) do
		table.insert(U.Gold, piece("Part", Vector3.new(e[3], e[4], 0.1), pf * CFrame.new(e[1], e[2], -0.04), C.Gold))
	end
	for i, sgn in ipairs({ { "bar", 0.12, 0.8 }, { "ring", 0.5, 0.5 }, { "bar", 0.7, 0.12 }, { "ring", 0.5, 0.5 }, { "bar", 0.12, 0.8 }, { "step", 0.6, 0.3 }, { "bar", 0.12, 0.8 } }) do
		local x = -2.1 + (i - 1) * 0.7
		if sgn[1] == "ring" then
			table.insert(U.Stone, piece("Part", Vector3.new(0.05, sgn[2], sgn[3]), pf * CFrame.new(x, 0.05, -0.04) * CFrame.fromOrientation(0, rad(90), 0), scaled(FOOT, 0.62), { shape = Enum.PartType.Cylinder }))
		else
			table.insert(U.Stone, piece("Part", Vector3.new(sgn[2], sgn[3], 0.05), pf * CFrame.new(x, 0, -0.04), scaled(FOOT, 0.62)))
		end
	end
	-- the throne: the seat (sunk side panels, a gold / lapis band) and the back (a cornice, a sunk panel)
	table.insert(U.Stone, chamfered(Vector3.new(5.2, 4.2, 4.6), CFrame.new(0, 4.7, 2.2), soft(STONE, 4.7, Ht, 1.02), { "vertical", "topFrontBack", "topSides" }, 0.12))
	for _, sx in ipairs({ -1, 1 }) do
		local sf = CFrame.new(sx * 2.6, 4.5, 2.2) * CFrame.Angles(0, -sx * math.pi / 2, 0)
		table.insert(U.Stone, piece("Part", Vector3.new(3.4, 2.6, 0.04), sf * CFrame.new(0, -0.2, -0.01), scaled(STONE, 0.84)))
		table.insert(U.Gold, piece("Part", Vector3.new(4.4, 0.18, 0.06), sf * CFrame.new(0, 1.55, -0.02), C.Gold))
		table.insert(U.Inlay, piece("Part", Vector3.new(4.4, 0.2, 0.05), sf * CFrame.new(0, 1.35, -0.02), C.Lapis))
	end
	table.insert(U.Stone, chamfered(Vector3.new(5.6, 7.6, 1.2), CFrame.new(0, 6.4, 4.6), soft(STONE, 6.4, Ht, 0.97), { "vertical" }, 0.12))
	table.insert(U.Stone, chamfered(Vector3.new(5.9, 0.4, 1.4), CFrame.new(0, 10.4, 4.6), soft(STONE, 10.4, Ht, 1.06), { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.08))
	table.insert(U.Gold, piece("Part", Vector3.new(5.64, 0.15, 1.24), CFrame.new(0, 10.1, 4.6), C.Gold))
	table.insert(U.Stone, piece("Part", Vector3.new(4.2, 6.0, 0.04), CFrame.new(0, 6.4, 5.21), scaled(STONE, 0.86)))
	-- the legs: thighs (knee caps), tapering shins, anklets, feet on sandals
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 1.3
		table.insert(U.Body, chamfered(Vector3.new(1.8, 1.7, 4.8), CFrame.new(x, 7.65, 0.2), body(7.6), { "vertical", "topFrontBack", "topSides" }, 0.18))
		table.insert(U.Body, chamfered(Vector3.new(1.3, 0.9, 0.35), CFrame.new(x, 7.2, -2.3), body(7.2), { "vertical", "topFrontBack" }, 0.1))
		table.insert(U.Body, squareFrustum(1.3, 1.6, 3.35, 6.9, { body(5), body(5.1), body(5.2), body(5.3) }))
		U.Body[#U.Body].CFrame = CFrame.new(x, 0, -1.6) * U.Body[#U.Body].CFrame
		table.insert(U.Body, chamfered(Vector3.new(1.0, 0.8, 0.3), CFrame.new(x, 6.45, -2.47), body(6.4), { "vertical", "topFrontBack", "bottomFrontBack" }, 0.1))
		limbRing(U, x, 3.85, -1.6, 1.32, 0.5)
		-- the sandal (sole 0.2 + gold strap) and the foot with 3 toe grooves
		table.insert(U.Body, chamfered(Vector3.new(1.9, 0.2, 2.7), CFrame.new(x, 2.7, -2.2), SOLE, { "vertical" }, 0.08))
		table.insert(U.Body, chamfered(Vector3.new(1.7, 0.6, 2.5), CFrame.new(x, 3.1, -2.2), soft(DARK, 3.1, Ht, 1.0), { "vertical", "topFrontBack" }, 0.15))
		for k = -1, 1 do
			table.insert(U.Body, piece("Part", Vector3.new(0.05, 0.3, 0.5), CFrame.new(x + k * 0.42, 3.05, -3.22), scaled(DARK, 0.6)))
		end
		table.insert(U.Gold, piece("Part", Vector3.new(1.76, 0.15, 0.3), CFrame.new(x, 3.42, -2.9), C.Gold))
		table.insert(U.Gold, piece("Part", Vector3.new(0.15, 0.62, 1.2), CFrame.new(x, 3.15, -1.9), C.Gold))
		-- the arms: upper arm, arm band, forearm on the thigh, hand with 3 finger grooves
		local ax = sx * 2.9
		table.insert(U.Body, chamfered(Vector3.new(1.3, 3.8, 1.3), CFrame.new(ax, 11.1, 1.9), body(11), { "vertical", "topFrontBack", "topSides" }, 0.18))
		limbRing(U, ax, 10.75, 1.9, 1.3, 0.5)
		table.insert(U.Body, chamfered(Vector3.new(1.3, 1.2, 3.6), CFrame.new(ax, 9, 0.3), body(9), { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.15))
		table.insert(U.Body, chamfered(Vector3.new(1.1, 1.0, 1.0), CFrame.new(ax, 8.9, -1.9), body(8.9), { "vertical", "topFrontBack", "topSides" }, 0.12))
		for k = -1, 1 do
			table.insert(U.Body, piece("Part", Vector3.new(1.12, 0.05, 0.6), CFrame.new(ax, 8.9 + k * 0.25, -2.1), scaled(BODY, 0.62)))
		end
		-- the nemes lappet with 4 gold stripes
		local nx = sx * 1.85
		table.insert(U.Inlay, chamfered(Vector3.new(0.9, 4.4, 2.2), CFrame.new(nx, 14.8, 2.4), C.Lapis, { "vertical", "bottomFrontBack", "bottomSides" }, 0.12))
		for k = 0, 3 do
			local y = 13.2 + k * 0.9
			table.insert(U.Gold, piece("Part", Vector3.new(0.94, 0.15, 2.24), CFrame.new(nx, y, 2.4), C.Gold))
		end
	end
	-- the torso: pectorals, a central line, the belt with a buckle panel, the kilt band
	table.insert(U.Body, chamfered(Vector3.new(4.6, 6.2, 2.6), CFrame.new(0, 10.3, 2.1), body(10.3), { "vertical", "topFrontBack", "topSides" }, 0.3))
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Body, chamfered(Vector3.new(1.8, 1.2, 0.2), CFrame.new(sx * 1.0, 11.8, 0.75), body(11.8), { "vertical", "bottomFrontBack" }, 0.08))
	end
	table.insert(U.Body, piece("Part", Vector3.new(0.08, 2.4, 0.06), CFrame.new(0, 10.0, 0.78), scaled(BODY, 0.72)))
	table.insert(U.Gold, chamfered(Vector3.new(4.4, 0.6, 3.0), CFrame.new(0, 8.3, 2.1), C.Gold, { "vertical" }, 0.1))
	table.insert(U.Gold, chamfered(Vector3.new(1.0, 0.75, 0.12), CFrame.new(0, 8.3, 0.56), scaled(C.Gold, 1.06), { "vertical" }, 0.05))
	table.insert(U.Inlay, piece("Part", Vector3.new(0.5, 0.35, 0.06), CFrame.new(0, 8.3, 0.49), C.Turquoise))
	table.insert(U.Inlay, chamfered(Vector3.new(4.3, 0.8, 2.95), CFrame.new(0, 7.6, 2.1), C.Lapis, { "vertical" }, 0.1))
	-- the pleated kilt apron (today's 1.6 x 2.6 at z 0.7): 6 pleats fanning, a gold hem
	for k = 0, 5 do
		local x = -0.625 + k * 0.25
		local tone = if k % 2 == 0 then C.Lapis else scaled(C.Lapis, 0.93)
		table.insert(U.Inlay, piece("Part", Vector3.new(0.25, 2.3, 0.3), CFrame.new(x, 7.25, 0.7) * CFrame.Angles(0, 0, rad(-x * 4)), tone))
	end
	table.insert(U.Gold, piece("Part", Vector3.new(1.7, 0.14, 0.34), CFrame.new(0, 6.08, 0.7), C.Gold))
	-- the neck
	table.insert(U.Body, chamfered(Vector3.new(1.6, 1.4, 1.6), CFrame.new(0, 14.6, 2.1), body(14.6), { "vertical" }, 0.25))
	-- Agent A's head and collar
	facetPiece(U, Data.anubis_head, Vector3.one, CFrame.identity, "Body")
	facetPiece(U, Data.anubis_collar, Vector3.one, CFrame.identity, "Gold")
	finish(m, "anubis_statue", U, "Stone", { Glow = GLOW })
	return m
end

---------------------------------------------------------------------
-- 05 GOLDEN GUARDIAN / SPHINX (kit MapAssets.Desert.Sarcophagus_Small, 12 parts; Desert_4 Props x4 at 1.2)
---------------------------------------------------------------------
Monuments.SHAPES.golden_guardian = { -- every part collides today
	box(5, 0.8, 10, 0, 0.4, 0), box(4, 2.2, 9, 0, 1.9, 0), -- Base, Box
	box(4.3, 0.9, 9.3, 0, 3.45, 0), box(3, 0.6, 6.5, 0, 4.2, 0.8), -- Lid x2
	box(4.34, 0.92, 0.6, 0, 3.46, -0.5), box(4.34, 0.92, 0.6, 0, 3.46, 1), box(4.34, 0.92, 0.6, 0, 3.46, 2.5), box(4.34, 0.92, 0.6, 0, 3.46, 4), -- Stripes
	box(2.6, 1.2, 2.2, 0, 4.5, -3.3), box(3.4, 1, 0.8, 0, 4.4, -2.2), -- Head, Nemes
	box(0.4, 0.3, 0.3, -0.6, 4.75, -4.4), box(0.4, 0.3, 0.3, 0.6, 4.75, -4.4), -- Eyes
}

-- The golden guardian (B13): a lying sphinx on today's base, head toward -Z. The base carved (0.15 chamfer, a lapis
-- band 0.3 round it, 4 corner blocks); the body block (today's 4 x 2.2 x 9) with sunk side panels and a gold rule;
-- the gold lid with today's 4 lapis stripes at the same z (chamfered bands) and gold plates 0.08 proud between them,
-- on the sides and on the upper lid (the back, with lapis inlay strips at the stripes' z); Agent A's `sphinx__head`
-- (gold face, Neon turquoise eyes at today's places, a nemes of gold / lapis bands, a gold cobra badge) and
-- `sphinx__paws` (2 gold paws stretched forward with toe grooves) facets. Parts: Stone, Gold, Inlay, Glow, Collision x12.
function Monuments.golden_guardian(): Model
	local m = Instance.new("Model")
	m.Name = "golden_guardian"
	H.setBevelSelf(true)
	local Ht = 5.6
	local U = { Stone = {}, Gold = {}, Inlay = {}, Glow = {} }
	local LID2 = rgb(234, 184, 55)
	-- the base: chamfered, a lapis band 0.3 round it, 4 corner blocks
	table.insert(U.Stone, chamfered(Vector3.new(5, 0.8, 10), CFrame.new(0, 0.4, 0), soft(FOOT, 0.4, Ht, 1.0), { "vertical", "topFrontBack", "topSides" }, 0.15))
	table.insert(U.Inlay, piece("Part", Vector3.new(5.06, 0.3, 10.06), CFrame.new(0, 0.4, 0), C.Lapis))
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Stone, chamfered(Vector3.new(0.7, 0.95, 0.7), CFrame.new(sx * 2.2, 0.475, sz * 4.7), soft(FOOT, 0.5, Ht, 1.08), { "vertical", "topFrontBack", "topSides" }, 0.08))
		end
	end
	-- the body block with sunk side panels (2 per side), a gold rule under the lid
	table.insert(U.Stone, chamfered(Vector3.new(4, 2.2, 9), CFrame.new(0, 1.9, 0), soft(STONE, 1.9, Ht, 1.0), { "vertical" }, 0.12))
	for _, sx in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -2.1, 2.1 }) do
			table.insert(U.Stone, piece("Part", Vector3.new(0.04, 1.4, 3.6), CFrame.new(sx * 2.005, 1.8, z), scaled(STONE, 0.84)))
		end
		table.insert(U.Gold, piece("Part", Vector3.new(0.06, 0.14, 8.8), CFrame.new(sx * 2.02, 2.85, 0), C.Gold))
	end
	for _, sz in ipairs({ -1, 1 }) do
		table.insert(U.Stone, piece("Part", Vector3.new(3.4, 1.4, 0.04), CFrame.new(0, 1.8, sz * 4.505), scaled(STONE, 0.84)))
	end
	-- the gold lid, today's 4 lapis stripes (same z), gold plates 0.08 proud between them on the sides
	table.insert(U.Gold, chamfered(Vector3.new(4.3, 0.9, 9.3), CFrame.new(0, 3.45, 0), C.Gold, { "vertical", "topFrontBack", "topSides" }, 0.1))
	local stripes = { -0.5, 1, 2.5, 4 }
	for _, z in ipairs(stripes) do
		table.insert(U.Inlay, chamfered(Vector3.new(4.34, 0.92, 0.6), CFrame.new(0, 3.46, z), C.Lapis, { "topSides" }, 0.08))
	end
	local gaps = { { -4.6, -0.8 }, { -0.2, 0.7 }, { 1.3, 2.2 }, { 2.8, 3.7 }, { 4.3, 4.6 } }
	for i, g in ipairs(gaps) do
		local len = g[2] - g[1] - 0.12
		if len > 0.1 then
			for _, sx in ipairs({ -1, 1 }) do
				table.insert(U.Gold, chamfered(Vector3.new(0.08, 0.6, len), CFrame.new(sx * 2.19, 3.42, (g[1] + g[2]) / 2), scaled(C.Gold, if i % 2 == 0 then 1.05 else 0.95), { "vertical" }, 0.03))
			end
		end
	end
	-- the upper lid (the back): gold plates 0.08 proud with lapis inlay strips at the stripes' z
	table.insert(U.Gold, chamfered(Vector3.new(3, 0.6, 6.5), CFrame.new(0, 4.2, 0.8), LID2, { "vertical", "topFrontBack", "topSides" }, 0.12))
	for i, g in ipairs({ { -1.8, -0.8 }, { -0.2, 0.7 }, { 1.3, 2.2 }, { 2.8, 3.7 } }) do
		table.insert(U.Gold, chamfered(Vector3.new(2.6, 0.08, g[2] - g[1] - 0.1), CFrame.new(0, 4.54, (g[1] + g[2]) / 2), scaled(C.Gold, if i % 2 == 0 then 1.04 else 0.97), { "vertical" }, 0.04))
	end
	for _, z in ipairs({ -0.5, 1, 2.5 }) do
		table.insert(U.Inlay, piece("Part", Vector3.new(2.7, 0.07, 0.5), CFrame.new(0, 4.535, z), C.Lapis))
	end
	-- Agent A's head and paws
	-- (the head scaled 0.96 in height about its base y 3.95: the top 5.62 -> 5.55, within +10 % of today's 5.1)
	facetPiece(U, Data.sphinx_head, Vector3.new(1, 0.96, 1), CFrame.new(0, 3.95 * 0.04, 0), "Gold")
	facetPiece(U, Data.sphinx_paws, Vector3.one, CFrame.identity, "Gold")
	finish(m, "golden_guardian", U, "Stone", { Glow = GLOW })
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into PropsDesert's fresh PropsBatch2 table; its install() builds them
---------------------------------------------------------------------
Monuments.BUILDERS = { desert_column = true, fallen_columns = true, obelisk = true, hieroglyph_tablet = true, golden_altar = true, anubis_statue = true, golden_guardian = true }
for id in pairs(Monuments.BUILDERS) do
	B2[id] = (Monuments :: any)[id]
	B2.BUILDERS[id] = true
end
Monuments.install = B2.install
Monuments.stats = B2.stats
Monuments.drum16, Monuments.axisFrame, Monuments.tri, Monuments.around = drum16, axisFrame, tri, around
Monuments.facetPiece, Monuments.GLOW, Monuments.finish = facetPiece, GLOW, finish
Monuments.D = D

return Monuments
