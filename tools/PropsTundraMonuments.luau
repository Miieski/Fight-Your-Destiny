--[[
	PropsTundraMonuments (dev tool, Edit mode only) - the owner's "TUNDRA (SNOW BIOME) PROP IMPROVEMENT - Ice monuments,
	statues and shrines" (2026-10-22): the ice pillar, the ice knight in its glass case, the ice throne, the dome brazier
	("yellow dome pedestal"), the glass frame with the checkmark and the blue lamp post, to the fountain / well quality in
	the tundra look (docs/prop_texture_guide.md sections A, E, E9), keeping each object's colours, place, size, function and
	collision. Source of truth: tools/PropsTundraMonuments.luau. Inventory: docs/prop_inventory.md "Tundra monuments".

	Collision: the visible unions never collide; every part that collides today is an invisible "Collision" copy of it
	(DevTools.PropsTundraMonumentsData = the kits; MeshParts cloned from a source with today's mesh and collision
	fidelity). Functional parts kept exactly: the brazier's Embers (+ FirePoint), the lamp's Head (+ FirePoint, where the
	zones' Fire_Torch_Blue VFX burn) and Ember.

	It uses DevTools.PropsTundraGates (and through it the tundra buildings' snow / ice helpers and Agent A's facets) and
	registers its builders into the same PropsBatch2 table:
		local TM = require(game.ServerStorage.DevTools.PropsTundraMonuments:Clone())
		print(TM.install("tundra_ice_pillar"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "tundra_ice_pillar" } }), Sync.run({ only = { "tundra_ice_pillar" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local TG = require(ServerStorage.DevTools.PropsTundraGates:Clone()) :: any
local TB = TG.TB
local B2, H, M, TS = TB.B2, TB.H, TB.M, TB.TS
local piece, chamfered = H.piece, H.chamfered
local scaled, graded = H.scaled, H.graded
local frustumN = M.frustumN
local facetPiece, facetIcicle, lump, snowTone = TB.facetPiece, TB.facetIcicle, TB.lump, TB.snowTone
local cap, rime, exactRow = TG.cap, TG.rime, TG.exactRow
local GS = TG.GS -- the tundra gates' E8 facets (the crystal spire)
local MD = require(ServerStorage.DevTools.PropsTundraMonumentsData:Clone()) :: any

local TM = {}

local rgb = Color3.fromRGB
local rad = math.rad

local NEON_CYAN = rgb(96, 190, 255) -- #60BEFF today's glow
local ICE_PALE = rgb(214, 236, 255) -- #D6ECFF
local ICE_EDGE = rgb(191, 233, 245) -- #BFE9F5
local RIME = rgb(230, 238, 246)
local GLASS = { material = Enum.Material.Glass, transparency = 0.3, shadow = false }
local NEON = { material = Enum.Material.Neon, shadow = false }

local function rowsNamed(kit: string, name: string?): { any }
	local out = {}
	for _, r in ipairs(MD.rows(kit)) do
		if name == nil or r.name == name then
			table.insert(out, r)
		end
	end
	return out
end
TM.rowsNamed = rowsNamed

-- a MeshPart with this MeshId and collision fidelity to clone (CollisionFidelity cannot be set from a script)
local function meshSourceFid(meshId: string, fidelity: string): MeshPart?
	local roots = { ServerStorage:FindFirstChild("MapAssets"), workspace:FindFirstChild("_Staging"), workspace:FindFirstChild("Zones"), ServerStorage:FindFirstChild("MapProps"), ServerStorage:FindFirstChild("BossArenas") }
	for _, root in ipairs(roots) do
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("MeshPart") and d.MeshId == meshId and d.CollisionFidelity.Name == fidelity then
					return d
				end
			end
		end
	end
	return nil
end

-- the colliding rows of `kit` except `keep` as invisible "Collision" parts
local function collisionRows(m: Model, kit: string, keep: { [string]: boolean }?): number
	local n = 0
	for _, r in ipairs(MD.rows(kit)) do
		if r.collide and not (keep and keep[r.name]) then
			local p: BasePart
			if r.class == "MeshPart" then
				local src = meshSourceFid(r.meshId, r.fidelity)
				assert(src, `PropsTundraMonuments: no MeshPart with {r.meshId} ({r.fidelity}) to clone`)
				p = src:Clone()
				p:ClearAllChildren()
				for key in pairs(p:GetAttributes()) do
					p:SetAttribute(key, nil)
				end
				for _, tag in ipairs(p:GetTags()) do
					p:RemoveTag(tag)
				end
				(p :: MeshPart).TextureID = ""
			else
				p = Instance.new(r.class) :: BasePart
				if r.shape ~= "" and p:IsA("Part") then
					p.Shape = (Enum.PartType :: any)[r.shape]
				end
			end
			p.Name = "Collision"
			p.Size = r.size
			p.CFrame = r.cf
			p.Color = r.color
			p.Anchored = true
			p.CanCollide = true
			p.CanQuery = true
			p.CanTouch = true
			p.CastShadow = false
			p.Transparency = 1
			p.Parent = m
			n += 1
		end
	end
	return n
end
TM.collisionRows = collisionRows

-- a bevelled n-gon prism (apothem r, y0..y1, axis Y, at the frame f): its n faces in `face` colour, n narrow edge faces
-- (the bevel, c wide) in `edge` colour, flat top / bottom; one convex solid
local function bevelPrism(n: number, r: number, c: number, y0: number, y1: number, f: CFrame, face: Color3, edge: Color3, phase: number?): BasePart
	local planes = { { 0, -1, 0, -y0 }, { 0, 1, 0, y1 } }
	local a0 = phase or 0
	for k = 0, n - 1 do
		local a = a0 + k * 2 * math.pi / n
		table.insert(planes, { math.cos(a), 0, math.sin(a), r, face })
		local b = a + math.pi / n
		table.insert(planes, { math.cos(b), 0, math.sin(b), r / math.cos(math.pi / n) - c / (2 * math.tan(math.pi / 2 - math.pi / n)), edge })
	end
	local R = r / math.cos(math.pi / n) + 0.05
	return H.convexSolid(Vector3.new(-R, y0, -R), Vector3.new(R, y1, R), f, face, planes)
end
TM.bevelPrism = bevelPrism

-- a chevron (V) of 2 Neon bars on a face: tip at p, opening along `up` (1 = the V opens upward), arms `len` long
-- spread `spread` rad, in the plane with normal n (out of the face)
local function chevron(list: { BasePart }, p: Vector3, n: Vector3, side: Vector3, up: number, len: number, spread: number, t: number)
	for _, s in ipairs({ -1, 1 }) do
		local dir = (Vector3.yAxis * up * math.cos(spread) + side * s * math.sin(spread)).Unit
		local mid = p + dir * (len / 2)
		table.insert(list, piece("Part", Vector3.new(t, len + t, t), CFrame.fromMatrix(mid, dir:Cross(n).Unit, dir), NEON_CYAN))
	end
end
TM.chevron = chevron

---------------------------------------------------------------------
-- 01 ICE PILLAR (kit MapAssets.Tundra.Ice_Pillar, 8 parts, 8 x 40 x 8; 20 copies: test, kit, Tundra_4 x10 at 1.2,
-- BossArenas Tundra x8 at 1.5)
---------------------------------------------------------------------
-- The ice pillar (guide E9): a bevelled square base in 2 steps of dark blue ice-stone (chamfered, a joint, frost rime on
-- the step edges, Agent A's frost crystals at 2 corners); an octagonal moulded plinth; the shaft as faceted translucent
-- ice (a bevelled 8-sided prism: big facets in today's #96D6FA, narrow light #D6ECFF edges, Glass T 0.3) over an opaque
-- #54A0E8 core (today's 2 crossed shafts); glowing cyan chevrons on its 4 main faces near both ends (where today's 2 Glow
-- squares were) and a thin glowing ring; a carved capital (an octagonal echinus flaring out, an abacus with dentils);
-- today's top block bevelled, a soft snow cap with a few small icicles. Same size. Colliders: today's 6 parts.
-- Parts: Ice, IceCore, Glow, Icicles, Snow, Stone, Collision x6.
function TM.tundra_ice_pillar(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_ice_pillar"
	local rng = Random.new(20261701)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Ice = {}, IceCore = {}, Glow = {}, Snow = {}, Icicles = {} }
	local kit = "Ice_Pillar"
	local Ht = 40
	local base = rowsNamed(kit, "Base")[1]
	local BC = base.color -- #3468B4
	-- the base: 2 bevelled steps, frost rime on the step edges
	table.insert(U.Stone, chamfered(Vector3.new(8, 1.45, 8), CFrame.new(0, 0.725, 0), graded(BC, 0.7, Ht, 0.95), { "topFrontBack", "topSides", "vertical" }, 0.3))
	table.insert(U.Stone, chamfered(Vector3.new(7.3, 1.5, 7.3), CFrame.new(0, 2.25, 0), graded(BC, 2.2, Ht, 1.04), { "topFrontBack", "topSides", "vertical" }, 0.3))
	for _, e in ipairs({ { Vector3.new(-3.4, 1.49, -3.95), Vector3.new(3.4, 1.49, -3.95) }, { Vector3.new(-3.1, 3.04, -3.6), Vector3.new(3.1, 3.04, -3.6) } }) do
		rime(U.Snow, rng, e[1], e[2], 0.25)
	end
	-- the plinth: an octagonal moulding (today's Plinth 6.4 x 2)
	local pl = rowsNamed(kit, "Plinth")[1]
	table.insert(U.Stone, frustumN(8, 3.2, 3.0, 3.0, 3.6, CFrame.Angles(0, rad(22.5), 0), { pl.color, scaled(pl.color, 1.1) }))
	table.insert(U.Stone, frustumN(8, 3.0, 2.55, 3.6, 4.6, CFrame.Angles(0, rad(22.5), 0), { scaled(pl.color, 1.05), pl.color }))
	table.insert(U.Stone, frustumN(8, 2.6, 2.6, 4.6, 5.05, CFrame.Angles(0, rad(22.5), 0), { scaled(pl.color, 0.92), pl.color }))
	-- the shaft: faceted translucent ice over a deeper core
	local y0, y1 = 5.0, 35.0
	table.insert(U.Ice, bevelPrism(8, 2.3, 0.28, y0, y1, CFrame.identity, rgb(150, 214, 250), ICE_PALE, rad(22.5)))
	table.insert(U.IceCore, frustumN(8, 1.55, 1.55, y0 + 0.2, y1 - 0.2, CFrame.Angles(0, rad(22.5), 0), { rgb(84, 160, 232), rgb(70, 140, 214) }))
	-- the chevrons on the 4 main faces (front / back / sides), pointing down near the foot and up near the top, a ring
	for k = 0, 3 do
		local a = k * math.pi / 2
		local n = Vector3.new(math.sin(a), 0, -math.cos(a))
		local side = Vector3.new(math.cos(a), 0, math.sin(a))
		local ap = 2.3 * math.cos(math.pi / 8) / math.cos(math.pi / 8)
		for _, ch in ipairs({ { 6.6, 1 }, { 7.6, 1 }, { 33.4, -1 }, { 32.4, -1 } }) do
			chevron(U.Glow, n * (ap + 0.05) + Vector3.new(0, ch[1], 0), n, side, ch[2], 1.25, rad(55), 0.2)
		end
	end
	for _, y in ipairs({ 5.35, 34.65 }) do
		table.insert(U.Glow, frustumN(8, 2.42, 2.42, y - 0.12, y + 0.12, CFrame.Angles(0, rad(22.5), 0), { NEON_CYAN }))
	end
	-- the capital: an octagonal echinus flaring out, an abacus with dentils (today's Capital 6.4 x 2)
	local cp = rowsNamed(kit, "Capital")[1]
	table.insert(U.Stone, frustumN(8, 2.45, 3.25, 35.0, 36.0, CFrame.Angles(0, rad(22.5), 0), { cp.color, scaled(cp.color, 1.12), scaled(cp.color, 0.92) }))
	table.insert(U.Stone, chamfered(Vector3.new(6.4, 1.0, 6.4), CFrame.new(0, 36.5, 0), scaled(cp.color, 1.05), { "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.2))
	for k = 0, 3 do
		local a = k * math.pi / 2
		local n = Vector3.new(math.sin(a), 0, -math.cos(a))
		local side = Vector3.new(math.cos(a), 0, math.sin(a))
		for i = -2, 2 do
			table.insert(U.Stone, piece("Part", Vector3.new(0.6, 0.45, 0.3), CFrame.fromMatrix(n * 3.25 + side * (i * 1.15) + Vector3.new(0, 35.75, 0), side, Vector3.yAxis), scaled(cp.color, 0.85)))
		end
	end
	-- today's top block bevelled, a soft snow cap, small icicles under its edges
	local tp = rowsNamed(kit, "Top")[1]
	table.insert(U.Stone, chamfered(tp.size, tp.cf, graded(tp.color, 38.5, Ht, 1.05), { "topFrontBack", "topSides", "bottomFrontBack", "bottomSides", "vertical" }, 0.35))
	cap(U, Vector3.new(0, 39.88, 0), Vector3.new(7.3, 0.75, 7.3), rng:NextNumber(-0.05, 0.05), true)
	for k = 0, 3 do
		local a = k * math.pi / 2
		local n = Vector3.new(math.sin(a), 0, -math.cos(a))
		local side = Vector3.new(math.cos(a), 0, math.sin(a))
		for _, i in ipairs({ -2.4, 0.6, 2.7 }) do
			facetIcicle(U, "Icicles", n * 3.75 + side * (i + rng:NextNumber(-0.3, 0.3)) + Vector3.new(0, 37.08, 0), rng:NextNumber(0.15, 0.32), 0.45, rng:NextNumber(0, 6.28))
		end
	end
	-- frost crystals on 2 corners of the upper base step (Agent A's shards, small; inside today's 8 x 8 footprint)
	for _, c in ipairs({ { -2.95, -2.95, 0.32, 30 }, { 2.95, 2.95, 0.28, 200 }, { 2.95, -2.95, 0.22, 110 } }) do
		facetPiece(U, TS.tundra_ice__shards, CFrame.new(c[1], 3.0, c[2]) * CFrame.Angles(0, rad(c[4]), 0), Vector3.one * c[3], "Ice", "Ice")
	end

	TB.finishTB(m, "tundra_ice_pillar", U, "Stone", { Ice = GLASS, Glow = NEON, Icicles = TB.ICICLE_OPTS })
	collisionRows(m, kit)
	return m
end

---------------------------------------------------------------------
-- 02 ICE KNIGHT IN A GLASS CASE (kit MapAssets.Tundra.Frozen_Knight_Statue, 19 parts, 11 x 14.7 x 8.5; 12 copies: test,
-- kit, Tundra_4 x4 at 1.15, Tundra_4 BossGate x2 at 1.25, BossArenas x4 at 1.0 / 1.2)
---------------------------------------------------------------------
-- a plate (a chamfered box) between a and b (its long axis), w wide, t thick, facing n
local function plate(list: { BasePart }, a: Vector3, b: Vector3, w: number, t: number, n: Vector3, color: Color3, c: number?): BasePart
	local y = (b - a).Unit
	local x = y:Cross(n).Unit
	local p = chamfered(Vector3.new(w, (b - a).Magnitude, t), CFrame.fromMatrix((a + b) / 2, x, y), color, { "vertical" }, c or math.min(w, t) * 0.25)
	table.insert(list, p)
	return p
end
TM.plate = plate

-- The ice knight in its glass case (guide E9): a carved plinth (today's 8 x 2 x 8: a chamfered base, sunk panels with a
-- frame on all 4 sides, a top moulding); the knight in plate armour in today's steel tones: sabatons, tapered greaves
-- with knee cops, cuisses, a breastplate with a centre ridge and a plackart, today's gold belt with a green sash tied at
-- the hip (2 tails), tassets, layered pauldrons (3 lames), arms with couters and gauntlets at today's angle, a great helm
-- with a domed top, today's glowing cyan visor slit, breath holes and a 3-piece lavender plume curving back; the sword
-- planted in front at today's place (a pale blade with a fuller, today's gold guard, a leather grip, a gold pommel);
-- the case: 4 translucent glass panes (Glass T 0.3) in light ice frames (corner posts, rails), a white lid with a raised
-- rim and a soft snow cap; Agent A's ice shards at today's 2 shard places. Colliders: today's Plinth and glass case.
-- Parts: Armor, Gold, Glow, Glass, IceFrame, Ice, Plinth, Snow, Wood, Collision x2.
function TM.tundra_ice_knight(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_ice_knight"
	local rng = Random.new(20261702)
	H.setBevelSelf(true)
	local U: any = { Plinth = {}, Armor = {}, Gold = {}, Glow = {}, Glass = {}, IceFrame = {}, Ice = {}, Snow = {}, Wood = {} }
	local kit = "Frozen_Knight_Statue"
	local Ht = 14.7
	local function row(name: string, i: number?): any
		return rowsNamed(kit, name)[i or 1]
	end
	local STEEL, STEEL2 = row("Leg").color, row("Torso").color -- #5C626E / #686E7C
	local GOLD = row("Belt").color
	local SASH = rgb(70, 140, 70)
	local LIGHT = scaled(STEEL2, 1.25)
	-- the plinth: base slab, a sunk panel with a frame on each side, a top moulding
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
	-- legs: sabatons, greaves with knee cops, cuisses
	for _, r in ipairs(rowsNamed(kit, "Leg")) do
		local x = r.cf.Position.X
		table.insert(U.Armor, chamfered(Vector3.new(1.5, 0.55, 2.2), CFrame.new(x, 2.28, -0.25), scaled(STEEL, 0.9), { "topFrontBack", "topSides" }, 0.2))
		table.insert(U.Armor, frustumN(8, 0.62, 0.75, 2.5, 4.2, CFrame.new(x, 0, 0) * CFrame.Angles(0, rad(22.5), 0), { STEEL, scaled(STEEL, 1.12), scaled(STEEL, 0.9) }))
		table.insert(U.Armor, frustumN(8, 0.42, 0.3, -0.15, 0.25, H.frameY(Vector3.new(x, 4.35, -0.72), -Vector3.zAxis), { LIGHT, STEEL }))
		table.insert(U.Armor, frustumN(8, 0.76, 0.82, 4.25, 6.05, CFrame.new(x, 0, 0) * CFrame.Angles(0, rad(22.5), 0), { STEEL2, scaled(STEEL2, 1.1), scaled(STEEL2, 0.9) }))
	end
	-- torso: breastplate with a ridge, a plackart, today's gold belt, the green sash with a knot and 2 tails, tassets
	local tr = row("Torso")
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
	-- pauldrons (3 lames each), arms with couters and gauntlets at today's angle
	for _, r in ipairs(rowsNamed(kit, "Shoulder")) do
		local p = r.cf.Position
		local sx = math.sign(p.X)
		for k = 0, 2 do
			table.insert(U.Armor, frustumN(8, 1.25 - k * 0.18, 0.95 - k * 0.15, 0, 0.42, H.frameY(Vector3.new(p.X + sx * (0.05 - k * 0.12), p.Y + 0.15 + k * 0.32, p.Z), Vector3.new(sx * 0.55, 1, 0).Unit), { if k == 2 then LIGHT else STEEL, scaled(STEEL, 1.1) }))
		end
	end
	for _, r in ipairs(rowsNamed(kit, "Arm")) do
		local cf, sz = r.cf, r.size
		table.insert(U.Armor, frustumN(8, 0.55, 0.62, -sz.Y / 2 + 0.6, sz.Y / 2, cf * CFrame.Angles(0, rad(22.5), 0), { STEEL2, scaled(STEEL2, 1.1), scaled(STEEL2, 0.9) }))
		table.insert(U.Armor, frustumN(8, 0.36, 0.25, -0.2, 0.25, H.frameY((cf * CFrame.new(0, 0.1, 0.62)).Position, cf.LookVector * -1), { LIGHT, STEEL }))
		table.insert(U.Armor, chamfered(Vector3.new(1.05, 0.9, 1.25), cf * CFrame.new(0, -sz.Y / 2 + 0.25, 0), scaled(STEEL, 0.85), { "vertical", "bottomFrontBack" }, 0.2))
	end
	-- the great helm, a domed top, today's visor (Neon), breath holes, the plume curving back
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
	-- the sword, planted in front (today's place): blade with a fuller, gold guard, leather grip, gold pommel
	local bl, gd, gp = row("Blade"), row("Guard"), row("Grip")
	table.insert(U.Armor, chamfered(Vector3.new(bl.size.X, bl.size.Y - 0.4, 0.2), bl.cf * CFrame.new(0, 0.2, 0), rgb(232, 238, 248), { "vertical" }, 0.08))
	table.insert(U.Armor, frustumN(4, 0.02, 0.25, bl.cf.Position.Y - bl.size.Y / 2 - 0.1, bl.cf.Position.Y - bl.size.Y / 2 + 0.4, CFrame.new(bl.cf.Position.X, 0, bl.cf.Position.Z) * CFrame.Angles(0, rad(45), 0), { rgb(232, 238, 248) }))
	table.insert(U.Armor, piece("Part", Vector3.new(0.12, bl.size.Y - 1.2, 0.24), bl.cf * CFrame.new(0, 0.2, 0), rgb(176, 188, 206)))
	table.insert(U.Gold, chamfered(gd.size, gd.cf, gd.color, { "topFrontBack", "bottomFrontBack" }, 0.1))
	table.insert(U.Wood, frustumN(8, 0.2, 0.18, -gp.size.Y / 2, gp.size.Y / 2, gp.cf, { gp.color, scaled(gp.color, 0.85) }))
	table.insert(U.Gold, frustumN(8, 0.28, 0.22, gp.cf.Position.Y + gp.size.Y / 2 - 0.02, gp.cf.Position.Y + gp.size.Y / 2 + 0.36, CFrame.new(gp.cf.Position.X, 0, gp.cf.Position.Z), { GOLD, scaled(GOLD, 0.88) }))
	-- the case: 4 glass panes in light ice frames, a white lid with a rim and a soft snow cap
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
	-- ice crystals at today's 2 shard places (Agent A's crystal spire, small)
	for _, r in ipairs(rowsNamed(kit, "Shard")) do
		local p, sz = r.cf.Position, r.size
		local top = p.Y + sz.Y / 2
		facetPiece(U, GS.tundra_gate4__spire, CFrame.new(p.X, -0.2, p.Z) * CFrame.Angles(0, if p.X < 0 then math.pi else 0, 0), Vector3.one * (top / 17.7), "Ice", "Ice")
	end

	TB.finishTB(m, "tundra_ice_knight", U, "Plinth", { Glass = { material = Enum.Material.Glass, transparency = 0.5, shadow = false }, Ice = GLASS, Glow = NEON })
	collisionRows(m, kit)
	return m
end

---------------------------------------------------------------------
-- 03 ICE THRONE (kit MapAssets.Tundra.Ice_Throne_Small, 12 parts, 12.9 x 18.4 x 8.5; 4 copies: test, kit, Tundra_4 (decor
-- by the boss gate), BossArenas at 1.1; no Seat instance, no NPC spot)
---------------------------------------------------------------------
-- The ice throne (guide E9): today's 2 steps bevelled (dark blue / blue ice-stone, frost rime on their edges, small frost
-- crystals at the front corners); the seat in ice with a pale blue cushion whose top stays today's seat top (y 3.6); bevelled
-- armrests with carved scroll ends; the tall back as a bevelled ice slab with a raised light frame, stepped shoulders and
-- a carved crest, today's glowing cyan gem in a faceted diamond inlay with a light ring; Agent A's crystal spires in
-- place of today's 3 back spikes and the 2 side crystals (their colliders kept). Colliders: today's steps, seat, back,
-- armrests and the 2 Crystal meshes (Hull). Parts: Glow, Ice, Snow, Stone, Cushion, Collision x8.
function TM.tundra_ice_throne(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_ice_throne"
	local rng = Random.new(20261703)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Ice = {}, Glow = {}, Snow = {}, Cushion = {} }
	local kit = "Ice_Throne_Small"
	local Ht = 18.4
	-- the steps
	for i, r in ipairs(rowsNamed(kit, "Step")) do
		table.insert(U.Stone, chamfered(r.size - Vector3.new(0.06, 0.04, 0.06), r.cf, graded(r.color, r.cf.Position.Y, Ht, 1.04), { "topFrontBack", "topSides", "vertical" }, 0.22))
		local p, sz = r.cf.Position, r.size
		rime(U.Snow, rng, Vector3.new(p.X - sz.X / 2 + 0.4, p.Y + sz.Y / 2 + 0.03, p.Z - sz.Z / 2 + 0.08), Vector3.new(p.X + sz.X / 2 - 0.4, p.Y + sz.Y / 2 + 0.03, p.Z - sz.Z / 2 + 0.08), 0.2)
	end
	for _, sx in ipairs({ -1, 1 }) do
		facetPiece(U, TS.tundra_ice__shards, CFrame.new(sx * 3.9, 1.0, -3.4) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Vector3.one * 0.3, "Ice", "Ice")
	end
	-- the seat (ice) and the pale blue cushion (its top = today's seat top 3.6)
	local st = rowsNamed(kit, "Seat")[1]
	local sp, ss = st.cf.Position, st.size
	local top = sp.Y + ss.Y / 2
	table.insert(U.Stone, chamfered(Vector3.new(ss.X, ss.Y - 0.45, ss.Z), CFrame.new(sp.X, sp.Y - 0.225, sp.Z), st.color, { "vertical", "topFrontBack", "topSides" }, 0.18))
	table.insert(U.Cushion, chamfered(Vector3.new(ss.X - 0.5, 0.45, ss.Z - 0.6), CFrame.new(sp.X, top - 0.225, sp.Z - 0.05), rgb(196, 226, 250), { "topFrontBack", "topSides", "vertical" }, 0.16))
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Cushion, piece("Part", Vector3.new(0.22, 0.12, 0.22), CFrame.new(sp.X + sx * 1.6, top - 0.02, sp.Z + sz * 1.3) * CFrame.Angles(0, rad(45), 0), rgb(160, 205, 240)))
		end
	end
	-- the armrests: bevelled, carved scroll ends at the front
	for _, r in ipairs(rowsNamed(kit, "ArmRest")) do
		local p, sz = r.cf.Position, r.size
		table.insert(U.Ice, chamfered(sz - Vector3.new(0.04, 0.3, 0.04), r.cf * CFrame.new(0, -0.15, 0), r.color, { "vertical", "topFrontBack", "topSides" }, 0.2))
		table.insert(U.Ice, frustumN(8, 0.68, 0.68, -0.6, 0.6, H.frameY(Vector3.new(p.X, p.Y + sz.Y / 2 - 0.15, p.Z - sz.Z / 2 + 0.55), Vector3.xAxis), { scaled(r.color, 1.08), r.color }))
		table.insert(U.Ice, chamfered(Vector3.new(sz.X + 0.1, 0.3, sz.Z - 1.0), CFrame.new(p.X, p.Y + sz.Y / 2 - 0.15, p.Z + 0.45), scaled(r.color, 1.1), { "topFrontBack", "topSides" }, 0.1))
	end
	-- the back: a bevelled slab, a raised light frame, stepped shoulders and a crest, the gem in a diamond inlay
	local bk = rowsNamed(kit, "Back")[1]
	local bp, bs = bk.cf.Position, bk.size
	local btop = bp.Y + bs.Y / 2
	table.insert(U.Stone, chamfered(Vector3.new(bs.X, bs.Y - 1.6, bs.Z), CFrame.new(bp.X, bp.Y - 0.8, bp.Z), bk.color, { "vertical", "topFrontBack" }, 0.25))
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Stone, chamfered(Vector3.new(1.3, 1.6, bs.Z), CFrame.new(sx * (bs.X / 2 - 0.65), btop - 0.8, bp.Z), scaled(bk.color, 1.05), { "vertical", "topFrontBack", "topSides" }, 0.22))
	end
	table.insert(U.Stone, chamfered(Vector3.new(2.6, 1.6, bs.Z), CFrame.new(0, btop - 0.8, bp.Z), scaled(bk.color, 1.05), { "vertical", "topFrontBack", "topSides" }, 0.22))
	local FR = rgb(170, 220, 245)
	local zf = bp.Z - bs.Z / 2 - 0.08
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Ice, chamfered(Vector3.new(0.35, bs.Y - 2.6, 0.2), CFrame.new(sx * (bs.X / 2 - 0.45), bp.Y - 0.9, zf), FR, { "frontFace" }, 0.08))
	end
	for _, y in ipairs({ sp.Y + 1.25, btop - 1.95 }) do
		table.insert(U.Ice, chamfered(Vector3.new(bs.X - 0.6, 0.35, 0.2), CFrame.new(0, y, zf), FR, { "frontFace" }, 0.08))
	end
	local gm = rowsNamed(kit, "Gem")[1]
	local gp = gm.cf.Position
	exactRow(m, gm)
	table.insert(U.Ice, chamfered(Vector3.new(1.7, 1.7, 0.18), CFrame.new(gp.X, gp.Y, zf) * CFrame.Angles(0, 0, rad(45)), FR, { "frontFace" }, 0.1))
	-- a thin glowing diamond outline round the inlay
	for k = 0, 3 do
		local ang = rad(45) + k * math.pi / 2
		local c = Vector3.new(gp.X + math.cos(ang) * 0.85, gp.Y + math.sin(ang) * 0.85, zf - 0.12)
		table.insert(U.Glow, piece("Part", Vector3.new(1.75, 0.09, 0.06), CFrame.new(c) * CFrame.Angles(0, 0, ang + math.pi / 2), NEON_CYAN))
	end
	-- Agent A's crystal spires: today's 3 back spikes (query only today) and 2 side crystals (colliding today)
	for _, r in ipairs(rowsNamed(kit, "Spike")) do
		local p, sz = r.cf.Position, r.size
		local foot = p.Y - sz.Y / 2
		facetPiece(U, GS.tundra_gate4__spire, CFrame.new(p.X, foot - 0.4, p.Z) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5) + (if p.X < 0 then math.pi else 0), 0), Vector3.one * ((sz.Y + 0.4) / 17.7), "Ice", "Ice")
	end
	for _, r in ipairs(rowsNamed(kit, "Crystal")) do
		local p, sz = r.cf.Position, r.size
		facetPiece(U, GS.tundra_gate4__spire, CFrame.new(p.X, -0.3, p.Z) * CFrame.Angles(0, if p.X < 0 then 0 else math.pi, rad(-6 * math.sign(p.X))), Vector3.new(0.26, (p.Y + sz.Y / 2) / 17.7, 0.26), "Ice", "Ice")
	end

	TB.finishTB(m, "tundra_ice_throne", U, "Stone", { Ice = GLASS, Glow = NEON })
	collisionRows(m, kit)
	return m
end

---------------------------------------------------------------------
-- 04 DOME BRAZIER, the owner's "yellow dome pedestal" (kit MapAssets.Tundra.Warm_Brazier, 10 parts, 8.6 x 8.8 x 8.6; 6
-- copies: test, kit, BossArenas.Tundra.WarmSpots x4 renamed WarmBrazier at 1.3, each with an 11th part "Fire" (an
-- attachment with 3 emitters and a PointLight) kept as a MapPropKeep child)
---------------------------------------------------------------------
-- The dome brazier (guide E9, the owner's description): a bevelled slate pedestal (today's base and step, chamfered, with
-- a joint line and rime), an octagonal stem with 2 dark steel bands; today's bowl as an octagonal steel bowl with a lighter
-- lip; today's gold rim as a 16-sided gold ring with a soft snow ring on its outer ledge; over it, in place of today's
-- glowing ember ball, a ribbed golden dome (3 stepped 12-sided courses, 6 darker ribs, a knob and finial) with 6 small
-- framed windows glowing warm (Neon #FFB648); today's Neon Embers disc and its FirePoint kept exactly (the copies' own Fire
-- part keeps burning on it). Colliders: today's base, step, stem, bowl and rim. Parts: Gold, Glow, Snow, Steel, Stone,
-- Embers (+ FirePoint), Collision x5.
function TM.tundra_dome_brazier(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_dome_brazier"
	local rng = Random.new(20261704)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Steel = {}, Gold = {}, Glow = {}, Snow = {} }
	local kit = "Warm_Brazier"
	local Ht = 8.8
	local function row(name: string): any
		return rowsNamed(kit, name)[1]
	end
	local GOLD = row("Rim").color
	local STEEL = row("Bowl").color
	-- the pedestal
	local bs, st = row("Base"), row("Step")
	table.insert(U.Stone, chamfered(bs.size, bs.cf, graded(bs.color, 0.6, Ht, 1.02), { "topFrontBack", "topSides", "vertical" }, 0.25))
	table.insert(U.Stone, chamfered(st.size - Vector3.new(0.04, 0, 0.04), st.cf, graded(st.color, 1.7, Ht, 1.05), { "topFrontBack", "topSides", "vertical" }, 0.22))
	rime(U.Snow, rng, Vector3.new(-3.0, 1.23, -3.44), Vector3.new(3.0, 1.23, -3.44), 0.22)
	rime(U.Snow, rng, Vector3.new(-2.1, 2.23, -2.44), Vector3.new(2.1, 2.23, -2.44), 0.2)
	local sm = row("Stem")
	local smp = sm.cf.Position
	table.insert(U.Steel, frustumN(8, 1.15, 1.0, smp.Y - sm.size.X / 2, smp.Y + sm.size.X / 2, CFrame.Angles(0, rad(22.5), 0), { STEEL, scaled(STEEL, 1.12), scaled(STEEL, 0.9) }))
	for _, y in ipairs({ smp.Y - 0.55, smp.Y + 0.55 }) do
		table.insert(U.Steel, frustumN(8, 1.2, 1.2, y - 0.12, y + 0.12, CFrame.Angles(0, rad(22.5), 0), { rgb(58, 72, 98) }))
	end
	-- the bowl and its lip; the gold rim with snow on its ledge
	local bw = row("Bowl")
	local bwp = bw.cf.Position
	table.insert(U.Steel, frustumN(8, 2.6, 4.0, bwp.Y - bw.size.X / 2, bwp.Y + bw.size.X / 2 - 0.15, CFrame.Angles(0, rad(22.5), 0), { STEEL, scaled(STEEL, 1.1), scaled(STEEL, 0.9) }))
	table.insert(U.Steel, frustumN(8, 4.0, 4.05, bwp.Y + bw.size.X / 2 - 0.15, bwp.Y + bw.size.X / 2, CFrame.Angles(0, rad(22.5), 0), { scaled(STEEL, 1.25) }))
	local rm = row("Rim")
	local rmp = rm.cf.Position
	table.insert(U.Gold, frustumN(16, 4.28, 4.28, rmp.Y - rm.size.X / 2, rmp.Y + rm.size.X / 2, CFrame.identity, { GOLD, scaled(GOLD, 0.92), scaled(GOLD, 1.05) }))
	local rimTop = rmp.Y + rm.size.X / 2
	for k = 0, 11 do
		local a = k * math.pi / 6 + rng:NextNumber(-0.1, 0.1)
		local p = Vector3.new(math.cos(a) * 3.85, rimTop + 0.02, math.sin(a) * 3.85)
		lump(U.Snow, rng, CFrame.new(p) * CFrame.Angles(0, -a, 0), 0.75, 0.22, 0.32, snowTone, 0.05)
	end
	-- the ribbed golden dome over the embers (3 stepped courses, 6 ribs, a knob and a finial)
	local d0 = rimTop
	local courses = { { 3.55, 3.2, 0.0, 0.9 }, { 3.2, 2.35, 0.9, 1.8 }, { 2.35, 1.0, 1.8, 2.45 } }
	for i, c in ipairs(courses) do
		table.insert(U.Gold, frustumN(12, c[1], c[2], d0 + c[3], d0 + c[4], CFrame.identity, { graded(GOLD, d0 + c[4], Ht, 1.05 - i * 0.04), scaled(GOLD, 0.96), scaled(GOLD, 1.03) }))
	end
	for k = 0, 5 do
		local a = k * math.pi / 3
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local pts = { dir * 3.62 + Vector3.new(0, d0, 0), dir * 3.27 + Vector3.new(0, d0 + 0.9, 0), dir * 2.4 + Vector3.new(0, d0 + 1.8, 0), dir * 1.05 + Vector3.new(0, d0 + 2.45, 0) }
		for j = 1, 3 do
			local a0, a1 = pts[j], pts[j + 1]
			local out = dir
			table.insert(U.Gold, piece("Part", Vector3.new(0.22, (a1 - a0).Magnitude + 0.12, 0.18), CFrame.fromMatrix((a0 + a1) / 2 + out * 0.04, (a1 - a0).Unit:Cross(out).Unit, (a1 - a0).Unit), scaled(GOLD, 0.8)))
		end
		-- a framed window between 2 ribs on the lowest course, glowing warm
		local wa = a + math.pi / 6
		local wd = Vector3.new(math.cos(wa), 0, math.sin(wa))
		local slope = Vector3.new(0, 0.9, 0) - wd * 0.35
		local wc = wd * 3.42 + Vector3.new(0, d0 + 0.47, 0)
		local f = CFrame.fromMatrix(wc, slope.Unit:Cross(wd).Unit, slope.Unit)
		table.insert(U.Glow, piece("Part", Vector3.new(0.6, 0.52, 0.14), f, rgb(255, 182, 72)))
		for _, e in ipairs({ { 0, 0.33, 0.84, 0.13 }, { 0, -0.33, 0.84, 0.13 }, { 0.37, 0, 0.13, 0.52 }, { -0.37, 0, 0.13, 0.52 } }) do
			table.insert(U.Gold, piece("Part", Vector3.new(e[3], e[4], 0.2), f * CFrame.new(e[1], e[2], 0.02), scaled(GOLD, 0.82)))
		end
	end
	table.insert(U.Gold, frustumN(8, 1.0, 0.55, d0 + 2.45, d0 + 2.8, CFrame.identity, { GOLD, scaled(GOLD, 0.9) }))
	table.insert(U.Gold, frustumN(6, 0.22, 0.02, d0 + 2.8, d0 + 3.25, CFrame.identity, { scaled(GOLD, 1.05), GOLD }))
	-- today's Embers (Neon) with its FirePoint, exactly
	local em = row("Embers")
	local e = exactRow(m, em)
	local fp = Instance.new("Attachment")
	fp.Name = "FirePoint"
	fp.CFrame = CFrame.new(0.5, 0, 0)
	fp.Parent = e

	TB.finishTB(m, "tundra_dome_brazier", U, "Stone", { Glow = NEON })
	collisionRows(m, kit, { Embers = true })
	return m
end

---------------------------------------------------------------------
-- 05 GLASS FRAME WITH THE CHECKMARK (kit MapAssets.Tundra.Ice_Wall_Panel, 7 parts, 20 x 24 x 3; 10 copies: test, kit,
-- Tundra_4 Decor.Exterior x4 (zone wall panels), Tundra_4 Decor.Props x4 at 1.2; decor, no script)
---------------------------------------------------------------------
-- The glass frame (guide E9): today's posts as thick bevelled ice pilasters (a raised inner bead, a base and a capital),
-- today's bottom rail as a base block with a plinth, today's top rail as a bevelled lintel with dentils, a soft snow cap
-- and small icicles; 4 corner bosses with diamond studs; the pane as translucent ice glass (Glass T 0.4) with 3 subtle
-- reflection streaks; today's 2 checkmark bars as a carved checkmark with depth (a raised light ice bar with a glowing
-- cyan core line). Colliders: today's 2 posts, 2 rails and the pane. Parts: Frame, Glass, Glow, Ice, Icicles, Snow,
-- Collision x5.
function TM.tundra_glass_frame(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_glass_frame"
	local rng = Random.new(20261705)
	H.setBevelSelf(true)
	local U: any = { Frame = {}, Glass = {}, Glow = {}, Ice = {}, Icicles = {}, Snow = {} }
	local kit = "Ice_Wall_Panel"
	local Ht = 24
	local LIGHT = rgb(150, 210, 245)
	-- the posts
	for _, r in ipairs(rowsNamed(kit, "Post")) do
		local p, sz = r.cf.Position, r.size
		local sx = math.sign(p.X)
		table.insert(U.Frame, chamfered(Vector3.new(sz.X, sz.Y - 2.6, sz.Z - 0.1), CFrame.new(p.X, p.Y + 0.2, p.Z), graded(r.color, 12, Ht, 1.04), { "vertical" }, 0.35))
		table.insert(U.Frame, chamfered(Vector3.new(sz.X + 0.3, 1.0, sz.Z + 0.2), CFrame.new(p.X, 0.5, p.Z), scaled(r.color, 0.86), { "topFrontBack", "topSides", "vertical" }, 0.25))
		table.insert(U.Frame, chamfered(Vector3.new(sz.X + 0.3, 1.2, sz.Z + 0.2), CFrame.new(p.X, sz.Y - 0.6, p.Z), scaled(r.color, 0.9), { "bottomFrontBack", "bottomSides", "vertical", "topFrontBack", "topSides" }, 0.22))
		-- a raised bead on the inner edge, front and back
		for _, zf in ipairs({ -1, 1 }) do
			table.insert(U.Ice, chamfered(Vector3.new(0.3, sz.Y - 4.6, 0.3), CFrame.new(p.X - sx * (sz.X / 2 - 0.35), 12, p.Z + zf * (sz.Z / 2 - 0.05)), LIGHT, { "vertical" }, 0.08))
		end
	end
	-- the bottom rail as a base block, the top rail as a lintel with dentils, a snow cap, icicles
	local rails = rowsNamed(kit, "Rail")
	table.sort(rails, function(a, c) return a.cf.Position.Y < c.cf.Position.Y end)
	local br, tr = rails[1], rails[2]
	table.insert(U.Frame, chamfered(br.size + Vector3.new(0, 0, 0.2), br.cf, br.color, { "topFrontBack", "vertical" }, 0.3))
	table.insert(U.Frame, chamfered(Vector3.new(br.size.X + 0.6, 0.45, br.size.Z + 0.15), CFrame.new(0, 0.225, 0), scaled(br.color, 0.85), { "topFrontBack", "topSides" }, 0.15))
	local tp, ts = tr.cf.Position, tr.size
	table.insert(U.Frame, chamfered(Vector3.new(ts.X + 4.8, ts.Y, ts.Z + 0.2), tr.cf, tr.color, { "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }, 0.3))
	for k = 0, 8 do
		for _, zf in ipairs({ -1, 1 }) do
			table.insert(U.Frame, piece("Part", Vector3.new(0.7, 0.4, 0.25), CFrame.new(-7.0 + k * 1.75, tp.Y - ts.Y / 2 + 0.25, zf * (ts.Z / 2 + 0.02)), scaled(tr.color, 0.85)))
		end
	end
	TG.cap(U, Vector3.new(0, tp.Y + ts.Y / 2 - 0.08, 0), Vector3.new(ts.X + 2.6, 0.6, ts.Z - 0.5), rng:NextNumber(-0.02, 0.02), true)
	for _, x in ipairs({ -8.6, -4.9, -1.2, 2.3, 5.8, 8.7 }) do
		facetIcicle(U, "Icicles", Vector3.new(x + rng:NextNumber(-0.4, 0.4), tp.Y - ts.Y / 2 + 0.06, -ts.Z / 2 + 0.3), rng:NextNumber(0.15, 0.35), 0.45, rng:NextNumber(0, 6.28))
	end
	-- 4 corner bosses with diamond studs (where the pane meets the frame)
	for _, sx in ipairs({ -1, 1 }) do
		for _, y in ipairs({ 2.6, 21.0 }) do
			for _, zf in ipairs({ -1, 1 }) do
				local c = Vector3.new(sx * 7.05, y, zf * 0.75)
				table.insert(U.Frame, chamfered(Vector3.new(1.1, 1.1, 0.3), CFrame.new(c), scaled(LIGHT, 0.92), { "frontFace" }, 0.12))
				table.insert(U.Ice, piece("Part", Vector3.new(0.45, 0.45, 0.22), CFrame.new(c + Vector3.new(0, 0, zf * 0.2)) * CFrame.Angles(0, 0, rad(45)), rgb(220, 242, 255)))
			end
		end
	end
	-- the pane (translucent ice glass) and 3 subtle reflection streaks
	local pn = rowsNamed(kit, "Pane")[1]
	table.insert(U.Glass, piece("Part", Vector3.new(pn.size.X, pn.size.Y, 0.4), pn.cf, pn.color))
	for _, st in ipairs({ { -4.5, 15.5, 0.35, 7 }, { -3.4, 14.8, 0.18, 5.5 }, { 4.6, 6.5, 0.22, 4.2 } }) do
		table.insert(U.Ice, piece("Part", Vector3.new(st[3], st[4], 0.05), CFrame.new(st[1], st[2], -0.24) * CFrame.Angles(0, 0, rad(-35)), rgb(235, 247, 255)))
	end
	-- the carved checkmark: today's 2 bars as raised light ice with a glowing core line
	for _, r in ipairs(rowsNamed(kit, "Facet")) do
		for _, zf in ipairs({ -1, 1 }) do
			table.insert(U.Ice, chamfered(Vector3.new(0.75, r.size.Y, 0.25), r.cf * CFrame.new(0, 0, zf * 0.3), rgb(196, 230, 250), { "frontFace" }, 0.1))
			table.insert(U.Glow, piece("Part", Vector3.new(0.16, r.size.Y - 0.4, 0.08), r.cf * CFrame.new(0, 0, zf * 0.45), NEON_CYAN))
		end
	end

	TB.finishTB(m, "tundra_glass_frame", U, "Frame", { Glass = { material = Enum.Material.Glass, transparency = 0.4, shadow = false }, Ice = { transparency = 0.15 }, Glow = NEON, Icicles = TB.ICICLE_OPTS })
	collisionRows(m, kit)
	return m
end

---------------------------------------------------------------------
-- 06 BLUE LAMP POST (kit MapAssets.Tundra.Blue_Torch_Standing, 4 parts + FirePoint, 1.8 x 6.5 x 1.8; 10 copies: test, kit,
-- Tundra_4 BossGate x2 at 1.7, BossArenas x6 at 1.5 .. 2.0; its light and flame are the zones' Fire_Torch_Blue VFX parts
-- standing on the FirePoint, untouched)
---------------------------------------------------------------------
-- The blue lamp post (guide E9): a bevelled 2-tier octagonal slate base (today's Foot) with a soft snow ring; a slim
-- octagonal post (today's Pole) with 2 dark steel bands and 2 small scroll brackets under the lantern; the glass lantern:
-- today's Head kept exactly as the lantern's (invisible) foot with its FirePoint, today's Neon Ember exactly inside, a
-- steel base plate, 4 corner posts, 4 cyan-tinted glass panes, a low pyramid roof with a ring and a small snow cap, tiny
-- icicles under the plate. Colliders: today's Foot and Pole (invisible) and the Head itself. Parts: Glass, Icicles, Snow,
-- Steel, Stone, Head (+ FirePoint), Ember, Collision x2.
function TM.tundra_blue_lamp(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_blue_lamp"
	local rng = Random.new(20261706)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Steel = {}, Glass = {}, Snow = {}, Icicles = {} }
	local kit = "Blue_Torch_Standing"
	local function row(name: string): any
		return rowsNamed(kit, name)[1]
	end
	local STEEL_D = rgb(58, 72, 98)
	-- the base and its snow ring
	local ft = row("Foot")
	table.insert(U.Stone, frustumN(8, 0.92, 0.86, 0, 0.3, CFrame.Angles(0, rad(22.5), 0), { ft.color, scaled(ft.color, 1.1), scaled(ft.color, 0.92) }))
	table.insert(U.Stone, frustumN(8, 0.72, 0.6, 0.3, 0.52, CFrame.Angles(0, rad(22.5), 0), { scaled(ft.color, 1.06), ft.color }))
	for k = 0, 5 do
		local a = k * math.pi / 3 + rng:NextNumber(-0.2, 0.2)
		lump(U.Snow, rng, CFrame.new(math.cos(a) * 0.64, 0.3, math.sin(a) * 0.64) * CFrame.Angles(0, -a, 0), 0.24, 0.09, 0.13, snowTone, 0.02)
	end
	-- the post, its bands and 2 scroll brackets
	local pl = row("Pole")
	local pp, ps = pl.cf.Position, pl.size
	local y0, y1 = pp.Y - ps.Y / 2, pp.Y + ps.Y / 2
	table.insert(U.Steel, frustumN(8, 0.27, 0.23, y0, y1 - 0.4, CFrame.Angles(0, rad(22.5), 0), { pl.color, scaled(pl.color, 1.12), scaled(pl.color, 0.9) }))
	for _, y in ipairs({ y0 + 0.9, y1 - 1.05 }) do
		table.insert(U.Steel, frustumN(8, 0.31, 0.31, y - 0.08, y + 0.08, CFrame.Angles(0, rad(22.5), 0), { STEEL_D }))
	end
	for _, sx in ipairs({ -1, 1 }) do
		local a, c = Vector3.new(sx * 0.2, y1 - 0.9, 0), Vector3.new(sx * 0.55, y1 - 0.35, 0)
		table.insert(U.Steel, piece("Part", Vector3.new(0.08, (c - a).Magnitude, 0.1), CFrame.fromMatrix((a + c) / 2, (c - a).Unit:Cross(Vector3.zAxis).Unit, (c - a).Unit), STEEL_D))
		table.insert(U.Steel, frustumN(6, 0.08, 0.08, -0.05, 0.05, H.frameY(c, Vector3.zAxis), { STEEL_D }))
	end
	-- the lantern: today's Head (invisible foot, FirePoint) and Ember (Neon) exactly, plate, posts, glass, roof, cap
	local hd = row("Head")
	local head = exactRow(m, hd)
	head.Transparency = 1
	local fpA = Instance.new("Attachment")
	fpA.Name = "FirePoint"
	fpA.CFrame = CFrame.new(0.5999999046325684, 0, 0)
	fpA.Parent = head
	local em = row("Ember")
	exactRow(m, em)
	local hy = hd.cf.Position.Y
	local yb, yt = hy - 0.45, 6.75
	table.insert(U.Steel, frustumN(8, 0.7, 0.6, yb - 0.12, yb, CFrame.Angles(0, rad(22.5), 0), { STEEL_D, scaled(STEEL_D, 1.15) }))
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Steel, piece("Part", Vector3.new(0.09, yt - yb, 0.09), CFrame.new(sx * 0.5, (yb + yt) / 2, sz * 0.5), STEEL_D))
		end
	end
	for _, f in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
		local size = if f[1] == 0 then Vector3.new(0.92, yt - yb - 0.08, 0.04) else Vector3.new(0.04, yt - yb - 0.08, 0.92)
		table.insert(U.Glass, piece("Part", size, CFrame.new(f[1] * 0.5, (yb + yt) / 2, f[2] * 0.5), rgb(170, 225, 250)))
	end
	table.insert(U.Steel, frustumN(4, 0.82, 0.12, yt, yt + 0.32, CFrame.Angles(0, rad(45), 0), { STEEL_D, scaled(STEEL_D, 1.2) }))
	table.insert(U.Steel, frustumN(8, 0.09, 0.09, yt + 0.3, yt + 0.38, CFrame.new(0, 0, 0) * CFrame.Angles(0, rad(22.5), 0), { STEEL_D }))
	lump(U.Snow, rng, CFrame.new(0, yt + 0.16, 0) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), 0.42, 0.12, 0.42, snowTone, 0.0)
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.4
		facetIcicle(U, "Icicles", Vector3.new(math.cos(a) * 0.55, yb - 0.1, math.sin(a) * 0.55), rng:NextNumber(0.06, 0.12), 0.2, rng:NextNumber(0, 6.28))
	end

	TB.finishTB(m, "tundra_blue_lamp", U, "Stone", { Glass = { material = Enum.Material.Glass, transparency = 0.3, shadow = false }, Icicles = TB.ICICLE_OPTS })
	collisionRows(m, kit, { Head = true, Ember = true })
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table as the earlier props; its install() builds them
---------------------------------------------------------------------
TM.BUILDERS = { tundra_ice_pillar = true, tundra_ice_knight = true, tundra_ice_throne = true, tundra_dome_brazier = true, tundra_glass_frame = true, tundra_blue_lamp = true }
for id in pairs(TM.BUILDERS) do
	B2[id] = (TM :: any)[id]
	B2.BUILDERS[id] = true
end
TM.install = B2.install
TM.stats = B2.stats

return TM
