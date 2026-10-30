class_name Music
extends Node
## Background music and stingers, played on synthesised acoustic-style
## instruments (no audio files): plucked harp, bass and pizzicato strings
## (Karplus-Strong), bowed strings, flute and clarinet, marimba, glockenspiel
## and bells (decaying partials), brass, and a kit of timpani, kick, snare,
## clap, shaker, woodblock and cymbal, all through a small reverb.
##
## Loops: the calm journey theme; the intense final stretch while anyone is in
## reach of the win; the casino tune (Slots, Pick a Card, the Chance Wheel); the
## race tune (Critter Race); the bonus tune for card picks. Each is
## rendered once on a worker thread and cached in CACHE_DIR, so later
## launches start at once (change SOUND_VERSION when a sound changes).

const RATE := 22050
const VOLUME_DB := -9.0
const SILENT_DB := -60.0
const FADE := 1.2  # seconds to crossfade between the loops
const DUCK_DB := 10.0  # how far the music dips under a fanfare
const TAIL := 3.0  # seconds of ringing and reverb kept after the last note
const PEAK := 0.9  # every clip is scaled to peak here
const CACHE_DIR := "user://music_cache"
const SOUND_VERSION := 12
## The whole-block fanfare: a snare roll, then one rising note per building
## as its roof goes on (BoardView.whole_block timing), then a held chord.
const FANFARE_LEAD_IN := 0.5
const FANFARE_STEP := 0.35
const FANFARE_NOTES := [60, 64, 67, 72, 76, 79, 84]
const FANFARE_MAX := 6  # buildings in a block the fanfare is rendered for

## Struck instruments: [frequency ratio, level, decay per second] per partial.
const MARIMBA := [[1.0, 1.0, 7.0], [4.0, 0.22, 24.0], [10.0, 0.05, 55.0]]
const GLOCK := [[1.0, 1.0, 2.2], [2.76, 0.3, 6.0], [5.4, 0.12, 10.0], [8.93, 0.05, 16.0]]
const BELL := [[0.5, 0.25, 1.2], [1.0, 1.0, 1.6], [1.19, 0.3, 2.0], [1.56, 0.2, 2.6],
		[2.0, 0.35, 2.4], [2.51, 0.12, 3.5]]
const VIBES := [[1.0, 1.0, 2.0], [4.0, 0.12, 9.0], [10.0, 0.03, 30.0]]
const PIANO := [[1.0, 1.0, 2.5], [2.0, 0.45, 3.5], [3.0, 0.22, 5.0], [4.0, 0.12, 7.0],
		[5.0, 0.06, 9.0], [6.0, 0.03, 12.0]]
const XYLO := [[1.0, 1.0, 16.0], [3.0, 0.25, 35.0], [6.3, 0.08, 60.0]]

## A song: tempo; one chord per bar; parts, each on an instrument (see _note),
## either a line of eighth notes ("notes": MIDI numbers, HOLD keeps the note
## before sounding, REST is silence; "gate": how much of its last eighth a
## note sounds) or built from the chords ("chords": "pad" holds each bar's
## chord, "arp" plays its notes in "order" every "step" sixteenths); "shift"
## moves a part by semitones. "drums": a character per sixteenth, the same
## every bar, played on "kit" (timpani tune to the bar's chord); "reverb".
const HOLD := -2
const REST := -1
const _H := HOLD
const _R := REST

