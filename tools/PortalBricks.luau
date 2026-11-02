--[[
	PortalBricks (dev tool, Edit mode only), Round 9 part 12: the real bricks of a hub portal, for the assembly of
	Controllers/PortalController. The hub's portal frames are 9 unions, and a union cannot be split on a client, so this tool
	runs the frame's own recipe (PropsBatch2.portal_frame), keeps each stone BEFORE it is merged and stores them in
	ReplicatedStorage.Assets.PortalBricks.<MapPropId>. All 12 frames have the same geometry (same MergeHash); a zone differs
	only by the colour of Gem, Keystone and its field, which the client reads from the real frame.

	Set = a Folder of bricks, at the template origin (pivot = bottom centre, front = -Z). A brick = one flying BasePart, with
	its bundle (the parts that fly with it: arch mortar, the gem on its setting, the name plate in its wooden frame) as
	children. Attributes: Group ("Base" | "Pillar" | "Arch" | "Sign" | "Keystone"), From (the union it comes from), Glow (a gem)
	on the part; PivotY on the Folder (the frame's pivot under the centre of Portal_<Zone>).

	Usage (execute_luau, Edit):
		local P = require(game.ServerStorage.DevTools.PortalBricks:Clone())
		print(P.build())     -- (re)builds the set of portal_frame
		print(P.check())     -- the set against the 12 real frames, part by part
]]
local GeometryService = game:GetService("GeometryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PortalBricks = {}

local ID = "portal_frame"
local CORE_SLICES = 5 -- the mortar core of a pillar: one part 12.6 tall would stand there alone, so it comes in slices
local ZONES = { "Plains", "Desert", "Jungle", "Tundra", "Swamp", "Volcano", "Hell", "Heaven", "Dead", "Abyss", "Mechanical", "Void" }

local function ghost(part: BasePart)
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.CastShadow = true
	part:SetAttribute("MergeHash", nil)
end

local function brick(folder: Folder, part: BasePart, group: string, from: string): BasePart
	ghost(part)
	part.Name = "Brick"
	part:SetAttribute("Group", group)
	part:SetAttribute("From", from)
	part.Parent = folder
	return part
end

local function bundle(root: BasePart, part: BasePart)
	ghost(part)
	part.Name = "Bundle"
	part.Parent = root
end

-- one union of a list, each piece keeping its colour
local function union(list: { BasePart }): BasePart
	if #list == 1 then
		return list[1]
	end
	local first = list[1]
	local rest = table.move(list, 2, #list, 1, {})
	local out = GeometryService:UnionAsync(first, rest, { CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Automatic, SplitApart = false })
	local result = out[1] :: BasePart
	if result:IsA("PartOperation") then
		result.UsePartColor = false
	end
	for _, p in ipairs(list) do
		p:Destroy()
	end
	return result
end

function PortalBricks.build(): string
	local B2 = require(ServerStorage.DevTools.PropsBatch2:Clone()) :: any
	local captured: { [string]: { BasePart } } = {}
	B2.onMerge = function(name: string, pieces: { BasePart })
		local list = {}
		for _, p in ipairs(pieces) do
			table.insert(list, p:Clone())
		end
		captured[name] = list
	end
	local model = B2.portal_frame()
	B2.onMerge = nil
	-- the recipe still makes the frame that is in the game: same hash as the template
	local template = ServerStorage.MapProps:FindFirstChild(ID) :: Model
	local same, total = 0, 0
	for _, part in ipairs(model:GetChildren()) do
		local hash = part:GetAttribute("MergeHash")
		if hash then
			total += 1
			local real = template:FindFirstChild(part.Name)
			if real and real:GetAttribute("MergeHash") == hash then
				same += 1
			end
		end
	end
	assert(same == total, `recipe differs from the template: {same} / {total} unions`)

	local folder = Instance.new("Folder")
	folder.Name = ID
	for _, p in ipairs(captured.Steps) do
		brick(folder, p, "Base", "Steps")
	end
	for _, name in ipairs({ "PillarL", "PillarR" }) do
		for _, p in ipairs(captured[name]) do
			if p.Size.Y > 10 then
				local h = p.Size.Y / CORE_SLICES
				for i = 1, CORE_SLICES do
					local slice = p:Clone()
					slice.Size = Vector3.new(p.Size.X, h, p.Size.Z)
					slice.CFrame = p.CFrame * CFrame.new(0, (i - 0.5 - CORE_SLICES / 2) * h, 0)
					brick(folder, slice, "Pillar", name)
				end
				p:Destroy()
			else
				brick(folder, p, "Pillar", name)
			end
		end
	end
	-- the gems: per side, the setting carries its gem
	for _, side in ipairs({ -1, 1 }) do
		local settings, gems = {}, {}
		for _, p in ipairs(captured.GemSetting) do
			if math.sign(p.Position.X) == side then
				table.insert(settings, p)
			end
		end
		for _, p in ipairs(captured.Gem) do
			if math.sign(p.Position.X) == side then
				table.insert(gems, p)
			end
		end
		local root = brick(folder, union(settings), "Pillar", "GemSetting")
		local gem = union(gems)
		if gem:IsA("PartOperation") then
			gem.UsePartColor = true
		end
		gem.Material = Enum.Material.Neon
		gem.CastShadow = false
		bundle(root, gem)
		gem.CastShadow = false
		gem:SetAttribute("Glow", true)
		gem:SetAttribute("From", "Gem")
	end
	-- the arch: the voussoirs; each mortar piece flies with its nearest voussoir
	local roots = {}
	for _, p in ipairs(captured.Arch) do
		if p:IsA("PartOperation") then
			table.insert(roots, brick(folder, p, "Arch", "Arch"))
		end
	end
	for _, p in ipairs(captured.Arch) do
		if not p:IsA("PartOperation") then
			local best, dist = roots[1], math.huge
			for _, root in ipairs(roots) do
				local d = (root.Position - p.Position).Magnitude
				if d < dist then
					best, dist = root, d
				end
			end
			bundle(best, p)
			p:SetAttribute("From", "Arch")
		end
	end
	-- the sign, whole: the wooden frame carries the plate (the client gives it the zone's NameGui)
	local signFrame = (model:FindFirstChild("NamePlateFrame") :: BasePart):Clone()
	brick(folder, signFrame, "Sign", "NamePlateFrame")
	local plate = (model:FindFirstChild("NamePlate") :: BasePart):Clone()
	bundle(signFrame, plate)
	plate.Name = "NamePlate"
	plate:SetAttribute("From", "NamePlate")
	-- the keystone last
	brick(folder, (model:FindFirstChild("Keystone") :: BasePart):Clone(), "Keystone", "Keystone")
	model:Destroy()

	local frame = workspace.Hub.Decor.PortalFrames.PortalFrame_Plains
	local portal = workspace.Hub.Portals.Portal_Plains
	folder:SetAttribute("PivotY", portal.CFrame:ToObjectSpace(frame:GetPivot()).Y)
	local assets = ReplicatedStorage.Assets
	local sets = assets:FindFirstChild("PortalBricks")
	if not sets then
		sets = Instance.new("Folder")
		sets.Name = "PortalBricks"
		sets.Parent = assets
	end
	local old = sets:FindFirstChild(ID)
	if old then
		old:Destroy()
	end
	folder.Parent = sets
	for i, stone in ipairs(folder:GetChildren()) do
		stone:SetAttribute("BrickId", i) -- DevTools.PortalRuins names them: a ruin holds some of them, by this id
	end
	local bricks, parts = #folder:GetChildren(), 0
	for _, item in ipairs(folder:GetDescendants()) do
		if item:IsA("BasePart") then
			parts += 1
		end
	end
	return `{ID}: {bricks} bricks, {parts} parts, hash {same} / {total} unions`
end

local function bounds(parts: { BasePart }, origin: CFrame): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, Vector3.one * -math.huge
	for _, part in ipairs(parts) do
		local half, box = part.ExtentsSize / 2, part.ExtentsCFrame -- a union's CFrame is not its centre
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local p = origin:PointToObjectSpace(box:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)))
					lo, hi = lo:Min(p), hi:Max(p)
				end
			end
		end
	end
	return lo, hi
end

-- For each zone: the pivot under its portal, and the box of each union against the box of its bricks.
function PortalBricks.check(): string
	local set = ReplicatedStorage.Assets.PortalBricks[ID]
	local pivotY = set:GetAttribute("PivotY") :: number
	local byFrom: { [string]: { BasePart } } = {}
	for _, item in ipairs(set:GetDescendants()) do
		if item:IsA("BasePart") then
			local from = item:GetAttribute("From") :: string
			byFrom[from] = byFrom[from] or {}
			table.insert(byFrom[from], item)
		end
	end
	local lines, good = {}, 0
	for _, zone in ipairs(ZONES) do
		local frame = workspace.Hub.Decor.PortalFrames:FindFirstChild("PortalFrame_" .. zone) :: Model
		local portal = workspace.Hub.Portals:FindFirstChild("Portal_" .. zone) :: BasePart
		local origin = portal.CFrame * CFrame.new(0, pivotY, 0)
		local off = (origin.Position - frame:GetPivot().Position).Magnitude
		local worst, name = 0, ""
		for from, parts in pairs(byFrom) do
			local real = frame:FindFirstChild(from) :: BasePart
			local lo, hi = bounds(parts, CFrame.identity)
			local rlo, rhi = bounds({ real }, origin)
			local d = math.max((lo - rlo).Magnitude, (hi - rhi).Magnitude)
			if d > worst then
				worst, name = d, from
			end
		end
		if off < 0.01 and worst < 1.1 then -- the box of a turned stone sticks out of the arch's by up to 1.0
			good += 1
		end
		table.insert(lines, string.format("%s pivot off %.3f, worst box %.3f (%s)", zone, off, worst, name))
	end
	return `{good} / {#ZONES} OK\n` .. table.concat(lines, "\n")
end

return PortalBricks
