--[[
	PropsRound7 (dev tool, Edit mode only) - owner prompt "ROUND 7: BOSS ROOM TEXTURE FIX + JUNGLE MOSS + ICE CASTLE +
	SWAMP EXTERIORS/INTERIOR + DESERT PYRAMID BRICKS" (docs/Round7_Textures_And_Exteriors/PROMPT_ROUND7.txt).
	Source of truth: tools/PropsRound7.luau (= ServerStorage.DevTools.PropsRound7).

	Usage (execute_luau, Edit):
		local R7 = require(game.ServerStorage.DevTools.PropsRound7:Clone())
		print(R7.mossTemplates())     -- P2: jungle_moss_patch_small / _medium / _large (+ Variant "Wall")
		print(R7.mossPlates())        -- P2: the list of today's flat moss plates (names, counts)
		print(R7.placeMoss())         -- P2: each plate -> the best-fitting patch (raised, never on a glowing pad)
		print(R7.caveBoulder(), R7.placeCaveBoulder()) -- P3 item 5: tundra_cave_boulder, nested in the cave landmark
		print(R7.caveGaps())          -- P3 item 5 (owner correction): the mouth as before, gap rocks in the side holes
		print(R7.castleBricks({ dry = true }), R7.castleBricks()) -- P3 items 1 / 2 / 4: ice castle bricks (texture only)
		print(R7.swampCliffWall(), R7.swampRottenTimber(), R7.swampPuddle(), R7.swampCliffRock()) -- P4 templates
		print(R7.swampExterior())       -- P4 placements: cliff panels, timbers (GiantRoots hidden), gate dressing
		print(R7.swampTextures({ dry = true }), R7.swampTextures()) -- P5 swamp wall / floor textures (texture only)
		then Sync.run({ only = { ids } }) and BuildAssetPreview tag / build "Jungle".
]]
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local R7 = {}

local rgb = Color3.fromRGB

local R6M = nil
local function r6(): any
	if not R6M then
		R6M = require(ServerStorage.DevTools.PropsRound6:Clone())
	end
	return R6M
end
local STM = nil
local function st(): any
	if not STM then
		STM = require(ServerStorage.DevTools.PropsSwampTrees:Clone())
	end
	return STM
end

local function folder(): Folder
	return ServerStorage:FindFirstChild("MapProps") :: Folder
end

-- every part of a model: anchored, no collision / query / touch, no shadow
local function decorOnly(m: Instance)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = false, false, false, false
		end
	end
end
R7.decorOnly = decorOnly

-- an invisible PrimaryPart at the origin (the sync needs one; the pivot stays on the surface point)
local function pivotPart(m: Model, cf: CFrame?): BasePart
	local p = Instance.new("Part")
	p.Name = "PivotPart"
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf or CFrame.identity
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Parent = m
	m.PrimaryPart = p
	return p
end
R7.pivotPart = pivotPart

---------------------------------------------------------------------
-- PART 2: JUNGLE MOSS PATCHES
---------------------------------------------------------------------
-- A patch lies in its local XZ plane (Y = the surface normal, origin on the surface, local X = its long axis): 2-4
-- thin faceted pads (flattened 18-plane blobs, thicker in the middle) at slightly different heights, lifted 0.14 off
-- the surface, an irregular rounded outline; light moss spots on top, leaf tufts and small ferns at the rim. The wall
-- look (Variant "Wall") shows a few short hanging strands along local -Z (placed so that -Z points down the wall).
local MOSS = { base = rgb(46, 107, 46), mid = rgb(76, 154, 60), light = rgb(126, 217, 87), dark = rgb(38, 88, 38) } -- #2E6B2E #4C9A3C #7ED957
R7.MOSS = MOSS
R7.MOSS_IDS = { "jungle_moss_patch_small", "jungle_moss_patch_medium", "jungle_moss_patch_large" }
R7.MOSS_SIZE = { jungle_moss_patch_small = { 5.5, 4.2 }, jungle_moss_patch_medium = { 8.5, 6.0 }, jungle_moss_patch_large = { 12.0, 8.0 } }
local LIFT = 0.14

local function mossPatch(id: string, L: number, W: number, nPads: number, seed: number): string
	local lib = r6().lib()
	local H = lib.H
	local ST = st()
	local rng = Random.new(seed)
	local m = Instance.new("Model")
	m.Name = id
	pivotPart(m)
	H.setBevelSelf(true)
	local U: any = { Pads = {}, Spots = {}, Tufts = {}, Strands = {} }
	local function padTone(k: number): (Vector3) -> Color3
		return function(n: Vector3): Color3
			if n.Y > 0.55 then
				return H.scaled(MOSS.mid, k * 1.12)
			elseif n.Y > -0.2 then
				return H.scaled(MOSS.base, k)
			end
			return MOSS.dark
		end
	end
	-- the pads: a main one and 1-3 lobes overlapping its rim
	local pads = { { 0, 0, L * 0.36, W * 0.38, 0.16, 0 } }
	for i = 2, nPads do
		local a = (i - 2) * 2 * math.pi / (nPads - 1) + rng:NextNumber(-0.5, 0.5)
		table.insert(pads, { math.cos(a) * L * 0.22, math.sin(a) * W * 0.22, L * rng:NextNumber(0.2, 0.26), W * rng:NextNumber(0.22, 0.28), rng:NextNumber(0.11, 0.15), 0.02 * (i - 1) })
	end
	for i, p in ipairs(pads) do
		local f = CFrame.new(p[1], LIFT + p[6], p[2]) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
		ST.blob(U.Pads, rng, f, p[3], p[5], p[4], padTone(({ 1.0, 1.06, 0.94, 1.1 })[i]), 0)
	end
	-- light spots on top of the pads
	for _ = 1, math.floor(2 + L / 4) do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0, 0.75)
		local x, z = math.cos(a) * r * L * 0.32, math.sin(a) * r * W * 0.32
		ST.blob(U.Spots, rng, CFrame.new(x, LIFT + 0.2, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.4, 0.75), 0.08, rng:NextNumber(0.3, 0.55), function(n: Vector3): Color3
			return if n.Y > 0.5 then MOSS.light else H.scaled(MOSS.light, 0.85)
		end, 0)
	end
	-- leaf tufts (thin wedge blades) and small ferns round the rim
	local nTufts = math.floor(3 + L / 3.5)
	for t = 1, nTufts do
		local a = t * 2 * math.pi / nTufts + rng:NextNumber(-0.3, 0.3)
		local base = Vector3.new(math.cos(a) * L * 0.4, LIFT, math.sin(a) * W * 0.4)
		if t % 4 == 0 then
			ST.fern(U.Tufts, rng, base, 3, rng:NextNumber(0.45, 0.6))
		else
			for k = 1, 3 do
				local h = rng:NextNumber(0.22, 0.32)
				local blade = Instance.new("WedgePart")
				blade.Size = Vector3.new(0.05, h, 0.16)
				blade.CFrame = CFrame.new(base) * CFrame.Angles(0, k * 2.1 + rng:NextNumber(-0.3, 0.3), 0) * CFrame.new(0, 0, 0.06) * CFrame.Angles(math.rad(rng:NextNumber(14, 30)), 0, 0) * CFrame.new(0, h / 2, 0)
				blade.Color = H.scaled(({ MOSS.mid, MOSS.light, MOSS.base })[k], rng:NextNumber(0.92, 1.05))
				blade.Anchored = true
				table.insert(U.Tufts, blade)
			end
		end
	end
	-- the wall look: short strands hanging from the lower rim (local -Z), built along -Y and turned onto -Z
	local nStr = math.floor(2 + L / 5)
	for s = 1, nStr do
		local x = (s - 0.5) / nStr * L * 0.7 - L * 0.35 + rng:NextNumber(-0.3, 0.3)
		local top = Vector3.new(x, LIFT + 0.08, -W * 0.36)
		local list = {}
		ST.mossStrand(list, rng, Vector3.zero, rng:NextNumber(0.7, 1.5), if s % 2 == 0 then MOSS.mid else MOSS.base)
		for _, p in ipairs(list) do
			p.CFrame = CFrame.new(top) * CFrame.Angles(math.rad(90), 0, 0) * p.CFrame
			table.insert(U.Strands, p)
		end
	end
	H.merge(m, "Pads", U.Pads, { shadow = false })
	task.wait()
	H.merge(m, "Spots", U.Spots, { shadow = false })
	H.merge(m, "Tufts", U.Tufts, { shadow = false })
	H.merge(m, "Strands", U.Strands, { shadow = false, transparency = 1 })
	H.setBevelSelf(false)
	-- (the blobs' flat bottoms sit lower than their frames: lift everything so the pads' underside is LIFT off the surface)
	local pads = m:FindFirstChild("Pads") :: BasePart
	local dy = LIFT - (pads.Position.Y - pads.Size.Y / 2)
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") and c ~= m.PrimaryPart then
			c.CFrame = c.CFrame + Vector3.new(0, dy, 0)
		end
	end
	decorOnly(m)
	local vf = Instance.new("Folder")
	vf.Name = "_Variants"
	vf.Parent = m
	local wall = Instance.new("Configuration")
	wall.Name = "Wall"
	wall:SetAttribute("Transparency_Strands", 0)
	wall.Parent = vf
	r6().install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: %.2f x %.2f x %.2f", id, size.X, size.Y, size.Z)
end

