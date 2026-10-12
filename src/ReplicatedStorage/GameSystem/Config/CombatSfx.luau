--!strict
-- Combat sounds (docs/weapons_combat_brief.txt 4D, contract in docs/COMBAT_CONTRACTS.md section 5).
-- OWNER: the SFX sub-agent. Read by Util/Sfx (Sfx.combat). The Sound instances live in
-- ReplicatedStorage.Assets.Sounds.Combat (their Volume = the loudness-matched base level, InverseTapered roll-off
-- 10-150 studs, attributes SourceAssetId / SourceName / SourceCreator: all from the Pro Sound Effects catalog).
--
-- How a call resolves:  Sfx.combat(event, ctx)
--   1. the category entry Categories[ctx.Category] (DefaultCategory when the category has none yet), else Shared
--   2. Swing  -> Swing.Finisher when ctx.Finisher, else Swing.Steps[ctx.Step] (wraps around)
--      Impact -> Impact.Materials[ctx.Material or DefaultMaterial], times Impact.Finisher on a finisher, plus
--                Impact.Crit layered on a crit
--      others -> the spec itself
--   3. a spec = { Set, Volume?, Pitch?, Also? }: one variant of the Set (never the same twice in a row), random pitch
--      +-PitchRange, Volume / Pitch multiply the Sound's own; Also = more specs played together (layers).
-- Swing sounds are delayed so their Peak lands HitLead seconds before the step's hit
-- (Config/Combat Combos[category][step].Impact / speed); every other event plays at once.
-- ctx.Position (and not ctx.IsLocal) -> a 3D sound there at RemoteVolume; otherwise the local player's own sound
-- (2D, full volume).
local CombatSfx = {}

CombatSfx.Cap = 12 -- combat sounds playing at once; a new one stops the oldest
CombatSfx.PitchRange = 0.05 -- random pitch +-5 %
CombatSfx.RemoteVolume = 0.8 -- other players' sounds (3D at ctx.Position)
CombatSfx.Range = 150 -- studs from the camera: farther 3D sounds are skipped (= the Sounds' RollOffMaxDistance)
CombatSfx.StackWindow = 0.05 -- one swing hitting many enemies: at most StackMax sounds of the same Set
CombatSfx.StackMax = 2 -- within StackWindow seconds
-- sets heard once per window (two enemies biting on the same tick, one swing critting two enemies)
CombatSfx.StackMaxOf = { Hurt = 1, BlockHit = 1, SwordCrit = 1, Death = 1 } :: { [string]: number }
CombatSfx.HitLead = 0.02 -- a whoosh peaks this long before the hit lands
CombatSfx.PoolMax = 4 -- idle copies kept per sound (pooled, no Clone once warm)
CombatSfx.Prewarm = 2 -- copies made per sound when the client starts (after ContentProvider:PreloadAsync)
CombatSfx.DefaultMaterial = "flesh" -- enemies are creatures today; "metal" and "stone" sets are ready
CombatSfx.DefaultCategory = "Sword" -- categories without their own entry use this one (until round 2)

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
} :: { [string]: { { Name: string, Peak: number, Length: number, Start: number? } } }

-- Per weapon category (round 2 adds Spear, Heavy, Dagger, Gauntlet, Ranged, Magic).
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
} :: { [string]: { [string]: any } }

return CombatSfx
