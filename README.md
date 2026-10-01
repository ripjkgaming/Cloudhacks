# CYCLE

A first-person 3D narrative choice game (Godot 4.3, GL Compatibility renderer, low-poly/code-built art).
It looks like a cozy life sim. It is secretly about the avoidance → relief → pressure loop.

## Run
Open the folder in Godot 4.3+ and press F5 (or `godot --path .`). No external assets: all geometry,
music and SFX are generated in code, so any piece can later be swapped without touching gameplay.

Controls: WASD move · Mouse look · E interact · Shift walk faster · Ctrl crouch · F flashlight · Esc pause
(all rebindable in Settings, plus subtitles, FOV, sensitivity, motion-sickness reduction, shake toggle, colour-blind UI).

## Endings
Escape (finish the essay) · Loop (keep playing) · Burnout · False Productivity · Awareness.

## Layout
- `scripts/autoload/` — Events (signal bus), GameState (hidden variables, memory, save data), Psychology
  (immediate/hidden/delayed consequences), Narrative (state-machine profiles), Dialogue (JSON + conditions),
  Audio (procedural), UI, Days (game loop), Endings, Saves, Settings.
- `scripts/world/` — Bedroom (mirror, escalating clutter/notes/light), Neighborhood + gym, Player, Avatar.
- `scripts/minigames/` — poker (engine + UI), gym timing games, essay-writing mechanic.
- `scripts/ui/` — fake-OS computer, character customization, menus, settings.
- `data/` — choices, sequences (all fourth-wall/ending text), dialogue pools, websites, essay cards.

## QA
- `tools/check.sh` — compile all scripts headless.
- `tests/run_playthrough.sh <policy> [scale]` — a bot plays the real game (`work|later|poker|mixed|burnout|false|aware|loop`).
