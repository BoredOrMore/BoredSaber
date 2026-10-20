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
## The player wants to download songs: the BeatSaver page opens in place of the menu.
signal get_songs_requested()
signal start_map(info: MapInfo, difficulty: DifficultyInfo, health: bool)

const FAVORITE_MASK := 0x4000000000000000
const STAR_ICON := preload("res://game/ui/icons/star.svg")
const STAR_FILLED_ICON := preload("res://game/ui/icons/star-filled.svg")
@export var main_song_player_ref: AudioStreamPlayer
@export var keyboard: OQ_UI2DKeyboard
@export var beepsaber_game : BeepSaber_Game

@export var song_uploader_ref: SongUploader

@onready var playlist_selector := $PlaylistSelector as OptionButton
@onready var reaction_filter := $ReactionFilter as OptionButton
@onready var favorites_filter := $FavoritesFilter as Button
@onready var workout_filter := $WorkoutFilter as Button
@onready var length_filter := $LengthFilter as OptionButton
@onready var filter_status := $FilterStatus as Label
@onready var clear_filters_button := $ClearFilters_Button as Button
@onready var empty_list_label := $EmptyList as Label
@onready var _bg_img_loader := preload("res://game/scripts/BackgroundImgLoader.gd").new()

@onready var cover := $cover as TextureRect
@onready var songs_menu := $SongsMenu as ItemList
@onready var characteristic_row := $DifficultyPicker/CharacteristicRow as HBoxContainer
@onready var level_row := $DifficultyPicker/LevelRow as HBoxContainer
@onready var level_stats := $DifficultyPicker/LevelStats as Label
@onready var delete_button := $MorePanel/Delete_Button as ConfirmButton
@onready var fail_row := $FailRow as HBoxContainer
@onready var damage_row := $DamageRow as HBoxContainer
@onready var environment_row := $EnvironmentRow as HBoxContainer
var environment_picker: OptionButton
@onready var bombs_control := $ModifiersPanel/Margin/Rows/Toggles/Bombs as CheckButton
@onready var arrows_control := $ModifiersPanel/Margin/Rows/Toggles/Arrows as CheckButton
@onready var flip_control := $ModifiersPanel/Margin/Rows/Flip as OptionButton
@onready var handedness_control := $ModifiersPanel/Margin/Rows/Handedness as OptionButton
@onready var claws_control := $ModifiersPanel/Margin/Rows/Toggles/Claws as CheckButton
@onready var size_control := $ModifiersPanel/Margin/Rows/Size as OptionButton
@onready var width_control := $ModifiersPanel/Margin/Rows/Width as OptionButton
@onready var speed_control := $ModifiersPanel/Margin/Rows/Speed as OptionButton
@onready var favorite_button := $Favorite_Button as Button
@onready var player_name_button := $PlayerName_Button as Button
@onready var reset_button := $ModifiersPanel/Margin/Rows/ResetRow/Reset_Button as Button

@onready var song_preview := $song_prev as AudioStreamPlayer
var song_preview_transition_time := 1.0
var licenses_showing := false

var current_selected := -1
## The song in the details panel. It stays there after a favorites-only list drops it, so the star can be undone.
var _shown_map: MapInfo

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
	
## Song to keep selected when the song list is reloaded, such as after a download.
var _reselect_path := ""
## Difficulty to keep selected with _reselect_path.
var _reselect_difficulty := -1
## True once the song list has been loaded; only the first load plays the selected song's preview.
var _songs_loaded := false

func _sort_songs() -> void:
	var do_path := _reselect_path
	var do_difficulty := _reselect_difficulty
	_reselect_path = ""
	
	if _currently_selected_songlist_ref != null and current_selected >= 0:
		do_path = _currently_selected_songlist_ref[current_selected].filepath
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
	# reselecting the same song keeps whatever preview is playing (maybe a BeatSaver one fading out)
	if not do_path.is_empty():
		for i in range(_currently_selected_songlist_ref.size()):
			if _currently_selected_songlist_ref[i].filepath == do_path:
				songs_menu.select(i)
				_select_song(i, false)
				_select_difficulty(do_difficulty)
				break

	if current_selected < 0:
		for i in range(_currently_selected_songlist_ref.size()):
			if _currently_selected_songlist_ref[i].filepath == Settings.last_map:
				songs_menu.select(i)
				_select_song(i, not _songs_loaded)
				break
	_songs_loaded = true
	
