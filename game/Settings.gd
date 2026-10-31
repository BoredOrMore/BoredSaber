extends Node

var config := ConfigFile.new()

const SECTION := "OpenSaber"
var CONFIG_PATH := Constants.CONFIG_ROOT_PATH + "config.ini"
var SABER_VISUALS: Array[PackedStringArray] = [
	PackedStringArray(["Default saber","res://game/sabers/default/default_saber.tscn"]),
	PackedStringArray(["Particle sword","res://game/sabers/particles/particles_saber.tscn"])
]

## Classic sky pictures: "Stage" is made by tools/make_stage_sky.py to follow AGENTS.md "Light".
const BACKGROUND_TEXTURES := [ ["res://game/data/background/stage_sky.png", "Stage"],
		["res://game/data/background/bg_base.jpg", "Original Open Saber"] ]

# Left/right note colours: bright enough to read as neon, but not fully saturated so long sessions are easier on the eyes.
const COLOR_PRESETS := [
		["Neon Classic", Color("3d7bff"), Color("ff3d5a")],
		["Cyber Pink", Color("00d8f0"), Color("ff2e9a")],
		["Synthwave", Color("8a5cff"), Color("ff8a3d")],
		["Toxic", Color("39f088"), Color("c04bff")],
		["Sunset", Color("ffb13d"), Color("ff4d8d")],
		["Sky & Gold", Color("3da9ff"), Color("ffd84d")],
		["Ice & Lava", Color("7fe0ff"), Color("ff5a1f")],
		["Mint & Coral", Color("4df0c0"), Color("ff6f61")],
		["Galaxy", Color("5b6cff"), Color("ff5be1")],
		["Lime & Grape", Color("b0f03d"), Color("8e3dff")] ]

## with Darker Notes on, note bodies are no brighter than this HSV value; hue and saturation stay
const NOTE_DARK_VALUE := 0.7
## the scenery around the track, picked on the song menu's Song tab; "auto" follows the environment each map was made for
## (EventDriver.pick_environment)
const ENVIRONMENTS := [ ["auto", "Follow map"], ["classic", "Classic"], ["neon_grid", "Neon Grid"], ["pulse_void", "Pulse Void"], ["night_city", "Night City"], ["metal_factory", "Metal Factory"], ["henge", "Henge"], ["monolith", "Monolith"] ]
## Graphics presets in Settings > Visuals: the effects each sets (Settings key: value). Glow was the only one
## measured to cost much on the headset (about 6 of a 13.9 ms frame). Both keep the light show (about 0.2 ms) and the
## slash note's light (about 0.3 ms): players missed them off.
const GRAPHICS_PRESETS := {
	"Low": {&"glare": false, &"smoke": false, &"saber_tail": false, &"cube_cuts_falloff": false, &"background": "dynamic"},
	"Normal": {&"glare": true, &"smoke": true, &"saber_tail": true, &"cube_cuts_falloff": true, &"background": "dynamic"},
}
const GRAPHICS_CUSTOM := "Custom"
## Render scales (OpenXR render target size multiplier) the player may pick: [name, scale]. Measured on the headset:
## Low at 1.44x takes about 11 of the 13.9 ms frame in a song; Normal was over budget already at 1.2x, so only Low
## could pick one, until the owner unlocked it on every preset (2026-10-25); a song that stutters still lowers Full to
## Sharp (resolution_cap).
const RESOLUTIONS := [["Normal", 1.0], ["Sharp", 1.2], ["Full", 1.44]]

## A RESOLUTIONS name the render scale is held at or below for the rest of the session ("" none): the game lowers
## Full to Sharp when a song stutters, leaving the picked resolution as it is.
var resolution_cap := ""

## The render scale in use: the picked resolution, at most resolution_cap.
func render_scale() -> float:
	var scale := _resolution_scale(resolution)
	if not resolution_cap.is_empty():
		scale = minf(scale, _resolution_scale(resolution_cap))
	return scale

static func _resolution_scale(resolution_name: String) -> float:
	for entry: Array in RESOLUTIONS:
		if entry[0] == resolution_name:
			return entry[1]
	return 1.0

## The preset the effects match, or GRAPHICS_CUSTOM when changed one by one.
func graphics_preset() -> String:
	for preset: String in GRAPHICS_PRESETS:
		var values: Dictionary = GRAPHICS_PRESETS[preset]
		if values.keys().all(func(key: StringName) -> bool: return get(key) == values[key]):
			return preset
	return GRAPHICS_CUSTOM