## The journey: unhurried, in D major. Flute over harp and strings, a plucked
## bass and a soft walking beat. Eight bars, about 24 seconds.
const CALM := {
	"bpm": 80,
	"chords": [[62, 66, 69], [61, 64, 69], [62, 66, 71], [62, 67, 71],
			[62, 66, 69], [62, 67, 71], [61, 64, 69], [62, 66, 69]],
	"parts": [
		{"inst": "flute", "vol": 0.3, "gate": 0.95, "notes": [
			66, _H, 69, _H, 74, _H, _H, 73,
			71, _H, 69, _H, _H, _H, 64, 66,
			66, _H, 71, _H, 74, _H, 73, 71,
			69, _H, _H, _H, 67, _H, 66, 64,
			66, _H, 69, _H, 74, _H, 76, 78,
			79, _H, 78, _H, 76, _H, 74, _H,
			76, _H, _H, _H, 73, _H, 71, 73,
			74, _H, _H, _H, _H, _H, _R, _R,
		]},
		{"inst": "bass", "vol": 0.5, "gate": 0.95, "notes": [
			50, _H, _H, _H, 45, _H, _H, _H,
			45, _H, _H, _H, 52, _H, _H, _H,
			47, _H, _H, _H, 54, _H, _H, _H,
			43, _H, _H, _H, 50, _H, _H, _H,
			50, _H, _H, _H, 45, _H, _H, _H,
			43, _H, _H, _H, 50, _H, _H, _H,
			45, _H, _H, _H, 49, _H, 52, _H,
			50, _H, _H, _H, _H, _H, 45, _H,
		]},
		{"inst": "strings", "vol": 0.07, "chords": "pad", "shift": -12},
		{"inst": "harp", "vol": 0.2, "chords": "arp", "step": 2, "order": [0, 1, 2, 1]},
	],
	"drums": "k.......k...h.h.",
	"kit": {"k": "kick", "h": "shaker"},
	"drum_vol": 0.35,
	"reverb": 0.3,
}
## The final stretch: the journey grown urgent, in A minor. Brass over driving
## strings, cellos and timpani.
const INTENSE := {
	"bpm": 126,
	"chords": [[57, 60, 64], [53, 57, 60], [55, 59, 62], [52, 56, 59]],
	"parts": [
		{"inst": "brass", "vol": 0.25, "gate": 0.85, "notes": [
			69, 72, 76, 72, 69, 72, 76, 81,
			77, 76, 72, 69, 72, 76, 77, 76,
			74, 71, 67, 71, 74, 79, 74, 71,
			76, 75, 76, 80, 83, 80, 76, _R,
		]},
		{"inst": "cello", "vol": 0.3, "gate": 0.7, "notes": [
			45, 57, 45, 57, 45, 57, 45, 57,
			41, 53, 41, 53, 41, 53, 41, 53,
			43, 55, 43, 55, 43, 55, 43, 55,
			40, 52, 40, 52, 40, 52, 44, 47,
		]},
		{"inst": "spiccato", "vol": 0.12, "chords": "arp", "step": 1, "order": [0, 1, 2, 1], "shift": 12},
		{"inst": "strings", "vol": 0.05, "chords": "pad"},
	],
	"drums": "t.h.s.h.k.khs.hk",
	"kit": {"t": "timpani", "k": "kick", "s": "snare", "h": "shaker"},
	"drum_vol": 0.7,
	"reverb": 0.22,
}
## The bonus round (card picks): bouncy and bright, in G major. Marimba over
## glockenspiel and pizzicato bass, with claps.
const BONUS := {
	"bpm": 138,
	"chords": [[67, 71, 74], [64, 67, 71], [60, 64, 67], [62, 66, 69]],
	"parts": [
		{"inst": "marimba", "vol": 0.4, "notes": [
			79, 78, 79, _R, 74, _R, 71, 74,
			76, _H, 74, 76, 79, _R, 76, _R,
			72, 74, 76, 79, 81, 79, 76, 74,
			78, _H, 81, _H, 78, 74, 76, 78,
		]},
		{"inst": "pizz", "vol": 0.45, "notes": [
			43, 55, 43, 55, 43, 55, 43, 55,
			40, 52, 40, 52, 40, 52, 40, 52,
			48, 60, 48, 60, 48, 60, 48, 60,
			50, 62, 50, 62, 50, 62, 45, 47,
		]},
		{"inst": "glock", "vol": 0.07, "chords": "arp", "step": 2, "order": [0, 1, 2, 1], "shift": 12},
	],
	"drums": "k.h.c.hkk.h.c.hh",
	"kit": {"k": "kick", "h": "shaker", "c": "clap"},
	"drum_vol": 0.5,
	"reverb": 0.2,
}
## Casino (Scrap Slots, Pick a Card, the Chance Wheel): a swinging lounge
## tune in F. Vibraphone over jazz piano chords and a walking bass, with
## brushes and a ride cymbal.
const CASINO := {
	"bpm": 112,
	"swing": 0.3,
	"chords": [[55, 58, 62, 65], [55, 58, 60, 64], [57, 60, 64, 65], [54, 57, 60, 62]],
	"parts": [
		{"inst": "vibes", "vol": 0.34, "notes": [
			74, 72, 70, _R, 69, 70, 72, _H,
			76, _H, 74, 72, 70, _H, 67, _R,
			69, 72, 76, _H, 77, 76, 72, 69,
			78, _H, 74, _H, 72, 69, 66, _R,
		]},
		{"inst": "bass", "vol": 0.5, "gate": 0.8, "notes": [
			43, _H, 46, _H, 50, _H, 49, _H,
			48, _H, 52, _H, 55, _H, 54, _H,
			53, _H, 48, _H, 45, _H, 47, _H,
			50, _H, 54, _H, 57, _H, 44, _H,
		]},
		{"inst": "piano", "vol": 0.1, "chords": "comp", "hits": [0, 6, 10]},
	],
	"drums": ["r...r.r.r...r.r.", "k.......k.......", "....b.......b..."],
	"kit": {"r": "ride", "k": "kick", "b": "brush"},
	"drum_vol": 0.45,
	"reverb": 0.28,
}
## Critter Race: an exciting gallop in D. Brass and flute over racing
## strings and an oom-pah bass, with a snare that keeps the critters running.
const RACE := {
	"bpm": 152,
	"chords": [[62, 66, 69], [57, 61, 64], [59, 62, 66], [55, 59, 62],
			[62, 66, 69], [57, 61, 64], [57, 61, 64, 67], [62, 66, 69]],
	"parts": [
		{"inst": "brass", "vol": 0.24, "gate": 0.75, "notes": [
			74, 76, 78, 74, 81, _H, 78, _R,
			76, 78, 79, 76, 81, _H, 76, _R,
			74, 76, 78, 81, 83, 81, 78, 74,
			79, _H, 78, _H, 76, _H, 74, 76,
			74, 76, 78, 74, 81, _H, 78, _R,
			76, 78, 79, 81, 83, 85, 86, _R,
			83, 81, 79, 78, 76, 74, 73, 76,
			74, _H, 81, _H, 74, _R, _R, _R,
		]},
		{"inst": "flute", "vol": 0.12, "gate": 0.7, "notes": [
			74, 76, 78, 74, 81, _H, 78, _R,
			76, 78, 79, 76, 81, _H, 76, _R,
			74, 76, 78, 81, 83, 81, 78, 74,
			79, _H, 78, _H, 76, _H, 74, 76,
			74, 76, 78, 74, 81, _H, 78, _R,
			76, 78, 79, 81, 83, 85, 86, _R,
			83, 81, 79, 78, 76, 74, 73, 76,
			74, _H, 81, _H, 74, _R, _R, _R,
		]},
		{"inst": "pizz", "vol": 0.45, "notes": [
			50, 57, 50, 57, 50, 57, 50, 57,
			45, 52, 45, 52, 45, 52, 45, 52,
			47, 54, 47, 54, 47, 54, 47, 54,
			43, 50, 43, 50, 43, 50, 43, 50,
			50, 57, 50, 57, 50, 57, 50, 57,
			45, 52, 45, 52, 45, 52, 45, 52,
			45, 52, 45, 52, 45, 49, 52, 55,
			50, 45, 50, _R, 50, _R, _R, _R,
		]},
		{"inst": "spiccato", "vol": 0.1, "chords": "arp", "step": 1, "order": [0, 1, 2, 1], "shift": 12},
	],
	"drums": ["k...k...k...k...", "..s...s...s...ss", "h.h.h.h.h.h.h.h."],
	"kit": {"k": "kick", "s": "snare", "h": "shaker"},
	"drum_vol": 0.6,
	"reverb": 0.2,
}

