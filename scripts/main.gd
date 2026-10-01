extends Node
## Scene orchestrator: menus, world switching, pause, minigame hosting and the
## cutscene hooks the story sequences call. Game *meaning* lives in Days.

var player: Player
var bedroom: Bedroom
var neighborhood: Neighborhood
var world: Node3D
var location := "menu"
var _menu: Control
var _pause: Control
var _settings: Control
var _paused := false
var _booting := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Days.main = self
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	UI.set_black()
	_register_hooks()
	DisplayServer.window_set_title("CYCLE")
	await return_to_menu()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot"):
			var bot: Node = load("res://tests/bot.gd").new()
			bot.main = self
			bot.args = OS.get_cmdline_user_args()
			add_child(bot)

func _process(delta: float) -> void:
	if UI.gameplay_active and not _paused:
		GameState.run_seconds += delta

# ====================================================================== menus

func return_to_menu() -> void:
	Days.locked = true
	Endings.running = false
	_unpause()
	UI.gameplay_active = false
	UI.show_hud(false)
	UI.reset_blocking()
	Narrative.set_state("NORMAL", 3.0)
	_clear_world()
	location = "menu"
	Audio.set_ambience("none")
	Audio.restore()
	Audio.set_music("lofi1", 2.0)
	if _menu and is_instance_valid(_menu):
		_menu.queue_free()
	await UI.fade_to(Color.BLACK, 0.01)
	_menu = Menus.main_menu(_on_menu)
	UI.open_screen(_menu)
	await UI.fade_clear(1.2)

func _on_menu(choice: String) -> void:
	match choice:
		"new": _new_game()
		"continue": _continue_game()
		"settings": _open_settings()
		"quit": get_tree().quit()

func _open_settings() -> void:
	if _settings and is_instance_valid(_settings):
		return
	_settings = SettingsMenu.new()
	_settings.process_mode = Node.PROCESS_MODE_ALWAYS
	_settings.closed.connect(func():
		UI.close_screen(_settings)
		_settings = null)
	UI.open_screen(_settings)

func _close_menu() -> void:
	if _menu and is_instance_valid(_menu):
		UI.close_screen(_menu)
		_menu = null

func _new_game() -> void:
	_close_menu()
	await UI.fade_to(Color.BLACK, 0.8)
	GameState.reset_run(false)
	GameState.custom = GameState.default_custom()
	Saves.delete_save()
	await UI.run_sequence("opening")
	await UI.seq_bg(0.0, 0.1)
	var cu := CustomizationUI.new()
	UI.open_screen(cu)
	await UI.fade_clear(1.0)
	await cu.confirmed
	await UI.fade_to(Color.BLACK, 0.8)
	UI.close_screen(cu)
	Days.locked = false
	await Days.begin_day(1)

func _continue_game() -> void:
	_close_menu()
	await UI.fade_to(Color.BLACK, 0.6)
	if not Saves.load_game():
		await return_to_menu()
		return
	Days.locked = false
	await Days.begin_day(GameState.day, true)

# ====================================================================== world

func _clear_world() -> void:
	for c in world.get_children():
		c.queue_free()
	bedroom = null
	neighborhood = null

func _ensure_player() -> void:
	if player == null or not is_instance_valid(player):
		player = Player.new()
		player.name = "Player"
		add_child(player)
	player.cam.top_level = false
	player.cam.transform = Transform3D.IDENTITY
	player.set_cull_cutscene(false)
	player.refresh_look()

func enter_bedroom(spawn: String = "bed") -> void:
	_clear_world()
	_ensure_player()
	location = "bedroom"
	GameState.location = "bedroom"
	bedroom = Bedroom.new()
	world.add_child(bedroom)
	bedroom.player = player
	bedroom.mirror.setup(player, bedroom, Vector2(0.8, 1.7))
	bedroom.activated.connect(func(id): Days.on_interact(id))
	var sp: Array = bedroom.spawn_point(spawn)
	player.set_pose(sp[0], sp[1])
	player.lock(false)
	await get_tree().process_frame

func enter_neighborhood(spawn: String = "door") -> void:
	_clear_world()
	_ensure_player()
	location = "neighborhood"
	GameState.location = "neighborhood"
	neighborhood = Neighborhood.new()
	world.add_child(neighborhood)
	neighborhood.player = player
	neighborhood.activated.connect(func(id): Days.on_interact(id))
	var sp: Array = neighborhood.spawn_point(spawn)
	player.set_pose(sp[0], sp[1])
	player.lock(false)
	await get_tree().process_frame

## Host a full-screen minigame control and wait for its result.
func run_minigame(ctl: Control) -> Dictionary:
	UI.open_screen(ctl)
	var res = await ctl.finished
	UI.close_screen(ctl)
	return res if res is Dictionary else {}

# ====================================================================== pause

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _paused:
			_unpause()
		elif UI.gameplay_active and not UI.is_blocking() and not Days.locked and location != "menu":
			_do_pause()
		get_viewport().set_input_as_handled()

func _do_pause() -> void:
	_paused = true
	get_tree().paused = true
	_pause = Menus.pause_menu(_on_pause_choice)
	UI.open_screen(_pause)

func _unpause() -> void:
	if not _paused:
		return
	_paused = false
	get_tree().paused = false
	if _pause and is_instance_valid(_pause):
		UI.close_screen(_pause)
	_pause = null

func _on_pause_choice(choice: String) -> void:
	match choice:
		"resume": _unpause()
		"save":
			Saves.save_game()
			UI.toast("Saved.")
		"settings": _open_settings()
		"menu":
			_unpause()
			return_to_menu()
		"quit": get_tree().quit()

# ====================================================================== cutscene hooks

func _register_hooks() -> void:
	UI.hooks["turn_to_viewer"] = _hook_turn_to_viewer
	UI.hooks["turn_back"] = _hook_turn_back
	UI.hooks["look_at_monitor"] = _hook_look_at_monitor
	UI.hooks["monitor_text"] = _hook_monitor_text
	UI.hooks["look_back_up"] = _hook_look_back_up

func _hook_turn_to_viewer(_args: Dictionary) -> void:
	if bedroom == null:
		return
	player.lock(true)
	var m := bedroom.mirror
	m.uncanny = 0.0
	player.set_cull_cutscene(true)
	var fwd := -player.global_transform.basis.z
	var face := player.global_position + Vector3(0, 1.58, 0)
	var cam_pos := face + fwd * 1.6
	var xf := Transform3D(Basis.looking_at(face - cam_pos, Vector3.UP), cam_pos)
	m.avatar.look_at_node(player.cam)
	await player.cam_move_to(xf, 3.5)

func _hook_turn_back(_args: Dictionary) -> void:
	if bedroom == null:
		return
	await player.cam_release(1.5)
	player.set_cull_cutscene(false)
	bedroom.mirror.avatar.clear_look()

func _hook_look_at_monitor(_args: Dictionary) -> void:
	if bedroom == null:
		return
	player.lock(true)
	var pos := Vector3(1.0, 1.14, -1.82)
	var xf := Transform3D(Basis.looking_at(Vector3(1.0, 1.1, -2.3) - pos, Vector3.UP), pos)
	await player.cam_move_to(xf, 4.5)

func _hook_monitor_text(args: Dictionary) -> void:
	if bedroom == null:
		return
	bedroom.set_monitor_text(String(args.get("text", "")))
	Audio.play_sfx("buzz", -6.0)

func _hook_look_back_up(_args: Dictionary) -> void:
	if bedroom == null:
		return
	bedroom.set_monitor_text("")
	await player.cam_release(1.2)
