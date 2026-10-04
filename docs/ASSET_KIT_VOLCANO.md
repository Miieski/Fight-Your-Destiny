# ASSET KIT VOLCANO - zone 6 props, gates, lighting presets and VFX

Built by the VOLCANO ZONE BUILDER, 2026-10-04. 30 models in `ServerStorage.MapAssets.Volcano`, 4 in
`ServerStorage.MapAssets.Gates`, 4 lighting presets, 6 world VFX prefabs. One clone of each model stands in the
preview line-up at `workspace._Staging.AssetPreview.Volcano` (ground centered on X = -3000, Z = 4210).

Use: `local m = Kit.asset("Volcano/Basalt_Rock_M"):Clone(); m:PivotTo(CFrame.new(groundPoint)); m.Parent = decorFolder`

Conventions are the same as `docs/ASSET_KIT_A.md`: every entry is a `Model`, pivot = bottom center, front = -Z,
all parts anchored, `SmoothPlastic` (`Neon` only for lava, crystals, embers and glow bands), colors from
`Kit.Palette.Volcano` / `Common` (plus lerps between those), no scripts, no unions, no textures, no `PrimaryPart`.
No new Toolbox asset was inserted: the organic pieces are recolored clones of kit A meshes (they keep their
`SourceAssetId` / `SourceCreator` attributes). Sizes are bounding boxes X x Y x Z in studs.

Scaling: several kit A source models are stored at a scale other than 1, so scale relative to the current scale:
`m:ScaleTo(m:GetScale() * k)` (after parenting the clone into the DataModel).

Hexagonal basalt columns are made of three overlapping boxes (flat-to-flat size `f`: three parts `f / sqrt(3)` x h x `f`
rotated 0 / 60 / 120 degrees).

## Volcano (30)

| Name | Size | Parts | Notes |
|---|---|---|---|
| Basalt_Rock_S | 4 x 2 x 4 | 1 | recolored Common/Rock_S_A (src 9682467046) |
| Basalt_Rock_M | 9 x 6 x 8 | 1 | recolored Common/Rock_M_A |
| Basalt_Rock_L | 25 x 14 x 22 | 2 | recolored Common/Rock_L_A |
| Basalt_Column_Cluster | 12 x 14 x 13 | 21 | 7 hexagonal columns (flat 4.2), heights 3-14 |
| Volcanic_Cliff_A | 57 x 50 x 37 | 4 | dark wall segment = Common/Boulder_Cliff_A recolored, stored at scale 1.25. Face toward -Z. Hull collision: climbable, keep an invisible wall in front |
| Ash_Mound_A | 25 x 6 x 22 | 2 | flattened ash-grey rock, decor only (no collision, no query) |
| DeadTree_Charred_A | 9 x 22 x 7 | 1 | recolored Common/DeadTree_A (src 127731233099210) |
| DeadTree_Charred_B | 9 x 18 x 9 | 1 | smaller, darker, turned 140 degrees |
| Lava_Crack_A | 12 x 0.4 x 9 | 6 | flat dark slab with a thin (0.5 wide) Neon crack, decor only. Place it 0.02 above the ground |
| Lava_Pool_Rim | 30 x 6 x 31 | 8 | ring of 8 rocks, inner clear radius about 6: put a lava disc (up to 17 across) inside |
| Red_Crystal_Cluster | 9 x 7 x 9 | 6 | recolored Plains/Ore_Cluster_Blue: Neon red `Crystal` parts + 1 PointLight (red, Brightness <= 0.9, Range <= 18). Delete the light when over budget |
| Obsidian_Shard_A | 11 x 17 x 10 | 2 | recolored Plains/Stalagmite_A, stored at scale 1.4 |
| Obsidian_Shard_B | 7 x 8 x 6 | 3 | recolored Plains/Stalagmite_B |
| Floating_Rock_A | 13 x 12 x 12 | 2 | upside-down boulder with a flat top, decor only. Place it high (pivot = lowest point) |
| Miner_Tent | 11 x 9 x 14 | 9 | ash-grey A-frame tent, dark red `Trim`, entrance on -Z |
| Mine_Cart_Lava | 5 x 6 x 7 | 13 | iron cart with Neon orange `OreNugget` parts; set it 0.25 above the rail pivot |
| Rail_Section_V | 5 x 1 x 20 | 9 | runs along Z, tiles every 20 studs. The zone uses it with `CanCollide = false` |
| Mine_Support_V | 29 x 19 x 4 | 10 | timber frame, clear opening 20 wide x 16 high |
| Ore_Crate | 4 x 6 x 4 | 13 | crate with dark ore and 3 Neon `OreNugget` parts |
| Pickaxe_Rack | 8 x 6 x 1 | 10 | three pickaxes leaning on a rack, tools on the -Z side |
| Dwarf_Forge | 15 x 22 x 10 | 15 | stone forge with chimney, Neon `Mouth` / `MouthCore` on -Z, Neon `Embers` with Attachment `FirePoint`. No light: add `VFX/Fire_Brazier` |
| Anvil_A | 5 x 5 x 3 | 5 | anvil on a stump |
| Bellows_A | 3 x 5 x 8 | 7 | nozzle toward -Z |
| Lantern_Iron | 3 x 9 x 2 | 7 | iron post, Neon `Lamp` + 1 PointLight (Brightness 0.9, Range 18, Shadows off); arm toward +X |
| Basalt_Bridge_Section | 27 x 17 x 20 | 9 | deck 26 wide x 20 long (along Z), walkable width 23 between two low parapets. Attribute `DeckTop = 14`: the deck top is 14 above the pivot (piers go down to the pivot), so place it at `groundY - 14` |
| Stone_Platform_Hex | 35 x 3 x 30 | 6 | hexagonal basalt platform 30 across (flat to flat), attribute `TopY = 3.15` |
| Obsidian_Pillar | 10 x 40 x 9 | 18 | hexagonal obsidian shaft, two Neon red `Glow` bands (no light) |
| Chain_Post | 3 x 8 x 3 | 11 | iron post with a short hanging chain on -Z |
| Brazier_Iron | 5 x 5 x 5 | 6 | tripod bowl, Neon `Embers` with Attachment `FirePoint`. No light: add `VFX/Fire_Brazier` |
| SafePlatform | 22 x 0.35 x 22 | 3 | flat round stone disc 22 across, 0.3 high, with a carved dark `Ring`: parts `Disc`, `Ring`, `Center`. The Magma Titan's Lava Floor attack spares these |

