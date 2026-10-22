extends Node3D
class_name Benchmark
## A hands-off GPU benchmark for the headset ("Measure the menu" in Settings > Advanced, or tools/bench.sh over adb,
## which drops FLAG_FILE that the song menu looks for every 2 s). It steps the game through fixed phases of
## PHASE_SECONDS, from the song menu with a synthetic pointer and keyboard to each graphics option off and on and
## then a song, printing "BENCH start <phase>" and "BENCH end <phase>" so tools/bench_report.py can match the
## headset's per-second PxrMetric timings to each phase. A label left of the menu shows the step and time left, with
## Cancel. Settings it changes are put back at the end or on cancel, and never saved. The headset has to be worn (or
## its proximity sensor covered): with the display off the runtime doesn't render the game.
## The flag file may name a mode: RESOLUTION runs only the render scale phases (tools/bench.sh --only resolution).

## The flag file in Constants.APPDATA_PATH; it is removed when a run starts.
const FLAG_FILE := "benchmark"
const PHASE_SECONDS := 20.0
## Time to let the menu settle (songs listed, covers loaded) before the first phase.
const SETTLE_SECONDS := 6.0
const SONG_SECONDS := 60.0
## The synthetic pointer: one sweep over the menu every SWEEP_SECONDS, within this part of the menu canvas
## (x, y from -0.5 to 0.5, y up).
const SWEEP_SECONDS := 3.0
const SWEEP_AREA := Rect2(-0.48, -0.45, 0.95, 0.85)
## What is typed into Search, one key every KEY_SECONDS.
const TYPED := "ayobu"
const KEY_SECONDS := 2.5
## Render scales (OpenXR render target size multiplier) the resolution phases try, each with Normal and Low graphics,
## and the song's seconds at the last scale with Low.
const RESOLUTION := "resolution"
## The flag file's mode for the anti-aliasing phases (tools/bench.sh --only msaa): MSAA off, 2x and 4x in a song
## (where glow shows) on Normal and on Low at 1x, then 4x on Low at Sharp (1.2x).
const MSAA := "msaa"
const MSAA_SONG_SECONDS := 20.0
const RENDER_SCALES: Array[float] = [1.0, 1.2, 1.44]
const RESOLUTION_SONG_SECONDS := 20.0
## The progress label and Cancel: left of the song menu, facing the player, at eye height.
const PANEL_POSITION := Vector3(-1.1, 1.55, 0.0)
const PANEL_YAW := deg_to_rad(50.0)
const TEXT_SIZE := 56
const TEXT_PIXEL := 0.001
## How long to wait for the player to turn to the slash note.
const FACE_TIMEOUT_SECONDS := 15.0

var game: BeepSaber_Game
## Called every frame of the running phase, with its elapsed seconds.
var _tick := Callable()
var _elapsed := 0.0
var _cancelled := false
var _saved := {}
var _foveation := -1
var _render_scale := 1.0
var _label := Label3D.new()
var _cancel := (preload("res://game/scripts/UIRaycast/UIRaycastButton.tscn") as PackedScene).instantiate() as UIRaycastButton
var _phase_index := 0
var _phase_count := 0
var _seconds_left := 0.0
## Set by a phase's setup to leave the phase out (its precondition didn't happen).
var _skip_phase := false

## Phases of a full run before the song (_phases(), with OpenXR's four foveation levels).
const PHASE_COUNT := 18

## How long a full run takes, in seconds.
static func total_seconds() -> float:
	return SETTLE_SECONDS + PHASE_COUNT * PHASE_SECONDS + SONG_SECONDS

## A flag file older than this was left by a tools/bench.sh run the game didn't see (closed, or in a song): ignored,
## so a run never starts by itself days later.
const FLAG_MAX_AGE_SECONDS := 120

## The mode in the flag file ("" for a full run) once if it is there and fresh (it is removed either way), null if not.
static func requested() -> Variant:
	var path := Constants.APPDATA_PATH + FLAG_FILE
	if not FileAccess.file_exists(path):
		return null
	var age := Time.get_unix_time_from_system() - FileAccess.get_modified_time(path)
	var mode := FileAccess.get_file_as_string(path).strip_edges()
	DirAccess.remove_absolute(path)
	if age > FLAG_MAX_AGE_SECONDS:
		print("BENCH ignored a flag file %d s old" % age)
		return null
	return mode

## The player's settings while a run is on (it saves some of its own on the way, as starting the song saves the
## settings): if the game closes mid-run, the next launch puts them back (restore_interrupted).
const BACKUP_FILE := "benchmark_settings.json"
const SAVED_KEYS: Array[StringName] = [&"glare", &"smoke", &"saber_tail", &"cube_cuts_falloff", &"background", &"health_mode"]

