--!strict
-- Window manager: one window open at a time over a dim backdrop; pop animation (0.9 -> 1, Back Out),
-- X button top-right, optional tabs, scrolling pages. Windows never exceed 90% of the screen.
--   Window.define(id, { Title, Tabs?, Size?: Vector2, Build = function(ctx) end })
--       ctx = { Frame, Pages = { [tab or "Main"] = ScrollingFrame }, Tabs?, Select(tab) }
--   Window.open(id, tab?), Window.close(), Window.toggle(id, tab?), Window.isOpen(id?)
--   Window.confirm({ Title, Text, ConfirmText, CancelText, OnConfirm })
--   Window.placeholder(page, text?)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local Button = require(script.Parent.Button)
local Icons = require(script.Parent.Icons)
local Panel = require(script.Parent.Panel)
local Tabs = require(script.Parent.Tabs)
local Theme = require(script.Parent.Theme)

local Window = {}

type Definition = { Title: string, Tabs: { string }?, Size: Vector2?, Build: ((any) -> ())? }
type Built = { frame: Frame, pages: { [string]: ScrollingFrame }, tabs: any?, pop: UIScale, def: Definition }

local HEADER = 74
local MAIN = "Main"
-- The screen root stops under the Roblox top bar; an oversized, centered backdrop dims that strip too.
local BACKDROP_COVER = 4

local function cover(dim: GuiObject)
	dim.AnchorPoint = Vector2.new(0.5, 0.5)
	dim.Position = UDim2.fromScale(0.5, 0.5)
	dim.Size = UDim2.fromScale(BACKDROP_COVER, BACKDROP_COVER)
end

local definitions: { [string]: Definition } = {}
local built: { [string]: Built } = {}
local current: string? = nil
local root: Frame? = nil
local backdrop: TextButton? = nil
local openedEvent = Instance.new("BindableEvent")
local closedEvent = Instance.new("BindableEvent")

Window.Opened = openedEvent.Event -- (id)
Window.Closed = closedEvent.Event -- (id)

local function ensureRoot(): Frame
	if root then
		return root
	end
	local _, screenRoot = Theme.screen("Windows", 20)
	local dim = Instance.new("TextButton")
	dim.Name = "Backdrop"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = Theme.Colors.Black
	dim.BackgroundTransparency = 1
	cover(dim)
	dim.Visible = false
	dim.ZIndex = 1
	dim.Activated:Connect(function()
		Window.close()
	end)
	dim.Parent = screenRoot
	root = screenRoot
	backdrop = dim
	return screenRoot
end

local function fitSize(preferred: Vector2): Vector2
	local screen = Theme.size()
	local fraction = UIConfig.MaxScreenFraction
	return Vector2.new(math.min(preferred.X, screen.X * fraction), math.min(preferred.Y, screen.Y * fraction))
end

local function newPage(parent: Instance, name: string): ScrollingFrame
	local page = Instance.new("ScrollingFrame")
	page.Name = name
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.Size = UDim2.fromScale(1, 1)
	page.CanvasSize = UDim2.new()
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.ScrollingDirection = Enum.ScrollingDirection.Y
	page.ScrollBarThickness = 6
	page.ScrollBarImageColor3 = Theme.Colors.GoldLight
	page.Visible = false
	page.ZIndex = 2
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = page
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = page
	page.Parent = parent
	return page
end

local function select(entry: Built, tab: string?)
	local name = if tab and entry.pages[tab] then tab elseif entry.tabs then entry.tabs.Selected or (entry.def.Tabs :: { string })[1] else MAIN
	for pageName, page in pairs(entry.pages) do
		page.Visible = pageName == name
	end
	if entry.tabs and entry.tabs.Selected ~= name then
		entry.tabs:Select(name, true)
	end
end

