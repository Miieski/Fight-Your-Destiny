--[[
	PropsTundraBuildings (dev tool, Edit mode only) - the owner's "TUNDRA (SNOW BIOME) PROP IMPROVEMENT - Buildings and
	structures" (2026-10-22): the wrecked wooden cabin, the ice cave entrance, the wooden scaffold stand and the curved snow
	bridge slab rebuilt to the fountain / well quality (docs/prop_texture_guide.md sections A and E), keeping each object's
	colours, place, size, function and collision. Source of truth: tools/PropsTundraBuildings.luau. Inventory:
	docs/prop_inventory.md "Tundra buildings".

	Collision: the visible unions never collide. Every part that collides today is cloned from
	DevTools.PropsTundraBuildingsData (the kits as they were before the remake; the game copies' own parts where they
	differ from the kit) as an invisible "Collision" part (same class, shape, size and place; the cave's ice rock
	MeshParts keep their mesh and collision fidelity), so no copy is more (or less) solid than today.

	Snow is soft and thick: convex solids (GeometryService, one solid = a box cut by planes) with bevelled top edges and
	corners, a few low facets on the top, and faceted lumps along the edges that overhang and droop (an irregular edge).
	Icicles are small tapering 6-sided cones. Ice is translucent faceted crystal (SmoothPlastic, Transparency 0.3, lighter
	edge facets). No union holds hundreds of pieces (a 600-wedge union hung Studio's CSG): logs and lumps are convex solids.

	It uses DevTools.PropsJungleNature (and through it every earlier helper, finish() and frustumN) and registers its
	builders into the same PropsBatch2 table:
		local TB = require(game.ServerStorage.DevTools.PropsTundraBuildings:Clone())
		print(TB.install("tundra_wrecked_cabin"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "tundra_wrecked_cabin" } }), Sync.run({ only = { "tundra_wrecked_cabin" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local Nat = require(ServerStorage.DevTools.PropsJungleNature:Clone()) :: any
local J = Nat.Dc.T.R.G.J
local M, B2, H = J.M, J.B2, J.H
local piece, chamfered = H.piece, H.chamfered
local scaled, graded = H.scaled, H.graded
local finish = M.finish
local frustumN = M.frustumN
local KD = require(ServerStorage.DevTools.PropsTundraBuildingsData:Clone()) :: any
local TS = require(ServerStorage.DevTools.PropsTundraBuildingsSolids:Clone()) :: any -- Agent A's facets as convex solids

local TB = {}

local rgb = Color3.fromRGB
local rad = math.rad
local UP = Vector3.yAxis

-- today's colours (the kits' parts)
local WOOD = rgb(134, 92, 66) -- #865C42 walls, logs, door, rafter
local WOOD_DARK = rgb(92, 66, 54) -- #5C4236 posts, roof, floor, lintel, ridge
local STONE = rgb(118, 128, 150) -- #768096 chimney
local SNOW = rgb(244, 248, 255) -- #F4F8FF
local SNOW_SHADE = rgb(206, 222, 246) -- #CEDEF6
local DARK = rgb(31, 34, 43) -- #1F222B door / window darkness
local ICE_PALE = rgb(214, 236, 255) -- #D6ECFF icicles
local GLASS = rgb(205, 235, 245) -- #CDEBF5 frozen pane
local IRON = H.P.Iron
local LOG_END = rgb(186, 136, 94) -- cut log ends (the log colour x1.4, a little warmer)
local ICE_OPTS = { transparency = 0.3, shadow = false }

TB.COLORS = { WOOD = WOOD, WOOD_DARK = WOOD_DARK, STONE = STONE, SNOW = SNOW, SNOW_SHADE = SNOW_SHADE, DARK = DARK, ICE_PALE = ICE_PALE, GLASS = GLASS }

---------------------------------------------------------------------
-- shared helpers
---------------------------------------------------------------------
local function rowsNamed(kit: string, name: string?): { any }
	local out = {}
	for _, r in ipairs(KD.rows(kit)) do
		if name == nil or r.name == name then
			table.insert(out, r)
		end
	end
	return out
end
TB.rowsNamed = rowsNamed

-- a MeshPart with this MeshId to clone (the kit while it is still today's kit, else the template's or any copy's
-- Collision MeshParts): MeshId cannot be set from a script
local function meshSource(meshId: string): MeshPart?
	local roots = { ServerStorage:FindFirstChild("MapAssets"), ServerStorage:FindFirstChild("MapProps"), ServerStorage:FindFirstChild("BossArenas"), workspace:FindFirstChild("Zones"), workspace:FindFirstChild("_Staging") }
	for _, root in ipairs(roots) do
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("MeshPart") and d.MeshId == meshId then
					return d
				end
			end
		end
	end
	return nil
end

-- today's colliding parts of `kit` (rows) as invisible "Collision" parts (class, shape, size, place; MeshParts keep
-- mesh and collision fidelity); returns how many
local function collisionRows(m: Model, kit: string): number
	local n = 0
	for _, r in ipairs(KD.rows(kit)) do
		if r.collide then
			local p: BasePart
			if r.class == "MeshPart" then
				local src = meshSource(r.meshId)
				assert(src, `PropsTundraBuildings: no MeshPart with {r.meshId} to clone`)
				p = src:Clone()
				p:ClearAllChildren()
				for key in pairs(p:GetAttributes()) do
					p:SetAttribute(key, nil)
				end
				for _, tag in ipairs(p:GetTags()) do
					p:RemoveTag(tag)
				end
				(p :: MeshPart).TextureID = ""
				if r.fidelity then
					pcall(function()
						(p :: any).CollisionFidelity = (Enum.CollisionFidelity :: any)[r.fidelity]
					end)
				end
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
TB.collisionRows = collisionRows

-- finish() without the empty lists
local function finishTB(m: Model, propId: string, U: any, root: string, extra: any?)
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	finish(m, propId, U, root, extra)
end

-- snow tone from a face's world normal: lit tops white, sides a step bluer, undersides the kit's shade
local function snowTone(n: Vector3): Color3
	if n.Y > 0.55 then
		return SNOW
	elseif n.Y > -0.15 then
		return SNOW:Lerp(SNOW_SHADE, 0.55)
	end
	return SNOW_SHADE
end

-- ice tone from a face's world normal: lighter tops and edges, deeper sides
local function iceTone(base: Color3): (Vector3) -> Color3
	return function(n: Vector3): Color3
		if n.Y > 0.5 then
			return base:Lerp(Color3.new(1, 1, 1), 0.35)
		elseif n.Y > -0.2 then
			return base
		end
		return scaled(base, 0.85)
	end
end
TB.snowTone, TB.iceTone = snowTone, iceTone

-- a convex solid from { n = Vector3, d = number } planes in `frame` (box lo .. hi), each face coloured by toneOf(world n)
local function solidOf(list: { BasePart }, frame: CFrame, lo: Vector3, hi: Vector3, planes: { any }, toneOf: (Vector3) -> Color3)
	local out = {}
	for _, pl in ipairs(planes) do
		local n = pl.n.Unit
		table.insert(out, { n.X, n.Y, n.Z, pl.d, toneOf(frame:VectorToWorldSpace(n)) })
	end
	table.insert(list, H.convexSolid(lo, hi, frame, toneOf(frame:VectorToWorldSpace(UP)), out))
end
TB.solidOf = solidOf

-- the bevel plane between planes a and b (both { n, d }), `cut` deep from their common edge
local function bevelOf(a: any, b: any, cut: number): any
	local n = a.n.Unit + b.n.Unit
	local len = n.Magnitude
	return { n = n / len, d = (a.d + b.d) / len - cut }
end

-- 26 directions (6 faces, 12 edges, 8 corners) for faceted lumps: soft, rounded snow (14 read as rocks)
local LUMP_DIRS = {}
for x = -1, 1 do
	for y = -1, 1 do
		for z = -1, 1 do
			if x ~= 0 or y ~= 0 or z ~= 0 then
				table.insert(LUMP_DIRS, Vector3.new(x, y, z).Unit)
			end
		end
	end
end

-- a faceted lump (an ellipsoid a x b x c circumscribed by 26 jittered planes) at frame; flat: a flat bottom that far
-- under the centre
local function lump(list: { BasePart }, rng: Random, frame: CFrame, a: number, b: number, c: number, toneOf: (Vector3) -> Color3, flat: number?)
	local planes = {}
	for _, d0 in ipairs(LUMP_DIRS) do
		local d = (d0 + Vector3.new(rng:NextNumber(-0.1, 0.1), rng:NextNumber(-0.1, 0.1), rng:NextNumber(-0.1, 0.1))).Unit
		table.insert(planes, { n = d, d = math.sqrt((a * d.X) ^ 2 + (b * d.Y) ^ 2 + (c * d.Z) ^ 2) })
	end
	if flat then
		table.insert(planes, { n = -UP, d = flat })
	end
	local e = Vector3.new(a, b, c) * 1.2
	solidOf(list, frame, -e, e, planes, toneOf)
end
TB.lump = lump

-- a soft snow cap on a box (cf, size; local Y up): its top edges bevelled by `top`, its vertical corners by `corner`,
-- `facets` low facets on the top (each tilts one side down a little), the bottom `sink` deeper
local function snowCap(list: { BasePart }, rng: Random, cf: CFrame, size: Vector3, top: number, corner: number, facets: number?, sink: number?)
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local P = {
		{ n = Vector3.xAxis, d = hx }, { n = -Vector3.xAxis, d = hx }, { n = Vector3.zAxis, d = hz }, { n = -Vector3.zAxis, d = hz },
		{ n = UP, d = hy }, { n = -UP, d = hy + (sink or 0) },
	}
	local base = table.clone(P)
	for k = 1, 4 do
		table.insert(P, bevelOf(base[k], base[5], top))
	end
	for _, pair in ipairs({ { 1, 3 }, { 1, 4 }, { 2, 3 }, { 2, 4 } }) do
		table.insert(P, bevelOf(base[pair[1]], base[pair[2]], corner))
	end
	for _ = 1, facets or 0 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local tilt = rng:NextNumber(0.03, 0.07)
		local n = Vector3.new(math.cos(a) * tilt, 1, math.sin(a) * tilt).Unit
		local at = Vector3.new(math.cos(a) * hx * 0.25, hy, math.sin(a) * hz * 0.25)
		table.insert(P, { n = n, d = n:Dot(at) })
	end
	local pad = Vector3.new(0.05, 0.05, 0.05)
	solidOf(list, cf, -size / 2 - pad - Vector3.new(0, sink or 0, 0), size / 2 + pad, P, snowTone)
end
TB.snowCap = snowCap

-- lumps along an edge of a snow cap: from a to b (model space), `n` lumps, each a x b x c (the frame's X along the
-- edge, Y = up), dropped by `droop` and pushed out along `out`
local function edgeLumps(list: { BasePart }, rng: Random, a: Vector3, b: Vector3, up: Vector3, out: Vector3, n: number, size: Vector3, droop: number)
	local along = (b - a)
	for k = 1, n do
		local t = (k - 0.5) / n + rng:NextNumber(-0.25, 0.25) / n
		local s = size * rng:NextNumber(0.75, 1.2)
		local p = a + along * t + out.Unit * rng:NextNumber(0, s.Z * 0.5) - up.Unit * droop * rng:NextNumber(0.6, 1.1)
		local x = along.Unit
		local frame = CFrame.fromMatrix(p, x, up.Unit) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.15, 0.15))
		lump(list, rng, frame, s.X, s.Y, s.Z, snowTone)
	end
end
TB.edgeLumps = edgeLumps

-- a small tapering icicle (6-sided cone) hanging from `top`, `len` long, `r` across at its root
local function icicle(list: { BasePart }, rng: Random, top: Vector3, len: number, r: number)
	local cf = CFrame.new(top) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0) * CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.05, 0.05))
	table.insert(list, frustumN(6, 0.02, r, -len, 0.02, cf, { ICE_PALE, scaled(ICE_PALE, 1.05), scaled(ICE_PALE, 0.93) }))
