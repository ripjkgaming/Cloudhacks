class_name Neighborhood
extends Node3D
## The small outdoor hub: friends in the park, snack stand, gym, a poker table.
## Built from code; interaction semantics are handled by Days.

signal activated(id: String)

var items := {}
var npcs := {}
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var player: Player
var _t := 0.0

func _ready() -> void:
	_build_env()
	_build_ground()
	_build_apartment()
	_build_park()
	_build_gym()
	_build_npcs()
	apply_time_of_day()

func _it(id: String, label: String, size: Vector3, pos: Vector3) -> Interactable:
	var it := Interactable.make(self, id, label, size, pos)
	it.activated.connect(func(_p): activated.emit(id))
	items[id] = it
	return it

func _build_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.fog_enabled = true
	env.fog_density = 0.004
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)

func apply_time_of_day() -> void:
	var tod := GameState.block
	var cols := [Color(1.0, 0.97, 0.9), Color(1.0, 0.9, 0.72), Color(1.0, 0.68, 0.45), Color(0.5, 0.58, 0.85)]
	var en := [1.1, 1.2, 0.9, 0.25]
	sun.light_color = cols[tod]
	sun.light_energy = en[tod]
	sun.rotation_degrees.x = [-52.0, -38.0, -14.0, -30.0][tod]
	sky_mat.sky_top_color = [Color("6fb4ee"), Color("78aee0"), Color("5a6fb0"), Color("101830")][tod]
	sky_mat.sky_horizon_color = [Color("dce9f0"), Color("f3d9b0"), Color("f09a6a"), Color("1c2442")][tod]
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	env.fog_light_color = sky_mat.sky_horizon_color
	env.ambient_light_energy = [0.9, 0.85, 0.6, 0.3][tod]

func set_bright_day() -> void:
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.light_energy = 1.3
	sun.rotation_degrees.x = -50.0
	sky_mat.sky_top_color = Color("6fb4ee")
	sky_mat.sky_horizon_color = Color("e6f1f7")
	env.ambient_light_energy = 1.0

func _build_ground() -> void:
	Build.box(self, Vector3(120, 0.2, 120), Vector3(0, -0.1, -20), Color("7fae6a"), true)
	Build.box(self, Vector3(120, 0.02, 6), Vector3(0, 0.01, 12), Color("55575c"))          # road
	Build.box(self, Vector3(120, 0.04, 2.5), Vector3(0, 0.02, 8.4), Color("c9c6bd"))         # sidewalk
	Build.box(self, Vector3(40, 0.04, 16), Vector3(-3, 0.02, -8), Color("bfb8a6"))           # plaza
	for i in range(-6, 7):
		Build.box(self, Vector3(1.6, 0.025, 0.12), Vector3(i * 6.0, 0.03, 12), Color("e8e2d0"))

func _build_apartment() -> void:
	var b := Build.box(self, Vector3(14, 12, 8), Vector3(-1, 6, 5.5), Color("c9a58a"), true)
	Build.box(self, Vector3(14.2, 0.4, 8.2), Vector3(-1, 12.1, 5.5), Color("8a6a55"))
	for r in 3:
		for c in 5:
			Build.box(self, Vector3(1.0, 1.3, 0.1), Vector3(-6.2 + c * 2.4, 3.8 + r * 3.0, 1.5), Color("ffe9a8"), false, 0.4).material_override = Build.mat(Color("ffe9a8"), 0.4, 0.35)
	var door := Build.box(self, Vector3(1.2, 2.2, 0.15), Vector3(0, 1.1, 1.52), Color("7a4f35"))
	Build.box(self, Vector3(1.6, 0.15, 0.7), Vector3(0, 2.4, 1.2), Color("5a3f2e"))
	_it("home_door", "Go home", Vector3(1.4, 2.3, 0.5), Vector3(0, 1.15, 1.3)).track(door)
	items["home_door"].enabled = true

