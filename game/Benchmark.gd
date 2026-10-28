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
## The flag file's mode for the glow phases (tools/bench.sh --only glowb), each in a song on Normal at 1x, with no
## glow between each pair: LowResGlow's parts at 752 px (the glow image with and without its MSAA, + the full or short
## blur chain), the full glow, the cheapest combination at 752 and 564, and the older 376 px single tap.
const GLOWB := "glowb"
## The flag file's mode for the whole look's cost (tools/bench.sh --only total): each setup in a song with the
## player's own settings switches, a no-glow phase (Normal, 4x, Atmosphere Normal, 1x) between each pair.
const TOTAL := "total"
## The flag file's mode for the refresh rate (tools/bench.sh --only hz90): the menu and a song at 72 and at 90 Hz, on
## the player's own settings, plus a song at 90 Hz on Low; 72 Hz again last, as the headset warms up through a run.
const HZ90 := "hz90"
## The flag file's mode for the stages' cost (tools/bench.sh --only fog): in a song on Night City (the canyon), all on,
## then the glow lighter (LIGHT_GLOW), then the scenery (EnvSolid: towers, roofs, deck edges) drawn one flat colour,
## then left out, then all on again; then the same on Metal Factory. Flat against all on is the scenery shader's cost,
## flat against none the area it covers. Each fog part on its own cost under half a millisecond (bench, 2026-10-25),
## so those phases are gone. Each phase sets its state every frame, as the song's start hangs the stage again.
const FOG := "fog"
const FOG_SONG_SECONDS := 20.0
## The flag file's mode for the floor reflection and the build-up sweep (tools/bench.sh --only reflection), in a
## song on Classic: all on, the reflection left out, each twice, then the sweep held on and all on again.
const REFLECTION := "reflection"
## The flag file's mode for the cuts' dust (tools/bench.sh --only cut_dust): in a song on Classic, full-swing cuts
## fired by the benchmark CUT_DUST_CUTS_PER_SECOND at the hit plane, left and right in turn (nobody swings during a
## run), with the dust left out and on, twice each.
const CUT_DUST := "cut_dust"
const CUT_DUST_CUTS_PER_SECOND := 4.0
const CUT_DUST_SWING := Vector3(0.0, -6.0, 0.0)
var _cuts_fired := 0
const HZ_SONG_SECONDS := 20.0
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
var _refresh_rate := 0.0
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
const SAVED_KEYS: Array[StringName] = [&"glare", &"smoke", &"saber_tail", &"cube_cuts_falloff", &"background", &"health_mode",
		&"msaa", &"glow_quality", &"atmosphere", &"environment", &"classic_night_city"]

## The fog mode's stage: Night City's canyon (environment is put back with the rest of the saved settings).
func _night_city() -> void:
	Settings.environment = "night_city"
	Settings.classic_night_city = false

## The glow image's height before the run, and the lighter glow's share of it.
var _glow_height := LowResGlow.height
const LIGHT_GLOW := 0.75

func _metal_factory() -> void:
	Settings.environment = "metal_factory"

## Glow, scenery and its shading on, but the one named ("" none off), on any stage.
func _stage_parts(off: String) -> void:
	var glare := off != "glow"
	if Settings.glare != glare:
		Settings.glare = glare
	# a lighter glow: its image LIGHT_GLOW of its height (fewer pixels to draw and blur, a softer glow)
	LowResGlow.height = roundi(_glow_height * LIGHT_GLOW) if off == "light_glow" else _glow_height
	var views := {"scenery": DebugView.RINGS, "shading": DebugView.FLAT_SCENERY}
	RenderingServer.global_shader_parameter_set(&"debug_view", views.get(off, 0))

## Fires full-swing cuts at the hit plane CUT_DUST_CUTS_PER_SECOND, left and right in turn, `t` seconds into the
## phase, with the benchmark DebugView bits set to `bits`.
func _fire_cuts(t: float, bits: int) -> void:
	_set_debug_bits(bits)
	var due := int(t * CUT_DUST_CUTS_PER_SECOND)
	while _cuts_fired < due:
		_cuts_fired += 1
		var side := -1.0 if _cuts_fired % 2 == 0 else 1.0
		var at := Vector3(side * Settings.LANE_DISTANCE_X * 0.5, Constants.layer_y(1.0), Constants.HIT_PLANE_Z)
		game.cut_flash.flash(at, CUT_DUST_SWING, Map.color_left if side < 0.0 else Map.color_right)

