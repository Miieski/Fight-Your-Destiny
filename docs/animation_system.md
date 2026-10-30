# Animation system (weapon overhaul, 2026-10-30)

Every weapon animation is **procedural**: keyframe data written to the R15 joints on each client, no uploaded animation
asset. Other players see the animations because the server sends a compact attack state and each client plays it.

## Pieces

| Piece | Role |
|---|---|
| `Config/WeaponMoves.luau` | The data of every weapon: shapes, steps, heavy, jump, dash, skill. Read by the server and all clients. |
| `Config/CombatAnimations.luau` | The clips: key poses per channel, markers `Hit`, `Charge`, `Dive`. Data only. |
| `Controllers/Combat/Animations.luau` | Samples the clips each frame, runs the arm and leg IK, cross-fades, writes the joints. |
| `Controllers/Combat/AnimationController.luau` | The single entry: "play this attack state on this character" (clip + trail + whoosh). |
| `Controllers/CombatController.luau` | Input: tap, hold, buffer, dodge, block; calls AnimationController at the press (prediction). |
| `Services/CombatService.luau` | The server: picks the step, validates timing, lands the hits, sends the state to the others. |

## The attack state

`Net "Swing"`: `attacker, category, step, direction, speed, aim, variant`.

`variant`: nil (combo step), `Heavy`, `Air`, `Dash`, `Skill`, or `Charge` (the hold's wind-up begins). It is sent once per
move, never per frame. A viewer calls `AnimationController.play` with `IsLocal = false`. The left dagger of a pair is a
real welded part in the Tool, so it replicates by itself; `Channeling` is a player attribute, so the heal circle does too.

## Timing

- `Impact` = press to first damaging frame, `Duration` = press to the next move. Both divide by the attack speed.
- A clip's `Hit` marker lands exactly on `Impact / speed` (the wind-up stretches), the recovery runs at `speed`. Animation and
  server stay in step at any speed. The speed comes from the same `Stats.compute` on both sides and travels in the state.
- Impact 0 (bow, staff): the shot leaves at the release, so the clip starts on its `Hit` marker. The draw played before it.
- `Charge` marker: the heavy clip waits there while the button is held (`Slot.holdAt`). The release takes `Impact` to reach
  `Hit`. Without the marker it holds at 60% of the wind-up.
- `FadeIn` 0.03-0.08 s between moves; each combo clip starts where the previous one ended, so the chain flows.
- Nothing slows a clip: hit-stop was removed.

## Add a weapon category

1. An entry in `WeaponMoves.Moves`: `Class`, `Dps`, `Shape`, `Steps`, `Heavy`, `Air`, `Dash`, `Skill`.
2. A row in `WeaponCategories.List` and a column in `Weapons` NAMES.
3. Clips `<Category>_Idle`, `_Run`, `_Equip`, `_Attack1..N`, `_Heavy`, `_Block`, `_BlockHit`, `_JumpAttack`, `_DashAttack`, `_Air`.
4. Optional: `CombatVFX.Swing` / `HeavySwing` / `SkillSwing`, `CombatSfx`, an entry in `Skills.List`.

No code change. `DamageMult` and `HitsPerSecond` are derived from the data, so tuning a timing never moves the DPS.

## Dev hooks (Play, Client)

- `character:SetAttribute("AnimDebug", "Sword_Attack1@0.1")` freezes a clip at a time; `"Clip@0.12@35"` adds an aim pitch.
- `AnimHitDebug = true` writes `AnimHitAt` (seconds from the call to the clip's Hit), `AnimHitClip`.
- `AnimProfile` writes `AnimCostMs`, `AnimChars`. `AnimReload` recompiles the clips, `AnimZone` shows a zone style.
- `player:SetAttribute("SwingSelfTest", true)` plays a Swing sent to oneself: the receive path, with one client only.

## Filmstrips

`tools/grab_studio.py` grabs the Studio window on `FYDSHOT|<set>/<name>` log markers (`BURST|<set>|<seconds>` = 48 fps real
time). `tools/make_filmstrip.py` builds the sheet, `tools/make_rt_gif.py` the GIF and the picked frames. Frozen poses show no
effects. Raw bursts stay out of the repo. In Play the Assistant resets the camera after each `execute_luau`: hold a
Scriptable camera from a `RenderStepped` connection in the running thread.
