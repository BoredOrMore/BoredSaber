extends Node
# Headless checks that the song menu and "Who's playing?" lay out without overlaps, with worst-case content.
# Run: godot --headless --path . res://tests/test_menu_layout.tscn

## Smallest gap, in px, between two controls placed side by side with offsets (not by a container).
const MIN_GAP := 4.0
## Panels that open over others: whatever lies wholly under a visible one is hidden, not overlapped.
const OVERLAYS := ["MorePanel", "MoreModsPanel"]
const LONG_NAME := "Wolfgang Amadeus Mozart and the Very Long Band Name"

var failures := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

func _ready() -> void:
	var keyboard := (load("res://OQ_Toolkit/OQ_UI2D/OQ_UI2DKeyboard.tscn") as PackedScene).instantiate() as OQ_UI2DKeyboard
	keyboard.visible = false
	add_child(keyboard)
	var menu := (load("res://game/BeepSaberMainMenu.tscn") as PackedScene).instantiate() as MainMenu
	menu.keyboard = keyboard
	var player := AudioStreamPlayer.new()
	add_child(player)
	menu.main_song_player_ref = player
	add_child(menu)
	menu.set_physics_process(false)
	(menu.get_node("song_vr_slider") as Node).process_mode = Node.PROCESS_MODE_DISABLED
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

	menu._show_more_modifiers(true)
	await _settle()
	_check_layout(menu, "more modifiers")
	menu._show_tab(MainMenu.Tab.MORE)
	await _settle()
	_check_layout(menu, "more tab")
	menu.queue_free()

	var profiles := (load("res://game/ui/ProfilesPanel.tscn") as PackedScene).instantiate() as ProfilesPanel
	profiles.keyboard = keyboard
	Settings.players = []
	for i in Settings.MAX_PLAYERS:
		Settings.players.append({"name": "%d %s" % [i, LONG_NAME], "player_height_offset": 0.0, "left_handed": false})
	Settings.player_name = Settings.players[0].name
	add_child(profiles)
	profiles._ask_delete(Settings.players[1].name)
	await _settle()
	_check_layout(profiles, "who's playing, six players, one asking to delete")

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
