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

@onready var main_menu := $MainMenu_OQ_UI2DCanvas as OQ_UI2DCanvas
@onready var pause_menu := $PauseMenu_canvas as OQ_UI2DCanvas
@onready var pause_countdown := $Pause_countdown as OQ_UI2DLabel
@onready var settings_canvas := $Settings_canvas as OQ_UI2DCanvas
@onready var settings_panel := settings_canvas.ui_control as SettingsPanel
@onready var highscore_canvas := $Highscores_Canvas as OQ_UI2DCanvas
@onready var highscore_panel := highscore_canvas.ui_control as HighscorePanel
@onready var name_selector_canvas := $NameSelector_Canvas as OQ_UI2DCanvas
@onready var highscore_keyboard := $Keyboard_highscore as OQ_UI2DKeyboard
@onready var endscore := $EndScore as EndScore

@onready var points_label_driver := $Points_label_driver as PointsLabelDriver
@onready var event_driver := $event_driver as EventDriver

@onready var multiplier_label := $Multiplier_Label as MeshInstance3D
@onready var point_label := $Point_Label as MeshInstance3D
@onready var percent_indicator := $Percent_Indicator as PercentIndicator

@onready var map_source_dialogs := $MapSourceDialogs as Node3D
@onready var online_search_keyboard := $Keyboard_online_search as OQ_UI2DKeyboard

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
# the high score saved at the end of the last song, so the player can rename it
var _new_record := {}
const DANGER_WALL_MATERIAL := preload("res://game/Wall/danger_wall.tres")
const BOMB_GLOW_MATERIAL := preload("res://game/Bomb/bomb_glow.tres")
# how long a rumble that was on when the song failed takes to fade out
const FAIL_RUMBLE_FADE_SECONDS := 0.6
# true while the "Failed" moment plays, before the score screen
var failing := false

func start_map(info: MapInfo, map_difficulty: DifficultyInfo) -> void:
	var map_data := Utils.binary_to_json(Utils.read_binary_file(info.filepath, map_difficulty.beatmap_filename))
	
	if (map_data.is_empty()):
		vr.log_error("Could not read map data from " + info.filepath + "/" + map_difficulty.beatmap_filename)
	if not Map.load_beatmap(info, map_difficulty, map_data):
		menu.show_play_error()
		return
		
	event_driver.set_background_texture()
	
	update_left_color(Map.color_left)
	update_right_color(Map.color_right)
	_update_danger_color(Map.color_left, Map.color_right)
	event_driver.set_background()
	
	if Map.event_stack.is_empty():
		event_driver.set_all_on(Map.color_left, Map.color_right)
	else:
		event_driver.set_all_off()
	
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
	percent_indicator.set_health_mode(Settings.health_mode)
	if Settings.health_mode:
		current_health = Constants.HEALTH_START if Settings.fail_mode == Constants.FAIL_MODE_BAR else Constants.HEALTH_MAX
		percent_indicator.update_percent(current_health / Constants.HEALTH_MAX)
	
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
		percent_indicator.update_percent(current_health / Constants.HEALTH_MAX)
		if current_health <= 0 and gamestate == gamestate_playing and not failing:
			_fail_song()

## Shows "Failed" while the song winds down and the track freezes, then the score screen.
func _fail_song() -> void:
	failing = true
	Scoreboard.paused = true
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
	gamestate._ready(self)

func show_MapSourceDialogs(showing: bool = true) -> void:
	map_source_dialogs.visible = showing
	for c in map_source_dialogs.get_children():
		if c is OQ_UI2DCanvas:
			(c as OQ_UI2DCanvas)._hide()
	if showing:
		var first_dialog := map_source_dialogs.get_child(0)
		if first_dialog is OQ_UI2DCanvas:
			(first_dialog as OQ_UI2DCanvas)._show()

# call this method to submit a new highscore to the database
## Renames the record that was saved under the default name, and makes the name the new default.
func _submit_highscore(player_name: String) -> void:
	player_name = player_name.strip_edges()
	if gamestate == gamestate_newhighscore and not player_name.is_empty():
		Highscores.rename_record(_new_record, player_name)
		Settings.player_name = player_name
		_transition_game_state(gamestate_mapcomplete)

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

	debug_info_label.visible = Settings.show_debug_info
	set_colors_from_settings()
	($WorldEnvironment as WorldEnvironment).environment.glow_enabled = Settings.glare
	($WorldEnvironment as WorldEnvironment).environment.adjustment_color_correction = _make_shadow_tint_lut()
	
	if not vr.inVR:
		xr_origin.add_child(preload("res://OQ_Toolkit/OQ_ARVROrigin/Feature_VRSimulator.tscn").instantiate())
	
	UI_AudioEngine.attach_children(highscore_keyboard)
	UI_AudioEngine.attach_children(online_search_keyboard)
	
	_transition_game_state(gamestate_mapselection)
	
	@warning_ignore("return_value_discarded")
	Scoreboard.score_changed.connect(_display_points)
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

