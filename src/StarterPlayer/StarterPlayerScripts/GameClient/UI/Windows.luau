--!strict
-- Window shells for every menu button (Config/UI Windows). Built so far: Shop (weapon shop), Inventory
-- (weapons), Settings and Zones; the others are empty shells: title, frame, X button, tabs, "Coming soon". The Shop's Diamonds tab
-- explains where diamond packs are sold and offers a trip to the hub.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local SettingsPage = require(script.Parent.Pages.SettingsPage)
local ZonesPage = require(script.Parent.Pages.ZonesPage)
local InventoryPage = require(script.Parent.Pages.InventoryPage)
local AttributesPage = require(script.Parent.Pages.AttributesPage)
local WeaponShopPage = require(script.Parent.Pages.WeaponShopPage)
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
	local page = ctx.Pages.Diamonds
	Theme.text({ Text = "Spend diamonds on rarity rerolls, premium eggs, Gold boosts and skins.", TextSize = 22, Wrapped = true, Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 1, Parent = page })
	Button.new({ Text = UIConfig.Text.GetDiamonds, Icon = "Diamond", Style = "primary", Size = UDim2.fromOffset(260, Theme.TOUCH), LayoutOrder = 2, Parent = page, OnClick = function()
		Window.confirm({
			Title = UIConfig.Text.GetDiamonds,
			Text = UIConfig.Text.GetDiamondsInfo,
			ConfirmText = "Go to hub",
			CancelText = "Not now",
			OnConfirm = function()
				Window.close()
				Net.request("GoToHub")
			end,
		})
	end })
	Window.placeholder(page)
end

local function inventory(ctx: any)
	InventoryPage.buildWeapons(ctx.Pages.Weapons)
	for name, page in pairs(ctx.Pages) do
		if name ~= "Weapons" then
			Window.placeholder(page)
		end
	end
end

local BUILDERS = {
	Shop = shop,
	Inventory = inventory,
	Stats = function(ctx: any)
		AttributesPage.build(ctx.Pages.Main)
	end,
	Settings = SettingsPage.build,
	Zones = ZonesPage.build,
}

function Windows:Start()
	-- the server opens windows for world objects (a hub portal opens the teleport menu on its zone)
	Net.on("OpenWindow", function(id: any, arg: any)
		if id == "Zones" then
			ZonesPage.open(if typeof(arg) == "string" then arg else nil)
		elseif typeof(id) == "string" and UIConfig.Windows[id] and id ~= "Admin" then
			Window.open(id)
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
