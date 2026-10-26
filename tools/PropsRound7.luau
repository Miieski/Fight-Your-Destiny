--[[
	PropsRound7 (dev tool, Edit mode only) - owner prompt "ROUND 7: BOSS ROOM TEXTURE FIX + JUNGLE MOSS + ICE CASTLE +
	SWAMP EXTERIORS/INTERIOR + DESERT PYRAMID BRICKS" (docs/Round7_Textures_And_Exteriors/PROMPT_ROUND7.txt).
	Source of truth: tools/PropsRound7.luau (= ServerStorage.DevTools.PropsRound7).

	Usage (execute_luau, Edit):
		local R7 = require(game.ServerStorage.DevTools.PropsRound7:Clone())
		print(R7.mossTemplates())     -- P2: jungle_moss_patch_small / _medium / _large (+ Variant "Wall")
		print(R7.mossPlates())        -- P2: the list of today's flat moss plates (names, counts)
		print(R7.placeMoss())         -- P2: each plate -> the best-fitting patch (raised, never on a glowing pad)
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

return R7
