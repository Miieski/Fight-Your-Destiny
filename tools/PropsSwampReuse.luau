--[[
	PropsSwampReuse (dev tool) - the owner's "CURSED SWAMP PROP IMPROVEMENT - Objects reused from other biomes"
	(2026-10-25): 4 swamp props that already exist, finished, in another biome. Each one is DUPLICATED from its finished
	base and only adjusted for the swamp (guide section F palette, F7):
	01 swamp_barrel (Potion_Barrel) from the plains `barrel` (DevTools.PropsBatch4.barrel: the same 14 staves in 3
	tilted thirds, the same profile, the 3 hoops), 02 swamp_scarecrow (Scarecrow_Swamp) from the plains `scarecrow`
	template, 03 swamp_rowboat (Rowboat_Sunk) from the plains `rowboat` template, 04 swamp_lily_pads (LilyPad_Swamp_A)
	from the jungle `jungle_lily_pads` (DevTools.PropsJungleNature).

	Kept: each kit's size, place and colliders (today's colliding parts as invisible "Collision" parts), the glowing
	parts exactly (the barrel's Liquid, the scarecrow's Eyes), the attributes (the rowboat's SinkDepth).
	Today's kit parts are rows in DevTools.PropsSwampReuseData (tools/PropsSwampReuseData.luau).

	Usage (Studio command bar):
		local SR = require(game.ServerStorage.DevTools.PropsSwampReuse:Clone())
		print(SR.install("swamp_barrel"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.run({ only = { "swamp_barrel" } }))
]]

local ServerStorage = game:GetService("ServerStorage")

local ST = require(ServerStorage.DevTools.PropsSwampTrees:Clone()) :: any
local SH = require(ServerStorage.DevTools.PropsSwampHuts:Clone()) :: any
local TB, B2, H, M = SH.TB, SH.B2, SH.H, SH.M
local GD = require(ServerStorage.DevTools.PropsSwampReuseData:Clone()) :: any
local piece, chamfered = H.piece, H.chamfered
local scaled, graded = H.scaled, H.graded
local frustumN = M.frustumN
local C = SH.COLORS
local blob, leaf = ST.blob, ST.leaf

local SR = {}

local rgb = Color3.fromRGB
local rad = math.rad
local UP = Vector3.yAxis

local MOSS, MOSS_MID, OLIVE = C.MOSS, C.MOSS_MID, C.OLIVE
local MOSS_TOP = MOSS:Lerp(OLIVE, 0.3)
local IRON = rgb(55, 58, 65) -- #373A41 today's swamp bands
local RUST = rgb(122, 74, 46) -- #7A4A2E
local SLUDGE = rgb(42, 52, 30) -- #2A341E dark sludge under the glow

local function rows(kit: string, name: string?): { any }
	return GD.rows(kit, name)
end
SR.rows = rows

-- an exact copy of a row (class, shape, size, place, colour, material, transparency, flags)
local function exactRow(parent: Instance, r: any): BasePart
	local p = Instance.new(r.class) :: BasePart
	if r.shape ~= "" and p:IsA("Part") then
		p.Shape = (Enum.PartType :: any)[r.shape]
	end
	p.Name = r.name
	p.Size = r.size
	p.CFrame = r.cf
	p.Color = r.color
	p.Material = (Enum.Material :: any)[r.material]
	p.Transparency = r.transparency
	p.CanCollide = r.collide
	p.CanQuery = r.query
	p.CanTouch = true
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
SR.exactRow = exactRow

-- today's colliding parts of a kit as invisible "Collision" parts (skip: rows to leave out)
local function kitColliders(m: Model, kit: string, skip: ((any) -> boolean)?): number
	local n = 0
	for _, r in ipairs(rows(kit)) do
		if r.collide and not (skip and skip(r)) then
			local p = Instance.new(r.class) :: BasePart
			if r.shape ~= "" and p:IsA("Part") then
				p.Shape = (Enum.PartType :: any)[r.shape]
			end
			p.Name = "Collision"
			p.Size = r.size
			p.CFrame = r.cf
			p.Anchored = true
			p.CanCollide = true
			p.CanQuery = true
			p.CastShadow = false
			p.Transparency = 1
			p.Parent = m
			n += 1
		end
	end
	return n
end
SR.kitColliders = kitColliders

-- every copy keeps today's own colliding parts, invisible, in a KeptCollision folder (MapPropKeep); run before the sync
-- (needs the untagged before-stash ServerStorage._ReuseOld_<propId>)
function SR.prepColliders(propId: string): string
	local Sync = require(ServerStorage.DevTools.SyncMapProps:Clone()) :: any
	local stash = ServerStorage:FindFirstChild("_ReuseOld_" .. propId)
	assert(stash, "PropsSwampReuse: no before-stash _ReuseOld_" .. propId)
	local n, parts = 0, 0
	for _, m in ipairs(Sync.find(propId)) do
		local old = nil
		for _, o in ipairs(stash:GetChildren()) do
			if ((o :: Model):GetPivot().Position - m:GetPivot().Position).Magnitude < 0.01 then
				old = o
			end
		end
		assert(old, "PropsSwampReuse: no stash copy for " .. m:GetFullName())
		local prev = m:FindFirstChild("KeptCollision")
		if prev then
			prev:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "KeptCollision"
		folder:SetAttribute("MapPropKeep", true)
		for _, p in ipairs(old:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then
				local q = p:Clone()
				q:ClearAllChildren()
				q.Name = "Collision"
				q.Transparency = 1
				q.CastShadow = false
				q.Parent = folder
				parts += 1
			end
		end
		folder.Parent = m
		n += 1
	end
	return `prepColliders {propId}: {n} copies, {parts} kept colliding parts`
end

-- a variant folder: _Variants/<name> with Color_<part> attributes
local function variant(m: Model, name: string, colors: { [string]: Color3 })
	local folder = m:FindFirstChild("_Variants") or Instance.new("Folder")
	folder.Name = "_Variants"
	local cfg = Instance.new("Configuration")
	cfg.Name = name
	for part, c in pairs(colors) do
		cfg:SetAttribute("Color_" .. part, c)
	end
	cfg.Parent = folder
	folder.Parent = m
end

---------------------------------------------------------------------
-- 01 BARREL WITH A GLOWING TOP (kit MapAssets.Swamp.Potion_Barrel: a Body cylinder 4 x 3, a Belly 2 x 3.4, 2 Bands at
-- y 1 and 3, a Lid at 4, the Neon Liquid #8CFF5A 2.1 across at y 4.07 (the only part that does not collide);
-- 3.45 x 4.17 x 3.45; 18 copies: test, kit, Swamp_3 x16 (scale 1 / 1.15); 4 with a purple liquid #AA50FF: Variant
-- Purple; no script, no prompt)
---------------------------------------------------------------------
-- DUPLICATED from the plains barrel (PropsBatch4.barrel: 14 staves of 3 tilted thirds on the same bulging profile,
-- 0.2 thick with gaps over a dark core, 3 tones and the height gradient; 3 iron hoops at 1.05 / 3.0 / 3.72 with 4
-- rivets each). Swamp changes: dark wet wood (today's #684C34, darker and wetter towards the foot), no lid: the barrel
-- is open and full of dark sludge with today's glowing liquid kept exactly on top (its size and glow), bubbles and 3
-- glowing drips running over the rim; the iron hoops in today's dark swamp iron with rust rivets, the middle hoop
-- dented (2 segments pushed in and twisted); moss cushions round the foot and a patch climbing a stave. Colliders:
-- today's 5 colliding parts. Parts: Wood (PrimaryPart), Iron, Moss, Glow (Neon, one colour: Variant Purple recolours
-- it with the liquid), Liquid, Collision x5
local BARREL_H = 4.05
local BARREL_YS = { 0, 1.35, 2.7, BARREL_H }
local function barrelNode(y: number): number
	return 1.5 + 0.19 * math.sin(math.pi * y / BARREL_H)
end
local function barrelR(y: number): number
	for k = 1, #BARREL_YS - 1 do
		local a, b = BARREL_YS[k], BARREL_YS[k + 1]
		if y <= b + 1e-6 then
			local t = (y - a) / (b - a)
			return barrelNode(a) + (barrelNode(b) - barrelNode(a)) * t
		end
	end
	return 1.5
end
SR.barrelR = barrelR

function SR.swamp_barrel(): Model
	local kit = "Potion_Barrel"
	local m = Instance.new("Model")
	m.Name = "swamp_barrel"
	local rng = Random.new(20261501)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Iron = {}, Moss = {}, Glow = {} }
	local liquid = rows(kit, "Liquid")[1]
	local GLOW = liquid.color
	local WOOD = rgb(104, 76, 52) -- today's #684C34
	local CORE = rgb(30, 22, 16)
	local N, t = 14, 0.2
	-- the dark core (seen through the stave gaps), as the plains barrel
	table.insert(U.Wood, H.prism16(2 * 1.24, 3.62, CFrame.new(0, 1.83, 0), CORE))
	-- staves: 3 tilted thirds on the plains profile; the lowest third wetter (darker)
	local ys = BARREL_YS
	local prev = nil
	for i = 0, N - 1 do
		local a = (i + 0.5) * 2 * math.pi / N
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local ti = H.toneIndex(rng, prev)
		prev = ti
		local base = scaled(WOOD, ({ 1, 0.93, 0.86 })[ti])
		for k = 1, #ys - 1 do
			local ya, yb = ys[k], ys[k + 1]
			local ra, rb = barrelR(ya) - t / 2, barrelR(yb) - t / 2
			local p0, p1 = d * ra + Vector3.new(0, ya, 0), d * rb + Vector3.new(0, yb, 0)
			local up = (p1 - p0).Unit
			local out = (d - up * d:Dot(up)).Unit
			local x = up:Cross(out)
			local rm = (ra + rb) / 2
			local w = 2 * (rm - t / 2) * math.tan(math.pi / N) - 0.04
			local c = graded(if k == 1 then scaled(base, 0.82) else base, (ya + yb) / 2, BARREL_H)
			table.insert(U.Wood, piece("Part", Vector3.new(w, (p1 - p0).Magnitude, t), CFrame.fromMatrix((p0 + p1) / 2, x, up), c))
		end
	end
	-- the open top: dark sludge filling the barrel to today's lid height, today's liquid on it exactly
	local inner = barrelR(BARREL_H) - t - 0.01
	table.insert(U.Wood, frustumN(14, inner, inner, 3.7, 3.99, CFrame.new(0, 0, 0) * CFrame.Angles(0, rad(6), 0), { SLUDGE, scaled(SLUDGE, 1.15) }))
	exactRow(m, liquid)
	local ly = liquid.cf.Y + liquid.size.X / 2
	local lr = liquid.size.Y / 2
	-- bubbles on the liquid and 3 drips over the rim (the same glow)
	for k = 1, 4 do
		local a = k * 1.9
		local rr = lr * (0.25 + 0.15 * k)
		local s = rng:NextNumber(0.12, 0.22)
		table.insert(U.Glow, frustumN(6, s, s * 0.3, ly - 0.04, ly + s * 0.6, CFrame.new(math.cos(a) * rr, 0, math.sin(a) * rr), { GLOW }))
	end
	-- a glowing slick from the liquid to the rim on the drip side, then the drips down the staves
	for _, dd in ipairs({ { 1.2, 0.95 }, { 1.5, 0.55 }, { 1.82, 0.75 } }) do -- (the front: -Z)
		local a = dd[1] * math.pi
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local top = d * (barrelR(BARREL_H) - 0.04) + Vector3.new(0, BARREL_H + 0.02, 0)
		table.insert(U.Glow, H.bar(d * (lr - 0.1) + Vector3.new(0, ly - 0.02, 0), top, 0.1, GLOW))
		local yb = BARREL_H - dd[2]
		local bot = d * (barrelR(yb) + 0.02) + Vector3.new(0, yb, 0)
		table.insert(U.Glow, H.bar(top, bot, 0.11, GLOW))
		table.insert(U.Glow, frustumN(6, 0.09, 0.03, -0.12, 0.06, H.frameY(bot, UP), { GLOW }))
	end
	-- the 3 hoops (the plains places), dark swamp iron; the middle one dented; rust rivets
	for hi, y in ipairs({ 1.05, 3.0, 3.72 }) do
		local r = barrelR(y) + 0.035
		local ic = scaled(IRON, 0.92 + 0.08 * hi / 3)
		if hi == 2 then
			local S = 16
			for k = 0, S - 1 do
				local a = (k + 0.5) * 2 * math.pi / S
				local d = Vector3.new(math.cos(a), 0, math.sin(a))
				local dent = if k == 5 or k == 6 then 0.07 else 0
				local twist = if k == 5 then 9 elseif k == 6 then -7 else 0
				local w = 2 * (r + 0.035) * math.tan(math.pi / S) + 0.03
				local cf = CFrame.lookAt(d * (r - dent), d * (r - dent) + d) * CFrame.Angles(0, 0, rad(twist))
				table.insert(U.Iron, piece("Part", Vector3.new(w, 0.28, 0.08), cf + Vector3.new(0, y - (if dent > 0 then 0.03 else 0), 0), if dent > 0 then scaled(ic, 1.12) else ic))
			end
		else
			table.insert(U.Iron, H.prism16(2 * (r + 0.035), 0.28, CFrame.new(0, y, 0), ic))
		end
		for k = 0, 3 do
			local a = (k * 4 + 0.5 + hi) * 2 * math.pi / N
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			table.insert(U.Iron, piece("Part", Vector3.new(0.12, 0.12, 0.12), CFrame.new(d * (r + 0.04) + Vector3.new(0, y, 0)) * CFrame.Angles(rad(45), a, rad(45)), RUST))
		end
	end
	-- moss: cushions round the foot, a patch climbing one stave
	for k = 0, 4 do
		local a = k * 1.3 + 0.4
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local s = rng:NextNumber(0.85, 1.25)
		blob(U.Moss, rng, CFrame.new(d * (barrelR(0) - 0.08) + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, -a, 0), 0.28 * s, 0.22 * s, 0.5 * s, function(n: Vector3): Color3
			return if n.Y > 0.4 then MOSS_TOP elseif n.Y > -0.2 then MOSS else scaled(MOSS, 0.8)
		end, 0.12)
	end
	do
		local a = 4.0
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		blob(U.Moss, rng, CFrame.lookAt(d * (barrelR(0.6) + 0.02) + Vector3.new(0, 0.6, 0), d * 3 + Vector3.new(0, 0.6, 0)), 0.32, 0.45, 0.08, function(): Color3
			return MOSS_MID
		end)
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, "swamp_barrel", U, "Wood", { Glow = { material = Enum.Material.Neon, shadow = false } })
	local glow = m:FindFirstChild("Glow") :: UnionOperation?
	if glow then
		glow.UsePartColor = true
		glow.Color = GLOW
	end
	kitColliders(m, kit)
	-- Variant Purple: today's purple liquid (and its bubbles and drips)
	variant(m, "Purple", { Liquid = Color3.fromHex("aa50ff"), Glow = Color3.fromHex("aa50ff") })
	return m
