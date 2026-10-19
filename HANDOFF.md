# HANDOFF - Fight Your Destiny (for the next Claude)

Read this first, then `DESIGN.md` (the contract; it wins over older docs where they differ),
then the design documents in `docs/`:
- `docs/enemy_database.txt` - stats, rewards, loot and diamonds (source of truth for numbers)
- `docs/zone_design_document.txt` - look and layout of every zone
- `docs/boss_patterns_document.txt` - boss attack patterns, tools and workflow
- `docs/weapon_system_document.txt` - 84 weapons, rarity, zone damage scaling, zone boost, shop

## 1. What this is

Roblox game **"Fight Your Destiny"** (placeId `106749213017380`, universeId `10769126910`):
an NPC combat game with a zone-progression and rebirth loop.

* **Core loop:** kill NPCs -> earn coins -> pay coins to unlock the next sub-zone ->
  reach the boss room -> beat 2 mini-bosses and the boss -> **Rebirth** -> replay the zone
  (stronger, with bonuses) -> the next zone unlocks.
* **12 zones, 4 sub-zones each** (48 sub-zones). Sub-zone 4 is always the boss room.
  Order of progression: Plains, Desert, Jungle, Tundra, Cursed Swamp, Volcano, Hell,
  Heaven, Realm of the Dead, Abyss, Mechanical City, The Void.
  The original four zones (Plains, Hell, Heaven, Void) are inspired by Minecraft's
  Overworld, Nether, Aether and End.
* **Enemies:** 132 normal enemies (3 per sub-zone, 2 in the boss room), 24 mini-bosses
  (2 per boss room), 12 bosses. Each enemy has HP, damage and a base coin reward.
* **Boss fights:** every boss has at least 3 attack patterns with a telegraph of 1 second or
  more, plus an enrage phase at 50% HP. The Void Dragon has 4 patterns.
* **Currencies:**
  * **Coins** - dropped by every enemy; values grow x10 per zone.
  * **Diamonds** - premium currency; dropped ONLY by mini-bosses (15%) and bosses (40%),
    amounts grow slowly (+z per zone), and sold for Robux (Developer Products).
* **Loot:** each enemy has one possible loot item (corpse, egg, weapon, armor, material,
  trophy). Drop chance: 2% normal enemies (identical for all), 4% mini-bosses, 6% bosses.
  8 rarity tiers: Common, Uncommon, Rare, Epic, Legendary, Mythic, Divine, Secret.
  Stronger enemy = rarer loot (see section 1 of `enemy_database.txt` for the exact rule).
* **Weapons:** 7 categories (Sword, Spear, Heavy, Dagger, Gauntlet, Ranged, Magic) x 12 zones
  = 84 weapons (the Whip & Chain category was removed on 2026-10-12). Each weapon belongs to a zone; damage = zone base x category x
  rarity, plus a Zone Boost when used in its home zone. Bought in the shop with a RANDOM rarity.
* **Rebirth (superseded - see DESIGN.md section 4):** resets Gold, weapons, armor, stats, eggs
  and pets, keeps diamonds and boss keys (old text follows),
  and gives a permanent bonus (for example more coins). Unlocking the next zone depends
  on the number of rebirths.
* **Monetization (planned):** diamond packs via Robux, game passes (double coins, exclusive
  weapon), temporary boosts.

The owner wants: a clean, readable game with satisfying combat, strong feedback (particles,
screen shake, damage numbers), and long-term progression. The owner works in French but
design documents are in English.

**Repo:** https://github.com/Miieski/Fight-Your-Destiny (branch `main`). Git holds the
scripts and docs only. The world and assets live in the Roblox place itself.

## 2. Repo layout

```
src/ReplicatedStorage/GameSystem/            shared config (zones, enemies, bosses, loot) + profile data
src/ServerScriptService/GameSystem/          combat, enemy spawner, bosses, economy, rebirth, DataStore
src/StarterPlayer/StarterPlayerScripts/GameClient/   HUD, VFX, shop/inventory UI, boss health bar
docs/                                        design documents (see above)
BackUP_Files/                                place backups (gitignored, kept locally)
default.project.json                         Rojo mapping (only the three src branches)
```

Suggested module layout (create as needed):
```
GameSystem/Config/ZonesConfig.luau       zones, sub-zones, unlock prices, boss names
GameSystem/Config/EnemyConfig.luau       HP, DMG, coins, loot, drop chances
GameSystem/Config/BossConfig.luau        patterns, cooldowns, enrage rules
GameSystem/Config/LootConfig.luau        rarity tiers, item list, diamond drops
GameSystem/Config/Products.luau          Developer Product / game pass IDs (0 = hidden)
Server/Services/*.luau                   one service per system (auto-loaded)
Server/Bosses/BossBase.luau              shared boss state machine
Server/Bosses/<BossName>.luau            patterns for each boss
Client/Controllers/*.luau                VFX, UI, camera shake, damage numbers
```

Conventions: Luau, tabs, `--!strict` where practical, `task.*` only (never `wait`), all
gameplay logic on the **server**, the client only shows visuals and sends requests.
Keep ALL numbers in config modules, never hard-coded in gameplay scripts. All remotes go
through one shared `Net` module. The server validates every request (distance, cooldown,
ownership, price). Never trust the client for damage, money, or drops.

## 3. How to work on it (tooling - read carefully)

**Only the scripts are in git.** The Workspace map, terrain, lighting and the enemy/boss
models in `ServerStorage` live **only in the place file**. The owner saves from Studio
(Ctrl+S). Ask them to save before anything risky.

1. **Rojo:** run `rojo serve` in the repo folder, then Studio -> Plugins -> Rojo -> Connect.
   Rojo pushes disk -> Studio and overwrites what it maps. There is **no pull**: a change
   made directly in Studio must be copied back into `src/` by hand, or it is lost on the
   next connect. Workspace, Lighting, Terrain and ServerStorage are NOT mapped.
2. **Backups:** before big changes, save `File -> Save to File As -> BackUP_Files/FightYourDestiny_<date>.rbxl` (see section 3b: backup before ANY change).
   These are gitignored (large); copy them to a cloud drive or external disk.
3. **Toolbox assets:** free models can contain hidden scripts (including purchase prompts and
   backdoors). Right after inserting any Toolbox asset:
   * delete EVERY script, remote, value and GUI inside it unless you wrote it,
   * check there is no `require(<number>)` or obfuscated code,
   * anchor static props (many Toolbox models arrive unanchored).
4. **Commits:** commit after every meaningful step with a short message
   (`git add -A && git commit -m "..." && git push`).
5. **Player data** lives in Roblox DataStores, not in git. Studio needs
   Game Settings -> Security -> **Enable Studio Access to API Services** to test DataStores.
   Use a session lock or a proven library pattern, save on leave and on a timer, and use
   `UpdateAsync` rather than `SetAsync` for anything important.

### Playtesting
* Test with **1 player and with 2-4 players** (use Test -> Clients and Servers). Boss rooms
  are multiplayer: each pattern must stay fair with several targets.
* Add a hidden **admin/debug command set** (owner only, check UserId on the server) to speed
  testing: set coins/diamonds, set rebirths, unlock zone N, teleport to a boss room, kill the
  current enemy, force a boss pattern.
* Studio has no real DataStore data unless API access is on; do not assume saves work in Studio
  without testing them.

## 3b. MANDATORY RULES: backup first, GitHub last

1. **Before making ANY change (even a small one), make a backup and put it in the folder
   `BackUP_Files/`** at the root of the project:
   * Place backup: `File -> Save to File As... -> BackUP_Files/FightYourDestiny_<YYYY-MM-DD_HHMM>.rbxl`.
   * If the Studio MCP / SerializationService is available, also serialize the Workspace map and
     the assets into `.rbxm` files in `BackUP_Files/`.
   * Never overwrite an older backup; every backup has its own dated name.
   * If you cannot create the backup yourself, ask the owner to save the place first and
     wait for confirmation before changing anything.
2. **At the end of the work, ALL modifications (scripts, configs, docs) must be committed and
   pushed to GitHub: https://github.com/Miieski/Fight-Your-Destiny (branch `main`).**
   Use short clear commit messages, push, and tell the owner the result.
3. `BackUP_Files/` is gitignored (the files are large), so the backups stay on the owner's
   computer. Remind the owner to copy them to a cloud drive or an external disk.
4. If the backup step or the push fails, say so plainly and do not continue as if it worked.

## 4. Sub-agents (the owner explicitly wants them used)

Work boss by boss and system by system with sub-agents:

* One sub-agent per boss, all using the same brief (`docs/boss_patterns_document.txt` +
  `docs/enemy_database.txt` + the shared `BossBase` module). Each delivers its boss module, a
  list of VFX and animation names it expects, and test notes.
* A separate **reviewer** sub-agent checks every module against the rules (telegraph >= 1s,
  damage and cooldowns server-side, no hard-coded numbers, no unsafe remotes).
