class_name Level
extends Node2D
## Builds a playable level (sprites, colliders, hazards, ladders, exit) from a
## LevelData ASCII map, using the individual Kenney sprites via SpriteLibrary.

signal goal_reached

## Emitted when the player touches a checkpoint beacon for the first time; `position` is where they
## will respawn from now on (the feet position on the floor in front of it).
signal checkpoint_reached(position: Vector2)

# MAP BASICS.

# T: size of one map tile in pixels (tiles are square). The art, the colliders, the player's
# size and the jump physics are all designed around it. The pixel position of map cell
# (column c, row r) is (c * T, r * T). Changing it only makes sense together with all the
# art (the Kenney tiles are drawn at a fixed size) and the jump limits in README.md.
const T := 70

# SOLID: the map characters that are solid, i.e. get a collider and block the player: ground
# '#', metal crate 'X', orange crate 'O'. _build_solid_colliders() merges neighbouring solid
# cells into large rectangles. To make a new kind of solid block, add its character here and
# give it art in _build_tiles(). Ledges '=' and ladder decks are NOT listed: they are
# one-way and built separately.
const SOLID := "#XO"

# MACHINES (GPU racks, supercomputers... placed from map letters).

# MACHINES: map letter -> which sprite to draw and its size in tiles ("w" wide, "h" tall).
# The letter marks the machine's BOTTOM-LEFT tile; it grows to the right and up, and the
# cells it covers must be '.' in the map. In _build_machine() the sprite is placed at
# (c * T, (r + 1 - h) * T) so its bottom edge sits on the floor line of that row.
# To add a machine: generate "<name>.png" (plus _leds_a, _leds_b and _shadow) with
# tools/art/generate_machines.py, add an entry here, then use its letter in the map. The
# sprite's pixel size must equal (w * T, h * T) or it won't line up with the grid.
const MACHINES := {
	"G": {"sprite": "machine_gpu_rack", "w": 2, "h": 3},
	"S": {"sprite": "machine_supercomputer", "w": 3, "h": 3},
	"M": {"sprite": "machine_monitoring_station", "w": 4, "h": 3},
	"R": {"sprite": "machine_server_tower", "w": 1, "h": 3},
}

# MACHINE_TINT: colour multiplied over each machine sprite. White leaves it unchanged, lower
# values darken it and uneven channels tint it. Machines are kept bright so they stand out
# against the dimmed background.
const MACHINE_TINT := Color.WHITE

# MACHINE_SHADOW_PAD: extra transparent border, in pixels, around each *_shadow.png so its
# blur isn't clipped. It must match the pad used by tools/art/generate_machines.py; the
# shadow sprite is shifted back by this amount so it lines up with the machine.
const MACHINE_SHADOW_PAD := 20

# MACHINE_SHADOW_OFFSET: how far the shadow is shifted from the machine, in pixels (x right,
# y down). A positive offset casts it down and to the right.
# Larger: a longer, more detached shadow (the machine looks further from the wall).
# Zero: the shadow sits directly behind the machine.
const MACHINE_SHADOW_OFFSET := Vector2(10, 6)

# MACHINE_BLINK_PERIOD: seconds for one full on-off cycle of a machine's LEDs and screens.
# Each machine has two LED layers that run half a period apart, so about half the lights
# are on at any moment.
# Smaller: frantic blinking. Larger: calm, slow pulsing.
const MACHINE_BLINK_PERIOD := 1.7

# MACHINE_BLINK_LOW: opacity of an LED layer at its dimmest (its brightest is full opacity).
# 0 = the LEDs switch fully off, 1 = no blinking at all.
const MACHINE_BLINK_LOW := 0.25

