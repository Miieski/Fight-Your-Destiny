# ASSET KIT SWAMP - zone 5 props, gates, lighting presets and VFX

Built by the SWAMP ZONE BUILDER, 2026-10-04. 36 models in `ServerStorage.MapAssets.Swamp`, 4 in
`ServerStorage.MapAssets.Gates`, 4 lighting presets, 6 world VFX prefabs. One clone of each model stands in the
preview line-up at `workspace._Staging.AssetPreview.Swamp` (ground centered on X = -3000, Z = 3600; the line-up
itself was never screenshotted, the models were only looked at in place in the zone).

Use: `local m = Kit.asset("Swamp/SwampTree_A"):Clone(); m:PivotTo(CFrame.new(groundPoint)); m.Parent = decorFolder`

Conventions are the same as `docs/ASSET_KIT_A.md`: every entry is a `Model`, pivot = bottom center, front = -Z,
all parts anchored, `SmoothPlastic` (`Neon` for glow accents), colors from `Kit.Palette.Swamp` / `Common` (plus
lerps between those and darker shades), no scripts, no unions, no textures, no `PrimaryPart`. No new Toolbox asset
was inserted: the organic pieces are recolored clones of kit A meshes (they keep their `SourceAssetId` /
`SourceCreator` attributes). Sizes are bounding boxes X x Y x Z in studs.

Scaling: use `m:ScaleTo(m:GetScale() * k)`. `GlowMushroom_A` (3.6), `GlowMushroom_B` (4.6), `Swamp_Cliff_A` (1.3)
and `Spellbook_Floating` (1.6) are stored at a scale other than 1, so a plain `ScaleTo(k)` shrinks them.

## Swamp (36)

