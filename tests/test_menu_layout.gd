extends Node
# Headless checks that the song menu and "Who's playing?" lay out without overlaps, with worst-case content.
# Run: godot --headless --path . res://tests/test_menu_layout.tscn

## Smallest gap, in px, between two controls placed side by side with offsets (not by a container).
const MIN_GAP := 4.0
## Panels that open over others: whatever lies wholly under a visible one is hidden, not overlapped.
const OVERLAYS := ["MorePanel", "MoreModsPanel", "FiltersPanel", "EnvironmentPanel"]
## The song menu's three panel backgrounds: what lies wholly on one is on it, not overlapping it.
const BACKGROUNDS := ["LeftPanel", "CentrePanel", "RightPanel"]
## Rows the song list must show at once at its original 76 px row size (owner, 2026-10-28: the curved menu in the
## 32 degree comfort zone, about 5 rows).
const MIN_VISIBLE_ROWS := 5
const TEST_HIGHSCORES := "user://test_menu_highscores.json"
const LONG_NAME := "Wolfgang Amadeus Mozart and the Very Long Band Name"
## Seconds a test song preview may take to decode once its START_DELAY_SECONDS have passed, before it counts as not playing.
const PREVIEW_DECODE_SECONDS := 2.0

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
	check(Settings.default_values["msaa"] == Settings.PRESET_MSAA["Normal"] and Settings.PRESET_MSAA["Normal"] == "4x",
			"anti-aliasing is 4x by default (the Normal preset's)")
	check(Settings.migrated_msaa("Normal", true) == "4x" and Settings.migrated_msaa("Low", false) == "4x"
			and Settings.migrated_msaa(Settings.GRAPHICS_CUSTOM, true) == "Off" and Settings.migrated_msaa(Settings.GRAPHICS_CUSTOM, false) == "4x",
			"configs from the 4x-everywhere build get their preset's anti-aliasing")
	_port.size = Vector2i(1600, 1100)
	add_child(_port)
	var keyboard := (load("res://OQ_Toolkit/OQ_UI2D/OQ_UI2DKeyboard.tscn") as PackedScene).instantiate() as OQ_UI2DKeyboard
	keyboard.visible = false
	add_child(keyboard)
	var menu := (load("res://game/ui/BeepSaberMainMenu.tscn") as PackedScene).instantiate() as MainMenu
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

		# the selected song's preview (SongPreview) starts, and stop_preview fades it out and stops it
		var preview := menu.song_preview
		preview.transition_time = 0.05
		Settings.audio_music_preview = maxf(Settings.audio_music_preview, 1.0)
		menu.play_selected_preview(0.0, true)
		# it waits START_DELAY_SECONDS, then decodes the song on a worker thread
		var give_up := Time.get_ticks_msec() + int((SongPreview.START_DELAY_SECONDS + PREVIEW_DECODE_SECONDS) * 1000.0)
		while not preview.playing and Time.get_ticks_msec() < give_up:
			await get_tree().process_frame
		check(preview.playing and preview.stream != null, "the selected song's preview plays")
		await menu.stop_preview()
		check(not preview.playing, "stop_preview stops the preview")
		preview.transition_time = 1.0

		# a rebuilt list (a filter that follows the speed) keeps the selected song where it was in the view
		if menu.songs_menu.item_count > 12:
			menu.songs_menu.select(12)
			menu._select_song(12, false)
			await _settle()
			# scrolled by hand so the song sits near the top, not where a glide would put it
			menu.songs_menu.place_row(12, 100.0)
			var before: float = menu.songs_menu.row_offset(12)
			menu._refilter()
			await _settle()
			var after: float = menu.songs_menu.row_offset(menu.current_selected)
			check(absf(after - before) < 1.0, "a rebuilt song list doesn't move the selected song (%.0f -> %.0f px)" % [before, after])

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
	var saved_highscores := Highscores.HIGHSCORES_FILEPATH
	await _fill_ranks(menu)
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
	menu._show_more_modifiers(false)
	menu.show_environments(true)
	await _settle()
	_check_layout(menu, "environments")
	var env_cards := menu.get_node(^"EnvironmentPanel/Rows/Grid").get_children()
	var smallest := 1e9
	for card: Control in env_cards:
		smallest = minf(smallest, minf(card.size.x, card.size.y))
	check(env_cards.size() == Settings.ENVIRONMENTS.size() and smallest >= 45.0,
			"a picture card per environment, each %.0f px or more across (3 degrees is 45 px)" % smallest)
	menu.show_environments(false)
	menu._show_tab(MainMenu.Tab.MORE)
	await _settle()
	_check_layout(menu, "more tab")
	# the licenses open over the right panel with a Back button above their scrolling text, 3 degrees or more tall
	var licenses := menu.get_node(^"LicensePopup") as Window
	menu._on_licenses_pressed()
	await _settle()
	var back := menu.get_node(^"LicensePopup/Rows/Back_Button") as Button
	var back_shown := licenses.visible and back.is_visible_in_tree() and back.size.y >= 45.0
	back.pressed.emit()
	await _settle()
	check(back_shown and not licenses.visible, "the licenses show a Back button (%.0f px tall) that closes them" % back.size.y)
	Highscores.HIGHSCORES_FILEPATH = TEST_HIGHSCORES
	Highscores.clear_table()
	Highscores.HIGHSCORES_FILEPATH = saved_highscores
	Highscores.load_hs_table()
	var beatsaver := (load("res://game/ui/BeatSaverPanel/BeatSaverPanel.tscn") as PackedScene).instantiate() as BeatSaverPanel
	beatsaver.main_menu_ref = menu
	beatsaver.keyboard = keyboard
	_port.add_child(beatsaver)
	await _settle()
	_check_layout(beatsaver, "download page")
	await _check_download_page(beatsaver)
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
	var settings := (load("res://game/ui/settings_Panel.tscn") as PackedScene).instantiate() as SettingsPanel
	# no controllers here for its sliders' thumbstick scrolling
	settings.process_mode = Node.PROCESS_MODE_DISABLED
	_port.add_child(settings)
	await _settle()
	Settings.set_graphics_preset("Low")
	await _settle()
	check(Settings.msaa == "4x", "Graphics Low picks 4x anti-aliasing")
	check(settings._graphics_chips["Low"].button_pressed and not settings.glare_control.button_pressed,
			"Graphics Low lights its chip and turns Glow off")
	settings._resolution_chips["Full"].pressed.emit()
	check(Settings.render_scale() == 1.44 and not settings._resolution_chips["Full"].disabled, "Resolution Full on Low renders at 1.44x")
	Settings.resolution_cap = "Sharp"
	check(Settings.render_scale() == 1.2 and Settings.resolution == "Full", "a stutter cap lowers Full to Sharp and keeps Full picked")
	Settings.resolution_cap = ""
	Settings.glare = true
	await _settle()
	check(settings._graphics_chips[Settings.GRAPHICS_CUSTOM].button_pressed, "changing an effect by hand shows Custom")
	Settings.set_graphics_preset("Normal")
	Settings.msaa = "2x"
	await _settle()
	check(Settings.graphics_preset() == "Normal", "changing anti-aliasing by hand keeps the preset")
	Settings.set_graphics_preset("Low")
	Settings.glare = true
	await _settle()
	check(Settings.render_scale() == 1.44 and not settings._resolution_chips["Full"].disabled and Settings.resolution == "Full",
			"off Low the picked resolution still applies (unlocked on every preset)")
	(settings.get_node(^"Tabs") as TabContainer).current_tab = settings.get_node(^"Tabs/Visuals").get_index()
	await _settle()
	_check_layout(settings.get_node(^"Tabs/Visuals/VBox") as Control, "settings visuals, Custom")
	settings.queue_free()

	# a map flashing one light group 6 times in a second flashes it at most 3 times
	var lights := (load("res://game/event_driver.tscn") as PackedScene).instantiate() as EventDriver
	add_child(lights)
	var flashed := 0
	for i in 6:
		if lights._flash_allowed(EventInfo.TYPE_DIAGONAL_LASERS):
			flashed += 1
	check(flashed == EventDriver.MAX_FLASHES_PER_SECOND, "a light group flashes at most %d times a second (flashed %d of 6)" % [EventDriver.MAX_FLASHES_PER_SECOND, flashed])
	lights.queue_free()

	# LowResGlow's ray from two unprojected points lands on the eye's real ray with Godot's stereo matrices
	var eyes: Array[Transform3D] = [Transform3D(Basis(), Vector3(-0.032, 1.6, 0)), Transform3D(Basis(), Vector3(0.032, 1.6, 0))]
	var projections: Array[Projection] = [Projection.create_frustum(-0.06, 0.04, -0.05, 0.05, 0.05, 1000.0),
			Projection.create_frustum(-0.04, 0.06, -0.05, 0.05, 0.05, 1000.0)]
	var main := LowResGlow._multiview_camera(eyes, projections)
	var worst := 0.0
	for v in 2:
		var point := Vector3(0.3, 1.8, -0.6)
		var stereo := projections[v] * Projection((main.affine_inverse() * eyes[v]).affine_inverse())
		var clip := stereo * Projection(main.affine_inverse()) * Vector4(point.x, point.y, point.z, 1.0)
		var ndc := Vector2(clip.x, clip.y) / clip.w
		var ray := LowResGlow._unproject(stereo, ndc, -1.0) - LowResGlow._unproject(stereo, ndc, 1.0)
		ray *= -1.0 if ray.z > 0.0 else 1.0
		worst = maxf(worst, rad_to_deg((main.basis * ray).angle_to(point - eyes[v].origin)))
	check(main.origin.z > 0.0 and worst < 0.01, "the glow's ray follows each eye's own ray (worst %.3f deg, stereo camera %.3f m behind the eyes)" % [worst, main.origin.z])

	# the play area warning: a 2 m square guardian leaves 1 m from its middle to an edge
	var square := PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	check(is_equal_approx(WarningIcon._distance_to_edge(Vector2.ZERO, square), 1.0) and WarningIcon._distance_to_edge(Vector2(0.5, 0), square) < WarningIcon.REACH,
			"the play area check measures the way to the guardian's nearest edge")

	# the hover sound: once per button moved onto, not for a pointer shaking on the line between two, and not
	# faster than HOVER_MIN_GAP_MS when sweeping a list
	var audio: Variant = (load("res://game/ui/UI_AudioEngine/UI_AudioEngine.gd") as GDScript).new()
	var a := Button.new()
	var b := Button.new()
	var c := Button.new()
	var d := Button.new()
	var heard := [audio.hover_sounds(a, 1000), audio.hover_sounds(b, 1300), audio.hover_sounds(a, 1330),
			audio.hover_sounds(b, 1360), audio.hover_sounds(a, 1390), audio.hover_sounds(c, 1420), audio.hover_sounds(d, 1440),
			audio.hover_sounds(a, 1800)]
	check(heard == [true, true, false, false, false, true, false, true],
			"the hover sound plays per button, not while the pointer shakes between two or faster than 70 ms (%s)" % [heard])
	for node: Node in [audio, a, b, c, d]:
		node.free()

	# song loudness: a 997 Hz sine at 0.5 in both channels is -6.0 LUFS (BS.1770: full scale in one channel is -3.01);
	# decoding at a quarter rate reads about 0.3 LU low, as on the songs against ffmpeg
	var tone := AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	tone.stereo = true
	tone.mix_rate = 44100
	var pcm := PackedByteArray()
	pcm.resize(44100 * 10 * 4)
	for i in 44100 * 10:
		var sample := int(0.5 * 32767.0 * sin(TAU * 997.0 * i / 44100.0))
		pcm.encode_s16(i * 4, sample)
		pcm.encode_s16(i * 4 + 2, sample)
	tone.data = pcm
	var lufs := Loudness.measure(tone)
	check(absf(lufs + 6.0) < 0.5 and is_equal_approx(Loudness.gain_db(lufs), Loudness.TARGET_LUFS - lufs)
			and Loudness.gain_db(-40.0) == Loudness.MAX_BOOST_DB,
			"song loudness measures a -6 LUFS tone as %.2f, and quiet songs are raised at most %d dB" % [lufs, Loudness.MAX_BOOST_DB])
	var limiter: Variant = AudioServer.get_bus_effect(0, 0) if AudioServer.get_bus_effect_count(0) > 0 else null
	check(limiter is AudioEffectHardLimiter and is_equal_approx(limiter.ceiling_db, -1.0),
			"the Master bus ends in a limiter at -1 dB, so music and effects together don't clip")

	# a curved panel (OQ_UI2DCanvas.curve_radius): a pixel's point on the cylinder maps back to that pixel (centre,
	# edges and corners), its width kept as arc, its height straight
	var curved := (load("res://OQ_Toolkit/OQ_UI2D/OQ_UI2DCanvas.tscn") as PackedScene).instantiate() as OQ_UI2DCanvas
	curved.curve_radius = 2.0
	curved.scale = Vector3(2.4, 2.4, 1.0)
	var page := Control.new()
	page.size = Vector2(1000, 500)
	curved.add_child(page)
	add_child(curved)
	await get_tree().process_frame
	var arc_worst := 0.0
	var on_cylinder := 0.0
	for u: float in [0.0, 0.02, 0.5, 0.98, 1.0]:
		for v: float in [0.0, 0.03, 0.5, 0.97, 1.0]:
			var want := Vector2(u * 1000.0, v * 500.0)
			var point := curved.curve_point(want)
			on_cylinder = maxf(on_cylinder, absf(Vector2(point.x, point.z - 2.0).length() - 2.0))
			# through the world and back, as a pointer hit is
			var hit := curved.ui_area.to_local(curved.ui_area.to_global(point))
			arc_worst = maxf(arc_worst, curved.curve_pixel(hit).distance_to(want))
	var span := curved.curve_size() / curved.curve_radius
	check(arc_worst < 0.01 and on_cylinder < 1e-5 and is_equal_approx(span.x, 1000.0 * 2.4 / 1024.0 / 2.0),
			"a curved panel maps its points back to its pixels, corners included (worst %.3f px), width kept as arc" % arc_worst)
	curved.queue_free()

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
	StatPills.fill(menu.level_stats, [StatPills.length(824.0, 24)] + StatPills.difficulty(1.0, 12.3, 24.0, 24)
			+ [StatPills.workout(12, 24)])
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
	# a press whose release something else took (an option list's popup): moving after it doesn't scroll
	var scrolled := list.scroll_vertical
	_pointer(at, true)
	_pointer_held = false
	_pointer(at + Vector2(0, -60), null)
	_pointer(at + Vector2(0, -120), null)
	await _settle()
	check(list.scroll_vertical == scrolled, "after a release the list didn't see, the pointer moves without scrolling it (moved %d px)" % (list.scroll_vertical - scrolled))

