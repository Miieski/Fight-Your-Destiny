--!strict
-- A hub portal is invisible until its zone opens for this player, then it builds itself from its real bricks, bottom up, keystone
-- last, and lights up (Controllers/PortalController, Round 9 part 12; the bricks: ReplicatedStorage.Assets.PortalBricks, made by
-- DevTools.PortalBricks). Personal: it plays once, on that player's client. At join an open portal is there at once, finished.
-- A player far away when the zone opens sees it on the way back (Range): it waits for the portal to be streamed in and near.
return {
	Seconds = 3.7, -- first brick leaves .. the last one lands, the keystone included
	Flight = 0.55, -- each brick
	KeystoneFlight = 0.7,
	KeystonePause = 0.2, -- a beat before the keystone
	Jitter = 0.05, -- random delay of each brick, seconds
	Ease = Enum.EasingStyle.Cubic, -- out
	Order = { "Base", "Pillar", "Arch", "Sign", "Keystone" }, -- groups of the bricks; inside one, by height
	-- where a brick comes from: chance, then a distance. Force = groups that always come from that side.
	Offsets = {
		Ground = { Chance = 0.5, Min = 7, Max = 12 },
		Sides = { Chance = 0.3, Min = 6, Max = 11 },
		Above = { Chance = 0.2, Min = 5, Max = 9 },
	},
	Force = { Base = "Ground", Keystone = "Above" },
	Scatter = 1.5, -- random sideways shift of the start
	Spin = 0.6, -- random turn of the start, radians
	FadeIn = 0.2, -- part of the flight spent appearing
	Sound = { "Combat_Shared_LandCrack1", "Combat_Sword_HitStone2" }, -- in the game already, played in turn
	SoundEvery = 5, -- landings
	KeystoneSound = "Combat_Sword_HitStone1",
	LightSound = "Unlock",
	DustEvery = 2, -- landings
	DustBurst = 4,
	DustColor = Color3.fromRGB(196, 176, 150),
	RampSeconds = 1.2, -- activation: gems, field, moss and lights come up
	GemDim = 0.75, -- how dark a gem is until then
	PulseBurst = 40,
	Range = 240, -- studs from the portal: it waits until the player is this close
	MaxAtOnce = 2, -- portals assembling together; the others wait their turn (unlockAll)
	Clearance = Vector3.new(13, 16, 6.5), -- half size of the spot around the centre of the field: a player in it keeps the portal
	-- without collision until they walk out, so the bricks can never push, trap or fling them
}
