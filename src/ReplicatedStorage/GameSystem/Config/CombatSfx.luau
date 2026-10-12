--!strict
-- Combat sounds (docs/weapons_combat_brief.txt 4D, contract in docs/COMBAT_CONTRACTS.md section 5).
-- OWNER: the SFX sub-agent. Read by Util/Sfx (Sfx.combat). The Sound instances live in
-- ReplicatedStorage.Assets.Sounds.Combat (their Volume = the loudness-matched base level, InverseTapered roll-off
-- 10-150 studs, attributes SourceAssetId / SourceName / SourceCreator: all from the Pro Sound Effects catalog).
--
-- How a call resolves:  Sfx.combat(event, ctx)
--   1. the category entry Categories[ctx.Category] (DefaultCategory when the category is unknown), else Shared
--   2. Swing  -> the weapon style's entry when the Tool's WeaponId has one (WeaponStyles: crossbow, gun, blowgun),
--                then Swing.Finisher when ctx.Finisher, else Swing.Steps[ctx.Step] (wraps around)
--      Impact -> Impact.Materials[ctx.Material or DefaultMaterial] (else Shared.Impact's), times Impact.Finisher on a
--                finisher, plus Impact.Crit layered on a crit
--      Shot   -> Shot.Enemy for enemy shots, Shot.Player for other players' shots, nothing for the player's own
--                (its release is the Swing)
--      Burst  -> Burst.Styles[ctx.Style or StyleGroups[ctx.Style]] (Slam, Enemy, magic element groups), else Default
--      Equip  -> the spec, plus the existing rarity chime (EquipChime) for a high rarity weapon
--      others -> the spec itself
--   3. a spec = { Set, Volume?, Pitch?, Lead?, Hit?, At?, Also? }: one variant of the Set (never the same twice in a
--      row), random pitch +-PitchRange, Volume / Pitch multiply the Sound's own; Also = more specs played together
--      (layers, they inherit the timing of their parent).
-- Timing (seconds at attack speed x1, divided by ctx.Speed): a Swing spec's variant Peak lands Lead (default HitLead)
-- before the step's hit (Config/Combat Combos[category][step].Impact) - delayed, or skipping the start of the file when
-- the hit comes sooner; Hit = sync to that time instead (Dagger's second slash, the Magic burst at the release);
-- At = start the file at that time, no sync (bow redraw, crossbow reload). Other events play at once.
-- ctx.Position and ctx.IsLocal == false -> a 3D sound there at RemoteVolume; a Position with IsLocal unknown (Burst,
-- Shot) counts as the player's own within NearLocal studs of the local character; IsLocal == true or no Position
-- -> the local player's own sound (2D, full volume).
local CombatSfx = {}

CombatSfx.Cap = 12 -- combat sounds playing at once; a new one stops the oldest
CombatSfx.PitchRange = 0.05 -- random pitch +-5 %
CombatSfx.RemoteVolume = 0.8 -- other players' sounds (3D at ctx.Position)
CombatSfx.NearLocal = 10 -- studs: a Burst / Shot this close to the local character is the player's own (no RemoteVolume)
CombatSfx.Range = 150 -- studs from the camera: farther 3D sounds are skipped (= the Sounds' RollOffMaxDistance)
CombatSfx.StackWindow = 0.05 -- one swing hitting many enemies: at most StackMax sounds of the same Set
CombatSfx.StackMax = 2 -- within StackWindow seconds
-- sets heard once per window (two enemies biting on the same tick, one swing critting two enemies, one slam)
CombatSfx.StackMaxOf = {
	Hurt = 1, BlockHit = 1, Death = 1, SwordCrit = 1, DaggerCrit = 1, GauntletCrit = 1, MagicHolyChime = 1,
	HeavySlamBoom = 1, HeavySlamDebris = 1,
} :: { [string]: number }
CombatSfx.HitLead = 0.02 -- a whoosh peaks this long before the hit lands
CombatSfx.PoolMax = 4 -- idle copies kept per sound (pooled, no Clone once warm)
CombatSfx.Prewarm = 2 -- copies made per sound when the client starts (after ContentProvider:PreloadAsync)
CombatSfx.DefaultMaterial = "flesh" -- enemies are creatures today; "metal" and "stone" sets are ready
CombatSfx.DefaultCategory = "Sword" -- unknown categories use this one

-- Ranged weapons that are not bows (Tool attribute WeaponId -> Swing.Styles key); every other Ranged is a bow.
CombatSfx.WeaponStyles = {
	tundra_ranged = "Crossbow", hell_ranged = "Crossbow", dead_ranged = "Crossbow",
	jungle_ranged = "Blowgun", abyss_ranged = "Gun", mechanical_ranged = "Gun",
} :: { [string]: string }

-- Burst ctx.Style (a weapon element, "Arcane", "Slam", "Enemy") -> Burst.Styles key.
CombatSfx.StyleGroups = {
	Nature = "Nature", Sand = "Earth", Poison = "Poison", Frost = "Frost", Curse = "Dark", Burn = "Fire",
	Hellfire = "Fire", Holy = "Holy", ["Soul Drain"] = "Dark", Tidal = "Water", Shock = "Shock", Gravity = "Dark",
	Arcane = "Arcane", Physical = "Arcane",
} :: { [string]: string }

-- Equip of a weapon of this rarity or more layers the game's rarity sound (Assets.Sounds.SFX, its own UI group).
CombatSfx.EquipChime = { From = 5, Legendary = 7, Volume = 0.3 } -- RarityReveal from From, RarityLegendary from Legendary

-- Variants of one sound. Name = Sound in Assets.Sounds.Combat; Peak = seconds into the file where it is loudest;
-- Length = seconds into the file where it has faded (the voice is freed then); Start = seconds skipped at play.
-- Peak / Length were measured with an AudioAnalyzer (RMS envelope, +-0.02 s).
CombatSfx.Sets = {
	-- Sword
	SwordSwing = { -- right / left slash
		{ Name = "Combat_Sword_Swing1", Peak = 0.12, Length = 0.3 },
		{ Name = "Combat_Sword_Swing2", Peak = 0.12, Length = 0.3 },
		{ Name = "Combat_Sword_Swing3", Peak = 0.1, Length = 0.3 },
	},
	SwordRise = { -- rising slash
		{ Name = "Combat_Sword_Rise1", Peak = 0.11, Length = 0.3 },
		{ Name = "Combat_Sword_Rise2", Peak = 0.06, Length = 0.3 },
		{ Name = "Combat_Sword_Rise3", Peak = 0.17, Length = 0.35 },
	},
	SwordSpin = { -- spinning slash finisher (heavier)
		{ Name = "Combat_Sword_Spin1", Peak = 0.17, Length = 0.5 },
		{ Name = "Combat_Sword_Spin2", Peak = 0.2, Length = 0.55 },
	},
	SwordHitFlesh = {
		{ Name = "Combat_Sword_HitFlesh1", Peak = 0, Length = 0.3 },
		{ Name = "Combat_Sword_HitFlesh2", Peak = 0.01, Length = 0.25 },
		{ Name = "Combat_Sword_HitFlesh3", Peak = 0.03, Length = 0.25 },
	},
	SwordHitMetal = {
		{ Name = "Combat_Sword_HitMetal1", Peak = 0.01, Length = 0.25 },
		{ Name = "Combat_Sword_HitMetal2", Peak = 0, Length = 0.3 },
		{ Name = "Combat_Sword_HitMetal3", Peak = 0, Length = 0.4 },
	},
	SwordHitStone = {
		{ Name = "Combat_Sword_HitStone1", Peak = 0.04, Length = 0.65 },
		{ Name = "Combat_Sword_HitStone2", Peak = 0.1, Length = 0.6 },
		{ Name = "Combat_Sword_HitStone3", Peak = 0.08, Length = 0.65 },
	},
	SwordHitHeavy = { -- body thud layered under the finisher's impact
		{ Name = "Combat_Sword_HitHeavy", Peak = 0.03, Length = 0.3 },
	},
	SwordCrit = { -- bright blade ring layered on a crit
		{ Name = "Combat_Sword_Crit1", Peak = 0.1, Length = 0.55 },
		{ Name = "Combat_Sword_Crit2", Peak = 0.08, Length = 0.4 },
	},
	SwordDraw = {
		{ Name = "Combat_Sword_Draw1", Peak = 0, Length = 0.45 },
		{ Name = "Combat_Sword_Draw2", Peak = 0, Length = 0.4 },
	},
	-- Spear
	SpearThrust = {
		{ Name = "Combat_Spear_Thrust1", Peak = 0.09, Length = 0.25 },
		{ Name = "Combat_Spear_Thrust2", Peak = 0.06, Length = 0.25 },
		{ Name = "Combat_Spear_Thrust3", Peak = 0.08, Length = 0.25 },
	},
	SpearPierce = { -- piercing lunge finisher (longer, hissing)
		{ Name = "Combat_Spear_Pierce1", Peak = 0.33, Length = 0.7, Start = 0.12 },
		{ Name = "Combat_Spear_Pierce2", Peak = 0.21, Length = 0.45 },
	},
	SpearStab = {
		{ Name = "Combat_Spear_Stab1", Peak = 0, Length = 0.5 },
		{ Name = "Combat_Spear_Stab2", Peak = 0.05, Length = 0.25, Start = 0.03 },
		{ Name = "Combat_Spear_Stab3", Peak = 0.05, Length = 0.25, Start = 0.03 },
	},
	-- Heavy
	HeavySwing = { -- slow, low whoosh (overhead slam)
		{ Name = "Combat_Heavy_Swing1", Peak = 0.31, Length = 0.65 },
		{ Name = "Combat_Heavy_Swing2", Peak = 0.38, Length = 0.65 },
		{ Name = "Combat_Heavy_Swing3", Peak = 0.38, Length = 0.7, Start = 0.2 },
	},
	HeavySmash = { -- wide smash finisher (rumbling)
		{ Name = "Combat_Heavy_Smash1", Peak = 0.42, Length = 1.0 },
		{ Name = "Combat_Heavy_Smash2", Peak = 0.5, Length = 1.1, Start = 0.15 },
	},
	HeavySlamBoom = { -- ground slam (Burst "Slam"), dark magic, enemy heavy attacks
		{ Name = "Combat_Heavy_SlamBoom1", Peak = 0.02, Length = 0.8 },
		{ Name = "Combat_Heavy_SlamBoom2", Peak = 0.09, Length = 0.4 },
	},
	HeavySlamDebris = { -- rock crack layered under the slam boom
		{ Name = "Combat_Heavy_SlamDebris1", Peak = 0.12, Length = 1.3, Start = 0.08 },
		{ Name = "Combat_Heavy_SlamDebris2", Peak = 0.12, Length = 1.3, Start = 0.08 },
	},
	HeavyHitFlesh = {
		{ Name = "Combat_Heavy_HitFlesh1", Peak = 0.24, Length = 0.8, Start = 0.2 },
		{ Name = "Combat_Heavy_HitFlesh2", Peak = 0.24, Length = 0.7, Start = 0.2 },
		{ Name = "Combat_Heavy_HitFlesh3", Peak = 0.11, Length = 0.5, Start = 0.04 },
	},
	HeavyEquip = {
		{ Name = "Combat_Heavy_Equip", Peak = 0.27, Length = 0.55, Start = 0.23 },
	},
	-- Dagger
	DaggerSlash = { -- very short, light
		{ Name = "Combat_Dagger_Slash1", Peak = 0.02, Length = 0.18 },
		{ Name = "Combat_Dagger_Slash2", Peak = 0.04, Length = 0.18 },
		{ Name = "Combat_Dagger_Slash3", Peak = 0.04, Length = 0.2 },
		{ Name = "Combat_Dagger_Slash4", Peak = 0.01, Length = 0.18 },
	},
	DaggerHitFlesh = {
		{ Name = "Combat_Dagger_HitFlesh1", Peak = 0, Length = 0.2 },
		{ Name = "Combat_Dagger_HitFlesh2", Peak = 0.01, Length = 0.3 },
		{ Name = "Combat_Dagger_HitFlesh3", Peak = 0.09, Length = 0.35, Start = 0.06 },
	},
	DaggerCrit = { -- short knife shing (daggers crit often)
		{ Name = "Combat_Dagger_Crit1", Peak = 0.01, Length = 0.2 },
		{ Name = "Combat_Dagger_Crit2", Peak = 0.01, Length = 0.2 },
	},
	DaggerDraw = {
		{ Name = "Combat_Dagger_Draw1", Peak = 0.24, Length = 0.4, Start = 0.18 },
		{ Name = "Combat_Dagger_Draw2", Peak = 0.13, Length = 0.3, Start = 0.04 },
	},
	-- Gauntlet
	GauntletSwing = { -- jab / cross punch whoosh
		{ Name = "Combat_Gauntlet_Swing1", Peak = 0.1, Length = 0.3 },
		{ Name = "Combat_Gauntlet_Swing2", Peak = 0.08, Length = 0.28 },
		{ Name = "Combat_Gauntlet_Swing3", Peak = 0.1, Length = 0.28 },
	},
	GauntletUpper = { -- uppercut finisher whoosh
		{ Name = "Combat_Gauntlet_Upper1", Peak = 0.18, Length = 0.37 },
		{ Name = "Combat_Gauntlet_Upper2", Peak = 0.1, Length = 0.25 },
	},
	GauntletHit = {
		{ Name = "Combat_Gauntlet_Hit1", Peak = 0.08, Length = 0.3 },
		{ Name = "Combat_Gauntlet_Hit2", Peak = 0.06, Length = 0.35 },
		{ Name = "Combat_Gauntlet_Hit3", Peak = 0.04, Length = 0.35 },
	},
	GauntletHitHeavy = { -- layered under the uppercut's impact
		{ Name = "Combat_Gauntlet_HitHeavy1", Peak = 0.02, Length = 0.42 },
		{ Name = "Combat_Gauntlet_HitHeavy2", Peak = 0.06, Length = 0.38 },
	},
	GauntletCrit = { -- a sharp crack
		{ Name = "Combat_Gauntlet_Crit", Peak = 0.11, Length = 0.57 },
	},
	-- Ranged
	BowRelease = {
		{ Name = "Combat_Ranged_BowRelease1", Peak = 0.01, Length = 0.3 },
		{ Name = "Combat_Ranged_BowRelease2", Peak = 0.01, Length = 0.25 },
	},
	BowWhoosh = { -- the arrow leaving (also the whiz of other players' shots)
		{ Name = "Combat_Ranged_BowWhoosh1", Peak = 0.28, Length = 0.4, Start = 0.22 },
		{ Name = "Combat_Ranged_BowWhoosh2", Peak = 0.3, Length = 0.48, Start = 0.2 },
	},
	BowDraw = { -- string creak (the bow drawn again after the shot; equip)
		{ Name = "Combat_Ranged_BowDraw", Peak = 0.19, Length = 0.55 },
	},
	CrossbowRelease = {
		{ Name = "Combat_Ranged_CrossbowRelease1", Peak = 0.01, Length = 0.22 },
		{ Name = "Combat_Ranged_CrossbowRelease2", Peak = 0.01, Length = 0.2 },
	},
	CrossbowKick = {
		{ Name = "Combat_Ranged_CrossbowKick", Peak = 0.08, Length = 0.27, Start = 0.06 },
	},
	CrossbowReload = {
		{ Name = "Combat_Ranged_CrossbowReload", Peak = 0.14, Length = 0.3, Start = 0.12 },
	},
	GunShot = { -- air bolt guns (abyss, mechanical)
		{ Name = "Combat_Ranged_GunShot1", Peak = 0.01, Length = 0.58 },
		{ Name = "Combat_Ranged_GunShot2", Peak = 0.01, Length = 0.5 },
		{ Name = "Combat_Ranged_GunShot3", Peak = 0.06, Length = 0.54 },
	},
	Blowgun = { -- breathy puff (jungle)
		{ Name = "Combat_Ranged_Blowgun1", Peak = 0.08, Length = 0.45 },
		{ Name = "Combat_Ranged_Blowgun2", Peak = 0.04, Length = 0.3 },
	},
	RangedHit = { -- arrival thunk
		{ Name = "Combat_Ranged_Hit1", Peak = 0.6, Length = 0.82, Start = 0.58 },
		{ Name = "Combat_Ranged_Hit2", Peak = 0.62, Length = 0.81, Start = 0.6 },
		{ Name = "Combat_Ranged_Hit3", Peak = 0.64, Length = 1.08, Start = 0.62 },
	},
	EnemyLaunch = { -- enemy projectile launch (Shot Enemy)
		{ Name = "Combat_Enemy_Launch1", Peak = 0.1, Length = 0.48 },
		{ Name = "Combat_Enemy_Launch2", Peak = 0.08, Length = 0.57 },
	},
	-- Magic
	MagicCharge = { -- rising charge, peaks at the release
		{ Name = "Combat_Magic_Charge1", Peak = 0.22, Length = 0.57 },
		{ Name = "Combat_Magic_Charge2", Peak = 0.65, Length = 0.93, Start = 0.3 },
	},
	MagicCast = { -- the release at the caster
		{ Name = "Combat_Magic_Cast1", Peak = 0.04, Length = 0.38 },
		{ Name = "Combat_Magic_Cast2", Peak = 0.04, Length = 0.44 },
	},
	MagicHit = { -- each enemy in the area
		{ Name = "Combat_Magic_Hit1", Peak = 0.02, Length = 0.55 },
		{ Name = "Combat_Magic_Hit2", Peak = 0.02, Length = 0.53 },
		{ Name = "Combat_Magic_Hit3", Peak = 0.04, Length = 0.68 },
	},
	MagicBurstArcane = {
		{ Name = "Combat_Magic_BurstArcane1", Peak = 0.13, Length = 0.93 },
		{ Name = "Combat_Magic_BurstArcane2", Peak = 0.13, Length = 0.78 },
	},
	MagicBurstFire = {
		{ Name = "Combat_Magic_BurstFire1", Peak = 0.11, Length = 0.6 },
		{ Name = "Combat_Magic_BurstFire2", Peak = 0.11, Length = 0.65 },
	},
	MagicBurstFrost = {
		{ Name = "Combat_Magic_BurstFrost1", Peak = 0.38, Length = 0.6, Start = 0.29 },
		{ Name = "Combat_Magic_BurstFrost2", Peak = 0.38, Length = 0.98, Start = 0.33 },
	},
	MagicBurstShock = {
		{ Name = "Combat_Magic_BurstShock1", Peak = 0.23, Length = 0.48, Start = 0.1 },
		{ Name = "Combat_Magic_BurstShock2", Peak = 0.42, Length = 0.67, Start = 0.12 },
	},
	MagicBurstWater = {
		{ Name = "Combat_Magic_BurstWater1", Peak = 0.27, Length = 2, Start = 0.15 },
		{ Name = "Combat_Magic_BurstWater2", Peak = 0.13, Length = 1.8 },
	},
	MagicHolyChime = { -- holy burst layer, magic crit sting
		{ Name = "Combat_Magic_HolyChime", Peak = 0.31, Length = 1.5 },
	},
	-- Shared
	Roll = {
		{ Name = "Combat_Shared_Roll1", Peak = 0.12, Length = 0.35 },
		{ Name = "Combat_Shared_Roll2", Peak = 0.2, Length = 0.45 },
	},
	BlockRaise = { -- the shield bubble forms
		{ Name = "Combat_Shared_BlockRaise", Peak = 0.15, Length = 0.65 },
	},
	BlockClink = {
		{ Name = "Combat_Shared_BlockClink", Peak = 0, Length = 0.2 },
	},
	BlockHit = {
		{ Name = "Combat_Shared_BlockHit1", Peak = 0.04, Length = 0.55 },
		{ Name = "Combat_Shared_BlockHit2", Peak = 0.04, Length = 0.75 },
		{ Name = "Combat_Shared_BlockHit3", Peak = 0.04, Length = 0.4 },
	},
	BlockBreak = {
		{ Name = "Combat_Shared_BlockBreak", Peak = 0.14, Length = 0.6, Start = 0.07 },
	},
	BlockShatter = {
		{ Name = "Combat_Shared_BlockShatter", Peak = 0.09, Length = 0.9 },
	},
	Hurt = {
		{ Name = "Combat_Shared_Hurt1", Peak = 0.04, Length = 0.5 },
		{ Name = "Combat_Shared_Hurt2", Peak = 0.08, Length = 0.35, Start = 0.05 },
		{ Name = "Combat_Shared_Hurt3", Peak = 0.08, Length = 0.45, Start = 0.05 },
	},
	Death = {
		{ Name = "Combat_Shared_Death", Peak = 0, Length = 2.2 },
	},
	-- the game's rarity sounds (Assets.Sounds.SFX, UI group), reused on Equip (EquipChime)
	RarityChime = {
		{ Name = "RarityReveal", Peak = 0.22, Length = 2.5 },
	},
	RarityChimeLegendary = {
		{ Name = "RarityLegendary", Peak = 0.3, Length = 5.2 },
	},
} :: { [string]: { { Name: string, Peak: number, Length: number, Start: number? } } }

-- Per weapon category.
CombatSfx.Categories = {
	Sword = {
		Swing = {
			Steps = {
				{ Set = "SwordSwing" }, -- RightSlash
				{ Set = "SwordSwing", Pitch = 1.06 }, -- LeftSlash
				{ Set = "SwordRise", Pitch = 1.04 }, -- RisingSlash
			},
			-- SpinSlash: the heavy whoosh with a lower blade swish under it
			Finisher = { Set = "SwordSpin", Pitch = 0.96, Also = { { Set = "SwordSwing", Pitch = 0.88, Volume = 0.55 } } },
		},
		Impact = {
			Materials = {
				flesh = { Set = "SwordHitFlesh" },
				metal = { Set = "SwordHitMetal" },
				stone = { Set = "SwordHitStone" },
			},
			Crit = { Set = "SwordCrit" },
			Finisher = { Pitch = 0.92, Volume = 1.15, Also = { { Set = "SwordHitHeavy" } } },
		},
		Equip = { Set = "SwordDraw" },
	},
	Spear = {
		Swing = {
			Steps = {
				{ Set = "SpearThrust" }, -- Thrust
				{ Set = "SpearThrust", Pitch = 1.06 }, -- Thrust2
			},
			-- PiercingLunge: the long hissing pierce over a lower thrust
			Finisher = { Set = "SpearPierce", Also = { { Set = "SpearThrust", Pitch = 0.9, Volume = 0.6 } } },
		},
		Impact = {
			Materials = { -- metal / stone: Shared
				flesh = { Set = "SpearStab", Also = { { Set = "SwordHitFlesh", Pitch = 1.05, Volume = 0.55 } } },
			},
			Crit = { Set = "SwordCrit", Pitch = 1.1 },
			Finisher = { Pitch = 0.94, Volume = 1.12, Also = { { Set = "SwordHitHeavy", Volume = 0.8 } } },
		},
		Equip = { Set = "SwordDraw", Pitch = 0.85, Volume = 0.7 },
	},
	Heavy = {
		Swing = {
			Steps = { { Set = "HeavySwing" } }, -- OverheadSlam (its ground slam: Burst "Slam")
			-- WideSmash: the rumbling smash over a lower slow whoosh
			Finisher = { Set = "HeavySmash", Also = { { Set = "HeavySwing", Pitch = 0.9, Volume = 0.6 } } },
		},
		Impact = {
			Materials = {
				flesh = { Set = "HeavyHitFlesh" },
				metal = { Set = "SwordHitMetal", Pitch = 0.78, Volume = 1.2 },
				stone = { Set = "SwordHitStone", Pitch = 0.85, Volume = 1.1 },
			},
			Crit = { Set = "SwordCrit", Pitch = 0.75 },
			Finisher = { Pitch = 0.92, Volume = 1.1, Also = { { Set = "HeavySlamBoom", Volume = 0.5 } } },
		},
		Equip = { Set = "HeavyEquip" },
	},
	Dagger = {
		Swing = {
			Steps = {
				{ Set = "DaggerSlash" }, -- SlashR
				{ Set = "DaggerSlash", Pitch = 1.06 }, -- SlashL
				{ Set = "DaggerSlash", Pitch = 0.96 }, -- StabR
				{ Set = "DaggerSlash", Pitch = 1.1 }, -- StabL
			},
			-- DoubleSlash: one slash on each hit (Combos Dagger[5] Hits = { 0.2 })
			Finisher = { Set = "DaggerSlash", Pitch = 0.94, Volume = 1.1,
				Also = { { Set = "DaggerSlash", Hit = 0.2, Pitch = 1.04, Volume = 1.1 } } },
		},
		Impact = {
			Materials = { -- stone: Shared
				flesh = { Set = "DaggerHitFlesh", Pitch = 1.08 },
				metal = { Set = "SwordHitMetal", Pitch = 1.25, Volume = 0.7 },
			},
			Crit = { Set = "DaggerCrit" },
		},
		Equip = { Set = "DaggerDraw" },
	},
	Gauntlet = {
		Swing = {
			Steps = {
				{ Set = "GauntletSwing" }, -- Jab
				{ Set = "GauntletSwing", Pitch = 0.95 }, -- Cross
			},
			Finisher = { Set = "GauntletUpper" }, -- Uppercut
		},
		Impact = {
			Materials = { -- stone: Shared
				flesh = { Set = "GauntletHit" },
				metal = { Set = "SwordHitMetal", Pitch = 0.9, Volume = 0.8 },
			},
			Crit = { Set = "GauntletCrit" },
			-- the uppercut (x2 damage): lower, louder, with a heavier punch under it
			Finisher = { Pitch = 0.93, Volume = 1.1, Also = { { Set = "GauntletHitHeavy" } } },
		},
		Equip = { Set = "BlockClink", Pitch = 0.85 },
	},
	Ranged = {
		Swing = {
			-- bows: the string release at the shot (Hit 0.05 s), the arrow leaving, the bow drawn again from 0.14 s
			Steps = {
				{ Set = "BowRelease", Pitch = 0.85, Lead = 0, Also = {
					{ Set = "BowWhoosh", Lead = -0.04, Volume = 0.8 },
					{ Set = "BowDraw", At = 0.14, Volume = 0.8 },
				} },
			},
			Styles = {
				Crossbow = { Steps = { { Set = "CrossbowRelease", Lead = 0, Also = {
					{ Set = "CrossbowKick", Lead = 0 },
					{ Set = "CrossbowReload", At = 0.3 },
				} } } },
				Gun = { Steps = { { Set = "GunShot", Lead = 0 } } },
				Blowgun = { Steps = { { Set = "Blowgun", Lead = 0, Also = {
					{ Set = "BowWhoosh", Lead = -0.04, Pitch = 1.2, Volume = 0.5 },
				} } } },
			},
		},
		Impact = {
			Materials = { -- metal / stone: Shared
				flesh = { Set = "RangedHit" },
			},
			Crit = { Set = "DaggerCrit", Pitch = 0.9 },
		},
		Equip = { Set = "BowDraw", Volume = 1.2 },
	},
	Magic = {
		Swing = {
			-- the charge rises from the call and peaks at the release (Impact 0.30 s), the cast bursts out there; the
			-- explosion at the target is the Burst
			Steps = {
				{ Set = "MagicCharge", Lead = 0, Also = { { Set = "MagicCast", Lead = -0.02 } } },
			},
		},
		Impact = {
			Materials = {
				flesh = { Set = "MagicHit" },
				metal = { Set = "MagicHit", Pitch = 1.1 },
				stone = { Set = "MagicHit", Pitch = 0.9 },
			},
			Crit = { Set = "MagicHolyChime", Pitch = 1.3, Volume = 1.2 },
		},
		Equip = { Set = "MagicHit", Volume = 0.6 },
	},
} :: { [string]: { [string]: any } }

-- Events that do not depend on the weapon (and the fallback of the category entries).
CombatSfx.Shared = {
	Roll = { Set = "Roll" },
	Block = { Set = "BlockRaise", Also = { { Set = "BlockClink", Volume = 0.7 } } },
	BlockHit = { Set = "BlockHit" },
	BlockBreak = { Set = "BlockBreak", Also = { { Set = "BlockShatter", Volume = 0.8 } } },
	Hurt = { Set = "Hurt" },
	Death = { Set = "Death" },
	Equip = { Set = "SwordDraw", Volume = 0.8 },
	Impact = { -- materials a category does not have
		Materials = {
			flesh = { Set = "SwordHitFlesh" },
			metal = { Set = "SwordHitMetal" },
			stone = { Set = "SwordHitStone" },
		},
	},
	Shot = {
		Player = { Set = "BowWhoosh", Volume = 0.45 }, -- another player's projectile leaving (the shooter's own: none)
		Enemy = { Set = "EnemyLaunch" },
	},
	Burst = {
		-- magic areas: sent at the cast start, the explosion peaks at the release (Hit 0.30 s)
		Styles = {
			Slam = { Set = "HeavySlamBoom", Also = { { Set = "HeavySlamDebris", Volume = 0.7 } } },
			Enemy = { Set = "HeavySlamBoom", Pitch = 1.1, Volume = 0.8, Also = { { Set = "HeavySlamDebris", Volume = 0.5 } } },
			Arcane = { Set = "MagicBurstArcane", Hit = 0.3, Lead = 0 },
			Nature = { Set = "MagicBurstArcane", Pitch = 1.05, Hit = 0.3, Lead = 0 },
			Fire = { Set = "MagicBurstFire", Hit = 0.3, Lead = 0 },
			Frost = { Set = "MagicBurstFrost", Hit = 0.3, Lead = 0 },
			Shock = { Set = "MagicBurstShock", Hit = 0.3, Lead = 0 },
			Water = { Set = "MagicBurstWater", Hit = 0.3, Lead = 0 },
			Dark = { Set = "MagicBurstArcane", Pitch = 0.72, Hit = 0.3, Lead = 0,
				Also = { { Set = "HeavySlamBoom", Pitch = 0.8, Volume = 0.6 } } },
			Holy = { Set = "MagicBurstArcane", Pitch = 1.15, Hit = 0.3, Lead = 0, Also = { { Set = "MagicHolyChime" } } },
			Earth = { Set = "MagicBurstArcane", Pitch = 0.85, Hit = 0.3, Lead = 0,
				Also = { { Set = "HeavySlamDebris", Volume = 0.5 } } },
			Poison = { Set = "MagicBurstArcane", Pitch = 0.9, Hit = 0.3, Lead = 0,
				Also = { { Set = "MagicBurstWater", Pitch = 1.3, Volume = 0.5 } } },
		},
		Default = "Arcane",
	},
} :: { [string]: { [string]: any } }

return CombatSfx
