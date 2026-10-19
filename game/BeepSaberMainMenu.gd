# The main menu is shown at game start or pause on an OQ_UI2DCanvas
# some logic is in the BeepSaber_Game.gd to set the correct state
#
# This file also contains the logic to load a beatmap in the format that
# normal Beat Saber uses. So you can load here custom beat saber songs too
extends Panel
class_name MainMenu

# emitted when a new map difficulty is selected
signal difficulty_changed(map_info: MapInfo, diff_rank: int)
# emitted when the settings button is pressed
signal settings_requested()
signal start_map(info: MapInfo, difficulty: DifficultyInfo, health: bool)

const FAVORITE_MASK := 0x4000000000000000
@export var main_song_player_ref: AudioStreamPlayer
@export var keyboard: OQ_UI2DKeyboard
@export var beepsaber_game : BeepSaber_Game

@export var song_uploader_ref: SongUploader

@onready var playlist_selector := $PlaylistSelector as OptionButton
@onready var nps_filter := $NpsFilter as OptionButton
@onready var length_filter := $LengthFilter as OptionButton
@onready var _bg_img_loader := preload("res://game/scripts/BackgroundImgLoader.gd").new()

@onready var cover := $cover as TextureRect
@onready var songs_menu := $SongsMenu as ItemList
@onready var characteristic_row := $DifficultyPicker/CharacteristicRow as HBoxContainer
@onready var level_row := $DifficultyPicker/LevelRow as HBoxContainer
@onready var level_stats := $DifficultyPicker/LevelStats as Label
@onready var delete_button := $MorePanel/Delete_Button as Button
@onready var fail_row := $FailRow as HBoxContainer
@onready var damage_row := $DamageRow as HBoxContainer
@onready var bombs_control := $ModifiersPanel/Margin/Rows/Toggles/Bombs as CheckButton
@onready var arrows_control := $ModifiersPanel/Margin/Rows/Toggles/Arrows as CheckButton
@onready var flip_control := $ModifiersPanel/Margin/Rows/Flip as OptionButton
@onready var handedness_control := $ModifiersPanel/Margin/Rows/Handedness as OptionButton
@onready var claws_control := $ModifiersPanel/Margin/Rows/Toggles/Claws as CheckButton
@onready var size_control := $ModifiersPanel/Margin/Rows/Size as OptionButton
@onready var width_control := $ModifiersPanel/Margin/Rows/Width as OptionButton
@onready var speed_control := $ModifiersPanel/Margin/Rows/Speed as OptionButton
@onready var favorite_button := $Favorite_Button as Button
@onready var reset_button := $ModifiersPanel/Margin/Rows/Header/Reset_Button as Button

@onready var song_preview := $song_prev as AudioStreamPlayer
var song_preview_transition_time := 1.0
var licenses_showing := false

var current_selected := -1

enum PlaylistOptions {
	AllSongs,
	RecentlyAdded,
	MostPlayed
}

# several different lists of maps, for use with the sort-by bar up top
var _all_songs: Array[MapInfo]
var _recently_added_songs: Array[MapInfo] # newest is first, oldest is last
var _most_played_songs: Array[MapInfo] # most played is first, least played is last
var _currently_selected_songlist_ref: Array[MapInfo] = _all_songs # reference to whichever map list is the currently selected one

# keep a record of all song hashes so we can check if the song is already in our local database
var all_song_hashes: Array[String]
# send a signal whenever the all_song_keys array changes
signal song_list_changed()

# stop the preview player if the main song player is going
func _physics_process(_delta: float) -> void:
	if main_song_player_ref.playing:
		song_preview.stop()

func refresh_playlist() -> void:
	var id := playlist_selector.get_selected_id()
	_on_PlaylistSelector_item_selected(id)

class MapInfoWithSort:
	var num: int
	var info: MapInfo
	
	func _init(n: int, i: MapInfo) -> void:
		num = n
		info = i

func compare(a: MapInfoWithSort, b: MapInfoWithSort) -> bool:
	return a.num > b.num
	