* Recommended lessons:
  * Run at most ~2 agents at the same time; too many parallel agents can hit usage limits and
    stop mid-task. Resuming an existing agent keeps its context and is cheaper than a new one.
  * Only one agent should control Studio at a time (Edit-mode actions fail while Play is running).
  * Give each agent a strict list of files/folders it owns and require a final report with the
    exact APIs it created.
  * Run a review pass and a playtest pass after each feature wave; verify visually yourself.
* Create a `docs/AGENT_BRIEF.md` with the rules every sub-agent must follow before launching them.

## 5. Current state (as of this handoff)

**2026-10-19: PROP MODEL UPGRADE (brief docs/model_upgrade_brief.txt; 18 props - the "mallet" of photo 03 is a bench
armrest, benches are out of scope).** Inventory `docs/prop_inventory.md` (test area =
`workspace._Staging.AssetPreview.ModelsA.Lineup`, X about -3000). STATE: Studio-built props done and live everywhere
(crate, barrel, lamp_post, lantern, laundry_rack, the 3 stall frames); the 13 Blender props (well, chest, rowboat,
minecart, skull_bones, clam_pearl, egg_nest, scarecrow, fountain, anvil_forge, and the awnings / items / signs of
weapon_stall, trophy_stall, diamond_shop) are built, previewed in Studio and WAITING FOR THE OWNER'S FBX IMPORT
(`Blender_Exports/Props/PROPS_IMPORT.md`); until then today's models stay. The 3 stall shopkeepers reuse the Part F
NPC models (`Blender/NPC/Hub/npc_blacksmith | npc_trophy_merchant | npc_gem_merchant`), which arrive with the creature
import (`Blender_Exports/CREATURES_IMPORT.md`).
* Single source of truth: `ServerStorage.MapProps.<propId>`; every placed copy (214) is a Model tagged `MapProp` with
  attribute `MapPropId` (test area, Hub, Zones, MapAssets kit, BossArenas). Props embedded in bigger kits (HunterCamp
  crate / barrel / laundry rack, Market_Awning barrel, WeaponShop anvil forge, TutorialGuide / EggStation / EntryArch
  lanterns) were wrapped in child Models in place. Recolours = variants (crate / rowboat `Sunken`, skull_bones `Pale`).
* `DevTools.SyncMapProps` (`tools/SyncMapProps.luau`): `run()` replaces out-of-date copies with a template clone,
  keeping pivot, scale, name, parent, attributes, tags, variants and the functional children (Interact, NpcSpot, NPC,
  prompts, GUIs, scripts, sounds, nested props, anything with attribute MapPropKeep); idempotent through
  `MapPropVersion` (second run = 0 replaced); nested copies (lamp_post > lantern, weapon_stall > anvil_forge) are
  synced in later passes. `capture(propId, instance)` = the reverse direction (a hand-improved copy becomes the
  template and is synced everywhere); `undoCapture(propId)`; `check()` = status. Always `require(module:Clone())`.
* Studio-built props: `DevTools.StudioProps` (builders; `StudioProps.stall` = the shared stall frame). Shared look:
  11 MaterialVariants `FYD_*` in MaterialService (the Prop Style Guide textures, 4 studs per tile).
* Blender props: pipeline `tools/blender/fyd_props*.py`, Prop Style Guide + naming contract `Blender/Props/README.txt`,
  manifest `Blender/Props/props_manifest.csv`, FBX in `Blender_Exports/Props/` (written in studs, no textures),
  data `Blender_Exports/Props/PropMeshData.luau` (pasted as `DevTools.PropMeshData`; `tools/PropMeshData.luau` must
  stay identical). After the owner's import: `print(require(game.ServerStorage.DevTools.ApplyPropMeshes:Clone()).run())`
  (`run({ only = { "well" } })`, `run({ dryRun = true })`). It validates each import against the data first and
  SKIPS a prop (template and today's models untouched) when a mesh is missing / unknown / duplicated (Merge Meshes
  ON?), rotated, distorted, laid out differently (turned or mirrored import), or its preview is installed; one common
  wrong unit (x28, x100, x0.036) is corrected; `allowMissing = true` overrides. Then it builds the template (shared
  SurfaceAppearances tinted per mesh, roles Glow / Water / Glass / Stream / Foam, invisible data colliders + Hull
  collider meshes, a Root part with the PropFX attachments, lights and emitters), installs it (old one in
  `MapProps._Previous`, skipped when identical), syncs, and moves the applied import to `ServerStorage.ImportedProps`.
  PIECES mode (the 3 stalls): the FBX holds only the Blender pieces; they are added to a copy of the Studio frame
  (saved once as `MapProps._Base.<id>`); anchored items are re-based on the real parts they replace; replaced solid
  parts stay as invisible colliders. Rebuilding a frame after the import: `StudioProps.install(<stall>)` (rebuilds
  `_Base`), then `run({ only = { "<stall>" } })`.
* Preview without an import: `preview(propId, { "rbxassetid://<id>" })` rebuilds the prop from its uploaded preview
  PNG (mesh data in the pixels: "FYDM" + Adler-32 + JSON; ids in `Blender_Exports/Props/preview/preview_ids.json`)
  with EditableMesh, installs and syncs it temporarily; `endPreview(propId)` MUST be run before saving (it puts the
  exact originals back; nested: end the host first). A second preview of the same prop is refused.
* Adding a prop: Agent-A side = Blender recipe, FBX, regenerate PropMeshData, upload a preview PNG; Agent-B side = a
  rule in `SyncMapProps.RULES` / `EMBEDDED`, `tagAll({ only = { id } })`, `backup(...)`, paste PropMeshData,
  VARIANTS / DROP_ATTRIBUTES / PIECES entries if needed, `Config/PropFX` entries, preview + screenshots + endPreview.
* Effects: client `Controllers/PropFX` driven by `Config/PropFX`: on within 80 studs, off beyond 100 (4 Hz check), at
  most 6 particle emitters in total (`MAX_EMITTERS`, nearest props first), active props re-check their parts every 2 s
  (StreamingEnabled), Low FX stops particles / sway / spin / scroll / flicker and keeps the static lights. The hub's
  always-on VFX parts (`Hub.Decor.VFX.Fire_Torch`, `Diamond_Sparkle`, `Water_Ripple`) were kept and PropFX does not
  duplicate them. Debug attributes on the client camera `PropFX_*`; test switch LocalPlayer attribute
  `PropFX_TestLowFx`.
* Backups of the old props: `BackUP_Files/old_props_2026-10-18_2328/` (18 .rbxm + MANIFEST.txt).
* Open for the owner: the FBX import + the command; optional: raise the two Plains_4 Mine minecarts by 0.80 (their
  wheels sink into the rails, today's carts too); optional ambient sounds (fire crackle, fountain water, wind chime -
  no Ambient SoundGroup exists).
Log: NIGHT_LOG "Prop model upgrade"; screenshots docs/screenshots/prop_upgrade/; previews Previews/Props/.

