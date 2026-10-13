--!strict
-- Realistic wood everywhere (owner 2026-10-13): every inset box of the UI (a Frame painted Theme.Colors.WoodInset -
-- window contents, cards, slots, rows) gets the dark-grain wood texture (Kit/Panel.wood "Inset") without touching
-- each page. The texture hides itself while the frame shows another color (a Secret rarity cell, a highlight).
local Players = game:GetService("Players")

local Kit = script.Parent.Kit
local Panel = require(Kit.Panel)
local Theme = require(Kit.Theme)

local WoodSkin = { Priority = 1 }

local MIN_SIZE = 18 -- design units: thinner frames (lines, bars) stay flat

local function corner(frame: Frame): number
	local c = frame:FindFirstChildOfClass("UICorner")
	if not c then
		return 0
	end
	return c.CornerRadius.Offset
end

local function skin(frame: Frame)
	if frame:GetAttribute("WoodSkin") ~= nil or frame:IsA("ScrollingFrame") then
		return
	end
	frame:SetAttribute("WoodSkin", true)
	local texture: ImageLabel? = nil
	local function update()
		local wanted = frame.BackgroundColor3 == Theme.Colors.WoodInset and frame.BackgroundTransparency < 0.5
		if wanted and not texture then
			local size = frame.AbsoluteSize / Theme.getScale()
			if size.X > 0 and (size.X < MIN_SIZE or size.Y < MIN_SIZE) then
				return
			end
			texture = Panel.wood(frame, "Inset", nil, corner(frame))
		end
		if texture then
			texture.Visible = wanted
		end
	end
	frame:GetPropertyChangedSignal("BackgroundColor3"):Connect(update)
	frame:GetPropertyChangedSignal("BackgroundTransparency"):Connect(update)
	update()
end

local function consider(item: Instance)
	if item:IsA("Frame") and not item:IsA("ScrollingFrame") then
		-- the color is often set after the frame is created, before it is parented: look once it settles
		task.defer(function()
			if item.Parent and (item :: Frame).BackgroundColor3 == Theme.Colors.WoodInset then
				skin(item :: Frame)
			end
		end)
	end
end

function WoodSkin:Start()
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui.DescendantAdded:Connect(consider)
	for _, item in ipairs(gui:GetDescendants()) do
		consider(item)
	end
end

return WoodSkin
