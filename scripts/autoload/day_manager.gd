extends Node
## The game loop: days, time blocks, what every activity does, how the story reacts.
## Main owns scenes; Days owns *meaning*. Everything here is awaitable.

const OUTINGS := ["friends", "gym"]
const NIGHT := 3

var main: Node                       # set by Main
var locked := false                  # a scripted flow is running; ignore interactions
var endgame_mode := false            # true ending: only the door works
var outing := {"committed": "", "gym": false, "poker": false, "hangout": false}
var _last_event := ""

func _ready() -> void:
	Events.interacted.connect(func(id): _last_event = id)

# ====================================================================== helpers

func player() -> Player:
	return main.player

func bedroom() -> Bedroom:
	return main.bedroom

func is_night() -> bool:
	return GameState.block >= NIGHT

func say(text: String, speaker: String = "") -> void:
	await UI.say(speaker, text)

func computer_menu_id() -> String:
	if GameState.cycle_broken:
		return "computer_escape"
	match GameState.day:
		1: return "computer_day1"
		2: return "computer_day2"
		3: return "computer_day3"
		_: return "computer_late"

const LABELS_DAY3 := {"start_essay": "START ESSAY", "later": "DO IT LATER", "leave": "LEAVE", "distract": "DISTRACT YOURSELF"}

func label_for(id: String) -> String:
	if id == "distract":
		return LABELS_DAY3["distract"] if GameState.day >= 3 else "Distract yourself..."
	var a := Psychology.activity(id)
	var l: String = a.get("label", id)
	if GameState.day == 3 and LABELS_DAY3.has(id):
		return LABELS_DAY3[id]
	if GameState.day >= 4 and id == "start_essay" and not GameState.cycle_broken:
		return "Start essay (overdue)"
	return l

## Menu entries honouring the time of day and the intensification level.
func menu_ids(menu_id: String) -> Array:
	var ids: Array = Psychology.menu(menu_id).duplicate()
	if is_night():
		ids = ids.filter(func(i): return not (i in OUTINGS))
	if GameState.has_flag("intens_2") and not GameState.cycle_broken and "start_essay" in ids:
		ids.erase("start_essay")
		ids.append("start_essay")           # the hard thing drifts to the bottom
	return ids

func intensification_level() -> int:
	var lvl := 0
	for i in [1, 2, 3]:
		if GameState.has_flag("intens_%d" % i):
			lvl = i
	return lvl

# ====================================================================== day lifecycle

func begin_new_run() -> void:
	GameState.reset_run()
	await begin_day(1, false)

## fresh=true: arriving from a save (don't re-apply overnight psychology).
func begin_day(day: int, loaded: bool = false) -> void:
	locked = true
	endgame_mode = false
	UI.gameplay_active = false
	UI.show_hud(false)
	GameState.day = day
	if not loaded:
		GameState.block = 0
		for f in ["relief_pending", "outing_avoided"]:
			GameState.flags.erase(f)
		Psychology.on_day_start()
	outing = {"committed": "", "gym": false, "poker": false, "hangout": false}
	Narrative.set_state(Narrative.baseline_state(), 1.0)
	await main.enter_bedroom("bed")
	Audio.set_music(Audio.music_kind_for_day(day), 3.0)
	Audio.set_ambience("room")
	UI.show_hud(true)
	player().lock(true)
	await UI.fade_clear(1.6)
	player().wake_up()
	UI.day_banner("DAY %d" % day)
	Events.day_started.emit(day)
	await UI.wait(1.4)
	var l := Dialogue.pick_from_pool("narration", "wake_up")
	if not l.is_empty():
		UI.bark(l["text"])
	if day >= 4 and not GameState.cycle_broken and not GameState.has_flag("fw2"):
		GameState.set_flag("fw2")
		await UI.wait(1.5)
		await UI.run_sequence("you_back")
	GameState.run_seconds += 0.0
	Saves.save_game()
	player().lock(false)
	UI.gameplay_active = true
	locked = false

func spend_blocks(n: int) -> void:
	if n <= 0:
		return
	GameState.block = mini(NIGHT, GameState.block + n)
	Events.block_changed.emit(GameState.block)
	Events.room_state_changed.emit()
	if main.neighborhood and is_instance_valid(main.neighborhood):
		main.neighborhood.apply_time_of_day()

