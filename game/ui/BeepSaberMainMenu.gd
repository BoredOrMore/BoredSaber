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
## The player wants to run the body test: the menu closes while it runs.
signal body_test_requested()
## The player button was pressed: "Who's playing?" opens in front of the menu.
signal profiles_requested()
signal start_map(info: MapInfo, difficulty: DifficultyInfo, health: bool)
## A song was picked or dropped, or a song stopped loading: the game shows or hides the block to slash.
signal play_ready_changed()

const FAVORITE_MASK := 0x4000000000000000
const STAR_ICON := preload("res://game/ui/icons/star.svg")
const STAR_FILLED_ICON := preload("res://game/ui/icons/star-filled.svg")
@export var main_song_player_ref: AudioStreamPlayer
@export var keyboard: OQ_UI2DKeyboard
@export var beepsaber_game : BeepSaber_Game

@export var song_uploader_ref: SongUploader

@onready var playlist_selector := $PlaylistSelector as OptionButton
@onready var filters_button := $Filters_Button as Button
@onready var favorites_filter := $FiltersPanel/Rows/ToggleRow/FavoritesFilter as Button
@onready var workout_filter := $FiltersPanel/Rows/ToggleRow/WorkoutFilter as Button
@onready var filter_rows := $FiltersPanel/Rows as VBoxContainer
@onready var filter_status := $FiltersPanel/Rows/FilterStatus as Label
@onready var clear_filters_button := $FiltersPanel/Rows/ClearFilters_Button as Button
@onready var empty_list_label := $EmptyList as Label
@onready var _bg_img_loader := preload("res://game/scripts/BackgroundImgLoader.gd").new()

@onready var cover := $cover as TextureRect
@onready var songs_menu := $SongsMenu as SongList
@onready var characteristic_row := $DifficultyPicker/CharacteristicRow as HBoxContainer
@onready var level_row := $DifficultyPicker/LevelRow as HBoxContainer
@onready var level_stats := $DifficultyPicker/LevelStats as HFlowContainer
@onready var delete_button := $MorePanel/Delete_Button as ConfirmButton
@onready var fail_row := $Modifiers/Fail/FailRow as HBoxContainer
@onready var damage_row := $Modifiers/Fail/DamageRow as HBoxContainer
@onready var toggle_row := $Modifiers/Notes/ToggleRow as HBoxContainer
@onready var speed_row := $Modifiers/Speed/SpeedRow as HBoxContainer
@onready var more_mods_button := $Modifiers/Header/MoreMods_Button as Button
@onready var environment_row := $Modifiers/Look/EnvironmentRow as HBoxContainer
@onready var more_mods_rows := $MoreModsPanel/Rows as VBoxContainer
@onready var favorite_button := $Favorite_Button as Button
@onready var profile_button := $Profile_Button as Button
@onready var reset_button := $Modifiers/Header/Reset_Button as Button

@onready var song_preview := $song_prev as SongPreview
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

## Every song folder's name (its hash) in the library, as a set (hash -> true): Get songs asks it for every row it
## shows and every frame of a download, so a lookup is O(1), not a search of the whole library (owner, 2026-10-29).
var all_song_hashes := {}
# send a signal whenever the all_song_keys array changes
signal song_list_changed()

func _physics_process(delta: float) -> void:
	_step_with_stick(delta)

## Thumbstick song stepping: pushed past STICK_THRESHOLD up or down, the selection moves one song; held, it
## repeats after STICK_REPEAT_DELAY every STICK_REPEAT_INTERVAL seconds. The preview starts once it is let go.
const STICK_THRESHOLD := 0.5
const STICK_REPEAT_DELAY := 0.4
const STICK_REPEAT_INTERVAL := 0.12
## each step the stick makes ticks that hand's controller lightly (owner, 2026-10-28): this strong (0-1), this long (s)
const STICK_TICK_STRENGTH := 0.15
const STICK_TICK_SECONDS := 0.02
## Seconds the stick has been pushed, -1 while it rests; and when the next step is due.
var _stick_time := -1.0
var _stick_next := 0.0

