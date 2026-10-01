class_name Menus
extends RefCounted
## Builders for the main menu, pause menu and credits. Each returns a Control that
## emits through a `choice` callback.

static func main_menu(on_choice: Callable) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("111319")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var glow := ColorRect.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.color = Color(1, 0.7, 0.4, 0.05)
	root.add_child(glow)
	var vb := VBoxContainer.new()
	UITheme.center(vb, Vector2(340, 420))
	vb.add_theme_constant_override("separation", 14)
	root.add_child(vb)
	var t := UITheme.label("ANXIETY TRAP", 52, Color("f2e6d0"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var sub := UITheme.label("a choice-driven experience", 18, Color(1, 1, 1, 0.5))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 24)
	vb.add_child(sp)
	var items := []
	if Saves.has_save():
		items.append(["Continue", "continue"])
	items.append_array([["New Game", "new"], ["Settings", "settings"], ["Quit", "quit"]])
	for it in items:
		var b := UITheme.button(it[0], 24)
		b.custom_minimum_size = Vector2(0, 52)
		b.pressed.connect(func():
			Audio.play_sfx("click")
			on_choice.call(it[1]))
		vb.add_child(b)
	var endings: int = Saves.meta.get("endings", {}).size()
	if endings > 0:
		var e := UITheme.label("Endings found: %d / 5" % endings, 15, Color(1, 1, 1, 0.4))
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(e)
	return root

static func pause_menu(on_choice: Callable) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var vb := VBoxContainer.new()
	UITheme.center(vb, Vector2(300, 340))
	vb.add_theme_constant_override("separation", 12)
	root.add_child(vb)
	var t := UITheme.label("Paused", 36)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	for it in [["Resume", "resume"], ["Save", "save"], ["Settings", "settings"], ["Main menu", "menu"], ["Quit", "quit"]]:
		var b := UITheme.button(it[0], 22)
		b.custom_minimum_size = Vector2(0, 46)
		b.pressed.connect(func(): on_choice.call(it[1]))
		vb.add_child(b)
	return root
