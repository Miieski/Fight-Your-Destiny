-- DoorStage (dev tool, Edit mode only) - Round 9 part 2. Open poses exist only on the client: D.pose("Plains_4", 0.6) puts one door in pose t with GateController's maths (third argument true: the Round 8 pose), D.restore("Plains_4") puts it back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local D = {}
local HOME, ALPHA = "StageHome", "StageAlpha"
local function hold(part)
	if part:GetAttribute(HOME) == nil then
		part:SetAttribute(HOME, part.CFrame)
		part:SetAttribute(ALPHA, part.Transparency)
	end
end
function D.pose(sub, t, old) -- old: the Round 8 pose, nothing fades
	local Doors = require(ReplicatedStorage.GameSystem.Config.DoorAnimations:Clone())
	local zone = string.match(sub, "^%a+")
	local z = workspace.Zones[zone][sub]
	local gate = z.Gate
	local b = gate.PrimaryPart or gate:FindFirstChild("Barrier", true)
	local id = gate:GetAttribute("MapPropId")
	local cfg = Doors.typeOf(id)
	local mode = cfg.Mode
	local entrance = z:FindFirstChild("Entrance")
	local swing = if entrance and b.CFrame:PointToObjectSpace(entrance.Position).Z < 0 then -1 else 1
	local f = b.CFrame
	local stage = Instance.new("Folder")
	stage.Name = "DoorStage"
	stage.Parent = workspace
	local pieces = {}
	for _, d in ipairs(b:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(pieces, d) end
	end
	if b.Transparency < 1 then
		local two = mode == "Hinge" or mode == "Slide" or mode == "CrackSlide"
		for _, x in ipairs(if two then { -b.Size.X / 4, b.Size.X / 4 } else { 0 }) do
			local p = b:Clone()
			p:ClearAllChildren()
			p.Name = "StageProxy"
			p.Size = Vector3.new(if two then b.Size.X / 2 else b.Size.X, b.Size.Y, b.Size.Z)
			p.CFrame = f * CFrame.new(x, 0, 0)
			p.Parent = stage
			table.insert(pieces, p)
		end
		hold(b)
		b.Transparency = 1
	end
	local index = 0
	local fadeFrom = cfg.FadeFrom or 0.8
	for _, part in ipairs(pieces) do
		hold(part)
		index += 1
		local name = string.sub(part.Name, -2)
		local side = if name == "_L" then -1 elseif name == "_R" then 1 elseif f:PointToObjectSpace(part.ExtentsCFrame.Position).X >= 0 then 1 else -1
		local home = part:GetAttribute(HOME)
		local alpha = part:GetAttribute(ALPHA)
		local fade = math.clamp((t - fadeFrom) / (1 - fadeFrom), 0, 1)
		if mode == "Hinge" then
			local hinge = f * CFrame.new(side * b.Size.X / 2, 0, 0)
			part.CFrame = hinge * CFrame.Angles(0, math.rad(if old then 100 else cfg.Angle or 90) * t * side * swing, 0) * hinge:Inverse() * home
		elseif mode == "Slide" or mode == "CrackSlide" then
			part.CFrame = home + f.RightVector * side * (if old then 12 else Doors.distanceOf(id)) * t
		elseif mode == "Rise" then
			part.CFrame = home + f.UpVector * (if old then 15.5 else cfg.Height or 15) * t
		elseif mode == "Fall" then
			local n = #pieces
			local k = math.clamp((t - 0.4 * (index - 1) / n) / 0.6, 0, 1)
			part.CFrame = (home - f.UpVector * (cfg.Drop or 12) * k * k) * CFrame.Angles(0, 0, 0.35 * side * k)
			fade = math.clamp((k - 0.65) / 0.35, 0, 1)
		elseif mode == "Retract" then
			part.CFrame = home + f.UpVector * (cfg.Height or 12) * t + f.RightVector * side * 2 * t
			fade = math.clamp((t - 0.4) / 0.6, 0, 1)
		else
			fade = t
		end
		if old and mode ~= "Fall" and mode ~= "Retract" and mode ~= "Fade" then fade = 0 end
		part.Transparency = 1 - (1 - alpha) * (1 - fade)
	end
	return sub .. " " .. tostring(id) .. " " .. mode .. " t=" .. t .. ": " .. #pieces .. " pieces"
end
function D.restore(sub)
	local n = 0
	local zone = string.match(sub, "^%a+")
	for _, d in ipairs(workspace.Zones[zone][sub].Gate:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute(HOME) ~= nil then
			d.CFrame = d:GetAttribute(HOME)
			d.Transparency = d:GetAttribute(ALPHA)
			d:SetAttribute(HOME, nil)
			d:SetAttribute(ALPHA, nil)
			n += 1
		end
	end
	local stage = workspace:FindFirstChild("DoorStage")
	while stage do
		stage:Destroy()
		stage = workspace:FindFirstChild("DoorStage")
	end
	return "restored " .. n
end
return D
