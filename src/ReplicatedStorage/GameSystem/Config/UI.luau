--!strict
-- HUD, menus and windows (docs/ui_hud_brief.txt). Pure data: the UI scripts read everything here.
local UI = {}

-- Screen scaling. Sizes in the UI scripts are "design units"; scale = gui height / BaseHeight,
-- clamped, times the player's UI Scale setting. Touch screens never go below TouchMin so that
-- 56-unit controls stay >= 44 px. Below CompactHeight design units the HUD uses its phone layout.
UI.Scale = { BaseHeight = 660, Min = 0.6, Max = 1.4, TouchMin = 0.8, CompactHeight = 520 }

-- Minimum size of anything tappable, in design units (56 x 0.8 = 44.8 px on the smallest scale).
UI.TOUCH = 56

-- Menu buttons in order. The grid (MenuGrid) holds the entries without Apart, filled row by row;
-- Apart entries are separate icon buttons next to the health bar (next to the Menu button on phones).
UI.Menu = {
	{ Id = "Inventory", Label = "Inventory", Icon = "Inventory" },
	{ Id = "Stats", Label = "Stats", Icon = "Stats" },
	{ Id = "Shop", Label = "Shop", Icon = "Shop" },
	{ Id = "RebirthShop", Label = "Rebirth Shop", Icon = "RebirthShop" },
	{ Id = "Pets", Label = "Pets", Icon = "Pets" },
	{ Id = "Index", Label = "Index", Icon = "Index" },
	{ Id = "Quests", Label = "Quests", Icon = "Quests" },
	{ Id = "Team", Label = "Team", Icon = "Team" },
	{ Id = "Settings", Label = "Settings", Icon = "Settings", Apart = true },
	{ Id = "Zones", Label = "Zones", Icon = "Zones", Apart = true, ShowLabel = true }, -- teleport menu
}
-- 8 buttons -> 4 rows at the vertical middle of the left edge. PC (no touch) uses PcTile / PcGap,
-- tablets Tile / Gap; phones use the Menu pop-up.
UI.MenuGrid = { Columns = 2, Tile = 58, Gap = 5, PcTile = 80, PcGap = 6 }

-- Window shells. Size is the preferred size in design units; windows never exceed MaxScreenFraction.
UI.Windows = {
	Inventory = { Title = "Inventory", Tabs = { "Weapons", "Armor", "Eggs", "Trophies" }, Size = Vector2.new(820, 560) },
	-- The whole RPG system lives here (DESIGN.md section 3): stats, upgrades and derived stats.
	Stats = { Title = "Stats", Intro = "Your RPG stats will live here: HP, Attack, Defense, Speed, Crit and the derived stats." },
	Shop = { Title = "Shop", Tabs = { "Weapons", "Diamonds" }, Size = Vector2.new(1040, 600) },
	RebirthShop = { Title = "Rebirth Shop" },
	Pets = { Title = "Pets" },
	Index = { Title = "Index", Tabs = { "Weapons", "Armor", "Pets", "Enemies" } },
	Quests = { Title = "Quests", Tabs = { "Daily" } },
	Team = { Title = "Team" },
	Settings = { Title = "Settings", Tabs = { "Audio", "Display", "Controls", "Other" } },
	Zones = { Title = "Zones", Size = Vector2.new(860, 540) }, -- teleport menu: zone list, then sub-zones
	Admin = { Title = "Admin", Tabs = { "Money", "Teleport", "UI Test", "Weapons" }, Size = Vector2.new(760, 520) },
}
UI.WINDOW_SIZE = Vector2.new(700, 500)
UI.MaxScreenFraction = 0.9
UI.WINDOW_POP_SECONDS = 0.2
UI.WINDOW_START_SCALE = 0.9
UI.BACKDROP_TRANSPARENCY = 0.45

-- Red badges on menu buttons. Settings never shows one.
UI.BadgeIds = { "Inventory", "Quests", "Index", "Pets", "RebirthShop", "Shop" }
UI.BADGE_MAX_SHOWN = 9 -- above this the badge shows "9+"

