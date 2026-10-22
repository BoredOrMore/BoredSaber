extends Panel
class_name SettingsPanel

signal apply()
## "Measure the menu" was pressed (Benchmark).
signal benchmark_requested()
@export var beepsaber_game : BeepSaber_Game

@onready var saber_control := $Tabs/Visuals/VBox/SaberTypeRow/saber as OptionButton
@onready var color_preset_control := $Tabs/Visuals/VBox/ColorPresetRow/color_preset as OptionButton
@onready var glare_control := $Tabs/Visuals/VBox/glare as CheckButton
@onready var smoke_control := $Tabs/Visuals/VBox/smoke as CheckButton
@onready var saber_tail_control := $Tabs/Visuals/VBox/saber_tail as CheckButton
@onready var saber_thickness := $Tabs/Visuals/VBox/SaberThicknessRow/saber_thickness as HSlider
@onready var cut_blocks := $Tabs/Visuals/VBox/cut_blocks as CheckButton
@onready var left_saber_col := $Tabs/Visuals/VBox/SaberColorsRow/left_saber_col as ColorPickerButton
@onready var right_saber_col := $Tabs/Visuals/VBox/SaberColorsRow/right_saber_col as ColorPickerButton
@onready var show_debug_control := $Tabs/Advanced/VBox/show_debug as CheckButton
@onready var mixed_reality_control := $Tabs/Visuals/VBox/mixed_reality as CheckButton
@onready var explain_control := $Tabs/Gameplay/VBox/explain as CheckButton
@onready var left_handed_control := $Tabs/Gameplay/VBox/left_handed as CheckButton
@onready var not_music_dl_control := $Tabs/Audio/VBox/not_music_dl as CheckButton
@onready var swing_scoring_control := $Tabs/Gameplay/VBox/swing_scoring as CheckButton
@onready var show_collisions := $Tabs/Advanced/VBox/show_collisions as CheckButton
@onready var ui_volume_slider := $Tabs/Audio/VBox/UI_VolumeRow/ui_volume_slider as HSlider
@onready var left_saber_posx_control := $Tabs/Advanced/VBox/left_saber_offset/pos_row/posx as SpinBox
@onready var left_saber_posy_control := $Tabs/Advanced/VBox/left_saber_offset/pos_row/posy as SpinBox
@onready var left_saber_posz_control := $Tabs/Advanced/VBox/left_saber_offset/pos_row/posz as SpinBox
@onready var left_saber_rotx_control := $Tabs/Advanced/VBox/left_saber_offset/rot_row/rotx as SpinBox
@onready var left_saber_roty_control := $Tabs/Advanced/VBox/left_saber_offset/rot_row/roty as SpinBox
@onready var left_saber_rotz_control := $Tabs/Advanced/VBox/left_saber_offset/rot_row/rotz as SpinBox
@onready var right_saber_posx_control := $Tabs/Advanced/VBox/right_saber_offset/pos_row/posx as SpinBox
@onready var right_saber_posy_control := $Tabs/Advanced/VBox/right_saber_offset/pos_row/posy as SpinBox
@onready var right_saber_posz_control := $Tabs/Advanced/VBox/right_saber_offset/pos_row/posz as SpinBox
@onready var right_saber_rotx_control := $Tabs/Advanced/VBox/right_saber_offset/rot_row/rotx as SpinBox
@onready var right_saber_roty_control := $Tabs/Advanced/VBox/right_saber_offset/rot_row/roty as SpinBox
@onready var right_saber_rotz_control := $Tabs/Advanced/VBox/right_saber_offset/rot_row/rotz as SpinBox
@onready var player_height_offset_control := $Tabs/Gameplay/VBox/player_height_offset/pos as SpinBox
@onready var audio_master_control := $Tabs/Audio/VBox/audio/master/master_slider as HSlider
@onready var audio_music_control := $Tabs/Audio/VBox/audio/music/music_slider as HSlider
@onready var audio_music_preview_control := $Tabs/Audio/VBox/audio/music_preview/music_preview_slider as HSlider
@onready var audio_sfx_control := $Tabs/Audio/VBox/audio/sfx/sfx_slider as HSlider
@onready var spectator_view_control := $Tabs/Advanced/VBox/spectator_view as CheckButton
@onready var spectator_hud_control := $Tabs/Advanced/VBox/spectator_hud as CheckButton
@onready var background_mode_control := $Tabs/Visuals/VBox/background_mode_grid/background_mode as OptionButton
@onready var background_texture_control := $Tabs/Visuals/VBox/background_texture_grid/background_texture as OptionButton
@onready var note_style_control := $Tabs/Visuals/VBox/note_style_grid/note_style as OptionButton
@onready var darker_notes_control := $Tabs/Visuals/VBox/darker_notes as CheckButton

