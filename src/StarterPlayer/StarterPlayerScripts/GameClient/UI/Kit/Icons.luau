--!strict
-- Icons: 3D images (Icons.<Group>.<id>) with the old flat shapes kept as a fallback for ids that
-- have no image yet. Icon ids are shared with Config/UI Menu, weapon categories and toast kinds.
local Theme = require(script.Parent.Theme)

local rgb = Color3.fromRGB

local Icons = {}

-- 3D icons rendered in Blender with the shared template (Blender/Icons/_IconTemplate.blend) and
-- uploaded to Roblox. Sources: Icons/<Group>/<id>.png and Blender/Icons/<Group>/<id>.blend.
Icons.Menu = {
	Hub = "rbxassetid://78324314568458",
	Index = "rbxassetid://110181092540409",
	Inventory = "rbxassetid://79699217856369",
	Pets = "rbxassetid://87961432830762",
	Quests = "rbxassetid://113023989103215",
	RebirthShop = "rbxassetid://114458665213719",
	Rewards = "rbxassetid://72322246886996",
	Settings = "rbxassetid://105368314181534",
	Shop = "rbxassetid://84453152556643",
	Stats = "rbxassetid://71235942557638",
	Team = "rbxassetid://77048844197287",
	Zones = "rbxassetid://87870957016250",
}
Icons.Currency = {
	Diamond = "rbxassetid://111694226932707",
	Gold = "rbxassetid://70512606638184",
	HealthHeart = "rbxassetid://87715477453344",
	Key = "rbxassetid://137031644082310",
	RebirthCredit = "rbxassetid://99588676527504",
	ZoneBoost = "rbxassetid://93633978298060",
}
Icons.Stats = {
	Attack = "rbxassetid://137835841351396",
	Crit = "rbxassetid://132335612435152",
	Defense = "rbxassetid://131900689208521",
	GoldGain = "rbxassetid://131899708084383",
	MaxHP = "rbxassetid://71889356267933",
	Speed = "rbxassetid://111503145787274",
}
Icons.Items = {
	Chest = "rbxassetid://134774043747832",
	Egg = "rbxassetid://93450406424053",
	Helmet = "rbxassetid://123418582134733",
	Legs = "rbxassetid://85544373051050",
	Pet = "rbxassetid://98845945273001",
	Trophy = "rbxassetid://80417676746268",
	Weapon = "rbxassetid://107109969437348",
}
Icons.Categories = {
	Dagger = "rbxassetid://72050021112662",
	Gauntlet = "rbxassetid://101679861341149",
	Heavy = "rbxassetid://82601398662224",
	Magic = "rbxassetid://74488887759460",
	Ranged = "rbxassetid://107838210333106",
	Spear = "rbxassetid://115877288350430",
	Sword = "rbxassetid://109014283536385",
	Whip = "rbxassetid://131679346612564",
}
Icons.Marks = {
	Arrow = "rbxassetid://133050853433089",
	Check = "rbxassetid://85216806609407",
	Close = "rbxassetid://94070366675137",
	Crown = "rbxassetid://89547984850233",
	Info = "rbxassetid://103973805729568",
	Lock = "rbxassetid://128219452761622",
	MenuLines = "rbxassetid://112737404070158",
	Plus = "rbxassetid://110393683182263",
	Skull = "rbxassetid://133585783255050",
	Star = "rbxassetid://131833469305832",
	Warning = "rbxassetid://96078521254826",
}
-- Teleport menu dioramas: one per zone (zone id) and per sub-zone ("Plains_1").
Icons.Zones = {
	Abyss = "rbxassetid://74619396639646",
	Dead = "rbxassetid://88642688552320",
	Desert = "rbxassetid://131197705313858",
	Heaven = "rbxassetid://78422699293280",
	Hell = "rbxassetid://91135552751474",
	Jungle = "rbxassetid://126235835421532",
	Mechanical = "rbxassetid://91556017684715",
	Plains = "rbxassetid://93513678676379",
	Swamp = "rbxassetid://87982777019395",
	Tundra = "rbxassetid://125213883761567",
	Void = "rbxassetid://119621554436838",
	Volcano = "rbxassetid://140087889662973",
}
Icons.SubZones = {
	Abyss_1 = "rbxassetid://106631420500626",
	Abyss_2 = "rbxassetid://107295321994577",
	Abyss_3 = "rbxassetid://85575591790796",
	Abyss_4 = "rbxassetid://79476419279734",
	Dead_1 = "rbxassetid://107294496457550",
	Dead_2 = "rbxassetid://125900342369721",
	Dead_3 = "rbxassetid://80705056488246",
	Dead_4 = "rbxassetid://129226493911121",
	Desert_1 = "rbxassetid://79054023809145",
	Desert_2 = "rbxassetid://103734269653806",
	Desert_3 = "rbxassetid://105960598289680",
	Desert_4 = "rbxassetid://96744326779176",
	Heaven_1 = "rbxassetid://115121574991531",
	Heaven_2 = "rbxassetid://134260505391918",
	Heaven_3 = "rbxassetid://89999021760568",
	Heaven_4 = "rbxassetid://80390253540235",
	Hell_1 = "rbxassetid://109477773108069",
	Hell_2 = "rbxassetid://84624215152660",
	Hell_3 = "rbxassetid://78550199456737",
	Hell_4 = "rbxassetid://74734059124073",
	Jungle_1 = "rbxassetid://76657839782928",
	Jungle_2 = "rbxassetid://110186822956894",
	Jungle_3 = "rbxassetid://123077809946103",
	Jungle_4 = "rbxassetid://93255042708472",
	Mechanical_1 = "rbxassetid://79469186975277",
	Mechanical_2 = "rbxassetid://103920335062106",
	Mechanical_3 = "rbxassetid://125095305425328",
	Mechanical_4 = "rbxassetid://128248118911807",
	Plains_1 = "rbxassetid://134648719990436",
	Plains_2 = "rbxassetid://79350473621730",
	Plains_3 = "rbxassetid://129194444397792",
	Plains_4 = "rbxassetid://135373183768089",
	Swamp_1 = "rbxassetid://130420011132395",
	Swamp_2 = "rbxassetid://94217071553219",
	Swamp_3 = "rbxassetid://92298560758532",
	Swamp_4 = "rbxassetid://85716721451323",
	Tundra_1 = "rbxassetid://74605200087985",
	Tundra_2 = "rbxassetid://82559049621886",
	Tundra_3 = "rbxassetid://128280513459643",
	Tundra_4 = "rbxassetid://125000000454536",
	Void_1 = "rbxassetid://99842594529207",
	Void_2 = "rbxassetid://137173702472960",
	Void_3 = "rbxassetid://86931584818293",
	Void_4 = "rbxassetid://98236512489595",
	Volcano_1 = "rbxassetid://118685137996283",
	Volcano_2 = "rbxassetid://120699571507933",
	Volcano_3 = "rbxassetid://102504048763223",
	Volcano_4 = "rbxassetid://96827613411523",
}

