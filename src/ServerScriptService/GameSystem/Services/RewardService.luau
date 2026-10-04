--!strict
-- RewardService (stub). Daily rewards, playtime gifts, quests, codes and boosts will live here
-- (DESIGN.md sections 9 and 10). For now only the Redeem Code box of the Settings window answers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)

local RewardService = { Priority = 7 }

local MAX_CODE_LENGTH = 30

function RewardService:Init()
	Net.handle("RedeemCode", function(_player: Player, code: any)
		if typeof(code) ~= "string" or #code == 0 or #code > MAX_CODE_LENGTH then
			return false, "Enter a code"
		end
		return false, "Codes are not available yet"
	end, 1)
end

return RewardService