func _load_playlists() -> void:
	#copy sample songs to main playlist folder on first run
	if _currently_selected_songlist_ref != null and current_selected >= 0:
		_reselect_path = _currently_selected_songlist_ref[current_selected].filepath
		_reselect_difficulty = _map_difficulty
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
		Settings.save()
	
	_discover_all_songs(Constants.APPDATA_PATH+"Songs/")
	SongTags.look_up_missing(self, _all_songs, _show_environment)
	
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
	var filter := SongFilter.saved()
	var shown: Array[MapInfo] = []
	for map in songs:
		if filter.passes(map):
			shown.append(map)
	_show_filter_counts(filter, songs, shown.size())
	songs = shown
	_currently_selected_songlist_ref = songs
	songs_menu.clear()
	_list_generation += 1
	
	var map_index := 0
	for map in songs:
		@warning_ignore("return_value_discarded")
		var favorite := PlayCount.is_favorite(map)
		songs_menu.add_item("%s%s - %s%s" % ["\u2605 " if favorite else "", map.song_author_name, map.song_name, "" if map.have_song else NO_MUSIC_SUFFIX], default_song_icon)
		songs_menu.set_item_custom_fg_color(map_index, Color.YELLOW if favorite else Color.WHITE)
		_bg_img_loader.load_texture(map.filepath, map.cover_image_filename, _on_cover_loaded.bind(_list_generation), false, map_index)
		map_index += 1
		
	if current_map != null:
		current_selected = -1
		for i in range(songs.size()):
			if songs[i] == current_map:
				songs_menu.select(i)
				# same song as before: keep whatever preview is playing (maybe a BeatSaver one)
				_select_song(i, false)
		if current_selected == -1:
			songs_menu.deselect_all()
	_update_play_button()

## One set of song list filters, so the counts can try a choice without saving it.
class SongFilter:
	## Difficulty filter id (MapStats.difficulty_filters).
	var reaction := 0
	## Length filter id (Constants.LENGTH_FILTERS).
	var length := 0
	var favorites := false
	var workout := false

	## The filters as saved in Settings.
	static func saved() -> SongFilter:
		var filter := SongFilter.new()
		filter.reaction = MapStats.difficulty_filter(Settings.song_filter_reaction)
		filter.length = Settings.song_filter_length
		filter.favorites = Settings.song_filter_favorites
		filter.workout = Settings.song_filter_workout
		return filter

	## A copy to change one choice of.
	func copy() -> SongFilter:
		var filter := SongFilter.new()
		filter.reaction = reaction
		filter.length = length
		filter.favorites = favorites
		filter.workout = workout
		return filter

	## True when every filter is off.
	func is_off() -> bool:
		return reaction == 0 and length == 0 and not favorites and not workout

	## False for non-favorites when only favorites are shown. Otherwise true if any difficulty of the map is
	## playable (MapStats.is_unplayable), at the picked level or easier (MapStats.level_of), inside the length
	## filter and, when only workouts are shown, has a set of wall moves (MapStats.workout_level). Maps that
	## haven't been counted yet pass, so the list never hides songs it knows nothing about.
	func passes(map: MapInfo) -> bool:
		if favorites and not PlayCount.is_favorite(map):
			return false
		var length_range := MapStats.length_filter(length)
		for diff in map.difficulty_beatmaps:
			var stats := MapStats.get_cached(map, diff)
			if not MapStats.is_unplayable(stats) \
					and MapStats.passes_difficulty_filter(MapStats.level_of(map, diff, stats), reaction) \
					and (stats.is_empty() or MapStats.in_filter(float(stats.seconds), length_range)) \
					and (not workout or stats.is_empty() or MapStats.workout_level(stats) > 0):
				return true
		return false

	## How many of the songs pass.
	func count(songs: Array[MapInfo]) -> int:
		var passing := 0
		for map in songs:
			if passes(map):
				passing += 1
		return passing

## After the name of a song whose music file is missing (it plays without sound).
const NO_MUSIC_SUFFIX := " (no music)"
## A filter choice with how many songs it would list, e.g. "Up to Hard (18)".
const FILTER_COUNT_LABEL := "%s (%d)"
const FAVORITES_LABEL := "Favorites"
const WORKOUT_LABEL := "Workout"
## Status above the list while filters hide songs; with none it only gives the total (SONG_TOTAL_TEXT).
## The %s is "song" or "songs" (SONG_NOUNS), following the total.
const FILTER_STATUS_TEXT := "Showing %d of %d %s"
const SONG_TOTAL_TEXT := "%d %s"
const SONG_NOUNS := ["song", "songs"]
## Status while searching, shorter so the search text fits: shown of total, then the text.
const SEARCH_FILTER_STATUS_TEXT := "%d of %d %s"
const SEARCH_STATUS_TEXT := " · \"%s\""
const NO_MATCH_TEXT := "No songs match these filters."
const NO_SONGS_TEXT := "No songs yet.\nGet more songs below."

