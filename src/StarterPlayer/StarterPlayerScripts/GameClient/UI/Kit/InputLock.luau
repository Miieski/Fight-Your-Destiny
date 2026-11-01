--!strict
-- Blocks the player's input while a short transition runs (Rebirth, boss doors). Counted per reason, so two
-- transitions never unlock each other. Every acquire needs a release; releaseAll is the safety net of the watchdogs.
--   InputLock.acquire(reason), InputLock.release(reason), InputLock.releaseAll(), InputLock.isLocked()
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local InputLock = {}

local ACTION = "FYDInputLock"
local PRIORITY = Enum.ContextActionPriority.High.Value + 100
local SINK_INPUTS = {
	Enum.UserInputType.Keyboard,
	Enum.UserInputType.MouseButton1,
	Enum.UserInputType.MouseButton2,
	Enum.UserInputType.Touch,
	Enum.UserInputType.Gamepad1,
}

local holders: { [string]: boolean } = {}
local locked = false

local function controls(): any?
	local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not module then
		return nil
	end
	local ok, result = pcall(function()
		return (require(module :: ModuleScript) :: any):GetControls()
	end)
	return if ok then result else nil
end

local function apply(on: boolean)
	if on == locked then
		return
	end
	locked = on
	local list = controls()
	if on then
		ContextActionService:BindActionAtPriority(ACTION, function()
			return Enum.ContextActionResult.Sink
		end, false, PRIORITY, table.unpack(SINK_INPUTS))
		if list then
			list:Disable()
		end
	else
		ContextActionService:UnbindAction(ACTION)
		if list then
			list:Enable()
		end
	end
end

function InputLock.isLocked(): boolean
	return locked
end

function InputLock.acquire(reason: string)
	holders[reason] = true
	apply(true)
end

function InputLock.release(reason: string)
	holders[reason] = nil
	if next(holders) == nil then
		apply(false)
	end
end

function InputLock.releaseAll()
	holders = {}
	apply(false)
end

return InputLock
