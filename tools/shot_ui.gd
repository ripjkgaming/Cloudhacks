extends Node
## Dev tool: open each UI screen over the bedroom and save a PNG of it.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
##       res://tools/shot_ui.tscn -- --out=/tmp/ui_shots
## Used for layout review at different window sizes (see README, QA).

var _out := "/tmp/ui_shots"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	Settings.master_volume = 0.0
	_run()

func _shot(name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])

func _open(node: Control, name: String) -> void:
	UI.open_screen(node)
	await _shot(name)
	UI.close_screen(node)
	await get_tree().process_frame

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	await _shot("main_menu")
	await main._on_menu("settings")
	await _shot("settings")
	var st: Control = main._settings
	st.closed.emit()
	main._close_menu()
	await get_tree().process_frame
	GameState.reset_run(false)
	GameState.custom = GameState.default_custom()
	Days.locked = false
	await main.enter_bedroom("bed")
	UI.set_black()
	await UI.fade_clear(0.1)
	UI.show_hud(true)
	UI.gameplay_active = true
	await _shot("bedroom_hud")
	UI.bark("A line of inner voice, to check subtitle placement.")
	await _shot("bark")
	await _open(CustomizationUI.new(), "customization")
	var cui := ComputerUI.new()
	UI.open_screen(cui)
	await _shot("computer_desktop")
	cui._open_assignment()
	for i in 24:                       # click through the anxiety sequence
		await get_tree().create_timer(0.15).timeout
		UI._advance.emit()
	await _shot("computer_assignment")
	UI.close_screen(cui)
	await _open(PokerGame.new(), "poker")
	var g := GymGame.new()
	g.mode = "bench"
	await _open(g, "gym_bench")
	await _open(WritingGame.new(), "essay")
	var pause: Control = Menus.pause_menu(func(_c): pass)
	await _open(pause, "pause_menu")
	UI.say("", "A line of dialogue to check the box.")
	await _shot("dialogue")
	UI._advance.emit()
	UI.choose("Go out?", ["Head outside", "Stay in"], 1)
	await _shot("choice")
	UI._choice_done.emit(1)
	await get_tree().process_frame
	print("[ui] shots written to ", _out)
	get_tree().quit(0)
