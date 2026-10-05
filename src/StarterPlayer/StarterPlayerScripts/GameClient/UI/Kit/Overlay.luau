--!strict
-- A panel over the current window (dim behind it; a tap on the dim or the X closes it). One at a time.
--   local panel = Overlay.open(parentFrame, Vector2.new(w, h))   (parentFrame = the window frame, ctx.Frame)
--   Overlay.close(), Overlay.isOpen(), Overlay.onClose(fn)   (fn runs once when this overlay closes)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Button = require(script.Parent.Button)
local Panel = require(script.Parent.Panel)
local Theme = require(script.Parent.Theme)

local Overlay = {}

local current: Frame? = nil
local cleanups: { () -> () } = {}

function Overlay.close()
	local list = cleanups
	cleanups = {}
	for _, fn in ipairs(list) do
		task.spawn(fn)
	end
	if current then
		current:Destroy()
		current = nil
	end
end

function Overlay.isOpen(): boolean
	return current ~= nil
end

function Overlay.onClose(fn: () -> ())
	table.insert(cleanups, fn)
end

function Overlay.open(parent: GuiObject, size: Vector2): Frame
	Overlay.close()
	local holder = Instance.new("Frame")
	holder.Name = "Overlay"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 20
	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = Theme.Colors.Black
	dim.BackgroundTransparency = 0.4
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 20
	Theme.corner(dim, 8)
	dim.Activated:Connect(Overlay.close)
	dim.Parent = holder
	local parentSize = parent.AbsoluteSize / Theme.getScale()
	local w, h = math.min(size.X, parentSize.X - 24), math.min(size.Y, parentSize.Y - 24)
	local panel = Panel.new({ Name = "Panel", Size = UDim2.fromOffset(w, h), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 21, Parent = holder })
	panel.Active = true -- clicks on the panel must not reach the dim
	Button.new({ Name = "Close", Style = "wood", Icon = "Close", Size = UDim2.fromOffset(Theme.TOUCH, Theme.TOUCH), Position = UDim2.new(1, -8, 0, 8), AnchorPoint = Vector2.new(1, 0), ZIndex = 24, OnClick = Overlay.close, Parent = panel })
	holder.Parent = parent
	current = holder
	Sfx.play("UIOpen")
	return panel
end

return Overlay
