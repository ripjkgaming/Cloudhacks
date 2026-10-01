extends Node
## Data-driven dialogue. Conversations live in res://data/dialogue/*.json:
##   {"nodes": {"id": {"speaker","text","conditions":[],"effects":{},"set_flags":[],"next":"id",
##      "choices":[{"text","next","conditions":[],"effects":{}}], "event": "name"}},
##    "pools": {"pool_id": [{"text","speaker","conditions":[],"priority":0,"once":false}]}}
## Conditions are tiny expressions evaluated against GameState.lookup(), e.g.
##   "stats.poker_count>=3", "day==2", "flag.met_friend", "!flag.x", "avoidance>50".

signal line_requested(speaker: String, text: String)

const MAX_STEPS := 120
var _files := {}

func load_file(id: String) -> Dictionary:
	if not _files.has(id):
		_files[id] = Util.load_json("res://data/dialogue/%s.json" % id)
	return _files[id]

func load_json(path: String):
	return Util.load_json(path)

# ---- conditions -----------------------------------------------------------

func check(conditions) -> bool:
	if conditions == null:
		return true
	if conditions is String:
		return _check_one(conditions)
	for c in conditions:
		if not _check_one(String(c)):
			return false
	return true

func _check_one(expr: String) -> bool:
	expr = expr.strip_edges()
	if expr.is_empty():
		return true
	var negate := false
	if expr.begins_with("!"):
		negate = true
		expr = expr.substr(1)
	var result := false
	for op in [">=", "<=", "==", "!=", ">", "<"]:
		var i := expr.find(op)
		if i > 0:
			var lhs = GameState.lookup(expr.substr(0, i).strip_edges())
			var rhs_s := expr.substr(i + op.length()).strip_edges()
			var rhs = float(rhs_s) if rhs_s.is_valid_float() else GameState.lookup(rhs_s)
			if lhs is String:
				match op:
					"==": result = lhs == rhs_s
					"!=": result = lhs != rhs_s
			else:
				var a := float(lhs)
				var b := float(rhs)
				match op:
					">=": result = a >= b
					"<=": result = a <= b
					"==": result = is_equal_approx(a, b)
					"!=": result = not is_equal_approx(a, b)
					">": result = a > b
					"<": result = a < b
			return result != negate
	# bare path: truthy test
	var v = GameState.lookup(expr)
	result = (float(v) != 0.0) if not (v is String) else v != ""
	return result != negate

# ---- text templating ------------------------------------------------------

func fill(text: String) -> String:
	var out := text
	var guard := 0
	while guard < 32:
		guard += 1
		var a := out.find("{")
		if a < 0:
			break
		var b := out.find("}", a)
		if b < 0:
			break
		var key := out.substr(a + 1, b - a - 1)
		var val = GameState.lookup(key)
		var s: String
		if val is float:
			s = str(int(round(val)))
		else:
			s = str(val)
		out = out.substr(0, a) + s + out.substr(b + 1)
	return out

# ---- pools (callbacks) ----------------------------------------------------

## Returns the best matching line from a pool, or {} if nothing matches.
## Highest priority wins; ties are chosen randomly. "once" lines are skipped after use.
func pick_from_pool(file_id: String, pool_id: String) -> Dictionary:
	var pools: Dictionary = load_file(file_id).get("pools", {})
	var lines: Array = pools.get(pool_id, [])
	var best: Array = []
	var best_pri := -9999
	for l in lines:
		if not check(l.get("conditions", [])):
			continue
		var key := "pool_%s_%s" % [pool_id, str(l.get("text", "")).hash()]
		if l.get("once", false) and GameState.has_flag(key):
			continue
		var p := int(l.get("priority", 0))
		if p > best_pri:
			best_pri = p
			best = [l]
		elif p == best_pri:
			best.append(l)
	if best.is_empty():
		return {}
	var chosen: Dictionary = best[randi() % best.size()]
	if chosen.get("once", false):
		GameState.set_flag("pool_%s_%s" % [pool_id, str(chosen.get("text", "")).hash()])
	var out := chosen.duplicate()
	out["text"] = fill(String(chosen.get("text", "")))
	return out

func pool_text(file_id: String, pool_id: String, fallback: String = "") -> String:
	var l := pick_from_pool(file_id, pool_id)
	return l.get("text", fallback)

# ---- runner ---------------------------------------------------------------

## Runs a conversation to completion. Returns the id of the last node.
## Presentation is delegated to UI (await-based) so tests can stub it.
func run(file_id: String, start_node: String = "start") -> String:
	var nodes: Dictionary = load_file(file_id).get("nodes", {})
	var cur := start_node
	var steps := 0
	var last := cur
	while cur != "" and steps < MAX_STEPS:
		steps += 1
		if not nodes.has(cur):
			push_warning("Dialogue node missing: %s/%s" % [file_id, cur])
			break
		var n: Dictionary = nodes[cur]
		last = cur
		if not check(n.get("conditions", [])) and n.has("else"):
			cur = n["else"]
			continue
		if n.has("effects"):
			Psychology.apply(n["effects"])
		for f in n.get("set_flags", []):
			GameState.set_flag(f)
		if n.has("event"):
			Events.interacted.emit(String(n["event"]))
		var text := fill(String(n.get("text", "")))
		var speaker := String(n.get("speaker", ""))
		if n.has("pool"):
			var pl := pick_from_pool(file_id, String(n["pool"]))
			text = String(pl.get("text", ""))
			speaker = String(pl.get("speaker", speaker))
		var choices: Array = []
		for c in n.get("choices", []):
			if check(c.get("conditions", [])):
				choices.append(c)
		if text != "":
			if choices.is_empty():
				await UI.say(speaker, text)
			else:
				var idx: int = await UI.say_with_choices(speaker, text, choices.map(func(c): return fill(String(c.get("text", "")))))
				var picked: Dictionary = choices[idx]
				if picked.has("effects"):
					Psychology.apply(picked["effects"])
				for f in picked.get("set_flags", []):
					GameState.set_flag(f)
				if picked.has("event"):
					Events.interacted.emit(String(picked["event"]))
				cur = String(picked.get("next", ""))
				continue
		cur = String(n.get("next", ""))
	if steps >= MAX_STEPS:
		push_warning("Dialogue step limit hit in " + file_id)
	return last

## Say one line from a pool (if any matches). Returns true if something was said.
func say_pool(file_id: String, pool_id: String) -> bool:
	var l := pick_from_pool(file_id, pool_id)
	if l.is_empty():
		return false
	await UI.say(String(l.get("speaker", "")), String(l["text"]))
	return true
