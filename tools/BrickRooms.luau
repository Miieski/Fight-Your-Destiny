--[[
	BrickRooms (dev tool, Edit mode only) - owner prompt "ROUND 6" Task B: the brick texture on the inner faces of the
	Desert / Jungle sub-zone 4 interiors and their boss arenas. Texture only: a Texture per inner face of the existing
	walls, floors, ceilings, bands, beams, square column parts and steps (no new geometry; Size, CFrame, collisions,
	scripts and attributes untouched). Source of truth: tools/BrickRooms.luau (= ServerStorage.DevTools.BrickRooms).
	Recipe: docs/prop_texture_guide.md "G. Boss room brick"; ids: Config/PropTextures.luau -> BossRoomBrick.

	Usage (execute_luau, Edit):
		local R = require(game.ServerStorage.DevTools.BrickRooms:Clone())
		local snap = R.snapshot()                    -- every BasePart of the 4 rooms (Size, CFrame, collisions, attributes ...)
		print(R.apply("Desert4", { only = "WallN" })) -- one wall first (tile origin / frieze alignment check)
		print(R.apply("Desert4"))                    -- a room: "Desert4", "DesertArena", "Jungle4", "JungleArena"
		print(R.compare(snap))                       -- parts changed per room, 0 changes in Size / CFrame / ...
		print(R.clear("Desert4"))                    -- removes this tool's textures from a room (undo)

	Inner face: a face whose probe point (0.5 stud out of the face) lies inside one of the room's interior boxes and
	(walls only) whose normal points toward that box's centre, and that is not covered by another part of the room.
]]
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local R = {}

local rgb = Color3.fromRGB
local TAG_NAMES = { BrickTex = true, FriezeTex = true, MossTex = true, FloorTex = true }

local function ids(): any
	local mod = ReplicatedStorage.GameSystem.Config:FindFirstChild("PropTextures")
	assert(mod and mod:IsA("ModuleScript"), "Config PropTextures missing")
	local cfg = require(mod:Clone()) :: any
	local b = cfg.BossRoomBrick
	assert(b, "PropTextures.BossRoomBrick missing")
	return b
end

-- the 4 rooms: root, the folders whose parts may be textured, interior boxes, recipe
local function rooms(): any
	local D4 = workspace.Zones.Desert.Desert_4
	local J4 = workspace.Zones.Jungle.Jungle_4
	local DA = ServerStorage.BossArenas.Desert
	local JA = ServerStorage.BossArenas.Jungle
	local function box(x0: number, x1: number, y0: number, y1: number, z0: number, z1: number): any
		return { lo = Vector3.new(x0, y0, z0), hi = Vector3.new(x1, y1, z1), c = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2) }
	end
	return {
		Desert4 = {
			root = D4,
			sources = { D4.Decor.Structure, D4.Decor.Columns, D4.Decor.FloorInlay },
			boxes = { box(3910, 4090, -0.5, 52, 789.5, 940.5), box(3984.5, 4015.5, -0.5, 24.5, 726, 790) },
			zone = "desert",
		},
		DesertArena = {
			root = DA,
			sources = { DA.Structure, DA },
			boxes = { box(3924.5, 4075.5, -0.5, 64.5, -675.5, -524.5), box(3968.5, 4031.5, -0.5, 64.5, -525, -479.5), box(3878.5, 3925, -0.5, 30.5, -620.5, -579.5), box(4075, 4121.5, -0.5, 30.5, -620.5, -579.5) },
			octagon = true,
			zone = "desert",
		},
		Jungle4 = {
			root = J4,
			sources = { J4.Decor.Shell, J4.Decor.FloorDecor, J4.Decor.Props },
			boxes = { box(5910, 6090, -0.5, 48.5, 844.5, 990.5), box(5984.5, 6015.5, -0.5, 24.5, 716, 845) },
			zone = "jungle",
		},
		JungleArena = {
			root = JA,
			sources = { JA.Decor.Shell, JA.Decor.FloorDecor, JA.Decor.Props, JA },
			boxes = { box(5922, 6078, -0.5, 66.5, -678, -522), box(5875.5, 5926, -0.5, 40.5, -621, -579), box(6074, 6124.5, -0.5, 40.5, -621, -579) },
			octagon = true,
			zone = "jungle",
		},
	}
