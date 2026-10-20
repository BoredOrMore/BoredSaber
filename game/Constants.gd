extends Node

const DEFAULT_LANE_ZERO_X := -0.9
const LAYER_ZERO_Y := 0.8
const BEAT_DISTANCE := 4.0
const DEFAULT_LANE_DISTANCE_X := 0.6
const LANE_DISTANCE_Y := 0.6
## Eye height the note rows (0.8, 1.4 and 2.0 m) and crouch walls (1.2 m) suit, as Beat Saber's default 1.80 m player
## (eyes about 0.1 m below the top of the head); "Measure my height" moves the view to it.
const EYE_HEIGHT := 1.7
const MISS_Z := 2.5
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
const SWING_CHAIN_HEAD_SCORE = 90
const SWING_ACCURACY_SCORE = 20.
const SWING_PRESWING_SCORE = 90.
const SWING_FOLLOWTHROUGH_SCORE = 40.
const TARGET_PRESWING_ANGLE = 100.
const TARGET_FOLLOWTHROUGH_ANGLE = 60.
const SWING_GOOD_SCORE := 95.
const SWING_CHAIN_LINK_SCORE := 25
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
const WIDTHS := [ [100, "No Stretch", 0], [125, "Stretch 125%", 1<<DIFFICULTY_WIDTH_SHIFT], [150, "Stretch 150%", 2<<DIFFICULTY_WIDTH_SHIFT], [175, "Stretch 175%", 3<<DIFFICULTY_WIDTH_SHIFT], [200, "Stretch 200%", 4<<12] ]
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
## Difficulty filter choices: 0 shows every song, n songs with a difficulty at DIFFICULTY_LEVELS[n - 1].
const ANY_DIFFICULTY_LABEL := "Any"
const LENGTH_FILTERS := [ [0, "Any length", 0.0, 0.0], [1, "Under 2 min", 0.0, 120.0], [2, "2-4 min", 120.0, 240.0], [3, "Over 4 min", 240.0, 0.0] ]
const DIFFICULTY_FLIP_SHIFT := 20
const DIFFICULTY_FLIP_HORIZONTAL := 0x100000
const DIFFICULTY_FLIP_VERTICAL := 0x200000
const DIFFICULTY_FLIP_MASK := 0x100000 | 0x200000
const DIFFICULTY_HANDEDNESS_FORCE_LEFT := 0x400000
const DIFFICULTY_HANDEDNESS_FORCE_RIGHT := 0x800000
const DIFFICULTY_HANDEDNESS_IGNORE := 0x800000
const DIFFICULTY_HANDEDNESS_MASK := 0x400000 | 0x800000
const FLIP_MASK := 3
const FLIP_HORIZONTAL := 1
const FLIP_VERTICAL := 2
const FLIPS := [ [0, "No Flip" ], [FLIP_HORIZONTAL,"Flip Horiz"], [FLIP_VERTICAL,"Flip Vert"], [FLIP_HORIZONTAL|FLIP_VERTICAL,"Flip HV"] ]
const HANDEDNESS_NORMAL := 0
const HANDEDNESS_IGNORE := 1
const HANDEDNESS_FORCE_LEFT := 2
const HANDEDNESS_FORCE_RIGHT := 3
const HANDEDNESSES := [ [0, "Normal Hands"], [HANDEDNESS_IGNORE, "Ignore Side"], [HANDEDNESS_FORCE_LEFT, "Left Only"], [HANDEDNESS_FORCE_RIGHT, "Right Only"] ]
const SIZES := [ [50, "Small Blocks"], [100, "Normal Blocks"], [150, "Big Blocks"], [225, "Giant Blocks"]]
const DIFFICULTY_BLOCK_SIZE_MASK := 0x1000000 | 0x2000000
const DIFFICULTY_BLOCK_SIZE_SMALL := 0x1000000
const DIFFICULTY_BLOCK_SIZE_BIG := 0x2000000
const DIFFICULTY_BLOCK_SIZE_GIANT := 0x1000000 | 0x2000000

# Menu colours, shared by the 3D panels (end score, buttons); keep in step with game/ui/menu_theme.tres.
const UI_PANEL := Color(0.086, 0.094, 0.114)
const UI_SURFACE := Color(0.133, 0.149, 0.18)
const UI_SURFACE_HOVER := Color(0.173, 0.192, 0.231)
const UI_SURFACE_PRESSED := Color(0.2, 0.36, 0.45)
const UI_BORDER := Color(0.208, 0.227, 0.271)
const UI_ACCENT := Color(0.37, 0.78, 0.94)
const UI_TEXT := Color(0.894, 0.902, 0.922)
const UI_TEXT_MUTED := Color(0.6, 0.63, 0.67)
## Text of a button asking before it deletes or resets something (ConfirmButton).
const UI_DANGER := Color(1.0, 0.45, 0.4)
## Health strips when full: the light UI text tinted toward the accent. They shift to the song's danger colour as health drops.
const HEALTH_FULL_COLOR := Color(0.74, 0.86, 0.93)
# The X shown for a missed note: a softer red than pure red
const MISS_COLOR := Color("ff4d5e")
# The combo HUD's multiplier ring (ComboHud.gd): lit and unlit segments. A broken combo tints it MISS_COLOR for a moment.
const COMBO_RING_COLOR := UI_TEXT
const COMBO_RING_EMPTY_COLOR := Color(0.26, 0.28, 0.32)

# Shadow toning for the scenery: black becomes SHADOW_TINT, fading out toward mid-tones (game/env/shadow_tone.gdshaderinc).
const SHADOW_TINT := Color(0.0, 0.0, 0.102)
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
	"dubstep": "neon_grid", "drum-and-bass": "neon_grid",
	"pop": "night_city", "k-pop": "night_city", "j-pop": "night_city", "hip-hop-rap": "night_city",
	"rb": "night_city", "dance": "night_city", "anime": "night_city", "vocaloid": "night_city",
	"rock": "pulse_void", "metal": "pulse_void", "punk": "pulse_void", "hardcore": "pulse_void",
	"alternative": "pulse_void",
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
