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
		-- combat (Config/CombatSfx, Assets.Sounds.Combat): the player's own and other players' fight sounds
		Combat_Sword_Swing1 = "PlayerFX", Combat_Sword_Swing2 = "PlayerFX", Combat_Sword_Swing3 = "PlayerFX",
		Combat_Sword_Rise1 = "PlayerFX", Combat_Sword_Rise2 = "PlayerFX", Combat_Sword_Rise3 = "PlayerFX",
		Combat_Sword_Spin1 = "PlayerFX", Combat_Sword_Spin2 = "PlayerFX",
		Combat_Sword_HitFlesh1 = "PlayerFX", Combat_Sword_HitFlesh2 = "PlayerFX", Combat_Sword_HitFlesh3 = "PlayerFX",
		Combat_Sword_HitMetal1 = "PlayerFX", Combat_Sword_HitMetal2 = "PlayerFX", Combat_Sword_HitMetal3 = "PlayerFX",
		Combat_Sword_HitStone1 = "PlayerFX", Combat_Sword_HitStone2 = "PlayerFX", Combat_Sword_HitStone3 = "PlayerFX",
		Combat_Sword_HitHeavy = "PlayerFX", Combat_Sword_Crit1 = "PlayerFX", Combat_Sword_Crit2 = "PlayerFX",
		Combat_Sword_Draw1 = "PlayerFX", Combat_Sword_Draw2 = "PlayerFX",
		Combat_Shared_Roll1 = "PlayerFX", Combat_Shared_Roll2 = "PlayerFX",
		Combat_Shared_BlockRaise = "PlayerFX", Combat_Shared_BlockClink = "PlayerFX",
		Combat_Shared_BlockHit1 = "PlayerFX", Combat_Shared_BlockHit2 = "PlayerFX", Combat_Shared_BlockHit3 = "PlayerFX",
		Combat_Shared_BlockBreak = "PlayerFX", Combat_Shared_BlockShatter = "PlayerFX",
		Combat_Shared_Hurt1 = "PlayerFX", Combat_Shared_Hurt2 = "PlayerFX", Combat_Shared_Hurt3 = "PlayerFX",
		Combat_Shared_Death = "PlayerFX",
	},
}