func _sort_songs() -> void:
	var do_map : MapInfo = null
	var do_difficulty := -1
	
	if _currently_selected_songlist_ref != null and current_selected >= 0:
		do_map = _currently_selected_songlist_ref[current_selected]
		do_difficulty = _map_difficulty
			
	var songs_with_modify_times: Array[MapInfoWithSort] = []
	var songs_with_play_count: Array[MapInfoWithSort] = []
	var songs_favorite: Array[MapInfo] = []
	var songs_unfavorite: Array[MapInfo] = []
	for song in _all_songs:
		var song_path := song.filepath
		var modified_time := FileAccess.get_modified_time(song_path)
		var play_count := PlayCount.get_total_play_count(song)
		var favorite := PlayCount.is_favorite(song)
		if favorite:
			modified_time |= FAVORITE_MASK
			play_count |= FAVORITE_MASK
			songs_favorite.append(song)
		else:
			songs_unfavorite.append(song)
		songs_with_modify_times.append(MapInfoWithSort.new(modified_time, song))
		songs_with_play_count.append(MapInfoWithSort.new(play_count, song))
	
	songs_with_modify_times.sort_custom(compare)
	songs_with_play_count.sort_custom(compare)
	_recently_added_songs = []
	_most_played_songs = []
	_all_songs = []
	for song in songs_with_modify_times:
		_recently_added_songs.append(song.info)
	for song in songs_with_play_count:
		_most_played_songs.append(song.info)
	for song in songs_favorite:
		_all_songs.append(song)
	for song in songs_unfavorite:
		_all_songs.append(song)
		
	refresh_playlist()
	if do_map != null:
		for i in range(_currently_selected_songlist_ref.size()):
			if _currently_selected_songlist_ref[i] == do_map:
				#songs_menu.select(i)
				_select_song(i)
				_select_difficulty(do_difficulty)

	if current_selected < 0:
		for i in range(_currently_selected_songlist_ref.size()):
			if _currently_selected_songlist_ref[i].filepath == Settings.last_map:
				songs_menu.select(i)
				_select_song(i)
				break
	
func _load_playlists() -> void:
	#copy sample songs to main playlist folder on first run
	current_selected = -1
	if not Settings.preloaded_songs:
		@warning_ignore("return_value_discarded")
		const maps_path := "res://game/data/maps/"
		var dir := DirAccess.open(maps_path + "Songs/")
		@warning_ignore("return_value_discarded")
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if dir.current_is_dir():
				var new_dir := maps_path+"Songs/"+file_name
				@warning_ignore("return_value_discarded")
				DirAccess.make_dir_recursive_absolute(Constants.APPDATA_PATH+"Songs/"+file_name)
				var copy := DirAccess.open(new_dir)
				@warning_ignore("return_value_discarded")
				copy.list_dir_begin()
				var copy_file_name := copy.get_next()
				while not copy_file_name.is_empty():
					var copy_new_dir := new_dir+"/"+copy_file_name
					@warning_ignore("return_value_discarded")
					dir.copy(copy_new_dir,Constants.APPDATA_PATH+"Songs/"+file_name+"/"+copy_file_name)
					copy_file_name = copy.get_next()
			file_name = dir.get_next()
		Settings.preloaded_songs = true
	
	_discover_all_songs(Constants.APPDATA_PATH+"Songs/")
	
	_sort_songs()
	MapStats.count_all_async(_all_songs, _on_map_stats_counted)
		
	var canvas := get_parent().get_parent()
	if canvas is OQ_UI2DCanvas:
		(canvas as OQ_UI2DCanvas)._input_update()

func _discover_all_songs(seek_path: String) -> void:
	_all_songs.clear()
	all_song_hashes.clear()
	var dir := DirAccess.open(seek_path)
	if dir:
		@warning_ignore("return_value_discarded")
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if dir.current_is_dir() or file_name.to_lower().ends_with(".zip"): 
				var path : String
				if dir.current_is_dir():
					path = seek_path+file_name+"/"
				else:
					path = seek_path+file_name
				var song := Map.load_map_info(path)
				if song:
					_all_songs.append(song)
				# record all hashes, even those that have unsupported versions
				all_song_hashes.append(file_name)
			file_name = dir.get_next()
	emit_signal("song_list_changed")

