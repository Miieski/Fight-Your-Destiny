--!strict
-- PLACEHOLDER combat input: hold the attack input to swing at the test cooldown. The server
-- decides hits and damage; this only sends the request and shows damage numbers.
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Playtest = require(ReplicatedStorage.GameSystem.Config.Playtest)

local CombatController = {}

local ACTION = "Attack"
local NUMBER_TIME = 0.7
local holding = false
local rng = Random.new()

local function burst(name: string, position: Vector3)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local vfx = assets and assets.VFX:FindFirstChild(name)
	if vfx and vfx:IsA("BasePart") then
		local clone = vfx:Clone()
		clone.CFrame = CFrame.new(position)
		clone.Parent = workspace
		for _, emitter in ipairs(clone:GetDescendants()) do
			if emitter:IsA("ParticleEmitter") then
				emitter:Emit(emitter:GetAttribute("EmitCount") or 8)
			end
		end
		Debris:AddItem(clone, 1.5)
	end
end

local function damageNumber(position: Vector3, amount: number, crit: boolean)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
	local gui = Instance.new("BillboardGui")
	gui.Size = if crit then UDim2.fromScale(7, 2.6) else UDim2.fromScale(5, 1.8)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Fantasy
	label.TextScaled = true
	label.Text = Format.number(amount) .. (if crit then "!" else "")
	label.TextColor3 = if crit then Color3.fromRGB(255, 201, 60) else Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	anchor.Parent = workspace
	TweenService:Create(gui, TweenInfo.new(NUMBER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(NUMBER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, NUMBER_TIME + 0.1)
end

function CombatController:Start()
	Net.event("Hit").OnClientEvent:Connect(function(position: Vector3, amount: number, crit: boolean)
		damageNumber(position, amount, crit)
		burst(if crit then "Crit_Spark" else "Hit_Spark", position - Vector3.new(0, 1.5, 0))
	end)
	ContextActionService:BindAction(ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			if not holding then
				holding = true
				task.spawn(function()
					while holding do
						Net.event("Attack"):FireServer()
						task.wait(Playtest.AttackCooldown)
					end
				end)
			end
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			holding = false
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle(ACTION, "Attack")
	ContextActionService:SetPosition(ACTION, UDim2.new(1, -120, 1, -160))
end

return CombatController
