# CYCLE

A first-person 3D narrative choice game (Godot 4.3, GL Compatibility renderer, low-poly/code-built art).
It looks like a cozy life sim. It is secretly about the avoidance → relief → pressure loop.

## Run
Open the folder in Godot 4.3+ and press F5 (or `godot --path .`). No external assets: all geometry,
music and SFX are generated in code, so any piece can later be swapped without touching gameplay.

Controls: WASD move · Mouse look · E interact · Shift walk faster · Ctrl crouch · F flashlight · Q phone · Space jump ·
Esc pause (all rebindable in Settings, plus subtitles, FOV, sensitivity, motion-sickness reduction, shake toggle,
colour-blind UI). In cutscenes any key or click skips. In minigames E / Space / click is the action and Esc stops.

## Endings
Each is reached from a different way of playing; every one has its own camera cutscene (Cinema) before its text.

| Ending | How you get there |
|---|---|
| Escape | Finish all four essay sections (writing two breaks the cycle, then the door is the only thing left to do) |
| Awareness | Break the cycle, then walk out of the door without finishing the essay |
| Burnout | Pressure and exhaustion both high from day 4 (heavy gym/outings, staying up, no early sleep) |
| False Productivity | Keep "productively" busy (clean, organize, research) and never write; stay rested enough not to burn out |
| Loop | Keep playing past the last gate: back to Day 1 with your history remembered |

## Cutscenes
`Cinema` (autoload) plays `opening`, `wake`, `day_end`, `night_scroll`, `doomscroll_enter`, `doomscroll_exit` and `ending`
(per-ending treatment). Text lives in `data/sequences.json` (`cin_*`). Honours motion-sickness reduction, camera shake and
subtitle settings; `--cinema=skip` resolves every scene instantly (bots). 

## Layout
- `scripts/autoload/` — Events (signal bus), GameState (hidden variables, memory, save data), Psychology
  (immediate/hidden/delayed consequences), Narrative (state-machine profiles), Dialogue (JSON + conditions),
  Audio (procedural), UI, Days (game loop), Endings, Saves, Settings.
- `scripts/world/` — Bedroom (mirror, escalating clutter/notes/light), Neighborhood + gym, Player, Avatar.
- `scripts/minigames/` — poker (engine + UI), gym timing games, essay-writing mechanic.
- `scripts/ui/` — fake-OS computer, character customization, menus, settings.
- `data/` — choices, sequences (all fourth-wall/ending text), dialogue pools, websites, essay cards.

## QA
- `tools/check.sh` — compile all scripts headless (prints nothing when clean).
- `tests/run_unit.sh` — headless unit checks: poker engine, run state (save/load, ranges, delayed consequences, settings,
  rebinding), world geometry, Cinema contract.
- `tests/run_playthrough.sh <policy> [scale] [shots_dir]` — a bot plays the real game under xvfb
  (`work|later|poker|mixed|burnout|false|aware|loop`) and prints a `RESULT ... verdict=PASS|FAIL` line comparing the first
  ending reached with the policy's intended one. `RES=WxH` sets the window size; screenshots include every cutscene beat and
  every line of story text. Run at most two at a time on a 4-core machine.
- `res://tools/shot_ui.tscn` — screenshots every UI screen (see the header of `tools/shot_ui.gd`).
- `tools/release.sh <version>` — Linux and Windows exports to `build/` (needs the 4.3 export templates installed).

## Known limitations
- Timing/FPS were only measured on a software renderer (llvmpipe): about 8 fps in the bedroom at 1280x720 there, which says
  little about real GPUs. No audio device exists in CI, so sound is unverified by ear.
- Godot prints "ObjectDB instances leaked at exit" on quit (coroutines still awaiting a fade); harmless.
- The exported builds were smoke-run (menu, 20 s, no errors) but not played through; playthroughs run from source.
- The Windows build is untested on Windows.
