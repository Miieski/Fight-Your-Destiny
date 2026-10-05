--!strict
-- Live 3D icons in ViewportFrames (docs/menu_systems_brief.txt B4: no PNG for pets, eggs or armor).
-- Each icon (kind, id, tier) is built once as a template (model, camera framing, rarity ring); every later use
-- is a Clone() of it, so a grid of 60 pets never rebuilds models.
--   ModelIcon.pet(petId, props?), ModelIcon.egg(zoneIndex, tier?, props?), ModelIcon.armor(id, tier, props?)
--       -> ViewportFrame (armor = the procedural piece of Util/ArmorLook, built on an invisible body)
--   props = { Size, Position, AnchorPoint, ZIndex, Parent, Silhouette (black shape, locked items), Name }
--   ModelIcon.turntable(view, seconds?) -> stop(): slow spin, drag to turn (detail previews)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Armor = require(ReplicatedStorage.GameSystem.Config.Armor)
local ArmorLook = require(ReplicatedStorage.GameSystem.Util.ArmorLook)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)

local ModelIcon = {}

local YAW = math.rad(-28) -- three-quarter view
local templates: { [string]: ViewportFrame } = {}

local function source(folder: string, name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local holder = assets and assets:FindFirstChild(folder)
	local model = holder and holder:FindFirstChild(name)
	return if model and model:IsA("Model") then model else nil
end

local function build(model: Model?, tier: number?, zoom: number): ViewportFrame
	local view = Instance.new("ViewportFrame")
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(175, 168, 160)
	view.LightColor = Color3.fromRGB(255, 246, 232)
	view.LightDirection = Vector3.new(-0.5, -1, 0.7)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 26
	camera.Parent = view
	view.CurrentCamera = camera
	if not model then
		return view
	end
	local clone = model:Clone()
	for _, item in ipairs(clone:GetDescendants()) do
		-- lights and particles do not render in a ViewportFrame
		if item:IsA("ParticleEmitter") or item:IsA("Light") then
			item:Destroy()
		elseif tier and item:IsA("BasePart") and item:GetAttribute("RarityRing") then
			local rarity = Rarities.get(tier)
			item.Color = rarity.Color
			item.Transparency = 0.15
		end
	end
	clone:PivotTo(CFrame.Angles(0, YAW, 0))
	clone.Parent = view
	local box, size = clone:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z) * 0.5
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * zoom
	local center = box.Position
	-- the models look toward -Z: the camera stands in front, a little above
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, radius * 0.45, -distance), center)
	return view
end

local function instance(key: string, make: () -> ViewportFrame, props: { [string]: any }?): ViewportFrame
	local template = templates[key]
	if not template then
		template = make()
		templates[key] = template
	end
	local view = template:Clone()
	view.CurrentCamera = view:FindFirstChildOfClass("Camera")
	local p = props or {}
	view.Name = p.Name or "ModelIcon"
	view.Size = p.Size or UDim2.fromScale(1, 1)
	view.Position = p.Position or UDim2.fromScale(0.5, 0.5)
	view.AnchorPoint = p.AnchorPoint or Vector2.new(0.5, 0.5)
	view.ZIndex = p.ZIndex or 1
	if p.Silhouette then
		view.ImageColor3 = Color3.new(0, 0, 0)
		view.Ambient = Color3.new(0, 0, 0)
		view.LightColor = Color3.new(0, 0, 0)
	end
	view.Parent = p.Parent
	return view
end

function ModelIcon.pet(petId: string, props: { [string]: any }?): ViewportFrame
	return instance("pet:" .. petId, function()
		return build(source("Pets", petId), nil, 1.12)
	end, props)
end

function ModelIcon.egg(zone: number, tier: number?, props: { [string]: any }?): ViewportFrame
	local zoneDef = Zones.List[zone]
	local name = if zoneDef then string.lower(zoneDef.Id) else ""
	return instance(`egg:{name}:{tier or 0}`, function()
		return build(source("Eggs", name), tier, 1.25)
	end, props)
end

function ModelIcon.armor(id: string, tier: number, props: { [string]: any }?): ViewportFrame
	return instance(`armor:{id}:{tier}`, function()
		local piece = Armor.ById[id]
		local model = Instance.new("Model")
		if piece then
			local dummy = ArmorLook.dummy()
			local folder = ArmorLook.apply(dummy, { [piece.Slot] = { id = id, tier = tier } }, { LowFx = true })
			if folder then
				for _, part in ipairs(folder:GetChildren()) do
					part.Parent = model
				end
			end
			if piece.Slot == "Helmet" then
				-- a mannequin head inside, so the icon reads as a helmet
				local head = Instance.new("Part")
				head.Shape = Enum.PartType.Ball
				head.Size = Vector3.new(1.15, 1.15, 1.15)
				head.CFrame = (dummy:FindFirstChild("Head") :: BasePart).CFrame
				head.Color = Color3.fromRGB(205, 195, 185)
				head.Anchored = true
				head.Parent = model
			end
			dummy:Destroy()
		end
		return build(model, nil, if piece and piece.Slot == "Chest" then 1.0 else 1.1)
	end, props)
end

-- Slow spin; drag (mouse or finger) turns the model by hand. Returns a function that stops it.
function ModelIcon.turntable(view: ViewportFrame, seconds: number?): () -> ()
	local model = view:FindFirstChildOfClass("Model")
	if not model then
		return function() end
	end
	local box = model:GetBoundingBox()
	local pivot = CFrame.new(box.Position)
	local offset = pivot:ToObjectSpace(model:GetPivot())
	local yaw, dragging, lastX = 0, false, 0
	local period = seconds or 8
	local conns = {}
	table.insert(conns, view.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, lastX = true, input.Position.X
		end
	end))
	table.insert(conns, view.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
	table.insert(conns, view.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			yaw += (input.Position.X - lastX) * 0.012
			lastX = input.Position.X
		end
	end))
	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		if not view.Parent then
			return
		end
		if not dragging then
			yaw += dt * math.pi * 2 / period
		end
		model:PivotTo(pivot * CFrame.Angles(0, yaw, 0) * offset)
	end))
	return function()
		for _, conn in ipairs(conns) do
			conn:Disconnect()
		end
	end
end

return ModelIcon
