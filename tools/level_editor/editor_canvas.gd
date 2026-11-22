class_name EditorCanvas
extends Control
## The level view: draws the level the way the game does (real sprites, auto-tiled ground, pits as liquid, machines with their
## LEDs) and handles the tools (select/move, paint, rectangle, line, eraser, eyedropper), panning and zooming. All edits go
## through the EditorDocument. Only the visible tiles are drawn, with textures cached, so large levels stay fast.

## The tools.
enum Tool { SELECT, PAINT, RECT, LINE, ERASER, EYEDROPPER }

## Emitted with a short hint for the status bar (what the tool will do, or why a placement is refused).
signal hint(text: String)
## Emitted when the mouse moves over a cell (or leaves the level: (-1,-1)).
signal cell_hovered(cell: Vector2i)
## Emitted when the eyedropper picked a palette entry.
signal entry_picked(entry: Dictionary)
## Emitted when the user presses Escape to leave the armed item (the editor then switches to the select tool).
signal disarm_requested

# T: tile size in pixels of the game (Level.T). Every drawing coordinate here is in these world pixels.
const T := 70

# MIN_ZOOM / MAX_ZOOM: limits of the zoom factor (screen pixels per world pixel). Lower MIN_ZOOM to see bigger levels at once;
# raise MAX_ZOOM to inspect pixels.
const MIN_ZOOM := 0.08
const MAX_ZOOM := 3.0

# ZOOM_STEP: factor applied by one mouse wheel notch or zoom button press. Higher: faster zooming.
const ZOOM_STEP := 1.15

# SIMPLE_ZOOM: below this zoom tiles are drawn as plain coloured squares instead of sprites (much faster for huge levels).
# Raise it if zoomed-out views of big levels are slow; lower it to see sprites even when small.
const SIMPLE_ZOOM := 0.28

# GRID_MIN_PX: the grid overlay is hidden when a tile is smaller than this many screen pixels (it would only be noise).
const GRID_MIN_PX := 9.0

# GHOST_ALPHA: opacity of an item that is armed under the cursor or being dragged, so it is clearly "held".
# Lower: more see-through; 1 would look like it is already placed.
const GHOST_ALPHA := 0.55

# GHOST_BAD: tint multiplied over a ghost whose placement breaks a rule (red).
const GHOST_BAD := Color(1.0, 0.3, 0.3)

# GHOST_WARN: tint multiplied over a ghost that is allowed but breaks a soft rule (yellow).
const GHOST_WARN := Color(1.0, 0.85, 0.35)

# DECOR_TINT: colour the game multiplies over decor sprites (Level._decor).
const DECOR_TINT := Color(0.78, 0.82, 0.95)

# FAR_TINT / MID_TINT: the game's tints of the two background layers drawn in the preview (LevelBackground).
const FAR_TINT := Color(0.50, 0.56, 0.74)
const MID_TINT := Color(0.40, 0.45, 0.62)

# BACKDROP_SHADE: the dark colour the game draws over the background so the tiles stay readable (alpha = strength).
const BACKDROP_SHADE := Color(0.04, 0.06, 0.11, 0.30)

# OUTSIDE_COLOR: the colour around the level.
const OUTSIDE_COLOR := Color(0.07, 0.075, 0.09)

# CHECKPOINT_DIM: brightness of a checkpoint beacon, like Level.CHECKPOINT_DIM.
const CHECKPOINT_DIM := 0.55

# SIMPLE_COLORS: the colour of each map character when zoomed far out.
const SIMPLE_COLORS := {
	"#": Color(0.42, 0.45, 0.52), "=": Color(0.55, 0.6, 0.7), "H": Color(0.75, 0.6, 0.3), "X": Color(0.5, 0.5, 0.58),
	"O": Color(0.85, 0.5, 0.2), "^": Color(0.9, 0.3, 0.3), "v": Color(0.9, 0.3, 0.3), "A": Color(0.3, 0.9, 0.3),
	"F": Color(1.0, 0.45, 0.1), "N": Color(0.8, 1.0, 0.3), "W": Color(0.3, 0.6, 1.0), "P": Color(0.3, 0.9, 1.0),
	"E": Color(0.3, 1.0, 0.5), "K": Color(0.3, 0.9, 0.5), "B": Color(1.0, 0.4, 0.8), "L": Color(0.9, 0.9, 0.3),
}

# MACHINE_COLOR: colour of a machine (and other decor) when zoomed far out.
const MACHINE_COLOR := Color(0.3, 0.34, 0.45)

## Show the grid overlay.
var show_grid := true
## Show the background preview (otherwise a flat colour).
var show_background := true

var doc: EditorDocument
var catalog: EditorCatalog
var tool: Tool = Tool.SELECT
var armed: Dictionary = {}
var _gate_char := ""   # the laser gate id being drawn, see _armed_char()
var zoom := 0.6
var pan := Vector2(40, 40)

