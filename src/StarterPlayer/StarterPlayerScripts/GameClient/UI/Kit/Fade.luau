--!strict
-- Black screen fade around a teleport (Zones menu and hub portals).
--   Fade.cover()   fades to black and waits until the screen is black
--   Fade.reveal()  fades back in (waits SETTLE_SECONDS first when settle = true) and waits until done
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Fade = {}

local INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad)
local DISPLAY_ORDER = 25 -- above the windows (20), below the toasts (30)
Fade.SETTLE_SECONDS = 0.35 -- wait for the character to arrive before fading back in

local frame: Frame? = nil

local function get(): Frame
	if frame then
		return frame
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "TeleportFade"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = DISPLAY_ORDER
	local black = Instance.new("Frame")
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 1
	black.Size = UDim2.fromScale(1, 1)
	black.Visible = false
	black.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	frame = black
	return black
end

function Fade.cover()
	local black = get()
	black.Visible = true
	local tween = TweenService:Create(black, INFO, { BackgroundTransparency = 0 })
	tween:Play()
	tween.Completed:Wait()
end

function Fade.reveal(settle: boolean?)
	local black = get()
	if settle then
		task.wait(Fade.SETTLE_SECONDS)
	end
	local tween = TweenService:Create(black, INFO, { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Wait()
	black.Visible = false
end

return Fade
