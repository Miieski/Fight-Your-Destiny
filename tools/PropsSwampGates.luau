--[[
	PropsSwampGates (dev tool, Edit mode only) - the owner's "CURSED SWAMP PROP IMPROVEMENT - Gates and entrances"
	(2026-10-24): 01 the mushroom vine arch (Swamp_1.EntryArch), 02 the wooden gate with the dead trees (Swamp_2), 03 the
	rock barricade (Swamp_3) and 04 the skull palisade (Swamp_4), to the fountain / well quality in the cursed swamp look
	(docs/prop_texture_guide.md sections A and F), keeping each gate's place, size, collisions, scripts and prompts.
	Source of truth: tools/PropsSwampGates.luau. Data: tools/PropsSwampGatesData.luau (the game copies' parts).
	Inventory: docs/prop_inventory.md "Swamp gates".

	REUSE: the finished gates' recipe, re-proportioned to the swamp kits' parts: the plains entry_arch / gate_palisade
	and the tundra palisade gate (logs with iron bands, rivets and rope, framed signs, lanterns in an iron frame on
	brackets, a plank double door with straps, hinges and ring handles under the Barrier), the jungle barricade (crossed
	branches with rope under the Barrier) and the jungle rock recipe (a faceted convex rock built from the measured hull
	of today's rock mesh: PropsJungleNature.supportPlanes) for the boulders; the swamp moss, mushrooms and hanging moss
	of DevTools.PropsSwampHuts.

	Kept (the owner / the main agent): the ravens (since the magic props prompt: the nested swamp_raven MapProp at today's
	raven pose, scale 1.3), the ghost mushroom meshes and their Neon glow, the lanterns (Neon cores and PointLights), the magenta glows
	(the barricade's orbs, the skull's eyes, the rune crosses), the shelf mushrooms, the NameSign / PriceSign (their GUIs
	move onto them) and the Barriers.

	Gate contract (as the jungle and tundra gates): the Barrier stays the PrimaryPart and collides, the door decor (and
	any glow on the door) sits under it, model attribute BarrierDecorIsChildOfBarrier; SubZoneId / ZoneId and the sign
	GUIs are kept by the sync; ZoneService adds the GatePrompt at run time. Collision: every other part that collides
	today is an invisible "Collision" copy (the trees' and rocks' Toolbox meshes keep their mesh and Hull collision); the
	visible pieces never collide. The kit and test copies of 01 and 04 differ in one collider from the game copy (04 also
	in its 8 trunks, by up to 0.0005): Variant "Kit" switches the matching colliders.

		local SG = require(game.ServerStorage.DevTools.PropsSwampGates:Clone())
		print(SG.install("swamp_vine_arch"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "swamp_vine_arch" } }), Sync.run({ only = { "swamp_vine_arch" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local SH = require(ServerStorage.DevTools.PropsSwampHuts:Clone()) :: any
local TB, B2, H, M = SH.TB, SH.B2, SH.H, SH.M
local GD = require(ServerStorage.DevTools.PropsSwampGatesData:Clone()) :: any
local piece, chamfered = H.piece, H.chamfered
local scaled = H.scaled
local frustumN = M.frustumN
local lump, lashing = TB.lump, TB.lashing

local SG = {}

local rgb = Color3.fromRGB
local rad = math.rad
local UP = Vector3.yAxis

local C = SH.COLORS
local MOSS, MUD_DARK, BLACKWOOD, BONE, WATER = C.MOSS, C.MUD_DARK, C.BLACKWOOD, C.BONE, C.WATER
local MOSS_TOP = MOSS:Lerp(C.OLIVE, 0.3)
local IRON = rgb(74, 78, 88) -- dark iron (straps, bands)
local IRON_LIGHT = rgb(108, 114, 126)
local ROPE = rgb(150, 124, 84) -- damp rope
local CRACK = rgb(34, 24, 20)

---------------------------------------------------------------------
-- shared helpers
---------------------------------------------------------------------
local function rows(kit: string, name: string?): { any }
	return GD.rows(kit, name)
end
SG.rows = rows

local function tone(rng: Random, c: Color3): Color3
	return scaled(c, H.TONES[H.toneIndex(rng, nil)])
end

-- moss tones by a face's world normal
local function mossTone(base: Color3): (Vector3) -> Color3
	return function(n: Vector3): Color3
		if n.Y > 0.5 then
			return base
		elseif n.Y > -0.2 then
			return scaled(base, 0.86)
		end
		return scaled(base, 0.72)
	end
end

-- a MeshPart with this MeshId and collision fidelity to clone (CollisionFidelity cannot be set from a script)
local function meshSource(meshId: string, fidelity: string): MeshPart?
	local roots = { ServerStorage:FindFirstChild("MapAssets"), ServerStorage:FindFirstChild("MapProps"), workspace:FindFirstChild("_Staging"), workspace:FindFirstChild("Zones") }
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

-- a bare part (or mesh clone) with a row's class, shape, size and place
local function rowPart(r: any): BasePart
	local p: BasePart
	if r.class == "MeshPart" then
		local src = meshSource(r.meshId, r.fidelity)
		assert(src, `PropsSwampGates: no MeshPart with {r.meshId} ({r.fidelity}) to clone`)
		p = src:Clone()
		p:ClearAllChildren()
		for key in pairs(p:GetAttributes()) do
			p:SetAttribute(key, nil)
		end
		for _, tag in ipairs(p:GetTags()) do
			p:RemoveTag(tag)
		end
	else
		p = Instance.new(r.class) :: BasePart
		if r.shape ~= "" and p:IsA("Part") then
			p.Shape = (Enum.PartType :: any)[r.shape]
		end
	end
	p.Size = r.size
	p.CFrame = r.cf
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- an exact copy of a row (name, size, place, colour, material, transparency, flags, its PointLight)
local function exactRow(parent: Instance, r: any): BasePart
	local p = rowPart(r)
	p.Name = r.name
	p.Color = r.color
	p.Material = (Enum.Material :: any)[r.material]
	p.Transparency = r.transparency
	p.CanCollide = r.collide
	p.CanQuery = r.query
	p.CanTouch = true
	if r.light then
		local l = Instance.new("PointLight")
		l.Name = "Light"
		l.Color, l.Range, l.Brightness, l.Shadows = r.light.color, r.light.range, r.light.brightness, r.light.shadows
		l.Parent = p
	end
	p.Parent = parent
	return p
end
SG.exactRow = exactRow

-- an invisible "Collision" copy of a colliding row (meshes keep their mesh and collision fidelity)
local function collider(m: Model, r: any, name: string?, on: boolean?): BasePart
	local p = rowPart(r)
	p.Name = name or "Collision"
	p.Color = r.color
	p.Transparency = 1
	p.CanCollide = on ~= false
	p.CanQuery = on ~= false
	p.CanTouch = true
	p.CastShadow = false
	if p:IsA("MeshPart") then
		(p :: MeshPart).TextureID = ""
	end
	p.Parent = m
	return p
end

-- the ends of a row's long axis (bottom, top)
local function longAxis(r: any): string
	local s = r.size
	if s.X >= s.Y and s.X >= s.Z then
		return "X"
	elseif s.Y >= s.Z then
		return "Y"
	end
	return "Z"
end
local function ends(r: any): (Vector3, Vector3)
	local ax = longAxis(r)
	local v = if ax == "X" then r.cf.XVector * r.size.X else if ax == "Y" then r.cf.YVector * r.size.Y else r.cf.ZVector * r.size.Z
	local a, b = r.cf.Position - v / 2, r.cf.Position + v / 2
	if a.Y > b.Y then
		a, b = b, a
	end
	return a, b
end
local function thick(r: any): number
	local ax = longAxis(r)
	local s = r.size
	return if ax == "X" then math.min(s.Y, s.Z) else if ax == "Y" then math.min(s.X, s.Z) else math.min(s.X, s.Y)
end

-- an 8-sided rotten log from a to b (r across the flats, tapering to r * taper), bark lines in 4 tones
local function logAB(list: { BasePart }, a: Vector3, b: Vector3, r: number, color: Color3, taper: number?)
	local L = (b - a).Magnitude
	table.insert(list, frustumN(8, r, r * (taper or 0.94), 0, L, H.frameY(a, (b - a).Unit) * CFrame.Angles(0, rad(22.5), 0), { color, scaled(color, 1.12), scaled(color, 0.88), scaled(color, 1.04) }))
end
SG.logAB = logAB

-- an iron band (8-sided ring) round an axis at p
local function ironRing(list: { BasePart }, p: Vector3, axis: Vector3, r: number, w: number)
	table.insert(list, frustumN(8, r + 0.06, r + 0.06, -w / 2, w / 2, H.frameY(p, axis.Unit) * CFrame.Angles(0, rad(22.5), 0), { IRON, scaled(IRON, 1.15) }))
end

-- a few dark cracks along a log (a .. b, radius r) on its front (-Z) side
local function logCracks(list: { BasePart }, rng: Random, a: Vector3, b: Vector3, r: number, n: number)
	local d = (b - a).Unit
	for _ = 1, n do
		local t = rng:NextNumber(0.15, 0.85)
		local len = rng:NextNumber(0.8, 1.8)
		local p = a:Lerp(b, t)
		local out = (Vector3.new(0, 0, -1) - d * d.Z)
		if out.Magnitude < 0.1 then
			out = Vector3.new(1, 0, 0)
		end
		out = out.Unit
		table.insert(list, piece("Part", Vector3.new(0.07, 0.07, len), CFrame.lookAt(p + out * (r * 1.02), p + out * (r * 1.02) + d) * CFrame.Angles(0, 0, rng:NextNumber(0, 1)), CRACK))
	end
end

-- a mud mound at the foot (flat bottom on the ground) with a moss mat on it
local function mud(U: any, rng: Random, p: Vector3, a: number, c: number)
	lump(U.Mud, rng, CFrame.new(p.X, 0.06, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), a, 0.32, c, function(n: Vector3): Color3
		return if n.Y > 0.5 then scaled(MUD_DARK, 1.15) else MUD_DARK
	end, 0.08)
	SH.mossPatch(U.Moss, rng, CFrame.new(p.X + rng:NextNumber(-0.4, 0.4) * a, 0.2, p.Z + rng:NextNumber(-0.4, 0.4) * c), a * 0.8, c * 0.7, 0.6)
end

-- a hanging vine with leaves: tapering segments of `color` from `top` down `len`, leaves (olive / green) on both sides
local function vineStrip(list: { BasePart }, rng: Random, top: Vector3, len: number, color: Color3)
	local p, y, k = top, 0, 0
	local phase = rng:NextNumber(0, 6.28)
	while y < len - 0.05 do
		local step = math.min(rng:NextNumber(0.5, 0.8), len - y)
		local yy = y + step
		local q = top + Vector3.new(math.sin(yy * 1.6 + phase) * 0.12, -yy, math.cos(yy * 1.3 + phase) * 0.08)
		table.insert(list, H.bar(p, q, 0.24 - 0.12 * y / len, scaled(color, 0.95 + 0.1 * math.sin(yy))))
		if k % 2 == 0 then
			local side = if k % 4 == 0 then 1 else -1
			local leafPos = q + Vector3.new(side * 0.26, 0.1, -0.05)
			table.insert(list, chamfered(Vector3.new(0.5, 0.08, 0.3), CFrame.new(leafPos) * CFrame.Angles(rad(70), 0, rad(side * 35)), if side > 0 then C.OLIVE else scaled(MOSS, 1.15), { "vertical" }, 0.12))
		end
		p, y, k = q, yy, k + 1
	end
end
SG.vineStrip = vineStrip

-- a lantern on today's parts: the core (exact, Neon + PointLight), an iron frame between today's plates (or round the
-- core), 4 rods, a pyramid cap and a ring on top
local function lanternFrame(U: any, m: Model, core: any, plates: { any }?)
	exactRow(m, core)
	local c, s = core.cf.Position, core.size
	local y0, y1 = c.Y - s.Y / 2 - 0.1, c.Y + s.Y / 2 + 0.1
	if plates and #plates == 2 then
		for _, pr in ipairs(plates) do
			table.insert(U.Iron, chamfered(pr.size, pr.cf, IRON, { "vertical" }, 0.12))
		end
		y0, y1 = math.min(plates[1].cf.Y, plates[2].cf.Y), math.max(plates[1].cf.Y, plates[2].cf.Y)
	else
		for _, y in ipairs({ y0, y1 }) do
			table.insert(U.Iron, chamfered(Vector3.new(s.X + 0.3, 0.16, s.Z + 0.3), CFrame.new(c.X, y, c.Z), IRON, { "vertical" }, 0.1))
		end
	end
	local hx = s.X / 2 + 0.08
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(U.Iron, piece("Part", Vector3.new(0.1, y1 - y0, 0.1), CFrame.new(c.X + sx * hx, (y0 + y1) / 2, c.Z + sz * hx), IRON))
		end
	end
	table.insert(U.Iron, frustumN(4, s.X / 2 + 0.25, 0.08, y1, y1 + 0.5, CFrame.new(c.X, 0, c.Z) * CFrame.Angles(0, rad(45), 0), { IRON, IRON_LIGHT }))
	table.insert(U.Iron, frustumN(8, 0.16, 0.16, y1 + 0.5, y1 + 0.62, CFrame.new(c.X, 0, c.Z), { IRON_LIGHT }))
	return y1 + 0.62
end

-- a bracket arm from a row (a thin iron bar row) and a hook down to the lantern top
local function bracketArm(U: any, r: any, lanternTop: number, lanternPos: Vector3)
	table.insert(U.Iron, piece("Part", r.size * Vector3.new(0.7, 0.7, 1), r.cf, IRON))
	local a, b = ends(r)
	local tip = if (a - lanternPos).Magnitude < (b - lanternPos).Magnitude then a else b
	local wall = if tip == a then b else a
	table.insert(U.Iron, piece("Part", Vector3.new(0.5, 0.7, 0.08), CFrame.new(wall), IRON_LIGHT))
	table.insert(U.Iron, H.bar(tip, Vector3.new(lanternPos.X, lanternTop, lanternPos.Z), 0.08, IRON))
end

-- a rotten sign frame round a sign row (rails, posts, iron corner plates, a broken corner chip, moss on top)
local function signFrame(U: any, rng: Random, r: any, color: Color3)
	local cf, s = r.cf, r.size
	local t = 0.42
	for _, sy in ipairs({ -1, 1 }) do
		table.insert(U.Wood, H.timber(Vector3.new(s.X + 2 * t, t, s.Z + 0.24), cf * CFrame.new(0, sy * (s.Y / 2 + t / 2), 0), tone(rng, color), 0.08))
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Wood, H.timber(Vector3.new(t, s.Y, s.Z + 0.24), cf * CFrame.new(sx * (s.X / 2 + t / 2), 0, 0), tone(rng, color), 0.08))
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local pz = sz * (s.Z / 2 + 0.15)
				table.insert(U.Iron, piece("Part", Vector3.new(0.7, 0.7, 0.06), cf * CFrame.new(sx * (s.X / 2 + 0.1), sy * (s.Y / 2 + 0.1), pz), IRON))
				H.rivet(U.Iron, (cf * CFrame.new(sx * (s.X / 2 + 0.1), sy * (s.Y / 2 + 0.1), pz + sz * 0.04)).Position, 0.12)
			end
		end
	end
	SH.mossPatch(U.Moss, rng, cf * CFrame.new(-s.X * 0.25, s.Y / 2 + t, 0), 2.4, s.Z + 0.3, 0.5)
	SH.hangingMoss(U.Hang, rng, (cf * CFrame.new(s.X * 0.3, -s.Y / 2 - t, 0)).Position, 1.0)
end

-- the support planes of a mesh row's convex hull, measured with ray grids (the jungle rock recipe, a denser grid):
-- { { n, d } } in the kit's space
local function hullPlanes(r: any, nDirs: number, grid: number): { any }
	local probe = rowPart(r)
	probe.Transparency = 1
	probe.CanCollide = true
	probe.CanQuery = true
	local far = CFrame.new(0, 30000, 0)
	probe.CFrame = far * r.cf
	probe.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { probe }
	local c = probe.Position
	local radius = probe.Size.Magnitude / 2 + 1
	local planes = {}
	local golden = math.pi * (3 - math.sqrt(5))
	local dirs = {}
	for i = 0, nDirs - 1 do
		local y = 1 - (i + 0.5) / nDirs * 1.7
		local rr = math.sqrt(math.max(0, 1 - y * y))
		local a = i * golden
		table.insert(dirs, Vector3.new(math.cos(a) * rr, y, math.sin(a) * rr).Unit)
	end
	table.insert(dirs, -UP)
	for _, d in ipairs(dirs) do
		local helper = if math.abs(d.Y) < 0.9 then UP else Vector3.xAxis
		local u = helper:Cross(d).Unit
		local v = d:Cross(u).Unit
		local best = -math.huge
		for i = 0, grid - 1 do
			for j = 0, grid - 1 do
				local o = c + d * radius + u * ((i / (grid - 1) * 2 - 1) * radius) + v * ((j / (grid - 1) * 2 - 1) * radius)
				local hit = workspace:Raycast(o, -d * radius * 2, params)
				if hit then
					best = math.max(best, (hit.Position - c):Dot(d))
				end
			end
		end
		if best > -math.huge then
			local centre = (far:Inverse() * CFrame.new(c)).Position
			table.insert(planes, { n = d, d = centre:Dot(d) + best + 0.03 })
		end
	end
	probe:Destroy()
	return planes
end
SG.hullPlanes = hullPlanes

-- a faceted rock (one convex solid) on a mesh row's hull, its faces toned by their normal (lit tops lighter)
local function hullRock(list: { BasePart }, r: any, planes: { any })
	local base = r.color
	local lo, hi = r.cf.Position - r.size, r.cf.Position + r.size
	TB.solidOf(list, CFrame.identity, lo, hi, planes, function(n: Vector3): Color3
		if n.Y > 0.6 then
			return scaled(base, 1.12)
		elseif n.Y > 0.1 then
			return base
		elseif n.Y > -0.4 then
			return scaled(base, 0.9)
		end
		return scaled(base, 0.78)
	end)
end

-- the top of a plane set straight above `from` (a point inside it)
local function topOf(planes: { any }, from: Vector3): number
	local t = math.huge
	for _, pl in ipairs(planes) do
		if pl.n.Y > 1e-6 then
			t = math.min(t, (pl.d - pl.n:Dot(from)) / pl.n.Y)
		end
	end
	return from.Y + t
end

-- the door pieces merged into a union UNDER the Barrier (never colliding, not queryable)
local function under(barrier: BasePart, name: string, list: { BasePart }, opts: any?)
	if #list == 0 then
		return
	end
	local u = H.merge(barrier :: any, name, list, opts or {})
	u.CanCollide = false
	u.CanQuery = false
	u.CanTouch = true
	u.Parent = barrier
end
local GLOW = { material = Enum.Material.Neon, shadow = false }

-- the Barrier: today's row exactly, the PrimaryPart (pivot at the origin), attribute BarrierDecorIsChildOfBarrier
local function barrierOf(m: Model, kit: string): BasePart
	local b = exactRow(m, rows(kit, "Barrier")[1])
	m:SetAttribute("BarrierDecorIsChildOfBarrier", true)
	return b
end
local function setPrimary(m: Model, barrier: BasePart)
	m.PrimaryPart = barrier
	barrier.PivotOffset = barrier.CFrame:Inverse()
end

-- the variants folder: Configuration attributes by part name
local function variants(m: Model, list: { [string]: { [string]: any } })
	local folder = Instance.new("Folder")
	folder.Name = "_Variants"
	for name, attrs in pairs(list) do
		local cfg = Instance.new("Configuration")
		cfg.Name = name
		for k, v in pairs(attrs) do
			cfg:SetAttribute(k, v)
		end
		cfg.Parent = folder
	end
	folder.Parent = m
end

-- a row is one of today's raven parts (kept exactly): a non-colliding "Part" within 2.6 of the raven's body
local function ravenOf(kit: string): ({ any }, (any) -> boolean)
	local body = nil
	for _, r in ipairs(rows(kit, "Part")) do
		if not r.collide and math.abs(r.size.X - 1.3) < 0.02 and math.abs(r.size.Z - 2.86) < 0.02 then
			body = r
		end
	end
	local list = {}
	local function isRaven(r: any): boolean
		return body ~= nil and r.name == "Part" and not r.collide and r.parent == "" and (r.cf.Position - body.cf.Position).Magnitude < 2.6
	end
	for _, r in ipairs(rows(kit, "Part")) do
		if isRaven(r) then
			table.insert(list, r)
		end
	end
	return list, isRaven
end

-- the raven: the swamp_raven MapProp nested at today's raven (its 8 parts are Crow_A at scale 1.3; the body row gives the
-- pose: pivot = body * (the kit's body place x 1.3)^-1), tagged so the sync keeps it current; nothing of it collides
local function nestRaven(m: Model, raven: { any })
	local body = nil
	for _, r in ipairs(raven) do
		if math.abs(r.size.X - 1.3) < 0.02 and math.abs(r.size.Z - 2.86) < 0.02 then
			body = r
		end
	end
	assert(body, "PropsSwampGates: the raven's body row missing")
	local MD = require(ServerStorage.DevTools.PropsSwampMagicData:Clone()) :: any
	local kitBody = nil
	for _, r in ipairs(MD.rows("Crow_A", "Part")) do
		if math.abs(r.size.Z - 2.2) < 0.01 then
			kitBody = r
		end
	end
	local t = ServerStorage.MapProps:FindFirstChild("swamp_raven")
	assert(t and kitBody, "PropsSwampGates: ServerStorage.MapProps.swamp_raven missing")
	local s = body.size.Z / kitBody.size.Z
	local bird = t:Clone()
	bird.Name = "Raven"
	bird:ScaleTo(s)
	bird:PivotTo(body.cf * (CFrame.new(kitBody.cf.Position * s) * kitBody.cf.Rotation):Inverse())
	bird:AddTag("MapProp")
	bird:SetAttribute("MapPropId", "swamp_raven")
	bird:SetAttribute("MapPropVersion", tostring(t:GetAttribute("MapPropVersion") or "?") .. "|")
	bird.Parent = m
end

-- the skull emblem (round 2): the swamp_skull_knocker MapProp nested at today's door skull (today's skull is the knocker
-- kit at scale cranium / 2.6 = 1.9: its sockets, eyes, nose, teeth line and ring bars match the knocker's x 1.9), so the
-- emblem is the new 04 skull with its iron frame and ring; tagged so the sync keeps it current; nothing of it collides
local function nestSkull(parent: Instance, cranium: any)
	local MD = require(ServerStorage.DevTools.PropsSwampMagicData:Clone()) :: any
	local kitCr = MD.rows("Skull_Knocker_Door", "Cranium")[1]
	local t = ServerStorage.MapProps:FindFirstChild("swamp_skull_knocker")
	assert(t and kitCr, "PropsSwampGates: ServerStorage.MapProps.swamp_skull_knocker missing")
	local s = cranium.size.X / kitCr.size.X
	local skull = t:Clone()
	skull.Name = "Skull"
	skull:ScaleTo(s)
	skull:PivotTo(cranium.cf * CFrame.new(-kitCr.cf.Position * s))
	skull:AddTag("MapProp")
	skull:SetAttribute("MapPropId", "swamp_skull_knocker")
	skull:SetAttribute("MapPropVersion", tostring(t:GetAttribute("MapPropVersion") or "?") .. "|")
	skull.Parent = parent
end

-- boards over a door plank row (in its frame; the face at local -Z): n boards with gaps, crooked a little, ragged
-- tops, 3 tones; a crack now and then. inPlace: the boards take the row's own depth (nothing in front of it moves)
local function doorBoards(list: { BasePart }, rng: Random, r: any, n: number, color: Color3, face: number, inPlace: boolean?)
	local s, cf = r.size, r.cf
	local bw = s.X / n
	local z, t = if inPlace then 0 else face * (s.Z / 2 + 0.11), if inPlace then s.Z else 0.22
	for i = 0, n - 1 do
		local x = -s.X / 2 + (i + 0.5) * bw
		local h = s.Y - rng:NextNumber(0, 0.5)
		local c = tone(rng, color)
		local bcf = cf * CFrame.new(x, -s.Y / 2 + h / 2, z) * CFrame.Angles(0, 0, rad(rng:NextNumber(-1.2, 1.2)))
		table.insert(list, chamfered(Vector3.new(bw - 0.08, h, t), bcf, c, { "vertical" }, 0.05))
		if rng:NextNumber() < 0.4 then
			table.insert(list, piece("Part", Vector3.new(0.06, rng:NextNumber(1.5, 3.5), 0.03), bcf * CFrame.new(rng:NextNumber(-bw * 0.25, bw * 0.25), rng:NextNumber(-h * 0.3, h * 0.3), face * (t / 2 + 0.01)), CRACK))
		end
	end
end

-- an iron strap across a door face (from x0 to x1 at height y, in the frame cf at depth z) with rivets
local function strap(list: { BasePart }, cf: CFrame, x0: number, x1: number, y: number, z: number, h: number)
	table.insert(list, piece("Part", Vector3.new(x1 - x0, h, 0.08), cf * CFrame.new((x0 + x1) / 2, y, z), IRON))
	local n = math.max(2, math.floor((x1 - x0) / 1.4))
	for k = 0, n - 1 do
		local x = x0 + 0.3 + k * (x1 - x0 - 0.6) / (n - 1)
		H.rivet(list, (cf * CFrame.new(x, y, z + math.sign(z) * 0.06)).Position, 0.13)
	end
end

-- an iron ring handle on a round plate at p, facing -Z (or +Z with face = 1)
local function ringHandle(list: { BasePart }, p: Vector3, face: number)
	local hc = CFrame.new(p) * (if face > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
	table.insert(list, piece("Part", Vector3.new(0.06, 0.7, 0.7), hc * CFrame.Angles(0, rad(90), 0), IRON_LIGHT, { shape = Enum.PartType.Cylinder }))
	for k = 0, 7 do
		local a = k * math.pi / 4
		table.insert(list, piece("Part", Vector3.new(0.3, 0.08, 0.08), hc * CFrame.new(math.cos(a) * 0.36, -0.36 + math.sin(a) * 0.36, -0.07) * CFrame.Angles(0, 0, a + math.pi / 2), IRON))
	end
end

---------------------------------------------------------------------
-- 01 MUSHROOM VINE ARCH (kit MapAssets.Gates.EntryArch_Swamp -> Zones.Swamp.Swamp_1.EntryArch, attr ZoneId; 47 parts)
---------------------------------------------------------------------
-- From the plains entry arch: today's crooked frame (3 tilted post segments a side) as rotten 8-sided logs with iron
-- bands, rivets and a rope lashing at every joint, cracks and moss; today's 2 foot roots as bent tapering roots and 2
-- more small roots a foot sinking into a mud base with moss; today's 2 beams as rotten logs with iron bands at the
-- joints, moss mats on top and hanging moss; today's NameSign kept exactly in a rotten frame with iron corners, today's
-- 2 sign posts as timbers with rope; today's vine bar and 10 vine strips as a mossy rod and curtains of vines with
-- leaves (their colours, places and lengths); the 2 lanterns: today's Neon cores and PointLights kept, today's plates
-- as an iron frame with rods, a pyramid cap and today's chain as links; today's ghost mushroom meshes kept (glow), small
-- pale mushrooms next to them; today's raven as the nested swamp_raven. Colliders: today's posts, roots, beams, sign posts
-- (invisible), the NameSign itself.
function SG.swamp_vine_arch(): Model
	local kit = "EntryArch_Swamp"
	local m = Instance.new("Model")
	m.Name = "swamp_vine_arch"
	local rng = Random.new(20261031)
	H.setBevelSelf(true)
	local U: any = { Logs = {}, Wood = {}, Iron = {}, Rope = {}, Vines = {}, Moss = {}, Hang = {}, Mud = {}, Mush = {} }
	local raven, isRaven = ravenOf(kit)
	local plates = {}
	for _, r in ipairs(rows(kit, "Part")) do
		if isRaven(r) then
			continue
		end
		local hex = r.color:ToHex()
		if r.collide and longAxis(r) ~= "Y" and r.size.Z > 5 then
			local a, b = ends(r)
			local rr = thick(r) / 2 + 0.03
			if r.cf.Y < 1.6 then
				-- a foot root: bent (2 segments), tapering into the mud
				local mid = a:Lerp(b, 0.5) + Vector3.new(0, 0.35, 0)
				logAB(U.Logs, b, mid, rr, r.color, 0.85)
				logAB(U.Logs, mid, a - (b - a).Unit * 0.4 - Vector3.new(0, 0.3, 0), rr * 0.85, r.color, 0.45)
			else
				logAB(U.Logs, a, b, rr, r.color, 0.92)
				logCracks(U.Wood, rng, a, b, rr, 2)
				for _, e in ipairs({ a, b }) do
					if e.Y > 1 then
						ironRing(U.Iron, a:Lerp(b, if e == a then 0.1 else 0.9), (b - a).Unit, rr, 0.4)
					end
				end
				lashing(U.Rope, a:Lerp(b, 0.82), (b - a).Unit, rr, 3, rng)
			end
		elseif r.collide then
			-- a sign post
			table.insert(U.Wood, H.timber(r.size, r.cf, tone(rng, r.color), 0.08))
			lashing(U.Rope, r.cf.Position - Vector3.new(0, 0.6, 0), UP, r.size.X / 2, 2, rng)
		elseif hex == "373a41" then
			table.insert(plates, r)
		elseif r.size.X > 6 then
			-- the vine bar: a mossy rod
			local a, b = ends(r)
			logAB(U.Vines, a, b, 0.3, scaled(MOSS, 0.85), 1)
			SH.mossPatch(U.Moss, rng, CFrame.new(r.cf.Position + Vector3.new(0, 0.3, 0)), 2.5, 0.6, 0.4)
		elseif math.abs(r.size.X - 0.9) < 0.02 then
			vineStrip(U.Vines, rng, r.cf.Position + Vector3.new(0, r.size.Y / 2, 0), r.size.Y, r.color)
		end
	end
	-- the foot roots' companions and the mud bases
	for _, sx in ipairs({ -1, 1 }) do
		local foot = Vector3.new(sx * 13.6, 0, 0.1)
		mud(U, rng, foot, 3.4, 2.8)
		for k = 1, 2 do
			local ang = rad(if k == 1 then 200 else -20) + (if sx > 0 then 0 else math.pi)
			local a = foot + Vector3.new(0, 1.6, 0)
			local b = foot + Vector3.new(math.cos(ang) * 3.2, -0.2, math.sin(ang) * 2.6)
			logAB(U.Logs, a, b, 0.42, rgb(62, 46, 36), 0.35)
		end
	end
	-- the beams: rotten logs, iron bands at the joints, moss mats on top, hanging moss under them
	for _, r in ipairs(rows(kit, "Beam")) do
		local a, b = ends(r)
		local rr = thick(r) / 2 + 0.02
		logAB(U.Logs, a, b, rr, r.color, 0.95)
		logCracks(U.Wood, rng, a, b, rr, 3)
		for _, t in ipairs({ 0.08, 0.92 }) do
			ironRing(U.Iron, a:Lerp(b, t), (b - a).Unit, rr, 0.45)
		end
		for _, t in ipairs({ 0.3, 0.7 }) do
			SH.mossPatch(U.Moss, rng, CFrame.fromMatrix(a:Lerp(b, t) + Vector3.new(0, rr * 0.9, 0), (b - a).Unit, UP), 2.2, rr * 1.6, 0.6)
		end
		for _, t in ipairs({ 0.2, 0.55, 0.85 }) do
			SH.hangingMoss(U.Hang, rng, a:Lerp(b, t) - Vector3.new(0, rr * 0.9, 0), rng:NextNumber(0.8, 1.6))
		end
	end
	-- the name sign (exact) in a rotten frame
	local ns = rows(kit, "NameSign")[1]
	exactRow(m, ns)
	signFrame(U, rng, ns, rgb(62, 46, 36))
	-- the lanterns (exact cores + lights) in iron frames on today's plates; today's chains as links
	for _, lr in ipairs(rows(kit, "Lantern")) do
		local mine = {}
		for _, pr in ipairs(plates) do
			if (pr.cf.Position - lr.cf.Position).Magnitude < 1.5 then
				table.insert(mine, pr)
			end
		end
		local top = lanternFrame(U, m, lr, mine)
		for _, ch in ipairs(rows(kit, "Chain")) do
			if math.abs(ch.cf.X - lr.cf.X) < 0.5 then
				local a, b = ends(ch)
				a = Vector3.new(a.X, top, a.Z)
				local n = 4
				for k = 0, n - 1 do
					local p = a:Lerp(b, (k + 0.5) / n)
					table.insert(U.Iron, piece("Part", Vector3.new(0.08, (b - a).Magnitude / n + 0.08, 0.26), CFrame.new(p) * CFrame.Angles(0, if k % 2 == 0 then 0 else rad(90), 0), IRON_LIGHT))
				end
			end
		end
	end
	-- the ghost mushrooms (today's meshes, exact) and small pale ones next to them; the raven (nested swamp_raven)
	for _, name in ipairs({ "Caps", "Stems" }) do
		for _, r in ipairs(rows(kit, name)) do
			exactRow(m, r)
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		SH.mushrooms(U.Mush, rng, Vector3.new(sx * 15.4, 0.15, -3.6), 3, 0.5)
	end
	nestRaven(m, raven)

	TB.finishTB(m, "swamp_vine_arch", U, "Logs", {})
	-- colliders: today's colliding parts (the NameSign is itself); the left beam: the game copy's, and the kit's for
	-- Variant "Kit"
	for _, r in ipairs(rows(kit)) do
		if r.collide and r.name ~= "NameSign" then
			local name = if r.name == "Beam" and r.cf.X < 0 then "CollisionBeamGame" else nil
			collider(m, r, name)
		end
	end
	local kitBeam = GD.rowOf(GD.KitRows.EntryArch_Swamp[1])
	collider(m, kitBeam, "CollisionBeamKit", false)
	variants(m, { Kit = { CanCollide_CollisionBeamGame = false, CanQuery_CollisionBeamGame = false, CanCollide_CollisionBeamKit = true, CanQuery_CollisionBeamKit = true } })
	return m
end

---------------------------------------------------------------------
-- 02 WOODEN GATE WITH THE DEAD TREES (kit MapAssets.Gates.Gate_Swamp_2 -> Zones.Swamp.Swamp_2.Gate, attr SubZoneId;
-- 54 parts)
---------------------------------------------------------------------
-- From the plains / tundra palisade gate: today's 8 stakes as crooked rotten logs (today's tilts and heights) with
-- 8-sided points, iron bands with rivets across each palisade at 2 heights, rope lashings, moss and mud at the feet;
-- today's lintel as a rotten log with iron bands, cracks, hanging moss and vines; today's PriceSign kept exactly in a
-- rotten frame, today's 2 sign ropes as ropes; the 2 lanterns: cores + lights kept, iron frames on today's brackets;
-- the 2 dead trees (round 2: the face tree's DEAD-TREE RECIPE): tapered bark trunks with ridges and knuckles, finer
-- limbs with twigs spreading into today's crown, roots spreading into the mud, bark shelves, moss and hanging moss
-- (today's meshes only collide now, as their own Hull colliders); today's mushroom meshes kept, the raven nested. THE
-- DOOR (under today's Barrier, the PrimaryPart, colliding): today's 6 planks as 3 crooked boards each (front) and 2
-- (back), today's 2 cross beams as rotten timbers with rivets, the centre split, thick iron straps with rivets across
-- both leaves, strap hinges, today's 2 handles as iron plates with ring handles.
function SG.swamp_tree_gate(): Model
	local kit = "Gate_Swamp_2"
	local m = Instance.new("Model")
	m.Name = "swamp_tree_gate"
	local rng = Random.new(20261032)
	H.setBevelSelf(true)
	local U: any = { Logs = {}, Wood = {}, Iron = {}, Rope = {}, Vines = {}, Moss = {}, Hang = {}, Mud = {}, Mush = {}, Branches = {} }
	local raven, isRaven = ravenOf(kit)
	-- the stakes: crooked logs with points (today's StakeTip places), iron bands across the palisade, rope, mud
	for _, r in ipairs(rows(kit, "Stake")) do
		local a, b = ends(r)
		local rr = r.size.X / 2 * 0.95
		logAB(U.Logs, a - Vector3.new(0, 0.2, 0), b, rr, r.color, 0.96)
		local d = (b - a).Unit
		table.insert(U.Logs, frustumN(8, rr * 0.96, 0.08, 0, 2.0, H.frameY(b, d) * CFrame.Angles(0, rad(22.5), 0), { scaled(r.color, 1.1), r.color, scaled(r.color, 0.9) }))
		logCracks(U.Wood, rng, a, b, rr, 2)
		for _, y in ipairs({ 4.5, 13.0 }) do
			ironRing(U.Iron, a:Lerp(b, (y - a.Y) / (b.Y - a.Y)), d, rr, 0.5)
		end
		lashing(U.Rope, a:Lerp(b, (9 - a.Y) / (b.Y - a.Y)), d, rr, 3, rng)
		SH.mossPatch(U.Moss, rng, CFrame.new(a.X, 0.15, a.Z - rr - 0.4), 1.8, 1.0, 0.6)
	end
	for _, sx in ipairs({ -1, 1 }) do
		mud(U, rng, Vector3.new(sx * 19.5, 0, -1.5), 6.5, 2.2)
	end
	-- the lintel: a rotten log, iron bands, hanging moss and 2 vines
	do
		local r = rows(kit, "Lintel")[1]
		local a, b = ends(r)
		local rr = thick(r) / 2 + 0.03
		logAB(U.Logs, a, b, rr, r.color, 0.97)
		logCracks(U.Wood, rng, a, b, rr, 4)
		for _, t in ipairs({ 0.12, 0.5, 0.88 }) do
			ironRing(U.Iron, a:Lerp(b, t), (b - a).Unit, rr, 0.5)
		end
		for _, t in ipairs({ 0.25, 0.42, 0.62, 0.78 }) do
			SH.hangingMoss(U.Hang, rng, a:Lerp(b, t) - Vector3.new(0, rr * 0.9, 0.2), rng:NextNumber(0.9, 1.8))
		end
		vineStrip(U.Vines, rng, a:Lerp(b, 0.15) - Vector3.new(0, rr, 0.5), 3.2, rgb(56, 90, 46))
		vineStrip(U.Vines, rng, a:Lerp(b, 0.86) - Vector3.new(0, rr, 0.5), 2.6, rgb(128, 120, 62))
	end
	-- the price sign (exact) in a rotten frame, today's 2 ropes as ropes
	local ps = rows(kit, "PriceSign")[1]
	exactRow(m, ps)
	signFrame(U, rng, ps, rgb(62, 46, 36))
	local brackets = {}
	for _, r in ipairs(rows(kit, "Part")) do
		if r.parent ~= "" or isRaven(r) then
			continue
		end
		local hex = r.color:ToHex()
		if hex == "c4a068" then
			local a, b = ends(r)
			table.insert(U.Rope, frustumN(6, 0.1, 0.1, 0, (b - a).Magnitude, H.frameY(a, (b - a).Unit), { ROPE, scaled(ROPE, 0.9) }))
		elseif hex == "373a41" then
			table.insert(brackets, r)
		end
	end
	for _, lr in ipairs(rows(kit, "Lantern")) do
		local top = lanternFrame(U, m, lr, nil)
		for _, br in ipairs(brackets) do
			if (br.cf.Position - lr.cf.Position).Magnitude < 2 then
				bracketArm(U, br, top, lr.cf.Position)
			end
		end
	end
	-- the dead trees (round 2: THE DEAD-TREE RECIPE of the face tree, PropsSwampTrees.deadTrunk / fineBranch): a tapered
	-- bark trunk with ridges and knuckles inside today's tree mesh (the mesh only collides now: its Hull copy, invisible),
	-- finer limbs with twigs spreading into today's crown (measured on the mesh: the crown leans to the mesh's +Z
	-- diagonals), roots spreading into the mud, bark shelves, moss, hanging moss
	local ST = require(ServerStorage.DevTools.PropsSwampTrees:Clone()) :: any
	for ti, r in ipairs(rows(kit, "Tree")) do
		local Hh = r.size.Y
		local foot = Vector3.new(r.cf.X, 0, r.cf.Z)
		local s = Hh / 36
		local function L(x: number, y: number, z: number): Vector3
			local v = r.cf:VectorToWorldSpace(Vector3.new(x, 0, z))
			return foot + Vector3.new(v.X, y * s, v.Z)
		end
		local P = { L(0, -0.3, 0), L(0.2, 10, 0.1), L(-0.2, 19, 0.3), L(0.1, 28, 0.2) }
		local Rr = { 3.4, 2.8, 2.1, 1.1 }
		ST.deadTrunk(U.Logs, U.Wood, rng, P, Rr, r.color, 3)
		local function R(y: number): number
			local t = math.clamp(y / (28 * s), 0, 1)
			return 3.4 + (1.1 - 3.4) * t
		end
		-- the limbs (mesh space: from the trunk to the crown)
		for k, br in ipairs({ { 17, 4.5, 26, 4.5, 0.62 }, { 19, -4.8, 27, 4.2, 0.6 }, { 22, 3.8, 31, -1.5, 0.5 }, { 24, -3.2, 33, -1.2, 0.48 }, { 15, -4.0, 21, -2.0, 0.55 } }) do
			local a = L(0, br[1], 0)
			local b = L(br[2], br[3], br[4])
			ST.fineBranch(U.Branches, U.Branches, rng, a, b, br[5], r.color, nil)
			if k <= 3 then
				SH.hangingMoss(U.Hang, rng, a:Lerp(b, 0.6) - Vector3.new(0, 0.3, 0), rng:NextNumber(1.2, 2.2))
			end
		end
		-- roots at the foot
		for k = 0, 5 do
			local ang = k * math.pi / 3 + 0.3 + ti
			local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local p = foot + dir * (R(1.2) - 0.4) + Vector3.new(0, 1.2, 0)
			logAB(U.Branches, p, p + dir * rng:NextNumber(2.0, 2.8) + Vector3.new(0, -1.5, 0), 0.6, r.color, 0.35)
		end
		mud(U, rng, foot, 4.0, 3.4)
		-- bark shelves (fungus, not glowing) and moss on the trunk
		for k, y in ipairs({ 7, 12, 17 }) do
			local ang = k * 2.2 + ti
			local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local p = foot + Vector3.new(0, y * s, 0) + dir * R(y * s)
			table.insert(U.Mush, frustumN(8, 0.7, 0.35, 0, 0.22, CFrame.new(p + dir * 0.3), { rgb(122, 104, 78), rgb(104, 88, 66) }))
			SH.mossPatch(U.Moss, rng, CFrame.fromMatrix(p + dir * 0.05 + Vector3.new(0, 0.8, 0), UP:Cross(dir).Unit, dir), 1.4, 1.0, 0.5)
		end
	end
	-- the ghost mushrooms exactly; the raven (the nested swamp_raven at today's pose)
	for _, name in ipairs({ "Caps", "Stems" }) do
		for _, r in ipairs(rows(kit, name)) do
			exactRow(m, r)
		end
	end
	nestRaven(m, raven)

	-- THE DOOR under today's Barrier
	local barrier = barrierOf(m, kit)
	H.setBevelSelf(true)
	local D = { Boards = {}, Iron = {}, Wood = {} }
	for _, r in ipairs(rows(kit, "Plank")) do
		doorBoards(D.Boards, rng, r, 3, scaled(r.color, 0.9), -1)
	end
	local bcf = barrier.CFrame
	local bs = barrier.Size
	for i = 0, 5 do
		local x = -bs.X / 2 + (i + 0.5) * bs.X / 6
		table.insert(D.Boards, chamfered(Vector3.new(bs.X / 6 - 0.1, bs.Y - 0.3, 0.2), bcf * CFrame.new(x, -0.15, bs.Z / 2 + 0.1), tone(rng, rgb(84, 62, 44)), { "vertical" }, 0.05))
	end
	for _, r in ipairs(rows(kit, "Part")) do
		if r.parent ~= "Barrier" then
			continue
		end
		local hex = r.color:ToHex()
		if hex == "373a41" then
			-- today's handle: an iron plate with a ring handle
			table.insert(D.Iron, chamfered(r.size * Vector3.new(1, 1, 0.4), r.cf, IRON, { "vertical" }, 0.1))
			ringHandle(D.Iron, r.cf.Position + Vector3.new(0, -0.2, -0.25), -1)
		elseif hex == "1e1613" then
			table.insert(D.Wood, piece("Part", r.size, r.cf * CFrame.new(0, 0, -0.22), BLACKWOOD))
		else
			-- a cross beam: a rotten timber with rivets
			table.insert(D.Wood, H.timber(r.size + Vector3.new(0.1, 0.1, 0), r.cf * CFrame.new(0, 0, 0), tone(rng, rgb(58, 44, 34)), 0.1))
			local a, b = ends(r)
			for _, t in ipairs({ 0.1, 0.5, 0.9 }) do
				H.rivet(D.Iron, a:Lerp(b, t) + Vector3.new(0, 0, -0.4), 0.16)
			end
		end
	end
	for _, y in ipairs({ 2.2, 14.0 }) do
		strap(D.Iron, bcf, -bs.X / 2 + 0.2, -0.3, y - bs.Y / 2, -bs.Z / 2 - 0.52, 0.45)
		strap(D.Iron, bcf, 0.3, bs.X / 2 - 0.2, y - bs.Y / 2, -bs.Z / 2 - 0.52, 0.45)
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(D.Iron, piece("Part", Vector3.new(0.8, 0.4, 0.4), bcf * CFrame.new(sx * (bs.X / 2 + 0.05), y - bs.Y / 2, -bs.Z / 2 - 0.3) * CFrame.Angles(0, 0, rad(90)), IRON_LIGHT, { shape = Enum.PartType.Cylinder }))
		end
	end
	under(barrier, "DoorBoards", D.Boards)
	under(barrier, "DoorWood", D.Wood)
	under(barrier, "DoorIron", D.Iron)

	TB.finishTB(m, "swamp_tree_gate", U, "Logs", {})
	setPrimary(m, barrier)
	for _, r in ipairs(rows(kit)) do
		if r.collide and r.parent == "" and r.name ~= "Barrier" and r.name ~= "PriceSign" then
			collider(m, r)
		end
	end
	return m
end

---------------------------------------------------------------------
-- 03 ROCK BARRICADE (kit MapAssets.Gates.Gate_Swamp_3 -> Zones.Swamp.Swamp_3.Gate, attr SubZoneId; 52 parts)
---------------------------------------------------------------------
-- The boulders with the jungle rock recipe: each of today's 4 rock meshes as one faceted convex rock built on its
-- measured hull (today's colours, lit tops lighter, undersides darker) with layered stone (round 2: 2 dark strata lines
-- and a lighter ledge round each rock), today's 2 moss meshes as soft moss (round 2: a crown cushion and 9 soft pads on
-- the upper facets instead of a cut cap) with hanging moss; today's 4 frame
-- sticks and 2 root beams as dark rotten logs with rope lashings; today's PriceSign kept exactly in a dark frame; the
-- mushroom mesh kept (glow) and pale mushrooms by it, 2 small clusters of glowing mushrooms (round 2); mud at the feet. THE BARRICADE (under today's invisible Barrier,
-- the PrimaryPart): today's dark backing, today's 10 branches as thick crossed 8-sided branches with rope lashings
-- where they cross, today's 18 thorns as small bones (a shaft and 2 knobs), today's 5 magenta orbs kept exactly
-- (Neon) in dark iron rings. Colliders: today's rock meshes (Hull), sticks and beams (invisible), the PriceSign and the
-- Barrier themselves.
function SG.swamp_rock_gate(): Model
	local kit = "Gate_Swamp_3"
	local m = Instance.new("Model")
	m.Name = "swamp_rock_gate"
	local rng = Random.new(20261033)
	H.setBevelSelf(true)
	local U: any = { Rock = {}, MossCap = {}, Logs = {}, Wood = {}, Iron = {}, Rope = {}, Moss = {}, Hang = {}, Mud = {}, Mush = {}, Glow = {} }
	local mossRows = rows(kit, "Moss")
	-- the surface point of a convex rock (planes) from `from` along the horizontal `dir`
	local function rockEdge(planes: { any }, from: Vector3, dir: Vector3): Vector3?
		local t = math.huge
		for _, pl in ipairs(planes) do
			local nd = pl.n:Dot(dir)
			if nd > 1e-6 then
				t = math.min(t, (pl.d - pl.n:Dot(from)) / nd)
			end
		end
		return if t < 60 then from + dir * t else nil
	end
	for _, r in ipairs(rows(kit, "Rock")) do
		local planes = hullPlanes(r, 44, 31)
		hullRock(U.Rock, r, planes)
		-- layered stone (round 2): 2 dark strata lines and a lighter ledge round the rock at 3 heights
		do
			local rTop = topOf(planes, r.cf.Position)
			local base = r.cf.Y - r.size.Y / 2
			for li, f in ipairs({ 0.22, 0.42, 0.6 }) do
				local y = base + (rTop - base) * f
				local from = Vector3.new(r.cf.X, y, r.cf.Z)
				local prev, first = nil, nil
				for k = 0, 16 do
					local a = (k % 16) * math.pi / 8 + li * 0.2
					local p = rockEdge(planes, from, Vector3.new(math.cos(a), 0, math.sin(a)))
					if p then
						p += Vector3.new(math.cos(a), 0, math.sin(a)) * 0.04 + Vector3.new(0, rng:NextNumber(-0.25, 0.25), 0)
						if prev then
							table.insert(U.Wood, H.bar(prev, p, if li == 2 then 0.32 else 0.16, if li == 2 then scaled(r.color, 1.12) else scaled(r.color, 0.55)))
						end
						prev = p
					else
						prev = nil
					end
				end
			end
		end
		-- a moss cap where today's moss mesh sits: the rock's facets 0.3 out, cut a quarter of the height down
		local hasMoss = false
		for _, mr in ipairs(mossRows) do
			if (Vector3.new(mr.cf.X, 0, mr.cf.Z) - Vector3.new(r.cf.X, 0, r.cf.Z)).Magnitude < 1 then
				hasMoss = true
			end
		end
		if hasMoss then
			local top = topOf(planes, r.cf.Position)
			local capH = r.size.Y * 0.24
			local capPlanes = {}
			for _, pl in ipairs(planes) do
				table.insert(capPlanes, { n = pl.n, d = pl.d + 0.3 })
			end
			table.insert(capPlanes, { n = -UP, d = -(top - capH) })
			-- the moss (round 2: soft patches, not a cut cap): a crown cushion on top and 9 soft pads round the upper
			-- facets, each sitting on the rock's surface
			local mossTone = function(n: Vector3): Color3
				return if n.Y > 0.5 then MOSS_TOP elseif n.Y > -0.2 then MOSS else scaled(MOSS, 0.8)
			end
			lump(U.MossCap, rng, CFrame.new(r.cf.X, top - 0.55, r.cf.Z), r.size.X * 0.16, 0.75, r.size.Z * 0.16, mossTone)
			for k = 0, 8 do
				local a = k * 2 * math.pi / 9 + rng:NextNumber(-0.2, 0.2)
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				local y = top - capH * rng:NextNumber(0.25, 1.15)
				local p = rockEdge(planes, Vector3.new(r.cf.X, y, r.cf.Z), dir)
				if p then
					local s = rng:NextNumber(0.8, 1.3)
					lump(U.MossCap, rng, CFrame.lookAt(p - dir * 0.3, p + dir) * CFrame.Angles(rad(-45), 0, 0), 1.6 * s, 0.4, 1.2 * s, mossTone)
				end
			end
			-- hanging moss from the cap's rim on the gate side and the front
			for k = 1, 5 do
				local ang = rad(k * 72 + rng:NextNumber(-15, 15))
				local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
				local from = Vector3.new(r.cf.X, top - capH - 0.2, r.cf.Z)
				local t = math.huge
				for _, pl in ipairs(capPlanes) do
					local nd = pl.n:Dot(dir)
					if nd > 1e-6 then
						t = math.min(t, (pl.d - pl.n:Dot(from)) / nd)
					end
				end
				if t < 40 then
					SH.hangingMoss(U.Hang, rng, from + dir * (t - 0.25), rng:NextNumber(1.2, 2.6))
				end
			end
		end
	end
	-- the frame sticks and root beams: dark rotten logs, rope where they meet
	for _, r in ipairs(rows(kit)) do
		if r.parent == "" and r.collide and (r.name == "Part" or r.name == "RootBeam") then
			local a, b = ends(r)
			local rr = thick(r) / 2 + 0.02
			logAB(U.Logs, a, b, rr, r.color, 0.9)
			logCracks(U.Wood, rng, a, b, rr, 2)
			lashing(U.Rope, a:Lerp(b, 0.85), (b - a).Unit, rr, 3, rng)
			if r.name == "RootBeam" then
				SH.hangingMoss(U.Hang, rng, a:Lerp(b, 0.5) - Vector3.new(0, rr, 0), 1.4)
				SH.mossPatch(U.Moss, rng, CFrame.fromMatrix(a:Lerp(b, 0.4) + Vector3.new(0, rr * 0.9, 0), (b - a).Unit, UP), 2.4, rr * 1.5, 0.6)
			end
		end
	end
	local ps = rows(kit, "PriceSign")[1]
	exactRow(m, ps)
	signFrame(U, rng, ps, rgb(46, 34, 28))
	for _, name in ipairs({ "Caps", "Stems" }) do
		for _, r in ipairs(rows(kit, name)) do
			exactRow(m, r)
		end
	end
	SH.mushrooms(U.Mush, rng, Vector3.new(14.2, 0.15, -6.8), 3, 0.55)
	-- 2 small clusters of glowing mushrooms at the rocks' feet (round 2)
	for _, gp in ipairs({ Vector3.new(-12.5, 0, -6.2), Vector3.new(9.5, 0, -6.6) }) do
		for k = 0, 2 do
			local p = gp + Vector3.new(k * 0.55 - 0.5, 0, (k % 2) * 0.4)
			local h = 0.45 + 0.18 * k
			table.insert(U.Mush, frustumN(5, 0.09, 0.07, 0, h, CFrame.new(p), { rgb(230, 225, 205) }))
			table.insert(U.Glow, frustumN(6, 0.3, 0.06, h - 0.04, h + 0.22, CFrame.new(p), { rgb(191, 245, 240) }))
		end
	end
	mud(U, rng, Vector3.new(0, 0, -3.2), 7.5, 2.0)

	-- THE BARRICADE under today's invisible Barrier
	local barrier = barrierOf(m, kit)
	H.setBevelSelf(true)
	local D = { Wood = {}, Rope = {}, Bone = {}, Iron = {}, Glow = {} }
	local branches = {}
	for _, r in ipairs(rows(kit)) do
		if r.parent ~= "Barrier" then
			continue
		end
		if r.name == "Backing" then
			table.insert(D.Wood, piece("Part", r.size, r.cf, r.color))
		elseif r.name == "ThornRoot" then
			local a, b = ends(r)
			local rr = thick(r) / 2 + 0.02
			logAB(D.Wood, a, b, rr, r.color, 0.85)
			table.insert(branches, { a = a, b = b, r = rr })
		elseif r.name == "Thorn" then
			-- a small bone: a shaft and 2 knobs
			local a, b = ends(r)
			local d = (b - a).Unit
			table.insert(D.Bone, frustumN(6, 0.13, 0.11, 0.15, (b - a).Magnitude - 0.15, H.frameY(a, d), { BONE, scaled(BONE, 0.92) }))
			for _, e in ipairs({ a + d * 0.18, b - d * 0.18 }) do
				lump(D.Bone, rng, CFrame.new(e), 0.2, 0.16, 0.2, function(n: Vector3): Color3
					return if n.Y > 0.3 then BONE else scaled(BONE, 0.88)
				end)
			end
		elseif r.name == "Bud" then
			exactRow(barrier, r)
			table.insert(D.Iron, frustumN(8, r.size.X * 0.62, r.size.X * 0.62, -0.08, 0.08, H.frameY(r.cf.Position + Vector3.new(0, 0, 0.1), -Vector3.zAxis) * CFrame.Angles(0, rad(22.5), 0), { IRON, IRON_LIGHT }))
		end
	end
	-- rope where 2 branches cross (closest points under 1.2 apart)
	for i = 1, #branches do
		for j = i + 1, #branches do
			local p, q = branches[i], branches[j]
			local d1, d2 = p.b - p.a, q.b - q.a
			local r0 = p.a - q.a
			local a, e, f = d1:Dot(d1), d2:Dot(d2), d2:Dot(r0)
			local c, bb = d1:Dot(r0), d1:Dot(d2)
			local den = a * e - bb * bb
			if den > 1e-6 then
				local s = math.clamp((bb * f - c * e) / den, 0, 1)
				local t = math.clamp((bb * s + f) / e, 0, 1)
				local x1, x2 = p.a + d1 * s, q.a + d2 * t
				if (x1 - x2).Magnitude < 1.2 and s > 0.05 and s < 0.95 then
					lashing(D.Rope, (x1 + x2) / 2, d1.Unit, (p.r + q.r) / 2, 2, rng)
				end
			end
		end
	end
	under(barrier, "BarricadeWood", D.Wood)
	under(barrier, "BarricadeRope", D.Rope)
	under(barrier, "BarricadeBones", D.Bone)
	under(barrier, "BarricadeIron", D.Iron)

	TB.finishTB(m, "swamp_rock_gate", U, "Rock", { Glow = { material = Enum.Material.Neon, shadow = false } })
	setPrimary(m, barrier)
	for _, r in ipairs(rows(kit)) do
		if r.collide and r.parent == "" and r.name ~= "Barrier" and r.name ~= "PriceSign" then
			collider(m, r)
		end
	end
	return m
end

---------------------------------------------------------------------
-- 04 SKULL PALISADE (kit MapAssets.Gates.Gate_Swamp_4 -> Zones.Swamp.Swamp_4.Gate, attr SubZoneId; 49 parts)
---------------------------------------------------------------------
-- From the plains / tundra palisade: today's 8 trunks as 2 crooked rotten planks each (different heights, pointed
-- tops) with dark gaps, iron bands with rivets across each wall at 2 heights, rope, moss and mud at the feet; today's 3
-- lintels as rotten timbers with cracks, iron straps and rope; today's 3 stubs as broken logs with splinters; today's
-- 2 roots as slanted support beams with rope and iron foot plates; today's PriceSign kept exactly in a rotten frame;
-- the 2 lanterns (cores + lights kept) in iron frames on today's brackets; today's 4 Neon shelf mushrooms kept with a
-- dark gill underside. THE DOOR (under today's Barrier, the PrimaryPart, colliding): today's 6 planks as crooked
-- boards, today's 2 bands as iron bands with rivets, the skull (round 2): the new 04 skull, the swamp_skull_knocker
-- MapProp nested at x 1.9 (today's door skull is that kit x 1.9: its sockets, Neon eyes, nose, teeth line and ring bars
-- land exactly where today's were), with its iron frame and ring; today's 4 Neon rune crosses kept exactly. Round 2
-- also: the wall planks in 2 different widths per trunk, with grain lines.
function SG.swamp_skull_gate(): Model
	local kit = "Gate_Swamp_4"
	local m = Instance.new("Model")
	m.Name = "swamp_skull_gate"
	local rng = Random.new(20261034)
	H.setBevelSelf(true)
	local U: any = { Planks = {}, Wood = {}, Iron = {}, Rope = {}, Moss = {}, Hang = {}, Mud = {}, Mush = {} }
	-- the trunks: 2 crooked planks each (round 2: different widths, 45 / 55 %) with pointed tops and grain lines (their
	-- own random stream r2, so the rest of the gate is drawn exactly as before)
	local r2 = Random.new(20261044)
	for _, r in ipairs(rows(kit, "Trunk")) do
		local s, cf = r.size, r.cf
		local split = r2:NextNumber(0.42, 0.58)
		for k, sx in ipairs({ -1, 1 }) do
			local frac = if k == 1 then split else 1 - split
			local w = s.X * frac - 0.08
			local x0 = if k == 1 then -s.X / 2 + s.X * frac / 2 else s.X / 2 - s.X * frac / 2
			local h = s.Y - (if k == 1 then 0 else rng:NextNumber(0.8, 2.2))
			local c = tone(rng, r.color)
			local pcf = cf * CFrame.new(x0, -s.Y / 2 + h / 2, 0) * CFrame.Angles(0, 0, rad(rng:NextNumber(-1.5, 1.5)))
			table.insert(U.Planks, chamfered(Vector3.new(w, h, s.Z), pcf, c, { "vertical" }, 0.18))
			-- 2 grain lines down the plank's front
			for _, gx in ipairs({ -w * 0.22, w * 0.18 }) do
				local g0 = r2:NextNumber(0.5, 3)
				table.insert(U.Wood, piece("Part", Vector3.new(0.09, h - g0 - 1.2, 0.06), pcf * CFrame.new(gx, -g0 / 2 - 0.4, -s.Z / 2 - 0.02), scaled(c, 0.72)))
			end
			local tip = pcf * CFrame.new(0, h / 2, 0)
			table.insert(U.Planks, chamfered(Vector3.new(w, 1.4, s.Z), tip * CFrame.new(0, 0.7, 0), scaled(c, 1.05), { "topSides" }, w / 2 - 0.06))
			for _, y in ipairs({ 5.5, 19.0 }) do
				if y < (pcf * CFrame.new(0, h / 2, 0)).Y - 1 then
					table.insert(U.Iron, piece("Part", Vector3.new(w + 0.12, 0.55, 0.1), CFrame.new((pcf * CFrame.new(0, y - pcf.Y, 0)).X, y, cf.Z - s.Z / 2 - 0.05), IRON))
					H.rivet(U.Iron, Vector3.new((pcf * CFrame.new(0, y - pcf.Y, 0)).X, y, cf.Z - s.Z / 2 - 0.12), 0.15)
				end
			end
			logCracks(U.Wood, rng, (pcf * CFrame.new(0, -h / 2, 0)).Position, (pcf * CFrame.new(0, h / 2, 0)).Position, s.Z / 2, 1)
		end
		SH.mossPatch(U.Moss, rng, CFrame.new(cf.X, 0.15, cf.Z - s.Z / 2 - 0.5), 2.6, 1.0, 0.6)
	end
	for _, sx in ipairs({ -1, 1 }) do
		mud(U, rng, Vector3.new(sx * 21.8, 0, -3.8), 8.5, 1.6)
	end
	-- the lintels, stubs and support roots
	for _, r in ipairs(rows(kit, "Lintel")) do
		table.insert(U.Wood, H.timber(r.size, r.cf, tone(rng, r.color), 0.2))
		local a, b = ends(r)
		logCracks(U.Wood, rng, a, b, r.size.Z / 2, 3)
		for _, t in ipairs({ 0.15, 0.85 }) do
			local p = a:Lerp(b, t)
			table.insert(U.Iron, piece("Part", Vector3.new(0.5, r.size.Y + 0.12, r.size.Z + 0.12), CFrame.new(p) * (r.cf - r.cf.Position), IRON))
		end
		SH.hangingMoss(U.Hang, rng, a:Lerp(b, rng:NextNumber(0.3, 0.7)) - Vector3.new(0, r.size.Y / 2, r.size.Z / 2 - 0.3), rng:NextNumber(1, 2))
	end
	for _, r in ipairs(rows(kit, "Stub")) do
		local a, b = ends(r)
		logAB(U.Wood, a, b, math.min(r.size.X, r.size.Z) / 2, r.color, 0.92)
		TB.splinters(U.Wood, rng, b, (b - a).Unit, 0.6, scaled(r.color, 1.15))
		SH.mossPatch(U.Moss, rng, CFrame.new(b), 1.6, 1.6, 0.5)
	end
	for _, r in ipairs(rows(kit, "Root")) do
		local a, b = ends(r)
		local rr = thick(r) / 2 + 0.02
		logAB(U.Wood, a, b, rr, r.color, 0.9)
		lashing(U.Rope, a:Lerp(b, 0.85), (b - a).Unit, rr, 3, rng)
		table.insert(U.Iron, piece("Part", Vector3.new(1.6, 0.15, 1.6), CFrame.new(a.X, 0.08, a.Z), IRON))
	end
	local ps = rows(kit, "PriceSign")[1]
	exactRow(m, ps)
	signFrame(U, rng, ps, rgb(62, 46, 36))
	local brackets = {}
	for _, r in ipairs(rows(kit, "Part")) do
		if r.parent == "" and r.color:ToHex() == "373a41" then
			table.insert(brackets, r)
		end
	end
	for _, lr in ipairs(rows(kit, "Lantern")) do
		local top = lanternFrame(U, m, lr, nil)
		for _, br in ipairs(brackets) do
			if (br.cf.Position - lr.cf.Position).Magnitude < 2 then
				bracketArm(U, br, top, lr.cf.Position)
			end
		end
	end
	for _, r in ipairs(rows(kit, "ShelfMushroom")) do
		exactRow(m, r)
		table.insert(U.Mush, piece("Part", r.size * Vector3.new(0.85, 0.3, 0.85), r.cf * CFrame.new(0, -r.size.Y * 0.62, 0.05), rgb(86, 74, 60)))
	end

	-- THE DOOR under today's Barrier
	local barrier = barrierOf(m, kit)
	H.setBevelSelf(true)
	local D = { Boards = {}, Iron = {}, Bone = {}, Dark = {} }
	for _, r in ipairs(rows(kit, "Plank")) do
		doorBoards(D.Boards, rng, r, 3, scaled(r.color, 0.92), -1, true)
	end
	for _, r in ipairs(rows(kit)) do
		if r.parent ~= "Barrier" then
			continue
		end
		if r.name == "Part" and r.size.X > 20 then
			-- today's 2 bands: iron bands with rivets
			table.insert(D.Iron, piece("Part", r.size + Vector3.new(0, 0, 0.04), r.cf * CFrame.new(0, 0, -0.12), IRON))
			for x = -11, 11, 2.2 do
				H.rivet(D.Iron, (r.cf * CFrame.new(x, 0, -0.32)).Position, 0.16)
			end
		elseif r.name == "Cranium" then
			-- the emblem: the new 04 skull (swamp_skull_knocker, nested at x 1.9) with its sockets, eyes, nose, teeth
			-- line, iron frame and ring (today's Socket / Eye / nose / teeth / Ring rows, exactly where they were)
			nestSkull(barrier, r)
		elseif r.name == "Rune" then
			exactRow(barrier, r)
		end
	end
	under(barrier, "DoorBoards", D.Boards)
	under(barrier, "DoorIron", D.Iron)

	TB.finishTB(m, "swamp_skull_gate", U, "Planks", {})
	setPrimary(m, barrier)
	local trunkN = 0
	for _, r in ipairs(rows(kit)) do
		if r.collide and r.parent == "" and r.name ~= "Barrier" and r.name ~= "PriceSign" then
			local name = if r.name == "Lintel" and r.cf.Y > 23 then "CollisionLintelGame" else nil
			if r.name == "Trunk" then
				trunkN += 1
				name = "CollisionTrunkGame_" .. trunkN
			end
			collider(m, r, name)
		end
	end
	collider(m, GD.rowOf(GD.KitRows.Gate_Swamp_4[1]), "CollisionLintelKit", false)
	-- the kit and the test copy keep their own 8 trunks (up to 0.0005 off the game's), switched by Variant "Kit"
	local kitSet = { CanCollide_CollisionLintelGame = false, CanQuery_CollisionLintelGame = false, CanCollide_CollisionLintelKit = true, CanQuery_CollisionLintelKit = true }
	for i = 1, trunkN do
		kitSet["CanCollide_CollisionTrunkGame_" .. i] = false
		kitSet["CanQuery_CollisionTrunkGame_" .. i] = false
	end
	for i, t in ipairs(GD.KitRows.Gate_Swamp_4Trunks) do
		collider(m, GD.rowOf(t), "CollisionTrunkKit_" .. i, false)
		kitSet["CanCollide_CollisionTrunkKit_" .. i] = true
		kitSet["CanQuery_CollisionTrunkKit_" .. i] = true
	end
	variants(m, { Kit = kitSet })
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table; its install() builds them
---------------------------------------------------------------------
SG.BUILDERS = { swamp_vine_arch = true, swamp_tree_gate = true, swamp_rock_gate = true, swamp_skull_gate = true }
for id in pairs(SG.BUILDERS) do
	B2[id] = (SG :: any)[id]
	B2.BUILDERS[id] = true
end
SG.install = B2.install
SG.stats = B2.stats

return SG