# ====================================================================== computer

func on_assignment_opened() -> void:
	if GameState.cycle_broken:
		Narrative.set_state("CONFRONTATION", 2.0)
		return
	var intensity := Psychology.anxiety_intensity()
	Psychology.apply({"anxiety": 5.0 + intensity * 10.0})
	var key := "anx_day_%d" % GameState.day
	var seq := "anxiety_short"
	if not GameState.has_flag(key) or GameState.stats["assignment_views"] <= 1:
		seq = "anxiety_full"
		GameState.set_flag(key)
	Events.anxiety_triggered.emit(intensity)
	await UI.run_sequence(seq)

func sit_at_computer() -> void:
	locked = true
	var p := player()
	p.lock(true)
	UI.gameplay_active = false
	p.vm.set_typing(true)
	Audio.play_sfx("creak")
	await p.cam_move_to(bedroom().monitor_view(), 0.9)
	var cui := ComputerUI.new()
	UI.open_screen(cui)
	var chosen := [""]
	cui.activity_chosen.connect(func(id): chosen[0] = id)
	await _wait_any(cui.activity_chosen, cui.closed)
	UI.close_screen(cui)
	p.vm.set_typing(false)
	if Narrative.target_state == "ANXIETY" or Narrative.target_state == "CONFRONTATION":
		Narrative.settle()
	var id: String = chosen[0]
	if id != "":
		await perform_activity(id, true)
	else:
		await p.cam_release(0.7)
		unlock()

func _wait_any(a: Signal, b: Signal) -> void:
	var done := [false]
	var cb := func(_x = null): done[0] = true
	a.connect(cb, CONNECT_ONE_SHOT)
	b.connect(cb, CONNECT_ONE_SHOT)
	while not done[0]:
		await get_tree().process_frame
	if a.is_connected(cb):
		a.disconnect(cb)
	if b.is_connected(cb):
		b.disconnect(cb)

func unlock() -> void:
	locked = false
	player().lock(false)
	UI.gameplay_active = true

# ====================================================================== activities

## Perform an activity the player has committed to. via_computer: we are seated at the desk.
func perform_activity(id: String, via_computer: bool = false) -> void:
	locked = true
	var a := Psychology.activity(id)
	if is_night() and id in OUTINGS:
		await _release_and_bark(via_computer, "It's too late to go out. Tomorrow.")
		return
	match id:
		"start_essay":
			await _do_essay(via_computer)
		"later", "leave":
			await _do_later(id, via_computer)
		"breathe":
			Psychology.commit_choice("breathe")
			await _release(via_computer)
			await UI.run_sequence("breathe")
			unlock()
		"friends":
			Psychology.commit_choice("friends")
			await _ack_avoidance()
			await _go_outside("friends", "door", "Sam: You coming out?")
		"gym":
			Psychology.commit_choice("gym")
			await _ack_avoidance()
			await _go_outside("gym", "gym", "Just a quick workout. For my health.")
		"poker":
			Psychology.commit_choice("poker")
			await _ack_avoidance()
			await _poker_session(via_computer, true)
		"console":
			Psychology.commit_choice("console")
			await _ack_avoidance()
			await _console_session(via_computer)
		"smoke":
			Psychology.commit_choice("smoke")
			await _release(via_computer)
			await _ack_avoidance()
			await UI.fade_to(Color.BLACK, 0.6)
			await UI.run_sequence("smoke_scene")
			spend_blocks(a.get("cost", 1))
			await UI.fade_clear(0.8)
			await _finish_avoidance_at_home()
		"videos", "browse":
			Psychology.commit_choice(id)
			await _ack_avoidance()
			await _release(via_computer)
			await _time_passes("One more video. Then one more. Then...", "videos")
			spend_blocks(a.get("cost", 1))
			await _finish_avoidance_at_home()
		"clean", "organize", "research", "sleep_early":
			await _chore(id, via_computer)
		_:
			push_warning("Unhandled activity " + id)
			await _release(via_computer)
			unlock()

func _release(via_computer: bool) -> void:
	if via_computer:
		await player().cam_release(0.7)

func _release_and_bark(via_computer: bool, text: String) -> void:
	await _release(via_computer)
	UI.bark(text)
	unlock()

