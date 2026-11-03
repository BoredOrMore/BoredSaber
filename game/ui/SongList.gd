extends ScrollContainer
class_name SongList
## The song menu's list: one row per song (cover and name) in the ItemList look, every row the same size; the
## selected one only changes its background (resizing rows made players dizzy). Empty space above the first row
## and below the last lets any row scroll to the middle (center_on), gliding over GLIDE_SECONDS.
## It keeps the few ItemList calls the menu uses (add_item, select, item_count...).

## A row was pressed (not emitted by select()).
signal item_selected(index: int)

## Row height, cover size and padding, in px: the list's original look (72 px covers, the theme's 28 px text, rows
## 82 px apart), which the player preferred to smaller rows that fit more songs.
const ROW_HEIGHT := 76.0
const COVER_SIZE := 72
const ROW_PADDING := 2.0
const ROW_SEPARATION := 6
## A favourite's star at a row's right end, in px, and the gap before it (the icons' 36 px, a little smaller than
## the 72 px cover beside the 28 px name).
const STAR_SIZE := 32
const STAR_GAP := 12
const STAR_ICON := preload("res://game/ui/icons/star-filled.svg")
## The artist under a row's name, in px: smaller and muted (white on the selected row's blue, where muted grey reads
## at 2.7:1); 28 + 22 px lines fit the 72 px inside a row.
const ARTIST_FONT_SIZE := 22
## How long scrolling to a row takes (eased, so the list never snaps).
const GLIDE_SECONDS := 0.18

## Content: empty space, the rows, empty space.
var _content := VBoxContainer.new()
var _top := Control.new()
var _rows := VBoxContainer.new()
var _bottom := Control.new()
var _selected := -1
var _glide: Tween

## Rows in the list. Rows past it are kept hidden for the next list: rebuilding the list (every search key,
## filter or sort) reuses them instead of freeing and creating buttons, which dropped frames.
var item_count: int:
	get:
		return _count
var _count := 0

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

## Adds a row (reusing a hidden one when there is one) and returns its index: the song's name on top, its artist
## under it (owner, 2026-11-04: the A–Z order is by name, so the name leads).
func add_item(title: String, artist: String, icon: Texture2D) -> int:
	var index := _count
	_count += 1
	var row: Button
	if index < _rows.get_child_count():
		row = _row(index)
		row.visible = true
		_star(index).visible = false
	else:
		row = _new_row(index)
	_title(index).text = title
	_artist(index).text = artist
	row.icon = icon
	_style_row(index)
	return index