end

-- a copy of one of a finished template's parts (a MeshPart of the plains scarecrow / rowboat), recoloured; it never
-- collides (the colliders are today's swamp kit parts)
local function baseCopy(m: Model, template: string, name: string, color: Color3?): BasePart
	local t = ServerStorage.MapProps:FindFirstChild(template)
	assert(t, "PropsSwampReuse: ServerStorage.MapProps." .. template .. " missing")
	local src = t:FindFirstChild(name) :: BasePart?
	assert(src and src:IsA("BasePart"), "PropsSwampReuse: " .. template .. "." .. name .. " missing")
	local p = src:Clone()
	p:ClearAllChildren()
	if color then
		p.Color = color
	end
	p.CanCollide = false
	p.CanTouch = false
	p.Anchored = true
	p.Parent = m
	return p
end
SR.baseCopy = baseCopy

-- a nested MapProp: the template `propId` scaled and placed (pivot = cf), tagged so the sync keeps it current
local function nestProp(m: Model, propId: string, name: string, cf: CFrame, scale: number): Model
	local t = ServerStorage.MapProps:FindFirstChild(propId)
	assert(t, "PropsSwampReuse: ServerStorage.MapProps." .. propId .. " missing")
	local c = t:Clone() :: Model
	c.Name = name
	c:ScaleTo(scale)
	c:PivotTo(cf)
	c:AddTag("MapProp")
	c:SetAttribute("MapPropId", propId)
	c:SetAttribute("MapPropVersion", tostring(t:GetAttribute("MapPropVersion") or "?") .. "|")
	c.Parent = m
	return c
end
SR.nestProp = nestProp

---------------------------------------------------------------------
-- 02 SCARECROW WITH A TOP HAT (kit MapAssets.Swamp.Scarecrow_Swamp: Pole, Arms, Shirt #622CA0, 3 Hay, a pale Head
-- ball #DED6BE, a black HatBrim and HatTop (tilted 6 degrees), 2 Neon Eyes #FFE860; everything collides; 8 x 9.45 x
-- 3.6; 6 copies: test, kit, Swamp_3 x4 (scale 1.15); no script, no prompt)
---------------------------------------------------------------------
-- DUPLICATED from the plains scarecrow (the `scarecrow` template: its post with the cross bar, rope lashings, the
-- shirt with sleeves, its patches and stitched mouth, the straw hem, collar and wrists, all MeshParts; the swamp kit
-- has the plains kit's post, arms, shirt and head). Swamp changes: today's purple shirt with dark green patches, tears
-- (dark slashes, a stitched square patch) and torn cloth strips hanging from the hem and a sleeve; today's olive straw;
-- the post dark and wet, the rope damp; a pale ghostly head with dark sockets round today's glowing eyes (kept
-- exactly; the plains button eyes left out); dark gloves with straw at the cuffs; a black top hat with a purple band in
-- today's hat place (the plains straw hat left out); a small raven (the nested swamp_raven) on the right sleeve; moss
-- at the foot of the post. Colliders: today's 9 colliding parts (+ the 2 colliding Eyes, exact). Parts: Root
-- (PrimaryPart, invisible), the plains meshes (Post, Shirt, Patches, Rope, Stitches, StrawHem, StrawCollar, StrawWristL /
-- R, Head), Hat, Cloth, Gloves, Moss, Eye x2, Raven (nested), Collision x9
function SR.swamp_scarecrow(): Model
	local kit = "Scarecrow_Swamp"
	local base = "scarecrow"
	local m = Instance.new("Model")
	m.Name = "swamp_scarecrow"
	local rng = Random.new(20261502)
	H.setBevelSelf(true)
	local U: any = { Hat = {}, Cloth = {}, Gloves = {}, Moss = {} }
	local SHIRT = rgb(98, 44, 160) -- today's #622CA0
	local HAY = rgb(128, 120, 62) -- today's #80783E
	local POLE = rgb(50, 38, 32) -- today's #322620
	local HATC = rgb(30, 22, 19) -- today's #1E1613
	local GHOST = rgb(218, 228, 216) -- #DAE4D8 pale, a little green
	local DARK = rgb(26, 20, 22)
	local GLOVE = rgb(44, 36, 34)
	-- the plains meshes, recoloured (the button eyes and the straw hat are left out)
	baseCopy(m, base, "Post", POLE)
	baseCopy(m, base, "Shirt", SHIRT)
	baseCopy(m, base, "Patches", rgb(70, 98, 50))
	baseCopy(m, base, "Rope", rgb(122, 106, 72))
	baseCopy(m, base, "Stitches", DARK)
	baseCopy(m, base, "StrawHem", HAY)
	baseCopy(m, base, "StrawCollar", HAY)
	baseCopy(m, base, "Head", GHOST)
	-- the wrists: the straw pushed in to the cuffs (60 %), dark gloves beyond
	for _, n in ipairs({ "StrawWristL", "StrawWristR" }) do
		local p = baseCopy(m, base, n, scaled(HAY, 0.92))
		local sx = if p.Position.X < 0 then -1 else 1
		p.Size = p.Size * 0.6
		p.CFrame = p.CFrame + Vector3.new(-sx * 0.25, 0, 0)
	end
	-- today's glowing eyes, exactly, in dark sockets
	for _, r in ipairs(rows(kit, "Eye")) do
		exactRow(m, r)
		table.insert(U.Gloves, chamfered(Vector3.new(0.46, 0.46, 0.12), r.cf * CFrame.new(0, 0, 0.06), DARK, { "vertical" }, 0.08))
	end
	-- dark gloves at today's hands: a palm, a thumb and 3 fingers hanging down and out
	for _, sx in ipairs({ -1, 1 }) do
		local palm = Vector3.new(sx * 3.5, 5.3, -0.02)
		blob(U.Gloves, rng, CFrame.new(palm), 0.3, 0.26, 0.24, function(n: Vector3): Color3
			return if n.Y > 0.3 then scaled(GLOVE, 1.15) else GLOVE
		end)
		for k = -1, 1 do
			local a = palm + Vector3.new(sx * 0.18, -0.12, k * 0.12)
			table.insert(U.Gloves, H.bar(a, a + Vector3.new(sx * 0.28, -0.3, k * 0.04), 0.1, scaled(GLOVE, 0.92 + 0.06 * (k + 1))))
		end
		table.insert(U.Gloves, H.bar(palm + Vector3.new(0, 0.05, -0.18), palm + Vector3.new(sx * 0.12, 0.2, -0.36), 0.1, GLOVE))
	end
	-- the top hat in today's hat place: a brim, a slightly flared crown, a purple band
	do
		local brim = rows(kit, "HatBrim")[1]
		local top = rows(kit, "HatTop")[1]
		local bf = brim.cf * CFrame.Angles(0, 0, -math.pi / 2)
		local tf = top.cf * CFrame.Angles(0, 0, -math.pi / 2)
		local hb, rb = brim.size.X / 2, brim.size.Y / 2
		local ht, rt = top.size.X / 2, top.size.Y / 2
		table.insert(U.Hat, frustumN(16, rb * 0.99, rb * 0.97, -hb, hb, bf, { HATC, scaled(HATC, 1.25), scaled(HATC, 1.1) }))
		table.insert(U.Hat, frustumN(12, rt * 0.93, rt * 1.0, -ht - 0.05, ht, tf, { HATC, scaled(HATC, 1.3), scaled(HATC, 1.12) }))
		table.insert(U.Hat, frustumN(12, rt * 1.0, rt * 0.96, ht - 0.02, ht + 0.04, tf * CFrame.Angles(rad(4), 0, 0), { scaled(HATC, 1.4) }))
		table.insert(U.Hat, frustumN(12, rt * 0.97, rt * 0.98, -ht + 0.05, -ht + 0.36, tf, { rgb(74, 42, 106), rgb(88, 52, 124) }))
	end
	-- tears on the shirt front (dark slashes), a stitched square patch, torn strips hanging from the hem and a sleeve
	for _, s in ipairs({ { -0.38, 4.35, 28 }, { 0.22, 5.05, -35 }, { 0.42, 3.75, 12 } }) do
		table.insert(U.Cloth, piece("Part", Vector3.new(0.07, 0.48, 0.06), CFrame.new(s[1], s[2], -0.8 - math.abs(s[1]) * 0.05) * CFrame.Angles(0, 0, rad(s[3])), DARK))
	end
	do
		local pc = CFrame.new(-0.55, 3.85, -0.77) * CFrame.Angles(0, rad(-14), rad(6))
		table.insert(U.Cloth, piece("Part", Vector3.new(0.55, 0.5, 0.05), pc, rgb(58, 84, 44)))
		for _, e in ipairs({ { 0, 0.25, 0.55, 0.04 }, { 0, -0.25, 0.55, 0.04 }, { 0.27, 0, 0.04, 0.5 }, { -0.27, 0, 0.04, 0.5 } }) do
			table.insert(U.Cloth, piece("Part", Vector3.new(e[3], e[4], 0.06), pc * CFrame.new(e[1], e[2], -0.01), rgb(196, 176, 120)))
		end
	end
	for _, s in ipairs({ { -0.75, 3.45, -0.62, 0.95, 8 }, { 0.15, 3.3, -0.74, 0.7, -5 }, { 0.85, 3.45, -0.6, 0.85, -10 }, { -2.3, 5.3, -0.36, 0.75, 4 } }) do
		local cf = CFrame.new(s[1], s[2] - s[4] / 2, s[3]) * CFrame.Angles(rad(-4), 0, rad(s[5]))
		local c = scaled(SHIRT, rng:NextNumber(0.78, 0.92))
		table.insert(U.Cloth, piece("Part", Vector3.new(0.32, s[4], 0.04), cf, c))
		-- a ragged end: 2 small tips
		for _, tx in ipairs({ -0.09, 0.09 }) do
			table.insert(U.Cloth, piece("WedgePart", Vector3.new(0.04, 0.18, 0.12), cf * CFrame.new(tx, -s[4] / 2 - 0.08, 0) * CFrame.Angles(0, rad(90), rad(180)), c))
		end
	end
	-- moss at the foot of the post
	for k = 0, 3 do
		local a = k * 1.7 + 0.3
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		blob(U.Moss, rng, CFrame.new(d * 0.42 + Vector3.new(0, 0.1, 0)), 0.3, 0.18, 0.3, function(n: Vector3): Color3
			return if n.Y > 0.4 then MOSS_TOP elseif n.Y > -0.2 then MOSS else scaled(MOSS, 0.8)
		end, 0.12)
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, "swamp_scarecrow", U, "Hat")
	-- a small raven on the right sleeve (the swamp_raven prop, nested)
	nestProp(m, "swamp_raven", "Raven", CFrame.new(2.3, 5.82, 0) * CFrame.Angles(0, rad(-25), 0), 0.45)
	-- the invisible root (as the plains template) over the whole prop
	local cf, size = m:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = size
	root.CFrame = cf
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Transparency = 1
	root.PivotOffset = cf:Inverse() -- the model's pivot stays the kit's (the foot of the post)
	root.Parent = m
	m.PrimaryPart = root
	kitColliders(m, kit, function(r: any): boolean
		return r.name == "Eye"
	end)
	return m
