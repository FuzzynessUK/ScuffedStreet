class_name Sfx
extends Node
## Short sound effects on the music's instruments (Music):
##   step(n)     a soft, low note for each space moved (STEP_STYLE), the
##               moves alternating between two notes like footsteps; back() a
##               lower one, for stepping back
##   play(name)  "purchase" a cash register's cha-ching (buying a lot, a
##               buyout, winning an auction), "build" two woodblock knocks and
##               a bell chord (investing, building on a plot), "bond_buy"
##               glockenspiel notes running up, "bond_sell" running down
##               "dice_hit" a knock and a sparkle (a fist hits the dice block),
##               "dice_bounce" a soft wooden tap, "dice_land" a bright two-note
##               ding (the roll shows), "sparkle" a quick twinkle running up
##               (a star rising on the Star space)
##               "takeover" an epic orchestral hit (buying out a rival's lot):
##               a drum roll swelling into two brass stabs and a held chord
## Game events carry the name in "sound" (GameState._sound). Clips are cached
## like the music.

const VOLUME_DB := -6.0
const VOICES := 6  # sounds that can overlap
## How a step sounds: "marimba" (a low, round wooden note), "pluck" (a
## plucked string), "tap" (a muted wooden tap) or "bass" (an upright bass
## pluck under a soft marimba).
const STEP_STYLE := "marimba"
const STEP_NOTES := [60, 64]  # alternate steps
const BACK_NOTE := 55
const LEVEL_DB := {"step": -4.0, "back": -6.0, "bond_buy": -1.0, "bond_sell": -1.0, "build": 0.0,
		"purchase": 0.0, "dice_hit": 0.0, "dice_bounce": -8.0, "dice_land": -2.0, "sparkle": -1.0, "takeover": 0.0}
## The register's "ching": a small, high, clangy strike that dies quickly
## (not a bell left ringing).
const CHING := [[1.0, 1.0, 9.0], [1.47, 0.6, 12.0], [2.09, 0.55, 15.0], [2.76, 0.45, 20.0]]
## A coin landing: a tiny high ping, gone almost at once.
const COIN := [[1.0, 1.0, 35.0], [2.4, 0.4, 50.0]]

var _sounds := {}  # name -> AudioStreamWAV
var _steps: Array[AudioStreamWAV] = []
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(Music.CACHE_DIR)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = Settings.BUSES.sfx
		add_child(p)
		_players.append(p)
	for note in STEP_NOTES:
		_steps.append(Music.cached("step_%s%d" % [STEP_STYLE, note], "", step_sound.bind(STEP_STYLE, note), false))
	_sounds.back = Music.cached("back_%s" % STEP_STYLE, "", step_sound.bind(STEP_STYLE, BACK_NOTE), false)
	_sounds.bond_buy = Music.cached("bond_buy", "", _run.bind([84, 88, 91, 96]), false)
	_sounds.bond_sell = Music.cached("bond_sell", "", _run.bind([91, 86, 82, 79]), false)
	_sounds.build = Music.cached("build", "", _build, false)
	_sounds.purchase = Music.cached("purchase", "", _cha_ching, false)
	_sounds.dice_hit = Music.cached("dice_hit", "", _dice_hit, false)
	_sounds.dice_bounce = Music.cached("dice_bounce", "", _dice_bounce, false)
	_sounds.dice_land = Music.cached("dice_land", "", _dice_land, false)
	_sounds.sparkle = Music.cached("sparkle", "", _sparkle, false)
	_sounds.takeover = Music.cached("takeover", "", _takeover, false)


## The sound for the `n`th space of a move (from 0).
func step(n: int) -> void:
	_start(_steps[n % _steps.size()], LEVEL_DB.step)


func back() -> void:
	_start(_sounds.back, LEVEL_DB.back)


func play(name: String) -> void:
	if _sounds.has(name):
		_start(_sounds[name], LEVEL_DB.get(name, 0.0))


func _start(wav: AudioStreamWAV, level_db: float) -> void:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = wav
	p.volume_db = VOLUME_DB + level_db
	p.play()


static func _samples(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * Music.RATE))
	return buf


