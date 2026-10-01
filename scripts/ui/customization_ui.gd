class_name CustomizationUI
extends Control
## Character creation with a live, rotating 3D preview. Emits `confirmed`.

signal confirmed

const OPTIONS := [
	["Hair", "hair_style", Avatar.HAIR_STYLES],
	["Hair colour", "hair_color", 6],
	["Skin tone", "skin", 6],
	["Shirt", "shirt_style", Avatar.SHIRT_STYLES],
	["Shirt colour", "shirt_color", 8],
	["Pants", "pants", 6],
	["Shoes", "shoes", 5],
	["Body type", "body", Avatar.BODIES],
	["Accessory", "accessory", Avatar.ACCESSORIES],
]

var _avatar: Avatar
var _pivot: Node3D
var _labels := {}
var _vp: SubViewport

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("14161d")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := UITheme.label("Who are you today?", 34)
	title.position = Vector2(80, 40)
	add_child(title)
	var sub := UITheme.label("Keep it simple. You'll see yourself in the mirror.", 18, Color(1, 1, 1, 0.55))
	sub.position = Vector2(82, 88)
	add_child(sub)
	# preview
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.position = Vector2(700, 90)
	vpc.size = Vector2(480, 560)
	add_child(vpc)
	_vp = SubViewport.new()
	_vp.size = Vector2i(480, 560)
	_vp.own_world_3d = true
	_vp.transparent_bg = false
	vpc.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1d2029")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.85, 0.8)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.0)
	cam.fov = 38
	_vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.0, 3.2), Vector3(0, 0.9, 0))
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-30, -30, 0)
	l.light_energy = 1.1
	_vp.add_child(l)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	_avatar = Avatar.new()
	_pivot.add_child(_avatar)
	# options
	var y := 150.0
	for o in OPTIONS:
		var key: String = o[1]
		var name_l := UITheme.label(o[0], 20)
		name_l.position = Vector2(80, y + 6)
		add_child(name_l)
		var left := UITheme.button("<", 20)
		left.position = Vector2(300, y)
		left.size = Vector2(44, 40)
		left.pressed.connect(func(): _step(key, o[2], -1))
		add_child(left)
		var val := UITheme.label("", 20, Settings.accent_color())
		val.position = Vector2(352, y + 6)
		val.size = Vector2(190, 28)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(val)
		_labels[key] = val
		var right := UITheme.button(">", 20)
		right.position = Vector2(550, y)
		right.size = Vector2(44, 40)
		right.pressed.connect(func(): _step(key, o[2], 1))
		add_child(right)
		y += 52.0
	var ok := UITheme.button("That's me", 24)
	ok.position = Vector2(80, y + 20)
	ok.size = Vector2(220, 54)
	ok.pressed.connect(func():
		Audio.play_sfx("click")
		confirmed.emit())
	add_child(ok)
	var rnd := UITheme.button("Surprise me", 20)
	rnd.position = Vector2(320, y + 24)
	rnd.size = Vector2(170, 46)
	rnd.pressed.connect(_randomize)
	add_child(rnd)
	_refresh()

func _count(spec) -> int:
	return spec.size() if spec is Array else int(spec)

func _step(key: String, spec, d: int) -> void:
	var n := _count(spec)
	GameState.custom[key] = posmod(int(GameState.custom.get(key, 0)) + d, n)
	Audio.play_sfx("click", -6.0)
	_refresh()

func _randomize() -> void:
	for o in OPTIONS:
		GameState.custom[o[1]] = randi() % _count(o[2])
	_refresh()

func _refresh() -> void:
	_avatar.build(GameState.custom)
	for o in OPTIONS:
		var v: int = GameState.custom.get(o[1], 0)
		_labels[o[1]].text = String(o[2][v]) if o[2] is Array else "#%d" % (v + 1)

func _process(delta: float) -> void:
	_pivot.rotation.y += delta * 0.6
