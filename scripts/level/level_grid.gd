class_name LevelGrid
extends RefCounted
## A small drawing API for building a level map in code. A map is a grid of one-character tiles
## (see the legend in level_data.gd); this class lets a level be written as calls such as
## ledge(), ladder() or crate_stack() instead of hand-counted strings. to_rows() produces the
## same Array[String] the Level builder reads, so every level, drawn either way, is just rows of text.
##
## Coordinates are (column, row), counted from the top-left corner, starting at 0. Ranges are
## inclusive at both ends: fill(2, 5, 4, 5, "#") fills columns 2, 3 and 4 of row 5.

var cols := 0
var rows := 0

var _cells: Array = []   # rows, each an Array of one-character strings


func _init(width_cols: int, height_rows: int) -> void:
	cols = width_cols
	rows = height_rows
	for r in rows:
		var row := []
		row.resize(cols)
		row.fill(".")
		_cells.append(row)


## Character at a cell ("#" for anywhere outside the grid).
func get_cell(c: int, r: int) -> String:
	if c < 0 or c >= cols or r < 0 or r >= rows:
		return "#"
	return _cells[r][c]


## Put one character in one cell.
func put(c: int, r: int, ch: String) -> void:
	if c < 0 or c >= cols or r < 0 or r >= rows:
		push_error("LevelGrid: cell (%d, %d) is outside the %dx%d grid" % [c, r, cols, rows])
		return
	_cells[r][c] = ch


## Fill a rectangle of cells (inclusive) with one character.
func fill(c0: int, r0: int, c1: int, r1: int, ch: String) -> void:
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			put(c, r, ch)


## Empty a rectangle of cells (carve a hole, clear decor).
func carve(c0: int, r0: int, c1: int, r1: int) -> void:
	fill(c0, r0, c1, r1, ".")


## A one-tile-thick solid slab on row r, from column c0 to c1.
func slab(c0: int, c1: int, r: int) -> void:
	fill(c0, r, c1, r, "#")


## One-way ledges on row r (the player can jump up through them and stand on top).
func ledge(c0: int, c1: int, r: int) -> void:
	fill(c0, r, c1, r, "=")


## A ladder in column c from r_top (where its deck is) down to r_bottom (the lowest rung).
## The tile just below r_bottom must be solid, so the ladder has a floor to start from.
func ladder(c: int, r_top: int, r_bottom: int) -> void:
	fill(c, r_top, c, r_bottom, "H")


## Floor spikes on row r (they sit on the tile below).
func spikes(c0: int, c1: int, r: int) -> void:
	fill(c0, r, c1, r, "^")


## Ceiling spikes hanging in row r (they hang from the tile above).
func ceiling_spikes(c0: int, c1: int, r: int) -> void:
	fill(c0, r, c1, r, "v")


## A laser force field in column c from row r0 down to row r1. id is one digit, "1" to "9"; the
## terminal listed for that id in LevelData.terminals() switches the field off.
func laser(c: int, r0: int, r1: int, id: String) -> void:
	fill(c, r0, c, r1, id)


## A deadly pit across columns c0 to c1: a hole `depth` rows deep whose top row is r_top (the walking surface),
## filled with `liquid` (a map character from SpriteLibrary.PIT_KINDS) except for the top row, which is left
## as air so the liquid sits one tile below the walkway. The row under the pit must be solid.
func pit(c0: int, c1: int, r_top: int, liquid: String, depth: int = 3) -> void:
	carve(c0, r_top, c1, r_top + depth - 1)
	fill(c0, r_top + 1, c1, r_top + depth - 1, liquid)


## Machine letters mark the bottom-LEFT tile of a footprint this many tiles wide (see level_data.gd).
const MACHINE_WIDTHS := {"G": 2, "S": 3, "M": 4, "R": 1, "L": 2}


## A left-right mirror image of this grid. Machine letters are moved so their footprints still stand where the
## mirrored machine is (their letter must stay at the left edge of the footprint).
func mirrored() -> LevelGrid:
	var out := LevelGrid.new(cols, rows)
	for r in rows:
		for c in cols:
			var ch: String = _cells[r][c]
			if ch == ".":
				continue
			var target := cols - 1 - c
			if MACHINE_WIDTHS.has(ch):
				target -= MACHINE_WIDTHS[ch] - 1
			out._cells[r][target] = ch
	return out


## Copy every non-empty cell of `other` into this grid, with its top-left corner at (col_off, row_off).
## Cells that fall outside this grid are dropped.
func paste(other: LevelGrid, col_off: int, row_off: int) -> void:
	for r in other.rows:
		for c in other.cols:
			var ch: String = other._cells[r][c]
			if ch != "." and r + row_off >= 0 and r + row_off < rows and c + col_off >= 0 and c + col_off < cols:
				_cells[r + row_off][c + col_off] = ch


## A column of crates, `height` tiles tall, whose lowest crate is on row r_bottom. ch is "X" (metal)
## or "O" (orange).
func crate_stack(c: int, r_bottom: int, height: int, ch: String = "X") -> void:
	fill(c, r_bottom - height + 1, c, r_bottom, ch)


## The map as rows of text, top row first.
func to_rows() -> Array[String]:
	var out: Array[String] = []
	for r in rows:
		out.append("".join(PackedStringArray(_cells[r])))
	return out