## Puts back and saves the settings of a run the game closed in the middle of; call at launch.
static func restore_interrupted() -> void:
	var path := Constants.APPDATA_PATH + BACKUP_FILE
	if not FileAccess.file_exists(path):
		return
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if saved is Dictionary:
		for key: String in saved:
			if StringName(key) in SAVED_KEYS:
				Settings.set(key, saved[key])
		Settings.save()
		print("BENCH restored settings of an interrupted run")
	DirAccess.remove_absolute(path)

## The phases in order: [name, per-frame tick, setup, seconds, plays the song], each followed by the restore.
func _phases(mode: String) -> Array:
	var openxr := XRServer.find_interface("OpenXR") as OpenXRInterface
	if mode == MSAA:
		var phases := []
		for preset: String in ["Normal", "Low"]:
			for level: Array in Settings.MSAA_LEVELS:
				phases.append(["msaa_%s_%s_song" % [level[0].to_lower(), preset.to_lower()], Callable(),
						_set_view.bind(preset, level[1], 1.0), MSAA_SONG_SECONDS, true])
		phases.append(["msaa_4x_low_sharp_song", Callable(), _set_view.bind("Low", Viewport.MSAA_4X, 1.2), MSAA_SONG_SECONDS, true])
		return phases
	if mode == RESOLUTION:
		var phases := []
		if openxr:
			for scale in RENDER_SCALES:
				for preset: String in ["Normal", "Low"]:
					phases.append(["scale_%.2f_%s" % [scale, preset.to_lower()], Callable(), func() -> void:
						openxr.render_target_size_multiplier = scale
						Settings.set_graphics_preset(preset)])
			var song_setup := func() -> void:
				openxr.render_target_size_multiplier = RENDER_SCALES[-1]
				Settings.set_graphics_preset("Low")
			phases.append(["scale_%.2f_low_song" % RENDER_SCALES[-1], Callable(), song_setup, RESOLUTION_SONG_SECONDS, true])
		return phases
	var phases := [
		["menu_idle", Callable(), Callable()],
		["pointer_sweep", _sweep_pointer, Callable()],
		["search_typing", _type_search, Callable()],
		["glow_off", Callable(), func() -> void: Settings.glare = false],
		["glow_on", Callable(), func() -> void: Settings.glare = true],
		["smoke_on", Callable(), func() -> void: Settings.smoke = true],
		["smoke_off", Callable(), func() -> void: Settings.smoke = false],
		["saber_trail_on", Callable(), func() -> void: Settings.saber_tail = true],
		["saber_trail_off", Callable(), func() -> void: Settings.saber_tail = false],
		["stage_light_show", Callable(), func() -> void: Settings.background = "dynamic"],
		["stage_lights_off", Callable(), func() -> void: Settings.background = "static"],
		["stage_lights_off_no_stage", Callable(), func() -> void: Settings.background = "simple"],
		["slash_note_light_on", Callable(), _face_slash_note.bind(true)],
		["slash_note_light_off", Callable(), _face_slash_note.bind(false)],
	]
	if openxr:
		for level in 4:
			phases.append(["foveation_%d" % level, Callable(), func() -> void: openxr.foveation_level = level])
	phases.append(["song", Callable(), Callable(), SONG_SECONDS, true])
	return phases

func _ready() -> void:
	_label.font_size = TEXT_SIZE
	_label.pixel_size = TEXT_PIXEL
	_label.outline_size = 12
	_label.modulate = Constants.UI_TEXT
	_label.outline_modulate = Constants.UI_PANEL
	add_child(_label)
	_cancel.text = "Cancel"
	_cancel.position = Vector3(0.0, -0.12, 0.0)
	_cancel.released.connect(func() -> void: _cancelled = true)
	add_child(_cancel)
	position = PANEL_POSITION
	rotation.y = PANEL_YAW

func _process(delta: float) -> void:
	_elapsed += delta
	if _tick.is_valid():
		_tick.call(_elapsed)

## Runs every phase of the mode ("" for all) in order, then puts everything back.
func run(mode := "") -> void:
	print("BENCH begin ", mode)
	for key in SAVED_KEYS:
		_saved[key] = Settings.get(key)
	var backup := FileAccess.open(Constants.APPDATA_PATH + BACKUP_FILE, FileAccess.WRITE)
	if backup:
		backup.store_string(JSON.stringify(_saved))
		backup.close()
	var openxr := XRServer.find_interface("OpenXR") as OpenXRInterface
	if openxr:
		_foveation = openxr.foveation_level
		_render_scale = openxr.render_target_size_multiplier
	# a song phase plays the picked song, or the first listed
	if not game.menu.has_song_picked() and game.menu.songs_menu.item_count > 0:
		game.menu.songs_menu.select(0)
		game.menu._select_song(0, false)
	var phases := _phases(mode).filter(func(phase: Array) -> bool:
		return phase.size() < 5 or game.menu.has_song_picked())
	_phase_count = phases.size()
	_seconds_left = SETTLE_SECONDS
	for phase: Array in phases:
		_seconds_left += phase[3] if phase.size() > 3 else PHASE_SECONDS
	_show_status("Getting ready")
	await _wait(SETTLE_SECONDS)
	_seconds_left -= SETTLE_SECONDS
	for phase: Array in phases:
		if _cancelled:
			break
		_phase_index += 1
		await _phase(phase[0], phase[1], phase[2], phase[3] if phase.size() > 3 else PHASE_SECONDS, phase.size() > 4)
	_restore()
	game.get_viewport().msaa_3d = Settings.msaa_mode()
	Settings.save()
	DirAccess.remove_absolute(Constants.APPDATA_PATH + BACKUP_FILE)
	# the render scale only at the end: each change makes the runtime remake its eye buffers
	if openxr:
		openxr.render_target_size_multiplier = _render_scale
	print("BENCH cancelled" if _cancelled else "BENCH done")
	queue_free()

