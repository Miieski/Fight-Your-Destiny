--!strict
-- Window shells for every menu button (Config/UI Windows). Built so far: Shop (weapon shop), Inventory
-- (weapons), Stats (Attributes), Pets (pets, eggs, premium eggs), Settings and Zones; the others are empty shells: title, frame, X button, tabs, "Coming soon". The Shop's Diamonds tab
-- explains where diamond packs are sold and offers a trip to the hub.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local SettingsPage = require(script.Parent.Pages.SettingsPage)
local ZonesPage = require(script.Parent.Pages.ZonesPage)
local InventoryPage = require(script.Parent.Pages.InventoryPage)
local TrophiesPage = require(script.Parent.Pages.TrophiesPage)
local AttributesPage = require(script.Parent.Pages.AttributesPage)
local WeaponShopPage = require(script.Parent.Pages.WeaponShopPage)
local PetsPage = require(script.Parent.Pages.PetsPage)
local ArmorPage = require(script.Parent.Pages.ArmorPage)
local EquipmentPage = require(script.Parent.Pages.EquipmentPage)
local DiamondShopPage = require(script.Parent.Pages.DiamondShopPage)
local RebirthShopPage = require(script.Parent.Pages.RebirthShopPage)
local IndexPage = require(script.Parent.Pages.IndexPage)
local QuestsPage = require(script.Parent.Pages.QuestsPage)
local TeamUI = require(script.Parent.Team)
local Kit = script.Parent.Kit
local Button = require(Kit.Button)
local Theme = require(Kit.Theme)
local Window = require(Kit.Window)

local Windows = { Priority = 4 }

local function placeholders(ctx: any, intro: string?)
	for _, page in pairs(ctx.Pages) do
		if intro then
			Theme.text({ Text = intro, TextSize = 22, Wrapped = true, Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 1, Parent = page })
		end
		Window.placeholder(page)
	end
end

local function shop(ctx: any)
	WeaponShopPage.build(ctx.Pages.Weapons, ctx)
	DiamondShopPage.build(ctx.Pages.Diamonds, ctx)
end

-- Inventory: Equipment (default), Weapons, Armor, Pets and Eggs (shortcuts to the Pets window), Trophies.
local function shortcut(page: ScrollingFrame, text: string, tab: string)
	Theme.text({ Text = text, TextSize = 22, Wrapped = true, Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 1, Parent = page })
	Button.new({ Text = "Open Pets", Icon = "Pets", Style = "primary", Size = UDim2.fromOffset(240, Theme.TOUCH), LayoutOrder = 2, Parent = page, OnClick = function()
		Window.open("Pets", tab)
	end })
	-- choosing the tab jumps straight to the Pets window
	page:GetPropertyChangedSignal("Visible"):Connect(function()
		if page.Visible and Window.isOpen("Inventory") then
			task.defer(Window.open, "Pets", tab)
		end
	end)
end

local function inventory(ctx: any)
	EquipmentPage.build(ctx.Pages.Equipment, ctx)
	InventoryPage.buildWeapons(ctx.Pages.Weapons)
	ArmorPage.build(ctx.Pages.Armor, ctx)
	shortcut(ctx.Pages.Pets, "Your pets live in the Pets window.", "Pets")
	shortcut(ctx.Pages.Eggs, "Your eggs are hatched in the Pets window.", "Eggs")
	TrophiesPage.build(ctx.Pages.Trophies)
end

local BUILDERS = {
	Shop = shop,
	Inventory = inventory,
	Stats = function(ctx: any)
		AttributesPage.build(ctx.Pages.Main)
	end,
	Settings = SettingsPage.build,
	Pets = PetsPage.build,
	Index = IndexPage.build,
	Quests = QuestsPage.build,
	Team = TeamUI.buildPage,
	RebirthShop = function(ctx: any)
		RebirthShopPage.build(ctx.Pages.Main)
	end,
	Zones = ZonesPage.build,
}

function Windows:Start()
	-- the server opens windows for world objects (a hub portal opens the teleport menu on its zone)
	Net.on("OpenWindow", function(id: any, arg: any)
		if id == "Zones" then
			ZonesPage.open(if typeof(arg) == "string" then arg else nil)
		elseif typeof(id) == "string" and UIConfig.Windows[id] and id ~= "Admin" then
			Window.open(id, if typeof(arg) == "string" then arg else nil)
		end
	end)
end

function Windows:Init()
	for id, def in pairs(UIConfig.Windows) do
		if id ~= "Admin" then
			Window.define(id, { Title = def.Title, Tabs = def.Tabs, Size = def.Size, Build = BUILDERS[id] or function(ctx)
				placeholders(ctx, def.Intro)
			end })
		end
	end
end

return Windows
