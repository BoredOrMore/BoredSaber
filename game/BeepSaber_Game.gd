# This is a stand-alone version of the demo game Beep Saber. It started (and is still included)
# in the godot oculus quest toolkit (https://github.com/NeoSpark314/godot_oculus_quest_toolkit)
# But this stand-alone version as additional features and will be developed independently
# This file contains the main game logic for the BeepSaber demo implementation
extends Node3D
class_name BeepSaber_Game

var version : String = ProjectSettings.get_setting("application/config/version", "0.0.0")
var gamestate_bootup := GameState.new()
var gamestate_mapcomplete := GameStateMapComplete.new()
var gamestate_mapselection := GameStateMapSelection.new()
var gamestate_newhighscore := GameStateNewHighScore.new()
var gamestate_paused := GameStatePaused.new()
var gamestate_playing := GameStatePlaying.new()
var gamestate_settings := GameStateSettings.new()
var gamestate_bodytest := GameStateBodyTest.new()

## Where the record table stands in the song menu: 53 degrees left of the player (eyes at (0, 1.6, 1)), 1.6 m away and
## facing them, its inner edge just clear of the menu panel's (37 degrees). Scale 1.5: text 1.5 degrees.
const HIGHSCORES_MENU_TRANSFORM := Transform3D(
	Basis(Vector3(0.90272, 0, -1.19795), Vector3(0, 1.5, 0), Vector3(1.19795, 0, 0.90272)),
	Vector3(-1.27782, 1.5, 0.0371))
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
@onready var pause_countdown := $Pause_countdown as OQ_UI2DLabel
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

@onready var cube_template := preload("res://game/BeepCube/BeepCube.tscn").instantiate() as BeepCube

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
# seconds left before the song starts, so the first notes can fly in; counted down by Playing
var lead_in := 0.0

const FAIL_SECONDS := 1.5
# the high score saved at the end of the last song
var _new_record := {}
## The song menu showed the record table when the BeatSaver page opened over it.
var _menu_highscores_shown := false
const DANGER_WALL_MATERIAL := preload("res://game/Wall/danger_wall.tres")
## Mistake sounds (tools/make_hit_sounds.py): a dull buzz for a bad cut or the wrong saber, a boom for a bomb.
## A miss gets a soft swipe (tools/make_feedback_sounds.py), quieter than a bad cut.
const BAD_CUT_SOUND := preload("res://game/data/bad_cut.wav")
const BOMB_HIT_SOUND := preload("res://game/data/bomb_hit.wav")
const MISS_SOUND := preload("res://game/data/miss.wav")
var _mistake_player: AudioStreamPlayer
## Song-end and danger sounds: the saber ignition reversed into a low thump for a fail (tools/make_fail_sound.py),
## a rising chord for a cleared song and a heartbeat that loops while health is low (tools/make_feedback_sounds.py).
const FAIL_SOUND := preload("res://game/data/fail.wav")
const CLEAR_SOUND := preload("res://game/data/clear.wav")
const LOW_HEALTH_SOUND := preload("res://game/data/low_health.wav")
## Health at or below this share of the bar plays the heartbeat; in 4 Lives mode that is the last life.
const LOW_HEALTH_FRACTION := 0.25
var _song_end_player: AudioStreamPlayer
var _low_health_player: AudioStreamPlayer
const BOMB_GLOW_MATERIAL := preload("res://game/Bomb/bomb_glow.tres")
# how long a rumble that was on when the song failed takes to fade out
const FAIL_RUMBLE_FADE_SECONDS := 0.6
# a combo milestone buzzes both controllers once, after the cut's own rumble has passed (untuned)
const MILESTONE_RUMBLE := 0.4
const MILESTONE_RUMBLE_SECONDS := 0.12
const MILESTONE_RUMBLE_DELAY := 0.12
# true while the "Failed" moment plays, before the score screen
var failing := false