## Puts next to each filter choice how many of the songs (the playlist, or the search matches) it would list with
## the other filters as they are, greys out
## choices that would list none (so the list can't be filtered empty), and says above the list how many songs
## are shown, what the search is, and how to clear both. Faceted filters that show counts, the active
## filters and one clear action keep a list from emptying without a reason (NN/g, "Filters vs. Facets";
## Baymard Institute, product list filtering).
func _show_filter_counts(filter: SongFilter, songs: Array[MapInfo], shown: int) -> void:
	var difficulties := MapStats.difficulty_filters()
	for i in reaction_filter.item_count:
		var choice := filter.copy()
		choice.reaction = difficulties[i][0]
		_show_choice_count(reaction_filter, i, difficulties[i][1], choice.count(songs))
	for i in length_filter.item_count:
		var choice := filter.copy()
		choice.length = Constants.LENGTH_FILTERS[i][0]
		_show_choice_count(length_filter, i, Constants.LENGTH_FILTERS[i][1], choice.count(songs))
	# the dropdown shows the picked choice without its count, which the status row gives
	reaction_filter.text = difficulties[reaction_filter.selected][1]
	length_filter.text = Constants.LENGTH_FILTERS[length_filter.selected][1]
	var favorites := filter.copy()
	favorites.favorites = true
	_show_toggle_count(favorites_filter, FAVORITES_LABEL, favorites.count(songs))
	var workout := filter.copy()
	workout.workout = true
	_show_toggle_count(workout_filter, WORKOUT_LABEL, workout.count(songs))

	var total := _all_songs.size()
	var noun: String = SONG_NOUNS[0] if total == 1 else SONG_NOUNS[1]
	var status := SONG_TOTAL_TEXT % [total, noun]
	if not filter.is_off() or not _search_text.is_empty():
		status = (FILTER_STATUS_TEXT if _search_text.is_empty() else SEARCH_FILTER_STATUS_TEXT) % [shown, total, noun]
	if not _search_text.is_empty():
		status += SEARCH_STATUS_TEXT % _search_text
	filter_status.text = status
	clear_filters_button.visible = not filter.is_off() or not _search_text.is_empty()
	empty_list_label.visible = shown == 0
	empty_list_label.text = NO_SONGS_TEXT if total == 0 else NO_MATCH_TEXT

## Shows a dropdown choice with its song count, greyed out at none unless it is the picked one.
func _show_choice_count(control: OptionButton, index: int, label: String, count: int) -> void:
	control.set_item_text(index, FILTER_COUNT_LABEL % [label, count])
	control.set_item_disabled(index, count == 0 and index != control.selected)

## Shows a filter toggle with how many songs it lists when on, greyed out at none unless it is on.
func _show_toggle_count(toggle: Button, label: String, count: int) -> void:
	toggle.text = FILTER_COUNT_LABEL % [label, count]
	toggle.disabled = count == 0 and not toggle.button_pressed

## Turns every filter off and clears the search, from the status row's Clear filters.
func _clear_filters() -> void:
	Settings.song_filter_reaction = 0
	Settings.song_filter_length = 0
	Settings.song_filter_favorites = false
	Settings.song_filter_workout = false
	_clean_search()

## Rebuilds the shown song list with the current search text and filters.
func _refilter() -> void:
	if keyboard.is_node_ready():
		_apply_search(_search_text)
	else:
		refresh_playlist()

## Called when the background count of song stats finishes.
func _on_map_stats_counted() -> void:
	# unplayable difficulties are left out whatever the filters
	_refilter()

## Stores the picked reaction time filter; on_settings_changed rebuilds the list.
func _on_reaction_filter_item_selected(index: int) -> void:
	Settings.song_filter_reaction = index

## Stores whether only favorite songs are listed; on_settings_changed rebuilds the list.
func _on_favorites_filter_toggled(on: bool) -> void:
	Settings.song_filter_favorites = on

## Stores whether only songs with a wall workout are listed; on_settings_changed rebuilds the list.
func _on_workout_filter_toggled(on: bool) -> void:
	Settings.song_filter_workout = on

## Stores the picked length filter; on_settings_changed rebuilds the list.
func _on_length_filter_item_selected(index: int) -> void:
	Settings.song_filter_length = Constants.LENGTH_FILTERS[index][0]

var default_song_icon := preload("res://game/data/beepsaber_logo.png")

## Bumped every time the song list is rebuilt, so covers still loading for an older list are dropped.
var _list_generation := 0

# callback from ImageUtils when background image loading is complete. if image
# failed to load, tex will be null
func _on_cover_loaded(img_tex: Texture2D, is_main_cover: bool, list_idx: int, generation := -1) -> void:
	if img_tex != null:
		if is_main_cover:
			cover.call_deferred("set_texture", img_tex)
		else:
			_set_list_cover.call_deferred(list_idx, img_tex, generation)