func _do_essay(via_computer: bool) -> void:
	GameState.inc("essay_attempts")
	Psychology.commit_choice("start_essay")
	if GameState.stats["essay_attempts"] == 1:
		await UI.say("", "Absolutely not.")
		await UI.say("", "...okay, maybe.")
	var result: Dictionary = await main.run_minigame(WritingGame.new())
	var sections: int = result.get("sections", 0)
	if sections > 0:
		GameState.inc("work_sessions")
		Psychology.apply({"avoidance": -6.0 * sections, "pressure": -10.0 * sections,
				"motivation": 6.0 * sections, "self_awareness": 5.0, "anxiety": -4.0 * sections})
		GameState.delayed.append({"day": GameState.day + 1, "effects": {"pressure": -8, "anxiety": -5}})
		spend_blocks(1)
		if GameState.essay_sections_done >= 2 and not GameState.cycle_broken:
			GameState.cycle_broken = true
			Narrative.set_state("ESCAPE", 3.0)
			Audio.set_music("lofi1", 3.0)
			Events.room_state_changed.emit()
	if GameState.essay_sections_done >= GameState.ESSAY_SECTIONS:
		GameState.essay_done = true
		await _release(via_computer)
		await Endings.start("escape")
		return
	if result.get("quit", false):
		if sections == 0:
			GameState.inc("quit_essay")
		if result.get("reason", "") == "distracted":
			Psychology.commit_choice("browse")
			GameState.inc("quit_essay")
			await _release(via_computer)
			await _time_passes("Just a quick look...", "scroll")
			spend_blocks(1)
			await _finish_avoidance_at_home()
			return
	await _release(via_computer)
	Narrative.settle()
	if sections > 0:
		UI.bark("That's %d of %d sections down." % [GameState.essay_sections_done, GameState.ESSAY_SECTIONS])
	Saves.save_game()
	unlock()

func _do_later(id: String, via_computer: bool) -> void:
	if id == "later" and GameState.day >= 3 and not GameState.cycle_broken and not GameState.has_flag("fw1"):
		GameState.set_flag("fw1")
		await _release(via_computer)
		await UI.run_sequence("fourth_wall_1")
		await _do_later_effects(id, false)
		return
	await _do_later_effects(id, via_computer)

func _do_later_effects(id: String, via_computer: bool) -> void:
	Psychology.commit_choice(id)
	await _ack_avoidance()
	await _release(via_computer)
	var lines := ["*gives the monitor a very mature gesture*", "Later. Definitely later.", "The essay can wait. It's patient."]
	if GameState.day >= 2:
		lines = ["*gives the monitor a very mature gesture*", "Tomorrow-me can handle it.", "Later. Again."]
	UI.bark(Util.pick(lines))
	player().vm.reach()
	Narrative.set_state("AVOIDANCE", 1.5, 3.0)
	GameState.set_flag("relief_pending")
	await UI.wait(1.2)
	await _show_relief()
	Saves.save_game()
	unlock()

# ---- feedback beats ------------------------------------------------------

func _ack_avoidance() -> void:
	var n: int = GameState.stats["avoidance_count"]
	var t := "Avoidance."
	if n >= 6:
		t = "Again."
	elif n >= 2:
		t = "Again?"
	GameState.set_flag("relief_pending")
	await UI.text_card(t, 0.5, 26, Color(1, 1, 1, 0.65))
	Narrative.set_state("AVOIDANCE", 1.5, 2.5)

func _show_relief() -> void:
	if not GameState.has_flag("relief_pending"):
		return
	GameState.flags.erase("relief_pending")
	Events.relief_triggered.emit()
	var n: int = GameState.stats["avoidance_count"]
	var seq := "relief_short"
	if n <= 1 or not GameState.has_flag("relief_seen"):
		seq = "relief_full"
		GameState.set_flag("relief_seen")
	elif n <= 4:
		seq = "relief_mid"
	await UI.run_sequence(seq)
	var lvl := Psychology.take_pending_intensification()
	if lvl > 0:
		Events.intensification_triggered.emit(lvl)
		await UI.run_sequence("intensification_%d" % clampi(lvl, 1, 3))
	Narrative.settle()

func _finish_avoidance_at_home() -> void:
	await _show_relief()
	Saves.save_game()
	unlock()

