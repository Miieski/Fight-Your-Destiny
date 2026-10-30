--!strict
-- Skills, server side. Net.request("UseSkill", slot, aimDir, aimPoint) -> true, or false + the reason: the slot's skill for
-- the equipped weapon (Config/Skills), its cooldown (a small tolerance for the network) and cost are decided here; the
-- move itself runs through CombatService (same hit shapes and rate rules as an attack).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local Skills = require(ReplicatedStorage.GameSystem.Config.Skills)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)

local SkillService = { Priority = 6 }

local readyAt: { [Player]: { [string]: number } } = {}

function SkillService:Start()
	Net.handle("UseSkill", function(player: Player, slot: any, aimDir: any, aimPoint: any)
		if not Skills.validSlot(slot) then
			return false, Skills.Text.InvalidSlot
		end
		local profile = DataService:Get(player)
		local item = profile and profile.EquippedWeapon and profile.Weapons[profile.EquippedWeapon]
		local weapon = item and Weapons.ById[item.id]
		local skill = Skills.at(slot, if weapon then weapon.Category else nil, profile and profile.EquippedSkills)
		if not skill then
			return false, Skills.Text.NotAvailable
		end
		local cooldowns = readyAt[player]
		if not cooldowns then
			cooldowns = {}
			readyAt[player] = cooldowns
		end
		local now = os.clock()
		if now < (cooldowns[skill.Id] or 0) - Skills.COOLDOWN_TOLERANCE then
			return false, Skills.RESOURCE_ERROR
		end
		if not CombatService:Skill(player, aimDir, aimPoint) then
			return false, Skills.RESOURCE_ERROR
		end
		cooldowns[skill.Id] = now + skill.Cooldown
		return true
	end, Skills.USE_INTERVAL)
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return SkillService
