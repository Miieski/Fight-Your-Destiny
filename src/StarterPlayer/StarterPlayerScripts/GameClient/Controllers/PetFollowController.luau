--!strict
-- Pets that follow their owner (docs/menu_systems_brief.txt B4, Pets V2 docs/pets_v2_plan.md). Client-side visuals
-- only: the server lists each player's first equipped pets in the "FollowPets" attribute
-- ("petId:tier" or "petId:tier:Mutation:Size"); this clones the models (ReplicatedStorage.Assets.Pets) into a
-- local folder, scales them by their size (Big / Huge, Config/PetMutations), dresses them in their mutation look
-- (Util/PetLook) and moves them every frame. V2 rigs are animated piece by piece (Util/PetMotion: walk cycle,
-- wings, tail, idle, a happy jump when the owner kills an enemy); the procedural placeholders are moved whole
-- with PivotTo (walkers hop). Flyers / swimmers / floaters stay in the air with a gentle bob. No collision, no
-- physics. Other players' pets: only within Follow.ViewDistance studs, at most 3 per player, hidden when Low FX
-- is on and more than Follow.CrowdPlayers players are nearby. Epic and rarer pets get a soft light in their
-- rarity color.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.GameSystem.Net)
local PetMutations = require(ReplicatedStorage.GameSystem.Config.PetMutations)
local PetRarities = require(ReplicatedStorage.GameSystem.Config.PetRarities)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local PetLook = require(ReplicatedStorage.GameSystem.Util.PetLook)
local PetMotion = require(ReplicatedStorage.GameSystem.Util.PetMotion)
local Settings = require(script.Parent.SettingsController)

local PetFollowController = { Priority = 30 }

local FOLLOW = PetRarities.Follow
local LIGHT_FROM = Rarities.GLOW_FROM

type Pet = {
	model: Model,
	flying: boolean,
	hops: boolean,
	position: Vector3,
	facing: Vector3,
	phase: number,
	height: number,
	spread: number,
	motion: any,
	look: PetLook.Look?,
}
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

local function makePet(id: string, tier: number, index: number, mutation: string?, size: string?): Pet?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local source = assets and assets:FindFirstChild("Pets") and assets.Pets:FindFirstChild(id)
	if not source then
		return nil
	end
	local model = source:Clone() :: Model
	local sizeScale = PetMutations.scale(size)
	local scale = FOLLOW.Scale * sizeScale
	if scale ~= 1 then
		model:ScaleTo(scale)
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
	local look = PetLook.apply(model, mutation, { LowFx = low })
	-- the rest pose is recorded after the scale and the shells, before the model moves
	local motion = PetMotion.new(model)
	if motion then
		motion.phase = index * 1.7
	end
	model.Parent = folder
	local _, box = model:GetBoundingBox()
	local gait = model:GetAttribute("Gait")
	return {
		model = model,
		flying = model:GetAttribute("Flying") == true,
		-- V2 walkers walk with their legs; hoppers and the old placeholders hop
		hops = gait == nil or gait == "Hop",
		position = Vector3.new(0, -1000, 0),
		facing = Vector3.new(0, 0, -1),
		phase = index * 1.7,
		height = box.Y,
		spread = 1 + (sizeScale - 1) * 0.6, -- big pets walk a little farther out
		motion = motion,
		look = look,
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
		local id, tier, mutation, size = string.match(entry, "^([%w_]+):(%d+):?(%a*):?(%a*)$")
		if id then
			local pet = makePet(id, tonumber(tier) or 1, #owner.pets + 1, if mutation ~= "" then mutation else nil, if size ~= "" then size else nil)
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
		local velocity = root.AssemblyLinearVelocity
		local ownerSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local moving = ownerSpeed > 2
		for index, pet in ipairs(owner.pets) do
			local offset = (FOLLOW.Offsets[index] or FOLLOW.Offsets[#FOLLOW.Offsets]) * pet.spread
			local spot = basis * offset
			local ground = if player == localPlayer or index == 1 then groundY(Vector3.new(spot.X, root.Position.Y, spot.Z), feet) else feet
			local y = ground
			if pet.flying then
				y += FOLLOW.FlyHeight + math.sin(now * FOLLOW.BobSpeed + pet.phase) * FOLLOW.BobHeight
			elseif moving and pet.hops then
				y += math.abs(math.sin(now * FOLLOW.HopSpeed + pet.phase)) * FOLLOW.HopHeight
			end
			local target = Vector3.new(spot.X, y, spot.Z)
			local before = pet.position
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
			local cf = CFrame.lookAt(pet.position, pet.position + pet.facing)
			if pet.motion then
				local moved = Vector3.new(pet.position.X - before.X, 0, pet.position.Z - before.Z).Magnitude
				local speed = if dt > 0 and moved < FOLLOW.TeleportDistance then moved / dt else 0
				pet.motion:step(cf, dt, math.max(speed, if moving then ownerSpeed * 0.8 else 0), now)
			else
				pet.model:PivotTo(cf)
			end
			if pet.look then
				pet.look.update(now)
			end
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
	-- the owner's pets jump for joy at each kill
	Net.on("EnemyKilled", function()
		local owner = owners[Players.LocalPlayer]
		if owner then
			local now = os.clock()
			for _, pet in ipairs(owner.pets) do
				if pet.motion then
					pet.motion:cheer(now)
				end
			end
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return PetFollowController