## Moves the song selection with the stronger thumbstick of the two hands while the song menu takes input.
func _step_with_stick(delta: float) -> void:
	var canvas := get_viewport().get_parent() as OQ_UI2DCanvas
	var takes_input := canvas != null and canvas.is_visible_in_tree() and not canvas.disable_collision \
			and not keyboard.visible and songs_menu.item_count > 0
	var y := 0.0
	var hand := vr.rightController
	if takes_input:
		var y_left := vr.leftController.get_vector2("primary").y
		var y_right := vr.rightController.get_vector2("primary").y
		y = y_left if absf(y_left) > absf(y_right) else y_right
		hand = vr.leftController if absf(y_left) > absf(y_right) else vr.rightController
	if absf(y) < STICK_THRESHOLD:
		if _stick_time >= 0.0:
			_stick_time = -1.0
			if takes_input:
				play_selected_preview(0.0, true)
		return
	if _stick_time < 0.0:
		_stick_time = 0.0
		_stick_next = 0.0
	if _stick_time >= _stick_next:
		# pushing down (negative y) moves down the list
		var next := clampi(current_selected + (1 if y < 0.0 else -1), 0, songs_menu.item_count - 1)
		if next != current_selected:
			songs_menu.select(next)
			_select_song(next, false)
			songs_menu.center_on(next)
			canvas._input_update()
			hand.simple_rumble(STICK_TICK_STRENGTH, STICK_TICK_SECONDS)
		_stick_next += STICK_REPEAT_DELAY if _stick_next == 0.0 else STICK_REPEAT_INTERVAL
	_stick_time += delta

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

## Adds just-downloaded song folders (`dir_names` under Songs/) to the list, without reading every song again
## (owner, 2026-10-28: the view froze downloading many songs; reloading the whole library after a queue was most of
## it).
func add_downloaded_songs(dir_names: Array[String]) -> void:
	var new_names := dir_names.filter(func(dir_name: String) -> bool: return not all_song_hashes.has(dir_name))
	# their info read on a worker thread, as the download's unzip
	var songs := []
	var task := WorkerThreadPool.add_task(func() -> void:
		for dir_name: String in new_names:
			songs.append(Map.load_map_info(Constants.APPDATA_PATH + "Songs/" + dir_name + "/")))
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	for i in new_names.size():
		if songs[i]:
			_all_songs.append(songs[i])
		all_song_hashes[new_names[i]] = true
	song_list_changed.emit()
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
				all_song_hashes[file_name] = true
			file_name = dir.get_next()
	emit_signal("song_list_changed")

