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
		print(R7.castleBricks({ dry = true }), R7.castleBricks()) -- P3 items 1 / 2 / 4: ice castle bricks (texture only)
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

return R7
