--[[
	PropsTundraGates (dev tool, Edit mode only) - the owner's "TUNDRA (SNOW BIOME) PROP IMPROVEMENT - Gates and entrances"
	(2026-10-22): the log torii arch (Tundra_1.EntryArch), the palisade gate (Tundra_2), the ice rock gate (Tundra_3) and
	the ice castle gate (Tundra_4), to the fountain / well quality in the tundra look (docs/prop_texture_guide.md sections
	A, E, E8), keeping each gate's place, size, collisions, scripts and prompts. Source of truth: tools/PropsTundraGates.luau.
	Inventory: docs/prop_inventory.md "Tundra gates".

	Owner: "do NOT start from zero for the first two gates": 01 and 02 reuse the PLAINS gates' builders (props batch 2
	entry_arch / gate_palisade in tools/PropsBatch2.luau: coursed stone piers, octagonal logs with iron straps and rivets,
	framed name / price boards, the plank double door) re-proportioned to the TUNDRA kits' parts, recoloured (frosted
	wood, blue-grey slate, dark blue steel, cold light) and given the snow / ice layer (soft caps, drifts, icicles).

	Gate contract (as the desert / jungle gates): the Barrier stays the PrimaryPart and collides, the door decor sits under
	it (model attribute BarrierDecorIsChildOfBarrier, kept from the copies), SubZoneId / ZoneId and the PriceSign /
	NameSign GUIs are kept by the sync (the GUIs move onto the new sign parts of the same name), ZoneService adds the
	GatePrompt on the Barrier at run time. Collision: every other part that collides today is an invisible "Collision"
	copy of it (DevTools.PropsTundraGatesData = the game copies' parts); the visible pieces never collide.

	It uses DevTools.PropsTundraBuildings (its snow / ice helpers and Agent A's facets) and registers its builders into
	the same PropsBatch2 table:
		local TG = require(game.ServerStorage.DevTools.PropsTundraGates:Clone())
		print(TG.install("tundra_log_arch"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "tundra_log_arch" } }), Sync.run({ only = { "tundra_log_arch" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local TB = require(ServerStorage.DevTools.PropsTundraBuildings:Clone()) :: any
local B2, H, M, TS = TB.B2, TB.H, TB.M, TB.TS
local piece, chamfered = H.piece, H.chamfered
local scaled, graded = H.scaled, H.graded
local frustumN = M.frustumN
local facetPiece, facetIcicle, log, snowTone, lump = TB.facetPiece, TB.facetIcicle, TB.log, TB.snowTone, TB.lump
local GD = require(ServerStorage.DevTools.PropsTundraGatesData:Clone()) :: any
local GS = require(ServerStorage.DevTools.PropsTundraGatesSolids:Clone()) :: any -- Agent A's E8 facets as convex solids

local TG = {}

local rgb = Color3.fromRGB
local rad = math.rad

-- the tundra gate palette (guide E1 / the owner's tundra gate list)
local SLATE = rgb(118, 128, 150) -- #768096 bases (blue-grey slate, today's colour)
local SLATE_DARK = rgb(78, 86, 110) -- #4E566E
local STEEL = rgb(58, 72, 98) -- #3A4862 dark blue steel (iron bands, straps, cages)
local STEEL_LIGHT = rgb(96, 112, 140) -- rivet heads, worn edges
local RIME = rgb(230, 238, 246) -- #E6EEF6 frost on the edges
local ICE_PALE = rgb(214, 236, 255) -- #D6ECFF
local ICE_GLASS = rgb(191, 233, 245) -- #BFE9F5
TG.COLORS = { SLATE = SLATE, SLATE_DARK = SLATE_DARK, STEEL = STEEL, RIME = RIME }

-- frosted wood: today's colour a little darker and desaturated (owner: "darker, slightly desaturated brown")
local function frosted(c: Color3): Color3
	local g = (c.R + c.G + c.B) / 3
	return Color3.new((c.R + (g - c.R) * 0.2) * 0.88, (c.G + (g - c.G) * 0.2) * 0.88, (c.B + (g - c.B) * 0.2) * 0.88)
end
TG.frosted = frosted

local function rowsNamed(kit: string, name: string?): { any }
	local out = {}
	for _, r in ipairs(GD.rows(kit)) do
		if name == nil or r.name == name then
			table.insert(out, r)
		end
	end
	return out
end
TG.rowsNamed = rowsNamed

-- a MeshPart with this MeshId and collision fidelity to clone (the kits / test row / zones / templates)
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

-- the colliding rows of `kit` except `keep` (functional parts rebuilt exactly) as invisible "Collision" parts
local function collisionRows(m: Model, kit: string, keep: { [string]: boolean }): number
	local n = 0
	for _, r in ipairs(GD.rows(kit)) do
		if r.collide and not keep[r.name] and r.parent == "" then
			local p: BasePart
			if r.class == "MeshPart" then
				-- (CollisionFidelity cannot be set from a script: the source must already have today's fidelity)
				local src = meshSourceFid(r.meshId, r.fidelity)
				assert(src, `PropsTundraGates: no MeshPart with {r.meshId} ({r.fidelity}) to clone`)
				p = src:Clone()
				p:ClearAllChildren()
				for key in pairs(p:GetAttributes()) do
					p:SetAttribute(key, nil)
				end
				for _, tag in ipairs(p:GetTags()) do
					p:RemoveTag(tag)
				end
				(p :: MeshPart).TextureID = ""
				pcall(function()
					(p :: any).CollisionFidelity = (Enum.CollisionFidelity :: any)[r.fidelity]
				end)
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
TG.collisionRows = collisionRows

-- an exact copy of a row (a functional part: Barrier, PriceSign, NameSign, Lantern, Ember), colour / material optional
local function exactRow(parent: Instance, r: any, color: Color3?, material: Enum.Material?): BasePart
	local p = Instance.new(r.class) :: BasePart
	if r.shape ~= "" and p:IsA("Part") then
		p.Shape = (Enum.PartType :: any)[r.shape]
	end
	p.Name = r.name
	p.Size = r.size
	p.CFrame = r.cf
	p.Color = color or r.color
	p.Material = material or (Enum.Material :: any)[r.material]
	p.Transparency = r.transparency
	p.Anchored = true
	p.CanCollide = r.collide
	p.CanQuery = r.query
	p.CanTouch = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
TG.exactRow = exactRow

-- a steel strap (h tall, 0.1 thick) round the box x0..x1 / z0..z1 at height y, rivets front and back (the plains
-- band() in dark blue steel)
local function steelBand(list: { BasePart }, x0: number, x1: number, z0: number, z1: number, y: number, h: number)
	local t = 0.1
	table.insert(list, piece("Part", Vector3.new(x1 - x0 + 2 * t, h, t), CFrame.new((x0 + x1) / 2, y, z0 - t / 2), STEEL))
	table.insert(list, piece("Part", Vector3.new(x1 - x0 + 2 * t, h, t), CFrame.new((x0 + x1) / 2, y, z1 + t / 2), STEEL))
	table.insert(list, piece("Part", Vector3.new(t, h, z1 - z0), CFrame.new(x0 - t / 2, y, (z0 + z1) / 2), STEEL))
	table.insert(list, piece("Part", Vector3.new(t, h, z1 - z0), CFrame.new(x1 + t / 2, y, (z0 + z1) / 2), STEEL))
	local n = math.max(2, math.floor((x1 - x0) / 0.8))
	for i = 0, n - 1 do
		local x = x0 + 0.25 + i * (x1 - x0 - 0.5) / (n - 1)
		for _, z in ipairs({ z0 - t, z1 + t }) do
			table.insert(list, piece("Part", Vector3.new(0.14, 0.14, 0.14), CFrame.new(x, y, z) * CFrame.Angles(rad(45), rad(45), 0), STEEL_LIGHT))
		end
	end
end
TG.steelBand = steelBand

-- a steel ring (n-sided, apothem r, w wide) round the axis u at p
local function steelRing(list: { BasePart }, p: Vector3, u: Vector3, r: number, w: number)
	table.insert(list, frustumN(10, r, r, -w / 2, w / 2, H.frameY(p, u), { STEEL, scaled(STEEL, 1.15) }))
end
TG.steelRing = steelRing

-- frost rime: a thin strip on a top edge from a to b (0.07 thick, w wide), broken in 2-3 runs
local function rime(list: { BasePart }, rng: Random, a: Vector3, b: Vector3, w: number)
	local runs = rng:NextInteger(2, 3)
	for k = 0, runs - 1 do
		local t0 = k / runs + rng:NextNumber(0.02, 0.08)
		local t1 = (k + 1) / runs - rng:NextNumber(0.04, 0.12)
		local p0, p1 = a:Lerp(b, t0), a:Lerp(b, t1)
		table.insert(list, piece("Part", Vector3.new(w, 0.07, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), RIME))
	end
end
TG.rime = rime

-- a soft snow cap (Agent A's cap / cap_drip, normalized 1 x 1 x 1) on a top: bottom centre p, size s, yaw
local function cap(U: any, p: Vector3, s: Vector3, yaw: number?, drip: boolean?)
	facetPiece(U, if drip then TS.tundra_snow__cap_drip else TS.tundra_snow__cap, CFrame.new(p) * CFrame.Angles(0, yaw or 0, 0), s, "Snow", "Snow")
end
TG.cap = cap

-- thick soft snow on a round log along X (Agent A's tundra_snow__log_cap: 3 mounds 0.7-0.85 high, a rim bulging past
-- the log's sides, drips over the front; origin on the log axis, a 12-stud segment at scale 1 = a 2.4 log): one segment
-- per centre x, scale = the log diameter / 2.4, turned 180 every other segment (owner: "thick, soft, irregular edge")
local function logSnow(U: any, rng: Random, xs: { number }, y: number, z: number, diameter: number)
	local k = diameter / 2.4
	for i, x in ipairs(xs) do
		facetPiece(U, GS.tundra_snow__log_cap, CFrame.new(x, y, z) * CFrame.Angles(0, (if i % 2 == 0 then math.pi else 0) + rng:NextNumber(-0.02, 0.02), 0), Vector3.one * k, "Snow", "Snow")
	end
end
TG.logSnow = logSnow

-- a small domed cap on a post / log top (centre p = the top, r = its half width)
local function domeCap(U: any, rng: Random, p: Vector3, r: number)
	cap(U, p - Vector3.new(0, 0.15, 0), Vector3.new(r * 2 + 0.45, 0.7, r * 2 + 0.45), rng:NextNumber(0, 6.28))
	lump(U.Snow, rng, CFrame.new(p + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), r * 0.75, 0.32, r * 0.7, snowTone, 0.1)
end
TG.domeCap = domeCap

---------------------------------------------------------------------
-- 01 LOG TORII ARCH (kit MapAssets.Gates.EntryArch_Tundra -> Zones.Tundra.Tundra_1.EntryArch, attr ZoneId; 47.5 x 27.7 x
-- 9.3; 37 parts)
---------------------------------------------------------------------
-- The log torii arch, derived from the plains entry arch (props batch 2 entry_arch): its coursed stone piers (ringCourse,
-- 2 courses, on today's 8 x 3 x 7 bases, blue-grey slate) under soft snow caps; today's paired round posts as 8-sided
-- frosted logs (outer 18 tall, inner 23) with steel collars at their feet and the plains' riveted straps round each
-- pair (dark blue steel, today's 2 binding heights), frost rime and snow caps on the post tops; today's 2 round beams as
-- frosted logs with cut ends, steel rings where they cross the posts, soft snow caps with drips along their tops and
-- groups of small icicles under them; 2 struts between the beams behind the sign; today's NameSign kept exactly (icy
-- blue, its NameGuiFront / Back move onto it) in a frosted frame (rails with rime, ice corner crystals, a snow cap, small
-- icicles); the 2 hanging ice lanterns: today's Neon cores and PointLights kept, in a steel cage with frosted glass
-- panes, a pyramid cap with snow, a hook ring on the beam and a 3-link chain; the ice crystals at the feet (Agent A's
-- shards on today's 4 Crystal colliders); soft drifts against the bases. Colliders: today's posts, beams, bindings,
-- bases, sign frame and the 4 Crystal MeshParts (invisible), the NameSign itself.
-- Parts: Ice, Icicles, Logs, Steel, Stone, Snow, Wood, NameSign, Lantern x2 (+ PointLight), Collision x19.
function TG.tundra_log_arch(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_log_arch"
	local rng = Random.new(20261601)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Logs = {}, Wood = {}, Steel = {}, Snow = {}, Ice = {}, Icicles = {} }
	local kit = "EntryArch"
	local Ht = 27.7
	-- the piers (plains ringCourse on today's bases) and their snow caps, drifts against them
	for _, b in ipairs(rowsNamed(kit, "Base")) do
		local p, s = b.cf.Position, b.size
		for k = 0, 1 do
			H.ringCourse(U.Stone, rng, { cx = p.X, cz = p.Z, w = s.X, d = s.Z, y = k * 1.5, h = 1.5, t = 1.6, odd = k % 2 == 1, color = SLATE, H = Ht })
		end
		cap(U, Vector3.new(p.X, s.Y - 0.12, p.Z), Vector3.new(s.X + 0.5, 0.75, s.Z + 0.5), rng:NextNumber(-0.05, 0.05), true)
		local side = math.sign(p.X)
		facetPiece(U, TS.tundra_snow__drift, CFrame.new(p.X - side * 0.6, -0.05, -4.1) * CFrame.Angles(0, 0, 0), Vector3.new(6.0, 1.3, 1.2), "Snow", "Snow")
		facetPiece(U, TS.tundra_snow__drift, CFrame.new(p.X, -0.05, 4.1) * CFrame.Angles(0, math.pi, 0), Vector3.new(5.0, 1.1, 1.2), "Snow", "Snow")
	end
	-- the paired posts: frosted 8-sided logs from the pier top, steel collars at their feet, rime and a snow cap on top
	for _, r in ipairs(rowsNamed(kit, "Post")) do
		local p = r.cf.Position
		local len = r.size.X
		local top = p.Y + len / 2
		local rr = r.size.Y / 2
		log(U.Logs, U.Wood, Vector3.new(p.X, 2.9, p.Z), Vector3.new(p.X, top, p.Z), rr, frosted(r.color), { "b" })
		steelRing(U.Steel, Vector3.new(p.X, 3.3, p.Z), Vector3.yAxis, rr + 0.08, 0.5)
		domeCap(U, rng, Vector3.new(p.X, top, p.Z), rr)
		rime(U.Snow, rng, Vector3.new(p.X, 4, p.Z - rr - 0.02), Vector3.new(p.X, top - 1, p.Z - rr - 0.02), 0.12)
	end
	-- the straps round each pair (today's Binding places), dark blue steel with rivets
	for _, r in ipairs(rowsNamed(kit, "Binding")) do
		local p, s = r.cf.Position, r.size
		steelBand(U.Steel, p.X - s.X / 2 + 0.25, p.X + s.X / 2 - 0.25, -1.4, 1.4, p.Y, 0.8)
	end
	-- the 2 beams: frosted logs with cut ends, steel rings over the posts, snow caps with drips, icicles under them
	local beams = rowsNamed(kit, "Beam")
	table.sort(beams, function(a, b)
		return a.cf.Position.Y < b.cf.Position.Y
	end)
	for i, r in ipairs(beams) do
		local p, len, rr = r.cf.Position, r.size.X, r.size.Y / 2
		log(U.Logs, U.Wood, Vector3.new(p.X - len / 2, p.Y, p.Z), Vector3.new(p.X + len / 2, p.Y, p.Z), rr, frosted(r.color), { "a", "b" })
		for _, x in ipairs({ -14.6, 14.6 }) do
			steelRing(U.Steel, Vector3.new(x + math.sign(x) * 1.7, p.Y, p.Z), Vector3.xAxis, rr + 0.07, 0.45)
		end
		-- Agent A's log snow segments (guide E8: main beam x -12.5 / 0 / 12.5, top beam -10.5 / 0 / 10.5 at 0.83)
		logSnow(U, rng, if i == 2 then { -10.5, 0, 10.5 } else { -12.5, 0, 12.5 }, p.Y, p.Z, r.size.Y)
		-- icicles: small groups under the beam (none in front of the lanterns), the longest near the posts
		local xs = if i == 1 then { 2.0, 4.3, 6.4, 11.9, 12.8 } else { 6.6, 9.8, 12.2 }
		for _, x0 in ipairs(xs) do
			for _, sx in ipairs({ -1, 1 }) do
				local x = sx * (x0 + rng:NextNumber(-0.2, 0.2))
				local near = math.clamp((math.abs(x) - 2) / 11, 0, 1)
				facetIcicle(U, "Icicles", Vector3.new(x, p.Y - rr + 0.15, p.Z + rng:NextNumber(-0.4, 0.4)), 0.25 + 0.45 * near * rng:NextNumber(0.6, 1), 0.55, rng:NextNumber(0, 6.28))
			end
		end
	end
	-- 2 struts between the beams, behind the sign frame
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Wood, H.timber(Vector3.new(1.1, 5.2, 1.1), CFrame.new(sx * 8.4, 22.15, 0.4), frosted(rgb(92, 66, 54))))
	end
	-- the name sign: today's NameSign exactly (icy blue), a frosted frame round it with rime, ice corners, snow, icicles
	local ns = rowsNamed(kit, "NameSign")[1]
	exactRow(m, ns, rgb(76, 140, 210))
	local sf = rowsNamed(kit, "SignFrame")[1]
	local fp, fs = sf.cf.Position, sf.size
	local FW = frosted(sf.color)
	for _, sy in ipairs({ -1, 1 }) do
		table.insert(U.Wood, H.timber(Vector3.new(fs.X, 0.6, fs.Z + 0.1), CFrame.new(fp.X, fp.Y + sy * (fs.Y / 2 - 0.3), fp.Z), FW))
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Wood, H.timber(Vector3.new(0.6, fs.Y - 1.2, fs.Z + 0.1), CFrame.new(fp.X + sx * (fs.X / 2 - 0.3), fp.Y, fp.Z), FW))
		for _, sy in ipairs({ -1, 1 }) do
			local c = Vector3.new(fp.X + sx * (fs.X / 2 - 0.3), fp.Y + sy * (fs.Y / 2 - 0.3), fp.Z - fs.Z / 2 - 0.12)
			table.insert(U.Ice, frustumN(4, 0.36, 0.05, -0.12, 0.3, H.frameY(c, -Vector3.zAxis) * CFrame.Angles(0, rad(45), 0), { ICE_GLASS, ICE_PALE }))
		end
	end
	rime(U.Snow, rng, Vector3.new(fp.X - fs.X / 2 + 0.4, fp.Y + fs.Y / 2 + 0.035, fp.Z - fs.Z / 2), Vector3.new(fp.X + fs.X / 2 - 0.4, fp.Y + fs.Y / 2 + 0.035, fp.Z - fs.Z / 2), 0.2)
	for _, x in ipairs({ -5.2, -1.4, 2.6, 5.8 }) do
		facetIcicle(U, "Icicles", Vector3.new(x, fp.Y - fs.Y / 2 + 0.1, fp.Z - 0.1), rng:NextNumber(0.15, 0.3), 0.45, rng:NextNumber(0, 6.28))
	end
	-- the hanging ice lanterns: today's Neon core + PointLight, a steel cage, frosted panes, a capped roof, chain, ring
	for _, lr in ipairs(rowsNamed(kit, "Lantern")) do
		local core = exactRow(m, lr, rgb(170, 228, 255))
		local light = Instance.new("PointLight")
		light.Brightness, light.Range, light.Color, light.Shadows = 0.8, 14, rgb(96, 190, 255), false
		light.Parent = core
		local c, s = lr.cf.Position, lr.size
		local y0, y1 = c.Y - s.Y / 2 - 0.1, c.Y + s.Y / 2 + 0.05
		table.insert(U.Steel, chamfered(Vector3.new(1.9, 0.18, 1.9), CFrame.new(c.X, y0, c.Z), STEEL, { "topFrontBack", "topSides" }, 0.05))
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				table.insert(U.Steel, piece("Part", Vector3.new(0.14, y1 - y0, 0.14), CFrame.new(c.X + sx * 0.82, (y0 + y1) / 2, c.Z + sz * 0.82), STEEL))
			end
		end
		for _, f in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
			local sz = if f[1] == 0 then Vector3.new(1.5, y1 - y0 - 0.2, 0.06) else Vector3.new(0.06, y1 - y0 - 0.2, 1.5)
			table.insert(U.Ice, piece("Part", sz, CFrame.new(c.X + f[1] * 0.8, (y0 + y1) / 2, c.Z + f[2] * 0.8), ICE_GLASS))
		end
		table.insert(U.Steel, frustumN(4, 1.15, 0.12, y1, y1 + 0.75, CFrame.new(c.X, 0, c.Z) * CFrame.Angles(0, rad(45), 0), { STEEL, scaled(STEEL, 1.15) }))
		cap(U, Vector3.new(c.X, y1 + 0.35, c.Z), Vector3.new(0.9, 0.35, 0.9), rng:NextNumber(0, 6.28))
		-- chain: 3 links up to a ring round the lower beam
		local beamY = beams[1].cf.Position.Y - beams[1].size.Y / 2
		local n = 3
		for k = 0, n - 1 do
			local y = y1 + 0.85 + (k + 0.5) * (beamY - y1 - 0.85) / n
			table.insert(U.Steel, piece("Part", Vector3.new(0.1, (beamY - y1 - 0.85) / n + 0.1, 0.32), CFrame.new(c.X, y, c.Z) * CFrame.Angles(0, if k % 2 == 0 then 0 else rad(90), 0), STEEL_LIGHT))
		end
		steelRing(U.Steel, Vector3.new(c.X, beams[1].cf.Position.Y, c.Z), Vector3.xAxis, beams[1].size.Y / 2 + 0.06, 0.35)
		facetIcicle(U, "Icicles", Vector3.new(c.X + 0.4, y0 - 0.05, c.Z - 0.3), 0.14, 0.35, rng:NextNumber(0, 6.28))
		facetIcicle(U, "Icicles", Vector3.new(c.X - 0.35, y0 - 0.05, c.Z + 0.25), 0.1, 0.3, rng:NextNumber(0, 6.28))
	end
	-- the ice crystals at the feet: Agent A's shards on today's 4 Crystal colliders (their tall ones taller)
	for _, cr in ipairs(rowsNamed(kit, "Crystal")) do
		local p, s = cr.cf.Position, cr.size
		local h = p.Y + s.Y / 2 - 0.5
		local k = s.X / 1.7
		facetPiece(U, TS.tundra_ice__shards, CFrame.new(p.X, 0, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Vector3.new(k, h / 2.17, k), "Ice", "Ice")
	end

	TB.finishTB(m, "tundra_log_arch", U, "Stone", { Ice = TB.GLASS_OPTS, Icicles = TB.ICICLE_OPTS })
	collisionRows(m, kit, { NameSign = true })
	return m
end

---------------------------------------------------------------------
-- shared gate helpers (the contract)
---------------------------------------------------------------------
-- door pieces merged into a union UNDER the Barrier (GateController hides the Barrier and every descendant when the
-- gate opens): never colliding, not queryable
local function underBarrier(barrier: BasePart, name: string, list: { BasePart }, opts: any?)
	if #list == 0 then
		return
	end
	local u = H.merge(barrier :: any, name, list, opts or {})
	u.CanCollide = false
	u.CanQuery = false
	u.CanTouch = true
	u.Parent = barrier
end
TG.underBarrier = underBarrier

-- the Barrier becomes the PrimaryPart (pivot at the origin)
local function setPrimary(m: Model, barrier: BasePart)
	m.PrimaryPart = barrier
	barrier.PivotOffset = barrier.CFrame:Inverse()
end
TG.setPrimary = setPrimary

-- a soft drift fitted to a (colliding) wedge row: Agent A's normalized drift on the wedge's bottom centre, its size
local function wedgeDrift(U: any, key: string, r: any, shade: boolean?)
	facetPiece(U, if shade then TS.tundra_snow__drift_shade else TS.tundra_snow__drift, r.cf * CFrame.new(0, -r.size.Y / 2 - 0.05, 0), r.size + Vector3.new(0, 0.05, 0), key, key)
end
TG.wedgeDrift = wedgeDrift

local COLD_FLAME = rgb(200, 240, 255) -- #C8F0FF pale cyan-white (owner: cold light instead of warm yellow)
TG.COLD_FLAME = COLD_FLAME

---------------------------------------------------------------------
-- 02 PALISADE GATE (kit MapAssets.Gates.Gate_Tundra_2 -> Zones.Tundra.Tundra_2.Gate, attr SubZoneId; 47 x 27.2 x 17.9;
-- 60 parts; it is the plains palisade kit recoloured with snow)
---------------------------------------------------------------------
-- The palisade gate, derived from the plains gate_palisade (props batch 2): its 2 towers of 4 octagonal logs on coursed
-- slate bases (ringCourse) with the riveted straps (dark blue steel) at today's 2 binding heights, frosted logs (today's
-- 2 browns, darker and desaturated) with rime and domed snow caps on today's colliding snow discs, soft caps on the bases;
-- the lintel (chamfered frosted timber, steel bands, rivets, pegs) under Agent A's lintel snow (drips, icicles that end
-- above the door); the sign posts and a frosted frame round today's PriceSign (kept exactly, icy blue, its GUIs move onto
-- it), 2 tie beams, a king post and a ridge beam; the plains shingle roof in blue-grey tiles (on today's SignRoof ridge
-- at z -0.4) under Agent A's thick roof snow on both slopes, icicles under the eaves; the 2 wall torches: the plains
-- torch (riveted plate, the bar leaning "/" from the log up to the cup, a steel cup with a rim) with today's Ember +
-- FirePoint kept exactly, the flame cold pale cyan-white; soft drifts on today's 4 Drift wedges. THE DOOR (all under
-- today's Barrier 24 x 16 x 1.4, PrimaryPart, colliding, a dark core): 10 frosted planks a leaf with gaps, top and
-- bottom rails and today's 2 diagonal braces, today's 2 bands as blue steel bands with rivets (both faces), strap hinges,
-- today's yellow handles as gold grips on plates (both faces), the 2 snow banks as soft drifts against it.
-- Colliders: today's logs, snow discs, bases, bindings, lintel, sign posts, sign frame, roof wedges, torch sticks and
-- drifts (invisible), the Barrier and the PriceSign themselves.
-- Parts: Ice, Icicles, Logs, Roof, Snow, Steel, Stone, Wood, PriceSign, Ember x2 (+ FirePoint), Barrier (+ DoorPlanks,
-- DoorWood, DoorSteel, DoorGold, DoorSnow), Collision x35.
function TG.tundra_palisade_gate(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_palisade_gate"
	local rng = Random.new(20261602)
	H.setBevelSelf(true)
	local U: any = { Stone = {}, Logs = {}, Wood = {}, Steel = {}, Snow = {}, Roof = {}, Ice = {}, Icicles = {} }
	local kit = "Gate2"
	local Ht = 27.2
	local DARK = frosted(rgb(92, 66, 54))
	-- the towers: coursed slate bases, snow caps, the logs (frosted, today's places / heights / colours) with domed caps
	for _, r in ipairs(rowsNamed(kit, "TowerBase")) do
		local p, sz = r.cf.Position, r.size
		for k = 0, 1 do
			H.ringCourse(U.Stone, rng, { cx = p.X, cz = p.Z, w = sz.X, d = sz.Z, y = k * 1.5, h = 1.5, t = 1.9, odd = k % 2 == 1, color = SLATE, H = Ht })
		end
		cap(U, Vector3.new(p.X, sz.Y - 0.1, p.Z), Vector3.new(sz.X + 0.5, 0.75, sz.Z + 0.5), rng:NextNumber(-0.04, 0.04), true)
	end
	local prev = nil
	for _, r in ipairs(rowsNamed(kit, "Log")) do
		local p, len = r.cf.Position, r.size.X
		local top = p.Y + len / 2
		local ti = H.toneIndex(rng, prev)
		prev = ti
		table.insert(U.Logs, H.octagon(2.6, top - 2.9, CFrame.new(p.X, (2.9 + top) / 2, p.Z), graded(frosted(r.color), top / 2, Ht, H.TONES[ti] * 1.08)))
		domeCap(U, rng, Vector3.new(p.X, top + 0.1, p.Z), 1.3)
		rime(U.Snow, rng, Vector3.new(p.X, 4, p.Z - 1.24), Vector3.new(p.X, top - 1.2, p.Z - 1.24), 0.12)
	end
	for _, r in ipairs(rowsNamed(kit, "Binding")) do
		local p = r.cf.Position
		local side = math.sign(p.X)
		steelBand(U.Steel, math.min(11.9 * side, 22.0 * side), math.max(11.9 * side, 22.0 * side), -1.3, 1.3, p.Y, 1.0)
	end
	-- the lintel (plains timber, bands, pegs) under Agent A's lintel snow; icicles at its roots (tips above y 16.2)
	local lt = rowsNamed(kit, "Lintel")[1]
	table.insert(U.Wood, H.timber(lt.size, lt.cf, graded(DARK, 17.3, Ht)))
	for _, side in ipairs({ -1, 1 }) do
		table.insert(U.Steel, piece("Part", Vector3.new(0.5, 2.74, 3.34), CFrame.new(side * 11.3, 17.3, 0), STEEL))
		for _, z in ipairs({ -1.67, 1.67 }) do
			for _, y in ipairs({ 16.7, 17.9 }) do
				table.insert(U.Steel, piece("Part", Vector3.new(0.14, 0.14, 0.14), CFrame.new(side * 11.3, y, z) * CFrame.Angles(rad(45), rad(45), 0), STEEL_LIGHT))
			end
		end
	end
	facetPiece(U, GS.tundra_gate2__lintel_snow, CFrame.identity, nil, "Snow", "Snow")
	for _, root in ipairs(GS.tundra_gate2__lintel_snow.icicleRoots) do
		facetIcicle(U, "Icicles", root + Vector3.new(0, 0.08, 0), math.min(0.55, (root.Y - 16.3) / 3), 0.55, rng:NextNumber(0, 6.28))
	end
	-- the sign: today's posts, a frosted frame round today's PriceSign (exact, icy blue), tie beams, king post, ridge beam
	for _, r in ipairs(rowsNamed(kit, "SignPost")) do
		table.insert(U.Wood, H.timber(r.size - Vector3.new(0.6, 0, 0.2), r.cf, graded(DARK, 20.4, Ht, 1.04)))
	end
	local ps = rowsNamed(kit, "PriceSign")[1]
	exactRow(m, ps, rgb(76, 140, 210))
	local sp, ss = ps.cf.Position, ps.size
	for _, sy in ipairs({ -1, 1 }) do
		table.insert(U.Wood, H.timber(Vector3.new(ss.X + 1.2, 0.5, 0.7), CFrame.new(sp.X, sp.Y + sy * (ss.Y / 2 + 0.25), sp.Z + 0.1), graded(DARK, sp.Y, Ht, 0.95)))
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Wood, H.timber(Vector3.new(0.6, ss.Y, 0.7), CFrame.new(sp.X + sx * (ss.X / 2 + 0.3), sp.Y, sp.Z + 0.1), graded(DARK, sp.Y, Ht)))
		for _, sy in ipairs({ -1, 1 }) do
			local c = Vector3.new(sp.X + sx * (ss.X / 2 + 0.3), sp.Y + sy * (ss.Y / 2 + 0.25), sp.Z - 0.3)
			table.insert(U.Ice, frustumN(4, 0.34, 0.05, -0.1, 0.28, H.frameY(c, -Vector3.zAxis) * CFrame.Angles(0, rad(45), 0), { ICE_GLASS, ICE_PALE }))
		end
	end
	rime(U.Snow, rng, Vector3.new(sp.X - ss.X / 2 - 0.4, sp.Y + ss.Y / 2 + 0.53, sp.Z - 0.22), Vector3.new(sp.X + ss.X / 2 + 0.4, sp.Y + ss.Y / 2 + 0.53, sp.Z - 0.22), 0.25)
	for _, side in ipairs({ -1, 1 }) do
		table.insert(U.Wood, H.timber(Vector3.new(0.7, 0.6, 7.0), CFrame.new(side * 13.45, 23.75, -0.4), graded(DARK, 24, Ht, 0.93)))
	end
	table.insert(U.Wood, H.timber(Vector3.new(0.6, 3.0, 0.6), CFrame.new(0, 23.8 + 1.5, -0.4), graded(DARK, 25, Ht)))
	table.insert(U.Wood, H.timber(Vector3.new(29.8, 0.5, 0.5), CFrame.new(0, 26.75, -0.4), graded(DARK, 26.7, Ht)))
	-- the roof: the plains shingles in blue-grey on today's SignRoof (ridge y 27.2 at z -0.4, eaves y 24.2), Agent A's
	-- thick snow on both slopes (built on a ridge at z 0: moved -0.4 with the roof), icicles under the eaves
	H.shingleRoof(U.Roof, U.Wood, rng, { x0 = -15.2, x1 = 15.2, zc = -0.4, e = 3.5, yE = 24.2, yR = 27.2, color = rgb(110, 124, 146), ridge = rgb(86, 98, 122), overhang = 0.3 })
	for _, f in ipairs({ CFrame.new(0, 0, -0.4), CFrame.new(0, 0, -0.4) * CFrame.Angles(0, math.pi, 0) }) do
		facetPiece(U, GS.tundra_gate2__roof_snow, f, nil, "Snow", "Snow")
		for _, root in ipairs(GS.tundra_gate2__roof_snow.icicleRoots) do
			facetIcicle(U, "Icicles", f * (root + Vector3.new(0, 0.08, 0)), rng:NextNumber(0.25, 0.5), 0.6, rng:NextNumber(0, 6.28))
		end
	end
	-- the 2 wall torches (plains torch, owner directive: the bar leans "/" up into the cup), today's Ember + FirePoint
	for _, er in ipairs(rowsNamed(kit, "Ember")) do
		local e = exactRow(m, er, COLD_FLAME, Enum.Material.Neon)
		e.CastShadow = false
		local fp = Instance.new("Attachment")
		fp.Name = "FirePoint"
		fp.CFrame = CFrame.new(0, 0.199999809, 0)
		fp.Parent = e
		local c = er.cf.Position
		local tx = c.X
		table.insert(U.Steel, piece("Part", Vector3.new(0.7, 1.0, 0.08), CFrame.new(tx, 10.6, -1.34), STEEL))
		for _, y in ipairs({ 10.25, 10.95 }) do
			table.insert(U.Steel, piece("Part", Vector3.new(0.14, 0.14, 0.14), CFrame.new(tx, y, -1.4) * CFrame.Angles(rad(45), rad(45), 0), STEEL_LIGHT))
		end
		local s0, s1 = Vector3.new(tx, 10.2, -1.45), Vector3.new(tx, c.Y - 0.5, c.Z + 0.02)
		table.insert(U.Wood, piece("Part", Vector3.new(0.4, (s1 - s0).Magnitude + 0.15, 0.4), CFrame.lookAt((s0 + s1) / 2, s1) * CFrame.Angles(rad(-90), 0, 0), DARK))
		steelRing(U.Steel, s0:Lerp(s1, 0.55), (s1 - s0).Unit, 0.24, 0.18)
		table.insert(U.Steel, frustumN(8, 0.36, 0.62, c.Y - 0.6, c.Y - 0.25, CFrame.new(tx, 0, c.Z), { STEEL, scaled(STEEL, 1.15) }))
		steelRing(U.Steel, Vector3.new(tx, c.Y - 0.25, c.Z), Vector3.yAxis, 0.63, 0.1)
	end
	-- soft drifts on today's 4 Drift wedges
	for _, r in ipairs(rowsNamed(kit, "Drift")) do
		wedgeDrift(U, "Snow", r, r.color:ToHex() == "cedef6")
	end

	TB.finishTB(m, "tundra_palisade_gate", U, "Logs", { Ice = TB.GLASS_OPTS, Icicles = TB.ICICLE_OPTS })
	-- THE DOOR: today's Barrier (a dark core, colliding) and everything under it
	H.setBevelSelf(true)
	local br = rowsNamed(kit, "Barrier")[1]
	local barrier = exactRow(m, br, rgb(58, 42, 34))
	local planks, dwood, dsteel, dgold = {}, {}, {}, {}
	local D: any = { Snow = {} }
	local pprev = nil
	for _, side in ipairs({ -1, 1 }) do
		local inner, outer = 0.06 * side, 12 * side
		local n = 10
		local w = (12 - 0.06 - 0.05 * (n - 1)) / n
		for i = 0, n - 1 do
			local x = inner + side * (w / 2 + i * (w + 0.05))
			local ti = H.toneIndex(rng, pprev)
			pprev = ti
			table.insert(planks, chamfered(Vector3.new(w, 15.95, 1.7), CFrame.new(x, 7.98, 0), graded(frosted(rgb(134, 92, 66)), 8, Ht, H.TONES[ti] * 1.08), { "vertical" }, 0.08))
		end
		local cx = 6.03 * side
		for _, y in ipairs({ 1.6, 14.4 }) do
			table.insert(dwood, H.timber(Vector3.new(11.2, 1.0, 0.35), CFrame.new(cx, y, -1.02), graded(DARK, y, Ht)))
		end
		for _, y in ipairs({ 5.4, 10.6 }) do
			table.insert(dsteel, piece("Part", Vector3.new(4.5, 0.5, 0.1), CFrame.new(outer - side * 2.25, y, -0.9), STEEL))
			table.insert(dsteel, piece("Part", Vector3.new(0.5, 0.9, 1.9), CFrame.new(outer - side * 0.1, y, 0), STEEL))
		end
		-- the gold grips on plates, both faces (today's yellow Handles)
		for _, zf in ipairs({ -1, 1 }) do
			table.insert(dgold, piece("Part", Vector3.new(0.9, 2.2, 0.08), CFrame.new(side * 1.6, 8, zf * 0.89), rgb(201, 154, 46)))
			table.insert(dgold, piece("Part", Vector3.new(0.3, 1.8, 0.3), CFrame.new(side * 1.6, 8, zf * 1.15), rgb(255, 201, 60)))
			for _, dy in ipairs({ -0.75, 0.75 }) do
				table.insert(dgold, piece("Part", Vector3.new(0.22, 0.22, 0.3), CFrame.new(side * 1.6, 8 + dy, zf * 1.0), rgb(255, 201, 60)))
			end
		end
	end
	-- today's 2 diagonal braces (front)
	for _, r in ipairs(rowsNamed(kit, "Brace")) do
		table.insert(dwood, H.timber(Vector3.new(r.size.X, r.size.Y, 0.4), r.cf * CFrame.new(0, 0, -1.07), graded(DARK, 8, Ht, 0.95)))
	end
	-- today's 2 bands (y 3 and 13) as blue steel bands with rivets, both faces
	for _, r in ipairs(rowsNamed(kit, "Band")) do
		local y = r.cf.Position.Y
		for _, zf in ipairs({ -1, 1 }) do
			table.insert(dsteel, piece("Part", Vector3.new(24.0, 0.9, 0.1), CFrame.new(0, y, zf * 0.9), rgb(52, 92, 150)))
			for k = 0, 23 do
				table.insert(dsteel, piece("Part", Vector3.new(0.13, 0.13, 0.13), CFrame.new(-11.5 + k, y, zf * 0.97) * CFrame.Angles(rad(45), rad(45), 0), STEEL_LIGHT))
			end
		end
	end
	-- the 2 snow banks against the door (soft drifts, under the Barrier like today's)
	for _, r in ipairs(rowsNamed(kit, "SnowBank")) do
		wedgeDrift(D, "Snow", r, r.color:ToHex() == "cedef6")
	end
	underBarrier(barrier, "DoorPlanks", planks)
	underBarrier(barrier, "DoorWood", dwood)
	underBarrier(barrier, "DoorSteel", dsteel)
	underBarrier(barrier, "DoorGold", dgold)
	underBarrier(barrier, "DoorSnow", D.Snow)
	H.setBevelSelf(false)
	setPrimary(m, barrier)
	collisionRows(m, kit, { Barrier = true, PriceSign = true })
	return m
end

---------------------------------------------------------------------
-- 03 ICE ROCK GATE (kit MapAssets.Gates.Gate_Tundra_3 -> Zones.Tundra.Tundra_3.Gate, attr SubZoneId; 77 x 39 x 22; 32 parts)
---------------------------------------------------------------------
-- The ice rock gate (guide E8, new model): Agent A's 2 faceted layered-blue ice-rock pillars and 2 side rocks with thick
-- snow caps on today's Pillar / Rock colliders (their Hull MeshParts kept invisible); today's 2 jambs as dark blue slate
-- pillars (coursed, chamfered, a capstone with snow and icicles); today's round beam as a thick frosted log with steel
-- rings and Agent A's log snow, single icicles under it; today's PriceSign kept exactly (icy blue, its GUIs move onto it)
-- in a frosted frame with ice corners, hung on 2 steel chains; slate stones and soft drifts at the feet (outside the
-- passage). THE DOOR (all under today's invisible colliding Barrier 24 x 16 x 2, PrimaryPart): today's 12 ice blocks
-- as bevelled translucent ice bricks (Glass T 0.25, today's 3 blues, a frosty joint wall behind them), an arch of 7
-- light ice voussoirs on their front with a keystone carrying a glowing cyan diamond, today's Neon Rune (the diamond
-- key) kept, today's top snow and snow bank as soft snow. The passage and the open behaviour are today's: the Barrier
-- is the only collider in the opening and everything of the door vanishes with it.
-- Colliders: today's 2 Pillar + 2 Rock MeshParts (Hull), 2 Jambs, Beam, SignFrame (invisible), the Barrier and the
-- PriceSign themselves. Parts: Ice, Icicles, Logs, Rock, Snow, Steel, Stone, Wood, PriceSign, Barrier (+ DoorIce,
-- DoorFrost, DoorArch, DoorGlow, DoorSnow), Collision x8.
function TG.tundra_ice_rock_gate(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_ice_rock_gate"
	local rng = Random.new(20261603)
	H.setBevelSelf(true)
	local U: any = { Rock = {}, Stone = {}, Logs = {}, Wood = {}, Steel = {}, Snow = {}, Ice = {}, Icicles = {} }
	local kit = "Gate3"
	local Ht = 39
	local ID = CFrame.identity
	-- Agent A's ice-rock pillars and side rocks (layered blues, snow caps)
	for _, name in ipairs({ "tundra_gate3__boulder_left", "tundra_gate3__boulder_right", "tundra_gate3__rock_left", "tundra_gate3__rock_right" }) do
		facetPiece(U, GS[name], ID, nil, "Ice", "Rock")
	end
	-- the 2 jambs: dark blue slate pillars in courses, a capstone with snow and icicles
	for _, r in ipairs(rowsNamed(kit, "Jamb")) do
		local p, sz = r.cf.Position, r.size
		local top = p.Y + sz.Y / 2
		local n = 10
		local h = (top - 0.8) / n
		for k = 0, n - 1 do
			H.ringCourse(U.Stone, rng, { cx = p.X, cz = p.Z, w = sz.X, d = sz.Z, y = k * h, h = h, t = 1.5, odd = k % 2 == 1, color = SLATE_DARK, H = Ht })
		end
		table.insert(U.Stone, chamfered(Vector3.new(sz.X + 0.6, 0.8, sz.Z + 0.6), CFrame.new(p.X, top - 0.4, p.Z), scaled(SLATE_DARK, 0.85), { "topFrontBack", "topSides" }, 0.18))
		cap(U, Vector3.new(p.X, top - 0.05, p.Z), Vector3.new(sz.X + 0.8, 0.7, sz.Z + 0.8), rng:NextNumber(-0.05, 0.05), true)
		for _, dx in ipairs({ -1.2, 0.3, 1.3 }) do
			facetIcicle(U, "Icicles", Vector3.new(p.X + dx, top - 0.75, p.Z - sz.Z / 2 - 0.25), rng:NextNumber(0.2, 0.45), 0.5, rng:NextNumber(0, 6.28))
		end
		-- slate stones and a soft drift at the foot (outside the passage)
		local side = math.sign(p.X)
		facetPiece(U, TS.tundra_snow__drift, CFrame.new(p.X + side * 0.4, -0.05, p.Z - sz.Z / 2 - 1.0), Vector3.new(4.2, 1.2, 2.0), "Snow", "Snow")
		for k = 1, 2 do
			lump(U.Stone, rng, CFrame.new(p.X + side * rng:NextNumber(1.8, 3.2), 0.2, p.Z - sz.Z / 2 - rng:NextNumber(0.6, 2.2)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.5, 0.8), 0.4, rng:NextNumber(0.4, 0.7), function(nv)
				return scaled(SLATE, if nv.Y > 0.5 then 1.05 else 0.85)
			end, 0.15)
		end
	end
	-- the beam: a thick frosted log, steel rings, Agent A's log snow (guide E8: x -11 / 0 / 11 at 0.92), icicles
	local bm = rowsNamed(kit, "Beam")[1]
	local bp, blen, brr = bm.cf.Position, bm.size.X, bm.size.Y / 2
	log(U.Logs, U.Wood, Vector3.new(bp.X - blen / 2, bp.Y, bp.Z), Vector3.new(bp.X + blen / 2, bp.Y, bp.Z), brr, frosted(bm.color), { "a", "b" })
	for _, x in ipairs({ -13.7, -5, 5, 13.7 }) do
		steelRing(U.Steel, Vector3.new(x, bp.Y, bp.Z), Vector3.xAxis, brr + 0.07, 0.4)
	end
	logSnow(U, rng, { -11, 0, 11 }, bp.Y, bp.Z, bm.size.Y)
	for _, x in ipairs({ -12.3, -8.6, -2.4, 2.8, 8.2, 11.6 }) do
		facetIcicle(U, "Icicles", Vector3.new(x + rng:NextNumber(-0.3, 0.3), bp.Y - brr + 0.15, bp.Z + rng:NextNumber(-0.3, 0.3)), rng:NextNumber(0.2, 0.42), 0.5, rng:NextNumber(0, 6.28))
	end
	-- the sign: today's PriceSign exactly (icy blue) in a frosted frame with ice corners, hung on 2 steel chains
	local ps = rowsNamed(kit, "PriceSign")[1]
	exactRow(m, ps, rgb(76, 140, 210))
	local sp, ss = ps.cf.Position, ps.size
	local DARK = frosted(rgb(92, 66, 54))
	for _, sy in ipairs({ -1, 1 }) do
		table.insert(U.Wood, H.timber(Vector3.new(ss.X + 1.2, 0.5, 0.6), CFrame.new(sp.X, sp.Y + sy * (ss.Y / 2 + 0.25), sp.Z + 0.3), graded(DARK, sp.Y, Ht, 0.95)))
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Wood, H.timber(Vector3.new(0.6, ss.Y, 0.6), CFrame.new(sp.X + sx * (ss.X / 2 + 0.3), sp.Y, sp.Z + 0.3), graded(DARK, sp.Y, Ht)))
		for _, sy in ipairs({ -1, 1 }) do
			local c = Vector3.new(sp.X + sx * (ss.X / 2 + 0.3), sp.Y + sy * (ss.Y / 2 + 0.25), sp.Z - 0.05)
			table.insert(U.Ice, frustumN(4, 0.34, 0.05, -0.1, 0.28, H.frameY(c, -Vector3.zAxis) * CFrame.Angles(0, rad(45), 0), { ICE_GLASS, ICE_PALE }))
		end
	end
	rime(U.Snow, rng, Vector3.new(sp.X - ss.X / 2 - 0.4, sp.Y + ss.Y / 2 + 0.53, sp.Z + 0.1), Vector3.new(sp.X + ss.X / 2 + 0.4, sp.Y + ss.Y / 2 + 0.53, sp.Z + 0.1), 0.25)
	local frameTop = sp.Y + ss.Y / 2 + 0.5
	for _, x in ipairs({ -5, 5 }) do
		local y0, y1 = frameTop, bp.Y - brr
		local n = 3
		for k = 0, n - 1 do
			local y = y0 + (k + 0.5) * (y1 - y0) / n
			table.insert(U.Steel, piece("Part", Vector3.new(0.1, (y1 - y0) / n + 0.12, 0.34), CFrame.new(x, y, -0.6) * CFrame.Angles(0, if k % 2 == 0 then 0 else rad(90), 0), STEEL_LIGHT))
		end
		steelRing(U.Steel, Vector3.new(x, bp.Y, bp.Z), Vector3.xAxis, brr + 0.06, 0.3)
	end

	TB.finishTB(m, "tundra_ice_rock_gate", U, "Rock", { Ice = TB.GLASS_OPTS, Icicles = TB.ICICLE_OPTS })
	-- THE DOOR: today's invisible Barrier and everything under it
	H.setBevelSelf(true)
	local br = rowsNamed(kit, "Barrier")[1]
	local barrier = exactRow(m, br)
	local iceB, frost, arch, glow = {}, {}, {}, {}
	local D: any = { Snow = {} }
	for _, r in ipairs(rowsNamed(kit, "IceBlock")) do
		local sz = r.size
		table.insert(iceB, chamfered(Vector3.new(sz.X - 0.14, sz.Y - 0.14, sz.Z), r.cf, r.color:Lerp(rgb(214, 236, 255), 0.08), { "frontFace", "topSides", "bottomSides" }, 0.32))
	end
	-- a frosty joint wall just behind the bricks (it shows in the 0.14 joints)
	table.insert(frost, piece("Part", Vector3.new(23.8, 15.8, 0.4), CFrame.new(0, 8, 0.75), rgb(206, 226, 246)))
	-- the arch: 7 light ice voussoirs on the bricks' front (springing y 10, crown 15.4), a keystone with a cyan diamond
	local cx, cyc, rIn, rOut = 0, 2.2, 11.0, 13.2
	local a0, a1 = math.asin((10 - cyc) / rIn), math.pi - math.asin((10 - cyc) / rIn)
	local n = 7
	for k = 0, n - 1 do
		local t0 = a0 + (a1 - a0) * k / n + 0.012
		local t1 = a0 + (a1 - a0) * (k + 1) / n - 0.012
		local tm = (t0 + t1) / 2
		local mid = Vector3.new(cx + math.cos(tm) * (rIn + rOut) / 2, cyc + math.sin(tm) * (rIn + rOut) / 2, -1.25)
		local len = (rIn + rOut) / 2 * (t1 - t0)
		local cf = CFrame.fromMatrix(mid, Vector3.new(-math.sin(tm), math.cos(tm), 0), Vector3.new(math.cos(tm), math.sin(tm), 0))
		if mid.Y + (rOut - rIn) / 2 < 16.05 then
			table.insert(arch, chamfered(Vector3.new(len, rOut - rIn, 0.6), cf, if k == 3 then rgb(170, 220, 245) else ICE_PALE, { "frontFace" }, 0.14))
		else
			-- (the crown voussoirs are cut to the door top, 16)
			table.insert(arch, chamfered(Vector3.new(len, math.max(0.6, 16 - (mid.Y - (rOut - rIn) / 2) - 0.1), 0.6), cf * CFrame.new(0, -((rOut - rIn) - math.max(0.6, 16 - (mid.Y - (rOut - rIn) / 2) - 0.1)) / 2, 0), if k == 3 then rgb(170, 220, 245) else ICE_PALE, { "frontFace" }, 0.14))
		end
	end
	local keyY = cyc + rIn + 0.6
	table.insert(glow, piece("Part", Vector3.new(0.9, 0.9, 0.3), CFrame.new(0, math.min(keyY, 15.1), -1.6) * CFrame.Angles(0, 0, rad(45)), rgb(96, 190, 255), { material = Enum.Material.Neon }))
	-- today's Neon Rune (the diamond key) kept exactly
	local rr = rowsNamed(kit, "Rune")[1]
	exactRow(barrier, rr)
	-- today's top snow and snow bank as soft snow (under the Barrier, as today)
	local ts = rowsNamed(kit, "TopSnow")[1]
	facetPiece(D, TS.tundra_snow__cap_drip, ts.cf * CFrame.new(0, -ts.size.Y / 2 - 0.05, 0), Vector3.new(ts.size.X, 0.7, ts.size.Z + 0.3), "Snow", "Snow")
	for _, r in ipairs(rowsNamed(kit, "SnowBank")) do
		wedgeDrift(D, "Snow", r, false)
	end
	underBarrier(barrier, "DoorIce", iceB, { material = Enum.Material.Glass, transparency = 0.25, shadow = false })
	underBarrier(barrier, "DoorFrost", frost)
	underBarrier(barrier, "DoorArch", arch, { material = Enum.Material.Glass, transparency = 0.15 })
	underBarrier(barrier, "DoorGlow", glow, { material = Enum.Material.Neon, shadow = false })
	underBarrier(barrier, "DoorSnow", D.Snow)
	H.setBevelSelf(false)
	setPrimary(m, barrier)
	collisionRows(m, kit, { Barrier = true, PriceSign = true })
	return m
end

---------------------------------------------------------------------
-- 04 ICE CASTLE GATE (kit MapAssets.Gates.Gate_Tundra_4 -> Zones.Tundra.Tundra_4.Gate, attr SubZoneId; 56 x 60.5 x 19; 38 parts)
---------------------------------------------------------------------
-- bevelled ice blocks on one face of a box: the face's plane (frame f: X along the face, Y up, -Z out), from u0..u1 and
-- y0..y1, courses of ch, blocks 1.3 .. 2 x ch long in running bond, 0.12 joints, 0.5 thick, today's colour in 3 tones
-- and the gradient (H the object's height)
local function iceFace(list: { BasePart }, rng: Random, f: CFrame, u0: number, u1: number, y0: number, y1: number, ch: number, color: Color3, Ht: number)
	local n = math.max(1, math.floor((y1 - y0) / ch + 0.5))
	local h = (y1 - y0) / n
	local prev = nil
	for row = 0, n - 1 do
		local yc = y0 + (row + 0.5) * h
		local x = u0 - (if row % 2 == 1 then rng:NextNumber(0.6, 1.0) * h else 0)
		while x < u1 - 0.05 do
			local len = rng:NextNumber(1.3, 2.0) * h
			local a, bb = math.max(x, u0), math.min(x + len, u1)
			if u1 - bb < 0.6 * h then
				bb = u1
			end
			if bb - a > 0.3 then
				local ti = H.toneIndex(rng, prev)
				prev = ti
				local j = ({ 0, 0.04, 0.07 })[rng:NextInteger(1, 3)]
				table.insert(list, chamfered(Vector3.new(bb - a - 0.12, h - 0.12, 0.5), f * CFrame.new((a + bb) / 2, yc, -0.25 - j), graded(color, yc, Ht, H.TONES[ti] * 1.06), { "frontFace" }, 0.16))
			end
			x = bb
		end
	end
end
TG.iceFace = iceFace

-- The ice castle gate (guide E8, new model): today's 2 towers as bevelled ice-block masonry (front and both sides, running
-- bond, joints over a deep blue core) with today's dark blue bands and caps (chamfered, studded), Agent A's faceted
-- crystal spires on the caps, snow caps and icicles; today's Neon slits kept in ice frames; the wall over the door in ice
-- blocks, today's cornice (chamfered, a row of dentils) and 4 merlons with snow caps, icicles under the cornice (today's
-- 5 + singles); today's 2 buttresses as bevelled ice pilasters with a base and a capital, snow on top; today's PriceSign
-- kept exactly in a frosted ice frame with corner gems; soft drifts on today's 2 Drift wedges. THE DOOR (all under today's
-- colliding Glass Barrier 24 x 16 x 3, T 0.35, PrimaryPart, kept exactly: the frosted-glass double door): lighter ice
-- frames (today's 3 Frames), the seam, today's 4 etched facets as frosted lines, frost in the corners, today's Neon
-- Emblem (the cyan gem) kept exactly in a faceted ice setting, a cold glow light under the Barrier (it goes out with it).
-- Colliders: today's towers, bands, caps, wall, cornice, crenels, buttresses, sign frame and drifts (invisible), the
-- Barrier and the PriceSign themselves. Parts: Ice, Icicles, IceBlocks, IceTrim, Snow, Stone, Slit x2, PriceSign, Barrier
-- (+ DoorFrame, DoorFrost, DoorGem, Emblem), Collision x18.
function TG.tundra_ice_castle_gate(): Model
	local m = Instance.new("Model")
	m.Name = "tundra_ice_castle_gate"
	local rng = Random.new(20261604)
	H.setBevelSelf(true)
	local U: any = { IceBlocks = {}, IceBlocks2 = {}, IceTrim = {}, Stone = {}, Snow = {}, Ice = {}, Icicles = {} }
	local kit = "Gate4"
	local Ht = 60
	local DEEP = rgb(40, 96, 170)
	-- the towers: a deep blue core, bevelled ice blocks on the front and both sides, today's band and cap
	for i, r in ipairs(rowsNamed(kit, "Tower")) do
		local p, sz = r.cf.Position, r.size
		local list = if i == 1 then U.IceBlocks else U.IceBlocks2
		table.insert(U.Stone, piece("Part", sz - Vector3.new(0.5, 0.2, 0.5), r.cf, DEEP))
		local x0, x1, z0, z1 = p.X - sz.X / 2, p.X + sz.X / 2, p.Z - sz.Z / 2, p.Z + sz.Z / 2
		local top = p.Y + sz.Y / 2
		local faces = {
			{ CFrame.new(p.X, 0, z0), -sz.X / 2, sz.X / 2 },
			{ CFrame.new(x0, 0, p.Z) * CFrame.Angles(0, rad(-90), 0), -sz.Z / 2, sz.Z / 2 },
			{ CFrame.new(x1, 0, p.Z) * CFrame.Angles(0, rad(90), 0), -sz.Z / 2, sz.Z / 2 },
		}
		for _, fc in ipairs(faces) do
			iceFace(list, rng, fc[1], fc[2], fc[3], 0, 29, 2.42, r.color, Ht)
			iceFace(list, rng, fc[1], fc[2], fc[3], 31, top, 2.25, r.color, Ht)
		end
	end
	for _, r in ipairs(rowsNamed(kit, "TowerBand")) do
		table.insert(U.IceTrim, chamfered(r.size, r.cf, r.color, { "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }, 0.22))
		for k = 0, 6 do
			local x = r.cf.Position.X - r.size.X / 2 + 1.2 + k * (r.size.X - 2.4) / 6
			table.insert(U.IceTrim, piece("Part", Vector3.new(0.35, 0.35, 0.35), CFrame.new(x, r.cf.Position.Y, r.cf.Position.Z - r.size.Z / 2 - 0.1) * CFrame.Angles(0, 0, rad(45)), rgb(150, 210, 245)))
		end
	end
	for _, r in ipairs(rowsNamed(kit, "TowerCap")) do
		local p, sz = r.cf.Position, r.size
		table.insert(U.IceTrim, chamfered(sz, r.cf, r.color, { "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.35))
		cap(U, Vector3.new(p.X, p.Y + sz.Y / 2 - 0.1, p.Z), Vector3.new(sz.X + 0.6, 0.9, sz.Z + 0.6), rng:NextNumber(-0.04, 0.04), true)
		for k = 0, 4 do
			local x = p.X - sz.X / 2 + 1.5 + k * (sz.X - 3) / 4 + rng:NextNumber(-0.4, 0.4)
			facetIcicle(U, "Icicles", Vector3.new(x, p.Y - sz.Y / 2 + 0.12, p.Z - sz.Z / 2 + 0.3), rng:NextNumber(0.3, 0.7), 0.7, rng:NextNumber(0, 6.28))
		end
	end
	-- Agent A's crystal spires on the caps (today's places and turns)
	for _, r in ipairs(rowsNamed(kit, "Spire")) do
		local p = r.cf.Position
		local _, yaw = r.cf:ToEulerAnglesYXZ()
		facetPiece(U, GS.tundra_gate4__spire, CFrame.new(p.X, 43.0, p.Z) * CFrame.Angles(0, yaw, 0), nil, "Ice", "IceTrim")
	end
	-- today's Neon slits, in light ice frames
	for _, r in ipairs(rowsNamed(kit, "Slit")) do
		exactRow(m, r)
		local p, sz = r.cf.Position, r.size
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(U.IceTrim, chamfered(Vector3.new(0.35, sz.Y + 0.7, 0.4), CFrame.new(p.X + sx * (sz.X / 2 + 0.17), p.Y, p.Z - 0.12), rgb(190, 228, 248), { "frontFace" }, 0.08))
		end
		for _, sy in ipairs({ -1, 1 }) do
			table.insert(U.IceTrim, chamfered(Vector3.new(sz.X + 1.0, 0.35, 0.4), CFrame.new(p.X, p.Y + sy * (sz.Y / 2 + 0.17), p.Z - 0.12), rgb(190, 228, 248), { "frontFace" }, 0.08))
		end
	end
	-- the wall over the door: a deep core, ice blocks on its front, today's cornice with dentils, 4 merlons with snow
	local wl = rowsNamed(kit, "Wall")[1]
	local wp, ws = wl.cf.Position, wl.size
	table.insert(U.Stone, piece("Part", ws - Vector3.new(0.5, 0.2, 0.5), wl.cf, DEEP))
	iceFace(U.IceBlocks, rng, CFrame.new(wp.X, 0, wp.Z - ws.Z / 2), -ws.X / 2, ws.X / 2, wp.Y - ws.Y / 2, wp.Y + ws.Y / 2, 2.5, wl.color, Ht)
	local co = rowsNamed(kit, "Cornice")[1]
	local cp, cs = co.cf.Position, co.size
	table.insert(U.IceTrim, chamfered(cs, co.cf, co.color, { "topFrontBack", "bottomFrontBack", "topSides", "bottomSides" }, 0.3))
	for k = 0, 12 do
		local x = cp.X - cs.X / 2 + 1.2 + k * (cs.X - 2.4) / 12
		table.insert(U.IceTrim, piece("Part", Vector3.new(0.7, 0.5, 0.4), CFrame.new(x, cp.Y - cs.Y / 2 - 0.25, cp.Z - cs.Z / 2 + 0.45), scaled(co.color, 0.9)))
	end
	for _, r in ipairs(rowsNamed(kit, "Crenel")) do
		local p, sz = r.cf.Position, r.size
		table.insert(U.IceBlocks, chamfered(sz - Vector3.new(0.1, 0, 0.1), r.cf, graded(r.color, p.Y, Ht, H.TONES[rng:NextInteger(1, 3)]), { "vertical", "topFrontBack", "topSides" }, 0.25))
		cap(U, Vector3.new(p.X, p.Y + sz.Y / 2 - 0.1, p.Z), Vector3.new(sz.X + 0.4, 0.6, sz.Z + 0.4), rng:NextNumber(-0.05, 0.05), true)
	end
	cap(U, Vector3.new(cp.X, cp.Y + cs.Y / 2 - 0.12, cp.Z), Vector3.new(cs.X - 0.3, 0.45, cs.Z + 0.3), 0, true)
	-- icicles under the cornice front: today's 5 (x, length) + singles between them
	for _, r in ipairs(rowsNamed(kit, "Icicle")) do
		local p = r.cf.Position
		facetIcicle(U, "Icicles", Vector3.new(p.X, cp.Y - cs.Y / 2 - 0.4, p.Z), r.size.Y / 3, 1.0, rng:NextNumber(0, 6.28))
	end
	for _, x in ipairs({ -12.4, -8.1, -4.0, 0, 4.1, 8.2, 12.4 }) do
		facetIcicle(U, "Icicles", Vector3.new(x + rng:NextNumber(-0.3, 0.3), cp.Y - cs.Y / 2 - 0.4, -2.45 + rng:NextNumber(-0.2, 0.2)), rng:NextNumber(0.25, 0.5), 0.6, rng:NextNumber(0, 6.28))
	end
	-- the pilasters (today's buttresses): bevelled ice in 4 drums, a base and a capital, snow on top
	for _, r in ipairs(rowsNamed(kit, "Buttress")) do
		local p, sz = r.cf.Position, r.size
		local y0, y1 = p.Y - sz.Y / 2, p.Y + sz.Y / 2
		table.insert(U.IceTrim, chamfered(Vector3.new(sz.X + 0.6, 1.2, sz.Z + 0.6), CFrame.new(p.X, y0 + 0.6, p.Z), scaled(r.color, 0.85), { "topFrontBack", "topSides" }, 0.3))
		local n = 4
		local hh = (sz.Y - 2.4) / n
		for k = 0, n - 1 do
			local yc = y0 + 1.2 + (k + 0.5) * hh
			table.insert(U.IceBlocks2, chamfered(Vector3.new(sz.X - 0.06, hh - 0.1, sz.Z - 0.06), CFrame.new(p.X, yc, p.Z), graded(r.color, yc, Ht, H.TONES[(k % 3) + 1]), { "vertical", "topFrontBack", "topSides" }, 0.22))
		end
		table.insert(U.IceTrim, chamfered(Vector3.new(sz.X + 0.6, 1.2, sz.Z + 0.6), CFrame.new(p.X, y1 - 0.6, p.Z), scaled(r.color, 0.85), { "bottomFrontBack", "bottomSides", "topFrontBack" }, 0.3))
		cap(U, Vector3.new(p.X, y1 - 0.08, p.Z), Vector3.new(sz.X + 0.8, 0.6, sz.Z + 0.8), rng:NextNumber(-0.05, 0.05), true)
	end
	-- the sign: today's PriceSign exactly, a frosted ice frame with corner gems (today's light ice SignFrame colour)
	local ps = rowsNamed(kit, "PriceSign")[1]
	exactRow(m, ps)
	local sf = rowsNamed(kit, "SignFrame")[1]
	local fp, fs = sf.cf.Position, sf.size
	for _, sy in ipairs({ -1, 1 }) do
		table.insert(U.IceTrim, chamfered(Vector3.new(fs.X, 0.6, 0.7), CFrame.new(fp.X, fp.Y + sy * (fs.Y / 2 - 0.3), fp.Z - 0.4), sf.color, { "frontFace" }, 0.15))
	end
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.IceTrim, chamfered(Vector3.new(0.6, fs.Y - 1.2, 0.7), CFrame.new(fp.X + sx * (fs.X / 2 - 0.3), fp.Y, fp.Z - 0.4), sf.color, { "frontFace" }, 0.15))
		for _, sy in ipairs({ -1, 1 }) do
			local c = Vector3.new(fp.X + sx * (fs.X / 2 - 0.3), fp.Y + sy * (fs.Y / 2 - 0.3), fp.Z - 0.78)
			table.insert(U.Ice, frustumN(4, 0.36, 0.05, -0.1, 0.3, H.frameY(c, -Vector3.zAxis) * CFrame.Angles(0, rad(45), 0), { ICE_GLASS, rgb(150, 210, 245) }))
		end
	end
	-- soft drifts on today's 2 Drift wedges
	for _, r in ipairs(rowsNamed(kit, "Drift")) do
		wedgeDrift(U, "Snow", r, false)
	end

	TB.finishTB(m, "tundra_ice_castle_gate", U, "IceTrim", { Ice = TB.GLASS_OPTS, Icicles = TB.ICICLE_OPTS })
	-- THE DOOR: today's Glass Barrier exactly, and under it the frames, frost lines, the gem and its glow
	H.setBevelSelf(true)
	local br = rowsNamed(kit, "Barrier")[1]
	local barrier = exactRow(m, br)
	local frames, frost, gem = {}, {}, {}
	for _, r in ipairs(rowsNamed(kit, "Frame")) do
		table.insert(frames, chamfered(r.size, r.cf, rgb(110, 176, 236), { "frontFace" }, 0.2))
	end
	for _, r in ipairs(rowsNamed(kit, "Seam")) do
		table.insert(frames, chamfered(r.size + Vector3.new(0.2, 0, 0), r.cf, rgb(110, 176, 236), { "frontFace" }, 0.08))
	end
	for _, r in ipairs(rowsNamed(kit, "Facet")) do
		table.insert(frost, piece("Part", Vector3.new(0.18, r.size.Y, r.size.Z + 0.06), r.cf, rgb(225, 240, 252)))
	end
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		for _, zf in ipairs({ -1, 1 }) do
			local corner = Vector3.new(c[1] * 11.0, 8 + c[2] * 7.5, 1 + zf * 1.53)
			H.triangleParts(frost, corner, corner - Vector3.new(c[1] * 1.6, 0, 0), corner - Vector3.new(0, c[2] * 1.4, 0), 0.04, CFrame.identity, rgb(240, 247, 255))
		end
	end
	local em = rowsNamed(kit, "Emblem")[1]
	local ep = em.cf.Position
	exactRow(barrier, em)
	for _, zf in ipairs({ -1, 1 }) do
		table.insert(gem, frustumN(8, 1.75, 1.45, 0, 0.25, H.frameY(Vector3.new(ep.X, ep.Y, ep.Z + zf * 1.6), Vector3.new(0, 0, zf)), { rgb(200, 232, 250), rgb(160, 210, 240) }))
	end
	local glow = Instance.new("PointLight")
	glow.Name = "GemGlow"
	glow.Brightness, glow.Range, glow.Color, glow.Shadows = 0.6, 10, rgb(150, 220, 255), false
	underBarrier(barrier, "DoorFrame", frames, { material = Enum.Material.Glass, transparency = 0.1 })
	underBarrier(barrier, "DoorFrost", frost, { shadow = false })
	underBarrier(barrier, "DoorGem", gem, { material = Enum.Material.Glass, transparency = 0.2, shadow = false })
	local emb = barrier:FindFirstChild("Emblem")
	if emb then
		glow.Parent = emb
	end
	H.setBevelSelf(false)
	setPrimary(m, barrier)
	collisionRows(m, kit, { Barrier = true, PriceSign = true })
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table as the earlier props; its install() builds them
---------------------------------------------------------------------
TG.BUILDERS = { tundra_log_arch = true, tundra_palisade_gate = true, tundra_ice_rock_gate = true, tundra_ice_castle_gate = true }
for id in pairs(TG.BUILDERS) do
	B2[id] = (TG :: any)[id]
	B2.BUILDERS[id] = true
end
TG.install = B2.install
TG.stats = B2.stats

return TG
