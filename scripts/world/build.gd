class_name Build
extends RefCounted
## Procedural geometry helpers. All art is code-built so assets can be swapped
## later without touching gameplay: replace the node returned for an object id.

const LAYER_WORLD := 1
const LAYER_FPS := 2           # arms / feet: only the main camera sees these
const LAYER_AVATAR := 1 << 19  # reflection avatar: only mirror / cutscene cameras see it

static var _mats := {}

static func mat(color: Color, rough: float = 0.85, emission: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s_%s_%s_%s" % [color.to_html(true), rough, emission, unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m

static func box(parent: Node, size: Vector3, pos: Vector3, color: Color, collide: bool = false, rough: float = 0.85, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(color, rough)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi

static func cyl(parent: Node, radius: float, height: float, pos: Vector3, color: Color, rough: float = 0.8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 16
	m.rings = 1
	mi.mesh = m
	mi.material_override = mat(color, rough)
	mi.position = pos
	parent.add_child(mi)
	return mi

static func sphere(parent: Node, radius: float, pos: Vector3, color: Color, scale_v: Vector3 = Vector3.ONE, rough: float = 0.8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 16
	m.rings = 8
	mi.mesh = m
	mi.material_override = mat(color, rough)
	mi.position = pos
	mi.scale = scale_v
	parent.add_child(mi)
	return mi

static func capsule(parent: Node, radius: float, height: float, pos: Vector3, color: Color, rough: float = 0.8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 12
	m.rings = 4
	mi.mesh = m
	mi.material_override = mat(color, rough)
	mi.position = pos
	parent.add_child(mi)
	return mi

static func quad(parent: Node, size: Vector2, pos: Vector3, material: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

static func label3d(parent: Node, text: String, pos: Vector3, size: int = 32, color: Color = Color.WHITE, pixel: float = 0.002, rot_deg: Vector3 = Vector3.ZERO) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees = rot_deg
	l.double_sided = false
	parent.add_child(l)
	return l

static func set_layers(node: Node, mask: int) -> void:
	if node is VisualInstance3D:
		node.layers = mask
	for c in node.get_children():
		set_layers(c, mask)