const SWATCH_SIZE := 24

var _play_ui_sound_demo := false
var left_saber_col_state := false
var right_saber_col_state := false

@export var main_menu_ref : MainMenu

func _ready() -> void:
	UI_AudioEngine.attach_children(self)
	# switching player changes these two behind the panel's back
	Settings.changed.connect(func(key: StringName) -> void:
		if key == &"left_handed":
			left_handed_control.set_pressed_no_signal(Settings.left_handed)
		elif key == &"player_height_offset":
			player_height_offset_control.set_value_no_signal(Settings.player_height_offset))
	
	if OS.get_name() in ["Android", "Web"]:
		spectator_hud_control.hide()
		spectator_view_control.hide()

	for i in len(Settings.BACKGROUND_MODES):
		background_mode_control.add_item(Settings.BACKGROUND_MODES[i][1])
		if Settings.background == Settings.BACKGROUND_MODES[i][0]:
			background_mode_control.selected = i
	background_mode_control.connect("item_selected", _on_background_mode_selected)
	_add_debug_view_switches()
	_add_graphics_row()

	for i in len(Settings.NOTE_STYLES):
		note_style_control.add_item(Settings.NOTE_STYLES[i][1])
		if Settings.note_style == Settings.NOTE_STYLES[i][0]:
			note_style_control.selected = i
	note_style_control.item_selected.connect(_on_note_style_selected)
	
	_update_backgrounds()

	color_preset_control.add_item("Custom")
	for preset: Array in Settings.COLOR_PRESETS:
		color_preset_control.add_icon_item(_preset_swatch(preset[1], preset[2]), preset[0])
	color_preset_control.item_selected.connect(_on_color_preset_selected)

	set_controls_from_settings()
	_play_ui_sound_demo = true
	# each saber's position and rotation row has a Reset back to 0
	for row: Node in [$Tabs/Advanced/VBox/left_saber_offset/pos_row, $Tabs/Advanced/VBox/left_saber_offset/rot_row,
			$Tabs/Advanced/VBox/right_saber_offset/pos_row, $Tabs/Advanced/VBox/right_saber_offset/rot_row]:
		(row.get_node(^"reset") as Button).pressed.connect(_reset_row.bind(row))
	for picker in [left_saber_col.get_picker(),right_saber_col.get_picker()]:
		picker.sampler_visible = false
		picker.presets_visible = true
		picker.picker_shape = ColorPicker.SHAPE_NONE
		picker.add_recent_preset(Color("ff1a1a"))
		picker.add_recent_preset(Color("1a1aff"))
			
	if OS.get_name() == &"Web":
		# way too heavy for webxr
		$Tabs/Visuals/VBox/glare.hide()
		
func _update_backgrounds() -> void:
	var selected := 0
	background_texture_control.clear()
	for i in len(Settings.BACKGROUND_TEXTURES):
		background_texture_control.add_item(Settings.BACKGROUND_TEXTURES[i][1])
		if Settings.background_texture == Settings.BACKGROUND_TEXTURES[i][0]:
			selected = i
	var dir := DirAccess.open(Constants.APPDATA_PATH + "Backgrounds")
	var i := len(Settings.BACKGROUND_TEXTURES)
	if dir:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if not dir.current_is_dir():
				background_texture_control.add_item(name)
				if Settings.background_texture == name:
					selected = i
				i += 1
			name = dir.get_next()
	background_texture_control.selected = selected
	# this runs each time Settings opens; connect once
	if not background_texture_control.item_selected.is_connected(_on_background_texture_selected):
		background_texture_control.item_selected.connect(_on_background_texture_selected)
	
