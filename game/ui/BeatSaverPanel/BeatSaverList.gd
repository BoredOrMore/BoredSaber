extends ScrollContainer
class_name BeatSaverList
## Get songs' song list, in the song menu's row look (SongList: a 72 px cover and "Artist - Title" in the theme's
## text), with the map's level strip (LevelStrip) and its length or download state at the row's end (owner,
## 2026-10-29, Get songs layout A). Built so its cost doesn't grow with the list (doc/research/get-songs-list-plan.md):
## it keeps every song's text and small cover *image* (CPU memory), but only enough rows for the view plus SPARE_ROWS,
## each with its own cover ImageTexture written over in place (ImageTexture.update, same size) when the row shows
## another song. So scrolling, a new page or a filter change never creates or frees GPU textures (freeing hundreds at
## once froze the headset about a second). Strips are shared textures the page makes once per kind of strip.
## It keeps the few ItemList calls the page uses (add_item, clear, item_count, item_selected...). The covers must all
## be COVER_SIZE square RGBA8.

## A row was pressed.
signal item_selected(index: int)
## A row's download icon was pressed (owner, 2026-11-04: one press gets a song, without opening its details).
signal download_pressed(index: int)

## What a row's end shows over its length: the download icon (pressable), the download's progress, or a check once
## the map is in the library.
enum Side { GET, BUSY, OWNED }
const DOWNLOAD_ICON := preload("res://game/ui/icons/download.svg")
const OWNED_ICON := preload("res://game/ui/icons/check.svg")
## The end icon's size and the length's text under it (px); the whole end, SIDE_WIDTH by the row, takes the press
## (84 x 76 px, about 5.6 x 5.1 degrees at the menus' 2 m).
const SIDE_ICON_SIZE := 32
const SIDE_LENGTH_FONT_SIZE := 20

## Row height, cover size, padding and gap between rows (px): SongList's.
const ROW_HEIGHT := 76.0
const COVER_SIZE := 72
const ROW_PADDING := 2.0
const ROW_SEPARATION := 6.0
## The room at the row's end: the level strip, then the length or download state, and the gaps around them (px).
const SIDE_WIDTH := 84.0
const END_GAP := 12.0
const SIDE_FONT_SIZE := 24
## Rows kept ready above and below the view, so a quick scroll doesn't show empty slots.
const SPARE_ROWS := 1

var item_count: int:
	get:
		return _texts.size()

var _texts := PackedStringArray()
var _sides := PackedStringArray()
var _states := PackedByteArray()
var _covers: Array[Image] = []
var _strips: Array[Texture2D] = []
var _selected := -1
## The tall empty content the scroll moves, and the rows placed on it
var _content := Control.new()
var _rows: Array[Button] = []
var _row_covers: Array[ImageTexture] = []
var _row_strips: Array[TextureRect] = []
var _row_sides: Array[Label] = []
var _row_icons: Array[TextureRect] = []
var _row_lengths: Array[Label] = []
## The song each row shows (-1 none), and the cover it last uploaded, so an unchanged row uploads nothing
var _row_item := PackedInt32Array()
var _row_cover: Array[Image] = []

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_theme_stylebox_override(&"panel", get_theme_stylebox(&"panel", &"ItemList"))
	add_child(_content)
	get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _place_rows())
	resized.connect(_make_rows)
	_make_rows()

## Adds songs' rows, each "Artist - Title", its end (a Side and the text with it: the length, or the download's
## progress), its cover image and level strip, laying the rows out once for all of them.
func add_items(texts: PackedStringArray, states: PackedByteArray, sides: PackedStringArray, covers: Array[Image],
		strips: Array[Texture2D]) -> void:
	_texts.append_array(texts)
	_states.append_array(states)
	_sides.append_array(sides)
	_covers.append_array(covers)
	_strips.append_array(strips)
	_grow()

## Changes a row's end (its Side and the length or the download's progress); true if it changed.
func set_item_side(index: int, state: BeatSaverList.Side, side: String) -> bool:
	if _sides[index] == side and _states[index] == state:
		return false
	_sides[index] = side
	_states[index] = state
	# only that row's end, if it is on a row: a download's progress changes it every frame
	var slot := index % _rows.size()
	if _row_item[slot] == index:
		_show_side(slot, index)
	return true

