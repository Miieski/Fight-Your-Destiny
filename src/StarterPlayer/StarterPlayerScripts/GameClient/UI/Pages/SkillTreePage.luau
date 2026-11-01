--!strict
-- The Skills tab of the Stats window (Round 8 part 6, a tab since Round 9): one tab per weapon type, a node graph you drag and zoom (mouse wheel, pinch or the + / -
-- buttons), the selected node's details, the mastery bar, the free picks and the bar of 3 equipped special attacks. Built on
-- Kit/Components. The server decides everything (Services/MasteryService).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Skills = require(ReplicatedStorage.GameSystem.Config.Skills)
local Trees = require(ReplicatedStorage.GameSystem.Config.WeaponSkillTrees)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local WeaponMastery = require(ReplicatedStorage.GameSystem.Config.WeaponMastery)
local State = require(script.Parent.Parent.Parent.State)
local Notifier = require(script.Parent.Parent.Notifier)
local Kit = script.Parent.Parent.Kit
local Components = require(Kit.Components)
local Icons = require(Kit.Icons)
local Tabs = require(Kit.Tabs)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local SkillTreePage = {}

local NODE = 66
local UNIT_X, UNIT_Y = 92, 118
local CANVAS = Vector2.new(1320, 1000)
local TOP = 54
local BOTTOM = 70
local SIDE = 280
local ZOOM = { Min = 0.4, Max = 1.2, Start = 0.56, Step = 0.12 }
local COMPACT_ROW_LEFT = 12 + 78 + 8 + UIConfig.Windows.Stats.CompactTabsWidth + 6 -- phones: the weapon tabs share the row of Stats | Skills

local function data(): { [string]: any }
	return { Mastery = State.get("Mastery"), FreePicks = State.get("FreePicks"), Gold = State.get("Gold"), EquippedSkills = State.get("EquippedSkills") }
end

local function request(action: string, ...: any): (boolean, any)
	local called, ok, result = pcall(Net.request, action, ...)
	if called and ok then
		return true, result
	end
	Sfx.play("Denied")
	Notifier.push({ Kind = "error", Text = if called and typeof(result) == "string" then result else "Could not do that", Icon = "Lock" })
	return false, nil
end

local paints: { () -> () } = {}
local function paintAll()
	if Window.isOpen("Stats") then
		for _, paint in ipairs(paints) do
			paint()
		end
	end
end

local function nodeCenter(node: { [string]: any }): Vector2
	return Vector2.new(CANVAS.X / 2 + node.X * UNIT_X, 54 + node.Y * UNIT_Y)
end

local function line(parent: Instance, a: Vector2, b: Vector2): Frame
	local bar = Instance.new("Frame")
	local delta = b - a
	bar.BackgroundColor3 = Theme.Colors.GoldDark
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	bar.Size = UDim2.fromOffset(delta.Magnitude, 4)
	bar.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	bar.ZIndex = 2
	bar.Parent = parent
	return bar
end