func _set_cur_playlist(songs: Array[MapInfo]) -> void:
	var current_map : MapInfo
	current_map = null
	# where the selected song sits in the view, to keep it there in the rebuilt list
	var row_offset := 0.0
	if current_selected >= 0:
		current_map = _currently_selected_songlist_ref[current_selected]
		row_offset = songs_menu.row_offset(current_selected)
	var filter := SongFilter.saved()
	var shown: Array[MapInfo] = []
	for map in songs:
		# the selected song stays even when a filter would hide it now (a filter that follows the speed would pull it
		# from under the player choosing its speed, and the list would jump)
		if filter.passes(map) or map == current_map:
			shown.append(map)
	_show_filter_counts(filter, songs, shown.size())
	songs = shown
	_currently_selected_songlist_ref = songs
	songs_menu.clear()
	_list_generation += 1
	# the old list's rows still waiting for a cover are other songs now
	_bg_img_loader.drop_list_requests()
	
	var map_index := 0
	var missing_covers: Array[int] = []
	for map in songs:
		@warning_ignore("return_value_discarded")
		var favorite := PlayCount.is_favorite(map)
		var list_cover: Texture2D = _list_covers.get(map.filepath, default_song_icon)
		songs_menu.add_item("%s%s - %s%s" % ["\u2605 " if favorite else "", map.song_author_name, map.song_name, "" if map.have_song else NO_MUSIC_SUFFIX], list_cover)
		songs_menu.set_item_custom_fg_color(map_index, Color.YELLOW if favorite else Color.WHITE)
		if not _list_covers.has(map.filepath):
			missing_covers.append(map_index)
		map_index += 1
		
	if current_map != null:
		current_selected = -1
		for i in range(songs.size()):
			if songs[i] == current_map:
				songs_menu.select(i)
				songs_menu.place_row(i, row_offset)
				# same song as before: keep whatever preview is playing (maybe a BeatSaver one)
				_select_song(i, false)
		if current_selected == -1:
			songs_menu.deselect_all()
	# asked for once the list is placed, so the rows in view load first
	_show_cover_view()
	for index in missing_covers:
		var map := songs[index]
		_bg_img_loader.load_texture(map.filepath, map.cover_image_filename, _on_cover_loaded.bind(_list_generation, map.filepath),
				false, index, LIST_COVER_SIZE)
	_update_play_status()

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
## The Filters button above the list: the song count, or with filters or a search on how many show and why.
const FILTERS_TEXT := "Filters · %d %s"
const FILTERS_SHOWN_TEXT := "%d of %d · %s"
const FILTERS_ON_TEXT := ["%d filter", "%d filters"]
const FAVORITES_LABEL := "Favorites"
const WORKOUT_LABEL := "Workout"
const DIFFICULTY_FILTER_TITLE := "Difficulty"
const LENGTH_FILTER_TITLE := "Length"
## The filters' chips (FilterChips), in the order of MapStats.difficulty_filters and Constants.LENGTH_FILTERS
## without their first, "any", choice
var _difficulty_chips: Array[Button] = []
var _length_chips: Array[Button] = []
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
	for i in _difficulty_chips.size():
		var choice := filter.copy()
		choice.reaction = difficulties[i + 1][0]
		FilterChips.show_count(_difficulty_chips[i], difficulties[i + 1][1], choice.count(songs))
	for i in _length_chips.size():
		var choice := filter.copy()
		choice.length = Constants.LENGTH_FILTERS[i + 1][0]
		FilterChips.show_count(_length_chips[i], Constants.LENGTH_FILTERS[i + 1][1], choice.count(songs))
	var favorites := filter.copy()
	favorites.favorites = true
	FilterChips.show_count(favorites_filter, FAVORITES_LABEL, favorites.count(songs))
	var workout := filter.copy()
	workout.workout = true
	FilterChips.show_count(workout_filter, WORKOUT_LABEL, workout.count(songs))

	var total := _all_songs.size()
	var noun: String = SONG_NOUNS[0] if total == 1 else SONG_NOUNS[1]
	var status := SONG_TOTAL_TEXT % [total, noun]
	if not filter.is_off() or not _search_text.is_empty():
		status = (FILTER_STATUS_TEXT if _search_text.is_empty() else SEARCH_FILTER_STATUS_TEXT) % [shown, total, noun]
	if not _search_text.is_empty():
		status += SEARCH_STATUS_TEXT % _search_text
	filter_status.text = status
	filters_button.text = FILTERS_TEXT % [total, noun]
	if not filter.is_off() or not _search_text.is_empty():
		var on := int(filter.reaction != 0) + int(filter.length != 0) + int(filter.favorites) + int(filter.workout)
		var what: String = (FILTERS_ON_TEXT[0 if on == 1 else 1] % on) if _search_text.is_empty() else ("\"%s\"" % _search_text)
		filters_button.text = FILTERS_SHOWN_TEXT % [shown, total, what]
	clear_filters_button.visible = not filter.is_off() or not _search_text.is_empty()
	empty_list_label.visible = shown == 0
	empty_list_label.text = NO_SONGS_TEXT if total == 0 else NO_MATCH_TEXT

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

