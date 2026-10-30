# Weapon overhaul: implementation plan (main agent, 2026-10-30)

Owner prompt: `docs/Weapon_Overhaul/PROMPT_WEAPON_OVERHAUL.txt`. It wins over this file. This file records how the prompt
maps onto the code that already exists. The existing combat stack is good: EVOLVE IT, do not rewrite it.

## What already exists (read before changing)

- `Config/Combat.luau`: shapes, combos, jump attacks (`AirAttacks`), dash strikes (`DashAttacks`), Feel.
- `Services/CombatService.luau`: `Attack` / `Roll` / `Block`, server-timed impacts, shapes, "Swing" replication.
- `Controllers/CombatController.luau`: inputs, prediction, lunge, plunge, feedback.
- `Controllers/Combat/Animations.luau` + `Config/CombatAnimations.luau`: procedural keyframe clips written to the R15
  joints on every client, with IK, cross-fades, `Hit` markers, zone styles. This IS the procedural, no-upload,
  multiplayer-visible pipeline the prompt asks for. Keep it; author new clips in its format.
- `Controllers/VFX/*`, `Util/Sfx`, `ControlsController` (movable touch buttons), `SkillController` + `Config/Skills`
  + `Services/SkillService` (empty framework, 3 slots).
- `docs/COMBAT_CONTRACTS.md`: the call order. Update it.

## Name mapping (do not rename ids: saves, assets and clips use them)

Hammer = `Heavy`, Bow = `Ranged`, Staff = `Magic`. UI text may stay as today. Crossbow / gun styles of `Ranged` keep
their clips and get the bow mechanics. Every `Magic` weapon is a "fire staff": same fireball and burn, core flame
always orange, trail / glow tinted by the weapon element (log it).

## Decisions

- **Tap vs hold, melee:** the press starts the light step at once (no waiting, so the start-up target holds). If the
  button is still down after `HoldThreshold` (about 0.22 s) the swing flows into the heavy wind-up; release or full
  charge fires the heavy. **Bow / staff:** the press starts the draw; a release before `HoldThreshold` fires the quick
  shot at max(release, press + quick delay of about 0.1 s); holding longer charges, and the release fires the charged
  shot. Auto-Attack (pass) keeps working through the light path.
- **Buffering:** a press in the last 35 % of a swing queues the next step. Holding no longer auto-chains.
- **Cancels:** only dodge, and only the recovery (after the impact). A dodge pressed during start-up is buffered to the
  impact on the client; the server refuses a roll before the impact. Remove the block cancel.
- **No hit-stop:** remove the calls and `Combat.Feel.HitStop`. Keep shake on finishers, heavies, slams only.
- **Movement:** no lunge on light steps (`Lunge = 0`), small lunge on heavy / charged only. Do not hard-set
  `root.CFrame` on every swing while running: turn the torso / root smoothly toward the aim. No WalkSpeed change.
- **Aim:** without lock-on melee goes in the flat camera direction (`AimAssistRange` tunable, default 0). Auto-Attack
  still picks its own target.
- **Rate check:** replace `HitsPerSecond` validation by each step's `Duration / speed` x `RateTolerance`. Keep
  `HitsPerSecond` as a derived display / DPS figure so `Stats.weaponDps` and the shop text stay right.
- **Attack speed:** one shared function in `Util/Stats`: `1 + attribute bonus + rarity bonus`, combined cap 2.0x,
  numbers in Config. Dexterity for melee and bow, Intelligence for Magic. Client and server run the same code; the
  server sends its speed in "Swing". The old `Attributes.Caps.AttackSpeed` and its UI texts must agree.
- **Guard break:** enemies have no guard meter. A staggered enemy counts as guard broken: a finisher on it deals
  `GuardBreakMult`; the spear gets a higher stagger chance and `GuardBreakMult`. Do not build an enemy guard system.
- **Player guard:** a server-side meter; each blocked hit weakens the block, it refills while not blocking, a perfect
  parry refunds it. Parry = block pressed within `ParryWindow` (0.2 s) before the hit: 0 damage, staggers the source
  (`DamagePlayer` must receive the enemy; check all callers).
