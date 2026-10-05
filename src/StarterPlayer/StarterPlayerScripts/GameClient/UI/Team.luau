--!strict
-- Teams on the client (docs/menu_systems_brief.txt D5): the Team window (Team and Invite tabs), the invite popup
-- (Accept / Decline, expires) and the HUD party list (shown while in a team). The server (TeamService) owns the
-- teams: this only shows Net "Team" / "TeamInvite" and sends the requests.
--   Team.buildPage(ctx)   (Windows.luau, Team window)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Teams = require(ReplicatedStorage.GameSystem.Config.Teams)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local Notifier = require(script.Parent.Notifier)
local Kit = script.Parent.Kit
local Button = require(Kit.Button)
local Icons = require(Kit.Icons)
local Panel = require(Kit.Panel)
local Screens = require(Kit.Screens)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local TeamUI = { Priority = 15 }

type Snapshot = { Id: string, Leader: number, Members: { number } }

local current: Snapshot? = nil
local changedEvent = Instance.new("BindableEvent")
local friends: { [number]: boolean } = {}
local busy = false

local function request(action: string, ...: any): (boolean, any)
	if busy then
		return false, nil
	end
	busy = true
	local called, ok, result = pcall(Net.request, action, ...)
	busy = false
	if called and ok then
		return true, result
	end
	Sfx.play("Denied")
	Notifier.push({ Kind = "error", Text = if called and typeof(result) == "string" then result else "Something went wrong", Icon = "Team" })
	return false, nil
end

local function headshot(userId: number): string
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

local function zoneText(player: Player): string
	local zone = player:GetAttribute("CurrentZone")
	local def = if typeof(zone) == "string" then Zones.ById[zone] else nil
	return if def then def.Name else UIConfig.Text.HubZone
end

local function isFriend(player: Player): boolean
	local known = friends[player.UserId]
	if known == nil then
		friends[player.UserId] = false
		task.spawn(function()
			local ok, result = pcall(function()
				return Players.LocalPlayer:IsFriendsWith(player.UserId)
			end)
			friends[player.UserId] = ok and result == true
		end)
		return false
	end
	return known
end

local function portrait(parent: Instance, userId: number, size: number, position: UDim2)
	local ring = Instance.new("Frame")
	ring.Size = UDim2.fromOffset(size, size)
	ring.Position = position
	ring.AnchorPoint = Vector2.new(0, 0.5)
	ring.BackgroundColor3 = Theme.Colors.WoodInset
	ring.ZIndex = 3
	Theme.round(ring)
	Theme.stroke(ring, Theme.Colors.GoldLight, 2)
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = headshot(userId)
	image.ZIndex = 4
	Theme.round(image)
	image.Parent = ring
	ring.Parent = parent
end

local function rowFrame(parent: Instance, order: number, height: number): Frame
	local row = Instance.new("Frame")
	row.BackgroundColor3 = Theme.Colors.WoodTop
	row.Size = UDim2.new(1, -8, 0, height)
	row.LayoutOrder = order
	row.ZIndex = 2
	Theme.corner(row, 8)
	Theme.stroke(row, Theme.Colors.GoldDark, 2)
	row.Parent = parent
	return row
end

local function clear(page: Instance)
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

