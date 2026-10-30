# SOUND KIT - Fight Your Destiny

Built 2026-10-04 by the SFX agent. Location: `ReplicatedStorage.Assets.Sounds` with three folders
`SFX` (29), `Music` (15), `Ambience` (18). 62 Sound instances, no scripts.

* Every Sound has the attributes `SourceAssetId` (number), `SourceCreator` (string), `SourceName` (string).
* Volumes: SFX 0.5-0.8, UI sounds 0.4, music 0.35, ambience 0.3. Music and ambience have `Looped = true`.
* SFX use `RollOffMode = InverseTapered` (min 10, max 150) so they can be cloned onto a part as 3D sounds.
* Names are the contract with the code (`DESIGN.md` section 10 and `AudioController.luau`):
  music `Music_<ZoneId>` -> `MusicZone` (`MusicHub` in the hub), ambience `Ambience_<SubZoneId>` -> `Ambience_<ZoneId>`.
* "Loaded" = `ContentProvider:PreloadAsync` succeeded in Studio (Edit) with `IsLoaded = true` and `TimeLength > 0`.
* **Nothing was auditioned by ear.** Sounds were chosen from their catalog title and description only.
  The owner should listen to each one once in Studio and swap any that do not fit (alternates are listed in the notes).

## Sources

| Creator account | Count | What it is |
|---|---|---|
| ProSoundEffects | 33 | Roblox's licensed sound-effect catalog ("Courtesy of Pro Sound Effects"), usable in every experience |
| APMOfficial | 15 | Roblox's licensed APM Music catalog, usable in every experience |
| Roblox | 7 | Sounds uploaded by Roblox itself (UI kit) |
| DistrokidOfficial | 2 | Roblox's licensed DistroKid catalog (Ambience_Desert, Ambience_Tundra) |
| Texodus | 1 | Public user upload (Ambience_Plains_4), free-to-use per its description |

Note: no asset in the catalog search is literally owned by the account "Roblox" except the UI kit; the
licensed catalogs are published by the official partner accounts above.

## SFX

| Name | Asset id | Source name | Creator | Length (s) | Loaded | Note |
|---|---|---|---|---|---|---|
| SwordSwing | 9119749145 | Sword Swish 102 (SFX) | ProSoundEffects | 0.96 | yes | alt 9119749263, 9119749931 |
| Hit | 9119747120 | Sword Impact 102 (SFX) | ProSoundEffects | 0.68 | yes | alt 9119747138, 9113487470 (Body Hit 2) |
| Crit | 9119747163 | Sword Impact 302 (SFX) | ProSoundEffects | 1.42 | yes | heavier impact than Hit; alt 9119061517 (Sharp Punch 6) |
| Block | 9119075617 | Shield Impacts 17 (SFX) | ProSoundEffects | 0.75 | yes | alt 9119075972, 9119072890 |
| Roll | 9120711313 | Whoosh Fast Swish By 6 (SFX) | ProSoundEffects | 1.18 | yes | alt 9125443457 (cloth whoosh) |
| Hurt | 9116451739 | Male Grunts Two Men Fighting With Spear 3 (SFX) | ProSoundEffects | 0.69 | yes | short grunt, no gore; alt 9116451917, 9113526423 (Body Impact 9) |
| Death | 9113475180 | Body Fall Master 12 (SFX) | ProSoundEffects | 3.02 | yes | body fall, no scream; alt 9114029889 (gasp) |
| EnemyDeath | 9117841338 | Pop Airy 1 (SFX) | ProSoundEffects | 0.79 | yes | cartoony "poof"; alt 9117840021, 9117839765 |
| BossRoar | 9113980319 | Creature Mix Giant Crab Monster Roar Growl 1 (SFX) | ProSoundEffects | 3.12 | yes | alt 9116292530 (lion beast roar), 9113985721 |
| TelegraphWarn | 9117060349 | Nasa Transmission Beep 2 (SFX) | ProSoundEffects | 0.85 | yes | closest match: a clean beep, not very "fantasy"; alt 9113085764 (Alarm Buzzer 5) |
| GoldPickup | 17208319162 | Roblox GUI - Pickup | Roblox | 0.90 | yes | closest match: generic pickup blip; coin alternates 127645268874265 (CoinTransfer_01, Roblox), 9113849731 (Coin Throws 2) |
| Purchase | 17208380755 | Roblox GUI - Purchase | Roblox | 0.87 | yes | alt 10066947742 (RBLX UI Purchase), 9113728625 (Cash Register 1) |
| Denied | 17208353912 | Roblox GUI - Negative | Roblox | 0.38 | yes | alt 17208214688 (Call Decline) |
| Unlock | 9116324156 | Lock Unlock Door 10 (SFX) | ProSoundEffects | 1.91 | yes | alt 9116324157, 9117185722 (padlock) |
| EggCrack | 9113959071 | Crack Egg Crunchy 6 (SFX) | ProSoundEffects | 1.29 | yes | alt 9113959343, 9113959559 |
| EggCrackSmall1 | 9113958805 | Crack Egg Crunchy 5 (SFX) | ProSoundEffects | 0.23 (trim) | yes | hatch crack burst; PlaybackRegion 1.755-1.980 of the 3.37 s file: one dry crack (~50 ms) + faint tail, volume 0.6; alt same file 0.990-1.240, 9113958660 (Crunchy 1) 0.060-0.360 |
| EggCrackSmall2 | 9113958805 | Crack Egg Crunchy 5 (SFX) | ProSoundEffects | 0.25 (trim) | yes | hatch crack burst; PlaybackRegion 2.355-2.600: one crack, slightly different attack, volume 0.6; alt 9113959071 (Crunchy 6 = EggCrack) 0.150-0.420 |
| EggCrackSmall3 | 9113958805 | Crack Egg Crunchy 5 (SFX) | ProSoundEffects | 0.25 (trim) | yes | hatch crack burst; PlaybackRegion 2.055-2.300: double crack (~70 ms), the fullest of the three, volume 0.6; alt 9113958660 (Crunchy 1) 0.060-0.360 |
| EggShellBreak | 9113959542 | Crack Egg Crunchy 13 (SFX) | ProSoundEffects | 1.15 (trim) | yes | shell breaks open; PlaybackRegion 0.155-1.300 of the 1.71 s file: dense crunch ~0.25 s, small bits at +0.35 s, one piece at +1.0 s, volume 0.7; alt 9113959343 (Crunchy 11, crunch + bits) 0.150-1.000, 9113958649 (Crunchy 2) 0.180-0.700 |
| PetHatch | 15675055424 | Roblox_UI_Cute_Pop | Roblox | 2.70 | yes | closest match; alt 9116422765 (Magic Transformation 23), 9120222027 (Toy Squeak 1) |
| RarityReveal | 9116395089 | Magic Glows Soft Clusters Of Chiming Hits 4 (SFX) | ProSoundEffects | 2.46 | yes | alt 9116394876, 9126073318 (synth sparkle bell) |
| RarityLegendary | 9116426026 | Magic Transformation 7 (SFX) | ProSoundEffects | 5.11 | yes | longest/biggest magic cue; alt 9114631461 (Gong Whoosh 3), 9116395085 |
| LevelUp | 9117887138 | Power Up Sweeteners 3 (SFX) | ProSoundEffects | 2.28 | yes | closest match: no musical fanfare found in the licensed SFX catalog; alt 9117885418, 15675043410 (Roblox_UI_Tonal_Stinger) |
| RebirthWhoosh | 9125645617 | Magic Whooshes Growly Magic Whooshes Airy Gu (SFX) | ProSoundEffects | 3.71 | yes | alt 9125646917, 9116411685 |
| UIClick | 15675032796 | Roblox_UI_Small_Click | Roblox | 0.13 | yes | alt 15675059323 (Bright Click), 17208396156 (Select) |
| UIOpen | 15675024286 | Roblox_UI_Whoosh_01 | Roblox | 0.85 | yes | alt 17208408337 (Tab), 15675046931 (Sweep) |
| UIClose | 17208186900 | Roblox GUI - Back | Roblox | 0.53 | yes | alt 10066914500 (RBLX UI Back), 15675012262 (Whoosh_04) |
| PortalEnter | 9116411685 | Magic Swoosh Fast Zooming Pass Bys 18 (SFX) | ProSoundEffects | 2.40 | yes | alt 9125648149 (Magic Zoom Up), 9116422213 |
| GateOpen | 9125880713 | Rock Scrape Deep Clunky Slides Rumbling Thun (SFX) | ProSoundEffects | 2.06 | yes | stone door slide; alt 9113807062, 9120878291 (wood gate hinge) |

