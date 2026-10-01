extends Node
## Fully procedural audio: lo-fi music variants, ambience loops and SFX are
## synthesised at startup (no audio asset files). Mood follows Narrative.current.

const RATE := 16000
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_AMB := "Ambience"

var enabled := true
var sfx := {}                 # name -> AudioStreamWAV
var music := {}               # kind -> AudioStreamWAV
var _music_players: Array[AudioStreamPlayer] = []
var _active_music := 0
var _current_kind := ""
var _amb_players := {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _heart_timer := 0.0
var _clock_timer := 0.0
var _chirp_timer := 6.0
var _music_ready := {}
var _thread: Thread
var _lock := Mutex.new()
var _pending_kind := ""
var _music_gain := 1.0       # extra gain (silence() sets 0)
var _ambience_kind := "none"
var _lp := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = DisplayServer.get_name() != "headless"
	_setup_buses()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_MUSIC
		add_child(p)
		_music_players.append(p)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_sfx_pool.append(p)
	for k in ["room", "traffic"]:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_AMB
		p.volume_db = -80
		add_child(p)
		_amb_players[k] = p
	Settings.changed.connect(apply_volumes)
	apply_volumes()
	if enabled:
		_synth_sfx()
		_thread = Thread.new()
		_thread.start(_synth_music_thread)

func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()

func _setup_buses() -> void:
	for b in [BUS_MUSIC, BUS_SFX, BUS_AMB]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
			var lp := AudioEffectLowPassFilter.new()
			lp.cutoff_hz = 20000
			AudioServer.add_bus_effect(idx, lp)
		_lp[b] = AudioServer.get_bus_effect(AudioServer.get_bus_index(b), 0)

func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(Settings.master_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC), linear_to_db(maxf(Settings.music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_SFX), linear_to_db(maxf(Settings.sfx_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_AMB), linear_to_db(maxf(Settings.sfx_volume * 0.8, 0.0001)))

# ======================================================================
# Public API
# ======================================================================

func play_sfx(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not enabled or not sfx.has(name):
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = sfx[name]
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return

## kind: none | lofi1 | lofi2 | detuned | drone | ending
func set_music(kind: String, fade: float = 2.0) -> void:
	_current_kind = kind
	if not enabled:
		return
	_start_music(kind, fade)

func _start_music(kind: String, fade: float) -> void:
	var old := _music_players[_active_music]
	if kind == "none":
		_fade_player(old, -80.0, fade, true)
		return
	_lock.lock()
	var stream: AudioStreamWAV = music.get(kind)
	_lock.unlock()
	if stream == null:
		_pending_kind = kind          # synthesis thread not finished; retried in _process
		return
	_pending_kind = ""
	if old.playing and old.stream == stream:
		return
	_active_music = 1 - _active_music
	var nw := _music_players[_active_music]
	nw.stream = stream
	nw.volume_db = -80
	nw.play()
	_fade_player(nw, 0.0, fade, false)
	_fade_player(old, -80.0, fade, true)

func _fade_player(p: AudioStreamPlayer, db: float, t: float, stop_after: bool) -> void:
	var tw := create_tween()
	tw.tween_property(p, "volume_db", db, maxf(t, 0.01))
	if stop_after:
		tw.tween_callback(p.stop)

## Total silence for fourth-wall moments (music, ambience, ticking, heartbeat).
func silence(fade: float = 0.6) -> void:
	_music_gain = 0.0
	for p in _amb_players.values():
		_fade_player(p, -80.0, fade, false)

func restore(fade: float = 2.0) -> void:
	_music_gain = 1.0
	set_ambience(_ambience_kind)

func is_silent() -> bool:
	return _music_gain == 0.0

func set_ambience(kind: String) -> void:
	_ambience_kind = kind
	if not enabled:
		return
	var targets := {"room": -80.0, "traffic": -80.0}
	match kind:
		"room":
			targets = {"room": -14.0, "traffic": -26.0}
		"outdoor":
			targets = {"room": -80.0, "traffic": -16.0}
	for k in _amb_players:
		var p: AudioStreamPlayer = _amb_players[k]
		if not p.playing and targets[k] > -80.0 and sfx.has("amb_" + k):
			p.stream = sfx["amb_" + k]
			p.play()
		_fade_player(p, targets[k] if _music_gain > 0.0 else -80.0, 1.5, false)

func music_kind_for_day(day: int) -> String:
	if GameState.cycle_broken:
		return "ending" if GameState.essay_done else "lofi1"
	if day <= 1: return "lofi1"
	if day == 2: return "lofi2"
	if day == 3: return "detuned"
	return "drone"

# ======================================================================
# Frame update: narrative-driven mood
# ======================================================================

func _process(delta: float) -> void:
	if not enabled:
		return
	if _pending_kind != "":
		_start_music(_pending_kind, 2.0)
	var n: Dictionary = Narrative.current
	var muffle: float = clampf(n.get("muffle", 0.0), 0.0, 1.0)
	if Settings.reduce_motion:
		muffle *= 0.6
	var cutoff := lerpf(20000.0, 500.0, muffle)
	for b in _lp:
		_lp[b].cutoff_hz = cutoff
	# music follows profile loudness (unless silenced)
	var mp := _music_players[_active_music]
	if mp.playing:
		mp.pitch_scale = 1.0 - clampf(GameState.get_psy("pressure") / 100.0, 0.0, 1.0) * 0.0
	var mus_scale: float = _music_gain * clampf(n.get("music", 1.0), 0.0, 1.5)
	_music_players[0].volume_db = _music_players[0].volume_db  # fades handled by tweens
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC),
			linear_to_db(maxf(Settings.music_volume * mus_scale, 0.0001)))
	# heartbeat
	var heart: float = n.get("heart", 0.0) * _music_gain
	if heart > 0.05:
		var bpm := 62.0 + 50.0 * heart + GameState.get_psy("anxiety") * 0.2
		_heart_timer -= delta
		if _heart_timer <= 0.0:
			_heart_timer = 60.0 / bpm
			play_sfx("heart", lerpf(-22.0, -4.0, heart))
	# clock: audible only at home, louder with pressure
	if _ambience_kind == "room" and _music_gain > 0.0:
		_clock_timer -= delta
		if _clock_timer <= 0.0:
			_clock_timer = 1.0
			var p := GameState.get_psy("pressure")
			play_sfx("tick", lerpf(-30.0, -6.0, clampf(p / 100.0, 0.0, 1.0)) + (4.0 if GameState.day >= 3 else 0.0))
	_chirp_timer -= delta
	if _chirp_timer <= 0.0:
		_chirp_timer = randf_range(5.0, 14.0)
		if _music_gain > 0.0 and GameState.get_psy("pressure") < 50.0 and _ambience_kind != "none":
			play_sfx("chirp", -22.0, randf_range(0.9, 1.3))

# ======================================================================
# Synthesis
# ======================================================================

static func mtof(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)

static func to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w

static func piano_note(freq: float, dur: float, vel: float = 1.0, bright: float = 1.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var w := TAU * freq / RATE
	for i in n:
		var t := float(i) / RATE
		var env := (1.0 - exp(-t * 70.0)) * exp(-t * 2.6)
		var v := sin(w * i) + 0.42 * bright * sin(2.0 * w * i) * exp(-t * 3.0) + 0.14 * bright * sin(3.0 * w * i) * exp(-t * 5.0)
		out[i] = v * env * vel * 0.22
	return out

static func mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, at: int) -> void:
	var n := mini(src.size(), dst.size() - at)
	for i in n:
		dst[at + i] += src[i]
	# wrap the tail so loops are seamless
	if src.size() > dst.size() - at:
		var over := src.size() - (dst.size() - at)
		for i in mini(over, dst.size()):
			dst[i] += src[(dst.size() - at) + i]

func _synth_music_thread() -> void:
	for kind in ["lofi1", "lofi2", "detuned", "drone", "ending"]:
		var s := _make_music(kind)
		_lock.lock()
		music[kind] = s
		_lock.unlock()

func _make_music(kind: String) -> AudioStreamWAV:
	var bar := 4.0
	var total := int(bar * 4.0 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	if kind == "drone":
		for i in total:
			var t := float(i) / RATE
			var v := 0.30 * sin(TAU * 55.0 * t) + 0.18 * sin(TAU * 82.5 * t + 0.4) + 0.12 * sin(TAU * 110.0 * t + 1.1)
			v += 0.05 * sin(TAU * 164.0 * t) * (0.5 + 0.5 * sin(TAU * t / 8.0 * 2.0))
			buf[i] = v * 0.5
		return to_wav(buf, true)
	var chords := [
		{"bass": 45, "arp": [57, 60, 64, 67]},
		{"bass": 41, "arp": [57, 60, 64, 65]},
		{"bass": 48, "arp": [60, 64, 67, 71]},
		{"bass": 43, "arp": [59, 62, 67, 69]},
	]
	var detune := 1.0 if kind != "detuned" else 0.972
	var cache := {}
	if kind == "ending":
		var mel := [72, 76, 79, 76, 74, 79, 83, 79, 72, 76, 79, 84, 83, 79, 76, 72]
		for i in mel.size():
			var f := mtof(mel[i])
			var key := "m%d" % mel[i]
			if not cache.has(key):
				cache[key] = piano_note(f, 3.2, 0.9)
			mix_into(buf, cache[key], int(i * 1.0 * RATE))
		for c in 4:
			var bk := "b%d" % chords[c]["bass"]
			if not cache.has(bk):
				cache[bk] = piano_note(mtof(chords[c]["bass"]), 3.8, 0.8)
			mix_into(buf, cache[bk], int(c * bar * RATE))
		return to_wav(buf, true)
	var pattern := [0, 2, 1, 3, 2, 1, 3, 2]
	for c in 4:
		var ch: Dictionary = chords[c]
		var t0 := c * bar
		var bk := "b%d" % ch["bass"]
		if not cache.has(bk):
			cache[bk] = piano_note(mtof(ch["bass"]) * detune, 2.4, 0.9, 0.5)
		mix_into(buf, cache[bk], int(t0 * RATE))
		mix_into(buf, cache[bk], int((t0 + 2.0) * RATE + (60 if c % 2 == 0 else 0)))
		for k in 8:
			var m: int = ch["arp"][pattern[k]]
			var key := "a%d" % m
			if not cache.has(key):
				cache[key] = piano_note(mtof(m) * detune, 1.3, 0.7)
			var swing := 0.06 if k % 2 == 1 else 0.0
			mix_into(buf, cache[key], int((t0 + k * 0.5 + swing) * RATE))
		if kind == "lofi2" or kind == "detuned":
			# extra soft pad layer
			for i in int(bar * RATE):
				var t := float(i) / RATE
				var env := sin(PI * t / bar)
				var v := 0.0
				for m in [ch["arp"][0], ch["arp"][2]]:
					v += sin(TAU * mtof(m - 12) * detune * t)
				buf[int(t0 * RATE) + i] += v * env * 0.035
	# tape-ish low pass + faint crackle
	var y := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in total:
		y += 0.45 * (buf[i] - y)
		var crackle := 0.0
		if rng.randf() < 0.0008:
			crackle = rng.randf_range(-0.03, 0.03)
		buf[i] = y + crackle
	if kind == "detuned":
		# slow tape wobble by resampling with a vibrato
		var src := buf.duplicate()
		for i in total:
			var pos := float(i) + 18.0 * sin(TAU * float(i) / RATE * 0.35)
			var a := int(pos)
			var fr := pos - a
			var a0 := posmod(a, total)
			var a1 := posmod(a + 1, total)
			buf[i] = lerpf(src[a0], src[a1], fr)
	return to_wav(buf, true)

func _noise_buf(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		b[i] = randf_range(-1.0, 1.0)
	return b

func _synth_sfx() -> void:
	seed(12345)
	# UI + interaction
	sfx["click"] = to_wav(_burst(0.04, 2200.0, 0.25, true), false)
	sfx["key"] = to_wav(_burst(0.035, 1500.0, 0.35, true), false)
	sfx["card"] = to_wav(_burst(0.09, 3000.0, 0.3, true), false)
	sfx["chip"] = to_wav(_burst(0.06, 3800.0, 0.35, false), false)
	sfx["tick"] = to_wav(_burst(0.02, 4200.0, 0.5, true), false)
	sfx["step"] = to_wav(_burst(0.12, 160.0, 0.55, true), false)
	sfx["thud"] = to_wav(_burst(0.25, 90.0, 0.8, true), false)
	sfx["creak"] = to_wav(_sweep(0.35, 380.0, 230.0, 0.12), false)
	sfx["gulp"] = to_wav(_sweep(0.3, 300.0, 520.0, 0.18), false)
	sfx["door"] = to_wav(_door(), false)
	sfx["heart"] = to_wav(_heartbeat(), false)
	sfx["notify"] = to_wav(_ping([880.0, 1318.5], 0.16), false)
	sfx["win"] = to_wav(_ping([523.25, 659.25, 783.99, 1046.5], 0.14), false)
	sfx["lose"] = to_wav(_ping([392.0, 349.2, 293.7, 261.6], 0.2), false)
	sfx["ding"] = to_wav(_ping([1046.5], 0.5), false)
	sfx["chirp"] = to_wav(_chirp(), false)
	sfx["buzz"] = to_wav(_buzz(), false)
	sfx["swoosh"] = to_wav(_sweep(0.4, 200.0, 1200.0, 0.1), false)
	sfx["amb_room"] = to_wav(_room_loop(), true)
	sfx["amb_traffic"] = to_wav(_traffic_loop(), true)

func _burst(dur: float, freq: float, vol: float, noise: bool) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var y := 0.0
	var a := clampf(freq / float(RATE) * 1.2, 0.02, 0.9)
	for i in n:
		var t := float(i) / n
		var src := randf_range(-1.0, 1.0) if noise else sin(TAU * freq * i / RATE)
		y += a * (src - y)
		b[i] = y * pow(1.0 - t, 3.0) * vol * (1.6 if noise else 1.0)
	return b

func _sweep(dur: float, f0: float, f1: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := 0.0
	var y := 0.0
	for i in n:
		var t := float(i) / n
		ph += TAU * lerpf(f0, f1, t) / RATE
		y += 0.3 * (randf_range(-1.0, 1.0) - y)
		b[i] = (sin(ph) * 0.5 + y) * sin(PI * t) * vol
	return b

func _door() -> PackedFloat32Array:
	var a := _burst(0.3, 110.0, 0.9, true)
	var c := _sweep(0.25, 500.0, 300.0, 0.15)
	for i in mini(a.size(), c.size()):
		a[i] += c[i]
	return a

func _heartbeat() -> PackedFloat32Array:
	var n := int(0.5 * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for beat in [[0.0, 1.0, 55.0], [0.17, 0.7, 48.0]]:
		var s := int(beat[0] * RATE)
		for i in int(0.16 * RATE):
			if s + i < n:
				var t := float(i) / RATE
				b[s + i] += sin(TAU * beat[2] * t) * exp(-t * 28.0) * beat[1] * 0.9
	return b

func _ping(freqs: Array, step: float) -> PackedFloat32Array:
	var n := int((step * freqs.size() + 0.5) * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for k in freqs.size():
		var s := int(k * step * RATE)
		for i in int(0.5 * RATE):
			if s + i < n:
				var t := float(i) / RATE
				b[s + i] += sin(TAU * freqs[k] * t) * exp(-t * 7.0) * 0.28
	return b

func _chirp() -> PackedFloat32Array:
	var n := int(0.5 * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for k in 3:
		var s := int(k * 0.14 * RATE)
		var f0 := 3200.0 + randf() * 800.0
		var ph := 0.0
		for i in int(0.09 * RATE):
			if s + i < n:
				var t := float(i) / (0.09 * RATE)
				ph += TAU * (f0 + 900.0 * t) / RATE
				b[s + i] += sin(ph) * sin(PI * t) * 0.25
	return b

func _buzz() -> PackedFloat32Array:
	var n := int(0.5 * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		var t := float(i) / RATE
		var on := 1.0 if fmod(t, 0.25) < 0.15 else 0.0
		b[i] = sin(TAU * 130.0 * t) * 0.3 * on
	return b

func _room_loop() -> PackedFloat32Array:
	# computer fan + AC hum, periodic so it loops cleanly
	var secs := 2.0
	var n := int(secs * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		y += 0.08 * (randf_range(-1.0, 1.0) - y)
		b[i] = y * 0.5 + sin(TAU * 60.0 * t) * 0.05 + sin(TAU * 120.0 * t) * 0.03
	# crossfade ends
	var f := 400
	for i in f:
		var a := float(i) / f
		b[i] = lerpf(b[n - f + i], b[i], a)
	return b

func _traffic_loop() -> PackedFloat32Array:
	var secs := 6.0
	var n := int(secs * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		y += 0.03 * (randf_range(-1.0, 1.0) - y)
		var swell := 0.6 + 0.4 * sin(TAU * t / secs * 2.0) * sin(TAU * t / secs)
		b[i] = y * 2.2 * swell
	var f := 800
	for i in f:
		var a := float(i) / f
		b[i] = lerpf(b[n - f + i], b[i], a)
	return b
