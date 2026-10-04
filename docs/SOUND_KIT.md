# SOUND KIT - Fight Your Destiny

Built 2026-10-04 by the SFX agent. Location: `ReplicatedStorage.Assets.Sounds` with three folders
`SFX` (25), `Music` (15), `Ambience` (18). 58 Sound instances, no scripts.

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

## How to swap a sound

Change `SoundId` to `rbxassetid://<new id>` on the Sound instance, keep its `Name`, and update the three
`Source*` attributes plus this table. Do not rename the instances: the code finds them by name.

## How the sounds were found (for future additions)

* Licensed SFX: `AssetService:SearchAudio` with `AudioSearchParams.Artist = "Pro Sound Effects"` and
  `AudioSubType = SoundEffect` (short sounds), or the Toolbox search with a minimum duration (long ambience loops).
* Roblox UI kit: same call with `Artist = "Roblox"` (keywords "Roblox GUI", "Roblox_UI", "RBLX UI").
* Licensed music: `AudioSubType = Music`, `MinDuration = 60`; asset ids below 10,000,000,000 are the APM catalog.
