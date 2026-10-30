class_name Settings
extends RefCounted
## The player's options, kept in user://settings.cfg and changed from the
## Escape menu: music and sound effects each switched on or off and set to a
## volume (0-100), and whether the camera always shows the whole board
## (zoomed_out). Music plays on the "Music" audio bus and effects on "SFX"
## (Music, Sfx), so the sound options are just those buses' volume and mute.

const PATH := "user://settings.cfg"
const BUSES := {"music": "Music", "sfx": "SFX"}
const DEFAULTS := {"music_on": true, "music_volume": 100, "sfx_on": true, "sfx_volume": 100,
		"zoomed_out": false}

static var values := {}


## Makes the Music and SFX buses (before any player is created on them),
## loads the saved options and applies them.
static func start() -> void:
	for name in BUSES.values():
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, "Master")
	values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for key in DEFAULTS:
			values[key] = cfg.get_value("options", key, cfg.get_value("sound", key, DEFAULTS[key]))
	apply()


static func get_value(key: String):
	return values.get(key, DEFAULTS[key])


## Changes one option, applies it and saves.
static func set_value(key: String, value) -> void:
	values[key] = value
	apply()
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("options", k, values[k])
	cfg.save(PATH)


static func apply() -> void:
	for kind in BUSES:
		var bus := AudioServer.get_bus_index(BUSES[kind])
		var volume: float = get_value(kind + "_volume") / 100.0
		AudioServer.set_bus_mute(bus, not get_value(kind + "_on") or volume <= 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)))