-- Older UI ids that now point at a 3D icon.
local ALIASES = {
	Heart = "HealthHeart", Boost = "ZoneBoost", Armor = "Chest", Gift = "Rewards", Training = "Stats",
	Admin = "Crown", Menu = "MenuLines",
}
local GROUPS = { "Menu", "Currency", "Stats", "Items", "Categories", "Marks", "Zones", "SubZones" }

-- The rendered icons keep a transparent margin (outline + shadow), so the image is drawn a bit larger
-- than its holder to fill the same space as the old flat shapes.
local IMAGE_BLEED = 1.14

-- Image id for an icon id (any group), or nil when only a placeholder shape exists.
function Icons.asset(id: string): string?
	local key = ALIASES[id] or id
	for _, group in ipairs(GROUPS) do
		local list = (Icons :: any)[group]
		if list and list[key] then
			return list[key]
		end
	end
	return nil
end

local C = {
	Gold = rgb(255, 201, 60), GoldDark = rgb(196, 140, 30), Silver = rgb(220, 226, 236), Steel = rgb(150, 156, 168),
	Wood = rgb(160, 104, 58), WoodDark = rgb(104, 66, 38), Leather = rgb(176, 112, 64), Paper = rgb(242, 228, 192),
	Red = rgb(217, 59, 59), Diamond = rgb(95, 212, 255), DiamondLight = rgb(210, 244, 255), Purple = rgb(168, 96, 236),
	Green = rgb(91, 200, 110), Blue = rgb(70, 130, 235), Bone = rgb(238, 230, 208), Dark = rgb(40, 26, 16),
	White = rgb(250, 250, 250), Orange = rgb(255, 150, 40),
}

