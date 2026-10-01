extends CanvasLayer
## Owns every screen-space layer: post-fx, HUD, dialogue, choice menus, cinematic
## text sequences, fades and full-screen apps (computer, minigames).
## Everything awaitable so story code reads top-to-bottom.

signal _advance
signal _choice_done(index: int)

const L_FX := 1
const L_HUD := 2
const L_DIALOGUE := 5
const L_SCREEN := 4
const L_SEQ := 6
const L_FADE := 10

var hooks := {}                    # name -> Callable (awaitable); registered by Main/world scripts
var gameplay_active := false:
	set(v):
		gameplay_active = v
		_refresh_mouse()
var _blocking := 0
var busy_dialogue := false         # true while say()/choose() is on screen
var current_options: Array = []    # labels of the choice currently shown (used by QA bots)

var _fx_layer: CanvasLayer
var _fx_rect: ColorRect
var _fx_mat: ShaderMaterial
var _hud: Control
var _crosshair: Control
var _prompt: Label
var _bark: Label
var _caption: Label
var _toasts: VBoxContainer
var _day_label: Label
var _dlg_layer: CanvasLayer
var _dlg_panel: PanelContainer
var _dlg_speaker: Label
var _dlg_text: RichTextLabel
var _dlg_hint: Label
var _dlg_choices: VBoxContainer
var _choice_layer: CanvasLayer
var _choice_root: Control
var _screen_layer: CanvasLayer
var _seq_layer: CanvasLayer
var _seq_bg: ColorRect
var _seq_label: Label
var _fade_layer: CanvasLayer
var _fade: ColorRect
var _typing_tween: Tween
var _bark_tween: Tween
var _awaiting_advance := false
var _awaiting_choice := false
var _choice_count := 0
var _choice_cancel := -1

func _ready() -> void:
	layer = 0
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fx()
	_build_hud()
	_build_dialogue()
	_build_choice()
	_build_screens()
	_build_seq()
	_build_fade()
	Events.notification.connect(toast)
	Settings.changed.connect(_apply_settings)
	_apply_settings()

func _mk_layer(l: int) -> CanvasLayer:
	var c := CanvasLayer.new()
	c.layer = l
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(c)
	return c

func _full(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ---------------------------------------------------------------- build

func _build_fx() -> void:
	_fx_layer = _mk_layer(L_FX)
	_fx_rect = ColorRect.new()
	_full(_fx_rect)
	_fx_mat = ShaderMaterial.new()
	_fx_mat.shader = load("res://scripts/ui/postfx.gdshader")
	_fx_rect.material = _fx_mat
	_fx_layer.add_child(_fx_rect)

func _build_hud() -> void:
	var l := _mk_layer(L_HUD)
	_hud = Control.new()
	_full(_hud)
	_hud.theme = UITheme.get_theme()
	l.add_child(_hud)
	_crosshair = Control.new()
	_full(_crosshair)
	_crosshair.draw.connect(func():
		var c := _crosshair.size / 2.0
		var hot := _prompt.text != ""
		_crosshair.draw_circle(c, 3.5 if hot else 2.0, Color(1, 1, 1, 0.75 if hot else 0.35)))
	_hud.add_child(_crosshair)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position = Vector2(-150, 24)
	_prompt.size = Vector2(300, 30)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 17)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_prompt.add_theme_constant_override("outline_size", 5)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_prompt)
	_bark = Label.new()
	_bark.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bark.anchor_left = 0.2
	_bark.anchor_right = 0.8
	_bark.offset_top = -150
	_bark.offset_bottom = -90
	_bark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bark.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bark.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_bark.add_theme_constant_override("outline_size", 6)
	_bark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bark.modulate.a = 0.0
	_hud.add_child(_bark)
	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.anchor_left = 0.25
	_caption.anchor_right = 0.75
	_caption.offset_top = -64
	_caption.offset_bottom = -34
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 15)
	_caption.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_caption.add_theme_constant_override("outline_size", 4)
	_caption.modulate.a = 0.0
	_hud.add_child(_caption)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.anchor_left = 1.0
	_toasts.offset_left = -330
	_toasts.offset_top = 24
	_toasts.offset_right = -24
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_toasts)
	_day_label = Label.new()
	_day_label.position = Vector2(32, 26)
	_day_label.add_theme_font_size_override("font_size", 22)
	_day_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_day_label.add_theme_constant_override("outline_size", 5)
	_day_label.modulate.a = 0.0
	_hud.add_child(_day_label)
	_hud.visible = false

