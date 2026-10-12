--!strict
-- Rebirth tab of the Rebirth window (DESIGN.md section 4, rules in Config/Rebirth): the next Rebirth with its
-- requirements (boss key, Gold), what it gives (credits, Gold multiplier, attribute power, the zone to redo), what is
-- lost and kept, and the Rebirth button (confirmation, then Net "Rebirth"; the server checks everything).
--   RebirthPage.build(page)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Rebirth = require(ReplicatedStorage.GameSystem.Config.Rebirth)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local State = require(script.Parent.Parent.Parent.State)
local Notifier = require(script.Parent.Parent.Notifier)
local Kit = script.Parent.Parent.Kit
local Button = require(Kit.Button)
local Icons = require(Kit.Icons)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)
local ZoneVisibility = require(Kit.ZoneVisibility)

local RebirthPage = {}

local FLASH = { Color = Color3.fromRGB(255, 226, 140), Start = 0.15, Seconds = 0.9 }

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

-- A full-screen golden flash when the Rebirth goes through.
local function flash()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "RebirthFlash"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = FLASH.Color
	frame.BackgroundTransparency = FLASH.Start
	frame.BorderSizePixel = 0
	frame.Parent = gui
	gui.Parent = playerGui
	local tween = TweenService:Create(frame, TweenInfo.new(FLASH.Seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
	tween.Completed:Connect(function()
		gui:Destroy()
	end)
	tween:Play()
end

function RebirthPage.build(page: ScrollingFrame)
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
	local zoneText = rewardCell("Zones", 4)

	-- lost / kept
	local listH = (if small then 17 else 19) * math.max(#Rebirth.Lost, #Rebirth.Kept) + 46
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
		Theme.text({ Font = "Title", Text = heading, TextSize = if small then 20 else 23, Color = color, Align = "Left", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(12, 6), ZIndex = 3, Parent = box })
		Theme.text({ Text = "- " .. table.concat(items, "\n- "), TextSize = if small then 15 else 17, Color = Theme.Colors.TextDim, Align = "Left", Wrapped = true, Size = UDim2.new(1, -24, 1, -40), Position = UDim2.fromOffset(12, 36), ZIndex = 3, Parent = box }).TextYAlignment = Enum.TextYAlignment.Top
	end
	listBox("You lose", Rebirth.Lost, 0, Theme.Colors.Bad)
	listBox("You keep", Rebirth.Kept, 1, Theme.Colors.Good)

	-- the button
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.Size = UDim2.new(1, -8, 0, Theme.TOUCH + 34)
	footer.LayoutOrder = 5
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
		Window.confirm({
			Title = `Rebirth {r}?`,
			Text = `You lose your Gold, weapons, armor, attribute points, eggs, pets and trophies. You keep Diamonds, keys and Rebirth upgrades, and get +{Rebirth.CreditsPerRebirth} Rebirth Credits.`,
			ConfirmText = "Rebirth",
			OnConfirm = function()
				if busy then
					return
				end
				busy = true
				local called, ok, result = pcall(Net.request, "Rebirth")
				busy = false
				if called and ok then
					Sfx.play("RebirthWhoosh")
					flash()
					Window.close(true)
					Notifier.push({ Kind = "reward", Text = `Rebirth {result.rebirth}! +{result.credits} Rebirth Credits`, Icon = "RebirthCredit" })
				else
					Sfx.play("Denied")
					Notifier.push({ Kind = "error", Text = if called and typeof(result) == "string" then result else "Could not Rebirth" })
				end
			end,
		})
	end })

	local function refresh()
		local rebirths = math.max(0, math.floor(tonumber(State.get("Rebirths")) or 0))
		status = Rebirth.status({ Rebirths = rebirths, Gold = State.get("Gold"), Keys = State.get("Keys") })
		goldPill.Text = `Gold x{times(Rebirth.goldMultiplier(rebirths))}`
		powerPill.Text = `Attributes x{times(Rebirth.power(rebirths))}`
		done.Text = `Rebirths done: {rebirths} / {Rebirth.Max}`
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
		keyLabel.Text = `{boss} key`
		keyStatus.Text = if status.hasKey then "Owned" else `Defeat the {boss} in {ZoneVisibility.displayName(zone.Id)}`
		keyStatus.TextColor3 = if status.hasKey then Theme.Colors.Good else Theme.Colors.TextDim
		setMark(keyMark, status.hasKey)
		goldLabel.Text = `{Format.number(status.cost)} Gold`
		goldStatus.Text = `{Format.number(math.min(status.gold, status.cost))} / {Format.number(status.cost)}`
		goldStatus.TextColor3 = if status.enoughGold then Theme.Colors.Good else Theme.Colors.TextDim
		fill.Size = UDim2.fromScale(math.clamp(status.gold / math.max(1, status.cost), 0, 1), 1)
		setMark(goldMark, status.enoughGold)
		creditsText.Text = `+{Rebirth.CreditsPerRebirth} Rebirth Credits`
		goldText.Text = `Gold x{times(Rebirth.goldMultiplier(rebirths))}  >  x{times(Rebirth.goldMultiplier(rebirths + 1))}`
		powerText.Text = `Attributes x{times(Rebirth.power(rebirths))}  >  x{times(Rebirth.power(rebirths + 1))}`
		zoneText.Text = `{ZoneVisibility.displayName(zone.Id)} restarts: redo it to open the next zone`
		button:SetText(`Rebirth {status.next}`)
		button:SetStyle(if status.ready then "primary" else "disabled")
		reason.Text = if status.ready then "Ready! Your character restarts stronger." else status.reason or ""
	end
	refresh()
	for _, key in ipairs({ "Rebirths", "Gold", "Keys", "Zones" }) do
		State.changed(key, refresh)
	end
end

return RebirthPage
