extends Node

const DEFAULT_LANE_ZERO_X := -0.9
const LAYER_ZERO_Y := 0.8
const BEAT_DISTANCE := 4.0
const DEFAULT_LANE_DISTANCE_X := 0.6
const LANE_DISTANCE_Y := 0.6
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
const NPS_FILTERS := [ [0, "Any note count", 0.0, 0.0], [1, "Few: under 3 a sec", 0.0, 3.0], [2, "Some: 3-5 a sec", 3.0, 5.0], [3, "Many: 5-7 a sec", 5.0, 7.0], [4, "Packed: 7+ a sec", 7.0, 0.0] ]
## Reaction time levels from easiest: [name, colour, least seconds a note is visible before reaching
## the player]. Band edges from doc/research/reaction-time-and-swing-gap.md (BeatSaver map data,
## midpoints between the median of neighbouring difficulties); not yet confirmed by headset playtests.
const REACTION_LEVELS := [
	["Relaxed", Color(0.24, 0.7, 0.44), 1.0],
	["Comfortable", Color(0.35, 0.69, 0.96), 0.8],
	["Quick", Color(1.0, 0.62, 0.26), 0.65],
	["Fast", Color(0.91, 0.3, 0.24), 0.55],
	["Extreme", Color(0.61, 0.35, 0.71), 0.0],
]
## Swing pace levels from easiest: [name, least median seconds between two swings of one hand]. Same
## source and status as REACTION_LEVELS.
const SWING_PACE_LEVELS := [
	["Calm", 0.8],
	["Steady", 0.55],
	["Brisk", 0.42],
	["Rapid", 0.33],
	["Frantic", 0.0],
]
## Reaction time filter choices: 0 shows every song, n songs with a difficulty at REACTION_LEVELS[n - 1].
const ANY_REACTION_LABEL := "Any"
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
## Health strips when full: the light UI text tinted toward the accent. They shift to the song's danger colour as health drops.
const HEALTH_FULL_COLOR := Color(0.74, 0.86, 0.93)
# The X shown for a missed note: a softer red than pure red
const MISS_COLOR := Color("ff4d5e")

# Shadow toning for the whole scene: black becomes SHADOW_TINT, fading out by SHADOW_TINT_FADE_LUMA (sRGB luma).
const SHADOW_TINT := Color(0.0, 0.0, 0.102)
const SHADOW_TINT_FADE_LUMA := 0.45
const SHADOW_TINT_LUT_SIZE := 32
# Walls and bombs use one danger colour: warning amber, unless a note colour's hue is within
# DANGER_MIN_HUE_GAP (0-1 around the colour wheel) of it; then whichever candidate is farthest from both.
const DANGER_COLORS := [Color("ffb020"), Color("ff3b30"), Color("ffe14d")]
const DANGER_MIN_HUE_GAP := 30.0 / 360.0

# Difficulty colours as players know them from Beat Saber, keyed by the map's difficulty name.
const DIFFICULTY_COLORS := {
	"Easy": Color(0.24, 0.7, 0.44),
	"Normal": Color(0.35, 0.69, 0.96),
	"Hard": Color(1.0, 0.62, 0.26),
	"Expert": Color(0.91, 0.3, 0.24),
	"ExpertPlus": Color(0.61, 0.35, 0.71),
}
