class_name PokerEngine
extends RefCounted
## Heads-up Texas hold'em rules + a simple equity-based opponent. Pure logic, no UI,
## so it can be unit-tested headless. Cards are ints 0..51: rank = c % 13 (0=2 .. 12=A),
## suit = c / 13 (0 spades, 1 hearts, 2 diamonds, 3 clubs).

const SB := 10
const BB := 20
const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const HAND_NAMES := ["High card", "Pair", "Two pair", "Three of a kind", "Straight", "Flush", "Full house", "Four of a kind", "Straight flush"]

var rng := RandomNumberGenerator.new()
var stacks := [1000, 1000]     # 0 = player, 1 = opponent
var bets := [0, 0]
var pot := 0                   # chips from finished betting rounds
var hole := [[], []]
var board: Array = []
var deck: Array = []
var street := 0                # 0 preflop, 1 flop, 2 turn, 3 river, 4 showdown/over
var button := 1                # 1 = opponent has the button first hand
var to_act := 0
var acted := [false, false]
var min_raise := BB
var hand_over := true
var winner := -1               # 0 player, 1 opp, 2 split
var win_amount := 0
var showdown := false
var hands_played := 0
var hands_won := 0
var scripted := false          # first hand ever: A♠K♠ vs a pair of nines
var last_text := ""

func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

# ---- evaluation -----------------------------------------------------------

static func card_rank(c: int) -> int:
	return c % 13

static func card_suit(c: int) -> int:
	return c / 13

static func card_name(c: int) -> String:
	return "%s%s" % [RANKS[card_rank(c)], ["s", "h", "d", "c"][card_suit(c)]]

## Score for the best 5-card hand among the given cards (5-7 cards). Higher is better.
static func evaluate(cards: Array) -> int:
	var rc := []
	rc.resize(13)
	rc.fill(0)
	var sc := [[], [], [], []]
	for c in cards:
		rc[card_rank(c)] += 1
		sc[card_suit(c)].append(card_rank(c))
	var flush_ranks: Array = []
	for s in 4:
		if sc[s].size() >= 5:
			flush_ranks = sc[s]
	# straight flush
	if not flush_ranks.is_empty():
		var sf := _straight_high(flush_ranks)
		if sf >= 0:
			return _pack(8, [sf])
	var quads := []
	var trips := []
	var pairs := []
	for r in range(12, -1, -1):
		match rc[r]:
			4: quads.append(r)
			3: trips.append(r)
			2: pairs.append(r)
	if not quads.is_empty():
		var kick := _top_excluding(rc, [quads[0]], 1)
		return _pack(7, [quads[0]] + kick)
	if not trips.is_empty() and (trips.size() > 1 or not pairs.is_empty()):
		var pr := -1
		if trips.size() > 1:
			pr = trips[1]
		if not pairs.is_empty():
			pr = maxi(pr, pairs[0])
		return _pack(6, [trips[0], pr])
	if not flush_ranks.is_empty():
		flush_ranks = flush_ranks.duplicate()
		flush_ranks.sort()
		flush_ranks.reverse()
		return _pack(5, flush_ranks.slice(0, 5))
	var st := _straight_high_counts(rc)
	if st >= 0:
		return _pack(4, [st])
	if not trips.is_empty():
		return _pack(3, [trips[0]] + _top_excluding(rc, [trips[0]], 2))
	if pairs.size() >= 2:
		return _pack(2, [pairs[0], pairs[1]] + _top_excluding(rc, [pairs[0], pairs[1]], 1))
	if pairs.size() == 1:
		return _pack(1, [pairs[0]] + _top_excluding(rc, [pairs[0]], 3))
	return _pack(0, _top_excluding(rc, [], 5))

static func _pack(cat: int, ranks: Array) -> int:
	var v := cat
	for i in 5:
		v = v * 16 + (ranks[i] if i < ranks.size() else 0)
	return v

static func hand_category(score: int) -> int:
	return score >> 20

static func _top_excluding(rc: Array, excl: Array, n: int) -> Array:
	var out := []
	for r in range(12, -1, -1):
		if rc[r] > 0 and not (r in excl):
			out.append(r)
			if out.size() == n:
				break
	return out

static func _straight_high(ranks: Array) -> int:
	var rc := []
	rc.resize(13)
	rc.fill(0)
	for r in ranks:
		rc[r] += 1
	return _straight_high_counts(rc)

static func _straight_high_counts(rc: Array) -> int:
	var run := 0
	for r in range(12, -2, -1):
		var has: bool = rc[r] > 0 if r >= 0 else rc[12] > 0     # r == -1 is the ace playing low
		if has:
			run += 1
			if run == 5:
				return r + 4 if r >= 0 else 3
		else:
			run = 0
	return -1

# ---- hand flow ------------------------------------------------------------

func _draw() -> int:
	return deck.pop_back()

func start_hand() -> void:
	hand_over = false
	winner = -1
	win_amount = 0
	showdown = false
	board = []
	hole = [[], []]
	pot = 0
	bets = [0, 0]
	acted = [false, false]
	street = 0
	min_raise = BB
	button = 1 - button
	deck = range(52)
	for i in range(51, 0, -1):
		var j := rng.randi_range(0, i)
		var t = deck[i]
		deck[i] = deck[j]
		deck[j] = t
	if scripted:
		_stack_deck([12 + 0, 11 + 0, 20, 46, 25, 31, 39, 3, 27])   # As Ks | 9h 9c | Ah 7d 2c | 5s | 3d
		button = 1
	hole[0] = [_draw(), _draw()]
	hole[1] = [_draw(), _draw()]
	# blinds: button posts SB and acts first preflop
	var sb_i := button
	var bb_i := 1 - button
	_post(sb_i, SB)
	_post(bb_i, BB)
	to_act = sb_i

