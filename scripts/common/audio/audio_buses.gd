class_name AudioBuses
extends RefCounted
## The game's two sound groups, as audio buses: MUSIC and SFX (sound effects), both feeding the master bus. Every music player and sound effect is played on one of them, so a
## volume setting reaches everything of its kind. The buses are made in code when they are first needed (there is no bus layout file).
##
##   AudioBuses.ensure()
##   AudioBuses.set_volume(AudioBuses.MUSIC, 0.5)      # half as loud

const MASTER := &"Master"
const MUSIC := &"Music"
const SFX := &"SFX"

# MUTE_DB: the volume (decibels) of a bus that is turned right down: far below hearing.
const MUTE_DB := -80.0

# RANGE_DB: how many decibels quieter than the files the bus is at the very lowest setting above silence (volume 0, which is muted, is below it). The volume goes in even steps of
# decibels, which is how loudness is heard: with the 10 blocks of the settings meter each block is RANGE_DB / 10 = 4 dB, a clear step. (A plain linear 0 to 1 gain is almost flat at
# the top: 100% to 50% is only 6 dB, which hardly sounds different.) Higher: a wider range and bigger steps.
const RANGE_DB := 40.0


## Make the MUSIC and SFX buses if they do not exist yet.
static func ensure() -> void:
	for bus_name: StringName in [MUSIC, SFX]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, MASTER)


## The decibels for a volume setting from 0 (silent) to 1 (as the files are): even steps of decibels between RANGE_DB below and 0.
static func volume_to_db(volume: float) -> float:
	if volume <= 0.0:
		return MUTE_DB
	return -RANGE_DB * (1.0 - clampf(volume, 0.0, 1.0))


## Set how loud a bus is: `volume` from 0 (silent) to 1 (as the files are), see volume_to_db().
static func set_volume(bus_name: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, volume <= 0.0)
	AudioServer.set_bus_volume_db(index, volume_to_db(volume))
