--!strict
-- The boss door transition of THIS player (Config/DoorAnimations.BossVeil, Net "BossDoor" from BossService). Enter / Exit:
-- input locked, a luminous veil in the zone's tint fills the door, the door leaves part, the camera pushes through it,
-- a short fade hidden by the light while the server teleports. Arrive / Back: the fade lifts, the camera eases back and
-- the character walks out. Input is locked only for this (about 1.5-2 s). A watchdog restores everything whatever happens.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DoorAnimations = require(ReplicatedStorage.GameSystem.Config.DoorAnimations)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Kit = script.Parent.Parent.UI.Kit
local InputLock = require(Kit.InputLock)
local Transition = require(Kit.Transition)
local Window = require(Kit.Window)

local BossDoorController = { Priority = 30 }

local VEIL = DoorAnimations.BossVeil
local LOCK = "BossDoor"
local CAMERA_LOCK = "BossDoorCamera"
local VEIL_SIZE = Vector3.new(36, 32, 0.3)
local NEAR_DOOR = 60 -- studs: further than this (a team mate) the veil opens in front of the player
local LEAF_NAMES = { "Door", "DoorL", "DoorR", "Leaf", "DoorLeaf", "DoorPanel", "DoorInner" }
local player = Players.LocalPlayer

local token = 0
local veil: BasePart? = nil
local moved: { { part: BasePart, home: CFrame } } = {}

local function tints(zoneId: any): { Color3 }
	return VEIL.Tints[zoneId] or { Color3.new(1, 1, 1), Color3.new(1, 1, 1) }
end

local function restoreDoor()
	for _, item in ipairs(moved) do
		if item.part.Parent then
			item.part.CFrame = item.home
		end
	end
	moved = {}
end

local function cleanup()
	if veil then
		veil:Destroy()
		veil = nil
	end
	restoreDoor()
	InputLock.release(LOCK)
	InputLock.release(CAMERA_LOCK)
end

local function makeVeil(cf: CFrame, zoneId: any): BasePart
	local tint = tints(zoneId)
	local p = Instance.new("Part")
	p.Name = "BossVeil"
	p.Size = VEIL_SIZE
	p.CFrame = cf
	p.Color, p.Material = tint[1], Enum.Material.Neon
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Transparency = 1
	local fx = Instance.new("ParticleEmitter")
	fx.Texture = "rbxasset://textures/particles/smoke_main.dds"
	fx.Color = ColorSequence.new(tint[2])
	fx.Rate = 0
	fx.Lifetime = NumberRange.new(0.6, 1.1)
	fx.Speed = NumberRange.new(3, 8)
	fx.SpreadAngle = Vector2.new(70, 70)
	fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 3.6) })
	fx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	fx.Parent = p
	p.Parent = workspace
	fx:Emit(36)
	return p
end

-- this client only: the leaves of the boss gate part (the gate goes back after the transition)
local function openLeaves(zoneId: any, door: CFrame)
	local zones = workspace:FindFirstChild("Zones")
	local folder = zones and zones:FindFirstChild(tostring(zoneId))
	local sub = folder and folder:FindFirstChild(`{zoneId}_4`)
	local gate = sub and sub:FindFirstChild("BossGate")
	if not gate then
		return
	end
	for _, part in ipairs(gate:GetDescendants()) do
		if part:IsA("BasePart") and table.find(LEAF_NAMES, part.Name) then
			local x = door:PointToObjectSpace(part.Position).X
			local side = if x >= 0 then 1 else -1
			table.insert(moved, { part = part, home = part.CFrame })
			TweenService:Create(part, TweenInfo.new(VEIL.Seconds * 0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = part.CFrame + door.RightVector * side * 9 }):Play()
		end
	end
end

local function leave(data: { [string]: any }, inward: boolean)
	token += 1
	local mine = token
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	InputLock.acquire(LOCK)
	Window.close(true)
	task.delay(VEIL.Watchdog, function()
		if mine == token then
			Transition.restore()
			cleanup()
		end
	end)
	if not (root and camera) then
		Transition.show({ Color = Color3.new(0, 0, 0), FadeIn = VEIL.FadeSeconds, Lock = LOCK })
		return
	end
	-- the fallback is the plain fade above; everything here only dresses it
	pcall(function()
		local door = data.Door
		local forward: Vector3
		local center: Vector3
		if inward and door and (door.Position - root.Position).Magnitude < NEAR_DOOR then
			local flat = (door.Position - root.Position) * Vector3.new(1, 0, 1)
			forward = flat.Unit
			center = Vector3.new(door.Position.X, root.Position.Y + 10, door.Position.Z) + forward * 2
			openLeaves(data.ZoneId, door)
		else
			forward = root.CFrame.LookVector
			center = root.Position + forward * 10 + Vector3.yAxis * 8
		end
		local v = makeVeil(CFrame.lookAt(center, center - forward), data.ZoneId)
		veil = v
		TweenService:Create(v, TweenInfo.new(VEIL.Seconds * 0.5, Enum.EasingStyle.Quad), { Transparency = 0.04 }):Play()
		camera.CameraType = Enum.CameraType.Scriptable
		local goal = CFrame.lookAt(center - forward * 1.2, center + forward)
		TweenService:Create(camera, TweenInfo.new(VEIL.Seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { CFrame = goal }):Play()
		Sfx.play("PortalEnter")
	end)
	task.delay(VEIL.FadeAt, function()
		if mine == token then
			Transition.show({ Color = tints(data.ZoneId)[1], FadeIn = VEIL.FadeSeconds, Lock = LOCK })
		end
	end)
end

local function arrive(data: { [string]: any })
	token += 1
	local mine = token
	task.delay(VEIL.Watchdog, function()
		if mine == token then
			Transition.restore()
			cleanup()
		end
	end)
	InputLock.acquire(CAMERA_LOCK)
	-- the character is on the other side before the light goes
	local goal = data.Look :: CFrame?
	local deadline = os.clock() + 2
	local root: BasePart? = nil
	while os.clock() < deadline do
		local character = player.Character
		root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (not goal or (root.Position - goal.Position).Magnitude < 14) then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if mine ~= token then
		return
	end
	if veil then
		veil:Destroy()
		veil = nil
	end
	restoreDoor()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and camera and humanoid then
		pcall(function()
			local r = root :: BasePart
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = r.CFrame * CFrame.new(0, 2.6, 2.5)
			TweenService:Create(camera, TweenInfo.new(VEIL.ArriveSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = r.CFrame * CFrame.new(0, 5, 13) * CFrame.Angles(math.rad(-12), 0, 0) }):Play()
			humanoid:MoveTo(r.Position + r.CFrame.LookVector * VEIL.WalkStuds)
		end)
	end
	Transition.hide(VEIL.FadeSeconds, true)
	task.delay(VEIL.ArriveSeconds, function()
		if mine ~= token then
			return
		end
		token += 1 -- the watchdog has nothing left to do
		Transition.restore()
		cleanup()
	end)
end

function BossDoorController:Start()
	Net.on("BossDoor", function(data: { [string]: any })
		if data.Phase == "Enter" then
			leave(data, true)
		elseif data.Phase == "Exit" then
			leave(data, false)
		else
			task.spawn(arrive, data)
		end
	end)
end

return BossDoorController
