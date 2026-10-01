class_name ComputerUI
extends Control
## Fake operating system on the bedroom PC. Desktop icons open small windows.
## Emits `activity_chosen(id)` when the player commits to something (the room scene
## then plays it out) and `closed` when they stand up.

signal activity_chosen(id: String)
signal closed

const SCREEN := Vector2(1120, 650)

var _desk: Control
var _window: PanelContainer
var _win_body: VBoxContainer
var _clock: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_t := 12.0
var _open_at := 0
var _assignment_open := false
var _scrolls := 0
var _browser_tab := "Feed"
var _feed: VBoxContainer
var _busy := false
var _you_shake := 0.0
var _you_btn: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.02, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var bezel := Panel.new()
	bezel.set_anchors_preset(Control.PRESET_CENTER)
	bezel.size = SCREEN + Vector2(28, 28)
	bezel.position = -bezel.size / 2.0
	bezel.add_theme_stylebox_override("panel", UITheme.box(Color("15161b"), 18, Color("2b2d35"), 3))
	add_child(bezel)
	_desk = Panel.new()
	_desk.size = SCREEN
	_desk.position = Vector2(14, 14)
	var wp := _wallpaper_style()
	_desk.add_theme_stylebox_override("panel", wp)
	_desk.clip_contents = true
	bezel.add_child(_desk)
	_build_icons()
	_build_taskbar()
	_toast = PanelContainer.new()
	_toast.position = Vector2(SCREEN.x - 360, SCREEN.y - 130)
	_toast.custom_minimum_size = Vector2(330, 0)
	_toast.visible = false
	_toast_label = UITheme.label("", 17)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_child(_toast_label)
	_desk.add_child(_toast)
	Audio.play_sfx("click")
	Audio.play_sfx("creak", -10.0)

func _wallpaper_style() -> StyleBox:
	var warm := GameState.get_psy("pressure") < 50
	var g := Gradient.new()
	g.set_color(0, Color("27324a") if warm else Color("1a2030"))
	g.set_color(1, Color("5c4a6b") if warm else Color("2a2c3a"))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 1)
	var sb := StyleBoxTexture.new()
	sb.texture = gt
	return sb

# ------------------------------------------------------------- desktop

const ICONS := [
	["Assignment", "doc", Color("e8a05a")], ["Messages", "chat", Color("5fb88b")],
	["Browser", "globe", Color("5a8fd8")], ["Games", "pad", Color("a86fd8")],
	["Calendar", "cal", Color("e86f6f")], ["Music", "note", Color("e8c35a")],
	["Notes", "pad2", Color("d8d86a")], ["YOU", "eye", Color("d8d8d8")],
]

func _build_icons() -> void:
	var col := 0
	var row := 0
	for ic in ICONS:
		if ic[0] == "YOU" and GameState.day < 4:
			continue
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(96, 100)
		holder.position = Vector2(30 + col * 110, 28 + row * 116)
		holder.size = Vector2(96, 100)
		var kind: String = ic[1]
		var color: Color = ic[2]
		holder.draw.connect(func(): _draw_icon(holder, kind, color))
		holder.mouse_filter = Control.MOUSE_FILTER_STOP
		holder.gui_input.connect(func(e): _icon_input(e, ic[0]))
		var lab := UITheme.label(ic[0], 16)
		lab.position = Vector2(0, 74)
		lab.size = Vector2(96, 22)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		lab.add_theme_constant_override("outline_size", 4)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(lab)
		_desk.add_child(holder)
		if ic[0] == "YOU":
			_you_btn = holder
		row += 1
		if row >= 5:
			row = 0
			col += 1

