--!strict
-- Visual comfort settings: Low FX (fewer particles) and camera shake (Screen Shake + intensity).
--   Fx.shake(strength 0..1)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local Settings = require(script.Parent.SettingsController)

local Fx = { Priority = 6 }

local baseRates: { [ParticleEmitter]: number } = {}
local low = false
local humanoid: Humanoid? = nil
local shakeConnection: RBXScriptConnection? = nil
local shakeEnd, shakeAmount = 0, 0
local rng = Random.new()

local function track(instance: Instance)
	if instance:IsA("ParticleEmitter") and baseRates[instance] == nil then
		baseRates[instance] = instance.Rate
		if low then
			instance.Rate = instance.Rate * UIConfig.Fx.LowFxRateFactor
		end
	end
end

local function setLow(value: boolean)
	if value == low then
		return
	end
	low = value
	for emitter, rate in pairs(baseRates) do
		if emitter.Parent then
			emitter.Rate = if low then rate * UIConfig.Fx.LowFxRateFactor else rate
		else
			baseRates[emitter] = nil
		end
	end
end

local function stopShake()
	if shakeConnection then
		shakeConnection:Disconnect()
		shakeConnection = nil
	end
	shakeAmount = 0
	if humanoid then
		humanoid.CameraOffset = Vector3.zero
	end
end

function Fx.shake(strength: number)
	if not Settings.get("ScreenShake") or not humanoid then
		return
	end
	local amount = math.clamp(strength, 0, 1) * (Settings.get("ShakeIntensity") or 0) / 100 * UIConfig.Fx.ShakeMaxOffset
	if amount <= 0 then
		return
	end
	shakeAmount = math.max(shakeAmount, amount)
	shakeEnd = os.clock() + UIConfig.Fx.ShakeSeconds
	if not shakeConnection then
		shakeConnection = RunService.RenderStepped:Connect(function()
			local remaining = shakeEnd - os.clock()
			if remaining <= 0 or not humanoid then
				stopShake()
				return
			end
			local a = shakeAmount * remaining / UIConfig.Fx.ShakeSeconds;
			(humanoid :: Humanoid).CameraOffset = Vector3.new(rng:NextNumber(-a, a), rng:NextNumber(-a, a), rng:NextNumber(-a, a) * 0.5)
		end)
	end
end

local function onCharacter(character: Model)
	stopShake()
	humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local last = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		local lost = last - health
		last = health
		if lost > 0 and humanoid then
			Fx.shake(lost / math.max(1, humanoid.MaxHealth) / UIConfig.Fx.DamageShakeFraction)
		end
	end)
end

function Fx:Start()
	for _, instance in ipairs(workspace:GetDescendants()) do
		track(instance)
	end
	workspace.DescendantAdded:Connect(track)
	setLow(Settings.get("LowFx") == true)
	Settings.changed("LowFx", function(value)
		setLow(value == true)
	end)
	Settings.changed("ScreenShake", function(value)
		if not value then
			stopShake()
		end
	end)
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return Fx
