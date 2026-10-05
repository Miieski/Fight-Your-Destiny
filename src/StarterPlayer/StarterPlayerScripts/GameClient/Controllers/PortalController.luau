--!strict
-- Hub portals (docs/menu_systems_brief.txt section 1). Touching workspace.Hub.Portals.Portal_<ZoneId> asks the
-- server to go straight to sub-zone 1 of that zone (Net "UsePortal"; the server checks everything). The
-- screen fades like the Zones menu. Each portal also shows THIS player's state (docs/enemies_npcs_pets_brief.txt 1A):
-- a locked zone's portal and its frame are under a BLACK FILTER (every color black / dark gray, a dark swirl, no
-- zone name or icon) with a "? ? ?" sign and the generic requirement. When the zone unlocks, a reveal plays: white
-- flash, the black filter dissolves into the zone colors, the name comes back.
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
local ZoneVisibility = require(UI.Kit.ZoneVisibility)
local TweenService = game:GetService("TweenService")

local PortalController = { Priority = 20 }

local LOCKED_COLOR = Color3.fromRGB(105, 105, 112)
local FILTER_DARK = Color3.fromRGB(16, 14, 20) -- the black filter: frame parts
local FILTER_PORTAL = Color3.fromRGB(28, 20, 40) -- the portal surface: an almost black purple swirl
local REVEAL_SECONDS = 1.2
local HIDDEN_TEXT = "? ? ?"
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
	row.Size = UDim2.fromScale(1, 0.55)
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
	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.fromScale(1, 0.62)
	hint.Position = UDim2.fromScale(0.5, 1.12)
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.FontFace = Theme.Fonts.Body
	hint.TextScaled = true
	hint.TextWrapped = true
	hint.TextColor3 = Theme.Colors.Text
	local hintStroke = Instance.new("UIStroke")
	hintStroke.Color = Theme.Colors.Ink
	hintStroke.Thickness = 1.5
	hintStroke.Parent = hint
	hint.Parent = row
	gui.Size = UDim2.fromScale(8, 4.4)
	gui.Parent = portal
	return gui
end

type Look = { color: Color3, material: Enum.Material }
local looks: { [BasePart]: Look } = {}
local revealed: { [string]: boolean } = {}

local function frameOf(zoneId: string): Instance?
	local hub = workspace:FindFirstChild("Hub")
	local decor = hub and hub:FindFirstChild("Decor")
	local frames = decor and decor:FindFirstChild("PortalFrames")
	return frames and frames:FindFirstChild("PortalFrame_" .. zoneId)
end

-- every part and every name text of a portal (the portal surface first)
local function pieces(portal: BasePart): ({ BasePart }, { TextLabel })
	local parts: { BasePart } = { portal }
	local texts: { TextLabel } = {}
	local frame = frameOf(portal:GetAttribute("ZoneId") :: string)
	for _, root in ipairs({ portal :: Instance, frame } :: { Instance? }) do
		if root then
			for _, item in ipairs(root:GetDescendants()) do
				if item:IsA("BasePart") then
					table.insert(parts, item)
				elseif item:IsA("TextLabel") and item.Name == "NameLabel" then
					table.insert(texts, item)
				end
			end
		end
	end
	return parts, texts
end

local function remember(part: BasePart)
	if not looks[part] then
		looks[part] = { color = part.Color, material = part.Material }
		part:SetAttribute("RealName", nil)
	end
end

-- the zone-colored swirl effects of the portal (Hub.Decor.VFX.Portal_Swirl_<ZoneId>): off under the black filter
local function zoneEffects(zoneId: string, on: boolean)
	local hub = workspace:FindFirstChild("Hub")
	local decor = hub and hub:FindFirstChild("Decor")
	local vfx = decor and decor:FindFirstChild("VFX")
	local fx = vfx and vfx:FindFirstChild("Portal_Swirl_" .. zoneId)
	if not fx then
		return
	end
	for _, item in ipairs(fx:GetDescendants()) do
		if item:IsA("ParticleEmitter") or item:IsA("Light") or item:IsA("Beam") then
			if item:GetAttribute("WasEnabled") == nil then
				item:SetAttribute("WasEnabled", item.Enabled)
			end
			item.Enabled = on and item:GetAttribute("WasEnabled") == true
			if not on and item:IsA("ParticleEmitter") then
				item:Clear()
			end
		end
	end
