# ASSET KIT TUNDRA - zone 4 props, gates, lighting presets and VFX

Built by the TUNDRA ZONE BUILDER, 2026-10-04. 34 models in `ServerStorage.MapAssets.Tundra`, 4 in
`ServerStorage.MapAssets.Gates`, 4 lighting presets, 6 world VFX prefabs. One clone of each model stands in the
preview line-up at `workspace._Staging.AssetPreview.Tundra` (ground centered on X = -3000, Z = 3025).

Use: `local m = Kit.asset("Tundra/SnowPine_A"):Clone(); m:PivotTo(CFrame.new(groundPoint)); m.Parent = decorFolder`

Conventions are the same as `docs/ASSET_KIT_A.md`: every entry is a `Model`, pivot = bottom center, front = -Z,
all parts anchored, `SmoothPlastic` (`Neon` for small glow accents, `Glass` for three translucent citadel pieces),
colors from `Kit.Palette.Tundra` / `Common` (plus lerps between those), no scripts, no unions, no textures, no
`PrimaryPart`. `Model:ScaleTo` works on all. No new Toolbox asset was inserted: the organic pieces are recolored
clones of kit A meshes (they keep their `SourceAssetId` / `SourceCreator` attributes). Sizes are bounding boxes
X x Y x Z in studs.

Snow caps: the white layer on pines, rocks and cliffs is a second copy of the same mesh, slightly narrower and
shifted up (part named `Snow`, no collision, no query, no shadow).

## Tundra (34)

| Name | Size | Parts | Notes |
|---|---|---|---|
| SnowPine_A | 16 x 32 x 18 | 3 | Common/PineTree_A in dark pine green + `Snow` layer. Leaves do not collide (src 8973577087) |
| SnowPine_B | 14 x 39 x 16 | 3 | same from PineTree_B |
| SnowPine_C | 16 x 46 x 18 | 3 | same from PineTree_C |
| FrozenBush_A | 7 x 4 x 7 | 2 | ice-blue bush with snow, no collision (src 9682467046) |
| DeadTree_Ice_A | 9 x 23 x 7 | 2 | dark dead tree with a frost layer (src 127731233099210) |
| SnowRock_S | 4 x 3 x 4 | 2 | gray rock + snow cap (src 9682467046) |
| SnowRock_M | 8 x 6 x 8 | 2 | |
| SnowRock_L | 25 x 16 x 22 | 4 | |
| Ice_Chunk_S | 5 x 4 x 4 | 1 | faceted blue ice, Transparency 0.2 |
| Ice_Chunk_M | 11 x 10 x 10 | 2 | |
| Ice_Chunk_L | 27 x 23 x 22 | 3 | |
| Ice_Spike_A | 8 x 12 x 7 | 2 | recolored Plains/Stalagmite_A, Transparency 0.15 (src 127731233099210) |
| Ice_Spike_B | 7 x 8 x 6 | 3 | recolored Plains/Stalagmite_B |
| Icicle_Row | 12 x 6 x 2 | 8 | hangs down. Pivot is at the LOWEST tip, attribute `Height = 6`: `PivotTo(CFrame.new(ceilingPoint - Vector3.new(0, 6, 0)))`. Decor only |
| Snow_Drift_A | 26 x 4 x 19 | 2 | low snow mound, decor only (no collision, no query) |
| Ice_Cliff_A | 59 x 54 x 39 | 7 | ice + rock wall segment = Common/Boulder_Cliff_A recolored, stored at scale 1.3 (`ScaleTo(1.7)` gives about 77 x 70 x 51). Hull collision: climbable, keep an invisible wall in front |
| Snow_Cliff_A | 59 x 54 x 39 | 7 | same, rock / pale purple rock with snow caps (extra, not in the task list) |
| Cabin_Broken | 26 x 18 x 26 | 40 | snowed-in log cabin 20 x 16, roof collapsed on the +X side, door on -Z (not enterable), chimney, three snow drifts |
| Snowman_A | 8 x 10 x 4 | 12 | top hat, stick arms |
| Snowman_B | 7 x 8 x 4 | 11 | bucket hat, pale purple `Scarf` |
| Sled_A | 4 x 2 x 10 | 16 | runners along Z, rope toward -Z |
| FishingHole | 9 x 4 x 7 | 12 | flush dark `Water` disc (6 across, no collision) + stool, rod, bucket, two fish. Put it on the ice surface |
| Wooden_Scaffold | 16 x 14 x 8 | 15 | plank deck 16 x 8, top at pivot Y + 10.8, rail on -Z. No ladder (side dressing) |
| Snow_Bridge_Section | 42 x 10 x 11 | 11 | arched snow / ice span 40 long (along X) x 10 wide, deck top about pivot Y + 8, icicles underneath |
| Ice_Cave_Mouth | 29 x 18 x 13 | 9 | dark recess 12 x 11 framed by ice rocks, icicles. Put its back (+Z) against a cliff |
| Bone_Pile_Ice | 7 x 3 x 6 | 18 | Plains/Bone_Pile_A half frozen in an ice lump |
| Ice_Wall_Panel | 20 x 24 x 3 | 7 | ice frame with a translucent `Pane` (Glass, Transparency 0.45) |
| Ice_Pillar | 8 x 40 x 8 | 8 | two-tone faceted shaft, two Neon `Glow` bands (no light). `ScaleTo(1.2)` = 48 tall, `ScaleTo(1.5)` = 60 |
| Frozen_Knight_Statue | 11 x 15 x 9 | 19 | knight (sword point down, Neon `Visor`) inside a translucent `IceBlock` (Glass), on a plinth |
| Blue_Torch_Standing | 2 x 7 x 2 | 4 | Attachment `FirePoint` on `Head`, Neon blue `Ember`. No light: add `VFX/Fire_Torch_Blue` |
| Blue_Torch_Wall | 1 x 4 x 2 | 4 | pivot = bottom of the bracket ON the wall plane, torch sticks out toward -Z. Attachment `FirePoint`. No light |
| Weapon_Rack_Frozen | 8 x 9 x 3 | 16 | sword, axe and spear on a rack, ice lumps and icicles; weapons face -Z |
| Warm_Brazier | 9 x 9 x 9 | 10 | large iron bowl with a gold rim, Neon orange `Embers` + `EmberGlow`, Attachment `FirePoint` on `Embers`. No light: add `VFX/Fire_Brazier`. The boss arena's warm safe spots |
| Ice_Throne_Small | 13 x 18 x 9 | 12 | ice seat on two steps, spiked back, two side crystals, Neon `Gem` |

