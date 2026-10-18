extends Node
## Scrolls the text of the hovered (or else selected) ItemList item in a loop
## when it is too long to fit, like a marquee.

## Seconds between each one-character step of the scrolling text.
const STEP_SECONDS := 0.15
## Pause, in seconds, before a title starts scrolling.
const START_DELAY := 0.6
## Space between the end of the title and its next repeat.
const GAP := "     "
## Room taken by the item's padding and icon when the list has one column.
const SINGLE_COLUMN_PADDING := 140.0

@export var list_path: NodePath

var _list: ItemList
var _index := -1
var _original := ""
var _shown := ""
var _offset := 0
var _timer := 0.0

## Finds the list to animate.
func _ready() -> void:
	_list = get_node(list_path) as ItemList
	assert(_list != null, "item_list_marquee needs an ItemList at list_path")

## Follows the hovered or selected item and steps its text when it overflows.
func _process(delta: float) -> void:
	var target := _target_index()
	if target != _index:
		_restore()
		_index = target
		if _index >= 0 and _overflows(_list.get_item_text(_index)):
			_original = _list.get_item_text(_index)
			_shown = _original
			_offset = 0
			_timer = -START_DELAY
		else:
			_index = -1
	if _index < 0:
		return
	_timer += delta
	if _timer < STEP_SECONDS:
		return
	_timer = 0.0
	var looped := _original + GAP
	_offset = (_offset + 1) % looped.length()
	_shown = looped.substr(_offset) + looped.substr(0, _offset)
	_list.set_item_text(_index, _shown)
	_redraw()

## Returns the item under the pointer, else the first selected item, else -1.
func _target_index() -> int:
	if not _list.is_visible_in_tree():
		return -1
	var hovered := _list.get_item_at_position(_list.get_local_mouse_position(), true)
	if hovered >= 0:
		return hovered
	var selected := _list.get_selected_items()
	return selected[0] if selected.size() > 0 else -1

## Returns whether the text is wider than the space an item has for it.
func _overflows(text: String) -> bool:
	var font := _list.get_theme_font("font")
	var font_size := _list.get_theme_font_size("font_size")
	var room := _list.size.x - SINGLE_COLUMN_PADDING
	if _list.fixed_column_width > 0:
		room = _list.fixed_column_width
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room

## Puts the animated item's full text back, unless the list was refilled since.
func _restore() -> void:
	if _index >= 0 and _index < _list.item_count and _list.get_item_text(_index) == _shown:
		_list.set_item_text(_index, _original)
		_redraw()
	_index = -1

## Asks the menu canvas to render again, since it only redraws on input.
func _redraw() -> void:
	var viewport := get_viewport()
	if viewport is SubViewport and (viewport as SubViewport).render_target_update_mode == SubViewport.UPDATE_DISABLED:
		(viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