## Shows song index's end on row slot: the icon with the length under it, or the progress alone while downloading.
func _show_side(slot: int, index: int) -> void:
	var state := _states[index] as Side
	_row_icons[slot].visible = state != Side.BUSY
	_row_icons[slot].texture = OWNED_ICON if state == Side.OWNED else DOWNLOAD_ICON
	_row_icons[slot].modulate = Constants.UI_TEXT_MUTED if state == Side.OWNED else Constants.UI_TEXT
	_row_lengths[slot].visible = state != Side.BUSY
	_row_lengths[slot].text = _sides[index]
	_row_sides[slot].visible = state == Side.BUSY
	_row_sides[slot].text = _sides[index]

## True if a point on row slot (its own coordinates) is on its end, the download icon's press area.
func _on_side(slot: int, point: Vector2) -> bool:
	return point.x >= _row_sides[slot].position.x - END_GAP

## Changes a row's level strip (measured once the map is in the library).
func set_item_strip(index: int, strip: Texture2D) -> void:
	if _strips[index] == strip:
		return
	_strips[index] = strip
	var slot := index % _rows.size()
	if _row_item[slot] == index:
		_row_strips[slot].texture = strip

## Puts a song's cover (or its placeholder) on its row.
func set_item_image(index: int, cover: Image) -> void:
	_covers[index] = cover
	_place_rows()

## True if a song's row is (even partly) in the view.
func shows(index: int) -> bool:
	var step := ROW_HEIGHT + ROW_SEPARATION
	return index * step < scroll_vertical + size.y and (index + 1) * step > scroll_vertical

## The song at the top of the view.
func first_shown() -> int:
	return maxi(int(scroll_vertical / (ROW_HEIGHT + ROW_SEPARATION)), 0)

## A song's small cover, shown in the details until the big one arrives.
func get_item_image(index: int) -> Image:
	return _covers[index]

## Drops every song (their images are CPU memory: nothing is freed on the GPU).
func clear() -> void:
	_texts.clear()
	_states.clear()
	_sides.clear()
	_covers.clear()
	_strips.clear()
	_selected = -1
	# the rows show other songs now, whatever index they had: their text and strip are set again
	_row_item.fill(-1)
	_grow()
	scroll_vertical = 0

## Sizes the content for the songs; new songs get their rows' text as they come into view (`_place_rows` sets a row's
## text only when it shows another song), so adding a page re-lays no text already on screen.
func _grow() -> void:
	_content.custom_minimum_size = Vector2(0.0, _texts.size() * (ROW_HEIGHT + ROW_SEPARATION))
	_place_rows()

## Enough rows for the view and SPARE_ROWS on each side, each with its own cover texture.
func _make_rows() -> void:
	var wanted := ceili(size.y / (ROW_HEIGHT + ROW_SEPARATION)) + 1 + 2 * SPARE_ROWS
	var selected := get_theme_stylebox(&"selected", &"ItemList").duplicate() as StyleBox
	var hover := get_theme_stylebox(&"hovered", &"ItemList").duplicate() as StyleBox
	var plain := StyleBoxEmpty.new()
	for box: StyleBox in [selected, hover, plain]:
		box.content_margin_top = ROW_PADDING
		box.content_margin_bottom = ROW_PADDING
		box.content_margin_left = selected.content_margin_left
		# the title stops before the strip and the end text
		box.content_margin_right = LevelStrip.WIDTH + SIDE_WIDTH + 2.0 * END_GAP
	while _rows.size() < wanted:
		var row := Button.new()
		row.toggle_mode = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.clip_text = true
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_theme_constant_override(&"icon_max_width", COVER_SIZE)
		row.add_theme_constant_override(&"h_separation", get_theme_constant(&"h_separation", &"ItemList"))
		row.add_theme_stylebox_override(&"normal", plain)
		row.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
		row.add_theme_stylebox_override(&"hover", hover)
		for state: StringName in [&"pressed", &"hover_pressed"]:
			row.add_theme_stylebox_override(state, selected)
		row.pressed.connect(_on_row_pressed.bind(_rows.size()))
		# the list's own enter and exit, so vr_slider's thumbstick scroll sees a pointer that came in over a row. Not
		# MOUSE_FILTER_PASS: with it, picking and dragging rows stopped working on the headset (owner, 2026-10-29)
		row.mouse_entered.connect(mouse_entered.emit)
		row.mouse_exited.connect(mouse_exited.emit)
		var texture := ImageTexture.create_from_image(Image.create(COVER_SIZE, COVER_SIZE, false, Image.FORMAT_RGBA8))
		row.icon = texture
		var strip := TextureRect.new()
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		strip.size = Vector2(LevelStrip.WIDTH, ROW_HEIGHT)
		row.add_child(strip)
		var side := Label.new()
		side.mouse_filter = Control.MOUSE_FILTER_IGNORE
		side.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		side.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		side.add_theme_font_size_override(&"font_size", SIDE_FONT_SIZE)
		side.size = Vector2(SIDE_WIDTH, ROW_HEIGHT)
		row.add_child(side)
		# the icon with the length under it, centred in the end over each other
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(SIDE_WIDTH, SIDE_ICON_SIZE)
		row.add_child(icon)
		var length := Label.new()
		length.mouse_filter = Control.MOUSE_FILTER_IGNORE
		length.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		length.add_theme_font_size_override(&"font_size", SIDE_LENGTH_FONT_SIZE)
		length.add_theme_color_override(&"font_color", Constants.UI_TEXT_MUTED)
		length.size = Vector2(SIDE_WIDTH, ROW_HEIGHT - SIDE_ICON_SIZE)
		row.add_child(length)
		var slot := _rows.size()
		# the download icon lights while pointed at, so it reads as its own button inside the row
		row.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseMotion and _row_item[slot] >= 0 and _states[_row_item[slot]] == Side.GET:
				icon.modulate = Constants.UI_ACCENT if _on_side(slot, (event as InputEventMouseMotion).position) \
						else Constants.UI_TEXT)
		row.mouse_exited.connect(func() -> void:
			if _row_item[slot] >= 0 and _states[_row_item[slot]] == Side.GET:
				icon.modulate = Constants.UI_TEXT)
		UI_AudioEngine.attach_button(row)
		_content.add_child(row)
		_rows.append(row)
		_row_covers.append(texture)
		_row_strips.append(strip)
		_row_sides.append(side)
		_row_icons.append(icon)
		_row_lengths.append(length)
		_row_item.append(-1)
		_row_cover.append(null)
	_place_rows(true)