# FAN_SPIN_MIN: slowest fan rotation speed, in radians per second. A machine's fans (for
# example the GPU rack's) are separate blade sprites turned every frame in _process():
#     rotation += speed * delta
# Each fan gets its own speed between FAN_SPIN_MIN and FAN_SPIN_MAX (spread by its position in
# the level), so they never look synchronised. One full turn is TAU radians, so
#     turns per second = speed / TAU
# Higher: faster fans. Very fast spinning can look like it stops or runs backwards (the
# "wagon wheel" effect, because the blades repeat around the circle), so don't go too high.
const FAN_SPIN_MIN := 5.0

# FAN_SPIN_MAX: fastest fan rotation speed, in radians per second (see FAN_SPIN_MIN).
# Keep it at or above FAN_SPIN_MIN. Setting both equal makes every fan spin at the same speed.
const FAN_SPIN_MAX := 9.0

# SCREEN_KINDS: which live display each monitor of a machine shows, keyed by the monitor's position
# name ("left", "center", "right") from tools/art/generate_machines.py, which also supplies the
# screen rectangles (see MachineScreens). The machine image itself has blank screens; the game draws
# on them every frame (see MonitorScreen for what each kind does). Swap the values to rearrange which
# screen shows what.
const SCREEN_KINDS := {
	"left": MonitorScreen.Kind.GRAPH,
	"center": MonitorScreen.Kind.TERMINAL,
	"right": MonitorScreen.Kind.SCOPE,
}

# SIRENS AND LAMPS (map letters 'i' and 'l'): a soft additive halo on the lamp that pulses.
# See _add_light(). The halo's opacity goes GLOW_MIN -> GLOW_MAX -> GLOW_MIN once per
# LIGHT_PERIOD, while the lamp sprite itself goes LAMP_DIM -> white -> LAMP_DIM in step.

# SIREN_LENS: where the glowing part sits inside a siren sprite, in pixels from the
# sprite's top-left corner. The halo is centred there. It was measured from the sprite; if
# you swap the art, re-measure it or the glow will float beside the lamp.
const SIREN_LENS := Vector2(35, 46)

# LAMP_LENS: the same measurement for the pole-mounted lamps (their lit part is near the
# top of the sprite).
const LAMP_LENS := Vector2(35, 24)

# LIGHT_ORANGE, LIGHT_BLUE: halo colours for sirens (they alternate by map column).
# Halos use additive blending, so bright colours add light and black adds nothing.
const LIGHT_ORANGE := Color(1.0, 0.54, 0.14)

# LIGHT_BLUE: the second siren colour (see LIGHT_ORANGE).
const LIGHT_BLUE := Color(0.23, 0.62, 1.0)

# LIGHT_GREEN: halo colour for the pole lamps.
const LIGHT_GREEN := Color(0.18, 0.9, 0.42)

# LIGHT_PERIOD: seconds for one full pulse (up and down).
# Smaller: faster, more alarm-like. Larger: slow and calm. Each light starts at its own
# phase (derived from its map column), so a row of them doesn't pulse in unison.
const LIGHT_PERIOD := 2.4

# GLOW_MIN: halo opacity at its dimmest (0 = invisible, 1 = fully opaque).
const GLOW_MIN := 0.12

# GLOW_MAX: halo opacity at its brightest. Raise it for a stronger bloom, lower it for a
# subtler one. Keep it above GLOW_MIN or there is no pulse.
const GLOW_MAX := 0.85

# LAMP_DIM: brightness of the lamp sprite itself at the dim point, as a colour multiplier
# (1 = no change, lower = darker). Lower: a bigger on/off contrast between lit and unlit.
const LAMP_DIM := 0.5

# CHECKPOINT_DIM: brightness of a checkpoint beacon before the player has touched it, as a colour
# multiplier (1 = fully bright, lower = darker). Once touched it switches to the pulsing green glow
# used by the lamps (see LAMP_DIM, GLOW_MIN, GLOW_MAX). Lower: a more obvious "off" beacon.
const CHECKPOINT_DIM := 0.4

