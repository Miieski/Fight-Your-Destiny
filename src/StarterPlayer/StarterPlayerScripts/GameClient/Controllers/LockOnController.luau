--!strict
-- Lock-on and body facing (Config/Combat LockOn). Client only: the server never trusts it, it only receives a direction.
-- The lock button takes the nearest enemy inside a cone around the camera's center; the camera blends toward the target
-- (never snaps, also on release: it just stops being pulled) and the body turns to it; attacks aim at it. The small arrow
-- goes to the next target to the right (it wraps). Auto release: the target dies or goes beyond Range, or a boss hit
-- breaks it (Net "LockBreak").
--   LockOn.toggle()   LockOn.next()   LockOn.release()
--   LockOn.point() -> Vector3?          the point attacks aim at (nil = not locked)
--   LockOn.face(direction, seconds)     turns the body smoothly toward a flat direction for that long (attacks)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Combat = require(ReplicatedStorage.GameSystem.Config.Combat)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Controls = require(script.Parent.ControlsController)
local Theme = require(script.Parent.Parent.UI.Kit.Theme)

local LockOn = { Priority = 6 }

local CFG = Combat.LockOn
local RENDER_STEP = "FYD_LockOn"
local MAX_PITCH = 0.55 -- sine of the steepest camera pitch the lock pulls to
local MARK_SIZE = 44 -- pixels

local player = Players.LocalPlayer
local target: Model? = nil
local facing: Vector3? = nil
local facingUntil = 0
local mark: BillboardGui? = nil

local function rootOf(): (BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root, humanoid
	end
	return nil, nil
end

local function alive(model: Model?): boolean
	return model ~= nil and model.Parent ~= nil and not model:GetAttribute("Dead")
end

local function pointOf(model: Model): Vector3
	return model:GetPivot().Position + Vector3.new(0, CFG.TargetHeight, 0)
end

-- Enemies in the cone, as { model, x (screen side), distance }.
local function inCone(root: BasePart): { { model: Model, side: number, distance: number } }
	local camera = workspace.CurrentCamera
	local folder = workspace:FindFirstChild("Enemies")
	local found = {}
	if not (camera and folder) then
		return found
	end
	local view = camera.CFrame
	local cosCone = math.cos(math.rad(CFG.ConeDegrees))
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("EnemyId") and alive(model) then
			local point = pointOf(model)
			local distance = (point - root.Position).Magnitude
			local fromCamera = point - view.Position
			if distance <= CFG.Range and fromCamera.Magnitude > 0.1 and fromCamera.Unit:Dot(view.LookVector) >= cosCone then
				table.insert(found, { model = model, side = view.RightVector:Dot(fromCamera), distance = distance })
			end
		end
	end
	return found
end

local function setMark(model: Model?)
	if mark then
		mark:Destroy()
		mark = nil
	end
	if not model then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "LockOnMark"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(MARK_SIZE, MARK_SIZE)
	gui.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	local ring = Instance.new("Frame")
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1
	Theme.round(ring)
	Theme.stroke(ring, Theme.Colors.Gold, 3)
	ring.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	mark = gui
end

local function setTarget(model: Model?)
	target = model
	setMark(model)
	Controls.setHidden("LockNext", model == nil)
end

function LockOn.release()
	if target then
		setTarget(nil)
	end
end

function LockOn.toggle()
	if target then
		setTarget(nil)
		return
	end
	local root = rootOf()
	if not root then
		return
	end
	local best, bestDistance = nil, math.huge
	for _, entry in ipairs(inCone(root)) do
		if entry.distance < bestDistance then
			best, bestDistance = entry.model, entry.distance
		end
	end
	if best then
		setTarget(best)
	end
end

-- The next enemy to the right on screen, else the leftmost one.
function LockOn.next()
	local root = rootOf()
	if not (root and target) then
		return
	end
	local list = inCone(root)
	table.sort(list, function(a, b)
		return a.side < b.side
	end)
	local at = 0
	for index, entry in ipairs(list) do
		if entry.model == target then
			at = index
		end
	end
	local entry = list[at % math.max(1, #list) + 1]
	if entry then
		setTarget(entry.model)
	end
end

function LockOn.point(): Vector3?
	return if target and alive(target) then pointOf(target) else nil
end

function LockOn.face(direction: Vector3, seconds: number)
	facing = direction
	facingUntil = math.max(facingUntil, os.clock() + seconds)
end

-- Runs right after the camera scripts: a rotation of the camera's look carries over to the next frame's orbit.
local function pullCamera(dt: number)
	local goal = LockOn.point()
	local root = rootOf()
	if target and (not goal or not root or (goal - root.Position).Magnitude > CFG.Range) then
		setTarget(nil)
		return
	end
	local camera = workspace.CurrentCamera
	if not (goal and camera) then
		return
	end
	local focus = camera.Focus.Position
	local distance = (camera.CFrame.Position - focus).Magnitude
	local wanted = goal - focus
	if wanted.Magnitude < 1 then
		return
	end
	local direction = wanted.Unit
	direction = Vector3.new(direction.X, math.clamp(direction.Y, -MAX_PITCH, MAX_PITCH), direction.Z).Unit
	local look = camera.CFrame.LookVector:Lerp(direction, 1 - math.exp(-CFG.CameraSpeed * dt))
	if look.Magnitude > 1e-3 then
		look = look.Unit
		camera.CFrame = CFrame.lookAt(focus - look * distance, focus)
	end
end

-- The body turns toward the lock's target, or the attack's direction while it lasts; otherwise the Humanoid decides.
local function turnBody(dt: number)
	local root, humanoid = rootOf()
	if not (root and humanoid) then
		return
	end
	local goal = LockOn.point()
	local wanted = if goal then Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
		elseif facing and os.clock() < facingUntil then facing
		else nil
	if not wanted or wanted.Magnitude < 0.1 then
		humanoid.AutoRotate = true
		return
	end
	humanoid.AutoRotate = false
	local look = root.CFrame.LookVector
	local now = Vector3.new(look.X, 0, look.Z)
	local turned = now:Lerp(wanted.Unit, 1 - math.exp(-CFG.FaceSpeed * dt))
	if turned.Magnitude > 1e-3 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + turned)
	end
end

function LockOn:Start()
	Controls.LockOn:Connect(LockOn.toggle)
	Controls.LockNext:Connect(LockOn.next)
	Net.on("LockBreak", LockOn.release)
	Controls.setHidden("LockNext", true)
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, pullCamera)
	RunService.Heartbeat:Connect(turnBody)
	player.CharacterAdded:Connect(LockOn.release)
end

return LockOn
