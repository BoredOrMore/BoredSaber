class_name ModifierChips
extends RefCounted
## The song menu's modifier controls on the Song tab (BeepSaberMainMenu.gd): the fail and damage rows, the on/off and
## Speed chips, the More modifiers view, the environment picker and the reset button, kept in step with Settings.
## Also the row-button helpers the menu's difficulty picker and the settings panel share.

var _menu: MainMenu

func _init(menu: MainMenu) -> void:
	_menu = menu

func _map_colors_row() -> HBoxContainer:
	return _menu.get_node(^"Modifiers/Look/MapColorsRow") as HBoxContainer

## Fills every row with its chips; call once the menu is in the tree (the chips read its theme).
func build() -> void:
	_build_rows()
	_build_chips()
	_add_heading_icons()

## Icons before the Modifiers area's row headings (owner, 2026-10-27: more icons on the song menu), each with its
## word: a gauge for Speed, a crossed-out bolt for Damage (the bolt is Energy, owner 2026-10-28). ICON_SIZE px, the size of the chips'
## text. (The Modifiers heading has none: with many changes its Reset fills the row; Environment's dropdown shows
## the environment's picture.)
const ICON_SIZE := 28
const SPEED_ICON := preload("res://game/ui/icons/gauge.svg")
const DAMAGE_ICON := preload("res://game/ui/icons/zap-off.svg")

func _add_heading_icons() -> void:
	_prefix_icon(_menu.get_node(^"Modifiers/Speed/Title") as Label, SPEED_ICON)
	_prefix_icon(_menu.damage_row.get_child(0) as Label, DAMAGE_ICON)

## Puts icon just before label: in its row, the label giving up the icon's room so the columns stay put, or in a
## new row where the label stood alone.
func _prefix_icon(label: Label, icon: Texture2D) -> void:
	var image := TextureRect.new()
	image.texture = icon
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2.ONE * ICON_SIZE
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var parent := label.get_parent()
	if parent is HBoxContainer:
		parent.add_child(image)
		parent.move_child(image, label.get_index())
		if label.custom_minimum_size.x > 0.0:
			label.custom_minimum_size.x -= ICON_SIZE + (parent as HBoxContainer).get_theme_constant(&"separation")
		return
	var row := HBoxContainer.new()
	parent.add_child(row)
	parent.move_child(row, label.get_index())
	label.reparent(row)
	row.add_child(image)
	row.move_child(image, 0)

## The width of the Damage row's leading label. (Chips' padding is the ChipButton kind's, menu_theme.tres: 28 px
## text in a 48 px row, 3.2° at the menu's 2 m.)
const ROW_LABEL_WIDTH := 110.0
const MORE_MODS_TEXT := "More modifiers"
## On/off chips on the Song tab: [label, Settings key, value of the key while the chip is on].
const TOGGLE_CHIPS := [["Walls", &"walls_enabled", true], ["Bombs", &"bombs_enabled", true],
	["Arrows", &"arrows_enabled", true], ["Map colors", &"disable_map_color", false]]
## The rarer modifiers in More modifiers: [title, Settings key, option table in Constants, chip labels, columns,
## default value]. Each option table row starts with the value and its name in the record table.
const MORE_MOD_ROWS := [
	["Blocks", &"block_size", Constants.SIZES, ["Small", "Normal", "Big", "Giant"], 4, 100],
	["Width", &"width", Constants.WIDTHS, ["100%", "125%", "150%", "175%", "200%"], 5, 100],
	["Mirror", &"flip", Constants.FLIPS, ["Off", "Left-Right", "Up-Down", "Both ways"], 2, 0],
	["Sabers", &"handedness", Constants.HANDEDNESSES, ["Normal", "Any color", "Left only", "Right only"], 2, 0],
]
## Speed chips and each More modifiers row: [chip buttons, Settings key, value of each chip].
var _option_rows: Array[Array] = []
var _claws_chip: Button

