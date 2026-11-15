class_name MusicPlayer
extends AudioStreamPlayer
## The background music: one looping track that keeps playing while levels change (it lives under the root node, not under the level, so
## reloading a level does not restart it). Main starts it with MusicPlayer.ensure_playing(). Set the environment variable
## SABOTAGE_NO_MUSIC=1 to play without it. There is no music in a headless run (the automated tests).

# TRACK: the music file. It is copyright-free music ("The Mountain" by the_mountain on Pixabay, retro game style; see assets/audio/CREDITS.md).
const TRACK := "res://assets/audio/music/the_mountain_retro_game.mp3"

# VOLUME_DB: how loud the music is (0 = the file as it is, lower = quieter). Keep it under the sound effects, if the game gets any.
const VOLUME_DB := -12.0


## Make sure the music is playing: starts it the first time and does nothing after that.
static func ensure_playing(tree: SceneTree) -> void:
	if OS.get_environment("SABOTAGE_NO_MUSIC") != "" or DisplayServer.get_name() == "headless" or tree.root.has_node("Music"):
		return
	var player := MusicPlayer.new()
	player.name = "Music"
	tree.root.add_child.call_deferred(player)


func _ready() -> void:
	var stream := load(TRACK) as AudioStreamMP3
	if stream == null:
		return
	stream.loop = true
	self.stream = stream
	volume_db = VOLUME_DB
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps playing while a puzzle or the pause menu stops the game
	play()
