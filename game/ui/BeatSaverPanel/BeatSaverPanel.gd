extends Panel
class_name BeatSaverPanel

class BeatSaverSongInfo extends RefCounted:
	var name: String
	var description: String
	var song_name: String
	var song_author_name: String
	var level_author_name: String
	var duration: float
	var bpm: float
	var versions: Array
	var uploader_id: int
	## Made by an auto-mapper (AI), not a person.
	var automapper: bool

	func _init(song_info: Dictionary) -> void:
		name = Utils.get_str(song_info, "name", "")
		description = Utils.get_str(song_info, "description", "")
		versions = Utils.get_array(song_info, "versions", [])
		automapper = bool(song_info.get("automapper", false))
		# difficulties that need a mod this game doesn't have (Noodle Extensions, Mapping Extensions,
		# Vivify) don't play right here, so they are left out
		if not versions.is_empty() and versions[0] is Dictionary:
			var version := versions[0] as Dictionary
			version["diffs"] = Utils.get_array(version, "diffs", []).filter(func(diff: Variant) -> bool:
				return diff is Dictionary and not (diff.get("ne", false) or diff.get("me", false) or diff.get("vivify", false)))
		uploader_id = int(Utils.get_float(Utils.get_dict(song_info, "uploader", {}), "id", -1))
		var metadata := Utils.get_dict(song_info, "metadata", {})
		song_name = Utils.get_str(metadata, "songName", "")
		song_author_name = Utils.get_str(metadata, "songAuthorName", "")
		level_author_name = Utils.get_str(metadata, "levelAuthorName", "")
		duration = Utils.get_float(metadata, "duration", 0.0)
		bpm = Utils.get_float(metadata, "bpm", 0.0)

	## Seconds a note of one difficulty (from versions[0].diffs) is visible before reaching the player.
	func reaction_seconds(diff: Dictionary) -> float:
		return MapStats.reaction_seconds_for(bpm, Utils.get_float(diff, "njs", 0.0), Utils.get_float(diff, "offset", 0.0))

	## True if the map can be played here: made by a person, with a Standard difficulty that needs no mod.
	func is_playable() -> bool:
		if automapper or versions.is_empty():
			return false
		for diff: Variant in Utils.get_array(versions[0] as Dictionary, "diffs", []):
			if Utils.get_str(diff as Dictionary, "characteristic", "") == "Standard":
				return true
		return false

	## True if the difficulty filter is off or any difficulty of the newest version reads like the picked
	## difficulty. BeatSaver has no swing data, so only reaction time counts until the map is downloaded.
	func passes_reaction_filter() -> bool:
		if Settings.song_filter_reaction == 0:
			return true
		if versions.is_empty():
			return false
		for diff: Variant in Utils.get_array(versions[0] as Dictionary, "diffs", []):
			if diff is Dictionary and MapStats.reaction_level(reaction_seconds(diff as Dictionary)) == Settings.song_filter_reaction - 1:
				return true
		return false

var song_data: Array[BeatSaverSongInfo] = []
# reference to the main main node (used for playing downloadable song previews)
@export var main_menu_ref: MainMenu
# the next requestable pages for the current list; -1 if prev/next page is
# not requestable (ie. reached end of the list)
var prev_page_available := -1
var next_page_available := -1
## Style chips and genres: [label, BeatSaver tag], "" meaning any.
const STYLES := [["Any", ""], ["Dance", "dance-style"], ["Workout", "fitness"], ["Accuracy", "accuracy"],
	["Tech", "tech"], ["Speed", "speed"], ["Challenge", "challenge"]]
const GENRES := [["Any genre", ""], ["Pop", "pop"], ["J-Pop", "j-pop"], ["K-Pop", "k-pop"], ["Anime", "anime"],
	["Electronic", "electronic"], ["Rock", "rock"], ["Game music", "video-game-soundtrack"], ["Metal", "metal"],
	["Classical", "classical-orchestral"], ["Hip-hop", "hip-hop-rap"], ["Vocaloid", "vocaloid"]]
