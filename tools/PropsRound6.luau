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
		print(P.plainsBossGate())     -- R6 01: plains_gate_boss_gate, cut blue stone, carved lintel / door
		print(P.campfire())           -- R6 02: hub_light_campfire_a + biome Variants
		print(P.campfireVariants())   -- R6 02: Variant attribute on every campfire copy by zone
		print(P.cottageShutters("cottage_two_windows"))  -- R6 03: the shutters in front of the beams (and cottage_one_window, 04)
		print(P.compareExceptShutters(id))  -- R6 03 / 04: every other part unchanged against _Previous
		print(P.plainsArenaDoor())     -- R6 05: plains_gate_door, blue stone frame, carved double door on both faces
		print(P.mineSupport())        -- R6 06: plains_prop_mine_support, timber frame, iron fish plates, lantern
		print(P.ropeBridge(), P.floatingDock()) -- R6 07 / 08: jungle rope bridge section, floating dock (docks recipe)
		print(P.giantTree())          -- R6 09: jungle_landmark_giant_tree, swamp tree recipe at landmark scale
		print(P.tundraTorch())        -- R6 10: tundra_light_blue_torch_wall = the improved wall_torch in tundra colours
		print(P.frozenTree())         -- R6 11: tundra_landmark_frozen_tree, dead tree in ice
		print(P.giantCauldron())      -- R6 12: swamp_landmark_giant_cauldron, the swamp cauldron recipe at landmark scale
		print(P.swampCrate(), P.swampFence(), P.swampSign(), P.swampSignVariants(), P.swampBonePile()) -- R6 13-16: swamp recolours of improved bases
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

