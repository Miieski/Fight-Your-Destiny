--!strict
-- Teams (docs/menu_systems_brief.txt D5): kept inside this server (not saved), up to Config/Teams.MaxMembers, one
-- leader. Requests (all validated): TeamCreate, TeamInvite(userId) (the leader; inviting without a team creates
-- one), TeamRespond(inviteId, accept), TeamLeave, TeamKick(userId) (leader), TeamDisband (leader).
-- Every member gets Net "Team" { Id, Leader, Members } on each change (nil = no team); the invited player gets
-- Net "TeamInvite". Player attributes TeamId (others' Invite lists) and Rebirths (the member rows).
--   TeamService.getTeam(player) -> { Id, Leader: Player, Members: { Player } }? (the boss gate uses it later)
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local Teams = require(ReplicatedStorage.GameSystem.Config.Teams)
local DataService = require(script.Parent.DataService)

local TeamService = { Priority = 5 }

type Team = { Id: string, Leader: Player, Members: { Player } }
type Invite = { Id: string, From: Player, To: Player, Team: Team, Expires: number }

local teams: { [string]: Team } = {}
local teamOf: { [Player]: Team } = {}
local invites: { [string]: Invite } = {}
local lastInvite: { [Player]: number } = {}

function TeamService.getTeam(player: Player): Team?
	return teamOf[player]
end

local function snapshot(team: Team): { [string]: any }
	local members = {}
	for _, member in ipairs(team.Members) do
		table.insert(members, member.UserId)
	end
	return { Id = team.Id, Leader = team.Leader.UserId, Members = members }
end

local function broadcast(team: Team)
	local data = snapshot(team)
	for _, member in ipairs(team.Members) do
		Net.fire(member, "Team", data)
	end
end

local function notify(player: Player, text: string, kind: string?)
	Net.fire(player, "Notify", { Kind = kind or "info", Text = text, Icon = "Team" })
end

local function create(player: Player): Team
	local team: Team = { Id = HttpService:GenerateGUID(false), Leader = player, Members = { player } }
	teams[team.Id] = team
	teamOf[player] = team
	player:SetAttribute("TeamId", team.Id)
	broadcast(team)
	return team
end

local function remove(player: Player, reason: string?)
	local team = teamOf[player]
	if not team then
		return
	end
	teamOf[player] = nil
	if player.Parent then
		player:SetAttribute("TeamId", nil)
		Net.fire(player, "Team", nil)
	end
	local at = table.find(team.Members, player)
	if at then
		table.remove(team.Members, at)
	end
	if #team.Members == 0 then
		teams[team.Id] = nil
		return
	end
	if team.Leader == player then
		team.Leader = team.Members[1]
		notify(team.Leader, "You are the team leader now")
	end
	for _, member in ipairs(team.Members) do
		notify(member, `{player.DisplayName} {reason or "left the team"}`)
	end
	broadcast(team)
end

local function disband(team: Team)
	for _, member in ipairs(table.clone(team.Members)) do
		teamOf[member] = nil
		if member.Parent then
			member:SetAttribute("TeamId", nil)
			Net.fire(member, "Team", nil)
			if member ~= team.Leader then
				notify(member, "The team was disbanded")
			end
		end
	end
	table.clear(team.Members)
	teams[team.Id] = nil
end

local function playerById(userId: any): Player?
	return if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

local function onCreate(player: Player): (boolean, any)
	if teamOf[player] then
		return false, "You are already in a team"
	end
	return true, snapshot(create(player))
end

local function onInvite(player: Player, userId: any): (boolean, any)
	local target = playerById(userId)
	if not target or target == player then
		return false, "Player not found"
	end
	local now = os.clock()
	if now - (lastInvite[player] or -math.huge) < Teams.InviteInterval then
		return false, "Wait a moment before the next invite"
	end
	local team = teamOf[player]
	if team and team.Leader ~= player then
		return false, "Only the leader can invite"
	end
	if teamOf[target] then
		return false, `{target.DisplayName} is already in a team`
	end
	if team and #team.Members >= Teams.MaxMembers then
		return false, `The team is full ({Teams.MaxMembers})`
	end
	for _, invite in pairs(invites) do
		if invite.To == target and invite.From == player and invite.Expires > now then
			return false, `{target.DisplayName} already has your invite`
		end
	end
	lastInvite[player] = now
	team = team or create(player)
	local invite: Invite = { Id = HttpService:GenerateGUID(false), From = player, To = target, Team = team :: Team, Expires = now + Teams.InviteSeconds }
	invites[invite.Id] = invite
	Net.fire(target, "TeamInvite", { Id = invite.Id, From = player.UserId, FromName = player.DisplayName, Seconds = Teams.InviteSeconds })
	task.delay(Teams.InviteSeconds + 1, function()
		if invites[invite.Id] == invite then
			invites[invite.Id] = nil
		end
	end)
	return true, `Invite sent to {target.DisplayName}`
end

local function onRespond(player: Player, inviteId: any, accept: any): (boolean, any)
	local invite = if typeof(inviteId) == "string" then invites[inviteId] else nil
	if not invite or invite.To ~= player or typeof(accept) ~= "boolean" then
		return false, "This invite is no longer valid"
	end
	invites[invite.Id] = nil
	if invite.Expires < os.clock() then
		return false, "This invite has expired"
	end
	local team = invite.Team
	if not accept then
		if invite.From.Parent then
			notify(invite.From, `{player.DisplayName} declined your invite`)
		end
		return true, nil
	end
	if not teams[team.Id] then
		return false, "This team does not exist any more"
	end
	if teamOf[player] then
		return false, "Leave your team first"
	end
	if #team.Members >= Teams.MaxMembers then
		return false, "The team is full"
	end
	table.insert(team.Members, player)
	teamOf[player] = team
	player:SetAttribute("TeamId", team.Id)
	for _, member in ipairs(team.Members) do
		if member ~= player then
			notify(member, `{player.DisplayName} joined the team`, "reward")
		end
	end
	broadcast(team)
	return true, snapshot(team)
end

local function onLeave(player: Player): (boolean, any)
	if not teamOf[player] then
		return false, "You are not in a team"
	end
	remove(player)
	return true, nil
end

local function onKick(player: Player, userId: any): (boolean, any)
	local team = teamOf[player]
	local target = playerById(userId)
	if not team or team.Leader ~= player then
		return false, "Only the leader can kick"
	end
	if not target or target == player or teamOf[target] ~= team then
		return false, "Not in your team"
	end
	remove(target, "was removed from the team")
	notify(target, "You were removed from the team")
	return true, nil
end

local function onDisband(player: Player): (boolean, any)
	local team = teamOf[player]
	if not team or team.Leader ~= player then
		return false, "Only the leader can disband"
	end
	disband(team)
	return true, nil
end

function TeamService:Init()
	Net.handle("TeamCreate", onCreate, 0.5)
	Net.handle("TeamInvite", onInvite, 0.3)
	Net.handle("TeamRespond", onRespond, 0.3)
	Net.handle("TeamLeave", onLeave, 0.5)
	Net.handle("TeamKick", onKick, 0.3)
	Net.handle("TeamDisband", onDisband, 0.5)
	Players.PlayerRemoving:Connect(function(player)
		remove(player, "left the game")
		lastInvite[player] = nil
		for id, invite in pairs(invites) do
			if invite.From == player or invite.To == player then
				invites[id] = nil
			end
		end
	end)
	-- the member rows show the Rebirths of other players
	local function rebirths(player: Player)
		local profile = DataService:Get(player)
		player:SetAttribute("Rebirths", if profile then profile.Rebirths or 0 else 0)
	end
	DataService.Loaded:Connect(rebirths)
	-- profiles loaded before this service started listening (Studio play solo)
	for _, player in ipairs(Players:GetPlayers()) do
		if DataService:Get(player) then
			rebirths(player)
		end
	end
	DataService.Changed:Connect(function(player: Player, key: string)
		if key == "Rebirths" then
			rebirths(player)
		end
	end)
end

return TeamService
