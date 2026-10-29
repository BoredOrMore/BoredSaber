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
## song folders downloaded since the queue last ran empty, added to the song list together then
var _downloaded: Array[String] = []
## Most previews kept in memory, so clicking a map again plays at once.
const MAX_CACHED_PREVIEWS := 10
## Tries again after a failed list request before showing the error (the headset sometimes fails to connect
## once, e.g. "request error 2"). Seconds to wait before each try.
const LIST_RETRIES := 2
const LIST_RETRY_SECONDS := 1.0
var _list_retries_left := LIST_RETRIES
## The level filter (owner, 2026-10-27): any difficulty (Constants.ANY_DIFFICULTY_LABEL, the song menu's word) or one
## level, matched exactly (a map shows when one of its difficulties plays at that level), kept per player in
## Settings.beatsaver_filter_reaction (0 any, 1 + level).
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
const CLEAR_ICON := preload("res://game/ui/icons/x.svg")
## The sort button while a search lists maps by how well they match.
const BEST_MATCH_TEXT := "Best match"
## The Filters button, with how many filters are on; the chip that stands for several filters when their chips don't
## fit above the list; the chip of the mapper list "More by" opened (its x goes back to the list before).
const FILTERS_TEXT := "Filters"
const FILTERS_ON_TEXT := "Filters · %d"
const SOME_FILTERS_TEXT := "%d filters"
const MAPPER_CHIP_TEXT := "By %s"
## Most letters of the search shown on its chip, before "…".
const SEARCH_CHIP_LETTERS := 16
## The x on a chip, px.
const CHIP_ICON_SIZE := 24
## A map's cover in the list (BeatSaverList.COVER_SIZE) and in the details, px. Only the picked map's big cover is
## fetched (DetailCoverDownload), so the list keeps 20 KB per map instead of 160 KB (owner, 2026-10-29, layout A).
const DETAIL_COVER := 152
## Preview mp3 bytes by preview URL, oldest first.
var _preview_cache := {}
## URL of the preview being downloaded.
var _preview_url := ""

@onready var item_list := $ItemList as BeatSaverList
@onready var sort_button := $SortButton as OptionButton
@onready var search_button := $search as Button
@onready var filters_button := $Filters_Button as Button
@onready var filters_panel := $FiltersPanel as Panel
@onready var chip_row := $ChipRow as HBoxContainer
@onready var source_label := $ChipRow/Source as Label
@onready var empty_list := $EmptyList as Label
@onready var label := $Label as Label
@onready var cover_rect := $TextureRect as TextureRect
@onready var title_label := $Head/Title as Label
@onready var artist_label := $Head/Artist as Label
@onready var mapper_label := $Head/Mapper as Label
@onready var httpreq := $HTTPReq as HTTPRequest
@onready var httpdownload := $HTTPDownload as HTTPRequest
@onready var httpcoverdownload := $CoverDownload as HTTPRequest
@onready var httpdetailcover := $DetailCoverDownload as HTTPRequest
@onready var httppreviewdownload := $PreviewDownload as HTTPRequest
@onready var placeholder_cover := preload("res://game/data/beepsaber_logo.png")
@onready var goto_maps_by := $gotoMapsBy as Button
@onready var download_button := $download as Button
@onready var reaction_filter := $FiltersPanel/Rows/DifficultyRow/ReactionFilter as OptionButton
@onready var genre_filter := $FiltersPanel/Rows/GenreRow/GenreFilter as OptionButton
@onready var style_chips := $FiltersPanel/Rows/StyleRow/StyleChips as HFlowContainer
@onready var length_filter := $FiltersPanel/Rows/LengthRow/LengthFilter as OptionButton
@onready var clear_filters_button := $FiltersPanel/Rows/ClearFilters_Button as Button
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
		item_list.set_item_side(item_index, _side_text(song_data[item_index]))
		item_list.set_item_strip(item_index, _strip(song_data[item_index]))
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

## A map's row text, as the song menu names its songs: "Artist - Title" (the map's name when it has neither).
static func _row_text(song: BeatSaverSongInfo) -> String:
	if song.song_name.is_empty():
		return song.name
	return "%s - %s" % [song.song_author_name, song.song_name] if not song.song_author_name.is_empty() else song.song_name

