extends Node
## Five endings and everything after them: credits, the closing message, returning to
## the menu — or, for LOOP, back to Day 1.
##   escape            finished the essay
##   loop              kept playing (the default avoidance outcome)
##   burnout           pressure and exhaustion overwhelm
##   false_productivity stayed busy with things that look like work
##   awareness         saw the pattern, left the room anyway

var running := false

func _main() -> Node:
	return Days.main

## Decide what happens when the player keeps playing at the last gate.
func resolve_stalled() -> String:
	if Psychology.is_burned_out():
		return "burnout"
	if Psychology.false_productivity_reached():
		return "false_productivity"
	return "loop"

func start(id: String) -> void:
	running = true
	Days.locked = true
	UI.gameplay_active = false
	Saves.record_ending(id)
	Events.ending_reached.emit(id)
	Narrative.set_state("ENDING", 1.0)
	match id:
		"escape": await _escape()
		"awareness": await _simple_ending("end_awareness")
		"burnout": await _burnout()
		"false_productivity": await _simple_ending("end_false_productivity")
		"loop": await _loop()
		_:
			push_warning("Unknown ending " + id)
			await _simple_ending("end_awareness")

func _escape() -> void:
	await UI.fade_to(Color.BLACK, 1.5)
	await UI.run_sequence("end_escape_intro")
	await UI.run_sequence("end_true")
	# Back in the bedroom: peaceful, computer off, the door is the only thing left to do.
	GameState.cycle_broken = true
	GameState.block = 0
	GameState.stats["clutter"] = 0
	Psychology.apply({"anxiety": -100, "pressure": -100, "avoidance": -100})
	await _main().enter_bedroom("desk")
	_main().bedroom.set_monitor_off()
	Audio.set_ambience("room")
	Audio.set_music("ending", 2.0)
	Narrative.set_state("ESCAPE", 0.5)
	Days.enter_endgame_room()
	Days.player().lock(false)
	await UI.fade_clear(2.0)
	UI.gameplay_active = true
	Days.locked = false
	UI.bark("The computer is off. The room is quiet.")
	GameState.set_flag("endgame_room")

## The player walks out of the door: sunlight, white, title.
func leave_room() -> void:
	Days.locked = true
	var p := Days.player()
	p.lock(true)
	UI.gameplay_active = false
	_main().bedroom.open_door()
	await UI.wait(0.6)
	await UI.fade_to(Color.WHITE, 1.4)
	await _main().enter_neighborhood("door")
	_main().neighborhood.set_bright_day()
	Audio.set_ambience("outdoor")
	p.set_pose(Vector3(0, 0, 0.3), 0.0)
	await UI.fade_clear(2.0)
	var tw := create_tween()
	tw.tween_method(func(v: float): p.global_position = Vector3(0, 0, 0.3 - v), 0.0, 3.0, 4.0)
	await tw.finished
	await UI.run_sequence("end_true_outro")
	await _credits_and_close(true)

func _burnout() -> void:
	# the room goes loud before the words arrive
	GameState.stats["clutter"] = 8
	GameState.set_psy("pressure", 100.0)
	Narrative.set_state("INTENSIFICATION", 0.5)
	Events.room_state_changed.emit()
	await UI.wait(1.5)
	await UI.fade_to(Color.BLACK, 2.0)
	await UI.run_sequence("end_burnout")
	await _credits_and_close(true)

func _simple_ending(seq: String) -> void:
	await UI.fade_to(Color.BLACK, 1.5)
	await UI.run_sequence(seq)
	await _credits_and_close(true)

func _loop() -> void:
	await UI.fade_to(Color.BLACK, 1.5)
	await UI.run_sequence("end_loop")
	GameState.restart_loop()
	await UI.run_sequence("opening_loop")
	running = false
	Days.locked = false
	await Days.begin_day(1)

func _credits_and_close(with_final_message: bool) -> void:
	await UI.run_sequence("credits")
	if with_final_message:
		await UI.run_sequence("final_message")
	running = false
	Saves.delete_save()
	await _main().return_to_menu()
