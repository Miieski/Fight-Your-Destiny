--!strict
-- The hub portal of a zone that just opened builds itself, brick by brick, then lights up (Controllers/PortalController,
-- Round 8 part 3). Personal: it plays once on that player's client; later, and at join, the finished portal is shown.
-- A player far from the hub when the zone opens sees it on the way back (Range).
return {
	Seconds = 4, -- from the first brick to the last
	RiseSeconds = 0.45, -- each brick's flight
	Range = 240, -- studs from the portal: it waits until the player is this close
	StartDepth = 4, -- bricks start this far under the base
	StartSpread = 7, -- and this far around their place
	Rows = 10, -- per pillar (two bricks a row)
	BrickHeight = 1.6,
	PillarX = 7.6,
	PillarWidth = 4.4,
	PillarDepth = 5.4,
	ArchBricks = 9,
	ArchWidth = 18,
	ArchHeight = 2.2,
	ArchDepth = 4.4,
	Sound = "Combat_Shared_LandCrack1", -- every SoundEvery bricks (placeholder)
	SoundEvery = 6,
	DustBurst = 5,
	DustColor = Color3.fromRGB(196, 176, 150),
	PulseBurst = 40,
}