func _set_cur_playlist(songs: Array[MapInfo]) -> void:
	var current_map : MapInfo
	current_map = null
	if current_selected >= 0:
		current_map = _currently_selected_songlist_ref[current_selected]
	var shown: Array[MapInfo] = []
	for map in songs:
		if _passes_song_filter(map):
			shown.append(map)
	songs = shown
	_currently_selected_songlist_ref = songs
	songs_menu.clear()
	
	var map_index := 0
	for map in songs:
		@warning_ignore("return_value_discarded")
		songs_menu.add_item("%s - %s%s" % [map.song_author_name, map.song_name, "" if map.have_song else " [silent]"], default_song_icon)
		songs_menu.set_item_custom_fg_color(map_index, Color.YELLOW if PlayCount.is_favorite(map) else Color.WHITE)
		_bg_img_loader.load_texture(map.filepath, map.cover_image_filename, _on_cover_loaded, false, map_index)
		map_index += 1
		
	if current_map != null:
		current_selected = -1
		for i in range(songs.size()):
			if songs[i] == current_map:
				songs_menu.select(i)
				_select_song(i)
		if current_selected == -1:
			songs_menu.select(-1)

## True if no song filter is set.
func _song_filter_is_off() -> bool:
	return Settings.song_filter_nps == 0 and Settings.song_filter_length == 0

## True if any difficulty of the map is inside the NPS and length filters. Maps that haven't been
## counted yet pass, so the list never hides songs it knows nothing about.
func _passes_song_filter(map: MapInfo) -> bool:
	if _song_filter_is_off():
		return true
	var nps_range := MapStats.nps_filter()
	var length_range := MapStats.length_filter()
	for diff in map.difficulty_beatmaps:
		var stats := MapStats.get_cached(map, diff)
		if stats.is_empty() or (MapStats.in_filter(float(stats.nps), nps_range) and MapStats.in_filter(float(stats.seconds), length_range)):
			return true
	return false

## Rebuilds the shown song list with the current search text and filters.
func _refilter() -> void:
	if keyboard.is_node_ready():
		_text_input_changed()
	else:
		refresh_playlist()

## Called when the background count of song stats finishes.
func _on_map_stats_counted() -> void:
	if not _song_filter_is_off():
		_refilter()

## Stores the picked NPS filter; on_settings_changed rebuilds the list.
func _on_nps_filter_item_selected(index: int) -> void:
	Settings.song_filter_nps = Constants.NPS_FILTERS[index][0]

## Stores the picked length filter; on_settings_changed rebuilds the list.
func _on_length_filter_item_selected(index: int) -> void:
	Settings.song_filter_length = Constants.LENGTH_FILTERS[index][0]

var default_song_icon := preload("res://game/data/beepsaber_logo.png")

# callback from ImageUtils when background image loading is complete. if image
# failed to load, tex will be null
func _on_cover_loaded(img_tex: Texture2D, is_main_cover: bool, list_idx: int) -> void:
	if img_tex != null:
		if is_main_cover:
			cover.call_deferred("set_texture", img_tex)
		else:
			songs_menu.call_deferred("set_item_icon", list_idx,img_tex)
			#songs_menu.set_item_icon(list_idx,img_tex)

func _load_cover(cover_path: String, filename: String) -> ImageTexture:
	# parse buffer into an ImageTexture
	return ImageTexture.create_from_image(Image.load_from_file(cover_path+filename))

func play_preview(buffer: PackedByteArray, start_time: float = 0.0, duration: float = -1.0, buffer_data_type_hint: String = 'ogg') -> void:
	var stream: AudioStream
	# take song preview data from buffer as-is. trust passed type hint
	if buffer_data_type_hint == 'ogg':
		stream = AudioStreamOggVorbis.load_from_buffer(buffer)
	elif buffer_data_type_hint == 'mp3':
		stream = AudioStreamMP3.new()
		(stream as AudioStreamMP3).data = buffer
	
	if not stream: return
	
	if duration < 0.0:
		# assume preview duration based on parsed audio length
		duration = stream.get_length()
	
	
	# fade out preview if ones already running
	if song_preview.playing:
		await _on_stop_prev_timeout()
	
	# start the requested preview, if still on song select
	if not main_song_player_ref.playing:
		song_preview.stream = stream
		var song_prev_Tween := song_preview.create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		@warning_ignore("return_value_discarded")
		# TODO: is this a good idea with higher speeds?
		song_prev_Tween.tween_property(song_preview, ^"volume_db", 0, song_preview_transition_time)
		song_prev_Tween.play()
		song_preview.play(start_time)
		song_preview.pitch_scale = Settings.music_speed / 100.
		($song_prev/stop_prev as Timer).start(duration)

