# Combat contracts (hack & slash, docs/weapons_combat_brief.txt Phase 4)

**Weapon overhaul, 2026-10-30:** read section 10 first: it replaces the combo tables, the call order and the APIs below where
they differ. How the animations work: `docs/animation_system.md`.

The main agent owns the gameplay and the integration. Three sub-agents fill in the feel: **animations**, **VFX**,
**SFX**. Each one owns its files only and keeps the API below exactly (names, arguments, return values), so the
integration in `CombatController` never has to change.

## 1. Who owns what

| Owner | Files |
|---|---|
| Main agent | `Config/Combat.luau` (combos, timings, feel numbers), `CombatService` (server: hits, damage, combo step), `Controllers/CombatController.luau` (input, aim assist, lunge, hit-stop calls, camera, cancel rules, combo counter), `FxController` (`Fx.shake`, `Fx.fovPulse`), `Net.luau`, `EnemyService` |
| Animation sub-agent | `Animations/` (sources, optional), `GameClient/Controllers/Combat/` (`Animations.luau` + any helper module next to it), `Config/CombatAnimations.luau` |
| VFX sub-agent | `ReplicatedStorage/Assets/VFX/` (Studio assets), `GameClient/Controllers/VFX/` (`VFX.luau` + helpers next to it), `Config/CombatVFX.luau` |
| SFX sub-agent | `Util/Sfx.luau` (the `Sfx.combat` part and the registry), `Config/CombatSfx.luau`, `Config/Audio.luau` (only to add combat sound names to `GroupOfSound`), `ReplicatedStorage/Assets/Sounds/Combat/` (sounds) |

Never edit another owner's file. If you need a change there, write it in your report ("REQUEST: ...").

## 2. Rules for every sub-agent

* **Server authoritative.** Hits, damage, cooldowns and the combo step are decided by `CombatService`. Animations,
  VFX and SFX are client-only and never decide damage.
* **Studio**: you are the ONLY agent using Roblox Studio during your run (the main agent works in Blender and does
  not touch Studio). Studio id: call `list_roblox_studios` (place "Combattez votre destin !"). Leave Studio in Edit
  mode (no Play running) and with the device emulator on "default" when you finish.
* **Editing scripts**: the project edits scripts in Studio through `execute_luau` (Edit datamodel: set
  `ModuleScript.Source`, check it compiles with `loadstring(source)` first), then writes them to disk:
  `require(game.ServerStorage.DevTools.ExportScripts)()` in Edit, then `python tools/pull_scripts.py --wait 15`
  from the project folder. Disk = the repo. Check `git status` afterwards: only your files may change.
* **Backup before your first change**: `require(game.ServerStorage.DevTools.Backup)("<agent>_before")` in Edit,
  then `python tools/collect_backup.py --wait 15`.
* **Do not commit or push.** The main agent reviews and commits.
* **Performance**: pool parts/emitters/sounds, no per-frame table allocations, a global cap on simultaneous
  effects/sounds, nothing left in the workspace. Mobile friendly (few particles).
* **Low FX** (`Settings.get("LowFx")`): halve particles, no afterimages, no shakes. `FxController` already scales
  the Rate of every ParticleEmitter in the workspace by 0.25 with Low FX; `Emit` counts are yours to halve.
* Use `Settings` from `GameClient/Controllers/SettingsController` (`Settings.get(key)`, `Settings.changed(key, fn)`).
* Log decisions and problems in your final report (the main agent copies them into `docs/NIGHT_LOG.md`).
* If something fails twice: note it, skip it, continue.
* **Pilot first**: do the **Sword** end to end, check it in Play, then the other categories (see your brief).
* Original work only: Blox Fruits is a feel reference (rhythm, dash, trails, hit-stop, readable effects); copy no
  asset, name, effect or UI.

## 3. The game data you build on

