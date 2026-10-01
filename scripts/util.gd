class_name Util
extends RefCounted
## Small static helpers shared across systems.

static var _json_cache := {}

static func load_json(path: String) -> Variant:
	if _json_cache.has(path):
		return _json_cache[path]
	if not FileAccess.file_exists(path):
		push_warning("Missing data file: " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("Invalid JSON: " + path)
		return {}
	_json_cache[path] = parsed
	return parsed

static func pick(arr: Array):
	if arr.is_empty():
		return null
	return arr[randi() % arr.size()]

static func ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

static func fmt_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