end
R.rooms = rooms

-- kinds by part name: wall (the faces toward the room), floor (top), ceiling (bottom), free (every open face), band
-- (a wall band: its room face, tinted from its own colour), frieze (desert: the blue / gold strip)
local KIND = {
	Wall = "wall", WallN = "wall", WallS = "wall", WallE = "wall", WallW = "wall", CorridorWall = "wall", Clerestory = "wall",
	ApseWall = "wall", AlcoveWall = "wall", HallWall = "wall", AlcoveBack = "wall", AlcoveSide = "wall", WallLintel = "wall",
	Floor = "floor", CorridorFloor = "floor", ApseFloor = "floor", AlcoveFloor = "floor", AlcoveGround = "floor", Aisle = "floor",
	TrapTile = "floortint",
	Ceiling = "ceiling", NaveCeiling = "ceiling", AisleCeiling = "ceiling", CorridorCeiling = "ceiling", AlcoveCeiling = "ceiling",
	Beam = "beam",
	BaseBand = "band", WallBand = "band", WallBase = "band", LintelTrim = "band",
	Frieze = "frieze",
	ColBase = "free", Dais = "step", DaisStep = "step", ThronePlatform = "step", ThroneStep = "step",
	Pillar = "free", PillarBase = "free", PillarBand = "free", PillarCapital = "free",
}
R.KIND = KIND

-- the brick image's average colour (for tints that keep a part's own tone relative to the wall)
local REF = { desert = rgb(157, 124, 83), jungle = rgb(100, 106, 98) }
local WALL, FLOOR, CEIL = rgb(255, 255, 255), rgb(208, 208, 208), rgb(184, 184, 184)

local function tintOf(c: Color3, ref: Color3, cap: number?): Color3
	local m = cap or 1
	return Color3.new(math.clamp(c.R / ref.R, 0.35, m), math.clamp(c.G / ref.G, 0.35, m), math.clamp(c.B / ref.B, 0.35, m))
end

local FACES = { Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Front, Enum.NormalId.Back }

local function faceInfo(p: BasePart, face: Enum.NormalId): (Vector3, Vector3, number, number)
	local lv = Vector3.FromNormalId(face)
	local n = p.CFrame:VectorToWorldSpace(lv)
	local h = math.abs(lv.X) * p.Size.X / 2 + math.abs(lv.Y) * p.Size.Y / 2 + math.abs(lv.Z) * p.Size.Z / 2
	local c = p.Position + n * h
	-- the face's height (along the part's Y) and its top edge in world Y (vertical faces)
	local fh = if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then 0 else p.Size.Y
	return n, c, fh, c.Y + fh / 2
end

local function inBox(b: any, p: Vector3): boolean
	return p.X >= b.lo.X and p.X <= b.hi.X and p.Y >= b.lo.Y and p.Y <= b.hi.Y and p.Z >= b.lo.Z and p.Z <= b.hi.Z
end

local function inPart(q: BasePart, p: Vector3): boolean
	local rel = q.CFrame:PointToObjectSpace(p)
	local s = q.Size / 2
	if q:IsA("Part") and q.Shape == Enum.PartType.Cylinder then
		return math.abs(rel.X) <= s.X and (rel.Y * rel.Y + rel.Z * rel.Z) <= s.Y * s.Y
	end
	return math.abs(rel.X) <= s.X and math.abs(rel.Y) <= s.Y and math.abs(rel.Z) <= s.Z
end

