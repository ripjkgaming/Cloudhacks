extends Node
## Cinematics director (autoload "Cinema"). Plays camera-driven cutscenes by id.
## Contract used by the rest of the game:
##   await Cinema.play(id, args)   -- returns when the cutscene is finished (or skipped)
##   Cinema.playing                -- true while a cutscene owns the camera
## Known ids: "opening", "wake" {day}, "day_end" {day}, "doomscroll_enter", "doomscroll_exit",
##   "night_scroll" {minutes}, "ending" {id}. Unknown ids return immediately.
##
## Every scene is built from tweened camera legs, letterbox bars, eyelids, colour washes and
## a text track read from data/sequences.json ("cin_*" entries). Any key / click skips; a
## skip (or the watchdog) snaps everything back to a clean state, so callers never see a
## half-finished shot. Honours Settings.reduce_motion (no roll/FOV punch/shake, shorter
## moves, no flicker) and Settings.camera_shake. `--cinema=skip` on the command line makes
## every scene resolve instantly (QA bots); under a bot Engine.time_scale compresses the rest.

const LAYER := 12                 # above the UI fade (10): a cutscene owns the whole screen
const BAR := 0.11                 # letterbox height, as a fraction of the screen
const MAX_SECONDS := 16.0         # watchdog (scene time): nothing may outlive this
const SKIP_GUARD := 0.5           # ignore the key press that started the scene
const SEQ_FILE := "res://data/sequences.json"
const CLOCK_START := [490, 800, 1110, 1360]       # minute of day at the start of each time block
const LID := Color(0.02, 0.015, 0.02)

const SCENES := ["opening", "wake", "day_end", "doomscroll_enter", "doomscroll_exit", "night_scroll", "ending"]

var playing := false
var skipped := false
var current_id := ""

var _mode := "play"
var _args := {}
var _saved := {}
var _t := 0.0
var _gen := 0
var _text_busy := false
var _ends_black := false
var _clears_fade := false
var _state_touched := false
var _roll := 0.0
var _shake := 0.0
var _tweens: Array[Tween] = []
var _lid_val := 0.0
var _bar_val := 0.0

var _layer: CanvasLayer
var _glow: TextureRect
var _feed: _Feed
var _ring: _Ring
var _wash: ColorRect
var _line: Label
var _clock: Label
var _list: Label
var _top: ColorRect
var _bottom: ColorRect
var _lid_top: ColorRect
var _lid_bottom: ColorRect
var _hint: Label

# ====================================================================== setup

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cinema="):
			_mode = a.get_slice("=", 1)
	_build()

func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.visible = false
	add_child(_layer)
	_glow = TextureRect.new()
	_full(_glow)
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_layer.add_child(_glow)
	_feed = _Feed.new()
	_full(_feed)
	_layer.add_child(_feed)
	_wash = ColorRect.new()
	_full(_wash)
	_layer.add_child(_wash)
	_ring = _Ring.new()
	_area(_ring, Rect2(0.5, 0.5, 0.0, 0.0), 190.0)
	_layer.add_child(_ring)
	_line = _label(30)
	_layer.add_child(_line)
	_clock = _label(76)
	_area(_clock, Rect2(0.25, 0.3, 0.5, 0.22))
	_layer.add_child(_clock)
	_list = _label(26)
	_list.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_area(_list, Rect2(0.58, 0.24, 0.36, 0.46))
	_layer.add_child(_list)
	_top = _bar(true)
	_bottom = _bar(false)
	_lid_top = _bar(true)
	_lid_bottom = _bar(false)
	for r in [_lid_top, _lid_bottom]:
		r.color = LID
	_hint = _label(16)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_area(_hint, Rect2(0.5, 0.925, 0.46, 0.06))
	_hint.text = "any key: skip"
	_layer.add_child(_hint)

