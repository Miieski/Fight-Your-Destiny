--!strict
-- Round 9 part 14: ruins mark the NEXT portal to open, personal to each player (the first locked zone in Config/Zones order); later
-- locked portals stay invisible (Controllers/PortalController). A ruin is made of the real bricks of its portal
-- (ReplicatedStorage.Assets.PortalRuins.<Zone>, made by DevTools.PortalRuins), so the portal builds itself from it. Plains is always
-- open and has no ruin. Stored anchors, not the hub's parts: the hub may not be streamed in. A ruin only exists for a player near it.
-- The rules and prices shown on its sign are those of Config/RebirthZoneUnlock.
local Zones = require(script.Parent.Zones)

local rgb = Color3.fromRGB

local function ruin(x: number, z: number, yaw: number, template: string, rune: Color3): { Anchor: CFrame, Template: string, Rune: Color3 }
	return { Anchor = CFrame.new(x, -0.6, z) * CFrame.Angles(0, yaw, 0), Template = template, Rune = rune }
end

local PortalRuins = {}

-- Anchor = the pivot of Hub.Decor.PortalFrames.PortalFrame_<Zone>. DevTools.PortalRuins.check compares them.
PortalRuins.Zones = {
	Desert = ruin(100.7993, 15.6046, 1.41721, "portal_ruins_desert", rgb(244, 208, 124)),
	Jungle = ruin(93.4690, 40.8356, 1.15890, "portal_ruins_jungle", rgb(40, 150, 66)),
	Tundra = ruin(79.9367, 63.3571, 0.90059, "portal_ruins_tundra", rgb(150, 214, 250)),
	Swamp = ruin(61.1004, 81.6746, 0.64228, "portal_ruins_swamp", rgb(170, 80, 255)),
	Volcano = ruin(38.2099, 94.5728, 0.38397, "portal_ruins_volcano", rgb(255, 120, 30)),
	Hell = ruin(-38.2099, 94.5728, -0.38397, "portal_ruins_hell", rgb(200, 36, 40)),
	Heaven = ruin(-61.1004, 81.6746, -0.64228, "portal_ruins_heaven", rgb(255, 208, 84)),
	Dead = ruin(-79.9367, 63.3571, -0.90059, "portal_ruins_dead", rgb(120, 255, 190)),
	Abyss = ruin(-93.4690, 40.8356, -1.15890, "portal_ruins_abyss", rgb(60, 255, 250)),
	Mechanical = ruin(-100.7993, 15.6046, -1.41721, "portal_ruins_mechanical", rgb(255, 140, 40)),
	Void = ruin(-101.4412, -10.6619, -1.67552, "portal_ruins_void", rgb(255, 60, 220)),
}

PortalRuins.ShowRange = 400 -- studs from the ruin: built nearer than this, gone further away
PortalRuins.FadeIn = 0.8 -- seconds, when a ruin appears because a zone opened; at join and on the way back it is simply there

-- The sign. Rebirths is a line because the buy rule still counts them (a player with the key and the Gold must see why Buy is refused).
PortalRuins.Sign = {
	Key = "Boss key: %s",
	Owned = "owned",
	Missing = "missing",
	Gold = "Gold: %s",
	Rebirths = "Rebirths: %d / %d",
	Action = "Open Zones menu",
	Buy = "Buy",
	Hold = 0.4, -- seconds
	Distance = 12, -- studs
	Sink = 7, -- how far the sign slides into the ground during the build
}

-- The build from the ruin (the timing and the sounds stay in Config/PortalBuild). A brick the ruin does not hold comes from there.
PortalRuins.Build = {
	Missing = { Pillar = "Ground", Arch = "Pile", Sign = "Pile", Keystone = "Pile", Base = "Ground" },
	PileDrop = 1.2, -- studs under the pile, where such a brick starts
	PileScatter = 1.5,
	Arc = 3, -- studs a lying brick rises on its way back
	DecorEnd = 0.4, -- part of the build at which moss, cracks and rune have gone
	SignStart = 0.15, -- part of the build at which the sign starts to sink
	SignEnd = 0.6,
}

-- The Zones menu's Locate button (UI/Kit/RuinGuide): a Beam from the player to the ruin, a light pillar on it, the distance.
PortalRuins.Locate = {
	Seconds = 10,
	Fade = 0.6,
	Tick = 0.25, -- seconds between two updates of the distance: nothing runs per frame
	MetersPerStud = 0.28,
	Texture = "rbxassetid://113197864152300",
	Width = 3.6,
	Brightness = 3,
	TextureLength = 4, -- studs per chevron
	TextureSpeed = 1.2,
	PillarHeight = 60,
	PillarWidth = 3,
	TeleportJump = 80, -- studs moved in one Tick: the player was teleported, the guide stops
	FarText = "The ruins of %s are in the Hub",
}

PortalRuins.Images = {
	Cracks = "rbxassetid://139312163732968",
	Rune = "rbxassetid://91713112602793",
}

-- The next portal of a player: the first locked zone. nil: all open, or the data has not arrived yet.
function PortalRuins.nextZone(zonesTable: { [string]: any }?): string?
	if typeof(zonesTable) ~= "table" then
		return nil
	end
	for _, zone in ipairs(Zones.List) do
		if not Zones.isUnlocked(zonesTable, zone.Id) then
			return if Zones.NOT_BUILT[zone.Id] then nil else zone.Id
		end
	end
	return nil
end

return PortalRuins