func set_controls_from_settings() -> void:
	saber_control.clear()
	for s in Settings.SABER_VISUALS:
		saber_control.add_item(s[0])
	
	show_collisions.button_pressed = get_tree().debug_collisions_hint
	show_collisions.visible = OS.is_debug_build()
	
	# set the selections to the loaded values
	await get_tree().process_frame
	saber_thickness.value = Settings.thickness
	cut_blocks.button_pressed = Settings.cube_cuts_falloff
	left_saber_col.color = Settings.color_left
	right_saber_col.color = Settings.color_right
	_update_color_preset_selection()
	saber_tail_control.button_pressed = Settings.saber_tail
	glare_control.button_pressed = Settings.glare
	smoke_control.button_pressed = Settings.smoke
	darker_notes_control.button_pressed = Settings.darker_notes
	saber_control.select(Settings.saber_visual)
	show_debug_control.button_pressed = Settings.show_debug_info
	mixed_reality_control.button_pressed = Settings.mixed_reality
	explain_control.button_pressed = Settings.explain
	left_handed_control.button_pressed = Settings.left_handed
	not_music_dl_control.button_pressed = Settings.not_music_dl
	swing_scoring_control.button_pressed = Settings.swing_scoring
	ui_volume_slider.value = Settings.ui_volume
	left_saber_posx_control.value = Settings.left_saber_offset_pos.x
	left_saber_posy_control.value = Settings.left_saber_offset_pos.y
	left_saber_posz_control.value = Settings.left_saber_offset_pos.z
	left_saber_rotx_control.value = Settings.left_saber_offset_rot.x
	left_saber_roty_control.value = Settings.left_saber_offset_rot.y
	left_saber_rotz_control.value = Settings.left_saber_offset_rot.z
	right_saber_posx_control.value = Settings.right_saber_offset_pos.x
	right_saber_posy_control.value = Settings.right_saber_offset_pos.y
	right_saber_posz_control.value = Settings.right_saber_offset_pos.z
	right_saber_rotx_control.value = Settings.right_saber_offset_rot.x
	right_saber_roty_control.value = Settings.right_saber_offset_rot.y
	right_saber_rotz_control.value = Settings.right_saber_offset_rot.z
	player_height_offset_control.value = Settings.player_height_offset
	audio_master_control.value = Settings.audio_master
	audio_music_control.value = Settings.audio_music
	audio_music_preview_control.value = Settings.audio_music_preview
	audio_sfx_control.value = Settings.audio_sfx
	spectator_view_control.button_pressed = Settings.spectator_view
	spectator_hud_control.button_pressed = Settings.spectator_hud

func _restore_defaults() -> void:
	Settings.restore_defaults()
	set_controls_from_settings()

#settings down here
func _on_thickness_value_changed(value: float) -> void:
	Settings.thickness = value

func _on_cut_blocks_toggled(button_pressed: bool) -> void:
	Settings.cube_cuts_falloff = button_pressed

func _on_left_saber_color_changed(color: Color) -> void:
	Settings.color_left = color
	_update_color_preset_selection()

func _on_right_saber_color_changed(color: Color) -> void:
	Settings.color_right = color
	_update_color_preset_selection()

## Applies the chosen colour preset to both sabers. Item 0 is "Custom", presets start at item 1.
func _on_color_preset_selected(index: int) -> void:
	if index == 0:
		return
	var preset: Array = Settings.COLOR_PRESETS[index - 1]
	Settings.color_left = preset[1]
	Settings.color_right = preset[2]
	left_saber_col.color = preset[1]
	right_saber_col.color = preset[2]

## A small left/right colour chip, so each preset shows its colours in the list.
func _preset_swatch(left: Color, right: Color) -> ImageTexture:
	var image := Image.create(SWATCH_SIZE * 2, SWATCH_SIZE, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 0, SWATCH_SIZE, SWATCH_SIZE), left)
	image.fill_rect(Rect2i(SWATCH_SIZE, 0, SWATCH_SIZE, SWATCH_SIZE), right)
	return ImageTexture.create_from_image(image)

func _on_darker_notes_toggled(button_pressed: bool) -> void:
	Settings.darker_notes = button_pressed

## Selects the preset matching the current saber colours, or "Custom" when none matches.
func _update_color_preset_selection() -> void:
	var selected := 0
	for i in len(Settings.COLOR_PRESETS):
		var preset: Array = Settings.COLOR_PRESETS[i]
		if Settings.color_left.is_equal_approx(preset[1]) and Settings.color_right.is_equal_approx(preset[2]):
			selected = i + 1
	color_preset_control.selected = selected

func _on_saber_tail_toggled(button_pressed: bool) -> void:
	Settings.saber_tail = button_pressed