func _draw_icon(c: Control, kind: String, color: Color) -> void:
	c.draw_style_box(UITheme.box(color, 14), Rect2(14, 4, 68, 64))
	var w := Color(1, 1, 1, 0.9)
	var o := Vector2(14, 4)
	match kind:
		"doc":
			c.draw_rect(Rect2(o + Vector2(20, 12), Vector2(28, 40)), w)
			for i in 4:
				c.draw_line(o + Vector2(25, 22 + i * 7), o + Vector2(43, 22 + i * 7), color.darkened(0.3), 2.0)
		"chat":
			c.draw_rect(Rect2(o + Vector2(12, 14), Vector2(44, 28)), w)
			c.draw_colored_polygon(PackedVector2Array([o + Vector2(20, 42), o + Vector2(32, 42), o + Vector2(20, 54)]), w)
		"globe":
			c.draw_arc(o + Vector2(34, 32), 22, 0, TAU, 24, w, 3.0)
			c.draw_arc(o + Vector2(34, 32), 10, 0, TAU, 24, w, 2.0)
			c.draw_line(o + Vector2(12, 32), o + Vector2(56, 32), w, 2.0)
		"pad":
			c.draw_rect(Rect2(o + Vector2(10, 22), Vector2(48, 24)), w)
			c.draw_circle(o + Vector2(24, 34), 5, color.darkened(0.4))
			c.draw_circle(o + Vector2(44, 34), 4, color.darkened(0.4))
		"cal":
			c.draw_rect(Rect2(o + Vector2(12, 14), Vector2(44, 38)), w)
			c.draw_rect(Rect2(o + Vector2(12, 14), Vector2(44, 10)), color.darkened(0.3))
		"note":
			c.draw_circle(o + Vector2(26, 44), 8, w)
			c.draw_line(o + Vector2(33, 44), o + Vector2(33, 16), w, 3.0)
			c.draw_line(o + Vector2(33, 16), o + Vector2(48, 22), w, 3.0)
		"pad2":
			c.draw_rect(Rect2(o + Vector2(14, 12), Vector2(40, 42)), w)
			c.draw_line(o + Vector2(20, 26), o + Vector2(48, 26), color.darkened(0.3), 2.0)
			c.draw_line(o + Vector2(20, 36), o + Vector2(42, 36), color.darkened(0.3), 2.0)
		"eye":
			c.draw_arc(o + Vector2(34, 32), 22, PI * 1.1, PI * 1.9, 16, Color.BLACK, 3.0)
			c.draw_arc(o + Vector2(34, 32), 22, PI * 0.1, PI * 0.9, 16, Color.BLACK, 3.0)
			c.draw_circle(o + Vector2(34, 32), 7, Color.BLACK)

func _icon_input(e: InputEvent, name: String) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or _busy:
		return
	Audio.play_sfx("click")
	match name:
		"Assignment": _open_assignment()
		"Messages": _open_messages()
		"Browser": _open_browser()
		"Games": _open_games()
		"Calendar": _open_calendar()
		"Music": _open_music()
		"Notes": _open_notes()
		"YOU": _open_you()

func _build_taskbar() -> void:
	var bar := Panel.new()
	bar.position = Vector2(0, SCREEN.y - 38)
	bar.size = Vector2(SCREEN.x, 38)
	bar.add_theme_stylebox_override("panel", UITheme.box(Color(0.05, 0.06, 0.09, 0.9), 0))
	_desk.add_child(bar)
	var start := UITheme.label("  Day %d" % GameState.day, 17, Settings.accent_color())
	start.position = Vector2(8, 6)
	bar.add_child(start)
	_clock = UITheme.label("", 17)
	_clock.position = Vector2(SCREEN.x - 90, 6)
	bar.add_child(_clock)
	var stand := UITheme.button("Stand up", 16)
	stand.position = Vector2(SCREEN.x - 220, 4)
	stand.size = Vector2(110, 30)
	stand.pressed.connect(close)
	bar.add_child(stand)
	_update_clock()

func _update_clock() -> void:
	if GameState.day >= 3 and not GameState.cycle_broken:
		_clock.text = "11:47"          # the clock stops moving
	else:
		var mins := 8 * 60 + 30 + GameState.block * 240 + int(GameState.run_seconds / 6.0) % 120
		_clock.text = "%02d:%02d" % [(mins / 60) % 24, mins % 60]

func close() -> void:
	if _assignment_open:
		_finish_assignment_timing(false)
	Audio.play_sfx("creak", -12.0)
	closed.emit()

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE and not e.echo and not _busy:
		get_viewport().set_input_as_handled()
		if _window:
			_close_window()
		else:
			close()