func _tree(pos: Vector3, h: float = 4.0) -> void:
	Build.cyl(self, 0.2, h * 0.5, pos + Vector3(0, h * 0.25, 0), Color("6b4a33"))
	Build.sphere(self, h * 0.42, pos + Vector3(0, h * 0.7, 0), Color("4c8c4a"), Vector3(1, 0.9, 1))
	Build.sphere(self, h * 0.3, pos + Vector3(h * 0.2, h * 0.55, 0.3), Color("5a9a52"))

func _build_park() -> void:
	for p in [Vector3(-9, 0, -14), Vector3(8, 0, -16), Vector3(-16, 0, -6), Vector3(18, 0, -18), Vector3(-2, 0, -22), Vector3(26, 0, -8)]:
		_tree(p, randf_range(3.5, 5.0))
	# bench
	var bench := Node3D.new()
	bench.position = Vector3(-4, 0, -8)
	add_child(bench)
	Build.box(bench, Vector3(1.8, 0.08, 0.5), Vector3(0, 0.45, 0), Color("8b6b4a"), true)
	Build.box(bench, Vector3(1.8, 0.5, 0.06), Vector3(0, 0.75, -0.22), Color("8b6b4a"))
	Build.box(bench, Vector3(0.08, 0.45, 0.45), Vector3(-0.8, 0.22, 0), Color("3a3f4a"))
	Build.box(bench, Vector3(0.08, 0.45, 0.45), Vector3(0.8, 0.22, 0), Color("3a3f4a"))
	_it("bench", "Bench", Vector3(1.8, 0.9, 0.6), Vector3(-4, 0.5, -8)).track(bench)
	# boombox on bench
	var bb := Node3D.new()
	bb.position = Vector3(-3.3, 0.55, -8)
	add_child(bb)
	Build.box(bb, Vector3(0.4, 0.2, 0.14), Vector3.ZERO, Color("c75b4a"))
	Build.cyl(bb, 0.06, 0.02, Vector3(-0.1, 0, 0.075), Color("222")).rotation_degrees = Vector3(90, 0, 0)
	Build.cyl(bb, 0.06, 0.02, Vector3(0.1, 0, 0.075), Color("222")).rotation_degrees = Vector3(90, 0, 0)
	_it("boombox", "Boombox", Vector3(0.45, 0.25, 0.2), bb.position).track(bb)
	# picnic table (poker)
	var pt := Node3D.new()
	pt.position = Vector3(6, 0, -10)
	add_child(pt)
	Build.box(pt, Vector3(2.0, 0.07, 1.0), Vector3(0, 0.75, 0), Color("9b7653"), true)
	Build.box(pt, Vector3(2.0, 0.06, 0.35), Vector3(0, 0.45, 0.8), Color("9b7653"))
	Build.box(pt, Vector3(2.0, 0.06, 0.35), Vector3(0, 0.45, -0.8), Color("9b7653"))
	Build.box(pt, Vector3(1.0, 0.01, 0.6), Vector3(0, 0.79, 0), Color("2f6b4a"))
	for i in 4:
		Build.cyl(pt, 0.04, 0.02, Vector3(-0.3 + i * 0.2, 0.8, 0.1), [Color("c0392b"), Color("2c6fbb"), Color("e5b84b"), Color("222")][i])
	_it("poker_table", "Poker table", Vector3(2.0, 0.9, 1.0), Vector3(6, 0.5, -10)).track(pt)
	# snack stand
	var st := Node3D.new()
	st.position = Vector3(-10, 0, -3)
	add_child(st)
	Build.box(st, Vector3(2.2, 1.0, 1.0), Vector3(0, 0.5, 0), Color("e5b84b"), true)
	Build.box(st, Vector3(2.4, 0.1, 1.3), Vector3(0, 2.3, 0), Color("c0392b"))
	Build.box(st, Vector3(0.08, 1.3, 0.08), Vector3(-1.1, 1.65, 0.55), Color("5a3f2e"))
	Build.box(st, Vector3(0.08, 1.3, 0.08), Vector3(1.1, 1.65, 0.55), Color("5a3f2e"))
	Build.label3d(st, "SNACKS", Vector3(0, 1.6, 0.52), 48, Color("2a2a32"), 0.006)
	_it("snack", "Snack stand", Vector3(2.2, 1.2, 1.0), Vector3(-10, 0.6, -3)).track(st)
	# lamp posts
	for x in [-12.0, 0.0, 12.0]:
		Build.cyl(self, 0.06, 4.0, Vector3(x, 2.0, 7.2), Color("2b2d33"))
		Build.sphere(self, 0.2, Vector3(x, 4.1, 7.2), Color("fff0c0")).material_override = Build.mat(Color("fff0c0"), 0.4, 0.8)
	# parked cars
	for c in [[Vector3(-14, 0.0, 10.4), Color("c75b4a")], [Vector3(10, 0, 13.6), Color("4f7cac")]]:
		var car := Node3D.new()
		car.position = c[0]
		add_child(car)
		Build.box(car, Vector3(4.0, 0.7, 1.8), Vector3(0, 0.55, 0), c[1], true)
		Build.box(car, Vector3(2.2, 0.6, 1.6), Vector3(-0.2, 1.15, 0), c[1].lightened(0.1))
		Build.box(car, Vector3(2.0, 0.45, 1.62), Vector3(-0.2, 1.17, 0), Color("a8c8e0"), false, 0.2)

