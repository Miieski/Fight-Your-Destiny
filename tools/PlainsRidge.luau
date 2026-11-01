--[[
	PlainsRidge (dev tool, Edit mode only): Round 8 part 1. The saddle that links the brown peak of Plains_1 and the
	green mountain of Plains_3, behind the cliffs of Plains_2 (x 1700-1848, z 160-460). Same look as the neighbours:
	BuildKit.tri facets, 0.3-stud slabs, height-banded tones. One invisible box blocks it (the facets do not collide).
	Rebuilds Plains_2.Decor.MountainRidge from scratch, same seed, same result.
		print(require(game.ServerStorage.DevTools.PlainsRidge:Clone()).build())
]]
local ServerStorage = game:GetService("ServerStorage")

local Kit = require(ServerStorage.DevTools.BuildKit:Clone()) :: any

local R = {}

local SEED = 8101
local THICKNESS = 0.3
local BASE_Y = -11
local EAST_X, EAST_Y = 1848, 30 -- buried in the cliffs of Plains_2
local LOW_GROUND_Z = 415
local Z0, DZ = 160, 30
-- crest height per column: under the green top (85) and well under the brown peak (144); both ends sink into the mountains
local CREST = { 78, 94, 84, 90, 78, 74, 79, 76, 85, 82, 72 }
-- rows west -> crest -> east: fraction along that side, fraction of the crest height
local WEST_ROWS = { { 0.25, 0.22 }, { 0.5, 0.5 }, { 0.75, 0.8 } }
local EAST_ROW = { 0.5, 0.8 }
local BLOCKER = { X0 = 1700, X1 = 1838, Y0 = -30, Y1 = 370, Z0 = 168, Z1 = 452 }

local GREENS = { "46ab3c", "4ab640", "4cbd42", "43a439", "47ae3d" }
local ROCKS = { "9b5f44", "8f573e", "9a5e43", "a16347", "8c553d", "925940" }
local CREST_ROCKS = { "7a4938", "784838", "7d4b3a" }
local FOOT_ROCKS = { "6a5750", "5f4f49", "705c54" }