| Name | Size | Parts | Notes |
|---|---|---|---|
| SwampTree_A | 26 x 36 x 26 | 12 | mangrove: 5 roots reaching 1.5 below the pivot (stand it in water), 2 `Canopy` meshes (no collision, no query), 3 `MossStrip` (decor). src 127731233099210 |
| SwampTree_B | 35 x 42 x 30 | 16 | bigger, leaning toward +X, 3 canopies, 4 moss strips |
| TwistedTree_A | 19 x 28 x 5 | 14 | bare crooked tree built from blocks, carved face on -Z (`Eye`, Neon `Pupil`, `Mouth`) |
| TwistedTree_B | 13 x 28 x 13 | 2 | two recolored Common/DeadTree_A meshes. src 127731233099210 |
| TwistedTree_C | 18 x 22 x 5 | 9 | hook-shaped, bends toward +X, one moss strip |
| Reed_Cluster_A | 6 x 8 x 6 | 5 | grass mesh + 2 cattails, decor only. src 127731233099210 |
| LilyPad_Swamp_A | 8 x 1 x 6 | 3 | recolored Jungle/LilyPad_A, pale `Bloom`. Put the pivot about 0.08 under the water surface |
| GlowMushroom_A | 8 x 5 x 6 | 2 | Neon MushroomGlow `Caps`, pale `Stems`; caps do not collide. No light. Stored scale 3.6. src 127731233099210 |
| GlowMushroom_B | 12 x 6 x 11 | 2 | larger cluster, stored scale 4.6 |
| Stump_Swamp_A | 5 x 3 x 5 | 2 | dark stump + moss cap |
| Mud_Mound_A | 12 x 3 x 10 | 2 | low mud lump (collides) |
| Swamp_Rock_S / _M / _L | 4 x 2 x 4 / 8 x 6 x 8 / 25 x 15 x 22 | 2 / 2 / 3 | dark green-gray rock + `Moss` cap (decor copy of the mesh). src 9682467046 |
| Swamp_Cliff_A | 59 x 54 x 39 | 6 | Common/Boulder_Cliff_A recolored with moss caps, stored at scale 1.3. Face toward -Z. Hull collision: keep an invisible wall in front (extra, not in the task list) |
| Hanging_Moss_A | 6 x 8 x 1 | 6 | hangs down. Pivot at the LOWEST tip, attribute `Height = 8`: `PivotTo(CFrame.new(anchorPoint - Vector3.new(0, 8 * scale, 0)))`. Decor only |
| Crow_A | 1 x 3 x 4 | 8 | low-poly perched bird, decor only, looks toward -Z |
| Walkway_Section | 14 x 5 x 20 | 13 | plank deck 12 wide x 20 long (along Z), deck top at pivot Y + 2, six posts going 1.2 below the pivot. Tile every 20 studs |
| Walkway_Corner | 14 x 4 x 12 | 9 | 12 x 12 deck, same height |
| Stilt_Platform | 16 x 11 x 28 | 16 | 16 x 16 deck, top at pivot Y + 6, rails on +X / -X / +Z, walkable `Ramp` (6 wide) on -Z down to the ground |
| Rope_Bridge_Swamp | 16 x 5 x 20 | 15 | recolored Common/Bridge_Wood_Section: deck 16 x 20 (along Z), deck top at pivot Y + 1 |
| Rowboat_Sunk | 14 x 5 x 11 | 13 | recolored Plains/Rowboat_Wreck + moss, attribute `SinkDepth = 1` |
| Stilt_Cabin_A | 18 x 30 x 20 | 26 | crooked cabin on 4 stilts, deck top at +7.8, `Door` 6 x 9 on -Z (not enterable), round Neon lantern-yellow `Window`, mossy gable roof, chimney, decor ladder, Neon `Lantern` block (no light) |
| Stilt_Cabin_B | 14 x 37 x 19 | 24 | taller, deck at +9.8, purple witch-hat roof, round Neon purple `Window` over the door |
| Hanging_Lantern | 2 x 5 x 2 | 4 | hangs down, pivot at the lowest point, attribute `Height = 5`. Neon `Lantern` with PointLight `Light` (Range 20, Brightness 1, Shadows off). Decor only |
| Potion_Barrel | 3 x 4 x 3 | 6 | recolored Common/Barrel_A with a Neon `Liquid` disc on top (recolor it: Toxic / Magic) |
| Potion_Shelf | 6 x 7 x 2 | 12 | three shelves, six `Bottle` blocks (three Neon), back toward +Z |
| Scarecrow_Swamp | 8 x 9 x 4 | 11 | recolored Plains/Scarecrow_A, Neon yellow `Eye` parts, dark hat |
| Cauldron_Small | 5 x 5 x 5 | 8 | iron pot on three legs and two logs, Neon `Liquid` with Attachment `SteamPoint` (put `VFX/Green_Steam` there) |
| Broom_A | 2 x 7 x 1 | 3 | leaning broom, decor only |
| Spellbook_Floating | 5 x 1 x 4 | 5 | open book with a Neon purple `Rune`, decor only, stored scale 1.6. Float it and add `VFX/Purple_Magic` |
| Potion_Bottle_A | 1 x 2 x 1 | 3 | round Neon `Liquid` flask (recolor), decor only (extra, for the floating bottles) |
| Skull_Knocker_Door | 3 x 5 x 2 | 11 | skull with Neon purple `Eye` parts and an iron `Ring`. Pivot = bottom center ON the door plane, sticks out toward -Z. Decor only |
| Toad_Totem | 7 x 16 x 6 | 25 | three stacked carved toads on a stone base, Neon green `Pupil` parts, faces -Z |
| Toad_Shrine | 14 x 11 x 12 | 17 | stepped stone altar with a toad statue (`ToadBody`, `ToadHead`, Neon `Eye`), two bowls with Neon `BowlGlow` |
| Rotten_Trunk_Glow | 19 x 25 x 19 | 15 | standing hollow rotten trunk (Plains/FallenLog_Large mesh upright), Neon green `Sap` veins and `SapPool`, 4 roots. src 9682467046 |

## Gates (4)

