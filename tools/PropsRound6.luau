--[[
	PropsRound6 (dev tool, Edit mode only) - owner prompt "ROUND 6" Task A: the armoured knight statues hold their
	sword. Source of truth: tools/PropsRound6.luau (= ServerStorage.DevTools.PropsRound6).

	Usage (execute_luau, Edit):
		local P = require(game.ServerStorage.DevTools.PropsRound6:Clone())
		print(P.iceKnight())          -- A pilot: tundra_ice_knight, both gauntlets round the grip of a planted sword
		print(P.angelStatue())        -- heaven_statue_angel_statue: fists round the planted gold sword
		print(P.demonStatue())        -- hell_statue_demon_statue: clawed fists round the planted dark sword
		print(P.voyagerStatue())      -- void_statue_voyager_statue: the hand round the staff
		print(P.tridentStatue())      -- abyss_statue_trident_statue: the hand round the trident shaft
		then Sync.run({ only = { id } }) syncs the copies (map, arena, preview samples).
	Every builder installs its model with P.install(): the old template goes to ServerStorage.MapProps._Previous.
]]
local ServerStorage = game:GetService("ServerStorage")

local P = {}

local rgb = Color3.fromRGB
local rad = math.rad

local function folder(): Folder
	return ServerStorage:FindFirstChild("MapProps") :: Folder
end

-- the new template replaces the old one (kept in _Previous)
function P.install(id: string, model: Model): Model
	local mapProps = folder()
	local old = mapProps:FindFirstChild(id)
	if old then
		local previous = mapProps:FindFirstChild("_Previous") or Instance.new("Folder")
		previous.Name = "_Previous"
		previous.Parent = mapProps
		local stale = previous:FindFirstChild(id)
		if stale then
			stale:Destroy()
		end
		old.Parent = previous
	end
	model.Name = id
	model:SetAttribute("MapPropId", id)
	model.Parent = mapProps
	return model
end

local LIB = nil
local function lib(): any
	if not LIB then
		local TM = require(ServerStorage.DevTools.PropsTundraMonuments:Clone()) :: any
		local TG = require(ServerStorage.DevTools.PropsTundraGates:Clone()) :: any
		local TB = TG.TB
		LIB = { TM = TM, TG = TG, TB = TB, H = TB.H, M = TB.M, GS = TG.GS }
	end
	return LIB
end
P.lib = lib

-- a limb segment from a to b: an 8-sided frustum (r0 at a, r1 at b)
local function limb(list: { BasePart }, a: Vector3, b: Vector3, r0: number, r1: number, colors: { Color3 })
	local L = lib()
	local d = b - a
	table.insert(list, L.M.frustumN(8, r0, r1, 0, d.Magnitude, L.H.frameY(a, d), colors))
end
P.limb = limb

-- a bevelled blade with a centre ridge: a convex solid with a diamond cross-section (w wide along X, t thick along Z),
-- from y0 (the point) to y1 (under the guard), the point tapering over `tipLen`
local function blade(list: { BasePart }, cf: CFrame, w: number, t: number, y0: number, y1: number, tipLen: number, color: Color3)
	local L = lib()
	local H = L.H
	local planes = {}
	local function plane(n: Vector3, p: Vector3)
		local u = n.Unit
		table.insert(planes, { n = u, d = u:Dot(p) })
	end
	plane(Vector3.new(0, 1, 0), Vector3.new(0, y1, 0))
	-- the 4 bevelled faces (ridge on Z = 0, edges at X = +-w/2)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			plane(Vector3.new(sx * t / 2, 0, sz * w / 2), Vector3.new(sx * w / 2, 0, 0))
		end
		-- the point: the edges run in to the tip over tipLen
		plane(Vector3.new(sx, -(w / 2) / tipLen, 0), Vector3.new(0, y0, 0))
	end
	L.TB.solidOf(list, cf, Vector3.new(-w / 2, y0, -t / 2), Vector3.new(w / 2, y1, t / 2), planes, function(n: Vector3): Color3
		if n.Y > 0.5 then
			return H.scaled(color, 0.9)
		end
		return if n.Z < 0 then H.scaled(color, 1.06) else H.scaled(color, 0.94)
	end)
end
P.blade = blade