* Character: **R15**, the default `Animate` LocalScript runs (idle / walk / run / jump / toolnone).
* Weapons are `Tool`s cloned from `ReplicatedStorage.Assets.Weapons.<weaponId>` (attributes `WeaponId`,
  `Category`, `Zone`, `Rarity` (1-8) once equipped, `Uid`). `Handle` attachments: `TipAttachment` (blade tip /
  head), `BaseAttachment` (hilt), `MuzzleAttachment` (Ranged, Magic), `ImpactAttachment` (Heavy: strike point).
  Today the Tools are simple placeholder parts; the real meshes come later with the same attachment names.
* Categories (6) and rate (`Config/WeaponCategories` HitsPerSecond -> interval between two attacks at speed x1):
  Sword 1.0/s (1.0 s), Spear 0.9/s (1.11 s), Heavy 0.4/s (2.5 s), Dagger 2.5/s (0.4 s),
  Ranged 1.2/s (0.833 s), Magic 1.0/s (1.0 s). Attack speed bonus: `speed` = 1 + AttackSpeed (up to 1.15).
* **Combos** (`Config/Combat` `Combos`, read it): per category, the steps in order with `Name`, `Impact` (seconds
  after the attack request when the hit lands, at speed x1), `Finisher`, `Hits` (extra impacts: Dagger double
  slash at 0.2 s), `Lunge`. Sword 4 steps (RightSlash, LeftSlash, RisingSlash, SpinSlash finisher = circle around
  the player), Spear 3 (Thrust, Thrust2, PiercingLunge), Heavy 2 (OverheadSlam with ground slam, WideSmash),
  Dagger 5 (SlashR, SlashL, StabR, StabL, DoubleSlash),
  Ranged 1 (Shot), Magic 1 (Cast). The combo restarts after `Combat.ComboReset` (0.8 s) without attacking.
* Zone elements of the first zones (trail tint): Plains Nature (green), Desert Sand (gold), Jungle Poison (lime),
  Tundra Frost (icy blue); `Config/Combat` `StyleColors` has a color per element.
* Rarity colors: `Config/Rarities` (`Rarities.get(tier).Color`).

## 4. Call order (what CombatController does)

Local attack (one combo step): turn toward the aim (aim assist 15 studs) -> lunge -> `Animations.attack(...)` ->
`VFX.swing(ctx)` -> `Sfx.combat("Swing", ctx)` -> `Net.send("Attack")`; the server answers every request with Net "Combo" (category, step, accepted) and the client's step prediction follows it. When the server confirms a hit (Net "Hit"):
`VFX.damageNumber`, `VFX.impact`, `Sfx.combat("Impact")`, combo counter, then (once per swing) `Animations.hitStop`,
`Fx.shake`, `Fx.fovPulse` on finishers. Other players: Net "Swing" -> `Animations.attack` + `VFX.swing` +
`Sfx.combat("Swing")` (IsLocal = false, ctx.Position = their root); Net "Impact" (with the weapon Element) ->
`VFX.impact` + `Sfx.combat`; Net "Motion" (`player, kind, dir?`, kind "Roll" | "Hurt" | "BlockHit") ->
`Animations.roll` + `VFX.roll` + `Sfx.combat("Roll")`, `Animations.hurt` + `Sfx.combat("Hurt")`, `Animations.blockHit` +
`VFX.blockHit` + `Sfx.combat("BlockHit")` (ctx.Position = their root); their "Blocking" attribute -> `Animations.block` +
`VFX.block`. The block bubble is drawn by `VFX.block` only (local and other players).
Roll: `Animations.cancel`, `Animations.roll`, `VFX.roll`, `Sfx.combat("Roll")`. Block on: `Animations.cancel`,
`Animations.block(true)`, `VFX.block`, `Sfx.combat("Block")`; off: `Animations.block(false)`, `VFX.block`.
Hit taken while blocking: `Animations.blockHit`, `VFX.blockHit`, `Sfx.combat("BlockHit")`; otherwise
`Animations.hurt`, `Sfx.combat("Hurt")`. Ranged / Magic / enemy shots: Net "Projectile" -> `VFX.shot` +
`Sfx.combat("Shot", { Position = origin, Style, Speed, Distance, Enemy, Shooter, Own })` (VFX.shot ctx also gets `Shooter`: the Player, nil for enemies) (the shooter's own release / fire sound is its
Swing: Shot is the projectile itself); Magic area and Heavy slam: Net "Burst" -> `VFX.burst` +
`Sfx.combat("Burst", { Position, Radius, Style })`. Every player's character: a weapon Tool appearing ->
`Sfx.combat("Equip", { Category, Rarity, IsLocal, Position })`, Humanoid.Died -> `Sfx.combat("Death", { IsLocal, Position })`.

