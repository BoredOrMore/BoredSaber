# This is a stand-alone version of the demo game Beep Saber. It started (and is still included)
# in the godot oculus quest toolkit (https://github.com/NeoSpark314/godot_oculus_quest_toolkit)
# But this stand-alone version as additional features and will be developed independently
# This file contains the main game logic for the BeepSaber demo implementation
extends Node3D
class_name BeepSaber_Game

var version : String = ProjectSettings.get_setting("application/config/version", "0.0.0")
## the streak where a saber cut a note (BeepCube.cut)
var cut_flash := CutFlash.new()
## Sabers touching: both controllers buzz while the blades are this close (metres), as in Beat Saber.
const CLASH_DISTANCE := 0.04
const CLASH_RUMBLE := 0.5
var gamestate_bootup := GameState.new()
var gamestate_mapcomplete := GameStateMapComplete.new()
var gamestate_mapselection := GameStateMapSelection.new()
var gamestate_newhighscore := GameStateNewHighScore.new()
var gamestate_paused := GameStatePaused.new()
var gamestate_playing := GameStatePlaying.new()
var gamestate_settings := GameStateSettings.new()
var gamestate_bodytest := GameStateBodyTest.new()

var gamestate: GameState = gamestate_bootup
var current_health := Constants.HEALTH_START

@onready var xr_origin := $XROrigin3D as XROrigin3D
@onready var left_controller := $XROrigin3D/LeftController as BeepSaberController
@onready var right_controller := $XROrigin3D/RightController as BeepSaberController
@onready var left_saber := $XROrigin3D/LeftController/LeftLightSaber as LightSaber
@onready var right_saber := $XROrigin3D/RightController/RightLightSaber as LightSaber
@onready var left_ui_raycast := $XROrigin3D/LeftController/LeftLightSaber/UIRaycast as UIRaycast
@onready var right_ui_raycast := $XROrigin3D/RightController/RightLightSaber/UIRaycast as UIRaycast
@onready var goggles_shader := ($XROrigin3D/XRCamera3D/VRGoggles as MeshInstance3D).material_override as ShaderMaterial
@onready var debug_info_label := $XROrigin3D/XRCamera3D/PlayerHead/DebugInfoLabel as MeshInstance3D
@onready var log_window := $Settings_canvas/OQ_UI2DLogWindow as Node3D

@onready var main_menu := $MainMenu_OQ_UI2DCanvas as OQ_UI2DCanvas
@onready var pause_menu := $PauseMenu_canvas as OQ_UI2DCanvas
@onready var pause_countdown := $Pause_countdown as Label3D
@onready var settings_canvas := $Settings_canvas as OQ_UI2DCanvas
@onready var settings_panel := settings_canvas.ui_control as SettingsPanel
@onready var profiles_canvas := $Profiles_canvas as OQ_UI2DCanvas
@onready var profiles_panel := profiles_canvas.ui_control as ProfilesPanel
@onready var highscore_canvas := $Highscores_Canvas as OQ_UI2DCanvas
@onready var highscore_panel := highscore_canvas.ui_control as HighscorePanel
## Where the record table stands on the score screen: next to the score panel (its place in the scene).
@onready var highscores_score_transform := highscore_canvas.transform
@onready var highscore_keyboard := $Keyboard_highscore as OQ_UI2DKeyboard
@onready var slash_block := $SlashBlock as SlashBlock
@onready var endscore := $EndScore as EndScore

@onready var points_label_driver := $Points_label_driver as PointsLabelDriver
@onready var event_driver := $event_driver as EventDriver

@onready var multiplier_label := $Multiplier_Label as MeshInstance3D
@onready var point_label := $Point_Label as MeshInstance3D
@onready var percent_indicator := $Percent_Indicator as PercentIndicator
@onready var health_rails := $HealthRails as HealthRails

@onready var map_source_dialogs := $MapSourceDialogs as Node3D
@onready var online_search_keyboard := $Keyboard_online_search as OQ_UI2DKeyboard
@onready var beatsaver_canvas := $MapSourceDialogs/BeatSaver_Canvas as OQ_UI2DCanvas

@onready var cube_template := preload("res://game/notes/BeepCube/BeepCube.tscn").instantiate() as BeepCube

@onready var track := $Track as Node3D
@onready var standing_ground := $StandingGround as Floor

@onready var song_player := $SongPlayer as AudioStreamPlayer

@onready var menu := main_menu.ui_control as MainMenu


# There's an interesting issue where the AudioStreamPlayer's playback_position
# doesn't immediately return to 0.0 after restarting the song_player. This
# causes issues with restarting a map because the process_physics routine will
# execute for a times and attempt to process the map up to the playback_position
# prior to the AudioStreamPlayer restart. This bug can presents itself as notes
# persisting between map restarts.
# To remidy this issue, this flag is set to true when the map is restarted. The
# process_physics routine won't begin processing the map until after the
# AudioStreamPlayer has reset it's playback_position to zero. This flag is set
# to false once the AudioStreamPlayer reset is detected.
var _audio_synced_after_restart := false

var _in_wall := false
# last clock value pushed to the score labels
var _shown_seconds_left := -1

#prevents the song for starting from the start when pausing and unpausing
var pause_position := 0.0

const LEAD_IN_MIN_SECONDS := 3.0
## The score, combo, accuracy and time panels (game/hud/Hud.gd)
var hud: Hud
# seconds left before the song starts, so the first notes can fly in; counted down by Playing
var lead_in := 0.0

## The fail, in the owner's order (2026-10-28): the sound goes first (the low-pass sweep below) and the play space
## empties, every note, chain, bomb, wall and arc falling away over FAIL_CLEAR_SECONDS (nothing can be cut or
## missed after the fail: the track freezes and the sabers stop cutting); then a pause of muffled bass; then at
## FAIL_WORD_DELAY the big FAILED appears and the red comes into the air; FAIL_WORD_SECONDS later the view fades to
## black for the score screen. Owner's timing (2026-10-28): shrink 0-0.5 s, an empty track with muffled bass to 1 s,
## FAILED and the red air at 1 s, the fade to black at 4 s; then (2026-10-28) the track's things fall for the whole
## second before FAILED instead of shrinking in half of it. Untuned until seen on the headset.
const FAIL_CLEAR_SECONDS := 1.0
const FAIL_FALL_GRAVITY := 9.8
const FAIL_TUMBLE := 3.0
const FAIL_REST_HEIGHT := 0.22
const FAIL_BOUNCE := 0.3
const FAIL_LAND_SPIN := 0.6
const FAIL_FADE_FROM := 0.65
## how far notes' dissolve plane travels (their own size, local), and how deep walls and arcs sink into the deck (m)
const FAIL_DISSOLVE_SPAN := 0.5
const FAIL_SINK_DEPTH := 6.0
const FAIL_WORD_DELAY := 1.0
const FAIL_WORD_SECONDS := 3.0
## the notes and blades mirrored in the deck, switched off while a fail drops everything through it
var _floor_reflection: FloorReflection
## the end of a song: "FAILED" in the play space and the fade to black (ResultMoment)
var _result_moment: ResultMoment
## where in the song (seconds) the last fail happened, for the score screen
var _failed_at := 0.0
## A fail closes a low-pass on the song like Beat Saber (measured from a recording of its PC version, 2026-10-28,
## recordings/audio/fail.wav): the top of the spectrum falls from about 10 kHz to 600 Hz in 0.2 s, halving about
## every 50 ms, then only the bass under 200 Hz is left for about 0.45 s before its fail screen's music. So the
## cutoff glides exponentially from FAIL_CUTOFF_FROM_HZ to FAIL_CUTOFF_TO_HZ over FAIL_SWEEP_SECONDS, and the
## muffled song fades to FAIL_SILENT_DB over FAIL_TAIL_SECONDS (longer than Beat Saber's 0.45 s: the owner wanted the
## bass to carry on until FAILED at 1 s); it stays quiet until the fade to black.
const FAIL_CUTOFF_FROM_HZ := 20000.0
const FAIL_CUTOFF_TO_HZ := 150.0
const FAIL_SWEEP_SECONDS := 0.2
const FAIL_TAIL_SECONDS := 0.8
const FAIL_SILENT_DB := -60.0
## added to the song's bus only while a fail plays out
var _fail_filter := AudioEffectLowPassFilter.new()
## A stage picked in the song menu changes behind a short black fade (owner, 2026-10-28, option "ข"): down over
## STAGE_FADE_SECONDS, the switch, STAGE_HOLD_SECONDS black while the new stage's first frames draw (on the Pico a
## switch stalls about 70 ms at 0.08 s and 110 ms at about 0.2 s, then two to four 28-40 ms frames to about 0.4 s,
## first pass or not; stages bench on 4f3f006, 2026-10-28), then back up.
const STAGE_FADE_SECONDS := 0.15
const STAGE_HOLD_SECONDS := 0.35
var _stage_switching := false
# the high score saved at the end of the last song
var _new_record := {}
const DANGER_WALL_MATERIAL := preload("res://game/notes/Wall/danger_wall.tres")
## Mistake sounds (tools/make_hit_sounds.py): a dull buzz for a bad cut or the wrong saber, a boom for a bomb.
## A miss gets a soft swipe (tools/make_feedback_sounds.py), quieter than a bad cut.
const BAD_CUT_SOUND := preload("res://game/data/bad_cut.wav")
const BOMB_HIT_SOUND := preload("res://game/data/bomb_hit.wav")
const MISS_SOUND := preload("res://game/data/miss.wav")
## Raised against the cuts (loudness notes, 2026-10-23): a miss and the low health loop measured about 9 LU under a
## cut and sank in the music, a bomb a little under. Starting points to try on the headset.
const MISS_GAIN_DB := 4.0
const LOW_HEALTH_GAIN_DB := 4.0
const BOMB_GAIN_DB := 2.0
## Mistake sounds come from where the note was, so a miss on the left sounds on the left; at full volume wherever.
var _mistake_player: AudioStreamPlayer3D
## Song-end and danger sounds: the saber ignition reversed into a low thump for a fail (tools/make_fail_sound.py),
## a rising chord for a cleared song and a heartbeat that loops while health is low (tools/make_feedback_sounds.py).
const FAIL_SOUND := preload("res://game/data/fail.wav")
const CLEAR_SOUND := preload("res://game/data/clear.wav")
const LOW_HEALTH_SOUND := preload("res://game/data/low_health.wav")
## Health at or below this share of the bar plays the heartbeat; in 4 Lives mode that is the last life.
const LOW_HEALTH_FRACTION := 0.25
var _song_end_player: AudioStreamPlayer
var _low_health_player: AudioStreamPlayer
const BOMB_GLOW_MATERIAL := preload("res://game/notes/Bomb/bomb_glow.tres")
# how long a rumble that was on when the song failed takes to fade out
const FAIL_RUMBLE_FADE_SECONDS := 0.6
# a combo milestone buzzes both controllers once, after the cut's own rumble has passed (untuned)
const MILESTONE_RUMBLE := 0.4
const MILESTONE_RUMBLE_SECONDS := 0.12
const MILESTONE_RUMBLE_DELAY := 0.12
# true while the "Failed" moment plays, before the score screen
var failing := false
# the last song start's timing, kept while it watches the frames after the start
var _start_timing: StartTiming
## Starting a song from the menu (owner, 2026-10-28: slashing Play froze the view). On the Pico a start took 70-90 ms
## (reading the map 10, parsing it 31-37, loading the song 22-27) and the next frame 30-40 ms (cuts bench, d23b0c6).
## So the picked difficulty's map file and song are read on a worker thread as soon as they're picked (_preload), and
## the rest runs behind a short black fade: START_FADE_SECONDS down, the start, START_HOLD_SECONDS while its first
## frames draw, back up.
## The fade waits START_SPARK_SECONDS first, so the play block's cut (its sparks and halves) shows before the black
## (owner, 2026-10-28).
const START_SPARK_SECONDS := 0.3
const START_FADE_SECONDS := 0.15
const START_HOLD_SECONDS := 0.2
## Seconds a difficulty must stay picked before _preload reads it, so scrolling through the song list doesn't read
## every song it passes (owner, 2026-10-29: scrolling the list froze while each step waited for the last song's read).
const PRELOAD_DELAY_SECONDS := 0.3
var _preload_key := ""
## whether the read of _preload_key has started (it waits PRELOAD_DELAY_SECONDS first)
var _preload_started := false
var _preload_task := -1
var _preloaded := {}
## the reads not yet collected (by their task id): the one under way, and those of songs scrolled past
var _preload_running := {}