## The end of a map's row: how its download is going, else its length, with "✓" once it is in the library.
func _side_text(song: BeatSaverSongInfo) -> String:
	var hash := song.get_hash()
	if not downloading.is_empty() and Utils.get_str(downloading[0][1] as Dictionary, "hash", "") == hash:
		var total := httpdownload.get_body_size()
		return "↓ %d%%" % (100 * httpdownload.get_downloaded_bytes() / total) if total > 0 else "↓ …"
	if downloading.any(func(entry: Array) -> bool: return Utils.get_str(entry[1] as Dictionary, "hash", "") == hash):
		return "↓ …"
	var seconds := int(song.duration)
	return "%s%d:%02d" % ["✓ " if _in_library(song) else "", seconds / 60, seconds % 60]

## Level strips by kind (levels, the player's level, estimated), each one texture shared by every row that shows it.
var _strip_textures := {}

## A map's level strip: measured once it is in the library, else BeatSaver's estimate.
func _strip(song: BeatSaverSongInfo) -> Texture2D:
	var levels := _levels(song)
	var key := "%s|%d|%s" % [levels[0], picked_level(), levels[1]]
	if not _strip_textures.has(key):
		_strip_textures[key] = ImageTexture.create_from_image(LevelStrip.strip_image(levels[0], picked_level(), levels[1]))
	return _strip_textures[key]

func _ready() -> void:
	for tab: Array in SORT_TABS:
		sort_button.add_item(tab[0])
	var style_group := ButtonGroup.new()
	for style: Array in STYLES:
		var chip := Button.new()
		chip.theme_type_variation = &"ChipButton"
		chip.text = style[0]
		chip.toggle_mode = true
		chip.button_group = style_group
		chip.pressed.connect(_on_style_pressed.bind(style[1]))
		style_chips.add_child(chip)
	(style_chips.get_child(0) as Button).set_pressed_no_signal(true)
	for genre: Array in GENRES:
		genre_filter.add_item(genre[0])
	UI_AudioEngine.attach_children(self)
	v_scroll.value_changed.connect(_on_ListV_Scroll_value_changed)
	_detail_texture = ImageTexture.create_from_image(_sized(placeholder_cover.get_image(), DETAIL_COVER))
	cover_rect.texture = _detail_texture
	
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
	
	reaction_filter.add_item(Constants.ANY_DIFFICULTY_LABEL)
	for level: Array in Constants.DIFFICULTY_LEVELS:
		reaction_filter.add_item(level[0])
	LevelStrip.prepare(self)
	_add_details_toggle()
	_make_details_box()
	for filter: Array in Constants.LENGTH_FILTERS:
		length_filter.add_item(filter[1])
	_sync_filter_controls()
	Settings.changed.connect(_on_settings_changed)

## Shows the filters in their controls, on the Filters button and as chips above the list.
func _sync_filter_controls() -> void:
	reaction_filter.select(picked_level() + 1)
	length_filter.select(MapStats.length_filter(Settings.beatsaver_filter_length)[0])
	for i in STYLES.size():
		(style_chips.get_child(i) as Button).set_pressed_no_signal(STYLES[i][1] == _style_tag)
	genre_filter.select(GENRES.map(func(genre: Array) -> String: return genre[1]).find(_genre_tag))
	var on := _filter_chips()
	filters_button.text = FILTERS_ON_TEXT % on.size() if not on.is_empty() else FILTERS_TEXT
	clear_filters_button.visible = not on.is_empty()
	_update_chips()

## The filters that are on, as [chip text, what pressing its x does].
func _filter_chips() -> Array:
	var chips := []
	if not _style_tag.is_empty():
		chips.append([_tag_name(_style_tag), func() -> void: _on_style_pressed("")])
	if not _genre_tag.is_empty():
		chips.append([_tag_name(_genre_tag), func() -> void: _on_genre_filter_item_selected(0)])
	if picked_level() >= 0:
		chips.append([Constants.DIFFICULTY_LEVELS[picked_level()][0], func() -> void: Settings.beatsaver_filter_reaction = 0])
	var length := MapStats.length_filter(Settings.beatsaver_filter_length)
	if int(length[0]) != 0:
		chips.append([length[1], func() -> void: Settings.beatsaver_filter_length = 0])
	return chips

