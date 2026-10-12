--!strict
-- Display name of a key binding (Config/Settings KEY_ACTIONS values): "Left Click", "Q" (the letter of the
-- player's keyboard layout), "Left Alt", "None".
local UserInputService = game:GetService("UserInputService")

local MOUSE_LABELS = { MouseButton1 = "Left Click", MouseButton2 = "Right Click", MouseButton3 = "Middle Click" }
local KEY_LABELS = { LeftControl = "Left Ctrl", RightControl = "Right Ctrl", None = "None" }

return function(name: string): string
	local fixed = MOUSE_LABELS[name] or KEY_LABELS[name]
	if fixed then
		return fixed
	end
	local ok, text = pcall(function()
		return UserInputService:GetStringForKeyCode((Enum.KeyCode :: any)[name])
	end)
	if ok and typeof(text) == "string" and #text == 1 and text ~= " " then
		return string.upper(text)
	end
	return (string.gsub(name, "(%l)(%u)", "%1 %2")) -- "LeftAlt" -> "Left Alt"
end