**2026-10-18 (late night): EGG LIGHT V2 (owner: "During the haching, remove the cercle below the egg. It spoil the
rarity and make the hacching uglier. For the light behind the egg put it progressly during the haching and relesing
process, and make it more realistic.").** `UI/Hatching` `eggOnly(view)` deletes the `RarityRing` parts from the hatch
screen's egg view (a clone; ModelIcon and the other egg icons unchanged) and re-frames the camera on the egg (zoom
1.25). `UI/EggLight` rewritten (VFX sub-agent): image layers with 4 uploaded soft textures (ids in `EggLight` TEX;
generator `Previews/EggLight/make_egg_light_textures.py`, PIL): aura + near-white core + 2 counter-rotating beam
layers + an egg-shaped rim light (follows the egg's tilt / squash) behind the egg, a bloom and sparks (max 16) over
it; about 6 ImageLabels. Intensity follows u and a smoothed crack spread; colour warm white -> rarity colour.
New `light:burst()` (breakEgg, or reveal on Skip / the flat path) and `light:reveal(keep)` (settles into the calm
glow behind the pet; `keep` false for Hatch All = fade out and remove). The old halo Frame, `makeRays` / `setRays`
and the reveal-time halo/rays snap are gone. `CaseOpening.burst(fx, modal, tier, opts?)`: new `opts.NoLight` leaves
out its flat flash disc and hard rays; the hatch screen passes it (sparkles and the Divine / Secret screen glow
stay); the weapon / armor case opening is unchanged. Log: NIGHT_LOG "Egg light v2"; screenshots
docs/screenshots/egg_light_v2/.

**2026-10-18 (night): THE PET'S LIGHT INSIDE THE EGG (owner: "make a emission of light during the animation in
the egg according to the rarity of the pet inside").** New `UI/EggLight` (client, VFX sub-agent):
`EggLight.new({ Holder, View, Tier, Low, Halo, Rays })`, `light:update(u, spread, dt, shell?)` every frame,
`light:peak()` at the break, `light:destroy()` in reveal / close. A ViewportFrame renders no real lights, so the
light = the cracks (new `EggCrack` `shell:glow(color, amount)`: Neon in the light's colour), the view's Ambient /
LightColor tint, an outline of 3 flat egg copies in their own ViewportFrames behind the egg, an aura (7 round frames)
and a bloom (3), sparks from Epic; it also drives the hatch screen's halo and rays (that colour code left Hatching,
and the old "tease" - gold turning to the rarity colour in the last 40 % - is gone: the colour shows from the start).
Per-rarity tuning in `EggLight.TUNE` (strength, aura, bloom, flicker, sparks/s, crack colour). `Hatching` now
computes the crack spread every frame (also on the flat path) and calls `shell:open(f)` without a colour. Low FX =
crack glow + tint + halo. Log: NIGHT_LOG "Egg light"; screenshots docs/screenshots/egg_light/.

**2026-10-18 (evening): REAL EGG CRACKING (owner: "The egg skin should crack bit by bit and then break, just like a
real egg. However, keep the egg skins").** New `UI/EggCrack` (client): reads the zone egg mesh with EditableMesh
(cached per mesh), an untextured overlay MeshPart gets crack strips (3 jagged segments per mesh edge) in the order
of a starburst + Dijkstra along the piece borders; `open(f, glow)` widens them and turns them Neon in the rarity
colour; `shatter(view)` shows prebuilt pieces (cup / 5 shards / cap: the egg's own faces + UVs + texture outside, a
cream inner shell + rims) flying in the hatch ViewportFrame. `UI/Hatching` drives it (CRACK_KEYS bursts, OPEN_FROM
0.9, breakEgg: viewport x1.9 with a widened camera, reveal 0.15 s after the break) and falls back to the old flat
cracks when `EggCrack.new` returns nil. `Config/PetRarities.HatchSeconds` 2.6 -> 3.4. Sounds (SFX sub-agent):
EggCrackSmall1-3 per burst (trimmed ProSoundEffects "Crack Egg Crunchy 5", vol 0.6), EggShellBreak at the break
(Crunchy 13, vol 0.7), preloaded by Hatching. **The place setting "Allow Mesh & Image APIs" (Game Settings >
Security) must be ON** - without it Roblox blocks EditableMesh even in Studio Play ("EditableMesh is not
accessible"); after the owner reopened the place it works in Play. A client may hold only 8 EditableMeshes at once:
a shell uses 3 (crack overlay + all pieces' outsides + all insides; the pieces move by their vertices, ~0.5 ms a
frame) and frees them when done. Log: NIGHT_LOG "Real egg cracking"; screenshots docs/screenshots/egg_crack/.

**2026-10-18: HUB / MAP POLISH (owner screenshots: misaligned tree base + mushroom, flickering Rebirth Altar stairs
and house windows, "gross" Egg Station eggs, a smoother bench you can sit on).** Plains_3 `AncientTree`
(Decor.Landmark): RootFlare + the 8 Root wedges moved under the trunk (+3.5, 0, +5.5; old position in attribute
HubFixOldPos), flare recolored like the trunk, mushroom removed. Rebirth Altar: the 3 Steps were flush with the round
Tier tops -> 0.05 stud higher. Windows: the panes of the 5 hub cottages, the Plains FarmHouse and the Tundra
Cabin_Broken sat 0.03-0.07 stud from the timber / bars -> panes now 0.12 stud out of the wall (cross bars in front).
MapAudit.zfight only checks exactly flush faces of blocks: near-flush (< 0.1) and cylinder faces need a manual check.
Egg Station: the 12 ball parts became 3 `Assets.Eggs` zone eggs (plains, desert, jungle; `DisplayEgg_<zone>`, rings
removed). Benches: models sub-agent built `Bench` (61 Parts, rounded slats / curved frame, 2 invisible `Seat`s with
CanTouch off; template `_Staging.BenchWork.Bench_Smooth`), it replaced the 11 hub `Bench_A`; new
`Services/BenchService` gives each bench one "Sit" prompt. Log: NIGHT_LOG "Hub polish"; screenshots
docs/screenshots/hub_fixes/. The map lives in the place file: the owner saves the .rbxl.

**2026-10-15: ARMOR SHOP + INVENTORY FILTERS AND MULTI-SELL (owner: "Create a shop for Armors too, same as the weapon
shop. And in the inventory for weapon, create a filter and an select option to sell many items at the same time for
each category").** Shop window tabs Weapons / Armor / Diamonds. `UI/Pages/WeaponShopPage` is now one page factory
`create(kind)` with two kinds (weapons: categories; armor: Helmet / Chest / Legs, `ModelIcon.armor` cards, turntable
preview, Max HP / Defense odds): `WeaponShopPage.build` and `.buildArmor`. Server: `ShopService` handles "BuyWeapon"
and "BuyArmor" with one `buy(player, kind, id)` (armor: storage check, own pity keys `Armor.PITY_KEYS`, price
`Armor.price` = half the zone's weapon price, auto-equip into an empty slot when the opening ends). `UI/CaseOpening`
plays weapons and armor (`itemOf(result)`: weaponId or armorId). Inventory: the shared `Kit/SellBar` (select mode,
"All", sell the ticked ones with a confirm) on Weapons (`InventoryPage`, now header + grid), Armor and Trophies;
`Kit/Filter` gained `rarityOptions()` / `zoneOptions(options, present)`. Server batch sells "SellWeapons",
"SellArmors", "SellTrophies" (skip equipped / worn / locked, max 300). Admin: setPity sets both shops, clearArmor
resets the armor pity, the Armor admin page shows it. Not tested: the phone layout of the new inventory headers (no
device emulation through the MCP). Log: NIGHT_LOG "Armor shop".

**2026-10-14 (evening): MAP FIX (owner: hollow shells, gaps, z-fighting, no entering / climbing giant trees and the
windmill).** 4 map sub-agent runs over all 12 zones + Hub with `tools/MapAudit.luau` (ServerStorage.DevTools.MapAudit:
audit, autoClose, skirt, underFill, capFan, holeScan, fixZFight, fixShadows, fill, shell, undo). Fix parts live in
`<Sub>.Decor.MapFix` (tagged, undoable), invisible no-climb shells in `<Landmark>.NoClimb` (Windmill, AncientTree,
GiantTree, FrozenTree, SwingTree, TreeOfLight, CrystalTree), walk-in meshes with collision carry `MapFixCollide`.
Facet surfaces (WedgePart "Facet") have nothing underneath: close any new one's open edges with MapAudit. Log: NIGHT_LOG
"Map fix"; screenshots docs/screenshots/map_fix/. The map lives in the place file: the owner saves the .rbxl.

**2026-10-14: COMBAT V3 + ZONE FIGHTING STYLES.** Jump attacks (`Config/Combat` AirAttacks: hang, dive timed on the hit,
landing shockwave; Ranged volley, Magic blast), dash strikes (DashAttacks: attack during / right after a roll), longer
Spear / Heavy / Ranged / Magic combos; 35 new clips, VFX (VFX.land, dives, dashes), SFX ("Land", Air / Dash). Dodge bug
fixed (the roll afterimages lay inside the ground: lifted, no Neon). Then the owner's zone styles: `Config/CombatStyles`
(12 styles, one per zone; animations (ZoneStyles + Style_<Zone>_* overlays, ground guard), VFX (Zone_<Zone> accents)
and SFX (Combat_Style_<Zone>_*) read the held weapon's zone, ctx.Zone). Owner: listen to the new combat sounds once. Contracts:
`docs/COMBAT_CONTRACTS.md` sections 8-9. Log: NIGHT_LOG "Combat V3". Test tricks in the contracts (attack key ButtonR2).

**2026-10-13: THE 84 REAL WEAPON MODELS ARE IN THE GAME (owner: "make these weapons in 3D, almost identical to the
icons").** The V2 Blender models (already built from the icons on 2026-10-12) were re-checked one by one against their
icon (`Previews/Weapons/<Cat>/<NN>_<id>_compare.png`), then imported by the owner (File > Import 3D, the 84 files of
`Blender_Exports/Weapons_ALL_import/` in one queue, preset Studio Default) and applied by
`DevTools.ApplyWeaponMeshes`: every Tool of `ReplicatedStorage.Assets.Weapons` now holds its real MeshPart
(Placeholder = false, MeshVersion = 2, grip and Tip / Base / Muzzle / Impact points from `DevTools.WeaponPoints`).
Import facts: the importer gives ONE MeshPart + SurfaceAppearance per file (the glow faces are merged into it) and
Studio Default reads the FBX as centimeters (28x too big): ApplyWeaponMeshes now rescales an import whose proportions
match, and `DevTools.WeaponGlow` (68 emissive masks, `tools/blender/weapon_emissive_masks.py`, ids in
`Blender/Weapons/weapons_emissive_ids.json`) gives the glow back (SurfaceAppearance EmissiveMaskContent, strength
1.5). Axis convention checked on the imported meshes (Roblox X = -Blender X, Y = Blender Z, Z = Blender Y). Tested in
Play: every category equips in the hand, no console error. The 84 imported models are kept in
`ServerStorage.ImportedWeapons` (can be deleted, the Tools hold their own copies). Backups
`BackUP_Files/*before_weapon_meshes_import*` / `*after_weapon_meshes_v2*`. **Save the place** (File > Save to File As).

**2026-10-13: RESPEC REFUND, NO DEATH PENALTY.** The Diamond respec of the Stats window gives back the Gold the points
cost (`Attributes.refundOf`, `StatsService` respec answers `{ Cost, Refund }`). Dying no longer costs Gold (the
ZoneService Died handler, `Economy.DeathGoldLoss` and `UI.Text.DeathGold` are gone). Details in NIGHT_LOG.

**2026-10-13: ADMIN PANEL V2 (owner: "I want to test every possibility in game").** `UI/AdminPanel` rewritten: 8 tabs
(Money, Swords, Armor, Pets, Stats, World, Gifts, Tests) with pickers (rows of buttons, the chosen one gold) and live
value lines; a button for every `AdminService` command. New commands: giveWeapons, clearArmor, givePets, rerollItems,
setAllPoints, giveAllKeys, clearBoosts, setUpgrades, save, resetProfile. When adding a feature: add its test command
to AdminService AND a button in the matching tab. Details in NIGHT_LOG and DESIGN.md section 13; screenshots
`docs/screenshots/admin_v2/`.

**2026-10-13: PET BONUS STATS, WEAPON SELLING, NEW HATCHING.** Every pet has 3 rolled items (Crown, Accessory,
Aura; own rarity + random stat; `Config/PetTraits`) that it wears (`Util/PetGear`, meshes in
`ReplicatedStorage.Assets.PetGear` - **in the place only: save it**); pet card shows Power / Worth / item cards
(`Kit/TraitCard`). Weapon Reroll removed; weapons sell for Gold (`Weapons.sellValue`, Net "SellWeapon"). Hatching
rebuilt "big and flashy" (`UI/Hatching`). Details in NIGHT_LOG and DESIGN.md (pets, weapons).

**2026-10-13: KID-FRIENDLY UI (owner: "understandable for a 5 years old, avoid text, more visual").** Realistic wood
(Blender textures `Icons/UiTex`, `Kit/Panel.wood`, `UI/WoodSkin`), 17 new "Ui" icons, pictures on every window title /
tab, and sentences replaced by pictures + numbers in every window. New kit pieces: `Kit/Chips` (icon + number),
`Kit/Info` (the (i) popup for details), `Kit/Filter` (one funnel for all filters / sorts of a list). Stats: the +
buys one point at once (no confirm). Rules in DESIGN.md "UI for young players"; screenshots `docs/screenshots/ui_kids/`.
When adding UI: no sentences on screen - a picture + number chip, a picture button, details in an (i).

**2026-10-12/13 (night): PETS V2 DONE (owner: inspired by Steal an Egg).** Plan `docs/pets_v2_plan.md`, log in NIGHT_LOG.
New species list; mutations & sizes (`Config/PetMutations`: Silver / Golden / Rainbow / Celestial, Big / Huge);
76 AI-generated cartoon pets (Studio generate_mesh) rigged by `DevTools/PetRigBuilder` and animated in code by
`Util/PetMotion` (walk / hop / fly / swim / slither / float, happy jump on kills); mutation looks `Util/PetLook`;
12 new zone eggs. The models only exist in the place (ReplicatedStorage.Assets.Pets / Eggs, ServerStorage.PetSources /
EggSources): **save the place**. To redo one pet: `PetRigBuilder.prompt(id)` -> generate_mesh (async, max 6 at once)
-> `PetRigBuilder.installGenerated()` (runs `check()`; failures go to ServerStorage._PetRejects).

**2026-10-12 (night): ENEMY RESPAWN 6 s.** `Config/Enemies.RESPAWN_SECONDS = 6` (was 2): a killed enemy comes back
6 s after its death (EnemyService). Tested in Play: first respawn at 6.04 s.

**2026-10-12 (night): ENEMY HP REDUCED.** `Config/Enemies.HP_MULT = { normal = 0.5, mini = 0.4, boss = 0.25 }` at
spawn (EnemyService:Spawn); database HP and Gold per kill unchanged (faster kills, same Gold). Zone 1: Golem 20,000 ->
5,000, mini-bosses 4,000 / 5,600 -> 1,600 / 2,240, normals -50%.

**2026-10-12 (night): ENEMY DAMAGE REDUCED (owner: easier, playable for everyone).** `Config/Enemies.DAMAGE_MULT =
{ normal = 0.5, mini = 0.2, boss = 0.06 }` multiplies every enemy hit (EnemyService attack); the database damage values
are unchanged (validateEnemies: 168 enemies, 0 mismatches). Zone 1: Golem 1,400 -> 84, mini-bosses 240 / 336 -> 48 / 67.

**2026-10-12 (night): BUG FIX "the character becomes invisible while attacking".** Camera occlusion is now
`StarterPlayer.DevCameraOcclusionMode = Invisicam` (a PLACE property, not in git: keep it when saving the place) - the
default Zoom mode pulled the camera into the head near trees / walls and the camera then hid the whole body. The
animation engine can no longer keep or write a NaN pose (accumulator reset per frame, safe normalisation, guard +
`AnimNaNSkips` attribute / one Output warning); the roll fade only undoes its own transparency. Details in NIGHT_LOG.

**2026-10-12 (evening): ATTRIBUTES REBALANCE (owner: "make each attribute level feel like a real upgrade; raise the
price per level so the max comes at the very end of the game").** `Config/Attributes`: next point = `400 x 1.1 ^ L`
(no zone factor any more; `pointCost(level)`, `costOf(level, count)`), per-point effects about x2-2.5 (Vigor +10% HP,
Mind +6% Gold, Endurance +2 Defense, damage scaling 0.08 = +9.6% for an S stat), effect texts generated from the
numbers, `Attributes.pointGain` = what the next point gives (shown in green on each row of the Attributes window).
Calibration table in docs/NIGHT_LOG.md (level ~26 per zone, 314 at the end of zone 12). `DevTools.StatsTests` 78/78.

**2026-10-12 (evening): REBIRTH (owner: "Create the rebirth functionality. Put it in the actual Rebirth Shop button.
Rename it Rebirth; one tab the rebirth menu, another tab the rebirth shop").** The menu button and window are now
"Rebirth" (window id `Rebirth`, tabs `Rebirth` / `Rebirth Shop`; the key action id stays `RebirthShop` so saved
bindings survive, hotkey Y). Rules of DESIGN.md section 4 in `Config/Rebirth` (Max 12, +3 credits, cost 10 x the
boss-gate price, `Rebirth.status(profile)`), server `RebirthService` (Net "Rebirth", `RebirthService:Wipe` = the reset,
also used by admin `wipeForRebirth`), zone unlock chain in `ZoneService:CheckRedo` (reopening zone N's boss room after
Rebirth N opens zone N + 1), UI `UI/Pages/RebirthPage`, badge = unspent credits + 1 when a Rebirth is ready. Admin:
`giveKey(zone)`, `clearKeys()`, `rebirthReady()`. Screenshots `docs/screenshots/rebirth/`.

**2026-10-12: WEAPONS V2 + HACK & SLASH COMBAT (`docs/weapons_combat_brief.txt`, live log `docs/NIGHT_LOG.md`).**
* Phase 1: the Whip & Chain category is gone (7 categories, 84 weapons; `DataService.migrate` cleans old profiles).
* Phase 2: the HUD's 3 pet slots are 3 empty SKILL slots (`Config/Skills`, `SkillService`, `SkillController`,
  `Kit/SkillSlot` with the cooldown sweep; keys Z / X / C, touch buttons around Attack). Skills come later.
* Phase 3: the 84 weapon models rebuilt from their icons (see the Part C notes below and
  `Blender_Exports/WEAPONS_IMPORT.md`); imported and applied on 2026-10-13 (entry above).
* Phase 4: combat framework by the main agent (`Config/Combat` Combos / Feel, `CombatService`, `CombatController`:
  combos, hit-stop, aim assist 15 studs, lunge, cancels, combo counter, Net "Swing" / "Impact" / "Motion"), then
  three sub-agents, each the only Studio user during its run, contract `docs/COMBAT_CONTRACTS.md`:
  animations (`Controllers/Combat/Animations` engine on the joints after the Animator + `Config/CombatAnimations`
  key-pose clips, option 2 = no assets to publish), VFX (`Controllers/VFX/*` pooled + `Config/CombatVFX` + assets
  `ReplicatedStorage.Assets.VFX.Shared_*` / `<Category>_*`), SFX (`Util/Sfx` `Sfx.combat` + `Config/CombatSfx` +
  licensed sounds in `Assets.Sounds.Combat`). Dev hooks: character `AnimDebug` / `AnimProfile`, workspace.VFX
  `Freeze` / `Profile` / `LowFx` / `Test`, SoundService `CombatSfxDebug`. ALL 7 CATEGORIES DONE (68 clips, per-category
  VFX, 115 licensed sounds), reviewed by a reviewer sub-agent and every BLOCKER / MAJOR fixed and re-verified in Play
  (Net "Combo" resync, rate booked at the due time, real knockback, point-blank shots, damage numbers after respawn).
  Screenshots `docs/screenshots/weapons_v2/combat_<category>_<step>.jpg`. Open: other players' view not testable
  through the MCP (no second client), crossbow / gun looks need the real meshes, nothing auditioned by ear.
* OWNER TO DO: (weapon FBX import done 2026-10-13) listen to the combat sounds once (`docs/SOUND_KIT.md` Combat section), File >
  Save to File As for the .rbxl. No animation to publish (procedural pipeline, option 2).

**2026-10-05 (evening): ENEMIES / NPCs / PETS (`docs/enemies_npcs_pets_brief.txt`, zones 1-4) are DONE - rule
changes, Parts A-F, final checks. NEXT STEP: the boss patterns (`docs/boss_patterns_document.txt`).**
Log with every decision and test: `docs/NIGHT_LOG.md` ("Enemies, NPCs, pets task"). Screenshots
`docs/screenshots/enemies_task/`.
* **Rules:** locked zones are black "?" silhouettes everywhere (`UI/Kit/ZoneVisibility`, `PortalController`);
  damage never depends on the zone (`Config/Balance.ZoneBoostEnabled = false` gates every Zone Boost).
* **Combat:** `Config/Combat` (shapes per category), `CombatService` (Attack / Roll / Block, `DamagePlayer`, starter
  weapon), client `CombatController` (aim, swings, shots, roll dash, block bubble, Auto-Attack HUD toggle).
* **Enemies:** `Config/Enemies` (zones 1-4 looks, AI values, loot, trophy value), `EnemyService` (spawning 10 per
  sub-zone, 10 Hz AI, AlignPosition movement, rewards), `LootService` (2/4/6% loot, head trophies, SellTrophy),
  `Lib/EnemyRigs` (part-built placeholders), client `EnemyController` (HP bars, flashes, death) + `AnimPlayer`
  (plays `Config/RigClips` on the Motor6D joints), Inventory > Trophies tab. Admin: spawnEnemy, killAll,
  validateEnemies (vs `DevTools/EnemyDatabase`, generated by `tools/gen_enemy_database.py`), simulateKills,
  dropLoot, giveTrophy, godMode, enemyHit.
* **Boss rooms:** `Config/Bosses` (Patterns = {} hooks), `BossService` (gate E solo / F team, lobby, minis, boss intro,
  HP x (1 + 0.6 (n - 1)), rewards per player with the 5% rule, keys, spectators), `UI/BossRoom`.
* **Models:** 88 creatures in Blender (`Blender/`, pipeline `tools/blender/fyd_creatures.py`, conventions in
  `Blender/README.txt`, manifest `Blender/models_manifest.csv`, FBX + JSON in `Blender_Exports/`, previews and
  lineups in `Previews/`). NOT imported yet: see `Blender_Exports/CREATURES_IMPORT.md` (owner's Bulk Import, then
  `DevTools.EnemyModels.fromImport`).
* **Hub NPCs:** `Config/NPCs`, `NPCService` (placement on the markers, prompts open the windows), client
  `NPCController` (idle, wave within 15 studs, head turn, talk).

**2026-10-05 (afternoon): MENU SYSTEMS (`docs/menu_systems_brief.txt`) are DONE - every part, A to D5.**
Live log with every decision and test: `docs/NIGHT_LOG.md` ("Menu systems task"). Screenshots:
`docs/screenshots/menu_systems/` (portal, Attributes), `pets/`, `armor/`, `menus/` (D1-D5), desktop / phone / tablet.
* **Portal rule:** a hub portal teleports straight to sub-zone 1 (`PortalController` -> Net "UsePortal"); locked
  portals are gray with a lock for that player. Zone Sign setting is off by default.
* **A - Attributes** (Stats button, window "Attributes"): `Config/Attributes`, `Util/Stats.compute` (every derived
  stat, shared by server and UI), `StatsService` (TrainAttributes, RespecAttributes, Max HP / walk speed on the
  Humanoid), `DevTools/StatsTests` (78 checks incl. pets and armor; admin runStatsTests).
* **B - Eggs & pets:** `Config/Pets` (72 species + 4 premium), `Config/PetRarities`, `PetService` (hatch, Hatch All,
  premium eggs, equip / lock / release, Equip Best, auto-sell, `grantPremium`), procedural models built by
  `DevTools/PetModels.buildAll()` into `ReplicatedStorage.Assets.Pets` / `Assets.Eggs` (in the place, not in git),
  `Kit/ModelIcon` (cached 3D icons), `PetFollowController`, `UI/Hatching`, `UI/Pages/PetsPage`. Egg odds checked by
  `DevTools/EggSim` (docs/egg_simulation.txt).
* **C - Armor & Equipment:** `Config/Armor` (36 pieces), `ArmorService`, `Util/ArmorLook` (procedural pieces on R15,
  placeholders for the future Blender armor), `ArmorVisualsController` (Show Armor setting), Inventory tabs Equipment
  (own avatar on a pedestal, slots, picker with arrows, stats) / Weapons / Armor / Pets + Eggs shortcuts / Trophies.
* **D1 Shop > Diamonds:** premium eggs, Weapon Reroll (keep new / old), Gold Boost x2 packs (`BoostService`, HUD
  `UI/BoostTimer`), skins "Coming soon". **D2 Rebirth Shop** (`RebirthShopService`). **D3 Index** (`Config/IndexBook`,
  `IndexService`, rewards per zone and tab; weapons now store their best rarity). **D4 Quests** (`Config/Quests`,
  `Config/Codes`, `RewardService` with ClaimQuest / ClaimDaily / ClaimGift / RedeemCode and
  `RewardService.progress(player, kind, n)` hooks in EnemyService, ZoneService, PetService, ShopService,
  StatsService). **D5 Team** (`TeamService.getTeam(player)` for the boss gate, invites, HUD party list).
* Admin commands added (section 8 of the brief): giveEgg, givePet, giveArmor, giveBoost, discover, simulateEggs,
  simulateQuests, setUpgrade, setPass, progressQuest, addPlaytime, setDaily, resetQuests, clearPets, clearIndex.
* MCP tips added this session: `loadstring(source)` in the Edit command bar is a quick compile check;
  `require` there may return stale cached configs (test in Play instead); mouse x/y for `user_mouse_input` =
  screenshot y - 58 (top-bar inset); if `screen_capture` times out, the display went to sleep (RenderStepped stops).
* NOT done / not testable here: real 2-player team invites, DataStore persistence (API Services off), regeneration /
  boss slayer / loot luck / trophy effects (computed, applied by the future combat step), trophies, skins, Robux
  products (ids are 0), Extra Pet Slots pass purchase (admin setPass simulates it), enemy models for the Index.

**Updated 2026-10-05 (00:40). GAMEPLAY PHASE, STEP 1 (UI) IS DONE AND WAITING FOR THE OWNER'S
REVIEW. Brief: `docs/ui_hud_brief.txt`. Do NOT start CombatService (step 2 of the brief's section 8)
until the owner says go. Screenshots: `docs/screenshots/ui_phase/` (1080p, 720p, phone, tablet).**

**Night 2026-10-05 (owner asleep, `docs/NIGHT_LOG.md` is the live log): Part A of
`docs/ui_redo_teleport_brief.txt` is done - every UI icon is a chunky glossy 3D render.**
* Pipeline: `tools/blender/fyd_icons.py` (template: ortho 3/4 camera, 4 area lights, glossy coat
  materials, post-process 14 px dark outline + soft drop shadow, 512 px PNG) + recipes
  `fyd_icon_recipes.py` / `fyd_icon_recipes2.py`. Template `Blender/Icons/_IconTemplate.blend`,
  sources `Blender/Icons/<Group>/<id>.blend`, renders `Icons/<Group>/<id>.png`, sheets in `Previews/Icons/`.
  Run inside Blender (connector): `sys.path.insert(0, "<project>/tools/blender")`,
  `I.setup_template()`, `I.make_icon(group, id, recipe)`.
* 50 icons uploaded (Studio MCP `upload_image` reads URLs, so `python -m http.server 8765` serves the
  project; batches of 5, bigger batches time out). Ids: `Icons/asset_ids.json` (`tools/icon_ids.py`)
  and `GameClient/UI/Kit/Icons.luau` (`Icons.<Group>.<id>`, `Icons.asset(id)` with aliases for the
  old ids, `Icons.preload()` at startup, `Flat = true` forces the old flat shape).
* Kit: menu tiles = wooden button with a 6 px raised base, big bobbing 3D icon, squash on press,
  bold cream label with a thick stroke; chunkier badges; window close = wood button with the red 3D X;
  touch Roll/Block use the boot/shield icons. Screenshots: `docs/screenshots/ui_redo/`.

**Night 2026-10-05, Part B (teleport menu) is done:**
* Zones button = an `Apart` menu entry with a label, stacked under the Settings gear (PC/tablet) or
  beside it (phone), so the owner's 2 x 4 grid stays intact. Hub portals now open the same window on
  their zone (`Net "OpenWindow"` event) instead of teleporting directly.
* `UI/Pages/ZonesPage.luau`: page 1 = scrollable list (Hub + 12 zones, rows 72 design units = 57 px on
  phones, states here / unlocked / locked with short requirement + lock / coming soon) and a preview
  (big diorama, name, description, boss); page 2 = Back + header + 4 cards (Teleport `go` button,
  locked with gate price, "You are here", boss card with red accent and "Boss Gate" = boss-room
  entrance, never the arena). Fade to black 0.25 s, `PortalEnter` sound, toast with the server message.
* Server: `Net.request("Teleport", zoneId, n)` in ZoneService checks zone unlock
  (`Zones.requirementText`), gate unlock (price), boss arena, combat (damage in the last
  `Zones.TELEPORT.CombatSeconds` = 5 s, tracked from HealthChanged) and cooldown (3 s). Admins skip
  arena/combat/cooldown, NOT the unlocks. Admin commands added: `lockAll`, `unlockZone(zoneId, gates)`;
  `unlockAll` and `setZone` now also open `profile.Zones`.
* Config: `Zones.TELEPORT`, `Zones.NOT_BUILT` (empty: all 12 worlds are built), `Zones.Descriptions`.
* 60 diorama icons (12 zones + 48 sub-zones, recipes `tools/blender/fyd_zone_recipes.py`), ids in
  `Icons.Zones` / `Icons.SubZones`. Tested: unlocked, locked zone, locked gate, bad request, cooldown,
  combat, Hub, Boss Gate, portal open (first build too). Screenshots `docs/screenshots/ui_redo/B*`.

**Night 2026-10-05, Part C (96 weapons in Blender) is DONE: all 8 categories x 12 zones** (details and
fixes per category in `docs/NIGHT_LOG.md`, one row per weapon in `Blender/Weapons/weapons_manifest.csv`).
* Pipeline `tools/blender/fyd_weapons.py`: `make_weapon(category, zone_index, builder)` builds the parts
  (meters, origin = grip, head along +Z), joins, scales to the category length (`LENGTH_STUDS` x 0.28 m),
  triangulates, Smart-UV unwraps, Cycles-bakes color/metalness/roughness (512 px, packed), makes
  `<id>_Main` + optional `<id>_Glow` (emissive parts), renders the icon + 3-angle preview, saves
  `Blender/Weapons/<Cat>/<NN>_<id>.blend`, exports `Blender_Exports/Weapons/<Cat>/<NN>_<id>.fbx`
  (Y up, textures embedded) and updates the manifest. `lineup(category)` makes `Previews/Weapons/<Cat>_lineup.png`.
* Builders: one module per category, `fyd_weapon_swords.py`, `fyd_weapon_spears.py`, `fyd_weapon_heavy.py`,
  `fyd_weapon_daggers.py`, `fyd_weapon_gauntlets.py`, `fyd_weapon_ranged.py`,
  `fyd_weapon_magic.py` (the Whip builder was deleted with the category)
  (`BUILDERS[zone_index - 1]`), shared parts in `fyd_weapon_parts.py`. Convention in `Blender/Weapons/README.txt`.
* Icons uploaded; ids in `Config/Weapons.luau` between `-- ICONS BEGIN` / `-- ICONS END`
  (`Weapons.ById[id].Icon`). `tools/weapon_icon_table.py` prints the table from `Icons/asset_ids.json`.
* Per-type conventions (gauntlet = one right-hand piece, ranged bow/crossbow/gun)
  are in `Blender/Weapons/README.txt`. Lineups: `Previews/Weapons/<Category>_lineup.png`.
* **2026-10-12: WEAPONS V2** - the 84 models were rebuilt from their icons (`tools/blender/fyd_weapons2.py`,
  `fyd_w2_parts.py`, builders `fyd_w2_<category>.py`, runner `run_weapons2.py`; compare sheets
  `Previews/Weapons/<Cat>/<NN>_<id>_compare.png`; V1 files in `BackUP_Files/old_weapon_models_2026-10-12/`). The .blend
  and .fbx files were replaced in place; measured points in `Blender/Weapons/weapons_v2_points.json` ->
  `tools/WeaponPoints.luau` + `tools/WeaponBounds.luau` (DevTools).
* The FBX files were imported on 2026-10-13 (`Blender_Exports/WEAPONS_IMPORT.md`: File > Import 3D, then
  `require(game.ServerStorage.DevTools.ApplyWeaponMeshes)()`, which swaps each mesh into the existing Tool
  `ReplicatedStorage.Assets.Weapons.<WeaponId>`, keeps attributes + grip rotation and rebuilds Tip / Base / Muzzle /
  Impact attachments).

**Owner request 2026-10-05 (noon): "Zone Sign" setting (Settings > Display, default on) hides the top-center zone
banner (the Zone Boost badge takes its place; the title card when entering a sub-zone still shows). On PC (no touch
screen) the Zones button is a wide wooden button in the bottom-right corner (`Config/UI` `CornerButton`, menu entry
`PcCorner`); tablets and phones keep the square tile next to the Settings gear (their bottom-right holds the action
buttons). Screenshots `docs/screenshots/ui_redo/E1-E4`.**

**2026-10-05: WEAPON SHOP + CASE OPENING + WEAPONS IN-GAME (docs/weapon_shop_brief.txt) are done** (details,
decisions and tests in `docs/NIGHT_LOG.md`, screenshots `docs/screenshots/weapon_shop/`).
* Configs: `Config/WeaponCategories`, `Config/WeaponRarities` (8 tiers + pity 30/100 + announcements),
  `Config/Weapons` (Id, Name, Category, Zone, ZoneId, Icon, Element; ByCategory; price(zone) = 1000 x 10^(zone-1)),
  `Util/Stats` (zone base x category x rarity), Settings `FastOpen`, Profile `PityLegendary`, Config/UI `WeaponShop`
  and `CaseOpening`.
* Server: `ShopService` (Net "BuyWeapon": checks, Gold, roll with pity, item + Index, save, reply; one opening at a
  time; toast / auto-equip of a first weapon / Mythic+ announcement sent at the reveal via Net "OpeningDone" or a
  timer; full undo + refund on failure; `ShopService.roll` is pure), `WeaponService` (Net "EquipWeapon", Tool with
  Uid/Rarity + rarity light/outline, re-given on respawn). Admin: lockZone, giveWeapon, forceRarity, setPity,
  resetWeapons (+ an Admin panel "Weapons" tab).
* Client: `UI/Pages/WeaponShopPage`, `UI/CaseOpening`, `UI/Pages/InventoryPage`; Kit/Window has a phone layout.
* Tools: 84 PLACEHOLDER Tools (96 before the Whip removal) in `ReplicatedStorage.Assets.Weapons` until the FBX import; then
  `require(game.ServerStorage.DevTools.WeaponTools).fromImport(folder)` (see Blender/Weapons/README.txt).
  `DevTools.WeaponRollSim` = the 100,000-roll check (`docs/weapon_roll_simulation.txt`).
* NOT done (not in this brief): damage/combat with the weapon, diamond reroll, salvage, weapon lock.

**Owner request 2026-10-05 (morning): the health bar shows the player's avatar headshot instead of the heart**
(`UI/HealthBar.luau` `makePortrait`: `rbxthumb://type=AvatarHeadShot`, round, gold ring, overlapping the panel's
left end like the currency icons). Test players without an account (UserId <= 0) keep the heart.
Screenshots `docs/screenshots/ui_redo/C1_desktop_health_portrait.jpg`, `C2_phone_health_portrait.jpg`.

**Owner decision 2026-10-05: the "Training" menu button and window are now "Stats". The Stats window
will hold the WHOLE RPG system (HP, Attack, Defense, Speed, Crit, Gold Gain, their upgrades and the
derived stats); see DESIGN.md section 3. Step 3 of the brief's plan is therefore "Stats window +
StatsService". For now the Stats window is a shell with an intro line (`Config/UI Windows.Stats`).**

What was built (all in `src/`, mirrored from Studio):
* **Plumbing.** `GameSystem/Net.luau`: one RemoteFunction `Request` and one RemoteEvent `Send`
  dispatched to `Net.handle(action, fn, minInterval)` handlers (per-player rate limit ->
  `false, "Too fast"`; unknown -> `false, "Unknown action"`; handler error -> `false, "Server error"`
  + warn); server -> client events `Net.EVENTS = { "Data", "Notify", "Hit" }` with
  `Net.fire / fireAll / on`. A second copy of Net (command bar) reuses the live remotes.
  `DataService`: profile from `Config/Profile.luau` (DESIGN section 11), session-locked UpdateAsync,
  autosave 90 s, save on leave + BindToClose; without API access it falls back to memory with ONE
  warn. Requests `GetProfile` and `SetSetting(key, value)` (validated by `Config/Settings.validate`).
  Client `State.luau`: `get`, `changed`, `observe`, `waitReady`. `AdminService` handles
  `Net.request("Admin", cmd, ...)` (setGold, addGold, setDiamonds, addDiamonds, notify, setZone,
  unlockAll, equipWeaponFake, equipArmorFake, equipPetFake, clearEquipment, damageSelf, heal, setBadge).
  `RewardService` is a stub (`RedeemCode` -> "Codes are not available yet").
* **New configs:** `Config/Rarities, Weapons (84), Economy, Products, Settings, Profile, Audio, UI`.
* **UI Kit** (`GameClient/UI/Kit/`): Theme (colors, fonts, screen scaling), Panel, Button, IconButton,
  Bar, Slot, Tabs, Slider, Toggle, Badge, Toast, Window, Icons (placeholder shapes; put image ids in
  `Icons.Assets`), Screens.
* **HUD** (`GameClient/UI/`): HealthBar (+ low-HP vignette, hides CoreGui Health/Backpack), Currencies
  (restyled 00:50 on the owner's reference image: Gold and Diamonds bars stacked at the top-right on
  every device, a big round icon over the left end of a dark wooden pill, white amount with a dark
  stroke that shrinks to fit, "+" end cap; Gold is longer (270 vs 200 design units) so "999.99Qa"
  fits; tapping a bar opens the Shop on its tab, Gold -> Weapons, Diamonds -> Diamonds; sizes and
  tabs in `Config/UI` `Currencies`; count-up, pop, and a +/- float left of the bar. On phones the
  Menu button and the admin crown moved under the health bar; screenshots 14-17), ZoneBanner (+ 2 s title card +
  Zone Boost badge "Weapon + n/3 Armor"), Equipment (weapon + 3 pet slots), MenuBar (owner's choice
  01:00, after a reference photo: 8 buttons in a 2-wide x 4-tall grid filled row by row on PC and
  tablets; Settings is `Apart = true` in `Config/UI Menu` and shows as a gear right of the health bar
  (health bar now 270 wide, `Config/UI Hud.Health`); phones keep the Menu pop-up, now the same 2 x 4
  grid, with the gear beside the Menu button; screenshots 18-20. Owner, 01:10: on PC (no touch) the
  tiles are 40% bigger (`MenuGrid.PcTile` 80) and the grid sits at the vertical middle of the left
  edge; screenshots 21-23. Owner, 01:20: tablets centered vertically too (tile size unchanged);
  screenshot 25), Notifier (queue, merge "x2", rarity glow, error shake), Windows (9 shells + Shop "Get
  diamonds" confirm -> GoToHub), Pages/SettingsPage (Audio, Display, Controls, Other), AdminPanel
  (crown button / F2: Money, Teleport, UI Test tabs).
* **Controllers:** SettingsController (applies locally, saves debounced via SetSetting; volumes go to
  the SoundGroups Master > Music/PlayerFX/EnemyFX/UI/Ambient), ControlsController (CAS binds + touch
  Attack/Roll/Block buttons + layout editor), FxController (LowFx, screen shake).

Phone top bar lift (owner, 01:20): in the compact layout the zone banner + Zone Boost badge and the
currency bars move up into the Roblox top bar strip, which is free right of the Roblox buttons
(`Theme.topbarLift(leftX)` reads `GuiService.TopbarInset`; it returns 0 when a piece would reach the
Roblox buttons). ZoneBanner publishes the bottom of its stack as the `TopCenterBottom` attribute on
the HUD root and the toasts stack under it. Finger taps reach the lifted bars (hit-testing checked),
but gamepad selection skips pieces that sit entirely in the strip (the Gold bar on phones), because
they are outside the HUD ScreenGui's bounds. Screenshot 24.

Scaling rule: every ScreenGui comes from `Theme.screen()`; its `Root` is in design units with a
UIScale `s = clamp(safeHeight/660, 0.6, 1.4) * UiScale` (min 0.8 on touch); compact (phone) layout
when the design height is under 520. UITextSizeConstraint sizes are screen pixels, so always create
them with `Theme.limit(label, max, min)` (it rescales them with the UI).

Tested 2026-10-05 in Studio Play (device simulator: HD 1080, HD 720, iPhone 17 Pro and iPad 10th gen,
landscape): no HUD overlaps (checked by code and by eye), touch targets >= 44 px, Format everywhere
(1.23Qa, 2.5B, 12.5K), gold/diamond animations, health bar + vignette with damageSelf, toast queue +
merge, badges, Zone Boost on/off, all 9 window shells, Settings (Master slider -> SoundGroup 0.4 live
and stored on the server; toggles; UI Scale live; layout editor Bigger + Done saved), Get diamonds ->
Hub. Output clean except the expected API Services warnings. NOT tested: persistence across rejoin
(API Services is off in Studio), real touch gestures (dragging the touch buttons; the simulator was
driven with GuiService.SelectedObject + Enter), gamepad.

MCP testing tips learned: `execute_luau` gets FRESH copies of ModuleScripts (State/Window/Notifier
state is not visible from it; read the GUI instances instead, or fire events from the Server
datamodel); `user_mouse_input` x/y are GUI coordinates (top-bar inset excluded) and clicks do not
reach GUI under the touch simulator; `screen_capture` can show a frame a few seconds old.

**Earlier (00:00). THE WORLD IS COMPLETE: Hub + all 12 zones are built, validated and
checked in Play, each with its kit catalog (`docs/ASSET_KIT_*.md`), lighting presets and a boss
arena in `ServerStorage.BossArenas` (12 arenas). Zone 12 (Void) was the last: 11,728 parts + arena
1,578; its arena floor is 8 pie sections (`FloorSections/Section1..8`) over an invisible `SafetyNet`
for the Void Collapse pattern. Next phases per the owner's plan: (1) real enemy and boss models
(Blender -> owner's 3D Importer), (2) full gameplay scripts. Open: owner review, Blender landmarks
for Heaven and zones 9-12, owner's landmark import, sounds never auditioned.**

**Earlier (22:55). Zone 11 (Mechanical City, id `Mechanical`) is built (4,756 parts +
arena 643), validated and checked in Play (all 4 sub-zones + arena readable; sub-zones 2-4 are
light on parts but clean, more dressing optional). The owner changed Claude and GitHub accounts
on 2026-10-04: pushes still go through the Miieski credential (fallback account: KodElse); the
Roblox_Studio MCP had to be re-added to the session. Remaining: zone 12 (Void).
Catalog: `docs/ASSET_KIT_MECHANICAL.md`.**

**Earlier (20:20). Zone 10 (Abyss) is built (10,854 parts + arena 611), validated and
checked in Play (Coral Reef, Abyssal Trench, boss arena: readable; Abyss_2 and Abyss_4 not seen in
Play). It is a DRY underwater zone: players walk, there is no water volume (per the zone doc's tip).
Remaining: Mechanical, then Void. Catalog: `docs/ASSET_KIT_ABYSS.md`.**

**Earlier (19:50). Zone 9 (Realm of the Dead, id `Dead`) is built (9,851 parts + arena
1,062), validated and checked in Play (Graveyard, Ossuary hall, boss arena: readable; Dead_3 and
Dead_4 not seen in Play). The owner said GO for zones 9-12 on 2026-10-04: remaining order is
Abyss, Mechanical, Void, one builder at a time, each followed by a Play check, this file, a backup
and a push. Catalog: `docs/ASSET_KIT_DEAD.md`.**

Earlier (19:10): Hub + zones 1-8 are built, validated (0 FAIL lines, 69,177 zone parts)
and walked in Play. Zones 6-8 (Volcano, Hell, Heaven) were walked on 2026-10-04 evening with the
admin teleport buttons: Volcano 1-3 + arena, Hell 1, 2, 4 + arena, Heaven 1, 3, 4 + arena all read
well in Play (no glare in Heaven, Hell dark but readable). NOT seen in Play: Volcano_4 itself,
Hell_3, Heaven_2. Fix made after the walk: placeholder enemy tints for Hell (bone white) and
Heaven (blue), which blended into their zones. WAITING for the owner's review: do not start
zones 9-12 until they say go. Zones 9-12 (Dead, Abyss,
Mechanical, Void) only have folders and markers and must NOT be started until the owner says go.
The admin panel also has teleport buttons for every zone (sub-zone 1-4 or the boss arena).
`Blender_Exports/` now has 29 FBX (Hub + zones 1-7); the 4 Heaven landmarks are not made yet.**

**Owner's working rules (2026-10-04):** only ONE builder agent at a time; after each finished zone
update this file, take a backup and push to GitHub; never press Play while a builder runs; after
Heaven, walk Volcano / Hell / Heaven in Play, fix, then stop and report.

Earlier note (afternoon of 2026-10-04): World build in progress: Hub + zones 1-5 (Plains, Desert, Jungle,
Tundra, Swamp) are built, validated and walked in Play; zones 6-12 (Volcano ... Void) only have
their folders and markers. Each built zone has its kit catalog (`docs/ASSET_KIT_*.md`), its boss
arena in `ServerStorage.BossArenas`, and lighting presets in `ReplicatedStorage.Assets.Lighting`.
An admin panel (F2 or the ADMIN button; `Config/Admins.luau`) adds/sets Gold and Diamonds and
unlocks all gates. `Blender_Exports/` holds 25 landmark FBX (Hub + zones 1-6) waiting for the
owner's import; the maps use part-built stand-ins (`Decor.Landmark`, attribute `LandmarkName`).
Known gaps: see `docs/QC_REPORT_1.md` (Hub + Plains only; zones 2-5 have had no QC agent pass),
boss-arena fights beyond entry are untested, sounds were never auditioned by ear.**

Earlier note (morning of 2026-10-04): Hub + Plains built and playtested.

Owner decisions (2026-10-03): build the world for all 12 zones first (maps, props, lighting, VFX,
sounds) with ONE placeholder dummy enemy; real enemy and boss models come after the 12 worlds;
the full gameplay scripts come last. Blender work is exported to `Blender_Exports/` and imported
by the owner with Studio's 3D Importer (landmarks first, then enemies and bosses).

In the place now:
* `workspace.Hub` (4,167 parts): spawn, 12 zone portals, 10 stations, 5 leaderboards, AFK zone.
* `workspace.Zones.Plains` (4 sub-zones, about 10,300 parts) and `ServerStorage.BossArenas.Plains`.
  The other 11 zones only have their folders and markers (`Area`, `Entrance`, `Spawns`, ...).
* `ServerStorage.MapAssets`: kit of 104 models (Common, Plains, Hub, Gates) + 33 VFX prefabs;
  `ReplicatedStorage.Assets`: 14 combat VFX and 11 lighting presets (Hub, Plains, Desert, Jungle).
  Catalogs: `docs/ASSET_KIT_A.md`, `docs/VFX_KIT.md`.
* Minimal playable layer (PLACEHOLDER, in `src/`): hub portals, return pads, per-player sub-zone
  gates paid with Gold, location tracking with pushback from locked areas, one dummy enemy tinted
  per zone with real HP/Gold, hold-to-attack test sword, lighting and music switching, Gold HUD,
  solo boss-arena visit. No DataStore (session memory only), no enemy AI, no real weapons.
  Playtested 2026-10-04 on Hub + Plains: portal, combat, Gold, the 3 gates, pushback, cave lighting
  and arena entry all work. NOT tested: mini-boss -> boss sequence, leaving by the arena door,
  death/respawn, mobile, 2+ players.
* `Blender_Exports/`: 13 landmark FBX (Hub + zones 1-3) waiting for the owner's import; see its README.

How the tooling works (read `docs/AGENT_BRIEF.md`):
* Backups: `require(game.ServerStorage.DevTools.Backup)("label")` in Studio, then
  `python tools/collect_backup.py --wait 15` -> verified `.rbxm` files in `BackUP_Files/`.
* Scripts are edited in Studio through the MCP and mirrored to disk with
  `require(game.ServerStorage.DevTools.ExportScripts)()` + `python tools/pull_scripts.py`.
  Rojo (`default.project.json`) pushes the other way: pull before you connect it.
* `ServerStorage.DevTools.BuildKit`: palettes for all 12 zones, faceted-terrain helpers, contract
  validators (`validateHub`, `validateZone`, `validateArena`).
* Sub-agents: at most 2 at a time. Three at once exhausted the owner's usage limit twice.

Earlier status (design phase), kept for reference:

Done:
* Zone list, sub-zones, bosses and progression order.
* Full stat tables for all enemies, mini-bosses and bosses (`docs/enemy_database.txt`),
  including loot rarity rules and the diamond system.
* Zone look-and-feel document for all 12 zones (`docs/zone_design_document.txt`).
* Boss pattern document with tools and workflow (`docs/boss_patterns_document.txt`).
* GitHub README, Rojo project file and `.gitignore`.

Not done yet (suggested order):
1. **Phase 0-1 systems:** Rojo repo set up, `Net` module, DataStore profile (coins, diamonds,
   zone progress, rebirths, inventory), coin HUD.
2. **Combat:** weapon + damage + cooldown, enemy base class (HP, simple AI, death, rewards),
   enemy spawner with respawn, damage numbers.
3. **Zone progression:** sub-zone gates with coin prices, teleports, boss room entry/lock.
4. **Plains, fully playable:** map, 2-3 enemy types per sub-zone, 2 mini-bosses, Golem boss.
5. **Rebirth loop:** Rebirth button, bonuses, unlocking Desert, then test the full loop with friends.
6. **Loot and diamonds:** loot drops, inventory, diamond drops, Robux diamond shop.
7. **Remaining zones** one by one (Desert and Jungle first, then publish a first version).
8. **Balance pass:** pacing target of about 10-15 minutes per sub-zone and about 1 hour per zone.

### Known open questions / risks
* Numbers grow x10 per zone, so the late game reaches 10^15 (use `Format` helpers with
  K/M/B/T/Qa suffixes). Lua numbers are doubles (exact to about 9e15), so very late values may
  need a big-number approach later; consider capping or rebalancing growth.
* The player's HP and weapon damage must follow the same curve as enemy HP/damage, otherwise
  late zones are impossible. This still has to be designed (levels, weapon tiers, rebirth bonus).
* Abyss zone: swimming mechanics are complex; consider a dry "underwater dome" look instead.
* Sub-zone unlock prices are not defined yet (suggestion: about x2.5 per sub-zone).
* Rebirth bonus values and the diamond shop uses (eggs, pets, boosts, skins) are not defined.
* Diamond pack prices in `enemy_database.txt` are placeholders.

### Manual items for the owner (keep collecting, give at the very end)
* Save the place (Ctrl+S); map/assets live only in the place file.
* Game Settings -> Security -> enable **API Services** for Studio DataStore testing.
* Create the game passes and Developer Products, then put their IDs in `Config/Products.luau`
  (Passes incl. ExtraPetSlots, DiamondPacks, PremiumPets) and wire the receipts to `PetService.grantPremium`.
* The pet / egg models (`ReplicatedStorage.Assets.Pets`, `Assets.Eggs`) only exist in the place: save it. To rebuild
  them: `require(game.ServerStorage.DevTools.PetModels).buildAll()` in the command bar (Edit mode).
* Test teams with 2+ players (Studio Test > Clients and Servers): invite, accept, kick, leader leaving; also a boss
  room with 2-5 players ("Enter with team", HP scaling, spectators, the 5% reward rule).
* Import the 13 prop FBX files: `Blender_Exports/Props/PROPS_IMPORT.md` (File > Import 3D, Studio Default,
  Merge Meshes OFF), then `print(require(game.ServerStorage.DevTools.ApplyPropMeshes:Clone()).run())`, then save.
* Import the 88 creature FBX files: `Blender_Exports/CREATURES_IMPORT.md` (Bulk Import in meters, then
  `require(game.ServerStorage.DevTools.EnemyModels).fromImport(folder)`), then save the place.
* Codes live in `Config/Codes.luau` (WELCOME, DESTINY, BOSSKEY); add or remove codes there.
* Set the admin UserId(s) in the admin config (owner account only).
* Copy `.rbxl` backups to a cloud drive or external disk.
* Remove any dev-only tools or test commands before publishing.
* Check that all Toolbox assets used are cleaned of scripts and are properly licensed.

## 6. Style of the owner

French-speaking; asks for documents and plans in English, and for explanations in French.
Direct and practical: wants step-by-step instructions and finished files rather than long theory.
Likes big, juicy combat feedback. Expects things to be tested before being called done. Keep
status updates short and concrete, and give the manual steps they must do themselves in a clear
list.
