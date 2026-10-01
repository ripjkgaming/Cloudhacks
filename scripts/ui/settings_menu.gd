class_name SettingsMenu
extends Control
## Audio, camera, accessibility and key rebinding. Emits `closed`.

signal closed

var _rebinding := ""
var _bind_buttons := {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 220
	scroll.offset_right = -220
	scroll.offset_top = 30
	scroll.offset_bottom = -30
	add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	scroll.add_child(vb)
	vb.add_child(UITheme.label("Settings", 34))
	_section(vb, "Audio")
	_slider(vb, "Master volume", 0.0, 1.0, Settings.master_volume, func(v): Settings.master_volume = v)
	_slider(vb, "Music volume", 0.0, 1.0, Settings.music_volume, func(v): Settings.music_volume = v)
	_slider(vb, "Effects volume", 0.0, 1.0, Settings.sfx_volume, func(v): Settings.sfx_volume = v)
	_section(vb, "Camera")
	_slider(vb, "Mouse sensitivity", 0.0008, 0.006, Settings.mouse_sensitivity, func(v): Settings.mouse_sensitivity = v)
	_slider(vb, "Field of view", 60.0, 105.0, Settings.fov, func(v): Settings.fov = v)
	_section(vb, "Accessibility")
	_check(vb, "Subtitles and sound captions", Settings.subtitles, func(v): Settings.subtitles = v)
	_slider(vb, "Subtitle size", 16.0, 36.0, float(Settings.subtitle_size), func(v): Settings.subtitle_size = int(v))
	_check(vb, "Motion sickness reduction (no head bob, softer effects)", Settings.reduce_motion, func(v): Settings.reduce_motion = v)
	_check(vb, "Camera shake", Settings.camera_shake, func(v): Settings.camera_shake = v)
	_check(vb, "Colour-blind friendly UI", Settings.colorblind, func(v): Settings.colorblind = v)
	_section(vb, "Controls (click, then press a key)")
	for a in Settings.ACTIONS:
		var hb := HBoxContainer.new()
		var l := UITheme.label(Settings.ACTIONS[a]["label"], 19)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l)
		var b := UITheme.button(OS.get_keycode_string(Settings.bindings[a]), 18)
		b.custom_minimum_size = Vector2(160, 0)
		b.pressed.connect(func():
			_rebinding = a
			b.text = "press a key...")
		hb.add_child(b)
		_bind_buttons[a] = b
		vb.add_child(hb)
	var back := UITheme.button("Back", 22)
	back.pressed.connect(func():
		Settings.save_settings()
		closed.emit())
	vb.add_child(back)

func _section(vb: VBoxContainer, t: String) -> void:
	var l := UITheme.label(t, 22, Settings.accent_color())
	vb.add_child(l)

func _slider(vb: VBoxContainer, name: String, lo: float, hi: float, val: float, cb: Callable) -> void:
	var hb := HBoxContainer.new()
	var l := UITheme.label(name, 19)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 100.0
	s.value = val
	s.custom_minimum_size = Vector2(260, 24)
	s.value_changed.connect(func(v):
		cb.call(v)
		Settings.changed.emit())
	hb.add_child(s)
	vb.add_child(hb)

func _check(vb: VBoxContainer, name: String, val: bool, cb: Callable) -> void:
	var c := CheckBox.new()
	c.text = name
	c.button_pressed = val
	c.add_theme_font_size_override("font_size", 19)
	c.toggled.connect(func(v):
		cb.call(v)
		Settings.changed.emit())
	vb.add_child(c)

func _input(e: InputEvent) -> void:
	if _rebinding != "" and e is InputEventKey and e.pressed:
		get_viewport().set_input_as_handled()
		if e.physical_keycode != KEY_ESCAPE:
			Settings.rebind(_rebinding, e.physical_keycode)
		_bind_buttons[_rebinding].text = OS.get_keycode_string(Settings.bindings[_rebinding])
		_rebinding = ""