-- { centerX, centerY, width, height, color, rotation, cornerFraction } in fractions of the icon
local PAW = { { 0.5, 0.66, 0.44, 0.36, "Paper", 0, 0.5 }, { 0.24, 0.42, 0.17, 0.2, "Paper", 0, 0.5 }, { 0.4, 0.26, 0.17, 0.2, "Paper", 0, 0.5 }, { 0.6, 0.26, 0.17, 0.2, "Paper", 0, 0.5 }, { 0.76, 0.42, 0.17, 0.2, "Paper", 0, 0.5 } }
local SHAPES: { [string]: { { any } } } = {
	Gold = { { 0.5, 0.5, 0.9, 0.9, "GoldDark", 0, 0.5 }, { 0.5, 0.5, 0.72, 0.72, "Gold", 0, 0.5 }, { 0.5, 0.5, 0.3, 0.3, "GoldDark", 0, 0.12 }, { 0.5, 0.5, 0.3, 0.3, "GoldDark", 45, 0.12 } },
	Diamond = { { 0.5, 0.5, 0.66, 0.66, "Diamond", 45, 0.08 }, { 0.41, 0.41, 0.22, 0.22, "DiamondLight", 45, 0.05 } },
	Heart = { { 0.34, 0.4, 0.38, 0.38, "Red", 0, 0.5 }, { 0.66, 0.4, 0.38, 0.38, "Red", 0, 0.5 }, { 0.5, 0.56, 0.46, 0.46, "Red", 45, 0.06 } },
	Plus = { { 0.5, 0.5, 0.62, 0.16, "Gold", 0, 0.3 }, { 0.5, 0.5, 0.16, 0.62, "Gold", 0, 0.3 } },
	Close = { { 0.5, 0.5, 0.72, 0.15, "White", 45, 0.3 }, { 0.5, 0.5, 0.72, 0.15, "White", -45, 0.3 } },
	Menu = { { 0.5, 0.28, 0.68, 0.13, "Gold", 0, 0.5 }, { 0.5, 0.5, 0.68, 0.13, "Gold", 0, 0.5 }, { 0.5, 0.72, 0.68, 0.13, "Gold", 0, 0.5 } },
	Sword = { { 0.57, 0.43, 0.13, 0.68, "Silver", 45, 0.1 }, { 0.33, 0.67, 0.44, 0.1, "Gold", 45, 0.3 }, { 0.23, 0.77, 0.09, 0.2, "Leather", 45, 0.3 }, { 0.15, 0.85, 0.12, 0.12, "Gold", 0, 0.5 } },
	Spear = { { 0.46, 0.54, 0.07, 0.86, "Wood", 45, 0.3 }, { 0.8, 0.2, 0.2, 0.2, "Silver", 45, 0.08 } },
	Heavy = { { 0.42, 0.58, 0.1, 0.72, "Wood", 45, 0.3 }, { 0.66, 0.34, 0.5, 0.26, "Steel", 45, 0.1 } },
	Dagger = { { 0.58, 0.42, 0.12, 0.46, "Silver", 45, 0.15 }, { 0.4, 0.6, 0.3, 0.09, "Gold", 45, 0.3 }, { 0.3, 0.7, 0.09, 0.18, "Leather", 45, 0.3 } },
	Gauntlet = { { 0.5, 0.56, 0.56, 0.46, "Steel", 0, 0.25 }, { 0.5, 0.33, 0.56, 0.14, "Silver", 0, 0.3 }, { 0.5, 0.84, 0.44, 0.14, "Leather", 0, 0.2 } },
	Ranged = { { 0.36, 0.22, 0.08, 0.34, "Wood", -30, 0.4 }, { 0.3, 0.5, 0.08, 0.3, "Wood", 0, 0.4 }, { 0.36, 0.78, 0.08, 0.34, "Wood", 30, 0.4 }, { 0.46, 0.5, 0.03, 0.78, "Paper", 0, 0 }, { 0.62, 0.5, 0.62, 0.05, "Silver", 0, 0 }, { 0.9, 0.5, 0.12, 0.12, "Silver", 45, 0 } },
	Magic = { { 0.44, 0.58, 0.08, 0.78, "Wood", 20, 0.3 }, { 0.58, 0.2, 0.32, 0.32, "Purple", 0, 0.5 }, { 0.55, 0.17, 0.12, 0.12, "White", 0, 0.5 } },
	Whip = { { 0.3, 0.78, 0.09, 0.3, "Leather", 30, 0.3 }, { 0.42, 0.55, 0.07, 0.34, "WoodDark", -20, 0.3 }, { 0.6, 0.4, 0.06, 0.3, "WoodDark", 40, 0.3 }, { 0.75, 0.22, 0.05, 0.26, "WoodDark", -10, 0.3 } },
	Inventory = { { 0.5, 0.62, 0.72, 0.6, "Leather", 0, 0.35 }, { 0.5, 0.3, 0.34, 0.16, "Leather", 0, 0.2 }, { 0.5, 0.38, 0.42, 0.08, "Gold", 0, 0.3 }, { 0.5, 0.64, 0.16, 0.16, "Gold", 0, 0.5 } },
	Training = { { 0.5, 0.5, 0.72, 0.1, "Steel", 0, 0.3 }, { 0.26, 0.5, 0.14, 0.52, "Dark", 0, 0.2 }, { 0.74, 0.5, 0.14, 0.52, "Dark", 0, 0.2 }, { 0.13, 0.5, 0.1, 0.34, "Steel", 0, 0.2 }, { 0.87, 0.5, 0.1, 0.34, "Steel", 0, 0.2 } },
	Stats = { { 0.27, 0.66, 0.16, 0.36, "Green", 0, 0.15 }, { 0.5, 0.56, 0.16, 0.56, "Blue", 0, 0.15 }, { 0.73, 0.46, 0.16, 0.76, "Red", 0, 0.15 }, { 0.5, 0.87, 0.86, 0.07, "Gold", 0, 0.3 } },
	Shop = { { 0.5, 0.76, 0.62, 0.14, "GoldDark", 0, 0.3 }, { 0.5, 0.62, 0.62, 0.14, "Gold", 0, 0.3 }, { 0.5, 0.48, 0.62, 0.14, "GoldDark", 0, 0.3 }, { 0.64, 0.28, 0.34, 0.34, "Gold", 0, 0.5 } },
	RebirthShop = { { 0.5, 0.5, 0.6, 0.6, "Purple", 0, 0.08 }, { 0.5, 0.5, 0.6, 0.6, "Purple", 45, 0.08 }, { 0.5, 0.5, 0.32, 0.32, "Gold", 0, 0.5 } },
	Pets = PAW,
	Pet = PAW,
	Index = { { 0.5, 0.5, 0.64, 0.8, "Red", 0, 0.1 }, { 0.24, 0.5, 0.1, 0.8, "Dark", 0, 0 }, { 0.76, 0.5, 0.08, 0.7, "Paper", 0, 0 }, { 0.52, 0.42, 0.22, 0.22, "Gold", 45, 0.1 } },
	Quests = { { 0.5, 0.5, 0.58, 0.62, "Paper", 0, 0.05 }, { 0.5, 0.18, 0.72, 0.14, "GoldDark", 0, 0.5 }, { 0.5, 0.82, 0.72, 0.14, "GoldDark", 0, 0.5 }, { 0.5, 0.42, 0.38, 0.05, "Dark", 0, 0 }, { 0.5, 0.54, 0.38, 0.05, "Dark", 0, 0 }, { 0.46, 0.66, 0.3, 0.05, "Dark", 0, 0 } },
	Team = { { 0.34, 0.32, 0.24, 0.24, "Paper", 0, 0.5 }, { 0.34, 0.7, 0.38, 0.36, "Blue", 0, 0.3 }, { 0.66, 0.3, 0.24, 0.24, "Paper", 0, 0.5 }, { 0.66, 0.68, 0.38, 0.36, "Green", 0, 0.3 } },
	Settings = { { 0.5, 0.5, 0.2, 0.86, "Steel", 0, 0.1 }, { 0.5, 0.5, 0.86, 0.2, "Steel", 0, 0.1 }, { 0.5, 0.5, 0.2, 0.86, "Steel", 45, 0.1 }, { 0.5, 0.5, 0.86, 0.2, "Steel", 45, 0.1 }, { 0.5, 0.5, 0.6, 0.6, "Steel", 0, 0.5 }, { 0.5, 0.5, 0.24, 0.24, "Dark", 0, 0.5 } },
	Egg = { { 0.5, 0.54, 0.56, 0.74, "Paper", 0, 0.5 }, { 0.42, 0.46, 0.12, 0.12, "Green", 0, 0.5 }, { 0.6, 0.66, 0.1, 0.1, "Green", 0, 0.5 } },
	Armor = { { 0.5, 0.48, 0.62, 0.62, "Steel", 0, 0.45 }, { 0.5, 0.58, 0.5, 0.1, "Dark", 0, 0.3 }, { 0.5, 0.36, 0.08, 0.4, "Silver", 0, 0.3 } },
	Info = { { 0.5, 0.5, 0.8, 0.8, "Blue", 0, 0.5 }, { 0.5, 0.3, 0.12, 0.12, "White", 0, 0.5 }, { 0.5, 0.6, 0.12, 0.34, "White", 0, 0.3 } },
	Warning = { { 0.5, 0.52, 0.64, 0.64, "Orange", 45, 0.12 }, { 0.5, 0.46, 0.1, 0.3, "Dark", 0, 0.3 }, { 0.5, 0.7, 0.1, 0.1, "Dark", 0, 0.5 } },
	Skull = { { 0.5, 0.44, 0.66, 0.56, "Bone", 0, 0.45 }, { 0.5, 0.74, 0.38, 0.2, "Bone", 0, 0.2 }, { 0.38, 0.44, 0.16, 0.16, "Dark", 0, 0.5 }, { 0.62, 0.44, 0.16, 0.16, "Dark", 0, 0.5 }, { 0.5, 0.58, 0.06, 0.1, "Dark", 0, 0.3 } },
	Gift = { { 0.5, 0.62, 0.66, 0.5, "Red", 0, 0.1 }, { 0.5, 0.36, 0.74, 0.16, "Red", 0, 0.1 }, { 0.5, 0.56, 0.12, 0.62, "Gold", 0, 0 }, { 0.4, 0.22, 0.18, 0.14, "Gold", 30, 0.5 }, { 0.6, 0.22, 0.18, 0.14, "Gold", -30, 0.5 } },
	Admin = { { 0.5, 0.66, 0.68, 0.22, "Gold", 0, 0.1 }, { 0.24, 0.44, 0.2, 0.2, "Gold", 45, 0.05 }, { 0.5, 0.38, 0.24, 0.24, "Gold", 45, 0.05 }, { 0.76, 0.44, 0.2, 0.2, "Gold", 45, 0.05 }, { 0.5, 0.66, 0.12, 0.12, "Red", 0, 0.5 } },
	Boost = { { 0.57, 0.31, 0.18, 0.48, "Gold", 25, 0.1 }, { 0.43, 0.69, 0.18, 0.48, "Gold", 25, 0.1 }, { 0.5, 0.5, 0.42, 0.12, "Gold", -20, 0.1 } },
}

