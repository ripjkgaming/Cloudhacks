extends Node
## Narrative state machine. Each state is a *profile* that audio, lighting,
## post-processing and the HUD read from; profiles blend smoothly.

const STATES := ["NORMAL", "ANXIETY", "AVOIDANCE", "RELIEF", "INTENSIFICATION", "PRESSURE",
		"RECOGNITION", "FOURTH_WALL", "CONFRONTATION", "ESCAPE", "LOOP", "ENDING"]

## vignette: edge darkness. distort: screen wobble/chroma. muffle: low-pass on audio.
## heart: heartbeat volume. light: lamp energy multiplier. warm: 1 warm .. 0 cool.
## contrast/sat: post grade. music: music volume multiplier. flicker: lamp instability.
## static_light: 1 = lighting frozen/flat (fourth wall). choices: which choice menu flavour.
const PROFILES := {
	"NORMAL":          {"vignette": 0.10, "distort": 0.0,  "muffle": 0.0, "heart": 0.0, "light": 1.0,  "warm": 1.0,  "contrast": 1.0,  "sat": 1.0,  "music": 1.0, "flicker": 0.0, "static_light": 0.0},
	"ANXIETY":         {"vignette": 0.55, "distort": 0.35, "muffle": 0.65, "heart": 1.0, "light": 0.85, "warm": 0.6,  "contrast": 1.05, "sat": 0.85, "music": 0.5, "flicker": 0.0, "static_light": 0.0},
	"AVOIDANCE":       {"vignette": 0.15, "distort": 0.0,  "muffle": 0.0, "heart": 0.1, "light": 0.95, "warm": 0.8,  "contrast": 1.0,  "sat": 1.0,  "music": 1.0, "flicker": 0.0, "static_light": 0.0},
	"RELIEF":          {"vignette": 0.05, "distort": 0.0,  "muffle": 0.0, "heart": 0.0, "light": 1.1,  "warm": 1.0,  "contrast": 0.95, "sat": 1.1,  "music": 1.1, "flicker": 0.0, "static_light": 0.0},
	"INTENSIFICATION": {"vignette": 0.45, "distort": 0.2,  "muffle": 0.3, "heart": 0.6, "light": 0.8,  "warm": 0.45, "contrast": 1.3,  "sat": 0.9,  "music": 0.7, "flicker": 0.3, "static_light": 0.0},
	"PRESSURE":        {"vignette": 0.35, "distort": 0.1,  "muffle": 0.2, "heart": 0.4, "light": 0.75, "warm": 0.35, "contrast": 1.1,  "sat": 0.8,  "music": 0.7, "flicker": 0.15, "static_light": 0.0},
	"RECOGNITION":     {"vignette": 0.4,  "distort": 0.05, "muffle": 0.5, "heart": 0.3, "light": 0.7,  "warm": 0.3,  "contrast": 1.1,  "sat": 0.6,  "music": 0.2, "flicker": 0.0, "static_light": 0.5},
	"FOURTH_WALL":     {"vignette": 0.5,  "distort": 0.0,  "muffle": 1.0, "heart": 0.0, "light": 0.65, "warm": 0.2,  "contrast": 1.15, "sat": 0.3,  "music": 0.0, "flicker": 0.0, "static_light": 1.0},
	"CONFRONTATION":   {"vignette": 0.3,  "distort": 0.1,  "muffle": 0.2, "heart": 0.5, "light": 0.9,  "warm": 0.6,  "contrast": 1.1,  "sat": 1.0,  "music": 0.5, "flicker": 0.0, "static_light": 0.0},
	"ESCAPE":          {"vignette": 0.0,  "distort": 0.0,  "muffle": 0.0, "heart": 0.0, "light": 1.35, "warm": 1.0,  "contrast": 0.95, "sat": 1.15, "music": 1.0, "flicker": 0.0, "static_light": 0.0},
	"LOOP":            {"vignette": 0.3,  "distort": 0.25, "muffle": 0.2, "heart": 0.3, "light": 0.8,  "warm": 0.4,  "contrast": 1.2,  "sat": 0.7,  "music": 0.6, "flicker": 0.2, "static_light": 0.0},
	"ENDING":          {"vignette": 0.0,  "distort": 0.0,  "muffle": 0.0, "heart": 0.0, "light": 1.0,  "warm": 1.0,  "contrast": 1.0,  "sat": 1.0,  "music": 0.0, "flicker": 0.0, "static_light": 0.0},
}

var current := {}          # blended profile, updated every frame
var target_state := "NORMAL"
var _returns_to := ""
var _return_timer := 0.0
var _blend_speed := 2.0

func _ready() -> void:
	current = PROFILES["NORMAL"].duplicate()
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_state(state: String, blend: float = 2.0, return_after: float = 0.0, return_to: String = "") -> void:
	if not PROFILES.has(state):
		push_warning("Unknown narrative state " + state)
		return
	target_state = state
	GameState.narrative_state = state
	_blend_speed = blend
	_returns_to = return_to
	_return_timer = return_after
	Events.narrative_state_changed.emit(state)

## The calm baseline for the current psychological situation.
func baseline_state() -> String:
	if GameState.cycle_broken:
		return "ESCAPE"
	if GameState.get_psy("avoidance") >= 55 or GameState.get_psy("pressure") >= 60:
		return "PRESSURE"
	return "NORMAL"

func settle(blend: float = 2.0) -> void:
	set_state(baseline_state(), blend)

func _process(delta: float) -> void:
	if _return_timer > 0.0:
		_return_timer -= delta
		if _return_timer <= 0.0:
			set_state(_returns_to if _returns_to != "" else baseline_state(), _blend_speed)
	var tgt: Dictionary = PROFILES[target_state]
	var t := clampf(delta * _blend_speed, 0.0, 1.0)
	for k in tgt:
		current[k] = lerpf(current[k], tgt[k], t)