## Tags of the picked style and genre.
var _style_tag := ""
var _genre_tag := ""
## Sort tabs: [label, BeatSaver sortOrder]. The play-count list BeatSaver used to keep is all zeros now.
const SORT_TABS := [["Popular", "Rating"], ["New", "Latest"], ["Staff picks", "Curated"], ["Random", "Random"]]
var search_word := ""
var item_selected := -1
var downloading := []#[["name","version_info"]]
## Most previews kept in memory, so clicking a map again plays at once.
const MAX_CACHED_PREVIEWS := 10
## Preview mp3 bytes by preview URL, oldest first.
var _preview_cache := {}
## URL of the preview being downloaded.
var _preview_url := ""

@onready var item_list := $ItemList as ItemList
@onready var sort_tabs := $SortTabs as HBoxContainer
@onready var search_button := $search as Button
@onready var clear_search_button := $ClearSearch as Button
@onready var back_button := $back as Button
@onready var label := $Label as Label
@onready var httpreq := $HTTPReq as HTTPRequest
@onready var httpdownload := $HTTPDownload as HTTPRequest
@onready var httpcoverdownload := $CoverDownload as HTTPRequest
@onready var httppreviewdownload := $PreviewDownload as HTTPRequest
@onready var placeholder_cover := preload("res://game/data/beepsaber_logo.png")
@onready var goto_maps_by := $gotoMapsBy as Button
@onready var reaction_filter := $ReactionFilter as OptionButton
@onready var genre_filter := $GenreFilter as OptionButton
@onready var style_chips := $StyleChips as HBoxContainer
@onready var length_filter := $LengthFilter as OptionButton
@onready var v_scroll := item_list.get_v_scroll_bar()

const MAX_BACK_STACK_DEPTH := 10
# series of previous requests that you can go back to
var back_stack: Array[BeatSaverRequest] = []

# structure representing the previous HTTP request we made to beatsaver
class BeatSaverRequest extends RefCounted:
	var page: int
	var type: String
	var data: String
var prev_request: BeatSaverRequest

@export var keyboard: OQ_UI2DKeyboard

func on_song_list_changed() -> void:
	for item_index in range(0, item_list.item_count):
		item_list.set_item_disabled(item_index,main_menu_ref.all_song_hashes.has(item_list.get_item_metadata(item_index)))

func _ready() -> void:
	var tab_group := ButtonGroup.new()
	for tab: Array in SORT_TABS:
		var button := Button.new()
		button.text = tab[0]
		button.toggle_mode = true
		button.button_group = tab_group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_sort_tab_pressed.bind(tab[1]))
		sort_tabs.add_child(button)
	(sort_tabs.get_child(0) as Button).set_pressed_no_signal(true)
	var style_group := ButtonGroup.new()
	for style: Array in STYLES:
		var chip := Button.new()
		chip.text = style[0]
		chip.toggle_mode = true
		chip.button_group = style_group
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_size_override(&"font_size", 22)
		chip.pressed.connect(_on_style_pressed.bind(style[1]))
		style_chips.add_child(chip)
	(style_chips.get_child(0) as Button).set_pressed_no_signal(true)
	for genre: Array in GENRES:
		genre_filter.add_item(genre[0])
	UI_AudioEngine.attach_children(self)
	back_button.visible = false
	v_scroll.value_changed.connect(_on_ListV_Scroll_value_changed)
	
	var is_web := OS.get_name() == "Web"
	
	if not is_web:
		httpreq.use_threads = true
		httpdownload.use_threads = true
		httpcoverdownload.use_threads = true
		httppreviewdownload.use_threads = true
	
	if keyboard != null:
		keyboard.text_input_enter.connect(_text_input_enter)
		keyboard.text_input_cancel.connect(_text_input_cancel)
	
	var parent_canvas: Node = self
	while parent_canvas != null:
		if parent_canvas is OQ_UI2DCanvas:
			(parent_canvas as OQ_UI2DCanvas).visibility_changed.connect(_on_BeatSaverPanel_visibility_changed)
			break
		parent_canvas = parent_canvas.get_parent()

	main_menu_ref.song_list_changed.connect(on_song_list_changed)
	
	for filter: Array in MapStats.difficulty_filters():
		reaction_filter.add_item(filter[1])
	reaction_filter.set_item_text(0, "Any difficulty")
	for filter: Array in Constants.LENGTH_FILTERS:
		length_filter.add_item(filter[1])
	_sync_filter_controls()
	Settings.changed.connect(_on_settings_changed)