## Puts a loaded cover on its row, unless the list was rebuilt since the load started (the row may be
## another song now, or gone).
func _set_list_cover(list_idx: int, img_tex: Texture2D, generation: int) -> void:
	if generation == _list_generation and list_idx < songs_menu.item_count:
		songs_menu.set_item_icon(list_idx, img_tex)

## Bumped by every preview request, so only the newest one plays after the fade-out awaits.
var _preview_generation := 0

## The score screen plays the song's preview quietly, about 30% loudness, as background (20 * log10(0.3) dB).
const SCORE_SCREEN_PREVIEW_DB := -10.5

## Plays the selected song's preview, fading in to volume_db, so the menus never fall silent after a song (as in Beat
## Saber); if a preview already plays, only fades it to that volume.
func play_selected_preview(volume_db := 0.0, restart := false) -> void:
	if current_selected < 0 or current_selected >= _currently_selected_songlist_ref.size() or Settings.audio_music_preview <= 0:
		return
	var map := _currently_selected_songlist_ref[current_selected]
	if not map.have_song:
		return
	if song_preview.playing and not restart:
		song_preview.create_tween().tween_property(song_preview, ^"volume_db", volume_db, song_preview_transition_time)
		return
	play_preview(Utils.read_binary_file(map.filepath, map.song_filename), map.preview_start_time, map.preview_duration,
		'ogg', volume_db)

func play_preview(buffer: PackedByteArray, start_time: float = 0.0, duration: float = -1.0, buffer_data_type_hint: String = 'ogg', volume_db: float = 0.0) -> void:
	_preview_generation += 1
	var generation := _preview_generation
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
	if generation != _preview_generation:
		return
	
	# start the requested preview, if still on song select
	if not main_song_player_ref.playing:
		song_preview.stream = stream
		var song_prev_Tween := song_preview.create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		@warning_ignore("return_value_discarded")
		# TODO: is this a good idea with higher speeds?
		song_prev_Tween.tween_property(song_preview, ^"volume_db", volume_db, song_preview_transition_time)
		song_prev_Tween.play()
		song_preview.play(start_time)
		song_preview.pitch_scale = Settings.music_speed / 100.
		($song_prev/stop_prev as Timer).start(duration)
		_loop_start = start_time
		_loop_duration = duration
		_loop_volume_db = volume_db

func _select_song(id: int, with_preview: bool = true) -> void:
	current_selected = id 
	if id < 0:
		return
	songs_menu.ensure_current_is_visible()
	delete_button.disabled = false
	favorite_button.show()
	
	var map := _currently_selected_songlist_ref[id]
	var song_name := map.song_name if map.song_name.length() <= DELETE_NAME_CHARS else map.song_name.left(DELETE_NAME_CHARS - 1) + "…"
	delete_button.cancel()
	delete_button.question = "Delete %s?\nIts scores too · press again" % song_name
	_shown_map = map
	($SongInfo_Label as Label).text = "%s\n%s\nMapped by %s\nPlayed %d times" % [
		map.song_name,
		map.song_author_name,
		map.level_author_name,
		PlayCount.get_total_play_count(map)
	]
	
	_set_favorite_icon(PlayCount.is_favorite(map))
	_show_environment()
	
	# load cover in background to avoid freezing UI
	_bg_img_loader.load_texture(map.filepath, map.cover_image_filename, _on_cover_loaded, true, -1)
	
	# preview song
	if with_preview and Settings.audio_music_preview > 0 and map.have_song:
		play_preview(Utils.read_binary_file(map.filepath, map.song_filename), map.preview_start_time, map.preview_duration)
	
	var d := PlayCount.get_last_difficulty(map)
	_select_difficulty(0 if d < 0 else (d & Constants.DIFFICULTY_MASK))

## Fades out the playing preview and drops any preview still waiting to start.
func stop_preview() -> void:
	_preview_generation += 1
	await _on_stop_prev_timeout()

## Seconds of quiet between the end of a preview and its next loop, and how fast Play fades it out.
const PREVIEW_LOOP_GAP := 0.5
const PLAY_FADE_SECONDS := 0.3
## the playing preview's start, length and volume, to loop it
var _loop_start := 0.0
var _loop_duration := 0.0
var _loop_volume_db := 0.0

## The preview reached its end: fade it out, then play it again from its start after a short gap, as long as nothing
## else took over (another preview, a song), so the song select never falls silent.
func _on_preview_ended() -> void:
	var generation := _preview_generation
	await _on_stop_prev_timeout()
	await get_tree().create_timer(PREVIEW_LOOP_GAP).timeout
	if generation != _preview_generation or main_song_player_ref.playing or song_preview.playing or song_preview.stream == null:
		return
	song_preview.volume_db = -50
	song_preview.play(_loop_start)
	song_preview.create_tween().tween_property(song_preview, ^"volume_db", _loop_volume_db, song_preview_transition_time)
	($song_prev/stop_prev as Timer).start(_loop_duration)

