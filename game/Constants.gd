extends Node

const DEFAULT_LANE_ZERO_X := -0.9
const BEAT_DISTANCE := 4.0
const DEFAULT_LANE_DISTANCE_X := 0.6
const LANE_DISTANCE_Y := 0.6
## Eye height the note rows (ROW_Y) and crouch walls (CROUCH_WALL_BOTTOM) suit, as Beat Saber's default 1.80 m player (eyes about
## 0.1 m below the top of the head); "Measure my height" sets a player's Height as their difference from it.
const EYE_HEIGHT := 1.7
## Note row heights in metres (bottom, middle, top), where Beat Saber puts them for its 1.80 m player
## (doc/research/scoring-and-reach.md); notes, bombs, arcs and chains use layer_y(), walls keep LANE_DISTANCE_Y steps.
const ROW_Y: Array[float] = [0.85, 1.40, 1.90]
## A player's Height moves the view by only this share of it, within VIEW_SHIFT_MIN..VIEW_SHIFT_MAX metres, as Beat
## Saber moves its grid by half the player's difference from 1.80 m, clamped to -0.2..+0.6 m (the view moves the
## other way).
const HEIGHT_FOLLOW := 0.5
## Where a crouch wall (one starting at row 2) begins, in metres; the player asked for 1.3 m (the plain 0.6 m steps
## put it at 1.2 m). Walls from row 2 up are raised by the difference (wall_y).
const CROUCH_WALL_BOTTOM := 1.3
const VIEW_SHIFT_MIN := -0.6
const VIEW_SHIFT_MAX := 0.2

## The height of a note row; fractional or outside rows (mapping extensions) carry on the nearest step.
static func layer_y(layer: float) -> float:
	var i := clampi(floori(layer), 0, ROW_Y.size() - 2)
	return lerpf(ROW_Y[i], ROW_Y[i + 1], layer - i)

## The height of a wall edge at a wall layer: 0.6 m steps, raised from row 2 up so crouch walls start at
## CROUCH_WALL_BOTTOM.
static func wall_y(layer: float) -> float:
	return layer * LANE_DISTANCE_Y + (CROUCH_WALL_BOTTOM - 2.0 * LANE_DISTANCE_Y) * clampf(layer - 1.0, 0.0, 1.0)

## How far the view moves for a player's Height setting.
static func view_shift(height_offset: float) -> float:
	return clampf(height_offset * HEIGHT_FOLLOW, VIEW_SHIFT_MIN, VIEW_SHIFT_MAX)
const MISS_Z := 2.5
## How far the track (every note, bomb, wall, arc and chain) is moved toward the player, so a note is on the beat
## 0.65 m in front of the player (XROrigin3D at z 1), near Beat Saber's cut plane, instead of 1 m. Further notes
## made players push from the shoulder instead of swinging (doc/research/scoring-and-reach.md). Track-local z 0 is
## still the beat; game/AGENTS.md lists what to check when this changes.
const HIT_PLANE_Z := 0.35
const DIRECTION8_OFFSET := 2 * TAU 
const DIRECTION8_COMPARE := DIRECTION8_OFFSET - .001
const ROTATION_EPS := 1e-5
const ROTATION_EPS_DEGREES := ROTATION_EPS * PI / 180.

var CUBE_ROTATIONS := PackedFloat64Array([PI, 0.0, -TAU*0.25, TAU*0.25, -TAU*0.375, TAU*0.375, -TAU*0.125, TAU*0.125, 0.0])
var ROTATION_UNIT_VECTORS := PackedVector2Array([
	Vector2(0, 1), Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0),
	Vector2(-0.70710678, 0.70710678), Vector2(0.70710678, 0.70710678),
	Vector2(-0.70710678, -0.70710678), Vector2(0.70710678, -0.70710678), Vector2(0,1)
])
var _global_path := ProjectSettings.globalize_path("user://")
var APPDATA_PATH := ( "user://OpenSaber/" if (OS.get_name() != "Android" or 
	  not _global_path.begins_with("/data/data/")) else "/sdcard/Android/data"+_global_path.substr(10) )