func _process(delta: float) -> void:
	_toast_t -= delta
	if _toast_t <= 0.0 and not _busy:
		_toast_t = randf_range(18.0, 34.0)
		var l := Dialogue.pick_from_pool("computer", "notification")
		if not l.is_empty():
			_show_toast(l["text"])
	if _you_btn and _you_shake > 0.0:
		_you_shake -= delta
		_you_btn.rotation = sin(_you_shake * 40.0) * 0.08
		if _you_shake <= 0.0:
			_you_btn.rotation = 0.0
	if _clock and Engine.get_process_frames() % 30 == 0:
		_update_clock()

func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.visible = true
	Audio.play_sfx("notify", -10.0)
	Events.subtitle.emit("[notification] " + text, "", 2.0)
	UI.caption("[notification sound]")
	var tw := create_tween()
	tw.tween_interval(4.5)
	tw.tween_callback(func(): _toast.visible = false)

# ------------------------------------------------------------- windows

func _win(title: String, w: float = 700, h: float = 470) -> VBoxContainer:
	_close_window()
	_window = PanelContainer.new()
	_window.size = Vector2(w, h)
	_window.position = Vector2((SCREEN.x - w) / 2.0 + 40, 36 + randf() * 14.0)
	_window.custom_minimum_size = Vector2(w, h)
	_desk.add_child(_window)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_window.add_child(vb)
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	var t := UITheme.label(title, 20, Settings.accent_color())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(t)
	var x := UITheme.button("X", 16)
	x.pressed.connect(_close_window)
	hb.add_child(x)
	_win_body = VBoxContainer.new()
	_win_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_win_body.add_theme_constant_override("separation", 10)
	vb.add_child(_win_body)
	_window.modulate.a = 0.0
	create_tween().tween_property(_window, "modulate:a", 1.0, 0.15)
	return _win_body

func _close_window() -> void:
	if _assignment_open:
		_finish_assignment_timing(false)
	if _window and is_instance_valid(_window):
		_window.queue_free()
	_window = null

func _text(parent: Control, text: String, size: int = 18, color: Color = Color(0.94, 0.92, 0.88)) -> Label:
	var l := UITheme.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

# ------------------------------------------------------------- assignment

func _open_assignment() -> void:
	if _assignment_open:
		return
	_busy = true
	GameState.inc("computer_opens")
	GameState.inc("assignment_views")
	Events.assignment_viewed.emit()
	await Days.on_assignment_opened()
	_busy = false
	var b := _win("Assignment 4", 760, 520)
	_open_at = Time.get_ticks_msec()
	_assignment_open = true
	var urgent := GameState.deadline_key() in ["tonight", "overdue"]
	_text(b, GameState.deadline_text(), 24, Settings.warn_color() if urgent else Settings.accent_color())
	var prompt: String = Util.load_json("res://data/assignments.json").get("prompt", "").replace("{subject}", GameState.subject)
	_text(b, prompt, 18)
	var done := GameState.essay_sections_done
	if done > 0:
		_text(b, "Draft: %d of %d sections written." % [done, GameState.ESSAY_SECTIONS], 16, Settings.good_color())
	var cb := Dialogue.pool_text("computer", "assignment_callback")
	if cb != "":
		_text(b, cb, 17, Color(1, 1, 1, 0.6))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	b.add_child(sp)
	_decision_menu(b, Days.computer_menu_id())

func _decision_menu(b: VBoxContainer, menu_id: String) -> void:
	for c in b.get_children():
		if c.has_meta("decision"):
			c.queue_free()
	var box := VBoxContainer.new()
	box.set_meta("decision", true)
	box.add_theme_constant_override("separation", 6)
	b.add_child(box)
	_text(box, "What do you do?", 16, Color(1, 1, 1, 0.5))
	var ids: Array = Psychology.menu(menu_id)
	if menu_id.begins_with("computer") and GameState.essay_done:
		ids = ["leave"]
	for id in ids:
		if id == "distract":
			var db := UITheme.button(Days.label_for("distract"), 19)
			db.alignment = HORIZONTAL_ALIGNMENT_LEFT
			db.pressed.connect(func(): _decision_menu(b, "distract"))
			box.add_child(db)
			continue
		var a := Psychology.activity(id)
		var btn := UITheme.button(Days.label_for(id), 19)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func(): _decide(id))
		box.add_child(btn)

