class_name PokerGame
extends Control
## Playable heads-up hold'em at the table. Hover hole cards to lift them; click to
## pick up and inspect. Fold / Call / Raise with a chip slider. Emits `finished`.

signal finished(result: Dictionary)

var engine: PokerEngine
var opp_name := "Theo"
var buy_in := 1000

var _msg: Label
var _pot_label: Label
var _pot_chips: ChipStack
var _opp_label: Label
var _me_label: Label
var _opp_cards: Array[CardView] = []
var _my_cards: Array[CardView] = []
var _board_cards: Array[CardView] = []
var _btn_fold: Button
var _btn_call: Button
var _btn_raise: Button
var _slider: HSlider
var _raise_label: Label
var _btn_next: Button
var _btn_leave: Button
var _opp_bet: Label
var _me_bet: Label
var _action := ""
var _action_to := 0
var _leave := false
var _closed := false
signal _acted
signal _next

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	engine = PokerEngine.new()
	engine.scripted = not GameState.has_flag("poker_first_done")
	_build()
	_run()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var felt := Panel.new()
	UITheme.center(felt, Vector2(1060, 640))
	var sb := UITheme.box(Color("1f5c3e"), 90, Color("5a3f2e"), 14)
	felt.add_theme_stylebox_override("panel", sb)
	add_child(felt)
	var root := Control.new()
	UITheme.center(root, Vector2(1060, 640))
	add_child(root)
	_opp_label = UITheme.label("", 20)
	_opp_label.position = Vector2(380, 18)
	_opp_label.size = Vector2(300, 28)
	_opp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_opp_label)
	for i in 2:
		var c := CardView.new()
		c.position = Vector2(448 + i * 96, 52)
		root.add_child(c)
		_opp_cards.append(c)
	_opp_bet = UITheme.label("", 18, Settings.accent_color())
	_opp_bet.position = Vector2(700, 90)
	root.add_child(_opp_bet)
	for i in 5:
		var c := CardView.new()
		c.position = Vector2(300 + i * 92, 232)
		root.add_child(c)
		_board_cards.append(c)
	_pot_label = UITheme.label("", 22)
	_pot_label.position = Vector2(60, 250)
	root.add_child(_pot_label)
	_pot_chips = ChipStack.new()
	_pot_chips.position = Vector2(60, 280)
	_pot_chips.size = Vector2(190, 70)
	root.add_child(_pot_chips)
	_msg = UITheme.label("", 22, Color(1, 1, 1, 0.9))
	_msg.position = Vector2(280, 366)
	_msg.size = Vector2(500, 60)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_msg)
	for i in 2:
		var c := CardView.new()
		c.position = Vector2(448 + i * 96, 430)
		root.add_child(c)
		c.mouse_entered.connect(func(): _hover_card(c, true))
		c.mouse_exited.connect(func(): _hover_card(c, false))
		c.gui_input.connect(func(e): _card_input(c, e))
		_my_cards.append(c)
	_me_label = UITheme.label("", 20)
	_me_label.position = Vector2(380, 566)
	_me_label.size = Vector2(300, 28)
	_me_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_me_label)
	_me_bet = UITheme.label("", 18, Settings.accent_color())
	_me_bet.position = Vector2(700, 470)
	root.add_child(_me_bet)
	_btn_fold = UITheme.button("Fold")
	_btn_fold.position = Vector2(30, 540)
	_btn_fold.size = Vector2(110, 44)
	_btn_fold.pressed.connect(func(): _choose("fold"))
	root.add_child(_btn_fold)
	_btn_call = UITheme.button("Call")
	_btn_call.position = Vector2(150, 540)
	_btn_call.size = Vector2(130, 44)
	_btn_call.pressed.connect(func(): _choose("call"))
	root.add_child(_btn_call)
	_btn_raise = UITheme.button("Raise")
	_btn_raise.position = Vector2(790, 540)
	_btn_raise.size = Vector2(110, 44)
	_btn_raise.pressed.connect(func(): _choose("raise"))
	root.add_child(_btn_raise)
	_slider = HSlider.new()
	_slider.position = Vector2(780, 500)
	_slider.size = Vector2(230, 24)
	_slider.step = 5
	_slider.value_changed.connect(func(v): _raise_label.text = "Raise to %d" % int(v))
	root.add_child(_slider)
	_raise_label = UITheme.label("", 16, Color(1, 1, 1, 0.8))
	_raise_label.position = Vector2(910, 548)
	root.add_child(_raise_label)
	_btn_next = UITheme.button("Next hand")
	_btn_next.position = Vector2(470, 560)
	_btn_next.size = Vector2(150, 44)
	_btn_next.pressed.connect(func(): _next.emit())
	_btn_next.visible = false
	root.add_child(_btn_next)
	_btn_leave = UITheme.button("Leave table")
	_btn_leave.position = Vector2(900, 18)
	_btn_leave.size = Vector2(140, 40)
	_btn_leave.pressed.connect(_on_leave)
	root.add_child(_btn_leave)
	var hint := UITheme.label("Hover cards to lift them. Click to pick up.", 14, Color(1, 1, 1, 0.45))
	hint.position = Vector2(20, 18)
	root.add_child(hint)