var _tex: Dictionary = {}
var _hover := Vector2i(-1, -1)
var _mouse_inside := false
var _drag := ""        # "", "paint", "erase", "rect", "line", "box", "move", "pan"
var _drag_start := Vector2i.ZERO
var _drag_cell := Vector2i.ZERO
var _drag_pan_origin := Vector2.ZERO
var _drag_copy := false
var _stroke: Array[Vector2i] = []
var _move_block: Dictionary = {}
var _move_preview: Dictionary = {}
var _ghost_problem: Dictionary = {}
var _ping_cell := Vector2i(-1, -1)
var _ping_time := 0.0
var _fit_pending := false
var _bg_name := ""
var _bg_far: Texture2D
var _bg_mid: Texture2D


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_CLICK
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	set_process(false)


## Connect the canvas to a document (it redraws on every change).
func set_document(d: EditorDocument) -> void:
	if doc != null:
		doc.changed.disconnect(_on_doc_changed)
		doc.selection_changed.disconnect(queue_redraw)
	doc = d
	catalog = d.catalog
	doc.changed.connect(_on_doc_changed)
	doc.selection_changed.connect(queue_redraw)
	_cancel_drag()
	_ghost_problem = {}
	queue_redraw()


func _on_doc_changed(_kind: String) -> void:
	_refresh_ghost_problem()
	queue_redraw()


# ---------------------------------------------------------------- view control

## The world position (pixels) under a screen position inside this control.
func screen_to_world(p: Vector2) -> Vector2:
	return (p - pan) / zoom


## The cell under a position of this control (may be outside the level).
func screen_to_cell(p: Vector2) -> Vector2i:
	var w := screen_to_world(p)
	return Vector2i(floori(w.x / T), floori(w.y / T))


