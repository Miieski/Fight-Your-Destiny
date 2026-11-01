--[[
	EdgesRound9 (dev tool, Edit mode only) - owner prompt "ROUND 9" part 1: every raised edge uses the texture family and palette of the ground it belongs to.
	The curbs are templates (FloorsRound8 BUILD: *_ground_curb, palette, foot, EdgeTex on the union). This tool does the rest: E.curbs() puts the beach and canyon variants on their
	sub-zones, E.zone(name) skins the loose edge parts of a zone with Textures named EdgeTex (top + sides of a block, the end of a cylinder), tinted with the part's own colour, E.banks()
	does the grass banks of Plains_1 and Plains_3 and the fallen logs of the forest. Nothing moves, no collider changes. Idempotent. Recipes: docs/prop_texture_guide.md "Raised edges".
		local E = require(game.ServerStorage.DevTools.EdgesRound9:Clone())
		print(E.curbs()) print(E.zone("Jungle")) print(E.banks())
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Textures = require(ReplicatedStorage.GameSystem.Config.PropTextures:Clone())
local Ground = Textures.Ground

local E = {}

local NAME = "EdgeTex"
local FACES = { Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Front, Enum.NormalId.Back }

local function add(part, face, id, tile, tint, alpha)
	local t = Instance.new("Texture")
	t.Name = NAME
	t.Texture = id
	t.Face = face
	t.StudsPerTileU, t.StudsPerTileV = tile, tile
	t.OffsetStudsU = math.floor(part.Position.X) % tile
	t.OffsetStudsV = math.floor(part.Position.Z) % tile
	t.Color3 = tint
	t.Transparency = alpha
	t.Parent = part
end

local function clear(part)
	for _, old in ipairs(part:GetChildren()) do
		if old.Name == NAME then
			old:Destroy()
		end
	end
end

-- the face looking up; a block keeps its sides too when it stands high enough to show them
local function skin(part, id, tile, alpha, lift)
	clear(part)
	local n = 0
	local cylinder = part:IsA("Part") and part.Shape == Enum.PartType.Cylinder
	for _, face in ipairs(FACES) do
		local up = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)).Y
		if up > 0.7 or (not cylinder and math.abs(up) < 0.3 and part.Size.Y >= 0.25) then
			add(part, face, id, tile, part.Color:Lerp(Color3.new(1, 1, 1), lift or 0), alpha)
			n += 1
		end
	end
	return n
end

local function sub(zone, id)
	return workspace.Zones[zone][id]
end

local dirt = { id = Ground.dirt.Id, tile = Ground.dirt.Tile, alpha = 0.3 }
local PLANS = {
	Desert = { { root = function() return sub("Desert", "Desert_3").Decor.Ruins end, names = { "Ledge", "LedgeSand" }, id = Ground.sand.Id, tile = Ground.sand.Tile, alpha = 0.3 } },
	Jungle = { { root = function() return sub("Jungle", "Jungle_3").Decor.Plaza end, names = { "PlazaBorder", "Slab" }, id = Ground.mossy_stone.Id, tile = Ground.mossy_stone.Tile, alpha = 0.25 } },
	Tundra = { { root = function() return sub("Tundra", "Tundra_3").Decor.Ground end, names = { "SnowLip" }, id = Ground.snow.Id, tile = Ground.snow.Tile, alpha = 0.2 } },
	Swamp = {
		{ root = function() return sub("Swamp", "Swamp_1").Decor.Ground end, names = { "Shore", "PathShore", "Island", "Path" }, id = dirt.id, tile = dirt.tile, alpha = dirt.alpha },
		{ root = function() return sub("Swamp", "Swamp_2").Decor.Ground end, names = { "Path", "Clearing" }, id = dirt.id, tile = dirt.tile, alpha = dirt.alpha },
		{ root = function() return sub("Swamp", "Swamp_3").Decor.Ground end, names = { "Path", "Square" }, id = dirt.id, tile = dirt.tile, alpha = dirt.alpha },
		{ root = function() return sub("Swamp", "Swamp_4").Decor.Pools end, names = { "PoolRim" }, id = Textures.BossRoomBrick.swamp_wall_stone, tile = 8, alpha = 0.2 },
	},
	Caves = { { root = function() return sub("Plains", "Plains_4").Decor.Mine end, names = { "Footings" }, id = Ground.cave_rock.Id, tile = Ground.cave_rock.Tile, alpha = 0.35, lift = 0.75 } },
	BossRooms = {
		{ root = function() return ServerStorage.BossArenas.Plains end, names = { "Dais", "DaisStep", "PlatformRim", "Floor" }, id = Ground.cave_rock.Id, tile = Ground.cave_rock.Tile, alpha = 0.35, lift = 0.6 },
		{ root = function() return ServerStorage.BossArenas.Tundra end, names = { "DaisStep", "Step" }, id = Ground.frost_slabs.Id, tile = Ground.frost_slabs.Tile, alpha = 0.3 },
		{ root = function() return ServerStorage.BossArenas.Desert end, names = { "MiniDais", "Plinth" }, id = Ground.slabs.Id, tile = Ground.slabs.Tile, alpha = 0.3 },
	},
}

