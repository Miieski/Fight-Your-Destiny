--!strict
-- Shared screens (one ScreenGui each, created on first use). Display orders:
-- Vignette 0 < Hud 1 < Controls 5 < Toasts 15 < Windows 20.
local Theme = require(script.Parent.Theme)

local Screens = {}

local roots: { [string]: Frame } = {}

function Screens.get(name: string, displayOrder: number): Frame
	local root = roots[name]
	if not root then
		local _, created = Theme.screen(name, displayOrder)
		root = created
		roots[name] = created
	end
	return root
end

function Screens.hud(): Frame
	return Screens.get("Hud", 1)
end

return Screens
