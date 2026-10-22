--[[
	PropsBatch2 (dev tool, Edit mode only) - the owner's "PROPS BATCH 2" (2026-10-19): 16 objects of the prop test
	zone rebuilt to fountain / well quality (docs/prop_texture_guide.md section A, Agent A's recipe) from Parts merged
	with GeometryService into a few unions per colour / material group (each union = one part of the hub budget).
	Source of truth: tools/PropsBatch2.luau. Inventory: docs/prop_inventory.md "Props batch 2".
	Over 200,000 characters since batch E: in Studio, edit it with multi_edit or ScriptEditorService:UpdateSourceAsync
	(assigning the Source property refuses strings that long).

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
	-- 0.02 larger on both legs, same centre: the same cut (its slope does not move) but no face coplanar with the
	-- block's faces (coplanar faces left zero-thickness sheets in turned unions, e.g. a 16-sided disc's 2nd octagon)
	w.Size = Vector3.new(len + 0.2, c + 0.04, c + 0.04)
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

-- The faces a CSG subtraction cuts take the colour of the negative part. Until batch A the negative wedges kept the
-- default grey (163, 162, 165): a pale bevel on stone (the approved pilot and batch A look, kept as it is). From
-- batch B on (BEVEL_SELF, set by those builders) every cut face is the block's own colour x1.1, a soft highlight
-- that also suits wood and iron.
local BEVEL_SELF = false

-- a block (L x H x D at cf) with the listed edge sets chamfered by c (CSG subtract); extra = more negative parts;
-- keep = negative parts whose own colour stays on the faces they cut (carving, engraving), even with BEVEL_SELF
local function chamfered(size: Vector3, cf: CFrame, color: Color3, sets: { string }, c: number, extra: { BasePart }?, keep: { BasePart }?): BasePart
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
	if BEVEL_SELF then
		local bevel = scaled(color, 1.1)
		for _, n in ipairs(negs) do
			n.Color = bevel
		end
	end
	for _, x in ipairs(keep or {}) do
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
	if not r then
		-- last resort: one negative part at a time, skipping any cut that would leave a degenerate result
		local current: BasePart = block
		for _, neg in ipairs(negs) do
			local ok, result = pcall(function()
				return GeometryService:SubtractAsync(current, { neg }, { CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Automatic })
			end)
			local next = ok and result and result[1]
			if next and next.Size.X >= size.X * 0.3 and next.Size.Y >= size.Y * 0.3 and next.Size.Z >= size.Z * 0.3 then
				if current ~= block then
					current:Destroy()
				end
				current = next
			elseif next then
				next:Destroy()
			end
		end
		if current ~= block then
			r = current
		end
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
	local h1, h2 = if BEVEL_SELF then 5387 else 5381, 52711
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
-- shared: coursed stone, slabs, octagons, ivy (batch A)
---------------------------------------------------------------------
local GAP = 0.09 -- vertical joint between blocks

-- one course of chamfered blocks along X from o.x0 to o.x1 (o.y = course bottom, o.h = course height with its 0.05
-- bed joint, o.depth = the wall thickness centred on z 0), leaving the openings o.gaps ({a, b}) and laying the fixed
-- blocks o.fixed ({a, b, color}: lintels). Blocks 1.8-2.8 x the course height, joints 0.09, kept 0.35 away from the
-- joints of the course below (o.below: running bond), depth jitter 0 / 0.04 / 0.07 on both faces, tones never
-- repeated on a neighbour, A9 gradient. A mortar core 0.25 behind both faces fills every stretch that is not an
-- opening. Returns the joints of the course.
local function course(list: { BasePart }, rng: Random, o: any): { number }
	local h = o.h
	local bh = h - 0.05
	local yc = o.y + 0.025 + bh / 2
	local minL, maxL = (o.minL or 1.8) * h, (o.maxL or 2.8) * h
	local sets = o.sets or { "vertical", "topFrontBack" }
	local c = o.c or 0.18
	local cuts = {}
	for _, g in ipairs(o.gaps or {}) do
		table.insert(cuts, { g[1], g[2], nil })
	end
	for _, f in ipairs(o.fixed or {}) do
		table.insert(cuts, { f[1], f[2], f[3] })
	end
	table.sort(cuts, function(a, b)
		return a[1] < b[1]
	end)
	local joints: { number } = {}
	local prev = nil
	local function block(a: number, b: number, color: Color3)
		local ti = toneIndex(rng, prev)
		prev = ti
		local jitter = ({ 0, 0.04, 0.07 })[rng:NextInteger(1, 3)]
		table.insert(list, chamfered(Vector3.new(b - a, bh, o.depth + 2 * jitter), CFrame.new((a + b) / 2, yc, 0), graded(color, yc, o.H, TONES[ti]), sets, c))
	end
	local function near(x: number): boolean
		for _, j in ipairs(o.below or {}) do
			if math.abs(j - x) < 0.35 then
				return true
			end
		end
		return false
	end
	local function fill(a: number, b: number, first: boolean)
		local pos = a
		local start = true
		while b - pos > 0.05 do
			local L = rng:NextNumber(minL, maxL)
			if start and first and o.half then
				L = rng:NextNumber(0.5, 0.65) * maxL
			end
			if b - pos - L - GAP < minL * 0.55 then
				L = if b - pos > maxL * 1.25 then (b - pos - GAP) / 2 else b - pos
			end
			if pos + L < b - 0.05 and near(pos + L + GAP / 2) then
				local alt = L + 0.45
				if b - (pos + alt + GAP) < minL * 0.55 then
					alt = L - 0.45
				end
				if alt >= minL * 0.5 then
					L = alt
				end
			end
			L = math.min(L, b - pos)
			block(pos, pos + L, o.color)
			if pos + L < b - 0.05 then
				table.insert(joints, pos + L + GAP / 2)
			end
			pos += L + GAP
			start = false
		end
	end
	local cursor = o.x0
	local first = true
	for _, cut in ipairs(cuts) do
		local e = if cut[3] then cut[1] - GAP else cut[1]
		if e - cursor > 0.3 then
			fill(cursor, e, first)
			first = false
		end
		if cut[3] then
			block(cut[1], cut[2], cut[3])
			table.insert(joints, cut[1] - GAP / 2)
			table.insert(joints, cut[2] + GAP / 2)
		end
		cursor = if cut[3] then cut[2] + GAP else cut[2]
	end
	if o.x1 - cursor > 0.3 then
		fill(cursor, o.x1, first)
	end
	-- mortar core over the stretches between the openings (0.25 short of an opening and of the free end)
	local gaps = table.clone(o.gaps or {})
	table.sort(gaps, function(a, b)
		return a[1] < b[1]
	end)
	local cur = o.x0
	local spans = {}
	for _, g in ipairs(gaps) do
		table.insert(spans, { cur, g[1] - 0.25 })
		cur = g[2] + 0.25
	end
	table.insert(spans, { cur, o.x1 - (o.endInset or 0.25) })
	for _, s in ipairs(spans) do
		if s[2] - s[1] > 0.1 then
			table.insert(list, piece("Part", Vector3.new(s[2] - s[1], h, o.depth - 0.5), CFrame.new((s[1] + s[2]) / 2, o.y + h / 2, 0), P.Mortar))
		end
	end
	return joints
end

-- a row of `count` slabs (random lengths) along X from x0 to x1, y0..y0+h, depth d, centred on z 0, with joints 0.1
-- (+ a mortar core 0.15 behind the faces), top edges chamfered
local function slabs(list: { BasePart }, rng: Random, x0: number, x1: number, y0: number, h: number, d: number, count: number, color: Color3, H: number, c: number?)
	local lens, total = {}, 0
	for i = 1, count do
		lens[i] = rng:NextNumber(0.8, 1.2)
		total += lens[i]
	end
	local gap = 0.1
	local x = x0
	local prev = nil
	for i = 1, count do
		local len = lens[i] / total * (x1 - x0 - gap * (count - 1))
		local ti = toneIndex(rng, prev)
		prev = ti
		table.insert(list, chamfered(Vector3.new(len, h - 0.02, d), CFrame.new(x + len / 2, y0 + (h - 0.02) / 2, 0), graded(color, y0 + h / 2, H, TONES[ti]), { "topFrontBack", "topSides" }, c or 0.16))
		x += len + gap
	end
	table.insert(list, piece("Part", Vector3.new(x1 - x0 - 0.3, h - 0.1, d - 0.3), CFrame.new((x0 + x1) / 2, y0 + (h - 0.1) / 2, 0), P.Mortar))
end

-- a regular octagonal prism (w across the flats, h tall) at cf; flutes = a vertical groove on each of the 8 faces
-- (0.42 wide, 0.12 deep, stopping 0.25 short of both ends)
local function octagon(w: number, h: number, cf: CFrame, color: Color3, flutes: boolean?): BasePart
	local c = w / (2 + math.sqrt(2))
	local negs = {}
	if flutes then
		for k = 0, 7 do
			table.insert(negs, piece("Part", Vector3.new(0.42, h - 0.5, 0.3), cf * CFrame.Angles(0, k * math.pi / 4, 0) * CFrame.new(0, 0, w / 2 + 0.15 - 0.12), P.Stone))
		end
	end
	return chamfered(Vector3.new(w, h, w), cf, color, { "vertical" }, c, negs)
end

-- an ivy strand climbing a vertical face (the plane z = zf of the model, leaves facing -Z when front, +Z when not):
-- stem segments and diamond leaves, from (x, y0) up `height`, wandering at most 0.8 left / right of x
local function ivy(list: { BasePart }, rng: Random, x: number, y0: number, zf: number, height: number)
	local pos = Vector2.new(x, y0)
	local top = y0 + height
	local side = 1
	while pos.Y < top do
		local nxt = Vector2.new(math.clamp(pos.X + rng:NextNumber(-0.28, 0.28), x - 0.8, x + 0.8), pos.Y + rng:NextNumber(0.45, 0.65))
		local mid = (pos + nxt) / 2
		local d = nxt - pos
		table.insert(list, piece("Part", Vector3.new(0.1, d.Magnitude + 0.06, 0.08), CFrame.new(mid.X, mid.Y, zf) * CFrame.Angles(0, 0, math.atan2(-d.X, d.Y)), scaled(P.WoodDark, 0.9)))
		-- a leaf (sometimes two) on alternate sides of the node
		local count = if rng:NextNumber() < 0.35 then 2 else 1
		for _ = 1, count do
			local s = rng:NextNumber(0.42, 0.6) * (1 - 0.3 * (nxt.Y - y0) / height)
			local off = Vector2.new(side * rng:NextNumber(0.18, 0.32), rng:NextNumber(-0.05, 0.12))
			local col = if rng:NextNumber() < 0.5 then P.Moss else P.MossDark
			table.insert(list, piece("Part", Vector3.new(s, s, 0.05), CFrame.new(nxt.X + off.X, nxt.Y + off.Y, zf + (if zf < 0 then -0.03 else 0.03)) * CFrame.Angles(0, 0, math.rad(45 + rng:NextNumber(-15, 15))), scaled(col, rng:NextNumber(0.85, 1.0))))
			side = -side
		end
		pos = nxt
	end
end

---------------------------------------------------------------------
-- 01 WALL (kit Hub.Hub_Wall_Section, 20.3 x 7.9 x 4.8; the hub's 4 Hub_Wall_Section in Hub.Decor.Village). A
-- free-standing wall of real stone blocks (4 courses of 1.0, running bond, 0.09 joints over a mortar core, both faces
-- shown) on a wider base step of slabs, capped with overhanging dark slabs; an end pier of coursed blocks with a
-- proud top course and a cushioned cap; the 3 small windows of the old wall (the 3 "Brick" plates) are kept as
-- stone-framed openings (sill, lintel) with an iron grille; moss on the base step against the wall.
-- Parts: Base, Stones, Cap, Grilles, Moss (5; the old one had 8).
---------------------------------------------------------------------
PropsBatch2.WALL_WINDOWS = { { x = 7.0, k = 2 }, { x = 2.0, k = 1 }, { x = -3.0, k = 2 } } -- the old Brick plates

function PropsBatch2.hub_wall(): Model
	local m = Instance.new("Model")
	m.Name = "hub_wall"
	local rng = Random.new(20261001)
	local H = 7.9
	local base, stones, caps, iron, mossList = {}, {}, {}, {}, {}
	local px = -8.2 -- the pier's centre (it spans x -10.0 .. -6.4, z +-2.1)

	-- 1. base: the pier plinth and a wider step of slabs under the wall (tread 0.8 on both faces)
	table.insert(base, chamfered(Vector3.new(4.4, 0.98, 4.8), CFrame.new(px - 0.0, 0.49, 0), graded(P.StoneDark, 0.5, H, 0.93), { "topFrontBack", "topSides" }, 0.15))
	slabs(base, rng, -5.91, 10.3, 0, 1.0, 4.2, 5, scaled(P.StoneDark, 0.93), H, 0.15)
	merge(m, "Base", base, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 2. the wall: 4 courses from y 1, from inside the pier (x -6.6) to the free end (x 10); openings 2.0 wide, one
	-- course tall; a lighter lintel block over each, a dark sill under each
	local below = {}
	for k = 0, 3 do
		local gaps, fixed = {}, {}
		for _, w in ipairs(PropsBatch2.WALL_WINDOWS) do
			if w.k == k then
				table.insert(gaps, { w.x - 1.0, w.x + 1.0 })
			elseif w.k == k - 1 then
				table.insert(fixed, { w.x - 1.6, w.x + 1.6, P.StoneLight })
			end
		end
		below = course(stones, rng, { x0 = -6.6, x1 = 10.0, y = 1 + k, h = 1.0, depth = 2.6, color = P.Stone, H = H, gaps = gaps, fixed = fixed, below = below, half = k % 2 == 1, c = 0.17 })
	end
	for _, w in ipairs(PropsBatch2.WALL_WINDOWS) do
		local y0 = 1 + w.k
		-- sill (0.15 proud of both faces) and the grille: 3 square bars into the sill and the lintel, a cross bar
		table.insert(caps, chamfered(Vector3.new(2.5, 0.22, 2.9), CFrame.new(w.x, y0 + 0.11, 0), graded(P.StoneDark, y0, H, 1), { "topFrontBack" }, 0.07))
		for _, bx in ipairs({ -0.5, 0, 0.5 }) do
			table.insert(iron, piece("Part", Vector3.new(0.14, 0.9, 0.14), CFrame.new(w.x + bx, y0 + 0.22 + 0.42, 0), P.Iron))
		end
		table.insert(iron, piece("Part", Vector3.new(2.1, 0.12, 0.12), CFrame.new(w.x, y0 + 0.62, 0), P.Iron))
	end

	-- 3. the pier: 6 courses of 1.0 from y 1, two blocks a course (split along z, then along x), the top course proud
	table.insert(stones, piece("Part", Vector3.new(3.1, 6.0, 3.7), CFrame.new(px, 4.0, 0), P.Mortar))
	local prev = nil
	for k = 0, 5 do
		local yc = 1 + k + 0.025 + 0.475
		local function blk(size: Vector3, pos: Vector3, color: Color3)
			local ti = toneIndex(rng, prev)
			prev = ti
			table.insert(stones, chamfered(size, CFrame.new(pos), graded(color, yc, H, TONES[ti]), { "vertical", "topFrontBack", "topSides" }, 0.16))
		end
		local j1, j2 = ({ 0, 0.04, 0.07 })[rng:NextInteger(1, 3)], ({ 0, 0.04, 0.07 })[rng:NextInteger(1, 3)]
		if k == 5 then
			blk(Vector3.new(3.84, 0.95, 4.44), Vector3.new(px, yc, 0), P.Stone)
		elseif k % 2 == 0 then
			local d1 = rng:NextNumber(1.8, 2.3)
			local d2 = 4.2 - d1 - GAP
			blk(Vector3.new(3.6 + 2 * j1, 0.95, d1 + j1), Vector3.new(px, yc, -2.1 + d1 / 2 - j1 / 2), P.StoneLight)
			blk(Vector3.new(3.6 + 2 * j2, 0.95, d2 + j2), Vector3.new(px, yc, 2.1 - d2 / 2 + j2 / 2), P.StoneLight)
		else
			local w1 = rng:NextNumber(1.5, 2.0)
			local w2 = 3.6 - w1 - GAP
			blk(Vector3.new(w1 + j1, 0.95, 4.2 + 2 * j1), Vector3.new(-10.0 + w1 / 2 - j1 / 2, yc, 0), P.StoneLight)
			blk(Vector3.new(w2 + j2, 0.95, 4.2 + 2 * j2), Vector3.new(-6.4 - w2 / 2 + j2 / 2, yc, 0), P.StoneLight)
		end
	end
	merge(m, "Stones", stones, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 4. caps: the wall's coping (0.8 thick, 0.4 overhang on both faces, 0.3 at the free end) and the pier cap
	slabs(caps, rng, -6.45, 10.3, 5.0, 0.8, 3.4, 6, P.StoneDark, H, 0.18)
	table.insert(caps, chamfered(Vector3.new(4.2, 0.9, 4.8), CFrame.new(px, 7.0 + 0.45, 0), graded(P.StoneDark, 7.45, H, 1), { "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.2))
	merge(m, "Cap", caps, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Grilles", iron, { collide = true, fidelity = Enum.CollisionFidelity.Box })

	-- 5. moss on the base step against both faces (and one against the pier)
	for _, sz in ipairs({ -1, 1 }) do
		for _, range in ipairs({ { -5.2, 1.0 }, { 3.0, 9.0 } }) do
			local len = rng:NextNumber(1.5, 2.0)
			moss(mossList, rng, Vector3.new(rng:NextNumber(range[1], range[2]), 0.98, sz * (1.3 + len * 0.18 - 0.07)), 0, len)
		end
	end
	moss(mossList, rng, Vector3.new(-5.85, 0.98, -(1.3 + 1.3 * 0.18 - 0.07)), math.rad(rng:NextNumber(-10, 10)), 1.3)
	merge(m, "Moss", mossList, { shadow = false })

	local root = m:FindFirstChild("Base") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "hub_wall")
	return m
end

---------------------------------------------------------------------
-- 08 STONE ARCH (kit Common.Stone_Arch_A, 36.4 x 27.5 x 6; test zone + kit only). Two piers of coursed blocks (10
-- courses of 1.3, two blocks a course, alternating) on two-step plinths, bevelled capitals (a carved band and an
-- impost slab), a round arch of 11 voussoirs with radial joints springing from the imposts (inner span 25, inner apex
-- 23.5) and a proud wedge-shaped keystone; moss at the foot of the steps and on them, ivy climbing two pier faces.
-- Parts: Steps, Piers, Arch, Moss (4; the old one had 11).
---------------------------------------------------------------------
function PropsBatch2.stone_arch(): Model
	local m = Instance.new("Model")
	m.Name = "stone_arch"
	local rng = Random.new(20261008)
	local H = 27.5
	local steps, piers, arch, mossList = {}, {}, {}, {}
	for _, side in ipairs({ -1, 1 }) do
		local x0 = 15 * side
		-- two-step plinth: lower 6.5 square (2 slabs split along z), upper 5.9 (2 slabs split along x), mortar
		for t = 0, 1 do
			local w = if t == 0 then 6.5 else 5.9
			local y0 = t * 1.0
			local col = if t == 0 then scaled(P.StoneDark, 0.93) else P.StoneDark
			local a = w * rng:NextNumber(0.42, 0.58) - 0.05
			local b = w - a - 0.1
			local sets = { "topFrontBack", "topSides" }
			local yc = y0 + 0.49
			local t1, t2 = rng:NextInteger(1, 3), 0
			t2 = t1 % 3 + 1
			if t == 0 then
				table.insert(steps, chamfered(Vector3.new(w, 0.98, a), CFrame.new(x0, yc, -w / 2 + a / 2), graded(col, yc, H, TONES[t1]), sets, 0.16))
				table.insert(steps, chamfered(Vector3.new(w, 0.98, b), CFrame.new(x0, yc, w / 2 - b / 2), graded(col, yc, H, TONES[t2]), sets, 0.16))
			else
				table.insert(steps, chamfered(Vector3.new(a, 0.98, w), CFrame.new(x0 - w / 2 + a / 2, yc, 0), graded(col, yc, H, TONES[t1]), sets, 0.16))
				table.insert(steps, chamfered(Vector3.new(b, 0.98, w), CFrame.new(x0 + w / 2 - b / 2, yc, 0), graded(col, yc, H, TONES[t2]), sets, 0.16))
			end
			table.insert(steps, piece("Part", Vector3.new(w - 0.3, 0.9, w - 0.3), CFrame.new(x0, y0 + 0.45, 0), P.Mortar))
		end
		-- pier: 5 x 5, y 2 .. 15, 10 courses of 1.3 (blocks 1.25), two blocks a course
		table.insert(piers, piece("Part", Vector3.new(4.5, 13.0, 4.5), CFrame.new(x0, 8.5, 0), P.Mortar))
		local prev = nil
		for k = 0, 9 do
			local yc = 2 + k * 1.3 + 0.025 + 0.625
			local s = rng:NextNumber(0.4, 0.6)
			local w1 = 5 * s - GAP / 2
			local w2 = 5 - w1 - GAP
			local j1, j2 = ({ 0, 0.04, 0.07 })[rng:NextInteger(1, 3)], ({ 0, 0.04, 0.07 })[rng:NextInteger(1, 3)]
			local ti1 = toneIndex(rng, prev)
			local ti2 = toneIndex(rng, ti1)
			prev = ti2
			local sets = { "vertical", "topFrontBack", "topSides" }
			if k % 2 == 0 then
				table.insert(piers, chamfered(Vector3.new(w1 + j1, 1.25, 5 + 2 * j1), CFrame.new(x0 - 2.5 + w1 / 2 - j1 / 2, yc, 0), graded(P.Stone, yc, H, TONES[ti1]), sets, 0.2))
				table.insert(piers, chamfered(Vector3.new(w2 + j2, 1.25, 5 + 2 * j2), CFrame.new(x0 + 2.5 - w2 / 2 + j2 / 2, yc, 0), graded(P.Stone, yc, H, TONES[ti2]), sets, 0.2))
			else
				table.insert(piers, chamfered(Vector3.new(5 + 2 * j1, 1.25, w1 + j1), CFrame.new(x0, yc, -2.5 + w1 / 2 - j1 / 2), graded(P.Stone, yc, H, TONES[ti1]), sets, 0.2))
				table.insert(piers, chamfered(Vector3.new(5 + 2 * j2, 1.25, w2 + j2), CFrame.new(x0, yc, 2.5 - w2 / 2 + j2 / 2), graded(P.Stone, yc, H, TONES[ti2]), sets, 0.2))
			end
		end
		-- bevelled capital: a carved band (chamfered underside) and the impost slab
		table.insert(piers, chamfered(Vector3.new(5.5, 0.4, 5.5), CFrame.new(x0, 15.2, 0), graded(P.StoneDark, 15.2, H, 1), { "bottomFrontBack", "bottomSides" }, 0.2))
		table.insert(piers, chamfered(Vector3.new(6.0, 0.7, 6.0), CFrame.new(x0, 15.75, 0), graded(P.StoneDark, 15.75, H, 0.93), { "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.2))
		-- moss: on the ground against the lower step (passage side and outer side), a cushion on the upper step
		-- against the pier
		for _, sx in ipairs({ -1, 1 }) do
			local len = rng:NextNumber(1.6, 2.2)
			moss(mossList, rng, Vector3.new(x0 + sx * (3.25 + len * 0.18 - 0.08), 0.0, rng:NextNumber(-1.8, 1.8)), math.rad(90), len)
		end
		local cl = rng:NextNumber(1.0, 1.25)
		moss(mossList, rng, Vector3.new(x0 + rng:NextNumber(-1.5, 1.5), 1.98, -(2.5 + cl * 0.18 - 0.05)), 0, cl)
	end
	-- ivy up the left pier's front face and the right pier's back face
	ivy(mossList, rng, -15 + 0.8, 2.05, -2.6, 8.5)
	ivy(mossList, rng, -15 - 0.9, 2.05, -2.6, 4.5)
	ivy(mossList, rng, 15 - 0.8, 2.05, 2.6, 6.0)
	merge(m, "Steps", steps, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Piers", piers, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- the arch: centre (0, 9.242), radii 14.258 - 18.158 (inner springing (+-12.5, 16.1), inner apex 23.5), 11
	-- voussoirs with V-grooved radial joints; the springers sit on the imposts (bed at y 16.1, back cut at |x| 17.8);
	-- the keystone is proud (0.5 above, 0.3 below, 0.3 in front and behind)
	local cy, ri, ro, D = 9.242, 14.258, 18.158, 4.6
	local half = math.asin(12.5 / ri)
	local n = 11
	local step = 2 * half / n
	local aStart = math.pi / 2 + half
	local prev = nil
	for i = 0, n - 1 do
		local key = i == (n - 1) / 2
		local springer = i == 0 or i == n - 1
		local a1, a2 = aStart - i * step, aStart - (i + 1) * step
		local am = (a1 + a2) / 2
		local rIn = if key then ri - 0.3 else ri
		local rOut = if key then ro + 0.5 else ro
		local depth = if key then D + 0.6 else D
		local rm = (rIn + rOut) / 2
		local h = (rOut - rIn) * math.cos(step / 2)
		local dir = Vector3.new(math.cos(am), math.sin(am), 0)
		local tan = Vector3.new(-math.sin(am), math.cos(am), 0)
		local mid = Vector3.new(0, cy, 0) + dir * (rm * math.cos(step / 2))
		local width = 2 * rOut * math.sin(step / 2) + (if springer then 7.6 else 0.6)
		local cf = CFrame.fromMatrix(mid, -tan, dir)
		local negs = {}
		for _, bound in ipairs({ { a1, 1 }, { a2, -1 } }) do
			local ab, s = bound[1], bound[2]
			if springer and ((i == 0 and s == 1) or (i == n - 1 and s == -1)) then
				-- bed on the impost and a vertical back over the pier's outer face
				local sx = math.sign(mid.X)
				table.insert(negs, piece("Part", Vector3.new(10, 10, depth + 2), CFrame.new(sx * 15, 16.1 - 5, 0), P.Stone))
				table.insert(negs, piece("Part", Vector3.new(6, 20, depth + 2), CFrame.new(sx * (17.8 + 3), 18, 0), P.Stone))
				continue
			end
			local ang = ab - s * (0.05 / rm)
			local rdir = Vector3.new(math.cos(ang), math.sin(ang), 0)
			local rtan = Vector3.new(-math.sin(ang), math.cos(ang), 0) * s
			local centre = Vector3.new(0, cy, 0) + rdir * rm + rtan * 5
			table.insert(negs, piece("Part", Vector3.new(20, 10, depth + 2), CFrame.fromMatrix(centre, rdir, rtan), P.Stone))
			-- V-groove: the voussoir's edges along this joint (front and back faces) chamfered, as the top edges of a
			-- virtual block whose top face is the joint plane
			local jb = CFrame.fromMatrix(Vector3.new(0, cy, 0) + rdir * rm - rtan * 1, rdir, rtan)
			for _, bz in ipairs({ 1, -1 }) do
				table.insert(negs, negWedge(jb, Vector3.new(rOut - rIn + 0.6, 2, depth), "X", 1, bz, 0.2))
			end
		end
		local ti = toneIndex(rng, prev)
		prev = ti
		local color = if key then scaled(P.StoneLight, 1.03) elseif i % 2 == 0 then P.Stone else P.StoneLight
		table.insert(arch, chamfered(Vector3.new(width, h, depth), cf, graded(color, mid.Y, H, if key then 1 else TONES[ti]), { "topFrontBack", "bottomFrontBack" }, 0.2, negs))
	end
	for i = 1, n - 1 do
		local am = aStart - i * step
		local dir = Vector3.new(math.cos(am), math.sin(am), 0)
		local tan = Vector3.new(-math.sin(am), math.cos(am), 0)
		table.insert(arch, piece("Part", Vector3.new(1.0, ro - ri - 0.6, D - 0.5), CFrame.fromMatrix(Vector3.new(0, cy, 0) + dir * ((ri + ro) / 2), -tan, dir), P.Mortar))
	end
	merge(m, "Arch", arch, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Moss", mossList, { shadow = false })

	local root = m:FindFirstChild("Steps") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "stone_arch")
	return m
end

---------------------------------------------------------------------
-- 09 PILLAR (kit Common.Stone_Pillar_A, 5.4 x 16.4 x 5.4; the 12 x3-scaled copies of the Plains boss arena,
-- ServerStorage.BossArenas.Plains.Decor). A plinth of 4 stone blocks, a carved base (bevelled square torus and two
-- octagonal fillets), a fluted octagonal shaft of 4 drums with a middle band and two astragals, a carved capital
-- (bevelled echinus and abacus), light moss at the foot. Same size; every piece collides as before (moss excepted).
-- Parts: Base, Shaft, Capital, Moss (4; the old one had 6).
---------------------------------------------------------------------
function PropsBatch2.stone_pillar(): Model
	local m = Instance.new("Model")
	m.Name = "stone_pillar"
	local rng = Random.new(20261009)
	local H = 16.4
	local base, shaft, cap, mossList = {}, {}, {}, {}
	-- 1. plinth: 4 blocks (2 x 2) of 2.655 with 0.09 joints over a mortar core
	local w = (5.4 - GAP) / 2
	local prev = nil
	for _, ix in ipairs({ -1, 1 }) do
		for _, iz in ipairs({ -1, 1 }) do
			local ti = toneIndex(rng, prev)
			prev = ti
			table.insert(base, chamfered(Vector3.new(w, 1.16, w), CFrame.new(ix * (w / 2 + GAP / 2), 0.58, iz * (w / 2 + GAP / 2)), graded(P.StoneDark, 0.6, H, TONES[ti]), { "vertical", "topFrontBack", "topSides" }, 0.15))
		end
	end
	table.insert(base, piece("Part", Vector3.new(4.9, 1.1, 4.9), CFrame.new(0, 0.55, 0), P.Mortar))
	-- 2. carved base: a bevelled square torus, an octagonal fillet and a thin octagonal ring
	table.insert(base, chamfered(Vector3.new(4.6, 0.45, 4.6), CFrame.new(0, 1.18 + 0.225, 0), graded(P.Stone, 1.4, H, 0.93), { "topFrontBack", "topSides", "vertical" }, 0.2))
	table.insert(base, octagon(4.1, 0.4, CFrame.new(0, 1.63 + 0.2, 0), graded(P.Stone, 1.8, H, 1)))
	table.insert(base, octagon(3.75, 0.25, CFrame.new(0, 2.03 + 0.125, 0), graded(P.StoneDark, 2.1, H, 1)))
	merge(m, "Base", base, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 3. shaft: astragal, 2 fluted drums, the middle band, 2 fluted drums, astragal (0.05 joints, mortar core)
	table.insert(shaft, piece("Part", Vector3.new(2.1, 11.9, 2.1), CFrame.new(0, 2.28 + 5.95, 0), P.Mortar)) -- corners inside the flutes
	table.insert(shaft, octagon(3.7, 0.25, CFrame.new(0, 2.28 + 0.125, 0), graded(P.StoneDark, 2.4, H, 1)))
	table.insert(shaft, octagon(3.85, 0.8, CFrame.new(0, 7.6 + 0.4, 0), graded(P.StoneDark, 8.0, H, 1)))
	table.insert(shaft, octagon(3.7, 0.25, CFrame.new(0, 13.9 + 0.125, 0), graded(P.StoneDark, 14.0, H, 1)))
	local tprev = nil
	for _, span in ipairs({ { 2.53, 7.6 }, { 8.4, 13.9 } }) do
		local hDrum = (span[2] - span[1] - 0.05) / 2
		for d = 0, 1 do
			local y0 = span[1] + d * (hDrum + 0.05) + 0.025
			local ti = toneIndex(rng, tprev)
			tprev = ti
			table.insert(shaft, octagon(3.4, hDrum - 0.025, CFrame.new(0, y0 + hDrum / 2, 0), graded(P.Stone, y0 + hDrum / 2, H, TONES[ti]), true))
		end
	end
	merge(m, "Shaft", shaft, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 4. capital: echinus (square, deep bevel underneath) and the abacus (all edges chamfered)
	local echinusCF = CFrame.new(0, 14.15 + 0.5, 0)
	local vert = {}
	for _, e in ipairs(EDGES.vertical) do
		table.insert(vert, negWedge(echinusCF, Vector3.new(4.6, 1.0, 4.6), e[1], e[2], e[3], 0.15))
	end
	table.insert(cap, chamfered(Vector3.new(4.6, 1.0, 4.6), echinusCF, graded(P.Stone, 14.65, H, 1), { "bottomFrontBack", "bottomSides" }, 0.5, vert))
	table.insert(cap, chamfered(Vector3.new(5.4, 1.25, 5.4), CFrame.new(0, 15.15 + 0.625, 0), graded(P.StoneDark, 15.8, H, 1), { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.2))
	merge(m, "Capital", cap, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 5. light moss: three cushions on the plinth against the base (nothing outside the plinth: same footprint)
	moss(mossList, rng, Vector3.new(rng:NextNumber(-1.2, 1.2), 1.16, -(2.3 + 0.2 - 0.05)), 0, 1.1)
	moss(mossList, rng, Vector3.new(2.3 + 0.18 - 0.05, 1.16, rng:NextNumber(-1.2, 1.2)), math.rad(90), 1.0)
	moss(mossList, rng, Vector3.new(-(2.3 + 0.18 - 0.05), 1.16, rng:NextNumber(-1.2, 1.2)), math.rad(90), 0.95)
	merge(m, "Moss", mossList, { shadow = false })

	local root = m:FindFirstChild("Base") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "stone_pillar")
	return m
end

---------------------------------------------------------------------
-- shared (batch B): timber, rivets, bands, stone piers and rings, slab caps, arches, shingle roofs, kept meshes
---------------------------------------------------------------------
local LOG_END = rgb(236, 200, 96)
local ROPE = rgb(196, 160, 104)

local function jit(rng: Random): number
	return ({ 0, 0.04, 0.07 })[rng:NextInteger(1, 3)]
end

-- a timber (box) with its 4 long edges chamfered (the long axis = the largest dimension)
local function timber(size: Vector3, cf: CFrame, color: Color3, c: number?): BasePart
	local cc = c or math.clamp(math.min(size.X, size.Y, size.Z) * 0.18, 0.05, 0.22)
	local sets
	if size.X >= size.Y and size.X >= size.Z then
		sets = { "topFrontBack", "bottomFrontBack" }
	elseif size.Y >= size.Z then
		sets = { "vertical" }
	else
		sets = { "topSides", "bottomSides" }
	end
	return chamfered(size, cf, color, sets, cc)
end

-- a rivet / stud / nail head: a small cube turned on its corner, half sunk where it is put
local function rivet(list: { BasePart }, pos: Vector3, s: number?)
	local k = s or 0.14
	table.insert(list, piece("Part", Vector3.new(k, k, k), CFrame.new(pos) * CFrame.Angles(math.rad(45), math.rad(45), 0), P.IronWorn))
end

-- an iron strap (h tall, 0.1 thick) wrapped around the box x0..x1 / z0..z1 at height y, rivets on the front and back
local function band(list: { BasePart }, x0: number, x1: number, z0: number, z1: number, y: number, h: number)
	local t = 0.1
	table.insert(list, piece("Part", Vector3.new(x1 - x0 + 2 * t, h, t), CFrame.new((x0 + x1) / 2, y, z0 - t / 2), P.Iron))
	table.insert(list, piece("Part", Vector3.new(x1 - x0 + 2 * t, h, t), CFrame.new((x0 + x1) / 2, y, z1 + t / 2), P.Iron))
	table.insert(list, piece("Part", Vector3.new(t, h, z1 - z0), CFrame.new(x0 - t / 2, y, (z0 + z1) / 2), P.Iron))
	table.insert(list, piece("Part", Vector3.new(t, h, z1 - z0), CFrame.new(x1 + t / 2, y, (z0 + z1) / 2), P.Iron))
	local n = math.max(2, math.floor((x1 - x0) / 0.65))
	for i = 0, n - 1 do
		local x = x0 + 0.25 + i * (x1 - x0 - 0.5) / (n - 1)
		rivet(list, Vector3.new(x, y, z0 - t))
		rivet(list, Vector3.new(x, y, z1 + t))
	end
end

-- a small stone pier (w x d) of n courses between y0 and y1, two blocks a course split along X then along Z (the
-- joints cross at the corners), over a mortar core
local function pier2(list: { BasePart }, rng: Random, o: any)
	local h = (o.y1 - o.y0) / o.n
	local prev = nil
	local sets = { "vertical", "topFrontBack", "topSides" }
	local c = o.c or 0.18
	table.insert(list, piece("Part", Vector3.new(o.w - 0.5, o.y1 - o.y0, o.d - 0.5), CFrame.new(o.cx, (o.y0 + o.y1) / 2, o.cz), P.Mortar))
	for k = 0, o.n - 1 do
		local yc = o.y0 + k * h + 0.025 + (h - 0.05) / 2
		local s = rng:NextNumber(0.4, 0.6)
		local j1, j2 = jit(rng), jit(rng)
		local ti1 = toneIndex(rng, prev)
		local ti2 = toneIndex(rng, ti1)
		prev = ti2
		local c1, c2 = graded(o.color, yc, o.H, TONES[ti1]), graded(o.color, yc, o.H, TONES[ti2])
		if k % 2 == 0 then
			local w1 = o.w * s - GAP / 2
			local w2 = o.w - w1 - GAP
			table.insert(list, chamfered(Vector3.new(w1 + j1, h - 0.05, o.d + 2 * j1), CFrame.new(o.cx - o.w / 2 + w1 / 2 - j1 / 2, yc, o.cz), c1, sets, c))
			table.insert(list, chamfered(Vector3.new(w2 + j2, h - 0.05, o.d + 2 * j2), CFrame.new(o.cx + o.w / 2 - w2 / 2 + j2 / 2, yc, o.cz), c2, sets, c))
		else
			local d1 = o.d * s - GAP / 2
			local d2 = o.d - d1 - GAP
			table.insert(list, chamfered(Vector3.new(o.w + 2 * j1, h - 0.05, d1 + j1), CFrame.new(o.cx, yc, o.cz - o.d / 2 + d1 / 2 - j1 / 2), c1, sets, c))
			table.insert(list, chamfered(Vector3.new(o.w + 2 * j2, h - 0.05, d2 + j2), CFrame.new(o.cx, yc, o.cz + o.d / 2 - d2 / 2 + j2 / 2), c2, sets, c))
		end
	end
end

-- one course of a big rectangular pier (w along X, d along Z, centred on cx / cz; y = course bottom, h = height with
-- the 0.05 joint): blocks t deep around the perimeter, the corners alternating between courses (o.odd: the side rows
-- run the full depth), a mortar core inside; blocks 1.5-2.5 x h long, the outer one jittered outward
local function ringCourse(list: { BasePart }, rng: Random, o: any)
	local h, t = o.h, o.t
	local bh = h - 0.05
	local yc = o.y + 0.025 + bh / 2
	local prev = nil
	local function fill(a: number, b: number, place: (number, number, number) -> ())
		local pos = a
		while b - pos > 0.05 do
			local L = rng:NextNumber(1.5, 2.5) * h
			if b - pos - L - GAP < 0.9 * h then
				L = if b - pos > 3.2 * h then (b - pos - GAP) / 2 else b - pos
			end
			L = math.min(L, b - pos)
			place(pos, pos + L, jit(rng))
			pos += L + GAP
		end
	end
	local function color(): Color3
		local ti = toneIndex(rng, prev)
		prev = ti
		return graded(o.color, yc, o.H, TONES[ti])
	end
	local xa, xb = o.cx - o.w / 2, o.cx + o.w / 2
	local za, zb = o.cz - o.d / 2, o.cz + o.d / 2
	local inX = if o.odd then t + GAP else 0
	local inZ = if o.odd then 0 else t + GAP
	for _, sz in ipairs({ -1, 1 }) do
		fill(xa + inX, xb - inX, function(a, b, j)
			local zc = (if sz < 0 then za + t / 2 else zb - t / 2) + sz * j / 2
			table.insert(list, chamfered(Vector3.new(b - a, bh, t + j), CFrame.new((a + b) / 2, yc, zc), color(), { "vertical", "topFrontBack" }, 0.18))
		end)
	end
	for _, sx in ipairs({ -1, 1 }) do
		fill(za + inZ, zb - inZ, function(a, b, j)
			local xc = (if sx < 0 then xa + t / 2 else xb - t / 2) + sx * j / 2
			table.insert(list, chamfered(Vector3.new(t + j, bh, b - a), CFrame.new(xc, yc, (a + b) / 2), color(), { "vertical", "topSides" }, 0.18))
		end)
	end
	table.insert(list, piece("Part", Vector3.new(o.w - 0.5, h, o.d - 0.5), CFrame.new(o.cx, o.y + h / 2, o.cz), P.Mortar))
end

-- a cap of n slabs (w x h x d, split along X) on top of a pier, top edges chamfered, joints 0.1 over a mortar core
local function capSlabs(list: { BasePart }, rng: Random, cx: number, cz: number, w: number, d: number, y0: number, h: number, color: Color3, H: number, n: number)
	local x = cx - w / 2
	local prev = nil
	local lens, total = {}, 0
	for i = 1, n do
		lens[i] = rng:NextNumber(0.8, 1.2)
		total += lens[i]
	end
	for i = 1, n do
		local len = lens[i] / total * (w - 0.1 * (n - 1))
		local ti = toneIndex(rng, prev)
		prev = ti
		table.insert(list, chamfered(Vector3.new(len, h, d), CFrame.new(x + len / 2, y0 + h / 2, cz), graded(color, y0 + h / 2, H, TONES[ti]), { "topFrontBack", "topSides" }, 0.2))
		x += len + 0.1
	end
	table.insert(list, piece("Part", Vector3.new(w - 0.4, h - 0.2, d - 0.4), CFrame.new(cx, y0 + (h - 0.2) / 2, cz), P.Mortar))
end

-- a round / segmental arch of o.n voussoirs (centre (0, o.cy), radii o.ri - o.ro, inner springing at x +-o.sx) with
-- V-grooved radial joints, a mortar core along the joints, a proud keystone (o.keyUp above, o.keyDown below,
-- o.keyDepth deep); the two springers get a horizontal bed at o.bedY (a box on each side centred on x +-o.bedX) and
-- a vertical back at |x| = o.backX; o.springExt = how much longer the springer blocks are cut from
local function voussoirs(list: { BasePart }, rng: Random, o: any)
	local cy, ri, ro, D, n = o.cy, o.ri, o.ro, o.depth, o.n
	local half = math.asin(o.sx / ri)
	local step = 2 * half / n
	local aStart = math.pi / 2 + half
	local prev = nil
	for i = 0, n - 1 do
		local key = i == (n - 1) / 2
		local springer = i == 0 or i == n - 1
		local a1, a2 = aStart - i * step, aStart - (i + 1) * step
		local am = (a1 + a2) / 2
		local rIn = if key then ri - o.keyDown else ri
		local rOut = if key then ro + o.keyUp else ro
		local depth = if key then o.keyDepth else D
		local rm = (rIn + rOut) / 2
		local h = (rOut - rIn) * math.cos(step / 2)
		local dir = Vector3.new(math.cos(am), math.sin(am), 0)
		local tan = Vector3.new(-math.sin(am), math.cos(am), 0)
		local mid = Vector3.new(0, cy, 0) + dir * (rm * math.cos(step / 2))
		local width = 2 * rOut * math.sin(step / 2) + (if springer then o.springExt else 0.6)
		local cf = CFrame.fromMatrix(mid, -tan, dir)
		local negs = {}
		for _, bound in ipairs({ { a1, 1 }, { a2, -1 } }) do
			local ab, s = bound[1], bound[2]
			if springer and ((i == 0 and s == 1) or (i == n - 1 and s == -1)) then
				local sx = math.sign(mid.X)
				table.insert(negs, piece("Part", Vector3.new(10, 10, depth + 2), CFrame.new(sx * o.bedX, o.bedY - 5, 0), P.Stone))
				table.insert(negs, piece("Part", Vector3.new(6, 30, depth + 2), CFrame.new(sx * (o.backX + 3), o.bedY + 10, 0), P.Stone))
				continue
			end
			local ang = ab - s * (0.05 / rm)
			local rdir = Vector3.new(math.cos(ang), math.sin(ang), 0)
			local rtan = Vector3.new(-math.sin(ang), math.cos(ang), 0) * s
			local centre = Vector3.new(0, cy, 0) + rdir * rm + rtan * 5
			table.insert(negs, piece("Part", Vector3.new(20, 10, depth + 2), CFrame.fromMatrix(centre, rdir, rtan), P.Stone))
			local jb = CFrame.fromMatrix(Vector3.new(0, cy, 0) + rdir * rm - rtan * 1, rdir, rtan)
			for _, bz in ipairs({ 1, -1 }) do
				table.insert(negs, negWedge(jb, Vector3.new(rOut - rIn + 0.6, 2, depth), "X", 1, bz, 0.2))
			end
		end
		local ti = toneIndex(rng, prev)
		prev = ti
		local color = if key then o.keyColor elseif i % 2 == 0 then o.color else o.color2
		table.insert(list, chamfered(Vector3.new(width, h, depth), cf, graded(color, mid.Y, o.H, if key then 1 else TONES[ti]), { "topFrontBack", "bottomFrontBack" }, 0.2, negs))
	end
	for i = 1, n - 1 do
		local am = aStart - i * step
		local dir = Vector3.new(math.cos(am), math.sin(am), 0)
		local tan = Vector3.new(-math.sin(am), math.cos(am), 0)
		table.insert(list, piece("Part", Vector3.new(1.0, ro - ri - 0.6, D - 0.5), CFrame.fromMatrix(Vector3.new(0, cy, 0) + dir * ((ri + ro) / 2), -tan, dir), P.Mortar))
	end
end

-- a gable roof along X: ridge from o.x0 to o.x1 at height o.yR over z = o.zc, eaves at z = o.zc +- o.e at height o.yE.
-- An under-board, rows of individual shingles (1.5 x 1.6 x 0.1, a row every 1.35, odd rows half-offset, butts lifted,
-- 0.06 gaps, 3 tones), a darker ridge cap (into `roof`) and bargeboards on both gables (into `wood`)
local function shingleRoof(roof: { BasePart }, wood: { BasePart }, rng: Random, o: any)
	local x0, x1 = o.x0 - (o.overhang or 0.3), o.x1 + (o.overhang or 0.3)
	local zc, e, yE, yR = o.zc or 0, o.e, o.yE, o.yR
	local dy = yR - yE
	local Ls = math.sqrt(e * e + dy * dy)
	local L = x1 - x0
	local prev = nil
	for _, s in ipairs({ -1, 1 }) do
		local nrm = Vector3.new(0, e, s * dy) / Ls -- outward normal of this slope
		local d = Vector3.new(0, dy, -s * e) / Ls -- eave -> ridge
		local eave = Vector3.new(0, yE, zc + s * e)
		local function at(t: number, x: number, lift: number): Vector3
			return Vector3.new(x, 0, 0) + eave + d * t + nrm * lift
		end
		local frame = CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, nrm)
		local function place(pos: Vector3): CFrame
			return CFrame.new(pos) * frame
		end
		-- under-board
		table.insert(roof, piece("Part", Vector3.new(L, 0.12, Ls + 0.1), place(at(Ls / 2 - 0.05, (x0 + x1) / 2, -0.06)), scaled(P.WoodDark, 0.85)))
		-- shingle rows
		local tilt = math.atan2(0.08, 1.6) * (if s < 0 then 1 else -1)
		local rows = math.ceil((Ls - 0.15) / 1.35)
		for k = 0, rows - 1 do
			local t0 = k * 1.35 - 0.08
			local len = math.min(1.6, Ls - t0 + 0.02)
			if len < 0.3 then
				continue
			end
			local x = x0 - (if k % 2 == 1 then 0.78 else 0)
			while x < x1 - 0.05 do
				local a, b = math.max(x, x0), math.min(x + 1.5, x1)
				if b - a > 0.3 then
					local ti = toneIndex(rng, prev)
					prev = ti
					local col = scaled(o.color, ({ 1, 0.94, 0.88 })[ti])
					table.insert(roof, piece("Part", Vector3.new(b - a, 0.1, len), place(at(t0 + len / 2, (a + b) / 2, 0.1)) * CFrame.Angles(tilt, 0, 0), col))
				end
				x += 1.56
			end
		end
		-- ridge cap (one step darker) and the bargeboards
		table.insert(roof, piece("Part", Vector3.new(L + 0.1, 0.12, 0.62), place(at(Ls - 0.31, (x0 + x1) / 2, 0.22)), o.ridge))
		for _, xe in ipairs({ x0 - 0.075, x1 + 0.075 }) do
			table.insert(wood, piece("Part", Vector3.new(0.15, 0.34, Ls + 0.15), place(at(Ls / 2, xe, 0.04)), P.WoodDark))
		end
	end
end

-- the Toolbox scenery meshes of a gate kit (cliffs, rock faces, grass caps and their moss) copied as they are, from
-- the current template (or from the kit model the first time), at the same place: the remake keeps them exactly
local function carryMeshes(m: Model, propId: string, kitPath: { string }, names: { [string]: boolean }): number
	local folder = ServerStorage:FindFirstChild("MapProps")
	local src: Instance? = folder and folder:FindFirstChild(propId)
	if not src then
		src = ServerStorage:FindFirstChild("MapAssets")
		for _, n in ipairs(kitPath) do
			src = src and (src :: Instance):FindFirstChild(n)
		end
	end
	assert(src and src:IsA("Model"), `PropsBatch2: no source model for the meshes of {propId}`)
	local pv = (src :: Model):GetPivot()
	local count = 0
	for _, c in ipairs((src :: Model):GetChildren()) do
		if c:IsA("MeshPart") and names[c.Name] then
			local copy = c:Clone()
			copy.CFrame = pv:ToObjectSpace(c.CFrame)
			copy.Parent = m
			count += 1
		end
	end
	return count
end

---------------------------------------------------------------------
-- 03a ENTRY ARCH (kit Gates.EntryArch_Plains, 50.2 x 29.6 x 8.8; Zones.Plains.Plains_1.EntryArch, attr ZoneId). Two
-- stone piers of coursed blocks with capped tops, two octagonal logs on each (iron collars at their feet, two iron
-- bands around the pair, a log end on the short one), the main beam and the lower beam (chamfered timbers with iron
-- bands, rivets and pegs) and the braces, the name board in a wooden frame (both faces show), a gable roof of
-- individual red shingles on 4 timber trusses with a ridge beam, the two flags, iron brackets for the two lanterns
-- (the nested `lantern` props stay: iron frame, glass, warm light), moss at the foot of the piers. The passage stays
-- open (24 wide between the piers, 16.4 under the lower beam).
-- Parts: Piers, Logs, Timber, Iron, Roof, Flags, NameSign (keeps the NameGuiFront / Back of the game copy), Moss.
---------------------------------------------------------------------
function PropsBatch2.entry_arch(): Model
	local m = Instance.new("Model")
	m.Name = "entry_arch"
	local rng = Random.new(20261003)
	BEVEL_SELF = true
	local H = 29.6
	local stone, logs, wood, iron, roof, flags, mossList = {}, {}, {}, {}, {}, {}, {}
	for _, side in ipairs({ -1, 1 }) do
		local px = 16 * side
		-- stone pier 8 x 8 (4 courses of 1.25) and its cap (2 slabs 8.8 x 1.0)
		for k = 0, 3 do
			ringCourse(stone, rng, { cx = px, cz = 0, w = 8, d = 8, y = k * 1.25, h = 1.25, t = 2.0, odd = k % 2 == 1, color = P.Stone, H = H })
		end
		capSlabs(stone, rng, px, 0, 8.8, 8.8, 5.0, 1.0, P.StoneDark, H, 2)
		-- the logs: inner one (x 14.2) up to the beam, outer one (x 17.6) to y 17 with its log end
		local xi, xo = 14.2 * side, 17.6 * side
		table.insert(logs, octagon(3.0, 13.0, CFrame.new(xi, 12.5, 0), graded(P.WoodMid, 12.5, H, 1)))
		table.insert(logs, octagon(3.0, 11.0, CFrame.new(xo, 11.5, 0), graded(P.WoodLight, 11.5, H, 0.93)))
		table.insert(logs, octagon(2.5, 0.12, CFrame.new(xo, 17.03, 0), LOG_END))
		for _, x in ipairs({ xi, xo }) do
			table.insert(iron, octagon(3.3, 0.6, CFrame.new(x, 6.3, 0), P.Iron))
		end
		local lo, hi = math.min(xi, xo) - 1.5, math.max(xi, xo) + 1.5
		band(iron, lo, hi, -1.5, 1.5, 9.0, 0.8)
		band(iron, lo, hi, -1.5, 1.5, 15.6, 0.8) -- above the lantern bracket
		-- beam bands (rivets on both faces), lower-beam band, pegs through the main beam over the inner log
		for _, x in ipairs({ 11.6, 18.6 }) do
			table.insert(iron, piece("Part", Vector3.new(0.5, 2.74, 3.54), CFrame.new(side * x, 20.3, 0), P.Iron))
			for _, z in ipairs({ -1.77, 1.77 }) do
				rivet(iron, Vector3.new(side * x, 20.9, z))
				rivet(iron, Vector3.new(side * x, 19.7, z))
			end
		end
		table.insert(iron, piece("Part", Vector3.new(0.45, 1.74, 2.74), CFrame.new(side * 12.1, 17.2, 0), P.Iron))
		for _, y in ipairs({ 19.75, 20.85 }) do
			table.insert(wood, piece("Part", Vector3.new(0.34, 0.34, 3.5), CFrame.new(xi, y, 0), LOG_END))
		end
		table.insert(wood, timber(Vector3.new(1, 6, 1), CFrame.new(side * 11.2, 17.2, 0) * CFrame.Angles(0, 0, math.rad(42 * side)), graded(P.WoodDark, 17.2, H, 0.93)))
		-- flag: mount under the beam end, pole, cloth (blue right, red left), gold finial
		table.insert(wood, timber(Vector3.new(1.2, 3.4, 1.2), CFrame.new(side * 19.4, 18.4, 0), graded(P.WoodDark, 18.4, H, 1)))
		table.insert(flags, octagon(0.42, 6.0, CFrame.new(side * 20, 22.4, 0), P.WoodDark))
		local cloth = Instance.new("WedgePart")
		cloth.Size = Vector3.new(0.2, 2.4, 5)
		cloth.CFrame = CFrame.new(side * 22.6, 23.8, 0) * CFrame.Angles(0, math.rad(-90 * side), 0)
		cloth.Color = if side > 0 then rgb(74, 108, 220) else rgb(212, 52, 60)
		cloth.Material = Enum.Material.SmoothPlastic
		cloth.Anchored = true
		table.insert(flags, cloth)
		table.insert(flags, piece("Part", Vector3.new(0.6, 0.6, 0.6), CFrame.new(side * 20, 25.75, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0), P.Gold))
		-- lantern bracket: a plate on the inner log, an arm out over the lantern, a hook down to its handle
		local lx = 13.4 * side
		table.insert(iron, piece("Part", Vector3.new(0.8, 1.1, 0.08), CFrame.new(side * 14.1, 14.35, -1.54), P.Iron))
		rivet(iron, Vector3.new(side * 14.1, 14.7, -1.6))
		rivet(iron, Vector3.new(side * 14.1, 14.0, -1.6))
		local a0, a1 = Vector3.new(side * 14.1, 14.4, -1.55), Vector3.new(lx, 14.4, -2.3)
		table.insert(iron, piece("Part", Vector3.new(0.14, 0.14, (a1 - a0).Magnitude + 0.1), CFrame.lookAt((a0 + a1) / 2, a1), P.Iron))
		table.insert(iron, piece("Part", Vector3.new(0.1, 0.42, 0.1), CFrame.new(lx, 14.2, -2.3), P.Iron))
		-- moss on the ground against the pier (front, passage side, back)
		for _, spot in ipairs({ { 0, -1 }, { -1, 0 }, { 0, 1 } }) do
			local len = rng:NextNumber(1.6, 2.2)
			local fx, fz = spot[1] * side, spot[2]
			local pos = Vector3.new(px + fx * (4 + len * 0.18 - 0.08) + (if fx == 0 then rng:NextNumber(-2.5, 2.5) else 0), 0, fz * (4 + len * 0.18 - 0.08) + (if fz == 0 then rng:NextNumber(-2.5, 2.5) else 0))
			moss(mossList, rng, pos, if fx ~= 0 then math.rad(90) else 0, len)
		end
	end
	-- beams
	table.insert(wood, timber(Vector3.new(40, 2.6, 3.4), CFrame.new(0, 20.3, 0), graded(P.WoodDark, 20.3, H, 1)))
	table.insert(wood, timber(Vector3.new(30, 1.6, 2.6), CFrame.new(0, 17.2, 0), graded(P.WoodMid, 17.2, H, 0.93)))
	-- the name board (both faces show: the game copy's NameGuiFront / NameGuiBack) in a wooden frame, iron corners
	plain(m, "NameSign", Vector3.new(14, 4, 3.4), CFrame.new(0, 23.9, 0), P.WoodLight, { collide = true })
	for _, sy in ipairs({ -1, 1 }) do
		table.insert(wood, timber(Vector3.new(15.2, 0.5, 3.6), CFrame.new(0, 23.9 + sy * 2.25, 0), graded(P.WoodDark, 23.9, H, 0.93)))
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(wood, timber(Vector3.new(0.6, 4.0, 3.6), CFrame.new(sx * 7.3, 23.9, 0), graded(P.WoodDark, 23.9, H, 1)))
		for _, sy in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1.83, 1.83 }) do
				table.insert(iron, piece("Part", Vector3.new(0.7, 0.7, 0.06), CFrame.new(sx * 7.2, 23.9 + sy * 2.15, z), P.Iron))
				rivet(iron, Vector3.new(sx * 7.2, 23.9 + sy * 2.15, z + math.sign(z) * 0.04))
			end
		end
	end
	-- roof: 4 trusses (king post on the beam, tie beam under the eaves, 2 rafters), a ridge beam, eave purlins
	local e, yE, yR = 4.0, 26.4, 29.6
	local Ls = math.sqrt(e * e + (yR - yE) ^ 2)
	for _, tx in ipairs({ -16.8, -8.6, 8.6, 16.8 }) do
		table.insert(wood, timber(Vector3.new(0.7, 7.3, 0.7), CFrame.new(tx, 21.6 + 3.65, 0), graded(P.WoodDark, 25, H, 0.93)))
		table.insert(wood, timber(Vector3.new(0.6, 0.5, 7.6), CFrame.new(tx, 26.0, 0), graded(P.WoodDark, 26, H, 1)))
		for _, s in ipairs({ -1, 1 }) do
			local nrm = Vector3.new(0, e, s * (yR - yE)) / Ls
			local d = Vector3.new(0, yR - yE, -s * e) / Ls
			local pos = Vector3.new(tx, yE, s * e) + d * (Ls / 2) - nrm * 0.33
			table.insert(wood, piece("Part", Vector3.new(0.5, 0.42, Ls), CFrame.new(pos) * CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, nrm), graded(P.WoodDark, 28, H, 0.93)))
		end
	end
	table.insert(wood, timber(Vector3.new(35.4, 0.5, 0.5), CFrame.new(0, 29.1, 0), graded(P.WoodDark, 29, H, 1)))
	shingleRoof(roof, wood, rng, { x0 = -17.7, x1 = 17.7, e = e, yE = yE, yR = yR, color = rgb(196, 64, 58), ridge = rgb(156, 48, 44), overhang = 0.3 })

	merge(m, "Piers", stone, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Logs", logs, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Timber", wood, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Iron", iron, {})
	merge(m, "Roof", roof, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Flags", flags, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Moss", mossList, { shadow = false })
	local root = m:FindFirstChild("Piers") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "entry_arch")
	BEVEL_SELF = false
	return m
end

-- the door of a gate: Barrier (the PrimaryPart: GateController hides it and its children and turns their collision
-- off when the gate opens; ZoneService puts the gate's prompt in it) and the door pieces merged under it
local function barrierDoor(m: Model, size: Vector3, cf: CFrame, color: Color3, transparent: boolean): Part
	local barrier = plain(m, "Barrier", size, cf, color, { collide = true })
	if transparent then
		barrier.Transparency = 1
	end
	return barrier
end

---------------------------------------------------------------------
-- 03b PALISADE + WOODEN DOOR (kit Gates.Gate_Plains_2, 44.6 x 27.2 x 7.65; Zones.Plains.Plains_2.Gate: attr
-- SubZoneId, PrimaryPart Barrier, PriceSign SurfaceGuis, 2 Ember FirePoints). Two palisade towers of 4 octagonal
-- logs (log ends) on stone block bases, iron bands around them, the lintel (chamfered timber, iron bands, pegs), the
-- price board framed between 4 posts under a gable of shingles, two wall torches (iron bracket, stick, brazier, the
-- Ember kept), the double door of planks (V-joints over the dark Barrier core) with Z-braces, strap hinges, iron
-- bands and gold ring handles, moss at the foot of the towers.
-- Parts: Bases, Logs, Timber, Iron, Roof, Moss, PriceSign, Ember x2, Barrier (+ DoorPlanks, DoorBraces, DoorIron).
---------------------------------------------------------------------
function PropsBatch2.gate_palisade(): Model
	local m = Instance.new("Model")
	m.Name = "gate_palisade"
	local rng = Random.new(20261032)
	BEVEL_SELF = true
	local H = 27.2
	local stone, logs, wood, iron, roof, mossList = {}, {}, {}, {}, {}, {}
	for _, side in ipairs({ -1, 1 }) do
		-- tower base 10.5 x 7.5: 2 courses of 1.5
		for k = 0, 1 do
			ringCourse(stone, rng, { cx = 17 * side, cz = 0, w = 10.5, d = 7.5, y = k * 1.5, h = 1.5, t = 1.9, odd = k % 2 == 1, color = P.Stone, H = H })
		end
		-- 4 logs (d 2.6) from the base top, log ends; iron bands around them at y 7 and 16
		local prev = nil
		for _, spec in ipairs({ { 13.2, 21, P.WoodMid }, { 15.7, 23, P.WoodLight }, { 18.2, 22, P.WoodMid }, { 20.7, 20, P.WoodLight } }) do
			local x, top = spec[1] * side, spec[2]
			local ti = toneIndex(rng, prev)
			prev = ti
			table.insert(logs, octagon(2.6, top - 2.9, CFrame.new(x, (2.9 + top) / 2, 0), graded(spec[3], top / 2, H, TONES[ti])))
			table.insert(logs, octagon(2.2, 0.12, CFrame.new(x, top + 0.03, 0), LOG_END))
		end
		local lo, hi = math.min(11.9 * side, 22.0 * side), math.max(11.9 * side, 22.0 * side)
		band(iron, lo, hi, -1.3, 1.3, 7.0, 0.9)
		band(iron, lo, hi, -1.3, 1.3, 16.0, 0.9)
		-- the lintel's bands (by the opening) and pegs over the inner logs
		table.insert(iron, piece("Part", Vector3.new(0.5, 2.74, 3.34), CFrame.new(side * 11.3, 17.3, 0), P.Iron))
		for _, z in ipairs({ -1.67, 1.67 }) do
			rivet(iron, Vector3.new(side * 11.3, 17.9, z))
			rivet(iron, Vector3.new(side * 11.3, 16.7, z))
		end
		for _, y in ipairs({ 16.7, 17.9 }) do
			table.insert(wood, piece("Part", Vector3.new(0.32, 0.32, 3.3), CFrame.new(side * 13.2, y, 0), LOG_END))
		end
		-- wall torch on the 2nd log: iron bracket, stick leaning out, brazier cup; the Ember sits in the cup
		local tx = 15.6 * side
		table.insert(iron, piece("Part", Vector3.new(0.7, 1.0, 0.08), CFrame.new(tx, 10.6, -1.34), P.Iron))
		rivet(iron, Vector3.new(tx, 10.95, -1.4))
		rivet(iron, Vector3.new(tx, 10.25, -1.4))
		local s0, s1 = Vector3.new(tx, 10.2, -1.45), Vector3.new(tx, 12.15, -2.15)
		table.insert(wood, piece("Part", Vector3.new(0.4, (s1 - s0).Magnitude + 0.2, 0.4), CFrame.lookAt((s0 + s1) / 2, s1) * CFrame.Angles(math.rad(-90), 0, 0), P.WoodDark))
		table.insert(iron, octagon(1.1, 0.4, CFrame.new(tx, 12.25, -2.2), P.Iron))
		table.insert(iron, octagon(0.62, 0.2, CFrame.new(tx, 11.3, -1.8), P.Iron))
		local ember = plain(m, "Ember", Vector3.new(0.9, 0.9, 0.9), CFrame.new(tx, 12.6, -2.2), rgb(255, 140, 40), { shape = Enum.PartType.Ball, material = Enum.Material.Neon, shadow = false })
		local fire = Instance.new("Attachment")
		fire.Name = "FirePoint"
		fire.Position = Vector3.new(0, 0.2, 0)
		fire.Parent = ember
		-- sign posts (front and back of the inner log) from the lintel up to the roof, and a tie beam on them
		for _, z in ipairs({ -1.75, 1.75 }) do
			table.insert(wood, timber(Vector3.new(1.0, 5.7, 1.0), CFrame.new(side * 13.4, 18.6 + 2.85, z), graded(P.WoodDark, 21, H, 1)))
		end
		table.insert(wood, timber(Vector3.new(0.7, 0.6, 7.2), CFrame.new(side * 13.4, 23.85, 0), graded(P.WoodDark, 24, H, 0.93)))
		-- moss on the ground against the base's outer end (inside the old footprint's depth)
		for _, dz in ipairs({ -1.6, 1.4 }) do
			local len = rng:NextNumber(1.4, 1.9)
			moss(mossList, rng, Vector3.new(side * (22.25 + len * 0.18 - 0.08), 0, dz + rng:NextNumber(-0.4, 0.4)), math.rad(90), len)
		end
	end
	table.insert(wood, timber(Vector3.new(28.6, 2.6, 3.2), CFrame.new(0, 17.3, 0), graded(P.WoodDark, 17.3, H, 1)))
	-- the price board (both faces show) in its frame, a king post on it, the ridge beam, the shingle roof
	plain(m, "PriceSign", Vector3.new(12, 4, 1.2), CFrame.new(0, 21.3, 0), P.WoodLight, { collide = true })
	for _, sy in ipairs({ -1, 1 }) do
		table.insert(wood, timber(Vector3.new(13.2, 0.5, 1.4), CFrame.new(0, 21.3 + sy * 2.25, 0), graded(P.WoodDark, 21.3, H, 0.93)))
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(wood, timber(Vector3.new(0.6, 4.0, 1.4), CFrame.new(sx * 6.3, 21.3, 0), graded(P.WoodDark, 21.3, H, 1)))
		for _, sy in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -0.73, 0.73 }) do
				table.insert(iron, piece("Part", Vector3.new(0.6, 0.6, 0.06), CFrame.new(sx * 6.2, 21.3 + sy * 2.15, z), P.Iron))
			end
		end
	end
	table.insert(wood, timber(Vector3.new(0.6, 3.1, 0.6), CFrame.new(0, 23.8 + 1.55, 0), graded(P.WoodDark, 25, H, 1)))
	table.insert(wood, timber(Vector3.new(29.8, 0.5, 0.5), CFrame.new(0, 26.75, 0), graded(P.WoodDark, 26.7, H, 1)))
	for _, side in ipairs({ -1, 1 }) do
		table.insert(wood, timber(Vector3.new(0.6, 2.4, 0.6), CFrame.new(side * 13.4, 24.15 + 1.2, 0), graded(P.WoodDark, 25.5, H, 1)))
	end
	shingleRoof(roof, wood, rng, { x0 = -15.2, x1 = 15.2, e = 3.5, yE = 24.2, yR = 27.2, color = rgb(196, 64, 58), ridge = rgb(156, 48, 44), overhang = 0.3 })

	-- the door: Barrier = the dark core between the planks (it keeps the collision); planks 1.7 thick (both faces)
	local barrier = barrierDoor(m, Vector3.new(24, 16, 1.4), CFrame.new(0, 8, 0), scaled(P.WoodDark, 0.55), false)
	local planks, braces, doorIron = {}, {}, {}
	local pprev = nil
	for _, side in ipairs({ -1, 1 }) do
		local inner, outer = 0.06 * side, 12 * side
		local n = 10
		local w = (12 - 0.06 - 0.05 * (n - 1)) / n
		for i = 0, n - 1 do
			local x = inner + side * (w / 2 + i * (w + 0.05))
			local ti = toneIndex(rng, pprev)
			pprev = ti
			table.insert(planks, chamfered(Vector3.new(w, 15.95, 1.7), CFrame.new(x, 7.98, 0), graded(P.WoodMid, 8, H, TONES[ti]), { "vertical" }, 0.08))
		end
		local cx = 6.03 * side
		-- front: Z-brace (two rails and a diagonal), strap hinges on the outer edge; back: two iron bands
		for _, y in ipairs({ 2.6, 13.4 }) do
			table.insert(braces, timber(Vector3.new(11.2, 1.1, 0.35), CFrame.new(cx, y, -1.02), graded(P.WoodDark, y, H, 1)))
		end
		local p0, p1 = Vector3.new(outer - side * 1.0, 3.1, -1.02), Vector3.new(inner + side * 1.0, 12.9, -1.02)
		table.insert(braces, piece("Part", Vector3.new(1.0, (p1 - p0).Magnitude, 0.35), CFrame.lookAt((p0 + p1) / 2, (p0 + p1) / 2 + Vector3.new(0, 0, -1), (p1 - p0).Unit), graded(P.WoodDark, 8, H, 0.93)))
		for _, y in ipairs({ 5.4, 10.6 }) do
			table.insert(doorIron, piece("Part", Vector3.new(6.5, 0.55, 0.1), CFrame.new(outer - side * 3.25, y, -0.9), P.Iron))
			for k = 0, 8 do
				rivet(doorIron, Vector3.new(outer - side * (0.4 + k * 0.72), y, -0.96), 0.13)
			end
			table.insert(doorIron, piece("Part", Vector3.new(0.5, 0.9, 1.9), CFrame.new(outer - side * 0.1, y, 0), P.Iron)) -- hinge knuckle
		end
		for _, y in ipairs({ 3.0, 13.0 }) do
			table.insert(doorIron, piece("Part", Vector3.new(11.9, 0.9, 0.1), CFrame.new(cx, y, 0.9), P.Iron))
			for k = 0, 15 do
				rivet(doorIron, Vector3.new(inner + side * (0.4 + k * 0.74), y, 0.96), 0.13)
			end
		end
		-- gold ring handle on a brass plate by the seam
		local hx = 1.0 * side
		table.insert(doorIron, piece("Part", Vector3.new(0.9, 1.2, 0.08), CFrame.new(hx, 8.3, -0.89), P.Brass))
		for k = 0, 3 do
			local a = math.rad(45 + 90 * k)
			table.insert(doorIron, piece("Part", Vector3.new(0.85, 0.14, 0.14), CFrame.new(hx, 7.55, -1.05) * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.3, 0), P.Gold))
		end
	end
	merge(barrier :: any, "DoorPlanks", planks, {})
	merge(barrier :: any, "DoorBraces", braces, {})
	merge(barrier :: any, "DoorIron", doorIron, {})

	merge(m, "Bases", stone, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Logs", logs, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Timber", wood, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Iron", iron, {})
	merge(m, "Roof", roof, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Moss", mossList, { shadow = false })
	m:SetAttribute("BarrierDecorIsChildOfBarrier", true)
	m.PrimaryPart = barrier
	barrier.PivotOffset = barrier.CFrame:Inverse()
	m:SetAttribute("MapPropId", "gate_palisade")
	BEVEL_SELF = false
	return m
end

---------------------------------------------------------------------
-- 04 BARRICADE (kit Gates.Gate_Plains_3, 70.5 x 34.9 x 29.0 with the cliffs; Zones.Plains.Plains_3.Gate). The
-- stone arch of the gate rebuilt (plinths of 2 slabs, piers of 10 courses, impost caps, a round arch of 9 voussoirs
-- with V-grooved joints and a proud keystone), the price board in a wooden frame hung on ropes from iron eyes in the
-- arch, the barricade under the invisible Barrier (two pointed posts, chamfered planks nailed across in layers, rope
-- lines to iron rings on the piers, rope wraps), moss at the plinths. The Toolbox cliffs and grass caps are kept.
-- Parts: Piers, Arch, Sign, PriceSign, Moss, Cliff x4, GrassCap x2, Barrier (+ BarricadePosts, BarricadePlanks,
-- BarricadeRopes, BarricadeNails).
---------------------------------------------------------------------
function PropsBatch2.gate_barricade(): Model
	local m = Instance.new("Model")
	m.Name = "gate_barricade"
	local rng = Random.new(20261004)
	BEVEL_SELF = true
	local H = 26.7
	carryMeshes(m, "gate_barricade", { "Gates", "Gate_Plains_3" }, { Cliff = true, GrassCap = true })
	local stone, arch, sign, mossList = {}, {}, {}, {}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(stone, chamfered(Vector3.new(4.0, 0.98, 6.0), CFrame.new(side * 14.0, 0.49, 0), graded(P.StoneDark, 0.5, H, 0.93), { "topFrontBack", "topSides" }, 0.15))
		table.insert(stone, chamfered(Vector3.new(3.6, 0.98, 5.6), CFrame.new(side * 13.8, 1.49, 0), graded(P.StoneDark, 1.5, H, 1), { "topFrontBack", "topSides" }, 0.15))
		pier2(stone, rng, { cx = side * 13.5, cz = 0, w = 3.0, d = 5.0, y0 = 2.0, y1 = 15.4, n = 10, color = P.Stone, H = H })
		table.insert(stone, chamfered(Vector3.new(3.8, 0.6, 5.6), CFrame.new(side * 13.6, 15.7, 0), graded(P.StoneDark, 15.7, H, 1), { "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.15))
		-- iron rings on the piers' inner faces for the rope lines
		for _, y in ipairs({ 1.0, 5.0, 8.6, 12.0 }) do
			table.insert(sign, piece("Part", Vector3.new(0.1, 0.5, 0.5), CFrame.new(side * 12.0, y + side * 0.42, 0.5), P.Iron))
			rivet(sign, Vector3.new(side * 11.95, y + side * 0.42, 0.5), 0.18)
		end
		-- moss on the ground against the plinth (front and back)
		for _, sz in ipairs({ -1, 1 }) do
			local len = rng:NextNumber(1.4, 1.9)
			moss(mossList, rng, Vector3.new(side * 14 + rng:NextNumber(-1.0, 1.0), 0, sz * (3.0 + len * 0.18 - 0.08)), 0, len)
		end
	end
	-- the arch: inner springing (+-12, 16), inner apex 23, ring 3.4 thick, 9 voussoirs
	local ri = 13.786
	voussoirs(arch, rng, { cy = 23.0 - ri, ri = ri, ro = ri + 3.4, depth = 5.0, n = 9, sx = 12.0, keyUp = 0.4, keyDown = 0.25, keyDepth = 5.5, bedY = 16.0, bedX = 13.5, backX = 15.4, springExt = 5.4, color = P.Stone, color2 = P.StoneLight, keyColor = scaled(P.StoneDark, 1.1), H = H })
	-- the price board (its old place) in a frame, hung on two ropes from iron eyes in the arch's underside
	plain(m, "PriceSign", Vector3.new(12, 4, 0.5), CFrame.new(0, 18.2, -2.2), P.WoodLight, { collide = true })
	for _, sy in ipairs({ -1, 1 }) do
		table.insert(sign, timber(Vector3.new(12.8, 0.4, 0.7), CFrame.new(0, 18.2 + sy * 2.2, -2.2), graded(P.WoodDark, 18.2, H, 1)))
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(sign, timber(Vector3.new(0.4, 4.0, 0.7), CFrame.new(sx * 6.2, 18.2, -2.2), graded(P.WoodDark, 18.2, H, 0.93)))
		local soffit = (23.0 - ri) + math.sqrt(ri * ri - 25)
		table.insert(sign, piece("Part", Vector3.new(0.2, soffit - 20.4 + 0.1, 0.2), CFrame.new(sx * 5, (20.4 + soffit) / 2, -2.2), ROPE))
		table.insert(sign, piece("Part", Vector3.new(0.34, 0.34, 0.12), CFrame.new(sx * 5, soffit - 0.05, -2.2) * CFrame.Angles(0, 0, math.rad(45)), P.Iron))
		table.insert(sign, piece("Part", Vector3.new(0.5, 0.12, 0.5), CFrame.new(sx * 5, soffit + 0.02, -2.2), P.Iron))
		rivet(sign, Vector3.new(sx * 5, 20.45, -2.2), 0.2)
	end

	-- the barricade under the invisible Barrier (it keeps the collision)
	local barrier = barrierDoor(m, Vector3.new(24, 16, 2), CFrame.new(0, 8, 0), ROPE, true)
	local posts, planks, ropes, nails = {}, {}, {}, {}
	for _, sx in ipairs({ -1, 1 }) do
		local negs = {}
		local cf = CFrame.new(sx * 7, 6.5, 0)
		for _, e in ipairs(EDGES.vertical) do
			table.insert(negs, negWedge(cf, Vector3.new(1.3, 13, 1.3), e[1], e[2], e[3], 0.18))
		end
		table.insert(posts, chamfered(Vector3.new(1.3, 13, 1.3), cf, graded(P.WoodDark, 6.5, H, 1), { "topFrontBack", "topSides" }, 0.55, negs))
	end
	local function plank(len: number, y: number, z: number, rot: number, color: Color3)
		local cfp = CFrame.new(0, y, z) * CFrame.Angles(0, 0, math.rad(rot))
		table.insert(planks, timber(Vector3.new(len, 1.5, 0.55), cfp, color, 0.1))
		for _, px in ipairs({ -7, 7 }) do
			-- two nails where the plank crosses a post (on the plank's front face)
			local hit = cfp:PointToWorldSpace(Vector3.new(px / math.cos(math.rad(rot)), 0, if z < 0 then -0.3 else 0.3))
			for _, dy in ipairs({ -0.35, 0.35 }) do
				rivet(nails, hit + Vector3.new(0, dy, 0), 0.16)
			end
		end
	end
	plank(23.6, 3.2, -0.93, 3, graded(P.WoodMid, 3.2, H, 0.93))
	plank(23.6, 11.4, -0.93, -4, graded(P.WoodMid, 11.4, H, 1))
	plank(25.0, 7.0, -1.5, -24, graded(P.WoodLight, 7, H, 1))
	plank(25.0, 7.0, -2.07, 24, graded(P.WoodLight, 7, H, 0.93))
	plank(23.0, 4.4, 0.93, -2, graded(P.WoodMid, 4.4, H, 0.86))
	plank(23.0, 10.2, 0.93, 3, graded(P.WoodMid, 10.2, H, 0.93))
	-- rope lines between the posts and the piers (two segments, sagging), wraps around the posts
	for _, sx in ipairs({ -1, 1 }) do
		for _, y in ipairs({ 1.0, 5.0, 8.6, 12.0 }) do -- the top line under the posts' points (13 tall)
			local a = Vector3.new(sx * 7.65, y, 0.5)
			local b = Vector3.new(sx * 11.95, y + sx * 0.42, 0.5)
			local mid = (a + b) / 2 - Vector3.new(0, 0.3, 0)
			for _, seg in ipairs({ { a, mid }, { mid, b } }) do
				table.insert(ropes, piece("Part", Vector3.new(0.26, 0.26, (seg[2] - seg[1]).Magnitude + 0.1), CFrame.lookAt((seg[1] + seg[2]) / 2, seg[2]), ROPE))
			end
			table.insert(ropes, octagon(1.62, 0.32, CFrame.new(sx * 7, y, 0), scaled(ROPE, 0.9)))
		end
	end
	merge(barrier :: any, "BarricadePosts", posts, {})
	merge(barrier :: any, "BarricadePlanks", planks, {})
	merge(barrier :: any, "BarricadeRopes", ropes, {})
	merge(barrier :: any, "BarricadeNails", nails, {})

	merge(m, "Piers", stone, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Arch", arch, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Sign", sign, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Moss", mossList, { shadow = false })
	m:SetAttribute("BarrierDecorIsChildOfBarrier", true)
	m.PrimaryPart = barrier
	barrier.PivotOffset = barrier.CFrame:Inverse()
	m:SetAttribute("MapPropId", "gate_barricade")
	BEVEL_SELF = false
	return m
end

---------------------------------------------------------------------
-- 05 MINE DOOR (kit Gates.Gate_Plains_4, 85.6 x 58.3 x 38.2 with the rocks; Zones.Plains.Plains_4.Gate). A dark
-- stone door frame: plinths and caps (2 slabs, chamfered), piers of 9 courses with the cyan rune strips set in dark
-- plates, a flat arch lintel of 5 blocks with fanned joints, the capping slabs, the price plaque in its dark frame;
-- the two door leaves of big stone blocks (V-joints over the dark Barrier core), iron border straps with studs, dark
-- emblems in iron rims with the glowing rune diamonds, ring pulls, moss at the door's foot (on the door: it goes
-- with it) and at the piers. The Toolbox rock faces and their moss are kept.
-- Parts: Frame, Lintel, Runes, Plaque, PriceSign, MossPads, RockFace x5, Moss x3, Barrier (+ DoorStones, DoorIron,
-- DoorEmblems, DoorRunes, DoorMoss).
---------------------------------------------------------------------
function PropsBatch2.gate_mine(): Model
	local m = Instance.new("Model")
	m.Name = "gate_mine"
	local rng = Random.new(20261005)
	BEVEL_SELF = true
	local H = 22.3
	local DARK, MID, DEEP = rgb(96, 92, 110), rgb(62, 60, 78), rgb(150, 156, 168)
	local CYAN = rgb(90, 230, 255)
	carryMeshes(m, "gate_mine", { "Gates", "Gate_Plains_4" }, { RockFace = true, Moss = true })
	local frame, lintel, runes, plaque, mossList = {}, {}, {}, {}, {}
	for _, side in ipairs({ -1, 1 }) do
		local px = 13.7 * side
		table.insert(frame, chamfered(Vector3.new(4.2, 1.58, 2.85), CFrame.new(px, 0.79, -1.475), graded(MID, 0.8, H, 1), { "topFrontBack", "topSides" }, 0.18))
		table.insert(frame, chamfered(Vector3.new(4.2, 1.58, 2.85), CFrame.new(px, 0.79, 1.475), graded(MID, 0.8, H, 0.93), { "topFrontBack", "topSides" }, 0.18))
		pier2(frame, rng, { cx = px, cz = 0, w = 3.4, d = 5.0, y0 = 1.6, y1 = 14.4, n = 9, color = DARK, H = H })
		table.insert(frame, chamfered(Vector3.new(4.2, 1.6, 5.8), CFrame.new(px, 15.2, 0), graded(MID, 15.2, H, 1), { "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.2))
		-- the rune strip in a dark plate on the pier's front
		table.insert(plaque, chamfered(Vector3.new(1.6, 5.8, 0.3), CFrame.new(px, 8.0, -2.6), MID, { "vertical", "topFrontBack", "bottomFrontBack" }, 0.08))
		table.insert(runes, piece("Part", Vector3.new(0.9, 5.0, 0.3), CFrame.new(px, 8.0, -2.72), CYAN, { material = Enum.Material.Neon }))
		for _, sz in ipairs({ -1, 1 }) do
			local len = rng:NextNumber(1.5, 2.0)
			moss(mossList, rng, Vector3.new(px + rng:NextNumber(-1.0, 1.0), 0, sz * (2.9 + len * 0.18 - 0.08)), 0, len)
		end
	end
	-- the flat arch lintel (y 16 .. 21, 5.6 deep): 5 blocks with joints fanned from (0, -4), chamfered front edges
	local joints = { -16.0, -8.6, -2.3, 2.3, 8.6, 16.0 }
	local F = Vector2.new(0, -4)
	local function cut(xj: number, keepLeft: boolean): BasePart
		local v = (Vector2.new(xj, 16) - F).Unit
		local nrm = Vector2.new(v.Y, -v.X) -- right of the joint
		local q = F + v * ((18.5 - F.Y) / v.Y)
		local off = if keepLeft then 5 - 0.05 else -(5 - 0.05)
		local c = Vector3.new(q.X + nrm.X * off, q.Y + nrm.Y * off, 0)
		return piece("Part", Vector3.new(10, 20, 7.6), CFrame.fromMatrix(c, Vector3.new(nrm.X, nrm.Y, 0), Vector3.new(v.X, v.Y, 0)), P.Stone)
	end
	local lprev = nil
	for i = 1, 5 do
		local a, b = joints[i], joints[i + 1]
		local negs = {}
		if i > 1 then
			table.insert(negs, cut(a, false))
		end
		if i < 5 then
			table.insert(negs, cut(b, true))
		end
		local x0 = if i == 1 then a else a - 3
		local x1 = if i == 5 then b else b + 3
		local ti = toneIndex(rng, lprev)
		lprev = ti
		local key = i == 3
		local yb = if key then 15.75 else 16.0
		table.insert(lintel, chamfered(Vector3.new(x1 - x0, 21 - yb, if key then 5.9 else 5.6), CFrame.new((x0 + x1) / 2, (yb + 21) / 2, 0), graded(DARK, 18.5, H, if key then 1.08 else TONES[ti]), { "topFrontBack", "bottomFrontBack" }, 0.2, negs))
	end
	table.insert(lintel, piece("Part", Vector3.new(31.5, 4.4, 5.0), CFrame.new(0, 18.5, 0), P.Mortar))
	capSlabs(lintel, rng, 0, 0, 34, 6.4, 20.95, 1.35, MID, H, 4)
	-- the price plaque (its old place) in a dark frame with iron studs
	plain(m, "PriceSign", Vector3.new(12, 4, 0.5), CFrame.new(0, 18.5, -3.0), DEEP, { collide = true })
	for _, sy in ipairs({ -1, 1 }) do
		table.insert(plaque, chamfered(Vector3.new(13.0, 0.5, 0.45), CFrame.new(0, 18.5 + sy * 2.25, -2.95), MID, { "topFrontBack", "bottomFrontBack" }, 0.08))
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(plaque, chamfered(Vector3.new(0.5, 4.0, 0.45), CFrame.new(sx * 6.25, 18.5, -2.95), MID, { "vertical" }, 0.08))
		for _, sy in ipairs({ -1, 1 }) do
			rivet(plaque, Vector3.new(sx * 6.25, 18.5 + sy * 2.25, -3.18), 0.2)
		end
	end

	-- the door under Barrier (the dark core between the blocks; it keeps the collision and the gate's prompt)
	local barrier = barrierDoor(m, Vector3.new(24, 16, 3), CFrame.new(0, 8, 0.4), MID, false)
	local stones, doorIron, emblems, doorRunes, doorMoss = {}, {}, {}, {}, {}
	local sprev = nil
	for _, side in ipairs({ -1, 1 }) do
		local inner, outer = 0.08 * side, 12 * side
		local lw = 12 - 0.08
		for k = 0, 3 do
			local y0 = k * 4.0
			local w1 = lw * rng:NextNumber(0.38, 0.62) - GAP / 2
			for bi, seg in ipairs({ { 0, w1 }, { w1 + GAP, lw } }) do
				local a, b = inner + side * seg[1], inner + side * seg[2]
				local ti = toneIndex(rng, sprev)
				sprev = ti
				local col = if (k + bi) % 2 == 0 then DEEP else P.StoneLight
				table.insert(stones, chamfered(Vector3.new(math.abs(b - a), 3.95, 3.2), CFrame.new((a + b) / 2, y0 + 0.025 + 1.975, 0.4), graded(col, y0 + 2, H, TONES[ti]), { "vertical", "topFrontBack" }, 0.2))
			end
		end
		local cx = 6.04 * side
		-- iron border straps (front) with studs, the emblem (dark octagon in an iron rim) and its rune, a ring pull
		table.insert(doorIron, piece("Part", Vector3.new(11.6, 0.5, 0.1), CFrame.new(cx, 15.5, -1.25), P.Iron))
		table.insert(doorIron, piece("Part", Vector3.new(11.6, 0.5, 0.1), CFrame.new(cx, 0.5, -1.25), P.Iron))
		table.insert(doorIron, piece("Part", Vector3.new(0.5, 15.5, 0.1), CFrame.new(outer - side * 0.45, 8, -1.25), P.Iron))
		for k = 0, 14 do
			rivet(doorIron, Vector3.new(inner + side * (0.5 + k * 0.78), 15.5, -1.31), 0.18)
			rivet(doorIron, Vector3.new(inner + side * (0.5 + k * 0.78), 0.5, -1.31), 0.18)
		end
		for k = 0, 17 do
			rivet(doorIron, Vector3.new(outer - side * 0.45, 1.2 + k * 0.8, -1.31), 0.18)
		end
		local ex = 6.2 * side
		table.insert(doorIron, octagon(4.7, 0.25, CFrame.new(ex, 9.5, -1.3) * CFrame.Angles(math.rad(90), 0, 0), P.Iron))
		table.insert(emblems, octagon(4.2, 0.5, CFrame.new(ex, 9.5, -1.45) * CFrame.Angles(math.rad(90), 0, 0), MID))
		table.insert(doorRunes, piece("Part", Vector3.new(1.8, 1.8, 0.3), CFrame.new(ex, 9.5, -1.75) * CFrame.Angles(0, 0, math.rad(45)), CYAN, { material = Enum.Material.Neon }))
		table.insert(doorIron, piece("Part", Vector3.new(0.8, 0.8, 0.1), CFrame.new(side * 1.2, 7.0, -1.25), P.Iron))
		for k = 0, 3 do
			local a = math.rad(45 + 90 * k)
			table.insert(doorIron, piece("Part", Vector3.new(0.75, 0.13, 0.13), CFrame.new(side * 1.2, 6.35, -1.4) * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.27, 0), P.IronWorn))
		end
		-- moss growing at the door's foot (it goes with the door)
		local len = rng:NextNumber(1.6, 2.2)
		moss(doorMoss, rng, Vector3.new(side * rng:NextNumber(3.0, 9.0), 0, -1.2 - len * 0.18 + 0.1), 0, len)
	end
	-- the seam between the leaves (dark), on both faces
	table.insert(stones, piece("Part", Vector3.new(0.12, 15.9, 3.0), CFrame.new(0, 7.98, 0.4), MID))
	merge(barrier :: any, "DoorStones", stones, {})
	merge(barrier :: any, "DoorIron", doorIron, {})
	merge(barrier :: any, "DoorEmblems", emblems, {})
	merge(barrier :: any, "DoorRunes", doorRunes, { single = CYAN, material = Enum.Material.Neon, shadow = false })
	merge(barrier :: any, "DoorMoss", doorMoss, { shadow = false })

	merge(m, "Frame", frame, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Lintel", lintel, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Plaque", plaque, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Runes", runes, { single = CYAN, material = Enum.Material.Neon, shadow = false })
	merge(m, "MossPads", mossList, { shadow = false })
	m:SetAttribute("BarrierDecorIsChildOfBarrier", true)
	m.PrimaryPart = barrier
	barrier.PivotOffset = barrier.CFrame:Inverse()
	m:SetAttribute("MapPropId", "gate_mine")
	BEVEL_SELF = false
	return m
end

---------------------------------------------------------------------
-- shared (batch C): convex solids from planes (facet crystals, flames, roofs), rings of cut blocks, faceted fruit
---------------------------------------------------------------------
local NEON_PINK = rgb(150, 110, 255) -- today's crystal / rune colour (as Neon it renders pink)

-- the box (size at cf) minus negative parts whose own colours stay on the faces they cut (engraving, carving, facets)
local function subtractKeep(size: Vector3, cf: CFrame, color: Color3, negs: { BasePart }, material: Enum.Material?): BasePart
	local block = piece("Part", size, cf, color, { material = material })
	if #negs == 0 then
		return block
	end
	local function attempt(list: { BasePart }): BasePart?
		local ok, result = pcall(function()
			return GeometryService:SubtractAsync(block, list, { CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Automatic })
		end)
		if not ok or not result or not result[1] then
			return nil
		end
		local r = result[1] :: BasePart
		if r.Size.X < size.X * 0.1 or r.Size.Y < size.Y * 0.1 or r.Size.Z < size.Z * 0.1 then
			r:Destroy()
			return nil
		end
		return r
	end
	local r = attempt(negs)
	if not r then
		local reversed = {}
		for k = #negs, 1, -1 do
			table.insert(reversed, negs[k])
		end
		r = attempt(reversed)
	end
	for _, n in ipairs(negs) do
		n:Destroy()
	end
	if not r then
		warn("PropsBatch2: subtract failed, plain block kept")
		return block
	end
	block:Destroy()
	r.Anchored = true
	if material then
		r.Material = material
	end
	return r
end

-- a convex solid: its bounding box (bmin .. bmax in the solid's frame cf) cut by half-spaces { nx, ny, nz, d, colour? }
-- (outward normal n, n . p <= d inside; colour = "#RRGGBB" or a Color3 for the face it makes)
local function convexSolid(bmin: Vector3, bmax: Vector3, cf: CFrame, color: Color3, planes: { any }, material: Enum.Material?, extra: { BasePart }?): BasePart
	local negs = {}
	for _, x in ipairs(extra or {}) do
		table.insert(negs, x)
	end
	-- each cut is an 80-stud cube whose near face lies on the plane, centred (along the plane) on the solid's box: a
	-- solid far from its frame's origin (a roof 45 studs up) is still cut whole
	local c0 = (bmin + bmax) / 2
	for _, pl in ipairs(planes) do
		local n = Vector3.new(pl[1], pl[2], pl[3]).Unit
		local helper = if math.abs(n.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
		local x = helper:Cross(n).Unit
		local y = n:Cross(x).Unit
		local c = if type(pl[5]) == "string" then Color3.fromHex(pl[5]) elseif typeof(pl[5]) == "Color3" then pl[5] else color
		table.insert(negs, piece("Part", Vector3.new(80, 80, 80), cf * CFrame.fromMatrix(n * (pl[4] + 40) + (c0 - n * c0:Dot(n)), x, y), c, { material = material }))
	end
	local pad = Vector3.new(0.02, 0.02, 0.02)
	return subtractKeep(bmax - bmin + pad, cf * CFrame.new((bmin + bmax) / 2), color, negs, material)
end

-- the planes of a pyramid from the apex down to a closed ring of points (all in one frame), normals pointing away from
-- `inside` (a point inside the solid); colours cycle through `colors`
local function pyramidPlanes(apex: Vector3, ring: { Vector3 }, inside: Vector3, colors: { Color3 }, out: { any })
	for k = 1, #ring do
		local a, b = ring[k], ring[k % #ring + 1]
		local n = (a - apex):Cross(b - apex).Unit
		if n:Dot(apex - inside) < 0 then
			n = -n
		end
		table.insert(out, { n.X, n.Y, n.Z, n:Dot(apex), colors[(k - 1) % #colors + 1] })
	end
end

-- a stylized flame (Neon): a 6-sided bipyramid from its foot (y 0) out to radius r at height hw and up to a leaning tip
-- at height h, facets in 3 tones of `color`, at cf
local function flame(cf: CFrame, r: number, hw: number, h: number, color: Color3, lean: Vector3?): BasePart
	local ring = {}
	for k = 0, 5 do
		local a = math.rad(k * 60 + 15)
		table.insert(ring, Vector3.new(math.cos(a) * r, hw, math.sin(a) * r))
	end
	local tones = { color, scaled(color, 1.12), scaled(color, 0.9) }
	local planes = {}
	local inside = Vector3.new(0, hw, 0)
	pyramidPlanes(Vector3.zero, ring, inside, tones, planes)
	pyramidPlanes(Vector3.new(0, h, 0) + (lean or Vector3.zero), ring, inside, tones, planes)
	local l = lean or Vector3.zero
	return convexSolid(Vector3.new(-r - 0.1 + math.min(l.X, 0), 0, -r - 0.1 + math.min(l.Z, 0)), Vector3.new(r + 0.1 + math.max(l.X, 0), h, r + 0.1 + math.max(l.Z, 0)), cf, color, planes, Enum.Material.Neon)
end

-- a 16-sided prism (w across the flats, h tall) as ONE convex part at cf (axis = the frame's Y); extra = more negative
-- parts (engraving) whose own colours stay on the faces they cut
local function prism16(w: number, h: number, cf: CFrame, color: Color3, extra: { BasePart }?): BasePart
	local planes = { { 0, 1, 0, h / 2 }, { 0, -1, 0, h / 2 } }
	for k = 0, 15 do
		local a = k * math.pi / 8
		table.insert(planes, { math.cos(a), 0, math.sin(a), w / 2 })
	end
	local r = w / 2 / math.cos(math.pi / 16) + 0.02
	return convexSolid(Vector3.new(-r, -h / 2, -r), Vector3.new(r, h / 2, r), cf, color, planes, nil, extra)
end

-- a ring of n cut stone blocks around the model's Y axis: outer faces flat on the polygon of vertex radius o.ro (block 0
-- centred on angle o.a0 + half a block), inner ends at o.ri, from o.y0 to o.y0 + o.h (0.05 bed joint), 0.1 radial joints
-- (cut planes) with V-grooved outer corners, the top outer edge chamfered (o.c), face jitter, tones, gradient; a dark
-- 16-sided mortar core behind the joints
local function ringBlocks(list: { BasePart }, rng: Random, o: any)
	local n = o.n
	local step = 2 * math.pi / n
	local bh = o.h - 0.05
	local yc = o.y0 + 0.025 + bh / 2
	local axis = Vector3.new(0, yc, 0)
	local A = o.ro * math.cos(step / 2)
	local prev = nil
	for i = 0, n - 1 do
		local a1 = (o.a0 or 0) - step / 2 + i * step
		local a2 = a1 + step
		local am = (a1 + a2) / 2
		local dir = Vector3.new(math.cos(am), 0, math.sin(am))
		local tan = Vector3.new(-math.sin(am), 0, math.cos(am))
		local outer = A + (if o.noJitter then 0 else jit(rng))
		local depth = outer - o.ri
		local mid = axis + dir * (o.ri + depth / 2)
		local width = 2 * outer * math.tan(step / 2) + 0.6
		local cf = CFrame.fromMatrix(mid, tan, Vector3.yAxis) -- local Z = -dir: the outer face is local -Z
		local size = Vector3.new(width, bh, depth)
		local negs = {}
		local rm = (o.ri + outer) / 2
		for _, bound in ipairs({ { a1, -1 }, { a2, 1 } }) do
			local ang = bound[1] - bound[2] * (0.05 / rm)
			local t = Vector3.new(-math.sin(ang), 0, math.cos(ang)) * bound[2] -- out of the block
			local x = Vector3.yAxis:Cross(t).Unit
			local y = t:Cross(x).Unit
			table.insert(negs, piece("Part", Vector3.new(80, 80, 80), CFrame.fromMatrix(axis + t * 40, x, y), o.color))
			local edge = axis + dir * outer + tan * (outer * math.tan(ang - am))
			table.insert(negs, piece("Part", Vector3.new(0.2, bh + 1, 0.2), CFrame.fromMatrix(edge, (dir + tan).Unit, Vector3.yAxis), o.color))
		end
		table.insert(negs, negWedge(cf, size, "X", 1, -1, o.c or 0.2))
		local ti = toneIndex(rng, prev)
		prev = ti
		table.insert(list, chamfered(size, cf, graded(o.color, yc, o.H, TONES[ti]), {}, 0, negs))
	end
	if not o.noCore then
		table.insert(list, prism16(2 * (A - 0.6), bh, CFrame.new(0, yc, 0), P.Mortar))
	end
end

-- a 16-sided disc / prism (w across the flats, h tall) at cf (axis = the frame's Y), into a piece list
local function disc16(list: { BasePart }, w: number, h: number, cf: CFrame, color: Color3)
	table.insert(list, prism16(w, h, cf, color))
end

-- a faceted fruit (a cube of side s with its 12 edges cut, about a rhombicuboctahedron) at cf
local function fruitPiece(s: number, cf: CFrame, color: Color3): BasePart
	return chamfered(Vector3.new(s, s * 0.94, s), cf, color, { "vertical", "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }, s * 0.29)
end

---------------------------------------------------------------------
-- 16 REBIRTH ALTAR (kit Hub.Station_RebirthAltar, 36 x 29 x 38.4; Hub.RebirthAltar: the Priest's marker, its Interact
-- prompt opens the Rebirth window). A round platform of 3 tiers of cut blocks (radii 18 / 14 / 10, 2 tall each, the
-- top one with an inner ring of flags), wide layered steps in front (6 risers of 1.0 over the old 3 steps' run), 4
-- columns on the middle tier (carved base, fluted drums with a band, carved capital, a gold bowl holding a stylized
-- pink flame), a carved octagonal pedestal with an engraved gold ring, Agent A's faceted crystals standing on it
-- (Blender_Exports/Props/facets/rebirth_altar__*.json: the main one now stands on the ring), 6 pink rune circles in
-- the floor, light moss. The Interact part (prompt + NameTag) is kept on every copy by SyncMapProps; the main crystal
-- carries today's PointLight and the EffectPoint attachment at the same place. Colours: today's stone (165,172,185 /
-- 150,156,168 / 104,110,124), gold 255,201,60, Neon 150,110,255.
-- Parts: Platform, Columns, Pedestal, Gold, CrystalMain, Crystals, Flames, Runes, Moss (9; the old one had 34).
---------------------------------------------------------------------
-- facet planes of Agent A's 4 crystals (generated from the JSON faces: outward normal, offset, face colour; the base's
-- 2 quads are one plane), in each crystal's own frame (origin = the centre of its flat base)
PropsBatch2.ALTAR_CRYSTALS = {
	crystal_main = { min = { -3.2, 0.0, -2.771 }, max = { 3.2, 19.5, 2.771 }, planes = {
		{ 0.8392, -0.2466, 0.4846, 2.2831, "#8763E6" },
		{ 0.8660, 0.0000, 0.5000, 2.7712, "#966EFF" },
		{ 0.7781, 0.4392, 0.4491, 8.4621, "#A988FF" },
		{ 0.7684, 0.4613, 0.4435, 8.8143, "#B69AFF" },
		{ 0.0000, -0.2464, 0.9692, 2.2833, "#8E6EE6" },
		{ 0.0000, 0.0000, 1.0000, 2.7710, "#9E7AFF" },
		{ 0.0000, 0.3989, 0.9170, 7.9660, "#9E7AFF" },
		{ 0.0000, 0.4001, 0.9165, 7.9850, "#B69AFF" },
		{ -0.8392, -0.2468, 0.4846, 2.2826, "#8763E6" },
		{ -0.8660, 0.0000, 0.5000, 2.7712, "#966EFF" },
		{ -0.8019, 0.3779, 0.4628, 7.7053, "#A988FF" },
		{ -0.8057, 0.3669, 0.4650, 7.5300, "#B69AFF" },
		{ -0.8392, -0.2466, -0.4846, 2.2831, "#8E6EE6" },
		{ -0.8660, 0.0000, -0.5000, 2.7712, "#9E7AFF" },
		{ -0.7943, 0.3986, -0.4585, 7.9626, "#9E7AFF" },
		{ -0.7940, 0.3995, -0.4583, 7.9768, "#B69AFF" },
		{ 0.0000, -0.2464, -0.9692, 2.2833, "#8763E6" },
		{ 0.0000, 0.0000, -1.0000, 2.7710, "#966EFF" },
		{ 0.0000, 0.4388, -0.8986, 8.4577, "#A988FF" },
		{ 0.0000, 0.4609, -0.8875, 8.8095, "#B69AFF" },
		{ 0.8392, -0.2468, -0.4846, 2.2826, "#8E6EE6" },
		{ 0.8660, 0.0000, -0.5000, 2.7712, "#9E7AFF" },
		{ 0.7698, 0.4583, -0.4443, 8.6963, "#9E7AFF" },
		{ 0.7553, 0.4894, -0.4359, 9.1923, "#B69AFF" },
		{ 0.0000, -1.0000, 0.0000, 0.0000, "#7858CC" },
	} },
	crystal_small_1 = { min = { -1.256, 0.0, -1.256 }, max = { 1.256, 8.2, 1.256 }, planes = {
		{ 0.6858, -0.2439, 0.6858, 0.9278, "#8763E6" },
		{ 0.7071, 0.0000, 0.7071, 1.1257, "#966EFF" },
		{ 0.6579, 0.3665, 0.6579, 3.1000, "#AD8EFF" },
		{ 0.6436, 0.4141, 0.6436, 3.4212, "#BA9FFF" },
		{ -0.2515, -0.2440, 0.9366, 0.9279, "#9372E6" },
		{ -0.2593, 0.0000, 0.9658, 1.1259, "#A37FFF" },
		{ -0.2372, 0.3969, 0.8867, 3.2554, "#A37FFF" },
		{ -0.2290, 0.4638, 0.8558, 3.7073, "#BA9FFF" },
		{ -0.9364, -0.2447, 0.2515, 0.9273, "#8763E6" },
		{ -0.9658, 0.0000, 0.2593, 1.1259, "#966EFF" },
		{ -0.8838, 0.4038, 0.2364, 3.2917, "#AD8EFF" },
		{ -0.8508, 0.4736, 0.2276, 3.7629, "#BA9FFF" },
		{ -0.6858, -0.2439, -0.6858, 0.9278, "#9372E6" },
		{ -0.7071, 0.0000, -0.7071, 1.1257, "#A37FFF" },
		{ -0.6542, 0.3794, -0.6542, 3.1664, "#A37FFF" },
		{ -0.6367, 0.4351, -0.6367, 3.5421, "#BA9FFF" },
		{ 0.2515, -0.2440, -0.9366, 0.9279, "#8763E6" },
		{ 0.2593, 0.0000, -0.9658, 1.1259, "#966EFF" },
		{ 0.2423, 0.3474, -0.9059, 3.0008, "#AD8EFF" },
		{ 0.2387, 0.3835, -0.8922, 3.2446, "#BA9FFF" },
		{ 0.9364, -0.2447, -0.2515, 0.9273, "#9372E6" },
		{ 0.9658, 0.0000, -0.2593, 1.1259, "#A37FFF" },
		{ 0.9080, 0.3415, -0.2429, 2.9710, "#A37FFF" },
		{ 0.8966, 0.3723, -0.2399, 3.1792, "#BA9FFF" },
		{ 0.0000, -1.0000, 0.0000, 0.0000, "#7858CC" },
	} },
	crystal_small_2 = { min = { -1.159, 0.0, -1.159 }, max = { 1.159, 7.4, 1.159 }, planes = {
		{ -0.2498, -0.2527, 0.9347, 0.8541, "#8763E6" },
		{ -0.2582, 0.0000, 0.9661, 1.0394, "#966EFF" },
		{ -0.2386, 0.3982, 0.8857, 2.9455, "#AD8EFF" },
		{ -0.2297, 0.4694, 0.8526, 3.3779, "#BA9FFF" },
		{ -0.9350, -0.2516, 0.2499, 0.8550, "#9372E6" },
		{ -0.9661, 0.0000, 0.2582, 1.0394, "#A37FFF" },
		{ -0.8835, 0.4034, 0.2380, 2.9670, "#A37FFF" },
		{ -0.8471, 0.4799, 0.2282, 3.4314, "#BA9FFF" },
		{ -0.6843, -0.2520, -0.6843, 0.8547, "#8763E6" },
		{ -0.7071, 0.0000, -0.7071, 1.0394, "#966EFF" },
		{ -0.6546, 0.3782, -0.6546, 2.8530, "#AD8EFF" },
		{ -0.6355, 0.4385, -0.6355, 3.2194, "#BA9FFF" },
		{ 0.2498, -0.2527, -0.9347, 0.8541, "#9372E6" },
		{ 0.2582, 0.0000, -0.9661, 1.0394, "#A37FFF" },
		{ 0.2442, 0.3448, -0.9064, 2.7009, "#A37FFF" },
		{ 0.2404, 0.3820, -0.8924, 2.9267, "#BA9FFF" },
		{ 0.9350, -0.2516, -0.2499, 0.8550, "#8763E6" },
		{ 0.9661, 0.0000, -0.2582, 1.0394, "#966EFF" },
		{ 0.9094, 0.3360, -0.2450, 2.6580, "#AD8EFF" },
		{ 0.8972, 0.3697, -0.2417, 2.8629, "#BA9FFF" },
		{ 0.6843, -0.2520, 0.6843, 0.8547, "#9372E6" },
		{ 0.7071, 0.0000, 0.7071, 1.0394, "#A37FFF" },
		{ 0.6585, 0.3642, 0.6585, 2.7892, "#A37FFF" },
		{ 0.6431, 0.4157, 0.6431, 3.1018, "#BA9FFF" },
		{ 0.0000, -1.0000, 0.0000, 0.0000, "#7858CC" },
	} },
	crystal_small_3 = { min = { -0.893, 0.0, -0.936 }, max = { 0.893, 5.5, 0.936 }, planes = {
		{ 0.3287, -0.2758, 0.9033, 0.6721, "#8763E6" },
		{ 0.3420, 0.0000, 0.9397, 0.8231, "#966EFF" },
		{ 0.3160, 0.3909, 0.8645, 2.1642, "#AD8EFF" },
		{ 0.3095, 0.4326, 0.8468, 2.3484, "#BA9FFF" },
		{ -0.6180, -0.2752, 0.7364, 0.6723, "#9372E6" },
		{ -0.6429, 0.0000, 0.7660, 0.8230, "#A37FFF" },
		{ -0.5829, 0.4237, 0.6933, 2.2712, "#A37FFF" },
		{ -0.5641, 0.4812, 0.6710, 2.5254, "#BA9FFF" },
		{ -0.9470, -0.2745, -0.1669, 0.6728, "#8763E6" },
		{ -0.9848, 0.0000, -0.1736, 0.8230, "#966EFF" },
		{ -0.8971, 0.4128, -0.1575, 2.2353, "#AD8EFF" },
		{ -0.8715, 0.4659, -0.1530, 2.4701, "#BA9FFF" },
		{ -0.3287, -0.2758, -0.9033, 0.6721, "#9372E6" },
		{ -0.3420, 0.0000, -0.9397, 0.8231, "#A37FFF" },
		{ -0.3190, 0.3694, -0.8728, 2.0941, "#A37FFF" },
		{ -0.3148, 0.3985, -0.8614, 2.2229, "#BA9FFF" },
		{ 0.6180, -0.2752, -0.7364, 0.6723, "#8763E6" },
		{ 0.6429, 0.0000, -0.7660, 0.8230, "#966EFF" },
		{ 0.6060, 0.3362, -0.7209, 1.9859, "#AD8EFF" },
		{ 0.6046, 0.3423, -0.7192, 2.0130, "#BA9FFF" },
		{ 0.9470, -0.2745, 0.1669, 0.6728, "#9372E6" },
		{ 0.9848, 0.0000, 0.1736, 0.8230, "#A37FFF" },
		{ 0.9238, 0.3468, 0.1622, 2.0200, "#A37FFF" },
		{ 0.9184, 0.3612, 0.1613, 2.0841, "#BA9FFF" },
		{ -0.0000, -1.0000, 0.0000, 0.0000, "#7858CC" },
	} },
}
-- the JSON "place" fields: position and orientation (degrees, Roblox order) relative to the altar pivot
PropsBatch2.ALTAR_CRYSTAL_PLACE = {
	crystal_main = { 0, 9.7, 0, 0, 20, 0 },
	crystal_small_1 = { -3.3, 9.6, 1.1, 14, 0, 22 },
	crystal_small_2 = { 3.2, 9.6, -1.2, -6, 40, -20 },
	crystal_small_3 = { 0.9, 9.6, 3.1, -24, 0, -8 },
}

local function crystalPiece(name: string): BasePart
	local data = PropsBatch2.ALTAR_CRYSTALS[name]
	local p = PropsBatch2.ALTAR_CRYSTAL_PLACE[name]
	local cf = CFrame.new(p[1], p[2], p[3]) * CFrame.fromOrientation(math.rad(p[4]), math.rad(p[5]), math.rad(p[6]))
	return convexSolid(Vector3.new(table.unpack(data.min)), Vector3.new(table.unpack(data.max)), cf, NEON_PINK, data.planes, Enum.Material.Neon)
end

function PropsBatch2.rebirth_altar(): Model
	local m = Instance.new("Model")
	m.Name = "rebirth_altar"
	local rng = Random.new(20261016)
	BEVEL_SELF = true
	local H = 29
	local STONE_TOP, STONE, STONE_DARK = rgb(165, 172, 185), P.Stone, P.StoneDark
	local platform, columns, pedestal, gold, runes, flames, mossList = {}, {}, {}, {}, {}, {}, {}
	local front = math.rad(270) -- -Z

	-- 1. platform: 3 tiers of cut blocks (a block centred on the front), the top one with an inner ring of flags
	ringBlocks(platform, rng, { n = 20, ro = 18, ri = 13.4, y0 = 0, h = 2, color = STONE_DARK, H = H, c = 0.25, a0 = front })
	ringBlocks(platform, rng, { n = 16, ro = 14, ri = 9.4, y0 = 2, h = 2, color = STONE, H = H, c = 0.25, a0 = front + math.rad(11.25) })
	ringBlocks(platform, rng, { n = 14, ro = 10, ri = 6.4, y0 = 4, h = 2, color = STONE_TOP, H = H, c = 0.22, a0 = front })
	ringBlocks(platform, rng, { n = 10, ro = 6.6, ri = 3.0, y0 = 4, h = 2, color = scaled(STONE_TOP, 0.97), H = H, c = 0.12, a0 = front + math.rad(18), noJitter = true })
	-- the stairs: 6 risers of 1.0 (the old 3 steps of 2.05 cut in two), each 3 slabs with joints, wider at the bottom
	local stairs = {
		{ -20.4, -15.5, 12.0 }, { -18.3, -15.5, 11.6 }, { -16.2, -11.0, 11.2 },
		{ -14.1, -11.0, 10.8 }, { -12.0, -7.0, 10.4 }, { -9.9, -7.0, 10.0 },
	}
	for k, s in ipairs(stairs) do
		local z0, z1, w = s[1], s[2], s[3]
		local y0 = k - 1
		local lens, total = {}, 0
		for i = 1, 3 do
			lens[i] = rng:NextNumber(0.8, 1.2)
			total += lens[i]
		end
		local x = -w / 2
		local prev = nil
		for i = 1, 3 do
			local len = lens[i] / total * (w - 0.2)
			local ti = toneIndex(rng, prev)
			prev = ti
			local sets = { "topFrontBack" }
			if i == 1 or i == 3 then
				table.insert(sets, "topSides")
			end
			table.insert(platform, chamfered(Vector3.new(len, 0.98, z1 - z0), CFrame.new(x + len / 2, y0 + 0.49, (z0 + z1) / 2), graded(if k % 2 == 1 then STONE else STONE_DARK, y0 + 0.5, H, TONES[ti]), sets, 0.16))
			x += len + 0.1
		end
		table.insert(platform, piece("Part", Vector3.new(w - 0.4, 0.95, z1 - z0 - 0.3), CFrame.new(0, y0 + 0.47, (z0 + z1) / 2 + 0.15), P.Mortar))
	end
	merge(m, "Platform", platform, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 2. the 4 columns on the middle tier (radius 12, at 45 / 135 / 225 / 315 degrees)
	for k = 0, 3 do
		local a = math.rad(45 + 90 * k)
		local x, z = 12 * math.cos(a), 12 * math.sin(a)
		local face = CFrame.new(x, 0, z) * CFrame.Angles(0, -a, 0) -- local +X = outward: a square side toward the centre
		table.insert(columns, chamfered(Vector3.new(3.6, 0.8, 3.6), face * CFrame.new(0, 4.4, 0), graded(STONE_DARK, 4.4, H, 0.93), { "topFrontBack", "topSides", "vertical" }, 0.18))
		table.insert(columns, octagon(3.0, 0.4, face * CFrame.new(0, 5.0, 0), graded(STONE, 5, H, 1)))
		table.insert(columns, octagon(2.7, 0.2, face * CFrame.new(0, 5.3, 0), graded(STONE_DARK, 5.3, H, 1)))
		table.insert(columns, piece("Part", Vector3.new(1.5, 12.6, 1.5), face * CFrame.new(0, 11.7, 0), P.Mortar))
		local prev = nil
		for _, span in ipairs({ { 5.4, 11.45 }, { 11.95, 18.0 } }) do
			local ti = toneIndex(rng, prev)
			prev = ti
			local h = span[2] - span[1] - 0.05
			table.insert(columns, octagon(2.5, h, face * CFrame.new(0, span[1] + 0.025 + h / 2, 0), graded(STONE, (span[1] + span[2]) / 2, H, TONES[ti]), true))
		end
		table.insert(columns, octagon(2.8, 0.5, face * CFrame.new(0, 11.7, 0), graded(STONE_DARK, 11.7, H, 1)))
		table.insert(columns, octagon(2.7, 0.25, face * CFrame.new(0, 18.125, 0), graded(STONE_DARK, 18.1, H, 1)))
		-- capital: echinus (deep bevel underneath) and abacus
		local eCF = face * CFrame.new(0, 18.65, 0)
		local vert = {}
		for _, e in ipairs(EDGES.vertical) do
			table.insert(vert, negWedge(eCF, Vector3.new(3.2, 0.8, 3.2), e[1], e[2], e[3], 0.15))
		end
		table.insert(columns, chamfered(Vector3.new(3.2, 0.8, 3.2), eCF, graded(STONE, 18.6, H, 1), { "bottomFrontBack", "bottomSides" }, 0.4, vert))
		table.insert(columns, chamfered(Vector3.new(3.7, 0.6, 3.7), face * CFrame.new(0, 19.35, 0), graded(STONE_DARK, 19.3, H, 1), { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.16))
		-- the gold bowl and its pink flame (static, as today's)
		table.insert(gold, octagon(1.9, 0.3, face * CFrame.new(0, 19.8, 0), P.Gold))
		table.insert(gold, octagon(2.2, 0.12, face * CFrame.new(0, 20.0, 0), scaled(P.Gold, 0.94)))
		table.insert(flames, flame(CFrame.new(x, 19.9, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), 0.75, 1.0, 3.0, NEON_PINK, Vector3.new(0.12, 0, 0.06)))
		-- light moss at the column's foot
		moss(mossList, rng, (face * CFrame.new(-(1.8 + 0.18 - 0.05), 3.98, rng:NextNumber(-0.8, 0.8))).Position, -a - math.pi / 2, 1.0)
	end
	merge(m, "Columns", columns, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 3. pedestal: plinth, a body with a carved panel on each of its 8 faces, a top moulding (dark stone)
	table.insert(pedestal, octagon(7.8, 0.5, CFrame.new(0, 6.25, 0), graded(STONE_DARK, 6.2, H, 0.93)))
	local bodyCF = CFrame.new(0, 7.45, 0)
	local panels = {}
	for k = 0, 7 do
		local a = k * math.pi / 4
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		table.insert(panels, piece("Part", Vector3.new(1.55, 1.1, 0.4), CFrame.lookAt(bodyCF.Position + dir * (3.4 - 0.1 + 0.2), bodyCF.Position + dir * 10), scaled(STONE_DARK, 0.78)))
	end
	local c8 = 6.8 / (2 + math.sqrt(2))
	local vert8 = {}
	for _, e in ipairs(EDGES.vertical) do
		table.insert(vert8, negWedge(bodyCF, Vector3.new(6.8, 1.9, 6.8), e[1], e[2], e[3], c8))
	end
	table.insert(pedestal, chamfered(Vector3.new(6.8, 1.9, 6.8), bodyCF, graded(STONE_DARK, 7.4, H, 1), {}, 0, vert8, panels))
	table.insert(pedestal, octagon(7.4, 0.5, CFrame.new(0, 8.65, 0), graded(STONE_DARK, 8.6, H, 0.93)))
	merge(m, "Pedestal", pedestal, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 4. the engraved gold ring (16-sided, 8.4 across, y 8.9 .. 9.7): a groove line and a diamond notch on each face
	local marks = {}
	for f = 0, 15 do
		local a = f * math.pi / 8
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local at = Vector3.new(0, 9.3, 0) + dir * 4.2
		local look = CFrame.lookAt(at, at + dir)
		table.insert(marks, piece("Part", Vector3.new(1.2, 0.07, 0.12), look * CFrame.new(0, 0.18, 0), P.Brass))
		table.insert(marks, piece("Part", Vector3.new(0.24, 0.24, 0.12), look * CFrame.new(0, -0.12, 0) * CFrame.Angles(0, 0, math.rad(45)), P.Brass))
	end
	table.insert(gold, prism16(8.4, 0.8, CFrame.new(0, 9.3, 0), P.Gold, marks))
	merge(m, "Gold", gold, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 5. the crystals (no collision, as today): the main one with today's light and effect point
	local main = merge(m, "CrystalMain", { crystalPiece("crystal_main") }, { material = Enum.Material.Neon, shadow = false })
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color = 30, 1, NEON_PINK
	light.Parent = main
	local effect = Instance.new("Attachment")
	effect.Name = "EffectPoint"
	effect.CFrame = main.CFrame:Inverse() * CFrame.new(0, 21, 0) -- today's crystal centre
	effect.Parent = main
	merge(m, "Crystals", { crystalPiece("crystal_small_1"), crystalPiece("crystal_small_2"), crystalPiece("crystal_small_3") }, { material = Enum.Material.Neon, shadow = false })
	merge(m, "Flames", flames, { material = Enum.Material.Neon, shadow = false })

	-- 6. the 6 rune circles in the floor (where today's runes are: radius 8.4, every 60 degrees from 30): a thin
	-- octagonal ring around a glyph (a diamond between two bars), Neon, 0.06 proud
	for k = 0, 5 do
		local a = math.rad(30 + 60 * k)
		local c = CFrame.new(8.4 * math.cos(a), 6.0, 8.4 * math.sin(a)) * CFrame.Angles(0, -a, 0)
		for f = 0, 7 do
			local fa = f * math.pi / 4
			table.insert(runes, piece("Part", Vector3.new(0.54, 0.06, 0.09), c * CFrame.Angles(0, fa, 0) * CFrame.new(0, 0, 0.65), NEON_PINK, { material = Enum.Material.Neon }))
		end
		table.insert(runes, piece("Part", Vector3.new(0.36, 0.06, 0.36), c * CFrame.Angles(0, math.rad(45), 0), NEON_PINK, { material = Enum.Material.Neon }))
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(runes, piece("Part", Vector3.new(0.09, 0.06, 0.7), c * CFrame.new(sx * 0.38, 0, 0), NEON_PINK, { material = Enum.Material.Neon }))
		end
	end
	merge(m, "Runes", runes, { single = NEON_PINK, material = Enum.Material.Neon, shadow = false })

	-- 7. light moss on the ground against the bottom tier (not in front of the stairs) and on the first tier
	for k = 0, 7 do
		local a = math.rad(22.5 + 45 * k + rng:NextNumber(-8, 8))
		if math.abs(math.cos(a)) < 0.42 and math.sin(a) < 0 then
			continue -- the stairs
		end
		local len = rng:NextNumber(1.6, 2.2)
		local r = 18 * math.cos(math.pi / 20) + len * 0.18 - 0.1
		moss(mossList, rng, Vector3.new(r * math.cos(a), 0, r * math.sin(a)), -a - math.pi / 2, len)
	end
	for _, a in ipairs({ math.rad(200), math.rad(-20), math.rad(110) }) do
		local r = 14 * math.cos(math.pi / 16) + 0.25
		moss(mossList, rng, Vector3.new(r * math.cos(a), 1.98, r * math.sin(a)), -a - math.pi / 2, 1.2)
	end
	merge(m, "Moss", mossList, { shadow = false })

	local root = m:FindFirstChild("Platform") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "rebirth_altar")
	BEVEL_SELF = false
	return m
end

---------------------------------------------------------------------
-- 10a EGG STATION (kit Hub.Station_EggStation, 18.9 x 13.45 x 22; Hub.EggStation: PetService's station, its Interact
-- prompt opens Pets > Eggs; the Egg Keeper's marker). A round plinth of cut blocks on a darker rim step, a woven nest: a
-- basket of wooden staves leaning out with 2 rope bands, a rim of straw bundles, a straw bed with loose strands and
-- twigs (its top at 3.38 under the eggs' feet at 3.35), the thick wooden arch (chamfered timbers on iron shoes, iron
-- plates and bolts at the joints, rope lashings), an iron hook and chain links for the lantern (the nested `lantern`
-- prop is kept on each copy), the signboard on its post with a painted egg. The real zone eggs DisplayEgg_* (the owner's
-- choice of 2026-10-18) are custom children with MapPropKeep: kept as they are on every copy.
-- Parts: Base, Nest, Arch, Iron, Sign (5; the old one had 12 + the placeholder eggs).
---------------------------------------------------------------------
function PropsBatch2.egg_station(): Model
	local m = Instance.new("Model")
	m.Name = "egg_station"
	local rng = Random.new(20261010)
	BEVEL_SELF = true
	local H = 13.45
	local STRAW = { rgb(236, 200, 96), rgb(222, 186, 88), rgb(206, 172, 82) }
	local BED = rgb(196, 160, 104)
	local stone, nest, arch, iron, sign = {}, {}, {}, {}, {}

	-- 1. base: the dark rim step (18 slabs, 0.6) and the plinth (14 blocks, 1.4), as today's BaseRim / Base
	ringBlocks(stone, rng, { n = 18, ro = 8.5, ri = 7.0, y0 = 0, h = 0.6, color = P.StoneDark, H = H, c = 0.12 })
	ringBlocks(stone, rng, { n = 14, ro = 8.0, ri = 4.6, y0 = 0, h = 1.4, color = P.Stone, H = H, c = 0.18, a0 = math.rad(13) })
	merge(m, "Base", stone, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 2. the nest (today's Nest: 11 across, y 1.4 .. 3.6)
	local prev = nil
	for i = 0, 17 do
		local a = i * math.pi / 9
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local tan = Vector3.new(-math.sin(a), 0, math.cos(a))
		local ti = toneIndex(rng, prev)
		prev = ti
		local cf = CFrame.fromMatrix(Vector3.new(0, 2.4, 0) + dir * 5.25, tan, Vector3.yAxis) * CFrame.Angles(math.rad(-6), 0, 0)
		table.insert(nest, chamfered(Vector3.new(1.78, 2.0, 0.35), cf, graded(if i % 2 == 0 then P.WoodMid else scaled(P.WoodMid, 1.08), 2.4, H, TONES[ti]), { "vertical", "topFrontBack" }, 0.07))
	end
	for _, band in ipairs({ { 1.9, 5.47 }, { 3.0, 5.59 } }) do
		for i = 0, 17 do
			local a = (i + 0.5) * math.pi / 9
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local tan = Vector3.new(-math.sin(a), 0, math.cos(a))
			table.insert(nest, piece("Part", Vector3.new(1.98, 0.24, 0.24), CFrame.fromMatrix(Vector3.new(0, band[1], 0) + dir * band[2], tan, Vector3.yAxis) * CFrame.Angles(math.rad(45), 0, 0), scaled(ROPE, if i % 2 == 0 then 1 else 0.92)))
		end
	end
	-- the straw bed (16 sides, top 3.38) inside the basket
	disc16(nest, 10.2, 1.98, CFrame.new(0, 2.39, 0), BED)
	-- a rim of straw bundles over the staves, loose strands on the bed, twigs poking out
	for i = 0, 21 do
		local a = i * 2 * math.pi / 22 + rng:NextNumber(-0.06, 0.06)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local tan = Vector3.new(-math.sin(a), 0, math.cos(a))
		local cf = CFrame.fromMatrix(Vector3.new(0, 3.42 + rng:NextNumber(-0.05, 0.08), 0) + dir * (5.15 + rng:NextNumber(-0.1, 0.12)), tan, Vector3.yAxis)
			* CFrame.Angles(rng:NextNumber(-0.18, 0.18), rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.15, 0.15))
		table.insert(nest, chamfered(Vector3.new(1.75, 0.5, 0.78), cf, scaled(STRAW[rng:NextInteger(1, 3)], rng:NextNumber(0.94, 1.04)), { "topFrontBack", "topSides", "bottomFrontBack" }, 0.14))
	end
	for _ = 1, 26 do
		local r = math.sqrt(rng:NextNumber(0.05, 1)) * 4.4
		local a = rng:NextNumber(0, 2 * math.pi)
		table.insert(nest, piece("Part", Vector3.new(1.1, 0.06, 0.1), CFrame.new(r * math.cos(a), 3.4, r * math.sin(a)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.08, 0.08)), STRAW[rng:NextInteger(1, 3)]))
	end
	for i = 0, 7 do
		local a = i * math.pi / 4 + rng:NextNumber(-0.2, 0.2)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local tip = Vector3.new(0, 3.55 + rng:NextNumber(0, 0.25), 0) + dir * 6.15
		local root = Vector3.new(0, 3.3, 0) + dir * 4.9 + Vector3.new(-dir.Z, 0, dir.X) * rng:NextNumber(-0.5, 0.5)
		table.insert(nest, piece("Part", Vector3.new(0.12, 0.12, (tip - root).Magnitude), CFrame.lookAt((tip + root) / 2, tip), scaled(P.WoodDark, rng:NextNumber(0.9, 1.1))))
	end
	merge(m, "Nest", nest, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 3. the arch (today's posts / rafters / top beam, thicker), iron shoes, plates and bolts, rope lashings
	local z = 2.5
	for _, sx in ipairs({ -1, 1 }) do
		local postCF = CFrame.new(sx * 6.6, 5.6, z) * CFrame.Angles(0, 0, math.rad(8 * sx)) -- the top leans in
		table.insert(arch, timber(Vector3.new(1.1, 9.0, 1.1), postCF, graded(P.WoodDark, 5.6, H, 1), 0.2))
		local rafterCF = CFrame.new(sx * 3.9, 11.4, z) * CFrame.Angles(0, 0, math.rad(52 * sx))
		table.insert(arch, timber(Vector3.new(1.0, 5.4, 1.0), rafterCF, graded(P.WoodDark, 11.4, H, 0.93), 0.18))
		for _, y in ipairs({ 3.1, 3.55 }) do
			table.insert(arch, octagon(1.42, 0.24, postCF * CFrame.new(0, y, 0), scaled(ROPE, if y > 3.3 then 0.92 else 1)))
		end
		-- iron shoe at the foot (on the plinth, y 1.4)
		table.insert(iron, chamfered(Vector3.new(1.45, 0.9, 1.45), CFrame.new(sx * 7.12, 1.85, z), P.Iron, { "topFrontBack", "topSides" }, 0.1))
		for _, fz in ipairs({ -1, 1 }) do
			-- the elbow plate (post / rafter) and the top plate (rafter / beam), front and back, with bolts
			local elbow = CFrame.new(sx * 5.95, 9.95, z + fz * 0.6) * CFrame.Angles(0, 0, math.rad(30 * sx))
			table.insert(iron, piece("Part", Vector3.new(1.3, 1.5, 0.08), elbow, P.Iron))
			local top = CFrame.new(sx * 2.0, 12.85, z + fz * 0.64)
			table.insert(iron, piece("Part", Vector3.new(1.4, 1.0, 0.08), top, P.Iron))
			for _, o in ipairs({ Vector3.new(-0.4, -0.45, 0), Vector3.new(0.4, 0.45, 0), Vector3.new(0.4, -0.45, 0), Vector3.new(-0.4, 0.45, 0) }) do
				rivet(iron, (elbow * CFrame.new(o + Vector3.new(0, 0, fz * 0.05))).Position, 0.17)
			end
			for _, ox in ipairs({ -0.45, 0.45 }) do
				rivet(iron, (top * CFrame.new(ox, 0, fz * 0.05)).Position, 0.17)
			end
		end
	end
	table.insert(arch, timber(Vector3.new(4.8, 1.0, 1.2), CFrame.new(0, 13.0, z), graded(P.WoodDark, 13, H, 1), 0.2))
	merge(m, "Arch", arch, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	-- the lantern hook and chain (the lantern's top is at 12.14, the beam's bottom at 12.5)
	table.insert(iron, piece("Part", Vector3.new(0.6, 0.12, 0.6), CFrame.new(0, 12.46, z), P.Iron))
	for k = 0, 1 do
		local y = 12.36 - k * 0.2
		table.insert(iron, piece("Part", if k % 2 == 0 then Vector3.new(0.08, 0.28, 0.22) else Vector3.new(0.22, 0.28, 0.08), CFrame.new(0, y, z), P.IronWorn))
	end
	merge(m, "Iron", iron, {})

	-- 4. the signboard (today's post and board): a framed board of 2 planks with a painted egg, on a chamfered post
	table.insert(sign, timber(Vector3.new(0.7, 4.0, 0.7), CFrame.new(8.6, 2.0, -4.0), graded(P.WoodDark, 2, H, 1), 0.12))
	for i, y in ipairs({ 3.7, 4.72 }) do
		table.insert(sign, timber(Vector3.new(3.4, 0.98, 0.3), CFrame.new(8.6, y, -4.42), graded(P.WoodLight, y, H, TONES[i]), 0.06))
	end
	for _, sy in ipairs({ -1, 1 }) do
		table.insert(sign, timber(Vector3.new(3.8, 0.22, 0.42), CFrame.new(8.6, 4.21 + sy * 1.1, -4.42), P.WoodDark, 0.05))
	end
	for _, sxx in ipairs({ -1, 1 }) do
		table.insert(sign, timber(Vector3.new(0.22, 2.4, 0.42), CFrame.new(8.6 + sxx * 1.79, 4.21, -4.42), P.WoodDark, 0.05))
	end
	-- the egg: a faceted white egg with 3 spots (painted, 0.06 proud)
	local eggCF = CFrame.new(8.6, 4.2, -4.6)
	table.insert(sign, chamfered(Vector3.new(0.9, 1.15, 0.06), eggCF, rgb(245, 246, 250), {}, 0, { negWedge(eggCF, Vector3.new(0.9, 1.15, 0.06), "Z", 1, 1, 0.34), negWedge(eggCF, Vector3.new(0.9, 1.15, 0.06), "Z", -1, 1, 0.34), negWedge(eggCF, Vector3.new(0.9, 1.15, 0.06), "Z", 1, -1, 0.2), negWedge(eggCF, Vector3.new(0.9, 1.15, 0.06), "Z", -1, -1, 0.2) }))
	for _, spot in ipairs({ { -0.18, 0.15, rgb(212, 52, 60) }, { 0.2, -0.12, rgb(64, 120, 212) }, { 0.05, 0.38, rgb(255, 201, 60) } }) do
		table.insert(sign, piece("Part", Vector3.new(0.17, 0.17, 0.05), eggCF * CFrame.new(spot[1], spot[2], -0.03) * CFrame.Angles(0, 0, math.rad(45)), spot[3]))
	end
	merge(m, "Sign", sign, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	local root = m:FindFirstChild("Base") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "egg_station")
	BEVEL_SELF = false
	return m
end

---------------------------------------------------------------------
-- 10b MOON GAZEBO (kit Hub.Station_RebirthShop, 19.6 x 15.5 x 21.2; Hub.RebirthShop: the Rebirth Shop board, its
-- Interact prompt opens Rebirth > Rebirth Shop; NpcSpot + the NPC stand-in are kept on every copy). A hexagonal deck of
-- planks with a dark rim and today's blue rug with its gold ring, 6 posts on carved bases with gold bands and carved
-- caps, a ring beam with knee braces, hip rafters, a gold fascia with hanging gold ornaments, a hexagonal roof of
-- individual purple shingles (today's purple) with darker hip caps and a gold finial, the moon crest (purple medallion,
-- gold rim, a real gold crescent, stars) standing on the front eave, 3 folded drapes at the back with gold valance rods
-- and tassels, the octagonal table with its gold top, a gold claw stand holding the glowing crystal ball (today's light),
-- 2 candles with wax drips and stylized flames.
-- Parts: Deck, Rug, Frame, Gold, Roof, Crest, Drapes, Table, Candles, Flames, CrystalBall, CrystalCore (12).
---------------------------------------------------------------------
function PropsBatch2.moon_gazebo(): Model
	local m = Instance.new("Model")
	m.Name = "moon_gazebo"
	local rng = Random.new(20261012)
	BEVEL_SELF = true
	local H = 15.5
	local PURPLE, PURPLE_DARK, CLOTH, BLUE = rgb(150, 110, 255), rgb(106, 68, 168), rgb(112, 82, 191), rgb(74, 108, 220)
	local deck, rug, frame, gold, roof, crest, drapes, tableP, candles, flames = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
	local function dirOf(a: number): Vector3
		return Vector3.new(math.cos(a), 0, math.sin(a))
	end
	local function tanOf(a: number): Vector3
		return Vector3.new(-math.sin(a), 0, math.cos(a))
	end

	-- 1. deck: 13 planks along X clipped to a hexagon (vertex radius 7.5 on +-X), a dark rim around
	local R = 7.5
	local ap = R * math.cos(math.pi / 6)
	local prev = nil
	for i = -6, 6 do
		local negs = {}
		for k = 0, 5 do
			local n = dirOf(math.rad(30 + 60 * k))
			local x = Vector3.yAxis:Cross(n).Unit
			local y = n:Cross(x).Unit
			table.insert(negs, piece("Part", Vector3.new(40, 40, 40), CFrame.fromMatrix(n * (ap - 0.25 + 20), x, y), P.WoodMid))
		end
		local ti = toneIndex(rng, prev)
		prev = ti
		local col = graded(if i % 2 == 0 then P.WoodMid else scaled(P.WoodLight, 0.86), 0.2, H, TONES[ti])
		table.insert(deck, chamfered(Vector3.new(2 * R, 0.4, 0.94), CFrame.new(0, 0.2, i * 1.0), col, {}, 0, negs))
	end
	for k = 0, 5 do
		local e = math.rad(30 + 60 * k)
		table.insert(deck, timber(Vector3.new(7.8, 0.5, 0.35), CFrame.fromMatrix(Vector3.new(0, 0.25, 0) + dirOf(e) * (ap - 0.1), tanOf(e), Vector3.yAxis), graded(P.WoodDark, 0.25, H, 1), 0.07))
	end
	merge(m, "Deck", deck, { collide = true, fidelity = Enum.CollisionFidelity.Hull })
	-- today's rug (blue, 10 across) on its gold ring (11 across)
	disc16(rug, 11, 0.04, CFrame.new(0, 0.42, 0), P.Gold)
	disc16(rug, 10, 0.06, CFrame.new(0, 0.43, 0), BLUE)
	merge(m, "Rug", rug, { collide = true, fidelity = Enum.CollisionFidelity.Hull })

	-- 2. frame: posts on carved bases, gold bands, carved caps, the ring beam, knee braces, hip rafters
	local posts = {}
	for k = 0, 5 do
		local a = math.rad(60 * k)
		local pos = dirOf(a) * 6.6
		posts[k] = pos
		local f = CFrame.fromMatrix(pos, tanOf(a), Vector3.yAxis)
		table.insert(frame, chamfered(Vector3.new(1.15, 0.35, 1.15), f * CFrame.new(0, 0.575, 0), graded(P.WoodDark, 0.6, H, 0.93), { "topFrontBack", "topSides" }, 0.1))
		table.insert(frame, timber(Vector3.new(0.8, 6.5, 0.8), f * CFrame.new(0, 4.0, 0), graded(P.WoodDark, 4, H, 1), 0.14))
		table.insert(frame, chamfered(Vector3.new(0.98, 0.25, 0.98), f * CFrame.new(0, 7.375, 0), graded(P.WoodDark, 7.4, H, 0.93), { "bottomFrontBack", "bottomSides" }, 0.08))
		table.insert(frame, chamfered(Vector3.new(1.18, 0.25, 1.18), f * CFrame.new(0, 7.625, 0), graded(P.WoodDark, 7.6, H, 1), { "bottomFrontBack", "bottomSides" }, 0.08))
		table.insert(gold, octagon(0.92, 0.14, f * CFrame.new(0, 6.9, 0), P.Gold))
		table.insert(gold, octagon(0.92, 0.1, f * CFrame.new(0, 1.0, 0), P.Gold))
		-- hip rafter from the post top out to the eave corner, under the roof
		table.insert(frame, timber(Vector3.new(0.3, 0.3, 2.6), CFrame.fromMatrix(Vector3.new(0, 8.25, 0) + dirOf(a) * 7.55, tanOf(a), Vector3.yAxis), graded(P.WoodDark, 8.2, H, 0.93), 0.06))
	end
	for k = 0, 5 do
		local e = math.rad(30 + 60 * k)
		table.insert(frame, timber(Vector3.new(7.2, 0.6, 0.55), CFrame.fromMatrix(Vector3.new(0, 8.05, 0) + dirOf(e) * (6.6 * math.cos(math.pi / 6)), tanOf(e), Vector3.yAxis), graded(P.WoodDark, 8, H, 1), 0.1))
		-- knee braces from both posts of this edge up into the beam
		local p0, p1 = posts[k], posts[(k + 1) % 6]
		local u = (p1 - p0).Unit
		for _, side in ipairs({ { p0, u }, { p1, -u } }) do
			local a0 = side[1] + side[2] * 0.42 + Vector3.new(0, 6.35, 0)
			local a1 = side[1] + side[2] * 1.55 + Vector3.new(0, 7.78, 0)
			table.insert(frame, piece("Part", Vector3.new(0.22, 0.22, (a1 - a0).Magnitude + 0.1), CFrame.lookAt((a0 + a1) / 2, a1), graded(P.WoodDark, 7, H, 0.86)))
		end
	end
	merge(m, "Frame", frame, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 3. the roof: eave line y 8.55 at apothem 7.534 (vertex radius 8.7), apex (0, 14.3, 0)
	local yE, yA, ae = 8.55, 14.3, 8.7 * math.cos(math.pi / 6)
	local dy = yA - yE
	local Ls = math.sqrt(ae * ae + dy * dy)
	local normals = {}
	local planes = { { 0, -1, 0, -8.4, PURPLE_DARK } }
	for k = 0, 5 do
		local e = math.rad(30 + 60 * k)
		local n = Vector3.new(math.cos(e) * dy, ae, math.sin(e) * dy).Unit
		normals[k] = n
		table.insert(planes, { n.X, n.Y, n.Z, n.Y * yA, PURPLE_DARK })
	end
	table.insert(roof, convexSolid(Vector3.new(-8.8, 8.4, -8.8), Vector3.new(8.8, 14.35, 8.8), CFrame.identity, PURPLE_DARK, planes))
	local sprev = nil
	for k = 0, 5 do
		local e = math.rad(30 + 60 * k)
		local d, t, n = dirOf(e), tanOf(e), normals[k]
		local E = d * ae + Vector3.new(0, yE, 0)
		local s = (-d * ae + Vector3.new(0, dy, 0)) / Ls
		local row = 0
		while true do
			local t0 = row * 1.35 - 0.12
			local len = math.min(1.6, Ls - t0 - 0.25)
			if len < 0.45 then
				break
			end
			local hw = 4.35 * (1 - (t0 + len) / Ls) - 0.05
			local x = -hw - (if row % 2 == 1 then 0.78 else 0)
			while x < hw - 0.05 do
				local a, b = math.max(x, -hw), math.min(x + 1.5, hw)
				if b - a > 0.3 then
					local ti = toneIndex(rng, sprev)
					sprev = ti
					local pos = E + s * (t0 + len / 2) + t * ((a + b) / 2) + n * 0.12
					local cf = CFrame.fromMatrix(pos, t, n)
					local tilt = math.atan2(0.1, len) * (if cf.ZVector:Dot(s) > 0 then 1 else -1)
					table.insert(roof, piece("Part", Vector3.new(b - a, 0.1, len), cf * CFrame.Angles(tilt, 0, 0), scaled(PURPLE, ({ 1, 0.94, 0.88 })[ti])))
				end
				x += 1.56
			end
			row += 1
		end
	end
	for j = 0, 5 do
		local b = math.rad(60 * j)
		local V = dirOf(b) * 8.7 + Vector3.new(0, yE, 0)
		local A = Vector3.new(0, yA, 0)
		local z = (A - V).Unit
		local nn = (normals[(j + 5) % 6] + normals[j]).Unit
		local up = (nn - z * nn:Dot(z)).Unit
		local mid = (V + A) / 2 + up * 0.14
		table.insert(roof, piece("Part", Vector3.new(0.5, 0.14, (A - V).Magnitude - 0.2), CFrame.lookAt(mid, mid + z, up), PURPLE_DARK))
	end
	merge(m, "Roof", roof, { collide = true, fidelity = Enum.CollisionFidelity.Hull })

	-- 4. gold: the eave fascia with hanging ornaments, the finial, the drapes' valance rods and tassels (below), the
	-- table top, the crystal ball's claw stand, the candle holders
	for k = 0, 5 do
		local e = math.rad(30 + 60 * k)
		local d, t = dirOf(e), tanOf(e)
		table.insert(gold, timber(Vector3.new(8.85, 0.5, 0.15), CFrame.fromMatrix(Vector3.new(0, 8.3, 0) + d * (ae + 0.08), t, Vector3.yAxis), P.Gold, 0.05))
		for _, o in ipairs({ -2.2, 2.2 }) do
			local base = Vector3.new(0, 8.0, 0) + d * (ae + 0.1) + t * o
			table.insert(gold, piece("Part", Vector3.new(0.05, 0.3, 0.05), CFrame.new(base - Vector3.new(0, 0.1, 0)), P.Brass))
			table.insert(gold, piece("Part", Vector3.new(0.26, 0.26, 0.26), CFrame.new(base - Vector3.new(0, 0.42, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), P.Gold))
		end
	end
	table.insert(gold, octagon(1.1, 0.4, CFrame.new(0, 14.35, 0), P.Gold))
	table.insert(gold, fruitPiece(0.95, CFrame.new(0, 15.0, 0) * CFrame.Angles(0, math.pi / 4, 0), P.Gold))
	table.insert(gold, piece("Part", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 15.6, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), P.Gold))

	-- 5. the moon crest on the front eave (today's emblem: 3 across at (0, 9.8, -7.6), facing -Z)
	local face = CFrame.new(0, 9.8, -7.62) * CFrame.Angles(math.rad(90), 0, 0)
	disc16(crest, 3.0, 0.3, face, CLOTH)
	disc16(crest, 3.4, 0.16, CFrame.new(0, 9.8, -7.42) * CFrame.Angles(math.rad(90), 0, 0), P.Gold)
	local moonA = prism16(2.0, 0.2, CFrame.new(0.15, 9.85, -7.85) * CFrame.Angles(math.rad(90), 0, 0), P.Gold)
	local moonB = prism16(1.7, 0.5, CFrame.new(0.7, 10.1, -7.85) * CFrame.Angles(math.rad(90), 0, 0), P.Gold)
	local ok, cut = pcall(function()
		return GeometryService:SubtractAsync(moonA, { moonB }, { CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Automatic })
	end)
	moonB:Destroy()
	if ok and cut and cut[1] then
		moonA:Destroy()
		cut[1].Anchored = true
		table.insert(crest, cut[1])
	else
		table.insert(crest, moonA)
	end
	for _, st in ipairs({ { -0.75, 10.4 }, { -0.5, 9.1 }, { 0.75, 9.2 } }) do
		table.insert(crest, piece("Part", Vector3.new(0.24, 0.24, 0.06), CFrame.new(st[1], st[2], -7.8) * CFrame.Angles(0, 0, math.rad(45)), P.Gold))
	end
	table.insert(crest, timber(Vector3.new(0.4, 1.6, 0.3), CFrame.new(0, 8.95, -7.3), P.WoodDark, 0.06))
	merge(m, "Crest", crest, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 6. the 3 drapes at the back (today's), each 4 folded panels with a gold hem, a gold valance rod and 3 tassels
	for _, spec in ipairs({ { 30, PURPLE }, { 90, CLOTH }, { 150, PURPLE } }) do
		local e = math.rad(spec[1])
		local d, t = dirOf(e), tanOf(e)
		local apo = 6.6 * math.cos(math.pi / 6)
		for i = 0, 3 do
			local o = -2.175 + i * 1.45
			local fold = if i % 2 == 0 then 1 else -1
			local cf = CFrame.fromMatrix(Vector3.new(0, 4.125, 0) + d * (apo + fold * 0.06) + t * o, t, Vector3.yAxis) * CFrame.Angles(0, math.rad(9 * fold), 0)
			table.insert(drapes, piece("Part", Vector3.new(1.48, 7.25, 0.12), cf, scaled(spec[2], if i % 2 == 0 then 1 else 0.92)))
			table.insert(gold, piece("Part", Vector3.new(1.48, 0.14, 0.16), cf * CFrame.new(0, -3.55, 0), P.Gold))
		end
		table.insert(gold, timber(Vector3.new(5.9, 0.16, 0.16), CFrame.fromMatrix(Vector3.new(0, 7.68, 0) + d * (apo - 0.2), t, Vector3.yAxis), P.Gold, 0.04))
		for _, o in ipairs({ -1.45, 0, 1.45 }) do
			local base = Vector3.new(0, 7.6, 0) + d * (apo - 0.22) + t * o
			table.insert(gold, piece("Part", Vector3.new(0.05, 0.4, 0.05), CFrame.new(base - Vector3.new(0, 0.2, 0)), P.Brass))
			table.insert(gold, chamfered(Vector3.new(0.2, 0.36, 0.2), CFrame.new(base - Vector3.new(0, 0.55, 0)), P.Gold, { "vertical", "bottomFrontBack", "bottomSides" }, 0.06))
		end
	end
	merge(m, "Drapes", drapes, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 7. the table (today's: 4.4 across at (0, -, -1)), its gold top, the claw stand, the candles
	local tc = Vector3.new(0, 0, -1)
	table.insert(tableP, octagon(4.2, 2.5, CFrame.new(tc + Vector3.new(0, 1.7, 0)), graded(CLOTH, 1.7, H, 1)))
	table.insert(tableP, octagon(4.0, 0.04, CFrame.new(tc + Vector3.new(0, 3.27, 0)), scaled(CLOTH, 1.12)))
	merge(m, "Table", tableP, { collide = true, fidelity = Enum.CollisionFidelity.Hull })
	table.insert(gold, octagon(4.32, 0.22, CFrame.new(tc + Vector3.new(0, 0.75, 0)), P.Gold))
	table.insert(gold, octagon(4.8, 0.3, CFrame.new(tc + Vector3.new(0, 3.1, 0)), P.Gold))
	table.insert(gold, octagon(1.5, 0.15, CFrame.new(tc + Vector3.new(0, 3.365, 0)), P.Gold))
	table.insert(gold, octagon(1.25, 0.18, CFrame.new(tc + Vector3.new(0, 3.53, 0)), scaled(P.Gold, 0.94)))
	for k = 0, 3 do
		local a = math.rad(45 + 90 * k)
		local p0 = tc + Vector3.new(0, 3.55, 0) + dirOf(a) * 0.55
		local p1 = tc + Vector3.new(0, 4.25, 0) + dirOf(a) * 1.02
		table.insert(gold, piece("Part", Vector3.new(0.1, 0.1, (p1 - p0).Magnitude + 0.05), CFrame.lookAt((p0 + p1) / 2, p1), P.Gold))
		table.insert(gold, piece("Part", Vector3.new(0.15, 0.15, 0.15), CFrame.new(p1) * CFrame.Angles(math.rad(45), 0, math.rad(45)), P.Gold))
	end
	for _, sx in ipairs({ -1, 1 }) do
		local c = Vector3.new(sx * 1.6, 0, -0.2)
		table.insert(gold, octagon(0.75, 0.1, CFrame.new(c + Vector3.new(0, 3.34, 0)), P.Gold))
		table.insert(candles, octagon(0.48, 1.05, CFrame.new(c + Vector3.new(0, 3.915, 0)), rgb(232, 226, 208)))
		for _, da in ipairs({ 0.6, 2.4 }) do
			local d = dirOf(da)
			table.insert(candles, piece("Part", Vector3.new(0.09, 0.32, 0.06), CFrame.lookAt(c + Vector3.new(0, 4.25, 0) + d * 0.24, c + Vector3.new(0, 4.25, 0) + d * 2), rgb(240, 236, 222)))
		end
		table.insert(candles, piece("Part", Vector3.new(0.05, 0.14, 0.05), CFrame.new(c + Vector3.new(0, 4.5, 0)), rgb(40, 34, 30)))
		table.insert(flames, flame(CFrame.new(c + Vector3.new(0, 4.48, 0)), 0.16, 0.22, 0.7, rgb(255, 140, 40), Vector3.new(0.03, 0, 0)))
	end
	merge(m, "Candles", candles, { collide = true, fidelity = Enum.CollisionFidelity.Hull })
	merge(m, "Flames", flames, { material = Enum.Material.Neon, shadow = false })
	merge(m, "Gold", gold, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 8. the glowing crystal ball (today's ball and light) with a brighter core
	local ball = plain(m, "CrystalBall", Vector3.new(2.2, 2.2, 2.2), CFrame.new(tc + Vector3.new(0, 4.6, 0)), rgb(95, 212, 255), { shape = Enum.PartType.Ball, material = Enum.Material.Neon, collide = true })
	ball.Transparency = 0.15
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color = 12, 0.6, rgb(95, 212, 255)
	light.Parent = ball
	local core = plain(m, "CrystalCore", Vector3.new(1.0, 1.0, 1.0), CFrame.new(tc + Vector3.new(0, 4.6, 0)), rgb(210, 245, 255), { shape = Enum.PartType.Ball, material = Enum.Material.Neon, shadow = false })
	core.Transparency = 0.35

	local root = m:FindFirstChild("Deck") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "moon_gazebo")
	BEVEL_SELF = false
	return m
end

---------------------------------------------------------------------
-- 11 FRUIT STALL (kit Hub.Market_Awning_A, 16.2 x 11.1 x 10.4 with its barrel; the hub's 2 Market_Awning_A). Built
-- like its siblings (StudioProps.stallFrame: the weapon / trophy / diamond stall frames, same wood colours), at its
-- own size: posts on stone feet, knee braces, a front beam and a back plate on the posts, planked side panels with top
-- rails, the counter (dark core, 3 rows of front planks, kick board, stiles, 2 top boards, lip), the low back wall of
-- vertical boards, rafters under a yellow / white striped awning (today's colours and slope) with a scalloped valance,
-- 3 slatted crates of faceted fruit (red apples with stems and leaves, oranges, green apples; a few stacked) and loose
-- fruit at the counter ends. The nested `barrel` prop, the NpcSpot and the hub's NPC stand-ins are kept on each copy.
-- Parts: Frame, Awning, Crates, Fruit (4; the old one had 35 + the barrel).
---------------------------------------------------------------------
function PropsBatch2.fruit_stall(): Model
	local m = Instance.new("Model")
	m.Name = "fruit_stall"
	local rng = Random.new(20261111)
	BEVEL_SELF = true
	-- the stall frame colours of the siblings (MapProps.weapon_stall / trophy_stall / diamond_shop today)
	local POST, BEAM, CORE, FOOT = rgb(107, 59, 36), rgb(97, 54, 32), rgb(81, 45, 26), rgb(93, 99, 111)
	local BOARD = { rgb(161, 94, 53), rgb(152, 88, 49), rgb(168, 99, 57) }
	local PLANK = { rgb(158, 93, 54), rgb(137, 79, 45), rgb(152, 89, 51) }
	local TOP = { rgb(205, 144, 88), rgb(197, 136, 82) }
	local CRATE = { rgb(214, 150, 92), rgb(199, 139, 85), rgb(184, 128, 79) }
	local YELLOW, WHITE = rgb(255, 201, 60), rgb(245, 246, 250)
	local frame, awning, crates, fruit = {}, {}, {}, {}

	-- 1. posts (today's boxes) on stone feet, knee braces, the front beam and the back plate on the post tops
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(frame, timber(Vector3.new(0.9, 8.4, 0.9), CFrame.new(5.55 * sx, 4.2, -3.05), POST, 0.16))
		table.insert(frame, timber(Vector3.new(0.9, 10.4, 0.9), CFrame.new(5.55 * sx, 5.2, 3.05), POST, 0.16))
		for _, z in ipairs({ -3.05, 3.05 }) do
			table.insert(frame, chamfered(Vector3.new(1.2, 0.3, 1.2), CFrame.new(5.55 * sx, 0.15, z), FOOT, { "topFrontBack", "topSides" }, 0.08))
		end
		table.insert(frame, timber(Vector3.new(0.3, 1.7, 0.3), CFrame.new(4.62 * sx, 7.72, -3.05) * CFrame.Angles(0, 0, math.rad(45 * sx)), BEAM, 0.06))
		-- side panel: dark core, 3 planks on the outer face, a top rail
		table.insert(frame, piece("Part", Vector3.new(0.4, 3.2, 5.2), CFrame.new(5.55 * sx, 1.6, 0), CORE))
		for i, y in ipairs({ 0.55, 1.6, 2.65 }) do
			table.insert(frame, timber(Vector3.new(0.2, 0.98, 5.3), CFrame.new(sx * 5.8, y, 0), BOARD[i], 0.05))
		end
		table.insert(frame, timber(Vector3.new(0.76, 0.18, 5.6), CFrame.new(sx * 5.55, 3.29, 0), BEAM, 0.04))
	end
	table.insert(frame, timber(Vector3.new(12.0, 0.5, 0.5), CFrame.new(0, 8.65, -3.05), BEAM, 0.09))
	table.insert(frame, timber(Vector3.new(12.0, 0.6, 0.6), CFrame.new(0, 9.3, 3.05), BEAM, 0.1))
	table.insert(frame, timber(Vector3.new(12.0, 0.5, 0.5), CFrame.new(0, 10.15, 3.05), BEAM, 0.09))
	-- 2. the counter (today's 10.4 x 3.2 box and its 12.4 x 2.6 top)
	table.insert(frame, piece("Part", Vector3.new(10.4, 3.2, 1.4), CFrame.new(0, 1.6, -2.3), CORE))
	for i, y in ipairs({ 0.75, 1.74, 2.73 }) do
		table.insert(frame, timber(Vector3.new(10.2, 0.9, 0.2), CFrame.new(0, y, -3.1), PLANK[i], 0.05))
	end
	table.insert(frame, timber(Vector3.new(10.4, 0.3, 0.24), CFrame.new(0, 0.15, -3.08), BEAM, 0.04))
	for _, x in ipairs({ -4.95, 0, 4.95 }) do
		table.insert(frame, timber(Vector3.new(0.32, 2.9, 0.12), CFrame.new(x, 1.75, -3.24), BEAM, 0.03))
	end
	for i, z in ipairs({ -3.065, -1.735 }) do
		table.insert(frame, timber(Vector3.new(12.4, 0.5, 1.27), CFrame.new(0, 3.45, z), TOP[i], 0.08))
	end
	table.insert(frame, timber(Vector3.new(12.4, 0.14, 0.1), CFrame.new(0, 3.13, -3.75), BEAM, 0.03))
	-- 3. the low back wall: core, 6 vertical boards, a top rail
	table.insert(frame, piece("Part", Vector3.new(11.0, 3.2, 0.3), CFrame.new(0, 1.6, 3.1), CORE))
	local prev = nil
	for i = 0, 5 do
		local ti = toneIndex(rng, prev)
		prev = ti
		table.insert(frame, timber(Vector3.new(1.74, 3.05, 0.22), CFrame.new(-4.45 + i * 1.78, 1.55, 2.85), BOARD[ti], 0.05))
	end
	table.insert(frame, timber(Vector3.new(11.2, 0.2, 0.5), CFrame.new(0, 3.25, 3.0), BEAM, 0.04))

	-- 4. the awning: today's slope (14 degrees, centre (y 9.6, z -1.2), 10.6 long), 6 stripes on 3 rafters, a front rod,
	-- a scalloped valance (a band and 2 scallops per stripe, each the stripe's colour)
	local tiltCF = CFrame.new(0, 9.6, -1.2) * CFrame.Angles(math.rad(-14), 0, 0)
	for i = 0, 5 do
		local x = -5.67 + i * 2.268
		local col = if i % 2 == 0 then YELLOW else WHITE
		table.insert(awning, timber(Vector3.new(2.25, 0.22, 10.6), tiltCF * CFrame.new(x, 0, 0), col, 0.04))
		local front = tiltCF * CFrame.new(x, 0, -5.3)
		local bandCF = CFrame.new(front.Position + Vector3.new(0, -0.28, -0.04))
		table.insert(awning, piece("Part", Vector3.new(2.25, 0.5, 0.1), bandCF, col))
		for _, o in ipairs({ -0.565, 0.565 }) do
			table.insert(awning, octagon(1.06, 0.1, bandCF * CFrame.new(o, -0.28, 0) * CFrame.Angles(math.rad(90), 0, 0), scaled(col, 0.97)))
		end
	end
	for _, x in ipairs({ -4.2, 0, 4.2 }) do
		table.insert(frame, timber(Vector3.new(0.26, 0.28, 10.2), tiltCF * CFrame.new(x, -0.25, 0.1), BEAM, 0.05))
	end
	table.insert(frame, timber(Vector3.new(13.7, 0.16, 0.16), (tiltCF * CFrame.new(0, -0.05, -5.35)) * CFrame.Angles(math.rad(14), 0, 0), BEAM, 0.04))
	merge(m, "Frame", frame, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Awning", awning, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 5. three slatted crates on the counter (today's 3 x 1.4 x 2 at x -3.4 / 0 / 3.4) and their fruit
	local kinds = {
		{ -3.4, rgb(212, 52, 60), 0.8, true }, -- red apples
		{ 0, rgb(255, 140, 40), 0.8, false }, -- oranges
		{ 3.4, rgb(110, 186, 60), 0.84, true }, -- green apples
	}
	for _, kind in ipairs(kinds) do
		local cx = kind[1]
		local c0 = Vector3.new(cx, 3.7, -2.4)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				table.insert(crates, timber(Vector3.new(0.22, 1.4, 0.22), CFrame.new(c0 + Vector3.new(sx * 1.39, 0.7, sz * 0.89)), scaled(CRATE[3], 0.85), 0.04))
			end
		end
		for _, y in ipairs({ 0.33, 1.05 }) do
			for _, sz in ipairs({ -1, 1 }) do
				table.insert(crates, timber(Vector3.new(2.6, 0.6, 0.1), CFrame.new(c0 + Vector3.new(0, y, sz * 0.93)), CRATE[rng:NextInteger(1, 3)], 0.03))
			end
			for _, sx in ipairs({ -1, 1 }) do
				table.insert(crates, timber(Vector3.new(0.1, 0.6, 1.6), CFrame.new(c0 + Vector3.new(sx * 1.43, y, 0)), CRATE[rng:NextInteger(1, 3)], 0.03))
			end
		end
		table.insert(crates, piece("Part", Vector3.new(2.7, 0.75, 1.7), CFrame.new(c0 + Vector3.new(0, 0.42, 0)), CORE))
		-- fruit: 6 in the crate (3 x 2), 2 on them, 1 on top
		local s = kind[3]
		local spots = {}
		for _, fx in ipairs({ -0.9, 0, 0.9 }) do
			for _, fz in ipairs({ -0.43, 0.43 }) do
				table.insert(spots, Vector3.new(fx, 0.8 + s / 2, fz))
			end
		end
		table.insert(spots, Vector3.new(-0.45, 0.8 + s * 1.3, 0.05))
		table.insert(spots, Vector3.new(0.45, 0.8 + s * 1.3, -0.05))
		table.insert(spots, Vector3.new(0, 0.8 + s * 2.05, 0))
		for _, sp in ipairs(spots) do
			local cf = CFrame.new(c0 + sp + Vector3.new(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.05, 0.05))) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3))
			table.insert(fruit, fruitPiece(s * rng:NextNumber(0.94, 1.04), cf, scaled(kind[2], rng:NextNumber(0.9, 1.05))))
			if kind[4] then
				table.insert(fruit, piece("Part", Vector3.new(0.07, 0.24, 0.07), cf * CFrame.new(0, s * 0.5, 0), P.WoodDark))
				table.insert(fruit, piece("Part", Vector3.new(0.24, 0.04, 0.13), cf * CFrame.new(0.12, s * 0.55, 0) * CFrame.Angles(0, 0, math.rad(20)), P.MossDark))
			end
		end
	end
	-- loose fruit at the counter ends
	for _, lf in ipairs({ { -5.45, rgb(212, 52, 60), 0.8 }, { -5.1, rgb(212, 52, 60), 0.76 }, { 5.35, rgb(255, 140, 40), 0.8 } }) do
		local cf = CFrame.new(lf[1], 3.7 + lf[3] * 0.47, -2.45 + rng:NextNumber(-0.4, 0.4)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		table.insert(fruit, fruitPiece(lf[3], cf, lf[2]))
	end
	merge(m, "Crates", crates, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Fruit", fruit, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	local root = m:FindFirstChild("Frame") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "fruit_stall")
	BEVEL_SELF = false
	return m
end

---------------------------------------------------------------------
-- shared (batch D)
---------------------------------------------------------------------
-- a frame CFrame at `pos` whose local Y is `up` (any X)
local function frameY(pos: Vector3, up: Vector3): CFrame
	local u = up.Unit
	local helper = if math.abs(u.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local x = helper:Cross(u).Unit
	return CFrame.fromMatrix(pos, x, u)
end

-- a square bar from a to b (thickness t, square), as a piece
local function bar(a: Vector3, b: Vector3, t: number, color: Color3): BasePart
	return piece("Part", Vector3.new(t, t, (b - a).Magnitude + t * 0.5), CFrame.lookAt((a + b) / 2, b), color)
end

-- a slatted crate (w x h x d, its floor centre at cf): corner posts, 2 rows of slats on each side, a dark core
local function slatCrate(list: { BasePart }, rng: Random, cf: CFrame, w: number, h: number, d: number, colors: { Color3 }, core: Color3)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(list, timber(Vector3.new(0.22, h, 0.22), cf * CFrame.new(sx * (w / 2 - 0.11), h / 2, sz * (d / 2 - 0.11)), scaled(colors[3], 0.85), 0.04))
		end
	end
	local rowH = (h - 0.1) / 2 - 0.06
	for r = 0, 1 do
		local y = 0.05 + rowH / 2 + r * (rowH + 0.12)
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(list, timber(Vector3.new(w - 0.2, rowH, 0.1), cf * CFrame.new(0, y, sz * (d / 2 - 0.02)), colors[rng:NextInteger(1, 3)], 0.03))
		end
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(list, timber(Vector3.new(0.1, rowH, d - 0.2), cf * CFrame.new(sx * (w / 2 - 0.02), y, 0), colors[rng:NextInteger(1, 3)], 0.03))
		end
	end
	-- a lid of 3 planks
	for i = -1, 1 do
		table.insert(list, timber(Vector3.new(w - 0.06, 0.12, d / 3 - 0.05), cf * CFrame.new(0, h - 0.06, i * d / 3), colors[rng:NextInteger(1, 3)], 0.03))
	end
	table.insert(list, piece("Part", Vector3.new(w - 0.3, h - 0.3, d - 0.3), cf * CFrame.new(0, h / 2, 0), core))
end

-- an iron S-scroll in the plane spanned by `out` (horizontal) and Y, from `root` (on a pole) outward: a quarter arc up
-- then a small curl back, made of short square bars
local function scroll(list: { BasePart }, root: Vector3, out: Vector3, r: number, color: Color3, t: number)
	local pts = {}
	-- main arc: centre root + out * r, from angle 180 (the root) down and out to angle 270, up the far side to 360
	local c1 = root + out * r
	for k = 0, 6 do
		local a = math.rad(180 + k * 30)
		table.insert(pts, c1 + out * (math.cos(a) * r) + Vector3.new(0, math.sin(a) * r, 0) * -1)
	end
	-- the curl at the end: a smaller circle turning inward
	local last = pts[#pts]
	local r2 = r * 0.45
	local c2 = last - Vector3.new(0, r2, 0)
	for k = 1, 5 do
		local a = math.rad(90 - k * 55)
		table.insert(pts, c2 + out * (math.cos(a) * r2) + Vector3.new(0, math.sin(a) * r2, 0))
	end
	for i = 1, #pts - 1 do
		table.insert(list, bar(pts[i], pts[i + 1], t, color))
	end
end

---------------------------------------------------------------------
-- 12 TRAINING AREA (kit Hub.Station_Trainer, 24.4 x 11.4 x 18; Hub.Trainer: the Trainer's marker, its Interact
-- prompt opens Stats; NpcSpot + NPC stand-in). A sand yard (today's 22 x 18) inside a border of cut stones, today's
-- fences (back and right) rebuilt as chamfered posts on footing stones with pointed tops and nailed rails, the weapon
-- rack (2 uprights on cross feet, 2 bars with pegs) holding 2 wooden practice swords, an iron sword, 2 spears and 2
-- round shields, 2 training dummies (post on cross feet, a straw-stuffed sack body tied with rope, a sack head, arm bar
-- with straw ends, a painted target on the chest), 2 archery targets on tripods (straw face with painted rings, arrows),
-- the banner (stone foot, pole with a gold finial, swallow-tail cloth with gold trim and emblem), 2 slatted crates; the
-- synced `barrel` prop stands next to them on every copy (a custom child). Same footprint; the fences, rack, dummies,
-- targets, banner and crates collide as before.
-- Parts: Ground, Fence, Rack, Dummies, Targets, Banner, Crates (7).
---------------------------------------------------------------------
function PropsBatch2.training_area(): Model
	local m = Instance.new("Model")
	m.Name = "training_area"
	local rng = Random.new(20261212)
	BEVEL_SELF = true
	local H = 11.4
	local SAND = rgb(226, 200, 150)
	local BURLAP = rgb(196, 160, 104)
	local STRAW = { rgb(236, 200, 96), rgb(222, 186, 88), rgb(206, 172, 82) }
	local RED, WHITE = rgb(212, 52, 60), rgb(245, 246, 250)
	local ground, fence, rack, dummies, targets, banner, crates = {}, {}, {}, {}, {}, {}, {}

	-- 1. ground: the sand (today's 22 x 18 at 0.4), a few darker patches and pebbles, a border of cut stones
	table.insert(ground, piece("Part", Vector3.new(21.0, 0.38, 17.0), CFrame.new(0, 0.19, 0), SAND))
	for _ = 1, 5 do
		local cf = CFrame.new(rng:NextNumber(-8, 8), 0.39, rng:NextNumber(-6.5, 6.5)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		table.insert(ground, chamfered(Vector3.new(rng:NextNumber(2.2, 3.6), 0.04, rng:NextNumber(1.4, 2.4)), cf, scaled(SAND, 0.92), { "vertical" }, 0.4))
	end
	for _ = 1, 9 do
		local s = rng:NextNumber(0.25, 0.45)
		table.insert(ground, chamfered(Vector3.new(s, s * 0.5, s * 0.8), CFrame.new(rng:NextNumber(-9.5, 9.5), 0.38 + s * 0.2, rng:NextNumber(-7.5, 7.5)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), scaled(P.Stone, rng:NextNumber(0.85, 1.0)), { "vertical", "topFrontBack", "topSides" }, s * 0.2))
	end
	local function run(fixedAxis: string, fixed: number, a: number, b: number)
		local pos = a
		local prev = nil
		while b - pos > 0.05 do
			local L = rng:NextNumber(1.4, 2.4)
			if b - pos - L - 0.09 < 0.8 then
				L = b - pos
			end
			local ti = toneIndex(rng, prev)
			prev = ti
			local size, cf
			if fixedAxis == "z" then
				size, cf = Vector3.new(L, 0.5, 0.62 + jit(rng)), CFrame.new(pos + L / 2, 0.25, fixed)
			else
				size, cf = Vector3.new(0.62 + jit(rng), 0.5, L), CFrame.new(fixed, 0.25, pos + L / 2)
			end
			table.insert(ground, chamfered(size, cf, graded(P.Stone, 0.25, H, TONES[ti]), { "topFrontBack", "topSides" }, 0.1))
			pos += L + 0.09
		end
	end
	run("z", -8.69, -11.0, 11.0)
	run("z", 8.69, -11.0, 11.0)
	run("x", -10.69, -8.38, 8.38)
	run("x", 10.69, -8.38, 8.38)
	table.insert(ground, piece("Part", Vector3.new(21.9, 0.36, 17.9), CFrame.new(0, 0.18, 0), P.Mortar))
	moss(ground, rng, Vector3.new(-11.0 - 0.2, 0, -5.5), math.rad(90), 1.4)
	moss(ground, rng, Vector3.new(6.0, 0, -9.0 - 0.2), 0, 1.5)
	merge(m, "Ground", ground, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 2. fences (today's posts and rails): posts on footing stones, pointed tops, nailed rails
	local posts = { Vector3.new(-11.5, 0, 8.5), Vector3.new(-3.5, 0, 8.5), Vector3.new(4.5, 0, 8.5), Vector3.new(11.5, 0, 8.5), Vector3.new(11.5, 0, 0.5), Vector3.new(11.5, 0, -7.5) }
	for _, p in ipairs(posts) do
		table.insert(fence, chamfered(Vector3.new(1.2, 0.4, 1.2), CFrame.new(p.X, 0.2, p.Z), graded(P.StoneDark, 0.2, H, 0.93), { "topFrontBack", "topSides" }, 0.1))
		local negs = {}
		local cf = CFrame.new(p.X, 2.3, p.Z)
		for _, e in ipairs(EDGES.vertical) do
			table.insert(negs, negWedge(cf, Vector3.new(0.9, 3.8, 0.9), e[1], e[2], e[3], 0.14))
		end
		table.insert(fence, chamfered(Vector3.new(0.9, 3.8, 0.9), cf, graded(P.WoodDark, 2.3, H, rng:NextNumber(0.93, 1)), { "topFrontBack", "topSides" }, 0.32, negs))
	end
	local function rails(p0: Vector3, p1: Vector3)
		local d = (p1 - p0).Unit
		local mid = (p0 + p1) / 2
		local len = (p1 - p0).Magnitude + 0.4
		for _, y in ipairs({ 1.6, 3.2 }) do
			local cf = CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(mid.X, y, mid.Z) + d) * CFrame.Angles(0, math.rad(90), 0)
			table.insert(fence, timber(Vector3.new(len, 0.62, 0.36), cf, graded(P.WoodMid, y, H, TONES[rng:NextInteger(1, 3)]), 0.08))
			for _, s in ipairs({ -1, 1 }) do
				local nailAt = Vector3.new(mid.X, y, mid.Z) + d * (s * (len / 2 - 0.35))
				local side = Vector3.new(-d.Z, 0, d.X)
				for _, dy in ipairs({ -0.15, 0.15 }) do
					rivet(fence, nailAt + side * 0.19 + Vector3.new(0, dy, 0), 0.11)
					rivet(fence, nailAt - side * 0.19 + Vector3.new(0, dy, 0), 0.11)
				end
			end
		end
	end
	for i = 1, 3 do
		rails(posts[i], posts[i + 1])
	end
	rails(posts[4], posts[5])
	rails(posts[5], posts[6])
	merge(m, "Fence", fence, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 3. the weapon rack (today's: uprights at x -10.4 / -5.6, bars at y 1.6 / 4.0, z 6.5)
	for _, x in ipairs({ -10.4, -5.6 }) do
		table.insert(rack, timber(Vector3.new(0.6, 4.5, 0.6), CFrame.new(x, 2.65, 6.5), graded(P.WoodDark, 2.6, H, 1), 0.1))
		table.insert(rack, timber(Vector3.new(0.5, 0.4, 1.8), CFrame.new(x, 0.6, 6.5), graded(P.WoodDark, 0.6, H, 0.93), 0.08))
		table.insert(rack, chamfered(Vector3.new(0.72, 0.2, 0.72), CFrame.new(x, 5.0, 6.5), graded(P.WoodDark, 5, H, 0.93), { "topFrontBack", "topSides" }, 0.08))
	end
	for _, y in ipairs({ 1.6, 4.0 }) do
		table.insert(rack, timber(Vector3.new(5.6, 0.45, 0.7), CFrame.new(-8.0, y, 6.5), graded(P.WoodMid, y, H, 0.93), 0.08))
	end
	for i = 0, 3 do
		table.insert(rack, piece("Part", Vector3.new(0.14, 0.14, 0.5), CFrame.new(-9.6 + i * 1.07, 4.1, 6.05), P.WoodDark))
	end
	-- weapons standing tip down on the sand, leaning back on the top bar (8 degrees)
	local lean = CFrame.Angles(math.rad(8), 0, 0)
	local function sword(x: number, blade: Color3, guard: Color3)
		local base = CFrame.new(x, 0.42, 5.55) * lean -- the tip
		table.insert(rack, chamfered(Vector3.new(0.36, 2.8, 0.12), base * CFrame.new(0, 1.65, 0), blade, { "vertical" }, 0.08))
		table.insert(rack, chamfered(Vector3.new(0.25, 0.25, 0.12), base * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(45)), blade, {}, 0))
		table.insert(rack, timber(Vector3.new(1.1, 0.18, 0.24), base * CFrame.new(0, 3.1, 0), guard, 0.04))
		table.insert(rack, piece("Part", Vector3.new(0.18, 0.75, 0.18), base * CFrame.new(0, 3.55, 0), rgb(92, 56, 40)))
		table.insert(rack, piece("Part", Vector3.new(0.26, 0.26, 0.26), base * CFrame.new(0, 4.0, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0), guard))
	end
	sword(-9.2, P.WoodLight, P.WoodMid)
	sword(-8.4, P.WoodLight, P.WoodMid)
	sword(-7.6, P.IronWorn, P.Brass)
	for _, x in ipairs({ -7.0, -6.75 }) do
		local base = CFrame.new(x, 0.42, 5.7) * CFrame.Angles(math.rad(6), 0, math.rad(x < -6.9 and 3 or -3))
		table.insert(rack, timber(Vector3.new(0.16, 5.4, 0.16), base * CFrame.new(0, 2.7, 0), P.WoodMid, 0.03))
		table.insert(rack, piece("Part", Vector3.new(0.2, 0.3, 0.2), base * CFrame.new(0, 5.4, 0), P.Iron))
		table.insert(rack, chamfered(Vector3.new(0.34, 0.75, 0.1), base * CFrame.new(0, 5.9, 0), P.IronWorn, { "vertical" }, 0.13))
		table.insert(rack, chamfered(Vector3.new(0.2, 0.2, 0.1), base * CFrame.new(0, 6.32, 0) * CFrame.Angles(0, 0, math.rad(45)), P.IronWorn, {}, 0))
	end
	-- 2 round shields on the uprights' fronts
	for i, x in ipairs({ -10.4, -5.6 }) do
		local f = CFrame.new(x, 3.0, 6.1) * CFrame.Angles(math.rad(90), 0, 0)
		table.insert(rack, octagon(2.0, 0.14, f * CFrame.new(0, 0.05, 0), P.Iron))
		table.insert(rack, octagon(1.8, 0.16, f * CFrame.new(0, -0.05, 0), if i == 1 then rgb(64, 120, 212) else RED))
		table.insert(rack, timber(Vector3.new(0.3, 0.18, 1.7), f * CFrame.new(0, -0.1, 0), WHITE, 0.03))
		table.insert(rack, octagon(0.55, 0.22, f * CFrame.new(0, -0.17, 0), P.Iron))
		for k = 0, 5 do
			local a = k * math.pi / 3
			rivet(rack, (f * CFrame.new(math.cos(a) * 0.82, -0.14, math.sin(a) * 0.82)).Position, 0.1)
		end
	end
	merge(m, "Rack", rack, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 4. two training dummies (today's at (-3, 2), a new one at (-6.6, -2.4), clear of the rack)
	for di, spot in ipairs({ { -3, 2, 0 }, { -6.6, -2.4, math.rad(18) } }) do
		local f = CFrame.new(spot[1], 0.4, spot[2]) * CFrame.Angles(0, spot[3], 0)
		table.insert(dummies, timber(Vector3.new(2.6, 0.35, 0.45), f * CFrame.new(0, 0.18, 0), graded(P.WoodDark, 0.5, H, 1), 0.06))
		table.insert(dummies, timber(Vector3.new(0.45, 0.35, 2.6), f * CFrame.new(0, 0.2, 0), graded(P.WoodDark, 0.5, H, 0.93), 0.06))
		table.insert(dummies, octagon(0.7, 6.4, f * CFrame.new(0, 3.2, 0), graded(P.WoodDark, 3.2, H, 1)))
		-- the sack body, 2 rope ties, straw poking out at the top and bottom
		table.insert(dummies, chamfered(Vector3.new(2.6, 2.8, 1.6), f * CFrame.new(0, 3.9, 0), BURLAP, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.35))
		for _, y in ipairs({ 3.0, 4.85 }) do
			table.insert(dummies, chamfered(Vector3.new(2.66, 0.2, 1.66), f * CFrame.new(0, y, 0), scaled(ROPE, 0.8), { "vertical" }, 0.38))
		end
		for k = 0, 5 do
			local a = k * math.pi / 3 + rng:NextNumber(-0.2, 0.2)
			local dir = Vector3.new(math.cos(a) * 1.0, 0, math.sin(a) * 0.55)
			table.insert(dummies, piece("Part", Vector3.new(0.08, 0.5, 0.08), f * CFrame.new(dir + Vector3.new(0, 2.45, 0)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5)), STRAW[rng:NextInteger(1, 3)]))
		end
		-- the painted target on the chest (front, -Z)
		local chest = f * CFrame.new(0, 4.0, -0.82) * CFrame.Angles(math.rad(90), 0, 0)
		table.insert(dummies, octagon(1.4, 0.04, chest, RED))
		table.insert(dummies, octagon(0.9, 0.06, chest * CFrame.new(0, -0.01, 0), WHITE))
		table.insert(dummies, octagon(0.42, 0.08, chest * CFrame.new(0, -0.02, 0), RED))
		-- arm bar with straw bundles at the ends
		table.insert(dummies, timber(Vector3.new(5.6, 0.45, 0.45), f * CFrame.new(0, 5.0, 0), graded(P.WoodDark, 5, H, 0.93), 0.07))
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(dummies, chamfered(Vector3.new(0.8, 0.7, 0.7), f * CFrame.new(sx * 2.95, 5.0, 0), STRAW[di], { "vertical", "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }, 0.16))
			table.insert(dummies, chamfered(Vector3.new(0.86, 0.14, 0.76), f * CFrame.new(sx * 2.95, 5.0, 0), scaled(ROPE, 0.8), { "vertical" }, 0.16))
		end
		-- the sack head with a rope tie at the neck and 2 stitched eyes
		table.insert(dummies, fruitPiece(1.8, f * CFrame.new(0, 6.55, 0), scaled(BURLAP, 1.06)))
		table.insert(dummies, octagon(0.95, 0.22, f * CFrame.new(0, 5.6, 0), scaled(ROPE, 0.8)))
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(dummies, piece("Part", Vector3.new(0.3, 0.07, 0.05), f * CFrame.new(sx * 0.38, 6.7, -0.92) * CFrame.Angles(0, 0, math.rad(45)), rgb(60, 40, 30)))
			table.insert(dummies, piece("Part", Vector3.new(0.3, 0.07, 0.05), f * CFrame.new(sx * 0.38, 6.7, -0.92) * CFrame.Angles(0, 0, math.rad(-45)), rgb(60, 40, 30)))
		end
	end
	merge(m, "Dummies", dummies, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 5. two archery targets on tripods (today's at (6.5, 4.2, 5) facing yaw 70, a new one by the right fence)
	for ti2, spec in ipairs({ { Vector3.new(6.5, 4.2, 5.0), math.rad(70) }, { Vector3.new(8.6, 3.9, -3.4), math.rad(140) } }) do
		local C, yaw = spec[1], spec[2]
		local n = Vector3.new(math.cos(yaw), 0, -math.sin(yaw)) -- the face's normal (today's cylinder axis)
		local up = Vector3.yAxis
		local t = n:Cross(up).Unit
		local face = frameY(C, n)
		table.insert(targets, prism16(4.6, 0.6, face, rgb(236, 200, 96)))
		table.insert(targets, prism16(4.75, 0.3, face * CFrame.new(0, -0.1, 0), scaled(ROPE, 0.82)))
		local rings = { { 3.7, rgb(212, 52, 60) }, { 2.8, WHITE }, { 1.9, rgb(212, 52, 60) }, { 1.0, rgb(255, 201, 60) } }
		for k, r in ipairs(rings) do
			table.insert(targets, prism16(r[1], 0.05, face * CFrame.new(0, 0.3 + 0.025 + (k - 1) * 0.02, 0), r[2]))
		end
		-- tripod: 2 front legs and a back leg, a cross bar under the face
		local foot = Vector3.new(C.X, 0.4, C.Z)
		local feet = { foot + t * 1.9 - n * 0.4, foot - t * 1.9 - n * 0.4, foot - n * 2.4 }
		local tops = { C + up * 1.6 - n * 0.42 + t * 0.5, C + up * 1.6 - n * 0.42 - t * 0.5, C + up * 1.2 - n * 0.5 }
		for k = 1, 3 do
			table.insert(targets, bar(feet[k], tops[k], 0.42, graded(P.WoodDark, 3, H, if k == 3 then 0.93 else 1)))
		end
		table.insert(targets, bar(C - up * 1.75 - n * 0.4 + t * 1.45, C - up * 1.75 - n * 0.4 - t * 1.45, 0.34, P.WoodDark))
		-- arrows stuck in the face
		for _, o in ipairs({ { 0.35, 0.5, 0.15 }, { -0.9, -0.3, -0.1 }, { 0.6, -1.1, 0.05 } }) do
			local hit = C + t * o[1] + up * o[2] + n * 0.32
			local dir = (n + t * o[3] + up * 0.08).Unit
			local tail = hit + dir * 1.5
			table.insert(targets, bar(hit - dir * 0.2, tail, 0.07, P.WoodLight))
			for _, s in ipairs({ -1, 1 }) do
				table.insert(targets, piece("Part", Vector3.new(0.04, 0.2, 0.36), CFrame.lookAt(tail - dir * 0.2, tail + dir) * CFrame.new(0, s * 0.08, 0) * CFrame.Angles(0, 0, math.rad(s * 25)), if ti2 == 1 then RED else WHITE))
			end
		end
	end
	merge(m, "Targets", targets, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 6. the banner (today's pole at (-10.4, z 8.5), cloth at z 7.9 facing -Z)
	table.insert(banner, chamfered(Vector3.new(1.3, 0.6, 1.3), CFrame.new(-10.4, 0.7, 8.5), graded(P.StoneDark, 0.7, H, 1), { "topFrontBack", "topSides" }, 0.12))
	table.insert(banner, octagon(0.6, 10.8, CFrame.new(-10.4, 5.8, 8.5), graded(P.WoodDark, 5.8, H, 1)))
	table.insert(banner, octagon(0.85, 0.3, CFrame.new(-10.4, 1.15, 8.5), P.Iron))
	table.insert(banner, octagon(0.5, 0.35, CFrame.new(-10.4, 11.3, 8.5), P.Gold))
	table.insert(banner, fruitPiece(0.6, CFrame.new(-10.4, 11.7, 8.5) * CFrame.Angles(0, math.pi / 4, 0), P.Gold))
	table.insert(banner, timber(Vector3.new(4.0, 0.36, 0.36), CFrame.new(-10.4, 10.6, 8.2), P.WoodDark, 0.06))
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(banner, piece("Part", Vector3.new(0.26, 0.26, 0.26), CFrame.new(-10.4 + sx * 2.05, 10.6, 8.2) * CFrame.Angles(math.rad(45), math.rad(45), 0), P.Gold))
	end
	table.insert(banner, piece("Part", Vector3.new(3.4, 4.6, 0.16), CFrame.new(-10.4, 8.05, 7.95), RED))
	for _, sx in ipairs({ -1, 1 }) do
		-- the swallow tail: a half-width panel under each side, cut on the inside
		local tailCF = CFrame.new(-10.4 + sx * 0.85, 5.15, 7.95)
		table.insert(banner, chamfered(Vector3.new(1.7, 1.2, 0.16), tailCF, RED, {}, 0, { negWedge(tailCF, Vector3.new(1.7, 1.2, 0.16), "Z", -sx, -1, 1.1) }))
	end
	for _, y in ipairs({ 10.3, 5.75 }) do
		table.insert(banner, piece("Part", Vector3.new(3.42, 0.16, 0.2), CFrame.new(-10.4, y, 7.94), P.Gold))
	end
	table.insert(banner, piece("Part", Vector3.new(1.4, 1.4, 0.08), CFrame.new(-10.4, 8.2, 7.84) * CFrame.Angles(0, 0, math.rad(45)), P.Gold))
	table.insert(banner, piece("Part", Vector3.new(0.18, 1.6, 0.06), CFrame.new(-10.4, 8.25, 7.78), RED))
	table.insert(banner, piece("Part", Vector3.new(0.8, 0.16, 0.06), CFrame.new(-10.4, 7.7, 7.78), RED))
	merge(m, "Banner", banner, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 7. two slatted crates by the left border (the barrel prop stands next to them)
	local CR = { rgb(214, 150, 92), rgb(199, 139, 85), rgb(184, 128, 79) }
	slatCrate(crates, rng, CFrame.new(-9.2, 0.4, -6.9) * CFrame.Angles(0, math.rad(8), 0), 2.2, 2.0, 2.2, CR, rgb(81, 45, 26))
	slatCrate(crates, rng, CFrame.new(-9.1, 2.4, -6.8) * CFrame.Angles(0, math.rad(-14), 0), 1.8, 1.6, 1.8, CR, rgb(81, 45, 26))
	merge(m, "Crates", crates, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	local root = m:FindFirstChild("Ground") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "training_area")
	BEVEL_SELF = false
	return m
end
-- where the trainer's barrel prop stands (model space) and its scale
PropsBatch2.TRAINER_BARREL = { CFrame.new(-9.4, 0.4, -3.9) * CFrame.Angles(0, math.rad(25), 0), 0.8 }

---------------------------------------------------------------------
-- 13 BOARDS. LEADERBOARD (kit Hub.Leaderboard_Board, 14 x 19.5 x 3; the hub's 5 Leaderboard_<Stat>: BoardGui on
-- "Screen", nothing writes it yet). A stone base of slabs on a step, thick posts (chamfered, iron bands, pegs) on
-- footing blocks, top and bottom beams running past the posts, a backing of vertical planks, a moulding around the
-- kept Screen (same part, same size and place: the SurfaceGui fits as before), iron corner brackets with rivets, a
-- small gable of blue shingles over the top beam and the gold trophy on its ridge.
-- Parts: Base, Frame, Iron, Roof, Trophy, Screen (6).
---------------------------------------------------------------------
function PropsBatch2.leaderboard(): Model
	local m = Instance.new("Model")
	m.Name = "leaderboard"
	local rng = Random.new(20261301)
	BEVEL_SELF = true
	local H = 19.5
	local base, frame, iron, roof, trophy = {}, {}, {}, {}, {}
	slabs(base, rng, -7.0, 7.0, 0, 0.6, 3.0, 4, scaled(P.StoneDark, 0.93), H, 0.14)
	slabs(base, rng, -6.6, 6.6, 0.6, 0.45, 2.4, 3, P.StoneDark, H, 0.12)
	merge(m, "Base", base, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(frame, timber(Vector3.new(1.2, 15.95, 1.2), CFrame.new(sx * 5.8, 1.05 + 7.975, 0), graded(P.WoodDark, 9, H, 1), 0.22))
		band(iron, sx * 5.8 - 0.6, sx * 5.8 + 0.6, -0.6, 0.6, 1.5, 0.4)
		band(iron, sx * 5.8 - 0.6, sx * 5.8 + 0.6, -0.6, 0.6, 15.2, 0.4)
		for _, y in ipairs({ 16.1, 16.7, 1.4, 1.8 }) do
			table.insert(frame, piece("Part", Vector3.new(0.26, 0.26, 1.6), CFrame.new(sx * 5.8, y, 0), LOG_END))
		end
		-- corner brackets (front and back) where the beams meet the posts
		for _, fz in ipairs({ -1, 1 }) do
			for _, y in ipairs({ 15.35, 2.45 }) do
				local up = if y > 9 then -1 else 1
				table.insert(iron, piece("Part", Vector3.new(1.2, 0.3, 0.06), CFrame.new(sx * 5.2, y, fz * 0.72), P.Iron))
				table.insert(iron, piece("Part", Vector3.new(0.3, 1.2, 0.06), CFrame.new(sx * 4.75, y + up * 0.45, fz * 0.72), P.Iron))
				rivet(iron, Vector3.new(sx * 5.5, y, fz * 0.76), 0.12)
				rivet(iron, Vector3.new(sx * 4.75, y + up * 0.8, fz * 0.76), 0.12)
			end
		end
	end
	table.insert(frame, timber(Vector3.new(14.0, 1.2, 1.4), CFrame.new(0, 16.4, 0), graded(P.WoodDark, 16.4, H, 0.93), 0.2))
	table.insert(frame, timber(Vector3.new(13.4, 0.8, 1.2), CFrame.new(0, 1.6, 0), graded(P.WoodDark, 1.6, H, 0.93), 0.16))
	-- backing: 6 vertical planks over a dark core, the moulding around the screen
	table.insert(frame, piece("Part", Vector3.new(10.8, 13.8, 0.4), CFrame.new(0, 9.0, 0.05), rgb(81, 45, 26)))
	local prev = nil
	for i = 0, 5 do
		local ti = toneIndex(rng, prev)
		prev = ti
		table.insert(frame, timber(Vector3.new(1.78, 13.9, 0.3), CFrame.new(-4.5 + i * 1.8, 9.0, 0.12), graded(P.WoodMid, 9, H, TONES[ti]), 0.06))
	end
	for _, sy in ipairs({ -1, 1 }) do
		table.insert(frame, timber(Vector3.new(11.0, 0.4, 0.3), CFrame.new(0, 8.6 + sy * 6.5, -0.45), graded(P.WoodDark, 9, H, 1), 0.08))
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(frame, timber(Vector3.new(0.4, 13.4, 0.3), CFrame.new(sx * 5.3, 8.6, -0.45), graded(P.WoodDark, 9, H, 1), 0.08))
	end
	merge(m, "Frame", frame, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Iron", iron, {})
	plain(m, "Screen", Vector3.new(10.2, 12.6, 0.2), CFrame.new(0, 8.6, -0.4), rgb(92, 98, 110), { collide = true })
	shingleRoof(roof, roof, rng, { x0 = -6.9, x1 = 6.9, e = 1.25, yE = 17.0, yR = 17.85, color = rgb(64, 120, 212), ridge = rgb(47, 92, 170), overhang = 0.2 })
	merge(m, "Roof", roof, { collide = true, fidelity = Enum.CollisionFidelity.Hull })
	-- the trophy on the ridge (today's place: cup centre y 18.85)
	table.insert(trophy, octagon(1.3, 0.35, CFrame.new(0, 18.05, 0), scaled(P.Gold, 0.9)))
	table.insert(trophy, octagon(0.45, 0.5, CFrame.new(0, 18.45, 0), P.Gold))
	local cupPlanes = { { 0, 1, 0, 0.55 }, { 0, -1, 0, 0.55 } }
	for k = 0, 7 do
		-- 8 sides flaring upward: radius 0.75 at the middle, about 0.98 at the rim and 0.52 at the foot
		local a = k * math.pi / 4 + math.pi / 8
		local n = Vector3.new(math.cos(a), -0.42, math.sin(a)).Unit
		table.insert(cupPlanes, { n.X, n.Y, n.Z, n:Dot(Vector3.new(math.cos(a), 0, math.sin(a)) * 0.75) })
	end
	table.insert(trophy, convexSolid(Vector3.new(-1.0, -0.55, -1.0), Vector3.new(1.0, 0.55, 1.0), CFrame.new(0, 19.25, 0), P.Gold, cupPlanes))
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(trophy, piece("Part", Vector3.new(0.3, 0.6, 0.14), CFrame.new(sx * 0.98, 19.25, 0), P.Gold))
	end
	merge(m, "Trophy", trophy, { collide = true, fidelity = Enum.CollisionFidelity.Hull })
	local root = m:FindFirstChild("Base") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "leaderboard")
	BEVEL_SELF = false
	return m
end

-- the shared frame of the codes board and the team board (kits Hub.Station_CodesBoard / Station_TeamBoard, 13.4 wide):
-- stone footing blocks, posts, a top beam under the roof, a bottom rail, a planked backing, the board with a moulding,
-- iron brackets, a gable of shingles (colour, ridge)
local function noticeFrame(m: Model, rng: Random, H: number, roofColor: Color3, ridgeColor: Color3)
	local base, frame, iron, roof = {}, {}, {}, {}
	for _, sx in ipairs({ -1, 1 }) do
		pier2(base, rng, { cx = sx * 5.4, cz = 0, w = 1.8, d = 1.8, y0 = 0, y1 = 0.8, n = 2, color = P.StoneDark, H = H, c = 0.1 })
		table.insert(frame, timber(Vector3.new(1.0, 8.8, 1.0), CFrame.new(sx * 5.4, 0.8 + 4.4, 0), graded(P.WoodDark, 5, H, 1), 0.18))
		band(iron, sx * 5.4 - 0.5, sx * 5.4 + 0.5, -0.5, 0.5, 1.2, 0.35)
		for _, fz in ipairs({ -1, 1 }) do
			table.insert(iron, piece("Part", Vector3.new(1.0, 0.28, 0.06), CFrame.new(sx * 4.95, 8.95, fz * 0.53), P.Iron))
			table.insert(iron, piece("Part", Vector3.new(0.28, 1.0, 0.06), CFrame.new(sx * 4.6, 8.6, fz * 0.53), P.Iron))
			rivet(iron, Vector3.new(sx * 5.2, 8.95, fz * 0.57), 0.12)
			rivet(iron, Vector3.new(sx * 4.6, 8.3, fz * 0.57), 0.12)
		end
	end
	table.insert(frame, timber(Vector3.new(12.6, 0.6, 0.9), CFrame.new(0, 9.3, 0), graded(P.WoodDark, 9.3, H, 0.93), 0.12))
	table.insert(frame, timber(Vector3.new(11.6, 0.5, 0.7), CFrame.new(0, 2.0, 0), graded(P.WoodDark, 2, H, 0.93), 0.1))
	table.insert(frame, piece("Part", Vector3.new(9.7, 6.6, 0.3), CFrame.new(0, 5.6, 0.12), rgb(81, 45, 26)))
	local prev = nil
	for i = 0, 5 do
		local ti = toneIndex(rng, prev)
		prev = ti
		table.insert(frame, timber(Vector3.new(1.62, 6.8, 0.36), CFrame.new(-4.05 + i * 1.62, 5.6, -0.03), graded(P.WoodMid, 5.6, H, TONES[ti]), 0.05))
	end
	for _, sy in ipairs({ -1, 1 }) do
		table.insert(frame, timber(Vector3.new(10.6, 0.36, 0.3), CFrame.new(0, 5.6 + sy * 2.98, -0.42), P.WoodDark, 0.07))
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(frame, timber(Vector3.new(0.36, 6.32, 0.3), CFrame.new(sx * 5.12, 5.6, -0.42), P.WoodDark, 0.07))
	end
	shingleRoof(roof, frame, rng, { x0 = -6.5, x1 = 6.5, e = 2.0, yE = 9.6, yR = 11.0, color = roofColor, ridge = ridgeColor, overhang = 0.2 })
	merge(m, "Base", base, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Frame", frame, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	merge(m, "Iron", iron, {})
	merge(m, "Roof", roof, { collide = true, fidelity = Enum.CollisionFidelity.Hull })
	-- the board (today's 10 x 5.6 x 0.3, front face z -0.5)
	plain(m, "Board", Vector3.new(10.0, 5.6, 0.3), CFrame.new(0, 5.6, -0.35), rgb(201, 152, 98), { collide = true })
end

---------------------------------------------------------------------
-- 13 BOARDS. CODES BOARD (kit Hub.Station_CodesBoard; Hub.CodesBoard: its Interact prompt opens Quests > Codes): the
-- notice frame with a red shingle gable, pinned papers of different shapes (tall, wide, folded corner, torn edge, a
-- small note) with written lines and coloured pins, the gold scroll ornament on the ridge.
-- Parts: Base, Frame, Iron, Roof, Board, Papers, Ornament (7, + the kept Interact).
---------------------------------------------------------------------
function PropsBatch2.codes_board(): Model
	local m = Instance.new("Model")
	m.Name = "codes_board"
	local rng = Random.new(20261302)
	BEVEL_SELF = true
	local H = 11.9
	noticeFrame(m, rng, H, rgb(196, 64, 58), rgb(156, 48, 44))
	local papers, ornament = {}, {}
	local INK = rgb(110, 104, 96)
	local PINS = { rgb(212, 52, 60), rgb(64, 120, 212), rgb(255, 201, 60), rgb(88, 204, 52) }
	local specs = {
		{ -3.2, 6.1, 2.2, 2.8, 5, rgb(245, 246, 250), "fold" },
		{ 0.1, 5.3, 2.6, 2.0, -4, rgb(232, 226, 208), "torn" },
		{ 3.2, 6.3, 2.4, 2.1, 3, rgb(240, 232, 190), "plain" },
		{ -0.6, 7.25, 1.4, 1.2, 8, rgb(214, 232, 245), "plain" },
		{ 3.5, 3.95, 1.5, 1.3, -6, rgb(245, 246, 250), "fold" },
	}
	for i, s in ipairs(specs) do
		local cf = CFrame.new(s[1], s[2], -0.53) * CFrame.Angles(0, 0, math.rad(s[5]))
		local size = Vector3.new(s[3], s[4], 0.05)
		local negs = {}
		if s[7] == "fold" then
			table.insert(negs, negWedge(cf, size, "Z", 1, 1, 0.55))
		elseif s[7] == "torn" then
			for k = 0, 5 do
				local x = -s[3] / 2 + 0.22 + k * (s[3] - 0.44) / 5
				table.insert(negs, piece("Part", Vector3.new(0.3, 0.3, 0.3), cf * CFrame.new(x, -s[4] / 2, 0) * CFrame.Angles(0, 0, math.rad(45)), s[6]))
			end
		end
		table.insert(papers, chamfered(size, cf, s[6], {}, 0, negs))
		if s[7] == "fold" then
			-- the folded corner flap: the mirror of the cut triangle (solid corner toward the middle), a bit proud
			local flap = Instance.new("WedgePart")
			flap.Size = Vector3.new(0.05, 0.55, 0.55)
			flap.CFrame = cf * CFrame.new(s[3] / 2 - 0.275, s[4] / 2 - 0.275, -0.04) * CFrame.Angles(0, math.rad(-90), 0)
			flap.Color = scaled(s[6], 0.86)
			flap.Anchored = true
			table.insert(papers, flap)
		end
		-- written lines
		local lines = math.max(2, math.floor((s[4] - 0.7) / 0.32))
		for k = 0, lines - 1 do
			local w = (s[3] - 0.5) * (if k == lines - 1 then 0.55 else rng:NextNumber(0.75, 1.0))
			table.insert(papers, piece("Part", Vector3.new(w, 0.07, 0.03), cf * CFrame.new(-(s[3] - 0.5) / 2 + w / 2, s[4] / 2 - 0.45 - k * 0.32, -0.035), INK))
		end
		-- the pin: a coloured head on an iron needle
		local pin = cf * CFrame.new(0, s[4] / 2 - 0.2, -0.06)
		table.insert(papers, chamfered(Vector3.new(0.3, 0.3, 0.2), pin * CFrame.new(0, 0, -0.1), PINS[(i - 1) % #PINS + 1], { "vertical", "topFrontBack", "bottomFrontBack" }, 0.08))
		table.insert(papers, piece("Part", Vector3.new(0.05, 0.05, 0.2), pin, P.IronWorn))
	end
	merge(m, "Papers", papers, { shadow = false })
	-- the gold scroll ornament standing on the ridge (today's crown: y 10.4 .. 11.9)
	table.insert(ornament, timber(Vector3.new(0.3, 0.5, 0.2), CFrame.new(0, 11.25, 0), P.Gold, 0.04))
	table.insert(ornament, timber(Vector3.new(1.2, 0.18, 0.2), CFrame.new(0, 11.45, 0), P.Gold, 0.04))
	table.insert(ornament, piece("Part", Vector3.new(0.5, 0.5, 0.2), CFrame.new(0, 11.8, 0) * CFrame.Angles(0, 0, math.rad(45)), P.Gold))
	for _, sx in ipairs({ -1, 1 }) do
		scroll(ornament, Vector3.new(sx * 0.55, 11.45, 0), Vector3.new(sx, 0, 0), 0.26, P.Gold, 0.12)
	end
	table.insert(ornament, piece("Part", Vector3.new(0.24, 0.24, 0.24), CFrame.new(0, 12.15, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0), P.Gold))
	merge(m, "Ornament", ornament, { collide = true, fidelity = Enum.CollisionFidelity.Box })
	local root = m:FindFirstChild("Base") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "codes_board")
	BEVEL_SELF = false
	return m
end

---------------------------------------------------------------------
-- 13 BOARDS. TEAM BOARD (kit Hub.Station_TeamBoard; Hub.TeamBoard: the Quartermaster's marker, its Interact prompt
-- opens Team): the notice frame with a blue shingle gable, the 2 team shields (red / blue, today's places) in iron
-- rims with a white chevron, crossed swords between them, 2 flag poles with pennants (red left, blue right, today's).
-- Parts: Base, Frame, Iron, Roof, Board, Icons, Flags (7, + the kept Interact).
---------------------------------------------------------------------
function PropsBatch2.team_board(): Model
	local m = Instance.new("Model")
	m.Name = "team_board"
	local rng = Random.new(20261303)
	BEVEL_SELF = true
	local H = 13.2
	noticeFrame(m, rng, H, rgb(74, 108, 220), rgb(54, 80, 170))
	local icons, flags = {}, {}
	local RED, BLUE = rgb(212, 52, 60), rgb(74, 108, 220)
	for _, spec in ipairs({ { -2.4, RED }, { 2.4, BLUE } }) do
		local f = CFrame.new(spec[1], 5.6, -0.6) * CFrame.Angles(math.rad(90), 0, 0)
		table.insert(icons, octagon(2.2, 0.12, f * CFrame.new(0, 0.04, 0), P.Iron))
		table.insert(icons, octagon(2.0, 0.16, f * CFrame.new(0, -0.04, 0), spec[2]))
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(icons, piece("Part", Vector3.new(0.3, 0.06, 1.1), f * CFrame.new(sx * 0.3, -0.13, 0.05) * CFrame.Angles(0, math.rad(sx * 40), 0), rgb(245, 246, 250)))
		end
		for k = 0, 7 do
			local a = k * math.pi / 4
			rivet(icons, (f * CFrame.new(math.cos(a) * 0.98, -0.1, math.sin(a) * 0.98)).Position, 0.1)
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		local cf = CFrame.new(0, 5.6, -0.6) * CFrame.Angles(0, 0, math.rad(s * 40))
		table.insert(icons, piece("Part", Vector3.new(0.18, 2.2, 0.06), cf * CFrame.new(0, 0.3, 0), P.IronWorn))
		table.insert(icons, piece("Part", Vector3.new(0.6, 0.12, 0.08), cf * CFrame.new(0, -0.8, 0), P.Brass))
		table.insert(icons, piece("Part", Vector3.new(0.12, 0.45, 0.08), cf * CFrame.new(0, -1.1, 0), P.WoodDark))
	end
	merge(m, "Icons", icons, { collide = true, fidelity = Enum.CollisionFidelity.Box })
	-- flag poles on the top beam ends (today's at x +-6.4, y 8.8 .. 13.2) with pennants pointing outward
	for _, spec in ipairs({ { -1, RED }, { 1, BLUE } }) do
		local x = spec[1] * 6.4
		table.insert(flags, octagon(0.36, 4.4, CFrame.new(x, 11.0, 0), P.WoodDark))
		table.insert(flags, fruitPiece(0.42, CFrame.new(x, 13.3, 0), P.Gold))
		local cloth = Instance.new("WedgePart")
		cloth.Size = Vector3.new(0.16, 2.0, 3.4)
		cloth.CFrame = CFrame.new(x + spec[1] * 1.9, 12.0, 0) * CFrame.Angles(0, math.rad(-90 * spec[1]), 0)
		cloth.Color = spec[2]
		cloth.Anchored = true
		table.insert(flags, cloth)
	end
	merge(m, "Flags", flags, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
	local root = m:FindFirstChild("Base") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "team_board")
	BEVEL_SELF = false
	return m
end

---------------------------------------------------------------------
-- 14a BENCH (kit Hub.Bench_A, the old rustic bench of the test zone; no copy in the game): an exact copy of the
-- current hub bench (workspace.Hub.Decor.Props.AFKCorner.Bench: wood slats, blue-grey frame, 2 Seats; BenchService
-- gives hub benches their Sit prompt at run time). Same pivot convention (floor centre, front -Z).
---------------------------------------------------------------------
function PropsBatch2.park_bench(): Model
	local hub = workspace:FindFirstChild("Hub")
	local source: Instance? = nil
	for _, d in ipairs(if hub then hub:GetDescendants() else {}) do
		if d:IsA("Model") and d.Name == "Bench" and d:GetAttribute("BenchVersion") ~= nil then
			source = d
			break
		end
	end
	assert(source, "PropsBatch2.park_bench: no hub Bench to copy")
	local m = (source :: Model):Clone()
	m.Name = "park_bench"
	m:PivotTo(CFrame.identity)
	for key in pairs(m:GetAttributes()) do
		m:SetAttribute(key, nil)
	end
	for _, tag in ipairs(m:GetTags()) do
		m:RemoveTag(tag)
	end
	m:SetAttribute("BenchVersion", (source :: Model):GetAttribute("BenchVersion"))
	local root: BasePart? = nil
	for _, d in ipairs(m:GetChildren()) do
		if d:IsA("BasePart") and not d:IsA("Seat") then
			root = d
			break
		end
	end
	assert(root, "PropsBatch2.park_bench: no frame part")
	m.PrimaryPart = root
	;(root :: BasePart).PivotOffset = (root :: BasePart).CFrame:Inverse()
	m:SetAttribute("MapPropId", "park_bench")
	return m
end

---------------------------------------------------------------------
-- 14b STREET LAMP (kit Hub.LampPost_A, 2.4 x 15.3 x 2.4; the hub's 8 LampPost_A in Hub.Decor.Props.Lamps: always on,
-- no script switches them). A village lamp: a stone base of blocks (plinth, a smaller course, a cap slab), a dark
-- wrought-iron pole (foot collar, rings, a twisted section, a top collar) with 4 scroll brackets under the lantern, the
-- lantern on top (base plate, corner posts and bars, a pyramid roof, finial and ring) around warm glass with a candle
-- flame holding today's PointLight (range 24, brightness 0.9, FFD678) at today's height.
-- Parts: Base, Iron, Glass, Lamp (4).
---------------------------------------------------------------------
function PropsBatch2.street_lamp(): Model
	local m = Instance.new("Model")
	m.Name = "street_lamp"
	local rng = Random.new(20261402)
	BEVEL_SELF = true
	local H = 15.3
	local IRON = rgb(52, 56, 66)
	local base, iron = {}, {}
	-- 1. stone base: plinth of 4 blocks, a course of 2 blocks, a cap slab
	local w = (2.4 - GAP) / 2
	local prev = nil
	for _, ix in ipairs({ -1, 1 }) do
		for _, iz in ipairs({ -1, 1 }) do
			local ti = toneIndex(rng, prev)
			prev = ti
			table.insert(base, chamfered(Vector3.new(w, 0.6, w), CFrame.new(ix * (w / 2 + GAP / 2), 0.3, iz * (w / 2 + GAP / 2)), graded(P.StoneDark, 0.3, H, TONES[ti]), { "vertical", "topFrontBack", "topSides" }, 0.1))
		end
	end
	table.insert(base, piece("Part", Vector3.new(2.1, 0.55, 2.1), CFrame.new(0, 0.3, 0), P.Mortar))
	local w1 = 1.8 * rng:NextNumber(0.42, 0.58) - GAP / 2
	table.insert(base, chamfered(Vector3.new(w1, 0.85, 1.8), CFrame.new(-0.9 + w1 / 2, 0.625 + 0.425, 0), graded(P.Stone, 1, H, 1), { "vertical", "topFrontBack", "topSides" }, 0.1))
	table.insert(base, chamfered(Vector3.new(1.8 - w1 - GAP, 0.85, 1.8), CFrame.new(0.9 - (1.8 - w1 - GAP) / 2, 0.625 + 0.425, 0), graded(P.Stone, 1, H, 0.93), { "vertical", "topFrontBack", "topSides" }, 0.1))
	table.insert(base, piece("Part", Vector3.new(1.5, 0.8, 1.5), CFrame.new(0, 1.05, 0), P.Mortar))
	table.insert(base, chamfered(Vector3.new(2.1, 0.32, 2.1), CFrame.new(0, 1.5 + 0.16, 0), graded(P.StoneDark, 1.7, H, 1), { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.1))
	merge(m, "Base", base, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 2. the iron pole: foot collar, shaft, 2 rings, a twisted section, the top collar
	table.insert(iron, octagon(1.0, 0.25, CFrame.new(0, 1.945, 0), IRON))
	table.insert(iron, octagon(0.75, 0.4, CFrame.new(0, 2.27, 0), IRON))
	table.insert(iron, octagon(0.46, 9.4, CFrame.new(0, 2.47 + 4.7, 0), IRON))
	for _, y in ipairs({ 3.4, 9.8 }) do
		table.insert(iron, octagon(0.66, 0.2, CFrame.new(0, y, 0), IRON))
	end
	for k = 0, 9 do
		table.insert(iron, piece("Part", Vector3.new(0.5, 0.2, 0.5), CFrame.new(0, 6.0 + k * 0.2, 0) * CFrame.Angles(0, math.rad(k * 9), 0), IRON))
	end
	table.insert(iron, octagon(0.8, 0.3, CFrame.new(0, 11.75, 0), IRON))
	-- 4 scroll brackets from the pole up to the lantern's base plate corners
	for k = 0, 3 do
		local a = math.rad(45 + 90 * k)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		scroll(iron, Vector3.new(0, 10.6, 0) + out * 0.23, out, 0.34, IRON, 0.1)
		table.insert(iron, bar(Vector3.new(0, 11.2, 0) + out * 0.25, Vector3.new(0, 12.05, 0) + out * 0.85, 0.1, IRON))
	end
	-- 3. the lantern (centre y 13.3 as today's lamp): base plate, corner posts, bars, roof, finial, ring
	table.insert(iron, chamfered(Vector3.new(1.9, 0.22, 1.9), CFrame.new(0, 12.11, 0), IRON, { "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.07))
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(iron, piece("Part", Vector3.new(0.14, 2.06, 0.14), CFrame.new(sx * 0.72, 13.25, sz * 0.72), IRON))
		end
	end
	for _, y in ipairs({ 12.36, 14.18 }) do
		for _, s in ipairs({ -1, 1 }) do
			table.insert(iron, piece("Part", Vector3.new(1.58, 0.1, 0.1), CFrame.new(0, y, s * 0.72), IRON))
			table.insert(iron, piece("Part", Vector3.new(0.1, 0.1, 1.58), CFrame.new(s * 0.72, y, 0), IRON))
		end
	end
	-- the roof: a 4-sided pyramid from the eave (2.3 wide, y 14.3) to the apex (y 15.0), then a cap and a ring
	local planes = { { 0, -1, 0, -14.28 } }
	for k = 0, 3 do
		local a = k * math.pi / 2
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local n = (d * 0.7 + Vector3.new(0, 1.15, 0)).Unit
		table.insert(planes, { n.X, n.Y, n.Z, n:Dot(Vector3.new(0, 15.0, 0)) })
	end
	table.insert(iron, convexSolid(Vector3.new(-1.2, 14.28, -1.2), Vector3.new(1.2, 15.0, 1.2), CFrame.identity, IRON, planes))
	table.insert(iron, octagon(0.36, 0.2, CFrame.new(0, 14.95, 0), IRON))
	table.insert(iron, piece("Part", Vector3.new(0.08, 0.32, 0.26), CFrame.new(0, 15.2, 0), IRON))
	-- the candle inside
	table.insert(iron, octagon(0.32, 0.5, CFrame.new(0, 12.47, 0), rgb(232, 226, 208)))
	merge(m, "Iron", iron, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 4. warm glass (as the lantern prop's: Neon, transparency 0.5) and the flame with today's light
	local glass = plain(m, "Glass", Vector3.new(1.36, 1.72, 1.36), CFrame.new(0, 13.27, 0), rgb(255, 226, 150), { material = Enum.Material.Neon, collide = true, shadow = false })
	glass.Transparency = 0.5
	local lamp = merge(m, "Lamp", { flame(CFrame.new(0, 12.72, 0), 0.17, 0.25, 0.75, rgb(255, 182, 72)) }, { material = Enum.Material.Neon, shadow = false })
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color = 24, 0.9, rgb(255, 214, 120)
	light.Parent = lamp

	local root = m:FindFirstChild("Base") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "street_lamp")
	BEVEL_SELF = false
	return m
end

---------------------------------------------------------------------
-- 06 GOLEM (kit Plains.Golem_Statue, 43.8 x 39.1 x 36; ServerStorage.BossArenas.Plains.Decor.Golem_Statue, boss-arena
-- decor: nothing reads it by name). The same pose and size, rebuilt in layered stone plates: torso, belly, arms and
-- legs of stacked bands (all edges chamfered, alternately lapping over each other, over a dark core in the joints), a
-- pelvis belt of blocks with a loin plate, knee caps with bosses, fists of 4 knuckle blocks and a thumb, feet with 3
-- toes, a head with a brow over deep eye sockets (glowing eyes) and a grooved jaw; the chest plate with today's cyan
-- runes inlaid in dark grooves around Agent A's faceted core crystal (Neon, Blender_Exports/Props/facets/golem__*.json),
-- which carries today's PointLight; Agent A's faceted shoulder boulders and 3 rubble boulders (CaveRock); engraved
-- zig-zag cracks (today's 6 places and 2 more); moss on the shoulders, the head, a foot, an elbow, the rubble and the
-- base; a carved round base of cut blocks (2 rings around a centre disc, 8 glowing rune tiles). Everything collides
-- as before (moss and the flush inlays excepted).
-- Parts: Plinth, Body, Core, Glow, Moss (5; the old one had 44).
---------------------------------------------------------------------
-- facet planes of Agent A's golem pieces (generated from the JSON faces: outward normal, offset, face colour; coplanar
-- faces merged), in each piece's own frame; place = the JSON "place" (position, orientation in degrees) relative to
-- the Plinth centre (y 0.75 in the model)
PropsBatch2.GOLEM_FACETS = {
	core_crystal = { min = { -1.500, -2.000, -1.300 }, max = { 1.500, 2.000, 0.000 }, place = { 0, 24.12, -7.89, 6.9, 0, 0 }, planes = {
		{ 0.5914, 0.8064, 0.0000, 1.6128, "#56BFE6" },
		{ 0.4603, 0.6277, -0.6277, 1.4438, "#7FDDFF" },
		{ 1.0000, 0.0000, 0.0000, 1.5000, "#56BFE6" },
		{ 0.8000, 0.0000, -0.6000, 1.3800, "#6FD8FF" },
		{ 0.5914, -0.8064, 0.0000, 1.6128, "#56BFE6" },
		{ 0.4603, -0.6277, -0.6277, 1.4438, "#7FDDFF" },
		{ -0.5914, -0.8064, 0.0000, 1.6128, "#56BFE6" },
		{ -0.4603, -0.6277, -0.6277, 1.4438, "#6FD8FF" },
		{ -1.0000, 0.0000, 0.0000, 1.5000, "#56BFE6" },
		{ -0.8000, 0.0000, -0.6000, 1.3800, "#7FDDFF" },
		{ -0.5914, 0.8064, 0.0000, 1.6128, "#56BFE6" },
		{ -0.4603, 0.6277, -0.6277, 1.4438, "#6FD8FF" },
		{ 0.0000, 0.0000, -1.0000, 1.3000, "#97E3FF" },
		{ 0.0000, 0.0000, 1.0000, 0.0000, "#4CAACC" },
	} },
	rubble_1 = { min = { -2.555, 0.000, -2.406 }, max = { 2.801, 2.956, 2.222 }, place = { -10.0, 0.45, -9.0, 0, 80, 0 }, planes = {
		{ -0.5520, 0.3373, -0.7626, 2.7450, "#575464" },
		{ -0.2873, 0.7581, -0.5854, 2.8452, "#5C596A" },
		{ 0.2765, 0.4222, -0.8633, 2.5983, "#4F4C5A" },
		{ 0.2981, 0.3115, -0.9023, 2.4953, "#575464" },
		{ 0.1189, -0.1318, -0.9841, 2.0739, "#474451" },
		{ -0.2559, -0.2410, -0.9362, 2.0175, "#4C4957" },
		{ -0.8190, -0.5713, -0.0522, 1.5413, "#4F4C5A" },
		{ -0.8880, -0.4594, -0.0191, 1.7089, "#45424F" },
		{ -0.9906, -0.1035, -0.0890, 2.2828, "#565262" },
		{ -0.3328, -0.6669, -0.6667, 1.4551, "#494654" },
		{ -0.6529, 0.7069, 0.2719, 2.8799, "#4F4C5A" },
		{ -0.1902, 0.9698, -0.1525, 2.6827, "#595566" },
		{ -0.1784, 0.9647, -0.1938, 2.6790, "#585565" },
		{ 0.3356, 0.8529, -0.3999, 2.8476, "#585465" },
		{ 0.9477, -0.1310, -0.2910, 2.1472, "#4F4C5B" },
		{ 0.8737, -0.1973, -0.4446, 2.0926, "#524E5D" },
		{ 0.5290, -0.0212, -0.8484, 2.2834, "#4D4A58" },
		{ 0.6672, 0.7425, -0.0595, 2.8421, "#5C586A" },
		{ 0.2142, -0.2391, -0.9471, 1.9838, "#4F4C5B" },
		{ 0.0000, -1.0000, 0.0000, 0.0000, "#4F4B5A" },
		{ -0.5688, -0.5346, 0.6251, 1.7357, "#4A4755" },
		{ -0.4126, -0.0887, 0.9066, 2.2596, "#534F5F" },
		{ -0.5016, 0.6406, 0.5814, 2.8631, "#4E4B59" },
		{ 0.0213, 0.7575, 0.6525, 2.7179, "#575364" },
		{ 0.0903, 0.9213, 0.3782, 2.8102, "#605C6D" },
		{ 0.5722, 0.8006, 0.1776, 2.9214, "#504D5C" },
		{ 0.9465, -0.1877, -0.2624, 2.0964, "#45424F" },
		{ 0.3434, 0.2244, 0.9120, 2.2912, "#585464" },
		{ 0.4297, -0.0834, 0.8991, 2.0875, "#514E5D" },
		{ 0.8134, -0.5399, 0.2165, 1.7636, "#4A4755" },
		{ 0.8589, -0.3695, -0.3546, 1.9124, "#4F4C5A" },
		{ 0.2821, -0.2665, 0.9216, 1.8586, "#4F4C5B" },
		{ 0.1342, 0.0183, 0.9908, 2.1038, "#524F5E" },
		{ 0.2486, 0.2667, 0.9312, 2.2839, "#524F5E" },
	} },
	rubble_2 = { min = { -2.167, 0.000, -1.946 }, max = { 1.764, 4.400, 1.922 }, place = { 11.0, 0.45, 8.0, 0, 20, 0 }, planes = {
		{ -0.5096, 0.2787, 0.8140, 2.3014, "#545060" },
		{ -0.7790, 0.4253, 0.4606, 2.7788, "#5B5769" },
		{ -0.9553, -0.0104, -0.2953, 1.7760, "#484552" },
		{ -0.9432, -0.3253, 0.0672, 1.6049, "#4A4755" },
		{ -0.5957, -0.3889, 0.7028, 1.3524, "#4A4755" },
		{ -0.4178, -0.0736, 0.9056, 1.6447, "#524F5E" },
		{ -0.2533, 0.4042, 0.8789, 2.6711, "#565363" },
		{ 0.1799, -0.1070, 0.9779, 1.5993, "#4C4957" },
		{ 0.1895, -0.1000, 0.9768, 1.6116, "#514E5D" },
		{ -0.3837, 0.8580, -0.3414, 3.4740, "#524F5E" },
		{ -0.4676, 0.8089, -0.3565, 3.3260, "#585464" },
		{ 0.1345, 0.8052, 0.5776, 3.7139, "#5F5B6D" },
		{ -0.5740, 0.6177, -0.5376, 2.9452, "#555161" },
		{ -0.8895, 0.0623, -0.4527, 1.8667, "#565263" },
		{ -0.6108, -0.4069, -0.6792, 1.3386, "#44414E" },
		{ 0.0000, -1.0000, 0.0000, 0.0000, "#494654" },
		{ 0.2316, -0.1578, 0.9599, 1.5545, "#44414E" },
		{ 0.8640, 0.4420, 0.2410, 2.5479, "#514D5D" },
		{ 0.3416, -0.1038, 0.9341, 1.6469, "#534F5F" },
		{ 0.5775, -0.0609, 0.8141, 1.7582, "#545161" },
		{ 0.4993, 0.6604, -0.5609, 3.1541, "#514E5D" },
		{ 0.4672, 0.2756, -0.8401, 2.2599, "#595566" },
		{ 0.1394, 0.1993, -0.9700, 2.1902, "#4C4957" },
		{ -0.0215, -0.1023, -0.9945, 1.7321, "#4C4957" },
		{ -0.5857, -0.2596, -0.7678, 1.4858, "#4B4856" },
		{ 0.2760, -0.2984, -0.9137, 1.5141, "#4A4754" },
		{ 0.8987, -0.2170, 0.3812, 1.5482, "#4A4755" },
		{ 0.9993, 0.0101, 0.0350, 1.7594, "#4E4A59" },
		{ 0.8543, -0.1282, -0.5037, 1.5559, "#514D5C" },
		{ 0.7414, -0.0660, -0.6678, 1.6609, "#534F5F" },
	} },
	rubble_3 = { min = { -1.583, 0.000, -1.214 }, max = { 1.426, 2.170, 1.393 }, place = { 7.5, 0.45, -10.5, 0, -35, 0 }, planes = {
		{ -0.7499, -0.0807, -0.6566, 1.1088, "#4E4A59" },
		{ -0.5466, 0.4226, -0.7230, 1.4997, "#535060" },
		{ 0.2157, 0.1300, -0.9678, 1.1728, "#4C4958" },
		{ 0.2239, 0.0962, -0.9698, 1.1434, "#474451" },
		{ -0.5960, -0.2886, -0.7493, 0.9734, "#4F4C5B" },
		{ -0.9534, -0.2887, -0.0880, 1.1072, "#4B4856" },
		{ 0.0000, -1.0000, 0.0000, 0.0000, "#494654" },
		{ -0.8621, 0.1213, 0.4920, 1.5090, "#565262" },
		{ -0.6430, 0.5844, 0.4950, 1.8146, "#5C5869" },
		{ -0.3236, 0.9013, -0.2879, 1.7978, "#575364" },
		{ -0.9680, -0.2401, 0.0723, 1.1902, "#524F5E" },
		{ 0.3477, 0.7028, -0.6207, 1.7256, "#5E5A6B" },
		{ 0.9703, -0.0038, -0.2420, 1.2762, "#524F5E" },
		{ 0.8497, -0.2005, -0.4877, 1.1035, "#504D5C" },
		{ 0.4182, -0.1291, -0.8992, 1.0355, "#4B4856" },
		{ 0.8685, 0.4956, 0.0115, 1.5547, "#4E4A59" },
		{ -0.5236, -0.5665, 0.6363, 0.8875, "#4F4C5A" },
		{ -0.5188, -0.4221, 0.7434, 1.0194, "#4B4856" },
		{ 0.1621, -0.0483, 0.9856, 1.1917, "#4F4C5A" },
		{ -0.1093, 0.6866, 0.7188, 1.7997, "#4F4C5B" },
		{ 0.0512, 0.8857, 0.4615, 1.9437, "#524E5E" },
		{ 0.8584, 0.5077, 0.0729, 1.5746, "#4F4B5A" },
		{ 0.6527, -0.1489, 0.7428, 1.1597, "#4D4A59" },
		{ 0.7550, -0.4233, 0.5009, 1.0281, "#4F4C5B" },
		{ 0.3477, -0.1731, 0.9215, 1.0773, "#464350" },
	} },
	shoulder_L = { min = { -6.016, 0.000, -4.694 }, max = { 5.960, 8.170, 4.902 }, place = { -13.0, 24.2, 0.5, 0, -40, 8 }, planes = {
		{ -0.7146, 0.6552, -0.2450, 6.9038, "#595566" },
		{ -0.6947, 0.0677, -0.7161, 4.5154, "#585565" },
		{ -0.6107, 0.0252, -0.7915, 4.4620, "#555161" },
		{ -0.2430, -0.0615, -0.9681, 4.2832, "#4F4B5A" },
		{ 0.0565, -0.0202, -0.9982, 4.4771, "#575363" },
		{ 0.5539, 0.5891, -0.5884, 6.8569, "#5D596A" },
		{ 0.4085, 0.8717, -0.2706, 7.7006, "#5F5C6D" },
		{ 0.0227, 0.9971, -0.0731, 8.0989, "#605C6E" },
		{ -0.7674, 0.6232, -0.1506, 6.7539, "#5F5B6D" },
		{ -0.0848, 0.9582, 0.2733, 8.0046, "#524F5E" },
		{ -0.8427, 0.0159, -0.5381, 4.4718, "#545060" },
		{ -0.8099, 0.5703, -0.1369, 6.6055, "#5B5768" },
		{ -0.8888, -0.1588, -0.4300, 4.2978, "#4A4755" },
		{ 0.0000, -1.0000, 0.0000, 0.0000, "#44414E" },
		{ -0.3631, -0.2296, -0.9030, 3.9685, "#44414E" },
		{ 0.4847, -0.4234, -0.7654, 3.5198, "#4A4755" },
		{ 0.9008, -0.0705, -0.4284, 4.9403, "#4F4C5A" },
		{ 0.9609, -0.2362, 0.1447, 4.3003, "#464350" },
		{ 0.5902, 0.1328, 0.7962, 4.3258, "#464350" },
		{ 0.5660, 0.1634, 0.8081, 4.3664, "#4A4654" },
		{ 0.5010, 0.3524, 0.7905, 5.1207, "#5E5A6B" },
		{ 0.2047, 0.5479, 0.8111, 6.0588, "#5E5A6C" },
		{ -0.6770, -0.1216, 0.7258, 4.5465, "#494654" },
		{ -0.1192, 0.0813, 0.9895, 4.7654, "#4A4755" },
		{ -0.2345, 0.0015, 0.9721, 4.5974, "#474451" },
		{ -0.7556, -0.5653, 0.3308, 3.0642, "#4A4755" },
	} },
	shoulder_R = { min = { -5.960, 0.000, -4.694 }, max = { 6.016, 8.170, 4.902 }, place = { 13.0, 24.2, 0.5, 0, 40, -8 }, planes = {
		{ 0.7146, 0.6552, -0.2450, 6.9038, "#595566" },
		{ 0.6947, 0.0677, -0.7161, 4.5154, "#585565" },
		{ 0.6107, 0.0252, -0.7915, 4.4620, "#555161" },
		{ 0.2430, -0.0615, -0.9681, 4.2832, "#4F4B5A" },
		{ -0.0565, -0.0202, -0.9982, 4.4771, "#575363" },
		{ -0.5539, 0.5891, -0.5884, 6.8569, "#5D596A" },
		{ -0.4085, 0.8717, -0.2706, 7.7006, "#5F5C6D" },
		{ -0.0227, 0.9971, -0.0731, 8.0989, "#605C6E" },
		{ 0.7674, 0.6232, -0.1506, 6.7539, "#5F5B6D" },
		{ 0.0848, 0.9582, 0.2733, 8.0046, "#524F5E" },
		{ 0.8427, 0.0159, -0.5381, 4.4718, "#545060" },
		{ 0.8099, 0.5703, -0.1369, 6.6055, "#5B5768" },
		{ 0.8888, -0.1588, -0.4300, 4.2978, "#4A4755" },
		{ 0.0000, -1.0000, 0.0000, 0.0000, "#44414E" },
		{ 0.3631, -0.2296, -0.9030, 3.9685, "#44414E" },
		{ -0.4847, -0.4234, -0.7654, 3.5198, "#4A4755" },
		{ -0.9008, -0.0705, -0.4284, 4.9403, "#4F4C5A" },
		{ -0.9609, -0.2362, 0.1447, 4.3003, "#464350" },
		{ -0.5902, 0.1328, 0.7962, 4.3258, "#464350" },
		{ -0.5660, 0.1634, 0.8081, 4.3664, "#4A4654" },
		{ -0.5010, 0.3524, 0.7905, 5.1207, "#5E5A6B" },
		{ -0.2047, 0.5479, 0.8111, 6.0588, "#5E5A6C" },
		{ 0.6770, -0.1216, 0.7258, 4.5465, "#494654" },
		{ 0.1192, 0.0813, 0.9895, 4.7654, "#4A4755" },
		{ 0.2345, 0.0015, 0.9721, 4.5974, "#474451" },
		{ 0.7556, -0.5653, 0.3308, 3.0642, "#4A4755" },
	} },
}

local GOLEM_H = 39.1
local GOLEM_JOINT = rgb(70, 74, 88)
local GOLEM_CRACK = rgb(62, 60, 78)
local GOLEM_GLOW = rgb(90, 230, 255) -- today's runes and light
local CAVE_ROCK = rgb(96, 92, 110)
local ALL_EDGES = { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }

-- a zig-zag crack (3 tapering segments) of length len along the local Y of cf (local Z = out of the face), as
-- negative-part specs { size, cf }
local function crackSpecs(cf: CFrame, len: number, rng: Random): { any }
	local pts = {}
	for k = 0, 3 do
		local x = if k == 0 or k == 3 then 0 else rng:NextNumber(-0.35, 0.35)
		table.insert(pts, Vector3.new(x, -len / 2 + len * k / 3, 0))
	end
	local specs = {}
	for k = 1, 3 do
		local a, b = pts[k], pts[k + 1]
		local d = b - a
		table.insert(specs, { Vector3.new(0.23 - 0.03 * k, d.Magnitude + 0.12, 1.4), cf * CFrame.new((a + b) / 2) * CFrame.Angles(0, 0, math.atan2(-d.X, d.Y)) })
	end
	return specs
end

-- fresh crack negative parts (dark: their colour stays on the faces they cut) for the specs that reach the box (size at cf)
local function cracksIn(specs: { any }?, size: Vector3, cf: CFrame): { BasePart }
	local list = {}
	for _, s in ipairs(specs or {}) do
		local p = cf:PointToObjectSpace(s[2].Position)
		local reach = s[1].Y / 2
		if math.abs(p.X) <= size.X / 2 + reach and math.abs(p.Y) <= size.Y / 2 + reach and math.abs(p.Z) <= size.Z / 2 + 0.8 then
			table.insert(list, piece("Part", s[1], s[2], GOLEM_CRACK))
		end
	end
	return list
end

-- a body segment of layered stone plates: the box (size at cf) cut along its own Y into o.n bands (0.14 joints) over
-- a dark core; the bands alternately 0.24 wider (each layer laps over the next), all edges chamfered (o.c), tones
-- never the neighbour's, the A9 gradient; o.cracks (crack specs) engrave the bands they reach
local function stonePlates(list: { BasePart }, rng: Random, size: Vector3, cf: CFrame, color: Color3, o: any)
	local n = o.n or 3
	local gap = 0.14
	local hb = (size.Y - gap * (n - 1)) / n
	table.insert(list, piece("Part", Vector3.new(size.X - 0.6, size.Y - 0.1, size.Z - 0.6), cf, GOLEM_JOINT))
	local prev = nil
	for k = 1, n do
		local y = -size.Y / 2 + hb / 2 + (k - 1) * (hb + gap)
		local grow = if (k + (if o.flip then 1 else 0)) % 2 == 1 then 0.24 else 0
		local s = Vector3.new(size.X + grow, hb, size.Z + grow)
		local bcf = cf * CFrame.new(rng:NextNumber(-0.05, 0.05), y, rng:NextNumber(-0.05, 0.05))
		local ti = toneIndex(rng, prev)
		prev = ti
		table.insert(list, chamfered(s, bcf, graded(color, bcf.Position.Y, GOLEM_H, TONES[ti]), ALL_EDGES, o.c or 0.35, nil, cracksIn(o.cracks, s, bcf)))
	end
end

-- the frame of one of Agent A's golem pieces in the model
local function golemFacetCF(name: string): CFrame
	local p = PropsBatch2.GOLEM_FACETS[name].place
	return CFrame.new(p[1], p[2] + 0.75, p[3]) * CFrame.fromOrientation(math.rad(p[4]), math.rad(p[5]), math.rad(p[6]))
end

local function golemFacet(name: string, color: Color3, material: Enum.Material?): BasePart
	local f = PropsBatch2.GOLEM_FACETS[name]
	return convexSolid(Vector3.new(table.unpack(f.min)), Vector3.new(table.unpack(f.max)), golemFacetCF(name), color, f.planes, material)
end

-- a moss pad (thick t, default 0.3) with a smaller cushion on it, lying in the frame cf (its Y = up), sunk into what
-- carries it
local function mossPad(list: { BasePart }, rng: Random, cf: CFrame, len: number, t: number?)
	local th = t or 0.3
	local col = if rng:NextNumber() < 0.5 then P.Moss else P.MossDark
	local tone = rng:NextNumber(0.78, 0.92)
	table.insert(list, chamfered(Vector3.new(len, th, len * 0.6), cf * CFrame.new(0, th / 2 - 0.08, 0), scaled(col, tone), { "topFrontBack", "topSides" }, th * 0.4))
	table.insert(list, chamfered(Vector3.new(len * 0.6, th * 0.6, len * 0.34), cf * CFrame.new(rng:NextNumber(-0.15, 0.15) * len, th - 0.02, rng:NextNumber(-0.06, 0.06) * len), scaled(col, tone * 1.06), { "topFrontBack", "topSides" }, th * 0.25))
end

-- a moss cap on one of Agent A's facet pieces: the piece's own facets pushed out by `grow` (moss tones per facet), cut
-- about `drop` below its top by a slightly tilted plane: a faceted cushion that hugs the rock
local function mossCap(name: string, drop: number, grow: number, rng: Random): BasePart
	local f = PropsBatch2.GOLEM_FACETS[name]
	local top = f.max[2]
	local planes = {}
	for i, pl in ipairs(f.planes) do
		table.insert(planes, { pl[1], pl[2], pl[3], pl[4] + grow, scaled(if i % 2 == 0 then P.Moss else P.MossDark, rng:NextNumber(0.8, 0.95)) })
	end
	local n = Vector3.new(rng:NextNumber(-0.15, 0.15), -1, rng:NextNumber(-0.15, 0.15)).Unit
	table.insert(planes, { n.X, n.Y, n.Z, n:Dot(Vector3.new(0, top - drop, 0)), scaled(P.MossDark, 0.78) })
	local pad = grow + 0.1
	return convexSolid(Vector3.new(f.min[1] - pad, top - drop - 1.2, f.min[3] - pad), Vector3.new(f.max[1] + pad, top + pad, f.max[3] + pad), golemFacetCF(name), P.Moss, planes)
end

function PropsBatch2.golem_statue(): Model
	local m = Instance.new("Model")
	m.Name = "golem_statue"
	local rng = Random.new(20261006)
	BEVEL_SELF = true
	local H = GOLEM_H
	local STONE, STONE_D = P.Stone, P.StoneDark -- today's 969CA8 / 686E7C
	local plinth, body, glow, mossList = {}, {}, {}, {}
	local rad = math.rad
	local function ori(x: number, y: number, z: number, rx: number, ry: number, rz: number): CFrame
		return CFrame.new(x, y, z) * CFrame.fromOrientation(rad(rx), rad(ry), rad(rz))
	end

	-- cracks: today's 6 places and 2 more (each a CFrame on the face it is cut into, and a length)
	local cracks = {}
	for _, c in ipairs({
		{ ori(4.6, 7.1, -4.1, 0, 0, -24), 3.4 }, { ori(-5.5, 9.5, -4.1, 0, 0, 18), 4.0 },
		{ ori(7.6, 23.1, -7.2, 7, 0, -30), 3.0 }, { ori(-7.4, 22.0, -7.0, 7, 0, -20), 4.5 },
		{ ori(16.4, 12.5, -5.9, -4, 0, 14), 4.6 }, { ori(6.5, 26.5, -7.6, 7, 0, 25), 5.0 },
		{ ori(-14.4, 24.2, -3.1, 6, 0, 7), 3.2 }, { ori(-3.6, 15.0, -4.8, 0, 0, 32), 2.6 },
	}) do
		for _, s in ipairs(crackSpecs(c[1], c[2], rng)) do
			table.insert(cracks, s)
		end
	end

	-- 1. the carved base: an outer ring of 24 cut blocks, an inner ring of 14, a centre disc, 8 glowing rune tiles
	local front = rad(270)
	ringBlocks(plinth, rng, { n = 24, ro = 18, ri = 12.7, y0 = 0, h = 1.5, color = STONE_D, H = H, c = 0.3, a0 = front })
	ringBlocks(plinth, rng, { n = 14, ro = 12.75, ri = 6.4, y0 = 0, h = 1.5, color = scaled(STONE, 0.9), H = H, c = 0.18, a0 = front + rad(12.86), noJitter = true, noCore = true })
	table.insert(plinth, prism16(12.6, 1.45, CFrame.new(0, 0.75, 0), scaled(STONE_D, 1.06)))
	for k = 0, 7 do
		local a = rad(22.5 + 45 * k)
		local pos = Vector3.new(math.cos(a) * 9.6, 1.475, math.sin(a) * 9.6)
		local turn = CFrame.new(pos) * CFrame.Angles(0, -a + rad(45), 0)
		table.insert(plinth, chamfered(Vector3.new(1.5, 0.1, 1.5), turn * CFrame.new(0, 0.05, 0), GOLEM_CRACK, { "topFrontBack", "topSides" }, 0.04))
		table.insert(glow, piece("Part", Vector3.new(0.95, 0.12, 0.95), turn * CFrame.new(0, 0.1, 0), GOLEM_GLOW, { material = Enum.Material.Neon }))
	end
	-- Agent A's rubble boulders, sunk 0.3 into the base top
	for _, name in ipairs({ "rubble_1", "rubble_2", "rubble_3" }) do
		table.insert(plinth, golemFacet(name, CAVE_ROCK))
	end
	merge(m, "Plinth", plinth, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 2. legs, knees, feet
	for _, sx in ipairs({ -1, 1 }) do
		stonePlates(body, rng, Vector3.new(7, 10, 8), ori(sx * 5.5, 9, 0, 0, 0, -sx * 3), STONE, { n = 3, c = 0.3, cracks = cracks, flip = sx > 0 })
		local kneeCF = ori(sx * 5.6, 9.5, 0, 0, 0, -sx * 3)
		table.insert(body, chamfered(Vector3.new(7.6, 2.4, 8.6), kneeCF, graded(STONE_D, 9.5, H, 1), ALL_EDGES, 0.4, nil, cracksIn(cracks, Vector3.new(7.6, 2.4, 8.6), kneeCF)))
		table.insert(body, chamfered(Vector3.new(3.4, 2.0, 0.9), kneeCF * CFrame.new(0, 0, -4.55), graded(STONE_D, 9.5, H, 0.93), ALL_EDGES, 0.3))
		-- the foot: a heel block and 3 toes
		table.insert(body, chamfered(Vector3.new(8.5, 3, 7.4), CFrame.new(sx * 5.5, 3, 0.8), graded(STONE_D, 3, H, 1), ALL_EDGES, 0.4))
		table.insert(body, piece("Part", Vector3.new(8.1, 2.2, 3.4), CFrame.new(sx * 5.5, 2.7, -3.6), GOLEM_JOINT))
		local prev = nil
		for t = -1, 1 do
			local ti = toneIndex(rng, prev)
			prev = ti
			table.insert(body, chamfered(Vector3.new(2.65, 2.4, 3.7), CFrame.new(sx * 5.5 + t * 2.86, 2.7, -4.75), graded(STONE_D, 2.7, H, TONES[ti]), ALL_EDGES, 0.45))
		end
	end

	-- 3. pelvis: a belt of 4 blocks over a dark core, a loin plate in front
	table.insert(body, piece("Part", Vector3.new(16.4, 4.9, 8.9), CFrame.new(0, 15.5, 0), GOLEM_JOINT))
	do
		local x, prev = -8.5, nil
		local widths = { 4.0, 4.4, 4.3 }
		for k = 1, 4 do
			local w = if k < 4 then widths[k] else 8.5 - x
			local ti = toneIndex(rng, prev)
			prev = ti
			local cf = CFrame.new(x + w / 2, 15.5, rng:NextNumber(-0.05, 0.05))
			local size = Vector3.new(w, 5, 9.5)
			table.insert(body, chamfered(size, cf, graded(STONE_D, 15.5, H, TONES[ti]), ALL_EDGES, 0.35, nil, cracksIn(cracks, size, cf)))
			x += w + 0.12
		end
	end
	table.insert(body, chamfered(Vector3.new(5.4, 3.8, 0.7), ori(0, 13.4, -5.0, -6, 0, 0), graded(STONE, 13.4, H, 0.93), ALL_EDGES, 0.25))

	-- 4. belly (2 bands) and torso (3 bands, leaning 7 degrees as today)
	stonePlates(body, rng, Vector3.new(12, 3.4, 9), CFrame.new(0, 18.9, -0.4), STONE_D, { n = 2, c = 0.3 })
	local torsoCF = ori(0, 24, -0.6, 7, 0, 0)
	stonePlates(body, rng, Vector3.new(21, 12, 12.5), torsoCF, STONE, { n = 3, c = 0.45, cracks = cracks, flip = true })

	-- 5. the chest plate: today's runes inlaid in dark grooves (the glowing stroke 0.05 proud), the core crystal on it
	local chestCF = ori(0, 24.8, -7.3, 7, 0, 0)
	local runes = {
		{ -5, 0, 0.7, 2.0, 0 }, { 5, 0, 0.7, 2.0, 0 },
		{ -1.6, 2.6, 3.0, 0.7, 28 }, { 1.6, 2.6, 3.0, 0.7, -28 },
		{ -1.6, -2.6, 3.0, 0.7, -28 }, { 1.6, -2.6, 3.0, 0.7, 28 },
	}
	local grooves = {}
	for _, r in ipairs(runes) do
		local cf = chestCF * CFrame.new(r[1], r[2], 0) * CFrame.Angles(0, 0, rad(r[5]))
		table.insert(grooves, piece("Part", Vector3.new(r[3] + 0.24, r[4] + 0.24, 0.6), cf * CFrame.new(0, 0, -0.6), GOLEM_CRACK))
		table.insert(glow, piece("Part", Vector3.new(r[3], r[4], 0.4), cf * CFrame.new(0, 0, -0.45), GOLEM_GLOW, { material = Enum.Material.Neon }))
	end
	for _, c in ipairs(cracksIn(cracks, Vector3.new(15, 8.5, 1.2), chestCF)) do
		table.insert(grooves, c)
	end
	table.insert(body, chamfered(Vector3.new(15, 8.5, 1.2), chestCF, graded(STONE_D, 24.8, H, 1), ALL_EDGES, 0.3, nil, grooves))
	-- the plate's rim: 4 proud border strips (top / bottom / sides), the layered look of a carved breastplate
	for _, b in ipairs({ { 0, 4.0, 15.2, 0.5 }, { 0, -4.0, 15.2, 0.5 }, { -7.25, 0, 0.7, 7.4 }, { 7.25, 0, 0.7, 7.4 } }) do
		table.insert(body, chamfered(Vector3.new(b[3], b[4], 0.5), chestCF * CFrame.new(b[1], b[2], -0.65), graded(STONE, 24.8, H, 0.93), ALL_EDGES, 0.15))
	end

	-- 6. arms: upper arms and forearms of bands, fists of 4 knuckles and a thumb; Agent A's shoulder boulders
	for _, sx in ipairs({ -1, 1 }) do
		stonePlates(body, rng, Vector3.new(6.5, 10, 7), ori(sx * 14.8, 23, 0.5, 6, 0, sx * 8), STONE, { n = 3, c = 0.3, cracks = cracks })
		stonePlates(body, rng, Vector3.new(8.5, 12, 9), ori(sx * 16.2, 12, -1.2, -4, 0, sx * 3), STONE_D, { n = 3, c = 0.4, cracks = cracks, flip = true })
		local fistCF = ori(sx * 16.4, 5.7, -1.6, -4, 0, sx * 3)
		table.insert(body, chamfered(Vector3.new(9.4, 5, 7), fistCF * CFrame.new(0, 0, 1.5), graded(STONE, 5.7, H, 1), ALL_EDGES, 0.45))
		table.insert(body, piece("Part", Vector3.new(9.0, 4.0, 3.0), fistCF * CFrame.new(0, -0.2, -2.6), GOLEM_JOINT))
		local prev = nil
		for f = 0, 3 do
			local ti = toneIndex(rng, prev)
			prev = ti
			table.insert(body, chamfered(Vector3.new(2.15, 4.4, 3.2), fistCF * CFrame.new(-3.48 + f * 2.32, -0.2, -3.4), graded(STONE, 5.5, H, TONES[ti]), ALL_EDGES, 0.5))
		end
		table.insert(body, chamfered(Vector3.new(2.0, 2.4, 4.2), fistCF * CFrame.new(-sx * 5.4, 1.0, -1.4), graded(STONE, 6.7, H, 0.93), ALL_EDGES, 0.4))
		table.insert(body, golemFacet(if sx < 0 then "shoulder_L" else "shoulder_R", CAVE_ROCK))
	end

	-- 7. the head: brow over deep eye sockets (glowing eyes), a grooved jaw, a crown plate
	local headCF = ori(0, 32.9, -3, 20, 0, 0)
	local sockets = {}
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(sockets, piece("Part", Vector3.new(1.9, 1.3, 1.0), headCF * CFrame.new(sx * 1.8, -0.2, -3.75), GOLEM_CRACK))
		table.insert(glow, piece("Part", Vector3.new(1.5, 0.9, 0.4), headCF * CFrame.new(sx * 1.8, -0.2, -3.48), GOLEM_GLOW, { material = Enum.Material.Neon }))
	end
	table.insert(body, chamfered(Vector3.new(7.5, 7, 7.5), headCF, graded(STONE, 32.9, H, 1), ALL_EDGES, 0.6, nil, sockets))
	table.insert(body, chamfered(Vector3.new(8.2, 1.8, 2), headCF * CFrame.new(0, 1.2, -3.4), graded(STONE_D, 35.2, H, 1), ALL_EDGES, 0.35))
	local teeth = {}
	for t = -1, 1 do
		table.insert(teeth, piece("Part", Vector3.new(0.16, 1.4, 0.5), headCF * CFrame.new(t * 1.2, -3.2, -4.0), GOLEM_CRACK))
	end
	table.insert(body, chamfered(Vector3.new(5, 2.2, 1.6), headCF * CFrame.new(0, -2.99, -3.2), graded(STONE_D, 31.2, H, 0.93), ALL_EDGES, 0.3, nil, teeth))
	table.insert(body, chamfered(Vector3.new(6.2, 0.6, 6.2), headCF * CFrame.new(0, 3.6, 0.1), graded(STONE_D, 36.4, H, 1), ALL_EDGES, 0.2))
	merge(m, "Body", body, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 8. the core crystal (Agent A's facets, Neon) with today's light; the flush glowing inlays
	local core = merge(m, "Core", { golemFacet("core_crystal", rgb(95, 212, 255), Enum.Material.Neon) }, { collide = true, material = Enum.Material.Neon, shadow = false })
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color, light.Shadows = 12, 0.6, GOLEM_GLOW, false
	light.Parent = core
	merge(m, "Glow", glow, { material = Enum.Material.Neon, shadow = false })

	-- 9. moss: the shoulders, the head, a foot, the left elbow, the biggest rubble, the base
	for _, name in ipairs({ "shoulder_L", "shoulder_R" }) do
		table.insert(mossList, mossCap(name, 1.7, 0.22, rng))
	end
	table.insert(mossList, mossCap("rubble_1", 0.9, 0.16, rng))
	table.insert(mossList, mossCap("rubble_2", 1.1, 0.16, rng))
	mossPad(mossList, rng, headCF * CFrame.new(0.5, 3.9, 0.4) * CFrame.Angles(0, 0.5, 0), 4.2, 0.5)
	mossPad(mossList, rng, CFrame.new(5.2, 3.9, -4.4) * CFrame.Angles(0, 0.2, 0), 3.4, 0.45)
	mossPad(mossList, rng, CFrame.new(-16.7, 18.0, -4.5) * CFrame.Angles(rad(-4), 0.3, rad(-3)), 3.4, 0.45)
	for _, p in ipairs({ { 9.0, -5.5, 0.6 }, { -9.6, 4.0, 2.2 }, { 2.5, 10.5, -0.3 }, { -3.5, -11.8, 1.4 }, { 13.2, -2.0, 1.9 }, { -12.6, -6.0, 0.9 } }) do
		mossPad(mossList, rng, CFrame.new(p[1], 1.5, p[2]) * CFrame.Angles(0, p[3], 0), rng:NextNumber(3.0, 4.2), 0.4)
	end
	for _, a in ipairs({ 200, 335, 60, 120, 255 }) do
		local t = rad(a)
		mossPad(mossList, rng, CFrame.new(math.cos(t) * 18.0, 0, math.sin(t) * 18.0) * CFrame.Angles(0, -t + math.pi / 2, 0), rng:NextNumber(3.4, 4.6), 0.55)
	end
	merge(m, "Moss", mossList, {})

	local root = m:FindFirstChild("Plinth") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "golem_statue")
	BEVEL_SELF = false
	return m
end

---------------------------------------------------------------------
-- 07 WINDMILL (kit Plains.Windmill, 53.2 x 62.6 x 27; Zones.Plains.Plains_1.Decor.Landmark, attr LandmarkName, with
-- its NoClimb folder of 17 invisible walls kept by SyncMapProps: MapPropKeep). Same tower, roof and sails as today:
-- a tapered round base of 3 courses of cut blocks under an overhanging cap ring, a stone landing with 2 slabs at the
-- door; the white plastered octagonal tower (3 storeys, today's taper) in a dark timber frame (8 corner posts, girts
-- at the sill, the 2 floors and the top plate, diagonal braces), corbels under the eave; a planked door with strap
-- hinges, a ring pull and a timber door frame; the 3 windows framed (sill, cross bars), the front one with an open
-- planked shutter on iron hinges; an octagonal roof of individual red shingles (today's red, hips capped) with a valance
-- and a gold finial; the static sails (no script, as today): a hub with iron bands and a gold cap, a toothed brake wheel
-- behind it, the axle in a bearing frame, 4 stocks with lattice frames (rail, 8 bars) and cream cloth panels; moss at
-- the foot and on the cap ring. Collisions as the game copy: everything collides except the sails and the moss.
-- Parts: Base, Tower, Timber, Roof, Glass, Iron, Sails, Moss (8; the old one had 94).
---------------------------------------------------------------------
local WM_SLOPE = 0.0925 -- today's taper: the face apothem shrinks 0.0925 per stud of height
local function wmApothem(y: number): number
	return 9.24 - WM_SLOPE * (y - 20)
end

-- the frame of face k (0..7, centred on 45k degrees) at height y: X along the face (increasing angle), Y up the face
-- (along the taper), local -Z = outward, origin on the face's centre line
local function wmFace(k: number, y: number): CFrame
	local a = math.rad(45 * k)
	local d = Vector3.new(math.cos(a), 0, math.sin(a))
	local t = Vector3.new(-math.sin(a), 0, math.cos(a))
	local u = (Vector3.yAxis - d * WM_SLOPE).Unit
	return CFrame.fromMatrix(d * wmApothem(y) + Vector3.new(0, y, 0), t, u)
end

-- a timber between two points (its long axis = Y), turned so its local -Z faces `out`
local function beamBetween(a: Vector3, b: Vector3, w: number, d: number, out: Vector3, color: Color3): BasePart
	local up = (b - a).Unit
	local x = out:Cross(up).Unit
	return timber(Vector3.new(w, (b - a).Magnitude, d), CFrame.fromMatrix((a + b) / 2, x, up), color)
end

function PropsBatch2.windmill(): Model
	local m = Instance.new("Model")
	m.Name = "windmill"
	local rng = Random.new(20261007)
	BEVEL_SELF = true
	local H = 63
	local rad = math.rad
	local tan8 = math.tan(math.pi / 8)
	local STONE, STONE_D = P.Stone, P.StoneDark
	local WOOD, WOOD_MID = P.WoodDark, P.WoodMid
	local IRON = rgb(52, 56, 66)
	local PLASTER = rgb(247, 236, 210)
	local RED = rgb(197, 64, 58) -- today's roof
	local GLASS = rgb(95, 212, 255)
	local CLOTH = rgb(232, 226, 208)
	local base, tower, wood, roof, glass, iron, sails, mossList = {}, {}, {}, {}, {}, {}, {}, {}

	-- 1. the base: 3 tapered courses of cut blocks, an overhanging cap ring, the landing at the door
	ringBlocks(base, rng, { n = 24, ro = 12.6, ri = 9.4, y0 = 0, h = 1.7, color = STONE, H = H, c = 0.2, a0 = rad(270) })
	ringBlocks(base, rng, { n = 22, ro = 12.35, ri = 9.4, y0 = 1.7, h = 1.6, color = STONE, H = H, c = 0.2, a0 = rad(278) })
	ringBlocks(base, rng, { n = 20, ro = 12.1, ri = 9.4, y0 = 3.3, h = 1.5, color = STONE, H = H, c = 0.2, a0 = rad(270) })
	ringBlocks(base, rng, { n = 26, ro = 13.0, ri = 10.2, y0 = 4.8, h = 1.2, color = STONE_D, H = H, c = 0.22, a0 = rad(275), noCore = true })
	do
		-- the landing pier (2 courses of 2 blocks over a core) and today's step slab split in two
		table.insert(base, piece("Part", Vector3.new(8.6, 4.75, 3.6), CFrame.new(0, 2.4, -12.5), P.Mortar))
		local prev = nil
		for c, y0 in ipairs({ 0, 2.4 }) do
			local split = if c == 1 then -0.6 else 0.7
			for _, s in ipairs({ { -4.5, split }, { split, 4.5 } }) do
				local w = s[2] - s[1] - GAP
				local ti = toneIndex(rng, prev)
				prev = ti
				table.insert(base, chamfered(Vector3.new(w, 2.35, 4.0), CFrame.new((s[1] + s[2]) / 2, y0 + 1.2, -12.5 + jit(rng) * -0.5), graded(STONE, y0 + 1.2, H, TONES[ti]), { "vertical", "topFrontBack", "topSides" }, 0.16))
			end
		end
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(base, chamfered(Vector3.new(4.45, 1.2, 4.2), CFrame.new(sx * 2.275, 5.4, -12.5), graded(STONE_D, 5.4, H, if sx < 0 then 1 else 0.93), { "vertical", "topFrontBack", "topSides" }, 0.18))
		end
	end
	merge(m, "Base", base, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	-- 2. the plastered tower: 3 storeys (convex frusta with today's 8 faces and taper), one tone per face
	local FACE_TONES = { 1, 0.975, 0.985, 0.96, 0.95, 0.99, 0.97, 0.98 }
	local storeys = { { 4.9, 16.5, 0.93 }, { 16.5, 31.0, 0.965 }, { 31.0, 44.9, 1.0 } }
	for _, st in ipairs(storeys) do
		local planes = { { 0, -1, 0, -st[1] }, { 0, 1, 0, st[2] } }
		for k = 0, 7 do
			local a = rad(45 * k)
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			local n = (d + Vector3.yAxis * WM_SLOPE).Unit
			table.insert(planes, { n.X, n.Y, n.Z, n:Dot(d * wmApothem(20) + Vector3.new(0, 20, 0)), scaled(PLASTER, st[3] * FACE_TONES[k + 1]) })
		end
		local r = wmApothem(st[1]) / math.cos(math.pi / 8) + 0.05
		table.insert(tower, convexSolid(Vector3.new(-r, st[1], -r), Vector3.new(r, st[2], r), CFrame.identity, PLASTER, planes))
	end
	merge(m, "Tower", tower, { collide = true, fidelity = Enum.CollisionFidelity.Hull })

	-- 3. the timber frame: corner posts, girts (sill / 2 floors / top plate), braces, corbels
	for k = 0, 7 do
		local c = rad(22.5 + 45 * k)
		local dir = Vector3.new(math.cos(c), 0, math.sin(c))
		local function corner(y: number): Vector3
			return dir * (wmApothem(y) / math.cos(math.pi / 8) + 0.12) + Vector3.new(0, y, 0)
		end
		table.insert(wood, beamBetween(corner(5.9), corner(44.9), 0.8, 0.8, dir, graded(WOOD, 25, H, 1)))
		-- corbel under the eave
		table.insert(wood, beamBetween(corner(42.4), dir * 10.0 + Vector3.new(0, 44.75, 0), 0.5, 0.5, dir, WOOD))
	end
	local girts = { { 6.45, 0.9 }, { 16.5, 0.9 }, { 31.0, 0.9 }, { 44.4, 1.0 } }
	for gi, g in ipairs(girts) do
		for k = 0, 7 do
			local w = 2 * wmApothem(g[1]) * tan8 + 0.3
			local f = wmFace(k, g[1])
			local col = graded(WOOD, g[1], H, TONES[(k + gi) % 3 + 1])
			if k == 6 and gi == 1 then
				-- the sill stops at the door frame
				local seg = w / 2 - 3.9
				for _, sx in ipairs({ -1, 1 }) do
					table.insert(wood, timber(Vector3.new(seg, g[2], 0.5), f * CFrame.new(sx * (3.9 + seg / 2), 0, -0.25), col))
				end
			else
				table.insert(wood, timber(Vector3.new(w, g[2], 0.5), f * CFrame.new(0, 0, -0.25), col))
			end
		end
	end
	-- braces between the girts (face, lower girt, upper girt, direction)
	local braces = {
		{ 1, 1, 2, 1 }, { 3, 1, 2, -1 }, { 5, 1, 2, 1 }, { 7, 1, 2, -1 },
		{ 1, 2, 3, -1 }, { 2, 2, 3, 1 }, { 3, 2, 3, 1 }, { 5, 2, 3, -1 }, { 7, 2, 3, 1 },
		{ 0, 3, 4, 1 }, { 2, 3, 4, -1 }, { 4, 3, 4, 1 },
	}
	for _, b in ipairs(braces) do
		local ya, yb = girts[b[2]][1] + girts[b[2]][2] / 2, girts[b[3]][1] - girts[b[3]][2] / 2
		local wa, wb = wmApothem(ya) * tan8 - 0.55, wmApothem(yb) * tan8 - 0.55
		local pa = wmFace(b[1], ya) * Vector3.new(-b[4] * wa, 0, -0.2)
		local pb = wmFace(b[1], yb) * Vector3.new(b[4] * wb, 0, -0.2)
		local out = -wmFace(b[1], (ya + yb) / 2).ZVector
		table.insert(wood, beamBetween(pa, pb, 0.65, 0.42, out, graded(WOOD, (ya + yb) / 2, H, 0.93)))
	end

	-- 4. the door (front face): planks over a dark backing, a timber frame, strap hinges, a ring pull
	do
		local f = wmFace(6, 10.05)
		table.insert(wood, piece("Part", Vector3.new(6.0, 8.1, 0.24), f * CFrame.new(0, 0, -0.1), rgb(60, 34, 22)))
		local prev = nil
		for i = -2, 2 do
			local ti = toneIndex(rng, prev)
			prev = ti
			table.insert(wood, chamfered(Vector3.new(1.12, 8.1, 0.36), f * CFrame.new(i * 1.2, 0, -0.3), scaled(WOOD_MID, TONES[ti]), { "vertical" }, 0.08))
		end
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(wood, timber(Vector3.new(0.9, 9.0, 0.8), f * CFrame.new(sx * 3.45, 0.45, -0.4), WOOD))
		end
		table.insert(wood, timber(Vector3.new(7.8, 0.9, 0.85), f * CFrame.new(0, 4.5, -0.42), WOOD))
		for _, y in ipairs({ -2.6, 2.6 }) do
			table.insert(iron, piece("Part", Vector3.new(4.4, 0.36, 0.1), f * CFrame.new(-0.8, y, -0.52), IRON))
			table.insert(iron, piece("Part", Vector3.new(0.34, 0.9, 0.34), f * CFrame.new(-3.0, y, -0.52), IRON))
			for _, x in ipairs({ -2.4, -0.9, 0.6 }) do
				rivet(iron, (f * CFrame.new(x, y, -0.58)).Position, 0.16)
			end
		end
		table.insert(iron, piece("Part", Vector3.new(0.5, 0.5, 0.08), f * CFrame.new(2.2, 0, -0.52), IRON))
		for q = 0, 3 do
			local a = rad(45 + 90 * q)
			table.insert(iron, piece("Part", Vector3.new(0.62, 0.1, 0.1), f * CFrame.new(2.2 + math.cos(a) * 0.32, -0.1 + math.sin(a) * 0.32, -0.6) * CFrame.Angles(0, 0, a + rad(90)), IRON))
		end
	end

	-- 5. the 3 windows: glass, frame, cross bars, sill; the front one with an open shutter
	local function window(k: number, y: number, shutter: boolean)
		local f = wmFace(k, y)
		table.insert(glass, piece("Part", Vector3.new(2.7, 3.3, 0.2), f * CFrame.new(0, 0, -0.04), GLASS))
		for _, sy in ipairs({ -1, 1 }) do
			table.insert(wood, timber(Vector3.new(3.6, 0.45, 0.5), f * CFrame.new(0, sy * 1.85, -0.25), WOOD))
			table.insert(wood, timber(Vector3.new(0.45, 3.25, 0.5), f * CFrame.new(sy * 1.575, 0, -0.25), WOOD))
		end
		table.insert(wood, piece("Part", Vector3.new(0.16, 3.3, 0.24), f * CFrame.new(0, 0, -0.17), WOOD))
		table.insert(wood, piece("Part", Vector3.new(2.7, 0.16, 0.24), f * CFrame.new(0, 0.1, -0.17), WOOD))
		table.insert(wood, chamfered(Vector3.new(4.1, 0.32, 0.85), f * CFrame.new(0, -2.22, -0.42), WOOD_MID, { "topFrontBack", "topSides" }, 0.1))
		if shutter then
			-- hinged on the left of the frame, swung 110 degrees open: 3 planks, 2 battens, a brace, 2 hinges
			local hinge = f * CFrame.new(-1.85, 0, -0.55) * CFrame.Angles(0, rad(-70), 0)
			local prev = nil
			for i = 0, 2 do
				local ti = toneIndex(rng, prev)
				prev = ti
				table.insert(wood, chamfered(Vector3.new(0.98, 3.6, 0.2), hinge * CFrame.new(-0.52 - i * 1.0, 0, 0), scaled(WOOD_MID, TONES[ti]), { "vertical" }, 0.05))
			end
			for _, sy in ipairs({ -1.2, 1.2 }) do
				table.insert(wood, timber(Vector3.new(2.9, 0.34, 0.14), hinge * CFrame.new(-1.52, sy, -0.16), WOOD))
				table.insert(iron, piece("Part", Vector3.new(1.4, 0.2, 0.06), hinge * CFrame.new(-0.62, sy, -0.26), IRON))
				table.insert(iron, piece("Part", Vector3.new(0.22, 0.5, 0.22), hinge * CFrame.new(0, sy, -0.05), IRON))
			end
			local a, b = hinge * Vector3.new(-0.35, -1.0, -0.16), hinge * Vector3.new(-2.7, 1.0, -0.16)
			table.insert(wood, beamBetween(a, b, 0.3, 0.12, -hinge.ZVector, WOOD))
		end
	end
	window(6, 26, true)
	window(0, 20, false)
	window(4, 20, false)

	-- 6. the roof: an octagonal pyramid (eave apothem 9.88 at y 44.9, apex y 61.3), rows of individual shingles on the
	-- 8 faces (cut at the hips), hip caps, a valance under the eave, the finial
	local YB, YA, RB = 44.9, 61.3, 9.88
	do
		local planes = { { 0, -1, 0, -YB, scaled(WOOD, 0.8) } }
		for k = 0, 7 do
			local a = rad(45 * k)
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			local n = (d * (YA - YB) / RB + Vector3.yAxis).Unit
			table.insert(planes, { n.X, n.Y, n.Z, n:Dot(Vector3.new(0, YA, 0)), scaled(RED, 0.72) })
		end
		local r = RB / math.cos(math.pi / 8) + 0.05
		table.insert(roof, convexSolid(Vector3.new(-r, YB, -r), Vector3.new(r, YA, r), CFrame.identity, scaled(RED, 0.72), planes))
	end
	local slant = math.sqrt((YA - YB) ^ 2 + RB ^ 2)
	local prev = nil
	for k = 0, 7 do
		local a = rad(45 * k)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local t = Vector3.new(-math.sin(a), 0, math.cos(a))
		local eave = d * RB + Vector3.new(0, YB, 0)
		local up = (Vector3.new(0, YA, 0) - eave).Unit
		local n = up:Cross(t).Unit -- outward
		local frame = CFrame.fromMatrix(Vector3.zero, t, n)
		local tilt = CFrame.Angles(math.atan2(0.08, 1.6), 0, 0)
		local rows = math.ceil(slant / 1.3)
		for row = 0, rows - 1 do
			local v0 = row * 1.3 - 0.15
			local len = math.min(1.6, slant - 0.4 - v0)
			if len < 0.35 then
				continue
			end
			local hw = RB * tan8 * (1 - (v0 + len * 0.5) / slant) + 0.05
			local x = -hw - (if row % 2 == 1 then 0.75 else 0)
			while x < hw - 0.05 do
				local x0, x1 = math.max(x, -hw), math.min(x + 1.5, hw)
				if x1 - x0 > 0.3 then
					local ti = toneIndex(rng, prev)
					prev = ti
					local pos = eave + t * ((x0 + x1) / 2) + up * (v0 + len / 2) + n * 0.1
					table.insert(roof, piece("Part", Vector3.new(x1 - x0, 0.1, len), CFrame.new(pos) * frame * tilt, scaled(RED, ({ 1, 0.93, 0.86 })[ti] * (0.9 + 0.1 * smoothstep(row / rows)))))
				end
				x += 1.56
			end
		end
		-- the hip cap over the corner (between face k and face k+1) and the valance board under the eave
		local c = rad(22.5 + 45 * k)
		local cd = Vector3.new(math.cos(c), 0, math.sin(c))
		local foot = cd * (RB / math.cos(math.pi / 8)) + Vector3.new(0, YB + 0.05, 0)
		local top = Vector3.new(0, YA - 0.3, 0)
		local hipUp = (top - foot).Unit
		local hipOut = (cd - hipUp * cd:Dot(hipUp)).Unit
		table.insert(roof, piece("Part", Vector3.new(0.62, (top - foot).Magnitude, 0.3), CFrame.fromMatrix((foot + top) / 2 + hipOut * 0.2, hipOut:Cross(hipUp), hipUp), scaled(RED, 0.62)))
		local vf = CFrame.fromMatrix(d * (RB - 0.2) + Vector3.new(0, YB - 0.3, 0), t, Vector3.yAxis)
		table.insert(wood, timber(Vector3.new(2 * (RB - 0.2) * tan8 + 0.32, 0.62, 0.3), vf, WOOD))
	end
	-- the finial: an iron collar, a gold ball and a spike
	table.insert(roof, octagon(1.3, 0.5, CFrame.new(0, YA - 0.45, 0), IRON))
	table.insert(roof, chamfered(Vector3.new(1.35, 1.35, 1.35), CFrame.new(0, YA + 0.55, 0), P.Gold, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.4))
	table.insert(roof, octagon(0.22, 1.1, CFrame.new(0, YA + 1.6, 0), P.Gold))
	merge(m, "Roof", roof, { collide = true, fidelity = Enum.CollisionFidelity.Hull })

	-- 7. the sails (static): bearing frame on the tower, the axle, a toothed brake wheel, the hub, 4 stocks with
	-- lattice frames and cloth panels
	local HUB = Vector3.new(0, 42, 0)
	do
		local f = wmFace(6, 42)
		for _, s in ipairs({ { 0, 1.45, 3.4, 0.5 }, { 0, -1.45, 3.4, 0.5 }, { 1.45, 0, 0.5, 2.4 }, { -1.45, 0, 0.5, 2.4 } }) do
			table.insert(wood, timber(Vector3.new(s[3], s[4], 0.6), f * CFrame.new(s[1], s[2], -0.3), WOOD))
		end
	end
	local alongZ = CFrame.Angles(rad(90), 0, 0)
	table.insert(sails, octagon(2.2, 4.4, CFrame.new(0, 42, -8.3) * alongZ, WOOD))
	for _, z in ipairs({ -7.6, -9.8 }) do
		table.insert(sails, octagon(2.45, 0.3, CFrame.new(0, 42, z) * alongZ, IRON))
	end
	-- brake wheel: a 16-sided wooden wheel, an iron tyre, 16 cogs
	table.insert(sails, prism16(4.3, 0.5, CFrame.new(0, 42, -9.0) * alongZ, WOOD_MID))
	table.insert(sails, prism16(4.55, 0.34, CFrame.new(0, 42, -9.0) * alongZ, IRON))
	for q = 0, 15 do
		local a = q * math.pi / 8
		local dir = Vector3.new(math.cos(a), math.sin(a), 0)
		table.insert(sails, piece("Part", Vector3.new(0.42, 0.42, 0.5), CFrame.new(HUB + dir * 2.45 + Vector3.new(0, 0, -9.0)) * CFrame.Angles(0, 0, a), WOOD))
	end
	-- the hub: a 16-sided drum with 2 iron bands, today's gold cap and a bolt
	table.insert(sails, prism16(3.4, 1.6, CFrame.new(0, 42, -10.9) * alongZ, WOOD))
	for _, z in ipairs({ -10.35, -11.45 }) do
		table.insert(sails, prism16(3.6, 0.22, CFrame.new(0, 42, z) * alongZ, IRON))
	end
	table.insert(sails, prism16(1.6, 0.9, CFrame.new(0, 42, -12.0) * alongZ, P.Gold))
	table.insert(sails, octagon(0.6, 0.4, CFrame.new(0, 42, -12.6) * alongZ, P.Gold))
	-- 4 stocks (today's angles), each with its sail on the trailing side: a rail, 8 bars, 7 cloth panels
	for q = 0, 3 do
		local arm = CFrame.new(0, 42, -10.9) * CFrame.Angles(0, 0, rad(20 + 90 * q))
		table.insert(sails, timber(Vector3.new(1.0, 26.6, 0.8), arm * CFrame.new(0, 13.5, 0), graded(WOOD, 42, H, TONES[q % 3 + 1]), 0.12))
		table.insert(sails, timber(Vector3.new(0.5, 19.2, 0.5), arm * CFrame.new(6.0, 16.5, 0.1), WOOD, 0.08))
		for b = 0, 7 do
			table.insert(sails, timber(Vector3.new(6.3, 0.36, 0.42), arm * CFrame.new(3.1, 7.2 + b * 2.66, 0.1), WOOD_MID, 0.06))
		end
		for b = 0, 6 do
			local tone = if b % 2 == 0 then 1 else 0.95
			table.insert(sails, piece("Part", Vector3.new(5.6, 2.3, 0.12), arm * CFrame.new(3.15, 8.53 + b * 2.66, 0.32 + (b % 2) * 0.04), scaled(CLOTH, tone)))
		end
	end
	merge(m, "Sails", sails, { query = true })

	-- 8. moss at the foot of the base and on the cap ring
	for i, a in ipairs({ 200, 245, 310, 20, 75, 130 }) do
		local t = rad(a + rng:NextNumber(-8, 8))
		local r = 12.55 - 0.1 * (i % 2)
		mossPad(mossList, rng, CFrame.new(math.cos(t) * r, 0, math.sin(t) * r) * CFrame.Angles(0, -t + math.pi / 2, 0), rng:NextNumber(3.0, 4.4), 0.5)
	end
	for _, a in ipairs({ 215, 330, 40, 160 }) do
		local t = rad(a + rng:NextNumber(-6, 6))
		mossPad(mossList, rng, CFrame.new(math.cos(t) * 11.6, 6.0, math.sin(t) * 11.6) * CFrame.Angles(0, -t + math.pi / 2, 0), rng:NextNumber(2.2, 3.2), 0.38)
	end
	mossPad(mossList, rng, CFrame.new(-3.4, 6.0, -13.9) * CFrame.Angles(0, 0.15, 0), 2.2, 0.32)
	merge(m, "Moss", mossList, {})

	-- glass and iron
	merge(m, "Glass", glass, { collide = true, fidelity = Enum.CollisionFidelity.Hull, material = Enum.Material.SmoothPlastic })
	merge(m, "Iron", iron, {})
	merge(m, "Timber", wood, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })

	local root = m:FindFirstChild("Base") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "windmill")
	BEVEL_SELF = false
	return m
end

---------------------------------------------------------------------
-- 15 SHIP (kit Plains.PirateShip_Wreck; Zones.Plains.Plains_2.Decor.Landmark, Tundra_2.Decor.Landmark.Ship (Variant
-- Frozen) and Abyss_2.Decor.Landmark.Hull (Variant Sunken, scale 1.12): the 3 game copies are the same shape, the
-- _Variants recolour them). Same size, place, heel and decks as today, rebuilt like the rowboat: a clinker hull of 11
-- strakes a side (planks 9-15 long, butt joints, each strake's lower edge 0.15 proud) between Agent A's curved bow and
-- stern (Blender_Exports/Props/facets/ship__bow_hull / ship__stern_hull.json, same rows so the joints line up), the
-- 2 holes on the port side opened in the planks (the dark hold behind, broken planks), 4 gun ports a side with lids,
-- a keel, bottom planks; the main deck, the fore deck and the stern deck of 1.5-wide planks (tones, butt joints; the
-- main deck top 0.4 lower than today's, level with Agent A's bow deck), bulwark stanchions, the red rail cap; the
-- forecastle (board wall, a small door, 3 steps up to its deck, railings), the stern cabin (board walls, corner posts,
-- 5 gold-framed windows with cross bars, a planked door with strap hinges, a lantern on an iron bracket, the stern
-- deck with railings), the rudder; the foremast (topmast, iron bands, crow's nest of staves, 2 yards) with Agent A's
-- torn main sail and remnant, shrouds with ratlines, lifts, the forestay to the bowsprit, the flag with its emblem;
-- the broken mainmast (splinters, collar, hanging ropes), the fallen mast and yard over the port side with Agent A's
-- fallen sail on the rail; the anchor (shank, ring, stock, crown, flukes) hanging on the port bow with its rope;
-- 3 barrels, the crate, 2 rope coils. The decks stay walkable; everything collides except ropes, sails and flag.
-- Every union is one colour (UsePartColor true; 3 tone unions per wood colour) so the _Variants recolour it by name.
-- Parts: Dark1-3, Mid1-3, Red1-3, Deck1-3, Cargo, Darker, Gold, Glass, Iron, Rope, Flag, Emblem, Sail1-3,
-- LanternGlass (24; the old one had 74).
---------------------------------------------------------------------
-- Agent A's facets (generated from the JSON faces: each rectangle a box of its thickness extruded inward, as
-- { centre, X axis, Y axis, size, union }; each triangle 3 corners already moved half its thickness inward)
PropsBatch2.SHIP_HULL = {
	{ 41.191, -2.931, 8.016, 0.9927, 0.0000, -0.1209, 0.0475, 0.9196, 0.3899, 4.556, 2.175, 0.35, "Dark1" },
	{ 45.022, -2.935, 7.052, 0.9227, 0.0000, -0.3856, 0.1432, 0.9285, 0.3427, 4.217, 2.154, 0.35, "Dark1" },
	{ 48.234, -2.941, 5.311, 0.8077, 0.0000, -0.5896, 0.1992, 0.9412, 0.2729, 3.874, 2.124, 0.35, "Dark3" },
	{ 50.611, -2.946, 3.333, 0.6946, 0.0000, -0.7194, 0.2225, 0.9509, 0.2149, 2.987, 2.103, 0.35, "Dark3" },
	{ 52.125, -2.949, 1.612, 0.5954, 0.0000, -0.8034, 0.2359, 0.9559, 0.1748, 2.212, 2.092, 0.35, "Dark1" },
	{ 52.940, -2.949, 0.381, 0.4704, 0.0000, -0.8824, 0.2587, 0.9561, 0.1379, 1.369, 2.092, 0.35, "Dark1" },
	{ 41.293, -1.041, 8.892, 0.9919, 0.0000, -0.1270, 0.0430, 0.9410, 0.3357, 4.766, 2.338, 0.35, "Dark1" },
	{ 45.312, -1.044, 7.826, 0.9157, 0.0000, -0.4019, 0.1285, 0.9475, 0.2928, 4.434, 2.322, 0.35, "Dark1" },
	{ 48.679, -1.049, 5.900, 0.7938, 0.0000, -0.6081, 0.1773, 0.9566, 0.2314, 4.109, 2.300, 0.35, "Dark1" },
	{ 51.168, -1.053, 3.714, 0.6770, 0.0000, -0.7360, 0.1988, 0.9628, 0.1829, 3.190, 2.285, 0.35, "Dark3" },
	{ 52.751, -1.054, 1.812, 0.5764, 0.0000, -0.8172, 0.2133, 0.9653, 0.1504, 2.372, 2.279, 0.35, "Dark1" },
	{ 53.603, -1.053, 0.443, 0.4526, 0.0000, -0.8917, 0.2396, 0.9632, 0.1216, 1.478, 2.284, 0.35, "Dark3" },
	{ 41.391, 0.959, 9.741, 0.9912, 0.0000, -0.1324, 0.0449, 0.9409, 0.3357, 4.976, 2.338, 0.35, "Dark2" },
	{ 45.594, 0.956, 8.576, 0.9093, 0.0000, -0.4162, 0.1331, 0.9475, 0.2907, 4.651, 2.322, 0.35, "Dark1" },
	{ 49.113, 0.951, 6.471, 0.7812, 0.0000, -0.6243, 0.1825, 0.9563, 0.2283, 4.347, 2.300, 0.35, "Dark1" },
	{ 51.714, 0.948, 4.082, 0.6612, 0.0000, -0.7502, 0.2041, 0.9623, 0.1799, 3.394, 2.286, 0.35, "Dark2" },
	{ 53.369, 0.946, 2.005, 0.5603, 0.0000, -0.8283, 0.2182, 0.9647, 0.1476, 2.531, 2.281, 0.35, "Dark2" },
	{ 54.264, 0.947, 0.504, 0.4376, 0.0000, -0.8992, 0.2437, 0.9626, 0.1186, 1.586, 2.286, 0.35, "Dark3" },
	{ 41.491, 2.959, 10.589, 0.9905, 0.0000, -0.1373, 0.0465, 0.9410, 0.3353, 5.185, 2.338, 0.35, "Dark2" },
	{ 45.876, 2.956, 9.326, 0.9031, 0.0000, -0.4295, 0.1374, 0.9474, 0.2890, 4.869, 2.322, 0.35, "Dark2" },
	{ 49.547, 2.951, 7.041, 0.7696, 0.0000, -0.6385, 0.1870, 0.9562, 0.2254, 4.586, 2.301, 0.35, "Dark2" },
	{ 52.261, 2.948, 4.450, 0.6474, 0.0000, -0.7622, 0.2085, 0.9618, 0.1771, 3.599, 2.287, 0.35, "Dark2" },
	{ 53.988, 2.947, 2.196, 0.5458, 0.0000, -0.8379, 0.2228, 0.9640, 0.1451, 2.691, 2.282, 0.35, "Dark2" },
	{ 54.926, 2.948, 0.564, 0.4242, 0.0000, -0.9056, 0.2479, 0.9618, 0.1161, 1.697, 2.287, 0.35, "Dark1" },
	{ 41.650, 4.896, 10.996, 0.9912, 0.0000, -0.1320, -0.0030, 0.9997, -0.0222, 5.386, 2.201, 0.35, "Mid1" },
	{ 46.310, 4.905, 9.623, 0.9095, 0.0000, -0.4156, 0.0120, 0.9996, 0.0263, 5.023, 2.201, 0.35, "Mid2" },
	{ 50.131, 4.918, 7.203, 0.7818, 0.0000, -0.6235, 0.0648, 0.9946, 0.0813, 4.691, 2.212, 0.35, "Mid2" },
	{ 52.910, 4.930, 4.521, 0.6620, 0.0000, -0.7495, 0.1282, 0.9853, 0.1132, 3.657, 2.233, 0.35, "Mid1" },
	{ 54.663, 4.938, 2.219, 0.5612, 0.0000, -0.8277, 0.1818, 0.9756, 0.1233, 2.721, 2.255, 0.35, "Mid2" },
	{ 55.608, 4.946, 0.563, 0.4381, 0.0000, -0.8989, 0.2351, 0.9652, 0.1146, 1.708, 2.279, 0.35, "Mid3" },
	{ 41.758, 6.889, 11.038, 0.9919, 0.0000, -0.1270, -0.0078, 0.9981, -0.0608, 5.589, 2.204, 0.35, "Mid3" },
	{ 46.617, 6.899, 9.655, 0.9154, 0.0000, -0.4026, -0.0016, 1.0000, -0.0037, 5.178, 2.200, 0.35, "Mid2" },
	{ 50.593, 6.914, 7.221, 0.7933, 0.0000, -0.6089, 0.0490, 0.9968, 0.0638, 4.799, 2.207, 0.35, "Mid1" },
	{ 53.482, 6.927, 4.527, 0.6762, 0.0000, -0.7367, 0.1154, 0.9877, 0.1059, 3.716, 2.227, 0.35, "Mid3" },
	{ 55.301, 6.937, 2.218, 0.5759, 0.0000, -0.8175, 0.1728, 0.9774, 0.1217, 2.752, 2.251, 0.35, "Mid2" },
	{ 56.281, 6.945, 0.558, 0.4519, 0.0000, -0.8921, 0.2297, 0.9663, 0.1164, 1.720, 2.277, 0.35, "Mid2" },
	{ 41.861, 8.889, 11.039, 0.9925, 0.0000, -0.1226, -0.0075, 0.9981, -0.0608, 5.792, 2.204, 0.35, "Mid2" },
	{ 46.909, 8.899, 9.656, 0.9208, 0.0000, -0.3901, -0.0025, 1.0000, -0.0060, 5.335, 2.200, 0.35, "Mid1" },
	{ 51.042, 8.913, 7.221, 0.8040, 0.0000, -0.5947, 0.0454, 0.9971, 0.0614, 4.907, 2.206, 0.35, "Mid2" },
	{ 54.044, 8.927, 4.525, 0.6897, 0.0000, -0.7241, 0.1100, 0.9884, 0.1048, 3.776, 2.226, 0.35, "Mid3" },
	{ 55.935, 8.936, 2.215, 0.5902, 0.0000, -0.8072, 0.1677, 0.9782, 0.1226, 2.784, 2.249, 0.35, "Mid2" },
	{ 56.954, 8.945, 0.553, 0.4651, 0.0000, -0.8852, 0.2256, 0.9670, 0.1185, 1.733, 2.275, 0.35, "Mid2" },
	{ 41.923, 10.482, 11.042, 0.9928, 0.0000, -0.1199, -0.0120, 0.9950, -0.0995, 5.913, 1.407, 0.35, "Red3" },
	{ 47.092, 10.492, 9.678, 0.9237, 0.0000, -0.3832, -0.0166, 0.9991, -0.0399, 5.428, 1.401, 0.35, "Red2" },
	{ 51.341, 10.507, 7.263, 0.8100, 0.0000, -0.5864, 0.0251, 0.9991, 0.0347, 4.973, 1.401, 0.35, "Red3" },
	{ 54.438, 10.521, 4.580, 0.6975, 0.0000, -0.7166, 0.0880, 0.9924, 0.0857, 3.814, 1.411, 0.35, "Red3" },
	{ 56.395, 10.532, 2.273, 0.5985, 0.0000, -0.8011, 0.1467, 0.9831, 0.1096, 2.804, 1.424, 0.35, "Red2" },
	{ 57.459, 10.541, 0.606, 0.4730, 0.0000, -0.8811, 0.2082, 0.9717, 0.1118, 1.740, 1.441, 0.35, "Red2" },
	{ 41.985, 11.683, 11.042, 0.9931, 0.0000, -0.1176, -0.0117, 0.9950, -0.0988, 6.035, 1.407, 0.35, "Mid1" },
	{ 47.267, 11.692, 9.678, 0.9265, 0.0000, -0.3763, -0.0168, 0.9990, -0.0412, 5.523, 1.401, 0.35, "Mid2" },
	{ 51.609, 11.707, 7.263, 0.8159, 0.0000, -0.5782, 0.0231, 0.9992, 0.0326, 5.040, 1.401, 0.35, "Mid1" },
	{ 54.774, 11.721, 4.579, 0.7049, 0.0000, -0.7093, 0.0854, 0.9927, 0.0848, 3.850, 1.410, 0.35, "Mid1" },
	{ 56.774, 11.732, 2.272, 0.6066, 0.0000, -0.7950, 0.1439, 0.9835, 0.1098, 2.822, 1.424, 0.35, "Mid1" },
	{ 57.862, 11.741, 0.604, 0.4810, 0.0000, -0.8767, 0.2049, 0.9723, 0.1124, 1.749, 1.440, 0.35, "Mid3" },
	{ 42.061, 13.036, 11.041, 0.9934, 0.0000, -0.1146, -0.0093, 0.9967, -0.0809, 6.187, 1.706, 0.35, "Mid1" },
	{ 47.483, 13.045, 9.671, 0.9299, 0.0000, -0.3678, -0.0107, 0.9996, -0.0270, 5.641, 1.701, 0.35, "Mid3" },
	{ 51.933, 13.059, 7.248, 0.8228, 0.0000, -0.5683, 0.0300, 0.9986, 0.0434, 5.124, 1.702, 0.35, "Mid3" },
	{ 55.174, 13.073, 4.558, 0.7140, 0.0000, -0.7001, 0.0910, 0.9915, 0.0928, 3.898, 1.715, 0.35, "Mid3" },
	{ 57.219, 13.083, 2.248, 0.6164, 0.0000, -0.7874, 0.1484, 0.9821, 0.1162, 2.847, 1.731, 0.35, "Mid1" },
	{ 58.327, 13.092, 0.580, 0.4904, 0.0000, -0.8715, 0.2094, 0.9707, 0.1178, 1.758, 1.751, 0.35, "Mid2" },
	{ 42.138, 14.536, 11.041, 0.9937, 0.0000, -0.1117, -0.0092, 0.9966, -0.0815, 6.339, 1.706, 0.35, "Mid3" },
	{ 47.701, 14.545, 9.672, 0.9329, 0.0000, -0.3601, -0.0109, 0.9995, -0.0281, 5.759, 1.701, 0.35, "Mid2" },
	{ 52.269, 14.559, 7.249, 0.8294, 0.0000, -0.5586, 0.0281, 0.9987, 0.0418, 5.207, 1.702, 0.35, "Mid1" },
	{ 55.594, 14.572, 4.558, 0.7228, 0.0000, -0.6911, 0.0876, 0.9919, 0.0916, 3.946, 1.714, 0.35, "Mid1" },
	{ 57.693, 14.582, 2.246, 0.6260, 0.0000, -0.7798, 0.1446, 0.9827, 0.1161, 2.874, 1.730, 0.35, "Mid1" },
	{ 58.831, 14.592, 0.576, 0.5000, 0.0000, -0.8660, 0.2057, 0.9714, 0.1188, 1.768, 1.750, 0.35, "Mid2" },
	{ 48.608, 12.000, 0.750, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, -1.0000, 19.217, 1.500, 0.80, "Deck1" },
	{ 48.108, 12.000, 2.250, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, -1.0000, 18.217, 1.500, 0.80, "Deck1" },
	{ 47.498, 12.000, 3.750, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, -1.0000, 16.995, 1.500, 0.80, "Deck2" },
	{ 46.776, 12.000, 5.250, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, -1.0000, 15.551, 1.500, 0.80, "Deck3" },
	{ 45.917, 12.000, 6.750, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, -1.0000, 13.834, 1.500, 0.80, "Deck3" },
	{ 44.861, 12.000, 8.250, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, -1.0000, 11.721, 1.500, 0.80, "Deck2" },
	{ 43.451, 12.000, 9.750, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, -1.0000, 8.901, 1.500, 0.80, "Deck2" },
	{ 41.530, 12.000, 11.000, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, -1.0000, 5.060, 1.000, 0.80, "Deck3" },
	{ 45.784, -3.825, 0.800, 1.0000, 0.0000, 0.0000, -0.0000, 0.0000, 1.0000, 13.568, 1.600, 0.35, "Dark1" },
	{ 45.169, -3.825, 2.400, 1.0000, 0.0000, 0.0000, -0.0000, 0.0000, 1.0000, 12.339, 1.600, 0.35, "Dark1" },
	{ 44.367, -3.825, 4.000, 1.0000, 0.0000, 0.0000, -0.0000, 0.0000, 1.0000, 10.735, 1.600, 0.35, "Dark3" },
	{ 43.302, -3.825, 5.600, 1.0000, 0.0000, 0.0000, -0.0000, 0.0000, 1.0000, 8.605, 1.600, 0.35, "Dark3" },
	{ 41.636, -3.825, 7.200, 1.0000, 0.0000, 0.0000, -0.0000, 0.0000, 1.0000, 5.271, 1.600, 0.35, "Dark2" },
	{ 42.289, 15.750, 11.130, 0.9937, 0.0000, -0.1118, -0.1118, 0.0000, -0.9937, 6.618, 1.499, 0.70, "Red1" },
	{ 47.755, 15.750, 9.811, 0.9330, 0.0000, -0.3600, -0.3600, 0.0000, -0.9330, 6.320, 1.500, 0.70, "Red1" },
	{ 52.390, 15.750, 7.430, 0.8293, 0.0000, -0.5587, -0.5587, 0.0000, -0.8293, 5.768, 1.500, 0.70, "Red1" },
	{ 55.789, 15.750, 4.761, 0.7228, 0.0000, -0.6911, -0.6911, 0.0000, -0.7228, 4.505, 1.499, 0.70, "Red1" },
	{ 57.952, 15.750, 2.454, 0.6258, 0.0000, -0.7800, -0.7800, 0.0000, -0.6258, 3.432, 1.500, 0.70, "Red1" },
	{ 59.163, 15.750, 0.757, 0.4999, 0.0000, -0.8661, -0.8661, 0.0000, -0.4999, 2.348, 1.501, 0.70, "Red1" },
	{ 41.191, -2.931, -8.016, 0.9927, 0.0000, 0.1209, -0.0475, -0.9196, 0.3899, 4.556, 2.175, 0.35, "Dark1" },
	{ 45.022, -2.935, -7.052, 0.9226, 0.0000, 0.3857, -0.1433, -0.9285, 0.3427, 4.218, 2.154, 0.35, "Dark1" },
	{ 48.234, -2.941, -5.311, 0.8079, 0.0000, 0.5893, -0.1991, -0.9412, 0.2729, 3.874, 2.124, 0.35, "Dark3" },
	{ 50.611, -2.946, -3.333, 0.6946, 0.0000, 0.7194, -0.2225, -0.9509, 0.2149, 2.987, 2.103, 0.35, "Dark3" },
	{ 52.125, -2.949, -1.612, 0.5955, 0.0000, 0.8033, -0.2358, -0.9559, 0.1748, 2.213, 2.092, 0.35, "Dark1" },
	{ 52.940, -2.949, -0.381, 0.4699, 0.0000, 0.8827, -0.2588, -0.9561, 0.1378, 1.368, 2.092, 0.35, "Dark1" },
	{ 41.293, -1.041, -8.892, 0.9919, 0.0000, 0.1270, -0.0430, -0.9410, 0.3357, 4.766, 2.338, 0.35, "Dark1" },
	{ 45.312, -1.044, -7.826, 0.9157, 0.0000, 0.4019, -0.1285, -0.9475, 0.2928, 4.434, 2.322, 0.35, "Dark1" },
	{ 48.679, -1.049, -5.900, 0.7939, 0.0000, 0.6080, -0.1772, -0.9566, 0.2314, 4.110, 2.300, 0.35, "Dark1" },
	{ 51.168, -1.053, -3.714, 0.6770, 0.0000, 0.7360, -0.1988, -0.9628, 0.1829, 3.190, 2.285, 0.35, "Dark3" },
	{ 52.751, -1.054, -1.812, 0.5769, 0.0000, 0.8168, -0.2132, -0.9653, 0.1506, 2.371, 2.279, 0.35, "Dark1" },
	{ 53.603, -1.053, -0.443, 0.4529, 0.0000, 0.8916, -0.2395, -0.9632, 0.1217, 1.477, 2.284, 0.35, "Dark3" },
	{ 41.391, 0.959, -9.741, 0.9912, 0.0000, 0.1323, -0.0448, -0.9409, 0.3357, 4.975, 2.338, 0.35, "Dark2" },
	{ 45.594, 0.956, -8.576, 0.9092, 0.0000, 0.4164, -0.1331, -0.9475, 0.2907, 4.651, 2.322, 0.35, "Dark1" },
	{ 49.113, 0.951, -6.471, 0.7812, 0.0000, 0.6243, -0.1825, -0.9563, 0.2283, 4.347, 2.300, 0.35, "Dark1" },
	{ 51.714, 0.948, -4.082, 0.6612, 0.0000, 0.7502, -0.2041, -0.9623, 0.1799, 3.394, 2.286, 0.35, "Dark2" },
	{ 53.369, 0.946, -2.005, 0.5602, 0.0000, 0.8284, -0.2182, -0.9647, 0.1476, 2.531, 2.281, 0.35, "Dark2" },
	{ 54.264, 0.947, -0.504, 0.4374, 0.0000, 0.8993, -0.2437, -0.9626, 0.1185, 1.587, 2.286, 0.35, "Dark3" },
	{ 41.491, 2.959, -10.589, 0.9905, 0.0000, 0.1373, -0.0465, -0.9410, 0.3353, 5.184, 2.338, 0.35, "Dark2" },
	{ 45.876, 2.956, -9.326, 0.9032, 0.0000, 0.4293, -0.1374, -0.9474, 0.2890, 4.868, 2.322, 0.35, "Dark2" },
	{ 49.547, 2.951, -7.041, 0.7695, 0.0000, 0.6387, -0.1870, -0.9562, 0.2254, 4.586, 2.301, 0.35, "Dark2" },
	{ 52.261, 2.948, -4.450, 0.6472, 0.0000, 0.7623, -0.2085, -0.9618, 0.1771, 3.598, 2.287, 0.35, "Dark2" },
	{ 53.988, 2.947, -2.196, 0.5456, 0.0000, 0.8381, -0.2229, -0.9640, 0.1451, 2.691, 2.282, 0.35, "Dark2" },
	{ 54.926, 2.948, -0.564, 0.4244, 0.0000, 0.9055, -0.2479, -0.9618, 0.1162, 1.696, 2.287, 0.35, "Dark1" },
	{ 41.650, 4.896, -10.996, 0.9913, 0.0000, 0.1320, 0.0030, -0.9997, -0.0222, 5.387, 2.201, 0.35, "Mid1" },
	{ 46.310, 4.905, -9.623, 0.9095, 0.0000, 0.4156, -0.0120, -0.9996, 0.0263, 5.023, 2.201, 0.35, "Mid2" },
	{ 50.131, 4.918, -7.203, 0.7818, 0.0000, 0.6235, -0.0648, -0.9946, 0.0813, 4.691, 2.212, 0.35, "Mid2" },
	{ 52.910, 4.930, -4.521, 0.6620, 0.0000, 0.7495, -0.1282, -0.9853, 0.1132, 3.657, 2.233, 0.35, "Mid1" },
	{ 54.663, 4.938, -2.219, 0.5612, 0.0000, 0.8277, -0.1818, -0.9756, 0.1233, 2.721, 2.255, 0.35, "Mid2" },
	{ 55.608, 4.946, -0.563, 0.4385, 0.0000, 0.8987, -0.2351, -0.9652, 0.1147, 1.708, 2.279, 0.35, "Mid3" },
	{ 41.758, 6.889, -11.038, 0.9919, 0.0000, 0.1272, 0.0078, -0.9981, -0.0608, 5.589, 2.204, 0.35, "Mid3" },
	{ 46.617, 6.899, -9.655, 0.9154, 0.0000, 0.4025, 0.0016, -1.0000, -0.0037, 5.178, 2.200, 0.35, "Mid2" },
	{ 50.593, 6.914, -7.221, 0.7934, 0.0000, 0.6087, -0.0490, -0.9968, 0.0638, 4.798, 2.207, 0.35, "Mid1" },
	{ 53.482, 6.927, -4.527, 0.6763, 0.0000, 0.7366, -0.1154, -0.9877, 0.1059, 3.716, 2.227, 0.35, "Mid3" },
	{ 55.301, 6.937, -2.218, 0.5759, 0.0000, 0.8175, -0.1728, -0.9774, 0.1217, 2.752, 2.251, 0.35, "Mid2" },
	{ 56.281, 6.945, -0.558, 0.4516, 0.0000, 0.8922, -0.2298, -0.9663, 0.1163, 1.720, 2.277, 0.35, "Mid2" },
	{ 41.861, 8.889, -11.039, 0.9925, 0.0000, 0.1226, 0.0075, -0.9981, -0.0608, 5.792, 2.204, 0.35, "Mid2" },
	{ 46.909, 8.899, -9.656, 0.9207, 0.0000, 0.3903, 0.0025, -1.0000, -0.0060, 5.335, 2.200, 0.35, "Mid1" },
	{ 51.042, 8.913, -7.221, 0.8040, 0.0000, 0.5946, -0.0454, -0.9971, 0.0614, 4.908, 2.206, 0.35, "Mid2" },
	{ 54.044, 8.927, -4.525, 0.6897, 0.0000, 0.7241, -0.1100, -0.9884, 0.1048, 3.777, 2.226, 0.35, "Mid3" },
	{ 55.935, 8.936, -2.216, 0.5900, 0.0000, 0.8074, -0.1677, -0.9782, 0.1226, 2.783, 2.249, 0.35, "Mid2" },
	{ 56.954, 8.945, -0.553, 0.4651, 0.0000, 0.8852, -0.2256, -0.9670, 0.1185, 1.733, 2.275, 0.35, "Mid2" },
	{ 41.923, 10.482, -11.042, 0.9928, 0.0000, 0.1201, 0.0120, -0.9950, -0.0995, 5.913, 1.407, 0.35, "Red3" },
	{ 47.092, 10.492, -9.678, 0.9237, 0.0000, 0.3831, 0.0166, -0.9991, -0.0399, 5.429, 1.401, 0.35, "Red2" },
	{ 51.341, 10.507, -7.263, 0.8101, 0.0000, 0.5863, -0.0251, -0.9991, 0.0347, 4.974, 1.401, 0.35, "Red3" },
	{ 54.438, 10.521, -4.580, 0.6973, 0.0000, 0.7167, -0.0880, -0.9924, 0.0856, 3.813, 1.411, 0.35, "Red3" },
	{ 56.395, 10.532, -2.273, 0.5983, 0.0000, 0.8013, -0.1467, -0.9831, 0.1096, 2.803, 1.424, 0.35, "Red2" },
	{ 57.459, 10.541, -0.605, 0.4734, 0.0000, 0.8808, -0.2081, -0.9717, 0.1119, 1.740, 1.441, 0.35, "Red2" },
	{ 41.985, 11.683, -11.042, 0.9931, 0.0000, 0.1175, 0.0117, -0.9950, -0.0988, 6.035, 1.407, 0.35, "Mid1" },
	{ 47.267, 11.692, -9.678, 0.9265, 0.0000, 0.3763, 0.0168, -0.9990, -0.0412, 5.523, 1.401, 0.35, "Mid2" },
	{ 51.609, 11.707, -7.263, 0.8158, 0.0000, 0.5783, -0.0231, -0.9992, 0.0326, 5.039, 1.401, 0.35, "Mid1" },
	{ 54.774, 11.721, -4.579, 0.7049, 0.0000, 0.7093, -0.0854, -0.9927, 0.0848, 3.850, 1.410, 0.35, "Mid1" },
	{ 56.774, 11.732, -2.272, 0.6066, 0.0000, 0.7950, -0.1439, -0.9835, 0.1098, 2.822, 1.424, 0.35, "Mid1" },
	{ 57.862, 11.741, -0.604, 0.4810, 0.0000, 0.8767, -0.2049, -0.9723, 0.1124, 1.749, 1.440, 0.35, "Mid3" },
	{ 42.061, 13.036, -11.041, 0.9934, 0.0000, 0.1146, 0.0093, -0.9967, -0.0809, 6.187, 1.706, 0.35, "Mid1" },
	{ 47.483, 13.045, -9.671, 0.9298, 0.0000, 0.3680, 0.0107, -0.9996, -0.0270, 5.642, 1.701, 0.35, "Mid3" },
	{ 51.933, 13.059, -7.248, 0.8227, 0.0000, 0.5684, -0.0300, -0.9986, 0.0434, 5.123, 1.702, 0.35, "Mid3" },
	{ 55.174, 13.073, -4.558, 0.7140, 0.0000, 0.7001, -0.0910, -0.9915, 0.0928, 3.898, 1.715, 0.35, "Mid3" },
	{ 57.219, 13.083, -2.248, 0.6162, 0.0000, 0.7876, -0.1484, -0.9821, 0.1161, 2.848, 1.731, 0.35, "Mid1" },
	{ 58.327, 13.092, -0.580, 0.4908, 0.0000, 0.8713, -0.2094, -0.9707, 0.1179, 1.758, 1.751, 0.35, "Mid2" },
	{ 42.138, 14.536, -11.041, 0.9937, 0.0000, 0.1119, 0.0092, -0.9966, -0.0815, 6.339, 1.706, 0.35, "Mid3" },
	{ 47.701, 14.545, -9.672, 0.9329, 0.0000, 0.3600, 0.0109, -0.9995, -0.0281, 5.760, 1.701, 0.35, "Mid2" },
	{ 52.269, 14.559, -7.249, 0.8295, 0.0000, 0.5585, -0.0281, -0.9987, 0.0418, 5.208, 1.702, 0.35, "Mid1" },
	{ 55.594, 14.572, -4.558, 0.7228, 0.0000, 0.6911, -0.0876, -0.9919, 0.0916, 3.946, 1.714, 0.35, "Mid1" },
	{ 57.693, 14.582, -2.246, 0.6258, 0.0000, 0.7800, -0.1446, -0.9827, 0.1160, 2.873, 1.730, 0.35, "Mid1" },
	{ 58.831, 14.592, -0.576, 0.5000, 0.0000, 0.8660, -0.2057, -0.9714, 0.1188, 1.768, 1.750, 0.35, "Mid2" },
	{ 48.608, 12.000, -0.750, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, -1.0000, 19.217, 1.500, 0.80, "Deck1" },
	{ 48.108, 12.000, -2.250, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, -1.0000, 18.217, 1.500, 0.80, "Deck1" },
	{ 47.498, 12.000, -3.750, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, -1.0000, 16.995, 1.500, 0.80, "Deck2" },
	{ 46.776, 12.000, -5.250, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, -1.0000, 15.551, 1.500, 0.80, "Deck3" },
	{ 45.917, 12.000, -6.750, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, -1.0000, 13.834, 1.500, 0.80, "Deck3" },
	{ 44.861, 12.000, -8.250, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, -1.0000, 11.721, 1.500, 0.80, "Deck2" },
	{ 43.451, 12.000, -9.750, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, -1.0000, 8.901, 1.500, 0.80, "Deck2" },
	{ 41.530, 12.000, -11.000, 1.0000, 0.0000, 0.0000, 0.0000, 0.0000, -1.0000, 5.060, 1.000, 0.80, "Deck3" },
	{ 45.784, -3.825, -0.800, 1.0000, 0.0000, 0.0000, -0.0000, 0.0000, 1.0000, 13.568, 1.600, 0.35, "Dark1" },
	{ 45.169, -3.825, -2.400, 1.0000, 0.0000, 0.0000, -0.0000, 0.0000, 1.0000, 12.339, 1.600, 0.35, "Dark1" },
	{ 44.367, -3.825, -4.000, 1.0000, 0.0000, 0.0000, -0.0000, 0.0000, 1.0000, 10.735, 1.600, 0.35, "Dark3" },
	{ 43.302, -3.825, -5.600, 1.0000, 0.0000, 0.0000, -0.0000, 0.0000, 1.0000, 8.605, 1.600, 0.35, "Dark3" },
	{ 41.636, -3.825, -7.200, 1.0000, 0.0000, 0.0000, -0.0000, 0.0000, 1.0000, 5.271, 1.600, 0.35, "Dark2" },
	{ 42.289, 15.750, -11.130, 0.9937, 0.0000, 0.1118, 0.1118, 0.0000, -0.9937, 6.619, 1.499, 0.70, "Red1" },
	{ 47.755, 15.750, -9.811, 0.9329, 0.0000, 0.3601, 0.3601, 0.0000, -0.9329, 6.320, 1.500, 0.70, "Red1" },
	{ 52.390, 15.750, -7.430, 0.8293, 0.0000, 0.5587, 0.5587, 0.0000, -0.8293, 5.768, 1.500, 0.70, "Red1" },
	{ 55.789, 15.750, -4.761, 0.7228, 0.0000, 0.6911, 0.6911, 0.0000, -0.7228, 4.505, 1.499, 0.70, "Red1" },
	{ 57.952, 15.750, -2.454, 0.6257, 0.0000, 0.7801, 0.7801, 0.0000, -0.6257, 3.433, 1.500, 0.70, "Red1" },
	{ 59.163, 15.750, -0.757, 0.4999, 0.0000, 0.8661, 0.8661, 0.0000, -0.4999, 2.348, 1.501, 0.70, "Red1" },
	{ 56.133, 6.247, 0.000, 0.3289, 0.9444, 0.0000, -0.0000, 0.0000, 1.0000, 21.284, 1.000, 1.20, "Dark1" },
	{ -39.113, -2.936, 8.187, -0.8862, 0.0000, -0.4634, 0.1700, -0.9303, -0.3250, 0.837, 2.150, 0.35, "Dark1" },
	{ -39.568, -2.951, 7.797, -0.5371, 0.0000, -0.8435, 0.2341, -0.9607, -0.1491, 1.423, 2.082, 0.35, "Dark1" },
	{ -39.198, -1.044, 9.057, -0.9002, 0.0000, -0.4355, 0.1396, -0.9473, -0.2885, 0.960, 2.322, 0.35, "Dark2" },
	{ -39.759, -1.056, 8.577, -0.5676, 0.0000, -0.8233, 0.2075, -0.9677, -0.1431, 1.572, 2.273, 0.35, "Dark2" },
	{ -39.269, 0.956, 9.909, -0.9103, 0.0000, -0.4140, 0.1336, -0.9465, -0.2937, 1.082, 2.324, 0.35, "Dark1" },
	{ -39.941, 0.945, 9.356, -0.5911, 0.0000, -0.8066, 0.2076, -0.9663, -0.1522, 1.722, 2.277, 0.35, "Dark3" },
	{ -39.337, 2.957, 10.762, -0.9176, 0.0000, -0.3974, 0.1290, -0.9458, -0.2979, 1.205, 2.326, 0.35, "Dark2" },
	{ -40.123, 2.946, 10.137, -0.6099, 0.0000, -0.7925, 0.2077, -0.9650, -0.1598, 1.873, 2.280, 0.35, "Dark2" },
	{ -39.557, 4.897, 11.116, -0.9327, 0.0000, -0.3608, -0.0060, -0.9999, 0.0154, 1.317, 2.200, 0.35, "Mid2" },
	{ -40.502, 4.908, 10.274, -0.6528, 0.0000, -0.7575, 0.0356, -0.9989, -0.0307, 1.948, 2.202, 0.35, "Mid2" },
	{ -39.637, 6.890, 11.156, -0.9441, 0.0000, -0.3296, -0.0179, -0.9985, 0.0514, 1.429, 2.203, 0.35, "Mid2" },
	{ -40.713, 6.903, 10.287, -0.6907, 0.0000, -0.7232, 0.0130, -0.9998, -0.0124, 2.030, 2.200, 0.35, "Mid1" },
	{ -39.701, 8.890, 11.158, -0.9529, 0.0000, -0.3034, -0.0171, -0.9984, 0.0536, 1.543, 2.203, 0.35, "Mid2" },
	{ -40.903, 8.902, 10.285, -0.7235, 0.0000, -0.6904, 0.0089, -0.9999, -0.0093, 2.115, 2.200, 0.35, "Mid2" },
	{ -39.740, 10.484, 11.163, -0.9573, 0.0000, -0.2891, -0.0271, -0.9956, 0.0896, 1.612, 1.406, 0.35, "Red1" },
	{ -41.034, 10.497, 10.302, -0.7411, 0.0000, -0.6714, -0.0129, -0.9998, 0.0142, 2.167, 1.400, 0.35, "Red1" },
	{ -39.778, 11.684, 11.164, -0.9611, 0.0000, -0.2761, -0.0260, -0.9956, 0.0904, 1.680, 1.406, 0.35, "Mid3" },
	{ -41.146, 11.696, 10.301, -0.7574, 0.0000, -0.6529, -0.0142, -0.9998, 0.0165, 2.221, 1.400, 0.35, "Mid2" },
	{ -39.516, -3.825, 0.800, -1.0000, 0.0000, 0.0000, -0.0000, 0.0000, -1.0000, 1.032, 1.600, 0.35, "Dark2" },
	{ -39.516, -3.825, 2.400, -1.0000, 0.0000, 0.0000, -0.0000, 0.0000, -1.0000, 1.032, 1.600, 0.35, "Dark2" },
	{ -39.516, -3.825, 4.000, -1.0000, 0.0000, 0.0000, -0.0000, 0.0000, -1.0000, 1.032, 1.600, 0.35, "Dark1" },
	{ -39.516, -3.825, 5.600, -1.0000, 0.0000, 0.0000, -0.0000, 0.0000, -1.0000, 1.032, 1.600, 0.35, "Dark2" },
	{ -39.516, -3.825, 6.675, -1.0000, 0.0000, 0.0000, -0.0000, 0.0000, -1.0000, 1.032, 0.550, 0.35, "Dark3" },
	{ -39.113, -2.936, -8.187, -0.8864, 0.0000, 0.4629, -0.1698, 0.9303, -0.3251, 0.838, 2.150, 0.35, "Dark1" },
	{ -39.568, -2.951, -7.797, -0.5372, 0.0000, 0.8434, -0.2341, 0.9607, -0.1491, 1.424, 2.082, 0.35, "Dark1" },
	{ -39.198, -1.044, -9.057, -0.9002, 0.0000, 0.4355, -0.1396, 0.9473, -0.2885, 0.960, 2.322, 0.35, "Dark2" },
	{ -39.759, -1.056, -8.577, -0.5676, 0.0000, 0.8233, -0.2075, 0.9677, -0.1431, 1.572, 2.273, 0.35, "Dark2" },
	{ -39.269, 0.956, -9.909, -0.9104, 0.0000, 0.4137, -0.1335, 0.9465, -0.2938, 1.083, 2.324, 0.35, "Dark1" },
	{ -39.941, 0.945, -9.356, -0.5911, 0.0000, 0.8066, -0.2076, 0.9663, -0.1522, 1.722, 2.277, 0.35, "Dark3" },
	{ -39.337, 2.957, -10.762, -0.9176, 0.0000, 0.3974, -0.1290, 0.9458, -0.2979, 1.205, 2.326, 0.35, "Dark2" },
	{ -40.123, 2.946, -10.136, -0.6102, 0.0000, 0.7922, -0.2076, 0.9650, -0.1599, 1.873, 2.280, 0.35, "Dark2" },
	{ -39.557, 4.897, -11.116, -0.9327, 0.0000, 0.3608, 0.0060, 0.9999, 0.0154, 1.317, 2.200, 0.35, "Mid2" },
	{ -40.502, 4.908, -10.274, -0.6531, 0.0000, 0.7573, -0.0356, 0.9989, -0.0307, 1.949, 2.202, 0.35, "Mid2" },
	{ -39.637, 6.890, -11.156, -0.9442, 0.0000, 0.3294, 0.0179, 0.9985, 0.0514, 1.430, 2.203, 0.35, "Mid2" },
	{ -40.713, 6.903, -10.287, -0.6907, 0.0000, 0.7232, -0.0130, 0.9998, -0.0124, 2.029, 2.200, 0.35, "Mid1" },
	{ -39.701, 8.890, -11.158, -0.9531, 0.0000, 0.3026, 0.0170, 0.9984, 0.0536, 1.543, 2.203, 0.35, "Mid2" },
	{ -40.903, 8.902, -10.285, -0.7235, 0.0000, 0.6904, -0.0089, 0.9999, -0.0093, 2.113, 2.200, 0.35, "Mid2" },
	{ -39.740, 10.484, -11.163, -0.9573, 0.0000, 0.2891, 0.0271, 0.9956, 0.0896, 1.612, 1.406, 0.35, "Red1" },
	{ -41.034, 10.497, -10.302, -0.7411, 0.0000, 0.6714, 0.0129, 0.9998, 0.0142, 2.167, 1.400, 0.35, "Red1" },
	{ -39.778, 11.684, -11.164, -0.9611, 0.0000, 0.2761, 0.0260, 0.9956, 0.0904, 1.680, 1.406, 0.35, "Mid3" },
	{ -41.146, 11.696, -10.301, -0.7570, 0.0000, 0.6534, 0.0142, 0.9998, 0.0165, 2.221, 1.400, 0.35, "Mid2" },
	{ -39.516, -3.825, -0.800, -1.0000, 0.0000, 0.0000, -0.0000, 0.0000, -1.0000, 1.032, 1.600, 0.35, "Dark2" },
	{ -39.516, -3.825, -2.400, -1.0000, 0.0000, 0.0000, -0.0000, 0.0000, -1.0000, 1.032, 1.600, 0.35, "Dark2" },
	{ -39.516, -3.825, -4.000, -1.0000, 0.0000, 0.0000, -0.0000, 0.0000, -1.0000, 1.032, 1.600, 0.35, "Dark1" },
	{ -39.516, -3.825, -5.600, -1.0000, 0.0000, 0.0000, -0.0000, 0.0000, -1.0000, 1.032, 1.600, 0.35, "Dark2" },
	{ -39.516, -3.825, -6.675, -1.0000, 0.0000, 0.0000, -0.0000, 0.0000, -1.0000, 1.032, 0.550, 0.35, "Dark3" },
	{ -40.035, -2.986, 0.000, 0.0000, 0.0000, 1.0000, -0.0822, 0.9966, 0.0000, 15.488, 2.007, 0.35, "Dark1" },
	{ -40.263, -1.085, 0.000, 0.0000, 0.0000, 1.0000, -0.0856, 0.9963, 0.0000, 16.976, 2.208, 0.35, "Dark2" },
	{ -40.503, 0.915, 0.000, 0.0000, 0.0000, 1.0000, -0.0856, 0.9963, 0.0000, 18.462, 2.208, 0.35, "Dark1" },
	{ -40.743, 2.915, 0.000, 0.0000, 0.0000, 1.0000, -0.0856, 0.9963, 0.0000, 19.950, 2.208, 0.35, "Dark1" },
	{ -40.983, 4.915, 0.000, 0.0000, 0.0000, 1.0000, -0.0856, 0.9963, 0.0000, 19.950, 2.208, 0.35, "Mid2" },
	{ -41.223, 6.915, 0.000, 0.0000, 0.0000, 1.0000, -0.0856, 0.9963, 0.0000, 19.950, 2.208, 0.35, "Mid1" },
	{ -41.463, 8.915, 0.000, 0.0000, 0.0000, 1.0000, -0.0856, 0.9963, 0.0000, 19.950, 2.208, 0.35, "Mid2" },
	{ -41.655, 10.512, 0.000, 0.0000, 0.0000, 1.0000, -0.0663, 0.9978, 0.0000, 19.950, 1.403, 0.35, "Red1" },
	{ -41.799, 11.712, 0.000, 0.0000, 0.0000, 1.0000, -0.0663, 0.9978, 0.0000, 19.950, 1.403, 0.35, "Mid2" },
}
PropsBatch2.SHIP_SAILS = {
	main = { rects = {
		{ -11.904, -3.400, -0.038, 0.9920, 0.0000, -0.1259, 0.0000, -1.0000, -0.0000, 2.184, 6.800, 0.20, "Sail1" },
		{ -9.740, -4.000, -0.288, 0.9946, 0.0000, -0.1033, 0.0000, -1.0000, -0.0000, 2.178, 8.000, 0.20, "Sail2" },
		{ -7.575, -3.600, -0.488, 0.9968, 0.0000, -0.0805, 0.0000, -1.0000, -0.0000, 2.174, 7.200, 0.20, "Sail1" },
		{ -5.411, -1.300, -0.638, 0.9983, 0.0000, -0.0576, 0.0000, -1.0000, -0.0000, 2.171, 2.600, 0.20, "Sail2" },
		{ -5.411, -6.200, -0.638, 0.9983, 0.0000, -0.0576, 0.0000, -1.0000, -0.0000, 2.171, 4.400, 0.20, "Sail2" },
		{ -3.247, -3.300, -0.738, 0.9994, 0.0000, -0.0346, 0.0000, -1.0000, -0.0000, 2.167, 6.600, 0.20, "Sail1" },
		{ -1.082, -3.900, -0.788, 0.9999, 0.0000, -0.0115, 0.0000, -1.0000, -0.0000, 2.167, 7.800, 0.20, "Sail2" },
		{ 1.082, -4.300, -0.788, 0.9999, 0.0000, 0.0115, 0.0000, -1.0000, 0.0000, 2.167, 8.600, 0.20, "Sail1" },
		{ 3.247, -3.500, -0.738, 0.9994, 0.0000, 0.0346, 0.0000, -1.0000, 0.0000, 2.167, 7.000, 0.20, "Sail2" },
		{ 5.411, -1.800, -0.638, 0.9983, 0.0000, 0.0576, 0.0000, -1.0000, 0.0000, 2.171, 3.600, 0.20, "Sail1" },
		{ 5.411, -6.200, -0.638, 0.9983, 0.0000, 0.0576, 0.0000, -1.0000, 0.0000, 2.171, 2.800, 0.20, "Sail1" },
		{ 7.575, -4.100, -0.488, 0.9968, 0.0000, 0.0805, 0.0000, -1.0000, 0.0000, 2.174, 8.200, 0.20, "Sail2" },
		{ 9.740, -3.200, -0.288, 0.9946, 0.0000, 0.1033, 0.0000, -1.0000, 0.0000, 2.178, 6.400, 0.20, "Sail1" },
		{ 11.904, -3.700, -0.038, 0.9920, 0.0000, 0.1259, 0.0000, -1.0000, 0.0000, 2.184, 7.400, 0.20, "Sail2" },
	}, tris = {
		{ -12.987, -6.800, 0.099, -10.820, -6.800, -0.176, -12.120, -8.400, -0.017, 0.20, "Sail1" },
		{ -10.823, -8.000, -0.176, -8.657, -8.000, -0.401, -9.523, -9.800, -0.317, 0.20, "Sail2" },
		{ -8.659, -7.200, -0.400, -6.492, -7.200, -0.575, -8.009, -8.400, -0.458, 0.20, "Sail1" },
		{ -6.494, -8.400, -0.575, -4.327, -8.400, -0.700, -5.302, -9.800, -0.650, 0.20, "Sail2" },
		{ -4.330, -6.601, -0.700, -2.164, -6.601, -0.775, -2.814, -7.601, -0.758, 0.20, "Sail1" },
		{ -2.166, -7.800, -0.775, 0.001, -7.800, -0.800, -1.407, -9.700, -0.789, 0.20, "Sail2" },
		{ -0.001, -8.601, -0.800, 2.166, -8.601, -0.775, 1.082, -9.801, -0.794, 0.20, "Sail1" },
		{ 2.164, -7.000, -0.775, 4.330, -7.000, -0.700, 3.572, -8.300, -0.732, 0.20, "Sail2" },
		{ 4.327, -7.600, -0.700, 6.494, -7.600, -0.575, 5.194, -9.600, -0.656, 0.20, "Sail1" },
		{ 6.492, -8.200, -0.575, 8.659, -8.200, -0.400, 7.792, -9.800, -0.476, 0.20, "Sail2" },
		{ 8.657, -6.401, -0.401, 10.823, -6.401, -0.176, 9.632, -7.501, -0.306, 0.20, "Sail1" },
		{ 10.820, -7.400, -0.176, 12.987, -7.400, 0.099, 11.904, -9.200, -0.045, 0.20, "Sail2" },
	} },
	remnant = { rects = {
		{ -1.985, -1.600, -0.057, 0.9881, 0.0000, -0.1537, 0.0000, -1.0000, -0.0000, 2.024, 3.200, 0.20, "Sail1" },
		{ -1.985, -5.950, -0.057, 0.9881, 0.0000, -0.1537, 0.0000, -1.0000, -0.0000, 2.024, 3.100, 0.20, "Sail1" },
		{ 0.000, -2.350, -0.211, 1.0000, 0.0000, 0.0000, 0.0000, -1.0000, 0.0000, 2.000, 4.700, 0.20, "Sail3" },
		{ 1.985, -3.200, -0.057, 0.9881, 0.0000, 0.1537, 0.0000, -1.0000, 0.0000, 2.024, 6.400, 0.20, "Sail1" },
	}, tris = {
		{ -2.985, -7.503, 0.099, -0.985, -7.503, -0.212, -1.985, -8.803, -0.095, 0.20, "Sail1" },
		{ -1.000, -4.704, -0.211, 1.000, -4.704, -0.211, -0.400, -5.504, -0.244, 0.20, "Sail3" },
		{ 0.985, -6.402, -0.212, 2.985, -6.402, 0.099, 2.185, -8.002, -0.063, 0.20, "Sail1" },
	} },
	fallen = { rects = {
		{ -5.200, -2.301, -0.513, 1.0000, 0.0000, 0.0000, 0.0000, -0.9659, -0.2589, 2.600, 4.712, 0.20, "Sail1" },
		{ -2.600, -2.425, -0.546, 1.0000, 0.0000, 0.0000, 0.0000, -0.9659, -0.2589, 2.600, 4.967, 0.20, "Sail2" },
		{ 0.000, -2.386, -0.536, 1.0000, 0.0000, 0.0000, 0.0000, -0.9659, -0.2588, 2.600, 4.888, 0.20, "Sail1" },
		{ 2.600, -2.435, -0.549, 1.0000, 0.0000, 0.0000, 0.0000, -0.9659, -0.2588, 2.600, 4.989, 0.20, "Sail2" },
		{ 5.200, -2.317, -0.517, 1.0000, 0.0000, 0.0000, 0.0000, -0.9659, -0.2589, 2.600, 4.744, 0.20, "Sail1" },
		{ -5.200, -0.791, 1.883, 1.0000, 0.0000, 0.0000, 0.0000, 0.3419, -0.9397, 2.600, 4.080, 0.20, "Sail1" },
		{ -2.600, -0.672, 1.554, 1.0000, 0.0000, 0.0000, 0.0000, 0.3420, -0.9397, 2.600, 3.380, 0.20, "Sail2" },
		{ 0.000, -0.711, 1.663, 1.0000, 0.0000, 0.0000, 0.0000, 0.3419, -0.9397, 2.600, 3.612, 0.20, "Sail1" },
		{ 2.600, -0.819, 1.959, 1.0000, 0.0000, 0.0000, 0.0000, 0.3421, -0.9397, 2.600, 4.242, 0.20, "Sail2" },
		{ 5.200, -0.746, 1.757, 1.0000, 0.0000, 0.0000, 0.0000, 0.3420, -0.9397, 2.600, 3.813, 0.20, "Sail1" },
	}, tris = {
		{ -6.500, -4.577, -1.123, -3.900, -4.577, -1.123, -5.641, -5.429, -1.351, 0.20, "Sail1" },
		{ -1.300, -4.747, -1.168, 1.300, -4.747, -1.168, 0.069, -5.827, -1.457, 0.20, "Sail1" },
		{ 3.900, -4.608, -1.131, 6.500, -4.608, -1.131, 5.602, -5.834, -1.459, 0.20, "Sail1" },
		{ -5.391, -1.886, 4.891, -3.900, -1.489, 3.800, -6.500, -1.489, 3.800, 0.20, "Sail1" },
		{ 0.349, -1.761, 4.546, 1.300, -1.329, 3.360, -1.300, -1.329, 3.360, 0.20, "Sail1" },
		{ 5.270, -1.795, 4.638, 6.500, -1.398, 3.549, 3.900, -1.398, 3.549, 0.20, "Sail1" },
	} },
}

local SHIP_TONES = {
	Dark = { rgb(112, 62, 38), rgb(106, 59, 36), rgb(101, 56, 34) },
	Mid = { rgb(168, 98, 56), rgb(160, 93, 53), rgb(151, 88, 50) },
	Red = { rgb(212, 52, 60), rgb(201, 49, 57), rgb(191, 47, 54) },
	Deck = { rgb(214, 150, 92), rgb(203, 142, 87), rgb(193, 135, 83) },
	Sail = { rgb(232, 226, 208), rgb(245, 246, 250), rgb(220, 212, 190) },
}
local SHIP_SINGLE = {
	Cargo = rgb(214, 150, 92), Darker = rgb(96, 53, 32), Gold = rgb(255, 201, 60), Glass = rgb(95, 212, 255),
	Iron = rgb(92, 98, 110), Rope = rgb(196, 160, 104), Flag = rgb(92, 98, 110), Emblem = rgb(245, 246, 250),
	LanternGlass = rgb(255, 200, 115),
}
-- the game's 2 recoloured copies (today's colours of the Tundra_2 frozen ship and the Abyss_2 sunken galleon)
PropsBatch2.SHIP_VARIANTS = {
	Frozen = {
		Dark = { "5c4236", "564033", "503b2f" }, Mid = { "865c42", "7e573e", "77523b" }, Red = { "baaaec", "b0a0e2", "a698d8" },
		Deck = { "f4f8ff", "e6eefa", "d8e4f4" }, Sail = { "d6ecff", "e2f2ff", "c8e0f6" },
		Cargo = "997660", Darker = "49342b", Glass = "96d6fa", Rope = "c8c4bc",
	},
	Sunken = {
		Dark = { "5c473b", "574338", "523f35" }, Mid = { "654e41", "5f493d", "594539" }, Red = { "564238", "503e34", "4e3c32" },
		Deck = { "624b3f", "5b463b", "533f35" }, Sail = { "b5bbb5", "aab0aa", "a0a6a0" },
		Cargo = "4e3c32", Darker = "473935", Gold = "5e483d", Glass = "544136", Iron = "685043", Rope = "5a4a3c",
		Flag = "574338", Emblem = "b5bbb5", LanternGlass = "544136",
		transparency = { Emblem = 0.12, Sail1 = 0.12, Sail2 = 0.12, Sail3 = 0.12 }, material = { LanternGlass = "SmoothPlastic" },
	},
}

-- the two wedges of a triangle (corners a, b, c) of thickness t
local function triangleParts(list: { BasePart }, a: Vector3, b: Vector3, c: Vector3, t: number, frame: CFrame, color: Color3)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local w1 = piece("WedgePart", Vector3.new(t, height, math.abs(ab:Dot(back))), frame * CFrame.fromMatrix((a + b) / 2, right, up, back), color)
	local w2 = piece("WedgePart", Vector3.new(t, height, math.abs(ac:Dot(back))), frame * CFrame.fromMatrix((a + c) / 2, -right, up, -back), color)
	table.insert(list, w1)
	table.insert(list, w2)
end

-- [a, b] minus the gaps { {x0, x1} }, keeping pieces longer than 0.3
local function cutSegments(a: number, b: number, gaps: { any }): { any }
	local segs = { { a, b } }
	for _, g in ipairs(gaps) do
		local next = {}
		for _, s in ipairs(segs) do
			if g[2] <= s[1] or g[1] >= s[2] then
				table.insert(next, s)
			else
				if g[1] - s[1] > 0.3 then
					table.insert(next, { s[1], g[1] })
				end
				if s[2] - g[2] > 0.3 then
					table.insert(next, { g[2], s[2] })
				end
			end
		end
		segs = next
	end
	return segs
end

function PropsBatch2.pirate_ship(): Model
	local m = Instance.new("Model")
	m.Name = "pirate_ship"
	local rng = Random.new(20261015)
	BEVEL_SELF = true
	local rad = math.rad
	-- every piece is placed in HullLower's frame (x toward the bow, y up, z across; -Z = the port side with the holes);
	-- today's HullLower sits at REL in the model (the wreck's heel and sink are kept)
	local REL = CFrame.new(-6.385, 10.598, -0.811) * CFrame.fromOrientation(rad(-14), 0, rad(6))
	local U: { [string]: { BasePart } } = {}
	local function add(name: string, p: BasePart)
		local list = U[name]
		if not list then
			list = {}
			U[name] = list
		end
		table.insert(list, p)
	end
	local function put(name: string, className: string, size: Vector3, cf: CFrame)
		local role, ti = string.match(name, "^(%a+)(%d)$")
		local color = if role and SHIP_TONES[role] then SHIP_TONES[role][tonumber(ti) :: number] else SHIP_SINGLE[name]
		add(name, piece(className, size, REL * cf, color))
	end
	local function tone(role: string, prev: number?): (string, number)
		local ti = toneIndex(rng, prev)
		return role .. ti, ti
	end
	local alongZ = CFrame.Angles(rad(90), 0, 0)
	local alongX = CFrame.Angles(0, 0, -math.pi / 2)
	local function rope(a: Vector3, b: Vector3, t: number?)
		add("Rope", bar(REL * a, REL * b, t or 0.18, SHIP_SINGLE.Rope))
	end

	-- 1. Agent A's bow and stern (each rectangle a plank of its thickness). The bow's deck planks are rectangles whose
	-- outer corners came out through the curved side: each one now stops under the waterway, a board along the inside
	-- of the curved side (BOW_LINE = the side's outer line at deck level, from Agent A's strakes)
	local BOW_LINE = { { 39.0, 11.5 }, { 44.9, 10.82 }, { 49.8, 8.83 }, { 53.7, 6.05 }, { 56.2, 3.5 }, { 57.8, 1.43 }, { 58.6, 0.0 } }
	local function bowLimit(zo: number): number
		-- the x where the side's outer line comes within 0.35 of a plank edge at |z| = zo
		for i = 1, #BOW_LINE - 1 do
			local a, b = BOW_LINE[i], BOW_LINE[i + 1]
			local za, zb = a[2] - 0.35, b[2] - 0.35
			if za <= zo then
				return a[1]
			elseif zb <= zo then
				return a[1] + (b[1] - a[1]) * (za - zo) / (za - zb)
			end
		end
		return BOW_LINE[#BOW_LINE][1]
	end
	for _, f in ipairs(PropsBatch2.SHIP_HULL) do
		local pos = Vector3.new(f[1], f[2], f[3])
		local x, y = Vector3.new(f[4], f[5], f[6]), Vector3.new(f[7], f[8], f[9])
		local size = Vector3.new(f[10], f[11], f[12])
		if string.sub(f[13], 1, 4) == "Deck" then
			local x0 = pos.X - f[10] / 2
			local x1 = math.min(pos.X + f[10] / 2, bowLimit(math.abs(pos.Z) + f[11] / 2))
			if x1 - x0 < 0.5 then
				continue
			end
			size = Vector3.new(x1 - x0, f[11], f[12])
			pos = Vector3.new((x0 + x1) / 2, pos.Y, pos.Z)
		end
		put(f[13], "Part", size, CFrame.fromMatrix(pos, x, y))
	end
	for _, side in ipairs({ -1, 1 }) do
		for i = 1, #BOW_LINE - 1 do
			local a = Vector3.new(BOW_LINE[i][1], 12.3, side * math.max(BOW_LINE[i][2] - 1.1, 0))
			local b = Vector3.new(BOW_LINE[i + 1][1], 12.3, side * math.max(BOW_LINE[i + 1][2] - 1.1, 0))
			put("Mid3", "Part", Vector3.new(1.6, 0.5, (b - a).Magnitude + 0.4), CFrame.lookAt((a + b) / 2, b))
		end
	end

	-- 2. the mid hull (x -39..39): 11 clinker strakes a side, the same rows as the bow (bottom edge y, z / top edge y,
	-- z at the joint), the bulwark rows (10, 11) from the cabin forward; the holes on the port side
	local ROWS = {
		{ -4.0, 8.027, -2.0, 8.875, "Dark" }, { -2.2, 8.965, 0.0, 9.75, "Dark" }, { -0.2, 9.841, 2.0, 10.625, "Dark" },
		{ 1.8, 10.716, 4.0, 11.5, "Dark" }, { 3.8, 11.549, 6.0, 11.5, "Mid" }, { 5.8, 11.633, 8.0, 11.5, "Mid" },
		{ 7.8, 11.634, 10.0, 11.5, "Mid" }, { 9.8, 11.639, 11.2, 11.5, "Red" }, { 11.0, 11.64, 12.4, 11.5, "Mid" },
		{ 12.2, 11.638, 13.9, 11.5, "Mid" }, { 13.7, 11.638, 15.4, 11.5, "Mid" },
	}
	local HOLES = { { 14, 2.4, 5.4, 2.9 }, { -22, 1.2, 3.6, 2.0 } } -- today's 2 holes (port side): centre x, y, radii
	for ri, row in ipairs(ROWS) do
		local x0 = if ri >= 10 then -18.0 else -39.0
		for _, side in ipairs({ -1, 1 }) do
			local yb, zb, yt, zt = row[1], row[2] * side, row[3], row[4] * side
			local up = Vector3.new(0, yt - yb, zt - zb)
			local h = up.Magnitude
			up = up.Unit
			local out = Vector3.xAxis:Cross(up)
			if out.Z * side < 0 then
				out = -out
			end
			local mid = Vector3.new(0, (yb + yt) / 2, (zb + zt) / 2) - out * 0.175
			local gaps = {}
			if side < 0 then
				for _, hole in ipairs(HOLES) do
					local dy = ((yb + yt) / 2 - hole[2]) / hole[4]
					if math.abs(dy) < 1 then
						local hx = hole[3] * math.sqrt(1 - dy * dy)
						table.insert(gaps, { hole[1] - hx - rng:NextNumber(0, 0.7), hole[1] + hx + rng:NextNumber(0, 0.7) })
					end
				end
			end
			local x, prev, first = x0, nil, true
			while x < 38.99 do
				local xe = math.min(x + (if first then rng:NextNumber(3, 12) else rng:NextNumber(9, 15)), 39.0)
				first = false
				if 39.0 - xe < 2.5 then
					xe = 39.0
				end
				local name, ti = tone(row[5], prev)
				prev = ti
				for _, s in ipairs(cutSegments(x, xe, gaps)) do
					put(name, "Part", Vector3.new(s[2] - s[1] - 0.06, h, 0.35), CFrame.fromMatrix(mid + Vector3.new((s[1] + s[2]) / 2, 0, 0), Vector3.xAxis, up))
				end
				x = xe
			end
		end
	end
	-- bottom planks, keel, the dark hold inside (seen through the holes and the joints)
	for k = -5, 4 do
		local name = tone("Dark", nil)
		put(name, "Part", Vector3.new(78, 0.35, 1.52), CFrame.new(0, -3.825, 0.8 + k * 1.6))
	end
	put("Dark1", "Part", Vector3.new(79.4, 0.8, 1.0), CFrame.new(0, -4.4, 0))
	for _, b in ipairs({ { -2.0, 3.2, 15.8 }, { 1.6, 4.0, 19.0 }, { 7.6, 8.0, 22.0 } }) do
		put("Darker", "Part", Vector3.new(78.4, b[2], b[3]), CFrame.new(0, b[1], 0))
	end
	-- broken planks at the holes (today's 3)
	for _, b in ipairs({ { 5, -24, 3.4, -12.0, 20, -30 }, { 6, 18, -0.8, -12.0, -20, -10 }, { 7, 10, 5.4, -12.2, 25, 18 } }) do
		add("Cargo", chamfered(Vector3.new(b[1], 1.0, 0.45), REL * CFrame.new(b[2], b[3], b[4]) * CFrame.fromOrientation(0, rad(b[5]), rad(b[6])), SHIP_SINGLE.Cargo, { "vertical" }, 0.12))
	end

	-- 3. gun ports (both sides): a dark opening in a frame, the lid hinged at the top (open on the port side)
	for _, side in ipairs({ -1, 1 }) do
		for _, px in ipairs({ -6, 4, 14, 24 }) do
			local f = CFrame.fromMatrix(Vector3.new(px, 7.5, side * 11.66), Vector3.xAxis * -side, Vector3.yAxis)
			put("Darker", "Part", Vector3.new(2.3, 2.3, 0.14), f)
			for _, e in ipairs({ { 0, 1.32, 2.9, 0.34 }, { 0, -1.32, 2.9, 0.34 }, { 1.32, 0, 0.34, 2.3 }, { -1.32, 0, 0.34, 2.3 } }) do
				put("Dark1", "Part", Vector3.new(e[3], e[4], 0.3), f * CFrame.new(e[1], e[2], -0.12))
			end
			local lid = f * CFrame.new(0, 1.45, -0.28) * CFrame.Angles(if side < 0 then rad(55) else 0, 0, 0) * CFrame.new(0, -1.2, 0)
			put(if side < 0 then "Mid2" else "Mid3", "Part", Vector3.new(2.6, 2.4, 0.22), lid)
			put("Iron", "Part", Vector3.new(0.2, 1.6, 0.08), lid * CFrame.new(-0.7, 0.3, -0.14))
			put("Iron", "Part", Vector3.new(0.2, 1.6, 0.08), lid * CFrame.new(0.7, 0.3, -0.14))
		end
	end

	-- 4. decks: 1.5-wide planks with butt joints over the hold (main deck top 12.4, fore deck 17.25, stern deck 22.3)
	local function deckPlanks(x0: number, x1: number, z0: number, n: number, w: number, yTop: number, t: number)
		for k = 0, n - 1 do
			local zc = z0 + w / 2 + k * w
			local x, prev, first = x0, nil, true
			while x < x1 - 0.01 do
				local xe = math.min(x + (if first then rng:NextNumber(2, 10) else rng:NextNumber(8, 14)), x1)
				first = false
				if x1 - xe < 2 then
					xe = x1
				end
				local name, ti = tone("Deck", prev)
				prev = ti
				put(name, "Part", Vector3.new(xe - x - 0.05, t, w - 0.06), CFrame.new((x + xe) / 2, yTop - t / 2, zc))
				x = xe
			end
		end
	end
	deckPlanks(-18.2, 27.2, -11.5, 16, 1.5, 12.4, 0.8)
	deckPlanks(26.8, 39.8, -11.7, 16, 23.4 / 16, 17.25, 0.7)
	deckPlanks(-42.6, -17.4, -13.0, 18, 26 / 18, 22.3, 0.8)
	-- the red rail cap (cabin to bow) and the bulwark stanchions
	for _, side in ipairs({ -1, 1 }) do
		local x, prev = -18.0, nil
		while x < 38.99 do
			local xe = math.min(x + rng:NextNumber(10, 16), 39.0)
			if 39.0 - xe < 3 then
				xe = 39.0
			end
			local name, ti = tone("Red", prev)
			prev = ti
			put(name, "Part", Vector3.new(xe - x - 0.05, 0.7, 1.49), CFrame.new((x + xe) / 2, 15.75, side * 11.5))
			x = xe
		end
		for k = 0, 9 do
			put("Dark3", "Part", Vector3.new(0.5, 3.0, 0.45), CFrame.new(-16 + k * 4.5, 13.9, side * 10.9))
		end
	end

	-- 5. the forecastle: hold, aft board wall with a small door, 3 steps, railings on its deck
	put("Darker", "Part", Vector3.new(12.3, 4.1, 22.2), CFrame.new(33.45, 14.45, 0))
	local function boardWall(frame: CFrame, a: number, b: number, rows: number, rh: number, role: string, gaps: { any })
		for r = 0, rows - 1 do
			local y0, y1 = r * rh, (r + 1) * rh
			local cuts = {}
			for _, g in ipairs(gaps) do
				if g[3] < y1 - 0.05 and g[4] > y0 + 0.05 then
					table.insert(cuts, { g[1], g[2] })
				end
			end
			local x, prev = a - rng:NextNumber(0, 4), nil
			while x < b - 0.01 do
				local xe = math.min(x + rng:NextNumber(5, 9), b)
				if b - xe < 1.5 then
					xe = b
				end
				local name, ti = tone(role, prev)
				prev = ti
				for _, s in ipairs(cutSegments(math.max(x, a), xe, cuts)) do
					put(name, "Part", Vector3.new(s[2] - s[1] - 0.05, rh - 0.07, 0.3), frame * CFrame.new((s[1] + s[2]) / 2, (y0 + y1) / 2, 0))
				end
				x = xe
			end
		end
	end
	boardWall(CFrame.fromMatrix(Vector3.new(27.0, 12.4, 0), Vector3.zAxis, Vector3.yAxis), -11.5, 11.5, 4, 4.15 / 4, "Mid", { { 3.8, 6.2, 0, 3.1 } })
	do
		local f = CFrame.fromMatrix(Vector3.new(26.95, 12.4, 5.0), -Vector3.zAxis, Vector3.yAxis)
		for i = -1, 1 do
			put("Dark" .. (i + 2), "Part", Vector3.new(0.76, 3.1, 0.24), f * CFrame.new(i * 0.8, 1.55, 0))
		end
		put("Dark1", "Part", Vector3.new(0.34, 3.4, 0.4), f * CFrame.new(-1.37, 1.7, -0.08))
		put("Dark1", "Part", Vector3.new(0.34, 3.4, 0.4), f * CFrame.new(1.37, 1.7, -0.08))
		put("Dark1", "Part", Vector3.new(3.08, 0.34, 0.4), f * CFrame.new(0, 3.27, -0.08))
		put("Iron", "Part", Vector3.new(0.18, 0.18, 0.18), f * CFrame.new(0.75, 1.5, -0.2))
	end
	for k = 1, 3 do
		local top = 12.4 + 1.21 * k
		add("Deck" .. k, chamfered(Vector3.new(1.0, top - 12.4, 4.0), REL * CFrame.new(23.3 + k, (12.4 + top) / 2, -7.4), SHIP_TONES.Deck[k], { "topFrontBack", "topSides" }, 0.08))
	end
	local function railing(a: Vector3, b: Vector3, yBase: number, h: number, skip: { any }?)
		-- posts every ~2.4 (skipping the gaps along the run), a mid rail and a top rail
		local len = (b - a).Magnitude
		local n = math.max(1, math.floor(len / 2.4 + 0.5))
		local dir = (b - a).Unit
		for i = 0, n do
			local p = a + dir * (len * i / n)
			local skipIt = false
			for _, s in ipairs(skip or {}) do
				local d = (p - a):Dot(dir)
				if d > s[1] - 0.2 and d < s[2] + 0.2 then
					skipIt = true
				end
			end
			if not skipIt then
				put(if i % 2 == 0 then "Dark1" else "Dark2", "Part", Vector3.new(0.4, h, 0.4), CFrame.new(p.X, yBase + h / 2, p.Z))
			end
		end
		local segs = cutSegments(0, len, skip or {})
		for _, s in ipairs(segs) do
			local pa, pb = a + dir * s[1], a + dir * s[2]
			local c = (pa + pb) / 2
			local f = CFrame.lookAt(Vector3.new(c.X, 0, c.Z), Vector3.new(c.X, 0, c.Z) + dir)
			put("Dark1", "Part", Vector3.new(0.45, 0.34, s[2] - s[1] + 0.4), f + Vector3.new(0, yBase + h + 0.12, 0))
			put("Dark2", "Part", Vector3.new(0.24, 0.22, s[2] - s[1]), f + Vector3.new(0, yBase + h * 0.5, 0))
		end
	end
	railing(Vector3.new(26.95, 0, -11.55), Vector3.new(26.95, 0, 11.55), 17.25, 2.1, { { 1.9, 6.3 } })
	railing(Vector3.new(27.2, 0, -11.55), Vector3.new(39.6, 0, -11.55), 17.25, 2.1)
	railing(Vector3.new(27.2, 0, 11.55), Vector3.new(39.6, 0, 11.55), 17.25, 2.1)

	-- 6. the stern cabin: hold, board walls with 5 gold-framed windows and the door, corner posts, top beams, the
	-- stern deck's railings, the lantern
	put("Darker", "Part", Vector3.new(23.4, 9.1, 24.0), CFrame.new(-30.0, 16.95, 0))
	local WIN = { 3.0, 6.0 } -- window rows (local y)
	for _, side in ipairs({ -1, 1 }) do
		boardWall(CFrame.fromMatrix(Vector3.new(0, 12.4, side * 12.15), Vector3.xAxis, Vector3.yAxis), -41.85, -18.15, 9, 9.1 / 9, "Mid", { { -26.6, -23.4, WIN[1], WIN[2] }, { -35.6, -32.4, WIN[1], WIN[2] } })
	end
	boardWall(CFrame.fromMatrix(Vector3.new(-41.85, 12.4, 0), Vector3.zAxis, Vector3.yAxis), -12.3, 12.3, 9, 9.1 / 9, "Mid", { { -8.6, -5.4, WIN[1], WIN[2] }, { -1.6, 1.6, WIN[1], WIN[2] }, { 5.4, 8.6, WIN[1], WIN[2] } })
	boardWall(CFrame.fromMatrix(Vector3.new(-18.15, 12.4, 0), Vector3.zAxis, Vector3.yAxis), -12.3, 12.3, 9, 9.1 / 9, "Mid", { { -3.0, 3.0, 0, 7.4 } })
	for _, x in ipairs({ -41.95, -18.05 }) do
		for _, z in ipairs({ -12.25, 12.25 }) do
			add("Dark1", timber(Vector3.new(0.8, 9.1, 0.8), REL * CFrame.new(x, 16.95, z), SHIP_TONES.Dark[1], 0.12))
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		put("Dark2", "Part", Vector3.new(24.6, 0.5, 0.5), CFrame.new(-30.0, 21.25, side * 12.45))
	end
	put("Dark2", "Part", Vector3.new(0.5, 0.5, 25.4), CFrame.new(-42.15, 21.25, 0))
	put("Dark2", "Part", Vector3.new(0.5, 0.5, 25.4), CFrame.new(-17.85, 21.25, 0))
	-- the 5 windows: glass, a gold frame, a dark cross
	local function cabinWindow(f: CFrame)
		put("Glass", "Part", Vector3.new(3.0, 2.9, 0.2), f)
		for _, e in ipairs({ { 0, 1.65, 3.8, 0.4 }, { 0, -1.65, 3.8, 0.4 }, { 1.7, 0, 0.4, 2.9 }, { -1.7, 0, 0.4, 2.9 } }) do
			put("Gold", "Part", Vector3.new(e[3], e[4], 0.4), f * CFrame.new(e[1], e[2], -0.18))
		end
		put("Dark1", "Part", Vector3.new(0.18, 2.9, 0.2), f * CFrame.new(0, 0, -0.1))
		put("Dark1", "Part", Vector3.new(3.0, 0.18, 0.2), f * CFrame.new(0, 0.1, -0.1))
	end
	for _, side in ipairs({ -1, 1 }) do
		for _, x in ipairs({ -25, -34 }) do
			cabinWindow(CFrame.fromMatrix(Vector3.new(x, 16.9, side * 12.15), Vector3.xAxis * -side, Vector3.yAxis))
		end
	end
	for _, z in ipairs({ -7, 0, 7 }) do
		cabinWindow(CFrame.fromMatrix(Vector3.new(-41.85, 16.9, z), -Vector3.zAxis, Vector3.yAxis))
	end
	-- the cabin door (facing the main deck): planks, frame, strap hinges, a ring
	do
		local f = CFrame.fromMatrix(Vector3.new(-18.1, 12.4, 0), Vector3.zAxis, Vector3.yAxis)
		local prev = nil
		for i = -2, 2 do
			local name, ti = tone("Dark", prev)
			prev = ti
			put(name, "Part", Vector3.new(1.16, 7.4, 0.3), f * CFrame.new(i * 1.2, 3.7, 0))
		end
		for _, sx in ipairs({ -1, 1 }) do
			put("Mid1", "Part", Vector3.new(0.5, 7.7, 0.5), f * CFrame.new(sx * 3.25, 3.85, -0.12))
		end
		put("Mid1", "Part", Vector3.new(7.0, 0.5, 0.5), f * CFrame.new(0, 7.65, -0.12))
		for _, y in ipairs({ 1.6, 5.8 }) do
			put("Iron", "Part", Vector3.new(4.2, 0.34, 0.1), f * CFrame.new(-0.9, y, -0.2))
			for _, x in ipairs({ -2.4, -1.0, 0.4 }) do
				add("Iron", piece("Part", Vector3.new(0.15, 0.15, 0.15), REL * f * CFrame.new(x, y, -0.27) * CFrame.Angles(rad(45), rad(45), 0), SHIP_SINGLE.Iron))
			end
		end
		put("Iron", "Part", Vector3.new(0.5, 0.5, 0.08), f * CFrame.new(2.1, 3.7, -0.2))
		for q = 0, 3 do
			local a = rad(45 + 90 * q)
			put("Iron", "Part", Vector3.new(0.6, 0.1, 0.1), f * CFrame.new(2.1 + math.cos(a) * 0.3, 3.6 + math.sin(a) * 0.3, -0.28) * CFrame.Angles(0, 0, a + rad(90)))
		end
		-- the lantern on an iron bracket, left of the door
		local lf = CFrame.new(-16.9, 18.7, -5.4)
		put("Iron", "Part", Vector3.new(1.3, 0.16, 0.16), CFrame.new(-17.4, 20.3, -5.4))
		put("Iron", "Part", Vector3.new(0.12, 0.7, 0.12), CFrame.new(-16.8, 19.95, -5.4))
		put("Iron", "Part", Vector3.new(0.95, 0.14, 0.95), lf * CFrame.new(0, 0.7, 0))
		put("Iron", "Part", Vector3.new(0.6, 0.18, 0.6), lf * CFrame.new(0, 0.85, 0))
		put("Iron", "Part", Vector3.new(0.95, 0.14, 0.95), lf * CFrame.new(0, -0.7, 0))
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				put("Iron", "Part", Vector3.new(0.1, 1.3, 0.1), lf * CFrame.new(sx * 0.42, 0, sz * 0.42))
			end
		end
		put("LanternGlass", "Part", Vector3.new(0.72, 1.26, 0.72), lf)
	end
	-- the stern deck's railings (back, sides, front)
	railing(Vector3.new(-42.3, 0, -12.7), Vector3.new(-42.3, 0, 12.7), 22.3, 2.0)
	railing(Vector3.new(-42.3, 0, -12.7), Vector3.new(-17.7, 0, -12.7), 22.3, 2.0)
	railing(Vector3.new(-42.3, 0, 12.7), Vector3.new(-17.7, 0, 12.7), 22.3, 2.0)
	railing(Vector3.new(-17.7, 0, -12.7), Vector3.new(-17.7, 0, 12.7), 22.3, 2.0)
	-- the rudder on the transom: post, 2 planks, iron straps
	put("Darker", "Part", Vector3.new(0.9, 14.0, 0.9), CFrame.new(-42.0, 2.6, 0))
	put("Darker", "Part", Vector3.new(1.2, 11.0, 0.8), CFrame.new(-43.0, 1.0, 0))
	put("Darker", "Part", Vector3.new(1.0, 9.0, 0.8), CFrame.new(-44.1, 0.0, 0))
	for _, y in ipairs({ -2.0, 2.0, 5.5 }) do
		put("Iron", "Part", Vector3.new(2.9, 0.3, 0.95), CFrame.new(-43.1, y, 0))
	end

	-- 7. the foremast (x 26): mast, topmast, iron bands, crow's nest, 2 yards, the flag
	add("Dark1", octagon(2.8, 30.6, REL * CFrame.new(26, 27.7, 0), SHIP_TONES.Dark[1]))
	add("Dark2", octagon(2.0, 9.8, REL * CFrame.new(26, 47.8, 0), SHIP_TONES.Dark[2]))
	add("Darker", prism16(3.8, 0.9, REL * CFrame.new(26, 12.85, 0), SHIP_SINGLE.Darker))
	for _, y in ipairs({ 18, 26, 34, 40 }) do
		add("Iron", octagon(3.1, 0.4, REL * CFrame.new(26, y, 0), SHIP_SINGLE.Iron))
	end
	add("Deck1", prism16(6.0, 0.3, REL * CFrame.new(26, 42.6, 0), SHIP_TONES.Deck[1]))
	for k = 0, 15 do
		local a = k * math.pi / 8
		local f = CFrame.new(26 + math.cos(a) * 2.85, 43.55, math.sin(a) * 2.85) * CFrame.Angles(0, -a + math.pi / 2, 0)
		put("Mid" .. (k % 3 + 1), "Part", Vector3.new(1.12, 1.6, 0.25), f)
		put("Dark1", "Part", Vector3.new(1.2, 0.3, 0.42), f * CFrame.new(0, 0.95, 0))
	end
	add("Dark2", octagon(1.5, 30.0, REL * CFrame.new(28.15, 37.05, 0) * alongZ, SHIP_TONES.Dark[2]))
	add("Dark3", octagon(1.2, 22.0, REL * CFrame.new(24.0, 28.85, 0) * alongZ, SHIP_TONES.Dark[3]))
	for _, p in ipairs({ { 28.15, 37.05 }, { 24.0, 28.85 } }) do
		add("Iron", octagon(1.75, 0.8, REL * CFrame.new(p[1], p[2], 0) * alongZ, SHIP_SINGLE.Iron))
	end
	-- the flag at the masthead: 3 waving strips, the emblem (skull and crossbones) on both faces
	for i = 0, 2 do
		local f = CFrame.new(28.0 + i * 1.98, 49.6, (i % 2) * 0.22) * CFrame.Angles(0, rad(if i % 2 == 0 then 8 else -8), 0)
		put("Flag", "Part", Vector3.new(2.0, 4.0 - i * 0.25, 0.16), f)
	end
	for _, s in ipairs({ -1, 1 }) do
		local f = CFrame.new(29.98, 50.0, 0.22 + s * 0.13)
		add("Emblem", chamfered(Vector3.new(1.1, 0.95, 0.08), REL * f, SHIP_SINGLE.Emblem, { "topSides" }, 0.25))
		put("Emblem", "Part", Vector3.new(0.5, 0.4, 0.08), f * CFrame.new(0, -0.55, 0))
		put("Emblem", "Part", Vector3.new(1.9, 0.26, 0.08), f * CFrame.new(0, -1.15, 0) * CFrame.Angles(0, 0, rad(32)))
		put("Emblem", "Part", Vector3.new(1.9, 0.26, 0.08), f * CFrame.new(0, -1.15, 0) * CFrame.Angles(0, 0, rad(-32)))
	end

	-- 8. the broken mainmast (x 2): stump, collar, bands, splinters, hanging ropes; the fallen mast and yard
	add("Dark1", octagon(3.2, 19.0, REL * CFrame.new(2, 21.9, 0), SHIP_TONES.Dark[1]))
	add("Darker", prism16(4.4, 1.2, REL * CFrame.new(2, 13.0, 0), SHIP_SINGLE.Darker))
	for _, y in ipairs({ 17, 24 }) do
		add("Iron", octagon(3.5, 0.4, REL * CFrame.new(2, y, 0), SHIP_SINGLE.Iron))
	end
	for k = 0, 4 do
		local a = rad(72 * k + 10)
		local h = rng:NextNumber(1.6, 3.6)
		put("Dark" .. (k % 3 + 1), "WedgePart", Vector3.new(0.9, h, 1.2), CFrame.new(2 + math.cos(a) * 0.85, 31.4 + h / 2 - 0.1, math.sin(a) * 0.85) * CFrame.Angles(0, -a, 0))
	end
	rope(Vector3.new(2.3, 30.6, 1.6), Vector3.new(6.5, 12.5, 6.8))
	rope(Vector3.new(1.7, 30.6, -1.6), Vector3.new(-2.8, 12.5, -6.2))
	local fallen = CFrame.new(16, 21.25, -16.5) * CFrame.fromOrientation(0, rad(48), rad(-23))
	add("Dark2", octagon(2.8, 39.3, REL * fallen * alongX, SHIP_TONES.Dark[2]))
	for _, d in ipairs({ -12, 4, 14 }) do
		add("Iron", octagon(3.1, 0.4, REL * fallen * CFrame.new(d, 0, 0) * alongX, SHIP_SINGLE.Iron))
	end
	add("Dark3", octagon(1.4, 23.35, REL * CFrame.new(17, 23.5, -15) * CFrame.fromOrientation(0, rad(-38), rad(12)) * alongX, SHIP_TONES.Dark[3]))
	rope((fallen * CFrame.new(-4, 0, 0)).Position, Vector3.new(12.5, 16.1, -11.9))
	rope((fallen * CFrame.new(8, 0, 0)).Position, Vector3.new(21.0, 16.1, -11.9))

	-- 9. rigging: shrouds with ratlines, the yards' lifts, the forestay to the bowsprit
	for _, side in ipairs({ -1, 1 }) do
		local tops, feet = {}, {}
		for k = 0, 2 do
			tops[k + 1] = Vector3.new(26, 42.2, side * 1.3)
			feet[k + 1] = Vector3.new(21.5 + 2 * k, 16.1, side * 11.9)
			rope(tops[k + 1], feet[k + 1], 0.2)
			put("Iron", "Part", Vector3.new(0.3, 1.2, 0.25), CFrame.new(feet[k + 1].X, 14.9, side * 11.85))
		end
		for y = 18.5, 40.5, 2 do
			local pts = {}
			for k = 1, 3 do
				local t = (y - feet[k].Y) / (tops[k].Y - feet[k].Y)
				pts[k] = feet[k]:Lerp(tops[k], t)
			end
			rope(pts[1], pts[2], 0.1)
			rope(pts[2], pts[3], 0.1)
		end
		rope(Vector3.new(28.15, 37.05, side * 14.6), Vector3.new(26.4, 50.5, side * 0.45), 0.14)
		rope(Vector3.new(24.0, 28.85, side * 10.8), Vector3.new(25.2, 41.6, side * 0.9), 0.14)
	end
	add("Dark1", octagon(1.6, 19.0, REL * CFrame.new(65, 16.5, 0) * CFrame.Angles(0, 0, rad(18)) * alongX, SHIP_TONES.Dark[1]))
	add("Iron", octagon(1.9, 0.5, REL * CFrame.new(65, 16.5, 0) * CFrame.Angles(0, 0, rad(18)) * CFrame.new(-6.5, 0, 0) * alongX, SHIP_SINGLE.Iron))
	rope(Vector3.new(26.9, 42.3, 0), Vector3.new(73.6, 19.4, 0), 0.2)

	-- 10. the sails (Agent A's facets): the main sail on the fore side of the mast under the upper yard, the remnant on
	-- the aft side under the lower yard (moved off the main sail, which it overlapped), the fallen sail on the port rail
	local SAIL_PLACE = {
		main = CFrame.new(28.15, 36.6, 0) * CFrame.fromOrientation(0, rad(-90), 0),
		remnant = CFrame.new(24.0, 28.4, -7.5) * CFrame.fromOrientation(0, rad(90), 0),
		fallen = CFrame.new(17, 16.1, -11.5),
	}
	for key, data in pairs(PropsBatch2.SHIP_SAILS) do
		local place = REL * SAIL_PLACE[key]
		for _, f in ipairs(data.rects) do
			local pos = Vector3.new(f[1], f[2], f[3])
			add(f[13], piece("Part", Vector3.new(f[10], f[11], f[12]), place * CFrame.fromMatrix(pos, Vector3.new(f[4], f[5], f[6]), Vector3.new(f[7], f[8], f[9])), SHIP_TONES.Sail[tonumber(string.sub(f[13], -1)) :: number]))
		end
		for _, f in ipairs(data.tris) do
			local list = U[f[11]] or {}
			U[f[11]] = list
			triangleParts(list, Vector3.new(f[1], f[2], f[3]), Vector3.new(f[4], f[5], f[6]), Vector3.new(f[7], f[8], f[9]), f[10], place, SHIP_TONES.Sail[tonumber(string.sub(f[11], -1)) :: number])
		end
	end

	-- 11. the anchor on the port bow (outside the planks) and its rope to the rail
	do
		local a = CFrame.new(46, 0, -10.75)
		add("Iron", octagon(0.7, 7.0, REL * a * CFrame.new(0, 5.0, 0), SHIP_SINGLE.Iron))
		add("Iron", octagon(0.6, 3.6, REL * a * CFrame.new(0, 7.6, 0) * alongX, SHIP_SINGLE.Iron))
		for q = 0, 3 do
			local ang = rad(45 + 90 * q)
			put("Iron", "Part", Vector3.new(0.75, 0.18, 0.18), a * CFrame.new(math.cos(ang) * 0.38, 9.05 + math.sin(ang) * 0.38, 0) * CFrame.Angles(0, 0, ang + rad(90)))
		end
		put("Iron", "Part", Vector3.new(1.6, 0.7, 0.7), a * CFrame.new(0, 1.65, 0))
		for _, sx in ipairs({ -1, 1 }) do
			local arm = a * CFrame.new(sx * 1.35, 2.2, 0) * CFrame.Angles(0, 0, rad(sx * 40))
			put("Iron", "Part", Vector3.new(1.9, 0.6, 0.6), arm)
			put("Iron", "WedgePart", Vector3.new(0.35, 1.3, 1.1), a * CFrame.new(sx * 2.15, 3.0, 0) * CFrame.Angles(0, rad(if sx < 0 then 90 else -90), 0))
		end
		rope(Vector3.new(46, 9.4, -10.75), Vector3.new(45.0, 15.9, -10.9), 0.22)
	end

	-- 12. cargo: the crate, 3 barrels (iron hoops), 2 rope coils
	U.Cargo = U.Cargo or {}
	slatCrate(U.Cargo, rng, REL * CFrame.new(-6, 12.4, -6) * CFrame.Angles(0, rad(20), 0), 4, 4, 4, { SHIP_SINGLE.Cargo, SHIP_SINGLE.Cargo, SHIP_SINGLE.Cargo }, SHIP_SINGLE.Cargo)
	local function barrel(cf: CFrame, k: number)
		add("Mid" .. k, prism16(2.9, 4.0, REL * cf, SHIP_TONES.Mid[k]))
		add("Mid" .. k, prism16(3.15, 1.5, REL * cf, SHIP_TONES.Mid[k]))
		for _, y in ipairs({ -1.5, -0.62, 0.62, 1.5 }) do
			add("Iron", prism16(if math.abs(y) > 1 then 3.05 else 3.25, 0.22, REL * cf * CFrame.new(0, y, 0), SHIP_SINGLE.Iron))
		end
		add("Deck2", prism16(2.55, 0.1, REL * cf * CFrame.new(0, 2.02, 0), SHIP_TONES.Deck[2]))
	end
	barrel(CFrame.new(12, 14.4, 6), 1)
	barrel(CFrame.new(15.0, 14.4, 7.9), 2)
	barrel(CFrame.new(-10.5, 13.85, -8.8) * CFrame.Angles(rad(90), rad(30), 0), 3)
	for _, c in ipairs({ { 20.5, 8.0 }, { -14.0, 9.2 } }) do
		add("Rope", prism16(2.6, 0.32, REL * CFrame.new(c[1], 12.56, c[2]), SHIP_SINGLE.Rope))
		add("Rope", prism16(1.95, 0.3, REL * CFrame.new(c[1], 12.86, c[2]), SHIP_SINGLE.Rope))
		add("Rope", prism16(1.25, 0.26, REL * CFrame.new(c[1], 13.12, c[2]), SHIP_SINGLE.Rope))
	end

	-- unions: one colour each (UsePartColor true: the _Variants recolour them by name); the hull, decks, cabin and
	-- cargo collide (precise, so the decks are walkable); ropes, sails, flag, emblem and the lantern glass do not
	local NOCOLLIDE = { Rope = true, Flag = true, Emblem = true, Sail1 = true, Sail2 = true, Sail3 = true, LanternGlass = true }
	local names = {}
	for name in pairs(U) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local role, ti = string.match(name, "^(%a+)(%d)$")
		local color = if role and SHIP_TONES[role] then SHIP_TONES[role][tonumber(ti) :: number] else SHIP_SINGLE[name]
		local opts: any = { single = color, collide = not NOCOLLIDE[name], fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition }
		if name == "LanternGlass" then
			opts.material = Enum.Material.Neon
			opts.shadow = false
		end
		if NOCOLLIDE[name] then
			opts.fidelity = nil
			opts.shadow = name ~= "Rope"
		end
		merge(m, name, U[name], opts)
		task.wait()
	end

	-- the variants of the Tundra_2 and Abyss_2 copies
	local folder = Instance.new("Folder")
	folder.Name = "_Variants"
	for vname, v in pairs(PropsBatch2.SHIP_VARIANTS) do
		local config = Instance.new("Configuration")
		config.Name = vname
		for key, value in pairs(v) do
			if type(value) == "table" and SHIP_TONES[key] then
				for i, hex in ipairs(value) do
					config:SetAttribute("Color_" .. key .. i, Color3.fromHex(hex))
				end
			elseif type(value) == "string" then
				config:SetAttribute("Color_" .. key, Color3.fromHex(value))
			end
		end
		for key, t in pairs(v.transparency or {}) do
			config:SetAttribute("Transparency_" .. key, t)
		end
		for key, mat in pairs(v.material or {}) do
			config:SetAttribute("Material_" .. key, mat)
		end
		config.Parent = folder
	end
	folder.Parent = m

	local root = m:FindFirstChild("Darker") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", "pirate_ship")
	BEVEL_SELF = false
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

-- the shared helpers, for the builder modules that follow this one (DevTools.PropsDesert ...): this module is over
-- Studio's 200,000-character Source limit, so new builders live in their own modules and register into a fresh
-- PropsBatch2 table (its install() then builds them)
PropsBatch2.H = {
	P = P, TONES = TONES, GAP = GAP, LOG_END = LOG_END, ROPE = ROPE, EDGES = EDGES,
	smoothstep = smoothstep, scaled = scaled, graded = graded, toneIndex = toneIndex, jit = jit,
	piece = piece, negWedge = negWedge, chamfered = chamfered, subtractKeep = subtractKeep, convexSolid = convexSolid,
	merge = merge, plain = plain, timber = timber, rivet = rivet, band = band, bar = bar, frameY = frameY,
	octagon = octagon, prism16 = prism16, disc16 = disc16, ringBlocks = ringBlocks, pyramidPlanes = pyramidPlanes,
	flame = flame, shingleRoof = shingleRoof, slatCrate = slatCrate, fruitPiece = fruitPiece, scroll = scroll,
	mossPad = mossPad, cutSegments = cutSegments, triangleParts = triangleParts, course = course, slabs = slabs,
	ringCourse = ringCourse, capSlabs = capSlabs, -- (the plains gates' pier courses and caps, reused by the tundra gates)
	setBevelSelf = function(on: boolean)
		BEVEL_SELF = on
	end,
}

PropsBatch2.BUILDERS = {
	portal_frame = true, hub_wall = true, stone_arch = true, stone_pillar = true,
	entry_arch = true, gate_palisade = true, gate_barricade = true, gate_mine = true,
	rebirth_altar = true, egg_station = true, moon_gazebo = true, fruit_stall = true,
	training_area = true, leaderboard = true, codes_board = true, team_board = true, park_bench = true, street_lamp = true,
	golem_statue = true, windmill = true, pirate_ship = true,
}

return PropsBatch2