## Builds the colour-correction LUT that tints the dark end of the scene towards Constants.SHADOW_TINT.
## Highlights and mid-tones (note and saber colours) pass through unchanged.
static func _make_shadow_tint_lut() -> ImageTexture3D:
	var n := Constants.SHADOW_TINT_LUT_SIZE
	var slices: Array[Image] = []
	for b in n:
		var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
		for g in n:
			for r in n:
				var c := Color(r / (n - 1.0), g / (n - 1.0), b / (n - 1.0))
				var luma := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
				var weight := 1.0 - smoothstep(0.0, Constants.SHADOW_TINT_FADE_LUMA, luma)
				img.set_pixel(r, g, Color(c.r + Constants.SHADOW_TINT.r * weight,
						c.g + Constants.SHADOW_TINT.g * weight, c.b + Constants.SHADOW_TINT.b * weight))
		slices.append(img)
	var lut := ImageTexture3D.new()
	lut.create(Image.FORMAT_RGB8, n, n, n, false, slices)
	return lut

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
		&"background":
			event_driver.set_background()
		&"background_texture":
			set_background_texture()
			event_driver.set_background_texture()
		&"show_debug_info":
			debug_info_label.visible = Settings.show_debug_info
		&"glare":
			($WorldEnvironment as WorldEnvironment).environment.glow_enabled = Settings.glare
		&"player_height_offset":
			xr_origin.transform.origin.y = Settings.player_height_offset

func set_colors_from_settings() -> void:
	update_left_color(Settings.color_left)
	update_right_color(Settings.color_right)
	event_driver.set_background()

## Colours walls and bombs with the danger colour that stands apart from both note colours.
static func _update_danger_color(left: Color, right: Color) -> void:
	var danger := pick_danger_color(left, right)
	(DANGER_WALL_MATERIAL as ShaderMaterial).set_shader_parameter(&"danger_color", danger)
	(BOMB_GLOW_MATERIAL as ShaderMaterial).set_shader_parameter(&"danger_color", danger)

## The first of Constants.DANGER_COLORS if its hue is far enough from both note colours,
## otherwise the candidate whose hue is farthest from the nearer of the two.
static func pick_danger_color(left: Color, right: Color) -> Color:
	var best: Color = Constants.DANGER_COLORS[0]
	var best_gap := -1.0
	for candidate: Color in Constants.DANGER_COLORS:
		var gap := minf(_hue_gap(candidate, left), _hue_gap(candidate, right))
		if candidate == Constants.DANGER_COLORS[0] and gap >= Constants.DANGER_MIN_HUE_GAP:
			return candidate
		if gap > best_gap:
			best_gap = gap
			best = candidate
	return best

## Distance between two hues around the colour wheel, 0 to 0.5.
static func _hue_gap(a: Color, b: Color) -> float:
	var gap := absf(a.h - b.h)
	return minf(gap, 1.0 - gap)

func update_left_color(color: Color) -> void:
	if !left_saber:
		await get_tree().process_frame
	left_saber.set_color(color)
	Arc.left_material.set_shader_parameter(&"color", color)
	Arc.left_material_magnet.set_shader_parameter(&"color", color)
	goggles_shader.set_shader_parameter(&"left_color", color)
	event_driver.update_left_color(color)
	standing_ground.update_left_color(color)

func update_right_color(color: Color) -> void:
	if !left_saber:
		await get_tree().process_frame
	right_saber.set_color(color)
	Arc.right_material.set_shader_parameter(&"color", color)
	Arc.right_material_magnet.set_shader_parameter(&"color", color)
	goggles_shader.set_shader_parameter(&"right_color", color)
	event_driver.update_right_color(color)
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

func _display_points() -> void:
	var hit_rate: float
	if Scoreboard.right_notes+Scoreboard.wrong_notes > 0:
		hit_rate = Scoreboard.right_notes/(Scoreboard.right_notes+Scoreboard.wrong_notes)
	else:
		hit_rate = 1.0
	
	var seconds_left := _seconds_left()
	@warning_ignore("integer_division")
	var display = "Score %6d\n%02d:%02d" % [Scoreboard.points,seconds_left / 60,seconds_left % 60]
	if (point_label.mesh as TextMesh).text != display:
		(point_label.mesh as TextMesh).text = display
	display = "x %d\nCombo %d" % [Scoreboard.multiplier, Scoreboard.combo]
	if (multiplier_label.mesh as TextMesh).text != display:
		(multiplier_label.mesh as TextMesh).text = display
	if not Settings.health_mode:
		percent_indicator.update_percent(hit_rate)

## Whole seconds left in the current map, for the clock under the score.
func _seconds_left() -> int:
	if Map.current_info == null:
		return 0
	return maxi(0, int(Map.current_info.get_length_seconds() - get_current_time()))

# accessor method for the player name selector UI element
func _name_selector() -> NameSelector:
	return name_selector_canvas.ui_control

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
		current_percent = Scoreboard.right_notes/(Scoreboard.right_notes+Scoreboard.wrong_notes) 
	endscore.show_score(
		Scoreboard.points,
		highscore,
		current_percent,
		"%s By %s\n%s     Map author: %s" % [
			Map.current_info.song_name,
			Map.current_info.song_author_name,
			Map.current_difficulty.get_display_name(),
			Map.current_info.level_author_name],
		Scoreboard.full_combo,
		new_record
	)
	
	if Highscores.is_new_highscore(Map.current_info,Map.current_difficulty.difficulty_rank,Scoreboard.points):
		# save right away under the default name, so nobody is stuck picking a name;
		# the score screen still offers to change it
		_new_record = Highscores.add_highscore(
			Map.current_info,
			Map.current_difficulty.difficulty_rank,
			_default_player_name(),
			Scoreboard.points)
		_transition_game_state(gamestate_newhighscore)
	else:
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
	
	highscore_canvas._show()
	highscore_panel.load_highscores(map_info,diff_rank)

func _settings_button() -> void:
	settings_panel._update_backgrounds()
	_transition_game_state(gamestate_settings)

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