## Stores whether only favorite songs are listed; on_settings_changed rebuilds the list.
func _on_favorites_filter_toggled(on: bool) -> void:
	Settings.song_filter_favorites = on

## Stores whether only songs with a wall workout are listed; on_settings_changed rebuilds the list.
func _on_workout_filter_toggled(on: bool) -> void:
	Settings.song_filter_workout = on

var default_song_icon := preload("res://game/data/beepsaber_logo.png")

## Bumped every time the song list is rebuilt, so covers still loading for an older list are dropped.
var _list_generation := 0
## The list's covers by song folder, shrunk to LIST_COVER_SIZE px: rebuilding the list (every search key, every
## filter) reuses them instead of decoding and uploading every full-size cover again, which dropped frames.
var _list_covers := {}
## Longest side of a list cover in px: twice the 72 px it is drawn at, for a sharp but small texture.
const LIST_COVER_SIZE := 144

# callback from ImageUtils when background image loading is complete. if image
# failed to load, tex will be null
func _on_cover_loaded(img_tex: Texture2D, is_main_cover: bool, list_idx: int, generation := -1, map_path := "") -> void:
	if img_tex != null:
		if is_main_cover:
			cover.call_deferred("set_texture", img_tex)
		else:
			_set_list_cover.call_deferred(list_idx, img_tex, generation, map_path)

## Tells the cover loader which rows are in view, so their covers load first.
func _show_cover_view() -> void:
	var rows := songs_menu.shown_rows()
	_bg_img_loader.set_view(rows.x, rows.y)

## Puts a loaded cover on its row, unless the list was rebuilt since the load started (the row may be
## another song now, or gone).
func _set_list_cover(list_idx: int, img_tex: Texture2D, generation: int, map_path: String) -> void:
	_list_covers[map_path] = img_tex
	if generation == _list_generation and list_idx < songs_menu.item_count:
		songs_menu.set_item_icon(list_idx, img_tex)

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
		song_preview.fade_to(volume_db)
		return
	song_preview.start_file(map.filepath + map.song_filename, map.preview_start_time, volume_db)

## Plays a song's audio as the preview (BeatSaver's previews too); duration is unused: it plays to the end and loops.
func play_preview(buffer: PackedByteArray, start_time: float = 0.0, _duration: float = -1.0, buffer_data_type_hint: String = 'ogg', volume_db: float = 0.0) -> void:
	song_preview.start(buffer, start_time, buffer_data_type_hint, volume_db)

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
		song_preview.start_file(map.filepath + map.song_filename, map.preview_start_time)
	
	# the difficulty last played (its rank), or the first
	var rank := PlayCount.get_last_difficulty(map) & Constants.DIFFICULTY_MASK
	var last := 0
	for i in map.difficulty_beatmaps.size():
		if map.difficulty_beatmaps[i].difficulty_rank == rank:
			last = i
			break
	_select_difficulty(last)

## Fades out the playing preview and drops any preview still waiting to start.
func stop_preview() -> void:
	await song_preview.cancel()

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
	
## Shows the saved modifiers on every chip, and what changed on Reset and More modifiers.
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(Constants.APPDATA_PATH+"Backgrounds/")
	DirAccess.make_dir_recursive_absolute(Constants.APPDATA_PATH+"Songs/")

	Settings.changed.connect(on_settings_changed)
	song_preview.song_player = main_song_player_ref
	
	_mods = ModifierChips.new(self)
	_mods.build()
	_build_difficulty_picker()
	_build_tabs()
	_build_filter_chips()
	songs_menu.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _show_cover_view())
	_show_player_name()
	_update_mod_controls()
	favorite_button.hide()
	
	UI_AudioEngine.attach_children(self)
	
	playlist_selector.clear()
	playlist_selector.add_item("All songs")
	playlist_selector.add_item("Newest")
	playlist_selector.add_item("Most played")
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
		&"environment":
			_show_environment()
		&"music_speed":
			song_preview.pitch_scale = Settings.music_speed / 100.
			# reaction times depend on the Speed modifier
			if MapStats.difficulty_filter(Settings.song_filter_reaction) != 0:
				_refilter()
		&"song_filter_reaction", &"song_filter_length":
			_show_picked_filters()
			_refilter()
		&"song_filter_favorites":
			favorites_filter.set_pressed_no_signal(Settings.song_filter_favorites)
			_refilter()
		&"song_filter_workout":
			workout_filter.set_pressed_no_signal(Settings.song_filter_workout)
			_refilter()