## How long a flick keeps going (the song list's vr_slider).
## The download page with worst-case content: every filter on and a long search as chips, a map with long names and
## all five levels picked (short details, then Details), downloading, and the filters open.
func _check_download_page(page: BeatSaverPanel) -> void:
	page._style_tag = "accuracy"
	page._genre_tag = "video-game-soundtrack"
	Settings.beatsaver_filter_reaction = Constants.DIFFICULTY_LEVELS.size()
	Settings.beatsaver_filter_length = 2
	page._set_search("the longest search anyone typed")
	page._sync_filter_controls()
	page.prev_request = BeatSaverPanel.BeatSaverRequest.new()
	page.prev_request.type = "text_search"
	page.prev_request.data = page.search_word
	var diffs := []
	for i in 5:
		diffs.append({"characteristic": "Standard", "njs": 10.0 + i * 3.0, "nps": 1.0 + i * 2.0, "notes": 400 + i * 300,
			"offset": 0.0, "obstacles": 1234, "paritySummary": {"errors": 2, "warns": 5, "resets": 1}})
	var map := {"name": LONG_NAME, "description": "%s\n%s\n%s\n%s" % [LONG_NAME, LONG_NAME, LONG_NAME, LONG_NAME],
		"curatedAt": "2026-10-01", "stats": {"score": 0.87}, "tags": ["accuracy", "video-game-soundtrack", "challenge"],
		"uploader": {"id": 5}, "metadata": {"songName": LONG_NAME, "songAuthorName": LONG_NAME,
		"levelAuthorName": "Nixie.Korten and Friends", "duration": 296.0, "bpm": 128.0},
		"versions": [{"hash": "abc", "coverURL": "", "previewURL": "", "downloadURL": "", "diffs": diffs}]}
	page._on_HTTPRequest_request_completed(0, 200, PackedStringArray(), JSON.stringify({"docs": [map, map, map]}).to_utf8_buffer())
	page._on_ItemList_item_selected(0)
	await _settle()
	check(page.item_list.item_count == 3, "the download page lists the maps it was sent (%d)" % page.item_list.item_count)
	# the pointer coming onto a row (not the gap between rows) lets the thumbstick scroll the list
	var row_point := page.item_list.get_global_rect().position + Vector2(200.0, BeatSaverList.ROW_HEIGHT / 2.0)
	_pointer(row_point - Vector2(0.0, 300.0), null)
	_pointer(row_point, null)
	await get_tree().process_frame
	check(page.get_node(^"list_slider").is_mouse_in, "download page: pointing at a song row lets the thumbstick scroll the list")
	var second_row := row_point + Vector2(0.0, BeatSaverList.ROW_HEIGHT + BeatSaverList.ROW_SEPARATION)
	_pointer(second_row, null)
	_pointer(second_row, true)
	_pointer(second_row, false)
	await _settle()
	check(page.item_selected == 1, "download page: pressing a song row picks that song (%d)" % page.item_selected)
	_pointer(row_point - Vector2(0.0, 300.0), null)
	check(page.chip_row.get_combined_minimum_size().x <= page.chip_row.size.x,
			"download page: the search and filter chips fit above the list (%.0f of %.0f px)" % [
			page.chip_row.get_combined_minimum_size().x, page.chip_row.size.x])
	_check_layout(page, "download page, map picked")
	page._details_toggle.button_pressed = true
	await _settle()
	_check_layout(page, "download page, Details")
	page._details_toggle.button_pressed = false
	page.downloading.append(["map", {"hash": "abc"}, []])
	page._update_download_button()
	page.label.text = "Couldn't download %s. Check your Wi-Fi and try again." % LONG_NAME
	await _settle()
	_check_layout(page, "download page, downloading")
	page.downloading.clear()
	page._set_filters_open(true)
	await _settle()
	_check_layout(page, "download page, filters open")
	Settings.beatsaver_filter_reaction = 0
	Settings.beatsaver_filter_length = 0
	# no level filter and a page too short to scroll (owner, 2026-10-29: the first page showed no scroll bar and never grew)
	page.prev_request.page = 0
	page._on_HTTPRequest_request_completed(0, 200, PackedStringArray(), JSON.stringify({"docs": [map, map, map]}).to_utf8_buffer())
	check(page._scroll_page_request_pending and page.prev_request.page == 1,
			"download page: a first page too short to scroll fetches the next one on its own (page %d)" % page.prev_request.page)
	page.httpreq.cancel_request()
	page._scroll_page_request_pending = false
	# a page of PAGE_SIZE songs; the next is fetched once FETCH_ROWS_LEFT songs or fewer are below the view
	check(page._search_url(0, "", "Latest").contains("pageSize=%d" % BeatSaverPanel.PAGE_SIZE),
			"download page: a list asks BeatSaver for %d songs a page" % BeatSaverPanel.PAGE_SIZE)
	var full_page := []
	for i in BeatSaverPanel.PAGE_SIZE:
		full_page.append(map)
	page.prev_request.page = 0
	page.update_list(page.prev_request)
	page.httpreq.cancel_request()
	page._on_HTTPRequest_request_completed(0, 200, PackedStringArray(), JSON.stringify({"docs": full_page}).to_utf8_buffer())
	await _settle()
	var row_step := BeatSaverList.ROW_HEIGHT + BeatSaverList.ROW_SEPARATION
	var rows_in_view := ceili(page.item_list.size.y / row_step)
	page.v_scroll.value = (BeatSaverPanel.PAGE_SIZE - BeatSaverPanel.FETCH_ROWS_LEFT - rows_in_view - 1) * row_step
	var early := page.prev_request.page
	page.v_scroll.value += row_step
	check(early == 0 and page.prev_request.page == 1 and page._scroll_page_request_pending,
			"download page: the next page loads once %d songs are left below the view (page %d, then %d)" % [
			BeatSaverPanel.FETCH_ROWS_LEFT, early, page.prev_request.page])
	page.httpreq.cancel_request()
	page._scroll_page_request_pending = false

