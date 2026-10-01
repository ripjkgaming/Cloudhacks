class_name UITheme
extends RefCounted
## Builds the shared Theme in code so there are no external UI assets.

static var _theme: Theme

static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme

static func rebuild() -> void:
	_theme = _build()

static func box(bg: Color, radius: int = 8, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func _build() -> Theme:
	var t := Theme.new()
	var accent := Settings.accent_color()
	t.default_font_size = 20
	t.set_stylebox("normal", "Button", box(Color(1, 1, 1, 0.07), 8, Color(1, 1, 1, 0.12), 1))
	t.set_stylebox("hover", "Button", box(Color(accent.r, accent.g, accent.b, 0.22), 8, accent, 1))
	t.set_stylebox("pressed", "Button", box(Color(accent.r, accent.g, accent.b, 0.4), 8, accent, 1))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 8, accent, 1))
	t.set_stylebox("disabled", "Button", box(Color(1, 1, 1, 0.03), 8))
	t.set_color("font_color", "Button", Color(0.94, 0.92, 0.88))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	t.set_stylebox("panel", "PanelContainer", box(Color(0.07, 0.07, 0.09, 0.88), 12, Color(1, 1, 1, 0.08), 1))
	t.set_stylebox("panel", "Panel", box(Color(0.07, 0.07, 0.09, 0.88), 12, Color(1, 1, 1, 0.08), 1))
	t.set_color("font_color", "Label", Color(0.94, 0.92, 0.88))
	t.set_color("font_color", "CheckBox", Color(0.94, 0.92, 0.88))
	t.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.12), 4))
	t.set_stylebox("grabber_area", "HSlider", box(accent, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(accent, 4))
	return t

static func label(text: String, size: int = 20, color: Color = Color(0.94, 0.92, 0.88)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func button(text: String, size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	return b

## Center a control with an explicit size, independent of parent size (works before add_child).
static func center(c: Control, size: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = -size.x / 2.0 + offset.x
	c.offset_right = size.x / 2.0 + offset.x
	c.offset_top = -size.y / 2.0 + offset.y
	c.offset_bottom = size.y / 2.0 + offset.y
