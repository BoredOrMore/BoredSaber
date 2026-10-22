extends Node
# Headless checks that the song menu and "Who's playing?" lay out without overlaps, with worst-case content.
# Run: godot --headless --path . res://tests/test_menu_layout.tscn

## Smallest gap, in px, between two controls placed side by side with offsets (not by a container).
const MIN_GAP := 4.0
## Panels that open over others: whatever lies wholly under a visible one is hidden, not overlapped.
const OVERLAYS := ["MorePanel", "MoreModsPanel", "FiltersPanel"]
## Rows the song list must show at once at its original 76 px row size.
const MIN_VISIBLE_ROWS := 9
## The download page's canvas is at scale 2 and the song menu's at 2.4, so the same world size takes 1.2 times the px.
const MENU_TO_BEATSAVER_PX := 1.2
const LONG_NAME := "Wolfgang Amadeus Mozart and the Very Long Band Name"

var failures := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

## Holds the panels, as each game canvas's SubViewport does; pointer events are pushed into it.
var _port := SubViewport.new()

func _ready() -> void:
	var normal: Dictionary = Settings.GRAPHICS_PRESETS["Normal"]
	check(normal.keys().all(func(key: StringName) -> bool: return Settings.default_values[key] == normal[key]),
			"first-run effects are the Normal graphics preset")
	_port.size = Vector2i(1600, 1100)
	add_child(_port)
	var keyboard := (load("res://OQ_Toolkit/OQ_UI2D/OQ_UI2DKeyboard.tscn") as PackedScene).instantiate() as OQ_UI2DKeyboard
	keyboard.visible = false
	add_child(keyboard)
	var menu := (load("res://game/BeepSaberMainMenu.tscn") as PackedScene).instantiate() as MainMenu
	check(menu != null, "the song menu scene loads (a script that fails to parse leaves it without MainMenu)")
	if menu == null:
		get_tree().quit(1)
		return
	menu.keyboard = keyboard
	var player := AudioStreamPlayer.new()
	add_child(player)
	menu.main_song_player_ref = player
	_port.add_child(menu)
	menu.set_physics_process(false)
	await _settle()
	check(menu.songs_menu.item_count > 0, "the song menu lists the bundled song")
	if menu.songs_menu.item_count > 0:
		menu.songs_menu.select(0)
		menu._select_song(0, false)

	# every modifier changed, a long player name, and the busiest song details
	Settings.health_mode = false
	Settings.walls_enabled = false
	Settings.bombs_enabled = false
	Settings.arrows_enabled = false
	Settings.disable_map_color = true
	Settings.music_speed = 175
	Settings.block_size = 225
	Settings.width = 200
	Settings.flip = Constants.FLIP_HORIZONTAL | Constants.FLIP_VERTICAL
	Settings.handedness = Constants.HANDEDNESS_IGNORE
	Settings.claws = true
	Settings.players = [{"name": LONG_NAME, "player_height_offset": 0.0, "left_handed": false}]
	Settings.player_name = LONG_NAME
	menu.update_view()
	_fill_worst_details(menu)
	await _settle()
	_check_layout(menu, "song tab")

	_check_list_rows(menu.songs_menu)
	await _check_list_drag(menu)
	menu._show_filters(true)
	await _settle()
	_check_layout(menu, "filters")
	menu._show_filters(false)
	menu._show_more_modifiers(true)
	await _settle()
	_check_layout(menu, "more modifiers")
	menu._show_tab(MainMenu.Tab.MORE)
	await _settle()
	_check_layout(menu, "more tab")
	var beatsaver := (load("res://game/ui/BeatSaverPanel/BeatSaverPanel.tscn") as PackedScene).instantiate() as BeatSaverPanel
	beatsaver.main_menu_ref = menu
	beatsaver.keyboard = keyboard
	_port.add_child(beatsaver)
	await _settle()
	check((beatsaver.size - menu.size * MENU_TO_BEATSAVER_PX).abs().x < 1.0 and (beatsaver.size - menu.size * MENU_TO_BEATSAVER_PX).abs().y < 1.0, "the download page is the song menu's size in the world (got %s px)" % beatsaver.size)
	_check_layout(beatsaver, "download page")
	beatsaver.queue_free()
	menu.queue_free()

	var profiles := (load("res://game/ui/ProfilesPanel.tscn") as PackedScene).instantiate() as ProfilesPanel
	profiles.keyboard = keyboard
	Settings.players = []
	for i in Settings.MAX_PLAYERS:
		Settings.players.append({"name": "%d %s" % [i, LONG_NAME], "player_height_offset": 0.0, "left_handed": false})
	Settings.player_name = Settings.players[0].name
	_port.add_child(profiles)
	profiles._ask_delete(Settings.players[1].name)
	await _settle()
	_check_layout(profiles, "who's playing, six players, one asking to delete")

	profiles.queue_free()

	# Visuals with the Graphics chips: Low, then one effect changed (Custom)
	var settings := (load("res://game/settings_Panel.tscn") as PackedScene).instantiate() as SettingsPanel
	# no controllers here for its sliders' thumbstick scrolling
	settings.process_mode = Node.PROCESS_MODE_DISABLED
	_port.add_child(settings)
	await _settle()
	Settings.set_graphics_preset("Low")
	await _settle()
	check(settings._graphics_chips["Low"].button_pressed and not settings.glare_control.button_pressed,
			"Graphics Low lights its chip and turns Glow off")
	settings._resolution_chips["Full"].pressed.emit()
	check(Settings.render_scale() == 1.44 and not settings._resolution_chips["Full"].disabled, "Resolution Full on Low renders at 1.44x")
	Settings.glare = true
	await _settle()
	check(settings._graphics_chips[Settings.GRAPHICS_CUSTOM].button_pressed, "changing an effect by hand shows Custom")
	check(Settings.render_scale() == 1.0 and settings._resolution_chips["Full"].disabled and Settings.resolution == "Full",
			"off Low the resolution chips grey out and render at 1x, keeping Full for Low")
	(settings.get_node(^"Tabs") as TabContainer).current_tab = settings.get_node(^"Tabs/Visuals").get_index()
	await _settle()
	_check_layout(settings.get_node(^"Tabs/Visuals/VBox") as Control, "settings visuals, Custom")
	settings.queue_free()

	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)