Hatch sounds (2026-10-18): the egg-crack files start with ~0.15-0.2 s of silence and some hold several cracks,
so the four hatch sounds play only a slice of their file (`PlaybackRegionsEnabled = true`, `PlaybackRegion` above;
a clone keeps it). Each slice starts ~25 ms before the crack so the sound lands on the visual burst. The slices were
picked from a measured envelope, not by ear: an `AudioPlayer` wired to an `AudioAnalyzer` (no output, silent) in Edit
gives `PeakLevel` per ~11 ms block at half speed and the spectrum centroid (all four ~8-10 kHz, i.e. bright, not muddy).
Alternate slices in the notes are suggestions from the same envelopes (not set up).

## Music

All from the APM Music licensed catalog, all 60 s or longer, `Looped = true`, volume 0.35.
Only "War Drums Of The North" is authored as a seamless loop; the others restart from the top.

| Name | Asset id | Source name | Creator | Length (s) | Loaded | Note |
|---|---|---|---|---|---|---|
| MusicHub | 9048663710 | Court Minstrel | APMOfficial | 116.5 | yes | medieval/minstrel; alt 1846301991 (Minstrel Medley), 1837153015 (Wandering Minstrels 2) |
| MusicZone | 1838685288 | Heroic Adventure | APMOfficial | 145.1 | yes | generic fallback; alt 1838990319 (Crystal Forest), 1838990063 (Fort Bravo) |
| MusicBoss | 9045953483 | Last Man Standing | APMOfficial | 136.8 | yes | alt 9043171470 (Edge Of Extinction), 1846428560 (Forces Of Nature B) |
| Music_Plains | 1836770452 | Green And Pleasant Land | APMOfficial | 92.4 | yes | pastoral orchestral; alt 9046390239 (Morning Skies), 9046393108 (Southern Winds) |
| Music_Desert | 1837405071 | Sahara Ney | APMOfficial | 106.1 | yes | ney = Middle-Eastern flute; alt 1838901247 (Sahara Dunes Percussions), 1847657288 (Bedouin Caravan A) |
| Music_Jungle | 1845518435 | Mystic Africa (drums) | APMOfficial | 200.7 | yes | drums; alt 9047904250 (Invocation Of The Spirits, perc), 1846358442 (African Drums A) |
| Music_Tundra | 1839780600 | Arctic Panorama | APMOfficial | 191.9 | yes | alt 1840777443 (Absolute Zero), 1842144942 (Cracking Glaciers a) |
| Music_Swamp | 1837172508 | The Fear Within | APMOfficial | 97.9 | yes | eerie drone; alt 1842083922 (Cinematic Texture Toolkit x), 9044512469 (Cypress Bayou) |
| Music_Volcano | 1843011412 | War Drums Of The North (Loop) | APMOfficial | 110.8 | yes | deep drums; alt 1838617399 (Drums Of War), 1846266639 (Drama Drum) |
| Music_Hell | 1838311778 | Hell's Gate | APMOfficial | 130.8 | yes | alt 1843640242 (Devil's Chant), 1846325213 (Calling The Demons C) |
| Music_Heaven | 1840524246 | Angelic Choir | APMOfficial | 124.7 | yes | alt 1848113516 (Choral Hymn To Life), 1840529649 (Alpha To Omega C) |
| Music_Dead | 1841982236 | Funeral Organ | APMOfficial | 68.3 | yes | slow organ; alt 1846172496 (Cathedral Largo, 176 s), 9038875024 (Organ Fantasia, 316 s) |
| Music_Abyss | 9043113681 | The Deep | APMOfficial | 177.6 | yes | alt 9043111706 (Underwater World), 1836052707 (Submarine Space) |
| Music_Mechanical | 1848199960 | Army Of Machines C | APMOfficial | 123.5 | yes | alt 1848137055 (Machines Uprising D), 1840896767 (Industrial Clockwork B) |
| Music_Void | 9038128309 | Into The Void Drone Mix No Bass | APMOfficial | 104.0 | yes | alt 1838049311 (Beyond the Cosmos c), 1840777443 (Absolute Zero) |