## Shows the saved song filters in the dropdowns.
func _sync_filter_controls() -> void:
	reaction_filter.select(clampi(Settings.song_filter_reaction, 0, Constants.DIFFICULTY_LEVELS.size()))
	length_filter.select(MapStats.length_filter()[0])

## BeatSaver search parameters for the picked style and genre (both must match) and the saved length filter,
## or "" when all are off.
func _filter_query() -> String:
	var length := MapStats.length_filter()
	var query := ""
	var tags := PackedStringArray([_style_tag, _genre_tag])
	tags.erase("")
	tags.erase("")
	if not tags.is_empty():
		query += "&tags=" + ",".join(tags)
	if float(length[2]) > 0.0:
		query += "&minDuration=%d" % int(length[2])
	if float(length[3]) > 0.0:
		query += "&maxDuration=%d" % int(length[3])
	return query

## Follows filter changes (made here or in the song menu) and reloads the current list with them.
func _on_settings_changed(key: StringName) -> void:
	if key != &"song_filter_reaction" and key != &"song_filter_length":
		return
	_sync_filter_controls()
	_reload()

## Loads the current list or search again from its first page, with the current filters.
func _reload() -> void:
	if prev_request != null and prev_request.type != "uploader":
		prev_request.page = 0
		update_list(prev_request)

## Lists only maps of one style (a BeatSaver tag), or any.
func _on_style_pressed(tag: String) -> void:
	_style_tag = tag
	_reload()

## Lists only maps of one genre (a BeatSaver tag), or any.
func _on_genre_filter_item_selected(index: int) -> void:
	_genre_tag = GENRES[index][1]
	_reload()

## Stores the picked reaction time filter.
func _on_reaction_filter_item_selected(index: int) -> void:
	Settings.song_filter_reaction = index

## Stores the picked length filter.
func _on_length_filter_item_selected(index: int) -> void:
	Settings.song_filter_length = Constants.LENGTH_FILTERS[index][0]

# override hide() method to handle case where UI is inside a OQ_UI2DCanvas
func _hide() -> void:
	var parent_canvas: Node = self
	while parent_canvas != null:
		if parent_canvas is OQ_UI2DCanvas:
			(parent_canvas as OQ_UI2DCanvas).hide()
			break
		parent_canvas = parent_canvas.get_parent()
		
	if parent_canvas == null:
		self.visible = false

# override show() method to handle case where UI is inside a OQ_UI2DCanvas
func _show() -> void:
	var parent_canvas: Node = self
	while parent_canvas != null:
		if parent_canvas is OQ_UI2DCanvas:
			(parent_canvas as OQ_UI2DCanvas).show()
			break
		parent_canvas = parent_canvas.get_parent()
		
	if parent_canvas == null:
		self.visible = true
	_on_BeatSaverPanel_visibility_changed()

## BeatSaver search URL for one page. Leaving out the automapper parameter leaves out AI-made maps.
func _search_url(page: int, query: String, sort_order: String) -> String:
	return "https://beatsaver.com/api/search/text/%d?q=%s&sortOrder=%s%s" % [page, query.uri_encode(), sort_order, _filter_query()]

func update_list(req: BeatSaverRequest) -> void:
	if req.page == 0:
		# brand new request, clear list to prep for reload
		item_list.clear()
		if goto_maps_by:
			goto_maps_by.visible = false
		song_data = []
		item_selected = -1
	if not httpcoverdownload:
		return
	httpcoverdownload.cancel_request()
	httpreq.cancel_request()
	prev_page_available = req.page
	next_page_available = -1
	
	match req.type:
		"list":
			httpreq.request(_search_url(req.page, "", req.data))
		"text_search":
			httpreq.request(_search_url(req.page, req.data, "Relevance"))
		"uploader":
			var uploader_id := req.data
			httpreq.request("https://beatsaver.com/api/maps/uploader/%s/%s" % [uploader_id,req.page])
		_:
			vr.log_warning("Unsupported request type '%s'" % req.type)

func _add_to_back_stack(request: BeatSaverRequest) -> void:
	if request == null: return
	back_stack.push_back(request)
	if back_stack.size() > MAX_BACK_STACK_DEPTH:
		back_stack.pop_front()