-- the parts of a room this tool may texture (named kinds, plain Parts, visible, not inside a MapProp model)
local function candidates(room: any): { BasePart }
	local out, seen = {}, {}
	for _, src in ipairs(room.sources) do
		local list = if src == room.root then src:GetChildren() else src:GetDescendants()
		for _, p in ipairs(list) do
			if p:IsA("Part") and KIND[p.Name] and not seen[p] and p.Transparency < 1 then
				local a, inProp = p.Parent, false
				while a and a ~= game do
					if a:HasTag("MapProp") or a:GetAttribute("MapPropId") then
						inProp = true
						break
					end
					a = a.Parent
				end
				if not inProp then
					seen[p] = true
					table.insert(out, p)
				end
			end
		end
	end
	return out
end
R.candidates = candidates

-- a face is covered when 90 % of a 5 x 5 grid of points on it lie inside (or on) other parts of the room, just in
-- front of or just behind the face (a wall end flush with another wall, a band face against a wall, a beam top under
-- the ceiling); a big floor with small things on it is never covered
local function coveredFace(p: BasePart, face: Enum.NormalId, n: Vector3, c: Vector3, blockers: { BasePart }): boolean
	local lv = Vector3.FromNormalId(face)
	local a1 = if math.abs(lv.X) > 0.5 then Vector3.yAxis else Vector3.xAxis
	local a2 = lv:Cross(a1)
	local h1 = math.abs(a1.X) * p.Size.X / 2 + math.abs(a1.Y) * p.Size.Y / 2 + math.abs(a1.Z) * p.Size.Z / 2
	local h2 = math.abs(a2.X) * p.Size.X / 2 + math.abs(a2.Y) * p.Size.Y / 2 + math.abs(a2.Z) * p.Size.Z / 2
	local w1, w2 = p.CFrame:VectorToWorldSpace(a1), p.CFrame:VectorToWorldSpace(a2)
	local total, hits = 0, 0
	for i = -2, 2 do
		for j = -2, 2 do
			local s = c + w1 * h1 * (i * 0.45) + w2 * h2 * (j * 0.45)
			total += 1
			for _, q in ipairs(blockers) do
				if q ~= p and q.Transparency < 1 and (inPart(q, s + n * 0.05) or inPart(q, s - n * 0.01)) then
					hits += 1
					break
				end
			end
		end
	end
	return hits >= total * 0.9
end

-- the faces to texture on part p of the room
local function innerFaces(room: any, p: BasePart, blockers: { BasePart }): { Enum.NormalId }
	local kind = KIND[p.Name]
	local out = {}
	local isCyl = p.Shape ~= Enum.PartType.Block
	if isCyl then
		return out -- (round parts keep their look: a Texture does not wrap a cylinder)
	end
	for _, face in ipairs(FACES) do
		local n, c = faceInfo(p, face)
		local ok = false
		if kind == "floor" or kind == "floortint" then
			ok = n.Y > 0.9
		elseif kind == "ceiling" then
			ok = n.Y < -0.9
		elseif kind == "wall" or kind == "band" or kind == "frieze" then
			ok = math.abs(n.Y) < 0.1
		else -- free, beam: every face but the bottom (beams: the bottom too)
			ok = n.Y > -0.9 or kind == "beam"
		end
		if ok then
			-- probes on a 5 x 5 grid over the face (a door jamb is only partly inside the room)
			local lv = Vector3.FromNormalId(face)
			local a1 = if math.abs(lv.X) > 0.5 then Vector3.yAxis else Vector3.xAxis
			local a2 = lv:Cross(a1)
			local h1 = math.abs(a1.X) * p.Size.X / 2 + math.abs(a1.Y) * p.Size.Y / 2 + math.abs(a1.Z) * p.Size.Z / 2
			local h2 = math.abs(a2.X) * p.Size.X / 2 + math.abs(a2.Y) * p.Size.Y / 2 + math.abs(a2.Z) * p.Size.Z / 2
			local w1, w2 = p.CFrame:VectorToWorldSpace(a1), p.CFrame:VectorToWorldSpace(a2)
			local probes = {}
			for i = -2, 2 do
				for j = -2, 2 do
					table.insert(probes, c + w1 * h1 * (i * 0.45) + w2 * h2 * (j * 0.45) + n * 0.5)
				end
			end
			local inside = false
			for _, b in ipairs(room.boxes) do
				local hitBox = false
				for _, probe in ipairs(probes) do
					if inBox(b, probe) then
						hitBox = true
						break
					end
				end
				if hitBox then
					if kind == "wall" or kind == "band" or kind == "frieze" then
						local toC = b.c - c
						if room.octagon and b == room.boxes[1] then
							toC = Vector3.new(b.c.X - c.X, 0, b.c.Z - c.Z)
						end
						if n:Dot(Vector3.new(toC.X, 0, toC.Z)) > 0 then
							inside = true
						end
					else
						inside = true
					end
				end
			end
			if inside and coveredFace(p, face, n, c, blockers) then
				inside = false
			end
			if inside then
				table.insert(out, face)
			end
		end
	end
	return out