## Sets every effect of a preset.
## Sets every effect of a preset, and its anti-aliasing (PRESET_MSAA).
func set_graphics_preset(preset: String) -> void:
	var values: Dictionary = GRAPHICS_PRESETS[preset]
	for key: StringName in values:
		set(key, values[key])
	msaa = PRESET_MSAA[preset]

## The anti-aliasing a preset picks; the player may change it afterwards without the preset becoming Custom.
## Measured in a song on the headset: with Godot's glow 4x MSAA cost about 3.2 ms and went over the 13.9 ms frame;
## with the Soft glow (LowResGlow) about 0.7 ms, and without glow (Low) about 1.5 ms, so both presets use 4x.
const PRESET_MSAA := {"Low": "4x", "Normal": "4x"}

## The anti-aliasing for a config from before PRESET_MSAA: its preset's, or for Custom Off with glow, 4x without.
static func migrated_msaa(preset: String, glow: bool) -> String:
	return PRESET_MSAA.get(preset, "Off" if glow else "4x")

## Stage lights: a light show that follows the music, lights off, or lights off with the stage pieces hidden too.
const BACKGROUND_MODES := [ ["dynamic", "Light show"],
		["simple", "Off, no stage"],
		["static", "Off"] ]

signal changed(name: StringName)

var LANE_DISTANCE_X := Constants.DEFAULT_LANE_DISTANCE_X
var LANE_ZERO_X := Constants.DEFAULT_LANE_ZERO_X

## The sample songs were copied into the library once; saved, so a deleted sample stays deleted.
var preloaded_songs: bool:
	set(value):
		preloaded_songs = value
		set_and_emit(&"preloaded_songs", value)
var thickness: float:
	set(value):
		thickness = value
		set_and_emit(&"thickness", value)
var claws: bool:
	set(value):
		claws = value
		set_and_emit(&"claws", value)
var color_left: Color:
	set(value):
		color_left = value
		set_and_emit(&"color_left", value)
var color_right: Color:
	set(value):
		color_right = value
		set_and_emit(&"color_right", value)
var gradual_rotation: float:
	set(value):
		gradual_rotation = value
		set_and_emit(&"gradual_rotation", value)
var saber_visual: int:
	set(value):
		saber_visual = value
		set_and_emit(&"saber_visual", value)
var ui_volume: float:
	set(value):
		ui_volume = value
		set_and_emit(&"ui_volume", value)
var width: int:
	set(value):
		width = value
		LANE_DISTANCE_X = Constants.DEFAULT_LANE_DISTANCE_X * width / 100.
		LANE_ZERO_X = Constants.DEFAULT_LANE_ZERO_X * width / 100.
		set_and_emit(&"width", value)
var flip: int:
	set(value):
		flip = value
		set_and_emit(&"flip", value)
var handedness: int:
	set(value):
		handedness = value
		set_and_emit(&"handedness", value)
var left_saber_offset_pos: Vector3:
	set(value):
		left_saber_offset_pos = value
		set_and_emit(&"left_saber_offset_pos", value)
var left_saber_offset_rot: Vector3:
	set(value):
		left_saber_offset_rot = value
		set_and_emit(&"left_saber_offset_rot", value)
var right_saber_offset_pos: Vector3:
	set(value):
		right_saber_offset_pos = value
		set_and_emit(&"right_saber_offset_pos", value)
var right_saber_offset_rot: Vector3:
	set(value):
		right_saber_offset_rot = value
		set_and_emit(&"right_saber_offset_rot", value)
var cube_cuts_falloff: bool:
	set(value):
		cube_cuts_falloff = value
		set_and_emit(&"cube_cuts_falloff", value)
## a burst of sparks where a saber cuts a note (CutFlash)
var cut_flash: bool:
	set(value):
		cut_flash = value
		set_and_emit(&"cut_flash", value)
## sparks fly and both controllers buzz while the blades touch
var saber_clash_rumble: bool:
	set(value):
		saber_clash_rumble = value
		set_and_emit(&"saber_clash_rumble", value)
var saber_tail: bool:
	set(value):
		saber_tail = value
		set_and_emit(&"saber_tail", value)
var glare: bool:
	set(value):
		glare = value
		set_and_emit(&"glare", value)
