--[[
	TerrainFix (dev tool, Edit mode only): reads the low-poly "Facet" surfaces (WedgePart pairs made by
	BuildKit.tri) back as triangles, so a surface can be warped, re-thickened or recoloured and rebuilt
	with the same look; closes mountain feet; checks what players and cameras can see / reach; plus
	folder-level backups through the Studio log.
	Source of truth: tools/TerrainFix.luau in the repo (= ServerStorage.DevTools.TerrainFix).
	Made for the Plains_1 fix of 2026-10-19 (owner items 4-8: holes by the gate, south mountain moved,
	closed mountains, ridge tops, rocks). Log: docs/NIGHT_LOG.md "Plains sub-zone 1 fix".

	Usage (execute_luau, Edit; require a Clone to dodge the require cache):
		local T = require(game.ServerStorage.DevTools.TerrainFix:Clone())
		print(T.backup("old_terrain_2026-10-19_plains1", { Mountains = P1.Decor.Mountains }))
		-- then on disk: python tools/collect_backup.py --wait 60   (writes BackUP_Files/<folder>/<name>.rbxm)
		local tris = T.triangles({ P1.Decor.Mountains })   -- { a, b, c, color, material, t, parts, ... }
		T.dump(tris, "mtn")                                 -- FYDTRI| lines in the log (plot them on disk)
		T.rebuild(tris, { thickness = 0.3, warp = function(v) return v end })   -- same shape, thin slabs
		local edges = T.openEdgesOf(tris)                   -- boundary edges of that surface
		T.seatEdges(tris, edges, { surfY = ..., filter = ... }) -- inner mountain edges onto the hill crest
		T.footSkirt(edges, folder, { surfY = ... })         -- close what is left under an edge
		T.viewScan(points, { dirs = T.directions(450, -60, 85), isTerrain = T.isTerrain, exclude = ... })
		T.reachScan({ x0, x1, z0, z1, start = entrance, isTerrain = T.isTerrain })   -- walkable flood fill

	A BuildKit.tri triangle is two right-triangle wedges sharing the altitude: on each wedge's top face
	(the X face whose world normal points up) P1 = the end of the long edge, P2 = the foot of the altitude,
	P3 = the apex. Triangle = { P3, P1(w1), P1(w2) }. A wedge without a twin is its own right triangle.

	Slab thickness: BuildKit puts each facet's slab UNDER the triangle. At a convex crest the slab of one
	side pokes out of the other side by about its thickness, and its underside reads as a dark ledge from
	below (owner, 2026-10-19: "thick dark slab-like edges along the ridges"). Mountains / ridges / cliffs
	around Plains_1 were rebuilt with 0.3-stud slabs: the surface is the same, the ledge is a hairline.
]]

local SerializationService = game:GetService("SerializationService")
local EncodingService = game:GetService("EncodingService")
local ServerStorage = game:GetService("ServerStorage")

local T = {}

local CHUNK = 800 -- Studio log lines are cut at about 1020 characters

