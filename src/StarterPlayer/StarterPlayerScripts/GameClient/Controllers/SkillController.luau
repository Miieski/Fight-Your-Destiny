--!strict
-- Skills on the client: the 3 slots of the HUD (PC) and the 3 touch buttons (mobile) register here as views of a slot.
-- A use (key, gamepad, tap) goes to SkillController.perform (set by CombatController: the move starts at once, the server
-- answers Net.request "UseSkill"); an empty slot shows the toast "Skills are coming soon". The server decides everything.
--   SkillController.register(slot, view, showKey?)   view = a UI/Kit/SkillSlot
--   SkillController.use(slot)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.GameSystem.Net)
local SettingsConfig = require(ReplicatedStorage.GameSystem.Config.Settings)
local Skills = require(ReplicatedStorage.GameSystem.Config.Skills)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Settings = require(script.Parent.SettingsController)
local State = require(script.Parent.Parent.State)
local Notifier = require(script.Parent.Parent.UI.Notifier)
local KeyLabel = require(script.Parent.Parent.UI.Kit.KeyLabel)

local SkillController = { Priority = 3, perform = nil :: ((number) -> (boolean, any))? }

local GAMEPAD_LABELS = { "LB", "RB", "Y" }

type View = { view: any, showKey: boolean }
local views: { [number]: { View } } = {}
for slot = 1, Skills.SLOT_COUNT do
	views[slot] = {}
end
local cooldownEnd: { [number]: number } = {}
local busy: { [number]: boolean } = {}

local function skillAt(slot: number): { [string]: any }?
	local weapons = State.get("Weapons")
	local uid = State.get("EquippedWeapon")
	local item = typeof(weapons) == "table" and uid and weapons[uid]
	local weapon = item and Weapons.ById[item.id]
	return Skills.at(slot, if weapon then weapon.Category else nil, State.get("EquippedSkills"))
end

local function usingGamepad(): boolean
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad") ~= nil
end

local function keyText(slot: number): string?
	if usingGamepad() then
		return GAMEPAD_LABELS[slot]
	end
	local keys = SettingsConfig.cleanKeys(Settings.get("KeyBindings"))
	local name = keys["Skill" .. slot]
	return if name and name ~= "None" then KeyLabel(name) else nil
end

local function paint(slot: number)
	local def = skillAt(slot)
	local key = keyText(slot)
	for _, entry in ipairs(views[slot]) do
		entry.view:SetSkill(def)
		local color = def and def.Element and Skills.ELEMENT_COLORS[def.Element]
		entry.view:SetFrame(color)
		entry.view:SetKey(if entry.showKey then key else nil)
	end
end

local function paintAll()
	for slot = 1, Skills.SLOT_COUNT do
		paint(slot)
	end
end

function SkillController.register(slot: number, view: any, showKey: boolean?)
	table.insert(views[slot], { view = view, showKey = showKey == true })
	paint(slot)
end

function SkillController.use(slot: number)
	if not Skills.validSlot(slot) or busy[slot] then
		return
	end
	local def = skillAt(slot)
	if not def then
		Notifier.push({ Kind = "info", Text = Skills.Text.ComingSoon })
		return
	end
	if os.clock() < (cooldownEnd[slot] or 0) then
		for _, entry in ipairs(views[slot]) do
			entry.view:Shake()
		end
		return
	end
	busy[slot] = true
	local perform = SkillController.perform
	local ok, result = false, nil
	if perform then
		ok, result = perform(slot)
	else
		ok, result = Net.request("UseSkill", slot)
	end
	busy[slot] = nil
	if ok then
		local seconds = def.Cooldown or 0
		cooldownEnd[slot] = os.clock() + seconds
		for _, entry in ipairs(views[slot]) do
			entry.view:StartCooldown(seconds)
		end
	elseif result == Skills.RESOURCE_ERROR then
		for _, entry in ipairs(views[slot]) do
			entry.view:Shake()
		end
	else
		Notifier.push({ Kind = "error", Text = tostring(result or Skills.Text.NotAvailable) })
	end
end

function SkillController:Start()
	State.changed("EquippedSkills", paintAll)
	State.changed("EquippedWeapon", paintAll)
	State.changed("Weapons", paintAll)
	Settings.changed("KeyBindings", paintAll)
	local wasGamepad = usingGamepad()
	UserInputService.LastInputTypeChanged:Connect(function()
		local now = usingGamepad()
		if now ~= wasGamepad then
			wasGamepad = now
			paintAll()
		end
	end)
	paintAll()
end

return SkillController
