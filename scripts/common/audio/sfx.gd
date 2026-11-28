class_name Sfx
extends RefCounted
## One-shot sound effects (assets/audio/sfx/<feature>/), played on the SFX bus so the sound-effects volume setting reaches them. A name is the file's path inside
## assets/audio/sfx/. The click and confirm sounds are made by tools/art/generate_sfx.py, the others are recordings (see assets/audio/CREDITS.md).
## A sound that has several takes is an array: play_any() picks one at random, so a repeated sound (a footstep, a laser) does not sound the same every time.
## There is no sound in a headless run (the automated tests).
##
##   Sfx.play(get_tree(), Sfx.CLICK)
##   Sfx.play_any(get_tree(), Sfx.LASER, -6.0)

const CLICK := &"ui/click.wav"                  # a button is pressed
const CONFIRM := &"ui/confirm.wav"              # the game is starting
const DOOR_OPEN := &"door/open.ogg"             # a door slides open
const DOOR_CLOSE := &"door/close.ogg"           # a door slides shut
const MECH_BOOSTER := &"mech/booster.wav"       # the mech's rocket booster (a loop, see SfxLoop)
const MISSILE_LAUNCH := &"weapons/missile_launch.ogg"          # a missile leaves the turret



# ALL: every sound above, so they can be read in advance (warm_up_jobs()).
const ALL: Array[StringName] = [CLICK, CONFIRM, DOOR_OPEN, DOOR_CLOSE, MECH_BOOSTER, MISSILE_LAUNCH]

static var _streams := {}       # name -> its stream, kept: a stream that nothing holds would be read from the file again at the next play


## The sound `sfx_name` (one of the names above) as a stream (read once, then kept).
static func stream(sfx_name: StringName) -> AudioStream:
	if not _streams.has(sfx_name):
		_streams[sfx_name] = load(AssetPaths.SFX + String(sfx_name)) as AudioStream
	return _streams[sfx_name]


## Jobs for WarmUp that read every sound now, so the first time one is played it does not wait for the disk.
static func warm_up_jobs() -> Array[Callable]:
	var jobs: Array[Callable] = []
	for sfx_name in ALL:
		jobs.append(func() -> void: stream(sfx_name))
	return jobs


## Play the effect `sfx_name` once, `volume_db` decibels louder (negative: quieter) than the file.
static func play(tree: SceneTree, sfx_name: StringName, volume_db: float = 0.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	AudioBuses.ensure()
	var player := AudioStreamPlayer.new()
	player.stream = stream(sfx_name)
	player.volume_db = volume_db
	player.bus = AudioBuses.SFX
	player.process_mode = Node.PROCESS_MODE_ALWAYS        # (a dialog that pauses the game still clicks)
	player.finished.connect(player.queue_free)
	tree.root.add_child(player)
	player.play()


## Play one of the takes in `names` (picked at random), once. An empty array plays nothing.
static func play_any(tree: SceneTree, names: Array[StringName], volume_db: float = 0.0) -> void:
	if not names.is_empty():
		play(tree, names[randi() % names.size()], volume_db)
