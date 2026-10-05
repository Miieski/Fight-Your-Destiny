# Night log - 2026-10-05 (overnight autonomous task)

Owner's overnight order: Part A (UI redo with 3D icons), Part B (teleport menu), Part C (96 weapons
in Blender). The owner is asleep: no waiting for approval, decisions are logged here.

## Status (newest first)

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

## Problems

- 02:35 Studio stopped receiving synthetic input and `screen_capture` times out (the PC display
  probably went to sleep). The Part B tablet screenshot is missing (desktop and phone are done).
  Studio and Blender still run scripts.