## 5. APIs

### Animations (`GameClient/Controllers/Combat/Animations.luau`)
```
Animations.attack(character: Model, category: string, step: number, speed: number, aim: Vector3?): number
    -- plays the step's clip; its "Hit" marker must sit at Combos[category][step].Impact / speed; returns the clip
    -- length in seconds at that speed (0 if none). The clip must fit in the category interval at speed x1.
    -- aim (optional) = the 3D aim direction: pitches the torso of AimPitch clips (Ranged, Magic), capped at 40 deg
Animations.cancel(character: Model)                 -- stop the attack clip (roll / block cancel the recovery)
Animations.hitStop(character: Model, seconds: number) -- play the character's clips at Combat.Feel.HitStopSpeed
Animations.block(character: Model, on: boolean)
Animations.blockHit(character: Model)
Animations.roll(character: Model, direction: Vector3) -- world direction of the dash (0.3 s, 12 studs)
Animations.hurt(character: Model)
```
Inside the module (automatic, for every player's character on this client): Idle / Run / Equip stance of the
equipped weapon's category (from the Tool's `Category` attribute), Death, Spawn. Clip names:
`<Category>_Idle`, `<Category>_Run`, `<Category>_Equip`, `<Category>_Attack1..N`, `<Category>_Block`,
`<Category>_BlockHit`, `Shared_Roll`, `Shared_Hit`, `Shared_Death`, `Shared_Spawn`.

### VFX (`GameClient/Controllers/VFX/VFX.luau`)
```
VFX.play(name: string, cframe: CFrame, options: { [string]: any }?)   -- one pooled effect (Assets/VFX/<name>)
VFX.swing(ctx)   -- { Character, Tool?, Category, Step, Finisher, Direction, Rarity?, Element?, Speed, IsLocal, Position? }
VFX.impact(ctx)  -- { Position, Category?, Crit, Finisher, Element?, IsLocal }
VFX.shot(ctx)    -- { Origin, Direction, Speed, Distance, Style }   Style = element name, "Physical", "Enemy", "Arcane"
VFX.burst(ctx)   -- { Position, Radius, Style }                     Style = element, "Arcane", "Slam"
VFX.roll(ctx)    -- { Character, Direction, IsLocal }
VFX.block(ctx)   -- { Character, On }
VFX.blockHit(ctx) -- { Character, Position? }
VFX.damageNumber(position: Vector3, text: string, kind: string)   -- "normal" | "crit" | "hurt" | "block" | "dodge"
```
Enemy hit flash and death are already drawn by `EnemyController` (hit flash on `HitAt`, death fade); the VFX module
may add to them by watching `workspace.Enemies` models (`HitAt`, `Dead` attributes) without editing EnemyController.