## Which level to build (see LevelData.ids()). Set it before adding the Level to the tree.
var level_id := LevelData.DEFAULT_ID
var world_w := 0
var world_h := 0
var spawn := Vector2.ZERO
## Extra decorative wall (px) drawn beyond the left and right edges, with no collision. The
## camera may scroll that far past the level, so near either end the player can be shown
## clear of the phone controls in the screen corners. Set before adding the level to the tree.
var side_padding := 0
## Ladder columns in world space (from the top tile down to the floor); the Player climbs these.
var ladders: Array[Rect2] = []

var _map: Array[String] = []
var _goal_fired := false
var _fans: Array[Dictionary] = []   # spinning fan blades: {"sprite": Sprite2D, "speed": radians per second}
var _glow_tex: GradientTexture2D
var _glow_mat: CanvasItemMaterial


func _ready() -> void:
	_map = LevelData.map(level_id)
	var cols := _map[0].length()
	for r in _map.size():
		if _map[r].length() != cols:
			push_error("Level row %d has length %d, expected %d" % [r, _map[r].length(), cols])
	world_w = cols * T
	world_h = _map.size() * T

	_build_backdrop()
	_build_side_padding()
	_build_tiles()
	_build_solid_colliders()
	_build_ledges()
	_build_ladders()


# ---------- map helpers ----------

func _cell(c: int, r: int) -> String:
	if r < 0 or r >= _map.size() or c < 0 or c >= _map[r].length():
		return "#"  # out of bounds counts as solid wall
	return _map[r][c]


func _is_solid(c: int, r: int) -> bool:
	return SOLID.contains(_cell(c, r))