func _select_song(id: int) -> void:
	current_selected = id 
	if id < 0:
		return
	songs_menu.ensure_current_is_visible()
	delete_button.disabled = false
	favorite_button.show()
	
	var map := _currently_selected_songlist_ref[id]
	($SongInfo_Label as Label).text = "%s\n%s\n\nMapped by %s\nPlayed %d times" % [
		map.song_name,
		map.song_author_name,
		map.level_author_name,
		PlayCount.get_total_play_count(map)
	]
	
	_set_favorite_icon(PlayCount.is_favorite(map))
	
	# load cover in background to avoid freezing UI
	_bg_img_loader.load_texture(map.filepath, map.cover_image_filename, _on_cover_loaded, true, -1)
	
	# preview song
	if Settings.audio_music_preview > 0 and map.have_song:
		play_preview(Utils.read_binary_file(map.filepath, map.song_filename), map.preview_start_time, map.preview_duration)
	
	var d := PlayCount.get_last_difficulty(map)
	_select_difficulty(0 if d < 0 else (d & Constants.DIFFICULTY_MASK))

func _on_stop_prev_timeout() -> void:
	var song_prev_Tween := song_preview.create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	@warning_ignore("return_value_discarded")
	song_prev_Tween.tween_property(song_preview, "volume_db", -50, song_preview_transition_time)
	song_prev_Tween.play()
	await get_tree().create_timer(song_preview_transition_time).timeout
	song_preview.stop()

var _map_difficulty := 0

func _select_difficulty(id: int) -> void:
	_map_difficulty = id
	
	# notify listeners that difficulty has changed
	update_view()


func _load_map_and_start(map: MapInfo) -> void:
	if map.is_empty(): return
	
	var set0 := map.difficulty_beatmaps
	if (set0.size() == 0):
		vr.log_error("No _difficultyBeatmaps in set")
		show_play_error()
		return
	
	var diff_info := set0[_map_difficulty]
	
	start_map.emit(map, diff_info)

func _on_Delete_Button_button_up() -> void:
	if delete_button.text != "Sure?":
		delete_button.text = "Sure?"
		await get_tree().create_timer(5).timeout
		delete_button.text = "Delete"
	else:
		delete_button.text = "Delete"
		_delete_map(_currently_selected_songlist_ref[current_selected])
		current_selected = -1
		update_view()
	
func _delete_map(map: MapInfo) -> void:
	Highscores.remove_map(map)
	PlayCount.remove_map(map)
	
	if not map.filepath.is_empty():
		var dir := DirAccess.open(map.filepath)
		if dir:
			@warning_ignore("return_value_discarded")
			dir.list_dir_begin()
			var current_file := dir.get_next()
			while current_file != "":
				@warning_ignore("return_value_discarded")
				DirAccess.remove_absolute(map.filepath+current_file)
				current_file = dir.get_next()
			@warning_ignore("return_value_discarded")
			DirAccess.remove_absolute(map.filepath)
			delete_button.disabled = true
			favorite_button.hide()
		else:
			DirAccess.remove_absolute(map.filepath)
			delete_button.disabled = true
			favorite_button.hide()
	_on_LoadPlaylists_Button_pressed()
	
func _drop_down(control: OptionButton, list: Array, value: Variant, defaultIndex: int) -> void:
	control.clear()
	var index := defaultIndex
	for i in range(list.size()):
		control.add_item(list[i][1])
		if list[i][0] == value:
			index = i
	control.selected = index
	
func _update_mod_controls() -> void:
	_sync_difficulty_rows()
	arrows_control.button_pressed = Settings.arrows_enabled
	
	_drop_down(flip_control, Constants.FLIPS, Settings.flip, 0)
	_drop_down(handedness_control, Constants.HANDEDNESSES, Settings.handedness, 0)
	_drop_down(width_control, Constants.WIDTHS, Settings.width, 0)
	_drop_down(size_control, Constants.SIZES, Settings.block_size, 1)
	_drop_down(speed_control, Constants.SPEEDS, Settings.music_speed, 1)
	
	bombs_control.button_pressed = Settings.bombs_enabled
	claws_control.button_pressed = Settings.claws

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(Constants.APPDATA_PATH+"Backgrounds/")
	DirAccess.make_dir_recursive_absolute(Constants.APPDATA_PATH+"Songs/")

	Settings.changed.connect(on_settings_changed)
	
	_build_difficulty_rows()
	_build_difficulty_picker()
	_update_mod_controls()
	favorite_button.hide()
	
	UI_AudioEngine.attach_children(self)
	
	playlist_selector.clear()
	playlist_selector.add_item("All Songs")
	playlist_selector.add_item("Recently Added")
	playlist_selector.add_item("Most Played")
	_drop_down(nps_filter, Constants.NPS_FILTERS, Settings.song_filter_nps, 0)
	_drop_down(length_filter, Constants.LENGTH_FILTERS, Settings.song_filter_length, 0)
	
	_load_playlists()
	
	await keyboard.ready
	@warning_ignore("return_value_discarded")
	keyboard.text_input_enter.connect(_text_input_enter)
	@warning_ignore("return_value_discarded")
	keyboard.text_input_cancel.connect(_text_input_cancel)
	@warning_ignore("return_value_discarded")
	keyboard._text_edit.text_changed.connect(_text_input_changed)
	@warning_ignore("return_value_discarded")
	keyboard._text_edit.focus_exited.connect(_text_input_enter)
	
	playlist_selector.select(1)
	playlist_selector.item_selected.emit(1)
	
	if song_uploader_ref and song_uploader_ref.active:
		$MorePanel/upload_url.text = "Manually Upload Songs/Backgrounds: \n%s"%[
			song_uploader_ref.get_server_url()
		]
	else:
		$MorePanel/upload_url.text = ""
	
	$MorePanel/version.text = beepsaber_game.version
	if OS.get_name() == &"Web":
		$MorePanel/Exit_Button.hide()
		
