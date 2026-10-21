extends Panel
class_name ProfilesPanel
## "Who's playing?": picks, adds, renames and deletes the players in Settings.players. Opened from the player
## button beside the song menu's gear; names are typed on the shared keyboard.

## The player asked to close the panel (Close, or a player was picked).
signal close_requested()

@export var keyboard: OQ_UI2DKeyboard

const CHECK_ICON := preload("res://game/ui/icons/check.svg")
const EDIT_ICON := preload("res://game/ui/edit.svg")
const TRASH_ICON := preload("res://game/ui/icons/trash-2.svg")
## Height of a player row and its buttons: 4 degrees at the panel's 1.9 m.
const ROW_HEIGHT := 56.0
const ROW_SEPARATION := 6
const NOTE_TEXT := "Height and left-handed in Settings are kept per player."
const ADD_TEXT := "Add player"
const FULL_TEXT := "%d players max"
const NAME_PROMPT := "Type the new player's name"
const RENAME_PROMPT := "Type a new name for %s"

@onready var _rows := $Margin/VBox/Rows as VBoxContainer
@onready var _note := $Margin/VBox/Note as Label
@onready var _add_button := $Margin/VBox/Add_Button as Button

## The keyboard is open for this panel: adding a player, or renaming _renaming.
var _typing := false
var _renaming := ""
## The player whose row asks to confirm deleting them, or "".
var _deleting := ""

func _ready() -> void:
	UI_AudioEngine.attach_children(self)
	keyboard.text_input_enter.connect(_on_name_entered)
	keyboard.text_input_cancel.connect(_stop_typing)
	refresh()

## Rebuilds the rows from Settings.players: the current player pressed (UI_ACCENT) with a check.
func refresh() -> void:
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	for player: Dictionary in Settings.players:
		var row := _make_row(player)
		_rows.add_child(row)
		UI_AudioEngine.attach_children(row)
	var full := Settings.players.size() >= Settings.MAX_PLAYERS
	_add_button.text = FULL_TEXT % Settings.MAX_PLAYERS if full else ADD_TEXT
	_add_button.disabled = full or _typing
	if not _typing:
		_note.text = NOTE_TEXT
	_redraw()

## One player's row: pick, Rename and Delete; or, while deleting, the question with Delete and Cancel.
func _make_row(player: Dictionary) -> HBoxContainer:
	var player_name: String = player.name
	var count := Highscores.count_records(player_name)
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = ROW_HEIGHT
	row.add_theme_constant_override(&"separation", ROW_SEPARATION)
	if player_name == _deleting:
		var question := Label.new()
		question.text = ("Delete %s? They have no records." % player_name) if count == 0 else \
				("Delete %s? Their %s stay in the table." % [player_name, _records_text(count)])
		question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		question.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(question)
		row.add_child(_make_button("Delete", TRASH_ICON, _delete.bind(player_name)))
		row.add_child(_make_button("Cancel", null, _ask_delete.bind("")))
		return row
	var current := player_name == Settings.player_name
	var pick := Button.new()
	pick.text = "%s · %s" % [player_name, _records_text(count)]
	pick.icon = CHECK_ICON if current else null
	pick.disabled = _typing
	pick.pressed.connect(_pick.bind(player_name))
	pick.toggle_mode = true
	pick.set_pressed_no_signal(current)
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	pick.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pick.clip_text = true
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pick)
	row.add_child(_make_button("Rename", EDIT_ICON, _start_typing.bind(player_name)))
	var delete := _make_button("Delete", TRASH_ICON, _ask_delete.bind(player_name))
	if current:
		# the current player can't be deleted; an invisible button keeps the columns lined up
		delete.disabled = true
		delete.modulate = Color.TRANSPARENT
		delete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(delete)
	return row

## A row button with its icon beside the word, off while a name is being typed.
func _make_button(text: String, icon: Texture2D, on_pressed: Callable) -> Button:
	var button := IconButton.new()
	button.text = text
	button.icon = icon
	button.disabled = _typing
	button.pressed.connect(on_pressed)
	return button

## "no records", "1 record" or "3 records".
static func _records_text(count: int) -> String:
	return "no records" if count == 0 else "1 record" if count == 1 else "%d records" % count

## Makes the player current and closes the panel.
func _pick(player_name: String) -> void:
	if player_name != Settings.player_name:
		Settings.switch_player(player_name)
	close_requested.emit()

## Asks in the row whether to delete the player ("" puts the row back).
func _ask_delete(player_name: String) -> void:
	_deleting = player_name
	refresh()

## Deletes the player; their records stay under their name.
func _delete(player_name: String) -> void:
	_deleting = ""
	Settings.delete_player(player_name)
	refresh()

## Opens the keyboard to rename player_name, or to name a new player when it is "".
func _start_typing(player_name: String) -> void:
	_typing = true
	_renaming = player_name
	_deleting = ""
	_note.text = RENAME_PROMPT % player_name if player_name else NAME_PROMPT
	keyboard._text_edit.placeholder_text = "Type a name"
	keyboard._text_edit.text = player_name
	keyboard._text_edit.set_caret_column(player_name.length())
	keyboard._on_TextEdit_text_changed()
	keyboard.visible = true
	keyboard._text_edit.grab_focus()
	refresh()

## Saves the typed name, or says on the note line why it can't be used and keeps the keyboard open.
func _on_name_entered(text: String = "") -> void:
	if not _typing:
		return
	var problem := Settings.player_name_problem(text, _renaming)
	if problem:
		_note.text = problem
		keyboard.visible = true
		_redraw()
		return
	if _renaming:
		var old_name: String = Settings.find_player(_renaming).name
		Highscores.rename_player(old_name, text.strip_edges())
		Settings.rename_player(old_name, text)
	else:
		Settings.add_player(text)
	_stop_typing()

## Closes the keyboard and gives the rows back.
func _stop_typing() -> void:
	if not _typing:
		return
	_typing = false
	keyboard.visible = false
	refresh()

func _on_close_pressed() -> void:
	_stop_typing()
	_deleting = ""
	close_requested.emit()

## Redraws the canvas: the rows change without pointer input after typing.
func _redraw() -> void:
	if not is_inside_tree():
		return
	var canvas := get_viewport().get_parent() as OQ_UI2DCanvas
	if canvas:
		canvas._input_update()
