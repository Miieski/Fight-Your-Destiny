--!strict
-- Skills, server side (docs/weapons_combat_brief.txt Phase 2): framework only. Net.request("UseSkill", slot)
-- validates the slot and answers false, "not available" until the skills exist (Config/Skills). Cooldowns, costs
-- and effects will be decided here (server authoritative); the client only shows the result.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local Skills = require(ReplicatedStorage.GameSystem.Config.Skills)
local DataService = require(script.Parent.DataService)

local SkillService = { Priority = 6 }

function SkillService:Start()
	Net.handle("UseSkill", function(player: Player, slot: any)
		if not Skills.validSlot(slot) then
			return false, Skills.Text.InvalidSlot
		end
		local profile = DataService:Get(player)
		local equipped = profile and profile.EquippedSkills
		local id = if typeof(equipped) == "table" then equipped[slot] else nil
		if not (typeof(id) == "string" and Skills.ById[id]) then
			return false, Skills.Text.NotAvailable
		end
		-- the skills are not built yet: nothing can be used
		return false, Skills.Text.NotAvailable
	end, Skills.USE_INTERVAL)
end

return SkillService
