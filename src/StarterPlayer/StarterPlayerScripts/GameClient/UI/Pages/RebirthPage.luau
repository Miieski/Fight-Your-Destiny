--!strict
-- Rebirth tab of the Rebirth window (DESIGN.md section 4, rules in Config/Rebirth): the next Rebirth with its
-- requirements (boss key, Gold), what it gives (credits, Gold multiplier, attribute power, the zone to redo), what is
-- lost and kept, and the Rebirth button (confirmation, then Net "Rebirth"; the server checks everything).
--   RebirthPage.build(page)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Armor = require(ReplicatedStorage.GameSystem.Config.Armor)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Pets = require(ReplicatedStorage.GameSystem.Config.Pets)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local RebirthProtection = require(ReplicatedStorage.GameSystem.Config.RebirthProtection)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Rebirth = require(ReplicatedStorage.GameSystem.Config.Rebirth)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local State = require(script.Parent.Parent.Parent.State)
local Notifier = require(script.Parent.Parent.Notifier)
local Kit = script.Parent.Parent.Kit
local Button = require(Kit.Button)
local Components = require(Kit.Components)
local Icons = require(Kit.Icons)
local Info = require(Kit.Info)
local Theme = require(Kit.Theme)
local Transition = require(Kit.Transition)
local Window = require(Kit.Window)
local ZoneVisibility = require(Kit.ZoneVisibility)

local RebirthPage = {}

-- 2 -> "2", 1.5 -> "1.5", 2.0455 -> "2.05"
local function times(value: number): string
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	return (string.gsub(text, "%.$", ""))
end

