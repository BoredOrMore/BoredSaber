class_name FilterChips
extends RefCounted
## The filter panels' template (owner, 2026-10-30: filters sit in the right panel beside the list they filter, never
## over it, one press per choice), shared by the song menu and Get songs: a titled section (MenuSection) per filter
## with one chip per choice, wrapping onto more rows as needed. Pressing the picked chip again turns its filter off,
## so no "Any" chip is needed.

## Gap between chips across and down (px): MenuSection's row gap.
const CHIP_GAP := MenuSection.ROW_GAP
## Chip height (px): the modifier chips' rows.
const CHIP_HEIGHT := 48
## A choice with how many songs it would list, e.g. "Up to Hard (18)".
const COUNT_LABEL := "%s (%d)"
## The count a counted chip keeps room for from the start, so its width (and its neighbours) stays put as counts
## change (owner, 2026-10-30: leave room for changing text so things don't move about).
const COUNT_ROOM := 9999
## The row above a list: the x on each chip (px), the chip that stands for all the filters when theirs don't fit, and
## most letters of a search shown on its chip before "…".
const CLEAR_ICON := preload("res://game/ui/icons/x.svg")
const CHIP_ICON_SIZE := 24
const SOME_FILTERS_TEXT := "%d filters"
const SEARCH_CHIP_LETTERS := 16

## Adds a section titled title to parent with a chip per label, in the theme's button kind `kind`. Pressing a chip
## calls on_pick with its index, or -1 when it was the picked one (the filter goes off). Returns the chips.
static func add_section(parent: Container, title: String, labels: Array, on_pick: Callable,
		kind := &"ChipButton") -> Array[Button]:
	var section := MenuSection.make(title)
	parent.add_child(section)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", CHIP_GAP)
	flow.add_theme_constant_override(&"v_separation", CHIP_GAP)
	section.add_child(flow)
	var chips: Array[Button] = []
	for i in labels.size():
		var chip := ModifierChips.make_row_button(str(labels[i]), null, func() -> void: pass, kind)
		chip.custom_minimum_size.y = CHIP_HEIGHT
		chip.toggled.connect(func(on: bool) -> void: on_pick.call(i if on else -1))
		flow.add_child(chip)
		chips.append(chip)
	return chips

## Shows the chip at index as picked and the others not (-1: none), without calling on_pick.
static func show_picked(chips: Array[Button], index: int) -> void:
	for i in chips.size():
		chips[i].set_pressed_no_signal(i == index)

## Shows a chip's label with how many songs it would list, greyed out at none unless it is the picked one (so the
## list can't be filtered empty).
static func show_count(chip: Button, label: String, count: int) -> void:
	if chip.custom_minimum_size.x == 0.0:
		chip.text = COUNT_LABEL % [label, COUNT_ROOM]
		chip.custom_minimum_size.x = chip.get_minimum_size().x
	chip.text = COUNT_LABEL % [label, count]
	chip.disabled = count == 0 and not chip.button_pressed

## A search's chip text: the search in quotes, cut to SEARCH_CHIP_LETTERS.
static func search_text(search: String) -> String:
	var shown := search if search.length() <= SEARCH_CHIP_LETTERS else search.left(SEARCH_CHIP_LETTERS).strip_edges() + "…"
	return "\"%s\"" % shown

## Fills the row above a list with chips [text, what pressing its x does]: `chips` (a search, a mapper), then
## `filters`; when they don't fit, one SOME_FILTERS_TEXT chip calling clear_filters stands for the filters. The row
## keeps its height with no chips, so the list under it never moves.
static func fill_row(row: HBoxContainer, chips: Array, filters: Array, clear_filters: Callable) -> void:
	_fill(row, chips + filters)
	if row.get_combined_minimum_size().x > row.size.x:
		_fill(row, chips + [[SOME_FILTERS_TEXT % filters.size(), clear_filters]])

static func _fill(row: HBoxContainer, chips: Array) -> void:
	for chip in row.get_children():
		row.remove_child(chip)
		chip.queue_free()
	for entry: Array in chips:
		var chip := Button.new()
		chip.theme_type_variation = &"ChipButton"
		chip.text = entry[0]
		chip.icon = CLEAR_ICON
		chip.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		chip.add_theme_constant_override(&"icon_max_width", CHIP_ICON_SIZE)
		chip.pressed.connect(entry[1] as Callable)
		UI_AudioEngine.attach_button(chip)
		row.add_child(chip)