end

-- an invisible root part over the whole model (as the plains templates), the model's pivot kept at the origin
local function rootOver(m: Model)
	local cf, size = m:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = size
	root.CFrame = cf
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Transparency = 1
	root.PivotOffset = cf:Inverse()
	root.Parent = m
	m.PrimaryPart = root
end

---------------------------------------------------------------------
-- 03 ROWBOAT (kit MapAssets.Swamp.Rowboat_Sunk: the plains Rowboat_Wreck recoloured (Bottom, Side, 2 SideBroken, 2
-- Bow wedges, Stern, 2 Bench, LoosePlank, Oar, OarBlade: all collide) + a green Moss block 4 x 0.5 x 3 (does not
-- collide); 14.1 x 4.98 x 11.14; attribute SinkDepth = 1; 4 copies: test, kit, Swamp_1 x2 (sunk, pivot y -2.6); no
-- script, no prompt)
---------------------------------------------------------------------
-- DUPLICATED from the plains rowboat (the `rowboat` template: hull planks, timber ribs and keel, thwarts, iron, rope,
-- oar and blade, all MeshParts made from the same kit). Swamp changes: a darker, wetter palette; mud and algae at the
-- waterline (a mud band with an algae fringe along both sides, hanging algae strands); rotten planks with moss on the
-- benches and the gunwale; 2 broken planks on the high side as dark holes with splintered ends and 2 cracks (the hull
-- is one mesh, so nothing is cut away and the colliders stay exactly today's); 3 leafy vines hanging over the edge;
-- today's green Moss block as a slimy cargo (a sunken crate and a sack under a moss mound with slime drips) in its
-- place. Colliders: each copy keeps today's own 12 colliding parts (KeptCollision: the game copies differ from the
-- kit). Parts: Root (PrimaryPart, invisible), the plains meshes (Hull, Timber, Thwarts, Iron, Rope, Oar, OarBlade),
-- Algae, Rot, Vines, Cargo
-- the outer surface z of the hull mesh (measured on the plains Hull, on its high +Z and its low -Z side), per x:
-- { x, z at y 1.6, z at y 2.0, z at y 2.4 }
local HULL_HIGH = { { -5, 1.57, 1.65, 1.64 }, { -4, 1.65, 1.75, 1.74 }, { -3, 1.72, 1.82, 1.83 }, { -2, 1.77, 1.88, 1.89 }, { -1, 1.79, 1.91, 1.92 }, { 0, 1.80, 1.92, 1.93 }, { 1, 1.78, 1.89, 1.90 }, { 2, 1.69, 1.80, 1.80 }, { 3, 1.60, 1.68, 1.67 }, { 4, 1.39, 1.45, 1.41 }, { 5, 1.19, 1.19, 1.15 }, { 6, 0.87, 0.84, 0.76 } }
local HULL_LOW_STERN = { { -5, -2.30, -2.68, -2.89 }, { -4, -2.45, -2.83, -3.04 }, { -3, -2.58, -2.95, -3.17 }, { -2, -2.70, -3.06, -3.28 } }
local HULL_LOW_BOW = { { 4, -2.02, -2.36, -2.59 }, { 5, -1.61, -1.87, -2.16 }, { 6, -1.08, -1.38, -1.60 } }
-- the high side's outer z at y 3.0 / 3.5 (for the holes and cracks)
local HIGH_UP = { [-4] = 1.79, [-3] = 1.89, [-2] = 1.98, [-1] = 2.01, [0] = 2.02, [1] = 1.99, [2] = 1.87, [3] = 1.72 }
function SR.swamp_rowboat(): Model
	local kit = "Rowboat_Sunk"
	local base = "rowboat"
	local m = Instance.new("Model")
	m.Name = "swamp_rowboat"
	local rng = Random.new(20261503)
	H.setBevelSelf(true)
	local U: any = { Algae = {}, Rot = {}, Vines = {}, VineLeaves = {}, Cargo = {} }
	local MUD = rgb(58, 42, 28) -- #3A2A1C
	local ALGAE = rgb(76, 106, 42) -- #4C6A2A
	local SLIME = rgb(111, 160, 58) -- #6FA03A
	local HOLE = rgb(24, 18, 14)
	local PLANK = rgb(82, 60, 42) -- #523C2A the hull, darker and wetter than today's #684C34
	-- the plains meshes, darker and wetter
	baseCopy(m, base, "Hull", PLANK)
	baseCopy(m, base, "Timber", rgb(46, 34, 26))
	baseCopy(m, base, "Thwarts", rgb(106, 84, 64))
	baseCopy(m, base, "Iron", IRON)
	baseCopy(m, base, "Rope", rgb(122, 106, 72))
	baseCopy(m, base, "Oar", rgb(50, 38, 32))
	baseCopy(m, base, "OarBlade", rgb(94, 76, 58))
	-- mud and algae at the waterline: a quad strip per metre along the measured hull surface (out 0.04)
	local function band(samples: { any }, side: number)
		for i = 1, #samples - 1 do
			local a, b = samples[i], samples[i + 1]
			for h = 0, 1 do
				-- h 0: the mud (y 1.6 .. 2.0), h 1: the algae (y 2.0 .. 2.4)
				local ya, yb = 1.6 + 0.4 * h, 2.0 + 0.4 * h
				local p00 = Vector3.new(a[1], ya, a[2 + h] + side * 0.04)
				local p01 = Vector3.new(a[1], yb, a[3 + h] + side * 0.04)
				local p10 = Vector3.new(b[1], ya, b[2 + h] + side * 0.04)
				local p11 = Vector3.new(b[1], yb, b[3 + h] + side * 0.04)
				local c = (p00 + p01 + p10 + p11) / 4
				local x = ((p10 + p11) / 2 - (p00 + p01) / 2)
				local y = ((p01 + p11) / 2 - (p00 + p10) / 2)
				local z = x:Cross(y).Unit
				local yy = z:Cross(x).Unit
				local col = if h == 0 then scaled(MUD, rng:NextNumber(0.9, 1.1)) else scaled(ALGAE, rng:NextNumber(0.88, 1.12))
				table.insert(U.Algae, piece("Part", Vector3.new(x.Magnitude + 0.06, y.Magnitude + 0.02, 0.06), CFrame.fromMatrix(c, x.Unit, yy), col))
			end
			-- an algae fringe: 2 small hanging tips under the band's top edge
			for _, f in ipairs({ 0.3, 0.75 }) do
				local zt = (a[4] + (b[4] - a[4]) * f) + side * 0.07
				local tip = Vector3.new(a[1] + (b[1] - a[1]) * f, 2.4, zt)
				table.insert(U.Algae, H.bar(tip, tip + Vector3.new(rng:NextNumber(-0.1, 0.1), -rng:NextNumber(0.3, 0.6), 0), 0.07, scaled(ALGAE, 1.12)))
			end
		end
	end
	band(HULL_HIGH, 1)
	band(HULL_LOW_STERN, -1)
	band(HULL_LOW_BOW, -1)
	-- 2 broken planks on the high side (dark holes, splintered ends) and 2 cracks
	for _, hb in ipairs({ { -1.6, 3.2, 1.0 }, { 2.0, 2.95, 0.8 } }) do
		local z = HIGH_UP[math.floor(hb[1] + 0.5)] or 1.9
		table.insert(U.Rot, piece("Part", Vector3.new(hb[3], 0.34, 0.06), CFrame.new(hb[1], hb[2], z + 0.03), HOLE))
		for _, sx in ipairs({ -1, 1 }) do
			local e = Vector3.new(hb[1] + sx * hb[3] / 2, hb[2], z + 0.05)
			table.insert(U.Rot, piece("WedgePart", Vector3.new(0.06, 0.3, 0.32), CFrame.new(e) * CFrame.Angles(0, rad(sx * 90), rad(sx * 8)), scaled(PLANK, 1.15)))
		end
	end
	for _, cr in ipairs({ { -3.6, 3.4, 1.3, 4 }, { 0.6, 2.75, 1.0, -6 } }) do
		local z = HIGH_UP[math.floor(cr[1] + 0.5)] or 1.9
		table.insert(U.Rot, piece("Part", Vector3.new(cr[3], 0.05, 0.05), CFrame.new(cr[1], cr[2], z + 0.03) * CFrame.Angles(0, 0, rad(cr[4])), HOLE))
	end
	-- moss on the rotten benches and on the high gunwale
	for _, r in ipairs(rows(kit, "Bench")) do
		local top = r.cf * CFrame.new(0, r.size.Y / 2, rng:NextNumber(-0.8, 0.8))
		ST.mossCushion(U.Rot, rng, top, 0.9)
	end
	for _, g in ipairs({ { -3, 4.25 }, { -1, 4.53 }, { 1, 4.51 } }) do
		ST.mossCushion(U.Rot, rng, CFrame.new(g[1], g[2] - 0.05, 1.8), 0.8)
	end
	-- 3 leafy vines hanging over the high side
	for _, v in ipairs({ { -2.5, 4.45, 1.9 }, { -0.2, 4.5, 2.2 }, { 1.4, 4.35, 1.7 } }) do
		ST.leafyVine(U.Vines, U.VineLeaves, rng, Vector3.new(v[1], v[2], 2.08), v[3], 0.5, rgb(62, 92, 40), true)
	end
	-- today's Moss block as a slimy cargo in its place: a sunken crate and a sack under a moss mound, slime drips
	do
		local mb = rows(kit, "Moss")[1]
		local c = mb.cf.Position
		table.insert(U.Cargo, chamfered(Vector3.new(1.5, 1.0, 1.3), CFrame.new(c + Vector3.new(-0.7, -0.15, 0.2)) * CFrame.Angles(rad(-6), rad(18), rad(5)), rgb(70, 54, 38), { "vertical", "topFrontBack", "topSides" }, 0.08))
		blob(U.Cargo, rng, CFrame.new(c + Vector3.new(0.9, -0.05, -0.3)), 0.7, 0.45, 0.6, function(n: Vector3): Color3
			return if n.Y > 0.3 then rgb(120, 104, 70) else rgb(96, 82, 56)
		end)
		blob(U.Cargo, rng, CFrame.new(c + Vector3.new(0, 0.12, 0)), mb.size.X * 0.48, 0.32, mb.size.Z * 0.46, function(n: Vector3): Color3
			return if n.Y > 0.45 then SLIME elseif n.Y > -0.1 then MOSS else scaled(MOSS, 0.75)
		end, 0.1)
		for k = 0, 4 do
			local a = k * 1.25 + 0.3
			local p = c + Vector3.new(math.cos(a) * mb.size.X * 0.42, 0.05, math.sin(a) * mb.size.Z * 0.4)
			table.insert(U.Cargo, H.bar(p, p - Vector3.new(0, rng:NextNumber(0.3, 0.6), 0), 0.08, SLIME))
		end
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, "swamp_rowboat", U, "Algae")
	rootOver(m)
	-- no colliders here: the 2 game copies' Side is 9.1 long (the kit's 9) and one SideBroken sits 0.05 off, so each
	-- copy keeps its own (SR.prepColliders("swamp_rowboat") before the sync)
	return m