## Gates (4)

All gates: opening 24 wide x 16 high, front = -Z = the side the player arrives from. `Barrier` and `PriceSign`
(12 x 4 x 0.5, Front face = -Z) are direct children. `Barrier.PivotOffset` is preset so the model pivot stays at the
bottom center after `Kit.finishGate`. Door decoration is parented under `Barrier` (all `CanCollide = false`):
destroy `Barrier` to open the gate.

| Name | Size | Parts | Notes |
|---|---|---|---|
| EntryArch_Tundra | 48 x 28 x 9 | 37 | snowy log posts on stone bases, two log beams, ice crystals, icicles. NO `Barrier`, NO `PriceSign`. `NameSign` 14 x 4 x 0.5 (Front = -Z). Two Neon blue `Lantern` parts with a PointLight each |
| Gate_Tundra_2 | 47 x 27 x 18 | 60 | log palisade half buried in snow (recolored Gate_Plains_2 + drifts). `Barrier` = wooden double door 24 x 16 x 1.4 with two `SnowBank` wedges. Two Attachments `FirePoint` on the torch embers (no light) |
| Gate_Tundra_3 | 77 x 39 x 22 | 32 | two snow-capped rock pillars, `Barrier` = INVISIBLE collidable 24 x 16 x 2 part with the wall of `IceBlock` parts and a Neon `Rune` as children. `PriceSign` hangs from the log beam |
| Gate_Tundra_4 | 56 x 60 x 19 | 38 | citadel gatehouse: two ice towers with spires, wall and crenels above the opening. `Barrier` = translucent ice slab 24 x 16 x 3 (Glass, Transparency 0.35) with frame, facets and a Neon `Emblem`: the gate "that melts". `PriceSign` = ice tablet on the wall above |

## Lighting presets - `ReplicatedStorage.Assets.Lighting`

Same format as `docs/VFX_KIT.md` (attributes named like Lighting properties + Atmosphere / Sky / ColorCorrection /
Bloom / SunRays children; the Sky is a copy of the one in `Plains`). Lookup rule: `Tundra_1` -> `Tundra`.

