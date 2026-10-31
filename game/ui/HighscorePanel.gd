extends Panel
class_name HighscorePanel

@export var show_song_info := true
## In the song menu's left panel, under the song (owner, 2026-10-27): no margins or background (the panel draws
## it), the count of scores as the title (the difficulty is picked right above), and at most COMPACT_ROWS rows, as
## nothing but the song list scrolls on that page (owner, 2026-10-28): the best ones, the current player's best
## in the last row when it's further down, its place before the name.
@export var compact := false
## 5 since the Practice button took the left panel's bottom (owner's choice A, 2026-10-30)
const COMPACT_ROWS := 5

# keep a copy of the base row for regeneration later
@onready var _base_row = $Margin/VBox/LeftRight/ScrollContainer/Margin/HighscoresList/BaseRecordRow.duplicate()
@onready var _highscore_list = $Margin/VBox/LeftRight/ScrollContainer/Margin/HighscoresList
@onready var _title = $Margin/VBox/Title
@onready var _song_info = $Margin/VBox/LeftRight/VBox/SongInfo_Label
@onready var _song_info_panel = $Margin/VBox/LeftRight/VBox

## The rows' columns: a name too long for its room ends in "…"; the score keeps a fixed width, right-aligned, so long
## modifier titles (they wrap) and long names can't push it off the board (owner on the headset, 2026-10-25).
const SCORE_WIDTH := 150.0

## The rows read [grade, name, score] (owner, 2026-10-27): the run's grade in the HUD's grade font and its colour, "–"
## for records from before grades were kept.
const GRADE_WIDTH := 64.0
const NO_GRADE := "–"

