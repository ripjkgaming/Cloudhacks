extends Node
## QA bot: plays the real game through the real UI code paths with a chosen policy.
## Run (see tests/run_playthrough.sh):
##   godot --headless --path . -- --bot --policy=work --scale=12
## Policies: work | later | poker | mixed | burnout | false | aware | loop
## It auto-advances dialogue, answers choices, drives the computer, and plays minigames.

var main: Node
var args: PackedStringArray
var policy := "mixed"
var shots_dir := ""
var max_seconds := 600.0
var _started := false
var _busy := false
var _t := 0.0
var _turns := 0
var _last_day := 0
var _log: Array = []
var _stall := 0.0
var _last_sig := ""
var _gym_done := {}
var _poker_hands := 0
var _outing_steps := 0
var _shot_n := 0
var _day_turns := 0
var _turn_day := 0

func _ready() -> void:
	for a in args:
		if a.begins_with("--policy="):
			policy = a.get_slice("=", 1)
		elif a.begins_with("--scale="):
			Engine.time_scale = float(a.get_slice("=", 1))
		elif a.begins_with("--shots="):
			shots_dir = a.get_slice("=", 1)
		elif a.begins_with("--max="):
			max_seconds = float(a.get_slice("=", 1))
		elif a.begins_with("--seed="):
			seed(int(a.get_slice("=", 1)))
	Settings.master_volume = 0.0
	print("[bot] policy=%s scale=%s" % [policy, Engine.time_scale])

func log_line(s: String) -> void:
	_log.append(s)
	print("[bot] ", s)

func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.001)
	if not _started:
		if main.location == "menu" and main._menu != null and is_instance_valid(main._menu) and UI._fade.modulate.a < 0.1:
			_started = true
			log_line("start new game")
			main._on_menu("new")
		return
	if _t > max_seconds:
		_finish("TIMEOUT")
		return
	_pump()
	if int(_t) % 10 == 0 and int(_t) != int(_t - delta / maxf(Engine.time_scale, 0.001)):
		print("[bot] t=%d frames=%d locked=%s adv=%s choice=%s screens=%d" % [int(_t), Engine.get_process_frames(), Days.locked, UI._awaiting_advance, UI._awaiting_choice, UI._screen_layer.get_child_count()])
	# deadlock watchdog: same signature for 60 real-time-scaled seconds
	var sig := "%s|%s|%s|%s|%s" % [GameState.day, GameState.block, Days.locked, UI._awaiting_advance, main.location]
	if sig == _last_sig:
		_stall += delta / maxf(Engine.time_scale, 0.001)
	else:
		_stall = 0.0
		_last_sig = sig
	if _stall > 90.0:
		_finish("STALL at " + sig)
		return
	if main.location == "menu" and _turns > 0 and not Endings.running:
		_finish("ENDING menu")
		return
	if GameState.day != _last_day:
		_last_day = GameState.day
		log_line("day %d (avoid=%d, pressure=%.0f, fatigue=%.0f, sections=%d)" % [GameState.day, GameState.stats["avoidance_count"], GameState.get_psy("pressure"), GameState.get_psy("fatigue"), GameState.essay_sections_done])
		shot("day%d" % GameState.day)
	if not _busy and not Days.locked and UI.gameplay_active and not UI.is_blocking():
		_take_turn()

func shot(name: String) -> void:
	if shots_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(shots_dir)
	_shot_n += 1
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [shots_dir, _shot_n, name])

func _finish(reason: String) -> void:
	set_process(false)
	var ends: Array = Saves.meta.get("endings", {}).keys()
	print("[bot] RESULT policy=%s reason=%s day=%d endings=%s stats=%s psy=%s" % [policy, reason, GameState.day, str(ends), JSON.stringify(GameState.stats), JSON.stringify(GameState.psy)])
	get_tree().quit(0 if reason.begins_with("ENDING") else 1)

# ------------------------------------------------------------------ prompts

func _pump() -> void:
	if UI._awaiting_choice and UI._awaiting_advance == false and UI.current_options.size() > 0 and UI.busy_dialogue:
		var idx := _answer(UI.current_options)
		UI._choice_done.emit(idx)
		return
	if UI._awaiting_choice and UI.busy_dialogue:
		var idx2 := _answer(UI.current_options)
		UI._choice_done.emit(idx2)
		return
	if UI._awaiting_advance and not UI._awaiting_choice:
		UI._advance.emit()
	for s in UI._screen_layer.get_children():
		_handle_screen(s)