local function buildTab(page: Frame, root: ScrollingFrame, category: string)
	local small = Theme.isCompact()
	local side = if small then 260 else SIDE
	local nodes = Trees.ByCategory[category]
	local selected: { [string]: any } = nodes[1]

	-- top: mastery, points, free picks, open / respec
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.BackgroundTransparency = 1
	top.Position = UDim2.fromOffset(8, 4)
	top.Size = UDim2.new(1, -16, 0, TOP - 8)
	top.Parent = page
	local levelText = Theme.text({ Font = "Title", Text = "", TextSize = if small then 20 else 24, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.fromOffset(if small then 76 else 110, 40), Position = UDim2.fromOffset(0, 2), Parent = top })
	local bar = Components.Bar({ Size = UDim2.fromOffset(if small then 130 else 220, 22), Position = UDim2.fromOffset(if small then 80 else 116, 12), Parent = top, Color = Theme.Colors.GoldLight, ShowText = true })
	local chips = Components.CounterRow(top, { Size = UDim2.fromOffset(if small then 420 else 340, 44), Align = "Left" })
	chips.Position = UDim2.fromOffset(if small then 216 else 346, 0)
	local points = Components.Counter(chips, "Star", "", { Height = 38, LayoutOrder = 1 })
	local picks = Components.Counter(chips, "Gift", "", { Height = 38, LayoutOrder = 2 })
	local action = Components.Button({ Name = "TreeAction", Text = "", Style = "secondary", TextSize = if small then 16 else 19, Size = UDim2.fromOffset(if small then 150 else 190, Theme.TOUCH - 4), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), Parent = top, OnClick = function()
		if not WeaponMastery.isOpen(data(), category) then
			if request("MasteryOpen", category) then
				Sfx.play("Purchase")
			end
		else
			Components.Confirm({
				Title = "Reset this tree?",
				Text = "Every node of this tree comes back, with its points and free picks.",
				ConfirmText = "Reset",
				OnConfirm = function()
					if request("MasteryRespec", category) then
						Sfx.play("UIClick")
					end
				end,
			})
		end
	end })

	-- the graph
	local view = Instance.new("Frame")
	view.Name = "Graph"
	view.BackgroundColor3 = Theme.Colors.WoodInset
	view.ClipsDescendants = true
	view.Active = true
	view.Position = UDim2.fromOffset(8, TOP)
	view.Size = UDim2.new(1, -(side + 24), 1, -(TOP + BOTTOM + 6))
	Theme.corner(view, 8)
	Theme.stroke(view, Theme.Colors.GoldDark, 2)
	view.Parent = page
	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y)
	canvas.Parent = view
	local scale = Instance.new("UIScale")
	scale.Scale = ZOOM.Start
	scale.Parent = canvas
	local offset = Vector2.new(0, 0)
	local function place()
		local s = scale.Scale
		local size = view.AbsoluteSize / Theme.getScale()
		local minX, minY = math.min(0, size.X - CANVAS.X * s), math.min(0, size.Y - CANVAS.Y * s)
		offset = Vector2.new(math.clamp(offset.X, minX - 60, 60), math.clamp(offset.Y, minY - 60, 60))
		canvas.Position = UDim2.fromOffset(offset.X, offset.Y)
	end
	local function zoom(by: number)
		scale.Scale = math.clamp(scale.Scale + by, ZOOM.Min, ZOOM.Max)
		place()
	end
	local function center()
		local size = view.AbsoluteSize / Theme.getScale()
		offset = Vector2.new((size.X - CANVAS.X * scale.Scale) / 2, 6)
		place()
	end
	view:GetPropertyChangedSignal("AbsoluteSize"):Connect(center)
	local dragging = false
	local last = Vector2.zero
	view.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			last = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	view.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			zoom(input.Position.Z * ZOOM.Step)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local now = Vector2.new(input.Position.X, input.Position.Y)
			offset += (now - last) / Theme.getScale()
			last = now
			place()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.TouchPinch:Connect(function(_, _, velocity)
		if page.Visible and root.Visible and Window.isOpen("Stats") then
			zoom(velocity * 0.01)
		end
	end)
	for index, text in ipairs({ "-", "+" }) do
		local button = Components.Button({ Name = "Zoom" .. text, Text = text, Style = "wood", TextSize = 26, Size = UDim2.fromOffset(Theme.TOUCH, Theme.TOUCH), Position = UDim2.new(1, -6 - (2 - index) * (Theme.TOUCH + 6), 0, 6), AnchorPoint = Vector2.new(1, 0), ZIndex = 8, Parent = view, OnClick = function()
			zoom(if text == "+" then ZOOM.Step else -ZOOM.Step)
		end })
		button.Instance.ZIndex = 8
	end

	-- the details of the chosen node
	local panel = Components.Panel({ Name = "Details", Size = UDim2.new(0, side, 1, -(TOP + BOTTOM + 6)), Position = UDim2.new(1, -8, 0, TOP), AnchorPoint = Vector2.new(1, 0), Gems = false, BorderThickness = 3, Parent = page })
	local name = Theme.text({ Font = "Title", Text = "", TextSize = if small then 18 else 24, Color = Theme.Colors.Gold, Wrapped = true, Size = UDim2.new(1, -20, 0, if small then 24 else 36), Position = UDim2.fromOffset(10, if small then 2 else 6), ZIndex = 3, Parent = panel })
	local effect = Theme.text({ Text = "", TextSize = 18, Wrapped = true, Size = UDim2.new(1, -20, 0, if small then 58 else 62), Position = UDim2.fromOffset(10, if small then 26 else 44), ZIndex = 3, Parent = panel })
	local costText = Theme.text({ Text = "", TextSize = 17, Color = Theme.Colors.TextDim, Wrapped = true, Size = UDim2.new(1, -20, 0, 66), Position = UDim2.fromOffset(10, 108), ZIndex = 3, Parent = panel })
	if small then -- the phone panel is short: the effect label takes the cost too (see paint) and fits its box
		costText.Visible = false
		effect.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 15
		limit.Parent = effect
	end
	local nodeButton = Components.Button({ Name = "NodeAction", Text = "Unlock", Style = "primary", TextSize = 22, Size = UDim2.new(1, -24, 0, Theme.TOUCH), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 3, Parent = panel, OnClick = function()
		local d = data()
		local entry = WeaponMastery.entry(d, category)
		if (entry.Nodes or {})[selected.Id] then
			if selected.Skill then
				local list = table.clone((d.EquippedSkills or {})[category] or {})
				local at = table.find(list, selected.Skill)
				if at then
					table.remove(list, at)
				else
					table.insert(list, selected.Skill)
				end
				if request("MasteryEquip", category, list) then
					Sfx.play("UIClick")
				end
			end
		elseif request("MasteryUnlock", selected.Id) then
			Sfx.play("Unlock")
		end
	end })

	-- the equipped special attacks
	local foot = Instance.new("Frame")
	foot.Name = "Equipped"
	foot.BackgroundTransparency = 1
	foot.Position = UDim2.new(0, 8, 1, -(BOTTOM - 6))
	foot.Size = UDim2.new(1, -16, 0, BOTTOM - 8)
	foot.Parent = page
	Theme.text({ Font = "Button", Text = "Special attacks", TextSize = 20, Align = "Left", Size = UDim2.fromOffset(170, 40), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = foot })
	local slots = {}
	local labels: { [string]: TextLabel } = {}
	local slotNames = {}
	for i = 1, WeaponMastery.MaxEquipped do
		local slot = Components.Slot({ Name = "Special" .. i, Size = 56, Position = UDim2.fromOffset(170 + (i - 1) * 190, 3), Parent = foot, OnClick = function()
			local list = table.clone((data().EquippedSkills or {})[category] or {})
			if list[i] then
				table.remove(list, i)
				request("MasteryEquip", category, list)
			end
		end })
		slots[i] = slot
		slotNames[i] = Theme.text({ Text = "", TextSize = 15, Align = "Left", Wrapped = true, Size = UDim2.fromOffset(124, 50), Position = UDim2.fromOffset(170 + (i - 1) * 190 + 62, 6), Parent = foot })
	end

	-- nodes and lines
	local buttons: { [string]: { button: TextButton, stroke: UIStroke } } = {}
	local byId: { [string]: any } = {}
	for _, node in ipairs(nodes) do
		byId[node.Id] = node
		for _, list in ipairs({ node.Requires, node.Any }) do
			for _, id in ipairs(list) do
				line(canvas, nodeCenter(Trees.Nodes[id]), nodeCenter(node))
			end
		end
	end
	local paint: () -> ()
	for _, node in ipairs(nodes) do
		local at = nodeCenter(node)
		local button = Instance.new("TextButton")
		button.Name = node.Id
		button.Text = ""
		button.AutoButtonColor = false
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = UDim2.fromOffset(at.X, at.Y)
		button.Size = UDim2.fromOffset(NODE, NODE)
		button.ZIndex = 4
		Theme.round(button)
		local stroke = Theme.stroke(button, Theme.Colors.SteelDark, 3)
		Icons.create(if node.Kind == "Special" then category elseif node.Kind == "Passive" then "Crown" else "Stats", button, { Size = UDim2.fromScale(0.68, 0.68), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5 })
		local nodeLabel = Theme.text({ Font = "Button", Text = node.Name, TextSize = if small then 20 else 17, Size = UDim2.fromOffset(if small then 190 else 150, if small then 26 else 20), Position = UDim2.new(0.5, 0, 1, 2), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 6, Parent = button })
		nodeLabel.Visible = not small
		labels[node.Id] = nodeLabel
		button.Activated:Connect(function()
			selected = node
			Sfx.play("UIClick")
			paint()
		end)
		button.Parent = canvas
		buttons[node.Id] = { button = button, stroke = stroke }
	end

	paint = function()
		local d = data()
		local colors = Theme.Colors
		local entry = WeaponMastery.entry(d, category)
		local owned = entry.Nodes or {}
		local isOpen = WeaponMastery.isOpen(d, category)
		local xp = entry.XP or 0
		local level, into, need = WeaponMastery.levelOf(xp)
		local left = WeaponMastery.pointsLeft(d, category)
		local free = d.FreePicks or 0
		levelText.Text = `Lv {level}`
		bar:Set(into, math.max(1, need), true)
		points:Set(`{left}`)
		picks:Set(`Free picks: {free}/{WeaponMastery.FreePicks}`)
		action:SetText(if isOpen then "Reset tree" else `Open: {Format.number(WeaponMastery.OpenPrice[category])} Gold`)
		for id, item in pairs(buttons) do
			local node = byId[id]
			local has = owned[id] == true
			local can = not has and WeaponMastery.available(entry, node)
			item.button.BackgroundColor3 = if has then colors.GoldBase elseif can then colors.WoodLight else colors.WoodLine
			item.stroke.Color = if id == selected.Id then colors.Good elseif has then colors.Gold elseif can then colors.GoldLight else colors.SteelBase
			item.stroke.Thickness = if id == selected.Id then 5 else 3
		end
		local has = owned[selected.Id] == true
		local equipped = (d.EquippedSkills or {})[category] or {}
		name.Text = selected.Name
		if small then -- the phone shows only the name of the selected node
			for id, label in pairs(labels) do
				label.Visible = id == selected.Id
			end
		end
		effect.Text = Trees.effect(selected)
		local needs = {}
		for _, list in ipairs({ selected.Requires, selected.Any }) do
			for _, id in ipairs(list) do
				table.insert(needs, Trees.Nodes[id].Name)
			end
		end
		local joint = if #selected.Any > 0 then " or " else ", "
		costText.Text = `Cost: {selected.Cost} point{if selected.Cost == 1 then "" else "s"}` .. (if #needs > 0 then `\nNeeds: {table.concat(needs, joint)}` else "")
		if selected.Skill then
			local skill = Skills.ById[selected.Skill]
			effect.Text = `{Trees.effect(selected)}\nCooldown {skill.Cooldown} s{if skill.Cost then `, {skill.Cost} mana` else ""}`
		end
		if small then
			effect.Text ..= "\n" .. string.gsub(costText.Text, "\n", ". ")
		end
		if has and selected.Skill then
			nodeButton:SetText(if table.find(equipped, selected.Skill) then "Unequip" else "Equip")
			nodeButton:SetStyle("primary")
		elseif has then
			nodeButton:SetText("Unlocked")
			nodeButton:SetStyle("disabled")
		else
			nodeButton:SetText(if free > 0 then "Unlock (free pick)" else "Unlock")
			nodeButton:SetStyle(if WeaponMastery.available(entry, selected) and (free > 0 or (isOpen and left >= selected.Cost)) then "primary" else "disabled")
		end
		for i, slot in ipairs(slots) do
			local skill = Skills.ById[equipped[i] or ""]
			if skill then
				slot:Set({ Icon = category, Tier = 5 })
				slotNames[i].Text = skill.Name
			else
				slot:Clear()
				slotNames[i].Text = "Empty"
			end
		end
	end
	table.insert(paints, paint)
	task.defer(center)
end

function SkillTreePage.build(root: ScrollingFrame, ctx: any)
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	root.ScrollingEnabled = false
	root.AutomaticCanvasSize = Enum.AutomaticSize.None
	root.CanvasSize = UDim2.new()
	root.ScrollBarThickness = 0
	local small = Theme.isCompact()
	local config = UIConfig.SkillTabs
	local labels = config.TabLabels
	if small then -- icons only: the row is short
		labels = {}
		for _, category in ipairs(config.Tabs) do
			labels[category] = ""
		end
	end
	local pages: { [string]: Frame } = {}
	local row = Tabs.new({
		Tabs = config.Tabs,
		Icons = config.TabIcons,
		Labels = labels,
		Size = if small then UDim2.new(1, -(COMPACT_ROW_LEFT + Theme.TOUCH + 16), 0, Theme.TOUCH) else UDim2.new(1, -16, 0, Theme.TOUCH),
		Position = if small then UDim2.fromOffset(COMPACT_ROW_LEFT, 8) else UDim2.fromOffset(8, 4),
		OnSelect = function(name: string)
			for category, page in pairs(pages) do
				page.Visible = category == name
			end
		end,
		Parent = if small then ctx.Frame else root,
	})
	if small then
		local function follow()
			row.Instance.Visible = root.Visible
		end
		root:GetPropertyChangedSignal("Visible"):Connect(follow)
		follow()
	end
	local rowHeight = if small then 0 else Theme.TOUCH + 8
	for _, category in ipairs(config.Tabs) do
		local page = Instance.new("Frame")
		page.Name = category
		page.BackgroundTransparency = 1
		page.Position = UDim2.fromOffset(0, rowHeight)
		page.Size = UDim2.new(1, 0, 1, -rowHeight)
		page.Parent = root
		pages[category] = page
		buildTab(page, root, category)
	end
	row:Select(config.Tabs[1])
	for _, key in ipairs({ "Mastery", "FreePicks", "EquippedSkills", "Gold" }) do
		State.changed(key, paintAll)
	end
	Window.Opened:Connect(function(id)
		if id == "Stats" then
			paintAll()
		end
	end)
end

return SkillTreePage
