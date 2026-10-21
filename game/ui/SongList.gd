extends ScrollContainer
class_name SongList
## The song menu's list: one row per song (cover and name) in the ItemList look, where the selected row is
## SELECTED_SCALE times as big and its neighbours shrink step by step to normal size at the list's edges.
## It keeps the few ItemList calls the menu uses (add_item, select, item_count...).

## A row was pressed (not emitted by select()).
signal item_selected(index: int)

## Size of the selected row, and of a row at the list's edge, relative to normal.
const SELECTED_SCALE := 1.25
const EDGE_SCALE := 1.0
## Normal row height, cover size and font size, in px (the theme's 28 px text and 72 px covers).
const ROW_HEIGHT := 76.0
const COVER_SIZE := 72.0
const FONT_SIZE := 28.0
const ROW_SEPARATION := 6

var _rows := VBoxContainer.new()
var _selected := -1

## Rows in the list.
var item_count: int:
	get:
		return _rows.get_child_count()

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_theme_stylebox_override(&"panel", get_theme_stylebox(&"panel", &"ItemList"))
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override(&"separation", ROW_SEPARATION)
	add_child(_rows)

## Adds a row and returns its index.
func add_item(text: String, icon: Texture2D) -> int:
	var row := Button.new()
	row.text = text
	row.icon = icon
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.clip_text = true
	row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"h_separation", get_theme_constant(&"h_separation", &"ItemList"))
	var index := _rows.get_child_count()
	row.pressed.connect(func() -> void:
		select(index)
		item_selected.emit(index))
	_rows.add_child(row)
	UI_AudioEngine.attach_button(row)
	_style_row(index)
	return index

## Removes every row.
func clear() -> void:
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	_selected = -1

## Marks a row selected (-1: none) and sizes the rows around it.
func select(index: int) -> void:
	_selected = index
	for i in item_count:
		_style_row(i)
	_redraw.call_deferred()

func deselect_all() -> void:
	select(-1)

func set_item_icon(index: int, icon: Texture2D) -> void:
	_row(index).icon = icon

## Text colour of a row (favourites are yellow).
func set_item_custom_fg_color(index: int, color: Color) -> void:
	var row := _row(index)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		row.add_theme_color_override(state, color)

## Scrolls the selected row into view once the rows have their new sizes.
func ensure_current_is_visible() -> void:
	if _selected >= 0:
		_scroll_to.call_deferred(_selected, false)

## Scrolls so the row sits in the middle of the list (the scroll bar stops at the ends), once the rows have
## their new sizes.
func center_on(index: int) -> void:
	_scroll_to.call_deferred(index, true)

## Waits a frame for the rows to take their sizes, then scrolls to the row.
func _scroll_to(index: int, center: bool) -> void:
	await get_tree().process_frame
	if index >= item_count:
		return
	var row := _row(index)
	if center:
		scroll_vertical = int(row.position.y + (row.size.y - size.y) / 2.0)
	else:
		ensure_control_visible(row)
	_redraw()

func _row(index: int) -> Button:
	return _rows.get_child(index) as Button

## Gives a row the ItemList look (selected, hover, plain) and its size for its distance from the selection.
func _style_row(index: int) -> void:
	var row := _row(index)
	var selected := get_theme_stylebox(&"selected", &"ItemList")
	var plain := StyleBoxEmpty.new()
	plain.content_margin_left = selected.content_margin_left
	plain.content_margin_right = selected.content_margin_right
	row.add_theme_stylebox_override(&"normal", selected if index == _selected else plain)
	row.add_theme_stylebox_override(&"hover", selected if index == _selected else get_theme_stylebox(&"hovered", &"ItemList"))
	row.add_theme_stylebox_override(&"pressed", selected)
	row.add_theme_stylebox_override(&"hover_pressed", selected)
	row.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	var row_scale := EDGE_SCALE
	if _selected >= 0:
		# rows from the selected one to the list's edge (half the visible rows) step down to EDGE_SCALE
		var edge_rows := maxf(1.0, size.y / 2.0 / (ROW_HEIGHT + ROW_SEPARATION))
		row_scale = lerpf(SELECTED_SCALE, EDGE_SCALE, clampf(absi(index - _selected) / edge_rows, 0.0, 1.0))
	row.custom_minimum_size.y = roundf(ROW_HEIGHT * row_scale)
	row.add_theme_font_size_override(&"font_size", roundi(FONT_SIZE * row_scale))
	row.add_theme_constant_override(&"icon_max_width", roundi(COVER_SIZE * row_scale))

## Redraws the canvas: sizes and scrolling change after the pointer input that caused them.
func _redraw() -> void:
	var canvas := get_viewport().get_parent() as OQ_UI2DCanvas
	if canvas:
		canvas._input_update()
