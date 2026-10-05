# Night log - 2026-10-05 (overnight autonomous task)

Owner's overnight order: Part A (UI redo with 3D icons), Part B (teleport menu), Part C (96 weapons
in Blender). The owner is asleep: no waiting for approval, decisions are logged here.

## Status (newest first)

- 03:43 PART C DONE - WHIP & CHAIN category pushed: ALL 96 WEAPONS ARE MADE. Builders
  `tools/blender/fyd_weapon_whips.py` (handle + S-curved lash or chain, 6 studs; shared `path()`, `lash()`,
  `chain()` with alternating links; 952-1936 tris). Each whip checked on its preview; fixes: lashes 1.3x
  thicker, bigger leaves / flowers / vertebrae / segments, gold rings sized to the lash, bigger chain links
  (Frozen Chain was 2904 tris, now 1816), Soul Chain hook and Rift blade turned to face the camera.
  Lineup `Previews/Weapons/Whip_lineup.png`. All 96 icons uploaded; `Config/Weapons.luau` ICONS has 96/96
  (checked with a fresh require: no weapon without an icon). Manifest: 96 rows, every weapon within budget.
  Next: none for Part C - the FBX files wait for the owner's Bulk Import.

- 03:36 PART C - MAGIC category done and pushed (84/96). Builders `tools/blender/fyd_weapon_magic.py`
  (6 studs = 1.68 m staffs, head on top along +Z, origin at the grip; 1080-2126 tris of the 4000 budget).
  Each staff checked on its preview; fixes: shorter shaft for all staffs so the heads read at icon size,
  Apprentice orb, Sandstorm vortex thicker, Shaman totem head 1.4x, Blizzard saturated cyan glow,
  Eruption volcano bigger, Infernal Tome rebuilt as an OPEN book with runes, Lich skull + crown bigger,
  Void orb/orbits bigger. Lineup `Previews/Weapons/Magic_lineup.png`. Icons uploaded (84 ids). Next: Whip
  & Chain (`fyd_weapon_whips.py`, 6 studs handle part) - last category.

- 03:29 PART C - RANGED category done and pushed (72/96). Builders `tools/blender/fyd_weapon_ranged.py`
  (5 studs = 1.4 m; shared bow / crossbow / gun parts; 680-1486 tris). Conventions per type written in
  `Blender/Weapons/README.txt` (bows: limbs on Z, string -X; crossbows: bolt +Z, prod across X; guns: muzzle
  +Z, grip -X). Each one checked on its preview; fixes: bow limbs drawn 1.35x thicker + deeper curves (thin
  bows vanished in the icon), Blowgun feathers/vial bigger, Frostbite crystals, Plague Bow made distinct
  (bone hooks, rag, toxic drips), Flame Bow veins on the front, Dawn Bow scalloped wings, Bone Crossbow
  skull/prod, Harpoon Gun thicker + barnacles, Starfall Bow crystals. Lineup
  `Previews/Weapons/Ranged_lineup.png`. Icons uploaded (72 ids). Next: Magic (`fyd_weapon_magic.py`,
  6 studs, budget 4000).

- 03:21 PART C - GAUNTLET category done and pushed (60/96). Builders `tools/blender/fyd_weapon_gauntlets.py`
  (1.8 studs = 0.5 m, ONE right-hand gauntlet: origin = fist center, knuckles +Z, cuff -Z, back of the
  hand -Y; shared `fist()` / `cuff()` parts; 1104-1726 tris of the 4000 budget). Convention added to
  `Blender/Weapons/README.txt`. Each one checked on its preview; fixes: Leather Knuckles (no skin-tone
  fingers, darker leathers), Desert Wraps cloth fingers, Jaguar Claws rosettes, Mud Fists darker mud +
  lumps, Magma cracks, Angelic wings swept back (they were wider than the gauntlet was long).
  Lineup `Previews/Weapons/Gauntlet_lineup.png`. Icons uploaded (60 ids in `Config/Weapons.luau`).
  Next: Ranged (`fyd_weapon_ranged.py`, 5 studs).

