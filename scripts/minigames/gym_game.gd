class_name GymGame
extends Control
## Four tiny timing games. mode: bench | dumbbell | bag | treadmill.
## Press E / Space / click on the beat. Emits finished({score: 0..1}).

signal finished(result: Dictionary)

var mode := "bench"
var title_override := ""
var _title: Label
var _info: Label
var _bar: Control
var _marker_x := 0.0
var _dir := 1.0
var _speed := 0.9
var _reps := 0
var _good := 0
var _total_reps := 5
var _zone_c := 0.5
var _zone_w := 0.18
var _fill := 0.0
var _time := 0.0
var _hold := false
var _running := false
var _score_acc := 0.0
var _done := false
var _pulse := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	UITheme.center(panel, Vector2(640, 260))
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	_title = UITheme.label("", 28)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)
	_info = UITheme.label("", 18, Color(1, 1, 1, 0.7))
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_info)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(580, 70)
	_bar.draw.connect(_draw_bar)
	vb.add_child(_bar)
	var hint := UITheme.label("E / Space / click", 15, Color(1, 1, 1, 0.45))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	var quit := UITheme.button("Stop")
	quit.pressed.connect(func(): _finish())
	vb.add_child(quit)
	_start()
	if title_override != "":
		_title.text = title_override

func _start() -> void:
	_running = true
	match mode:
		"bench":
			_title.text = "Bench press"
			_total_reps = 5
			_speed = 0.8
			_new_zone()
			_info.text = "Press when the marker is in the green zone."
		"dumbbell":
			_title.text = "Dumbbell curls"
			_total_reps = 6
			_speed = 1.15
			_new_zone()
			_info.text = "Faster rhythm. Stay smooth."
		"bag":
			_title.text = "Punching bag"
			_info.text = "Mash the key! Fill the bar before time runs out."
			_time = 6.0
		"treadmill":
			_title.text = "Treadmill"
			_info.text = "Hold the key to speed up. Release to ease off. Stay in the zone."
			_time = 10.0
			_marker_x = 0.4
			_zone_c = 0.62
			_zone_w = 0.22

func _new_zone() -> void:
	_zone_c = randf_range(0.25, 0.75)
	_zone_w = maxf(0.1, 0.2 - _reps * 0.015)

func _is_press(e: InputEvent) -> bool:
	return e.is_action_pressed("interact") or (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_SPACE) \
			or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT)

func _is_release(e: InputEvent) -> bool:
	return e.is_action_released("interact") or (e is InputEventKey and not e.pressed and e.keycode == KEY_SPACE) \
			or (e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT)

func _input(e: InputEvent) -> void:
	if _done or not _running:
		return
	if _is_press(e):
		get_viewport().set_input_as_handled()
		_hold = true
		match mode:
			"bench", "dumbbell":
				_press_rep()
			"bag":
				_fill = minf(1.0, _fill + 0.045)
				_pulse = 1.0
				Audio.play_sfx("thud", -10.0, randf_range(0.9, 1.2))
	elif _is_release(e):
		_hold = false

func _press_rep() -> void:
	var dist := absf(_marker_x - _zone_c)
	var ok := dist <= _zone_w / 2.0
	_reps += 1
	if ok:
		_good += 1
		_score_acc += 1.0 - dist / (_zone_w / 2.0) * 0.4
		Audio.play_sfx("ding", -8.0)
		_info.text = "Clean rep! %d/%d" % [_reps, _total_reps]
	else:
		Audio.play_sfx("lose", -14.0)
		_info.text = "Sloppy. %d/%d" % [_reps, _total_reps]
		_score_acc += 0.2
	_pulse = 1.0
	if _reps >= _total_reps:
		_finish()
	else:
		_new_zone()
		_speed += 0.12

func _process(delta: float) -> void:
	if _done or not _running:
		return
	_pulse = maxf(0.0, _pulse - delta * 3.0)
	match mode:
		"bench", "dumbbell":
			_marker_x += _dir * _speed * delta
			if _marker_x > 1.0:
				_marker_x = 1.0
				_dir = -1.0
			elif _marker_x < 0.0:
				_marker_x = 0.0
				_dir = 1.0
		"bag":
			_time -= delta
			_fill = maxf(0.0, _fill - delta * 0.12)
			_score_acc = _fill
			if _fill >= 1.0 or _time <= 0.0:
				_finish()
		"treadmill":
			_time -= delta
			_marker_x += ((0.55 if _hold else -0.35) * delta)
			_marker_x = clampf(_marker_x, 0.0, 1.0)
			if absf(_marker_x - _zone_c) <= _zone_w / 2.0:
				_good += 1
				_score_acc += delta
			if _time <= 0.0:
				_finish()
	_bar.queue_redraw()

func _draw_bar() -> void:
	var w := _bar.size.x
	var h := 36.0
	var y := 18.0
	_bar.draw_style_box(UITheme.box(Color(1, 1, 1, 0.08), 8), Rect2(0, y, w, h))
	match mode:
		"bench", "dumbbell", "treadmill":
			var zc := _zone_c * w
			var zw := _zone_w * w
			_bar.draw_rect(Rect2(zc - zw / 2.0, y, zw, h), Color(Settings.good_color(), 0.55))
			var mx := _marker_x * w
			_bar.draw_rect(Rect2(mx - 4, y - 8, 8, h + 16), Settings.accent_color())
		"bag":
			_bar.draw_rect(Rect2(0, y, w * _fill, h), Settings.accent_color())
			_bar.draw_string(ThemeDB.fallback_font, Vector2(w / 2 - 20, y + 62), "%.1fs" % maxf(_time, 0.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.6))
	if mode == "treadmill":
		_bar.draw_string(ThemeDB.fallback_font, Vector2(w / 2 - 20, y + 62), "%.1fs" % maxf(_time, 0.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.6))

func _finish() -> void:
	if _done:
		return
	_done = true
	var score := 0.0
	match mode:
		"bench", "dumbbell":
			score = clampf(_score_acc / float(_total_reps), 0.0, 1.0)
		"bag":
			score = clampf(_fill, 0.0, 1.0)
		"treadmill":
			score = clampf(_score_acc / 10.0, 0.0, 1.0) if _time <= 0 else clampf(_score_acc / 10.0, 0.0, 1.0)
	finished.emit({"score": score, "mode": mode})
