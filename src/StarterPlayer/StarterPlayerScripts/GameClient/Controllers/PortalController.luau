--!strict
-- Hub portals (docs/menu_systems_brief.txt section 1). Touching workspace.Hub.Portals.Portal_<ZoneId> asks the
-- server to go straight to sub-zone 1 of that zone (Net "UsePortal"; the server checks everything). The
-- screen fades like the Zones menu. Each portal also shows THIS player's state: a locked zone's portal is
-- gray with a lock and "Locked", a zone that is not built yet says "Coming soon".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.State)
local UI = script.Parent.Parent.UI
local Notifier = require(UI.Notifier)
local Fade = require(UI.Kit.Fade)
local Icons = require(UI.Kit.Icons)
local Theme = require(UI.Kit.Theme)

local PortalController = { Priority = 20 }

local LOCKED_COLOR = Color3.fromRGB(105, 105, 112)
local REFRESH_SECONDS = 2 -- portals can stream in and out: their look is re-applied regularly

local busy = false
local lastTry: { [string]: number } = {} -- zone id -> os.clock() of the last refused try
local original: { [BasePart]: Color3 } = {}

local function portals(): { BasePart }
	local list = {}
	local hub = workspace:FindFirstChild("Hub")
	local folder = hub and hub:FindFirstChild("Portals")
	for _, portal in ipairs(if folder then folder:GetChildren() else {}) do
		if portal:IsA("BasePart") and typeof(portal:GetAttribute("ZoneId")) == "string" then
			table.insert(list, portal)
		end
	end
	return list
end

local function isOpen(zoneId: string): boolean
	local zone = Zones.ById[zoneId]
	return zone ~= nil and (zone.Index == 1 or (State.get("Zones") or {})[zoneId] == true)
end

-- The "Locked" / "Coming soon" sign in the portal (created once, shown or hidden).
local function sign(portal: BasePart): BillboardGui
	local existing = portal:FindFirstChild("PortalState")
	if existing then
		return existing :: BillboardGui
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PortalState"
	gui.Size = UDim2.fromScale(7, 2.6)
	gui.StudsOffset = Vector3.new(0, -1, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.Enabled = false
	local row = Instance.new("Frame")
	row.BackgroundColor3 = Theme.Colors.WoodInset
	row.BackgroundTransparency = 0.15
	row.Size = UDim2.fromScale(1, 1)
	Theme.corner(row, 10)
	Theme.stroke(row, Theme.Colors.GoldDark, 2)
	row.Parent = gui
	Icons.create("Lock", row, { Size = UDim2.new(0, 0, 0.8, 0), Position = UDim2.new(0.04, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) }).Name = "Lock"
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.66, 0.8)
	label.Position = UDim2.fromScale(0.3, 0.1)
	label.FontFace = Theme.Fonts.Title
	label.TextScaled = true
	label.TextColor3 = Theme.Colors.Gold
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Ink
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = row
	gui.Parent = portal
	return gui
end

local function paint(portal: BasePart)
	local zoneId = portal:GetAttribute("ZoneId") :: string
	if original[portal] == nil then
		original[portal] = portal.Color
	end
	local notBuilt = Zones.NOT_BUILT[zoneId] == true
	local locked = not isOpen(zoneId)
	portal.Color = if locked or notBuilt then LOCKED_COLOR else original[portal]
	local gui = sign(portal)
	gui.Enabled = locked or notBuilt
	local label = gui:FindFirstChild("Text", true) :: TextLabel
	label.Text = if notBuilt then "Coming soon" else "Locked"
	local lock = gui:FindFirstChild("Lock", true)
	if lock then
		(lock :: GuiObject).Visible = locked and not notBuilt
	end
end

local function refresh()
	for _, portal in ipairs(portals()) do
		paint(portal)
	end
end

local function use(zoneId: string)
	if busy then
		return
	end
	local now = os.clock()
	if now - (lastTry[zoneId] or -math.huge) < Zones.TELEPORT.PortalRetry then
		return
	end
	local zone = Zones.ById[zoneId]
	if not zone then
		return
	end
	busy = true
	-- a portal that cannot open (locked, coming soon) answers without the fade
	local expectOk = isOpen(zoneId) and not Zones.NOT_BUILT[zoneId]
	if expectOk then
		Fade.cover()
	end
	local called, ok, message = pcall(Net.request, "UsePortal", zoneId)
	ok = called and ok == true
	if ok then
		Sfx.play("PortalEnter")
		lastTry[zoneId] = nil
	else
		lastTry[zoneId] = os.clock()
		Sfx.play("Denied")
	end
	Notifier.push({ Kind = if ok then "info" else "error", Text = tostring(if called then message or "Portal failed" else "Portal failed"), Icon = if ok then zone.Id else "Lock" })
	if expectOk then
		Fade.reveal(ok)
	end
	busy = false
end

function PortalController:Start()
	local player = Players.LocalPlayer
	local hooked: { [BasePart]: boolean } = {}
	local function hook()
		for _, portal in ipairs(portals()) do
			if not hooked[portal] then
				hooked[portal] = true
				local zoneId = portal:GetAttribute("ZoneId") :: string
				portal.Touched:Connect(function(hit)
					local character = player.Character
					if character and hit:IsDescendantOf(character) then
						task.spawn(use, zoneId)
					end
				end)
			end
		end
	end
	State.changed("Zones", refresh)
	while true do
		hook()
		refresh()
		task.wait(REFRESH_SECONDS)
	end
end

return PortalController