## The row above the list shows what it lists (owner, 2026-10-29, layout A: show which filters are on): the mapper of
## a "More by" list, or the search and each filter on, each a chip whose x takes it off; when the filters' chips don't
## fit, one chip stands for them all. With none it credits BeatSaver.
func _update_chips() -> void:
	var chips := []
	var filters := []
	if prev_request != null and prev_request.type == "uploader":
		chips.append([MAPPER_CHIP_TEXT % _uploader_name, _on_back_pressed])
	else:
		if not search_word.is_empty():
			var shown := search_word if search_word.length() <= SEARCH_CHIP_LETTERS else search_word.left(SEARCH_CHIP_LETTERS).strip_edges() + "…"
			chips.append(["\"%s\"" % shown, _on_clear_search_pressed])
		filters = _filter_chips()
	_fill_chips(chips + filters)
	if chip_row.get_combined_minimum_size().x > chip_row.size.x:
		_fill_chips(chips + [[SOME_FILTERS_TEXT % filters.size(), _on_clear_filters_pressed]])

## Puts chips [text, what pressing it does] in the row above the list; with none it credits BeatSaver.
func _fill_chips(chips: Array) -> void:
	for chip in chip_row.get_children():
		if chip != source_label:
			chip_row.remove_child(chip)
			chip.queue_free()
	for entry: Array in chips:
		var chip := Button.new()
		chip.theme_type_variation = &"ChipButton"
		chip.text = entry[0]
		chip.icon = CLEAR_ICON
		chip.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		chip.add_theme_constant_override(&"icon_max_width", CHIP_ICON_SIZE)
		chip.pressed.connect(entry[1] as Callable)
		UI_AudioEngine.attach_button(chip)
		chip_row.add_child(chip)
		chip_row.move_child(chip, chip_row.get_child_count() - 2)
	source_label.visible = chips.is_empty()

## Opens or closes the filters over the list.
func _set_filters_open(open: bool) -> void:
	filters_panel.visible = open
	_redraw()

## Turns every filter off and lists again once.
func _on_clear_filters_pressed() -> void:
	_style_tag = ""
	_genre_tag = ""
	_clearing = true
	Settings.beatsaver_filter_reaction = 0
	Settings.beatsaver_filter_length = 0
	_clearing = false
	_sync_filter_controls()
	_reload()

## True while Clear filters changes several settings, so the list loads once.
var _clearing := false

## Draws the page again (it redraws only on input otherwise).
func _redraw() -> void:
	var canvas := get_parent().get_parent()
	if canvas is OQ_UI2DCanvas: (canvas as OQ_UI2DCanvas)._input_update()

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
	if key != &"beatsaver_filter_reaction" and key != &"beatsaver_filter_length" or _clearing:
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
	_sync_filter_controls()
	_reload()

## Lists only maps of one genre (a BeatSaver tag), or any.
func _on_genre_filter_item_selected(index: int) -> void:
	_genre_tag = GENRES[index][1]
	_sync_filter_controls()
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
	return "https://beatsaver.com/api/search/text/%d?q=%s&sortOrder=%s&pageSize=%d%s" % [page, query.uri_encode(), sort_order,
		PAGE_SIZE, _filter_query()]

func update_list(req: BeatSaverRequest) -> void:
	if req.page == 0:
		# brand new request, clear list to prep for reload
		item_list.clear()
		_show_empty(LOADING_TEXT)
		if goto_maps_by:
			goto_maps_by.visible = false
		song_data = []
		_cover_list += 1
		_finished_covers.clear()
		item_selected = -1
		_show_no_song()
		_update_download_button()
		_update_chips()
	if not httpcoverdownload:
		return
	httpcoverdownload.cancel_request()
	httpreq.cancel_request()
	_list_request += 1
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

## The logo as a row's cover until the map's own comes: made once and shared; read back from the GPU for each row, a page
## of them froze dragging the list (owner, 2026-10-28; headset: one second at 20 of 72 frames while scrolling Get songs).
var _placeholder_image: Image

func _placeholder_row_cover() -> Image:
	if _placeholder_image == null:
		_placeholder_image = _sized(placeholder_cover.get_image(), BeatSaverList.COVER_SIZE)
	return _placeholder_image

## An image as a cover of size px: RGBA8, square, its corners rounded like the song menu's covers.
static func _sized(image: Image, size: int) -> Image:
	var sized := image.duplicate() as Image
	if sized.is_compressed():
		sized.decompress()
	sized.convert(Image.FORMAT_RGBA8)
	sized.resize(size, size, Image.INTERPOLATE_BILINEAR)
	return ImageUtils.round_corners(sized, roundi(size * ImageUtils.COVER_CORNER))