## Sets the benchmark-only DebugView bits to `bits` (the reflection mode), leaving the rest of the flags alone.
func _set_debug_bits(bits: int) -> void:
	var mask := DebugView.NO_REFLECTION | DebugView.FORCE_SWEEP | DebugView.NO_CUT_DUST
	if DebugView.flags & mask != bits:
		DebugView.flags = (DebugView.flags & ~mask) | bits

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
	if mode == GLOWB:
		var G := BeepSaber_Game.Glow
		# A no-glow phase between each pair (the headset warms up through a run, so each is compared with the no-glow
		# phases next to it): [name, glow, glow image MSAA, short blur chain, glow image height, upsample]
		var tested := [
			["new_752_view_msaa", G.NEW_VIEWPORTS_ONLY, true, false, 752, "pass"],
			["new_752_view_no_msaa", G.NEW_VIEWPORTS_ONLY, false, false, 752, "pass"],
			["new_752_blur_full_chain", G.NEW_WITH_BLUR, true, false, 752, "pass"],
			["new_752_blur_short_chain", G.NEW_WITH_BLUR, true, true, 752, "pass"],
			["new_752_full", G.NEW, true, false, 752, "pass"],
			["new_752_cheapest", G.NEW, false, true, 752, "pass"],
			["new_564_cheapest", G.NEW, false, true, 564, "pass"],
			["new_376_old_single_tap", G.NEW, true, false, 376, "none"],
		]
		var glow_phases := []
		for i in tested.size():
			glow_phases.append(["glow_off_%d" % i, G.NONE, true, false, 752, "pass"])
			glow_phases.append(tested[i])
		glow_phases.append(["glow_off_%d" % tested.size(), G.NONE, true, false, 752, "pass"])
		var phases := []
		for phase: Array in glow_phases:
			phases.append([phase[0] + "_song", Callable(), _set_glow.bind(phase[1], phase[2], phase[3], phase[4], phase[5]),
					MSAA_SONG_SECONDS, true])
		return phases
	if mode == FOG:
		var phases := []
		for stage: Array in [["night_city", _night_city], ["metal_factory", _metal_factory]]:
			for off: String in ["", "light_glow", "shading", "scenery"]:
				phases.append(["%s_%s_song" % [stage[0], "all_on" if off == "" else "no_" + off],
					func(_t: float) -> void: _stage_parts(off), stage[1], FOG_SONG_SECONDS, true])
			phases.append(["%s_all_on_again_song" % stage[0], func(_t: float) -> void: _stage_parts(""), stage[1],
				FOG_SONG_SECONDS, true])
		return phases
	if mode == REFLECTION:
		var classic := func() -> void: Settings.environment = "classic"
		var phases := []
		for step: Array in [["all_on", 0], ["no_reflection", DebugView.NO_REFLECTION], ["all_on_again", 0],
				["no_reflection_again", DebugView.NO_REFLECTION], ["sweep_held", DebugView.FORCE_SWEEP], ["all_on_last", 0]]:
			var bits: int = step[1]
			phases.append(["classic_%s_song" % step[0], func(_t: float) -> void: _set_debug_bits(bits), classic,
				FOG_SONG_SECONDS, true])
		return phases
	if mode == CUT_DUST:
		var classic := func() -> void:
			Settings.environment = "classic"
			_cuts_fired = 0
		var phases := []
		for step: Array in [["sparks_only", DebugView.NO_CUT_DUST], ["sparks_and_dust", 0],
				["sparks_only_again", DebugView.NO_CUT_DUST], ["sparks_and_dust_again", 0]]:
			var bits: int = step[1]
			phases.append(["classic_%s_song" % step[0], func(t: float) -> void: _fire_cuts(t, bits), classic,
				FOG_SONG_SECONDS, true])
		return phases
	if mode == HZ90:
		var phases := []
		if openxr:
			print("BENCH refresh rates ", openxr.get_available_display_refresh_rates())
			var rate := func(hz: float, preset: String) -> void:
				openxr.display_refresh_rate = hz
				if not preset.is_empty():
					Settings.set_graphics_preset(preset)
			phases = [
				["menu_72hz", _sweep_pointer, rate.bind(72.0, "")],
				["menu_90hz", _sweep_pointer, rate.bind(90.0, "")],
				["song_72hz_song", Callable(), rate.bind(72.0, ""), HZ_SONG_SECONDS, true],
				["song_90hz_song", Callable(), rate.bind(90.0, ""), HZ_SONG_SECONDS, true],
				["song_90hz_low_song", Callable(), rate.bind(90.0, "Low"), HZ_SONG_SECONDS, true],
				["song_72hz_again_song", Callable(), rate.bind(72.0, ""), HZ_SONG_SECONDS, true],
			]
		return phases
	if mode == TOTAL:
		# [name, preset, glow on (null: the preset's), glow style, anti-aliasing, atmosphere, render scale]
		var tested := [
			["old_normal_godot_glow_aa_off", "Normal", true, "Classic", "Off", "Normal", 1.0],
			["normal_4x_soft_halo", "Normal", true, "Soft", "4x", "Normal", 1.0],
			["normal_4x_soft_halo_eerie", "Normal", true, "Soft", "4x", "Eerie", 1.0],
			["normal_4x_crisp_halo", "Normal", true, "Crisp", "4x", "Normal", 1.0],
			["normal_4x_classic", "Normal", true, "Classic", "4x", "Normal", 1.0],
			["low_preset", "Low", null, "Soft", "4x", "Normal", 1.0],
			["normal_4x_soft_halo_sharp_1.2", "Normal", true, "Soft", "4x", "Normal", 1.2],
		]
		var off := ["Normal", false, "Soft", "4x", "Normal", 1.0]
		var phases := []
		for i in tested.size():
			phases.append(["glow_off_%d_song" % i, Callable(), _set_look.bindv(off), MSAA_SONG_SECONDS, true])
			phases.append([tested[i][0] + "_song", Callable(), _set_look.bindv(tested[i].slice(1)), MSAA_SONG_SECONDS, true])
		phases.append(["glow_off_%d_song" % tested.size(), Callable(), _set_look.bindv(off), MSAA_SONG_SECONDS, true])
		return phases
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
		_refresh_rate = openxr.display_refresh_rate
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
	game.glow_override = -1
	LowResGlow.set_quality(Settings.glow_quality)
	LowResGlow.upsample = "pass"
	game._apply_glow()
	game.get_viewport().msaa_3d = Settings.msaa_mode()
	Settings.save()
	DirAccess.remove_absolute(Constants.APPDATA_PATH + BACKUP_FILE)
	# the render scale only at the end: each change makes the runtime remake its eye buffers
	if openxr:
		openxr.render_target_size_multiplier = _render_scale
		if _refresh_rate > 0.0:
			openxr.display_refresh_rate = _refresh_rate
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

## Sets the player's own look settings for a phase (glare null keeps the preset's); all put back after it, the render
## scale at the end of the run.
func _set_look(preset: String, glare: Variant, quality: String, msaa: String, atmosphere: String, scale: float) -> void:
	Settings.set_graphics_preset(preset)
	if glare != null:
		Settings.glare = glare
	Settings.glow_quality = quality
	Settings.msaa = msaa
	Settings.atmosphere = atmosphere
	var openxr := XRServer.find_interface("OpenXR") as OpenXRInterface
	if openxr:
		openxr.render_target_size_multiplier = scale

## Sets the glow (BeepSaber_Game.Glow) and LowResGlow's switches for a phase, on Normal at 1x without MSAA; all put
## back at the end of the run.
func _set_glow(glow: int, view_msaa: bool, short_chain: bool, height: int, upsample: String) -> void:
	_set_view("Normal", Viewport.MSAA_DISABLED, 1.0)
	LowResGlow.view_msaa = view_msaa
	LowResGlow.short_chain = short_chain
	LowResGlow.height = height
	LowResGlow.upsample = upsample
	game.glow_override = glow
	game._apply_glow()

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
	LowResGlow.height = _glow_height
	_set_debug_bits(0)
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