## Fades out the preview over seconds (the usual transition when below 0) and stops it, unless a newer one started.
func _on_stop_prev_timeout(seconds := -1.0) -> void:
	if seconds < 0.0:
		seconds = song_preview_transition_time
	var generation := _preview_generation
	var song_prev_Tween := song_preview.create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	@warning_ignore("return_value_discarded")
	song_prev_Tween.tween_property(song_preview, "volume_db", -50, seconds)
	song_prev_Tween.play()
	await get_tree().create_timer(seconds).timeout
	# a newer preview has started meanwhile; leave it playing
	if generation == _preview_generation:
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

## Longest song name the delete question shows before cutting it short.
const DELETE_NAME_CHARS := 18

## Deletes the picked song once the player pressed Delete twice (ConfirmButton).
func _on_delete_confirmed() -> void:
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
	_build_environment_row()
	_build_difficulty_picker()
	_build_tabs()
	_show_player_name()
	_update_mod_controls()
	favorite_button.hide()
	
	UI_AudioEngine.attach_children(self)
	
	playlist_selector.clear()
	playlist_selector.add_item("All Songs")
	playlist_selector.add_item("Recently Added")
	playlist_selector.add_item("Most Played")
	_drop_down(reaction_filter, MapStats.difficulty_filters(), MapStats.difficulty_filter(Settings.song_filter_reaction), 0)
	_drop_down(length_filter, Constants.LENGTH_FILTERS, Settings.song_filter_length, 0)
	favorites_filter.set_pressed_no_signal(Settings.song_filter_favorites)
	workout_filter.set_pressed_no_signal(Settings.song_filter_workout)
	
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
		$MorePanel/upload_url.text = "Add songs from a computer:\n%s" % song_uploader_ref.get_server_url()
	else:
		$MorePanel/upload_url.text = ""
	
	$MorePanel/version.text = beepsaber_game.version
	if OS.get_name() == &"Web":
		$MorePanel/Exit_Button.hide()
		
func on_settings_changed(key: StringName) -> void:
	match key:
		&"player_name":
			_show_player_name()
		&"music_speed":
			song_preview.pitch_scale = Settings.music_speed / 100.
			# reaction times depend on the Speed modifier
			if MapStats.difficulty_filter(Settings.song_filter_reaction) != 0:
				_refilter()
		&"environment":
			_show_environment()
		&"song_filter_reaction", &"song_filter_length":
			reaction_filter.select(MapStats.difficulty_filter(Settings.song_filter_reaction))
			length_filter.select(MapStats.length_filter(Settings.song_filter_length)[0])
			_refilter()
		&"song_filter_favorites":
			favorites_filter.set_pressed_no_signal(Settings.song_filter_favorites)
			_refilter()
		&"song_filter_workout":
			workout_filter.set_pressed_no_signal(Settings.song_filter_workout)
			_refilter()

func _on_Play_Button_pressed() -> void:
	if current_selected >= 0:
		var map := _currently_selected_songlist_ref[current_selected]
		Settings.last_map = map.filepath
		_preview_generation += 1
		_on_stop_prev_timeout(PLAY_FADE_SECONDS)
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
			play_button.text = PLAY_TEXT

## Play button text while a song is picked, and while none is, when the button is off.
const PLAY_TEXT := "Play"
const NO_SONG_TEXT := "Pick a song"

## Turns Play off, saying why, while no song is picked.
func _update_play_button() -> void:
	var play_button := $Play_Button as Button
	var picked := current_selected >= 0 and current_selected < _currently_selected_songlist_ref.size()
	play_button.disabled = not picked
	if not picked:
		play_button.text = NO_SONG_TEXT
	elif play_button.text == NO_SONG_TEXT:
		play_button.text = PLAY_TEXT

## Tells the player on the Play button that the selected map couldn't be loaded.
func show_play_error() -> void:
	var play_button := $Play_Button as Button
	play_button.text = "Can't load map"
	await get_tree().create_timer(3.0).timeout
	play_button.text = PLAY_TEXT

func _on_Exit_Button_pressed() -> void:
	get_tree().quit()

## Tabs above the right column, in order. Settings is not one: it opens its own screen, so it is the gear
## button beside them (a control looks like what it does).
enum Tab { SONG, MODIFIERS, MORE }
const TAB_LABELS := ["Song", "Modifiers", "More"]