func on_settings_changed(key: StringName) -> void:
	match key:
		&"music_speed":
			song_preview.pitch_scale = Settings.music_speed / 100.
		&"song_filter_nps", &"song_filter_length":
			# the BeatSaver panel shares these filters, so follow changes made there too
			nps_filter.select(MapStats.nps_filter()[0])
			length_filter.select(MapStats.length_filter()[0])
			_refilter()

func difficulty_modifier_changed() -> void:
	pass			

func _on_Play_Button_pressed() -> void:
	if current_selected >= 0:
		var map := _currently_selected_songlist_ref[current_selected]
		Settings.last_map = map.filepath
		song_preview.stop()
		Settings.save()
		var play_button := $Play_Button as Button
		play_button.text = "Loading..."
		play_button.disabled = true
		# loading blocks the main thread, so let the button redraw first
		await get_tree().process_frame
		await get_tree().process_frame
		_load_map_and_start(map)
		play_button.disabled = false
		if play_button.text == "Loading...":
			play_button.text = "Play"

## Tells the player on the Play button that the selected map couldn't be loaded.
func show_play_error() -> void:
	var play_button := $Play_Button as Button
	play_button.text = "Can't load map"
	await get_tree().create_timer(3.0).timeout
	play_button.text = "Play"

func _on_Exit_Button_pressed() -> void:
	get_tree().quit()

func _on_Settings_Button_pressed() -> void:
	settings_requested.emit()

## Shows or hides the modifiers panel over the song details.
func _on_modifiers_button_pressed() -> void:
	_show_side_panel($ModifiersPanel if not $ModifiersPanel.visible else null)

## Shows or hides the panel with the less used actions (refresh, delete, licenses, exit).
func _on_more_button_pressed() -> void:
	_show_side_panel($MorePanel if not $MorePanel.visible else null)

## Shows one panel over the song details (null shows the details) and lights up its footer button.
func _show_side_panel(panel: Panel) -> void:
	$ModifiersPanel.visible = panel == $ModifiersPanel
	$MorePanel.visible = panel == $MorePanel
	$Modifiers_Button.set_pressed_no_signal($ModifiersPanel.visible)
	$More_Button.set_pressed_no_signal($MorePanel.visible)

const READ_PERMISSION = "android.permission.READ_EXTERNAL_STORAGE"

func is_in_array(arr: Array, val: Variant) -> bool:
	for e: Variant in arr:
		if (e == val): return true
	return false
	
func _check_required_permissions() -> bool:
	if not vr.inVR: return true # desktop is always allowed
	
	var permissions := OS.get_granted_permissions()
	var read_storage_permission := is_in_array(permissions, READ_PERMISSION)
	
	vr.log_info(str(permissions))
	
	if not read_storage_permission:
		return false

	return true

func _check_and_request_permission() -> bool:
	vr.log_info("Checking permissions")
	
	if not _check_required_permissions():
		vr.log_info("Requesting permissions")
		OS.request_permissions()
		return false
	else:
		return true


func _on_LoadPlaylists_Button_pressed() -> void:
	# Note: this call is non-blocking; so a user has to click again after
	#       granting the permissions; we need to find a solutio for this
	#       maybe polling after the button press?
	_check_and_request_permission()
	_load_playlists()


