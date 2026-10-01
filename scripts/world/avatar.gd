class_name Avatar
extends Node3D
## Procedural stylised humanoid built from the saved customization. Used in the
## mirror, the customization preview and fourth-wall cutscenes.

const SKIN := ["f6d7bd", "efc29d", "d9a077", "b97f56", "8a5a3c", "5a3825"]
const HAIR_COLORS := ["2b1d14", "6b4226", "c9a063", "b8452c", "1c1c20", "cfcfd4"]
const HAIR_STYLES := ["Short", "Long", "Bun", "Buzz", "Bald"]
const SHIRT_COLORS := ["4f7cac", "c75b4a", "5c9c6f", "d9b44a", "7a5ca8", "e8e2d4", "2f3a4a", "d97fa0"]
const SHIRT_STYLES := ["Tee", "Hoodie"]
const PANTS_COLORS := ["2d3a52", "3b3b40", "6e5a43", "8895a6", "4a3a5a", "1e1e22"]
const SHOE_COLORS := ["e8e8e8", "1c1c1c", "c24a3a", "3a6ea5", "d9a54a"]
const BODIES := ["Slim", "Average", "Broad"]
const ACCESSORIES := ["None", "Glasses", "Cap", "Headphones", "Beanie"]

var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var _custom := {}
var _walk := 0.0
var _look_target: Node3D = null

func build(custom: Dictionary) -> Avatar:
	_custom = custom
	for c in get_children():
		c.queue_free()
	var bs: float = [0.88, 1.0, 1.16][clampi(custom.get("body", 1), 0, 2)]
	var skin := Color(SKIN[clampi(custom.get("skin", 2), 0, SKIN.size() - 1)])
	var hair_c := Color(HAIR_COLORS[clampi(custom.get("hair_color", 0), 0, HAIR_COLORS.size() - 1)])
	var shirt := Color(SHIRT_COLORS[clampi(custom.get("shirt_color", 0), 0, SHIRT_COLORS.size() - 1)])
	var pants := Color(PANTS_COLORS[clampi(custom.get("pants", 0), 0, PANTS_COLORS.size() - 1)])
	var shoe := Color(SHOE_COLORS[clampi(custom.get("shoes", 0), 0, SHOE_COLORS.size() - 1)])
	var hoodie: bool = custom.get("shirt_style", 0) == 1
	# legs
	leg_l = _limb(Vector3(-0.1 * bs, 0.85, 0), 0.8, 0.075 * bs, pants)
	leg_r = _limb(Vector3(0.1 * bs, 0.85, 0), 0.8, 0.075 * bs, pants)
	for leg in [leg_l, leg_r]:
		Build.box(leg, Vector3(0.11 * bs, 0.07, 0.26), Vector3(0, -0.8, 0.05), shoe)
	# torso
	var torso := Node3D.new()
	torso.position = Vector3(0, 1.12, 0)
	add_child(torso)
	Build.box(torso, Vector3(0.40 * bs, 0.60, 0.22 * (1.0 if bs < 1.1 else 1.1)), Vector3.ZERO, shirt)
	Build.box(torso, Vector3(0.41 * bs, 0.12, 0.23), Vector3(0, -0.3, 0), pants.darkened(0.1))
	if hoodie:
		Build.box(torso, Vector3(0.30 * bs, 0.16, 0.12), Vector3(0, 0.0, 0.12), shirt.darkened(0.12))
		Build.sphere(torso, 0.11, Vector3(0, 0.32, -0.08), shirt.darkened(0.08), Vector3(1.2, 0.7, 0.8))
	# arms
	arm_l = _arm(Vector3(-0.25 * bs, 1.38, 0), bs, shirt, skin, hoodie)
	arm_r = _arm(Vector3(0.25 * bs, 1.38, 0), bs, shirt, skin, hoodie)
	# head
	head = Node3D.new()
	head.position = Vector3(0, 1.52, 0)
	add_child(head)
	Build.cyl(head, 0.045, 0.1, Vector3(0, -0.05, 0), skin)
	Build.sphere(head, 0.115, Vector3(0, 0.1, 0), skin, Vector3(1, 1.12, 1))
	Build.sphere(head, 0.016, Vector3(-0.04, 0.12, 0.105), Color("1a1a1a"))
	Build.sphere(head, 0.016, Vector3(0.04, 0.12, 0.105), Color("1a1a1a"))
	Build.box(head, Vector3(0.05, 0.012, 0.01), Vector3(0, 0.05, 0.11), skin.darkened(0.25))
	_hair(hair_c)
	_accessory(custom.get("accessory", 0), shirt)
	return self

