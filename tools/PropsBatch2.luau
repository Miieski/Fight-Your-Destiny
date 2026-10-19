--[[
	PropsBatch2 (dev tool, Edit mode only) - the owner's "PROPS BATCH 2" (2026-10-19): 16 objects of the prop test
	zone rebuilt to fountain / well quality (docs/prop_texture_guide.md section A, Agent A's recipe) from Parts merged
	with GeometryService into a few unions per colour / material group (each union = one part of the hub budget).
	Source of truth: tools/PropsBatch2.luau. Inventory: docs/prop_inventory.md "Props batch 2".

	Usage (execute_luau, Edit):
		local B2 = require(game.ServerStorage.DevTools.PropsBatch2:Clone())
		print(B2.install("portal_frame"))   -- (re)builds ServerStorage.MapProps.portal_frame (old one -> _Previous)
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "portal_frame" } }), Sync.run({ only = { "portal_frame" } }))

	Shared rules of every builder:
	- template at the origin: pivot = bottom centre on Y 0, front = -Z, the old kit model's footprint (+10 % max);
	- stone blocks: running bond, joints 0.08-0.10 (vertical) / 0.05 (horizontal) over a dark mortar core, chamfers
	  (CSG: the block minus negative wedges), face jitter 0 / 0.04 / 0.07, tones x1 / x0.93 / x0.86 never repeated on
	  a neighbour, caps one step darker with an overhang, moss only at the base;
	- gradient: Color = palette x tone x (0.82 + 0.18 x smoothstep(h / H)), h = the piece's centre height (A9);
	- each union keeps the colours of its pieces (UsePartColor false) unless it is one-colour by design (gems:
	  UsePartColor true, so a _Variants recolour or the PortalController black filter can set its Color);
	- union attribute MergeHash = a hash of its pieces (SyncMapProps' fingerprint reads attributes: a change inside a
	  union updates the copies).
]]
local GeometryService = game:GetService("GeometryService")
local ServerStorage = game:GetService("ServerStorage")

local PropsBatch2 = {}

local rgb = Color3.fromRGB

-- palette (docs/prop_texture_guide.md A1)
local P = {
	StoneLight = rgb(163, 170, 183), Stone = rgb(150, 156, 168), StoneDark = rgb(104, 110, 124), Mortar = rgb(84, 88, 100),
	WoodLight = rgb(214, 150, 92), WoodMid = rgb(168, 98, 56), WoodDark = rgb(112, 62, 38),
	Iron = rgb(92, 98, 110), IronWorn = rgb(122, 128, 140), Gold = rgb(255, 201, 60), Brass = rgb(201, 154, 46),
	Moss = rgb(104, 168, 72), MossDark = rgb(74, 138, 60),
}
PropsBatch2.PALETTE = P
local TONES = { 1, 0.93, 0.86 }

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------
local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function scaled(c: Color3, f: number): Color3
	return Color3.new(math.min(c.R * f, 1), math.min(c.G * f, 1), math.min(c.B * f, 1))
end

-- the A9 gradient of a piece whose centre is h studs high in an object H tall
local function graded(c: Color3, h: number, H: number, tone: number?): Color3
	return scaled(c, (tone or 1) * (0.82 + 0.18 * smoothstep(h / H)))
end

