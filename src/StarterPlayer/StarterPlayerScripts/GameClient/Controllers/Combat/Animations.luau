--!strict
-- Player combat animations (docs/weapons_combat_brief.txt 4B, contract in docs/COMBAT_CONTRACTS.md).
-- OWNER: the Animation sub-agent. CombatController calls only the functions below; keep their names and arguments.
-- Everything else (Idle / Run / Equip stance of the equipped weapon's category, Death, Spawn, other players'
-- characters) is handled inside this module.
--   Animations.attack(character, category, step, speed) -> length   one combo step (Config/Combat Combos); the clip's
--                                                                   "Hit" marker sits at the step's Impact; returns
--                                                                   the clip length in seconds at that speed
--   Animations.cancel(character)                 stops the attack clip (Roll / Block cancels)
--   Animations.hitStop(character, seconds)       slows the character's clips to Combat.Feel.HitStopSpeed
--   Animations.block(character, on)              guard pose while Block is held
--   Animations.blockHit(character)               a hit taken while blocking
--   Animations.roll(character, direction)        the dash (world direction)
--   Animations.hurt(character)                   a hit taken
-- STUB until the Animation sub-agent delivers: the default Animate script's tool animations (toolslash / toollunge).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.GameSystem.Config.Combat)

local Animations = {}

function Animations.attack(character: Model, category: string, step: number, speed: number): number
	local tool = character:FindFirstChildOfClass("Tool")
	local shape = Combat.Shapes[category] or Combat.Shapes.Sword
	if tool then
		-- the default Animate script plays toolslash / toollunge when this value appears in the tool
		local value = Instance.new("StringValue")
		value.Name = "toolanim"
		value.Value = shape.Anim or "Slash"
		value.Parent = tool
		Debris:AddItem(value, 0.5)
	end
	return 0
end

function Animations.cancel(_character: Model) end

function Animations.hitStop(_character: Model, _seconds: number) end

function Animations.block(_character: Model, _on: boolean) end

function Animations.blockHit(_character: Model) end

function Animations.roll(_character: Model, _direction: Vector3) end

function Animations.hurt(_character: Model) end

return Animations
