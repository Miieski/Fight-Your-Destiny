--!strict
-- Inventory > Equipment, the default tab (docs/menu_systems_brief.txt C3). A wooden scroll banner with the player's
-- name and Rebirths; in the middle the player's own avatar (a posed copy of their character) on a pedestal with the
-- worn armor, turning slowly (drag to turn, tap to pause); left: Helmet / Chest / Legs slots (rarity border, 3D
-- icon, "+HP", info button; a tap opens the picker with comparison arrows, ArmorPage.picker); right: the weapon in a
-- large slot and the pet slots (3, +2 locked without the pass). Bottom: Equip Best Armor (current zone) and Unequip
-- All. Stats summary on the right (phones: a drawer opened by the "Stats" button): Max HP, Defense and damage
-- reduction, Zone Boost per slot, set bonus, weapon damage per hit.
--   EquipmentPage.build(page, ctx)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Armor = require(ReplicatedStorage.GameSystem.Config.Armor)
local ArmorLook = require(ReplicatedStorage.GameSystem.Util.ArmorLook)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local PetRarities = require(ReplicatedStorage.GameSystem.Config.PetRarities)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.Parent.State)
local ArmorPage = require(script.Parent.ArmorPage)
local Notifier = require(script.Parent.Parent.Notifier)
local Kit = script.Parent.Parent.Kit
local Balance = require(ReplicatedStorage.GameSystem.Config.Balance)
local ZoneVisibility = require(Kit.ZoneVisibility)
local Button = require(Kit.Button)
local Icons = require(Kit.Icons)
local ModelIcon = require(Kit.ModelIcon)
local Overlay = require(Kit.Overlay)
local Slot = require(Kit.Slot)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local EquipmentPage = {}

local DATA_KEYS = { "Attributes", "Rebirths", "RebirthUpgrades", "Weapons", "EquippedWeapon", "Pets", "EquippedPets", "Armor", "EquippedArmor", "Boosts", "Zones", "Passes" }
local SPIN_SECONDS = 14
local MAX_PET_SLOTS = PetRarities.Slots + PetRarities.ExtraSlots

local busy = false

local function request(action: string, ...: any): (boolean, any)
	if busy then
		return false, nil
	end
	busy = true
	local called, ok, result = pcall(Net.request, action, ...)
	busy = false
	if called and ok then
		return true, result
	end
	Sfx.play("Denied")
	Notifier.push({ Kind = "error", Text = if called and typeof(result) == "string" then result else "Something went wrong" })
	return false, nil
end

local function snapshot(): { [string]: any }
	local data = {}
	for _, key in ipairs(DATA_KEYS) do
		data[key] = State.get(key)
	end
	return data
end

local function currentZone(): string?
	local zone = Players.LocalPlayer:GetAttribute("CurrentZone")
	return if typeof(zone) == "string" then zone else nil
end

local function wornItems(): { [string]: { id: string, tier: number } }
	local items = {}
	for slot, item in pairs(Armor.equipped(snapshot())) do
		items[slot] = { id = item.id, tier = item.rarity }
	end
	return items
end

----------------------------------------------------------------------------------------------------
-- avatar
----------------------------------------------------------------------------------------------------
local REMOVE = { "Script", "LocalScript", "ModuleScript", "Sound", "ForceField", "BillboardGui", "ParticleEmitter", "Light", "Tool", "Trail", "Beam", "Highlight" }

local function isRemoved(item: Instance): boolean
	for _, class in ipairs(REMOVE) do
		if item:IsA(class) then
			return true
		end
	end
	return false
end