func _answer(opts: Array) -> int:
	var joined := " | ".join(opts)
	log_line("choice: " + joined)
	for i in opts.size():
		var o: String = opts[i]
		if o == "BREAK THE CYCLE":
			return i if policy in ["aware", "work"] else opts.find("KEEP PLAYING")
		if o == "KEEP PLAYING":
			continue
		if o.begins_with("Sleep") and not o.contains("early"):
			return i
	if opts.has("Walk out"):
		return 0 if policy == "aware" else 1
	if opts.has("Clean it up"):
		return 0 if policy == "false" else 1
	if opts.has("Head outside"):
		return 1
	if opts.has("Sit and hang out"):
		return opts.find("Sit and hang out")
	if opts.has("On my way"):
		return opts.find("Put it down")
	if opts.has("Keep looking"):
		return 2
	return 0

func _handle_screen(s: Node) -> void:
	if s is CustomizationUI:
		s.confirmed.emit()
	elif s is ComputerUI:
		_computer(s)
	elif s is WritingGame:
		_writing(s)
	elif s is PokerGame:
		_poker(s)
	elif s is GymGame:
		_gym(s)

func _computer(c: ComputerUI) -> void:
	if c.has_meta("bot_done") or c._busy:
		return
	if not c.has_meta("opened"):
		c.set_meta("opened", true)
		c._open_assignment()
		return
	if c._assignment_open and c._window != null:
		c.set_meta("bot_done", true)
		var id := _choose_activity()
		log_line("day %d block %d -> %s" % [GameState.day, GameState.block, id])
		if _shot_n < 40:
			shot("computer_d%d" % GameState.day)
		c._decide(id)

func _choose_activity() -> String:
	var day := GameState.day
	match policy:
		"work":
			return "start_essay"
		"later":
			return "later"
		"poker":
			return ["poker", "later"][_turns % 2]
		"burnout":
			return ["gym", "poker", "smoke", "videos"][_turns % 4]
		"false":
			return ["clean", "organize", "research", "gym", "organize"][_turns % 5]
		"aware":
			if GameState.cycle_broken:
				return "breathe"
			return ["later", "breathe", "later", "breathe"][_turns % 4]
		"loop":
			return ["friends", "poker", "videos", "later"][_turns % 4]
		_:
			return ["friends", "gym", "later", "poker", "videos", "smoke", "console"][_turns % 7]

func _writing(w: WritingGame) -> void:
	if w._finished:
		return
	if w._stage == "pick":
		var secs: Array = w._sections()
		if w._section < secs.size() and w._cards_box.get_child_count() > 0:
			for card in secs[w._section]["cards"]:
				if int(card["q"]) == 2:
					w._pick(card)
					break
	elif w._stage == "type":
		for ch in w._target:
			var ev := InputEventKey.new()
			ev.pressed = true
			ev.unicode = ch.unicode_at(0)
			w._input(ev)
	elif w._stage == "between":
		if w._next_box.get_child_count() > 0:
			w._show_pick()

func _poker(p: PokerGame) -> void:
	if p._closed:
		return
	if p._btn_next.visible:
		_poker_hands += 1
		if _poker_hands >= 3:
			_poker_hands = 0
			p._on_leave()
		else:
			p._next.emit()
	elif not p._btn_call.disabled:
		if _shot_n < 40 and not p.has_meta("shot"):
			p.set_meta("shot", true)
			shot("poker")
		p._choose("call")

func _gym(g: GymGame) -> void:
	if g._done:
		return
	match g.mode:
		"bench", "dumbbell":
			if absf(g._marker_x - g._zone_c) < g._zone_w * 0.4:
				g._press_rep()
		"bag":
			g._fill = 1.0
		"treadmill":
			g._hold = absf(g._marker_x - g._zone_c) > 0.02 and g._marker_x < g._zone_c
	if g.mode == "treadmill":
		pass

# ------------------------------------------------------------------ free roam turns

func _take_turn() -> void:
	_busy = true
	_turns += 1
	if _turn_day != GameState.day:
		_turn_day = GameState.day
		_day_turns = 0
	_day_turns += 1
	if Days.endgame_mode:
		log_line("endgame: leave room")
		await Days.on_interact("door")
	elif main.location == "neighborhood":
		await _outdoor_turn()
	elif GameState.cycle_broken and policy == "aware" and not GameState.essay_done and _day_turns >= 2:
		log_line("aware: walk out")
		await Days.on_interact("door")
	elif GameState.block >= 3 or _day_turns > 3:
		await Days.on_interact("bed")
	else:
		await Days.on_interact("pc")
	# give the pump a few frames before next turn
	for i in 10:
		await get_tree().process_frame
	_busy = false

func _outdoor_turn() -> void:
	_outing_steps += 1
	if _outing_steps == 1:
		if Days.outing["committed"] == "gym":
			await Days.on_interact("gym_bench")
			return
		await Days.on_interact("friend_sam")
		return
	if _outing_steps == 2 and Days.outing["committed"] == "gym":
		await Days.on_interact("gym_bag")
		return
	_outing_steps = 0
	await Days.on_interact("home_door")
