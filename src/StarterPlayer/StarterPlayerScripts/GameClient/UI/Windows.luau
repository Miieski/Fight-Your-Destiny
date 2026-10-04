--!strict
-- Window shells for every menu button (Config/UI Windows). For now everything except Settings is an
-- empty shell: title, frame, X button, tabs and a "Coming soon" placeholder. The Shop's Diamonds tab
-- explains where diamond packs are sold and offers a trip to the hub.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.GameSystem.Net)
local UIConfig = require(ReplicatedStorage.GameSystem.Config.UI)
local SettingsPage = require(script.Parent.Pages.SettingsPage)
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
	Window.placeholder(ctx.Pages.Weapons)
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

local BUILDERS = {
	Shop = shop,
	Settings = SettingsPage.build,
}

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