func _on_Search_Button_button_up() -> void:
	keyboard._text_edit.placeholder_text = "Search songs"
	keyboard.visible=true
	keyboard._text_edit.grab_focus()

func _text_input_enter(_text:String = "") -> void:
	keyboard.visible=false

func _text_input_cancel() -> void:
	keyboard.visible=false
	_clean_search()

func _text_input_changed() -> void:
	var text := keyboard._text_edit.text
	($Search_Button/Label as Label).text = text
	if text == "":
		_clean_search()
		return
	text = text.to_upper() # ignore case
	var songs_sorted_by_similarity: Array[MapInfoWithSort] = []
	for song in _all_songs:
		# similarity is between 0.0 and 1.0, MapInfoWithSort takes an int,
		# gotta make the number larger else it'll just be 0 or 1 later
		var similarity := song.song_name.to_upper().similarity(text) * 65536.0
		songs_sorted_by_similarity.append(MapInfoWithSort.new(int(similarity), song))
	songs_sorted_by_similarity.sort_custom(compare)
	var songs_sorted: Array[MapInfo] = []
	for song in songs_sorted_by_similarity:
		songs_sorted.append(song.info)
	_set_cur_playlist(songs_sorted)

func _clean_search() -> void:
	_on_PlaylistSelector_item_selected(playlist_selector.get_selected_id())
	($Search_Button/Label as Label).text = ""

func _on_PlaylistSelector_item_selected(id: int) -> void:
	match id:
		PlaylistOptions.AllSongs:
			_set_cur_playlist(_all_songs)
		PlaylistOptions.MostPlayed:
			_set_cur_playlist(_most_played_songs)
		PlaylistOptions.RecentlyAdded:
			_set_cur_playlist(_recently_added_songs)
		_:
			vr.log_warning("Unsupported playlist option %s" % id)
			_set_cur_playlist(_all_songs)

func _on_licenses_pressed() -> void:
	var license := FileAccess.open("res://LICENSE", FileAccess.READ).get_as_text()
	$LicensePopup/ScrollContainer/Label.text = license
	if licenses_showing:
		$LicensePopup.hide()
	else:
		$LicensePopup.show()
	licenses_showing = not licenses_showing
	return
	
func update_view() -> void:
	if current_selected >= 0 and len(_currently_selected_songlist_ref):
		if current_selected >= len(_currently_selected_songlist_ref):
			current_selected = 0
		if _map_difficulty >= len(_currently_selected_songlist_ref[current_selected].difficulty_beatmaps):
			_map_difficulty = 0
		var difficulty := _currently_selected_songlist_ref[current_selected].difficulty_beatmaps[_map_difficulty]
		difficulty_changed.emit(_currently_selected_songlist_ref[current_selected], difficulty.difficulty_rank)
	else:	
		difficulty_changed.emit(null, -1)
	_sync_difficulty_picker()
	_set_reset_icon()

## Fills the fail and damage rows with one toggle button per option, so they're a single press away.
func _build_difficulty_rows() -> void:
	var fail_group := ButtonGroup.new()
	for i in Constants.FAIL_OPTIONS.size():
		fail_row.add_child(_make_row_button(Constants.FAIL_OPTIONS[i][2], fail_group, _on_fail_option_pressed.bind(i)))
	var damage_group := ButtonGroup.new()
	for i in Constants.DAMAGE_SCALES.size():
		damage_row.add_child(_make_row_button(Constants.DAMAGE_SCALES[i][1], damage_group, _on_damage_option_pressed.bind(i)))
	_sync_difficulty_rows()

## Difficulty levels in button order: [difficulty name in the map, button label].
const LEVELS := [["Easy", "Easy"], ["Normal", "Normal"], ["Hard", "Hard"], ["Expert", "Expert"], ["ExpertPlus", "Expert+"]]
## Most characteristic tabs a map can show; BeatSaver has 8 characteristics.
const MAX_CHARACTERISTICS := 8
## Shorter tab labels for characteristics whose names don't fit.
const CHARACTERISTIC_LABELS := {"OneSaber": "1 Saber", "NoArrows": "No Arrows", "360Degree": "360°", "90Degree": "90°"}

## Characteristic of each tab in characteristic_row, in tab order, for the selected map.
var _characteristics: Array[String] = []