end

---------------------------------------------------------------------
-- 04 LILY PADS WITH THE WHITE CUBE (kit MapAssets.Swamp.LilyPad_Swamp_A: 2 Pad cylinders 5.2 and 3.2 across (#385A2E,
-- #5C823A) and the Bloom cube 1.3 x 0.9 x 1.3 #DED6BE turned 45 degrees; nothing collides, is queried or touched; 7.6 x
-- 1.12 x 6; 92 copies: test, kit, Swamp_1 x90 on the water (pivot y -0.48, scales 0.82 .. 1.39); the Bloom is
-- decoration: no script, no prompt, no touch handler, src/ never names it)
---------------------------------------------------------------------
-- DUPLICATED from the jungle lily pads (PropsJungleNature.jungle_lily_pads: the same 2 round pads in the same places,
-- each an n-sided disc with an upturned rim band, a V notch to the centre, a low dome and 5 lighter veins; the jungle
-- kit is the same 2 pads + Bloom). Swamp changes: today's darker swamp greens with a wet slimy sheen (a thin, faintly
-- reflective green film over each pad), 2 ragged holes in the big pad and 1 in the small one, a curled-up edge on each, 3 veins; 2 algae
-- clumps floating at the big pad's rim; the Bloom cube as a pale glowing flower bud
-- in the Bloom's box (place and size kept): 5 pale petals opening round a glowing pearl, 4 dark green sepals. Nothing
-- collides, is queried or touched (as today). Parts: Pads (PrimaryPart), Sheen, Bud, Pearl (Neon)
-- one round pad: as the jungle lilyPad (an n-sided disc w across, the rim band flaring out toward the top, a V notch to
-- the centre, a low dome, 5 lighter veins; top at 0.25), plus `holes` ragged triangular holes through it and a curled
-- edge opposite the notch
local function swampPad(list: { BasePart }, sheen: { BasePart }, rng: Random, frame: CFrame, w: number, n: number, color: Color3, holes: number)
	local r = w / 2
	local planes = { { 0, 1, 0, 0.25, color }, { 0, -1, 0, 0, H.scaled(color, 0.7) } }
	for k = 0, n - 1 do
		local a = (k + 0.5) * 2 * math.pi / n
		local nrm = Vector3.new(math.cos(a), -0.35, math.sin(a)).Unit
		table.insert(planes, { nrm.X, nrm.Y, nrm.Z, nrm:Dot(Vector3.new(math.cos(a) * r, 0.25, math.sin(a) * r)), H.scaled(color, 0.86) })
	end
	local notch = rng:NextNumber(0, 2 * math.pi)
	local negs = {}
	local e1 = Vector3.new(math.cos(notch - 0.22), 0, math.sin(notch - 0.22)) * (r + 0.3)
	local e2 = Vector3.new(math.cos(notch + 0.22), 0, math.sin(notch + 0.22)) * (r + 0.3)
	H.triangleParts(negs, Vector3.zero, e1, e2, 1, frame * CFrame.new(0, 0.12, 0), H.scaled(color, 0.8))
	-- the ragged holes: a small irregular triangle each, between the veins
	for h = 1, holes do
		local a = notch + (h + 0.5) * 2 * math.pi / (holes + 1.4)
		local c = Vector3.new(math.cos(a), 0, math.sin(a)) * r * rng:NextNumber(0.45, 0.62)
		local s = r * rng:NextNumber(0.1, 0.14)
		local p1 = c + Vector3.new(math.cos(a + 0.4), 0, math.sin(a + 0.4)) * s
		local p2 = c + Vector3.new(math.cos(a + 2.5), 0, math.sin(a + 2.5)) * s * 0.9
		local p3 = c + Vector3.new(math.cos(a + 4.3), 0, math.sin(a + 4.3)) * s * 1.1
		H.triangleParts(negs, p1, p2, p3, 1, frame * CFrame.new(0, 0.12, 0), H.scaled(color, 0.6))
	end
	table.insert(list, H.convexSolid(Vector3.new(-r - 0.2, 0, -r - 0.2), Vector3.new(r + 0.2, 0.25, r + 0.2), frame, color, planes, nil, negs))
	table.insert(list, M.frustumN(8, r * 0.18, r * 0.05, 0.2, 0.31, frame, { H.scaled(color, 1.05), color }))
	local vein = color:Lerp(Color3.new(1, 1, 1), 0.16)
	for k = 1, 5, 2 do -- 3 veins (92 copies: the budget)
		local a = notch + k * 2 * math.pi / 6
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local p0, p1 = d * r * 0.15, d * r * 0.82
		table.insert(list, piece("Part", Vector3.new(0.08, 0.03, (p1 - p0).Magnitude), frame * CFrame.lookAt((p0 + p1) / 2 + Vector3.new(0, 0.255, 0), p1 + Vector3.new(0, 0.255, 0)), vein))
	end
	-- the curled edge opposite the notch: 2 strips rolling up from the rim
	local ca = notch + math.pi
	local cd = Vector3.new(math.cos(ca), 0, math.sin(ca))
	local cw = r * 0.55
	for k = 0, 1 do
		local rr = r * (0.9 + 0.08 * k)
		local p = cd * rr + Vector3.new(0, 0.24 + 0.12 * k, 0)
		table.insert(list, piece("Part", Vector3.new(cw * (1 - 0.25 * k), 0.06, 0.24), frame * CFrame.lookAt(p, p + cd) * CFrame.Angles(rad(30 + 35 * k), 0, 0), H.scaled(color, 1.08 - 0.12 * k)))
	end
	-- the wet sheen: a thin, faintly reflective green film just over the top
	table.insert(sheen, M.frustumN(n, r * 0.84, r * 0.84, 0.25, 0.27, frame * CFrame.Angles(0, rad(180 / n), 0), { H.scaled(color, 1.3) }))
