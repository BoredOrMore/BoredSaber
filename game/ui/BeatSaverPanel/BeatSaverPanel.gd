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
	## Share of players who liked the map, 0 to 1 (BeatSaver's rating score).
	var score: float
	## Picked by BeatSaver's staff.
	var curated: bool
	var tags: PackedStringArray

	func _init(song_info: Dictionary) -> void:
		name = Utils.get_str(song_info, "name", "")
		description = Utils.get_str(song_info, "description", "")
		versions = Utils.get_array(song_info, "versions", [])
		automapper = bool(song_info.get("automapper", false))
		score = Utils.get_float(Utils.get_dict(song_info, "stats", {}), "score", 0.0)
		curated = song_info.get("curatedAt") != null
		tags = PackedStringArray(Utils.get_array(song_info, "tags", []))
		# difficulties that need a mod this game doesn't have (Noodle Extensions, Mapping Extensions,
		# Vivify) don't play right here, and ones too tangled to swing aren't listed, so both are left out
		if not versions.is_empty() and versions[0] is Dictionary:
			var version := versions[0] as Dictionary
			version["diffs"] = Utils.get_array(version, "diffs", []).filter(func(diff: Variant) -> bool:
				return diff is Dictionary and not (diff.get("ne", false) or diff.get("me", false) or diff.get("vivify", false)) \
					and parity_percent(diff as Dictionary) < Constants.FLOW_HIDDEN_PERCENT)
		uploader_id = int(Utils.get_float(Utils.get_dict(song_info, "uploader", {}), "id", -1))
		var metadata := Utils.get_dict(song_info, "metadata", {})
		song_name = Utils.get_str(metadata, "songName", "")
		song_author_name = Utils.get_str(metadata, "songAuthorName", "")
		level_author_name = Utils.get_str(metadata, "levelAuthorName", "")
		duration = Utils.get_float(metadata, "duration", 0.0)
		bpm = Utils.get_float(metadata, "bpm", 0.0)

	## BeatSaver's count of swings that break the flow (parity errors, warnings and resets) as a percent of the
	## notes; it follows MapStats' swing flow percent (doc/research/swing-flow.md), so the same bands apply.
	static func parity_percent(diff: Dictionary) -> float:
		var notes := Utils.get_float(diff, "notes", 0.0)
		if notes <= 0.0:
			return 0.0
		var parity := Utils.get_dict(diff, "paritySummary", {})
		return 100.0 * (Utils.get_float(parity, "errors", 0.0) + Utils.get_float(parity, "warns", 0.0)
			+ Utils.get_float(parity, "resets", 0.0)) / notes

	## Median same-hand swing gap over 2 / notes per second (each hand takes about half the notes): 0.84 over the
	## test headset's 77 Standard difficulties (doc/research/flow_research.py), refit to 0.82 against the measured
	## levels of 195 (doc/research/download-level-estimate.md). Stacks and chains make it a little under 1.
	const SWING_GAP_PER_NOTE_GAP := 0.82

	## Difficulty a map difficulty plays at before it is downloaded (an index in Constants.DIFFICULTY_LEVELS): the
	## harder of its reaction time and its swing pace estimated from notes per second. Downloaded maps use the measured
	## swing gap and swing flow instead (MapStats.level_of). Against them (doc/research/download-level-estimate.md, 195
	## difficulties of the headset's 53 songs and the Mac's 18) it matches 73%, within one level 95%; BeatSaver's
	## parity count no longer adds a level (67% with it). Most misses read easier: dense bursts the average hides.
	func level_of(diff: Dictionary) -> int:
		var level := MapStats.reaction_level(reaction_seconds(diff))
		var nps := Utils.get_float(diff, "nps", 0.0)
		if nps > 0.0:
			level = maxi(level, MapStats.swing_pace_level(SWING_GAP_PER_NOTE_GAP * 2.0 / nps / MapStats._speed()))
		return mini(level, Constants.DIFFICULTY_LEVELS.size() - 1)

	## Seconds a note of one difficulty (from versions[0].diffs) is visible before reaching the player.
	func reaction_seconds(diff: Dictionary) -> float:
		return MapStats.reaction_seconds_for(bpm, Utils.get_float(diff, "njs", 0.0), Utils.get_float(diff, "offset", 0.0))

	## Hash of the newest version, which is also its folder name once downloaded.
	func get_hash() -> String:
		return Utils.get_str(versions[0] as Dictionary, "hash", "") if not versions.is_empty() else ""

	## True if the map can be played here: made by a person, with a Standard difficulty that needs no mod.
	func is_playable() -> bool:
		if automapper or versions.is_empty():
			return false
		for diff: Variant in Utils.get_array(versions[0] as Dictionary, "diffs", []):
			if Utils.get_str(diff as Dictionary, "characteristic", "") == "Standard":
				return true
		return false

	## True if the level filter is off or a Standard difficulty of the newest version plays at the picked level
	## (level_of).
	func passes_reaction_filter() -> bool:
		var level := BeatSaverPanel.picked_level()
		return level < 0 or estimated_levels().has(level)

	## The levels (indices in Constants.DIFFICULTY_LEVELS) of the newest version's Standard difficulties.
	func estimated_levels() -> Array:
		var levels := []
		if versions.is_empty():
			return levels
		for diff: Variant in Utils.get_array(versions[0] as Dictionary, "diffs", []):
			if diff is Dictionary and Utils.get_str(diff as Dictionary, "characteristic", "Standard") == "Standard":
				levels.append(level_of(diff as Dictionary))
		return levels