-- a gauntlet closed round a vertical grip: a rounded fist the grip runs through, a knuckle ridge and finger grooves on
-- the front, a back-of-hand plate, a thumb over the top; grip at gp (radius gr), the hand coming in from side sx (+1:
-- from +X), hand height h
local function gauntlet(list: { BasePart }, gp: Vector3, gr: number, sx: number, h: number, color: Color3, light: Color3)
	local H = lib().H
	local ALL = { "vertical", "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }
	-- the closed fist: a rounded block round the grip (the grip runs through it), a little toward the arm's side
	table.insert(list, H.chamfered(Vector3.new(1.15, h - 0.04, 0.95), CFrame.new(gp.X + sx * 0.12, gp.Y, gp.Z), color, ALL, 0.22))
	-- the knuckle ridge down the front of the fingers (the side away from the arm) and 2 finger grooves
	table.insert(list, H.chamfered(Vector3.new(0.22, h - 0.16, 0.18), CFrame.new(gp.X - sx * 0.36, gp.Y, gp.Z - 0.45), light, { "vertical" }, 0.06))
	for _, dy in ipairs({ -h / 6, h / 6 }) do
		table.insert(list, H.piece("Part", Vector3.new(0.5, 0.045, 0.04), CFrame.new(gp.X - sx * 0.02, gp.Y + dy, gp.Z - 0.49), H.scaled(color, 0.55)))
	end
	-- the plate on the back of the hand (the arm's side) and the thumb over the top of the fist
	table.insert(list, H.chamfered(Vector3.new(0.16, h * 0.8, 0.8), CFrame.new(gp.X + sx * 0.74, gp.Y, gp.Z), light, { "vertical", "topSides", "bottomSides" }, 0.06))
	table.insert(list, H.chamfered(Vector3.new(0.56, 0.18, 0.42), CFrame.new(gp.X + sx * 0.12, gp.Y + h / 2 + 0.05, gp.Z - 0.14), light, { "topFrontBack", "topSides" }, 0.06))
end
P.gauntlet = gauntlet

---------------------------------------------------------------------
-- A PILOT: the ice knight in its glass case (tundra_ice_knight). The round-4 build (PropsTundraMonuments
-- .tundra_ice_knight: plinth, case, lid, crystals, legs, torso, sash, pauldrons, helm, visor, plume) kept as it is;
-- the arms and the sword are new: the knight rests on his sword - a slightly smaller sword planted in the plinth in
-- front of him (point in an ice crack on the plinth top, the crossguard at chest height), both forearms forward and
-- bent at the elbows, the two gauntlets closed round the grip one over the other right above the crossguard. Armour
-- follows the pose: rerebraces, couters at the elbows, vambraces, flared cuffs. Colliders: today's Plinth and glass
-- case (invisible copies, unchanged).
---------------------------------------------------------------------
function P.iceKnight(): string
	local id = "tundra_ice_knight"
	local L = lib()
	local TM, TG, TB, H, M, GS = L.TM, L.TG, L.TB, L.H, L.M, L.GS
	local piece, chamfered, scaled, frustumN = H.piece, H.chamfered, H.scaled, M.frustumN
	local rowsNamed, plate = TM.rowsNamed, TM.plate
	local cap, facetPiece = TG.cap, TB.facetPiece
	local m = Instance.new("Model")
	m.Name = id
	local rng = Random.new(20261702)
	H.setBevelSelf(true)
	local U: any = { Plinth = {}, Armor = {}, Arms = {}, Gold = {}, Glow = {}, Glass = {}, IceFrame = {}, Ice = {}, Snow = {}, Wood = {}, Blade = {} }
	local kit = "Frozen_Knight_Statue"
	local function row(name: string, i: number?): any
		return rowsNamed(kit, name)[i or 1]
	end
	local NEON_CYAN = rgb(96, 190, 255)
	local STEEL, STEEL2 = row("Leg").color, row("Torso").color
	local GOLD = row("Belt").color
	local SASH = rgb(70, 140, 70)
	local LIGHT = scaled(STEEL2, 1.25)
	local ICE_BLADE = rgb(206, 232, 250)
	-- the plinth (as round 4)
	local pl = row("Plinth")
	table.insert(U.Plinth, chamfered(Vector3.new(8, 0.5, 8), CFrame.new(0, 0.25, 0), scaled(pl.color, 0.9), { "topFrontBack", "topSides" }, 0.15))
	table.insert(U.Plinth, chamfered(Vector3.new(7.5, 1.15, 7.5), CFrame.new(0, 1.07, 0), pl.color, { "vertical" }, 0.25))
	table.insert(U.Plinth, chamfered(Vector3.new(8, 0.4, 8), CFrame.new(0, 1.8, 0), scaled(pl.color, 1.08), { "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.14))
	for k = 0, 3 do
		local a = k * math.pi / 2
		local n = Vector3.new(math.sin(a), 0, -math.cos(a))
		local side = Vector3.new(math.cos(a), 0, math.sin(a))
		local c = n * 3.78 + Vector3.new(0, 1.07, 0)
		for _, e in ipairs({ { 0.45, 2.6 }, { -0.45, 2.6 } }) do
			table.insert(U.Plinth, piece("Part", Vector3.new(e[2] * 2, 0.14, 0.12), CFrame.fromMatrix(c + Vector3.new(0, e[1], 0), side, Vector3.yAxis), scaled(pl.color, 1.15)))
		end
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(U.Plinth, piece("Part", Vector3.new(0.14, 0.9, 0.12), CFrame.fromMatrix(c + side * sx * 2.6, side, Vector3.yAxis), scaled(pl.color, 1.15)))
		end
		table.insert(U.Plinth, piece("Part", Vector3.new(0.5, 0.5, 0.1), CFrame.fromMatrix(c + n * 0.02, side, Vector3.yAxis) * CFrame.Angles(0, 0, rad(45)), GOLD))
	end
	-- legs (as round 4)
	for _, r in ipairs(rowsNamed(kit, "Leg")) do
		local x = r.cf.Position.X
		table.insert(U.Armor, chamfered(Vector3.new(1.5, 0.55, 2.2), CFrame.new(x, 2.28, -0.25), scaled(STEEL, 0.9), { "topFrontBack", "topSides" }, 0.2))
		table.insert(U.Armor, frustumN(8, 0.62, 0.75, 2.5, 4.2, CFrame.new(x, 0, 0) * CFrame.Angles(0, rad(22.5), 0), { STEEL, scaled(STEEL, 1.12), scaled(STEEL, 0.9) }))
		table.insert(U.Armor, frustumN(8, 0.42, 0.3, -0.15, 0.25, H.frameY(Vector3.new(x, 4.35, -0.72), -Vector3.zAxis), { LIGHT, STEEL }))
		table.insert(U.Armor, frustumN(8, 0.76, 0.82, 4.25, 6.05, CFrame.new(x, 0, 0) * CFrame.Angles(0, rad(22.5), 0), { STEEL2, scaled(STEEL2, 1.1), scaled(STEEL2, 0.9) }))
	end
	-- torso, belt, sash, tassets (as round 4)
	table.insert(U.Armor, chamfered(Vector3.new(4.0, 2.6, 2.2), CFrame.new(0, 8.9, 0), STEEL2, { "vertical", "topFrontBack", "bottomFrontBack" }, 0.35))
	table.insert(U.Armor, chamfered(Vector3.new(3.6, 1.6, 2.0), CFrame.new(0, 6.95, 0), scaled(STEEL2, 0.92), { "vertical", "bottomFrontBack" }, 0.3))
	table.insert(U.Armor, piece("Part", Vector3.new(0.35, 2.4, 0.35), CFrame.new(0, 8.9, -1.05) * CFrame.Angles(0, rad(45), 0), LIGHT))
	local belt = row("Belt")
	table.insert(U.Gold, chamfered(belt.size, belt.cf, GOLD, { "topFrontBack", "bottomFrontBack" }, 0.12))
	table.insert(U.Gold, chamfered(Vector3.new(0.8, 0.8, 0.2), CFrame.new(0, 6.3, -1.25), scaled(GOLD, 0.9), { "frontFace" }, 0.1))
	table.insert(U.Wood, piece("Part", Vector3.new(4.32, 0.5, 2.52), CFrame.new(0, 6.95, 0) * CFrame.Angles(0, 0, rad(-6)), SASH))
	table.insert(U.Wood, frustumN(6, 0.32, 0.38, -0.25, 0.25, H.frameY(Vector3.new(-1.75, 6.75, -1.25), -Vector3.zAxis), { SASH, scaled(SASH, 0.9) }))
	for _, t in ipairs({ { -1.95, 0.2, 1.7 }, { -1.55, -0.25, 1.4 } }) do
		table.insert(U.Wood, piece("Part", Vector3.new(0.45, t[3], 0.12), CFrame.new(t[1], 6.65 - t[3] / 2, -1.32) * CFrame.Angles(0, 0, rad(t[2] * 20)), scaled(SASH, 0.95)))
	end
	for _, sx in ipairs({ -1, 1 }) do
		plate(U.Armor, Vector3.new(sx * 1.0, 5.9, -1.15), Vector3.new(sx * 1.15, 4.6, -1.0), 1.45, 0.2, Vector3.new(sx * 0.1, 0.15, -1).Unit, scaled(STEEL2, 0.95))
	end
	-- pauldrons (3 lames; round 4's reached 0.3 past the side glass: now 0.3 further in and a little smaller, so
	-- nothing touches the case)
	for _, r in ipairs(rowsNamed(kit, "Shoulder")) do
		local p = r.cf.Position
		local sx = math.sign(p.X)
		for k = 0, 2 do
			table.insert(U.Armor, frustumN(8, 1.12 - k * 0.16, 0.86 - k * 0.13, 0, 0.42, H.frameY(Vector3.new(p.X - sx * 0.3 + sx * (0.05 - k * 0.12), p.Y + 0.15 + k * 0.32, p.Z), Vector3.new(sx * 0.55, 1, 0).Unit), { if k == 2 then LIGHT else STEEL, scaled(STEEL, 1.1) }))
		end
	end
	-- THE SWORD: a little smaller, planted in the plinth in front of the knight; crossguard at chest height
	local SX, SZ = 0, -2.0 -- the sword's line (in front of the breastplate, well inside the case)
	local plinthTop = 2.0
	local guardY = 8.4 -- (chest height: the breastplate runs 7.6 .. 10.2, the sash 6.7 .. 7.2)
	local gripR = 0.17
	local handH = 0.85
	local grip0 = guardY + 0.18
	local grip1 = grip0 + 2 * handH + 0.2 -- (2 fists and a short gold collar above them)
	blade(U.Blade, CFrame.new(SX, 0, SZ), 0.44, 0.16, plinthTop - 0.9, guardY - 0.18, 0.9, ICE_BLADE)
	-- the ricasso and the crossguard (gold, bevelled, with turned-down quillon ends)
	table.insert(U.Gold, chamfered(Vector3.new(2.0, 0.34, 0.42), CFrame.new(SX, guardY, SZ), GOLD, { "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }, 0.1))
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Gold, chamfered(Vector3.new(0.3, 0.5, 0.44), CFrame.new(SX + sx * 1.0, guardY - 0.12, SZ), scaled(GOLD, 0.9), { "vertical", "bottomFrontBack", "bottomSides" }, 0.1))
	end
	table.insert(U.Gold, chamfered(Vector3.new(0.5, 0.3, 0.3), CFrame.new(SX, guardY - 0.3, SZ), scaled(GOLD, 0.92), { "bottomFrontBack", "bottomSides" }, 0.08))
	-- the grip: a gold core, a spiral wrap of darker gold bands, the pommel
	table.insert(U.Gold, frustumN(8, gripR, gripR * 0.92, grip0, grip1, CFrame.new(SX, 0, SZ), { scaled(GOLD, 0.95), scaled(GOLD, 0.85) }))
	for k = 0, 6 do
		local y = grip0 + 0.14 + k * (grip1 - grip0 - 0.28) / 6
		table.insert(U.Wood, piece("Part", Vector3.new(gripR * 2 + 0.06, 0.08, gripR * 2 + 0.06), CFrame.new(SX, y, SZ) * CFrame.Angles(0, rad(k * 25), rad(14)), scaled(GOLD, 0.8)))
	end
	table.insert(U.Gold, frustumN(8, 0.24, 0.3, grip1, grip1 + 0.18, CFrame.new(SX, 0, SZ), { scaled(GOLD, 0.9) }))
	table.insert(U.Gold, frustumN(8, 0.3, 0.12, grip1 + 0.18, grip1 + 0.46, CFrame.new(SX, 0, SZ) * CFrame.Angles(0, rad(22.5), 0), { GOLD, scaled(GOLD, 0.88) }))
	-- the point's entry: a small cut in the plinth top with a little ice crack round it
	table.insert(U.Wood, piece("Part", Vector3.new(0.6, 0.03, 0.3), CFrame.new(SX, plinthTop + 0.005, SZ), rgb(24, 46, 90)))
	for k = 0, 4 do
		local a = rad(k * 72 + 20)
		local len = 0.5 + (k % 2) * 0.35
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		table.insert(U.Ice, piece("Part", Vector3.new(len, 0.04, 0.07), CFrame.lookAt(Vector3.new(SX, plinthTop + 0.02, SZ) + dir * (0.3 + len / 2), Vector3.new(SX, plinthTop + 0.02, SZ) + dir * 2) * CFrame.Angles(0, rad(90), 0), rgb(214, 240, 255)))
	end
	-- THE ARMS: shoulder -> elbow (down, out, a little forward) -> wrist (forward, in, up) -> the gauntlets on the grip
	-- (left hand on top, right hand under it, right above the crossguard)
	local lowY = grip0 + handH / 2 -- (the lower fist sits on the crossguard: gap 0.03)
	local highY = lowY + handH
	for _, sx in ipairs({ -1, 1 }) do
		local shoulder = Vector3.new(sx * 2.6, 9.05, -0.05)
		local elbow = Vector3.new(sx * 2.55, 7.45, -1.15)
		local handY = if sx < 0 then highY else lowY
		local gp = Vector3.new(SX, handY, SZ)
		local wrist = Vector3.new(SX + sx * 0.72, handY - 0.05, SZ + 0.05)
		-- rerebrace and vambrace
		limb(U.Arms, shoulder, elbow, 0.56, 0.5, { STEEL2, scaled(STEEL2, 1.1), scaled(STEEL2, 0.9) })
		limb(U.Arms, elbow, wrist, 0.5, 0.42, { STEEL2, scaled(STEEL2, 1.1), scaled(STEEL2, 0.9) })
		-- the couter (an elbow cop with a fan plate) and a band on the vambrace
		table.insert(U.Arms, M.frustumN(8, 0.58, 0.58, -0.3, 0.3, H.frameY(elbow, (elbow - shoulder).Unit:Lerp((wrist - elbow).Unit, 0.5)), { LIGHT, STEEL }))
		local out = (elbow - shoulder):Cross(wrist - elbow).Unit
		if out.Z > 0 then
			out = -out
		end
		table.insert(U.Arms, chamfered(Vector3.new(0.7, 0.7, 0.16), CFrame.lookAt(elbow + Vector3.new(sx * 0.42, 0, 0), elbow + Vector3.new(sx * 2, 0, 0)), scaled(STEEL, 1.05), { "vertical" }, 0.12))
		local band = elbow:Lerp(wrist, 0.45)
		table.insert(U.Arms, M.frustumN(8, 0.47, 0.47, -0.08, 0.08, H.frameY(band, wrist - elbow), { LIGHT }))
		-- the flared cuff at the wrist and the gauntlet round the grip
		table.insert(U.Arms, M.frustumN(8, 0.45, 0.56, -0.32, 0.06, H.frameY(wrist, wrist - elbow), { scaled(STEEL, 0.9), STEEL }))
		gauntlet(U.Arms, gp, gripR, sx, handH, if sx < 0 then scaled(STEEL, 0.95) else scaled(STEEL, 0.88), LIGHT)
	end
	-- the great helm, visor, breath holes, plume (as round 4)
	local hd = row("Head")
	local hp = hd.cf.Position
	table.insert(U.Armor, chamfered(Vector3.new(2.0, 1.75, 2.0), CFrame.new(hp.X, hp.Y - 0.12, hp.Z), STEEL, { "vertical", "bottomFrontBack", "bottomSides" }, 0.3))
	table.insert(U.Armor, frustumN(8, 1.0, 0.55, hp.Y + 0.7, hp.Y + 1.2, CFrame.new(hp.X, 0, hp.Z) * CFrame.Angles(0, rad(22.5), 0), { scaled(STEEL, 1.08), STEEL }))
	table.insert(U.Armor, piece("Part", Vector3.new(0.18, 1.8, 0.25), CFrame.new(hp.X, hp.Y - 0.05, hp.Z - 1.02), LIGHT))
	local vz = row("Visor")
	table.insert(U.Glow, piece("Part", vz.size, vz.cf, NEON_CYAN))
	for _, sx in ipairs({ -0.55, -0.25, 0.25, 0.55 }) do
		table.insert(U.Wood, piece("Part", Vector3.new(0.12, 0.12, 0.1), CFrame.new(hp.X + sx, hp.Y - 0.55, hp.Z - 1.0), rgb(30, 34, 44)))
	end
	local pm = row("Plume")
	for k = 0, 2 do
		local p0 = Vector3.new(0, hp.Y + 1.15 + k * 0.4, 0.2 + k * 0.45)
		table.insert(U.Wood, frustumN(6, 0.3 - k * 0.06, 0.24 - k * 0.06, -0.3, 0.35, H.frameY(p0, Vector3.new(0, 1, 0.5 + k * 0.6).Unit), { pm.color, scaled(pm.color, 0.9), scaled(pm.color, 1.08) }))
	end
	-- the case, lid and crystals (as round 4)
	local ib = row("IceBlock")
	local cp, cs = ib.cf.Position, ib.size
	local yb, yt = cp.Y - cs.Y / 2, cp.Y + cs.Y / 2
	local FR = rgb(170, 220, 245)
	for _, f in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
		local w = if f[1] == 0 then cs.X - 0.7 else cs.Z - 0.7
		local pos = Vector3.new(cp.X + f[1] * (cs.X / 2 - 0.12), cp.Y, cp.Z + f[2] * (cs.Z / 2 - 0.12))
		local size = if f[1] == 0 then Vector3.new(w, cs.Y - 0.8, 0.12) else Vector3.new(0.12, cs.Y - 0.8, w)
		table.insert(U.Glass, piece("Part", size, CFrame.new(pos), rgb(160, 214, 246)))
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.IceFrame, chamfered(Vector3.new(0.5, cs.Y, 0.5), CFrame.new(cp.X + sx * (cs.X / 2 - 0.25), cp.Y, cp.Z + sz * (cs.Z / 2 - 0.25)), FR, { "vertical" }, 0.12))
		end
	end
	for _, y in ipairs({ yb + 0.25, yt - 0.25 }) do
		for _, f in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
			local size = if f[1] == 0 then Vector3.new(cs.X - 0.9, 0.4, 0.4) else Vector3.new(0.4, 0.4, cs.Z - 0.9)
			table.insert(U.IceFrame, chamfered(size, CFrame.new(cp.X + f[1] * (cs.X / 2 - 0.25), y, cp.Z + f[2] * (cs.Z / 2 - 0.25)), scaled(FR, 0.95), { "topFrontBack", "topSides" }, 0.1))
		end
	end
	local lid = row("SnowCap")
	local lp, ls = lid.cf.Position, lid.size
	table.insert(U.Snow, chamfered(Vector3.new(ls.X, 0.35, ls.Z), CFrame.new(lp.X, lp.Y - 0.12, lp.Z), rgb(236, 242, 250), { "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.1))
	for _, f in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
		local size = if f[1] == 0 then Vector3.new(ls.X, 0.22, 0.3) else Vector3.new(0.3, 0.22, ls.Z)
		table.insert(U.Snow, chamfered(size, CFrame.new(lp.X + f[1] * (ls.X / 2 - 0.15), lp.Y + 0.16, lp.Z + f[2] * (ls.Z / 2 - 0.15)), rgb(222, 232, 246), { "topFrontBack", "topSides" }, 0.06))
	end
	cap(U, Vector3.new(lp.X, lp.Y + 0.02, lp.Z), Vector3.new(ls.X - 0.9, 0.42, ls.Z - 0.9), rng:NextNumber(-0.05, 0.05))
	for _, r in ipairs(rowsNamed(kit, "Shard")) do
		local p, sz = r.cf.Position, r.size
		local top = p.Y + sz.Y / 2
		facetPiece(U, GS.tundra_gate4__spire, CFrame.new(p.X, -0.2, p.Z) * CFrame.Angles(0, if p.X < 0 then math.pi else 0, 0), Vector3.one * (top / 17.7), "Ice", "Ice")
	end
	local GLASS = { material = Enum.Material.Glass, transparency = 0.3, shadow = false }
	TB.finishTB(m, id, U, "Plinth", { Glass = { material = Enum.Material.Glass, transparency = 0.5, shadow = false }, Ice = GLASS, Glow = { material = Enum.Material.Neon, shadow = false } })
	TM.collisionRows(m, kit)
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: arms gripping a planted sword, %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

---------------------------------------------------------------------
-- A other statues (the audit: statues holding a weapon that stood beside the hands). Shared pieces: an old template
-- cloned, its loose arms / weapon parts removed (non-colliding) or kept as invisible collision (colliding), new arms
-- (frustum segments shoulder -> elbow -> wrist, a cuff) and closed fists round the grip / shaft (P.gauntlet), the sword
-- rebuilt as for the knight (bevelled blade with a ridge, planted point with a crack, crossguard at chest height, a
-- wrapped grip just 2 fists long, pommel). One union per name.
---------------------------------------------------------------------
local function toCollision(p: BasePart)
	p.Name = "Collision"
	p.Transparency = 1
	p.CastShadow = false
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = false
end

local function mergeAll(m: Model, U: any, opts: any?)
	local H = lib().H
	local names = {}
	for name, list in pairs(U) do
		if #list > 0 then
			table.insert(names, name)
		end
	end
	table.sort(names)
	for _, name in ipairs(names) do
		H.merge(m, name, U[name], (opts and opts[name]) or {})
		task.wait()
	end
	H.setBevelSelf(false)
end

-- an arm from the shoulder over the elbow to a fist round the vertical grip at gp (hand from side sx); r = upper arm
-- radius, k = fist scale; colours: arm, fist, light
local function gripArm(U: any, shoulder: Vector3, elbow: Vector3, gp: Vector3, sx: number, r: number, handH: number, k: number, arm: Color3, fist: Color3, light: Color3)
	local L = lib()
	local H, M = L.H, L.M
	local wrist = Vector3.new(gp.X + sx * 0.72 * k, gp.Y - 0.05, gp.Z + 0.05)
	limb(U.Arms, shoulder, elbow, r, r * 0.9, { arm, H.scaled(arm, 1.08), H.scaled(arm, 0.92) })
	limb(U.Arms, elbow, wrist, r * 0.9, r * 0.75, { arm, H.scaled(arm, 1.08), H.scaled(arm, 0.92) })
	table.insert(U.Arms, M.frustumN(8, r * 1.02, r * 1.02, -r * 0.55, r * 0.55, H.frameY(elbow, (elbow - shoulder).Unit:Lerp((wrist - elbow).Unit, 0.5)), { H.scaled(arm, 0.95) }))
	table.insert(U.Arms, M.frustumN(8, r * 0.8, r, -r * 0.6, r * 0.1, H.frameY(wrist, wrist - elbow), { H.scaled(fist, 0.92), fist }))
	local list = {}
	gauntlet(list, Vector3.zero, 0.17, sx, handH / k, fist, light)
	for _, p in ipairs(list) do
		p.Size *= k
		p.CFrame = CFrame.new(gp) * CFrame.new(p.Position * k) * p.CFrame.Rotation
		table.insert(U.Arms, p)
	end
end
P.gripArm = gripArm

-- a planted sword at (x, z): the point sunk into the floor at floorY (a cut and a crack), the crossguard at guardY, a
-- grip 2 fists long, the pommel; returns the 2 fist centres (lower, upper)
local function plantedSword(U: any, x: number, z: number, floorY: number, guardY: number, handH: number, bw: number, bt: number, guardW: number, bladeColor: Color3, gold: Color3, crack: Color3): (Vector3, Vector3)
	local L = lib()
	local H, M = L.H, L.M
	local chamfered, piece, scaled = H.chamfered, H.piece, H.scaled
	local gr = 0.17 * bw / 0.44
	local grip0 = guardY + 0.18
	local grip1 = grip0 + 2 * handH + 0.2
	blade(U.Blade, CFrame.new(x, 0, z), bw, bt, floorY - 0.5, guardY - 0.18, bw * 2, bladeColor)
	table.insert(U.Gold, chamfered(Vector3.new(guardW, 0.34, 0.42 * bw / 0.44 + 0.02), CFrame.new(x, guardY, z), gold, { "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }, 0.1))
	for _, s in ipairs({ -1, 1 }) do
		table.insert(U.Gold, chamfered(Vector3.new(0.3, 0.5, 0.44 * bw / 0.44), CFrame.new(x + s * guardW / 2, guardY - 0.12, z), scaled(gold, 0.9), { "vertical", "bottomFrontBack", "bottomSides" }, 0.1))
	end
	table.insert(U.Gold, M.frustumN(8, gr, gr * 0.92, grip0, grip1, CFrame.new(x, 0, z), { scaled(gold, 0.95), scaled(gold, 0.85) }))
	for k = 0, 6 do
		local y = grip0 + 0.14 + k * (grip1 - grip0 - 0.28) / 6
		table.insert(U.Gold, piece("Part", Vector3.new(gr * 2 + 0.06, 0.08, gr * 2 + 0.06), CFrame.new(x, y, z) * CFrame.Angles(0, rad(k * 25), rad(14)), scaled(gold, 0.8)))
	end
	table.insert(U.Gold, M.frustumN(8, gr * 1.4, gr * 1.75, grip1, grip1 + 0.18, CFrame.new(x, 0, z), { scaled(gold, 0.9) }))
	table.insert(U.Gold, M.frustumN(8, gr * 1.75, gr * 0.7, grip1 + 0.18, grip1 + 0.46, CFrame.new(x, 0, z) * CFrame.Angles(0, rad(22.5), 0), { gold, scaled(gold, 0.88) }))
	-- the cut and a small crack round the point
	table.insert(U.Crack, piece("Part", Vector3.new(bw + 0.16, 0.03, bt + 0.14), CFrame.new(x, floorY + 0.005, z), crack))
	for k = 0, 4 do
		local a = rad(k * 72 + 20)
		local len = 0.45 + (k % 2) * 0.3
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local c0 = Vector3.new(x, floorY + 0.015, z)
		table.insert(U.Crack, piece("Part", Vector3.new(len, 0.03, 0.06), CFrame.lookAt(c0 + dir * (0.28 + len / 2), c0 + dir * 2) * CFrame.Angles(0, rad(90), 0), crack))
	end
	local lowY = grip0 + handH / 2
	return Vector3.new(x, lowY, z), Vector3.new(x, lowY + handH, z)
end
P.plantedSword = plantedSword

local function cloneTemplate(id: string): Model
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	return old:Clone()
end

local function finish(m: Model, id: string, U: any): string
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	mergeAll(m, U)
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: hands round the weapon, %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

-- the marble angel (heaven_statue_angel_statue): the gold sword planted on the front step (point in the lower plinth,
-- crossguard at chest height), both forearms forward from the elbows, marble fists round the grip one over the other
function P.angelStatue(): string
	local id = "heaven_statue_angel_statue"
	local H = lib().H
	local m = cloneTemplate(id)
	H.setBevelSelf(true)
	local U: any = { Arms = {}, Blade = {}, Gold = {}, Crack = {} }
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") and (c.Name == "Arm" or c.Name == "Blade" or c.Name == "Guard" or c.Name == "Hilt") then
			assert(not c.CanCollide, "angel " .. c.Name .. " collides")
			c:Destroy()
		end
	end
	local MARBLE, MARBLE2, GOLD = rgb(214, 210, 204), rgb(242, 240, 234), rgb(214, 160, 50)
	local handH = 0.8
	local low, high = plantedSword(U, 0, -3.1, 1.5, 9.9, handH, 0.5, 0.2, 2.2, rgb(255, 208, 84), GOLD, rgb(150, 146, 140))
	for _, sx in ipairs({ -1, 1 }) do
		local gp = if sx < 0 then high else low
		gripArm(U, Vector3.new(sx * 1.95, 12.15, -0.3), Vector3.new(sx * 2.45, 9.6, -1.4), gp, sx, 0.46, handH, 1, MARBLE, MARBLE2, H.scaled(MARBLE2, 1.03))
	end
	return finish(m, id, U)
end

-- the demon (hell_statue_demon_statue): its dark sword planted in the plinth top, crossguard at chest height, both
-- clawed fists round the grip; the arms and sword of today stay as invisible collision
function P.demonStatue(): string
	local id = "hell_statue_demon_statue"
	local H = lib().H
	local m = cloneTemplate(id)
	H.setBevelSelf(true)
	local U: any = { Arms = {}, Blade = {}, Gold = {}, Crack = {} }
	local found = 0
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			local p, s = c.Position, c.Size
			local isArm = math.abs(math.abs(p.X) - 3.6) < 0.05 and math.abs(p.Y - 11.6) < 0.05 and math.abs(s.Y - 6) < 0.05
			local isBlade = math.abs(p.X) < 0.05 and math.abs(p.Z + 2.8) < 0.05 and (math.abs(s.Y - 11) < 0.05 or math.abs(s.X - 4) < 0.05)
			if isArm or isBlade then
				toCollision(c)
				found += 1
			end
		end
	end
	assert(found == 4, "demon: " .. found .. " arm / sword parts")
	local SKIN, DARK = rgb(70, 60, 64), rgb(49, 41, 44)
	local handH = 1.0
	local low, high = plantedSword(U, 0, -2.8, 4.0, 12.0, handH, 0.8, 0.3, 3.6, rgb(58, 50, 54), rgb(120, 40, 44), rgb(20, 16, 18))
	for _, sx in ipairs({ -1, 1 }) do
		local gp = if sx < 0 then high else low
		gripArm(U, Vector3.new(sx * 3.45, 14.0, -0.3), Vector3.new(sx * 4.2, 11.3, -1.9), gp, sx, 0.8, handH, 1.25, SKIN, DARK, H.scaled(SKIN, 1.25))
		-- 3 claw tips over the front of each fist
		for k = -1, 1 do
			table.insert(U.Arms, lib().M.frustumN(4, 0.12, 0.02, 0, 0.35, H.frameY(gp + Vector3.new(-sx * 0.3, k * 0.28, -0.62), Vector3.new(0, -0.4, -1).Unit), { rgb(226, 214, 190) }))
		end
	end
	return finish(m, id, U)
end

-- the void voyager (void_statue_voyager_statue): the right hand closed round its staff (it has one arm, by the
-- staff); the staff stays, a socket ring where it meets the plinth
function P.voyagerStatue(): string
	local id = "void_statue_voyager_statue"
	local H = lib().H
	local m = cloneTemplate(id)
	H.setBevelSelf(true)
	local U: any = { Arms = {}, Gold = {}, Crack = {} }
	local arm = m:FindFirstChild("Arm") :: BasePart
	local staff = m:FindFirstChild("Staff") :: BasePart
	assert(arm and staff and not arm.CanCollide, "voyager Arm / Staff")
	local CLOTH = arm.Color
	arm:Destroy()
	local sp = staff.Position
	local gp = Vector3.new(sp.X, 11.7, sp.Z)
	gripArm(U, Vector3.new(1.7, 13.55, -0.05), Vector3.new(2.05, 11.25, 0.05), gp, -1, 0.45, 0.8, 1, CLOTH, H.scaled(CLOTH, 0.9), H.scaled(CLOTH, 1.08))
	table.insert(U.Gold, lib().M.frustumN(8, 0.42, 0.34, sp.Y - staff.Size.Y / 2, sp.Y - staff.Size.Y / 2 + 0.3, CFrame.new(sp.X, 0, sp.Z), { rgb(90, 40, 170) }))
	return finish(m, id, U)
end

-- the trident statue (abyss_statue_trident_statue): the right hand closed round the trident shaft (the shaft stands
-- on the plinth top: a ring there); the right arm of today stays as invisible collision; the left arm holds nothing
function P.tridentStatue(): string
	local id = "abyss_statue_trident_statue"
	local H = lib().H
	local m = cloneTemplate(id)
	H.setBevelSelf(true)
	local U: any = { Arms = {}, Gold = {}, Crack = {} }
	local armColor = nil
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") and math.abs(c.Position.X - 2.9) < 0.05 and math.abs(c.Position.Y - 9.0) < 0.05 then
			armColor = c.Color
			toCollision(c)
		end
	end
	assert(armColor, "trident: right arm not found")
	local gp = Vector3.new(3.4, 9.6, -1.4)
	gripArm(U, Vector3.new(2.3, 10.0, -0.1), Vector3.new(2.8, 8.1, 0.05), gp, -1, 0.5, 0.85, 1.05, armColor, H.scaled(armColor, 0.92), H.scaled(armColor, 1.08))
	table.insert(U.Gold, lib().M.frustumN(8, 0.42, 0.34, 2.5, 2.8, CFrame.new(3.4, 0, -1.4), { rgb(214, 160, 50) }))
	return finish(m, id, U)
end

return P
