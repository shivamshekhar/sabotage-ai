class_name Sfx
extends RefCounted
## One-shot sound effects (assets/audio/sfx/; the click and confirm sounds are made by tools/art/generate_sfx.py, the door sounds are Kenney's, see assets/audio/CREDITS.md), played on the SFX bus so the sound-effects volume setting reaches them. There is no
## sound in a headless run (the automated tests).
##
##   Sfx.play(get_tree(), Sfx.CLICK)

const CLICK := &"ui_click.wav"            # a button is pressed
const CONFIRM := &"ui_confirm.wav"        # the game is starting
const DOOR_OPEN := &"door_open.ogg"       # a door slides open
const DOOR_CLOSE := &"door_close.ogg"     # a door slides shut


## Play the effect `sfx_name` (one of the file names above) once.
static func play(tree: SceneTree, sfx_name: StringName) -> void:
	if DisplayServer.get_name() == "headless":
		return
	AudioBuses.ensure()
	var player := AudioStreamPlayer.new()
	player.stream = load(AssetPaths.SFX + String(sfx_name)) as AudioStream
	player.bus = AudioBuses.SFX
	player.process_mode = Node.PROCESS_MODE_ALWAYS        # (a dialog that pauses the game still clicks)
	player.finished.connect(player.queue_free)
	tree.root.add_child(player)
	player.play()
