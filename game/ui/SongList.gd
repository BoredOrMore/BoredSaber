extends ScrollContainer
class_name SongList
## The song menu's list: one row per song (cover and name) in the ItemList look, every row the same size; the
## selected one only changes its background (resizing rows made players dizzy). Empty space above the first row
## and below the last lets any row scroll to the middle (center_on), gliding over GLIDE_SECONDS.
## It keeps the few ItemList calls the menu uses (add_item, select, item_count...).

## A row was pressed (not emitted by select()).
signal item_selected(index: int)

## Row height, cover size and padding, in px: 48 px rows are 3.2 degrees at the menu's 2 m, with the theme's
## 28 px text; a 40 px cover with 4 px above and below fills the row.
const ROW_HEIGHT := 48.0
const COVER_SIZE := 40
const ROW_PADDING := 4.0
const ROW_SEPARATION := 4
## How long scrolling to a row takes (eased, so the list never snaps).
const GLIDE_SECONDS := 0.18

## Content: empty space, the rows, empty space.
var _content := VBoxContainer.new()
var _top := Control.new()
var _rows := VBoxContainer.new()
var _bottom := Control.new()
var _selected := -1
var _glide: Tween

## Rows in the list.
var item_count: int:
	get:
		return _rows.get_child_count()

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_theme_stylebox_override(&"panel", get_theme_stylebox(&"panel", &"ItemList"))
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override(&"separation", 0)
	_rows.add_theme_constant_override(&"separation", ROW_SEPARATION)
	_content.add_child(_top)
	_content.add_child(_rows)
	_content.add_child(_bottom)
	add_child(_content)
	resized.connect(_pad_ends)

## Adds a row and returns its index.
func add_item(text: String, icon: Texture2D) -> int:
	var row := Button.new()
	row.text = text
	row.icon = icon
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.clip_text = true
	row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.custom_minimum_size.y = ROW_HEIGHT
	row.add_theme_constant_override(&"icon_max_width", COVER_SIZE)
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
	# a new list starts with its first row at the top, not after the empty space
	_show_first_row.call_deferred()

## Marks a row selected (-1: none); the list doesn't move, so a row picked with the pointer stays under it.
func select(index: int) -> void:
	var previous := _selected
	_selected = index
	for i in [previous, index]:
		if i >= 0 and i < item_count:
			_style_row(i)
	_redraw()

func deselect_all() -> void:
	select(-1)

func set_item_icon(index: int, icon: Texture2D) -> void:
	_row(index).icon = icon

## Text colour of a row (favourites are yellow).
func set_item_custom_fg_color(index: int, color: Color) -> void:
	var row := _row(index)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		row.add_theme_color_override(state, color)

## Glides the selected row to the middle when it is out of view (a song selected by search or a rebuilt list).
func ensure_current_is_visible() -> void:
	if _selected < 0:
		return
	var top := _row_top(_selected) - scroll_vertical
	if top < 0.0 or top + ROW_HEIGHT > _view_height():
		center_on(_selected)

## Glides the list so the row sits in its middle.
func center_on(index: int) -> void:
	if _glide:
		_glide.kill()
	var target := _row_top(index) + (ROW_HEIGHT - _view_height()) / 2.0
	_glide = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_glide.tween_method(func(value: float) -> void:
		scroll_vertical = roundi(value)
		_redraw(), float(scroll_vertical), target, GLIDE_SECONDS)

func _show_first_row() -> void:
	scroll_vertical = roundi(_top.custom_minimum_size.y)
	_redraw()

func _row(index: int) -> Button:
	return _rows.get_child(index) as Button

## Where a row starts in the scrolled content (every row has the same height).
func _row_top(index: int) -> float:
	return _top.custom_minimum_size.y + index * (ROW_HEIGHT + ROW_SEPARATION)

## Height of the list's visible part.
func _view_height() -> float:
	var panel := get_theme_stylebox(&"panel")
	return size.y - panel.content_margin_top - panel.content_margin_bottom

## Room above the first row and below the last for either to sit in the middle.
func _pad_ends() -> void:
	var pad := maxf(0.0, (_view_height() - ROW_HEIGHT) / 2.0)
	_top.custom_minimum_size.y = pad
	_bottom.custom_minimum_size.y = pad

## Gives a row the ItemList look: selected, hover or plain, with the row's padding.
func _style_row(index: int) -> void:
	var row := _row(index)
	var selected := get_theme_stylebox(&"selected", &"ItemList").duplicate() as StyleBox
	var hover := get_theme_stylebox(&"hovered", &"ItemList").duplicate() as StyleBox
	var plain := StyleBoxEmpty.new()
	for box: StyleBox in [selected, hover, plain]:
		box.content_margin_top = ROW_PADDING
		box.content_margin_bottom = ROW_PADDING
	plain.content_margin_left = selected.content_margin_left
	plain.content_margin_right = selected.content_margin_right
	row.add_theme_stylebox_override(&"normal", selected if index == _selected else plain)
	row.add_theme_stylebox_override(&"hover", selected if index == _selected else hover)
	row.add_theme_stylebox_override(&"pressed", selected)
	row.add_theme_stylebox_override(&"hover_pressed", selected)
	row.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())

## Redraws the canvas: selection and scrolling change between pointer inputs.
func _redraw() -> void:
	if not is_inside_tree():
		return
	var canvas := get_viewport().get_parent() as OQ_UI2DCanvas
	if canvas:
		canvas._input_update()
