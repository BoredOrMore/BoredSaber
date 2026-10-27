class_name LevelStrip
## The Download page's level strip (owner, 2026-10-27: finding songs at your level was hard, the levels hard to see
## and the details too long to read): five slots along the bottom of a map's cover, Easy..Expert+ (LETTERS), each in
## its level's colour with its letter when the map has a difficulty at that level and dark when not, the player's
## level (the level filter) framed in UI_ACCENT. A map not yet downloaded shows the BeatSaver estimate and a "≈" in
## the cover's corner; one in the library shows its measured levels. Drawn into the cover image, as an ItemList
## icon can't hold controls.

const LETTERS := ["E", "N", "H", "X", "X+"]
const ESTIMATE := "≈"
## The cover's size on the card (the list's fixed icon size), the strip's height, and the frame around the
## player's level, in canvas px. A letter is GLYPH_SIZE px: at the page's 2 m about 1.85 degrees, the body text
## minimum (vr-ui-design); "X+" a little smaller to fit its slot.
const COVER := 200
const STRIP := 46
const FRAME := 4
const GLYPH_SIZE := 34
const GLYPH_SIZE_WIDE := 28
const ESTIMATE_BOX := 34
const FONT := preload("res://game/ui/fonts/roboto_bold.tres")

## letter -> white-on-transparent image, made once by prepare(); and "letter|colour" -> that letter tinted
static var _glyphs := {}
static var _tinted := {}

## Draws the letters once in an off-screen viewport; covers drawn before it finishes get no letters.
static func prepare(parent: Node) -> void:
	if not _glyphs.is_empty():
		return
	var labels := LETTERS + [ESTIMATE]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(COVER / LETTERS.size() * labels.size(), STRIP)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cell := COVER / LETTERS.size()
	for i in labels.size():
		var label := Label.new()
		label.text = labels[i]
		label.add_theme_font_override(&"font", FONT)
		label.add_theme_font_size_override(&"font_size", GLYPH_SIZE_WIDE if labels[i].length() > 1 else GLYPH_SIZE)
		label.add_theme_color_override(&"font_color", Color.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(i * cell, 0)
		label.size = Vector2(cell, STRIP)
		viewport.add_child(label)
	parent.add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	for i in labels.size():
		_glyphs[labels[i]] = image.get_region(Rect2i(i * cell, 0, cell, STRIP))
	viewport.queue_free()

## The cover with the strip: levels the map has (indices in Constants.DIFFICULTY_LEVELS), the player's level (-1
## none) framed, and the estimate mark when not measured.
static func compose(cover: Image, levels: Array, mine: int, estimated: bool) -> ImageTexture:
	var image := cover.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(COVER, COVER, Image.INTERPOLATE_BILINEAR)
	var cell := COVER / LETTERS.size()
	for i in LETTERS.size():
		var rect := Rect2i(i * cell, COVER - STRIP, cell, STRIP)
		var has := levels.has(i)
		if i == mine:
			image.fill_rect(rect, Constants.UI_ACCENT)
			rect = rect.grow(-FRAME)
		image.fill_rect(rect, Constants.DIFFICULTY_LEVELS[i][1] if has else Constants.UI_PANEL)
		_blend_glyph(image, LETTERS[i], rect.get_center(), Constants.UI_PANEL if has else Constants.UI_TEXT_MUTED)
	if estimated:
		var box := Rect2i(COVER - ESTIMATE_BOX, 0, ESTIMATE_BOX, ESTIMATE_BOX)
		image.fill_rect(box, Constants.UI_PANEL)
		_blend_glyph(image, ESTIMATE, box.get_center(), Constants.UI_TEXT)
	return ImageTexture.create_from_image(ImageUtils.round_corners(image, roundi(COVER * ImageUtils.COVER_CORNER)))

## Blends a letter's image tinted in color, centred on centre.
static func _blend_glyph(image: Image, letter: String, centre: Vector2i, color: Color) -> void:
	if not _glyphs.has(letter):
		return
	var key := letter + "|" + color.to_html()
	if not _tinted.has(key):
		var tinted := (_glyphs[letter] as Image).duplicate() as Image
		for y in tinted.get_height():
			for x in tinted.get_width():
				tinted.set_pixel(x, y, Color(color, tinted.get_pixel(x, y).a))
		_tinted[key] = tinted
	var glyph := _tinted[key] as Image
	image.blend_rect(glyph, Rect2i(Vector2i.ZERO, glyph.get_size()), centre - glyph.get_size() / 2)