- 03:15 PART C - DAGGER category done and pushed (48/96). Builders `tools/blender/fyd_weapon_daggers.py`
  (2 studs = 0.56 m, 0.16 m grip + ~0.3 m blade before scaling, 560-1340 tris). Each dagger checked on
  its preview; fixes: Hunter's Knife detail (was 328 tris, under the brief's 500 minimum), Venom Fang
  cream ivory, Ice Shard core visible + dark grip, Toad Tooth made distinct from the Venom Fang (barbs,
  slime, warty collar), Feather Dagger barbs/vane, Ghoul Fang (deeper serration, ribs, skull), Nano
  Dagger enriched for zone 11 (circuits, emitters, power cell). Lineup `Previews/Weapons/Dagger_lineup.png`.
  Icons uploaded, ids in `Config/Weapons.luau` (48 icons). Next: Gauntlet (`fyd_weapon_gauntlets.py`,
  1.8 studs, one hand, budget 4000).

- 03:09 PART C - HEAVY category done and pushed (36/96). Builders `tools/blender/fyd_weapon_heavy.py`
  (5 studs = 1.4 m, head centered 0.82 m above the grip before scaling, 764-1682 tris). Each weapon
  checked on its preview; fixes: Stone Hammer darker stone, Obelisk Hammer contrast (sandstone vs gold),
  Glacier Axe (dark haft, bearded blade, outer glow edge), Swamp Maul (moss, mushrooms, tones), Lava
  Hammer (rough obsidian, zig-zag cracks), Doom Axe horns, Judgment Hammer (feathered wings, gold core,
  halo), Gravedigger's Maul (chains, bigger skull/cross), Kraken Anchor (thicker), Hydraulic Hammer
  (bigger head, exhausts), Void Maul (bigger crystal head, tilted orbit). Lineup
  `Previews/Weapons/Heavy_lineup.png`. Icons uploaded, ids in `Config/Weapons.luau` (36 icons).
  HANDOFF.md now has a Part C section. Next: Dagger (`fyd_weapon_daggers.py`, 2 studs).

- 02:59 PART C - SPEAR category done and pushed (24/96). Builders `tools/blender/fyd_weapon_spears.py`
  (shared shaft/socket/ring/butt-cap/grip-wrap parts, 8 studs = 2.24 m, 694-1256 tris). Each spear
  checked on its preview; fixes: leaf head rebuilt (was a sliver), thicker shaft + 8 px outline so
  the long thin icons stay readable, Desert needle, Swamp head, Volcano lava rings, Hell crescent
  halberd, Heaven wider blade, Void rebuilt (faceted crystal blade + orbit ring). Lineup
  `Previews/Weapons/Spear_lineup.png`. Icons uploaded, ids added to `Config/Weapons.luau` ICONS.
  Next: Heavy (`fyd_weapon_heavy.py`, 5 studs).

- 02:49 PART C - SWORD category done and pushed (12/96). Pipeline `tools/blender/fyd_weapons.py`
  (build -> join -> triangulate -> Smart UV -> Cycles EMIT bakes of color/metalness/roughness 512 px
  packed -> 3-angle preview -> .blend -> FBX (Y up, meters, textures embedded) -> icon -> manifest).
  Pilot 01_plains_sword checked first (FBX re-import: 1.26 m, upright, 3 textures). Convention in
  `Blender/Weapons/README.txt`. Each sword checked on its preview before the next; fixes: Dead sword
  enriched, Abyss fuller removed. Lineup `Previews/Weapons/Sword_lineup.png`. Icons uploaded, ids in
  `Config/Weapons.luau` (ICONS table, `Weapons.ById[id].Icon`). Next: Spear.

- 02:40 PART B DONE and pushed. Teleport menu (page 1 list + preview, page 2 sub-zone cards, fade,
  toasts), server-validated `Teleport` request, hub portals open the menu, 60 zone/sub-zone diorama
  icons uploaded. Tested every state with admin commands at 1080p and phone. Next: Part C weapons
  (Sword pilot first).

