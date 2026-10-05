--!strict
-- Rebirth Shop window (docs/menu_systems_brief.txt D2): the credits available, then the 6 upgrades of
-- Config/RebirthShop, each with its 3D icon, level pips (level / max), effect and current bonus, and a Buy button
-- (1 credit per level; Net "BuyRebirthUpgrade"). Credits and upgrades are kept on Rebirth.
--   RebirthShopPage.build(page)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local RebirthShop = require(ReplicatedStorage.GameSystem.Config.RebirthShop)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local State = require(script.Parent.Parent.Parent.State)
local Notifier = require(script.Parent.Parent.Notifier)
local Kit = script.Parent.Parent.Kit
local Button = require(Kit.Button)
local Icons = require(Kit.Icons)
local Theme = require(Kit.Theme)

local RebirthShopPage = {}

type Row = { level: TextLabel, bonus: TextLabel, pips: { Frame }, buy: any }

function RebirthShopPage.build(page: ScrollingFrame)
	local small = Theme.isCompact()
	local busy = false
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, -8, 0, Theme.TOUCH)
	header.LayoutOrder = 0
	header.Parent = page
	local box = Instance.new("Frame")
	box.BackgroundColor3 = Theme.Colors.WoodInset
	box.Size = UDim2.fromOffset(if small then 200 else 240, 44)
	box.Position = UDim2.new(0, 10, 0.5, 0)
	box.AnchorPoint = Vector2.new(0, 0.5)
	Theme.corner(box, 22)
	Theme.stroke(box, Theme.Colors.GoldDark, 2)
	box.Parent = header
	Icons.create("RebirthCredit", box, { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, -8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 2 })
	local credits = Theme.text({ Font = "Number", Text = "", TextSize = 22, Align = "Right", Size = UDim2.new(1, -52, 1, -6), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 2, Parent = box })
	Theme.text({ Text = "Rebirth Credits come from Rebirths. Upgrades are kept forever.", TextSize = 18, Wrapped = true, Color = Theme.Colors.TextDim, Align = "Left", Size = UDim2.new(1, -(if small then 230 else 270), 1, -4), Position = UDim2.new(1, -4, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = header })

	local rows: { [string]: Row } = {}
	local rowH = if small then 76 else 86
	for index, upgrade in ipairs(RebirthShop.List) do
		local frame = Instance.new("Frame")
		frame.Name = upgrade.Id
		frame.BackgroundColor3 = Theme.Colors.WoodTop
		frame.Size = UDim2.new(1, -8, 0, rowH)
		frame.LayoutOrder = index
		Theme.corner(frame, 8)
		Theme.stroke(frame, Theme.Colors.GoldDark, 2)
		frame.Parent = page
		Icons.create(upgrade.Icon, frame, { Size = UDim2.fromOffset(rowH - 16, rowH - 16), Position = UDim2.fromOffset(10, 8), AnchorPoint = Vector2.zero, ZIndex = 2 })
		local x = rowH + 4
		Theme.text({ Font = "Title", Text = upgrade.Name, TextSize = if small then 22 else 26, Color = Theme.Colors.Gold, Align = "Left", Size = UDim2.new(0.34, -x, 0, 30), Position = UDim2.fromOffset(x, 6), ZIndex = 2, Parent = frame })
		Theme.text({ Text = upgrade.Effect, TextSize = 16, Color = Theme.Colors.TextDim, Align = "Left", Wrapped = true, Size = UDim2.new(0.34, -x, 0, rowH - 40), Position = UDim2.fromOffset(x, 36), ZIndex = 2, Parent = frame })
		-- level pips
		local pipsFrame = Instance.new("Frame")
		pipsFrame.BackgroundTransparency = 1
		pipsFrame.Size = UDim2.new(0.34, 0, 0, 18)
		pipsFrame.Position = UDim2.new(0.34, 0, 0, 14)
		pipsFrame.ZIndex = 2
		local pipList = Instance.new("UIListLayout")
		pipList.FillDirection = Enum.FillDirection.Horizontal
		pipList.Padding = UDim.new(0, 4)
		pipList.Parent = pipsFrame
		pipsFrame.Parent = frame
		local pips = {}
		for i = 1, upgrade.Max do
			local pip = Instance.new("Frame")
			pip.Size = UDim2.new(1 / upgrade.Max, -4, 1, 0)
			pip.BackgroundColor3 = Theme.Colors.WoodInset
			pip.ZIndex = 3
			Theme.corner(pip, 4)
			Theme.stroke(pip, Theme.Colors.Ink, 1)
			pip.Parent = pipsFrame
			pips[i] = pip
		end
		local level = Theme.text({ Font = "Number", Text = "", TextSize = 18, Align = "Left", Size = UDim2.new(0.16, 0, 0, 24), Position = UDim2.new(0.34, 0, 0, 40), ZIndex = 2, Parent = frame })
		local bonus = Theme.text({ Font = "Number", Text = "", TextSize = 18, Color = Theme.Colors.Good, Align = "Left", Size = UDim2.new(0.18, 0, 0, 24), Position = UDim2.new(0.5, 0, 0, 40), ZIndex = 2, Parent = frame })
		local buy = Button.new({ Text = `Buy  {RebirthShop.CostPerLevel}`, Icon = "RebirthCredit", Style = "primary", TextSize = 20, Size = UDim2.new(0.28, -16, 0, Theme.TOUCH), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 2, Parent = frame, OnClick = function()
			if busy then
				return
			end
			busy = true
			local called, ok, result = pcall(Net.request, "BuyRebirthUpgrade", upgrade.Id)
			busy = false
			if called and ok then
				Sfx.play("LevelUp")
				Notifier.push({ Kind = "reward", Text = `{upgrade.Name} level {result.level}`, Icon = upgrade.Icon })
			else
				Sfx.play("Denied")
				Notifier.push({ Kind = "error", Text = if called and typeof(result) == "string" then result else "Could not buy" })
			end
		end })
		rows[upgrade.Id] = { level = level, bonus = bonus, pips = pips, buy = buy }
	end

	local function refresh()
		local have = math.floor(tonumber(State.get("RebirthCredits")) or 0)
		credits.Text = `{have} credit{if have == 1 then "" else "s"}`
		local levels = State.get("RebirthUpgrades") or {}
		for _, upgrade in ipairs(RebirthShop.List) do
			local row = rows[upgrade.Id]
			local lv = math.clamp(math.floor(tonumber(levels[upgrade.Id]) or 0), 0, upgrade.Max)
			row.level.Text = `Lv {lv} / {upgrade.Max}`
			row.bonus.Text = `+{math.round(RebirthShop.bonus(levels, upgrade.Id) * 100)}%`
			for i, pip in ipairs(row.pips) do
				pip.BackgroundColor3 = if i <= lv then Theme.Colors.Gold else Theme.Colors.WoodInset
			end
			if lv >= upgrade.Max then
				row.buy:SetText("Max")
				row.buy:SetStyle("disabled")
			else
				row.buy:SetText(`Buy  {RebirthShop.CostPerLevel}`)
				row.buy:SetStyle(if have >= RebirthShop.CostPerLevel then "primary" else "disabled")
			end
		end
	end
	refresh()
	State.changed("RebirthCredits", refresh)
	State.changed("RebirthUpgrades", refresh)
end

return RebirthShopPage
