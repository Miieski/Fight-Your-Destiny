--!strict
-- Pets that follow their owner (docs/menu_systems_brief.txt B4). Client-side visuals only: the server lists
-- each player's first equipped pets in the "FollowPets" attribute ("petId:tier,petId:tier"); this clones the
-- models (ReplicatedStorage.Assets.Pets) into a local folder and moves them every frame with PivotTo.
-- Walkers hop along the ground behind the owner, flyers float with a gentle bob. No collision, no physics.
-- Other players' pets: only within Follow.ViewDistance studs, at most 3 per player, hidden when Low FX is on and
-- more than Follow.CrowdPlayers players are nearby. Epic and rarer pets get a soft light in their rarity color.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetRarities = require(ReplicatedStorage.GameSystem.Config.PetRarities)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local Settings = require(script.Parent.SettingsController)

local PetFollowController = { Priority = 30 }

local FOLLOW = PetRarities.Follow
local LIGHT_FROM = Rarities.GLOW_FROM

type Pet = { model: Model, flying: boolean, position: Vector3, facing: Vector3, phase: number, height: number }
type Owner = { key: string, pets: { Pet }, visible: boolean }

local owners: { [Player]: Owner } = {}
local folder: Folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local lastFilter = 0

local function clear(owner: Owner)
	for _, pet in ipairs(owner.pets) do
		pet.model:Destroy()
	end
	table.clear(owner.pets)
end

local function makePet(id: string, tier: number, index: number): Pet?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local source = assets and assets:FindFirstChild("Pets") and assets.Pets:FindFirstChild(id)
	if not source then
		return nil
	end
	local model = source:Clone() :: Model
	if FOLLOW.Scale ~= 1 then
		model:ScaleTo(FOLLOW.Scale)
	end
	local low = Settings.get("LowFx") == true
	for _, item in ipairs(model:GetDescendants()) do
		if low and (item:IsA("ParticleEmitter") or item:IsA("Light")) then
			item:Destroy()
		end
	end
	if tier >= LIGHT_FROM and not low and model.PrimaryPart then
		local light = Instance.new("PointLight")
		light.Name = "RarityLight"
		light.Color = Rarities.get(tier).Color
		light.Range = 5 + tier
		light.Brightness = 0.9
		light.Parent = model.PrimaryPart
	end
	model.Parent = folder
	local _, size = model:GetBoundingBox()
	return {
		model = model,
		flying = model:GetAttribute("Flying") == true,
		position = Vector3.new(0, -1000, 0),
		facing = Vector3.new(0, 0, -1),
		phase = index * 1.7,
		height = size.Y,
	}
end

local function rebuild(player: Player, owner: Owner)
	local key = player:GetAttribute("FollowPets")
	key = if typeof(key) == "string" then key else ""
	if key == owner.key then
		return
	end
	owner.key = key
	clear(owner)
	if key == "" then
		return
	end
	for entry in string.gmatch(key, "[^,]+") do
		if #owner.pets >= PetRarities.MaxFollowing then
			break
		end
		local id, tier = string.match(entry, "^([%w_]+):(%d+)$")
		if id then
			local pet = makePet(id, tonumber(tier) or 1, #owner.pets + 1)
			if pet then
				table.insert(owner.pets, pet)
				if not owner.visible then
					pet.model.Parent = nil
				end
			end
		end
	end
end

local function track(player: Player)
	local owner: Owner = { key = "", pets = {}, visible = true }
	owners[player] = owner
	rebuild(player, owner)
	player:GetAttributeChangedSignal("FollowPets"):Connect(function()
		if owners[player] == owner then
			rebuild(player, owner)
		end
	end)
end

local function groundY(position: Vector3, fallback: number): number
	local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), rayParams)
	return if hit then hit.Position.Y else fallback
end

local function setVisible(owner: Owner, visible: boolean)
	if owner.visible == visible then
		return
	end
	owner.visible = visible
	for _, pet in ipairs(owner.pets) do
		pet.model.Parent = if visible then folder else nil
		pet.position = Vector3.new(0, -1000, 0) -- reappear at the owner, not where it was hidden
	end
end

local function step(dt: number)
	local now = os.clock()
	local localPlayer = Players.LocalPlayer
	local myRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if now - lastFilter > 1 then
		lastFilter = now
		local ignore: { Instance } = { folder }
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		rayParams.FilterDescendantsInstances = ignore
	end
	-- crowd check for the Low FX rule
	local crowd = false
	if Settings.get("LowFx") == true and myRoot then
		local near = 0
		for player in pairs(owners) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if player ~= localPlayer and root and (root.Position - myRoot.Position).Magnitude <= FOLLOW.ViewDistance then
				near += 1
			end
		end
		crowd = near > FOLLOW.CrowdPlayers
	end
	local alpha = 1 - math.exp(-FOLLOW.Smoothing * dt)
	for player, owner in pairs(owners) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local visible = root ~= nil and #owner.pets > 0
		if visible and player ~= localPlayer then
			visible = not crowd and myRoot ~= nil and ((root :: BasePart).Position - myRoot.Position).Magnitude <= FOLLOW.ViewDistance
		end
		setVisible(owner, visible)
		if not visible or not root then
			continue
		end
		local feet = root.Position.Y - root.Size.Y / 2 - (if humanoid then humanoid.HipHeight else 2)
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
		local basis = CFrame.lookAt(Vector3.new(root.Position.X, 0, root.Position.Z), Vector3.new(root.Position.X, 0, root.Position.Z) + flat)
		local moving = root.AssemblyLinearVelocity.Magnitude > 2
		for index, pet in ipairs(owner.pets) do
			local offset = FOLLOW.Offsets[index] or FOLLOW.Offsets[#FOLLOW.Offsets]
			local spot = basis * offset
			local ground = if player == localPlayer or index == 1 then groundY(Vector3.new(spot.X, root.Position.Y, spot.Z), feet) else feet
			local y = ground
			if pet.flying then
				y += FOLLOW.FlyHeight + math.sin(now * FOLLOW.BobSpeed + pet.phase) * FOLLOW.BobHeight
			elseif moving then
				y += math.abs(math.sin(now * FOLLOW.HopSpeed + pet.phase)) * FOLLOW.HopHeight
			end
			local target = Vector3.new(spot.X, y, spot.Z)
			if (pet.position - target).Magnitude > FOLLOW.TeleportDistance then
				pet.position = target
			else
				local next = pet.position:Lerp(target, alpha)
				-- the hop / bob height follows at once, only the ground position is smoothed
				pet.position = Vector3.new(next.X, y, next.Z)
			end
			local delta = target - pet.position
			local wanted = if Vector3.new(delta.X, 0, delta.Z).Magnitude > 0.3 then Vector3.new(delta.X, 0, delta.Z).Unit else flat
			pet.facing = pet.facing:Lerp(wanted, alpha)
			if pet.facing.Magnitude < 0.01 then
				pet.facing = flat
			end
			pet.model:PivotTo(CFrame.lookAt(pet.position, pet.position + pet.facing))
		end
	end
end

function PetFollowController:Start()
	local holder = Instance.new("Folder")
	holder.Name = "ClientPets"
	holder.Parent = workspace
	folder = holder
	for _, player in ipairs(Players:GetPlayers()) do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		local owner = owners[player]
		owners[player] = nil
		if owner then
			clear(owner)
		end
	end)
	Settings.changed("LowFx", function()
		-- rebuild the models with / without lights and particles
		for player, owner in pairs(owners) do
			owner.key = "\0"
			rebuild(player, owner)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return PetFollowController