## Ambience

`Looped = true`, volume 0.3.

| Name | Asset id | Source name | Creator | Length (s) | Loaded | Note |
|---|---|---|---|---|---|---|
| Ambience_Hub | 9112751378 | British Surf Birds 1 (SFX) | ProSoundEffects | 36.0 | yes | waves on rocks + seabirds, authored loop; alt 9113592288 (56 s), 9112829678 (Marina Ambience 5) |
| Ambience_Plains | 9112831284 | Morning Birds 1 (SFX) | ProSoundEffects | 36.0 | yes | birds, authored loop (no distinct wind layer); alt 9116969466, 9112832297 (Mountain Birds 2) |
| Ambience_Plains_2 | 9112751340 | British Surf Birds 2 (SFX) | ProSoundEffects | 36.0 | yes | same family as the hub (different take); alt 9113592099, 9113592145 |
| Ambience_Plains_3 | 9112761688 | Coyote Forest 2 (SFX) | ProSoundEffects | 36.0 | yes | forest, foliage drips, constant birds, authored loop; alt 9112806209 (Jungle Dawn 2) |
| Ambience_Plains_4 | 273398061 | Cave Ambience | Texodus | 117.8 | yes | NOT from a licensed catalog (public user upload, "free to use"); licensed fallback 9112893362 (reverberant water drips) |
| Ambience_Desert | 81404060588532 | Howling Wind (Sound) | DistrokidOfficial | 147.2 | yes | check by ear that it is pure wind; fallback 9125742262 (airy wind whoosh, Pro Sound Effects) |
| Ambience_Desert_4 | 9116328633 | Low Drone Pulsing Tone Continuous 2 (SFX) | ProSoundEffects | 38.4 | yes | closest match: low drone only, no fire layer; alt 9114353535 (Evil Drone Eerie 1), 9125351901 (Afterworld Ambience) |
| Ambience_Jungle | 9112800640 | Jungle Ambience 1 (SFX) | ProSoundEffects | 36.0 | yes | birds + insects, authored loop; alt 9113048424, 9112800287 |
| Ambience_Jungle_2 | 9120550276 | Waterfall Cu 2 (SFX) | ProSoundEffects | 55.6 | yes | heavy constant waterfall; alt 9120550180, 9114492638 |
| Ambience_Tundra | 112385924701681 | Cold Wind Howling | DistrokidOfficial | 291.4 | yes | check by ear that it is pure wind (artist "Always Musics"); fallback 9120125188 (Tonal Wind Fluctuating Hollow 1) |
| Ambience_Swamp | 9125615469 | Kenyan Frogs Cu Deep Throaty Croaking Insect (SFX) | ProSoundEffects | 53.8 | yes | frogs + insects, no bubbling layer; alt 9112808120 (Jungle Frogs 2), 9113996155 (Creek Night) |
| Ambience_Volcano | 9112823563 | Lava Rumble 2 (SFX) | ProSoundEffects | 59.8 | yes | authored loop; alt 9112823552 (Lava Rumble 1) |
| Ambience_Hell | 9112887827 | Toxic Fire 2 (SFX) | ProSoundEffects | 50.8 | yes | fire + deep growls, authored loop, no screams; alt 9112823552 |
| Ambience_Heaven | 9120750367 | Wind Chimes 3 (SFX) | ProSoundEffects | 51.1 | yes | chimes; alt 9120749909 (Wind Chimes 2), 9113122478 (Angel Presence Cymbal Drone 3) |
| Ambience_Dead | 9120125188 | Tonal Wind Fluctuating Hollow 1 (SFX) | ProSoundEffects | 27.0 | yes | closest match: hollow wind only, no bells, short loop; bells alternates 9043368494 (APM "Church Bells", 37 s), 9113804573 (Church Bell Tolling 2) |
| Ambience_Abyss | 9112889917 | Underwater Ambience 1 (SFX) | ProSoundEffects | 59.4 | yes | alt 9113608232 (Bubbling Synth Swirling Drone 4) |
| Ambience_Mechanical | 9112839813 | Oil Refinery Ambience 1 (SFX) | ProSoundEffects | 31.5 | yes | machine hum + hiss, authored loop; alt 9112839913, 9118069484 (Reactor throbbing drone, 68 s) |
| Ambience_Void | 9126058563 | Synth Drone Continuous Multi- Tone Modulatin (SFX) | ProSoundEffects | 55.5 | yes | alt 9119423099 (Spaceship mellow drone), 9113948291 (Cosmic Longing) |

## Combat (2026-10-12, hack & slash, SFX sub-agent)