## Fills the tab row; Song shows the details, the others a panel above Play.
func _build_tabs() -> void:
	var group := ButtonGroup.new()
	for i in TAB_LABELS.size():
		$Tabs.add_child(_make_row_button(TAB_LABELS[i], group, _on_tab_pressed.bind(i)))
	_show_tab(Tab.SONG)

func _on_tab_pressed(tab: int) -> void:
	_show_tab(tab)

## Opens the settings screen from the gear button.
func _on_settings_button_pressed() -> void:
	settings_requested.emit()

## Shows the tab's panel over the song details (Song shows the details) and lights up its tab.
func _show_tab(tab: int) -> void:
	$ModifiersPanel.visible = tab == Tab.MODIFIERS
	$MorePanel.visible = tab == Tab.MORE
	for i in $Tabs.get_child_count():
		($Tabs.get_child(i) as Button).set_pressed_no_signal(i == tab)

## Asks the game to open the BeatSaver page.
func _on_get_songs_pressed() -> void:
	get_songs_requested.emit()

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


## Picks a downloaded song (by its folder name) in the list, clearing the search and filters first if they hide
## it. False if the song isn't loaded.
func show_song(folder_name: String) -> bool:
	var path := Constants.APPDATA_PATH + "Songs/" + folder_name + "/"
	if _shown_index(path) < 0:
		_clear_filters()
	var index := _shown_index(path)
	if index < 0:
		return false
	songs_menu.select(index)
	_select_song(index)
	return true

## Index of a song in the shown list by its path, or -1.
func _shown_index(path: String) -> int:
	for i in _currently_selected_songlist_ref.size():
		if _currently_selected_songlist_ref[i].filepath == path:
			return i
	return -1

func _on_LoadPlaylists_Button_pressed() -> void:
	# Note: this call is non-blocking; so a user has to click again after
	#       granting the permissions; we need to find a solutio for this
	#       maybe polling after the button press?
	_check_and_request_permission()
	_load_playlists()


## The shared keyboard is typing a song search.
const KEYBOARD_SEARCH := &"search"
## The shared keyboard is typing the player name.
const KEYBOARD_NAME := &"name"
## What the shared keyboard is open for here; empty when it was opened elsewhere (the new-record name).
var _keyboard_for := &""
## The text the song list is sorted by, shown in the status row above it; empty when not searching.
var _search_text := ""

func _on_Search_Button_button_up() -> void:
	_keyboard_for = KEYBOARD_SEARCH
	keyboard._text_edit.placeholder_text = "Search songs"
	keyboard.visible=true
	keyboard._text_edit.grab_focus()

## Opens the keyboard with the current player name, which new records are saved under.
func _on_PlayerName_Button_pressed() -> void:
	_keyboard_for = KEYBOARD_NAME
	keyboard._text_edit.placeholder_text = "Type your name"
	keyboard._text_edit.text = Settings.player_name
	keyboard._text_edit.set_caret_column(Settings.player_name.length())
	keyboard._on_TextEdit_text_changed()
	keyboard.visible=true
	keyboard._text_edit.grab_focus()

## Shows the name new records are saved under.
func _show_player_name() -> void:
	player_name_button.text = BeepSaber_Game._default_player_name()

func _text_input_enter(text:String = "") -> void:
	if _keyboard_for == KEYBOARD_NAME and not text.strip_edges().is_empty():
		Settings.player_name = text.strip_edges()
	_keyboard_for = &""
	keyboard.visible=false

func _text_input_cancel() -> void:
	var was_searching := _keyboard_for == KEYBOARD_SEARCH
	_keyboard_for = &""
	keyboard.visible=false
	if was_searching:
		_clean_search()

func _text_input_changed() -> void:
	if _keyboard_for != KEYBOARD_SEARCH:
		return
	_apply_search(keyboard._text_edit.text)

## Lists the songs whose title, artist or mapper contains the search text, closest title first, like the
## BeatSaver page's search; the playlist when the text is empty.
func _apply_search(text: String) -> void:
	_search_text = text
	if text == "":
		_clean_search()
		return
	text = text.to_upper() # ignore case
	var songs_sorted_by_similarity: Array[MapInfoWithSort] = []
	for song in _all_songs:
		if not (song.song_name + "\n" + song.song_author_name + "\n" + song.level_author_name).to_upper().contains(text):
			continue
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
	_search_text = ""
	if keyboard.is_node_ready() and not keyboard._text_edit.text.is_empty():
		keyboard._text_edit.text = ""
	_on_PlaylistSelector_item_selected(playlist_selector.get_selected_id())

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
	_update_play_button()
	_set_reset_icon()