## Fills the song details with the most they show: eight characteristic tabs, five numbered levels, two long
## stats lines and a long title, as the busiest maps on the headset do and more.
func _fill_worst_details(menu: MainMenu) -> void:
	menu.characteristic_row.visible = true
	for tab: Button in menu.characteristic_row.get_children():
		tab.visible = true
		tab.text = "Lightshow"
	for level: Button in menu.level_row.get_children():
		level.visible = true
		level.text = "Expert+ 3"
	menu.level_stats.max_lines_visible = 2
	menu.level_stats.text = "13:44 · Notes 1.00 s ahead · Swings every 0.93 s\nSwing flow: Tangled · Workout"
	(menu.get_node("SongInfo_Label") as Label).text = "%s\n%s\nMapped by %s\nPlayed 999 times" % [LONG_NAME, LONG_NAME, LONG_NAME]

## Counts the song list's whole rows in view, filling it with sample rows first (the test has one song).
func _check_list_rows(list: SongList) -> void:
	while list.item_count < 40:
		list.add_item(LONG_NAME, null)
	await _settle()
	var view := list._view_height()
	var shown := floori((view + SongList.ROW_SEPARATION) / (SongList.ROW_HEIGHT + SongList.ROW_SEPARATION))
	var row_height := list._row(0).size.y
	check(shown >= MIN_VISIBLE_ROWS and is_equal_approx(row_height, SongList.ROW_HEIGHT),
			"song list shows %d whole rows of %d px (wants %d of %d px)" % [shown, row_height, MIN_VISIBLE_ROWS, SongList.ROW_HEIGHT])