func _hover_card(c: CardView, on: bool) -> void:
	if c.has_meta("held"):
		return
	var tw := create_tween()
	tw.tween_property(c, "position:y", 430.0 - (22.0 if on else 0.0), 0.12)

func _card_input(c: CardView, e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var held := c.has_meta("held")
		if held:
			c.remove_meta("held")
		else:
			c.set_meta("held", true)
		Audio.play_sfx("card", -6.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(c, "scale", Vector2.ONE * (1.0 if held else 1.5), 0.15)
		tw.tween_property(c, "position:y", 430.0 if held else 360.0, 0.15)
		c.z_index = 0 if held else 5

func _choose(kind: String) -> void:
	_action = kind
	_action_to = int(_slider.value)
	_acted.emit()

func _on_leave() -> void:
	_leave = true
	_acted.emit()
	_next.emit()

func _update_ui(reveal_opp: bool = false) -> void:
	_opp_label.text = "%s   %d chips" % [opp_name, engine.stacks[1]]
	_me_label.text = "You   %d chips" % engine.stacks[0]
	_pot_label.text = "Pot  %d" % engine.total_pot()
	_pot_chips.amount = engine.total_pot()
	_opp_bet.text = "bet %d" % engine.bets[1] if engine.bets[1] > 0 else ""
	_me_bet.text = "bet %d" % engine.bets[0] if engine.bets[0] > 0 else ""
	for i in 2:
		if engine.hole[0].size() > i:
			_my_cards[i].set_card(engine.hole[0][i], true)
		if engine.hole[1].size() > i:
			_opp_cards[i].set_card(engine.hole[1][i], reveal_opp)
	for i in 5:
		if engine.board.size() > i:
			_board_cards[i].set_card(engine.board[i], true)
		else:
			_board_cards[i].set_card(-1, false)

func _set_buttons(enabled: bool) -> void:
	_btn_fold.disabled = not enabled
	_btn_call.disabled = not enabled
	var can_r := enabled and engine.can_raise(0)
	_btn_raise.disabled = not can_r
	_slider.editable = can_r
	if enabled:
		var tc := engine.to_call(0)
		_btn_call.text = "Check" if tc == 0 else "Call %d" % tc
		if can_r:
			_slider.min_value = engine.min_raise_to(0)
			_slider.max_value = engine.max_raise_to(0)
			_slider.value = _slider.min_value
			_raise_label.text = "Raise to %d" % int(_slider.value)
		else:
			_raise_label.text = ""

func _say(pool: String, fallback: String = "") -> void:
	_msg.text = Dialogue.pool_text("poker", pool, fallback)

func _run() -> void:
	_say("start", "Cards in the air.")
	while not _closed:
		if engine.busted() != -1 or _leave:
			break
		engine.start_hand()
		for c in _my_cards:
			c.scale = Vector2.ONE
			c.position.y = 430.0
			if c.has_meta("held"):
				c.remove_meta("held")
			c.z_index = 0
		for c in _opp_cards:
			c.set_card(-1)
		_update_ui()
		Audio.play_sfx("card")
		await get_tree().create_timer(0.35).timeout
		_update_ui()
		_msg.text = "Blinds posted. %s." % ("You are on the button" if engine.button == 0 else "%s has the button" % opp_name)
		await get_tree().create_timer(0.6).timeout
		while not engine.hand_over and not _leave:
			if engine.to_act == 0:
				await _player_turn()
			else:
				await _opp_turn()
		if _leave and not engine.hand_over:
			engine.fold(0)
		await _resolve_hand()
		if engine.busted() != -1 or _leave:
			break
		_btn_next.visible = true
		await _next
		_btn_next.visible = false
	_closed = true
	GameState.set_flag("poker_first_done")
	var result := {"net": engine.stacks[0] - buy_in, "hands": engine.hands_played, "wins": engine.hands_won, "bust": engine.busted()}
	finished.emit(result)

func _player_turn() -> void:
	_update_ui()
	_set_buttons(true)
	var prev_board := engine.board.size()
	await _acted
	_set_buttons(false)
	if _leave:
		return
	match _action:
		"fold":
			engine.fold(0)
			_say("fold")
		"call":
			engine.call_or_check(0)
			Audio.play_sfx("chip")
		"raise":
			engine.raise_to(0, _action_to)
			Audio.play_sfx("chip")
			_msg.text = "You raise."
	_after_step(prev_board)

func _opp_turn() -> void:
	_update_ui()
	_set_buttons(false)
	_msg.text = "%s is thinking..." % opp_name
	await get_tree().create_timer(randf_range(0.7, 1.4)).timeout
	var prev_board := engine.board.size()
	var d := engine.opponent_decision()
	match d["action"]:
		"fold":
			engine.fold(1)
			_msg.text = "%s folds." % opp_name
		"call":
			var was := engine.to_call(1)
			engine.call_or_check(1)
			_msg.text = "%s %s." % [opp_name, "checks" if was == 0 else "calls"]
			Audio.play_sfx("chip")
		"raise":
			engine.raise_to(1, d["to"])
			_msg.text = "%s raises to %d." % [opp_name, engine.bets[1]]
			Audio.play_sfx("chip")
	_after_step(prev_board)

func _after_step(prev_board: int) -> void:
	if engine.board.size() > prev_board:
		Audio.play_sfx("card")
	_update_ui(false)

func _resolve_hand() -> void:
	_update_ui(engine.showdown)
	if engine.showdown:
		for c in _opp_cards:
			c.face_up = false
		_opp_cards[0].set_card(engine.hole[1][0], false)
		_opp_cards[1].set_card(engine.hole[1][1], false)
		_opp_cards[0].flip_to(true)
		_opp_cards[1].flip_to(true)
		await get_tree().create_timer(0.5).timeout
	var line := ""
	match engine.winner:
		0:
			var big: bool = engine.win_amount >= 300
			line = Dialogue.pool_text("poker", "win_big" if big else "win", "Nice.")
			Audio.play_sfx("win")
			if engine.showdown:
				var cat := PokerEngine.hand_category(PokerEngine.evaluate(engine.hole[0] + engine.board))
				line += "  (%s)" % PokerEngine.HAND_NAMES[cat]
			line += "  +%d" % (engine.win_amount - 0)
		1:
			line = Dialogue.pool_text("poker", "lose", "Well.")
			Audio.play_sfx("lose", -6.0)
		_:
			line = "Split pot."
	if engine.busted() == 1:
		line = Dialogue.pool_text("poker", "bust_opp", "He's out.")
	elif engine.busted() == 0:
		line = Dialogue.pool_text("poker", "bust_me", "Out of chips.")
	_msg.text = line
	_update_ui(engine.showdown)
	await get_tree().create_timer(0.8).timeout
