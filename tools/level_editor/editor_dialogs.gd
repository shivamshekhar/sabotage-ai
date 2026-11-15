class_name EditorDialogs
extends RefCounted
## Small modal dialogs of the level editor (message, confirmation, new level, help). Each function creates the dialog under
## `parent`, shows it centred and frees it when closed.

# HELP_TEXT: the text of the shortcut list shown by Help > Shortcuts (BBCode).
const HELP_TEXT := """[b]Files[/b]
Ctrl+N new    Ctrl+O open    Ctrl+S save    Ctrl+Shift+S save as    F5 play-test    Ctrl+Q quit

[b]Tools[/b]
V select / move    B paint    R rectangle    L line    E eraser    I eyedropper    Esc put the item down
Left click place / select    Right click erase    Middle mouse or Space+drag pan    Mouse wheel zoom
F fit the level in the view    1 zoom 100%    G grid on/off    Ctrl+B hide/show the drawer    Ctrl+F search the palette

[b]Editing[/b]
Ctrl+Z undo    Ctrl+Y or Ctrl+Shift+Z redo
Select tool: click a thing to select it, drag it to move (it turns transparent while held; red = not allowed),
Ctrl+drag copies, drag on empty space to box-select a group of tiles
Delete remove    Ctrl+D duplicate    Arrow keys nudge the selection by one tile
Ctrl+C copy    Ctrl+X cut    Ctrl+V paste at the mouse (then it is selected and can be dragged)
Rectangle tool: Shift = outline only

[b]Placing[/b]
Machines are placed by their bottom-left tile and grow to the right and up; the area must be free.
Only one player spawn and one exit exist: placing another moves it.
A lock terminal opens the laser gate named in its values (auto = the nearest one) with the puzzle you choose.

[b]Windows[/b]
Tab "Level": the canvas. Tab "Minigames": the minigame designer.
The list at the bottom shows what is wrong with the level; click an entry to jump to it.
"""


## Show a message with an OK button.
static func message(parent: Node, title: String, text: String) -> void:
	var d := AcceptDialog.new()
	d.title = title
	d.dialog_text = text
	d.dialog_autowrap = true
	d.min_size = Vector2i(420, 120)
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	parent.add_child(d)
	d.popup_centered()


## Ask a yes/no question; on_ok runs when the user accepts. An optional third button (extra_text) runs on_extra.
static func confirm(parent: Node, title: String, text: String, ok_text: String, on_ok: Callable, extra_text: String = "", on_extra: Callable = Callable()) -> void:
	var d := ConfirmationDialog.new()
	d.title = title
	d.dialog_text = text
	d.dialog_autowrap = true
	d.min_size = Vector2i(460, 120)
	d.ok_button_text = ok_text
	if extra_text != "":
		d.add_button(extra_text, true, "extra")
		d.custom_action.connect(func(_a: StringName) -> void:
			on_extra.call()
			d.queue_free())
	d.confirmed.connect(func() -> void:
		on_ok.call()
		d.queue_free())
	d.canceled.connect(d.queue_free)
	parent.add_child(d)
	d.popup_centered()


## The "New level" dialog: asks for the size; on_ok(cols, rows) runs when accepted.
static func new_level(parent: Node, on_ok: Callable) -> void:
	var d := ConfirmationDialog.new()
	d.title = "New level"
	d.ok_button_text = "Create"
	var grid := GridContainer.new()
	grid.columns = 2
	d.add_child(grid)
	var spins: Array[SpinBox] = []
	for f in [["Columns (tiles wide)", 60.0], ["Rows (tiles high)", 24.0]]:
		var l := Label.new()
		l.text = str(f[0])
		grid.add_child(l)
		var sb := SpinBox.new()
		sb.min_value = EditorDocument.MIN_GRID
		sb.max_value = EditorDocument.MAX_GRID
		sb.value = float(f[1])
		grid.add_child(sb)
		spins.append(sb)
	var note := Label.new()
	note.text = "A new level starts with a floor, walls, the player spawn and the exit."
	d.add_child(note)
	d.confirmed.connect(func() -> void:
		on_ok.call(int(spins[0].value), int(spins[1].value))
		d.queue_free())
	d.canceled.connect(d.queue_free)
	parent.add_child(d)
	d.popup_centered(Vector2i(420, 160))


## The shortcut list.
static func help(parent: Node) -> void:
	var d := AcceptDialog.new()
	d.title = "Level editor shortcuts"
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.text = HELP_TEXT
	text.custom_minimum_size = Vector2(760, 440)
	text.scroll_active = true
	d.add_child(text)
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	parent.add_child(d)
	d.popup_centered()