## Plays the selected song (the block in front of the player was slashed).
func play_selected() -> void:
	if not has_song_picked():
		return
	var map := _currently_selected_songlist_ref[current_selected]
	Settings.last_map = map.filepath
	song_preview.cancel(SongPreview.PLAY_FADE_SECONDS)
	Settings.save()
	_show_status(LOADING_TEXT)
	_loading = true
	# loading blocks the main thread, so let the status redraw first
	await get_tree().process_frame
	await get_tree().process_frame
	_load_map_and_start(map)
	_loading = false
	# a load error (show_play_error) keeps its message for a while
	if _status == LOADING_TEXT:
		_show_status("")

## Shown in place of the stats pills while the picked song loads or when it can't (owner, 2026-10-28: no
## "Slash to play" line on the panel; the note to slash says it).
const LOADING_TEXT := "Loading song…"
const LOAD_ERROR_TEXT := "Can't load this song. Pick another one."
## Seconds the load error stays before the status comes back.
const LOAD_ERROR_SECONDS := 3.0
var _loading := false
var _status := ""

func _show_status(text: String) -> void:
	_status = text
	_sync_difficulty_picker()

## The selected song and difficulty, or nulls when none is picked.
func selected_map() -> MapInfo:
	return _currently_selected_songlist_ref[current_selected] if has_song_picked() else null

func selected_difficulty() -> DifficultyInfo:
	var map := selected_map()
	return map.difficulty_beatmaps[_map_difficulty] if map and _map_difficulty >= 0 and _map_difficulty < map.difficulty_beatmaps.size() else null

## True while a song in the list is selected.
## The difficulty Play would start for the picked song, or null with none picked.
func picked_difficulty() -> DifficultyInfo:
	if current_selected < 0 or current_selected >= _currently_selected_songlist_ref.size():
		return null
	var set0 := _currently_selected_songlist_ref[current_selected].difficulty_beatmaps
	return set0[_map_difficulty] if _map_difficulty < set0.size() else null

func has_song_picked() -> bool:
	return not _loading and current_selected >= 0 and current_selected < _currently_selected_songlist_ref.size()

## Tells the game whether a song is ready to play (the note to slash shows then).
func _update_play_status() -> void:
	if _loading:
		return
	play_ready_changed.emit()


## Tells the player, in place of the stats pills, that the selected song couldn't be loaded.
func show_play_error() -> void:
	_show_status(LOAD_ERROR_TEXT)
	await get_tree().create_timer(LOAD_ERROR_SECONDS).timeout
	_show_status("")
	_update_play_status()

func _on_Exit_Button_pressed() -> void:
	get_tree().quit()

## Tabs at the top of the right panel, in order. Settings is not one: it opens its own screen, so it is the gear
## button beside them (a control looks like what it does).
enum Tab { MODIFIERS, MORE }
const TAB_LABELS := ["Modifiers", "More"]

## Fills the tab row; Modifiers shows the modifiers, More a panel in their place.
func _build_tabs() -> void:
	var group := ButtonGroup.new()
	for i in TAB_LABELS.size():
		$Tabs.add_child(ModifierChips.make_row_button(TAB_LABELS[i], group, _on_tab_pressed.bind(i), &"TabButton"))
	_show_tab(Tab.MODIFIERS)