function R7.mossTemplates(): string
	local out = {}
	table.insert(out, mossPatch("jungle_moss_patch_small", 5.5, 4.2, 3, 70201))
	table.insert(out, mossPatch("jungle_moss_patch_medium", 8.5, 6.0, 3, 70202))
	table.insert(out, mossPatch("jungle_moss_patch_large", 12.0, 8.0, 4, 70203))
	return table.concat(out, "\n")
end

-- today's flat moss plates (plain thin Parts): name -> where they are
local PLATE_NAMES = { MossPatch = true, WallMoss = true, PlatformMoss = true }
local function plateRoots(): { Instance }
	return { workspace.Zones.Jungle, ServerStorage.BossArenas.Jungle }
end
function R7.mossPlates(): ({ BasePart }, string)
	local list, counts = {}, {}
	for _, root in ipairs(plateRoots()) do
		for _, p in ipairs(root:GetDescendants()) do
			if p:IsA("Part") and PLATE_NAMES[p.Name] and math.min(p.Size.X, p.Size.Y, p.Size.Z) <= 0.7 then
				table.insert(list, p)
				local key = p.Parent:GetFullName() .. "." .. p.Name
				counts[key] = (counts[key] or 0) + 1
			end
		end
	end
	local lines = {}
	for k, v in pairs(counts) do
		table.insert(lines, string.format("%s x%d", k, v))
	end
	table.sort(lines)
	return list, #list .. " plates\n" .. table.concat(lines, "\n")
end

-- the glowing floor pads (Neon parts near the floor; a pad model's whole box)
local function glowBoxes(root: Instance): { { cf: CFrame, size: Vector3 } }
	local boxes, seen = {}, {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			local host: Instance = d
			if d.Parent and d.Parent:IsA("Model") and d.Parent ~= root then
				host = d.Parent
			end
			if not seen[host] then
				seen[host] = true
				if host:IsA("Model") then
					local cf, size = host:GetBoundingBox()
					table.insert(boxes, { cf = cf, size = size })
				else
					table.insert(boxes, { cf = (host :: BasePart).CFrame, size = (host :: BasePart).Size })
				end
			end
		end
	end
	return boxes
end

-- does a disc (centre c, radius r, on a surface with normal n) reach into a glow box?
local function hitsGlow(boxes: { any }, c: Vector3, r: number): boolean
	for _, b in ipairs(boxes) do
		local lp = b.cf:PointToObjectSpace(c)
		local h = b.size / 2 + Vector3.new(0.3, 0.6, 0.3)
		local dx = math.max(0, math.abs(lp.X) - h.X)
		local dy = math.max(0, math.abs(lp.Y) - h.Y)
		local dz = math.max(0, math.abs(lp.Z) - h.Z)
		if dy <= 0.6 and math.sqrt(dx * dx + dz * dz) < r then
			return true
		end
	end
	return false
end

-- each plate -> the best-fitting patch (opts.dry: report only)
function R7.placeMoss(opts: any?): string
	local o = opts or {}
	local plates = R7.mossPlates()
	local arena = ServerStorage.BossArenas.Jungle
	local arenaParent = arena.Parent
	arena.Parent = workspace -- (raycasts need it in the workspace; moved back below)
	local lines, n = {}, 0
	local ok, err = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = plates
		local glow = { [workspace.Zones.Jungle] = glowBoxes(workspace.Zones.Jungle), [arena] = glowBoxes(arena) }
		local rng = Random.new(70210)
		for _, p in ipairs(plates) do
			local s = p.Size
			local axes = { { s.X, p.CFrame.RightVector }, { s.Y, p.CFrame.UpVector }, { s.Z, p.CFrame.LookVector } }
			table.sort(axes, function(a, b)
				return a[1] < b[1]
			end)
			local thinN, Sdim, Sdir, Ldim, Ldir = axes[1][2], axes[2][1], axes[2][2], axes[3][1], axes[3][2]
			-- the surface under / behind the plate
			local best = nil
			for _, d in ipairs({ thinN, -thinN }) do
				local r = workspace:Raycast(p.Position + d * 1.5, -d * 4, params)
				if r and (best == nil or (r.Position - p.Position).Magnitude < (best.Position - p.Position).Magnitude) then
					best = r
				end
			end
			local isWall = math.abs(thinN.Y) < 0.5
			local surf, nrm
			if best then
				surf, nrm = best.Position, best.Normal
			else
				nrm = if isWall then thinN else (if thinN.Y > 0 then thinN else -thinN)
				surf = p.Position - nrm * (axes[1][1] / 2)
			end
			-- variant and scale (footprint: the plate's long / short sides, at most +10 %)
			local area = math.sqrt(Ldim * Sdim)
			local id = if area < 6.5 then "jungle_moss_patch_small" elseif area < 9.5 then "jungle_moss_patch_medium" else "jungle_moss_patch_large"
			local pads = folder():FindFirstChild(id):FindFirstChild("Pads") :: BasePart
			local t = { pads.Size.X, pads.Size.Z } -- (the pads' footprint)
			local k = math.clamp(math.min(Ldim / t[1], Sdim * 1.1 / t[2]), 0.75, 1.6)
			-- orientation
			local cf
			if isWall then
				local up = Vector3.yAxis
				local x = nrm:Cross(up).Unit
				cf = CFrame.fromMatrix(surf, x, nrm, x:Cross(nrm)) * CFrame.Angles(0, math.rad(rng:NextNumber(-12, 12)), 0)
			else
				local ld = (Ldir - nrm * Ldir:Dot(nrm)).Unit
				cf = CFrame.fromMatrix(surf, ld, nrm) * CFrame.Angles(0, math.rad(rng:NextNumber(-15, 15)) + (if rng:NextNumber() < 0.5 then math.pi else 0), 0)
			end
			-- never on a glowing pad: shrink, then step away
			local root = if p:IsDescendantOf(arena) then arena else workspace.Zones.Jungle
			local note = ""
			if not isWall then
				local tries = 0
				while hitsGlow(glow[root], cf.Position, t[1] * k * 0.5) and tries < 8 do
					tries += 1
					if k > 0.8 then
						k = math.max(0.75, k * 0.9)
					else
						-- step away from the nearest pad
						local nearest, nd = nil, math.huge
						for _, b in ipairs(glow[root]) do
							local dd = (b.cf.Position - cf.Position).Magnitude
							if dd < nd then
								nearest, nd = b, dd
							end
						end
						local away = cf.Position - nearest.cf.Position
						away = Vector3.new(away.X, 0, away.Z)
						away = if away.Magnitude > 1e-3 then away.Unit else Vector3.xAxis
						cf = cf + away * 1.0
					end
					note = string.format(" (glow pad: k %.2f, moved %.1f)", k, (cf.Position - surf).Magnitude)
				end
			end
			n += 1
			table.insert(lines, string.format("%s -> %s %s k %.2f%s", p:GetFullName(), id, if isWall then "Wall" else "floor", k, note))
			if not o.dry then
				local m = folder():FindFirstChild(id):Clone()
				for _, c in ipairs(m:GetChildren()) do
					if c.Name == "_Variants" then
						c:Destroy()
					end
				end
				m.Name = p.Name
				m:SetAttribute("MapPropId", id)
				m:SetAttribute("MapPropVersion", nil)
				if isWall then
					m:SetAttribute("Variant", "Wall")
				end
				CollectionService:AddTag(m, "MapProp")
				m:ScaleTo(k)
				m:PivotTo(cf)
				m.Parent = p.Parent
				p:Destroy()
			end
		end
	end)
	arena.Parent = arenaParent
	assert(ok, err)
	return n .. " patches\n" .. table.concat(lines, "\n")
end

---------------------------------------------------------------------
-- PART 3 item 5: THE EMPTY CAVE (tundra_landmark_ice_cave_peak, Tundra_3): a big ice-blue / grey boulder fills the
-- cave mouth, built from Agent A's faceted gate boulders (DevTools.PropsTundraGatesSolids tundra_gate3__boulder_left /
-- _right: layered blues with snow caps), a few faceted ice crystals at its foot, icicles under its brow, soft snow at
-- the front. One invisible "Collision" box matching it. Template tundra_cave_boulder (pivot on the ground, the mouth
-- side = local -Z); a copy is nested in the cave landmark template (tagged MapProp), so the preview sample and the map
-- stay identical.
---------------------------------------------------------------------
R7.CAVE_ID = "tundra_cave_boulder"
function R7.caveBoulder(): string
	local lib = r6().lib()
	local H, M, TB, GS = lib.H, lib.M, lib.TB, lib.GS
	local rng = Random.new(70305)
	local m = Instance.new("Model")
	m.Name = R7.CAVE_ID
	pivotPart(m)
	H.setBevelSelf(true)
	local U: any = { Rock = {}, Ice = {}, Snow = {}, Icicles = {}, Crystals = {} }
	-- two big rounded boulders bulging out of the mouth (fronts 3-6 studs proud of the ice pillars, at local z about
	-- -6), each a cluster of overlapping faceted lumps (many small facets), in the light tundra rock family: pale ice
	-- tops, grey-blue sides in layered bands, a cooler shadow underneath; a thick snow cap on top, drifts at the foot
	local ROCKS = { rgb(160, 178, 204), rgb(143, 163, 191), rgb(176, 194, 218), rgb(131, 151, 180) } -- #A0B2CC #8FA3BF #B0C2DA #8397B4
	local function rockTone(n: Vector3): Color3
		if n.Y > 0.7 then
			return rgb(206, 222, 246) -- #CEDEF6 frosted top
		elseif n.Y < -0.4 then
			return rgb(118, 136, 164)
		end
		return H.scaled(ROCKS[rng:NextInteger(1, #ROCKS)], 1 + 0.06 * n.Y)
	end
	local lumps = {
		-- the left boulder (biggest)
		{ -5.5, 14.0, -3.5, 10.5, 14.5, 8.0 }, { -8.5, 7.0, -5.5, 7.5, 7.5, 6.5 }, { -3.0, 23.5, -2.5, 8.5, 7.5, 7.0 },
		{ -11.0, 18.0, -1.5, 5.5, 9.0, 6.0 },
		-- the right boulder
		{ 7.5, 11.5, -3.0, 8.5, 11.5, 7.5 }, { 10.0, 5.0, -4.5, 6.5, 5.5, 6.0 }, { 6.0, 19.5, -1.5, 7.5, 7.0, 6.5 },
		-- the crown between them, up to the cave's brow
		{ 1.0, 28.5, 0.5, 11.5, 7.5, 6.5 }, { -1.0, 33.0, 2.0, 9.0, 4.5, 5.0 },
		-- the back mass (fills the mouth behind them)
		{ 0.5, 18.0, 3.0, 14.5, 19.0, 5.0 },
	}
	for _, l in ipairs(lumps) do
		local f = CFrame.new(l[1], l[2], l[3]) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 6.28), rng:NextNumber(-0.15, 0.15))
		TB.lump(U.Rock, rng, f, l[4], l[5], l[6], rockTone, if l[2] - l[5] < 1 then l[2] else nil)
	end
	-- smaller knobs on the fronts (breaking the big faces into many small facets)
	for _, k in ipairs({ { -7.0, 9.0, -10.0, 3.5 }, { -2.5, 16.5, -10.5, 3.0 }, { -9.0, 21.0, -6.0, 2.8 }, { 5.0, 7.5, -9.5, 3.2 }, { 10.5, 14.0, -8.0, 2.8 }, { 3.0, 13.0, -9.0, 2.5 }, { -4.0, 4.0, -10.5, 3.0 }, { 1.5, 24.0, -6.0, 3.0 } }) do
		TB.lump(U.Rock, rng, CFrame.new(k[1], k[2], k[3]) * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0), k[4] * 1.2, k[4], k[4] * 0.9, rockTone)
	end
	-- the snow cap (thick, soft, over the crown and the two boulder tops) and a few patches on the ledges
	local function snowCapTone(n: Vector3): Color3
		return if n.Y > 0.45 then rgb(244, 248, 255) else rgb(214, 228, 248)
	end
	for _, s in ipairs({ { 1.0, 35.2, 0.5, 10.5, 1.8, 6.0 }, { -4.0, 30.2, -4.5, 7.0, 1.4, 4.5 }, { 7.0, 26.0, -4.0, 6.0, 1.3, 4.0 }, { -7.5, 23.0, -8.5, 4.5, 1.0, 3.0 }, { 9.5, 16.5, -8.0, 3.5, 0.9, 2.5 } }) do
		TB.lump(U.Snow, rng, CFrame.new(s[1], s[2], s[3]) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), s[4], s[5], s[6], snowCapTone, s[5] * 0.4)
	end
	-- faceted ice crystals at the foot (front)
	local ICE = { rgb(150, 214, 250), rgb(84, 160, 232) }
	for k, c in ipairs({ { -13.0, -9.5, 7.5 }, { -10.0, -11.5, 4.5 }, { 12.0, -10.0, 6.0 }, { 14.5, -7.5, 9.0 } }) do
		local col = ICE[(k % 2) + 1]
		local tilt = (Vector3.new(math.sign(c[1]) * 0.35, 1, -0.3)).Unit
		local f = H.frameY(Vector3.new(c[1], -0.3, c[2]), tilt) * CFrame.Angles(0, rng:NextNumber(0, 1), 0)
		local r = c[3] * 0.16
		table.insert(U.Crystals, M.frustumN(6, r, r * 0.86, 0, c[3] * 0.72, f, { col, H.scaled(col, 1.12), H.scaled(col, 0.9) }))
		table.insert(U.Crystals, M.frustumN(6, r * 0.86, 0.05, c[3] * 0.72, c[3], f, { H.scaled(col, 1.15), col }))
	end
	-- icicles under the brow and snow drifts at the front
	for _, x in ipairs({ -9.0, -6.2, -2.5, 1.5, 4.8 }) do
		TB.facetIcicle(U, "Icicles", Vector3.new(x + rng:NextNumber(-0.4, 0.4), rng:NextNumber(17, 21), -10.5 + rng:NextNumber(-0.3, 0.3)), rng:NextNumber(0.5, 0.9), 1.0, rng:NextNumber(0, 6.28))
	end
	local function snowTone(n: Vector3): Color3
		return if n.Y > 0.5 then rgb(244, 248, 255) else rgb(206, 222, 246)
	end
	for _, s in ipairs({ { -8, -11.0, 5.5 }, { 0.5, -10.5, 6.0 }, { 9, -10.0, 5.0 }, { -14, -5, 3.5 }, { 15, -4, 3.5 } }) do
		TB.lump(U.Snow, rng, CFrame.new(s[1], 0.05, s[2]) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), s[3], 1.8, s[3] * 0.6, snowTone, 0.3)
	end
	for k, v in pairs(U) do
		if #v == 0 then
			U[k] = nil
		end
	end
	for name, list in pairs(U) do
		local opts = {}
		if name == "Ice" or name == "Icicles" then
			opts = TB.ICICLE_OPTS
		elseif name == "Crystals" then
			opts = { material = Enum.Material.Glass, transparency = 0.15, shadow = false }
		end
		H.merge(m, name, list, opts)
		task.wait()
	end
	H.setBevelSelf(false)
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			c.Anchored = true
			c.CanCollide, c.CanQuery, c.CanTouch = false, false, false
		end
	end
	-- the blocker: one invisible box over the rock's body
	local _, size = m:GetBoundingBox()
	local col = Instance.new("Part")
	col.Name = "Collision"
	col.Size = Vector3.new(26, 35, 13)
	col.CFrame = CFrame.new(0.5, 17.5, -1.0)
	col.Anchored = true
	col.CanCollide, col.CanQuery, col.CanTouch, col.CastShadow = true, true, false, false
	col.Transparency = 1
	col.Parent = m
	r6().install(R7.CAVE_ID, m)
	return string.format("%s: %.1f x %.1f x %.1f", R7.CAVE_ID, size.X, size.Y, size.Z)