func _build_dialogue() -> void:
	_dlg_layer = _mk_layer(L_DIALOGUE)
	var root := Control.new()
	_full(root)
	root.theme = UITheme.get_theme()
	_dlg_layer.add_child(root)
	_dlg_panel = PanelContainer.new()
	_dlg_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dlg_panel.anchor_left = 0.18
	_dlg_panel.anchor_right = 0.82
	_dlg_panel.anchor_top = 1.0
	_dlg_panel.anchor_bottom = 1.0
	_dlg_panel.offset_top = -210
	_dlg_panel.offset_bottom = -34
	_dlg_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_dlg_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_dlg_panel.add_child(vb)
	_dlg_speaker = UITheme.label("", 18, Settings.accent_color())
	vb.add_child(_dlg_speaker)
	_dlg_text = RichTextLabel.new()
	_dlg_text.bbcode_enabled = true
	_dlg_text.fit_content = true
	_dlg_text.scroll_active = false
	_dlg_text.custom_minimum_size = Vector2(0, 52)
	_dlg_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_dlg_text)
	_dlg_choices = VBoxContainer.new()
	_dlg_choices.add_theme_constant_override("separation", 6)
	vb.add_child(_dlg_choices)
	_dlg_hint = UITheme.label("", 14, Color(1, 1, 1, 0.4))
	_dlg_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(_dlg_hint)
	_dlg_panel.gui_input.connect(_on_dialogue_gui_input)
	_dlg_panel.visible = false

func _build_choice() -> void:
	_choice_layer = _mk_layer(L_DIALOGUE)
	_choice_root = Control.new()
	_full(_choice_root)
	_choice_root.theme = UITheme.get_theme()
	_choice_layer.add_child(_choice_root)
	_choice_root.visible = false

func _build_screens() -> void:
	_screen_layer = _mk_layer(L_SCREEN)

func _build_seq() -> void:
	_seq_layer = _mk_layer(L_SEQ)
	_seq_bg = ColorRect.new()
	_full(_seq_bg)
	_seq_bg.color = Color.BLACK
	_seq_bg.modulate.a = 0.0
	_seq_layer.add_child(_seq_bg)
	_seq_label = Label.new()
	_full(_seq_label)
	_seq_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seq_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_seq_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_seq_label.offset_left = 120
	_seq_label.offset_right = -120
	_seq_label.add_theme_font_size_override("font_size", 34)
	_seq_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_seq_label.add_theme_constant_override("outline_size", 6)
	_seq_label.visible_ratio = 0.0
	_seq_layer.add_child(_seq_label)

func _build_fade() -> void:
	_fade_layer = _mk_layer(L_FADE)
	_fade = ColorRect.new()
	_full(_fade)
	_fade.color = Color.BLACK
	_fade.modulate.a = 1.0
	_fade_layer.add_child(_fade)

func _apply_settings() -> void:
	UITheme.rebuild()
	for r in [_hud, _dlg_layer.get_child(0), _choice_root]:
		if r:
			r.theme = UITheme.get_theme()
	var sz := Settings.subtitle_size
	_bark.add_theme_font_size_override("font_size", sz)
	_dlg_text.add_theme_font_size_override("normal_font_size", sz)
	_dlg_text.add_theme_color_override("default_color", Color(0.96, 0.94, 0.9))
	_dlg_speaker.add_theme_color_override("font_color", Settings.accent_color())
	_caption.visible = Settings.subtitles

# ---------------------------------------------------------------- frame