end
R.innerFaces = innerFaces

local function newTexture(p: BasePart, face: Enum.NormalId, name: string, tex: string, u: number, v: number, color: Color3, offV: number?)
	local t = Instance.new("Texture")
	t.Name = name
	t.Texture = tex
	t.Face = face
	t.StudsPerTileU = u
	t.StudsPerTileV = v
	t.Color3 = color
	t.OffsetStudsV = offV or 0
	t.ZIndex = if name == "BrickTex" or name == "FloorTex" then 1 else 2 -- (a strip always draws over the bricks of its face)
	-- the top face of an unturned part: bricks on the world grid (U runs from the +X edge toward -X, V from the +Z
	-- edge toward -Z, checked with a probe part), so floor pieces that touch or overlap line up and never flicker
	if face == Enum.NormalId.Top and p.CFrame.Rotation:FuzzyEq(CFrame.identity, 1e-4) then
		t.OffsetStudsU = (-(p.Position.X + p.Size.X / 2)) % u
		t.OffsetStudsV = (-(p.Position.Z + p.Size.Z / 2)) % v
	end
	t.Parent = p
	return t
end

-- the OffsetStudsV that puts a strip's painted row (rowTop .. rowTop + 2 studs from the strip tile's top) at world Y
-- y0 .. y0 + 2 on a vertical face whose top edge is at topY (V grows downward from the face's top edge)
local function stripOffset(topY: number, rowY0: number, rowTop: number, sign: number): number
	local d = topY - (rowY0 + 2) -- the row's top, measured down from the face's top edge
	return ((sign * (rowTop - d)) % 32)
end
R.stripOffset = stripOffset

R.SIGN = 1 -- OffsetStudsV direction (checked on one wall with a screenshot: see NIGHT_LOG)

-- applies the textures to a room (opts.only = a part name to limit to; opts.dry = list only)
function R.apply(roomName: string, opts: any?): string
	opts = opts or {}
	local room = rooms()[roomName]
	assert(room, "unknown room " .. tostring(roomName))
	local I = ids()
	local isDesert = room.zone == "desert"
	-- the owner fix (prop_texture_guide G2): lighter desert bricks and frieze, a marble floor in the desert and
	-- flagstones in the jungle; the jungle walls keep their bricks
	local brick = if isDesert then I.desert_brick_light else I.jungle_brick
	local friezeStrip = I.desert_frieze_strip_light
	local floorTex = if isDesert then I.desert_marble_floor else I.jungle_flagstone_floor
	local floorTile = if isDesert then 28 else 24
	local floorColor = if isDesert then rgb(230, 230, 230) else WALL
	local ref = REF[room.zone]
	local function floorTint(p: BasePart): Color3
		if p.Name == "Aisle" then
			return tintOf(p.Color, ref, 0.82)
		elseif p.Name == "TrapTile" or KIND[p.Name] == "step" then
			-- (a floor tile or a step keeps its tone against the desert floor's sand colour)
			local base = rgb(226, 190, 132)
			local k = Color3.new(math.clamp(p.Color.R / base.R, 0.5, 1), math.clamp(p.Color.G / base.G, 0.5, 1), math.clamp(p.Color.B / base.B, 0.5, 1))
			return Color3.new(floorColor.R * k.R, floorColor.G * k.G, floorColor.B * k.B)
		end
		return floorColor
	end
	local function isFloorFace(p: BasePart, face: Enum.NormalId): boolean
		local kind = KIND[p.Name]
		return kind == "floor" or kind == "floortint" or (kind == "step" and face == Enum.NormalId.Top)
	end
	local parts = candidates(room)
	-- the frieze height (desert: the existing Frieze parts; the row on plain walls continues them) and the moss row
	local friezeY, nf = 0, 0
	for _, p in ipairs(parts) do
		if p.Name == "Frieze" then
			friezeY += p.Position.Y
			nf += 1
		end
	end
	friezeY = if nf > 0 then friezeY / nf else 30
	local friezeRow0 = math.floor(friezeY - 1 + 0.5) -- an even brick row near the existing frieze
	if friezeRow0 % 2 == 1 then
		friezeRow0 -= 1
	end
	local lines, nTex, nParts = {}, 0, 0
	for _, p in ipairs(parts) do
		if opts.only and p.Name ~= opts.only then
			continue
		end
		local kind = KIND[p.Name]
		local faces = innerFaces(room, p, parts)
		if #faces == 0 then
			continue
		end
		nParts += 1
		local faceNames = {}
		for _, face in ipairs(faces) do
			if opts.floorsOnly and not isFloorFace(p, face) then
				continue
			end
			table.insert(faceNames, face.Name)
			if opts.dry then
				continue
			end
			local _, c, fh, topY = faceInfo(p, face)
			if isFloorFace(p, face) then
				newTexture(p, face, "FloorTex", floorTex, floorTile, floorTile, floorTint(p))
				nTex += 1
			elseif kind == "wall" then
				newTexture(p, face, "BrickTex", brick, 8, 8, WALL)
				nTex += 1
				-- desert: the blue / gold row on plain walls tall enough to reach the frieze line (no Frieze part in front)
				if isDesert and topY >= friezeRow0 + 2 and c.Y - fh / 2 <= friezeRow0 then
					local covered = false
					for _, q in ipairs(parts) do
						if q.Name == "Frieze" and inPart(q, Vector3.new(c.X, friezeY, c.Z) + p.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)) * 0.3) then
							covered = true
						end
					end
					if not covered then
						newTexture(p, face, "FriezeTex", friezeStrip, 8, 32, WALL, stripOffset(topY, friezeRow0, 2, R.SIGN))
						nTex += 1
					end
				end
				-- jungle: the moss row near the bottom (y 4 .. 6, over the wall base) on walls that reach the floor
				if not isDesert and c.Y - fh / 2 <= 4 and topY >= 8 then
					newTexture(p, face, "MossTex", I.jungle_moss_strip, 8, 32, WALL, stripOffset(topY, 4, 28, R.SIGN))
					nTex += 1
				end
			elseif kind == "ceiling" or kind == "beam" then
				newTexture(p, face, "BrickTex", brick, 8, 8, CEIL)
				nTex += 1
			elseif kind == "band" or kind == "free" or kind == "step" then
				newTexture(p, face, "BrickTex", brick, 8, 8, tintOf(p.Color, ref))
				nTex += 1
			elseif kind == "frieze" then
				-- the blue / gold strip scaled so its painted row (2 of 32 studs) fills the band's height exactly; the
				-- gold band of a stacked pair shifted half a brick (running bond with the blue band above it)
				local k = p.Size.Y / 2
				local t = newTexture(p, face, "FriezeTex", friezeStrip, 8, 32 * k, WALL, (2 * k) % (32 * k))
				if p.Color.R > 0.8 then
					t.OffsetStudsU = 2
				end
				nTex += 1
			end
		end
		if #faceNames == 0 then
			nParts -= 1
			continue
		end
		table.insert(lines, string.format("  %s %s: %s", p:GetFullName():gsub("^Workspace%.Zones%.", ""):gsub("^ServerStorage%.", ""), kind, table.concat(faceNames, ",")))
	end
	table.sort(lines)
	return string.format("BrickRooms.apply %s%s: %d parts, %d textures (frieze row y %d)\n", roomName, if opts.dry then " (DRY)" else "", nParts, nTex, friezeRow0) .. table.concat(lines, "\n")
