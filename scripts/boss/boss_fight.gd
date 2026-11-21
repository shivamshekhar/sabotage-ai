class_name BossFight
extends Node2D
## A boss fight inside a level: the level file names the boss in meta "boss" ("salt_shaker" = RAM Saltman) and Main adds one of these
## to the level. It creates the boss, takes over the camera and sends AI Bros in while the boss sprays.
##
## The level is a closed arena: two columns of "invisible_wall" tiles are its ends. The player cannot pass them and the camera stops at
## them, so nothing behind them is ever shown. The boss hovers in the middle; the player hits it with thrown objects. When it swoops over
## the player, turns upside down and rains hardware it cannot be hurt, so run (the ledges are places to hide). `defeated` fires when the
## boss is dead and its fall has ended.

signal defeated

# BOSSES: the boss names a level file may use.
const BOSSES := ["salt_shaker"]

# CAMERA_ZOOM: below 1 shows more of the arena. The camera pulls back a little to show the boss with
# its health bar and the player below it. CAMERA_BOSS_PULL: how much of the way from the player to the boss the camera looks (0 = it
# only follows the player, 1 = it centres on the boss).
const CAMERA_ZOOM := 0.78
const CAMERA_BOSS_PULL := 0.35

# CAMERA_Y: the height the camera looks at, fixed so the whole arena (ceiling to floor) stays in view however high the boss floats.
const CAMERA_Y := 400.0

# CAMERA_TOP: how far above the arena's top edge the camera may look, in pixels. The room above the boss keeps its health bar clear of
# the HUD at the top of the screen.
const CAMERA_TOP := -100

# BRO_RESPAWN: seconds after an AI Bro is defeated before the next one may come from that side. While the boss shakes (sprays), a Bro
# comes in from the side of the screen the player is farther from, never more than one per side. (The Bros are a stand-in for the real
# minions.)
const BRO_RESPAWN := 3.0

# BRO_OFFSCREEN: how far in pixels beyond the edge of the screen a Bro first appears, so it walks in rather than popping up in view.
const BRO_OFFSCREEN := 160.0

var level: Level
var player: Player
var boss: SaltShakerBoss
var camera: Camera2D
var floor_y := 0.0

var _camera_placed := false
var _over := false
var _bros := {-1: null, 1: null}          # the Bro on each side (-1 left, 1 right), or null
var _bro_cooldown := {-1: 0.0, 1: 0.0}    # seconds until that side may send another


## The boss a level has ("" = none).
static func boss_of(level_id: String) -> String:
	var name := str(LevelFile.value(LevelData.data_for(level_id), "meta", "boss", ""))
	return name if BOSSES.has(name) else ""


## Start the fight in `level` against the player `player`: the floor is the one the player starts on.
func setup(the_level: Level, the_player: Player) -> void:
	name = "BossFight"
	level = the_level
	player = the_player
	floor_y = level.spawn.y
	boss = SaltShakerBoss.new()
	add_child(boss)
	boss.setup(arena_rect(), floor_y)
	boss.defeated.connect(func() -> void:
		_over = true
		defeated.emit())
	player.died.connect(func(_cause: String) -> void: _over = true)

	camera = Camera2D.new()
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	# The invisible walls are the ends of the level: the camera stops at them, so nothing behind them is ever shown.
	var arena := arena_rect()
	camera.limit_left = int(arena.position.x)
	camera.limit_top = CAMERA_TOP
	camera.limit_right = int(arena.end.x)
	camera.limit_bottom = level.world_h
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)
	camera.make_current()
	camera.global_position = Vector2(lerpf(player.global_position.x, boss.global_position.x, CAMERA_BOSS_PULL), CAMERA_Y)
	camera.reset_smoothing()


## The open space of the arena: between the invisible walls (the first and last "invisible_wall" tiles in the middle of the map), or the
## whole level if it has none.
func arena_rect() -> Rect2:
	var wall := str(TileRegistry.kind_for_key("invisible_wall").get("char", ""))
	var rows := LevelData.map(level.level_id)
	var row: String = rows[clampi(int(floor_y / Level.T) - 2, 0, rows.size() - 1)]
	var first := row.find(wall)
	var last := row.rfind(wall)
	if first < 0 or last <= first:
		return Rect2(Level.T, Level.T, level.world_w - 2 * Level.T, floor_y - Level.T)
	return Rect2((first + 1) * Level.T, Level.T, (last - first - 1) * Level.T, floor_y - Level.T)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_send_bros(delta)
	var look := player.global_position
	if is_instance_valid(boss):
		look = look.lerp(boss.global_position, CAMERA_BOSS_PULL)
	camera.global_position = Vector2(look.x, CAMERA_Y)
	if not _camera_placed:
		_camera_placed = true
		camera.force_update_scroll()
		camera.reset_smoothing()      # (the first frame already shows both fighters, no glide in from the corner)


## While the boss shakes and sprays, send AI Bros in from the side of the screen the player is FARTHER from (so a Bro never lands on the
## player the moment it arrives), at most one per side at a time. They start just beyond the edge of the screen (behind an invisible wall,
## which they walk through) and walk in.
func _send_bros(delta: float) -> void:
	for side in [-1, 1]:
		_bro_cooldown[side] = maxf(0.0, float(_bro_cooldown[side]) - delta)
		var bro = _bros[side]
		if bro != null and not is_instance_valid(bro):
			_bros[side] = null
			_bro_cooldown[side] = BRO_RESPAWN
	if not is_instance_valid(boss) or boss.state != SaltShakerBoss.State.SPRAY or _over:
		return
	var side := far_side()
	if _bros[side] == null and float(_bro_cooldown[side]) <= 0.0:
		_bros[side] = _spawn_bro(side)


## Which side of the screen the player is farther from: 1 = the right, -1 = the left.
func far_side() -> int:
	return 1 if player.global_position.x < camera.get_screen_center_position().x else -1


## The area of the world the camera shows now.
func view_rect() -> Rect2:
	var size := get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size / 2.0, size)


## An AI Bro on the floor just outside the screen on `side` (-1 left, 1 right), already after the player.
func _spawn_bro(side: int) -> AIBro:
	var bro := AIBro.new()
	bro.configure({"sight_range": 4000.0, "lose_range": 6000.0, "sight_height": 800.0, "patrol_radius": 100.0}, "AI BRO")
	var view := view_rect()
	var x := view.end.x + BRO_OFFSCREEN if side > 0 else view.position.x - BRO_OFFSCREEN
	bro.position = Vector2(clampf(x, float(Level.T), float(level.world_w - Level.T)), floor_y)
	bro.set_meta("always_awake", true)
	level.get_parent().add_child(bro)
	bro._dir = -side                       # facing the screen
	bro.state = AIBro.State.CHASE
	return bro