## Zoom by a factor keeping the point `around` (in this control's coordinates) fixed.
func zoom_by(factor: float, around: Vector2) -> void:
	var new_zoom := clampf(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	var world := screen_to_world(around)
	zoom = new_zoom
	pan = around - world * zoom
	queue_redraw()


## Zoom so the whole level is visible.
func fit_view() -> void:
	if doc == null:
		return
	if size.x < 100.0 or size.y < 100.0:
		_fit_pending = true   # the layout is not ready yet; fit when the control gets its size
		return
	_fit_pending = false
	var world := Vector2(doc.cols() * T, doc.rows() * T)
	var avail := size - Vector2(40, 40)
	zoom = clampf(minf(avail.x / world.x, avail.y / world.y), MIN_ZOOM, 1.0)
	pan = (size - world * zoom) / 2.0
	queue_redraw()


## Set zoom to 1:1 around the middle of the view.
func zoom_actual() -> void:
	zoom_by(1.0 / zoom, size / 2.0)


## Scroll so a cell is in the middle of the view and flash it.
func jump_to(cell: Vector2i) -> void:
	pan = size / 2.0 - (Vector2(cell) + Vector2(0.5, 0.5)) * T * zoom
	_ping_cell = cell
	_ping_time = 1.6
	set_process(true)
	queue_redraw()


## For screenshots and tests: pretend the mouse hovers over a cell.
func debug_hover(cell: Vector2i) -> void:
	_hover = cell
	_refresh_ghost_problem()
	queue_redraw()


## For screenshots and tests: pretend the selection is being dragged by d tiles.
func debug_move(d: Vector2i) -> void:
	_drag = "move"
	_drag_start = doc.sel.position
	_drag_cell = _drag_start + d
	_move_block = doc.take_block(doc.sel)
	_update_move_preview(false)
	queue_redraw()


func _process(delta: float) -> void:
	_ping_time -= delta
	if _ping_time <= 0.0:
		_ping_cell = Vector2i(-1, -1)
		set_process(false)
	queue_redraw()


## Choose the tool. Switching tools cancels a drag in progress.
func set_tool(t: Tool) -> void:
	tool = t
	_cancel_drag()
	_refresh_ghost_problem()
	_emit_tool_hint()
	queue_redraw()


## The map character the armed item puts down. For the laser gate (one palette item for all nine ids) it is the lowest id no gate
## in the level uses yet, kept for a whole stroke so one drag draws one gate; it is chosen again for the next gate.
func _armed_char() -> String:
	var ch := str(armed.get("char", "."))
	if not bool(armed.get("auto_id", false)):
		return ch
	if _gate_char == "":
		_gate_char = doc.next_free_gate_id()
	return _gate_char


## Arm a palette entry (placed by the paint, rectangle and line tools).
func set_armed(entry: Dictionary) -> void:
	armed = entry
	_gate_char = ""
	_refresh_ghost_problem()
	_emit_tool_hint()
	queue_redraw()


func _emit_tool_hint() -> void:
	match tool:
		Tool.SELECT:
			hint.emit("Select: click a thing to select it, drag to move (Ctrl = copy), drag empty space to box-select. Right click erases.")
		Tool.PAINT:
			hint.emit("Paint: %s. Click or drag to place, right click to erase, Esc to put it down." % (str(armed.get("name", "pick an item in the drawer")) if not armed.is_empty() else "pick an item in the drawer"))
		Tool.RECT:
			hint.emit("Rectangle: drag to fill an area with the armed item (Shift = outline).")
		Tool.LINE:
			hint.emit("Line: drag to draw a straight line of the armed item.")
		Tool.ERASER:
			hint.emit("Eraser: click or drag to erase. Machines are erased whole.")
		Tool.EYEDROPPER:
			hint.emit("Eyedropper: click a tile to arm the same item.")


func _cancel_drag() -> void:
	if _drag == "paint" or _drag == "erase":
		doc.end_edit()
	_drag = ""
	_stroke.clear()
	_move_block = {}
	_move_preview = {}
	_drag_copy = false


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if doc == null:
		return
	if event is InputEventMouseMotion:
		_on_motion(event as InputEventMouseMotion)
	elif event is InputEventMouseButton:
		_on_button(event as InputEventMouseButton)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_mouse_inside = true
	elif what == NOTIFICATION_MOUSE_EXIT:
		_mouse_inside = false
		_hover = Vector2i(-1, -1)
		cell_hovered.emit(_hover)
		queue_redraw()
	elif what == NOTIFICATION_RESIZED and doc != null:
		if _fit_pending:
			fit_view()
		queue_redraw()


func _on_button(e: InputEventMouseButton) -> void:
	var cell := screen_to_cell(e.position)
	if e.pressed:
		grab_focus()
	match e.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if e.pressed:
				zoom_by(ZOOM_STEP, e.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if e.pressed:
				zoom_by(1.0 / ZOOM_STEP, e.position)
		MOUSE_BUTTON_MIDDLE:
			if e.pressed:
				_begin_pan(e.position)
			elif _drag == "pan":
				_drag = ""
		MOUSE_BUTTON_LEFT:
			if e.pressed:
				if Input.is_key_pressed(KEY_SPACE):
					_begin_pan(e.position)
				else:
					_left_down(cell, e)
			else:
				_left_up(cell, e)
		MOUSE_BUTTON_RIGHT:
			if e.pressed:
				if _drag == "move" or _drag == "box" or _drag == "rect" or _drag == "line":
					_cancel_drag()
					queue_redraw()
				else:
					_drag = "erase"
					doc.begin_edit()
					_erase_at(cell)
			elif _drag == "erase":
				doc.end_edit()
				_drag = ""
				_stroke.clear()


func _begin_pan(at: Vector2) -> void:
	_drag = "pan"
	_drag_start = Vector2i.ZERO
	_drag_pan_origin = pan - at


func _on_motion(e: InputEventMouseMotion) -> void:
	var cell := screen_to_cell(e.position)
	if _drag == "pan":
		pan = e.position + _drag_pan_origin
		queue_redraw()
		return
	if cell != _hover:
		_hover = cell
		cell_hovered.emit(cell if doc.in_bounds(cell.x, cell.y) else Vector2i(-1, -1))
		_refresh_ghost_problem()
	match _drag:
		"paint":
			_paint_to(cell)
		"erase":
			_erase_to(cell)
		"rect", "line", "box":
			_drag_cell = cell
		"move":
			_drag_cell = cell
			_update_move_preview(Input.is_key_pressed(KEY_CTRL))
	queue_redraw()


func _left_down(cell: Vector2i, _e: InputEventMouseButton) -> void:
	match tool:
		Tool.SELECT:
			_select_down(cell)
		Tool.PAINT, Tool.RECT, Tool.LINE:
			if armed.is_empty():
				hint.emit("Pick an item in the drawer first.")
				return
			if str(armed.get("char", "")) == ".":
				_drag = "erase"
				doc.begin_edit()
				_erase_at(cell)
			elif catalog.is_single(armed) or catalog.is_machine(str(armed["char"])):
				_place_single(cell)
			elif tool == Tool.PAINT:
				_drag = "paint"
				doc.begin_edit()
				_stroke.clear()
				_paint_to(cell)
			else:
				_drag = "rect" if tool == Tool.RECT else "line"
				_drag_start = cell
				_drag_cell = cell
		Tool.ERASER:
			_drag = "erase"
			doc.begin_edit()
			_erase_at(cell)
		Tool.EYEDROPPER:
			_eyedrop(cell)
	queue_redraw()


func _left_up(cell: Vector2i, e: InputEventMouseButton) -> void:
	var finished := _drag
	match _drag:
		"pan":
			_drag = ""
		"paint":
			doc.end_edit()
			_drag = ""
			_stroke.clear()
		"erase":
			doc.end_edit()
			_drag = ""
			_stroke.clear()
		"rect":
			var cells := _rect_cells(_drag_start, cell, e.shift_pressed)
			_commit_cells(cells)
			_drag = ""
		"line":
			_commit_cells(_line_cells(_drag_start, cell))
			_drag = ""
		"box":
			_finish_box(cell)
		"move":
			_finish_move(cell)
	if finished in ["paint", "rect", "line"]:
		_gate_char = ""   # the next gate gets the next free id
	queue_redraw()


func _place_single(cell: Vector2i) -> void:
	var res := doc.place(cell.x, cell.y, _armed_char())
	if bool(res["ok"]):
		hint.emit(str(res["text"]) if str(res["text"]) != "" else "Placed %s at (%d,%d)." % [str(armed["name"]), cell.x, cell.y])
	else:
		hint.emit("Cannot place: " + str(res["text"]))
	_refresh_ghost_problem()


func _paint_to(cell: Vector2i) -> void:
	var from := _stroke[_stroke.size() - 1] if not _stroke.is_empty() else cell
	var cells := _line_cells(from, cell)
	var ch := _armed_char()
	for c in cells:
		if doc.in_bounds(c.x, c.y) and doc.get_cell(c.x, c.y) != ch:
			var res := doc.place(c.x, c.y, ch)
			if not bool(res["ok"]):
				hint.emit("Cannot place: " + str(res["text"]))
	_stroke.append(cell)


func _erase_at(cell: Vector2i) -> void:
	_stroke.append(cell)
	doc.erase(cell.x, cell.y)


func _erase_to(cell: Vector2i) -> void:
	var from := _stroke[_stroke.size() - 1] if not _stroke.is_empty() else cell
	for c in _line_cells(from, cell):
		doc.erase(c.x, c.y)
	_stroke.append(cell)


func _commit_cells(cells: Array[Vector2i]) -> void:
	var inside: Array[Vector2i] = []
	for c in cells:
		if doc.in_bounds(c.x, c.y):
			inside.append(c)
	var n := doc.place_cells(inside, _armed_char())
	hint.emit("Placed %d tiles." % n)


func _eyedrop(cell: Vector2i) -> void:
	var t := doc.thing_at(cell.x, cell.y)
	if t.is_empty():
		hint.emit("Nothing there to pick.")
		return
	var e := catalog.entry_for_char(str(t["char"]))
	if e.is_empty():
		hint.emit("That tile is not in the catalog.")
		return
	entry_picked.emit(e)


# --- select tool

func _select_down(cell: Vector2i) -> void:
	if not doc.in_bounds(cell.x, cell.y):
		doc.clear_selection()
		return
	if doc.has_selection() and doc.sel.has_point(cell):
		_start_move(cell)
		return
	if doc.select_thing_at(cell.x, cell.y):
		_start_move(cell)
	else:
		_drag = "box"
		_drag_start = cell
		_drag_cell = cell


func _start_move(cell: Vector2i) -> void:
	_drag = "move"
	_drag_start = cell
	_drag_cell = cell
	_move_block = doc.take_block(doc.sel)
	_update_move_preview(false)


func _update_move_preview(copy: bool) -> void:
	_drag_copy = copy
	var d := _drag_cell - _drag_start
	if d == Vector2i.ZERO:
		_move_preview = {}
		return
	_move_preview = doc.preview_move(doc.sel, d, copy)


func _finish_move(cell: Vector2i) -> void:
	var d := cell - _drag_start
	var copy := Input.is_key_pressed(KEY_CTRL)
	_drag = ""
	if d == Vector2i.ZERO:
		_move_block = {}
		return
	var res := doc.move_region(doc.sel, d, copy)
	if bool(res["ok"]):
		hint.emit(str(res["text"]) if str(res["text"]) != "" else ("Copied." if copy else "Moved."))
	else:
		hint.emit("Cannot drop there: " + str(res["text"]))
	_move_block = {}
	_move_preview = {}


func _finish_box(cell: Vector2i) -> void:
	_drag = ""
	var a := Vector2i(mini(_drag_start.x, cell.x), mini(_drag_start.y, cell.y))
	var b := Vector2i(maxi(_drag_start.x, cell.x), maxi(_drag_start.y, cell.y))
	a = Vector2i(clampi(a.x, 0, doc.cols() - 1), clampi(a.y, 0, doc.rows() - 1))
	b = Vector2i(clampi(b.x, 0, doc.cols() - 1), clampi(b.y, 0, doc.rows() - 1))
	if a == b:
		doc.clear_selection()
		return
	doc.select_rect(Rect2i(a, b - a + Vector2i.ONE))
	hint.emit("Selected %d x %d tiles: drag to move, Ctrl+C / Ctrl+X to copy or cut, Delete to clear." % [b.x - a.x + 1, b.y - a.y + 1])


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	if (event as InputEventKey).keycode == KEY_ESCAPE and (has_focus() or _mouse_inside):
		if _drag != "":
			_cancel_drag()
			queue_redraw()
		elif not armed.is_empty() and (tool == Tool.PAINT or tool == Tool.RECT or tool == Tool.LINE):
			disarm_requested.emit()
		elif doc != null:
			doc.clear_selection()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- shapes

static func _line_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x := a.x
	var y := a.y
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	while true:
		out.append(Vector2i(x, y))
		if x == b.x and y == b.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
		if out.size() > 100000:
			break
	return out


static func _rect_cells(a: Vector2i, b: Vector2i, outline: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x0 := mini(a.x, b.x)
	var x1 := maxi(a.x, b.x)
	var y0 := mini(a.y, b.y)
	var y1 := maxi(a.y, b.y)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if not outline or x == x0 or x == x1 or y == y0 or y == y1:
				out.append(Vector2i(x, y))
	return out


func _refresh_ghost_problem() -> void:
	_ghost_problem = {}
	if doc == null or armed.is_empty() or not doc.in_bounds(_hover.x, _hover.y):
		return
	if tool == Tool.PAINT or tool == Tool.RECT or tool == Tool.LINE:
		var ch := _armed_char()
		if ch != ".":
			_ghost_problem = doc.placement_problem(_hover.x, _hover.y, ch)


# ---------------------------------------------------------------- drawing: helpers

func _t(sprite_name: String) -> Texture2D:
	if not _tex.has(sprite_name):
		_tex[sprite_name] = SpriteLibrary.tile(sprite_name)
	return _tex[sprite_name]


func _machine_tex(sprite_name: String) -> Texture2D:
	var key := "m:" + sprite_name
	if not _tex.has(key):
		_tex[key] = SpriteLibrary.machine(sprite_name)
	return _tex[key]


func _pit_tex(kind: String) -> Texture2D:
	var key := "p:" + kind
	if not _tex.has(key):
		_tex[key] = SpriteLibrary.pit(kind, "liquid")
	return _tex[key]


func _char_tex(pose_char: String, pose: String) -> Texture2D:
	var key := "c:%s:%s" % [pose_char, pose]
	if not _tex.has(key):
		_tex[key] = SpriteLibrary.character_pose(pose_char, pose)
	return _tex[key]


func _entry_tex(entry: Dictionary) -> Texture2D:
	var key := "e:" + str(entry.get("char", "")) + str(entry.get("name", ""))
	if not _tex.has(key):
		_tex[key] = catalog.texture(entry)
	return _tex[key]


func _pit_kind(ch: String) -> String:
	for k in SpriteLibrary.PIT_KINDS:
		if SpriteLibrary.PIT_KINDS[k] == ch:
			return k
	return ""


func _load_background() -> void:
	var bg := str(doc.get_setting("terrain", "background"))
	var base := doc.path.get_base_dir() if doc.path != "" else LevelData.art_dir(LevelData.DEFAULT_ID)
	if bg + "|" + base == _bg_name:
		return
	_bg_name = bg + "|" + base
	var dir := LevelData.resolve_background(bg, base)   # the level's own background/ folder (or the first level's)
	_bg_far = load(dir + "far.png") if ResourceLoader.exists(dir + "far.png") else null
	_bg_mid = load(dir + "mid_base.png") if ResourceLoader.exists(dir + "mid_base.png") else null
	if _bg_far == null:
		# a background folder without the game's layer names: show its first image
		var d := DirAccess.open(dir)
		if d != null:
			for f in d.get_files():
				if f.ends_with(".png"):
					_bg_far = load(dir + f)
					break


## True if the cell holds this character (outside the grid counts as empty).
func _is(rows: Array, c: int, r: int, ch: String) -> bool:
	if r < 0 or r >= rows.size() or c < 0 or c >= (rows[r] as String).length():
		return false
	return (rows[r] as String)[c] == ch


func _ch(rows: Array, c: int, r: int) -> String:
	if r < 0 or r >= rows.size() or c < 0 or c >= (rows[r] as String).length():
		return "#"
	return (rows[r] as String)[c]


func _run_name(rows: Array, prefix: String, ch: String, c: int, r: int, has_single: bool) -> String:
	var l := _is(rows, c - 1, r, ch)
	var rt := _is(rows, c + 1, r, ch)
	if l and rt:
		return prefix + "_middle"
	if rt:
		return prefix + "_start"
	if l:
		return prefix + "_end"
	return prefix + ("_single" if has_single else "_start")


func _joins_ground(rows: Array, c: int, r: int) -> bool:
	var ch := _ch(rows, c, r)
	return ch == "#" or (ch == "H" and _ch(rows, c, r - 1) != "H")


func _ground_name(rows: Array, c: int, r: int) -> String:
	if _ch(rows, c, r - 1) == "#":
		return "ground_fill"
	var l := _joins_ground(rows, c - 1, r)
	var rt := _joins_ground(rows, c + 1, r)
	if l and rt:
		return "ground_middle"
	if rt:
		return "ground_start"
	if l:
		return "ground_end"
	return "ground_single"


func _tile(sprite_name: String, c: int, r: int, mod: Color = Color.WHITE) -> void:
	var tex := _t(sprite_name)
	if tex != null:
		draw_texture_rect(tex, Rect2(c * T, r * T, T, T), false, mod)


# ---------------------------------------------------------------- drawing: the level

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), OUTSIDE_COLOR)
	if doc == null:
		return
	var rows: Array = doc.data["tiles"]
	var cols := doc.cols()
	var nrows := doc.rows()
	draw_set_transform(pan, 0.0, Vector2(zoom, zoom))
	var level_rect := Rect2(0, 0, cols * T, nrows * T)
	# visible cell range
	var top_left := screen_to_world(Vector2.ZERO)
	var bottom_right := screen_to_world(size)
	var c0 := clampi(floori(top_left.x / T), 0, cols - 1)
	var c1 := clampi(floori(bottom_right.x / T), 0, cols - 1)
	var r0 := clampi(floori(top_left.y / T), 0, nrows - 1)
	var r1 := clampi(floori(bottom_right.y / T), 0, nrows - 1)
	_draw_backdrop(level_rect, top_left, bottom_right)
	if zoom < SIMPLE_ZOOM:
		_draw_simple(rows, c0, c1, r0, r1)
	else:
		_draw_decor(rows, c0, c1, r0, r1)
		_draw_solids(rows, c0, c1, r0, r1)
		_draw_actors(rows, c0, c1, r0, r1)
		_draw_pits(rows, c0, c1, r0, r1)
		_draw_names()
	if show_grid and T * zoom >= GRID_MIN_PX:
		_draw_grid(c0, c1, r0, r1)
	draw_rect(level_rect, Color(0.4, 0.8, 1.0, 0.8), false, 2.0 / zoom)
	_draw_selection()
	_draw_tool_overlay()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_backdrop(level_rect: Rect2, tl: Vector2, br: Vector2) -> void:
	draw_rect(level_rect, Color(0.07, 0.09, 0.14))
	if show_background:
		_load_background()
		var vis := level_rect.intersection(Rect2(tl, br - tl))
		for tex_pair in [[_bg_far, FAR_TINT], [_bg_mid, MID_TINT]]:
			var tex: Texture2D = tex_pair[0]
			if tex == null or vis.size.x <= 0.0:
				continue
			var tw := float(tex.get_width())
			var th := float(tex.get_height())
			var x := floorf(vis.position.x / tw) * tw
			while x < vis.end.x:
				var y := floorf(vis.position.y / th) * th
				while y < vis.end.y:
					var piece := Rect2(x, y, tw, th).intersection(level_rect)
					if piece.size.x > 0.0 and piece.size.y > 0.0:
						draw_texture_rect_region(tex, piece, Rect2(piece.position - Vector2(x, y), piece.size), tex_pair[1])
					y += th
				x += tw
		draw_rect(level_rect, BACKDROP_SHADE)
	var title := str(doc.get_setting("meta", "title"))
	if title != "":
		draw_string(ThemeDB.fallback_font, Vector2(150, 260), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1, 1, 1, 0.3))