local function pick(rng: Random, list: { string }): Color3
	return Color3.fromHex(list[rng:NextInteger(1, #list)])
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function westX(z: number): number
	return 1742 - 44 * math.sin(math.pi * math.clamp((z - Z0) / 300, 0, 1))
end

local function crestX(z: number): number
	return 1806 + 7 * math.sin(z / 31)
end

local function point(rng: Random, iz: number, row: number): Vector3
	local z = Z0 + (iz - 1) * DZ
	local inner = iz > 1 and iz < #CREST
	if inner then
		z += rng:NextNumber(-5, 5)
	end
	local h = CREST[iz]
	local w, c = westX(z), crestX(z)
	local x, y
	if row == 1 then
		x, y = w, BASE_Y
	elseif row <= 1 + #WEST_ROWS then
		local r = WEST_ROWS[row - 1]
		x, y = lerp(w, c, r[1]), h * r[2]
	elseif row == 2 + #WEST_ROWS then
		x, y = c, h
	elseif row == 3 + #WEST_ROWS then
		x, y = lerp(c, EAST_X, EAST_ROW[1]), h * EAST_ROW[2]
	else
		x, y = EAST_X, if z >= LOW_GROUND_Z then -3 else EAST_Y -- the cliffs stop before the green mountain: down to the ground there
	end
	if inner and row > 1 and row < 5 + #WEST_ROWS then
		x += rng:NextNumber(-4, 4)
		y += rng:NextNumber(-3, 3)
	end
	return Vector3.new(x, y, z)
end

local function colorOf(rng: Random, center: Vector3, crest: number): Color3
	local t = math.clamp((center.Z - Z0) / 300, 0, 1)
	local grassTop = 30 + 30 * t + rng:NextNumber(-6, 6)
	if center.Y < 12 and t < 0.32 + rng:NextNumber(-0.12, 0.12) then
		return pick(rng, FOOT_ROCKS)
	end
	if center.Y < grassTop then
		return pick(rng, GREENS)
	end
	if center.Y > crest - 12 and rng:NextNumber() < 0.5 then
		return pick(rng, CREST_ROCKS)
	end
	return pick(rng, ROCKS)
end

local function plantTrees(rng: Random, folder: Instance, facets: Instance): number
	local sources = workspace.Zones.Plains.Plains_3.Decor.BackdropTrees:GetChildren()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { facets }
	local planted = 0
	local spots: { { number } } = {}
	for z = 200, 420, 26 do
		table.insert(spots, { 1824 + rng:NextNumber(-3, 8), z + rng:NextNumber(-9, 9), rng:NextNumber(1, 1.3) }) -- seen from the beach
		table.insert(spots, { 1742 + rng:NextNumber(-10, 12), z + rng:NextNumber(-9, 9), rng:NextNumber(1.1, 1.6) }) -- outer slope
	end
	for _, spot in ipairs(spots) do
		local hit = workspace:Raycast(Vector3.new(spot[1], 300, spot[2]), Vector3.new(0, -400, 0), params)
		if hit then
			local tree = sources[rng:NextInteger(1, #sources)]:Clone()
			tree:ScaleTo(spot[3])
			local box, size = tree:GetBoundingBox()
			local above = tree:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
			tree:PivotTo(CFrame.new(hit.Position + Vector3.new(0, above - 1.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
			for _, d in ipairs(tree:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanCollide, d.CanTouch = false, false
				end
			end
			tree.Parent = folder
			planted += 1
		end
	end
	return planted
end

function R.build(): string
	local decor = workspace.Zones.Plains.Plains_2.Decor
	local old = decor:FindFirstChild("MountainRidge")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "MountainRidge"
	local facets = Instance.new("Folder")
	facets.Name = "Facets"
	facets.Parent = root
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = root
	local rng = Random.new(SEED)
	local rows = 4 + #WEST_ROWS
	local grid = {}
	for iz = 1, #CREST do
		grid[iz] = {}
		for row = 1, rows + 0 do
			grid[iz][row] = point(rng, iz, row)
		end
	end
	local function tri(a: Vector3, b: Vector3, c: Vector3, crest: number)
		Kit.tri(a, b, c, facets, colorOf(rng, (a + b + c) / 3, crest), THICKNESS, Enum.Material.SmoothPlastic)
	end
	for iz = 1, #CREST - 1 do
		local crest = (CREST[iz] + CREST[iz + 1]) / 2
		for row = 1, rows - 1 do
			local a, b, c, d = grid[iz][row], grid[iz][row + 1], grid[iz + 1][row], grid[iz + 1][row + 1]
			if (iz + row) % 2 == 0 then
				tri(a, b, c, crest)
				tri(b, d, c, crest)
			else
				tri(a, b, d, crest)
				tri(a, d, c, crest)
			end
		end
		task.wait()
	end
	for _, part in ipairs(facets:GetChildren()) do
		local wedge = part :: BasePart
		wedge.CanCollide, wedge.CanTouch = false, false
	end
	local blocker = Instance.new("Part")
	blocker.Name = "RidgeBlocker"
	blocker.Anchored = true
	blocker.Transparency = 1
	blocker.CastShadow = false
	blocker.CanTouch = false
	blocker.Size = Vector3.new(BLOCKER.X1 - BLOCKER.X0, BLOCKER.Y1 - BLOCKER.Y0, BLOCKER.Z1 - BLOCKER.Z0)
	blocker.Position = Vector3.new((BLOCKER.X0 + BLOCKER.X1) / 2, (BLOCKER.Y0 + BLOCKER.Y1) / 2, (BLOCKER.Z0 + BLOCKER.Z1) / 2)
	blocker.Parent = root
	root.Parent = decor
	local planted = plantTrees(rng, trees, facets)
	return `ridge: {#facets:GetChildren()} wedges, {planted} trees, 1 blocker`
end

return R