Folder `ReplicatedStorage.Assets.Sounds.Combat`, all from the licensed ProSoundEffects catalog (found with
`AssetService:SearchAudio`), group PlayerFX, RollOff InverseTapered 10-150 studs, attributes SourceAssetId / SourceName /
SourceCreator on each Sound. Played only through `Sfx.combat(event, ctx)` with the mapping in `Config/CombatSfx`
(variants, no repeat, pitch +-5 %, cap 12, whoosh peak timed to the hit). Volumes are loudness-matched by measurement:
**nothing was auditioned by ear - the owner should listen to each one once.** The old SFX `SwordSwing`, `Hit`, `Crit`,
`Block`, `Roll` are no longer used by combat (kept; Notifier still uses `Hurt`).

| Name | Asset id | Event | Volume |
|---|---|---|---|
| Combat_Sword_Swing1 | 9119698838 | Swing steps 1-2 | 0.90 |
| Combat_Sword_Swing2 | 9119698772 | Swing steps 1-2 | 1.00 |
| Combat_Sword_Swing3 | 9119691969 | Swing steps 1-2 | 0.86 |
| Combat_Sword_Rise1 | 9126013005 | Swing step 3 (RisingSlash) | 0.75 |
| Combat_Sword_Rise2 | 9119691895 | Swing step 3 | 0.90 |
| Combat_Sword_Rise3 | 9119698849 | Swing step 3 | 1.20 |
| Combat_Sword_Spin1 | 9126229805 | Swing finisher (SpinSlash) | 0.58 |
| Combat_Sword_Spin2 | 9126229716 | Swing finisher | 0.57 |
| Combat_Sword_HitFlesh1 | 9114482303 | Impact flesh | 1.08 |
| Combat_Sword_HitFlesh2 | 9114482566 | Impact flesh | 1.13 |
| Combat_Sword_HitFlesh3 | 9114482142 | Impact flesh | 1.24 |
| Combat_Sword_HitMetal1 | 9119746759 | Impact metal | 0.49 |
| Combat_Sword_HitMetal2 | 9119072660 | Impact metal | 0.34 |
| Combat_Sword_HitMetal3 | 9119072674 | Impact metal | 0.56 |
| Combat_Sword_HitStone1 | 9113225488 | Impact stone | 0.39 |
| Combat_Sword_HitStone2 | 9113225186 | Impact stone | 0.41 |
| Combat_Sword_HitStone3 | 9113225486 | Impact stone | 0.30 |
| Combat_Sword_HitHeavy | 9113514932 | Impact finisher layer | 0.83 |
| Combat_Sword_Crit1 | 9116197252 | Impact crit sting | 0.47 |
| Combat_Sword_Crit2 | 9116197044 | Impact crit sting | 0.84 |
| Combat_Sword_Draw1 | 9119742750 | Equip | 0.75 |
| Combat_Sword_Draw2 | 9119743888 | Equip | 0.80 |
| Combat_Shared_Roll1 | 9120742710 | Roll | 0.94 |
| Combat_Shared_Roll2 | 9120742903 | Roll | 0.65 |
| Combat_Shared_BlockRaise | 9117886252 | Block (bubble forms) | 0.70 |
| Combat_Shared_BlockClink | 9119072890 | Block layer | 0.42 |
| Combat_Shared_BlockHit1 | 9119075617 | BlockHit (= old Block) | 0.76 |
| Combat_Shared_BlockHit2 | 9119075637 | BlockHit | 1.38 |
| Combat_Shared_BlockHit3 | 9119075623 | BlockHit | 1.47 |
| Combat_Shared_BlockBreak | 9119074309 | BlockBreak | 0.67 |
| Combat_Shared_BlockShatter | 9114590645 | BlockBreak layer | 0.45 |
| Combat_Shared_Hurt1 | 9113485306 | Hurt (body thud, no voice) | 0.96 |
| Combat_Shared_Hurt2 | 9113527137 | Hurt | 0.45 |
| Combat_Shared_Hurt3 | 9113527320 | Hurt | 0.51 |
| Combat_Shared_Death | 9113475180 | Death (= old Death) | 0.70 |

### Round 2 (Spear, Heavy, Dagger, Ranged, Magic): 80 more sounds, 115 in total

Same source, settings and rule (nothing auditioned by ear; candidates to swap first: the bow release = Crossbow Fire
at pitch 0.85, the gun = Air Bolt Gun). Ranged sounds follow the Tool's WeaponId (bow / crossbow tundra hell dead /
blowgun jungle / gun abyss mechanical); Burst by Style (element groups); a quiet RarityReveal (rarity 5-6) or
RarityLegendary (7-8) layered on Equip; enemy launches in the EnemyFX group. Reused with a pitch change (no new
asset): Spear crit / finisher / equip, Heavy metal / stone / crit, Dagger metal, Ranged crit.

