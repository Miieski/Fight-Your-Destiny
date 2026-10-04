--!strict
-- Settings of the PLACEHOLDER playable layer (walk the world, open gates, hit dummy enemies).
-- Everything here goes away when the real combat, weapons, enemies and DataStore arrive.
local rgb = Color3.fromRGB

return {
	StartGold = 0,
	FreeGates = false, -- true = gates open without paying (fast walkthrough)
	GoldMultiplier = 1, -- raise to open gates faster while testing

	-- Test weapon: a Common sword of the zone the player stands in (docs/weapon_system_document.txt).
	WeaponBaseDamage = 10, -- x 10^(zone - 1)
	AttackCooldown = 0.5,
	AttackRange = 10,
	AttackArcDot = 0.1, -- targets must be in front of the player
	MaxTargets = 3,
	CritChance = 0.05,
	CritMultiplier = 2,

	ZoneCheckInterval = 0.5,
	HubRadius = 600, -- players within this distance of the hub center are "in the Hub"
	TeleportCooldown = 2,
	EmptySubZoneDespawnSeconds = 15,
	ArenaOrigin = Vector3.new(0, 0, -4000), -- runtime boss arenas are cloned here, 600 studs apart
	ArenaSpacing = 600,
	ArenaCleanupSeconds = 15,

	-- One generic dummy model stands in for every enemy; it is tinted per zone and scaled per role.
	DummyScale = { Normal = 1, MiniBoss = 2.2, Boss = 3.6 },
	DummyColors = {
		Plains = rgb(110, 200, 80), Desert = rgb(240, 170, 80), Jungle = rgb(40, 150, 110),
		Tundra = rgb(96, 104, 224), Swamp = rgb(150, 90, 200), Volcano = rgb(255, 110, 40),
		Hell = rgb(236, 226, 204), Heaven = rgb(70, 130, 235), Dead = rgb(120, 220, 180),
		Abyss = rgb(60, 140, 230), Mechanical = rgb(140, 150, 165), Void = rgb(210, 70, 230),
	},
}
