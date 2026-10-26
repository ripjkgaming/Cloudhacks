# CYCLE — finish + test megaprompt

Paste everything below the line into a fresh Claude Code session started in `~/Cloudhacks`.

---

You are finishing **CYCLE**, a Godot 4.3 (GL Compatibility) first-person narrative game about the avoidance → relief → pressure loop. It looks like a cozy life sim and is secretly about anxiety/procrastination. All art, music and SFX are generated in code. Repo: `~/Cloudhacks`. Read `README.md` first.

## Known state (verify, do not trust blindly)
- ~6300 lines GDScript. Autoloads: Events, Settings, GameState, Psychology, Narrative, Dialogue, Audio, Saves, UI, Endings, Cinema, Days (see `project.godot`).
- `scripts/autoload/cinema.gd` is a **STUB**: `play(id, args)` only awaits one frame. Contract: `await Cinema.play(id, args)`; `Cinema.playing` true while a cutscene owns the camera. Ids: `opening`, `wake {day}`, `day_end {day}`, `doomscroll_enter`, `doomscroll_exit`, `night_scroll {minutes}`, `ending {id}`. Unknown ids must return immediately.
- Endings: Escape, Loop, Burnout, False Productivity, Awareness.
- Test tooling: `tools/check.sh` (headless compile), `tests/run_playthrough.sh <work|later|poker|mixed|burnout|false|aware|loop> [scale]` (QA bot, xvfb), `tools/release.sh <version>` (Linux + Windows export to `build/`).
- Scripts default `GODOT=/tmp/godot/Godot_v4.3-stable_linux.x86_64`, which may not exist. System Godot is `/usr/bin/godot`. Run `godot --version` first. If it is not 4.3.x, download 4.3-stable to `/tmp/godot/` or export `GODOT=/usr/bin/godot` and note any version mismatch. Export presets need matching export templates; check before release.
- Ignore `.claude/worktrees/*` (stale agent worktrees). Do not edit them.

## Rules
1. Plan before editing: list all gaps found, ranked by player impact. Then execute.
2. Baseline first: run `tools/check.sh` and all 8 bot policies at scale 10. Record results. Fix compile errors before anything else.
3. Delegate repetitive, non-UI bulk work (boilerplate, data/dialogue JSON expansion, mechanical edits) to opencode: `opencode run --auto -m opencode/muse-spark-1.3-contributor-free --variant high "<brief>"`, parallel only on non-overlapping files. **Never delegate UI, visuals, layout, animation, camera work.** Review all delegated diffs.
4. Match existing code style, comment density, naming. No new external assets: keep everything code-generated.
5. Commit in small logical steps. Commit only after check.sh is clean and affected policies pass.
6. Never claim done without evidence: paste actual command output for each verification.

## Work items

### A. Implement Cinema (biggest gap)
Replace the stub with real camera-driven cutscenes honouring the contract above. Each id needs a distinct, short (3–12 s), skippable (any key / Esc) sequence built from tweened camera moves, letterbox bars, fades, text from `data/sequences.json`, and Audio cues. Requirements:
- `Cinema.playing` true for exactly the duration; player input locked then restored; camera restored on skip or scene exit.
- `ending {id}` has a unique treatment per ending. `doomscroll_enter/exit` and `night_scroll {minutes}` should visually sell time loss (pull into screen, blur/flicker, clock jump).
- Respect Settings: motion-sickness reduction (no camera shake/spin, softer moves), subtitles, shake toggle.
- Bot/headless runs must not hang: if running with `--bot`, collapse durations (scale arg) or skip. No cutscene may deadlock `Days`.

### B. Completeness audit
Grep for TODO/FIXME/stub/placeholder/`pass`-only functions and signals emitted but never connected (Events bus). For each: implement or delete with reason. Confirm every id referenced in `data/*.json` (choices, sequences, dialogue, websites, essay, assignments) resolves to code, and every code reference resolves to data. Check every ending is reachable and has its sequence text.

### C. Game-loop correctness
Verify across a full run: day progression, hidden variables (GameState/Psychology) stay in range and drift as designed, delayed consequences fire, memory/narrative profile transitions work, save/load round-trips (save mid-day, quit, load, state identical), pause menu, settings persistence, rebinding, character customization → in-world avatar/mirror.

### D. Minigames
Poker (engine correctness: hand ranking, split pots, all-in, no negative chips), gym timing games, essay-writing mechanic. Add headless unit checks for `poker_engine.gd` (deterministic seed) under `tests/`.

### E. Polish pass
Playable start-to-finish with no soft-locks: stuck-in-geometry check on Player/Neighborhood, interactable prompts, interaction during dialogue/cutscene blocked, flashlight/crouch/walk, window resize at 1280x720 and other sizes, no console errors/warnings during a full run, FPS acceptable on GL Compatibility (report numbers).

### F. Test + release
1. `tools/check.sh` → zero errors.
2. All policies `work later poker mixed burnout false aware loop` must each reach their intended ending (`aware` → Awareness, `burnout` → Burnout, etc.). Print each RESULT line. Add a policy or fix the bot if an ending is unreachable.
3. Run with `shots_dir` on at least `mixed` and `aware`; open and visually review screenshots of bedroom, neighborhood, gym, poker, computer UI, each ending, and each cutscene. Fix visible defects.
4. Fresh-clone test: `git clone` to a temp dir, import, run check + one policy, so no dependency on untracked or `.godot/` state.
5. Bump version, run `tools/release.sh 0.2.0`, confirm both zips exist and the Linux build launches (smoke-run under xvfb for ~20 s with no errors).
6. Update `README.md` (controls, endings, QA commands, known limitations).

## Final report (required)
- Table of work items A–F: done / partial / skipped, with evidence.
- Bot RESULT line per policy.
- Remaining known issues, ranked.
- Commit list.
