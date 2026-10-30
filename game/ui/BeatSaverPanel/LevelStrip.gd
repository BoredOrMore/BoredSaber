class_name LevelStrip
## The Download page's level strip (owner, 2026-10-27: finding songs at your level was hard, the levels hard to see
## and the details too long to read): five slots at the end of a map's row, Easy..Expert+ (LETTERS), each in
## its level's colour with its letter when the map has a difficulty at that level and dark when not, the player's
## level (the level filter) framed in UI_ACCENT. A map not yet downloaded shows the BeatSaver estimate and a "≈" before
## the slots; one in the library shows its measured levels. Drawn into an image, so a row shows it as one texture
## (one draw) instead of ten controls.

const LETTERS := ["E", "N", "H", "X", "X+"]
const ESTIMATE := "≈"
## A slot's width, the gap between slots, the strip's height, the room for "≈" before the slots and the frame around
## the player's level, in canvas px. A letter is GLYPH_SIZE px: at the page's 2 m and scale 2.4 about 1.85 degrees,
## the body text minimum (vr-ui-design); "X+" a little smaller to fit its slot. GLYPH_CELL is the room each
## letter is drawn in, wider than a slot so "X+" isn't cut.
const SLOT := 36
const SLOT_GAP := 2
const STRIP := 44
const ESTIMATE_ROOM := 28
const FRAME := 3
const GLYPH_SIZE := 28
const GLYPH_SIZE_WIDE := 22
const GLYPH_CELL := 40
## LETTERS.size() slots after the estimate mark
const WIDTH := ESTIMATE_ROOM + 5 * (SLOT + SLOT_GAP) - SLOT_GAP
const FONT := preload("res://game/ui/fonts/roboto_bold.tres")

## letter -> white-on-transparent image, made once by prepare(); and "letter|colour" -> that letter tinted
static var _glyphs := {}
static var _tinted := {}

## Draws the letters once in an off-screen viewport; strips drawn before it finishes get no letters.
static func prepare(parent: Node) -> void:
	if not _glyphs.is_empty():
		return
	var labels := LETTERS + [ESTIMATE]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(GLYPH_CELL * labels.size(), STRIP)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	for i in labels.size():
		var label := Label.new()
		label.text = labels[i]
		label.add_theme_font_override(&"font", FONT)
		label.add_theme_font_size_override(&"font_size", GLYPH_SIZE_WIDE if labels[i].length() > 1 else GLYPH_SIZE)
		label.add_theme_color_override(&"font_color", Color.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(i * GLYPH_CELL, 0)
		label.size = Vector2(GLYPH_CELL, STRIP)
		viewport.add_child(label)
	parent.add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	for i in labels.size():
		_glyphs[labels[i]] = image.get_region(Rect2i(i * GLYPH_CELL, 0, GLYPH_CELL, STRIP))
	viewport.queue_free()
	for letter: String in _glyphs:
		for color: Color in [Constants.UI_PANEL, Constants.UI_TEXT_MUTED, Constants.UI_TEXT]:
			_tinted_glyph(letter, color)

## The strip: levels the map has (indices in Constants.DIFFICULTY_LEVELS), the player's level (-1 none) framed, and
## the estimate mark when not measured; WIDTH x STRIP, transparent around the slots.
static func strip_image(levels: Array, mine: int, estimated: bool) -> Image:
	var image := Image.create(WIDTH, STRIP, false, Image.FORMAT_RGBA8)
	if estimated:
		_blend_glyph(image, ESTIMATE, Vector2i(ESTIMATE_ROOM / 2, STRIP / 2), Constants.UI_TEXT)
	for i in LETTERS.size():
		var rect := Rect2i(ESTIMATE_ROOM + i * (SLOT + SLOT_GAP), 0, SLOT, STRIP)
		var has := levels.has(i)
		if i == mine:
			image.fill_rect(rect, Constants.UI_ACCENT)
			rect = rect.grow(-FRAME)
		image.fill_rect(rect, Constants.DIFFICULTY_LEVELS[i][1] if has else Constants.UI_SURFACE)
		_blend_glyph(image, LETTERS[i], rect.get_center(), Constants.UI_PANEL if has else Constants.UI_TEXT_MUTED)
	return image

## Blends a letter's image tinted in color, centred on centre.
static func _blend_glyph(image: Image, letter: String, centre: Vector2i, color: Color) -> void:
	if not _glyphs.has(letter):
		return
	var glyph := _tinted_glyph(letter, color)
	image.blend_rect(glyph, Rect2i(Vector2i.ZERO, glyph.get_size()), centre - glyph.get_size() / 2)

## A letter's image tinted in color, made once and kept.
static func _tinted_glyph(letter: String, color: Color) -> Image:
	var key := letter + "|" + color.to_html()
	if not _tinted.has(key):
		var tinted := (_glyphs[letter] as Image).duplicate() as Image
		for y in tinted.get_height():
			for x in tinted.get_width():
				tinted.set_pixel(x, y, Color(color, tinted.get_pixel(x, y).a))
		_tinted[key] = tinted
	return _tinted[key]