func _build_gym() -> void:
	var g := Node3D.new()
	g.position = Vector3(18, 0, -3)
	add_child(g)
	var wall := Color("8f95a0")
	Build.box(g, Vector3(10, 0.1, 8), Vector3(0, 0.0, 0), Color("3f424a"), true)
	Build.box(g, Vector3(10, 3.2, 0.2), Vector3(0, 1.6, -4), wall, true)
	Build.box(g, Vector3(0.2, 3.2, 8), Vector3(5, 1.6, 0), wall, true)
	Build.box(g, Vector3(10, 3.2, 0.2), Vector3(0, 1.6, 4), wall, true)
	Build.box(g, Vector3(0.2, 3.2, 3.0), Vector3(-5, 1.6, -2.5), wall, true)
	Build.box(g, Vector3(0.2, 3.2, 3.0), Vector3(-5, 1.6, 2.5), wall, true)
	Build.box(g, Vector3(0.2, 1.0, 2.0), Vector3(-5, 2.7, 0), wall, true)
	Build.box(g, Vector3(10.4, 0.2, 8.4), Vector3(0, 3.3, 0), Color("5a5e68"))
	Build.label3d(g, "IRON  YARD  GYM", Vector3(-5.12, 2.9, 0), 64, Color("ffb454"), 0.006, Vector3(0, -90, 0))
	var l := OmniLight3D.new()
	l.position = Vector3(0, 3.0, 0)
	l.omni_range = 11.0
	l.light_energy = 1.1
	g.add_child(l)
	# bench press
	var bp := Node3D.new()
	bp.position = Vector3(-1.5, 0, -2.2)
	g.add_child(bp)
	Build.box(bp, Vector3(0.45, 0.4, 1.3), Vector3(0, 0.3, 0), Color("22242a"), true)
	Build.box(bp, Vector3(0.1, 0.9, 0.1), Vector3(-0.5, 0.6, -0.4), Color("c75b4a"))
	Build.box(bp, Vector3(0.1, 0.9, 0.1), Vector3(0.5, 0.6, -0.4), Color("c75b4a"))
	Build.box(bp, Vector3(1.8, 0.04, 0.04), Vector3(0, 1.0, -0.4), Color("b8bcc4"))
	_gym_it("gym_bench", "Bench press", Vector3(1.5, 1.2, 1.4), g.position + bp.position + Vector3(0, 0.6, 0)).track(bp)
	# dumbbell rack
	var dr := Node3D.new()
	dr.position = Vector3(2.0, 0, -3.3)
	g.add_child(dr)
	Build.box(dr, Vector3(2.0, 0.8, 0.5), Vector3(0, 0.4, 0), Color("3a3f4a"), true)
	for i in 6:
		Build.sphere(dr, 0.1, Vector3(-0.8 + i * 0.32, 0.9, 0), Color("22242a"))
	_gym_it("gym_dumbbell", "Dumbbells", Vector3(2.0, 1.0, 0.6), g.position + dr.position + Vector3(0, 0.5, 0)).track(dr)
	# punching bag
	var pb := Node3D.new()
	pb.position = Vector3(3.0, 0, 1.5)
	g.add_child(pb)
	Build.cyl(pb, 0.05, 1.8, Vector3(0, 2.2, 0), Color("b8bcc4"))
	Build.cyl(pb, 0.22, 1.1, Vector3(0, 1.0, 0), Color("c0392b"))
	_gym_it("gym_bag", "Punching bag", Vector3(0.6, 1.4, 0.6), g.position + pb.position + Vector3(0, 1.0, 0)).track(pb)
	# treadmill
	var tm := Node3D.new()
	tm.position = Vector3(-2.5, 0, 2.2)
	g.add_child(tm)
	Build.box(tm, Vector3(0.8, 0.2, 1.8), Vector3(0, 0.2, 0), Color("22242a"), true)
	Build.box(tm, Vector3(0.7, 0.01, 1.6), Vector3(0, 0.31, 0), Color("3a3f4a"))
	Build.box(tm, Vector3(0.7, 0.1, 0.1), Vector3(0, 1.2, -0.8), Color("22242a"))
	Build.box(tm, Vector3(0.06, 1.0, 0.06), Vector3(-0.35, 0.8, -0.8), Color("22242a"))
	Build.box(tm, Vector3(0.06, 1.0, 0.06), Vector3(0.35, 0.8, -0.8), Color("22242a"))
	_gym_it("gym_treadmill", "Treadmill", Vector3(0.9, 1.3, 1.9), g.position + tm.position + Vector3(0, 0.6, 0)).track(tm)