local function card(page: Instance, name: string, height: number, order: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Theme.Colors.WoodTop
	frame.Size = UDim2.new(1, -8, 0, height)
	frame.LayoutOrder = order
	Theme.corner(frame, 8)
	Theme.stroke(frame, Theme.Colors.GoldDark, 2)
	frame.Parent = page
	return frame
end

local function title(parent: Instance, text: string, small: boolean)
	Theme.text({ Font = "Title", Text = text, TextSize = if small then 22 else 26, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(14, 6), ZIndex = 2, Parent = parent })
end

-- The staged Rebirth on this side: cover the screen (input blocked by the cover only), ask the server, wait for
-- "RebirthDone" (back in the Hub), uncover. Every path ends in finish(); the watchdog covers the paths that never answer.
local function runRebirth(onEnd: () -> ())
	local settings = Rebirth.Transition
	local started = os.clock()
	local ended = false
	local connection: RBXScriptConnection? = nil
	local function finish(fade: boolean, kind: string?, text: string?, icon: string?)
		if ended then
			return
		end
		ended = true
		if connection then
			connection:Disconnect()
		end
		if fade then
			Transition.hide(settings.FadeOut)
		end
		onEnd()
		if text then
			Sfx.play(if kind == "error" then "Denied" else "RebirthWhoosh")
			Notifier.push({ Kind = kind or "info", Text = text, Icon = icon })
		end
	end
	Window.close(true)
	Transition.show({
		Text = "Rebirth...",
		Spinner = true,
		Color = settings.Color,
		FadeIn = settings.FadeIn,
		Lock = "Rebirth",
		Watchdog = settings.Watchdog,
		OnTimeout = function() -- everything is already restored: back to the Hub and say so
			finish(false, "error", "The Rebirth took too long. You are back in the Hub.")
			pcall(Net.request, "GoToHub")
		end,
	})
	connection = Net.on("RebirthDone", function(info: { [string]: any })
		-- the new character is on the Hub ground before the cover comes off
		local player = Players.LocalPlayer
		local deadline = os.clock() + settings.SettleSeconds
		local params = RaycastParams.new()
		while os.clock() < deadline and not ended do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and character then
				params.FilterDescendantsInstances = { character }
				if workspace:Raycast(root.Position, Vector3.new(0, -20, 0), params) then
					break
				end
			end
			task.wait(0.1)
		end
		task.wait(math.max(0, settings.MinSeconds - (os.clock() - started)))
		if info.Ok then
			finish(true, "reward", `Rebirth {info.Rebirth}! +{info.Credits} Rebirth Credits`, "RebirthCredit")
		else
			finish(true, "error", "Something went wrong, but your Rebirth is done. You are back in the Hub.")
		end
	end)
	task.spawn(function()
		task.wait(settings.FadeIn)
		local called, ok, result = pcall(Net.request, "Rebirth")
		if not (called and ok) then
			finish(true, "error", if called and typeof(result) == "string" then result else "Could not Rebirth")
		end
	end)
end

-- what a Rebirth takes and keeps, as pictures (kid-friendly UI); the words are behind the (i)
local ITEM_ICONS = {
	Gold = "Gold", Weapons = "Sword", Armor = "Chest", ["Attribute points"] = "Stats", Eggs = "Egg",
	Pets = "Pets", Trophies = "Trophy", Diamonds = "Diamond", ["Boss keys"] = "Key",
	["Rebirth Credits and upgrades"] = "RebirthCredit", ["Protected items"] = "Defense", Index = "Index",
	["Boosts and passes"] = "Boost", ["Unlocked zones"] = "Zones",
}

-- The player's weapons, armor and pets: kept (protected) and lost, by category, the most valuable lost ones named.
local function itemSummary(): { kept: number, lost: number, keptLine: string, lostLine: string, top: string }
	local kept, lost, keptParts, lostParts, ranked = 0, 0, {}, {}, {}
	local names = { Weapon = "weapons", Armor = "armor", Pet = "pets" }
	for _, category in ipairs(RebirthProtection.Categories) do
		local k, l = 0, 0
		for _, item in pairs(State.get(RebirthProtection.Keys[category]) or {}) do
			if item.Protected then
				k += 1
			else
				l += 1
				local def: any = if category == "Weapon" then Weapons.ById[item.id] elseif category == "Armor" then Armor.ById[item.id] else Pets.ById[item.id]
				table.insert(ranked, { rarity = item.rarity or 1, name = def and def.Name or "?" })
			end
		end
		kept += k
		lost += l
		table.insert(keptParts, `{k} {names[category]}`)
		table.insert(lostParts, `{l} {names[category]}`)
	end
	table.sort(ranked, function(a, b)
		return a.rarity > b.rarity
	end)
	local top = {}
	for i = 1, math.min(3, #ranked) do
		table.insert(top, `{Rarities.get(ranked[i].rarity).Name} {ranked[i].name}`)
	end
	return { kept = kept, lost = lost, keptLine = table.concat(keptParts, ", "), lostLine = table.concat(lostParts, ", "), top = table.concat(top, ", ") }
end

function RebirthPage.build(page: ScrollingFrame, ctx: any?)
	local small = Theme.isCompact()
	local busy = false
	local rowH = if small then 54 else 62

	-- header: the next Rebirth, Rebirths done, current bonuses
	local hero = card(page, "Hero", if small then 96 else 116, 1)
	local heroIcon = if small then 72 else 92
	Icons.create("RebirthShop", hero, { Size = UDim2.fromOffset(heroIcon, heroIcon), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 2 })
	local heroX = heroIcon + 22
	local heading = Theme.text({ Font = "Title", Text = "", TextSize = if small then 30 else 38, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(0.55, -heroX, 0, 44), Position = UDim2.new(0, heroX, 0.5, -4), AnchorPoint = Vector2.new(0, 1), ZIndex = 2, Parent = hero })
	local done = Theme.text({ Text = "", TextSize = if small then 16 else 19, Color = Theme.Colors.TextDim, Align = "Left", Size = UDim2.new(0.55, -heroX, 0, 26), Position = UDim2.new(0, heroX, 0.5, 2), ZIndex = 2, Parent = hero })
	local function pill(icon: string, y: number): TextLabel
		local box = Instance.new("Frame")
		box.BackgroundColor3 = Theme.Colors.WoodInset
		box.Size = UDim2.new(0.42, -14, 0, if small then 34 else 40)
		box.Position = UDim2.new(1, -12, 0, y)
		box.AnchorPoint = Vector2.new(1, 0)
		box.ZIndex = 2
		Theme.corner(box, 18)
		Theme.stroke(box, Theme.Colors.GoldDark, 2)
		box.Parent = hero
		Icons.create(icon, box, { Size = UDim2.fromOffset(if small then 36 else 42, if small then 36 else 42), Position = UDim2.new(0, -6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
		return Theme.text({ Font = "Number", Text = "", TextSize = if small then 16 else 19, Align = "Right", Size = UDim2.new(1, -46, 1, -4), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 3, Parent = box })
	end
	local goldPill = pill("Gold", if small then 10 else 12)
	local powerPill = pill("Stats", if small then 50 else 62)

	-- requirements: the boss key and the Gold
	local needs = card(page, "Requirements", 40 + 2 * rowH, 2)
	title(needs, "Requirements", small)
	local function requirementRow(icon: string, index: number): (TextLabel, TextLabel, Frame)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -24, 0, rowH - 6)
		row.Position = UDim2.fromOffset(12, 38 + (index - 1) * rowH)
		row.ZIndex = 2
		row.Parent = needs
		Icons.create(icon, row, { Size = UDim2.fromOffset(rowH - 12, rowH - 12), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
		local label = Theme.text({ Text = "", TextSize = if small then 18 else 21, Align = "Left", Size = UDim2.new(0.42, -(rowH - 4), 1, 0), Position = UDim2.fromOffset(rowH - 2, 0), ZIndex = 3, Parent = row })
		local status = Theme.text({ Text = "", TextSize = if small then 16 else 18, Align = "Right", Wrapped = true, Size = UDim2.new(0.58, -40, 1, 0), Position = UDim2.new(1, -40, 0, 0), AnchorPoint = Vector2.new(1, 0), ZIndex = 3, Parent = row })
		local mark = Instance.new("Frame")
		mark.BackgroundTransparency = 1
		mark.Size = UDim2.fromOffset(32, 32)
		mark.Position = UDim2.new(1, 0, 0.5, 0)
		mark.AnchorPoint = Vector2.new(1, 0.5)
		mark.ZIndex = 3
		mark.Parent = row
		return label, status, mark
	end
	local keyLabel, keyStatus, keyMark = requirementRow("Key", 1)
	local goldLabel, goldStatus, goldMark = requirementRow("Gold", 2)
	goldStatus.Position = UDim2.new(1, -40, 0, -6) -- room for the progress bar below
	-- Gold progress bar under the Gold status
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Theme.Colors.WoodInset
	bar.Size = UDim2.new(0.34, 0, 0, 10)
	bar.Position = UDim2.new(1, -52, 1, -2)
	bar.AnchorPoint = Vector2.new(1, 1)
	bar.ZIndex = 3
	Theme.corner(bar, 5)
	bar.Parent = goldMark.Parent
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Theme.Colors.Gold
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 4
	Theme.corner(fill, 5)
	fill.Parent = bar

	local function setMark(mark: Frame, ok: boolean)
		for _, child in ipairs(mark:GetChildren()) do
			child:Destroy()
		end
		Icons.create(if ok then "Check" else "Lock", mark, { Size = UDim2.fromScale(1, 1), ZIndex = 4 })
	end

	-- rewards
	local rewards = card(page, "Rewards", 40 + 2 * rowH, 3)
	title(rewards, "You get", small)
	local function rewardCell(icon: string, index: number): TextLabel
		local col = (index - 1) % 2
		local line = math.floor((index - 1) / 2)
		local cell = Instance.new("Frame")
		cell.BackgroundTransparency = 1
		cell.Size = UDim2.new(0.5, -18, 0, rowH - 6)
		cell.Position = UDim2.new(0.5 * col, 12, 0, 38 + line * rowH)
		cell.ZIndex = 2
		cell.Parent = rewards
		Icons.create(icon, cell, { Size = UDim2.fromOffset(rowH - 14, rowH - 14), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
		return Theme.text({ Text = "", TextSize = if small then 16 else 19, Align = "Left", Wrapped = true, Size = UDim2.new(1, -(rowH - 4), 1, 0), Position = UDim2.fromOffset(rowH - 6, 0), ZIndex = 3, Parent = cell })
	end
	local creditsText = rewardCell("RebirthCredit", 1)
	local goldText = rewardCell("Gold", 2)
	local powerText = rewardCell("Stats", 3)
	local zoneText = rewardCell("Reset", 4) -- this zone starts again

	-- lost / kept
	local itemSize = if small then 40 else 50
	local listH = (if small then 2 else 1) * (itemSize + 6) + 52 -- 7 pictures: one row (phones: two)
	local lists = card(page, "LostKept", listH, 4)
	lists.BackgroundTransparency = 1
	for _, child in ipairs(lists:GetChildren()) do
		if child:IsA("UIStroke") then
			child.Enabled = false
		end
	end
	local function listBox(heading: string, items: { string }, col: number, color: Color3)
		local box = Instance.new("Frame")
		box.BackgroundColor3 = Theme.Colors.WoodInset
		box.Size = UDim2.new(0.5, -6, 1, 0)
		box.Position = UDim2.fromScale(0.5 * col, 0)
		box.ZIndex = 2
		Theme.corner(box, 8)
		Theme.stroke(box, Theme.Colors.GoldDark, 2)
		box.Parent = lists
		-- red X = lost, green check = kept; then the pictures
		local mark = Instance.new("Frame")
		mark.Size = UDim2.fromOffset(34, 34)
		mark.Position = UDim2.fromOffset(10, 8)
		mark.BackgroundColor3 = color
		mark.ZIndex = 3
		Theme.round(mark)
		Theme.stroke(mark, Theme.Colors.Ink, 1.5)
		Icons.create(if col == 0 then "Close" else "Check", mark, { Size = UDim2.fromScale(0.72, 0.72), ZIndex = 4 })
		mark.Parent = box
		if ctx then
			Info.button({ Parent = box, Frame = ctx.Frame, Title = heading, Lines = items, Size = 34, Position = UDim2.new(1, -8, 0, 8), AnchorPoint = Vector2.new(1, 0), ZIndex = 3, PopupSize = Vector2.new(520, 360) })
		end
		local grid = Instance.new("Frame")
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, -20, 1, -50)
		grid.Position = UDim2.fromOffset(10, 46)
		grid.ZIndex = 3
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(itemSize, itemSize)
		layout.CellPadding = UDim2.fromOffset(6, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		for i, item in ipairs(items) do
			local holder = Icons.create(ITEM_ICONS[item] or "Star", grid, { ZIndex = 4 })
			holder.LayoutOrder = i
		end
		grid.Parent = box
	end
	listBox("You lose", Rebirth.Lost, 0, Theme.Colors.Bad)
	listBox("You keep", Rebirth.Kept, 1, Theme.Colors.Good)

	-- the player's own items: what is kept, what is lost (the most valuable first), the way to protect them
	local items = Components.Card(page, "Items", if small then 158 else 176, 5)
	title(items, "Your items", small)
	local keptText = Theme.text({ Text = "", TextSize = if small then 16 else 18, Color = Theme.Colors.Good, Align = "Left", Wrapped = true, Size = UDim2.new(1, -28, 0, 26), Position = UDim2.fromOffset(14, 36), ZIndex = 2, Parent = items })
	local lostText = Theme.text({ Text = "", TextSize = if small then 16 else 18, Color = Theme.Colors.Bad, Align = "Left", Wrapped = true, Size = UDim2.new(1, -28, 0, 48), Position = UDim2.fromOffset(14, 62), ZIndex = 2, Parent = items })
	Components.Button({ Name = "ProtectItems", Text = "Protect items", Icon = "Defense", Style = "secondary", TextSize = if small then 20 else 22, Size = UDim2.new(0.5, 0, 0, Theme.TOUCH), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 2, Parent = items, OnClick = function()
		Window.open("Inventory", "Weapons")
	end })

	-- the button
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.Size = UDim2.new(1, -8, 0, Theme.TOUCH + 34)
	footer.LayoutOrder = 6
	footer.Parent = page
	local reason = Theme.text({ Text = "", TextSize = if small then 16 else 18, Color = Theme.Colors.TextDim, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0.5, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 1), Parent = footer })
	local status = Rebirth.status({})
	local button = Button.new({ Text = "Rebirth", Icon = "RebirthShop", Style = "primary", TextSize = if small then 24 else 28, Size = UDim2.new(if small then 0.7 else 0.5, 0, 0, Theme.TOUCH + 4), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), Parent = footer, OnClick = function()
		if busy or not status.ready then
			if not status.ready then
				Sfx.play("Denied")
				Notifier.push({ Kind = "error", Text = status.reason or "Not available" })
			end
			return
		end
		local r = status.next
		local summary = itemSummary()
		Window.confirm({
			Title = `Rebirth {r}?`,
			Text = `You lose your Gold, attribute points, eggs, trophies and {summary.lost} unprotected items{if summary.top ~= "" then ` ({summary.top}...)` else ""}. You keep Diamonds, keys, Rebirth upgrades and {summary.kept} protected items, and get +{Rebirth.CreditsPerRebirth} Rebirth Credits.`,
			ConfirmText = "Rebirth",
			OnConfirm = function()
				if busy then
					return
				end
				busy = true
				runRebirth(function()
					busy = false
				end)
			end,
		})
	end })

	local function refreshItems()
		local summary = itemSummary()
		keptText.Text = `Kept: {summary.kept} protected ({summary.keptLine})`
		lostText.Text = `Lost: {summary.lostLine}{if summary.top ~= "" then `. Most valuable: {summary.top}` else ""}`
	end
	refreshItems()
	for _, key in ipairs({ "Weapons", "Armor", "Pets" }) do
		State.changed(key, refreshItems)
	end

	local function refresh()
		local rebirths = math.max(0, math.floor(tonumber(State.get("Rebirths")) or 0))
		status = Rebirth.status({ Rebirths = rebirths, Gold = State.get("Gold"), Keys = State.get("Keys") })
		goldPill.Text = `x{times(Rebirth.goldMultiplier(rebirths))}`
		powerPill.Text = `x{times(Rebirth.power(rebirths))}`
		done.Text = `{rebirths} / {Rebirth.Max}`
		local zone = status.zone
		local maxed = status.maxed or zone == nil
		needs.Visible = not maxed
		rewards.Visible = not maxed
		lists.Visible = not maxed
		if maxed or not zone then
			heading.Text = "All Rebirths done!"
			reason.Text = "You reached the last Rebirth."
			button:SetText("Rebirth")
			button:SetStyle("disabled")
			return
		end
		heading.Text = `Rebirth {status.next}`
		local boss = ZoneVisibility.bossName(zone.Id)
		keyLabel.Text = boss
		keyStatus.Text = "" -- the check / lock says it
		keyStatus.TextColor3 = if status.hasKey then Theme.Colors.Good else Theme.Colors.TextDim
		setMark(keyMark, status.hasKey)
		goldLabel.Text = Format.number(status.cost)
		goldStatus.Text = `{Format.number(math.min(status.gold, status.cost))} / {Format.number(status.cost)}`
		goldStatus.TextColor3 = if status.enoughGold then Theme.Colors.Good else Theme.Colors.TextDim
		fill.Size = UDim2.fromScale(math.clamp(status.gold / math.max(1, status.cost), 0, 1), 1)
		setMark(goldMark, status.enoughGold)
		creditsText.Text = `+{Rebirth.CreditsPerRebirth}`
		goldText.Text = `x{times(Rebirth.goldMultiplier(rebirths))}  >  x{times(Rebirth.goldMultiplier(rebirths + 1))}`
		powerText.Text = `x{times(Rebirth.power(rebirths))}  >  x{times(Rebirth.power(rebirths + 1))}`
		zoneText.Text = ZoneVisibility.displayName(zone.Id)
		button:SetText(`Rebirth {status.next}`)
		button:SetStyle(if status.ready then "primary" else "disabled")
		reason.Text = if status.ready then "" else status.reason or ""
	end
	refresh()
	for _, key in ipairs({ "Rebirths", "Gold", "Keys", "Zones" }) do
		State.changed(key, refresh)
	end
end

return RebirthPage
