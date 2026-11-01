--[[
	GateSplit (dev tool, Edit mode only): Round 8 part 3. Double doors need two leaves, but a gate's Barrier pieces are
	unions across the whole door. For the gates whose type opens in two leaves (Config/DoorAnimations: Hinge, Slide,
	CrackSlide), each piece of the template's Barrier that crosses the door's centre is cut in two: <name>_L and <name>_R.
	Nothing changes in the look of a closed door. Idempotent.
		local G = require(game.ServerStorage.DevTools.GateSplit:Clone())
		print(G.run())   -- then Sync.run({ only = G.ids() })
]]
local GeometryService = game:GetService("GeometryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local G = {}

local MARGIN = 0.25 -- a piece reaching less than this over the centre stays whole
local CUT = 400
local OPTS = { CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Automatic, SplitApart = false }

local function doorTypes()
	local source = ReplicatedStorage.GameSystem.Config.DoorAnimations:Clone()
	return require(source) :: any
end

function G.ids(): { string }
	local D = doorTypes()
	local list = {}
	for id, name in pairs(D.Doors) do
		local mode = D.Types[name].Mode
		if mode == "Hinge" or mode == "Slide" or mode == "CrackSlide" then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

-- the part's extent along the door's width (local X of frame)
local function extent(part: BasePart, frame: CFrame): (number, number)
	local rel = frame:ToObjectSpace(part.ExtentsCFrame) -- a union's CFrame is not its centre
	local half = part.ExtentsSize / 2
	local reach = math.abs(rel.RightVector.X) * half.X + math.abs(rel.UpVector.X) * half.Y + math.abs(rel.LookVector.X) * half.Z
	return rel.Position.X - reach, rel.Position.X + reach
end

local function half(part: BasePart, frame: CFrame, sign: number, suffix: string): BasePart?
	local cutter = Instance.new("Part")
	cutter.Anchored = true
	cutter.Size = Vector3.new(CUT, CUT, CUT)
	cutter.CFrame = frame * CFrame.new(sign * CUT / 2, 0, 0)
	local ok, out = pcall(function()
		return GeometryService:SubtractAsync(part, { cutter }, OPTS)
	end)
	cutter:Destroy()
	if not ok or not out or not out[1] then
		return nil
	end
	local r = out[1] :: BasePart
	r.Name = part.Name .. suffix
	r.Anchored = true
	r.CanCollide, r.CanQuery, r.CanTouch, r.CastShadow = part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow
	r.Transparency, r.Material = part.Transparency, part.Material
	if r:IsA("PartOperation") then
		r.UsePartColor = if part:IsA("PartOperation") then part.UsePartColor else true
	end
	r.Color = part.Color
	local hash = part:GetAttribute("MergeHash")
	r:SetAttribute("MergeHash", tostring(hash or part.Name) .. suffix)
	return r
end

function G.split(id: string): string
	local template = ServerStorage.MapProps:FindFirstChild(id)
	local barrier = template and template:FindFirstChild("Barrier")
	if not (barrier and barrier:IsA("BasePart")) then
		return `{id}: no Barrier`
	end
	local frame = barrier.CFrame
	local cut, failed = 0, 0
	for _, d in ipairs(barrier:GetDescendants()) do
		if d:IsA("BasePart") and not d:IsA("MeshPart") and d:FindFirstAncestorOfClass("Model") == template then
			local lo, hi = extent(d, frame)
			if lo < -MARGIN and hi > MARGIN and not d:GetAttribute("Uncut") then
				local left, right = half(d, frame, 1, "_L"), half(d, frame, -1, "_R")
				if left and right then
					left.Parent, right.Parent = d.Parent, d.Parent
					for _, child in ipairs(d:GetChildren()) do
						child.Parent = left
					end
					d:Destroy()
					cut += 1
				else
					failed += 1
				end
			end
		end
	end
	return `{id}: {cut} cut, {failed} failed`
end

function G.run(): string
	local out = {}
	for _, id in ipairs(G.ids()) do
		table.insert(out, G.split(id))
		task.wait()
	end
	return table.concat(out, "\n")
end

return G
