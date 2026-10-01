extends Node
## Single source of truth for run data: hidden psychological variables,
## behaviour memory, flags, customization and day/time. Serializable.

const VARS := ["anxiety", "avoidance", "relief", "pressure", "motivation", "fatigue", "self_awareness"]
const INITIAL := {"anxiety": 0.0, "avoidance": 0.0, "relief": 0.0, "pressure": 0.0,
		"motivation": 50.0, "fatigue": 0.0, "self_awareness": 0.0}
const BLOCKS := ["morning", "afternoon", "evening", "night"]
const ESSAY_SECTIONS := 4
const FINAL_DAY_FIRST_GATE := 5
const FINAL_DAY_LAST_GATE := 7

var psy := {}
var day := 1
var block := 0
var location := "bedroom"
var custom := {}
var stats := {}
var flags := {}
var delayed := []            # [{day:int, effects:{}}]
var narrative_state := "NORMAL"
var essay_sections_done := 0
var essay_done := false
var subject := ""
var cycle_broken := false    # player chose BREAK THE CYCLE
var loops := 0               # how many times the cycle has restarted
var run_seconds := 0.0

func _ready() -> void:
	reset_run()

static func default_custom() -> Dictionary:
	return {"hair_style": 0, "hair_color": 0, "skin": 2, "shirt_color": 0, "shirt_style": 0,
			"pants": 0, "shoes": 0, "body": 1, "accessory": 0}

static func default_stats() -> Dictionary:
	return {
		"avoidance_count": 0, "essay_attempts": 0, "work_sessions": 0, "quit_essay": 0,
		"social_count": 0, "poker_count": 0, "poker_wins": 0, "gym_count": 0, "smoke_count": 0,
		"browse_count": 0, "console_count": 0, "sleep_count": 0, "early_sleep": 0,
		"computer_opens": 0, "assignment_views": 0, "later_count": 0, "fast_avoid": 0,
		"false_productive": 0, "clean_count": 0, "reflect_count": 0, "mirror_count": 0,
		"you_clicks": 0, "last_assignment_seconds": 0.0, "inspected": {}, "clutter": 0,
		"minigames": 0, "messages_read": 0,
	}

func reset_run(keep_loops: bool = true) -> void:
	psy = INITIAL.duplicate()
	day = 1
	block = 0
	location = "bedroom"
	stats = default_stats()
	flags = {}
	delayed = []
	narrative_state = "NORMAL"
	essay_sections_done = 0
	essay_done = false
	cycle_broken = false
	run_seconds = 0.0
	if not keep_loops:
		loops = 0
	pick_subject()

## Restart Day 1 after the LOOP ending. Memory of behaviour persists; psychology resets.
func restart_loop() -> void:
	var old_stats := stats.duplicate(true)
	var old_loops := loops + 1
	var old_custom := custom.duplicate()
	reset_run()
	stats = old_stats
	stats["clutter"] = 0
	stats["last_assignment_seconds"] = 0.0
	loops = old_loops
	custom = old_custom
	flags["loop_%d" % loops] = true

func pick_subject() -> void:
	var data: Dictionary = Util.load_json("res://data/assignments.json")
	var topics: Array = data.get("topics", ["the role of public libraries in modern communities"])
	subject = topics[randi() % topics.size()]

func get_psy(v: String) -> float:
	return psy.get(v, 0.0)

func set_psy(v: String, value: float) -> void:
	var old: float = psy.get(v, 0.0)
	psy[v] = clampf(value, 0.0, 100.0)
	if not is_equal_approx(old, psy[v]):
		Events.psy_changed.emit(v, old, psy[v])

func add_psy(v: String, amount: float) -> void:
	set_psy(v, get_psy(v) + amount)

func inc(stat: String, amount = 1) -> void:
	stats[stat] = stats.get(stat, 0) + amount

func inspect(id: String) -> int:
	var d: Dictionary = stats["inspected"]
	d[id] = d.get(id, 0) + 1
	return d[id]

func set_flag(f: String, v = true) -> void:
	flags[f] = v

func has_flag(f: String) -> bool:
	return flags.get(f, false) != false

func deadline_key() -> String:
	if essay_done:
		return "done"
	match day:
		1: return "2days"
		2: return "tomorrow"
		3: return "tonight"
		_: return "overdue"

func deadline_text() -> String:
	match deadline_key():
		"2days": return "Essay due in 2 days."
		"tomorrow": return "Essay due tomorrow."
		"tonight": return "ESSAY DUE TONIGHT."
		"done": return "Essay submitted."
		_: return "OVERDUE."

## Resolve a dotted path used by data-driven conditions and text templates.
func lookup(path: String):
	if psy.has(path):
		return psy[path]
	match path:
		"day": return day
		"block": return block
		"loops": return loops
		"sections_done": return essay_sections_done
		"essay_done": return 1 if essay_done else 0
		"cycle_broken": return 1 if cycle_broken else 0
		"subject": return subject
		"inspected_distinct": return stats["inspected"].size()
	if path.begins_with("stats."):
		var key := path.substr(6)
		if key.begins_with("inspected."):
			return stats["inspected"].get(key.substr(10), 0)
		return stats.get(key, 0)
	if path.begins_with("flag."):
		return 1 if has_flag(path.substr(5)) else 0
	if path == "state":
		return narrative_state
	return 0

func to_dict() -> Dictionary:
	return {"version": 1, "psy": psy, "day": day, "block": block, "location": location,
			"custom": custom, "stats": stats, "flags": flags, "delayed": delayed,
			"narrative_state": narrative_state, "essay_sections_done": essay_sections_done,
			"essay_done": essay_done, "subject": subject, "cycle_broken": cycle_broken,
			"loops": loops, "run_seconds": run_seconds}

func from_dict(d: Dictionary) -> void:
	reset_run()
	psy = INITIAL.duplicate()
	for k in d.get("psy", {}):
		psy[k] = clampf(float(d["psy"][k]), 0.0, 100.0)
	day = clampi(int(d.get("day", 1)), 1, 99)
	block = clampi(int(d.get("block", 0)), 0, 3)
	location = "bedroom"
	custom = default_custom()
	for k in d.get("custom", {}):
		custom[k] = int(d["custom"][k])
	var fresh := default_stats()
	var saved: Dictionary = d.get("stats", {})
	for k in fresh:
		if saved.has(k):
			fresh[k] = saved[k]
	stats = fresh
	flags = d.get("flags", {}).duplicate()
	delayed = d.get("delayed", []).duplicate(true)
	narrative_state = String(d.get("narrative_state", "NORMAL"))
	essay_sections_done = int(d.get("essay_sections_done", 0))
	essay_done = bool(d.get("essay_done", false))
	subject = String(d.get("subject", subject))
	cycle_broken = bool(d.get("cycle_broken", false))
	loops = int(d.get("loops", 0))
	run_seconds = float(d.get("run_seconds", 0.0))
