class_name ViewModel
extends Node3D
## First-person arms/hands and held props, animated procedurally. Attached to the camera.

var arm_l: Node3D
var arm_r: Node3D
var held: Node3D
var typing := false
var _t := 0.0
var _rest_l := Vector3(-0.17, -0.3, -0.3)
var _rest_r := Vector3(0.17, -0.3, -0.3)
var _tw: Tween
var _sway := Vector2.ZERO

func setup(custom: Dictionary) -> void:
	var shirt := Color(Avatar.SHIRT_COLORS[clampi(custom.get("shirt_color", 0), 0, Avatar.SHIRT_COLORS.size() - 1)])
	var skin := Color(Avatar.SKIN[clampi(custom.get("skin", 2), 0, Avatar.SKIN.size() - 1)])
	var hoodie: bool = custom.get("shirt_style", 0) == 1
	for c in get_children():
		c.queue_free()
	arm_l = _make_arm(shirt, skin, hoodie, -1.0)
	arm_r = _make_arm(shirt, skin, hoodie, 1.0)
	arm_l.position = _rest_l
	arm_r.position = _rest_r
	add_child(arm_l)
	add_child(arm_r)
	Build.set_layers(self, Build.LAYER_FPS)

func _make_arm(shirt: Color, skin: Color, long_sleeve: bool, side: float) -> Node3D:
	var n := Node3D.new()
	n.rotation_degrees = Vector3(-8, -side * 6.0, 0)
	var sleeve := Build.capsule(n, 0.032, 0.38, Vector3(0, 0, 0.12), shirt)
	sleeve.rotation_degrees = Vector3(90, 0, 0)
	var fore := Build.capsule(n, 0.027, 0.3, Vector3(0, 0, -0.17), shirt if long_sleeve else skin)
	fore.rotation_degrees = Vector3(90, 0, 0)
	var hand := Build.box(n, Vector3(0.075, 0.035, 0.1), Vector3(0, 0, -0.38), skin)
	Build.box(n, Vector3(0.025, 0.02, 0.05), Vector3(side * -0.04, 0.0, -0.4), skin)  # thumb
	return n

func _process(delta: float) -> void:
	_t += delta
	if arm_l == null:
		return
	var calm := 0.6 if Settings.reduce_motion else 1.0
	var sx := sin(_t * 1.1) * 0.004 * calm
	var sy := sin(_t * 1.7) * 0.004 * calm
	var jitter := Vector3.ZERO
	if typing:
		jitter = Vector3(sin(_t * 28.0) * 0.004, absf(sin(_t * 19.0)) * 0.012, 0)
	arm_l.position = arm_l.position.lerp(_target_l() + Vector3(sx, sy, 0) + jitter, clampf(delta * 10.0, 0, 1)) if _tw == null or not _tw.is_running() else arm_l.position
	arm_r.position = arm_r.position.lerp(_target_r() + Vector3(-sx, sy, 0) - jitter, clampf(delta * 10.0, 0, 1)) if _tw == null or not _tw.is_running() else arm_r.position

var _mode_l := Vector3.ZERO
var _mode_r := Vector3.ZERO
var _use_mode := false

func _target_l() -> Vector3:
	return _mode_l if _use_mode else _rest_l

func _target_r() -> Vector3:
	return _mode_r if _use_mode else _rest_r

func set_typing(on: bool) -> void:
	typing = on
	_use_mode = on
	_mode_l = Vector3(-0.1, -0.22, -0.42)
	_mode_r = Vector3(0.1, -0.22, -0.42)

func _kill() -> void:
	if _tw and _tw.is_running():
		_tw.kill()

func reach() -> void:
	_kill()
	_tw = create_tween()
	_tw.tween_property(arm_r, "position", _rest_r + Vector3(-0.08, 0.08, -0.14), 0.12)
	_tw.tween_property(arm_r, "position", _rest_r, 0.2)

func drink() -> void:
	_kill()
	_attach_held(Build.cyl(arm_r, 0.032, 0.18, Vector3(0, 0.05, -0.38), Color(0.6, 0.8, 0.95, 0.85)))
	_tw = create_tween()
	_tw.tween_property(arm_r, "position", Vector3(0.02, -0.02, -0.28), 0.5)
	_tw.parallel().tween_property(arm_r, "rotation_degrees", Vector3(35, 0, 0), 0.5)
	_tw.tween_interval(0.7)
	_tw.tween_property(arm_r, "position", _rest_r, 0.5)
	_tw.parallel().tween_property(arm_r, "rotation_degrees", Vector3(-8, -6, 0), 0.5)
	_tw.tween_callback(_drop_held)

func phone(duration: float = 1.8) -> void:
	_kill()
	var p := Build.box(arm_l, Vector3(0.07, 0.012, 0.14), Vector3(0, 0.03, -0.4), Color("1d1f24"))
	Build.box(p, Vector3(0.06, 0.003, 0.12), Vector3(0, 0.008, 0), Color("6aa5ff"), false, 0.3)
	_attach_held(p)
	_tw = create_tween()
	_tw.tween_property(arm_l, "position", Vector3(-0.02, -0.12, -0.34), 0.35)
	_tw.parallel().tween_property(arm_l, "rotation_degrees", Vector3(40, 0, 0), 0.35)
	_tw.tween_interval(duration)
	_tw.tween_property(arm_l, "position", _rest_l, 0.35)
	_tw.parallel().tween_property(arm_l, "rotation_degrees", Vector3(-8, 6, 0), 0.35)
	_tw.tween_callback(_drop_held)

func lift_both(times: int = 1) -> void:
	_kill()
	_tw = create_tween()
	for i in times:
		_tw.tween_property(arm_l, "position", Vector3(-0.14, 0.02, -0.36), 0.35)
		_tw.parallel().tween_property(arm_r, "position", Vector3(0.14, 0.02, -0.36), 0.35)
		_tw.tween_property(arm_l, "position", _rest_l, 0.35)
		_tw.parallel().tween_property(arm_r, "position", _rest_r, 0.35)

func _attach_held(n: Node3D) -> void:
	_drop_held()
	held = n
	Build.set_layers(n, Build.LAYER_FPS)

func _drop_held() -> void:
	if held and is_instance_valid(held):
		held.queue_free()
	held = null