## Gates (4)

All gates: opening 24 wide x 16 high, front = -Z = the side the player arrives from. `Barrier` and `PriceSign`
(12 x 4 x 0.5, Front face = -Z) are direct children. `Barrier.PivotOffset` is preset so the model pivot stays at the
bottom center after `Kit.finishGate`. Door decoration is parented under `Barrier` (attribute
`BarrierDecorIsChildOfBarrier = true`, all `CanCollide = false`): destroy `Barrier` to open the gate.

| Name | Size | Parts | Notes |
|---|---|---|---|
| EntryArch_Volcano | 45 x 28 x 15 | 49 | two clusters of hexagonal basalt columns, a heavy beam, hanging chains, two Neon `Lantern` parts with a PointLight each, two Neon `Vein` strips. NO `Barrier`, NO `PriceSign`. `NameSign` 14 x 4 x 0.5 on the beam (Front = -Z) |
| Gate_Volcano_2 | 127 x 44 x 31 | 45 | mine entrance (Volcano Foot -> Magma Mine): timber frame in a rock face (two `RockJamb` blocks, `RockHead`, two cliff pieces, boulder on top). `Barrier` = heavy plank door 24 x 16 x 1.2 with iron bands and crossed boards. `PriceSign` on the beam. Two Neon `Lamp` parts (no light). A non-colliding rail section runs through the door |
| Gate_Volcano_3 | 59 x 29 x 21 | 74 | iron portcullis between basalt columns (Magma Mine -> Lava River). `Barrier` = INVISIBLE collidable 24 x 16 x 1.4 part with the 9 `Bar` and 4 `CrossBar` parts as children. `PriceSign` on the lintel, Neon red `Emblem` |
| Gate_Volcano_4 | 84 x 34 x 27 | 65 | obsidian door with glowing red cracks (Lava River -> Crater). `Barrier` = obsidian slab 24 x 16 x 3 with Neon `Crack` strips on both faces. Two hexagonal obsidian pylons with a Neon `Glow` band, `PriceSign` on the lintel |

## Lighting presets - `ReplicatedStorage.Assets.Lighting`

Same format as `docs/VFX_KIT.md` (attributes named like Lighting properties + Atmosphere / Sky / ColorCorrection /
Bloom / SunRays children; the Sky is the shared one). Lookup rule: `Volcano_1` -> `Volcano`.

| Preset | Intent | ClockTime / Lat | Brightness / Exposure | Ambient / OutdoorAmbient | Atmosphere (Density, Haze, Color, Decay, Glare) | ColorCorrection (Sat, Contrast, Tint) | Bloom (Intensity, Threshold) | SunRays |
|---|---|---|---|---|---|---|---|---|
| `Volcano` (Volcano Foot) | Ash haze, warm orange horizon, readable ground | 15.0 / -14 | 2.1 / +0.10 | 128,106,98 / 178,148,136 | 0.38, 2.4, 255,150,116, 65,105,125, 0.20 | 0.06, 0.10, 255,236,222 | 0.38, 1.3 | 0.04 |
| `Volcano_2` (Magma Mine interior) | Dark warm cave lit by `Ambient`; lava veins and red crystals pop. The room must be closed | 16.6 / -14 | 1.2 / +0.30 | 180,140,122 (both) | 0.27, 1.4, 170,80,44, 105,185,215, 0 | 0.10, 0.08, 255,238,224 | 0.40, 1.1 | 0 |
| `Volcano_3` (Lava River) | Strongest orange glow and haze | 15.3 / -14 | 2.1 / +0.10 | 150,112,94 / 190,150,126 | 0.37, 2.5, 255,138,84, 35,115,165, 0.25 | 0.10, 0.11, 255,228,206 | 0.40, 1.2 | 0.06 |
| `Volcano_4` (Crater + boss arena) | Red-orange rim light, ember mood | 14.6 / -14 | 1.9 / +0.10 | 140,98,90 / 182,126,112 | 0.37, 2.6, 255,110,84, 45,145,165, 0.20 | 0.08, 0.12, 255,224,212 | 0.40, 1.15 | 0.03 |

