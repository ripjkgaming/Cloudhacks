class_name Player
extends CharacterBody3D
## First-person controller: smooth movement, comfortable head motion, interaction ray,
## procedural arms, and cutscene camera moves.

signal interacted_with(it: Interactable)

const WALK := 1.9
const SPRINT := 3.5
const CROUCH_SPEED := 1.0
const EYE_STAND := 1.62
const EYE_CROUCH := 1.05
const GRAVITY := 18.0

var input_enabled := true
var head: Node3D
var cam: Camera3D
var ray: RayCast3D
var flash: SpotLight3D
var vm: ViewModel
var feet: Node3D
var target: Interactable = null
var yaw := 0.0
var pitch := 0.0
var _bob := 0.0
var _t := 0.0
var _eye := EYE_STAND
var eye_speed := 8.0
var _last_step := 0
var _shape: CollisionShape3D
var _cam_tween: Tween
var _shake_seed := randf() * 100.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.7
	_shape.shape = cap
	_shape.position.y = 0.85
	add_child(_shape)
	head = Node3D.new()
	head.position.y = EYE_STAND
	add_child(head)
	cam = Camera3D.new()
	cam.current = true
	cam.near = 0.04
	cam.far = 120.0
	cam.cull_mask = Build.LAYER_WORLD | Build.LAYER_FPS
	head.add_child(cam)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.3)
	ray.collision_mask = 1 | 2
	ray.collide_with_areas = false
	ray.collide_with_bodies = true
	cam.add_child(ray)
	flash = SpotLight3D.new()
	flash.spot_range = 9.0
	flash.spot_angle = 32.0
	flash.light_energy = 1.6
	flash.visible = false
	cam.add_child(flash)
	vm = ViewModel.new()
	cam.add_child(vm)
	vm.setup(GameState.custom)
	_build_feet()
	Settings.changed.connect(_apply_settings)
	_apply_settings()

func _apply_settings() -> void:
	cam.fov = Settings.fov

## Wake up in bed: eyes open low, looking at the ceiling, then sit up.
func wake_up() -> void:
	eye_speed = 1.4
	_eye = 0.55
	pitch = deg_to_rad(55)
	var tw := create_tween()
	tw.tween_property(self, "pitch", 0.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): eye_speed = 8.0)

func refresh_look() -> void:
	vm.setup(GameState.custom)
	_build_feet()

func _build_feet() -> void:
	if feet:
		feet.queue_free()
	feet = Node3D.new()
	add_child(feet)
	var pants := Color(Avatar.PANTS_COLORS[clampi(GameState.custom.get("pants", 0), 0, Avatar.PANTS_COLORS.size() - 1)])
	var shoe := Color(Avatar.SHOE_COLORS[clampi(GameState.custom.get("shoes", 0), 0, Avatar.SHOE_COLORS.size() - 1)])
	for s in [-1.0, 1.0]:
		Build.box(feet, Vector3(0.11, 0.07, 0.27), Vector3(s * 0.11, 0.035, -0.12), shoe)
		Build.box(feet, Vector3(0.11, 0.3, 0.12), Vector3(s * 0.11, 0.22, 0.0), pants)
	Build.set_layers(feet, Build.LAYER_FPS)
	feet.visible = false

func set_pose(position_v: Vector3, yaw_rad: float) -> void:
	global_position = position_v
	yaw = yaw_rad
	pitch = 0.0
	rotation.y = yaw
	head.rotation.x = 0.0
	velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := Settings.mouse_sensitivity
		yaw -= event.relative.x * s
		pitch = clampf(pitch - event.relative.y * s, deg_to_rad(-85), deg_to_rad(85))
	elif event.is_action_pressed("interact") and target != null:
		vm.reach()
		interacted_with.emit(target)
		target.activate(self)
	elif event.is_action_pressed("flashlight"):
		flash.visible = not flash.visible
		Audio.play_sfx("click", -8.0)

