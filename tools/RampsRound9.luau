--[[
	RampsRound9 (dev tool, Edit mode only) - owner prompt "ROUND 9" part 11: the 4 ice ramps of Tundra_3 (image 18).
	Source of truth: tools/RampsRound9.luau (= ServerStorage.DevTools.RampsRound9). Template: FloorsRound8 F.tundra_ice_ramp. Recipe: docs/prop_texture_guide.md "Ice ramps".

		local R = require(game.ServerStorage.DevTools.RampsRound9:Clone())
		print(R.colliders())  -- position, size, rotation, CanCollide of Ramp and RampSide: compare before and after
		print(R.apply())      -- one tundra_ice_ramp on each Ramp, in Decor.IceRamps; Ramp and RampSide stay, Transparency 1; frost_slabs on the terrace wall

	A texture never goes on a wedge here: the slope is a flat Part laid on it, so the tile keeps its true length. Same result each time.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Ground = require(ReplicatedStorage.GameSystem.Config.PropTextures:Clone()).Ground

local R = {}

local function ground(): any
	return (workspace.Zones :: any).Tundra.Tundra_3.Decor
end

function R.colliders(): string
	local list = {}
	for _, p in ipairs(ground().Ground:GetChildren()) do
		if p.Name == "Ramp" or p.Name == "RampSide" then
			local x, y, z = p.CFrame:ToOrientation()
			table.insert(list, string.format("%s %.2f,%.2f,%.2f %.2f,%.2f,%.2f %.0f,%.0f,%.0f %s %s", p.Name, p.Position.X, p.Position.Y, p.Position.Z, p.Size.X, p.Size.Y, p.Size.Z, math.deg(x), math.deg(y), math.deg(z), tostring(p.CanCollide), tostring(p.CanQuery)))
		end
	end
	table.sort(list)
	return table.concat(list, "\n")
end

function R.apply(): string
	local d = ground()
	local old = d:FindFirstChild("IceRamps")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "IceRamps"
	folder.Parent = d
	local ramps, sides = 0, 0
	for _, p in ipairs(d.Ground:GetChildren()) do
		if p.Name == "Ramp" then
			local m = (ServerStorage.MapProps :: any).tundra_ice_ramp:Clone() :: Model
			local variants = m:FindFirstChild("_Variants")
			if variants then
				variants:Destroy()
			end
			-- the wedge's high side is its local +Z, the template's too
			m:PivotTo(p.CFrame)
			m:SetAttribute("MapPropId", "tundra_ice_ramp")
			m:SetAttribute("Zone", "Tundra")
			CollectionService:AddTag(m, "MapProp")
			m.Parent = folder
			p.Transparency = 1
			ramps += 1
		elseif p.Name == "RampSide" then
			p.Transparency = 1
			sides += 1
		end
	end
	local body = d.Ground.T2Body
	for _, t in ipairs(body:GetChildren()) do
		if t.Name == "WallTex" then
			t:Destroy()
		end
	end
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local t = Instance.new("Texture")
		t.Name = "WallTex"
		t.Texture = Ground.frost_slabs.Id
		t.Face = face
		t.StudsPerTileU, t.StudsPerTileV = Ground.frost_slabs.Tile, Ground.frost_slabs.Tile
		t.Color3 = Color3.fromHex("9cb4dc")
		t.Transparency = 0.2
		t.Parent = body
	end
	return `{ramps} ramps, {sides} rails hidden, wall textured`
end

return R
