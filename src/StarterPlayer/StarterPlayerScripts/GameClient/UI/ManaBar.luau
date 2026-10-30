--!strict
-- HUD: the mana bar under the health bar, in the same wood style, visible only while a staff is equipped. The server owns mana
-- (ManaService); this reads the player attributes Mana / MaxMana. A refused cast flashes it (Net "NoMana" or ManaBar.flash).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.GameSystem.Net)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local WeaponMoves = require(ReplicatedStorage.GameSystem.Config.WeaponMoves)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local State = require(script.Parent.Parent.State)
local Kit = script.Parent.Kit
local Bar = require(Kit.Bar)
local Panel = require(Kit.Panel)
local Screens = require(Kit.Screens)
local Theme = require(Kit.Theme)

local ManaBar = { Priority = 11 }

local MANA_COLOR = Color3.fromRGB(70, 140, 255)
local FLASH_COLOR = Color3.fromRGB(255, 70, 60)
local FLASH = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GAP = 4 -- pixels under the health bar
local HEIGHT_K = 0.62 -- of the health bar's height

local panel: Frame
local border: UIStroke
local bar: any

local function refreshVisible()
	local weapons = State.get("Weapons")
	local uid = State.get("EquippedWeapon")
	local item = typeof(weapons) == "table" and uid and weapons[uid]
	local weapon = item and Weapons.ById[item.id]
	local moves = weapon and WeaponMoves.Moves[weapon.Category]
	panel.Visible = moves ~= nil and moves.Class == "Staff"
end

local function layout()
	local cfg = UIConfig.Hud.Health
	local size = if Theme.isCompact() then cfg.Compact else cfg.Normal
	panel.Size = UDim2.fromOffset(size.X, math.floor(size.Y * HEIGHT_K))
	panel.Position = UDim2.fromOffset(12, cfg.Top + size.Y + GAP)
end

function ManaBar.flash()
	if border then
		border.Color = FLASH_COLOR
		TweenService:Create(border, FLASH, { Color = Theme.Colors.GoldLight }):Play()
	end
end

function ManaBar:Start()
	panel = Panel.new({ Name = "Mana", Gems = false, BorderThickness = 3, Parent = Screens.hud() })
	border = panel:FindFirstChildOfClass("UIStroke") :: UIStroke
	bar = Bar.new({ Name = "MP", Size = UDim2.new(1, -20, 0.62, 0), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Color = MANA_COLOR, Parent = panel })
	layout()
	Theme.Changed:Connect(layout)
	local player = Players.LocalPlayer
	local function update()
		local mana, maxMana = player:GetAttribute("Mana"), player:GetAttribute("MaxMana")
		if typeof(mana) == "number" and typeof(maxMana) == "number" then
			bar:Set(mana, maxMana)
		end
	end
	player:GetAttributeChangedSignal("Mana"):Connect(update)
	player:GetAttributeChangedSignal("MaxMana"):Connect(update)
	update()
	State.observe("EquippedWeapon", refreshVisible)
	State.observe("Weapons", refreshVisible)
	Net.on("NoMana", ManaBar.flash)
end

return ManaBar