end
TB.icicle = icicle

-- icicles along a line a .. b (their roots on it): n of them, lengths lo .. hi
local function icicleRow(list: { BasePart }, rng: Random, a: Vector3, b: Vector3, n: number, lo: number, hi: number, r: number?)
	for k = 1, n do
		local t = (k - 0.5) / n + rng:NextNumber(-0.3, 0.3) / n
		local len = rng:NextNumber(lo, hi)
		icicle(list, rng, a:Lerp(b, t), len, (r or 0.16) * (0.75 + 0.25 * len / hi))
	end
end
TB.icicleRow = icicleRow

-- an 8-sided log from a to b (r = half its thickness, a flat face up), tone faces; cut ends (lighter discs) at the ends
-- listed in `cut` ("a", "b")
local function log(list: { BasePart }, ends: { BasePart }?, a: Vector3, b: Vector3, r: number, color: Color3, cut: { string }?)
	local L = (b - a).Magnitude
	local cf = H.frameY((a + b) / 2, b - a) * CFrame.Angles(0, rad(22.5), 0)
	table.insert(list, frustumN(8, r, r, -L / 2, L / 2, cf, { color, scaled(color, 1.07), scaled(color, 0.9), scaled(color, 0.97) }))
	for _, e in ipairs(cut or {}) do
		local y = if e == "a" then -L / 2 else L / 2
		local s = if e == "a" then -1 else 1
		table.insert(ends :: { BasePart }, frustumN(8, r * 0.84, r * 0.84, math.min(y, y + s * 0.04), math.max(y, y + s * 0.04), cf, { LOG_END, scaled(LOG_END, 0.93) }))
	end
end
TB.log = log

-- 2-3 small splinters at a broken end p (pointing along dir)
local function splinters(list: { BasePart }, rng: Random, p: Vector3, dir: Vector3, r: number, color: Color3)
	for _ = 1, rng:NextInteger(2, 3) do
		local off = Vector3.new(rng:NextNumber(-r, r), rng:NextNumber(-r, r), rng:NextNumber(-r, r)) * 0.6
		local len = rng:NextNumber(0.25, 0.55)
		local tip = p + off + dir.Unit * len + Vector3.new(rng:NextNumber(-0.1, 0.1), rng:NextNumber(-0.1, 0.1), rng:NextNumber(-0.1, 0.1))
		table.insert(list, frustumN(4, 0.11, 0.015, 0, (tip - (p + off)).Magnitude, H.frameY(p + off, tip - (p + off)), { scaled(color, 1.15), color }))
	end
end
TB.splinters = splinters

-- a nail head (iron) at p on a face with normal n
local function nail(list: { BasePart }, p: Vector3, n: Vector3)
	table.insert(list, piece("Part", Vector3.new(0.13, 0.05, 0.13), H.frameY(p + n.Unit * 0.02, n), IRON))
end
TB.nail = nail

-- a plank (size, cf) with its tone; nails at the listed local points (on its +Y face)
local function plank(list: { BasePart }, iron: { BasePart }?, size: Vector3, cf: CFrame, color: Color3, nails: { Vector3 }?)
	table.insert(list, piece("Part", size, cf, color))
	for _, q in ipairs(nails or {}) do
		nail(iron :: { BasePart }, cf * Vector3.new(q.X, size.Y / 2, q.Z), cf.UpVector)
	end
end
TB.plank = plank

-- a soft snow drift on a wedge row (the wedge's slope kept as its walking face; the ends tapered, every edge bevelled,
-- the foot 0.08 under the ground) + lumps along its crest and foot
local function drift(list: { BasePart }, rng: Random, r: any, cut: number, lumps: number)
	local s = r.size
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	local sl = Vector3.new(0, s.Z, -s.Y).Unit
	local P = {
		{ n = -UP, d = hy + 0.08 },
		{ n = Vector3.zAxis, d = hz },
		{ n = sl, d = sl:Dot(Vector3.new(0, -hy, -hz)) },
	}
	for _, sx in ipairs({ -1, 1 }) do
		local en = Vector3.new(sx, 0.22, -0.08).Unit
		table.insert(P, { n = en, d = en:Dot(Vector3.new(sx * hx, -hy, 0)) })
	end
	local base = table.clone(P)
	-- 2-step rounding of an edge: a bevel, then the 2 edges it leaves bevelled again
	local function round2(a: any, b: any, c: number)
		local m1 = bevelOf(a, b, c)
		table.insert(P, m1)
		table.insert(P, bevelOf(a, m1, c * 0.3))
		table.insert(P, bevelOf(m1, b, c * 0.3))
	end
	round2(base[3], base[4], cut)
	round2(base[3], base[5], cut)
	round2(base[3], base[2], cut * 0.7)
	round2(base[4], base[2], cut)
	round2(base[5], base[2], cut)
	table.insert(P, bevelOf(base[3], base[1], cut * 0.3))
	local pad = Vector3.new(0.05, 0.05, 0.05)
	solidOf(list, r.cf, -s / 2 - pad - Vector3.new(0, 0.1, 0), s / 2 + pad, P, snowTone)
	-- lumps on the slope (sitting in it, their tops at most 0.25 over it)
	for k = 1, lumps do
		local t = (k - 0.5) / lumps
		local x = -hx * 0.75 + t * hx * 1.5 + rng:NextNumber(-0.4, 0.4)
		local z = rng:NextNumber(-hz * 0.7, hz * 0.4)
		local y = -hy + s.Y * (z + hz) / s.Z
		local a, b, c = rng:NextNumber(1.2, 2.0), 0.35, rng:NextNumber(0.9, 1.4)
		local frame = r.cf * CFrame.fromMatrix(Vector3.new(x, y - b + 0.12, z), Vector3.xAxis, sl) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		lump(list, rng, frame, a, b, c, snowTone)
	end
end
TB.drift = drift