var smoke: bool:
	set(value):
		smoke = value
		set_and_emit(&"smoke", value)
var show_debug_info: bool:
	set(value):
		show_debug_info = value
		set_and_emit(&"show_debug_info", value)
var mixed_reality: bool:
	set(value):
		mixed_reality = value
		set_and_emit(&"mixed_reality", value)
var explain: bool:
	set(value):
		explain = value
		set_and_emit(&"explain", value)
var left_handed: bool:
	set(value):
		left_handed = value
		set_and_emit(&"left_handed", value)
var not_music_dl: bool:
	set(value):
		not_music_dl = value
		set_and_emit(&"not_music_dl", value)
var swing_scoring: bool:
	set(value):
		swing_scoring = value
		set_and_emit(&"swing_scoring", value)
var bombs_enabled: bool:
	set(value):
		bombs_enabled = value
		set_and_emit(&"bombs_enabled", value)
## Walls modifier: off leaves every wall out of the song, for 5% less score (Constants.NO_WALLS_SCORE).
var walls_enabled: bool:
	set(value):
		walls_enabled = value
		set_and_emit(&"walls_enabled", value)
var events: bool:
	set(value):
		events = value
		set_and_emit(&"events", value)
var disable_map_color: bool:
	set(value):
		disable_map_color = value
		set_and_emit(&"disable_map_color", value)
var player_height_offset: float:
	set(value):
		player_height_offset = value
		set_and_emit(&"player_height_offset", value)
var audio_master: float:
	set(value):
		audio_master = value
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Master"), linear_to_db(value))
		set_and_emit(&"audio_master", value)
		Utils.update_bus_speed(&"Music")
		Utils.update_bus_speed(&"MusicPreview")
var audio_music: float:
	set(value):
		audio_music = value
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), linear_to_db(value))
		set_and_emit(&"audio_music", value)
		Utils.update_bus_speed(&"Music")
var music_speed: int:
	set(value):
		music_speed = value
		set_and_emit(&"music_speed", value)
		Utils.update_bus_speed(&"Music")
		Utils.update_bus_speed(&"MusicPreview")
var audio_music_preview: float:
	set(value):
		audio_music_preview = value
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"MusicPreview"), linear_to_db(value))
		set_and_emit(&"audio_music_preview", value)
		Utils.update_bus_speed(&"MusicPreview")
var audio_sfx: float:
	set(value):
		audio_sfx = value
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"), linear_to_db(value))
		set_and_emit(&"audio_sfx", value)
var spectator_view: bool:
	set(value):
		spectator_view = value
		set_and_emit(&"spectator_view", value)
## The display at 90 Hz instead of 72 when the headset offers it (vr.apply_refresh_rate): 72 is the default for every
## scene, a 13.9 ms frame (owner, 2026-10-26)
var refresh_90: bool:
	set(value):
		refresh_90 = value
		set_and_emit(&"refresh_90", value)
var spectator_hud: bool:
	set(value):
		spectator_hud = value
		set_and_emit(&"spectator_hud", value)
var background: String:
	set(value):
		background = value
		set_and_emit(&"background", value)
var environment: String:
	set(value):
		environment = value
		set_and_emit(&"environment", value)
## Anti-aliasing (MSAA) of the 3D view: [name, Viewport.MSAA value]. 4x is the default: on a tiled GPU like the
## Pico 4's it resolves in tile memory, so it smooths the thin lasers, note edges and floor lines cheaply.
const MSAA_LEVELS := [["Off", Viewport.MSAA_DISABLED], ["2x", Viewport.MSAA_2X], ["4x", Viewport.MSAA_4X]]
## Which glow draws while Glow is on: a GLOW_QUALITIES name. Soft and Crisp are LowResGlow at two sizes; Classic
## is Godot's own (about 5 ms in a song on the Pico 4, against 0.2 for Soft).
const GLOW_QUALITIES := ["Soft", "Crisp", "Classic"]
var glow_quality: String:
	set(value):
		glow_quality = value
		set_and_emit(&"glow_quality", value)

## The air: "Normal", or "Eerie" (thicker low fog that stays during songs, colder darker haze and shadows, slower
## dimmer dust and menu lights). Not part of the graphics presets.
const ATMOSPHERES := ["Normal", "Eerie"]
var atmosphere: String:
	set(value):
		atmosphere = value
		set_and_emit(&"atmosphere", value)