end

-- removes this tool's textures from a room (opts.floorsOnly: only the floor faces' textures)
function R.clear(roomName: string, opts: any?): string
	local room = rooms()[roomName]
	local n = 0
	for _, d in ipairs(room.root:GetDescendants()) do
		local onFloor = d:IsA("Texture") and d.Parent:IsA("BasePart") and d.Face == Enum.NormalId.Top and (KIND[d.Parent.Name] == "floor" or KIND[d.Parent.Name] == "floortint" or KIND[d.Parent.Name] == "step")
		if d:IsA("Texture") and TAG_NAMES[d.Name] and (not (opts and opts.floorsOnly) or onFloor) then
			d:Destroy()
			n += 1
		end
	end
	return `BrickRooms.clear {roomName}: {n} textures removed`
end

-- every BasePart of the 4 rooms: what must not change
function R.snapshot(): any
	local snap = {}
	for name, room in pairs(rooms()) do
		local t = {}
		for _, p in ipairs(room.root:GetDescendants()) do
			if p:IsA("BasePart") then
				local other = 0
				for _, c in ipairs(p:GetChildren()) do
					if not (c:IsA("Texture") and TAG_NAMES[c.Name]) then
						other += 1
					end
				end
				t[p] = {
					size = p.Size, cf = p.CFrame, cc = p.CanCollide, cq = p.CanQuery, ct = p.CanTouch, mat = p.Material,
					color = p.Color, tr = p.Transparency, attrs = HttpService:JSONEncode(p:GetAttributes()), kids = other,
				}
			end
		end
		local scripts = 0
		for _, d in ipairs(room.root:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				scripts += 1
			end
		end
		snap[name] = { parts = t, scripts = scripts }
	end
	return snap
end

function R.compare(snap: any): string
	local lines = {}
	for name, room in pairs(rooms()) do
		local s = snap[name]
		local changed, textured, nTex, scripts = 0, 0, 0, 0
		local diffs = {}
		local count = 0
		for p, v in pairs(s.parts) do
			count += 1
			if not p.Parent then
				table.insert(diffs, "missing " .. p.Name)
				continue
			end
			local other, tex = 0, 0
			for _, c in ipairs(p:GetChildren()) do
				if c:IsA("Texture") and TAG_NAMES[c.Name] then
					tex += 1
				else
					other += 1
				end
			end
			if tex > 0 then
				textured += 1
				nTex += tex
			end
			local d = {}
			if p.Size ~= v.size then table.insert(d, "Size") end
			if p.CFrame ~= v.cf then table.insert(d, "CFrame") end
			if p.CanCollide ~= v.cc or p.CanQuery ~= v.cq or p.CanTouch ~= v.ct then table.insert(d, "collision") end
			if p.Material ~= v.mat then table.insert(d, "Material") end
			if p.Color ~= v.color then table.insert(d, "Color") end
			if p.Transparency ~= v.tr then table.insert(d, "Transparency") end
			if HttpService:JSONEncode(p:GetAttributes()) ~= v.attrs then table.insert(d, "attributes") end
			if other ~= v.kids then table.insert(d, "children") end
			if #d > 0 then
				changed += 1
				table.insert(diffs, p:GetFullName() .. ": " .. table.concat(d, ","))
			end
		end
		for _, d in ipairs(room.root:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				scripts += 1
			end
		end
		table.insert(lines, string.format("%s: %d parts checked, %d textured (%d textures), %d changed in Size / CFrame / collision / Material / Color / Transparency / attributes / children, scripts %d -> %d", name, count, textured, nTex, changed, s.scripts, scripts))
		for i, d in ipairs(diffs) do
			if i > 10 then
				break
			end
			table.insert(lines, "  " .. d)
		end
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end

return R