- **Dodge:** reuse Roll. IFrames 0.25, base cooldown 1.2 (Mind still reduces it, floor as today). Roll already
  replicates. Keep the dash strike.
- **Mana:** new `Services/ManaService`. Saved in the profile (`Config/Profile`), max and regen from Mind, faster out of
  combat. Replicated with player attributes `Mana` / `MaxMana`, written only when the value changes by at least 1, on
  a 0.25 s tick. Attribute mapping: Mind, Faith and Intelligence all exist; no fallback needed (still write it in
  DESIGN.md).
- **Heal channel:** `Block` while Magic is equipped routes to the channel. Attribute `Channeling` replicates the light
  circle to every client. Heal per tick on the server, Faith through `FaithHealing`, allies within 20 studs get 50 %,
  50 % walk speed, a dodge interrupts it, cooldown after it ends.
- **Burn:** reuse the enemy damage-over-time of the element procs if there is one; cap the stacks in Config.
- **Bow / staff server side:** the client sends the 3D aim direction and aim point; the server rebuilds the origin from
  the character (tolerance), uses the 3D direction and raycasts walls. Pierce = the first N enemies along the ray. Net
  "Projectile" gets a `stuck` flag so clients leave the arrow in the wall for a moment.
- **Lock-on:** client only, new `Controllers/LockOnController`. The server never trusts it: it only receives a
  direction. Blend the camera, no snapping, also on release. Target = nearest enemy in a screen cone. A boss attack can
  disable it through a Net event.
- **Crosshair:** shown while Ranged / Magic is equipped; on PC the mouse locks to the centre outside windows (mind the
  Free Cursor key and the window Modal logic).
- **AnimationController:** a small new `Controllers/Combat/AnimationController.luau`: the single entry for "play this
  attack state on this character" (local prediction and `onSwing`), reading a data-driven `Config/WeaponMoves.luau`
  (steps, heavy, finisher, skill, timings, shapes, clips, trail). Server and client both read `WeaponMoves`. Move the
  combo data there instead of duplicating it. A new weapon = new data only. It wraps `Animations`, it does not replace it.
- **Pair daggers:** `WeaponService` equip adds an off-hand copy of the visual, welded to `LeftHand` on the server so
  everyone sees it, rotated 180 degrees around the blade axis (a mesh cannot be mirrored; log it). One item everywhere.
- **Skills:** `Skills.List` gets one basic skill per category on slot 1 (Z), auto-used by the category; slots 2 and 3
  stay as they are. Run on the server with the shared shapes; cooldown, cost and multiplier in `Skills`.
- **Icons (daggers):** the main agent composes and uploads the crossed-pair icons. Do not do them.

## Target numbers (starting points, all in Config)

| | Dagger | Sword | Spear | Hammer |
|---|---|---|---|---|
| Steps + finisher | 5 + 1 | 4 + 1 | 4 + 1 | 3 + 1 |
| First hit after press | 0.08 | 0.10 | 0.11 | 0.12 |
| Step duration | 0.22 | 0.34 | 0.40 | 0.60 |
| Max targets | 2 | 3 | 4 | 6 |

Bow quick shot about 0.1 s; staff quick cast about 0.15 s. Crossfades 0.05-0.1. Keep the DPS of the categories close
(`DamageMult` x average step damage / average duration); write the table in `docs/weapon_system_document.txt`.

## Step 0 notes

- `Weapons.luau` `NAMES[zone][index]` is positional: remove the Gauntlet column, not just the category row.
- 84 / 7 becomes 72 / 6: update every count (`Weapons.luau`, Index Book, UI, docs).
- Load: `DataService` drops items whose weapon id no longer exists, unequips them, equips another owned weapon or the
  starter one; also clean any index / favourite / loadout entries pointing at them.
- Disk files go to `_removed/` at the project root (git tracked, not synced to the game). Studio instances: delete them
  after the backup.
- "gauntlet" as a piece of armour on knight statues (`tools/Props*`, the prop guide) is not the weapon: leave it and
  name it as an exception, along with `docs/NIGHT_LOG.md` history, prompt files and `_removed/`.
