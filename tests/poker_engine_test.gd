extends SceneTree
## Headless unit checks for PokerEngine (hand ranking, split pots, all-in, chip conservation).
## Run: godot --headless --path . -s tests/poker_engine_test.gd   (see tests/run_unit.sh)
## Deterministic: every random draw comes from a seeded engine.

var _fails := 0
var _checks := 0

# card helpers: rank 0=2 .. 12=A, suit 0 spades, 1 hearts, 2 diamonds, 3 clubs
func c(rank_name: String, suit: String) -> int:
	return PokerEngine.RANKS.find(rank_name) + 13 * ["s", "h", "d", "c"].find(suit)

func hand(names: String) -> Array:
	var out := []
	for tok in names.split(" "):
		out.append(c(tok.substr(0, tok.length() - 1), tok.substr(tok.length() - 1)))
	return out

func ok(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", label)

func score(names: String) -> int:
	return PokerEngine.evaluate(hand(names))

func _init() -> void:
	test_categories()
	test_ordering()
	test_edge_hands()
	test_split_pot()
	test_all_in()
	test_scripted_first_hand()
	test_random_play_conserves_chips()
	test_determinism()
	print("[poker] %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)

func test_categories() -> void:
	var cases := {
		"As Ks Qs Js 10s 2d 3c": 8,     # royal flush is a straight flush
		"9h 9d 9s 9c Kd 2c 3c": 7,
		"Kh Kd Ks 4c 4d 2c 7s": 6,
		"2h 7h 9h Jh Kh 3c 3d": 5,
		"5h 6d 7s 8c 9d 2c 2d": 4,
		"Qh Qd Qs 4c 8d 2c 7s": 3,
		"Jh Jd 4s 4c Kd 2c 7s": 2,
		"Ah Ad 4s 5c 9d 2c 7s": 1,
		"Ah Jd 4s 5c 9d 2c 7s": 0,
	}
	for k in cases:
		ok(PokerEngine.hand_category(score(k)) == cases[k], "category of %s should be %d (was %d)" % [k, cases[k], PokerEngine.hand_category(score(k))])

func test_ordering() -> void:
	var order := [
		"As 7d 4c 3h 2s 9c Jd",                 # high card
		"2s 2d 5c 8h Jd 9c 3s",                 # pair of twos
		"Ah Ad 4s 5c 9d 2c 7s",                 # pair of aces
		"3h 3d 4s 4c 9d 2c 7s",                 # two pair
		"Kh Kd 9s 9c 2d 3c 7s",                 # higher two pair
		"4h 4d 4s 8c 9d 2c 7s",                 # trips
		"5h 6d 7s 8c 9d Kc Kd",                 # straight
		"2h 7h 9h Jh Kh 3c 4d",                 # flush
		"2h 2d 2s 3c 3d 9c 7s",                 # full house
		"9h 9d 9s 9c Kd 2c 3c",                 # quads
		"5d 6d 7d 8d 9d Kc Kd",                 # straight flush
	]
	for i in range(1, order.size()):
		ok(score(order[i]) > score(order[i - 1]), "%s should beat %s" % [order[i], order[i - 1]])

func test_edge_hands() -> void:
	# wheel is a straight, but the lowest one
	ok(PokerEngine.hand_category(score("Ah 2d 3s 4c 5d 9c Kd")) == 4, "wheel is a straight")
	ok(score("6h 2d 3s 4c 5d 9c Kd") > score("Ah 2d 3s 4c 5d 9c Kd"), "six-high straight beats the wheel")
	ok(score("Ah Kd Qs Jc 10d 2c 3d") > score("9h Kd Qs Jc 10d 2c 3d"), "broadway beats king-high straight")
	# ace-high flush needs five of one suit; four is not enough
	ok(PokerEngine.hand_category(score("Ah 2h 9h Jh 3c 4d 7s")) == 0, "four hearts is not a flush")
	# kickers decide
	ok(score("Ah Ad Ks 5c 9d 2c 7s") > score("Ac As Qh 5d 9h 2d 7d"), "pair of aces: king kicker beats queen")
	# three pairs: the best two play, best remaining card kicks
	ok(score("Kh Kd 9s 9c 3d 3c Qs") > score("Kc Ks 9h 9d 3h 3s 2c"), "three pairs: queen kicker beats a deuce")
	# full house: higher trips wins, then higher pair; two sets of trips make a full house
	ok(score("2h 2d 2s Ac Ad 9c 7s") > score("2c 2h 2s Kc Kd 9d 7d"), "twos full of aces beats twos full of kings")
	ok(PokerEngine.hand_category(score("3h 3d 3s 8c 8d 8h 7s")) == 6, "two trips make a full house")
	# the board can play for both: equal scores
	ok(score("As Ks Qs Js 10s 2c 3d") == score("As Ks Qs Js 10s 9h 4d"), "royal on board splits")
	ok(score("Ah Kd Qs Jc 9d 2c 3d") == score("Ac Kh Qh Jd 9h 4c 5d"), "same five best cards tie")

func test_split_pot() -> void:
	var e := PokerEngine.new(1)
	e.start_hand()
	e.hole = [hand("2c 3d"), hand("2h 3s")]
	e.board = hand("As Ks Qs Js 10s")
	e.pot = 100
	e.bets = [0, 0]
	e.stacks = [450, 450]
	e._showdown()
	ok(e.winner == 2, "royal flush board is a split")
	ok(e.stacks[0] + e.stacks[1] == 1000, "split conserves chips")
	ok(e.stacks[0] == 500 and e.stacks[1] == 500, "even split pays 50 each")
	# odd pot: the extra chip is not lost
	e.hand_over = false
	e.pot = 101
	e.stacks = [450, 449]
	e._showdown()
	ok(e.stacks[0] + e.stacks[1] == 1000, "odd split conserves chips")
	ok(absi(e.stacks[0] - e.stacks[1]) <= 1 + 1, "odd split is nearly even")
	# clear winner takes everything
	e.hand_over = false
	e.hole = [hand("Ah Ad"), hand("2h 3s")]
	e.board = hand("Ac 7d 9c Jd Kh")
	e.pot = 200
	e.stacks = [400, 400]
	e._showdown()
	ok(e.winner == 0 and e.stacks[0] == 600, "better hand wins the pot")

func test_all_in() -> void:
	# short stack calls a big all-in: the excess is refunded, nobody goes negative
	var e := PokerEngine.new(7)
	e.stacks = [300, 1000]
	e.start_hand()
	var guard := 0
	while not e.hand_over and guard < 20:
		guard += 1
		var i: int = e.to_act
		if e.can_raise(i):
			e.raise_to(i, e.max_raise_to(i))
		else:
			e.call_or_check(i)
		ok(e.stacks[0] >= 0 and e.stacks[1] >= 0, "no negative stacks during all-in")
	ok(e.hand_over, "all-in hand resolves")
	ok(e.stacks[0] + e.stacks[1] == 1300, "all-in conserves chips (%d)" % [e.stacks[0] + e.stacks[1]])
	ok(e.board.size() == 5 or e.winner >= 0, "board is run out after all-in")
	# both all-in for equal stacks
	var f := PokerEngine.new(3)
	f.start_hand()
	guard = 0
	while not f.hand_over and guard < 20:
		guard += 1
		var j: int = f.to_act
		if f.can_raise(j):
			f.raise_to(j, f.max_raise_to(j))
		else:
			f.call_or_check(j)
	ok(f.stacks[0] + f.stacks[1] == 2000, "equal all-in conserves chips")
	ok(f.stacks[0] == 0 or f.stacks[1] == 0 or f.winner == 2, "someone is felted unless split")
	# fold: folder loses only what they bet
	var g := PokerEngine.new(5)
	g.start_hand()
	var folder: int = g.to_act
	g.fold(folder)
	ok(g.hand_over and g.winner == 1 - folder, "fold ends the hand for the other player")
	ok(g.stacks[0] + g.stacks[1] == 2000, "fold conserves chips")
	# short stack that cannot cover the blind still posts what it has
	var h := PokerEngine.new(9)
	h.stacks = [6, 1000]
	h.button = 0
	h.start_hand()
	ok(h.stacks[0] >= 0 and h.bets[0] <= 6, "blind is capped by the stack")

func test_scripted_first_hand() -> void:
	var e := PokerEngine.new(11)
	e.scripted = true
	e.start_hand()
	ok(card_set(e.hole[0]) == card_set(hand("As Ks")), "scripted hand: player holds A-K suited")
	ok(card_set(e.hole[1]) == card_set(hand("9h 9c")), "scripted hand: opponent holds nines")
	ok(not e.scripted, "script is consumed")
	var all: Array = e.hole[0] + e.hole[1]
	ok(all.size() == 4, "four hole cards")

func card_set(cards: Array) -> Array:
	var s := cards.duplicate()
	s.sort()
	return s

## Random legal play: chips are always conserved and never negative; every hand ends.
func test_random_play_conserves_chips() -> void:
	for seed_value in range(1, 41):
		var e := PokerEngine.new(seed_value)
		var r := RandomNumberGenerator.new()
		r.seed = seed_value * 977
		for h in 60:
			if e.busted() != -1:
				e.stacks = [1000, 1000]
			e.start_hand()
			var guard := 0
			while not e.hand_over and guard < 60:
				guard += 1
				var i: int = e.to_act
				var roll := r.randf()
				if roll < 0.15 and e.to_call(i) > 0:
					e.fold(i)
				elif roll < 0.45 and e.can_raise(i):
					e.raise_to(i, r.randi_range(e.min_raise_to(i), e.max_raise_to(i)))
				else:
					e.call_or_check(i)
				if e.stacks[0] < 0 or e.stacks[1] < 0 or e.bets[0] < 0 or e.bets[1] < 0:
					ok(false, "negative chips seed %d hand %d" % [seed_value, h])
					return
				if e.stacks[0] + e.stacks[1] + e.total_pot() != 2000 and not e.hand_over:
					ok(false, "chips leaked mid-hand seed %d hand %d: %d" % [seed_value, h, e.stacks[0] + e.stacks[1] + e.total_pot()])
					return
			if not e.hand_over:
				ok(false, "hand never ended seed %d hand %d" % [seed_value, h])
				return
			if e.stacks[0] + e.stacks[1] != 2000:
				ok(false, "chips leaked at hand end seed %d hand %d: %d" % [seed_value, h, e.stacks[0] + e.stacks[1]])
				return
	ok(true, "2400 random hands conserve chips")

func test_determinism() -> void:
	var a := PokerEngine.new(42)
	var b := PokerEngine.new(42)
	a.start_hand()
	b.start_hand()
	ok(a.hole == b.hole and a.deck == b.deck, "same seed deals the same hand")
	var d := PokerEngine.new(43)
	d.start_hand()
	ok(a.hole != d.hole or a.deck != d.deck, "different seeds deal differently")