## Fills the fail and damage rows with one toggle button per option, so they're a single press away;
## the damage row starts with a "Damage" label.
func _build_difficulty_rows() -> void:
	var fail_group := ButtonGroup.new()
	for i in Constants.FAIL_OPTIONS.size():
		fail_row.add_child(_make_row_button(Constants.FAIL_OPTIONS[i][2], fail_group, _on_fail_option_pressed.bind(i)))
	var damage_label := Label.new()
	damage_label.text = "Damage"
	damage_label.add_theme_font_size_override(&"font_size", 24)
	damage_label.custom_minimum_size.x = 130
	damage_row.add_child(damage_label)
	var damage_group := ButtonGroup.new()
	for i in Constants.DAMAGE_SCALES.size():
		damage_row.add_child(_make_row_button(Constants.DAMAGE_SCALES[i][1], damage_group, _on_damage_option_pressed.bind(i)))
	_sync_difficulty_rows()

## A small picture of each environment, by id, shown in the environment dropdown when the file exists.
const ENVIRONMENT_THUMBS := "res://game/env/thumbs/%s.png"
## how wide the pictures show in the open list, and on the closed dropdown, which must stay one row high
const ENVIRONMENT_THUMB_WIDTH := 128
const ENVIRONMENT_THUMB_WIDTH_CLOSED := 48

## The environment picker beside the song: a "Environment" label and a dropdown of Settings.ENVIRONMENTS.
func _build_environment_row() -> void:
	var label := Label.new()
	label.text = "Environment"
	label.add_theme_font_size_override(&"font_size", 24)
	label.custom_minimum_size.x = 150
	environment_row.add_child(label)
	environment_picker = OptionButton.new()
	environment_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	environment_picker.add_theme_font_size_override(&"font_size", 24)
	environment_picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	environment_picker.get_popup().add_theme_font_size_override(&"font_size", 24)
	environment_picker.add_theme_constant_override(&"icon_max_width", ENVIRONMENT_THUMB_WIDTH_CLOSED)
	environment_picker.get_popup().add_theme_constant_override(&"icon_max_width", ENVIRONMENT_THUMB_WIDTH)
	for environment: Array in Settings.ENVIRONMENTS:
		environment_picker.add_item(environment[1])
		environment_picker.set_item_icon(environment_picker.item_count - 1, _environment_thumb(environment[0]))
	environment_picker.item_selected.connect(func(item: int) -> void: Settings.environment = Settings.ENVIRONMENTS[item][0])
	environment_row.add_child(environment_picker)
	_show_environment()

## Shows the saved pick; "Follow map" also names the environment the selected song will get.
func _show_environment() -> void:
	if not environment_picker:
		return
	var ids: Array = Settings.ENVIRONMENTS.map(func(e: Array) -> String: return e[0])
	environment_picker.select(maxi(ids.find(Settings.environment), 0))
	var follow: String = Settings.ENVIRONMENTS[0][1]
	var resolved := EventDriver.map_environment(_shown_map)
	if _shown_map:
		follow += " (%s)" % Settings.ENVIRONMENTS[ids.find(resolved)][1]
	environment_picker.set_item_text(0, follow)
	environment_picker.set_item_icon(0, _environment_thumb(resolved))

## The picture of an environment, or null when there is none.
static func _environment_thumb(id: String) -> Texture2D:
	var path := ENVIRONMENT_THUMBS % id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

## Difficulty levels in button order: [difficulty name in the map, button label].
const LEVELS := [["Easy", "Easy"], ["Normal", "Normal"], ["Hard", "Hard"], ["Expert", "Expert"], ["ExpertPlus", "Expert+"]]
## Most characteristic tabs a map can show; BeatSaver has 8 characteristics.
const MAX_CHARACTERISTICS := 8
## Shorter tab labels for characteristics whose names don't fit.
const CHARACTERISTIC_LABELS := {"OneSaber": "1 Saber", "NoArrows": "No Arrows", "360Degree": "360°", "90Degree": "90°"}

## Characteristic of each tab in characteristic_row, in tab order, for the selected map.
var _characteristics: Array[String] = []
## Side padding of the level buttons, so "Expert+" fits five to a row at full size.
const LEVEL_BUTTON_PADDING := 4.0

