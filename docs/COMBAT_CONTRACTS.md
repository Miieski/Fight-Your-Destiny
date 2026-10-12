# Combat contracts (hack & slash, docs/weapons_combat_brief.txt Phase 4)

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
* Categories (7) and rate (`Config/WeaponCategories` HitsPerSecond -> interval between two attacks at speed x1):
  Sword 1.0/s (1.0 s), Spear 0.9/s (1.11 s), Heavy 0.4/s (2.5 s), Dagger 2.5/s (0.4 s), Gauntlet 1.8/s (0.556 s),
  Ranged 1.2/s (0.833 s), Magic 1.0/s (1.0 s). Attack speed bonus: `speed` = 1 + AttackSpeed (up to 1.15).
* **Combos** (`Config/Combat` `Combos`, read it): per category, the steps in order with `Name`, `Impact` (seconds
  after the attack request when the hit lands, at speed x1), `Finisher`, `Hits` (extra impacts: Dagger double
  slash at 0.2 s), `Lunge`. Sword 4 steps (RightSlash, LeftSlash, RisingSlash, SpinSlash finisher = circle around
  the player), Spear 3 (Thrust, Thrust2, PiercingLunge), Heavy 2 (OverheadSlam with ground slam, WideSmash),
  Dagger 5 (SlashR, SlashL, StabR, StabL, DoubleSlash), Gauntlet 3 (Jab, Cross, Uppercut x2 damage),
  Ranged 1 (Shot), Magic 1 (Cast). The combo restarts after `Combat.ComboReset` (0.8 s) without attacking.
* Zone elements of the first zones (trail tint): Plains Nature (green), Desert Sand (gold), Jungle Poison (lime),
  Tundra Frost (icy blue); `Config/Combat` `StyleColors` has a color per element.
* Rarity colors: `Config/Rarities` (`Rarities.get(tier).Color`).

## 4. Call order (what CombatController does)

Local attack (one combo step): turn toward the aim (aim assist 15 studs) -> lunge -> `Animations.attack(...)` ->
`VFX.swing(ctx)` -> `Sfx.combat("Swing", ctx)` -> `Net.send("Attack")`. When the server confirms a hit (Net "Hit"):
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
`Animations.hurt`, `Sfx.combat("Hurt")`. Ranged / Magic / enemy shots: Net "Projectile" -> `VFX.shot`; Magic area
and Heavy slam: Net "Burst" -> `VFX.burst`.

## 5. APIs

### Animations (`GameClient/Controllers/Combat/Animations.luau`)
```
Animations.attack(character: Model, category: string, step: number, speed: number): number
    -- plays the step's clip; its "Hit" marker must sit at Combos[category][step].Impact / speed; returns the clip
    -- length in seconds at that speed (0 if none). The clip must fit in the category interval at speed x1.
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
