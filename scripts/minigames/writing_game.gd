class_name WritingGame
extends Control
## The actual work. For each essay section: choose the strongest approach, then type
## a short line while distractions try to pull you away. Opening a distraction ends the
## session. Emits finished({sections, quality, quit, reason}).

signal finished(result: Dictionary)

var data: Dictionary
var _doc: RichTextLabel
var _title: Label
var _hint: Label
var _cards_box: VBoxContainer
var _type_label: RichTextLabel
var _status: Label
var _notif: PanelContainer
var _notif_label: Label
var _next_box: HBoxContainer
var _stage := "pick"
var _section := 0
var _target := ""
var _typed := 0
var _chosen_q := 0
var _done_sections := 0
var _quality_sum := 0.0
var _notif_timer := 5.0
var _notif_life := 0.0
var _quit := false
var _reason := ""
var _paragraphs: Array = []
var _finished := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	data = Util.load_json("res://data/essay.json")
	_section = GameState.essay_sections_done
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.06, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 60
	root.offset_right = -60
	root.offset_top = 50
	root.offset_bottom = -50
	root.add_theme_constant_override("separation", 30)
	add_child(root)
	# document page
	var page := PanelContainer.new()
	page.custom_minimum_size = Vector2(430, 0)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sbp := UITheme.box(Color("f4f0e6"), 6)
	sbp.content_margin_left = 28
	sbp.content_margin_right = 28
	sbp.content_margin_top = 24
	page.add_theme_stylebox_override("panel", sbp)
	root.add_child(page)
	var pv := VBoxContainer.new()
	page.add_child(pv)
	var ph := UITheme.label("Assignment 4", 22, Color("23252b"))
	pv.add_child(ph)
	_doc = RichTextLabel.new()
	_doc.bbcode_enabled = true
	_doc.fit_content = false
	_doc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_doc.add_theme_color_override("default_color", Color("2b2d33"))
	_doc.add_theme_font_size_override("normal_font_size", 17)
	pv.add_child(_doc)
	# work panel
	var work := VBoxContainer.new()
	work.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	work.add_theme_constant_override("separation", 14)
	root.add_child(work)
	_title = UITheme.label("", 30)
	work.add_child(_title)
	_hint = UITheme.label("", 18, Color(1, 1, 1, 0.65))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	work.add_child(_hint)
	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 10)
	work.add_child(_cards_box)
	_type_label = RichTextLabel.new()
	_type_label.bbcode_enabled = true
	_type_label.fit_content = true
	_type_label.add_theme_font_size_override("normal_font_size", 28)
	_type_label.visible = false
	work.add_child(_type_label)
	_status = UITheme.label("", 18, Settings.accent_color())
	work.add_child(_status)
	_next_box = HBoxContainer.new()
	_next_box.add_theme_constant_override("separation", 12)
	work.add_child(_next_box)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	work.add_child(spacer)
	var stop := UITheme.button("Take a break")
	stop.pressed.connect(func(): _end(false, "break"))
	work.add_child(stop)
	# notification toast
	_notif = PanelContainer.new()
	_notif.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_notif.position = Vector2(-380, -150)
	_notif.custom_minimum_size = Vector2(330, 0)
	_notif.visible = false
	var nv := VBoxContainer.new()
	_notif.add_child(nv)
	_notif_label = UITheme.label("", 18)
	_notif_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nv.add_child(_notif_label)
	var ob := UITheme.button("Open", 16)
	ob.pressed.connect(_open_distraction)
	nv.add_child(ob)
	add_child(_notif)
	_refresh_doc()
	_show_pick()

func _sections() -> Array:
	return data.get("sections", [])

func _refresh_doc() -> void:
	var t := "[b]%s[/b]\n\n" % Dialogue.fill("{subject}").capitalize()
	for p in _paragraphs:
		t += p + "\n\n"
	if _paragraphs.is_empty():
		t += "[color=#999999]Blank page. A cursor. That's all it is.[/color]"
	_doc.text = t

