--!strict
-- Admin commands (DESIGN.md section 13). First set: money. Every command is validated here;
-- a non-admin who fires the remote is ignored.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Admins = require(ReplicatedStorage.GameSystem.Config.Admins)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local DataService = require(script.Parent.DataService)
local ZoneService = require(script.Parent.ZoneService)

local AdminService = { Priority = 6 }

local COMMANDS: { [string]: (Player, number, any) -> () } = {
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
	-- Opens every sub-zone gate of every zone for this player (the amount is ignored).
	UnlockAll = function(player, _amount)
		local unlocked = {}
		for _, zone in ipairs(Zones.List) do
			for n = 2, Zones.SUBZONE_COUNT do
				unlocked[Zones.subZoneId(zone.Id, n)] = true
			end
		end
		DataService:Set(player, "SubZones", unlocked)
	end,
	-- amount = sub-zone 1..4, 5 = the zone's boss arena, 0 = hub; extra = zone id ("Plains", ...).
	-- The sub-zones up to the target are unlocked first so the player is not sent back.
	Teleport = function(player, amount, extra)
		local zone = if typeof(extra) == "string" then Zones.ById[extra] else nil
		local n = math.floor(amount)
		if not zone or n < 1 then
			ZoneService:ToHub(player)
			return
		end
		local profile = DataService:Get(player)
		if profile then
			local unlocked = table.clone(profile.SubZones)
			for i = 2, math.min(n, Zones.SUBZONE_COUNT) do
				unlocked[Zones.subZoneId(zone.Id, i)] = true
			end
			DataService:Set(player, "SubZones", unlocked)
		end
		if n > Zones.SUBZONE_COUNT then
			ZoneService:EnterArena(player, zone.Id)
		else
			ZoneService:TeleportTo(player, zone.Id, n)
		end
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
	Net.event("Admin").OnServerEvent:Connect(function(player: Player, command: any, amount: any, extra: any)
		if not AdminService:IsAdmin(player) then
			return
		end
		local handler = if typeof(command) == "string" then COMMANDS[command] else nil
		if not handler or typeof(amount) ~= "number" or amount ~= amount or amount < 0 or amount > Admins.MaxAmount then
			Net.event("Notify"):FireClient(player, "Admin: invalid command or amount", "bad")
			return
		end
		handler(player, amount, extra)
		if command ~= "Teleport" then
			Net.event("Notify"):FireClient(player, `Admin: {command} {Format.number(amount)}`, "info")
		end
	end)
end

return AdminService