end

-- the boulder nested in the cave landmark template, in the mouth (the dark panel's frame: front = its -Z)
function R7.placeCaveBoulder(): string
	local tpl = folder():FindFirstChild("tundra_landmark_ice_cave_peak") :: Model
	assert(tpl, "cave landmark template missing")
	local old = tpl:FindFirstChild("Cave_Boulder")
	if old then
		old:Destroy()
	end
	local dark = tpl:FindFirstChild("CaveDark") :: BasePart
	local b = folder():FindFirstChild(R7.CAVE_ID):Clone()
	b.Name = "Cave_Boulder"
	b:SetAttribute("MapPropId", R7.CAVE_ID)
	CollectionService:AddTag(b, "MapProp")
	local f = dark.CFrame
	local ground = f.Position.Y - dark.Size.Y / 2
	b:PivotTo(CFrame.fromMatrix(Vector3.new(0, ground, 0) + (f * Vector3.new(0, 0, -7.5)) * Vector3.new(1, 0, 1), f.RightVector, Vector3.yAxis))
	b.Parent = tpl
	return "nested at " .. tostring(b:GetPivot().Position)
end

-- OWNER CORRECTION (2026-10-26): the cave mouth stays as it was (no boulder in it); the "holes on the sides" are the
-- strip under the peaks north of the mouth (world x 8130-8160, z 655-690, y 0-6: rays from the lower terrace at player
-- height reach about x 8360, out of the map). Smaller copies of tundra_cave_boulder (the reusable gap rock) close it,
-- nested in the landmark template (so the preview sample shows them too). They stand behind the zone's East bound
-- (x 8127): their scaled invisible Collision is kept but no player reaches it.
R7.GAP_ROCKS = {
	-- world position (the landmark copy's pivot is (8150, 0, 664), no turn), yaw (the rock's front, local -Z, faces the
	-- terrace: west), scale
	{ Vector3.new(8136, 0, 651), 95, 0.36 },
	{ Vector3.new(8139, 0, 661), 90, 0.44 },
	{ Vector3.new(8141, 0, 676), 75, 0.48 },
	{ Vector3.new(8138, 0, 690), 105, 0.42 },
	{ Vector3.new(8140, 0, 701), 115, 0.40 },
}
function R7.caveGaps(): string
	local tpl = folder():FindFirstChild("tundra_landmark_ice_cave_peak") :: Model
	assert(tpl, "cave landmark template missing")
	local removed = 0
	for _, c in ipairs(tpl:GetChildren()) do
		if c.Name == "Cave_Boulder" or c.Name == "Gap_Rock" then
			c:Destroy()
			removed += 1
		end
	end
	local base = Vector3.new(8150, 0, 664) -- (the map copy's pivot = the template's origin)
	for i, g in ipairs(R7.GAP_ROCKS) do
		local b = folder():FindFirstChild(R7.CAVE_ID):Clone()
		b.Name = "Gap_Rock"
		b:SetAttribute("MapPropId", R7.CAVE_ID)
		CollectionService:AddTag(b, "MapProp")
		b:ScaleTo(g[3])
		b:PivotTo(CFrame.new(g[1] - base) * CFrame.Angles(0, math.rad(g[2]), 0))
		b.Parent = tpl
	end
	return string.format("%d removed, %d gap rocks nested", removed, #R7.GAP_ROCKS)
end

---------------------------------------------------------------------
-- PART 3 items 1, 2, 4: ICE CASTLE BRICKS (texture only, PropTextures.BossRoomBrick.tundra_ice_brick: an 8 x 8 stud
-- tile of 4 x 2 blocks in running bond, the gate's built ice-block colours, joints #2860AA). Textures named
-- "IceBrickTex" (ZIndex 1) on the vertical faces of the listed walls and towers: outer faces Color3 white, faces
-- that look into the hall or the entrance corridor (and every boss room wall) Color3 #D2D2D2 (a bit darker inside).
-- Never on tops / bottoms (roofs, ceilings), trims, crystals, facets or floors. A face mostly covered by another part
-- is skipped. Rows on the world grid (OffsetStudsV from the face's top edge), columns from the face's +edge along
-- world X or Z, so neighbouring faces line up.
---------------------------------------------------------------------
R7.BRICK_NAME = "IceBrickTex"
local function brickId(): string
	local cfg = require(game:GetService("ReplicatedStorage").GameSystem.Config.PropTextures:Clone()) :: any
	local id = cfg.BossRoomBrick and cfg.BossRoomBrick.tundra_ice_brick
	assert(id, "PropTextures.BossRoomBrick.tundra_ice_brick missing")
	return id
end
local CASTLE = {
	exterior = { "FrontWallE", "FrontWallW", "CornerTower", "BackTower", "KeepTower", "GreatTower", "Keep" },
	shell = { "ForeBlockE", "ForeBlockW", "WingE", "WingW", "WallE", "WallN", "WallSE", "WallSW", "WallSTop" },
	arena = { "Wall", "ApseBack", "ApseSide", "AlcoveBack", "AlcoveSide" },
}
R7.CASTLE = CASTLE
-- the castle's interior volumes (world): the hall and the entrance corridor
local HALL = { { Vector3.new(7910, 0, 790), Vector3.new(8090, 48, 940) }, { Vector3.new(7985, 0, 733), Vector3.new(8015, 24, 790) } }
local function inBoxes(p: Vector3): boolean
	for _, b in ipairs(HALL) do
		if p.X > b[1].X and p.X < b[2].X and p.Y > b[1].Y and p.Y < b[2].Y and p.Z > b[1].Z and p.Z < b[2].Z then
			return true
		end
	end
	return false
end
local function inPart(q: BasePart, p: Vector3): boolean
	local lp = q.CFrame:PointToObjectSpace(p)
	local h = q.Size / 2
	return math.abs(lp.X) < h.X and math.abs(lp.Y) < h.Y and math.abs(lp.Z) < h.Z
end
local function covered(p: BasePart, face: Enum.NormalId, blockers: { BasePart }): boolean
	local lv = Vector3.FromNormalId(face)
	local n = p.CFrame:VectorToWorldSpace(lv)
	local c = p.CFrame * (lv * p.Size / 2)
	local a1 = Vector3.yAxis
	local a2 = lv:Cross(a1)
	local h1 = p.Size.Y / 2
	local h2 = math.abs(a2.X) * p.Size.X / 2 + math.abs(a2.Z) * p.Size.Z / 2
	local w2 = p.CFrame:VectorToWorldSpace(a2)
	local total, hits = 0, 0
	for i = -2, 2 do
		for j = -2, 2 do
			local s = c + Vector3.yAxis * h1 * (i * 0.45) + w2 * h2 * (j * 0.45)
			total += 1
			for _, q in ipairs(blockers) do
				if q ~= p and inPart(q, s + n * 0.05) then
					hits += 1
					break
				end
			end
		end
	end
	return hits >= total * 0.9
end
local function blockersOf(root: Instance): { BasePart }
	local list = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.5 and d.Name ~= "Facet" and not d:IsA("MeshPart") and d:IsA("Part") then
			table.insert(list, d)
		end
	end
	return list
end

-- opts.dry: list only; returns the report
function R7.castleBricks(opts: any?): string
	local o = opts or {}
	local id = brickId()
	local T4 = workspace.Zones.Tundra.Tundra_4.Decor
	local arena = ServerStorage.BossArenas.Tundra
	local castleBlockers = blockersOf(T4)
	local arenaBlockers = blockersOf(arena.Decor)
	local sets = {
		{ root = T4.Exterior, names = CASTLE.exterior, blockers = castleBlockers, arena = false },
		{ root = T4.Shell, names = CASTLE.shell, blockers = castleBlockers, arena = false },
		{ root = arena.Decor.Shell, names = CASTLE.arena, blockers = arenaBlockers, arena = true },
	}
	local lines, nTex, nOut, nIn = {}, 0, 0, 0
	for _, set in ipairs(sets) do
		local wanted = {}
		for _, nm in ipairs(set.names) do
			wanted[nm] = true
		end
		for _, p in ipairs(set.root:GetChildren()) do
			if p:IsA("Part") and wanted[p.Name] then
				local faces = {}
				for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
					local lv = Vector3.FromNormalId(face)
					local n = p.CFrame:VectorToWorldSpace(lv)
					if math.abs(n.Y) > 0.1 or covered(p, face, set.blockers) then
						continue
					end
					local c = p.CFrame * (lv * p.Size / 2)
					-- (a boss room face that looks away from the arena's centre is never seen)
					if set.arena and Vector3.new(c.X - arena.Floor.Position.X, 0, c.Z - arena.Floor.Position.Z).Unit:Dot(n) > 0.3 then
						continue
					end
					local inner = set.arena or inBoxes(c + n * 1.0)
					table.insert(faces, face.Name .. (if inner then "(in)" else ""))
					if not o.dry then
						local t = Instance.new("Texture")
						t.Name = R7.BRICK_NAME
						t.Texture = id
						t.Face = face
						t.StudsPerTileU, t.StudsPerTileV = 8, 8
						t.Color3 = if inner then Color3.fromRGB(210, 210, 210) else Color3.new(1, 1, 1)
						t.ZIndex = 1
						local topY = p.Position.Y + p.Size.Y / 2
						t.OffsetStudsV = (-topY) % 8
						-- columns: the face's low edge along world X (or Z) on the 8-stud grid (axis-aligned faces only)
						local u = n:Cross(Vector3.yAxis)
						local hw = (if face == Enum.NormalId.Front or face == Enum.NormalId.Back then p.Size.X else p.Size.Z) / 2
						if math.abs(u.X) > 0.99 then
							t.OffsetStudsU = (-(c.X - hw)) % 8
						elseif math.abs(u.Z) > 0.99 then
							t.OffsetStudsU = (-(c.Z - hw)) % 8
						end
						t.Parent = p
					end
					nTex += 1
					if inner then
						nIn += 1
					else
						nOut += 1
					end
				end
				table.insert(lines, string.format("  %s %s: %s", p:GetFullName():gsub("Workspace.Zones.Tundra.", ""), p.Color:ToHex(), table.concat(faces, " ")))
			end
		end
	end
	return string.format("%s%d faces (%d outer, %d inner)\n%s", if o.dry then "DRY " else "", nTex, nOut, nIn, table.concat(lines, "\n"))
end

-- removes the castle brick textures
function R7.castleBricksClear(): string
	local n = 0
	for _, root in ipairs({ workspace.Zones.Tundra.Tundra_4.Decor, ServerStorage.BossArenas.Tundra }) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Texture") and d.Name == R7.BRICK_NAME then
				d:Destroy()
				n += 1
			end
		end
	end
	return n .. " removed"
end

---------------------------------------------------------------------
-- PART 4: THE SWAMP EXTERIOR BEFORE SUB-ZONE 4 (the approach from Swamp_3 to the skull palisade gate, image 09).
-- New reusable MapProps templates (swamp block of the preview):
--   swamp_cliff_wall      a 30 x 58 (+ rim) cladding panel of layered faceted rock strata (flat-topped slabs in
--                         banded tones, ledges, a wet dark foot, cracks, moss on the ledges, ghost mushrooms, hanging
--                         moss, vines and roots, an irregular rim of crags and moss); front = local -Z, pivot = bottom
--                         centre of the face it covers; set on the front faces of the sub-zone's flat Shell rocks
--                         (their collision unchanged)
--   swamp_rotten_timber   a rotten broken timber (33.6 long, local Z): twisted grain, splintered end (+Z), rope
--                         lashings, an iron bracket with rivets at the end that enters the cliff (-Z), moss; over the
--                         Shell GiantRoot beams (made invisible, their collision unchanged)
--   swamp_puddle          a shallow muddy puddle (dark teal water, a ring of wet mud) for the gate dressing
-- swamp_rock_cliff_a (the big side rocks) is rebuilt in the improved boulder look (a faceted mass per rock with strata
-- ledges, a draped moss cap, ferns); its Toolbox meshes stay as the invisible collision. Decor only (no scripts),
-- anchored, CanCollide / CanQuery / CanTouch off on every visible piece.
---------------------------------------------------------------------
local SW = {
	rock = { rgb(102, 115, 109), rgb(86, 98, 92), rgb(112, 122, 115), rgb(75, 84, 78) }, -- #66736D #56625C #707A73 #4B544E
	wet = rgb(44, 52, 48), moss = rgb(56, 90, 46), mossTop = rgb(78, 116, 52), mud = rgb(58, 42, 28), -- moss #385A2E / #4E7434
	water = rgb(32, 62, 60), crack = rgb(36, 40, 38), wood = rgb(78, 58, 44), root = rgb(70, 52, 38), iron = rgb(72, 70, 76),
}
R7.SW = SW
local function mossT(n: Vector3): Color3
	if n.Y > 0.45 then
		return SW.mossTop
	end
	return if n.Y > -0.2 then SW.moss else Color3.new(SW.moss.R * 0.8, SW.moss.G * 0.8, SW.moss.B * 0.8)
end
local function finishDecor(m: Model, U: any, opts: any?)
	local H = r6().lib().H
	for name, list in pairs(U) do
		if #list > 0 then
			H.merge(m, name, list, (opts and opts[name]) or { shadow = true })
			task.wait()
		end
	end
	H.setBevelSelf(false)
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") and c.Name ~= "Collision" then
			c.Anchored = true
			c.CanCollide, c.CanQuery, c.CanTouch = false, false, false
		end
	end
end

-- a faceted rock slab at frame (a half-width X, b half-height Y, c half-depth Z): a flat top and bottom (the strata),
-- 8 jittered side planes and 8 chamfers along the top and bottom edges (about 60 triangles)
local function slab(list: { BasePart }, rng: Random, frame: CFrame, a: number, b: number, c: number, toneOf: (Vector3) -> Color3)
	local TB = r6().lib().TB
	local planes = { { n = Vector3.yAxis, d = b }, { n = -Vector3.yAxis, d = b } }
	local a0 = rng:NextNumber(0, 0.4)
	for k = 0, 7 do
		local ang = a0 + k * math.pi / 4 + rng:NextNumber(-0.12, 0.12)
		local d = Vector3.new(math.cos(ang), rng:NextNumber(-0.15, 0.15), math.sin(ang)).Unit
		local dd = math.sqrt((a * d.X) ^ 2 + (c * d.Z) ^ 2) * rng:NextNumber(0.96, 1.04)
		table.insert(planes, { n = d, d = dd })
		if k % 2 == 0 then
			for _, sy in ipairs({ 1, -1 }) do
				local e = Vector3.new(d.X, sy * 0.9, d.Z)
				table.insert(planes, { n = e.Unit, d = (dd * math.sqrt(d.X ^ 2 + d.Z ^ 2) + b * 0.9 - math.min(a, b, c) * 0.35) / e.Magnitude })
			end
		end
	end
	local e = Vector3.new(a, b, c) * 1.3
	TB.solidOf(list, frame, -e, e, planes, toneOf)
end
R7.slab = slab

function R7.swampCliffWall(): string
	local L = r6().lib()
	local H, TB = L.H, L.TB
	local ST = st()
	local rng = Random.new(70401)
	local m = Instance.new("Model")
	m.Name = "swamp_cliff_wall"
	pivotPart(m)
	H.setBevelSelf(true)
	local U: any = { Strata = {}, Strata2 = {}, Wet = {}, Moss = {}, Cracks = {}, Vines = {}, Leaves = {}, Roots = {}, Mush = {}, Strands = {} }
	local W, Ht = 30, 58
	local dip = CFrame.Angles(0, 0, 0.035)
	-- the strata: rows 4-7 tall of 2-4 flat-topped slabs; every row its own band tone and depth (ledges and recesses)
	local y = 0
	local row = 0
	local tones = { 1, 3, 2, 4, 1, 2, 3, 4 }
	while y < Ht - 0.5 do
		local h = math.min(rng:NextNumber(4, 7), Ht - y)
		if Ht - y - h < 2.5 then
			h = Ht - y
		end
		local n = rng:NextInteger(2, 4)
		local x = -W / 2
		local wet = y < 4.5
		local base = if wet then SW.wet else SW.rock[tones[(row % #tones) + 1]]
		local ledge = row % 3 == 2
		local rowOut = (if ledge then 3.4 else rng:NextNumber(1.2, 2.6))
		for k = 1, n do
			local w = if k == n then W / 2 - x else (W / n) * rng:NextNumber(0.8, 1.2)
			local cx = x + w / 2
			local out = rowOut + rng:NextNumber(-0.4, 0.4)
			local col = H.scaled(base, rng:NextNumber(0.94, 1.06))
			local depth = 2.2 + out * 0.5
			local f = dip * CFrame.new(cx, y + h / 2, -out + depth) * CFrame.Angles(0, rng:NextNumber(-0.05, 0.05), rng:NextNumber(-0.03, 0.03))
			slab(if wet then U.Wet elseif row % 2 == 0 then U.Strata else U.Strata2, rng, f, w * 0.56 + 0.4, h * 0.5, depth, function(nv: Vector3): Color3
				if nv.Y > 0.6 then
					return H.scaled(col, if wet then 1.1 else 1.14)
				elseif nv.Y < -0.6 then
					return H.scaled(col, 0.78)
				end
				return H.scaled(col, 0.96 + 0.06 * nv.X)
			end)
			-- moss on the top of some slabs (front edge)
			if not wet and rng:NextNumber() < 0.3 then
				local mt = (dip * CFrame.new(cx + rng:NextNumber(-w * 0.2, w * 0.2), y + h, -out + 0.5)).Position
				TB.lump(U.Moss, rng, CFrame.new(mt) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), w * rng:NextNumber(0.2, 0.32), 0.4, 1.1, mossT, 0.12)
			end
			-- a crack down some slabs
			if not wet and rng:NextNumber() < 0.3 then
				table.insert(U.Cracks, H.piece("Part", Vector3.new(0.2, h * 0.7, 0.3), dip * CFrame.new(cx + rng:NextNumber(-w * 0.25, w * 0.25), y + h / 2, -out - 0.05) * CFrame.Angles(0, 0, rng:NextNumber(-0.25, 0.25)), SW.crack))
			end
			x += w
		end
		-- the ledges: moss along the top, ghost mushrooms here and there, hanging moss over the edge
		if ledge and y > 4 and y + h < Ht - 4 then
			local lx = rng:NextNumber(-W / 2 + 6, W / 2 - 6)
			local top = (dip * CFrame.new(lx, y + h, -rowOut + 0.6)).Position
			TB.lump(U.Moss, rng, CFrame.new(top) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0), rng:NextNumber(4, 6.5), 0.45, 1.4, mossT, 0.15)
			if rng:NextNumber() < 0.65 then
				ST.ghostMushrooms(U.Mush, rng, top + Vector3.new(rng:NextNumber(-2, 2), 0.25, -0.2), 3, 0.9)
			else
				ST.fern(U.Leaves, rng, top + Vector3.new(rng:NextNumber(-2, 2), 0.2, 0), 4, 1.6)
			end
			for _ = 1, rng:NextInteger(1, 3) do
				ST.mossStrand(U.Strands, rng, top + Vector3.new(rng:NextNumber(-3.5, 3.5), -0.1, -1.4), rng:NextNumber(1.2, 2.6), SW.moss)
			end
		end
		y += h
		row += 1
	end
	-- the irregular rim: low crags of rock with moss between and on them
	local x = -W / 2
	while x < W / 2 - 0.5 do
		local w = math.min(rng:NextNumber(4, 7), W / 2 - x)
		local cx = x + w / 2
		local hh = rng:NextNumber(1.0, 4.0)
		slab(U.Strata, rng, CFrame.new(cx, Ht + hh / 2 - 0.3, 0.6) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.12, 0.12)), w * 0.55, hh / 2 + 0.3, 3.0, function(nv: Vector3): Color3
			return H.scaled(SW.rock[3], if nv.Y > 0.6 then 1.1 else 0.95)
		end)
		if rng:NextNumber() < 0.85 then
			TB.lump(U.Moss, rng, CFrame.new(cx, Ht + hh + 0.1, 0.0) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), w * 0.5, 0.9, 3.0, mossT, 0.4)
		end
		x += w
	end
	-- 3 weathered boulders bulging out of the strata (they break the courses)
	for _ = 1, 3 do
		local s = rng:NextNumber(3.2, 4.6)
		ST.blob(U.Strata2, rng, CFrame.new(rng:NextNumber(-W / 2 + 5, W / 2 - 5), rng:NextNumber(8, Ht - 10), -2.6) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)), s * 1.2, s, s * 0.9, function(nv: Vector3): Color3
			return H.scaled(SW.rock[2], if nv.Y > 0.5 then 1.16 else 0.95 + 0.05 * nv.X)
		end)
	end
	-- hanging vines and roots from the rim
	for _ = 1, 3 do
		local top = Vector3.new(rng:NextNumber(-12, 12), Ht + 0.3, -3.2)
		ST.leafyVine(U.Vines, U.Leaves, rng, top, rng:NextNumber(10, 22), 0.35, rgb(52, 92, 40))
	end
	for _ = 1, 2 do
		-- a root hanging over the rim and down the face in 3 crooked lengths
		local p = Vector3.new(rng:NextNumber(-11, 11), Ht + 0.6, -1.5)
		local r0 = 0.8
		local len = rng:NextNumber(14, 22)
		for j = 1, 3 do
			local q = p + Vector3.new(rng:NextNumber(-2, 2), -len / 3, if j == 1 then -1.6 else rng:NextNumber(-0.5, 0.3))
			ST.twistedLog(U.Roots, nil, rng, p, q, r0, r0 * 0.75, SW.root)
			p, r0 = q, r0 * 0.75
		end
	end
	finishDecor(m, U, { Mush = { shadow = false }, Vines = { shadow = false }, Leaves = { shadow = false }, Strands = { shadow = false }, Cracks = { shadow = false } })
	r6().install("swamp_cliff_wall", m)
	local _, size = m:GetBoundingBox()
	return string.format("swamp_cliff_wall: %.1f x %.1f x %.1f", size.X, size.Y, size.Z)
end

function R7.swampRottenTimber(): string
	local L = r6().lib()
	local H, M, TB = L.H, L.M, L.TB
	local ST = st()
	local rng = Random.new(70402)
	local m = Instance.new("Model")
	m.Name = "swamp_rotten_timber"
	pivotPart(m)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Grain = {}, Rope = {}, Iron = {}, Moss = {}, Splinters = {} }
	local Len, r = 33.6, 2.7
	local a, b = Vector3.new(0, 0, -Len / 2), Vector3.new(0, 0, Len / 2 - 2.5)
	ST.twistedLog(U.Wood, U.Grain, rng, a, b, r, r * 0.86, SW.wood, 0.2, math.rad(6))
	-- the broken end: splinters of different lengths round the rim
	for k = 0, 6 do
		local ang = k * math.pi * 2 / 7 + rng:NextNumber(-0.2, 0.2)
		local p = b + Vector3.new(math.cos(ang) * r * 0.6, math.sin(ang) * r * 0.6, -0.2)
		local len = rng:NextNumber(1.2, 3.6)
		table.insert(U.Splinters, M.frustumN(4, rng:NextNumber(0.35, 0.6), 0.05, 0, len, H.frameY(p, (Vector3.zAxis + Vector3.new(math.cos(ang), math.sin(ang), 0) * 0.25).Unit), { H.scaled(SW.wood, 1.25), H.scaled(SW.wood, 1.05) }))
	end
	-- light end grain on the broken end and on the sawn end
	table.insert(U.Splinters, M.frustumN(8, r * 0.84, r * 0.8, -0.1, 0.06, H.frameY(b, Vector3.zAxis), { rgb(104, 80, 58), rgb(92, 70, 50) }))
	table.insert(U.Splinters, M.frustumN(8, r * 0.9, r * 0.9, 0, 0.1, H.frameY(a - Vector3.new(0, 0, 0.08), Vector3.zAxis), { rgb(122, 92, 64), rgb(110, 82, 58) }))
	-- rope lashings, an iron bracket with rivets near the root end, moss on the top side
	for _, f in ipairs({ -0.12, 0.18 }) do
		TB.lashing(U.Rope, Vector3.new(0, 0, Len * f), Vector3.zAxis, r * 0.95, 3, rng)
	end
	local z0 = -Len / 2 + 3.0
	table.insert(U.Iron, M.frustumN(8, r + 0.12, r + 0.12, z0 - 0.5, z0 + 0.5, H.frameY(Vector3.zero, Vector3.zAxis) * CFrame.Angles(0, math.rad(22.5), 0), { SW.iron, H.scaled(SW.iron, 1.2) }))
	for k = 0, 5 do
		local ang = k * math.pi / 3
		H.rivet(U.Iron, Vector3.new(math.cos(ang) * (r + 0.2), math.sin(ang) * (r + 0.2), z0), 0.3)
	end
	for _, z in ipairs({ -6, 4 }) do
		TB.lump(U.Moss, rng, CFrame.new(0, r * 0.85, z), 1.8, 0.45, rng:NextNumber(3, 5), mossT, 0.1)
	end
	finishDecor(m, U)
	r6().install("swamp_rotten_timber", m)
	local _, size = m:GetBoundingBox()
	return string.format("swamp_rotten_timber: %.1f x %.1f x %.1f", size.X, size.Y, size.Z)
