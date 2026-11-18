class_name MusicPlayer
extends AudioStreamPlayer
## The background music: one looping track that keeps playing while levels change (it lives under the root node, not under the level, so
## reloading a level does not restart it). Main starts it with MusicPlayer.ensure_playing(). Set the environment variable
## SABOTAGE_NO_MUSIC=1 to play without it. There is no music in a headless run (the automated tests).

# TRACK: the music file. It is copyright-free music ("The Mountain" by the_mountain on Pixabay, retro game style; see assets/audio/CREDITS.md).
const TRACK := "res://assets/audio/music/the_mountain_retro_game.mp3"

# VOLUME_DB: how loud the music is (0 = the file as it is, lower = quieter). Keep it under the sound effects, if the game gets any.
const VOLUME_DB := -12.0

# BOSS_TRACK: the music of the boss stage ("Video Game Boss Fight" by ihatetuesdays on Pixabay; see assets/audio/CREDITS.md).
const BOSS_TRACK := "res://assets/audio/music/ihatetuesdays_boss_fight.mp3"

var track := TRACK


## Make sure the music is playing: starts it the first time and does nothing after that. `music_file` is the track to play (the
## game's own by default); the boss stage passes BOSS_TRACK.
static func ensure_playing(tree: SceneTree, music_file: String = TRACK) -> void:
	if OS.get_environment("SABOTAGE_NO_MUSIC") != "" or DisplayServer.get_name() == "headless":
		return
	if tree.root.has_node("Music"):
		var current := tree.root.get_node("Music") as MusicPlayer
		if current != null and current.track != music_file:
			current.track = music_file     # (a boss level has its own track; the next level switches back)
			current._start()
		return
	var player := MusicPlayer.new()
	player.name = "Music"
	player.track = music_file
	tree.root.add_child.call_deferred(player)


func _ready() -> void:
	_start()


func _start() -> void:
	var stream := load(track) as AudioStreamMP3
	if stream == null:
		return
	stream.loop = true
	self.stream = stream
	volume_db = VOLUME_DB
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps playing while a puzzle or the pause menu stops the game
	play()