## Reads the map file and the song of `difficulty` of `info` on a worker thread once it has stayed picked for
## PRELOAD_DELAY_SECONDS, unless that's the one read. Never waits for an earlier read: that one finishes on its own.
func _preload(info: MapInfo, difficulty: DifficultyInfo) -> void:
	var key := info.filepath + difficulty.beatmap_filename
	if key == _preload_key:
		return
	_preload_key = key
	_preload_started = false
	_preloaded = {}
	await get_tree().create_timer(PRELOAD_DELAY_SECONDS).timeout
	if key != _preload_key or _preload_started:
		return
	_preload_started = true
	var task := WorkerThreadPool.add_task(_read_song.bind(info, difficulty, _preloaded))
	_preload_task = task
	_preload_running[task] = true
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	if _preload_running.erase(task):
		WorkerThreadPool.wait_for_task_completion(task)

## Reads the map file (as "map_data") and the song (as "stream", with its file's "size") into `into`; on a worker.
static func _read_song(info: MapInfo, difficulty: DifficultyInfo, into: Dictionary) -> void:
	into["map_data"] = Utils.binary_to_json(Utils.read_binary_file(info.filepath, difficulty.beatmap_filename))
	var filename := info.filepath + info.song_filename
	if FileAccess.file_exists(filename):
		into["stream"] = AudioStreamOggVorbis.load_from_file(filename)
		into["size"] = FileAccess.open(filename, FileAccess.READ).get_length()

## What was read for `difficulty` of `info` (waiting for it if it's still being read, reading it now if it was picked
## too recently to have started), {} if something else was. It stays, so a restart of the song finds it in memory.
func _take_preload(info: MapInfo, difficulty: DifficultyInfo) -> Dictionary:
	if _preload_key != info.filepath + difficulty.beatmap_filename:
		return {}
	if not _preload_started:
		# behind the start's black fade, like the rest of the start
		_preload_started = true
		_read_song(info, difficulty, _preloaded)
	elif _preload_running.erase(_preload_task):
		WorkerThreadPool.wait_for_task_completion(_preload_task)
	return _preloaded

## Starts a song behind a short black fade (START_*): from the song menu after the play block's sparks, on a restart
## (`restart`, owner, 2026-10-28) at once.
func start_map(info: MapInfo, map_difficulty: DifficultyInfo, restart := false) -> void:
	var from_menu := gamestate == gamestate_mapselection
	var faded := (from_menu or restart) and _result_moment != null
	if faded:
		if from_menu:
			await get_tree().create_timer(START_SPARK_SECONDS).timeout
		await _result_moment.fade_out(START_FADE_SECONDS)
	_start_map(info, map_difficulty)
	if faded:
		await get_tree().create_timer(START_HOLD_SECONDS).timeout
		_result_moment.fade_in(START_FADE_SECONDS)

## Loads the song and its map (using what _preload read when it's this one), sets the stage up and starts playing.
func _start_map(info: MapInfo, map_difficulty: DifficultyInfo) -> void:
	points_label_driver.visible = true
	var timing := StartTiming.new()
	_start_timing = timing
	var preloaded := _take_preload(info, map_difficulty)
	var map_data: Dictionary = preloaded["map_data"] if preloaded.has("map_data") else \
			Utils.binary_to_json(Utils.read_binary_file(info.filepath, map_difficulty.beatmap_filename))
	
	if (map_data.is_empty()):
		vr.log_error("Could not read map data from " + info.filepath + "/" + map_difficulty.beatmap_filename)
	timing.lap("read")
	if not Map.load_beatmap(info, map_difficulty, map_data):
		menu.show_play_error()
		return
	timing.lap("parse")
		
	event_driver.set_environment(EventDriver.pick_environment(info))
	timing.lap("stage")
	# for reading GPU timings on the headset by environment
	print("Song starts in environment %s, smoke %s, debug_view %d" % [event_driver.environment, Settings.smoke, DebugView.flags])
	print("song_info %s | %s | speed %d" % [info.song_name, MapStats.level_name(info, map_difficulty), Settings.music_speed])
	event_driver.set_background_texture()
	timing.lap("sky")
	
	event_driver.set_menu_focus(false)
	update_left_color(Map.color_left)
	update_right_color(Map.color_right)
	_update_danger_color(Map.color_obstacle)
	event_driver.set_background()
	
	# the show starts in the dark; a map with its own light show turns lights on at its first event, and one without
	# stays dark (the owner's choice, doc/world/GAME_BIBLE.md): the notes, sabers and platform light themselves
	event_driver.set_all_off()
	event_driver.start_show(Map.event_stack, info.beats_per_minute)
	timing.lap("colours_show")
	
	var filename := info.filepath + info.song_filename
	vr.log_info("loading: " + filename)
	if preloaded.has("stream"):
		song_player.stream = preloaded["stream"]
		Loudness.apply(song_player.bus, song_player.stream, Loudness.key(preloaded["size"], song_player.stream))
	elif FileAccess.file_exists(filename):
		song_player.stream = AudioStreamOggVorbis.load_from_file(filename)
		Loudness.apply(song_player.bus, song_player.stream, Loudness.key(FileAccess.open(filename, FileAccess.READ).get_length(),
				song_player.stream))
	else:
		var audio_data : PackedByteArray
		audio_data = Utils.read_binary_file(info.filepath, info.song_filename)
		if len(audio_data) > 0:
			song_player.stream = AudioStreamOggVorbis.load_from_buffer(audio_data)
			Loudness.apply(song_player.bus, song_player.stream, Loudness.key(audio_data.size(), song_player.stream))
		else:
			vr.log_info("playing silence")
			var wav := AudioStreamWAV.new()
			wav.set_stereo(false)
			wav.set_format(AudioStreamWAV.FORMAT_8_BITS)
			wav.set_mix_rate(11025)
			var length := ceili((Map.current_info.get_length_seconds() + 2) * wav.mix_rate)
			var data := PackedByteArray()
			data.resize(length) 
			data.fill(0)
			wav.set_data(data)
			song_player.stream = wav
	
	timing.lap("audio")
	_audio_synced_after_restart = false
	song_player.stop()
	# room for the first notes to fly in and jump (Cuttable.FLY_SECONDS)
	lead_in = maxf(LEAD_IN_MIN_SECONDS, Map.half_jump_beats / Map.beats_per_second() + Cuttable.FLY_SECONDS)
	song_player.volume_db = 0.0
	song_player.pitch_scale = Settings.music_speed / 100.
	_remove_fail_filter()
	_in_wall = false
	Scoreboard.restart()
	
	hud.place(_eye())
	_display_points()
	percent_indicator.start_map()
	# No Fail still keeps a health bar out of sight: running it out halves the score (Scoreboard.spend_no_fail)
	current_health = Health.start_value(Settings.health_mode, Settings.fail_mode)
	if Settings.health_mode:
		health_rails.start_map(Settings.fail_mode == Constants.FAIL_MODE_LIVES, current_health / Constants.HEALTH_MAX, _eye())
	
	_clear_track()
	_lowered_resolution = false
	_transition_game_state(gamestate_playing)
	timing.lap("rest")
	timing.report()