---------------------------------------------------------------------
-- Backups (one .rbxm per instance; collect with tools/collect_backup.py)
---------------------------------------------------------------------
-- items: { [name] = Instance }. Ids "<folderName>/<name>" -> BackUP_Files/<folderName>/<name>.rbxm.
function T.backup(folderName: string, items: { [string]: Instance }): string
	assert(string.match(folderName, "^[%w_%-]+$"), "backup: folder name must be letters, digits, _ or -")
	local report = {}
	local names = {}
	for name in pairs(items) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		assert(string.match(name, "^[%w_%-]+$"), "backup: bad name " .. name)
		local inst = items[name]
		local id = `{folderName}/{name}`
		local ok, result = pcall(function()
			return SerializationService:SerializeInstancesAsync({ inst })
		end)
		if ok then
			local b64 = buffer.tostring(EncodingService:Base64Encode(result))
			local count = math.ceil(#b64 / CHUNK)
			print(`FYDBAK|{id}|HEAD|{count}|{#b64}|{buffer.len(result)}`)
			for i = 1, count do
				print(`FYDBAK|{id}|{i}|{string.sub(b64, (i - 1) * CHUNK + 1, i * CHUNK)}`)
				if i % 200 == 0 then
					task.wait()
				end
			end
			print(`FYDBAK|{id}|TAIL`)
			table.insert(report, `{id}.rbxm {buffer.len(result)} bytes ({inst:GetFullName()})`)
		else
			table.insert(report, `FAILED {id}: {result}`)
		end
	end
	return table.concat(report, "\n")
end

---------------------------------------------------------------------
-- Facets -> triangles
---------------------------------------------------------------------
local function topFace(p: BasePart)
	local cf, s = p.CFrame, p.Size
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	local sx = if cf.RightVector.Y >= 0 then 1 else -1
	return cf:PointToWorldSpace(Vector3.new(sx * hx, -hy, -hz)), cf:PointToWorldSpace(Vector3.new(sx * hx, -hy, hz)),
		cf:PointToWorldSpace(Vector3.new(sx * hx, hy, hz))
end
T.topFace = topFace

local function key(v: Vector3): string
	return string.format("%d|%d|%d", math.round(v.X * 20), math.round(v.Y * 20), math.round(v.Z * 20))
end

local function vkey(v: Vector3): string
	return string.format("%d|%d|%d", math.round(v.X * 4), math.round(v.Y * 4), math.round(v.Z * 4))
end
T.vkey = vkey

-- Triangles of every WedgePart named "Facet" under roots (filter(part) -> boolean optional).
-- Record: { a, b, c, color, material, t (slab thickness), parts = { w1, w2? }, parent, castShadow,
--           canCollide, tag (attribute Tag), transparency }
function T.triangles(roots: { Instance }, filter: ((BasePart) -> boolean)?)
	local wedges = {}
	for _, root in ipairs(roots) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("WedgePart") and d.Name == "Facet" and (not filter or filter(d)) then
				table.insert(wedges, d)
			end
		end
	end
	local byKey = {}
	local recs = {}
	for i, w in ipairs(wedges) do
		local p1, p2, p3 = topFace(w)
		local r = { w = w, p1 = p1, p2 = p2, p3 = p3, k = key(p2) .. "/" .. key(p3) }
		recs[i] = r
		local list = byKey[r.k]
		if not list then
			list = {}
			byKey[r.k] = list
		end
		table.insert(list, r)
		if i % 3000 == 0 then
			task.wait()
		end
	end
	local used = {}
	local tris = {}
	local function make(parts, a, b, c)
		local w = parts[1]
		return {
			a = a, b = b, c = c, color = w.Color, material = w.Material, t = w.Size.X, parts = parts,
			parent = w.Parent, castShadow = w.CastShadow, canCollide = w.CanCollide, tag = w:GetAttribute("Tag"),
			transparency = w.Transparency,
		}
	end
	for _, r in ipairs(recs) do
		if not used[r] then
			used[r] = true
			local twin
			for _, o in ipairs(byKey[r.k]) do
				if not used[o] and o.w.Parent == r.w.Parent then
					twin = o
					break
				end
			end
			if twin then
				used[twin] = true
				table.insert(tris, make({ r.w, twin.w }, r.p3, r.p1, twin.p1))
			else
				table.insert(tris, make({ r.w }, r.p3, r.p1, r.p2))
			end
		end
	end
	return tris
end

-- Prints the triangles as "FYDTRI|<tag>|ax,ay,az,bx,by,bz,cx,cy,cz,r,g,b,folder" lines (several per line).
function T.dump(tris, tag: string): number
	local line = {}
	local n = 0
	local function flush()
		if #line > 0 then
			print(`FYDTRI|{tag}|` .. table.concat(line, ";"))
			table.clear(line)
		end
	end
	for _, t in ipairs(tris) do
		local c = t.color
		table.insert(line, string.format("%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%d,%d,%d,%s",
			t.a.X, t.a.Y, t.a.Z, t.b.X, t.b.Y, t.b.Z, t.c.X, t.c.Y, t.c.Z,
			math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255), t.parent.Name))
		n += 1
		if #line >= 6 then
			flush()
		end
		if n % 1200 == 0 then
			task.wait()
		end
	end
	flush()
	return n
