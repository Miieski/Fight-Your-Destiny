--!strict
-- HUD 4 + 5: the equipped weapon (icon, name and border in its rarity color; tap = Inventory >
-- Weapons; empty = "No weapon" + hint) and the 3 skill slots (Kit/SkillSlot with the key label; tap = use;
-- kept up to date by SkillController). On touch screens the skill slots are touch buttons next to Attack
-- (ControlsController), so this row shows the weapon only. Pets are equipped from the Pets window and the
-- Equipment screen. Bottom-center, clear of the joystick (left) and the action buttons (right).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skills = require(ReplicatedStorage.GameSystem.Config.Skills)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local State = require(script.Parent.Parent.State)
local SkillController = require(script.Parent.Parent.Controllers.SkillController)
local Kit = script.Parent.Kit
local Icons = require(Kit.Icons)
local Screens = require(Kit.Screens)
local SkillSlot = require(Kit.SkillSlot)
local Slot = require(Kit.Slot)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local Equipment = { Priority = 10 }

local WEAPON_SLOT = 76
local SKILL_SLOT = UIConfig.Hud.SkillSlot
local GAP = 8
local NAME_HEIGHT = 28

local nameLabel: TextLabel
local weaponSlot: any

local function refreshWeapon()
	local weapons = State.get("Weapons") or {}
	local item = weapons[State.get("EquippedWeapon") or ""]
	local def = item and Weapons.ById[item.id]
	local gradient = nameLabel:FindFirstChild("RarityGradient")
	if gradient then
		gradient:Destroy()
	end
	if def then
		weaponSlot:Set({ Icon = def.Icon or def.Category, Tier = item.rarity })
		nameLabel.Text = def.Name
		Theme.paintRarity(nameLabel, item.rarity)
	else
		weaponSlot:Clear("Sword")
		nameLabel.Text = `{UIConfig.Text.NoWeapon}  -  {UIConfig.Text.NoWeaponHint}`
		nameLabel.TextColor3 = Theme.Colors.TextDim
	end
	-- the empty weapon icon is shown faded
	local icon = weaponSlot.Box:FindFirstChild("Icon")
	if icon and not def then
		Icons.setFaded(icon, 0.55)
	end
end

function Equipment:Start()
	local container = Instance.new("Frame")
	container.Name = "Equipment"
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = UDim2.new(0.5, 0, 1, -10)
	local skillCount = if Theme.isTouch() then 0 else Skills.SLOT_COUNT
	local width = WEAPON_SLOT + skillCount * (SKILL_SLOT + GAP) + 4
	container.Size = UDim2.fromOffset(width, WEAPON_SLOT + NAME_HEIGHT + 4)
	container.Parent = Screens.hud()

	nameLabel = Theme.text({ Name = "WeaponName", Font = "Button", TextSize = 22, Size = UDim2.new(1, 60, 0, NAME_HEIGHT), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), Parent = container })

	local row = Instance.new("Frame")
	row.Name = "Slots"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, WEAPON_SLOT)
	row.Position = UDim2.new(0, 0, 1, 0)
	row.AnchorPoint = Vector2.new(0, 1)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.Padding = UDim.new(0, GAP)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	row.Parent = container

	weaponSlot = Slot.new({ Name = "Weapon", Size = WEAPON_SLOT, LayoutOrder = 0, Parent = row, OnClick = function()
		Window.open("Inventory", "Weapons")
	end })
	for index = 1, skillCount do
		local slot = SkillSlot.new({ Name = "Skill" .. index, Size = SKILL_SLOT, LayoutOrder = index, Parent = row, OnActivate = function()
			task.spawn(SkillController.use, index)
		end })
		SkillController.register(index, slot, true)
	end
	refreshWeapon()
	State.changed("Weapons", refreshWeapon)
	State.changed("EquippedWeapon", refreshWeapon)
end

return Equipment