var CONFIG_ROOT_PATH := "user://" if APPDATA_PATH.begins_with("user://") else APPDATA_PATH
const OPENSABER_BEAT_ACCURACY_SCORE := 50.
const OPENSABER_ANGLE_ACCURACY_SCORE := 50.
const OPENSABER_DISTANCE_ACCURACY_SCORE := 50.
const OPENSABER_GOOD_SCORE := 88.
const OPENSABER_CHAIN_LINK_SCORE := 20
## Beat Saber's points (owner, 2026-10-26; bsmg.wiki/ranking-guide.html): 70 approach + 30 follow-through + 15
## centre = 115 a note, a chain head 70 + 15 = 85 and a link 20. They were 90 / 40 / 20 (150), the same shares.
const SWING_CHAIN_HEAD_SCORE = 85
const SWING_ACCURACY_SCORE = 15.
const SWING_PRESWING_SCORE = 70.
const SWING_FOLLOWTHROUGH_SCORE = 30.
const TARGET_PRESWING_ANGLE = 100.
const TARGET_FOLLOWTHROUGH_ANGLE = 60.
## a cut at or above this shows its number in the accent colour (95 of 150 before, the same share of 115)
const SWING_GOOD_SCORE := 73.
const SWING_CHAIN_LINK_SCORE := 20
const HEALTH_MISS := -15.
const HEALTH_BAD_CUT := -10.
const HEALTH_HIT  := 1.
const HEALTH_OBSTACLE_PER_SECOND := -130.
const HEALTH_BOMB := -15.
const HEALTH_MAX := 100.
const HEALTH_START := 50.
# How a song is failed when health mode is on, like Beat Saber's energy bar, 4 Lives and Instant Fail
const FAIL_MODE_BAR := 0
const FAIL_MODE_LIVES := 1
const FAIL_MODE_INSTANT := 2
const FAIL_LIVES := 4
# Modifiers dropdown: [health_mode, fail_mode, label]
# Health bar damage choices: [scale applied to every health loss, label]
const DAMAGE_SCALES := [ [0.5, "50%"], [1.0, "100%"], [1.5, "150%"] ]
const FAIL_OPTIONS := [ [false, FAIL_MODE_BAR, "No Fail"], [true, FAIL_MODE_BAR, "Health"], [true, FAIL_MODE_LIVES, "4 Lives"], [true, FAIL_MODE_INSTANT, "Instant"] ]
const DIFFICULTY_MASK := 0xFF
const DIFFICULTY_HEALTH := 0x100
const DIFFICULTY_BOMBS := 0x200
const DIFFICULTY_ARROWS := 0x400
const DIFFICULTY_CLAWS := 0x800
const DIFFICULTY_WIDTH_SHIFT := 12
const DIFFICULTY_WIDTH_BIT0 := 0x1000 # 1<<12
const DIFFICULTY_WIDTH_BIT1 := 0x2000
const DIFFICULTY_WIDTH_BIT2 := 0x40000
const DIFFICULTY_WIDTH_MASK := 0x1000 | 0x2000 | 0x4000
const WIDTHS := [ [100, "Normal Width", 0], [125, "Wide 125%", 1<<DIFFICULTY_WIDTH_SHIFT], [150, "Wide 150%", 2<<DIFFICULTY_WIDTH_SHIFT], [175, "Wide 175%", 3<<DIFFICULTY_WIDTH_SHIFT], [200, "Wide 200%", 4<<12] ]
#const DIFFICULTY_RESERVED := 0x8000
const DIFFICULTY_SPEED_SHIFT := 17
const DIFFICULTY_SPEED_BIT0 := 0x20000
const DIFFICULTY_SPEED_BIT1 := 0x40000
const DIFFICULTY_SPEED_BIT2 := 0x80000
const DIFFICULTY_SPEED_MASK := 0x20000 | 0x40000 | 0x80000
const SPEEDS := [ [85, "Speed 85%", 1<<DIFFICULTY_SPEED_SHIFT], [100, "Speed 100%", 0], [125, "Speed 125%", 2<<DIFFICULTY_SPEED_SHIFT], [150, "Speed 150%", 3<<DIFFICULTY_SPEED_SHIFT], [175, "Speed 175%", 4<<DIFFICULTY_SPEED_SHIFT]]
# Song list filters: [id, label, min, max], where max <= 0 means no upper limit. Length is in seconds.
## The song list's difficulty levels from easiest, computed from how a map plays rather than the mapper's
## label: [name, colour, least seconds a note is visible before reaching the player, least median seconds
## between two swings of one hand]. Edges are the midpoints between the medians of neighbouring BeatSaver
## difficulties (doc/research/reaction-time-and-swing-gap.md); not yet confirmed by headset playtests.
const DIFFICULTY_LEVELS := [
	["Easy", Color(0.24, 0.7, 0.44), 1.04, 0.866],
	["Normal", Color(0.35, 0.69, 0.96), 0.903, 0.646],
	["Hard", Color(1.0, 0.62, 0.26), 0.776, 0.496],
	["Expert", Color(0.91, 0.3, 0.24), 0.645, 0.383],
	["Expert+", Color(0.61, 0.35, 0.71), 0.0, 0.0],
]
## Swing flow levels from smoothest: [name, least percent of awkward swings (MapStats._awkward_percent)].
## Edges from doc/research/swing-flow.md (BeatSaver map data: about 70% of difficulties are under 4%,
## about 13% at 10% or more); not yet confirmed by headset playtests.
const FLOW_LEVELS := [ ["Smooth", 0.0], ["Twisty", 4.0], ["Tangled", 10.0] ]
## Difficulties with at least this percent of awkward swings are left out of the song list: hardly playable
## (the worst 5% of the BeatSaver sample, doc/research/swing-flow.md). Tangled ones below it stay, one level up.
const FLOW_HIDDEN_PERCENT := 25.0
## Wall workout labels by MapStats.workout_level: no sets, some sets, or at least WORKOUT_SET_SHARE of the song
## in sets (doc/research/wall-workout.md).
const WORKOUT_LEVELS := ["", "Some workout", "Workout"]
const WORKOUT_SET_SHARE := 0.3
## Difficulty filter choices: 0 shows every song, n songs with a difficulty at DIFFICULTY_LEVELS[n - 1] or easier.
const ANY_DIFFICULTY_LABEL := "Any difficulty"
## Difficulty filter label for a level above Easy, which also lists easier songs.
const UP_TO_LEVEL_LABEL := "Up to %s"
const LENGTH_FILTERS := [ [0, "Any length", 0.0, 0.0], [1, "Under 2 min", 0.0, 120.0], [2, "2-4 min", 120.0, 240.0], [3, "Over 4 min", 240.0, 0.0] ]
const DIFFICULTY_FLIP_SHIFT := 20
const DIFFICULTY_FLIP_HORIZONTAL := 0x100000
const DIFFICULTY_FLIP_VERTICAL := 0x200000
const DIFFICULTY_FLIP_MASK := 0x100000 | 0x200000
const DIFFICULTY_HANDEDNESS_FORCE_LEFT := 0x400000
const DIFFICULTY_HANDEDNESS_FORCE_RIGHT := 0x800000
## Both bits: it once shared Right Saber Only's bit, so those records read as Right Saber Only.
const DIFFICULTY_HANDEDNESS_IGNORE := 0x400000 | 0x800000
const DIFFICULTY_HANDEDNESS_MASK := 0x400000 | 0x800000
const FLIP_MASK := 3
const FLIP_HORIZONTAL := 1
const FLIP_VERTICAL := 2
const FLIPS := [ [0, "No Mirror" ], [FLIP_HORIZONTAL,"Mirror Left-Right"], [FLIP_VERTICAL,"Mirror Up-Down"], [FLIP_HORIZONTAL|FLIP_VERTICAL,"Mirror Both Ways"] ]
const HANDEDNESS_NORMAL := 0
const HANDEDNESS_IGNORE := 1
const HANDEDNESS_FORCE_LEFT := 2
const HANDEDNESS_FORCE_RIGHT := 3
const HANDEDNESSES := [ [0, "Normal Sabers"], [HANDEDNESS_IGNORE, "Any Saber, Any Color"], [HANDEDNESS_FORCE_LEFT, "Left Saber Only"], [HANDEDNESS_FORCE_RIGHT, "Right Saber Only"] ]
## Modifier labels without an option table; the Modifiers tab and the record table both use them.
const NO_BOMBS_LABEL := "No Bombs"
const NO_ARROWS_LABEL := "No Arrows"
const CLAWS_LABEL := "Short Sabers"
const SIZES := [ [50, "Small Blocks"], [100, "Normal Blocks"], [150, "Big Blocks"], [225, "Giant Blocks"]]
const DIFFICULTY_BLOCK_SIZE_MASK := 0x1000000 | 0x2000000
const DIFFICULTY_BLOCK_SIZE_SMALL := 0x1000000
const DIFFICULTY_BLOCK_SIZE_BIG := 0x2000000
const DIFFICULTY_BLOCK_SIZE_GIANT := 0x1000000 | 0x2000000
## Set in a record's rank when walls were off. 0x10000 is avoided: old records used it for small blocks.
const DIFFICULTY_NO_WALLS := 0x4000000
const NO_WALLS_LABEL := "No Walls"
## Modifiers change the score as Beat Saber's do (owner, 2026-10-26; bsmg.wiki/ranking-guide.html): their shares
## add up and the points are kept at 1 plus the sum. Ours that Beat Saber has take its values; speeds it lacks are read
## off a straight line through its (speed %, share) points, extended past the last; ours that make the game easier
## and have no Beat Saber match (wider lanes, bigger blocks, half damage) take a share in proportion. Harder ones
## without a match (short sabers, more damage), the health modes, flips and handedness: 0.
const NO_WALLS_SCORE := -0.05
const NO_BOMBS_SCORE := -0.10
const NO_ARROWS_SCORE := -0.30
## No Fail: half the score once health would have run out (Beat Saber: "0.00 / -0.50")
const NO_FAIL_SPENT_SCORE := -0.50
## Beat Saber's Slower (85%), Faster (120%) and Super Fast (150%) songs
const SPEED_SCORE: Array[Vector2] = [Vector2(85, -0.30), Vector2(100, 0.0), Vector2(120, 0.08), Vector2(150, 0.10)]
## wider lanes: -10% at 200% width; bigger blocks: -5% Big (150), -10% Giant (225); half damage: -10%
const WIDTH_SCORE: Array[Vector2] = [Vector2(100, 0.0), Vector2(200, -0.10)]
const BLOCK_SIZE_SCORE: Array[Vector2] = [Vector2(100, 0.0), Vector2(150, -0.05), Vector2(225, -0.10)]
const HALF_DAMAGE_SCORE := -0.10