----------------------------------------------------------------------------------------------------
-- window
----------------------------------------------------------------------------------------------------
local function buildTeamTab(page: ScrollingFrame, ctx: any)
	clear(page)
	local me = Players.LocalPlayer
	local team = current
	if not team then
		Theme.text({ Text = `You are not in a team. Create one, or accept an invite. Up to {Teams.MaxMembers} players fight bosses together.`, TextSize = 21, Wrapped = true, Size = UDim2.new(1, -8, 0, 60), LayoutOrder = 1, Parent = page })
		Button.new({ Name = "CreateTeam", Text = "Create Team", Icon = "Team", Style = "go", Size = UDim2.fromOffset(280, Theme.TOUCH), LayoutOrder = 2, Parent = page, OnClick = function()
			if request("TeamCreate") then
				Sfx.play("UIClick")
			end
		end })
		Button.new({ Text = "Invite players", Style = "secondary", Size = UDim2.fromOffset(280, Theme.TOUCH), LayoutOrder = 3, Parent = page, OnClick = function()
			ctx.Select("Invite")
		end })
		return
	end
	local leader = team.Leader == me.UserId
	Theme.text({ Font = "Title", Text = `Your team ({#team.Members}/{Teams.MaxMembers})`, TextSize = 28, Color = Theme.Colors.Gold, Size = UDim2.new(1, -8, 0, 36), LayoutOrder = 0, Parent = page })
	local rowH = if Theme.isCompact() then 64 else 76
	for index, userId in ipairs(team.Members) do
		local player = Players:GetPlayerByUserId(userId)
		local row = rowFrame(page, index, rowH)
		portrait(row, userId, rowH - 14, UDim2.new(0, 8, 0.5, 0))
		local x = rowH + 4
		local name = Theme.text({ Font = "Button", Text = if player then player.DisplayName else "?", TextSize = 22, Align = "Left", Size = UDim2.new(0.45, -x, 0, 28), Position = UDim2.fromOffset(x, 8), ZIndex = 3, Parent = row })
		if userId == team.Leader then
			Icons.create("Crown", row, { Size = UDim2.fromOffset(28, 28), Position = UDim2.new(0, x - 34, 0, 4), AnchorPoint = Vector2.zero, ZIndex = 5 })
			name.TextColor3 = Theme.Colors.Gold
		end
		if player then
			Theme.text({ Text = `Rebirth {player:GetAttribute("Rebirths") or 0}   |   {zoneText(player)}`, TextSize = 17, Color = Theme.Colors.TextDim, Align = "Left", Size = UDim2.new(0.5, -x, 0, 22), Position = UDim2.fromOffset(x, 38), ZIndex = 3, Parent = row })
		end
		if leader and userId ~= me.UserId then
			Button.new({ Name = "Kick", Text = "Kick", Style = "danger", TextSize = 20, Size = UDim2.fromOffset(140, Theme.TOUCH), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 3, Parent = row, OnClick = function()
				Window.confirm({ Title = "Kick?", Text = `Remove {if player then player.DisplayName else "this player"} from the team?`, ConfirmText = "Kick", CancelText = "Cancel", OnConfirm = function()
					request("TeamKick", userId)
				end })
			end })
		elseif userId == me.UserId then
			Theme.text({ Text = "You", TextSize = 18, Color = Theme.Colors.Good, Align = "Right", Size = UDim2.fromOffset(120, 24), Position = UDim2.new(1, -16, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 3, Parent = row })
		end
	end
	local bar = Instance.new("Frame")
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, -8, 0, Theme.TOUCH)
	bar.LayoutOrder = 50
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 12)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = bar
	bar.Parent = page
	if leader then
		Button.new({ Text = "Invite players", Icon = "Plus", Style = "primary", Size = UDim2.fromOffset(240, Theme.TOUCH), LayoutOrder = 1, Parent = bar, OnClick = function()
			ctx.Select("Invite")
		end })
	end
	Button.new({ Name = "Leave", Text = "Leave", Style = "secondary", Size = UDim2.fromOffset(200, Theme.TOUCH), LayoutOrder = 2, Parent = bar, OnClick = function()
		if request("TeamLeave") then
			Sfx.play("UIClick")
		end
	end })
	if leader then
		Button.new({ Name = "Disband", Text = "Disband", Style = "danger", Size = UDim2.fromOffset(200, Theme.TOUCH), LayoutOrder = 3, Parent = bar, OnClick = function()
			Window.confirm({ Title = "Disband the team?", Text = "Every member leaves the team.", ConfirmText = "Disband", CancelText = "Cancel", OnConfirm = function()
				request("TeamDisband")
			end })
		end })
	end
end

