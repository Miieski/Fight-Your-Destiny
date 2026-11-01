--!strict
-- Full-screen transition (Rebirth, later the boss doors): a quick fade, an optional text with a small spinner, input
-- blocked for as long as it lasts, and a watchdog so that a failed step can never leave the screen covered.
--   Transition.show({ Text?, Spinner?, Color?, FadeIn?, Lock?, Watchdog?, OnTimeout? })
--   Transition.hide(seconds?, keepCamera?)   normal end: fades out, gives the input back (keepCamera: the caller eases it)
--   Transition.restore()        forced end: everything back at once (overlay, input, camera)
--   Transition.isActive()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local InputLock = require(script.Parent.InputLock)
local Theme = require(script.Parent.Theme)

local Transition = {}

local DISPLAY_ORDER = 40 -- above the windows (20) and the toasts (30)
local DEFAULT = { Color = Color3.fromRGB(24, 16, 10), FadeIn = 0.25, FadeOut = 0.35, SpinnerSize = 44, SpinTurnsPerSecond = 1.1 }

type Parts = { gui: ScreenGui, cover: TextButton, label: TextLabel, ring: Frame, stroke: UIStroke, gradient: UIGradient }

local parts: Parts? = nil
local active = false
local lockReason: string? = nil
local token = 0 -- each show / hide owns the transition; a stale watchdog or fade does nothing
local spin: RBXScriptConnection? = nil

local function get(): Parts
	if parts then
		return parts
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Transition"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = DISPLAY_ORDER
	gui.Enabled = false
	local cover = Instance.new("TextButton") -- a button: it catches every click and touch while it is up
	cover.Name = "Cover"
	cover.Text = ""
	cover.AutoButtonColor = false
	cover.BorderSizePixel = 0
	cover.BackgroundTransparency = 1
	cover.Size = UDim2.fromScale(1, 1)
	cover.Parent = gui
	local label = Theme.text({ Font = "Title", Text = "", TextSize = 34, Color = Theme.Colors.Gold, Size = UDim2.new(1, -32, 0, 44), Position = UDim2.new(0.5, 0, 0.5, -30), AnchorPoint = Vector2.new(0.5, 1), Parent = cover })
	local ring = Instance.new("Frame")
	ring.Name = "Spinner"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.fromOffset(DEFAULT.SpinnerSize, DEFAULT.SpinnerSize)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	Theme.round(ring)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Theme.Colors.Gold
	stroke.Parent = ring
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(0.72, 1), NumberSequenceKeypoint.new(1, 1) })
	gradient.Parent = stroke
	ring.Parent = cover
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local built: Parts = { gui = gui, cover = cover, label = label, ring = ring, stroke = stroke, gradient = gradient }
	parts = built
	return built
end

local function stopSpin()
	if spin then
		spin:Disconnect()
		spin = nil
	end
end

local function setAlpha(p: Parts, seconds: number, transparency: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad)
	TweenService:Create(p.cover, info, { BackgroundTransparency = transparency }):Play()
	TweenService:Create(p.label, info, { TextTransparency = transparency, TextStrokeTransparency = transparency }):Play()
	TweenService:Create(p.stroke, info, { Transparency = transparency }):Play()
end

-- The camera back on the character (a fresh character, or a scripted camera left behind).
local function resetCamera()
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

local function releaseLock()
	if lockReason then
		InputLock.release(lockReason)
		lockReason = nil
	end
end

function Transition.isActive(): boolean
	return active
end

function Transition.show(props: { [string]: any })
	local p = get()
	token += 1
	local mine = token
	active = true
	lockReason = props.Lock or "Transition"
	InputLock.acquire(lockReason :: string)
	p.cover.BackgroundColor3 = props.Color or DEFAULT.Color
	p.label.Text = props.Text or ""
	p.ring.Visible = props.Spinner == true
	p.gui.Enabled = true
	setAlpha(p, props.FadeIn or DEFAULT.FadeIn, 0)
	stopSpin()
	if props.Spinner then
		spin = RunService.Heartbeat:Connect(function(dt)
			p.gradient.Rotation = (p.gradient.Rotation + 360 * DEFAULT.SpinTurnsPerSecond * dt) % 360
		end)
	end
	if props.Watchdog then
		task.delay(props.Watchdog, function()
			if mine == token and active then
				Transition.restore()
				if props.OnTimeout then
					props.OnTimeout()
				end
			end
		end)
	end
end

function Transition.hide(seconds: number?, keepCamera: boolean?)
	if not active then
		return
	end
	local p = get()
	token += 1
	local mine = token
	local fade = seconds or DEFAULT.FadeOut
	setAlpha(p, fade, 1)
	if not keepCamera then
		resetCamera()
	end
	task.delay(fade, function()
		if mine == token then
			active = false
			stopSpin()
			p.gui.Enabled = false
			releaseLock()
		end
	end)
end

function Transition.restore()
	token += 1
	active = false
	stopSpin()
	local p = get()
	p.cover.BackgroundTransparency = 1
	p.gui.Enabled = false
	lockReason = nil
	InputLock.releaseAll()
	resetCamera()
end

return Transition