| Name | Asset id | Event | Volume |
|---|---|---|---|
| Combat_Spear_Thrust1 | 9113319325 | Spear swing steps 1-2 | 0.78 |
| Combat_Spear_Thrust2 | 9125495641 | Spear swing steps 1-2 | 0.82 |
| Combat_Spear_Thrust3 | 9120972321 | Spear swing steps 1-2 | 1.5 |
| Combat_Spear_Pierce1 | 9125920178 | Spear PiercingLunge finisher | 1.33 |
| Combat_Spear_Pierce2 | 9120995177 | Spear PiercingLunge finisher | 1.09 |
| Combat_Spear_Stab1 | 9119748927 | Spear impact flesh | 1.63 |
| Combat_Spear_Stab2 | 9114487004 | Spear impact flesh | 1.73 |
| Combat_Spear_Stab3 | 9114487427 | Spear impact flesh | 2.6 |
| Combat_Heavy_Swing1 | 9119227880 | Heavy OverheadSlam swing | 2.86 |
| Combat_Heavy_Swing2 | 9119227910 | Heavy OverheadSlam swing | 3.33 |
| Combat_Heavy_Swing3 | 9113305631 | Heavy OverheadSlam swing | 0.57 |
| Combat_Heavy_Smash1 | 9120706815 | Heavy WideSmash finisher | 0.96 |
| Combat_Heavy_Smash2 | 9120707899 | Heavy WideSmash finisher | 0.96 |
| Combat_Heavy_SlamBoom1 | 9113551779 | Burst Slam / Enemy / Dark, finisher impact layer | 1.25 |
| Combat_Heavy_SlamBoom2 | 9126009638 | Burst Slam / Enemy / Dark, finisher impact layer | 0.63 |
| Combat_Heavy_SlamDebris1 | 9118613697 | slam layer, Earth burst | 0.36 |
| Combat_Heavy_SlamDebris2 | 9118613863 | slam layer, Earth burst | 0.38 |
| Combat_Heavy_HitFlesh1 | 9116488438 | Heavy impact flesh | 2.14 |
| Combat_Heavy_HitFlesh2 | 9116488784 | Heavy impact flesh | 2.0 |
| Combat_Heavy_HitFlesh3 | 9113523399 | Heavy impact flesh | 0.6 |
| Combat_Heavy_Equip | 9113157053 | Heavy equip | 0.24 |
| Combat_Dagger_Slash1 | 9114164739 | Dagger swing (5 steps + double slash) | 0.93 |
| Combat_Dagger_Slash2 | 9114163805 | Dagger swing | 1.27 |
| Combat_Dagger_Slash3 | 9119740811 | Dagger swing | 1.27 |
| Combat_Dagger_Slash4 | 9119742184 | Dagger swing | 1.08 |
| Combat_Dagger_HitFlesh1 | 9114482141 | Dagger impact flesh | 0.88 |
| Combat_Dagger_HitFlesh2 | 9114482569 | Dagger impact flesh | 1.05 |
| Combat_Dagger_HitFlesh3 | 9114482300 | Dagger impact flesh | 1.0 |
| Combat_Dagger_Crit1 | 9116197039 | Dagger crit sting | 0.82 |
| Combat_Dagger_Crit2 | 9116196826 | Dagger crit sting | 0.82 |
| Combat_Dagger_Draw1 | 9116190959 | Dagger equip | 1.43 |
| Combat_Dagger_Draw2 | 9116191739 | Dagger equip | 2.5 |
| Combat_Ranged_BowRelease1 | 9114001456 | bow swing | 1.33 |
| Combat_Ranged_BowRelease2 | 9114000974 | bow swing | 1.18 |
| Combat_Ranged_BowWhoosh1 | 9113167619 | bow swing layer, Shot whiz, blowgun layer | 0.63 |
| Combat_Ranged_BowWhoosh2 | 9113167193 | bow swing layer, Shot whiz, blowgun layer | 3.0 |
| Combat_Ranged_BowDraw | 9125405903 | bow redraw at 0.14 s, Ranged equip | 2.0 |
| Combat_Ranged_CrossbowRelease1 | 9114001369 | crossbow swing | 1.25 |
| Combat_Ranged_CrossbowRelease2 | 9114000843 | crossbow swing | 1.25 |
| Combat_Ranged_CrossbowKick | 9114003826 | crossbow swing layer | 0.75 |
| Combat_Ranged_CrossbowReload | 9114004190 | crossbow reload at 0.3 s | 0.43 |
| Combat_Ranged_GunShot1 | 9113051048 | gun swing (air bolt gun) | 0.76 |
| Combat_Ranged_GunShot2 | 9113050696 | gun swing | 0.96 |
| Combat_Ranged_GunShot3 | 9113052411 | gun swing | 0.7 |
| Combat_Ranged_Blowgun1 | 9116405618 | blowgun swing | 0.86 |
| Combat_Ranged_Blowgun2 | 9125640992 | blowgun swing | 1.5 |
| Combat_Ranged_Hit1 | 9113161857 | Ranged impact (arrow arriving) | 0.42 |
| Combat_Ranged_Hit2 | 9113160396 | Ranged impact | 0.67 |
| Combat_Ranged_Hit3 | 9113160692 | Ranged impact | 1.14 |
| Combat_Enemy_Launch1 | 9120629100 | Shot Enemy (EnemyFX) | 1.0 |
| Combat_Enemy_Launch2 | 9120629317 | Shot Enemy (EnemyFX) | 1.13 |
| Combat_Magic_Charge1 | 9125648149 | Magic swing, charge to the release | 0.78 |
| Combat_Magic_Charge2 | 9125807267 | Magic swing, charge | 1.27 |
| Combat_Magic_Cast1 | 9116421639 | Magic swing, release | 0.61 |
| Combat_Magic_Cast2 | 9116421238 | Magic swing, release | 0.83 |
| Combat_Magic_Hit1 | 9116423786 | Magic impact (also Magic equip) | 1.45 |
| Combat_Magic_Hit2 | 9116422765 | Magic impact | 1.78 |
| Combat_Magic_Hit3 | 9116424101 | Magic impact | 1.45 |
| Combat_Magic_BurstArcane1 | 9116384485 | Burst Arcane / Nature / Dark / Holy / Earth / Poison | 0.61 |
| Combat_Magic_BurstArcane2 | 9116385087 | Burst Arcane group | 1.15 |
| Combat_Magic_BurstFire1 | 9117982785 | Burst Burn / Hellfire | 0.65 |
| Combat_Magic_BurstFire2 | 9117982781 | Burst Burn / Hellfire | 0.97 |
| Combat_Magic_BurstFrost1 | 9114856215 | Burst Frost | 0.81 |
| Combat_Magic_BurstFrost2 | 9114856304 | Burst Frost | 1.03 |
| Combat_Magic_BurstShock1 | 9114277338 | Burst Shock | 2.5 |
| Combat_Magic_BurstShock2 | 9114277528 | Burst Shock | 1.67 |
| Combat_Magic_BurstWater1 | 9119478063 | Burst Tidal, Poison layer | 1.76 |
| Combat_Magic_BurstWater2 | 9120504377 | Burst Tidal, Poison layer | 1.76 |
| Combat_Magic_HolyChime | 9116394876 | Holy burst layer, Magic crit sting | 2.5 |