func _draw_simple(rows: Array, c0: int, c1: int, r0: int, r1: int) -> void:
	for r in range(r0, r1 + 1):
		var row: String = rows[r]
		for c in range(c0, c1 + 1):
			var ch := row[c]
			if ch == ".":
				continue
			var col: Color = SIMPLE_COLORS.get(ch, MACHINE_COLOR)
			draw_rect(Rect2(c * T, r * T, T, T), col)
			if catalog.is_machine(ch):
				var fp := catalog.footprint(ch)
				draw_rect(Rect2(c * T, (r - fp.y + 1) * T, fp.x * T, fp.y * T), Color(col, 0.7))


func _draw_decor(rows: Array, c0: int, c1: int, r0: int, r1: int) -> void:
	var cmin := maxi(c0 - 3, 0)
	var rmax := mini(r1 + 2, doc.rows() - 1)
	for r in range(r0, rmax + 1):
		var row: String = rows[r]
		for c in range(cmin, c1 + 1):
			var ch := row[c]
			if ch == ".":
				continue
			match ch:
				"H":
					_tile("ladder_top" if _ch(rows, c, r - 1) != "H" else "ladder_middle", c, r)
				"k":
					_tile(_run_name(rows, "panel_controls", "k", c, r, false), c, r, DECOR_TINT)
				"w":
					_tile(_run_name(rows, "panel_dark", "w", c, r, false), c, r, DECOR_TINT)
				"r":
					_tile(_run_name(rows, "rail_thin", "r", c, r, false), c, r)
				"m":
					_tile("monitor_text", c, r, DECOR_TINT)
				"t":
					_tile("monitor_tv_text", c, r, DECOR_TINT)
				"g":
					_tile("gear_full", c, r, DECOR_TINT)
				"i":
					_tile("siren_orange" if int(c / 2.0) % 2 == 0 else "siren_blue", c, r)
				"l":
					_tile("lamp_pole_green", c, r)
				"c":
					_tile("canister_blue_vertical" if c % 2 == 0 else "canister_yellow_vertical", c, r, DECOR_TINT)
				"~":
					_tile(_run_name(rows, "slime_floor", "~", c, r, true), c, r)
				"E":      # the exit: a door standing on this tile, in the middle of it (see ExitDoor)
					var door := _t("door_exit")
					if door != null:
						draw_texture(door, Vector2((c + 0.5) * T - door.get_width() / 2.0, (r + 1) * T - door.get_height()))
				"K":
					_tile("siren_green", c, r, Color(CHECKPOINT_DIM, CHECKPOINT_DIM, CHECKPOINT_DIM))
				_:
					if catalog.is_machine(ch):
						_draw_machine(ch, c, r, Color.WHITE)
					elif ch >= "1" and ch <= "9":
						_draw_gate(ch, c, r)
					elif str(catalog.entry_for_char(ch).get("behavior", "")) == "decor":   # a picture that is only a registry entry
						_tile(str((catalog.entry_for_char(ch).get("sprite", {}) as Dictionary).get("tile", "")), c, r, DECOR_TINT)