### SFX (`Util/Sfx.luau`)
```
Sfx.combat(event: string, ctx: { [string]: any }?)
    -- event: "Swing" | "Impact" | "Shot" | "Cast" | "Burst" | "Roll" | "Block" | "BlockHit" | "BlockBreak" |
    --        "Hurt" | "Death" | "Equip"
    -- ctx: { Category?, Step?, Finisher?, Crit?, Material? ("flesh" | "metal" | "stone"), Position? }
    -- Position = a 3D sound there; nil = the local player's own sound (full volume).
```
`Sfx.play(name, position?)` (existing) plays a sound by name from `ReplicatedStorage.Assets.Sounds` and routes it
to its SoundGroup (`Config/Audio` `GroupOfSound`; combat sounds -> PlayerFX, enemy sounds -> EnemyFX).

## 6. Testing in Play (Client datamodel, `Net = require(game.ReplicatedStorage.GameSystem.Net)`)

* `Net.request("Admin", "godMode", true)` - no damage taken.
* `Net.request("Admin", "spawnEnemy", "plains_boar")` - an enemy next to you (zones 1-4 ids).
* `Net.request("Admin", "equipWeaponFake", "Plains", rarityTier, "Spear")` - equip a weapon of any category.
* Hold attack: `user_mouse_input` (datamodel "Client", moveTo first) mouse down / up; keys with `user_keyboard_input`
  (Q roll, MouseButton2 block). Two MCP calls are several seconds apart: send them in the same message with a
  leading `wait` in the second one when timing matters.
* Phone check: `game:GetService("StudioDeviceSimulatorService"):SetDeviceAsync("iphone_17_pro")` +
  `SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft)` in Edit before Play; `SetDeviceAsync("default")` after.
* Module state of the running game is invisible from `execute_luau` (it gets fresh module copies): read instances,
  attributes and GUI, or listen to Net events from the command line.
* `screen_capture` may return a frame a few seconds old.

## 7. Report (end of each run)

Files created / changed, the exact API and clip / effect / sound names, what was tested in Play (with timings),
decisions, problems, REQUESTS for other owners, and what is left.

## 8. Combat V3 additions (2026-10-14: jump attacks, dash strikes, longer combos)

Owner: "Make more combat animation. Make a special animation when the character jump+attack ... take inspiration from
Iron Soul: Dungeon ... create as much animation as possible ... You MUST use Subagent for VFX and SFX. Fix a lag of ground
texture lagging when you dodge" (the ground turns blue and flickers: the cyan Neon roll afterimages of the curled roll
pose lie on / inside the ground). Gameplay by the main agent (done, tested in Play): `Config/Combat`, `CombatService`,
`CombatController`, `Net` ("Swing" gets a variant, new "AirSlam").

### 8.1 New moves (Config/Combat)
* **Combos** - Spear 4 steps (Thrust, Thrust2, **Sweep** 0.22 (new: wide 180 deg arc), PiercingLunge 0.24 finisher =
  was step 3, now 4), Heavy 3 (OverheadSlam 0.45, WideSmash 0.40 (no longer the finisher), **GroundBreaker** 0.55 (new
  finisher: jumping two-handed slam, circle radius 8 + ground slam radius 9)), Ranged 3 (Shot 0.05, **QuickShot** 0.05,
  **PowerShot** 0.12 finisher, faster arrow), Magic 3 (Cast 0.30, **Cast2** 0.28, **GrandCast** 0.40 finisher, radius
  8.5). Sword (4), Dagger (5) unchanged.
* **Jump attack** `Combat.AirAttacks[category]` (variant "Air"): attack while airborne (>= 1.2 studs under the feet).
  Melee: the body hangs `Hang` s, then dives (CombatController) so the feet touch the ground exactly at `Impact`; the
  hit is a circle around the landing point (counts as a finisher). Sword PlungeStrike (Impact 0.32, Hang 0.10, r 7),
  Spear DragoonDive (0.34, 0.12, r 6.5), Heavy MeteorSmash (0.45, 0.16, r 9, stagger), Dagger ShadowDrop (0.26, 0.06,
  r 5). Ranged AirVolley (Impact 0.12, Hang 0.25: the body hovers,
  3 arrows fanned 14 deg toward the nearest enemy below / the ground ahead). Magic MeteorDrop (Impact 0.40, Hang 0.30:
  hovers, a radius 9 blast at the aim point). The combo restarts after it.
