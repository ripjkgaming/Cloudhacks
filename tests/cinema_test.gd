extends Node
## Cinema contract checks (no world needed): unknown ids return at once, `playing` is true exactly
## while a scene runs, any key skips it, nothing outlives the watchdog, reduced motion works,
## and the input lock / HUD / blocking state is restored afterwards.
## Run: godot --headless --path . res://tests/cinema_test.tscn   (see tests/run_unit.sh)

var _fails := 0
var _checks := 0

func ok(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", label)

func _ready() -> void:
	_run()

func _key() -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_SPACE
	Input.parse_input_event(ev)

func _run() -> void:
	Engine.time_scale = 8.0
	ok(not Cinema.playing, "idle at start")
	var t0 := Time.get_ticks_msec()
	await Cinema.play("no_such_scene")
	ok(Time.get_ticks_msec() - t0 < 100 and not Cinema.playing, "unknown id returns immediately")
	var ids := {"opening": {}, "wake": {"day": 2}, "day_end": {"day": 2}, "doomscroll_enter": {},
			"doomscroll_exit": {"minutes": 90}, "night_scroll": {"minutes": 50}}
	for e in ["escape", "loop", "burnout", "false_productivity", "awareness"]:
		ids["ending:" + e] = {"id": e}
	var hud_before: bool = UI.hud_visible()
	var blocking_before: bool = UI.is_blocking()
	for reduce in [false, true]:
		Settings.reduce_motion = reduce
		for key in ids:
			var id: String = key.get_slice(":", 0)
			var label := "%s%s (reduce_motion=%s)" % [id, "" if ":" not in key else " " + key.get_slice(":", 1), reduce]
			# 1) skipped by a key press
			var done := [false]
			var saw_playing := [false]
			get_tree().create_timer(0.9).timeout.connect(func():
				saw_playing[0] = Cinema.playing
				_key())
			var start := Time.get_ticks_msec()
			_play(id, ids[key], done)
			while not done[0] and Time.get_ticks_msec() - start < 20000:
				await get_tree().process_frame
			var scene_s := (Time.get_ticks_msec() - start) / 1000.0 * Engine.time_scale
			ok(done[0] and scene_s < 3.0, "%s returns right after a key press (%.1f scene-s)" % [label, scene_s])
			ok(saw_playing[0], "%s: playing is true while it runs" % label)
			ok(not Cinema.playing, "%s: playing is false afterwards" % label)
			ok(UI.hud_visible() == hud_before and UI.is_blocking() == blocking_before, "%s: HUD/blocking state restored" % label)
			await get_tree().process_frame
	# 2) un-skipped scenes finish on their own, inside the watchdog
	for id in ["opening", "doomscroll_exit", "night_scroll"]:
		var done2 := [false]
		var begin := Time.get_ticks_msec()
		_play(id, {"minutes": 60}, done2)
		while not done2[0] and Time.get_ticks_msec() - begin < 30000:
			await get_tree().process_frame
		var scene_seconds := (Time.get_ticks_msec() - begin) / 1000.0 * Engine.time_scale
		ok(done2[0] and scene_seconds <= Cinema.MAX_SECONDS + 2.0, "%s ends by itself within the watchdog (%.1f scene-s)" % [id, scene_seconds])
	# 3) --cinema=skip style: skipped before start resolves in a frame or two
	Cinema._mode = "skip"
	var t1 := Time.get_ticks_msec()
	await Cinema.play("opening")
	ok(Time.get_ticks_msec() - t1 < 1000 and not Cinema.playing, "skip mode resolves immediately")
	Cinema._mode = "play"
	# 4) abort() ends a running scene
	var done3 := [false]
	_play("opening", {}, done3)
	await get_tree().create_timer(0.4).timeout     # scaled time = scene time
	Cinema.abort()
	var t2 := Time.get_ticks_msec()
	while not done3[0] and Time.get_ticks_msec() - t2 < 3000:
		await get_tree().process_frame
	ok(done3[0], "abort() unwinds a running scene")
	Settings.reduce_motion = false
	Engine.time_scale = 1.0
	print("[cinema] %d checks, %d failed" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)

func _play(id: String, args: Dictionary, done: Array) -> void:
	await Cinema.play(id, args)
	done[0] = true
