--[[
	PropsDesert (dev tool, Edit mode only) - the owner's "DESERT ZONE PROP IMPROVEMENT - Buildings and shelters"
	(2026-10-19): the desert buildings and shelters of docs/Desert_Images/01_Buildings_and_Shelters rebuilt to the
	fountain / well quality with the desert recipe (docs/prop_texture_guide.md sections A and B), from parts merged into
	a few unions per colour group, keeping each object's own colours (the desert identity). Source of truth:
	tools/PropsDesert.luau. Inventory: docs/prop_inventory.md "Desert buildings and shelters".

	It uses DevTools.PropsBatch2's shared helpers (PropsBatch2.H: PropsBatch2 itself is over Studio's 200,000-character
	Source limit) and registers its builders into a fresh PropsBatch2 table, whose install() builds them:
		local D = require(game.ServerStorage.DevTools.PropsDesert:Clone())
		print(D.install("adobe_house_a"))   -- (re)builds ServerStorage.MapProps.adobe_house_a (old one -> _Previous)
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "adobe_house_a" } }), Sync.run({ only = { "adobe_house_a" } }))
]]
local ServerStorage = game:GetService("ServerStorage")
local GeometryService = game:GetService("GeometryService")

local B2 = require(ServerStorage.DevTools.PropsBatch2:Clone()) :: any
local H = B2.H
local TONES = H.TONES
local smoothstep, scaled, toneIndex = H.smoothstep, H.scaled, H.toneIndex
local piece, chamfered, merge, convexSolid = H.piece, H.chamfered, H.merge, H.convexSolid
local octagon, prism16, timber, bar = H.octagon, H.prism16, H.timber, H.bar

local PropsDesert = {}

local rgb = Color3.fromRGB
local rad = math.rad