func _show_pick() -> void:
	_stage = "pick"
	_type_label.visible = false
	for c in _next_box.get_children():
		c.queue_free()
	for c in _cards_box.get_children():
		c.queue_free()
	var secs := _sections()
	if _section >= secs.size():
		_end(false, "complete")
		return
	var s: Dictionary = secs[_section]
	_title.text = "%d / %d   %s" % [_section + 1, secs.size(), s["title"]]
	_hint.text = s["hint"] + "\nChoose how to write it."
	_status.text = ""
	for card in s["cards"]:
		var b := UITheme.button(Dialogue.fill(String(card["text"]).replace("{subject}", GameState.subject)), 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 56)
		b.pressed.connect(func(): _pick(card))
		_cards_box.add_child(b)

func _pick(card: Dictionary) -> void:
	Audio.play_sfx("click")
	_chosen_q = int(card["q"])
	_target = String(card["type"])
	_typed = 0
	_stage = "type"
	for c in _cards_box.get_children():
		c.queue_free()
	_hint.text = "Type it out. Notifications will try to pull you away. You don't have to open them."
	_type_label.visible = true
	_notif_timer = 3.5
	Narrative.set_state("CONFRONTATION", 2.0)
	_update_type()
	_status.text = ""

func _update_type() -> void:
	var done := _target.substr(0, _typed)
	var rest := _target.substr(_typed)
	_type_label.text = "[color=#ffb454]%s[/color][color=#777777]%s[/color]" % [done, rest]

func _input(e: InputEvent) -> void:
	if _stage != "type" or _finished:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.unicode > 0:
		var ch := String.chr(e.unicode)
		if _typed < _target.length() and ch.to_lower() == _target[_typed].to_lower():
			_typed += 1
			Audio.play_sfx("key", -6.0, randf_range(0.9, 1.15))
			_update_type()
			get_viewport().set_input_as_handled()
			if _typed >= _target.length():
				_section_done()
		else:
			Audio.play_sfx("key", -16.0, 0.6)

func _section_done() -> void:
	_stage = "between"
	_done_sections += 1
	_quality_sum += _chosen_q
	GameState.essay_sections_done += 1
	Events.essay_progress.emit(GameState.essay_sections_done)
	_notif.visible = false
	var sec: Dictionary = _sections()[_section]
	var full: String = String(sec["cards"].filter(func(c): return c["type"] == _target)[0]["text"]).replace("{subject}", GameState.subject)
	_paragraphs.append(full)
	_refresh_doc()
	_section += 1
	Audio.play_sfx("win", -6.0)
	_type_label.visible = false
	var lines := ["Sentence one is the hardest.", "Okay. That's actually decent.", "You're in it now."]
	_status.text = lines[mini(_done_sections - 1, 2)] if _chosen_q > 0 else "It's on the page. That counts."
	if _section >= _sections().size():
		await get_tree().create_timer(1.2).timeout
		_end(false, "complete")
		return
	var more := UITheme.button("Keep going")
	more.pressed.connect(func():
		Audio.play_sfx("click")
		_show_pick())
	_next_box.add_child(more)

func _process(delta: float) -> void:
	if _stage != "type" or _finished:
		return
	_notif_timer -= delta
	if _notif.visible:
		_notif_life -= delta
		if _notif_life <= 0.0:
			_notif.visible = false
	elif _notif_timer <= 0.0:
		var lst: Array = data.get("distractions", ["New message"])
		_notif_label.text = lst[randi() % lst.size()]
		_notif.visible = true
		_notif_life = 4.5
		Audio.play_sfx("notify", -8.0)
		_notif_timer = lerpf(9.0, 4.0, GameState.get_psy("avoidance") / 100.0) + randf_range(0.0, 2.0)

func _open_distraction() -> void:
	_status.text = "Just a quick look..."
	_end(true, "distracted")

func _end(quit_early: bool, reason: String) -> void:
	if _finished:
		return
	_finished = true
	_quit = quit_early
	_reason = reason
	finished.emit({"sections": _done_sections, "quality": _quality_sum / maxf(float(_done_sections), 1.0),
			"quit": quit_early, "reason": reason})