func _ready() -> void:
	var grade := _base_row.get_child(0) as Label
	grade.custom_minimum_size.x = GRADE_WIDTH
	grade.add_theme_font_override(&"font", Hud.GRADE_FONT)
	(_base_row.get_child(1) as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var score := _base_row.get_child(2) as Label
	score.custom_minimum_size.x = SCORE_WIDTH
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clear_list()
	_song_info_panel.visible = show_song_info
	if compact:
		add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
		_highscore_list.add_theme_constant_override(&"separation", 0)
		for margin: MarginContainer in [$Margin, $Margin/VBox/LeftRight/ScrollContainer/Margin]:
			for side in ["left", "top", "right", "bottom"]:
				margin.add_theme_constant_override("margin_" + side, 0)
	
## Rows stand out in UI_ACCENT: on the score screen only the run just played (latest, the record add_highscore
## returned; none when it didn't make the list), elsewhere (latest null) the current player's rows.
func load_highscores(map_info: MapInfo, diff_rank: int, latest: Variant = null) -> void:
	
	# clear the high score list
	_clear_list()
	
	diff_rank = HighscoreTable.get_rank_key(diff_rank)
	
	# populate title text
	set_title("Highscores (%s)" % _get_difficulty_name(map_info,diff_rank))
	
	# populate song info
	_song_info.text = """Artist: %s
		Song: %s
		Map Author: %s""" % [map_info.song_author_name, map_info.song_name, map_info.level_author_name]
		
	# TODO populate song artwork
	
	var records := Highscores.get_records(map_info,diff_rank)
	var places := range(records.size())
	if compact:
		set_title("No scores yet" if records.is_empty() else "%d %s" % [records.size(), "score" if records.size() == 1 else "scores"])
		var my_best := records.map(func(r: Dictionary) -> String: return r.player_name).find(Settings.player_name)
		places = places.slice(0, COMPACT_ROWS)
		if my_best >= COMPACT_ROWS:
			places[-1] = my_best
	for place: int in places:
		var record: Dictionary = records[place]
		# build a new row and populate fields from record
		var new_row = _base_row.duplicate()
		var grade_label := new_row.get_child(0) as Label
		grade_label.text = EndScore.grade(record.accuracy) if record.has("accuracy") else NO_GRADE
		grade_label.add_theme_color_override(&"font_color",
				Constants.RANK_COLORS[grade_label.text] if record.has("accuracy") else Constants.UI_TEXT_MUTED)
		new_row.get_child(1).text = record.player_name if not compact or place < COMPACT_ROWS else "#%d %s" % [place + 1, record.player_name]
		new_row.get_child(2).text = Hud._grouped(record.score)
		(new_row.get_child(2) as Control).add_theme_font_override(&"font", Hud.NUMBER_FONT)
		var mine: bool = record.player_name == Settings.player_name if latest == null else (
				not (latest as Dictionary).is_empty() and record.epoch_time == latest.epoch_time and record.score == latest.score)
		if mine:
			# the grade keeps its own colour
			for label: Label in new_row.get_children().slice(1):
				label.add_theme_color_override(&"font_color", Constants.UI_ACCENT)
		
		_highscore_list.add_child(new_row)
		
func set_title(title_text):
	_title.text = title_text
	
# clears all rows from the highscore table
func _clear_list():
	for c in _highscore_list.get_children():
		c.queue_free()
	
## Joins a level name and the run's modifiers, e.g. "Hard · No Fail · Speed 85%".
const RUN_PARTS_SEPARATOR := " · "

## The level and the modifiers a run was played with, all read from its rank (HighscoreTable.get_rank_key), with
## the same names the Modifiers tab uses. Defaults (health on, bombs, arrows, normal size...) are left out.
func _get_difficulty_name(map_info: MapInfo, diff_rank: int) -> String:
	var parts := PackedStringArray(['Rank %d' % (diff_rank & Constants.DIFFICULTY_MASK)])
	for beat_map in map_info.difficulty_beatmaps:
		if beat_map.difficulty_rank == (diff_rank & Constants.DIFFICULTY_MASK):
			parts[0] = MapStats.level_name(map_info, beat_map)
	if diff_rank & Constants.DIFFICULTY_HEALTH == 0:
		parts.append(Constants.FAIL_OPTIONS[0][2])
	if diff_rank & Constants.DIFFICULTY_BOMBS == 0:
		parts.append(Constants.NO_BOMBS_LABEL)
	if diff_rank & Constants.DIFFICULTY_NO_WALLS != 0:
		parts.append(Constants.NO_WALLS_LABEL)
	if diff_rank & Constants.DIFFICULTY_ARROWS == 0:
		parts.append(Constants.NO_ARROWS_LABEL)
	match diff_rank & Constants.DIFFICULTY_BLOCK_SIZE_MASK:
		Constants.DIFFICULTY_BLOCK_SIZE_SMALL: parts.append(Constants.SIZES[0][1])
		Constants.DIFFICULTY_BLOCK_SIZE_BIG: parts.append(Constants.SIZES[2][1])
		Constants.DIFFICULTY_BLOCK_SIZE_GIANT: parts.append(Constants.SIZES[3][1])
	if diff_rank & Constants.DIFFICULTY_CLAWS != 0:
		parts.append(Constants.CLAWS_LABEL)
	_append_label(parts, Constants.WIDTHS, HighscoreTable.get_width_from_rank(diff_rank), 100)
	_append_label(parts, Constants.SPEEDS, HighscoreTable.get_speed_from_rank(diff_rank), 100)
	_append_label(parts, Constants.FLIPS, (diff_rank & Constants.DIFFICULTY_FLIP_MASK) >> Constants.DIFFICULTY_FLIP_SHIFT, 0)
	match diff_rank & Constants.DIFFICULTY_HANDEDNESS_MASK:
		Constants.DIFFICULTY_HANDEDNESS_IGNORE: _append_label(parts, Constants.HANDEDNESSES, Constants.HANDEDNESS_IGNORE, 0)
		Constants.DIFFICULTY_HANDEDNESS_FORCE_LEFT: _append_label(parts, Constants.HANDEDNESSES, Constants.HANDEDNESS_FORCE_LEFT, 0)
		Constants.DIFFICULTY_HANDEDNESS_FORCE_RIGHT: _append_label(parts, Constants.HANDEDNESSES, Constants.HANDEDNESS_FORCE_RIGHT, 0)
	return RUN_PARTS_SEPARATOR.join(parts)

## Adds the label of value from a [value, label, ...] option table, unless it is the default.
func _append_label(parts: PackedStringArray, options: Array, value: int, default: int) -> void:
	if value == default:
		return
	for option: Array in options:
		if option[0] == value:
			parts.append(option[1])