func _draw_machine(ch: String, c: int, r: int, mod: Color) -> void:
	var e := catalog.entry_for_char(ch)
	if e.is_empty():
		return
	var tex := _entry_tex(e)
	if tex == null:
		return
	var fp := catalog.footprint(ch)
	var pos := Vector2(c * T, (r - fp.y + 1) * T)
	draw_texture(tex, pos, mod)
	var sprite_name: String = (e["sprite"] as Dictionary).get("machine", "")
	var leds := _machine_tex(sprite_name + "_leds_a")
	if leds != null:
		draw_texture(leds, pos, Color(mod, mod.a * 0.8))


func _draw_gate(ch: String, c: int, r: int) -> void:
	var rect := Rect2(c * T, r * T, T, T)
	draw_rect(rect, Color(1.0, 0.1, 0.25, 0.22))
	draw_line(Vector2(c * T + T / 2.0, r * T), Vector2(c * T + T / 2.0, (r + 1) * T), Color(1.0, 0.3, 0.4, 0.9), 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(c * T + 8, r * T + 26), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.9, 0.9, 0.9))


func _draw_solids(rows: Array, c0: int, c1: int, r0: int, r1: int) -> void:
	for r in range(r0, r1 + 1):
		var row: String = rows[r]
		for c in range(c0, c1 + 1):
			match row[c]:
				"#":
					_tile(_ground_name(rows, c, r), c, r)
				"X":
					_tile("block_metal_x", c, r)
				"O":
					_tile("block_metal_orange", c, r)
				"=":
					_tile(_run_name(rows, "ledge", "=", c, r, true), c, r)
				"^":
					_tile("spikes_up", c, r)
				"v":
					_tile("spikes_down", c, r)
				_:
					var kind := catalog.entry_for_char(row[c])
					if str(kind.get("behavior", "")) in ["solid", "barrier"]:   # a block that is only a registry entry (a barrier is invisible in the game, shown here)
						_tile(str((kind.get("sprite", {}) as Dictionary).get("tile", "")), c, r)