func _full(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Place a control by fractional screen rect (x, y, w, h). With a radius, centre it and use +-radius pixels.
func _area(c: Control, r: Rect2, radius: float = 0.0) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.anchor_left = r.position.x
	c.anchor_top = r.position.y
	c.anchor_right = r.position.x + r.size.x
	c.anchor_bottom = r.position.y + r.size.y
	c.offset_left = -radius
	c.offset_top = -radius
	c.offset_right = radius
	c.offset_bottom = radius

func _label(size: int) -> Label:
	var l := Label.new()
	_full(l)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.modulate.a = 0.0
	return l

func _bar(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = 0.0 if top else 1.0
	r.anchor_bottom = 0.0 if top else 1.0
	r.offset_left = 0.0
	r.offset_right = 0.0
	r.offset_top = 0.0
	r.offset_bottom = 0.0
	_layer.add_child(r)
	return r

# ====================================================================== entry point

func play(id: String, args: Dictionary = {}) -> void:
	if not (id in SCENES):
		return
	while playing:
		await get_tree().process_frame
	_begin(id, args)
	match id:
		"opening": await _opening()
		"wake": await _wake()
		"day_end": await _day_end()
		"doomscroll_enter": await _doomscroll_enter()
		"doomscroll_exit": await _doomscroll_exit()
		"night_scroll": await _night_scroll()
		"ending": await _ending(String(args.get("id", "loop")))
	_end()

## Drop a running cutscene (scene exit, return to menu). The coroutine unwinds on its own.
func abort() -> void:
	if playing:
		skipped = true

func _begin(id: String, args: Dictionary) -> void:
	playing = true
	skipped = _mode == "skip"
	current_id = id
	_args = args
	_t = 0.0
	_gen += 1
	_ends_black = false
	_clears_fade = false
	_state_touched = false
	var p := _player()
	_saved = {
		"enabled": p.input_enabled if p else true,
		"detached": p.cam.top_level if p else false,
		"xform": p.cam.global_transform if p else Transform3D.IDENTITY,
		"hud": UI.hud_visible(),
		"state": Narrative.target_state,
	}
	if p:
		p.lock(true)
	UI.show_hud(false)
	UI.push_blocking()
	_reset_visuals()
	_layer.visible = true
	Events.cinema_started.emit(id)

func _end() -> void:
	_gen += 1                       # orphans any text track still waiting
	_kill_tweens()
	_restore_camera()
	if _ends_black:
		UI.set_black()
	elif _clears_fade:
		UI.fade_clear(0.01)
	if _state_touched:
		Narrative.set_state(_saved["state"], 1.5)
	_reset_visuals()
	_layer.visible = false
	var p := _player()
	if p:
		p.lock(not _saved["enabled"])
	UI.show_hud(_saved["hud"])
	UI.pop_blocking()
	playing = false
	Events.cinema_finished.emit(current_id, skipped)

func _kill_tweens() -> void:
	for t in _tweens:
		if t != null and t.is_valid():
			t.kill()
	_tweens.clear()

func _reset_visuals() -> void:
	_lid_val = 0.0
	_bar_val = 0.0
	_roll = 0.0
	_shake = 0.0
	_set_lids(0.0)
	_set_bars(0.0)
	for c in [_wash, _glow, _line, _clock, _list, _hint, _ring, _feed]:
		c.modulate = Color(1, 1, 1, 0)
	_feed.visible = false
	_feed.speed = 0.0
	_line.text = ""
	_clock.text = ""
	_list.text = ""
	_wash.color = Color.BLACK
	_ring.sweep = 0.0

func _restore_camera() -> void:
	var p := _player()
	if p == null:
		return
	if _saved["detached"]:
		p.cam.top_level = true
		p.cam.global_transform = _saved["xform"]
	else:
		p.cam.top_level = false
		p.cam.transform = Transform3D.IDENTITY
	p.cam.fov = Settings.fov
	p.vm.visible = true

func _process(delta: float) -> void:
	if not playing:
		return
	_t += delta
	if _t > MAX_SECONDS:
		skipped = true
	if _hint.modulate.a < 0.45 and _t > 1.0 and not skipped:
		_hint.modulate.a = minf(0.45, _hint.modulate.a + delta * 0.5)

func _input(event: InputEvent) -> void:
	if not playing or skipped or _t < SKIP_GUARD:
		return
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.pressed
	if pressed:
		skipped = true
		get_viewport().set_input_as_handled()

# ====================================================================== helpers

func _player() -> Player:
	var m: Node = Days.main
	if m == null or not is_instance_valid(m):
		return null
	var p = m.get("player")
	if p == null or not is_instance_valid(p):
		return null
	return p as Player

func _in_room() -> bool:
	var m: Node = Days.main
	return _player() != null and m != null and m.get("location") == "bedroom" \
			and m.get("bedroom") != null and is_instance_valid(m.get("bedroom"))

func _bedroom() -> Bedroom:
	return Days.main.get("bedroom") as Bedroom

func _soft() -> float:
	return 0.0 if Settings.reduce_motion else 1.0

func _shake_ok() -> bool:
	return Settings.camera_shake and not Settings.reduce_motion

func _wait(sec: float) -> void:
	var g := _gen
	var t := 0.0
	while t < sec and not skipped and g == _gen:
		await get_tree().process_frame
		t += get_process_delta_time()

func _tw() -> Tween:
	var t := create_tween()
	_tweens.append(t)
	return t

func _prop(obj: Object, prop: String, to, dur: float, delay: float = 0.0,
		tr: Tween.TransitionType = Tween.TRANS_SINE, ea: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	var t := _tw()
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_property(obj, prop, to, maxf(dur, 0.01)).set_trans(tr).set_ease(ea)

func _beat(name: String) -> void:
	Events.cinema_beat.emit(current_id, name)

func _state(name: String, blend: float = 2.0) -> void:
	_state_touched = true
	Narrative.set_state(name, blend)

func _set_lids(closed: float) -> void:
	_lid_val = closed
	_lid_top.anchor_bottom = closed * 0.5
	_lid_bottom.anchor_top = 1.0 - closed * 0.5

func _set_bars(v: float) -> void:
	_bar_val = v
	_top.anchor_bottom = v * BAR
	_bottom.anchor_top = 1.0 - v * BAR

func _bars(to: float, dur: float, delay: float = 0.0) -> void:
	var t := _tw()
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_method(_set_bars, _bar_val, to, maxf(dur, 0.01))

func _lids(to: float, dur: float, delay: float = 0.0) -> void:
	var t := _tw()
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_method(_set_lids, _lid_val, to, maxf(dur, 0.01))

func _black(dur: float, delay: float = 0.0) -> void:
	_wash.color = Color.BLACK
	_prop(_wash, "modulate:a", 1.0, dur, delay)

func _glow_setup(from: Vector2, to: Vector2, color: Color) -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([color, Color(color.r, color.g, color.b, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 256
	tex.height = 256
	_glow.texture = tex

## A slow, soft pulse of the glow. Reduced motion keeps it steady.
func _glow_pulse(base: float, amp: float, dur: float) -> void:
	var t := _tw()
	if Settings.reduce_motion:
		t.tween_property(_glow, "modulate:a", base, dur)
		return
	var n := maxi(1, int(dur / 0.7))
	for i in n:
		t.tween_property(_glow, "modulate:a", base + amp * (1.0 if i % 2 == 0 else -1.0), dur / n)

func _clock_text(minutes: int) -> String:
	var m := ((minutes % 1440) + 1440) % 1440
	var h := m / 60
	var ap := "AM" if h < 12 else "PM"
	h = h % 12
	if h == 0:
		h = 12
	return "%d:%02d %s" % [h, m % 60, ap]

## Show a clock that runs from one time to another, ticking as it goes.
func _clock_run(from_min: int, to_min: int, dur: float, color: Color = Color(0.9, 0.93, 1.0)) -> void:
	_clock.add_theme_color_override("font_color", color)
	_clock.text = _clock_text(from_min)
	_prop(_clock, "modulate:a", 1.0, 0.4)
	var last := [from_min]
	var t := _tw()
	t.tween_interval(0.4)
	t.tween_method(func(v: float):
		var m := int(v)
		_clock.text = _clock_text(m)
		if m - last[0] >= 6:
			last[0] = m
			Audio.play_sfx("tick", -14.0, 0.9 + 0.5 * (v - from_min) / maxf(to_min - from_min, 1.0)),
			float(from_min), float(to_min), maxf(dur - 0.4, 0.1)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _block_clock() -> int:
	return int(CLOCK_START[clampi(GameState.block, 0, 3)]) + 14

# ---- text track (lines read from data/sequences.json) ----------------------------

func _start_text(seq_id: String, center: bool = false) -> void:
	var seqs: Dictionary = Util.load_json(SEQ_FILE)
	var steps: Array = seqs.get(seq_id, {}).get("steps", [])
	if center:
		_area(_line, Rect2(0.1, 0.28, 0.8, 0.44))
	else:
		_area(_line, Rect2(0.1, 0.74, 0.8, 0.14))
	_text_busy = true
	_text_track(steps, _gen)

func _text_track(steps: Array, g: int) -> void:
	for s in steps:
		if skipped or g != _gen:
			break
		if s.has("if") and not Dialogue.check(s["if"]):
			continue
		match String(s.get("t", "")):
			"text":
				await _show_line(Dialogue.fill(String(s.get("text", ""))), float(s.get("hold", 1.6)),
						int(s.get("size", 30)), String(s.get("color", "")), g)
			"pool":
				var l := Dialogue.pick_from_pool(String(s["file"]), String(s["pool"]))
				if not l.is_empty():
					await _show_line(String(l["text"]), float(s.get("hold", 1.8)), int(s.get("size", 28)), "", g)
			"pause":
				await _wait(float(s.get("s", 1.0)))
			"sfx":
				Audio.play_sfx(String(s["name"]), float(s.get("db", 0.0)))
	if g == _gen:
		_text_busy = false

func _show_line(text: String, hold: float, size: int, color: String, g: int) -> void:
	var col := Color(0.96, 0.94, 0.9)
	if color == "warn":
		col = Settings.warn_color()
	elif color == "accent":
		col = Settings.accent_color()
	_line.text = text
	_line.add_theme_font_size_override("font_size", size)
	_line.add_theme_color_override("font_color", col)
	_line.modulate.a = 0.0
	var tw := _tw()
	tw.tween_property(_line, "modulate:a", 1.0, 0.35)
	await _wait(0.35 + hold)
	if g != _gen:
		return
	var out := _tw()
	out.tween_property(_line, "modulate:a", 0.0, 0.35)
	await _wait(0.35)

func _finish_text() -> void:
	var g := _gen
	while _text_busy and not skipped and g == _gen:
		await get_tree().process_frame

# ---- camera ------------------------------------------------------------------

func _detach() -> void:
	var p := _player()
	if p == null or p.cam.top_level:
		return
	var g := p.cam.global_transform
	p.cam.top_level = true
	p.cam.global_transform = g
	p.vm.visible = false            # no floating hands in a flying shot

func _apply_cam(t: Transform3D) -> void:
	var p := _player()
	if p == null:
		return
	var b := t.basis
	if absf(_roll) > 0.0001:
		b = b * Basis(Vector3.BACK, _roll)
	var o := t.origin
	if _shake > 0.0 and _shake_ok():
		var s := Time.get_ticks_msec() * 0.001
		o += Vector3(sin(s * 31.0), cos(s * 27.0), sin(s * 19.0)) * _shake
	p.cam.global_transform = Transform3D(b, o)

func _pose(pos: Vector3, look_dir: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(look_dir, Vector3.UP), pos)

## Queue one camera move on `tw`. target: a Transform3D or a Callable returning one (a moving goal).
func _leg(tw: Tween, target, dur: float, tr: Tween.TransitionType = Tween.TRANS_SINE,
		ea: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	var p := _player()
	if p == null:
		return
	var st: Array = [Transform3D.IDENTITY]
	tw.tween_callback(func(): st[0] = p.cam.global_transform)
	tw.tween_method(func(w: float):
		var to: Transform3D = target.call() if target is Callable else target
		var from: Transform3D = st[0]
		var q := from.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), w)
		_apply_cam(Transform3D(Basis(q), from.origin.lerp(to.origin, w))),
			0.0, 1.0, maxf(dur, 0.01)).set_trans(tr).set_ease(ea)

func _hold_cam(tw: Tween, dur: float) -> void:
	_leg(tw, func(): return _player().cam.global_transform, dur)

func _head_pose() -> Transform3D:
	return _player().head.global_transform

func _fov(to: float, dur: float, delay: float = 0.0) -> void:
	var p := _player()
	if p != null and not Settings.reduce_motion:
		_prop(p.cam, "fov", to, dur, delay)

## Camera over the pillow, eyes up at the ceiling (bed is at the west wall, head to the north).
func _pillow_pose() -> Transform3D:
	return _pose(Vector3(-2.2, 0.9, -2.1), Vector3(0.15, 0.9, 0.45))

func _sitting_up_pose() -> Transform3D:
	return _pose(Vector3(-2.0, 1.15, -1.75), Vector3(0.9, -0.08, 0.5))

# ====================================================================== scenes

## Title: three lines, a ring that almost closes, CYCLE.
func _opening() -> void:
	_bars(1.0, 0.9)
	Audio.set_music("lofi1", 3.0)
	_ring.modulate.a = 0.0
	_prop(_ring, "modulate:a", 0.55, 2.0, 0.5)
	_prop(_ring, "sweep", TAU * 0.9, 9.0, 0.5, Tween.TRANS_SINE, Tween.EASE_OUT)
	_start_text("cin_opening", true)
	await _wait(5.0)
	_beat("lines")
	await _wait(3.4)
	_beat("title")
	await _finish_text()
	_prop(_ring, "modulate:a", 0.0, 0.9)
	_bars(0.0, 0.8)
	await _wait(0.9)

## Eyes open on the ceiling, sit up, the day begins.
func _wake() -> void:
	var day := int(_args.get("day", GameState.day))
	_clears_fade = true
	_set_lids(1.0)
	_bars(1.0, 0.8)
	UI.fade_clear(0.4)
	Audio.play_sfx("buzz", -12.0)
	UI.caption("[phone alarm]")
	var cold := day >= 4 and not GameState.cycle_broken
	_wash.color = Color(0.72, 0.78, 0.92) if cold else Color(1.0, 0.86, 0.6)
	_wash.modulate.a = 0.3
	_prop(_wash, "modulate:a", 0.0, 3.4)
	var lids := _tw()
	lids.tween_interval(0.4)
	if Settings.reduce_motion:
		lids.tween_method(_set_lids, 1.0, 0.0, 1.8)
	else:
		lids.tween_method(_set_lids, 1.0, 0.55, 0.6)
		lids.tween_method(_set_lids, 0.55, 0.9, 0.3)
		lids.tween_method(_set_lids, 0.9, 0.2, 0.6)
		lids.tween_method(_set_lids, 0.2, 0.0, 0.7)
	var total := 4.6 if day <= 1 else 4.2
	if _in_room():
		_detach()
		var cam_tw := _tw()
		if Settings.reduce_motion:
			_apply_cam(_sitting_up_pose())
			_hold_cam(cam_tw, 0.4)
			_leg(cam_tw, _head_pose, 2.0)
		else:
			_apply_cam(_pillow_pose())
			_roll = deg_to_rad(-8.0)
			_prop(self, "_roll", 0.0, 3.0)
			_hold_cam(cam_tw, 0.8)
			_leg(cam_tw, _sitting_up_pose(), 1.5)
			_leg(cam_tw, _head_pose, 1.4)
	_start_text("cin_wake")
	await _wait(total * 0.5)
	_beat("waking")
	await _wait(total * 0.5)
	if GameState.get_psy("pressure") >= 60.0 and not GameState.cycle_broken:
		Audio.play_sfx("heart", -10.0)
	await _finish_text()
	_bars(0.0, 0.5)
	await _wait(0.5)

## Lie back, the ceiling, the eyes close.
func _day_end() -> void:
	_bars(1.0, 0.7)
	Audio.play_sfx("creak", -8.0)
	var dur := 2.8
	if _in_room():
		_detach()
		var tw := _tw()
		_leg(tw, _sitting_up_pose(), dur * 0.45)
		_leg(tw, _pillow_pose(), dur * 0.55)
	var late: int = CLOCK_START[3] + 40
	_clock_run(late, late + 12, 2.4)
	_start_text("cin_day_end")
	await _wait(dur)
	_beat("lying")
	_lids(1.0, 1.3)
	_prop(_clock, "modulate:a", 0.0, 1.0)
	await _wait(1.3)
	_black(0.5)
	await _wait(0.6)
	_ends_black = true

## Phone light on the ceiling, the clock runs away from you.
func _night_scroll() -> void:
	var minutes := int(_args.get("minutes", 60))
	var start: int = CLOCK_START[3] + 40
	_bars(1.0, 0.7)
	Audio.play_sfx("creak", -8.0)
	_glow_setup(Vector2(0.5, 1.0), Vector2(0.5, 0.25), Color(0.55, 0.72, 1.0, 0.9))
	_glow.modulate.a = 0.0
	_feed.set_layout(Rect2(0.36, 0.5, 0.28, 0.5))
	if _in_room():
		_detach()
		var tw := _tw()
		_leg(tw, _sitting_up_pose(), 1.2)
		_leg(tw, _pillow_pose(), 1.4)
		_hold_cam(tw, 5.0)
	_prop(_glow, "modulate:a", 0.7, 1.5, 1.8)
	_feed.visible = true
	_feed.modulate.a = 0.0
	_prop(_feed, "modulate:a", 0.8, 0.8, 2.2)
	_prop(_feed, "speed", 900.0, 3.0, 2.4, Tween.TRANS_QUAD, Tween.EASE_IN)
	_clock_run(start, start + minutes, 3.8, Color(0.9, 0.93, 1.0))
	_start_text("cin_night_scroll")
	await _wait(2.6)
	_beat("scrolling")
	await _wait(2.8)
	_clock.add_theme_color_override("font_color", Settings.warn_color())
	_beat("late")
	_prop(_feed, "speed", 120.0, 1.0)
	_glow_pulse(0.35, 0.0, 1.2)
	_lids(1.0, 1.5)
	await _wait(1.6)
	_black(0.5)
	await _wait(0.6)
	_ends_black = true

## Pull into the screen; the feed accelerates; the colour drains.
func _doomscroll_enter() -> void:
	var p := _player()
	_bars(1.0, 0.5)
	_glow_setup(Vector2(0.5, 0.5), Vector2(0.5, 1.05), Color(0.55, 0.72, 1.0, 0.9))
	_glow.modulate.a = 0.0
	_feed.set_layout(Rect2(0.3, 0.1, 0.4, 0.8))
	_feed.visible = true
	_feed.modulate.a = 0.0
	_prop(_feed, "modulate:a", 0.85, 0.6)
	_prop(_feed, "speed", 1100.0, 2.4, 0.0, Tween.TRANS_QUAD, Tween.EASE_IN)
	_prop(_glow, "modulate:a", 0.55, 2.0)
	_state("LOOP", 2.0)
	if p != null and _saved["detached"]:
		var fwd: Vector3 = -(_saved["xform"] as Transform3D).basis.z
		var tw := _tw()
		var to: Transform3D = _saved["xform"]
		to.origin += fwd * (0.12 if Settings.reduce_motion else 0.3)
		_leg(tw, to, 2.6, Tween.TRANS_QUAD, Tween.EASE_IN)
	_fov(Settings.fov - 12.0, 2.6)
	_start_text("cin_doomscroll_enter")
	var tick := _tw()
	for i in 8:
		tick.tween_interval(0.42 - i * 0.04)
		tick.tween_callback(func(): Audio.play_sfx("tick", -12.0, 1.0 + i * 0.06))
	await _wait(1.7)
	_beat("pull")
	await _wait(0.9)
	_black(0.5)
	await _wait(0.6)
	_ends_black = true
	_state_touched = false          # the exit scene settles the mood

## The clock jumps while the screen is dark; the room comes back later than it should.
func _doomscroll_exit() -> void:
	var minutes := int(_args.get("minutes", 90))
	var start: int = _block_clock()
	_wash.color = Color.BLACK
	_wash.modulate.a = 1.0
	_clears_fade = true
	UI.fade_clear(0.01)
	_bars(1.0, 0.4)
	_feed.set_layout(Rect2(0.3, 0.1, 0.4, 0.8))
	_feed.visible = true
	_feed.speed = 900.0
	_feed.modulate.a = 0.0
	_prop(_feed, "modulate:a", 0.5, 0.5)
	_prop(_feed, "speed", 0.0, 2.0, 0.2)
	_clock_run(start, start + minutes, 2.2, Settings.warn_color())
	_start_text("cin_doomscroll_exit")
	await _wait(1.8)
	_beat("clock")
	await _wait(0.8)
	_prop(_clock, "modulate:a", 0.0, 0.5)
	_prop(_feed, "modulate:a", 0.0, 0.5)
	_prop(_glow, "modulate:a", 0.0, 0.8)
	_prop(_wash, "modulate:a", 0.0, 0.9)
	_bars(0.0, 0.7, 0.3)
	Narrative.settle(2.0)
	await _finish_text()
	await _wait(0.4)

# ---- endings ---------------------------------------------------------------------------------

func _ending(id: String) -> void:
	if UI.fade_alpha() > 0.5:
		# arriving from a black fade (after the night's sequences): bring the room up under our own black
		_wash.color = Color.BLACK
		_wash.modulate.a = 1.0
		UI.fade_clear(0.01)
		_prop(_wash, "modulate:a", 0.0, 1.0)
	_start_text("cin_end_" + id)
	match id:
		"escape": await _end_escape()
		"awareness": await _end_awareness()
		"burnout": await _end_burnout()
		"false_productivity": await _end_false_productivity()
		_: await _end_loop()
	_ends_black = true

## Light comes in: a slow drift to the window, warm bloom, white.
func _end_escape() -> void:
	_bars(1.0, 0.9)
	_state("ESCAPE", 1.5)
	Audio.play_sfx("ding", -4.0)
	_glow_setup(Vector2(0.78, 0.4), Vector2(0.78, 1.2), Color(1.0, 0.92, 0.7, 1.0))
	_glow.modulate.a = 0.0
	if _in_room():
		_detach()
		var tw := _tw()
		_hold_cam(tw, 0.3)
		_leg(tw, _pose(Vector3(0.2, 1.75, 0.5), Vector3(2.8, -0.15, -1.1)), 4.0)
		_leg(tw, _pose(Vector3(1.0, 1.7, 0.1), Vector3(2.0, -0.05, -0.7)), 5.0)
	_prop(_glow, "modulate:a", 0.9, 5.0, 1.0)
	_wash.color = Color(1.0, 0.97, 0.88)
	_prop(_wash, "modulate:a", 1.0, 2.2, 6.0)
	Audio.play_sfx("win", -10.0)
	await _wait(5.0)
	_beat("light")
	await _wait(3.4)
	await _finish_text()
	_prop(_wash, "modulate", Color.BLACK, 1.2)
	await _wait(1.3)

## Turn from the screen to the door, walk to it, open it.
func _end_awareness() -> void:
	_bars(1.0, 0.9)
	_state("RECOGNITION", 2.0)
	_glow_setup(Vector2(0.5, 0.55), Vector2(0.5, 1.0), Color(1.0, 0.95, 0.8, 1.0))
	_glow.modulate.a = 0.0
	var room := _in_room()
	if room:
		_detach()
		var p := _player()
		var door := Vector3(-1.18, 1.1, 2.45)
		var eye := p.cam.global_position
		var tw := _tw()
		_hold_cam(tw, 0.3)
		_leg(tw, _pose(eye, door - eye), 2.2)
		_leg(tw, _pose(Vector3(-1.18, 1.45, 1.35), Vector3(0, -0.2, 1)), 4.2, Tween.TRANS_SINE, Tween.EASE_IN)
	_prop(_glow, "modulate:a", 0.7, 3.0, 3.0)
	await _wait(6.4)
	_beat("door")
	if room:
		_bedroom().open_door()
	_wash.color = Color(1.0, 0.98, 0.9)
	_prop(_wash, "modulate:a", 1.0, 1.6)
	await _wait(2.0)
	await _finish_text()
	_prop(_wash, "modulate", Color.BLACK, 1.0)
	await _wait(1.1)

## The body gives out: the eye line drops, the room tilts, the heartbeat slows.
func _end_burnout() -> void:
	_bars(1.0, 0.7)
	_state("INTENSIFICATION", 1.0)
	_shake = 0.012
	_prop(self, "_shake", 0.0, 3.0)
	if _in_room():
		_detach()
		var p := _player()
		var eye := p.cam.global_position
		var floor_pose := _pose(Vector3(eye.x, 0.28, eye.z), Vector3(0.3, 0.9, -0.3))
		var tw := _tw()
		_hold_cam(tw, 0.8)
		_leg(tw, floor_pose, 2.6, Tween.TRANS_QUAD, Tween.EASE_IN)
		_prop(self, "_roll", deg_to_rad(70.0) * _soft(), 2.6, 0.8, Tween.TRANS_QUAD, Tween.EASE_IN)
		_hold_cam(tw, 4.0)
	var hb := _tw()
	hb.tween_interval(0.5)
	for gap in [0.55, 0.7, 0.95, 1.4]:
		hb.tween_callback(func(): Audio.play_sfx("heart", -4.0))
		hb.tween_interval(gap)
	await _wait(3.3)
	Audio.play_sfx("thud", -4.0)
	_beat("down")
	_lids(1.0, 3.0)
	await _wait(3.2)
	await _finish_text()
	_black(0.6)
	await _wait(0.7)

## Everything is checked off. Except the one thing.
func _end_false_productivity() -> void:
	_bars(1.0, 0.8)
	var rows := ["[x]  Room cleaned", "[x]  Folders organized", "[x]  Research (17 tabs)", "[x]  Folders, again", "[ ]  The essay"]
	_list.text = ""
	_list.modulate.a = 0.0
	if _in_room():
		_detach()
		var tw := _tw()
		_leg(tw, _pose(Vector3(-0.4, 1.6, 1.9), Vector3(0.2, -0.12, -1.0)), 2.2)
		_leg(tw, _pose(Vector3(1.5, 1.55, 1.9), Vector3(-0.1, -0.18, -1.0)), 5.5)
	_prop(_list, "modulate:a", 1.0, 0.6, 1.0)
	var shown := [0]
	var reveal := _tw()
	reveal.tween_interval(1.2)
	for i in rows.size():
		reveal.tween_callback(func():
			shown[0] += 1
			_list.text = "\n".join(rows.slice(0, shown[0]))
			Audio.play_sfx("ding", -12.0 if i < rows.size() - 1 else -8.0, 0.9 + i * 0.08))
		reveal.tween_interval(1.1)
	await _wait(6.8)
	_state("RECOGNITION", 2.0)
	_beat("checklist")
	await _wait(1.6)
	await _finish_text()
	_prop(_list, "modulate:a", 0.0, 0.6)
	_black(1.0)
	await _wait(1.1)

## Days run backwards; the shot pulls away from you and the world goes flat.
func _end_loop() -> void:
	var day := maxi(1, GameState.day)
	_bars(1.0, 0.7)
	_state("LOOP", 1.5)
	_clock.add_theme_color_override("font_color", Settings.warn_color())
	_clock.text = "DAY %d" % day
	_prop(_clock, "modulate:a", 1.0, 0.5)
	if _in_room():
		# a dolly zoom on the room from the doorway: the camera backs away while the lens tightens
		_detach()
		var look := Vector3(0.7, -0.1, -1.0)
		_apply_cam(_pose(Vector3(-0.6, 1.5, 1.2), look))
		var tw := _tw()
		_hold_cam(tw, 0.3)
		_leg(tw, _pose(Vector3(-1.0, 1.55, 2.3), look), 5.0)
		_fov(Settings.fov - 30.0, 5.0)
	var count := _tw()
	count.tween_interval(1.0)
	var steps := mini(day - 1, 7)
	for i in steps:
		var d := day - 1 - i
		count.tween_callback(func():
			_clock.text = "DAY %d" % d
			Audio.play_sfx("tick", -8.0, 0.8 + i * 0.1))
		count.tween_interval(maxf(0.55 - i * 0.05, 0.18))
	await _wait(1.0 + steps * 0.4 + 0.5)
	_beat("rewind")
	_clock.text = "DAY 1"
	Audio.play_sfx("swoosh", -6.0)
	await _wait(1.6)
	await _finish_text()
	_lids(1.0, 0.35)
	_black(0.4, 0.2)
	await _wait(0.7)

# ====================================================================== overlays drawn in code

## A column of scrolling "cards": the feed.
class _Feed extends Control:
	var speed := 0.0
	var _off := 0.0
	var _cards: Array = []

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 14:
			_cards.append({"h": rng.randf_range(70.0, 170.0), "hue": rng.randf_range(0.5, 0.72), "lines": rng.randi_range(1, 3)})

	func set_layout(r: Rect2) -> void:
		anchor_left = r.position.x
		anchor_top = r.position.y
		anchor_right = r.position.x + r.size.x
		anchor_bottom = r.position.y + r.size.y
		offset_left = 0.0
		offset_top = 0.0
		offset_right = 0.0
		offset_bottom = 0.0

	func _process(delta: float) -> void:
		if visible:
			_off += speed * delta
			queue_redraw()

	func _draw() -> void:
		var total := 0.0
		for c in _cards:
			total += float(c["h"]) + 14.0
		var y := -fposmod(_off, total)
		var i := 0
		while y < size.y:
			var c: Dictionary = _cards[i % _cards.size()]
			var h: float = c["h"]
			if y + h > 0.0:
				var col := Color.from_hsv(c["hue"], 0.35, 0.9, 0.55)
				draw_rect(Rect2(0.0, y, size.x, h), col)
				draw_rect(Rect2(10.0, y + 10.0, size.x * 0.35, 8.0), Color(1, 1, 1, 0.7))
				for l in int(c["lines"]):
					draw_rect(Rect2(10.0, y + 30.0 + l * 16.0, size.x * (0.8 - l * 0.18), 6.0), Color(1, 1, 1, 0.35))
			y += h + 14.0
			i += 1

## An almost-closed circle, slowly turning.
class _Ring extends Control:
	var sweep := 0.0:
		set(v):
			sweep = v
			queue_redraw()
	var _spin := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if visible and modulate.a > 0.01:
			_spin += delta * (0.0 if Settings.reduce_motion else 0.35)
			queue_redraw()

	func _draw() -> void:
		if sweep <= 0.01:
			return
		var c := size * 0.5
		draw_arc(c, minf(size.x, size.y) * 0.45, _spin - PI / 2.0, _spin - PI / 2.0 + sweep, 96, Settings.warn_color(), 3.0, true)