func _place(sprite_name: String, c: int, r: int, z: int = 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = SpriteLibrary.tile(sprite_name)
	s.centered = false
	s.position = Vector2(c * T, r * T)
	s.z_index = z
	add_child(s)
	return s


func _decor(sprite_name: String, c: int, r: int, z: int = -5, tint: Color = Color(0.78, 0.82, 0.95)) -> Sprite2D:
	var s := _place(sprite_name, c, r, z)
	s.modulate = tint
	return s


## Pick <prefix>_start / _middle / _end (and _single when available) from neighbours.
func _run_name(prefix: String, ch: String, c: int, r: int, has_single: bool) -> String:
	var l := _cell(c - 1, r) == ch
	var rt := _cell(c + 1, r) == ch
	if l and rt:
		return prefix + "_middle"
	if rt:
		return prefix + "_start"
	if l:
		return prefix + "_end"
	return prefix + ("_single" if has_single else "_start")


## Ground, or the deck on top of a ladder (which continues the ground line).
func _joins_ground(c: int, r: int) -> bool:
	var ch := _cell(c, r)
	return ch == "#" or (ch == "H" and _cell(c, r - 1) != "H")


func _ground_name(c: int, r: int) -> String:
	if _cell(c, r - 1) == "#":
		return "ground_fill"
	var l := _joins_ground(c - 1, r)
	var rt := _joins_ground(c + 1, r)
	if l and rt:
		return "ground_middle"
	if rt:
		return "ground_start"
	if l:
		return "ground_end"
	return "ground_single"


# ---------- building ----------

func _build_tiles() -> void:
	for r in _map.size():
		for c in _map[r].length():
			match _map[r][c]:
				"#": _place(_ground_name(c, r), c, r)
				"X": _place("block_metal_x", c, r)
				"O": _place("block_metal_orange", c, r)
				"=": _place(_run_name("ledge", "=", c, r, true), c, r)
				"H": _place("ladder_top" if _cell(c, r - 1) != "H" else "ladder_middle", c, r, -2)
				"^":
					_place("spikes_up", c, r, 1)
					_add_hazard(Rect2(c * T + 10, r * T + 30, 50, 40))
				"v":
					_place("spikes_down", c, r, 1)
					_add_hazard(Rect2(c * T + 10, r * T, 50, 40))
				"k": _decor(_run_name("panel_controls", "k", c, r, false), c, r)
				"w": _decor(_run_name("panel_dark", "w", c, r, false), c, r)
				"r": _decor(_run_name("rail_thin", "r", c, r, false), c, r, -4, Color.WHITE)
				"m": _decor("monitor_text", c, r)
				"t": _decor("monitor_tv_text", c, r)
				"g": _decor("gear_full", c, r, -6)
				"i":
					var orange := int(c / 2.0) % 2 == 0
					var siren := _decor("siren_orange" if orange else "siren_blue", c, r, -3, Color.WHITE)
					_add_light(siren, c, SIREN_LENS, LIGHT_ORANGE if orange else LIGHT_BLUE, 90.0)
				"l":
					var lamp := _decor("lamp_pole_green", c, r, -3, Color.WHITE)
					_add_light(lamp, c, LAMP_LENS, LIGHT_GREEN, 70.0)
				"c": _decor("canister_blue_vertical" if c % 2 == 0 else "canister_yellow_vertical", c, r, -3)
				"~": _place(_run_name("slime_floor", "~", c, r, true), c, r, -1)
				"P": spawn = Vector2((c + 0.5) * T, (r + 1) * T)
				"E": _build_exit(c, r)
				"K": _build_checkpoint(c, r)
				_:
					if MACHINES.has(_map[r][c]):
						_build_machine(MACHINES[_map[r][c]], c, r)


## Decorative wall tiles beyond the left and right edges (see side_padding). No colliders: the
## map's own edge walls are the real boundary.
func _build_side_padding() -> void:
	if side_padding <= 0:
		return
	var cols_extra := ceili(float(side_padding) / T)
	var map_cols := _map[0].length()
	for r in _map.size():
		for i in cols_extra:
			_place("ground_fill", -1 - i, r)
			_place("ground_fill", map_cols + i, r)


## Soft additive halo on a lamp, pulsing slowly. Each light starts at its own phase
## (from its column) so a row of them doesn't blink in unison.
func _add_light(lamp: Sprite2D, c: int, lens: Vector2, color: Color, radius: float) -> void:
	var glow := Sprite2D.new()
	glow.texture = _glow_texture()
	glow.material = _glow_material()
	glow.position = lamp.position + lens
	glow.scale = Vector2.ONE * (radius * 2.0 / float(_glow_texture().width))
	glow.modulate = Color(color, GLOW_MIN)
	glow.z_index = -2  # above the lamp, below the player
	add_child(glow)
	lamp.modulate = Color(LAMP_DIM, LAMP_DIM, LAMP_DIM)
	_pulse_light(lamp, glow, color, fmod(c * 0.37, LIGHT_PERIOD))


func _pulse_light(lamp: Sprite2D, glow: Sprite2D, color: Color, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	var half := LIGHT_PERIOD / 2.0
	var tw := create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "modulate", Color(color, GLOW_MAX), half)
	tw.parallel().tween_property(lamp, "modulate", Color.WHITE, half)
	tw.tween_property(glow, "modulate", Color(color, GLOW_MIN), half)
	tw.parallel().tween_property(lamp, "modulate", Color(LAMP_DIM, LAMP_DIM, LAMP_DIM), half)


func _glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = grad
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 128
		_glow_tex.height = 128
	return _glow_tex


func _glow_material() -> CanvasItemMaterial:
	if _glow_mat == null:
		_glow_mat = CanvasItemMaterial.new()
		_glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _glow_mat


## Place a machine so its bottom edge sits on the floor line of tile (c, r), growing
## right and up. Its LED/screen overlays blink in two alternating groups.
func _build_machine(def: Dictionary, c: int, r: int) -> void:
	var pos := Vector2(c * T, (r + 1 - int(def["h"])) * T)
	var sprite_name: String = def["sprite"]
	# Soft shadow cast onto the wall behind: separates the machine from the background.
	var shadow := Sprite2D.new()
	shadow.texture = SpriteLibrary.machine(sprite_name + "_shadow")
	shadow.centered = false
	shadow.position = pos - Vector2(MACHINE_SHADOW_PAD, MACHINE_SHADOW_PAD) + MACHINE_SHADOW_OFFSET
	shadow.z_index = -6
	add_child(shadow)
	var base := Sprite2D.new()
	base.texture = SpriteLibrary.machine(sprite_name)
	base.centered = false
	base.position = pos
	base.z_index = -5
	base.modulate = MACHINE_TINT
	add_child(base)
	# Machines with fans (positions come from the generator, see MachineFans) get a blade
	# sprite over each fan housing; _process() spins them.
	for centre in MachineFans.centres(sprite_name):
		_add_fan(pos + centre)
	# Machines with monitors get a live display over each blank screen (rectangles come from the generator).
	var screens := MachineScreens.rects(sprite_name)
	for key in screens:
		var rect: Rect2 = screens[key]
		_add_screen(SCREEN_KINDS[key], pos + rect.position, rect.size)
	var half := MACHINE_BLINK_PERIOD / 2.0
	for i in 2:
		var leds := Sprite2D.new()
		leds.texture = SpriteLibrary.machine("%s_leds_%s" % [sprite_name, "ab"[i]])
		leds.centered = false
		leds.position = pos
		leds.z_index = -4
		leds.modulate = Color(MACHINE_TINT, MACHINE_BLINK_LOW)
		add_child(leds)
		# Group B runs half a cycle behind A; each machine gets its own offset from its column.
		_blink_machine(leds, fmod(c * 0.29 + i * half, MACHINE_BLINK_PERIOD))


## One spinning fan: a blade sprite centred on `at`, turned every frame by _process().
func _add_fan(at: Vector2) -> void:
	var blades := Sprite2D.new()
	blades.texture = SpriteLibrary.machine(MachineFans.FAN_SPRITE)
	blades.position = at
	blades.z_index = -4  # over the machine, under the player
	blades.modulate = MACHINE_TINT
	# Vary speed and starting angle from the fan's index so neighbours never match.
	var spread := fmod(_fans.size() * 0.381966, 1.0)
	blades.rotation = spread * TAU
	add_child(blades)
	_fans.append({"sprite": blades, "speed": lerpf(FAN_SPIN_MIN, FAN_SPIN_MAX, spread)})


## One live monitor screen drawn over a blank screen in a machine image.
func _add_screen(screen_kind: MonitorScreen.Kind, at: Vector2, screen_size: Vector2) -> void:
	var screen := MonitorScreen.new()
	screen.position = at
	screen.z_index = -4  # over the machine, under the player
	screen.modulate = MACHINE_TINT
	screen.setup(screen_kind, screen_size, hash(at))  # seeded by position so screens differ
	add_child(screen)


func _process(delta: float) -> void:
	for fan in _fans:
		fan["sprite"].rotation += fan["speed"] * delta


func _blink_machine(leds: Sprite2D, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	var half := MACHINE_BLINK_PERIOD / 2.0
	var tw := create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(leds, "modulate:a", 1.0, half)
	tw.tween_property(leds, "modulate:a", MACHINE_BLINK_LOW, half)


func _build_exit(c: int, r: int) -> void:
	var s := _decor("sign_power_green", c, r, -1, Color.WHITE)
	var tw := create_tween().set_loops()
	tw.tween_property(s, "modulate:a", 0.45, 0.6)
	tw.tween_property(s, "modulate:a", 1.0, 0.6)
	var area := _make_area(Rect2(c * T, r * T, T, T))
	area.body_entered.connect(_on_goal_body)


## A checkpoint: a green beacon that stays dim until the player touches it. Touching it makes it the
## player's new respawn point (Player.spawn) and switches it on (a pulsing green glow, like the lamps).
func _build_checkpoint(c: int, r: int) -> void:
	var beacon := _decor("siren_green", c, r, -3, Color.WHITE)
	beacon.modulate = Color(CHECKPOINT_DIM, CHECKPOINT_DIM, CHECKPOINT_DIM)
	# the player's body overlaps this area whenever they stand on the floor in front of the beacon
	var area := _make_area(Rect2(c * T, (r - 1) * T, T, 2 * T))
	var lit := [false]   # an array so the closure below can change it
	area.body_entered.connect(func(body: Node) -> void:
		if body is Player and not lit[0]:
			lit[0] = true
			var respawn := Vector2((c + 0.5) * T, (r + 1) * T)
			body.spawn = respawn
			_add_light(beacon, c, SIREN_LENS, LIGHT_GREEN, 90.0)
			checkpoint_reached.emit(respawn))


func _on_goal_body(body: Node) -> void:
	if body is Player and not _goal_fired:
		_goal_fired = true
		goal_reached.emit()


func _make_area(rect: Rect2) -> Area2D:
	var area := Area2D.new()
	area.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	area.add_child(shape)
	add_child(area)
	return area


func _add_hazard(rect: Rect2) -> void:
	# Player tracks how many hazards it overlaps and takes damage while inside one.
	var area := _make_area(rect)
	area.body_entered.connect(func(body: Node) -> void:
		if body is Player:
			body.hazard_count += 1)
	area.body_exited.connect(func(body: Node) -> void:
		if body is Player:
			body.hazard_count -= 1)


func _add_solid(rect: Rect2, one_way: bool = false, layer: int = Player.LAYER_WORLD) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	shape.one_way_collision = one_way
	body.add_child(shape)
	add_child(body)


## Merge solid tiles into the fewest rectangles (greedy) to avoid seams.
func _build_solid_colliders() -> void:
	var used := {}
	var rows := _map.size()
	var cols := _map[0].length()
	for r in rows:
		for c in cols:
			if used.has(Vector2i(c, r)) or not _is_solid(c, r):
				continue
			var w := 1
			while c + w < cols and _is_solid(c + w, r) and not used.has(Vector2i(c + w, r)):
				w += 1
			var h := 1
			while r + h < rows and _row_free(c, r + h, w, used):
				h += 1
			for yy in h:
				for xx in w:
					used[Vector2i(c + xx, r + yy)] = true
			_add_solid(Rect2(c * T, r * T, w * T, h * T))


func _row_free(c: int, r: int, w: int, used: Dictionary) -> bool:
	for xx in w:
		if not _is_solid(c + xx, r) or used.has(Vector2i(c + xx, r)):
			return false
	return true


func _build_ledges() -> void:
	for r in _map.size():
		var c := 0
		while c < _map[r].length():
			if _map[r][c] == "=":
				var start := c
				while c < _map[r].length() and _map[r][c] == "=":
					c += 1
				_add_solid(Rect2(start * T, r * T, (c - start) * T, 14), true)
			else:
				c += 1


func _build_ladders() -> void:
	for c in _map[0].length():
		var r := 0
		while r < _map.size():
			if _cell(c, r) == "H":
				var top := r
				while _cell(c, r) == "H":
					r += 1
				ladders.append(Rect2(c * T, top * T, T, (r - top) * T))
				# Deck on top of the ladder: stand on it, climb up through it from below.
				# Own physics layer so the climbing player can ignore it (to climb back down).
				_add_solid(Rect2(c * T, top * T, T, 12), true, Player.LAYER_LADDER_DECK)
			else:
				r += 1


# ---------- backdrop ----------

func _build_backdrop() -> void:
	add_child(LevelBackground.new())

	# Light tint over the parallax art so gameplay tiles stay readable, plus the title.
	var bd := Node2D.new()
	bd.z_index = -20
	add_child(bd)
	bd.draw.connect(func() -> void:
		bd.draw_rect(Rect2(0, 0, world_w, world_h), Color(0.04, 0.06, 0.11, 0.30))
		bd.draw_string(ThemeDB.fallback_font, LevelData.title_position(level_id), LevelData.title(level_id),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1, 1, 1, 0.35)))
	bd.queue_redraw()
