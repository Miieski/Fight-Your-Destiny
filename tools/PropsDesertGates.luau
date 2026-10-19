--[[
	PropsDesertGates (dev tool, Edit mode only) - the owner's "DESERT ZONE PROP IMPROVEMENT - Gates and entrances"
	(2026-10-19), gates 02 (pylon temple gate, kit MapAssets.Gates.Gate_Desert_4; Zones.Desert.Desert_4.Gate) and 03
	(canyon barricade, kit MapAssets.Gates.Gate_Desert_3; Zones.Desert.Desert_3.Gate), rebuilt with the desert recipe
	(docs/prop_texture_guide.md B and B12). Source of truth: tools/PropsDesertGates.luau. Inventory:
	docs/prop_inventory.md "Desert gates and entrances".

	The gate contract is kept exactly (ZoneService / GateController): the model's PrimaryPart is the colliding
	"Barrier"; everything that must vanish when the gate opens is a descendant of the Barrier (attribute
	BarrierDecorIsChildOfBarrier); "PriceSign" keeps its place and size (SyncMapProps moves its PriceGuiFront / Back
	SurfaceGuis onto the new part); the instance keeps its SubZoneId attribute. The pylon's 47 glyph parts (37 door
	glyphs + 10 tower figure parts), its 4 Borders, Seam and SunDisc are exact copies of the game copy
	(Zones.Desert.Desert_4.Gate, recorded in docs B12) and are checked part by part after every sync.

	It uses DevTools.PropsDesert (its fresh PropsBatch2 table and helpers) and registers its builders there:
		local G = require(game.ServerStorage.DevTools.PropsDesertGates:Clone())
		print(G.install("pylon_temple_gate"))   -- (re)builds ServerStorage.MapProps.pylon_temple_gate
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "pylon_temple_gate" } }), Sync.run({ only = { "pylon_temple_gate" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local D = require(ServerStorage.DevTools.PropsDesert:Clone()) :: any
local B2 = D.B2
local H = B2.H
local L = D.lib
local C = D.PALETTE
local TONES = H.TONES
local scaled, toneIndex = H.scaled, H.toneIndex
local piece, chamfered, merge = H.piece, H.chamfered, H.merge
local soft, lists, envelope = L.soft, L.lists, L.envelope

local Gates = {}

local rgb = Color3.fromRGB
local rad = math.rad
local UP = Vector3.yAxis

local SAND = rgb(244, 208, 124)

-- a cylinder (axis X) from a to b
local function cyl(a: Vector3, b: Vector3, d: number, color: Color3): BasePart
	local dir = (b - a).Unit
	local side = if math.abs(dir.Y) > 0.9 then Vector3.xAxis else UP
	local vy = (side - dir * side:Dot(dir)).Unit
	return piece("Part", Vector3.new((b - a).Magnitude, d, d), CFrame.fromMatrix((a + b) / 2, dir, vy), color, { shape = Enum.PartType.Cylinder })
end

-- a ring of n short bars (radius r, bar thickness t) around centre c in the plane of the unit vectors u, v
local function ring(list: { BasePart }, c: Vector3, u: Vector3, v: Vector3, r: number, t: number, n: number, color: Color3)
	local len = 2 * math.pi * r / n * 1.08
	for k = 0, n - 1 do
		local a = (k + 0.5) * 2 * math.pi / n
		local p = c + (u * math.cos(a) + v * math.sin(a)) * r
		local tangent = -u * math.sin(a) + v * math.cos(a)
		local normal = u:Cross(v)
		table.insert(list, piece("Part", Vector3.new(len, t, t), CFrame.fromMatrix(p, tangent, normal), color))
	end
end

-- an exact copy of a kept part (functional or puzzle part): row = { name, sx, sy, sz, x, y, z, hex, neon?, diamond? }
local function exact(parent: Instance, row: any, flags: any): Part
	local p = Instance.new("Part")
	p.Name = row[1]
	p.Size = Vector3.new(row[2], row[3], row[4])
	local cf = CFrame.new(row[5], row[6], row[7])
	if row.diamond then
		cf *= CFrame.Angles(0, 0, rad(45))
	end
	if row.turnY then
		cf *= CFrame.Angles(0, rad(row.turnY), 0)
	end
	p.CFrame = cf
	if row.cylinder then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Color = Color3.fromHex(row[8])
	p.Material = if row.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Transparency = flags.transparency or 0
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = flags.collide == true
	p.CanQuery = flags.query == true
	p.CanTouch = flags.touch == true
	p.CastShadow = flags.shadow ~= false
	p.Parent = parent
	return p
end

-- split [a, b] into blocks of minL .. maxL whose joints stay 0.6 away from the joints `below`
local function blockRow(rng: Random, a: number, b: number, minL: number, maxL: number, below: { number }): ({ any }, { number })
	local segs, joints = {}, {}
	local pos = a
	local function near(x: number): boolean
		for _, j in ipairs(below) do
			if math.abs(j - x) < 0.6 then
				return true
			end
		end
		return false
	end
	while b - pos > 0.01 do
		local len = rng:NextNumber(minL, maxL)
		if b - pos - len < minL * 0.6 then
			len = if b - pos <= maxL * 1.3 then b - pos else (b - pos) / 2
		end
		if pos + len < b - 0.01 and near(pos + len) then
			if b - (pos + len + 0.7) >= minL * 0.6 then
				len += 0.7
			elseif len - 0.7 >= minL * 0.6 then
				len -= 0.7
			end
		end
		table.insert(segs, { pos, pos + len })
		pos += len
		if pos < b - 0.01 then
			table.insert(joints, pos)
		end
	end
	return segs, joints
end

-- courses of blocks on one face. `frame` maps (u along the face, y, depth into the wall) with the face at depth 0;
-- rows = { {y0, y1} }; gapsFor(y0, y1) gives the u ranges to leave open on that row; chamfered = the outer edges cut
local function faceCourses(list: { BasePart }, rng: Random, frame: CFrame, u0: number, u1: number, rows: { any }, depth: number, color: Color3, Ht: number, chamfer: boolean, gapsFor: any?)
	local GAP = 0.08
	local below = {}
	for _, r in ipairs(rows) do
		local y0, y1 = r[1], r[2]
		local spans = if gapsFor then H.cutSegments(u0, u1, gapsFor(y0, y1)) else { { u0, u1 } }
		local joints = {}
		for _, sp in ipairs(spans) do
			local segs, js = blockRow(rng, sp[1], sp[2], 2.6, 4.6, below)
			for _, j in ipairs(js) do
				table.insert(joints, j)
			end
			local prev = nil
			for _, s in ipairs(segs) do
				local a = s[1] + (if s[1] > sp[1] + 0.01 then GAP / 2 else 0)
				local b = s[2] - (if s[2] < sp[2] - 0.01 then GAP / 2 else 0)
				local ti = toneIndex(rng, prev)
				prev = ti
				local yc = (y0 + y1) / 2
				local size = Vector3.new(b - a, y1 - y0 - GAP, depth)
				local cf = frame * CFrame.new((a + b) / 2, yc, depth / 2)
				local col = soft(color, yc, Ht, TONES[ti])
				if chamfer then
					table.insert(list, chamfered(size, cf, col, { "frontFace" }, 0.13))
				else
					table.insert(list, piece("Part", size, cf, col))
				end
			end
		end
		below = joints
	end
end

local OUT = { front = Vector3.new(0, 0, -1), back = Vector3.new(0, 0, 1), left = Vector3.new(-1, 0, 0), right = Vector3.new(1, 0, 0) }

-- the face plane and its span at footprint fraction f (fp(f) -> x0, x1, z0, z1)
local function faceAt(fp: any, f: number, face: string): (number, number, number)
	local x0, x1, z0, z1 = fp(f)
	if face == "front" then
		return z0, x0, x1
	elseif face == "back" then
		return z1, x0, x1
	elseif face == "left" then
		return x0, z0, z1
	end
	return x1, z0, z1
end

-- a point on a face: plane coordinate w, span coordinate s, height y
local function facePoint(face: string, w: number, s: number, y: number): Vector3
	if face == "front" or face == "back" then
		return Vector3.new(s, y, w)
	end
	return Vector3.new(w, y, s)
end

-- the cavetto cornice of B12, `k` x 2.4 tall from y0: a torus roll on the wall edges, a fillet, a cove of 3 slabs
-- stepping out on a concave curve (0.3 / 0.5 / 0.8 of the projection) with a fill wedge and reed grooves every 0.8
-- on each listed face, a flat chamfered top slab at the full footprint fp(1)
local function cavetto(list: { BasePart }, fp: any, y0: number, k: number, color: Color3, Ht: number, faces: { string })
	local x0, x1, z0, z1 = fp(0)
	table.insert(list, piece("Part", Vector3.new(x1 - x0, 0.5 * k, z1 - z0), CFrame.new((x0 + x1) / 2, y0 + 0.25 * k, (z0 + z1) / 2), scaled(color, 0.9)))
	for _, face in ipairs(faces) do
		local w, s0, s1 = faceAt(fp, 0, face)
		table.insert(list, cyl(facePoint(face, w, s0, y0 + 0.27 * k), facePoint(face, w, s1, y0 + 0.27 * k), 0.55, scaled(color, 1.08)))
	end
	local steps = { { 0.5, 0.7, 0.1, 0.92 }, { 0.7, 1.05, 0.3, 0.95 }, { 1.05, 1.4, 0.5, 0.98 }, { 1.4, 1.95, 0.8, 1.0 } }
	for _, st in ipairs(steps) do
		local a0, a1, b0, b1 = fp(st[3])
		local yc = y0 + (st[1] + st[2]) / 2 * k
		table.insert(list, piece("Part", Vector3.new(a1 - a0, (st[2] - st[1]) * k, b1 - b0), CFrame.new((a0 + a1) / 2, yc, (b0 + b1) / 2), soft(color, yc, Ht, st[4])))
	end
	local t0, t1, u0, u1 = fp(1)
	table.insert(list, chamfered(Vector3.new(t1 - t0, 0.45 * k, u1 - u0), CFrame.new((t0 + t1) / 2, y0 + 2.175 * k, (u0 + u1) / 2), soft(color, y0 + 2.2 * k, Ht, 1.05), { "vertical", "topFrontBack", "topSides" }, 0.1))
	for _, face in ipairs(faces) do
		local o = OUT[face]
		local wIn, s0, s1 = faceAt(fp, 0.1, face)
		local wOut = faceAt(fp, 0.8, face)
		local d = math.abs(wOut - wIn)
		local h = 1.25 * k
		local yc = y0 + 1.325 * k
		local centre = facePoint(face, (wIn + wOut) / 2, (s0 + s1) / 2, yc)
		local vy = -UP
		local vz = -o
		local along = if face == "front" or face == "back" then Vector3.xAxis else Vector3.zAxis
		table.insert(list, piece("WedgePart", Vector3.new(s1 - s0, h, d), CFrame.fromMatrix(centre, vy:Cross(vz), vy, vz), soft(color, yc, Ht, 0.97)))
		local dir = (UP * h + o * d).Unit
		local nrm = along:Cross(dir)
		if nrm:Dot(o) < 0 then
			nrm = -nrm
		end
		local slopeLen = math.sqrt(h * h + d * d)
		local n = math.floor((s1 - s0 - 0.4) / 0.8)
		local first = (s0 + s1) / 2 - (n - 1) / 2 * 0.8
		for i = 0, n - 1 do
			local s = first + i * 0.8
			local p = facePoint(face, (wIn + wOut) / 2, s, yc) + nrm * 0.02
			table.insert(list, piece("Part", Vector3.new(0.1, slopeLen * 0.95, 0.05), CFrame.fromMatrix(p, along, dir), scaled(color, 0.84)))
		end
	end
end

-- a twisted rope from a to b (short tilted strands, alternating tones)
local function rope(list: { BasePart }, a: Vector3, b: Vector3, d: number, color: Color3)
	local dir = (b - a).Unit
	local len = (b - a).Magnitude
	local n = math.max(2, math.floor(len / 0.45))
	local side = if math.abs(dir.Z) < 0.9 then Vector3.zAxis else Vector3.xAxis
	for i = 0, n - 1 do
		local p0 = a + dir * (len * i / n)
		local p1 = a + dir * (len * (i + 1) / n)
		local tilt = side * (if i % 2 == 0 then 0.06 else -0.06)
		table.insert(list, cyl(p0 - tilt, p1 + tilt, d, scaled(color, if i % 2 == 0 then 1 else 0.88)))
	end
end

-- a triangle (3 points, a wedge pair `t` thick) into the list
local function tri(list: { BasePart }, a: Vector3, b: Vector3, c: Vector3, t: number, color: Color3)
	H.triangleParts(list, a, b, c, t, CFrame.identity, color)
end

---------------------------------------------------------------------
-- 02 PYLON TEMPLE GATE (kit Gates.Gate_Desert_4, 81 parts; Zones.Desert.Desert_4.Gate, attr SubZoneId).
---------------------------------------------------------------------
-- the door glyph field, children of the Barrier, copied exactly from the game copy (docs B12 "Glyph record")
local PYLON_DOOR = {
	{ "Border", 10.6, 0.6, 0.3, -6, 1.1, -1.6, "ffc93c" },
	{ "Border", 10.6, 0.6, 0.3, -6, 14.9, -1.6, "ffc93c" },
	{ "Border", 10.6, 0.6, 0.3, 6, 1.1, -1.6, "ffc93c" },
	{ "Border", 10.6, 0.6, 0.3, 6, 14.9, -1.6, "ffc93c" },
	{ "Glyph", 0.6, 2.2, 0.3, -9.4, 3.5, -1.6, "b89262" },
	{ "Glyph", 2, 0.6, 0.3, -9.4, 5.8, -1.6, "b89262" },
	{ "Glyph", 2, 0.6, 0.3, -9.4, 7.2, -1.6, "b89262" },
	{ "Glyph", 1.5, 1.5, 0.3, -9.4, 9.75, -1.6, "b89262", diamond = true },
	{ "Glyph", 2, 0.6, 0.3, -9.4, 12, -1.6, "ffc93c", neon = true },
	{ "Glyph", 2, 0.6, 0.3, -9.4, 13.4, -1.6, "ffc93c", neon = true },
	{ "Glyph", 2, 0.6, 0.3, -6, 2.7, -1.6, "ffc93c", neon = true },
	{ "Glyph", 2, 0.6, 0.3, -6, 4.1, -1.6, "ffc93c", neon = true },
	{ "Glyph", 0.6, 2.2, 0.3, -6, 6.6, -1.6, "b89262" },
	{ "Glyph", 0.6, 2.2, 0.3, -6, 9.7, -1.6, "b89262" },
	{ "Glyph", 0.6, 1.5, 0.3, -6, 12.45, -1.6, "b89262" },
	{ "Glyph", 2, 0.6, 0.3, -6, 13.5, -1.6, "b89262" },
	{ "Glyph", 1.5, 1.5, 0.3, -2.6, 3.55, -1.6, "b89262", diamond = true },
	{ "Glyph", 0.6, 2.2, 0.3, -2.6, 6.6, -1.6, "ffc93c", neon = true },
	{ "Glyph", 1.5, 1.5, 0.3, -2.6, 9.75, -1.6, "b89262", diamond = true },
	{ "Glyph", 0.6, 1.5, 0.3, -2.6, 12.45, -1.6, "b89262" },
	{ "Glyph", 2, 0.6, 0.3, -2.6, 13.5, -1.6, "b89262" },
	{ "Glyph", 2, 0.6, 0.3, 2.6, 2.7, -1.6, "b89262" },
	{ "Glyph", 2, 0.6, 0.3, 2.6, 4.1, -1.6, "b89262" },
	{ "Glyph", 0.6, 1.5, 0.3, 2.6, 6.25, -1.6, "ffc93c", neon = true },
	{ "Glyph", 2, 0.6, 0.3, 2.6, 7.3, -1.6, "ffc93c", neon = true },
	{ "Glyph", 1.5, 1.5, 0.3, 2.6, 9.75, -1.6, "b89262", diamond = true },
	{ "Glyph", 0.6, 2.2, 0.3, 2.6, 12.8, -1.6, "b89262" },
	{ "Glyph", 2, 0.6, 0.3, 6, 2.7, -1.6, "ffc93c", neon = true },
	{ "Glyph", 2, 0.6, 0.3, 6, 4.1, -1.6, "ffc93c", neon = true },
	{ "Glyph", 0.6, 1.5, 0.3, 6, 6.25, -1.6, "b89262" },
	{ "Glyph", 2, 0.6, 0.3, 6, 7.3, -1.6, "b89262" },
	{ "Glyph", 2, 0.6, 0.3, 6, 8.9, -1.6, "b89262" },
	{ "Glyph", 2, 0.6, 0.3, 6, 10.3, -1.6, "b89262" },
	{ "Glyph", 1.5, 1.5, 0.3, 6, 12.85, -1.6, "b89262", diamond = true },
	{ "Glyph", 0.6, 2.2, 0.3, 9.4, 3.5, -1.6, "b89262" },
	{ "Glyph", 0.6, 1.5, 0.3, 9.4, 6.25, -1.6, "b89262" },
	{ "Glyph", 2, 0.6, 0.3, 9.4, 7.3, -1.6, "b89262" },
	{ "Glyph", 2, 0.6, 0.3, 9.4, 8.9, -1.6, "b89262" },
	{ "Glyph", 2, 0.6, 0.3, 9.4, 10.3, -1.6, "b89262" },
	{ "Glyph", 0.6, 1.5, 0.3, 9.4, 12.45, -1.6, "ffc93c", neon = true },
	{ "Glyph", 2, 0.6, 0.3, 9.4, 13.5, -1.6, "ffc93c", neon = true },
	{ "Seam", 0.5, 16, 0.3, 0, 8.05, -1.6, "b89262" },
}
-- the tower figures (children of the model; the belt bars are 0.4 thick in the game copy, 0.3 in the old kit)
local PYLON_FIGURES = {
	{ "Glyph", 2, 5.5, 0.3, -23.6, 9.75, -4.4, "b89262" },
	{ "Glyph", 5, 8, 0.3, -22, 16.5, -4.4, "b89262" },
	{ "Glyph", 8, 0.8, 0.4, -22, 17.9, -4.4, "ffc93c", neon = true },
	{ "Glyph", 3, 3, 0.3, -22, 22.5, -4.4, "b89262" },
	{ "Glyph", 2, 5.5, 0.3, -20.4, 9.75, -4.4, "b89262" },
	{ "Glyph", 2, 5.5, 0.3, 20.4, 9.75, -4.4, "b89262" },
	{ "Glyph", 5, 8, 0.3, 22, 16.5, -4.4, "b89262" },
	{ "Glyph", 8, 0.8, 0.4, 22, 17.9, -4.4, "ffc93c", neon = true },
	{ "Glyph", 3, 3, 0.3, 22, 22.5, -4.4, "b89262" },
	{ "Glyph", 2, 5.5, 0.3, 23.6, 9.75, -4.4, "b89262" },
}
local PYLON_KEPT = {
	{ "PriceSign", 12, 4, 0.5, 0, 21.1, -2.4, "f1ca8c" },
	{ "SunDisc", 0.6, 5, 5, 0, 26, -2.2, "ffc93c", neon = true, cylinder = true, turnY = 90 },
}
Gates.PYLON_DOOR, Gates.PYLON_FIGURES, Gates.PYLON_KEPT = PYLON_DOOR, PYLON_FIGURES, PYLON_KEPT

-- today's colliding parts except the Barrier and the exact copies (their own collision is kept)
D.ENVELOPES.pylon_temple_gate = {
	{ "Block", 13.2, 5, 0.4, { 0, 21.1, -2.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- SignBack
	{ "Block", 6, 0.8, 0.5, { 6, 24.8, -2.2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Wing
	{ "Block", 4, 0.7, 0.5, { -5.2, 23.95, -2.2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Wing
	{ "Block", 8, 1.6, 0.5, { 6.4, 26.2, -2.2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Wing
	{ "Block", 6, 0.8, 0.5, { -6, 24.8, -2.2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Wing
	{ "Block", 29, 2.2, 2.4, { 0, 17.1, -4.6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Header
	{ "Block", 8, 1.6, 0.5, { -6.4, 26.2, -2.2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Wing
	{ "Block", 26, 2, 11.6, { 0, 31, 3, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Cornice
	{ "Block", 24, 14, 10, { 0, 23, 3, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Lintel
	{ "Block", 2.4, 16, 2, { -13.3, 8, -4.6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Jamb
	{ "Block", 20.6, 0.9, 12.6, { -22, 34.25, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Trim
	{ "Block", 20.6, 0.9, 12.6, { -22, 36.05, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Trim
	{ "WedgePart", 12, 38, 8, { -36, 19, 2, 0, 0, 1, 0, 1, 0, -1, 0, 0 } }, -- TowerSlope
	{ "Block", 20.6, 2, 12.8, { -22, 1, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Footing
	{ "Block", 20, 38, 12, { -22, 19, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Tower
	{ "Block", 12, 20, 0.4, { -22, 16, -4.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Carving
	{ "Block", 22, 2.4, 13.6, { -22.6, 39.2, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Cornice
	{ "Block", 4, 0.7, 0.5, { 5.2, 23.95, -2.2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Wing
	{ "Block", 2.4, 16, 2, { 13.3, 8, -4.6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Jamb
	{ "Block", 12, 20, 0.4, { 22, 16, -4.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Carving
	{ "Block", 20.6, 0.9, 12.6, { 22, 36.05, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Trim
	{ "Block", 20.6, 0.9, 12.6, { 22, 34.25, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Trim
	{ "Block", 20, 38, 12, { 22, 19, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Tower
	{ "Block", 20.6, 2, 12.8, { 22, 1, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Footing
	{ "WedgePart", 12, 38, 8, { 36, 19, 2, 0, 0, -1, 0, 1, 0, 1, 0, 0 } }, -- TowerSlope
	{ "Block", 22, 2.4, 13.6, { 22.6, 39.2, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Cornice
}

---------------------------------------------------------------------
-- Today's layout, opening, colours and gate contract (docs B12). Each tower: a stepped footing; a mortar core faced
-- with courses of cut blocks (17 courses of 1.87 to the trims, staggered joints, tone steps, chamfered front edges);
-- the batter slope in courses (a box and a wedge per course, joint lines on all 3 faces) with torus rolls on its
-- edges banded lapis / gold; torus rolls on the inner corners; today's lapis and gold trims as inlay bands (gold
-- lotus petals on lapis, a lapis chequer on gold, gold rules); a cavetto cornice (roll, fillet, cove of 3 slabs,
-- fill wedges with reed grooves, top slab). The carving panels: today's 10 figure parts kept exactly, now in SUNK
-- RELIEF (a raised panel face cut around each figure 0.2 deep, lighter cut walls with a bevel, a darker floor) in a
-- stone frame. A niche at the foot of a flag pole on each tower front (cedar pole with gold bands, clamps and cap,
-- a red banner with gold trims, forked tail and a lapis eye). The lintel in courses with a soffit and its own
-- cavetto cornice. The stone door frame: jambs of 4 blocks with torus rolls banded in gold, the header with a lapis
-- inlay and gold rosettes. The door (the Barrier, today's sandstone slab with its 42 glyph / border / seam parts kept
-- exactly) gets a dark-wood frame (outer stiles, rails, centre stiles at the seam) front and back with gold studs
-- every 1.5, and 2 gold ring handles. The winged sun disk: today's Neon SunDisc kept, a gold ring, 2 gold uraei, 3
-- rows of feathers per wing in today's places (gold coverts with pointed tips, lapis, turquoise), a gold top edge.
-- The price sign: today's PriceSign kept, a gold back with a raised frame and lapis corners. Sand drifts at the feet.
-- Collision: the visible unions do not collide; an invisible "Collision" union is today's colliding parts; the
-- Barrier, PriceSign, SunDisc and the 10 figure parts keep their own collision as today.
-- Parts: TowerL, TowerR, Stone, Carving, Inlay, Gold, Wings, Poles, Cloth, Sand, Collision, Barrier (+ DoorFrame,
-- DoorGold and the 42 kept parts), PriceSign, SunDisc, Glyph x10.
---------------------------------------------------------------------
function Gates.pylon_temple_gate(): Model
	local m = Instance.new("Model")
	m.Name = "pylon_temple_gate"
	local rng = Random.new(20261119)
	H.setBevelSelf(true)
	local Ht = 40.4
	local TOWER, SLOPE, CARVE, STONE = rgb(204, 160, 100), rgb(193, 152, 95), rgb(216, 170, 106), C.Footing
	local MORTAR = scaled(TOWER, 0.72)
	local U, add = lists()
	U.Inlay, U.Gold = {}, {}

	-- the course rows: 17 to the lapis trim, then the 2 strips between and above the trims
	local CH = 31.8 / 17
	local ROWS = {}
	for k = 0, 16 do
		table.insert(ROWS, { 2 + k * CH, 2 + (k + 1) * CH })
	end
	table.insert(ROWS, { 34.7, 35.6 })
	table.insert(ROWS, { 36.5, 38 })
	local NICHE_TOP = 2 + 6 * CH

	for _, sx in ipairs({ -1, 1 }) do
		local T = if sx < 0 then "TowerL" else "TowerR"
		U[T] = {}
		local list = U[T]
		local cx = sx * 22
		local function X(x: number): number -- right-tower coordinates (12 .. 32 inner to outer) to this side
			return sx * x
		end
		-- the stepped footing (today's 20.6 x 2 x 12.8): 2 steps of blocks
		local prev = nil
		for i = 0, 3 do
			local ti = toneIndex(rng, prev)
			prev = ti
			local a, b = 11.7 + i * 5.15, 11.7 + (i + 1) * 5.15
			table.insert(list, chamfered(Vector3.new(5.15 - 0.06, 1.1, 12.8), CFrame.new(X((a + b) / 2), 0.55, 2), soft(STONE, 0.5, Ht, TONES[ti]), { "topFrontBack", "topSides" }, 0.15))
		end
		table.insert(list, chamfered(Vector3.new(20.2, 0.9, 12.4), CFrame.new(cx, 1.55, 2), soft(STONE, 1.5, Ht, 1.04), { "topFrontBack", "topSides" }, 0.15))
		-- the core and the faced courses: front (chamfered; the carving panel and the niche left open), back, inner face
		table.insert(list, piece("Part", Vector3.new(19.8, 36, 10.8), CFrame.new(cx, 20, 2), MORTAR))
		local gaps = function(y0: number, y1: number)
			local g = {}
			if y0 >= 5.49 and y1 <= 26.51 then
				table.insert(g, if sx > 0 then { 15.5, 28.5 } else { -28.5, -15.5 })
			end
			if y1 <= NICHE_TOP + 0.01 then
				table.insert(g, if sx > 0 then { 29.25, 30.75 } else { -30.75, -29.25 })
			end
			return g
		end
		local u0, u1 = math.min(X(12), X(32)), math.max(X(12), X(32))
		faceCourses(list, rng, CFrame.new(0, 0, -4), u0, u1, ROWS, 0.6, TOWER, Ht, true, gaps)
		faceCourses(list, rng, CFrame.new(0, 0, 8) * CFrame.Angles(0, math.pi, 0), -u1, -u0, ROWS, 0.6, TOWER, Ht, false)
		local innerRows = {}
		for _, r in ipairs(ROWS) do
			if r[1] < 16.5 or r[1] >= 30 then
				table.insert(innerRows, r)
			end
		end
		if sx > 0 then
			faceCourses(list, rng, CFrame.fromMatrix(Vector3.new(12, 0, 0), Vector3.new(0, 0, -1), UP), -7.4, 3.4, innerRows, 0.6, TOWER, Ht, false)
		else
			faceCourses(list, rng, CFrame.fromMatrix(Vector3.new(-12, 0, 0), Vector3.new(0, 0, 1), UP), -3.4, 7.4, innerRows, 0.6, TOWER, Ht, false)
		end
		-- the niche at the foot of the flag pole
		table.insert(list, piece("Part", Vector3.new(1.5, NICHE_TOP - 2, 0.05), CFrame.new(X(30), (2 + NICHE_TOP) / 2, -3.42), scaled(TOWER, 0.55)))
		-- the batter slope in courses: a box and a wedge per course (today's 8 wide at the ground, 0 at y 38)
		local slopeRows = { { 0, 2 } }
		for _, r in ipairs(ROWS) do
			table.insert(slopeRows, r)
		end
		table.insert(slopeRows, 19, { 33.8, 34.7 })
		table.insert(slopeRows, 21, { 35.6, 36.5 })
		local function xs(y: number): number
			return 40 - 8 * y / 38
		end
		local joint = scaled(SLOPE, 0.74)
		local nrm = Vector3.new(sx * 38, 8, 0).Unit
		local upSlope = Vector3.new(-sx * 8, 38, 0).Unit
		prev = nil
		for _, r in ipairs(slopeRows) do
			local y0, y1 = r[1], r[2]
			local h = y1 - y0
			local ti = toneIndex(rng, prev)
			prev = ti
			local col = soft(SLOPE, (y0 + y1) / 2, Ht, TONES[ti])
			local wTop = xs(y1) - 32
			if wTop > 0.02 then
				table.insert(list, piece("Part", Vector3.new(wTop, h, 12), CFrame.new(X(32 + wTop / 2), (y0 + y1) / 2, 2), col))
			end
			local wd = xs(y0) - xs(y1)
			table.insert(list, piece("WedgePart", Vector3.new(12, h, wd), CFrame.new(X(xs(y1) + wd / 2), (y0 + y1) / 2, 2) * CFrame.Angles(0, -sx * rad(90), 0), col))
			-- joint lines: the bed joint on the front, back and slope faces, one vertical joint front and back
			if y1 < 37.9 then
				local w = xs(y1) - 32
				for _, z in ipairs({ -4.03, 8.03 }) do
					table.insert(list, piece("Part", Vector3.new(w, 0.08, 0.06), CFrame.new(X(32 + w / 2), y1, z), joint))
				end
				local p = Vector3.new(X(xs(y1)), y1, 2) + nrm * 0.02
				table.insert(list, piece("Part", Vector3.new(0.06, 0.09, 12), CFrame.fromMatrix(p, nrm, upSlope), joint))
			end
			if wTop > 1.2 then
				for _, z in ipairs({ -4.03, 8.03 }) do
					local jx = 32 + rng:NextNumber(0.4, wTop - 0.4)
					table.insert(list, piece("Part", Vector3.new(0.08, h, 0.06), CFrame.new(X(jx), (y0 + y1) / 2, z), joint))
				end
			end
		end
		-- torus rolls: the slope edges (front, back) and the inner corners, banded lapis / gold every 2.4
		local function banded(a: Vector3, b: Vector3, d: number, color: Color3)
			table.insert(list, cyl(a, b, d, color))
			local dir = (b - a).Unit
			local len = (b - a).Magnitude
			local n = math.floor(len / 2.4)
			for i = 1, n do
				local c = a + dir * (len * i / (n + 1))
				table.insert(U.Inlay, cyl(c - dir * 0.075, c + dir * 0.075, d + 0.14, if i % 2 == 0 then C.Gold else C.Lapis))
			end
		end
		for _, z in ipairs({ -4, 8 }) do
			banded(Vector3.new(X(40), 0.05, z), Vector3.new(X(32), 37.9, z), 0.5, scaled(SLOPE, 1.06))
		end
		banded(Vector3.new(X(12), 18.3, -4), Vector3.new(X(12), 33.75, -4), 0.5, scaled(TOWER, 1.06))
		banded(Vector3.new(X(12), 2.1, 8), Vector3.new(X(12), 15.9, 8), 0.5, scaled(TOWER, 1.06))
		-- today's trims as inlay bands: lapis with gold lotus petals (y 34.25), gold with a lapis chequer (y 36.05)
		table.insert(U.Inlay, chamfered(Vector3.new(20.6, 0.9, 12.6), CFrame.new(cx, 34.25, 2), C.Lapis, { "vertical", "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }, 0.06))
		table.insert(U.Gold, chamfered(Vector3.new(20.6, 0.9, 12.6), CFrame.new(cx, 36.05, 2), C.Gold, { "vertical", "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }, 0.06))
		for _, y in ipairs({ 33.74, 34.76 }) do
			table.insert(U.Gold, piece("Part", Vector3.new(20.7, 0.12, 12.7), CFrame.new(cx, y, 2), C.Gold))
		end
		for i = -8, 8 do
			local x = cx + i * 1.2
			for _, z in ipairs({ -4.33, 8.33 }) do
				tri(U.Gold, Vector3.new(x - 0.3, 33.88, z), Vector3.new(x + 0.3, 33.88, z), Vector3.new(x, 34.62, z), 0.05, C.Gold)
			end
		end
		for i = -4, 4 do
			local z = 2 + i * 1.2
			local x = X(11.67)
			tri(U.Gold, Vector3.new(x, 33.88, z - 0.3), Vector3.new(x, 33.88, z + 0.3), Vector3.new(x, 34.62, z), 0.05, C.Gold)
		end
		for i = -11, 11 do
			for row = 0, 1 do
				if (i + row) % 2 == 0 then
					local y = 35.83 + row * 0.44
					for _, z in ipairs({ -4.32, 8.32 }) do
						table.insert(U.Inlay, piece("Part", Vector3.new(0.42, 0.4, 0.06), CFrame.new(cx + i * 0.9, y, z), C.Lapis))
					end
					if math.abs(i) <= 6 then
						table.insert(U.Inlay, piece("Part", Vector3.new(0.06, 0.4, 0.42), CFrame.new(X(11.68), y, 2 + i * 0.9), C.Lapis))
					end
				end
			end
		end
		-- the cavetto cornice (today's 22 x 2.4 x 13.6 at y 38 .. 40.4)
		local fp = function(f: number)
			if sx > 0 then
				return 12 - 0.4 * f, 32 + 1.6 * f, -4 - 0.8 * f, 8 + 0.8 * f
			end
			return -32 - 1.6 * f, -12 + 0.4 * f, -4 - 0.8 * f, 8 + 0.8 * f
		end
		cavetto(list, fp, 38, 1, STONE, Ht, { "front", "back", "left", "right" })

		-- the carving panel in sunk relief: a darker floor, the raised face cut 0.2 deep around today's figure parts
		-- (lighter cut walls, a 0.12 bevel at the lip), a stone frame
		U.Carving = U.Carving or {}
		table.insert(U.Carving, piece("Part", Vector3.new(12, 20, 0.4), CFrame.new(cx, 16, -4.1), scaled(CARVE, 0.84)))
		local negs = {}
		for _, f in ipairs(PYLON_FIGURES) do
			if f[5] * sx > 0 then
				local w, h = f[2] + 0.6, f[3] + 0.6
				table.insert(negs, piece("Part", Vector3.new(w, h, 2), CFrame.new(f[5], f[6], -4.5), scaled(CARVE, 1.1)))
				table.insert(negs, piece("Part", Vector3.new(w + 0.24, h + 0.24, 1), CFrame.new(f[5], f[6], -5.15), scaled(CARVE, 1.16)))
			end
		end
		table.insert(U.Carving, H.subtractKeep(Vector3.new(12, 20, 0.45), CFrame.new(cx, 16, -4.525), CARVE, negs))
		for _, e in ipairs({ { 0, 5.75, 13, 0.5 }, { 0, 26.25, 13, 0.5 }, { -6.25, 16, 0.5, 20 }, { 6.25, 16, 0.5, 20 } }) do
			table.insert(U.Carving, chamfered(Vector3.new(e[3], e[4], 0.6), CFrame.new(cx + e[1], e[2], -4.5), soft(STONE, e[2], Ht, 1.02), { "frontFace" }, 0.1))
		end

		-- the flag pole in front of the niche: a stone foot, the cedar pole, gold bands, clamps and cap; the banner
		local px = X(30)
		add("Stone", chamfered(Vector3.new(1.1, 0.6, 1.1), CFrame.new(px, 0.3, -5.0), soft(STONE, 0.3, Ht, 0.95), { "vertical", "topFrontBack", "topSides" }, 0.1))
		U.Poles = U.Poles or {}
		table.insert(U.Poles, cyl(Vector3.new(px, 0.6, -5.0), Vector3.new(px, 45.4, -5.0), 0.5, C.DarkWood))
		for _, y in ipairs({ 1.0, 13.4, 26, 33.2, 44.4 }) do
			table.insert(U.Gold, cyl(Vector3.new(px, y - 0.1, -5.0), Vector3.new(px, y + 0.1, -5.0), 0.64, C.Gold))
		end
		for _, y in ipairs({ 20, 31.5 }) do
			table.insert(U.Gold, piece("Part", Vector3.new(0.28, 0.28, 1.05), CFrame.new(px, y, -4.5), scaled(C.Gold, 0.9)))
		end
		table.insert(U.Gold, piece("Part", Vector3.new(0.62, 0.62, 0.62), CFrame.new(px, 45.65, -5.0), C.Gold, { shape = Enum.PartType.Ball }))
		table.insert(U.Gold, chamfered(Vector3.new(0.4, 0.6, 0.4), CFrame.new(px, 46.15, -5.0), C.Gold, { "topFrontBack", "topSides" }, 0.15))
		local rodEnd = X(28.0)
		table.insert(U.Gold, cyl(Vector3.new(px, 45.1, -5.0), Vector3.new(rodEnd, 45.1, -5.0), 0.22, C.Gold))
		table.insert(U.Gold, piece("Part", Vector3.new(0.34, 0.34, 0.34), CFrame.new(rodEnd, 45.1, -5.0), C.Gold, { shape = Enum.PartType.Ball }))
		U.Cloth = U.Cloth or {}
		local bx = X(29.0)
		for k = 0, 2 do
			local x = bx + (k - 1) * 0.5
			table.insert(U.Cloth, piece("Part", Vector3.new(0.52, 5.9, 0.13), CFrame.new(x, 41.95, -5.0 + (if k % 2 == 0 then -0.04 else 0.04)) * CFrame.Angles(0, rad(if k % 2 == 0 then 4 else -4), 0), scaled(C.Red, if k % 2 == 0 then 1 else 0.9)))
		end
		tri(U.Cloth, Vector3.new(bx - 0.75, 39.0, -5.0), Vector3.new(bx, 39.0, -5.0), Vector3.new(bx - 0.45, 38.2, -5.0), 0.13, scaled(C.Red, 0.94))
		tri(U.Cloth, Vector3.new(bx, 39.0, -5.0), Vector3.new(bx + 0.75, 39.0, -5.0), Vector3.new(bx + 0.45, 38.2, -5.0), 0.13, scaled(C.Red, 0.94))
		for _, e in ipairs({ -0.8, 0.8 }) do
			table.insert(U.Gold, piece("Part", Vector3.new(0.12, 6.0, 0.18), CFrame.new(bx + e, 41.95, -5.0), C.Gold))
		end
		table.insert(U.Gold, piece("Part", Vector3.new(1.72, 0.15, 0.18), CFrame.new(bx, 39.05, -5.0), C.Gold))
		table.insert(U.Inlay, piece("Part", Vector3.new(0.55, 0.55, 0.06), CFrame.new(bx, 43.2, -5.12) * CFrame.Angles(0, 0, rad(45)), C.Lapis))
		table.insert(U.Gold, piece("Part", Vector3.new(0.22, 0.22, 0.06), CFrame.new(bx, 43.2, -5.17), C.Gold, { shape = Enum.PartType.Ball }))

		-- sand drifts at the foot (never in the opening or on the door's path)
		U.Sand = U.Sand or {}
		for _, d in ipairs({ { 21.8, 12.6, -4.4, -1 }, { 22.3, 18.2, 8.4, 1 } }) do
			local turn = if d[4] < 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
			table.insert(U.Sand, piece("WedgePart", Vector3.new(d[2], 0.6, 1.2), CFrame.new(X(d[1]), 0.3, d[3] + d[4] * 0.6) * turn, SAND))
			table.insert(U.Sand, piece("Part", Vector3.new(d[2] - 0.8, 0.5, 0.5), CFrame.new(X(d[1]), 0.36, d[3] + d[4] * 0.12), SAND, { shape = Enum.PartType.Cylinder }))
		end
		table.insert(U.Sand, piece("WedgePart", Vector3.new(11, 0.7, 1.4), CFrame.new(X(40.7), 0.35, 2) * CFrame.Angles(0, -sx * rad(90), 0), SAND))
	end

	-- the lintel in courses over a core, a soffit, its own cavetto cornice (today's 26 x 2 x 11.6 at y 30 .. 32)
	add("Stone", piece("Part", Vector3.new(24, 14, 8.8), CFrame.new(0, 23, 3), MORTAR))
	local LROWS = {}
	for k = 0, 6 do
		table.insert(LROWS, { 16 + k * 2, 18 + k * 2 })
	end
	faceCourses(U.Stone, rng, CFrame.new(0, 0, -2), -12, 12, LROWS, 0.6, TOWER, Ht, true)
	faceCourses(U.Stone, rng, CFrame.new(0, 0, 8) * CFrame.Angles(0, math.pi, 0), -12, 12, LROWS, 0.6, TOWER, Ht, false)
	add("Stone", piece("Part", Vector3.new(23.9, 0.25, 8.8), CFrame.new(0, 16.125, 3), soft(TOWER, 16, Ht, 0.9)))
	cavetto(U.Stone, function(f: number)
		return -12 - 1.0 * f, 12 + 1.0 * f, -2 - 0.8 * f, 8 + 0.8 * f
	end, 30, 2 / 2.4, STONE, Ht, { "front", "back" })

	-- the stone door frame: jambs of 4 blocks with a banded roll, the header with a lapis inlay and gold rosettes
	for _, sx in ipairs({ -1, 1 }) do
		local prev = nil
		for i = 0, 3 do
			local ti = toneIndex(rng, prev)
			prev = ti
			add("Stone", chamfered(Vector3.new(2.4, 3.94, 2), CFrame.new(sx * 13.3, 2 + i * 4, -4.6), soft(STONE, 2 + i * 4, Ht, TONES[ti]), { "vertical", "topFrontBack", "bottomFrontBack" }, 0.12))
		end
		add("Stone", cyl(Vector3.new(sx * 12.1, 0.1, -5.6), Vector3.new(sx * 12.1, 15.9, -5.6), 0.42, scaled(STONE, 1.08)))
		for _, y in ipairs({ 0.6, 4, 8, 12, 15.5 }) do
			table.insert(U.Gold, cyl(Vector3.new(sx * 12.1, y - 0.08, -5.6), Vector3.new(sx * 12.1, y + 0.08, -5.6), 0.56, C.Gold))
		end
	end
	add("Stone", chamfered(Vector3.new(29, 2.2, 2.4), CFrame.new(0, 17.1, -4.6), soft(STONE, 17.1, Ht, 1.02), { "vertical", "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }, 0.14))
	add("Stone", cyl(Vector3.new(-14.4, 18.2, -5.8), Vector3.new(14.4, 18.2, -5.8), 0.4, scaled(STONE, 1.08)))
	table.insert(U.Inlay, piece("Part", Vector3.new(27.4, 0.55, 0.08), CFrame.new(0, 17.1, -5.83), C.Lapis))
	for _, y in ipairs({ 16.76, 17.44 }) do
		table.insert(U.Gold, piece("Part", Vector3.new(27.5, 0.1, 0.1), CFrame.new(0, y, -5.84), C.Gold))
	end
	for i = -6, 6 do
		table.insert(U.Gold, piece("Part", Vector3.new(0.32, 0.32, 0.08), CFrame.new(i * 2.1, 17.1, -5.88) * CFrame.Angles(0, 0, rad(45)), C.Gold))
	end

	-- the winged sun disk: a gold ring round today's SunDisc, 2 uraei, 3 rows of feathers per wing, a gold top edge
	U.Wings = {}
	ring(U.Gold, Vector3.new(0, 26, -2.2), Vector3.xAxis, UP, 2.65, 0.3, 20, C.Gold)
	for _, sx in ipairs({ -1, 1 }) do
		-- uraei (rearing cobras) at the foot of the disc
		local pts = { Vector3.new(sx * 2.75, 23.35, -2.58), Vector3.new(sx * 3.0, 23.7, -2.58), Vector3.new(sx * 2.82, 24.05, -2.58), Vector3.new(sx * 2.95, 24.35, -2.58) }
		for i = 1, 3 do
			table.insert(U.Gold, cyl(pts[i], pts[i + 1], 0.3, C.Gold))
		end
		table.insert(U.Gold, chamfered(Vector3.new(0.6, 0.6, 0.18), CFrame.new(sx * 2.95, 24.6, -2.6), C.Gold, { "topFrontBack", "bottomFrontBack" }, 0.16))
		table.insert(U.Gold, piece("Part", Vector3.new(0.26, 0.26, 0.26), CFrame.new(sx * 2.95, 24.98, -2.62), scaled(C.Gold, 1.05), { shape = Enum.PartType.Ball }))
		-- the gold coverts (today's 8 x 1.6 bar at x 2.4 .. 10.4), each feather with a pointed tip and a rib
		for k = 0, 6 do
			local w = 8 / 7
			local x0 = 2.4 + k * w
			local x = sx * (x0 + w / 2)
			local top = 27.0 + 0.07 * k
			local col = scaled(C.Gold, if k % 2 == 0 then 1 else 0.92)
			table.insert(U.Wings, piece("Part", Vector3.new(w - 0.06, top - 25.4, 0.5), CFrame.new(x, (top + 25.4) / 2, -2.2), col))
			tri(U.Wings, Vector3.new(x - (w / 2 - 0.03), 25.4, -2.25), Vector3.new(x + (w / 2 - 0.03), 25.4, -2.25), Vector3.new(x + sx * 0.18, 24.95, -2.25), 0.4, col)
			table.insert(U.Wings, piece("Part", Vector3.new(0.07, top - 25.6, 0.05), CFrame.new(x, (top + 25.6) / 2, -2.47), scaled(C.Gold, 0.8)))
		end
		table.insert(U.Gold, cyl(Vector3.new(sx * 2.4, 27.05, -2.2), Vector3.new(sx * 10.45, 27.5, -2.2), 0.2, scaled(C.Gold, 1.08)))
		-- lapis secondaries (today's 6 x 0.8 bar at x 3 .. 9) and turquoise (4 x 0.7 at x 3.2 .. 7.2)
		for k = 0, 5 do
			local x = sx * (3.5 + k)
			local col = scaled(C.Lapis, if k % 2 == 0 then 1 else 0.88)
			table.insert(U.Wings, piece("Part", Vector3.new(0.94, 0.8, 0.5), CFrame.new(x, 24.8, -2.3), col))
			tri(U.Wings, Vector3.new(x - 0.46, 24.4, -2.35), Vector3.new(x + 0.46, 24.4, -2.35), Vector3.new(x + sx * 0.15, 24.08, -2.35), 0.4, col)
		end
		for k = 0, 3 do
			local x = sx * (3.7 + k)
			table.insert(U.Wings, chamfered(Vector3.new(0.94, 0.7, 0.5), CFrame.new(x, 23.95, -2.4), scaled(C.Turquoise, if k % 2 == 0 then 1 else 0.88), { "bottomFrontBack" }, 0.2))
		end
	end

	-- the price sign: a gold back (today's SignBack) with a raised frame round today's PriceSign and lapis corners
	table.insert(U.Gold, chamfered(Vector3.new(13.2, 5, 0.4), CFrame.new(0, 21.1, -2.1), scaled(C.Gold, 0.9), { "vertical" }, 0.1))
	for _, e in ipairs({ { 0, 23.35, 13.2, 0.5 }, { 0, 18.85, 13.2, 0.5 }, { -6.3, 21.1, 0.6, 4 }, { 6.3, 21.1, 0.6, 4 } }) do
		table.insert(U.Gold, chamfered(Vector3.new(e[3], e[4], 0.25), CFrame.new(e[1], e[2], -2.42), C.Gold, { "frontFace" }, 0.07))
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, y in ipairs({ 18.85, 23.35 }) do
			table.insert(U.Inlay, piece("Part", Vector3.new(0.34, 0.34, 0.06), CFrame.new(sx * 6.3, y, -2.57) * CFrame.Angles(0, 0, rad(45)), C.Lapis))
		end
	end

	envelope(m, "pylon_temple_gate")
	local QUERY = { TowerL = true, TowerR = true, Stone = true, Carving = true }
	local names = {}
	for name in pairs(U) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		merge(m, name, U[name], { query = QUERY[name] == true })
		task.wait()
	end

	-- the Barrier: today's door slab and its 42 glyph / border / seam parts, exactly; the dark-wood door frame front
	-- and back with gold studs every 1.5, 2 gold ring handles (all children of the Barrier: they vanish when it opens)
	local barrier = exact(m, { "Barrier", 24, 16, 3, 0, 8, 0, "e2be84" }, { collide = true, query = true, touch = true })
	barrier:SetAttribute("BarrierDecorIsChildOfBarrier", true)
	for _, row in ipairs(PYLON_DOOR) do
		exact(barrier, row, { query = true, touch = true })
	end
	local wood, gold = {}, {}
	local function stud(pos: Vector3, s: number) -- a gold stud: a small cube turned on its corner
		table.insert(gold, piece("Part", Vector3.new(s, s, s), CFrame.new(pos) * CFrame.Angles(rad(45), rad(45), 0), C.Gold))
	end
	for _, z in ipairs({ -1.65, 1.65 }) do
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(wood, H.timber(Vector3.new(0.8, 16, 0.3), CFrame.new(sx * 11.6, 8, z), C.DarkWood, 0.08))
			table.insert(wood, H.timber(Vector3.new(0.45, 14.4, 0.3), CFrame.new(sx * 0.475, 8, z), scaled(C.DarkWood, 0.92), 0.06))
		end
		for _, y in ipairs({ 0.4, 15.6 }) do
			table.insert(wood, H.timber(Vector3.new(22.4, 0.8, 0.3), CFrame.new(0, y, z), scaled(C.DarkWood, 0.96), 0.08))
		end
		local zs = z + (if z < 0 then -0.17 else 0.17)
		for _, sx in ipairs({ -1, 1 }) do
			for i = 0, 9 do
				stud(Vector3.new(sx * 11.6, 1.5 + i * 1.45, zs), 0.26)
			end
			for i = 0, 8 do
				local y = 1.6 + i * 1.6
				stud(Vector3.new(sx * 0.475, y, zs), 0.22)
			end
		end
		for i = -7, 7 do
			if i ~= 0 then
				for _, y in ipairs({ 0.4, 15.6 }) do
					stud(Vector3.new(i * 1.5, y, zs), 0.26)
				end
			end
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(gold, piece("Part", Vector3.new(0.1, 0.5, 0.5), CFrame.new(sx * 1.1, 8.62, -1.55) * CFrame.Angles(0, rad(90), 0), scaled(C.Gold, 0.9), { shape = Enum.PartType.Cylinder }))
		table.insert(gold, piece("Part", Vector3.new(0.16, 0.16, 0.16), CFrame.new(sx * 1.1, 8.62, -1.63), C.Gold, { shape = Enum.PartType.Ball }))
		ring(gold, Vector3.new(sx * 1.1, 8.12, -1.66), Vector3.xAxis, UP, 0.42, 0.12, 12, C.Gold)
	end
	local frame = merge(m, "DoorFrame", wood, {})
	frame.Parent = barrier
	local studs = merge(m, "DoorGold", gold, {})
	studs.Parent = barrier

	-- today's PriceSign and SunDisc, and the 10 figure parts, exactly
	exact(m, PYLON_KEPT[1], { collide = true, query = true, touch = true })
	exact(m, PYLON_KEPT[2], { collide = true, query = true, touch = true })
	for _, row in ipairs(PYLON_FIGURES) do
		exact(m, row, { collide = true, query = true, touch = true })
	end

	m.PrimaryPart = barrier
	barrier.PivotOffset = barrier.CFrame:Inverse()
	m:SetAttribute("MapPropId", "pylon_temple_gate")
	H.setBevelSelf(false)
	return m
end

---------------------------------------------------------------------
-- 03 CANYON BARRICADE (kit Gates.Gate_Desert_3, 49 parts; Zones.Desert.Desert_3.Gate, attr SubZoneId).
---------------------------------------------------------------------
Gates.CANYON_FACETS = { -- { boxes = { {cx, cy, cz, X axis, Y axis, sx, sy, t, colour} }, tris = { {a, b, c, t, colour} } }
	pillar_L = { boxes = {
		{ -19.520, 1.500, -8.150, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 12.143, 3.000, 0.600, "#9D422C" },
		{ -13.436, 1.500, -8.014, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.634, 3.000, 0.600, "#A2442D" },
		{ -13.300, 1.500, 0.032, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 16.069, 3.000, 0.600, "#98402A" },
		{ -13.404, 1.500, 8.046, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.542, 3.000, 0.600, "#98402A" },
		{ -18.811, 1.500, 8.150, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 10.856, 3.000, 0.600, "#9D422C" },
		{ -25.857, 1.500, 6.407, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 5.177, 3.000, 0.600, "#98402A" },
		{ -27.600, 1.500, -0.676, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 10.930, 3.000, 0.600, "#98402A" },
		{ -26.533, 1.500, -7.083, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 3.265, 3.000, 0.600, "#9D422C" },
		{ -19.354, 4.600, -7.800, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 11.367, 3.200, 0.600, "#AE4A32" },
		{ -13.672, 4.600, -7.678, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.594, 3.200, 0.600, "#A94830" },
		{ -13.550, 4.600, -0.004, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 15.351, 3.200, 0.600, "#AE4A32" },
		{ -13.677, 4.600, 7.673, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.607, 3.200, 0.600, "#AE4A32" },
		{ -19.102, 4.600, 7.800, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 10.847, 3.200, 0.600, "#A4462F" },
		{ -25.826, 4.600, 6.376, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 4.277, 3.200, 0.600, "#A4462F" },
		{ -27.250, 4.600, -0.256, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 10.663, 3.200, 0.600, "#A4462F" },
		{ -26.081, 4.600, -6.631, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 3.554, 3.200, 0.600, "#A94830" },
		{ -19.285, 7.600, -8.050, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 11.595, 2.800, 0.600, "#A5462F" },
		{ -13.506, 7.600, -7.944, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.547, 2.800, 0.600, "#AF4B32" },
		{ -13.400, 7.600, 0.093, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 16.112, 2.800, 0.600, "#A5462F" },
		{ -13.413, 7.600, 8.037, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.284, 2.800, 0.600, "#A5462F" },
		{ -18.672, 7.600, 8.050, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 10.741, 2.800, 0.600, "#AA4930" },
		{ -25.709, 7.600, 6.259, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 5.315, 2.800, 0.600, "#AA4930" },
		{ -27.500, 7.600, -0.520, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 10.224, 2.800, 0.600, "#AF4B32" },
		{ -26.229, 7.600, -6.779, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 3.844, 2.800, 0.600, "#AA4930" },
		{ -18.640, 11.000, -7.000, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 10.044, 4.000, 0.600, "#C46E45" },
		{ -13.646, 11.000, -6.904, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.520, 4.000, 0.600, "#CB7247" },
		{ -13.550, 11.000, 0.041, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 13.946, 4.000, 0.600, "#D17549" },
		{ -13.605, 11.000, 6.945, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.404, 4.000, 0.600, "#C46E45" },
		{ -18.616, 11.000, 7.000, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 10.159, 4.000, 0.600, "#C46E45" },
		{ -24.735, 11.000, 5.835, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 3.543, 4.000, 0.600, "#C46E45" },
		{ -25.900, 11.000, 0.017, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 9.557, 4.000, 0.600, "#C46E45" },
		{ -24.719, 11.000, -5.819, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 3.589, 4.000, 0.600, "#CB7247" },
		{ -18.273, 14.750, -7.050, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 10.093, 3.500, 0.600, "#B44D33" },
		{ -13.325, 14.750, -7.025, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.320, 3.500, 0.600, "#A94830" },
		{ -13.300, 14.750, -0.008, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 14.232, 3.500, 0.600, "#A94830" },
		{ -13.333, 14.750, 7.017, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.342, 3.500, 0.600, "#B44D33" },
		{ -18.045, 14.750, 7.050, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.606, 3.500, 0.600, "#B44D33" },
		{ -24.062, 14.750, 5.712, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 4.033, 3.500, 0.600, "#A94830" },
		{ -25.400, 14.750, -0.236, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 9.467, 3.500, 0.600, "#AF4A32" },
		{ -24.297, 14.750, -5.947, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 3.367, 3.500, 0.600, "#A94830" },
		{ -18.442, 18.000, -6.650, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.678, 3.000, 0.600, "#A0432C" },
		{ -13.639, 18.000, -6.561, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.499, 3.000, 0.600, "#A5452E" },
		{ -13.550, 18.000, 0.069, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 13.332, 3.000, 0.600, "#AB472F" },
		{ -13.570, 18.000, 6.630, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.304, 3.000, 0.600, "#A5452E" },
		{ -18.386, 18.000, 6.650, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.843, 3.000, 0.600, "#AB472F" },
		{ -24.092, 18.000, 5.742, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 2.817, 3.000, 0.600, "#A5452E" },
		{ -25.000, 18.000, 0.014, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 9.889, 3.000, 0.600, "#AB472F" },
		{ -24.078, 18.000, -5.728, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 2.855, 3.000, 0.600, "#A5452E" },
		{ -17.907, 20.750, -6.950, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.110, 2.500, 0.600, "#B94F35" },
		{ -13.438, 20.750, -6.912, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.356, 2.500, 0.600, "#B34D33" },
		{ -13.400, 20.750, -0.038, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 13.921, 2.500, 0.600, "#AE4A31" },
		{ -13.476, 20.750, 6.874, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.462, 2.500, 0.600, "#AE4A31" },
		{ -18.614, 20.750, 6.950, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 10.374, 2.500, 0.600, "#B94F35" },
		{ -24.488, 20.750, 6.138, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 2.544, 2.500, 0.600, "#AE4A31" },
		{ -25.300, 20.750, 0.669, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 9.563, 2.500, 0.600, "#B94F35" },
		{ -23.819, 20.750, -5.469, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 4.438, 2.500, 0.600, "#AE4A31" },
		{ -18.165, 24.000, -6.000, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 8.962, 4.000, 0.600, "#8C392D" },
		{ -13.679, 24.000, -5.871, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.614, 4.000, 0.600, "#903B2E" },
		{ -13.550, 24.000, 0.083, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 11.897, 4.000, 0.600, "#953D30" },
		{ -13.597, 24.000, 5.953, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.380, 4.000, 0.600, "#8C392D" },
		{ -17.962, 24.000, 6.000, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 8.886, 4.000, 0.600, "#8C392D" },
		{ -23.040, 24.000, 5.240, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 2.397, 4.000, 0.600, "#953D30" },
		{ -23.800, 24.000, -0.120, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 9.451, 4.000, 0.600, "#953D30" },
		{ -23.161, 24.000, -5.361, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 2.056, 4.000, 0.600, "#903B2E" },
		{ -17.585, 27.500, -5.950, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 8.393, 3.000, 0.600, "#BB4F35" },
		{ -13.407, 27.500, -5.843, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.550, 3.000, 0.600, "#B54D34" },
		{ -13.300, 27.500, -0.022, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 11.679, 3.000, 0.600, "#AF4B32" },
		{ -13.428, 27.500, 5.822, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.611, 3.000, 0.600, "#B54D34" },
		{ -17.672, 27.500, 5.950, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 8.479, 3.000, 0.600, "#AF4B32" },
		{ -22.493, 27.500, 5.243, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 2.247, 3.000, 0.600, "#AF4B32" },
		{ -23.200, 27.500, 0.064, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 9.193, 3.000, 0.600, "#B54D34" },
		{ -22.429, 27.500, -5.179, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 2.430, 3.000, 0.600, "#AF4B32" },
		{ -17.222, 30.400, -5.600, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 7.094, 2.800, 0.600, "#A7462F" },
		{ -13.675, 30.400, -5.475, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.601, 2.800, 0.600, "#A7462F" },
		{ -13.550, 30.400, 0.064, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 11.078, 2.800, 0.600, "#A2442E" },
		{ -13.611, 30.400, 5.539, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.420, 2.800, 0.600, "#AC4831" },
		{ -17.246, 30.400, 5.600, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 7.398, 2.800, 0.600, "#A7462F" },
		{ -21.835, 30.400, 4.585, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 3.118, 2.800, 0.600, "#AC4831" },
		{ -22.850, 30.400, 0.088, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 7.214, 2.800, 0.600, "#A7462F" },
		{ -21.747, 30.400, -4.497, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 3.367, 2.800, 0.600, "#A2442E" },
		{ -17.293, 32.900, -5.850, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 7.501, 2.200, 0.600, "#B94E35" },
		{ -13.533, 32.900, -5.717, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.625, 2.200, 0.600, "#BE5136" },
		{ -13.400, 32.900, 0.038, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 11.491, 2.200, 0.600, "#B34C33" },
		{ -13.496, 32.900, 5.754, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.519, 2.200, 0.600, "#BE5136" },
		{ -17.477, 32.900, 5.850, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 8.019, 2.200, 0.600, "#B94E35" },
		{ -22.231, 32.900, 4.981, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 2.707, 2.200, 0.600, "#BE5136" },
		{ -23.100, 32.900, 0.221, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 8.029, 2.200, 0.600, "#BE5136" },
		{ -22.009, 32.900, -4.759, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 3.333, 2.200, 0.600, "#B34C33" },
		{ -16.937, 36.000, -4.900, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 6.764, 4.000, 0.600, "#D8784C" },
		{ -13.615, 36.000, -4.835, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.431, 4.000, 0.600, "#E58050" },
		{ -13.550, 36.000, 0.052, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 9.894, 4.000, 0.600, "#E58050" },
		{ -13.563, 36.000, 4.887, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 0.284, 4.000, 0.600, "#E58050" },
		{ -16.584, 36.000, 4.900, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 6.265, 4.000, 0.600, "#D8784C" },
		{ -20.596, 36.000, 3.896, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 3.089, 4.000, 0.600, "#D8784C" },
		{ -21.600, 36.000, -0.302, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 6.635, 4.000, 0.600, "#D8784C" },
		{ -20.897, 36.000, -4.197, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 2.236, 4.000, 0.600, "#DF7C4E" },
	}, tris = {
		{ -13.000, 2.700, 8.067, -13.000, 2.700, -8.002, -13.448, 2.700, -8.450, 0.60, "#AC4830" },
		{ -13.000, 2.700, 8.067, -13.448, 2.700, -8.450, -25.591, 2.700, -8.450, 0.60, "#AC4830" },
		{ -24.239, 2.700, 8.450, -13.383, 2.700, 8.450, -13.000, 2.700, 8.067, 0.60, "#AC4830" },
		{ -24.239, 2.700, 8.450, -13.000, 2.700, 8.067, -25.591, 2.700, -8.450, 0.60, "#AC4830" },
		{ -27.900, 2.700, -6.141, -27.900, 2.700, 4.789, -24.239, 2.700, 8.450, 0.60, "#AC4830" },
		{ -27.900, 2.700, -6.141, -24.239, 2.700, 8.450, -25.591, 2.700, -8.450, 0.60, "#AC4830" },
		{ -13.250, 5.900, 7.671, -13.250, 5.900, -7.680, -13.670, 5.900, -8.100, 0.60, "#B94F34" },
		{ -13.250, 5.900, 7.671, -13.670, 5.900, -8.100, -25.037, 5.900, -8.100, 0.60, "#B94F34" },
		{ -24.526, 5.900, 8.100, -13.679, 5.900, 8.100, -13.250, 5.900, 7.671, 0.60, "#B94F34" },
		{ -24.526, 5.900, 8.100, -13.250, 5.900, 7.671, -25.037, 5.900, -8.100, 0.60, "#B94F34" },
		{ -27.550, 5.900, -5.587, -27.550, 5.900, 5.076, -24.526, 5.900, 8.100, 0.60, "#B94F34" },
		{ -27.550, 5.900, -5.587, -24.526, 5.900, 8.100, -25.037, 5.900, -8.100, 0.60, "#B94F34" },
		{ -13.100, 8.700, 8.149, -13.100, 8.700, -7.963, -13.487, 8.700, -8.350, 0.60, "#BA4F35" },
		{ -13.100, 8.700, 8.149, -13.487, 8.700, -8.350, -25.082, 8.700, -8.350, 0.60, "#BA4F35" },
		{ -24.042, 8.700, 8.350, -13.301, 8.700, 8.350, -13.100, 8.700, 8.149, 0.60, "#BA4F35" },
		{ -24.042, 8.700, 8.350, -13.100, 8.700, 8.149, -25.082, 8.700, -8.350, 0.60, "#BA4F35" },
		{ -27.800, 8.700, -5.632, -27.800, 8.700, 4.592, -24.042, 8.700, 8.350, 0.60, "#BA4F35" },
		{ -27.800, 8.700, -5.632, -24.042, 8.700, 8.350, -25.082, 8.700, -8.350, 0.60, "#BA4F35" },
		{ -25.082, 6.500, -8.350, -13.487, 6.500, -8.350, -13.100, 6.500, -7.963, 0.60, "#943F2A" },
		{ -25.082, 6.500, -8.350, -13.100, 6.500, -7.963, -13.100, 6.500, 8.149, 0.60, "#943F2A" },
		{ -25.082, 6.500, -8.350, -13.100, 6.500, 8.149, -13.301, 6.500, 8.350, 0.60, "#943F2A" },
		{ -25.082, 6.500, -8.350, -13.301, 6.500, 8.350, -24.042, 6.500, 8.350, 0.60, "#943F2A" },
		{ -25.082, 6.500, -8.350, -24.042, 6.500, 8.350, -27.800, 6.500, 4.592, 0.60, "#943F2A" },
		{ -25.082, 6.500, -8.350, -27.800, 6.500, 4.592, -27.800, 6.500, -5.632, 0.60, "#943F2A" },
		{ -13.250, 12.700, 7.014, -13.250, 12.700, -6.932, -13.618, 12.700, -7.300, 0.60, "#DD7C4D" },
		{ -13.250, 12.700, 7.014, -13.618, 12.700, -7.300, -23.662, 12.700, -7.300, 0.60, "#DD7C4D" },
		{ -23.695, 12.700, 7.300, -13.536, 12.700, 7.300, -13.250, 12.700, 7.014, 0.60, "#DD7C4D" },
		{ -23.695, 12.700, 7.300, -13.250, 12.700, 7.014, -23.662, 12.700, -7.300, 0.60, "#DD7C4D" },
		{ -26.200, 12.700, -4.762, -26.200, 12.700, 4.795, -23.695, 12.700, 7.300, 0.60, "#DD7C4D" },
		{ -26.200, 12.700, -4.762, -23.695, 12.700, 7.300, -23.662, 12.700, -7.300, 0.60, "#DD7C4D" },
		{ -13.000, 16.200, 7.108, -13.000, 16.200, -7.124, -13.226, 16.200, -7.350, 0.60, "#BF5136" },
		{ -13.000, 16.200, 7.108, -13.226, 16.200, -7.350, -23.319, 16.200, -7.350, 0.60, "#BF5136" },
		{ -22.848, 16.200, 7.350, -13.242, 16.200, 7.350, -13.000, 16.200, 7.108, 0.60, "#BF5136" },
		{ -22.848, 16.200, 7.350, -13.000, 16.200, 7.108, -23.319, 16.200, -7.350, 0.60, "#BF5136" },
		{ -25.700, 16.200, -4.969, -25.700, 16.200, 4.498, -22.848, 16.200, 7.350, 0.60, "#BF5136" },
		{ -25.700, 16.200, -4.969, -22.848, 16.200, 7.350, -23.319, 16.200, -7.350, 0.60, "#BF5136" },
		{ -23.319, 13.300, -7.350, -13.226, 13.300, -7.350, -13.000, 13.300, -7.124, 0.60, "#943F2A" },
		{ -23.319, 13.300, -7.350, -13.000, 13.300, -7.124, -13.000, 13.300, 7.108, 0.60, "#943F2A" },
		{ -23.319, 13.300, -7.350, -13.000, 13.300, 7.108, -13.242, 13.300, 7.350, 0.60, "#943F2A" },
		{ -23.319, 13.300, -7.350, -13.242, 13.300, 7.350, -22.848, 13.300, 7.350, 0.60, "#943F2A" },
		{ -23.319, 13.300, -7.350, -22.848, 13.300, 7.350, -25.700, 13.300, 4.498, 0.60, "#943F2A" },
		{ -23.319, 13.300, -7.350, -25.700, 13.300, 4.498, -25.700, 13.300, -4.969, 0.60, "#943F2A" },
		{ -13.250, 19.200, 6.735, -13.250, 19.200, -6.597, -13.603, 19.200, -6.950, 0.60, "#B54C32" },
		{ -13.250, 19.200, 6.735, -13.603, 19.200, -6.950, -23.281, 19.200, -6.950, 0.60, "#B54C32" },
		{ -23.308, 19.200, 6.950, -13.465, 19.200, 6.950, -13.250, 19.200, 6.735, 0.60, "#B54C32" },
		{ -23.308, 19.200, 6.950, -13.250, 19.200, 6.735, -23.281, 19.200, -6.950, 0.60, "#B54C32" },
		{ -25.300, 19.200, -4.931, -25.300, 19.200, 4.958, -23.308, 19.200, 6.950, 0.60, "#B54C32" },
		{ -25.300, 19.200, -4.931, -23.308, 19.200, 6.950, -23.281, 19.200, -6.950, 0.60, "#B54C32" },
		{ -13.100, 21.700, 6.923, -13.100, 21.700, -6.998, -13.352, 21.700, -7.250, 0.60, "#C45438" },
		{ -13.100, 21.700, 6.923, -13.352, 21.700, -7.250, -22.462, 21.700, -7.250, 0.60, "#C45438" },
		{ -23.801, 21.700, 7.250, -13.427, 21.700, 7.250, -13.100, 21.700, 6.923, 0.60, "#C45438" },
		{ -23.801, 21.700, 7.250, -13.100, 21.700, 6.923, -22.462, 21.700, -7.250, 0.60, "#C45438" },
		{ -25.600, 21.700, -4.112, -25.600, 21.700, 5.451, -23.801, 21.700, 7.250, 0.60, "#C45438" },
		{ -25.600, 21.700, -4.112, -23.801, 21.700, 7.250, -22.462, 21.700, -7.250, 0.60, "#C45438" },
		{ -22.462, 19.800, -7.250, -13.352, 19.800, -7.250, -13.100, 19.800, -6.998, 0.60, "#943F2A" },
		{ -22.462, 19.800, -7.250, -13.100, 19.800, -6.998, -13.100, 19.800, 6.923, 0.60, "#943F2A" },
		{ -22.462, 19.800, -7.250, -13.100, 19.800, 6.923, -13.427, 19.800, 7.250, 0.60, "#943F2A" },
		{ -22.462, 19.800, -7.250, -13.427, 19.800, 7.250, -23.801, 19.800, 7.250, 0.60, "#943F2A" },
		{ -22.462, 19.800, -7.250, -23.801, 19.800, 7.250, -25.600, 19.800, 5.451, 0.60, "#943F2A" },
		{ -22.462, 19.800, -7.250, -25.600, 19.800, 5.451, -25.600, 19.800, -4.112, 0.60, "#943F2A" },
		{ -13.250, 25.700, 6.031, -13.250, 25.700, -5.866, -13.684, 25.700, -6.300, 0.60, "#9E4132" },
		{ -13.250, 25.700, 6.031, -13.684, 25.700, -6.300, -22.646, 25.700, -6.300, 0.60, "#9E4132" },
		{ -22.405, 25.700, 6.300, -13.519, 25.700, 6.300, -13.250, 25.700, 6.031, 0.60, "#9E4132" },
		{ -22.405, 25.700, 6.300, -13.250, 25.700, 6.031, -22.646, 25.700, -6.300, 0.60, "#9E4132" },
		{ -24.100, 25.700, -4.846, -24.100, 25.700, 4.605, -22.405, 25.700, 6.300, 0.60, "#9E4132" },
		{ -24.100, 25.700, -4.846, -22.405, 25.700, 6.300, -22.646, 25.700, -6.300, 0.60, "#9E4132" },
		{ -13.000, 28.700, 5.818, -13.000, 28.700, -5.861, -13.389, 28.700, -6.250, 0.60, "#C65438" },
		{ -13.000, 28.700, 5.818, -13.389, 28.700, -6.250, -21.782, 28.700, -6.250, 0.60, "#C65438" },
		{ -21.911, 28.700, 6.250, -13.432, 28.700, 6.250, -13.000, 28.700, 5.818, 0.60, "#C65438" },
		{ -21.911, 28.700, 6.250, -13.000, 28.700, 5.818, -21.782, 28.700, -6.250, 0.60, "#C65438" },
		{ -23.500, 28.700, -4.532, -23.500, 28.700, 4.661, -21.911, 28.700, 6.250, 0.60, "#C65438" },
		{ -23.500, 28.700, -4.532, -21.911, 28.700, 6.250, -21.782, 28.700, -6.250, 0.60, "#C65438" },
		{ -21.782, 26.300, -6.250, -13.389, 26.300, -6.250, -13.000, 26.300, -5.861, 0.60, "#913E29" },
		{ -21.782, 26.300, -6.250, -13.000, 26.300, -5.861, -13.000, 26.300, 5.818, 0.60, "#913E29" },
		{ -21.782, 26.300, -6.250, -13.000, 26.300, 5.818, -13.432, 26.300, 6.250, 0.60, "#913E29" },
		{ -21.782, 26.300, -6.250, -13.432, 26.300, 6.250, -21.911, 26.300, 6.250, 0.60, "#913E29" },
		{ -21.782, 26.300, -6.250, -21.911, 26.300, 6.250, -23.500, 26.300, 4.661, 0.60, "#913E29" },
		{ -21.782, 26.300, -6.250, -23.500, 26.300, 4.661, -23.500, 26.300, -4.532, 0.60, "#913E29" },
		{ -13.250, 31.500, 5.603, -13.250, 31.500, -5.475, -13.675, 31.500, -5.900, 0.60, "#B64D34" },
		{ -13.250, 31.500, 5.603, -13.675, 31.500, -5.900, -20.769, 31.500, -5.900, 0.60, "#B64D34" },
		{ -20.945, 31.500, 5.900, -13.547, 31.500, 5.900, -13.250, 31.500, 5.603, 0.60, "#B64D34" },
		{ -20.945, 31.500, 5.900, -13.250, 31.500, 5.603, -20.769, 31.500, -5.900, 0.60, "#B64D34" },
		{ -23.150, 31.500, -3.519, -23.150, 31.500, 3.695, -20.945, 31.500, 5.900, 0.60, "#B64D34" },
		{ -23.150, 31.500, -3.519, -20.945, 31.500, 5.900, -20.769, 31.500, -5.900, 0.60, "#B64D34" },
		{ -13.100, 33.700, 5.783, -13.100, 33.700, -5.708, -13.542, 33.700, -6.150, 0.60, "#CA5639" },
		{ -13.100, 33.700, 5.783, -13.542, 33.700, -6.150, -21.043, 33.700, -6.150, 0.60, "#CA5639" },
		{ -21.486, 33.700, 6.150, -13.467, 33.700, 6.150, -13.100, 33.700, 5.783, 0.60, "#CA5639" },
		{ -21.486, 33.700, 6.150, -13.100, 33.700, 5.783, -21.043, 33.700, -6.150, 0.60, "#CA5639" },
		{ -23.400, 33.700, -3.793, -23.400, 33.700, 4.236, -21.486, 33.700, 6.150, 0.60, "#CA5639" },
		{ -23.400, 33.700, -3.793, -21.486, 33.700, 6.150, -21.043, 33.700, -6.150, 0.60, "#CA5639" },
		{ -21.043, 32.100, -6.150, -13.542, 32.100, -6.150, -13.100, 32.100, -5.708, 0.60, "#913E29" },
		{ -21.043, 32.100, -6.150, -13.100, 32.100, -5.708, -13.100, 32.100, 5.783, 0.60, "#913E29" },
		{ -21.043, 32.100, -6.150, -13.100, 32.100, 5.783, -13.467, 32.100, 6.150, 0.60, "#913E29" },
		{ -21.043, 32.100, -6.150, -13.467, 32.100, 6.150, -21.486, 32.100, 6.150, 0.60, "#913E29" },
		{ -21.043, 32.100, -6.150, -21.486, 32.100, 6.150, -23.400, 32.100, 4.236, 0.60, "#913E29" },
		{ -21.043, 32.100, -6.150, -23.400, 32.100, 4.236, -23.400, 32.100, -3.793, 0.60, "#913E29" },
		{ -13.250, 37.700, 4.999, -13.250, 37.700, -4.895, -13.555, 37.700, -5.200, 0.60, "#F38855" },
		{ -13.250, 37.700, 4.999, -13.555, 37.700, -5.200, -20.319, 37.700, -5.200, 0.60, "#F38855" },
		{ -19.716, 37.700, 5.200, -13.451, 37.700, 5.200, -13.250, 37.700, 4.999, 0.60, "#F38855" },
		{ -19.716, 37.700, 5.200, -13.250, 37.700, 4.999, -20.319, 37.700, -5.200, 0.60, "#F38855" },
		{ -21.900, 37.700, -3.619, -21.900, 37.700, 3.016, -19.716, 37.700, 5.200, 0.60, "#F38855" },
		{ -21.900, 37.700, -3.619, -19.716, 37.700, 5.200, -20.319, 37.700, -5.200, 0.60, "#F38855" },
		{ -25.705, 16.450, 1.267, -25.705, 16.450, 0.987, -25.705, 15.035, 0.811, 0.05, "#622A1C" },
		{ -25.705, 16.450, 1.267, -25.705, 15.035, 0.811, -25.705, 15.035, 1.091, 0.05, "#622A1C" },
		{ -25.705, 15.035, 1.091, -25.705, 15.035, 0.811, -25.705, 13.400, 1.026, 0.05, "#622A1C" },
		{ -25.705, 15.035, 1.091, -25.705, 13.400, 1.026, -25.705, 13.400, 1.306, 0.05, "#622A1C" },
		{ -26.213, 2.950, 6.482, -26.411, 2.950, 6.284, -26.636, 1.586, 6.059, 0.05, "#5C261A" },
		{ -26.213, 2.950, 6.482, -26.636, 1.586, 6.059, -26.438, 1.586, 6.257, 0.05, "#5C261A" },
		{ -26.438, 1.586, 6.257, -26.636, 1.586, 6.059, -26.250, 0.400, 6.445, 0.05, "#5C261A" },
		{ -26.438, 1.586, 6.257, -26.250, 0.400, 6.445, -26.052, 0.400, 6.643, 0.05, "#5C261A" },
		{ -17.336, 37.950, 5.204, -17.616, 37.950, 5.204, -17.060, 35.738, 5.204, 0.05, "#744028" },
		{ -17.336, 37.950, 5.204, -17.060, 35.738, 5.204, -16.780, 35.738, 5.204, 0.05, "#744028" },
		{ -16.780, 35.738, 5.204, -17.060, 35.738, 5.204, -17.747, 34.400, 5.204, 0.05, "#744028" },
		{ -16.780, 35.738, 5.204, -17.747, 34.400, 5.204, -17.467, 34.400, 5.204, 0.05, "#744028" },
		{ -17.660, 33.950, 6.155, -17.940, 33.950, 6.155, -18.220, 32.886, 6.155, 0.05, "#60291C" },
		{ -17.660, 33.950, 6.155, -18.220, 32.886, 6.155, -17.940, 32.886, 6.155, 0.05, "#60291C" },
		{ -17.940, 32.886, 6.155, -18.220, 32.886, 6.155, -17.551, 32.200, 6.155, 0.05, "#60291C" },
		{ -17.940, 32.886, 6.155, -17.551, 32.200, 6.155, -17.271, 32.200, 6.155, 0.05, "#60291C" },
		{ -26.236, 8.950, -7.202, -26.038, 8.950, -7.400, -25.944, 7.677, -7.494, 0.05, "#622A1C" },
		{ -26.236, 8.950, -7.202, -25.944, 7.677, -7.494, -26.142, 7.677, -7.297, 0.05, "#622A1C" },
		{ -26.142, 7.677, -7.297, -25.944, 7.677, -7.494, -26.261, 6.600, -7.177, 0.05, "#622A1C" },
		{ -26.142, 7.677, -7.297, -26.261, 6.600, -7.177, -26.459, 6.600, -6.979, 0.05, "#622A1C" },
		{ -21.213, 41.614, -2.700, -17.199, 42.096, -2.700, -17.199, 38.000, -2.700, 0.60, "#D2764A" },
		{ -21.213, 41.614, -2.700, -17.199, 38.000, -2.700, -21.213, 38.000, -2.700, 0.60, "#D2764A" },
		{ -17.411, 42.096, -2.788, -16.212, 42.144, -1.589, -16.212, 38.000, -1.589, 0.60, "#DB7B4D" },
		{ -17.411, 42.096, -2.788, -16.212, 38.000, -1.589, -17.411, 38.000, -2.788, 0.60, "#DB7B4D" },
		{ -16.300, 42.144, -1.801, -16.300, 41.777, 2.787, -16.300, 38.000, 2.787, 0.60, "#D2764A" },
		{ -16.300, 42.144, -1.801, -16.300, 38.000, 2.787, -16.300, 38.000, -1.801, 0.60, "#D2764A" },
		{ -16.212, 41.777, 2.575, -17.425, 41.534, 3.788, -17.425, 38.000, 3.788, 0.60, "#E48050" },
		{ -16.212, 41.777, 2.575, -17.425, 38.000, 3.788, -16.212, 38.000, 2.575, 0.60, "#E48050" },
		{ -17.213, 41.534, 3.700, -21.257, 41.049, 3.700, -21.257, 38.000, 3.700, 0.60, "#D2764A" },
		{ -17.213, 41.534, 3.700, -21.257, 38.000, 3.700, -17.213, 38.000, 3.700, 0.60, "#D2764A" },
		{ -21.045, 41.049, 3.788, -21.788, 41.019, 3.045, -21.788, 38.000, 3.045, 0.60, "#DB7B4D" },
		{ -21.045, 41.049, 3.788, -21.788, 38.000, 3.045, -21.045, 38.000, 3.788, 0.60, "#DB7B4D" },
		{ -21.700, 41.019, 3.257, -21.700, 41.457, -2.213, -21.700, 38.000, -2.213, 0.60, "#DB7B4D" },
		{ -21.700, 41.019, 3.257, -21.700, 38.000, -2.213, -21.700, 38.000, 3.257, 0.60, "#DB7B4D" },
		{ -21.788, 41.457, -2.001, -21.001, 41.614, -2.788, -21.001, 38.000, -2.788, 0.60, "#DB7B4D" },
		{ -21.788, 41.457, -2.001, -21.001, 38.000, -2.788, -21.788, 38.000, -2.001, 0.60, "#DB7B4D" },
		{ -15.964, 41.480, 2.763, -15.964, 41.847, -1.825, -17.163, 41.799, -3.024, 0.60, "#F28855" },
		{ -15.964, 41.480, 2.763, -17.163, 41.799, -3.024, -21.177, 41.317, -3.024, 0.60, "#F28855" },
		{ -21.221, 40.752, 3.976, -17.177, 41.237, 3.976, -15.964, 41.480, 2.763, 0.60, "#F28855" },
		{ -21.221, 40.752, 3.976, -15.964, 41.480, 2.763, -21.177, 41.317, -3.024, 0.60, "#F28855" },
		{ -21.964, 41.160, -2.237, -21.964, 40.722, 3.233, -21.221, 40.752, 3.976, 0.60, "#F28855" },
		{ -21.965, 41.160, -2.237, -21.222, 40.752, 3.976, -21.178, 41.317, -3.024, 0.60, "#F28855" },
	} },
	pillar_R = { boxes = {
		{ 19.318, 1.500, -8.150, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 11.834, 3.000, 0.600, "#A4462F" },
		{ 26.355, 1.500, -6.905, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 3.769, 3.000, 0.600, "#9F432D" },
		{ 27.600, 1.500, -0.141, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 11.289, 3.000, 0.600, "#A4462F" },
		{ 26.215, 1.500, 6.765, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 4.166, 3.000, 0.600, "#9F432D" },
		{ 19.172, 1.500, 8.150, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 11.565, 3.000, 0.600, "#A4462F" },
		{ 13.407, 1.500, 8.043, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 0.550, 3.000, 0.600, "#9A412C" },
		{ 13.300, 1.500, 0.006, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 16.110, 3.000, 0.600, "#9F432D" },
		{ 13.413, 1.500, -8.037, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 0.567, 3.000, 0.600, "#9A412C" },
		{ 18.691, 4.500, -7.850, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 10.437, 3.000, 0.600, "#A7472F" },
		{ 25.542, 4.500, -6.092, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 5.220, 3.000, 0.600, "#AC4A31" },
		{ 27.300, 4.500, 0.560, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 10.037, 3.000, 0.600, "#B24C32" },
		{ 26.102, 4.500, 6.652, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 3.637, 3.000, 0.600, "#A7472F" },
		{ 19.287, 4.500, 7.850, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 11.483, 3.000, 0.600, "#B24C32" },
		{ 13.610, 4.500, 7.790, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 0.417, 3.000, 0.600, "#A7472F" },
		{ 13.550, 4.500, -0.036, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 15.783, 3.000, 0.600, "#A7472F" },
		{ 13.573, 4.500, -7.827, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 0.314, 3.000, 0.600, "#A7472F" },
		{ 19.431, 7.500, -8.100, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 12.224, 3.000, 0.600, "#A84830" },
		{ 26.484, 7.500, -7.034, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 3.263, 3.000, 0.600, "#B34D33" },
		{ 27.550, 7.500, -0.390, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 11.406, 3.000, 0.600, "#A84830" },
		{ 26.094, 7.500, 6.644, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 4.366, 3.000, 0.600, "#B34D33" },
		{ 19.124, 7.500, 8.100, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 11.278, 3.000, 0.600, "#A84830" },
		{ 13.480, 7.500, 7.970, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 0.615, 3.000, 0.600, "#A84830" },
		{ 13.350, 7.500, -0.083, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 16.096, 3.000, 0.600, "#AE4A31" },
		{ 13.397, 7.500, -8.053, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 0.380, 3.000, 0.600, "#B34D33" },
		{ 19.096, 11.000, -7.000, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 10.893, 4.000, 0.600, "#CD7348" },
		{ 25.159, 11.000, -6.259, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.343, 4.000, 0.600, "#C77046" },
		{ 25.900, 11.000, 0.047, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 11.380, 4.000, 0.600, "#C77046" },
		{ 25.206, 11.000, 6.306, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.210, 4.000, 0.600, "#C16C44" },
		{ 19.114, 11.000, 7.000, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 11.046, 4.000, 0.600, "#C16C44" },
		{ 13.633, 11.000, 6.917, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 0.482, 4.000, 0.600, "#C16C44" },
		{ 13.550, 11.000, 0.029, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 13.859, 4.000, 0.600, "#C16C44" },
		{ 13.662, 11.000, -6.888, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 0.566, 4.000, 0.600, "#CD7348" },
		{ 17.971, 14.400, -7.050, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.245, 2.800, 0.600, "#AA4930" },
		{ 23.934, 14.400, -5.584, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 4.394, 2.800, 0.600, "#AA4930" },
		{ 25.400, 14.400, 0.730, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 9.947, 2.800, 0.600, "#AA4930" },
		{ 24.665, 14.400, 6.315, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.328, 2.800, 0.600, "#A5462E" },
		{ 18.697, 14.400, 7.050, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 10.714, 2.800, 0.600, "#AF4B31" },
		{ 13.382, 14.400, 6.968, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 0.481, 2.800, 0.600, "#AA4930" },
		{ 13.300, 14.400, 0.004, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 14.012, 2.800, 0.600, "#AF4B31" },
		{ 13.386, 14.400, -6.964, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 0.492, 2.800, 0.600, "#A5462E" },
		{ 18.556, 17.400, -6.600, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.983, 3.200, 0.600, "#9E422D" },
		{ 24.187, 17.400, -5.837, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.407, 3.200, 0.600, "#A3442E" },
		{ 24.950, 17.400, -0.100, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 10.197, 3.200, 0.600, "#9E422D" },
		{ 24.087, 17.400, 5.737, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.688, 3.200, 0.600, "#99402B" },
		{ 18.476, 17.400, 6.600, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.746, 3.200, 0.600, "#A3442E" },
		{ 13.639, 17.400, 6.511, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 0.499, 3.200, 0.600, "#A3442E" },
		{ 13.550, 17.400, -0.019, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 13.132, 3.200, 0.600, "#9E422D" },
		{ 13.620, 17.400, -6.530, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 0.445, 3.200, 0.600, "#A3442E" },
		{ 18.596, 20.500, -6.950, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 10.565, 3.000, 0.600, "#A94830" },
		{ 24.527, 20.500, -6.177, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.434, 3.000, 0.600, "#B44D33" },
		{ 25.300, 20.500, -0.205, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 10.647, 3.000, 0.600, "#AF4B31" },
		{ 24.322, 20.500, 5.972, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 3.015, 3.000, 0.600, "#B44D33" },
		{ 18.387, 20.500, 6.950, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 10.162, 3.000, 0.600, "#B44D33" },
		{ 13.415, 20.500, 6.935, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 0.291, 3.000, 0.600, "#B44D33" },
		{ 13.400, 20.500, 0.004, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 14.080, 3.000, 0.600, "#B44D33" },
		{ 13.419, 20.500, -6.931, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 0.303, 3.000, 0.600, "#AF4B31" },
		{ 17.758, 24.000, -6.000, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 8.583, 4.000, 0.600, "#86382B" },
		{ 22.862, 24.000, -5.062, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.901, 4.000, 0.600, "#8B392C" },
		{ 23.800, 24.000, -0.130, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 8.237, 4.000, 0.600, "#86382B" },
		{ 22.732, 24.000, 4.932, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 3.270, 4.000, 0.600, "#8B392C" },
		{ 17.636, 24.000, 6.000, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 8.304, 4.000, 0.600, "#86382B" },
		{ 13.579, 24.000, 5.971, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 0.331, 4.000, 0.600, "#8B392C" },
		{ 13.550, 24.000, -0.009, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 12.150, 4.000, 0.600, "#8F3B2E" },
		{ 13.570, 24.000, -5.980, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 0.305, 4.000, 0.600, "#8B392C" },
		{ 17.648, 27.300, -5.950, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 8.532, 2.600, 0.600, "#B74E34" },
		{ 22.495, 27.300, -5.245, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.243, 2.600, 0.600, "#B74E34" },
		{ 23.200, 27.300, -0.172, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 8.984, 2.600, 0.600, "#BC5035" },
		{ 22.323, 27.300, 5.073, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.729, 2.600, 0.600, "#B74E34" },
		{ 17.457, 27.300, 5.950, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 8.226, 2.600, 0.600, "#B74E34" },
		{ 13.384, 27.300, 5.866, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 0.486, 2.600, 0.600, "#BC5035" },
		{ 13.300, 27.300, 0.019, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 11.774, 2.600, 0.600, "#B74E34" },
		{ 13.403, 27.300, -5.847, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 0.540, 2.600, 0.600, "#BC5035" },
		{ 17.513, 30.000, -5.650, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 7.844, 2.800, 0.600, "#AE4932" },
		{ 22.105, 30.000, -4.855, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.496, 2.800, 0.600, "#AE4932" },
		{ 22.900, 30.000, 0.001, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 8.371, 2.800, 0.600, "#A3452F" },
		{ 22.106, 30.000, 4.856, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.495, 2.800, 0.600, "#AE4932" },
		{ 17.505, 30.000, 5.650, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 7.862, 2.800, 0.600, "#A3452F" },
		{ 13.624, 30.000, 5.576, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 0.458, 2.800, 0.600, "#A94730" },
		{ 13.550, 30.000, 0.009, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 11.235, 2.800, 0.600, "#AE4932" },
		{ 13.633, 30.000, -5.567, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 0.482, 2.800, 0.600, "#A3452F" },
		{ 17.389, 32.700, -5.850, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 7.953, 2.600, 0.600, "#BA4F35" },
		{ 22.171, 32.700, -4.921, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.877, 2.600, 0.600, "#B54D33" },
		{ 23.100, 32.700, 0.297, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 8.826, 2.600, 0.600, "#B54D33" },
		{ 22.468, 32.700, 5.218, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.036, 2.600, 0.600, "#B54D33" },
		{ 17.700, 32.700, 5.850, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 8.521, 2.600, 0.600, "#C05236" },
		{ 13.482, 32.700, 5.768, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 0.479, 2.600, 0.600, "#BA4F35" },
		{ 13.400, 32.700, -0.013, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 11.648, 2.600, 0.600, "#BA4F35" },
		{ 13.469, 32.700, -5.781, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 0.443, 2.600, 0.600, "#C05236" },
		{ 16.844, 36.000, -4.900, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 6.312, 4.000, 0.600, "#D17549" },
		{ 20.738, 36.000, -4.038, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.687, 4.000, 0.600, "#D17549" },
		{ 21.600, 36.000, -0.056, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 6.488, 4.000, 0.600, "#DF7C4D" },
		{ 20.682, 36.000, 3.982, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.845, 4.000, 0.600, "#DF7C4D" },
		{ 16.733, 36.000, 4.900, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 6.311, 4.000, 0.600, "#D17549" },
		{ 13.626, 36.000, 4.824, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 0.462, 4.000, 0.600, "#D17549" },
		{ 13.550, 36.000, 0.056, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 9.635, 4.000, 0.600, "#D8784B" },
		{ 13.681, 36.000, -4.769, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 0.619, 4.000, 0.600, "#D17549" },
	}, tris = {
		{ 27.900, 2.700, 5.504, 27.900, 2.700, -5.785, 25.235, 2.700, -8.450, 0.60, "#AE4A31" },
		{ 27.900, 2.700, 5.504, 25.235, 2.700, -8.450, 13.401, 2.700, -8.450, 0.60, "#AE4A31" },
		{ 13.389, 2.700, 8.450, 24.954, 2.700, 8.450, 27.900, 2.700, 5.504, 0.60, "#AE4A31" },
		{ 13.389, 2.700, 8.450, 27.900, 2.700, 5.504, 13.401, 2.700, -8.450, 0.60, "#AE4A31" },
		{ 13.000, 2.700, -8.049, 13.000, 2.700, 8.061, 13.389, 2.700, 8.450, 0.60, "#AE4A31" },
		{ 13.000, 2.700, -8.049, 13.389, 2.700, 8.450, 13.401, 2.700, -8.450, 0.60, "#AE4A31" },
		{ 27.600, 5.700, 5.578, 27.600, 5.700, -4.459, 23.909, 5.700, -8.150, 0.60, "#BC5135" },
		{ 27.600, 5.700, 5.578, 23.909, 5.700, -8.150, 13.472, 5.700, -8.150, 0.60, "#BC5135" },
		{ 13.545, 5.700, 8.150, 25.028, 5.700, 8.150, 27.600, 5.700, 5.578, 0.60, "#BC5135" },
		{ 13.545, 5.700, 8.150, 27.600, 5.700, 5.578, 13.472, 5.700, -8.150, 0.60, "#BC5135" },
		{ 13.250, 5.700, -7.928, 13.250, 5.700, 7.855, 13.545, 5.700, 8.150, 0.60, "#BC5135" },
		{ 13.250, 5.700, -7.928, 13.545, 5.700, 8.150, 13.472, 5.700, -8.150, 0.60, "#BC5135" },
		{ 27.850, 8.700, 5.313, 27.850, 8.700, -6.093, 25.543, 8.700, -8.400, 0.60, "#BE5136" },
		{ 27.850, 8.700, 5.313, 25.543, 8.700, -8.400, 13.319, 8.700, -8.400, 0.60, "#BE5136" },
		{ 13.485, 8.700, 8.400, 24.763, 8.700, 8.400, 27.850, 8.700, 5.313, 0.60, "#BE5136" },
		{ 13.485, 8.700, 8.400, 27.850, 8.700, 5.313, 13.319, 8.700, -8.400, 0.60, "#BE5136" },
		{ 13.050, 8.700, -8.131, 13.050, 8.700, 7.965, 13.485, 8.700, 8.400, 0.60, "#BE5136" },
		{ 13.050, 8.700, -8.131, 13.485, 8.700, 8.400, 13.319, 8.700, -8.400, 0.60, "#BE5136" },
		{ 13.319, 6.300, -8.400, 25.543, 6.300, -8.400, 27.850, 6.300, -6.093, 0.60, "#97402B" },
		{ 13.319, 6.300, -8.400, 27.850, 6.300, -6.093, 27.850, 6.300, 5.313, 0.60, "#97402B" },
		{ 13.319, 6.300, -8.400, 27.850, 6.300, 5.313, 24.763, 6.300, 8.400, 0.60, "#97402B" },
		{ 13.319, 6.300, -8.400, 24.763, 6.300, 8.400, 13.485, 6.300, 8.400, 0.60, "#97402B" },
		{ 13.319, 6.300, -8.400, 13.485, 6.300, 8.400, 13.050, 6.300, 7.965, 0.60, "#97402B" },
		{ 13.319, 6.300, -8.400, 13.050, 6.300, 7.965, 13.050, 6.300, -8.131, 0.60, "#97402B" },
		{ 26.200, 12.700, 5.737, 26.200, 12.700, -5.643, 24.543, 12.700, -7.300, 0.60, "#DA7A4C" },
		{ 26.200, 12.700, 5.737, 24.543, 12.700, -7.300, 13.650, 12.700, -7.300, 0.60, "#DA7A4C" },
		{ 13.591, 12.700, 7.300, 24.637, 12.700, 7.300, 26.200, 12.700, 5.737, 0.60, "#DA7A4C" },
		{ 13.591, 12.700, 7.300, 26.200, 12.700, 5.737, 13.650, 12.700, -7.300, 0.60, "#DA7A4C" },
		{ 13.250, 12.700, -6.900, 13.250, 12.700, 6.959, 13.591, 12.700, 7.300, 0.60, "#DA7A4C" },
		{ 13.250, 12.700, -6.900, 13.591, 12.700, 7.300, 13.650, 12.700, -7.300, 0.60, "#DA7A4C" },
		{ 25.700, 15.500, 5.704, 25.700, 15.500, -4.243, 22.593, 15.500, -7.350, 0.60, "#BA4F34" },
		{ 25.700, 15.500, 5.704, 22.593, 15.500, -7.350, 13.348, 15.500, -7.350, 0.60, "#BA4F34" },
		{ 13.340, 15.500, 7.350, 24.054, 15.500, 7.350, 25.700, 15.500, 5.704, 0.60, "#BA4F34" },
		{ 13.340, 15.500, 7.350, 25.700, 15.500, 5.704, 13.348, 15.500, -7.350, 0.60, "#BA4F34" },
		{ 13.000, 15.500, -7.002, 13.000, 15.500, 7.010, 13.340, 15.500, 7.350, 0.60, "#BA4F34" },
		{ 13.000, 15.500, -7.002, 13.340, 15.500, 7.350, 13.348, 15.500, -7.350, 0.60, "#BA4F34" },
		{ 13.348, 13.300, -7.350, 22.593, 13.300, -7.350, 25.700, 13.300, -4.243, 0.60, "#903E28" },
		{ 13.348, 13.300, -7.350, 25.700, 13.300, -4.243, 25.700, 13.300, 5.704, 0.60, "#903E28" },
		{ 13.348, 13.300, -7.350, 25.700, 13.300, 5.704, 24.054, 13.300, 7.350, 0.60, "#903E28" },
		{ 13.348, 13.300, -7.350, 24.054, 13.300, 7.350, 13.340, 13.300, 7.350, 0.60, "#903E28" },
		{ 13.348, 13.300, -7.350, 13.340, 13.300, 7.350, 13.000, 13.300, 7.010, 0.60, "#903E28" },
		{ 13.348, 13.300, -7.350, 13.000, 13.300, 7.010, 13.000, 13.300, -7.002, 0.60, "#903E28" },
		{ 25.250, 18.700, 4.999, 25.250, 18.700, -5.198, 23.548, 18.700, -6.900, 0.60, "#AD4931" },
		{ 25.250, 18.700, 4.999, 23.548, 18.700, -6.900, 13.565, 18.700, -6.900, 0.60, "#AD4931" },
		{ 13.603, 18.700, 6.900, 23.349, 18.700, 6.900, 25.250, 18.700, 4.999, 0.60, "#AD4931" },
		{ 13.603, 18.700, 6.900, 25.250, 18.700, 4.999, 13.565, 18.700, -6.900, 0.60, "#AD4931" },
		{ 13.250, 18.700, -6.585, 13.250, 18.700, 6.547, 13.603, 18.700, 6.900, 0.60, "#AD4931" },
		{ 13.250, 18.700, -6.585, 13.603, 18.700, 6.900, 13.565, 18.700, -6.900, 0.60, "#AD4931" },
		{ 25.600, 21.700, 5.118, 25.600, 21.700, -5.529, 23.879, 21.700, -7.250, 0.60, "#BF5236" },
		{ 25.600, 21.700, 5.118, 23.879, 21.700, -7.250, 13.314, 21.700, -7.250, 0.60, "#BF5236" },
		{ 13.306, 21.700, 7.250, 23.468, 21.700, 7.250, 25.600, 21.700, 5.118, 0.60, "#BF5236" },
		{ 13.306, 21.700, 7.250, 25.600, 21.700, 5.118, 13.314, 21.700, -7.250, 0.60, "#BF5236" },
		{ 13.100, 21.700, -7.036, 13.100, 21.700, 7.044, 13.306, 21.700, 7.250, 0.60, "#BF5236" },
		{ 13.100, 21.700, -7.036, 13.306, 21.700, 7.250, 13.314, 21.700, -7.250, 0.60, "#BF5236" },
		{ 13.314, 19.300, -7.250, 23.879, 19.300, -7.250, 25.600, 19.300, -5.529, 0.60, "#903E28" },
		{ 13.314, 19.300, -7.250, 25.600, 19.300, -5.529, 25.600, 19.300, 5.118, 0.60, "#903E28" },
		{ 13.314, 19.300, -7.250, 25.600, 19.300, 5.118, 23.468, 19.300, 7.250, 0.60, "#903E28" },
		{ 13.314, 19.300, -7.250, 23.468, 19.300, 7.250, 13.306, 19.300, 7.250, 0.60, "#903E28" },
		{ 13.314, 19.300, -7.250, 13.306, 19.300, 7.250, 13.100, 19.300, 7.044, 0.60, "#903E28" },
		{ 13.314, 19.300, -7.250, 13.100, 19.300, 7.044, 13.100, 19.300, -7.036, 0.60, "#903E28" },
		{ 24.100, 25.700, 3.988, 24.100, 25.700, -4.249, 22.049, 25.700, -6.300, 0.60, "#973F30" },
		{ 24.100, 25.700, 3.988, 22.049, 25.700, -6.300, 13.466, 25.700, -6.300, 0.60, "#973F30" },
		{ 13.484, 25.700, 6.300, 21.788, 25.700, 6.300, 24.100, 25.700, 3.988, 0.60, "#973F30" },
		{ 13.484, 25.700, 6.300, 24.100, 25.700, 3.988, 13.466, 25.700, -6.300, 0.60, "#973F30" },
		{ 13.250, 25.700, -6.084, 13.250, 25.700, 6.066, 13.484, 25.700, 6.300, 0.60, "#973F30" },
		{ 13.250, 25.700, -6.084, 13.484, 25.700, 6.300, 13.466, 25.700, -6.300, 0.60, "#973F30" },
		{ 23.500, 28.300, 4.320, 23.500, 28.300, -4.664, 21.914, 28.300, -6.250, 0.60, "#C85538" },
		{ 23.500, 28.300, 4.320, 21.914, 28.300, -6.250, 13.382, 28.300, -6.250, 0.60, "#C85538" },
		{ 13.344, 28.300, 6.250, 21.570, 28.300, 6.250, 23.500, 28.300, 4.320, 0.60, "#C85538" },
		{ 13.344, 28.300, 6.250, 23.500, 28.300, 4.320, 13.382, 28.300, -6.250, 0.60, "#C85538" },
		{ 13.000, 28.300, -5.868, 13.000, 28.300, 5.906, 13.344, 28.300, 6.250, 0.60, "#C85538" },
		{ 13.000, 28.300, -5.868, 13.344, 28.300, 6.250, 13.382, 28.300, -6.250, 0.60, "#C85538" },
		{ 13.382, 26.300, -6.250, 21.914, 26.300, -6.250, 23.500, 26.300, -4.664, 0.60, "#923E29" },
		{ 13.382, 26.300, -6.250, 23.500, 26.300, -4.664, 23.500, 26.300, 4.320, 0.60, "#923E29" },
		{ 13.382, 26.300, -6.250, 23.500, 26.300, 4.320, 21.570, 26.300, 6.250, 0.60, "#923E29" },
		{ 13.382, 26.300, -6.250, 21.570, 26.300, 6.250, 13.344, 26.300, 6.250, 0.60, "#923E29" },
		{ 13.382, 26.300, -6.250, 13.344, 26.300, 6.250, 13.000, 26.300, 5.906, 0.60, "#923E29" },
		{ 13.382, 26.300, -6.250, 13.000, 26.300, 5.906, 13.000, 26.300, -5.868, 0.60, "#923E29" },
		{ 23.200, 31.100, 4.186, 23.200, 31.100, -4.185, 21.435, 31.100, -5.950, 0.60, "#B84E35" },
		{ 23.200, 31.100, 4.186, 21.435, 31.100, -5.950, 13.591, 31.100, -5.950, 0.60, "#B84E35" },
		{ 13.574, 31.100, 5.950, 21.436, 31.100, 5.950, 23.200, 31.100, 4.186, 0.60, "#B84E35" },
		{ 13.574, 31.100, 5.950, 23.200, 31.100, 4.186, 13.591, 31.100, -5.950, 0.60, "#B84E35" },
		{ 13.250, 31.100, -5.609, 13.250, 31.100, 5.626, 13.574, 31.100, 5.950, 0.60, "#B84E35" },
		{ 13.250, 31.100, -5.609, 13.574, 31.100, 5.950, 13.591, 31.100, -5.950, 0.60, "#B84E35" },
		{ 23.400, 33.700, 4.710, 23.400, 33.700, -4.116, 21.366, 33.700, -6.150, 0.60, "#CC5739" },
		{ 23.400, 33.700, 4.710, 21.366, 33.700, -6.150, 13.413, 33.700, -6.150, 0.60, "#CC5739" },
		{ 13.439, 33.700, 6.150, 21.960, 33.700, 6.150, 23.400, 33.700, 4.710, 0.60, "#CC5739" },
		{ 13.439, 33.700, 6.150, 23.400, 33.700, 4.710, 13.413, 33.700, -6.150, 0.60, "#CC5739" },
		{ 13.100, 33.700, -5.837, 13.100, 33.700, 5.811, 13.439, 33.700, 6.150, 0.60, "#CC5739" },
		{ 13.100, 33.700, -5.837, 13.439, 33.700, 6.150, 13.413, 33.700, -6.150, 0.60, "#CC5739" },
		{ 13.413, 31.700, -6.150, 21.366, 31.700, -6.150, 23.400, 31.700, -4.116, 0.60, "#923E29" },
		{ 13.413, 31.700, -6.150, 23.400, 31.700, -4.116, 23.400, 31.700, 4.710, 0.60, "#923E29" },
		{ 13.413, 31.700, -6.150, 23.400, 31.700, 4.710, 21.960, 31.700, 6.150, 0.60, "#923E29" },
		{ 13.413, 31.700, -6.150, 21.960, 31.700, 6.150, 13.439, 31.700, 6.150, 0.60, "#923E29" },
		{ 13.413, 31.700, -6.150, 13.439, 31.700, 6.150, 13.100, 31.700, 5.811, 0.60, "#923E29" },
		{ 13.413, 31.700, -6.150, 13.100, 31.700, 5.811, 13.100, 31.700, -5.837, 0.60, "#923E29" },
		{ 21.900, 37.700, 3.188, 21.900, 37.700, -3.300, 20.000, 37.700, -5.200, 0.60, "#EC8452" },
		{ 21.900, 37.700, 3.188, 20.000, 37.700, -5.200, 13.688, 37.700, -5.200, 0.60, "#EC8452" },
		{ 13.577, 37.700, 5.200, 19.888, 37.700, 5.200, 21.900, 37.700, 3.188, 0.60, "#EC8452" },
		{ 13.577, 37.700, 5.200, 21.900, 37.700, 3.188, 13.688, 37.700, -5.200, 0.60, "#EC8452" },
		{ 13.250, 37.700, -4.762, 13.250, 37.700, 4.873, 13.577, 37.700, 5.200, 0.60, "#EC8452" },
		{ 13.250, 37.700, -4.762, 13.577, 37.700, 5.200, 13.688, 37.700, -5.200, 0.60, "#EC8452" },
		{ 16.892, 28.550, -6.255, 17.172, 28.550, -6.255, 16.772, 27.193, -6.255, 0.05, "#622A1C" },
		{ 16.892, 28.550, -6.255, 16.772, 27.193, -6.255, 16.492, 27.193, -6.255, 0.05, "#622A1C" },
		{ 16.492, 27.193, -6.255, 16.772, 27.193, -6.255, 17.463, 26.400, -6.255, 0.05, "#622A1C" },
		{ 16.492, 27.193, -6.255, 17.463, 26.400, -6.255, 17.183, 26.400, -6.255, 0.05, "#622A1C" },
		{ 16.480, 25.950, 6.305, 16.200, 25.950, 6.305, 16.514, 23.742, 6.305, 0.05, "#4B1F18" },
		{ 16.480, 25.950, 6.305, 16.514, 23.742, 6.305, 16.794, 23.742, 6.305, 0.05, "#4B1F18" },
		{ 16.794, 23.742, 6.305, 16.514, 23.742, 6.305, 16.020, 22.400, 6.305, 0.05, "#4B1F18" },
		{ 16.794, 23.742, 6.305, 16.020, 22.400, 6.305, 16.300, 22.400, 6.305, 0.05, "#4B1F18" },
		{ 25.255, 18.950, 0.502, 25.255, 18.950, 0.782, 25.255, 17.421, 0.293, 0.05, "#582519" },
		{ 25.255, 18.950, 0.502, 25.255, 17.421, 0.293, 25.255, 17.421, 0.013, 0.05, "#582519" },
		{ 25.255, 17.421, 0.013, 25.255, 17.421, 0.293, 25.255, 16.200, 0.488, 0.05, "#582519" },
		{ 25.255, 17.421, 0.013, 25.255, 16.200, 0.488, 25.255, 16.200, 0.208, 0.05, "#582519" },
		{ 23.405, 33.950, 1.211, 23.405, 33.950, 1.491, 23.405, 32.866, 1.644, 0.05, "#622A1C" },
		{ 23.405, 33.950, 1.211, 23.405, 32.866, 1.644, 23.405, 32.866, 1.364, 0.05, "#622A1C" },
		{ 23.405, 32.866, 1.364, 23.405, 32.866, 1.644, 23.405, 31.800, 1.635, 0.05, "#622A1C" },
		{ 23.405, 32.866, 1.364, 23.405, 31.800, 1.635, 23.405, 31.800, 1.355, 0.05, "#622A1C" },
		{ 18.936, 33.950, 6.155, 18.656, 33.950, 6.155, 18.833, 32.817, 6.155, 0.05, "#622A1C" },
		{ 18.936, 33.950, 6.155, 18.833, 32.817, 6.155, 19.113, 32.817, 6.155, 0.05, "#622A1C" },
		{ 19.113, 32.817, 6.155, 18.833, 32.817, 6.155, 18.464, 31.800, 6.155, 0.05, "#622A1C" },
		{ 19.113, 32.817, 6.155, 18.464, 31.800, 6.155, 18.744, 31.800, 6.155, 0.05, "#622A1C" },
		{ 17.011, 42.119, -2.700, 21.399, 41.592, -2.700, 21.399, 38.000, -2.700, 0.60, "#DB7B4D" },
		{ 17.011, 42.119, -2.700, 21.399, 38.000, -2.700, 17.011, 38.000, -2.700, 0.60, "#DB7B4D" },
		{ 21.187, 41.592, -2.788, 21.788, 41.472, -2.187, 21.788, 38.000, -2.187, 0.60, "#D2764A" },
		{ 21.187, 41.592, -2.788, 21.788, 38.000, -2.187, 21.187, 38.000, -2.788, 0.60, "#D2764A" },
		{ 21.700, 41.472, -2.399, 21.700, 41.031, 3.118, 21.700, 38.000, 3.118, 0.60, "#D2764A" },
		{ 21.700, 41.472, -2.399, 21.700, 38.000, 3.118, 21.700, 38.000, -2.399, 0.60, "#D2764A" },
		{ 21.788, 41.031, 2.906, 20.906, 41.066, 3.788, 20.906, 38.000, 3.788, 0.60, "#D2764A" },
		{ 21.788, 41.031, 2.906, 20.906, 38.000, 3.788, 21.788, 38.000, 2.906, 0.60, "#D2764A" },
		{ 21.118, 41.066, 3.700, 17.007, 41.559, 3.700, 17.007, 38.000, 3.700, 0.60, "#DB7B4D" },
		{ 21.118, 41.066, 3.700, 17.007, 38.000, 3.700, 21.118, 38.000, 3.700, 0.60, "#DB7B4D" },
		{ 17.219, 41.559, 3.788, 16.212, 41.761, 2.781, 16.212, 38.000, 2.781, 0.60, "#E48050" },
		{ 17.219, 41.559, 3.788, 16.212, 38.000, 2.781, 17.219, 38.000, 3.788, 0.60, "#E48050" },
		{ 16.300, 41.761, 2.993, 16.300, 42.159, -1.989, 16.300, 38.000, -1.989, 0.60, "#DB7B4D" },
		{ 16.300, 41.761, 2.993, 16.300, 38.000, -1.989, 16.300, 38.000, 2.993, 0.60, "#DB7B4D" },
		{ 16.212, 42.159, -1.777, 17.223, 42.119, -2.788, 17.223, 38.000, -2.788, 0.60, "#DB7B4D" },
		{ 16.212, 42.159, -1.777, 17.223, 38.000, -2.788, 16.212, 38.000, -1.777, 0.60, "#DB7B4D" },
		{ 21.964, 40.734, 3.094, 21.964, 41.175, -2.423, 21.363, 41.295, -3.024, 0.60, "#F28855" },
		{ 21.964, 40.734, 3.094, 21.363, 41.295, -3.024, 16.975, 41.822, -3.024, 0.60, "#F28855" },
		{ 16.971, 41.262, 3.976, 21.082, 40.769, 3.976, 21.964, 40.734, 3.094, 0.60, "#F28855" },
		{ 16.971, 41.262, 3.976, 21.964, 40.734, 3.094, 16.975, 41.822, -3.024, 0.60, "#F28855" },
		{ 15.964, 41.862, -2.013, 15.964, 41.464, 2.969, 16.971, 41.262, 3.976, 0.60, "#F28855" },
		{ 15.964, 41.862, -2.013, 16.971, 41.262, 3.976, 16.975, 41.822, -3.024, 0.60, "#F28855" },
	} },
	side_rock_L = { boxes = {
		{ -36.054, 2.000, -5.200, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.956, 4.000, 0.600, "#9F442D" },
		{ -30.000, 2.000, -4.000, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 3.643, 4.000, 0.600, "#9F442D" },
		{ -28.800, 2.000, 1.685, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 9.218, 4.000, 0.600, "#9F442D" },
		{ -29.815, 2.000, 7.185, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 3.120, 4.000, 0.600, "#9F442D" },
		{ -35.367, 2.000, 8.200, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.322, 4.000, 0.600, "#95402A" },
		{ -41.552, 2.000, 6.552, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 4.910, 4.000, 0.600, "#95402A" },
		{ -43.200, 2.000, 0.998, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 8.060, 4.000, 0.600, "#9F442D" },
		{ -42.054, 2.000, -4.054, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 3.490, 4.000, 0.600, "#9A422C" },
		{ -35.319, 6.000, -4.900, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.096, 4.000, 0.600, "#A3462E" },
		{ -29.998, 6.000, -4.002, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.787, 4.000, 0.600, "#A84830" },
		{ -29.100, 6.000, 1.276, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 9.009, 4.000, 0.600, "#9E442D" },
		{ -30.222, 6.000, 6.778, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 3.422, 4.000, 0.600, "#A3462E" },
		{ -35.609, 6.000, 7.900, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 8.779, 4.000, 0.600, "#A3462E" },
		{ -41.387, 6.000, 6.387, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 4.527, 4.000, 0.600, "#A3462E" },
		{ -42.900, 6.000, 1.566, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 6.866, 4.000, 0.600, "#A3462E" },
		{ -41.321, 6.000, -3.321, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 4.714, 4.000, 0.600, "#A3462E" },
		{ -35.883, 10.000, -4.100, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.256, 4.000, 0.600, "#C16D43" },
		{ -30.640, 10.000, -3.360, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.341, 4.000, 0.600, "#C16D43" },
		{ -29.900, 10.000, 0.803, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 7.096, 4.000, 0.600, "#CD7448" },
		{ -31.337, 10.000, 5.663, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 4.312, 4.000, 0.600, "#CD7448" },
		{ -36.337, 10.000, 7.100, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 7.376, 4.000, 0.600, "#C16D43" },
		{ -41.000, 10.000, 6.000, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 3.359, 4.000, 0.600, "#C77046" },
		{ -42.100, 10.000, 1.257, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 7.536, 4.000, 0.600, "#CD7448" },
		{ -41.243, 10.000, -3.243, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 2.671, 4.000, 0.600, "#CD7448" },
		{ -35.992, 13.750, -4.200, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 7.998, 3.500, 0.600, "#A2452E" },
		{ -30.959, 13.750, -3.041, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 3.526, 3.500, 0.600, "#A2452E" },
		{ -29.800, 13.750, 1.919, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 7.853, 3.500, 0.600, "#AC4A31" },
		{ -30.539, 13.750, 6.461, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.339, 3.500, 0.600, "#A2452E" },
		{ -35.831, 13.750, 7.200, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.354, 3.500, 0.600, "#AC4A31" },
		{ -41.292, 13.750, 6.292, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 2.817, 3.500, 0.600, "#AC4A31" },
		{ -42.200, 13.750, 1.758, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 7.499, 3.500, 0.600, "#A2452E" },
		{ -41.033, 13.750, -3.033, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 3.548, 3.500, 0.600, "#A74830" },
		{ -36.270, 17.250, -3.850, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 8.121, 3.500, 0.600, "#A3452E" },
		{ -31.242, 17.250, -2.758, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 3.336, 3.500, 0.600, "#99412B" },
		{ -30.150, 17.250, 1.851, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 7.284, 3.500, 0.600, "#9E432D" },
		{ -30.891, 17.250, 6.109, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.343, 3.500, 0.600, "#99412B" },
		{ -36.014, 17.250, 6.850, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.015, 3.500, 0.600, "#99412B" },
		{ -41.124, 17.250, 6.124, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 2.302, 3.500, 0.600, "#99412B" },
		{ -41.850, 17.250, 1.596, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 7.852, 3.500, 0.600, "#99412B" },
		{ -41.028, 17.250, -3.028, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 2.574, 3.500, 0.600, "#99412B" },
		{ -36.237, 21.000, -3.400, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 7.401, 4.000, 0.600, "#84372A" },
		{ -31.631, 21.000, -2.369, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 3.164, 4.000, 0.600, "#803529" },
		{ -30.600, 21.000, 1.988, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 6.902, 4.000, 0.600, "#84372A" },
		{ -31.143, 21.000, 5.857, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 1.783, 4.000, 0.600, "#84372A" },
		{ -35.320, 21.000, 6.400, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 7.519, 4.000, 0.600, "#84372A" },
		{ -40.178, 21.000, 5.178, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 3.705, 4.000, 0.600, "#803529" },
		{ -41.400, 21.000, 1.071, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 6.018, 4.000, 0.600, "#84372A" },
		{ -40.607, 21.000, -2.607, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 2.492, 4.000, 0.600, "#803529" },
	}, tris = {
		{ -28.500, 3.700, 6.294, -28.500, 3.700, -2.924, -31.076, 3.700, -5.500, 0.60, "#A84830" },
		{ -28.500, 3.700, 6.294, -31.076, 3.700, -5.500, -41.032, 3.700, -5.500, 0.60, "#A84830" },
		{ -40.028, 3.700, 8.500, -30.706, 3.700, 8.500, -28.500, 3.700, 6.294, 0.60, "#A84830" },
		{ -40.028, 3.700, 8.500, -28.500, 3.700, 6.294, -41.032, 3.700, -5.500, 0.60, "#A84830" },
		{ -43.500, 3.700, -3.032, -43.500, 3.700, 5.028, -40.028, 3.700, 8.500, 0.60, "#A84830" },
		{ -43.500, 3.700, -3.032, -40.028, 3.700, 8.500, -41.032, 3.700, -5.500, 0.60, "#A84830" },
		{ -28.800, 7.700, 5.780, -28.800, 7.700, -3.229, -30.771, 7.700, -5.200, 0.60, "#B34C33" },
		{ -28.800, 7.700, 5.780, -30.771, 7.700, -5.200, -39.867, 7.700, -5.200, 0.60, "#B34C33" },
		{ -39.999, 7.700, 8.200, -31.220, 7.700, 8.200, -28.800, 7.700, 5.780, 0.60, "#B34C33" },
		{ -39.999, 7.700, 8.200, -28.800, 7.700, 5.780, -39.867, 7.700, -5.200, 0.60, "#B34C33" },
		{ -43.200, 7.700, -1.867, -43.200, 7.700, 4.999, -39.999, 7.700, 8.200, 0.60, "#B34C33" },
		{ -43.200, 7.700, -1.867, -39.999, 7.700, 8.200, -39.867, 7.700, -5.200, 0.60, "#B34C33" },
		{ -29.600, 11.700, 4.351, -29.600, 11.700, -2.745, -31.255, 11.700, -4.400, 0.60, "#DA7B4C" },
		{ -29.600, 11.700, 4.351, -31.255, 11.700, -4.400, -40.511, 11.700, -4.400, 0.60, "#DA7B4C" },
		{ -40.025, 11.700, 7.400, -32.649, 11.700, 7.400, -29.600, 11.700, 4.351, 0.60, "#DA7B4C" },
		{ -40.025, 11.700, 7.400, -29.600, 11.700, 4.351, -40.511, 11.700, -4.400, 0.60, "#DA7B4C" },
		{ -42.400, 11.700, -2.511, -42.400, 11.700, 5.025, -40.025, 11.700, 7.400, 0.60, "#DA7B4C" },
		{ -42.400, 11.700, -2.511, -40.025, 11.700, 7.400, -40.511, 11.700, -4.400, 0.60, "#DA7B4C" },
		{ -29.500, 15.200, 5.846, -29.500, 15.200, -2.007, -31.993, 15.200, -4.500, 0.60, "#B64E34" },
		{ -29.500, 15.200, 5.846, -31.993, 15.200, -4.500, -39.991, 15.200, -4.500, 0.60, "#B64E34" },
		{ -40.508, 15.200, 7.500, -31.154, 15.200, 7.500, -29.500, 15.200, 5.846, 0.60, "#B64E34" },
		{ -40.508, 15.200, 7.500, -29.500, 15.200, 5.846, -39.991, 15.200, -4.500, 0.60, "#B64E34" },
		{ -42.500, 15.200, -1.991, -42.500, 15.200, 5.508, -40.508, 15.200, 7.500, 0.60, "#B64E34" },
		{ -42.500, 15.200, -1.991, -40.508, 15.200, 7.500, -39.991, 15.200, -4.500, 0.60, "#B64E34" },
		{ -39.991, 12.300, -4.500, -31.993, 12.300, -4.500, -29.500, 12.300, -2.007, 0.60, "#8E3D28" },
		{ -39.991, 12.300, -4.500, -29.500, 12.300, -2.007, -29.500, 12.300, 5.846, 0.60, "#8E3D28" },
		{ -39.991, 12.300, -4.500, -29.500, 12.300, 5.846, -31.154, 12.300, 7.500, 0.60, "#8E3D28" },
		{ -39.991, 12.300, -4.500, -31.154, 12.300, 7.500, -40.508, 12.300, 7.500, 0.60, "#8E3D28" },
		{ -39.991, 12.300, -4.500, -40.508, 12.300, 7.500, -42.500, 12.300, 5.508, 0.60, "#8E3D28" },
		{ -39.991, 12.300, -4.500, -42.500, 12.300, 5.508, -42.500, 12.300, -1.991, 0.60, "#8E3D28" },
		{ -29.850, 18.700, 5.493, -29.850, 18.700, -1.791, -32.209, 18.700, -4.150, 0.60, "#AC4931" },
		{ -29.850, 18.700, 5.493, -32.209, 18.700, -4.150, -40.330, 18.700, -4.150, 0.60, "#AC4931" },
		{ -40.522, 18.700, 7.150, -31.507, 18.700, 7.150, -29.850, 18.700, 5.493, 0.60, "#AC4931" },
		{ -40.522, 18.700, 7.150, -29.850, 18.700, 5.493, -40.330, 18.700, -4.150, 0.60, "#AC4931" },
		{ -42.150, 18.700, -2.330, -42.150, 18.700, 5.522, -40.522, 18.700, 7.150, 0.60, "#AC4931" },
		{ -42.150, 18.700, -2.330, -40.522, 18.700, 7.150, -40.330, 18.700, -4.150, 0.60, "#AC4931" },
		{ -30.300, 22.700, 5.439, -30.300, 22.700, -1.463, -32.537, 22.700, -3.700, 0.60, "#903C2E" },
		{ -30.300, 22.700, 5.439, -32.537, 22.700, -3.700, -39.938, 22.700, -3.700, 0.60, "#903C2E" },
		{ -39.080, 22.700, 6.700, -31.561, 22.700, 6.700, -30.300, 22.700, 5.439, 0.60, "#903C2E" },
		{ -39.080, 22.700, 6.700, -30.300, 22.700, 5.439, -39.938, 22.700, -3.700, 0.60, "#903C2E" },
		{ -41.700, 22.700, -1.938, -41.700, 22.700, 4.080, -39.080, 22.700, 6.700, 0.60, "#903C2E" },
		{ -41.700, 22.700, -1.938, -39.080, 22.700, 6.700, -39.938, 22.700, -3.700, 0.60, "#903C2E" },
		{ -41.272, 7.950, 6.933, -41.470, 7.950, 6.735, -41.046, 6.357, 7.159, 0.05, "#5F281B" },
		{ -41.272, 7.950, 6.933, -41.046, 6.357, 7.159, -40.848, 6.357, 7.357, 0.05, "#5F281B" },
		{ -40.848, 6.357, 7.357, -41.046, 6.357, 7.159, -41.726, 4.400, 6.480, 0.05, "#5F281B" },
		{ -40.848, 6.357, 7.357, -41.726, 4.400, 6.480, -41.528, 4.400, 6.678, 0.05, "#5F281B" },
		{ -30.627, 11.950, 5.385, -30.825, 11.950, 5.583, -30.969, 10.380, 5.726, 0.05, "#724028" },
		{ -30.627, 11.950, 5.385, -30.969, 10.380, 5.726, -30.771, 10.380, 5.528, 0.05, "#724028" },
		{ -30.771, 10.380, 5.528, -30.969, 10.380, 5.726, -30.749, 8.400, 5.506, 0.05, "#724028" },
		{ -30.771, 10.380, 5.528, -30.749, 8.400, 5.506, -30.551, 8.400, 5.308, 0.05, "#724028" },
		{ -42.070, 3.950, -4.469, -41.872, 3.950, -4.667, -41.917, 1.913, -4.621, 0.05, "#5A261A" },
		{ -42.070, 3.950, -4.469, -41.917, 1.913, -4.621, -42.115, 1.913, -4.423, 0.05, "#5A261A" },
		{ -42.115, 1.913, -4.423, -41.917, 1.913, -4.621, -41.730, 0.400, -4.809, 0.05, "#5A261A" },
		{ -42.115, 1.913, -4.423, -41.730, 0.400, -4.809, -41.928, 0.400, -4.611, 0.05, "#5A261A" },
	} },
	side_rock_R = { boxes = {
		{ 36.593, 2.000, -5.200, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.315, 4.000, 0.600, "#A74730" },
		{ 42.163, 2.000, -4.163, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 3.182, 4.000, 0.600, "#9D432D" },
		{ 43.200, 2.000, 1.134, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 8.768, 4.000, 0.600, "#A74730" },
		{ 41.797, 2.000, 6.797, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 4.217, 4.000, 0.600, "#A2452E" },
		{ 36.032, 2.000, 8.200, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 8.971, 4.000, 0.600, "#A74730" },
		{ 30.236, 2.000, 6.764, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 4.309, 4.000, 0.600, "#A74730" },
		{ 28.800, 2.000, 1.694, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 7.518, 4.000, 0.600, "#A74730" },
		{ 30.430, 2.000, -3.570, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 4.858, 4.000, 0.600, "#9D432D" },
		{ 35.988, 6.000, -4.900, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.462, 4.000, 0.600, "#A74730" },
		{ 41.747, 6.000, -3.747, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 3.509, 4.000, 0.600, "#A74730" },
		{ 42.900, 6.000, 1.147, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 7.732, 4.000, 0.600, "#B14B33" },
		{ 41.394, 6.000, 6.394, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 4.507, 4.000, 0.600, "#B14B33" },
		{ 35.704, 6.000, 7.900, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 8.618, 4.000, 0.600, "#A74730" },
		{ 30.310, 6.000, 6.690, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 3.670, 4.000, 0.600, "#A74730" },
		{ 29.100, 6.000, 1.431, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 8.348, 4.000, 0.600, "#B14B33" },
		{ 30.241, 6.000, -3.759, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 3.475, 4.000, 0.600, "#B14B33" },
		{ 35.901, 10.000, -4.100, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 8.823, 4.000, 0.600, "#CE7448" },
		{ 41.144, 10.000, -3.144, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.951, 4.000, 0.600, "#C26D43" },
		{ 42.100, 10.000, 1.533, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 7.692, 4.000, 0.600, "#CE7448" },
		{ 41.177, 10.000, 6.177, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.858, 4.000, 0.600, "#C26D43" },
		{ 35.793, 10.000, 7.100, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.171, 4.000, 0.600, "#CE7448" },
		{ 30.616, 10.000, 6.384, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 2.274, 4.000, 0.600, "#C87046" },
		{ 29.900, 10.000, 1.641, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 8.302, 4.000, 0.600, "#C26D43" },
		{ 30.757, 10.000, -3.243, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 2.673, 4.000, 0.600, "#C87046" },
		{ 36.400, 13.750, -4.200, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 9.056, 3.500, 0.600, "#A3452E" },
		{ 41.502, 13.750, -3.502, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.223, 3.500, 0.600, "#A84830" },
		{ 42.200, 13.750, 1.233, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 8.323, 3.500, 0.600, "#A3452E" },
		{ 41.235, 13.750, 6.235, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.977, 3.500, 0.600, "#AD4A31" },
		{ 36.319, 13.750, 7.200, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 8.153, 3.500, 0.600, "#A84830" },
		{ 31.083, 13.750, 5.917, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 3.878, 3.500, 0.600, "#AD4A31" },
		{ 29.800, 13.750, 1.315, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 6.886, 3.500, 0.600, "#A3452E" },
		{ 30.898, 13.750, -3.102, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 3.355, 3.500, 0.600, "#A3452E" },
		{ 36.177, 17.250, -3.850, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 7.344, 3.500, 0.600, "#A4452E" },
		{ 40.787, 17.250, -2.787, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 3.254, 3.500, 0.600, "#9A412B" },
		{ 41.850, 17.250, 1.733, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 7.165, 3.500, 0.600, "#A4452E" },
		{ 41.021, 17.250, 6.021, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 2.594, 3.500, 0.600, "#9A412B" },
		{ 36.493, 17.250, 6.850, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 7.645, 3.500, 0.600, "#9A412B" },
		{ 31.473, 17.250, 5.527, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 3.989, 3.500, 0.600, "#9A412B" },
		{ 30.150, 17.250, 1.417, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 5.824, 3.500, 0.600, "#9A412B" },
		{ 31.390, 17.250, -2.610, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 3.755, 3.500, 0.600, "#A4452E" },
		{ 36.579, 21.000, -3.400, 1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 7.539, 4.000, 0.600, "#85372A" },
		{ 40.812, 21.000, -2.812, 0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 1.911, 4.000, 0.600, "#813529" },
		{ 41.400, 21.000, 0.933, 0.000, 0.000, 1.000, 0.000, -1.000, 0.000, 6.565, 4.000, 0.600, "#89382B" },
		{ 40.246, 21.000, 5.246, -0.707, 0.000, 0.707, 0.000, -1.000, 0.000, 3.513, 4.000, 0.600, "#89382B" },
		{ 35.819, 21.000, 6.400, -1.000, 0.000, 0.000, 0.000, -1.000, 0.000, 6.795, 4.000, 0.600, "#813529" },
		{ 31.573, 21.000, 5.427, -0.707, 0.000, -0.707, -0.000, -1.000, 0.000, 3.000, 4.000, 0.600, "#813529" },
		{ 30.600, 21.000, 1.694, 0.000, 0.000, -1.000, 0.000, -1.000, -0.000, 5.769, 4.000, 0.600, "#85372A" },
		{ 31.767, 21.000, -2.233, 0.707, 0.000, -0.707, 0.000, -1.000, -0.000, 3.550, 4.000, 0.600, "#85372A" },
	}, tris = {
		{ 43.500, 3.700, 5.518, 43.500, 3.700, -3.250, 41.250, 3.700, -5.500, 0.60, "#B14C32" },
		{ 43.500, 3.700, 5.518, 41.250, 3.700, -5.500, 31.935, 3.700, -5.500, 0.60, "#B14C32" },
		{ 31.547, 3.700, 8.500, 40.518, 3.700, 8.500, 43.500, 3.700, 5.518, 0.60, "#B14C32" },
		{ 31.547, 3.700, 8.500, 43.500, 3.700, 5.518, 31.935, 3.700, -5.500, 0.60, "#B14C32" },
		{ 28.500, 3.700, -2.065, 28.500, 3.700, 5.453, 31.547, 3.700, 8.500, 0.60, "#B14C32" },
		{ 28.500, 3.700, -2.065, 31.547, 3.700, 8.500, 31.935, 3.700, -5.500, 0.60, "#B14C32" },
		{ 43.200, 7.700, 5.013, 43.200, 7.700, -2.719, 40.719, 7.700, -5.200, 0.60, "#BC5036" },
		{ 43.200, 7.700, 5.013, 40.719, 7.700, -5.200, 31.257, 7.700, -5.200, 0.60, "#BC5036" },
		{ 31.395, 7.700, 8.200, 40.013, 7.700, 8.200, 43.200, 7.700, 5.013, 0.60, "#BC5036" },
		{ 31.395, 7.700, 8.200, 43.200, 7.700, 5.013, 31.257, 7.700, -5.200, 0.60, "#BC5036" },
		{ 28.800, 7.700, -2.743, 28.800, 7.700, 5.605, 31.395, 7.700, 8.200, 0.60, "#BC5036" },
		{ 28.800, 7.700, -2.743, 31.395, 7.700, 8.200, 31.257, 7.700, -5.200, 0.60, "#BC5036" },
		{ 42.400, 11.700, 5.379, 42.400, 11.700, -2.313, 40.313, 11.700, -4.400, 0.60, "#DB7B4C" },
		{ 42.400, 11.700, 5.379, 40.313, 11.700, -4.400, 31.490, 11.700, -4.400, 0.60, "#DB7B4C" },
		{ 31.208, 11.700, 7.400, 40.379, 11.700, 7.400, 42.400, 11.700, 5.379, 0.60, "#DB7B4C" },
		{ 31.208, 11.700, 7.400, 42.400, 11.700, 5.379, 31.490, 11.700, -4.400, 0.60, "#DB7B4C" },
		{ 29.600, 11.700, -2.510, 29.600, 11.700, 5.792, 31.208, 11.700, 7.400, 0.60, "#DB7B4C" },
		{ 29.600, 11.700, -2.510, 31.208, 11.700, 7.400, 31.490, 11.700, -4.400, 0.60, "#DB7B4C" },
		{ 42.500, 15.200, 5.395, 42.500, 15.200, -2.928, 40.928, 15.200, -4.500, 0.60, "#B74E34" },
		{ 42.500, 15.200, 5.395, 40.928, 15.200, -4.500, 31.872, 15.200, -4.500, 0.60, "#B74E34" },
		{ 32.242, 15.200, 7.500, 40.395, 15.200, 7.500, 42.500, 15.200, 5.395, 0.60, "#B74E34" },
		{ 32.242, 15.200, 7.500, 42.500, 15.200, 5.395, 31.872, 15.200, -4.500, 0.60, "#B74E34" },
		{ 29.500, 15.200, -2.128, 29.500, 15.200, 4.758, 32.242, 15.200, 7.500, 0.60, "#B74E34" },
		{ 29.500, 15.200, -2.128, 32.242, 15.200, 7.500, 31.872, 15.200, -4.500, 0.60, "#B74E34" },
		{ 31.872, 12.300, -4.500, 40.928, 12.300, -4.500, 42.500, 12.300, -2.928, 0.60, "#8E3D28" },
		{ 31.872, 12.300, -4.500, 42.500, 12.300, -2.928, 42.500, 12.300, 5.395, 0.60, "#8E3D28" },
		{ 31.872, 12.300, -4.500, 42.500, 12.300, 5.395, 40.395, 12.300, 7.500, 0.60, "#8E3D28" },
		{ 31.872, 12.300, -4.500, 40.395, 12.300, 7.500, 32.242, 12.300, 7.500, 0.60, "#8E3D28" },
		{ 31.872, 12.300, -4.500, 32.242, 12.300, 7.500, 29.500, 12.300, 4.758, 0.60, "#8E3D28" },
		{ 31.872, 12.300, -4.500, 29.500, 12.300, 4.758, 29.500, 12.300, -2.128, 0.60, "#8E3D28" },
		{ 42.150, 18.700, 5.316, 42.150, 18.700, -1.849, 39.849, 18.700, -4.150, 0.60, "#AD4931" },
		{ 42.150, 18.700, 5.316, 39.849, 18.700, -4.150, 32.505, 18.700, -4.150, 0.60, "#AD4931" },
		{ 32.671, 18.700, 7.150, 40.316, 18.700, 7.150, 42.150, 18.700, 5.316, 0.60, "#AD4931" },
		{ 32.671, 18.700, 7.150, 42.150, 18.700, 5.316, 32.505, 18.700, -4.150, 0.60, "#AD4931" },
		{ 29.850, 18.700, -1.495, 29.850, 18.700, 4.329, 32.671, 18.700, 7.150, 0.60, "#AD4931" },
		{ 29.850, 18.700, -1.495, 32.671, 18.700, 7.150, 32.505, 18.700, -4.150, 0.60, "#AD4931" },
		{ 41.700, 22.700, 4.216, 41.700, 22.700, -2.349, 40.349, 22.700, -3.700, 0.60, "#913C2E" },
		{ 41.700, 22.700, 4.216, 40.349, 22.700, -3.700, 32.810, 22.700, -3.700, 0.60, "#913C2E" },
		{ 32.421, 22.700, 6.700, 39.216, 22.700, 6.700, 41.700, 22.700, 4.216, 0.60, "#913C2E" },
		{ 32.421, 22.700, 6.700, 41.700, 22.700, 4.216, 32.810, 22.700, -3.700, 0.60, "#913C2E" },
		{ 30.300, 22.700, -1.190, 30.300, 22.700, 4.579, 32.421, 22.700, 6.700, 0.60, "#913C2E" },
		{ 30.300, 22.700, -1.190, 32.421, 22.700, 6.700, 32.810, 22.700, -3.700, 0.60, "#913C2E" },
		{ 31.219, 22.950, -2.115, 31.417, 22.950, -2.313, 31.772, 21.131, -2.668, 0.05, "#491E17" },
		{ 31.219, 22.950, -2.115, 31.772, 21.131, -2.668, 31.574, 21.131, -2.470, 0.05, "#491E17" },
		{ 31.574, 21.131, -2.470, 31.772, 21.131, -2.668, 31.296, 19.400, -2.192, 0.05, "#491E17" },
		{ 31.574, 21.131, -2.470, 31.296, 19.400, -2.192, 31.098, 19.400, -1.994, 0.05, "#491E17" },
		{ 29.495, 15.450, 2.237, 29.495, 15.450, 1.957, 29.495, 13.781, 2.183, 0.05, "#5F281B" },
		{ 29.495, 15.450, 2.237, 29.495, 13.781, 2.183, 29.495, 13.781, 2.463, 0.05, "#5F281B" },
		{ 29.495, 13.781, 2.463, 29.495, 13.781, 2.183, 29.495, 12.400, 1.846, 0.05, "#5F281B" },
		{ 29.495, 13.781, 2.463, 29.495, 12.400, 1.846, 29.495, 12.400, 2.126, 0.05, "#5F281B" },
		{ 36.470, 11.950, 7.405, 36.190, 11.950, 7.405, 36.329, 10.056, 7.405, 0.05, "#734028" },
		{ 36.470, 11.950, 7.405, 36.329, 10.056, 7.405, 36.609, 10.056, 7.405, 0.05, "#734028" },
		{ 36.609, 10.056, 7.405, 36.329, 10.056, 7.405, 36.165, 8.400, 7.405, 0.05, "#734028" },
		{ 36.609, 10.056, 7.405, 36.165, 8.400, 7.405, 36.445, 8.400, 7.405, 0.05, "#734028" },
	} },
}

D.ENVELOPES.canyon_barricade = {
	{ "Block", 10.5, 8, 12.5, { -18.25, 30, 0, 0.9992, 0, -0.0389, 0, 1, 0, 0.0389, 0, 0.9992 } }, -- Pillar
	{ "Block", 11.6, 4, 13.6, { -18.8, 24, 0, 0.9999, 0, 0.0103, 0, 1, 0, -0.0103, 0, 0.9999 } }, -- Pillar
	{ "Block", 14, 4, 13, { -36, 10, 1.5, 0.9971, 0, 0.0761, 0, 1, 0, -0.0761, 0, 0.9971 } }, -- SideRock
	{ "Block", 15, 8, 14, { -36, 4, 1.5, 0.9991, 0, 0.042, 0, 1, 0, -0.042, 0, 0.9991 } }, -- SideRock
	{ "Block", 6, 5, 7, { -19, 39.5, 0.5, 0.9345, 0.0982, -0.342, -0.1045, 0.9945, 0, 0.3401, 0.0358, 0.9397 } }, -- PillarCap
	{ "Block", 9.4, 4, 11.4, { -17.7, 36, 0, 0.9996, 0, -0.0276, 0, 1, 0, 0.0276, 0, 0.9996 } }, -- Pillar
	{ "Block", 13.8, 4, 15.8, { -19.9, 11, 0, 0.9988, 0, 0.0497, 0, 1, 0, -0.0497, 0, 0.9988 } }, -- Pillar
	{ "Block", 14.9, 9, 16.9, { -20.45, 4.5, 0, 0.998, 0, 0.0625, 0, 1, 0, -0.0625, 0, 0.998 } }, -- Pillar
	{ "Block", 12.7, 9, 14.7, { -19.35, 17.5, 0, 0.9992, 0, -0.0402, 0, 1, 0, 0.0402, 0, 0.9992 } }, -- Pillar
	{ "Block", 13, 5, 0.5, { 0, 18.4, -1.15, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- SignBack
	{ "Block", 1.4, 1.4, 1.4, { -12.6, 10.3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Anchor
	{ "Block", 1.4, 1.4, 1.4, { -12.6, 14.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Anchor
	{ "Block", 1.4, 1.4, 1.4, { -12.6, 4.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Anchor
	{ "Block", 14.9, 9, 16.9, { 20.45, 4.5, 0, 0.9999, 0, 0.0171, 0, 1, 0, -0.0171, 0, 0.9999 } }, -- Pillar
	{ "Block", 12, 4, 11, { -36, 21, 1.5, 0.9935, 0, 0.114, 0, 1, 0, -0.114, 0, 0.9935 } }, -- SideRock
	{ "Block", 13, 7, 12, { -36, 15.5, 1.5, 0.9946, 0, 0.1038, 0, 1, 0, -0.1038, 0, 0.9946 } }, -- SideRock
	{ "Block", 30, 1.8, 1.8, { 0, 21.1, 0, 0.9997, -0.0262, 0, 0.0262, 0.9997, 0, 0, 0, 1 } }, -- Beam
	{ "Block", 1, 6, 1, { 5, 17.6, -0.6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Rope
	{ "Block", 1, 6, 1, { -5, 17.6, -0.6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Rope
	{ "Block", 1.4, 1.4, 1.4, { 12.6, 14.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Anchor
	{ "Block", 1.4, 1.4, 1.4, { 12.6, 4.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Anchor
	{ "Block", 12, 4, 11, { 36, 21, 1.5, 0.9987, 0, 0.0505, 0, 1, 0, -0.0505, 0, 0.9987 } }, -- SideRock
	{ "Block", 14, 4, 13, { 36, 10, 1.5, 0.9952, 0, 0.0978, 0, 1, 0, -0.0978, 0, 0.9952 } }, -- SideRock
	{ "Block", 15, 8, 14, { 36, 4, 1.5, 1, 0, -0.0003, 0, 1, 0, 0.0003, 0, 1 } }, -- SideRock
	{ "Block", 13, 7, 12, { 36, 15.5, 1.5, 0.9968, 0, -0.0796, 0, 1, 0, 0.0796, 0, 0.9968 } }, -- SideRock
	{ "Block", 1.4, 1.4, 1.4, { 12.6, 10.3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, -- Anchor
	{ "Block", 10.5, 8, 12.5, { 18.25, 30, 0, 0.9995, 0, -0.0301, 0, 1, 0, 0.0301, 0, 0.9995 } }, -- Pillar
	{ "Block", 6, 5, 7, { 19, 39.5, 0.5, 0.9345, -0.0982, 0.342, 0.1045, 0.9945, 0, -0.3401, 0.0358, 0.9397 } }, -- PillarCap
	{ "Block", 9.4, 4, 11.4, { 17.7, 36, 0, 0.9979, 0, 0.0653, 0, 1, 0, -0.0653, 0, 0.9979 } }, -- Pillar
	{ "Block", 13.8, 4, 15.8, { 19.9, 11, 0, 1, 0, 0.0045, 0, 1, 0, -0.0045, 0, 1 } }, -- Pillar
	{ "Block", 12.7, 9, 14.7, { 19.35, 17.5, 0, 0.9991, 0, -0.043, 0, 1, 0, 0.043, 0, 0.9991 } }, -- Pillar
	{ "Block", 11.6, 4, 13.6, { 18.8, 24, 0, 0.9996, 0, 0.0287, 0, 1, 0, -0.0287, 0, 0.9996 } }, -- Pillar
}

-- one of Agent A's facet pieces (Blender_Exports/Props/facets/canyon_gate__*.json, origin = the gate pivot): a box
-- per rectangle face (t thick, inward), a wedge pair per triangle
local function facetUnion(m: Model, name: string, data: any): BasePart
	local list = {}
	for _, b in ipairs(data.boxes) do
		local xa = Vector3.new(b[4], b[5], b[6]).Unit
		local ya = Vector3.new(b[7], b[8], b[9])
		ya = (ya - xa * ya:Dot(xa)).Unit
		table.insert(list, piece("Part", Vector3.new(b[10], b[11], b[12]), CFrame.fromMatrix(Vector3.new(b[1], b[2], b[3]), xa, ya), Color3.fromHex(b[13])))
	end
	for _, t in ipairs(data.tris) do
		tri(list, Vector3.new(t[1], t[2], t[3]), Vector3.new(t[4], t[5], t[6]), Vector3.new(t[7], t[8], t[9]), t[10], Color3.fromHex(t[11]))
	end
	return merge(m, name, list, { query = true })
end

---------------------------------------------------------------------
-- Today's layout, opening (26 wide between the flat inner rock faces), colours and gate contract (docs B12). The
-- canyon rock: Agent A's 4 facet pieces (12 strata red / dark red / orange, erosion grooves, lit ledges, crack
-- strips, a tilted cap; the side rocks in 6 strata) placed at the pivot with no offset. The barricade (all children
-- of today's invisible Barrier, so they vanish when it opens): today's 5 planks as chamfered boards with a chipped
-- top corner, grain lines and knots, 2 battens behind; today's 2 cross boards with grain and nails at every plank;
-- today's 6 chains as riveted iron straps (same places and angles) with hasp plates in the middle; the lock plate
-- with 4 rivets, a padlock with its shackle; today's gold keyhole as an escutcheon with a dark key slot. Outside the
-- Barrier (they stay when it opens): the beam as an adzed timber with 4 iron bands; today's 2 ropes as twisted ropes
-- lashed round the beam; the sign board (today's SignBack) of 3 nailed planks behind today's PriceSign; a small
-- hanging warning plank (a red X) on 2 short ropes; today's 6 anchors as iron eye bolts on rock plates; rubble,
-- broken plank ends, small rocks and sand drifts at the feet of the rocks (never in the opening).
-- Collision: the visible unions do not collide; invisible "Collision" parts are today's colliding parts (32 boxes);
-- the Barrier and the PriceSign keep their own collision as today.
-- Parts: PillarL, PillarR, RockL, RockR, Beam, Ropes, SignBoard, HangingSign, Anchors, Rubble, Sand, Collision x32,
-- Barrier (+ Planks, Crosses, Straps, Lock, Keyhole), PriceSign.
---------------------------------------------------------------------
function Gates.canyon_barricade(): Model
	local m = Instance.new("Model")
	m.Name = "canyon_barricade"
	local rng = Random.new(20261120)
	H.setBevelSelf(true)
	local IRON = rgb(92, 98, 110)
	local PLANK_A, PLANK_B, CROSS = rgb(168, 98, 56), rgb(112, 62, 38), rgb(214, 150, 92)
	local NAIL = scaled(IRON, 0.8)
	local SLOT = rgb(40, 30, 24)
	local function nail(list: { BasePart }, pos: Vector3, s: number?)
		local k = s or 0.2
		table.insert(list, piece("Part", Vector3.new(k, k, 0.1), CFrame.new(pos) * CFrame.Angles(0, 0, rad(45)), NAIL))
	end

	-- the canyon rock
	facetUnion(m, "PillarL", Gates.CANYON_FACETS.pillar_L)
	task.wait()
	facetUnion(m, "PillarR", Gates.CANYON_FACETS.pillar_R)
	task.wait()
	facetUnion(m, "RockL", Gates.CANYON_FACETS.side_rock_L)
	facetUnion(m, "RockR", Gates.CANYON_FACETS.side_rock_R)
	task.wait()

	local U, add = lists()
	-- the beam (today's 30 x 1.8 x 1.8 at y 21.1, turned 1.5 degrees): an adzed timber, grain lines, 4 iron bands
	local beamCF = CFrame.new(0, 21.1, 0) * CFrame.Angles(0, 0, rad(1.5))
	add("Beam", H.timber(Vector3.new(30, 1.8, 1.8), beamCF, C.DarkWood, 0.2))
	for i = 1, 7 do
		local x = rng:NextNumber(-12, 12)
		add("Beam", piece("Part", Vector3.new(rng:NextNumber(2.5, 6), 0.06, 0.04), beamCF * CFrame.new(x, rng:NextNumber(-0.6, 0.6), -0.915), scaled(C.DarkWood, 0.75)))
	end
	for _, x in ipairs({ -11.6, -7.2, 7.2, 11.6 }) do
		add("Beam", piece("Part", Vector3.new(0.4, 1.94, 1.94), beamCF * CFrame.new(x, 0, 0), IRON))
		for _, y in ipairs({ -0.5, 0.5 }) do
			add("Beam", piece("Part", Vector3.new(0.18, 0.18, 0.18), beamCF * CFrame.new(x, y, -0.98) * CFrame.Angles(rad(45), rad(45), 0), NAIL))
		end
	end
	-- today's 2 ropes: twisted ropes lashed round the beam, down to the top of the barricade
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 5
		local c = beamCF * CFrame.new(x, 0, 0)
		U.Ropes = U.Ropes or {}
		ring(U.Ropes, c.Position, UP, Vector3.zAxis, 1.08, 0.3, 10, C.Rope)
		ring(U.Ropes, c.Position + Vector3.new(0.35, 0, 0), UP, Vector3.zAxis, 1.08, 0.3, 10, scaled(C.Rope, 0.9))
		rope(U.Ropes, Vector3.new(x, c.Position.Y - 0.9, -0.6), Vector3.new(x + sx * 0.15, 15.0, -0.6), 0.34, C.Rope)
		rope(U.Ropes, Vector3.new(x + 0.3, c.Position.Y - 0.9, -0.6), Vector3.new(x + 0.3 + sx * 0.15, 15.0, -0.6), 0.3, scaled(C.Rope, 0.92))
	end
	-- the sign board (today's SignBack 13 x 5 x 0.5): 3 nailed planks behind today's PriceSign
	for i = 0, 2 do
		local y = 16.73 + i * 1.67
		local len = 13 + rng:NextNumber(-0.3, 0.3)
		local off = rng:NextNumber(-0.15, 0.15)
		add("SignBoard", H.timber(Vector3.new(len, 1.62, 0.5), CFrame.new(off, y, -1.15) * CFrame.Angles(0, 0, rad(rng:NextNumber(-0.6, 0.6))), scaled(C.DarkWood, ({ 1, 0.9, 1.06 })[i + 1]), 0.1))
		for _, sx in ipairs({ -1, 1 }) do
			for _, dy in ipairs({ -0.4, 0.4 }) do
				nail(U.SignBoard, Vector3.new(off + sx * 6.25, y + dy, -1.43), 0.18)
			end
		end
	end
	-- a small hanging warning plank with a red X, on 2 short ropes from the beam
	do
		local cf = CFrame.new(-9.4, 17.8, -1.2) * CFrame.Angles(0, 0, rad(5))
		add("HangingSign", H.timber(Vector3.new(3.4, 1.1, 0.25), cf, PLANK_A, 0.08))
		for _, a in ipairs({ 24, -24 }) do
			add("HangingSign", piece("Part", Vector3.new(2.3, 0.2, 0.03), cf * CFrame.new(0, 0, -0.14) * CFrame.Angles(0, 0, rad(a)), C.Red))
		end
		for _, dx in ipairs({ -1.3, 1.3 }) do
			local top = (cf * CFrame.new(dx, 0.5, 0)).Position
			local beamY = 21.1 + math.tan(rad(1.5)) * top.X - 0.9
			rope(U.HangingSign, Vector3.new(top.X, beamY, -1.2), top, 0.16, C.Rope)
			nail(U.HangingSign, (cf * CFrame.new(dx, 0.32, -0.14)).Position, 0.16)
		end
	end
	-- today's 6 anchors (1.4 cubes at x +-12.6) as iron eye bolts on plates against the rock faces
	for _, sx in ipairs({ -1, 1 }) do
		for _, y in ipairs({ 4.8, 10.3, 14.8 }) do
			add("Anchors", chamfered(Vector3.new(0.22, 1.5, 1.5), CFrame.new(sx * 12.95, y, 0), IRON, { "vertical" }, 0.1))
			for _, dy in ipairs({ -0.5, 0.5 }) do
				for _, dz in ipairs({ -0.5, 0.5 }) do
					add("Anchors", piece("Part", Vector3.new(0.16, 0.16, 0.16), CFrame.new(sx * 12.82, y + dy, dz) * CFrame.Angles(rad(45), rad(45), 0), NAIL))
				end
			end
			add("Anchors", cyl(Vector3.new(sx * 12.85, y, 0), Vector3.new(sx * 12.35, y, 0), 0.26, IRON))
			ring(U.Anchors, Vector3.new(sx * 12.05, y, 0), Vector3.xAxis, UP, 0.32, 0.13, 8, IRON)
		end
	end
	-- rubble, broken plank ends, small rocks at the feet of the rocks; sand drifts (never in the opening)
	local ROCK = { rgb(197, 84, 56), rgb(156, 64, 50), rgb(228, 128, 80), rgb(190, 81, 54) }
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			for i = 1, 4 do
				local s = rng:NextNumber(0.8, 1.8)
				local pos = Vector3.new(sx * rng:NextNumber(14.5, 27), s * 0.32, sz * rng:NextNumber(9.0, 10.2))
				add("Rubble", chamfered(Vector3.new(s, s * 0.7, s * rng:NextNumber(0.7, 1.1)), CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)), ROCK[rng:NextInteger(1, 4)], { "vertical", "topFrontBack", "topSides" }, s * 0.18))
			end
			for i = 1, 6 do
				local s = rng:NextNumber(0.3, 0.6)
				local pos = Vector3.new(sx * rng:NextNumber(14, 42), s * 0.35, sz * rng:NextNumber(9.2, 11))
				add("Rubble", piece("Part", Vector3.new(s, s * 0.7, s), CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.28), rng:NextNumber(-0.5, 0.5)), scaled(ROCK[rng:NextInteger(1, 4)], 0.95)))
			end
			add("Sand", piece("WedgePart", Vector3.new(13, 0.8, 1.6), CFrame.new(sx * 20.6, 0.4, sz * 9.25) * (if sz < 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0)), SAND))
			add("Sand", piece("Part", Vector3.new(12.2, 0.6, 0.6), CFrame.new(sx * 20.6, 0.42, sz * 8.6), SAND, { shape = Enum.PartType.Cylinder }))
			local rz = if sz < 0 then -6.1 else 9.1
			add("Sand", piece("WedgePart", Vector3.new(13.5, 0.7, 1.4), CFrame.new(sx * 36, 0.35, rz) * (if sz < 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0)), SAND))
		end
		-- broken plank ends lying against the pillar front
		for i = 1, 2 do
			local pos = Vector3.new(sx * rng:NextNumber(16, 24), 0.15, -rng:NextNumber(9.4, 10.6))
			add("Rubble", H.timber(Vector3.new(rng:NextNumber(1.6, 2.6), 0.25, 0.7), CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rad(rng:NextNumber(-8, 8))), if i == 1 then PLANK_A else PLANK_B, 0.05))
		end
	end

	-- today's colliding boxes as separate invisible parts (one union's convex decomposition would bridge the notches
	-- between the rotated rock boxes)
	for _, e in ipairs(D.ENVELOPES.canyon_barricade) do
		local p = piece("Part", Vector3.new(e[2], e[3], e[4]), CFrame.new(table.unpack(e[5])), rgb(197, 84, 56))
		p.Name = "Collision"
		p.Transparency = 1
		p.CanCollide = true
		p.CanQuery = true
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = m
	end
	local names = {}
	for name in pairs(U) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		merge(m, name, U[name], { query = name == "Beam" or name == "SignBoard" })
		task.wait()
	end

	-- the Barrier exactly as today (invisible, colliding) and the barricade under it
	local barrier = exact(m, { "Barrier", 24, 16, 2, 0, 8, 0, "5c626e" }, { collide = true, query = true, touch = true, shadow = false, transparency = 1 })
	barrier:SetAttribute("BarrierDecorIsChildOfBarrier", true)
	local B = { Planks = {}, Crosses = {}, Straps = {}, Lock = {}, Keyhole = {} }
	-- today's 5 planks (x, turn, colour)
	for _, p in ipairs({ { -9.6, -0.25, PLANK_A }, { -4.8, 0.42, PLANK_B }, { 0, 1.5, PLANK_A }, { 4.8, -0.27, PLANK_B }, { 9.6, -1.08, PLANK_A } }) do
		local cf = CFrame.new(p[1], 7.8, 0.3) * CFrame.Angles(0, 0, rad(p[2]))
		local corner = if rng:NextNumber() < 0.5 then -1 else 1
		local chip = piece("Part", Vector3.new(1.3, 1.3, 2), cf * CFrame.new(corner * 1.78, 7.6, 0) * CFrame.Angles(0, 0, rad(38)), p[3])
		table.insert(B.Planks, chamfered(Vector3.new(3.5, 15, 0.9), cf, p[3], { "vertical" }, 0.12, { chip }))
		for i = 1, 3 do
			local gx = rng:NextNumber(-1.35, 1.35)
			local len = rng:NextNumber(3.5, 9)
			table.insert(B.Planks, piece("Part", Vector3.new(0.06, len, 0.03), cf * CFrame.new(gx, rng:NextNumber(-7 + len / 2, 6.5 - len / 2), -0.46), scaled(p[3], 0.74)))
		end
		table.insert(B.Planks, piece("Part", Vector3.new(0.04, 0.38, 0.38), cf * CFrame.new(rng:NextNumber(-1, 1), rng:NextNumber(-5, 5), -0.46) * CFrame.Angles(0, rad(90), 0), scaled(p[3], 0.6), { shape = Enum.PartType.Cylinder }))
	end
	for _, y in ipairs({ 3.2, 12.6 }) do
		table.insert(B.Planks, H.timber(Vector3.new(23.4, 0.9, 0.35), CFrame.new(0, y, 0.93), scaled(PLANK_B, 0.95), 0.08))
	end
	-- today's 2 cross boards (26 x 2.2 x 0.7 turned +-27 degrees), nailed at every plank
	for ci, c in ipairs({ { 27, -0.6 }, { -27, -0.95 } }) do
		local cf = CFrame.new(0, 8, c[2]) * CFrame.Angles(0, 0, rad(c[1]))
		table.insert(B.Crosses, H.timber(Vector3.new(26, 2.2, 0.7), cf, scaled(CROSS, if ci == 1 then 0.94 else 1), 0.14))
		for i = 1, 3 do
			table.insert(B.Crosses, piece("Part", Vector3.new(rng:NextNumber(5, 10), 0.06, 0.03), cf * CFrame.new(rng:NextNumber(-7, 7), rng:NextNumber(-0.7, 0.7), -0.36), scaled(CROSS, 0.72)))
		end
		for _, xp in ipairs({ -9.6, -4.8, 0, 4.8, 9.6 }) do
			if not (ci == 1 and xp == 0) then
				local u = xp / math.cos(rad(c[1]))
				for _, dv in ipairs({ -0.5, 0.5 }) do
					nail(B.Crosses, (cf * CFrame.new(u, dv, -0.38)).Position)
				end
			end
		end
	end
	-- today's 6 chains as riveted iron straps (same places and turns), hasp plates in the middle
	for _, s in ipairs({ { -6, 4.1, -3.5 }, { -6, 9.6, -3.5 }, { -6, 14.1, -3.5 }, { 6, 4.1, 3.5 }, { 6, 9.6, 3.5 }, { 6, 14.1, 3.5 } }) do
		local cf = CFrame.new(s[1], s[2], -1.42) * CFrame.Angles(0, 0, rad(s[3]))
		table.insert(B.Straps, chamfered(Vector3.new(12.3, 0.7, 0.2), cf, scaled(IRON, if s[2] == 9.6 then 0.92 else 1), { "frontFace" }, 0.05))
		for i = -5, 5 do
			table.insert(B.Straps, piece("Part", Vector3.new(0.17, 0.17, 0.17), cf * CFrame.new(i * 1.1, 0, -0.1) * CFrame.Angles(rad(45), rad(45), 0), NAIL))
		end
	end
	for _, y in ipairs({ 4.1, 14.1 }) do
		table.insert(B.Straps, chamfered(Vector3.new(1.4, 1.2, 0.22), CFrame.new(0, y, -1.55), scaled(IRON, 0.85), { "frontFace" }, 0.06))
		for _, dx in ipairs({ -0.45, 0.45 }) do
			for _, dy in ipairs({ -0.35, 0.35 }) do
				table.insert(B.Straps, piece("Part", Vector3.new(0.16, 0.16, 0.16), CFrame.new(dx, y + dy, -1.67) * CFrame.Angles(rad(45), rad(45), 0), NAIL))
			end
		end
	end
	-- the lock: today's plate (2.4 x 2.8 at y 9.8) with 4 rivets, a padlock and its shackle; the gold keyhole escutcheon
	table.insert(B.Lock, chamfered(Vector3.new(2.5, 2.9, 0.24), CFrame.new(0, 9.8, -1.6), scaled(IRON, 0.8), { "frontFace" }, 0.1))
	for _, dx in ipairs({ -1.0, 1.0 }) do
		for _, dy in ipairs({ -1.2, 1.2 }) do
			table.insert(B.Lock, piece("Part", Vector3.new(0.2, 0.2, 0.2), CFrame.new(dx, 9.8 + dy, -1.73) * CFrame.Angles(rad(45), rad(45), 0), NAIL))
		end
	end
	table.insert(B.Lock, chamfered(Vector3.new(1.7, 1.5, 0.6), CFrame.new(0, 9.3, -1.98), IRON, { "vertical", "frontFace" }, 0.14))
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(B.Lock, cyl(Vector3.new(sx * 0.5, 9.95, -1.98), Vector3.new(sx * 0.5, 10.75, -1.98), 0.22, scaled(IRON, 1.15)))
	end
	table.insert(B.Lock, cyl(Vector3.new(-0.61, 10.8, -1.98), Vector3.new(0.61, 10.8, -1.98), 0.22, scaled(IRON, 1.15)))
	table.insert(B.Keyhole, piece("Part", Vector3.new(0.12, 0.9, 0.9), CFrame.new(0, 9.5, -2.33) * CFrame.Angles(0, rad(90), 0), C.Gold, { shape = Enum.PartType.Cylinder }))
	table.insert(B.Keyhole, piece("Part", Vector3.new(0.04, 0.3, 0.3), CFrame.new(0, 9.6, -2.4) * CFrame.Angles(0, rad(90), 0), SLOT, { shape = Enum.PartType.Cylinder }))
	table.insert(B.Keyhole, piece("Part", Vector3.new(0.14, 0.36, 0.04), CFrame.new(0, 9.36, -2.4), SLOT))
	for _, name in ipairs({ "Crosses", "Keyhole", "Lock", "Planks", "Straps" }) do
		local u = merge(m, name, B[name], {})
		u.Parent = barrier
		task.wait()
	end

	-- today's PriceSign, exactly
	exact(m, { "PriceSign", 12, 4, 0.5, 0, 18.4, -1.5, "d6965c" }, { collide = true, query = true, touch = true })

	m.PrimaryPart = barrier
	barrier.PivotOffset = barrier.CFrame:Inverse()
	m:SetAttribute("MapPropId", "canyon_barricade")
	H.setBevelSelf(false)
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into PropsDesert's fresh PropsBatch2 table; its install() builds them
---------------------------------------------------------------------
Gates.BUILDERS = { pylon_temple_gate = true, canyon_barricade = true }
for id in pairs(Gates.BUILDERS) do
	B2[id] = (Gates :: any)[id]
	B2.BUILDERS[id] = true
end
Gates.install = B2.install
Gates.stats = B2.stats
Gates.ENVELOPES = D.ENVELOPES -- for the collision checks

return Gates