## The share on a straight line through points (sorted by x), extended past the ends; nothing below the first for
## tables that start at 100 (sizes and widths under 100 are not easier).
static func score_share(points: Array[Vector2], x: float) -> float:
	if x <= points[0].x:
		return points[0].y if points[0].x >= 100.0 else _lerp_through(points[0], points[1], x)
	for i in range(1, points.size()):
		if x <= points[i].x:
			return _lerp_through(points[i - 1], points[i], x)
	return _lerp_through(points[-2], points[-1], x)

static func _lerp_through(a: Vector2, b: Vector2, x: float) -> float:
	return a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x)

# Menu colours, shared by the 3D panels (end score, buttons); keep in step with game/ui/menu_theme.tres.
const UI_PANEL := Color(0.086, 0.094, 0.114)
const UI_SURFACE := Color(0.133, 0.149, 0.18)
const UI_SURFACE_HOVER := Color(0.173, 0.192, 0.231)
const UI_SURFACE_PRESSED := Color(0.2, 0.36, 0.45)
const UI_BORDER := Color(0.208, 0.227, 0.271)
const UI_ACCENT := Color(0.37, 0.78, 0.94)
const UI_TEXT := Color(0.894, 0.902, 0.922)
const UI_TEXT_MUTED := Color(0.6, 0.63, 0.67)
## Text of a button asking before it deletes or resets something (ConfirmButton), and the song menu's warning icon
## (WarningIcon: something may hurt the player or the headset), always with its "!" or words.
const UI_DANGER := Color(1.0, 0.45, 0.4)
## Health strips when full: the light UI text tinted toward the accent. They shift to the song's danger colour as health drops.
const HEALTH_FULL_COLOR := Color(0.74, 0.86, 0.93)
# The X shown for a missed note: a softer red than pure red
const MISS_COLOR := Color("ff4d5e")
# The combo HUD's multiplier ring (ComboHud.gd): lit and unlit segments. A broken combo tints it MISS_COLOR for a moment.
const COMBO_RING_COLOR := UI_TEXT
const COMBO_RING_EMPTY_COLOR := Color(0.26, 0.28, 0.32)

