class_name IconButton
extends Button
## A button whose icon sits just left of its centred label, read as one group. A plain Button with a
## left icon and centred text puts the icon at the far edge, away from the word it explains.

const _STYLES: Array[StringName] = [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]

## Left padding that centres the icon and label; -1 until first drawn.
var _margin := -1.0

## Draws icon and label from the left so the padding below can centre them together.
func _ready() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

## Checks the centring on each draw, since the size, label or icon may have changed. A style set while
## drawing doesn't show until the next draw, so a change is applied right after this one.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW:
		var margin := _centred_margin()
		if not is_equal_approx(margin, _margin):
			_set_margin.call_deferred(margin)

## Half the room the icon and label leave free, at least a small edge.
func _centred_margin() -> float:
	var width := get_theme_font(&"font").get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			get_theme_font_size(&"font_size")).x
	if icon != null:
		width += icon.get_width() + get_theme_constant(&"h_separation")
	# never so far right that the label runs into the right padding
	var right := get_theme_stylebox(&"normal").content_margin_right
	return maxf(minf(roundf((size.x - width) / 2.0), size.x - width - right), 12.0)

## Sets the left padding of every state's style.
func _set_margin(margin: float) -> void:
	_margin = margin
	for style in _STYLES:
		var box := get_theme_stylebox(style).duplicate() as StyleBox
		box.content_margin_left = margin
		add_theme_stylebox_override(style, box)