## The anti-aliasing picked (an MSAA_LEVELS name).
var msaa: String:
	set(value):
		msaa = value
		set_and_emit(&"msaa", value)

## The Viewport.MSAA value for msaa.
func msaa_mode() -> Viewport.MSAA:
	for entry: Array in MSAA_LEVELS:
		if entry[0] == msaa:
			return entry[1]
	return Viewport.MSAA_DISABLED

## The resolution picked (a RESOLUTIONS name), on any preset.
var resolution: String:
	set(value):
		resolution = value
		set_and_emit(&"resolution", value)
var darker_notes: bool:
	set(value):
		darker_notes = value
		set_and_emit(&"darker_notes", value)
var background_texture: String:
	set(value):
		background_texture = value
		set_and_emit(&"background_texture", value)
var health_mode: bool:
	set(value):
		health_mode = value
		set_and_emit(&"health_mode", value)
var fail_mode: int:
	set(value):
		fail_mode = value
		set_and_emit(&"fail_mode", value)
## The current player, one of players.
var player_name: String:
	set(value):
		player_name = value
		set_and_emit(&"player_name", value)
## The players on this headset, each {"name": String, "player_height_offset": float, "left_handed": bool}. The
## current one's height and handedness are the top-level settings while it plays (_store_current_player()).
var players: Array:
	set(value):
		players = value
		set_and_emit(&"players", value)
var damage_scale: float:
	set(value):
		damage_scale = value
		set_and_emit(&"damage_scale", value)
var arrows_enabled: bool:
	set(value):
		arrows_enabled = value
		set_and_emit(&"arrows_enabled", value)
var block_size: int:
	set(value):
		block_size = value
		set_and_emit(&"block_size", value)
var last_map: String:
	set(value):
		last_map = value
		set_and_emit(&"last_map", value)
var song_filter_length: int:
	set(value):
		song_filter_length = value
		set_and_emit(&"song_filter_length", value)
var song_filter_reaction: int:
	set(value):
		song_filter_reaction = value
		set_and_emit(&"song_filter_reaction", value)
var song_filter_favorites: bool:
	set(value):
		song_filter_favorites = value
		set_and_emit(&"song_filter_favorites", value)
var song_filter_workout: bool:
	set(value):
		song_filter_workout = value
		set_and_emit(&"song_filter_workout", value)
## The song menu's style and genre filters: a BeatSaver tag (SongTags.STYLES, GENRES), "" for any.
var song_filter_style: String:
	set(value):
		song_filter_style = value
		set_and_emit(&"song_filter_style", value)
var song_filter_genre: String:
	set(value):
		song_filter_genre = value
		set_and_emit(&"song_filter_genre", value)
## The practice speed in percent (Map.practice_speed), kept for the next practice (owner, 2026-10-30: 50-200%).
var practice_speed: int:
	set(value):
		# config.ini is a boundary: a hand-edited value lands on a step in range
		practice_speed = clampi(snappedi(value, Constants.PRACTICE_SPEED_STEP), Constants.PRACTICE_SPEED_MIN,
				Constants.PRACTICE_SPEED_MAX)
		set_and_emit(&"practice_speed", practice_speed)
## Get songs lists AI-made maps too (owner, 2026-10-30; off: BeatSaver leaves them out).
var beatsaver_include_ai: bool:
	set(value):
		beatsaver_include_ai = value
		set_and_emit(&"beatsaver_include_ai", value)
## Length filter of the BeatSaver page, kept apart from the song menu's so changing one doesn't empty the other.
var beatsaver_filter_length: int:
	set(value):
		beatsaver_filter_length = value
		set_and_emit(&"beatsaver_filter_length", value)
## Difficulty filter of the BeatSaver page, kept apart from the song menu's.
var beatsaver_filter_reaction: int:
	set(value):
		beatsaver_filter_reaction = value
		set_and_emit(&"beatsaver_filter_reaction", value)
	
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(Constants.CONFIG_ROOT_PATH)

	if OS.get_name() in platform_default_values.keys():
		for key in platform_default_values[OS.get_name()].keys():
			default_values[key] = platform_default_values[OS.get_name()][key]
	
	if FileAccess.file_exists(CONFIG_PATH):
		reload()
	else:
		restore_defaults()
		save()
	# first launch with profiles: the saved name becomes the only player
	if players.is_empty():
		players = [_new_player(player_name.strip_edges() if not player_name.strip_edges().is_empty() else "Player")]
		player_name = players[0].name
		_store_current_player()
	changed.connect(func(key: StringName) -> void:
		if key == &"player_height_offset" or key == &"left_handed" or key == &"beatsaver_filter_reaction":
			_store_current_player())

