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
var _covers: Array[Image] = []
var _strips: Array[Texture2D] = []
var _selected := -1
## The tall empty content the scroll moves, and the rows placed on it
var _content := Control.new()
var _rows: Array[Button] = []
var _row_covers: Array[ImageTexture] = []
var _row_strips: Array[TextureRect] = []
var _row_sides: Array[Label] = []
## The song each row shows (-1 none), and the cover it last uploaded, so an unchanged row uploads nothing
var _row_item := PackedInt32Array()
var _row_cover: Array[Image] = []

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_theme_stylebox_override(&"panel", get_theme_stylebox(&"panel", &"ItemList"))
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_content)
	get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _place_rows())
	resized.connect(_make_rows)
	_make_rows()

## Adds a song's row: "Artist - Title", the text at its end (length or state), its cover image and level strip;
## returns its index.
func add_item(text: String, side: String, cover: Image, strip: Texture2D) -> int:
	_texts.append(text)
	_sides.append(side)
	_covers.append(cover)
	_strips.append(strip)
	_grow()
	return _texts.size() - 1

## Changes the text at a row's end (its length, or how its download is going); true if it changed.
func set_item_side(index: int, side: String) -> bool:
	if _sides[index] == side:
		return false
	_sides[index] = side
	_place_rows(true)
	return true

## Changes a row's level strip (measured once the map is in the library).
func set_item_strip(index: int, strip: Texture2D) -> void:
	if _strips[index] == strip:
		return
	_strips[index] = strip
	_place_rows(true)

## Puts a song's cover (or its placeholder) on its row.
func set_item_image(index: int, cover: Image) -> void:
	_covers[index] = cover
	_place_rows()

## A song's small cover, shown in the details until the big one arrives.
func get_item_image(index: int) -> Image:
	return _covers[index]

## Drops every song (their images are CPU memory: nothing is freed on the GPU).
func clear() -> void:
	_texts.clear()
	_sides.clear()
	_covers.clear()
	_strips.clear()
	_selected = -1
	_grow()
	scroll_vertical = 0

func _grow() -> void:
	_content.custom_minimum_size = Vector2(0.0, _texts.size() * (ROW_HEIGHT + ROW_SEPARATION))
	_place_rows(true)

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
		# lets the list see the pointer come in over a row too, so the thumbstick scrolls it (vr_slider)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
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
		side.add_theme_color_override(&"font_color", Constants.UI_TEXT_MUTED)
		side.size = Vector2(SIDE_WIDTH, ROW_HEIGHT)
		row.add_child(side)
		UI_AudioEngine.attach_button(row)
		_content.add_child(row)
		_rows.append(row)
		_row_covers.append(texture)
		_row_strips.append(strip)
		_row_sides.append(side)
		_row_item.append(-1)
		_row_cover.append(null)
	_place_rows(true)

## Puts the rows in view (and the spare ones), each showing its song; `texts` also refreshes their text.
## Song i always goes on row i % the row count, so scrolling moves only the rows that leave the view (and uploads
## only their covers).
func _place_rows(texts := false) -> void:
	var width := size.x - (get_v_scroll_bar().size.x if get_v_scroll_bar().visible else 0.0)
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
		_row_strips[slot].position = Vector2(width - 2.0 * END_GAP - SIDE_WIDTH - LevelStrip.WIDTH, 0.0)
		if _row_item[slot] != index or texts:
			row.text = _texts[index]
			_row_sides[slot].text = _sides[index]
			_row_strips[slot].texture = _strips[index]
		_row_item[slot] = index
		row.set_pressed_no_signal(index == _selected)
		var cover := _covers[index]
		if cover != _row_cover[slot]:
			_row_cover[slot] = cover
			_row_covers[slot].update(cover)

func _on_row_pressed(slot: int) -> void:
	_selected = _row_item[slot]
	_place_rows()
	item_selected.emit(_selected)
