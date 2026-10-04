--!strict
-- Sound routing (docs/ui_hud_brief.txt section 6). Every sound plays through one SoundGroup;
-- the "Master" group is the parent of all the others.
return {
	MASTER = "Master",
	Groups = { "Music", "PlayerFX", "EnemyFX", "UI", "Ambient" },
	-- SoundGroup -> setting that controls its volume (0-100)
	VolumeSetting = {
		Master = "MasterVolume",
		Music = "MusicVolume",
		PlayerFX = "PlayerFxVolume",
		EnemyFX = "EnemyFxVolume",
		UI = "UiVolume",
		Ambient = "AmbientVolume",
	},
	DefaultGroup = "PlayerFX",
	-- Sound name -> group (names not listed use DefaultGroup)
	GroupOfSound = {
		UIClick = "UI", UIOpen = "UI", UIClose = "UI", Purchase = "UI", Denied = "UI",
		RarityReveal = "UI", RarityLegendary = "UI", GoldPickup = "UI", Unlock = "UI",
		LevelUp = "UI", EggCrack = "UI", PetHatch = "UI", PortalEnter = "UI",
		EnemyDeath = "EnemyFX", BossRoar = "EnemyFX", TelegraphWarn = "EnemyFX",
	},
}