func _draw_feet_sprite(tex: Texture2D, c: int, r: int, mod: Color) -> void:
	if tex == null:
		return
	var sz := tex.get_size() * PlayerSprite.base_scale(tex)
	draw_texture_rect(tex, Rect2(Vector2((c + 0.5) * T - sz.x / 2.0, (r + 1) * T - sz.y), sz), false, mod)


func _draw_actors(rows: Array, c0: int, c1: int, r0: int, r1: int) -> void:
	var typed: Array[String] = []
	for r in range(r0, r1 + 1):
		var row: String = rows[r]
		for c in range(c0, c1 + 1):
			var ch := row[c]
			if ch == "P":
				_draw_feet_sprite(_char_tex("player", CharacterPoses.standing("player")), c, r, Color.WHITE)
			elif ch == "B":
				_draw_feet_sprite(_char_tex("zombie", CharacterPoses.standing("zombie")), c, r, Color.WHITE)
				if typed.is_empty():
					typed = doc.tile_rows()
				var span := LevelData.bro_flat_span(typed, c, r)
				if span < LevelData.bro_min_flat_tiles():
					draw_rect(Rect2(c * T, r * T, T, T), Color(1, 0.2, 0.2, 0.25))


func _draw_pits(rows: Array, c0: int, c1: int, r0: int, r1: int) -> void:
	for r in range(r0, r1 + 1):
		var row: String = rows[r]
		for c in range(c0, c1 + 1):
			var kind := _pit_kind(row[c])
			if kind == "":
				continue
			var tex := _pit_tex(kind)
			var top := not _is(rows, c, r - 1, row[c])
			var y := r * T + (20 if top else 0)
			var rect := Rect2(c * T, y, T, T - (20 if top else 0))
			if tex != null:
				draw_texture_rect_region(tex, rect, Rect2(0, 0, tex.get_width(), tex.get_height() * rect.size.y / T))
			else:
				draw_rect(rect, SIMPLE_COLORS.get(row[c], Color.WHITE))
			if top:
				draw_line(Vector2(c * T, y), Vector2((c + 1) * T, y), Color(1, 1, 1, 0.55), 2.0)