**Atmosphere lesson (useful for Hell and other tinted zones):** the distance fog on objects seen away from the sun
comes out as roughly the COMPLEMENT of `Atmosphere.Decay`. A warm `Decay` gave teal / cyan fog on the crater walls;
a blue-cyan `Decay` (the values above) gives the wanted warm orange-red haze. `Atmosphere.Color` must also be
strongly saturated (a grey-brown Color left the whole sky teal).

## World VFX prefabs - `ServerStorage.MapAssets.VFX`

Same Part format as the other world prefabs (invisible anchored Part, built-in particle textures, every emitter
Rate <= 20).

| Name | What it is | Size / coverage | How to place | Emitters (Rate) + beams + lights |
|---|---|---|---|---|
| `Embers_Rising` | Slow glowing orange embers drifting up + soft glow dots | 30 x 4 x 30 area | Lay it on the ground / lava and resize X / Z (the zone uses 30-130 wide) | `Ember` (10), `Glow` (3) |
| `Ash_Fall` | Grey ash flakes falling about 30 studs | 40 x 4 x 40 plate | Put the plate 36-46 above the ground and resize X / Z | `Flake` (16), `Soft` (5) |
| `Steam_Vent` | White steam jet rising about 15 studs + small spits | point (Attachment `Vent`) | Part center = the vent hole on the ground | `Jet` (12), `Spit` (5) |
| `Lava_Bubbles` | Bubbles swelling and popping, sparks, flat rings | 20 x 0.2 x 20 | Lay it on the lava surface and resize X / Z | `Bubble` (7), `Pop` (6), `Ring` (2) |
| `Lava_Glow` | Soft orange PointLight + a few sparks | point | 1.5-4 above the lava. Light: Brightness 1, Range 26, Shadows off (counts toward the light budget) | `Spark` (3) + `Light` |
| `Lava_Fall_Sheet` | Falling lava strip (two beams) with streaks and a splash at the foot | 14 wide; height 20 by default | Part = top lip (X = width). Height: move attachment `Bottom` down and set `Streaks.Lifetime = height / 14`. The sheet faces the part's +Z / -Z | `Streaks` (16), `Splash` (14), `SplashGlow` (5) + beams `Sheet`, `Core` |

## Where the zone uses things that are not kit models

* Landmark stand-ins are built in place (one `Landmark` Model each in `Decor`, pivot bottom center, attribute
  `LandmarkName`):
  * `Volcano` (Volcano_1): faceted cone 312 x 222 x 338 east-north-east of the basin, pivot 12272, 0, 177, outside
    the play area (no collision). Neon `LavaStream` strips, `CraterLava` disc, four `AshPlume` balls above the
    crater (they raise the bounding box to 402). Its west foot touches the east side of the Magma Mine shell.
  * `MineElevator` (Volcano_2): timber head-frame with a cage, wheel and cables + stone furnace with a glowing
    mouth and an iron chimney, 62 x 88 x 37, pivot 12055, 0, 372, front toward -Z. It stands under the tall shaft
    part of the cavern (ceiling about 95 there). 1 PointLight on `FurnaceMouth`.
  * `LavaFall` (Volcano_3): cliff with a 100-stud lava fall on the west edge, 69 x 107 x 129, pivot 11852, 0, 630,
    back toward -X. Contains a `Fall` part (a `Lava_Fall_Sheet` clone) and static Neon `LavaColumn` parts.
  * `StoneTitan` (boss arena `Decor`): waist-up stone titan rising from the lava north of the floor, about
    62 x 71 x 44 for the body (74 x 75 x 60 with the rocks at its base), pivot 12000, -3, -502, facing -Z.
* `BossGate` (Volcano_4) is built in place: a 40 x 56 obsidian double door between two 77-stud pylons in the north
  crater wall. The arena `Door` is a 24 x 30 obsidian slab (`PrimaryPart` = `Slab`) between two pylons.
* Arena: `workspace._Staging.BossArenas.Volcano`, `PrimaryPart` = `Floor` (cylinder 150 across, pivot at the top
  center). `SafePlatforms` (Folder) holds six `SafePlatform` models 45 studs from the center (every 60 degrees,
  starting at 30). `Bounds` (Folder) holds the invisible ring, alcove walls, pool fence and the `Lid` at Y = 101.