func _time_passes(text: String, sfx_name: String = "") -> void:
	await UI.fade_to(Color.BLACK, 0.7)
	await UI.text_card(text, 1.0, 26, Color(1, 1, 1, 0.8))
	await UI.wait(0.4)
	await UI.fade_clear(0.8)

# ---- poker / console / chores ---------------------------------------------

func _poker_session(via_computer: bool, at_home: bool) -> void:
	await _release(via_computer)
	var result: Dictionary = await main.run_minigame(PokerGame.new())
	GameState.inc("minigames")
	if result.get("net", 0) > 0:
		GameState.inc("poker_wins")
	Events.minigame_finished.emit("poker", result)
	spend_blocks(1)
	var l := Dialogue.pool_text("poker", "leave")
	if l != "":
		UI.bark(l)
	if at_home:
		await _finish_avoidance_at_home()
	else:
		unlock()

func _console_session(via_computer: bool) -> void:
	await _release(via_computer)
	var g := GymGame.new()
	g.mode = "bag"
	g.title_override = "Boss fight"
	var result: Dictionary = await main.run_minigame(g)
	GameState.inc("minigames")
	spend_blocks(1)
	UI.bark("GG. The boss never stood a chance." if result.get("score", 0.0) > 0.6 else "The boss wins. Rematch later.")
	await _finish_avoidance_at_home()

func _chore(id: String, via_computer: bool) -> void:
	var a := Psychology.activity(id)
	if id == "sleep_early":
		Psychology.commit_choice(id)
		await _release(via_computer)
		await _ack_avoidance()
		spend_blocks(3)
		await end_day()
		return
	Psychology.commit_choice(id)
	await _release(via_computer)
	await _ack_avoidance()
	match id:
		"clean":
			GameState.stats["clutter"] = maxi(0, GameState.stats["clutter"] - 5)
			await _time_passes("You scrub, fold, wipe, and rearrange. The room is spotless.")
		"organize":
			await _time_passes("Folders named. Icons aligned. A colour-coded system.")
		"research":
			await _time_passes("Seventeen tabs open. Zero sentences written. Very thorough.")
	spend_blocks(a.get("cost", 1))
	Events.room_state_changed.emit()
	GameState.set_flag("relief_pending")
	if Psychology.false_productivity_reached() and not GameState.has_flag("fp_hint"):
		GameState.set_flag("fp_hint")
		UI.bark("It feels productive. It even looks productive.")
	await _finish_avoidance_at_home()

# ====================================================================== outings

func _go_outside(committed: String, spawn: String, bark_text: String) -> void:
	outing = {"committed": committed, "gym": committed == "gym", "poker": false, "hangout": committed == "friends"}
	await _release(false)
	if committed == "gym":
		spend_blocks(1)
	Audio.play_sfx("door")
	await UI.fade_to(Color.BLACK, 0.7)
	await main.enter_neighborhood(spawn)
	Audio.set_ambience("outdoor")
	Audio.set_music(Audio.music_kind_for_day(GameState.day), 1.5)
	await UI.fade_clear(1.0)
	UI.bark(bark_text)
	unlock()

func return_home(forced: bool = false) -> void:
	locked = true
	player().lock(true)
	UI.gameplay_active = false
	await UI.fade_to(Color.BLACK, 0.8)
	await main.enter_bedroom("door")
	Audio.set_ambience("room")
	var avoided: bool = GameState.has_flag("relief_pending")
	Audio.set_music(Audio.music_kind_for_day(GameState.day), 1.0)
	await UI.fade_clear(0.9)
	player().lock(false)
	var l := Dialogue.pick_from_pool("narration", "return_home")
	if not l.is_empty():
		UI.bark(l["text"])
	await UI.wait(1.2)
	if avoided:
		await _show_relief()
	if is_night():
		UI.bark("It's late. Maybe you should sleep.")
	Saves.save_game()
	unlock()