## Changes health by delta in the health bar mode. mistake is a miss, bad cut, bomb or wall
## entry, which costs a life in 4 Lives mode and ends the song in Instant Fail mode.
func update_health(delta: float, mistake: bool = false) -> void:
	current_health = Health.next_value(current_health, delta, mistake, Settings.health_mode, Settings.fail_mode,
			Settings.damage_scale)
	if not Settings.health_mode:
		if current_health <= 0.0 and gamestate == gamestate_playing:
			Scoreboard.spend_no_fail()
		return
	if Settings.health_mode:
		health_rails.update_health(current_health / Constants.HEALTH_MAX)
		if current_health <= 0 and gamestate == gamestate_playing and not failing:
			_fail_song()
		_update_low_health_sound()

## Loops the heartbeat while a map plays with health at or below LOW_HEALTH_FRACTION, and stops it otherwise.
func _update_low_health_sound() -> void:
	var low := (Settings.health_mode and gamestate == gamestate_playing and not failing
			and current_health <= Constants.HEALTH_MAX * LOW_HEALTH_FRACTION)
	if low and not _low_health_player.playing:
		_low_health_player.play()
	elif not low and _low_health_player.playing:
		_low_health_player.stop()

## Shows "FAILED" in the play space while the song winds down and the track freezes, fades to black, then the score
## screen fades up.
func _fail_song() -> void:
	failing = true
	_failed_at = get_current_time()
	event_driver.set_all_off()
	Scoreboard.paused = true
	_update_low_health_sound()
	_song_end_player.stream = FAIL_SOUND
	_song_end_player.play()
	left_saber.set_swingcast_enabled(false)
	right_saber.set_swingcast_enabled(false)
	_empty_track()
	# the score and combo panels and the energy strips are gone by the time FAILED shows (owner, 2026-10-29)
	hud.fade_out(FAIL_WORD_DELAY)
	health_rails.fade_out(FAIL_WORD_DELAY)
	var tw := create_tween().set_parallel()
	# the frozen wall that failed the song would otherwise keep the controllers buzzing
	_in_wall = false
	for controller: BeepSaberController in [left_controller, right_controller]:
		var from := controller.get_rumble_intensity()
		if from > 0.0:
			tw.tween_method(func(amount: float) -> void: controller.simple_rumble(amount, 0.05), from, 0.0, FAIL_RUMBLE_FADE_SECONDS)
	_fail_filter.cutoff_hz = FAIL_CUTOFF_FROM_HZ
	AudioServer.add_bus_effect(AudioServer.get_bus_index(song_player.bus), _fail_filter)
	tw.tween_method(func(octaves: float) -> void: _fail_filter.cutoff_hz = FAIL_CUTOFF_FROM_HZ * pow(2.0, -octaves),
			0.0, log(FAIL_CUTOFF_FROM_HZ / FAIL_CUTOFF_TO_HZ) / log(2.0), FAIL_SWEEP_SECONDS)
	tw.tween_property(song_player, ^"volume_db", FAIL_SILENT_DB, FAIL_TAIL_SECONDS).set_delay(FAIL_SWEEP_SECONDS)
	var show_word := func() -> void:
		event_driver.result_mood(true)
		_result_moment.show_failed(_eye())
	tw.tween_callback(show_word).set_delay(FAIL_WORD_DELAY)
	tw.tween_interval(FAIL_WORD_DELAY + FAIL_WORD_SECONDS)
	await tw.finished
	await _result_moment.fade_out()
	_result_moment.hide_failed()
	failing = false
	_on_song_ended()
	_result_moment.fade_in()

## The song played to its end: a short fade to black, then the score screen fades up.
func _on_song_finished() -> void:
	await _result_moment.fade_out()
	_on_song_ended()
	_result_moment.fade_in()

## The track empties over FAIL_CLEAR_SECONDS (owner, 2026-10-28: things should fall, land and fade, not shrink). Notes,
## chain links and bombs fall under FAIL_FALL_GRAVITY with a little tumble (up to FAIL_TUMBLE rad/s round a random
## axis), land on the floor (y 0, FAIL_REST_HEIGHT their half height), bounce with FAIL_BOUNCE of their speed and lose
## FAIL_LAND_SPIN of their tumble on each landing, then from FAIL_FADE_FROM of the window notes and links dissolve from
## the top down (their cut shader's vanish) and bombs shrink away. Walls and arcs, long and fixed to the track, sink into
## the deck instead. Cheap per-object maths, no physics bodies. The cut numbers go at once; the floor reflection goes
## when the fading starts (it mirrors the landed notes until then). Then the track is cleared, the pooled ones released
## with their transforms and shader state put back, so the play space is empty before FAILED.
func _empty_track() -> void:
	points_label_driver.visible = false
	var rests := {}
	var falling := []
	for c: Node in track.get_children():
		if not (c is Node3D and (c as Node3D).visible):
			continue
		var node := c as Node3D
		rests[node] = node.transform
		if node is Wall or node is Arc:
			falling.append({node = node, sink = true})
		else:
			falling.append({node = node, sink = false, velocity = 0.0, angle = 0.0,
				axis = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized(),
				spin = randf_range(-FAIL_TUMBLE, FAIL_TUMBLE)})
	var t := 0.0
	while t < FAIL_CLEAR_SECONDS and not falling.is_empty():
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var fade := clampf((t / FAIL_CLEAR_SECONDS - FAIL_FADE_FROM) / (1.0 - FAIL_FADE_FROM), 0.0, 1.0)
		if fade > 0.0:
			_floor_reflection.enabled = false
		for body: Dictionary in falling:
			var node: Node3D = body.node
			var rest: Transform3D = rests[node]
			if not is_instance_valid(node):
				continue
			if body.sink:
				node.position.y = rest.origin.y - FAIL_SINK_DEPTH * ease(t / FAIL_CLEAR_SECONDS, 2.0)
				continue
			body.velocity -= FAIL_FALL_GRAVITY * dt
			var y: float = node.position.y + body.velocity * dt
			if y < FAIL_REST_HEIGHT and body.velocity < 0.0:
				y = FAIL_REST_HEIGHT
				body.velocity = -body.velocity * FAIL_BOUNCE
				body.spin *= 1.0 - FAIL_LAND_SPIN
			body.angle += body.spin * dt
			node.transform = Transform3D(rest.basis.rotated(body.axis, body.angle), Vector3(node.position.x, y, node.position.z))
			if node is BeepCube or node is ChainLink:
				var material: ShaderMaterial = node._mat
				material.set_shader_parameter(&"cutted", fade > 0.0)
				material.set_shader_parameter(&"cut_plane_normal", Vector3.DOWN)
				material.set_shader_parameter(&"cut_plane_dist", -FAIL_DISSOLVE_SPAN)
				material.set_shader_parameter(&"cut_vanish", fade * 2.0 * FAIL_DISSOLVE_SPAN)
			elif fade > 0.0:
				node.scale = rest.basis.get_scale() * (1.0 - fade)
	_clear_track()
	_floor_reflection.enabled = true
	for c: Node3D in rests:
		if is_instance_valid(c):
			c.transform = rests[c]
			if c is BeepCube or c is ChainLink:
				var material: ShaderMaterial = c._mat
				material.set_shader_parameter(&"cutted", false)
				material.set_shader_parameter(&"cut_vanish", 0.0)