## Fills the difficulty picker with one button per level and a pool of characteristic tabs, so nothing scrolls.
func _build_difficulty_picker() -> void:
	var tab_group := ButtonGroup.new()
	for i in MAX_CHARACTERISTICS:
		var tab := _make_row_button("", tab_group, _on_characteristic_pressed.bind(i))
		tab.add_theme_font_size_override(&"font_size", 16)
		tab.clip_text = true
		characteristic_row.add_child(tab)
	var level_group := ButtonGroup.new()
	for i in LEVELS.size():
		var button := _make_row_button(LEVELS[i][1], level_group, _on_level_pressed.bind(i))
		button.add_theme_font_size_override(&"font_size", 18)
		var color: Color = Constants.DIFFICULTY_COLORS.get(LEVELS[i][0], Constants.UI_TEXT)
		for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
			button.add_theme_color_override(state, color)
		level_row.add_child(button)
	_sync_difficulty_picker()

## The characteristic a difficulty belongs to; maps without one are Standard.
func _characteristic_of(diff: DifficultyInfo) -> String:
	return diff.characteristic if diff.characteristic != "" else "Standard"

## Index in difficulty_beatmaps of the given characteristic and level, or -1 when the map lacks it.
func _find_difficulty(map: MapInfo, characteristic: String, level: int) -> int:
	for i in map.difficulty_beatmaps.size():
		var diff := map.difficulty_beatmaps[i]
		if _characteristic_of(diff) == characteristic and diff.difficulty == LEVELS[level][0]:
			return i
	return -1

## Shows the selected map's characteristics (tabs only when there is more than one), its levels and the picked one's stats.
func _sync_difficulty_picker() -> void:
	if level_row.get_child_count() == 0:
		return
	var map: MapInfo = null
	if current_selected >= 0 and current_selected < _currently_selected_songlist_ref.size():
		map = _currently_selected_songlist_ref[current_selected]
	var picked: DifficultyInfo = null
	if map and _map_difficulty >= 0 and _map_difficulty < map.difficulty_beatmaps.size():
		picked = map.difficulty_beatmaps[_map_difficulty]
	_characteristics.clear()
	if map:
		for diff in map.difficulty_beatmaps:
			var characteristic := _characteristic_of(diff)
			if not characteristic in _characteristics and _characteristics.size() < MAX_CHARACTERISTICS:
				_characteristics.append(characteristic)
	for i in MAX_CHARACTERISTICS:
		var tab := characteristic_row.get_child(i) as Button
		tab.visible = i < _characteristics.size() and _characteristics.size() > 1
		if tab.visible:
			tab.text = CHARACTERISTIC_LABELS.get(_characteristics[i], _characteristics[i])
			tab.set_pressed_no_signal(picked != null and _characteristic_of(picked) == _characteristics[i])
	for i in LEVELS.size():
		var button := level_row.get_child(i) as Button
		button.disabled = not picked or _find_difficulty(map, _characteristic_of(picked), i) < 0
		button.set_pressed_no_signal(picked != null and picked.difficulty == LEVELS[i][0])
	if picked:
		level_stats.text = "%s   %s" % [picked.get_display_name(), MapStats.describe(MapStats.get_stats(map, picked))]
		level_stats.add_theme_color_override(&"font_color", Constants.DIFFICULTY_COLORS.get(picked.difficulty, Constants.UI_TEXT))
	else:
		level_stats.text = ""

## Picks the pressed level within the shown characteristic.
func _on_level_pressed(level: int) -> void:
	var map := _currently_selected_songlist_ref[current_selected]
	_select_difficulty(_find_difficulty(map, _characteristic_of(map.difficulty_beatmaps[_map_difficulty]), level))

## Switches characteristic, keeping the closest level the new one has.
func _on_characteristic_pressed(tab: int) -> void:
	var map := _currently_selected_songlist_ref[current_selected]
	var current := LEVELS.map(func(level: Array) -> String: return level[0]).find(map.difficulty_beatmaps[_map_difficulty].difficulty)
	var best := -1
	for level in LEVELS.size():
		var index := _find_difficulty(map, _characteristics[tab], level)
		if index >= 0 and (best < 0 or absi(level - current) < absi(best - current)):
			best = level
	if best >= 0:
		_select_difficulty(_find_difficulty(map, _characteristics[tab], best))

