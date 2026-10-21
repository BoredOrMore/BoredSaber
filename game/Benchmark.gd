extends Node3D
class_name Benchmark
## A hands-off GPU benchmark for the headset ("Measure the menu" in Settings > Advanced, or tools/bench.sh over adb,
## which drops FLAG_FILE that the song menu looks for every 2 s). It steps the game through fixed phases of
## PHASE_SECONDS, from the song menu with a synthetic pointer and keyboard to each graphics option off and on and
## then a song, printing "BENCH start <phase>" and "BENCH end <phase>" so tools/bench_report.py can match the
## headset's per-second PxrMetric timings to each phase. A label left of the menu shows the step and time left, with
## Cancel. Settings it changes are put back at the end or on cancel, and never saved. The headset has to be worn (or
## its proximity sensor covered): with the display off the runtime doesn't render the game.

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
## The progress label and Cancel: left of the song menu, facing the player, at eye height.
const PANEL_POSITION := Vector3(-1.1, 1.55, 0.0)
const PANEL_YAW := deg_to_rad(50.0)
const TEXT_SIZE := 56
const TEXT_PIXEL := 0.001

var game: BeepSaber_Game
## Called every frame of the running phase, with its elapsed seconds.
var _tick := Callable()
var _elapsed := 0.0
var _cancelled := false
var _saved := {}
var _foveation := -1
var _label := Label3D.new()
var _cancel := (preload("res://game/scripts/UIRaycast/UIRaycastButton.tscn") as PackedScene).instantiate() as UIRaycastButton
var _phase_index := 0
var _phase_count := 0

## Phases before the song (_phases(), with OpenXR's four foveation levels).
const PHASE_COUNT := 18

## How long a whole run takes, in seconds.
static func total_seconds() -> float:
	return SETTLE_SECONDS + PHASE_COUNT * PHASE_SECONDS + SONG_SECONDS

## True once if the flag file is there (and removes it).
static func requested() -> bool:
	var path := Constants.APPDATA_PATH + FLAG_FILE
	if not FileAccess.file_exists(path):
		return false
	DirAccess.remove_absolute(path)
	return true

## The phases in order: [name, per-frame tick, setup], teardown being the restore at the end of each.
func _phases() -> Array:
	var openxr := XRServer.find_interface("OpenXR") as OpenXRInterface
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
		["slash_note_light_on", Callable(), func() -> void: _face_slash_note(true)],
		["slash_note_light_off", Callable(), func() -> void: _face_slash_note(false)],
	]
	if openxr:
		for level in 4:
			phases.append(["foveation_%d" % level, Callable(), func() -> void: openxr.foveation_level = level])
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

## Runs every phase in order, then the song, then puts everything back.
func run() -> void:
	print("BENCH begin")
	for key: StringName in [&"glare", &"smoke", &"saber_tail", &"background", &"health_mode"]:
		_saved[key] = Settings.get(key)
	var openxr := XRServer.find_interface("OpenXR") as OpenXRInterface
	if openxr:
		_foveation = openxr.foveation_level
	var phases := _phases()
	assert(phases.size() == PHASE_COUNT or openxr == null)
	# the song phase plays the picked song, or the first listed
	if not game.menu.has_song_picked() and game.menu.songs_menu.item_count > 0:
		game.menu.songs_menu.select(0)
		game.menu._select_song(0, false)
	var song := game.menu.has_song_picked()
	_phase_count = phases.size() + (1 if song else 0)
	_show_status("Getting ready")
	await _wait(SETTLE_SECONDS)
	for phase: Array in phases:
		if _cancelled:
			break
		_phase_index += 1
		await _phase(phase[0], phase[1], phase[2])
	if song and not _cancelled:
		_phase_index += 1
		Settings.health_mode = false
		_show_status("song")
		print("BENCH start song")
		game.menu.play_selected()
		await _wait(SONG_SECONDS)
		print("BENCH end song")
		game._main_menu_button()
	_restore()
	print("BENCH cancelled" if _cancelled else "BENCH done")
	queue_free()

## One phase: setup, PHASE_SECONDS with tick called every frame, logged at both ends, then everything put back.
func _phase(phase_name: String, tick: Callable, setup: Callable) -> void:
	if setup.is_valid():
		setup.call()
	_show_status(phase_name)
	print("BENCH start ", phase_name)
	_elapsed = 0.0
	_tick = tick
	await _wait(PHASE_SECONDS)
	_tick = Callable()
	print("BENCH end ", phase_name)
	_restore()

## Waits, or less if cancelled.
func _wait(seconds: float) -> void:
	var waited := 0.0
	while waited < seconds and not _cancelled:
		await get_tree().process_frame
		waited += get_process_delta_time()

## "Measuring 4/19 · glow_on · 6:20 left".
func _show_status(phase_name: String) -> void:
	var left := (_phase_count - _phase_index + 1) * PHASE_SECONDS + (SONG_SECONDS - PHASE_SECONDS if game.menu.has_song_picked() else 0.0)
	_label.text = "Measuring %d/%d · %s · %d:%02d left" % [_phase_index, _phase_count, phase_name, int(left) / 60, int(left) % 60]

## Puts every setting the benchmark touches back.
func _restore() -> void:
	for key: StringName in _saved:
		if Settings.get(key) != _saved[key]:
			Settings.set(key, _saved[key])
	var openxr := XRServer.find_interface("OpenXR") as OpenXRInterface
	if openxr and _foveation >= 0:
		openxr.foveation_level = _foveation
	game.xr_origin.rotation.y = 0.0
	game.slash_block._light.visible = game.slash_block._note_mesh.visible
	if game.highscore_keyboard.visible:
		game.highscore_keyboard._on_cancel()

## Turns the player to the slash note (instead of the head: it is placed for where the head looks) with or without
## its light.
func _face_slash_note(light: bool) -> void:
	var turn := deg_to_rad(SlashBlock.YAW_DEGREES) * (-1.0 if Settings.left_handed else 1.0)
	game.xr_origin.rotation.y = -turn
	game.slash_block._light.visible = light

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
