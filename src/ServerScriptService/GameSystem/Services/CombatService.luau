--!strict
-- PLACEHOLDER combat: one melee swing with a Common sword of the zone the player stands in.
-- The client only sends "I attack"; range, arc, cooldown, crit and damage are decided here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local Playtest = require(ReplicatedStorage.GameSystem.Config.Playtest)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local EnemyService = require(script.Parent.EnemyService)

local CombatService = { Priority = 5 }

local lastAttack: { [Player]: number } = {}
local rng = Random.new()

function CombatService:Init()
	Net.event("Attack").OnServerEvent:Connect(function(player: Player)
		local now = os.clock()
		if now - (lastAttack[player] or 0) < Playtest.AttackCooldown * 0.9 then
			return
		end
		lastAttack[player] = now
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local zone = Zones.ById[player:GetAttribute("ZoneId") or ""]
		if not (humanoid and humanoid.Health > 0 and root and zone) then
			return
		end
		local origin = root.Position
		local look = root.CFrame.LookVector
		local targets = {}
		for _, state in ipairs(EnemyService:GetNear(origin, Playtest.AttackRange)) do
			local offset = state.model:GetPivot().Position - origin
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude < 4 or flat.Unit:Dot(look) >= Playtest.AttackArcDot then
				table.insert(targets, { state = state, distance = flat.Magnitude })
			end
		end
		table.sort(targets, function(a, b)
			return a.distance < b.distance
		end)
		local base = Playtest.WeaponBaseDamage * 10 ^ (zone.Index - 1)
		for i = 1, math.min(#targets, Playtest.MaxTargets) do
			local state = targets[i].state
			local crit = rng:NextNumber() < Playtest.CritChance
			local damage = base * (if crit then Playtest.CritMultiplier else 1)
			local hitPosition = state.model:GetPivot().Position + Vector3.new(0, 3 + state.radius, 0)
			EnemyService:Damage(player, state, damage)
			Net.event("Hit"):FireClient(player, hitPosition, damage, crit)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
	end)
end

return CombatService