---------------------------------------------------------------------
-- ROUND 6 ASSETS (owner prompt "ROUND 6: ASSET PREVIEW - 18 MORE ASSETS"). Shared helpers for this part.
---------------------------------------------------------------------
-- cut stone blocks (running bond, bevelled, 3 tones and a gradient) on the listed faces of a box part: "front" -Z,
-- "back" +Z, "left" -X, "right" +X; y0 .. y1 world heights; ch = course height
local function stoneBox(list: { BasePart }, rng: Random, p: BasePart, faces: { string }, y0: number, y1: number, ch: number, color: Color3, Ht: number)
	local TG = lib().TG
	local c, s = p.Position, p.Size
	local frames = {
		front = { CFrame.new(c.X, 0, c.Z - s.Z / 2), s.X },
		back = { CFrame.new(c.X, 0, c.Z + s.Z / 2) * CFrame.Angles(0, math.pi, 0), s.X },
		-- (the face frame's -Z points out of the part: +90 degrees for the -X face, -90 for the +X face)
		left = { CFrame.new(c.X - s.X / 2, 0, c.Z) * CFrame.Angles(0, math.rad(90), 0), s.Z },
		right = { CFrame.new(c.X + s.X / 2, 0, c.Z) * CFrame.Angles(0, math.rad(-90), 0), s.Z },
	}
	for _, f in ipairs(faces) do
		local fr = frames[f]
		-- (set 0.55 into the part, so the blocks' faces sit at the old face and today's glyphs stay in front)
		TG.iceFace(list, rng, fr[1] * CFrame.new(0, 0, 0.55), -fr[2] / 2, fr[2] / 2, y0, y1, ch, color, Ht)
	end
end
P.stoneBox = stoneBox

-- a frame of 4 bars round a square glow turned 45 degrees (cf = the glow's CFrame, s = its side)
local function diamondFrame(list: { BasePart }, cf: CFrame, s: number, w: number, depth: number, color: Color3)
	local H = lib().H
	for _, e in ipairs({ { 0, s / 2 + w / 2, s + 2 * w, w }, { 0, -s / 2 - w / 2, s + 2 * w, w }, { s / 2 + w / 2, 0, w, s }, { -s / 2 - w / 2, 0, w, s } }) do
		table.insert(list, H.piece("Part", Vector3.new(e[3], e[4], depth), cf * CFrame.new(e[1], e[2], 0), color))
	end
end
P.diamondFrame = diamondFrame

local function children(m: Model, name: string): { BasePart }
	local t = {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") and c.Name == name then
			table.insert(t, c)
		end
	end
	return t
end

local function finishR6(m: Model, id: string, U: any, opts: any?): string
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	mergeAll(m, U, opts)
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

---------------------------------------------------------------------
-- 01 PLAINS BOSS GATE (plains_gate_boss_gate, Plains_4): the improved plains / tundra gate recipe in the blue stone of
-- today: the 2 pillars as cut stone blocks (front and sides) on a bevelled plinth with a capital under the lintel,
-- the lintel in 2 courses of cut stone with carved frames round the 5 glowing diamonds, a bevelled cornice with
-- dentils, the double door kept with stone frames, a carved ring round the glowing face and studs, the threshold as
-- jointed steps (its glowing edge strips kept). Every rune, glow, light and the map copy's prompt are kept; today's
-- pillars, bases, lintel, cap and threshold stay as invisible collision; the doors stay as they are (they block).
---------------------------------------------------------------------
function P.plainsBossGate(): string
	local id = "plains_gate_boss_gate"
	local L = lib()
	local H, M = L.H, L.M
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(60101)
	H.setBevelSelf(true)
	local STONE, DARK, LIGHT = rgb(104, 110, 124), rgb(62, 60, 78), rgb(150, 156, 168)
	local U: any = { Stone = {}, Stone2 = {}, Carving = {}, Trim = {}, DoorTrim = {} }
	local Ht = 48
	for _, name in ipairs({ "PillarL", "PillarR" }) do
		local p = m:FindFirstChild(name) :: BasePart
		local c, s = p.Position, p.Size
		toCollision(p)
		table.insert(U.Carving, H.piece("Part", s - Vector3.new(0.4, 0.2, 0.4), p.CFrame, DARK))
		stoneBox(if name == "PillarL" then U.Stone else U.Stone2, rng, p, { "front", if name == "PillarL" then "left" else "right", if name == "PillarL" then "right" else "left" }, c.Y - s.Y / 2 + 3, 16.6, 2.6, STONE, Ht)
		-- capital under the lintel, a band at mid height
		table.insert(U.Trim, H.chamfered(Vector3.new(s.X + 1.0, 1.4, s.Z + 1.0), CFrame.new(c.X, 17.3, c.Z), H.scaled(DARK, 1.15), { "vertical", "bottomFrontBack", "bottomSides" }, 0.3))
		table.insert(U.Trim, H.chamfered(Vector3.new(s.X + 0.5, 0.8, s.Z + 0.5), CFrame.new(c.X, -0.2, c.Z), H.scaled(DARK, 1.15), { "vertical", "topFrontBack", "topSides" }, 0.2))
	end
	for _, name in ipairs({ "BaseL", "BaseR" }) do
		local p = m:FindFirstChild(name) :: BasePart
		toCollision(p)
		table.insert(U.Trim, H.chamfered(p.Size, p.CFrame, DARK, { "vertical", "topFrontBack", "topSides" }, 0.45))
		table.insert(U.Trim, H.chamfered(Vector3.new(p.Size.X - 1.6, 0.6, p.Size.Z - 1.6), p.CFrame * CFrame.new(0, p.Size.Y / 2 + 0.3, 0), H.scaled(DARK, 1.12), { "vertical", "topFrontBack", "topSides" }, 0.2))
	end
	-- the lintel: a dark core, 2 courses of cut stone on the front, carved frames round the 5 diamonds
	local li = m:FindFirstChild("Lintel") :: BasePart
	toCollision(li)
	table.insert(U.Carving, H.piece("Part", li.Size - Vector3.new(0.4, 0.2, 0.4), li.CFrame, DARK))
	stoneBox(U.Stone, rng, li, { "front", "left", "right" }, li.Position.Y - li.Size.Y / 2, li.Position.Y + li.Size.Y / 2, 4.5, STONE, Ht)
	for _, r in ipairs(children(m, "Rune")) do
		if math.abs(r.Position.Y - 22.5) < 0.1 then
			diamondFrame(U.DoorTrim, r.CFrame * CFrame.new(0, 0, 0.05), r.Size.X, 0.5, 0.4, H.scaled(DARK, 1.2))
		end
	end
	-- the cornice: a bevelled cap with a row of dentils under its front edge
	local cap = m:FindFirstChild("LintelCap") :: BasePart
	toCollision(cap)
	table.insert(U.Trim, H.chamfered(cap.Size, cap.CFrame, DARK, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.4))
	for k = 0, 24 do
		local x = cap.Position.X - cap.Size.X / 2 + 1.4 + k * (cap.Size.X - 2.8) / 24
		table.insert(U.Trim, H.piece("Part", Vector3.new(0.9, 0.6, 0.5), CFrame.new(x, cap.Position.Y - cap.Size.Y / 2 - 0.3, cap.Position.Z - cap.Size.Z / 2 + 0.6), H.scaled(DARK, 1.1)))
	end
	-- the door leaves: a stone frame round each leaf and studs; a carved ring round the glowing face
	for _, name in ipairs({ "DoorL", "DoorR" }) do
		local d = m:FindFirstChild(name) :: BasePart
		local c, s = d.Position, d.Size
		local zf = c.Z - s.Z / 2 - 0.12
		for _, e in ipairs({ { 0, s.Y / 2 - 0.5, s.X, 1.0 }, { 0, -s.Y / 2 + 0.5, s.X, 1.0 }, { -s.X / 2 + 0.5, 0, 1.0, s.Y - 2 }, { s.X / 2 - 0.5, 0, 1.0, s.Y - 2 } }) do
			table.insert(U.DoorTrim, H.chamfered(Vector3.new(e[3], e[4], 0.3), CFrame.new(c.X + e[1], c.Y + e[2], zf), H.scaled(STONE, 1.05), { "frontFace" }, 0.12))
		end
		for _, sy in ipairs({ -1, 1 }) do
			for k = -2, 2 do
				table.insert(U.DoorTrim, H.chamfered(Vector3.new(0.5, 0.5, 0.25), CFrame.new(c.X + k * 2.6, c.Y + sy * (s.Y / 2 - 0.5), zf - 0.2), DARK, { "frontFace" }, 0.1))
			end
		end
	end
	local fc = Vector3.new(7.5, 5.0, -1.62)
	for k = 0, 15 do
		local a = k * math.pi / 8
		local r0 = 9.2 -- (outside the rune octagon, r 8)
		local p = fc + Vector3.new(math.cos(a) * r0, math.sin(a) * r0, 0)
		table.insert(U.DoorTrim, H.piece("Part", Vector3.new(2 * r0 * math.sin(math.pi / 16) + 0.1, 0.7, 0.2), CFrame.new(p) * CFrame.Angles(0, 0, a + math.pi / 2), H.scaled(STONE, 0.9)))
	end
	-- the threshold: jointed steps (its glowing edge strips stay)
	local th = m:FindFirstChild("Threshold") :: BasePart
	toCollision(th)
	local n = 5
	for k = 0, n - 1 do
		local w = th.Size.X / n
		table.insert(U.Trim, H.chamfered(Vector3.new(w - 0.12, th.Size.Y, th.Size.Z), th.CFrame * CFrame.new(-th.Size.X / 2 + (k + 0.5) * w, 0, 0), H.scaled(DARK, ({ 1.0, 1.08, 0.94 })[k % 3 + 1]), { "vertical", "topFrontBack", "topSides" }, 0.1))
	end
	return finishR6(m, id, U)
end

---------------------------------------------------------------------
-- 02 CAMPFIRE (hub_light_campfire_a; the hub AFK corner and every zone's camps): a ring of 9 faceted stones in 2
-- tones, 3 crossed 8-sided logs with bark facets and light cut ends, a bed of ash with glowing coal chips, a layered
-- stylized flame (3 nested Neon cones and 2 side tongues). Today's Embers disc (PointLight, FirePoint for the fire VFX)
-- is kept exactly; today's stones and logs stay as invisible collision. Biome looks are template Variants (attribute
-- Variant on each copy): Desert (sandy stones, sandy ash), Jungle (mossy stones, moss tufts), Tundra (blue-grey stones,
-- a snow ring), Volcano (basalt stones, dark ash); the hub and the plains keep the default grey stones.
---------------------------------------------------------------------
function P.campfire(): string
	local id = "hub_light_campfire_a"
	local L = lib()
	local H, M, TB = L.H, L.M, L.TB
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(60202)
	H.setBevelSelf(true)
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") and (c.Name == "Stone" or c.Name == "Log") then
			toCollision(c)
		end
	end
	local U: any = { StonesA = {}, StonesB = {}, Logs = {}, LogEnds = {}, Ash = {}, Coals = {}, FlameOuter = {}, FlameMid = {}, FlameCore = {}, Snow = {}, Moss = {} }
	local GREY, GREY2 = rgb(150, 156, 168), rgb(104, 110, 124)
	-- the stone ring
	local n = 9
	for k = 0, n - 1 do
		local a = k * 2 * math.pi / n + rng:NextNumber(-0.08, 0.08)
		local r = 2.6 + rng:NextNumber(-0.1, 0.12)
		local p = Vector3.new(math.cos(a) * r, 0.42, math.sin(a) * r)
		local f = CFrame.new(p) * CFrame.Angles(0, -a + rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.12, 0.12))
		TB.lump(if k % 2 == 0 then U.StonesA else U.StonesB, rng, f, rng:NextNumber(0.62, 0.8), rng:NextNumber(0.42, 0.52), rng:NextNumber(0.55, 0.7), function(): Color3
			return GREY
		end, 0.4)
		-- moss tufts (jungle) and snow (tundra) on the outer side of the stones
		TB.lump(U.Moss, rng, CFrame.new(p + Vector3.new(0, 0.42, 0)) * CFrame.Angles(0, -a, 0), 0.42, 0.12, 0.36, function(): Color3
			return rgb(88, 150, 66)
		end, 0.05)
		TB.lump(U.Snow, rng, CFrame.new(Vector3.new(math.cos(a + 0.35) * 2.95, 0.12, math.sin(a + 0.35) * 2.95)) * CFrame.Angles(0, -a, 0), 0.6, 0.22, 0.5, function(): Color3
			return rgb(236, 242, 250)
		end, 0.12)
	end
	-- ash bed and coals
	table.insert(U.Ash, M.frustumN(10, 1.9, 1.7, 0.0, 0.14, CFrame.identity, { rgb(78, 74, 72) }))
	for k = 1, 10 do
		local a = rng:NextNumber(0, 6.28)
		local r = rng:NextNumber(0.4, 1.6)
		table.insert(U.Coals, H.chamfered(Vector3.new(rng:NextNumber(0.25, 0.45), 0.16, rng:NextNumber(0.2, 0.35)), CFrame.new(math.cos(a) * r, 0.2, math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), if k % 3 == 0 then rgb(255, 200, 80) else rgb(255, 120, 40), { "vertical" }, 0.05))
	end
	-- 3 crossed logs (today's places: yaw 0 / 60 / 120, a 12 degree tilt, stacked)
	local BARK = rgb(112, 70, 42)
	for i, yaw in ipairs({ 0, 60, 120 }) do
		local cf = CFrame.new(0, 0.5 + (i - 1) * 0.25, 0) * CFrame.Angles(0, math.rad(yaw), math.rad(12))
		local a, b = cf * Vector3.new(-1.8, 0, 0), cf * Vector3.new(1.8, 0, 0)
		TB.log(U.Logs, U.LogEnds, a, b, 0.4, H.scaled(BARK, ({ 1.0, 0.92, 1.08 })[i]), { "a", "b" })
	end
	-- the layered flame: an outer orange cone, a yellow-orange one, a pale core, 2 side tongues
	local f0 = CFrame.new(0, 0.6, 0)
	table.insert(U.FlameOuter, M.frustumN(6, 0.95, 0.05, 0, 2.5, f0 * CFrame.Angles(0, 0.3, 0), { rgb(255, 110, 30) }))
	table.insert(U.FlameMid, M.frustumN(6, 0.66, 0.04, 0.1, 2.0, f0 * CFrame.Angles(0, 0.8, 0), { rgb(255, 170, 50) }))
	table.insert(U.FlameCore, M.frustumN(6, 0.36, 0.03, 0.15, 1.3, f0 * CFrame.Angles(0, 0.2, 0), { rgb(255, 236, 150) }))
	for _, s in ipairs({ -1, 1 }) do
		local base = Vector3.new(s * 0.55, 0.65, s * 0.2)
		table.insert(U.FlameOuter, M.frustumN(5, 0.42, 0.03, 0, 1.35, H.frameY(base, Vector3.new(s * 0.25, 1, 0.1).Unit), { rgb(255, 120, 35) }))
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	local NEON = { material = Enum.Material.Neon, shadow = false }
	mergeAll(m, U, {
		StonesA = { single = GREY }, StonesB = { single = GREY2 }, Ash = { single = rgb(78, 74, 72) },
		Coals = NEON, FlameOuter = { material = Enum.Material.Neon, shadow = false, transparency = 0.15 }, FlameMid = { material = Enum.Material.Neon, shadow = false, transparency = 0.1 }, FlameCore = NEON,
		Snow = { single = rgb(236, 242, 250), transparency = 1 }, Moss = { single = rgb(88, 150, 66), transparency = 1 },
	})
	for _, name in ipairs({ "Snow", "Moss", "Coals", "FlameOuter", "FlameMid", "FlameCore", "Ash", "Logs", "LogEnds", "StonesA", "StonesB" }) do
		local u = m:FindFirstChild(name) :: BasePart
		if u then
			u.CanCollide, u.CanQuery, u.CanTouch = false, false, false
		end
	end
	-- the biome variants
	local vf = m:FindFirstChild("_Variants") or Instance.new("Folder")
	vf.Name = "_Variants"
	vf.Parent = m
	local function variant(name: string, attrs: { [string]: any })
		local c = vf:FindFirstChild(name) or Instance.new("Configuration")
		c.Name = name
		for k, v in pairs(attrs) do
			c:SetAttribute(k, v)
		end
		c.Parent = vf
	end
	variant("Desert", { Color_StonesA = rgb(213, 179, 124), Color_StonesB = rgb(184, 146, 98), Color_Ash = rgb(160, 140, 108) })
	variant("Jungle", { Color_StonesA = rgb(122, 130, 114), Color_StonesB = rgb(92, 100, 92), Transparency_Moss = 0 })
	variant("Tundra", { Color_StonesA = rgb(176, 186, 204), Color_StonesB = rgb(130, 140, 160), Transparency_Snow = 0 })
	variant("Volcano", { Color_StonesA = rgb(84, 74, 76), Color_StonesB = rgb(56, 48, 50), Color_Ash = rgb(46, 40, 42) })
	variant("Swamp", { Color_StonesA = rgb(92, 96, 80), Color_StonesB = rgb(70, 72, 60), Color_Logs = rgb(70, 52, 38), Color_Ash = rgb(64, 58, 46), Transparency_Moss = 0 })
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

-- the Variant of each campfire copy by its zone (the hub and plains: default)
function P.campfireVariants(): string
	local lines = {}
	local counts = {}
	for _, root in ipairs({ workspace.Zones, workspace.Hub, game.ServerStorage.BossArenas, workspace._Staging.AssetPreview.ByZone }) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Model") and d:GetAttribute("MapPropId") == "hub_light_campfire_a" then
				local path = d:GetFullName()
				local v = nil
				for _, z in ipairs({ "Desert", "Jungle", "Tundra", "Volcano", "Swamp" }) do
					if path:find("%." .. z .. "[%._]") or path:find("_" .. z .. "%.") then
						v = z
					end
				end
				d:SetAttribute("Variant", v)
				local key = (v or "default") .. " " .. (if root == workspace._Staging.AssetPreview.ByZone then "preview" else "map")
				counts[key] = (counts[key] or 0) + 1
				table.insert(lines, path .. " -> " .. tostring(v or "default"))
			end
		end
	end
	local c = {}
	for k, v in pairs(counts) do
		table.insert(c, k .. " " .. v)
	end
	table.sort(c)
	table.sort(lines)
	return table.concat(c, ", ") .. "\n" .. table.concat(lines, "\n")
end

---------------------------------------------------------------------
-- 03 / 04 COTTAGE SHUTTERS (cottage_two_windows, cottage_one_window): the shutters only. The batch-4 builder
-- (DevTools.PropsBatch4, deterministic) is run from a copy whose windowUnit sets the shutters (planks, battens, the Z
-- brace) 0.5 stud further out - in front of the half-timbering beams, which stand up to 0.53 proud of the plaster - and
-- adds an iron hinge strap per batten on the window side; only its "Shutters" union (with the flower boxes, which do
-- not move) replaces the template's. Every other part of the template is untouched (checked: 0 changes).
---------------------------------------------------------------------
local SHUTTER_OUT = 0.5
local function shutterBuilder(): any
	local src = ServerStorage.DevTools.PropsBatch4.Source
	local function rep(a: string, b: string)
		local i, j = string.find(src, a, 1, true)
		assert(i, "PropsBatch4 anchor missing: " .. a)
		src = string.sub(src, 1, i - 1) .. b .. string.sub(src, j + 1)
	end
	local o = tostring(SHUTTER_OUT)
	rep("face * CFrame.new(px, 0, 0.09)", "face * CFrame.new(px, 0, 0.09 + " .. o .. ")")
	rep("Vector3.new(sw - 0.1, 0.3, 0.08), face * CFrame.new(x, y, 0.21)", "Vector3.new(sw - 0.1, 0.3, 0.08), face * CFrame.new(x, y, 0.21 + " .. o .. ")")
	rep("-h * 0.3, 0.21), face * Vector3.new(x + sx * (sw / 2 - 0.25), h * 0.3, 0.21)", "-h * 0.3, 0.21 + " .. o .. "), face * Vector3.new(x + sx * (sw / 2 - 0.25), h * 0.3, 0.21 + " .. o .. ")")
	rep("face * CFrame.new(sx * (w / 2 + 0.55), y, 0.2), P.Iron))", "face * CFrame.new(sx * (w / 2 + 0.55), y, 0.2), P.Iron))\n\t\t\t\ttable.insert(U.Shutters, piece(\"Part\", Vector3.new(0.5, 0.18, 0.1), face * CFrame.new(sx * (w / 2 + 0.6), y, 0.26 + " .. o .. "), P.Iron))")
	local tmp = Instance.new("ModuleScript")
	tmp.Name = "PropsBatch4_shutters"
	tmp.Source = src
	tmp.Parent = ServerStorage.DevTools
	local B4 = require(tmp:Clone())
	tmp:Destroy()
	return B4
end

function P.cottageShutters(id: string): string
	local B4 = shutterBuilder()
	local fresh = (B4 :: any)[id]() :: Model
	local m = folder():FindFirstChild(id):Clone() :: Model
	-- the rest of the fresh build must match the template exactly (same recipe, same seed)
	for _, n in ipairs({ "Timber", "Plaster", "Stone", "Roof" }) do
		local a, b = fresh:FindFirstChild(n) :: BasePart, m:FindFirstChild(n) :: BasePart
		assert(a and b and (a.ExtentsCFrame.Position - b.ExtentsCFrame.Position).Magnitude < 1e-3 and (a.ExtentsSize - b.ExtentsSize).Magnitude < 1e-3, "fresh build differs from the template: " .. n)
	end
	local oldS = m:FindFirstChild("Shutters") :: BasePart
	local newS = fresh:FindFirstChild("Shutters") :: BasePart
	newS.Parent = m
	oldS:Destroy()
	fresh:Destroy()
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: shutters moved out %.2f, %.1f x %.1f x %.1f", id, SHUTTER_OUT, size.X, size.Y, size.Z)
end

-- every part but the shutters identical between 2 versions of a template (old in _Previous)
function P.compareExceptShutters(id: string): string
	local a, b = folder()._Previous:FindFirstChild(id) :: Model, folder():FindFirstChild(id) :: Model
	local function list(m: Model): { [string]: number }
		local t = {}
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "Shutters" then
				local c, s = d.CFrame, d.Size
				local k = string.format("%s|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%s|%s", d.Name, c.X, c.Y, c.Z, s.X, s.Y, s.Z, tostring(d.CanCollide), d.Color:ToHex())
				t[k] = (t[k] or 0) + 1
			end
		end
		return t
	end
	local la, lb = list(a), list(b)
	local diff, n = 0, 0
	for k, v in pairs(la) do
		n += v
		if lb[k] ~= v then
			diff += 1
		end
	end
	for k, v in pairs(lb) do
		if la[k] ~= v then
			diff += 1
		end
	end
	return string.format("%s: %d parts compared (all but Shutters), %d differences", id, n, diff)
end

---------------------------------------------------------------------
-- 05 PLAINS ARENA DOOR (plains_gate_door, the Plains boss arena's Door): the boss gate's blue stone family. The pillars
-- and lintel as cut stone blocks with capitals, plinths, a cornice and dentils, carved frames round the 3 glowing
-- diamonds; on both faces a double door: per leaf a stone frame, 3 carved panels, 2 iron bands with studs and hinge
-- knuckles, an iron ring, a small glowing rune; the outer face (the plain navy back) as cut stone with a jamb frame.
-- Every part of today stays where it is with its collision: the slab (it carries the Leave prompt) as the dark door
-- reveal; the pillars, lintel and back fill as invisible collision round a dark core (the stone joints), the 5 bands as
-- invisible collision under the new leaves. BossService fades the whole Door when it opens, the new parts too.
---------------------------------------------------------------------
-- a double door on a face frame F (local -Z = outward, origin = the face's centre), w x h
local function doubleDoor(U: any, F: CFrame, w: number, h: number)
	local H = lib().H
	local STONE, DARK, LIGHT = rgb(104, 110, 124), rgb(62, 60, 78), rgb(150, 156, 168)
	local IRON, RUNE = rgb(64, 68, 80), rgb(90, 230, 255)
	local lw = w / 2
	local fr = 1.3
	table.insert(U.DoorTrim, H.piece("Part", Vector3.new(0.3, h - 0.3, 0.3), F * CFrame.new(0, 0, -0.2), DARK))
	for _, sx in ipairs({ -1, 1 }) do
		local cx = sx * lw / 2
		table.insert(U.Leaf, H.chamfered(Vector3.new(lw - 0.3, h - 0.3, 0.3), F * CFrame.new(cx, 0, -0.15), H.scaled(LIGHT, if sx < 0 then 1 else 0.96), { "frontFace" }, 0.08))
		-- the leaf frame: 2 stiles, 2 end rails, 2 middle rails
		for _, ex in ipairs({ -1, 1 }) do
			table.insert(U.DoorTrim, H.chamfered(Vector3.new(fr, h - 0.3, 0.4), F * CFrame.new(cx + ex * (lw / 2 - 0.15 - fr / 2), 0, -0.5), STONE, { "frontFace" }, 0.12))
		end
		local inner = lw - 0.3 - 2 * fr
		local yEnd = h / 2 - 0.15 - fr / 2
		for _, y in ipairs({ -yEnd, yEnd, -h / 6, h / 6 }) do
			table.insert(U.DoorTrim, H.chamfered(Vector3.new(inner, fr, 0.4), F * CFrame.new(cx, y, -0.5), STONE, { "frontFace" }, 0.12))
		end
		-- 3 carved panels: a dark recess and a bevelled raised panel
		local top0, top1 = h / 6 + fr / 2, yEnd - fr / 2
		for _, r in ipairs({ { top0, top1 }, { -h / 6 + fr / 2, h / 6 - fr / 2 }, { -top1, -top0 } }) do
			local ph, py = r[2] - r[1], (r[1] + r[2]) / 2
			table.insert(U.Recess, H.piece("Part", Vector3.new(inner, ph, 0.1), F * CFrame.new(cx, py, -0.35), DARK))
			table.insert(U.Leaf, H.chamfered(Vector3.new(inner - 1.0, ph - 1.0, 0.3), F * CFrame.new(cx, py, -0.45), H.scaled(LIGHT, 1.04), { "frontFace" }, 0.3))
		end
		-- the small glowing rune in a carved diamond on the middle panel
		local rf = F * CFrame.new(cx, 0, -0.7) * CFrame.Angles(0, 0, math.rad(45))
		table.insert(U.RuneSmall, H.piece("Part", Vector3.new(1.0, 1.0, 0.3), rf, RUNE))
		diamondFrame(U.DoorTrim, rf * CFrame.new(0, 0, 0.05), 1.0, 0.35, 0.3, DARK)
		-- 2 iron bands with studs, a hinge knuckle on the outer edge
		for _, y in ipairs({ -h * 0.36, h * 0.36 }) do
			table.insert(U.Iron, H.chamfered(Vector3.new(lw - 0.5, 0.9, 0.5), F * CFrame.new(cx, y, -0.7), IRON, { "frontFace" }, 0.1))
			local n = math.max(3, math.floor((lw - 1.5) / 1.6))
			for k = 0, n - 1 do
				local x = cx - (lw - 1.5) / 2 + k * (lw - 1.5) / (n - 1)
				table.insert(U.Iron, H.chamfered(Vector3.new(0.34, 0.34, 0.2), F * CFrame.new(x, y, -1.0), H.scaled(IRON, 1.2), { "frontFace" }, 0.08))
			end
			table.insert(U.Iron, H.chamfered(Vector3.new(0.6, 2.0, 0.6), F * CFrame.new(cx + sx * (lw / 2 - 0.35), y, -0.75), IRON, { "vertical" }, 0.15))
		end
		-- the iron ring by the centre seam
		local hx, hy, rr = sx * 1.3, -1.2, 0.75
		table.insert(U.Iron, H.chamfered(Vector3.new(0.8, 0.8, 0.2), F * CFrame.new(hx, hy + rr, -0.75), IRON, { "frontFace" }, 0.1))
		for k = 0, 7 do
			local a = k * math.pi / 4
			table.insert(U.Iron, H.piece("Part", Vector3.new(2 * rr * math.sin(math.pi / 8) + 0.06, 0.2, 0.2), F * CFrame.new(hx + math.cos(a) * rr, hy + math.sin(a) * rr, -0.95) * CFrame.Angles(0, 0, a + math.pi / 2), H.scaled(IRON, 1.15)))
		end
	end
end

function P.plainsArenaDoor(): string
	local id = "plains_gate_door"
	local L = lib()
	local H = L.H
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(60505)
	H.setBevelSelf(true)
	local STONE, DARK = rgb(104, 110, 124), rgb(62, 60, 78)
	local U: any = { Stone = {}, Stone2 = {}, Trim = {}, DoorTrim = {}, Leaf = {}, Recess = {}, Iron = {}, RuneSmall = {}, Carving = {} }
	local Ht = 42
	local slab = m:FindFirstChild("Slab") :: BasePart
	local back = m:FindFirstChild("BackFill") :: BasePart
	local li = m:FindFirstChild("Lintel") :: BasePart
	slab.Color = DARK
	for _, b in ipairs(children(m, "Band")) do
		toCollision(b)
	end
	-- the pillars (arena face +Z = "back" in stoneBox terms): cut stone on the arena face and the outer side, a plinth
	-- and a capital
	for _, name in ipairs({ "PillarL", "PillarR" }) do
		local p = m:FindFirstChild(name) :: BasePart
		local c, s = p.Position, p.Size
		toCollision(p)
		table.insert(U.Carving, H.piece("Part", s - Vector3.new(0.4, 0.2, 0.4), p.CFrame, DARK))
		stoneBox(if name == "PillarL" then U.Stone else U.Stone2, rng, p, { "back", if name == "PillarL" then "left" else "right" }, c.Y - s.Y / 2 + 1.2, li.Position.Y - li.Size.Y / 2 - 1.0, 2.6, STONE, Ht)
		table.insert(U.Trim, H.chamfered(Vector3.new(s.X + 0.6, 1.0, s.Z + 0.6), CFrame.new(c.X, li.Position.Y - li.Size.Y / 2 - 0.5, c.Z), H.scaled(DARK, 1.15), { "vertical", "bottomFrontBack", "bottomSides" }, 0.25))
		table.insert(U.Trim, H.chamfered(Vector3.new(s.X + 0.6, 1.2, s.Z + 0.6), CFrame.new(c.X, c.Y - s.Y / 2 + 0.6, c.Z), H.scaled(DARK, 1.15), { "vertical", "topFrontBack", "topSides" }, 0.25))
	end
	-- the lintel: cut stone on the arena face and the ends, carved frames round today's 3 diamonds, a cornice, dentils
	toCollision(li)
	table.insert(U.Carving, H.piece("Part", li.Size - Vector3.new(0.4, 0.2, 0.4), li.CFrame, DARK))
	stoneBox(U.Stone, rng, li, { "back", "left", "right" }, li.Position.Y - li.Size.Y / 2, li.Position.Y + li.Size.Y / 2 - 0.8, 3.6, STONE, Ht)
	for _, r in ipairs(children(m, "Rune")) do
		diamondFrame(U.DoorTrim, r.CFrame * CFrame.new(0, 0, -0.15), r.Size.X, 0.5, 0.5, H.scaled(DARK, 1.2))
	end
	local lc, ls = li.Position, li.Size
	table.insert(U.Trim, H.chamfered(Vector3.new(ls.X, 0.8, ls.Z + 0.3), CFrame.new(lc.X, lc.Y + ls.Y / 2 - 0.4, lc.Z + 0.15), DARK, { "topFrontBack", "topSides", "bottomFrontBack" }, 0.3))
	for k = 0, 16 do
		local x = -12.4 + k * 24.8 / 16
		table.insert(U.Trim, H.piece("Part", Vector3.new(0.8, 0.5, 0.5), CFrame.new(x, lc.Y - ls.Y / 2 - 0.25, lc.Z + ls.Z / 2 - 0.3), H.scaled(DARK, 1.1)))
	end
	-- the arena face of the door
	local sc, ss = slab.Position, slab.Size
	doubleDoor(U, CFrame.new(sc.X, sc.Y, sc.Z + ss.Z / 2) * CFrame.Angles(0, math.pi, 0), ss.X, ss.Y)
	-- the outer face (today a plain navy wall): cut stone, a jamb frame and the same double door
	local bc, bs = back.Position, back.Size
	toCollision(back)
	table.insert(U.Carving, H.piece("Part", bs - Vector3.new(0.4, 0.2, 0.4), back.CFrame, DARK))
	stoneBox(U.Stone2, rng, back, { "front", "left", "right" }, bc.Y - bs.Y / 2, bc.Y + bs.Y / 2, 2.8, STONE, Ht)
	stoneBox(U.Stone2, rng, back, { "back" }, bc.Y - bs.Y / 2, bc.Y + bs.Y / 2, 2.8, STONE, Ht)
	local zb = bc.Z - bs.Z / 2
	local FB = CFrame.new(sc.X, sc.Y, zb)
	for _, e in ipairs({ { -ss.X / 2 - 0.8, 0, 1.6, ss.Y }, { ss.X / 2 + 0.8, 0, 1.6, ss.Y }, { 0, ss.Y / 2 + 0.8, ss.X + 3.2, 1.6 } }) do
		table.insert(U.Trim, H.chamfered(Vector3.new(e[3], e[4], 0.6), FB * CFrame.new(e[1], e[2], -0.3), H.scaled(DARK, 1.15), { "frontFace" }, 0.2))
	end
	table.insert(U.Recess, H.piece("Part", Vector3.new(ss.X, ss.Y, 0.1), FB * CFrame.new(0, 0, -0.05), DARK))
	doubleDoor(U, FB * CFrame.new(0, 0, -0.1), ss.X, ss.Y)
	return finishR6(m, id, U, { RuneSmall = { material = Enum.Material.Neon, shadow = false } })
end

---------------------------------------------------------------------
-- 06 MINE SUPPORT (plains_prop_mine_support; the Plains_4 mine x5, the Desert_3 caves x2): a mine timber frame. Thick
-- chamfered posts with grain and knots, bolster caps on top, the crossbeam in 3 lengths with scarf joints and riveted
-- iron fish plates, today's 2 bolts as iron plates with hex heads, the braces as timbers with iron brackets and rivets,
-- 3 nailed top boards, stone footings with a few loose stones, a rope lashing round a post and a small lantern on an
-- iron hook under the beam. Today's 10 parts stay as invisible collision.
---------------------------------------------------------------------
function P.mineSupport(): string
	local id = "plains_prop_mine_support"
	local L = lib()
	local H, M = L.H, L.M
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(60606)
	H.setBevelSelf(true)
	local WOOD, DARKW, PLANK, STONE = rgb(168, 98, 56), rgb(112, 62, 38), rgb(214, 150, 92), rgb(104, 110, 124)
	local IRON, ROPE = rgb(74, 78, 88), rgb(196, 160, 104)
	local U: any = { Posts = {}, Beam = {}, Boards = {}, Braces = {}, Footings = {}, Iron = {}, Rope = {}, Lamp = {}, Grain = {} }
	local parts = {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			table.insert(parts, { name = c.Name, cf = c.CFrame, size = c.Size })
			toCollision(c)
		end
	end
	-- grain lines and a knot or two on a face (frame f: X along, Y up, -Z out; len x wid)
	local function grain(f: CFrame, len: number, wid: number, color: Color3, vertical: boolean)
		for k = 1, 3 do
			local l = rng:NextNumber(0.3, 0.6) * len
			local a = rng:NextNumber(-len / 2 + l / 2, len / 2 - l / 2)
			local b = (k - 2) * wid * 0.28 + rng:NextNumber(-0.08, 0.08)
			local size = if vertical then Vector3.new(0.07, l, 0.06) else Vector3.new(l, 0.07, 0.06)
			local p = if vertical then Vector3.new(b, a, -0.01) else Vector3.new(a, b, -0.01)
			table.insert(U.Grain, H.piece("Part", size, f * CFrame.new(p), H.scaled(color, 0.72)))
		end
		if rng:NextNumber() < 0.7 then
			local a = rng:NextNumber(-len / 3, len / 3)
			local p = if vertical then Vector3.new(rng:NextNumber(-wid / 4, wid / 4), a, -0.02) else Vector3.new(a, rng:NextNumber(-wid / 4, wid / 4), -0.02)
			table.insert(U.Grain, H.piece("Part", Vector3.new(0.3, 0.3, 0.08), f * CFrame.new(p) * CFrame.Angles(0, 0, math.rad(45)), H.scaled(color, 0.62)))
		end
	end
	local function bolt(f: CFrame, s: number)
		table.insert(U.Iron, H.chamfered(Vector3.new(s, s, 0.25), f * CFrame.new(0, 0, -0.125), IRON, { "frontFace" }, 0.06))
		table.insert(U.Iron, M.frustumN(6, s * 0.28, s * 0.24, 0, s * 0.4, H.frameY(f * Vector3.new(0, 0, -0.2), f.LookVector), { H.scaled(IRON, 1.2), IRON }))
	end
	for _, r in ipairs(parts) do
		local c, s = r.cf.Position, r.size
		if r.name == "Post" then
			-- the post from the footing to the cap, a bolster cap under the beam
			local y0, y1 = 1.2, 15.3
			local pc = CFrame.new(c.X, (y0 + y1) / 2, c.Z)
			table.insert(U.Posts, H.timber(Vector3.new(s.X, y1 - y0, s.Z), pc, H.scaled(WOOD, rng:NextNumber(0.94, 1.04)), 0.22))
			for _, face in ipairs({ CFrame.new(c.X, (y0 + y1) / 2, c.Z - s.Z / 2), CFrame.new(c.X, (y0 + y1) / 2, c.Z + s.Z / 2) * CFrame.Angles(0, math.pi, 0) }) do
				grain(face, y1 - y0, s.X, WOOD, true)
			end
			table.insert(U.Beam, H.chamfered(Vector3.new(s.X + 1.4, 0.7, s.Z + 0.4), CFrame.new(c.X, y1 + 0.35, c.Z), H.scaled(DARKW, 1.08), { "bottomFrontBack", "bottomSides" }, 0.25))
			-- the stone footing and a few loose stones beside it
		elseif r.name == "Footing" then
			table.insert(U.Footings, H.chamfered(s, r.cf, H.scaled(STONE, rng:NextNumber(0.95, 1.05)), { "vertical", "topFrontBack", "topSides" }, 0.3))
			for _, sx in ipairs({ -1, 1 }) do
				local p = Vector3.new(c.X + sx * rng:NextNumber(2.0, 2.3), 0.2, c.Z + rng:NextNumber(-0.9, 0.9))
				table.insert(U.Footings, H.chamfered(Vector3.new(rng:NextNumber(0.6, 0.85), 0.42, rng:NextNumber(0.5, 0.7)), CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), H.scaled(STONE, rng:NextNumber(0.85, 1.0)), { "vertical", "topFrontBack", "topSides" }, 0.12))
			end
		elseif r.name == "Beam" then
			-- 3 lengths with scarf joints; riveted iron fish plates over the joints on both faces
			local x0, x1 = c.X - s.X / 2, c.X + s.X / 2
			local cuts = { x0, -7.5, 7.5, x1 }
			for k = 1, 3 do
				local a, b = cuts[k] + (if k > 1 then 0.06 else 0), cuts[k + 1] - (if k < 3 then 0.06 else 0)
				table.insert(U.Beam, H.timber(Vector3.new(b - a, s.Y, s.Z), CFrame.new((a + b) / 2, c.Y, c.Z), H.scaled(DARKW, ({ 1.0, 1.06, 0.95 })[k]), 0.2))
				for _, zs in ipairs({ -1, 1 }) do
					grain(CFrame.new((a + b) / 2, c.Y, c.Z + zs * s.Z / 2) * CFrame.Angles(0, if zs > 0 then math.pi else 0, 0), b - a, s.Y, DARKW, false)
				end
			end
			for _, x in ipairs({ -7.5, 7.5 }) do
				table.insert(U.Grain, H.piece("Part", Vector3.new(0.14, s.Y - 0.2, s.Z - 0.2), CFrame.new(x, c.Y, c.Z), H.scaled(DARKW, 0.5)))
				for _, zs in ipairs({ -1, 1 }) do
					table.insert(U.Iron, H.chamfered(Vector3.new(1.7, 1.9, 0.12), CFrame.new(x, c.Y, c.Z + zs * (s.Z / 2 + 0.06)), IRON, { "vertical" }, 0.05))
					for _, dx in ipairs({ -0.5, 0.5 }) do
						for _, dy in ipairs({ -0.6, 0.6 }) do
							H.rivet(U.Iron, Vector3.new(x + dx, c.Y + dy, c.Z + zs * (s.Z / 2 + 0.12)), 0.24)
						end
					end
				end
			end
		elseif r.name == "Plank" then
			-- 3 nailed boards along the top
			local w = (s.Z - 0.16) / 3
			for k = 0, 2 do
				local z = c.Z - s.Z / 2 + 0.08 + w * (k + 0.5)
				table.insert(U.Boards, H.timber(Vector3.new(s.X - rng:NextNumber(0, 0.4), s.Y, w - 0.08), CFrame.new(c.X + rng:NextNumber(-0.15, 0.15), c.Y + rng:NextNumber(-0.03, 0.03), z), H.scaled(PLANK, ({ 1.0, 0.93, 1.05 })[k + 1]), 0.1))
				for _, x in ipairs({ -11.2, -6, 0, 6, 11.2 }) do
					H.rivet(U.Iron, Vector3.new(x, c.Y + s.Y / 2, z), 0.18)
				end
			end
		elseif r.name == "Brace" then
			-- the brace as a timber: an iron strap with 2 rivets on each face of its top end (under the beam), an iron
			-- plate with 4 rivets on the post's outer face where it goes in
			table.insert(U.Braces, H.timber(Vector3.new(s.X + 0.1, s.Y, s.Z - 0.4), r.cf, H.scaled(DARKW, 1.04), 0.12))
			for _, zs in ipairs({ -1, 1 }) do
				local e = r.cf * CFrame.new(0, s.Y / 2 - 0.75, zs * ((s.Z - 0.4) / 2 + 0.05))
				table.insert(U.Iron, H.piece("Part", Vector3.new(s.X + 0.3, 1.2, 0.1), e, IRON))
				for _, dy in ipairs({ -0.3, 0.3 }) do
					H.rivet(U.Iron, (e * CFrame.new(0, dy, zs * 0.06)).Position, 0.2)
				end
			end
			local sg = if c.X < 0 then -1 else 1
			local px = sg * (11.1 + 1.1 + 0.05)
			table.insert(U.Iron, H.chamfered(Vector3.new(0.1, 1.5, 1.7), CFrame.new(px, 12.9, c.Z), IRON, {}, 0))
			for _, dy in ipairs({ -0.45, 0.45 }) do
				for _, dz in ipairs({ -0.55, 0.55 }) do
					H.rivet(U.Iron, Vector3.new(px + sg * 0.06, 12.9 + dy, c.Z + dz), 0.22)
				end
			end
		elseif r.name == "Bolt" then
			-- today's bolts as iron plates with hex heads on the beam's face
			bolt(CFrame.new(c.X, c.Y, c.Z + s.Z / 2 - 0.2), 1.2)
		end
	end
	-- a rope lashing round the left post below the brace (2 turns)
	for t = 0, 1 do
		local y = 10.4 + t * 0.32
		local px, ps = -11.1, 2.2 + 0.18
		for _, e in ipairs({ { 0, -1, ps, 0.18 }, { 0, 1, ps, 0.18 }, { -1, 0, 0.18, ps }, { 1, 0, 0.18, ps } }) do
			table.insert(U.Rope, H.piece("Part", Vector3.new(e[3], 0.2, e[4]), CFrame.new(px + e[1] * (ps / 2 - 0.09), y, e[2] * (ps / 2 - 0.09)) * CFrame.Angles(0, 0, math.rad(t * 4 - 2)), H.scaled(ROPE, 1 - t * 0.06)))
		end
	end
	-- a small lantern on an iron hook under the beam, on its front side
	local hx, hz = 2.2, -0.7
	table.insert(U.Iron, H.piece("Part", Vector3.new(0.14, 0.9, 0.14), CFrame.new(hx, 15.55, hz), IRON))
	table.insert(U.Iron, H.piece("Part", Vector3.new(0.5, 0.14, 0.14), CFrame.new(hx + 0.18, 15.1, hz), IRON))
	table.insert(U.Iron, H.piece("Part", Vector3.new(0.14, 0.4, 0.14), CFrame.new(hx + 0.38, 15.25, hz), IRON))
	local ly = 14.45
	table.insert(U.Iron, M.frustumN(6, 0.42, 0.12, 0, 0.32, CFrame.new(hx, ly + 0.45, hz), { IRON, H.scaled(IRON, 1.15) }))
	table.insert(U.Iron, H.chamfered(Vector3.new(0.84, 0.16, 0.84), CFrame.new(hx, ly - 0.42, hz), IRON, { "vertical" }, 0.1))
	for _, d in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		table.insert(U.Iron, H.piece("Part", Vector3.new(0.1, 0.8, 0.1), CFrame.new(hx + d[1] * 0.36, ly, hz + d[2] * 0.36), IRON))
	end
	table.insert(U.Lamp, H.piece("Part", Vector3.new(0.5, 0.62, 0.5), CFrame.new(hx, ly, hz), rgb(255, 196, 96)))
	return finishR6(m, id, U, { Lamp = { material = Enum.Material.Neon, shadow = false, transparency = 0.1 } })
end

---------------------------------------------------------------------
-- 07 ROPE BRIDGE SECTION (jungle_bridge_rope_bridge_section, Jungle_2 x2) and 08 FLOATING DOCK
-- (jungle_bridge_floating_dock_a, Jungle_2): the docks recipe (DevTools.PropsDocks: boards ~0.95 wide in 3 tones over
-- a dark core, butt joints, nails, cracks, knots, board tops = today's plank tops; round 8-sided posts with a capped
-- top and a rope wrap) in warm jungle wood, with real rope handrails (2 strands per side, sagging between the posts,
-- tied with rope ties and knots), moss rings at the post feet, hanging vines with leaves. 07: 2 stringers and X braces
-- under the deck. 08: rim joists, 2 rows of 3 banded barrels as the floats, X braces between them, a sagging rope rail,
-- a rope coil on the deck. Today's colliding parts stay as invisible collision (walk surfaces, rails and floats exactly
-- as today); today's visual planks, ties, bands and rope go (rebuilt).
---------------------------------------------------------------------
local PDM = nil
local function pd(): any
	if not PDM then
		PDM = require(ServerStorage.DevTools.PropsDocks:Clone())
	end
	return PDM
end

local JUNGLE = { rope = rgb(196, 160, 104), moss = rgb(88, 150, 66), vine = rgb(62, 118, 48), leaf = rgb(92, 170, 70), iron = rgb(84, 86, 92) }

-- the colliding parts become invisible collision, the rest of today's parts go; returns today's rows
local function strip(m: Model): { any }
	local rows = {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			table.insert(rows, { name = c.Name, cf = c.CFrame, size = c.Size, color = c.Color })
			if c.CanCollide then
				toCollision(c)
			else
				c:Destroy()
			end
		end
	end
	return rows
end

-- a rope sagging from a to b (n segments, sag at the middle), alternating 2 tones
local function sagRope(list: { BasePart }, a: Vector3, b: Vector3, sag: number, t: number, n: number)
	local H = lib().H
	local prev = a
	for k = 1, n do
		local f = k / n
		local p = a:Lerp(b, f) - Vector3.new(0, sag * 4 * f * (1 - f), 0)
		table.insert(list, H.bar(prev, p, t, H.scaled(JUNGLE.rope, if k % 2 == 0 then 0.9 else 1.0)))
		prev = p
	end
end
local function sagAt(a: Vector3, b: Vector3, sag: number, f: number): Vector3
	return a:Lerp(b, f) - Vector3.new(0, sag * 4 * f * (1 - f), 0)
end

-- a vine hanging from p (3 wiggly segments, a leaf at each joint)
local function vine(U: any, rng: Random, p: Vector3, len: number)
	local H = lib().H
	local prev = p
	for k = 1, 3 do
		local q = p + Vector3.new(rng:NextNumber(-0.15, 0.15), -len * k / 3, rng:NextNumber(-0.15, 0.15))
		table.insert(U.Vines, H.bar(prev, q, 0.09, JUNGLE.vine))
		table.insert(U.Leaves, H.piece("Part", Vector3.new(0.42, 0.05, 0.26), CFrame.new(q) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 6.28), rng:NextNumber(0.3, 0.7)), H.scaled(JUNGLE.leaf, rng:NextNumber(0.88, 1.08))))
		prev = q
	end
end

-- a rope wrap (3 tilted rings) round a vertical round post (radius r) at p
local function wrap(U: any, rng: Random, p: Vector3, r: number)
	local L = lib()
	for k = 1, 3 do
		local cf = L.H.frameY(p + Vector3.new(0, (k - 2) * 0.14, 0), Vector3.yAxis) * CFrame.Angles(math.rad(8), rng:NextNumber(0, 6.28), 0)
		table.insert(U.Rope, L.M.frustumN(8, r + 0.06, r + 0.06, -0.06, 0.06, cf, { JUNGLE.rope, L.H.scaled(JUNGLE.rope, 0.88) }))
	end
end

-- a moss ring at a post's foot (deck level y)
local function mossRing(U: any, x: number, y: number, z: number, r: number)
	local L = lib()
	table.insert(U.Moss, L.M.frustumN(8, r + 0.07, r + 0.03, y, y + 0.35, CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(22.5), 0), { JUNGLE.moss, L.H.scaled(JUNGLE.moss, 1.12) }))
end

local function newU(): any
	return { Core = {}, Deck = {}, Nails = {}, Wear = {}, Stain = {}, Wood = {}, Iron = {}, Rope = {}, Moss = {}, Mud = {}, Grass = {}, Vines = {}, Leaves = {}, Frame = {}, Barrels = {}, Bands = {} }
end

function P.ropeBridge(): string
	local id = "jungle_bridge_rope_bridge_section"
	local L = lib()
	local H = L.H
	local PD = pd()
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(60707)
	H.setBevelSelf(true)
	local WOOD, POST = rgb(170, 100, 58), rgb(112, 70, 42)
	local U = newU()
	local rows = strip(m)
	-- the boards (tops = today's plank tops, y 1.0), nailed over the 2 stringers
	PD.boards(U, rng, { size = Vector3.new(15.6, 0.2, 19.7), cf = CFrame.new(0, 0.9, 0), color = WOOD }, { -6.5, 6.5 }, false)
	-- 2 stringers and X braces under the deck
	for _, x in ipairs({ -6.5, 6.5 }) do
		table.insert(U.Frame, H.chamfered(Vector3.new(0.7, 0.45, 19.8), CFrame.new(x, 0.575, 0), H.scaled(POST, 1.05), { "topSides", "bottomSides" }, 0.1))
	end
	for _, b in ipairs({ { -9.2, -0.4 }, { 0.4, 9.2 } }) do
		table.insert(U.Frame, H.bar(Vector3.new(-6.1, 0.5, b[1]), Vector3.new(6.1, 0.5, b[2]), 0.24, POST))
		table.insert(U.Frame, H.bar(Vector3.new(6.1, 0.46, b[1]), Vector3.new(-6.1, 0.46, b[2]), 0.24, H.scaled(POST, 0.92)))
	end
	-- the 4 round posts (today's places), capped, with rope wraps where the handrails tie, moss at the foot
	for _, r in ipairs(rows) do
		if r.name == "Post" then
			local c = r.cf.Position
			PD.roundPost(U, rng, Vector3.new(c.X, 0.5, c.Z), Vector3.new(c.X, 5.6, c.Z), 0.5, H.scaled(POST, rng:NextNumber(0.95, 1.06)), { cap = true, ropeY = 5.2, iron = JUNGLE.iron })
			wrap(U, rng, Vector3.new(c.X, 3.1, c.Z), 0.5)
			mossRing(U, c.X, 0.95, c.Z, 0.5)
		end
	end
	-- the handrails: 2 sagging rope strands per side, rope ties with knots at z -5 / 0 / 5, vines and leaves
	for _, x in ipairs({ -7.5, 7.5 }) do
		local a1, b1 = Vector3.new(x, 5.2, -9.5), Vector3.new(x, 5.2, 9.5)
		local a2, b2 = Vector3.new(x, 3.1, -9.5), Vector3.new(x, 3.1, 9.5)
		sagRope(U.Rope, a1, b1, 0.35, 0.26, 10)
		sagRope(U.Rope, a2, b2, 0.25, 0.24, 10)
		for _, z in ipairs({ -5, 0, 5 }) do
			local f = (z + 9.5) / 19
			local top, low = sagAt(a1, b1, 0.35, f), sagAt(a2, b2, 0.25, f)
			table.insert(U.Rope, H.bar(low - Vector3.new(0, 0.25, 0), top, 0.15, H.scaled(JUNGLE.rope, 0.95)))
			for _, p in ipairs({ top, low }) do
				table.insert(U.Rope, H.chamfered(Vector3.new(0.34, 0.3, 0.34), CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), H.scaled(JUNGLE.rope, 0.86), { "vertical" }, 0.08))
			end
		end
		for _ = 1, 2 do
			local f = rng:NextNumber(0.15, 0.85)
			vine(U, rng, sagAt(a1, b1, 0.35, f) + Vector3.new(math.sign(x) * 0.12, 0, 0), rng:NextNumber(1.2, 2.0))
		end
		-- moss creeping onto the board ends
		for _ = 1, 3 do
			table.insert(U.Stain, H.piece("Part", Vector3.new(rng:NextNumber(0.5, 0.9), 0.02, rng:NextNumber(0.6, 1.4)), CFrame.new(x - math.sign(x) * rng:NextNumber(0.3, 0.6), 1.006, rng:NextNumber(-8, 8)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), H.scaled(JUNGLE.moss, rng:NextNumber(0.85, 1.0))))
		end
	end
	return finishR6(m, id, U)
end

function P.floatingDock(): string
	local id = "jungle_bridge_floating_dock_a"
	local L = lib()
	local H, M = L.H, L.M
	local PD = pd()
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(60808)
	H.setBevelSelf(true)
	local WOOD, POST, BARREL = rgb(208, 146, 90), rgb(112, 70, 42), rgb(150, 96, 56)
	local U = newU()
	local rows = strip(m)
	-- the boards (tops = today's plank tops, y 2.71), nailed over the rim joists and the middle
	PD.boards(U, rng, { size = Vector3.new(11.6, 0.22, 15.75), cf = CFrame.new(0, 2.6, 0), color = WOOD }, { -5.4, 0, 5.4 }, false)
	-- rim joists round the deck, under the boards
	for _, x in ipairs({ -5.75, 5.75 }) do
		table.insert(U.Frame, H.chamfered(Vector3.new(0.5, 0.45, 16), CFrame.new(x, 2.27, 0), H.scaled(POST, 1.05), { "topSides", "bottomSides" }, 0.08))
	end
	for _, z in ipairs({ -7.75, 7.75 }) do
		table.insert(U.Frame, H.chamfered(Vector3.new(11, 0.45, 0.5), CFrame.new(0, 2.27, z), POST, { "topFrontBack", "bottomFrontBack" }, 0.08))
	end
	for _, r in ipairs(rows) do
		local c = r.cf.Position
		if r.name == "Float" then
			-- 3 banded barrels lying along the float
			for _, bx in ipairs({ -3.55, 0, 3.55 }) do
				local len, re, rm = 3.3, 1.05, 1.28
				local F = H.frameY(Vector3.new(bx, c.Y, c.Z), Vector3.xAxis) * CFrame.Angles(0, rng:NextNumber(0, 0.6), 0)
				local col = H.scaled(BARREL, rng:NextNumber(0.92, 1.06))
				table.insert(U.Barrels, M.frustumN(10, re, rm, -len / 2, 0, F, { col, H.scaled(col, 0.9) }))
				table.insert(U.Barrels, M.frustumN(10, rm, re, 0, len / 2, F, { col, H.scaled(col, 0.9) }))
				for _, e in ipairs({ -1, 1 }) do
					table.insert(U.Barrels, M.frustumN(10, re - 0.12, re - 0.12, e * len / 2 - 0.04, e * len / 2 + 0.03, F, { H.scaled(col, 0.75) }))
					for _, yy in ipairs({ 0.38, 0.12 }) do
						local y = e * len * yy
						local rr = re + (rm - re) * (1 - math.abs(y) / (len / 2)) + 0.04
						table.insert(U.Bands, M.frustumN(10, rr, rr, y - 0.1, y + 0.1, F, { JUNGLE.iron, H.scaled(JUNGLE.iron, 0.85) }))
					end
				end
			end
		elseif r.name == "Post" then
			PD.roundPost(U, rng, Vector3.new(c.X, 2.3, c.Z), Vector3.new(c.X, 6.2, c.Z), 0.4, H.scaled(POST, rng:NextNumber(0.95, 1.06)), { cap = true, ropeY = 5.9, iron = JUNGLE.iron })
			mossRing(U, c.X, 2.66, c.Z, 0.4)
		end
	end
	-- X braces between the 2 float rows on both sides
	for _, x in ipairs({ -5.4, 5.4 }) do
		table.insert(U.Frame, H.bar(Vector3.new(x, 0.9, -3.9), Vector3.new(x, 2.0, 3.9), 0.24, POST))
		table.insert(U.Frame, H.bar(Vector3.new(x, 2.0, -3.9), Vector3.new(x, 0.9, 3.9), 0.24, H.scaled(POST, 0.92)))
	end
	-- the rope rail between the posts (sagging), a vine on it, a rope coil on the deck
	local a, b = Vector3.new(-5.45, 5.9, 7.4), Vector3.new(5.45, 5.9, 7.4)
	sagRope(U.Rope, a, b, 0.3, 0.26, 8)
	vine(U, rng, sagAt(a, b, 0.3, 0.3) + Vector3.new(0, 0, 0.12), 1.4)
	for k, r in ipairs({ 0.62, 0.5, 0.38 }) do
		table.insert(U.Rope, M.frustumN(10, r, r, 2.71 + (k - 1) * 0.1, 2.71 + k * 0.1, CFrame.new(3.6, 0, -6.2), { JUNGLE.rope, H.scaled(JUNGLE.rope, 0.88) }))
	end
	for _ = 1, 4 do
		local x = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(4.6, 5.3)
		table.insert(U.Stain, H.piece("Part", Vector3.new(rng:NextNumber(0.6, 1.0), 0.02, rng:NextNumber(0.7, 1.5)), CFrame.new(x, 2.716, rng:NextNumber(-6.5, 6.5)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), H.scaled(JUNGLE.moss, rng:NextNumber(0.85, 1.0))))
	end
	return finishR6(m, id, U)
end

---------------------------------------------------------------------
-- 09 GIANT TREE (jungle_landmark_giant_tree, the Jungle_1 landmark): the swamp tree recipe (DevTools.PropsSwampTrees:
-- twisted 8-sided bark logs with winding grooves, faceted leaf clusters lit on top and dark under, folded leaves,
-- leafy vines, moss cushions, ferns) at landmark scale in jungle greens. The trunk as 3 twisted sections tapering from
-- today's base to the canopy; the 7 roots as buttress roots (a flaring web under a thick root log, inside today's root
-- wedges); today's 5 branches as twisted limbs; today's 7 canopy discs as layered leaf clusters (a centre cluster and a
-- ring, drooping leaf tips at the rims); today's 8 vines as leafy vines and 4 more from the canopy; moss on the roots
-- and the trunk, ferns between the roots. The tribal mask on the trunk (the 2 "hanging objects" between the roots) is
-- kept: its small parts (eyes, pupils, nose, mouth, teeth, stripes, feathers) as they are, the board, brow and chin
-- bevelled with a carved border, the horns as pointed bone horns, the rope band as a rope ring. Today's colliding parts
-- (trunk, roots, rope band, mask board / brow / chin / horns) stay as invisible collision; the NoClimb walls stay.
---------------------------------------------------------------------
local STM = nil
local function swampTrees(): any
	if not STM then
		STM = require(ServerStorage.DevTools.PropsSwampTrees:Clone())
	end
	return STM
end

function P.giantTree(): string
	local id = "jungle_landmark_giant_tree"
	local L = lib()
	local H, M = L.H, L.M
	local ST = swampTrees()
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(60909)
	H.setBevelSelf(true)
	local BARK, ROOT, ROPE, BONE, VINE = rgb(104, 68, 44), rgb(86, 56, 38), rgb(196, 160, 104), rgb(232, 226, 208), rgb(70, 150, 60)
	local U: any = { Trunk = {}, Bark = {}, Roots = {}, RootWeb = {}, Branches = {}, Leaves = {}, LeafTips = {}, Vines = {}, VineLeaves = {}, Moss = {}, Fern = {}, Rope = {}, Mask = {}, MaskTrim = {} }
	local rows = {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			table.insert(rows, { name = c.Name, cf = c.CFrame, size = c.Size, color = c.Color })
			if c.CanCollide then
				toCollision(c)
			elseif c.Name == "Canopy" or c.Name == "Branch" or c.Name == "Vine" then
				if c == m.PrimaryPart then
					-- (today's PrimaryPart, the big canopy disc: an invisible plain part in its place keeps the pivot)
					local a = Instance.new("Part")
					a.Name = "PivotPart"
					a.Size, a.CFrame, a.PivotOffset = c.Size, c.CFrame, c.PivotOffset
					a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.CastShadow = true, false, false, false, false
					a.Transparency = 1
					a.Parent = m
					m.PrimaryPart = a
				end
				c:Destroy()
			end
		end
	end
	-- the trunk: 3 twisted sections, one twist running through
	local secs = { { 0, 34, 13.3, 12.6 }, { 34, 67, 12.6, 10.2 }, { 67, 92, 10.2, 8.2 } }
	-- (today's trunk browns, lighter towards the top; the bark grooves a darker shade of the same brown)
	for k, s in ipairs(secs) do
		local n0 = #U.Bark
		local col = H.scaled(BARK, ({ 1.14, 1.27, 1.4 })[k])
		ST.twistedLog(U.Trunk, U.Bark, rng, Vector3.new(0, s[1] - (if k > 1 then 0.3 else 0), 0), Vector3.new(0, s[2], 0), s[3], s[4], col, k * 1.3, math.rad(9))
		for j = n0 + 1, #U.Bark do
			U.Bark[j].Color = H.scaled(col, 0.78)
		end
	end
	-- the buttress roots: per root wedge a concave flaring web (stepped boxes and wedges under the curve) and a thick root
	-- log along its top, from the trunk down to the wedge's foot
	for _, r in ipairs(rows) do
		if r.name == "Root" then
			local c, s = r.cf.Position, r.size
			local rc = Vector3.new(c.X, 0, c.Z).Magnitude
			local y0, y1 = c.Y - s.Y / 2, c.Y + s.Y / 2
			local ui, uo = rc - s.Z / 2 + 0.5, rc + s.Z / 2 - 0.3
			local function at(u: number, y: number): CFrame
				return r.cf * CFrame.new(0, y - c.Y, -(u - rc))
			end
			local function curve(t: number): (number, number)
				local cu, cy = ui + (uo - ui) * 0.2, y0 + (y1 - y0) * 0.18
				local a, b = (1 - t) * (1 - t), 2 * (1 - t) * t
				return a * ui + b * cu + t * t * uo, a * (y1 - 0.6) + b * cy + t * t * (y0 + 0.4)
			end
			local n = 6
			local pu, py = curve(0)
			local prevP = at(pu, py).Position
			local col = H.scaled(r.color, rng:NextNumber(1.15, 1.25))
			for k = 1, n do
				local u, y = curve(k / n)
				local T = 3.2 - 1.6 * k / n
				local mid = (pu + u) / 2
				if y - y0 > 0.2 then
					table.insert(U.RootWeb, H.piece("Part", Vector3.new(T, y - y0, u - pu + 0.05), at(mid, (y0 + y) / 2), H.scaled(col, 0.92)))
				end
				if py - y > 0.05 then
					table.insert(U.RootWeb, H.piece("WedgePart", Vector3.new(T, py - y, u - pu + 0.05), at(mid, (py + y) / 2), H.scaled(col, 0.92)))
				end
				local q = at(u, y).Position
				local ra, rb = 3.0 - 1.9 * (k - 1) / n, 3.0 - 1.9 * k / n
				table.insert(U.Roots, M.frustumN(6, ra, rb, -0.15, (q - prevP).Magnitude + 0.15, H.frameY(prevP, q - prevP) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), { col, H.scaled(col, 1.08), H.scaled(col, 0.9) }))
				if k == 2 then
					ST.mossCushion(U.Moss, rng, CFrame.new(q + Vector3.new(0, rb * 0.8, 0)), 4.2)
				end
				pu, py, prevP = u, y, q
			end
		end
	end
	-- ferns between the roots
	for k = 0, 6 do
		local a = k * 2 * math.pi / 7 + 0.45
		ST.fern(U.Fern, rng, Vector3.new(math.cos(a) * 16.5, 0.2, math.sin(a) * 16.5), 6, 5.5)
	end
	-- moss cushions up the trunk
	for k = 1, 6 do
		local a = rng:NextNumber(0, 6.28)
		local y = rng:NextNumber(38, 85)
		local r = 12.6 - (y - 34) * 0.07
		local nrm = Vector3.new(math.cos(a), 0, math.sin(a))
		ST.mossCushion(U.Moss, rng, CFrame.fromMatrix(nrm * (r - 0.6) + Vector3.new(0, y, 0), nrm:Cross(Vector3.yAxis), nrm), 6)
	end
	for _, r in ipairs(rows) do
		local c, s = r.cf.Position, r.size
		if r.name == "Branch" then
			-- the limb from its trunk end out to the canopy
			local a, b = (r.cf * CFrame.new(0, 0, -s.Z / 2)).Position, (r.cf * CFrame.new(0, 0, s.Z / 2)).Position
			if Vector3.new(a.X, 0, a.Z).Magnitude > Vector3.new(b.X, 0, b.Z).Magnitude then
				a, b = b, a
			end
			local n0 = #U.Bark
			ST.twistedLog(U.Branches, U.Bark, rng, a, b, 3.4, 2.0, H.scaled(BARK, 1.4))
			for j = n0 + 1, #U.Bark do
				U.Bark[j].Color = H.scaled(BARK, 1.09)
			end
		elseif r.name == "Canopy" then
			-- a centre cluster, a ring of clusters, drooping leaf tips at the rim
			local big = s.X > 50
			local yaw = rng:NextNumber(0, 6.28)
			local f = CFrame.new(c) * CFrame.Angles(0, yaw, 0)
			ST.blob(U.Leaves, rng, f, s.X * 0.3, s.Y * 0.36, s.Z * 0.3, ST.leafTone(r.color))
			local nr = if big then 8 else 6
			for k = 1, nr do
				local a = k * 2 * math.pi / nr + rng:NextNumber(-0.2, 0.2)
				local d = Vector3.new(math.cos(a), 0, math.sin(a))
				local p = f * (d * s.X * rng:NextNumber(0.31, 0.35) + Vector3.new(0, s.Y * rng:NextNumber(-0.16, 0.08), 0))
				ST.blob(U.Leaves, rng, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), s.X * rng:NextNumber(0.19, 0.23), s.Y * rng:NextNumber(0.24, 0.3), s.Z * rng:NextNumber(0.19, 0.23), ST.leafTone(H.scaled(r.color, rng:NextNumber(0.9, 1.1))))
			end
			for k = 1, 6 do
				local a = k * 2 * math.pi / 6 + rng:NextNumber(-0.3, 0.3)
				local d = (f - f.Position) * Vector3.new(math.cos(a), 0, math.sin(a))
				local p = c + d * s.X * 0.46 - Vector3.new(0, s.Y * 0.12, 0)
				ST.leaf(U.LeafTips, p, (d - Vector3.new(0, 0.7, 0)).Unit, 5.5, 3.2, H.scaled(r.color, rng:NextNumber(0.9, 1.08)), d + Vector3.new(0, 1, 0))
			end
		elseif r.name == "Vine" then
			ST.leafyVine(U.Vines, U.VineLeaves, rng, c + Vector3.new(0, s.Y / 2, 0), s.Y, 0.75, H.scaled(r.color, 0.85))
		elseif r.name == "RopeBand" and math.abs(select(2, r.cf:ToEulerAnglesYXZ())) < 0.01 then
			-- the rope band as a rope ring with 2 thinner turns
			for k, dy in ipairs({ -0.45, 0.1, 0.55 }) do
				local rr = 13.15 + (if k == 2 then 0.25 else 0)
				table.insert(U.Rope, M.frustumN(8, rr, rr, dy - 0.3, dy + 0.3, CFrame.new(0, c.Y, 0) * CFrame.Angles(math.rad(rng:NextNumber(-1.5, 1.5)), math.rad(22.5 + k * 7), 0), { ROPE, H.scaled(ROPE, 0.88) }))
			end
		elseif r.name == "MaskBoard" or r.name == "MaskBrow" or r.name == "MaskChin" then
			table.insert(U.Mask, H.chamfered(s, r.cf, r.color, { "frontFace" }, if r.name == "MaskBoard" then 0.45 else 0.3))
			if r.name == "MaskBoard" then
				local zf = -s.Z / 2 - 0.12
				for _, e in ipairs({ { 0, s.Y / 2 - 0.3, s.X, 0.6 }, { 0, -s.Y / 2 + 0.3, s.X, 0.6 }, { -s.X / 2 + 0.3, 0, 0.6, s.Y - 1.2 }, { s.X / 2 - 0.3, 0, 0.6, s.Y - 1.2 } }) do
					table.insert(U.MaskTrim, H.chamfered(Vector3.new(e[3], e[4], 0.25), r.cf * CFrame.new(e[1], e[2], zf), rgb(74, 48, 34), { "frontFace" }, 0.08))
				end
			end
		elseif r.name == "MaskHorn" then
			local base = (r.cf * CFrame.new(0, -s.Y / 2, 0)).Position
			table.insert(U.Mask, M.frustumN(6, s.X * 0.55, 0.12, 0, s.Y, H.frameY(base, r.cf.UpVector), { BONE, H.scaled(BONE, 0.9) }))
		end
	end
	-- 4 more leafy vines from the canopy rims
	for k = 1, 4 do
		local a = k * math.pi / 2 + 0.6
		local top = Vector3.new(math.cos(a) * 30, 92, math.sin(a) * 30)
		ST.leafyVine(U.Vines, U.VineLeaves, rng, top, rng:NextNumber(14, 22), 0.75, H.scaled(VINE, rng:NextNumber(0.85, 1.0)))
	end
	return finishR6(m, id, U)
end

---------------------------------------------------------------------
-- 10 TUNDRA WALL TORCH (tundra_light_blue_torch_wall, Tundra_4 x14 + the tundra arena x8): the improved wall_torch
-- (DevTools.PropsBatch4 B4.wall_torch, deterministic: the "/" bar with the cup on its top end) run from a copy with
-- the tundra colours: dark blue iron, a frosted wooden bar with a cold blue wrap, a cold cyan layered flame and Ember,
-- a little snow on the back plate and the cup rim. Today's Head (invisible, FirePoint kept) and the 3 colliders exactly
-- as the wall torch has them (today's Bracket, Stick and Head boxes).
---------------------------------------------------------------------
function P.tundraTorch(): string
	local id = "tundra_light_blue_torch_wall"
	local src = ServerStorage.DevTools.PropsBatch4.Source
	local i0 = string.find(src, "function B4.wall_torch(): Model", 1, true)
	assert(i0, "B4.wall_torch missing")
	local i1 = string.find(src, "\n---", i0, true)
	local body = string.sub(src, i0, i1)
	local function sub(a: string, b: string)
		local n
		body, n = string.gsub(body, a, b)
		assert(n > 0, "wall_torch anchor missing: " .. a)
	end
	sub("function B4%.wall_torch%(%): Model", "function B4.tundra_torch_r6(): Model")
	sub("P%.Iron", "TI")
	sub("st%.color", "TW")
	sub("br%.color", "TI")
	sub("LEATHER", "TL")
	sub("layeredFlame%(", "coldFlame(")
	sub("local U: any = { Wood = {}, Iron = {} }", "local U: any = { Wood = {}, Iron = {}, Snow = {} }")
	sub("\tU%.Glow = {}\n", "\ttable.insert(U.Snow, chamfered(Vector3.new(br.size.X + 0.06, 0.16, br.size.Z + 0.1), br.cf * CFrame.new(0, br.size.Y / 2 + 0.06, -0.03), SNOW, { \"topFrontBack\", \"topSides\" }, 0.05))\n\tfor k = 0, 2 do\n\t\tlocal a = k * 2.1 + 0.4\n\t\ttable.insert(U.Snow, chamfered(Vector3.new(0.26, 0.1, 0.18), rim * CFrame.new(math.cos(a) * 0.5, 0.07, math.sin(a) * 0.5) * CFrame.Angles(0, -a, 0), SNOW, { \"topFrontBack\", \"topSides\" }, 0.03))\n\tend\n\tU.Glow = {}\n")
	local defs = "local TI, TW, TL, SNOW = rgb(52, 66, 104), rgb(150, 172, 196), rgb(64, 80, 120), rgb(240, 246, 252)\n"
		.. "local function coldFlame(list: { BasePart }, cf: CFrame, s: number)\n"
		.. "\ttable.insert(list, H.flame(cf, 0.36 * s, 0.32 * s, 1.0 * s, rgb(60, 170, 255), Vector3.new(0.04, 0, 0.03) * s))\n"
		.. "\ttable.insert(list, H.flame(cf * CFrame.new(0, 0.08 * s, 0) * CFrame.Angles(0, rad(30), 0), 0.26 * s, 0.3 * s, 0.82 * s, rgb(110, 210, 255), Vector3.new(-0.03, 0, 0.02) * s))\n"
		.. "\ttable.insert(list, H.flame(cf * CFrame.new(0, 0.14 * s, 0), 0.15 * s, 0.22 * s, 0.58 * s, rgb(200, 240, 255)))\n"
		.. "end\n"
	local k = string.find(src, "\nreturn B4", 1, true)
	assert(k, "return B4 missing")
	local tmp = Instance.new("ModuleScript")
	tmp.Name = "PropsBatch4_tundraTorch"
	tmp.Source = string.sub(src, 1, k) .. defs .. body .. string.sub(src, k)
	tmp.Parent = ServerStorage.DevTools
	local ok, B4 = pcall(require, tmp:Clone())
	tmp:Destroy()
	assert(ok, tostring(B4))
	local m = (B4 :: any).tundra_torch_r6() :: Model
	local ember = m:FindFirstChild("Ember") :: BasePart
	ember.Color = rgb(96, 190, 255)
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: %.2f x %.2f x %.2f, pivot %s", id, size.X, size.Y, size.Z, tostring(m:GetPivot().Position))
end

---------------------------------------------------------------------
-- 11 FROZEN TREE (tundra_landmark_frozen_tree, the Tundra_1 landmark): a big dead tree in ice. Today's 3 trunk blocks
-- as twisted bark sections with winding grooves along their own (tilted) axes, the 2 forks as twisted limbs with a snow
-- cap, today's 18 branches as gnarled limbs with forked twigs (the swamp dead tree recipe), today's 15 branch snow
-- strips as soft snow caps, today's 38 icicles as faceted glass icicles at the same places and lengths (the tundra
-- icicle), today's 5 root wedges as buttress roots with snow drifts, today's 4 crystals as faceted glass crystals with
-- small shards, today's ice shell as a glassy ice collar round the trunk foot. Colliding parts (trunk, roots, crystals)
-- stay as invisible collision, the NoClimb walls stay; the PrimaryPart (the ice shell) becomes an invisible PivotPart.
---------------------------------------------------------------------
-- a buttress root inside a root wedge row r (tall side +Z towards the trunk): a flaring web under a tapering root log
local function buttressRoot(U: any, rng: Random, r: any, col: Color3, logR: number, webT: number)
	local L = lib()
	local H, M = L.H, L.M
	local c, s = r.cf.Position, r.size
	local rc = Vector3.new(c.X, 0, c.Z).Magnitude
	local y0, y1 = c.Y - s.Y / 2, c.Y + s.Y / 2
	local ui, uo = rc - s.Z / 2 + 0.3, rc + s.Z / 2 - 0.2
	local function at(u: number, y: number): CFrame
		return r.cf * CFrame.new(0, y - c.Y, -(u - rc))
	end
	local function curve(t: number): (number, number)
		local cu, cy = ui + (uo - ui) * 0.2, y0 + (y1 - y0) * 0.18
		local a, b = (1 - t) * (1 - t), 2 * (1 - t) * t
		return a * ui + b * cu + t * t * uo, a * (y1 - 0.3) + b * cy + t * t * (y0 + 0.2)
	end
	local n = 5
	local pu, py = curve(0)
	local prevP = at(pu, py).Position
	for k = 1, n do
		local u, y = curve(k / n)
		local T = webT * (1 - 0.5 * k / n)
		local mid = (pu + u) / 2
		if y - y0 > 0.1 then
			table.insert(U.RootWeb, H.piece("Part", Vector3.new(T, y - y0, u - pu + 0.04), at(mid, (y0 + y) / 2), H.scaled(col, 0.92)))
		end
		if py - y > 0.03 then
			table.insert(U.RootWeb, H.piece("WedgePart", Vector3.new(T, py - y, u - pu + 0.04), at(mid, (py + y) / 2), H.scaled(col, 0.92)))
		end
		local q = at(u, y).Position
		local ra, rb = logR * (1 - 0.6 * (k - 1) / n), logR * (1 - 0.6 * k / n)
		table.insert(U.Roots, M.frustumN(6, ra, rb, -0.1, (q - prevP).Magnitude + 0.1, H.frameY(prevP, q - prevP) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), { col, H.scaled(col, 1.08), H.scaled(col, 0.9) }))
		pu, py, prevP = u, y, q
	end
end

function P.frozenTree(): string
	local id = "tundra_landmark_frozen_tree"
	local L = lib()
	local H, M, TB = L.H, L.M, L.TB
	local ST = swampTrees()
	assert(TB.facetIcicle and TB.lump, "TB.facetIcicle / TB.lump missing")
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(61111)
	H.setBevelSelf(true)
	local BARK, SNOW, ICE = rgb(80, 58, 46), rgb(244, 248, 255), rgb(150, 214, 250)
	local U: any = { Trunk = {}, Bark = {}, Roots = {}, RootWeb = {}, Branches = {}, Twigs = {}, Snow = {}, Icicles = {}, Crystals = {}, IceCollar = {} }
	local function snowTone(n: Vector3): Color3
		return if n.Y > 0.5 then SNOW else H.scaled(SNOW, 0.9):Lerp(ICE, 0.15)
	end
	local rows = {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			table.insert(rows, { name = c.Name, cf = c.CFrame, size = c.Size, color = c.Color })
			if c == m.PrimaryPart then
				local a = Instance.new("Part")
				a.Name = "PivotPart"
				a.Size, a.CFrame, a.PivotOffset = c.Size, c.CFrame, c.PivotOffset
				a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.CastShadow = true, false, false, false, false
				a.Transparency = 1
				a.Parent = m
				m.PrimaryPart = a
			end
			if c.CanCollide then
				toCollision(c)
			else
				c:Destroy()
			end
		end
	end
	for _, r in ipairs(rows) do
		local c, s = r.cf.Position, r.size
		if r.name == "Trunk" and math.abs(r.cf.LookVector:Dot(Vector3.zAxis)) > 0.9 then
			-- a twisted bark section along today's block axis (the unrotated block of each pair)
			local up = r.cf.UpVector
			local a, b = c - up * (s.Y / 2 + (if c.Y > 15 then 0.6 else 0)), c + up * (s.Y / 2 + 0.3)
			local r0 = s.X * 0.5
			ST.twistedLog(U.Trunk, U.Bark, rng, a, b, r0, r0 * 0.78, H.scaled(BARK, rng:NextNumber(0.95, 1.05)), rng:NextNumber(0, 1), math.rad(11))
		elseif r.name == "Fork" then
			local up = r.cf.UpVector
			local a, b = c - up * (s.Y / 2 + 0.4), c + up * (s.Y / 2)
			ST.twistedLog(U.Branches, U.Bark, rng, a, b, s.X * 0.5, s.X * 0.28, H.scaled(BARK, 0.95), rng:NextNumber(0, 1), math.rad(13))
		elseif r.name == "ForkSnow" then
			TB.lump(U.Snow, rng, r.cf * CFrame.new(0, -0.1, 0), s.X * 0.5, 0.45, s.Z * 0.5, snowTone, 0.2)
		elseif r.name == "Branch" then
			local a, b = r.cf * Vector3.new(-s.X / 2, 0, 0), r.cf * Vector3.new(s.X / 2, 0, 0)
			if Vector3.new(a.X, 0, a.Z).Magnitude > Vector3.new(b.X, 0, b.Z).Magnitude then
				a, b = b, a
			end
			ST.gnarledBranch(U.Branches, U.Twigs, rng, a - (b - a).Unit * 0.6, b, s.Y * 0.5, H.scaled(BARK, rng:NextNumber(0.92, 1.08)))
		elseif r.name == "BranchSnow" then
			-- a soft snow cap along the branch: a bevelled strip and 2-3 lumps
			table.insert(U.Snow, H.chamfered(Vector3.new(s.X * 0.92, s.Y, s.Z * 0.8), r.cf * CFrame.new(0, -0.08, 0), SNOW, { "topFrontBack", "topSides" }, 0.22))
			for k = 1, math.max(2, math.floor(s.X / 7)) do
				local x = (k / (math.floor(s.X / 7) + 1) - 0.5) * s.X * 0.85
				TB.lump(U.Snow, rng, r.cf * CFrame.new(x, 0.12, 0), rng:NextNumber(0.9, 1.4), 0.3, s.Z * 0.4, snowTone, 0.12)
			end
		elseif r.name == "Icicle" then
			-- the tundra faceted icicle, today's place, length and width
			TB.facetIcicle(U, "Icicles", c + Vector3.new(0, s.Y / 2 - 0.1, 0), s.Y / 3, s.X / 0.9, rng:NextNumber(0, 6.28))
		elseif r.name == "Root" then
			buttressRoot(U, rng, r, H.scaled(BARK, rng:NextNumber(0.95, 1.08)), 1.7, 2.2)
		elseif r.name == "RootSnow" then
			TB.lump(U.Snow, rng, r.cf * CFrame.new(0, 0.1, 0), s.X * 0.5, 0.55, s.Z * 0.42, snowTone, 0.2)
		elseif r.name == "Crystal" then
			-- a faceted glass crystal (6-sided prism, pointed tip) along today's crystal, 2 small shards at its foot
			local up = r.cf.UpVector
			local base = c - up * (s.Y / 2)
			local f = H.frameY(base, up) * CFrame.Angles(0, rng:NextNumber(0, 1), 0)
			local rr = math.min(s.X, s.Z) * 0.48
			table.insert(U.Crystals, M.frustumN(6, rr, rr * 0.86, 0, s.Y * 0.72, f, { r.color, H.scaled(r.color, 1.12), H.scaled(r.color, 0.9) }))
			table.insert(U.Crystals, M.frustumN(6, rr * 0.86, 0.06, s.Y * 0.72, s.Y, f, { H.scaled(r.color, 1.15), r.color }))
			for k = 1, 2 do
				local a = rng:NextNumber(0, 6.28)
				local p = Vector3.new(c.X + math.cos(a) * rr * 1.6, 0, c.Z + math.sin(a) * rr * 1.6)
				local tilt = (Vector3.new(math.cos(a), 0, math.sin(a)) * 0.45 + Vector3.yAxis).Unit
				local h = s.Y * rng:NextNumber(0.22, 0.32)
				local sf = H.frameY(p, tilt)
				table.insert(U.Crystals, M.frustumN(6, rr * 0.35, rr * 0.3, -0.2, h * 0.7, sf, { r.color, H.scaled(r.color, 1.12) }))
				table.insert(U.Crystals, M.frustumN(6, rr * 0.3, 0.04, h * 0.7, h, sf, { H.scaled(r.color, 1.15), r.color }))
			end
		elseif r.name == "IceShell" then
			-- a glassy ice collar round the trunk foot, a snow drift ring round it
			table.insert(U.IceCollar, M.frustumN(10, 6.6, 5.4, 0, 4.2, CFrame.new(c.X, 0, c.Z) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), { ICE, H.scaled(ICE, 1.1), H.scaled(ICE, 0.9) }))
			for k = 1, 6 do
				local a = k * math.pi / 3 + rng:NextNumber(-0.3, 0.3)
				TB.lump(U.Snow, rng, CFrame.new(c.X + math.cos(a) * 7.2, 0.2, c.Z + math.sin(a) * 7.2) * CFrame.Angles(0, -a, 0), rng:NextNumber(1.4, 2.2), 0.7, rng:NextNumber(1.0, 1.5), snowTone, 0.2)
			end
		end
	end
	return finishR6(m, id, U, { Icicles = TB.ICICLE_OPTS, Crystals = { material = Enum.Material.Glass, transparency = 0.15, shadow = false }, IceCollar = { material = Enum.Material.Glass, transparency = 0.35, shadow = false } })
end

---------------------------------------------------------------------
-- 12 GIANT CAULDRON (swamp_landmark_giant_cauldron, the swamp boss arena): the improved swamp cauldron recipe
-- (DevTools.PropsSwampMagic swamp_cauldron) at landmark scale: today's stacked pot cylinders as one rounded cast iron
-- body (16-sided bands from the base over the belly to the neck, inside today's cylinders), today's 2 bands as riveted
-- iron bands, today's rim as a thick lip ring of 16 segments, today's 2 handle brackets as lugs with heavy ring handles,
-- today's 3 legs as tapered iron claw legs, today's 8 logs as bark logs with grooves and pale cut ends, embers and coals
-- under the pot, a small stack of wood and bones at the foot. Today's glowing liquid, its drips and the 8 magenta
-- runes stay exactly (the runes in carved dark panels), with glowing bubbles on the liquid. Every colliding part stays
-- as invisible collision; no script, prompt or light on it.
---------------------------------------------------------------------
function P.giantCauldron(): string
	local id = "swamp_landmark_giant_cauldron"
	local L = lib()
	local H, M = L.H, L.M
	local ST = swampTrees()
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(61212)
	H.setBevelSelf(true)
	local IRON, IRON_L, BONE = rgb(80, 86, 96), rgb(112, 118, 130), rgb(226, 218, 196)
	local U: any = { Pot = {}, Iron = {}, Bubbles = {}, Logs = {}, Embers = {}, Carving = {}, Bones = {} }
	local rows = {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			table.insert(rows, { name = c.Name, cf = c.CFrame, size = c.Size, color = c.Color })
			if c.CanCollide then
				toCollision(c)
			end
		end
	end
	local F0 = CFrame.identity
	-- the body: base -> belly -> shoulder -> neck (radii inside today's cylinders)
	local bands = { { 3.0, 5.6, 15.2, 18.6 }, { 5.6, 8.2, 18.6, 23.2 }, { 8.2, 15.0, 23.2, 24.9 }, { 15.0, 21.8, 24.9, 24.5 }, { 21.8, 25.2, 24.5, 21.8 }, { 25.2, 28.2, 21.8, 20.0 }, { 28.2, 30.3, 20.0, 19.9 } }
	for i, b in ipairs(bands) do
		local c = H.scaled(IRON, 0.9 + 0.035 * i)
		table.insert(U.Pot, M.frustumN(16, b[3], b[4], b[1] - (if i > 1 then 0.03 else 0), b[2], F0 * CFrame.Angles(0, math.rad(i * 5), 0), { c, H.scaled(c, 1.1), H.scaled(c, 0.9) }))
	end
	-- the 2 riveted bands
	for _, y in ipairs({ 12, 19 }) do
		table.insert(U.Iron, M.frustumN(16, 25.6, 25.6, y - 0.78, y + 0.78, F0 * CFrame.Angles(0, math.rad(11.25), 0), { IRON_L, H.scaled(IRON_L, 0.88) }))
		for k = 0, 23 do
			local a = k * math.pi / 12 + math.rad(7.5)
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			table.insert(U.Iron, H.chamfered(Vector3.new(0.7, 0.7, 0.35), CFrame.lookAt(d * 25.7 + Vector3.new(0, y, 0), d * 30 + Vector3.new(0, y, 0)), H.scaled(IRON_L, 1.15), { "frontFace" }, 0.1))
		end
	end
	-- the rim: a lip ring and 16 bevelled lip segments round the liquid (radius 21)
	table.insert(U.Pot, M.frustumN(16, 23.5, 23.9, 30.0, 32.6, F0, { IRON_L, H.scaled(IRON_L, 1.08), H.scaled(IRON_L, 0.92) }))
	for k = 0, 15 do
		local a = k * math.pi / 8
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = d * 22.45 + Vector3.new(0, 32.75, 0)
		table.insert(U.Pot, H.chamfered(Vector3.new(3.2, 0.5, 2 * 24.1 * math.tan(math.pi / 16)), CFrame.lookAt(p, p + d) * CFrame.Angles(0, math.rad(90), 0), H.scaled(IRON_L, if k % 2 == 0 then 1.12 else 1.02), { "topFrontBack" }, 0.2))
	end
	for _, r in ipairs(rows) do
		local c, s = r.cf.Position, r.size
		if r.name == "Leg" then
			-- a tapered iron leg with 3 claws
			table.insert(U.Iron, M.frustumN(6, s.X * 0.4, s.X * 0.55, c.Y - s.Y / 2, c.Y + s.Y / 2 + 0.4, CFrame.new(c.X, 0, c.Z) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), { IRON, H.scaled(IRON, 1.12), H.scaled(IRON, 0.9) }))
			local out = Vector3.new(c.X, 0, c.Z).Unit
			for t = -1, 1 do
				local d = (out + Vector3.new(-out.Z, 0, out.X) * t * 0.6).Unit
				table.insert(U.Iron, M.frustumN(4, 0.8, 0.15, 0, 2.0, H.frameY(Vector3.new(c.X, c.Y - s.Y / 2 + 0.7, c.Z) + d * s.X * 0.35, (d - Vector3.new(0, 0.3, 0)).Unit), { IRON_L, IRON }))
			end
		elseif r.name == "Log" then
			-- a bark log with grooves and pale cut ends
			local axis = r.cf.LookVector
			local a, b = c - axis * s.Z / 2, c + axis * s.Z / 2
			local lr = s.X / 2
			local cf = H.frameY(a, b - a) * CFrame.Angles(0, rng:NextNumber(0, 1), 0)
			table.insert(U.Logs, M.frustumN(8, lr, lr * 0.94, 0, s.Z, cf, { r.color, H.scaled(r.color, 1.1), H.scaled(r.color, 0.88) }))
			for _, e in ipairs({ 0, 1 }) do
				table.insert(U.Logs, M.frustumN(8, lr * 0.8, lr * 0.8, -0.03, 0.03, H.frameY(a:Lerp(b, e), b - a), { rgb(170, 132, 92) }))
			end
			for k = 0, 2 do
				local off = (cf * CFrame.Angles(0, k * 2.1 + 0.4, 0)).XVector * lr
				table.insert(U.Logs, H.bar(a + off + axis * 0.8, b + off - axis * rng:NextNumber(0.8, 1.6), 0.14, H.scaled(r.color, 0.6)))
			end
		elseif r.name == "Rune" and s.Y > 4 then
			-- the carved dark panel behind each rune pair (the runes stay as they are)
			local zs = if r.cf.LookVector:Dot(Vector3.new(c.X, 0, c.Z).Unit) > 0 then 1 else -1
			local back = r.cf * CFrame.new(0, 0.2, 0.3 * zs) * CFrame.Angles(0, if zs > 0 then 0 else math.pi, 0)
			table.insert(U.Carving, H.chamfered(Vector3.new(4.8, 6.6, 0.4), back, rgb(40, 34, 48), { "frontFace" }, 0.2))
			table.insert(U.Carving, H.chamfered(Vector3.new(5.6, 7.4, 0.3), back * CFrame.new(0, 0, 0.12), H.scaled(IRON_L, 0.95), { "frontFace" }, 0.15))
		elseif r.name == "Handle" and s.Y > 5 then
			-- lugs on the belly and a heavy ring handle (in today's bracket)
			local sx = math.sign(c.X)
			for _, y in ipairs({ 18, 26 }) do
				table.insert(U.Iron, H.chamfered(Vector3.new(4.0, 2.2, 2.8), CFrame.new(sx * 25.0, y, 0), H.scaled(IRON, 1.08), { "vertical", "topFrontBack", "bottomFrontBack" }, 0.3))
			end
			local rc = Vector3.new(sx * 26.6, 22, 0)
			local rr = 4.0
			for k = 0, 11 do
				local a0, a1 = k * math.pi / 6, (k + 1) * math.pi / 6
				local p0 = rc + Vector3.new(math.cos(a0) * rr * 0.55, math.sin(a0) * rr, 0)
				local p1 = rc + Vector3.new(math.cos(a1) * rr * 0.55, math.sin(a1) * rr, 0)
				table.insert(U.Iron, H.bar(p0, p1, 1.3, H.scaled(IRON_L, if k % 2 == 0 then 1.0 else 0.92)))
			end
		end
	end
	-- glowing bubbles on the liquid (its glow colour)
	local liquidRow
	for _, r in ipairs(rows) do
		if r.name == "Liquid" then
			liquidRow = r
		end
	end
	local ly = liquidRow.cf.Position.Y + liquidRow.size.X / 2
	for k = 1, 9 do
		local a = k * 2.4
		local rr = 3 + k * 1.8
		local s = rng:NextNumber(0.9, 2.0)
		table.insert(U.Bubbles, M.frustumN(8, s, s * 0.3, ly - 0.1, ly + s * 0.35, CFrame.new(math.cos(a) * rr, 0, math.sin(a) * rr), { liquidRow.color, H.scaled(liquidRow.color, 1.1) }))
	end
	-- embers and coals among the logs under the pot
	for k = 1, 14 do
		local a = k * 0.45
		local rr = rng:NextNumber(5, 15)
		local p = Vector3.new(math.cos(a) * rr, 0.35, math.sin(a) * rr)
		if k % 3 == 0 then
			ST.blob(U.Logs, rng, CFrame.new(p), 1.0, 0.5, 0.8, function(): Color3
				return rgb(34, 30, 30)
			end, 0.3)
		else
			table.insert(U.Embers, M.frustumN(5, rng:NextNumber(0.4, 0.7), 0.15, 0, rng:NextNumber(0.5, 0.9), CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), { if k % 2 == 0 then rgb(255, 122, 46) else rgb(255, 170, 60) }))
		end
	end
	-- a small stack of firewood and bones at the foot (between 2 logs)
	local base = CFrame.new(-15.5, 0, -15.5) * CFrame.Angles(0, math.rad(45), 0)
	for k, l in ipairs({ { -1.0, 0.7 }, { 1.0, 0.7 }, { 0, 2.0 } }) do
		local cf = base * CFrame.new(l[1], l[2], 0)
		local a, b = (cf * CFrame.new(0, 0, -2.6)).Position, (cf * CFrame.new(0, 0, 2.6)).Position
		table.insert(U.Logs, M.frustumN(8, 0.7, 0.66, 0, 5.2, H.frameY(a, b - a) * CFrame.Angles(0, k, 0), { rgb(78, 58, 44), rgb(96, 70, 50), rgb(64, 48, 36) }))
		table.insert(U.Logs, M.frustumN(8, 0.56, 0.56, -0.03, 0.03, H.frameY(b, b - a), { rgb(170, 132, 92) }))
	end
	for k, t in ipairs({ { 2.6, 0.35, 1.2, 0.5 }, { 3.0, 0.35, -1.4, -0.3 } }) do
		local cf = base * CFrame.new(t[1], t[2], t[3]) * CFrame.Angles(0, t[4], 0)
		local a, b = (cf * CFrame.new(-1.3, 0, 0)).Position, (cf * CFrame.new(1.3, 0, 0)).Position
		table.insert(U.Bones, H.bar(a, b, 0.42, BONE))
		for _, e in ipairs({ a, b }) do
			for _, sz in ipairs({ -0.22, 0.22 }) do
				ST.blob(U.Bones, rng, cf - cf.Position + e + (cf - cf.Position) * Vector3.new(0, 0, sz), 0.3, 0.26, 0.26, function(): Color3
					return BONE
				end)
			end
		end
	end
	local sk = base * CFrame.new(1.4, 0.75, 0.2) * CFrame.Angles(0, math.rad(-30), 0)
	ST.blob(U.Bones, rng, sk, 0.8, 0.7, 0.85, function(n: Vector3): Color3
		return if n.Y > 0 then BONE else H.scaled(BONE, 0.9)
	end, 0.5)
	for _, ex in ipairs({ -0.32, 0.32 }) do
		table.insert(U.Carving, H.piece("Part", Vector3.new(0.34, 0.3, 0.1), sk * CFrame.new(ex, 0.1, -0.82), rgb(40, 34, 48)))
	end
	return finishR6(m, id, U, { Bubbles = { material = Enum.Material.Neon, shadow = false }, Embers = { material = Enum.Material.Neon, shadow = false } })
end

---------------------------------------------------------------------
-- 13 - 16 SWAMP RECOLOURS of improved bases (owner: "take the improved X and change the colours for the swamp"):
-- 13 swamp_furniture_crate = the improved crate's parts in dark rotten wood with moss and mud; 14 swamp_fence_fence =
-- the improved fence_section (B4.fence_section, run from a copy) in dark rotten wood, bent posts, moss, mud; 15
-- swamp_sign_hub_sign = the improved sign board recipe (posts, 3 planks in a trimmed frame, iron corners, a stone
-- footing, the invisible GUI carrier "Board") in rotten wood with moss and a rope wrap, with Heaven / Dead variants
-- for the copies there; 16 swamp_statue_bone_pile = the improved skull_bones in dirty bone with moss and green slime.
-- Each template keeps its own colliders exactly (invisible "Collision"); 15 adds the board's collider that every copy
-- carries today on its own Board part.
---------------------------------------------------------------------
local SWAMP = { mud = rgb(58, 42, 28), moss = rgb(63, 122, 44), mossTop = rgb(96, 150, 58), slime = rgb(120, 176, 52), rope = rgb(150, 128, 90), rust = rgb(96, 84, 74) }

-- a base colour in swamp rot: darker, greener, less saturated
local function rot(c: Color3, k: number?): Color3
	local h, s, v = c:ToHSV()
	local d = Color3.fromHSV(h, s * 0.72, v * (k or 0.66))
	return d:Lerp(rgb(58, 62, 40), 0.22)
end
P.swampRot = rot

local function mossTone(n: Vector3): Color3
	return if n.Y > 0.5 then SWAMP.mossTop else SWAMP.moss
end

local function plainVisual(p: BasePart)
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.Anchored = true
end

function P.swampCrate(): string
	local id = "swamp_furniture_crate"
	local L = lib()
	local H, TB = L.H, L.TB
	local old = folder():FindFirstChild(id) :: Model
	local base = folder():FindFirstChild("crate") :: Model
	assert(old and base, "templates missing")
	local m = old:Clone()
	local rng = Random.new(61313)
	H.setBevelSelf(true)
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			toCollision(c)
		end
	end
	-- the improved crate's parts (same footprint), visual only, in rotten wood (iron stays iron, a bit rusty)
	for _, c in ipairs(base:GetChildren()) do
		if c:IsA("BasePart") then
			local p = c:Clone()
			plainVisual(p)
			p.Color = if c.Name == "Cap" or c.Name == "Nail" then c.Color:Lerp(SWAMP.rust, 0.4) else rot(c.Color, if c.Name == "Core" then 0.8 else 0.66)
			p.Parent = m
		end
	end
	local U: any = { Moss = {}, Mud = {} }
	-- moss on the lid and down one corner, mud round the foot
	for k = 1, 3 do
		TB.lump(U.Moss, rng, CFrame.new(rng:NextNumber(-1.4, 1.2), 4.02, rng:NextNumber(-1.3, 1.3)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), rng:NextNumber(0.5, 0.8), 0.14, rng:NextNumber(0.4, 0.6), mossTone, 0.04)
	end
	for _, y in ipairs({ 3.2, 2.4, 1.6 }) do
		TB.lump(U.Moss, rng, CFrame.new(1.9, y, -1.9) * CFrame.Angles(0, math.rad(45), 0), 0.24, 0.36, 0.12, mossTone, 0.05)
	end
	for k = 0, 7 do
		local a = k * math.pi / 4 + rng:NextNumber(-0.2, 0.2)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = Vector3.new(d.X * 1.86, 0.08, d.Z * 1.86)
		TB.lump(U.Mud, rng, CFrame.new(p) * CFrame.Angles(0, -a, 0), 0.4, 0.14, 0.22, function(n: Vector3): Color3
			return if n.Y > 0.5 then H.scaled(SWAMP.mud, 1.15) else SWAMP.mud
		end, 0.06)
	end
	return finishR6(m, id, U)
end

function P.swampBonePile(): string
	local id = "swamp_statue_bone_pile"
	local L = lib()
	local H, TB = L.H, L.TB
	local ST = swampTrees()
	local old = folder():FindFirstChild(id) :: Model
	local base = folder():FindFirstChild("skull_bones") :: Model
	assert(old and base, "templates missing")
	local m = old:Clone()
	local rng = Random.new(61616)
	H.setBevelSelf(true)
	-- today's pile has no collider: its parts go, the improved skull_bones meshes come in (its skull collider not:
	-- the swamp pile never collided)
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			c:Destroy()
		end
	end
	for _, c in ipairs(base:GetChildren()) do
		if c:IsA("BasePart") and not c.CanCollide then
			local p = c:Clone()
			plainVisual(p)
			if c.Name == "Bones" then
				p.Color = rgb(206, 194, 160)
			elseif c.Name == "Aged" then
				p.Color = rgb(170, 164, 120)
			elseif c.Name == "Sockets" then
				p.Color = rgb(40, 44, 34)
			end
			p.Parent = m
			if c == base.PrimaryPart then
				m.PrimaryPart = p
			end
		end
	end
	local U: any = { Moss = {}, Slime = {} }
	-- moss on the pile, green slime dripping off the skull and pooling at the foot
	for k = 1, 4 do
		TB.lump(U.Moss, rng, CFrame.new(rng:NextNumber(-2.4, 1.8), rng:NextNumber(0.5, 0.9), rng:NextNumber(-1.8, 2.2)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), rng:NextNumber(0.45, 0.7), 0.16, rng:NextNumber(0.35, 0.55), mossTone, 0.05)
	end
	for _, d in ipairs({ { 0.9, 2.55, -0.55 }, { -0.4, 2.7, 0.5 } }) do
		ST.mossStrand(U.Slime, rng, Vector3.new(d[1], d[2], d[3]), 0.7, SWAMP.slime)
	end
	for k = 1, 3 do
		TB.lump(U.Slime, rng, CFrame.new(rng:NextNumber(-2.6, 2.4), 0.04, rng:NextNumber(-2.2, 2.4)), rng:NextNumber(0.5, 0.8), 0.06, rng:NextNumber(0.4, 0.7), function(): Color3
			return SWAMP.slime
		end, 0.02)
	end
	return finishR6(m, id, U, { Slime = { material = Enum.Material.SmoothPlastic, shadow = false } })
end

-- 14: the improved fence builder from a copy of DevTools.PropsBatch4 with the swamp colours, bent posts, moss and mud
function P.swampFence(): string
	local id = "swamp_fence_fence"
	local src = ServerStorage.DevTools.PropsBatch4.Source
	local i0 = string.find(src, "function B4.fence_section(): Model", 1, true)
	assert(i0, "B4.fence_section missing")
	local i1 = string.find(src, "\n---", i0, true)
	local body = string.sub(src, i0, i1)
	local function sub(a: string, b: string)
		local n
		body, n = string.gsub(body, a, b)
		assert(n > 0, "fence anchor missing: " .. a)
	end
	sub("function B4%.fence_section%(%): Model", "function B4.swamp_fence_r6(): Model")
	sub("graded%(scaled%(r%.color, if i == 1 then 1 else 0%.93%), 2, 4%)", "graded(scaled(SW_POST, if i == 1 then 1 else 0.93), 2, 4)")
	sub("r%.cf %* CFrame%.new%(0, %-0%.1, 0%)", "r.cf * CFrame.new(0, -0.1, 0) * CFrame.Angles(rad(if i == 1 then 2.5 else -2), 0, rad(if i == 1 then -2 else 2.5))")
	sub("{ P%.WoodMid, scaled%(P%.WoodMid, 0%.9%) }", "{ SW_CAP, scaled(SW_CAP, 0.9) }")
	sub("scaled%(r%.color, %({ 1, 0%.93, 0%.87, 0%.96 }%)", "scaled(SW_RAIL, ({ 1, 0.93, 0.87, 0.96 })")
	sub("ROPE%)", "SW_ROPE)")
	sub("local U: any = { Wood = {}, Iron = {}, Plants = {} }", "local U: any = { Wood = {}, Iron = {}, Plants = {}, Moss = {}, Mud = {} }")
	sub("\tfinishB4%(m, \"fence_section\", U, \"Wood\", { Plants = { shadow = false } }%)", "\tswampExtras(U, rng)\n\tfinishB4(m, \"fence_section\", U, \"Wood\", { Plants = { shadow = false } })")
	local defs = "local SW_POST, SW_RAIL, SW_CAP, SW_ROPE = rgb(56, 42, 34), rgb(92, 74, 56), rgb(70, 54, 42), rgb(150, 128, 90)\n"
		.. "local function swampExtras(U: any, rng: Random)\n"
		.. "\tlocal TB = (require(ServerStorage.DevTools.PropsTundraGates:Clone()) :: any).TB\n"
		.. "\tlocal function mt(n: Vector3): Color3 return if n.Y > 0.5 then rgb(96, 150, 58) else rgb(63, 122, 44) end\n"
		.. "\tfor _, x in ipairs({ -3.5, 3.5 }) do\n"
		.. "\t\tTB.lump(U.Mud, rng, CFrame.new(x, 0.06, 0), 0.85, 0.18, 0.8, function(n: Vector3): Color3 return if n.Y > 0.5 then rgb(70, 52, 34) else rgb(58, 42, 28) end, 0.06)\n"
		.. "\t\tTB.lump(U.Moss, rng, CFrame.new(x + rng:NextNumber(-0.1, 0.1), 3.95, 0), 0.42, 0.14, 0.42, mt, 0.04)\n"
		.. "\tend\n"
		.. "\tfor _, p in ipairs({ { -1.6, 3.38 }, { 2.2, 3.38 }, { 0.6, 1.78 } }) do\n"
		.. "\t\tTB.lump(U.Moss, rng, CFrame.new(p[1], p[2], 0) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), rng:NextNumber(0.5, 0.8), 0.12, 0.22, mt, 0.03)\n"
		.. "\tend\n"
		.. "end\n"
	local k = string.find(src, "\nreturn B4", 1, true)
	assert(k, "return B4 missing")
	local tmp = Instance.new("ModuleScript")
	tmp.Name = "PropsBatch4_swampFence"
	tmp.Source = string.sub(src, 1, k) .. defs .. body .. string.sub(src, k)
	tmp.Parent = ServerStorage.DevTools
	local ok, B4 = pcall(require, tmp:Clone())
	tmp:Destroy()
	assert(ok, tostring(B4))
	local m = (B4 :: any).swamp_fence_r6() :: Model
	-- today's colliders exactly (the swamp copies' posts sit up to 0.001 off the plains kit's)
	for _, c in ipairs(m:GetChildren()) do
		if c.Name == "Collision" then
			c:Destroy()
		end
	end
	for _, c in ipairs((folder():FindFirstChild(id) :: Model):GetChildren()) do
		if c:IsA("BasePart") and c.CanCollide then
			local p = c:Clone()
			toCollision(p)
			p.Parent = m
		end
	end
	-- the grass tufts as swamp moss tufts
	local plants = m:FindFirstChild("Plants") :: BasePart
	if plants and plants:IsA("PartOperation") then
		plants.UsePartColor = true
		plants.Color = rgb(70, 112, 46)
	end
	P.install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: %.2f x %.2f x %.2f", id, size.X, size.Y, size.Z)
end

-- 15: the improved sign board recipe in swamp wood; Post / Trim / Planks as single-colour unions so the Heaven and
-- Dead copies keep their own colours (Variants), Moss hidden there
function P.swampSign(): string
	local id = "swamp_sign_hub_sign"
	local L = lib()
	local H, M, TB = L.H, L.M, L.TB
	local ST = swampTrees()
	local old = folder():FindFirstChild(id) :: Model
	assert(old, "template " .. id .. " missing")
	local m = old:Clone()
	local rng = Random.new(61515)
	H.setBevelSelf(true)
	local POST, TRIM, BOARD, STONE = rgb(58, 44, 36), rgb(74, 56, 44), rgb(129, 106, 82), rgb(104, 106, 96)
	local U: any = { Post = {}, Trim = {}, Planks = {}, Iron = {}, Stone = {}, Moss = {}, Rope = {} }
	local post, trims = nil, {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			if c.Name == "Post" then
				post = { cf = c.CFrame, size = c.Size }
			else
				table.insert(trims, { cf = c.CFrame, size = c.Size })
			end
			toCollision(c)
		end
	end
	-- the board: every copy carries a colliding Board today (5.5 x 2.6 x 0.4 at (0, 5, -0.6)): its collider, and the
	-- invisible GUI carrier the sync moves the copies' texts onto
	local bcf, bs = CFrame.new(0, 5, -0.6), Vector3.new(5.5, 2.6, 0.4)
	local col = Instance.new("Part")
	col.Size, col.CFrame = bs, bcf
	col.Anchored = true
	col.Parent = m
	toCollision(col)
	local carrier = H.piece("Part", bs, bcf * CFrame.new(0, 0, -0.02), BOARD)
	carrier.Name = "Board"
	carrier.Transparency = 1
	carrier.CanCollide, carrier.CanQuery, carrier.CanTouch, carrier.CastShadow = false, false, false, false
	carrier.Parent = m
	-- the post, a little bent, with a pyramid cap and a rope wrap
	table.insert(U.Post, H.chamfered(post.size - Vector3.new(0, 0.5, 0), post.cf * CFrame.new(0, 0.05, 0) * CFrame.Angles(math.rad(1.5), 0, math.rad(-2)), POST, { "vertical" }, 0.12))
	table.insert(U.Post, M.frustumN(4, 0.6, 0.1, 6.24, 6.7, CFrame.new(0.1, 0, 0) * CFrame.Angles(0, math.rad(45), 0), { POST }))
	for k = 0, 2 do
		table.insert(U.Rope, M.frustumN(8, 0.47, 0.47, -0.06, 0.06, H.frameY(Vector3.new(-0.03, 2.1 + k * 0.14, 0), Vector3.yAxis) * CFrame.Angles(math.rad(8), rng:NextNumber(0, 6.28), 0), { SWAMP.rope, H.scaled(SWAMP.rope, 0.88) }))
	end
	-- 3 planks (front 0.04 behind the carrier's front), a back board, 4 trims
	local bp = bcf.Position
	for k = 0, 2 do
		local h = bs.Y / 3
		table.insert(U.Planks, H.chamfered(Vector3.new(bs.X, h - 0.06, bs.Z - 0.1), CFrame.new(bp.X, bp.Y - bs.Y / 2 + h * (k + 0.5), bp.Z - 0.03) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-1.2, 1.2))), BOARD, { "topFrontBack", "bottomFrontBack" }, 0.05))
	end
	table.insert(U.Planks, H.piece("Part", Vector3.new(bs.X - 0.2, bs.Y - 0.2, 0.06), CFrame.new(bp.X, bp.Y, bp.Z + bs.Z / 2 - 0.08), BOARD))
	for i, r in ipairs(trims) do
		table.insert(U.Trim, H.chamfered(r.size, r.cf * CFrame.Angles(0, 0, math.rad(if i == 1 then 1.0 else -0.8)), TRIM, { "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }, 0.08))
	end
	local front = bp.Z - bs.Z / 2
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Trim, H.chamfered(Vector3.new(0.4, bs.Y + 0.4, 0.5), CFrame.new(sx * (bs.X / 2 + 0.05), bp.Y, bp.Z), TRIM, { "vertical" }, 0.08))
		for _, y in ipairs({ -1, 1 }) do
			table.insert(U.Iron, H.piece("Part", Vector3.new(0.5, 0.12, 0.06), CFrame.new(sx * (bs.X / 2 - 0.05), bp.Y + y * (bs.Y / 2 + 0.05), front - 0.3), SWAMP.rust))
			H.rivet(U.Iron, Vector3.new(sx * (bs.X / 2 + 0.05), bp.Y + y * (bs.Y / 2 - 0.35), front - 0.28), 0.12)
		end
	end
	-- the stone footing, moss on the top trim, the cap and the footing, a hanging moss strand
	for k = 0, 1 do
		table.insert(U.Stone, H.chamfered(Vector3.new(0.78, 0.45, 1.5), CFrame.new(-0.4 + k * 0.8, 0.225, 0), H.scaled(STONE, ({ 1, 0.88 })[k + 1]), { "topFrontBack", "topSides" }, 0.12))
	end
	for _, p in ipairs({ { -1.9, 6.62, -0.6, 0.7 }, { 1.2, 6.62, -0.6, 0.55 }, { 0.15, 6.68, 0, 0.36 }, { 0.3, 0.47, 0.2, 0.5 } }) do
		TB.lump(U.Moss, rng, CFrame.new(p[1], p[2], p[3]) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), p[4], 0.14, p[4] * 0.55, mossTone, 0.04)
	end
	ST.mossStrand(U.Moss, rng, Vector3.new(2.3, 3.4, -0.62), 0.9, SWAMP.moss)
	local r = finishR6(m, id, U, { Post = { single = POST }, Trim = { single = TRIM }, Planks = { single = BOARD }, Moss = { single = SWAMP.moss } })
	-- the variants: the Heaven and Dead hub signs keep today's colours there
	local tpl = folder():FindFirstChild(id) :: Model
	local vf = tpl:FindFirstChild("_Variants") or Instance.new("Folder")
	vf.Name = "_Variants"
	vf.Parent = tpl
	local function variant(name: string, attrs: { [string]: any })
		local c = vf:FindFirstChild(name) or Instance.new("Configuration")
		c.Name = name
		for k, v in pairs(attrs) do
			c:SetAttribute(k, v)
		end
		c.Parent = vf
	end
	variant("Heaven", { Color_Post = Color3.fromHex("d6a032"), Color_Trim = Color3.fromHex("ffd054"), Color_Planks = Color3.fromHex("f2f0ea"), Transparency_Moss = 1 })
	variant("Dead", { Color_Post = Color3.fromHex("403a3c"), Color_Trim = Color3.fromHex("403a3c"), Color_Planks = Color3.fromHex("e8e2ce"), Transparency_Moss = 1 })
	return r
end

-- the Variant attribute on the sign copies by zone (Heaven / Dead; the swamp ones default)
function P.swampSignVariants(): string
	local lines = {}
	for _, root in ipairs({ workspace.Zones, workspace._Staging.AssetPreview.ByZone }) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Model") and d:GetAttribute("MapPropId") == "swamp_sign_hub_sign" then
				local path = d:GetFullName()
				local v = if path:find("Heaven") then "Heaven" elseif path:find("Dead") then "Dead" else nil
				d:SetAttribute("Variant", v)
				table.insert(lines, path .. " -> " .. tostring(v or "default"))
			end
		end
	end
	return table.concat(lines, "\n")
end

return P