-- A still copy of the player's character in its rest pose (joints solved from the root), feet at y = 0.
local function avatarModel(): Model?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root then
		return nil
	end
	local archivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = archivable
	if not clone then
		return nil
	end
	ArmorLook.clear(clone)
	for _, item in ipairs(clone:GetDescendants()) do
		if isRemoved(item) then
			item:Destroy()
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	local cloneRoot = clone:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not cloneRoot then
		return nil
	end
	-- joints: Motor6D / Weld (C0, C1), AnimationConstraint / RigidConstraint (the avatar joint upgrade: their two
	-- attachments) and WeldConstraint (kept at their current offset). Solved from the root = the rest pose.
	type Link = { a: BasePart, b: BasePart, c0: CFrame, c1: CFrame }
	local links: { Link } = {}
	for _, item in ipairs(clone:GetDescendants()) do
		if item:IsA("JointInstance") and item.Part0 and item.Part1 then
			table.insert(links, { a = item.Part0, b = item.Part1, c0 = item.C0, c1 = item.C1 })
		elseif (item:IsA("AnimationConstraint") or item:IsA("RigidConstraint")) and item.Attachment0 and item.Attachment1 then
			local a0, a1 = item.Attachment0 :: Attachment, item.Attachment1 :: Attachment
			local p0, p1 = a0.Parent, a1.Parent
			if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
				table.insert(links, { a = p0, b = p1, c0 = a0.CFrame, c1 = a1.CFrame })
			end
		elseif item:IsA("WeldConstraint") and item.Part0 and item.Part1 then
			local a, b = item.Part0 :: BasePart, item.Part1 :: BasePart
			table.insert(links, { a = a, b = b, c0 = a.CFrame:ToObjectSpace(b.CFrame), c1 = CFrame.identity })
		end
	end
	-- parts no joint reaches keep their current place relative to the root
	local rootBefore = cloneRoot.CFrame
	local relative: { [BasePart]: CFrame } = {}
	for _, item in ipairs(clone:GetDescendants()) do
		if item:IsA("BasePart") then
			relative[item] = rootBefore:ToObjectSpace(item.CFrame)
		end
	end
	local hip = if humanoid then humanoid.HipHeight else 2
	cloneRoot.CFrame = CFrame.new(0, hip + cloneRoot.Size.Y / 2, 0)
	local placed: { [BasePart]: boolean } = { [cloneRoot] = true }
	local changed = true
	while changed do
		changed = false
		for _, link in ipairs(links) do
			if placed[link.a] and not placed[link.b] then
				link.b.CFrame = link.a.CFrame * link.c0 * link.c1:Inverse()
				placed[link.b] = true
				changed = true
			elseif placed[link.b] and not placed[link.a] then
				link.a.CFrame = link.b.CFrame * link.c1 * link.c0:Inverse()
				placed[link.a] = true
				changed = true
			end
		end
	end
	for _, item in ipairs(clone:GetDescendants()) do
		if item:IsA("BasePart") then
			if not placed[item] and relative[item] then
				item.CFrame = cloneRoot.CFrame * relative[item]
			end
			item.Anchored = true
			item.CanCollide = false
		elseif item:IsA("Constraint") then
			item.Enabled = false
		end
	end
	cloneRoot.Transparency = 1
	clone.Name = "Avatar"
	return clone
end

type Viewer = { view: ViewportFrame, camera: Camera, avatar: Model?, pivot: CFrame, offset: CFrame, yaw: number, paused: boolean, dragging: boolean, moved: number, lastX: number }

local function pedestal(view: ViewportFrame)
	local base = Instance.new("Part")
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(0.6, 4.4, 4.4)
	base.CFrame = CFrame.new(0, -0.3, 0) * CFrame.Angles(0, 0, math.pi / 2)
	base.Color = Color3.fromRGB(104, 70, 44)
	base.Material = Enum.Material.Wood
	base.Anchored = true
	base.Parent = view
	local rim = base:Clone()
	rim.Size = Vector3.new(0.2, 4.7, 4.7)
	rim.CFrame = CFrame.new(0, -0.55, 0) * CFrame.Angles(0, 0, math.pi / 2)
	rim.Color = Color3.fromRGB(232, 180, 74)
	rim.Material = Enum.Material.Metal
	rim.Parent = view
end

local function rebuildAvatar(viewer: Viewer)
	if viewer.avatar then
		viewer.avatar:Destroy()
		viewer.avatar = nil
	end
	local avatar = avatarModel()
	if not avatar then
		return
	end
	ArmorLook.apply(avatar, wornItems(), { LowFx = true })
	avatar.Parent = viewer.view
	local box, size = avatar:GetBoundingBox()
	viewer.avatar = avatar
	viewer.pivot = CFrame.new(box.Position.X, 0, box.Position.Z)
	viewer.offset = viewer.pivot:ToObjectSpace(avatar:GetPivot())
	local height = math.max(size.Y, 4)
	local distance = (height * 0.62) / math.tan(math.rad(viewer.camera.FieldOfView / 2))
	local center = Vector3.new(box.Position.X, height * 0.48, box.Position.Z)
	viewer.camera.CFrame = CFrame.lookAt(center + Vector3.new(0, height * 0.12, -distance), center)
	avatar:PivotTo(viewer.pivot * CFrame.Angles(0, viewer.yaw, 0) * viewer.offset)