- 02:08 PART A DONE and pushed. 50 icons uploaded (45 + Skull, Info, Warning, Crown, MenuLines so no
  flat placeholder is left in the HUD); ids in `Icons/asset_ids.json` and `UI/Kit/Icons.luau`.
  Kit restyled (menu tiles, badges, close button, touch buttons, currency icons, toasts).
  Tested at 1080p, phone, tablet; Output clean. Screenshots `docs/screenshots/ui_redo/`.
  Next: Part B (teleport menu).

- 01:55 Part A icons: all 45 rendered with the shared template (`Blender/Icons/_IconTemplate.blend`,
  sources `Blender/Icons/<Group>/<id>.blend`, PNG `Icons/<Group>/<id>.png`, sheet
  `Previews/Icons/PartA_all.png`). Gold coin pilot checked first, then groups checked on contact
  sheets; fixes made: shop awning, roof color, world light (washed-out reds), boot wing, spear,
  dagger taper, whip handle, magic orb. Next: upload, Icons.luau, Kit restyle.

- 01:25 Started. Read the briefs. Blender 5.2 connector OK (interactive, EEVEE). Studio upload tool
  takes image URLs, so icons are served from a local `http.server` on 127.0.0.1.

## Plan / resume pointer

1. Part A: icon pipeline (`tools/blender/fyd_icons.py`) -> template -> Gold coin pilot -> all A icons
   -> upload -> `Icons.luau` ids -> Kit/HUD/menu/pills restyle -> tests 1080/720/phone/tablet -> push.
2. Part B: Zones button + teleport window (page 1/2) + server `Teleport` + fade + 12 zone and 48
   sub-zone icons -> tests -> push.
3. Part C: weapons, category by category (Sword pilot first), manifest
   `Blender/Weapons/weapons_manifest.csv`, push after each category.

## Decisions taken without the owner

- The brief's menu icon "Training" is made as "Stats" (bar chart + rising arrow), because the owner
  renamed the Training window to Stats on 2026-10-05.
- Icon outline is done in post (alpha dilation 14 px + soft drop shadow) instead of Freestyle, so
  every icon gets the same thick dark outline regardless of the model.
- The Diamond keeps the game's cyan (DESIGN: Diamonds #5FD4FF), not the reference's purple.
- Zones button is an extra "Apart" button under the Settings gear (with a label) so the owner's 2 x 4
  grid stays as chosen.
- Zone and sub-zone icon ids live in `UI/Kit/Icons.luau` (Icons.Zones / Icons.SubZones) like every
  other icon id, not in Config/Zones (the two briefs disagreed; Part A says ids only in Icons.luau).
- Admins skip arena/combat/cooldown checks but NOT the unlock checks (so the owner can test locked
  states with an admin account; `lockAll` / `unlockZone` / `unlockAll` change the unlocks).
- Hub portals now open the teleport menu on their zone instead of teleporting directly (brief).
- Gauntlets are modeled as ONE right-hand piece (the brief says "pair, one per hand"): the left one is the
  same mesh mirrored in Studio, so the pair always matches and the file count stays 12 per category.
- Whip & Chain (brief: "6 studs, handle part") are modeled as the handle + a rigid S-curved lash/chain,
  6 studs in total, so the icon and the held weapon read as a whip; a physical rope/Beam can replace the
  lash in Studio later (written in Blender/Weapons/README.txt).
- Ranged: one convention per type (bow / crossbow / gun) instead of one for all, so each icon shows its
  best side (README). Long thin parts (bow limbs, lashes, spear shafts) are drawn thicker than real.
- Weapon icon outline width is per category (Sword 14 px, Spear 8, Heavy 11, Dagger 14, Gauntlet 14,
  Ranged 9, Magic 9, Whip 10): a 14 px outline swallowed the thin spear shafts at 512 px.

## Problems

- 02:35 Studio stopped receiving synthetic input and `screen_capture` times out (the PC display
  probably went to sleep). The Part B tablet screenshot is missing (desktop and phone are done).
  Studio and Blender still run scripts.