All gates: opening 24 wide x 16 high, front = -Z = the side the player arrives from. `Barrier` and `PriceSign`
(12 x 4 x 0.5, Front face = -Z) are direct children. `Barrier.PivotOffset` is preset so the model pivot stays at the
bottom center after `Kit.finishGate`. Door decoration is parented under `Barrier` (all `CanCollide = false`,
attribute `BarrierDecorIsChildOfBarrier = true`): destroy `Barrier` to open the gate.

| Name | Size | Parts | Notes |
|---|---|---|---|
| EntryArch_Swamp | 42 x 28 x 10 | 47 | two crooked posts and a crooked beam, `NameSign` 14 x 4 x 0.5 on top (Front = -Z), two hanging lanterns (2 PointLights), hanging moss, glow mushrooms, a crow. NO `Barrier`, NO `PriceSign` |
| Gate_Swamp_2 | 57 x 37 x 12 | 54 | rickety palisade between two twisted trees (Marsh -> Dead Forest). `Barrier` = wooden double door 24 x 16 x 1.4. `PriceSign` hangs above the lintel. Two Neon `Lantern` parts with a PointLight each |
| Gate_Swamp_3 | 114 x 42 x 31 | 52 | rock gap closed by thorny roots (Dead Forest -> Witch Village). `Barrier` = INVISIBLE collidable 24 x 16 x 3 part; the dark `Backing`, `ThornRoot`, `Thorn` and Neon purple `Bud` parts are its children. `PriceSign` on the root beam. No light |
| Gate_Swamp_4 | 64 x 32 x 14 | 49 | rotten-wood wall with a crooked door (Witch Village -> Giant Cauldron). `Barrier` = door 24 x 16 x 2 with planks, iron bands, a big skull knocker and Neon purple `Rune` parts. `PriceSign` on the lintel. Two Neon `Lantern` parts with a PointLight each |

## Lighting presets - `ReplicatedStorage.Assets.Lighting`

Same format as `docs/VFX_KIT.md` (attributes named like Lighting properties + Atmosphere / Sky / ColorCorrection /
Bloom / SunRays children; the Sky is a copy of the one in `Plains`). Lookup rule: `Swamp_1` -> `Swamp`.

| Preset | Intent | ClockTime / Lat | Brightness / Exposure | Ambient / OutdoorAmbient | Atmosphere (Density, Haze, Color) | ColorCorrection (Sat, Contrast, Tint) | ShadowSoftness | SunRays |
|---|---|---|---|---|---|---|---|---|
| `Swamp` (Marsh) | Overcast dusk, murky green haze, readable | 17.2 / -10 | 1.5 / 0 | 98,114,98 / 122,138,118 | 0.42, 2.2, 142,164,122 | 0.06, 0.10, 232,246,224 | 0.6 | 0.04 |
| `Swamp_2` (Dead Forest) | Darker, blue-green mist so mushrooms and wisps pop | 16.6 / -10 | 1.3 / +0.02 | 100,124,124 / 114,140,138 | 0.48, 2.4, 96,132,126 | 0.06, 0.10, 220,244,238 | 0.7 | 0.02 |
| `Swamp_3` (Witch Village) | Warmer, purple tint | 15.6 / -10 | 1.7 / +0.10 | 134,120,142 / 152,138,158 | 0.38, 2.2, 150,132,152 | 0.08, 0.10, 246,232,250 | 0.6 | 0.03 |
| `Swamp_4` (Cauldron grotto + boss arena) | Toxic green interior lit by `Ambient`; the room must be closed | 17.2 / -10 | 1.2 / +0.28 | 134,166,120 (both) | 0.33, 1.6, 70,112,66 | 0.12, 0.08, 236,255,226 | 0.5 | 0 |

Bloom: 0.5 / 1.3 (`Swamp`), 0.65 / 1.15 (`Swamp_2`), 0.6 / 1.2 (`Swamp_3`), 0.75 / 1.1 (`Swamp_4`).
`Swamp_2` and `Swamp_3` were brightened after a first look (the cliffs shade the ground when the sun is low):
do not lower their `Ambient`. The shared blue Sky still shows above the haze in `Swamp_3`.