end

local function refreshArmorOnAvatar(viewer: Viewer)
	if viewer.avatar then
		ArmorLook.apply(viewer.avatar, wornItems(), { LowFx = true })
	end
end

local function makeViewer(parent: Instance, size: UDim2, position: UDim2): Viewer
	local view = Instance.new("ViewportFrame")
	view.Name = "Avatar"
	view.BackgroundTransparency = 1
	view.Size = size
	view.Position = position
	view.Ambient = Color3.fromRGB(165, 158, 150)
	view.LightColor = Color3.fromRGB(255, 244, 228)
	view.LightDirection = Vector3.new(-0.6, -1, 0.6)
	view.ZIndex = 3
	view.Parent = parent
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = view
	view.CurrentCamera = camera
	pedestal(view)
	local viewer: Viewer = { view = view, camera = camera, avatar = nil, pivot = CFrame.identity, offset = CFrame.identity, yaw = math.rad(-20), paused = false, dragging = false, moved = 0, lastX = 0 }
	view.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			viewer.dragging, viewer.moved, viewer.lastX = true, 0, input.Position.X
		end
	end)
	view.InputEnded:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and viewer.dragging then
			viewer.dragging = false
			if viewer.moved < 6 then
				viewer.paused = not viewer.paused -- a tap pauses / resumes the turning
			end
		end
	end)
	view.InputChanged:Connect(function(input)
		if viewer.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local dx = input.Position.X - viewer.lastX
			viewer.moved += math.abs(dx)
			viewer.yaw += dx * 0.012
			viewer.lastX = input.Position.X
		end
	end)
	return viewer
end

