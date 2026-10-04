--!strict
-- PLACEHOLDER profile: lives in memory for the session only (no DataStore yet).
-- Keys follow the data model of DESIGN.md section 11 so the real DataService can replace it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.GameSystem.Net)
local Playtest = require(ReplicatedStorage.GameSystem.Config.Playtest)

local DataService = { Priority = 1 }

local profiles: { [Player]: { [string]: any } } = {}

function DataService:Get(player: Player): { [string]: any }?
	return profiles[player]
end

-- Sets a top-level key and replicates the whole value to the owner.
function DataService:Set(player: Player, key: string, value: any)
	local profile = profiles[player]
	if profile then
		profile[key] = value
		Net.event("Data"):FireClient(player, { [key] = value })
	end
end

function DataService:AddGold(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		DataService:Set(player, "Gold", math.max(0, profile.Gold + amount))
	end
end

function DataService:Init()
	local function add(player: Player)
		local profile = { Gold = Playtest.StartGold, SubZones = {}, CurrentZone = "Hub" }
		profiles[player] = profile
		Net.event("Data"):FireClient(player, profile)
		if RunService:IsStudio() then
			-- Studio-only test hook: setting the attribute "DebugGold" on the server adds that much Gold.
			player:GetAttributeChangedSignal("DebugGold"):Connect(function()
				local amount = player:GetAttribute("DebugGold")
				if typeof(amount) == "number" and amount ~= 0 then
					DataService:AddGold(player, amount)
					player:SetAttribute("DebugGold", 0)
				end
			end)
		end
	end
	Players.PlayerAdded:Connect(add)
	for _, player in ipairs(Players:GetPlayers()) do
		add(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
	end)
end

return DataService
