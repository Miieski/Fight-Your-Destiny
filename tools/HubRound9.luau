--[[
	HubRound9 (dev tool, Edit mode only) - owner prompt "ROUND 9" part 13: one stylized ground family for the Hub (image 21).
	Source of truth: tools/HubRound9.luau (= ServerStorage.DevTools.HubRound9). Images: tools/make_floor_textures.py --hub. Recipe: docs/prop_texture_guide.md "Hub ground".

		local H = require(game.ServerStorage.DevTools.HubRound9:Clone())
		print(H.skin())     -- plaza, inner floor, ring road, rings, rays, altar ring take the set
		print(H.lanes())    -- the 12 PortalLane parts wear out on the ring road instead of ending as a stub of path
		print(H.details())  -- soft moss and worn patches, a few pebbles
		print(H.counts())

	Each step rebuilds its own pieces, same seed, same result. After F.hub (FloorsRound8, which lays the old pavers) run all three again.
	Nothing moves, nothing changes its collision. A PortalLane stays a collider at Transparency 1, the look is a Decal on it.
	Patches: Part Transparency 1 + Decal, in Decor.FloorDetail, CanCollide / CanTouch / CanQuery / CastShadow false, no script.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Ground = require(ReplicatedStorage.GameSystem.Config.PropTextures:Clone()).Ground

local H = {}
local TEX, PATCH, LANE, FOLDER = "FloorTex", "GroundPatch", "LaneFade", "FloorDetail"
local TOP, RIGHT = Enum.NormalId.Top, Enum.NormalId.Right
local hex = Color3.fromHex
local TAU = 2 * math.pi

-- one family, told apart by tint and pattern. disc = the image once across the end of a cylinder (tile = diameter).
-- hollow = a full disc only 0.05-0.10 under the floor it borders: at a distance the depth buffer cannot part them and the dark disc wins (max zoom is 128), so the part goes
-- Transparency 1 (still a collider) and hub_rim draws the ring only
local RIM = "b8a488" -- rings, rays, borders: the same stone, a step darker
H.PLAN = {
	PlazaFloor = { key = "hub_slab", tint = "e8dcc4", macro = 0.6 },
	InnerFloor = { key = "hub_diamond", tint = "eeddc0", macro = 0.6 },
	RingRoad = { key = "hub_cobble", tint = "e0c6a0", macro = 0.6 },
	DockLane = { key = "hub_cobble", tint = "e0c6a0" },
	PlazaBorder = { key = "hub_rim", disc = true, tint = RIM, hollow = true },
	InnerRingDark = { key = "hub_rim", disc = true, tint = RIM, hollow = true },
	PlazaRay = { key = "hub_band", tint = RIM },
	AltarDais = { key = "hub_ring", disc = true, tint = "cdbb9c" }, -- darker than its 2 sisters: the altar's pink light washes it out
	AltarDaisBorder = { key = "hub_rim", disc = true, tint = RIM, hollow = true },
	CenterRing = { key = "hub_ring", disc = true, tint = "f0e4d0" },
	CenterRingDark = { key = "hub_ring", disc = true, tint = RIM },
	CenterGem = { key = "hub_ring", disc = true, tint = "8ea4e6" },
	FountainSquare = { key = "hub_ring", disc = true, tint = "f0e4d0" },
	FountainSquareBorder = { key = "hub_rim", disc = true, tint = RIM, hollow = true },
	WellPad = { key = "hub_ring", disc = true, tint = RIM },
}

local function plaza(): Instance
	return workspace.Hub.Decor.Plaza
end

local function isCylinder(p: BasePart): boolean
	return p:IsA("Part") and p.Shape == Enum.PartType.Cylinder
end

local function wipe(part: BasePart)
	for _, t in ipairs(part:GetChildren()) do
		if t.Name == TEX or t.Name == LANE then
			t:Destroy()
		end
	end
end

local function put(part: BasePart, face: Enum.NormalId, key: string, tile: number, o: any?)
	local t = Instance.new("Texture")
	t.Name = TEX
	t.Texture = Ground[key].Id
	t.Face = face
	t.StudsPerTileU, t.StudsPerTileV = tile, tile
	t.Color3 = if o and o.tint then hex(o.tint) else Color3.new(1, 1, 1)
	t.ZIndex = (o and o.z) or 1
	t.Transparency = (o and o.alpha) or 0
	t.Parent = part
end

function H.skin(): string
	local n, parts = 0, 0
	for _, p in ipairs(plaza():GetChildren()) do
		local plan = H.PLAN[p.Name]
		if plan and p:IsA("BasePart") then
			wipe(p)
			if plan.hollow then
				p.Transparency = 1
			end
			local face = if isCylinder(p) then RIGHT else TOP
			put(p, face, plan.key, if plan.disc then p.Size.Y else Ground[plan.key].Tile, plan)
			n += 1
			parts += 1
			if plan.macro then
				put(p, face, "macro_blotch", Ground.macro_blotch.Tile, { z = 2, alpha = plan.macro })
				n += 1
			end
		end
	end
	return `skin: {parts} parts, {n} textures`
end

function H.lanes(): string
	local n = 0
	for _, p in ipairs(plaza():GetChildren()) do
		if p.Name == "PortalLane" and p:IsA("BasePart") then
			wipe(p)
			p.Transparency = 1 -- still the same collider, the ring road shows through
			local d = Instance.new("Decal")
			d.Name = LANE
			d.Texture = Ground.hub_lane_fade.Id
			d.Face = TOP
			d.Color3 = hex("eadfc8")
			d.Parent = p
			n += 1
		end
	end
	return `lanes: {n}`
end

local function floorHit(pos: Vector3, names: { [string]: boolean }, params: RaycastParams): RaycastResult?
	local hit = workspace:Raycast(Vector3.new(pos.X, 40, pos.Z), Vector3.new(0, -60, 0), params)
	if hit and names[hit.Instance.Name] and hit.Instance.Parent == plaza() then
		return hit
	end
	return nil
end

local function patch(folder: Instance, key: string, y: number, pos: Vector3, angle: number, wide: number, deep: number, alpha: number?)
	local p = Instance.new("Part")
	p.Name = PATCH
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(wide, 0.05, deep)
	p.CFrame = CFrame.new(pos.X, y - 0.025, pos.Z) * CFrame.Angles(0, angle, 0)
	local d = Instance.new("Decal")
	d.Texture = Ground[key].Id
	d.Face = TOP
	d.Transparency = alpha or 0
	d.Parent = p
	p.Parent = folder
end

-- { image(s), floors, centre, r min, r max, count, wide min, wide max }
local PATCHES = {
	{ { "hub_moss_a", "hub_moss_b" }, { RingRoad = true }, Vector3.zero, 94, 98, 22, 4, 8 },
	{ { "hub_moss_a", "hub_moss_b" }, { RingRoad = true }, Vector3.zero, 81, 84, 8, 2.5, 4 },
	{ { "hub_moss_a", "hub_moss_b" }, { PlazaFloor = true }, Vector3.zero, 73, 76.5, 8, 2.5, 4 },
	{ { "hub_moss_a", "hub_moss_b" }, { AltarDais = true }, Vector3.new(0, 0, 40), 20, 24, 6, 1.6, 2.6 },
	{ { "hub_worn" }, { RingRoad = true }, Vector3.zero, 84, 96, 14, 6, 10 },
	{ { "hub_worn" }, { PlazaFloor = true }, Vector3.zero, 50, 74, 10, 6, 11 },
	{ { "hub_worn" }, { InnerFloor = true }, Vector3.zero, 18, 43, 5, 6, 10 },
}

function H.details(): string
	local folder = workspace.Hub.Decor:FindFirstChild(FOLDER) :: Instance
	for _, c in ipairs(folder:GetChildren()) do
		if c.Name == PATCH or c:GetAttribute("HubRound9") then
			c:Destroy()
		end
	end
	local rng = Random.new(1309)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, workspace.Hub.Bounds }
	local nMoss, nWorn = 0, 0
	for _, entry in ipairs(PATCHES) do
		local done, tries = 0, 0
		while done < entry[6] and tries < entry[6] * 20 do
			tries += 1
			local a, r = rng:NextNumber(0, TAU), rng:NextNumber(entry[4], entry[5])
			local pos = entry[3] + Vector3.new(math.cos(a), 0, math.sin(a)) * r
			local hit = floorHit(pos, entry[2], params)
			if hit then
				local wide = rng:NextNumber(entry[7], entry[8])
				local key = entry[1][rng:NextInteger(1, #entry[1])]
				patch(folder, key, hit.Position.Y + 0.02, pos, rng:NextNumber(0, TAU), wide, wide * rng:NextNumber(0.62, 0.85), if key == "hub_worn" then 0.25 else 0)
				done += 1
				if key == "hub_worn" then
					nWorn += 1
				else
					nMoss += 1
				end
			end
		end
		task.wait()
	end
	local pebbles, tries = 0, 0
	local template = ServerStorage.MapProps.hub_ground_pebbles
	while pebbles < 14 and tries < 200 do
		tries += 1
		local a, r = rng:NextNumber(0, TAU), rng:NextNumber(84, 97)
		local pos = Vector3.new(math.cos(a), 0, math.sin(a)) * r
		local hit = floorHit(pos, { RingRoad = true }, params)
		if hit then
			local copy = template:Clone()
			local variants = copy:FindFirstChild("_Variants")
			if variants then
				variants:Destroy()
			end
			copy:PivotTo(CFrame.new(hit.Position) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0))
			copy:SetAttribute("MapPropId", "hub_ground_pebbles")
			copy:SetAttribute("Zone", "Hub")
			copy:SetAttribute("SizeClass", "small")
			copy:SetAttribute("HubRound9", true)
			CollectionService:AddTag(copy, "MapProp")
			copy.Parent = folder
			pebbles += 1
		end
	end
	return `details: {nMoss} moss, {nWorn} worn, {pebbles} pebbles`
end

function H.counts(): string
	local tex, decals, patches = 0, 0, 0
	local folder = workspace.Hub.Decor:FindFirstChild(FOLDER) :: Instance
	for _, p in ipairs(plaza():GetChildren()) do
		for _, c in ipairs(p:GetChildren()) do
			if c.Name == TEX then
				tex += 1
			elseif c.Name == LANE then
				decals += 1
			end
		end
	end
	for _, c in ipairs(folder:GetChildren()) do
		if c.Name == PATCH then
			patches += 1
		end
	end
	return `plaza textures {tex}, lane decals {decals}, patches {patches}`
end

return H
