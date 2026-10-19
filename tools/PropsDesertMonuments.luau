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
-- scales with the smallest axis
local function facetPiece(U: any, data: any, sc: Vector3, frame: CFrame, key: string, recolor: Color3?)
	local ts = math.min(sc.X, sc.Y, sc.Z)
	local colors, lists = {}, {}
	for i, entry in ipairs(data.palette) do
		local hex, mat = string.match(entry, "^(#%x+)|?(%a*)$")
		local c = Color3.fromHex(hex :: string)
		local r, b = c.R * 255, c.B * 255
		local dest = if mat == "Neon" then "Glow" elseif b > r then "Inlay" elseif r > 120 and b < 0.45 * r then "Gold" else key
		if dest == key and recolor then
			c = recolor
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
-- registration: the builders go into PropsDesert's fresh PropsBatch2 table; its install() builds them
---------------------------------------------------------------------
Monuments.BUILDERS = { desert_column = true }
for id in pairs(Monuments.BUILDERS) do
	B2[id] = (Monuments :: any)[id]
	B2.BUILDERS[id] = true
end
Monuments.install = B2.install
Monuments.stats = B2.stats
Monuments.drum16, Monuments.axisFrame, Monuments.tri, Monuments.around = drum16, axisFrame, tri, around
Monuments.facetPiece, Monuments.GLOW = facetPiece, GLOW

return Monuments
