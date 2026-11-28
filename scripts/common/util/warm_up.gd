class_name WarmUp
extends Node
## Does a list of jobs a few at a time, frame after frame, so that nothing which has to be ready soon (a picture that is made when it is first needed, an effect that is drawn for the
## first time, a sound that is read from the disk) makes the game stop for a moment when it is first needed: the work is done early, in small pieces, while nothing else is going on.
## It removes itself when the last job is done.
##
##   WarmUp.run(self, [func() -> void: OutfitComposer.texture(outfit, "jump"), func() -> void: Sfx.stream(Sfx.CLICK)])

# BUDGET_MS: the time (ms) a frame may spend on jobs: it starts jobs until this much is used (at least one a frame, so a slow job still gets done). Higher: the work is finished
# sooner, but a frame in which jobs run may be longer; lower: smoother, but it takes more frames.
const BUDGET_MS := 3.0

signal finished

var _jobs: Array[Callable] = []


## Start doing `jobs` (callables without arguments) under `parent`. Returns the WarmUp, which can be freed to stop what is left.
static func run(parent: Node, jobs: Array[Callable]) -> WarmUp:
	var warm := WarmUp.new()
	warm._jobs = jobs.duplicate()
	warm.process_mode = Node.PROCESS_MODE_ALWAYS          # (a pause menu or a dialog does not stop it)
	parent.add_child(warm)
	return warm


## How many jobs are still to do.
func pending() -> int:
	return _jobs.size()


func _process(_delta: float) -> void:
	var start := Time.get_ticks_usec()
	while not _jobs.is_empty():
		_jobs.pop_front().call()
		if (Time.get_ticks_usec() - start) / 1000.0 >= BUDGET_MS:
			break
	if _jobs.is_empty():
		finished.emit()
		queue_free()
