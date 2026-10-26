extends Node
## Headless geometry checks for the two walkable maps: spawn points are not inside colliders,
## every interactable can be reached and used, and the player cannot walk off the edge.
## Run: godot --headless --path . res://tests/world_test.tscn   (see tests/run_unit.sh)
## A scene (not -s) so the autoloads exist when the world scripts compile.

const STEP := 0.25
const CAP_RADIUS := 0.28
const CAP_HEIGHT := 1.7
const REACH := 2.2                # Player.ray reaches 2.3 m

var _fails := 0
var _checks := 0
var _space: PhysicsDirectSpaceState3D
var _capsule: CapsuleShape3D

func ok(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", label)

func _ready() -> void:
	_run()

func _run() -> void:
	_capsule = CapsuleShape3D.new()
	_capsule.radius = CAP_RADIUS
	_capsule.height = CAP_HEIGHT
	var bedroom := Bedroom.new()
	add_child(bedroom)
	await _settle()
	check_map("bedroom", bedroom, ["bed", "door", "desk"], Rect2(-3.4, -2.9, 6.8, 5.8), bedroom.spawn_point)
	bedroom.queue_free()
	await get_tree().process_frame
	var hood := Neighborhood.new()
	add_child(hood)
	await _settle()
	check_map("neighborhood", hood, ["door", "gym"], Rect2(-40, -40, 80, 70), hood.spawn_point)
	print("[world] %d checks, %d failed" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)

func _settle() -> void:
	for i in 3:
		await get_tree().physics_frame
	_space = get_viewport().find_world_3d().direct_space_state

## Top of whatever floor is under (x, z): the ray starts 1 m up so ceilings and roofs are ignored.
func _floor_y(p: Vector3) -> float:
	var rq := PhysicsRayQueryParameters3D.create(Vector3(p.x, 1.0, p.z), Vector3(p.x, -1.5, p.z), 1)
	var hit := _space.intersect_ray(rq)
	return hit["position"].y if not hit.is_empty() else NAN

func _blocked(p: Vector3) -> bool:
	return not _hits(p).is_empty()

func _hits(p: Vector3) -> Array:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _capsule
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, CAP_HEIGHT / 2.0 + 0.03, 0))
	q.collision_mask = 1
	return _space.intersect_shape(q, 3)

func _describe(p: Vector3) -> String:
	var out := []
	for h in _hits(p):
		var b: Node = h["collider"]
		out.append("%s@%s" % [b.name, str(b.global_position) if b is Node3D else "?"])
	return ", ".join(out)

func check_map(label: String, map: Node, spawns: Array, bounds: Rect2, spawn_fn: Callable) -> void:
	var nx := int(bounds.size.x / STEP)
	var nz := int(bounds.size.y / STEP)
	var seen := {}
	var queue: Array = []
	var edge_cells := 0
	for s in spawns:
		var sp: Array = spawn_fn.call(s)
		var pos: Vector3 = sp[0]
		var fy := _floor_y(pos)
		ok(not is_nan(fy), "%s: spawn '%s' has floor under it" % [label, s])
		pos.y = 0.0 if is_nan(fy) else fy
		ok(not _blocked(pos), "%s: spawn '%s' %s is not inside a collider (%s)" % [label, s, pos, _describe(pos)])
		var key := Vector2i(int((pos.x - bounds.position.x) / STEP), int((pos.z - bounds.position.y) / STEP))
		if not seen.has(key):
			seen[key] = true
			queue.append(key)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var void_walkoff := 0
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in dirs:
			var n: Vector2i = c + d
			if seen.has(n):
				continue
			if n.x < 0 or n.y < 0 or n.x >= nx or n.y >= nz:
				edge_cells += 1
				continue
			var wp := Vector3(bounds.position.x + n.x * STEP, 0.0, bounds.position.y + n.y * STEP)
			var wy := _floor_y(wp)
			if is_nan(wy):
				void_walkoff += 1
				continue
			wp.y = wy
			if _blocked(wp):
				continue
			seen[n] = true
			queue.append(n)
	ok(edge_cells == 0, "%s: walkable area is enclosed (reached the search boundary %d times)" % [label, edge_cells])
	ok(void_walkoff == 0, "%s: no walkable cell borders a drop into the void (%d found)" % [label, void_walkoff])
	var interactables := 0
	var unreachable := []
	for it in map.get_children():
		if it is Interactable:
			interactables += 1
			var target: Vector3 = it.global_position
			var reachable := false
			for key in seen:
				var p := Vector3(bounds.position.x + key.x * STEP, 0.0, bounds.position.y + key.y * STEP)
				if Vector2(p.x, p.z).distance_to(Vector2(target.x, target.z)) <= REACH:
					reachable = true
					break
			if not reachable:
				unreachable.append(it.id)
	ok(interactables > 0, "%s: has interactables" % label)
	ok(unreachable.is_empty(), "%s: every interactable can be reached; unreachable: %s" % [label, str(unreachable)])
	print("[world] %s: %d walkable cells, %d interactables" % [label, seen.size(), interactables])