## Fills the Song tab's on/off and Speed chips and the More modifiers view.
func _build_chips() -> void:
	for toggle: Array in TOGGLE_CHIPS:
		var chip := make_row_button(str(toggle[0]), null, func() -> void: pass)
		chip.toggled.connect(func(on: bool) -> void:
			Settings.set(toggle[1] as StringName, on == toggle[2])
			_menu.update_view())
		# Map colors is a look, above the environment
		(_map_colors_row() if toggle[1] == &"disable_map_color" else _menu.toggle_row).add_child(chip)
	_add_option_chips(_menu.speed_row, &"music_speed", Constants.SPEEDS, Constants.SPEEDS.map(func(o: Array) -> String: return "%d%%" % o[0]))
	MenuSection.section_list(_menu.more_mods_rows)
	for row: Array in MORE_MOD_ROWS:
		var section := MenuSection.make(str(row[0]))
		_menu.more_mods_rows.add_child(section)
		var grid := GridContainer.new()
		grid.columns = int(row[4])
		grid.add_theme_constant_override(&"h_separation", 4)
		grid.add_theme_constant_override(&"v_separation", 6)
		section.add_child(grid)
		_add_option_chips(grid, row[1] as StringName, row[2] as Array, row[3] as Array)
	_claws_chip = make_row_button(Constants.CLAWS_LABEL, null, func() -> void: pass)
	_claws_chip.toggled.connect(func(on: bool) -> void:
		Settings.claws = on
		_menu.update_view())
	_menu.more_mods_rows.add_child(_claws_chip)
	# the closed Environment button, and a card per environment over the modifiers once it's pressed
	environment_button = EnvironmentCard.make(null, "")
	environment_button.pressed.connect(_menu.show_environments.bind(true))
	_menu.environment_row.add_child(environment_button)
	var group := ButtonGroup.new()
	for environment: Array in Settings.ENVIRONMENTS:
		var card := EnvironmentCard.make(environment_thumb(environment[0]), environment[1])
		card.toggle_mode = true
		card.button_group = group
		card.custom_minimum_size.y = ENVIRONMENT_CARD_HEIGHT
		card.pressed.connect(func() -> void:
			Settings.environment = environment[0]
			_menu.show_environments(false))
		_environment_grid().add_child(card)
	show_environment()

## Adds one chip per option of an option table to parent, picking the option's value for key when pressed.
func _add_option_chips(parent: Container, key: StringName, options: Array, labels: Array) -> void:
	var group := ButtonGroup.new()
	var chips: Array[Button] = []
	var values := options.map(func(o: Array) -> Variant: return o[0])
	for i in options.size():
		var value: Variant = values[i]
		var chip := make_row_button(str(labels[i]), group, func() -> void:
			Settings.set(key, value)
			_menu.update_view())
		parent.add_child(chip)
		chips.append(chip)
	_option_rows.append([chips, key, values])

## Names of the modifiers that differ from the default; with rare_only, only those in More modifiers, by their
## names in the record table.
func changed(rare_only := false) -> PackedStringArray:
	var names := PackedStringArray()
	if not rare_only:
		if not Settings.health_mode or Settings.fail_mode != Constants.FAIL_MODE_BAR:
			names.append("Fail")
		if not is_equal_approx(Settings.damage_scale, 1.0):
			names.append("Damage")
		for toggle: Array in TOGGLE_CHIPS:
			if Settings.get(toggle[1] as StringName) != toggle[2]:
				names.append(str(toggle[0]))
		if Settings.music_speed != 100:
			names.append("Speed")
	for row: Array in MORE_MOD_ROWS:
		var value: Variant = Settings.get(row[1] as StringName)
		if value != row[5]:
			for option: Array in row[2]:
				if option[0] == value:
					names.append(str(option[1]))
	if Settings.claws:
		names.append(Constants.CLAWS_LABEL)
	return names

## Each environment's pictures (tools/capture/env_thumbnails.sh): the card, and the wide one for the closed button.
const ENVIRONMENT_THUMBS := "res://game/env/thumbs/%s.png"
const ENVIRONMENT_WIDE_THUMBS := "res://game/env/thumbs/%s_wide.png"
## The cards' height: four rows of two (six stages and Follow map) fill the right panel under Back, so nothing scrolls
## (about 10 degrees at 2 m; three rows took 196 px before Henge).
const ENVIRONMENT_CARD_HEIGHT := 148
## The closed Environment button in the Look section, showing the pick's picture (Settings.ENVIRONMENTS).
var environment_button: EnvironmentCard

## "Follow map" with a song selected names the environment that song will get.
const MAP_ENVIRONMENT_TEXT := "Map's: %s"

func _environment_grid() -> GridContainer:
	return _menu.get_node(^"EnvironmentPanel/Rows/Grid") as GridContainer

## Shows the saved pick on the button and the cards; "Follow map" shows and names the environment the selected song
## will get.
func show_environment() -> void:
	if not environment_button:
		return
	var ids: Array = Settings.ENVIRONMENTS.map(func(e: Array) -> String: return e[0])
	var picked := maxi(ids.find(Settings.environment), 0)
	var resolved := EventDriver.map_environment(_menu._shown_map)
	var follow: String = Settings.ENVIRONMENTS[0][1]
	if _menu._shown_map:
		follow = MAP_ENVIRONMENT_TEXT % Settings.ENVIRONMENTS[ids.find(resolved)][1]
	var shown: String = resolved if picked == 0 else ids[picked]
	environment_button.show_card(environment_thumb(shown, true), follow if picked == 0 else Settings.ENVIRONMENTS[picked][1])
	var cards := _environment_grid().get_children()
	(cards[0] as EnvironmentCard).show_card(environment_thumb(resolved), follow)
	for i in cards.size():
		(cards[i] as EnvironmentCard).set_picked(i == picked)