func _gym_it(id: String, label: String, size: Vector3, pos: Vector3) -> Interactable:
	return _it(id, label, size, pos)

func _build_npcs() -> void:
	var specs := {
		"friend_sam": {"pos": Vector3(-4.3, 0, -7.3), "yaw": 0.0, "name": "Sam",
			"c": {"hair_style": 0, "hair_color": 1, "skin": 1, "shirt_color": 3, "shirt_style": 1, "pants": 0, "shoes": 0, "body": 1, "accessory": 2}},
		"friend_priya": {"pos": Vector3(-1.0, 0, -13.0), "yaw": 0.0, "name": "Priya",
			"c": {"hair_style": 1, "hair_color": 0, "skin": 3, "shirt_color": 2, "shirt_style": 0, "pants": 1, "shoes": 1, "body": 0, "accessory": 1}},
		"friend_theo": {"pos": Vector3(5.2, 0, -8.7), "yaw": 0.0, "name": "Theo",
			"c": {"hair_style": 3, "hair_color": 4, "skin": 4, "shirt_color": 1, "shirt_style": 0, "pants": 2, "shoes": 2, "body": 2, "accessory": 3}},
	}
	for id in specs:
		var sp: Dictionary = specs[id]
		var a := Avatar.new()
		a.position = sp["pos"]
		add_child(a)
		a.build(sp["c"])
		npcs[id] = a
		_it(id, "Talk to %s" % sp["name"], Vector3(0.7, 1.8, 0.7), sp["pos"] + Vector3(0, 0.9, 0))

func _process(delta: float) -> void:
	_t += delta
	if player == null:
		return
	for id in npcs:
		var a: Avatar = npcs[id]
		var to := player.global_position - a.global_position
		var d := Vector2(to.x, to.z).length()
		if d < 14.0:
			a.rotation.y = lerp_angle(a.rotation.y, atan2(to.x, to.z), clampf(delta * 2.5, 0.0, 1.0))
		a.position.y = absf(sin(_t * 1.4 + a.position.x)) * 0.006
		a.arm_l.rotation.x = sin(_t * 1.1 + a.position.z) * 0.05
		a.arm_r.rotation.x = -sin(_t * 1.1 + a.position.z) * 0.05

func spawn_point(where: String) -> Array:
	if where == "gym":
		return [Vector3(14.0, 0.0, -3.0), -PI / 2]
	return [Vector3(0, 0.0, 3.5), 0.0]        # outside the apartment, facing the park (-Z)