func _on_glare_toggled(button_pressed: bool) -> void:
	Settings.glare = button_pressed

func _on_smoke_toggled(button_pressed: bool) -> void:
	Settings.smoke = button_pressed

func _on_saber_item_selected(index: int) -> void:
	Settings.saber_visual = index

func _on_show_debug_toggled(button_pressed: bool) -> void:
	Settings.show_debug_info = button_pressed
	_show_debug_view_switches()

var _debug_view_switches: Array[CheckButton] = []

## The DebugView switches go right under Show Debug Info and only show while it is on.
func _add_debug_view_switches() -> void:
	var index := show_debug_control.get_index()
	for entry: Array in DebugView.SWITCHES:
		var bit: int = entry[1]
		var switch := CheckButton.new()
		switch.text = "  %s:" % entry[0]
		switch.button_pressed = DebugView.flags & bit != 0
		switch.toggled.connect(func(on: bool) -> void: DebugView.set_flag(bit, on))
		index += 1
		show_debug_control.get_parent().add_child(switch)
		show_debug_control.get_parent().move_child(switch, index)
		_debug_view_switches.append(switch)
	var measure := Button.new()
	measure.text = "Measure the menu (%d min, wear the headset)" % ceili(Benchmark.total_seconds() / 60.0)
	measure.pressed.connect(benchmark_requested.emit)
	index += 1
	show_debug_control.get_parent().add_child(measure)
	show_debug_control.get_parent().move_child(measure, index)
	_show_debug_view_switches()

## What each graphics chip means, under the chips.
const GRAPHICS_HINTS := {
	"Low": "Less glow and effects",
	"Normal": "Every effect on",
	Settings.GRAPHICS_CUSTOM: "Effects below changed one by one",
}
const RESOLUTION_HINTS := {
	"Normal": "Standard sharpness",
	"Sharp": "Sharper",
	"Full": "Sharpest",
}
const RESOLUTION_NEEDS_LOW := "Needs Graphics: Low"
const MSAA_HINTS := {
	"Off": "Jagged edges",
	"2x": "Smoother edges",
	"4x": "Smoothest edges",
}

var _graphics_chips := {}
var _graphics_hint := Label.new()
var _resolution_chips := {}
var _resolution_hint := Label.new()
var _msaa_chips := {}
var _msaa_hint := Label.new()

## At the top of Visuals: "Graphics: Low | Normal" chips setting the effects below (a third chip, Custom, can't be
## picked and lights up when the effects match neither), then "Resolution: Normal | Sharp | Full", only on Low.
func _add_graphics_row() -> void:
	_graphics_chips = _add_chip_row(0, "Graphics", Settings.GRAPHICS_PRESETS.keys() + [Settings.GRAPHICS_CUSTOM],
			Settings.set_graphics_preset, _graphics_hint)
	var custom := _graphics_chips[Settings.GRAPHICS_CUSTOM] as Button
	# lit when it applies, but the pointer can't pick it (a disabled button wouldn't light up)
	custom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom.focus_mode = Control.FOCUS_NONE
	_resolution_chips = _add_chip_row(2, "Resolution", Settings.RESOLUTIONS.map(func(r: Array) -> String: return r[0]),
			func(resolution: String) -> void: Settings.resolution = resolution, _resolution_hint)
	_msaa_chips = _add_chip_row(4, "Anti-aliasing", Settings.MSAA_LEVELS.map(func(m: Array) -> String: return m[0]),
			func(level: String) -> void: Settings.msaa = level, _msaa_hint)
	Settings.changed.connect(func(key: StringName) -> void:
		if key in [&"resolution", &"msaa"] or key in Settings.GRAPHICS_PRESETS["Low"]:
			_sync_graphics())
	_sync_graphics()