func _finish_assignment_timing(chose_avoidance: bool) -> void:
	if not _assignment_open:
		return
	_assignment_open = false
	var secs := (Time.get_ticks_msec() - _open_at) / 1000.0
	GameState.stats["last_assignment_seconds"] = int(round(secs))
	if chose_avoidance and secs < 6.0:
		GameState.inc("fast_avoid")

func _decide(id: String) -> void:
	var a := Psychology.activity(id)
	_finish_assignment_timing(a.get("avoidance", false))
	activity_chosen.emit(id)

# ------------------------------------------------------------- messages

func _open_messages() -> void:
	GameState.inc("messages_read")
	var b := _win("Messages", 640, 440)
	var seen := {}
	var picks: Array = []
	for i in 12:
		var l := Dialogue.pick_from_pool("computer", "messages")
		if not l.is_empty() and not seen.has(l["text"]):
			seen[l["text"]] = true
			picks.append(l["text"])
		if picks.size() >= 3:
			break
	for m in picks:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UITheme.box(Color(1, 1, 1, 0.07), 10))
		var l := UITheme.label(m, 18)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(l)
		b.add_child(p)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_child(sp)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	b.add_child(row)
	var go := UITheme.button("On my way", 18)
	go.pressed.connect(func(): activity_chosen.emit("friends"))
	row.add_child(go)
	var later := UITheme.button("Later.", 18)
	later.pressed.connect(func():
		Psychology.commit_choice("later")
		_text_flash("Message sent: later."))
	row.add_child(later)

func _text_flash(t: String) -> void:
	_show_toast(t)

# ------------------------------------------------------------- browser

func _open_browser() -> void:
	_scrolls = 0
	var b := _win("Browser", 800, 520)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	b.add_child(tabs)
	var web: Dictionary = Util.load_json("res://data/websites.json").get("tabs", {})
	for t in web:
		var tb := UITheme.button(t, 16)
		tb.pressed.connect(func():
			_browser_tab = t
			_scrolls = 0
			_load_items())
		tabs.add_child(tb)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	b.add_child(sc)
	_feed = VBoxContainer.new()
	_feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feed.add_theme_constant_override("separation", 8)
	sc.add_child(_feed)
	var more := UITheme.button("Keep scrolling", 18)
	more.pressed.connect(_scroll_more)
	b.add_child(more)
	_load_items()

func _pick_items(n: int) -> Array:
	var web: Dictionary = Util.load_json("res://data/websites.json").get("tabs", {})
	var items: Array = web.get(_browser_tab, []).filter(func(i): return Dialogue.check(i.get("conditions", [])))
	items.sort_custom(func(a, c): return int(a.get("priority", 0)) > int(c.get("priority", 0)))
	var out := []
	var normal := items.filter(func(i): return int(i.get("priority", 0)) == 0)
	normal.shuffle()
	var special := items.filter(func(i): return int(i.get("priority", 0)) > 0)
	if not special.is_empty():
		out.append(special[0])
	for i in normal:
		if out.size() >= n:
			break
		out.append(i)
	return out

func _load_items() -> void:
	for c in _feed.get_children():
		c.queue_free()
	for it in _pick_items(3):
		_add_item(it)

func _add_item(it: Dictionary) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(Color(1, 1, 1, 0.06), 10))
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UITheme.label(it["title"], 17, Settings.accent_color()))
	var l := UITheme.label(Dialogue.fill(it["text"]), 18)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	_feed.add_child(p)

func _scroll_more() -> void:
	_scrolls += 1
	Audio.play_sfx("swoosh", -14.0)
	Psychology.apply({"relief": 2, "avoidance": 2})
	for it in _pick_items(2):
		_add_item(it)
	if _scrolls >= 3:
		_scrolls = 0
		var id := "videos" if _browser_tab == "Videos" else "browse"
		activity_chosen.emit(id)

# ------------------------------------------------------------- games

func _open_games() -> void:
	var b := _win("Games", 560, 320)
	_text(b, "Installed", 16, Color(1, 1, 1, 0.5))
	var pk := UITheme.button("Poker Night (heads-up)", 20)
	pk.alignment = HORIZONTAL_ALIGNMENT_LEFT
	pk.pressed.connect(func(): activity_chosen.emit("poker"))
	b.add_child(pk)
	var cs := UITheme.button("Console (in the corner)", 20)
	cs.alignment = HORIZONTAL_ALIGNMENT_LEFT
	cs.pressed.connect(func(): activity_chosen.emit("console"))
	b.add_child(cs)