local function buildInviteTab(page: ScrollingFrame)
	clear(page)
	local me = Players.LocalPlayer
	local myRoot = me.Character and me.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local entries = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= me then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local distance = if root and myRoot then (root.Position - myRoot.Position).Magnitude else math.huge
			table.insert(entries, { player = player, friend = isFriend(player), distance = distance })
		end
	end
	-- friends first, then the nearest
	table.sort(entries, function(a, b)
		if a.friend ~= b.friend then
			return a.friend
		end
		return a.distance < b.distance
	end)
	Theme.text({ Text = `Friends first, then players near you. An invite lasts {Teams.InviteSeconds} seconds.`, TextSize = 18, Color = Theme.Colors.TextDim, Size = UDim2.new(1, -8, 0, 28), LayoutOrder = 0, Parent = page })
	if #entries == 0 then
		Theme.text({ Text = "No other players in this server yet.", TextSize = 22, Size = UDim2.new(1, -8, 0, 50), LayoutOrder = 1, Parent = page })
		return
	end
	local team = current
	local canInvite = team == nil or (team.Leader == me.UserId and #team.Members < Teams.MaxMembers)
	local rowH = if Theme.isCompact() then 60 else 70
	for index, entry in ipairs(entries) do
		local player = entry.player
		local row = rowFrame(page, index, rowH)
		portrait(row, player.UserId, rowH - 14, UDim2.new(0, 8, 0.5, 0))
		local x = rowH + 4
		Theme.text({ Font = "Button", Text = player.DisplayName, TextSize = 21, Align = "Left", Size = UDim2.new(0.45, -x, 0, 26), Position = UDim2.fromOffset(x, 6), ZIndex = 3, Parent = row })
		local where = if entry.distance < math.huge then `{math.floor(entry.distance)} studs` else "far away"
		Theme.text({ Text = `{if entry.friend then "Friend  |  " else ""}{zoneText(player)}  |  {where}`, TextSize = 16, Color = if entry.friend then Theme.Colors.Good else Theme.Colors.TextDim, Align = "Left", Size = UDim2.new(0.5, -x, 0, 20), Position = UDim2.fromOffset(x, 36), ZIndex = 3, Parent = row })
		local inTeam = player:GetAttribute("TeamId") ~= nil
		local mine = team ~= nil and player:GetAttribute("TeamId") == team.Id
		local button = Button.new({ Text = if mine then "In your team" elseif inTeam then "In a team" else "Invite", Style = if canInvite and not inTeam then "go" else "disabled", TextSize = 20, Size = UDim2.fromOffset(170, Theme.TOUCH), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 3, Parent = row, OnClick = function()
			if inTeam or not canInvite then
				return
			end
			local ok, message = request("TeamInvite", player.UserId)
			if ok then
				Sfx.play("UIClick")
				Notifier.push({ Kind = "info", Text = tostring(message), Icon = "Team" })
			end
		end })
		button.Instance.Name = "Invite"
	end
end

function TeamUI.buildPage(ctx: any)
	local function refresh()
		buildTeamTab(ctx.Pages.Team, ctx)
		buildInviteTab(ctx.Pages.Invite)
	end
	refresh()
	changedEvent.Event:Connect(refresh)
	-- zones, distances and team flags change without a team event: refresh the open window now and then
	task.spawn(function()
		while true do
			task.wait(2)
			if ctx.Frame.Visible then
				refresh()
			end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- invite popup and party list
----------------------------------------------------------------------------------------------------
local queue: { any } = {}
local showing = false
local popupRoot: Frame? = nil

local function showNext()
	if showing or #queue == 0 then
		return
	end
	local invite = table.remove(queue, 1)
	if os.clock() > invite.expires then
		showNext()
		return
	end
	showing = true
	if not popupRoot then
		local _, root = Theme.screen("TeamInvite", 28)
		popupRoot = root
	end
	local panel = Panel.new({ Name = "Invite", Size = UDim2.fromOffset(440, 170), Position = UDim2.new(0.5, 0, 0, 120), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 2, Parent = popupRoot })
	panel.Active = true
	portrait(panel, invite.from, 64, UDim2.new(0, 16, 0, 52))
	Theme.text({ Text = `{invite.name} invites you to their team`, TextSize = 22, Wrapped = true, Align = "Left", Size = UDim2.new(1, -110, 0, 56), Position = UDim2.fromOffset(92, 10), ZIndex = 3, Parent = panel })
	local timer = Theme.text({ Font = "Number", Text = "", TextSize = 16, Color = Theme.Colors.TextDim, Align = "Left", Size = UDim2.new(1, -110, 0, 20), Position = UDim2.fromOffset(92, 66), ZIndex = 3, Parent = panel })
	local done = false
	local function finish(accept: boolean?)
		if done then
			return
		end
		done = true
		panel:Destroy()
		showing = false
		if accept ~= nil then
			local ok = request("TeamRespond", invite.id, accept)
			if ok and accept then
				Sfx.play("Unlock")
				Notifier.push({ Kind = "reward", Text = `You joined {invite.name}'s team`, Icon = "Team" })
			end
		end
		showNext()
	end
	Button.new({ Name = "Accept", Text = "Accept", Style = "go", Size = UDim2.new(0.5, -24, 0, Theme.TOUCH), Position = UDim2.new(0, 16, 1, -12), AnchorPoint = Vector2.new(0, 1), ZIndex = 3, Parent = panel, OnClick = function()
		finish(true)
	end })
	Button.new({ Name = "Decline", Text = "Decline", Style = "secondary", Size = UDim2.new(0.5, -24, 0, Theme.TOUCH), Position = UDim2.new(1, -16, 1, -12), AnchorPoint = Vector2.new(1, 1), ZIndex = 3, Parent = panel, OnClick = function()
		finish(false)
	end })
	Sfx.play("UIOpen")
	task.spawn(function()
		while not done do
			local left = invite.expires - os.clock()
			if left <= 0 then
				finish(nil) -- expired: nothing to send
				return
			end
			timer.Text = `Expires in {math.ceil(left)} s`
			task.wait(0.25)
		end
	end)
end

local partyFrame: Frame
local function refreshParty()
	for _, child in ipairs(partyFrame:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local team = current
	partyFrame.Visible = team ~= nil
	if not team then
		return
	end
	for index, userId in ipairs(team.Members) do
		local player = Players:GetPlayerByUserId(userId)
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Theme.Colors.WoodInset
		row.BackgroundTransparency = 0.25
		row.Size = UDim2.new(1, 0, 0, 32)
		row.LayoutOrder = index
		Theme.corner(row, 16)
		row.Parent = partyFrame
		portrait(row, userId, 28, UDim2.new(0, 2, 0.5, 0))
		local label = Theme.text({ Font = "Button", Text = if player then player.DisplayName else "?", TextSize = 16, Align = "Left", Size = UDim2.new(1, -60, 1, -6), Position = UDim2.new(0, 36, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3, Parent = row })
		if userId == team.Leader then
			label.TextColor3 = Theme.Colors.Gold
			Icons.create("Crown", row, { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -4, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 4 })
		end
	end
end

function TeamUI:Start()
	partyFrame = Instance.new("Frame")
	partyFrame.Name = "Party"
	partyFrame.BackgroundTransparency = 1
	partyFrame.Size = UDim2.fromOffset(180, Teams.MaxMembers * 36)
	partyFrame.Visible = false
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = partyFrame
	partyFrame.Parent = Screens.hud()
	local function place()
		-- right of the health bar's column: under the bar on PC / tablet, beside the menu toggle on phones
		local health = UIConfig.Hud.Health
		partyFrame.Position = if Theme.isCompact() then UDim2.fromOffset(200, health.Top + 64) else UDim2.fromOffset(200, health.Top + 70)
	end
	place()
	Theme.Changed:Connect(place)
	Net.on("Team", function(data: any)
		current = if typeof(data) == "table" then data else nil
		refreshParty()
		changedEvent:Fire()
	end)
	Net.on("TeamInvite", function(data: any)
		if typeof(data) ~= "table" or typeof(data.Id) ~= "string" then
			return
		end
		table.insert(queue, { id = data.Id, from = tonumber(data.From) or 0, name = tostring(data.FromName), expires = os.clock() + (tonumber(data.Seconds) or Teams.InviteSeconds) - 1 })
		showNext()
	end)
end

return TeamUI