## Puts the rows in view (and the spare ones), each showing its song; `texts` also refreshes their text.
## Song i always goes on row i % the row count, so scrolling moves only the rows that leave the view (and uploads
## only their covers).
func _place_rows(texts := false) -> void:
	# the rows stop a scroll bar's width short of the scroll bar, so they don't touch it (owner, 2026-10-30)
	var width := size.x - (2.0 * get_v_scroll_bar().size.x if get_v_scroll_bar().visible else 0.0)
	var first := maxi(int(scroll_vertical / (ROW_HEIGHT + ROW_SEPARATION)) - SPARE_ROWS, 0)
	for index in range(first, first + _rows.size()):
		var slot := index % _rows.size()
		var row := _rows[slot]
		if index >= _texts.size():
			row.visible = false
			_row_item[slot] = -1
			continue
		row.visible = true
		row.position = Vector2(0.0, index * (ROW_HEIGHT + ROW_SEPARATION))
		row.size = Vector2(width, ROW_HEIGHT)
		_row_sides[slot].position = Vector2(width - END_GAP - SIDE_WIDTH, 0.0)
		_row_icons[slot].position = Vector2(width - END_GAP - SIDE_WIDTH, (ROW_HEIGHT - SIDE_ICON_SIZE - SIDE_LENGTH_FONT_SIZE) / 2.0 - 2.0)
		_row_lengths[slot].position = _row_icons[slot].position + Vector2(0.0, SIDE_ICON_SIZE)
		_row_strips[slot].position = Vector2(width - 2.0 * END_GAP - SIDE_WIDTH - LevelStrip.WIDTH, 0.0)
		if _row_item[slot] != index or texts:
			row.text = _texts[index]
			_show_side(slot, index)
			_row_strips[slot].texture = _strips[index]
		_row_item[slot] = index
		row.set_pressed_no_signal(index == _selected)
		var cover := _covers[index]
		if cover != _row_cover[slot]:
			_row_cover[slot] = cover
			_row_covers[slot].update(cover)

func _on_row_pressed(slot: int) -> void:
	var index := _row_item[slot]
	if _states[index] == Side.GET and _on_side(slot, _rows[slot].get_local_mouse_position()):
		# the row stays as it was: a toggle button flips itself on press
		_rows[slot].set_pressed_no_signal(index == _selected)
		download_pressed.emit(index)
		return
	_selected = _row_item[slot]
	_place_rows()
	item_selected.emit(_selected)
