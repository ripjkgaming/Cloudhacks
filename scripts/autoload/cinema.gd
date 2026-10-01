extends Node
## Cinematics director (autoload "Cinema"). Plays camera-driven cutscenes by id.
## Contract used by the rest of the game:
##   await Cinema.play(id, args)   -- returns when the cutscene is finished (or skipped)
##   Cinema.playing                -- true while a cutscene owns the camera
## Known ids: "opening", "wake" {day}, "day_end" {day}, "doomscroll_enter", "doomscroll_exit",
##   "night_scroll" {minutes}, "ending" {id}. Unknown ids must return immediately.

var playing := false

func play(id: String, args: Dictionary = {}) -> void:
	await get_tree().process_frame