## A row of chips under a row label at index in Visuals, each calling pick with its name, and hint under it;
## returns the chips by name.
func _add_chip_row(index: int, title: String, names: Array, pick: Callable, hint: Label) -> Dictionary:
	var visuals := $Tabs/Visuals/VBox as VBoxContainer
	var row_label := $Tabs/Visuals/VBox/ColorPresetRow/color_preset_label as Label
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = row_label.custom_minimum_size
	label.add_theme_stylebox_override(&"normal", row_label.get_theme_stylebox(&"normal"))
	row.add_child(label)
	var group := ButtonGroup.new()
	var chips := {}
	for chip_name: String in names:
		var chip := Button.new()
		chip.text = chip_name
		chip.toggle_mode = true
		chip.button_group = group
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.pressed.connect(pick.bind(chip_name))
		row.add_child(chip)
		chips[chip_name] = chip
	visuals.add_child(row)
	visuals.move_child(row, index)
	# the song menu's chip padding, so three fit beside the row label
	for chip: Button in chips.values():
		MainMenu._set_padding(chip, MainMenu.CHIP_PADDING)
	hint.add_theme_stylebox_override(&"normal", row_label.get_theme_stylebox(&"normal"))
	hint.add_theme_color_override(&"font_color", Constants.UI_TEXT_MUTED)
	hint.add_theme_font_size_override(&"font_size", 22)
	visuals.add_child(hint)
	visuals.move_child(hint, index + 1)
	UI_AudioEngine.attach_children(row)
	return chips

## Lights the chips of the preset the effects match and of the resolution (greyed off Low), and shows the effects'
## switches as set (a preset sets them).
func _sync_graphics() -> void:
	var preset := Settings.graphics_preset()
	for name: String in _graphics_chips:
		(_graphics_chips[name] as Button).set_pressed_no_signal(name == preset)
	_graphics_hint.text = GRAPHICS_HINTS[preset]
	# Custom only reads as a choice while it applies
	(_graphics_chips[Settings.GRAPHICS_CUSTOM] as Button).modulate.a = 1.0 if preset == Settings.GRAPHICS_CUSTOM else 0.4
	var low := preset == "Low"
	for name: String in _resolution_chips:
		var chip := _resolution_chips[name] as Button
		chip.disabled = not low
		chip.set_pressed_no_signal(name == (Settings.resolution if low else "Normal"))
	_resolution_hint.text = RESOLUTION_HINTS.get(Settings.resolution, "") if low else RESOLUTION_NEEDS_LOW
	for name: String in _msaa_chips:
		(_msaa_chips[name] as Button).set_pressed_no_signal(name == Settings.msaa)
	_msaa_hint.text = MSAA_HINTS.get(Settings.msaa, "")
	glare_control.set_pressed_no_signal(Settings.glare)
	smoke_control.set_pressed_no_signal(Settings.smoke)
	saber_tail_control.set_pressed_no_signal(Settings.saber_tail)
	cut_blocks.set_pressed_no_signal(Settings.cube_cuts_falloff)
	for i in Settings.BACKGROUND_MODES.size():
		if Settings.BACKGROUND_MODES[i][0] == Settings.background:
			background_mode_control.selected = i

func _show_debug_view_switches() -> void:
	for switch in _debug_view_switches:
		switch.visible = Settings.show_debug_info

func _on_mixed_reality_toggled(button_pressed: bool) -> void:
	Settings.mixed_reality = button_pressed
	MixedReality.set_mixed_reality(Settings.mixed_reality)

func _on_explain_toggled(button_pressed: bool) -> void:
	Settings.explain = button_pressed

func _on_swing_scoring_toggled(button_pressed: bool) -> void:
	Settings.swing_scoring = button_pressed

func _on_ui_volume_slider_value_changed(value: float) -> void:
	UI_AudioEngine.set_volume(linear_to_db(float(value)/10.0))
	if _play_ui_sound_demo:
		UI_AudioEngine.play_click()
	
	Settings.ui_volume = value

func _on_left_saber_pos_x_changed(value: float) -> void:
	Settings.left_saber_offset_pos.x = value

func _on_left_saber_pos_y_changed(value: float) -> void:
	Settings.left_saber_offset_pos.y = value

func _on_left_saber_pos_z_changed(value: float) -> void:
	Settings.left_saber_offset_pos.z = value

func _on_left_saber_rot_x_changed(value: float) -> void:
	Settings.left_saber_offset_rot.x = value

func _on_left_saber_rot_y_changed(value: float) -> void:
	Settings.left_saber_offset_rot.y = value

func _on_left_saber_rot_z_changed(value: float) -> void:
	Settings.left_saber_offset_rot.z = value

func _on_right_saber_pos_x_changed(value: float) -> void:
	Settings.right_saber_offset_pos.x = value

func _on_right_saber_pos_y_changed(value: float) -> void:
	Settings.right_saber_offset_pos.y = value

func _on_right_saber_pos_z_changed(value: float) -> void:
	Settings.right_saber_offset_pos.z = value