func on_outdoor_interact(id: String) -> void:
	if locked:
		return
	locked = true
	player().lock(true)
	UI.gameplay_active = false
	match id:
		"home_door":
			await return_home()
			return
		"friend_sam", "friend_priya", "friend_theo":
			_last_event = ""
			await Dialogue.run("friends", "talk_" + id.substr(7))
			if _last_event == "friends_hangout":
				await _hangout()
			elif _last_event == "play_poker":
				await _park_poker()
		"poker_table":
			await _park_poker()
		"snack":
			Psychology.apply({"relief": 3})
			Audio.play_sfx("gulp", -8.0)
			UI.bark(Dialogue.pool_text("friends", "snack", "Tasty."))
		"boombox":
			Audio.play_sfx("click")
			var kinds := ["lofi1", "lofi2", "none"]
			var k: String = kinds[randi() % kinds.size()]
			Audio.set_music(k, 0.8)
			UI.bark("The boombox plays something warm." if k != "none" else "You switch the boombox off. Birds.")
		"bench":
			Psychology.apply({"relief": 2})
			UI.bark("You sit for a minute. The sun is nice.")
		"gym_bench", "gym_dumbbell", "gym_bag", "gym_treadmill":
			await _gym_station(id)
	if not Endings.running:
		var night_out := is_night()
		if night_out:
			UI.bark("It's getting dark. Time to head home.")
			await UI.wait(1.8)
			await return_home(true)
			return
		unlock()

func _hangout() -> void:
	if outing["committed"] != "friends" and not outing["hangout"]:
		Psychology.commit_choice("friends")
		await _ack_avoidance()
	outing["hangout"] = true
	outing["committed"] = "friends"
	await UI.fade_to(Color.BLACK, 0.8)
	await UI.text_card("You sit down with them. Nobody mentions the assignment.", 1.8, 24, Color(1, 1, 1, 0.85))
	for i in 3:
		var l := Dialogue.pick_from_pool("friends", "joke")
		if not l.is_empty():
			await UI.text_card("%s: %s" % [l.get("speaker", "Sam"), l["text"]], 2.4, 22, Color(1, 1, 1, 0.9), false)
	Psychology.apply({"relief": 6})
	spend_blocks(2)
	await UI.text_card(Dialogue.pool_text("friends", "hangout_end", ""), 2.2, 22, Color(1, 1, 1, 0.8))
	main.neighborhood.apply_time_of_day()
	await UI.fade_clear(1.0)

func _park_poker() -> void:
	if not outing["poker"]:
		if outing["committed"] != "poker":
			Psychology.commit_choice("poker")
			await _ack_avoidance()
		outing["poker"] = true
	await _poker_session(false, false)
	locked = true            # _poker_session unlocks; on_outdoor_interact decides again

func _gym_station(id: String) -> void:
	if not outing["gym"]:
		Psychology.commit_choice("gym")
		outing["gym"] = true
		await _ack_avoidance()
		spend_blocks(1)
	var g := GymGame.new()
	g.mode = {"gym_bench": "bench", "gym_dumbbell": "dumbbell", "gym_bag": "bag", "gym_treadmill": "treadmill"}[id]
	var result: Dictionary = await main.run_minigame(g)
	GameState.inc("minigames")
	var score: float = result.get("score", 0.0)
	GameState.stats["fitness"] = GameState.stats.get("fitness", 0.0) + score
	Psychology.apply({"fatigue": 4.0 * score})
	UI.bark("Solid set." if score > 0.6 else "Well. That was a workout. Technically.")

# ====================================================================== bedroom objects

func on_interact(raw_id: String) -> void:
	var id := raw_id.rstrip("0123456789")
	if locked:
		return
	if main.location == "neighborhood":
		await on_outdoor_interact(raw_id)
		return
	GameState.inspect(id)
	Events.interacted.emit(id)
	if endgame_mode:
		await _endgame_interact(id)
		return
	match id:
		"pc", "chair", "monitor", "desk", "keyboard":
			if id != "pc" and GameState.get_psy("pressure") < 20:
				_bark_for(id)
				return
			await sit_at_computer()
		"bed": await _bed()
		"door": await _door()
		"mirror": _mirror()
		"trash": await _trash()
		"water":
			player().vm.drink()
			Audio.play_sfx("gulp", -6.0)
			Psychology.apply({"fatigue": -2})
			_bark_for("water")
		"phone": await _phone()
		"window": await _window()
		"console": await _console()
		"sticky": _bark_for("sticky", true)
		_: _bark_for(id)

func _bark_for(id: String, force_text: bool = false) -> void:
	var l := Dialogue.pick_from_pool("interactions", id)
	if not l.is_empty():
		UI.bark(l["text"])

func _mirror() -> void:
	GameState.inc("mirror_count")
	if GameState.stats["mirror_count"] <= 3:
		Psychology.apply({"self_awareness": 2})
	_bark_for("mirror")