## A step in `style` (see STEP_STYLE) on `note`: short, low and soft.
static func step_sound(style: String, note: int) -> PackedFloat32Array:
	var buf := _samples(0.5)
	match style:
		"pluck":
			Music._pluck(buf, 0.0, 0.35, note - 12, 0.7, 0.25, 0.985)
		"tap":
			var rng := RandomNumberGenerator.new()
			rng.seed = note
			Music._struck(buf, 0.0, note - 12, 0.5, Music.XYLO)
			Music._drum(buf, "kick", 0.0, 0.25, rng, 0)
		"bass":
			Music._pluck(buf, 0.0, 0.4, note - 24, 0.8, 0.2, 0.99)
			Music._struck(buf, 0.0, note, 0.15, Music.MARIMBA)
		_:
			Music._struck(buf, 0.0, note, 0.6, Music.MARIMBA)
	Music._reverb(buf, 0.1)
	# Soften the very start, so it thuds rather than clicks.
	var soft := int(0.004 * Music.RATE)
	for i in soft:
		buf[i] *= float(i) / soft
	Music._normalise(buf)
	return buf


## Glockenspiel notes in quick succession, the last left ringing.
static func _run(notes: Array) -> PackedFloat32Array:
	var buf := _samples(1.6)
	for i in notes.size():
		Music._struck(buf, i * 0.06, notes[i], 0.5, Music.GLOCK)
	Music._struck(buf, (notes.size() - 1) * 0.06, notes[-1] - 12, 0.2, Music.BELL)
	Music._reverb(buf, 0.25)
	Music._normalise(buf)
	return buf