## Set by the game; switching crossfades between the loops.
var intense := false:
	set(v):
		if v != intense:
			intense = v
			_switch()
## During a minigame, "casino" or "race" (else ""): its loop, over the calm
## or intense one.
var minigame := "":
	set(v):
		if v != minigame:
			minigame = v
			_switch()
## While a card is being picked: the bonus loop, over any of the others.
var bonus := false:
	set(v):
		if v != bonus:
			bonus = v
			_switch()

var _calm: AudioStreamPlayer
var _intense: AudioStreamPlayer
var _bonus: AudioStreamPlayer
var _casino: AudioStreamPlayer
var _race: AudioStreamPlayer
var _fanfare: AudioStreamPlayer
var _tasks: Array[int] = []
var _calm_wav: AudioStreamWAV  # each set by its own render task
var _intense_wav: AudioStreamWAV
var _bonus_wav: AudioStreamWAV
var _casino_wav: AudioStreamWAV
var _race_wav: AudioStreamWAV
var _payday_wav: AudioStreamWAV
var _fanfares: Array[AudioStreamWAV] = []  # by building count, from 1
var _fade: Tween


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	_calm = _player()
	_intense = _player()
	_bonus = _player()
	_casino = _player()
	_race = _player()
	_fanfare = _player()
	_fanfare.volume_db = VOLUME_DB + 2.0
	_fanfare.finished.connect(_unduck)
	_tasks.append(WorkerThreadPool.add_task(func(): _calm_wav = song_clip("calm", CALM)))
	_tasks.append(WorkerThreadPool.add_task(func(): _intense_wav = song_clip("intense", INTENSE)))
	_tasks.append(WorkerThreadPool.add_task(func(): _casino_wav = song_clip("casino", CASINO)))
	_tasks.append(WorkerThreadPool.add_task(func(): _race_wav = song_clip("race", RACE)))
	_tasks.append(WorkerThreadPool.add_task(func(): _bonus_wav = song_clip("bonus", BONUS)))
	_tasks.append(WorkerThreadPool.add_task(func():
		_payday_wav = cached("payday", "", render_payday, false)))
	_tasks.append(WorkerThreadPool.add_task(func():
		var all: Array[AudioStreamWAV] = []
		for n in range(1, FANFARE_MAX + 1):
			all.append(cached("fanfare%d" % n, "", render_fanfare.bind(n), false))
		_fanfares = all))


