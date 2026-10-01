extends Node
## Autosave after major decisions. Two files: the run (save.json) and
## cross-run meta (meta.json: endings seen, loops).

const SAVE_PATH := "user://save.json"
const META_PATH := "user://meta.json"

var meta := {"endings": {}, "plays": 0}

func _ready() -> void:
	load_meta()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save")
		return false
	f.store_string(JSON.stringify(GameState.to_dict()))
	return true

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		push_warning("Corrupt save, ignoring")
		return false
	GameState.from_dict(d)
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func record_ending(id: String) -> void:
	meta["endings"][id] = true
	save_meta()

func load_meta() -> void:
	if not FileAccess.file_exists(META_PATH):
		return
	var d = JSON.parse_string(FileAccess.open(META_PATH, FileAccess.READ).get_as_text())
	if d is Dictionary:
		meta = d
		if not meta.has("endings"):
			meta["endings"] = {}

func save_meta() -> void:
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))