function E.zone(name)
	local parts, textures = 0, 0
	for _, plan in ipairs(PLANS[name]) do
		local names = {}
		for _, n in ipairs(plan.names) do
			names[n] = true
		end
		for _, d in ipairs(plan.root():GetDescendants()) do
			if d:IsA("BasePart") and names[d.Name] and d.Transparency < 1 then
				parts += 1
				textures += skin(d, plan.id, plan.tile, plan.alpha, plan.lift)
			end
		end
		task.wait()
	end
	return name .. ": " .. parts .. " parts, " .. textures .. " textures"
end

-- a curb of another colour on a sub-zone: same place, same tags
local function swap(folder, from, to)
	local template = ServerStorage.MapProps[to]
	local n = 0
	for _, m in ipairs(folder:GetDescendants()) do
		if m:IsA("Model") and m:GetAttribute("MapPropId") == from then
			local new = template:Clone()
			local variants = new:FindFirstChild("_Variants")
			if variants then
				variants:Destroy()
			end
			new:PivotTo(m:GetPivot())
			new:SetAttribute("MapPropId", to)
			new:SetAttribute("Zone", m:GetAttribute("Zone"))
			CollectionService:AddTag(new, "MapProp")
			new.Parent = m.Parent
			m:Destroy()
			n += 1
		end
	end
	return n
end

function E.curbs()
	local beach = swap(sub("Plains", "Plains_2"), "plains_ground_curb", "beach_ground_curb")
	local canyon = swap(sub("Desert", "Desert_3"), "desert_ground_curb", "canyon_ground_curb")
	return "beach " .. beach .. ", canyon " .. canyon
end

-- the green banks take the grass of the ground (images 03, 04); grass and pebbles grow around the forest's fallen logs
function E.banks()
	local banks, total = 0, 0
	for _, id in ipairs({ "Plains_1", "Plains_3" }) do
		local hills = sub("Plains", id).Decor:FindFirstChild("Hills")
		for _, p in ipairs(hills and hills:GetDescendants() or {}) do
			if p:IsA("WedgePart") and p.Name == "Facet" then
				total += 1
				local y = p.CFrame.RightVector.Y
				if p.Color.G > p.Color.R * 1.3 and math.abs(y) > 0.45 then
					clear(p)
					add(p, if y > 0 then Enum.NormalId.Right else Enum.NormalId.Left, Ground.grass.Id, Ground.grass.Tile, p.Color:Lerp(Color3.new(1, 1, 1), 0.5), 0.3)
					banks += 1
				end
			end
		end
		task.wait()
	end
	local forest = sub("Plains", "Plains_3")
	local folder = forest.Decor:FindFirstChild("FloorDetail")
	for _, old in ipairs(folder:GetChildren()) do
		if old:GetAttribute("LogBase") then
			old:Destroy()
		end
	end
	local rng = Random.new(913)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { forest.Decor.Ground, forest.Decor.Hills }
	local placed = 0
	for _, m in ipairs(forest:GetDescendants()) do
		if m:IsA("Model") and m:GetAttribute("MapPropId") == "plains_prop_fallen_log_large" then
			local cf, size = m:GetBoundingBox()
			local long = if size.X > size.Z then cf.RightVector else cf.LookVector
			local half = math.max(size.X, size.Z) / 2
			local side = long:Cross(Vector3.yAxis)
			for i = 1, 9 do
				local across = (if i % 2 == 0 then 1 else -1) * (math.min(size.X, size.Z) / 2 + rng:NextNumber(0.1, 0.9))
				local pos = cf.Position + long * rng:NextNumber(-half, half) + side * across
				local hit = workspace:Raycast(Vector3.new(pos.X, 40, pos.Z), Vector3.new(0, -60, 0), params)
				if hit then
					local id = if i % 3 == 0 then "plains_ground_pebbles" else "plains_ground_tuft"
					local copy = ServerStorage.MapProps[id]:Clone()
					local variants = copy:FindFirstChild("_Variants")
					if variants then
						variants:Destroy()
					end
					copy:PivotTo(CFrame.new(hit.Position) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
					copy:SetAttribute("MapPropId", id)
					copy:SetAttribute("Zone", "Plains")
					copy:SetAttribute("LogBase", true)
					CollectionService:AddTag(copy, "MapProp")
					copy.Parent = folder
					placed += 1
				end
			end
		end
	end
	return "banks " .. banks .. " / " .. total .. " facets, " .. placed .. " tufts and pebbles at the log bases"
end

return E
