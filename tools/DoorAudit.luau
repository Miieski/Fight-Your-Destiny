-- DoorAudit (dev tool, Edit mode only) - Round 9 part 2. require(ServerStorage.DevTools.DoorAudit:Clone()).run({ "Plains" }) lists every door: leaf, jamb, travel, what the open leaf overlaps.
-- Reads the world only (a probe part is created and destroyed). Overlaps use collision geometry: a union with a hull collider gives false hits, and the boss line's travel prints the whole door width. Results: docs/NIGHT_LOG.md.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DoorAudit = {}
local LEAF_NAMES = { "Door", "DoorL", "DoorR", "Leaf", "DoorLeaf", "DoorPanel", "DoorInner" }
local FLOOR = { Grass = true, Path = true, Sand = true, Ground = true, BasePlane = true, CaveFloor = true, CanyonFloor = true, Snow = true, Floor = true, Curb = true }
-- the real extents: a union's CFrame is not its centre (GateSplit keeps the original's pivot)
local function extents(frame, part, into)
	local box = into or { x0 = math.huge, x1 = -math.huge, y0 = math.huge, y1 = -math.huge, z0 = math.huge, z1 = -math.huge }
	local s = part.ExtentsSize / 2
	local cf = part.ExtentsCFrame
	for _, a in ipairs({ -1, 1 }) do
		for _, b in ipairs({ -1, 1 }) do
			for _, c in ipairs({ -1, 1 }) do
				local p = frame:PointToObjectSpace(cf:PointToWorldSpace(Vector3.new(s.X * a, s.Y * b, s.Z * c)))
				box.x0, box.x1 = math.min(box.x0, p.X), math.max(box.x1, p.X)
				box.y0, box.y1 = math.min(box.y0, p.Y), math.max(box.y1, p.Y)
				box.z0, box.z1 = math.min(box.z0, p.Z), math.max(box.z1, p.Z)
			end
		end
	end
	return box
end
local function owner(part)
	local a = part
	while a and a ~= workspace do
		local id = a:GetAttribute("MapPropId")
		if id then return tostring(id) .. ":" .. part.Name end
		a = a.Parent
	end
	return part.Name
end
local function touching(frame, box, skip)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Name = "AuditProbe"
	local y0 = box.y0 + 3.5
	p.Size = Vector3.new(box.x1 - box.x0, math.max(0.2, box.y1 - y0), box.z1 - box.z0)
	p.CFrame = frame * CFrame.new((box.x0 + box.x1) / 2, (y0 + box.y1) / 2, (box.z0 + box.z1) / 2)
	p.Parent = workspace
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	local found = {}
	for _, hit in ipairs(workspace:GetPartsInPart(p, params)) do
		if hit.Transparency < 1 and not FLOOR[hit.Name] then
			local name = owner(hit)
			found[name] = (found[name] or 0) + 1
		end
	end
	p:Destroy()
	return found
end
local function text(found)
	local list = {}
	for name, n in pairs(found) do table.insert(list, name .. " x" .. n) end
	table.sort(list)
	return if #list == 0 then "none" else table.concat(list, ", ")
end
-- the frame: rays through the leaf's band. inner / outer face of what stands beside the opening, and how deep it is
local function jamb(frame, side, all, width, include)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	local inner, outer = math.huge, 0
	for y = all.y0 + 3, all.y1 - 1, 3 do
		for _, z in ipairs({ all.z0 + 0.1, (all.z0 + all.z1) / 2, all.z1 - 0.1 }) do
			local from = frame:PointToWorldSpace(Vector3.new(side * 1, y, z))
			local hit = workspace:Raycast(from, frame.RightVector * side * 60, params)
			if hit then
				local d = math.abs(frame:PointToObjectSpace(hit.Position).X)
				inner = math.min(inner, d)
				local backFrom = frame:PointToWorldSpace(Vector3.new(side * (d + 30), y, z))
				local back = workspace:Raycast(backFrom, -frame.RightVector * side * 30, params)
				if back then outer = math.max(outer, math.abs(frame:PointToObjectSpace(back.Position).X)) end
			end
		end
	end
	local z0, z1 = math.huge, -math.huge
	if inner < math.huge then
		for y = all.y0 + 3, all.y1 - 1, 3 do
			for _, sgn in ipairs({ -1, 1 }) do
				local x = side * (inner + 0.4)
				local from = frame:PointToWorldSpace(Vector3.new(x, y, sgn * 25))
				local hit = workspace:Raycast(from, frame.LookVector * sgn * 25, params)
				if hit then
					local z = frame:PointToObjectSpace(hit.Position).Z
					z0, z1 = math.min(z0, z), math.max(z1, z)
				end
			end
		end
	end
	return { inner = inner, outer = outer, z0 = z0, z1 = z1 }