* **Dash strike** `Combat.DashAttacks[category]` (variant "Dash"): attack pressed during a roll or within 0.35 s after
  it -> a long lunge out of the roll. Sword DashSlash (Impact 0.14, lunge 6 studs over 0.16 s, line 9), Spear
  ChargeThrust (0.16, 8 over 0.18, line 13), Heavy RushingSmash (0.30, 5 over 0.20, arc 150), Dagger ShadowStep (0.10 +
  second hit 0.18, 6 over 0.14), Ranged SlideShot (0.08, no lunge),
  Magic BlinkBlast (0.20, a radius 6 blast around the caster). The combo restarts after it.

### 8.2 API changes (keep the old calls working)
```
Animations.attack(character, category, step, speed, aim?, variant?) -> length
    -- variant nil = the combo step's clip <Category>_Attack<step>; "Air" = <Category>_JumpAttack (step = 1; its Hit
    -- marker = Combat.AirAttacks[category].Impact, the landing for melee: the clip must look airborne until Hit -
    -- hang + dive - then land / recover, Legs "Own"); "Dash" = <Category>_DashAttack (Hit = Combat.DashAttacks Impact).
    -- Styles (RangedCrossbow_, RangedGun_) fall back to the category's clip as before.
VFX.swing(ctx)      -- ctx.Variant = nil | "Air" | "Dash" (ctx.Step = 1 for both; ctx.Finisher = true for "Air")
VFX.land(ctx)       -- NEW: a melee jump attack hits the ground. ctx = { Character?, Tool?, Category, Position (ground
                    -- point), Radius (the hit radius), Rarity?, Element?, IsLocal }. Local: called by the client at its
                    -- own landing; others: Net "AirSlam" at the server's hit. CombatController calls it only if it exists.
Sfx.combat("Land", ctx)   -- NEW event, same ctx as VFX.land (Position = a 3D sound there, IsLocal = own sound)
Sfx.combat("Swing", ctx)  -- ctx.Variant as in VFX.swing
```
New clip names: `<Category>_JumpAttack`, `<Category>_DashAttack` (6 categories each), `Spear_Attack3` (Sweep, the old
PiercingLunge clip becomes `Spear_Attack4`), `Heavy_Attack3`, `Ranged_Attack2..3` (+ RangedCrossbow_ / RangedGun_
versions where the style differs), `Magic_Attack2..3`. Optional (if time allows): `<Category>_Air` (upper-body stance
while jumping / falling, Legs "Upper"), a second hurt clip, a landing recovery.

### 8.3 What V3 added in each owner's files (for the next rounds)
* Animations: `<Category>_JumpAttack` (new `Markers.Dive` = dive start; the local clip waits at Dive while the body hangs
  and just before Hit until the body has landed), `<Category>_DashAttack`, `<Category>_Air` (upper-body stance while
  jumping / falling), `Shared_Hit2` (random second hurt clip), new combo clips; dev hook `AnimReload` (recompiles the
  clips in Play). The held Tool's parts are forced CanCollide = false on the client.
