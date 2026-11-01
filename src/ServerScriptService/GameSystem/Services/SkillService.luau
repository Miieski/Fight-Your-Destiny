--!strict
-- Skills, server side. Net.request("UseSkill", slot, aimDir, aimPoint) -> true, or false + the reason: the slot's skill for
-- the equipped weapon (Config/Skills), its cooldown (a small tolerance for the network) and cost are decided here; the
-- move itself runs through CombatService (same hit shapes and rate rules as an attack).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local Skills = require(ReplicatedStorage.GameSystem.Config.Skills)
local WeaponMastery = require(ReplicatedStorage.GameSystem.Config.WeaponMastery)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local ManaService = require(script.Parent.ManaService)

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
		if skill.Move and not WeaponMastery.hasSkill(profile, skill.Category, skill.Id) then
			return false, Skills.Text.NotAvailable
		end
		local stats = CombatService:Stats(player)
		local cost = if skill.Cost then skill.Cost * ((stats and stats.ManaCostMult) or 1) else nil
		local cooldowns = readyAt[player]
		if not cooldowns then
			cooldowns = {}
			readyAt[player] = cooldowns
		end
		local now = os.clock()
		if now < (cooldowns[skill.Id] or 0) - Skills.COOLDOWN_TOLERANCE then
			return false, Skills.RESOURCE_ERROR
		end
		if cost and not ManaService:Has(player, cost) then
			Net.fire(player, "NoMana")
			return false, Skills.RESOURCE_ERROR
		end
		if not CombatService:Skill(player, aimDir, aimPoint, skill.Move) then
			return false, Skills.RESOURCE_ERROR
		end
		if cost then
			ManaService:Spend(player, cost)
		end
		cooldowns[skill.Id] = now + skill.Cooldown * ((stats and stats.SkillCooldownMult) or 1)
		return true
	end, Skills.USE_INTERVAL)
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return SkillService