# The scenery's shadows stay black: no colour toning (a navy tint in the darks was removed on the owner's request,
# 2026-10-26: it turned every stage's darkest colour dark navy).
# The Eerie atmosphere (Settings.atmosphere, agreed with the user 2026-10-22): the haze is pulled toward this cold
# grey; it stays dark, so the note colours keep standing out most.
const EERIE_HAZE_TINT := Color(0.8, 0.95, 1.05)
# Walls and bombs use one danger colour: Beat Saber's default wall red (agreed with the user 2026-10-19), unless the
# map sets its own wall colour.
const DANGER_COLOR := Color("ff3030")

# Rank colours on the score screen (the rank letter and the result ring), agreed with the user 2026-10-19.
# F is a muted red-grey, not the danger colour, which means "dodge".
const RANK_COLORS := {
	"SS": Color("ffeaa8"),
	"S": Color("ffd24d"),
	"A": Color("5ec7f0"),
	"B": Color("4de0a0"),
	"C": Color("f0e04d"),
	"D": Color("ff9f43"),
	"F": Color("8a5a5e"),
}

# Which of our environments a map gets on "Auto", keyed by the Beat Saber environment it names, without the
# "Environment" suffix (maps write both forms), grouped by the mood of the original scene. Default and names not
# here go by the song's genre (TAG_ENVIRONMENTS), then AUTO_ENVIRONMENTS.
const MAP_ENVIRONMENTS := {
	"Origins": "classic", "Nice": "classic", "BigMirror": "classic", "KDA": "classic", "Monstercat": "classic",
	"Triangle": "neon_grid", "Weave": "neon_grid", "EDM": "neon_grid", "Lattice": "neon_grid",
	"FitBeat": "neon_grid", "Timbaland": "neon_grid", "Interscope": "neon_grid", "Skrillex": "neon_grid",
	"BTS": "night_city", "Billie": "night_city", "LinkinPark": "night_city", "GreenDay": "night_city",
	"Gaga": "night_city", "Panic": "night_city", "Rocket": "night_city", "Weeknd": "night_city",
	"Kaleidoscope": "night_city",
	"Dragons": "pulse_void", "Spooky": "pulse_void", "Halloween": "pulse_void", "CrabRave": "pulse_void",
	"GlassDesert": "pulse_void", "TheSecond": "pulse_void", "RockMixtape": "pulse_void", "Pyro": "pulse_void",
}
# Environment for a map whose environment is Default, by the first of its BeatSaver genre tags found here.
const TAG_ENVIRONMENTS := {
	"electronic": "neon_grid", "house": "neon_grid", "techno": "neon_grid", "trance": "neon_grid",
	"pop": "night_city", "k-pop": "night_city", "j-pop": "night_city", "hip-hop-rap": "night_city",
	"rb": "night_city", "dance": "night_city", "anime": "night_city", "vocaloid": "night_city",
	"rock": "pulse_void", "punk": "pulse_void", "hardcore": "pulse_void", "alternative": "pulse_void",
	# the owner's pick, 2026-10-25 (BeatSaver has no "industrial" tag)
	"metal": "metal_factory", "dubstep": "metal_factory", "drum-and-bass": "metal_factory",
	"classical-orchestral": "classic", "jazz": "classic", "ambient": "classic", "kids-family": "classic",
	"tv-movie-soundtrack": "classic", "video-game-soundtrack": "classic",
}
# Environments a map with neither a known environment nor a genre tag is spread over, the same one for a song
# every time.
const AUTO_ENVIRONMENTS := ["classic", "neon_grid", "night_city", "pulse_void"]

# Difficulty colours as players know them from Beat Saber, keyed by the map's difficulty name.
const DIFFICULTY_COLORS := {
	"Easy": Color(0.24, 0.7, 0.44),
	"Normal": Color(0.35, 0.69, 0.96),
	"Hard": Color(1.0, 0.62, 0.26),
	"Expert": Color(0.91, 0.3, 0.24),
	"ExpertPlus": Color(0.61, 0.35, 0.71),
}