var song_data: Array[BeatSaverSongInfo] = []
# reference to the main main node (used for playing downloadable song previews)
@export var main_menu_ref: MainMenu
# the next requestable pages for the current list; -1 if prev/next page is
# not requestable (ie. reached end of the list)
var prev_page_available := -1
var next_page_available := -1
## Style chips and genres: [label, BeatSaver tag], "" meaning any.
const STYLES := [["Any", ""], ["Dance", "dance-style"], ["Fitness", "fitness"], ["Accuracy", "accuracy"],
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
var downloading := []#[["name","version_info", tags]]
## Most previews kept in memory, so clicking a map again plays at once.
const MAX_CACHED_PREVIEWS := 10
## Tries again after a failed list request before showing the error (the headset sometimes fails to connect
## once, e.g. "request error 2"). Seconds to wait before each try.
const LIST_RETRIES := 2
const LIST_RETRY_SECONDS := 1.0
var _list_retries_left := LIST_RETRIES
## The level filter (owner, 2026-10-27): "Any level" or one level, matched exactly (a map shows when one of its
## difficulties plays at that level), kept per player in Settings.beatsaver_filter_reaction (0 any, 1 + level).
const ANY_LEVEL_TEXT := "Any level"
## The details list a map's levels and its words; Details opens the rest (reaction time, flow, walls, description).
const DETAILS_TEXT := "Details"

## The picked level (an index in Constants.DIFFICULTY_LEVELS), or -1 for any.
static func picked_level() -> int:
	var id := Settings.beatsaver_filter_reaction
	return id - 1 if id > 0 and id <= Constants.DIFFICULTY_LEVELS.size() else -1

## BeatSaver's notes-per-second window for a level, so its pages come back with maps near it (the level is the
## harder of reaction time and the swing pace from notes per second, so the window is the pace's): [min, max], 0 for
## no bound.
static func nps_window(level: int) -> Vector2:
	var thresholds := Constants.DIFFICULTY_LEVELS.map(func(l: Array) -> float: return float(l[3]))
	var k := BeatSaverSongInfo.SWING_GAP_PER_NOTE_GAP * 2.0 / MapStats._speed()
	var low: float = k / thresholds[level - 1] if level > 0 else 0.0
	var high: float = k / thresholds[level] if thresholds[level] > 0.0 else 0.0
	return Vector2(low, high)

## Icons of the big button: download, or play once the song is in the library.
const DOWNLOAD_ICON := preload("res://game/ui/icons/download.svg")
const PLAY_ICON := preload("res://game/ui/icons/play.svg")
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
@onready var download_button := $download as Button
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
	for item_index in mini(item_list.item_count, song_data.size()):
		item_list.set_item_text(item_index, _card_text(song_data[item_index]))
	_update_download_button()

## True if the map is already in the song list.
func _in_library(song: BeatSaverSongInfo) -> bool:
	return main_menu_ref.all_song_hashes.has(song.get_hash())

## The map in the library, or null.
func _local_map(song: BeatSaverSongInfo) -> MapInfo:
	var hash := song.get_hash().to_lower()
	for info: MapInfo in main_menu_ref._all_songs:
		if info.filepath.trim_suffix("/").get_file().to_lower() == hash:
			return info
	return null

## The map's levels: measured once it is in the library, else BeatSaver's estimate; [levels, estimated].
func _levels(song: BeatSaverSongInfo) -> Array:
	var info := _local_map(song) if _in_library(song) else null
	if info == null:
		return [song.estimated_levels(), true]
	var levels := []
	for difficulty in info.difficulty_beatmaps:
		if difficulty.characteristic == "" or difficulty.characteristic == "Standard":
			levels.append(MapStats.level_of(info, difficulty, MapStats.get_stats(info, difficulty)))
	return [levels, false]

## A cover with the map's level strip (LevelStrip).
func _with_levels(cover: Image, song: BeatSaverSongInfo) -> ImageTexture:
	var levels := _levels(song)
	return LevelStrip.compose(cover, levels[0], picked_level(), levels[1])

## A title cut to fit one line of a card, ending in "…"; the details panel shows it whole.
func _one_line(title: String) -> String:
	var font := item_list.get_theme_font("font")
	var font_size := item_list.get_theme_font_size("font_size")
	var room := float(item_list.fixed_column_width)
	if font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= room:
		return title
	while title.length() > 1 and font.get_string_size(title + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		title = title.left(-1)
	return title.strip_edges() + "…"

## A map's card under its cover (its levels are on the cover): title and length, then whether staff picked it or it
## is already downloaded.
func _card_text(song: BeatSaverSongInfo) -> String:
	var seconds := int(song.duration)
	var text := "%s\n%d:%02d" % [_one_line(song.name), seconds / 60, seconds % 60]
	if _in_library(song):
		text += "\n✓ In library"
	elif song.curated:
		text += "\n★ Staff pick"
	return text

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
	
	reaction_filter.add_item(ANY_LEVEL_TEXT)
	for level: Array in Constants.DIFFICULTY_LEVELS:
		reaction_filter.add_item(level[0])
	LevelStrip.prepare(self)
	_add_details_toggle()
	_make_details_box()
	for filter: Array in Constants.LENGTH_FILTERS:
		length_filter.add_item(filter[1])
	_sync_filter_controls()
	Settings.changed.connect(_on_settings_changed)

## Shows the saved song filters in the dropdowns.
func _sync_filter_controls() -> void:
	reaction_filter.select(picked_level() + 1)
	length_filter.select(MapStats.length_filter(Settings.beatsaver_filter_length)[0])

## BeatSaver search parameters for the picked style and genre (both must match) and the saved length filter,
## or "" when all are off.
func _filter_query() -> String:
	var length := MapStats.length_filter(Settings.beatsaver_filter_length)
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
	if picked_level() >= 0:
		var window := nps_window(picked_level())
		if window.x > 0.0:
			query += "&minNps=%.2f" % window.x
		if window.y > 0.0:
			query += "&maxNps=%.2f" % window.y
	return query

## Follows filter changes and reloads the current list with them.
func _on_settings_changed(key: StringName) -> void:
	if key != &"beatsaver_filter_reaction" and key != &"beatsaver_filter_length":
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
	Settings.beatsaver_filter_reaction = index

## Stores the picked length filter.
func _on_length_filter_item_selected(index: int) -> void:
	Settings.beatsaver_filter_length = Constants.LENGTH_FILTERS[index][0]

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
		label.text = "Loading songs…"
		if goto_maps_by:
			goto_maps_by.visible = false
		song_data = []
		item_selected = -1
		if _song_text:
			_song_text.text = "Pick a song to see what it plays like."
			StatPills.fill(_level_rows, [])
		($TextureRect as TextureRect).texture = placeholder_cover
		_update_download_button()
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
						var index := item_list.add_item(_card_text(parsed_song))
						item_list.set_item_icon(index, _with_levels(placeholder_cover.get_image(), parsed_song))
						item_list.set_item_tooltip_enabled(index, false)
						song_data.append(parsed_song)

	elif _list_retries_left > 0 and prev_request != null:
		_list_retries_left -= 1
		vr.log_warning("BeatSaver list request failed (result %d), trying again" % result)
		await get_tree().create_timer(LIST_RETRY_SECONDS).timeout
		update_list(prev_request)
		return
	else:
		vr.log_error("request error "+str(result))
		label.text = "Can't reach BeatSaver. Check your Wi-Fi."
	_list_retries_left = LIST_RETRIES
	back_button.visible = prev_request != null and prev_request.type == "uploader" and back_stack.size() > 0
	_scroll_page_request_pending = false
	
	var canvas := get_parent().get_parent()
	if canvas is OQ_UI2DCanvas: (canvas as OQ_UI2DCanvas)._input_update()
	
	_update_all_covers()
	_fill_reaction_filtered_list()
	if result == 0:
		if item_list.item_count > 0:
			label.text = ""
		elif not _scroll_page_request_pending:
			label.text = "No songs match. Try another style."

## Most items the list fetches pages for on its own while the reaction time filter hides songs.
const REACTION_FILL_ITEMS := 20
## Most pages fetched on their own in a row, so a rare reaction time can't keep requesting forever.
const REACTION_FILL_PAGES := 10

## BeatSaver can't filter by reaction time, so it is applied to each page after it arrives and a page
## can show few or no songs; fetch the next pages until the list has enough songs to scroll.
func _fill_reaction_filtered_list() -> void:
	if picked_level() < 0 or prev_request == null or prev_request.type == "uploader":
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
	var version: Dictionary = selected_data.versions[0]
	goto_maps_by.text = "More by %s" % selected_data.level_author_name
	_details_toggle.visible = true
	goto_maps_by.visible = selected_data.uploader_id != -1 and prev_request != null and prev_request.type != "uploader"
	_show_details(selected_data)
	($TextureRect as TextureRect).texture = item_list.get_item_icon(index)
	_update_download_button()

	if Settings.audio_master > 0 and Settings.audio_music_preview > 0:
		# the click means the player wants this map's preview: quiet the local song now
		main_menu_ref.stop_preview()
		httppreviewdownload.cancel_request()
		_preview_url = version['previewURL']
		if _preview_cache.has(_preview_url):
			_play_preview(_preview_cache[_preview_url])
		elif httppreviewdownload.request(_preview_url) != OK:
			vr.log_warning("Preview request failed: %s" % _preview_url)

## The picked map in plain words: title, artist and mapper, how liked it is, its tags, each difficulty and
## the start of its description.
func _details_text(song: BeatSaverSongInfo) -> String:
	if not _details_toggle.button_pressed:
		return _short_details_text(song)
	var muted := Constants.UI_TEXT_MUTED.to_html(false)
	var seconds := int(song.duration)
	var text := "[b]%s[/b]\n%s\n[color=#%s]Mapped by %s · %d%% liked · %d:%02d[/color]" % [
		_escape(song.song_name), _escape(song.song_author_name), muted, _escape(song.level_author_name),
		roundi(song.score * 100.0), seconds / 60, seconds % 60]
	var tag_names := PackedStringArray()
	for tag in song.tags:
		tag_names.append(_tag_name(tag))
	if not tag_names.is_empty():
		text += "\n[color=#%s]%s[/color]" % [muted, " · ".join(tag_names)]
	text += "\n"
	for diff: Variant in Utils.get_array(song.versions[0] as Dictionary, "diffs", []):
		var d := diff as Dictionary
		var level: Array = Constants.DIFFICULTY_LEVELS[song.level_of(d)]
		var line: String = level[0]
		if Utils.get_str(d, "characteristic", "Standard") != "Standard":
			line += " · %s" % Utils.get_str(d, "characteristic", "")
		if song.bpm > 0.0:
			line += " · Notes %.2f s ahead" % song.reaction_seconds(d)
		var flow := MapStats.flow_level(BeatSaverSongInfo.parity_percent(d))
		if flow > 0:
			line += " · %s" % Constants.FLOW_LEVELS[flow][0]
		var walls := int(Utils.get_float(d, "obstacles", 0))
		if walls > 0:
			line += " · %d walls" % walls
		text += "\n[color=#%s]%s[/color]" % [(level[1] as Color).to_html(false), line]
	var description := song.description.strip_edges()
	if not description.is_empty():
		var lines := description.split("\n", false)
		var shown := "\n".join(lines.slice(0, DESCRIPTION_LINES))
		if lines.size() > DESCRIPTION_LINES:
			shown += " …"
		text += "\n\n[color=#%s]%s[/color]" % [muted, _escape(shown)]
	return text

## The picked map in a few words: title and artist, mapper and length; _level_row_controls adds each Standard
## difficulty under it. Details shows the rest.
func _short_details_text(song: BeatSaverSongInfo) -> String:
	var muted := Constants.UI_TEXT_MUTED.to_html(false)
	var seconds := int(song.duration)
	return "[b]%s[/b]\n%s\n[color=#%s]Mapped by %s · %d:%02d[/color]" % [_escape(song.song_name),
		_escape(song.song_author_name), muted, _escape(song.level_author_name), seconds / 60, seconds % 60]

## Each Standard difficulty as a rounded bar in its level's colour and name ("≈" while estimated) over its stats
## pills (StatPills: time to get ready, notes per second, swing flow), measured once the map is in the library;
## then what "≈" means.
func _level_row_controls(song: BeatSaverSongInfo) -> Array[Control]:
	var controls: Array[Control] = []
	var rows := _difficulty_rows(song)
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var estimated := _local_map(song) == null
	for row: Array in rows:
		var entry: Array = Constants.DIFFICULTY_LEVELS[row[0]]
		var bar := PanelContainer.new()
		bar.theme_type_variation = &"LevelBar"
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var colored := bar.get_theme_stylebox(&"panel", &"LevelBar").duplicate() as StyleBoxFlat
		colored.bg_color = entry[1]
		bar.add_theme_stylebox_override(&"panel", colored)
		var level_name := Label.new()
		level_name.text = "%s%s" % [entry[0], " ≈" if estimated else ""]
		level_name.add_theme_font_size_override(&"font_size", LEVEL_BAR_SIZE)
		level_name.add_theme_color_override(&"font_color", Constants.UI_PANEL)
		bar.add_child(level_name)
		controls.append(bar)
		var pills := StatPills.flow()
		pills.alignment = FlowContainer.ALIGNMENT_BEGIN
		StatPills.fill(pills, StatPills.difficulty(row[1], row[2], row[3], PILL_ICON_SIZE))
		controls.append(pills)
	if estimated:
		var hint := Label.new()
		hint.text = ESTIMATE_HINT
		hint.add_theme_font_size_override(&"font_size", 22)
		hint.add_theme_color_override(&"font_color", Constants.UI_TEXT_MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		controls.append(hint)
	return controls

## The details' text and, in the short details, the level rows under it, in one column where song_data stood.
var _song_text: RichTextLabel
var _level_rows := VBoxContainer.new()

func _make_details_box() -> void:
	_song_text = $song_data as RichTextLabel
	var box := VBoxContainer.new()
	box.position = _song_text.position
	box.size = _song_text.size
	box.add_theme_constant_override(&"separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_song_text.reparent(box)
	_song_text.fit_content = true
	box.add_child(_level_rows)
	_level_rows.add_theme_constant_override(&"separation", 8)

func _show_details(song: BeatSaverSongInfo) -> void:
	_song_text.text = _details_text(song)
	StatPills.fill(_level_rows, [] if _details_toggle.button_pressed else _level_row_controls(song))

## Icons in the details' pills, the size of their 22 px text.
const PILL_ICON_SIZE := 24

## Each Standard difficulty as [level, seconds to get ready, notes per second, flow percent]: measured from the map
## file once it is in the library (MapStats), else from BeatSaver's data.
func _difficulty_rows(song: BeatSaverSongInfo) -> Array:
	var rows := []
	var info := _local_map(song)
	if info != null:
		for difficulty in info.difficulty_beatmaps:
			if difficulty.characteristic == "" or difficulty.characteristic == "Standard":
				var stats := MapStats.get_stats(info, difficulty)
				rows.append([MapStats.level_of(info, difficulty, stats), MapStats.reaction_seconds(info, difficulty),
					float(stats.get("nps", 0.0)) * MapStats._speed(), float(stats.get("flow", 0.0))])
		return rows
	if song.versions.is_empty():
		return rows
	for diff: Variant in Utils.get_array(song.versions[0] as Dictionary, "diffs", []):
		var d := diff as Dictionary
		if Utils.get_str(d, "characteristic", "Standard") == "Standard":
			rows.append([song.level_of(d), song.reaction_seconds(d), Utils.get_float(d, "nps", 0.0) * MapStats._speed(),
				BeatSaverSongInfo.parity_percent(d)])
	return rows

## What "≈" means, under the level bars of a map not yet downloaded.
const ESTIMATE_HINT := "≈ about: measured once downloaded"

## The level bars' text size in the short details: at the page's 2 m about 1.85 degrees (vr-ui-design).
const LEVEL_BAR_SIZE := 34
var _details_toggle := Button.new()

## Details beside "More by", halving its width: opens and closes the long details.
func _add_details_toggle() -> void:
	var half := (goto_maps_by.size.x - 12.0) / 2.0
	_details_toggle.text = DETAILS_TEXT
	_details_toggle.toggle_mode = true
	_details_toggle.position = goto_maps_by.position + Vector2(half + 12.0, 0.0)
	_details_toggle.size = Vector2(half, goto_maps_by.size.y)
	_details_toggle.add_theme_font_size_override(&"font_size", 22)
	_details_toggle.visible = false
	_details_toggle.toggled.connect(func(_on: bool) -> void:
		var song := _get_selected_song()
		if song != null:
			_show_details(song))
	add_child(_details_toggle)
	UI_AudioEngine.attach_button(_details_toggle)
	goto_maps_by.size.x = half

## Most description lines the details show.
const DESCRIPTION_LINES := 3

## Text with BBCode brackets made harmless.
static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")

## A BeatSaver tag in the words the style chips and genre list use, else the tag with spaces.
static func _tag_name(tag: String) -> String:
	for entry: Array in STYLES + GENRES:
		if entry[1] == tag:
			return entry[0]
	return tag.replace("-", " ").capitalize()

## The big button under the details: Download, its progress while downloading, or Play now once the map is in
## the song list.
func _update_download_button() -> void:
	var song := _get_selected_song()
	download_button.visible = song != null
	if song == null:
		return
	var hash := song.get_hash()
	download_button.icon = PLAY_ICON if _in_library(song) else DOWNLOAD_ICON
	if _in_library(song):
		download_button.text = "In library · Play now"
	elif not downloading.is_empty() and Utils.get_str(downloading[0][1] as Dictionary, "hash", "") == hash:
		var total := httpdownload.get_body_size()
		var done := httpdownload.get_downloaded_bytes()
		download_button.text = "Downloading %d%%" % (100 * done / total) if total > 0 else "Downloading…"
	elif downloading.any(func(entry: Array) -> bool: return Utils.get_str(entry[1] as Dictionary, "hash", "") == hash):
		download_button.text = "Waiting to download"
	else:
		download_button.text = "Download"

## Keeps the download progress on the button current.
func _process(_delta: float) -> void:
	if downloading.is_empty():
		return
	var before := download_button.text
	_update_download_button()
	if download_button.text != before:
		var canvas := get_parent().get_parent()
		if canvas is OQ_UI2DCanvas: (canvas as OQ_UI2DCanvas)._input_update()

## Downloads the picked map, or once it is in the song list, picks it there and closes this page.
func _on_download_button_up() -> void:
	var song := _get_selected_song()
	if song == null: return
	if _in_library(song):
		if main_menu_ref.show_song(song.get_hash()):
			_hide()
		return
	var hash := song.get_hash()
	if downloading.any(func(entry: Array) -> bool: return Utils.get_str(entry[1] as Dictionary, "hash", "") == hash):
		return
	OS.request_permissions()
	downloading.append([song.name, song.versions[0], song.tags])
	if downloading.size() == 1:
		download_next()
	_update_download_button()

func download_next() -> void:
	if downloading.size() > 0:
		httpdownload.request(downloading[0][1]['downloadURL'])

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
			SongTags.remember(song_dir_name, downloading[0][2])
		
		DirAccess.remove_absolute(zippath)
		
		downloading.remove_at(0)
		
		if not downloading.size() > 0:
			main_menu_ref._on_LoadPlaylists_Button_pressed()
	else:
		label.text = "Couldn't download %s. Check your Wi-Fi and try again." % str(downloading[0][0])
		vr.log_info("download error "+str(result))
		downloading.remove_at(0)
	_update_download_button()
	
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
		if _current_cover_to_download < song_data.size():
			item_list.set_item_icon(_current_cover_to_download, _with_levels(img, song_data[_current_cover_to_download]))
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
## Makes sure the page always opens with songs listed: the most liked maps the first time, and the last list
## again if it came back empty (e.g. no connection when it last loaded).
func _on_BeatSaverPanel_visibility_changed() -> void:
	if _is_first_show:
		# start on the most liked maps
		_on_sort_tab_pressed(SORT_TABS[0][1])
		_is_first_show = false
	elif item_list.item_count == 0 and httpreq.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		if prev_request != null and prev_request.type != "uploader":
			_reload()
		else:
			_on_sort_tab_pressed(SORT_TABS[0][1])