UI.Hud = {
	Health = { Top = 10, Normal = Vector2.new(270, 54), Compact = Vector2.new(250, 50) }, -- top-left panel
	HealthSegments = 10,
	LowHealthFraction = 0.25,
	HealthTweenSeconds = 0.25,
	TrailDelaySeconds = 0.35,
	TrailTweenSeconds = 0.45,
	CountUpSeconds = 0.4,
	PopScale = 1.15,
	FloatSeconds = 0.9,
	TitleCardSeconds = 2,
	PetSlots = 3,
}

-- Gold and Diamonds bars (top-right, stacked in Order). Sizes in design units: Icon is the round
-- icon over the left end of the pill, Bar the pill height. Gold is longer for K/M/B/T/Qa amounts;
-- the amount shrinks to fit when it is still too long. The bar's "+" opens the Shop on ShopTab.
UI.Currencies = {
	Order = { "Gold", "Diamonds" }, -- profile keys
	Normal = { Icon = 62, Bar = 44, Gap = 4, Top = 8 },
	Compact = { Icon = 56, Bar = 38, Gap = 4, Top = 8 },
	Gold = { Icon = "Gold", Width = 270, CompactWidth = 226, ShopTab = "Weapons", Sound = "GoldPickup" },
	Diamonds = { Icon = "Diamond", Width = 200, CompactWidth = 170, ShopTab = "Diamonds", Sound = "GoldPickup" },
}

-- Weapon shop (docs/weapon_shop_brief.txt part 2): sizes in design units.
UI.WeaponShop = {
	TabWidth = 150, -- left column of category tabs (PC / tablet)
	TabHeight = 64,
	CardSize = Vector2.new(176, 254),
	CompactCardSize = Vector2.new(240, 152), -- phones: icon left, texts right, Buy below
	CompactInfoHeight = 24, -- phones: one line "Gold | pity" above the grid
	CardGap = 10,
	HeaderHeight = 56,
	PreviewSpinSeconds = 8, -- one turn of the preview model when nobody drags it
	RevealSeconds = 0.5, -- a newly unlocked zone's cards flip from silhouette to colors
	Locked = "???",
}

-- CS:GO-style case opening (part 4). The reel is cosmetic: the result is always the server's.
UI.CaseOpening = {
	SpinSeconds = 6, -- normal spin (ease-out quint)
	FastSpinSeconds = 1.5, -- with the "Fast Open" setting
	ServerGraceSeconds = 2, -- the server ends an opening the client never closed after spin + this
	TileCount = 60,
	WinIndex = 48, -- the server's rarity sits on this tile
	TileWidth = 140,
	CompactTileWidth = 110, -- phones
	TileGap = 8,
	MarkerScale = 1.08, -- the tile under the marker grows a little
	RevealScale = 1.15,
	TickMaxPitch = 1.35, -- the tick sound's pitch at full speed (1 when stopping)
	BurstFrom = 5, -- Legendary and better: burst of rays; Divine/Secret add a screen glow
	SecretStingSeconds = 2.2,
}

UI.Toast = {
	MaxVisible = 4,
	Seconds = 3,
	Width = 440,
	CompactWidth = 360,
	Height = 56,
	Gap = 6,
	SlideSeconds = 0.22,
}

UI.Fx = {
	LowFxRateFactor = 0.25, -- particle rate multiplier with Low FX on
	ShakeMaxOffset = 0.7, -- studs of camera offset at 100% intensity
	ShakeSeconds = 0.3,
	DamageShakeFraction = 0.25, -- losing this fraction of max HP in one hit = full shake
	CameraMinZoom = 8,
	CameraMaxZoom = 40,
}

UI.Text = {
	HubZone = "Hub",
	HubSubZone = "Safe zone",
	ArenaSubZone = "Boss Arena",
	NoWeapon = "No weapon",
	NoWeaponHint = "Buy one in the Shop",
	ComingSoon = "Coming soon",
	GetDiamonds = "Get diamonds",
	GetDiamondsInfo = "Diamond packs are sold at the Diamond Shop in the hub. Do you want to go there now?",
	ZoneBoost = "Zone Boost Active",
	YouAreHere = "You are here",
	Teleport = "Teleport",
	BossGate = "Boss Gate",
	ZoneLocked = "Zone locked",
	Back = "Back",
	HubDescription = "The safe hub: shops, the Rebirth Altar and the portals to every zone.",
	DeathGold = "You lost %d%% of your Gold: -%s",
}

return UI
