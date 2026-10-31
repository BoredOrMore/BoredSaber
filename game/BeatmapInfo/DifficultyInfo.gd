extends RefCounted
class_name DifficultyInfo

## Mods a map may require that this game plays without (owner, 2026-10-30): Mapping Extensions' precise lanes, rows
## and angles are read (Utils.precise_measurement, precise_layer, precise_angle_rad); Chroma and Cinema only colour
## the lights or add a video. Any other required mod (Noodle Extensions, Vivify, ...) makes a difficulty unplayable.
const PLAYABLE_MODS := ["Mapping Extensions", "Chroma", "Cinema"]

var difficulty: String
var difficulty_rank: int
var characteristic: String
var beatmap_filename: String
## the v4 file holding this difficulty's lights ("" before v4, where the lights are in the beatmap file)
var lightshow_filename := ""
var note_jump_movement_speed: float
var note_jump_start_beat_offset: float
var custom_data: Dictionary
# not officially part of the spec, but used by mods a lot
var custom_name: String

func _init(
	difficulty: String, difficulty_rank: int, beatmap_filename: String,
	note_jump_movement_speed: float, note_jump_start_beat_offset: float,
	custom_data: Dictionary, custom_name: String, characteristic: String
) -> void:
	self.difficulty = difficulty
	self.difficulty_rank = difficulty_rank
	self.beatmap_filename = beatmap_filename
	self.note_jump_movement_speed = note_jump_movement_speed
	self.note_jump_start_beat_offset = note_jump_start_beat_offset
	self.custom_data = custom_data
	# not officially part of the spec, but used by mods a lot
	self.custom_name = custom_name
	self.characteristic = characteristic

## The first mod the difficulty requires (its "_requirements", or v4's "requirements") that the game doesn't have, or
## "" when it plays here.
func missing_mod() -> String:
	for mod: Variant in Utils.get_array(custom_data, "_requirements", Utils.get_array(custom_data, "requirements", [])):
		if mod is String and not PLAYABLE_MODS.has(mod):
			return mod
	return ""

func get_display_name() -> String:
	var name := ""
	if self.custom_name != null and custom_name.length() > 0:
		name = self.custom_name
	else:
		name = self.difficulty
	if self.characteristic != "" and self.characteristic != "Standard":
		return name + " " + self.characteristic
	else:
		return name

static func load_v2(diff_dict: Dictionary, characteristic: String) -> DifficultyInfo:
	var diff := Utils.get_str(diff_dict, "_difficulty", "")
	var data := Utils.get_dict(diff_dict, "_customData", {})
	
	var name := ""
	# not officially part of the spec, but used by mods a lot
	if not data.is_empty():
		name = Utils.get_str(data, "_difficultyLabel", "")
	if name.is_empty():
		name = diff
	
	return DifficultyInfo.new(
		diff,
		int(Utils.get_float(diff_dict, "_difficultyRank", 0)),
		Utils.get_str(diff_dict, "_beatmapFilename", ""),
		Utils.get_float(diff_dict, "_noteJumpMovementSpeed", 1.0),
		Utils.get_float(diff_dict, "_noteJumpStartBeatOffset", 0.0),
		data,
		name,
		characteristic
	)

static func load_v4(diff_dict: Dictionary) -> DifficultyInfo:
	var diff := Utils.get_str(diff_dict, "difficulty", "")
	var data := Utils.get_dict(diff_dict, "customData", {})
	
	var name := ""
	# not officially part of the spec, but used by mods a lot
	if not data.is_empty():
		name = Utils.get_str(data, "difficultyLabel", "")
	if name.is_empty():
		name = diff
	
	var info := DifficultyInfo.new(
		diff,
		0, # TODO: difficulty rank
		Utils.get_str(diff_dict, "beatmapDataFilename", ""),
		Utils.get_float(diff_dict, "noteJumpMovementSpeed", 1.0),
		Utils.get_float(diff_dict, "noteJumpStartBeatOffset", 0.0),
		data,
		name,
		Utils.get_str(diff_dict, "characteristic", "")
	)
	info.lightshow_filename = Utils.get_str(diff_dict, "lightshowDataFilename", "")
	return info