## One phase: setup, then seconds with tick called every frame (and the song playing, without failing), logged at
## both ends with the eye buffer size, then everything put back.
func _phase(phase_name: String, tick: Callable, setup: Callable, seconds: float, song: bool) -> void:
	if setup.is_valid():
		await setup.call()
	if _skip_phase:
		_skip_phase = false
		print("BENCH skip ", phase_name)
		_seconds_left -= seconds
		_restore()
		return
	_show_status(phase_name)
	if song:
		Settings.health_mode = false
		game.menu.play_selected()
	print("BENCH start ", phase_name, " eye ", XRServer.primary_interface.get_render_target_size() if XRServer.primary_interface else Vector2.ZERO)
	_elapsed = 0.0
	_tick = tick
	await _wait(seconds)
	_tick = Callable()
	print("BENCH end ", phase_name)
	_seconds_left -= seconds
	if song:
		game._main_menu_button()
	_restore()

## Sets the graphics preset, anti-aliasing and render scale for a phase (all put back at the end of the run).
func _set_view(preset: String, msaa: Viewport.MSAA, scale: float) -> void:
	Settings.set_graphics_preset(preset)
	game.get_viewport().msaa_3d = msaa
	var openxr := XRServer.find_interface("OpenXR") as OpenXRInterface
	if openxr:
		openxr.render_target_size_multiplier = scale

## Waits, or less if cancelled.
func _wait(seconds: float) -> void:
	var waited := 0.0
	while waited < seconds and not _cancelled:
		await get_tree().process_frame
		waited += get_process_delta_time()

## "Measuring 4/19 · glow_on · 6:20 left".
func _show_status(phase_name: String) -> void:
	var left := int(_seconds_left)
	_label.text = "Measuring %d/%d · %s · %d:%02d left" % [_phase_index, _phase_count, phase_name, left / 60, left % 60]

## Puts every setting the benchmark touches back.
func _restore() -> void:
	for key: StringName in _saved:
		if Settings.get(key) != _saved[key]:
			Settings.set(key, _saved[key])
	var openxr := XRServer.find_interface("OpenXR") as OpenXRInterface
	if openxr and _foveation >= 0:
		openxr.foveation_level = _foveation

	game.slash_block._light.visible = game.slash_block._note_mesh.visible
	if game.highscore_keyboard.visible:
		game.highscore_keyboard._on_cancel()

## Asks the player to turn to the slash note (the view is never turned for them: that made players sick) and waits
## until it is in view, with or without its light; the phase is skipped if the note isn't up or not looked at within
## FACE_TIMEOUT_SECONDS.
func _face_slash_note(light: bool) -> void:
	var slash := game.slash_block
	if not slash._shown:
		_skip_phase = true
		return
	slash._light.visible = light
	var waited := 0.0
	while not slash._in_view and waited < FACE_TIMEOUT_SECONDS and not _cancelled:
		_label.text = "Turn %s to the note to measure it" % ("left" if Settings.left_handed else "right")
		await get_tree().process_frame
		waited += get_process_delta_time()
	_skip_phase = not slash._in_view

## Moves a pointer over the menu canvas through the same path the laser takes (its UIArea).
func _sweep_pointer(elapsed: float) -> void:
	var area := game.main_menu.get_node(^"UIArea") as UIRaycastTarget
	var t := fmod(elapsed / SWEEP_SECONDS, 1.0)
	var row := fmod(floorf(elapsed / SWEEP_SECONDS) * 0.37, 1.0)
	var local := Vector3(SWEEP_AREA.position.x + SWEEP_AREA.size.x * t, SWEEP_AREA.position.y + SWEEP_AREA.size.y * row, 0.0)
	area.ui_raycast_hit_event(area.to_global(local), false, false)

## Opens Search and types TYPED one key at a time.
func _type_search(elapsed: float) -> void:
	var keyboard := game.highscore_keyboard
	if not keyboard.visible:
		game.menu._on_Search_Button_button_up()
	var keys := mini(int(elapsed / KEY_SECONDS), TYPED.length())
	if keyboard._text_edit.text.length() < keys:
		keyboard._text_edit.insert_text_at_caret(TYPED[keyboard._text_edit.text.length()])
