--!strict
-- Select mode of an inventory tab (owner 2026-10-15: "a select option to sell many items at the same time for each
-- category"). A check button turns it on; then a tap on an item ticks it instead of using it, "All" ticks every
-- shown item, and the trash button sells the ticked ones in one request (always with a confirm). Items that cannot
-- be sold (equipped, worn, locked) are dimmed and never ticked. Ticked items hidden by a filter are unticked, so
-- only what is on screen is sold.
--   SellBar.new({ Parent (header with a horizontal UIListLayout), LayoutOrder, ZIndex?, Page (the tab's page:
--                 leaving it ends select mode), Request (Net action, e.g. "SellWeapons"), Noun = { "weapon",
--                 "weapons" }, OnMode = fn(on)? }) -> SellBar
--   per rebuild:  bar:Begin(), bar:Attach(cell, { uid, value, rarity, blocked?, hide?, ringAt? }) for each shown item,
--                 bar:Finish(). blocked = the reason it cannot be sold, shown when it is tapped; hide = the item's own
--                 buttons (trash, sell), hidden while select mode is on; ringAt = where the tick ring sits in the cell
--   bar:IsOn(), bar:SetOn(on)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Notifier = require(script.Parent.Parent.Notifier)
local Button = require(script.Parent.Button)
local Chips = require(script.Parent.Chips)
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)
local Window = require(script.Parent.Window)

local SellBar = {}
SellBar.__index = SellBar

local WARN_FROM = 4 -- Epic and better: the confirm says how many are in the batch

export type Entry = { uid: string, value: number, rarity: number, blocked: string?, hide: { GuiObject }?, ringAt: UDim2? }
type Mark = { entry: Entry, button: TextButton, ring: Frame, check: GuiObject, stroke: UIStroke }

export type SellBar = typeof(setmetatable({} :: {
	_on: boolean,
	_busy: boolean,
	_selected: { [string]: boolean },
	_marks: { [string]: Mark },
	_props: { [string]: any },
	_toggle: any,
	_all: any,
	_sell: any,
	_count: any,
}, SellBar))