### Round 3 (2026-10-14, Combat V3): 36 more sounds, 151 in total

Jump attacks (`Swing` ctx.Variant "Air"), the new event `Land` (a melee jump attack hits the ground: the local landing
or Net "AirSlam"), dash strikes (Variant "Dash") and the new combo steps (Spear 3 Sweep, Heavy 3 GroundBreaker, Ranged
2-3 QuickShot / PowerShot, Magic 2-3 Cast2 / GrandCast), mapped in `Config/CombatSfx` (`Swing.Air`, `Swing.Dash`,
`Land`, more `Steps`, new `Finisher`s; crossbow / gun / blowgun have their own). Same source and settings as before
(licensed ProSoundEffects catalog, free; inserted with the Studio MCP `insert_asset`, a plain Sound each, no children,
attributes SourceAssetId / SourceName / SourceCreator, RollOff InverseTapered 10-150, group PlayerFX). Volumes
loudness-matched by measurement (AudioAnalyzer RMS peak against the existing kit: whooshes about -15 dB, impacts and
booms about -11 dB); Peak / Start / Length measured the same way. **Nothing was auditioned by ear.** Swap candidates
first: the dive wind (a reversed wind build-up), the RocketPunch thruster, the GrandCast energy blast.

Timing: the melee jump attack's dive wind (AirDive, a reversed build-up) ends at the landing (AirAttacks Impact), the
hang whoosh (AirRise) plays from the call; `Land` layers play at the real landing. The Magic area burst now peaks where
the drawn bolt lands (the cast's release + the bolt's flight, as Controllers/VFX), grand casts add a deep boom;
another player's arrow whiz waits for the release of its swing (at most 0.3 s).

| Name | Asset id | Event | Volume |
|---|---|---|---|
| Combat_Heavy_LandBoom1 | 9125401226 | Land Heavy (MeteorSmash) deep boom; small layer of the other landings; grand magic burst | 1.27 |
| Combat_Heavy_LandBoom2 | 9125401225 | same set | 1.13 |
| Combat_Heavy_LandCrunch1 | 9118617342 | Land Heavy rock crunch | 0.34 |
| Combat_Heavy_LandCrunch2 | 9114036371 | Land Heavy rock crunch | 0.49 |
| Combat_Shared_LandCrack1 | 9119041016 | Land Heavy ground crack | 0.46 |
| Combat_Shared_LandCrack2 | 9125869504 | Land Heavy ground crack | 2.46 |
| Combat_Shared_LandStab1 | 9117738766 | Land Sword / Spear point into the ground | 0.99 |
| Combat_Shared_LandStab2 | 9117736085 | Land Sword / Spear point into the ground | 1.72 |
| Combat_Shared_LandDirt1 | 9118596772 | Land Dagger (ShadowDrop) thump, feet layer of Sword / Spear, Shared.Land | 1.08 |
| Combat_Shared_LandDirt2 | 9118683165 | same set | 1.26 |
| Combat_Shared_AirRise1 | 9114374862 | Swing Air: hang whoosh (Dagger flip, Magic hover) | 0.97 |
| Combat_Shared_AirRise2 | 9120716440 | Swing Air: hang whoosh | 0.46 |
| Combat_Shared_AirDive1 | 9120767439 | Swing Air melee: dive wind into the landing | 1.08 |
| Combat_Shared_AirDive2 | 9120768247 | Swing Air melee: dive wind | 2.0 |
| Combat_Shared_DashWhoosh1 | 9120716042 | Swing Dash: lunge whoosh (Sword, Spear, Heavy, Dagger) | 0.67 |
| Combat_Shared_DashWhoosh2 | 9120713678 | Swing Dash: lunge whoosh | 0.52 |
| Combat_Spear_Sweep1 | 9120297827 | Spear step 3 Sweep | 1.64 |
| Combat_Spear_Sweep2 | 9117034144 | Spear step 3 Sweep | 0.74 |
| Combat_Spear_Shaft | 9126283595 | Sweep layer (wooden swish) | 1.33 |
| Combat_Heavy_Breaker1 | 9120720141 | Heavy step 3 GroundBreaker swing | 0.94 |
| Combat_Heavy_Breaker2 | 9117034419 | Heavy step 3 GroundBreaker swing | 1.0 |
| Combat_Dagger_Shadow1 | 9116405867 | Dagger ShadowStep vanish puff, ShadowDrop landing layer | 0.89 |
| Combat_Dagger_Shadow2 | 9125646252 | same set | 1.86 |
| Combat_Ranged_Slide1 | 9114658416 | Ranged SlideShot knee slide (all weapon styles) | 0.51 |
| Combat_Ranged_Slide2 | 9114658160 | Ranged SlideShot knee slide | 0.56 |
| Combat_Ranged_PowerRelease1 | 9114001801 | Ranged step 3 PowerShot report (bow, crossbow) | 1.7 |
| Combat_Ranged_PowerRelease2 | 9114002002 | Ranged PowerShot report | 2.09 |
| Combat_Ranged_PowerWhoosh | 9113166206 | PowerShot arrow leaving (bow, crossbow, gun, blowgun) | 1.9 |
| Combat_Magic_GrandCast1 | 9114314786 | Magic step 3 GrandCast / MeteorDrop deep cast | 0.43 |
| Combat_Magic_GrandCast2 | 9114314602 | Magic GrandCast / MeteorDrop deep cast | 0.46 |
| Combat_Magic_Blink1 | 9116422213 | Magic BlinkBlast blink | 1.0 |
| Combat_Magic_Blink2 | 9116422021 | Magic BlinkBlast blink | 1.57 |