---------------------------------------------------------------------
-- 01 WRECKED WOODEN CABIN (kit MapAssets.Tundra.Cabin_Broken, 40 parts, 26.3 x 18 x 26; 3 copies: test, kit, Tundra_1)
---------------------------------------------------------------------
-- The wrecked cabin (guide E): walls of round (8-sided) logs with saddle-notched corners (the logs of the 2 directions
-- alternate half a log apart and run 0.6 past the corners with lighter cut ends) on a stone footing; the left half
-- standing to the eaves, the right wall and the front right broken off in jagged steps with splintered log ends and 2
-- boards nailed across the break; log gables; a plank roof on rafters with a fascia and bargeboards under a soft thick
-- snow cap with an irregular drooping edge and small icicles; the right roof mostly gone (a remnant at the back, a fallen
-- section inside, one bare rafter over the hole); a log ridge; a stone chimney (17 courses in bond over a dark core, a
-- cap stone, a snow cap round the flue, icicles); a frozen cross-frame window (frosted ice pane, cross bars, frost in
-- the corners, a snowy sill); the plank door with iron straps hanging askew off its top hinge (the bottom strap torn,
-- the pintle empty); snow inside, soft drifts against 3 walls, loose planks in the snow.
-- Today's colliders (the Tundra_1 copy's 32 colliding parts, incl. the askew door and the dark doorway) are kept.
-- Parts: Dark, Ice, Iron, Logs, Snow, Stone, Wood, Collision x32.
function TB.tundra_wrecked_cabin(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_wrecked_cabin"
	local rng = Random.new(20261501)
	H.setBevelSelf(true)
	local U: any = { Logs = {}, Wood = {}, Stone = {}, Iron = {}, Snow = {}, Ice = {}, Dark = {} }
	local Ht = 15
	local R = 0.55 -- log half thickness
	-- (the logs' average tone = today's flat #865C42: the gradient and tone steps darken the palette value by ~12 %)
	local LOGS = scaled(WOOD, 1.12)
	local function logTone(y: number): Color3
		return graded(LOGS, y, Ht, H.TONES[rng:NextInteger(1, 3)])
	end
	-- the log walls. X walls (front z -7.5, back z 7.5) at 1.15 + 1.05 k, Z walls (left x -9.5, right x 9.5) half a log
	-- higher; corners overrun 0.6 past the outer faces (x +-10.65, z +-8.65)
	local XO, ZO = 10.65, 8.65
	local function xLog(z: number, y: number, x0: number, x1: number, cutA: boolean, cutB: boolean, brokenB: boolean?)
		local cut = {}
		if cutA then
			table.insert(cut, "a")
		end
		if cutB then
			table.insert(cut, "b")
		end
		log(U.Logs, U.Wood, Vector3.new(x0, y, z), Vector3.new(x1, y, z), R, logTone(y), cut)
		if brokenB then
			splinters(U.Wood, rng, Vector3.new(x1, y, z), Vector3.xAxis, R, WOOD)
		end
	end
	local function zLog(x: number, y: number, z0: number, z1: number, cutA: boolean, cutB: boolean, brokenA: boolean?)
		local cut = {}
		if cutA then
			table.insert(cut, "a")
		end
		if cutB then
			table.insert(cut, "b")
		end
		log(U.Logs, U.Wood, Vector3.new(x, y, z0), Vector3.new(x, y, z1), R, logTone(y), cut)
		if brokenA then
			splinters(U.Wood, rng, Vector3.new(x, y, z0), -Vector3.zAxis, R, WOOD)
		end
	end
	for k = 0, 7 do
		local y = 1.15 + 1.05 * k
		-- back wall: whole
		xLog(7.5, y, -XO, XO, true, true)
		-- front wall: the window (x -8 .. -5, y 3.5 .. 6.5) and the door (x -3 .. 3, up to 6.5)
		local inWindow = y > 3.4 and y < 6.6
		if k <= 5 then
			if inWindow then
				xLog(-7.5, y, -XO, -8.25, true, false)
				xLog(-7.5, y, -4.75, -3.45, false, false)
			else
				xLog(-7.5, y, -XO, -3.45, true, false)
			end
			if k <= 4 then
				xLog(-7.5, y, 3.45, XO, false, true)
			else
				xLog(-7.5, y, 3.45, 5.6, false, false, true)
			end
		elseif k == 6 then
			xLog(-7.5, y, -XO, 3.8, true, false, true)
		else
			xLog(-7.5, y, -XO, 3.2, true, false, true)
		end
	end
	for k = 0, 6 do
		local y = 1.675 + 1.05 * k
		zLog(-9.5, y, -ZO, ZO, true, true)
		-- the right wall: whole to y 5, then broken along the wedge (top 5 + z / 2)
		if k <= 3 then
			zLog(9.5, y, -ZO, ZO, true, true)
		else
			local z0 = 2 * (y + R - 5) + rng:NextNumber(-0.2, 0.2)
			if ZO - z0 > 1.2 then
				zLog(9.5, y, z0, ZO, false, true, true)
			end
		end
	end
	-- the left wall's top plate (under the eave) and the sill beams under the Z walls
	table.insert(U.Wood, chamfered(Vector3.new(1.0, 0.5, 2 * ZO - 0.3), CFrame.new(-9.5, 8.78, 0), graded(WOOD_DARK, 8.8, Ht), { "topFrontBack", "bottomFrontBack" }, 0.1))
	for _, x in ipairs({ -9.5, 9.5 }) do
		table.insert(U.Wood, chamfered(Vector3.new(1.0, 0.55, 2 * ZO - 1.6), CFrame.new(x, 0.875, 0), graded(WOOD_DARK, 0.9, Ht, 0.95), { "topFrontBack" }, 0.1))
	end
	-- the gables: logs shortening under the roof (the roof underside runs y = 14.88 - 0.577 |x|)
	for i = 0, 4 do
		local y = 9.55 + 1.05 * i
		local half = (14.88 - y - R) / 0.577 - 0.1
		if half > 0.8 then
			xLog(7.5, y, -half, half, false, false)
			-- the front gable: only its left half stands, its right end broken near the middle
			local x1 = rng:NextNumber(-0.6, 0.5)
			if x1 > -half + 0.8 then
				xLog(-7.5, y, -half, x1, false, false, true)
			end
		end
	end
	-- stone footing under the visible front (right of the drift) and right walls
	local function footing(a: number, b: number, fixed: number, alongX: boolean)
		local x = a
		local prev = nil
		while x < b - 0.3 do
			local len = math.min(rng:NextNumber(1.6, 2.6), b - x)
			local ti = H.toneIndex(rng, prev)
			prev = ti
			local c = graded(STONE, 0.3, Ht, H.TONES[ti])
			local mid = x + len / 2
			local cf = if alongX then CFrame.new(mid, 0.3, fixed) else CFrame.new(fixed, 0.3, mid) * CFrame.Angles(0, rad(90), 0)
			table.insert(U.Stone, chamfered(Vector3.new(len - 0.09, 0.62, 1.25), cf, c, { "topFrontBack", "topSides" }, 0.12))
			x += len
		end
	end
	footing(-2.2, 10.6, -7.5, true)
	footing(-8.6, 8.6, 9.5, false)
	-- the floor: dark planks (0.25) over a dark core, most of it under the snow
	for i = 0, 15 do
		local z = -7.5 + i + 0.5 - 0.5
		table.insert(U.Wood, piece("Part", Vector3.new(19, 0.25, 0.95), CFrame.new(0, 0.475, z - 0.0), graded(WOOD_DARK, 0.4, Ht, H.TONES[rng:NextInteger(1, 3)])))
	end
	table.insert(U.Dark, piece("Part", Vector3.new(19, 0.35, 15.6), CFrame.new(0, 0.2, 0), scaled(WOOD_DARK, 0.6)))

	-- the doorway: jambs, threshold, lintel beam, the darkness inside (today's DoorDark)
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Wood, chamfered(Vector3.new(0.45, 5.9, 1.2), CFrame.new(sx * 3.22, 3.55, -7.5), graded(WOOD_DARK, 3.5, Ht), { "vertical" }, 0.1))
	end
	table.insert(U.Wood, chamfered(Vector3.new(6.0, 0.18, 1.2), CFrame.new(0, 0.69, -7.5), scaled(WOOD_DARK, 0.9), { "topFrontBack" }, 0.06))
	table.insert(U.Wood, chamfered(Vector3.new(7.4, 0.6, 1.25), CFrame.new(0, 6.75, -7.5), graded(WOOD_DARK, 6.7, Ht), { "topFrontBack", "bottomFrontBack" }, 0.12))
	table.insert(U.Dark, piece("Part", Vector3.new(6.0, 5.9, 0.2), CFrame.new(0, 3.55, -7.2), DARK))
	-- the door (today's askew slab): 4 planks with gaps, 2 battens and a brace inside, 2 iron straps outside; it hangs
	-- off its top hinge (local -X, the left jamb); the bottom strap is torn and bent
	local door = rowsNamed("Cabin_Broken_game", "Door")[1]
	local dcf, ds = door.cf, door.size
	for i = 0, 3 do
		local w = ds.X / 4
		local x = -ds.X / 2 + w * (i + 0.5)
		local short = if i == 3 then rng:NextNumber(0.4, 0.7) else 0
		table.insert(U.Wood, chamfered(Vector3.new(w - 0.06, ds.Y - short, 0.26), dcf * CFrame.new(x, short / 2, -0.02), graded(WOOD, 3, Ht, H.TONES[(i % 3) + 1]), { "vertical" }, 0.05))
		if short > 0 then
			splinters(U.Wood, rng, (dcf * CFrame.new(x, -ds.Y / 2 + short, 0)).Position, -dcf.UpVector, 0.3, WOOD)
		end
	end
	for _, y in ipairs({ -2.2, 2.2 }) do
		table.insert(U.Wood, piece("Part", Vector3.new(ds.X - 0.4, 0.5, 0.14), dcf * CFrame.new(0, y, 0.19), scaled(WOOD, 0.85)))
	end
	local b0, b1 = Vector3.new(-ds.X / 2 + 0.4, -2.0, 0.19), Vector3.new(ds.X / 2 - 0.4, 2.0, 0.19)
	table.insert(U.Wood, piece("Part", Vector3.new(0.45, (b1 - b0).Magnitude, 0.12), dcf * CFrame.new((b0 + b1) / 2) * CFrame.Angles(0, 0, -math.atan2(b1.X - b0.X, b1.Y - b0.Y)), scaled(WOOD, 0.8)))
	-- the top strap, whole, with its hinge knuckle on the hinge edge
	table.insert(U.Iron, piece("Part", Vector3.new(3.6, 0.32, 0.07), dcf * CFrame.new(-ds.X / 2 + 1.8, 2.2, -0.19), IRON))
	table.insert(U.Iron, piece("Part", Vector3.new(0.6, 0.26, 0.26), dcf * CFrame.new(-ds.X / 2 - 0.08, 2.2, -0.12) * CFrame.Angles(0, 0, rad(90)), scaled(IRON, 0.9), { shape = Enum.PartType.Cylinder }))
	-- the bottom strap, torn off the hinge: a short piece on the door and a bent end hanging loose
	table.insert(U.Iron, piece("Part", Vector3.new(2.4, 0.32, 0.07), dcf * CFrame.new(-ds.X / 2 + 1.75, -2.2, -0.19), IRON))
	table.insert(U.Iron, piece("Part", Vector3.new(0.9, 0.3, 0.07), dcf * CFrame.new(-ds.X / 2 + 0.25, -2.42, -0.22) * CFrame.Angles(0, rad(-18), rad(28)), scaled(IRON, 1.08)))
	for _, q in ipairs({ { -1.6, 2.2 }, { -0.5, 2.2 }, { 0.6, 2.2 }, { -1.6, -2.2 }, { -0.4, -2.2 } }) do
		nail(U.Iron, (dcf * CFrame.new(q[1], q[2], -0.23)).Position, dcf.LookVector)
	end
	-- the pintles on the left jamb: the top one holds the knuckle, the bottom one is empty
	for _, y in ipairs({ 5.3, 1.6 }) do
		table.insert(U.Iron, piece("Part", Vector3.new(0.18, 0.18, 0.5), CFrame.new(-3.3, y, -8.25), IRON))
		table.insert(U.Iron, piece("Part", Vector3.new(0.12, 0.35, 0.12), CFrame.new(-3.3, y + 0.17, -8.45), scaled(IRON, 0.9)))
	end

	-- the frozen cross-frame window (today's Window at (-6.5, 5, -7.5) of the game copy: 3 x 3)
	local win = rowsNamed("Cabin_Broken_game", "Window")[1]
	local wp = win.cf.Position
	local wz = -8.0
	table.insert(U.Dark, piece("Part", Vector3.new(3.0, 3.0, 0.2), CFrame.new(wp.X, wp.Y, -7.15), DARK))
	table.insert(U.Ice, piece("Part", Vector3.new(3.0, 3.0, 0.08), CFrame.new(wp.X, wp.Y, wz + 0.25), GLASS))
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Wood, chamfered(Vector3.new(0.4, 3.4, 1.3), CFrame.new(wp.X + sx * 1.7, wp.Y, -7.5), graded(WOOD_DARK, wp.Y, Ht), { "vertical" }, 0.08))
	end
	table.insert(U.Wood, chamfered(Vector3.new(3.9, 0.32, 1.3), CFrame.new(wp.X, wp.Y + 1.66, -7.5), graded(WOOD_DARK, wp.Y + 1.7, Ht), { "topFrontBack" }, 0.08))
	table.insert(U.Wood, chamfered(Vector3.new(4.1, 0.3, 1.75), CFrame.new(wp.X, wp.Y - 1.65, -7.72), graded(WOOD_DARK, wp.Y - 1.6, Ht, 1.05), { "topFrontBack" }, 0.08))
	table.insert(U.Wood, piece("Part", Vector3.new(3.0, 0.2, 0.2), CFrame.new(wp.X, wp.Y, wz + 0.15), WOOD_DARK))
	table.insert(U.Wood, piece("Part", Vector3.new(0.2, 3.0, 0.2), CFrame.new(wp.X, wp.Y, wz + 0.15), WOOD_DARK))
	-- frost in the pane corners
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local corner = Vector3.new(wp.X + c[1] * 1.45, wp.Y + c[2] * 1.45, wz + 0.19)
		local s1 = rng:NextNumber(0.5, 0.8)
		local s2 = rng:NextNumber(0.5, 0.8)
		H.triangleParts(U.Snow, corner, corner - Vector3.new(c[1] * s1, 0, 0), corner - Vector3.new(0, c[2] * s2, 0), 0.04, CFrame.identity, SNOW)
	end
	snowCap(U.Snow, rng, CFrame.new(wp.X, wp.Y - 1.38, -7.85), Vector3.new(3.7, 0.26, 1.2), 0.1, 0.25, 1)
	icicleRow(U.Ice, rng, Vector3.new(wp.X - 1.6, wp.Y - 1.8, -8.45), Vector3.new(wp.X + 1.6, wp.Y - 1.8, -8.45), 4, 0.25, 0.6, 0.1)

	-- boards nailed across the front right break
	for _, b in ipairs({ { Vector3.new(4.0, 6.75, -8.14), Vector3.new(9.6, 5.35, -8.14) }, { Vector3.new(4.6, 5.2, -8.2), Vector3.new(9.2, 6.1, -8.2) } }) do
		local a, c = b[1], b[2]
		local cf2 = CFrame.fromMatrix((a + c) / 2, (c - a).Unit, -Vector3.zAxis)
		plank(U.Wood, U.Iron, Vector3.new((c - a).Magnitude, 0.12, 0.85), cf2, graded(WOOD, a.Y, Ht, 1.08), { Vector3.new(-(c - a).Magnitude / 2 + 0.4, 0, 0.2), Vector3.new(-(c - a).Magnitude / 2 + 0.4, 0, -0.2), Vector3.new((c - a).Magnitude / 2 - 0.4, 0, 0) })
	end

	-- the roof: per slope a frame whose X runs down/up the slope, Y = the slope's normal (today's Roof rows)
	local roofs = rowsNamed("Cabin_Broken_game", "Roof")
	table.sort(roofs, function(a, b)
		return a.cf.Position.X < b.cf.Position.X
	end)
	local snows = rowsNamed("Cabin_Broken_game", "RoofSnow")
	table.sort(snows, function(a, b)
		return a.cf.Position.X < b.cf.Position.X
	end)
	local function roofBoards(r: any, eaveSign: number, broken: (number) -> number)
		-- boards along the slope (local X) over rafters, a fascia at the eave, bargeboards at the gable ends
		local s = r.size
		local n = math.floor(s.Z / 1.12 + 0.5)
		local w = s.Z / n
		for i = 0, n - 1 do
			local z = -s.Z / 2 + w * (i + 0.5)
			local short = broken(z)
			local len = s.X - short
			local xc = -eaveSign * short / 2
			local c = graded(WOOD_DARK, r.cf.Position.Y, Ht, H.TONES[rng:NextInteger(1, 3)] * 1.08)
			table.insert(U.Wood, chamfered(Vector3.new(len, 0.22, w - 0.07), r.cf * CFrame.new(xc, 0.29, z), c, { "topFrontBack" }, 0.05))
			if short > 0.3 then
				splinters(U.Wood, rng, (r.cf * CFrame.new(xc + eaveSign * len / 2, 0.29, z)).Position, r.cf.RightVector * eaveSign, 0.12, WOOD_DARK)
			else
				nail(U.Iron, (r.cf * CFrame.new(eaveSign * (s.X / 2 - 0.35), 0.41, z)).Position, r.cf.UpVector)
			end
		end
		for z = -s.Z / 2 + 0.6, s.Z / 2 - 0.5, 3.6 do
			table.insert(U.Wood, chamfered(Vector3.new(s.X - 0.3, 0.45, 0.45), r.cf * CFrame.new(0, -0.05, z), graded(WOOD, r.cf.Position.Y - 0.5, Ht, 0.9), { "bottomFrontBack" }, 0.08))
		end
		table.insert(U.Wood, chamfered(Vector3.new(0.22, 0.6, s.Z + 0.2), r.cf * CFrame.new(eaveSign * (s.X / 2 + 0.05), 0.08, 0), graded(WOOD_DARK, r.cf.Position.Y, Ht, 0.95), { "topSides" }, 0.06))
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Wood, chamfered(Vector3.new(s.X, 0.6, 0.2), r.cf * CFrame.new(0, 0.12, sz * (s.Z / 2 + 0.08)), graded(WOOD_DARK, r.cf.Position.Y, Ht, 0.92), { "topFrontBack" }, 0.06))
		end
	end
	-- left slope (eave at local -X): whole, 2 boards at the front gable shorter (storm damage)
	roofBoards(roofs[1], -1, function(z)
		return if z < -7.4 then rng:NextNumber(0.6, 1.4) else 0
	end)
	-- right remnant (eave at local +X): its front (local -Z) boards broken off at different lengths
	roofBoards(roofs[2], 1, function(z)
		return if z < 0 then rng:NextNumber(0.8, 2.6) else rng:NextNumber(0, 0.25)
	end)
	-- the snow caps, their edges overhanging the eaves with drooping lumps, icicles under the eaves
	for i, sr in ipairs(snows) do
		local s = sr.size
		snowCap(U.Snow, rng, sr.cf * CFrame.new(0, -0.05, 0), s - Vector3.new(0, 0.1, 0), 0.42, 0.7, 3, 0.05)
		local eave = if i == 1 then -1 else 1
		local ea = (sr.cf * CFrame.new(eave * (s.X / 2 - 0.1), -0.05, -s.Z / 2 + 0.5)).Position
		local eb = (sr.cf * CFrame.new(eave * (s.X / 2 - 0.1), -0.05, s.Z / 2 - 0.5)).Position
		edgeLumps(U.Snow, rng, ea, eb, sr.cf.UpVector, sr.cf.RightVector * eave, if i == 1 then 7 else 3, Vector3.new(1.3, 0.42, 0.55), 0.18)
		for _, sz in ipairs({ -1, 1 }) do
			local ga = (sr.cf * CFrame.new(-s.X / 2 + 1.2, -0.05, sz * (s.Z / 2 - 0.1))).Position
			local gb = (sr.cf * CFrame.new(s.X / 2 - 1.2, -0.05, sz * (s.Z / 2 - 0.1))).Position
			edgeLumps(U.Snow, rng, ga, gb, sr.cf.UpVector, sr.cf.LookVector * -sz, if i == 1 then 3 else 2, Vector3.new(1.1, 0.38, 0.45), 0.1)
		end
		local r = roofs[i]
		local ia = (r.cf * CFrame.new(eave * (r.size.X / 2 + 0.1), -0.25, -r.size.Z / 2 + 0.4)).Position
		local ib = (r.cf * CFrame.new(eave * (r.size.X / 2 + 0.1), -0.25, r.size.Z / 2 - 0.4)).Position
		icicleRow(U.Ice, rng, ia, ib, if i == 1 then 11 else 4, 0.35, 1.3)
	end
	-- the bare rafter over the hole (today's Rafter), its low end splintered
	local raf = rowsNamed("Cabin_Broken_game", "Rafter")[1]
	table.insert(U.Wood, chamfered(raf.size - Vector3.new(0.4, 0, 0), raf.cf * CFrame.new(-0.2, 0, 0), graded(WOOD, raf.cf.Position.Y, Ht), { "topFrontBack", "bottomFrontBack" }, 0.12))
	splinters(U.Wood, rng, (raf.cf * CFrame.new(raf.size.X / 2 - 0.4, 0, 0)).Position, raf.cf.RightVector, 0.3, WOOD)
	snowCap(U.Snow, rng, raf.cf * CFrame.new(-1.2, 0.45, 0), Vector3.new(5.0, 0.22, 0.75), 0.08, 0.2, 0)
	-- the fallen section inside (today's RoofFallen): 6 boards on 2 battens, a little snow on its upper part
	local fall = rowsNamed("Cabin_Broken_game", "RoofFallen")[1]
	do
		local s = fall.size
		for i = 0, 5 do
			local w = s.Z / 6
			local short = rng:NextNumber(0, 0.9)
			table.insert(U.Wood, chamfered(Vector3.new(s.X - short, 0.22, w - 0.08), fall.cf * CFrame.new(short / 2 * (if i % 2 == 0 then 1 else -1), 0.29, -s.Z / 2 + w * (i + 0.5)), graded(WOOD_DARK, 4, Ht, H.TONES[rng:NextInteger(1, 3)] * 1.06), { "topFrontBack" }, 0.05))
		end
		for _, x in ipairs({ -2.6, 2.4 }) do
			table.insert(U.Wood, chamfered(Vector3.new(0.45, 0.42, s.Z - 0.3), fall.cf * CFrame.new(x, -0.1, 0), scaled(WOOD, 0.85), { "bottomFrontBack" }, 0.06))
		end
		-- a little snow caught along its upper edge (local -X is up the slope)
		edgeLumps(U.Snow, rng, (fall.cf * CFrame.new(-s.X / 2 + 0.5, 0.42, -s.Z / 2 + 0.8)).Position, (fall.cf * CFrame.new(-s.X / 2 + 0.5, 0.42, s.Z / 2 - 0.8)).Position, fall.cf.UpVector, -fall.cf.RightVector, 3, Vector3.new(0.9, 0.22, 0.4), 0)
	end
	-- the ridge log (today's Ridge, 18.6 long, 1.4 thick) with cut ends
	log(U.Logs, U.Wood, Vector3.new(0, 15.2, -9.3), Vector3.new(0, 15.2, 9.3), 0.68, graded(WOOD_DARK, 15, Ht, 1.05), { "a", "b" })

	-- the stone chimney (today's Chimney 3.2 x 17 x 3.2 at (-5.5, 8.5, 5)): 17 courses in bond over a dark core
	local ch = rowsNamed("Cabin_Broken_game", "Chimney")[1]
	local cp = ch.cf.Position
	local cw = ch.size.X
	table.insert(U.Dark, piece("Part", Vector3.new(cw - 0.3, ch.size.Y - 0.1, cw - 0.3), CFrame.new(cp.X, cp.Y - 0.05, cp.Z), scaled(STONE, 0.55)))
	local nC = 17
	local hC = ch.size.Y / nC
	local prev = nil
	for i = 0, nC - 1 do
		local y = i * hC + hC / 2
		local turn = i % 2 == 1
		local function blk(size: Vector3, off: Vector3)
			local ti = H.toneIndex(rng, prev)
			prev = ti
			local o = if turn then Vector3.new(off.Z, off.Y, off.X) else off
			local sz = if turn then Vector3.new(size.Z, size.Y, size.X) else size
			local j = Vector3.new(rng:NextNumber(-0.03, 0.03), 0, rng:NextNumber(-0.03, 0.03))
			table.insert(U.Stone, chamfered(sz, CFrame.new(cp.X + o.X + j.X, y, cp.Z + o.Z + j.Z), graded(STONE, y, 17, H.TONES[ti]), { "vertical" }, 0.13))
		end
		blk(Vector3.new(cw, hC - 0.06, 1.05), Vector3.new(0, 0, cw / 2 - 0.525))
		blk(Vector3.new(cw, hC - 0.06, 1.05), Vector3.new(0, 0, -cw / 2 + 0.525))
		blk(Vector3.new(1.0, hC - 0.06, cw - 2.2), Vector3.new(cw / 2 - 0.5, 0, 0))
		blk(Vector3.new(1.0, hC - 0.06, cw - 2.2), Vector3.new(-cw / 2 + 0.5, 0, 0))
	end
	local topY = ch.size.Y
	table.insert(U.Stone, chamfered(Vector3.new(cw + 0.5, 0.3, cw + 0.5), CFrame.new(cp.X, topY - 0.05, cp.Z), scaled(STONE, 0.8), { "topFrontBack", "topSides" }, 0.1))
	table.insert(U.Dark, piece("Part", Vector3.new(1.0, 0.1, 1.0), CFrame.new(cp.X, topY + 0.12, cp.Z), DARK))
	-- the snow cap round the flue (today's ChimneySnow 3.8 x 0.9 on top)
	local cs = rowsNamed("Cabin_Broken_game", "ChimneySnow")[1]
	local csy = cs.cf.Position.Y + 0.05
	for _, sz in ipairs({ -1, 1 }) do
		snowCap(U.Snow, rng, CFrame.new(cp.X, csy, cp.Z + sz * 1.22), Vector3.new(cs.size.X - 0.1, 0.62, 1.32), 0.22, 0.4, 1)
		snowCap(U.Snow, rng, CFrame.new(cp.X + sz * 1.22, csy - 0.04, cp.Z), Vector3.new(1.32, 0.55, 1.2), 0.2, 0.3, 0)
	end
	for _, e in ipairs({ { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1) }, { Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) }, { Vector3.new(1, 0, -1), Vector3.new(1, 0, 1) } }) do
		local a = Vector3.new(cp.X, topY - 0.22, cp.Z) + e[1] * (cw / 2 + 0.24)
		local b = Vector3.new(cp.X, topY - 0.22, cp.Z) + e[2] * (cw / 2 + 0.24)
		icicleRow(U.Ice, rng, a, b, 2, 0.25, 0.6, 0.11)
	end

	-- snow: inside (today's SnowInside, a soft blanket blown in, a mound under the hole), the 3 drifts against the walls
	local si = rowsNamed("Cabin_Broken_game", "SnowInside")[1]
	snowCap(U.Snow, rng, si.cf, si.size, 0.45, 1.0, 3)
	for _, p in ipairs({ Vector3.new(6.4, 1.3, -1.5), Vector3.new(7.6, 1.3, 2.6), Vector3.new(3.2, 1.3, 1.0), Vector3.new(-4.2, 1.3, -3.6) }) do
		lump(U.Snow, rng, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(1.3, 2.2), 0.45, rng:NextNumber(1.1, 1.8), snowTone, 0.2)
	end
	for _, d in ipairs(rowsNamed("Cabin_Broken_game", "Drift")) do
		drift(U.Snow, rng, d, 0.8, math.max(2, math.floor(d.size.X / 5)))
	end
	-- small drifts along the front-right and right walls (no collider today: flat, under 0.6)
	for _, p in ipairs({ { Vector3.new(6.5, 0, -8.5), 2.2 }, { Vector3.new(10.4, 0, -3.0), 1.5 }, { Vector3.new(10.4, 0, 4.0), 1.5 } }) do
		lump(U.Snow, rng, CFrame.new(p[1]) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), p[2], 0.5, p[2] * 0.55, snowTone, 0.02)
	end
	-- loose planks half buried in the snow round the cabin (one with its nails)
	for _, l in ipairs({ { Vector3.new(10.2, 0.12, -10.6), 32, 3.0 }, { Vector3.new(10.4, 0.16, 10.8), -58, 3.0 }, { Vector3.new(3.6, 0.12, -12.0), 12, 3.4 }, { Vector3.new(-1.5, 1.66, -2.4), 70, 2.8 }, { Vector3.new(11.2, 0.1, 1.0), 95, 2.4 } }) do
		local cf = CFrame.new(l[1]) * CFrame.Angles(0, rad(l[2]), 0) * CFrame.Angles(rad(rng:NextNumber(-4, 4)), 0, rad(rng:NextNumber(-5, 5)))
		plank(U.Wood, U.Iron, Vector3.new(l[3], 0.2, 0.95), cf, graded(WOOD, 0.5, Ht, H.TONES[rng:NextInteger(1, 3)]), { Vector3.new(-l[3] / 2 + 0.3, 0, 0.2), Vector3.new(l[3] / 2 - 0.3, 0, -0.15) })
		splinters(U.Wood, rng, (cf * CFrame.new(l[3] / 2, 0, 0)).Position, cf.RightVector, 0.12, WOOD)
		lump(U.Snow, rng, cf * CFrame.new(rng:NextNumber(-0.8, 0.8), 0.05, 0.6), 0.9, 0.22, 0.5, snowTone, 0.1)
	end

	finishTB(m, "tundra_wrecked_cabin", U, "Logs", { Ice = ICE_OPTS })
	collisionRows(m, "Cabin_Broken_game")
	return m
end

---------------------------------------------------------------------
-- Agent A's facet pieces (guide E7; DevTools.PropsTundraBuildingsSolids: each closed convex shell = one convex solid)
---------------------------------------------------------------------
-- a piece at frame, scaled per axis by S (default 1): its Glass shells go to U[glassKey], the others to U[solidKey]
local function facetPiece(U: any, data: any, frame: CFrame, S: Vector3?, glassKey: string, solidKey: string)
	local s = S or Vector3.one
	for _, sd in ipairs(data.solids) do
		local planes = {}
		for _, p in ipairs(sd.planes) do
			local n = Vector3.new(p[1] / s.X, p[2] / s.Y, p[3] / s.Z)
			local len = n.Magnitude
			table.insert(planes, { n.X / len, n.Y / len, n.Z / len, p[4] / len, p[5] })
		end
		local key = if sd.glass then glassKey else solidKey
		U[key] = U[key] or {}
		local pad = Vector3.new(0.03, 0.03, 0.03)
		table.insert(U[key], H.convexSolid(sd.lo * s - pad, sd.hi * s + pad, frame, Color3.fromHex(sd.planes[1][5]), planes))
	end
end
TB.facetPiece = facetPiece

-- Agent A's icicle (root at `root`, 3.0 long at Y scale 1, 0.9 across at XZ scale 1) into U[key]
local function facetIcicle(U: any, key: string, root: Vector3, yScale: number, xzScale: number, yaw: number)
	facetPiece(U, TS.tundra_ice__icicle, CFrame.new(root) * CFrame.Angles(0, yaw, 0), Vector3.new(xzScale, yScale, xzScale), key, key)
end
TB.facetIcicle = facetIcicle

-- the underside y of a facet solid over (x, z) (its planes, from a point inside it straight down)
local function undersideOf(sd: any, x: number, z: number, insideY: number): number
	local planes = {}
	for _, p in ipairs(sd.planes) do
		table.insert(planes, { n = Vector3.new(p[1], p[2], p[3]), d = p[4] })
	end
	return Nat.surfaceAlong(planes, Vector3.new(x, insideY, z), -UP).Y
end

local GLASS_OPTS = { material = Enum.Material.Glass, transparency = 0.3, shadow = false }
local ICICLE_OPTS = { material = Enum.Material.Glass, transparency = 0.25, shadow = false }
TB.GLASS_OPTS, TB.ICICLE_OPTS = GLASS_OPTS, ICICLE_OPTS

---------------------------------------------------------------------
-- 02 ICE CAVE ENTRANCE (kit MapAssets.Tundra.Ice_Cave_Mouth, 9 parts, 29 x 18.2 x 13; 7 copies: test, kit, Tundra_2 x4,
-- BossArenas Tundra at Model scale 1.25)
---------------------------------------------------------------------
-- The ice cave entrance (guide E4, Agent A's facets): 2 faceted translucent ice boulders (Glass T 0.3 with light
-- chamfered edges over an opaque deep core: navy in the left #54A0E8 one, #1E7FD6 in the right #96D6FA one) in place of
-- today's 2 IceRock looks; the thick slate slab in 2 strata (#4E566E under, #768096 above with a front overhang and a
-- light top band) under its soft thick snow cap (domed, bulging rim, 5 drips over the front, 2 per end); icicles: today's
-- 3 at their x / z with roots on the slab underside (no tip under y 7.0, today's lowest) + 2 clusters along the front
-- edge; the dark interior: today's Back and Dark exactly as they are, with an inner frame of slate blocks in front of
-- the Dark (2 jambs, an arch of 5 voussoirs under the slab) lined with a navy band, and a frozen stone lip (a chamfered
-- threshold slab with an ice glaze over its front half and 3 icicle stubs); ice shards x4, 2 ice blocks with snow caps
-- and soft drifts against the boulders' feet. Colliders: today's Back, Dark and the 3 IceRock MeshParts (mesh, size,
-- place, fidelity) as invisible Collision parts. The opening stays closed by the Dark, as today.
-- Parts: Dark, Ice, IceCore, Icicles, Rock, Snow, Collision x5.
function TB.tundra_ice_cave(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_ice_cave"
	local rng = Random.new(20261502)
	H.setBevelSelf(true)
	local U: any = { Rock = {}, Ice = {}, IceCore = {}, Icicles = {}, Snow = {}, Dark = {} }
	local kit = "Ice_Cave_Mouth"
	local ID = CFrame.identity
	facetPiece(U, TS.tundra_cave__ice_left, ID, nil, "Ice", "IceCore")
	facetPiece(U, TS.tundra_cave__ice_right, ID, nil, "Ice", "IceCore")
	facetPiece(U, TS.tundra_cave__slab, ID, nil, "Ice", "Rock")
	facetPiece(U, TS.tundra_cave__slab_snow, ID, nil, "Ice", "Snow")
	-- the slab's lower stratum (its underside = the opening's top)
	local lower = TS.tundra_cave__slab.solids[1]
	for _, sd in ipairs(TS.tundra_cave__slab.solids) do
		if sd.lo.Y < lower.lo.Y then
			lower = sd
		end
	end
	local midY = (lower.lo.Y + lower.hi.Y) / 2
	-- today's 3 icicles (x, z, length; the tips stay at y 7.0 or higher) and 2 clusters along the front edge
	for _, ic in ipairs({ { 0.4, -0.6, 3.3 }, { -3.2, -0.6, 3.0 }, { 3.4, -0.6, 2.6 } }) do
		local y = undersideOf(lower, ic[1], ic[2], midY)
		local len = math.min(ic[3], y + 0.1 - 7.0)
		facetIcicle(U, "Icicles", Vector3.new(ic[1], y + 0.1, ic[2]), len / 3, 1, rng:NextNumber(0, 6.28))
	end
	for _, cl in ipairs({ { -2.0, 0.72 }, { 2.3, 0.8 } }) do
		local z = -3.0
		local y = undersideOf(lower, cl[1], z, midY)
		local s = math.min(cl[2], (y + 0.1 - 7.0) / 3.05)
		facetPiece(U, TS.tundra_ice__icicle_cluster, CFrame.new(cl[1], y + 0.1, z) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), Vector3.one * s, "Icicles", "Icicles")
	end

	-- today's Back and Dark, exactly as they are (their looks; the colliders are separate)
	for _, name in ipairs({ "Back", "Dark" }) do
		local r = rowsNamed(kit, name)[1]
		table.insert(U.Dark, piece("Part", r.size, r.cf, r.color))
	end
	-- the inner frame in front of the Dark (z 0 .. 0.8): 2 slate jambs and an arch of 5 voussoirs under the slab, a navy
	-- band lining it
	local SLATE, NAVY = rgb(78, 86, 110), rgb(35, 74, 143)
	local top = undersideOf(lower, 0, 0.4, midY)
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Rock, chamfered(Vector3.new(1.2, top - 1.3, 0.8), CFrame.new(sx * 4.1, (top - 1.3) / 2 + 0.02, 0.4), graded(SLATE, 4, 14, H.TONES[rng:NextInteger(1, 3)]), { "vertical" }, 0.12))
		table.insert(U.Dark, piece("Part", Vector3.new(0.45, top - 1.4, 0.5), CFrame.new(sx * 3.3, (top - 1.4) / 2, 0.55), NAVY))
	end
	local x = -4.7
	for k = 1, 5 do
		local w = 9.4 / 5
		local mid = x + w / 2
		local h = 1.25 - math.abs(mid) * 0.08
		table.insert(U.Rock, chamfered(Vector3.new(w - 0.08, h, 0.8), CFrame.new(mid, top - h / 2 - 0.02, 0.4) * CFrame.Angles(0, 0, -mid * 0.03), graded(SLATE, 10, 14, H.TONES[(k % 3) + 1]), { "bottomFrontBack" }, 0.1))
		x += w
	end
	table.insert(U.Dark, piece("Part", Vector3.new(6.2, 0.45, 0.5), CFrame.new(0, top - 1.45, 0.55), NAVY))
	-- the frozen stone lip: a threshold slab, an ice glaze over its front half, 3 icicle stubs on its front edge
	table.insert(U.Rock, chamfered(Vector3.new(9.0, 0.5, 1.6), CFrame.new(0, 0.25, -0.2), scaled(SLATE, 0.95), { "topFrontBack", "topSides" }, 0.14))
	table.insert(U.Ice, piece("Part", Vector3.new(8.7, 0.08, 0.8), CFrame.new(0, 0.53, -0.58), rgb(191, 233, 245)))
	for _, sx in ipairs({ -2.6, 0.3, 2.9 }) do
		facetIcicle(U, "Icicles", Vector3.new(sx, 0.48, -0.98), 0.12, 0.3, rng:NextNumber(0, 6.28))
	end

	-- the base: 4 shard clusters, 2 ice blocks with snow caps, soft drifts against the boulders' feet and both sides
	for _, sh in ipairs({ { -4.9, -5.2, 20, 1 }, { 5.3, -5.4, -35, 0.8 }, { -11.8, -2.6, 0, 0.7 }, { 12.3, -1.8, 150, 0.6 } }) do
		facetPiece(U, TS.tundra_ice__shards, CFrame.new(sh[1], 0, sh[2]) * CFrame.Angles(0, rad(sh[3]), 0), Vector3.one * sh[4], "Ice", "Ice")
	end
	for _, bl in ipairs({ { -12.4, -3.0, 25, 1.0 }, { 11.6, -3.4, -15, 1.2 } }) do
		local cf = CFrame.new(bl[1], 0, bl[2]) * CFrame.Angles(0, rad(bl[3]), 0)
		facetPiece(U, TS.tundra_ice__block, cf, Vector3.one * bl[4], "Ice", "Ice")
		facetPiece(U, TS.tundra_snow__cap, cf * CFrame.new(0, 1.2 * bl[4], 0), Vector3.new(1.5, 0.35, 1.3) * bl[4], "Snow", "Snow")
	end
	for _, d in ipairs({ { -8.2, -5.0, 0, Vector3.new(7, 1.6, 3) }, { 8.0, -5.0, 0, Vector3.new(7, 1.6, 3) }, { -13.2, 0.6, 90, Vector3.new(6, 1.4, 2.4) }, { 13.2, 0.4, -90, Vector3.new(6, 1.4, 2.4) } }) do
		facetPiece(U, TS.tundra_snow__drift, CFrame.new(d[1], -0.05, d[2]) * CFrame.Angles(0, rad(d[3]), 0), d[4], "Snow", "Snow")
	end

	finishTB(m, "tundra_ice_cave", U, "Rock", { Ice = GLASS_OPTS, Icicles = ICICLE_OPTS })
	collisionRows(m, kit)
	return m
end

---------------------------------------------------------------------
-- 03 WOODEN SCAFFOLD STAND (kit MapAssets.Tundra.Wooden_Scaffold, 15 parts, 16 x 13.6 x 8; 5 copies: test, kit,
-- Tundra_3 x3)
---------------------------------------------------------------------
-- a rope lashing: `turns` thin rings round the axis `axis` at p (radius r), tilted, and a hanging end
local ROPE = rgb(196, 160, 104) -- #C4A068
local function lashing(list: { BasePart }, p: Vector3, axis: Vector3, r: number, turns: number, rng: Random)
	local a = axis.Unit
	for k = 1, turns do
		local c = p + a * ((k - (turns + 1) / 2) * 0.14)
		local cf = H.frameY(c, a) * CFrame.Angles(rad(8), rng:NextNumber(0, 6.28), 0)
		table.insert(list, frustumN(8, r + 0.06, r + 0.06, -0.06, 0.06, cf, { ROPE, scaled(ROPE, 0.88) }))
	end
	local side = if math.abs(a.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local out = a:Cross(side).Unit
	table.insert(list, piece("Part", Vector3.new(0.1, 0.55, 0.1), CFrame.new(p + out * (r + 0.08) - Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, rad(10)), scaled(ROPE, 0.92)))
end
TB.lashing = lashing

-- an iron band (w tall, 0.06 proud) round a square post (side s) at height y
local function postBand(list: { BasePart }, x: number, z: number, y: number, s: number, w: number)
	table.insert(list, piece("Part", Vector3.new(s + 0.12, w, s + 0.12), CFrame.new(x, y, z), IRON))
end

-- The scaffold stand (guide E5): today's 4 posts chamfered (0.18) on slate footing stones, 2 iron bands each, an ice
-- glaze at the feet, the front posts with a cap and a soft snow cap above the rail; today's front X braces cross-lapped
-- with an iron strap and pegs at the crossing and rope lashings at the posts; the 2 side diagonals with iron straps and
-- nails at both ends; 2 knee braces under the deck front; the deck as 6 planks with gaps (top exactly y 10.8) over a
-- dark board and 2 joists, nails at the posts, one plank shorter; today's front rail chamfered, 2 short side rails to 2
-- stub posts on the back corners, rope ties, a thin snow line on the rail (0.15) and frost rime; today's 2 snow patches
-- as soft caps (today's height), 3 ice blocks with small caps on the deck, icicle clusters under the deck front and the
-- rail, a low drift at 2 post feet. Colliders: today's 4 Posts, Deck and Rail. Parts: Dark, Ice, Icicles, Iron, Rope,
-- Snow, Stone, Wood, Collision x6.
function TB.tundra_scaffold(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_scaffold"
	local rng = Random.new(20261503)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Iron = {}, Rope = {}, Stone = {}, Snow = {}, Ice = {}, Icicles = {}, Dark = {} }
	local kit = "Wooden_Scaffold"
	local Ht = 13.6
	local SLATE, FROST, BACKING = rgb(78, 86, 110), rgb(230, 238, 246), rgb(58, 42, 34)
	local deck = rowsNamed(kit, "Deck")[1]
	local deckTop = deck.cf.Position.Y + deck.size.Y / 2 -- 10.8
	local rail = rowsNamed(kit, "Rail")[1]
	local railTop = rail.cf.Position.Y + rail.size.Y / 2 -- 13.55
	-- the posts
	for _, p in ipairs(rowsNamed(kit, "Post")) do
		local pp, ps = p.cf.Position, p.size
		local h = ps.Y
		table.insert(U.Wood, chamfered(ps, p.cf, graded(p.color, h / 2, Ht, H.TONES[rng:NextInteger(1, 3)] * 1.08), { "vertical" }, 0.18))
		table.insert(U.Stone, chamfered(Vector3.new(1.5, 0.35, 1.5), CFrame.new(pp.X, 0.17, pp.Z) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), graded(SLATE, 0.2, Ht, H.TONES[rng:NextInteger(1, 3)]), { "topFrontBack", "topSides" }, 0.1))
		postBand(U.Iron, pp.X, pp.Z, h / 6, ps.X, 0.3)
		postBand(U.Iron, pp.X, pp.Z, h - h / 6, ps.X, 0.3)
		table.insert(U.Ice, piece("Part", Vector3.new(ps.X + 0.1, 0.3, ps.Z + 0.1), CFrame.new(pp.X, 0.5, pp.Z), rgb(191, 233, 245)))
		if h > 12 then
			-- the front posts: a cap slab, a low pyramid, a soft snow cap above the rail
			table.insert(U.Wood, chamfered(Vector3.new(ps.X + 0.24, 0.16, ps.Z + 0.24), CFrame.new(pp.X, h + 0.08, pp.Z), scaled(p.color, 1.1), { "topFrontBack", "topSides" }, 0.05))
			table.insert(U.Wood, frustumN(4, (ps.X + 0.2) / 2, 0.06, h + 0.16, h + 0.42, CFrame.new(pp.X, 0, pp.Z) * CFrame.Angles(0, rad(45), 0), { scaled(p.color, 1.12), p.color }))
			facetPiece(U, TS.tundra_snow__cap, CFrame.new(pp.X, h + 0.14, pp.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Vector3.new(1.1, 0.4, 1.1), "Snow", "Snow")
		end
	end
	-- the front X braces (today's 2), the crossing strapped and pegged, rope lashings where they meet the posts
	local cross = Vector3.zero
	for _, r in ipairs(rowsNamed(kit, "Brace")) do
		local s = r.size
		if s.X > 10 then
			table.insert(U.Wood, chamfered(s - Vector3.new(0.6, 0, 0), r.cf, graded(r.color, 5, Ht, H.TONES[rng:NextInteger(1, 3)] * 1.05), { "topFrontBack", "bottomFrontBack" }, 0.1))
			cross += r.cf.Position / 2
			for _, e in ipairs({ -1, 1 }) do
				local p = (r.cf * CFrame.new(e * (s.X / 2 - 0.9), 0, 0)).Position
				lashing(U.Rope, p, r.cf.RightVector, 0.25, 3, rng)
			end
		else
			-- the side diagonals: iron straps with nails at both ends
			table.insert(U.Wood, chamfered(s - Vector3.new(0, 0, 0.4), r.cf, graded(r.color, 5, Ht, H.TONES[rng:NextInteger(1, 3)] * 1.05), { "topFrontBack", "bottomFrontBack" }, 0.1))
			for _, e in ipairs({ -1, 1 }) do
				local c = r.cf * CFrame.new(0, 0, e * (s.Z / 2 - 0.8))
				table.insert(U.Iron, piece("Part", Vector3.new(s.X + 0.12, s.Y + 0.12, 0.3), c, IRON))
				local out = if r.cf.Position.X < 0 then -Vector3.xAxis else Vector3.xAxis
				nail(U.Iron, c.Position + out * (s.X / 2 + 0.06), out)
			end
		end
	end
	-- the crossing: an iron strap over both braces, 2 pegs
	table.insert(U.Iron, piece("Part", Vector3.new(0.3, 1.0, 0.14), CFrame.new(cross.X, cross.Y, -3.83), IRON))
	for _, dy in ipairs({ -0.3, 0.3 }) do
		table.insert(U.Wood, piece("Part", Vector3.new(0.14, 0.14, 0.12), CFrame.new(cross.X + 0.25, cross.Y + dy, -3.92), scaled(WOOD_DARK, 0.9)))
	end
	-- knee braces under the deck front
	for _, sx in ipairs({ -1, 1 }) do
		local a, b = Vector3.new(sx * 6.95, deckTop - 2.15, -3.4), Vector3.new(sx * 5.55, deckTop - 0.75, -3.4)
		table.insert(U.Wood, chamfered(Vector3.new(0.4, (b - a).Magnitude + 0.3, 0.4), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(rad(-90), 0, 0), graded(WOOD, 9, Ht), { "vertical" }, 0.08))
	end
	-- the deck: 6 planks (top exactly at the collider's top), a dark backing board, 2 joists, nails at the posts
	local n = 6
	local w = 1.25
	for i = 0, n - 1 do
		local z = -((n - 1) / 2) * (w + 0.06) + i * (w + 0.06)
		local short = if i == 2 then 0.3 else 0
		local len = 16.2 - short
		local c = graded(rgb(134, 92, 66), deckTop, Ht, H.TONES[(i % 3) + 1] * 1.04)
		table.insert(U.Wood, chamfered(Vector3.new(len, 0.2, w), CFrame.new(-short / 2, deckTop - 0.1, z), c, { "topFrontBack" }, 0.05))
		for _, x in ipairs({ -7.4, 7.4 }) do
			if not (short > 0 and x > 0) then
				nail(U.Iron, Vector3.new(x, deckTop - 0.025, z - 0.3), UP)
				nail(U.Iron, Vector3.new(x, deckTop - 0.025, z + 0.3), UP)
			end
		end
	end
	table.insert(U.Dark, piece("Part", Vector3.new(15.8, 0.15, 7.6), CFrame.new(0, deckTop - 0.28, 0), BACKING))
	for _, z in ipairs({ -2.5, 2.5 }) do
		table.insert(U.Wood, chamfered(Vector3.new(15.6, 0.45, 0.5), CFrame.new(0, deckTop - 0.6, z), graded(WOOD_DARK, 10, Ht), { "bottomFrontBack" }, 0.08))
	end
	-- the rails: today's front rail, 2 side rails to 2 stub posts on the back corners, rope ties, rime and snow
	table.insert(U.Wood, chamfered(rail.size, rail.cf, graded(rail.color, railTop, Ht, 1.06), { "topFrontBack", "bottomFrontBack" }, 0.1))
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 7.4
		table.insert(U.Wood, chamfered(Vector3.new(0.6, 2.6, 0.6), CFrame.new(x, deckTop + 1.3, 3.1), graded(WOOD_DARK, 12, Ht, 1.05), { "vertical" }, 0.1))
		table.insert(U.Wood, chamfered(Vector3.new(0.4, 0.4, 6.9), CFrame.new(x, 13.0, -0.15), graded(WOOD, 13, Ht, 1.02), { "topSides", "bottomSides" }, 0.08))
		lashing(U.Rope, Vector3.new(x, 13.0, -2.95), Vector3.zAxis, 0.22, 3, rng)
		lashing(U.Rope, Vector3.new(x, 13.0, 2.7), Vector3.zAxis, 0.22, 2, rng)
		facetPiece(U, TS.tundra_snow__cap, CFrame.new(x, deckTop + 2.6, 3.1), Vector3.new(0.75, 0.25, 0.75), "Snow", "Snow")
	end
	-- frost rime on the front rail top (3 broken runs) and a thin soft snow line (0.15 over the rail top)
	for _, run in ipairs({ { -7.0, -3.2 }, { -1.6, 2.4 }, { 3.9, 6.9 } }) do
		local mid, len = (run[1] + run[2]) / 2, run[2] - run[1]
		facetPiece(U, TS.tundra_snow__cap, CFrame.new(mid, railTop - 0.01, rail.cf.Position.Z), Vector3.new(len, 0.15, 0.6), "Snow", "Snow")
	end
	table.insert(U.Snow, piece("Part", Vector3.new(15.4, 0.06, 0.12), CFrame.new(0, railTop - 0.2, rail.cf.Position.Z - 0.27), FROST))
	-- today's 2 snow patches on the deck as soft caps (today's height), 3 ice blocks with small caps
	facetPiece(U, TS.tundra_snow__cap, CFrame.new(-2, deckTop - 0.02, 0.6), Vector3.new(8.6, 0.45, 4.6), "Snow", "Snow")
	facetPiece(U, TS.tundra_snow__cap_shade, CFrame.new(5, deckTop - 0.02, -1.5), Vector3.new(4, 0.4, 3), "Snow", "Snow")
	for _, bl in ipairs({ { 4.6, 1.6, 18, 1 }, { 5.9, 2.6, -25, 0.7 }, { -6.2, -1.9, 40, 0.85 } }) do
		local cf = CFrame.new(bl[1], deckTop, bl[2]) * CFrame.Angles(0, rad(bl[3]), 0)
		facetPiece(U, TS.tundra_ice__block, cf, Vector3.one * bl[4], "Ice", "Ice")
		facetPiece(U, TS.tundra_snow__cap, cf * CFrame.new(0, 1.2 * bl[4], 0), Vector3.new(1.5, 0.35, 1.3) * bl[4], "Snow", "Snow")
	end
	-- icicle clusters under the deck front edge and the rail
	for _, ic in ipairs({ { -3.0, deckTop - 0.8, -3.95 }, { 2.6, deckTop - 0.8, -3.95 }, { -0.8, railTop - 0.5, rail.cf.Position.Z } }) do
		facetPiece(U, TS.tundra_ice__icicle_cluster, CFrame.new(ic[1], ic[2], ic[3]) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0), Vector3.one * 0.45, "Icicles", "Icicles")
	end
	-- a low drift against 2 post feet (its high side on the post; inside today's footprint +10 %)
	for _, d in ipairs({ { -6.15, -3.4, -90 }, { 6.15, 3.4, 90 } }) do
		facetPiece(U, TS.tundra_snow__drift, CFrame.new(d[1], -0.05, d[2]) * CFrame.Angles(0, rad(d[3]), 0), Vector3.new(1.9, 1.0, 2.2), "Snow", "Snow")
	end

	finishTB(m, "tundra_scaffold", U, "Wood", { Ice = GLASS_OPTS, Icicles = ICICLE_OPTS })
	collisionRows(m, kit)
	return m
end

---------------------------------------------------------------------
-- 04 CURVED SNOW BRIDGE SLAB (kit MapAssets.Tundra.Snow_Bridge_Section, 11 parts, 41.6 x 9.8 x 10.6; 5 copies: test,
-- kit, Tundra_3 x3)
---------------------------------------------------------------------
-- the lowest underside of a facet piece over (x, z) (the piece in its own frame), or nil
local function pieceUnderside(data: any, x: number, z: number): number?
	local best = nil
	for _, sd in ipairs(data.solids) do
		if x > sd.lo.X and x < sd.hi.X and z > sd.lo.Z and z < sd.hi.Z then
			local y = undersideOf(sd, x, z, (sd.lo.Y + sd.hi.Y) / 2)
			if y > sd.lo.Y - 0.1 and y < sd.hi.Y and (best == nil or y < best) then
				best = y
			end
		end
	end
	return best
end

-- The snow bridge (guide E6, Agent A's facets): each span's layered faceted blue ice underside (3 strata stepping in
-- going down, a keel, light chamfered edges, Glass T 0.25 over an opaque core: #54A0E8 / navy in the middle,
-- #96D6FA / #1E7FD6 on the sides; the left side = the right piece turned 180) under soft snow whose TOPS are exactly
-- today's collider tops (middle flat y 8.0, sides on their 13 deg planes), lips rolling over the long edges and the
-- bridge ends with drip lumps; a soft snow roll over each joint (at most 0.1 over a walk top, visual only); today's 5
-- icicles at their x / z (length / 3 = Y scale) with roots in the keels + single small icicles under the snow lips.
-- Colliders: the game copies' 3 Span + 3 SpanSnow (side parts 10.1 / 10.7 deep), so every walk top stays exactly.
-- Parts: Ice, IceCore, Icicles, Snow, Collision x6.
function TB.tundra_snow_bridge(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_snow_bridge"
	local rng = Random.new(20261504)
	H.setBevelSelf(true)
	local U: any = { Snow = {}, Ice = {}, IceCore = {}, Icicles = {} }
	local ID = CFrame.identity
	local LEFT = CFrame.Angles(0, math.pi, 0)
	facetPiece(U, TS.tundra_bridge__ice_mid, ID, nil, "Ice", "IceCore")
	facetPiece(U, TS.tundra_bridge__snow_mid, ID, nil, "Ice", "Snow")
	for _, f in ipairs({ ID, LEFT }) do
		facetPiece(U, TS.tundra_bridge__ice_side, f, nil, "Ice", "IceCore")
		facetPiece(U, TS.tundra_bridge__snow_side, f, nil, "Ice", "Snow")
	end
	-- a soft snow roll over each joint, hiding the seam (and today's 0.07-0.17 step): its top 0.02 under the middle's
	-- walk top, so it stands at most 0.1 over the side's top next to it (checked analytically on the planes)
	local midTop = 8.0
	for _, sx in ipairs({ -1, 1 }) do
		facetPiece(U, TS.tundra_snow__cap, CFrame.new(sx * 7.85, midTop - 0.02 - 0.3, 0), Vector3.new(1.2, 0.3, 11.2), "Snow", "Snow")
	end
	-- today's 5 icicles (x, z, length), roots 0.1 inside the keels
	for _, ic in ipairs({ { -9, -3, 3.0 }, { -4, 2.5, 4.6 }, { 1, -3, 2.6 }, { 6, 2.5, 5.0 }, { 11, -3, 3.4 } }) do
		local x, z = ic[1], ic[2]
		local y
		if math.abs(x) < 7.6 then
			y = pieceUnderside(TS.tundra_bridge__ice_mid, x, z)
		elseif x > 0 then
			y = pieceUnderside(TS.tundra_bridge__ice_side, x, z)
		else
			y = pieceUnderside(TS.tundra_bridge__ice_side, -x, -z)
		end
		if y then
			facetIcicle(U, "Icicles", Vector3.new(x, y + 0.1, z), ic[3] / 3, 1, rng:NextNumber(0, 6.28))
		end
	end
	-- single small icicles under the snow lips (the pieces' icicleRoots; the left side mirrored)
	for _, r in ipairs(TS.tundra_bridge__snow_mid.icicleRoots) do
		facetIcicle(U, "Icicles", r + Vector3.new(0, 0.08, 0), rng:NextNumber(0.35, 0.6), 0.6, rng:NextNumber(0, 6.28))
	end
	for _, r in ipairs(TS.tundra_bridge__snow_side.icicleRoots) do
		for _, s in ipairs({ 1, -1 }) do
			facetIcicle(U, "Icicles", Vector3.new(s * r.X, r.Y + 0.08, s * r.Z), rng:NextNumber(0.35, 0.6), 0.6, rng:NextNumber(0, 6.28))
		end
	end

	finishTB(m, "tundra_snow_bridge", U, "Snow", { Ice = { material = Enum.Material.Glass, transparency = 0.25, shadow = false }, Icicles = ICICLE_OPTS })
	collisionRows(m, "Snow_Bridge_Section_game")
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table as the earlier props; its install() builds them
---------------------------------------------------------------------
TB.BUILDERS = { tundra_wrecked_cabin = true, tundra_ice_cave = true, tundra_scaffold = true, tundra_snow_bridge = true }
for id in pairs(TB.BUILDERS) do
	B2[id] = (TB :: any)[id]
	B2.BUILDERS[id] = true
end
TB.install = B2.install
TB.stats = B2.stats
TB.KD = KD
-- (shared with DevTools.PropsTundraGates)
TB.B2, TB.H, TB.M, TB.Nat, TB.TS, TB.meshSource, TB.finishTB = B2, H, M, Nat, TS, meshSource, finishTB

return TB