end

-- Boundary edges of a triangle set (used by one triangle only): { a, b, tri }.
function T.openEdgesOf(tris)
	local cnt, rec = {}, {}
	for _, t in ipairs(tris) do
		for _, e in ipairs({ { t.a, t.b }, { t.b, t.c }, { t.c, t.a } }) do
			local k1, k2 = vkey(e[1]), vkey(e[2])
			local kk = if k1 < k2 then k1 .. "/" .. k2 else k2 .. "/" .. k1
			cnt[kk] = (cnt[kk] or 0) + 1
			rec[kk] = { a = e[1], b = e[2], tri = t }
		end
	end
	local list = {}
	for kk, n in pairs(cnt) do
		if n == 1 then
			table.insert(list, rec[kk])
		end
	end
	return list
end

---------------------------------------------------------------------
-- Rebuild
---------------------------------------------------------------------
--[[
	Rebuilds triangles as new facets (BuildKit.tri) and deletes their old wedges.
	opts = {
		thickness = number? (default: each triangle's own t),
		warp = function(Vector3) -> Vector3 ? (moves every vertex; shared vertices stay shared),
		parent = Instance? (default: each triangle's own parent), color = function(tri) -> Color3 ?,
		keepOld = boolean? (true = leave the old wedges), attribute = string? (set to true on new wedges)
	}
	Returns made, removed.
]]
function T.rebuild(tris, opts: { [string]: any }?): (number, number)
	opts = opts or {}
	local Kit = require(ServerStorage.DevTools.BuildKit)
	local made, removed = 0, 0
	local staging = {}
	for i, t in ipairs(tris) do
		local a, b, c = t.a, t.b, t.c
		if opts.warp then
			a, b, c = opts.warp(a), opts.warp(b), opts.warp(c)
		end
		local parent = opts.parent or t.parent
		local holder = staging[parent]
		if not holder then
			holder = Instance.new("Folder")
			holder.Name = "_staging"
			staging[parent] = holder
		end
		local color = if opts.color then opts.color(t) else t.color
		local w1, w2 = Kit.tri(a, b, c, holder, color, opts.thickness or t.t, t.material)
		for _, w in ipairs({ w1, w2 }) do
			if w then
				w.CastShadow = t.castShadow
				w.CanCollide = t.canCollide
				w.Transparency = t.transparency or 0
				if t.tag then
					w:SetAttribute("Tag", t.tag)
				end
				if opts.attribute then
					w:SetAttribute(opts.attribute, true)
				end
				made += 1
			end
		end
		if not opts.keepOld then
			for _, p in ipairs(t.parts) do
				p:Destroy()
				removed += 1
			end
		end
		if i % 150 == 0 then
			for par, h in pairs(staging) do
				for _, w in ipairs(h:GetChildren()) do
					w.Parent = par
				end
			end
			task.wait()
		end
	end
	for par, h in pairs(staging) do
		for _, w in ipairs(h:GetChildren()) do
			w.Parent = par
		end
		h:Destroy()
	end
	return made, removed
end

---------------------------------------------------------------------
-- Mountain feet
---------------------------------------------------------------------
-- Height of the surface made of the given roots under (x, z) (e.g. a sub-zone's Hills + Ground: the
-- mountain itself is left out, so the result is the hill under an overhang). Returns fallback if none.
function T.surfaceY(roots: { Instance }, fallback: number?): (number, number) -> number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = roots
	return function(x: number, z: number): number
		local hit = workspace:Raycast(Vector3.new(x, 250, z), Vector3.new(0, -300, 0), params)
		return if hit then hit.Position.Y else (fallback or -1)
	end
end

-- Outward (away from the surface, horizontal) direction of each open edge, summed per vertex.
local function edgeDirs(edges)
	local vinfo = {}
	local list = {}
	for _, e in ipairs(edges) do
		local t = e.tri
		local c = (t.a + t.b + t.c) / 3
		local d = e.b - e.a
		local o = Vector3.new(-d.Z, 0, d.X).Unit
		if o:Dot(Vector3.new(c.X - e.a.X, 0, c.Z - e.a.Z)) > 0 then
			o = -o
		end
		local n = (t.b - t.a):Cross(t.c - t.a).Unit
		if n.Y < 0 then
			n = -n
		end
		for _, v in ipairs({ e.a, e.b }) do
			local k = vkey(v)
			local r = vinfo[k] or { v = v, o = Vector3.zero, ang = 0, n = 0 }
			r.o += o
			r.ang += math.acos(math.clamp(n.Y, -1, 1))
			r.n += 1
			vinfo[k] = r
		end
		table.insert(list, { e = e, o = o, ang = math.acos(math.clamp(n.Y, -1, 1)) })
	end
	return vinfo, list
end

--[[
	Seats the lower open edge of a mountain on the hill in front of it: every edge vertex that hangs
	above the hill (gap > opts.minGap, default 0.3) moves back into the mountain (horizontally, away from
	the zone) until the hill is within opts.reach (3.5) studs of its height, at most opts.maxBack (12)
	studs, and down to opts.bury (0.6) studs under the hill (never more than opts.maxDrop, 5, lower).
	The mountain triangles that use a moved vertex are rebuilt. opts.surfY = T.surfaceY({ hills, ground }).
	Returns the list of moves { from, to }.
]]
function T.seatEdges(tris, edges, opts: { [string]: any })
	local vinfo = edgeDirs(edges)
	local moves, list = {}, {}
	for k, r in pairs(vinfo) do
		local v = r.v
		if v.Y - opts.surfY(v.X, v.Z) > (opts.minGap or 0.3) then
			local back = -r.o.Unit
			local found, best, bestH = nil, nil, -math.huge
			for s = 0, math.floor((opts.maxBack or 12) * 2) do
				local p = v + back * (s * 0.5)
				local h = opts.surfY(p.X, p.Z)
				if h > bestH then
					best, bestH = p, h
				end
				if h >= v.Y - (opts.reach or 3.5) then
					found, bestH = p, h
					break
				end
			end
			local p = found or best
			local y = math.max(math.min(v.Y, bestH - (opts.bury or 0.6)), v.Y - (opts.maxDrop or 5))
			moves[k] = Vector3.new(p.X, y, p.Z)
			table.insert(list, { from = v, to = moves[k] })
		end
	end
	local affected = {}
	for _, t in ipairs(tris) do
		if moves[vkey(t.a)] or moves[vkey(t.b)] or moves[vkey(t.c)] then
			table.insert(affected, t)
		end
	end
	T.rebuild(affected, { warp = function(v)
		return moves[vkey(v)] or v
	end })
	return list
end

--[[
	Closes the gap under open edges that still hang above the hill: a skirt continues each edge down at
	the adjacent face's slope (clamped to opts.minAngle..opts.maxAngle degrees, default 80..86 = almost a
	cliff) until it is opts.bury (1.5) studs under opts.surfY; the edge is split where the bottom line
	would surface. Colour = the adjacent mountain triangle, thickness opts.thickness (0.3), attribute Tag.
	Returns the number of wedges made (in parent).
]]
function T.footSkirt(edges, parent: Instance, opts: { [string]: any }): number
	local Kit = require(ServerStorage.DevTools.BuildKit)
	local surfY = opts.surfY
	local bury = opts.bury or 1.5
	local minA, maxA = math.rad(opts.minAngle or 80), math.rad(opts.maxAngle or 86)
	local made = 0
	local vinfo, list = edgeDirs(edges)
	local function dirAt(v: Vector3, fo: Vector3, fa: number): Vector3
		local r = vinfo[vkey(v)]
		local o, ang = fo, fa
		if r and r.o.Magnitude > 0.2 then
			o, ang = r.o.Unit, r.ang / r.n
		end
		ang = math.clamp(ang, minA, maxA)
		return o * math.cos(ang) - Vector3.yAxis * math.sin(ang)
	end
	local function base(v: Vector3, d: Vector3): Vector3
		for step = 0, 400 do
			local p = v + d * (step * 0.25)
			if p.Y <= surfY(p.X, p.Z) - bury then
				return p
			end
		end
		return v + d * 100
	end
	for _, it in ipairs(list) do
		local e = it.e
		local da, db = dirAt(e.a, it.o, it.ang), dirAt(e.b, it.o, it.ang)
		local pts = { { f = 0 }, { f = 1 } }
		for _, p in ipairs(pts) do
			p.v = e.a:Lerp(e.b, p.f)
			p.b = base(p.v, da:Lerp(db, p.f).Unit)
		end
		local i = 1
		while i < #pts do
			local p, q = pts[i], pts[i + 1]
			local under = true
			for _, s in ipairs({ 0.25, 0.5, 0.75 }) do
				local m = p.b:Lerp(q.b, s)
				if m.Y > surfY(m.X, m.Z) - 0.4 then
					under = false
				end
			end
			if not under and (q.f - p.f) * (e.b - e.a).Magnitude > 3 then
				local f = (p.f + q.f) / 2
				local v = e.a:Lerp(e.b, f)
				table.insert(pts, i + 1, { f = f, v = v, b = base(v, da:Lerp(db, f).Unit) })
			else
				i += 1
			end
		end
		for j = 1, #pts - 1 do
			local p, q = pts[j], pts[j + 1]
			for _, tri in ipairs({ { p.v, q.v, q.b }, { p.v, q.b, p.b } }) do
				if (tri[2] - tri[1]):Cross(tri[3] - tri[1]).Magnitude > 0.05 then
					local w1, w2 = Kit.tri(tri[1], tri[2], tri[3], parent, opts.color or e.tri.color, opts.thickness or 0.3, e.tri.material)
					for _, w in ipairs({ w1, w2 }) do
						if w then
							w:SetAttribute("Tag", opts.tag or "foot")
							made += 1
						end
					end
				end
			end
		end
	end
	return made
end

---------------------------------------------------------------------
-- Checks: what do players / cameras see, where can they walk?
---------------------------------------------------------------------
T.TERRAIN_FOLDERS = {
	Ground = true, Hills = true, Mountains = true, MapFix = true, Closures = true, CorridorRidge = true,
	Cliffs = true, Dunes = true, Shore = true, Skirts = true, FootSkirts = true,
}
function T.isTerrain(p: Instance): boolean
	local node = p.Parent
	while node and node ~= workspace do
		if T.TERRAIN_FOLDERS[node.Name] then
			return true
		end
		node = node.Parent
	end
	return false
end

-- Face of a terrain part hit by a ray: "top" (the visible surface), "under" (the underside of a facet
-- slab or of a ground block = the inside of a hollow shell), "side" (a slab's edge, its thickness).
function T.faceKind(part: BasePart, normal: Vector3): string
	local n = part.CFrame:VectorToObjectSpace(normal)
	if part:IsA("WedgePart") and part.Name == "Facet" then
		if math.abs(n.X) > 0.9 then
			local sx = if part.CFrame.RightVector.Y >= 0 then 1 else -1
			return if n.X * sx > 0 then "top" else "under"
		end
		return "side"
	end
	if normal.Y < -0.5 then
		return "under"
	end
	return "top"
end

-- Directions on a sphere (Fibonacci), elevation between minEl and maxEl degrees.
function T.directions(count: number, minEl: number, maxEl: number): { Vector3 }
	local dirs = {}
	local golden = math.pi * (3 - math.sqrt(5))
	for i = 0, count - 1 do
		local y = 1 - (i + 0.5) / count * 2
		local el = math.deg(math.asin(y))
		if el >= minEl and el <= maxEl then
			local r = math.sqrt(1 - y * y)
			local th = golden * i
			table.insert(dirs, Vector3.new(math.cos(th) * r, y, math.sin(th) * r))
		end
	end
	return dirs
end

-- Viewpoints on the ground within band studs of the box edges, at the given heights above the ground.
function T.perimeterPoints(x0: number, x1: number, z0: number, z1: number, step: number, band: number, heights: { number }, exclude: { Instance }?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude or {}
	local pts = {}
	for x = x0, x1, step do
		for z = z0, z1, step do
			if math.min(x - x0, x1 - x, z - z0, z1 - z) <= band then
				local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), params)
				if hit then
					for _, h in ipairs(heights) do
						table.insert(pts, hit.Position + Vector3.new(0, h, 0))
					end
				end
			end
		end
	end
	return pts
end

--[[
	Casts rays from each viewpoint in every direction and classifies the first terrain hit.
	opts = {
		dirs = { Vector3 }, maxDist = number (default 600), isTerrain = function(part) -> boolean,
		exclude = { Instance }? (see-through: Bounds walls, water...), escapeEl = number? (degrees: a ray
		below this elevation that hits nothing is reported as "escape", default -2),
		ignoreSide = number? (side hits on slabs thinner than this are not reported, default 0)
	}
	Returns { counts = { top, under, side, escape, other }, bad = { { from, to, kind, part } } }.
]]
function T.viewScan(viewpoints: { Vector3 }, opts: { [string]: any })
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = opts.exclude or {}
	local maxDist = opts.maxDist or 600
	local escapeEl = math.sin(math.rad(opts.escapeEl or -2))
	local counts = { top = 0, under = 0, side = 0, escape = 0, other = 0 }
	local bad = {}
	local n = 0
	for _, vp in ipairs(viewpoints) do
		for _, d in ipairs(opts.dirs) do
			local hit = workspace:Raycast(vp, d * maxDist, params)
			n += 1
			if not hit then
				if d.Y < escapeEl then
					counts.escape += 1
					table.insert(bad, { from = vp, to = vp + d * 60, kind = "escape" })
				end
			elseif opts.isTerrain(hit.Instance) then
				local kind = T.faceKind(hit.Instance, hit.Normal)
				counts[kind] += 1
				if kind == "under" or (kind == "side" and hit.Instance.Size.X > (opts.ignoreSide or 0)) then
					table.insert(bad, { from = vp, to = hit.Position, kind = kind, part = hit.Instance })
				end
			else
				counts.other += 1
			end
			if n % 4000 == 0 then
				task.wait()
			end
		end
	end
	return { counts = counts, bad = bad }
end

-- Groups bad hits into cells of `cell` studs: { { pos, n, kinds, from, part } } sorted by n.
function T.clusters(bad, cell: number?)
	cell = cell or 10
	local map = {}
	for _, b in ipairs(bad) do
		local p = b.to
		local k = string.format("%d|%d|%d", math.floor(p.X / cell), math.floor(p.Y / cell), math.floor(p.Z / cell))
		local c = map[k]
		if not c then
			c = { pos = p, n = 0, kinds = {}, from = b.from, part = b.part }
			map[k] = c
		end
		c.n += 1
		c.kinds[b.kind] = (c.kinds[b.kind] or 0) + 1
	end
	local list = {}
	for _, c in pairs(map) do
		table.insert(list, c)
	end
	table.sort(list, function(a, b)
		return a.n > b.n
	end)
	return list
end

-- World ray through pixel (px, py) of a screen_capture taken with camera_position / look_at_position
-- (w x h pixels, vertical field of view fov, default 70): find the part under a pixel of a screenshot.
function T.pixelRay(camPos: Vector3, lookAt: Vector3, px: number, py: number, w: number, h: number, fov: number?): Vector3
	local cf = CFrame.lookAt(camPos, lookAt)
	local tanY = math.tan(math.rad((fov or 70) / 2))
	local tanX = tanY * w / h
	return (cf.LookVector + cf.RightVector * ((px / w) * 2 - 1) * tanX + cf.UpVector * (1 - (py / h) * 2) * tanY).Unit
end

--[[
	Walkable flood fill. Floors = upward faces (normal.Y > 0.3) of colliding parts with 4.6 studs of
	head room, on a grid (cell studs; offset the grid by a fraction of a stud so no sample lies exactly
	on a wall face). BFS from opts.start: a neighbour is reached when it is at most opts.climb (3.5)
	higher and a ray 2.5 studs above the floors is free. Every reached floor with terrain above it
	(an underside, T.faceKind) is reported in covered = a spot "inside a mountain" / under an overhang.
	opts = { x0, x1, z0, z1, cell, start = Vector3, isTerrain, exclude, climb, drop, top }
	Returns { reach = { {x, y, z, part} }, covered = { {x, y, z, above, h} }, box = { minX, maxX, minZ, maxZ }, cells }.
]]
function T.reachScan(opts: { [string]: any })
	local cell = opts.cell or 3
	local x0, x1, z0, z1 = opts.x0, opts.x1, opts.z0, opts.z1
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = opts.exclude or {}
	params.RespectCanCollide = true
	local nx, nz = math.floor((x1 - x0) / cell), math.floor((z1 - z0) / cell)
	local floors = {}
	local count = 0
	for ix = 0, nx do
		floors[ix] = {}
		for iz = 0, nz do
			local x, z = x0 + ix * cell, z0 + iz * cell
			local list = {}
			local from = Vector3.new(x, opts.top or 220, z)
			for _ = 1, 12 do
				local hit = workspace:Raycast(from, Vector3.new(0, -(from.Y + 40), 0), params)
				if not hit then
					break
				end
				if hit.Normal.Y > 0.3 then
					local p = hit.Position
					if not workspace:Raycast(p + Vector3.new(0, 0.1, 0), Vector3.new(0, 4.6, 0), params) then
						table.insert(list, { y = p.Y, part = hit.Instance })
					end
				end
				from = hit.Position - Vector3.new(0, 0.05, 0)
			end
			floors[ix][iz] = list
			count += 1
			if count % 300 == 0 then
				task.wait()
			end
		end
	end
	local function fkey(ix, iz, k)
		return (ix * 1000 + iz) * 20 + k
	end
	local seen, queue = {}, {}
	local sx, sz = math.round((opts.start.X - x0) / cell), math.round((opts.start.Z - z0) / cell)
	local best, bk = math.huge, nil
	for k, f in ipairs(floors[sx][sz]) do
		if math.abs(f.y - opts.start.Y) < best then
			best, bk = math.abs(f.y - opts.start.Y), k
		end
	end
	assert(bk, "reachScan: no floor at the start")
	table.insert(queue, { sx, sz, bk })
	seen[fkey(sx, sz, bk)] = true
	local head = 0
	local reach = {}
	while head < #queue do
		head += 1
		local ix, iz, k = queue[head][1], queue[head][2], queue[head][3]
		local f = floors[ix][iz][k]
		table.insert(reach, { x = x0 + ix * cell, z = z0 + iz * cell, y = f.y, part = f.part })
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local jx, jz = ix + d[1], iz + d[2]
			local list = floors[jx] and floors[jx][jz]
			for k2, f2 in ipairs(list or {}) do
				if not seen[fkey(jx, jz, k2)] and f2.y - f.y <= (opts.climb or 3.5) and f.y - f2.y <= (opts.drop or 30) then
					local a = Vector3.new(x0 + ix * cell, f.y + 2.5, z0 + iz * cell)
					local b = Vector3.new(x0 + jx * cell, f2.y + 2.5, z0 + jz * cell)
					if not workspace:Raycast(a, b - a, params) then
						seen[fkey(jx, jz, k2)] = true
						table.insert(queue, { jx, jz, k2 })
					end
				end
			end
		end
		if head % 400 == 0 then
			task.wait()
		end
	end
	local covered = {}
	local up = RaycastParams.new()
	up.FilterType = Enum.RaycastFilterType.Exclude
	up.FilterDescendantsInstances = opts.exclude or {}
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for i, r in ipairs(reach) do
		minX, maxX = math.min(minX, r.x), math.max(maxX, r.x)
		minZ, maxZ = math.min(minZ, r.z), math.max(maxZ, r.z)
		local hit = workspace:Raycast(Vector3.new(r.x, r.y + 0.5, r.z), Vector3.new(0, 300, 0), up)
		if hit and opts.isTerrain(hit.Instance) and T.faceKind(hit.Instance, hit.Normal) ~= "top" then
			table.insert(covered, { x = r.x, y = r.y, z = r.z, above = hit.Instance, h = hit.Position.Y - r.y })
		end
		if i % 500 == 0 then
			task.wait()
		end
	end
	return { reach = reach, covered = covered, box = { minX, maxX, minZ, maxZ }, cells = count }
end

return T