func vr_slider_momentum() -> float:
	return preload("res://game/ui/vr_slider.gd").MOMENTUM_SECONDS

## Sends a pointer press (true), release (false) or move (null) to the menu's viewport, as the VR pointer does.
var _pointer_held := false

func _pointer(at: Vector2, pressed: Variant) -> void:
	var event: InputEventMouse
	if pressed == null:
		event = InputEventMouseMotion.new()
		# as the VR pointer sends it: the button held while pressed
		(event as InputEventMouseMotion).button_mask = MOUSE_BUTTON_MASK_LEFT if _pointer_held else 0
	else:
		_pointer_held = pressed
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
	if root is MainMenu:
		_check_no_scroll(root, state)

## Nothing on the song page but the song list scrolls (owner, 2026-10-28): every other shown scroll container's
## content fits it.
func _check_no_scroll(menu: MainMenu, state: String) -> void:
	var scrolling := PackedStringArray()
	for scroll: ScrollContainer in menu.find_children("*", "ScrollContainer", true, false):
		if scroll == menu.songs_menu or not scroll.is_visible_in_tree():
			continue
		for content: Control in scroll.get_children().filter(func(c: Node) -> bool: return c is Control and not c is ScrollBar):
			if content.get_combined_minimum_size().y > scroll.size.y + 0.5 or content.get_combined_minimum_size().x > scroll.size.x + 0.5:
				scrolling.append("%s (content %s in %s)" % [menu.get_path_to(scroll), content.get_combined_minimum_size(), scroll.size])
	check(scrolling.is_empty(), "%s: only the song list scrolls%s" % [state, "" if scrolling.is_empty() else ": " + ", ".join(scrolling)])