func _physics_process(delta: float) -> void:
	if not input_enabled:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	rotation.y = yaw
	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward"))
	var crouching := Input.is_action_pressed("crouch")
	var speed := CROUCH_SPEED if crouching else (SPRINT if Input.is_action_pressed("sprint") else WALK)
	var wish := (transform.basis * Vector3(dir.x, 0, dir.y)).normalized() * speed if dir.length() > 0.01 else Vector3.ZERO
	velocity.x = lerpf(velocity.x, wish.x, clampf(delta * 11.0, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, wish.z, clampf(delta * 11.0, 0.0, 1.0))
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	_eye = lerpf(_eye, EYE_CROUCH if crouching else EYE_STAND, clampf(delta * eye_speed, 0.0, 1.0))

func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func _process(delta: float) -> void:
	_t += delta
	var anx: float = clampf(float(Narrative.current.get("heart", 0.0)), 0.0, 1.0)
	var calm := 0.0 if Settings.reduce_motion else 1.0
	var spd := horizontal_speed()
	_bob += delta * spd * 5.2
	var bob_y := sin(_bob * 2.0) * 0.022 * clampf(spd / WALK, 0.0, 1.5) * calm
	var bob_x := cos(_bob) * 0.012 * clampf(spd / WALK, 0.0, 1.5) * calm
	var breathe := sin(_t * (1.25 + anx * 1.6)) * (0.0035 + anx * 0.004)
	var shake := Vector3.ZERO
	if Settings.camera_shake and not Settings.reduce_motion and anx > 0.1:
		shake = Vector3(sin(_t * 31.0 + _shake_seed), cos(_t * 27.0), 0) * 0.0012 * anx
	head.position = Vector3(bob_x, _eye + bob_y + breathe, 0) + shake
	head.rotation.x = pitch
	cam.rotation.z = lerpf(cam.rotation.z, -Input.get_axis("move_left", "move_right") * 0.012 * calm, clampf(delta * 6.0, 0, 1))
	# footsteps
	if spd > 0.5 and is_on_floor():
		var step := int(floor(_bob / PI))
		if step != _last_step:
			_last_step = step
			Audio.play_sfx("step", -16.0 + (3.0 if Input.is_action_pressed("sprint") else 0.0), randf_range(0.9, 1.1))
	feet.visible = pitch < deg_to_rad(-38) and input_enabled
	_update_target()

func _update_target() -> void:
	var found: Interactable = null
	if input_enabled and ray.is_colliding():
		var c := ray.get_collider()
		if c is Interactable and c.enabled:
			found = c
	if found != target:
		if target and is_instance_valid(target):
			target.set_highlight(false)
		target = found
		if target:
			target.set_highlight(true)
	UI.set_prompt("" if target == null else "E   %s" % target.prompt)

# ---- cutscene camera ------------------------------------------------------

func lock(on: bool) -> void:
	input_enabled = not on
	if on:
		UI.set_prompt("")
		if target:
			target.set_highlight(false)
			target = null

## Detach the camera and glide it to a world transform (used for sitting at the PC,
## turning to look at the player, and so on).
func cam_move_to(xform: Transform3D, time: float = 1.0) -> void:
	if not cam.top_level:
		var g := cam.global_transform
		cam.top_level = true
		cam.global_transform = g
	if _cam_tween:
		_cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var from := cam.global_transform
	_cam_tween.tween_method(func(w: float):
		var o := from.origin.lerp(xform.origin, w)
		var b := from.basis.get_rotation_quaternion().slerp(xform.basis.get_rotation_quaternion(), w)
		cam.global_transform = Transform3D(Basis(b), o), 0.0, 1.0, maxf(time, 0.01))
	await _cam_tween.finished

func cam_release(time: float = 0.8) -> void:
	if not cam.top_level:
		return
	var target_t := head.global_transform
	await cam_move_to(target_t, time)
	cam.top_level = false
	cam.transform = Transform3D.IDENTITY

func set_cull_cutscene(show_avatar: bool) -> void:
	cam.cull_mask = Build.LAYER_WORLD | (Build.LAYER_AVATAR if show_avatar else Build.LAYER_FPS)
	if not show_avatar:
		cam.cull_mask = Build.LAYER_WORLD | Build.LAYER_FPS
	vm.visible = not show_avatar
	if feet:
		feet.visible = false

func eye_position() -> Vector3:
	return cam.global_position
