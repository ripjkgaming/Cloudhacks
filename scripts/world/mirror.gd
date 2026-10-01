class_name Mirror
extends Node3D
## A real planar mirror: SubViewport + off-axis frustum camera placed at the
## reflected eye position. Shows the player's Avatar (invisible to the main
## camera). The avatar can lag behind or glance at the viewer: the "uncanny" system.

var player: Player
var avatar: Avatar
var size := Vector2(0.8, 1.7)
var uncanny := 0.0            # 0..1 → reflection lag
var _vp: SubViewport
var _cam: Camera3D
var _quad: MeshInstance3D
var _gaze := 0.0
var _a_pos := Vector3.ZERO
var _a_yaw := 0.0
var _gaze_cooldown := 0.0

func setup(p: Player, avatar_parent: Node3D, mirror_size: Vector2) -> void:
	player = p
	size = mirror_size
	_vp = SubViewport.new()
	_vp.size = Vector2i(240, int(240.0 * mirror_size.y / mirror_size.x))
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.cull_mask = Build.LAYER_WORLD | Build.LAYER_AVATAR
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.far = 14.0
	_vp.add_child(_cam)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _vp.get_texture()
	m.uv1_scale = Vector3(-1, 1, 1)
	m.uv1_offset = Vector3(1, 0, 0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_quad = Build.quad(self, mirror_size, Vector3.ZERO, m)
	avatar = Avatar.new()
	avatar_parent.add_child(avatar)
	avatar.build(GameState.custom)
	avatar.set_layer_mask(Build.LAYER_AVATAR)
	_a_pos = player.global_position
	_a_yaw = player.yaw

func rebuild_avatar() -> void:
	avatar.build(GameState.custom)
	avatar.set_layer_mask(Build.LAYER_AVATAR)

## Trigger a rare moment where the reflection looks at the viewer.
func glance(duration: float = 1.4) -> void:
	_gaze = duration

func _process(delta: float) -> void:
	if player == null:
		return
	var tau := uncanny * 0.35
	var k := 1.0 if tau < 0.001 else 1.0 - exp(-delta / tau)
	_a_pos = _a_pos.lerp(player.global_position, k)
	_a_yaw = lerp_angle(_a_yaw, player.yaw, k)
	avatar.global_position = _a_pos
	avatar.rotation.y = _a_yaw
	avatar.head.rotation.x = player.pitch * 0.8 if _gaze <= 0.0 else avatar.head.rotation.x
	avatar.animate(delta, player.horizontal_speed())
	var to_mirror := global_position - player.eye_position()
	var dist := to_mirror.length()
	var fwd := -player.cam.global_transform.basis.z
	var facing := fwd.dot(to_mirror.normalized())
	var visible_to_player := dist < 7.0 and facing > 0.25
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible_to_player else SubViewport.UPDATE_DISABLED
	if _gaze > 0.0:
		_gaze -= delta
		avatar.look_at_node(_cam)
		if _gaze <= 0.0:
			avatar.clear_look()
	_gaze_cooldown -= delta
	if not visible_to_player:
		return
	_update_camera()

func _update_camera() -> void:
	var n := global_transform.basis.z.normalized()
	var up := global_transform.basis.y.normalized()
	var eye := player.eye_position()
	var d := (eye - global_position).dot(n)          # signed distance of eye from plane
	if d < 0.05:
		return
	var eye_r := eye - 2.0 * d * n                   # reflected eye, behind the mirror
	var x_cam := n.cross(up).normalized()
	_cam.global_transform = Transform3D(Basis(x_cam, up, -n), eye_r)
	var rel := global_position - eye_r
	_cam.set_frustum(size.x, Vector2(rel.dot(x_cam), rel.dot(up)), d, 16.0)

## Called by the world when the player looks at the mirror at an angle: for rare glances.
func try_uncanny_glance(day: int) -> void:
	if day < 3 or _gaze > 0.0 or _gaze_cooldown > 0.0:
		return
	if GameState.has_flag("mirror_glance_%d" % day):
		return
	var to_mirror := (global_position - player.eye_position()).normalized()
	var fwd := -player.cam.global_transform.basis.z
	var ang := rad_to_deg(acos(clampf(fwd.dot(to_mirror), -1.0, 1.0)))
	if ang > 22.0 and ang < 55.0 and (global_position - player.eye_position()).length() < 5.0:
		GameState.set_flag("mirror_glance_%d" % day)
		_gaze_cooldown = 30.0
		glance(1.6)
