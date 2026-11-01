--!strict
-- The "Aura of Mastery" passive: a soft glow around any player whose attribute MasteryAura names the weapon type in hand
-- (MasteryService sets it). Each client draws it; one emitter per character, nothing per frame.
local Players = game:GetService("Players")

local MasteryAuraController = {}

local COLORS = {
	Sword = Color3.fromRGB(255, 226, 150), Spear = Color3.fromRGB(150, 220, 255), Heavy = Color3.fromRGB(255, 170, 110),
	Dagger = Color3.fromRGB(190, 130, 255), Ranged = Color3.fromRGB(150, 255, 170), Magic = Color3.fromRGB(255, 120, 80),
}

local function apply(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local category = player:GetAttribute("MasteryAura")
	local fx = root:FindFirstChild("MasteryAura") :: ParticleEmitter?
	if not category then
		if fx then
			fx:Destroy()
		end
		return
	end
	if not fx then
		local new = Instance.new("ParticleEmitter")
		new.Name = "MasteryAura"
		new.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		new.Rate = 6
		new.Lifetime = NumberRange.new(0.7, 1.2)
		new.Speed = NumberRange.new(1, 2)
		new.SpreadAngle = Vector2.new(180, 180)
		new.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		new.LightEmission = 0.6
		new.Parent = root
		fx = new
	end
	(fx :: ParticleEmitter).Color = ColorSequence.new(COLORS[category] or Color3.new(1, 1, 1))
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("MasteryAura"):Connect(function()
		apply(player)
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		apply(player)
	end)
	apply(player)
end

function MasteryAuraController:Start()
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
end

return MasteryAuraController