## Takes the fail's low-pass off the song's bus, if a fail left it there.
func _remove_fail_filter() -> void:
	var bus := AudioServer.get_bus_index(song_player.bus)
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) == _fail_filter:
			AudioServer.remove_bus_effect(bus, i)
			return
			
# This function will transitioning the game from it's current state into
# the provided 'next_state'.
func _transition_game_state(next_state: GameState) -> void:
	gamestate = next_state
	_place_menus()
	_apply_glow()
	_update_low_health_sound()
	# the scene only lights up for the combo while a map is on
	if gamestate != gamestate_playing and gamestate != gamestate_paused:
		event_driver.set_combo_multiplier(1)
	gamestate._ready(self)

## Shows the FPS label and the log window under the settings panel only when debug info is on.
func _show_debug_info() -> void:
	debug_info_label.visible = Settings.show_debug_info
	var log_canvas := log_window.get_node(^"OQ_UI2DCanvas") as OQ_UI2DCanvas
	if Settings.show_debug_info:
		log_canvas._show()
	else:
		log_canvas._hide()
	log_window.set_process(Settings.show_debug_info)

## Closes any download page; they open in front of the player, in place of the menu, when asked for.
func show_MapSourceDialogs(showing: bool = true) -> void:
	map_source_dialogs.visible = showing
	for c in map_source_dialogs.get_children():
		if c is OQ_UI2DCanvas:
			(c as OQ_UI2DCanvas)._hide()

## Opens the BeatSaver page where the song menu was; closing it brings the menu back.
## While Get songs is open the stage behind it goes quiet (owner, 2026-10-28, option ก): no beams, dust, scenery detail
## or floor reflection, through DebugView's bits, so the page's GPU headroom stops running out while it is dragged
## (GPU 10-14 ms of the 13.9 ms frame there, headset 1073fc0). Only the bits this turned on are turned off again.
const BEATSAVER_QUIET := DebugView.LASERS | DebugView.DUST | DebugView.FLAT_SCENERY | DebugView.NO_REFLECTION
var _quieted := 0

func _open_beatsaver() -> void:
	_quieted = BEATSAVER_QUIET & ~DebugView.flags
	DebugView.flags |= _quieted
	main_menu._hide()
	# the song menu's keyboard sits where the BeatSaver one opens
	highscore_keyboard._hide()
	beatsaver_canvas._show()

## Brings the song menu back once the BeatSaver page closes in the song menu.
func _on_beatsaver_visibility_changed() -> void:
	if not beatsaver_canvas.visible and _quieted:
		DebugView.flags &= ~_quieted
		_quieted = 0
	if not beatsaver_canvas.visible and gamestate == gamestate_mapselection:
		online_search_keyboard._hide()
		main_menu._show()
		# the BeatSaver preview stops; the selected song's preview comes back
		menu.play_selected_preview(0.0, true)

## The card under the score: who this run's record was saved as, or the map's best when this run didn't make the board.
func _show_name_card() -> void:
	var records := Highscores.get_records(Map.current_info,
		HighscoreTable.get_rank_key(Map.current_difficulty.difficulty_rank))
	if not _new_record.is_empty():
		endscore.show_name_card("Saved as %s" % _new_record.player_name, true)
	elif not records.is_empty():
		endscore.show_name_card("Best on this map: %s by %s" % [Hud._grouped(records[0].score), records[0].player_name])
	else:
		endscore.hide_name_card()
	if _lowered_resolution:
		var card := endscore._name_label.text if endscore._name_card.visible else ""
		endscore.show_name_card(LOWERED_TEXT if card.is_empty() else "%s\n%s" % [card, LOWERED_TEXT])

func _check_and_update_saber(controller: BeepSaberController, saber: LightSaber) -> void:
	# to allow extending/sheething the saber while not playing a song
	# (the song is also silent during the lead-in, so check the game state; the
	# pause menu keeps them sheathed so they don't get in the way of pointing)
	if ((gamestate != gamestate_playing and gamestate != gamestate_paused)
		and (controller.ax_just_pressed() or controller.by_just_pressed())
		and (not saber._anim.is_playing())):
		if (saber.is_extended()): saber._hide()
		else: saber._show()
		
	# walls only count while playing; after a fail or the song's end the head
	# can still be inside a frozen or hidden wall
	var walled := _in_wall and gamestate == gamestate_playing and not failing
	if walled:
		Scoreboard.enter_wall()
	
	# check for saber rumble (only when extended and not already rumbling)
	# this check is necessary to not overwrite a rumble set from somewhere else
	# (in this case it can come from cutting cubes); a fail fades its own rumble
	if not controller.is_simple_rumbling() and not failing: 
		if walled:
			# weak rumble on both controllers when player is inside wall
			controller.simple_rumble(0.3, 0.3)
		elif saber.get_overlapping_areas().size() > 0 or saber.get_overlapping_bodies().size() > 0:
			# strong rumble when saber is cutting into wall or other saber
			controller.simple_rumble(0.5, 0.1)
		else:
			controller.simple_rumble(0.0, 0.1)


func _physics_process(_dt: float) -> void:
	# score changes emit on their own; this only ticks the clock under the score
	var seconds_left := _seconds_left()
	if seconds_left != _shown_seconds_left:
		_shown_seconds_left = seconds_left
		Scoreboard.score_changed.emit()
	
	if debug_info_label.visible:
		var dbg_text := "FPS: %d\nCube Pool: %d free of %d\nLink Pool: %d free of %d" % [
			Engine.get_frames_per_second(),
			GlobalReferences.cube_pool.free_count(), GlobalReferences.cube_pool.total_count(),
			GlobalReferences.link_pool.free_count(), GlobalReferences.link_pool.total_count()]
		(debug_info_label.mesh as TextMesh).text = dbg_text
	
	gamestate._physics_process(self)
	
	_check_and_update_saber(left_controller, left_saber)
	_check_and_update_saber(right_controller, right_saber)

func _enter_tree() -> void:
	GlobalReferences.main_game_scene = self
	
	@warning_ignore("return_value_discarded")
	Settings.changed.connect(on_settings_changed)

## The countdown before a song starts or resumes (tools/make_countdown_sounds.py): a tick on 3, 2, 1 and a higher
## tone when the song goes.
const COUNTDOWN_TICK := preload("res://game/data/countdown_tick.wav")
const COUNTDOWN_GO := preload("res://game/data/countdown_go.wav")
var _countdown_player := AudioStreamPlayer.new()

## The countdown's digit height in metres, as the old 16 px Roboto digit drawn 4.587 times larger (0.051 m at 0.65 m,
## about 4.5 degrees); Kanit's digits stand as tall as its capitals (ResultMoment.CAP_SHARE).
const COUNTDOWN_DIGIT_HEIGHT := 0.051
const COUNTDOWN_FONT_SIZE := 100
const COUNTDOWN_OUTLINE_SIZE := 16

const PAUSE_SOUND := preload("res://game/data/pause.wav")

## Plays the falling notes for the song pausing (resuming has the countdown).
func play_pause_sound() -> void:
	_countdown_player.stream = PAUSE_SOUND
	_countdown_player.play()

## Plays the countdown sound for seconds left (0: go).
func play_countdown(seconds: int) -> void:
	_countdown_player.stream = COUNTDOWN_TICK if seconds > 0 else COUNTDOWN_GO
	_countdown_player.play()

