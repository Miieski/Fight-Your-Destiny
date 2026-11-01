--[[
	HoleAudit (dev tool, Edit mode only) - owner prompt "ROUND 9" part 4: finds where a player can see out of the map.
	Source of truth: tools/HoleAudit.luau (= ServerStorage.DevTools.HoleAudit).

		local H = require(game.ServerStorage.DevTools.HoleAudit:Clone())
		_G.R = nil task.spawn(function() _G.R = H.zone("Plains_3") end)   -- text report, poll _G.R
		H.zone("Hub")

	1. Flood fill on a grid from the sub-zone's Entrance (or a start you give): where a character can walk, by rays that respect CanCollide.
	2. From each border cell, rays outwards that ignore what is invisible:
		eye   at 3 and 9 studs over the ground: "void" when nothing is hit in 400 studs, "through" when the first thing seen is more than 45 studs away and outside the sub-zone
		cam   from 28 studs back and 20 up, looking down 18 degrees, like a zoomed out camera: "void" when nothing is hit
	3. Close results are merged in cells of 24 studs and sorted, biggest first. A through can be a real view (the sea, a far mountain): each one is looked at by hand.
	4. H.scan() lists the columns open at the side of each gate; H.fill() puts a rock in each one (Decor.MapFix.GateFill, rebuilt each time), H.scan() again must say 0.
	A part with CanQuery false stops no ray: the Swamp cliffs give false voids here.
]]
local ServerStorage = game:GetService("ServerStorage")

local H = {}

local STEP = 6
local LOOK = 400
local PAST = 45
-- a mountain seen far away is scenery, not a hole
local NATURAL = { Mountains = true, Backdrop = true, MountainShell = true, CorridorRidge = true, Cliffs = true, Closures = true, Hills = true, BackdropTrees = true, MountainRidge = true }
local RANK = { camvoid = 1, void = 2, through = 3 }
local DIRS = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }

local function solid(): RaycastParams
	local p = RaycastParams.new()
	p.RespectCanCollide = true
	return p
end

