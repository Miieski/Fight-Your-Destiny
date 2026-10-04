--!strict
-- Admin commands (DESIGN.md section 13). First set: money. Every command is validated here;
-- a non-admin who fires the remote is ignored.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Admins = require(ReplicatedStorage.GameSystem.Config.Admins)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local DataService = require(script.Parent.DataService)

local AdminService = { Priority = 6 }

local COMMANDS: { [string]: (Player, number) -> () } = {
	AddGold = function(player, amount)
		DataService:AddGold(player, amount)
	end,
	SetGold = function(player, amount)
		DataService:Set(player, "Gold", amount)
	end,
	AddDiamonds = function(player, amount)
		DataService:AddDiamonds(player, amount)
	end,
	SetDiamonds = function(player, amount)
		DataService:Set(player, "Diamonds", math.floor(amount))
	end,
}

function AdminService:IsAdmin(player: Player): boolean
	if Admins.AllowInStudio and RunService:IsStudio() then
		return true
	end
	if Admins.AllowCreator and game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return table.find(Admins.UserIds, player.UserId) ~= nil
end

function AdminService:Init()
	local function flag(player: Player)
		-- Only tells the client whether to show the panel; it grants nothing.
		player:SetAttribute("IsAdmin", AdminService:IsAdmin(player))
	end
	Players.PlayerAdded:Connect(flag)
	for _, player in ipairs(Players:GetPlayers()) do
		flag(player)
	end
	Net.event("Admin").OnServerEvent:Connect(function(player: Player, command: any, amount: any)
		if not AdminService:IsAdmin(player) then
			return
		end
		local handler = if typeof(command) == "string" then COMMANDS[command] else nil
		if not handler or typeof(amount) ~= "number" or amount ~= amount or amount < 0 or amount > Admins.MaxAmount then
			Net.event("Notify"):FireClient(player, "Admin: invalid command or amount", "bad")
			return
		end
		handler(player, amount)
		Net.event("Notify"):FireClient(player, `Admin: {command} {Format.number(amount)}`, "info")
	end)
end

return AdminService
