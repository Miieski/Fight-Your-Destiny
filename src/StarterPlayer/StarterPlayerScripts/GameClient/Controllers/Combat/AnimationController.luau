--!strict
-- The one entry for "play this attack state on this character" (docs/animation_system.md). The local prediction
-- (CombatController, at the press) and every other player's state (Net "Swing") both come here, so a character looks the
-- same on every client: clip (Combat/Animations), trail and effects (VFX), whoosh (Sfx.combat). All the data is in
-- Config/WeaponMoves: a new weapon needs no new code.
--   AnimationController.play(state) -> length of the clip in seconds
--     state = { Character, Category, Step, Variant?, Speed, Aim?, Direction?, IsLocal }
--     Variant: nil (combo step) | "Heavy" | "Air" | "Dash" | "Skill" | "Charge" (the hold's wind-up: clip only)
--   AnimationController.tool(character) -> Tool?, rarity?, element?, zone?   the held weapon
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local WeaponMoves = require(ReplicatedStorage.GameSystem.Config.WeaponMoves)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)

local Animations = require(script.Parent.Animations)
local VFX = require(script.Parent.Parent.VFX.VFX)

local AnimationController = {}

-- The held weapon: Tool, rarity, element and zone (1..12: the zone fighting style, Config/CombatStyles).
function AnimationController.tool(character: Model): (Tool?, number?, string?, number?)
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		return nil, nil, nil, nil
	end
	local def = Weapons.ById[tool:GetAttribute("WeaponId") or ""]
	local rarity = tool:GetAttribute("Rarity")
	local zone = tool:GetAttribute("Zone")
	return tool, if typeof(rarity) == "number" then rarity else nil, if def then def.Element else nil, if typeof(zone) == "number" then zone elseif def then def.Zone else nil
end

function AnimationController.play(state: { [string]: any }): number
	local character, category, step, variant, speed = state.Character, state.Category, state.Step, state.Variant, state.Speed
	if variant == "Charge" then
		Animations.charge(character, category, speed)
		return 0
	end
	local length = Animations.attack(character, category, step, speed, state.Aim, variant)
	local move = WeaponMoves.move(category, step, variant)
	local tool, rarity, element, zone = AnimationController.tool(character)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local ctx = {
		Character = character,
		Tool = tool,
		Category = category,
		Step = step,
		Variant = variant,
		Finisher = variant == "Air" or variant == "Heavy" or variant == "Skill" or (variant == nil and move ~= nil and move.Finisher == true),
		Direction = state.Direction or Vector3.new(0, 0, -1),
		Rarity = rarity,
		Element = element,
		Zone = zone,
		Speed = speed,
		IsLocal = state.IsLocal == true,
		Position = if not state.IsLocal and root then root.Position else nil,
	}
	VFX.swing(ctx)
	Sfx.combat("Swing", ctx)
	return length
end

return AnimationController