## Fills the difficulty picker with one button per level and a pool of characteristic tabs, so nothing scrolls.
func _build_difficulty_picker() -> void:
	var tab_group := ButtonGroup.new()
	for i in MAX_CHARACTERISTICS:
		var tab := _make_row_button("", tab_group, _on_characteristic_pressed.bind(i))
		tab.add_theme_font_size_override(&"font_size", 20)
		tab.clip_text = true
		characteristic_row.add_child(tab)
	var level_group := ButtonGroup.new()
	for i in LEVELS.size():
		var button := _make_row_button(LEVELS[i][1], level_group, _on_level_pressed.bind(i))
		button.add_theme_font_size_override(&"font_size", 22)
		var color: Color = Constants.DIFFICULTY_COLORS.get(LEVELS[i][0], Constants.UI_TEXT)
		for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
			button.add_theme_color_override(state, color)
		level_row.add_child(button)
		# five buttons share the column: narrow side padding (read once in the tree, from the menu theme),
		# and the text never widens the row past the panel
		button.clip_text = true
		for style: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
			var box := button.get_theme_stylebox(style).duplicate() as StyleBox
			box.content_margin_left = LEVEL_BUTTON_PADDING
			box.content_margin_right = LEVEL_BUTTON_PADDING
			button.add_theme_stylebox_override(style, box)
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
	# the tab row only takes room when there are tabs; then the stats get one line less, so the picker
	# never runs into the fail row below it
	characteristic_row.visible = _characteristics.size() > 1
	level_stats.max_lines_visible = 2 if characteristic_row.visible else 3
	# each of the map's difficulties keeps the mapper's slot but shows the difficulty it plays at
	# (MapStats.level_of); slots the map lacks are hidden, and slots that play at the same level
	# are numbered in the map's order ("Hard 1", "Hard 2") so no name shows twice
	var levels := {}
	var level_counts := {}
	for i in LEVELS.size():
		var index := _find_difficulty(map, _characteristic_of(picked), i) if picked else -1
		if index >= 0:
			var diff := map.difficulty_beatmaps[index]
			levels[i] = MapStats.level_of(map, diff, MapStats.get_stats(map, diff))
			level_counts[levels[i]] = level_counts.get(levels[i], 0) + 1
	var level_seen := {}
	for i in LEVELS.size():
		var button := level_row.get_child(i) as Button
		var index := _find_difficulty(map, _characteristic_of(picked), i) if picked else -1
		button.text = LEVELS[i][1]
		button.add_theme_font_size_override(&"font_size", 22)
		button.remove_theme_color_override(&"font_color")
		button.remove_theme_color_override(&"font_pressed_color")
		if index >= 0:
			var level: Array = Constants.DIFFICULTY_LEVELS[levels[i]]
			button.text = level[0]
			if level_counts[levels[i]] > 1:
				level_seen[levels[i]] = level_seen.get(levels[i], 0) + 1
				button.text += " %d" % level_seen[levels[i]]
			button.add_theme_color_override(&"font_color", level[1])
			button.add_theme_color_override(&"font_pressed_color", level[1])
		button.visible = index >= 0 or not picked
		button.disabled = index < 0
		button.set_pressed_no_signal(picked != null and picked.difficulty == LEVELS[i][0])
	if picked:
		var stats := MapStats.get_stats(map, picked)
		level_stats.text = MapStats.describe(map, picked, stats)
		level_stats.add_theme_color_override(&"font_color", Constants.DIFFICULTY_LEVELS[MapStats.level_of(map, picked, stats)][1])
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
	button.add_theme_font_size_override(&"font_size", 24)
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
		# child 0 is the "Damage" label
		var button := damage_row.get_child(i + 1) as Button
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
		reset_button.show()

## Shows whether the selected song is a favourite: a filled yellow star, or an outline to add it.
func _set_favorite_icon(value: bool) -> void:
	favorite_button.set_pressed_no_signal(value)
	favorite_button.text = "Favorite" if value else "Add to favorites"
	favorite_button.icon = STAR_FILLED_ICON if value else STAR_ICON
	var color := Color.YELLOW if value else Color.WHITE
	for icon_color in [&"icon_normal_color", &"icon_pressed_color", &"icon_hover_color", &"icon_hover_pressed_color", &"icon_focus_color"]:
		favorite_button.add_theme_color_override(icon_color, color)
	favorite_button.add_theme_color_override("font_color", color)
	favorite_button.add_theme_color_override("font_disabled_color", color)
	favorite_button.add_theme_color_override("font_focus_color", color)
	favorite_button.add_theme_color_override("font_hover_color", color)
	favorite_button.add_theme_color_override("font_hover_pressed_color", color)
	favorite_button.add_theme_color_override("font_pressed_color", color)

func _on_favorite_button_pressed() -> void:
	if _shown_map == null:
		return
	var map := _shown_map
	var favorite := not PlayCount.is_favorite(map)
	PlayCount.set_favorite(map, favorite)
	_set_favorite_icon(favorite)
	_reselect_path = map.filepath
	_sort_songs()
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
	Settings.arrows_enabled = true
	Settings.claws = false
	Settings.block_size = 100
	Settings.width = 100 
	Settings.flip = 0
	Settings.music_speed = 100
	Settings.handedness = 0
	_update_mod_controls()
	update_view()

	pass # Replace with function body.