# ------------------------------------------------------------- calendar

func _open_calendar() -> void:
	var b := _win("Calendar", 640, 360)
	_text(b, "This week", 18, Color(1, 1, 1, 0.55))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	b.add_child(grid)
	for d in range(1, 8):
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(76, 76)
		var col := Color(1, 1, 1, 0.06)
		if d == GameState.day:
			col = Color(Settings.accent_color(), 0.3)
		if d == 3 and not GameState.essay_done:
			col = Color(Settings.warn_color(), 0.35)
		p.add_theme_stylebox_override("panel", UITheme.box(col, 8))
		var v := VBoxContainer.new()
		p.add_child(v)
		v.add_child(UITheme.label("Day %d" % d, 16))
		if d == 3:
			v.add_child(UITheme.label("DUE", 16, Settings.warn_color()))
		elif d < GameState.day:
			v.add_child(UITheme.label("...", 16, Color(1, 1, 1, 0.4)))
		grid.add_child(p)
	if GameState.day > 3 and not GameState.essay_done:
		_text(b, "The deadline is behind you. The date still has a red box.", 17, Settings.warn_color())

# ------------------------------------------------------------- music

func _open_music() -> void:
	var b := _win("Music", 520, 300)
	_text(b, "Now playing: lo-fi beats to avoid things to", 18)
	for opt in [["Warm piano", "lofi1"], ["Same melody, extra layer", "lofi2"], ["Silence", "none"]]:
		var btn := UITheme.button(opt[0], 18)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func(): Audio.set_music(opt[1], 1.0))
		b.add_child(btn)

# ------------------------------------------------------------- notes

func _open_notes() -> void:
	var b := _win("Notes", 600, 420)
	_text(b, "to do:", 20, Settings.accent_color())
	var lines := ["- reply to everyone", "- laundry", "- gym?", "- start essay (!!)"]
	if GameState.essay_sections_done > 0:
		lines[3] = "- start essay (started!)"
	if GameState.get_psy("pressure") > 60:
		lines.append("- ESSAY.")
	for l in lines:
		_text(b, l, 18)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_child(sp)
	var o := UITheme.button("Organize the desktop files", 18)
	o.alignment = HORIZONTAL_ALIGNMENT_LEFT
	o.pressed.connect(func(): activity_chosen.emit("organize"))
	b.add_child(o)
	var r := UITheme.button("Research a bit (just for context)", 18)
	r.alignment = HORIZONTAL_ALIGNMENT_LEFT
	r.pressed.connect(func(): activity_chosen.emit("research"))
	b.add_child(r)

# ------------------------------------------------------------- YOU

func _open_you() -> void:
	GameState.inc("you_clicks")
	if GameState.stats["you_clicks"] < 2 and GameState.day < 5:
		_you_shake = 0.6
		Audio.play_sfx("buzz", -10.0)
		return
	var b := _win("PLAY SESSION SUMMARY", 560, 440)
	var s: Dictionary = GameState.stats
	var rows := [
		["Avoidance events", s["avoidance_count"]],
		["Work sessions", s["work_sessions"]],
		["Poker games", s["poker_count"]],
		["Times you said \"later\"", s["later_count"]],
		["Times you opened the assignment", s["assignment_views"]],
		["Objects inspected", s["inspected"].size()],
	]
	for r in rows:
		var hb := HBoxContainer.new()
		var k := UITheme.label(String(r[0]), 19)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(k)
		hb.add_child(UITheme.label(str(int(r[1])), 19, Settings.accent_color()))
		b.add_child(hb)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	b.add_child(sp)
	var interesting := UITheme.label("", 26, Settings.warn_color())
	b.add_child(interesting)
	if not GameState.has_flag("you_summary_seen"):
		GameState.set_flag("you_summary_seen")
		Psychology.apply({"self_awareness": 8})
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(func():
		interesting.text = "Interesting."
		Audio.play_sfx("heart", -10.0))