func start_map(info: MapInfo, map_difficulty: DifficultyInfo) -> void:
	var map_data := Utils.binary_to_json(Utils.read_binary_file(info.filepath, map_difficulty.beatmap_filename))
	
	if (map_data.is_empty()):
		vr.log_error("Could not read map data from " + info.filepath + "/" + map_difficulty.beatmap_filename)
	if not Map.load_beatmap(info, map_difficulty, map_data):
		menu.show_play_error()
		return
		
	event_driver.set_environment(EventDriver.pick_environment(info))
	# for reading GPU timings on the headset by environment
	print("Song starts in environment %s, smoke %s, debug_view %d" % [event_driver.environment, Settings.smoke, DebugView.flags])
	print("song_info %s | %s | speed %d" % [info.song_name, MapStats.level_name(info, map_difficulty), Settings.music_speed])
	event_driver.set_background_texture()
	
	event_driver.set_menu_focus(false)
	update_left_color(Map.color_left)
	update_right_color(Map.color_right)
	_update_danger_color(Map.color_obstacle)
	event_driver.set_background()
	
	# the show starts in the dark (EventDriver.SHOW_BLACKOUT_SECONDS); a map with its own light show turns
	# lights on at its first event, one without gets them all on after the blackout
	event_driver.set_all_off()
	if Map.event_stack.is_empty():
		get_tree().create_timer(EventDriver.SHOW_BLACKOUT_SECONDS).timeout.connect(func() -> void:
			if gamestate == gamestate_playing or gamestate == gamestate_paused:
				event_driver.set_all_on(Map.color_left, Map.color_right)
		)
	
	var filename := info.filepath + info.song_filename
	vr.log_info("loading: " + filename)
	if FileAccess.file_exists(filename):
		song_player.stream = AudioStreamOggVorbis.load_from_file(filename)
	else:
		var audio_data : PackedByteArray
		audio_data = Utils.read_binary_file(info.filepath, info.song_filename)
		if len(audio_data) > 0:
			song_player.stream = AudioStreamOggVorbis.load_from_buffer(audio_data)
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
	
	_audio_synced_after_restart = false
	song_player.stop()
	lead_in = maxf(LEAD_IN_MIN_SECONDS, Map.half_jump_beats / Map.beats_per_second())
	song_player.volume_db = 0.0
	song_player.pitch_scale = Settings.music_speed / 100.
	_in_wall = false
	Scoreboard.restart()
	
	_display_points()
	percent_indicator.start_map()
	if Settings.health_mode:
		current_health = Constants.HEALTH_START if Settings.fail_mode == Constants.FAIL_MODE_BAR else Constants.HEALTH_MAX
		health_rails.start_map(Settings.fail_mode == Constants.FAIL_MODE_LIVES, current_health / Constants.HEALTH_MAX)
	
	_clear_track()
	_transition_game_state(gamestate_playing)

## Changes health by delta in the health bar mode. mistake is a miss, bad cut, bomb or wall
## entry, which costs a life in 4 Lives mode and ends the song in Instant Fail mode.
func update_health(delta: float, mistake: bool = false) -> void:
	if Settings.health_mode:
		match Settings.fail_mode:
			Constants.FAIL_MODE_LIVES:
				if mistake:
					current_health -= Constants.HEALTH_MAX / Constants.FAIL_LIVES
			Constants.FAIL_MODE_INSTANT:
				if mistake:
					current_health = 0.0
			_:
				current_health += delta * Settings.damage_scale if delta < 0.0 else delta
		if current_health > Constants.HEALTH_MAX:
			current_health = Constants.HEALTH_MAX
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

## Shows "Failed" while the song winds down and the track freezes, then the score screen.
func _fail_song() -> void:
	failing = true
	Scoreboard.paused = true
	_update_low_health_sound()
	_song_end_player.stream = FAIL_SOUND
	_song_end_player.play()
	left_saber.set_swingcast_enabled(false)
	right_saber.set_swingcast_enabled(false)
	pause_countdown.set_label_text("Failed")
	pause_countdown.visible = true
	var tw := create_tween().set_parallel()
	# the frozen wall that failed the song would otherwise keep the controllers buzzing
	_in_wall = false
	for controller: BeepSaberController in [left_controller, right_controller]:
		var from := controller.get_rumble_intensity()
		if from > 0.0:
			tw.tween_method(func(amount: float) -> void: controller.simple_rumble(amount, 0.05), from, 0.0, FAIL_RUMBLE_FADE_SECONDS)
	tw.tween_property(song_player, ^"pitch_scale", 0.3, FAIL_SECONDS)
	tw.tween_property(song_player, ^"volume_db", -30.0, FAIL_SECONDS)
	await tw.finished
	pause_countdown.visible = false
	failing = false
	_on_song_ended()
			
# This function will transitioning the game from it's current state into
# the provided 'next_state'.
func _transition_game_state(next_state: GameState) -> void:
	gamestate = next_state
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
func _open_beatsaver() -> void:
	_menu_highscores_shown = highscore_canvas.visible
	main_menu._hide()
	highscore_canvas._hide()
	# the song menu's keyboard sits where the BeatSaver one opens
	highscore_keyboard._hide()
	beatsaver_canvas._show()