## A new row button, added to the rows; pressing it selects row index.
func _new_row(index: int) -> Button:
	var row := Button.new()
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size.y = ROW_HEIGHT
	row.add_theme_constant_override(&"icon_max_width", COVER_SIZE)
	row.add_theme_constant_override(&"h_separation", get_theme_constant(&"h_separation", &"ItemList"))
	var star := TextureRect.new()
	star.texture = STAR_ICON
	star.modulate = Constants.FAVORITE_COLOR
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	star.offset_left = -STAR_SIZE - STAR_GAP
	star.offset_right = -STAR_GAP
	star.offset_top = -STAR_SIZE / 2.0
	star.offset_bottom = STAR_SIZE / 2.0
	star.visible = false
	row.add_child(star)
	# the name and artist right of the cover, placed by _style_row; presses go through to the row
	var lines := VBoxContainer.new()
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override(&"separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for font_size: int in [get_theme_default_font_size(), ARTIST_FONT_SIZE]:
		var line := Label.new()
		line.add_theme_font_size_override(&"font_size", font_size)
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(line)
	(lines.get_child(0) as Label).add_theme_font_override(&"font", get_theme_font(&"font", &"Button"))
	row.add_child(lines)
	row.pressed.connect(func() -> void:
		select(index)
		item_selected.emit(index))
	_rows.add_child(row)
	UI_AudioEngine.attach_button(row)
	return row

## Empties the list: its rows hide, kept for reuse.
func clear() -> void:
	for row in _rows.get_children():
		(row as Button).visible = false
	_count = 0
	_selected = -1
	# a new list starts with its first row at the top, not after the empty space, unless place_row keeps a row in place
	_reset_scroll = true
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

## Marks a row as a favourite: a filled star at its right end, the name ending before it.
func set_item_favorite(index: int, favorite: bool) -> void:
	_star(index).visible = favorite
	_style_row(index)

func _star(index: int) -> TextureRect:
	return _row(index).get_child(0) as TextureRect

func _title(index: int) -> Label:
	return _row(index).get_child(1).get_child(0) as Label

func _artist(index: int) -> Label:
	return _row(index).get_child(1).get_child(1) as Label

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

## Where row index is from the top of the view, in px (for place_row after a rebuild).
func row_offset(index: int) -> float:
	return _row_top(index) - scroll_vertical

## Scrolls so row index sits offset px from the top of the view, as it did before the list was rebuilt (a filter that
## follows the speed refilled it), so the list doesn't jump.
func place_row(index: int, offset: float) -> void:
	_reset_scroll = false
	if _glide:
		_glide.kill()
	_place_generation += 1
	var generation := _place_generation
	var scroll := _row_top(index) - offset
	scroll_vertical = roundi(scroll)
	# again once the rebuilt rows are laid out (until then the scroll range is the old list's and clamps it); the
	# canvas meanwhile isn't asked to redraw (OQ_UI2DCanvas.update_only_on_input), so it shows the row only in place
	_placing = true
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _place_generation:
		return
	_placing = false
	if is_inside_tree():
		scroll_vertical = roundi(scroll)
		_redraw()

## bumped by each place_row, so only the newest one applies after the layout waits
var _place_generation := 0
## set while place_row waits for the layout: no redraws meanwhile
var _placing := false

## set by clear(), cleared by place_row
var _reset_scroll := false

func _show_first_row() -> void:
	if not _reset_scroll:
		return
	_reset_scroll = false
	scroll_vertical = roundi(_top.custom_minimum_size.y)
	_redraw()

func _row(index: int) -> Button:
	return _rows.get_child(index) as Button

## Where a row starts in the scrolled content (every row has the same height).
## The row at the top of the view (for loading the covers in view first).
func first_shown() -> int:
	return maxi(int((scroll_vertical - _top.custom_minimum_size.y) / (ROW_HEIGHT + ROW_SEPARATION)), 0)

func _row_top(index: int) -> float:
	return _top.custom_minimum_size.y + index * (ROW_HEIGHT + ROW_SEPARATION)

## Height of the list's visible part.
func _view_height() -> float:
	var panel := get_theme_stylebox(&"panel")
	return size.y - panel.content_margin_top - panel.content_margin_bottom

## How many whole rows the list shows at once (a screen, for the thumbstick's jumps).
func rows_in_view() -> int:
	return maxi(floori((_view_height() + ROW_SEPARATION) / (ROW_HEIGHT + ROW_SEPARATION)), 1)

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
	if _star(index).visible:
		for box: StyleBox in [selected, hover, plain]:
			box.content_margin_right += STAR_SIZE + STAR_GAP
	var lines := row.get_child(1) as Control
	lines.offset_left = plain.content_margin_left + COVER_SIZE + row.get_theme_constant(&"h_separation")
	lines.offset_right = -plain.content_margin_right
	_artist(index).add_theme_color_override(&"font_color", Constants.UI_TEXT if index == _selected else Constants.UI_TEXT_MUTED)
	row.add_theme_stylebox_override(&"normal", selected if index == _selected else plain)
	row.add_theme_stylebox_override(&"hover", selected if index == _selected else hover)
	row.add_theme_stylebox_override(&"pressed", selected)
	row.add_theme_stylebox_override(&"hover_pressed", selected)
	row.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())

## Redraws the canvas: selection and scrolling change between pointer inputs.
func _redraw() -> void:
	if not is_inside_tree() or _placing:
		return
	var canvas := get_viewport().get_parent() as OQ_UI2DCanvas
	if canvas:
		canvas._input_update()
