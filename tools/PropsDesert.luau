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
-- shared (02-05): today's collision envelopes. Every visible union of these props is non-colliding; one invisible
-- union "Collision" (precise) rebuilds today's colliding parts, so each prop is exactly as walkable / climbable as
-- today (the pilot's rule). Data = today's colliding parts of the kits (shape, size, CFrame components relative to
-- the pivot), read from ServerStorage.MapAssets.Desert on 2026-10-19.
---------------------------------------------------------------------
PropsDesert.ENVELOPES = {
	market_stall = { -- MarketStall_A: posts, counter, top, awning strips, back, shelf (its goods were steps: dropped)
		{ "Block", 0.7, 7.4, 0.7, { -5.6, 3.7, -3.4, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 0.7, 9.4, 0.7, { -5.6, 4.7, 3.4, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 0.7, 7.4, 0.7, { 5.6, 3.7, -3.4, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 0.7, 9.4, 0.7, { 5.6, 4.7, 3.4, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 11.6, 3.2, 2.2, { 0, 1.6, -2.8, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 12.2, 0.4, 2.9, { 0, 3.4, -2.8, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 12.3, 0.3, 8.6, { 0, 8.4, 0, 1, 0, 0, 0, 0.9744, 0.225, 0, -0.225, 0.9744 } },
		{ "Block", 11.6, 5, 0.4, { 0, 2.5, 3.4, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 11, 0.4, 1.6, { 0, 4.6, 2.6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	},
	canopy_pavilion = { -- NomadTent_B
		{ "Block", 0.7, 7, 0.7, { -6, 3.5, -6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 0.7, 7, 0.7, { -6, 3.5, 6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 0.7, 7, 0.7, { 6, 3.5, -6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 0.7, 7, 0.7, { 6, 3.5, 6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 0.8, 12.4, 0.8, { 0, 6.2, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "CornerWedgePart", 7, 5.2, 7, { -3.5, 9.6, 3.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "CornerWedgePart", 7, 5.2, 7, { 3.5, 9.6, 3.5, 0, 0, 1, 0, 1, 0, -1, 0, 0 } },
		{ "CornerWedgePart", 7, 5.2, 7, { 3.5, 9.6, -3.5, -1, 0, 0, 0, 1, 0, 0, 0, -1 } },
		{ "CornerWedgePart", 7, 5.2, 7, { -3.5, 9.6, -3.5, 0, 0, -1, 0, 1, 0, 1, 0, 0 } },
		{ "Block", 14.2, 1, 0.3, { 0, 6.6, -7, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 14.2, 1, 0.3, { 0, 6.6, 7, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 0.3, 1, 14.2, { -7, 6.6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 0.3, 1, 14.2, { 7, 6.6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 12.6, 6.2, 0.3, { 0, 3.1, 6.2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 0.3, 6.2, 7, { -6.2, 3.1, 2.8, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 0.3, 6.2, 7, { 6.2, 3.1, 2.8, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 0.9, 0.9, 0.9, { 0, 12.65, 0, 0.7071, 0, 0.7071, 0, 1, 0, -0.7071, 0, 0.7071 } },
	},
	desert_tent = { -- NomadTent_A (the entrance is closed today: kept)
		{ "WedgePart", 12, 8, 5.5, { -2.75, 4, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0 } },
		{ "WedgePart", 12, 8, 5.5, { 2.75, 4, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0 } },
		{ "WedgePart", 0.2, 6, 3, { -1.5, 3, -6.05, 0, 0, 1, 0, 1, 0, -1, 0, 0 } },
		{ "WedgePart", 0.2, 6, 3, { 1.5, 3, -6.05, 0, 0, -1, 0, 1, 0, 1, 0, 0 } },
		{ "WedgePart", 0.8, 8.15, 5.6, { -2.77, 4.06, -5.7, 0, 0, 1, 0, 1, 0, -1, 0, 0 } },
		{ "WedgePart", 0.8, 8.15, 5.6, { 2.77, 4.06, -5.7, 0, 0, -1, 0, 1, 0, 1, 0, 0 } },
		{ "Block", 0.5, 0.5, 14, { 0, 8.1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 0.5, 8.6, 0.5, { 0, 4.3, -6.6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 0.5, 8.6, 0.5, { 0, 4.3, 6.6, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	},
	ruined_wall = { -- Sandstone_Wall_Ruin (as climbable as today)
		{ "Block", 7, 12, 3, { -6.5, 6, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 6, 8.5, 3, { 0, 4.25, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 7, 5, 3, { 6.5, 2.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 20.4, 1.4, 3.6, { 0, 0.7, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 7.4, 1, 3.6, { -6.5, 12.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 3, 2, 3, { -1.5, 9.5, 0, 0.9781, 0, 0.2079, 0, 1, 0, -0.2079, 0, 0.9781 } },
		{ "Block", 4, 2.4, 3, { 5, 1.2, -4, 0.9063, 0, 0.4226, 0, 1, 0, -0.4226, 0, 0.9063 } },
		{ "Block", 3, 2, 0.3, { -6.5, 7, -1.55, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
		{ "Block", 1, 3, 0.3, { -6.5, 4, -1.55, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	},
}

local function envelope(m: Model, id: string)
	local list = {}
	for _, e in ipairs(PropsDesert.ENVELOPES[id]) do
		local cf = CFrame.new(table.unpack(e[5]))
		local size = Vector3.new(e[2], e[3], e[4])
		if e[1] == "WedgePart" or e[1] == "CornerWedgePart" then
			table.insert(list, piece(e[1], size, cf, C.Clay))
		else
			table.insert(list, piece("Part", size, cf, C.Clay, { shape = (Enum.PartType :: any)[e[1]] }))
		end
	end
	merge(m, "Collision", list, { collide = true, fidelity = Enum.CollisionFidelity.PreciseConvexDecomposition, transparency = 1, shadow = false })
end

local function finishVisual(m: Model, propId: string, U: any, root: string, queryNames: { [string]: boolean })
	local names = {}
	for name in pairs(U) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local opts: any = { query = queryNames[name] == true }
		if name == "Glass" then
			opts.material = Enum.Material.Neon
			opts.shadow = false
		end
		merge(m, name, U[name], opts)
		task.wait()
	end
	local r = m:FindFirstChild(root) :: BasePart
	m.PrimaryPart = r
	r.PivotOffset = r.CFrame:Inverse()
	m:SetAttribute("MapPropId", propId)
end

local SAND, SAND_DARK = rgb(244, 208, 124), rgb(214, 168, 96)
local COUNTER, COUNTER_TOP, RUG = rgb(168, 98, 56), rgb(214, 150, 92), rgb(188, 65, 54)
local RED_ALT = rgb(193, 66, 56)

---------------------------------------------------------------------
-- 02 MARKET STALL (kit Desert.MarketStall_A, 12.3 x 9.5 x 8.5; Desert_2.Decor.Village x4; no prompt / NPC / shop).
-- Today's colours and layout, like its sibling stalls: posts on sandstone footing blocks, front and back beams and 3
-- rafters, the 6 red / linen strips of the awning as cloth with a sag at the middle, a front valance of tabs with gold
-- tassels between them and a dark binding; a counter of vertical planks over a dark core with a kick board, a top rail
-- and end stiles, a top of 3 planks; a back wall of planks with 2 battens, a plank shelf on brackets; the goods: today's
-- 3 jars as clay pots with painted bands on the shelf, a tray of faceted fruit (green / gold / red), the blue and gold
-- cloths as folded stacks with a blue cloth draped over the counter front.
-- Parts: Wood, Cloth, Goods, Collision (4; the old one had 23).
---------------------------------------------------------------------
function PropsDesert.market_stall(): Model
	local m = Instance.new("Model")
	m.Name = "market_stall"
	local rng = Random.new(20261103)
	H.setBevelSelf(true)
	local Ht = 9.5
	local U, add = lists()
	-- posts on footing blocks
	for _, p in ipairs({ { -5.6, -3.4, 7.4 }, { 5.6, -3.4, 7.4 }, { -5.6, 3.4, 9.4 }, { 5.6, 3.4, 9.4 } }) do
		add("Wood", chamfered(Vector3.new(1.0, 0.4, 1.0), CFrame.new(p[1], 0.2, p[2]), C.Sandstone, { "vertical", "topFrontBack", "topSides" }, 0.1))
		local h = p[3] - 0.4
		add("Wood", timber(Vector3.new(0.8, h, 0.8), CFrame.new(p[1], 0.4 + h / 2, p[2]), soft(C.Trunk, p[3] / 2, Ht, TONES[rng:NextInteger(1, 3)]), 0.12))
	end
	-- beams and rafters under the cloth
	add("Wood", timber(Vector3.new(12.2, 0.4, 0.45), CFrame.new(0, 7.2, -3.4), C.Trunk, 0.08))
	add("Wood", timber(Vector3.new(12.2, 0.4, 0.45), CFrame.new(0, 9.2, 3.4), C.Trunk, 0.08))
	for _, x in ipairs({ -5.6, 0, 5.6 }) do
		add("Wood", bar(Vector3.new(x, 9.3, 3.9), Vector3.new(x, 7.36, -3.9), 0.3, scaled(C.Trunk, 0.92)))
	end
	for _, sx in ipairs({ -1, 1 }) do
		add("Goods", piece("Part", Vector3.new(0.45, 0.45, 0.45), CFrame.new(sx * 6.35, 7.2, -3.4), C.Gold, { shape = Enum.PartType.Ball }))
	end
	-- the awning: 6 strips (today's colours), each 2 halves with a sag
	local stripes = { { -5.12, C.Red }, { -3.07, C.Linen }, { -1.02, C.Red }, { 1.03, C.Linen }, { 3.08, C.Red }, { 5.13, C.Linen } }
	for i, s in ipairs(stripes) do
		local x = s[1]
		local B, F = Vector3.new(x, 9.42, 4.25), Vector3.new(x, 7.5, -4.25)
		local M = (B + F) / 2 - Vector3.new(0, 0.22, 0)
		for _, seg in ipairs({ { B, M }, { M, F } }) do
			local a, b = seg[1], seg[2]
			add("Cloth", piece("Part", Vector3.new(2.03, 0.15, (b - a).Magnitude + 0.06), CFrame.lookAt((a + b) / 2, b), scaled(s[2], if i % 2 == 0 then 1 else 0.98)))
		end
		add("Cloth", chamfered(Vector3.new(2.0, 0.75, 0.12), CFrame.new(x, 7.05, -4.27), s[2], { "bottomSides" }, 0.34))
	end
	add("Cloth", piece("Part", Vector3.new(12.4, 0.16, 0.2), CFrame.new(0, 7.47, -4.28), scaled(C.Red, 0.78)))
	for k = 0, 6 do
		local x = -6.15 + k * 2.05
		add("Goods", piece("Part", Vector3.new(0.1, 0.45, 0.1), CFrame.new(x, 7.2, -4.35), C.Gold))
		add("Goods", chamfered(Vector3.new(0.26, 0.42, 0.26), CFrame.new(x, 6.8, -4.35), C.Gold, { "bottomFrontBack", "bottomSides" }, 0.08))
	end
	-- the counter
	add("Wood", piece("Part", Vector3.new(11.3, 2.9, 1.9), CFrame.new(0, 1.6, -2.8), scaled(COUNTER, 0.6)))
	local prev = nil
	for i = 0, 8 do
		local ti = toneIndex(rng, prev)
		prev = ti
		add("Wood", chamfered(Vector3.new(1.22, 2.6, 0.25), CFrame.new(-4.94 + i * 1.235, 1.75, -3.78), soft(COUNTER, 1.7, Ht, TONES[ti]), { "vertical" }, 0.05))
	end
	add("Wood", timber(Vector3.new(11.7, 0.45, 0.32), CFrame.new(0, 0.225, -3.83), scaled(COUNTER, 0.78), 0.06))
	add("Wood", timber(Vector3.new(11.7, 0.3, 0.3), CFrame.new(0, 3.05, -3.84), scaled(COUNTER, 0.9), 0.06))
	for _, sx in ipairs({ -1, 1 }) do
		add("Wood", chamfered(Vector3.new(0.45, 3.2, 2.25), CFrame.new(sx * 5.75, 1.6, -2.8), scaled(COUNTER, 0.86), { "vertical" }, 0.08))
	end
	for k = -1, 1 do
		add("Wood", chamfered(Vector3.new(12.2, 0.4, 0.93), CFrame.new(0, 3.4, -2.8 + k * 0.97), scaled(COUNTER_TOP, TONES[(k + 3) % 3 + 1]), { "topFrontBack", "topSides" }, 0.08))
	end
	-- the back wall of planks with battens, the shelf on brackets
	prev = nil
	for i = 0, 7 do
		local ti = toneIndex(rng, prev)
		prev = ti
		add("Wood", chamfered(Vector3.new(1.42, 5.0, 0.35), CFrame.new(-5.075 + i * 1.45, 2.5, 3.42), soft(C.DarkWood, 2.5, Ht, TONES[ti]), { "vertical" }, 0.04))
	end
	for _, y in ipairs({ 1.1, 3.9 }) do
		add("Wood", timber(Vector3.new(11.4, 0.35, 0.15), CFrame.new(0, y, 3.17), scaled(C.DarkWood, 0.85), 0.04))
	end
	add("Wood", chamfered(Vector3.new(11.0, 0.3, 1.6), CFrame.new(0, 4.6, 2.6), scaled(COUNTER, 1.04), { "topFrontBack", "topSides" }, 0.06))
	for _, x in ipairs({ -4.6, 0, 4.6 }) do
		add("Wood", bar(Vector3.new(x, 3.6, 3.15), Vector3.new(x, 4.42, 2.0), 0.22, C.DarkWood))
	end
	-- goods: today's jars as pots on the shelf
	pot(U.Goods, CFrame.new(-3.8, 4.75, 2.6), 1.4, 1.1, C.Terracotta, C.Lapis)
	pot(U.Goods, CFrame.new(-1.8, 4.75, 2.6) * CFrame.Angles(0, 0.5, 0), 1.2, 1.2, C.Clay, C.Turquoise)
	pot(U.Goods, CFrame.new(3.5, 4.75, 2.6), 1.5, 1.05, C.Turquoise, C.Gold)
	-- the tray of fruit (today's Tray place)
	add("Wood", chamfered(Vector3.new(2.4, 0.45, 1.8), CFrame.new(-3.6, 3.83, -2.8), C.DarkWood, { "topFrontBack", "topSides" }, 0.06, nil, { piece("Part", Vector3.new(2.1, 0.4, 1.5), CFrame.new(-3.6, 4.05, -2.8), scaled(C.DarkWood, 0.7)) }))
	local fruitCols = { rgb(76, 164, 84), C.Gold, C.Red }
	for k = 0, 6 do
		local fx = -4.35 + (k % 4) * 0.5 + (if k >= 4 then 0.25 else 0)
		local fz = -2.8 + (if k % 2 == 0 then -0.3 else 0.3)
		local fy = if k >= 4 then 4.55 else 4.2
		add("Goods", H.fruitPiece(0.55, CFrame.new(fx, fy, fz) * CFrame.Angles(0, k * 0.7, 0), fruitCols[k % 3 + 1]))
	end
	-- the cloths: folded stacks (blue, gold) and a blue cloth draped over the counter front
	for k = 0, 2 do
		add("Cloth", chamfered(Vector3.new(3.0 - k * 0.15, 0.16, 2.0 - k * 0.1), CFrame.new(2.5, 3.68 + k * 0.17, -2.8), scaled(C.Blue, ({ 1, 0.92, 1.05 })[k + 1]), { "topFrontBack", "bottomFrontBack" }, 0.07))
	end
	for k = 0, 2 do
		add("Cloth", chamfered(Vector3.new(1.6 - k * 0.1, 0.15, 1.4 - k * 0.08), CFrame.new(2.6, 4.2 + k * 0.16, -2.8), scaled(C.Gold, ({ 1, 0.93, 1 })[k + 1]), { "topFrontBack", "bottomFrontBack" }, 0.06))
	end
	add("Cloth", piece("Part", Vector3.new(1.3, 1.5, 0.08), CFrame.new(1.2, 2.85, -4.02), C.Blue))
	add("Cloth", piece("Part", Vector3.new(1.3, 0.12, 0.6), CFrame.new(1.2, 3.62, -3.75), C.Blue))
	add("Cloth", piece("Part", Vector3.new(1.3, 0.14, 0.09), CFrame.new(1.2, 2.17, -4.03), C.Gold))

	envelope(m, "market_stall")
	finishVisual(m, "market_stall", U, "Wood", { Wood = true })
	H.setBevelSelf(false)
	return m
end

---------------------------------------------------------------------
-- 03 CANOPY PAVILION (kit Desert.NomadTent_B, 14.3 x 13.1 x 14.3; Desert_1.Decor.Camps). Today's colours, size and
-- walk-under height: a canopy of 8 gores (today's red / blue quarters) with gold piping on the hips and linen piping on
-- the middle seams, a linen valance with a gold trim and scalloped tabs, gold tassels at the corners; 4 corner posts
-- (base blocks, octagonal shafts, dark bands, rope wraps, carved caps), the centre pole with bands, a gold collar, ball
-- and spike finial; the back (red) and side (blue) walls as pleated curtains, the sides gathered at their front edge
-- with a rope tie; the red rug with a gold border band, today's gold diamond with a red heart, fringes; 4 cushions with
-- buttons; a small lantern hanging from the centre pole (warm glass, a soft light).
-- Parts: Canopy, Trim, Curtains, Wood, Rug, Glass, Collision (7; the old one had 19).
---------------------------------------------------------------------
function PropsDesert.canopy_pavilion(): Model
	local m = Instance.new("Model")
	m.Name = "canopy_pavilion"
	local rng = Random.new(20261104)
	H.setBevelSelf(true)
	local Ht = 13.1
	local U = lists()
	U.Canopy, U.Trim = {}, {}
	-- the canopy: 8 gores from the apex to the eave square (today's surface)
	local A = Vector3.new(0, 12.2, 0)
	local corners = { Vector3.new(-7, 7, -7), Vector3.new(7, 7, -7), Vector3.new(7, 7, 7), Vector3.new(-7, 7, 7) }
	local function quadColor(c: Vector3): Color3
		return if (c.X < 0) == (c.Z < 0) then C.Red else C.Blue
	end
	for i = 1, 4 do
		local c1, c2 = corners[i], corners[i % 4 + 1]
		local mid = (c1 + c2) / 2
		local tone = if i % 2 == 0 then 0.94 else 1
		H.triangleParts(U.Canopy, A, c1, mid, 0.18, CFrame.identity, scaled(quadColor(c1), tone))
		H.triangleParts(U.Canopy, A, mid, c2, 0.18, CFrame.identity, scaled(quadColor(c2), tone * 0.97))
		table.insert(U.Trim, bar(A + Vector3.new(0, 0.12, 0), c1 + Vector3.new(0, 0.12, 0), 0.16, C.Gold))
		table.insert(U.Trim, bar(A + Vector3.new(0, 0.12, 0), mid + Vector3.new(0, 0.12, 0), 0.14, C.Linen))
	end
	-- valance: band, gold trim, scalloped tabs, corner tassels
	for _, side in ipairs({ { 0, -7.06, 0 }, { 0, 7.06, 0 }, { -7.06, 0, 1 }, { 7.06, 0, 1 } }) do
		local turn = if side[3] == 1 then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity
		local base = CFrame.new(side[1], 0, side[2]) * turn
		table.insert(U.Trim, piece("Part", Vector3.new(14.3, 0.7, 0.12), base * CFrame.new(0, 6.75, 0), C.Linen))
		table.insert(U.Trim, piece("Part", Vector3.new(14.4, 0.12, 0.18), base * CFrame.new(0, 7.06, 0), C.Gold))
		table.insert(U.Trim, piece("Part", Vector3.new(14.4, 0.1, 0.16), base * CFrame.new(0, 6.42, 0), C.Gold))
		for k = 0, 9 do
			table.insert(U.Trim, chamfered(Vector3.new(1.32, 0.55, 0.12), base * CFrame.new(-6.3 + k * 1.4, 6.12, 0), scaled(C.Linen, 0.95), { "bottomSides" }, 0.27))
		end
	end
	for _, c in ipairs(corners) do
		local p = Vector3.new(c.X * 1.012, 0, c.Z * 1.012)
		table.insert(U.Trim, piece("Part", Vector3.new(0.1, 0.7, 0.1), CFrame.new(p + Vector3.new(0, 6.35, 0)), C.Gold))
		table.insert(U.Trim, piece("Part", Vector3.new(0.34, 0.34, 0.34), CFrame.new(p + Vector3.new(0, 5.95, 0)), C.Gold, { shape = Enum.PartType.Ball }))
		table.insert(U.Trim, chamfered(Vector3.new(0.3, 0.4, 0.3), CFrame.new(p + Vector3.new(0, 5.62, 0)), C.Gold, { "bottomFrontBack", "bottomSides" }, 0.09))
	end
	-- posts
	U.Wood = {}
	for _, c in ipairs(corners) do
		local x, z = c.X * 6 / 7, c.Z * 6 / 7
		table.insert(U.Wood, chamfered(Vector3.new(1.15, 0.5, 1.15), CFrame.new(x, 0.25, z), C.Footing, { "vertical", "topFrontBack", "topSides" }, 0.12))
		table.insert(U.Wood, octagon(0.75, 6.0, CFrame.new(x, 3.5, z), soft(C.Trunk, 3.5, Ht, TONES[rng:NextInteger(1, 3)])))
		for _, y in ipairs({ 1.0, 5.3 }) do
			table.insert(U.Wood, octagon(0.92, 0.22, CFrame.new(x, y, z), C.DarkWood))
		end
		table.insert(U.Wood, octagon(0.88, 0.3, CFrame.new(x, 6.15, z), C.Rope))
		table.insert(U.Wood, chamfered(Vector3.new(1.0, 0.45, 1.0), CFrame.new(x, 6.75, z), scaled(C.Trunk, 0.9), { "vertical", "bottomFrontBack", "bottomSides" }, 0.12))
	end
	table.insert(U.Wood, octagon(0.8, 12.15, CFrame.new(0, 6.225, 0), C.Trunk))
	for _, y in ipairs({ 1.2, 4.6, 8.0 }) do
		table.insert(U.Wood, octagon(0.98, 0.22, CFrame.new(0, y, 0), C.DarkWood))
	end
	table.insert(U.Trim, octagon(0.62, 0.35, CFrame.new(0, 12.35, 0), C.Gold))
	table.insert(U.Trim, piece("Part", Vector3.new(0.75, 0.75, 0.75), CFrame.new(0, 12.85, 0), C.Gold, { shape = Enum.PartType.Ball }))
	do
		local planes = {}
		H.pyramidPlanes(Vector3.new(0, 0.85, 0), { Vector3.new(0.17, 0, 0.17), Vector3.new(-0.17, 0, 0.17), Vector3.new(-0.17, 0, -0.17), Vector3.new(0.17, 0, -0.17) }, Vector3.new(0, 0.2, 0), { C.Gold, scaled(C.Gold, 0.9) }, planes)
		table.insert(planes, { 0, -1, 0, 0 })
		table.insert(U.Trim, convexSolid(Vector3.new(-0.19, 0, -0.19), Vector3.new(0.19, 0.85, 0.19), CFrame.new(0, 13.15, 0), C.Gold, planes))
	end
	-- curtains: back (red) and sides (blue), pleated; the sides gathered at their front with a rope tie
	U.Curtains = {}
	for k = 0, 11 do
		local x = -5.775 + k * 1.05
		table.insert(U.Curtains, piece("Part", Vector3.new(1.08, 6.0, 0.15), CFrame.new(x, 3.1, 6.2 + (if k % 2 == 0 then 0.08 else -0.08)), scaled(C.Red, if k % 2 == 0 then 1 else 0.9)))
	end
	for _, sx in ipairs({ -1, 1 }) do
		for k = 0, 5 do
			local z = 5.7 - k * 1.1
			table.insert(U.Curtains, piece("Part", Vector3.new(0.15, 6.0, 1.13), CFrame.new(sx * (6.2 + (if k % 2 == 0 then 0.08 else -0.08)), 3.1, z), scaled(C.Blue, if k % 2 == 0 then 1 else 0.9)))
		end
		for j = 0, 2 do
			table.insert(U.Curtains, octagon(0.55 - j * 0.08, 5.9, CFrame.new(sx * (6.2 + (j - 1) * 0.12), 3.1, -0.45 - j * 0.12), scaled(C.Blue, 0.95 - j * 0.04)))
		end
		table.insert(U.Wood, octagon(0.85, 0.16, CFrame.new(sx * 6.2, 3.3, -0.57), C.Rope))
		table.insert(U.Wood, bar(Vector3.new(sx * 6.2, 3.25, -0.95), Vector3.new(sx * 6.25, 2.5, -1.05), 0.1, C.Rope))
	end
	-- the rug: red, gold border band, today's gold diamond with a red heart, fringes; cushions
	U.Rug = {}
	table.insert(U.Rug, piece("Part", Vector3.new(9, 0.15, 9), CFrame.new(0, 0.075, 0), RUG))
	for _, b in ipairs({ { 0, -3.8, 7.6, 0.6 }, { 0, 3.8, 7.6, 0.6 }, { -3.8, 0, 0.6, 7.0 }, { 3.8, 0, 0.6, 7.0 } }) do
		table.insert(U.Rug, piece("Part", Vector3.new(b[3], 0.04, b[4]), CFrame.new(b[1], 0.165, b[2]), C.Gold))
	end
	table.insert(U.Rug, piece("Part", Vector3.new(4.2, 0.04, 4.2), CFrame.new(0, 0.17, 0) * CFrame.Angles(0, rad(45), 0), C.Gold))
	table.insert(U.Rug, piece("Part", Vector3.new(2.2, 0.04, 2.2), CFrame.new(0, 0.19, 0) * CFrame.Angles(0, rad(45), 0), scaled(RUG, 0.9)))
	for _, sz in ipairs({ -1, 1 }) do
		for k = 0, 13 do
			table.insert(U.Rug, piece("Part", Vector3.new(0.14, 0.05, 0.45), CFrame.new(-4.2 + k * 0.646, 0.03, sz * 4.7), C.Linen))
		end
	end
	local cushion = { { -2.3, -2.6, C.Blue, 0.3 }, { 2.4, -2.4, C.Gold, -0.4 }, { 2.6, 2.3, C.Red, 0.6 }, { -2.5, 2.4, C.Linen, -0.2 } }
	for _, c in ipairs(cushion) do
		local cf = CFrame.new(c[1], 0.43, c[2]) * CFrame.Angles(0, c[4], 0)
		table.insert(U.Rug, chamfered(Vector3.new(1.7, 0.56, 1.7), cf, c[3], { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.2))
		table.insert(U.Rug, piece("Part", Vector3.new(0.2, 0.08, 0.2), cf * CFrame.new(0, 0.3, 0), C.Gold))
	end
	-- the lantern on a bracket from the centre pole
	table.insert(U.Wood, bar(Vector3.new(0.3, 7.6, 0), Vector3.new(1.35, 7.6, 0), 0.12, C.Iron))
	table.insert(U.Wood, piece("Part", Vector3.new(0.06, 0.5, 0.06), CFrame.new(1.3, 7.3, 0), C.Iron))
	local lf = CFrame.new(1.3, 6.6, 0)
	table.insert(U.Wood, octagon(0.7, 0.12, lf * CFrame.new(0, 0.48, 0), C.Gold))
	table.insert(U.Wood, octagon(0.4, 0.14, lf * CFrame.new(0, 0.6, 0), C.Gold))
	table.insert(U.Wood, octagon(0.7, 0.12, lf * CFrame.new(0, -0.48, 0), C.Gold))
	for q = 0, 3 do
		local a = rad(45 + 90 * q)
		table.insert(U.Wood, piece("Part", Vector3.new(0.07, 0.9, 0.07), lf * CFrame.new(math.cos(a) * 0.3, 0, math.sin(a) * 0.3), C.Gold))
	end
	U.Glass = { piece("Part", Vector3.new(0.45, 0.8, 0.45), lf, rgb(255, 200, 115)) }

	envelope(m, "canopy_pavilion")
	finishVisual(m, "canopy_pavilion", U, "Wood", { Wood = true })
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color, light.Shadows = 10, 0.5, rgb(255, 200, 120), false
	light.Parent = m:FindFirstChild("Glass")
	H.setBevelSelf(false)
	return m
end

---------------------------------------------------------------------
-- 04 TENT (kit Desert.NomadTent_A, 11.1 x 8.6 x 14; Desert_1.Decor.Camps x2, Desert_3.Decor.Camp). Today's shape,
-- colours and entrance: each side 4 canvas panels from the ridge to the ground (today's red / darker red, tone steps),
-- raised seams, a darker hem and a ridge fold; the back gable in canvas with a seam; the front gable: the 2 flaps
-- folded back showing today's gold lining, red bindings, rolled flap edges tied with ropes around the dark doorway;
-- the dark wood poles with gold ball caps and today's ridge pole; guy ropes to wooden stakes front, back and on both
-- sides; a small striped rug at the doorway; a low sand drift along one side.
-- Parts: Canvas, Lining, Wood, Ground, Collision (5; the old one had 9).
---------------------------------------------------------------------
function PropsDesert.desert_tent(): Model
	local m = Instance.new("Model")
	m.Name = "desert_tent"
	H.setBevelSelf(true)
	local U, add = lists()
	U.Canvas, U.Lining = {}, {}
	local slopeLen = math.sqrt(5.5 ^ 2 + 8 ^ 2)
	for _, side in ipairs({ { -1, C.Red }, { 1, RED_ALT } }) do
		local sx = side[1]
		local u = Vector3.new(-sx * 5.5, 8, 0).Unit -- base -> ridge
		local n = Vector3.new(sx * 8, 5.5, 0).Unit -- outward
		local mid = Vector3.new(sx * 2.75, 4, 0)
		for k = 0, 3 do
			local z = -4.5 + k * 3
			local c = mid + Vector3.new(0, 0, z) + n * 0.08
			add("Canvas", piece("Part", Vector3.new(3.0, slopeLen + 0.1, 0.15), CFrame.fromMatrix(c, Vector3.zAxis, u), scaled(side[2], if k % 2 == 0 then 1 else 0.93)))
		end
		for _, z in ipairs({ -3, 0, 3 }) do
			add("Canvas", piece("Part", Vector3.new(0.12, slopeLen, 0.06), CFrame.fromMatrix(mid + Vector3.new(0, 0, z) + n * 0.18, Vector3.zAxis, u), scaled(side[2], 0.8)))
		end
		local base = Vector3.new(sx * 5.5, 0, 0)
		add("Canvas", piece("Part", Vector3.new(12.0, 0.3, 0.07), CFrame.fromMatrix(base + u * 0.2 + n * 0.19, Vector3.zAxis, u), scaled(side[2], 0.82)))
		add("Canvas", piece("Part", Vector3.new(12.1, 0.45, 0.08), CFrame.fromMatrix(Vector3.new(0, 8, 0) - u * 0.25 + n * 0.2, Vector3.zAxis, u), scaled(side[2], 0.86)))
	end
	-- back gable with a seam
	H.triangleParts(U.Canvas, Vector3.new(-5.5, 0, 6.05), Vector3.new(5.5, 0, 6.05), Vector3.new(0, 8, 6.05), 0.15, CFrame.identity, scaled(RED_ALT, 0.95))
	add("Canvas", piece("Part", Vector3.new(0.12, 7.9, 0.06), CFrame.new(0, 3.95, 6.14), scaled(RED_ALT, 0.8)))
	-- front gable: gold lining (the flaps folded back) left and right of the doorway, bindings, rolled edges, ties
	for _, sx in ipairs({ -1, 1 }) do
		H.triangleParts(U.Lining, Vector3.new(sx * 5.5, 0, -6.05), Vector3.new(sx * 3.0, 0, -6.05), Vector3.new(0, 8, -6.05), 0.15, CFrame.identity, C.Gold)
		H.triangleParts(U.Lining, Vector3.new(sx * 3.0, 0, -6.05), Vector3.new(0, 6, -6.05), Vector3.new(0, 8, -6.05), 0.15, CFrame.identity, scaled(C.Gold, 0.93))
		add("Canvas", bar(Vector3.new(sx * 5.5, 0.05, -6.12), Vector3.new(0, 8.0, -6.12), 0.24, scaled(if sx < 0 then C.Red else RED_ALT, 0.85)))
		local a, b = Vector3.new(sx * 3.15, 0.2, -6.25), Vector3.new(sx * 0.15, 5.85, -6.25)
		local dir = (b - a).Unit
		add("Canvas", octagon(0.5, (b - a).Magnitude, CFrame.fromMatrix((a + b) / 2, Vector3.zAxis:Cross(dir).Unit, dir), if sx < 0 then C.Red else RED_ALT))
		for _, f in ipairs({ 0.35, 0.7 }) do
			local p = a:Lerp(b, f)
			add("Wood", octagon(0.62, 0.14, CFrame.fromMatrix(p, Vector3.zAxis:Cross(dir).Unit, dir), C.Rope))
		end
	end
	-- the dark doorway
	H.triangleParts(U.Lining, Vector3.new(-3, 0, -5.6), Vector3.new(3, 0, -5.6), Vector3.new(0, 6, -5.6), 0.12, CFrame.identity, scaled(C.DarkWood, 0.55))
	-- poles, ridge, gold caps, guy ropes and stakes
	for _, z in ipairs({ -6.6, 6.6 }) do
		add("Wood", timber(Vector3.new(0.5, 8.6, 0.5), CFrame.new(0, 4.3, z), C.DarkWood, 0.08))
		add("Lining", piece("Part", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 8.75, z), C.Gold, { shape = Enum.PartType.Ball }))
		for _, sx in ipairs({ -1, 1 }) do
			local stake = Vector3.new(sx * 2.2, 0.35, z + (if z < 0 then -0.55 else 0.55))
			add("Wood", bar(Vector3.new(0, 8.3, z), stake + Vector3.new(0, 0.3, 0), 0.12, C.Rope))
			add("Wood", piece("Part", Vector3.new(0.25, 0.8, 0.25), CFrame.new(stake) * CFrame.Angles(if z < 0 then rad(-25) else rad(25), 0, 0), C.Trunk))
		end
	end
	add("Wood", timber(Vector3.new(0.5, 0.5, 14), CFrame.new(0, 8.1, 0), scaled(C.DarkWood, 1.06), 0.08))
	for _, sx in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -3, 3 }) do
			local onSlope = Vector3.new(sx * 3.35, 3.1, z)
			local stake = Vector3.new(sx * 5.7, 0.35, z)
			add("Wood", bar(onSlope, stake + Vector3.new(0, 0.3, 0), 0.12, C.Rope))
			add("Wood", piece("Part", Vector3.new(0.25, 0.8, 0.25), CFrame.new(stake) * CFrame.Angles(0, 0, sx * rad(25)), C.Trunk))
		end
	end
	-- the rug at the doorway, a sand drift along the right side
	U.Ground = {}
	table.insert(U.Ground, piece("Part", Vector3.new(3.4, 0.12, 2.2), CFrame.new(0, 0.06, -6.2), RUG))
	for _, x in ipairs({ -1.2, 1.2 }) do
		table.insert(U.Ground, piece("Part", Vector3.new(0.3, 0.03, 2.2), CFrame.new(x, 0.13, -6.2), C.Gold))
	end
	table.insert(U.Ground, piece("Part", Vector3.new(0.5, 0.03, 0.5), CFrame.new(0, 0.13, -6.2) * CFrame.Angles(0, rad(45), 0), C.Blue))
	local drift = piece("WedgePart", Vector3.new(9.0, 0.7, 1.1), CFrame.new(5.45, 0.35, 0.5) * CFrame.Angles(0, rad(-90), 0), SAND)
	table.insert(U.Ground, drift)
	table.insert(U.Ground, piece("WedgePart", Vector3.new(8.0, 0.35, 0.6), CFrame.new(5.8, 0.17, 0.5) * CFrame.Angles(0, rad(-90), 0), SAND_DARK))

	envelope(m, "desert_tent")
	finishVisual(m, "desert_tent", U, "Wood", { Canvas = true })
	H.setBevelSelf(false)
	return m
end

---------------------------------------------------------------------
-- 05 RUINED WALL (kit Desert.Sandstone_Wall_Ruin, 20.4 x 13 x 8; Desert_2.Decor.Village, Desert_3.Decor.Ruins x2).
-- Today's footprint, steps and colours, in real blocks: a footing of slabs, the 3 wall pieces (12 / 8.5 / 5 high) in
-- courses of cut sandstone blocks (running bond, 0.09 joints over a dark core, chamfers, tone steps, gradient), a broken
-- top (missing blocks, the last blocks turned and slid out, a cracked block per piece), today's cap on the tall piece
-- broken off at one end, today's 2 loose blocks (one on the middle piece, one fallen in front, cracked), 5 rubble
-- blocks half in the sand; today's 2 plaques as carved glyph plaques (frame, recessed panel, raised glyphs: an eye, wavy
-- water, a bird, an ankh; a lapis and a gold inlay); sand drifts along the foot. Collisions = today's (as climbable).
-- Parts: Walls, Glyphs, Sand, Collision (4; the old one had 9).
---------------------------------------------------------------------
function PropsDesert.ruined_wall(): Model
	local m = Instance.new("Model")
	m.Name = "ruined_wall"
	local rng = Random.new(20261106)
	H.setBevelSelf(true)
	local Ht = 13
	local U, add = lists()
	local CORE = scaled(C.Footing, 0.8)
	local MID = rgb(215, 181, 126)
	local BLOCK = rgb(210, 177, 123)
	-- footing slabs
	add("Walls", piece("Part", Vector3.new(20.0, 1.36, 3.2), CFrame.new(0, 0.68, 0), CORE))
	do
		local x, prev = -10.2, nil
		while x < 10.19 do
			local xe = math.min(x + rng:NextNumber(2.8, 4.0), 10.2)
			if 10.2 - xe < 1.5 then
				xe = 10.2
			end
			local ti = toneIndex(rng, prev)
			prev = ti
			add("Walls", chamfered(Vector3.new(xe - x - 0.09, 1.4, 3.6), CFrame.new((x + xe) / 2, 0.7, 0), soft(C.Footing, 0.7, Ht, TONES[ti]), { "topFrontBack", "topSides", "vertical" }, 0.15))
			x = xe
		end
	end
	-- the 3 pieces in courses; the top course broken (a gap, a turned / slid last block); one cracked block each
	-- the middle piece loses the right end of its top course (a step down to the low piece; its loose block stays
	-- supported), the low piece a block in the middle of its top course and its last block is turned and slid out
	local pieces = { { -10, -3, 12, C.Sandstone, 8 }, { -3, 3, 8.5, MID, 5 }, { 3, 10, 5, C.Sandstone, 3 } }
	for pi, s in ipairs(pieces) do
		local x0, x1, top, color, n = s[1], s[2], s[3], s[4], s[5]
		local ch = (top - 1.4) / n
		-- the core stops under the top course of the broken pieces (their missing blocks are real notches)
		local coreTop = top - (if pi > 1 then ch else 0)
		add("Walls", piece("Part", Vector3.new(x1 - x0 - 0.3, coreTop - 1.4, 2.6), CFrame.new((x0 + x1) / 2, (1.4 + coreTop) / 2, 0), CORE))
		local prev = nil
		local offset = rng:NextNumber(0.6, 1.2)
		for k = 0, n - 1 do
			local y0 = 1.4 + k * ch
			local bh = ch - 0.05
			local yc = y0 + 0.025 + bh / 2
			local x = x0 - (if k % 2 == 1 then offset else 0)
			local isTop = k == n - 1
			local idx = 0
			while x < x1 - 0.05 do
				local xe = math.min(x + rng:NextNumber(2.0, 3.4), x1)
				if x1 - xe < 1.0 then
					xe = x1
				end
				local a = math.max(x, x0)
				idx += 1
				local len = xe - a - 0.09
				local skip = isTop and ((pi == 2 and xe >= x1) or (pi == 3 and idx == 2))
				if len > 0.4 and not skip then
					local ti = toneIndex(rng, prev)
					prev = ti
					local cf = CFrame.new((a + xe) / 2 - 0.045, yc, rng:NextNumber(-0.04, 0.04))
					local last = isTop and xe >= x1 and pi == 3
					if last then
						cf = cf * CFrame.new(0.12, 0, -0.15) * CFrame.Angles(0, rad(4), rad(-5))
					end
					add("Walls", chamfered(Vector3.new(len, bh, 3.0), cf, soft(color, yc, Ht, TONES[ti]), { "vertical", "topFrontBack", "topSides" }, 0.18))
					if k == math.floor(n / 2) and idx == 2 then
						-- a crack across the block's front face
						add("Walls", piece("Part", Vector3.new(0.09, bh * 0.85, 0.06), cf * CFrame.new(0, 0, -1.49) * CFrame.Angles(0, 0, rad(18)), CORE))
					end
				end
				x = xe
			end
		end
	end
	-- today's cap on the tall piece, broken off at its right end
	add("Walls", chamfered(Vector3.new(5.7, 0.95, 3.6), CFrame.new(-7.35, 12.475, 0), soft(C.Footing, 12.5, Ht, 1), { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.15))
	add("Walls", chamfered(Vector3.new(1.45, 0.9, 3.5), CFrame.new(-3.75, 12.4, -0.05) * CFrame.Angles(rad(2), rad(-4), rad(-7)), soft(C.Footing, 12.4, Ht, 0.93), { "vertical", "topFrontBack", "topSides" }, 0.15))
	-- today's loose blocks: on the middle piece, and fallen in front (cracked)
	add("Walls", chamfered(Vector3.new(3, 2, 3), CFrame.new(-1.5, 9.5, 0) * CFrame.Angles(0, rad(12), 0), soft(C.Sandstone, 9.5, Ht, 0.93), { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.22))
	add("Walls", chamfered(Vector3.new(4, 2.4, 3), CFrame.new(5, 1.05, -4) * CFrame.Angles(0, rad(25), rad(3)), BLOCK, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.25, nil, { piece("Part", Vector3.new(0.09, 3.0, 3.4), CFrame.new(5, 1.05, -4) * CFrame.Angles(0, rad(25), rad(-20)), CORE) }))
	-- rubble half in the sand
	for _, r in ipairs({ { -8.6, -2.7, 1.2, 20 }, { -2.4, -2.5, 0.9, -15 }, { 8.6, -2.6, 1.4, 30 }, { 1.5, 2.15, 0.9, 12 }, { -6.0, 2.2, 0.8, -25 } }) do
		local s = r[3]
		add("Walls", chamfered(Vector3.new(s * 1.3, s, s), CFrame.new(r[1], s * 0.5 - 0.3, r[2]) * CFrame.Angles(rad(r[4] * 0.5), rad(r[4] * 2), rad(r[4])), scaled(BLOCK, TONES[rng:NextInteger(1, 3)]), { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, s * 0.18))
	end
	-- the 2 glyph plaques (today's places on the tall piece's front face)
	U.Glyphs = {}
	local GLYPH = scaled(C.Footing, 0.78)
	local function plaque(cx: number, cy: number, w: number, h: number): CFrame
		local face = -1.5
		table.insert(U.Glyphs, piece("Part", Vector3.new(w, h, 0.14), CFrame.new(cx, cy, face - 0.02), scaled(C.Footing, 0.92)))
		for _, e in ipairs({ { 0, h / 2 - 0.125, w, 0.25 }, { 0, -h / 2 + 0.125, w, 0.25 }, { -w / 2 + 0.125, 0, 0.25, h - 0.5 }, { w / 2 - 0.125, 0, 0.25, h - 0.5 } }) do
			table.insert(U.Glyphs, chamfered(Vector3.new(e[3], e[4], 0.2), CFrame.new(cx + e[1], cy + e[2], face - 0.1), C.Footing, { "frontFace" }, 0.05))
		end
		return CFrame.new(cx, cy, face - 0.12)
	end
	local p1 = plaque(-6.5, 7, 3, 2)
	-- the eye (almond, lapis pupil), wavy water, a bird
	table.insert(U.Glyphs, chamfered(Vector3.new(0.9, 0.38, 0.08), p1 * CFrame.new(-0.7, 0.3, 0), GLYPH, { "vertical" }, 0.14))
	table.insert(U.Glyphs, piece("Part", Vector3.new(0.2, 0.2, 0.08), p1 * CFrame.new(-0.7, 0.3, -0.03), C.Lapis))
	table.insert(U.Glyphs, piece("Part", Vector3.new(0.5, 0.08, 0.08), p1 * CFrame.new(-0.85, 0.02, 0) * CFrame.Angles(0, 0, rad(-25)), GLYPH))
	for row = 0, 1 do
		for k = 0, 3 do
			table.insert(U.Glyphs, piece("Part", Vector3.new(0.3, 0.08, 0.08), p1 * CFrame.new(-1.05 + k * 0.28, -0.45 - row * 0.25, 0) * CFrame.Angles(0, 0, rad(if k % 2 == 0 then 30 else -30)), GLYPH))
		end
	end
	table.insert(U.Glyphs, chamfered(Vector3.new(0.5, 0.3, 0.08), p1 * CFrame.new(0.65, 0.05, 0), GLYPH, { "vertical" }, 0.1))
	table.insert(U.Glyphs, piece("Part", Vector3.new(0.18, 0.18, 0.08), p1 * CFrame.new(0.95, 0.3, 0), GLYPH))
	table.insert(U.Glyphs, piece("Part", Vector3.new(0.18, 0.06, 0.08), p1 * CFrame.new(1.1, 0.3, 0), C.Gold))
	table.insert(U.Glyphs, piece("Part", Vector3.new(0.35, 0.1, 0.08), p1 * CFrame.new(0.4, 0.05, 0) * CFrame.Angles(0, 0, rad(20)), GLYPH))
	table.insert(U.Glyphs, piece("Part", Vector3.new(0.06, 0.3, 0.08), p1 * CFrame.new(0.6, -0.25, 0), GLYPH))
	table.insert(U.Glyphs, piece("Part", Vector3.new(0.06, 0.3, 0.08), p1 * CFrame.new(0.75, -0.25, 0), GLYPH))
	local p2 = plaque(-6.5, 4, 1, 3)
	-- the ankh and a gold sun
	for _, e in ipairs({ { 0, 0.75, 0.36, 0.08 }, { 0, 0.35, 0.36, 0.08 }, { -0.17, 0.55, 0.08, 0.4 }, { 0.17, 0.55, 0.08, 0.4 } }) do
		table.insert(U.Glyphs, piece("Part", Vector3.new(e[3], e[4], 0.08), p2 * CFrame.new(e[1], e[2], 0), GLYPH))
	end
	table.insert(U.Glyphs, piece("Part", Vector3.new(0.4, 0.08, 0.08), p2 * CFrame.new(0, 0.2, 0), GLYPH))
	table.insert(U.Glyphs, piece("Part", Vector3.new(0.08, 0.95, 0.08), p2 * CFrame.new(0, -0.3, 0), GLYPH))
	table.insert(U.Glyphs, octagon(0.32, 0.08, p2 * CFrame.new(0, -0.95, 0) * CFrame.Angles(rad(90), 0, 0), C.Gold))
	-- sand drifts along the foot (front and back), a crest on each
	U.Sand = {}
	for _, d in ipairs({ { -7.0, -1, 5.5, 0.9, 1.3 }, { 2.2, -1, 4.5, 0.7, 1.1 }, { -2.5, 1, 6.0, 0.7, 0.5 }, { 6.8, 1, 4.0, 0.55, 0.5 } }) do
		local x, side, len, h, depth = d[1], d[2], d[3], d[4], d[5]
		local z = side * (1.8 + depth / 2)
		local turn = if side < 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
		table.insert(U.Sand, piece("WedgePart", Vector3.new(len, h, depth), CFrame.new(x, h / 2 + 0.02, z) * turn, SAND))
		table.insert(U.Sand, piece("Part", Vector3.new(len * 0.9, h * 0.8, h * 0.8), CFrame.new(x, h * 0.45, side * (1.8 + h * 0.3)), SAND, { shape = Enum.PartType.Cylinder }))
		table.insert(U.Sand, piece("WedgePart", Vector3.new(len * 0.8, h * 0.4, depth * 0.5), CFrame.new(x, h * 0.2, z + side * depth * 0.3) * turn, SAND_DARK))
	end
	-- a drift around the fallen block
	table.insert(U.Sand, piece("WedgePart", Vector3.new(3.0, 0.6, 1.0), CFrame.new(5.0, 0.3, -4.9) * CFrame.Angles(0, rad(25 + 180), 0), SAND))

	envelope(m, "ruined_wall")
	finishVisual(m, "ruined_wall", U, "Walls", { Walls = true })
	H.setBevelSelf(false)
	return m
end

---------------------------------------------------------------------
-- DESERT GATES (owner, 2026-10-19): docs/Desert_Images/02_Gates_and_Entrances. Same collision rule as the buildings:
-- the visible unions do not collide; one invisible "Collision" union rebuilds today's colliding parts.
---------------------------------------------------------------------
PropsDesert.ENVELOPES.egyptian_arch = { -- EntryArch_Desert: every part (all collide today)
	{ "Block", 5, 18, 5, { -14.5, 9, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 6.6, 2, 6.6, { -14.5, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 5.3, 1, 5.3, { -14.5, 6.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 5.3, 1, 5.3, { -14.5, 13.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "CornerWedgePart", 2, 3.4, 2, { -18, 24.2, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "CornerWedgePart", 2, 3.4, 2, { -16, 24.2, 1, 0, 0, 1, 0, 1, 0, -1, 0, 0 } },
	{ "CornerWedgePart", 2, 3.4, 2, { -16, 24.2, -1, -1, 0, 0, 0, 1, 0, 0, 0, -1 } },
	{ "CornerWedgePart", 2, 3.4, 2, { -18, 24.2, -1, 0, 0, -1, 0, 1, 0, 1, 0, 0 } },
	{ "Block", 2.6, 7, 0.2, { -8.5, 14.5, -2.2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 2.6, 1, 0.2, { -8.5, 10.7, -2.2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 1, 1.4, 2, { -14.5, 8.3, -3.3, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 2.2, 0.7, 2.2, { -14.5, 9.35, -4, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 1.6, 0.6, 1.6, { -14.5, 9.9, -4, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 5, 18, 5, { 14.5, 9, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 6.6, 2, 6.6, { 14.5, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 5.3, 1, 5.3, { 14.5, 6.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 5.3, 1, 5.3, { 14.5, 13.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "CornerWedgePart", 2, 3.4, 2, { 16, 24.2, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "CornerWedgePart", 2, 3.4, 2, { 18, 24.2, 1, 0, 0, 1, 0, 1, 0, -1, 0, 0 } },
	{ "CornerWedgePart", 2, 3.4, 2, { 18, 24.2, -1, -1, 0, 0, 0, 1, 0, 0, 0, -1 } },
	{ "CornerWedgePart", 2, 3.4, 2, { 16, 24.2, -1, 0, 0, -1, 0, 1, 0, 1, 0, 0 } },
	{ "Block", 2.6, 7, 0.2, { 8.5, 14.5, -2.2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 2.6, 1, 0.2, { 8.5, 10.7, -2.2, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 1, 1.4, 2, { 14.5, 8.3, -3.3, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 2.2, 0.7, 2.2, { 14.5, 9.35, -4, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 1.6, 0.6, 1.6, { 14.5, 9.9, -4, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 36, 3.5, 5.6, { 0, 19.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 36, 0.8, 5.9, { 0, 19.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 38.5, 1, 6.8, { 0, 22, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 16.4, 5.2, 1.6, { 0, 25.1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 17.4, 0.8, 2.2, { 0, 28.1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 14, 4, 0.5, { 0, 25.1, -0.9, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
	{ "Block", 14, 4, 0.5, { 0, 25.1, 0.9, 1, 0, 0, 0, 1, 0, 0, 0, 1 } },
}

-- a band of inlay around a square pier (w across, h tall, centre height y): the band in `color`, 0.15 proud, with a row
-- of small inlaid diamonds / squares in `accent` on each of its 4 faces
local function inlayBand(list: { BasePart }, cx: number, y: number, w: number, h: number, color: Color3, accent: Color3, diamonds: boolean)
	table.insert(list, chamfered(Vector3.new(w, h, w), CFrame.new(cx, y, 0), color, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.08))
	if color ~= C.Gold then
		-- 0.12 gold rules above and below the band
		for _, sy in ipairs({ -1, 1 }) do
			table.insert(list, piece("Part", Vector3.new(w + 0.08, 0.12, w + 0.08), CFrame.new(cx, y + sy * (h / 2 + 0.06), 0), C.Gold))
		end
	end
	for face = 0, 3 do
		local turn = CFrame.new(cx, y, 0) * CFrame.Angles(0, face * math.pi / 2, 0)
		for k = -1, 1 do
			local cf = turn * CFrame.new(k * w / 3.2, 0, -w / 2 - 0.02)
			if diamonds then
				cf *= CFrame.Angles(0, 0, rad(45))
			end
			local s = h * (if diamonds then 0.42 else 0.5)
			table.insert(list, piece("Part", Vector3.new(s, s, 0.1), cf, accent))
		end
	end
end

---------------------------------------------------------------------
-- 01 EGYPTIAN ARCH (kit Gates.EntryArch_Desert, 38.5 x 28.5 x 8.5; Zones.Desert.Desert_1.EntryArch, attr ZoneId; its
-- NameSign carries the NameGuiFront / Back "Desert", moved onto the new NameSign by SyncMapProps). Today's layout,
-- passage and colours: stepped bases (footing slabs and a chamfered plinth), the 2 piers in courses of cut sandstone
-- blocks (alternating joints, chamfers, tone steps) with today's gold and lapis bands as inlay bands with diamonds /
-- squares and a turquoise capital band; the lintel of 5 cut blocks with today's turquoise band as an inlay band
-- (lapis squares, gold dots); a cavetto cornice (a roll moulding and 3 slabs flaring out); today's golden pyramid tips
-- as faceted pyramids on plinths with a glowing pyramidion and a soft light; the name board: lapis back in a gold
-- frame, today's sandstone NameSign / SignRear plates, the gold cap with a small sun disc; the 2 red banners as pleated
-- cloth on gold rods with gold side trims, today's gold tail band, a pointed end and a gold tassel; the 2 lamps (iron
-- scroll brackets, brass bowls with a rim, a Neon flame "Ember" with today's PointLight 14 / 1 / FFD678 and FirePoint);
-- small sand drifts at the bases.
-- Parts: Stone, Inlay, Gold, Cloth, Iron, Ember x2, Glow, NameSign, SignRear, Sand, Collision.
---------------------------------------------------------------------
function PropsDesert.egyptian_arch(): Model
	local m = Instance.new("Model")
	m.Name = "egyptian_arch"
	local rng = Random.new(20261110)
	H.setBevelSelf(true)
	local Ht = 28.5
	local U, add = lists()
	U.Inlay, U.Iron = {}, {}
	local GAP_D = 0.09
	local BRASS = rgb(201, 154, 46)
	local SAND_DARK2 = C.Footing
	local MORTAR = scaled(C.Footing, 0.72)
	for _, sx in ipairs({ -1, 1 }) do
		local cx = sx * 14.5
		-- stepped base: 4 slabs, a chamfered plinth
		local prev = nil
		for _, ix in ipairs({ -1, 1 }) do
			for _, iz in ipairs({ -1, 1 }) do
				local ti = toneIndex(rng, prev)
				prev = ti
				add("Stone", chamfered(Vector3.new(3.33, 0.8, 3.33), CFrame.new(cx + ix * 1.71, 0.4, iz * 1.71), soft(SAND_DARK2, 0.4, Ht, TONES[ti]), { "vertical", "topFrontBack", "topSides" }, 0.12))
			end
		end
		add("Stone", piece("Part", Vector3.new(6.6, 0.76, 6.6), CFrame.new(cx, 0.4, 0), MORTAR))
		add("Stone", chamfered(Vector3.new(6.2, 1.2, 6.2), CFrame.new(cx, 1.4, 0), soft(SAND_DARK2, 1.4, Ht, 1.04), { "vertical", "topFrontBack", "topSides" }, 0.22))
		-- the pier: courses of 2 blocks (split along X, then along Z) over a core; today's gold band (6 .. 7) and lapis
		-- band (13 .. 14) as inlay bands; a turquoise capital band and an abacus under the lintel
		add("Stone", piece("Part", Vector3.new(4.5, 16, 4.5), CFrame.new(cx, 10, 0), MORTAR))
		local courses = { { 2.0, 1.4 }, { 3.4, 1.4 }, { 4.8, 1.2 }, { 6.0, 1.0, "gold" }, { 7.0, 1.5 }, { 8.5, 1.5 }, { 10.0, 1.5 }, { 11.5, 1.5 }, { 13.0, 1.0, "lapis" }, { 14.0, 1.6 }, { 15.6, 1.65 } }
		for ci, c in ipairs(courses) do
			local y0, h = c[1], c[2]
			local yc = y0 + h / 2
			if c[3] == "gold" then
				inlayBand(U.Inlay, cx, yc, 5.3, 1.0, C.Gold, C.Lapis, true)
			elseif c[3] == "lapis" then
				inlayBand(U.Inlay, cx, yc, 5.3, 1.0, C.Lapis, C.Gold, false)
			else
				local alongX = ci % 2 == 0
				local split = rng:NextNumber(-0.6, 0.6)
				for _, half in ipairs({ -1, 1 }) do
					local a = if half < 0 then -2.5 else split + GAP_D / 2
					local b = if half < 0 then split - GAP_D / 2 else 2.5
					local len = b - a
					local mid = (a + b) / 2
					local size = if alongX then Vector3.new(len, h - 0.05, 5) else Vector3.new(5, h - 0.05, len)
					local cf = if alongX then CFrame.new(cx + mid, yc, 0) else CFrame.new(cx, yc, mid)
					add("Stone", chamfered(size, cf, soft(C.Sandstone, yc, Ht, TONES[rng:NextInteger(1, 3)]), { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.14))
				end
			end
		end
		inlayBand(U.Inlay, cx, 17.55, 5.4, 0.6, C.Turquoise, C.Gold, false)
		add("Stone", chamfered(Vector3.new(5.6, 0.16, 5.6), CFrame.new(cx, 17.93, 0), C.Footing, { "vertical" }, 0.05))
	end
	-- the lintel: 5 cut blocks over a core, today's turquoise band as an inlay band with lapis squares and gold dots
	add("Stone", piece("Part", Vector3.new(35.6, 2.4, 5.2), CFrame.new(0, 19.25, 0), MORTAR))
	do
		local edges = { -18, -10.6, -3.4, 3.6, 10.8, 18 }
		local prev = nil
		for i = 1, 5 do
			local a, b = edges[i] + (if i > 1 then GAP_D / 2 else 0), edges[i + 1] - (if i < 5 then GAP_D / 2 else 0)
			local ti = toneIndex(rng, prev)
			prev = ti
			add("Stone", chamfered(Vector3.new(b - a, 2.5, 5.6), CFrame.new((a + b) / 2, 19.25, 0), soft(C.Sandstone, 19.25, Ht, TONES[ti]), { "vertical", "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }, 0.16))
		end
	end
	add("Inlay", piece("Part", Vector3.new(36.1, 0.8, 5.8), CFrame.new(0, 19.6, 0), C.Turquoise))
	for _, y in ipairs({ 19.14, 20.06 }) do
		add("Gold", piece("Part", Vector3.new(36.15, 0.12, 5.86), CFrame.new(0, y, 0), C.Gold))
	end
	for _, z in ipairs({ -2.97, 2.97 }) do
		for k = 0, 16 do
			local x = -16 + k * 2
			if k % 2 == 0 then
				add("Inlay", piece("Part", Vector3.new(0.5, 0.5, 0.08), CFrame.new(x, 19.6, z * 0.985) * CFrame.Angles(0, 0, rad(45)), C.Lapis))
			else
				add("Inlay", piece("Part", Vector3.new(0.28, 0.28, 0.08), CFrame.new(x, 19.6, z * 0.985), C.Gold))
			end
		end
	end
	-- the cavetto cornice: a roll moulding, 3 slabs flaring out, a top fillet (today's 38.5 x 1 x 6.8 at 21.5 .. 22.5)
	-- the cavetto cornice (B12): a torus roll, a fillet, a cove of 3 slabs stepping out on a concave curve with wedges
	-- filling the steps, a flat top slab; 2.05 tall (20.5 .. 22.55), 0.8 of projection over the 5.6 lintel
	add("Stone", piece("Part", Vector3.new(36.0, 0.25, 5.6), CFrame.new(0, 20.62, 0), MORTAR))
	for _, z in ipairs({ -2.85, 2.85 }) do
		add("Stone", octagon(0.55, 36.2, CFrame.new(0, 20.78, z) * CFrame.Angles(0, 0, rad(90)), scaled(C.Footing, 1.08)))
	end
	add("Stone", piece("Part", Vector3.new(36.6, 0.25, 6.0), CFrame.new(0, 21.17, 0), soft(C.Footing, 21.1, Ht, 0.95)))
	local cove = { { 21.45, 0.3, 37.0, 6.12 }, { 21.75, 0.3, 37.4, 6.4 }, { 22.0, 0.2, 37.9, 6.84 } }
	for i, f in ipairs(cove) do
		add("Stone", piece("Part", Vector3.new(f[3], f[2], f[4]), CFrame.new(0, f[1], 0), soft(C.Footing, f[1], Ht, ({ 0.92, 0.96, 1.0 })[i])))
	end
	for _, sz in ipairs({ -1, 1 }) do
		local turn = if sz < 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
		add("Stone", piece("WedgePart", Vector3.new(37.8, 0.8, 0.44), CFrame.new(0, 21.7, sz * 3.2) * turn * CFrame.Angles(math.pi, 0, 0), soft(C.Footing, 21.7, Ht, 0.98)))
		-- reed grooves on the cove face, every 0.8
		for k = -22, 22 do
			add("Stone", piece("Part", Vector3.new(0.1, 0.62, 0.06), CFrame.new(k * 0.8, 21.62, sz * 3.25) * CFrame.Angles(sz * rad(-28), 0, 0), scaled(C.Footing, 0.86)))
		end
	end
	add("Stone", chamfered(Vector3.new(38.5, 0.4, 7.04), CFrame.new(0, 22.35, 0), soft(C.Footing, 22.35, Ht, 1.05), { "vertical", "topFrontBack", "topSides" }, 0.08))
	-- the golden pyramid tips (today's at x +-17, base 4 x 4, top 25.9): a plinth, a faceted pyramid, a glowing pyramidion
	for _, sx in ipairs({ -1, 1 }) do
		local cx = sx * 17
		add("Stone", chamfered(Vector3.new(4.4, 0.15, 4.4), CFrame.new(cx, 22.62, 0), C.Footing, { "vertical", "topFrontBack", "topSides" }, 0.05))
		add("Stone", chamfered(Vector3.new(4.15, 0.15, 4.15), CFrame.new(cx, 22.77, 0), scaled(C.Footing, 1.05), { "vertical", "topFrontBack", "topSides" }, 0.05))
		-- today's tip (4 x 4 base, 3.4 tall): the lower 60 % gold, the top 40 % Neon gold
		local apex = Vector3.new(0, 26.25, 0)
		local split = 22.85 + 3.4 * 0.6
		local function pyramid(y0: number, y1: number, material: Enum.Material?): BasePart
			local planes = { { 0, -1, 0, -y0 }, { 0, 1, 0, y1 } }
			for k = 0, 3 do
				local a = k * math.pi / 2
				local d = Vector3.new(math.cos(a), 0, math.sin(a))
				local n = (d * 3.4 + Vector3.new(0, 2.0, 0)).Unit
				table.insert(planes, { n.X, n.Y, n.Z, n:Dot(apex), scaled(C.Gold, ({ 1, 0.92, 0.86, 0.95 })[k + 1]) })
			end
			return convexSolid(Vector3.new(-2.02, y0, -2.02), Vector3.new(2.02, y1, 2.02), CFrame.new(cx, 0, 0), C.Gold, planes, material)
		end
		add("Gold", pyramid(22.85, split))
		add("Glow", pyramid(split, 26.25, Enum.Material.Neon))
	end
	-- the name board: lapis back, gold frame, today's NameSign / SignRear plates (plain parts), the gold cap and sun
	add("Inlay", chamfered(Vector3.new(16.4, 5.2, 1.6), CFrame.new(0, 25.1, 0), C.Lapis, { "vertical" }, 0.12))
	for _, z in ipairs({ -1, 1 }) do
		for _, e in ipairs({ { 0, 2.35, 15.4, 0.35 }, { 0, -2.35, 15.4, 0.35 }, { -7.55, 0, 0.35, 4.35 }, { 7.55, 0, 0.35, 4.35 } }) do
			add("Gold", chamfered(Vector3.new(e[3], e[4], 0.3), CFrame.new(e[1], 25.1 + e[2], z * 0.95), C.Gold, { "topFrontBack", "bottomFrontBack" }, 0.06))
		end
		for _, sx in ipairs({ -1, 1 }) do
			add("Gold", piece("Part", Vector3.new(0.4, 0.4, 0.4), CFrame.new(sx * 7.55, 27.45, z * 0.95) * CFrame.Angles(rad(45), rad(45), 0), C.Gold))
		end
	end
	add("Gold", chamfered(Vector3.new(17.4, 0.8, 2.2), CFrame.new(0, 28.1, 0), C.Gold, { "vertical", "topFrontBack", "topSides" }, 0.18))
	add("Gold", chamfered(Vector3.new(16.8, 0.3, 1.9), CFrame.new(0, 27.55, 0), scaled(C.Gold, 0.86), { "vertical" }, 0.1))
	for _, z in ipairs({ -1.12, 1.12 }) do
		add("Gold", octagon(0.9, 0.12, CFrame.new(0, 28.1, z) * CFrame.Angles(rad(90), 0, 0), scaled(C.Gold, 1.05)))
		for _, sx in ipairs({ -1, 1 }) do
			add("Gold", piece("Part", Vector3.new(1.6, 0.22, 0.1), CFrame.new(sx * 1.25, 28.15, z) * CFrame.Angles(0, 0, sx * rad(8)), scaled(C.Gold, 0.9)))
		end
	end
	local sign = piece("Part", Vector3.new(14, 4, 0.5), CFrame.new(0, 25.1, -0.9), C.Sandstone)
	sign.Name = "NameSign"
	local rear = piece("Part", Vector3.new(14, 4, 0.5), CFrame.new(0, 25.1, 0.9), C.Sandstone)
	rear.Name = "SignRear"
	-- the banners (today's at x +-8.5, 2.6 wide, 11 .. 18): a gold rod with knobs, pleated cloth, gold trims, today's
	-- gold tail band, a pointed end with a gold tassel, a small gold ankh
	U.Cloth = {}
	for _, sx in ipairs({ -1, 1 }) do
		local cx = sx * 8.5
		add("Gold", octagon(0.22, 3.4, CFrame.new(cx, 17.85, -2.2) * CFrame.Angles(0, 0, rad(90)), C.Gold))
		for _, e in ipairs({ -1.75, 1.75 }) do
			add("Gold", piece("Part", Vector3.new(0.34, 0.34, 0.34), CFrame.new(cx + e, 17.85, -2.2), C.Gold, { shape = Enum.PartType.Ball }))
		end
		for k = 0, 3 do
			local x = cx - 0.975 + k * 0.65
			table.insert(U.Cloth, piece("Part", Vector3.new(0.67, 6.4, 0.14), CFrame.new(x, 14.5, -2.2 + (if k % 2 == 0 then -0.05 else 0.05)), scaled(C.Red, if k % 2 == 0 then 1 else 0.9)))
		end
		H.triangleParts(U.Cloth, Vector3.new(cx - 1.3, 11.3, -2.2), Vector3.new(cx + 1.3, 11.3, -2.2), Vector3.new(cx, 10.1, -2.2), 0.14, CFrame.identity, scaled(C.Red, 0.95))
		for _, e in ipairs({ -1.36, 1.36 }) do
			add("Gold", piece("Part", Vector3.new(0.14, 6.6, 0.2), CFrame.new(cx + e, 14.5, -2.2), C.Gold))
		end
		add("Gold", piece("Part", Vector3.new(2.7, 0.9, 0.22), CFrame.new(cx, 11.75, -2.2), C.Gold))
		add("Gold", piece("Part", Vector3.new(2.6, 0.12, 0.24), CFrame.new(cx, 12.1, -2.2), scaled(C.Gold, 0.85)))
		add("Gold", piece("Part", Vector3.new(0.1, 0.5, 0.1), CFrame.new(cx, 9.85, -2.2), C.Gold))
		add("Gold", chamfered(Vector3.new(0.34, 0.55, 0.34), CFrame.new(cx, 9.4, -2.2), C.Gold, { "bottomFrontBack", "bottomSides" }, 0.1))
		-- the ankh
		add("Gold", piece("Part", Vector3.new(0.14, 1.3, 0.06), CFrame.new(cx, 14.3, -2.33), C.Gold))
		add("Gold", piece("Part", Vector3.new(0.8, 0.14, 0.06), CFrame.new(cx, 14.75, -2.33), C.Gold))
		for _, e in ipairs({ { 0, 15.5, 0.6, 0.12 }, { -0.25, 15.2, 0.12, 0.5 }, { 0.25, 15.2, 0.12, 0.5 } }) do
			add("Gold", piece("Part", Vector3.new(e[3], e[4], 0.06), CFrame.new(cx + e[1], e[2], -2.33), C.Gold))
		end
	end
	-- the lamps: an iron scroll bracket, a brass bowl with a rim, the flame (Ember) with today's light and FirePoint
	local embers = {}
	for _, sx in ipairs({ -1, 1 }) do
		local cx = sx * 14.5
		add("Iron", chamfered(Vector3.new(1.0, 1.6, 0.25), CFrame.new(cx, 8.3, -2.6), C.Iron, { "frontFace" }, 0.08))
		add("Iron", bar(Vector3.new(cx, 7.7, -2.6), Vector3.new(cx, 8.95, -4.0), 0.22, C.Iron))
		add("Iron", bar(Vector3.new(cx, 8.95, -2.6), Vector3.new(cx, 8.95, -4.0), 0.2, C.Iron))
		H.scroll(U.Iron, Vector3.new(cx, 9.15, -2.75), Vector3.new(0, 0, -1), 0.28, C.Iron, 0.1)
		local bowl = CFrame.new(cx, 8.95, -4.0)
		add("Iron", frustum8(0.45, 1.05, 0, 0.62, bowl, BRASS))
		add("Iron", octagon(2.25, 0.14, bowl * CFrame.new(0, 0.66, 0), scaled(BRASS, 1.12)))
		add("Iron", octagon(0.7, 0.16, bowl * CFrame.new(0, 0.02, 0), scaled(BRASS, 0.85)))
		local fl = H.flame(bowl * CFrame.new(0, 0.55, 0), 0.62, 0.35, 1.5, rgb(255, 190, 80))
		table.insert(embers, fl)
	end
	-- sand drifts at the bases (front and back of each pier)
	U.Sand = {}
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local turn = if sz < 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
			table.insert(U.Sand, piece("WedgePart", Vector3.new(4.2, 0.6, 1.1), CFrame.new(sx * 14.5 + sx * 0.6, 0.3, sz * 3.85) * turn, rgb(244, 208, 124)))
			table.insert(U.Sand, piece("Part", Vector3.new(3.6, 0.45, 0.45), CFrame.new(sx * 14.5 + sx * 0.6, 0.38, sz * 3.4), rgb(244, 208, 124), { shape = Enum.PartType.Cylinder }))
		end
	end

	envelope(m, "egyptian_arch")
	finishVisual(m, "egyptian_arch", U, "Stone", { Stone = true })
	for i, fl in ipairs(embers) do
		local e = merge(m, "Ember", { fl }, { material = Enum.Material.Neon, shadow = false })
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color = 14, 1, rgb(255, 214, 120)
		light.Parent = e
		local fp = Instance.new("Attachment")
		fp.Name = "FirePoint"
		fp.Parent = e
		fp.WorldPosition = Vector3.new((if i == 1 then -1 else 1) * 14.5, 9.9 + 0.4, -4.0)
	end
	for _, p in ipairs({ sign, rear }) do
		p.CanCollide = false
		p.CanQuery = true
		p.CanTouch = false
		p.Parent = m
	end
	for _, sx in ipairs({ -1, 1 }) do
		local l = Instance.new("PointLight")
		l.Range, l.Brightness, l.Color, l.Shadows = 8, 0.4, rgb(255, 214, 110), false
		local a = Instance.new("Attachment")
		a.Name = "TipGlow"
		a.Parent = m:FindFirstChild("Glow")
		a.WorldPosition = Vector3.new(sx * 17, 25.0, 0)
		l.Parent = a
	end
	H.setBevelSelf(false)
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the fresh PropsBatch2 table; its install() builds them
---------------------------------------------------------------------
PropsDesert.BUILDERS = {
	adobe_house_a = true, adobe_house_b = true, market_stall = true, canopy_pavilion = true, desert_tent = true, ruined_wall = true,
	egyptian_arch = true,
}
for id in pairs(PropsDesert.BUILDERS) do
	B2[id] = (PropsDesert :: any)[id]
	B2.BUILDERS[id] = true
end
PropsDesert.install = B2.install
PropsDesert.stats = B2.stats

return PropsDesert