end

function R7.swampPuddle(): string
	local L = r6().lib()
	local H, M, TB = L.H, L.M, L.TB
	local rng = Random.new(70403)
	local m = Instance.new("Model")
	m.Name = "swamp_puddle"
	pivotPart(m)
	H.setBevelSelf(true)
	local U: any = { Water = {}, Mud = {} }
	table.insert(U.Water, M.frustumN(10, 4.3, 4.1, 0.0, 0.1, CFrame.Angles(0, rng:NextNumber(0, 1), 0), { SW.water, H.scaled(SW.water, 1.12) }))
	-- a second, smaller pool (an irregular outline)
	local lobe = Vector3.new(4.2, 0, 2.2)
	table.insert(U.Water, M.frustumN(9, 2.7, 2.6, 0.0, 0.1, CFrame.new(lobe) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), { SW.water, H.scaled(SW.water, 1.12) }))
	-- a ring of flat wet mud lumps of uneven size round both (none where the pools meet)
	local function ring(c: Vector3, R: number, n: number)
		for k = 0, n - 1 do
			local ang = k * math.pi * 2 / n + rng:NextNumber(-0.15, 0.15)
			local p = c + Vector3.new(math.cos(ang), 0, math.sin(ang)) * R * rng:NextNumber(0.97, 1.1)
			if (p - Vector3.zero).Magnitude > 4.0 and (p - lobe).Magnitude > 2.4 then
				TB.lump(U.Mud, rng, CFrame.new(p.X, 0.02, p.Z) * CFrame.Angles(0, -ang, 0), rng:NextNumber(0.7, 1.4), rng:NextNumber(0.16, 0.3), rng:NextNumber(1.3, 2.4), function(nv: Vector3): Color3
					return if nv.Y > 0.5 then H.scaled(SW.mud, 1.12) else H.scaled(SW.mud, 0.85)
				end, 0.02)
			end
		end
	end
	ring(Vector3.zero, 4.5, 12)
	ring(lobe, 2.9, 8)
	finishDecor(m, U, { Water = { material = Enum.Material.SmoothPlastic, transparency = 0.05, shadow = false }, Mud = { shadow = false } })
	r6().install("swamp_puddle", m)
	return "swamp_puddle"