func _draw_names() -> void:
	if zoom < 0.4:
		return
	var objects: Dictionary = doc.data["objects"]
	for key in objects:
		var o: Dictionary = objects[key]
		var nm := str(o.get("name", ""))
		if nm == "":
			continue
		var p := (key as String).split(",")
		var c := int(p[0])
		var r := int(p[1])
		var base_y := (r + 1) * T - 130.0 if str(o.get("type", "")) != "lock_terminal" else (r - 2) * T - 12.0
		draw_string(ThemeDB.fallback_font, Vector2(c * T - 10, base_y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 0.7, 0.95))


func _draw_grid(c0: int, c1: int, r0: int, r1: int) -> void:
	var line_w := 1.0 / zoom
	var y0 := r0 * T
	var y1 := (r1 + 1) * T
	var x0 := c0 * T
	var x1 := (c1 + 1) * T
	for c in range(c0, c1 + 2):
		var major := c % 10 == 0
		draw_line(Vector2(c * T, y0), Vector2(c * T, y1), Color(1, 1, 1, 0.16 if major else 0.07), line_w)
	for r in range(r0, r1 + 2):
		var major := r % 10 == 0
		draw_line(Vector2(x0, r * T), Vector2(x1, r * T), Color(1, 1, 1, 0.16 if major else 0.07), line_w)


func _draw_selection() -> void:
	if doc.has_selection():
		var rect := Rect2(Vector2(doc.sel.position) * T, Vector2(doc.sel.size) * T)
		draw_rect(rect, Color(EditorTheme.ACCENT, 0.15))
		draw_rect(rect, EditorTheme.ACCENT, false, 3.0 / zoom)
	if _ping_cell.x >= 0:
		var k := 1.0 - clampf(_ping_time / 1.6, 0.0, 1.0)
		var centre := (Vector2(_ping_cell) + Vector2(0.5, 0.5)) * T
		draw_arc(centre, T * (0.6 + k * 1.5), 0, TAU, 32, Color(1, 0.9, 0.3, 1.0 - k), 4.0 / zoom)