end

function SR.swamp_lily_pads(): Model
	local kit = "LilyPad_Swamp_A"
	local m = Instance.new("Model")
	m.Name = "swamp_lily_pads"
	local rng = Random.new(20261504)
	H.setBevelSelf(true)
	local U: any = { Pads = {}, Sheen = {}, Bud = {}, Pearl = {} }
	local pads = rows(kit, "Pad")
	table.sort(pads, function(a: any, b: any): boolean
		return a.size.Y > b.size.Y
	end)
	for i, p in ipairs(pads) do
		local c = p.cf.Position
		swampPad(U.Pads, U.Sheen, rng, CFrame.new(c.X, c.Y - p.size.X / 2, c.Z), p.size.Y, if i == 1 then 14 else 11, p.color, if i == 1 then 2 else 1)
	end
	-- algae clumps floating at the big pad's rim
	local big = pads[1]
	local bc = big.cf.Position
	for _, a in ipairs({ 2.6, 4.6 }) do
		local p = bc + Vector3.new(math.cos(a), 0, math.sin(a)) * (big.size.Y / 2 - 0.05)
		blob(U.Pads, rng, CFrame.new(p.X, bc.Y - 0.02, p.Z), 0.42, 0.1, 0.3, function(n: Vector3): Color3
			return if n.Y > 0.3 then rgb(84, 112, 44) else rgb(52, 74, 34)
		end, 0.05)
	end
	-- the Bloom as a pale glowing bud in its box (1.3 x 0.9 x 1.3): sepals, petals opening round a glowing pearl
	do
		local b = rows(kit, "Bloom")[1]
		local bf = b.cf * CFrame.new(0, -b.size.Y / 2, 0) -- the bud's foot on the pad
		local hw, h = b.size.X / 2, b.size.Y
		local SEPAL = rgb(46, 84, 40)
		local PETAL = rgb(232, 240, 222) -- #E8F0DE
		for k = 0, 3 do
			local a = k * 2 * math.pi / 4
			local d = (bf:VectorToWorldSpace(Vector3.new(math.cos(a), 0, math.sin(a))))
			leaf(U.Bud, bf.Position + d * 0.12 + Vector3.new(0, 0.04, 0), (d * 0.9 + UP * 0.25).Unit, hw * 0.95, 0.36, scaled(SEPAL, 0.95 + 0.04 * (k % 3)), UP)
		end
		for k = 0, 4 do
			local a = (k + 0.5) * 2 * math.pi / 5
			local d = bf:VectorToWorldSpace(Vector3.new(math.cos(a), 0, math.sin(a)))
			-- a petal rising from the foot, opening a little round the pearl
			leaf(U.Bud, bf.Position + d * 0.2 + Vector3.new(0, 0.06, 0), (UP + d * 0.2).Unit, h * 0.75, 0.4, scaled(PETAL, 0.94 + 0.03 * (k % 3)), d)
		end
		blob(U.Pearl, rng, bf * CFrame.new(0, h * 0.55, 0), 0.3, 0.32, 0.3, function(): Color3
			return rgb(214, 255, 226)
		end)
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	M.finish(m, "swamp_lily_pads", U, "Pads", { Sheen = { transparency = 0.6, shadow = false }, Pearl = { material = Enum.Material.Neon, shadow = false } })
	local film = m:FindFirstChild("Sheen") :: BasePart?
	if film then
		film.Reflectance = 0.2 -- wet and slimy, still green (Glass mirrored the sky blue)
	end
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		end
	end
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table; its install() builds them
---------------------------------------------------------------------
SR.BUILDERS = { swamp_barrel = true, swamp_scarecrow = true, swamp_rowboat = true, swamp_lily_pads = true }
for id in pairs(SR.BUILDERS) do
	B2[id] = (SR :: any)[id]
	B2.BUILDERS[id] = true
end
SR.install = B2.install
SR.stats = B2.stats

return SR
