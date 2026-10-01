class_name Interactable
extends StaticBody3D
## Anything the player can look at and press E on. The world wires `activated`.

signal activated(player: Node)

@export var id := ""
@export var prompt := "Interact"
var enabled := true
var _highlight_mat: StandardMaterial3D
var _meshes: Array = []
var _on := false

static func make(parent: Node, obj_id: String, label: String, size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> Interactable:
	var it := Interactable.new()
	it.id = obj_id
	it.prompt = label
	it.collision_layer = 2
	it.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	it.add_child(cs)
	it.position = pos
	it.rotation_degrees = rot_deg
	parent.add_child(it)
	return it

## Attach visuals that should glow subtly when targeted.
func track(node: Node) -> Interactable:
	if node is MeshInstance3D:
		_meshes.append(node)
	for c in node.get_children():
		track(c)
	return self

func set_highlight(on: bool) -> void:
	if on == _on:
		return
	_on = on
	if _highlight_mat == null:
		_highlight_mat = StandardMaterial3D.new()
		_highlight_mat.albedo_color = Color(1, 0.92, 0.7, 0.10)
		_highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_highlight_mat.emission_enabled = true
		_highlight_mat.emission = Color(1, 0.85, 0.5)
		_highlight_mat.emission_energy_multiplier = 0.35
	for m in _meshes:
		if is_instance_valid(m):
			m.material_overlay = _highlight_mat if on else null

func activate(player: Node) -> void:
	if enabled:
		activated.emit(player)