-- desert palette (docs/prop_texture_guide.md B1: today's real part colours)
local C = {
	Clay = rgb(222, 164, 110), ClayLight = rgb(242, 179, 120), Footing = rgb(184, 146, 98), Sandstone = rgb(226, 190, 132),
	Terracotta = rgb(204, 96, 62), Turquoise = rgb(64, 208, 196), Blue = rgb(60, 150, 170), Red = rgb(214, 74, 62),
	Linen = rgb(232, 226, 208), Gold = rgb(255, 201, 60), Trunk = rgb(150, 104, 64), DarkWood = rgb(112, 62, 38),
	Recess = rgb(83, 62, 40), Rope = rgb(196, 160, 104), Lapis = rgb(44, 92, 200), Iron = rgb(52, 56, 66),
}
PropsDesert.PALETTE = C
local PLASTER_TONES = { 1, 0.96, 0.92 } -- plaster layers: a quieter step than the blocks' x1 / x0.93 / x0.86

-- the soft desert gradient: lighter at the top, a little darker at the base (keeps the colour identity)
local function soft(c: Color3, h: number, Ht: number, tone: number?): Color3
	return scaled(c, (tone or 1) * (0.9 + 0.1 * smoothstep(h / Ht)))
end

-- union lists by name
local function lists()
	local U: { [string]: { BasePart } } = {}
	local function add(name: string, p: BasePart)
		local l = U[name]
		if not l then
			l = {}
			U[name] = l
		end
		table.insert(l, p)
	end
	return U, add
end

---------------------------------------------------------------------
-- adobe pieces (docs B2-B4, B7, B9)
---------------------------------------------------------------------
-- a block b = { x0, x1, z0, z1 (at the base), y0 (bottom of the plaster), y1 (top), batter }: the frame on face
-- "front" (-Z) / "back" / "left" (-X) / "right" at u (x on front / back, z on the sides) and height y, `out` studs in
-- front of the battered face; its local -Z points out of the wall, its X runs along the face
local function faceCF(b: any, face: string, u: number, y: number, out: number): CFrame
	local inset = b.batter * math.clamp((y - b.y0) / (b.y1 - b.y0), 0, 1)
	if face == "front" then
		return CFrame.new(u, y, b.z0 + inset - out)
	elseif face == "back" then
		return CFrame.new(u, y, b.z1 - inset + out) * CFrame.Angles(0, math.pi, 0)
	elseif face == "left" then
		return CFrame.new(b.x0 + inset - out, y, u) * CFrame.Angles(0, math.pi / 2, 0)
	end
	return CFrame.new(b.x1 - inset + out, y, u) * CFrame.Angles(0, -math.pi / 2, 0)
end

-- a plastered adobe block: one slab per plaster layer (b.layers between b.y0 and b.y1, 0.08 joints showing the darker
-- core), battered (each layer set in by b.batter x its height fraction), alternate layers 0.04 proud, tone steps,
-- chamfered vertical corners; the openings { face, u, y, w, h } cut 0.3 deep (dark recess); chipped corners
-- { corner 1-4, y, size } showing the darker block colour; b.base = bottom of the hidden core (inside the footing)
local function adobeBlock(list: { BasePart }, rng: Random, b: any)
	local w, d = b.x1 - b.x0, b.z1 - b.z0
	local cx, cz = (b.x0 + b.x1) / 2, (b.z0 + b.z1) / 2
	local base = b.base or b.y0
	table.insert(list, piece("Part", Vector3.new(w - 2 * b.batter - 0.5, b.y1 - base, d - 2 * b.batter - 0.5), CFrame.new(cx, (base + b.y1) / 2, cz), scaled(b.color, 0.72)))
	if base < b.y0 then
		table.insert(list, piece("Part", Vector3.new(w - 0.1, b.y0 - base + 0.04, d - 0.1), CFrame.new(cx, (base + b.y0) / 2, cz), scaled(b.color, 0.9)))
	end
	local n = b.layers
	local hl = (b.y1 - b.y0 - 0.08 * (n - 1)) / n
	local corners = { { b.x0, b.z0 }, { b.x1, b.z0 }, { b.x1, b.z1 }, { b.x0, b.z1 } }
	local prev = nil
	for k = 0, n - 1 do
		local yb = b.y0 + k * (hl + 0.08)
		local yt = yb + hl
		local inset = b.batter * (k + 0.5) / n - (if k % 2 == 0 then 0.04 else 0)
		local size = Vector3.new(w - 2 * inset, hl, d - 2 * inset)
		local cf = CFrame.new(cx, (yb + yt) / 2, cz)
		local negs = {}
		for _, o in ipairs(b.openings or {}) do
			if o.y - o.h / 2 < yt and o.y + o.h / 2 > yb then
				table.insert(negs, piece("Part", Vector3.new(o.w, o.h, 0.6), faceCF(b, o.face, o.u, o.y, 0), C.Recess))
			end
		end
		for _, ch in ipairs(b.chips or {}) do
			if ch[2] >= yb and ch[2] <= yt then
				local c = corners[ch[1]]
				local x = cx + (if c[1] < cx then -1 else 1) * size.X / 2
				local z = cz + (if c[2] < cz then -1 else 1) * size.Z / 2
				table.insert(negs, piece("Part", Vector3.new(ch[3], ch[3], ch[3]), CFrame.new(x, ch[2], z) * CFrame.Angles(0, rad(45), 0), scaled(C.Footing, 0.95)))
			end
		end
		local ti = toneIndex(rng, prev)
		prev = ti
		table.insert(list, chamfered(size, cf, soft(b.color, (yb + yt) / 2, b.H, PLASTER_TONES[ti]), { "vertical" }, 0.3, nil, negs))
	end
end

-- a 0.38 band of light plaster, 0.1 proud, around a block at height y
local function plasterBand(list: { BasePart }, b: any, y: number, color: Color3)
	local inset = b.batter * math.clamp((y - b.y0) / (b.y1 - b.y0), 0, 1)
	local size = Vector3.new(b.x1 - b.x0 - 2 * inset + 0.2, 0.38, b.z1 - b.z0 - 2 * inset + 0.2)
	table.insert(list, chamfered(size, CFrame.new((b.x0 + b.x1) / 2, y, (b.z0 + b.z1) / 2), soft(color, y, b.H, 1), { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.08))
end

-- the footing: a ring of chamfered blocks (2.5-3.5 long, 0.08 joints, 1.0 deep) around a dark core, x0..x1 / z0..z1
local function footing(list: { BasePart }, rng: Random, x0: number, x1: number, z0: number, z1: number, h: number, Ht: number)
	table.insert(list, piece("Part", Vector3.new(x1 - x0 - 1.0, h - 0.04, z1 - z0 - 1.0), CFrame.new((x0 + x1) / 2, h / 2, (z0 + z1) / 2), scaled(C.Footing, 0.72)))
	local function row(a: number, bEnd: number, fixed: number, alongX: boolean)
		local x, prev = a, nil
		while x < bEnd - 0.01 do
			local xe = math.min(x + rng:NextNumber(2.5, 3.5), bEnd)
			if bEnd - xe < 1.2 then
				xe = bEnd
			end
			local ti = toneIndex(rng, prev)
			prev = ti
			local len = xe - x - 0.08
			local mid = (x + xe) / 2
			local size = if alongX then Vector3.new(len, h, 1.0) else Vector3.new(1.0, h, len)
			local cf = if alongX then CFrame.new(mid, h / 2, fixed) else CFrame.new(fixed, h / 2, mid)
			table.insert(list, chamfered(size, cf, soft(C.Footing, h / 2, Ht, TONES[ti]), { "vertical", "topFrontBack", "topSides" }, 0.15))
			x = xe
		end
	end
	row(x0, x1, z0 + 0.5, true)
	row(x0, x1, z1 - 0.5, true)
	row(z0 + 1.04, z1 - 1.04, x0 + 0.5, false)
	row(z0 + 1.04, z1 - 1.04, x1 - 0.5, false)
end

-- a patch where the plaster fell off: a dark plate and 2 staggered rows of sandstone blocks, 0.05 proud, at cf (a face
-- frame, local -Z out)
local function blockPatch(list: { BasePart }, rng: Random, cf: CFrame, Ht: number)
	local w = rng:NextNumber(2.8, 3.6)
	table.insert(list, piece("Part", Vector3.new(w, 1.7, 0.06), cf * CFrame.new(0, 0, -0.03), scaled(C.Footing, 0.9)))
	local prev = nil
	for r = 0, 1 do
		local y = -0.42 + r * 0.82
		local x = -w / 2 + 0.08 - (if r == 1 then rng:NextNumber(0.4, 0.7) else 0)
		while x < w / 2 - 0.5 do
			local len = math.min(rng:NextNumber(1.2, 1.6), w / 2 - 0.08 - x)
			local a = math.max(x, -w / 2 + 0.08)
			if len > 0.5 and x + len - a > 0.5 then
				local ti = toneIndex(rng, prev)
				prev = ti
				table.insert(list, chamfered(Vector3.new(x + len - a, 0.72, 0.14), cf * CFrame.new((a + x + len) / 2, y, -0.1), soft(C.Sandstone, (cf * CFrame.new(0, y, 0)).Position.Y, Ht, TONES[ti]), { "frontFace" }, 0.05))
			end
			x += len + 0.08
		end
	end
end

-- a parapet segment: body (len x h x thick at cf, its X along the run) and a cap 0.25 thick, 0.15 over, top chamfered
local function parapetSeg(list: { BasePart }, rng: Random, cf: CFrame, len: number, h: number, thick: number, Ht: number)
	local ti = rng:NextInteger(1, 3)
	table.insert(list, chamfered(Vector3.new(len, h, thick), cf * CFrame.new(0, h / 2, 0), soft(C.ClayLight, (cf.Position.Y + h / 2), Ht, PLASTER_TONES[ti]), { "vertical" }, 0.12))
	table.insert(list, chamfered(Vector3.new(len + 0.3, 0.25, thick + 0.3), cf * CFrame.new(0, h + 0.125, 0), soft(C.ClayLight, cf.Position.Y + h, Ht, PLASTER_TONES[ti % 3 + 1]), { "vertical", "topFrontBack", "topSides" }, 0.12))
end

-- a viga: an octagonal log 0.85 across from `inside` studs within the wall to 1.4 out of it, its end cut at 28 degrees
-- (top longer; the cut face shows the dark end grain), and a terracotta socket ring at the wall (cf = a face frame)
local function viga(wood: { BasePart }, frames: { BasePart }, rng: Random, cf: CFrame, Ht: number)
	local out, inside = 1.4, 0.8
	local frame = cf * CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, -Vector3.zAxis, Vector3.yAxis) -- local Y = out, Z = up
	local planes = { { 0, -1, 0, inside } }
	for k = 0, 7 do
		local a = rad(22.5 + 45 * k)
		table.insert(planes, { math.cos(a), 0, math.sin(a), 0.425 })
	end
	local n = Vector3.new(0, 0.85, -0.85 * math.tan(rad(28))).Unit
	table.insert(planes, { n.X, n.Y, n.Z, n:Dot(Vector3.new(0, out, 0.425)), scaled(C.Trunk, 0.78) }) -- the end grain, a darker wood
	local ti = rng:NextInteger(1, 3)
	table.insert(wood, convexSolid(Vector3.new(-0.47, -inside, -0.47), Vector3.new(0.47, out, 0.47), frame, soft(C.Trunk, cf.Position.Y, Ht, TONES[ti]), planes))
	table.insert(frames, octagon(1.05, 0.15, frame * CFrame.new(0, 0.02, 0), C.Terracotta))
end

-- a 4-panel cloth awning on a wall (cf = a face frame at the awning's back edge, centre of its width): panels 0.15
-- thick pitched 17 degrees down with pleats, a valance of rounded tabs with a linen piping, 2 wooden struts, rope ties
local function awning(cloth: { BasePart }, wood: { BasePart }, details: { BasePart }, cf: CFrame, width: number, depth: number, color: Color3)
	local pitch = rad(17)
	local n = 4
	local pw = width / n
	for i = 0, n - 1 do
		local xc = -width / 2 + pw * (i + 0.5)
		local fold = if i % 2 == 0 then rad(3) else rad(-3)
		local p = cf * CFrame.Angles(-pitch, 0, 0) * CFrame.new(xc, (if i % 2 == 0 then 0.05 else 0), -depth / 2) * CFrame.Angles(0, 0, fold)
		table.insert(cloth, piece("Part", Vector3.new(pw + 0.04, 0.15, depth), p, scaled(color, ({ 1, 0.93 })[i % 2 + 1])))
	end
	local edge = (cf * CFrame.Angles(-pitch, 0, 0) * CFrame.new(0, 0, -depth)).Position
	local vf = CFrame.new(edge) * (cf - cf.Position)
	table.insert(cloth, piece("Part", Vector3.new(width + 0.1, 0.34, 0.12), vf * CFrame.new(0, -0.14, 0), scaled(color, 0.9)))
	table.insert(details, piece("Part", Vector3.new(width + 0.14, 0.09, 0.16), vf * CFrame.new(0, 0.02, -0.02), C.Linen))
	local tabs = n * 2
	for t = 0, tabs - 1 do
		local x = -width / 2 + width / tabs * (t + 0.5)
		table.insert(cloth, chamfered(Vector3.new(width / tabs - 0.06, 0.6, 0.12), vf * CFrame.new(x, -0.55, 0), color, { "bottomSides" }, 0.24))
	end
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * (width / 2 - 0.5)
		local wallPt = (cf * CFrame.new(x, -1.5, 0.1)).Position
		local clothPt = (cf * CFrame.Angles(-pitch, 0, 0) * CFrame.new(x, -0.12, -1.6)).Position
		table.insert(wood, bar(wallPt, clothPt, 0.25, C.Trunk))
		local corner = (cf * CFrame.Angles(-pitch, 0, 0) * CFrame.new(sx * width / 2, 0.1, -depth + 0.1)).Position
		table.insert(details, bar(corner, (cf * CFrame.new(sx * (width / 2 + 0.2), 0.75, 0.05)).Position, 0.12, C.Rope))
	end
end

-- a planked door at the old door's place (doorCF = its centre, size w x h x 0.6, -Z out): planks with 0.06 gaps over a
-- dark backing, 2 battens with gold studs, 2 iron hinge straps; the knob at knobPos
local function plankDoor(door: { BasePart }, details: { BasePart }, doorCF: CFrame, w: number, h: number, visibleBottom: number, color: Color3, knobPos: Vector3)
	-- the planks start 0.3 under the visible bottom (below, the door is inside the footing: its joints showed the planks)
	local hv = h - visibleBottom + 0.3
	local yc = h / 2 - hv / 2
	table.insert(door, piece("Part", Vector3.new(w - 0.1, hv - 0.1, 0.24), doorCF * CFrame.new(0, yc, 0.16), C.Recess))
	local np = 4
	local pw = (w - 0.06 * (np - 1)) / np
	for i = 0, np - 1 do
		table.insert(door, chamfered(Vector3.new(pw, hv, 0.48), doorCF * CFrame.new(-w / 2 + pw / 2 + i * (pw + 0.06), yc, -0.06), scaled(color, ({ 1, 0.93, 0.86, 0.96 })[i + 1]), { "vertical" }, 0.06))
	end
	local yb = -h / 2 + visibleBottom
	local vis = h - visibleBottom
	for _, f in ipairs({ 0.2, 0.8 }) do
		local y = yb + vis * f
		table.insert(door, chamfered(Vector3.new(w - 0.5, 0.3, 0.15), doorCF * CFrame.new(0, y, -0.37), scaled(color, 0.82), { "topFrontBack", "bottomFrontBack" }, 0.05))
		for _, x in ipairs({ -w / 2 + 0.7, 0, w / 2 - 0.7 }) do
			table.insert(details, piece("Part", Vector3.new(0.16, 0.16, 0.16), doorCF * CFrame.new(x, y, -0.46) * CFrame.Angles(rad(45), rad(45), 0), C.Gold))
		end
		table.insert(details, piece("Part", Vector3.new(1.9, 0.22, 0.06), doorCF * CFrame.new(-w / 2 + 0.95, y + 0.3, -0.33), C.Iron))
		table.insert(details, piece("Part", Vector3.new(0.26, 0.6, 0.26), doorCF * CFrame.new(-w / 2 + 0.05, y + 0.3, -0.25), C.Iron))
	end
	-- the knob: a gold boss and a ring
	table.insert(details, chamfered(Vector3.new(0.5, 0.5, 0.3), CFrame.new(knobPos) * (doorCF - doorCF.Position), C.Gold, { "frontFace" }, 0.12))
	for q = 0, 3 do
		local a = rad(45 + 90 * q)
		table.insert(details, piece("Part", Vector3.new(0.5, 0.09, 0.09), CFrame.new(knobPos) * (doorCF - doorCF.Position) * CFrame.new(math.cos(a) * 0.26, -0.2 + math.sin(a) * 0.26, -0.2) * CFrame.Angles(0, 0, a + rad(90)), C.Gold))
	end
end

-- a window on a face frame cf (its centre on the battered face): a terracotta frame 0.3 around the w x h opening (cut by
-- adobeBlock), a wooden lintel 0.6 longer, the sill (its old size and place), and 2 open shutters (110 degrees, 3
-- planks, 2 hinges each) or a grille of 3 dark bars
local function window(add: any, cf: CFrame, w: number, h: number, sillSize: Vector3, sillCF: CFrame, shutterColor: Color3?)
	for _, sx in ipairs({ -1, 1 }) do
		add("Frames", chamfered(Vector3.new(0.3, h + 0.3, 0.45), cf * CFrame.new(sx * (w / 2 + 0.15), 0.15, -0.02), C.Terracotta, { "frontFace" }, 0.06))
	end
	add("Frames", chamfered(sillSize, sillCF, C.Terracotta, { "topFrontBack", "topSides" }, 0.1))
	add("Wood", timber(Vector3.new(w + 0.9, 0.4, 0.5), cf * CFrame.new(0, h / 2 + 0.3, -0.05), C.Trunk, 0.08))
	if shutterColor then
		for _, sx in ipairs({ -1, 1 }) do
			local hinge = cf * CFrame.new(sx * (w / 2 + 0.3), 0, -0.3) * CFrame.Angles(0, sx * -rad(110), 0)
			local leaf = w / 2
			local pw = (leaf - 0.08) / 3
			for i = 0, 2 do
				add("Shutters", piece("Part", Vector3.new(pw, h, 0.15), hinge * CFrame.new(-sx * (0.05 + pw / 2 + i * (pw + 0.04)), 0, 0), scaled(shutterColor, ({ 1, 0.93, 0.86 })[i + 1])))
			end
			add("Shutters", piece("Part", Vector3.new(leaf - 0.1, 0.22, 0.08), hinge * CFrame.new(-sx * leaf / 2, h * 0.3, -0.1), scaled(shutterColor, 0.82)))
			add("Shutters", piece("Part", Vector3.new(leaf - 0.1, 0.22, 0.08), hinge * CFrame.new(-sx * leaf / 2, -h * 0.3, -0.1), scaled(shutterColor, 0.82)))
			for _, y in ipairs({ -h * 0.3, h * 0.3 }) do
				add("Details", piece("Part", Vector3.new(0.6, 0.16, 0.06), hinge * CFrame.new(-sx * 0.3, y, -0.12), C.Iron))
			end
		end
	else
		for i = -1, 1 do
			add("Wood", piece("Part", Vector3.new(0.12, h, 0.12), cf * CFrame.new(i * w / 4, 0, 0.12), C.DarkWood))
		end
	end
end

-- an 8-sided frustum (apothem r0 at y0 -> r1 at y1) at cf, for pots
local function frustum8(r0: number, r1: number, y0: number, y1: number, cf: CFrame, color: Color3): BasePart
	local planes = { { 0, -1, 0, -y0 }, { 0, 1, 0, y1 } }
	for k = 0, 7 do
		local a = rad(22.5 + 45 * k)
		local nrm = Vector3.new(math.cos(a), (r0 - r1) / (y1 - y0), math.sin(a)).Unit
		table.insert(planes, { nrm.X, nrm.Y, nrm.Z, nrm:Dot(Vector3.new(math.cos(a) * r0, y0, math.sin(a) * r0)) })
	end
	local r = math.max(r0, r1) / math.cos(math.pi / 8) + 0.02
	return convexSolid(Vector3.new(-r, y0, -r), Vector3.new(r, y1, r), cf, color, planes)
end

-- a clay pot (docs B9) of width w standing at cf (its foot): body, shoulder, neck, lip, foot ring and a painted band
local function pot(list: { BasePart }, cf: CFrame, w: number, ratio: number, color: Color3, bandColor: Color3)
	local h = w * ratio
	table.insert(list, frustum8(w * 0.27, w * 0.5, 0.1, h * 0.5, cf, color))
	table.insert(list, frustum8(w * 0.5, w * 0.24, h * 0.5, h * 0.86, cf, scaled(color, 1.04)))
	table.insert(list, frustum8(w * 0.25, w * 0.25, 0, 0.12, cf, scaled(color, 0.86)))
	table.insert(list, frustum8(w * 0.515, w * 0.47, h * 0.53, h * 0.53 + 0.15, cf, bandColor))
	table.insert(list, octagon(w * 0.45, 0.3, cf * CFrame.new(0, h * 0.86 + 0.15, 0), scaled(color, 0.95)))
	table.insert(list, octagon(w * 0.55, 0.12, cf * CFrame.new(0, h * 0.86 + 0.36, 0), color))
end

-- a ladder (docs B9) from foot to top (both rail feet / tops at their middle), 2 rails 0.35, rungs every 1.1 with dark
-- lashing rings
local function ladder(list: { BasePart }, foot: Vector3, top: Vector3, width: number, side: Vector3)
	for _, s in ipairs({ -1, 1 }) do
		local o = side * (s * width / 2)
		table.insert(list, bar(foot + o, top + o, 0.35, C.Trunk))
	end
	local len = (top - foot).Magnitude
	local dir = (top - foot).Unit
	local r = 0.9
	while r < len - 0.3 do
		local c = foot + dir * r
		table.insert(list, bar(c - side * (width / 2), c + side * (width / 2), 0.25, scaled(C.Trunk, 1.08)))
		for _, s in ipairs({ -1, 1 }) do
			table.insert(list, piece("Part", Vector3.new(0.5, 0.12, 0.5), CFrame.lookAt(c + side * (s * width / 2), c + side * (s * width / 2) + dir) * CFrame.Angles(rad(90), 0, 0), C.DarkWood))
		end
		r += 1.1
	end
end

-- a drain spout (canal) through a parapet: a wooden trough sticking out 0.85, sloping 10 degrees down, a dark strip
-- on top (cf = a frame at the parapet's outer face, roof level, local -Z out)
local function spout(wood: { BasePart }, cf: CFrame, thick: number)
	local f = cf * CFrame.Angles(rad(-10), 0, 0)
	table.insert(wood, chamfered(Vector3.new(0.5, 0.4, thick + 0.85), f * CFrame.new(0, 0.2, -(0.85 - thick) / 2), C.Trunk, { "topFrontBack", "bottomFrontBack" }, 0.06))
	table.insert(wood, piece("Part", Vector3.new(0.28, 0.06, 0.85), f * CFrame.new(0, 0.41, -0.425), C.Recess))
end

local function finishModel(m: Model, propId: string, U: any, opts: { [string]: any })
	local names = {}
	for name in pairs(U) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		merge(m, name, U[name], opts[name] or {})
		task.wait()
	end
	local root = m:FindFirstChild("Walls") :: BasePart
	m.PrimaryPart = root
	root.PivotOffset = root.CFrame:Inverse()
	m:SetAttribute("MapPropId", propId)
end

-- The houses must not be climbable (today's plain walls are not): the visible unions do not collide, except the
-- door (as today) and the dome on the roof; invisible "Collision" boxes give today's wall envelope (footing, walls,
-- parapets, chimney / upper storey / cap) with smooth vertical sides, so no sill, viga, awning, spout, frame or
-- threshold can be used as a step
local HOUSE_OPTS = {
	Walls = { query = true },
	Frames = {},
	Door = { collide = true, fidelity = Enum.CollisionFidelity.Box },
	Wood = {},
	Awning = {},
	Pots = {},
	Dome = { collide = true, fidelity = Enum.CollisionFidelity.Hull },
	Shutters = {},
	Ladder = {},
	Details = {},
}

-- invisible colliding boxes { size, centre } named "Collision"
local function collisionShell(m: Model, boxes: { any })
	for _, b in ipairs(boxes) do
		local p = piece("Part", b[1], CFrame.new(b[2]), C.Clay)
		p.Name = "Collision"
		p.Transparency = 1
		p.CanCollide = true
		p.CanQuery = true
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = m
	end
end

---------------------------------------------------------------------
-- 01a ADOBE HOUSE, one storey (kit Desert.ClayHouse_A, 21 x 14.2 x 19.8; Desert_2.Decor.Village.ClayHouse_A x5).
-- Today's colours, shape and door: a wall of 6 battered plaster layers (layer lines, alternate layers proud, tone
-- steps, chipped corners, 4 patches of exposed sandstone blocks) on a wider footing of blocks, light plaster bands at
-- the lintel and under the parapet, a parapet with caps, corner merlons and a lower middle, 5 drain spouts; 5 vigas
-- front and back with carved ends and socket rings; the turquoise door (today's place and size) of planks with
-- battens, gold studs, iron hinge straps and today's gold knob, in today's terracotta frame with a wooden lintel and a
-- threshold step; the 2 windows cut 0.3 deep with terracotta frames, wooden lintels, today's sills and turquoise
-- shutters open; the red awning as pleated cloth with a tabbed valance, linen piping, struts and rope ties (raised
-- over the vigas, which it crossed); the chimney with a cap and a dark flue; a roof hatch with a ladder; clay pots on
-- the roof.
-- Parts: Walls, Frames, Door, Wood, Shutters, Awning, Pots, Ladder, Details (9; the old one had 22).
---------------------------------------------------------------------
function PropsDesert.adobe_house_a(): Model
	local m = Instance.new("Model")
	m.Name = "adobe_house_a"
	local rng = Random.new(20261101)
	H.setBevelSelf(true)
	local Ht = 14.2
	local U, add = lists()
	U.Walls = {}
	local wall = {
		x0 = -10, x1 = 10, z0 = -8, z1 = 8, y0 = 1.4, y1 = 12, base = 0, batter = 0.3, layers = 6, color = C.Clay, H = Ht,
		openings = {
			{ face = "front", u = -6.6, y = 6.6, w = 3.0, h = 3.2 },
			{ face = "front", u = 6.6, y = 6.6, w = 3.0, h = 3.2 },
		},
		chips = { { 1, 3.2, 0.6 }, { 1, 8.9, 0.5 }, { 2, 5.0, 0.55 }, { 2, 10.6, 0.6 }, { 3, 2.6, 0.5 }, { 3, 7.4, 0.65 }, { 4, 4.3, 0.6 }, { 4, 9.6, 0.5 } },
	}
	footing(U.Walls, rng, -10.5, 10.5, -8.5, 8.5, 1.4, Ht)
	adobeBlock(U.Walls, rng, wall)
	plasterBand(U.Walls, wall, 10.0, C.ClayLight)
	plasterBand(U.Walls, wall, 11.79, C.ClayLight)
	blockPatch(U.Walls, rng, faceCF(wall, "front", -8.1, 2.9, 0), Ht)
	blockPatch(U.Walls, rng, faceCF(wall, "back", 4.0, 4.0, 0), Ht)
	blockPatch(U.Walls, rng, faceCF(wall, "left", 2.0, 6.0, 0), Ht)
	blockPatch(U.Walls, rng, faceCF(wall, "right", -3.0, 3.5, 0), Ht)
	-- threshold step
	add("Walls", chamfered(Vector3.new(6.8, 0.3, 0.5), CFrame.new(0, 1.55, -8.65), C.Footing, { "topFrontBack", "topSides" }, 0.08))

	-- parapet: corner merlons 2 x 2 (0.5 higher), the runs between, the front / back middle 0.3 lower
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			parapetSeg(U.Walls, rng, CFrame.new(sx * 9.5, 12, sz * 7.5), 2.0, 1.9, 2.0, Ht)
		end
	end
	for _, sz in ipairs({ -1, 1 }) do
		local zc = sz * 7.7
		parapetSeg(U.Walls, rng, CFrame.new(-5.75, 12, zc), 5.5, 1.4, 1.6, Ht)
		parapetSeg(U.Walls, rng, CFrame.new(0, 12, zc), 6.0, 1.1, 1.6, Ht)
		parapetSeg(U.Walls, rng, CFrame.new(5.75, 12, zc), 5.5, 1.4, 1.6, Ht)
	end
	for _, sx in ipairs({ -1, 1 }) do
		parapetSeg(U.Walls, rng, CFrame.new(sx * 9.7, 12, 0) * CFrame.Angles(0, math.pi / 2, 0), 13.0, 1.4, 1.6, Ht)
	end
	U.Wood = {}
	spout(U.Wood, CFrame.new(-6.2, 12.05, -8.5), 1.6)
	spout(U.Wood, CFrame.new(-2.0, 12.05, 8.5) * CFrame.Angles(0, math.pi, 0), 1.6)
	spout(U.Wood, CFrame.new(6.2, 12.05, 8.5) * CFrame.Angles(0, math.pi, 0), 1.6)
	spout(U.Wood, CFrame.new(-10.5, 12.05, 3.0) * CFrame.Angles(0, math.pi / 2, 0), 1.6)
	spout(U.Wood, CFrame.new(10.5, 12.05, -2.0) * CFrame.Angles(0, -math.pi / 2, 0), 1.6)

	-- chimney: 2 layers, a cap, a dark flue
	add("Walls", chamfered(Vector3.new(3.0, 1.05, 3.0), CFrame.new(-5.5, 12.525, 3), soft(C.ClayLight, 12.5, Ht, 1), { "vertical" }, 0.2))
	add("Walls", chamfered(Vector3.new(2.92, 1.02, 2.92), CFrame.new(-5.5, 13.64, 3), soft(C.ClayLight, 13.6, Ht, 0.96), { "vertical" }, 0.2, nil, { piece("Part", Vector3.new(1.0, 1.2, 1.0), CFrame.new(-5.5, 14.1, 3), C.Recess) }))
	add("Walls", chamfered(Vector3.new(3.5, 0.25, 3.5), CFrame.new(-5.5, 14.275, 3), C.ClayLight, { "vertical", "topFrontBack", "topSides" }, 0.08, nil, { piece("Part", Vector3.new(1.0, 1.0, 1.0), CFrame.new(-5.5, 14.4, 3), C.Recess) }))

	-- vigas: 5 front and back, at 10.95 (above the door's lintel beam)
	U.Frames = {}
	for _, x in ipairs({ -8, -4, 0, 4, 8 }) do
		viga(U.Wood, U.Frames, rng, faceCF(wall, "front", x, 10.95, 0), Ht)
		viga(U.Wood, U.Frames, rng, faceCF(wall, "back", -x, 10.95, 0), Ht)
	end

	-- the door (today's place and size), frame, lintel beam
	U.Door, U.Details = {}, {}
	plankDoor(U.Door, U.Details, CFrame.new(0, 4.5, -8.1), 6.0, 9.0, 1.7, C.Turquoise, Vector3.new(2.0, 4.45, -8.6))
	for _, sx in ipairs({ -1, 1 }) do
		add("Frames", chamfered(Vector3.new(0.8, 9.0, 1.0), CFrame.new(sx * 3.4, 4.5, -8.2), C.Terracotta, { "frontFace" }, 0.08))
	end
	add("Frames", chamfered(Vector3.new(7.6, 1.0, 1.0), CFrame.new(0, 9.5, -8.2), C.Terracotta, { "frontFace", "topFrontBack" }, 0.08))
	add("Wood", timber(Vector3.new(8.8, 0.5, 0.5), CFrame.new(0, 10.25, -8.45), C.Trunk, 0.08))

	-- windows (today's places; the sills unchanged)
	for _, sx in ipairs({ -1, 1 }) do
		window(add, faceCF(wall, "front", sx * 6.6, 6.6, 0), 3.0, 3.2, Vector3.new(3.8, 0.5, 1.0), CFrame.new(sx * 6.6, 4.75, -8.15), C.Turquoise)
	end

	-- the red awning over the door, its back edge at 11.85 (over the vigas)
	U.Awning = {}
	awning(U.Awning, U.Wood, U.Details, faceCF(wall, "front", 0, 11.85, 0.05), 8.4, 3.3, C.Red)

	-- roof hatch with a ladder, pots on the roof (none on the ground: the village places its own jars by the doors)
	add("Walls", piece("Part", Vector3.new(2.0, 0.06, 2.0), CFrame.new(4.5, 12.03, 2.6), C.Recess))
	for _, e in ipairs({ { 0, 1.15, 2.6, 0.3 }, { 0, -1.15, 2.6, 0.3 }, { 1.15, 0, 0.3, 2.0 }, { -1.15, 0, 0.3, 2.0 } }) do
		add("Wood", timber(Vector3.new(e[3], 0.25, e[4]), CFrame.new(4.5 + e[1], 12.12, 2.6 + e[2]), C.Trunk, 0.05))
	end
	U.Ladder = {}
	ladder(U.Ladder, Vector3.new(4.5, 10.6, 2.05), Vector3.new(4.5, 15.3, 3.3), 1.1, Vector3.xAxis)
	U.Pots = {}
	pot(U.Pots, CFrame.new(-2.9, 12, 5.2), 1.3, 1.15, C.Terracotta, C.Lapis)
	pot(U.Pots, CFrame.new(-2.7, 12, 3.6) * CFrame.Angles(0, 0.6, 0), 0.95, 1.25, C.ClayLight, C.Turquoise)

	collisionShell(m, {
		{ Vector3.new(21, 1.4, 17), Vector3.new(0, 0.7, 0) },
		{ Vector3.new(20, 12, 16), Vector3.new(0, 6, 0) },
		{ Vector3.new(1.6, 1.6, 17), Vector3.new(-9.7, 12.8, 0) },
		{ Vector3.new(1.6, 1.6, 17), Vector3.new(9.7, 12.8, 0) },
		{ Vector3.new(21, 1.6, 1.6), Vector3.new(0, 12.8, -7.7) },
		{ Vector3.new(21, 1.6, 1.6), Vector3.new(0, 12.8, 7.7) },
		{ Vector3.new(3, 2.2, 3), Vector3.new(-5.5, 13.1, 3) },
		{ Vector3.new(6.0, 3.0, 0.5), Vector3.new(0, 10.5, -8.24) }, -- flush with the door above it: no ledge on its top
	})
	finishModel(m, "adobe_house_a", U, HOUSE_OPTS)
	H.setBevelSelf(false)
	return m
end

---------------------------------------------------------------------
-- 01b ADOBE HOUSE, two storeys (kit Desert.ClayHouse_B, 25 x 21.2 x 21.5; Desert_2.Decor.Village.ClayHouse_B x2).
-- Today's colours, shape and door: the lower block (5 battered layers, patches, chipped corners) on a wider footing,
-- the upper storey in light plaster (5 layers) under today's terracotta cap (now a capped slab), plaster bands, the
-- terrace parapet (today's 3 runs) with caps, merlons and spouts; 4 + 6 lower vigas (none over the door: they crossed
-- its lintel) and 3 + 3 upper ones; the turquoise plank door in today's frame with a lintel beam, a threshold and a
-- gold knob; 3 windows cut 0.3 deep with frames, lintels and today's sills: the lower left one narrowed to 2.6 and
-- moved 0.7 left (it overlapped the door frame by 0.3) with a grille, the 2 others with turquoise shutters; the blue
-- awning as pleated cloth with a tabbed valance; the dome on a drum with a terracotta base ring, 8 ribs and a taller
-- gold finial (ball, collar, spike); clay pots on the terrace; a ladder from the terrace to the roof.
-- Parts: Walls, Frames, Door, Wood, Shutters, Awning, Dome, Pots, Ladder, Details (10; the old one had 29).
---------------------------------------------------------------------
function PropsDesert.adobe_house_b(): Model
	local m = Instance.new("Model")
	m.Name = "adobe_house_b"
	local rng = Random.new(20261102)
	H.setBevelSelf(true)
	local Ht = 21.2
	local U, add = lists()
	U.Walls, U.Wood, U.Frames, U.Door, U.Details, U.Awning, U.Pots, U.Ladder = {}, {}, {}, {}, {}, {}, {}, {}
	local lower = {
		x0 = -12, x1 = 12, z0 = -9, z1 = 9, y0 = 1.4, y1 = 11, base = 0, batter = 0.3, layers = 5, color = C.Clay, H = Ht,
		openings = {
			{ face = "front", u = -9.7, y = 6.6, w = 2.6, h = 3.2 },
			{ face = "front", u = 5.5, y = 6.1, w = 3.0, h = 3.2 },
		},
		chips = { { 1, 3.4, 0.6 }, { 1, 8.4, 0.5 }, { 2, 4.6, 0.55 }, { 2, 9.6, 0.6 }, { 3, 2.8, 0.5 }, { 3, 7.0, 0.65 }, { 4, 5.2, 0.6 }, { 4, 9.2, 0.5 } },
	}
	local upper = {
		x0 = -2, x1 = 11, z0 = -4, z1 = 8, y0 = 11, y1 = 20, batter = 0.25, layers = 5, color = C.ClayLight, H = Ht,
		openings = { { face = "front", u = 4.5, y = 15.6, w = 3.0, h = 3.2 } },
		chips = { { 1, 13.4, 0.5 }, { 2, 17.2, 0.55 }, { 3, 14.6, 0.5 }, { 4, 18.4, 0.5 } },
	}
	footing(U.Walls, rng, -12.5, 12.5, -9.5, 9.5, 1.4, Ht)
	adobeBlock(U.Walls, rng, lower)
	adobeBlock(U.Walls, rng, upper)
	plasterBand(U.Walls, lower, 10.0, C.ClayLight)
	plasterBand(U.Walls, lower, 10.79, C.ClayLight)
	plasterBand(U.Walls, upper, 19.6, scaled(C.ClayLight, 1.04))
	blockPatch(U.Walls, rng, faceCF(lower, "front", 9.9, 2.7, 0), Ht)
	blockPatch(U.Walls, rng, faceCF(lower, "left", -2.0, 5.5, 0), Ht)
	blockPatch(U.Walls, rng, faceCF(lower, "right", 3.0, 7.4, 0), Ht)
	blockPatch(U.Walls, rng, faceCF(lower, "back", 6.0, 4.0, 0), Ht)
	blockPatch(U.Walls, rng, faceCF(lower, "back", -7.0, 7.6, 0), Ht)
	blockPatch(U.Walls, rng, faceCF(upper, "front", 8.9, 12.6, 0), Ht)
	blockPatch(U.Walls, rng, faceCF(upper, "right", 4.0, 16.0, 0), Ht)
	add("Walls", chamfered(Vector3.new(6.8, 0.3, 0.5), CFrame.new(-4, 1.55, -9.65), C.Footing, { "topFrontBack", "topSides" }, 0.08))
	-- the cap of the upper storey (today's terracotta slab, now a capped edge in 2 layers)
	add("Walls", chamfered(Vector3.new(14.0, 0.95, 13.0), CFrame.new(4.5, 20.475, 2), scaled(C.Terracotta, 0.96), { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.15))
	add("Walls", chamfered(Vector3.new(13.4, 0.25, 12.4), CFrame.new(4.5, 21.075, 2), C.Terracotta, { "vertical", "topFrontBack", "topSides" }, 0.1))

	-- the terrace parapet: today's 3 runs (front, left, back-left), merlons at the corners and the right end
	parapetSeg(U.Walls, rng, CFrame.new(-11.5, 11, -8.5), 2.0, 1.75, 2.0, Ht)
	parapetSeg(U.Walls, rng, CFrame.new(11.5, 11, -8.5), 2.0, 1.75, 2.0, Ht)
	parapetSeg(U.Walls, rng, CFrame.new(-11.5, 11, 8.5), 2.0, 1.75, 2.0, Ht)
	parapetSeg(U.Walls, rng, CFrame.new(-7.25, 11, -8.7), 6.5, 1.3, 1.6, Ht)
	parapetSeg(U.Walls, rng, CFrame.new(-1.0, 11, -8.7), 6.0, 1.0, 1.6, Ht)
	parapetSeg(U.Walls, rng, CFrame.new(6.25, 11, -8.7), 8.5, 1.3, 1.6, Ht)
	parapetSeg(U.Walls, rng, CFrame.new(-11.7, 11, 0) * CFrame.Angles(0, math.pi / 2, 0), 15.0, 1.3, 1.6, Ht)
	parapetSeg(U.Walls, rng, CFrame.new(-6.0, 11, 8.7), 9.0, 1.3, 1.6, Ht)
	spout(U.Wood, CFrame.new(0.9, 11.05, -9.5), 1.6)
	spout(U.Wood, CFrame.new(8.5, 11.05, -9.5), 1.6)
	spout(U.Wood, CFrame.new(-12.5, 11.05, 0.5) * CFrame.Angles(0, math.pi / 2, 0), 1.6)
	spout(U.Wood, CFrame.new(-6.0, 11.05, 9.5) * CFrame.Angles(0, math.pi, 0), 1.6)

	-- vigas: lower front (not over the door), lower back, upper front and back
	for _, x in ipairs({ -10, 2, 6, 10 }) do
		viga(U.Wood, U.Frames, rng, faceCF(lower, "front", x, 9.8, 0), Ht)
	end
	for _, x in ipairs({ -10, -6, -2, 2, 6, 10 }) do
		viga(U.Wood, U.Frames, rng, faceCF(lower, "back", x, 9.8, 0), Ht)
	end
	for _, x in ipairs({ 0.5, 4.5, 8.5 }) do
		viga(U.Wood, U.Frames, rng, faceCF(upper, "front", x, 18.6, 0), Ht)
		viga(U.Wood, U.Frames, rng, faceCF(upper, "back", 9 - x, 18.6, 0), Ht)
	end

	-- the door (today's place and size), frame, lintel beam
	plankDoor(U.Door, U.Details, CFrame.new(-4, 4.5, -9.1), 6.0, 9.0, 1.7, C.Turquoise, Vector3.new(-2.0, 4.45, -9.6))
	for _, x in ipairs({ -7.4, -0.6 }) do
		add("Frames", chamfered(Vector3.new(0.8, 9.0, 1.0), CFrame.new(x, 4.5, -9.2), C.Terracotta, { "frontFace" }, 0.08))
	end
	add("Frames", chamfered(Vector3.new(7.6, 1.0, 1.0), CFrame.new(-4, 9.5, -9.2), C.Terracotta, { "frontFace", "topFrontBack" }, 0.08))
	add("Wood", timber(Vector3.new(8.8, 0.5, 0.5), CFrame.new(-4, 10.25, -9.45), C.Trunk, 0.08))

	-- windows: lower left (narrowed, grille), lower right and upper (shutters); today's sills (the left one 3.2 long)
	window(add, faceCF(lower, "front", -9.7, 6.6, 0), 2.6, 3.2, Vector3.new(3.2, 0.5, 1.0), CFrame.new(-9.7, 4.75, -9.15), nil)
	window(add, faceCF(lower, "front", 5.5, 6.1, 0), 3.0, 3.2, Vector3.new(3.8, 0.5, 1.0), CFrame.new(5.5, 4.25, -9.15), C.Turquoise)
	window(add, faceCF(upper, "front", 4.5, 15.6, 0), 3.0, 3.2, Vector3.new(3.8, 0.5, 1.0), CFrame.new(4.5, 13.75, -4.15), C.Turquoise)

	-- the blue awning over the lower right window (under the vigas)
	awning(U.Awning, U.Wood, U.Details, faceCF(lower, "front", 5.5, 9.1, 0.05), 7.0, 3.2, C.Blue)

	-- the dome: drum, terracotta base ring, the linen dome with 8 ribs, the gold finial (ball, collar, spike)
	local dc = Vector3.new(-6.5, 0, 1)
	add("Walls", prism16(8.4, 0.8, CFrame.new(dc + Vector3.new(0, 11.4, 0)), C.ClayLight))
	add("Frames", prism16(8.3, 0.3, CFrame.new(dc + Vector3.new(0, 11.95, 0)), C.Terracotta))
	U.Dome = {}
	local dome = piece("Part", Vector3.new(8, 8, 8), CFrame.new(dc + Vector3.new(0, 12.0, 0)), C.Linen, { shape = Enum.PartType.Ball })
	table.insert(U.Dome, dome)
	for k = 0, 3 do
		local ball = piece("Part", Vector3.new(8.16, 8.16, 8.16), CFrame.new(dc + Vector3.new(0, 12.0, 0)), scaled(C.Linen, 0.86), { shape = Enum.PartType.Ball })
		local slab = piece("Part", Vector3.new(0.2, 9, 9), CFrame.new(dc + Vector3.new(0, 12.0, 0)) * CFrame.Angles(0, rad(45 * k), 0), scaled(C.Linen, 0.86))
		local ok, res = pcall(function()
			return GeometryService:IntersectAsync(ball, { slab }, { CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Automatic })
		end)
		ball:Destroy()
		slab:Destroy()
		if ok and res and res[1] then
			local rib = res[1] :: BasePart
			rib.Color = scaled(C.Linen, 0.86)
			table.insert(U.Dome, rib)
		end
	end
	add("Details", piece("Part", Vector3.new(0.7, 0.7, 0.7), CFrame.new(dc + Vector3.new(0, 16.25, 0)), C.Gold, { shape = Enum.PartType.Ball }))
	add("Details", octagon(0.42, 0.3, CFrame.new(dc + Vector3.new(0, 16.72, 0)), C.Gold))
	do
		local planes = {}
		H.pyramidPlanes(Vector3.new(0, 1.25, 0), { Vector3.new(0.16, 0, 0.16), Vector3.new(-0.16, 0, 0.16), Vector3.new(-0.16, 0, -0.16), Vector3.new(0.16, 0, -0.16) }, Vector3.new(0, 0.3, 0), { C.Gold, scaled(C.Gold, 0.9) }, planes)
		table.insert(planes, { 0, -1, 0, 0 })
		add("Details", convexSolid(Vector3.new(-0.18, 0, -0.18), Vector3.new(0.18, 1.25, 0.18), CFrame.new(dc + Vector3.new(0, 16.86, 0)), C.Gold, planes))
	end

	-- pots on the terrace (none on the ground: the village places its own jars by the doors); the ladder from the
	-- terrace to the upper roof
	pot(U.Pots, CFrame.new(-10.0, 11, -7.0), 1.3, 1.15, C.Terracotta, C.Lapis)
	pot(U.Pots, CFrame.new(-8.6, 11, -7.2) * CFrame.Angles(0, 0.5, 0), 0.95, 1.25, C.ClayLight, C.Turquoise)
	pot(U.Pots, CFrame.new(-9.9, 11, 6.8), 1.2, 1.1, C.Terracotta, C.Linen)
	ladder(U.Ladder, Vector3.new(9.65, 11.0, -7.7), Vector3.new(9.65, 22.2, -4.45), 1.2, Vector3.xAxis)

	collisionShell(m, {
		{ Vector3.new(25, 1.4, 19), Vector3.new(0, 0.7, 0) },
		{ Vector3.new(24, 11, 18), Vector3.new(0, 5.5, 0) },
		{ Vector3.new(1.6, 1.5, 19), Vector3.new(-11.7, 11.75, 0) },
		{ Vector3.new(10.5, 1.5, 1.6), Vector3.new(-6.7, 11.75, 8.7) },
		{ Vector3.new(25, 1.5, 1.6), Vector3.new(0, 11.75, -8.7) },
		{ Vector3.new(13, 9, 12), Vector3.new(4.5, 15.5, 2) },
		{ Vector3.new(14, 1.2, 13), Vector3.new(4.5, 20.6, 2) },
		{ Vector3.new(6.0, 2.0, 0.5), Vector3.new(-4, 10.0, -9.24) }, -- flush with the door above it: no ledge on its top
	})
	finishModel(m, "adobe_house_b", U, HOUSE_OPTS)
	H.setBevelSelf(false)
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the fresh PropsBatch2 table; its install() builds them
---------------------------------------------------------------------
PropsDesert.BUILDERS = {
	adobe_house_a = true, adobe_house_b = true,
}
for id in pairs(PropsDesert.BUILDERS) do
	B2[id] = (PropsDesert :: any)[id]
	B2.BUILDERS[id] = true
end
PropsDesert.install = B2.install
PropsDesert.stats = B2.stats

return PropsDesert
