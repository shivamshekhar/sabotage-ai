class_name EditorProblems
extends PanelContainer
## The live validation list at the bottom of the window: the level's errors and warnings (EditorDocument.validate()).
## Clicking one jumps to the offending tile. The list is rebuilt a moment after the last edit so painting stays fast.

## Emitted when the user clicks a problem that has a tile.
signal jump_requested(cell: Vector2i)

# REFRESH_DELAY: seconds to wait after the last change before the list is recomputed. Lower: the list follows edits more
# closely; higher: less work while painting on a big level.
const REFRESH_DELAY := 0.35

var doc: EditorDocument
var _summary: Label
var _list: ItemList
var _timer: Timer
var _entries: Array[Dictionary] = []


func _ready() -> void:
	custom_minimum_size = Vector2(0, 110)
	var col := VBoxContainer.new()
	add_child(col)
	_summary = Label.new()
	col.add_child(_summary)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_selected)
	_list.item_activated.connect(_on_selected)
	col.add_child(_list)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = REFRESH_DELAY
	_timer.timeout.connect(refresh)
	add_child(_timer)
	if doc != null:
		refresh()


## Show the problems of a document.
func set_document(d: EditorDocument) -> void:
	if doc != null:
		doc.changed.disconnect(_on_changed)
	doc = d
	doc.changed.connect(_on_changed)
	if _list != null:
		refresh()


func _on_changed(_kind: String) -> void:
	if _timer != null:
		_timer.start()


## Recompute and show the list now.
func refresh() -> void:
	if doc == null or _list == null:
		return
	_entries = doc.validate()
	_list.clear()
	var errors := 0
	var warnings := 0
	for e in _entries:
		var is_error := str(e["level"]) == "error"
		if is_error:
			errors += 1
		else:
			warnings += 1
		var cell: Vector2i = e["cell"]
		var text := ("ERROR  " if is_error else "warning  ") + str(e["text"])
		if cell.x >= 0:
			text += "   [click to jump]"
		var i := _list.add_item(text)
		_list.set_item_custom_fg_color(i, EditorTheme.ERROR if is_error else EditorTheme.WARN)
	if _entries.is_empty():
		_summary.text = "VALIDATION: the level is valid."
		_summary.add_theme_color_override("font_color", EditorTheme.ACCENT)
	else:
		_summary.text = "VALIDATION: %d error(s), %d warning(s)" % [errors, warnings]
		_summary.add_theme_color_override("font_color", EditorTheme.ERROR if errors > 0 else EditorTheme.WARN)


## The number of errors in the last validation (for the title bar and play-test).
func error_count() -> int:
	var n := 0
	for e in _entries:
		if str(e["level"]) == "error":
			n += 1
	return n


func _on_selected(i: int) -> void:
	if i < 0 or i >= _entries.size():
		return
	var cell: Vector2i = _entries[i]["cell"]
	if cell.x >= 0:
		jump_requested.emit(cell)