Reused (no new asset): the AirVolley triple release = BowRelease / CrossbowRelease / GunShot / Blowgun three times
0.015 s apart + BowWhoosh + Roll (backflip); jump attack weapon whooshes = SwordSwing / SpearThrust / HeavySwing /
DaggerSlash (lower pitch); Land metal ring = SwordHitMetal, debris = HeavySlamDebris; dash strikes = SwordSpin + SwordSwing, SpearPierce + SpearThrust, HeavySmash + HeavySwing,
DaggerSlash x2; QuickShot = BowRelease / BowWhoosh / BowDraw (higher), crossbow / gun / blowgun steps 2-3
from their own sets (+ HeavySlamBoom under the gun PowerShot); Cast2 = MagicCharge + MagicCast (higher); GrandCast /
MeteorDrop = MagicCharge + MagicCast (lower) + GrandCast; BlinkBlast burst = the element's Burst style at its hit;
GroundBreaker jump = Roll (lower), its slam = the existing Burst "Slam".

### Round 4 (2026-10-14, zone fighting styles): 56 more sounds, 207 in total

Every weapon now adds its zone's accent layer (ctx.Zone = the weapon's zone, the brief = the Sound line of
`Config/CombatStyles`) on top of the category sounds, mapped in `Config/CombatSfx` `Zones` / `ZoneAccent`: a light
layer on ordinary combo steps (every 2nd step; every step for Heavy / Magic, every 3rd for Dagger), a fuller one on
finishers, dash strikes and jump attacks, the zone's signature beats timed exactly like the animation's
`Style_<Zone>_Finisher` / `_Jump` overlays (read from `Config/CombatVFX` `ZoneTiming`, late mode and JumpSkip included),
impacts (at most 3 accents per 0.1 s) and landings. Plains (the base style) has no accent. Accents are quieter than the
category sounds, count in the cap of 12, at most 4 play at once, they are the first ones stopped when the cap is full
and never stop a category sound. Same source and settings as before (licensed ProSoundEffects catalog, free; inserted
with the Studio MCP `insert_asset`, a plain Sound each, no children, attributes SourceAssetId / SourceName /
SourceCreator, RollOff InverseTapered 10-150, group PlayerFX). Base volumes loudness-matched by measurement
(AudioAnalyzer RMS peak: whoosh-type layers -15 dB, impact-type -11 dB, voices and clicks -13 dB); the accent level is
the spec Volume in `Zones` (0.2-0.85). Peak / Start / Length measured the same way. All 56 verified loaded in Play
(IsLoaded, TimeLength > 0). **Nothing was auditioned by ear.** Swap candidates first: the Dead moans (no real moan in
the catalog: an eerie choral exhale and a very quiet ghostly exhale at Volume 8.5), the Swamp bubbles (wet "mouth pops"),
the Heaven choir (a short real chorus swell), the Jungle growls (lion roar / snarl).