func _on_right_saber_rot_x_changed(value: float) -> void:
	Settings.right_saber_offset_rot.x = value

func _on_right_saber_rot_y_changed(value: float) -> void:
	Settings.right_saber_offset_rot.y = value

func _on_right_saber_rot_z_changed(value: float) -> void:
	Settings.right_saber_offset_rot.z = value

func _on_player_height_offset_changed(value: float) -> void:
	Settings.player_height_offset = value

## Sets every number in a saber offset row back to 0.
func _reset_row(row: Node) -> void:
	for control in row.get_children():
		if control is SpinBox:
			(control as SpinBox).value = 0.0

## Stand straight and press: raises or lowers the view so the eyes are at Constants.EYE_HEIGHT, the height the
## notes and walls are laid out for, as far as the adjust range allows.
func _on_measure_height_pressed() -> void:
	var eyes := vr.get_current_player_height()
	player_height_offset_control.value = clampf(snappedf(Constants.EYE_HEIGHT - eyes, 0.01),
			player_height_offset_control.min_value, player_height_offset_control.max_value)

func _force_update_show_coll_shapes(node: Node) -> void:
	# toggle enable to make engine show collision shapes
	if node is CollisionShape3D:
		var col := node as CollisionShape3D
		col.disabled = not col.disabled
		col.disabled = not col.disabled
	elif node is RayCast3D:
		var ray := node as RayCast3D
		ray.enabled = not ray.enabled
		ray.enabled = not ray.enabled
	
	for c in node.get_children():
		_force_update_show_coll_shapes(c)

func _on_show_collisions_toggled(button_pressed: bool) -> void:
	get_tree().debug_collisions_hint = button_pressed
	# must toggle 
	_force_update_show_coll_shapes(get_tree().root)

func _on_apply_pressed() -> void:
	Settings.save()
	apply.emit()
	left_saber_col.get_popup().hide()
	right_saber_col.get_popup().hide()
	left_saber_col_state = false
	right_saber_col_state = false

func _on_master_slider_value_changed(value: float) -> void:
	Settings.audio_master = value

func _on_music_slider_value_changed(value: float) -> void:
	Settings.audio_music = value

func _on_music_preview_slider_value_changed(value: float) -> void:
	Settings.audio_music_preview = value

func _on_sfx_slider_value_changed(value: float) -> void:
	Settings.audio_sfx = value

func _on_spectator_view_toggled(value: bool) -> void:
	Settings.spectator_view = value

func _on_spectator_hud_toggled(value: bool) -> void:
	Settings.spectator_hud = value


func _on_recenter_button_up() -> void:
	var recenter_button : Button = $Tabs/Gameplay/VBox/recenter
	recenter_button.disabled = true
	recenter_button.text = "3.."
	await get_tree().create_timer(1).timeout
	recenter_button.text = "2.."
	await get_tree().create_timer(1).timeout
	recenter_button.text = "1.."
	await get_tree().create_timer(1).timeout
	recenter_button.text = "Recenter"
	recenter_button.disabled = false
	beepsaber_game.recenter()

## Opens or closes the left saber's colour picker; only one picker is open at a time, so they never overlap.
func _on_left_saber_col_pressed() -> void:
	if left_saber_col_state:
		left_saber_col.get_popup().hide()
	left_saber_col_state = not left_saber_col_state
	right_saber_col.get_popup().hide()
	right_saber_col_state = false

## Opens or closes the right saber's colour picker, closing the left one.
func _on_right_saber_col_pressed() -> void:
	if right_saber_col_state:
		right_saber_col.get_popup().hide()
	right_saber_col_state = not right_saber_col_state
	left_saber_col.get_popup().hide()
	left_saber_col_state = false

func _on_not_music_dl_toggled(button_pressed: bool) -> void:
	Settings.not_music_dl = button_pressed

func _on_background_texture_selected(item: int) -> void:
	if item < len(Settings.BACKGROUND_TEXTURES):
		Settings.background_texture = Settings.BACKGROUND_TEXTURES[item][0]
	else:
		Settings.background_texture = background_texture_control.get_item_text(item)

func _on_background_mode_selected(item: int) -> void:
	Settings.background = Settings.BACKGROUND_MODES[item][0]

func _on_note_style_selected(item: int) -> void:
	Settings.note_style = Settings.NOTE_STYLES[item][0]

func _on_left_handed_toggled(value: bool) -> void:
	Settings.left_handed = value
