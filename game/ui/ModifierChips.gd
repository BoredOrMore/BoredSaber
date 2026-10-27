class_name ModifierChips
extends RefCounted
## The song menu's modifier controls on the Song tab (BeepSaberMainMenu.gd): the fail and damage rows, the on/off and
## Speed chips, the More modifiers view, the environment picker and the reset button, kept in step with Settings.
## Also the row-button helpers the menu's difficulty picker and the settings panel share.

var _menu: MainMenu

func _init(menu: MainMenu) -> void:
	_menu = menu

## Fills every row with its chips; call once the menu is in the tree (the chips read its theme).
func build() -> void:
	_build_rows()
	_build_chips()
	_add_heading_icons()

## Icons before the Modifiers area's row headings (owner, 2026-10-27: more icons on the song menu), each with its
## word: a gauge for Speed, a cracked heart for Damage (the heart is health). ICON_SIZE px, the size of the chips'
## text. (The Modifiers heading has none: with many changes its Reset fills the row; Environment's dropdown shows
## the environment's picture, and an icon would cut its name short.)
const ICON_SIZE := 28
const SPEED_ICON := preload("res://game/ui/icons/gauge.svg")
const DAMAGE_ICON := preload("res://game/ui/icons/heart-crack.svg")

func _add_heading_icons() -> void:
	_prefix_icon(_menu.get_node(^"Modifiers/SpeedLabel") as Label, SPEED_ICON)
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

## Chip side padding, and the width of the Damage row's leading label.
const CHIP_PADDING := 6.0
## Top and bottom padding of chips, so the theme's 28 px text fits a 48 px row (3.2° at the menu's 2 m).
const CHIP_VERTICAL_PADDING := 7.0
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
		_menu.toggle_row.add_child(chip)
		set_padding(chip, CHIP_PADDING, CHIP_VERTICAL_PADDING)
	_add_option_chips(_menu.speed_row, &"music_speed", Constants.SPEEDS, Constants.SPEEDS.map(func(o: Array) -> String: return "%d%%" % o[0]))
	for row: Array in MORE_MOD_ROWS:
		var title := Label.new()
		title.text = str(row[0])
		_menu.more_mods_rows.add_child(title)
		var grid := GridContainer.new()
		grid.columns = int(row[4])
		grid.add_theme_constant_override(&"h_separation", 4)
		grid.add_theme_constant_override(&"v_separation", 6)
		_menu.more_mods_rows.add_child(grid)
		_add_option_chips(grid, row[1] as StringName, row[2] as Array, row[3] as Array)
	_claws_chip = make_row_button(Constants.CLAWS_LABEL, null, func() -> void: pass)
	_claws_chip.toggled.connect(func(on: bool) -> void:
		Settings.claws = on
		_menu.update_view())
	_menu.more_mods_rows.add_child(_claws_chip)
	set_padding(_claws_chip, CHIP_PADDING, CHIP_VERTICAL_PADDING)
	environment_picker = OptionButton.new()
	environment_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	environment_picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	environment_picker.add_theme_constant_override(&"icon_max_width", ENVIRONMENT_THUMB_WIDTH_CLOSED)
	environment_picker.get_popup().add_theme_constant_override(&"icon_max_width", ENVIRONMENT_THUMB_WIDTH)
	for environment: Array in Settings.ENVIRONMENTS:
		environment_picker.add_item(environment[1])
		environment_picker.set_item_icon(environment_picker.item_count - 1, environment_thumb(environment[0]))
	environment_picker.item_selected.connect(func(item: int) -> void: Settings.environment = Settings.ENVIRONMENTS[item][0])
	_menu.environment_row.add_child(environment_picker)
	set_padding(environment_picker, CHIP_PADDING, CHIP_VERTICAL_PADDING)
	show_environment()
	set_padding(_menu.reset_button, CHIP_PADDING, CHIP_VERTICAL_PADDING)
	set_padding(_menu.more_mods_button, CHIP_PADDING, CHIP_VERTICAL_PADDING)
	# the star and its label in a 48 px button: the theme's 12 px padding would make it 60 px, into the picker
	set_padding(_menu.favorite_button, CHIP_PADDING, CHIP_VERTICAL_PADDING)

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
		set_padding(chip, CHIP_PADDING, CHIP_VERTICAL_PADDING)
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