func _process(_delta: float) -> void:
	var n: Dictionary = Narrative.current
	var vig: float = n.get("vignette", 0.0)
	var dist: float = n.get("distort", 0.0)
	if Settings.reduce_motion:
		dist *= 0.2
	var warm: float = n.get("warm", 1.0)
	var tint := Vector3(1.0, 1.0, 1.0).lerp(Vector3(0.88, 0.95, 1.08), 1.0 - warm) if warm < 1.0 else Vector3.ONE
	var sat: float = n.get("sat", 1.0)
	var con: float = n.get("contrast", 1.0)
	_fx_mat.set_shader_parameter("vignette", vig)
	_fx_mat.set_shader_parameter("distort", dist)
	_fx_mat.set_shader_parameter("sat", sat)
	_fx_mat.set_shader_parameter("contrast", con)
	_fx_mat.set_shader_parameter("tint", tint)
	_fx_mat.set_shader_parameter("grain", 0.03 if GameState.narrative_state == "FOURTH_WALL" else 0.0)
	_fx_rect.visible = vig > 0.02 or dist > 0.01 or absf(sat - 1.0) > 0.02 or absf(con - 1.0) > 0.02 or warm < 0.99
	if _crosshair:
		_crosshair.queue_redraw()

func _input(event: InputEvent) -> void:
	if _awaiting_advance and not _awaiting_choice:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
				or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
			_complete_or_advance()
			get_viewport().set_input_as_handled()
	if _awaiting_choice and event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < _choice_count:
			_choice_done.emit(k - KEY_1)
			get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE and _choice_cancel >= 0:
			_choice_done.emit(_choice_cancel)
			get_viewport().set_input_as_handled()

func _on_dialogue_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _awaiting_advance:
		_complete_or_advance()

func _complete_or_advance() -> void:
	if _typing_tween and _typing_tween.is_running():
		_typing_tween.kill()
		_dlg_text.visible_ratio = 1.0
		return
	_advance.emit()

# ---------------------------------------------------------------- mouse

func push_blocking() -> void:
	_blocking += 1
	_refresh_mouse()

func pop_blocking() -> void:
	_blocking = maxi(0, _blocking - 1)
	_refresh_mouse()

func reset_blocking() -> void:
	_blocking = 0
	_refresh_mouse()

func is_blocking() -> bool:
	return _blocking > 0

func _refresh_mouse() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if gameplay_active and _blocking == 0:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# ---------------------------------------------------------------- HUD

func show_hud(v: bool) -> void:
	_hud.visible = v

func set_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))