const platform_default_values = {
	Web = {
		glare = false,
		saber_tail = false,
		cube_cuts_falloff = false,
		events = false,
	},
}

var default_values = {
	thickness = 1.0,
	cube_cuts_falloff = true,
	cut_flash = true,
	saber_clash_rumble = true,
	color_left = COLOR_PRESETS[0][1],
	color_right = COLOR_PRESETS[0][2],
	saber_tail = true,
	gradual_rotation = 0,
	# first-run effects match the Normal graphics preset
	glare = true,
	smoke = true,
	show_debug_info = false,
	mixed_reality = false,
	explain = false,
	left_handed = false,
	not_music_dl = false,
	swing_scoring = true,
	bombs_enabled = true,
	walls_enabled = true,
	events = true,
	saber_visual = 0,
	ui_volume = 10.0,
	width = 100,
	flip = 0,
	handedness = 0,
	left_saber_offset_pos = Vector3.ZERO,
	# sabers turned 5 degrees outward (positive y is outward on the left, negative on the right)
	left_saber_offset_rot = Vector3(0, 5, 0),
	right_saber_offset_pos = Vector3.ZERO,
	right_saber_offset_rot = Vector3(0, -5, 0),
	disable_map_color = false,
	player_height_offset = 0.0,
	audio_master = 0.8,
	audio_music = 0.8,
	music_speed = 100,
	audio_music_preview = 0.6,
	audio_sfx = 0.8,
	spectator_view = false,
	spectator_hud = true,
	refresh_90 = false,
	background = "dynamic",
	environment = "auto",
	resolution = "Normal",
	msaa = "4x",
	glow_quality = "Soft",
	atmosphere = "Normal",
	darker_notes = false,
	background_texture = "res://game/data/background/stage_sky.png",
	health_mode = true,
	fail_mode = 0,
	damage_scale = 1.0,
	player_name = "Player",
	arrows_enabled = true,
	block_size = 100,
	last_map = "",
	song_filter_length = 0,
	song_filter_reaction = 0,
	song_filter_favorites = false,
	song_filter_workout = false,
	song_filter_style = "",
	song_filter_genre = "",
	beatsaver_filter_length = 0,
	beatsaver_include_ai = false,
	practice_speed = 100,
	beatsaver_filter_reaction = 0,
	claws = false,
	preloaded_songs = false,
	players = [],
}

func cast_or_default(key: String, to_type: int = -1) -> Variant:
	var default = default_values[key] if key in default_values else null
	return convert(config.get_value(SECTION, key, default), typeof(default) if to_type < 0 else to_type)

func set_and_emit(key: StringName, value: Variant) -> void:
	config.set_value(SECTION, String(key), value if default_values[key] != value else null)
	changed.emit(key)

# load() is the name of a built-in function,
# so i went with the next best thing.
## Marks a config written since glow is on by default (see reload).
const GLOW_DEFAULT_ON := "glow_default_on"
## Marks a config written since the anti-aliasing follows the graphics preset (see reload).
const MSAA_PER_PRESET := "msaa_per_preset"
## Marks a config written since Normal's anti-aliasing is 4x (see reload).
const NORMAL_MSAA_4X := "normal_msaa_4x"

