class_name Bedroom
extends Node3D
## The hub. Built entirely from code. Visuals react to the psychological state:
## lighting cools and dims, clutter accumulates, sticky notes multiply, the clock
## freezes. Gameplay meaning of each object lives in Days/Main, not here.

signal activated(id: String)

const W := 6.0   # x extent
const D := 5.0   # z extent
const H := 2.7

var player: Player
var mirror: Mirror
var items := {}                       # id -> Interactable
var env: Environment
var world_env: WorldEnvironment
var ceiling_light: OmniLight3D
var desk_lamp: OmniLight3D
var sun: DirectionalLight3D
var window_glass: MeshInstance3D
var sky_mat: ProceduralSkyMaterial
var monitor_label: Label3D
var monitor_screen: MeshInstance3D
var door_pivot: Node3D
var clock_hour: Node3D
var clock_min: Node3D
var clutter: Array = []               # [Node3D]; index i appears when clutter > i
var notes: Array = []                 # [{node, level}]
var _time := 0.0
var _flicker := 0.0
var _screen_text := ""
var _notes_built := false

func _ready() -> void:
	_build_environment()
	_build_shell()
	_build_furniture()
	_build_decor()
	_build_clutter()
	_build_notes()
	_build_outside()
	_build_lights()
	refresh()
	Events.room_state_changed.connect(refresh)
	Events.choice_made.connect(func(_a, _b): refresh())
	Events.day_started.connect(func(_d): refresh())

# ====================================================================== build

func _build_environment() -> void:
	world_env = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.8, 0.7)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.05
	world_env.environment = env
	add_child(world_env)

func _build_shell() -> void:
	var wall := Color("d9c5a8")
	var trim := Color("f1e8d8")
	var fl := Build.box(self, Vector3(W + 0.2, 0.1, D + 0.2), Vector3(0, -0.05, 0), Color("a67c52"), true, 0.65)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.04
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.width = 256
	nt.height = 256
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("b88a5c")
	fm.albedo_texture = nt
	fm.roughness = 0.6
	fm.uv1_scale = Vector3(6, 5, 1)
	fl.material_override = fm
	Build.box(self, Vector3(W + 0.2, 0.1, D + 0.2), Vector3(0, H + 0.05, 0), Color("efe7da"), true)
	Build.box(self, Vector3(W + 0.2, H, 0.1), Vector3(0, H / 2, -D / 2 - 0.05), wall, true)           # north
	Build.box(self, Vector3(0.1, H, D + 0.2), Vector3(-W / 2 - 0.05, H / 2, 0), wall, true)           # west
	# south wall with door opening x in [-1.7,-0.7]
	Build.box(self, Vector3(1.4, H, 0.1), Vector3(-2.4 - 0.05, H / 2, D / 2 + 0.05), wall, true)
	Build.box(self, Vector3(3.8, H, 0.1), Vector3(1.2 + 0.1, H / 2, D / 2 + 0.05), wall, true)
	Build.box(self, Vector3(1.0, H - 2.05, 0.1), Vector3(-1.2, 2.05 + (H - 2.05) / 2, D / 2 + 0.05), wall, true)
	# east wall with window z in [-1.35, 0.15], y in [0.9, 2.1]
	Build.box(self, Vector3(0.1, 0.9, D + 0.2), Vector3(W / 2 + 0.05, 0.45, 0), wall, true)
	Build.box(self, Vector3(0.1, H - 2.1, D + 0.2), Vector3(W / 2 + 0.05, 2.1 + (H - 2.1) / 2, 0), wall, true)
	Build.box(self, Vector3(0.1, 1.2, 1.15), Vector3(W / 2 + 0.05, 1.5, -1.925), wall, true)
	Build.box(self, Vector3(0.1, 1.2, 2.35), Vector3(W / 2 + 0.05, 1.5, 1.325), wall, true)
	# baseboards
	Build.box(self, Vector3(W, 0.1, 0.03), Vector3(0, 0.05, -D / 2 + 0.015), trim)
	Build.box(self, Vector3(0.03, 0.1, D), Vector3(-W / 2 + 0.015, 0.05, 0), trim)
	# window frame + glass (outside glow)
	var frame := Color("f4efe6")
	Build.box(self, Vector3(0.06, 0.05, 1.5), Vector3(W / 2 - 0.03, 0.9, -0.6), frame)
	Build.box(self, Vector3(0.06, 0.05, 1.5), Vector3(W / 2 - 0.03, 2.1, -0.6), frame)
	Build.box(self, Vector3(0.06, 1.25, 0.05), Vector3(W / 2 - 0.03, 1.5, -1.35), frame)
	Build.box(self, Vector3(0.06, 1.25, 0.05), Vector3(W / 2 - 0.03, 1.5, 0.15), frame)
	Build.box(self, Vector3(0.05, 1.2, 0.03), Vector3(W / 2 - 0.03, 1.5, -0.6), frame)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.7, 0.85, 1.0, 0.25)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	window_glass = Build.quad(self, Vector2(1.45, 1.2), Vector3(W / 2 - 0.02, 1.5, -0.6), gm, Vector3(0, -90, 0))
	_it("window", "Window", Vector3(0.3, 1.2, 1.5), Vector3(W / 2 - 0.12, 1.5, -0.6))
	# door
	door_pivot = Node3D.new()
	door_pivot.position = Vector3(-0.7, 0, D / 2)
	add_child(door_pivot)
	var door := Build.box(door_pivot, Vector3(0.96, 2.03, 0.05), Vector3(-0.48, 1.015, 0), Color("c9a77c"))
	Build.sphere(door_pivot, 0.03, Vector3(-0.85, 1.0, -0.05), Color("d4af37"), Vector3.ONE, 0.3)
	var it := _it("door", "Door", Vector3(0.96, 2.03, 0.2), Vector3(-1.18, 1.015, D / 2 - 0.05))
	it.track(door)

