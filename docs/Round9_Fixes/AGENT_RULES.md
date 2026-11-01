# Round 9: rules for every Studio agent

Read `docs/Round9_Fixes/PROMPT_Round9_Fixes.txt` for your parts, and the top section of `docs/NIGHT_LOG.md`. The numbered images are in `docs/Round9_Fixes/`: look at the ones of your parts.
If graphify-out/graph.json exists, run `graphify query "<question>"` before your first grep or source read. Read raw files only for lines the graph or an earlier read located.
You are the only one using Studio. Do not ask the owner anything: take the most reasonable reading, log it at the top of `docs/NIGHT_LOG.md` and carry on. If a step fails twice, log it and move on.

## Studio
- Studio id: call `mcp__Roblox_Studio__list_roblox_studios` (last id 73bd0bf3-c434-4767-bb64-c4cc2f1a31d8). Load the tools with ToolSearch.
- Scripts: Studio is the source for `src/`. Set `Source` in Edit (read it, replace by plain `string.find`, `loadstring` to check, assign). Then `task.spawn(function() require(game.ServerStorage.DevTools.ExportScripts:Clone())() end)` and `python tools/pull_scripts.py --wait 15` until "0 written". Never edit `src/` on disk only: a pull overwrites it.
- Backup BEFORE each part, in Edit: `task.spawn(function() require(game.ServerStorage.DevTools.Backup)("before_r9_partN") end)`, then in the background `python tools/collect_backup.py --wait 60` in a loop until 6 files with that label exist (Workspace is slow, 10+ tries). Do not start Play while it is printing. Never overwrite a backup.
- Play: `start_stop_play`. If it says "Start play hasn't finished yet" or times out, start Play from Edit with `task.spawn(function() pcall(function() game:GetService("StudioTestService"):ExecutePlayModeAsync({}) end) end)` and read `get_studio_state`.
- In Play: `Net.request("Admin", "unlockAll"|"lockAll"|"unlockZone", zoneId, gates|"setGold", 1e12|"setZone", zoneId, n (5 = boss room)|"damageSelf", 1e9|"killAll")`, 2 s between Admin calls. `Net.request("Teleport", zoneId, n)`, 3 s cooldown, 5 s after damage. To point the shot: pivot the character and set `workspace.CurrentCamera.CFrame` from the Client datamodel, then `screen_capture` (no camera arguments in Play). In Edit, `screen_capture` takes camera_position / look_at_position. Send captures one at a time.
- Script errors are in `%LOCALAPPDATA%\Roblox\logs\*_Studio_*.log` as `[FLog::CreatorError]` / `[FLog::CreatorWarning]`. Scan them after each Play. "past shutdown" lines and `AssistantCommand` stacks are not game errors. Warning 203785492 is old and harmless.
- Long Luau loops: `task.wait()` per chunk, or the connection drops.
- Images: `tools/make_floor_textures.py` and `tools/textures/make_brick_textures.py` are the existing generators (Python on Windows: write text with newline="\n"). Upload: `python -m http.server <new port> --bind 127.0.0.1` from the folder, check 200 with curl, `upload_image`, then stop the server. Use a fresh port each time.
- Phone emulator: in Edit before Play `game:GetService("StudioDeviceSimulatorService"):SetDeviceAsync("iphone_17_pro")` + `SetOrientationAsync(Enum.ScreenOrientation.LandscapeLeft)`, reset with `"default"` after. Mouse clicks do not reach GUI there.

## World rules
- Assets: MapProps. Edit `ServerStorage.MapProps.<id>`, then SyncMapProps; all copies follow, and the asset preview in the same way ("replaced n / total"). Tools: BuildAssetPreview (B.tag / build / check / compare / index). See `docs/prop_inventory.md`, `docs/prop_texture_guide.md`, HANDOFF.md.
- Never touch the asset preview ground (OwnerLocked, docs/preview_ground_snapshot.json).
- Keep position, rotation, names, tags, attributes, prompts, scripts, GUIs, lights, collisions, spawns unless the part says otherwise. Compare colliders before and after each ground or decor change. Do not touch experience security settings.
- Style: low-mid poly, soft gradients, bevels, no PBR, nothing photographic: 3-5 tones, large soft shapes. Textures 128-256 px, shared, tinted. No stretching, no z-fighting, no coplanar faces. Mobile first: count what you add. The pink glow around the player is the weapon's aura.

## Reports and git
- Photo report after EACH asset or room, right away: `python tools/make_before_after.py NN name "NN - Title" --row "Label" before.jpg after.jpg [--row ...]` writes `docs/before_after/NN_name.png` (name them R9-...). Same camera. The owner's image can be the "before" for "Dans le jeu". Animations: filmstrip of 8-12 frames (`tools/grab_studio.py`, `tools/make_filmstrip.py`).
- After each part: log at the top of `docs/NIGHT_LOG.md` (decisions, numbers, what was NOT tested), update the docs the part touches, then `git add` only what you changed, check that no .rbxl / .rbxm / backup is staged and that no secret is in a file, commit, push to origin main, run `graphify update .`. Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never put secrets in files.
- Do not write to stored player data outside the game's own Admin commands. Never work around a permission refusal: stop that step and report it.
- Blender tools run arbitrary Python: stay in the project folders.
- Your final message to the coordinator: per part OK / not OK, numbers, sheets written, what was not tested, and any finding. Say plainly if something failed. Be exact: do not call something tested if you did not run it.