local function build(id: string): Built
	local existing = built[id]
	if existing then
		return existing
	end
	local def = definitions[id]
	assert(def, `Window "{id}" is not defined`)
	local parent = ensureRoot()
	local size = fitSize(def.Size or UIConfig.WINDOW_SIZE)
	local frame = Panel.new({ Name = id .. "Window", Size = UDim2.fromOffset(size.X, size.Y), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2, Parent = parent })
	frame.Visible = false
	local pop = Instance.new("UIScale")
	pop.Parent = frame

	local banner = Panel.new({ Name = "Banner", Size = UDim2.new(0.5, 0, 0, 50), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), Gems = false, BorderThickness = 3, ZIndex = 3, Parent = frame })
	local bannerLimit = Instance.new("UISizeConstraint")
	bannerLimit.MaxSize = Vector2.new(380, 50)
	bannerLimit.Parent = banner
	Theme.text({ Name = "Title", Font = "Title", Text = def.Title, TextSize = 32, Color = Theme.Colors.Gold, Size = UDim2.new(1, -16, 0.86, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4, Parent = banner })

	Button.new({ Name = "Close", Style = "wood", Icon = "Close", Size = UDim2.fromOffset(Theme.TOUCH, Theme.TOUCH), Position = UDim2.new(1, -8, 0, 8), AnchorPoint = Vector2.new(1, 0), ZIndex = 3, OnClick = Window.close, Parent = frame })

	local top = HEADER
	local entry: Built = { frame = frame, pages = {}, tabs = nil, pop = pop, def = def }
	if def.Tabs then
		entry.tabs = Tabs.new({
			Tabs = def.Tabs,
			Size = UDim2.new(1, -24, 0, Theme.TOUCH),
			Position = UDim2.fromOffset(12, top),
			OnSelect = function(name: string)
				select(entry, name)
			end,
			Parent = frame,
		})
		top += Theme.TOUCH + 8
	end
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Position = UDim2.fromOffset(12, top)
	content.Size = UDim2.new(1, -24, 1, -top - 12)
	content.BackgroundColor3 = Theme.Colors.WoodInset
	content.BorderSizePixel = 0
	content.ZIndex = 2
	Theme.corner(content, 4)
	Theme.stroke(content, Theme.Colors.WoodLine, 1.5)
	content.Parent = frame
	for _, name in ipairs(def.Tabs or { MAIN }) do
		entry.pages[name] = newPage(content, name)
	end
	built[id] = entry
	if def.Build then
		def.Build({
			Frame = frame,
			Pages = entry.pages,
			Tabs = entry.tabs,
			Select = function(tab: string)
				select(entry, tab)
			end,
		})
	end
	select(entry, nil)
	return entry
end

local function resize(entry: Built)
	local size = fitSize(entry.def.Size or UIConfig.WINDOW_SIZE)
	entry.frame.Size = UDim2.fromOffset(size.X, size.Y)
end

function Window.define(id: string, def: Definition)
	definitions[id] = def
end

-- The scrolling page of a tab (or "Main"); builds the window if needed.
function Window.page(id: string, tab: string?): ScrollingFrame
	return build(id).pages[tab or MAIN]
end

function Window.isOpen(id: string?): boolean
	return if id then current == id else current ~= nil
end

function Window.open(id: string, tab: string?)
	if current == id then
		select(built[id], tab)
		return
	end
	if current then
		Window.close(true)
	end
	local entry = build(id)
	resize(entry)
	select(entry, tab)
	current = id
	local dim = backdrop :: TextButton
	dim.Visible = true
	TweenService:Create(dim, TweenInfo.new(UIConfig.WINDOW_POP_SECONDS), { BackgroundTransparency = UIConfig.BACKDROP_TRANSPARENCY }):Play()
	entry.pop.Scale = UIConfig.WINDOW_START_SCALE
	entry.frame.Visible = true
	TweenService:Create(entry.pop, TweenInfo.new(UIConfig.WINDOW_POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Sfx.play("UIOpen")
	openedEvent:Fire(id)
end

function Window.close(quiet: boolean?)
	local id = current
	if not id then
		return
	end
	current = nil
	local entry = built[id]
	entry.frame.Visible = false
	if not quiet then
		local dim = backdrop :: TextButton
		dim.BackgroundTransparency = 1
		dim.Visible = false
		Sfx.play("UIClose")
	end
	closedEvent:Fire(id)
end

function Window.toggle(id: string, tab: string?)
	if current == id then
		Window.close()
	else
		Window.open(id, tab)
	end
end

-- Centered "Coming soon" block for empty shells.
function Window.placeholder(page: Instance, text: string?): Frame
	local block = Instance.new("Frame")
	block.Name = "Placeholder"
	block.BackgroundTransparency = 1
	block.Size = UDim2.new(1, 0, 0, 170)
	block.LayoutOrder = 100
	Icons.create("Info", block, { Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0.5, 0, 0, 44) })
	Theme.text({ Font = "Title", Text = text or UIConfig.Text.ComingSoon, TextSize = 34, Color = Theme.Colors.TextDim, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0.5, 0, 0, 92), AnchorPoint = Vector2.new(0.5, 0), Parent = block })
	block.Parent = page
	return block
end

-- Small modal question above every window.
function Window.confirm(props: { [string]: any })
	local parent = ensureRoot()
	local dim = Instance.new("TextButton")
	dim.Name = "ConfirmBackdrop"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = Theme.Colors.Black
	dim.BackgroundTransparency = 0.35
	cover(dim)
	dim.ZIndex = 20
	dim.Parent = parent
	local size = fitSize(Vector2.new(460, 250))
	local dialog = Panel.new({ Name = "Confirm", Size = UDim2.fromOffset(size.X, size.Y), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 21, Parent = dim })
	Theme.text({ Font = "Title", Text = props.Title or "", TextSize = 30, Color = Theme.Colors.Gold, Size = UDim2.new(1, -24, 0, 40), Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 22, Parent = dialog })
	Theme.text({ Text = props.Text or "", TextSize = 22, Wrapped = true, Size = UDim2.new(1, -36, 1, -(Theme.TOUCH + 80)), Position = UDim2.new(0.5, 0, 0, 56), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 22, Parent = dialog })
	local function close()
		dim:Destroy()
	end
	Button.new({ Text = props.CancelText or "Cancel", Style = "secondary", Size = UDim2.new(0.5, -24, 0, Theme.TOUCH), Position = UDim2.new(0, 16, 1, -12), AnchorPoint = Vector2.new(0, 1), ZIndex = 22, OnClick = close, Parent = dialog })
	Button.new({ Text = props.ConfirmText or "OK", Style = "primary", Size = UDim2.new(0.5, -24, 0, Theme.TOUCH), Position = UDim2.new(1, -16, 1, -12), AnchorPoint = Vector2.new(1, 1), ZIndex = 22, OnClick = function()
		close()
		if props.OnConfirm then
			props.OnConfirm()
		end
	end, Parent = dialog })
	Sfx.play("UIOpen")
end

Theme.Changed:Connect(function()
	if current then
		resize(built[current])
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.ButtonB and current then
		Window.close()
	end
end)

return Window