## Brings the song menu back once the BeatSaver page closes in the song menu.
func _on_beatsaver_visibility_changed() -> void:
	if not beatsaver_canvas.visible and gamestate == gamestate_mapselection:
		online_search_keyboard._hide()
		main_menu._show()
		if _menu_highscores_shown:
			highscore_canvas._show()
		# the BeatSaver preview stops; the selected song's preview comes back
		menu.play_selected_preview(0.0, true)

## The card under the score: who this run's record was saved as, or the map's best when this run didn't make the board.
func _show_name_card() -> void:
	var records := Highscores.get_records(Map.current_info,
		HighscoreTable.get_rank_key(Map.current_difficulty.difficulty_rank))
	if not _new_record.is_empty():
		endscore.show_name_card("Saved as %s" % _new_record.player_name)
	elif not records.is_empty():
		endscore.show_name_card("Best on this map: %d by %s" % [records[0].score, records[0].player_name])
	else:
		endscore.hide_name_card()

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

func _ready() -> void:
	_mistake_player = AudioStreamPlayer.new()
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
		right_controller
	)
	
	vr.pose_recentered.connect(recenter)
	# OpenXRInterface emits these when the headset comes off or a system window takes focus
	if vr.xr_interface and vr.xr_interface.has_signal(&"session_visible"):
		vr.xr_interface.connect(&"session_visible", _pause_if_playing)
		vr.xr_interface.connect(&"session_stopping", _pause_if_playing)

	_show_debug_info()
	set_colors_from_settings()
	($WorldEnvironment as WorldEnvironment).environment.glow_enabled = Settings.glare
	_apply_note_style()
	_apply_environment()
	# the scenery shaders tint their own shadows (game/env/shadow_tone.gdshaderinc)
	RenderingServer.global_shader_parameter_set(&"shadow_tint", Constants.SHADOW_TINT)
	
	if not vr.inVR:
		xr_origin.add_child(preload("res://OQ_Toolkit/OQ_ARVROrigin/Feature_VRSimulator.tscn").instantiate())
	
	UI_AudioEngine.attach_children(highscore_keyboard)
	slash_block.sabers = [left_saber, right_saber]
	highscore_keyboard.visibility_changed.connect(_update_slash_block)
	main_menu.visibility_changed.connect(_update_slash_block)
	UI_AudioEngine.attach_children(online_search_keyboard)
	beatsaver_canvas.visibility_changed.connect(_on_beatsaver_visibility_changed)
	
	_transition_game_state(gamestate_mapselection)
	
	@warning_ignore("return_value_discarded")
	Scoreboard.score_changed.connect(_display_points)
	(multiplier_label as ComboHud).milestone_reached.connect(_on_combo_milestone)
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

## Pauses the song when the player can no longer see or control the game.
func _pause_if_playing() -> void:
	if gamestate == gamestate_playing and not failing:
		_transition_game_state(gamestate_paused)

func set_background_texture() -> void:
	var environment : Environment = $WorldEnvironment.environment
	var panorama : PanoramaSkyMaterial = environment.sky.sky_material 
	panorama.panorama = load(Settings.background_texture)	
	
func on_settings_changed(key: StringName) -> void:
	# ensures proper initialization of tree for proper first frame setting loading
	await get_tree().process_frame
	match key:
		&"left_handed":
			if Settings.left_handed:
				left_ui_raycast.active = true
				right_ui_raycast.active = false
			else:
				left_ui_raycast.active = false
				right_ui_raycast.active = true
		&"color_left":
			update_left_color(Settings.color_left)
		&"color_right":
			update_right_color(Settings.color_right)
		&"width":
			event_driver.set_background()
		&"background", &"smoke":
			event_driver.set_background()
		&"background_texture":
			set_background_texture()
			event_driver.set_background_texture()
		&"show_debug_info":
			_show_debug_info()
		&"glare":
			($WorldEnvironment as WorldEnvironment).environment.glow_enabled = Settings.glare
		&"note_style", &"darker_notes":
			_apply_note_style()
		&"environment":
			_apply_environment()
		&"player_height_offset":
			xr_origin.transform.origin.y = Settings.player_height_offset

## Tells the note shaders which look the player picked, and how bright their colours may be.
func _apply_note_style() -> void:
	var style := maxi(Settings.NOTE_STYLES.map(func(s: Array) -> String: return s[0]).find(Settings.note_style), 0)
	RenderingServer.global_shader_parameter_set(&"note_style", style)
	RenderingServer.global_shader_parameter_set(&"note_max_value", Settings.NOTE_DARK_VALUE if Settings.darker_notes else 1.0)

## Shows the environment the player picked, or on "Auto" the one for the last map played.
func _apply_environment() -> void:
	event_driver.set_environment(EventDriver.pick_environment(Map.current_info))

