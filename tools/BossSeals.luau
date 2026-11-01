--[[
	BossSeals (dev tool, Edit mode only) - owner prompt "ROUND 9" part 5: the flat circles of the boss rooms become carved seals.
	Source of truth: tools/BossSeals.luau (= ServerStorage.DevTools.BossSeals). Images: tools/make_boss_seals.py, ids in Config/PropTextures.BossSeal. Recipe: docs/prop_texture_guide.md "Boss seals".

		local S = require(game.ServerStorage.DevTools.BossSeals:Clone())
		print(S.apply("Desert"))     -- or S.all()
		print(S.peek("Desert"))      -- a copy of the room in workspace for screen_capture; S.peek() takes it away

	These circles are decoration: no script names them, the boss stands on BossSpawn, not on them; telegraphs are VFX of their own. Size and centre are kept anyway.
	The old flat parts stay in the room (names, positions), Transparency 1. A seal is one flat part with no collision, a Decal on top, 0.02 over the top of what it replaces.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Textures = require(ReplicatedStorage.GameSystem.Config.PropTextures:Clone())
local Images, Ground = Textures.BossSeal, Textures.Ground

local S = {}
local NAME = "FloorSeal"

-- which parts each seal replaces; the seal takes their centre and their outer size
local PLAN: { [string]: { { key: string, wide: number?, parts: (p: BasePart) -> boolean } } } = {
	Desert = { { key = "desert", parts = function(p) return p.Name == "FloorDisc" or p.Name == "FloorRing" or p.Name == "FloorSun" end } },
	Tundra = {
		{ key = "ice_ring", parts = function(p) return p.Name == "Ring" and p.Size.Y > 100 end },
		{ key = "ice", parts = function(p) return (p.Name == "Ring" and p.Size.Y < 100) or p.Name == "Snowflake" end },
	},
	Jungle = {
		{ key = "jungle_ring", parts = function(p) return p.Name == "FloorRing" end },
		{ key = "jungle", wide = 30, parts = function(p) return p.Name == "FloorCenter" end },
	},
	Volcano = { { key = "volcano", parts = function(p) return p.Name == "FloorRing" and p.Size.Y < 100 end } },
	Abyss = { { key = "abyss", parts = function(p) return p.Name == "Mosaic" and p.Size.Y < 100 end } },
	Mechanical = { { key = "mechanical", parts = function(p) return p.Name == "CenterPlate" end } },
}

local function reach(p: BasePart): (number, number)
	-- half width on the floor plane, top of the part
	local cf, size = p.CFrame, p.Size
	local x = math.abs(cf.RightVector.X) * size.X + math.abs(cf.UpVector.X) * size.Y + math.abs(cf.LookVector.X) * size.Z
	local y = math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z
	local z = math.abs(cf.RightVector.Z) * size.X + math.abs(cf.UpVector.Z) * size.Y + math.abs(cf.LookVector.Z) * size.Z
	return math.max(x, z) / 2, p.Position.Y + y / 2
end

function S.apply(name: string): string
	local room = ServerStorage.BossArenas[name]
	for _, d in ipairs(room:GetDescendants()) do
		if d.Name == NAME then
			d:Destroy()
		end
	end
	local out = {}
	for _, plan in ipairs(PLAN[name]) do
		local parts = {}
		for _, d in ipairs(room:GetDescendants()) do
			if d:IsA("BasePart") and plan.parts(d) then
				table.insert(parts, d)
			end
		end
		-- the centre of a ring of blocks: the middle of its box
		local low, high = Vector3.one * 1e9, -Vector3.one * 1e9
		local top = -1e9
		for _, p in ipairs(parts) do
			local half, t = reach(p)
			local at = Vector3.new(half, 0, half)
			low, high = low:Min(p.Position - at), high:Max(p.Position + at)
			top = math.max(top, t)
		end
		local mid = (low + high) / 2
		local d = plan.wide or math.max(high.X - low.X, high.Z - low.Z)
		local seal = Instance.new("Part")
		seal.Name = NAME
		seal.Size = Vector3.new(d, 0.04, d)
		seal.CFrame = CFrame.new(mid.X, top + 0.02, mid.Z)
		seal.Anchored = true
		seal.Transparency = 1
		seal.CanCollide, seal.CanTouch, seal.CanQuery, seal.CastShadow = false, false, false, false
		seal.TopSurface, seal.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		local decal = Instance.new("Decal")
		decal.Name = "Seal"
		decal.Texture = Images[plan.key]
		decal.Face = Enum.NormalId.Top
		decal.Parent = seal
		if plan.key == "ice" then
			-- a Decal cannot glow: a soft pale light over the frost lines
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(214, 240, 255)
			light.Range, light.Brightness, light.Shadows = 26, 0.7, false
			light.Parent = seal
		end
		seal.Parent = parts[1].Parent
		for _, p in ipairs(parts) do
			p.Transparency = 1
			p.CastShadow = false
		end
		table.insert(out, `{plan.key}: {#parts} parts hidden, seal {math.round(d)} wide at y {string.format("%.2f", top + 0.02)}`)
	end
	return name .. ": " .. table.concat(out, "; ")
end

-- the ice room's floor was a bare colour: the frosted slabs of the tundra, so the seal sits on stone
function S.tundraFloor(): string
	local floor = ServerStorage.BossArenas.Tundra.Floor
	local old = floor:FindFirstChild("FloorTex")
	if old then
		old:Destroy()
	end
	local info = Ground.frost_slabs
	local t = Instance.new("Texture")
	t.Name = "FloorTex"
	t.Texture = info.Id
	for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
		if floor.CFrame:VectorToWorldSpace(Vector3.FromNormalId(face)).Y > 0.7 then
			t.Face = face
		end
	end
	t.StudsPerTileU, t.StudsPerTileV = info.Tile, info.Tile
	t.Parent = floor
	return "tundra floor: " .. t.Face.Name
end

function S.all(): string
	local out = {}
	for name in pairs(PLAN) do
		table.insert(out, S.apply(name))
	end
	return table.concat(out, "\n")
end

function S.peek(name: string?): string
	local old = workspace:FindFirstChild("_ArenaPeek")
	if old then
		old:Destroy()
	end
	if name then
		local copy = ServerStorage.BossArenas[name]:Clone()
		copy.Name = "_ArenaPeek"
		copy.Parent = workspace
		return "peek " .. name
	end
	return "peek off"
end

return S