func _process(_delta: float) -> void:
	for t in _tasks.duplicate():
		if WorkerThreadPool.is_task_completed(t):
			WorkerThreadPool.wait_for_task_completion(t)
			_tasks.erase(t)
			_calm.stream = _calm_wav
			_intense.stream = _intense_wav
			_bonus.stream = _bonus_wav
			_casino.stream = _casino_wav
			_race.stream = _race_wav
			if not _current().playing and _current().stream != null:
				_current().volume_db = VOLUME_DB
				_current().play()


func _exit_tree() -> void:
	for t in _tasks:
		WorkerThreadPool.wait_for_task_completion(t)


func _player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = Settings.BUSES.music
	p.volume_db = SILENT_DB
	add_child(p)
	return p


func _current() -> AudioStreamPlayer:
	if bonus:
		return _bonus
	if minigame == "casino":
		return _casino
	if minigame == "race":
		return _race
	return _intense if intense else _calm


## Plays the whole-block fanfare for a block of `buildings` lots.
func fanfare(buildings: int) -> void:
	if not _fanfares.is_empty():  # else still rendering
		_stinger(_fanfares[clampi(buildings, 1, FANFARE_MAX) - 1])


## The PAYDAY trumpets.
func payday() -> void:
	_stinger(_payday_wav)


## Plays a one-off over the music, dipped underneath until it ends.
func _stinger(wav: AudioStreamWAV) -> void:
	if wav == null:
		return
	_fanfare.stream = wav
	_fanfare.play()
	if _fade:
		_fade.kill()
	_current().volume_db = VOLUME_DB - DUCK_DB


func _unduck() -> void:
	if _current().playing:
		create_tween().tween_property(_current(), "volume_db", VOLUME_DB, 0.6)


## Fades whichever loop is playing out and the one wanted now in, from its start.
func _switch() -> void:
	var to := _current()
	if _fade:
		_fade.kill()
	var others: Array[AudioStreamPlayer] = []
	for p in [_calm, _intense, _bonus, _casino, _race]:
		if p != to and p.playing:
			others.append(p)
	if to.stream == null:
		for p in others:
			p.stop()
		return  # still rendering: it starts by itself once ready
	to.volume_db = SILENT_DB
	to.play()
	_fade = create_tween().set_parallel()
	_fade.tween_property(to, "volume_db", VOLUME_DB, FADE * 0.5)
	for p in others:
		_fade.tween_property(p, "volume_db", SILENT_DB, FADE * 0.6)
	_fade.chain().tween_callback(func():
		for p in others:
			p.stop())


# --- rendering ------------------------------------------------------------

## A song as a looping clip, from the cache when it has this version of it.
static func song_clip(name: String, song: Dictionary) -> AudioStreamWAV:
	return cached(name, str(hash(var_to_str(song))), render_song.bind(song), true)


## The clip `name` from the cache, or made by `make` (returning samples) and
## stored. `key` tells versions of the same clip apart.
static func cached(name: String, key: String, make: Callable, loop: bool) -> AudioStreamWAV:
	var path := "%s/%s_v%d_%s.pcm" % [CACHE_DIR, name, SOUND_VERSION, key]
	if FileAccess.file_exists(path):
		var stored := FileAccess.get_file_as_bytes(path)
		if not stored.is_empty():
			return _wav(stored, loop)
	var data := _pcm(make.call())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_buffer(data)
	return _wav(data, loop)


## Renders a song for tests and previews (no cache).
static func render(song: Dictionary) -> AudioStreamWAV:
	return _wav(_pcm(render_song(song)), true)