func toast(text: String) -> void:
	if not _hud.visible and not gameplay_active:
		return
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UITheme.label(text, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(260, 0)
	p.add_child(l)
	p.modulate.a = 0.0
	_toasts.add_child(p)
	Audio.play_sfx("notify", -10.0)
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(3.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)

func day_banner(text: String) -> void:
	_day_label.text = text
	var tw := create_tween()
	tw.tween_property(_day_label, "modulate:a", 0.9, 0.6)
	tw.tween_interval(2.6)
	tw.tween_property(_day_label, "modulate:a", 0.0, 1.0)

## Non-blocking one-liner (the character's inner voice). Player keeps control.
func bark(text: String, speaker: String = "") -> void:
	_bark.text = text if speaker == "" else "%s: %s" % [speaker, text]
	if _bark_tween:
		_bark_tween.kill()
	_bark.modulate.a = 0.0
	_bark_tween = create_tween()
	_bark_tween.tween_property(_bark, "modulate:a", 1.0, 0.2)
	_bark_tween.tween_interval(clampf(1.4 + text.length() * 0.045, 2.0, 7.0))
	_bark_tween.tween_property(_bark, "modulate:a", 0.0, 0.6)
	Events.subtitle.emit(text, speaker, 3.0)

## Sound caption (accessibility), e.g. "[phone buzzes]".
func caption(text: String) -> void:
	if not Settings.subtitles:
		return
	_caption.text = text
	var tw := create_tween()
	tw.tween_property(_caption, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.6)
	tw.tween_property(_caption, "modulate:a", 0.0, 0.5)

# ---------------------------------------------------------------- dialogue

func _show_dialogue(speaker: String, text: String) -> void:
	busy_dialogue = true
	push_blocking()
	_dlg_panel.visible = true
	_dlg_speaker.text = speaker
	_dlg_speaker.visible = speaker != ""
	_dlg_text.text = text
	_dlg_text.visible_ratio = 0.0
	for c in _dlg_choices.get_children():
		c.queue_free()
	if _typing_tween:
		_typing_tween.kill()
	_typing_tween = create_tween()
	var dur := clampf(text.length() * 0.022, 0.2, 2.5)
	_typing_tween.tween_property(_dlg_text, "visible_ratio", 1.0, dur)

func _hide_dialogue() -> void:
	_dlg_panel.visible = false
	busy_dialogue = false
	pop_blocking()

## Show one line and wait for the player to continue.
func say(speaker: String, text: String) -> void:
	_show_dialogue(speaker, text)
	_dlg_hint.text = "E / click"
	_awaiting_advance = true
	await _advance
	_awaiting_advance = false
	_hide_dialogue()

## Show a line with options. Returns the picked index.
func say_with_choices(speaker: String, text: String, options: Array) -> int:
	_show_dialogue(speaker, text)
	_dlg_hint.text = ""
	var done := false
	var result := [0]
	for i in options.size():
		var b := UITheme.button("%d.  %s" % [i + 1, options[i]], Settings.subtitle_size - 2)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): _choice_done.emit(i))
		_dlg_choices.add_child(b)
	_awaiting_choice = true
	_choice_count = options.size()
	_choice_cancel = -1
	current_options = options.duplicate()
	var idx: int = await _choice_done
	_awaiting_choice = false
	Audio.play_sfx("click")
	_hide_dialogue()
	return idx

## Centered menu used for the big decisions. options: Array of String or
## {label, desc, disabled}. cancel: index returned on Esc (-1 = none).
func choose(title: String, options: Array, cancel: int = -1, subtitle: String = "") -> int:
	for c in _choice_root.get_children():
		c.queue_free()
	_choice_root.visible = true
	push_blocking()
	busy_dialogue = true
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(520, 0)
	panel.modulate.a = 0.0
	_choice_root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	if title != "":
		var t := UITheme.label(title, 24)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(t)
	if subtitle != "":
		var s := UITheme.label(subtitle, 16, Color(1, 1, 1, 0.55))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(s)
	for i in options.size():
		var o = options[i]
		var label: String = o if o is String else String(o.get("label", ""))
		var b := UITheme.button("%d.  %s" % [i + 1, label], 20)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if o is Dictionary:
			if o.get("disabled", false):
				b.disabled = true
			if o.get("desc", "") != "":
				b.tooltip_text = o["desc"]
		b.pressed.connect(func(): _choice_done.emit(i))
		vb.add_child(b)
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	_awaiting_choice = true
	_awaiting_advance = true
	_choice_count = options.size()
	_choice_cancel = cancel
	current_options = options.map(func(o): return o if o is String else String(o.get("label", "")))
	var idx: int = await _choice_done
	_awaiting_choice = false
	_awaiting_advance = false
	Audio.play_sfx("click")
	_choice_root.visible = false
	for c in _choice_root.get_children():
		c.queue_free()
	busy_dialogue = false
	pop_blocking()
	return idx

# ---------------------------------------------------------------- screens

func open_screen(node: Control) -> void:
	node.theme = UITheme.get_theme()
	_screen_layer.add_child(node)
	push_blocking()

func close_screen(node: Control) -> void:
	if is_instance_valid(node):
		node.queue_free()
	pop_blocking()

# ---------------------------------------------------------------- fades

func fade_to(color: Color, t: float = 1.0) -> void:
	_fade.color = Color(color.r, color.g, color.b, 1.0)
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, maxf(t, 0.001))
	await tw.finished

func fade_clear(t: float = 1.0) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, maxf(t, 0.001))
	await tw.finished

func set_black() -> void:
	_fade.color = Color.BLACK
	_fade.modulate.a = 1.0

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout

# ---------------------------------------------------------------- sequences

## One centered line. style: {size, color, hold, bg}
func text_card(text: String, hold: float = 2.4, size: int = 34, color: Color = Color(0.96, 0.94, 0.9), typed: bool = true) -> void:
	text = Dialogue.fill(text)
	_seq_label.text = text
	_seq_label.add_theme_font_size_override("font_size", size)
	_seq_label.add_theme_color_override("font_color", color)
	_seq_label.modulate.a = 1.0
	_seq_label.visible_ratio = 0.0 if typed else 1.0
	if typed:
		var tw := create_tween()
		tw.tween_property(_seq_label, "visible_ratio", 1.0, clampf(text.length() * 0.035, 0.4, 2.2))
		await tw.finished
	await wait(hold)
	var out := create_tween()
	out.tween_property(_seq_label, "modulate:a", 0.0, 0.6)
	await out.finished
	_seq_label.text = ""

func seq_bg(alpha: float, t: float = 0.8) -> void:
	var tw := create_tween()
	tw.tween_property(_seq_bg, "modulate:a", alpha, maxf(t, 0.001))
	await tw.finished

## Run a scripted sequence from data/sequences.json.
func run_sequence(id: String) -> void:
	var seqs: Dictionary = Util.load_json("res://data/sequences.json")
	if not seqs.has(id):
		push_warning("Unknown sequence " + id)
		return
	var seq: Dictionary = seqs[id]
	push_blocking()
	if seq.get("bg", "none") == "black":
		await seq_bg(1.0, float(seq.get("bg_fade", 0.8)))
	await _run_steps(seq.get("steps", []))
	if seq.get("bg", "none") == "black" and not seq.get("keep_bg", false):
		await seq_bg(0.0, 0.8)
	pop_blocking()

func _run_steps(steps: Array) -> void:
	for s in steps:
		if OS.get_environment("DEBUG_SEQ") != "":
			print("[seq] ", s)
		if s.has("if") and not Dialogue.check(s["if"]):
			continue
		match String(s.get("t", "")):
			"text":
				var col := Color(0.96, 0.94, 0.9)
				if s.get("color", "") == "warn":
					col = Settings.warn_color()
				elif s.get("color", "") == "accent":
					col = Settings.accent_color()
				await text_card(String(s.get("text", "")), float(s.get("hold", 2.0)), int(s.get("size", 34)), col, s.get("typed", true))
			"pool":
				var l := Dialogue.pick_from_pool(String(s["file"]), String(s["pool"]))
				if not l.is_empty():
					await text_card(l["text"], float(s.get("hold", 2.0)), int(s.get("size", 30)))
			"pause":
				await wait(float(s.get("s", 1.0)))
			"state":
				Narrative.set_state(String(s["state"]), float(s.get("blend", 2.0)))
			"settle":
				Narrative.settle()
			"silence":
				Audio.silence(float(s.get("fade", 0.5)))
			"restore":
				Audio.restore()
			"music":
				Audio.set_music(String(s["kind"]), float(s.get("fade", 2.0)))
			"sfx":
				Audio.play_sfx(String(s["name"]), float(s.get("db", 0.0)))
				if s.has("caption"):
					caption(String(s["caption"]))
			"flag":
				GameState.set_flag(String(s["name"]))
			"effects":
				Psychology.apply(s["effects"])
			"bg":
				await seq_bg(float(s.get("a", 1.0)), float(s.get("fade", 0.8)))
			"fade":
				if s.get("to", "black") == "clear":
					await fade_clear(float(s.get("time", 1.0)))
				else:
					await fade_to(Color.WHITE if s.get("to") == "white" else Color.BLACK, float(s.get("time", 1.0)))
			"call":
				var h = hooks.get(String(s["name"]))
				if h is Callable:
					await h.call(s.get("args", {}))
				else:
					push_warning("Sequence hook missing: " + String(s["name"]))
			"fourth_wall":
				Events.fourth_wall.emit(String(s["id"]))
			"steps":
				await _run_steps(s["steps"])