func _ready() -> void:
	track.position.z = Constants.HIT_PLANE_Z
	cut_flash.sabers = [left_saber, right_saber]
	add_child(cut_flash)
	_countdown_player.bus = &"SFX"
	add_child(_countdown_player)
	# the countdown in the numbers' font (Hud.NUMBER_FONT), outlined in the panel colour to read over the stage
	pause_countdown.font = Hud.NUMBER_FONT
	pause_countdown.font_size = COUNTDOWN_FONT_SIZE
	pause_countdown.pixel_size = COUNTDOWN_DIGIT_HEIGHT / (ResultMoment.CAP_SHARE * COUNTDOWN_FONT_SIZE)
	pause_countdown.outline_size = COUNTDOWN_OUTLINE_SIZE
	pause_countdown.modulate = Constants.UI_TEXT
	pause_countdown.outline_modulate = Constants.UI_PANEL
	_mistake_player = AudioStreamPlayer3D.new()
	_mistake_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	_mistake_player.bus = &"SFX"
	_mistake_player.max_polyphony = 2
	add_child(_mistake_player)
	_song_end_player = AudioStreamPlayer.new()
	# the only sounds with the environment's room (event_driver.gd STINGER_ROOMS)
	_song_end_player.bus = &"Stinger"
	add_child(_song_end_player)
	_low_health_player = AudioStreamPlayer.new()
	_low_health_player.bus = &"SFX"
	_low_health_player.stream = LOW_HEALTH_SOUND
	_low_health_player.volume_db = LOW_HEALTH_GAIN_DB
	add_child(_low_health_player)
	# pre-allocate scenes in our scene pools
	GlobalReferences.cube_pool = $BeepCubePool
	GlobalReferences.link_pool = $ChainLinkPool
	GlobalReferences.bomb_pool = $BombPool
	GlobalReferences.wall_pool = $WallPool
	GlobalReferences.arc_pool = $ArcPool
	GlobalReferences.cube_pool.presize(100)
	GlobalReferences.link_pool.presize(100)
	GlobalReferences.bomb_pool.presize(30)
	GlobalReferences.wall_pool.presize(15)
	GlobalReferences.arc_pool.presize(15)
	
	var xr_camera := $XROrigin3D/XRCamera3D as XRCamera3D
	vr.initialize(
		xr_origin,
		xr_camera,
		left_controller,
		right_controller,
		Settings.render_scale()
	)
	
	vr.pose_recentered.connect(recenter)
	# OpenXRInterface emits these when the headset comes off or a system window takes focus
	if vr.xr_interface and vr.xr_interface.has_signal(&"session_visible"):
		vr.xr_interface.connect(&"session_visible", _pause_if_playing)
		vr.xr_interface.connect(&"session_stopping", _pause_if_playing)
		for lost: StringName in [&"session_visible", &"session_synchronized", &"session_stopping"]:
			if vr.xr_interface.has_signal(lost):
				vr.xr_interface.connect(lost, _set_away.bind(true))
		if vr.xr_interface.has_signal(&"session_focussed"):
			vr.xr_interface.connect(&"session_focussed", _set_away.bind(false))

	_show_debug_info()
	set_colors_from_settings()
	LowResGlow.set_quality(Settings.glow_quality)
	low_res_glow = LowResGlow.new(self)
	low_res_glow.name = &"LowResGlow"
	add_child(low_res_glow)
	_apply_glow()
	_apply_msaa()
	_apply_note_style()
	_apply_environment()
	_apply_atmosphere()
	
	if not vr.inVR:
		xr_origin.add_child(preload("res://OQ_Toolkit/OQ_ARVROrigin/Feature_VRSimulator.tscn").instantiate())
	
	UI_AudioEngine.attach_children(highscore_keyboard)
	slash_block.sabers = [left_saber, right_saber]
	highscore_keyboard.visibility_changed.connect(_update_slash_block)
	main_menu.visibility_changed.connect(_update_slash_block)
	UI_AudioEngine.attach_children(online_search_keyboard)
	beatsaver_canvas.visibility_changed.connect(_on_beatsaver_visibility_changed)
	# from Settings: back to the song menu, which is what it measures
	Benchmark.restore_interrupted()
	var warnings := WarningIcon.new()
	warnings.name = &"WarningIcon"
	warnings.game = self
	add_child(warnings)
	var clock := MenuClock.new()
	clock.name = &"MenuClock"
	clock.game = self
	add_child(clock)
	settings_panel.benchmark_requested.connect(func() -> void:
		_on_settings_Panel_apply()
		_start_benchmark())
	# tools/bench.sh starts a run over adb by dropping the benchmark flag file
	var poll := Timer.new()
	poll.wait_time = 2.0
	poll.timeout.connect(func() -> void:
		if gamestate != gamestate_mapselection:
			return
		var mode: Variant = Benchmark.requested()
		if mode != null:
			_start_benchmark(mode))
	add_child(poll)
	poll.start()
	
	_transition_game_state(gamestate_mapselection)
	
	@warning_ignore("return_value_discarded")
	Scoreboard.score_changed.connect(_display_points)
	(multiplier_label as ComboHud).milestone_reached.connect(_on_combo_milestone)
	hud = Hud.new(point_label, multiplier_label as ComboHud, percent_indicator)
	add_child(hud)
	_floor_reflection = FloorReflection.new(track, [left_saber, right_saber], event_driver.track_deck)
	add_child(_floor_reflection)
	_result_moment = ResultMoment.new($XROrigin3D/XRCamera3D as Node3D)
	add_child(_result_moment)
	@warning_ignore("return_value_discarded")
	Scoreboard.points_awarded.connect(points_label_driver.show_points)
	
	#render common assets for a couple of frames to prevent performance issues when loading them mid game
	($pre_renderer as Node3D).visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	($pre_renderer as Node3D).queue_free()
	
	set_background_texture()
	
	recenter()