* VFX: `Config/CombatVFX` `Land[category]` (VFX.land effects: Ring / Line / Burst / Ground), `AirSwing`, `DashSwing`;
  module `Controllers/VFX/Dives.luau` (dive streaks from the body's real fall); dev hook command `land:<category>` on
  workspace.VFX `Test`. Roll afterimages are lifted above the ground under the body (SmoothPlastic, no bloom).
* Testing spots in Plains_1: path (2000, 3.2, -70), grass (2066, 3.2, -22).

## 9. Zone fighting styles (2026-10-14)

Owner: "Create different animations according to the zone weapon. So plains weapon will have a different animation than
the void one." Answers: **12 fighting styles** (each zone its own stance and idle, rhythm, swing size and a signature
move on finishers and jump attacks, for all 6 categories) and **effects and sounds too**.
* `Config/CombatStyles.luau` (main agent, read it): one style per zone - Plains Squire (the base, unchanged), Desert
  Dune Dancer, Jungle Feral, Tundra Glacier, Swamp Hexblade, Volcano Berserker, Hell Demon, Heaven Seraph, Dead
  Revenant, Abyss Tidecaller, Mechanical Automaton, Void Voidwalker. Each entry describes Moves, Finisher, Jump, Look and
  Sound: that is the brief; the numbers live in each owner's config. `CombatStyles.get(zoneIndexOrId)`,
  `CombatStyles.ofTool(tool)` (the Tool's "Zone" attribute 1..12).
* The style is the held weapon's zone, for every player's character (the Tool and its attributes replicate).
* ctx.Zone (1..12, the weapon's zone) is now in every combat ctx CombatController builds: `VFX.swing`, `VFX.impact`,
  `VFX.land`, `Sfx.combat("Swing" | "Impact" | "Land")` (other players' impacts: derived from their element).
* Timing rules stay: a style may reshape a clip and its rhythm, but the Hit marker stays exactly at the step's Impact /
  speed (the server hits then), and combo clips still fit the weapon interval at speed x1.
* Animations (zone styles round): `CombatAnimations.ZoneStyles[zoneId]` (posture, idle guard, swing amplitude /
  follow-through, wind-up / recovery time-warps keeping Hit exact, Linear / IdleStep, idle and attack waves) and 22
  overlay clips `Style_<Zone>_Finisher` / `Style_<Zone>_Jump` (offsets layered on the finisher steps and the jump
  attacks, timed on their Dive / Hit markers, "late" mode on very short wind-ups). Plains runs the old path. Dev hooks
  `AnimZone` (character attribute: show the held weapon in any zone's style) and `AnimHitDebug` (writes `AnimHitAt` /
  `AnimHitPose` / `AnimHitClip`).

## 10. Weapon overhaul (2026-10-30)

* **Data:** `Config/WeaponMoves` holds every shape, step, heavy, jump attack, dash strike and skill move
  (`Combat.Shapes`, `Combos`, `AirAttacks`, `DashAttacks` are gone). `WeaponMoves.move(category, step, variant)`,
  `WeaponMoves.shape(category, move)`.
* **Call order, local attack:** `aim` -> `LockOn.face` -> lunge (heavy, jump, dash only) -> `AnimationController.play` (clip,
  `VFX.swing`, `Sfx.combat("Swing")`) -> `Net.send("Attack", dir, point, variant)`. The hold: `Net.send("Charge", true)` +
  `AnimationController.play` with Variant "Charge"; the release: Attack with variant "Heavy".
* **Other players:** Net "Swing" -> `AnimationController.play` with `IsLocal = false`.
* **Removed:** `Animations.hitStop`, `Trails.extend`, `Combat.Feel.HitStop`, the block cancel, the light lunge.
* **New APIs:** `Animations.charge(character, category, speed)`, `Animations.aim(character, direction)`,
  `VFX.chargeGlow(ctx)`, `VFX.chargeEnd(character)`, `VFX.channel(ctx)`, `Casts.stop(character)`,
  `LockOn.toggle / next / release / point / face`, `ManaService:Has / Spend / Touch / Channel / IsChanneling`,
  `CombatService:Skill`, `MenuBar.setPushDown`, `DataService.Migrate`.
* **Net:** "Projectile" gets `stuck?, size?`; new "NoMana", "LockBreak"; "Hurt" kinds "parry", "break"; "Motion" kind "Parry".
* **Readability limit** (`Config/CombatVFX`): a combat flash particle is at most 7 studs, 35-60% see-through, under 0.2 s; big arcs
  see-through and at most 1.8 studs wide. A finisher or heavy must never hide enemies or boss telegraphs.