func _stack_deck(cards: Array) -> void:
	# put the scripted cards on top in draw order: p0 c1, p0 c2, p1 c1, p1 c2, flop x3, turn, river
	for c in cards:
		deck.erase(c)
	var order := [cards[0], cards[1], cards[2], cards[3], cards[4], cards[5], cards[6], cards[7], cards[8]]
	order.reverse()
	for c in order:
		deck.append(c)
	scripted = false

func _post(i: int, amount: int) -> void:
	var a := mini(amount, stacks[i])
	stacks[i] -= a
	bets[i] += a

func to_call(i: int) -> int:
	return mini(maxi(bets[0], bets[1]) - bets[i], stacks[i])

func current_bet() -> int:
	return maxi(bets[0], bets[1])

func min_raise_to(i: int) -> int:
	return mini(current_bet() + min_raise, bets[i] + stacks[i])

func max_raise_to(i: int) -> int:
	return bets[i] + stacks[i]

func can_raise(i: int) -> bool:
	return stacks[i] > to_call(i) and stacks[1 - i] > 0

func total_pot() -> int:
	return pot + bets[0] + bets[1]

func fold(i: int) -> void:
	_finish(1 - i, false)

func call_or_check(i: int) -> void:
	var amt: int = to_call(i)
	stacks[i] -= amt
	bets[i] += amt
	acted[i] = true
	_after_action(i)

func raise_to(i: int, target: int) -> void:
	target = clampi(target, min_raise_to(i), max_raise_to(i))
	var prev := current_bet()
	var amt: int = target - bets[i]
	stacks[i] -= amt
	bets[i] = target
	if target - prev >= min_raise:
		min_raise = target - prev
	acted[i] = true
	acted[1 - i] = false
	_after_action(i)

func _after_action(i: int) -> void:
	var someone_all_in: bool = stacks[0] == 0 or stacks[1] == 0
	var equal: bool = bets[0] == bets[1]
	if acted[0] and acted[1] and (equal or someone_all_in):
		_end_round()
	elif someone_all_in and acted[1 - i] and equal:
		_end_round()
	else:
		to_act = 1 - i

func _end_round() -> void:
	# refund any uncalled excess (short all-in)
	if bets[0] != bets[1]:
		var big := 0 if bets[0] > bets[1] else 1
		var excess: int = bets[big] - bets[1 - big]
		bets[big] -= excess
		stacks[big] += excess
	pot += bets[0] + bets[1]
	bets = [0, 0]
	acted = [false, false]
	min_raise = BB
	street += 1
	if stacks[0] == 0 or stacks[1] == 0:
		while board.size() < 5:
			board.append(_draw())
		street = 4
		_showdown()
		return
	match street:
		1: board.append_array([_draw(), _draw(), _draw()])
		2: board.append(_draw())
		3: board.append(_draw())
		_:
			_showdown()
			return
	to_act = 1 - button           # big blind acts first post-flop

func _showdown() -> void:
	showdown = true
	var s0 := evaluate(hole[0] + board)
	var s1 := evaluate(hole[1] + board)
	if s0 > s1:
		_finish(0, true)
	elif s1 > s0:
		_finish(1, true)
	else:
		_finish(2, true)

func _finish(w: int, was_showdown: bool) -> void:
	showdown = was_showdown
	pot += bets[0] + bets[1]
	bets = [0, 0]
	hand_over = true
	winner = w
	hands_played += 1
	var total := pot
	if w == 2:
		stacks[0] += total / 2
		stacks[1] += total - total / 2
		win_amount = 0
	else:
		stacks[w] += total
		win_amount = total
		if w == 0:
			hands_won += 1
	pot = 0
	street = 4

func busted() -> int:
	if stacks[0] <= 0:
		return 0
	if stacks[1] <= 0:
		return 1
	return -1

# ---- opponent -------------------------------------------------------------

## Monte-Carlo equity of `cards` vs a random hand.
func equity(cards: Array, board_cards: Array, sims: int = 70) -> float:
	var known := cards + board_cards
	var wins := 0.0
	var pool := []
	for c in 52:
		if not (c in known):
			pool.append(c)
	for s in sims:
		var p := pool.duplicate()
		for i in range(p.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = p[i]
			p[i] = p[j]
			p[j] = t
		var opp := [p[0], p[1]]
		var b := board_cards.duplicate()
		var k := 2
		while b.size() < 5:
			b.append(p[k])
			k += 1
		var me := evaluate(cards + b)
		var th := evaluate(opp + b)
		if me > th:
			wins += 1.0
		elif me == th:
			wins += 0.5
	return wins / sims

## Returns {"action": "fold"|"call"|"raise", "to": int}
func opponent_decision() -> Dictionary:
	var i := 1
	var e := equity(hole[1], board)
	var call_cost := to_call(i)
	var pot_now := total_pot()
	var odds := float(call_cost) / float(pot_now + call_cost) if call_cost > 0 else 0.0
	var r := rng.randf()
	if call_cost == 0:
		if e > 0.66 and r < 0.75 and can_raise(i):
			return {"action": "raise", "to": current_bet() + maxi(min_raise, int(pot_now * rng.randf_range(0.5, 0.8)))}
		if e < 0.4 and r < 0.1 and can_raise(i):
			return {"action": "raise", "to": current_bet() + min_raise}
		return {"action": "call", "to": 0}
	if e > 0.78 and r < 0.55 and can_raise(i):
		return {"action": "raise", "to": current_bet() + maxi(min_raise, int(pot_now * rng.randf_range(0.6, 1.0)))}
	if e > odds + 0.07 or r < 0.08:
		return {"action": "call", "to": 0}
	return {"action": "fold", "to": 0}
