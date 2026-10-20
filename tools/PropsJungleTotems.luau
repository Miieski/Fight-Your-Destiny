--[[
	PropsJungleTotems (dev tool, Edit mode only) - the owner's "JUNGLE ZONE PROP IMPROVEMENT - Totems, shrines and
	water" (2026-10-20, jungle PROMPT_04): the tall totem pole, the totem figure, the golden shrine and the water pool
	with gold corners rebuilt in the jungle recipe (docs/prop_texture_guide.md sections A, C1, C2, C5), keeping each
	object's colours, place, size, function and collision. Source of truth: tools/PropsJungleTotems.luau.
	Inventory: docs/prop_inventory.md "Jungle totems".

	Collision: the visible unions never collide; invisible "Collision" parts are the kit's colliding parts (same shape,
	size and place), so no copy is more (or less) solid than today. None of the four has a script, prompt, tag or touch
	handler (checked in Studio and src/); the pool's water is a plain non-colliding part (not terrain): players walk
	through it, as today.

	It uses DevTools.PropsJungleRuins (and through it the jungle gates / buildings / desert helpers, finish() and the
	SHAPES table) and registers its builders into the same PropsBatch2 table:
		local T = require(game.ServerStorage.DevTools.PropsJungleTotems:Clone())
		print(T.install("jungle_temple_pool"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.run({ only = { "jungle_temple_pool" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local R = require(ServerStorage.DevTools.PropsJungleRuins:Clone()) :: any
local G = R.G
local J = G.J
local M, B2, H = J.M, J.B2, J.H
local piece, chamfered = H.piece, H.chamfered
local finish = M.finish
local P = J.PALETTE
local MOSS = P.MOSS
local mossMat, partDrape, looseStone = R.mossMat, R.partDrape, R.looseStone
local TData = require(ServerStorage.DevTools.PropsJungleTotemsData:Clone()) :: any -- Agent A's totem / shrine / pool facets
local RData = require(ServerStorage.DevTools.PropsJungleRuinsData:Clone()) :: any -- the ruins' tuft and fern

local Totems = {}

local rgb = Color3.fromRGB
local rad = math.rad

-- shared colours (C5 "real colours")
local GOLD = rgb(255, 201, 60) -- #FFC93C
local GOLD_DARK = rgb(229, 180, 53) -- #E5B435 (engraved lines)
local STONE = rgb(132, 138, 124) -- #848A7C
local STONE_DARK = rgb(92, 100, 92) -- #5C645C
local CORE = rgb(52, 58, 52)
local WATER = rgb(48, 196, 190) -- #30C4BE
local BASIN = rgb(30, 140, 150) -- #1E8C96
local WET = rgb(78, 86, 80)
local WATER_LINES = "rbxassetid://92684887585956" -- PropTextures water_lines (the fountain / well "Ripples")

-- a frame per rim side: local +Z = outward, local X along the side
local function sideFrames(dist: number): { CFrame }
	return {
		CFrame.new(0, 0, -dist) * CFrame.Angles(0, math.pi, 0),
		CFrame.new(0, 0, dist),
		CFrame.new(-dist, 0, 0) * CFrame.Angles(0, rad(-90), 0),
		CFrame.new(dist, 0, 0) * CFrame.Angles(0, rad(90), 0),
	}
end

---------------------------------------------------------------------
-- 04 WATER POOL WITH GOLD CORNERS (kit MapAssets.Jungle.Temple_Pool, 14 parts, 24.6 x 3.1 x 24.6; Jungle_3 x1,
-- Jungle_4 x2 at 1.2)
---------------------------------------------------------------------
M.SHAPES.jungle_temple_pool = { -- today's colliding parts: 4 Rims, 4 Posts
	{ "Block", 24, 1.4, 2, { 0, 0.7, -11, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 24, 1.4, 2, { 0, 0.7, 11, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 2, 1.4, 20, { -11, 0.7, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 2, 1.4, 20, { 11, 0.7, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 2.6, 2.6, 2.6, { -11, 1.3, -11, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 2.6, 2.6, 2.6, { -11, 1.3, 11, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 2.6, 2.6, 2.6, { 11, 1.3, -11, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 2.6, 2.6, 2.6, { 11, 1.3, 11, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
}

-- Agent A's floating lily pad (2.0 wide at scale 1, a V notch) centred at `at` on the water, maybe with his pink flower
local function lilyPad(U: any, rng: Random, at: Vector3, sc: number, withFlower: boolean)
	local cf = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 6.3), 0)
	J.facets(U, TData.lily_pad, Vector3.one * sc, cf, "Moss")
	if withFlower then
		J.facets(U, TData.lily_flower, Vector3.one * math.max(sc, 0.8), cf * CFrame.new(-0.15 * sc, 0.02, 0.1 * sc), "Moss")
	end
end
Totems.lilyPad = lilyPad

-- The water pool (guide C5): today's 4 rims as cut stone blocks 3-4 long with joints over a dark core, a bevelled cap
-- course (0.2 chamfer, 0.3 overhang over the water, 3 tone steps, 2-3 chipped corners), a wet band 0.2 on the inner
-- faces above the waterline; today's 4 corner posts as carved posts (a footing band, a carved band with 2 grooves,
-- recessed panels on the 2 outer faces, a chamfered top) with a gold cap stepped in 2 levels with engraved lines and a
-- small pyramid knob; today's water like the fountain / well (Glass, T 0.15, #30C4BE, the water_lines "Ripples"
-- texture, top at today's 0.8, CanCollide off: walk-through as today) over today's dark Basin with a few stones on its
-- floor; 5 of Agent A's lily pads (2 with his pink flower); soft moss: mats on 2 cap corners, drapes over 3 rim edges
-- and down 2 posts, tufts at 2 post feet.
-- Parts: Gold, Moss, Stone, Water, Basin, Collision x8.
function Totems.jungle_temple_pool(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_temple_pool"
	local rng = Random.new(20261261)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Gold = {}, Moss = {} }
	for side, fr in ipairs(sideFrames(11)) do
		-- the lower course (y 0 .. 1.0) of cut blocks through the rim's depth, over a dark core
		R.stoneCourses(U.Stone, rng, -9.7, 9.7, 0, 1.05, 0, 2, 1.05, H.scaled(STONE, 0.93), CORE, 0, fr)
		-- the cap course (y 1.0 .. 1.4): 0.3 over the water, 0.05 out, bevelled 0.2, 3 tone steps, chipped corners
		local x = -9.7 - (if side % 2 == 0 then rng:NextNumber(0.8, 1.6) else 0)
		local chips = if side <= 2 then 1 else 0
		while x < 9.65 do
			local len = rng:NextNumber(3.0, 4.0)
			local a, b = math.max(x, -9.7), math.min(x + len, 9.7)
			if b - a > 0.6 then
				local size = Vector3.new(b - a - 0.1, 0.4, 2.35)
				local cf = fr * CFrame.new((a + b) / 2, 1.2, -0.125)
				local negs = {}
				if chips > 0 and rng:NextNumber() < 0.5 then
					local sx = if rng:NextNumber() < 0.5 then -1 else 1
					table.insert(negs, piece("Part", Vector3.one * 0.55, cf * CFrame.new(sx * size.X / 2, 0.2, -size.Z / 2) * CFrame.Angles(rad(35), rad(45), 0), CORE))
					chips -= 1
				end
				local tone = ({ 1.08, 1.0, 0.93 })[rng:NextInteger(1, 3)]
				table.insert(U.Stone, chamfered(size, cf, H.scaled(STONE, tone), { "vertical", "topFrontBack", "topSides" }, 0.2, negs))
			end
			x += len
		end
		-- the wet band on the inner face just above the waterline (0.8 .. 1.0)
		table.insert(U.Stone, piece("Part", Vector3.new(19.3, 0.2, 0.04), fr * CFrame.new(0, 0.9, -1.02), WET))
	end
	-- the 4 corner posts (today's 2.6 cube): footing band, shaft, carved band, recessed panels, chamfered top
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local base = CFrame.new(sx * 11, 0, sz * 11)
			table.insert(U.Stone, chamfered(Vector3.new(2.6, 0.5, 2.6), base * CFrame.new(0, 0.25, 0), H.scaled(STONE_DARK, 0.92), { "vertical", "topFrontBack", "topSides" }, 0.12))
			table.insert(U.Stone, chamfered(Vector3.new(2.4, 1.75, 2.4), base * CFrame.new(0, 1.37, 0), STONE_DARK, { "vertical" }, 0.22))
			table.insert(U.Stone, chamfered(Vector3.new(2.52, 0.3, 2.52), base * CFrame.new(0, 1.55, 0), H.scaled(STONE_DARK, 1.12), { "vertical" }, 0.24))
			for _, dy in ipairs({ -0.19, 0.19 }) do
				table.insert(U.Stone, chamfered(Vector3.new(2.46, 0.05, 2.46), base * CFrame.new(0, 1.55 + dy, 0), CORE, { "vertical" }, 0.24))
			end
			table.insert(U.Stone, chamfered(Vector3.new(2.6, 0.38, 2.6), base * CFrame.new(0, 2.41, 0), H.scaled(STONE_DARK, 1.06), { "vertical", "topFrontBack", "topSides" }, 0.2))
			-- recessed panels on the 2 outer faces (a dark inset with a lighter rim)
			for _, face in ipairs({ CFrame.Angles(0, if sz < 0 then math.pi else 0, 0), CFrame.Angles(0, rad(sx * 90), 0) }) do
				local fcf = base * face * CFrame.new(0, 0.95, 1.2)
				table.insert(U.Stone, piece("Part", Vector3.new(1.4, 0.65, 0.04), fcf, H.scaled(STONE_DARK, 1.15)))
				table.insert(U.Stone, piece("Part", Vector3.new(1.15, 0.42, 0.05), fcf * CFrame.new(0, 0, 0.01), CORE))
			end
			-- the gold cap: 2 stepped levels with engraved edge lines and a small pyramid knob (top 3.36)
			table.insert(U.Gold, chamfered(Vector3.new(1.8, 0.2, 1.8), base * CFrame.new(0, 2.7, 0), GOLD, { "vertical", "topFrontBack", "topSides" }, 0.06))
			table.insert(U.Gold, chamfered(Vector3.new(1.84, 0.05, 1.84), base * CFrame.new(0, 2.66, 0), GOLD_DARK, { "vertical" }, 0.08))
			table.insert(U.Gold, chamfered(Vector3.new(1.3, 0.2, 1.3), base * CFrame.new(0, 2.9, 0), GOLD, { "vertical", "topFrontBack", "topSides" }, 0.05))
			table.insert(U.Gold, chamfered(Vector3.new(1.34, 0.05, 1.34), base * CFrame.new(0, 2.86, 0), GOLD_DARK, { "vertical" }, 0.06))
			table.insert(U.Gold, M.frustumN(4, 0.5, 0.06, 3.0, 3.36, base * CFrame.Angles(0, rad(45), 0), { GOLD, H.scaled(GOLD, 0.92) }))
		end
	end
	-- a few stones on the basin floor (seen through the water)
	for _, s in ipairs({ { -6.5, 4.8, 0.9 }, { 5.2, -6.1, 0.7 }, { 7.4, 6.6, 0.6 }, { -3.0, -7.3, 0.55 } }) do
		looseStone(U.Stone, rng, Vector3.new(s[3] * 1.3, s[3] * 0.5, s[3]), CFrame.new(s[1], 0.2 + s[3] * 0.18, s[2]) * CFrame.Angles(0, rng:NextNumber(0, 6.3), 0), H.scaled(BASIN, rng:NextNumber(0.7, 0.85)))
	end
	-- 5 of Agent A's lily pads on the water (y 0.82), 2 with his pink flower
	for i, l in ipairs({ { -7.2, -6.4, 1.0 }, { -5.6, -7.9, 0.7 }, { 6.8, 4.9, 1.15 }, { 7.9, 7.2, 0.65 }, { -7.6, 6.9, 0.85 } }) do
		lilyPad(U, rng, Vector3.new(l[1], 0.82, l[2]), l[3], i == 1 or i == 3)
	end
	-- moss: soft mats on 2 cap corners, drapes over 3 rim edges (outer faces) and down 2 posts, tufts at 2 post feet
	mossMat(U.Moss, rng, CFrame.new(-8.3, 1.4, -11.1), 2.4, 1.3, 0.7)
	mossMat(U.Moss, rng, CFrame.new(11.1, 1.4, 8.2) * CFrame.Angles(0, rad(90), 0), 2.2, 1.2, 0.7)
	J.mossFacet(U, "A", Vector3.new(-6.5, 1.4, -12.06), Vector3.new(0, 0, -1), 0.8)
	J.mossFacet(U, "B", Vector3.new(12.06, 1.4, 5.8), Vector3.new(1, 0, 0), 0.75)
	partDrape(U.Moss, rng, Vector3.new(3.8, 1.4, 12.06), Vector3.new(0, 0, 1), 2.0, 0.8, 0.9)
	partDrape(U.Moss, rng, Vector3.new(-11, 2.6, -12.32), Vector3.new(0, 0, -1), 1.6, 0.35, 1.6)
	partDrape(U.Moss, rng, Vector3.new(12.32, 2.6, 11), Vector3.new(1, 0, 0), 1.4, 0.35, 1.4)
	J.facets(U, RData.plant_tuft, Vector3.one * 0.65, CFrame.new(-12.45, 0, -9.5), "Moss")
	J.facets(U, RData.plant_tuft, Vector3.one * 0.55, CFrame.new(12.45, 0, 9.4) * CFrame.Angles(0, rad(40), 0), "Moss")
	finish(m, "jungle_temple_pool", U, "Stone")
	-- today's Basin (kept: dark #1E8C96, not colliding) and the Water like the fountain / well (not colliding,
	-- not queried, not touched: players walk through it as today)
	G.exact(m, "Part", "Basin", Vector3.new(20, 0.2, 20), CFrame.new(0, 0.1, 0), BASIN, { collide = false, query = false, touch = true })
	local water = G.exact(m, "Part", "Water", Vector3.new(20, 0.12, 20), CFrame.new(0, 0.74, 0), WATER, { collide = false, query = false, touch = false, shadow = false })
	water.Material = Enum.Material.Glass
	water.Transparency = 0.15
	local tex = Instance.new("Texture")
	tex.Name = "Ripples"
	tex.Face = Enum.NormalId.Top
	tex.Texture = WATER_LINES
	tex.StudsPerTileU = 4
	tex.StudsPerTileV = 4
	tex.Parent = water
	return m
end

---------------------------------------------------------------------
-- shared totem helpers (01 and 02, the same family as the C3 totem arch)
---------------------------------------------------------------------
local WOOD_DARK = rgb(74, 48, 34) -- #4A3022 (bases, sockets)
local BONE = rgb(232, 226, 208) -- #E8E2D0
local ROPE = rgb(196, 160, 104) -- #C4A068
local RELIEF_REF = Color3.fromHex("#D6965C") -- the colour Agent A's face reliefs were painted in

local function lum(c: Color3): number
	return 0.3 * c.R + 0.59 * c.G + 0.11 * c.B
end

-- a copy of a facet piece recoloured to `base`: each tone keeps its brightness ratio to the painted colour (the dark
-- nostrils stay dark: 45 % of the base)
local function tinted(data: any, base: Color3): any
	local pal = {}
	for i, entry in ipairs(data.palette) do
		local c = Color3.fromHex((string.match(entry, "^(#%x+)")) :: string)
		local f = lum(c) / lum(RELIEF_REF)
		pal[i] = "#" .. H.scaled(base, if f < 0.5 then 0.45 else f):ToHex()
	end
	return { palette = pal, tris = data.tris }
end

-- a carved head: today's cube (size, colour, place) with all edges chamfered 0.2
local function head(list: { BasePart }, size: Vector3, y: number, color: Color3)
	table.insert(list, chamfered(size, CFrame.new(0, y, 0), color, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.2))
end

-- an eye with depth on a face frame (`face` at the centre of the front face, -Z out): a dark socket frame, the eye
-- 0.16 proud, a pupil (dark on light eyes, a light glint on dark ones); round = an 8-sided eye
local function eye(list: { BasePart }, face: CFrame, x: number, y: number, w: number, h: number, color: Color3, socket: Color3, round: boolean?)
	local at = face * CFrame.new(x, y, 0)
	table.insert(list, piece("Part", Vector3.new(w + 0.34, h + 0.34, 0.06), at * CFrame.new(0, 0, -0.03), socket))
	if round then
		table.insert(list, M.frustumN(8, w / 2, w / 2 - 0.05, 0, 0.16, at * CFrame.Angles(rad(-90), 0, 0), { color, H.scaled(color, 0.92) }))
	else
		table.insert(list, chamfered(Vector3.new(w, h, 0.16), at * CFrame.new(0, 0, -0.08), color, { "frontFace" }, 0.05))
	end
	local light = lum(color) > 0.5
	local pc = if light then WOOD_DARK else Color3.fromRGB(250, 245, 230)
	local ps = if light then 0.32 else 0.18
	table.insert(list, piece("Part", Vector3.new(ps, ps, 0.04), at * CFrame.new(if light then 0 else w * 0.2, if light then -h * 0.1 else h * 0.22, -0.18), pc))
end

-- a closed eye: a dark bar with a thin lid above it
local function closedEye(list: { BasePart }, face: CFrame, x: number, y: number, w: number, color: Color3, lid: Color3)
	table.insert(list, chamfered(Vector3.new(w, 0.16, 0.12), face * CFrame.new(x, y, -0.06), color, { "frontFace" }, 0.04))
	table.insert(list, chamfered(Vector3.new(w + 0.2, 0.14, 0.18), face * CFrame.new(x, y + 0.2, -0.09) * CFrame.Angles(0, 0, rad(if x < 0 then 6 else -6)), lid, { "frontFace" }, 0.05))
end

-- a mouth with lips and teeth: today's mouth slab (w x h, colour) 0.1 proud, lips 0.2 proud in the head's darker tone,
-- n white teeth along its top (and `lower` along its bottom)
local function mouth(list: { BasePart }, face: CFrame, y: number, w: number, h: number, color: Color3, lip: Color3, n: number, lower: number?)
	local at = face * CFrame.new(0, y, 0)
	table.insert(list, chamfered(Vector3.new(w + 0.36, h + 0.36, 0.2), at * CFrame.new(0, 0, -0.1), lip, { "frontFace" }, 0.08))
	table.insert(list, piece("Part", Vector3.new(w, h, 0.1), at * CFrame.new(0, 0, -0.23), color))
	local function row(count: number, yy: number)
		for k = 1, count do
			local x = -w / 2 + (k - 0.5) * w / count
			table.insert(list, chamfered(Vector3.new(math.min(0.3, w / count - 0.06), 0.28, 0.12), at * CFrame.new(x, yy, -0.3), BONE, { "frontFace" }, 0.04))
		end
	end
	row(n, h / 2 - 0.15)
	if lower and lower > 0 then
		row(lower, -h / 2 + 0.15)
	end
end

-- a band between 2 sections: rope (twisted: diagonal strands) or gold (0.35 tall, 2 rivets on the front)
local function band(list: { BasePart }, gold: { BasePart }, y: number, w: number, isGold: boolean)
	if isGold then
		table.insert(gold, chamfered(Vector3.new(w, 0.35, w), CFrame.new(0, y, 0), GOLD, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.08))
		table.insert(gold, chamfered(Vector3.new(w + 0.02, 0.06, w + 0.02), CFrame.new(0, y, 0), GOLD_DARK, { "vertical" }, 0.1))
		for _, x in ipairs({ -w * 0.3, w * 0.3 }) do
			table.insert(gold, M.frustumN(6, 0.1, 0.06, 0, 0.08, CFrame.new(x, y, -w / 2) * CFrame.Angles(rad(-90), 0, 0), { GOLD, H.scaled(GOLD, 0.9) }))
		end
	else
		table.insert(list, chamfered(Vector3.new(w, 0.3, w), CFrame.new(0, y, 0), ROPE, { "vertical" }, 0.3))
		for side = 0, 3 do
			local face = CFrame.Angles(0, side * math.pi / 2, 0)
			for k = -3, 3 do
				table.insert(list, piece("Part", Vector3.new(0.06, 0.36, 0.04), face * CFrame.new(k * w / 7.5, y, -w / 2 - 0.01) * CFrame.Angles(0, 0, rad(35)), H.scaled(ROPE, 0.82)))
			end
		end
	end
end

-- the plinth: 2 chamfered stone steps (#5C645C, 0.6 together, inside `w`) round today's dark wood base, which keeps its
-- size and place: a 0.2 groove band and 4 corner notches; a moss mat on the plinth's front-left corner
local function plinth(U: any, rng: Random, w: number, baseW: number, baseH: number)
	table.insert(U.Stone, chamfered(Vector3.new(w, 0.32, w), CFrame.new(0, 0.16, 0), H.scaled(STONE_DARK, 0.92), { "vertical", "topFrontBack", "topSides" }, 0.12))
	table.insert(U.Stone, chamfered(Vector3.new(w - 0.4, 0.3, w - 0.4), CFrame.new(0, 0.47, 0), STONE_DARK, { "vertical", "topFrontBack", "topSides" }, 0.1))
	local negs = {}
	for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		table.insert(negs, piece("Part", Vector3.new(0.35, baseH * 0.5, 0.35), CFrame.new(c[1] * baseW / 2, baseH * 0.75, c[2] * baseW / 2) * CFrame.Angles(0, rad(45), 0), WOOD_DARK))
	end
	table.insert(U.Wood, chamfered(Vector3.new(baseW, baseH, baseW), CFrame.new(0, baseH / 2, 0), WOOD_DARK, { "vertical", "topFrontBack", "topSides" }, 0.12, negs))
	table.insert(U.Wood, chamfered(Vector3.new(baseW + 0.02, 0.12, baseW + 0.02), CFrame.new(0, baseH * 0.42, 0), H.scaled(WOOD_DARK, 0.7), { "vertical" }, 0.14))
	mossMat(U.Moss, rng, CFrame.new(-w / 2 + 0.55, 0.62, -w / 2 + 0.6) * CFrame.Angles(0, rad(-45), 0), 1.4, 0.6, 0.6)
end

---------------------------------------------------------------------
-- 01 TALL TOTEM POLE (kit MapAssets.Jungle.Totem_B, 26 parts, 7 x 21.6 x 5.0; Jungle_1 x2, Jungle_2 x1, BA x1)
---------------------------------------------------------------------
M.SHAPES.jungle_tall_totem = { -- today's colliding parts: Base, 5 Heads, 2 Ears
	{ "Block", 4.8, 1.2, 4.8, { 0, 0.6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 3.4, 3.4, 3.4, { 0, 2.9, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 3.7, 3.4, 3.7, { 0, 6.3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 3.4, 3.4, 3.4, { 0, 9.7, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 3.7, 3.4, 3.7, { 0, 13.1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 3.4, 3.4, 3.4, { 0, 16.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 1.6, 2.6, 0.8, { -2.7, 9.7, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 1.6, 2.6, 0.8, { 2.7, 9.7, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
}

-- a carved small arm (today's gold Ear, 1.6 x 2.6 x 0.8 at x = side * 2.7): a shoulder block out of the head, a
-- forearm down, a hand of 3 fingers, engraved lines
local function smallArm(list: { BasePart }, side: number)
	local x0 = side * 1.7
	table.insert(list, chamfered(Vector3.new(1.05, 0.8, 0.72), CFrame.new(x0 + side * 0.5, 10.55, 0), GOLD, { "vertical", "topFrontBack", "topSides" }, 0.1))
	table.insert(list, chamfered(Vector3.new(0.78, 1.5, 0.66), CFrame.new(side * 2.95, 9.9, 0), H.scaled(GOLD, 0.97), { "vertical", "topFrontBack", "topSides" }, 0.1))
	table.insert(list, chamfered(Vector3.new(0.82, 0.12, 0.7), CFrame.new(side * 2.95, 10.25, 0), GOLD_DARK, { "vertical" }, 0.08))
	table.insert(list, chamfered(Vector3.new(0.92, 0.5, 0.78), CFrame.new(side * 2.95, 8.95, -0.02), GOLD, { "vertical", "bottomFrontBack", "bottomSides" }, 0.1))
	for k = -1, 1 do
		table.insert(list, chamfered(Vector3.new(0.2, 0.42, 0.2), CFrame.new(side * 2.95 + k * 0.26, 8.5, -0.2), H.scaled(GOLD, 0.95), { "vertical", "bottomFrontBack", "bottomSides" }, 0.06))
	end
end

-- The tall totem pole (guide C5): 5 carved heads at today's sizes, colours and heights, each with a different
-- expression: the blue one grinning with Agent A's curved tusks, the tan one calm (closed eyes), the red one angry, the
-- brown one open-mouthed, the yellow one surprised (round eyes); Agent A's face reliefs (brows, nose, cheek plates)
-- tinted to each head (B on blue, tan, yellow; A on red, brown); rope and gold bands with rivets between the sections;
-- today's gold ears as carved small arms with hands; Agent A's feather crest in a gold band (replacing the 3
-- feathers); a 2-step stone plinth round today's dark wood base (groove band, corner notches), moss on a corner.
-- (the carved faces are 2 unions, the lower 2 heads and the upper 3: one would pass the 20,000-triangle union cap)
-- Parts: Faces, FacesUp, Gold, Heads, Moss, Stone, Wood, Collision x8.
function Totems.jungle_tall_totem(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_tall_totem"
	local rng = Random.new(20261262)
	H.setBevelSelf(true)
	local U: any = { Heads = {}, Faces = {}, FacesUp = {}, Gold = {}, Stone = {}, Wood = {}, Moss = {} }
	plinth(U, rng, 5.3, 4.8, 1.2)
	local BLUE, TAN, RED, BROWN, YELLOW = rgb(60, 170, 190), rgb(214, 150, 92), rgb(196, 70, 50), rgb(104, 68, 44), rgb(255, 201, 60)
	local heads = { { 3.4, 2.9, BLUE }, { 3.7, 6.3, TAN }, { 3.4, 9.7, RED }, { 3.7, 13.1, BROWN }, { 3.4, 16.5, YELLOW } }
	for _, hd in ipairs(heads) do
		head(U.Heads, Vector3.new(hd[1], 3.4, hd[1]), hd[2], hd[3])
	end
	local function faceOf(i: number): CFrame
		return CFrame.new(0, heads[i][2], -heads[i][1] / 2)
	end
	local function relief(i: number, variant: string)
		local hd = heads[i]
		J.facets(U, tinted(TData["face_relief_" .. variant], H.scaled(hd[3], 0.93)), Vector3.one * (hd[1] / 3.4), faceOf(i), if i <= 2 then "Faces" else "FacesUp")
	end
	-- 1 blue, grinning: white eyes, a wide grin with 2 rows of teeth, Agent A's tusks
	relief(1, "B")
	eye(U.Faces, faceOf(1), -0.95, 0.5, 0.8, 0.8, BONE, WOOD_DARK)
	eye(U.Faces, faceOf(1), 0.95, 0.5, 0.8, 0.8, BONE, WOOD_DARK)
	mouth(U.Faces, faceOf(1), -0.9, 2.2, 0.6, WOOD_DARK, H.scaled(BLUE, 0.8), 5, 4)
	J.facets(U, TData.tusks, Vector3.one, CFrame.identity, "Faces")
	-- 2 tan, calm: closed eyes (dark bars under lids), a closed mouth line
	relief(2, "B")
	closedEye(U.Faces, faceOf(2), -1.0, 0.5, 0.85, WOOD_DARK, H.scaled(TAN, 0.88))
	closedEye(U.Faces, faceOf(2), 1.0, 0.5, 0.85, WOOD_DARK, H.scaled(TAN, 0.88))
	table.insert(U.Faces, chamfered(Vector3.new(1.4, 0.16, 0.14), faceOf(2) * CFrame.new(0, -0.95, -0.07), WOOD_DARK, { "frontFace" }, 0.04))
	-- 3 red, angry: white eyes under Agent A's angry brow, today's mouth with teeth
	relief(3, "A")
	eye(U.FacesUp, faceOf(3), -0.95, 0.45, 0.8, 0.7, BONE, WOOD_DARK)
	eye(U.FacesUp, faceOf(3), 0.95, 0.45, 0.8, 0.7, BONE, WOOD_DARK)
	mouth(U.FacesUp, faceOf(3), -0.9, 2.2, 0.6, WOOD_DARK, H.scaled(RED, 0.8), 5)
	smallArm(U.Gold, -1)
	smallArm(U.Gold, 1)
	-- 4 brown, open-mouthed: white eyes, a tall open mouth with upper and lower teeth
	relief(4, "A")
	eye(U.FacesUp, faceOf(4), -1.0, 0.55, 0.8, 0.8, BONE, H.scaled(BROWN, 0.6))
	eye(U.FacesUp, faceOf(4), 1.0, 0.55, 0.8, 0.8, BONE, H.scaled(BROWN, 0.6))
	mouth(U.FacesUp, faceOf(4), -0.95, 1.5, 0.75, H.scaled(WOOD_DARK, 0.7), H.scaled(BROWN, 0.8), 3, 3)
	-- 5 yellow, surprised: round dark eyes, today's red mouth as a small round "O"
	relief(5, "B")
	eye(U.FacesUp, faceOf(5), -0.95, 0.5, 0.85, 0.85, WOOD_DARK, H.scaled(YELLOW, 0.78), true)
	eye(U.FacesUp, faceOf(5), 0.95, 0.5, 0.85, 0.85, WOOD_DARK, H.scaled(YELLOW, 0.78), true)
	table.insert(U.FacesUp, M.frustumN(8, 0.5, 0.42, 0, 0.14, faceOf(5) * CFrame.new(0, -0.9, 0) * CFrame.Angles(rad(-90), 0, 0), { RED, H.scaled(RED, 0.9) }))
	table.insert(U.FacesUp, M.frustumN(8, 0.3, 0.3, 0.1, 0.16, faceOf(5) * CFrame.new(0, -0.9, 0) * CFrame.Angles(rad(-90), 0, 0), { H.scaled(RED, 0.45) }))
	-- bands between the sections: rope, gold, rope, gold
	for i, y in ipairs({ 4.55, 8.1, 11.35, 14.85 }) do
		band(U.Stone, U.Gold, y, 3.8, i % 2 == 0)
	end
	-- Agent A's feather crest in its gold band (replaces today's 3 feathers)
	J.facets(U, TData.feather_crest, Vector3.one, CFrame.identity, "Gold")
	finish(m, "jungle_tall_totem", U, "Heads")
	return m
end

---------------------------------------------------------------------
-- 02 TOTEM FIGURE (kit MapAssets.Jungle.Totem_A, 18 parts, 14.1 x 16.7 x 7.1; Jungle_1 x3, Jungle_2 x1)
---------------------------------------------------------------------
local function wingCf(side: number): { number }
	local a = rad(side * 18)
	return { side * 4.3, 11.2, 0, math.cos(a), -math.sin(a), 0, math.sin(a), math.cos(a), 0, 0, 0, 1 }
end
M.SHAPES.jungle_totem_figure = { -- today's colliding parts: Base, 3 Heads, Brow (hat brim), Crown, 2 Wings
	{ "Block", 5.2, 1.4, 5.2, { 0, 0.7, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 4, 4, 4, { 0, 3.4, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 4.4, 3.6, 4.4, { 0, 7.2, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 4, 3.6, 4, { 0, 10.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 4.6, 0.7, 4.6, { 0, 12.6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 3, 2.2, 3, { 0, 14, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 5, 2.4, 0.7, wingCf(-1) },
	{ "Block", 5, 2.4, 0.7, wingCf(1) },
}

-- The totem figure (guide C5, the same family as the tall totem): today's red lower face stern (white eyes in sockets,
-- Agent A's angry relief, a mouth with 2 rows of teeth); today's blue bird head with gold eyes in sockets, carved brow
-- wedges and a 2-part hooked beak (today's upper wedge, a smaller lower jaw, a dark line between); today's tan head
-- proud (Agent A's arched relief, tall dark eyes in lighter sockets) with Agent A's spread feathered wings (replacing
-- today's 2 wings, kept as colliders); today's red hat: the brim chamfered, a gold band round the crown, a chamfered
-- top, Agent A's curved horns (replacing the 2 sticks); a rope and a gold band between the sections; a 2-step stone
-- plinth round today's dark wood base (groove band, corner notches), moss on a corner.
-- Parts: Faces, Gold, Heads, Moss, Stone, Wood, Collision x8.
function Totems.jungle_totem_figure(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_totem_figure"
	local rng = Random.new(20261263)
	H.setBevelSelf(true)
	local U: any = { Heads = {}, Faces = {}, Gold = {}, Stone = {}, Wood = {}, Moss = {} }
	plinth(U, rng, 5.7, 5.2, 1.4)
	local RED, BLUE, TAN = rgb(196, 70, 50), rgb(60, 170, 190), rgb(214, 150, 92)
	head(U.Heads, Vector3.new(4, 4, 4), 3.4, RED)
	head(U.Heads, Vector3.new(4.4, 3.6, 4.4), 7.2, BLUE)
	head(U.Heads, Vector3.new(4, 3.6, 4), 10.8, TAN)
	-- red, stern
	local f1 = CFrame.new(0, 3.4, -2)
	J.facets(U, tinted(TData.face_relief_A, H.scaled(RED, 0.93)), Vector3.one * (4 / 3.4), f1, "Faces")
	eye(U.Faces, f1, -1.0, 0.7, 1.0, 0.85, BONE, WOOD_DARK)
	eye(U.Faces, f1, 1.0, 0.7, 1.0, 0.85, BONE, WOOD_DARK)
	mouth(U.Faces, f1, -1.0, 2.6, 0.7, WOOD_DARK, H.scaled(RED, 0.8), 6, 5)
	-- blue bird: gold eyes in dark sockets, 2 carved brow wedges, the hooked beak
	local f2 = CFrame.new(0, 7.2, -2.2)
	eye(U.Faces, f2, -1.2, 0.9, 0.9, 0.9, GOLD, WOOD_DARK)
	eye(U.Faces, f2, 1.2, 0.9, 0.9, 0.9, GOLD, WOOD_DARK)
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Faces, chamfered(Vector3.new(1.3, 0.3, 0.4), f2 * CFrame.new(sx * 1.15, 1.55, -0.2) * CFrame.Angles(0, 0, rad(sx * -14)), H.scaled(BLUE, 0.85), { "frontFace", "vertical" }, 0.08))
	end
	local beak = Instance.new("WedgePart")
	beak.Size = Vector3.new(1.6, 1.8, 2.4)
	beak.CFrame = CFrame.new(0, 7.0, -3.3)
	beak.Color = GOLD
	beak.Material = Enum.Material.SmoothPlastic
	beak.Anchored = true
	table.insert(U.Gold, beak)
	table.insert(U.Gold, chamfered(Vector3.new(1.3, 0.45, 1.6), CFrame.new(0, 5.85, -2.95), H.scaled(GOLD, 0.9), { "frontFace", "vertical" }, 0.12))
	table.insert(U.Gold, piece("Part", Vector3.new(1.62, 0.08, 2.0), CFrame.new(0, 6.12, -3.1), H.scaled(GOLD, 0.55)))
	table.insert(U.Gold, piece("Part", Vector3.new(0.2, 0.12, 0.06), CFrame.new(-0.35, 7.0, -3.72) * CFrame.Angles(rad(37), 0, 0), H.scaled(GOLD, 0.6)))
	table.insert(U.Gold, piece("Part", Vector3.new(0.2, 0.12, 0.06), CFrame.new(0.35, 7.0, -3.72) * CFrame.Angles(rad(37), 0, 0), H.scaled(GOLD, 0.6)))
	-- tan, proud: Agent A's arched relief, tall dark eyes in lighter sockets, a closed smile; Agent A's wings
	local f3 = CFrame.new(0, 10.8, -2)
	J.facets(U, tinted(TData.face_relief_B, H.scaled(TAN, 0.93)), Vector3.one * (4 / 3.4), f3, "Faces")
	eye(U.Faces, f3, -1.0, 0.35, 0.9, 1.2, WOOD_DARK, H.scaled(TAN, 1.12))
	eye(U.Faces, f3, 1.0, 0.35, 0.9, 1.2, WOOD_DARK, H.scaled(TAN, 1.12))
	table.insert(U.Faces, chamfered(Vector3.new(1.6, 0.18, 0.14), f3 * CFrame.new(0, -1.1, -0.07), WOOD_DARK, { "frontFace" }, 0.04))
	J.facets(U, TData.wing_L, Vector3.one, CFrame.identity, "Gold")
	J.facets(U, TData.wing_R, Vector3.one, CFrame.identity, "Gold")
	-- the hat: today's brim chamfered, a gold band round the crown, a chamfered crown top, Agent A's horns
	table.insert(U.Heads, chamfered(Vector3.new(4.6, 0.7, 4.6), CFrame.new(0, 12.6, 0), RED, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.2))
	table.insert(U.Heads, chamfered(Vector3.new(3, 2.2, 3), CFrame.new(0, 14, 0), RED, { "vertical", "topFrontBack", "topSides" }, 0.25))
	table.insert(U.Gold, chamfered(Vector3.new(3.1, 0.35, 3.1), CFrame.new(0, 13.35, 0), GOLD, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.08))
	table.insert(U.Gold, M.frustumN(6, 0.12, 0.07, 0, 0.08, CFrame.new(0, 13.35, -1.55) * CFrame.Angles(rad(-90), 0, 0), { GOLD_DARK }))
	J.facets(U, TData.horns, Vector3.one, CFrame.identity, "Faces")
	-- bands between the sections: rope, gold
	band(U.Stone, U.Gold, 5.4, 4.5, false)
	band(U.Stone, U.Gold, 9.0, 4.5, true)
	finish(m, "jungle_totem_figure", U, "Heads")
	return m
end

---------------------------------------------------------------------
-- 03 GOLDEN SHRINE (kit MapAssets.Jungle.Golden_Altar, 13 parts, 12 x 9.05 x 8; Jungle_4 x1 at 1.6)
---------------------------------------------------------------------
local GEM_CF = { -- today's 2 Gems (turned)
	CFrame.new(-3, 6.5, 0, 0.7071, -0.7071, 0, 0.5, 0.5, -0.7071, 0.5, 0.5, 0.7071):Orthonormalize(),
	CFrame.new(3, 6.5, 0, 0.7071, -0.7071, 0, 0.5, 0.5, -0.7071, 0.5, 0.5, 0.7071):Orthonormalize(),
}
M.SHAPES.jungle_golden_shrine = { -- today's colliding parts: 2 Steps, Table, GoldTop
	{ "Block", 12, 1.4, 8, { 0, 0.7, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 10, 1.4, 6, { 0, 2.1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 8, 2.2, 4.4, { 0, 3.9, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 8.6, 0.6, 5, { 0, 5.3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
}

-- one stepped course of jointed chamfered slabs (w x d, y0 .. y1), running the joints across the depth
local function stepCourse(list: { BasePart }, rng: Random, w: number, d: number, y0: number, y1: number, color: Color3)
	table.insert(list, piece("Part", Vector3.new(w - 0.16, y1 - y0 - 0.04, d - 0.16), CFrame.new(0, (y0 + y1) / 2, 0), CORE))
	local x = -w / 2
	while x < w / 2 - 0.05 do
		local len = math.min(rng:NextNumber(3.0, 4.0), w / 2 - x)
		if w / 2 - (x + len) < 1.2 then
			len = w / 2 - x
		end
		local tone = ({ 1.06, 1.0, 0.94 })[rng:NextInteger(1, 3)]
		table.insert(list, chamfered(Vector3.new(len - 0.08, y1 - y0, d), CFrame.new(x + len / 2, (y0 + y1) / 2, 0), H.scaled(color, tone), { "vertical", "topFrontBack", "topSides" }, 0.2))
		x += len
	end
end

-- The golden shrine (guide C5): today's 2 steps as bevelled jointed slabs (0.2 bevels, joints every 3-4) with moss
-- drapes on 2 corners and a mat in the back joint; today's table as a carved front panel (a 0.2 frame, today's Neon
-- glyph in a recessed dark groove, 2 small carved side glyphs) with today's 2 gold corner trims engraved; today's gold
-- top plated (a raised rim, darker engraved strips along the edges, a key pattern on the front); Agent A's gold claw
-- settings round today's 2 Neon gems (kept, each with a PointLight #78FFBE range 8, brightness 0.6) and Agent A's gold
-- finial with its small Neon tip (replacing today's idol). No prompt or script to keep (none today).
-- Parts: Finial, Gold, Moss, Stone, Glow, Gem x2, Glyph, Collision x4.
function Totems.jungle_golden_shrine(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_golden_shrine"
	local rng = Random.new(20261264)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Gold = {}, Moss = {} }
	stepCourse(U.Stone, rng, 12, 8, 0, 1.4, STONE_DARK)
	stepCourse(U.Stone, rng, 10, 6, 1.4, 2.8, STONE)
	-- the table: a chamfered body, a 0.2 frame on the front, the glyph's dark recessed groove, 2 carved side glyphs
	table.insert(U.Stone, chamfered(Vector3.new(8, 2.2, 4.4), CFrame.new(0, 3.9, 0), STONE, { "vertical" }, 0.15))
	for _, b in ipairs({ { 0, 4.87, 7.2, 0.2 }, { 0, 2.93, 7.2, 0.2 }, { -3.5, 3.9, 0.2, 1.75 }, { 3.5, 3.9, 0.2, 1.75 } }) do
		table.insert(U.Stone, chamfered(Vector3.new(b[3], b[4], 0.12), CFrame.new(b[1], b[2], -2.26), H.scaled(STONE, 1.08), { "frontFace" }, 0.05))
	end
	table.insert(U.Stone, chamfered(Vector3.new(3.6, 1.5, 0.08), CFrame.new(0, 3.9, -2.24), H.scaled(STONE, 1.1), { "frontFace" }, 0.04))
	table.insert(U.Stone, piece("Part", Vector3.new(3.3, 1.25, 0.06), CFrame.new(0, 3.9, -2.27), rgb(41, 45, 41)))
	for _, sx in ipairs({ -1, 1 }) do
		local c = CFrame.new(sx * 2.55, 3.9, -2.25)
		table.insert(U.Stone, piece("Part", Vector3.new(0.5, 0.5, 0.05), c * CFrame.Angles(0, 0, rad(45)), H.scaled(STONE, 0.6)))
		table.insert(U.Stone, piece("Part", Vector3.new(0.12, 0.9, 0.06), c, H.scaled(STONE, 0.6)))
	end
	-- today's 2 gold corner trims, engraved (2 darker rings)
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Gold, chamfered(Vector3.new(0.5, 2.2, 0.5), CFrame.new(sx * 3.8, 3.9, -2.1), GOLD, { "vertical" }, 0.08))
		for _, dy in ipairs({ -0.7, 0.7 }) do
			table.insert(U.Gold, chamfered(Vector3.new(0.54, 0.08, 0.54), CFrame.new(sx * 3.8, 3.9 + dy, -2.1), GOLD_DARK, { "vertical" }, 0.08))
		end
	end
	-- the gold top: today's plate with a raised rim, engraved strips along the edges and a key pattern on the front
	table.insert(U.Gold, chamfered(Vector3.new(8.6, 0.6, 5), CFrame.new(0, 5.3, 0), GOLD, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.1))
	for _, e in ipairs({ { 0, -2.08, 7.8, 0.08 }, { 0, 2.08, 7.8, 0.08 }, { -3.88, 0, 0.08, 4.2 }, { 3.88, 0, 0.08, 4.2 } }) do
		table.insert(U.Gold, piece("Part", Vector3.new(e[3], 0.02, e[4]), CFrame.new(e[1], 5.605, e[2]), GOLD_DARK))
	end
	for _, e in ipairs({ { 0, -2.3, 8.2, 0.12 }, { 0, 2.3, 8.2, 0.12 }, { -4.1, 0, 0.12, 4.6 }, { 4.1, 0, 0.12, 4.6 } }) do
		table.insert(U.Gold, piece("Part", Vector3.new(e[3], 0.1, e[4]), CFrame.new(e[1], 5.63, e[2]), H.scaled(GOLD, 1.04)))
	end
	for k = -9, 9 do -- the key pattern: a meander of 0.1 blocks on the front face
		local x = k * 0.42
		table.insert(U.Gold, piece("Part", Vector3.new(0.1, 0.32, 0.06), CFrame.new(x, 5.3, -2.52), GOLD_DARK))
		table.insert(U.Gold, piece("Part", Vector3.new(0.32, 0.1, 0.06), CFrame.new(x + 0.11, if k % 2 == 0 then 5.41 else 5.19, -2.52), GOLD_DARK))
	end
	-- Agent A's claw settings (replacing today's bowls) and finial (replacing today's idol + head)
	for _, g in ipairs(GEM_CF) do
		J.facets(U, TData.gem_setting, Vector3.one, CFrame.new(g.Position), "Gold")
	end
	J.facets(U, TData.finial, Vector3.one, CFrame.identity, "Finial")
	-- moss: drapes on 2 corners of the lower step, a mat in the back joint
	partDrape(U.Moss, rng, Vector3.new(-5.2, 1.4, -4.02), Vector3.new(0, 0, -1), 1.6, 0.6, 0.9)
	partDrape(U.Moss, rng, Vector3.new(6.02, 1.4, 2.6), Vector3.new(1, 0, 0), 1.5, 0.6, 0.9)
	mossMat(U.Moss, rng, CFrame.new(1.5, 2.8, 2.75), 2.4, 0.5, 0.6)
	finish(m, "jungle_golden_shrine", U, "Stone")
	-- today's 2 Neon gems (kept) with their soft cyan light, today's Neon glyph (kept)
	local GLOW = rgb(120, 255, 190) -- #78FFBE
	local flags = { collide = false, query = false, touch = false, shadow = false, neon = true }
	for _, g in ipairs(GEM_CF) do
		local gem = G.exact(m, "Part", "Gem", Vector3.new(0.7, 0.7, 0.7), g, GLOW, flags)
		local light = Instance.new("PointLight")
		light.Color = GLOW
		light.Range = 8
		light.Brightness = 0.6
		light.Shadows = false
		light.Parent = gem
	end
	G.exact(m, "Part", "Glyph", Vector3.new(3, 1, 0.3), CFrame.new(0, 3.9, -2.3), GLOW, flags)
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table as the jungle ruins; its install() builds them
---------------------------------------------------------------------
Totems.BUILDERS = { jungle_temple_pool = true, jungle_tall_totem = true, jungle_totem_figure = true, jungle_golden_shrine = true }
for id in pairs(Totems.BUILDERS) do
	B2[id] = (Totems :: any)[id]
	B2.BUILDERS[id] = true
end
Totems.install = B2.install
Totems.SHAPES = M.SHAPES
Totems.R = R

return Totems