func _on_tab_pressed(tab: int) -> void:
	_show_tab(tab)

## Opens the settings screen from the gear button.
func _on_settings_button_pressed() -> void:
	settings_requested.emit()

## Shows the tab's panel over the modifiers (Modifiers shows them) and lights up its tab.
func _show_tab(tab: int) -> void:
	$MorePanel.visible = tab == Tab.MORE
	$MoreModsPanel.hide()
	$EnvironmentPanel.hide()
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
## What the shared keyboard is open for here; empty when it was opened elsewhere (a player name).
var _keyboard_for := &""
## The text the song list is sorted by, shown in the status row above it; empty when not searching.
var _search_text := ""

func _on_Search_Button_button_up() -> void:
	_keyboard_for = KEYBOARD_SEARCH
	keyboard._text_edit.placeholder_text = "Search songs"
	keyboard.visible=true
	keyboard._text_edit.grab_focus()

## Opens "Who's playing?".
func _on_profile_button_pressed() -> void:
	profiles_requested.emit()

## Shows the current player on the player button.
func _show_player_name() -> void:
	profile_button.text = Settings.player_name

func _text_input_enter(_text:String = "") -> void:
	if _keyboard_for.is_empty():
		return
	_keyboard_for = &""
	keyboard.visible=false

func _text_input_cancel() -> void:
	if _keyboard_for.is_empty():
		return
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

## Starts the body test.
func _on_body_test_pressed() -> void:
	body_test_requested.emit()

func _on_licenses_pressed() -> void:
	var license := FileAccess.open("res://LICENSE", FileAccess.READ).get_as_text()
	$LicensePopup/Rows/ScrollContainer/Label.text = license
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
	_update_play_status()
	_update_mod_controls()

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
		# the level buttons' narrow kind, so "Standard" and "No Arrows" fit four or five to a row
		var tab := ModifierChips.make_row_button("", tab_group, _on_characteristic_pressed.bind(i), &"DifficultyButton")
		tab.add_theme_font_size_override(&"font_size", 20)
		tab.clip_text = true
		characteristic_row.add_child(tab)
	var level_group := ButtonGroup.new()
	for i in LEVELS.size():
		var button := ModifierChips.make_row_button(LEVELS[i][1], level_group, _on_level_pressed.bind(i), &"DifficultyButton")
		var color: Color = Constants.DIFFICULTY_COLORS.get(LEVELS[i][0], Constants.UI_TEXT)
		for state: StringName in [&"font_color", &"font_hover_color", &"font_focus_color"]:
			button.add_theme_color_override(state, color)
		# the picked one's name stays white on the blue (its colour fails contrast there); its border shows the colour
		for state: StringName in [&"font_pressed_color", &"font_hover_pressed_color"]:
			button.add_theme_color_override(state, Constants.UI_TEXT)
		level_row.add_child(button)
		# five buttons share the column (DifficultyButton's narrow padding): the text never widens the row
		button.clip_text = true
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

## Shows the selected map's characteristics (tabs only when there is more than one), its levels and the picked
## one's stats, or the status while a song loads or failed to.
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
		button.remove_theme_color_override(&"font_color")
		_set_picked_border(button, Constants.UI_ACCENT)
		if index >= 0:
			var level: Array = Constants.DIFFICULTY_LEVELS[levels[i]]
			button.text = level[0]
			if level_counts[levels[i]] > 1:
				level_seen[levels[i]] = level_seen.get(levels[i], 0) + 1
				button.text += " %d" % level_seen[levels[i]]
			button.add_theme_color_override(&"font_color", level[1])
			_set_picked_border(button, level[1])
		button.visible = index >= 0 or not picked
		button.disabled = index < 0
		button.set_pressed_no_signal(picked != null and picked.difficulty == LEVELS[i][0])
	if _status != "":
		var status := Label.new()
		status.text = _status
		StatPills.fill(level_stats, [status])
	elif picked:
		StatPills.fill(level_stats, stat_pills(map, picked, MapStats.get_stats(map, picked)))
	else:
		StatPills.fill(level_stats, [])

