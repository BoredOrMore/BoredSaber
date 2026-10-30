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
	chip.text = COUNT_LABEL % [label, count]
	chip.disabled = count == 0 and not chip.button_pressed