-- A square-ish holder (fills its parent by default) with the icon drawn inside. props.Flat = true
-- forces the flat shape (for example the white "+" of the currency bars).
function Icons.create(id: string, parent: Instance?, props: { [string]: any }?): Frame
	local options = props or {}
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.Size = options.Size or UDim2.fromScale(1, 1)
	holder.Position = options.Position or UDim2.fromScale(0.5, 0.5)
	holder.AnchorPoint = options.AnchorPoint or Vector2.new(0.5, 0.5)
	holder.ZIndex = options.ZIndex or 1
	-- An icon sized by height only (width 0) is a square measured on the parent's height.
	if holder.Size.X.Scale == 0 and holder.Size.X.Offset == 0 then
		holder.Size = UDim2.new(holder.Size.Y.Scale, holder.Size.Y.Offset, holder.Size.Y.Scale, holder.Size.Y.Offset)
		holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
	else
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.Parent = holder
	end
	local asset = if options.Flat then nil else Icons.asset(id)
	if asset then
		local image = Instance.new("ImageLabel")
		image.Name = "Image"
		image.BackgroundTransparency = 1
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(IMAGE_BLEED, IMAGE_BLEED)
		image.ScaleType = Enum.ScaleType.Fit
		image.Image = asset
		image.ZIndex = holder.ZIndex
		image.Parent = holder
	else
		for _, shape in ipairs(SHAPES[id] or SHAPES.Info) do
			local part = Instance.new("Frame")
			part.BorderSizePixel = 0
			part.AnchorPoint = Vector2.new(0.5, 0.5)
			part.Position = UDim2.fromScale(shape[1], shape[2])
			part.Size = UDim2.fromScale(shape[3], shape[4])
			part.BackgroundColor3 = if options.Color then options.Color else C[shape[5]]
			part.Rotation = shape[6] or 0
			part.ZIndex = holder.ZIndex
			if (shape[7] or 0) > 0 then
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(shape[7], 0)
				corner.Parent = part
			end
			local stroke = Instance.new("UIStroke")
			stroke.Color = Theme.Colors.Ink
			stroke.Thickness = 1
			stroke.Transparency = 0.25
			stroke.Parent = part
			part.Parent = holder
		end
	end
	holder.Parent = parent
	return holder
end

-- Downloads every icon image once (call at startup) so the first toast or window shows its icon.
function Icons.preload()
	local labels = {}
	for _, group in ipairs(GROUPS) do
		for _, asset in pairs((Icons :: any)[group]) do
			local label = Instance.new("ImageLabel")
			label.Image = asset
			table.insert(labels, label)
		end
	end
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(labels)
		end)
		for _, label in ipairs(labels) do
			label:Destroy()
		end
	end)
end

-- Fades an icon made by Icons.create (image or shape), e.g. for empty slots.
function Icons.setFaded(holder: Instance, transparency: number)
	for _, d in ipairs(holder:GetDescendants()) do
		if d:IsA("ImageLabel") then
			d.ImageTransparency = transparency
		elseif d:IsA("Frame") then
			d.BackgroundTransparency = transparency
		end
	end
end

return Icons