-- a tone step different from `previous` (index into TONES)
local function toneIndex(rng: Random, previous: number?): number
	local i = rng:NextInteger(1, #TONES)
	if i == previous then
		i = i % #TONES + 1
	end
	return i
end

-- an unparented piece
local function piece(className: string, size: Vector3, cf: CFrame, color: Color3, opts: any?): BasePart
	local p = Instance.new(className) :: BasePart
	if opts and opts.shape and p:IsA("Part") then
		p.Shape = opts.shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if opts and opts.material then opts.material else Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end
PropsBatch2.piece = piece

-- negative wedges for chamfers. A WedgePart's solid triangle has its right angle at one of the 4 corners of its local
-- (y, z) square depending on its turn about its own X axis; the table (measured with GetPartsInPart in Studio) gives
-- the turn that puts the solid corner at (a, b). PRE turns the wedge's X axis onto the edge's axis.
local ANG = {
	X = { ["-1,-1"] = 90, ["-1,1"] = 0, ["1,-1"] = 180, ["1,1"] = 270 }, -- corner (y, z)
	Y = { ["-1,-1"] = 180, ["-1,1"] = 270, ["1,-1"] = 90, ["1,1"] = 0 }, -- corner (x, z)
	Z = { ["-1,-1"] = 0, ["-1,1"] = 270, ["1,-1"] = 90, ["1,1"] = 180 }, -- corner (x, y)
}
local PRE = { X = CFrame.identity, Y = CFrame.Angles(0, 0, math.rad(90)), Z = CFrame.Angles(0, math.rad(-90), 0) }

local function negWedge(blockCF: CFrame, size: Vector3, axis: string, a: number, b: number, c: number): BasePart
	local L, H, D = size.X, size.Y, size.Z
	local offset, len
	if axis == "X" then
		offset, len = Vector3.new(0, a * (H / 2 - c / 2), b * (D / 2 - c / 2)), L
	elseif axis == "Y" then
		offset, len = Vector3.new(a * (L / 2 - c / 2), 0, b * (D / 2 - c / 2)), H
	else
		offset, len = Vector3.new(a * (L / 2 - c / 2), b * (H / 2 - c / 2), 0), D
	end
	local w = Instance.new("WedgePart")
	w.Size = Vector3.new(len + 0.2, c, c)
	w.Anchored = true
	w.CFrame = blockCF * CFrame.new(offset) * PRE[axis] * CFrame.Angles(math.rad(ANG[axis][a .. "," .. b]), 0, 0)
	return w
end

-- edge sets (axis, a, b) in the block's own frame
local EDGES = {
	vertical = { { "Y", 1, 1 }, { "Y", 1, -1 }, { "Y", -1, 1 }, { "Y", -1, -1 } },
	topFrontBack = { { "X", 1, 1 }, { "X", 1, -1 } },
	bottomFrontBack = { { "X", -1, 1 }, { "X", -1, -1 } },
	topSides = { { "Z", 1, 1 }, { "Z", -1, 1 } },
	bottomSides = { { "Z", 1, -1 }, { "Z", -1, -1 } },
	frontFace = { { "X", 1, -1 }, { "X", -1, -1 }, { "Y", 1, -1 }, { "Y", -1, -1 } },
}
PropsBatch2.EDGES = EDGES

-- a block (L x H x D at cf) with the listed edge sets chamfered by c (CSG subtract); extra = more negative parts
local function chamfered(size: Vector3, cf: CFrame, color: Color3, sets: { string }, c: number, extra: { BasePart }?): BasePart
	local block = piece("Part", size, cf, color)
	local negs = {}
	for _, name in ipairs(sets) do
		for _, e in ipairs(EDGES[name]) do
			table.insert(negs, negWedge(cf, size, e[1], e[2], e[3], c))
		end
	end
	for _, x in ipairs(extra or {}) do
		table.insert(negs, x)
	end
	if #negs == 0 then
		return block
	end
	-- CSG can return a degenerate sliver for some orders of the negative parts (seen on the arch voussoirs): a result
	-- that lost most of the block along an axis is thrown away and the subtraction retried with the order reversed
	local function attempt(list: { BasePart }): (BasePart?, any)
		local ok, result = pcall(function()
			return GeometryService:SubtractAsync(block, list, { CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Automatic })
		end)
		if not ok or not result or not result[1] then
			return nil, result
		end
		local r = result[1] :: BasePart
		local s = r.Size
		if s.X < size.X * 0.3 or s.Y < size.Y * 0.3 or s.Z < size.Z * 0.3 then
			r:Destroy()
			return nil, "degenerate result " .. tostring(s)
		end
		return r, nil
	end
	local r, err = attempt(negs)
	if not r then
		local reversed = {}
		for k = #negs, 1, -1 do
			table.insert(reversed, negs[k])
		end
		r, err = attempt(reversed)
	end
	for _, n in ipairs(negs) do
		n:Destroy()
	end
	if not r then
		warn("PropsBatch2: chamfer failed, plain block kept: " .. tostring(err))
		return block
	end
	block:Destroy()
	r.Color = color
	r.Anchored = true
	return r
end
PropsBatch2.chamfered = chamfered

-- a hash of pieces for MergeHash (class, size, place, turn, colour)
local function hashOf(pieces: { BasePart }): string
	local h1, h2 = 5381, 52711
	for _, p in ipairs(pieces) do
		local rx, ry, rz = p.CFrame:ToOrientation()
		local line = string.format("%s|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%.4f,%.4f,%.4f|%d,%d,%d;", p.ClassName, p.Size.X, p.Size.Y, p.Size.Z, p.Position.X, p.Position.Y, p.Position.Z, rx, ry, rz, math.round(p.Color.R * 255), math.round(p.Color.G * 255), math.round(p.Color.B * 255))
		for i = 1, #line do
			local b = string.byte(line, i)
			h1 = (h1 * 33 + b) % 4294967296
			h2 = (h2 * 31 + b * 7) % 4294967291
		end
	end
	return string.format("%08x", bit32.bxor(h1, h2))
end

-- the pieces merged into ONE UnionOperation `name` in `model`.
-- opts: collide (default false), fidelity (Enum.CollisionFidelity, default Box), shadow (default true), single (Color3:
-- a one-colour union, UsePartColor true), material, transparency
local function merge(model: Model, name: string, pieces: { BasePart }, opts: any?): BasePart
	opts = opts or {}
	local hash = hashOf(pieces)
	local result: BasePart
	if #pieces == 1 then
		result = pieces[1]
	else
		-- a tiny axis-aligned first piece buried in the first real one: the union takes the frame of its first piece,
		-- so its Size / bounding box / Box collision stay axis-aligned in the template
		local first = piece("Part", Vector3.new(0.05, 0.05, 0.05), CFrame.new(pieces[1].Position), pieces[1].Color)
		local ok, out = pcall(function()
			return GeometryService:UnionAsync(first, pieces, {
				CollisionFidelity = opts.fidelity or Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Automatic,
				SplitApart = false,
			})
		end)
		assert(ok and out and out[1], `PropsBatch2: union {name} failed: {out}`)
		first:Destroy()
		for _, p in ipairs(pieces) do
			p:Destroy()
		end
		result = out[1]
	end
	result.Name = name
	result:SetAttribute("MergeHash", hash)
	if result:IsA("PartOperation") then
		result.UsePartColor = opts.single ~= nil
		pcall(function()
			(result :: any).CollisionFidelity = opts.fidelity or Enum.CollisionFidelity.Box
		end)
	end
	if opts.single then
		result.Color = opts.single
	end
	if opts.material then
		result.Material = opts.material
	end
	if opts.transparency then
		result.Transparency = opts.transparency
	end
	result.Anchored = true
	result.CanCollide = opts.collide == true
	result.CanQuery = opts.collide == true or opts.query == true
	result.CanTouch = false
	result.CastShadow = opts.shadow ~= false
	result.Parent = model
	return result
end
PropsBatch2.merge = merge

-- a plain part placed in the model (functional or kept parts: NamePlate, Interact ...)
local function plain(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, opts: any?): Part
	local p = piece("Part", size, cf, color, opts) :: Part
	p.Name = name
	p.CanCollide = opts ~= nil and opts.collide == true
	p.CanQuery = opts ~= nil and (opts.collide == true or opts.query == true)
	p.CanTouch = false
	p.CastShadow = opts == nil or opts.shadow ~= false
	p.Parent = model
	return p
end

-- a faceted gem (Neon, front -Z of `cf`, `s` = its width) and its gold setting, into the two piece lists
local function gem(gems: { BasePart }, settings: { BasePart }, cf: CFrame, s: number)
	local d45 = CFrame.Angles(0, 0, math.rad(45))
	local k = s / math.sqrt(2) -- side of the rotated square whose diagonal is s
	table.insert(gems, piece("Part", Vector3.new(k, k, 0.3 * s), cf * CFrame.new(0, 0, -0.15 * s) * d45, P.Gold, { material = Enum.Material.Neon }))
	table.insert(gems, piece("Part", Vector3.new(k * 0.62, k * 0.62, 0.22 * s), cf * CFrame.new(0, 0, -0.41 * s) * d45, P.Gold, { material = Enum.Material.Neon }))
	table.insert(gems, piece("Part", Vector3.new(k * 0.34, k * 0.34, 0.12 * s), cf * CFrame.new(0, 0, -0.58 * s) * d45, P.Gold, { material = Enum.Material.Neon }))
	-- setting: brass back plate, a gold diamond frame, 4 gold prongs on the tips
	table.insert(settings, piece("Part", Vector3.new(k * 1.45, k * 1.45, 0.1), cf * CFrame.new(0, 0, -0.05) * d45, P.Brass))
	local r = s / 2 + 0.1
	for i = 0, 3 do
		local a = math.rad(45 + 90 * i)
		local mid = Vector3.new(math.cos(a), math.sin(a), 0) * (r * 0.72)
		table.insert(settings, piece("Part", Vector3.new(k * 1.12, 0.13, 0.2), cf * CFrame.new(mid.X, mid.Y, -0.15) * CFrame.Angles(0, 0, a + math.rad(90)), P.Gold))
		local tip = Vector3.new(math.cos(math.rad(90 * i)), math.sin(math.rad(90 * i)), 0) * (s / 2 + 0.02)
		table.insert(settings, piece("Part", Vector3.new(0.17, 0.17, 0.17), cf * CFrame.new(tip.X, tip.Y, -0.3 * s) * CFrame.Angles(math.rad(45), math.rad(45), 0), P.Gold)) -- prong
	end
end
PropsBatch2.gem = gem

-- a squashed moss cushion (Ball) half sunk at height y, along `dir` (radians about Y)
local function moss(list: { BasePart }, rng: Random, pos: Vector3, yaw: number, len: number)
	local col = if rng:NextNumber() < 0.5 then P.Moss else P.MossDark
	local tone = rng:NextNumber(0.78, 0.92)
	-- a low pad (all top edges chamfered) with a smaller cushion on it, sunk a little into what carries it
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	table.insert(list, chamfered(Vector3.new(len, 0.28, len * 0.36), cf * CFrame.new(0, 0.05, 0), scaled(col, tone), { "topFrontBack", "topSides" }, 0.12))
	table.insert(list, chamfered(Vector3.new(len * 0.55, 0.16, len * 0.2), cf * CFrame.new(rng:NextNumber(-0.15, 0.15) * len, 0.18, 0), scaled(col, tone * 1.06), { "topFrontBack", "topSides" }, 0.07))
end

---------------------------------------------------------------------
-- 02 PORTAL FRAME (kit Hub.PortalFrame, 19.5 x 22.9 x 7.0; the hub's 12 PortalFrame_<Zone>). Stepped block base,
-- two pillars of bevelled stone courses on carved plinths with capitals, a semicircular arch of 9 voussoirs with a
-- keystone, glowing gem settings (the old yellow diamonds) on both pillars and in the keystone, the name plate hung
-- from the arch on iron rods in a wooden frame with iron corner plates, moss at the base. The opening stays 12 wide
-- (pillar inner faces at x +-6) from the threshold (y 1) to the capitals (y 17): the glowing field of the game
-- (Hub.Portals.Portal_<Zone>, a separate part) and the test frame's own "Surface" fill it as before.
-- Parts: Steps, PillarL, PillarR, Arch, Keystone, Moss, Gem, GemSetting, NamePlate, NamePlateFrame (10).
-- Gem and Keystone are one colour each (UsePartColor true): the _Variants (one per zone) recolour them to the zone
-- colour (the old Accent / Keystone colour of each hub frame); gold in the test zone, as the old ones.
---------------------------------------------------------------------
PropsBatch2.PORTAL_ZONE_COLORS = {
	Plains = rgb(88, 204, 52), Desert = rgb(244, 208, 124), Jungle = rgb(40, 150, 66), Tundra = rgb(150, 214, 250),
	Swamp = rgb(170, 80, 255), Volcano = rgb(255, 120, 30), Hell = rgb(200, 36, 40), Heaven = rgb(255, 208, 84),
	Dead = rgb(120, 255, 190), Abyss = rgb(60, 255, 250), Mechanical = rgb(255, 140, 40), Void = rgb(255, 60, 220),
}

function PropsBatch2.portal_frame(): Model
	local m = Instance.new("Model")
	m.Name = "portal_frame"
	local rng = Random.new(20261019)
	local H = 25 -- object height for the gradient
	local stones: { BasePart } = {}

	-- 1. base: lower step (6 slabs) and the threshold (5 slabs) over mortar, chamfered top edges
	local steps: { BasePart } = {}
	local function slabRow(width: number, depth: number, y0: number, h: number, count: number, color: Color3)
		local lens, total = {}, 0
		for i = 1, count do
			lens[i] = rng:NextNumber(0.8, 1.2)
			total += lens[i]
		end
		local gap = 0.1
		local x = -width / 2
		local prev = nil
		for i = 1, count do
			local len = lens[i] / total * (width - gap * (count - 1))
			local ti = toneIndex(rng, prev)
			prev = ti
			local cf = CFrame.new(x + len / 2, y0 + h / 2, 0)
			table.insert(steps, chamfered(Vector3.new(len, h - 0.02, depth), cf, graded(color, y0 + h / 2, H, TONES[ti]), { "topFrontBack", "topSides" }, 0.14))
			x += len + gap
		end
		table.insert(steps, piece("Part", Vector3.new(width - 0.3, h - 0.1, depth - 0.3), CFrame.new(0, y0 + (h - 0.1) / 2, 0), P.Mortar))
	end
	slabRow(20.4, 7.6, 0, 0.5, 6, scaled(P.StoneDark, 0.93))
	slabRow(18.8, 6.4, 0.5, 0.5, 5, P.StoneDark)
	local stepsUnion = merge(m, "Steps", steps, { collide = true, fidelity = Enum.CollisionFidelity.Box })

	-- 2. pillars
	local gems, settings, mossList = {}, {}, {}
	for _, side in ipairs({ -1, 1 }) do
		local x0 = 7.5 * side
		local list: { BasePart } = {}
		-- plinth: 2 courses (the lower one wider), top edges chamfered
		table.insert(list, chamfered(Vector3.new(4.4, 0.95, 5.6), CFrame.new(x0 + 0.1 * side, 1.0 + 0.475, 0), graded(P.StoneDark, 1.5, H, 0.93), { "topFrontBack", "topSides" }, 0.18))
		table.insert(list, chamfered(Vector3.new(4.0, 0.95, 5.2), CFrame.new(x0 + 0.1 * side, 2.05 + 0.475, 0), graded(P.StoneDark, 2.5, H, 1), { "topFrontBack", "topSides" }, 0.18))
		-- shaft: 10 courses of 1.26 (blocks 1.21 + 0.05 joints), every other course split in two
		table.insert(list, piece("Part", Vector3.new(2.6, 12.6, 3.8), CFrame.new(x0, 3.0 + 6.3, 0), P.Mortar))
		local prev = nil
		for i = 0, 9 do
			local y = 3.0 + 0.025 + i * 1.26 + 0.605
			local jitter = ({ 0, 0.04, 0.07 })[rng:NextInteger(1, 3)]
			local depth = 4.2 + jitter * 2
			if i % 2 == 0 then
				local ti = toneIndex(rng, prev)
				prev = ti
				table.insert(list, chamfered(Vector3.new(3.0, 1.21, depth), CFrame.new(x0, y, 0), graded(P.Stone, y, H, TONES[ti]), { "vertical", "topFrontBack" }, 0.18))
			else
				-- two blocks side by side (outer one 1.7, inner one 1.21) with a 0.09 joint
				local outerW, innerW = 1.7, 1.21
				local ti1 = toneIndex(rng, prev)
				local ti2 = toneIndex(rng, ti1)
				prev = ti2
				local inner = x0 - side * (1.5 - innerW / 2)
				local outer = x0 + side * (1.5 - outerW / 2)
				table.insert(list, chamfered(Vector3.new(innerW, 1.21, depth), CFrame.new(inner, y, 0), graded(P.Stone, y, H, TONES[ti1]), { "vertical", "topFrontBack" }, 0.16))
				table.insert(list, chamfered(Vector3.new(outerW, 1.21, depth), CFrame.new(outer, y, 0), graded(P.Stone, y, H, TONES[ti2]), { "vertical", "topFrontBack" }, 0.16))
			end
		end
		-- capital: a carved band and the cushioned cap slab (one step darker)
		table.insert(list, piece("Part", Vector3.new(3.4, 0.36, 4.6), CFrame.new(x0, 15.6 + 0.18, 0), graded(P.StoneDark, 15.8, H, 1)))
		table.insert(list, chamfered(Vector3.new(4.0, 1.04, 5.2), CFrame.new(x0 + 0.1 * side, 15.96 + 0.52, 0), graded(P.StoneDark, 16.5, H, 1), { "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.2))
		merge(m, if side < 0 then "PillarL" else "PillarR", list, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
		-- the gem setting on the front face (z -2.1), where the old yellow diamond was
		gem(gems, settings, CFrame.new(x0, 10.0, -2.1 - 0.04), 1.05)
		-- moss at the plinth foot, on the threshold (front, and one at the back)
		moss(mossList, rng, Vector3.new(x0 + side * rng:NextNumber(0.4, 1.4), 1.02, -2.95), rng:NextNumber(-0.2, 0.2), rng:NextNumber(1.6, 2.1))
		moss(mossList, rng, Vector3.new(x0 - side * rng:NextNumber(0.6, 1.2), 1.02, 2.95), rng:NextNumber(-0.2, 0.2), rng:NextNumber(1.4, 1.8))
		moss(mossList, rng, Vector3.new(side * 9.75, 0.52, rng:NextNumber(-1.8, 1.8)), math.rad(90), rng:NextNumber(1.3, 1.7)) -- lower step, against the threshold end
	end

	-- 3. arch: a segmental arch springing from the capitals (y 17) at the opening's edges (x +-6) with its inner apex at
	-- y 20.6 (centre (0, 13.8), radii 6.8 - 8.5), 7 voussoirs with radial joints; the two springers sit on the caps
	-- with a horizontal bed. Its keystone stays under y 22.6, so the portal's floating name (the BillboardGui of
	-- Hub.Portals.Portal_<Zone>, 15 studs over its centre) stays visible above it as before.
	local cy, ri, ro, D = 13.8, 6.8, 8.5, 4.4
	local springY = 17.0
	local half = math.asin(6.0 / ri) -- half the arch's angle, from the vertical
	local arch: { BasePart } = {}
	local keystone: BasePart? = nil
	local n = 7
	local step = 2 * half / n
	local aStart = math.pi / 2 + half
	local rm0 = (ri + ro) / 2
	local prev = nil
	for i = 0, n - 1 do
		local key = i == (n - 1) / 2
		local springer = i == 0 or i == n - 1
		local a1, a2 = aStart - i * step, aStart - (i + 1) * step -- left to right
		local am = (a1 + a2) / 2
		local rOut = if key then ro + 0.3 else ro
		local depth = if key then D + 0.5 else D
		local rm = (ri + rOut) / 2
		local h = rOut * math.cos(step / 2) - ri * math.cos(step / 2)
		local dir = Vector3.new(math.cos(am), math.sin(am), 0)
		local tan = Vector3.new(-math.sin(am), math.cos(am), 0)
		local mid = Vector3.new(0, cy, 0) + dir * ((ri + rOut) / 2 * math.cos(step / 2))
		local width = 2 * rOut * math.sin(step / 2) + (if springer then 2.6 else 0.6)
		-- local frame: X = tangent (toward a decreasing angle), Y = radial out, Z = depth
		local cf = CFrame.fromMatrix(mid, -tan, dir)
		-- the two radial joint planes, 0.05 inside each joint line (0.1 joints)
		local negs = {}
		for _, bound in ipairs({ { a1, 1 }, { a2, -1 } }) do
			local ab, s = bound[1], bound[2]
			if springer and ((i == 0 and s == 1) or (i == n - 1 and s == -1)) then
				-- the springer's bed: everything under the capital's top goes (a box local to that side: one box across
				-- the whole arch made the right springer's subtraction degenerate)
				table.insert(negs, piece("Part", Vector3.new(8, 10, depth + 2), CFrame.new(math.sign(mid.X) * 7, springY - 5, 0), P.Stone))
				continue
			end
			local g = 0.05 / rm
			local ang = ab - s * g
			local rdir = Vector3.new(math.cos(ang), math.sin(ang), 0)
			local rtan = Vector3.new(-math.sin(ang), math.cos(ang), 0) * s -- pointing out of the voussoir
			local centre = Vector3.new(0, cy, 0) + rdir * rm + rtan * 5
			table.insert(negs, piece("Part", Vector3.new(14, 10, depth + 2), CFrame.fromMatrix(centre, rdir, rtan), P.Stone))
		end
		-- the 4 long edges (front / back of the intrados and extrados) chamfered; the edge wedges go first in the list
		local edges = { "topFrontBack", "bottomFrontBack" }
		local ti = toneIndex(rng, prev)
		prev = ti
		if key then
			-- the keystone: one colour like the old one (gold in the test zone, the zone colour on the hub frames)
			keystone = chamfered(Vector3.new(width, h, depth), cf, P.Gold, edges, 0.18, negs)
		else
			table.insert(arch, chamfered(Vector3.new(width, h, depth), cf, graded(if i % 2 == 0 then P.Stone else P.StoneLight, mid.Y, H, TONES[ti]), edges, 0.18, negs))
		end
	end
	-- mortar core of the arch (seen through the joints), kept above the capitals
	for i = 1, n - 1 do
		local am = aStart - i * step -- on each joint
		local dir = Vector3.new(math.cos(am), math.sin(am), 0)
		local tan = Vector3.new(-math.sin(am), math.cos(am), 0)
		local mid = Vector3.new(0, cy, 0) + dir * (rm0 + 0.0)
		table.insert(arch, piece("Part", Vector3.new(0.9, ro - ri - 0.5, D - 0.5), CFrame.fromMatrix(mid, -tan, dir), P.Mortar))
	end
	merge(m, "Arch", arch, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	local key = keystone :: BasePart
	key.Name = "Keystone"
	key:SetAttribute("MergeHash", hashOf({ key }))
	if key:IsA("PartOperation") then
		key.UsePartColor = true
	end
	key.Color = P.Gold
	key.CanCollide, key.CanQuery, key.CanTouch, key.CastShadow = true, true, false, true
	key.Parent = m

	-- 4. the name plate (kept as a Part named NamePlate: the hub copies' NameGui moves onto it), mounted on the arch
	-- face at its ends (as the old one), in a wooden frame with iron corner plates
	plain(m, "NamePlate", Vector3.new(9.5, 1.9, 0.5), CFrame.new(0, 18.2, -2.5), P.WoodLight, { collide = true })
	local frame: { BasePart } = {}
	for _, sy in ipairs({ -1, 1 }) do
		table.insert(frame, piece("Part", Vector3.new(10.3, 0.3, 0.62), CFrame.new(0, 18.2 + sy * 1.1, -2.5), graded(P.WoodDark, 18.2, H, if sy > 0 then 1 else 0.93)))
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(frame, piece("Part", Vector3.new(0.3, 1.9, 0.62), CFrame.new(sx * 5.0, 18.2, -2.5), graded(P.WoodDark, 18.2, H, 0.93)))
		for _, sy in ipairs({ -1, 1 }) do
			-- iron corner plates with a rivet
			table.insert(frame, piece("Part", Vector3.new(0.55, 0.55, 0.06), CFrame.new(sx * 4.9, 18.2 + sy * 1.0, -2.84), P.Iron))
			table.insert(frame, piece("Part", Vector3.new(0.13, 0.13, 0.13), CFrame.new(sx * 4.9, 18.2 + sy * 1.0, -2.88) * CFrame.Angles(math.rad(45), math.rad(45), 0), P.IronWorn)) -- rivet
		end
		-- an iron strap from each end of the frame up onto the arch face
		table.insert(frame, piece("Part", Vector3.new(0.4, 1.1, 0.08), CFrame.new(sx * 4.2, 19.75, -2.28), P.Iron))
		table.insert(frame, piece("Part", Vector3.new(0.13, 0.13, 0.13), CFrame.new(sx * 4.2, 20.1, -2.34) * CFrame.Angles(math.rad(45), math.rad(45), 0), P.IronWorn))
	end
	merge(m, "NamePlateFrame", frame, { collide = true, fidelity = Enum.CollisionFidelity.Box })

	-- 5. gems (one colour, Neon), settings, moss: no collision (they would close the opening)
	merge(m, "Gem", gems, { single = P.Gold, material = Enum.Material.Neon, shadow = false })
	merge(m, "GemSetting", settings, { shadow = true })
	merge(m, "Moss", mossList, { shadow = false })

	m.PrimaryPart = stepsUnion
	stepsUnion.PivotOffset = stepsUnion.CFrame:Inverse() -- pivot at the bottom centre (the origin)
	m:SetAttribute("MapPropId", "portal_frame")
	-- the zone variants of the hub frames (Variant = the zone id)
	local folder = Instance.new("Folder")
	folder.Name = "_Variants"
	for zone, color in pairs(PropsBatch2.PORTAL_ZONE_COLORS) do
		local config = Instance.new("Configuration")
		config.Name = zone
		config:SetAttribute("Color_Gem", color)
		config:SetAttribute("Color_Keystone", color)
		config.Parent = folder
	end
	folder.Parent = m
	return m
end

---------------------------------------------------------------------
-- install: build, replace ServerStorage.MapProps.<propId> (the old template goes to MapProps._Previous)
---------------------------------------------------------------------
function PropsBatch2.stats(model: Instance): (number, number, number)
	local parts, unions, triangles = 0, 0, 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
			if d:IsA("PartOperation") then
				unions += 1
				triangles += (d :: any).TriangleCount
			else
				triangles += 12
			end
		end
	end
	return parts, unions, triangles
end

function PropsBatch2.install(propId: string): string
	local builder = PropsBatch2[propId]
	assert(type(builder) == "function" and PropsBatch2.BUILDERS[propId], `PropsBatch2: no builder for {propId}`)
	local folder = ServerStorage:FindFirstChild("MapProps")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MapProps"
		folder.Parent = ServerStorage
	end
	local t0 = os.clock()
	local model = builder()
	model.Name = propId
	model:PivotTo(CFrame.identity)
	local old = folder:FindFirstChild(propId)
	if old then
		local previous = folder:FindFirstChild("_Previous") or Instance.new("Folder")
		previous.Name = "_Previous"
		previous.Parent = folder
		local stale = previous:FindFirstChild(propId)
		if stale then
			stale:Destroy()
		end
		old.Parent = previous
	end
	model.Parent = folder
	local _, size = model:GetBoundingBox()
	local parts, unions, triangles = PropsBatch2.stats(model)
	return string.format("installed ServerStorage.MapProps.%s: %d parts (%d unions), about %d triangles, bbox %.2f x %.2f x %.2f, built in %.1f s", propId, parts, unions, triangles, size.X, size.Y, size.Z, os.clock() - t0)
end

PropsBatch2.BUILDERS = { portal_frame = true }

return PropsBatch2