## Ten records on the selected difficulty, the current player's best ninth (in a table of the test's own): the ranks
## under the song show the best ones and, last, the player's best with its place.
func _fill_ranks(menu: MainMenu) -> void:
	Highscores.HIGHSCORES_FILEPATH = TEST_HIGHSCORES
	Highscores.clear_table()
	var info := MapInfo.new("2.0.0", "Ranks", "", "Artist", "Mapper", 120.0, 0.0, 10.0, "song.ogg", "cover.jpg", "",
		0.0, {}, "user://no_such_song/", [] as Array[DifficultyInfo])
	for i in 10:
		Highscores.add_highscore(info, 1, Settings.player_name if i == 8 else "Rival %d" % i, 900000 - i * 1000, 0.95)
	var ranks := menu.get_node(^"Ranks") as HighscorePanel
	ranks.show()
	ranks.load_highscores(info, 1)
	await _settle()
	var rows := ranks._highscore_list.get_children().filter(func(row: Node) -> bool: return not row.is_queued_for_deletion())
	check(rows.size() == HighscorePanel.COMPACT_ROWS and ((rows[-1] as Node).get_child(1) as Label).text == "#9 " + Settings.player_name
			and ranks._title.text == "10 scores",
			"ten ranks under the song: %d rows, the last \"%s\", titled \"%s\"" % [rows.size(),
			((rows[-1] as Node).get_child(1) as Label).text if rows.size() > 0 else "", ranks._title.text])

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
		# a scroll container's content is meant to run past it; a picture card's layers sit on each other
		if not child is ScrollContainer and not child is EnvironmentCard:
			_check_children(child, rect, problems)
	for i in placed.size():
		for j in range(i + 1, placed.size()):
			var a := placed[i].get_global_rect()
			var b := placed[j].get_global_rect()
			if _hidden_under_overlay(placed[i], a, placed[j], b):
				continue
			if a.grow(MIN_GAP - 0.5).intersects(b):
				problems.append("%s %s and %s %s are closer than %d px" % [placed[i].name, a, placed[j].name, b, MIN_GAP])

## True when one of the two is an open overlay panel or a panel background that wholly covers the other.
func _hidden_under_overlay(a: Control, a_rect: Rect2, b: Control, b_rect: Rect2) -> bool:
	var covers := OVERLAYS + BACKGROUNDS
	return (String(a.name) in covers and a_rect.encloses(b_rect)) or (String(b.name) in covers and b_rect.encloses(a_rect))
