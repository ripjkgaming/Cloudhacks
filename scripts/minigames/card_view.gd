class_name CardView
extends Control
## A playing card drawn with vector shapes (no font glyphs, no art assets).

var card := -1
var face_up := false
var _flip_tween: Tween

func _init() -> void:
	custom_minimum_size = Vector2(84, 118)
	size = Vector2(84, 118)
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_PASS

func set_card(c: int, up: bool = false) -> void:
	card = c
	face_up = up
	queue_redraw()

func flip_to(up: bool) -> void:
	if up == face_up:
		return
	if _flip_tween:
		_flip_tween.kill()
	_flip_tween = create_tween()
	_flip_tween.tween_property(self, "scale:x", 0.0, 0.12)
	_flip_tween.tween_callback(func():
		face_up = up
		queue_redraw())
	_flip_tween.tween_property(self, "scale:x", 1.0, 0.12)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if card < 0:
		draw_style_box(UITheme.box(Color(1, 1, 1, 0.05), 8, Color(1, 1, 1, 0.15), 1), r)
		return
	if not face_up:
		draw_style_box(UITheme.box(Color("2d4f8a"), 8, Color("e8e2d4"), 3), r)
		for i in 5:
			for j in 7:
				if (i + j) % 2 == 0:
					draw_rect(Rect2(10 + i * 13.0, 12 + j * 13.0, 11, 11), Color("3b66ad"))
		return
	draw_style_box(UITheme.box(Color("f6f2e8"), 8, Color(0, 0, 0, 0.35), 1), r)
	var suit := PokerEngine.card_suit(card)
	var rank_s: String = PokerEngine.RANKS[PokerEngine.card_rank(card)]
	var red := suit == 1 or suit == 2
	var col := Settings.warn_color().darkened(0.1) if red else Color("1d1d22")
	if Settings.colorblind and red:
		col = Color("0072b2")
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(8, 24), rank_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
	_suit(Vector2(14, 40), 8.0, suit, col)
	_suit(size / 2.0 + Vector2(0, 4), 22.0, suit, col)

func _suit(c: Vector2, s: float, suit: int, col: Color) -> void:
	match suit:
		1:  # heart
			draw_circle(c + Vector2(-s * 0.5, -s * 0.25), s * 0.55, col)
			draw_circle(c + Vector2(s * 0.5, -s * 0.25), s * 0.55, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.03, -s * 0.05), c + Vector2(s * 1.03, -s * 0.05), c + Vector2(0, s * 1.05)]), col)
		2:  # diamond
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 1.1), c + Vector2(s * 0.8, 0), c + Vector2(0, s * 1.1), c + Vector2(-s * 0.8, 0)]), col)
		0:  # spade
			draw_circle(c + Vector2(-s * 0.5, s * 0.15), s * 0.55, col)
			draw_circle(c + Vector2(s * 0.5, s * 0.15), s * 0.55, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.03, s * 0.05), c + Vector2(s * 1.03, s * 0.05), c + Vector2(0, -s * 1.1)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.2), c + Vector2(-s * 0.35, s * 1.05), c + Vector2(s * 0.35, s * 1.05)]), col)
		3:  # club
			draw_circle(c + Vector2(0, -s * 0.5), s * 0.5, col)
			draw_circle(c + Vector2(-s * 0.55, s * 0.25), s * 0.5, col)
			draw_circle(c + Vector2(s * 0.55, s * 0.25), s * 0.5, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0), c + Vector2(-s * 0.35, s * 1.05), c + Vector2(s * 0.35, s * 1.05)]), col)
