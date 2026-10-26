extends SceneTree
## Headless checks of the run model: save/load round trip, variable ranges and drift, delayed
## consequences, narrative profiles, settings persistence and rebinding.
## Run: godot --headless --path . -s tests/state_test.gd   (see tests/run_unit.sh)
## Writes only to user:// (use a throwaway HOME in CI), and restores nothing it does not own.

var _fails := 0
var _checks := 0

func ok(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", label)

func _init() -> void:
	# autoloads are instanced just after _init; run the checks on the first idle frame
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var gs: Node = root.get_node("GameState")
	var saves: Node = root.get_node("Saves")
	var psych: Node = root.get_node("Psychology")
	var narr: Node = root.get_node("Narrative")
	var settings: Node = root.get_node("Settings")
	test_save_roundtrip(gs, saves)
	test_ranges_and_drift(gs, psych)
	test_delayed(gs, psych)
	test_narrative(narr)
	test_settings(settings)
	test_intensification_and_loop(gs, psych)
	print("[state] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)

func snapshot(gs: Node) -> String:
	return JSON.stringify(gs.to_dict(), "", true)

func test_save_roundtrip(gs: Node, saves: Node) -> void:
	gs.reset_run(false)
	gs.day = 4
	gs.block = 2
	gs.psy["anxiety"] = 37.5
	gs.psy["pressure"] = 91.0
	gs.psy["fatigue"] = 12.25
	gs.stats["avoidance_count"] = 7
	gs.stats["later_count"] = 3
	gs.stats["inspected"] = {"pc": 9, "bed": 2}
	gs.stats["last_assignment_seconds"] = 4.5
	gs.flags = {"fw1": true, "pending_intensification": 2, "intens_1": true}
	gs.delayed = [{"day": 5, "effects": {"pressure": 5.0, "anxiety": 4.0}}]
	gs.custom = gs.default_custom()
	gs.custom["shirt_color"] = 3
	gs.essay_sections_done = 2
	gs.cycle_broken = true
	gs.loops = 1
	gs.subject = "the role of public libraries"
	gs.run_seconds = 123.5
	var before := snapshot(gs)
	ok(saves.save_game(), "save_game writes the file")
	gs.reset_run(false)
	ok(snapshot(gs) != before, "reset really clears the state")
	ok(saves.load_game(), "load_game reads the file")
	var after := snapshot(gs)
	ok(before == after, "save/load round trip is identical\n  before: %s\n  after:  %s" % [before, after])
	ok(typeof(gs.stats["avoidance_count"]) == TYPE_INT, "integer stats stay integers after load")
	ok(typeof(gs.day) == TYPE_INT and typeof(gs.delayed[0]["day"]) == TYPE_INT, "day numbers stay integers after load")
	saves.delete_save()
	ok(not saves.has_save(), "delete_save removes the file")
	# a corrupt save is ignored, not fatal
	var f := FileAccess.open(saves.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f = null
	ok(not saves.load_game(), "corrupt save is rejected")
	saves.delete_save()

func test_ranges_and_drift(gs: Node, psych: Node) -> void:
	gs.reset_run(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var ids: Array = psych.data["activities"].keys()
	var in_range := true
	for i in 400:
		var id: String = ids[rng.randi() % ids.size()]
		psych.commit_choice(id)
		if i % 4 == 3:
			gs.day += 1
			psych.on_day_start()
		for v in gs.VARS:
			var x: float = gs.get_psy(v)
			if x < 0.0 or x > 100.0:
				in_range = false
	ok(in_range, "hidden variables stay within 0..100 over 400 random choices")
	gs.reset_run(false)
	for i in 6:
		psych.commit_choice("later")
	ok(gs.get_psy("avoidance") >= 55.0, "repeated avoidance raises the avoidance variable (%.0f)" % gs.get_psy("avoidance"))
	ok(gs.stats["avoidance_count"] == 6, "avoidance count tracks each avoidant choice")
	ok(gs.has_flag("intens_1") and gs.has_flag("intens_2"), "intensification thresholds fired")
	gs.reset_run(false)
	var a0: float = gs.get_psy("avoidance")
	psych.commit_choice("start_essay")
	ok(gs.get_psy("avoidance") <= a0, "working never raises avoidance")
	ok(gs.get_psy("self_awareness") > 0.0, "working raises self-awareness a little")

func test_delayed(gs: Node, psych: Node) -> void:
	gs.reset_run(false)
	gs.day = 1
	var before_pressure: float = gs.get_psy("pressure")
	psych.commit_choice("later")
	var queued: int = gs.delayed.size()
	ok(queued == 1, "avoidance queues a delayed consequence")
	var after_choice: float = gs.get_psy("pressure")
	ok(after_choice > before_pressure, "hidden pressure lands immediately")
	gs.day = 2
	psych.on_day_start()
	ok(gs.delayed.size() == 0, "delayed consequence is consumed when its day arrives")
	ok(gs.get_psy("pressure") > after_choice, "delayed pressure lands the next morning")
	# a consequence for a later day waits
	gs.delayed = [{"day": 5, "effects": {"pressure": 20.0}}]
	var p: float = gs.get_psy("pressure")
	gs.day = 3
	psych.on_day_start()
	ok(gs.delayed.size() == 1, "future consequences stay queued")
	ok(gs.get_psy("pressure") >= p, "deadline pressure still accrues")

func test_narrative(narr: Node) -> void:
	for state in narr.PROFILES:
		ok(narr.PROFILES[state].keys().size() == narr.PROFILES["NORMAL"].keys().size(), "profile %s has every channel" % state)
	ok("ANXIETY" in narr.STATES and narr.PROFILES.has("ENDING"), "states and profiles agree")
	narr.set_state("ANXIETY", 50.0)
	for i in 5:
		narr._process(0.1)
	ok(absf(float(narr.current["vignette"]) - float(narr.PROFILES["ANXIETY"]["vignette"])) < 0.01, "narrative blends to the target profile")
	narr.set_state("NOT_A_STATE", 1.0)
	ok(narr.target_state == "ANXIETY", "unknown narrative state is ignored")
	narr.set_state("AVOIDANCE", 50.0, 0.2, "RELIEF")
	for i in 5:
		narr._process(0.1)
	ok(narr.target_state == "RELIEF", "timed state returns to its follow-up state")
	narr.set_state("NORMAL", 50.0)

func test_settings(s: Node) -> void:
	var old_fov: float = s.fov
	var old_key: int = s.bindings["interact"]
	s.fov = 91.0
	s.reduce_motion = true
	s.subtitles = false
	s.rebind("interact", KEY_G)
	s.save_settings()
	s.fov = 60.0
	s.reduce_motion = false
	s.subtitles = true
	s.bindings["interact"] = KEY_E
	s.load_settings()
	s.apply_bindings()
	ok(is_equal_approx(s.fov, 91.0) and s.reduce_motion and not s.subtitles, "settings persist across load")
	ok(s.bindings["interact"] == KEY_G, "rebound key persists")
	var evs := InputMap.action_get_events("interact")
	ok(evs.size() == 1 and evs[0] is InputEventKey and evs[0].physical_keycode == KEY_G, "InputMap follows the rebinding")
	s.fov = old_fov
	s.reduce_motion = false
	s.subtitles = true
	s.rebind("interact", old_key)
	s.save_settings()

func test_intensification_and_loop(gs: Node, psych: Node) -> void:
	gs.reset_run(false)
	gs.stats["avoidance_count"] = 9
	gs.custom["hair_color"] = 2
	gs.day = 7
	gs.restart_loop()
	ok(gs.day == 1 and gs.loops == 1, "loop restarts at day 1 and counts the loop")
	ok(gs.stats["avoidance_count"] == 9, "behavioural memory survives the loop")
	ok(gs.get_psy("pressure") == 0.0 and not gs.cycle_broken, "psychology resets on loop")
	ok(gs.custom["hair_color"] == 2, "character customization survives the loop")
	gs.psy["pressure"] = 95.0
	gs.psy["fatigue"] = 80.0
	gs.day = 4
	ok(psych.is_burned_out(), "burnout needs day>=4, high pressure and fatigue")
	gs.day = 3
	ok(not psych.is_burned_out(), "no burnout before day 4")
	gs.reset_run(false)
	gs.stats["false_productive"] = 5
	ok(psych.false_productivity_reached(), "five busy-work choices reach false productivity")
	gs.essay_sections_done = 1
	ok(not psych.false_productivity_reached(), "doing real work disqualifies false productivity")
	gs.reset_run(false)