----------------------------------------------------------------------------------------------------
-- page
----------------------------------------------------------------------------------------------------
local function banner(parent: Instance, size: UDim2, position: UDim2): TextLabel
	local scroll = Instance.new("Frame")
	scroll.Name = "Scroll"
	scroll.Size = size
	scroll.Position = position
	scroll.AnchorPoint = Vector2.new(0.5, 0)
	scroll.BackgroundColor3 = Color3.new(1, 1, 1)
	scroll.ZIndex = 4
	Theme.corner(scroll, 4)
	Theme.gradient(scroll, Color3.fromRGB(236, 214, 170), Color3.fromRGB(196, 160, 104))
	Theme.stroke(scroll, Theme.Colors.GoldDark, 2)
	for _, side in ipairs({ 0, 1 }) do
		local roll = Instance.new("Frame")
		roll.Size = UDim2.new(0, 16, 1, 10)
		roll.Position = UDim2.new(side, 0, 0.5, 0)
		roll.AnchorPoint = Vector2.new(0.5, 0.5)
		roll.BackgroundColor3 = Color3.new(1, 1, 1)
		roll.ZIndex = 5
		Theme.corner(roll, 8)
		Theme.gradient(roll, Color3.fromRGB(150, 104, 60), Color3.fromRGB(96, 62, 30), 0)
		Theme.stroke(roll, Theme.Colors.Ink, 1.5)
		roll.Parent = scroll
	end
	scroll.Parent = parent
	return Theme.text({ Font = "Title", Text = "", TextSize = 26, Color = Theme.Colors.TextDark, Stroke = false, Size = UDim2.new(1, -40, 1, -4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6, Parent = scroll })
end

type ArmorSlot = { slot: any, label: TextLabel, holder: Frame }

function EquipmentPage.build(page: ScrollingFrame, ctx: any)
	ArmorPage.setParent(ctx.Frame)
	ArmorPage.fixedPage(page)
	local small = Theme.isCompact()
	local bottom = if small then 0 else Theme.TOUCH + 8

	-- left: armor slots
	local slotSize = if small then 62 else 92
	local left = Instance.new("Frame")
	left.Name = "ArmorSlots"
	left.BackgroundTransparency = 1
	left.Size = UDim2.new(0, slotSize + 16, 1, -bottom)
	left.ZIndex = 2
	local leftList = Instance.new("UIListLayout")
	leftList.Padding = UDim.new(0, if small then 6 else 10)
	leftList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	leftList.VerticalAlignment = Enum.VerticalAlignment.Center
	leftList.SortOrder = Enum.SortOrder.LayoutOrder
	leftList.Parent = left
	left.Parent = page
	local armorSlots: { [string]: ArmorSlot } = {}
	for index, slotName in ipairs(Armor.SLOTS) do
		local holder = Instance.new("Frame")
		holder.Name = slotName
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(slotSize + 12, slotSize + (if small then 0 else 22))
		holder.LayoutOrder = index
		holder.ZIndex = 2
		holder.Parent = left
		local slot = Slot.new({ Name = "Slot", Size = slotSize, Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), Parent = holder, OnClick = function()
			ArmorPage.picker(slotName)
		end })
		local label = Theme.text({ Font = "Number", Text = "", TextSize = if small then 13 else 16, Color = Theme.Colors.Good, Size = UDim2.new(1, 0, 0, if small then 16 else 20), Position = UDim2.new(0.5, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 6, Parent = holder })
		if small then
			label.Position = UDim2.new(0.5, 0, 1, -2)
		end
		-- info (i): a 44-unit touch area around a small round badge
		local info = Instance.new("TextButton")
		info.Name = "Info"
		info.Text = ""
		info.BackgroundTransparency = 1
		info.Size = UDim2.fromOffset(Theme.TOUCH * 0.8, Theme.TOUCH * 0.8)
		info.Position = UDim2.new(1, 4, 0, -8)
		info.AnchorPoint = Vector2.new(1, 0)
		info.ZIndex = 7
		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(24, 24)
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BackgroundColor3 = Theme.Colors.WoodLight
		dot.ZIndex = 7
		Theme.round(dot)
		Theme.stroke(dot, Theme.Colors.GoldLight, 1.5)
		Icons.create("Info", dot, { Size = UDim2.fromScale(0.85, 0.85), ZIndex = 8 })
		dot.Parent = info
		info.Activated:Connect(function()
			local uid = (State.get("EquippedArmor") or {})[slotName]
			if uid and (State.get("Armor") or {})[uid] then
				ArmorPage.detail(uid)
			else
				ArmorPage.picker(slotName)
			end
		end)
		info.Parent = holder
		armorSlots[slotName] = { slot = slot, label = label, holder = holder }
	end

	-- center: banner + avatar
	local centerX = slotSize + 24
	local centerW = if small then 236 else 360
	local center = Instance.new("Frame")
	center.Name = "Center"
	center.BackgroundTransparency = 1
	center.Position = UDim2.fromOffset(centerX, 0)
	center.Size = UDim2.new(0, centerW, 1, -bottom)
	center.ZIndex = 2
	center.Parent = page
	local glow = Instance.new("Frame")
	glow.Name = "Spot"
	glow.AnchorPoint = Vector2.new(0.5, 1)
	glow.Position = UDim2.new(0.5, 0, 1, -4)
	glow.Size = UDim2.new(1, 0, 0.9, 0)
	glow.BackgroundColor3 = Theme.Colors.GoldFace
	glow.BackgroundTransparency = 0.86
	glow.ZIndex = 2
	Theme.corner(glow, 16)
	glow.Parent = center
	local bannerH = if small then 30 else 40
	local nameLabel = banner(center, UDim2.new(1, -20, 0, bannerH), UDim2.new(0.5, 0, 0, 2))
	local viewer = makeViewer(center, UDim2.new(1, 0, 1, -(bannerH + 6)), UDim2.fromOffset(0, bannerH + 6))
	Theme.text({ Text = "Drag to turn - tap to pause", TextSize = 14, Color = Theme.Colors.TextDim, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0.5, 0, 1, -2), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 4, Parent = center })

	-- right: weapon + pets
	local rightX = centerX + centerW + 10
	local rightW = if small then 156 else 196
	local right = Instance.new("Frame")
	right.Name = "Gear"
	right.BackgroundTransparency = 1
	right.Position = UDim2.fromOffset(rightX, 0)
	right.Size = UDim2.new(0, rightW, 1, -bottom)
	right.ZIndex = 2
	right.Parent = page
	local weaponSize = if small then 76 else 122
	local weaponSlot = Slot.new({ Name = "Weapon", Size = weaponSize, Position = UDim2.new(0.5, 0, 0, if small then 4 else 14), AnchorPoint = Vector2.new(0.5, 0), Parent = right, OnClick = function()
		Window.open("Inventory", "Weapons")
	end })
	local weaponName = Theme.text({ Font = "Button", Text = "", TextSize = if small then 14 else 18, Size = UDim2.new(1, 0, 0, if small then 18 else 24), Position = UDim2.fromOffset(0, (if small then 4 else 14) + weaponSize + 4), ZIndex = 3, Parent = right })
	local petSize = if small then 44 else 56
	local petsFrame = Instance.new("Frame")
	petsFrame.Name = "Pets"
	petsFrame.BackgroundTransparency = 1
	petsFrame.Position = UDim2.fromOffset(0, (if small then 4 else 14) + weaponSize + (if small then 24 else 34))
	petsFrame.Size = UDim2.new(1, 0, 0, petSize * 2 + 8)
	petsFrame.ZIndex = 2
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(petSize, petSize)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = petsFrame
	petsFrame.Parent = right
	local petSlots = {}
	for i = 1, MAX_PET_SLOTS do
		petSlots[i] = Slot.new({ Name = "Pet" .. i, Size = petSize, LayoutOrder = i, Parent = petsFrame, OnClick = function()
			Window.open("Pets", "Pets")
		end })
	end

	-- stats (a panel on the right; phones: a drawer)
	local statsLines: Frame
	local function statsColumn(parent: Instance): Frame
		local column = Instance.new("Frame")
		column.Name = "StatsLines"
		column.BackgroundTransparency = 1
		column.Size = UDim2.new(1, -20, 1, -16)
		column.Position = UDim2.fromOffset(10, 8)
		column.ZIndex = 23
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 4)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = column
		column.Parent = parent
		return column
	end
	local function fillStats(column: Frame)
		for _, child in ipairs(column:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local zone = currentZone()
		local out = Stats.compute(snapshot(), { zoneId = zone, now = os.time() })
		local armor = Armor.totals(snapshot(), zone)
		local order = 0
		local function add(text: string, color: Color3?, size: number?, font: string?)
			order += 1
			Theme.text({ Font = font or "Body", Text = text, TextSize = size or 19, Wrapped = true, Align = "Left", Color = color, Size = UDim2.new(1, 0, 0, (size or 19) + 9), LayoutOrder = order, ZIndex = 24, Parent = column })
		end
		add("Stats", Theme.Colors.Gold, 26, "Title")
		add(`Max HP: {Format.number(math.floor(out.MaxHP + 0.5))}`)
		add(string.format("Defense: %s (-%d%% damage)", Format.number(math.floor(out.Defense * 10 + 0.5) / 10), math.floor(out.DamageReduction * 100 + 0.5)))
		add(`Armor: +{Format.number(math.floor(armor.HP + 0.5))} HP, +{math.floor(armor.Defense * 10 + 0.5) / 10} Defense`, Theme.Colors.TextDim, 17)
		local zoneDef = zone and Zones.ById[zone]
		local parts = {}
		for _, slot in ipairs(Armor.SLOTS) do
			local per = armor.PerSlot[slot]
			table.insert(parts, `{slot} {if per == nil then "-" elseif per.Boosted then "ON" else "off"}`)
		end
		if Balance.ZoneBoostEnabled then
			add(`Zone Boost{if zoneDef then ` ({ZoneVisibility.displayName(zoneDef.Id)})` else ""}: {table.concat(parts, ", ")}`, nil, 17)
		end
		if armor.SetZone then
			local full = armor.SetCount >= Armor.SetSize
			add(`{ZoneVisibility.displayName(armor.SetZone)} set {armor.SetCount}/{Armor.SetSize}{if full then (if Balance.ZoneBoostEnabled then " (+10% Max HP, +10% Zone Boost)" else " (+10% Max HP)") else ""}`, if full then Theme.Colors.Good else Theme.Colors.TextDim, 17)
		else
			add("No set bonus (wear 3 pieces of one zone)", Theme.Colors.TextDim, 17)
		end
		add(if out.WeaponDamage > 0 then `Weapon damage per hit: {Format.number(math.floor(out.WeaponDamage + 0.5))}` else "No weapon equipped", nil, 18)
		add(string.format("Move speed +%d%%   Crit x%.2f", math.floor(out.MoveSpeed * 100 + 0.5), out.CritDamage), Theme.Colors.TextDim, 16)
	end
	local statsPanel: Frame? = nil
	if not small then
		local panel = Instance.new("Frame")
		panel.Name = "Stats"
		panel.BackgroundColor3 = Theme.Colors.WoodTop
		panel.Position = UDim2.fromOffset(rightX + rightW + 10, 0)
		panel.Size = UDim2.new(1, -(rightX + rightW + 14), 1, -bottom)
		panel.ZIndex = 2
		Theme.corner(panel, 8)
		Theme.stroke(panel, Theme.Colors.GoldDark, 2)
		panel.Parent = page
		statsPanel = panel
		statsLines = statsColumn(panel)
	end

	-- buttons: bottom bar (phones: a column on the right)
	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.BackgroundTransparency = 1
	buttons.ZIndex = 2
	local buttonList = Instance.new("UIListLayout")
	buttonList.Padding = UDim.new(0, 8)
	buttonList.SortOrder = Enum.SortOrder.LayoutOrder
	buttonList.Parent = buttons
	if small then
		buttons.Position = UDim2.fromOffset(rightX + rightW + 10, 0)
		buttons.Size = UDim2.new(1, -(rightX + rightW + 14), 1, 0)
		buttonList.VerticalAlignment = Enum.VerticalAlignment.Center
		buttonList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	else
		buttons.Position = UDim2.new(0, 0, 1, -Theme.TOUCH)
		buttons.Size = UDim2.new(0, rightX + rightW, 0, Theme.TOUCH)
		buttonList.FillDirection = Enum.FillDirection.Horizontal
		buttonList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	buttons.Parent = page
	local buttonW = if small then UDim2.new(1, 0, 0, Theme.TOUCH) else UDim2.fromOffset(250, Theme.TOUCH)
	Button.new({ Name = "EquipBestArmor", Text = if small then "Best Armor" else "Equip Best Armor", Icon = "Star", Style = "go", TextSize = 20, Size = buttonW, LayoutOrder = 1, ZIndex = 3, Parent = buttons, OnClick = function()
		if request("EquipBestArmor") then
			Sfx.play("UIClick")
			Notifier.push({ Kind = "info", Text = "Best armor equipped for this zone", Icon = "Chest" })
		end
	end })
	Button.new({ Name = "UnequipAll", Text = "Unequip All", Style = "secondary", TextSize = 20, Size = buttonW, LayoutOrder = 2, ZIndex = 3, Parent = buttons, OnClick = function()
		if next(State.get("EquippedArmor") or {}) == nil then
			Notifier.push({ Kind = "info", Text = "No armor worn" })
			return
		end
		if request("UnequipArmor", "All") then
			Sfx.play("UIClick")
		end
	end })
	if small then
		Button.new({ Name = "StatsDrawer", Text = "Stats", Icon = "Stats", Style = "primary", TextSize = 20, Size = buttonW, LayoutOrder = 3, ZIndex = 3, Parent = buttons, OnClick = function()
			local panel = Overlay.open(ctx.Frame, Vector2.new(520, 360))
			local column = statsColumn(panel)
			column.Size = UDim2.new(1, -(Theme.TOUCH + 30), 1, -16)
			fillStats(column)
		end })
	end

	-- refresh
	local function refreshSlots()
		local owned = State.get("Armor") or {}
		local zone = currentZone()
		local totals = Armor.totals(snapshot(), zone)
		for _, slotName in ipairs(Armor.SLOTS) do
			local entry = armorSlots[slotName]
			local uid = (State.get("EquippedArmor") or {})[slotName]
			local item = uid and owned[uid]
			if item and Armor.ById[item.id] then
				entry.slot:Set({ Icon = Armor.SLOT_ICONS[slotName], Tier = item.rarity })
				if entry.slot._icon then
					entry.slot._icon:Destroy()
				end
				entry.slot._icon = ModelIcon.armor(item.id, item.rarity, { Size = UDim2.fromScale(0.94, 0.94), ZIndex = entry.slot.Box.ZIndex + 1, Parent = entry.slot.Box })
				local per = totals.PerSlot[slotName]
				entry.label.Text = `+{Format.number(math.floor((per and per.HP or 0) + 0.5))} HP`
			else
				entry.slot:Clear(Armor.SLOT_ICONS[slotName])
				local icon = entry.slot.Box:FindFirstChild("Icon")
				if icon then
					Icons.setFaded(icon, 0.55)
				end
				entry.label.Text = if small then "" else "Empty"
			end
		end
		-- weapon
		local weapons = State.get("Weapons") or {}
		local weapon = weapons[State.get("EquippedWeapon") or ""]
		local def = weapon and Weapons.ById[weapon.id]
		local old = weaponName:FindFirstChild("RarityGradient")
		if old then
			old:Destroy()
		end
		if def then
			weaponSlot:Set({ Icon = def.Icon or def.Category, Tier = weapon.rarity })
			weaponName.Text = def.Name
			Theme.paintRarity(weaponName, weapon.rarity)
		else
			weaponSlot:Clear("Sword")
			weaponName.Text = "No weapon"
			weaponName.TextColor3 = Theme.Colors.TextDim
		end
		-- pets
		local pets = State.get("Pets") or {}
		local equipped = State.get("EquippedPets") or {}
		local passes = State.get("Passes") or {}
		local open = PetRarities.Slots + (if passes.ExtraPetSlots then PetRarities.ExtraSlots else 0)
		for i, slot in ipairs(petSlots) do
			local pet = pets[equipped[i] or ""]
			if i > open then
				slot:Clear("Lock")
			elseif pet then
				slot:Set({ Icon = "Pet", Tier = pet.rarity })
				if slot._icon then
					slot._icon:Destroy()
				end
				slot._icon = ModelIcon.pet(pet.id, { Size = UDim2.fromScale(0.92, 0.92), ZIndex = slot.Box.ZIndex + 1, Parent = slot.Box })
			else
				slot:Clear("Plus")
			end
		end
		-- name banner
		local rebirths = State.get("Rebirths") or 0
		nameLabel.Text = `{Players.LocalPlayer.DisplayName}  -  Rebirth {rebirths}`
		if statsPanel then
			fillStats(statsLines)
		end
	end

	local spinConn: RBXScriptConnection? = nil
	local function startSpin()
		if spinConn then
			return
		end
		spinConn = RunService.RenderStepped:Connect(function(dt)
			if not page.Visible or not viewer.avatar then
				return
			end
			if not viewer.paused and not viewer.dragging then
				viewer.yaw += dt * math.pi * 2 / SPIN_SECONDS
			end
			viewer.avatar:PivotTo(viewer.pivot * CFrame.Angles(0, viewer.yaw, 0) * viewer.offset)
		end)
	end
	local function stopSpin()
		if spinConn then
			spinConn:Disconnect()
			spinConn = nil
		end
	end

	local function onOpen()
		rebuildAvatar(viewer)
		refreshSlots()
		startSpin()
	end
	Window.Opened:Connect(function(id: string)
		if id == "Inventory" then
			onOpen()
		end
	end)
	Window.Closed:Connect(function(id: string)
		if id == "Inventory" then
			stopSpin()
			Overlay.close()
		end
	end)
	for _, key in ipairs({ "Armor", "EquippedArmor" }) do
		State.changed(key, function()
			refreshSlots()
			refreshArmorOnAvatar(viewer)
		end)
	end
	for _, key in ipairs({ "Weapons", "EquippedWeapon", "Pets", "EquippedPets", "Passes", "Rebirths", "Attributes", "RebirthUpgrades" }) do
		State.changed(key, function()
			refreshSlots()
		end)
	end
	Players.LocalPlayer:GetAttributeChangedSignal("CurrentZone"):Connect(refreshSlots)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.delay(2, function()
			if Window.isOpen("Inventory") then
				rebuildAvatar(viewer)
			end
		end)
	end)
	-- another tab closes this tab's picker / drawer
	page:GetPropertyChangedSignal("Visible"):Connect(function()
		if not page.Visible then
			Overlay.close()
		end
	end)
	-- built inside Window.open: the Opened event right after shows the avatar
end

return EquipmentPage