## One option of a button row.
func _make_row_button(text: String, group: ButtonGroup, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override(&"font_size", 20)
	button.pressed.connect(on_pressed)
	return button

## Shows the saved fail mode and damage scale in the rows; damage only matters for the health bar.
func _sync_difficulty_rows() -> void:
	if fail_row.get_child_count() == 0:
		return
	for i in Constants.FAIL_OPTIONS.size():
		var option: Array = Constants.FAIL_OPTIONS[i]
		(fail_row.get_child(i) as Button).set_pressed_no_signal(option[0] == Settings.health_mode and (not Settings.health_mode or option[1] == Settings.fail_mode))
	var damage_counts := Settings.health_mode and Settings.fail_mode == Constants.FAIL_MODE_BAR
	for i in Constants.DAMAGE_SCALES.size():
		var button := damage_row.get_child(i) as Button
		button.set_pressed_no_signal(is_equal_approx(Constants.DAMAGE_SCALES[i][0], Settings.damage_scale))
		button.disabled = not damage_counts

## Stores the picked fail option: No Fail turns health mode off, the others pick how to fail.
func _on_fail_option_pressed(index: int) -> void:
	Settings.health_mode = Constants.FAIL_OPTIONS[index][0]
	Settings.fail_mode = Constants.FAIL_OPTIONS[index][1]
	_sync_difficulty_rows()
	update_view()

## Stores the picked damage scale.
func _on_damage_option_pressed(index: int) -> void:
	Settings.damage_scale = Constants.DAMAGE_SCALES[index][0]
	_sync_difficulty_rows()
	update_view()

func _on_claws_toggled(value: bool) -> void:
	Settings.claws = value
	update_view()

func _on_bombs_toggled(value: bool) -> void:
	Settings.bombs_enabled = value
	update_view()
	
func _on_arrows_toggled(value: bool) -> void:
	Settings.arrows_enabled = value
	update_view()
	
func _are_mods_default() -> bool:
	if not Settings.health_mode or Settings.fail_mode != Constants.FAIL_MODE_BAR or Settings.damage_scale != 1.0 or not Settings.bombs_enabled or not Settings.arrows_enabled:
		return false
	if Settings.claws or Settings.block_size != 100:
		return false
	if Settings.width != 100 or Settings.flip != 0 or Settings.music_speed != 100:
		return false
	if Settings.handedness != 0:
		return false
	return true
	
func _set_reset_icon() -> void:
	if _are_mods_default():
		reset_button.hide()
	else:
		reset_button.text = "\u21BA" 
		reset_button.show()

func _set_favorite_icon(value: bool) -> void:
	favorite_button.text = "\u2605" if value else "\u2606"
	var color := Color.YELLOW if value else Color.WHITE
	favorite_button.add_theme_color_override("font_color", color)
	favorite_button.add_theme_color_override("font_disabled_color", color)
	favorite_button.add_theme_color_override("font_focus_color", color)
	favorite_button.add_theme_color_override("font_hover_color", color)
	favorite_button.add_theme_color_override("font_hover_pressed_color", color)
	favorite_button.add_theme_color_override("font_pressed_color", color)

func _on_favorite_button_pressed() -> void:
	var map := _currently_selected_songlist_ref[current_selected]
	var favorite := not PlayCount.is_favorite(map)
	PlayCount.set_favorite(map, favorite)
	_set_favorite_icon(favorite)
	_sort_songs()
	update_view()
	
func _on_small_toggled(value: bool) -> void:
	Settings.small = value
	update_view()

func _on_width_item_selected(index: int) -> void:
	Settings.width = Constants.WIDTHS[index][0]
	update_view()

func _on_size_item_selected(index: int) -> void:
	Settings.block_size = Constants.SIZES[index][0]
	update_view()

func _on_speed_item_selected(index: int) -> void:
	Settings.music_speed = Constants.SPEEDS[index][0]
	update_view()

func _on_flip_item_selected(index: int) -> void:
	Settings.flip = Constants.FLIPS[index][0]
	update_view()

func _on_handedness_item_selected(index: int) -> void:
	Settings.handedness = Constants.HANDEDNESSES[index][0]
	update_view()

func _on_reset_button_pressed() -> void:
	Settings.health_mode = true
	Settings.fail_mode = Constants.FAIL_MODE_BAR
	Settings.damage_scale = 1.0
	Settings.bombs_enabled = true
	Settings.claws = false
	Settings.block_size = 100
	Settings.width = 100 
	Settings.flip = 0
	Settings.music_speed = 100
	Settings.handedness = 0
	_update_mod_controls()
	update_view()

	pass # Replace with function body.
