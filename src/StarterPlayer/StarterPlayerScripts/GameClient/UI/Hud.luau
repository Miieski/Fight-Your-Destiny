--!strict
-- PLACEHOLDER HUD: Gold counter, zone banner and short notifications. The real wood UI kit
-- (DESIGN.md section 1) replaces this later.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.State)

local Hud = { Priority = 10 }

local WOOD = Color3.fromRGB(74, 48, 32)
local GOLD = Color3.fromRGB(255, 201, 60)
local GOLD_BORDER = Color3.fromRGB(232, 180, 74)
local KIND_COLORS = { info = Color3.new(1, 1, 1), good = Color3.fromRGB(91, 220, 110), bad = Color3.fromRGB(255, 96, 96) }
local BASE_HEIGHT = 720 -- the layout is designed for this viewport height
local BANNER_SECONDS = 2.5
local NOTIFY_SECONDS = 2.5

local goldLabel: TextLabel
local banner: TextLabel
local notice: TextLabel
local bannerToken, noticeToken = 0, 0

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Fantasy
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	for key, value in pairs(props) do
		(text :: any)[key] = value
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(40, 24, 12)
	stroke.Parent = text
	text.Parent = parent
	return text
end

local function flash(target: TextLabel, seconds: number, token: number, current: () -> number)
	local stroke = target:FindFirstChildOfClass("UIStroke")
	target.TextTransparency = 0
	if stroke then
		stroke.Transparency = 0
	end
	target.Visible = true
	task.delay(seconds, function()
		if current() == token then
			TweenService:Create(target, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end
	end)
end

local function locationText(zoneId: string, subZoneId: string): string
	local zone = Zones.ById[zoneId]
	if not zone then
		return "Hub"
	end
	if string.sub(subZoneId, -6) == "_Arena" then
		return `{zone.Boss}'s Lair`
	end
	local _, n = Zones.parseSubZoneId(subZoneId)
	local subZoneName = n and zone.SubZones[n]
	return if subZoneName and subZoneName ~= zone.Name then `{zone.Name} - {subZoneName}` else zone.Name
end

function Hud:Init()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local camera = workspace.CurrentCamera
	local function rescale()
		scale.Scale = math.clamp(camera.ViewportSize.Y / BASE_HEIGHT, 0.6, 1.5)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	local panel = Instance.new("Frame")
	panel.Name = "GoldPanel"
	panel.Position = UDim2.fromOffset(12, 12)
	panel.Size = UDim2.fromOffset(190, 48)
	panel.BackgroundColor3 = WOOD
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel
	local border = Instance.new("UIStroke")
	border.Thickness = 3
	border.Color = GOLD_BORDER
	border.Parent = panel
	local coin = Instance.new("Frame")
	coin.Position = UDim2.fromOffset(8, 8)
	coin.Size = UDim2.fromOffset(32, 32)
	coin.BackgroundColor3 = GOLD
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = coin
	coin.Parent = panel
	goldLabel = label(panel, { Name = "Gold", Position = UDim2.fromOffset(48, 6), Size = UDim2.fromOffset(134, 36), TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Text = "0" })
	panel.Parent = gui

	banner = label(gui, { Name = "Banner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(520, 56), Text = "", TextTransparency = 1 })
	notice = label(gui, { Name = "Notice", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -120), Size = UDim2.fromOffset(520, 40), Text = "", TextTransparency = 1 })
	for _, hidden in ipairs({ banner, notice }) do
		(hidden:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = 1
	end
	gui.Parent = player:WaitForChild("PlayerGui")
end

function Hud:Start()
	local player = Players.LocalPlayer
	goldLabel.Text = Format.number(State.get("Gold") or 0)
	State.Changed:Connect(function(key, value)
		if key == "Gold" then
			goldLabel.Text = Format.number(value)
		end
	end)
	local function showLocation()
		bannerToken += 1
		banner.Text = locationText(player:GetAttribute("ZoneId") or "Hub", player:GetAttribute("SubZoneId") or "Hub")
		flash(banner, BANNER_SECONDS, bannerToken, function()
			return bannerToken
		end)
	end
	player:GetAttributeChangedSignal("SubZoneId"):Connect(showLocation)
	showLocation()
	Net.event("Notify").OnClientEvent:Connect(function(text: string, kind: string)
		noticeToken += 1
		notice.Text = text
		notice.TextColor3 = KIND_COLORS[kind] or KIND_COLORS.info
		flash(notice, NOTIFY_SECONDS, noticeToken, function()
			return noticeToken
		end)
	end)
end

return Hud