| Name | Asset id | Zone: event | Volume |
|---|---|---|---|
| Combat_Style_Desert_Hiss1 | 9118771837 | Desert: sandy hiss on swings, corkscrew jump, landing | 1.32 |
| Combat_Style_Desert_Hiss2 | 9118772208 | Desert: same set | 0.68 |
| Combat_Style_Desert_Burst1 | 9118768545 | Desert: sand burst on impacts, landings, the finisher's sand kick | 1.07 |
| Combat_Style_Desert_Burst2 | 9118768199 | Desert: same set | 0.79 |
| Combat_Style_Jungle_Growl1 | 9116302323 | Jungle: growl-breath at the top of the finisher pounce, pounce jump, dash strike | 1.20 |
| Combat_Style_Jungle_Growl2 | 9116311713 | Jungle: same set | 1.02 |
| Combat_Style_Jungle_Rustle1 | 9114518070 | Jungle: leaf rustle on swings, impacts, landing crouch, landings | 0.77 |
| Combat_Style_Jungle_Rustle2 | 9114515384 | Jungle: same set | 0.54 |
| Combat_Style_Jungle_Rustle3 | 9114515381 | Jungle: same set (short crunchy rustle) | 0.88 |
| Combat_Style_Tundra_Crack1 | 9114857058 | Tundra: icy crack at the release, the finisher's crush (~0.19 s), the frozen jump lock | 0.72 |
| Combat_Style_Tundra_Crack2 | 9114856932 | Tundra: same set | 2.16 |
| Combat_Style_Tundra_Crunch1 | 9114857626 | Tundra: crunching ice impacts, landings | 1.06 |
| Combat_Style_Tundra_Crunch2 | 9114857819 | Tundra: same set | 1.15 |
| Combat_Style_Swamp_Whisper1 | 9126213992 | Swamp: whispery curse on swings, the finisher twirl, jump twist, landings | 1.51 |
| Combat_Style_Swamp_Whisper2 | 9126214931 | Swamp: same set | 4.07 |
| Combat_Style_Swamp_Bubble1 | 9113607142 | Swamp: bubbling pop on impacts, landings, the late body turn | 1.12 |
| Combat_Style_Swamp_Bubble2 | 9113607667 | Swamp: same set | 2.00 |
| Combat_Style_Swamp_Bubble3 | 9113606976 | Swamp: same set | 2.34 |
| Combat_Style_Volcano_Roar1 | 9114442751 | Volcano: fiery roar on swings, the finisher's knee-up and smash, the explosive leap | 0.43 |
| Combat_Style_Volcano_Roar2 | 9114445306 | Volcano: same set | 0.88 |
| Combat_Style_Volcano_Roar3 | 9114443884 | Volcano: same set | 1.07 |
| Combat_Style_Volcano_Hiss1 | 9119165650 | Volcano: lava hiss on impacts, landings, the finisher overshoot | 1.27 |
| Combat_Style_Volcano_Hiss2 | 9119166217 | Volcano: same set | 1.23 |
| Combat_Style_Hell_Rumble1 | 9125990895 | Hell: deep demonic rumble on swings, the savage spin, crater landings | 0.90 |
| Combat_Style_Hell_Rumble2 | 9125989410 | Hell: same set | 1.22 |
| Combat_Style_Hell_Growl1 | 9114628620 | Hell: demonic growl at the finisher's counter-coil, the dive with arms wide | 0.94 |
| Combat_Style_Hell_Growl2 | 9114628598 | Hell: same set | 0.95 |
| Combat_Style_Hell_Fire1 | 9117984279 | Hell: fire burst on impacts, landings, the deepest rip | 1.33 |
| Combat_Style_Hell_Fire2 | 9117988143 | Hell: same set | 1.48 |
| Combat_Style_Heaven_Chime1 | 9126073318 | Heaven: bright chime on swings, the strike, impacts, landings | 2.04 |
| Combat_Style_Heaven_Chime2 | 9126073001 | Heaven: same set | 2.51 |
| Combat_Style_Heaven_Chime3 | 9126071458 | Heaven: same set | 1.04 |
| Combat_Style_Heaven_Shimmer1 | 9120296422 | Heaven: shimmer on the open wings, the halo pause, landings | 1.88 |
| Combat_Style_Heaven_Choir1 | 9113043149 | Heaven: choir-like swell on the finisher's open wings, the halo pause | 3.35 |
| Combat_Style_Dead_Moan1 | 9113802218 | Dead: ghostly moan on the finisher's glide back, the jump drift | 2.04 |
| Combat_Style_Dead_Moan2 | 9114572768 | Dead: same set | 8.51 |
| Combat_Style_Dead_Spirit1 | 9119468359 | Dead: ghostly whoosh on swings, landings | 1.29 |
| Combat_Style_Dead_Spirit2 | 9119467121 | Dead: same set | 1.82 |
| Combat_Style_Dead_Bone1 | 9113510003 | Dead: hollow bone impacts, landings | 1.23 |
| Combat_Style_Dead_Bone2 | 9113509723 | Dead: same set | 1.80 |
| Combat_Style_Dead_Knock1 | 9119975167 | Dead: hollow knock under the bone impacts, the finisher's two snaps | 1.76 |
| Combat_Style_Abyss_Swoosh1 | 9118859153 | Abyss: watery swoosh on swings, the whip, the breaching dive | 0.39 |
| Combat_Style_Abyss_Swoosh2 | 9118859436 | Abyss: same set | 0.51 |
| Combat_Style_Abyss_Splash1 | 9117947034 | Abyss: splash on impacts, landings, the finisher's second ripples | 3.35 |
| Combat_Style_Abyss_Splash2 | 9125701286 | Abyss: same set | 2.63 |
| Combat_Style_Mechanical_Servo1 | 9118943996 | Mechanical: servo whir on swings, the piston release, the jump lock | 1.02 |
| Combat_Style_Mechanical_Servo2 | 9118991185 | Mechanical: same set | 1.58 |
| Combat_Style_Mechanical_Servo3 | 9118421080 | Mechanical: same set | 1.48 |
| Combat_Style_Mechanical_Click1 | 9125822328 | Mechanical: ratchet clicks of the finisher wind-up / retract, the jump lock, after landings | 1.93 |
| Combat_Style_Mechanical_Click2 | 9117612325 | Mechanical: same set | 1.11 |
| Combat_Style_Mechanical_Zap1 | 9114277402 | Mechanical: electric zap on impacts, landings | 1.72 |
| Combat_Style_Mechanical_Zap2 | 9114277403 | Mechanical: same set | 2.75 |
| Combat_Style_Void_Warp1 | 9118158113 | Void: reversed whoosh sucked into the hit (swings, the snap), the flip, implode on impacts | 0.97 |
| Combat_Style_Void_Warp2 | 9118158252 | Void: same set | 1.24 |
| Combat_Style_Void_Thump1 | 9119873301 | Void: deep gravity thump on landings, the slam-down, impacts | 2.95 |
| Combat_Style_Void_Thump2 | 9119872771 | Void: same set | 3.31 |

Reused (no new asset): the Volcano finisher's two stomps = LandDirt (lower), the Abyss splash landing = MagicBurstWater
under the splash. Dev hook: `SoundService:SetAttribute("CombatSfxZone", "<ZoneId>")` forces one zone's accent for
every combat sound; with `CombatSfxDebug` the log marks accents "<event>+<Zone>" and `CombatSfxAccents` counts them.

## How to swap a sound

Change `SoundId` to `rbxassetid://<new id>` on the Sound instance, keep its `Name`, and update the three
`Source*` attributes plus this table. Do not rename the instances: the code finds them by name.

## How the sounds were found (for future additions)

* Licensed SFX: `AssetService:SearchAudio` with `AudioSearchParams.Artist = "Pro Sound Effects"` and
  `AudioSubType = SoundEffect` (short sounds), or the Toolbox search with a minimum duration (long ambience loops).
* Roblox UI kit: same call with `Artist = "Roblox"` (keywords "Roblox GUI", "Roblox_UI", "RBLX UI").
* Licensed music: `AudioSubType = Music`, `MinDuration = 60`; asset ids below 10,000,000,000 are the APM catalog.