# ---------------------------------------------------------------- drawing: ghosts and tool overlays

func _ghost_mod(prob: Dictionary) -> Color:
	var tint := Color.WHITE
	if not prob.is_empty():
		tint = GHOST_BAD if str(prob["level"]) == "error" else GHOST_WARN
	return Color(tint.r, tint.g, tint.b, GHOST_ALPHA)


## Draw one map character the way the palette entry looks, at a cell, with a colour multiplier (used for ghosts).
func _draw_ghost_char(ch: String, c: int, r: int, mod: Color) -> void:
	var e := catalog.entry_for_char(ch)
	if catalog.is_machine(ch):
		_draw_machine(ch, c, r, mod)
		return
	if ch >= "1" and ch <= "9":
		draw_rect(Rect2(c * T, r * T, T, T), Color(1.0, 0.1, 0.25, 0.3) * mod)
		draw_string(ThemeDB.fallback_font, Vector2(c * T + 8, r * T + 26), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, mod)
		return
	var tex := _entry_tex(e) if not e.is_empty() else null
	if tex == null:
		return
	var sprite: Dictionary = e.get("sprite", {})
	if sprite.has("character"):
		_draw_feet_sprite(tex, c, r, mod)
	else:
		draw_texture_rect(tex, Rect2(c * T, r * T, T, T), false, mod)


func _draw_tool_overlay() -> void:
	var hovered_ok := doc.in_bounds(_hover.x, _hover.y)
	if hovered_ok and _drag == "":
		draw_rect(Rect2(_hover.x * T, _hover.y * T, T, T), Color(1, 1, 1, 0.5), false, 2.0 / zoom)
	match _drag:
		"rect", "line":
			var cells := _rect_cells(_drag_start, _drag_cell, Input.is_key_pressed(KEY_SHIFT)) if _drag == "rect" else _line_cells(_drag_start, _drag_cell)
			var ch := _armed_char()
			var mod := Color(1, 1, 1, GHOST_ALPHA)
			for c in cells:
				if doc.in_bounds(c.x, c.y):
					_draw_ghost_char(ch, c.x, c.y, mod)
			return
		"box":
			var a := Vector2i(mini(_drag_start.x, _drag_cell.x), mini(_drag_start.y, _drag_cell.y))
			var b := Vector2i(maxi(_drag_start.x, _drag_cell.x), maxi(_drag_start.y, _drag_cell.y))
			var rect := Rect2(Vector2(a) * T, Vector2(b - a + Vector2i.ONE) * T)
			draw_rect(rect, Color(0.4, 0.7, 1.0, 0.15))
			draw_rect(rect, Color(0.4, 0.7, 1.0, 0.9), false, 2.0 / zoom)
			return
		"move":
			_draw_move_ghost()
			return
	if not hovered_ok or armed.is_empty() or not (tool == Tool.PAINT or tool == Tool.RECT or tool == Tool.LINE):
		return
	var ch2 := _armed_char()
	if ch2 == ".":
		return
	_draw_ghost_char(ch2, _hover.x, _hover.y, _ghost_mod(_ghost_problem))
	if not _ghost_problem.is_empty():
		_draw_label(str(_ghost_problem["text"]), _hover, EditorTheme.ERROR if str(_ghost_problem["level"]) == "error" else EditorTheme.WARN)


func _draw_move_ghost() -> void:
	var d := _drag_cell - _drag_start
	if d == Vector2i.ZERO or _move_block.is_empty():
		return
	var src := doc.sel
	if not _drag_copy:
		# the picked-up original is dimmed (the thing is "in the hand")
		draw_rect(Rect2(Vector2(src.position) * T, Vector2(src.size) * T), Color(0.05, 0.06, 0.09, 0.6))
	var lvl := str(_move_preview.get("level", "")) if not _move_preview.is_empty() else ""
	var mod := _ghost_mod({"level": lvl} if lvl != "" else {})
	var brows: Array = _move_block["rows"]
	for dr in int(_move_block["h"]):
		var s: String = brows[dr]
		for dc in int(_move_block["w"]):
			if s[dc] != ".":
				_draw_ghost_char(s[dc], src.position.x + dc + d.x, src.position.y + dr + d.y, mod)
	var dest := Rect2(Vector2(src.position + d) * T, Vector2(src.size) * T)
	var col := Color(1, 1, 1, 0.8) if mod.r == 1.0 and mod.g == 1.0 and mod.b == 1.0 else Color(mod.r, mod.g, mod.b, 0.9)
	draw_rect(dest, col, false, 2.0 / zoom)
	if not _move_preview.is_empty() and str(_move_preview["text"]) != "":
		_draw_label(str(_move_preview["text"]), src.position + d, EditorTheme.ERROR if not bool(_move_preview["ok"]) else EditorTheme.WARN)


func _draw_label(text: String, cell: Vector2i, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var fs := int(16.0 / zoom)
	var pos := Vector2(cell.x * T, cell.y * T - 8.0 / zoom)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_rect(Rect2(pos.x - 4.0 / zoom, pos.y - fs, w + 8.0 / zoom, fs + 6.0 / zoom), Color(0, 0, 0, 0.75))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