## A press that moves under 12 px picks the row; a pointer drag on the song list moves it 1:1 and picks nothing.
func _check_list_drag(menu: MainMenu) -> void:
	var list := menu.songs_menu
	list.scroll_vertical = 0
	list.deselect_all()
	await _settle()
	var at := list._row(0).get_global_rect().get_center()
	_pointer(at, null)
	await _settle()
	_pointer(at, true)
	_pointer(at + Vector2(0, 5), null)
	_pointer(at + Vector2(0, 5), false)
	await _settle()
	check(list._selected == 0 and list.scroll_vertical == 0, "a press that moves under 12 px picks the row and doesn't scroll (picked %d, scrolled %d)" % [list._selected, list.scroll_vertical])
	list.deselect_all()
	_pointer(at, true)
	_pointer(at + Vector2(0, -6), null)
	_pointer(at + Vector2(0, -126), null)
	# hold still before letting go: no flick
	await get_tree().create_timer(vr_slider_momentum() + 0.1).timeout
	_pointer(at + Vector2(0, -126), false)
	await _settle()
	# 6 px is under the threshold, then the list follows the pointer from the press: 126 px
	check(absi(list.scroll_vertical - 126) <= 2 and list._selected == -1,
			"a drag moves the list 1:1 (moved %d of 126 px) and picks no song" % list.scroll_vertical)

## How long a flick keeps going (the song list's vr_slider).
func vr_slider_momentum() -> float:
	return preload("res://game/vr_slider.gd").MOMENTUM_SECONDS

## Sends a pointer press (true), release (false) or move (null) to the menu's viewport, as the VR pointer does.
func _pointer(at: Vector2, pressed: Variant) -> void:
	var event: InputEventMouse
	if pressed == null:
		event = InputEventMouseMotion.new()
	else:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		event = button
	event.position = at
	event.global_position = at
	_port.push_input(event)

## A few frames so containers take their sizes.
func _settle() -> void:
	for i in 4:
		await get_tree().process_frame

## Every visible control stays inside its parent (and the panel), and controls placed with offsets keep
## MIN_GAP between them.
func _check_layout(root: Control, state: String) -> void:
	var problems := PackedStringArray()
	_check_children(root, root.get_global_rect(), problems)
	check(problems.is_empty(), "%s: nothing overlaps or spills out%s" % [state, "" if problems.is_empty() else "\n  " + "\n  ".join(problems)])

func _check_children(parent: Control, bounds: Rect2, problems: PackedStringArray) -> void:
	var placed: Array[Control] = []
	for node in parent.get_children():
		var child := node as Control
		if child == null or not child.visible or child.size.x <= 0.0 or child.size.y <= 0.0:
			continue
		var rect := child.get_global_rect()
		if not bounds.grow(0.5).encloses(rect):
			problems.append("%s %s spills out of %s %s" % [child.name, rect, parent.name, bounds])
		if not parent is Container:
			placed.append(child)
		# a scroll container's content is meant to run past it
		if not child is ScrollContainer:
			_check_children(child, rect, problems)
	for i in placed.size():
		for j in range(i + 1, placed.size()):
			var a := placed[i].get_global_rect()
			var b := placed[j].get_global_rect()
			if _hidden_under_overlay(placed[i], a, placed[j], b):
				continue
			if a.grow(MIN_GAP - 0.5).intersects(b):
				problems.append("%s %s and %s %s are closer than %d px" % [placed[i].name, a, placed[j].name, b, MIN_GAP])

## True when one of the two is an open overlay panel that wholly covers the other.
func _hidden_under_overlay(a: Control, a_rect: Rect2, b: Control, b_rect: Rect2) -> bool:
	return (String(a.name) in OVERLAYS and a_rect.encloses(b_rect)) or (String(b.name) in OVERLAYS and b_rect.encloses(a_rect))