function SellBar.new(props: { [string]: any }): SellBar
	local z = props.ZIndex or 3
	local order = props.LayoutOrder or 10
	local self = setmetatable({
		_on = false,
		_busy = false,
		_selected = {},
		_marks = {},
		_props = props,
		_toggle = nil :: any,
		_all = nil :: any,
		_sell = nil :: any,
		_count = nil :: any,
	}, SellBar)
	-- check = select mode; X = back to normal
	self._toggle = Button.new({ Name = "Select", Icon = "Check", Style = "secondary", Size = UDim2.fromOffset(Theme.TOUCH, Theme.TOUCH), LayoutOrder = order, ZIndex = z, Parent = props.Parent, OnClick = function()
		Sfx.play("UIClick")
		self:SetOn(not self._on)
	end })
	self._count = Chips.chip(props.Parent, "Check", "0", { Name = "Selected", Height = Theme.TOUCH - 8, LayoutOrder = order + 1, ZIndex = z })
	self._all = Button.new({ Name = "SelectAll", Text = "All", Style = "primary", Size = UDim2.fromOffset(84, Theme.TOUCH), LayoutOrder = order + 2, ZIndex = z, Parent = props.Parent, OnClick = function()
		Sfx.play("UIClick")
		self:_selectAll()
	end })
	self._sell = Button.new({ Name = "SellSelected", Text = "0", Icon = "Trash", Style = "danger", Size = UDim2.fromOffset(if Theme.isCompact() then 150 else 176, Theme.TOUCH), LayoutOrder = order + 3, ZIndex = z, Parent = props.Parent, OnClick = function()
		self:_confirm()
	end })
	self._sell.Label.Size = UDim2.new(1, -86, 0.78, 0) -- room for the coin
	Icons.create("Gold", self._sell.Face, { Size = UDim2.new(0, 0, 0.66, 0), Position = UDim2.new(1, -8, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = self._sell.Instance.ZIndex })
	local page = props.Page :: GuiObject?
	if page then
		page:GetPropertyChangedSignal("Visible"):Connect(function()
			if not page.Visible then
				self:SetOn(false)
			end
		end)
	end
	self:_paintBar()
	return self
end

function SellBar.IsOn(self: SellBar): boolean
	return self._on
end

function SellBar.SetOn(self: SellBar, on: boolean)
	if self._on == on then
		return
	end
	self._on = on
	table.clear(self._selected)
	for _, mark in pairs(self._marks) do
		self:_paintMark(mark)
	end
	self:_paintBar()
	local onMode = self._props.OnMode
	if onMode then
		onMode(on)
	end
end

-- The page rebuilds its cells: Begin, Attach each shown item, Finish.
function SellBar.Begin(self: SellBar)
	table.clear(self._marks)
end

function SellBar.Attach(self: SellBar, cell: GuiObject, entry: Entry)
	-- a see-through button over the whole cell: in select mode it takes the tap (no equip, detail or trash)
	local button = Instance.new("TextButton")
	button.Name = "SelectMark"
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = Theme.Colors.Black
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromScale(1, 1)
	button.ZIndex = 12
	Theme.corner(button, 8)
	local stroke = Theme.stroke(button, Theme.Colors.Good, 4)
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.Size = UDim2.fromOffset(32, 32)
	ring.Position = entry.ringAt or UDim2.fromOffset(4, 4)
	ring.BackgroundColor3 = Theme.Colors.WoodInset
	ring.ZIndex = 13
	Theme.round(ring)
	Theme.stroke(ring, Theme.Colors.Text, 2.5)
	local check = Icons.create("Check", ring, { Size = UDim2.fromScale(0.86, 0.86), ZIndex = 14 })
	ring.Parent = button
	button.Parent = cell
	local mark: Mark = { entry = entry, button = button, ring = ring, check = check, stroke = stroke }
	button.Activated:Connect(function()
		self:_tap(mark)
	end)
	self._marks[entry.uid] = mark
	self:_paintMark(mark)
end

function SellBar.Finish(self: SellBar)
	-- only what is on screen (and still sellable) stays ticked
	for uid in pairs(self._selected) do
		local mark = self._marks[uid]
		if not mark or mark.entry.blocked then
			self._selected[uid] = nil
		end
	end
	self:_paintBar()
end

function SellBar._tap(self: SellBar, mark: Mark)
	if not self._on then
		return
	end
	local uid = mark.entry.uid
	if mark.entry.blocked then
		Sfx.play("Denied")
		Notifier.push({ Kind = "error", Text = mark.entry.blocked })
		return
	end
	self._selected[uid] = if self._selected[uid] then nil else true
	Sfx.play("UIClick")
	self:_paintMark(mark)
	self:_paintBar()
end

function SellBar._selectAll(self: SellBar)
	-- every shown sellable item; if they are all ticked already, untick them
	local all = true
	for uid, mark in pairs(self._marks) do
		if not mark.entry.blocked and not self._selected[uid] then
			all = false
		end
	end
	for uid, mark in pairs(self._marks) do
		if not mark.entry.blocked then
			self._selected[uid] = if all then nil else true
		end
		self:_paintMark(mark)
	end
	self:_paintBar()
end

function SellBar._paintMark(self: SellBar, mark: Mark)
	local on = self._on
	mark.button.Visible = on
	for _, item in ipairs(mark.entry.hide or {}) do
		item.Visible = not on
	end
	if not on then
		return
	end
	local blocked = mark.entry.blocked ~= nil
	local picked = self._selected[mark.entry.uid] == true
	mark.button.BackgroundTransparency = if blocked then 0.25 elseif picked then 0.85 else 1
	mark.ring.Visible = not blocked
	mark.ring.BackgroundColor3 = if picked then Theme.Colors.Good else Theme.Colors.WoodInset
	mark.check.Visible = picked
	mark.stroke.Enabled = picked
end

function SellBar._picked(self: SellBar): ({ string }, number, number)
	local uids, gold, rare = {}, 0, 0
	for uid in pairs(self._selected) do
		local mark = self._marks[uid]
		if mark and not mark.entry.blocked then
			table.insert(uids, uid)
			gold += mark.entry.value
			if mark.entry.rarity >= WARN_FROM then
				rare += 1
			end
		end
	end
	return uids, gold, rare
end

function SellBar._paintBar(self: SellBar)
	local on = self._on
	self._toggle:SetStyle(if on then "primary" else "secondary") -- gold while select mode is on
	self._count.Instance.Visible = on
	self._all.Instance.Visible = on
	self._sell.Instance.Visible = on
	if not on then
		return
	end
	local uids, gold = self:_picked()
	self._count:Set(tostring(#uids))
	self._sell:SetText(Format.number(gold))
	self._sell:SetStyle(if #uids > 0 then "danger" else "disabled")
end

function SellBar._confirm(self: SellBar)
	local uids, gold, rare = self:_picked()
	if #uids == 0 then
		Sfx.play("Denied")
		Notifier.push({ Kind = "error", Text = "Tap the items to sell first" })
		return
	end
	local noun = self._props.Noun or { "item", "items" }
	local what = `{#uids} {if #uids == 1 then noun[1] else noun[2]}`
	local warning = if rare > 0 then ` {rare} of them {if rare == 1 then "is" else "are"} {Rarities.get(WARN_FROM).Name} or better.` else ""
	Window.confirm({
		Title = "Sell?",
		Text = `Sell {what} for {Format.number(gold)} Gold?{warning}`,
		ConfirmText = "Sell",
		CancelText = "Keep",
		OnConfirm = function()
			self:_send(uids, what)
		end,
	})
end

function SellBar._send(self: SellBar, uids: { string }, what: string)
	if self._busy then
		return
	end
	self._busy = true
	local called, ok, result = pcall(Net.request, self._props.Request, uids)
	self._busy = false
	if called and ok and typeof(result) == "table" then
		Sfx.play("Purchase")
		local count = result.count or #uids
		local noun = self._props.Noun or { "item", "items" }
		Notifier.push({ Kind = "reward", Text = `Sold {count} {if count == 1 then noun[1] else noun[2]}: +{Format.number(result.gold or 0)} Gold`, Icon = "Gold" })
		self:SetOn(false)
	else
		Sfx.play("Denied")
		Notifier.push({ Kind = "error", Text = if called and typeof(result) == "string" then result else `Could not sell {what}` })
	end
end

return SellBar