func _limb(pivot: Vector3, length: float, radius: float, color: Color) -> Node3D:
	var n := Node3D.new()
	n.position = pivot
	add_child(n)
	Build.capsule(n, radius, length, Vector3(0, -length / 2.0, 0), color)
	return n

func _arm(pivot: Vector3, bs: float, shirt: Color, skin: Color, long_sleeve: bool) -> Node3D:
	var n := Node3D.new()
	n.position = pivot
	add_child(n)
	var r := 0.05 * bs
	Build.capsule(n, r, 0.3 if not long_sleeve else 0.6, Vector3(0, -0.15 if not long_sleeve else -0.3, 0), shirt)
	if not long_sleeve:
		Build.capsule(n, r * 0.85, 0.34, Vector3(0, -0.45, 0), skin)
	Build.sphere(n, r * 1.1, Vector3(0, -0.62, 0), skin)
	return n

func _hair(color: Color) -> void:
	match int(_custom.get("hair_style", 0)):
		0:
			Build.sphere(head, 0.125, Vector3(0, 0.12, -0.012), color, Vector3(1, 1.05, 1.02))
		1:
			Build.sphere(head, 0.127, Vector3(0, 0.12, -0.015), color, Vector3(1, 1.05, 1.02))
			Build.box(head, Vector3(0.24, 0.34, 0.07), Vector3(0, -0.02, -0.1), color)
		2:
			Build.sphere(head, 0.122, Vector3(0, 0.12, -0.012), color, Vector3(1, 1.0, 1.0))
			Build.sphere(head, 0.07, Vector3(0, 0.27, -0.05), color)
		3:
			Build.sphere(head, 0.118, Vector3(0, 0.115, -0.005), color, Vector3(1, 1.1, 1.0))
		4:
			pass

func _accessory(kind: int, shirt: Color) -> void:
	match kind:
		1:
			var c := Color("222222")
			Build.box(head, Vector3(0.07, 0.05, 0.008), Vector3(-0.05, 0.12, 0.117), c)
			Build.box(head, Vector3(0.07, 0.05, 0.008), Vector3(0.05, 0.12, 0.117), c)
			Build.box(head, Vector3(0.03, 0.01, 0.008), Vector3(0, 0.125, 0.117), c)
			Build.box(head, Vector3(0.06, 0.04, 0.003), Vector3(-0.05, 0.12, 0.122), Color(0.7, 0.85, 1.0, 0.35))
			Build.box(head, Vector3(0.06, 0.04, 0.003), Vector3(0.05, 0.12, 0.122), Color(0.7, 0.85, 1.0, 0.35))
		2:
			Build.cyl(head, 0.125, 0.07, Vector3(0, 0.22, 0), Color("333a46"))
			Build.box(head, Vector3(0.18, 0.012, 0.12), Vector3(0, 0.19, 0.13), Color("333a46"))
		3:
			Build.box(head, Vector3(0.28, 0.02, 0.03), Vector3(0, 0.25, 0), Color("222222"))
			Build.cyl(head, 0.05, 0.04, Vector3(-0.13, 0.1, 0), Color("c75b4a")).rotation_degrees = Vector3(0, 0, 90)
			Build.cyl(head, 0.05, 0.04, Vector3(0.13, 0.1, 0), Color("c75b4a")).rotation_degrees = Vector3(0, 0, 90)
		4:
			Build.sphere(head, 0.13, Vector3(0, 0.15, -0.005), shirt.lightened(0.15), Vector3(1, 0.9, 1.02))

func set_layer_mask(mask: int) -> void:
	Build.set_layers(self, mask)

## Drive limbs: speed in m/s. Call every frame.
func animate(delta: float, speed: float) -> void:
	_walk += delta * speed * 4.2
	var amp := clampf(speed / 2.0, 0.0, 1.0) * 0.55
	if leg_l:
		leg_l.rotation.x = sin(_walk) * amp
		leg_r.rotation.x = -sin(_walk) * amp
		arm_l.rotation.x = -sin(_walk) * amp * 0.8
		arm_r.rotation.x = sin(_walk) * amp * 0.8
	if _look_target and head:
		var to := _look_target.global_position - head.global_position
		var local: Vector3 = head.get_parent().global_transform.basis.inverse() * to
		head.rotation.y = lerp_angle(head.rotation.y, atan2(local.x, local.z), clampf(delta * 6.0, 0, 1))
		head.rotation.x = lerp_angle(head.rotation.x, -atan2(local.y, Vector2(local.x, local.z).length()), clampf(delta * 6.0, 0, 1))

func look_at_node(n: Node3D) -> void:
	_look_target = n

func clear_look(delta_reset: bool = true) -> void:
	_look_target = null
	if head:
		head.rotation = Vector3.ZERO