## The picture of an environment (its wide one for the closed button), or null when there is none.
static func environment_thumb(id: String, wide := false) -> Texture2D:
	var path := (ENVIRONMENT_WIDE_THUMBS if wide else ENVIRONMENT_THUMBS) % id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

## Fills the fail and damage rows with one toggle button per option, so they're a single press away;
## the damage row starts with a "Damage" label.
func _build_rows() -> void:
	var fail_group := ButtonGroup.new()
	for i in Constants.FAIL_OPTIONS.size():
		var chip := make_row_button(Constants.FAIL_OPTIONS[i][2], fail_group, _on_fail_option_pressed.bind(i))
		_menu.fail_row.add_child(chip)
	var damage_label := Label.new()
	damage_label.text = "Damage"
	damage_label.custom_minimum_size.x = ROW_LABEL_WIDTH
	_menu.damage_row.add_child(damage_label)
	var damage_group := ButtonGroup.new()
	for i in Constants.DAMAGE_SCALES.size():
		var chip := make_row_button(Constants.DAMAGE_SCALES[i][1], damage_group, _on_damage_option_pressed.bind(i))
		_menu.damage_row.add_child(chip)
	_sync_rows()

## Shows the saved fail mode and damage scale in the rows; damage only matters for the health bar.
func _sync_rows() -> void:
	if _menu.fail_row.get_child_count() == 0:
		return
	for i in Constants.FAIL_OPTIONS.size():
		var option: Array = Constants.FAIL_OPTIONS[i]
		(_menu.fail_row.get_child(i) as Button).set_pressed_no_signal(option[0] == Settings.health_mode and (not Settings.health_mode or option[1] == Settings.fail_mode))
	var damage_counts := Settings.health_mode and Settings.fail_mode == Constants.FAIL_MODE_BAR
	for i in Constants.DAMAGE_SCALES.size():
		# the row starts with the "Damage" icon and label
		var button := _menu.damage_row.get_child(_menu.damage_row.get_child_count() - Constants.DAMAGE_SCALES.size() + i) as Button
		button.set_pressed_no_signal(is_equal_approx(Constants.DAMAGE_SCALES[i][0], Settings.damage_scale))
		button.disabled = not damage_counts

## Stores the picked fail option: No Fail turns health mode off, the others pick how to fail.
func _on_fail_option_pressed(index: int) -> void:
	Settings.health_mode = Constants.FAIL_OPTIONS[index][0]
	Settings.fail_mode = Constants.FAIL_OPTIONS[index][1]
	_menu.update_view()

## Stores the picked damage scale.
func _on_damage_option_pressed(index: int) -> void:
	Settings.damage_scale = Constants.DAMAGE_SCALES[index][0]
	_menu.update_view()

func sync() -> void:
	_sync_rows()
	var toggle_chips := _menu.toggle_row.get_children() + _map_colors_row().get_children()
	for i in TOGGLE_CHIPS.size():
		var toggle: Array = TOGGLE_CHIPS[i]
		(toggle_chips[i] as Button).set_pressed_no_signal(Settings.get(toggle[1] as StringName) == toggle[2])
	for row: Array in _option_rows:
		var chips: Array = row[0]
		for i in chips.size():
			(chips[i] as Button).set_pressed_no_signal(Settings.get(row[1] as StringName) == row[2][i])
	_claws_chip.set_pressed_no_signal(Settings.claws)
	var changed := changed()
	_menu.reset_button.visible = changed.size() > 0
	_menu.reset_button.text = "Reset (%d)" % changed.size()
	var rare := changed(true)
	_menu.more_mods_button.text = MORE_MODS_TEXT + (HighscorePanel.RUN_PARTS_SEPARATOR + ", ".join(rare) if rare.size() > 0 else "")

## Puts every modifier back to its default.
func reset() -> void:
	Settings.health_mode = true
	Settings.fail_mode = Constants.FAIL_MODE_BAR
	Settings.damage_scale = 1.0
	Settings.walls_enabled = true
	Settings.bombs_enabled = true
	Settings.arrows_enabled = true
	Settings.disable_map_color = false
	Settings.claws = false
	Settings.block_size = 100
	Settings.width = 100
	Settings.flip = 0
	Settings.music_speed = 100
	Settings.handedness = 0
	_menu.update_view()

## One option of a button row.
static func make_row_button(text: String, group: ButtonGroup, on_pressed: Callable, kind := &"ChipButton") -> Button:
	var button := Button.new()
	button.theme_type_variation = kind
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(on_pressed)
	return button