## Icons in the stats pills, the size of the 22 px text.
const STAT_ICON_SIZE := 24

## The picked difficulty's stats as pills (StatPills): length, time to get ready, notes per second, swing flow,
## and a workout's sets.
static func stat_pills(map: MapInfo, difficulty: DifficultyInfo, stats: Dictionary) -> Array[Control]:
	var pills: Array[Control] = [StatPills.length(float(stats.get("seconds", 0.0)), STAT_ICON_SIZE)]
	pills.append_array(StatPills.difficulty(MapStats.reaction_seconds(map, difficulty),
		float(stats.get("nps", 0.0)) * MapStats._speed(), float(stats.get("flow", 0.0)), STAT_ICON_SIZE))
	if MapStats.workout_level(stats) > 0:
		pills.append(StatPills.workout(int(stats.get("sets", 0)), STAT_ICON_SIZE))
	return pills

## The picked level button's border in its difficulty's colour (the name on it stays white, for contrast; Game
## Accessibility Guidelines, doc/research/game-ui.md).
static func _set_picked_border(button: Button, color: Color) -> void:
	for style: StringName in [&"pressed", &"hover_pressed"]:
		# the button's own copy of its kind's style (DifficultyButton), so other buttons keep theirs
		button.remove_theme_stylebox_override(style)
		var box := button.get_theme_stylebox(style).duplicate() as StyleBoxFlat
		if box:
			box.border_color = color
			button.add_theme_stylebox_override(style, box)

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
	
## The Song tab's modifier chips, fail and damage rows and environment picker (ModifierChips.gd).
var _mods: ModifierChips

## Shows the saved modifiers on their chips.
func _update_mod_controls() -> void:
	_mods.sync()

## Puts every modifier back to its default.
func _on_reset_button_pressed() -> void:
	_mods.reset()

func _show_environment() -> void:
	if _mods:
		_mods.show_environment()

## Opens the song filters in the right panel, over the modifiers and beside the list they filter, or goes back to
## the modifiers.
func _show_filters(open: bool) -> void:
	$FiltersPanel.visible = open

## Fills the filters panel with a Difficulty and a Length section of chips (FilterChips), above Clear filters.
func _build_filter_chips() -> void:
	var label := func(choice: Array) -> String: return str(choice[1])
	# a chip's index is its choice's less one: the first choice is "any", which no chip picked gives
	var pick_difficulty := func(index: int) -> void:
		Settings.song_filter_reaction = index + 1
	var pick_length := func(index: int) -> void:
		Settings.song_filter_length = Constants.LENGTH_FILTERS[index + 1][0]
	_difficulty_chips = FilterChips.add_section(filter_rows, DIFFICULTY_FILTER_TITLE,
		MapStats.difficulty_filters().slice(1).map(label), pick_difficulty, &"DifficultyButton")
	_length_chips = FilterChips.add_section(filter_rows, LENGTH_FILTER_TITLE,
		Constants.LENGTH_FILTERS.slice(1).map(label), pick_length, &"DifficultyButton")
	filter_rows.move_child(clear_filters_button, -1)
	_show_picked_filters()

## Shows the saved difficulty and length filters on their chips.
func _show_picked_filters() -> void:
	FilterChips.show_picked(_difficulty_chips, MapStats.difficulty_filter(Settings.song_filter_reaction) - 1)
	FilterChips.show_picked(_length_chips, MapStats.length_filter(Settings.song_filter_length)[0] - 1)

## Opens More modifiers over the song details, or goes back to them.
## Opens or closes the environment cards over the modifiers (the Environment button, Back, or a pick).
func show_environments(open: bool) -> void:
	$EnvironmentPanel.visible = open

func _show_more_modifiers(open: bool) -> void:
	$MoreModsPanel.visible = open