## A small picture of each environment, by id, shown in the environment dropdown when the file exists.
const ENVIRONMENT_THUMBS := "res://game/env/thumbs/%s.png"
## how wide the pictures show in the open list, and on the closed dropdown, which must stay one row high
const ENVIRONMENT_THUMB_WIDTH := 128
const ENVIRONMENT_THUMB_WIDTH_CLOSED := 36
## The environment dropdown on the Song tab, under Damage (Settings.ENVIRONMENTS).
var environment_picker: OptionButton

## "Follow map" with a song selected names the environment that song will get, short enough for the Song tab.
const MAP_ENVIRONMENT_TEXT := "Map's: %s"

## Shows the saved pick; "Follow map" also names the environment the selected song will get.
func show_environment() -> void:
	if not environment_picker:
		return
	var ids: Array = Settings.ENVIRONMENTS.map(func(e: Array) -> String: return e[0])
	environment_picker.select(maxi(ids.find(Settings.environment), 0))
	var follow: String = Settings.ENVIRONMENTS[0][1]
	var resolved := EventDriver.map_environment(_menu._shown_map)
	if _menu._shown_map:
		follow = MAP_ENVIRONMENT_TEXT % Settings.ENVIRONMENTS[ids.find(resolved)][1]
	environment_picker.set_item_text(0, follow)
	environment_picker.set_item_icon(0, environment_thumb(resolved))

## The picture of an environment, or null when there is none.
static func environment_thumb(id: String) -> Texture2D:
	var path := ENVIRONMENT_THUMBS % id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

## Fills the fail and damage rows with one toggle button per option, so they're a single press away;
## the damage row starts with a "Damage" label.
func _build_rows() -> void:
	var fail_group := ButtonGroup.new()
	for i in Constants.FAIL_OPTIONS.size():
		var chip := make_row_button(Constants.FAIL_OPTIONS[i][2], fail_group, _on_fail_option_pressed.bind(i))
		_menu.fail_row.add_child(chip)
		set_padding(chip, CHIP_PADDING, CHIP_VERTICAL_PADDING)
	var damage_label := Label.new()
	damage_label.text = "Damage"
	damage_label.custom_minimum_size.x = ROW_LABEL_WIDTH
	_menu.damage_row.add_child(damage_label)
	var damage_group := ButtonGroup.new()
	for i in Constants.DAMAGE_SCALES.size():
		var chip := make_row_button(Constants.DAMAGE_SCALES[i][1], damage_group, _on_damage_option_pressed.bind(i))
		_menu.damage_row.add_child(chip)
		set_padding(chip, CHIP_PADDING, CHIP_VERTICAL_PADDING)
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
	for chip: Button in _menu.toggle_row.get_children():
		var toggle: Array = TOGGLE_CHIPS[chip.get_index()]
		chip.set_pressed_no_signal(Settings.get(toggle[1] as StringName) == toggle[2])
	for row: Array in _option_rows:
		var chips: Array = row[0]
		for i in chips.size():
			(chips[i] as Button).set_pressed_no_signal(Settings.get(row[1] as StringName) == row[2][i])
	_claws_chip.set_pressed_no_signal(Settings.claws)
	var changed := changed()
	_menu.reset_button.visible = changed.size() > 0
	_menu.reset_button.text = "%d changed · Reset" % changed.size()
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
static func make_row_button(text: String, group: ButtonGroup, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(on_pressed)
	return button

## Gives button, already in the tree so it reads the menu theme, narrower padding in every state, so a row
## of chips fits the column; vertical padding changes only when given.
static func set_padding(button: Button, side: float, vertical := -1.0) -> void:
	for style: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		# the menu theme's Button look, also for an OptionButton (whose own focus style is the engine's)
		var box := button.get_theme_stylebox(style, &"Button").duplicate() as StyleBox
		box.content_margin_left = side
		box.content_margin_right = side
		if vertical >= 0.0:
			box.content_margin_top = vertical
			box.content_margin_bottom = vertical
		button.add_theme_stylebox_override(style, box)
