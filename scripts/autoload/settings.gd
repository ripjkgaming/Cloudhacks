extends Node
## Player settings: audio, camera, accessibility, key bindings. Persisted to user://settings.cfg.

const PATH := "user://settings.cfg"

const ACTIONS := {
	"move_forward": {"label": "Move forward", "key": KEY_W},
	"move_back": {"label": "Move back", "key": KEY_S},
	"move_left": {"label": "Move left", "key": KEY_A},
	"move_right": {"label": "Move right", "key": KEY_D},
	"interact": {"label": "Interact", "key": KEY_E},
	"sprint": {"label": "Walk faster", "key": KEY_SHIFT},
	"crouch": {"label": "Crouch", "key": KEY_CTRL},
	"jump": {"label": "Jump", "key": KEY_SPACE},
	"phone": {"label": "Phone", "key": KEY_Q},
	"flashlight": {"label": "Flashlight", "key": KEY_F},
	"pause": {"label": "Pause", "key": KEY_ESCAPE},
}

var master_volume := 0.8
var music_volume := 0.7
var sfx_volume := 0.8
var mouse_sensitivity := 0.0024
var fov := 75.0
var subtitles := true
var subtitle_size := 22
var reduce_motion := false   # motion sickness reduction: no head bob, softer effects
var camera_shake := true
var colorblind := false
var bindings := {}           # action -> physical keycode

signal changed

func _ready() -> void:
	for a in ACTIONS:
		bindings[a] = ACTIONS[a]["key"]
	load_settings()
	apply_bindings()

func apply_bindings() -> void:
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		InputMap.action_erase_events(a)
		var ev := InputEventKey.new()
		ev.physical_keycode = bindings[a]
		InputMap.action_add_event(a, ev)

func rebind(action: String, keycode: int) -> void:
	bindings[action] = keycode
	apply_bindings()
	save_settings()
	changed.emit()

func accent_color() -> Color:
	return Color("ffb454") if not colorblind else Color("56b4e9")

func warn_color() -> Color:
	return Color("e8705f") if not colorblind else Color("e69f00")

func good_color() -> Color:
	return Color("8fd694") if not colorblind else Color("0072b2")

func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in ["master_volume", "music_volume", "sfx_volume", "mouse_sensitivity", "fov",
			"subtitles", "subtitle_size", "reduce_motion", "camera_shake", "colorblind"]:
		cf.set_value("settings", k, get(k))
	for a in bindings:
		cf.set_value("bindings", a, bindings[a])
	cf.save(PATH)
	changed.emit()

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in ["master_volume", "music_volume", "sfx_volume", "mouse_sensitivity", "fov",
			"subtitles", "subtitle_size", "reduce_motion", "camera_shake", "colorblind"]:
		if cf.has_section_key("settings", k):
			set(k, cf.get_value("settings", k))
	for a in ACTIONS:
		if cf.has_section_key("bindings", a):
			bindings[a] = int(cf.get_value("bindings", a))