-- first thing the eye stops on: skips invisible parts
local function sight(origin: Vector3, dir: Vector3, ignore: { Instance }): (RaycastResult?, number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local from, walked = origin, 0
	for _ = 1, 8 do
		local hit = workspace:Raycast(from, dir * (LOOK - walked), params)
		if not hit then
			return nil, LOOK
		end
		walked += hit.Distance
		if hit.Instance.Transparency < 0.6 then
			return hit, walked
		end
		from = hit.Position + dir * 0.2
		walked += 0.2
	end
	return nil, walked
end

function H.flood(start: Vector3, box: { min: Vector3, max: Vector3 }): { { p: Vector3, d: Vector3 } }
	local params = solid()
	local function ground(x: number, y: number, z: number): Vector3?
		local hit = workspace:Raycast(Vector3.new(x, y + 7, z), Vector3.new(0, -16, 0), params)
		return hit and hit.Position
	end
	local first = ground(start.X, start.Y, start.Z)
	if not first then
		return {}
	end
	local seen: { [string]: boolean } = {}
	local border = {}
	local queue = { first }
	seen[math.round(first.X / STEP) .. "," .. math.round(first.Z / STEP)] = true
	local count = 0
	while #queue > 0 do
		local p = table.remove(queue)
		count += 1
		if count % 200 == 0 then
			task.wait()
		end
		for _, d in ipairs(DIRS) do
			local q = p + d * STEP
			local key = math.round(q.X / STEP) .. "," .. math.round(q.Z / STEP)
			if not seen[key] then
				local inside = q.X > box.min.X and q.X < box.max.X and q.Z > box.min.Z and q.Z < box.max.Z
				local wall = workspace:Raycast(p + Vector3.new(0, 3, 0), d * (STEP + 1), params)
				local g = ground(q.X, p.Y, q.Z)
				if inside and not wall and g and math.abs(g.Y - p.Y) < 4 then
					seen[key] = true
					table.insert(queue, g)
				else
					table.insert(border, { p = p, d = d })
				end
			end
		end
	end
	return border
end

local function report(name: string, border: { any }, gate: Vector3?, sub: Instance?, area: BasePart?): string
	local ignore = { workspace:FindFirstChild("_Staging") :: any }
	local cells: { [string]: any } = {}
	local function mark(kind: string, p: Vector3, d: Vector3, hit: RaycastResult?, dist: number)
		local key = kind .. "|" .. math.floor(p.X / 24) * 24 .. "," .. math.floor(p.Z / 24) * 24
		local c = cells[key]
		if not c then
			c = { kind = kind, n = 0, p = p, d = d, what = hit and hit.Instance:GetFullName() or "nothing", dist = dist }
			cells[key] = c
		end
		c.n += 1
	end
	local function outward(p: Vector3, dir: Vector3): boolean
		return area == nil or ((p - area.Position) * Vector3.new(1, 0, 1)):Dot(dir) > 0
	end
	local function within(q: Vector3): boolean
		return area == nil or (math.abs(q.X - area.Position.X) < area.Size.X / 2 + 6 and math.abs(q.Z - area.Position.Z) < area.Size.Z / 2 + 6)
	end
	for i, b in ipairs(border) do
		if i % 40 == 0 then
			task.wait()
		end
		local nearGate = gate and math.abs(b.p.X - gate.X) < 14 and math.abs(b.p.Z - gate.Z) < 30
		if not nearGate then
			for a = -1, 1 do
				local dir = (CFrame.Angles(0, a * 0.45, 0) * b.d).Unit
				for _, h in ipairs({ 3, 9 }) do
					local hit, dist = sight(b.p + Vector3.new(0, h, 0), dir, ignore)
					if not hit then
						mark("void", b.p, dir, nil, dist)
					elseif sub and dist > PAST and outward(b.p, dir) and hit.Position.Y < 15 and not NATURAL[hit.Instance.Parent.Name] and not (hit.Instance:IsDescendantOf(sub) and within(hit.Position)) then
						mark("through", b.p, dir, hit, dist)
					end
				end
			end
			local cam = b.p - b.d * 28 + Vector3.new(0, 20, 0)
			local hit = sight(cam, (b.d + Vector3.new(0, -0.32, 0)).Unit, ignore)
			if not hit then
				mark("camvoid", b.p, b.d, nil, 0)
			end
		end
	end
	local list = {}
	for _, c in pairs(cells) do
		table.insert(list, c)
	end
	table.sort(list, function(a, b)
		return if RANK[a.kind] ~= RANK[b.kind] then RANK[a.kind] < RANK[b.kind] else a.n > b.n
	end)
	local out = { `{name}: {#border} border sides, {#list} clusters` }
	for i = 1, math.min(14, #list) do
		local c = list[i]
		table.insert(out, string.format("  %s x%d at (%.0f,%.0f,%.0f) dir (%.1f,%.1f) %.0f -> %s", c.kind, c.n, c.p.X, c.p.Y, c.p.Z, c.d.X, c.d.Z, c.dist, string.sub(c.what, 11, 70)))
	end
	return table.concat(out, "\n")
end

function H.zone(id: string, start: Vector3?, half: number?): string
	local region = string.match(id, "^(%a+)_")
	if id == "Hub" then
		local c = start or Vector3.new(0, 3, 0)
		local h = half or 260
		local box = { min = c - Vector3.new(h, 0, h), max = c + Vector3.new(h, 0, h) }
		return report(id, H.flood(c, box))
	end
	local sub = workspace.Zones[region][id]
	local area = sub.Area
	local gate = sub:FindFirstChild("Gate")
	local box = { min = area.Position - area.Size / 2 - Vector3.new(30, 0, 60), max = area.Position + area.Size / 2 + Vector3.new(30, 0, 60) }
	local from = start or (sub.Entrance.Position + Vector3.new(0, 1, 0))
	return report(id, H.flood(from, box), gate and gate:GetPivot().Position, sub, area)
end

---------------------------------------------------------------------
-- GATES: the strip between 2 sub-zones, beside each gate. The first scan found every hole there (image 08): a rock with a thin foot, a gap in front of the ridge.
---------------------------------------------------------------------
local BIOME = {
	Plains = { "6e7484", "62687a" },
	Desert = { "b5533f", "a84a38" },
	Jungle = { "5f6a58", "566050" },
	Tundra = { "c8d8ec", "a8c0dc" },
	Swamp = { "3e4c4a", "34423f" },
}
local REGIONS = { "Plains", "Desert", "Jungle", "Tundra", "Swamp" }
local FAR = 96
-- seen on screen, missed by rays along z: the view comes in at an angle
local EXTRA = { Plains_3 = { -34, 34 } }
local CLEAR = 14 -- half of the doorway and its frame

-- x offsets from the gate where a ray along z crosses the strip without hitting anything, from either side, at knee, chest or head height
local function leaks(sub: Instance, gate: Instance): { [number]: boolean }
	local c = (gate :: Model):GetPivot().Position
	local ignore: { Instance } = {}
	for _, s in ipairs(sub.Parent:GetChildren()) do
		if s:FindFirstChild("Bounds") then
			table.insert(ignore, s.Bounds)
		end
	end
	local staging = workspace:FindFirstChild("_Staging")
	if staging then
		table.insert(ignore, staging)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local out = {}
	for xo = -FAR, FAR, 8 do
		if math.abs(xo) >= CLEAR then
			for _, side in ipairs({ 1, -1 }) do
				for _, y in ipairs({ 1.5, 5, 10 }) do
					local hit, dist = sight(Vector3.new(c.X + xo, c.Y + y, c.Z + side * 22), Vector3.new(0, 0, -side), ignore)
					if not hit or dist > 60 then
						out[xo] = true
					end
				end
			end
		end
	end
	return out
end

local function eachGate(fn: (sub: Instance, gate: Instance, region: string) -> ())
	for _, region in ipairs(REGIONS) do
		for _, sub in ipairs(workspace.Zones[region]:GetChildren()) do
			local gate = sub:FindFirstChild("Gate")
			if gate then
				fn(sub, gate, region)
			end
		end
		task.wait()
	end
end

-- the Swamp cliffs are not queryable: they count for a moment, or every ray would miss them
local function withCliffs(fn: () -> ())
	local flipped = {}
	for _, p in ipairs(workspace.Zones.Swamp:GetDescendants()) do
		if p:IsA("BasePart") and not p.CanQuery and p.Parent.Name == "Swamp_Cliff_A" then
			p.CanQuery = true
			table.insert(flipped, p)
		end
	end
	local ok, err = pcall(fn)
	for _, p in ipairs(flipped) do
		p.CanQuery = false
	end
	assert(ok, err)
end

function H.scan(): string
	local rows = {}
	withCliffs(function()
		eachGate(function(sub, gate)
			local found = leaks(sub, gate)
			local list = {}
			for xo in pairs(found) do
				table.insert(list, xo)
			end
			table.sort(list)
			table.insert(rows, sub.Name .. ": " .. #list .. " " .. table.concat(list, " "))
		end)
	end)
	return table.concat(rows, "\n")
end

-- one rock per open column, on the gate's line: nobody can walk there, the Bounds of both sub-zones stand in front. No collision.
function H.fill(): string
	local rock = ServerStorage.MapProps.hub_rock_m_a:FindFirstChildWhichIsA("MeshPart", true)
	local rng = Random.new(9401)
	local rows = {}
	withCliffs(function()
		eachGate(function(sub, gate, region)
			local mapFix = sub.Decor:FindFirstChild("MapFix")
			if not mapFix then
				mapFix = Instance.new("Folder")
				mapFix.Name = "MapFix"
				mapFix.Parent = sub.Decor
			end
			local old = mapFix:FindFirstChild("GateFill")
			if old then
				old:Destroy()
			end
			local folder = Instance.new("Folder")
			folder.Name = "GateFill"
			folder.Parent = mapFix
			local c = (gate :: Model):GetPivot().Position
			local tones = BIOME[region]
			local n = 0
			local columns = leaks(sub, gate)
			for _, xo in ipairs(EXTRA[sub.Name] or {}) do
				columns[xo] = true
			end
			for xo in pairs(columns) do
				local p = rock:Clone()
				p.Name = "FillRock"
				for _, child in ipairs(p:GetChildren()) do
					child:Destroy()
				end
				local near = math.abs(xo) < 26 -- a slimmer rock beside the doorway: it must stay out of the opening
				local x = if near then 22 * math.sign(xo) else xo
				local h = rng:NextNumber(15, 22)
				p.Size = if near then Vector3.new(13, h, 14) else Vector3.new(rng:NextNumber(15, 19), h, rng:NextNumber(16, 22))
				p.CFrame = CFrame.new(c.X + x, c.Y + h / 2 - 2, c.Z + rng:NextNumber(-2, 2)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
				p.Color = Color3.fromHex(tones[rng:NextInteger(1, #tones)])
				p.Anchored = true
				p.CanCollide, p.CanTouch = false, false
				p.Parent = folder
				n += 1
			end
			table.insert(rows, sub.Name .. " " .. n)
		end)
	end)
	return table.concat(rows, ", ")
end

-- Swamp_4 is a flat box seen from Swamp_3 with the camera up: 9 big rocks on its roof make a hill. They start inside the ceiling slab, nothing shows in the room.
function H.mounds(): string
	local mapFix = workspace.Zones.Swamp.Swamp_4.Decor.MapFix
	local old = mapFix:FindFirstChild("RoofHill")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "RoofHill"
	folder.Parent = mapFix
	local rock = ServerStorage.MapProps.hub_rock_m_a:FindFirstChildWhichIsA("MeshPart", true)
	local rng = Random.new(9402)
	for x = 9925, 10075, 75 do
		for z = 800, 950, 75 do
			local h = rng:NextNumber(42, 62)
			local p = rock:Clone()
			p.Name = "HillRock"
			for _, child in ipairs(p:GetChildren()) do
				child:Destroy()
			end
			p.Size = Vector3.new(rng:NextNumber(110, 130), h, rng:NextNumber(100, 120))
			p.CFrame = CFrame.new(x, 52 + h / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			p.Color = Color3.fromHex(if rng:NextNumber() < 0.5 then "3f5a44" else "4a5c50")
			p.Anchored = true
			p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
			p.Parent = folder
		end
	end
	return "roof hill: " .. #folder:GetChildren() .. " rocks"
end

return H