| Preset | Intent | ClockTime / Lat | Brightness / Exposure | Ambient / OutdoorAmbient | Atmosphere (Density, Haze, Color) | ColorCorrection (Sat, Contrast, Tint) | ShadowSoftness | SunRays |
|---|---|---|---|---|---|---|---|---|
| `Tundra` | Pale low sun from the south-west, cold blue shadows, white snow that keeps its facets | 14.6 / -20 | 2.1 / -0.10 | 118,130,160 / 138,150,182 | 0.30, 1.3, 214,232,255 | 0.10, 0.08, 244,249,255 | 0.22 | 0.06 |
| `Tundra_2` (Frozen Lake) | A little brighter and more cyan | 14.2 / -16 | 2.2 / -0.10 | 116,136,162 / 136,160,186 | 0.27, 1.2, 204,240,255 | 0.14, 0.08, 238,250,255 | 0.20 | 0.08 |
| `Tundra_3` (Mountain) | Lower sun, hazier, cooler, long shadows | 15.5 / -24 | 2.0 / -0.08 | 110,122,158 / 128,140,180 | 0.40, 2.1, 196,212,246 | 0.06, 0.08, 232,240,255 | 0.30 | 0.10 |
| `Tundra_4` (Ice Citadel interior + boss arena) | Cool blue interior lit by `Ambient`, readable; the room must be closed | 15.9 / -20 | 1.2 / +0.25 | 150,168,206 (both) | 0.24, 1.0, 96,126,184 | 0.04, 0.10, 238,245,255 | 0.5 | 0 |

Bloom: 0.28-0.30 with threshold 1.9-1.95 outdoors (so the snow does not glow), 0.7 / 1.1 in `Tundra_4`.

## World VFX prefabs - `ServerStorage.MapAssets.VFX`

Same Part format as the other world prefabs (invisible anchored Part, built-in particle textures, every emitter
Rate <= 20).

| Name | What it is | Size / coverage | How to place | Emitters (sum Rate) + beams + lights |
|---|---|---|---|---|
| `Snow_Fall` | Gentle falling flakes (soft dots + squares) | 40 x 4 x 40 plate; flakes fall about 25-35 studs | Put the plate about 34 above the ground and resize X / Z (the zone uses 64-110 wide plates) | 2 (28) |
| `Snow_Gust` | Wind-blown white streaks + powder puffs | 30 x 6 x 30 volume | Sits just above the ground; blows toward the part's **+X** | 2 (19) |
| `Ice_Sparkle` | White-cyan glints | 20 x 1 x 20 volume | Lay it on ice / frosty floors and resize | 1 (8) |
| `Fire_Torch_Blue` | Blue version of `Fire_Torch` (`Fire.Flame`, `Fire.Core`, `Fire.Ember`, `Fire.Light`) | point | Part center = torch `FirePoint`. Light: blue, Range 22, Brightness 1.6, Shadows off (the citadel and arena clones use Range 28-34, Brightness 2.4) | 3 (22) + light |
| `Frost_Mist` | Low pale-blue ground mist | 30 x 2 x 30 volume | Part center about 1.5 above the ground | 1 (3) |
| `Aurora_Ribbon` | Three wide soft beams (green, purple, cyan), camera-facing | about 260 long (attachments `L1..L3` / `R1..R3` along X) | Sky backdrop: put it 250+ high to the north. To enlarge, multiply the attachment positions and the beams' `Width0/Width1/CurveSize0/CurveSize1` by the same factor (the zone uses 2.2) | 3 beams |

## Where the zone uses things that are not kit models

* Landmark stand-ins are built in place (one `Landmark` Model each in `Decor`, pivot bottom center, attribute
  `LandmarkName`): `FrozenTree` (Tundra_1, 46 x 73 x 47, pivot 8045, 0, 60), `FrozenShip` (Tundra_2, 131 x 64 x 77,
  a recolored Plains/PirateShip_Wreck frozen into an ice bulge, pivot 8076, 0.14, 366), `IceCavePeak` (Tundra_3,
  132 x 126 x 132, pivot 8150, 0, 664, cave mouth facing south-west), `IceThrone` (boss arena `Decor`,
  50 x 53 x 33 with its side crystals, pivot 8000, 3, -492 on top of the dais).
* `BossGate` (Tundra_4) and the arena `Door` are built in place (dark ice double doors; the BossGate carries a
  gold crown emblem).
* Arena: `workspace._Staging.BossArenas.Tundra`, `PrimaryPart` = `Floor` (cylinder, pivot at the top center).
  `WarmSpots` (Folder) holds four `WarmBrazier` models at the diagonals, 62 studs from the center; each contains
  its fire as a child Part named `Fire` (a `VFX/Fire_Brazier` clone with the light).