end
local function audit(lines, name, frame, kind, travel, width, pieces, statics, skip, cfg)
	local sides = {}
	local all = extents(frame, pieces[1])
	for _, part in ipairs(pieces) do extents(frame, part, all) end
	for _, side in ipairs({ -1, 1 }) do
		local box = nil
		for _, part in ipairs(pieces) do
			local n = string.sub(part.Name, -2)
			local c = frame:PointToObjectSpace(part.ExtentsCFrame.Position).X
			local s = if n == "_L" then -1 elseif n == "_R" then 1 elseif c >= 0 then 1 else -1
			if s == side then box = extents(frame, part, box) end
		end
		sides[side] = box
	end
	local J = { [-1] = jamb(frame, -1, all, width, statics), [1] = jamb(frame, 1, all, width, statics) }
	local thick = 0
	for _, j in pairs(J) do if j.inner < math.huge then thick = math.max(thick, j.outer - j.inner) end end
	local leafW = 0
	for _, box in pairs(sides) do leafW = math.max(leafW, box.x1 - box.x0) end
	table.insert(lines, string.format("%s [%s] door %.1f leaf w %.1f h %.1f z %.2f..%.2f | jamb L %.1f..%.1f z %.2f..%.2f R %.1f..%.1f z %.2f..%.2f | thick %.1f | travel %s need %.1f",
		name, kind, width, leafW, all.y1 - all.y0, all.z0, all.z1, J[-1].inner, J[-1].outer, J[-1].z0, J[-1].z1, J[1].inner, J[1].outer, J[1].z0, J[1].z1, thick,
		if travel then string.format("%.1f", travel) else "-", leafW + thick + 0.5))
	local mode = cfg and cfg.Mode
	for _, side in ipairs({ -1, 1 }) do
		local box = sides[side]
		if box then
			local swept = table.clone(box)
			local open = table.clone(box)
			local poseFrame = frame
			if mode == "Hinge" then
				local hinge = frame * CFrame.new(side * width / 2, 0, 0)
				local angle = math.rad(cfg.Angle or 90) * side * (cfg.Swing or 1)
				poseFrame = hinge * CFrame.Angles(0, angle, 0) * hinge:Inverse() * frame
			elseif mode == "Slide" or mode == "CrackSlide" then
				open.x0 += side * travel
				open.x1 += side * travel
				swept.x0 = math.min(box.x0, open.x0)
				swept.x1 = math.max(box.x1, open.x1)
			elseif mode == "Rise" then
				open.y0 += travel
				open.y1 += travel
				swept.y1 = open.y1
			end
			local line = string.format("   %s x %.1f..%.1f closed: %s", if side < 0 then "L" else "R", box.x0, box.x1, text(touching(frame, box, skip)))
			if mode == "Hinge" or mode == "Slide" or mode == "CrackSlide" or mode == "Rise" then
				line ..= " | OPEN: " .. text(touching(poseFrame, open, skip))
			end
			table.insert(lines, line)
		end
	end
end
function DoorAudit.run(only)
	local DoorAnimations = require(ReplicatedStorage.GameSystem.Config.DoorAnimations:Clone())
	local lines = {}
	local zones = {}
	for _, zone in ipairs(workspace.Zones:GetChildren()) do
		if not only or table.find(only, zone.Name) then table.insert(zones, zone) end
	end
	table.sort(zones, function(a, b) return a.Name < b.Name end)
	for _, zone in ipairs(zones) do
		for n = 2, 4 do
			local sub = zone:FindFirstChild(zone.Name .. "_" .. n)
			local gate = sub and sub:FindFirstChild("Gate")
			local barrier = gate and (gate.PrimaryPart or gate:FindFirstChild("Barrier", true))
			if barrier then
				local id = gate:GetAttribute("MapPropId")
				local name = DoorAnimations.Doors[id] or DoorAnimations.Default
				local doorTravel = DoorAnimations.distanceOf(id)
				local cfg = table.clone(DoorAnimations.typeOf(id))
				local entrance = sub:FindFirstChild("Entrance")
				cfg.Swing = if entrance and entrance:IsA("BasePart") and barrier.CFrame:PointToObjectSpace(entrance.Position).Z < 0 then -1 else 1
				local pieces, statics = {}, {}
				for _, part in ipairs(barrier:GetDescendants()) do
					if part:IsA("BasePart") then table.insert(pieces, part) end
				end
				if #pieces == 0 or barrier.Transparency < 1 then table.insert(pieces, barrier) end
				for _, part in ipairs(gate:GetDescendants()) do
					if part:IsA("BasePart") and part ~= barrier and not part:IsDescendantOf(barrier) and part.Transparency < 1 then table.insert(statics, part) end
				end
				audit(lines, sub.Name .. " " .. tostring(id), barrier.CFrame, name .. " " .. cfg.Mode, (cfg.Height or cfg.Drop or (cfg.Mode ~= "Hinge" and cfg.Mode ~= "Fade" and doorTravel) or nil), barrier.Size.X, pieces, statics, { barrier }, cfg)
				task.wait()
			end
		end
		local sub = zone:FindFirstChild(zone.Name .. "_4")
		local gate = sub and sub:FindFirstChild("BossGate")
		if gate then
			local pieces, statics = {}, {}
			for _, part in ipairs(gate:GetDescendants()) do
				if part:IsA("BasePart") then
					if table.find(LEAF_NAMES, part.Name) then table.insert(pieces, part)
					elseif part.Transparency < 1 then table.insert(statics, part) end
				end
			end
			if #pieces == 0 then
				table.insert(lines, sub.Name .. " BossGate: NO LEAF PART (nothing moves)")
			else
				local pos = Vector3.zero
				for _, part in ipairs(pieces) do pos += part.ExtentsCFrame.Position end
				pos /= #pieces
				local frame = CFrame.new(pos) * gate:GetPivot().Rotation
				local box = nil
				for _, part in ipairs(pieces) do box = extents(frame, part, box) end
				if box.x1 - box.x0 < box.z1 - box.z0 then
					frame *= CFrame.Angles(0, math.pi / 2, 0)
					box = nil
					for _, part in ipairs(pieces) do box = extents(frame, part, box) end
				end
				audit(lines, sub.Name .. " BossGate(" .. #pieces .. ")", frame, "Boss Slide", box.x1 - box.x0 + DoorAnimations.BossVeil.DoorFrame + 0.5, box.x1 - box.x0, pieces, statics, table.clone(pieces), { Mode = "Slide" })
			end
		end
		task.wait()
	end
	return table.concat(lines, "\n")
end
return DoorAudit
