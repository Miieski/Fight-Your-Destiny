--!strict
-- Hub NPCs on the client (docs/enemies_npcs_pets_brief.txt Part F, Config/NPCs, server NPCService): Idle loop,
-- a Wave when the local player comes within NPCs.WAVE_RANGE, the head turning toward the player within
-- NPCs.LOOK_RANGE, and Talk while the player uses the NPC's prompt. Clips: Config/RigClips (Biped) via AnimPlayer.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NPCs = require(ReplicatedStorage.GameSystem.Config.NPCs)
local AnimPlayer = require(script.Parent.AnimPlayer)

local NPCController = {}

local player = Players.LocalPlayer
local MAX_YAW, MAX_PITCH = math.rad(70), math.rad(25)

type Entry = { model: Model, root: BasePart, anim: any, head: Motor6D?, near: boolean, yaw: number, pitch: number }
local entries: { [Model]: Entry } = {}

local function add(model: Instance)
	if not model:IsA("Model") or entries[model] then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local head: Motor6D? = nil
	for _, joint in ipairs(model:GetDescendants()) do
		if joint:IsA("Motor6D") and joint.Part1 and joint.Part1.Name == "Head" then
			head = joint
		end
	end
	entries[model] = { model = model, root = root, anim = AnimPlayer.new(model, "Biped", NPCs.HEIGHT), head = head, near = false, yaw = 0, pitch = 0 }
end

function NPCController:Start()
	local hub = workspace:WaitForChild("Hub", 30)
	local folder = hub and hub:WaitForChild("NPCs", 30)
	if not folder then
		return
	end
	folder.ChildAdded:Connect(function(child)
		task.defer(add, child)
	end)
	folder.ChildRemoved:Connect(function(child)
		entries[child :: Model] = nil
	end)
	for _, child in ipairs(folder:GetChildren()) do
		add(child)
	end
	task.spawn(function()
		while true do -- streaming: models can arrive without their parts
			for _, child in ipairs(folder:GetChildren()) do
				local entry = entries[child :: Model]
				if entry and not entry.root.Parent then
					entries[child :: Model] = nil
				elseif not entry then
					add(child)
				end
			end
			task.wait(2)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local id = prompt:GetAttribute("NpcId")
		if typeof(id) ~= "string" then
			return
		end
		for model, entry in pairs(entries) do
			if model:GetAttribute("NpcId") == id then
				entry.anim:Action("Talk", { duration = NPCs.TALK_SECONDS })
			end
		end
	end)
	RunService.PreRender:Connect(function(dt: number)
		local character = player.Character
		local myRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = workspace.CurrentCamera
		for model, entry in pairs(entries) do
			if not model.Parent then
				entries[model] = nil
				continue
			end
			local root = entry.root
			if camera and (camera.CFrame.Position - root.Position).Magnitude > 160 then
				continue
			end
			local distance = if myRoot then (myRoot.Position - root.Position).Magnitude else math.huge
			local near = distance <= NPCs.WAVE_RANGE
			if near and not entry.near and entry.anim:ActionName() == nil then
				entry.anim:Action("Wave", { duration = 1.6 })
			end
			entry.near = near
			entry.anim:SetLocomotion(0, 12)
			entry.anim:Update(dt)
			-- head turn toward the player (on top of the clip)
			local yaw, pitch = 0, 0
			if myRoot and distance <= NPCs.LOOK_RANGE then
				local localDir = root.CFrame:VectorToObjectSpace(myRoot.Position + Vector3.new(0, 1.5, 0) - (root.Position + Vector3.new(0, 2, 0)))
				yaw = math.clamp(math.atan2(-localDir.X, -localDir.Z), -MAX_YAW, MAX_YAW)
				pitch = math.clamp(math.atan2(localDir.Y, Vector2.new(localDir.X, localDir.Z).Magnitude), -MAX_PITCH, MAX_PITCH)
			end
			local k = math.min(1, dt * 6)
			entry.yaw += (yaw - entry.yaw) * k
			entry.pitch += (pitch - entry.pitch) * k
			if entry.head then
				entry.head.Transform = CFrame.Angles(0, entry.yaw, 0) * CFrame.Angles(entry.pitch, 0, 0) * entry.head.Transform
			end
		end
	end)
end

return NPCController
