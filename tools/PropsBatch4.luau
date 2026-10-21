--[[
	PropsBatch4 (dev tool, Edit mode only) - the owner's "HUB AND PLAINS BUILDINGS AND PROPS IMPROVEMENT - BATCH 4"
	(2026-10-21): the plains / hub cottages, the two-storey house, the stone tower, the 2 tents and the props (spiked
	mace, barrel, ladder, fence section, sign board, wooden post, banner, flagpole, short lamp post, wall torch, the
	tutorial guide's platform) rebuilt in the fountain / well recipe (docs/prop_texture_guide.md sections A and D),
	keeping each object's colours, place, size, function and collision. Source of truth: tools/PropsBatch4.luau.
	Inventory: docs/prop_inventory.md "Batch 4".

	Collision: the visible unions never collide. Every kit part that collides today is cloned from
	DevTools.PropsBatch4Data (the kits as they were before the remake) as an invisible "Collision" part (same class,
	shape, size and place), so no copy is more (or less) solid than today.

	It uses DevTools.PropsJungleNature (and through it every earlier helper, finish() and the SHAPES table) and
	registers its builders into the same PropsBatch2 table:
		local B4 = require(game.ServerStorage.DevTools.PropsBatch4:Clone())
		print(B4.install("barrel"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.run({ only = { "barrel" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local Nat = require(ServerStorage.DevTools.PropsJungleNature:Clone()) :: any
local Dc = Nat.Dc
local T = Dc.T
local R = T.R
local G = R.G
local J = G.J
local M, B2, H = J.M, J.B2, J.H
local piece, chamfered = H.piece, H.chamfered
local finish = M.finish
local P = H.P
local KD = require(ServerStorage.DevTools.PropsBatch4Data:Clone()) :: any

local B4 = {}

-- the FirePoint Attachments of today's torch Heads (read from the kits on 2026-10-21; the zones' Fire_Torch VFX parts
-- stand on them)
local FIREPOINT = {
	Torch_Standing = CFrame.new(0.599999905, 0, 0, -4.37113883e-08, 1, 0, -1, -4.37113883e-08, 0, 0, 0, 1),
	Torch_Wall = CFrame.new(0.38867569, 0, -0.372749329, -4.37113883e-08, 0.927183867, 0.37460658, -1, -4.05284943e-08, -1.63745728e-08, 0, -0.37460658, 0.927183867),
}
B4.FIREPOINT = FIREPOINT

local rad = math.rad
local rgb = Color3.fromRGB
local scaled, graded = H.scaled, H.graded

---------------------------------------------------------------------
-- shared helpers
---------------------------------------------------------------------
-- finish() without the empty lists
local function finishB4(m: Model, propId: string, U: any, root: string, extra: any?)
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	finish(m, propId, U, root, extra)
end

-- the kit rows named `name` (all when nil)
local function rowsNamed(kit: string, name: string?): { any }
	local out = {}
	for _, r in ipairs(KD.rows(kit)) do
		if name == nil or r.name == name then
			table.insert(out, r)
		end
	end
	return out
end

-- today's colliding kit parts as invisible "Collision" parts (class, shape, size, place kept); skip(row) leaves rows out
-- (a nested prop's parts); returns how many
local function kitCollision(m: Model, kit: string, skip: ((any) -> boolean)?): number
	local n = 0
	for _, r in ipairs(KD.rows(kit)) do
		if r.collide and not (skip and skip(r)) then
			local p = Instance.new(r.class) :: BasePart
			if r.shape ~= "" and p:IsA("Part") then
				p.Shape = Enum.PartType[r.shape]
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
B4.kitCollision = kitCollision

-- a box from a to b in the plane with normal n (its thickness `w` across, `d` deep along n)
local function strut(a: Vector3, b: Vector3, n: Vector3, w: number, d: number, color: Color3, chamfer: boolean?): BasePart
	local y = (b - a).Unit
	local x = y:Cross(n).Unit
	local cf = CFrame.fromMatrix((a + b) / 2, x, y)
	local size = Vector3.new(w, (b - a).Magnitude, d)
	if chamfer then
		return chamfered(size, cf, color, { "vertical" }, math.min(w, d) * 0.2)
	end
	return piece("Part", size, cf, color)
end

-- the outward axis of a part sitting on one of the 4 walls of a box w x d centred on the origin (+-X or +-Z)
local function wallNormal(pos: Vector3, w: number, d: number): Vector3
	if math.abs(pos.X) / w > math.abs(pos.Z) / d then
		return Vector3.new(math.sign(pos.X), 0, 0)
	end
	return Vector3.new(0, 0, math.sign(pos.Z))
end

-- a small Neon-glass wall lantern: an iron arm out of the wall at `at` (normal n), a square cage with a warm glass,
-- a pyramid cap and a ring (no light: decor)
local function wallLantern(iron: { BasePart }, glass: { BasePart }, at: Vector3, n: Vector3, s: number)
	local side = Vector3.yAxis:Cross(n).Unit
	local frame = CFrame.fromMatrix(at, side, Vector3.yAxis)
	table.insert(iron, piece("Part", Vector3.new(0.5, 0.7, 0.12) * s, frame * CFrame.new(0, 0, 0.06 * s), P.Iron)) -- wall plate
	local tip = at + n * 1.0 * s
	table.insert(iron, H.bar(at + n * 0.05, tip + Vector3.new(0, 0.1 * s, 0), 0.12 * s, P.Iron))
	local c = tip + Vector3.new(0, -0.55 * s, 0)
	local cage = CFrame.fromMatrix(c, side, Vector3.yAxis)
	table.insert(glass, piece("Part", Vector3.new(0.5, 0.7, 0.5) * s, cage, rgb(255, 214, 120), { material = Enum.Material.Neon }))
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(iron, piece("Part", Vector3.new(0.08, 0.78, 0.08) * s, cage * CFrame.new(sx * 0.27 * s, 0, sz * 0.27 * s), P.Iron))
		end
	end
	table.insert(iron, piece("Part", Vector3.new(0.68, 0.1, 0.68) * s, cage * CFrame.new(0, -0.42 * s, 0), P.Iron))
	table.insert(iron, M.frustumN(4, 0.5 * s, 0.06 * s, 0.38 * s, 0.75 * s, cage * CFrame.Angles(0, rad(45), 0), { P.Iron, scaled(P.Iron, 0.9) }))
	table.insert(iron, piece("Part", Vector3.new(0.06, 0.25, 0.25) * s, cage * CFrame.new(0, 0.85 * s, 0), P.Iron))
end

-- moss pad at the foot of a wall (guide A4): 2 squashed low frusta at `pos`, along `along`
local function footMoss(list: { BasePart }, rng: Random, pos: Vector3, along: Vector3, len: number)
	local yaw = math.atan2(-along.Z, along.X)
	for k = 0, 1 do
		local o = along * (k - 0.5) * len * 0.45
		local r = len * (0.32 - k * 0.07)
		table.insert(list, M.frustumN(6, r, r * 0.6, -0.1, 0.22 + 0.08 * (1 - k), CFrame.new(pos + o) * CFrame.Angles(0, yaw + k, 0), { if k == 0 then P.Moss else P.MossDark, scaled(P.MossDark, 0.92) }))
	end
end
---------------------------------------------------------------------
-- 02 BARREL (the "barrel" template since batch 1: StaveLow / StaveBelly / StaveHigh cylinders 3.0 / 3.38 / 3.0 across,
-- a Lid, 3 iron Hoops with 2 rivets each; 4.05 tall, pivot = bottom centre; 43 copies: Barrel_A x33 (hub harbour /
-- AFK corner, the plains farm, docks, pirate camp, mine, desert camps and village, volcano camp, the troll den, test,
-- kit) and the embedded barrels of the HunterCamps, the fruit stalls and the trainer)
---------------------------------------------------------------------
-- The barrel (guide A6 / A7 / D4, owner: "staves with visible plank lines, slightly bulging shape, iron bands with
-- rivets, a lid with planks and a small bung hole"): 14 staves of 3 tilted thirds each (1.5 at the ends, 1.66 at the
-- belly, 0.2 thick, 0.05 gaps over a dark core, 3 tones, the gradient), their tops standing over the lid (the
-- chime, 0.15); today's 3 hoops (1.05, 3.0, 3.72) as 16-sided iron bands 0.07 proud of the staves, 4 rivets each; a lid of
-- 5 planks with gaps and a dark bung hole. Today's 3 stave cylinders stay the colliders. Parts: Wood, Iron,
-- Collision x3.
local BARREL_H = 4.05
local BARREL_YS = { 0, 1.35, 2.7, BARREL_H } -- the stave profile points (3 straight thirds: a soft bulge)
local function barrelNode(y: number): number
	return 1.5 + 0.19 * math.sin(math.pi * y / BARREL_H)
end
-- the outer radius of the staves at height y (linear between the profile points)
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

function B4.barrel(): Model
	local m = Instance.new("Model")
	m.Name = "barrel"
	local rng = Random.new(20261401)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Iron = {} }
	local WOOD = rgb(187, 109, 62) -- today's belly #BB6D3E
	local CORE = rgb(70, 40, 24)
	local N, t = 14, 0.2
	-- the dark core (seen through the stave gaps and between the lid planks)
	table.insert(U.Wood, H.prism16(2 * 1.24, 3.62, CFrame.new(0, 1.83, 0), CORE)) -- inside the staves (no overlap: fewer triangles)
	-- staves: 3 tilted thirds (the profile points), each a box from the lower to the upper point
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
			local w = 2 * (rm - t / 2) * math.tan(math.pi / N) - 0.04 -- the inner corners clear their neighbours
			table.insert(U.Wood, piece("Part", Vector3.new(w, (p1 - p0).Magnitude, t), CFrame.fromMatrix((p0 + p1) / 2, x, up), graded(base, (ya + yb) / 2, BARREL_H)))
		end
	end
	-- the lid: 5 planks 0.15 under the stave tops (just over the solid top hoop), gaps 0.05, a dark bung hole
	local lidY, lidR = BARREL_H - 0.15, barrelR(BARREL_H) - t - 0.02
	local LID = rgb(150, 86, 50)
	for k = -2, 2 do
		local x = k * 0.53
		local half = math.sqrt(math.max(lidR * lidR - (math.abs(x) + 0.26) ^ 2, 0.2))
		table.insert(U.Wood, piece("Part", Vector3.new(0.48, 0.12, 2 * half), CFrame.new(x, lidY - 0.06, 0), scaled(LID, ({ 1, 0.92, 0.86, 0.95, 1.04 })[k + 3])))
	end
	table.insert(U.Wood, M.frustumN(8, 0.14, 0.14, -0.01, 0.015, CFrame.new(0.53, lidY, 0.45), { CORE, CORE }))
	table.insert(U.Wood, M.frustumN(8, 0.21, 0.19, -0.01, 0.025, CFrame.new(0.53, lidY - 0.01, 0.45), { scaled(LID, 0.8), scaled(LID, 0.8) }))
	-- today's 3 hoops: 16-sided iron bands 0.07 proud of the staves (solid: their inside is hidden in the barrel), 4 rivets
	for hi, y in ipairs({ 1.05, 3.0, 3.72 }) do
		local r = barrelR(y) + 0.035
		table.insert(U.Iron, H.prism16(2 * (r + 0.035), 0.28, CFrame.new(0, y, 0), scaled(P.Iron, 0.92 + 0.08 * hi / 3)))
		for k = 0, 3 do
			local a = (k * 4 + 0.5 + hi) * 2 * math.pi / N
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			table.insert(U.Iron, piece("Part", Vector3.new(0.12, 0.12, 0.12), CFrame.new(d * (r + 0.04) + Vector3.new(0, y, 0)) * CFrame.Angles(rad(45), a, rad(45)), P.IronWorn))
		end
	end
	finishB4(m, "barrel", U, "Wood")
	kitCollision(m, "Barrel_A")
	return m
end

---------------------------------------------------------------------
-- half-timbered houses (01 FarmHouse, 02 Cottage_A, 03 Cottage_B): one recipe on the kit's own parts (guide D2)
---------------------------------------------------------------------
-- clay tiles on a roof slab (the kit's Roof part: L along X, its slope along local Z): a dark deck = today's slab,
-- rows of tiles (1.9 x 1.95 x 0.16, rows every 1.6, half-offset, butts lifted), a fascia board at the eave and
-- bargeboards at both gable edges. The even rows go into `tiles`, the odd ones into `tiles2`: no tile overlaps another in
-- its union (overlapping parts split into many triangles)
local function tileRoof(tiles: { BasePart }, tiles2: { BasePart }, wood: { BasePart }, rng: Random, row: any, color: Color3, deckColor: Color3)
	local cf, size = row.cf, row.size
	local n = cf.UpVector
	if n.Y < 0 then
		n = -n
	end
	local u = cf.LookVector
	if u.Y < 0 then
		u = -u
	end
	local x = Vector3.xAxis
	local top = cf.Position + n * size.Y / 2
	local L, W = size.X, size.Z
	table.insert(wood, piece("Part", size, cf, deckColor))
	local frame = CFrame.fromMatrix(Vector3.zero, x, n, x:Cross(n))
	local function at(t: number, xx: number, lift: number): CFrame
		return CFrame.new(top - u * W / 2 + u * t + x * xx + n * lift) * frame
	end
	local tw, tl, step = 1.9, 1.95, 1.6
	local rows = math.ceil((W - 0.2) / step)
	local prev
	for k = 0, rows - 1 do
		local t0 = k * step - 0.1
		local len = math.min(tl, W - t0 + 0.02)
		if len < 0.4 then
			continue
		end
		local xx = -L / 2 - (if k % 2 == 1 then tw / 2 else 0)
		while xx < L / 2 - 0.05 do
			local a, b = math.max(xx, -L / 2), math.min(xx + tw, L / 2)
			if b - a > 0.4 then
				local ti = H.toneIndex(rng, prev)
				prev = ti
				local col = scaled(color, ({ 1, 0.94, 0.88 })[ti] * (0.92 + 0.08 * k / rows))
				-- the eave end of each tile lifted (a visible butt line)
				local tilt = math.atan2(0.12, len)
				local s = if (u:Cross(x)):Dot(n) > 0 then 1 else -1
				table.insert(if k % 2 == 0 then tiles else tiles2, piece("Part", Vector3.new(b - a - 0.08, 0.16, len), at(t0 + len / 2, (a + b) / 2, 0.1) * CFrame.Angles(s * tilt, 0, 0), col))
			end
			xx += tw
		end
	end
	-- fascia at the eave, bargeboards along the 2 gable edges
	table.insert(wood, piece("Part", Vector3.new(L + 0.3, size.Y + 0.3, 0.25), at(0.12, 0, -size.Y / 2 + 0.05), P.WoodDark))
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(wood, piece("Part", Vector3.new(0.22, 0.5, W + 0.1), at(W / 2, sx * (L / 2 + 0.11), 0.05), P.WoodDark))
	end
end

-- the roof surface height at (x, z) under a roof slab row (its top face)
local function roofY(row: any, x: number, z: number): number
	local n = row.cf.UpVector
	if n.Y < 0 then
		n = -n
	end
	local p = row.cf.Position + n * row.size.Y / 2
	return p.Y - (n.X * (x - p.X) + n.Z * (z - p.Z)) / n.Y
end

-- openings (windows, door) on a wall face: { a, b, y0, y1 } in the face's own x (along `along`)
local function openings(rowsAll: { any }, nrm: Vector3, along: Vector3, w: number, d: number): { any }
	local out = {}
	for _, r in ipairs(rowsAll) do
		if r.name == "Window" or r.name == "Door" then
			local p = r.cf.Position
			if wallNormal(p, w, d):Dot(nrm) > 0.9 then
				local half = (if r.name == "Door" then 3.8 else 2.55)
				local u = p:Dot(along)
				table.insert(out, { u - half, u + half, p.Y - r.size.Y / 2 - 0.4, p.Y + r.size.Y / 2 + 0.6 })
			end
		end
	end
	return out
end

local function blocked(list: { any }, a: number, b: number, y0: number, y1: number): boolean
	for _, o in ipairs(list) do
		if b > o[1] and a < o[2] and y1 > o[3] and y0 < o[4] then
			return true
		end
	end
	return false
end
-- a plank door on today's Door part (front = its outward normal n): a dark back board, 5 vertical planks with gaps,
-- 2 iron strap hinges with rivets on the hinge side, today's gold handle on a back plate
local function plankDoor(U: any, rng: Random, row: any, n: Vector3, handle: any?)
	local cf, size = row.cf, row.size
	local side = Vector3.yAxis:Cross(n).Unit
	local face = CFrame.fromMatrix(cf.Position, side, Vector3.yAxis) -- +Z = outward
	local w, h = size.X, size.Y
	table.insert(U.Wood, piece("Part", Vector3.new(w, h, 0.2), face * CFrame.new(0, 0, -0.05), rgb(60, 34, 20)))
	local planks = 5
	local pw = w / planks
	for k = 0, planks - 1 do
		local c = scaled(row.color, ({ 1, 0.92, 0.86, 0.96, 0.9 })[k + 1])
		table.insert(U.Wood, chamfered(Vector3.new(pw - 0.07, h - 0.04, 0.32), face * CFrame.new(-w / 2 + pw * (k + 0.5), 0, 0.1), c, { "vertical" }, 0.06))
	end
	-- the hinge side: away from the handle
	local hs = -1
	if handle then
		local hp = face:PointToObjectSpace(handle.cf.Position)
		hs = if hp.X > 0 then -1 else 1
	end
	for _, y in ipairs({ -h * 0.32, h * 0.32 }) do
		local len = w * 0.62
		local x0 = hs * (w / 2 - 0.05)
		table.insert(U.Iron, piece("Part", Vector3.new(len, 0.32, 0.06), face * CFrame.new(x0 - hs * len / 2, y, 0.29), P.Iron))
		table.insert(U.Iron, M.frustumN(8, 0.24, 0.24, -0.02, 0.36, face * CFrame.new(x0, y - 0.18, 0.3), { P.Iron, P.Iron }))
		for k = 1, 3 do
			table.insert(U.Iron, piece("Part", Vector3.new(0.11, 0.11, 0.11), face * CFrame.new(x0 - hs * len * k / 3.4, y, 0.33) * CFrame.Angles(rad(45), rad(45), 0), P.IronWorn))
		end
	end
	if handle then
		local hp = face:PointToObjectSpace(handle.cf.Position)
		table.insert(U.Iron, piece("Part", Vector3.new(0.35, 0.8, 0.06), face * CFrame.new(hp.X, hp.Y, 0.29), P.Iron))
		table.insert(U.Gold, M.frustumN(8, 0.16, 0.12, 0, 0.3, face * CFrame.new(hp.X, hp.Y, 0.3) * CFrame.Angles(rad(90), 0, 0), { handle.color, scaled(handle.color, 1.05) }))
	end
end

-- a window on today's pane (n outward): the glass in 2 colour bands (lighter top) just proud of the wall, thick cross
-- muntins, today's frame and sill as chamfered timbers, 2 plank shutters if there is room (`room` = free width each
-- side), a flower box
local function windowUnit(U: any, rng: Random, pane: any, frames: { any }, sills: { any }, n: Vector3, room: number, flowers: boolean)
	local cf = pane.cf
	local side = Vector3.yAxis:Cross(n).Unit
	local face = CFrame.fromMatrix(cf.Position, side, Vector3.yAxis) -- +Z = outward
	local w, h = pane.size.X, pane.size.Y
	local glass = pane.color
	table.insert(U.Glass, piece("Part", Vector3.new(w, h * 0.55, 0.12), face * CFrame.new(0, h * 0.225, 0.06), glass:Lerp(Color3.new(1, 1, 1), 0.18)))
	table.insert(U.Glass, piece("Part", Vector3.new(w, h * 0.45, 0.12), face * CFrame.new(0, -h * 0.275, 0.06), scaled(glass, 0.9)))
	table.insert(U.Timber, piece("Part", Vector3.new(0.22, h, 0.22), face * CFrame.new(0, 0, 0.17), P.WoodDark))
	table.insert(U.Timber, piece("Part", Vector3.new(w, 0.22, 0.22), face * CFrame.new(0, 0, 0.17), P.WoodDark))
	for _, f in ipairs(frames) do
		table.insert(U.Timber, H.timber(f.size, f.cf, scaled(f.color, rng:NextNumber(0.92, 1.02))))
	end
	for _, s in ipairs(sills) do
		table.insert(U.Timber, chamfered(s.size, s.cf, s.color, { "topFrontBack", "topSides" }, 0.08))
	end
	if room >= 1.4 then
		local sw = math.min(1.9, room - 0.2)
		for _, sx in ipairs({ -1, 1 }) do
			local x = sx * (w / 2 + 0.55 + sw / 2)
			local planks = 3
			for k = 0, planks - 1 do
				local px = x - sw / 2 + sw / planks * (k + 0.5)
				table.insert(U.Shutters, chamfered(Vector3.new(sw / planks - 0.05, h + 0.3, 0.16), face * CFrame.new(px, 0, 0.09), scaled(rgb(168, 98, 56), ({ 1, 0.9, 0.95 })[k + 1]), { "vertical" }, 0.04))
			end
			for _, y in ipairs({ -h * 0.32, h * 0.32 }) do
				table.insert(U.Shutters, piece("Part", Vector3.new(sw - 0.1, 0.3, 0.08), face * CFrame.new(x, y, 0.21), rgb(140, 80, 46)))
			end
			table.insert(U.Shutters, strut(face * Vector3.new(x - sx * (sw / 2 - 0.25), -h * 0.3, 0.21), face * Vector3.new(x + sx * (sw / 2 - 0.25), h * 0.3, 0.21), face.LookVector * -1, 0.24, 0.07, rgb(140, 80, 46)))
			-- hinge straps on the window side
			for _, y in ipairs({ -h * 0.32, h * 0.32 }) do
				table.insert(U.Iron, piece("Part", Vector3.new(0.35, 0.16, 0.1), face * CFrame.new(sx * (w / 2 + 0.55), y, 0.2), P.Iron))
			end
		end
	end
	if flowers and #sills > 0 then
		local s = sills[1]
		local sp = face:PointToObjectSpace(s.cf.Position)
		local bw = w + 0.5
		local by = sp.Y - 0.6
		table.insert(U.Shutters, chamfered(Vector3.new(bw, 0.75, 0.7), face * CFrame.new(0, by, 0.42), rgb(150, 86, 50), { "topFrontBack", "topSides" }, 0.06))
		table.insert(U.Shutters, piece("Part", Vector3.new(bw - 0.2, 0.08, 0.5), face * CFrame.new(0, by + 0.36, 0.42), rgb(84, 52, 34)))
		local FL = { rgb(196, 64, 58), rgb(255, 201, 60), rgb(232, 74, 156), rgb(245, 246, 250) }
		local count = math.floor(bw / 0.55)
		for k = 0, count - 1 do
			local x = -bw / 2 + 0.35 + k * (bw - 0.7) / math.max(count - 1, 1)
			local lh = rng:NextNumber(0.25, 0.45)
			table.insert(U.Plants, M.frustumN(5, 0.24, 0.1, 0, lh, face * CFrame.new(x, by + 0.38, 0.42 + rng:NextNumber(-0.12, 0.12)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), { rgb(88, 150, 66), P.MossDark }))
			if k % 2 == 0 or rng:NextNumber() < 0.4 then
				table.insert(U.Plants, piece("Part", Vector3.new(0.22, 0.22, 0.22), face * CFrame.new(x, by + 0.42 + lh, 0.42) * CFrame.Angles(rad(45), rng:NextNumber(0, 3), rad(45)), FL[(k % #FL) + 1]))
			end
		end
	end
end
-- the whole half-timbered house from its kit rows
local function halfTimber(m: Model, kit: string, o: any)
	local rng = Random.new(o.seed)
	local rows = KD.rows(kit)
	local U: any = { Stone = {}, Plaster = {}, Timber = {}, Roof = {}, Roof2 = {}, RoofDeck = {}, Wood = {}, Iron = {}, Gold = {}, Glass = {}, Lamp = {}, Shutters = {}, Plants = {} }
	local walls = rowsNamed(kit, "Walls")[1]
	local W, D = walls.size.X, walls.size.Z
	local wallTop = walls.cf.Position.Y + walls.size.Y / 2
	local found = rowsNamed(kit, "Foundation")[1]
	local fTop = found.cf.Position.Y + found.size.Y / 2
	local Ht = 0
	for _, r in ipairs(rows) do
		Ht = math.max(Ht, r.cf.Position.Y + r.size.Y / 2)
	end
	local STONE, SDARK = rgb(150, 156, 168), rgb(104, 110, 124)
	-- 1. foundation: 2 courses of cut stone all round (the front / back full width, the sides between)
	local fw, fd, th = found.size.X, found.size.Z, 0.9
	for _, s in ipairs({ -1, 1 }) do
		R.stoneCourses(U.Stone, rng, -fw / 2, fw / 2, 0, fTop, s * (fd / 2 - th / 2), th, fTop / 2, STONE, SDARK, 1)
		R.stoneCourses(U.Stone, rng, -(fd / 2 - th), fd / 2 - th, 0, fTop, s * (fw / 2 - th / 2), th, fTop / 2, STONE, SDARK, 1, CFrame.Angles(0, rad(90), 0))
	end
	table.insert(U.Stone, piece("Part", Vector3.new(fw - 2 * th, fTop - 0.05, fd - 2 * th), CFrame.new(0, (fTop - 0.05) / 2, 0), SDARK))
	-- 2. plaster: the walls in 2 bands (the lower storey a touch darker), the 2 gable wedges
	local rail = nil
	for _, r in ipairs(rowsNamed(kit, "Timber")) do
		local p = r.cf.Position
		if r.size.Y < 1 and p.Y > fTop + 3 and p.Y < wallTop - 2 and (r.size.X > 4 or r.size.Z > 4) then
			rail = rail or p.Y
		end
	end
	local split = rail or (fTop + wallTop) / 2
	local PL = walls.color
	table.insert(U.Plaster, piece("Part", Vector3.new(W, split - fTop, D), CFrame.new(walls.cf.Position.X, (fTop + split) / 2, walls.cf.Position.Z), scaled(PL, 0.94)))
	table.insert(U.Plaster, piece("Part", Vector3.new(W, wallTop - split, D), CFrame.new(walls.cf.Position.X, (split + wallTop) / 2, walls.cf.Position.Z), PL))
	for _, g in ipairs(rowsNamed(kit, "Gable")) do
		local p = Instance.new("WedgePart")
		p.Size, p.CFrame, p.Color, p.Material, p.Anchored = g.size, g.cf, PL, Enum.Material.SmoothPlastic, true
		table.insert(U.Plaster, p)
	end
	-- 3. today's timbers as chamfered beams (tones), pegs at the corner posts, diagonal braces where the walls are free
	for _, r in ipairs(rowsNamed(kit, "Timber")) do
		table.insert(U.Timber, H.timber(r.size, r.cf, graded(scaled(r.color, rng:NextNumber(0.92, 1.04)), r.cf.Position.Y, Ht)))
	end
	for _, r in ipairs(rowsNamed(kit, "DoorFrame")) do
		table.insert(U.Timber, H.timber(r.size, r.cf, scaled(r.color, rng:NextNumber(0.92, 1.0))))
	end
	local faces = {
		{ n = Vector3.new(0, 0, -1), along = Vector3.xAxis, half = W / 2, depth = D / 2 },
		{ n = Vector3.new(0, 0, 1), along = Vector3.xAxis, half = W / 2, depth = D / 2 },
		{ n = Vector3.new(-1, 0, 0), along = Vector3.zAxis, half = D / 2, depth = W / 2 },
		{ n = Vector3.new(1, 0, 0), along = Vector3.zAxis, half = D / 2, depth = W / 2 },
	}
	local bands = { { fTop + 0.6, split } }
	if rail then
		table.insert(bands, { split, wallTop })
	end
	for _, f in ipairs(faces) do
		local ops = openings(rows, f.n, f.along, W, D)
		for _, b in ipairs(bands) do
			local y0, y1 = b[1] + 0.45, b[2] - 0.5
			for _, s in ipairs({ -1, 1 }) do
				local uIn = s * (f.half - 0.6)
				local uOut = uIn - s * math.min(3.0, (y1 - y0) * 0.55)
				local a, bb = math.min(uIn, uOut), math.max(uIn, uOut)
				if not blocked(ops, a - 0.5, bb + 0.5, y0, y1) then
					local pA = f.n * f.depth + f.along * uIn + Vector3.new(0, y1, 0)
					local pB = f.n * f.depth + f.along * uOut + Vector3.new(0, y0, 0)
					table.insert(U.Timber, strut(pA, pB, f.n, 0.75, 0.42, graded(scaled(P.WoodDark, rng:NextNumber(0.9, 1.0)), (y0 + y1) / 2, Ht), true))
				end
			end
		end
		-- pegs where the corner posts meet the top plate and the rail
		for _, s in ipairs({ -1, 1 }) do
			for _, y in ipairs({ wallTop - 0.55, split }) do
				local pos = f.n * (f.depth + 0.35) + f.along * s * (f.half - 0.3) + Vector3.new(0, y, 0)
				table.insert(U.Timber, piece("Part", Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos) * CFrame.Angles(rad(45), rad(45), 0), rgb(70, 38, 24)))
			end
		end
	end
	-- a sole plate on the foundation all round (0.6 tall, 0.15 proud), broken at the door
	do
		local dr = rowsNamed(kit, "Door")[1]
		local dn = wallNormal(dr.cf.Position, W, D)
		for _, f in ipairs(faces) do
			local segs = { { -f.half - 0.15, f.half + 0.15 } }
			if f.n:Dot(dn) > 0.9 then
				local du = dr.cf.Position:Dot(f.along)
				segs = { { -f.half - 0.15, du - 3.4 }, { du + 3.4, f.half + 0.15 } }
			end
			for _, sg in ipairs(segs) do
				if sg[2] - sg[1] > 0.5 then
					local mid = f.along * (sg[1] + sg[2]) / 2 + f.n * (f.depth + 0.075) + Vector3.new(0, fTop + 0.3, 0)
					local size = if math.abs(f.along.X) > 0.5 then Vector3.new(sg[2] - sg[1], 0.6, 0.45) else Vector3.new(0.45, 0.6, sg[2] - sg[1])
					table.insert(U.Timber, H.timber(size, CFrame.new(mid), graded(scaled(P.WoodDark, 0.92), fTop, Ht)))
				end
			end
		end
	end
	-- gable collar beams
	local apex = wallTop
	for _, g in ipairs(rowsNamed(kit, "Gable")) do
		apex = math.max(apex, g.cf.Position.Y + g.size.Y / 2)
	end
	for _, s in ipairs({ -1, 1 }) do
		local yc = wallTop + 3.2
		local halfW = (D / 2) * (apex - yc) / (apex - wallTop) - 0.4
		if halfW > 1 then
			table.insert(U.Timber, H.timber(Vector3.new(0.5, 0.8, 2 * halfW), CFrame.new(s * (W / 2 + 0.05), yc, 0), P.WoodDark))
		end
	end
	-- 4. roof: clay tiles on each slab, a darker ridge cap
	for _, r in ipairs(rowsNamed(kit, "Roof")) do
		tileRoof(U.Roof, U.Roof2, U.RoofDeck, rng, r, r.color, scaled(P.WoodDark, 0.8))
	end
	for _, r in ipairs(rowsNamed(kit, "Ridge")) do
		table.insert(U.Roof, chamfered(r.size + Vector3.new(0, 0.1, 0), r.cf * CFrame.new(0, 0.12, 0), r.color, { "topFrontBack" }, 0.3))
		local n = math.floor(r.size.X / 1.6)
		for k = 0, n - 1 do
			local x = -r.size.X / 2 + (k + 0.5) * r.size.X / n
			table.insert(U.Roof, piece("Part", Vector3.new(0.12, 0.5, 1.5), r.cf * CFrame.new(x, 0.45, 0), scaled(r.color, 0.85)))
		end
	end
	-- 5. chimney: cut stone courses above the roof line, a dark cap slab with a flue
	local roofs = rowsNamed(kit, "Roof")
	for _, ch in ipairs(rowsNamed(kit, "Chimney")) do
		local p, sz = ch.cf.Position, ch.size
		local low = math.huge
		for _, dx in ipairs({ -1, 1 }) do
			for _, dz in ipairs({ -1, 1 }) do
				for _, rr in ipairs(roofs) do
					local y = roofY(rr, p.X + dx * sz.X / 2, p.Z + dz * sz.Z / 2)
					if y < p.Y + sz.Y / 2 then
						low = math.min(low, math.max(y, 0))
					end
				end
			end
		end
		local y0 = math.max(low - 1.2, p.Y - sz.Y / 2)
		local y1 = p.Y + sz.Y / 2
		local fr = CFrame.new(p.X, 0, p.Z)
		local t2 = 0.7
		for _, s in ipairs({ -1, 1 }) do
			R.stoneCourses(U.Stone, rng, -sz.X / 2, sz.X / 2, y0, y1, s * (sz.Z / 2 - t2 / 2), t2, 1.0, ch.color, SDARK, 0, fr)
			R.stoneCourses(U.Stone, rng, -(sz.Z / 2 - t2), sz.Z / 2 - t2, y0, y1, s * (sz.X / 2 - t2 / 2), t2, 1.0, ch.color, SDARK, 0, fr * CFrame.Angles(0, rad(90), 0))
		end
	end
	for _, cap in ipairs(rowsNamed(kit, "ChimneyCap")) do
		table.insert(U.Stone, chamfered(cap.size, cap.cf, cap.color, { "topFrontBack", "topSides" }, 0.18))
		table.insert(U.Stone, piece("Part", Vector3.new(cap.size.X * 0.5, 0.1, cap.size.Z * 0.5), cap.cf * CFrame.new(0, cap.size.Y / 2 + 0.03, 0), rgb(40, 40, 46)))
		table.insert(U.Stone, chamfered(Vector3.new(cap.size.X * 0.62, 0.35, 0.3), cap.cf * CFrame.new(0, cap.size.Y / 2 + 0.17, cap.size.Z * 0.27), scaled(cap.color, 1.1), { "topFrontBack" }, 0.08))
		table.insert(U.Stone, chamfered(Vector3.new(cap.size.X * 0.62, 0.35, 0.3), cap.cf * CFrame.new(0, cap.size.Y / 2 + 0.17, -cap.size.Z * 0.27), scaled(cap.color, 1.1), { "topFrontBack" }, 0.08))
	end
	-- 6. door with a small tiled canopy, the step, the windows
	local handle = rowsNamed(kit, "Handle")[1]
	local doorRow = rowsNamed(kit, "Door")[1]
	local doorN = wallNormal(doorRow.cf.Position, W, D)
	plankDoor(U, rng, doorRow, doorN, handle)
	-- the canopy only where there is room under the eaves (3.5 over the door top: the two-storey house)
	if wallTop - (doorRow.cf.Position.Y + doorRow.size.Y / 2) >= 3.5 then
		local side = Vector3.yAxis:Cross(doorN).Unit
		local dp = doorRow.cf.Position
		local wallFace = if math.abs(doorN.X) > 0.5 then W / 2 else D / 2
		local face = CFrame.fromMatrix(dp - doorN * (dp:Dot(doorN) - wallFace), side, Vector3.yAxis) -- +Z out, on the wall
		local yTop = doorRow.size.Y / 2 + 1.55
		local roofColor = rowsNamed(kit, "Roof")[1].color
		local slope = rad(28)
		local depth = 2.1
		local board = face * CFrame.new(0, yTop, 0) * CFrame.Angles(-slope, 0, 0) * CFrame.new(0, 0, depth / 2)
		table.insert(U.RoofDeck, piece("Part", Vector3.new(7.2, 0.18, depth), board, scaled(P.WoodDark, 0.85)))
		for row = 0, 1 do
			local z = -depth / 2 + 0.55 + row * 0.95
			local xx = -3.6 - (if row == 1 then 0.6 else 0)
			while xx < 3.55 do
				local a, b = math.max(xx, -3.6), math.min(xx + 1.2, 3.6)
				if b - a > 0.3 then
					table.insert(U.Roof, piece("Part", Vector3.new(b - a - 0.07, 0.12, 1.2), board * CFrame.new((a + b) / 2, 0.15, z) * CFrame.Angles(rad(-4), 0, 0), scaled(roofColor, rng:NextNumber(0.86, 1.0))))
				end
				xx += 1.2
			end
		end
		table.insert(U.Roof, piece("Part", Vector3.new(7.3, 0.22, 0.4), board * CFrame.new(0, 0.2, -depth / 2 + 0.15), scaled(roofColor, 0.8)))
		for _, sx in ipairs({ -1, 1 }) do
			-- a bracket wedge: its vertical face on the wall, its flat top under the canopy, sloping down and out
			local w = Instance.new("WedgePart")
			w.Size = Vector3.new(0.45, 1.4, 1.5)
			local top = face * Vector3.new(sx * 3.2, yTop - 0.1, 0)
			w.CFrame = CFrame.fromMatrix(top + doorN * 0.75 - Vector3.new(0, 0.7, 0), Vector3.yAxis:Cross(-doorN).Unit, Vector3.yAxis, -doorN) * CFrame.Angles(0, 0, math.pi)
			w.Color = P.WoodDark
			w.Material = Enum.Material.SmoothPlastic
			w.Anchored = true
			table.insert(U.Timber, w)
		end
	end
	for _, st in ipairs(rowsNamed(kit, "Step")) do
		local p, sz = st.cf.Position, st.size
		local side = Vector3.yAxis:Cross(doorN).Unit
		local face = CFrame.fromMatrix(p, side, Vector3.yAxis)
		local n = 3
		local bw = sz.X / n
		for k = 0, n - 1 do
			local negs = {}
			if k == 1 then -- the worn middle: a shallow scoop on the front top edge
				table.insert(negs, piece("Part", Vector3.new(bw * 0.8, 0.5, 0.5), face * CFrame.new(0, sz.Y / 2, sz.Z / 2) * CFrame.Angles(rad(45), 0, 0), st.color))
			end
			table.insert(U.Stone, chamfered(Vector3.new(bw - 0.08, sz.Y, sz.Z), face * CFrame.new(-sz.X / 2 + bw * (k + 0.5), 0, 0), scaled(st.color, ({ 1, 0.92, 0.97 })[k + 1]), { "topFrontBack", "topSides" }, 0.18, negs))
		end
	end
	local frames, sills = rowsNamed(kit, "WindowFrame"), rowsNamed(kit, "WindowSill")
	for _, pane in ipairs(rowsNamed(kit, "Window")) do
		local n = wallNormal(pane.cf.Position, W, D)
		local mine, mySills = {}, {}
		for _, f in ipairs(frames) do
			if (f.cf.Position - pane.cf.Position).Magnitude < 3.5 then
				table.insert(mine, f)
			end
		end
		for _, s in ipairs(sills) do
			if (s.cf.Position - pane.cf.Position).Magnitude < 3 then
				table.insert(mySills, s)
			end
		end
		-- free room beside the frame for the shutters (corner posts, other openings)
		local along = if math.abs(n.X) > 0.5 then Vector3.zAxis else Vector3.xAxis
		local half = if math.abs(n.X) > 0.5 then D / 2 else W / 2
		local u = pane.cf.Position:Dot(along)
		local others = openings(rows, n, along, W, D)
		local room = math.huge
		for _, sgn in ipairs({ -1, 1 }) do
			local edge = u + sgn * 2.55
			local lim = sgn * (half - 0.7) -- the corner post
			local free = (lim - edge) * sgn
			for _, op in ipairs(others) do
				if math.abs((op[1] + op[2]) / 2 - u) > 0.5 and pane.cf.Position.Y + 2 > op[3] and pane.cf.Position.Y - 2 < op[4] then
					local near = if sgn > 0 then op[1] else op[2]
					if (near - edge) * sgn > -0.1 then
						free = math.min(free, (near - edge) * sgn)
					end
				end
			end
			room = math.min(room, free - 0.55)
		end
		windowUnit(U, rng, pane, mine, mySills, n, room, n:Dot(doorN) > 0.9 and (pane.cf.Position.Y < 12 or o.upperFlowers == true))
	end
	-- 7. a wall lantern beside the door (the side away from the handle if free), moss at the foundation corners
	do
		local side = Vector3.yAxis:Cross(doorN).Unit
		local face = CFrame.fromMatrix(doorRow.cf.Position, side, Vector3.yAxis)
		local hp = face:PointToObjectSpace(handle.cf.Position)
		local sx = if hp.X > 0 then 1 else -1
		local axis = if math.abs(doorN.X) > 0.5 then Vector3.zAxis else Vector3.xAxis
		local ops = openings(rows, doorN, axis, W, D)
		local wallFace = (if math.abs(doorN.X) > 0.5 then W / 2 else D / 2)
		local base = doorRow.cf.Position * Vector3.new(1, 0, 1) + Vector3.new(0, doorRow.cf.Position.Y + 2.3, 0)
		local du = doorRow.cf.Position:Dot(axis)
		local others = {}
		for _, op in ipairs(ops) do
			if not (op[1] < du and op[2] > du) then
				table.insert(others, op)
			end
		end
		local chosen = nil
		for _, sgn in ipairs({ -sx, sx }) do
			local at = base + side * sgn * (doorRow.size.X / 2 + 1.35)
			local u = at:Dot(axis)
			if not blocked(others, u - 1.2, u + 1.2, at.Y - 1.5, at.Y + 1.5) then
				chosen = at
				break
			end
		end
		if chosen then
			chosen = chosen - doorN * (chosen:Dot(doorN) - wallFace)
			wallLantern(U.Iron, U.Lamp, chosen, doorN, 1)
		end
	end
	for _, c in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
		if rng:NextNumber() < 0.75 then
			local pos = Vector3.new(c[1] * (found.size.X / 2 + 0.15), 0, c[2] * (found.size.Z / 2 - 1.6))
			footMoss(U.Plants, rng, pos, Vector3.zAxis, rng:NextNumber(1.8, 2.6))
		end
	end
	if o.extra then
		o.extra(U, rng, rows, W, D)
	end
	finishB4(m, o.id, U, "Plaster", { Lamp = { material = Enum.Material.Neon, shadow = false } })
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("PartOperation") then
			p.CanQuery = p.Name == "Plaster"
		end
	end
	-- the game copies' colliders (Data.<kit>_game: they differ from the kits by 0.06 .. 0.17 after an earlier window fix)
	kitCollision(m, if KD[kit .. "_game"] then kit .. "_game" else kit)
end
B4.halfTimber = halfTimber

-- 01 COTTAGE, RED ROOF, ONE WINDOW (kit MapAssets.Plains.FarmHouse: foundation 29 x 1.6 x 23, walls 28 x 12 x 22 white
-- plaster #F0E4C8, a dark #703E26 timber frame, red roof #C4403A at 45 deg, ridge 25.5, stone chimney with a cap, a
-- door 6 x 9 with a gold handle, a stone step, 5 windows 4 x 4 (one on the front); 3 copies: test, kit,
-- Plains_1.Decor.Farm; 73 parts, every one colliding except the window bars, frames and sills; no NPC / prompt)
-- The cottage (owner: half-timbered, white plaster walls with a visible timber frame - beams with joints, diagonal
-- braces -, a stone block foundation, a red tiled roof with individual tiles, overhanging eaves, a ridge cap, a stone
-- chimney with a cap, a window with a cross frame, shutters and a flower box, a plank door with hinges and today's
-- handle, a stone step with a worn edge, a lantern by the door). Parts: Plaster, Timber, Roof, Roof2, RoofDeck, Stone, Wood,
-- Iron, Gold, Glass, Lamp, Shutters, Plants, Collision x(today's colliding parts).
function B4.cottage_one_window(): Model
	local m = Instance.new("Model")
	m.Name = "cottage_one_window"
	H.setBevelSelf(true)
	halfTimber(m, "FarmHouse", { id = "cottage_one_window", seed = 20261402 })
	return m
end

---------------------------------------------------------------------
-- more shared helpers (batch 4 props)
---------------------------------------------------------------------
local FAC = require(ServerStorage.DevTools.PropsBatch4Facets:Clone()) :: any -- Agent A's batch4 facet pieces (D6)
local ROPE = rgb(196, 160, 104) -- #C4A068
local LEATHER = rgb(74, 48, 34) -- #4A3022

-- a carved bracket under a beam or a canopy: a wedge whose vertical face is on the wall (normal n) and whose flat top
-- is at `top` (a point on the wall face), sloping down and outward
local function bracketWedge(list: { BasePart }, top: Vector3, n: Vector3, w: number, h: number, d: number, color: Color3)
	local back = -n
	local X = Vector3.yAxis:Cross(back).Unit
	local p = Instance.new("WedgePart")
	p.Size = Vector3.new(w, h, d)
	p.CFrame = CFrame.fromMatrix(top + n * (d / 2) - Vector3.new(0, h / 2, 0), X, Vector3.yAxis, back) * CFrame.Angles(0, 0, math.pi)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	table.insert(list, p)
end

-- a frame whose Y axis runs along `axis` (unit), at pos
local function alongY(pos: Vector3, axis: Vector3): CFrame
	local helper = if math.abs(axis.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local x = helper:Cross(axis).Unit
	return CFrame.fromMatrix(pos, x, axis)
end

-- a ring of rope / iron (n-gon band) around an axis: centre pos, axis (unit), radius r, height h
local function ring(list: { BasePart }, pos: Vector3, axis: Vector3, r: number, h: number, color: Color3, n: number?)
	table.insert(list, M.frustumN(n or 8, r, r, -h / 2, h / 2, alongY(pos, axis), { color, scaled(color, 0.9) }))
end

-- a small grass tuft of `count` thin wedge blades around pos (decor, never colliding)
local function tuft(list: { BasePart }, rng: Random, pos: Vector3, size: number, count: number?)
	local n = count or 4
	for k = 1, n do
		local h = size * rng:NextNumber(0.8, 1.3)
		local blade = Instance.new("WedgePart")
		blade.Size = Vector3.new(0.08, h, 0.3 * size)
		blade.CFrame = CFrame.new(pos) * CFrame.Angles(0, k * 2 * math.pi / n + rng:NextNumber(-0.3, 0.3), 0) * CFrame.new(0, -0.05, 0.12 * size) * CFrame.Angles(rad(rng:NextNumber(10, 24)), 0, 0) * CFrame.new(0, h / 2, 0)
		blade.Color = scaled(({ P.Moss, rgb(120, 190, 80), P.MossDark })[(k % 3) + 1], rng:NextNumber(0.92, 1.05))
		blade.Material = Enum.Material.SmoothPlastic
		blade.Anchored = true
		table.insert(list, blade)
	end
end

-- a nail / rivet head (a turned cube) at pos
local function nail(list: { BasePart }, pos: Vector3, s: number?)
	local k = s or 0.12
	table.insert(list, piece("Part", Vector3.new(k, k, k), CFrame.new(pos) * CFrame.Angles(rad(45), rad(45), 0), P.Iron))
end

-- a faceted ball (2 octagonal cones) of radius r at pos
local function knob(list: { BasePart }, pos: Vector3, r: number, color: Color3)
	table.insert(list, M.frustumN(8, r * 0.55, r, -r, 0, CFrame.new(pos), { scaled(color, 0.92), color }))
	table.insert(list, M.frustumN(8, r, r * 0.45, 0, r * 0.85, CFrame.new(pos), { color, scaled(color, 1.05) }))
end

-- Agent A's facets with each palette colour routed to a list: route(hex) returns the list name (a cloth's red tones
-- go to single-colour unions Cloth1, Cloth2 ... so the _Variants can recolour the copies whose cloth is another colour)
local function facetsSplit(U: any, data: any, sc: Vector3, frame: CFrame, route: (string) -> string)
	local ts = math.min(sc.X, sc.Y, sc.Z)
	local colors, lists = {}, {}
	for i, entry in ipairs(data.palette) do
		local hex = string.match(entry, "^(#%x+)") :: string
		colors[i] = Color3.fromHex(hex)
		local dest = route(string.upper(hex))
		U[dest] = U[dest] or {}
		lists[i] = U[dest]
	end
	for _, t in ipairs(data.tris) do
		local a = Vector3.new(t[1], t[2], t[3]) * sc
		local b = Vector3.new(t[4], t[5], t[6]) * sc
		local c = Vector3.new(t[7], t[8], t[9]) * sc
		H.triangleParts(lists[t[11]], a, b, c, t[10] * ts, frame, colors[t[11]])
	end
end

-- the cloth tone unions (Cloth1..n = the red tones `tones`, hex) as single-colour unions, and a _Variants folder with
-- one Configuration per other cloth colour of today's copies ("Cloth_<HEX>": each tone = the colour x its tone ratio)
local function clothVariants(m: Model, tones: { string }, others: { string }): any
	local base = Color3.fromHex("#D4343C")
	local opts = {}
	for i, hex in ipairs(tones) do
		opts["Cloth" .. i] = { single = Color3.fromHex(hex) }
	end
	local folder = Instance.new("Folder")
	folder.Name = "_Variants"
	for _, other in ipairs(others) do
		local config = Instance.new("Configuration")
		config.Name = "Cloth_" .. other
		local target = Color3.fromHex("#" .. other)
		for i, hex in ipairs(tones) do
			local c = Color3.fromHex(hex)
			config:SetAttribute("Color_Cloth" .. i, scaled(target, (c.R + c.G + c.B) / (base.R + base.G + base.B)))
		end
		config.Parent = folder
	end
	folder.Parent = m
	return opts
end

-- a climbing vine on a wall: a stem zigzagging down from `top` along the wall (normal n) with small diamond leaves
local function wallVine(list: { BasePart }, rng: Random, top: Vector3, n: Vector3, length: number)
	local side = Vector3.yAxis:Cross(n).Unit
	local p = top + n * 0.12
	local leafCols = { P.Moss, P.MossDark, rgb(120, 190, 80) }
	local y = 0
	local k = 0
	while y < length do
		local step = rng:NextNumber(0.9, 1.4)
		local q = p - Vector3.new(0, step, 0) + side * rng:NextNumber(-0.5, 0.5)
		table.insert(list, H.bar(p, q, 0.1, rgb(84, 110, 50)))
		for _, sgn in ipairs({ -1, 1 }) do
			if rng:NextNumber() < 0.8 then
				local c = p:Lerp(q, rng:NextNumber(0.2, 0.8)) + side * sgn * 0.3 + n * 0.05
				table.insert(list, piece("Part", Vector3.new(0.55, 0.42, 0.05), CFrame.fromMatrix(c, side, Vector3.yAxis) * CFrame.Angles(0, 0, rad(45 + sgn * 15)), scaled(leafCols[(k % 3) + 1], rng:NextNumber(0.92, 1.05))))
				k += 1
			end
		end
		p = q
		y += step
	end
end

---------------------------------------------------------------------
-- 02 COTTAGE, RED ROOF, TWO WINDOWS (kit MapAssets.Hub.Cottage_A: foundation 23 x 1.6 x 19, walls 22 x 11 x 18, red roof
-- 25.6 x 15.23 at 45 deg, ridge 22.5, door centred, 2 front windows at x +-7, 1 window per side, chimney at (-6, 19.6,
-- 4.5); 5 copies: test, kit, Hub.Decor.Village x3; 65 parts; no NPC / prompt)
-- The same cottage recipe as 01 (guide D2), with a climbing vine on the front left corner and a second one at the back.
-- Parts: as 01 (+ the vines in Plants).
function B4.cottage_two_windows(): Model
	local m = Instance.new("Model")
	m.Name = "cottage_two_windows"
	H.setBevelSelf(true)
	halfTimber(m, "Cottage_A", { id = "cottage_two_windows", seed = 20261403, extra = function(U, rng, rows, W, D)
		wallVine(U.Plants, rng, Vector3.new(-W / 2 + 1.2, 11.6, -D / 2 - 0.25), Vector3.new(0, 0, -1), 6.5)
		wallVine(U.Plants, rng, Vector3.new(W / 2 - 1.4, 11.6, D / 2 + 0.25), Vector3.new(0, 0, 1), 8)
	end })
	return m
end

-- 03 TWO-STOREY HOUSE, BLUE ROOF (kit MapAssets.Hub.Cottage_B: foundation 21 x 1.6 x 19, walls 20 x 19 x 18 (2 storeys
-- in one block, the floor rail at y 11.1), blue roof #4078D4 23.6 x 15.95 at 48 deg, ridge 31.5, door at x -4, ground
-- window at x 5, 2 upper front windows at y 16.1, 1 window per side per floor, chimney at (6, 28.1, 4.5); 4 copies:
-- test, kit, Hub.Decor.Village x2; 76 parts; no NPC / prompt)
-- The same recipe (guide D2) with blue tiles, the jetty of the upper floor shown by a row of joist ends and carved
-- brackets along the floor rail on the front and the sides, flower boxes under the 2 upper front windows too.
-- Parts: as 01.
function B4.house_blue_roof(): Model
	local m = Instance.new("Model")
	m.Name = "house_blue_roof"
	H.setBevelSelf(true)
	halfTimber(m, "Cottage_B", { id = "house_blue_roof", seed = 20261404, upperFlowers = true, extra = function(U, rng, rows, W, D)
		local floorY = 11.1 - 0.45
		local fronts = {
			{ n = Vector3.new(0, 0, -1), along = Vector3.xAxis, half = W / 2, depth = D / 2 },
			{ n = Vector3.new(-1, 0, 0), along = Vector3.zAxis, half = D / 2, depth = W / 2 },
			{ n = Vector3.new(1, 0, 0), along = Vector3.zAxis, half = D / 2, depth = W / 2 },
		}
		for _, f in ipairs(fronts) do
			local ops = openings(rows, f.n, f.along, W, D)
			local u = -f.half + 1.6
			while u < f.half - 1.5 do
				local top = f.n * (f.depth + 0.25) + f.along * u + Vector3.new(0, floorY, 0)
				-- joist end (every 1.4) and a bracket under every other one
				table.insert(U.Timber, chamfered(Vector3.new(0.42, 0.42, 0.42), CFrame.fromMatrix(top + f.n * 0.2 + Vector3.new(0, 0.62, 0), f.along, Vector3.yAxis), rgb(128, 78, 48), { "vertical" }, 0.06))
				if not blocked(ops, u - 0.5, u + 0.5, floorY - 1.4, floorY) and math.floor((u + f.half) / 1.4 + 0.5) % 2 == 0 then
					bracketWedge(U.Timber, top - f.n * 0.25, f.n, 0.45, 1.1, 0.7, scaled(P.WoodDark, rng:NextNumber(0.9, 1.0)))
				end
				u += 1.4
			end
		end
	end })
	return m
end

---------------------------------------------------------------------
-- 03 LADDER (kit MapAssets.Common.Ladder_A: 2 Rails 0.5 x 10 x 0.5 at x +-1.4, 6 Rungs 2.6 x 0.3 x 0.3 at y 1.3 .. 8.8
-- every 1.5, all colliding, plain Parts (no TrussPart, no script); 3 copies: test, kit, Plains_4.Decor.Mine)
---------------------------------------------------------------------
-- The ladder (guide D4): rails with bevelled tops and chamfered long edges (#703E26 tones, a crack on one rail), the 6
-- rungs at today's heights (#A86238, chamfered, the 3 lowest a touch lighter: worn), each set into the rails through a
-- darker mortise plate with a peg head outside. Today's 8 parts stay the exact colliders (the climbing is unchanged).
-- Parts: Wood, Pegs, Collision x8.
function B4.ladder(): Model
	local m = Instance.new("Model")
	m.Name = "ladder"
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Pegs = {} }
	for i, r in ipairs(rowsNamed("Ladder_A", "Rail")) do
		table.insert(U.Wood, chamfered(r.size, r.cf, scaled(r.color, if i == 1 then 1 else 0.92), { "vertical", "topFrontBack", "topSides" }, 0.1))
		if i == 1 then
			table.insert(U.Wood, piece("Part", Vector3.new(0.06, 1.6, 0.04), r.cf * CFrame.new(0.05, 1.8, -r.size.Z / 2 - 0.01) * CFrame.Angles(0, 0, rad(6)), scaled(r.color, 0.55)))
		end
	end
	for k, r in ipairs(rowsNamed("Ladder_A", "Rung")) do
		local wear = if r.cf.Position.Y < 5 then 1.06 else 1
		table.insert(U.Wood, chamfered(Vector3.new(r.size.X - 0.04, 0.33, 0.33), r.cf, scaled(r.color, wear * ({ 1, 0.94, 0.88 })[(k % 3) + 1]), { "topFrontBack", "bottomFrontBack" }, 0.08))
		for _, sx in ipairs({ -1, 1 }) do
			local railX = sx * 1.4
			local p = r.cf.Position
			table.insert(U.Wood, piece("Part", Vector3.new(0.5, 0.45, 0.05), CFrame.new(railX, p.Y, -0.27), scaled(P.WoodDark, 0.75)))
			nail(U.Pegs, Vector3.new(railX + sx * 0.27, p.Y, 0), 0.16)
		end
	end
	finishB4(m, "ladder", U, "Wood")
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("PartOperation") then
			p.CanQuery = false
		end
	end
	kitCollision(m, "Ladder_A")
	return m
end

---------------------------------------------------------------------
-- 04 FENCE SECTION (kit MapAssets.Common.Fence_Section: 2 Posts 0.9 x 4 x 0.9 at x +-3.5, 2 Rails 8 x 0.7 x 0.4 at y
-- 1.4 / 3.0, ends at x +-4; 16 copies: test, kit, Plains_1.Decor.Farm x14 laid end to end every 8)
---------------------------------------------------------------------
-- The fence section (guide D4): the posts with chamfered edges and a pyramid cap (0.15 overhang, #A86238), 2 nails where
-- each rail meets a post, a rope lashing on one post; each rail as 2 boards with a scarf joint at x 0 (a 0.03 step, 2
-- pegs), a slight tilt and tone steps, the rail ends still at x +-4; grass tufts at the post feet. Today's 4 parts stay
-- the exact colliders (every line still joins). Parts: Wood, Iron, Plants, Collision x4.
function B4.fence_section(): Model
	local m = Instance.new("Model")
	m.Name = "fence_section"
	local rng = Random.new(20261406)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Iron = {}, Plants = {} }
	for i, r in ipairs(rowsNamed("Fence_Section", "Post")) do
		local p = r.cf.Position
		table.insert(U.Wood, chamfered(r.size - Vector3.new(0, 0.2, 0), r.cf * CFrame.new(0, -0.1, 0), graded(scaled(r.color, if i == 1 then 1 else 0.93), 2, 4), { "vertical" }, 0.12))
		table.insert(U.Wood, M.frustumN(4, 0.75, 0.12, 0, 0.42, CFrame.new(p.X, 3.8, p.Z) * CFrame.Angles(0, rad(45), 0), { P.WoodMid, scaled(P.WoodMid, 0.9) }))
		tuft(U.Plants, rng, Vector3.new(p.X + 0.35, 0, p.Z - 0.4), 0.55, 4)
		if i == 1 then
			for _, y in ipairs({ 2.15, 2.32 }) do
				ring(U.Iron, Vector3.new(p.X, y, p.Z), Vector3.yAxis, 0.52, 0.12, ROPE)
			end
		end
	end
	for j, r in ipairs(rowsNamed("Fence_Section", "Rail")) do
		local p, s = r.cf.Position, r.size
		for _, sx in ipairs({ -1, 1 }) do
			local len = s.X / 2 + 0.2
			local cx = sx * (s.X / 2 - len / 2)
			local dy = if sx < 0 then 0 else 0.03
			table.insert(U.Wood, chamfered(Vector3.new(len, s.Y - 0.06 - dy, s.Z), CFrame.new(cx, p.Y + dy / 2, p.Z) * CFrame.Angles(0, 0, rad(sx * (if j == 1 then 0.6 else -0.5))), scaled(r.color, ({ 1, 0.93, 0.87, 0.96 })[(j * 2 + sx + 2) % 4 + 1]), { "topFrontBack", "bottomFrontBack" }, 0.08))
			nail(U.Iron, Vector3.new(sx * 3.5 - sx * 0.15, p.Y + 0.15, p.Z - s.Z / 2 - 0.02))
			nail(U.Iron, Vector3.new(sx * 3.5 + sx * 0.15, p.Y - 0.15, p.Z - s.Z / 2 - 0.02))
		end
		nail(U.Iron, Vector3.new(-0.12, p.Y, p.Z - s.Z / 2 - 0.02), 0.1)
		nail(U.Iron, Vector3.new(0.12, p.Y, p.Z - s.Z / 2 - 0.02), 0.1)
	end
	finishB4(m, "fence_section", U, "Wood", { Plants = { shadow = false } })
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("PartOperation") then
			p.CanQuery = false
		end
	end
	kitCollision(m, "Fence_Section")
	return m
end

---------------------------------------------------------------------
-- 06 WOODEN POST (kit MapAssets.Common.Fence_Post: Post 1.0 x 4.2 x 1.0, Cap 1.3 x 0.4 x 1.3 at y 4.4; 8 copies: test,
-- kit, Plains_1.Decor.Farm x6 (one an empty model with no part: deleted))
---------------------------------------------------------------------
-- The wooden post (guide D4): the post chamfered with 2 dark cracks and 3 nails, today's cap bevelled with a low pyramid,
-- a rope wrap of 3 turns at y 3.2 with a hanging end, a chamfered stone footing (1.4 wide) and 2 grass tufts. Today's 2
-- parts stay the exact colliders. Parts: Wood, Stone, Iron, Plants, Collision x2.
function B4.wooden_post(): Model
	local m = Instance.new("Model")
	m.Name = "wooden_post"
	local rng = Random.new(20261407)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Stone = {}, Iron = {}, Plants = {} }
	local post = rowsNamed("Fence_Post", "Post")[1]
	local cap = rowsNamed("Fence_Post", "Cap")[1]
	table.insert(U.Wood, chamfered(post.size - Vector3.new(0, 0.3, 0), post.cf * CFrame.new(0, 0.15, 0), graded(post.color, 2.4, 4.6), { "vertical" }, 0.14))
	for _, c in ipairs({ { -0.2, 1.8, 1.4 }, { 0.25, 3.0, 0.9 } }) do
		table.insert(U.Wood, piece("Part", Vector3.new(0.06, c[3], 0.04), CFrame.new(c[1], c[2], -0.51) * CFrame.Angles(0, 0, rad(4)), scaled(post.color, 0.5)))
	end
	for _, y in ipairs({ 1.2, 2.6, 3.7 }) do
		nail(U.Iron, Vector3.new(rng:NextNumber(-0.25, 0.25), y, -0.52))
	end
	table.insert(U.Wood, chamfered(cap.size, cap.cf, cap.color, { "vertical", "topFrontBack", "topSides" }, 0.1))
	table.insert(U.Wood, M.frustumN(4, 0.62, 0.1, cap.cf.Position.Y + cap.size.Y / 2 - 0.01, cap.cf.Position.Y + cap.size.Y / 2 + 0.22, CFrame.Angles(0, rad(45), 0), { scaled(cap.color, 1.04), cap.color }))
	for k = 0, 2 do
		ring(U.Wood, Vector3.new(0, 3.05 + k * 0.15, 0), Vector3.new(0, 1, 0.08 * (k - 1)).Unit, 0.58, 0.12, scaled(ROPE, ({ 1, 0.92, 0.97 })[k + 1]))
	end
	table.insert(U.Wood, H.bar(Vector3.new(0.45, 3.05, -0.42), Vector3.new(0.6, 2.3, -0.55), 0.12, ROPE))
	table.insert(U.Stone, chamfered(Vector3.new(1.4, 0.3, 1.4), CFrame.new(0, 0.15, 0), rgb(150, 156, 168), { "topFrontBack", "topSides" }, 0.1))
	tuft(U.Plants, rng, Vector3.new(0.55, 0.2, -0.55), 0.5, 4)
	tuft(U.Plants, rng, Vector3.new(-0.6, 0.2, 0.5), 0.45, 3)
	finishB4(m, "wooden_post", U, "Wood", { Plants = { shadow = false } })
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("PartOperation") then
			p.CanQuery = false
		end
	end
	kitCollision(m, "Fence_Post")
	return m
end

---------------------------------------------------------------------
-- 05 SIGN BOARD (kit MapAssets.Common.Signpost_A: Post 0.8 x 6.5, Board 5.5 x 2.6 x 0.4 #D6965C at (0, 5, -0.6), 2 trim
-- Parts 5.9 x 0.4 x 0.5 #A86238; 10 copies: test, kit, the hub AFK corner ("AFK Zone"), the "Hub" signs of Plains_1,
-- Desert_1 (front + back), Jungle_1, Tundra_1, Volcano_1, Abyss_1, Void_1; the texts are SurfaceGuis on the Board)
---------------------------------------------------------------------
-- The sign board (guide D4): 3 horizontal planks with gaps in a frame of 4 chamfered trims (today's 2 + 2 sides), nail
-- heads, 4 iron corner plates; the post chamfered with a pyramid cap on a 2-block stone footing. The GUI carrier: an
-- invisible part named Board exactly where today's Board is (the sync moves each copy's SurfaceGuis onto it; its front
-- face lies 0.02 in front of the planks so the texts show as before). Today's 4 parts stay the exact colliders.
-- Parts: Wood, Stone, Iron, Board (invisible), Collision x4.
local function signModel(id: string, pal: any): Model
	local m = Instance.new("Model")
	m.Name = id
	local rng = Random.new(20261408)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Stone = {}, Iron = {} }
	local post = rowsNamed("Signpost_A", "Post")[1]
	local board = rowsNamed("Signpost_A", "Board")[1]
	table.insert(U.Wood, chamfered(post.size - Vector3.new(0, 0.5, 0), post.cf * CFrame.new(0, 0.05, 0), graded(pal.post, 3, 6.6), { "vertical" }, 0.12))
	table.insert(U.Wood, M.frustumN(4, 0.6, 0.1, 6.24, 6.7, CFrame.Angles(0, rad(45), 0), { scaled(pal.post, 1.05), pal.post }))
	local bp, bs = board.cf.Position, board.size
	local front = bp.Z - bs.Z / 2
	for k = 0, 2 do
		local h = bs.Y / 3
		-- (front 0.04 behind the carrier's front, back 0.06 inside its back: both faces can carry a GUI)
		table.insert(U.Wood, chamfered(Vector3.new(bs.X, h - 0.06, bs.Z - 0.1), CFrame.new(bp.X, bp.Y - bs.Y / 2 + h * (k + 0.5), bp.Z - 0.03), scaled(pal.board, ({ 1, 0.93, 0.97 })[k + 1]), { "topFrontBack", "bottomFrontBack" }, 0.05))
	end
	table.insert(U.Wood, piece("Part", Vector3.new(bs.X - 0.2, bs.Y - 0.2, 0.06), CFrame.new(bp.X, bp.Y, bp.Z + bs.Z / 2 - 0.08), scaled(pal.board, 0.55)))
	for _, r in ipairs(rowsNamed("Signpost_A", "Part")) do
		table.insert(U.Wood, chamfered(r.size, r.cf, pal.trim, { "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }, 0.08))
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Wood, chamfered(Vector3.new(0.4, bs.Y + 0.4, 0.5), CFrame.new(sx * (bs.X / 2 + 0.05), bp.Y, bp.Z), scaled(pal.trim, 0.95), { "vertical" }, 0.08))
		for _, y in ipairs({ -1, 1 }) do
			table.insert(U.Iron, piece("Part", Vector3.new(0.5, 0.12, 0.06), CFrame.new(sx * (bs.X / 2 - 0.05), bp.Y + y * (bs.Y / 2 + 0.05), front - 0.3), P.Iron))
			nail(U.Iron, Vector3.new(sx * (bs.X / 2 + 0.05), bp.Y + y * (bs.Y / 2 - 0.35), front - 0.28))
			nail(U.Iron, Vector3.new(sx * (bs.X / 2 - 1.4), bp.Y + y * (bs.Y / 2 + 0.2), front - 0.28))
		end
	end
	for k = 0, 1 do
		table.insert(U.Stone, chamfered(Vector3.new(0.78, 0.45, 1.5), CFrame.new(-0.4 + k * 0.8, 0.225, 0), scaled(rgb(150, 156, 168), ({ 1, 0.9 })[k + 1]), { "topFrontBack", "topSides" }, 0.12))
	end
	tuft(U.Wood, rng, Vector3.new(0.9, 0.1, 0.5), 0.5, 3)
	finishB4(m, id, U, "Wood")
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("PartOperation") then
			p.CanQuery = false
		end
	end
	-- the GUI carrier (the texts of the copies land on its Front face)
	local carrier = piece("Part", bs, board.cf * CFrame.new(0, 0, -0.02), board.color)
	carrier.Name = "Board"
	carrier.Transparency = 1
	carrier.CanCollide = false
	carrier.CanQuery = false
	carrier.CanTouch = false
	carrier.CastShadow = false
	carrier.Parent = m
	kitCollision(m, "Signpost_A")
	return m
end

function B4.sign_board(): Model
	return signModel("sign_board", { board = rgb(214, 150, 92), trim = rgb(168, 98, 56), post = rgb(112, 62, 38) })
end

-- the Tundra_1 "Hub" sign is in dark wood today (Board #997660, trims and post #5C4236): the same sign in those colours
function B4.sign_board_dark(): Model
	return signModel("sign_board_dark", { board = rgb(153, 118, 96), trim = rgb(92, 66, 54), post = rgb(92, 66, 54) })
end

---------------------------------------------------------------------
-- 07 BANNER, RED DIAMOND (kit MapAssets.Common.Banner_A: stone Foot 1.4 x 0.6, Pole 0.6 x 13, Crossbar 5.6 at y 12.4,
-- red Cloth 4.6 x 7 with 2 tail wedges and a gold diamond Emblem, a gold Finial ball 0.9; all 8 parts collide; 11
-- copies: test, kit, Hub Decor.Props.Flags x6, AltarBackdrop x3 (scale 1.5 / 1.5 / 1.9); static, no PropFX)
---------------------------------------------------------------------
-- The banner (guide D4 / D6): Agent A's banner cloth (folds, zigzag gold-trimmed lower edge, the stitched gold diamond,
-- today's red) at the kit pivot; the crossbar as a chamfered beam with carved end knobs, a rope X-lashing at the pole
-- and 5 rope loops holding the sleeve; an octagonal pole with 2 carved rings; today's gold finial as a faceted ball on a
-- collar; today's stone foot as a 2-step chamfered base. Today's 8 parts stay the exact colliders. The cloth's 4 red
-- tones are single-colour unions: the _Variants recolour the blue (#4A6CDC x3), purple (#966EFF) and gold (#FFC93C x2)
-- copies (rule variant = "Cloth_<hex>" of today's Cloth). Parts: Cloth1-4, Trim, Wood, Stone, Gold, Collision x8.
function B4.banner_diamond(): Model
	local m = Instance.new("Model")
	m.Name = "banner_diamond"
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Stone = {}, Gold = {} }
	local TONES_B = { "#AA2A30", "#D4343C", "#832025", "#B62D34" }
	facetsSplit(U, FAC.banner_cloth, Vector3.one, CFrame.identity, function(hex)
		for i, t in ipairs(TONES_B) do
			if t == hex then
				return "Cloth" .. i
			end
		end
		return "Trim"
	end)
	local opts = clothVariants(m, TONES_B, { "4A6CDC", "966EFF", "FFC93C" })
	local bar = rowsNamed("Banner_A", "Crossbar")[1]
	local bp = bar.cf.Position
	table.insert(U.Wood, chamfered(bar.size - Vector3.new(0.5, 0, 0), bar.cf, bar.color, { "topFrontBack", "bottomFrontBack" }, 0.1))
	for _, sx in ipairs({ -1, 1 }) do
		knob(U.Wood, bp + Vector3.new(sx * (bar.size.X / 2 - 0.1), 0, 0), 0.32, scaled(bar.color, 1.08))
	end
	for k = 0, 4 do
		ring(U.Wood, bp + Vector3.new(-1.9 + k * 0.95, 0, 0), Vector3.xAxis, 0.33, 0.14, ROPE)
	end
	table.insert(U.Wood, H.bar(bp + Vector3.new(-0.42, 0.42, -0.3), bp + Vector3.new(0.42, -0.42, -0.3), 0.12, ROPE))
	table.insert(U.Wood, H.bar(bp + Vector3.new(-0.42, -0.42, -0.3), bp + Vector3.new(0.42, 0.42, -0.3), 0.12, ROPE))
	local pole = rowsNamed("Banner_A", "Pole")[1]
	table.insert(U.Wood, M.frustumN(8, 0.33, 0.29, 0.6, pole.size.Y, CFrame.identity, { pole.color, scaled(pole.color, 0.92) }))
	for _, y in ipairs({ 11.0, 12.9 }) do
		ring(U.Wood, Vector3.new(0, y, 0), Vector3.yAxis, 0.38, 0.22, P.WoodMid)
	end
	local fin = rowsNamed("Banner_A", "Finial")[1]
	ring(U.Gold, fin.cf.Position - Vector3.new(0, 0.5, 0), Vector3.yAxis, 0.3, 0.16, scaled(fin.color, 0.9))
	knob(U.Gold, fin.cf.Position, fin.size.X / 2, fin.color)
	local foot = rowsNamed("Banner_A", "Foot")[1]
	table.insert(U.Stone, chamfered(Vector3.new(1.4, 0.36, 1.4), CFrame.new(0, 0.18, 0), foot.color, { "topFrontBack", "topSides", "vertical" }, 0.1))
	table.insert(U.Stone, chamfered(Vector3.new(1.0, 0.26, 1.0), CFrame.new(0, 0.48, 0), scaled(foot.color, 1.08), { "topFrontBack", "topSides" }, 0.08))
	finishB4(m, "banner_diamond", U, "Wood", opts)
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("PartOperation") then
			p.CanQuery = false
		end
	end
	kitCollision(m, "Banner_A")
	return m
end

---------------------------------------------------------------------
-- 08 FLAGPOLE, RED FLAG (kit MapAssets.Common.Flag_Pole_A: Foot cylinder 1.6 x 0.6, Pole cylinder 0.6 x 17, a gold
-- Finial ball 1.0 at y 17.3, a red Cloth wedge 7.5 x 3.6 at y 14.6; all 4 collide; 21 copies: test, kit, Hub
-- Decor.Props.Flags x12 (4 at 1.0, 8 at 1.35), Decor.Backdrop.Islets x6 (2.2), Plains_2 PirateCamp; static)
---------------------------------------------------------------------
-- The flagpole (guide D4 / D6): a pole tapered in 3 octagonal sections (0.65 -> 0.45), 3 iron rings, a rope cleat at
-- y 3 with the halyard up to the flag; Agent A's flag (5 fold panels, hem, gold sleeve) at today's place; today's gold
-- finial as a faceted ball on a collar; today's foot as an octagonal 2-step stone plinth. Today's 4 parts stay the exact
-- colliders. The flag's 3 red tones are single-colour unions: the _Variants recolour the copies flying another colour
-- (blue, pink, gold, purple, grey, yellow, cyan). Parts: Cloth1-3, Trim, Wood, Iron, Stone, Gold, Collision x4.
function B4.flagpole(): Model
	local m = Instance.new("Model")
	m.Name = "flagpole"
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Iron = {}, Stone = {}, Gold = {} }
	local TONES_F = { "#D4343C", "#99252B", "#B62D34" }
	facetsSplit(U, FAC.flag_cloth, Vector3.one, CFrame.new(0, 12.8, 0), function(hex)
		for i, t in ipairs(TONES_F) do
			if t == hex then
				return "Cloth" .. i
			end
		end
		return "Trim"
	end)
	local opts = clothVariants(m, TONES_F, { "4A6CDC", "FF5C78", "FFC93C", "966EFF", "5C626E", "FFD646", "34D6EC" })
	local W0 = rgb(112, 62, 38)
	local secs = { { 0.55, 6, 0.33, 0.3 }, { 6, 11.5, 0.3, 0.26 }, { 11.5, 16.85, 0.26, 0.23 } }
	for i, s in ipairs(secs) do
		table.insert(U.Wood, M.frustumN(8, s[3], s[4], s[1], s[2], CFrame.identity, { scaled(W0, 0.9 + 0.05 * i), scaled(W0, 0.86 + 0.05 * i) }))
	end
	for _, y in ipairs({ 4, 9, 13 }) do
		ring(U.Iron, Vector3.new(0, y, 0), Vector3.yAxis, 0.38, 0.2, P.Iron)
	end
	table.insert(U.Iron, piece("Part", Vector3.new(0.14, 0.7, 0.14), CFrame.new(0.38, 3, 0), P.Iron))
	table.insert(U.Iron, H.bar(Vector3.new(0.42, 3.3, 0), Vector3.new(0.3, 12.85, 0), 0.07, ROPE))
	local fin = rowsNamed("Flag_Pole_A", "Finial")[1]
	ring(U.Gold, fin.cf.Position - Vector3.new(0, 0.55, 0), Vector3.yAxis, 0.3, 0.3, scaled(fin.color, 0.9))
	knob(U.Gold, fin.cf.Position, fin.size.X / 2, fin.color)
	local STONE = rgb(150, 156, 168)
	table.insert(U.Stone, M.frustumN(8, 0.88, 0.8, 0, 0.36, CFrame.Angles(0, rad(22.5), 0), { STONE, scaled(STONE, 0.93) }))
	table.insert(U.Stone, M.frustumN(8, 0.66, 0.58, 0.36, 0.6, CFrame.Angles(0, rad(22.5), 0), { rgb(163, 170, 183), scaled(rgb(163, 170, 183), 0.93) }))
	finishB4(m, "flagpole", U, "Wood", opts)
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("PartOperation") then
			p.CanQuery = false
		end
	end
	kitCollision(m, "Flag_Pole_A")
	return m
end

---------------------------------------------------------------------
-- torches (09 the short lamp post = Torch_Standing, 10 the wall torch = Torch_Wall): today's Head keeps the FirePoint
-- (the zone's Decor.VFX.Fire_Torch part stands on it) and today's Neon Ember stays; the copies' own PointLights are
-- carried by an invisible "TorchLight" part (MapPropKeep) made from each copy before the sync, so the template has no
-- light and each copy keeps its own (or none)
---------------------------------------------------------------------
local function keptPart(m: Model, row: any, visible: boolean, color: Color3?, material: Enum.Material?): BasePart
	local p = Instance.new(row.class) :: BasePart
	if row.shape ~= "" and p:IsA("Part") then
		p.Shape = Enum.PartType[row.shape]
	end
	p.Name = row.name
	p.Size = row.size
	p.CFrame = row.cf
	p.Color = color or row.color
	p.Material = material or Enum.Material[row.material]
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = if visible then 0 else 1
	p.Parent = m
	return p
end

-- a layered stylized flame (guide C6 / D6, as 3 nested Neon bipyramids instead of Agent A's 44-face facet: the facet
-- was about 2,200 triangles a torch, these about 150, on 59 torches): an orange outer flame, a gold middle one turned
-- 30 deg, a pale core; foot at `cf` (Y up), `s` = scale (1 = 1.0 tall)
local function layeredFlame(list: { BasePart }, cf: CFrame, s: number)
	table.insert(list, H.flame(cf, 0.36 * s, 0.32 * s, 1.0 * s, rgb(255, 140, 40), Vector3.new(0.04, 0, 0.03) * s))
	table.insert(list, H.flame(cf * CFrame.new(0, 0.08 * s, 0) * CFrame.Angles(0, rad(30), 0), 0.26 * s, 0.3 * s, 0.82 * s, rgb(255, 182, 72), Vector3.new(-0.03, 0, 0.02) * s))
	table.insert(list, H.flame(cf * CFrame.new(0, 0.14 * s, 0), 0.15 * s, 0.22 * s, 0.58 * s, rgb(255, 214, 120)))
end

-- 09 SHORT LAMP POST (kit MapAssets.Common.Torch_Standing: round stone Foot 1.8 x 0.5, Pole 0.6 x 5.2, an iron Head
-- cylinder 1.3 x 0.9 at y 5.6 with the FirePoint and a PointLight, a Neon Ember ball 0.9 at y 6.1; 21 copies: test, kit,
-- Hub Harbor x2 (1.3) / AltarBackdrop x2 (1.4, no light), Plains_4 Cavern x5 (1.3), Desert_3 Caves x4, BossArenas
-- Plains x6 (1.4))
-- The lamp post (guide D4 / D6): today's pole chamfered with 2 iron bands and an iron collar; today's Head as the iron
-- base of a glass lantern around today's Ember: 4 corner posts, 4 warm glass panes (Glass T 0.4 #FFE296) and an OPEN
-- crown (a ring with 4 points: the copies' fire particles still rise out of it), a layered Neon flame inside; today's
-- foot as an octagonal 2-tier stone base. Today's 3 colliding parts stay the exact colliders.
-- Parts: Wood, Iron, Stone, Glass, Glow (flame), Head (FirePoint), Ember, Collision x3.
function B4.standing_torch(): Model
	local m = Instance.new("Model")
	m.Name = "standing_torch"
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Iron = {}, Stone = {}, Glass = {} }
	local pole = rowsNamed("Torch_Standing", "Pole")[1]
	table.insert(U.Wood, chamfered(pole.size, pole.cf, graded(pole.color, 2.9, 6.5), { "vertical" }, 0.1))
	for _, y in ipairs({ 1.5, 4.2 }) do
		table.insert(U.Iron, piece("Part", Vector3.new(0.68, 0.2, 0.68), CFrame.new(0, y, 0), P.Iron))
	end
	table.insert(U.Iron, M.frustumN(8, 0.42, 0.62, 4.95, 5.2, CFrame.identity, { P.Iron, scaled(P.Iron, 1.08) }))
	-- the lantern on the Head (top 6.05)
	local y0, y1 = 6.05, 6.9
	table.insert(U.Iron, piece("Part", Vector3.new(1.4, 0.1, 1.4), CFrame.new(0, y0 + 0.05, 0), P.Iron))
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Iron, piece("Part", Vector3.new(0.1, y1 - y0 + 0.1, 0.1), CFrame.new(sx * 0.65, (y0 + y1) / 2 + 0.05, sz * 0.65), P.Iron))
			table.insert(U.Iron, M.frustumN(4, 0.07, 0.01, y1 + 0.1, y1 + 0.2, CFrame.new(sx * 0.65, 0, sz * 0.65), { P.Iron, P.Iron }))
		end
	end
	for k = 0, 3 do
		local a = k * math.pi / 2
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local side = Vector3.new(-d.Z, 0, d.X)
		table.insert(U.Iron, piece("Part", Vector3.new(1.4, 0.1, 0.1), CFrame.fromMatrix(d * 0.65 + Vector3.new(0, y1 + 0.05, 0), side, Vector3.yAxis), P.Iron))
		table.insert(U.Glass, piece("Part", Vector3.new(1.18, y1 - y0 - 0.1, 0.05), CFrame.fromMatrix(d * 0.62 + Vector3.new(0, (y0 + y1) / 2 + 0.05, 0), side, Vector3.yAxis), rgb(255, 226, 150)))
	end
	U.Glow = {}
	layeredFlame(U.Glow, CFrame.new(0, 5.95, 0), 0.92)
	local STONE = rgb(150, 156, 168)
	table.insert(U.Stone, M.frustumN(8, 0.95, 0.86, -0.05, 0.25, CFrame.Angles(0, rad(22.5), 0), { STONE, scaled(STONE, 0.93) }))
	table.insert(U.Stone, M.frustumN(8, 0.68, 0.6, 0.25, 0.45, CFrame.Angles(0, rad(22.5), 0), { rgb(163, 170, 183), scaled(rgb(163, 170, 183), 0.93) }))
	finishB4(m, "standing_torch", U, "Wood", { Glass = { material = Enum.Material.Glass, transparency = 0.4, shadow = false }, Glow = { material = Enum.Material.Neon, shadow = false } })
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("PartOperation") then
			p.CanQuery = false
		end
	end
	local head = keptPart(m, rowsNamed("Torch_Standing", "Head")[1], true, P.Iron)
	local fp = Instance.new("Attachment")
	fp.Name = "FirePoint"
	fp.CFrame = FIREPOINT.Torch_Standing
	fp.Parent = head
	keptPart(m, rowsNamed("Torch_Standing", "Ember")[1], true)
	kitCollision(m, "Torch_Standing")
	return m
end

-- 10 WALL TORCH (the owner's "campfire or brazier parts": kit MapAssets.Common.Torch_Wall: an iron Bracket 0.9 x 1.4 x
-- 0.3 on the wall plane, a wooden Stick 0.5 x 3 tilted 22 deg, an iron Head cylinder with the FirePoint and a PointLight,
-- a Neon Ember ball 0.8; 38 copies: test, kit, Plains_4 Mine x4, Desert_4 x10, Jungle_4 x14 (parts resized x1.3: rule
-- bakedScale from the Stick), BossArenas Jungle x8; 22 copies have no light)
-- The wall torch (guide D4 / D6; owner 2026-10-21: "flip the bar so it leans the other way, bottom end near the gray
-- post, top end going up to the cup, and attach the cup and flame on top of the bar's upper end"): today's stick
-- mirrored across the vertical plane through its centre (it leaned "\", its top 1.2 from the cup; now "/", its foot at
-- the back plate and its top end inside the cup's foot), today's bracket as an iron back plate with 4 rivets and a ring
-- holding the stick;
-- today's stick chamfered with a leather wrap at the grip and 2 iron rings; an octagonal iron cup with a rim and 4 claws
-- and a layered Neon flame on today's Head (kept invisible: it holds the FirePoint) and today's Ember (part-built: Agent
-- A's cup and flame facets were about 3,500 triangles a torch, on 38 torches). Today's 3 colliding parts stay the exact
-- colliders. Parts: Wood, Iron, Glow (flame), Head (FirePoint), Ember, Collision x3.
function B4.wall_torch(): Model
	local m = Instance.new("Model")
	m.Name = "wall_torch"
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Iron = {} }
	local br = rowsNamed("Torch_Wall", "Bracket")[1]
	table.insert(U.Iron, chamfered(br.size, br.cf, br.color, { "vertical", "topFrontBack", "bottomFrontBack" }, 0.06))
	for _, sx in ipairs({ -1, 1 }) do
		for _, y in ipairs({ -0.5, 0.5 }) do
			nail(U.Iron, br.cf * Vector3.new(sx * 0.3, y, -0.16), 0.12)
		end
	end
	local st = rowsNamed("Torch_Wall", "Stick")[1]
	-- the stick mirrored (owner): same centre and length, its lean toward -Z reversed
	local up0 = st.cf.UpVector
	local axis = Vector3.new(up0.X, up0.Y, -up0.Z).Unit
	local stick = alongY(st.cf.Position, axis)
	table.insert(U.Wood, chamfered(st.size, stick, st.color, { "vertical" }, 0.08))
	for _, k in ipairs({ -0.75, -0.45, -0.15 }) do
		ring(U.Wood, stick * Vector3.new(0, k, 0), axis, 0.3, 0.22, scaled(LEATHER, 1 + k * 0.1))
	end
	for _, k in ipairs({ 0.55, 0.9 }) do
		ring(U.Iron, stick * Vector3.new(0, k, 0), axis, 0.31, 0.14, P.Iron)
	end
	-- the collar band at the top end carrying the cup, a ring holding the foot on the back plate
	ring(U.Iron, stick * Vector3.new(0, 1.28, 0), axis, 0.36, 0.3, scaled(P.Iron, 1.08))
	local hold = stick * Vector3.new(0, -1.15, 0)
	ring(U.Iron, hold, axis, 0.36, 0.16, P.Iron)
	table.insert(U.Iron, H.bar(br.cf * Vector3.new(0, -0.25, -0.15), hold + Vector3.new(0, 0, 0.05), 0.12, P.Iron))
	local rim = CFrame.new(0, 3.55, -1.6)
	table.insert(U.Iron, M.frustumN(8, 0.28, 0.5, -0.6, -0.05, rim * CFrame.Angles(0, rad(22.5), 0), { P.Iron, scaled(P.Iron, 0.9) }))
	-- the cup's foot resting on the stick's collar (no gap)
	local top = stick * Vector3.new(0, 1.42, 0)
	table.insert(U.Iron, M.frustumN(8, 0.3, 0.26, top.Y - 0.08 - 3.55, -0.58, rim * CFrame.new(top.X, 0, top.Z + 1.6) * CFrame.Angles(0, rad(22.5), 0), { scaled(P.Iron, 0.95), P.Iron }))
	table.insert(U.Iron, M.frustumN(8, 0.56, 0.56, -0.08, 0.04, rim * CFrame.Angles(0, rad(22.5), 0), { scaled(P.Iron, 1.1), P.Iron }))
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		table.insert(U.Iron, H.bar(rim * (d * 0.5), rim * (d * 0.62 + Vector3.new(0, 0.3, 0)), 0.08, P.Iron))
	end
	U.Glow = {}
	layeredFlame(U.Glow, CFrame.new(0, 3.35, -1.65), 0.95)
	finishB4(m, "wall_torch", U, "Wood", { Glow = { material = Enum.Material.Neon, shadow = false } })
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("PartOperation") then
			p.CanQuery = false
		end
	end
	local head = keptPart(m, rowsNamed("Torch_Wall", "Head")[1], false)
	local fp = Instance.new("Attachment")
	fp.Name = "FirePoint"
	fp.CFrame = FIREPOINT.Torch_Wall
	fp.Parent = head
	keptPart(m, rowsNamed("Torch_Wall", "Ember")[1], true)
	kitCollision(m, "Torch_Wall")
	return m
end

---------------------------------------------------------------------
-- 01 SPIKED MACE (kit MapAssets.Plains.Troll_Club: a Handle cylinder 8 x 1.7, a Pommel 1.0 x 2.2, 2 Head cylinders
-- 4.0 x 3.2 / 5.0 x 4.6 #A86238, 2 iron Bands 0.8 x 4.9, 6 Spike MeshParts; lying on the ground along X, tilted 4 deg;
-- attributes SourceAssetId / SourceCreator; 3 copies: test, kit, BossArenas.Plains.Decor.TrollDen)
---------------------------------------------------------------------
-- The mace (guide D4 / D6): today's 2 head cylinders as an octagonal carved wooden head (6 grooves along it), today's 2
-- bands as iron bands with 8 rivets and raised rims, an iron end cap with a boss; spikes after Agent A's design
-- (collar, bevelled blade, pale tip) at today's 6 Spike places; the handle octagonal with a 6-band leather wrap, an iron collar where it enters the head, today's pommel as an
-- octagonal iron pommel with a ring. Today's 6 colliding cylinders stay the exact colliders.
-- Parts: Wood, Iron, Leather, Collision x6.
function B4.spiked_mace(): Model
	local m = Instance.new("Model")
	m.Name = "spiked_mace"
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Iron = {}, Leather = {} }
	local function axisFrame(r: any): CFrame
		return r.cf * CFrame.Angles(0, 0, -math.pi / 2) -- the cylinder's X axis as the frame's Y
	end
	local heads = rowsNamed("Troll_Club", "Head")
	for i, r in ipairs(heads) do
		local f = axisFrame(r)
		local rad0 = r.size.Y / 2
		table.insert(U.Wood, M.frustumN(8, rad0, rad0, -r.size.X / 2, r.size.X / 2, f * CFrame.Angles(0, rad(22.5), 0), { r.color, scaled(r.color, 0.93) }))
		if i == 2 then
			for k = 0, 5 do
				local a = k * math.pi / 3 + 0.3
				local d = Vector3.new(math.cos(a), 0, math.sin(a))
				table.insert(U.Wood, piece("Part", Vector3.new(0.18, r.size.X - 0.6, 0.06), f * CFrame.new(d * (rad0 - 0.02)) * CFrame.lookAt(Vector3.zero, d), scaled(r.color, 0.8)))
			end
			-- the end cap with a boss at the head's far end (+axis)
			local tip = f * CFrame.new(0, r.size.X / 2, 0)
			table.insert(U.Iron, M.frustumN(8, rad0 * 0.98, rad0 * 0.9, 0, 0.3, tip, { P.Iron, scaled(P.Iron, 1.05) }))
			table.insert(U.Iron, M.frustumN(8, 0.6, 0.35, 0.3, 0.65, tip, { rgb(122, 128, 140), P.Iron }))
		end
	end
	for _, r in ipairs(rowsNamed("Troll_Club", "Band")) do
		local f = axisFrame(r)
		local rb = r.size.Y / 2
		table.insert(U.Iron, M.frustumN(8, rb, rb, -r.size.X / 2, r.size.X / 2, f * CFrame.Angles(0, rad(22.5), 0), { r.color, scaled(r.color, 0.9) }))
		for _, e in ipairs({ -1, 1 }) do
			table.insert(U.Iron, M.frustumN(8, rb + 0.08, rb + 0.08, e * r.size.X / 2 - 0.06, e * r.size.X / 2 + 0.06, f * CFrame.Angles(0, rad(22.5), 0), { scaled(r.color, 1.1), r.color }))
		end
		for k = 0, 7 do
			local a = k * math.pi / 4 + rad(22.5)
			table.insert(U.Iron, piece("Part", Vector3.new(0.2, 0.2, 0.2), f * CFrame.new(math.cos(a) * (rb + 0.05), 0, math.sin(a) * (rb + 0.05)) * CFrame.Angles(rad(45), a, rad(45)), rgb(122, 128, 140)))
		end
	end
	-- the spikes (after Agent A's b4_mace__spike, part-built: an octagonal collar, a bevelled 4-sided blade, a pale tip)
	for _, r in ipairs(rowsNamed("Troll_Club", "Spike")) do
		local h = r.size.Y
		table.insert(U.Iron, M.frustumN(8, 0.5, 0.42, -h / 2, -h / 2 + 0.3, r.cf * CFrame.Angles(0, rad(22.5), 0), { P.Iron, scaled(P.Iron, 1.1) }))
		table.insert(U.Iron, M.frustumN(4, 0.42, 0.1, -h / 2 + 0.3, h / 2 - 0.35, r.cf * CFrame.Angles(0, rad(45), 0), { rgb(150, 156, 168), rgb(180, 186, 196), rgb(135, 140, 151) }))
		table.insert(U.Iron, M.frustumN(4, 0.1, 0.01, h / 2 - 0.35, h / 2, r.cf * CFrame.Angles(0, rad(45), 0), { rgb(200, 205, 214), rgb(200, 205, 214) }))
	end
	local hd = rowsNamed("Troll_Club", "Handle")[1]
	local fh = axisFrame(hd)
	local rh = hd.size.Y / 2
	table.insert(U.Wood, M.frustumN(8, rh, rh, -hd.size.X / 2, hd.size.X / 2, fh * CFrame.Angles(0, rad(22.5), 0), { hd.color, scaled(hd.color, 0.92) }))
	for k = 0, 5 do
		local y = -2 + k * 0.72
		table.insert(U.Leather, M.frustumN(8, rh + 0.05, rh + 0.05, -0.3, 0.3, fh * CFrame.new(0, y, 0) * CFrame.Angles(rad(12), 0, 0), { scaled(LEATHER, 1 + (k % 2) * 0.12), LEATHER }))
	end
	table.insert(U.Iron, M.frustumN(8, rh + 0.18, rh + 0.18, -0.2, 0.2, fh * CFrame.new(0, hd.size.X / 2 - 0.25, 0), { P.Iron, scaled(P.Iron, 1.08) }))
	local pm = rowsNamed("Troll_Club", "Pommel")[1]
	local fp = axisFrame(pm)
	local rp = pm.size.Y / 2
	table.insert(U.Iron, M.frustumN(8, rp * 0.75, rp, -pm.size.X / 2, 0, fp * CFrame.Angles(0, rad(22.5), 0), { P.Iron, scaled(P.Iron, 1.06) }))
	table.insert(U.Iron, M.frustumN(8, rp, rp * 0.8, 0, pm.size.X / 2, fp * CFrame.Angles(0, rad(22.5), 0), { scaled(P.Iron, 1.06), P.Iron }))
	ring(U.Iron, fp * Vector3.new(0, -pm.size.X / 2 - 0.25, 0), fp.UpVector, 0.38, 0.12, rgb(122, 128, 140))
	finishB4(m, "spiked_mace", U, "Wood")
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("PartOperation") then
			p.CanQuery = false
		end
	end
	kitCollision(m, "Troll_Club")
	return m
end

---------------------------------------------------------------------
-- tents (guide D3): the improved desert tent (tools/PropsDesert.luau 04 TENT, guide B6) rebuilt here with a palette:
-- canvas panels with stitched seams and a hem, a ridge binding, the front flaps folded back (their lining shows) with
-- rolled edges and rope ties, the dark doorway, poles with gold ball caps, guy ropes and stakes, a rug at the door and
-- grass tufts (instead of the desert's sand drift). Ridge along Z, the door at -Z, 11 x 8.75 x 14 like NomadTent_A /
-- Tent_A. The colliders are added by the caller.
---------------------------------------------------------------------
local function plainsTent(U: any, rng: Random, o: any)
	local slopeLen = math.sqrt(5.5 ^ 2 + 8 ^ 2)
	local DARK = rgb(112, 62, 38)
	local TRUNK = rgb(150, 104, 64)
	for _, side in ipairs({ { -1, o.canvas }, { 1, o.canvasAlt } }) do
		local sx = side[1]
		local u = Vector3.new(-sx * 5.5, 8, 0).Unit -- base -> ridge
		local n = Vector3.new(sx * 8, 5.5, 0).Unit -- outward
		local mid = Vector3.new(sx * 2.75, 4, 0)
		for k = 0, 3 do
			local z = -4.5 + k * 3
			local c = mid + Vector3.new(0, 0, z) + n * 0.08
			table.insert(U.Canvas, piece("Part", Vector3.new(3.0, slopeLen + 0.1, 0.15), CFrame.fromMatrix(c, Vector3.zAxis, u), scaled(side[2], if k % 2 == 0 then 1 else 0.93)))
		end
		for _, z in ipairs({ -3, 0, 3 }) do
			table.insert(U.Canvas, piece("Part", Vector3.new(0.12, slopeLen, 0.06), CFrame.fromMatrix(mid + Vector3.new(0, 0, z) + n * 0.18, Vector3.zAxis, u), o.seam))
		end
		local base = Vector3.new(sx * 5.5, 0, 0)
		table.insert(U.Canvas, piece("Part", Vector3.new(12.0, 0.3, 0.07), CFrame.fromMatrix(base + u * 0.2 + n * 0.19, Vector3.zAxis, u), o.seam))
		table.insert(U.Canvas, piece("Part", Vector3.new(12.1, 0.45, 0.08), CFrame.fromMatrix(Vector3.new(0, 8, 0) - u * 0.25 + n * 0.2, Vector3.zAxis, u), o.binding))
	end
	-- back gable with a seam
	H.triangleParts(U.Canvas, Vector3.new(-5.5, 0, 6.05), Vector3.new(5.5, 0, 6.05), Vector3.new(0, 8, 6.05), 0.15, CFrame.identity, scaled(o.canvasAlt, 0.95))
	table.insert(U.Canvas, piece("Part", Vector3.new(0.12, 7.9, 0.06), CFrame.new(0, 3.95, 6.14), o.seam))
	-- front gable: the lining of the flaps folded back left and right of the doorway, bindings, rolled edges, ties
	for _, sx in ipairs({ -1, 1 }) do
		H.triangleParts(U.Lining, Vector3.new(sx * 5.5, 0, -6.05), Vector3.new(sx * 3.0, 0, -6.05), Vector3.new(0, 8, -6.05), 0.15, CFrame.identity, o.lining)
		H.triangleParts(U.Lining, Vector3.new(sx * 3.0, 0, -6.05), Vector3.new(0, 6, -6.05), Vector3.new(0, 8, -6.05), 0.15, CFrame.identity, scaled(o.lining, 0.93))
		table.insert(U.Canvas, H.bar(Vector3.new(sx * 5.5, 0.05, -6.12), Vector3.new(0, 8.0, -6.12), 0.24, o.binding))
		local a, b = Vector3.new(sx * 3.15, 0.2, -6.25), Vector3.new(sx * 0.15, 5.85, -6.25)
		local dir = (b - a).Unit
		table.insert(U.Canvas, H.octagon(0.5, (b - a).Magnitude, CFrame.fromMatrix((a + b) / 2, Vector3.zAxis:Cross(dir).Unit, dir), if sx < 0 then o.canvas else o.canvasAlt))
		for _, f in ipairs({ 0.35, 0.7 }) do
			local p = a:Lerp(b, f)
			table.insert(U.Wood, H.octagon(0.62, 0.14, CFrame.fromMatrix(p, Vector3.zAxis:Cross(dir).Unit, dir), ROPE))
		end
	end
	-- the dark doorway
	H.triangleParts(U.Lining, Vector3.new(-3, 0, -5.6), Vector3.new(3, 0, -5.6), Vector3.new(0, 6, -5.6), 0.12, CFrame.identity, scaled(DARK, 0.55))
	-- poles, ridge, gold caps, guy ropes and stakes
	for _, z in ipairs({ -6.6, 6.6 }) do
		table.insert(U.Wood, H.timber(Vector3.new(0.5, 8.6, 0.5), CFrame.new(0, 4.3, z), DARK, 0.08))
		knob(U.Gold, Vector3.new(0, 8.75, z), 0.3, rgb(255, 201, 60))
		for _, sx in ipairs({ -1, 1 }) do
			local stake = Vector3.new(sx * 2.2, 0.35, z + (if z < 0 then -0.55 else 0.55))
			table.insert(U.Wood, H.bar(Vector3.new(0, 8.3, z), stake + Vector3.new(0, 0.3, 0), 0.12, ROPE))
			table.insert(U.Wood, piece("Part", Vector3.new(0.25, 0.8, 0.25), CFrame.new(stake) * CFrame.Angles(if z < 0 then rad(-25) else rad(25), 0, 0), TRUNK))
		end
	end
	table.insert(U.Wood, H.timber(Vector3.new(0.5, 0.5, 14), CFrame.new(0, 8.1, 0), scaled(DARK, 1.06), 0.08))
	for _, sx in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -3, 3 }) do
			local onSlope = Vector3.new(sx * 3.35, 3.1, z)
			local stake = Vector3.new(sx * 5.7, 0.35, z)
			table.insert(U.Wood, H.bar(onSlope, stake + Vector3.new(0, 0.3, 0), 0.12, ROPE))
			table.insert(U.Wood, piece("Part", Vector3.new(0.25, 0.8, 0.25), CFrame.new(stake) * CFrame.Angles(0, 0, sx * rad(25)), TRUNK))
		end
	end
	-- a striped rug at the door, grass tufts along the sides
	table.insert(U.Ground, piece("Part", Vector3.new(3.4, 0.12, 2.2), CFrame.new(0, 0.06, -6.2), o.rug))
	for _, x in ipairs({ -1.2, -0.4, 0.4, 1.2 }) do
		table.insert(U.Ground, piece("Part", Vector3.new(0.28, 0.03, 2.2), CFrame.new(x, 0.13, -6.2), o.rugStripe))
	end
	for _, p in ipairs({ Vector3.new(5.6, 0, -4.8), Vector3.new(-5.7, 0, 1.5), Vector3.new(5.5, 0, 4.2), Vector3.new(-4.2, 0, -6.4) }) do
		tuft(U.Plants, rng, p, 0.7, 5)
	end
	if o.bedroll then
		-- a rolled bedroll just inside the open door
		local f = CFrame.new(1.2, 0.32, -4.4) * CFrame.Angles(0, rad(80), 0) * CFrame.Angles(0, 0, rad(90))
		table.insert(U.Ground, M.frustumN(8, 0.32, 0.32, -1.2, 1.2, f, { rgb(168, 98, 56), scaled(rgb(168, 98, 56), 0.9) }))
		for _, y in ipairs({ -0.7, 0.7 }) do
			table.insert(U.Ground, M.frustumN(8, 0.34, 0.34, y - 0.08, y + 0.08, f, { rgb(232, 226, 208), rgb(232, 226, 208) }))
		end
	end
end

local function tentModel(id: string, o: any): Model
	local m = Instance.new("Model")
	m.Name = id
	local rng = Random.new(o.seed)
	H.setBevelSelf(true)
	local U: any = { Canvas = {}, Lining = {}, Wood = {}, Gold = {}, Ground = {}, Plants = {} }
	plainsTent(U, rng, o)
	finishB4(m, id, U, "Wood", { Plants = { shadow = false } })
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("PartOperation") then
			p.CanQuery = false
		end
	end
	return m
end

-- 01 TENT RED / WHITE (kit MapAssets.Common.Tent_A = NomadTent_A's 9 parts: linen ClothL / ClothR wedges 12 x 8 x 5.5,
-- red Trim wedges, dark Entrance wedges, 2 Poles, a RidgePole; 4 copies: test, kit, Hub AFKCorner (linen), Plains_2
-- PirateCamp (all red: template tent_red))
-- The tent (guide D3): the desert tent recipe in linen #E8E2D0 / #DCD5C2 with darker seams #C9C1AC, red #D4343C bindings
-- and flap lining, rope ties, poles with gold caps, a red / linen rug and grass tufts. Today's 9 parts stay the exact
-- colliders (the doorway is closed today). Parts: Canvas, Lining, Wood, Gold, Ground, Plants, Collision x9.
local LINEN, RED = rgb(232, 226, 208), rgb(212, 52, 60)
function B4.tent_red_white(): Model
	local m = tentModel("tent_red_white", { seed = 20261409, canvas = LINEN, canvasAlt = rgb(220, 213, 194), seam = rgb(201, 193, 172), binding = RED, lining = RED, rug = RED, rugStripe = LINEN })
	kitCollision(m, "Tent_A")
	return m
end

-- the Plains_2 PirateCamp copy is all red today (ClothL / R #D4343C): the same tent in red #D4343C / #BF2E36 with a
-- linen lining and bindings
function B4.tent_red(): Model
	local m = tentModel("tent_red", { seed = 20261410, canvas = RED, canvasAlt = rgb(191, 46, 54), seam = rgb(150, 36, 42), binding = LINEN, lining = LINEN, rug = LINEN, rugStripe = RED })
	kitCollision(m, "Tent_A")
	return m
end

---------------------------------------------------------------------
-- 04 STONE TOWER, BLUE ROOF (kit MapAssets.Hub.Hub_Tower: a Base cylinder 21 x 3 #686E7C, a Body cylinder 18 x 31
-- #969CA8 (y 3 .. 34), a Band at y 15, a ParapetRim + Parapet 22 x 3.6 #A3AAB7 with 8 Merlons, a RoofDrum 15 x 2, a
-- RoofCone of 16 wedges (y 37.6 .. 53.6), a FlagPole 0.5 x 7 with a gold Finial and a red Cloth wedge, a door 5 x 8
-- in a frame with a DoorStep 7 x 3 x 4, 3 windows 2.2 x 3.6; 47 parts, all colliding; 3 copies: test, kit,
-- Hub.Decor.Village)
---------------------------------------------------------------------
-- a ring of n stone faces (flat plates on the n-gon of apothem `ap`, `h` tall, `d` deep, its face jittered 0 / 0.04 /
-- 0.07) from y0, block k centred on angle a0 + k * step; skip(a, y0, y1) leaves a block out (an opening)
local function plateRing(list: { BasePart }, rng: Random, o: any)
	local step = 2 * math.pi / o.n
	local w = 2 * o.ap * math.tan(step / 2) - (o.gap or 0.1)
	local prev
	for k = 0, o.n - 1 do
		local a = (o.a0 or 0) + k * step
		if o.skip and o.skip(a, o.y0, o.y0 + o.h) then
			continue
		end
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local ti = H.toneIndex(rng, prev)
		prev = ti
		local r = o.ap - o.d / 2 + (if o.noJitter then 0 else ({ 0, 0.04, 0.07 })[rng:NextInteger(1, 3)])
		local c = graded(scaled(o.color, H.TONES[ti]), o.y0 + o.h / 2, o.Ht or 60)
		local cf = CFrame.lookAt(d * r + Vector3.new(0, o.y0 + o.h / 2, 0), d * (r + 1) + Vector3.new(0, o.y0 + o.h / 2, 0))
		if o.chamfer then
			table.insert(list, chamfered(Vector3.new(w, o.h - 0.06, o.d), cf, c, { "topFrontBack" }, o.chamfer))
		else
			table.insert(list, piece("Part", Vector3.new(w, o.h - 0.06, o.d), cf, c))
		end
	end
end

-- The tower (guide D5): today's body as 24 courses of cut stone faces (16 a course, running bond, 0.1 joints over a dark
-- 16-sided core, 3 tones, the gradient), today's band as a projecting ring of darker blocks with a chamfered top, the
-- base as 2 battered courses of big blocks, the parapet as 2 courses of blocks over a corbel ring of 16 brackets, the 8
-- merlons with chamfered dark cap slabs, the roof drum as a dark ring; Agent A's tiled cone roof (8 rows of individual
-- tiles, darker hip ribs, a gold apex collar) in place of today's 16 wedges; the flag pole with 2 iron rings, today's gold
-- finial and Agent A's flag at 0.72 (static, like today); the door as 5 planks with strap hinges under an arch of 7
-- dark voussoirs, today's step as 2 courses of blocks; the 3 windows with a dark stone sill and lintel and 2 small
-- shutters each; moss at the foot. Today's 47 parts stay the exact colliders.
-- Parts: Stone, BodyLow, BodyHigh, Roof1-4, Wood, Iron, Gold, Glass, Cloth, Plants, Collision x47.
function B4.stone_tower(): Model
	local m = Instance.new("Model")
	m.Name = "stone_tower"
	local rng = Random.new(20261411)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, BodyLow = {}, BodyHigh = {}, Wood = {}, Iron = {}, Gold = {}, Glass = {}, Plants = {} }
	local STONE, LIGHT, DARK, MORTAR = rgb(150, 156, 168), rgb(163, 170, 183), rgb(104, 110, 124), rgb(84, 88, 100)
	-- the openings on the body (angle, half width in radians, y0, y1)
	local opens = {}
	for _, r in ipairs(KD.rows("Hub_Tower")) do
		if r.name == "Window" or r.name == "Door" then
			local p = r.cf.Position
			local a = math.atan2(p.Z, p.X)
			local half = (r.size.X / 2 + 0.45) / 9
			table.insert(opens, { a = a, half = half, y0 = p.Y - r.size.Y / 2 - 0.5, y1 = p.Y + r.size.Y / 2 + 0.6 })
		end
	end
	local function skip(a: number, y0: number, y1: number): boolean
		for _, o in ipairs(opens) do
			local da = math.abs((a - o.a + math.pi) % (2 * math.pi) - math.pi)
			if da < o.half + math.pi / 16 and y1 > o.y0 and y0 < o.y1 then
				return true
			end
		end
		return false
	end
	-- the body: a dark core and 24 courses of faces (y 3 .. 34)
	table.insert(U.Stone, H.prism16(2 * 8.7, 31, CFrame.new(0, 18.5, 0) * CFrame.Angles(0, math.pi / 16, 0), MORTAR))
	local ch = 31 / 24
	for c = 0, 23 do
		local y0 = 3 + c * ch
		if y0 + ch > 14.4 and y0 < 15.6 then
			continue -- the band
		end
		-- (2 unions of about 170 faces each: big unions build slowly)
		plateRing(if c < 12 then U.BodyLow else U.BodyHigh, rng, { n = 16, ap = 9.05, d = 0.5, h = ch, y0 = y0, a0 = (c % 2) * math.pi / 16, color = STONE, Ht = 60, skip = skip })
	end
	plateRing(U.Stone, rng, { n = 16, ap = 9.35, d = 0.8, h = 1.2, y0 = 14.4, color = DARK, Ht = 60, chamfer = 0.2, noJitter = true })
	-- the base: 2 battered courses of big blocks (today's 21 x 3)
	plateRing(U.Stone, rng, { n = 14, ap = 10.45, d = 1.4, h = 1.5, y0 = 0, color = DARK, Ht = 60, chamfer = 0.2, noJitter = true, skip = skip })
	plateRing(U.Stone, rng, { n = 14, ap = 10.1, d = 1.2, h = 1.5, y0 = 1.5, a0 = math.pi / 14, color = scaled(DARK, 1.06), Ht = 60, chamfer = 0.25, noJitter = true, skip = skip })
	table.insert(U.Stone, H.prism16(2 * 9.6, 2.9, CFrame.new(0, 1.45, 0), MORTAR))
	-- corbels and the parapet rim, the parapet (y 34 .. 37.6), the merlons
	for k = 0, 15 do
		local a = k * math.pi / 8
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local wdg = Instance.new("WedgePart")
		wdg.Size = Vector3.new(0.7, 1.1, 1.0)
		wdg.CFrame = CFrame.fromMatrix(d * 9.5 + Vector3.new(0, 33.25, 0), Vector3.yAxis:Cross(-d).Unit, Vector3.yAxis, -d) * CFrame.Angles(0, 0, math.pi)
		wdg.Color = DARK
		wdg.Material = Enum.Material.SmoothPlastic
		wdg.Anchored = true
		table.insert(U.Stone, wdg)
	end
	plateRing(U.Stone, rng, { n = 16, ap = 11.25, d = 1.0, h = 0.8, y0 = 33.8, color = DARK, Ht = 60, chamfer = 0.15, noJitter = true })
	for c = 0, 1 do
		plateRing(U.Stone, rng, { n = 18, ap = 10.95, d = 0.8, h = 1.6, y0 = 34.4 + c * 1.6, a0 = c * math.pi / 18, color = LIGHT, Ht = 60 })
	end
	table.insert(U.Stone, H.prism16(2 * 10.5, 3.6, CFrame.new(0, 35.8, 0), MORTAR))
	for _, r in ipairs(KD.rows("Hub_Tower")) do
		if r.name == "Merlon" then
			table.insert(U.Stone, chamfered(r.size - Vector3.new(0, 0.25, 0), r.cf * CFrame.new(0, -0.125, 0), r.color, { "vertical" }, 0.15))
			table.insert(U.Stone, chamfered(Vector3.new(r.size.X + 0.3, 0.25, r.size.Z + 0.3), r.cf * CFrame.new(0, r.size.Y / 2 - 0.125, 0), DARK, { "topFrontBack", "topSides" }, 0.1))
		elseif r.name == "RoofDrum" then
			table.insert(U.Stone, H.prism16(r.size.Y, r.size.X, CFrame.new(r.cf.Position), DARK))
		end
	end
	-- the cone roof (Agent A) and the flag pole
	-- (the 136 facets in 4 unions of about 100 wedges each: big unions build slowly)
	for q = 1, 4 do
		local part = { palette = FAC.tower_cone_roof.palette, tris = {} }
		for i, t in ipairs(FAC.tower_cone_roof.tris) do
			if (i - 1) % 4 == q - 1 then
				table.insert(part.tris, t)
			end
		end
		J.facets(U, part, Vector3.one, CFrame.identity, "Roof" .. q)
	end
	local pole = rowsNamed("Hub_Tower", "FlagPole")[1]
	local pp, plen = pole.cf.Position, pole.size.X
	table.insert(U.Wood, M.frustumN(8, 0.27, 0.22, pp.Y - plen / 2, pp.Y + plen / 2, CFrame.identity, { pole.color, scaled(pole.color, 0.92) }))
	for _, y in ipairs({ pp.Y - plen / 2 + 0.6, pp.Y + 1.5 }) do
		ring(U.Iron, Vector3.new(0, y, 0), Vector3.yAxis, 0.33, 0.2, P.Iron)
	end
	local fin = rowsNamed("Hub_Tower", "Finial")[1]
	ring(U.Gold, fin.cf.Position - Vector3.new(0, 0.5, 0), Vector3.yAxis, 0.3, 0.2, scaled(fin.color, 0.9))
	knob(U.Gold, fin.cf.Position, fin.size.X / 2, fin.color)
	J.facets(U, FAC.flag_cloth, Vector3.one * 0.72, CFrame.new(0, 57.1, 0), "Cloth")
	-- the door: planks with strap hinges, today's frame as chamfered timbers, an arch of 7 dark voussoirs, the step
	local door = rowsNamed("Hub_Tower", "Door")[1]
	plankDoor(U, rng, door, Vector3.new(0, 0, -1), nil)
	for _, r in ipairs(rowsNamed("Hub_Tower", "DoorFrame")) do
		table.insert(U.Wood, H.timber(r.size, r.cf, scaled(r.color, rng:NextNumber(0.92, 1.0))))
	end
	local dp = door.cf.Position
	local archC = Vector3.new(dp.X, dp.Y + door.size.Y / 2 + 0.2, dp.Z - 0.4)
	for k = 0, 6 do
		local a = math.pi * (k + 0.5) / 7
		local up = Vector3.new(-math.sin(a) * 0.55, math.cos(a), 0).Unit
		local pos = archC + Vector3.new(math.cos(a) * 3.6, math.sin(a) * 0.55 * 3.6, 0)
		table.insert(U.Stone, chamfered(Vector3.new(1.5, 0.9, 1.0), CFrame.fromMatrix(pos, up:Cross(Vector3.zAxis), up), scaled(DARK, ({ 1, 0.93, 0.87 })[(k % 3) + 1]), { "topFrontBack" }, 0.12))
	end
	local step = rowsNamed("Hub_Tower", "DoorStep")[1]
	local sp, ss = step.cf.Position, step.size
	for c = 0, 1 do
		local bw = ss.X / 3
		for k = 0, 2 do
			local x0 = sp.X - ss.X / 2 + bw * k + (if c == 1 then bw / 2 else 0)
			local x1 = math.min(x0 + bw, sp.X + ss.X / 2)
			table.insert(U.Stone, chamfered(Vector3.new(x1 - x0 - 0.08, ss.Y / 2 - 0.04, ss.Z), CFrame.new((x0 + x1) / 2, sp.Y - ss.Y / 4 + c * ss.Y / 2, sp.Z), scaled(DARK, ({ 1, 0.93, 0.87 })[((k + c) % 3) + 1]), { "topFrontBack", "topSides" }, 0.15))
		end
		if c == 1 then
			table.insert(U.Stone, chamfered(Vector3.new(bw / 2 - 0.08, ss.Y / 2 - 0.04, ss.Z), CFrame.new(sp.X - ss.X / 2 + bw / 4, sp.Y + ss.Y / 4, sp.Z), DARK, { "topFrontBack", "topSides" }, 0.15))
		end
	end
	-- windows: glass, cross bars, a dark sill and lintel, 2 small shutters
	for _, r in ipairs(rowsNamed("Hub_Tower", "Window")) do
		local face = r.cf -- local -Z = outward (front)
		table.insert(U.Glass, piece("Part", r.size - Vector3.new(0, 0, 0.1), r.cf * CFrame.new(0, 0, 0.05), r.color))
		table.insert(U.Wood, piece("Part", Vector3.new(0.18, r.size.Y, 0.15), r.cf * CFrame.new(0, 0, -r.size.Z / 2), P.WoodDark))
		table.insert(U.Wood, piece("Part", Vector3.new(r.size.X, 0.18, 0.15), r.cf * CFrame.new(0, 0, -r.size.Z / 2), P.WoodDark))
		for _, y in ipairs({ -1, 1 }) do
			table.insert(U.Stone, chamfered(Vector3.new(r.size.X + 1.2, 0.45, 1.5), face * CFrame.new(0, y * (r.size.Y / 2 + 0.55), -0.2), DARK, { "topFrontBack", "topSides" }, 0.1))
		end
		for _, sx in ipairs({ -1, 1 }) do
			for k = 0, 1 do
				table.insert(U.Wood, chamfered(Vector3.new(0.55, r.size.Y + 0.2, 0.14), face * CFrame.new(sx * (r.size.X / 2 + 0.38 + k * 0.6), 0, -r.size.Z / 2 - 0.05), scaled(P.WoodMid, ({ 1, 0.9 })[k + 1]), { "vertical" }, 0.03))
			end
			table.insert(U.Iron, piece("Part", Vector3.new(1.0, 0.14, 0.06), face * CFrame.new(sx * (r.size.X / 2 + 0.65), r.size.Y * 0.3, -r.size.Z / 2 - 0.14), P.Iron))
		end
	end
	for _, r in ipairs(rowsNamed("Hub_Tower", "WindowFrame")) do
		table.insert(U.Wood, H.timber(r.size, r.cf, scaled(r.color, rng:NextNumber(0.92, 1.0))))
	end
	-- moss at the foot
	for k = 0, 5 do
		local a = k * math.pi / 3 + 0.4
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		if math.abs(a - math.pi * 1.5) > 0.5 then
			footMoss(U.Plants, rng, d * 10.6, Vector3.new(-d.Z, 0, d.X), rng:NextNumber(2.0, 3.0))
		end
	end
	finishB4(m, "stone_tower", U, "Stone", { Plants = { shadow = false }, Glow = { material = Enum.Material.Neon, shadow = false } })
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("PartOperation") then
			p.CanQuery = p.Name == "Stone"
		end
	end
	kitCollision(m, "Hub_Tower")
	return m
end

---------------------------------------------------------------------
-- 11 SIGNPOST + LECTERN + LANTERN PLATFORM (kit MapAssets.Hub.Station_TutorialGuide; the hub copy is workspace.Hub.
-- TutorialGuide, the marker of the Guide NPC (Config/NPCs Marker "TutorialGuide"): a round stone Platform 12 x 0.6 with
-- a darker PlatformRim 13, a lectern (LecternPost 1.2 x 3.4, LecternFoot, a LecternTop tilted 22 deg, 2 Book parts), a
-- signpost (SignPost 0.8 x 9, a Board 4.4 x 1.3 pointing +X, an ArrowBoard 4.0 x 1.2 pointing -X, 4 ArrowTip wedges, a
-- gold Finial ball), the nested Lantern (the "lantern" MapProp), the invisible NpcSpot and Interact (ProximityPrompt
-- "Talk" / "Guide", BillboardGui NameTag); 3 copies: test, kit, Hub.TutorialGuide)
---------------------------------------------------------------------
-- The guide platform (guide D4): today's platform as a ring of 12 bevelled stone blocks around an inset centre disc
-- with a carved 4-point compass star, on a darker kerb ring of 16 blocks (the walking surface stays at y 0.6); the signpost
-- chamfered with a pyramid cap and today's gold finial as a faceted ball on a collar, 2 iron bands with nails; today's
-- 2 arrow boards as 2-plank boards with their pointed tips (today's wedges); the lectern on a cross foot, its post
-- chamfered with 2 rings, its slanted top with a lip and Agent A's open book (pages, text lines, a picture, a red
-- bookmark) in place of the 2 Book parts. The nested Lantern, NpcSpot, Interact and the NPC are kept by the sync (the
-- template has none of them). Today's colliding parts (not the lantern's) stay the exact colliders.
-- Parts: Stone, Wood, Iron, Gold, Book, Collision.
function B4.tutorial_guide(): Model
	local m = Instance.new("Model")
	m.Name = "tutorial_guide"
	local rng = Random.new(20261412)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Wood = {}, Iron = {}, Gold = {} }
	local STONE, DARK = rgb(150, 156, 168), rgb(104, 110, 124)
	-- platform: kerb ring (top 0.35), the main ring (top 0.6), the inset centre disc with a compass star
	H.ringBlocks(U.Stone, rng, { n = 16, ro = 6.55, ri = 5.7, y0 = -0.05, h = 0.4, c = 0.12, color = DARK, H = 10 })
	H.ringBlocks(U.Stone, rng, { n = 12, ro = 6.05, ri = 2.55, y0 = -0.05, h = 0.65, c = 0.15, color = STONE, H = 10, a0 = math.pi / 12 })
	table.insert(U.Stone, H.prism16(2 * 2.5, 0.6, CFrame.new(0, 0.25, 0), scaled(STONE, 1.06)))
	-- a 4-point compass star (kites along the 4 axes, symmetric) inlaid 0.04 in the centre disc
	for k = 0, 3 do
		local a = k * math.pi / 2
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local side = Vector3.new(-d.Z, 0, d.X)
		local y = 0.56
		local tip, l, r, c = d * 2.1, d * 0.45 + side * 0.32, d * 0.45 - side * 0.32, Vector3.zero
		H.triangleParts(U.Stone, c + Vector3.new(0, y, 0), l + Vector3.new(0, y, 0), tip + Vector3.new(0, y, 0), 0.04, CFrame.identity, DARK)
		H.triangleParts(U.Stone, c + Vector3.new(0, y, 0), tip + Vector3.new(0, y, 0), r + Vector3.new(0, y, 0), 0.04, CFrame.identity, scaled(DARK, 1.12))
	end
	-- the signpost
	local post = rowsNamed("Station_TutorialGuide", "SignPost")[1]
	local pp = post.cf.Position
	table.insert(U.Wood, chamfered(post.size - Vector3.new(0, 0.35, 0), post.cf * CFrame.new(0, -0.15, 0), graded(post.color, pp.Y, 10), { "vertical" }, 0.12))
	table.insert(U.Wood, M.frustumN(4, 0.58, 0.12, pp.Y + post.size.Y / 2 - 0.5, pp.Y + post.size.Y / 2 - 0.1, CFrame.new(pp.X, 0, pp.Z) * CFrame.Angles(0, rad(45), 0), { scaled(post.color, 1.05), post.color }))
	local fin = rowsNamed("Station_TutorialGuide", "Finial")[1]
	ring(U.Gold, fin.cf.Position - Vector3.new(0, 0.55, 0), Vector3.yAxis, 0.3, 0.2, scaled(fin.color, 0.9))
	knob(U.Gold, fin.cf.Position, fin.size.X / 2, fin.color)
	for _, name in ipairs({ "Board", "ArrowBoard" }) do
		local b = rowsNamed("Station_TutorialGuide", name)[1]
		local bp, bs = b.cf.Position, b.size
		for k = 0, 1 do
			table.insert(U.Wood, chamfered(Vector3.new(bs.X, bs.Y / 2 - 0.04, bs.Z), CFrame.new(bp.X, bp.Y - bs.Y / 4 + k * bs.Y / 2, bp.Z), scaled(b.color, ({ 1, 0.92 })[k + 1]), { "topFrontBack", "bottomFrontBack" }, 0.06))
		end
		-- the iron band holding it on the post, with nails
		table.insert(U.Iron, piece("Part", Vector3.new(0.95, 0.22, post.size.Z + 0.1), CFrame.new(pp.X, bp.Y, pp.Z), P.Iron))
		nail(U.Iron, Vector3.new(pp.X, bp.Y, pp.Z - post.size.Z / 2 - 0.07))
		nail(U.Iron, Vector3.new(bp.X + (if bp.X > pp.X then 1 else -1) * (bs.X / 2 - 0.4), bp.Y, bp.Z - bs.Z / 2 - 0.03))
	end
	for _, w in ipairs(rowsNamed("Station_TutorialGuide", "ArrowTip")) do
		local p = Instance.new("WedgePart")
		p.Size, p.CFrame, p.Color, p.Material, p.Anchored = w.size, w.cf, w.color, Enum.Material.SmoothPlastic, true
		table.insert(U.Wood, p)
	end
	-- the lectern
	local lp = rowsNamed("Station_TutorialGuide", "LecternPost")[1]
	local lpp = lp.cf.Position
	table.insert(U.Wood, chamfered(lp.size - Vector3.new(0.3, 0, 0.3), lp.cf, lp.color, { "vertical" }, 0.15))
	for _, y in ipairs({ lpp.Y - 0.8, lpp.Y + 1.2 }) do
		table.insert(U.Wood, chamfered(Vector3.new(1.15, 0.22, 1.15), CFrame.new(lpp.X, y, lpp.Z), P.WoodMid, { "vertical" }, 0.1))
	end
	local lf = rowsNamed("Station_TutorialGuide", "LecternFoot")[1]
	for _, yaw in ipairs({ 0, 90 }) do
		table.insert(U.Wood, chamfered(Vector3.new(lf.size.X, lf.size.Y, 0.55), lf.cf * CFrame.Angles(0, rad(yaw), 0), lf.color, { "topFrontBack", "topSides" }, 0.08))
	end
	local lt = rowsNamed("Station_TutorialGuide", "LecternTop")[1]
	table.insert(U.Wood, chamfered(lt.size, lt.cf, lt.color, { "topFrontBack", "topSides" }, 0.08))
	table.insert(U.Wood, chamfered(Vector3.new(lt.size.X, 0.18, 0.16), lt.cf * CFrame.new(0, lt.size.Y / 2 + 0.06, -lt.size.Z / 2 + 0.08), scaled(lt.color, 0.9), { "topFrontBack" }, 0.04))
	local rx = select(1, lt.cf:ToEulerAnglesXYZ())
	local topC = lt.cf * Vector3.new(0, lt.size.Y / 2, 0)
	J.facets(U, FAC.guide_open_book, Vector3.one, CFrame.new(topC.X, topC.Y, topC.Z - 0.05) * CFrame.Angles(rx, 0, 0), "Book")
	finishB4(m, "tutorial_guide", U, "Stone")
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("PartOperation") then
			p.CanQuery = p.Name == "Stone"
		end
	end
	kitCollision(m, "Station_TutorialGuide", function(r)
		return string.sub(r.name, 1, 8) == "Lantern." or r.name == "Interact" or r.name == "NpcSpot"
	end)
	return m
end

-- 02 GREEN TENT (the tent inside MapAssets.Plains.HunterCamp: 2 TentCloth wedges 11 x 7.5 x 5 #68A848 (opaque, but the
-- colour of the plains grass: it melted into the ground behind it), 2 TentEntrance wedges, 3 TentPoles (2 x 8.1 tall,
-- a 13 ridge); 3 hosts: test, kit, Plains_3.Decor.HunterCamp; the embedded rule "tent_green" wraps them into a "Tent"
-- model, pivot = the bottom centre of the group, ridge along Z)
-- The green tent (guide D3): the same plains tent recipe at 0.92 (ridge 13, height 8), in an opaque olive canvas #7A8A3C
-- / #6E7E35 with #66752F seams, linen bindings, a light olive #9AA65A lining (so the front reads green too), a brown and
-- linen rug, a rolled bedroll inside the open door
-- and grass tufts; Transparency 0 everywhere. Today's 7 tent parts (Data.HunterTent, read from the kit's wrapper) stay
-- the exact colliders. Parts: Canvas, Lining, Wood, Gold, Ground, Plants, Collision x7.
function B4.tent_green(): Model
	local s = 0.92
	local rows = KD.rows("HunterTent")
	-- the door end: the entrance flaps' side of the ridge (the recipe's door is at -Z)
	local ez = 0
	for _, r in ipairs(rows) do
		if r.name == "TentEntrance" then
			ez += r.cf.Position.Z
		end
	end
	local m = tentModel("tent_green", { seed = 20261413, canvas = rgb(122, 138, 60), canvasAlt = rgb(110, 126, 53), seam = rgb(102, 117, 47), binding = LINEN, lining = rgb(154, 166, 90), rug = rgb(168, 98, 56), rugStripe = LINEN, bedroll = true })
	local turn = if ez > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			p.Size *= s
			p.CFrame = turn * (CFrame.new(p.Position * s) * p.CFrame.Rotation)
		end
	end
	m.PrimaryPart.PivotOffset = m.PrimaryPart.CFrame:Inverse()
	kitCollision(m, "HunterTent")
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table as the jungle props; its install() builds them
---------------------------------------------------------------------
B4.BUILDERS = { barrel = true, cottage_one_window = true, cottage_two_windows = true, house_blue_roof = true, ladder = true, fence_section = true, wooden_post = true, sign_board = true, banner_diamond = true, flagpole = true, standing_torch = true, wall_torch = true, spiked_mace = true, tent_red_white = true, tent_red = true, stone_tower = true, tutorial_guide = true, tent_green = true, sign_board_dark = true }
for id in pairs(B4.BUILDERS) do
	B2[id] = (B4 :: any)[id]
	B2.BUILDERS[id] = true
end
B4.install = B2.install
B4.FIREPOINT = FIREPOINT
B4.KD = KD

return B4