# return the selected song's data, or null if not song is selected
func _get_selected_song() -> BeatSaverSongInfo:
	if item_selected >= 0 && song_data.size():
		return song_data[item_selected]
	return null

func _on_HTTPRequest_request_completed(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == 0:
		var json_data: Variant = JSON.parse_string(body.get_string_from_utf8())
		if json_data is Dictionary:
			var json_dict := json_data as Dictionary
			next_page_available = prev_page_available + 1
			
			if json_dict.has("docs"):
				var docs: Variant = json_dict["docs"]
				if docs is Array:
					var docs_array := docs as Array
					# resume covers a newer page interrupted, rather than skipping them
					_current_cover_to_download = mini(_current_cover_to_download, song_data.size())
					for i: Variant in docs_array:
						if not i is Dictionary: continue
						var parsed_song := BeatSaverSongInfo.new(i as Dictionary)
						if not parsed_song.is_playable() or (prev_request.type != "uploader" and not parsed_song.passes_reaction_filter()):
							continue
						var index := item_list.add_item(parsed_song.name)
						item_list.set_item_icon(index, placeholder_cover)
						var tooltip := "Map author: %s" % parsed_song.level_author_name
						item_list.set_item_tooltip(index, tooltip)
						song_data.append(parsed_song)
						item_list.set_item_disabled(index, main_menu_ref.all_song_hashes.has(parsed_song.versions[0]["hash"]))
						item_list.set_item_metadata(index, parsed_song.versions[0]["hash"])

	else:
		vr.log_error("request error "+str(result))
	back_button.visible = prev_request != null and prev_request.type == "uploader" and back_stack.size() > 0
	_scroll_page_request_pending = false
	
	var canvas := get_parent().get_parent()
	if canvas is OQ_UI2DCanvas: (canvas as OQ_UI2DCanvas)._input_update()
	
	_update_all_covers()
	_fill_reaction_filtered_list()

## Most items the list fetches pages for on its own while the reaction time filter hides songs.
const REACTION_FILL_ITEMS := 20
## Most pages fetched on their own in a row, so a rare reaction time can't keep requesting forever.
const REACTION_FILL_PAGES := 10

## BeatSaver can't filter by reaction time, so it is applied to each page after it arrives and a page
## can show few or no songs; fetch the next pages until the list has enough songs to scroll.
func _fill_reaction_filtered_list() -> void:
	if Settings.song_filter_reaction == 0 or prev_request == null or prev_request.type == "uploader":
		return
	if next_page_available == -1 or item_list.item_count >= REACTION_FILL_ITEMS or prev_request.page >= REACTION_FILL_PAGES:
		return
	prev_request.page += 1
	update_list(prev_request)
	_scroll_page_request_pending = true


## Lists every map in one sort order, leaving any search.
func _on_sort_tab_pressed(sort_order: String) -> void:
	_set_search("")
	back_stack.clear()
	prev_request = BeatSaverRequest.new()
	prev_request.page = 0
	prev_request.type = "list"
	prev_request.data = sort_order
	update_list(prev_request)

## Shows the search text on the search button (with a clear button) and lights the sort tabs only when
## there is no search.
func _set_search(text: String) -> void:
	search_word = text
	search_button.text = text if not text.is_empty() else "Search songs"
	clear_search_button.visible = not text.is_empty()
	if not text.is_empty():
		var pressed := (sort_tabs.get_child(0) as Button).button_group.get_pressed_button()
		if pressed:
			pressed.set_pressed_no_signal(false)

## Clears the search and goes back to the Popular list.
func _on_clear_search_pressed() -> void:
	var popular := sort_tabs.get_child(0) as Button
	popular.set_pressed_no_signal(true)
	_on_sort_tab_pressed(SORT_TABS[0][1])


func _on_ItemList_item_selected(index: int) -> void:
	item_selected = index
	var selected_data := _get_selected_song()
	var dur_s := int(selected_data.duration)
	var version = selected_data.versions[0]
	goto_maps_by.text = "Maps by %s" % selected_data.level_author_name
	goto_maps_by.visible = true
	var difficulties := ""
	for diff in version['diffs']:
		var diff_name := str(diff.get('difficulty', ""))
		var diff_color: Color = Constants.DIFFICULTY_COLORS.get(diff_name, Constants.UI_TEXT)
		if diff is Dictionary and selected_data.bpm > 0.0:
			var reaction := selected_data.reaction_seconds(diff as Dictionary)
			diff_name += " · Notes appear %.2f s ahead" % reaction
		difficulties += "\n[color=#%s]%s[/color]" % [diff_color.to_html(false), diff_name]
	var text := """[center]%s By %s[/center]

Map author: %s
Duration: %dm %ds
Difficulties:%s

[center]Description:[/center]
%s""" % [
		selected_data.song_name,
		selected_data.song_author_name,
		selected_data.level_author_name,
		dur_s/60,dur_s%60,
		difficulties,
		selected_data.description,
	]
	($song_data as RichTextLabel).text = text
	
	($TextureRect as TextureRect).texture = item_list.get_item_icon(index)

	if Settings.audio_master > 0 and Settings.audio_music_preview > 0:
		# the click means the player wants this map's preview: quiet the local song now
		main_menu_ref.stop_preview()
		httppreviewdownload.cancel_request()
		_preview_url = version['previewURL']
		if _preview_cache.has(_preview_url):
			_play_preview(_preview_cache[_preview_url])
		elif httppreviewdownload.request(_preview_url) != OK:
			vr.log_warning("Preview request failed: %s" % _preview_url)

func _on_download_button_up() -> void:
	OS.request_permissions()
	if item_selected == -1: return
	var version_info = song_data[item_selected].versions[0]
	downloading.insert(downloading.size(),[song_data[item_selected].name,version_info])
	download_next()
	item_list.set_item_disabled(item_selected, true)

func download_next() -> void:
	if downloading.size() > 0:
		httpdownload.request(downloading[0][1]['downloadURL'])
		label.text = "Downloading: %s - %d left" % [str(downloading[0][0]),downloading.size()-1]
		label.visible = true

func _on_HTTPRequest_download_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
#	$download.disabled = false
	if body.slice(0, 10) == "<!DOCTYPE html>".to_utf8_buffer().slice(0, 10):
		result = -1
	if result == 0:
		var has_error := false
		var tempdir := Constants.APPDATA_PATH+"temp"
		DirAccess.remove_absolute(tempdir)
		var error := DirAccess.make_dir_recursive_absolute(tempdir)
		if error != OK: 
			vr.log_error(
				"_on_HTTPRequest_download_completed - " +
				"Failed to create temp directory '%s'" % tempdir)
			has_error = true
		
		# use hash as song directory, so there are no clashes with the same name or
		# issues with special characters in names
		var song_dir_name: String = downloading[0][1]["hash"]

		var zippath := Constants.APPDATA_PATH+"temp/%s.zip"%song_dir_name
		if not has_error:
			var file := FileAccess.open(zippath,FileAccess.WRITE)
			if file:
				file.store_buffer(body)
				file.close()
			else:
				vr.log_file_error(FileAccess.get_open_error(), zippath, "BeatSaverPanel.gd at line 261")
				has_error = true
		
		var song_out_dir := Constants.APPDATA_PATH+("Songs/%s/"%song_dir_name)
		if not has_error:
			DirAccess.remove_absolute(song_out_dir)
			error = DirAccess.make_dir_recursive_absolute(song_out_dir)
			if error != OK: 
				vr.log_error(
					"_on_HTTPRequest_download_completed - " +
					"Failed to create song output dir '%s'" % song_out_dir)
				has_error = true
		
		if not has_error:
			Utils.unzip(zippath,song_out_dir)
		
		DirAccess.remove_absolute(zippath)
		
		downloading.remove_at(0)
		
		if not downloading.size() > 0:
			main_menu_ref._on_LoadPlaylists_Button_pressed()
			label.text = "All downloaded"
	else:
		label.text = "Download error "+str(result)
		if result == -1:
			label.text += "\nInvalid URL or server is down"
		vr.log_info("download error "+str(result))
		downloading.remove_at(0)
	
	var canvas := get_parent().get_parent()
	if canvas is OQ_UI2DCanvas:
		(canvas as OQ_UI2DCanvas)._input_update()
	download_next()

func _on_preview_download_completed(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == 0:
		_preview_cache[_preview_url] = body
		if _preview_cache.size() > MAX_CACHED_PREVIEWS:
			_preview_cache.erase(_preview_cache.keys()[0])
		_play_preview(body)

## Asks the main menu to play a BeatSaver preview.
func _play_preview(body: PackedByteArray) -> void:
	main_menu_ref.play_preview(
		body, # song data buffer
		0,    # start previous at time 0
		-1,   # play preview song for entire duration
		'mp3')# bsaver has all it's previews in mp3 format for now

func _on_search_button_up() -> void:
	keyboard._show()
	keyboard._text_edit.grab_focus()

func _text_input_enter(text: String) -> void:
	keyboard._hide()
	if text.strip_edges().is_empty():
		_on_clear_search_pressed()
		return
	_set_search(text.strip_edges())
	back_stack.clear()
	prev_request = BeatSaverRequest.new()
	prev_request.page = 0
	prev_request.type = "text_search"
	prev_request.data = search_word
	update_list(prev_request)

func _text_input_cancel() -> void:
	keyboard._hide()


var _current_cover_to_download := 0

func _update_all_covers() -> void:
	httpcoverdownload.cancel_request()
	update_next_cover()

func update_next_cover() -> void:
	if _current_cover_to_download < song_data.size():
		var cover_url := _get_cover_url_from_song_data(song_data[_current_cover_to_download])
		
		if cover_url == "":
			# song didn't have a cover. skip this cover and move to next one
			_current_cover_to_download += 1
			update_next_cover()
		else:
			httpcoverdownload.request(cover_url)

func _update_cover(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == 0:
		var img := Image.new()
		if not img.load_jpg_from_buffer(body) == 0:
			img.load_png_from_buffer(body)
		var img_tex := ImageTexture.create_from_image(img)
		item_list.set_item_icon(_current_cover_to_download,img_tex)
	_current_cover_to_download += 1
	
	var canvas := get_parent().get_parent()
	if canvas is OQ_UI2DCanvas: (canvas as OQ_UI2DCanvas)._input_update()
	
	update_next_cover()

func _on_gotoMapsBy_pressed() -> void:
	var selected_song := _get_selected_song()
	if selected_song.uploader_id == -1: return
	_add_to_back_stack(prev_request)
	prev_request = BeatSaverRequest.new()
	prev_request.page = 0
	prev_request.type = "uploader"
	prev_request.data = str(selected_song.uploader_id)
	update_list(prev_request)
	
# SCROLL_TO_FETCH_THRESHOLD
# Range: 0.0 to 1.0
# Description: Used to request the next page of songs from the current list
# once the user scrolls past this threshold
const SCROLL_TO_FETCH_THRESHOLD := 0.9
var _scroll_page_request_pending := false

func _on_ListV_Scroll_value_changed(new_value: float) -> void:
	var scroll_range := v_scroll.max_value - v_scroll.min_value
	var scroll_ratio := (new_value + v_scroll.page) / scroll_range
	if scroll_ratio > SCROLL_TO_FETCH_THRESHOLD:
		if next_page_available == -1:
			# no next page to load
			return
		
		# prevent back to back requests
		if _scroll_page_request_pending:
			return
		
		# request next page and update list
		prev_request.page += 1
		update_list(prev_request)
		_scroll_page_request_pending = true

func _on_back_pressed() -> void:
	if back_stack.is_empty():
		return
	
	# re-request latest entry
	prev_request = back_stack.back()
	prev_request.page = 0
	back_stack.pop_back()
	update_list(prev_request)
	back_button.visible = false

func _get_cover_url_from_song_data(song_info: BeatSaverSongInfo) -> String:
	var song_versions := song_info.versions
	var version_data := {}
	if len(song_versions) == 1:
		version_data = song_versions[0]# is there always 1 version?!?
	elif len(song_versions) > 1:
		vr.log_warning("The are %d versions for this song, but only getting cover for the first. song_data = %s" % [len(song_versions),song_data])
		version_data = song_versions[0]
	else:
		vr.log_warning("No version info available in song_data: %s" % song_data)
		return ""
		
	return version_data['coverURL']

func _on_CloseButton_pressed() -> void:
	self._hide()

var _is_first_show := true
func _on_BeatSaverPanel_visibility_changed() -> void:
	if _is_first_show:
		# start on the most liked maps
		_on_sort_tab_pressed(SORT_TABS[0][1])
		_is_first_show = false