end

local function swirl(portal: BasePart, on: boolean)
	local existing = portal:FindFirstChild("DarkSwirl")
	if on and not existing then
		local fx = Instance.new("ParticleEmitter")
		fx.Name = "DarkSwirl"
		fx.Color = ColorSequence.new(Color3.fromRGB(10, 8, 14), Color3.fromRGB(60, 40, 90))
		fx.Texture = "rbxasset://textures/particles/smoke_main.dds"
		fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
		fx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		fx.Lifetime = NumberRange.new(1.5, 2.5)
		fx.Rate = 6
		fx.Speed = NumberRange.new(0.5, 1.5)
		fx.RotSpeed = NumberRange.new(-120, 120)
		fx.Rotation = NumberRange.new(0, 360)
		fx.SpreadAngle = Vector2.new(30, 30)
		fx.Parent = portal
	elseif not on and existing then
		existing:Destroy()
	end
end

local function realName(label: TextLabel): string
	local saved = label:GetAttribute("RealName")
	if typeof(saved) ~= "string" then
		saved = label.Text
		label:SetAttribute("RealName", saved)
	end
	return saved :: string
end

-- Black filter on / off. animate = the reveal (white flash, colors dissolve back, name appears).
local function filter(portal: BasePart, hidden: boolean, animate: boolean)
	local parts, texts = pieces(portal)
	for _, part in ipairs(parts) do
		remember(part)
	end
	for _, label in ipairs(texts) do
		realName(label)
	end
	swirl(portal, hidden)
	zoneEffects(portal:GetAttribute("ZoneId") :: string, not hidden)
	if hidden then
		for i, part in ipairs(parts) do
			part.Color = if i == 1 then FILTER_PORTAL else FILTER_DARK
		end
		for _, label in ipairs(texts) do
			label.Text = HIDDEN_TEXT
		end
		return
	end
	for _, label in ipairs(texts) do
		label.Text = realName(label)
	end
	if not animate then
		for _, part in ipairs(parts) do
			part.Color = looks[part].color
		end
		return
	end
	-- reveal: a white flash over the portal, then the colors come back
	local flash = Instance.new("Part")
	flash.Anchored = true
	flash.CanCollide, flash.CanQuery, flash.CanTouch = false, false, false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.new(1, 1, 1)
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * 4
	flash.CFrame = portal.CFrame
	flash.Transparency = 0.05
	flash.Parent = workspace
	TweenService:Create(flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 26, Transparency = 1 }):Play()
	task.delay(0.7, function()
		flash:Destroy()
	end)
	for _, part in ipairs(parts) do
		part.Color = Color3.new(1, 1, 1)
		TweenService:Create(part, TweenInfo.new(REVEAL_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Color = looks[part].color }):Play()
	end
	Sfx.play("Unlock", portal.Position)
end

local function paint(portal: BasePart)
	local zoneId = portal:GetAttribute("ZoneId") :: string
	if original[portal] == nil then
		original[portal] = portal.Color
	end
	local notBuilt = Zones.NOT_BUILT[zoneId] == true
	local hidden = not ZoneVisibility.isRevealed(zoneId)
	local was = revealed[zoneId]
	if was == nil or was == hidden then
		-- first paint or a change: black filter on, or the reveal (only animated when it happens live)
		filter(portal, hidden, was ~= nil and not hidden)
		revealed[zoneId] = not hidden
	elseif hidden then
		filter(portal, true, false) -- streamed-in parts get the filter too
	end
	local gui = sign(portal)
	gui.Enabled = hidden or notBuilt
	local label = gui:FindFirstChild("Text", true) :: TextLabel
	label.Text = if notBuilt and not hidden then "Coming soon" else HIDDEN_TEXT
	local hint = gui:FindFirstChild("Hint", true) :: TextLabel?
	if hint then
		hint.Text = if hidden then ZoneVisibility.requirement(zoneId) else ""
		hint.Visible = hidden
	end
	local lock = gui:FindFirstChild("Lock", true)
	if lock then
		(lock :: GuiObject).Visible = hidden
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
	Notifier.push({ Kind = if ok then "info" else "error", Text = tostring(if called then message or "Portal failed" else "Portal failed"), Icon = if ok and ZoneVisibility.isRevealed(zone.Id) then zone.Id else "Lock" })
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
