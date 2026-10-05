--!strict
-- HUD: the active timed boosts (Gold Boost x2) under the currency bars with the time left; a tap opens
-- Shop > Diamonds. Hidden when no boost is active. Updated once a second.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boosts = require(ReplicatedStorage.GameSystem.Config.Boosts)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local State = require(script.Parent.Parent.State)
local Kit = script.Parent.Kit
local Icons = require(Kit.Icons)
local Screens = require(Kit.Screens)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local BoostTimer = { Priority = 12 }

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = seconds // 3600, (seconds // 60) % 60, seconds % 60
	return if h > 0 then string.format("%d:%02d:%02d", h, m, s) else string.format("%d:%02d", m, s)
end

function BoostTimer:Start()
	local button = Instance.new("TextButton")
	button.Name = "BoostTimer"
	button.Text = ""
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(1, 0)
	button.Size = UDim2.fromOffset(200, 44)
	button.BackgroundColor3 = Theme.Colors.WoodInset
	button.BackgroundTransparency = 0.1
	button.Visible = false
	Theme.corner(button, 22)
	Theme.stroke(button, Theme.Colors.Good, 2)
	Icons.create("Gold", button, { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 2, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 2 })
	local label = Theme.text({ Font = "Number", Text = "", TextSize = 20, Color = Theme.Colors.Good, Align = "Left", Size = UDim2.new(1, -52, 1, -8), Position = UDim2.new(0, 46, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 2, Parent = button })
	button.Activated:Connect(function()
		Window.open("Shop", "Diamonds")
	end)
	button.Parent = Screens.hud()
	local function place()
		-- under the two currency bars (Config/UI Currencies)
		if Theme.isCompact() then
			-- phones: left of the Diamonds bar (the right side below the bars belongs to the action buttons)
			local sizes = UIConfig.Currencies.Compact
			button.Size = UDim2.fromOffset(150, 36)
			button.Position = UDim2.new(1, -(12 + UIConfig.Currencies.Diamonds.CompactWidth + 10), 0, sizes.Top + sizes.Icon + sizes.Gap + (sizes.Icon - 36) / 2)
		else
			-- PC / tablet: under the bars, left of the admin crown (which sits at the right edge on that row)
			local sizes = UIConfig.Currencies.Normal
			button.Size = UDim2.fromOffset(200, 44)
			button.Position = UDim2.new(1, -(20 + Theme.TOUCH), 0, sizes.Top + 2 * (sizes.Icon + sizes.Gap) + 6)
		end
	end
	place()
	Theme.Changed:Connect(place)
	task.spawn(function()
		while true do
			local left = Boosts.remaining(State.get("Boosts"), "GoldX2", os.time())
			button.Visible = left > 0
			if left > 0 then
				label.Text = `Gold x2  {clock(left)}`
			end
			task.wait(1)
		end
	end)
end

return BoostTimer
