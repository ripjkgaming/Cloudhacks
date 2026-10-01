class_name ChipStack
extends Control
## Draws an amount as stacks of coloured chips.

var amount := 0:
	set(v):
		amount = v
		queue_redraw()

const DENOMS := [[100, Color("2b2b30")], [50, Color("2c6fbb")], [20, Color("2f8f5b")], [10, Color("c0392b")], [5, Color("e5b84b")]]

func _init() -> void:
	custom_minimum_size = Vector2(150, 60)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var left := amount
	var x := 14.0
	for d in DENOMS:
		var n := mini(left / d[0], 8)
		left -= (left / d[0]) * d[0]
		for i in n:
			var y := size.y - 12.0 - i * 5.0
			draw_circle(Vector2(x, y), 13.0, Color(0, 0, 0, 0.35))
			draw_circle(Vector2(x, y - 1), 12.0, d[1])
			draw_arc(Vector2(x, y - 1), 8.0, 0.0, TAU, 16, Color(1, 1, 1, 0.55), 1.5)
		if n > 0:
			x += 30.0