## Kha-ching, unhurried, in two parts. "Kha": the register's metal lever, a
## bright "chk" (a hiss of metal on metal with a high clink in it) and a
## smaller tick as it latches. "Ching": the drawer springs open with a short,
## bright clang, and coins clatter in it.
const CHING_NOTE := 104
const CHING_AT := 0.26  # seconds from "kha" to "ching"
## Metal striking metal: high, unevenly spaced partials that ring briefly.
const CLACK := [[1.0, 1.0, 45.0], [1.41, 0.7, 55.0], [2.13, 0.45, 70.0], [2.76, 0.3, 90.0]]
static func _cha_ching() -> PackedFloat32Array:
	var buf := _samples(1.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	_clack(buf, 0.0, 96, 0.8, rng)  # "kha": the lever goes down...
	_clack(buf, 0.035, 99, 0.35, rng)  # ...and latches
	Music._drum(buf, "kick", 0.0, 0.1, rng, 0)  # a hint of the register's weight
	Music._drum(buf, "kick", CHING_AT, 0.3, rng, 0)  # the drawer
	_rattle(buf, CHING_AT, 0.05, 0.4, rng)
	Music._struck(buf, CHING_AT, CHING_NOTE, 0.8, CHING)  # "ching"
	Music._struck(buf, CHING_AT + 0.004, CHING_NOTE + 7, 0.5, CHING)
	_tick(buf, CHING_AT, 0.5, rng)  # its hard, sharp strike
	for k in 9:  # coins
		Music._struck(buf, CHING_AT + 0.04 + k * 0.028 + rng.randf_range(0.0, 0.015),
				rng.randi_range(106, 112), 0.18 * (1.0 - k / 12.0), COIN)
	Music._reverb(buf, 0.12)
	Music._normalise(buf)
	return buf


## One metal "chk" on `note`: a short hiss of bright (high-passed) noise,
## gone in about 30 ms, with a high metallic clink ringing under it.
static func _clack(buf: PackedFloat32Array, at: float, note: int, vol: float,
		rng: RandomNumberGenerator) -> void:
	Music._struck(buf, at, note, vol * 0.5, CLACK)
	var start := int(at * Music.RATE)
	var lp := 0.0
	for i in int(0.035 * Music.RATE):
		var t := float(i) / Music.RATE
		var x := rng.randf_range(-1.0, 1.0)
		lp += 0.3 * (x - lp)
		buf[start + i] += (x - lp) * minf(1.0, t / 0.001) * exp(-t * 110.0) * vol


## The instant of a hard strike on metal: 3 ms of the brightest noise.
static func _tick(buf: PackedFloat32Array, at: float, vol: float, rng: RandomNumberGenerator) -> void:
	var start := int(at * Music.RATE)
	var n := int(0.003 * Music.RATE)
	var last := 0.0
	for i in n:
		var x := rng.randf_range(-1.0, 1.0)
		buf[start + i] += (x - last) * (1.0 - float(i) / n) * vol
		last = x


## Metal rattling against metal: bright noise chopped into fast clicks, with
## a couple of short metallic ring tones in it, for `length` seconds.
static func _rattle(buf: PackedFloat32Array, at: float, length: float, vol: float,
		rng: RandomNumberGenerator) -> void:
	var start := int(at * Music.RATE)
	var lp := 0.0
	for i in int((length + 0.05) * Music.RATE):
		var t := float(i) / Music.RATE
		var x := rng.randf_range(-1.0, 1.0)
		lp += 0.4 * (x - lp)
		var chop := 0.55 + 0.45 * sin(t * 180.0 * TAU)  # the parts clattering
		var ring := sin(t * 1870.0 * TAU) + 0.6 * sin(t * 3110.0 * TAU)
		var env := minf(1.0, t / 0.002) * exp(-t * 3.0 / length)
		buf[start + i] += ((x - lp) * chop * 0.7 + ring * 0.15) * env * vol


## Two woodblock knocks, then a bell chord.
static func _build() -> PackedFloat32Array:
	var buf := _samples(1.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for at in [0.0, 0.11]:
		Music._drum(buf, "woodblock", at, 0.9, rng, 0)
	for note in [79, 84, 88]:
		Music._struck(buf, 0.24, note, 0.3, Music.BELL)
	Music._struck(buf, 0.24, 96, 0.2, Music.GLOCK)
	Music._reverb(buf, 0.25)
	Music._normalise(buf)
	return buf


## A fist meets the dice block: a hard woodblock knock with a glockenspiel
## flourish over it.
static func _dice_hit() -> PackedFloat32Array:
	var buf := _samples(1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	Music._drum(buf, "woodblock", 0.0, 1.0, rng, 0)
	Music._drum(buf, "kick", 0.0, 0.4, rng, 0)
	for i in 3:
		Music._struck(buf, 0.02 + i * 0.035, [88, 91, 96][i], 0.35, Music.GLOCK)
	Music._reverb(buf, 0.15)
	Music._normalise(buf)
	return buf


## The block landing at the bottom of the screen: a soft, short wooden tap.
static func _dice_bounce() -> PackedFloat32Array:
	var buf := _samples(0.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 32
	Music._drum(buf, "woodblock", 0.0, 0.5, rng, 0)
	Music._struck(buf, 0.0, 55, 0.4, Music.MARIMBA)
	Music._reverb(buf, 0.08)
	Music._normalise(buf)
	return buf


## The roll settles face on: two bright notes, a fourth apart.
static func _dice_land() -> PackedFloat32Array:
	var buf := _samples(1.2)
	Music._struck(buf, 0.0, 84, 0.5, Music.VIBES)
	Music._struck(buf, 0.09, 89, 0.6, Music.VIBES)
	Music._struck(buf, 0.09, 101, 0.2, Music.GLOCK)
	Music._reverb(buf, 0.2)
	Music._normalise(buf)
	return buf


## A quick twinkle: glockenspiel notes tumbling up a bright scale, with a
## shimmer of very high, soft pings over them.
static func _sparkle() -> PackedFloat32Array:
	var buf := _samples(1.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var notes := [88, 91, 93, 96, 100, 103]
	for i in notes.size():
		Music._struck(buf, i * 0.045, notes[i], 0.4, Music.GLOCK)
	for k in 8:
		Music._struck(buf, 0.05 + k * 0.05 + rng.randf_range(0.0, 0.02), rng.randi_range(103, 110),
				0.12, COIN)
	Music._reverb(buf, 0.3)
	Music._normalise(buf)
	return buf


## TAKEOVER: timpani and snare rolling up to two hard brass stabs, then a big
## held major chord over low strings with a cymbal crash and glockenspiel
## sparkle - the lot changes hands.
static func _takeover() -> PackedFloat32Array:
	var buf := _samples(3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var roll := 0.0
	while roll < 0.58:  # the swell
		var k := roll / 0.58
		Music._drum(buf, "timpani", roll, lerpf(0.15, 0.7, k), rng, 38)
		Music._drum(buf, "snare", roll + 0.02, lerpf(0.05, 0.35, k), rng, 0)
		roll += 0.045
	# [start, length, notes]: stab, stab, then the held chord.
	for e in [[0.6, 0.22, [50, 57, 62, 65]], [0.92, 0.22, [53, 60, 65, 69]],
			[1.24, 1.3, [55, 62, 67, 71, 74]]]:
		for note in e[2]:
			Music._brass(buf, e[0], e[1], note, 0.22)
		Music._drum(buf, "timpani", e[0], 1.0, rng, 31 if e[0] > 1.0 else 38)
		Music._drum(buf, "kick", e[0], 0.7, rng, 0)
	for note in [31, 43, 50]:
		Music._bowed(buf, 1.24, 1.4, note, 0.14, 0.05, 0.7, 1400.0, 0.08)
	Music._drum(buf, "cymbal", 0.6, 0.45, rng, 0)
	Music._drum(buf, "cymbal", 1.24, 0.8, rng, 0)
	for k in 6:
		Music._struck(buf, 1.3 + k * 0.07, [91, 95, 98, 103, 98, 103][k], 0.12, Music.GLOCK)
	Music._reverb(buf, 0.3)
	Music._normalise(buf)
	return buf