## Pauses when Android moves the app to the background.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_pause_if_playing()
		_set_away(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_set_away(false)

## How long the menu music takes to fade out when the headset comes off.
const AWAY_FADE_SECONDS := 1.0
var _away := false
var _away_fade: Tween
var _away_volume_db := 0.0

## With the headset off (or a system window over the game) the menu's song preview fades out over AWAY_FADE_SECONDS
## and pauses, so it doesn't play to nobody on the battery; it resumes and fades back in when the player returns.
## A song in play pauses on its own (_pause_if_playing).
func _set_away(away: bool) -> void:
	if away == _away:
		return
	_away = away
	var preview := menu.song_preview
	if _away_fade:
		_away_fade.kill()
	if away:
		_away_volume_db = preview.volume_db
		_away_fade = create_tween()
		_away_fade.tween_property(preview, ^"volume_db", -60.0, AWAY_FADE_SECONDS)
		_away_fade.tween_callback(func() -> void: preview.stream_paused = true)
	else:
		preview.stream_paused = false
		_away_fade = create_tween()
		_away_fade.tween_property(preview, ^"volume_db", _away_volume_db, AWAY_FADE_SECONDS)
	print("Menu music %s" % ("paused: player away" if away else "resumed"))

## Pauses the song when the player can no longer see or control the game.
func _pause_if_playing() -> void:
	if gamestate == gamestate_playing and not failing:
		_transition_game_state(gamestate_paused)

func set_background_texture() -> void:
	var environment : Environment = $WorldEnvironment.environment
	var panorama : PanoramaSkyMaterial = environment.sky.sky_material 
	panorama.panorama = load(Settings.background_texture)	
	
## Glow (Settings.glare) only while a song plays or is paused: in the menus it cost about 6 of the 13.9 ms frame
## (measured on the headset) for little to see; the saved setting stays as the player set it.
## Settings.glow_quality Soft and Crisp are LowResGlow, Classic Godot's glow.
## The benchmark sets glow_override to one of Glow to measure each part.
enum Glow { NONE, GODOT, ADJUSTMENTS_ONLY, NEW_VIEWPORTS_ONLY, NEW_WITH_BLUR, NEW }
var glow_override := -1
var low_res_glow: LowResGlow

func _apply_glow() -> void:
	var song := gamestate == gamestate_playing or gamestate == gamestate_paused
	var glow := Glow.NONE
	if glow_override >= 0:
		glow = glow_override
	elif Settings.glare and song:
		glow = Glow.GODOT if Settings.glow_quality == "Classic" else Glow.NEW
	var environment := ($WorldEnvironment as WorldEnvironment).environment
	environment.glow_enabled = glow == Glow.GODOT
	# neutral adjustments: only to measure the internal buffer they share with Godot's glow
	environment.adjustment_enabled = glow == Glow.ADJUSTMENTS_ONLY
	if low_res_glow:
		low_res_glow.stage = glow - Glow.NEW_VIEWPORTS_ONLY + 1 if glow >= Glow.NEW_VIEWPORTS_ONLY else 0

## The scenery shaders' share of Settings.atmosphere (height fog, dust) and the stage smoke; the haze and
## menu lights read it themselves.
func _apply_atmosphere() -> void:
	var eerie := Settings.atmosphere == "Eerie"
	RenderingServer.global_shader_parameter_set(&"atmosphere_eerie", 1.0 if eerie else 0.0)
	event_driver.stage_smoke.apply_atmosphere()

## Sets the 3D view's anti-aliasing to Settings.msaa (it applies to both eyes).
func _apply_msaa() -> void:
	get_viewport().msaa_3d = Settings.msaa_mode()

## Sets the OpenXR render scale to Settings.render_scale() if it differs (the runtime then remakes its eye buffers).
func _apply_render_scale() -> void:
	var openxr := XRServer.find_interface("OpenXR") as OpenXRInterface
	if openxr and openxr.is_initialized() and openxr.render_target_size_multiplier != Settings.render_scale():
		openxr.render_target_size_multiplier = Settings.render_scale()
		print("render scale ", Settings.render_scale())

## Full resolution stutters in busy songs (measured near the 13.9 ms budget): when a song misses more than
## SMOOTH_MISSED_SHARE of its frames for SMOOTH_BAD_SECONDS seconds in a row, the render scale drops to Sharp for
## the rest of the session (Settings.resolution_cap) and the end screen says so. Only the resolution changes:
## lights and effects stay as the player set them.
const SMOOTH_MISSED_SHARE := 0.05
const SMOOTH_BAD_SECONDS := 3
const SMOOTH_FALLBACK := "Sharp"
const LOWERED_TEXT := "Lowered to Sharp to stay smooth"
var _smooth_frames := 0
var _smooth_time := 0.0
var _smooth_bad_seconds := 0
## The resolution was lowered during this song (shown on its end screen).
var _lowered_resolution := false

## Seconds of songs played this session (WarningIcon suggests a break after 30 minutes).
var played_seconds := 0.0

# whether the blades touched last frame (logged when it changes, for matching GPU timings on the headset)
var _clashing := false

## Sparks and a buzz in both controllers while the two blades touch.
func _rumble_on_clash() -> void:
	var touching := false
	var closest := PackedVector3Array()
	if Settings.saber_clash_rumble and left_saber.is_extended() and right_saber.is_extended():
		closest = Geometry3D.get_closest_points_between_segments(left_saber.global_position, left_saber.saber_end,
				right_saber.global_position, right_saber.saber_end)
		touching = closest[0].distance_to(closest[1]) < CLASH_DISTANCE
	if touching:
		left_controller.simple_rumble(CLASH_RUMBLE, 0.05)
		right_controller.simple_rumble(CLASH_RUMBLE, 0.05)
		# the cut sparks (CutFlash.spray), in either blade's colour in turn
		var saber := left_saber if randi() % 2 == 0 else right_saber
		cut_flash.spray(CutFlash.SPRAY_CLASH, (closest[0] + closest[1]) * 0.5, Vector3.UP,
				saber.saber_visual.get_color())
	if touching != _clashing:
		_clashing = touching
		print("saber_clash ", touching)

func _process(delta: float) -> void:
	_rumble_on_clash()
	if gamestate == gamestate_playing:
		played_seconds += delta
	if gamestate != gamestate_playing or Settings.render_scale() <= Settings._resolution_scale(SMOOTH_FALLBACK) \
			or has_node(^"Benchmark"):
		_smooth_frames = 0
		_smooth_time = 0.0
		_smooth_bad_seconds = 0
		return
	_smooth_frames += 1
	_smooth_time += delta
	if _smooth_time < 1.0:
		return
	var expected := _smooth_time * Engine.physics_ticks_per_second
	var missed := 1.0 - _smooth_frames / expected
	_smooth_bad_seconds = _smooth_bad_seconds + 1 if missed > SMOOTH_MISSED_SHARE else 0
	_smooth_frames = 0
	_smooth_time = 0.0
	if _smooth_bad_seconds >= SMOOTH_BAD_SECONDS:
		Settings.resolution_cap = SMOOTH_FALLBACK
		_apply_render_scale()
		_lowered_resolution = true
		print("render scale lowered to %s: missed %d%% of frames for %d s" % [SMOOTH_FALLBACK, int(missed * 100), SMOOTH_BAD_SECONDS])

func on_settings_changed(key: StringName) -> void:
	# ensures proper initialization of tree for proper first frame setting loading
	await get_tree().process_frame
	# the render scale follows the picked resolution (Settings.render_scale)
	# (not while the benchmark sets scales itself)
	if key == &"resolution" and not has_node(^"Benchmark"):
		_apply_render_scale()
	match key:
		&"refresh_90":
			vr.apply_refresh_rate()
		&"left_handed":
			if Settings.left_handed:
				left_ui_raycast.active = true
				right_ui_raycast.active = false
			else:
				left_ui_raycast.active = false
				right_ui_raycast.active = true
		&"color_left":
			update_left_color(Settings.color_left)
			_update_slash_block()
		&"color_right":
			update_right_color(Settings.color_right)
			_update_slash_block()
		&"width":
			event_driver.set_background()
		&"background", &"smoke", &"old_track":
			event_driver.set_background()
		&"background_texture":
			set_background_texture()
			event_driver.set_background_texture()
		&"show_debug_info":
			_show_debug_info()
		&"atmosphere":
			_apply_atmosphere()
		&"glare", &"glow_quality":
			if glow_override < 0:
				LowResGlow.set_quality(Settings.glow_quality)
			_apply_glow()
		&"msaa":
			_apply_msaa()
		&"note_style", &"darker_notes", &"classic_notes":
			_apply_note_style()
		&"environment":
			if gamestate == gamestate_mapselection and _result_moment:
				_switch_stage_in_black()
			else:
				_apply_environment()
		&"player_height_offset":
			if not _height_held:
				xr_origin.transform.origin.y = Constants.view_shift(Settings.player_height_offset)

## Tells the note shaders which look the player picked (the glossy one, 2, unless Classic notes is on), and how
## bright their colours may be.
func _apply_note_style() -> void:
	var style := maxi(Settings.NOTE_STYLES.map(func(s: Array) -> String: return s[0]).find(Settings.note_style), 0)
	if not Settings.classic_notes:
		style = 2
	RenderingServer.global_shader_parameter_set(&"note_style", style)
	RenderingServer.global_shader_parameter_set(&"note_max_value", Settings.NOTE_DARK_VALUE if Settings.darker_notes else 1.0)

## Shows the environment the player picked, or on "Auto" the one for the last map played.
func _apply_environment() -> void:
	event_driver.set_environment(EventDriver.pick_environment(Map.current_info))

## Changes the stage behind a short black fade (STAGE_*), following the latest pick if it changes meanwhile.
func _switch_stage_in_black() -> void:
	if _stage_switching:
		return
	_stage_switching = true
	await _result_moment.fade_out(STAGE_FADE_SECONDS)
	while event_driver.environment != EventDriver.pick_environment(Map.current_info):
		_apply_environment()
		await get_tree().create_timer(STAGE_HOLD_SECONDS).timeout
	_stage_switching = false
	_result_moment.fade_in(STAGE_FADE_SECONDS)

func set_colors_from_settings() -> void:
	# only the menus use the settings' colours: dim the scene so the menu holds the eye
	event_driver.set_menu_focus(true)
	update_left_color(Settings.color_left)
	update_right_color(Settings.color_right)
	event_driver.set_background()

## Plays the sound for a bad cut or wrong saber, or for a bomb hit, from where it happened.
func play_mistake_sound(bomb: bool, at: Vector3) -> void:
	_mistake_player.position = at
	_mistake_player.stream = BOMB_HIT_SOUND if bomb else BAD_CUT_SOUND
	_mistake_player.volume_db = BOMB_GAIN_DB if bomb else 0.0
	_mistake_player.play()

## Plays the soft sound for a note that flew past uncut, from where it was.
func play_miss_sound(at: Vector3) -> void:
	_mistake_player.position = at
	_mistake_player.stream = MISS_SOUND
	_mistake_player.volume_db = MISS_GAIN_DB
	_mistake_player.play()

## Colours walls and bombs with the song's danger colour.
static func _update_danger_color(danger: Color) -> void:
	(DANGER_WALL_MATERIAL as ShaderMaterial).set_shader_parameter(&"danger_color", danger)
	(Wall.FRAMED_MATERIAL as ShaderMaterial).set_shader_parameter(&"danger_color", danger)
	(BOMB_GLOW_MATERIAL as ShaderMaterial).set_shader_parameter(&"danger_color", danger)
	(Bomb.MERGED_MATERIAL as ShaderMaterial).set_shader_parameter(&"danger_color", danger)

func update_left_color(color: Color) -> void:
	if !left_saber:
		await get_tree().process_frame
	left_saber.set_color(color)
	Arc.left_material.set_shader_parameter(&"color", color)
	Arc.left_material_magnet.set_shader_parameter(&"color", color)
	goggles_shader.set_shader_parameter(&"left_color", color)
	event_driver.update_left_color(color)
	RenderingServer.global_shader_parameter_set(&"left_saber_color", color)
	standing_ground.update_left_color(color)

func update_right_color(color: Color) -> void:
	if !left_saber:
		await get_tree().process_frame
	right_saber.set_color(color)
	Arc.right_material.set_shader_parameter(&"color", color)
	Arc.right_material_magnet.set_shader_parameter(&"color", color)
	goggles_shader.set_shader_parameter(&"right_color", color)
	event_driver.update_right_color(color)
	RenderingServer.global_shader_parameter_set(&"right_saber_color", color)
	standing_ground.update_right_color(color)

func _clear_track() -> void:
	# cleared walls don't report the head leaving them
	_in_wall = false
	for c in track.get_children():
		if c.has_method("clear_from_track"):
			c.clear_from_track()
		else:
			track.remove_child(c)
			c.queue_free()

func _on_combo_milestone(_combo: int) -> void:
	event_driver.combo_pulse()
	await get_tree().create_timer(MILESTONE_RUMBLE_DELAY).timeout
	for controller: BeepSaberController in [left_controller, right_controller]:
		controller.simple_rumble(MILESTONE_RUMBLE, MILESTONE_RUMBLE_SECONDS)

func _display_points() -> void:
	if gamestate == gamestate_playing:
		event_driver.set_combo_multiplier(Scoreboard.multiplier)
	var played := 0 if Map.current_info == null else int(get_current_time())
	var length := 0 if Map.current_info == null else int(Map.current_info.get_length_seconds())
	hud.show_points(Scoreboard.points, played, length, Scoreboard.accuracy())

## The menus, panels and keyboards, laid out (in the scene and their constants) for an eye at Hud.HUD_EYE. They move
## with the player's real eye height (owner, 2026-10-27: everything the player looks at is worked out from their own
## eye), so each keeps the angle it was laid out at. The slash note places itself (SlashBlock.set_shown).
const MENU_NODES: Array[NodePath] = [^"MainMenu_OQ_UI2DCanvas", ^"PauseMenu_canvas", ^"Pause_countdown",
	^"Settings_canvas", ^"MapSourceDialogs", ^"Keyboard_online_search", ^"Keyboard_highscore", ^"Profiles_canvas",
	^"EndScore", ^"WarningIcon", ^"MenuClock"]
## how far the menus are raised for the player's eye (Hud.HUD_EYE is 0)
var menu_lift := 0.0
## each menu node's laid-out place
var _menu_rest := {}

## Raises the menus to the player's eye height now (on every game state change, so a menu opens where it's seen).
func _place_menus() -> void:
	menu_lift = _eye().y - Hud.HUD_EYE.y
	for path in MENU_NODES:
		var node := get_node_or_null(path) as Node3D
		if node == null:
			continue
		if not _menu_rest.has(node):
			_menu_rest[node] = node.position
		node.position = _menu_rest[node] + Vector3(0.0, menu_lift, 0.0)

## A transform laid out for Hud.HUD_EYE, raised to the player's eye (for nodes placed in more than one spot).
func lifted(t: Transform3D) -> Transform3D:
	return t.translated(Vector3(0.0, menu_lift, 0.0))

## The player's eye now: the headset's place, or Hud.HUD_EYE while it isn't tracked yet (at the floor's origin).
func _eye() -> Vector3:
	var eye := ($XROrigin3D/XRCamera3D as XRCamera3D).global_position
	return eye if eye.y > 0.5 else Hud.HUD_EYE

## Whole seconds left in the current map, for the clock under the score.
func _seconds_left() -> int:
	if Map.current_info == null:
		return 0
	return maxi(0, int(Map.current_info.get_length_seconds() - get_current_time()))

func _on_PlayerHead_area_entered(area: Area3D) -> void:
	if area.is_in_group(&"wall"):
		song_player.volume_db = -15.0
		_in_wall = true
		Scoreboard.enter_wall()

func _on_PlayerHead_area_exited(area: Area3D) -> void:
	if area.is_in_group(&"wall"):
		song_player.volume_db = 0.0
		_in_wall = false
		Scoreboard.exit_wall()
		
## Song position in song seconds; negative while the lead-in before the song runs.
func get_current_time() -> float:
	if lead_in > 0.0:
		# lead_in counts real seconds, which the Speed modifier stretches
		return -lead_in * Settings.music_speed / 100.
	return song_player.get_playback_position()

# when the song ended we want to display the current score and
# the high score
func _on_song_ended() -> void:
	song_player.stop()
	_new_record = {}
	PlayCount.increment_play_count(Map.current_info,Map.current_difficulty.difficulty_rank)
	
	# a failed song's score stops where it failed, so it isn't a record (it filled the tables with near-zero runs)
	var failed := Settings.health_mode and current_health <= 0
	var new_record := false
	var highscore := Highscores.get_highscore(Map.current_info,Map.current_difficulty.difficulty_rank)
	if highscore == -1:
		# no highscores exist yet
		highscore = Scoreboard.points
	elif Scoreboard.points > highscore and not failed:
		# player's score is the new highscore!
		highscore = Scoreboard.points
		new_record = true

	var current_percent : float
	if failed:
		current_percent = -1
	else:
		current_percent = Scoreboard.accuracy()
		event_driver.result_mood(false)
		_song_end_player.stream = CLEAR_SOUND
		_song_end_player.play()
	print(Scoreboard.summary())
	endscore.show_score(
		Scoreboard.points,
		highscore,
		current_percent,
		"%s By %s\n%s     Map author: %s" % [
			Map.current_info.song_name,
			Map.current_info.song_author_name,
			MapStats.level_name(Map.current_info, Map.current_difficulty),
			Map.current_info.level_author_name],
		Scoreboard.full_combo,
		new_record,
		_failed_at,
		song_player.stream.get_length() if song_player.stream else 0.0
	)
	
	if not failed and Highscores.is_new_highscore(Map.current_info,Map.current_difficulty.difficulty_rank,Scoreboard.points):
		# saved under the current player, picked in the song menu
		_new_record = Highscores.add_highscore(
			Map.current_info,
			Map.current_difficulty.difficulty_rank,
			_default_player_name(),
			Scoreboard.points,
			Scoreboard.accuracy())
		_show_name_card()
		_transition_game_state(gamestate_newhighscore)
	else:
		_show_name_card()
		_transition_game_state(gamestate_mapcomplete)

## The saved player name, or "Player" if it was left empty.
static func _default_player_name() -> String:
	var player_name := Settings.player_name.strip_edges()
	return player_name if not player_name.is_empty() else "Player"

func _restart_button() -> void:
	start_map(Map.current_info, Map.current_difficulty, true)
	endscore.visible = false
	pause_menu.visible = false

func _main_menu_button() -> void:
	_clear_track()
	_transition_game_state(gamestate_mapselection)

## Extends the sabers the current map and handedness setting call for, and sheathes the others.
func show_sabers_for_map() -> void:
	if Settings.handedness == 0:
		if Map.one_saber:
			if Settings.left_handed:
				right_saber._hide()
				left_saber._show()
			else:
				left_saber._hide()
				right_saber._show()
		else:
			right_saber._show()
			left_saber._show()
	elif Settings.handedness == Constants.HANDEDNESS_FORCE_LEFT:
		right_saber._hide()
		left_saber._show()
	elif Settings.handedness == Constants.HANDEDNESS_FORCE_RIGHT:
		right_saber._show()
		left_saber._hide()
	elif Settings.handedness == Constants.HANDEDNESS_IGNORE:
		right_saber._show()
		left_saber._show()

func _unpause_button() -> void:
	pause_menu.visible = false
	# draw the sabers during the countdown so they're out before notes move again
	show_sabers_for_map()
	pause_countdown.visible = true
	track.visible = true
	# a second per number, so "3" means three seconds to get ready
	for seconds in [3, 2, 1]:
		pause_countdown.text = str(seconds)
		play_countdown(seconds)
		await get_tree().create_timer(1.0).timeout
	pause_countdown.visible = false
	play_countdown(0)
	
	# continue game play; a lead-in that was cut short keeps counting in Playing
	if lead_in <= 0.0:
		song_player.play(pause_position)
	_transition_game_state(gamestate_playing)

func _on_BeepSaberMainMenu_difficulty_changed(map_info: MapInfo, diff_rank: int) -> void:
	# the menu loads its playlist in its _ready(), before this node's
	if not menu:
		await ready
	# the ranks sit in the song menu's left panel, under the song
	var ranks := menu.get_node(^"Ranks") as HighscorePanel
	ranks.visible = diff_rank >= 0
	if diff_rank >= 0:
		ranks.load_highscores(map_info, diff_rank)
	var difficulty := menu.picked_difficulty()
	if map_info and difficulty and map_info.have_song:
		_preload(map_info, difficulty)

## Shows the note to slash, in the selected song's colours, while the song menu is open with a song picked and
## nothing (keyboard, "Who's playing?") in front of it.
## Runs the menu benchmark (Benchmark) unless one is running.
func _start_benchmark(mode := "") -> void:
	if has_node(^"Benchmark") or gamestate != gamestate_mapselection:
		return
	var bench := Benchmark.new()
	bench.name = &"Benchmark"
	bench.game = self
	add_child(bench)
	bench.run(mode)

func _update_slash_block() -> void:
	# the menu reports its first song while it loads, before this scene is ready
	if not is_node_ready():
		return
	var difficulty := menu.selected_difficulty()
	if difficulty:
		# the map's colours, or the player's while the Map colors chip is off (Map.note_colors)
		var colors := Map.note_colors(menu.selected_map(), difficulty)
		slash_block.set_note(colors)
		# the sabers take them too, so the player holds the colours the song will play in (owner, 2026-10-27)
		if gamestate == gamestate_mapselection:
			left_saber.set_color(colors[0])
			right_saber.set_color(colors[1])
	slash_block.set_shown(gamestate == gamestate_mapselection and main_menu.visible and not main_menu.disable_collision
			and not highscore_keyboard.visible and menu.has_song_picked())

## Opens "Who's playing?" in front of the song menu; the menu behind takes no pointer input until it closes. The
## view keeps its height until the panel closes (_adjust_height).
func _open_profiles() -> void:
	_height_held = true
	_height_player = Settings.find_player(Settings.player_name)
	profiles_panel.refresh()
	profiles_canvas._show()
	main_menu.disable_collision = true
	_update_slash_block()

## "Not you?" on the score screen (owner, 2026-10-28): "Who's playing?" opens in its place; whoever is picked (or added)
## when it closes becomes the current player and gets this run's record (_close_profiles). A better record that player
## already has on the map stays too: the table keeps both rows.
var _naming_record := false

func _change_record_player() -> void:
	_naming_record = true
	# the score screen and its records stood in front of the list (owner, 2026-10-28): out of the way meanwhile
	endscore._hide()
	highscore_canvas._hide()
	_open_profiles()

## Closes "Who's playing?" and shows the (maybe new) current player's records in the menu, or, opened from the score
## screen, moves this run's record to them.
func _close_profiles() -> void:
	profiles_canvas._hide()
	if _naming_record:
		_naming_record = false
		endscore._show()
		highscore_canvas._show()
		if not _new_record.is_empty() and _new_record.player_name != Settings.player_name:
			Highscores.rename_record(_new_record, Settings.player_name)
		highscore_panel.load_highscores(Map.current_info, Map.current_difficulty.difficulty_rank, _new_record)
		_show_name_card()
	main_menu.disable_collision = false
	menu.update_view()
	_update_slash_block()
	_adjust_height()

## Where "Adjusting height" shows: where "Who's playing?" was, a little nearer.
const HEIGHT_NOTICE_POSITION := Vector3(0.0, 1.6, -0.85)
## The player's Height (Settings.player_height_offset) is held while "Who's playing?" is open, so a new player's
## height doesn't jump the view under them.
var _height_held := false
var _height_notice := Label3D.new()
var _height_notice_back := MeshInstance3D.new()
const HEIGHT_NOTICE_PADDING := 0.03
const HEIGHT_NOTICE_FONT_SIZE := 56
const HEIGHT_NOTICE_PIXEL_SIZE := 0.001
## The notice's countdown digit, in the numbers' font on the notice's last line, as tall as the 56 px digit it replaced.
var _height_digit := Label3D.new()
const HEIGHT_DIGIT_HEIGHT := 0.04
## The current player's Settings.players entry when "Who's playing?" opened (a rename keeps the entry).
var _height_player := {}

const HEIGHT_FADE_SECONDS := 0.2
var _height_fade := MeshInstance3D.new()

## After picking another player: "Adjusting height for <name>" counts 3, 2, 1 with the countdown ticks when their Height
## differs; for a player whose Height was never set (0) it asks them to stand straight and measures it at the end
## (settings Measure). The view then moves to the height behind a short fade to the panel colour.
func _adjust_height() -> void:
	var measure := Settings.player_height_offset == 0.0
	if is_same(Settings.find_player(Settings.player_name), _height_player) or not measure and absf(Constants.view_shift(Settings.player_height_offset) - xr_origin.transform.origin.y) < 0.005:
		_height_held = false
		return
	if not _height_notice.is_inside_tree():
		_height_notice.font_size = HEIGHT_NOTICE_FONT_SIZE
		_height_notice.pixel_size = HEIGHT_NOTICE_PIXEL_SIZE
		_height_notice.outline_size = 12
		_height_notice.modulate = Constants.UI_TEXT
		_height_notice.outline_modulate = Constants.UI_PANEL
		_height_notice.no_depth_test = true
		_height_notice.render_priority = Material.RENDER_PRIORITY_MAX
		_height_notice.position = HEIGHT_NOTICE_POSITION
		add_child(_height_notice)
		var back_material := StandardMaterial3D.new()
		back_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		back_material.no_depth_test = true
		back_material.render_priority = Material.RENDER_PRIORITY_MAX - 1
		back_material.albedo_color = Constants.UI_SURFACE
		_height_notice_back.mesh = QuadMesh.new()
		_height_notice_back.material_override = back_material
		_height_notice.add_child(_height_notice_back)
		_height_digit.font = Hud.NUMBER_FONT
		_height_digit.font_size = COUNTDOWN_FONT_SIZE
		_height_digit.pixel_size = HEIGHT_DIGIT_HEIGHT / (ResultMoment.CAP_SHARE * COUNTDOWN_FONT_SIZE)
		_height_digit.outline_size = COUNTDOWN_OUTLINE_SIZE
		_height_digit.modulate = Constants.UI_TEXT
		_height_digit.outline_modulate = Constants.UI_PANEL
		_height_digit.no_depth_test = true
		_height_digit.render_priority = Material.RENDER_PRIORITY_MAX
		_height_notice.add_child(_height_digit)
	_height_notice.visible = true
	for seconds in [3, 2, 1]:
		# the last line is left blank for the digit
		_height_notice.text = ("Measuring height for %s\nStand straight, look ahead\n " if measure
				else "Adjusting height for %s\n ") % Settings.player_name
		_height_digit.text = str(seconds)
		var font := _height_notice.font if _height_notice.font else ThemeDB.fallback_font
		var lines := _height_notice.text.count("\n") + 1
		_height_digit.position.y = -(lines - 1) * 0.5 * font.get_height(_height_notice.font_size) * _height_notice.pixel_size
		var text_size := font.get_multiline_string_size(_height_notice.text, HORIZONTAL_ALIGNMENT_CENTER, -1,
				_height_notice.font_size) * _height_notice.pixel_size
		(_height_notice_back.mesh as QuadMesh).size = text_size + Vector2.ONE * HEIGHT_NOTICE_PADDING * 2.0
		play_countdown(seconds)
		await get_tree().create_timer(0.5).timeout
	_height_notice.visible = false
	play_countdown(0)
	if measure:
		settings_panel._on_measure_height_pressed()
	await _fade_view(1.0)
	xr_origin.transform.origin.y = Constants.view_shift(Settings.player_height_offset)
	await _fade_view(0.0)
	_height_held = false

## Fades a quad over the eyes to opacity over HEIGHT_FADE_SECONDS.
func _fade_view(opacity: float) -> void:
	if not _height_fade.is_inside_tree():
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		_height_fade.mesh = quad
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.no_depth_test = true
		material.render_priority = Material.RENDER_PRIORITY_MAX
		material.albedo_color = Color(Constants.UI_PANEL, 0.0)
		_height_fade.material_override = material
		_height_fade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_height_fade.position = Vector3(0.0, 0.0, -0.1)
		vr.vrCamera.add_child(_height_fade)
	var material := _height_fade.material_override as StandardMaterial3D
	await create_tween().tween_property(material, "albedo_color:a", opacity, HEIGHT_FADE_SECONDS).finished

func _settings_button() -> void:
	settings_panel._update_backgrounds()
	_transition_game_state(gamestate_settings)

## Starts the body test from the song menu's More tab.
func _body_test_button() -> void:
	_transition_game_state(gamestate_bodytest)

func _on_settings_Panel_apply() -> void:
	set_colors_from_settings()
	_transition_game_state(gamestate_mapselection)

func _on_ScenePool_new_scene_instanced(obj: Node3D, during_presizing: bool) -> void:
	# add obj to the track. it will reside inside the track for eternity, only
	# to be reposition and made visible again when it is acquired and spawned.
	track.add_child(obj)
	
	# make obj visible and wait for a frame to be processed. this tricks
	# shaders to be loaded at startup time.
	if during_presizing:
		obj.position.z = -2.0
		await get_tree().process_frame
		
		if obj is BeepCube:
			obj.hide_cube()
		elif obj is ChainLink:
			obj.hide_cube()
		elif obj.has_method(&"hide_pooled"):
			obj.hide_pooled()
		else:
			obj.visible = false

func recenter():
	var xr_camera := $XROrigin3D/XRCamera3D as XRCamera3D
	xr_origin.rotation.y -= xr_camera.global_rotation.y
	xr_origin.position -= (xr_camera.global_position * Vector3(1,0,1)) - Vector3(0,0,1)

func _set_hand(right: bool, hand: bool) -> void:
	var angle_offset := -45. if hand else 0.
	if right:
		right_saber.second_extra_offset_rot.x=angle_offset
		right_saber._update_size_and_angle()
	else:
		left_saber.second_extra_offset_rot.x=angle_offset
		left_saber._update_size_and_angle()

func _on_right_controller_profile_changed(role: String) -> void:
	if role.ends_with("/simple_controller"):
		_set_hand(true, true)
	else:
		_set_hand(true, false)

func _on_left_controller_profile_changed(role: String) -> void:
	if role.ends_with("/simple_controller"):
		_set_hand(false, true)
	else:
		_set_hand(false, false)

## How long each step of starting a song took, logged once as "START <step> <ms> ... total <ms>" to find what
## freezes the view when a song starts (owner, 2026-10-28), and the frames after it as "START frame <ms>" while
## they run over START_SLOW_FRAME seconds, for START_WATCH_FRAMES frames.
class StartTiming:
	const START_SLOW_FRAME := 0.025
	const START_WATCH_FRAMES := 90
	var _started := Time.get_ticks_usec()
	var _last := _started
	var _line := "START"

	## Notes the time since the last step under `step`.
	func lap(step: String) -> void:
		var now := Time.get_ticks_usec()
		_line += " %s %.1f" % [step, (now - _last) / 1000.0]
		_last = now

	## Prints the steps, then watches the next frames for slow ones.
	func report() -> void:
		print(_line + " total %.1f" % ((_last - _started) / 1000.0))
		var tree := Engine.get_main_loop() as SceneTree
		var before := Time.get_ticks_usec()
		for frame in START_WATCH_FRAMES:
			await tree.process_frame
			var now := Time.get_ticks_usec()
			if now - before > START_SLOW_FRAME * 1e6:
				print("START frame %d %.1f" % [frame, (now - before) / 1000.0])
			before = now