func _it(id: String, label: String, size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Interactable:
	var it := Interactable.make(self, id, label, size, pos, rot)
	it.activated.connect(func(_p): activated.emit(id))
	items[id] = it
	return it

func _build_furniture() -> void:
	# --- bed (west wall, north end)
	var bed := Node3D.new()
	bed.position = Vector3(-2.2, 0, -1.5)
	add_child(bed)
	Build.box(bed, Vector3(1.5, 0.3, 2.0), Vector3(0, 0.2, 0), Color("8b6b4a"), true)
	Build.box(bed, Vector3(1.4, 0.2, 1.9), Vector3(0, 0.45, 0), Color("e9e2d5"))
	Build.box(bed, Vector3(1.42, 0.12, 1.2), Vector3(0, 0.55, 0.35), Color("7b9cc4"))
	Build.box(bed, Vector3(0.9, 0.12, 0.4), Vector3(0, 0.58, -0.7), Color("f4f0e8"))
	Build.box(bed, Vector3(1.5, 0.9, 0.08), Vector3(0, 0.55, -1.0), Color("7a5c3e"), true)
	_it("bed", "Bed", Vector3(1.5, 0.7, 2.0), Vector3(-2.2, 0.4, -1.5)).track(bed)
	# --- desk (north wall)
	var desk := Node3D.new()
	add_child(desk)
	Build.box(desk, Vector3(2.0, 0.05, 0.8), Vector3(1.0, 0.75, -2.1), Color("b08968"), true)
	Build.box(desk, Vector3(0.05, 0.75, 0.75), Vector3(0.05, 0.375, -2.1), Color("8c6b4f"), true)
	Build.box(desk, Vector3(0.05, 0.75, 0.75), Vector3(1.95, 0.375, -2.1), Color("8c6b4f"), true)
	_it("desk", "Desk", Vector3(2.0, 0.1, 0.8), Vector3(1.0, 0.75, -2.1)).track(desk)
	# --- monitor + keyboard + pc
	var pc := Node3D.new()
	add_child(pc)
	Build.box(pc, Vector3(0.62, 0.38, 0.03), Vector3(1.0, 1.1, -2.3), Color("1c1d22"), false, 0.4)
	monitor_screen = Build.box(pc, Vector3(0.58, 0.34, 0.01), Vector3(1.0, 1.1, -2.28), Color("9cc8ff"), false, 0.2)
	monitor_screen.material_override = Build.mat(Color("8ab8f0"), 0.2, 0.9)
	Build.box(pc, Vector3(0.06, 0.14, 0.05), Vector3(1.0, 0.85, -2.3), Color("1c1d22"))
	Build.box(pc, Vector3(0.18, 0.015, 0.14), Vector3(1.0, 0.78, -2.27), Color("1c1d22"))
	Build.box(pc, Vector3(0.44, 0.02, 0.15), Vector3(1.0, 0.79, -1.95), Color("2b2d33"))
	Build.box(pc, Vector3(0.1, 0.4, 0.4), Vector3(0.35, 0.98, -2.2), Color("22242a"))   # tower
	monitor_label = Build.label3d(self, "", Vector3(1.0, 1.1, -2.27), 36, Color("1c2430"), 0.0016)
	monitor_label.rotation_degrees = Vector3(0, 0, 0)
	_it("pc", "Computer", Vector3(0.9, 0.7, 0.5), Vector3(1.0, 0.98, -2.15)).track(pc)
	# --- chair
	var chair := Node3D.new()
	chair.position = Vector3(1.0, 0, -1.35)
	add_child(chair)
	Build.box(chair, Vector3(0.5, 0.06, 0.5), Vector3(0, 0.48, 0), Color("3a3f4a"), true)
	Build.box(chair, Vector3(0.5, 0.55, 0.06), Vector3(0, 0.8, 0.23), Color("3a3f4a"))
	Build.cyl(chair, 0.03, 0.45, Vector3(0, 0.23, 0), Color("22242a"))
	Build.cyl(chair, 0.25, 0.04, Vector3(0, 0.03, 0), Color("22242a"))
	_it("chair", "Chair", Vector3(0.5, 0.9, 0.5), Vector3(1.0, 0.5, -1.35)).track(chair)
	# --- closet (west wall south)
	var closet := Node3D.new()
	add_child(closet)
	Build.box(closet, Vector3(0.6, 2.2, 1.7), Vector3(-2.68, 1.1, 0.9), Color("c9b79c"), true)
	Build.box(closet, Vector3(0.02, 2.1, 0.8), Vector3(-2.37, 1.1, 0.5), Color("bda88a"))
	Build.box(closet, Vector3(0.02, 2.1, 0.8), Vector3(-2.37, 1.1, 1.3), Color("bda88a"))
	Build.box(closet, Vector3(0.03, 0.2, 0.03), Vector3(-2.35, 1.1, 0.88), Color("d4af37"))
	_it("closet", "Closet", Vector3(0.6, 2.2, 1.7), Vector3(-2.68, 1.1, 0.9)).track(closet)
	# --- bookshelf (north wall, between bed and desk)
	var shelf := Node3D.new()
	add_child(shelf)
	Build.box(shelf, Vector3(0.9, 1.6, 0.3), Vector3(-0.65, 0.8, -2.35), Color("9b7653"), true)
	var cols := [Color("c0504d"), Color("4f81bd"), Color("9bbb59"), Color("8064a2"), Color("e5b84b"), Color("e8e2d4")]
	for r in 4:
		for c in 6:
			if randf() < 0.82:
				Build.box(shelf, Vector3(0.1, 0.28, 0.2), Vector3(-0.95 + c * 0.12, 0.2 + r * 0.38, -2.3), cols[(r + c) % cols.size()])
	_it("books", "Books", Vector3(0.9, 1.6, 0.3), Vector3(-0.65, 0.8, -2.35)).track(shelf)
	# --- mini fridge (north-east corner)
	var fridge := Node3D.new()
	add_child(fridge)
	Build.box(fridge, Vector3(0.55, 0.9, 0.55), Vector3(2.65, 0.45, -2.2), Color("e8e8ea"), true, 0.4)
	Build.box(fridge, Vector3(0.03, 0.4, 0.03), Vector3(2.37, 0.55, -2.0), Color("9aa0a8"))
	_it("fridge", "Fridge", Vector3(0.55, 0.9, 0.55), Vector3(2.65, 0.45, -2.2)).track(fridge)
	# --- tv + console (east wall south)
	var tv := Node3D.new()
	add_child(tv)
	Build.box(tv, Vector3(0.4, 0.45, 1.3), Vector3(2.75, 0.225, 1.5), Color("5a4632"), true)
	Build.box(tv, Vector3(0.05, 0.5, 0.9), Vector3(2.85, 0.95, 1.5), Color("15161a"))
	Build.box(tv, Vector3(0.02, 0.44, 0.82), Vector3(2.82, 0.95, 1.5), Color("2b3a55"), false, 0.2)
	Build.box(tv, Vector3(0.28, 0.06, 0.24), Vector3(2.7, 0.48, 1.9), Color("e8e8ea"))
	_it("console", "Console", Vector3(0.5, 0.9, 1.3), Vector3(2.75, 0.55, 1.5)).track(tv)
	# --- mirror frame (south wall)
	var mf := Node3D.new()
	add_child(mf)
	var mp := Vector3(1.6, 1.05, D / 2 - 0.02)
	Build.box(mf, Vector3(0.9, 1.8, 0.04), mp + Vector3(0, 0, 0.0), Color("3b2f26"))
	mirror = Mirror.new()
	mirror.position = mp + Vector3(0, 0, -0.03)
	mirror.rotation_degrees = Vector3(0, 180, 0)    # +Z (quad normal) faces into the room (-Z)
	add_child(mirror)
	_it("mirror", "Mirror", Vector3(0.9, 1.8, 0.2), mp + Vector3(0, 0, -0.1)).track(mf)
	# --- trash can
	var trash := Node3D.new()
	add_child(trash)
	Build.cyl(trash, 0.17, 0.4, Vector3(2.5, 0.2, -1.3), Color("5b616b"))
	Build.cyl(trash, 0.15, 0.02, Vector3(2.5, 0.39, -1.3), Color("22242a"))
	_it("trash", "Trash", Vector3(0.4, 0.5, 0.4), Vector3(2.5, 0.25, -1.3)).track(trash)
	# --- backpack
	var bp := Node3D.new()
	add_child(bp)
	Build.box(bp, Vector3(0.3, 0.42, 0.18), Vector3(0.25, 0.21, -1.5), Color("c75b4a"))
	Build.box(bp, Vector3(0.22, 0.18, 0.04), Vector3(0.25, 0.14, -1.4), Color("a94838"))
	_it("backpack", "Backpack", Vector3(0.32, 0.45, 0.2), Vector3(0.25, 0.22, -1.5)).track(bp)
	# --- water bottle + phone + lamp on desk
	var wb := Node3D.new()
	add_child(wb)
	Build.cyl(wb, 0.035, 0.2, Vector3(1.8, 0.88, -2.0), Color(0.55, 0.78, 0.95, 0.9))
	Build.cyl(wb, 0.03, 0.04, Vector3(1.8, 1.0, -2.0), Color("2b5a8a"))
	_it("water", "Water bottle", Vector3(0.12, 0.25, 0.12), Vector3(1.8, 0.9, -2.0)).track(wb)
	var ph := Node3D.new()
	add_child(ph)
	Build.box(ph, Vector3(0.075, 0.012, 0.15), Vector3(0.5, 0.78, -1.9), Color("1d1f24"), false, 0.3)
	Build.box(ph, Vector3(0.065, 0.004, 0.13), Vector3(0.5, 0.787, -1.9), Color("5a8fd8"), false, 0.3)
	_it("phone", "Phone", Vector3(0.12, 0.08, 0.2), Vector3(0.5, 0.8, -1.9)).track(ph)
	var lamp := Node3D.new()
	add_child(lamp)
	Build.cyl(lamp, 0.08, 0.02, Vector3(1.9, 0.79, -2.3), Color("2b2d33"))
	Build.cyl(lamp, 0.01, 0.3, Vector3(1.9, 0.95, -2.3), Color("2b2d33"))
	Build.cyl(lamp, 0.07, 0.1, Vector3(1.9, 1.15, -2.3), Color("f0c987"))
	_it("lamp", "Desk lamp", Vector3(0.2, 0.5, 0.2), Vector3(1.9, 0.95, -2.3)).track(lamp)
	# --- plant
	var plant := Node3D.new()
	add_child(plant)
	Build.cyl(plant, 0.12, 0.22, Vector3(0.3, 0.11, 2.2), Color("b5694a"))
	for i in 5:
		var a := i * TAU / 5.0
		Build.sphere(plant, 0.1, Vector3(0.3 + cos(a) * 0.08, 0.38 + (i % 2) * 0.1, 2.2 + sin(a) * 0.08), Color("4f8a50"), Vector3(1, 1.6, 1))
	_it("plant", "Plant", Vector3(0.3, 0.6, 0.3), Vector3(0.3, 0.3, 2.2)).track(plant)
	# --- rug + laundry
	Build.box(self, Vector3(2.4, 0.015, 1.7), Vector3(-0.2, 0.01, 0.5), Color("8c6f8f"))
	var laundry := Node3D.new()
	add_child(laundry)
	Build.box(laundry, Vector3(0.5, 0.12, 0.35), Vector3(-1.5, 0.07, 1.8), Color("6f8fb0"), false, 0.9, Vector3(0, 20, 0))
	Build.box(laundry, Vector3(0.4, 0.1, 0.3), Vector3(-1.45, 0.17, 1.82), Color("b0766f"), false, 0.9, Vector3(0, -15, 0))
	_it("laundry", "Laundry", Vector3(0.55, 0.25, 0.4), Vector3(-1.5, 0.12, 1.8)).track(laundry)
	# --- dumbbell
	var db := Node3D.new()
	add_child(db)
	Build.cyl(db, 0.012, 0.28, Vector3(-0.2, 0.06, 2.3), Color("22242a")).rotation_degrees = Vector3(0, 0, 90)
	Build.cyl(db, 0.06, 0.04, Vector3(-0.32, 0.06, 2.3), Color("3a3f4a")).rotation_degrees = Vector3(0, 0, 90)
	Build.cyl(db, 0.06, 0.04, Vector3(-0.08, 0.06, 2.3), Color("3a3f4a")).rotation_degrees = Vector3(0, 0, 90)
	_it("dumbbell", "Dumbbell", Vector3(0.35, 0.15, 0.15), Vector3(-0.2, 0.08, 2.3)).track(db)
	# --- AC unit
	var ac := Build.box(self, Vector3(0.9, 0.25, 0.2), Vector3(-0.2, 2.4, 2.4), Color("f1f1f1"))
	_it("ac", "Air conditioner", Vector3(0.9, 0.25, 0.2), Vector3(-0.2, 2.4, 2.4)).track(ac)

func _build_decor() -> void:
	# posters
	var p1 := Node3D.new()
	add_child(p1)
	p1.position = Vector3(-2.2, 1.7, -D / 2 + 0.01)
	Build.box(p1, Vector3(0.7, 0.95, 0.01), Vector3.ZERO, Color("f4efe6"))
	Build.box(p1, Vector3(0.6, 0.85, 0.012), Vector3(0, 0, 0.002), Color("e8935a"))
	Build.sphere(p1, 0.17, Vector3(0, 0.1, 0.01), Color("f7d36b"), Vector3(1, 1, 0.1))
	Build.box(p1, Vector3(0.6, 0.3, 0.014), Vector3(0, -0.28, 0.004), Color("3b4d6b"))
	_it("poster", "Poster", Vector3(0.7, 0.95, 0.1), p1.position + Vector3(0, 0, 0.05)).track(p1)
	var p2 := Node3D.new()
	add_child(p2)
	p2.position = Vector3(-W / 2 + 0.01, 1.6, -0.2)
	p2.rotation_degrees = Vector3(0, 90, 0)
	Build.box(p2, Vector3(0.9, 0.6, 0.01), Vector3.ZERO, Color("2b2d3a"))
	Build.label3d(p2, "LO-FI\nNIGHTS", Vector3(0, 0.02, 0.01), 40, Color("f3b6d4"), 0.004)
	_it("poster2", "Poster", Vector3(0.9, 0.6, 0.1), p2.position + Vector3(0.05, 0, 0)).track(p2)
	var p3 := Node3D.new()
	add_child(p3)
	p3.position = Vector3(0.5, 1.9, D / 2 - 0.01)
	p3.rotation_degrees = Vector3(0, 180, 0)
	Build.box(p3, Vector3(0.6, 0.8, 0.01), Vector3.ZERO, Color("dfe8ea"))
	Build.box(p3, Vector3(0.3, 0.3, 0.012), Vector3(-0.05, -0.1, 0.002), Color("6f8f9b"), false, 0.8, Vector3(0, 0, 45))
	_it("poster3", "Poster", Vector3(0.6, 0.8, 0.1), p3.position + Vector3(0, 0, -0.05)).track(p3)
	# wall clock
	var clock := Node3D.new()
	clock.position = Vector3(2.0, 2.0, -D / 2 + 0.03)
	add_child(clock)
	Build.cyl(clock, 0.18, 0.04, Vector3.ZERO, Color("f4f0e8")).rotation_degrees = Vector3(90, 0, 0)
	for i in 4:
		var a := i * PI / 2.0
		Build.box(clock, Vector3(0.02, 0.04, 0.01), Vector3(sin(a) * 0.14, cos(a) * 0.14, 0.025), Color("22242a"))
	clock_hour = Node3D.new()
	clock_hour.position = Vector3(0, 0, 0.03)
	clock.add_child(clock_hour)
	Build.box(clock_hour, Vector3(0.015, 0.09, 0.008), Vector3(0, 0.045, 0), Color("22242a"))
	clock_min = Node3D.new()
	clock_min.position = Vector3(0, 0, 0.036)
	clock.add_child(clock_min)
	Build.box(clock_min, Vector3(0.01, 0.14, 0.006), Vector3(0, 0.07, 0), Color("22242a"))
	_it("clock", "Clock", Vector3(0.4, 0.4, 0.15), clock.position + Vector3(0, 0, 0.05)).track(clock)

func _build_clutter() -> void:
	var specs := [
		["cup", Vector3(0.7, 0.8, -2.0)], ["paper", Vector3(2.35, 0.1, -1.1)], ["clothes", Vector3(-0.8, 0.02, -0.4)],
		["paper", Vector3(0.1, 0.06, -0.8)], ["pizza", Vector3(1.6, 0.8, -1.95)], ["clothes", Vector3(-1.2, 0.02, 1.0)],
		["cup", Vector3(-1.5, 0.52, -0.9)], ["paper", Vector3(2.0, 0.06, 0.4)]]
	for s in specs:
		var n := Node3D.new()
		n.position = s[1]
		add_child(n)
		match s[0]:
			"cup":
				Build.cyl(n, 0.04, 0.1, Vector3(0, 0.05, 0), Color("e8e2d4"))
			"paper":
				Build.sphere(n, 0.07, Vector3.ZERO, Color("f4f0e8"), Vector3(1, 0.8, 1))
			"clothes":
				Build.box(n, Vector3(0.4, 0.06, 0.3), Vector3.ZERO, Color("6a7a90"), false, 0.9, Vector3(0, randf() * 90, 0))
			"pizza":
				Build.box(n, Vector3(0.3, 0.04, 0.3), Vector3.ZERO, Color("b8996a"))
		n.visible = false
		clutter.append(n)

func _build_notes() -> void:
	# sticky notes: (position, rotation_y, level, text)
	var spec := [
		[Vector3(0.75, 1.22, -2.275), 0.0, 1, "START."],
		[Vector3(-2.2, 1.4, -2.48), 0.0, 2, "START."],
		[Vector3(1.0, 1.4, -2.48), 0.0, 2, "START."],
		[Vector3(-1.0, 1.6, -2.48), 0.0, 3, "ESSAY."],
		[Vector3(2.9, 1.5, 0.6), -90.0, 3, "ESSAY."],
		[Vector3(1.25, 1.22, -2.275), 0.0, 3, "ESSAY."],
		[Vector3(-2.95, 1.2, -0.8), 90.0, 4, "ESSAY."],
		[Vector3(0.0, 2.5, -1.0), 0.0, 4, "ESSAY."],
		[Vector3(2.3, 1.3, -2.48), 0.0, 4, "ESSAY."],
		[Vector3(-0.5, 1.2, 2.48), 180.0, 4, "ESSAY."],
	]
	var cols := [Color("f6e27a"), Color("f2b8c6"), Color("a8d8ea")]
	for i in spec.size():
		var s: Array = spec[i]
		var n := Node3D.new()
		n.position = s[0]
		n.rotation_degrees = Vector3(0, s[1], randf_range(-6, 6))
		if s[0].y > 2.4:
			n.rotation_degrees = Vector3(90, 0, 0)
		add_child(n)
		Build.box(n, Vector3(0.12, 0.12, 0.004), Vector3.ZERO, cols[i % 3], false, 0.9)
		Build.label3d(n, s[3], Vector3(0, 0, 0.0035), 22, Color("2a2a32"), 0.0017)
		n.visible = false
		notes.append({"node": n, "level": s[2]})
	# interactable for the first note so it can be read
	var it := _it("sticky", "Sticky note", Vector3(0.16, 0.16, 0.1), Vector3(0.75, 1.22, -2.2))
	it.enabled = false

func _build_outside() -> void:
	# a distant street seen through the window
	var ground := Build.box(self, Vector3(80, 0.2, 80), Vector3(20, -6.0, 0), Color("6e7a6a"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 9:
		var h := rng.randf_range(4.0, 14.0)
		var b := Build.box(self, Vector3(rng.randf_range(3, 6), h, rng.randf_range(3, 6)),
				Vector3(rng.randf_range(9, 22), h / 2.0 - 6.0, rng.randf_range(-16, 16)), Color(0.5, 0.5, 0.56).lerp(Color("c9b79c"), rng.randf()))
		for w in 4:
			Build.box(b, Vector3(0.1, 0.5, 0.4), Vector3(-1.6, rng.randf_range(-h / 3, h / 3), rng.randf_range(-1.5, 1.5)), Color("ffe9a8"), false, 0.5).material_override = Build.mat(Color("ffe9a8"), 0.5, 0.6)

func _build_lights() -> void:
	ceiling_light = OmniLight3D.new()
	ceiling_light.position = Vector3(0, 2.4, 0)
	ceiling_light.omni_range = 9.0
	ceiling_light.light_energy = 1.0
	ceiling_light.shadow_enabled = false
	add_child(ceiling_light)
	desk_lamp = OmniLight3D.new()
	desk_lamp.position = Vector3(1.9, 1.15, -2.1)
	desk_lamp.omni_range = 3.2
	desk_lamp.light_energy = 0.8
	desk_lamp.light_color = Color(1, 0.85, 0.6)
	add_child(desk_lamp)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, 80, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 12.0
	add_child(sun)

# ====================================================================== state

## Place the player in the room. spawn: "bed" | "door" | "desk"
func spawn_point(spawn: String) -> Array:
	match spawn:
		"door": return [Vector3(-1.2, 0.0, 1.7), 0.0]          # facing into the room (-Z)
		"desk": return [Vector3(1.0, 0.0, -0.9), 0.0]
		_: return [Vector3(-1.0, 0.0, -1.0), -PI / 2]          # beside bed, facing east

func monitor_view() -> Transform3D:
	var pos := Vector3(1.0, 1.2, -1.55)
	var t := Transform3D(Basis.looking_at(Vector3(1.0, 1.1, -2.3) - pos, Vector3.UP), pos)
	return t

func set_monitor_text(text: String) -> void:
	_screen_text = text
	monitor_label.text = text

func set_monitor_off() -> void:
	var m: StandardMaterial3D = monitor_screen.material_override
	m.albedo_color = Color("0b0c10")
	m.emission_enabled = false
	monitor_label.text = ""

func open_door() -> void:
	var tw := create_tween()
	tw.tween_property(door_pivot, "rotation_degrees:y", -85.0, 0.7)
	Audio.play_sfx("door")

func close_door() -> void:
	door_pivot.rotation_degrees.y = 0.0

func clutter_level() -> int:
	return int(GameState.stats.get("clutter", 0))

func sticky_level() -> int:
	if GameState.cycle_broken:
		return 0
	var lvl := 0
	if GameState.day >= 2 and GameState.get_psy("pressure") >= 12:
		lvl = 1
	if GameState.day >= 3 or GameState.get_psy("pressure") >= 30:
		lvl = 2
	if GameState.get_psy("pressure") >= 55 or GameState.day >= 4:
		lvl = 3
	if GameState.get_psy("pressure") >= 85 or GameState.day >= 6:
		lvl = 4
	return lvl

## Re-evaluate everything that depends on the psychological state.
func refresh() -> void:
	var cl := clutter_level()
	for i in clutter.size():
		clutter[i].visible = cl > i
	var lvl := sticky_level()
	for n in notes:
		n["node"].visible = lvl >= n["level"]
	items["sticky"].enabled = lvl >= 1
	var tod := GameState.block
	# window light by time of day
	var sun_col: Color = [Color(1.0, 0.96, 0.88), Color(1.0, 0.86, 0.62), Color(1.0, 0.62, 0.38), Color(0.4, 0.5, 0.8)][tod]
	var sun_e: float = [1.0, 1.15, 0.7, 0.0][tod]
	sun.light_color = sun_col
	sun.set_meta("base_energy", sun_e)
	var sky_top: Color = [Color("8ec5ee"), Color("7ab0e0"), Color("5a5f9c"), Color("0f1428")][tod]
	var sky_hor: Color = [Color("e8f0f4"), Color("f7dcb0"), Color("f09a6a"), Color("1c2442")][tod]
	sky_mat.sky_top_color = sky_top
	sky_mat.sky_horizon_color = sky_hor
	sky_mat.ground_horizon_color = sky_hor
	sky_mat.ground_bottom_color = sky_top.darkened(0.5)
	var gm: StandardMaterial3D = window_glass.material_override
	gm.albedo_color = Color(sky_hor.r, sky_hor.g, sky_hor.b, 0.28)
	_screen_refresh()

func _screen_refresh() -> void:
	if GameState.has_flag("endgame_room"):
		return
	var m: StandardMaterial3D = monitor_screen.material_override
	var col := Color("8ab8f0")
	if GameState.get_psy("pressure") > 60:
		col = Color("a8b8d8")
	m.albedo_color = col
	m.emission = col

func _process(delta: float) -> void:
	_time += delta
	var n: Dictionary = Narrative.current
	var anx_press := GameState.get_psy("pressure") / 100.0
	var light_mult: float = n.get("light", 1.0)
	var warm: float = n.get("warm", 1.0)
	var static_l: float = n.get("static_light", 0.0)
	# darkness creeps with pressure/clutter even in "NORMAL"
	var creep := 1.0 - clampf(anx_press * 0.45 + float(clutter_level()) * 0.02, 0.0, 0.55)
	if GameState.cycle_broken:
		creep = 1.0
	var base_ceiling := 1.0 * light_mult * creep
	var flicker_amt: float = n.get("flicker", 0.0) * (1.0 - static_l)
	if GameState.get_psy("pressure") > 70 and GameState.narrative_state != "ESCAPE":
		flicker_amt = maxf(flicker_amt, 0.12)
	if Settings.reduce_motion:
		flicker_amt *= 0.25
	_flicker = lerpf(_flicker, 0.0 if randf() > flicker_amt * 0.15 else randf_range(0.3, 0.9), 0.4)
	var warm_col := Color(1.0, 0.84, 0.64).lerp(Color(0.72, 0.82, 1.0), 1.0 - warm)
	ceiling_light.light_color = warm_col
	ceiling_light.light_energy = base_ceiling * (1.0 - _flicker * flicker_amt)
	desk_lamp.light_energy = 0.8 * light_mult * (1.0 - _flicker * 0.5 * flicker_amt)
	desk_lamp.light_color = Color(1, 0.85, 0.6).lerp(Color(0.8, 0.88, 1.0), 1.0 - warm)
	sun.light_energy = sun.get_meta("base_energy", 1.0) * light_mult * (0.4 + 0.6 * creep)
	env.ambient_light_color = Color(0.92, 0.82, 0.72).lerp(Color(0.6, 0.68, 0.85), 1.0 - warm)
	env.ambient_light_energy = lerpf(0.55, 0.32, static_l) * clampf(light_mult, 0.5, 1.4) * (0.35 if GameState.block == 3 else 1.0)
	# clock
	if GameState.day >= 3 and not GameState.cycle_broken:
		clock_min.rotation_degrees.z = -282.0   # 11:47, always
		clock_hour.rotation_degrees.z = -353.5
	else:
		var m := fmod(GameState.run_seconds / 20.0, 60.0)
		clock_min.rotation_degrees.z = -m * 6.0
		clock_hour.rotation_degrees.z = -(m / 12.0 * 6.0) - GameState.block * 30.0 - 270.0
	if mirror and GameState.day >= 3:
		mirror.try_uncanny_glance(GameState.day)
	if mirror:
		mirror.uncanny = 0.0 if GameState.day < 2 else clampf(float(GameState.day - 2) / 4.0 + GameState.get_psy("self_awareness") / 300.0, 0.0, 0.8) * (0.0 if GameState.cycle_broken else 1.0)