## What the list area says while it has no songs: loading, nothing found or no connection.
const LOADING_TEXT := "Loading songs…"
const NO_MATCH_TEXT := "No songs match. Try fewer filters."
const NO_CONNECTION_TEXT := "Can't reach BeatSaver. Check your Wi-Fi."

## Shows a message where the list is, or none.
func _show_empty(text: String) -> void:
	empty_list.text = text
	empty_list.visible = not text.is_empty()

## Rows added to the list per frame as a page comes in, so a page of PAGE_SIZE never stalls a frame (owner,
## 2026-10-29: Get songs froze for a moment as each new page came while scrolling; a 50-song page took 10-13 ms in one
## frame on desktop, over the 13.9 ms frame at 72 Hz and a few times that on the headset).
const ROWS_PER_FRAME := 10
## Counts list requests, so a page that comes in after a newer request is dropped.
var _list_request := 0

func _on_HTTPRequest_request_completed(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == 0:
		var request := _list_request
		var parsed := []
		# low priority: the pool's high-priority threads would compete with the game's own for the cores
		var task := WorkerThreadPool.add_task(_parse_page.bind(body, parsed), false)
		# always a frame later, so a request made meanwhile is seen the same way however fast the page parsed
		await get_tree().process_frame
		while not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(task)
		if request != _list_request:
			return
		if not parsed.is_empty():
			var songs: Array = parsed[0]
			# resume covers a newer page interrupted, rather than skipping them
			_current_cover_to_download = mini(_current_cover_to_download, song_data.size())
			for first in range(0, songs.size(), ROWS_PER_FRAME):
				if first > 0:
					await get_tree().process_frame
					if request != _list_request:
						return
				_add_rows(songs.slice(first, first + ROWS_PER_FRAME))
			# an empty page is the end of the list
			next_page_available = -1 if songs.is_empty() else prev_page_available + 1
	elif _list_retries_left > 0 and prev_request != null:
		_list_retries_left -= 1
		vr.log_warning("BeatSaver list request failed (result %d), trying again" % result)
		await get_tree().create_timer(LIST_RETRY_SECONDS).timeout
		update_list(prev_request)
		return
	else:
		vr.log_error("request error "+str(result))
		if item_list.item_count == 0:
			_show_empty(NO_CONNECTION_TEXT)
	_list_retries_left = LIST_RETRIES
	_scroll_page_request_pending = false
	_redraw()
	
	_update_all_covers()
	_fill_short_list()
	if result == 0:
		if item_list.item_count > 0:
			_show_empty("")
		elif not _scroll_page_request_pending:
			_show_empty(NO_MATCH_TEXT)

## Parses a BeatSaver page into `parsed` as [maps playable here], left empty when the page isn't a map list; on a
## worker thread.
static func _parse_page(body: PackedByteArray, parsed: Array) -> void:
	var json_data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not json_data is Dictionary:
		return
	var songs := []
	var docs: Variant = (json_data as Dictionary).get("docs")
	if docs is Array:
		for i: Variant in docs as Array:
			if not i is Dictionary: continue
			var song := BeatSaverSongInfo.new(i as Dictionary)
			if song.is_playable():
				songs.append(song)
	parsed.append(songs)

## Adds the parsed maps that pass the level filter (an uploader's maps all show) to the list.
func _add_rows(songs: Array) -> void:
	var texts := PackedStringArray()
	var sides := PackedStringArray()
	var covers: Array[Image] = []
	var strips: Array[Texture2D] = []
	for song: BeatSaverSongInfo in songs:
		if prev_request.type != "uploader" and not song.passes_reaction_filter():
			continue
		texts.append(_row_text(song))
		sides.append(_side_text(song))
		covers.append(_placeholder_row_cover())
		strips.append(_strip(song))
		song_data.append(song)
	item_list.add_items(texts, sides, covers, strips)

## Most items the list fetches pages for on its own while the reaction time filter hides songs.
const REACTION_FILL_ITEMS := 20
## Most pages fetched on their own in a row, so a rare reaction time can't keep requesting forever.
const REACTION_FILL_PAGES := 10

## Fetches the next pages on its own while the list still ends within FETCH_ROWS_LEFT rows of the view, since the
## next page otherwise loads only when the player scrolls (owner, 2026-10-29: the first page of Latest showed no scroll
## bar, so no more songs ever came: automapped maps and ones without Standard are left out, and a page can keep few).
## BeatSaver can't filter by reaction time either, so with that filter on it keeps going until REACTION_FILL_ITEMS songs.
func _fill_short_list() -> void:
	if prev_request == null or next_page_available == -1 or prev_request.page >= REACTION_FILL_PAGES:
		return
	var level_fill := picked_level() >= 0 and prev_request.type != "uploader" and item_list.item_count < REACTION_FILL_ITEMS
	if not _near_end() and not level_fill:
		return
	prev_request.page += 1
	update_list(prev_request)
	_scroll_page_request_pending = true


## Lists every map in the picked sort order, leaving any search.
func _on_sort_selected(index: int) -> void:
	_list_sorted(SORT_TABS[index][1])

## Lists every map in one sort order, leaving any search.
func _list_sorted(sort_order: String) -> void:
	_set_search("")
	back_stack.clear()
	prev_request = BeatSaverRequest.new()
	prev_request.page = 0
	prev_request.type = "list"
	prev_request.data = sort_order
	update_list(prev_request)

## Keeps the search (shown as a chip above the list); while there is one the sort button says the list is in best
## match order.
func _set_search(text: String) -> void:
	search_word = text
	if not text.is_empty():
		sort_button.select(-1)
		sort_button.text = BEST_MATCH_TEXT

## Clears the search and goes back to the Popular list.
func _on_clear_search_pressed() -> void:
	sort_button.select(0)
	_list_sorted(SORT_TABS[0][1])


func _on_ItemList_item_selected(index: int) -> void:
	item_selected = index
	var selected_data := _get_selected_song()
	var version: Dictionary = selected_data.versions[0]
	goto_maps_by.text = "More by %s" % selected_data.level_author_name
	_details_toggle.visible = true
	goto_maps_by.visible = selected_data.uploader_id != -1 and prev_request != null and prev_request.type != "uploader"
	_show_details(selected_data)
	# the row's small cover at once, the big one when it arrives
	_detail_texture.update(_sized(item_list.get_item_image(index), DETAIL_COVER))
	httpdetailcover.cancel_request()
	_detail_cover_song = selected_data
	var cover_url := _get_cover_url_from_song_data(selected_data)
	if not cover_url.is_empty() and httpdetailcover.request(cover_url) != OK:
		vr.log_warning("Cover request failed: %s" % cover_url)
	label.text = ""
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

## The rest of the picked map in plain words, under its title, artist and mapper: how liked it is, whether staff picked
## it, its tags, each Standard difficulty, the other modes by name and the start of its description. Short enough for
## the song menu's side panel with five Standard difficulties (tests/test_menu_layout.gd).
func _details_text(song: BeatSaverSongInfo) -> String:
	var muted := Constants.UI_TEXT_MUTED.to_html(false)
	var text := "[color=#%s]%d%% liked%s[/color]" % [muted, roundi(song.score * 100.0), " · ★ Staff pick" if song.curated else ""]
	var tag_names := PackedStringArray()
	for tag in song.tags:
		tag_names.append(_tag_name(tag))
	if not tag_names.is_empty():
		text += "\n[color=#%s]%s[/color]" % [muted, " · ".join(tag_names)]
	var modes := PackedStringArray()
	for diff: Variant in Utils.get_array(song.versions[0] as Dictionary, "diffs", []):
		var d := diff as Dictionary
		var mode := Utils.get_str(d, "characteristic", "Standard")
		if mode != "Standard":
			if not modes.has(mode):
				modes.append(mode)
			continue
		var level: Array = Constants.DIFFICULTY_LEVELS[song.level_of(d)]
		var line: String = level[0]
		if song.bpm > 0.0:
			line += " · Notes %.2f s ahead" % song.reaction_seconds(d)
		var flow := MapStats.flow_level(BeatSaverSongInfo.parity_percent(d))
		if flow > 0:
			line += " · %s" % Constants.FLOW_LEVELS[flow][0]
		var walls := int(Utils.get_float(d, "obstacles", 0))
		if walls > 0:
			line += " · %s walls" % Hud._grouped(walls)
		text += "\n[color=#%s]%s[/color]" % [(level[1] as Color).to_html(false), line]
	if not modes.is_empty():
		text += "\n[color=#%s]Also %s[/color]" % [muted, ", ".join(modes)]
	var description := song.description.strip_edges().replace("\n", " ")
	if not description.is_empty():
		if description.length() > DESCRIPTION_LETTERS:
			description = description.left(DESCRIPTION_LETTERS).strip_edges() + "…"
		text += "\n[color=#%s]%s[/color]" % [muted, _escape(description)]
	return text

## Each Standard difficulty as a rounded bar across the panel in its level's colour, with its name ("≈" while
## estimated) and its numbers in columns under a header of stats pills (StatPills: time to get ready, notes per second,
## swing flow, each icon with its unit), measured once the map is in the library; the player's level (the level
## filter) framed in UI_ACCENT; then what "≈" means. A table, so all five levels' numbers fit the song menu's side
## panel (owner, 2026-10-29: every level's pills and numbers; one pill row per level took 632 of 341 px).
func _level_row_controls(song: BeatSaverSongInfo) -> Array[Control]:
	var controls: Array[Control] = []
	var rows := _difficulty_rows(song)
	if rows.is_empty():
		return controls
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var estimated := _local_map(song) == null
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 0)
	var corner := Control.new()
	corner.custom_minimum_size.x = LEVEL_COLUMNS[0] + LEVEL_BAR_MARGIN
	header.add_child(corner)
	var heads := [[StatPills.READY_ICON, "s"], [StatPills.NPS_ICON, "notes/s"], [StatPills.FLOW_ICON, "flow"]]
	for k in heads.size():
		var cell := CenterContainer.new()
		cell.custom_minimum_size.x = LEVEL_COLUMNS[k + 1]
		cell.add_child(StatPills.pill(heads[k][0], heads[k][1], PILL_ICON_SIZE))
		header.add_child(cell)
	controls.append(header)
	for row: Array in rows:
		var entry: Array = Constants.DIFFICULTY_LEVELS[row[0]]
		var bar := PanelContainer.new()
		bar.theme_type_variation = &"LevelBar"
		var colored := bar.get_theme_stylebox(&"panel", &"LevelBar").duplicate() as StyleBoxFlat
		colored.bg_color = entry[1]
		# the name keeps off the rounded left end; the columns line up with the header's pills
		colored.content_margin_left = LEVEL_BAR_MARGIN
		colored.content_margin_right = 0.0
		if row[0] == picked_level():
			colored.border_color = Constants.UI_ACCENT
			colored.set_border_width_all(LEVEL_FRAME)
		bar.add_theme_stylebox_override(&"panel", colored)
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 0)
		bar.add_child(line)
		var texts := ["%s%s" % [entry[0], " ≈" if estimated else ""], "%.2f" % row[1],
			"%.1f" % row[2] if row[2] > 0.0 else "–", "%d%%" % roundi(row[3])]
		for k in texts.size():
			var label := Label.new()
			label.text = texts[k]
			label.custom_minimum_size.x = LEVEL_COLUMNS[k]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if k == 0 else HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override(&"font_size", LEVEL_BAR_SIZE)
			label.add_theme_color_override(&"font_color", Constants.UI_PANEL)
			line.add_child(label)
		controls.append(bar)
	if estimated:
		var hint := Label.new()
		hint.text = ESTIMATE_HINT
		hint.add_theme_font_size_override(&"font_size", 22)
		hint.add_theme_color_override(&"font_color", Constants.UI_TEXT_MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		controls.append(hint)
	return controls

## The room at a bar's left end, the frame round the player's level, and the table's column widths: the level's name
## ("Expert+ ≈"), then get ready, notes per second and flow, each as wide as its header pill (px; with the margin they
## fill the 432 px details column).
const LEVEL_BAR_MARGIN := 12.0
const LEVEL_FRAME := 3
const LEVEL_COLUMNS: Array[float] = [122.0, 74.0, 128.0, 96.0]

## The details' text and, in the short details, the level rows under it, in one column where song_data stood.
var _song_text: RichTextLabel
var _level_rows := VBoxContainer.new()
var _details_box := VBoxContainer.new()

func _make_details_box() -> void:
	_song_text = $song_data as RichTextLabel
	var box := _details_box
	box.position = _song_text.position
	box.size = _song_text.size
	box.add_theme_constant_override(&"separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_song_text.reparent(box)
	_song_text.fit_content = true
	box.add_child(_level_rows)
	_level_rows.add_theme_constant_override(&"separation", 8)

## The picked map beside its cover (title, artist, mapper and length) and under it its levels, or with Details on the
## rest of what BeatSaver says about it.
func _show_details(song: BeatSaverSongInfo) -> void:
	var seconds := int(song.duration)
	title_label.text = song.song_name if not song.song_name.is_empty() else song.name
	artist_label.text = song.song_author_name
	mapper_label.text = "by %s · %d:%02d" % [song.level_author_name, seconds / 60, seconds % 60]
	var long := _details_toggle.button_pressed
	_song_text.visible = long
	_song_text.text = _details_text(song) if long else ""
	StatPills.fill(_level_rows, [] if long else _level_row_controls(song))

## The details with no map picked: a hint where the title goes and the logo for a cover.
func _show_no_song() -> void:
	if _song_text == null:
		return
	title_label.text = "Pick a song to see what it plays like."
	artist_label.text = ""
	mapper_label.text = ""
	_song_text.visible = false
	StatPills.fill(_level_rows, [])
	_details_toggle.visible = false
	httpdetailcover.cancel_request()
	_detail_cover_song = null
	_detail_texture.update(_sized(placeholder_cover.get_image(), DETAIL_COVER))
	label.text = ""

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

## The level bars' text size in the short details: at the page's 2 m and scale 2.4 about 1.85 degrees (vr-ui-design).
const LEVEL_BAR_SIZE := 28
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

## Most letters of the description the details show (about two lines).
const DESCRIPTION_LETTERS := 70

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

## Puts finished covers on the list and keeps the download progress on the button current.
func _process(delta: float) -> void:
	_flush_covers(delta)
	if downloading.is_empty():
		return
	var before := download_button.text
	_update_download_button()
	var index := song_data.find(_downloading_song())
	var row_changed := index >= 0 and index < item_list.item_count and item_list.set_item_side(index, _side_text(song_data[index]))
	if download_button.text != before or row_changed:
		_redraw()

## The listed map being downloaded now, or null.
func _downloading_song() -> BeatSaverSongInfo:
	var hash := Utils.get_str(downloading[0][1] as Dictionary, "hash", "")
	for song in song_data:
		if song.get_hash() == hash:
			return song
	return null

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
	label.text = ""
	_update_download_button()
	item_list.set_item_side(item_selected, _side_text(song))

## Writes a downloaded song's zip `body` to `zippath`, unpacks it into `song_out_dir` and removes the zip; on a worker
## thread. Appends true to `saved` when the zip could be written.
static func _save_song(body: PackedByteArray, zippath: String, song_out_dir: String, saved: Array) -> void:
	var file := FileAccess.open(zippath, FileAccess.WRITE)
	if not file:
		return
	file.store_buffer(body)
	file.close()
	Utils.unzip(zippath, song_out_dir)
	DirAccess.remove_absolute(zippath)
	saved.append(true)

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
			# saved and unpacked on a worker thread: on the main thread it froze the view for each song (owner,
			# 2026-10-28)
			var saved := []
			var task := WorkerThreadPool.add_task(_save_song.bind(body, zippath, song_out_dir, saved))
			while not WorkerThreadPool.is_task_completed(task):
				await get_tree().process_frame
			WorkerThreadPool.wait_for_task_completion(task)
			if saved.is_empty():
				vr.log_file_error(FileAccess.get_open_error(), zippath, "BeatSaverPanel._save_song")
			else:
				SongTags.remember(song_dir_name, downloading[0][2])
				_downloaded.append(song_dir_name)
		
		downloading.remove_at(0)
		
		if not downloading.size() > 0:
			main_menu_ref.add_downloaded_songs(_downloaded)
			_downloaded = []
	else:
		label.text = "Couldn't download %s. Check your Wi-Fi and try again." % str(downloading[0][0])
		vr.log_info("download error "+str(result))
		downloading.remove_at(0)
	_update_download_button()
	on_song_list_changed()
	_redraw()
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
## Counts list rebuilds, so a cover finished for an older list is dropped.
var _cover_list := 0
## Finished covers wait here, [index, song, image], and go onto the list together at most every COVER_FLUSH_SECONDS:
## each one set alone relaid the list and redrew the whole page (headset, 1c474b4: seconds at 19-38 of 72 frames
## while covers came in).
const COVER_FLUSH_SECONDS := 0.25
var _finished_covers := []
var _cover_flush_wait := 0.0

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

## A cover arrived: the next one starts downloading at once, while this one is decoded, sized and given its level strip
## on a worker thread (owner, 2026-10-28: the view hitched as covers came in; a full-size JPEG decoded on the main
## thread), and only the finished 200 px image becomes the card's texture here.
func _update_cover(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var index := _current_cover_to_download
	var list := _cover_list
	_current_cover_to_download += 1
	update_next_cover()
	if result != 0 or index >= song_data.size():
		return
	var song: BeatSaverSongInfo = song_data[index]
	var made := []
	# low priority: the pool's high-priority threads would compete with the game's own for the cores
	var task := WorkerThreadPool.add_task(_make_cover.bind(body, BeatSaverList.COVER_SIZE, made), false)
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	if made.is_empty() or list != _cover_list:
		return
	_finished_covers.append([index, song, made[0]])

## Puts the finished covers onto the list together, every COVER_FLUSH_SECONDS, with one redraw of the page.
func _flush_covers(delta: float) -> void:
	_cover_flush_wait -= delta
	if _finished_covers.is_empty() or _cover_flush_wait > 0.0:
		return
	_cover_flush_wait = COVER_FLUSH_SECONDS
	for cover: Array in _finished_covers:
		var index: int = cover[0]
		if index < song_data.size() and song_data[index] == cover[1]:
			item_list.set_item_image(index, cover[2])
	_finished_covers.clear()
	_redraw()

## Decodes a cover (JPEG or PNG) and sizes it to size px into `made`; on a worker thread.
static func _make_cover(body: PackedByteArray, size: int, made: Array) -> void:
	var img := Image.new()
	if img.load_jpg_from_buffer(body) != OK and img.load_png_from_buffer(body) != OK:
		return
	made.append(_sized(img, size))

## The details' cover, written over in place for each picked map (one texture for the page's life).
var _detail_texture: ImageTexture
## The map whose big cover is being fetched, so a late one for an earlier pick is dropped.
var _detail_cover_song: BeatSaverSongInfo

## The picked map's big cover arrived: decoded and sized on a worker thread, then shown in the details.
func _on_detail_cover_completed(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var song := _detail_cover_song
	if result != 0 or song == null:
		return
	var made := []
	var task := WorkerThreadPool.add_task(_make_cover.bind(body, DETAIL_COVER, made), false)
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	if made.is_empty() or song != _detail_cover_song:
		return
	_detail_texture.update(made[0])
	_redraw()

## The mapper whose maps "More by" lists, for its chip.
var _uploader_name := ""

func _on_gotoMapsBy_pressed() -> void:
	var selected_song := _get_selected_song()
	if selected_song.uploader_id == -1: return
	_uploader_name = selected_song.level_author_name
	_add_to_back_stack(prev_request)
	prev_request = BeatSaverRequest.new()
	prev_request.page = 0
	prev_request.type = "uploader"
	prev_request.data = str(selected_song.uploader_id)
	update_list(prev_request)
	
## Songs a text search or sorted list asks BeatSaver for at a time (its default is 20; a mapper's list has no page
## size), and how many songs may still be below the view before the next page is fetched (owner, 2026-10-29).
const PAGE_SIZE := 50
const FETCH_ROWS_LEFT := 15
var _scroll_page_request_pending := false

## True when FETCH_ROWS_LEFT or fewer songs are below the bottom of the view.
func _near_end() -> bool:
	var row_step := BeatSaverList.ROW_HEIGHT + BeatSaverList.ROW_SEPARATION
	var rows_seen := ceili((item_list.scroll_vertical + item_list.size.y) / row_step)
	return item_list.item_count - rows_seen <= FETCH_ROWS_LEFT

## Fetches the next page once the player scrolls near the end of the list.
func _on_ListV_Scroll_value_changed(_new_value: float) -> void:
	if _near_end():
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
		sort_button.select(0)
		_list_sorted(SORT_TABS[0][1])
		_is_first_show = false
	elif item_list.item_count == 0 and httpreq.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		if prev_request != null and prev_request.type != "uploader":
			_reload()
		else:
			_on_clear_search_pressed()