end

-- swamp_rock_cliff_a in the improved boulder look (template rebuilt from the Toolbox original: its colliding meshes
-- become the invisible collision, the rest go; a rebuild starts again from the original kept in _Previous)
function R7.swampCliffRock(): string
	local id = "swamp_rock_cliff_a"
	local L = r6().lib()
	local H, TB = L.H, L.TB
	local ST = st()
	local cur = folder():FindFirstChild(id) :: Model
	assert(cur, "template " .. id .. " missing")
	local prev = folder():FindFirstChild("_Previous")
	local src = cur
	if cur:FindFirstChild("Collision") then
		src = assert(prev and prev:FindFirstChild(id), "original of " .. id .. " missing") :: Model
		cur:Destroy()
		src.Parent = folder()
	end
	local m = src:Clone()
	local rng = Random.new(70404)
	H.setBevelSelf(true)
	local U: any = { Rock = {}, Rock2 = {}, Moss = {}, Fern = {} }
	local rows = {}
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			-- world-aligned half extents of the (rotated) mesh box
			local R = c.CFrame
			local hs = c.Size / 2
			local ext = Vector3.new(
				math.abs(R.RightVector.X) * hs.X + math.abs(R.UpVector.X) * hs.Y + math.abs(R.LookVector.X) * hs.Z,
				math.abs(R.RightVector.Y) * hs.X + math.abs(R.UpVector.Y) * hs.Y + math.abs(R.LookVector.Y) * hs.Z,
				math.abs(R.RightVector.Z) * hs.X + math.abs(R.UpVector.Z) * hs.Y + math.abs(R.LookVector.Z) * hs.Z
			)
			table.insert(rows, { name = c.Name, p = c.Position, e = ext, color = c.Color })
			if c.CanCollide then
				c.Name = "Collision"
				c.Transparency = 1
				c.CastShadow = false
				c.CanQuery = true
				c.CanTouch = false
			else
				c:Destroy()
			end
		end
	end
	local bb, total = src:GetBoundingBox()
	local foot = bb.Position - Vector3.new(0, total.Y / 2, 0)
	for i, r in ipairs(rows) do
		local c, e = r.p, r.e
		if r.name == "Moss" then
			-- a draped moss cap over the top of the rock under it
			TB.lump(U.Moss, rng, CFrame.new(c.X, c.Y + e.Y * 0.25, c.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), e.X * 0.92, e.Y * 0.5, e.Z * 0.92, mossT, e.Y * 0.1)
		else
			-- the rock: a faceted mass (18 planes, rocky) filling its box, and 2 strata ledges round its sides
			local base = SW.rock[(i % #SW.rock) + 1]:Lerp(r.color, 0.3)
			local function tone(nv: Vector3): Color3
				if nv.Y > 0.6 then
					return H.scaled(base, 1.12)
				elseif nv.Y < -0.5 then
					return H.scaled(base, 0.8)
				end
				return H.scaled(base, 0.95 + 0.05 * nv.X)
			end
			ST.blob(U.Rock, rng, CFrame.new(c - Vector3.new(0, e.Y * 0.05, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), e.X * 0.84, e.Y * 0.9, e.Z * 0.84, tone, e.Y * 0.85)
			for k = 1, 2 do
				local yy = c.Y - e.Y + e.Y * 2 * (k / 3) + rng:NextNumber(-0.1, 0.1) * e.Y
				local off = Vector3.new(rng:NextNumber(-0.15, 0.15) * e.X, 0, rng:NextNumber(-0.15, 0.15) * e.Z)
				slab(U.Rock2, rng, CFrame.new(c.X + off.X, yy, c.Z + off.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.05, 0.05)), e.X * (0.88 - 0.1 * k), e.Y * 0.17, e.Z * (0.88 - 0.1 * k), function(nv: Vector3): Color3
					return H.scaled(base, if nv.Y > 0.6 then 1.08 else 0.9)
				end)
			end
		end
	end
	-- ferns at the foot
	for k = 1, 5 do
		local ang = k * math.pi * 2 / 5 + rng:NextNumber(-0.3, 0.3)
		ST.fern(U.Fern, rng, foot + Vector3.new(math.cos(ang) * total.X * 0.42, 0.1, math.sin(ang) * total.Z * 0.42), 5, 3.2)
	end
	finishDecor(m, U, { Fern = { shadow = false } })
	r6().install(id, m)
	local _, size = m:GetBoundingBox()
	return string.format("%s: %.1f x %.1f x %.1f", id, size.X, size.Y, size.Z)
end

-- the placements (world; the sub-zone's Shell rocks are fixed): cliff panels { x, y, z, scale } (no turn: their
-- fronts face the approach, -Z); the dressing { id, x, y, z, yaw (degrees), scale, roll (degrees, the crooked fence) }
R7.SWAMP_CLIFF = {
	-- the front faces (z 775) of the two big Shell rocks either side of the passage (x 9875-9985 / 10015-10125)
	-- (sizes and heights varied: the copies do not repeat in a row and the rim stays irregular)
	{ 9890, -2, 775, 1.04 }, { 9919, 0, 775, 0.96 }, { 9947, -3, 775, 1.08 }, { 9971, -1, 775, 0.98 },
	{ 10029, -2, 775, 1.05 }, { 10053, 0, 775, 0.95 }, { 10081, -3, 775, 1.07 }, { 10110, -1, 775, 1.0 },
	-- the rock over the passage (x 9985-10015, y 36-58; the panel's foot hides in the canopy rock)
	{ 10000, 24, 775, 0.6 },
	-- the frame round the gate (the "light-blue frame" of image 09): the fronts (z 728.4) of the canopy rock and the 2
	-- side rocks, a low rampart band above the palisade (y about 33-48)
	{ 9975, 22, 728.4, 0.42 }, { 9987.5, 23, 728.4, 0.40 }, { 10000, 22, 728.4, 0.44 }, { 10012.5, 23, 728.4, 0.40 },
	{ 10025, 22, 728.4, 0.42 },
}
R7.SWAMP_DRESS = {
	-- left of the path
	{ "swamp_puddle", 9970, 0.02, 699.5, 20, 0.75 },
	{ "swamp_lily_pads", 9969, 0.08, 699, 0, 0.45 },
	{ "swamp_fence_fence", 9942, 0, 703.5, 8, 1, -5 },
	{ "swamp_fence_fence", 9950.2, 0, 703, -6, 1, 7 },
	{ "swamp_fence_fence", 9958.3, 0, 703.8, 12, 1, -9 },
	{ "swamp_statue_bone_pile", 9947, 0, 698, 30, 0.8 },
	{ "swamp_furniture_crate", 9983.5, 0, 703, 25, 1 },
	{ "swamp_plant_glow_mushroom_b", 9979.5, 0, 700, 0, 1 },
	{ "swamp_plant_glow_mushroom_a", 9962, 0, 700.5, 40, 0.9 },
	{ "swamp_hanging_lantern", 9988, 0, 706, 0, 1 },
	-- right of the path
	{ "swamp_hanging_lantern", 10012, 0, 706, 0, 1 },
	{ "swamp_puddle", 10026, 0.02, 701, -30, 0.7 },
	{ "swamp_lily_pads", 10025, 0.08, 700.5, 60, 0.4 },
	{ "swamp_rock_mud_mound_a", 10046, 0, 703, 15, 0.5 },
	{ "swamp_plant_glow_mushroom_a", 10018, 0, 704, 0, 1 },
	{ "swamp_plant_glow_mushroom_b", 10052, 0, 704.5, 70, 0.9 },
	{ "swamp_statue_bone_pile", 10035, 0, 705.5, -40, 0.7 },
	{ "swamp_fence_fence", 10058, 0, 705, -10, 1, 6 },
	{ "swamp_fence_fence", 10066.2, 0, 704.2, 5, 1, -8 },
}
local function copyOf(id: string, cf: CFrame, scale: number, parent: Instance, name: string?): Model
	local c = (folder():FindFirstChild(id) :: Model):Clone()
	c.Name = name or id
	c:SetAttribute("MapPropId", id)
	CollectionService:AddTag(c, "MapProp")
	if math.abs(scale - 1) > 1e-3 then
		c:ScaleTo(scale)
	end
	c:PivotTo(cf)
	c.Parent = parent
	return c
end

-- the exterior: cliff panels, rotten timbers over the GiantRoot beams (made invisible, collision kept), the gate
-- dressing (all copies of MapProps templates); run again, it replaces its own copies
function R7.swampExterior(): string
	local s3 = workspace.Zones.Swamp.Swamp_3
	local shell = workspace.Zones.Swamp.Swamp_4.Decor.Shell
	R7.swampExteriorClear(true)
	local cliffF = Instance.new("Folder")
	cliffF.Name = "R7_CliffDress"
	cliffF.Parent = shell
	local n = { cliff = 0, timber = 0, dress = 0 }
	for i, p in ipairs(R7.SWAMP_CLIFF) do
		copyOf("swamp_cliff_wall", CFrame.new(p[1], p[2], p[3]), p[4], cliffF, "Cliff_" .. i)
		n.cliff += 1
	end
	-- the timbers: the end deeper in the cliff (larger z) takes the bracket (-Z); the 2 long beams break in the middle
	for _, r in ipairs(shell:GetChildren()) do
		if r:IsA("BasePart") and r.Name == "GiantRoot" then
			local L = r.Size.Z
			local cf = r.CFrame
			local e1 = cf * Vector3.new(0, 0, -L / 2)
			local e2 = cf * Vector3.new(0, 0, L / 2)
			local flip = CFrame.Angles(0, math.pi, 0)
			if L < 40 then
				local f = if e1.Z >= e2.Z then cf else cf * flip
				copyOf("swamp_rotten_timber", f, L / 33.6 * (if r.Size.X > 6.5 then 1.08 else 1), cliffF, "Timber")
				n.timber += 1
			else
				local s = (L / 2 - 1) / 33.6
				copyOf("swamp_rotten_timber", cf * CFrame.new(0, 0, -L / 4 - 0.5), s, cliffF, "Timber")
				copyOf("swamp_rotten_timber", cf * CFrame.new(0, 0, L / 4 + 0.5) * flip, s, cliffF, "Timber")
				n.timber += 2
			end
			r.Transparency = 1
			r.CastShadow = false
		end
	end
	local dressF = Instance.new("Folder")
	dressF.Name = "R7_GateDressing"
	dressF.Parent = s3.Decor
	for _, d in ipairs(R7.SWAMP_DRESS) do
		local cf = CFrame.new(d[2], d[3], d[4]) * CFrame.Angles(0, math.rad(d[5]), 0) * CFrame.Angles(0, 0, math.rad(d[7] or 0))
		copyOf(d[1], cf, d[6], dressF)
		n.dress += 1
	end
	return string.format("cliff %d, timbers %d, dressing %d", n.cliff, n.timber, n.dress)
end

-- removes the exterior copies; without `keepRoots` the GiantRoot beams are shown again
function R7.swampExteriorClear(keepRoots: boolean?): string
	local shell = workspace.Zones.Swamp.Swamp_4.Decor.Shell
	local s3d = workspace.Zones.Swamp.Swamp_3.Decor
	for _, f in ipairs({ shell:FindFirstChild("R7_CliffDress"), s3d:FindFirstChild("R7_GateDressing") }) do
		if f then
			f:Destroy()
		end
	end
	if not keepRoots then
		for _, r in ipairs(shell:GetChildren()) do
			if r:IsA("BasePart") and r.Name == "GiantRoot" then
				r.Transparency = 0
				r.CastShadow = true
			end
		end
	end
	return "cleared"
end

---------------------------------------------------------------------
-- PART 5: SWAMP SUB-ZONE 4 AND BOSS ROOM TEXTURES (texture only; ids PropTextures.BossRoomBrick.swamp_wall_stone,
-- an 8 x 8 stud tile of mossy dark stone blocks, and swamp_floor_mud_stone, 24 x 24 studs of muddy flagstones).
-- Walls ("SwampWallTex", Color3 white): the room-facing vertical faces of the sub-zone's RockFacets and Shell Rocks
-- (above / between the facets, the passage sides; never the outer cliff face of Part 4) and of the boss room's
-- RockSlabs, alcove walls / lintels and the Rock over the door. Floors ("SwampFloorTex"): the tops of the sub-zone's
-- Ground.Floor and the arena Floor / AlcoveFloors (Color3 white); the stone slabs lying on them (FloorStone,
-- PathStone, FloorTile) the same texture at Color3 #E0E0E0 (lighter slabs of the same family). Ceilings, pools, glow
-- veins and roots stay as they are. Rows on the world grid (OffsetStudsV from the face's top edge, columns from the
-- face's low edge along world X / Z for axis-aligned faces; floor tops from the +X / +Z edge).
---------------------------------------------------------------------
R7.SWAMP_WALL_TEX, R7.SWAMP_FLOOR_TEX = "SwampWallTex", "SwampFloorTex"
local function swampIds(): (string, string)
	local cfg = require(game:GetService("ReplicatedStorage").GameSystem.Config.PropTextures:Clone()) :: any
	local b = cfg.BossRoomBrick or {}
	assert(b.swamp_wall_stone and b.swamp_floor_mud_stone, "PropTextures swamp ids missing")
	return b.swamp_wall_stone, b.swamp_floor_mud_stone
end
local function sbox(x0: number, x1: number, y0: number, y1: number, z0: number, z1: number): any
	return { lo = Vector3.new(x0, y0, z0), hi = Vector3.new(x1, y1, z1), c = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2) }
end
local function inSBox(b: any, p: Vector3): boolean
	return p.X >= b.lo.X and p.X <= b.hi.X and p.Y >= b.lo.Y and p.Y <= b.hi.Y and p.Z >= b.lo.Z and p.Z <= b.hi.Z
end
-- the rooms: the interior volumes (boxes; the arena: a round room of radius 79 round its centre), the wall parts by
-- folder and name, the floor parts
local function swampRooms(): any
	local S4 = workspace.Zones.Swamp.Swamp_4.Decor
	local A = ServerStorage.BossArenas.Swamp
	return {
		{
			name = "Swamp_4",
			root = S4,
			boxes = { sbox(9909.5, 10090.5, -0.5, 46, 795, 945), sbox(9985, 10015, -0.5, 24, 729, 795) },
			walls = { { S4.Shell, { Rock = true } }, { S4.Facets, { RockFacet = true } } },
			floors = { { S4.Ground, { Floor = 1 } }, { S4.Ground, { FloorStone = 0.88, PathStone = 0.88 } } },
		},
		{
			name = "BossArenas.Swamp",
			root = A,
			centre = Vector3.new(10000, 0, -600),
			radius = 79,
			height = 64,
			boxes = { sbox(9874, 9924, -0.5, 30, -620, -580), sbox(10076, 10126, -0.5, 30, -620, -580) },
			walls = { { A.Walls, { RockSlab = true, AlcoveWall = true, AlcoveLintel = true, Rock = true } } },
			floors = { { A, { Floor = 1 } }, { A.Walls, { AlcoveFloor = 1 } }, { A.Decor, { FloorTile = 0.88 } } },
		},
	}
end
-- the face's centre, normal and the 2 in-plane axes (world) with their half lengths
local function faceFrame(p: BasePart, face: Enum.NormalId): (Vector3, Vector3, Vector3, number, Vector3, number)
	local lv = Vector3.FromNormalId(face)
	local n = p.CFrame:VectorToWorldSpace(lv)
	local h = math.abs(lv.X) * p.Size.X / 2 + math.abs(lv.Y) * p.Size.Y / 2 + math.abs(lv.Z) * p.Size.Z / 2
	local a1 = if math.abs(lv.X) > 0.5 then Vector3.yAxis else Vector3.xAxis
	local a2 = lv:Cross(a1)
	local h1 = math.abs(a1.X) * p.Size.X / 2 + math.abs(a1.Y) * p.Size.Y / 2 + math.abs(a1.Z) * p.Size.Z / 2
	local h2 = math.abs(a2.X) * p.Size.X / 2 + math.abs(a2.Y) * p.Size.Y / 2 + math.abs(a2.Z) * p.Size.Z / 2
	return p.Position + n * h, n, p.CFrame:VectorToWorldSpace(a1), h1, p.CFrame:VectorToWorldSpace(a2), h2
end
-- a room-facing face: one of 25 probes (0.5 stud out) lies in the room and the normal points toward the room's middle
local function roomFace(room: any, p: BasePart, face: Enum.NormalId): boolean
	local c, n, w1, h1, w2, h2 = faceFrame(p, face)
	for i = -2, 2 do
		for j = -2, 2 do
			local q = c + w1 * h1 * (i * 0.45) + w2 * h2 * (j * 0.45) + n * 0.5
			if room.centre then
				local d = Vector3.new(q.X - room.centre.X, 0, q.Z - room.centre.Z)
				if d.Magnitude < room.radius and q.Y > -0.5 and q.Y < room.height and n:Dot(-d) > 0 then
					return true
				end
			end
			for _, b in ipairs(room.boxes) do
				if inSBox(b, q) and n:Dot(Vector3.new(b.c.X - c.X, 0, b.c.Z - c.Z)) > 0 then
					return true
				end
			end
		end
	end
	return false
end

-- opts.dry: list only; returns the report
function R7.swampTextures(opts: any?): string
	local o = opts or {}
	local wallId, floorId = swampIds()
	local lines, nWall, nFloor = {}, 0, 0
	for _, room in ipairs(swampRooms()) do
		local blockers = blockersOf(room.root)
		for _, set in ipairs(room.walls) do
			for _, p in ipairs(set[1]:GetChildren()) do
				if p:IsA("Part") and p.Shape == Enum.PartType.Block and set[2][p.Name] and p.Transparency < 1 then
					local faces = {}
					for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
						local c, n = faceFrame(p, face)
						-- (the facets lean 5-9 degrees: a face up to about 17 degrees off vertical is a wall face)
						if math.abs(n.Y) > 0.3 or not roomFace(room, p, face) or covered(p, face, blockers) then
							continue
						end
						table.insert(faces, face.Name)
						nWall += 1
						if not o.dry then
							local t = Instance.new("Texture")
							t.Name = R7.SWAMP_WALL_TEX
							t.Texture = wallId
							t.Face = face
							t.StudsPerTileU, t.StudsPerTileV = 8, 8
							t.Color3 = Color3.new(1, 1, 1)
							t.ZIndex = 1
							t.OffsetStudsV = (-(p.Position.Y + p.Size.Y / 2)) % 8
							local u = n:Cross(Vector3.yAxis)
							local hw = (if face == Enum.NormalId.Front or face == Enum.NormalId.Back then p.Size.X else p.Size.Z) / 2
							if math.abs(u.X) > 0.99 then
								t.OffsetStudsU = (-(c.X - hw)) % 8
							elseif math.abs(u.Z) > 0.99 then
								t.OffsetStudsU = (-(c.Z - hw)) % 8
							end
							t.Parent = p
						end
					end
					if #faces > 0 then
						table.insert(lines, string.format("  %s wall: %s", p:GetFullName():gsub("^Workspace%.Zones%.Swamp%.", ""):gsub("^ServerStorage%.", ""), table.concat(faces, ",")))
					end
				end
			end
		end
		for _, set in ipairs(room.floors) do
			for _, p in ipairs(set[1]:GetChildren()) do
				local k = p:IsA("Part") and set[2][p.Name]
				if k and p.Transparency < 1 then
					-- the up face (a turned cylinder: its end cap)
					local face = Enum.NormalId.Top
					for _, f in ipairs({ Enum.NormalId.Top, Enum.NormalId.Right, Enum.NormalId.Left, Enum.NormalId.Front, Enum.NormalId.Back }) do
						if p.CFrame:VectorToWorldSpace(Vector3.FromNormalId(f)).Y > 0.9 then
							face = f
						end
					end
					nFloor += 1
					if not o.dry then
						local t = Instance.new("Texture")
						t.Name = R7.SWAMP_FLOOR_TEX
						t.Texture = floorId
						t.Face = face
						t.StudsPerTileU, t.StudsPerTileV = 24, 24
						t.Color3 = Color3.new(k, k, k)
						t.ZIndex = 1
						if face == Enum.NormalId.Top and p.CFrame.Rotation:FuzzyEq(CFrame.identity, 1e-4) then
							t.OffsetStudsU = (-(p.Position.X + p.Size.X / 2)) % 24
							t.OffsetStudsV = (-(p.Position.Z + p.Size.Z / 2)) % 24
						end
						t.Parent = p
					end
					if k == 1 then
						table.insert(lines, string.format("  %s floor: %s", p:GetFullName():gsub("^Workspace%.Zones%.Swamp%.", ""):gsub("^ServerStorage%.", ""), face.Name))
					end
				end
			end
		end
	end
	table.sort(lines)
	return string.format("%sswamp textures: %d wall faces, %d floor faces (slabs included)\n%s", if o.dry then "DRY " else "", nWall, nFloor, table.concat(lines, "\n"))
end

-- removes the swamp textures
function R7.swampTexturesClear(): string
	local n = 0
	for _, root in ipairs({ workspace.Zones.Swamp.Swamp_4.Decor, ServerStorage.BossArenas.Swamp }) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Texture") and (d.Name == R7.SWAMP_WALL_TEX or d.Name == R7.SWAMP_FLOOR_TEX) then
				d:Destroy()
				n += 1
			end
		end
	end
	return n .. " removed"
end

return R7
