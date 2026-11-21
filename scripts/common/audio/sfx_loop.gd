class_name SfxLoop
extends AudioStreamPlayer
## A sound that goes on while something is on (a booster burning) and fades out when it stops. Add it under whatever makes the sound and call set_on() every step
## with whether that is on; it starts the sound when it turns on and fades it out when it turns off. The sound file must be set to loop (its import settings).
## There is no sound in a headless run (the automated tests).
##
##   var burn := SfxLoop.attach(self, Sfx.MECH_BOOSTER)
##   burn.set_on(thrusting)

# FADE_TIME: seconds the sound takes to fade out when it turns off (a loop cut off at once clicks). Higher: a slower tail.
const FADE_TIME := 0.15

var _on := false
var _fade: Tween


## Make a loop of `sfx_name` (see Sfx) as a child of `parent`. It is silent until set_on(true).
static func attach(parent: Node, sfx_name: StringName) -> SfxLoop:
	var loop := SfxLoop.new()
	loop.name = "Loop_%s" % String(sfx_name).get_file().get_basename()
	loop.stream = Sfx.stream(sfx_name)
	loop.bus = AudioBuses.SFX
	parent.add_child(loop)
	return loop


## True while the sound is meant to be on.
func is_on() -> bool:
	return _on


## Turn the sound on (it starts at once, at full volume) or off (it fades out).
func set_on(on: bool) -> void:
	if on == _on:
		return
	_on = on
	if _fade != null:
		_fade.kill()
	if on:
		volume_db = 0.0
		if DisplayServer.get_name() != "headless":
			AudioBuses.ensure()
			play()
		return
	_fade = create_tween()
	_fade.tween_property(self, "volume_db", AudioBuses.MUTE_DB, FADE_TIME)
	_fade.tween_callback(stop)
