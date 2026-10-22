--[[
	PropsTundraProps (dev tool, Edit mode only) - the owner's "TUNDRA (SNOW BIOME) PROP IMPROVEMENT - Props and decor"
	(2026-10-22): the frozen skeleton in ice, the ice fishing hole, the sled, the snowman with the gray hat, the snowman
	with the blue hat and the ice drying rack, to the fountain / well quality in the tundra look (docs/prop_texture_guide.md
	sections A, E, E10), keeping each object's colours, place, size and collision. Source of truth:
	tools/PropsTundraProps.luau. Inventory: docs/prop_inventory.md "Tundra props".

	Collision: the visible unions never collide; every part that collides today is an invisible "Collision" copy of it
	(DevTools.PropsTundraPropsData = the kits; MeshParts cloned from a source with today's mesh and collision fidelity).
	None of the 6 has a prompt, a script or a light.

	It uses DevTools.PropsTundraGates (and through it the tundra buildings' snow and ice helpers and Agent A's E7 facets)
	and Agent A's E10 facets (DevTools.PropsTundraPropsSolids) and registers its builders into the same PropsBatch2 table:
		local TP = require(game.ServerStorage.DevTools.PropsTundraProps:Clone())
		print(TP.install("tundra_snowman_gray"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "tundra_snowman_gray" } }), Sync.run({ only = { "tundra_snowman_gray" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local TG = require(ServerStorage.DevTools.PropsTundraGates:Clone()) :: any
local TB = TG.TB
local B2, H, M = TB.B2, TB.H, TB.M
local piece, chamfered = H.piece, H.chamfered
local scaled = H.scaled
local frustumN = M.frustumN
local lump, snowTone, facetIcicle, facetPiece = TB.lump, TB.snowTone, TB.facetIcicle, TB.facetPiece
local TS = TB.TS -- the tundra buildings' E7 facets (snow caps, drifts, ice shards, icicles)
local PD = require(ServerStorage.DevTools.PropsTundraPropsData:Clone()) :: any
local PS = require(ServerStorage.DevTools.PropsTundraPropsSolids:Clone()) :: any -- Agent A's E10 facets

local TP = {}

local rgb = Color3.fromRGB
local rad = math.rad
local UP = Vector3.yAxis

local COAL = rgb(31, 34, 43) -- #1F222B today's eyes / buttons
local COAL_LIT = rgb(56, 60, 76)
local TWIG = rgb(92, 66, 54) -- #5C4236 today's arms
local TWIG_D = rgb(74, 52, 42)

local function rowsNamed(kit: string, name: string?): { any }
	local out = {}
	for _, r in ipairs(PD.rows(kit)) do
		if name == nil or r.name == name then
			table.insert(out, r)
		end
	end
	return out
end
TP.rowsNamed = rowsNamed

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
	for _, r in ipairs(PD.rows(kit)) do
		if r.collide and not (keep and keep[r.name]) then
			local p: BasePart
			if r.class == "MeshPart" then
				local src = meshSourceFid(r.meshId, r.fidelity)
				assert(src, `PropsTundraProps: no MeshPart with {r.meshId} ({r.fidelity}) to clone`)
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
TP.collisionRows = collisionRows

-- a coal lump (a, b, c half sizes) facing out along `out` at p
local function coal(list: { BasePart }, rng: Random, p: Vector3, out: Vector3, a: number, b: number, c: number)
	lump(list, rng, CFrame.lookAt(p, p + out) * CFrame.Angles(0, 0, rng:NextNumber(0, 6.28)), a, b, c, function(n: Vector3): Color3
		return if n.Y > 0.35 then COAL_LIT else COAL
	end)
end
TP.coal = coal

-- a point on a ball's surface (centre c, radius r) at azimuth az (0 = front, -Z) and elevation el, pushed in by `sink`
local function onBall(c: Vector3, r: number, az: number, el: number, sink: number?): (Vector3, Vector3)
	local d = Vector3.new(math.sin(az) * math.cos(el), math.sin(el), -math.cos(az) * math.cos(el))
	return c + d * (r - (sink or 0)), d
end

-- a stick from a to b (radius r0 -> r1) as an 8-sided frustum
local function stick(list: { BasePart }, a: Vector3, b: Vector3, r0: number, r1: number, color: Color3)
	table.insert(list, frustumN(8, r0, r1, 0, (b - a).Magnitude, H.frameY(a, b - a), { color, scaled(color, 1.12), scaled(color, 0.9) }))
end
TP.stick = stick

-- a stick arm along a kit row (its long X axis, the inner end nearer `body`): an 8-sided stick tapering to the tip,
-- 2 twigs (0.08 thick, 0.6 long, 35 deg, one up, one down / out) and a fork at the end, inside today's length
local function stickArm(list: { BasePart }, row: any, body: Vector3)
	local cf, L = row.cf, row.size.X
	local e1, e2 = cf.Position - cf.XVector * L / 2, cf.Position + cf.XVector * L / 2
	local inner, outer = e1, e2
	if (e2 - body).Magnitude < (e1 - body).Magnitude then
		inner, outer = e2, e1
	end
	local dir = (outer - inner).Unit
	local perp = Vector3.zAxis:Cross(dir).Unit
	if perp.Y < 0 then
		perp = -perp
	end
	local t = row.size.Y
	local tip = outer - dir * 0.04
	stick(list, inner, tip, t * 0.55, t * 0.3, row.color)
	local twigs = {
		{ 0.5, (dir * math.cos(rad(35)) + perp * math.sin(rad(35))).Unit, 0.6 },
		{ 0.66, (dir * math.cos(rad(35)) - perp * math.sin(rad(25)) + Vector3.zAxis * 0.3).Unit, 0.5 },
	}
	for _, tw in ipairs(twigs) do
		local a = inner + dir * L * tw[1]
		stick(list, a, a + tw[2] * tw[3], 0.045, 0.025, TWIG_D)
	end
	-- the fork: 2 short prongs from 0.86 of the length, ending inside today's tip
	local f0 = inner + dir * L * 0.86
	for _, s in ipairs({ -1, 1 }) do
		local d = (dir * math.cos(rad(28)) + perp * s * math.sin(rad(28))).Unit
		stick(list, f0, f0 + d * L * 0.15, t * 0.26, t * 0.12, row.color)
	end
end

-- a ring of n chamfered segments (radius R at the frame F, XZ plane, section w radial x h tall)
local function ring(list: { BasePart }, F: CFrame, R: number, w: number, h: number, n: number, colorOf: (number) -> Color3, y: number?)
	for k = 0, n - 1 do
		local a = (k + 0.5) * 2 * math.pi / n
		local dir = F:VectorToWorldSpace(Vector3.new(math.cos(a), 0, math.sin(a)))
		local tan = F:VectorToWorldSpace(Vector3.new(-math.sin(a), 0, math.cos(a)))
		local up = F.YVector
		table.insert(list, chamfered(Vector3.new(2 * math.pi * R / n + 0.04, h, w), CFrame.fromMatrix(F.Position + up * (y or 0) + dir * R, tan, up), colorOf(k), { "topFrontBack", "bottomFrontBack" }, math.min(w, h) * 0.3))
	end
end
TP.ring = ring

-- a top hat standing on `base` along `axis`: a brim (brimR, brimT; an optional 0.1-proud edge ring), the crown (crownR,
-- up to height h, a slight flare), a band (bandH tall), a lid and Agent A's snow cap on the lid
local function topHat(U: any, rng: Random, base: Vector3, axis: Vector3, o: any)
	local F = H.frameY(base, axis) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	local hat = o.color
	local dark, light = scaled(hat, 0.86), scaled(hat, 1.14)
	local brimR, brimT, crownR, h = o.brimR, o.brimT, o.crownR, o.h
	table.insert(U.Hat, frustumN(16, brimR - 0.05, brimR, 0, brimT * 0.5, F, { hat, dark }))
	table.insert(U.Hat, frustumN(16, brimR, brimR - 0.06, brimT * 0.5, brimT, F, { light, hat }))
	if o.lip then
		ring(U.Hat, F, brimR - 0.07, 0.12, 0.1, 20, function(): Color3
			return light
		end, brimT + 0.04)
	end
	table.insert(U.Hat, frustumN(16, crownR * 0.97, crownR * 1.03, brimT - 0.02, h - 0.05, F, { hat, light, hat, dark }))
	table.insert(U.Hat, frustumN(16, crownR * 1.03, crownR * 0.98, h - 0.05, h, F, { light }))
	table.insert(U.Hat, frustumN(16, crownR * 0.97 + 0.03, crownR * (0.97 + 0.06 * o.bandH / h) + 0.03, brimT, brimT + o.bandH, F, { o.band, scaled(o.band, 1.15) }))
	facetPiece(U, TS.tundra_snow__cap, F * CFrame.new(0, h - 0.02, 0), Vector3.new(o.cap, 0.2, o.cap), "Snow", "Snow")
end

---------------------------------------------------------------------
-- 04 / 05 SNOWMEN (kits MapAssets.Tundra.Snowman_B: the gray bucket hat, the purple scarf, 11 parts, 6.7 x 8 x 3.7;
-- Snowman_A: the blue-gray top hat, 2 buttons, 12 parts, 8.4 x 10 x 4.5; 6 copies each: test, kit, Tundra_1 x3 /
-- x4, Tundra_2 x1 / -)
---------------------------------------------------------------------
-- One recipe for both (guide E10): today's 3 balls as Agent A's soft bumpy snowballs (the white one on the white balls,
-- the shaded one on today's #CEDEF6 balls; each turned a different yaw) with a collar of packed snow where they meet;
-- 2 small drifts at the foot; a top hat with a band on today's hat (the gray one keeps today's 8 deg tilt), Agent A's
-- snow cap on the crown; chunky coal eyes at today's places, a smile of 5 coal pebbles, 3 coal buttons; Agent A's
-- carrot on today's nose (a slight droop); stick arms on today's arms (8-sided, tapering, 2 twigs, a fork); the gray
-- one's knitted scarf: 2 rolled turns with 3 darker stripes each, a knot at the front left, today's tail as 2 hanging
-- ends with stripes and a fringe. Colliders: today's 3 balls. Parts: Snow, Coal, Carrot, Twig, Hat, Scarf, Collision x3.
local function snowman(propId: string, kit: string, seed: number, o: any): Model
	local m = Instance.new("Model")
	m.Name = propId
	local rng = Random.new(seed)
	H.setBevelSelf(true)
	local U: any = { Snow = {}, Coal = {}, Carrot = {}, Twig = {}, Hat = {}, Scarf = {} }
	local function row(name: string): any
		return rowsNamed(kit, name)[1]
	end
	local base, body, head = row("Base"), row("Body"), row("Head")
	local balls = { base, body, head }
	for i, b in ipairs(balls) do
		local pc = if b.color == rgb(206, 222, 246) then PS.tundra_props__snowball_shade else PS.tundra_props__snowball
		facetPiece(U, pc, CFrame.new(b.cf.Position) * CFrame.Angles(0, rad(40 + i * 97), 0), Vector3.one * (b.size.X / 2), "Snow", "Snow")
	end
	-- the collars where the balls meet
	for i = 1, 2 do
		local lo, hi = balls[i], balls[i + 1]
		local cl, rl = lo.cf.Position, lo.size.X / 2
		local ch, rh = hi.cf.Position, hi.size.X / 2
		local axis = ch - cl
		local dd = axis.Magnitude
		axis = axis.Unit
		local x = (dd * dd + rl * rl - rh * rh) / (2 * dd)
		local rr = math.sqrt(math.max(rl * rl - x * x, 0.01))
		local cc = cl + axis * x
		local F = H.frameY(cc, axis)
		for k = 0, 6 do
			local a = k * 2 * math.pi / 7 + rng:NextNumber(-0.2, 0.2)
			local dir = F.XVector * math.cos(a) + F.ZVector * math.sin(a)
			lump(U.Snow, rng, CFrame.fromMatrix(cc + dir * (rr - 0.09), dir:Cross(axis), axis), rh * 0.1, rh * 0.07, rh * 0.32, snowTone)
		end
	end
	-- 2 small drifts at the foot, along the ball, left and right (inside today's footprint)
	local bc, br = base.cf.Position, base.size.X / 2
	for _, a in ipairs({ 0.15, math.pi - 0.2 }) do
		facetPiece(U, TS.tundra_snow__drift, CFrame.new(bc.X + math.cos(a) * br * 0.92, 0, bc.Z + math.sin(a) * br * 0.92) * CFrame.Angles(0, -(a + math.pi / 2), 0), Vector3.new(2.4 * br / 1.8, 0.32, 1.0) * math.min(1, br / 1.8 + 0.1), "Snow", "Snow")
	end
	-- the face: chunky coal eyes at today's places (0.1 proud), a coal smile, Agent A's carrot on today's nose
	local hc, hr = head.cf.Position, head.size.X / 2
	for _, e in ipairs(rowsNamed(kit, "Eye")) do
		local d = (e.cf.Position - hc).Unit
		coal(U.Coal, rng, hc + d * (hr - 0.02), d, e.size.X * 0.52, e.size.X * 0.5, 0.12)
	end
	for i = -2, 2 do
		local p, d = onBall(hc, hr, rad(i * 14), rad(-38 + math.abs(i) * 5), 0.02)
		coal(U.Coal, rng, p, d, 0.09, 0.09, 0.07)
	end
	facetPiece(U, PS.tundra_props__carrot, CFrame.new(o.nose) * CFrame.Angles(rad(-6), 0, 0), Vector3.one * o.noseScale, "Carrot", "Carrot")
	-- the buttons
	for _, b in ipairs(o.buttons) do
		local bb = if b.ball == "Body" then body else base
		local p, d = onBall(bb.cf.Position, bb.size.X / 2, rad(b.az or 0), rad(b.el), 0.02)
		coal(U.Coal, rng, p, d, o.button / 2, o.button / 2, 0.1)
	end
	-- the arms
	for _, a in ipairs(rowsNamed(kit, "Arm")) do
		stickArm(U.Twig, a, body.cf.Position)
	end
	-- the hat
	topHat(U, rng, o.hat.base, o.hat.axis, o.hat)
	-- the knitted scarf (the gray one): 2 rolled turns, 3 darker stripes each, the knot, 2 hanging ends
	if o.scarf then
		local sc = row("Scarf")
		local c0 = sc.cf.Position
		local R = sc.size.Y / 2
		local purple, stripe = sc.color, rgb(154, 138, 204) -- #BAAAEC, #9A8ACC
		local hh = sc.size.X
		for turn = 0, 1 do
			local F = CFrame.new(c0 + Vector3.new(0, (turn - 0.5) * hh * 0.46, 0)) * CFrame.Angles(0, turn * rad(40) + rad(10), 0)
			local w = 0.4
			ring(U.Scarf, F, R - w / 2 + 0.02 - turn * 0.03, w, hh * 0.56, 18, function(k: number): Color3
				return if k % 6 == 2 then stripe elseif k % 2 == 0 then purple else scaled(purple, 1.04)
			end)
		end
		-- the knot (0.5 across) at the front left, over today's tail
		local tail = row("ScarfTail")
		local tp = tail.cf.Position
		local kd = Vector3.new(tp.X - c0.X, 0, tp.Z - c0.Z).Unit
		local kp = c0 + kd * (R - 0.05) + Vector3.new(0, -0.08, 0)
		lump(U.Scarf, rng, CFrame.lookAt(kp, kp + kd), 0.25, 0.23, 0.2, function(n: Vector3): Color3
			return if n.Y > 0.3 then scaled(purple, 1.06) else purple
		end)
		-- 2 hanging ends: today's tail and a shorter one beside it; stripes, a fringe of 4 thin wedges
		local function tailEnd(cf: CFrame, len: number, wd: number, th: number)
			local n = 6
			for i = 0, n - 1 do
				local col = if i == 1 or i == 4 then stripe else purple
				table.insert(U.Scarf, chamfered(Vector3.new(wd, len / n + 0.02, th), cf * CFrame.new(0, len / 2 - (i + 0.5) * len / n, 0), col, { "vertical" }, 0.05))
			end
			for i = 0, 3 do
				local x = (i - 1.5) * wd / 4.4
				table.insert(U.Scarf, piece("WedgePart", Vector3.new(0.06, 0.15, th * 0.7), cf * CFrame.new(x, -len / 2 - 0.075, 0) * CFrame.Angles(0, 0, math.pi), scaled(purple, 0.95)))
			end
		end
		tailEnd(tail.cf, tail.size.Y, tail.size.X, tail.size.Z)
		tailEnd(tail.cf * CFrame.new(0.26, 0.15, 0.08) * CFrame.Angles(0, 0, rad(-12)), tail.size.Y * 0.74, tail.size.X * 0.85, tail.size.Z * 0.9)
	end

	TB.finishTB(m, propId, U, "Snow", {})
	collisionRows(m, kit)
	return m
end

-- 04: today's gray bucket (#5C626E, tilted 8 deg) as a gray top hat (crown 1.5, brim 2.3 x 0.15, a #3E4C66 band 0.25);
-- today's purple scarf; 3 coal buttons 0.32 on the body
function TP.tundra_snowman_gray(): Model
	local kit = "Snowman_B"
	local b = rowsNamed(kit, "Bucket")[1]
	local axis = b.cf.XVector
	if axis.Y < 0 then
		axis = -axis
	end
	local len = b.size.X
	return snowman("tundra_snowman_gray", kit, 20261804, {
		scarf = true,
		nose = Vector3.new(0.35, 5.6, -0.7),
		noseScale = 0.86,
		button = 0.32,
		buttons = { { ball = "Body", el = 14 }, { ball = "Body", el = -12 }, { ball = "Body", el = -38 } },
		hat = { base = b.cf.Position - axis * len / 2, axis = axis, brimR = 1.15, brimT = 0.15, crownR = 0.75, h = len, color = b.color, band = rgb(62, 76, 102), bandH = 0.25, cap = 1.35 },
	})
end

-- 05: today's blue-gray top hat (#4E566E: brim 2.7 x 0.3 with a 0.1-proud edge, crown 1.8) with a blue #3468B4 band
-- 0.3; today's 2 buttons as coal lumps 0.4 and a third on the base ball
function TP.tundra_snowman_blue(): Model
	local kit = "Snowman_A"
	local brim = rowsNamed(kit, "HatBrim")[1]
	local crown = rowsNamed(kit, "Hat")[1]
	local y0 = brim.cf.Y - brim.size.X / 2
	local y1 = crown.cf.Y + crown.size.X / 2
	local btn = {}
	for _, r in ipairs(rowsNamed(kit, "Button")) do
		local d = (r.cf.Position - rowsNamed(kit, "Body")[1].cf.Position).Unit
		table.insert(btn, { ball = "Body", el = math.deg(math.asin(d.Y)) })
	end
	table.insert(btn, { ball = "Base", el = 30 })
	return snowman("tundra_snowman_blue", kit, 20261805, {
		scarf = false,
		nose = Vector3.new(0, 6.9, -0.9),
		noseScale = 1.0,
		button = 0.4,
		buttons = btn,
		hat = { base = Vector3.new(brim.cf.X, y0, brim.cf.Z), axis = UP, brimR = brim.size.Y / 2, brimT = brim.size.X, crownR = crown.size.Y / 2, h = y1 - y0, color = crown.color, band = rgb(52, 104, 180), bandH = 0.3, lip = true, cap = 1.5 },
	})
end

---------------------------------------------------------------------
-- shared: Agent A's convex ice pieces (their planes) for surface points
---------------------------------------------------------------------
-- where a ray from o along dir leaves a convex solid (planes { nx, ny, nz, d }): the point and the plane's normal
local function exitOf(sd: any, o: Vector3, dir: Vector3): (Vector3, Vector3)
	local best, bn = math.huge, Vector3.yAxis
	for _, p in ipairs(sd.planes) do
		local n = Vector3.new(p[1], p[2], p[3])
		local k = n:Dot(dir)
		if k > 1e-6 then
			local t = (p[4] - n:Dot(o)) / k
			if t < best then
				best, bn = t, n
			end
		end
	end
	return o + dir * best, bn.Unit
end
TP.exitOf = exitOf

-- a thin irregular 5-sided frost patch (radius r) lying on a face (point p, normal n), 0.03 proud
local function frostPatch(list: { BasePart }, rng: Random, p: Vector3, n: Vector3, r: number, color: Color3)
	local F = H.frameY(p, n)
	local planes = { { 0, 1, 0, 0.03 }, { 0, -1, 0, 0.02 } }
	local a0 = rng:NextNumber(0, 6.28)
	for k = 0, 4 do
		local a = a0 + k * 2 * math.pi / 5 + rng:NextNumber(-0.25, 0.25)
		table.insert(planes, { math.cos(a), 0, math.sin(a), r * rng:NextNumber(0.7, 1.1) })
	end
	local e = Vector3.new(r * 1.5, 0.1, r * 1.5)
	table.insert(list, H.convexSolid(-e, e, F, color, planes))
end

local BONE = rgb(240, 232, 208) -- #F0E8D0 today's bones
local BONE_D = rgb(214, 206, 184)
local FROST = rgb(242, 246, 248) -- #F2F6F8

---------------------------------------------------------------------
-- 01 FROZEN SKELETON IN ICE (kit MapAssets.Tundra.Bone_Pile_Ice, 18 parts, 7.3 x 3.2 x 5.8; 11 copies: test, kit,
-- Tundra_3 x3 (one on a ledge at y 8), Tundra_4 x1, BossArenas x5 at 1.5)
---------------------------------------------------------------------
-- Owner follow-up (2026-10-22): not remodelled - the PLAINS biome's finished skull-and-bones (the `skull_bones` MapProp:
-- the skull with the sad face and dark eyes, 2 crossed bones with knobbed ends, the curved rib cage; its 3 MeshParts
-- Bones / Aged / Sockets) is duplicated here, compacted (x 0.76 round the point under today's skull, so the pose fits
-- today's tundra footprint) and frozen in Agent A's faceted translucent ice block (Glass T 0.4, light edges, the
-- darker inner facets: the gradient), the block widened to hold it (x 1.2, y 1.05, z 1.15, moved 1.0 left and 0.4 to
-- the front; checked on the meshes' vertices: about 3 % of them are outside); a thin glass ice layer over the bits
-- that stick out; frost (small rime flakes) on the bones' tops; 4 frost patches on the ice; a soft snow cap on the
-- top toward the back; 3 small icicles under the block's upper edges; Agent A's ice shards at 2 feet.
-- Colliders: today's 16 bone parts, exactly. Parts: Bones, Aged, Sockets (the plains meshes), Ice, Frost, Shards, Snow,
-- Icicles, Collision x16.
local SKEL = {
	s = 0.76, -- the plains skull-and-bones' scale, round g (the ground under today's skull)
	g = Vector3.new(0.3, 0, 0.2),
	d = Vector3.new(0.15, 0, -0.15), -- and moved by d
	iceS = Vector3.new(1.2, 1.05, 1.15), -- Agent A's ice block scaled round c and moved by iceOff
	c = Vector3.new(0.5, 0, 0.53),
	iceOff = Vector3.new(-1.0, 0, -0.4),
}
TP.SKEL = SKEL

function TP.tundra_frozen_skeleton(): Model
	local AssetService = game:GetService("AssetService")
	local m = Instance.new("Model")
	m.Name = "tundra_frozen_skeleton"
	local rng = Random.new(20261801)
	H.setBevelSelf(true)
	local U: any = { Ice = {}, Frost = {}, Shards = {}, Snow = {}, Icicles = {} }
	local kit = "Bone_Pile_Ice"
	-- Agent A's ice block, scaled and moved (its planes kept for the surface points below)
	local ice = PS.tundra_props__skeleton_ice
	local T = SKEL.c + SKEL.iceOff - SKEL.c * SKEL.iceS
	facetPiece(U, ice, CFrame.new(T), SKEL.iceS, "Ice", "Ice")
	local sd = ice.solids[1]
	local function toLocal(q: Vector3): Vector3
		return (q - T) / SKEL.iceS
	end
	local function depth(q: Vector3): number
		local p = toLocal(q)
		local w = -math.huge
		for _, pl in ipairs(sd.planes) do
			local n = Vector3.new(pl[1], pl[2], pl[3])
			w = math.max(w, (n:Dot(p) - pl[4]) / n.Magnitude)
		end
		return w
	end
	local function exitAt(o: Vector3, dir: Vector3): (Vector3, Vector3)
		local p, n = exitOf(sd, toLocal(o), dir / SKEL.iceS)
		return T + p * SKEL.iceS, (n / SKEL.iceS).Unit
	end
	-- the plains skull-and-bones: its 3 MeshParts, compacted and placed
	local src = ServerStorage.MapProps:FindFirstChild("skull_bones")
	assert(src, "PropsTundraProps: ServerStorage.MapProps.skull_bones missing")
	local spiv = src:GetPivot()
	local function place(p: Vector3): Vector3
		return SKEL.g + (p - SKEL.g) * SKEL.s + SKEL.d
	end
	local verts: { Vector3 } = {}
	local tops: { [string]: Vector3 } = {}
	for _, name in ipairs({ "Bones", "Aged", "Sockets" }) do
		local orig = src:FindFirstChild(name) :: MeshPart
		assert(orig, `PropsTundraProps: skull_bones.{name} missing`)
		local mp = orig:Clone()
		mp:ClearAllChildren()
		for key in pairs(mp:GetAttributes()) do
			mp:SetAttribute(key, nil)
		end
		local rel = spiv:ToObjectSpace(orig.CFrame)
		mp.Size = orig.Size * SKEL.s
		mp.CFrame = CFrame.new(place(rel.Position)) * rel.Rotation
		mp.Anchored = true
		mp.CanCollide, mp.CanQuery, mp.CanTouch = false, false, false
		mp.Parent = m
		-- its vertices (for the ice layer and the frost): kit space
		local em = AssetService:CreateEditableMeshAsync(Content.fromUri(orig.MeshId))
		local k = orig.Size / orig.MeshSize
		for _, id in ipairs(em:GetVertices()) do
			local q = place(rel * (em:GetPosition(id) * k))
			table.insert(verts, q)
			if name == "Bones" and q.Y > 0.3 then
				local key = string.format("%d,%d", math.floor(q.X / 0.45), math.floor(q.Z / 0.45))
				if not tops[key] or q.Y > tops[key].Y then
					tops[key] = q
				end
			end
		end
		em:Destroy()
	end
	-- a thin glass ice layer over what sticks out of the block (by 0.5-stud cells)
	local cells: { [string]: { lo: Vector3, hi: Vector3 } } = {}
	for _, q in ipairs(verts) do
		if depth(q) > -0.04 then
			local key = string.format("%d,%d,%d", math.floor(q.X / 0.5), math.floor(q.Y / 0.5), math.floor(q.Z / 0.5))
			local c = cells[key]
			if c then
				c.lo, c.hi = c.lo:Min(q), c.hi:Max(q)
			else
				cells[key] = { lo = q, hi = q }
			end
		end
	end
	local keys = {}
	for key in pairs(cells) do
		table.insert(keys, key)
	end
	table.sort(keys)
	local layer = 0
	for _, key in ipairs(keys) do
		local c = cells[key]
		local mid, half = (c.lo + c.hi) / 2, (c.hi - c.lo) / 2 + Vector3.new(0.12, 0.12, 0.12)
		lump(U.Ice, rng, CFrame.new(mid), math.max(half.X, 0.18), math.max(half.Y, 0.15), math.max(half.Z, 0.18), TB.iceTone(rgb(191, 233, 245)), math.max(0, mid.Y))
		layer += 1
	end
	TP.lastIceLayer = layer
	-- frost on the bones: small rime flakes on their tops (cells 0.45, spread out)
	local tkeys = {}
	for key in pairs(tops) do
		table.insert(tkeys, key)
	end
	table.sort(tkeys)
	local chosen: { Vector3 } = {}
	for _, key in ipairs(tkeys) do
		local q = tops[key]
		local far = true
		for _, o in ipairs(chosen) do
			if (o - q).Magnitude < 0.8 then
				far = false
			end
		end
		if far and #chosen < 16 then
			table.insert(chosen, q)
			frostPatch(U.Frost, rng, q - UP * 0.015, UP, rng:NextNumber(0.1, 0.16), FROST)
		end
	end
	-- frost patches on the ice (from inside its centre out)
	local c0 = T + Vector3.new(0.5, 1.0, 0.5) * SKEL.iceS
	for _, d in ipairs({ Vector3.new(-0.5, 0.75, -0.45), Vector3.new(0.75, 0.6, 0.3), Vector3.new(-0.7, 0.45, 0.55), Vector3.new(0.25, 0.85, 0.5) }) do
		local p, n = exitAt(c0, d.Unit)
		frostPatch(U.Frost, rng, p, n, rng:NextNumber(0.32, 0.45), FROST)
	end
	-- the snow cap on the ice top, toward the back, on the face it sits on
	local top, tn = exitAt(T + Vector3.new(0.7, 1.0, 1.5) * SKEL.iceS, UP)
	facetPiece(U, TS.tundra_snow__cap, CFrame.fromMatrix(top - tn * 0.1, tn:Cross(Vector3.zAxis).Unit, tn), Vector3.new(2.8, 0.25, 2.2), "Snow", "Snow")
	-- 3 small icicles under the block's upper edges (front, left, right)
	for _, d in ipairs({ Vector3.new(0.1, 0, -1), Vector3.new(-1, 0, 0.2), Vector3.new(1, 0, 0.3) }) do
		local p = exitAt(c0 + Vector3.new(0, 0.75, 0), d.Unit)
		facetIcicle(U, "Icicles", p - d.Unit * 0.12, rng:NextNumber(0.18, 0.26), 0.22, rng:NextNumber(0, 6.28))
	end
	-- Agent A's ice shards at 2 feet
	local f1 = exitAt(c0 - Vector3.new(0, 0.9, 0), Vector3.new(1, 0, -0.5).Unit)
	facetPiece(U, TS.tundra_ice__shards, CFrame.new(f1.X, 0, f1.Z) * CFrame.Angles(0, rad(-30), 0), Vector3.one * 0.3, "Shards", "Shards")
	local f2 = exitAt(c0 - Vector3.new(0, 0.9, 0), Vector3.new(-0.6, 0, 1).Unit)
	facetPiece(U, TS.tundra_ice__shards, CFrame.new(f2.X, 0, f2.Z) * CFrame.Angles(0, rad(120), 0), Vector3.one * 0.22, "Shards", "Shards")

	TB.finishTB(m, "tundra_frozen_skeleton", U, "Ice", {
		Ice = { material = Enum.Material.Glass, transparency = 0.4, shadow = false, query = true },
		Frost = { transparency = 0.3, shadow = false },
		Shards = TB.GLASS_OPTS,
		Icicles = TB.ICICLE_OPTS,
	})
	collisionRows(m, kit)
	return m
end

---------------------------------------------------------------------
-- 02 ICE FISHING HOLE (kit MapAssets.Tundra.FishingHole, 12 parts, 9.1 x 4.1 x 7.4; 6 copies: test, kit, Tundra_2 x4 on
-- the frozen lake; decor: no prompt, no script)
---------------------------------------------------------------------
local WATER_LINES = "rbxassetid://92684887585956" -- PropTextures water_lines (the fountain / well "Ripples")
local WOOD = rgb(134, 92, 66) -- #865C42 today's seat / rod
local WOOD_DARK = rgb(92, 66, 54) -- #5C4236 today's legs / fork
local IRON = rgb(92, 98, 110) -- #5C626E
local STEEL_EDGE = rgb(62, 76, 102) -- #3E4C66
local ROPE = rgb(196, 160, 104) -- #C4A068 today's rope
local ROPE_D = rgb(168, 138, 85) -- #A88A55

-- a convex plank cut by a circle: x0..x1 across, the circle radius R (16 sides) round (cx, cz), y0..y1
local function roundPlank(list: { BasePart }, cx: number, cz: number, R: number, x0: number, x1: number, y0: number, y1: number, color: Color3)
	local planes = { { 0, 1, 0, y1 }, { 0, -1, 0, -y0 }, { 1, 0, 0, x1 - cx }, { -1, 0, 0, -(x0 - cx) } }
	for k = 0, 15 do
		local a = (k + 0.5) * math.pi / 8
		table.insert(planes, { math.cos(a), 0, math.sin(a), R, if k % 2 == 0 then color else scaled(color, 0.94) })
	end
	-- a small chamfer round the top edge
	for k = 0, 15 do
		local a = (k + 0.5) * math.pi / 8
		local n = Vector3.new(math.cos(a), 1, math.sin(a)).Unit
		table.insert(planes, { n.X, n.Y, n.Z, n:Dot(Vector3.new(math.cos(a) * (R - 0.06), y1, math.sin(a) * (R - 0.06))), scaled(color, 1.1) })
	end
	table.insert(list, H.convexSolid(Vector3.new(-R - 0.1, y0 - 0.1, -R - 0.1), Vector3.new(R + 0.1, y1 + 0.1, R + 0.1), CFrame.new(cx, 0, cz), color, planes))
end

-- The ice fishing hole (guide E10): today's Rim as 10 cut ice slabs (0.38 thick, 3.0 -> 3.7, joints, a top chamfer,
-- tones) with a dark #234A8F band on the inside wall; today's Water as deep water like the fountain / well (Glass T 0.15,
-- #1E5FA8, the water_lines Ripples, PropFX scrolls them; 0.35 under the rim top); soft snow round the outside and 2 snow
-- patches on the slabs. The stool: today's seat as 3 round-cut planks with nails, 3 tapered legs with 2 rungs, a pinch of
-- snow. Today's Bucket as the new barrel (the `barrel` MapProp nested at scale 0.4, kept in sync by the barrel rule;
-- the Bucket stays the invisible collider). Today's Fork as a forked stick, today's Rod as a tapered 2-piece rod with a
-- ferrule, 3 line guides and a reel; today's Line (its place kept) ending in a red / white bobber on the water with a
-- ripple ring. Today's 2 Fish as fish (body, lighter belly, tail fin, eye) on the slabs, 2 loose crossed planks with
-- nails on the ice. Nothing new collides. Colliders: today's Seat, 3 Legs, Fork, Bucket.
-- Parts: Ice, Water, Wood, Iron, Snow, Fish, Line, Ripple, Barrel (nested), Collision x6.
function TP.tundra_fishing_hole(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_fishing_hole"
	local rng = Random.new(20261802)
	H.setBevelSelf(true)
	local U: any = { Ice = {}, Wood = {}, Iron = {}, Snow = {}, Fish = {}, Line = {}, Ripple = {} }
	local kit = "FishingHole"
	local function row(name: string): any
		return rowsNamed(kit, name)[1]
	end
	local RIM_TOP, WATER_TOP = 0.38, 0.03
	-- the rim: 10 cut ice slabs, the dark inside band
	H.ringBlocks(U.Ice, rng, { n = 10, ro = 3.7, ri = 3.0, y0 = 0, h = RIM_TOP, c = 0.1, color = rgb(214, 236, 255), H = 4, noCore = true, a0 = rad(9) })
	ring(U.Ice, CFrame.new(0, 0, 0), 2.99, 0.05, RIM_TOP - WATER_TOP, 20, function(): Color3
		return rgb(35, 74, 143) -- #234A8F
	end, (RIM_TOP + WATER_TOP) / 2)
	-- the water (an exact part: the Ripples texture and PropFX need it)
	local w = row("Water")
	local water = piece("Part", Vector3.new(0.12, w.size.Y, w.size.Z), CFrame.new(0, WATER_TOP - 0.06, 0) * CFrame.Angles(0, 0, rad(90)), rgb(30, 95, 168), { shape = Enum.PartType.Cylinder })
	water.Name = "Water"
	water.Material = Enum.Material.Glass
	water.Transparency = 0.15
	water.CanCollide, water.CanQuery, water.CanTouch, water.CastShadow = false, false, false, false
	local tex = Instance.new("Texture")
	tex.Name = "Ripples"
	tex.Face = Enum.NormalId.Right
	tex.Texture = WATER_LINES
	tex.StudsPerTileU = 4
	tex.StudsPerTileV = 4
	tex.Parent = water
	water.Parent = m
	-- soft snow round the outside (thin cap strips), 2 snow patches on the slabs
	for k = 0, 6 do
		local a = k * 2 * math.pi / 7 + rng:NextNumber(-0.1, 0.1)
		facetPiece(U, TS.tundra_snow__cap, CFrame.new(math.cos(a) * 3.68, 0, math.sin(a) * 3.68) * CFrame.Angles(0, -a - math.pi / 2, 0), Vector3.new(2.0, 0.15, 0.4), "Snow", "Snow")
	end
	for _, a in ipairs({ rad(150), rad(232) }) do
		facetPiece(U, TS.tundra_snow__cap, CFrame.new(math.cos(a) * 3.35, RIM_TOP - 0.02, math.sin(a) * 3.35) * CFrame.Angles(0, -a - math.pi / 2, 0), Vector3.new(1.6, 0.15, 0.55), "Snow", "Snow")
	end
	-- the stool: 3 round-cut planks with nails on 2 battens, 3 tapered legs, 2 rungs, a pinch of snow
	local seat = row("Seat")
	local sc = seat.cf.Position
	local sR = seat.size.Y / 2
	local sTop = sc.Y + seat.size.X / 2
	local pw = (2 * sR - 2 * 0.06) / 3
	for i = 0, 2 do
		local x0 = sc.X - sR + i * (pw + 0.06)
		roundPlank(U.Wood, sc.X, sc.Z, sR, x0, x0 + pw, sTop - 0.2, sTop, if i == 1 then scaled(WOOD, 1.08) else WOOD)
		for _, dz in ipairs({ -0.5, 0.5 }) do
			TB.nail(U.Iron, Vector3.new(x0 + pw / 2, sTop, sc.Z + dz), UP)
		end
	end
	for _, dz in ipairs({ -0.5, 0.5 }) do
		table.insert(U.Wood, H.timber(Vector3.new(2 * sR * 0.86, 0.18, 0.22), CFrame.new(sc.X, sTop - 0.29, sc.Z + dz), WOOD_DARK))
	end
	local legs = rowsNamed(kit, "Leg")
	for _, l in ipairs(legs) do
		local p = l.cf.Position
		stick(U.Wood, Vector3.new(p.X, 0, p.Z), Vector3.new(p.X, sTop - 0.36, p.Z), 0.17, 0.14, WOOD_DARK)
	end
	-- 2 rungs at y 0.6 from the outer leg to the 2 inner ones
	local outer = legs[1]
	for _, l in ipairs(legs) do
		if l.cf.X > outer.cf.X then
			outer = l
		end
	end
	for _, l in ipairs(legs) do
		if l ~= outer then
			local a, b = outer.cf.Position, l.cf.Position
			stick(U.Wood, Vector3.new(a.X, 0.6, a.Z), Vector3.new(b.X, 0.6, b.Z), 0.075, 0.075, WOOD)
		end
	end
	lump(U.Snow, rng, CFrame.new(sc.X + 0.55, sTop, sc.Z - 0.45), 0.4, 0.07, 0.28, snowTone, 0.0)
	-- the barrel: the new barrel (the `barrel` MapProp) nested at today's Bucket, scale 0.4
	local bucket = row("Bucket")
	local bt = ServerStorage.MapProps:FindFirstChild("barrel")
	assert(bt, "PropsTundraProps: ServerStorage.MapProps.barrel missing")
	local barrel = bt:Clone()
	barrel.Name = "Barrel"
	barrel:ScaleTo(0.4)
	barrel:PivotTo(CFrame.new(bucket.cf.X, 0, bucket.cf.Z) * CFrame.Angles(0, rad(25), 0))
	barrel:AddTag("MapProp")
	barrel:SetAttribute("MapPropId", "barrel")
	barrel:SetAttribute("MapPropVersion", tostring(bt:GetAttribute("MapPropVersion") or "?") .. "|")
	barrel.Parent = m
	-- the fork: a forked stick (2 prongs across the rod)
	local fk = row("Fork")
	local fp = fk.cf.Position
	local fTop = fp.Y + fk.size.Y / 2
	stick(U.Wood, Vector3.new(fp.X, 0, fp.Z), Vector3.new(fp.X, fTop - 0.38, fp.Z), 0.16, 0.13, WOOD_DARK)
	for _, s in ipairs({ -1, 1 }) do
		local a = Vector3.new(fp.X, fTop - 0.42, fp.Z)
		stick(U.Wood, a, a + Vector3.new(0, 0.46, s * 0.2), 0.08, 0.05, WOOD_DARK)
	end
	-- the rod: 2 tapered pieces, a ferrule, 3 line guides, a reel near the butt
	local rd = row("Rod")
	local rdir = rd.cf.XVector
	local r0, r1 = rd.cf.Position - rdir * rd.size.X / 2, rd.cf.Position + rdir * rd.size.X / 2
	local butt, tip = r0, r1
	if r1.Y < r0.Y then
		butt, tip = r1, r0
	end
	local rmid = butt:Lerp(tip, 0.5)
	stick(U.Wood, butt, rmid, 0.11, 0.08, WOOD)
	stick(U.Wood, rmid, tip, 0.075, 0.035, rgb(168, 98, 56))
	stick(U.Iron, rmid - (tip - butt).Unit * 0.12, rmid + (tip - butt).Unit * 0.12, 0.1, 0.1, IRON)
	local below = (tip - butt).Unit:Cross(Vector3.zAxis).Unit
	if below.Y > 0 then
		below = -below
	end
	for _, t in ipairs({ 0.62, 0.78, 0.92 }) do
		local p = butt:Lerp(tip, t) + below * 0.09
		table.insert(U.Iron, frustumN(8, 0.05, 0.05, -0.015, 0.015, H.frameY(p, tip - butt), { IRON }))
	end
	local reelAt = butt:Lerp(tip, 0.14) + below * 0.2
	table.insert(U.Iron, frustumN(12, 0.175, 0.175, -0.07, 0.07, H.frameY(reelAt, Vector3.zAxis), { IRON, scaled(IRON, 1.15) }))
	stick(U.Iron, reelAt, reelAt + Vector3.new(0, 0, -0.22), 0.025, 0.025, IRON)
	stick(U.Wood, reelAt + Vector3.new(0, 0, -0.22), reelAt + Vector3.new(0, 0, -0.34), 0.04, 0.04, WOOD_DARK)
	stick(U.Iron, reelAt - below * 0.08, reelAt - below * 0.2, 0.035, 0.035, IRON)
	-- today's Line (its place) and a red / white bobber on the water with a ripple ring
	local ln = row("Line")
	local lp = ln.cf.Position
	local lTop = lp.Y + ln.size.Y / 2
	local bob = Vector3.new(lp.X, WATER_TOP + 0.1, lp.Z)
	table.insert(U.Line, piece("Part", Vector3.new(0.04, lTop - (bob.Y + 0.15), 0.04), CFrame.new(lp.X, (lTop + bob.Y + 0.15) / 2, lp.Z), ln.color))
	lump(U.Line, rng, CFrame.new(bob + Vector3.new(0, 0.04, 0)), 0.15, 0.1, 0.15, function(n: Vector3): Color3
		return if n.Y > -0.1 then rgb(212, 52, 60) else rgb(245, 246, 250)
	end)
	lump(U.Line, rng, CFrame.new(bob - Vector3.new(0, 0.06, 0)), 0.14, 0.08, 0.14, function(): Color3
		return rgb(245, 246, 250)
	end)
	for k = 0, 9 do
		local a = (k + 0.5) * 2 * math.pi / 10
		table.insert(U.Ripple, piece("Part", Vector3.new(0.19, 0.02, 0.05), CFrame.new(bob.X + math.cos(a) * 0.28, WATER_TOP + 0.01, bob.Z + math.sin(a) * 0.28) * CFrame.Angles(0, -a - math.pi / 2, 0), rgb(191, 233, 245)))
	end
	-- today's 2 fish (on the slabs): a body, a lighter belly, a tail fin, an eye
	for _, f in ipairs(rowsNamed(kit, "Fish")) do
		local L, Hh, Wd = f.size.X, f.size.Y, f.size.Z
		local F = CFrame.new(f.cf.X, RIM_TOP + Hh * 0.42, f.cf.Z) * f.cf.Rotation
		local belly = f.color:Lerp(Color3.new(1, 1, 1), 0.45)
		lump(U.Fish, rng, F * CFrame.new(-L * 0.08, 0, 0), L * 0.42, Hh * 0.45, Wd * 0.45, function(n: Vector3): Color3
			return if n.Y > 0.2 then f.color elseif n.Y > -0.3 then scaled(f.color, 1.08) else belly
		end, Hh * 0.42)
		local tb = F * Vector3.new(L * 0.3, 0, 0)
		H.triangleParts(U.Fish, tb, F * Vector3.new(L * 0.52, 0, -Wd * 0.45), F * Vector3.new(L * 0.52, 0, Wd * 0.45), 0.06, CFrame.identity, scaled(f.color, 0.88))
		table.insert(U.Fish, piece("Part", Vector3.new(0.09, 0.06, 0.09), F * CFrame.new(-L * 0.36, Hh * 0.3, -Wd * 0.18), COAL))
		table.insert(U.Fish, piece("Part", Vector3.new(0.09, 0.06, 0.09), F * CFrame.new(-L * 0.36, Hh * 0.3, Wd * 0.18), COAL))
	end
	-- 2 loose planks crossed on the ice between the stool and the hole, a nail each
	local p1 = CFrame.new(3.45, 0.075, 2.75) * CFrame.Angles(0, rad(-48), 0)
	TB.plank(U.Wood, U.Iron, Vector3.new(0.8, 0.15, 2.4), p1, WOOD, { Vector3.new(0, 0, 0.8) })
	local p2 = CFrame.new(3.35, 0.2, 2.8) * CFrame.Angles(0, rad(30), rad(3))
	TB.plank(U.Wood, U.Iron, Vector3.new(0.8, 0.15, 2.0), p2, scaled(WOOD, 1.1), { Vector3.new(0, 0, -0.6) })

	TB.finishTB(m, "tundra_fishing_hole", U, "Ice", {
		Ripple = { transparency = 0.4, shadow = false },
		Line = { shadow = false },
	})
	collisionRows(m, kit)
	return m
end

---------------------------------------------------------------------
-- 03 SLED (kit MapAssets.Tundra.Sled_A, 16 parts, 3.6 x 2 x 10.4; 5 copies: test, kit, Tundra_1 / 2 / 3)
---------------------------------------------------------------------
-- The sled (guide E10): one curved runner per side (today's Runner and RunnerTip: the straight runner and a tip curling
-- up and back in 3 segments (35 / 70 / 110 deg) to a scroll) with a dark-steel edge strip along the underside and up
-- the curl, 4 rivets a side; a front dowel between the curls; today's 4 legs chamfered; today's 2 cross bars with a
-- notch line and 2 nails each; an X brace between the legs on each side; today's 5 slats with 0.08 gaps and rounded
-- ends over 2 battens, 2 nails per slat per batten (today's alternating colours); today's rope as a twisted rope (2
-- strands spiralling) tied to the dowel with a knot, a frayed tuft at the end; a snow dusting over the back of the
-- slats and a pinch on each curl. Colliders: today's 15 parts (not the rope). Parts: Wood, Steel, Rope, Snow, Collision x15.
function TP.tundra_sled(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_sled"
	local rng = Random.new(20261803)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Steel = {}, Rope = {}, Snow = {} }
	local kit = "Sled_A"
	local function row(name: string): any
		return rowsNamed(kit, name)[1]
	end
	local runner = row("Runner")
	local RW, RH = runner.size.X, runner.size.Y
	local zBack = runner.cf.Z + runner.size.Z / 2
	local zFront = runner.cf.Z - runner.size.Z / 2
	local curlTop = {}
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * math.abs(runner.cf.X)
		-- the straight runner over its steel shoe
		table.insert(U.Wood, chamfered(Vector3.new(RW, RH - 0.1, zBack - zFront), CFrame.new(x, 0.1 + (RH - 0.1) / 2, (zBack + zFront) / 2), runner.color, { "topSides", "topFrontBack" }, 0.07))
		table.insert(U.Steel, piece("Part", Vector3.new(RW + 0.02, 0.1, zBack - zFront - 0.02), CFrame.new(x, 0.05, (zBack + zFront) / 2), STEEL_EDGE))
		-- the curl: 3 segments along the runner's centre line, each turned more
		local p = Vector3.new(x, RH / 2, zFront + 0.05)
		local lens = { 0.9, 0.6, 0.4 }
		local angs = { 35, 70, 110 }
		for i = 1, 3 do
			local a = rad(angs[i])
			local d = Vector3.new(0, math.sin(a), -math.cos(a))
			local q = p + d * lens[i]
			-- local -Z along the segment, local +Y the inner (top) side, local -Y the outer side (the steel)
			local frame = CFrame.lookAt((p + q) / 2, q, Vector3.xAxis:Cross(d))
			table.insert(U.Wood, chamfered(Vector3.new(RW, RH - 0.06, lens[i] + 0.22), frame, runner.color, { "topSides" }, 0.06))
			table.insert(U.Steel, piece("Part", Vector3.new(RW + 0.02, 0.08, lens[i] + 0.16), frame * CFrame.new(0, -(RH - 0.06) / 2 - 0.02, 0), STEEL_EDGE))
			p = q
			if i == 1 then
				curlTop[sx] = q
			end
		end
		-- the scroll at the end of the curl
		table.insert(U.Wood, frustumN(10, RH * 0.55, RH * 0.55, -RW / 2, RW / 2, H.frameY(p, Vector3.xAxis), { runner.color, scaled(runner.color, 1.12) }))
		table.insert(U.Steel, frustumN(10, RH * 0.22, RH * 0.22, -RW / 2 - 0.02, RW / 2 + 0.02, H.frameY(p, Vector3.xAxis), { STEEL_EDGE }))
		lump(U.Snow, rng, CFrame.new(p + Vector3.new(0, RH * 0.5, 0)), 0.2, 0.07, 0.2, snowTone, 0.0)
		-- 4 rivets along the shoe's outer side
		for k = 0, 3 do
			H.rivet(U.Steel, Vector3.new(x + sx * (RW / 2 + 0.01), 0.06, zFront + 0.6 + k * (zBack - zFront - 1.2) / 3), 0.09)
		end
	end
	-- the front dowel between the curls
	stick(U.Wood, curlTop[-1] - Vector3.xAxis * 0.1, curlTop[1] + Vector3.xAxis * 0.1, 0.09, 0.09, scaled(runner.color, 1.1))
	-- the legs, chamfered
	for _, l in ipairs(rowsNamed(kit, "Leg")) do
		table.insert(U.Wood, H.timber(l.size, l.cf, l.color, 0.06))
	end
	-- the cross bars: a notch line where they sit on the legs, 2 nails each
	for _, c in ipairs(rowsNamed(kit, "Cross")) do
		table.insert(U.Wood, H.timber(c.size, c.cf, c.color, 0.07))
		for _, sx in ipairs({ -1, 1 }) do
			local x = sx * 1.5
			table.insert(U.Wood, piece("Part", Vector3.new(0.03, c.size.Y + 0.02, c.size.Z + 0.02), CFrame.new(x - 0.21, c.cf.Y, c.cf.Z), scaled(c.color, 0.75)))
			table.insert(U.Wood, piece("Part", Vector3.new(0.03, c.size.Y + 0.02, c.size.Z + 0.02), CFrame.new(x + 0.21, c.cf.Y, c.cf.Z), scaled(c.color, 0.75)))
			TB.nail(U.Steel, Vector3.new(x, c.cf.Y, c.cf.Z - c.size.Z / 2), -Vector3.zAxis)
		end
	end
	-- an X brace between the legs on each side (outside the legs)
	local legZ0, legZ1 = math.huge, -math.huge
	for _, l in ipairs(rowsNamed(kit, "Leg")) do
		legZ0, legZ1 = math.min(legZ0, l.cf.Z), math.max(legZ1, l.cf.Z)
	end
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 1.79
		stick(U.Wood, Vector3.new(x, 0.55, legZ0 + 0.15), Vector3.new(x, 1.3, legZ1 - 0.15), 0.1, 0.1, scaled(runner.color, 1.05))
		stick(U.Wood, Vector3.new(x, 1.3, legZ0 + 0.15), Vector3.new(x, 0.55, legZ1 - 0.15), 0.1, 0.1, scaled(runner.color, 0.95))
	end
	-- the slats (0.08 gaps, rounded ends) over 2 battens, 2 nails per slat per batten
	local slats = rowsNamed(kit, "Slat")
	local s1 = slats[1]
	local sTop = s1.cf.Y + s1.size.Y / 2
	local z0, z1 = s1.cf.Z - s1.size.Z / 2, s1.cf.Z + s1.size.Z / 2
	local battens = { z0 + 0.45, z1 - 0.45 }
	for _, bz in ipairs(battens) do
		table.insert(U.Wood, H.timber(Vector3.new(3.4, 0.14, 0.4), CFrame.new(0, sTop - s1.size.Y - 0.07, bz), runner.color, 0.04))
	end
	for _, s in ipairs(slats) do
		table.insert(U.Wood, chamfered(s.size - Vector3.new(0.08, 0, 0), s.cf, s.color, { "topFrontBack", "topSides" }, 0.1))
		for _, bz in ipairs(battens) do
			for _, dx in ipairs({ -0.14, 0.14 }) do
				TB.nail(U.Steel, Vector3.new(s.cf.X + dx, sTop, bz), UP)
			end
		end
	end
	-- the snow dusting over the back of the slats
	facetPiece(U, TS.tundra_snow__cap, CFrame.new(0, sTop - 0.03, z1 - 1.55) * CFrame.Angles(0, rad(3), 0), Vector3.new(3.3, 0.15, 2.9), "Snow", "Snow")
	-- today's rope as a twisted rope: 2 strands spiralling round today's line, a knot at the dowel, a frayed tuft
	local rp = row("Rope")
	local rax = rp.cf.ZVector
	local ra, rb = rp.cf.Position - rax * rp.size.Z / 2, rp.cf.Position + rax * rp.size.Z / 2
	local near, far = ra, rb
	if rb.Z > ra.Z then
		near, far = rb, ra
	end
	local dowel = (curlTop[-1] + curlTop[1]) / 2
	stick(U.Rope, dowel, near, 0.06, 0.06, ROPE)
	lump(U.Rope, rng, CFrame.new(dowel + Vector3.new(0, 0, -0.02)), 0.14, 0.13, 0.13, function(n: Vector3): Color3
		return if n.Y > 0 then ROPE else ROPE_D
	end)
	local dir = (far - near).Unit
	local e1 = dir:Cross(Vector3.xAxis).Unit
	local e2 = dir:Cross(e1).Unit
	local N = 14
	for strand = 0, 1 do
		for i = 0, N - 1 do
			local function at(t: number): Vector3
				local th = t * 7 * math.pi + strand * math.pi
				return near:Lerp(far, t) + (e1 * math.cos(th) + e2 * math.sin(th)) * 0.035
			end
			local t0, t1 = i / N, (i + 1) / N
			stick(U.Rope, at(t0), at(t1) + (at(t1) - at(t0)).Unit * 0.02, 0.06, 0.06, if strand == 0 then ROPE else ROPE_D)
		end
	end
	for k = 0, 2 do
		local a = k * 2 * math.pi / 3
		local spread = (e1 * math.cos(a) + e2 * math.sin(a)) * 0.08
		stick(U.Rope, far, far + dir * 0.22 + spread, 0.035, 0.012, ROPE)
	end

	TB.finishTB(m, "tundra_sled", U, "Wood", {})
	collisionRows(m, kit)
	return m
end

---------------------------------------------------------------------
-- 06 FROZEN WEAPON RACK, the owner's "ice drying rack" (kit MapAssets.Tundra.Weapon_Rack_Frozen, 16 parts, 8 x 8.9 x
-- 3.4; 10 copies: test, kit, Tundra_4 x4 at 1.2, BossArenas x4 at 1.3)
---------------------------------------------------------------------
-- The frozen weapon rack (guide E10, owner: "ice drying rack"): today's 2 posts chamfered with pyramid caps and snow caps;
-- today's 2 rails chamfered, with 2 pegs at each post and rope ties at every rail-post joint; a third crossbar at y 3.6
-- (no collider); frost rime and a snow cap on the top rail; today's Base as 4 planks with gaps and nails on 2 battens, a
-- snow strip at the back; Agent A's 2 faceted ice blocks (the lump on the base, the block round the sword) in place of
-- today's Ice meshes. The weapons at today's places and angles: the spear (today's Shaft as an 8-sided shaft, today's
-- SpearTip as a bevelled blue spear head on a socket) with a small blue swallow-tail pennant tied under the head (the
-- owner's "blue flag"); the axe (today's Handle, today's AxeHead with a bevelled light edge) with a gray cloth wrapped
-- round the handle under the head and hanging (the owner's "cloth"); the sword frozen in the ice (a blade with a fuller
-- line, today's gold guard). Today's 3 icicles and 4 more under the rails, a small cluster under the top rail's middle.
-- Colliders: today's Base, 2 Posts, 2 Rails. Parts: Wood, Iron, Gold, Cloth, Rope, Ice, Icicles, Snow, Collision x5.
function TP.tundra_ice_rack(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_ice_rack"
	local rng = Random.new(20261806)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Iron = {}, Gold = {}, Cloth = {}, Rope = {}, Ice = {}, Icicles = {}, Snow = {} }
	local kit = "Weapon_Rack_Frozen"
	local function row(name: string): any
		return rowsNamed(kit, name)[1]
	end
	-- the plank base: 4 planks along X (gaps, nails) on 2 battens, a snow strip at the back
	local base = row("Base")
	local bs, bp = base.size, base.cf.Position
	local pw = (bs.Z - 3 * 0.06) / 4
	for _, bx in ipairs({ -bs.X / 2 + 0.6, bs.X / 2 - 0.6 }) do
		table.insert(U.Wood, H.timber(Vector3.new(0.5, 0.28, bs.Z - 0.04), CFrame.new(bx, 0.14, bp.Z), scaled(base.color, 0.85), 0.04))
	end
	for i = 0, 3 do
		local z = bp.Z - bs.Z / 2 + pw / 2 + i * (pw + 0.06)
		table.insert(U.Wood, chamfered(Vector3.new(bs.X - rng:NextNumber(0, 0.08), 0.22, pw), CFrame.new(0, bs.Y - 0.11, z), if i % 2 == 0 then base.color else scaled(base.color, 1.1), { "topFrontBack", "topSides" }, 0.05))
		for _, bx in ipairs({ -bs.X / 2 + 0.6, bs.X / 2 - 0.6 }) do
			TB.nail(U.Iron, Vector3.new(bx, bs.Y, z), UP)
		end
	end
	facetPiece(U, TS.tundra_snow__cap, CFrame.new(0.3, bs.Y - 0.03, bp.Z + bs.Z / 2 - 0.3), Vector3.new(7.2, 0.18, 0.5), "Snow", "Snow")
	-- the posts: chamfered, pyramid caps, snow caps
	local posts = rowsNamed(kit, "Post")
	local postTop = 0
	for _, p in ipairs(posts) do
		local pc, ps = p.cf.Position, p.size
		local y0, y1 = bs.Y, pc.Y + ps.Y / 2
		postTop = y1
		table.insert(U.Wood, chamfered(Vector3.new(ps.X, y1 - y0, ps.Z), CFrame.new(pc.X, (y0 + y1) / 2, pc.Z), p.color, { "vertical" }, 0.08))
		table.insert(U.Wood, frustumN(4, ps.X / 2 + 0.03, 0.04, y1, y1 + 0.38, CFrame.new(pc.X, 0, pc.Z) * CFrame.Angles(0, rad(45), 0), { scaled(p.color, 1.1), p.color, scaled(p.color, 0.9), p.color }))
		lump(U.Snow, rng, CFrame.new(pc.X, y1 + 0.12, pc.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), 0.34, 0.14, 0.34, snowTone, 0.02)
	end
	-- the rails, a third crossbar, 2 pegs per joint, rope ties at every joint
	local rails = rowsNamed(kit, "Rail")
	local railYs = {}
	for _, r in ipairs(rails) do
		table.insert(U.Wood, H.timber(r.size, r.cf, r.color, 0.07))
		table.insert(railYs, r.cf.Y)
	end
	local rz = rails[1].cf.Z
	table.insert(U.Wood, H.timber(Vector3.new(7.2, 0.3, 0.3), CFrame.new(0, 3.6, rz), scaled(rails[1].color, 0.95), 0.05))
	table.insert(railYs, 3.6)
	for _, y in ipairs(railYs) do
		for _, p in ipairs(posts) do
			local x = p.cf.X
			for _, dy in ipairs({ -0.08, 0.08 }) do
				table.insert(U.Wood, frustumN(8, 0.05, 0.05, 0, 0.06, H.frameY(Vector3.new(x - math.sign(x) * 0.12, y + dy, rz - 0.2), -Vector3.zAxis), { scaled(p.color, 0.8) }))
			end
			TB.lashing(U.Rope, Vector3.new(x, y, rz), UP, p.size.X / 2 * 1.414 - 0.04, 3, rng)
		end
	end
	-- frost rime and a snow cap on the top rail
	local top = rails[1]
	for _, r in ipairs(rails) do
		if r.cf.Y > top.cf.Y then
			top = r
		end
	end
	local ty = top.cf.Y + top.size.Y / 2
	TG.rime(U.Snow, rng, Vector3.new(-3.2, ty, rz - 0.17), Vector3.new(3.2, ty, rz - 0.17), 0.08)
	facetPiece(U, TS.tundra_snow__cap, CFrame.new(0, ty - 0.02, rz), Vector3.new(7.0, 0.3, 0.55), "Snow", "Snow")
	-- Agent A's 2 faceted ice blocks
	facetPiece(U, PS.tundra_props__rack_ice, CFrame.identity, nil, "Ice", "Ice")
	-- the spear: an 8-sided shaft, a socket, a bevelled blue head, a blue swallow-tail pennant tied under it
	local sh, st = row("Shaft"), row("SpearTip")
	local sax = sh.cf.YVector
	local s0, s1 = sh.cf.Position - sax * sh.size.Y / 2, sh.cf.Position + sax * sh.size.Y / 2
	stick(U.Wood, s0, s1, sh.size.X / 2 * 1.05, sh.size.X / 2 * 0.95, sh.color)
	local tipBase = st.cf.Position - st.cf.YVector * st.size.Y / 2
	stick(U.Iron, tipBase - st.cf.YVector * 0.25, tipBase + st.cf.YVector * 0.08, 0.13, 0.1, IRON)
	do
		local F = st.cf
		local hw, hh, ht = st.size.X / 2, st.size.Y / 2, st.size.Z / 2
		local planes = { { 0, 0, 1, ht, st.color }, { 0, 0, -1, ht, scaled(st.color, 1.1) } }
		for _, sx in ipairs({ -1, 1 }) do
			-- the edges: up to the point (from the widest place, a third up) and down to the socket
			local nu = Vector3.new(sx * 1.3 * hh, hw, 0).Unit
			table.insert(planes, { nu.X, nu.Y, nu.Z, nu:Dot(Vector3.new(0, hh, 0)), scaled(st.color, 1.12) })
			local nd = Vector3.new(sx * 0.7 * hh, -(hw - 0.12), 0).Unit
			table.insert(planes, { nd.X, nd.Y, nd.Z, nd:Dot(Vector3.new(sx * hw, -0.3 * hh, 0)), scaled(st.color, 0.9) })
			-- the bevels from the centre ridge to the edges, both faces
			for _, sz in ipairs({ -1, 1 }) do
				local nb = Vector3.new(sx * ht, 0, sz * hw).Unit
				table.insert(planes, { nb.X, nb.Y, nb.Z, nb:Dot(Vector3.new(0, 0, sz * ht)), if sx * sz > 0 then scaled(st.color, 1.15) else st.color })
			end
		end
		table.insert(U.Iron, H.convexSolid(-st.size, st.size, F, st.color, planes))
		-- the pennant: 2 triangles (a swallow tail) tied under the head with a cord, flying to +X
		local a = tipBase - st.cf.YVector * 0.35
		local b = tipBase - st.cf.YVector * 1.05
		local flagX = st.cf.XVector
		local tipA = a + flagX * 0.8 - st.cf.YVector * 0.08
		local tipB = b + flagX * 0.8 + st.cf.YVector * 0.08
		local notch = (a + b) / 2 + flagX * 0.5
		H.triangleParts(U.Cloth, a, tipA, notch, 0.05, CFrame.identity, st.color)
		H.triangleParts(U.Cloth, b, notch, tipB, 0.05, CFrame.identity, scaled(st.color, 0.9))
		H.triangleParts(U.Cloth, a, notch, b, 0.05, CFrame.identity, st.color)
		for _, q in ipairs({ a, b }) do
			TB.lashing(U.Rope, q, sax, sh.size.X / 2, 1, rng)
		end
	end
	-- the axe: today's handle, today's head with a bevelled light edge, a gray cloth wrapped under it and hanging
	local hd, ax = row("Handle"), row("AxeHead")
	local hax = hd.cf.YVector
	local h0, h1 = hd.cf.Position - hax * hd.size.Y / 2, hd.cf.Position + hax * hd.size.Y / 2
	stick(U.Wood, h0, h1, hd.size.X / 2 * 1.05, hd.size.X / 2 * 0.9, hd.color)
	do
		local F = ax.cf
		local hx, hy, hz = ax.size.X / 2, ax.size.Y / 2, ax.size.Z / 2
		local planes = {
			{ 0, 1, 0, hy * 0.85, IRON }, { 0, -1, 0, hy, IRON }, { -1, 0, 0, hx, scaled(IRON, 0.9) },
			{ 0, 0, 1, hz, IRON }, { 0, 0, -1, hz, scaled(IRON, 1.08) },
		}
		-- the cutting edge: 2 bevels meeting at +X, light worn steel
		for _, s in ipairs({ -1, 1 }) do
			local n = Vector3.new(hz, 0, s * 0.35).Unit
			table.insert(planes, { n.X, n.Y, n.Z, n:Dot(Vector3.new(hx, 0, 0)), rgb(122, 128, 140) })
		end
		-- the bearded lower edge (the blade drops toward the cutting edge)
		local n = Vector3.new(-0.35, -1, 0).Unit
		table.insert(planes, { n.X, n.Y, n.Z, n:Dot(Vector3.new(hx * 0.2, -hy, 0)), scaled(IRON, 0.9) })
		table.insert(U.Iron, H.convexSolid(-ax.size, ax.size, F, IRON, planes))
		-- the cloth: 2 wraps round the handle under the head and a strip hanging in front, frayed
		local CLOTH = rgb(150, 156, 168)
		local w0 = ax.cf.Position - hax * (hy + 0.25)
		w0 = h0 + hax * (hax:Dot(w0 - h0))
		for k = 0, 1 do
			local p = w0 - hax * (k * 0.22)
			table.insert(U.Cloth, frustumN(8, hd.size.X / 2 + 0.07, hd.size.X / 2 + 0.07, -0.1, 0.1, H.frameY(p, hax) * CFrame.Angles(0, rad(k * 20), rad(k * 6)), { CLOTH, scaled(CLOTH, 0.9) }))
		end
		local front = -hd.cf.ZVector
		local hang0 = w0 + front * (hd.size.X / 2 + 0.06)
		local segs = { { 0.5, 3 }, { 0.42, -4 }, { 0.36, 5 } }
		local p = hang0
		for i, sg in ipairs(segs) do
			local d = (-UP + Vector3.new(rad(sg[2]), 0, 0) + front * 0.08).Unit
			local q = p + d * sg[1]
			table.insert(U.Cloth, piece("Part", Vector3.new(0.42 - i * 0.03, sg[1] + 0.03, 0.04), CFrame.fromMatrix((p + q) / 2, Vector3.xAxis, d), if i == 2 then rgb(200, 204, 212) else CLOTH))
			p = q
		end
		for i = -1, 1 do
			table.insert(U.Cloth, piece("WedgePart", Vector3.new(0.05, 0.14, 0.04), CFrame.new(p + Vector3.new(i * 0.11, -0.07, 0)) * CFrame.Angles(0, 0, math.pi), CLOTH))
		end
	end
	-- the sword frozen in the ice: a blade with a fuller line, today's gold guard
	local bl, gd = row("Blade"), row("Guard")
	do
		local F = bl.cf
		local hx, hy, hz = bl.size.X / 2, bl.size.Y / 2, bl.size.Z / 2
		local planes = { { 0, -1, 0, hy, BONE } }
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local n = Vector3.new(sx * hz, 0, sz * hx).Unit
				table.insert(planes, { n.X, n.Y, n.Z, n:Dot(Vector3.new(0, 0, sz * hz)), rgb(232, 236, 244) })
			end
			-- the point
			local np = Vector3.new(sx * 0.6, hx, 0).Unit
			table.insert(planes, { np.X, np.Y, np.Z, np:Dot(Vector3.new(0, hy, 0)), rgb(245, 246, 250) })
			table.insert(planes, { sx, 0, 0, hx, rgb(214, 220, 230) })
		end
		table.insert(U.Iron, H.convexSolid(-bl.size, bl.size, F, bl.color, planes))
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Iron, piece("Part", Vector3.new(0.06, bl.size.Y * 0.62, 0.02), F * CFrame.new(0, -hy * 0.3, sz * hz), rgb(150, 158, 172)))
		end
		table.insert(U.Gold, H.timber(gd.size, gd.cf, gd.color, 0.06))
		for _, sx in ipairs({ -1, 1 }) do
			lump(U.Gold, rng, gd.cf * CFrame.new(sx * (gd.size.X / 2), 0, 0), 0.13, 0.13, 0.13, function(): Color3
				return scaled(gd.color, 0.92)
			end)
		end
	end
	-- the icicles: today's 3 and 4 more under the rails, a small cluster under the top rail's middle
	for _, ic in ipairs(rowsNamed(kit, "Icicle")) do
		local root = ic.cf.Position + Vector3.new(0, ic.size.Y / 2, 0)
		facetIcicle(U, "Icicles", root, ic.size.Y / 3.0, ic.size.X / 0.9, rng:NextNumber(0, 6.28))
	end
	local lowY = 0
	for _, r in ipairs(rails) do
		if r ~= top then
			lowY = r.cf.Y - r.size.Y / 2
		end
	end
	for _, q in ipairs({ { -2.9, lowY, 0.45 }, { -0.4, lowY, 0.35 }, { 2.7, lowY, 0.4 }, { -2.6, ty - top.size.Y, 0.3 } }) do
		facetIcicle(U, "Icicles", Vector3.new(q[1], q[2], rz), q[3], q[3] * 0.8, rng:NextNumber(0, 6.28))
	end
	facetPiece(U, TS.tundra_ice__icicle_cluster, CFrame.new(-0.1, ty - top.size.Y, rz), Vector3.one * 0.4, "Icicles", "Icicles")

	TB.finishTB(m, "tundra_ice_rack", U, "Wood", {
		Ice = { material = Enum.Material.Glass, transparency = 0.4, shadow = false, query = true },
		Icicles = TB.ICICLE_OPTS,
	})
	collisionRows(m, kit)
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table as the earlier props; its install() builds them
---------------------------------------------------------------------
TP.BUILDERS = { tundra_frozen_skeleton = true, tundra_fishing_hole = true, tundra_sled = true, tundra_snowman_gray = true, tundra_snowman_blue = true, tundra_ice_rack = true }
for id in pairs(TP.BUILDERS) do
	B2[id] = (TP :: any)[id]
	B2.BUILDERS[id] = true
end
TP.install = B2.install
TP.stats = B2.stats

return TP