func _bed() -> void:
	locked = true
	if is_night():
		var c := await UI.choose("", ["Sleep", "Not yet"], 1, "Another day done.")
		if c == 0:
			await end_day()
			return
		unlock()
		return
	_bark_for("bed_early")
	var c := await UI.choose("", ["Sleep (it's early)", "Never mind"], 1, "Sleeping now would pause everything.")
	if c == 0:
		await _chore("sleep_early", false)
		return
	unlock()

func _door() -> void:
	locked = true
	if GameState.cycle_broken and not GameState.essay_done:
		var c := await UI.choose("Leave the room?", ["Walk out", "Not yet"], 1,
				"The essay is still on the computer." if GameState.essay_sections_done > 0 else "")
		if c == 0:
			await Endings.start("awareness")
			return
		unlock()
		return
	if is_night():
		_bark_for("door_night")
		unlock()
		return
	var c := await UI.choose("Go out?", ["Head outside", "Stay in"], 1)
	if c == 0:
		await _go_outside("", "door", "Fresh air.")
		return
	unlock()

func _trash() -> void:
	locked = true
	_bark_for("trash")
	var c := await UI.choose("", ["Clean it up", "Leave it"], 1)
	if c == 0:
		await _chore("clean", false)
		return
	unlock()

func _phone() -> void:
	locked = true
	player().vm.phone(2.2)
	Audio.play_sfx("buzz", -8.0)
	UI.caption("[phone buzzes]")
	var l := Dialogue.pick_from_pool("friends", "invite_msg")
	var txt: String = "%s: %s" % [l.get("speaker", "Sam"), l.get("text", "...")] if not l.is_empty() else "No new messages."
	var c := await UI.say_with_choices("", txt, ["On my way", "Later.", "Put it down"])
	match c:
		0:
			await perform_activity("friends", false)
			return
		1:
			Psychology.commit_choice("later")
			await _ack_avoidance()
	unlock()

func _window() -> void:
	locked = true
	_bark_for("window")
	var c := await UI.choose("", ["Keep looking", "Step out for a smoke", "Never mind"], 2)
	if c == 1:
		await perform_activity("smoke", false)
		return
	unlock()

func _console() -> void:
	locked = true
	_bark_for("console")
	var c := await UI.choose("", ["Play for a bit", "Never mind"], 1)
	if c == 0:
		await perform_activity("console", false)
		return
	unlock()

# ====================================================================== end of day

func end_day() -> void:
	locked = true
	UI.gameplay_active = false
	Events.day_ended.emit(GameState.day)
	GameState.inc("sleep_count")
	player().lock(true)
	await UI.fade_to(Color.BLACK, 1.2)
	Audio.play_sfx("creak", -8.0)
	await UI.run_sequence("sleep")
	var recover := maxf(4.0, 32.0 - GameState.get_psy("pressure") * 0.28)
	Psychology.apply({"fatigue": -recover})
	if Psychology.is_burned_out():
		await Endings.start("burnout")
		return
	var day := GameState.day
	if not GameState.cycle_broken and not GameState.essay_done:
		if day == GameState.FINAL_DAY_FIRST_GATE:
			await _gate(1)
			return
		if day == GameState.FINAL_DAY_LAST_GATE:
			await _gate(2)
			return
	await begin_day(day + 1)

func _gate(which: int) -> void:
	await UI.run_sequence("final_gate" if which == 1 else "final_gate_2")
	var c := await UI.choose("", ["BREAK THE CYCLE", "KEEP PLAYING"], -1)
	await UI.seq_bg(0.0, 0.5)
	if c == 0:
		GameState.cycle_broken = true
		GameState.set_flag("broke_cycle")
		Psychology.apply({"self_awareness": 15})
		await UI.run_sequence("break_cycle")
		Narrative.set_state("ESCAPE", 1.0)
		await begin_day(GameState.day + 1)
		return
	if which == 1:
		await begin_day(GameState.day + 1)
		return
	await Endings.start(Endings.resolve_stalled())

# ====================================================================== true-ending room

func enter_endgame_room() -> void:
	endgame_mode = true

func _endgame_interact(id: String) -> void:
	if id == "door":
		locked = true
		await Endings.leave_room()
		return
	_bark_for(id)