func reload() -> void:
	var config_error := config.load(CONFIG_PATH)
	if config_error != OK:
		vr.log_file_error(config_error, CONFIG_PATH, "reload() in Settings.gd")
		return
	
	# Glow was off by default until the defaults became the Normal preset: a player who left it at that default
	# (not saved) keeps it off, once.
	if not config.has_section_key(SECTION, GLOW_DEFAULT_ON):
		if not config.has_section_key(SECTION, "glare"):
			config.set_value(SECTION, "glare", false)
		config.set_value(SECTION, GLOW_DEFAULT_ON, true)
	for key in default_values:
		set(key, cast_or_default(key))
	# The glow test's style (glow_style) becomes the glow quality, once: Godot's is Classic.
	if config.has_section_key(SECTION, "glow_style"):
		if config.get_value(SECTION, "glow_style") == "godot":
			glow_quality = "Classic"
		config.erase_section_key(SECTION, "glow_style")
	# A build forced 4x MSAA on every config; once, configs get their preset's (migrated_msaa).
	if not config.has_section_key(SECTION, MSAA_PER_PRESET):
		msaa = migrated_msaa(graphics_preset(), glare)
		config.set_value(SECTION, MSAA_PER_PRESET, true)
	# Normal's anti-aliasing was Off while Godot's glow made 4x too costly; once, Normal configs with it Off get 4x.
	if not config.has_section_key(SECTION, NORMAL_MSAA_4X):
		if graphics_preset() == "Normal" and msaa == "Off":
			msaa = "4x"
		config.set_value(SECTION, NORMAL_MSAA_4X, true)

func save() -> void:
	var error := config.save(CONFIG_PATH)
	if error != OK:
		vr.log_file_error(error, CONFIG_PATH, "save() in Settings.gd")
		return

## Puts every setting back to its default; the library's sample songs aren't a setting, so they aren't copied again,
## and the players stay (the current one gets the default height and handedness).
func restore_defaults() -> void:
	var samples_copied := preloaded_songs
	var kept_players := players.duplicate(true)
	var kept_name := player_name
	config.clear()
	config.set_value(SECTION, GLOW_DEFAULT_ON, true)
	config.set_value(SECTION, MSAA_PER_PRESET, true)
	config.set_value(SECTION, NORMAL_MSAA_4X, true)
	save()
	reload()
	preloaded_songs = samples_copied
	if not kept_players.is_empty():
		players = kept_players
		player_name = kept_name
		_store_current_player()
	save()

## Most players one headset keeps.
const MAX_PLAYERS := 6

## A player with the default height and handedness.
func _new_player(new_name: String) -> Dictionary:
	return {"name": new_name, "player_height_offset": default_values.player_height_offset, "left_handed": default_values.left_handed}

## The players entry called new_name (ignoring case), or an empty Dictionary.
func find_player(new_name: String) -> Dictionary:
	for player: Dictionary in players:
		if (player.name as String).to_lower() == new_name.strip_edges().to_lower():
			return player
	return {}

## Copies the current height, handedness and Download page level into the current player's entry, and saves the list.
func _store_current_player() -> void:
	var player := find_player(player_name)
	if player.is_empty():
		return
	player.player_height_offset = player_height_offset
	player.left_handed = left_handed
	player.beatsaver_level = beatsaver_filter_reaction
	players = players

## Why new_name can't name a player (empty, or taken by another player than old_name), or "" when it can.
func player_name_problem(new_name: String, old_name := "") -> String:
	new_name = new_name.strip_edges()
	if new_name.is_empty():
		return "Type a name"
	var other := find_player(new_name)
	if not other.is_empty() and (other.name as String).to_lower() != old_name.to_lower():
		return "%s is already a player" % other.name
	return ""

## Makes the named player the current one, with their height and handedness.
func switch_player(new_name: String) -> void:
	var player := find_player(new_name)
	assert(not player.is_empty(), "no player %s" % new_name)
	player_name = player.name
	player_height_offset = player.player_height_offset
	left_handed = player.left_handed
	beatsaver_filter_reaction = int(player.get("beatsaver_level", 0))
	save()

## Adds a player with default height and handedness and makes them the current one.
func add_player(new_name: String) -> void:
	assert(player_name_problem(new_name) == "" and players.size() < MAX_PLAYERS)
	players.append(_new_player(new_name.strip_edges()))
	switch_player(new_name)

## Renames a player (and the current name, if it's them). Their records are renamed by HighscoreTable.
func rename_player(old_name: String, new_name: String) -> void:
	var player := find_player(old_name)
	assert(not player.is_empty() and player_name_problem(new_name, old_name) == "")
	var was_current := (player.name as String) == player_name
	player.name = new_name.strip_edges()
	players = players
	if was_current:
		player_name = player.name
	save()

## Removes a player who isn't the current one; their records stay.
func delete_player(old_name: String) -> void:
	var player := find_player(old_name)
	assert(not player.is_empty() and (player.name as String) != player_name)
	players.erase(player)
	players = players
	save()
	
func get_saber_visuals() -> String:
	return SABER_VISUALS[saber_visual if not claws else 0][1]
