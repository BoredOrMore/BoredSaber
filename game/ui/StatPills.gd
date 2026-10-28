class_name StatPills
## A difficulty's short stats as pills (owner, 2026-10-27: the long details under a difficulty compressed into pills,
## with icons where they fit): each an icon and a value in a rounded pill (the StatPill kind in menu_theme.tres;
## owner, 2026-10-28: rounded like everything else), laid in a centred flow that wraps between pills, never inside
## one. The song menu's stats under the difficulty and the Download page's details both use them, so a stat looks
## the same on both.
## - time to get ready for each note: seconds a note is in view before it arrives ("1.00 s"),
## - notes to hit per second ("4.6 notes/s"),
## - how twisty its swings are: the percent of swings that break the flow and its band ("6% Twisty",
##   Constants.FLOW_LEVELS); every value carries its unit (owner, 2026-10-27),
## and on the song menu its length and a workout's sets.

const READY_ICON := preload("res://game/ui/icons/timer.svg")
## a music note for notes per second; the bolt means Energy (owner, 2026-10-28: one symbol, one meaning)
const NPS_ICON := preload("res://game/ui/icons/music.svg")
const FLOW_ICON := preload("res://game/ui/icons/shuffle.svg")
const LENGTH_ICON := preload("res://game/ui/icons/clock.svg")
const WORKOUT_ICON := preload("res://game/ui/icons/dumbbell.svg")
## between pills, both ways
const GAP := 6

## A centred flow for pills, wrapping between them.
static func flow() -> HFlowContainer:
	var box := HFlowContainer.new()
	box.alignment = FlowContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"h_separation", GAP)
	box.add_theme_constant_override(&"v_separation", GAP)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box

## One pill: icon (size px, in UI_TEXT) and text (size px) in the StatPill kind.
static func pill(icon: Texture2D, text: String, size: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"StatPill"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var image := TextureRect.new()
	image.texture = icon
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2.ONE * size
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	image.modulate = Constants.UI_TEXT
	row.add_child(image)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size - 2)
	row.add_child(label)
	panel.add_child(row)
	return panel

## The three pills of a difficulty: get ready, notes per second (left out when unknown), swing flow from the
## percent of swings that break it.
static func difficulty(ready_seconds: float, notes_per_second: float, flow_percent: float, size: int) -> Array[Control]:
	var pills: Array[Control] = [pill(READY_ICON, "%.2f s" % ready_seconds, size)]
	if notes_per_second > 0.0:
		pills.append(pill(NPS_ICON, "%.1f notes/s" % notes_per_second, size))
	pills.append(pill(FLOW_ICON, "%d%% %s" % [roundi(flow_percent), Constants.FLOW_LEVELS[MapStats.flow_level(flow_percent)][0]], size))
	return pills

## A length in minutes and seconds, as a pill.
static func length(seconds: float, size: int) -> PanelContainer:
	return pill(LENGTH_ICON, "%d:%02d" % [int(seconds) / 60, int(seconds) % 60], size)

## A workout's sets ("3 sets"), as a pill.
static func workout(sets: int, size: int) -> PanelContainer:
	return pill(WORKOUT_ICON, "%d %s" % [sets, "set" if sets == 1 else "sets"], size)

## Puts pills in box, replacing what it held.
static func fill(box: Container, pills: Array) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	for p: Control in pills:
		box.add_child(p)