## One pass of `song`; what rings on past the end is folded back over the
## start, so it loops seamlessly.
static func render_song(song: Dictionary) -> PackedFloat32Array:
	var sixteenth: float = 60.0 / song.bpm / 4.0
	var eighth := sixteenth * 2.0
	var bars: int = song.chords.size()
	var total := int(bars * 16 * sixteenth * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total + int(TAIL * RATE))
	# Swing: every offbeat eighth comes `swing` of an eighth late.
	var swing: float = song.get("swing", 0.0)
	var at := func(sixteenths: int) -> float:
		return sixteenths * sixteenth + (swing * eighth if sixteenths % 4 == 2 else 0.0)
	for part in song.parts:
		var shift: int = part.get("shift", 0)
		var vol: float = part.vol
		if part.has("notes"):
			var notes: Array = part.notes
			var gate: float = part.get("gate", 0.9)
			for i in notes.size():
				if notes[i] < 0:
					continue
				var held := 1
				while i + held < notes.size() and notes[i + held] == HOLD:
					held += 1
				_note(buf, part.inst, at.call(i * 2), (held - 1 + gate) * eighth, notes[i] + shift, vol)
			continue
		for bar in bars:
			var chord: Array = song.chords[bar]
			match part.chords:
				"pad":
					for note in chord:
						_note(buf, part.inst, at.call(bar * 16), 16 * sixteenth, note + shift, vol)
				"comp":  # the whole chord on the given sixteenths
					for s in part.hits:
						for note in chord:
							_note(buf, part.inst, at.call(bar * 16 + s), 3 * sixteenth, note + shift, vol)
				_:
					var step: int = part.step
					var order: Array = part.get("order", [0, 1, 2])
					var k := 0
					for s in range(0, 16, step):
						var note: int = chord[int(order[k % order.size()]) % chord.size()]
						_note(buf, part.inst, at.call(bar * 16 + s), step * sixteenth * 0.9, note + shift, vol)
						k += 1
	# Drums: one pattern, or several layered; a character per sixteenth.
	var layers = song.get("drums", "")
	if layers is String:
		layers = [layers]
	var kit: Dictionary = song.get("kit", {})
	var dv: float = song.get("drum_vol", 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for bar in bars:
		for pattern in layers:
			for s in pattern.length():
				var hit: String = kit.get(pattern[s], "")
				if hit != "":
					_drum(buf, hit, at.call(bar * 16 + s), dv, rng, song.chords[bar][0] - 12)
	_reverb(buf, song.get("reverb", 0.25))
	for i in buf.size() - total:
		buf[i] += buf[total + i]
	buf.resize(total)
	_normalise(buf)
	return buf


## PAYDAY: a trumpet fanfare. Three quick pickup notes, a big C, a run up to
## G, and a held C major chord with strings, a glockenspiel trill on top,
## timpani, a snare roll and a cymbal crash.
static func render_payday() -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int((2.6 + TAIL) * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	# [start, length, notes]: the trumpets, in parts.
	var parts := [
		[0.0, 0.08, [67, 64]], [0.1, 0.08, [67, 64]], [0.2, 0.08, [67, 64]],
		[0.3, 0.3, [72, 67, 64]],
		[0.64, 0.05, [72, 67]], [0.7, 0.05, [74, 69]], [0.76, 0.05, [76, 72]],
		[0.82, 0.05, [77, 74]], [0.88, 0.2, [79, 76, 71]],
		[1.12, 1.3, [84, 79, 76, 72, 67]],
	]
	for e in parts:
		for note in e[2]:
			_brass(buf, e[0], e[1], note, 0.2)
	for note in [48, 55, 64]:
		_bowed(buf, 1.12, 1.3, note, 0.12, 0.08, 0.6, 1800.0, 0.08)
	for k in 8:
		_struck(buf, 1.4 + k * 0.08, 96 if k % 2 == 0 else 98, 0.12, GLOCK)
	for e in [[0.3, 43], [0.88, 43], [1.12, 36]]:
		_drum(buf, "timpani", e[0], 0.9, rng, e[1])
	var roll := 0.6
	while roll < 1.1:
		_drum(buf, "snare", roll, lerpf(0.15, 0.5, (roll - 0.6) / 0.5), rng, 0)
		roll += 0.04
	_drum(buf, "cymbal", 1.12, 0.6, rng, 0)
	_reverb(buf, 0.3)
	_normalise(buf)
	return buf


## The whole-block fanfare for `n` buildings (see FANFARE_*).
static func render_fanfare(n: int) -> PackedFloat32Array:
	var hold := 1.3
	var end := FANFARE_LEAD_IN + n * FANFARE_STEP
	var buf := PackedFloat32Array()
	buf.resize(int((end + hold + TAIL) * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var roll := 0.0
	while roll < FANFARE_LEAD_IN - 0.02:  # a snare roll, getting louder
		_drum(buf, "snare", roll, lerpf(0.12, 0.45, roll / FANFARE_LEAD_IN), rng, 0)
		roll += 0.045
	for i in n:
		var at := FANFARE_LEAD_IN + i * FANFARE_STEP
		var note: int = FANFARE_NOTES[mini(i, FANFARE_NOTES.size() - 2)]
		_brass(buf, at, FANFARE_STEP * 0.85, note, 0.28)
		_brass(buf, at, FANFARE_STEP * 0.85, note - 12, 0.18)
		_struck(buf, at, note + 12, 0.25, GLOCK)
		_drum(buf, "timpani", at, 0.7, rng, 43 if i % 2 == 0 else 48)
	# The landing: brass and strings on a big major chord, bells, timpani, cymbal.
	for note in [72, 76, 79, 84]:
		_brass(buf, end, hold, note, 0.17)
	for note in [48, 60, 64, 67]:
		_bowed(buf, end, hold, note, 0.1, 0.05, 0.6, 2000.0, 0.08)
	_struck(buf, end, 84, 0.3, BELL)
	_drum(buf, "timpani", end, 1.0, rng, 36)
	_drum(buf, "cymbal", end, 0.6, rng, 0)
	_reverb(buf, 0.3)
	_normalise(buf)
	return buf


# --- instruments ------------------------------------------------------------

static func _hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


## One note on `inst` from `at` seconds, sounding for `length` (struck and
## plucked instruments ring on as they would).
static func _note(buf: PackedFloat32Array, inst: String, at: float, length: float, note: int,
		vol: float) -> void:
	match inst:
		"harp":
			_pluck(buf, at, 1.6, note, vol, 0.55, 0.997)
		"pizz":
			_pluck(buf, at, 0.45, note, vol, 0.3, 0.99)
		"bass":
			_pluck(buf, at, length + 0.4, note, vol, 0.25, 0.996)
		"strings":
			_bowed(buf, at, length, note, vol, 0.3, 0.5, 1500.0, 0.08)
		"cello":
			_bowed(buf, at, length, note, vol, 0.015, 0.08, 900.0, 0.05)
		"spiccato":
			_bowed(buf, at, length * 0.6, note, vol, 0.006, 0.05, 2400.0, 0.0)
		"brass":
			_brass(buf, at, length, note, vol)
		"flute":
			_wind(buf, at, length, note, vol, false)
		"clarinet":
			_wind(buf, at, length, note, vol, true)
		"marimba":
			_struck(buf, at, note, vol, MARIMBA)
		"glock":
			_struck(buf, at, note, vol, GLOCK)
		"bell":
			_struck(buf, at, note, vol, BELL)
		"vibes":
			_struck(buf, at, note, vol, VIBES, 0.0, 0.25)
		"piano":
			_struck(buf, at, note, vol, PIANO)


## A plucked string (Karplus-Strong): a burst of noise, `bright` how much of
## its top end is kept, circulating in a delay line one period long and
## losing a little (`damp`) each time round; tuned by an allpass.
static func _pluck(buf: PackedFloat32Array, at: float, dur: float, note: int, vol: float,
		bright: float, damp: float) -> void:
	var delay := RATE / _hz(note) - 0.5
	var n := int(delay)
	var d := delay - n
	if d < 0.1:
		n -= 1
		d += 1.0
	var c := (1.0 - d) / (1.0 + d)
	var line := PackedFloat32Array()
	line.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = note * 977 + int(at * 1000.0)
	var smooth := 0.0
	for i in n:
		smooth = lerpf(smooth, rng.randf_range(-1.0, 1.0), bright)
		line[i] = smooth
	var start := int(at * RATE)
	var total := int(dur * RATE)
	var fade := int(0.05 * RATE)
	var prev := 0.0
	var ap_x := 0.0
	var ap_y := 0.0
	for i in total:
		var j := start + i
		if j >= buf.size():
			return
		var k := i % n
		var cur := line[k]
		var avg := 0.5 * (cur + prev) * damp
		prev = cur
		var y := c * avg + ap_x - c * ap_y
		ap_x = avg
		ap_y = y
		line[k] = y
		var env := 1.0 if i < total - fade else float(total - i) / fade
		buf[j] += cur * vol * env


## Bowed strings: three slightly detuned sawtooths through a two-pole
## low-pass at `cutoff`, swelling in over `attack` and away over `release`.
static func _bowed(buf: PackedFloat32Array, at: float, length: float, note: int, vol: float,
		attack: float, release: float, cutoff: float, vibrato: float) -> void:
	var freq := _hz(note) / RATE
	var start := int(at * RATE)
	var n := int((length + release) * RATE)
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var up := pow(2.0, 5.0 / 1200.0)
	var down := pow(2.0, -6.0 / 1200.0)
	var p1 := 0.0
	var p2 := 0.37
	var p3 := 0.71
	var lp1 := 0.0
	var lp2 := 0.0
	for i in n:
		var j := start + i
		if j >= buf.size():
			return
		var t := float(i) / RATE
		var f := freq * (1.0 + vibrato * 0.0578 * minf(1.0, t / 0.4) * sin(t * 5.2 * TAU))
		p1 = fmod(p1 + f, 1.0)
		p2 = fmod(p2 + f * up, 1.0)
		p3 = fmod(p3 + f * down, 1.0)
		var x := (p1 + p2 + p3) * (2.0 / 3.0) - 1.0
		lp1 += a * (x - lp1)
		lp2 += a * (lp1 - lp2)
		var env := minf(1.0, t / attack)
		if t > length:
			env *= maxf(0.0, 1.0 - (t - length) / release)
		buf[j] += lp2 * env * vol


## Brass: two sawtooths whose tone opens up as the note speaks (the filter
## sweeps up, then settles), lipping up into the pitch.
static func _brass(buf: PackedFloat32Array, at: float, length: float, note: int, vol: float) -> void:
	var freq := _hz(note) / RATE
	var start := int(at * RATE)
	var release := 0.08
	var n := int((length + release) * RATE)
	var p1 := 0.0
	var p2 := 0.5
	var lp1 := 0.0
	var lp2 := 0.0
	var a := 0.0
	for i in n:
		var j := start + i
		if j >= buf.size():
			return
		var t := float(i) / RATE
		if i % 16 == 0:
			var cutoff := lerpf(350.0, 3200.0, minf(1.0, t / 0.06)) \
					- 900.0 * clampf((t - 0.1) / 0.3, 0.0, 1.0)
			a = 1.0 - exp(-TAU * cutoff / RATE)
		var scoop := 1.0 - 0.035 * maxf(0.0, 1.0 - t / 0.035)
		var vib := 1.0 + 0.004 * clampf((t - 0.25) / 0.3, 0.0, 1.0) * sin(t * 5.5 * TAU)
		var f := freq * scoop * vib
		p1 = fmod(p1 + f, 1.0)
		p2 = fmod(p2 + f * 1.003, 1.0)
		var x := p1 + p2 - 1.0
		lp1 += a * (x - lp1)
		lp2 += a * (lp1 - lp2)
		var env := minf(1.0, t / 0.02) * (0.85 + 0.15 * exp(-t * 6.0))
		if t > length:
			env *= maxf(0.0, 1.0 - (t - length) / release)
		buf[j] += lp2 * env * vol


## Flute (`reedy` false: a near-pure tone with breath and a soft chiff) or
## clarinet (`reedy`: odd harmonics, a quicker start).
static func _wind(buf: PackedFloat32Array, at: float, length: float, note: int, vol: float,
		reedy: bool) -> void:
	var freq := _hz(note) / RATE
	var start := int(at * RATE)
	var attack := 0.025 if reedy else 0.07
	var release := 0.06 if reedy else 0.1
	var n := int((length + release) * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = note * 131 + int(at * 1000.0)
	var phase := 0.0
	var breath := 0.0
	for i in n:
		var j := start + i
		if j >= buf.size():
			return
		var t := float(i) / RATE
		var vib := 1.0 + 0.006 * clampf((t - 0.2) / 0.4, 0.0, 1.0) * sin(t * 5.0 * TAU)
		phase = fmod(phase + freq * vib, 1.0)
		var w := phase * TAU
		var s := 0.0
		if reedy:
			s = sin(w) + 0.45 * sin(3.0 * w) + 0.22 * sin(5.0 * w) + 0.1 * sin(7.0 * w)
			s *= 0.6
		else:
			s = sin(w) + 0.22 * sin(2.0 * w) + 0.06 * sin(3.0 * w)
		breath += 0.15 * (rng.randf_range(-1.0, 1.0) - breath)
		var air := (0.05 if reedy else 0.1) * (1.0 - 0.6 * minf(1.0, t / 0.2))
		var env := minf(1.0, t / attack)
		if t > length:
			env *= maxf(0.0, 1.0 - (t - length) / release)
		buf[j] += (s * 0.8 + breath * air * 3.0) * env * vol


## A struck bar or bell: sine partials, each dying away at its own rate.
## `glide`: semitones the pitch starts away from the note, springing to it.
## `tremolo`: how deep a vibraphone's 5 Hz pulse is.
static func _struck(buf: PackedFloat32Array, at: float, note: float, vol: float, partials: Array,
		glide := 0.0, tremolo := 0.0) -> void:
	var freq := _hz(note)
	var slowest := 100.0
	for p in partials:
		slowest = minf(slowest, p[2])
	var n := int(minf(3.0, 5.0 / slowest) * RATE)
	var start := int(at * RATE)
	for p in partials:
		var f: float = freq * p[0]
		if f > RATE * 0.45:
			continue
		var env: float = p[1] * vol
		var fall := exp(-float(p[2]) / RATE)
		var phase := 0.0
		for i in n:
			var j := start + i
			if j >= buf.size():
				break
			var g := 1.0
			if glide != 0.0:
				g = pow(2.0, glide * exp(-float(i) / RATE * 60.0) / 12.0)
			phase += f * g / RATE
			var click := minf(1.0, i / 40.0)
			if tremolo > 0.0:
				click *= 1.0 - tremolo * (0.5 + 0.5 * sin(float(i) / RATE * 5.0 * TAU))
			buf[j] += sin(phase * TAU) * env * click
			env *= fall


## Percussion. `tune`: the timpani's note.
static func _drum(buf: PackedFloat32Array, kind: String, at: float, vol: float,
		rng: RandomNumberGenerator, tune: int) -> void:
	var start := int(at * RATE)
	var dur: float = {"kick": 0.35, "timpani": 1.2, "snare": 0.25, "clap": 0.2, "shaker": 0.12,
			"woodblock": 0.12, "cymbal": 2.0, "ride": 0.9, "brush": 0.3}.get(kind, 0.2)
	var phase := 0.0
	var phase2 := 0.0
	var lp := 0.0
	var lp2 := 0.0
	var tf := _hz(tune) if kind == "timpani" else 0.0
	for i in int(dur * RATE):
		var j := start + i
		if j >= buf.size():
			return
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		var v := 0.0
		match kind:
			"kick":
				phase += lerpf(120.0, 48.0, minf(1.0, t / 0.1)) / RATE
				v = sin(phase * TAU) * exp(-t * 14.0) * 0.9 + (x * 0.3 if t < 0.003 else 0.0)
			"timpani":
				var drop := 1.0 + 0.04 * exp(-t * 20.0)
				phase += tf * drop / RATE
				phase2 += tf * 1.5 * drop / RATE
				lp += 0.1 * (x - lp)
				v = (sin(phase * TAU) * exp(-t * 3.5) + 0.4 * sin(phase2 * TAU) * exp(-t * 5.0)) * 0.8 \
						+ lp * exp(-t * 30.0) * 1.5
			"snare":
				lp += 0.25 * (x - lp)
				phase += 185.0 / RATE
				v = (x - lp) * exp(-t * 16.0) * 0.7 + sin(phase * TAU) * exp(-t * 30.0) * 0.4
			"clap":
				lp += 0.3 * (x - lp)
				var burst := 0.0
				for b in [0.0, 0.011, 0.022]:
					if t >= b:
						burst += exp(-(t - b) * 180.0)
				v = (x - lp) * (burst * 0.5 + exp(-t * 25.0) * 0.5) * 0.8
			"shaker":
				lp += 0.45 * (x - lp)
				v = (x - lp) * minf(1.0, t / 0.012) * exp(-t * 35.0) * 0.4
			"woodblock":
				phase += 880.0 / RATE
				phase2 += 1430.0 / RATE
				v = (sin(phase * TAU) + 0.4 * sin(phase2 * TAU)) * exp(-t * 40.0) * 0.6 \
						+ (x * 0.4 if t < 0.002 else 0.0)
			"cymbal":
				lp += 0.6 * (x - lp)
				lp2 += 0.05 * ((x - lp) - lp2)
				v = ((x - lp) - lp2) * exp(-t * 2.2) * 0.45
			"ride":  # a jazz ride: a ping of bell over a soft wash
				lp += 0.6 * (x - lp)
				phase += 3150.0 / RATE
				phase2 += 4470.0 / RATE
				v = (x - lp) * exp(-t * 5.0) * 0.18 \
						+ (sin(phase * TAU) + 0.6 * sin(phase2 * TAU)) * exp(-t * 9.0) * 0.08
			"brush":  # a brush swept across the snare
				lp += 0.2 * (x - lp)
				v = lp * minf(1.0, t / 0.02) * exp(-t * 12.0) * 0.6
		buf[j] += v * vol


## A small room: four feedback combs (damped) and two allpasses, mixed in.
static func _reverb(buf: PackedFloat32Array, wet: float) -> void:
	if wet <= 0.0:
		return
	var out := PackedFloat32Array()
	out.resize(buf.size())
	for d in [557, 593, 641, 677]:
		var line := PackedFloat32Array()
		line.resize(d)
		var k := 0
		var store := 0.0
		for i in buf.size():
			var y := line[k]
			store = y * 0.7 + store * 0.3
			line[k] = buf[i] + store * 0.82
			out[i] += y
			k += 1
			if k == d:
				k = 0
	for d in [225, 172]:
		var line := PackedFloat32Array()
		line.resize(d)
		var k := 0
		for i in out.size():
			var held := line[k]
			var y := held - 0.5 * out[i]
			line[k] = out[i] + 0.5 * y
			out[i] = y
			k += 1
			if k == d:
				k = 0
	for i in buf.size():
		buf[i] += out[i] * wet * 0.25


static func _normalise(buf: PackedFloat32Array) -> void:
	var top := 0.0
	for v in buf:
		top = maxf(top, absf(v))
	if top > 0.0:
		var k := PEAK / top
		for i in buf.size():
			buf[i] *= k


static func _pcm(buf: PackedFloat32Array) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, clampi(int(buf[i] * 32767.0), -32768, 32767))
	return data


static func _wav(data: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = data.size() / 2
	return wav


## Samples as a clip (Sfx, previews).
static func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	return _wav(_pcm(buf), loop)