## World VFX prefabs - `ServerStorage.MapAssets.VFX`

Same Part format as the other world prefabs (invisible anchored Part, built-in particle textures, every emitter
Rate <= 20).

| Name | What it is | Size / coverage | How to place | Emitters (sum Rate) + lights |
|---|---|---|---|---|
| `Swamp_Bubbles` | Slow bubbles (`Bubble`), flat pop rings (`Pop`), small droplets (`Drop`) | 12 x 0.4 x 12 area | Lay it just above the water / mud surface and resize X / Z. Recolor the three emitters for toxic pools | 3 (12) |
| `Green_Steam` | Rising toxic steam column (`Steam.Puff`, `Steam.Mote`) | point; rises about 12 | Part center = source (cauldron `SteamPoint`, pool center) | 2 (10) |
| `Wisp` | Floating glowing orb (`Core.Glow`, `Core.Orb`, `Core.Trail`) | point; glow about 3 across | Put it 5-9 studs above the ground. PointLight `Core.Light` (Range 14, Brightness 1.1, Shadows off) | 3 (9.5) + light |
| `Swamp_Mist` | Low thick murky-green ground mist (`Mist`) | 30 x 2 x 30 volume | Part center about 1.2 above the ground; the zone uses 50-70 wide parts. Tint `Mist.Color` per sub-zone | 1 (5) |
| `Purple_Magic` | Swirling purple motes (`Mote`), slow vortex and glow (`Center.Swirl`, `Center.Glow`) | 4 x 4 x 4 volume | Around a witch prop / rune; resize the part | 3 (9.1) |
| `Cauldron_Boil` | Big bubbles, pop rings, splashes and a wide steam column, Disc-shaped | 40 x 1 x 40 | Lay it on the liquid of the giant cauldron (part X / Z = liquid diameter). PointLight `Center.Light` (Range 48, Brightness 1.6, Shadows off) | 4 (39) + light |

## Where the zone uses things that are not kit models

* Landmark stand-ins are built in place (one `Landmark` Model each, pivot bottom center, attribute `LandmarkName`):
  `SunkenTrunk` (Swamp_1 `Decor`, 125 x 68 x 85 with its root plate and stubs, pivot 10074, 0, 92; a walkable hollow
  octagonal trunk), `SwingTree` (Swamp_2, 82 x 76 x 84, pivot 10038, 0, 380, carved face toward the south, swing on
  the west branch), `WitchTower` (Swamp_3, 38 x 106 x 44, pivot 10050, 0, 674, door facing the square),
  `GiantCauldron` (boss arena `Decor`, 59 x 34 x 52 with handles and logs, pivot 10000, 0, -600; Neon `Liquid` on top).
* Swamp_1 water: `Decor.Ground.MudBed` (top Y = -1.6) under a non-colliding, non-queryable `Water` part (top
  Y = -0.4, so 1.2 deep everywhere). Island tops are at Y = 0, walkway decks at Y = 0.4. The leech spawns sit on
  the bed, under the water.
* `HubReturn` (Swamp_1): Neon cyan disc 8 across at 10016, 0.15, -106, `CanTouch = true`, attribute `Target = "Hub"`.
* `BossGate` (Swamp_4): round root door built in place at the north wall, `Interact` 10 x 8 x 5 in front of it.
* Swamp_4 playable floor is 140 x 120 inside the invisible walls; the toxic pools, rune stones and crystals stand
  in the band between those walls and the rock.
* Arena: `workspace._Staging.BossArenas.Swamp`, `PrimaryPart` = `Floor` (cylinder 158 across, pivot at the top
  center). Children: `PlayerSpawns` (5 pads at Z = -664), `BossSpawn` (10000, 0.5, -545), `MiniBossSpawn1` (west
  alcove, toad shrine), `MiniBossSpawn2` (east alcove, rotting treant), `Door` (Model, `PrimaryPart` = `Panel`,
  south), `Walls`, `Decor` (`Landmark`, `Props`, `VFX` with the `Cauldron_Boil` clone, `Lanterns`, `Roots`).