func set_colors_from_settings() -> void:
	# only the menus use the settings' colours: dim the scene so the menu holds the eye
	event_driver.set_menu_focus(true)
	update_left_color(Settings.color_left)
	update_right_color(Settings.color_right)
	event_driver.set_background()

## Plays the sound for a bad cut or wrong saber, or for a bomb hit.
func play_mistake_sound(bomb: bool) -> void:
	_mistake_player.stream = BOMB_HIT_SOUND if bomb else BAD_CUT_SOUND
	_mistake_player.play()

## Plays the soft sound for a note that flew past uncut.
func play_miss_sound() -> void:
	_mistake_player.stream = MISS_SOUND
	_mistake_player.play()

## Colours walls and bombs with the song's danger colour.
static func _update_danger_color(danger: Color) -> void:
	(DANGER_WALL_MATERIAL as ShaderMaterial).set_shader_parameter(&"danger_color", danger)
	(BOMB_GLOW_MATERIAL as ShaderMaterial).set_shader_parameter(&"danger_color", danger)

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
	var seconds_left := _seconds_left()
	@warning_ignore("integer_division")
	var display = "Score %6d\n%02d:%02d" % [Scoreboard.points,seconds_left / 60,seconds_left % 60]
	if (point_label.mesh as TextMesh).text != display:
		(point_label.mesh as TextMesh).text = display
	percent_indicator.update_percent(Scoreboard.accuracy())

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
	
	var new_record := false
	var highscore := Highscores.get_highscore(Map.current_info,Map.current_difficulty.difficulty_rank)
	if highscore == -1:
		# no highscores exist yet
		highscore = Scoreboard.points
	elif Scoreboard.points > highscore:
		# player's score is the new highscore!
		highscore = Scoreboard.points
		new_record = true

	var current_percent : float
	if Settings.health_mode and current_health <= 0:
		current_percent = -1
	else:
		current_percent = Scoreboard.accuracy()
		_song_end_player.stream = CLEAR_SOUND
		_song_end_player.play()
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
		new_record
	)
	
	if Highscores.is_new_highscore(Map.current_info,Map.current_difficulty.difficulty_rank,Scoreboard.points):
		# saved under the current player, picked in the song menu
		_new_record = Highscores.add_highscore(
			Map.current_info,
			Map.current_difficulty.difficulty_rank,
			_default_player_name(),
			Scoreboard.points)
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
	start_map(Map.current_info, Map.current_difficulty)
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
	pause_countdown.set_label_text("3")
	await get_tree().create_timer(0.5).timeout
	pause_countdown.set_label_text("2")
	await get_tree().create_timer(0.5).timeout
	pause_countdown.set_label_text("1")
	await get_tree().create_timer(0.5).timeout
	pause_countdown.visible = false
	
	# continue game play; a lead-in that was cut short keeps counting in Playing
	if lead_in <= 0.0:
		song_player.play(pause_position)
	_transition_game_state(gamestate_playing)

func _on_BeepSaberMainMenu_difficulty_changed(map_info: MapInfo, diff_rank: int) -> void:
	if diff_rank < 0:
		if highscore_canvas:
			highscore_canvas.hide()
		return
		
	# menu loads playlist in _ready(), must yield until scene is loaded
	if not highscore_canvas:
		await self.ready
	
	highscore_canvas.transform = HIGHSCORES_MENU_TRANSFORM
	highscore_canvas._show()
	highscore_panel.load_highscores(map_info,diff_rank)

## Shows the note to slash, in the selected song's colours, while the song menu is open with a song picked and
## nothing (keyboard, "Who's playing?") in front of it.
func _update_slash_block() -> void:
	# the menu reports its first song while it loads, before this scene is ready
	if not is_node_ready():
		return
	var difficulty := menu.selected_difficulty()
	if difficulty:
		slash_block.set_note(Map.note_colors(menu.selected_map(), difficulty))
	slash_block.set_shown(gamestate == gamestate_mapselection and main_menu.visible and not main_menu.disable_collision
			and not highscore_keyboard.visible and menu.has_song_picked())

## Opens "Who's playing?" in front of the song menu; the menu behind takes no pointer input until it closes.
func _open_profiles() -> void:
	profiles_panel.refresh()
	profiles_canvas._show()
	main_menu.disable_collision = true
	_update_slash_block()

## Closes "Who's playing?" and shows the (maybe new) current player's records in the menu.
func _close_profiles() -> void:
	profiles_canvas._hide()
	main_menu.disable_collision = false
	menu.update_view()
	_update_slash_block()

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
