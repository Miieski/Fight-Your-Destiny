-- DoorPockets (dev tool, Edit mode only) - Round 9 part 2. A stone wall each side that a sliding leaf goes into, on the 3 doors whose frame is too thin (2 parts per side, in the Barrier's space), and gate_mine's rocks moved off the pillars. Idempotent. Then Sync.run({ only = D.IDS }).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local LINES = require(ReplicatedStorage.GameSystem.Config.PropTextures:Clone()).Ids.stone_block_lines
local D = {}
local rgb = Color3.fromRGB
local SPEC = {
	gate_mine = { x0 = 15.4, x1 = 29.3, z0 = -3.0, z1 = 2.3, y0 = -8.5, y1 = 8.5, body = rgb(62, 60, 78), cap = rgb(94, 90, 108) },
	heaven_gate_4 = { x0 = 18.2, x1 = 31.6, z0 = -1.8, z1 = 1.8, y0 = -8.5, y1 = 8.5, body = rgb(242, 240, 234), cap = rgb(255, 208, 84) },
	dead_gate_4 = { x0 = 18.7, x1 = 32, z0 = -4.5, z1 = 1.4, y0 = -8.5, y1 = 8.5, body = rgb(120, 126, 138), cap = rgb(76, 80, 94) },
}
D.IDS = { "gate_mine", "heaven_gate_4", "dead_gate_4" }
local function block(parent, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
function D.build(id)
	local s = SPEC[id]
	local model = ServerStorage.MapProps[id]
	local barrier = model:FindFirstChild("Barrier")
	for _, old in ipairs(model:GetChildren()) do
		if old.Name == "DoorPocket" or old.Name == "DoorPocketCap" then old:Destroy() end
	end
	local f = barrier.CFrame
	local w, h, d = s.x1 - s.x0, s.y1 - s.y0, s.z1 - s.z0
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (s.x0 + s.x1) / 2
		local wall = block(model, "DoorPocket", Vector3.new(w, h, d), f * CFrame.new(x, (s.y0 + s.y1) / 2, (s.z0 + s.z1) / 2), s.body)
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local t = Instance.new("Texture")
			t.Texture = LINES
			t.StudsPerTileU, t.StudsPerTileV = 4, 4
			t.Face = face
			t.Parent = wall
		end
		local cap = block(model, "DoorPocketCap", Vector3.new(w + 0.1, 0.8, d + 0.7), f * CFrame.new(x, s.y1 + 0.3, (s.z0 + s.z1) / 2), s.cap)
		cap.CanCollide = true
	end
	if id == "gate_mine" then
		for _, rock in ipairs(model:GetChildren()) do
			if rock:IsA("MeshPart") and rock.Name == "RockFace" then
				local rel = f:PointToObjectSpace(rock.Position)
				if math.abs(rel.X) > 24 and math.abs(rel.X) < 26 then
					rock.CFrame = rock.CFrame + f.RightVector * math.sign(rel.X) * 4
				elseif math.abs(rel.X) > 29 and math.abs(rel.X) < 31 then
					rock.CFrame = rock.CFrame + f.RightVector * math.sign(rel.X) * 1.5
				end
			end
		end
	end
	return id .. ": 4 parts"
end
function D.run()
	local out = {}
	for _, id in ipairs(D.IDS) do table.insert(out, D.build(id)) end
	return table.concat(out, ", ")
end
return D
