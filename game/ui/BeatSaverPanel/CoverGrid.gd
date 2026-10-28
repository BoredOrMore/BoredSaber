extends ScrollContainer
class_name CoverGrid
## Get songs' grid of song cards (a cover with its level strip, then the title and length), built so its cost doesn't
## grow with the list (owner, 2026-10-28, doc/research/get-songs-list-plan.md): it keeps every song's text and cover
## *image* (CPU memory), but only enough cards for the rows in view plus SPARE_ROWS, each with its own ImageTexture
## that is written over (ImageTexture.update, same size) when the card shows another song. So scrolling, a new page
## or a filter change never creates or frees GPU textures (freeing hundreds at once froze the headset about a
## second; an ItemList kept a texture per song). It keeps the few ItemList calls the page uses (add_item, clear,
## item_count, item_selected...). The covers must all be COVER_SIZE square RGBA8 (LevelStrip.compose_image).

## A card was pressed.
signal item_selected(index: int)

## Columns, the card's width and height, the cover's size and the gaps between cards (px; the ItemList's look: 200 px
## covers, up to TEXT_LINES lines of 22 px text under them, inside the list styles' 16 px side padding).
const COLUMNS := 4
const CARD_WIDTH := 232.0
const CARD_HEIGHT := 300.0
const COVER_SIZE := 200
const GAP := 8.0
const SIDE_PADDING := 16.0
const TEXT_LINES := 3
const FONT_SIZE := 22
## Rows of cards kept ready above and below the view, so a quick scroll doesn't show empty slots.
const SPARE_ROWS := 1

## The room for a title on a card (inside its padding), for fitting titles (the ItemList's fixed_column_width).
var fixed_column_width: int:
	get:
		return int(CARD_WIDTH - 2.0 * SIDE_PADDING)
var item_count: int:
	get:
		return _texts.size()

var _texts := PackedStringArray()
var _covers: Array[Image] = []
var _selected := -1
## The tall empty content the scroll moves, and the cards placed on it
var _content := Control.new()
var _cards: Array[Button] = []
var _card_textures: Array[ImageTexture] = []
## The song each card shows (-1 none), and the cover it last uploaded, so an unchanged card uploads nothing
var _card_item := PackedInt32Array()
var _card_cover: Array[Image] = []

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_theme_stylebox_override(&"panel", get_theme_stylebox(&"panel", &"ItemList"))
	add_child(_content)
	get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _place_cards())
	resized.connect(_make_cards)
	_make_cards()

## Adds a song card with its text and cover image; returns its index.
func add_item(text: String, cover: Image) -> int:
	_texts.append(text)
	_covers.append(cover)
	_grow()
	return _texts.size() - 1

func set_item_text(index: int, text: String) -> void:
	_texts[index] = text
	_place_cards(true)

## Puts a song's cover (or its placeholder) on its card.
func set_item_image(index: int, cover: Image) -> void:
	_covers[index] = cover
	_place_cards()

## A texture of a song's cover, for the details panel.
func get_item_icon(index: int) -> Texture2D:
	return ImageTexture.create_from_image(_covers[index])

## Drops every song (their images are CPU memory: nothing is freed on the GPU).
func clear() -> void:
	_texts.clear()
	_covers.clear()
	_selected = -1
	_grow()
	scroll_vertical = 0

func _grow() -> void:
	@warning_ignore("integer_division")
	var rows := (_texts.size() + COLUMNS - 1) / COLUMNS
	_content.custom_minimum_size = Vector2(COLUMNS * (CARD_WIDTH + GAP), rows * (CARD_HEIGHT + GAP))
	_place_cards(true)

## Enough cards for the rows in view and SPARE_ROWS on each side, each with its own cover texture.
func _make_cards() -> void:
	var wanted := (ceili(size.y / (CARD_HEIGHT + GAP)) + 1 + 2 * SPARE_ROWS) * COLUMNS
	while _cards.size() < wanted:
		var card := Button.new()
		card.toggle_mode = true
		# the ItemList's look: plain, its hover colour under the pointer, its selected colour when picked (owner,
		# 2026-10-28: the card colour on every card crowded the page)
		# every state keeps the selected look's margins, so nothing on the card moves when it is picked
		var plain := StyleBoxEmpty.new()
		var selected := get_theme_stylebox(&"selected", &"ItemList")
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			plain.set_content_margin(side, selected.get_content_margin(side))
		card.add_theme_stylebox_override(&"normal", plain)
		card.add_theme_stylebox_override(&"focus", plain)
		card.add_theme_stylebox_override(&"hover", get_theme_stylebox(&"hovered", &"ItemList"))
		for state: StringName in [&"pressed", &"hover_pressed"]:
			card.add_theme_stylebox_override(state, get_theme_stylebox(&"selected", &"ItemList"))
		card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		card.expand_icon = false
		card.add_theme_constant_override(&"icon_max_width", COVER_SIZE)
		card.add_theme_font_size_override(&"font_size", FONT_SIZE)
		card.autowrap_mode = TextServer.AUTOWRAP_OFF
		card.alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.pressed.connect(_on_card_pressed.bind(_cards.size()))
		var texture := ImageTexture.create_from_image(Image.create(COVER_SIZE, COVER_SIZE, false, Image.FORMAT_RGBA8))
		card.icon = texture
		_content.add_child(card)
		_cards.append(card)
		_card_textures.append(texture)
		_card_item.append(-1)
		_card_cover.append(null)
	_place_cards(true)

## Puts the cards on the rows in view (and the spare ones), each showing its song; `texts` also refreshes their text.
## Song i always goes on card i % the card count, so scrolling a row moves only that row's cards (and uploads only
## their covers).
func _place_cards(texts := false) -> void:
	var first := maxi(int(scroll_vertical / (CARD_HEIGHT + GAP)) - SPARE_ROWS, 0) * COLUMNS
	for index in range(first, first + _cards.size()):
		var slot := index % _cards.size()
		var card := _cards[slot]
		if index >= _texts.size():
			card.visible = false
			_card_item[slot] = -1
			continue
		card.visible = true
		@warning_ignore("integer_division")
		card.position = Vector2((index % COLUMNS) * (CARD_WIDTH + GAP), (index / COLUMNS) * (CARD_HEIGHT + GAP))
		if _card_item[slot] != index or texts:
			card.text = _texts[index]
		_card_item[slot] = index
		card.set_pressed_no_signal(index == _selected)
		var cover := _covers[index]
		if cover != _card_cover[slot]:
			_card_cover[slot] = cover
			_card_textures[slot].update(cover)

func _on_card_pressed(slot: int) -> void:
	_selected = _card_item[slot]
	_place_cards()
	item_selected.emit(_selected)
