extends Node
## Rules of the hidden psychological model. Reads data/choices.json and applies
## immediate, hidden and delayed consequences. Never exposes numbers to the player.

var data: Dictionary = {}

func _ready() -> void:
	data = Util.load_json("res://data/choices.json")

func activity(id: String) -> Dictionary:
	return data.get("activities", {}).get(id, {})

func menu(id: String) -> Array:
	return data.get("menus", {}).get(id, [])

## Apply an effect dictionary ({var: delta}). Values are clamped to 0..100.
func apply(effects: Dictionary) -> void:
	for k in effects:
		if GameState.psy.has(k):
			GameState.add_psy(k, float(effects[k]))
	check_thresholds()

## Core mechanic: record a choice, apply its immediate+hidden effects now and queue
## the delayed consequence for the start of the next day. Returns the activity dict.
func commit_choice(id: String) -> Dictionary:
	var a := activity(id)
	if a.is_empty():
		push_warning("Unknown activity " + id)
		return a
	var scale := 1.0
	# Intensification: once avoidance is established, relief feels bigger and so does the debt.
	if a.get("avoidance", false):
		scale = 1.0 + GameState.get_psy("avoidance") / 150.0
	var imm: Dictionary = a.get("immediate", {})
	var hid: Dictionary = a.get("hidden", {})
	var scaled_imm := {}
	for k in imm:
		scaled_imm[k] = imm[k] * (scale if imm[k] > 0 and k == "relief" else 1.0)
	apply(scaled_imm)
	apply(hid)
	var dl: Dictionary = a.get("delayed", {})
	if not dl.is_empty():
		var d := {}
		for k in dl:
			d[k] = dl[k] * (scale if dl[k] > 0 else 1.0)
		GameState.delayed.append({"day": GameState.day + 1, "effects": d})
	if a.get("avoidance", false):
		GameState.inc("avoidance_count")
		if GameState.stats["clutter"] < 8:
			GameState.inc("clutter")
	if a.has("stat"):
		GameState.inc(a["stat"])
	if "false_productive" in a.get("tags", []):
		GameState.inc("false_productive")
	Events.choice_made.emit(id, a.get("category", ""))
	return a

## Called at the start of every day: lands delayed consequences and deadline pressure.
func on_day_start() -> void:
	var remaining := []
	for d in GameState.delayed:
		if int(d["day"]) <= GameState.day:
			apply(d["effects"])
		else:
			remaining.append(d)
	GameState.delayed = remaining
	var dp: Dictionary = data.get("deadline_pressure", {})
	var base := float(dp.get(str(GameState.day), 14))
	if GameState.essay_sections_done > 0:
		base *= 0.5
	if not GameState.cycle_broken and not GameState.essay_done:
		add("pressure", base)
	# Overnight, short-term relief fades and anxiety rebounds a little.
	GameState.set_psy("relief", GameState.get_psy("relief") * 0.3)
	if GameState.cycle_broken:
		apply({"anxiety": -10, "pressure": -10, "avoidance": -8, "motivation": 8})
	check_thresholds()

func add(v: String, amount: float) -> void:
	GameState.add_psy(v, amount)

## 0..1 strength of the anxiety response when looking at the assignment.
func anxiety_intensity() -> float:
	if GameState.cycle_broken:
		return 0.15
	var base := 0.25 + GameState.get_psy("pressure") / 140.0 + GameState.get_psy("avoidance") / 250.0
	base += (GameState.day - 1) * 0.06
	return clampf(base, 0.2, 1.0)

func check_thresholds() -> void:
	var av: Array = data.get("intensify_thresholds", [25, 55, 85])
	for i in av.size():
		var f := "intens_%d" % (i + 1)
		if GameState.get_psy("avoidance") >= av[i] and not GameState.has_flag(f):
			GameState.set_flag(f)
			GameState.set_flag("pending_intensification", i + 1)
	var pr: Array = data.get("pressure_thresholds", [30, 60, 90])
	for i in pr.size():
		var f := "press_%d" % (i + 1)
		if GameState.get_psy("pressure") >= pr[i] and not GameState.has_flag(f):
			GameState.set_flag(f)
			Events.pressure_threshold.emit(i + 1)
			Events.room_state_changed.emit()
	if GameState.get_psy("self_awareness") >= 40 and not GameState.has_flag("awareness_unlocked"):
		GameState.set_flag("awareness_unlocked")

## Intensification is queued by thresholds and consumed at the next calm moment (see Days).
func take_pending_intensification() -> int:
	var lvl: int = int(GameState.flags.get("pending_intensification", 0))
	GameState.flags.erase("pending_intensification")
	return lvl

func is_burned_out() -> bool:
	var b: Dictionary = data.get("burnout", {})
	return GameState.day >= int(b.get("min_day", 4)) \
			and GameState.get_psy("pressure") >= float(b.get("pressure", 90)) \
			and GameState.get_psy("fatigue") >= float(b.get("fatigue", 70))

func false_productivity_reached() -> bool:
	return GameState.stats["false_productive"] >= int(data.get("false_productive_needed", 5)) \
			and GameState.essay_sections_done == 0
