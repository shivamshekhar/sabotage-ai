class_name EffectWarmUp
extends RefCounted
## Gets the effects of the game ready before they are first needed. The first time an effect is drawn, the pictures it uses are read, its materials are set up and the graphics card
## prepares to draw it: that takes a few frames' worth of time and is felt as a stutter at the first explosion or the first shot. Here every effect is made once, nearly invisible (see
## HIDDEN_ALPHA) in the middle of the screen, a little at a time (see WarmUp), and removed again.
##
##   WarmUp.run(self, EffectWarmUp.jobs(self))

# HIDDEN_ALPHA: how opaque the effects are while they warm up (0 to 1). Not 0: a thing that cannot be seen is not drawn, and then nothing would be prepared. Small enough to be unseen.
const HIDDEN_ALPHA := 0.01

# STAGE_LAYER: the canvas layer the effects are shown on (a layer of the screen, so they are drawn wherever the camera is).
const STAGE_LAYER := 2

# SHOW_TIME: seconds the effects stay after the last job, to be drawn at least a few times.
const SHOW_TIME := 0.5

# EXPLOSION_STRENGTH: the size of the warm-up explosion (see Explosion). BOLT_LENGTH: how long (px) the warm-up lightning and energy wave are.
const EXPLOSION_STRENGTH := 0.5
const BOLT_LENGTH := 160.0


## The jobs that make every effect once and read the throwable objects' pictures and every sound; `parent` is where the stage is put. Run them with WarmUp.run().
static func jobs(parent: Node) -> Array[Callable]:
	var stage: Array[Node2D] = []        # (made by the first job, so nothing is made if the jobs are never run)
	var out: Array[Callable] = []
	out.append(func() -> void: stage.append(_make_stage(parent)))
	out.append(func() -> void: Explosion.spawn(stage[0], Vector2.ZERO, EXPLOSION_STRENGTH))
	out.append(func() -> void: ElectricArc.hold(stage[0], Vector2.ZERO, Vector2(BOLT_LENGTH, 0.0), true).release())
	out.append(func() -> void: EnergyBeam.hold(stage[0], Vector2.ZERO, Vector2(BOLT_LENGTH, 0.0), true).release())
	for object_name in SpriteLibrary.PROJECTILES:
		out.append(func() -> void: SpriteLibrary.projectile(object_name))
	out.append_array(Sfx.warm_up_jobs())
	out.append(func() -> void: parent.get_tree().create_timer(SHOW_TIME).timeout.connect(stage[0].get_parent().queue_free))
	return out


## The stage: a canvas layer with a node in the middle of the screen that makes what is put on it nearly invisible.
static func _make_stage(parent: Node) -> Node2D:
	var layer := CanvasLayer.new()
	layer.layer = STAGE_LAYER
	var stage := Node2D.new()
	stage.position = parent.get_viewport().get_visible_rect().size / 2.0
	stage.modulate = Color(1.0, 1.0, 1.0, HIDDEN_ALPHA)
	layer.add_child(stage)
	parent.add_child(layer)
	return stage
