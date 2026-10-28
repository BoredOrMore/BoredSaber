extends Node3D
class_name EventDriver

## How far a flash overshoots the base light colour. Kept low: jumps to near-white strain the eyes.
const FLASH_BOOST := 1.6
# sphere shader parameter per light type, so tween steps don't format a name every frame
const INTENSITY_PARAMS: Array[StringName] = [&"bg_0_intensity", &"bg_1_intensity", &"bg_2_intensity", &"bg_3_intensity", &"bg_4_intensity"]
## Air colour with every light off, and how much each lit group tints the haze (sky, distant scenery). Untuned.
const HAZE_BASE := Color(0.01, 0.01, 0.02)
const HAZE_LIGHT_WEIGHT := 0.08
## How far the air's colour leans to grey of the same brightness: haze reveals light, it doesn't paint the scene
## (AGENTS.md "Light", rule 6). Untuned.
const HAZE_NEUTRAL := 0.5
## A combo milestone (ComboHud) brightens the air for a moment: the haze jumps by this part of itself and fades
## out over COMBO_PULSE_SECONDS. Below the map's own flashes (FLASH_BOOST), so it reads as a bonus, not an event. Untuned.
const COMBO_PULSE := 0.8
const COMBO_PULSE_SECONDS := 0.6
## The higher the combo multiplier, the brighter the air and the laser bars, up to these parts more at x8; a
## broken combo dims them again. Rises slowly, falls faster. Kept small and never flashing, for comfort. Untuned.
const COMBO_HAZE_BOOST := 0.3
const COMBO_LASER_BOOST := 0.2
const COMBO_PULSE_LASER := 0.3
const COMBO_RISE_SECONDS := 1.0
const COMBO_FALL_SECONDS := 0.3
## In the menus the stage waits like a concert before the show: dim lights in a cool house tone that slowly
## "breathe" between MENU_BREATH_LOW and MENU_BREATH_HIGH of their colour (the haze as in play: owner, 2026-10-27, the
## menus as clear as can be), and the
## waving lasers sweeping slowly through it at MENU_LASER_LEVEL from their fixtures at the sides. Slow and dim on
## purpose so the menu still holds the eye: no bright or busy motion in the periphery, and nothing oscillating
## near 0.2 Hz (Apple visionOS HIG, Spatial layout, Motion). All values untuned.
const MENU_BREATH_LOW := 0.3
const MENU_BREATH_HIGH := 0.4
const MENU_BREATH_SECONDS := 12.0
## Settings.atmosphere Eerie: the menu lights breathe lower and slower, and the air is darker, greyer and colder
## (Constants.EERIE_HAZE_TINT). Untuned.
const EERIE_BREATH_LOW := 0.2
const EERIE_BREATH_HIGH := 0.28
const EERIE_BREATH_SECONDS := 20.0
const EERIE_HAZE_DIM := 0.7
const EERIE_HAZE_NEUTRAL := 0.8
const MENU_LASER_LEVEL := 0.2
const MENU_LASER_SWEEP_SECONDS := 30.0
## The house light colour the menu lights lean toward, and how far (0 = note colours only): a near-neutral
## cool grey, like Beat Saber's menu, so the stage doesn't look tinted (saturation about 0.09). Untuned.
const HOUSE_COLOR := Color(0.62, 0.64, 0.68)
const MENU_HOUSE_MIX := 0.85
## Seconds the menu lights take to fade in before they start breathing.
const MENU_FADE_SECONDS := 1.0
## A menu is showing: pre-show lighting (see MENU_BREATH_LOW), rings still.
var menu_focus := false
var _menu_time := 0.0
## The sky draws after every other solid thing, so the GPU skips the parts of it hidden behind the floor,
## the track and the scenery instead of shading the whole sphere first (Godot draws higher priority later).
const SKY_RENDER_PRIORITY := Material.RENDER_PRIORITY_MAX
## mask textures of the skies that use them, by shader parameter
const SKY_TEXTURES := {
	"neon_grid": {
		"sharp_masks": "res://game/env/neon_grid_sky_sharp.png",
		"soft_masks": "res://game/env/neon_grid_sky_soft.png",
	},
	"night_city": {
		"sharp_masks": "res://game/env/night_city_sky_sharp.png",
		"soft_masks": "res://game/env/night_city_sky_soft.png",
	},
}
## the sky shader of each environment other than Classic, which keeps the one in the scene
const SKY_SHADERS := {
	"neon_grid": preload("res://game/env/NeonGridSky.gdshader"),
	"pulse_void": preload("res://game/env/PulseVoidSky.gdshader"),
	"night_city": preload("res://game/env/NightCitySky.gdshader"),
	"metal_factory": preload("res://game/env/MetalFactorySky.gdshader"),
}

var ring_rot_speed := 0.0
var ring_rot_inv_dir := false
var rings_in := false

var left_color: Color
var right_color: Color

## The room each environment gives the song-end stingers (fail, clear) on the Stinger bus: properties of its
## reverb (effect 0) and delay (effect 1). Cuts, misses and menu sounds stay dry on other buses. Untuned guesses
## at the sound plan: Classic a medium tunnel (RT60 ~0.6-0.9 s), Neon Grid open and near dry with one faint far
## echo, Night City slapback off the buildings (80-200 ms), Pulse Void dark and longer (~1.2-1.5 s) but low wet.
## audiobuslayout.tres holds Classic's, the starting environment.
const STINGER_ROOMS := {
	"classic": [{&"room_size": 0.45, &"damping": 0.5, &"wet": 0.25},
			{&"tap1_active": false, &"tap2_active": false}],
	"neon_grid": [{&"room_size": 0.2, &"damping": 0.5, &"wet": 0.05},
			{&"tap1_active": true, &"tap1_delay_ms": 380.0, &"tap1_level_db": -20.0, &"tap1_pan": 0.0,
			&"tap2_active": false}],
	"night_city": [{&"room_size": 0.25, &"damping": 0.5, &"wet": 0.08},
			{&"tap1_active": true, &"tap1_delay_ms": 110.0, &"tap1_level_db": -10.0, &"tap1_pan": -0.3,
			&"tap2_active": true, &"tap2_delay_ms": 190.0, &"tap2_level_db": -16.0, &"tap2_pan": 0.3}],
	"pulse_void": [{&"room_size": 0.7, &"damping": 0.8, &"wet": 0.15},
			{&"tap1_active": false, &"tap2_active": false}],
	# Metal Factory: a big hard hall, bright and long-ish, with a slap off the side walls (18 m away, ~105 ms)
	"metal_factory": [{&"room_size": 0.6, &"damping": 0.3, &"wet": 0.2},
			{&"tap1_active": true, &"tap1_delay_ms": 105.0, &"tap1_level_db": -14.0, &"tap1_pan": 0.0,
			&"tap2_active": false}],
}

## The scenery around the track, one of the ids in Settings.ENVIRONMENTS other than "auto".
var environment := "classic"
## Only Classic has the tunnel rings; the others open the view.
var rings_enabled := true
var _sky_materials := {}
## 1 right after a combo milestone, falling to 0
var _combo_pulse := 0.0
var _dust := Dust.new()
## the moving heads the lasers leave from
var _fixtures := LaserFixtures.new()
## A good cut sends a ring of the saber's light out from the player along the scene's lights
## (player_light.gdshaderinc): how far each saber's ring has gone in metres, negative when there is none.
var _cut_waves := Vector2(-1.0, -1.0)
## metres per second, and how far a ring runs before it stops
const CUT_WAVE_SPEED := 30.0
const CUT_WAVE_REACH := 80.0
## a mistake dims the air by this much for a moment
var _mistake_dip := 0.0
const MISTAKE_DIP := 0.5
const MISTAKE_DIP_SECONDS := 0.6
## 0 at x1 to 1 at x8, and where it is heading
var _combo_level := 0.0
var _combo_target := 0.0
## Settings.atmosphere Eerie, in a song: after QUIET_AFTER_SECONDS without a light event the lasers and the air sink
## by up to QUIET_DIM over QUIET_FADE_SECONDS, and the next light event brings them back over QUIET_RISE_SECONDS.
## Untuned.
const QUIET_AFTER_SECONDS := 1.5
const QUIET_FADE_SECONDS := 3.0
const QUIET_RISE_SECONDS := 0.3
const QUIET_DIM := 0.4
var _since_event := 0.0
## 0 lit to 1 fully sunk
var _quiet := 0.0
## The show's intensity, which builds the stage as the song builds (doc/world/AUDIO_VISUAL_MAPPING.md): how many
## light events the map fires in the last INTENSITY_WINDOW_SECONDS, against the song's own range (between its
## INTENSITY_LOW and INTENSITY_HIGH percentiles, so a song whose lights barely vary still builds and one with dense
## light shows doesn't saturate at once; measured on 52 maps, rates run from 1 to 165 events a second and peaks
## 1.3-7.5 times the mean). Worked out once per song as a curve sampled every INTENSITY_STEP beats, then smoothed
## while playing, rising over INTENSITY_RISE_SECONDS and falling over INTENSITY_FALL_SECONDS. A map without light
## events has no curve and stays dark and unbuilt. The player found the timing right on the headset (2026-10-24).
const INTENSITY_WINDOW_SECONDS := 4.0
const INTENSITY_STEP := 0.5
const INTENSITY_LOW := 0.2
const INTENSITY_HIGH := 0.9
const INTENSITY_RISE_SECONDS := 1.0
const INTENSITY_FALL_SECONDS := 3.0
## the song's beat now, set by the Playing state; the curve and the smoothed intensity
var show_beat := 0.0
## the song's tempo, for the Metal Factory's pistons
var _show_bpm := 0.0
var _intensity_curve := PackedFloat32Array()
var _intensity := 0.0
## how far the moving heads have turned to the build-up sweep (0 their own aim), the sweep's phase in sweeps, and the
## heads' own transforms while they sweep
var _sweep := 0.0
var _sweep_phase := 0.0
var _sweep_rest := {}
## the highest the smoothed intensity has been this song: what the crew has built so far (it never comes down)
var _built := 0.0
## whether the square bars were last left lowered with Classic's frames
var _bars_lowered := false

@onready var ring_holder := $Level/rings as Node3D
@onready var diagonal_lasers_holder := $Level/DiagonalLasers as Node3D
@onready var diagonal_lasers := [
	$Level/DiagonalLasers/laser1,
	$Level/DiagonalLasers/laser2,
	$Level/DiagonalLasers/laser3,
	$Level/DiagonalLasers/laser4,
	$Level/DiagonalLasers/laser5,
	$Level/DiagonalLasers/laser6,
	$Level/DiagonalLasers/laser7,
	$Level/DiagonalLasers/laser8,
	$Level/DiagonalLasers/laser9,
	$Level/DiagonalLasers/laser10
]
@onready var square_lasers_holder := $Level/SquareLasers as Node3D
@onready var left_waving_lasers_holder := $Level/LeftWavingLasers as Node3D
@onready var right_waving_lasers_holder := $Level/RightWavingLasers as Node3D
@onready var track_lights_holder := $Level/TrackLights as Node3D

@onready var sphere_material := ($Level/Sphere as MeshInstance3D).material_override as ShaderMaterial
@onready var classic_sky_material := sphere_material
@onready var neon_grid := $Level/NeonGrid as Node3D
@onready var pulse_void := $Level/PulseVoid as PulseVoid
@onready var diagonal_lasers_material := ($Level/DiagonalLasers/laser1/Bar7 as MeshInstance3D).material_override as ShaderMaterial
@onready var square_lasers_material := ($Level/SquareLasers/Bar7 as MeshInstance3D).material_override as ShaderMaterial
@onready var left_waving_lasers_material := ($Level/LeftWavingLasers/laser1/Bar7 as MeshInstance3D).material_override as ShaderMaterial
@onready var right_waving_lasers_material := ($Level/RightWavingLasers/laser1/Bar7 as MeshInstance3D).material_override as ShaderMaterial
@onready var track_lights_material := ($Level/TrackLights/Bar1 as MeshInstance3D).material_override as ShaderMaterial
@onready var floor_mesh := ($Level/floor as MeshInstance3D).mesh as PlaneMesh
@onready var floor_material := ($Level/floor as MeshInstance3D).material_override as StandardMaterial3D
@onready var track_lights_right := $Level/TrackLights/Bar1 as MeshInstance3D
@onready var track_lights_left := $Level/TrackLights/Bar2 as MeshInstance3D
@onready var end_path := $Level/Endpath as MeshInstance3D
@onready var track_deck := $Level/TrackDeck as TrackDeck
@onready var stage_smoke := $Level/StageSmoke as StageSmoke
## the player's platform border (game/floor.tscn): always lit, white-hot with the right note colour at its edges,
## whatever the map's light show does, so the player always sees where they stand
const PLATFORM_LIGHTS := preload("res://game/env/platform_lights.tres")
@onready var classic_rig := $Level/ClassicRig as ClassicRig
@onready var neon_grid_rig := $Level/NeonGridRig as NeonGridRig
@onready var night_city_rig := $Level/NightCityRig as NightCityRig
@onready var metal_factory_rig := $Level/MetalFactoryRig as MetalFactoryRig

@onready var ring_anim_player := $Level/rings/AnimationPlayer as AnimationPlayer
@onready var left_laser_anim_player := $Level/LeftWavingLasers/AnimationPlayer as AnimationPlayer
@onready var right_laser_anim_player := $Level/RightWavingLasers/AnimationPlayer as AnimationPlayer

@export var disabled := false

## The stages' light rigs (LightRig.gd)
var _rig := LightRig.new(self)

func _ready() -> void:
	classic_sky_material.render_priority = SKY_RENDER_PRIORITY
	$Level.add_child(_dust)
	# each laser's own transform (its aim), put back before a rig hangs it (Classic's places it on the tunnel's hanging scaffolds
	# and catwalks, ClassicRig)
	for laser: Node3D in diagonal_lasers + _rig.waving_lasers():
		_rig.classic_places[laser] = laser.global_transform
	var fixture_lasers: Array[Node3D] = []
	var fixture_materials: Array[ShaderMaterial] = []
	for laser: Node3D in diagonal_lasers:
		fixture_lasers.append(laser)
		fixture_materials.append(diagonal_lasers_material)
	for laser in _rig.waving_lasers():
		fixture_lasers.append(laser)
		fixture_materials.append(left_waving_lasers_material if laser.get_parent() == left_waving_lasers_holder
				else right_waving_lasers_material)
	_fixtures.setup(fixture_lasers, fixture_materials)
	$Level.add_child(_fixtures)
	# Night City's layout follows its Classic switch, the lights hung again on the one shown
	Settings.changed.connect(func(key: StringName) -> void:
		if key == &"classic_night_city":
			night_city_rig.build(Settings.classic_night_city)
			if environment == "night_city":
				_rig.apply(environment))
	# each group's bars in one draw call (LaserBatch)
	for holder: Node3D in [diagonal_lasers_holder, square_lasers_holder, left_waving_lasers_holder, right_waving_lasers_holder]:
		LaserBatch.make(holder, $Level)
	_rig.classic_places[square_lasers_holder] = square_lasers_holder.transform
	for strip: MeshInstance3D in [track_lights_left, track_lights_right]:
		_strip_rest[strip] = strip.global_transform
	for bar in _rig.square_bars():
		_rig.classic_places[bar] = bar.global_transform
	track_lights_holder.hide()
	
	set_background_texture()
	
	# get_rendering_device() returns null in opengl, meaning this block is skipped in vulkan
	
	set_background()
	
	if not RenderingServer.get_rendering_device():
		sphere_material.set_shader_parameter("contrast", 1)
		for background_side in 5:
			var shader_param := StringName("bg_%s_intensity_mult" % background_side)
			sphere_material.set_shader_parameter(
				shader_param,
				(sphere_material.get_shader_parameter(shader_param) as float) * 2.2
			)
	# Neon Grid's terrain stays flat under the arches' footings
	(($Level/NeonGrid/GridFloor as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter(
			&"flat_spots", NeonGridRig.ground_spots())
	# set_environment skips the current environment, and it starts as "classic": apply that one in full (its rig's
	# lights placed, the old rings left out) as the stage capture does
	var start := environment
	environment = ""
	set_environment(start)

func set_background_texture() -> void:
	if not Settings.background_texture.begins_with("res:"):
		var img := Image.new()
		if OK == img.load(Constants.APPDATA_PATH + "Backgrounds/" + Settings.background_texture):
			img.flip_x()
			classic_sky_material.set_shader_parameter("bg_base", ImageTexture.create_from_image(img))
			return
		Settings.background_texture = Settings.default_values["background_texture"]
	# a saved picture that no longer ships (the old photographs) falls back to the default sky
	if not ResourceLoader.exists(Settings.background_texture):
		Settings.background_texture = Settings.default_values["background_texture"]
	classic_sky_material.set_shader_parameter("bg_base", load(Settings.background_texture))

## The environment a map plays in: the player's pick, or with "auto" the one map_environment finds.
static func pick_environment(map: MapInfo) -> String:
	if Settings.environment != "auto":
		return Settings.environment
	return map_environment(map)

## Our environment for a map: the one matching the Beat Saber environment it names (Constants.MAP_ENVIRONMENTS),
## else the one for its genre (Constants.TAG_ENVIRONMENTS, tags from SongTags), else one of
## Constants.AUTO_ENVIRONMENTS picked by its folder name, so a song always gets the same one. Classic without a map.
static func map_environment(map: MapInfo) -> String:
	if map == null:
		return "classic"
	var named := map.environment_name.trim_suffix("Environment")
	if Constants.MAP_ENVIRONMENTS.has(named):
		return Constants.MAP_ENVIRONMENTS[named]
	for tag in SongTags.tags_of(map):
		if Constants.TAG_ENVIRONMENTS.has(tag):
			return Constants.TAG_ENVIRONMENTS[tag]
	var folder := SongTags.folder_of(map)
	return Constants.AUTO_ENVIRONMENTS[absi(folder.hash()) % Constants.AUTO_ENVIRONMENTS.size()]

## Swaps the scenery around the track; the lights carry over as they are.
func set_environment(id: String) -> void:
	if id == environment:
		return
	environment = id
	if SKY_SHADERS.has(id) and not _sky_materials.has(id):
		var material := ShaderMaterial.new()
		material.shader = SKY_SHADERS[id]
		material.render_priority = SKY_RENDER_PRIORITY
		for texture: String in SKY_TEXTURES.get(id, {}):
			material.set_shader_parameter(texture, load(SKY_TEXTURES[id][texture]))
		_sky_materials[id] = material
	var sky: ShaderMaterial = _sky_materials.get(id, classic_sky_material)
	for type in 5:
		for param: StringName in [StringName("bg_%d_tint" % type), INTENSITY_PARAMS[type]]:
			var value: Variant = sphere_material.get_shader_parameter(param)
			if value != null:
				sky.set_shader_parameter(param, value)
	sphere_material = sky
	($Level/Sphere as MeshInstance3D).material_override = sky
	# the old Classic's rotating rings are retired (its new tunnel's ribs took their place, 2026-10-27)
	rings_enabled = false
	_apply_stinger_room(id)
	# the rig places the heads afresh: no sweep to turn back from
	_sweep = 0.0
	_sweep_rest.clear()
	_rig.apply(id)
	track_deck.set_stage(id)
	show_scenery_for_mixed_reality()
	set_background()

## Sets the Stinger bus's reverb and delay to the environment's room (STINGER_ROOMS).
func _apply_stinger_room(id: String) -> void:
	var bus := AudioServer.get_bus_index(&"Stinger")
	assert(bus >= 0, "audiobuslayout.tres has no Stinger bus")
	var room: Array = STINGER_ROOMS[id]
	for effect in room.size():
		var target := AudioServer.get_bus_effect(bus, effect)
		for property: StringName in room[effect]:
			target.set(property, room[effect][property])

## Build-up sweep (owner, 2026-10-28, after Beat Saber's beams rushing over the player before a drop, PC version
## recording): in the BUILD_UP_SECONDS before the show reaches its drop (the intensity curve passing STRIP_DROP), the
## moving heads turn from their own aim toward a point SWEEP_TARGET over the player's head and pan side to side,
## SWEEP_HALF_WIDTH either way, faster as the drop nears (SWEEP_PERIOD_START to SWEEP_PERIOD_END seconds a sweep). Each
## head pans on its own phase (SWEEP_PHASE_STEP), on a sine, so it eases at both ends like a machine; the beams keep
## their colour and events (no extra flashes). The heads turn back over SWEEP_EASE_SECONDS once the drop hits or the
## build-up ends. Over the head, not into the note corridor: the heads stand 20 m up (Classic) and the beams come down
## to SWEEP_TARGET's height. Only on SWEEP_STAGES so far: on Night City the heads on the low roofs stand close, and
## their beams crossed the view thick and bright (stage_capture --build-up 0.7, 2026-10-28). Untuned.
const SWEEP_STAGES: Array[String] = ["classic"]
const BUILD_UP_SECONDS := 8.0
const SWEEP_TARGET := Vector3(0.0, 4.0, 1.0)
const SWEEP_HALF_WIDTH := 6.0
const SWEEP_PERIOD_START := 4.0
const SWEEP_PERIOD_END := 1.5
const SWEEP_PHASE_STEP := 0.13
const SWEEP_EASE_SECONDS := 1.5
## The arches' strips climb with the show (owner, 2026-10-26): a strip segment is lit once the show has built up to its
## height on the arch (as Night City's windows, _built), at least STRIP_MIN; on the drop (show intensity over STRIP_DROP)
## all of arch B lights; when the square bars' light is off they keep STRIP_QUIET of their last colour (dim, never
## dark). They carry the square bars' light group (NeonGridRig's strips; the bars are left out there). Untuned.
const STRIP_MIN := 0.25
const STRIP_DROP := 0.85
const STRIP_QUIET := 0.15
const MENU_STRIPS := 0.5
var _strip_last := Color.BLACK
## Classic's rib strips: how far from the far end they are lit, out of the song's drops, and how fast that runs
const RIB_QUIET := 0.2
const RIB_SWEEP_SECONDS := 1.2
const RIB_FADE_SECONDS := 4.0
var _rib_sweep := 0.0
## the edge light strips' transforms along the old track, put back with the Old track setting
var _strip_rest := {}

## the canyon's windows: how many the menu shows lit and how bright, and how bright they stay in a song's quiet parts
const MENU_WINDOWS := 0.35
const WINDOWS_QUIET := 0.4
## Neon Grid's arch strips and Pulse Void's dish seams: how far up (in from the rim) they are lit (how far the show has
## built, all of arch B or the whole dish on the drop) and their light, never dark.
func _update_strips(material: ShaderMaterial) -> void:
	material.set_shader_parameter(&"level", MENU_STRIPS if menu_focus else maxf(STRIP_MIN, _built))
	material.set_shader_parameter(&"drop", 1.0 if not menu_focus and _intensity > STRIP_DROP else 0.0)
	var color: Color = square_lasers_material.get_shader_parameter(&"light_color")
	if color.get_luminance() > 0.01:
		_strip_last = color
	else:
		var last := _strip_last if _strip_last.get_luminance() > 0.01 else left_color
		color = Color(last.r * STRIP_QUIET, last.g * STRIP_QUIET, last.b * STRIP_QUIET)
	material.set_shader_parameter(&"light_color", color)

## Classic's rib strips, the tunnel's test lights: in the square bars' light, never dark (as Neon Grid's strips); a few
## far ribs lit through the song, and on the drop they run from far to near (RIB_SWEEP_SECONDS), back on a lull.
func _update_rib_strips(delta: float) -> void:
	var material := classic_rig.rib_strip_material
	var drop := not menu_focus and _intensity > STRIP_DROP
	var rest := MENU_STRIPS if menu_focus else RIB_QUIET
	_rib_sweep = move_toward(_rib_sweep, 1.0 if drop else rest, delta / (RIB_SWEEP_SECONDS if drop else RIB_FADE_SECONDS))
	material.set_shader_parameter(&"level", _rib_sweep)
	var color: Color = square_lasers_material.get_shader_parameter(&"light_color")
	if color.get_luminance() > 0.01:
		_strip_last = color
	else:
		var last := _strip_last if _strip_last.get_luminance() > 0.01 else left_color
		color = Color(last.r * STRIP_QUIET, last.g * STRIP_QUIET, last.b * STRIP_QUIET)
	material.set_shader_parameter(&"light_color", color)

## Shows the environment's own scenery (Neon Grid's floor, Pulse Void's rings, the smoke) except in mixed reality,
## where opaque scenery would cover the player's room: there only the track, notes and light beams are drawn
## (the sky is hidden by MixedReality.gd).
func show_scenery_for_mixed_reality() -> void:
	neon_grid.visible = environment == "neon_grid" and not Settings.mixed_reality
	pulse_void.visible = environment == "pulse_void" and not Settings.mixed_reality
	classic_rig.visible = environment == "classic" and not Settings.mixed_reality
	neon_grid_rig.visible = environment == "neon_grid" and not Settings.mixed_reality
	night_city_rig.visible = environment == "night_city" and not Settings.mixed_reality
	metal_factory_rig.visible = environment == "metal_factory" and not Settings.mixed_reality
	stage_smoke.visible = Settings.smoke and not Settings.mixed_reality
	_dust.visible = not Settings.mixed_reality
	# Metal Factory has no moving heads: its lights glow in the wall vents
	_fixtures.visible = not Settings.mixed_reality and Settings.background != "simple" and environment != "metal_factory"

func set_background() -> void:
	var track_lights_width := track_lights_right.get_aabb().size.x
	track_lights_right.global_transform.origin.x = track_lights_width / 2 + 2 * Settings.LANE_DISTANCE_X - .01
	track_lights_left.global_transform.origin.x = -track_lights_right.transform.origin.x
	end_path.scale.z = track_lights_right.global_transform.origin.x + track_lights_width / 2 - .01
	floor_mesh.size.y = 4 * Settings.LANE_DISTANCE_X
	($Level/floor/line1).global_transform.origin.x = Settings.LANE_DISTANCE_X
	($Level/floor/line2).global_transform.origin.x = -Settings.LANE_DISTANCE_X
	($Level/floor/line3).global_transform.origin.x = 2 * Settings.LANE_DISTANCE_X
	($Level/floor/line4).global_transform.origin.x = -2 * Settings.LANE_DISTANCE_X
	($Level/floor).scale.z = 1
	# the deck with its curbs (TrackDeck), whose curbs house the edge light strips; or the old see-through sheet, with
	# its strips at its edges, in mixed reality (the room must show through) and with the Old track setting
	var old_track := Settings.old_track or Settings.mixed_reality
	($Level/floor as Node3D).visible = old_track
	# the old track's far end piece; the deck ends in its own low stop (it rose over the horizon straight ahead)
	end_path.visible = old_track
	track_deck.visible = not old_track
	track_deck.layout(Settings.LANE_DISTANCE_X)
	# the deck's strips run its whole length, out to where it fades into the haze, and fade with it; the old track's
	# stop at its end, as they always did
	var span := track_deck.strip_span()
	track_lights_material.set_shader_parameter(&"fade_z", Vector2.ZERO if old_track else track_deck.fade_z())
	track_lights_material.set_shader_parameter(&"min_pixels", 0.0 if old_track else TrackDeck.STRIP_MIN_PIXELS)
	track_lights_material.set_shader_parameter(&"top_white", 0.0 if old_track else TrackDeck.STRIP_TOP_WHITE)
	for strip: MeshInstance3D in [track_lights_left, track_lights_right]:
		var rest: Transform3D = _strip_rest[strip]
		if old_track:
			strip.global_transform = Transform3D(rest.basis, Vector3(strip.global_position.x, rest.origin.y, rest.origin.z))
			continue
		var side := signf(strip.global_position.x)
		var place := TrackDeck.strip_position(Settings.LANE_DISTANCE_X, side, strip.get_aabb().size)
		var stretch := (span.x - span.y) / strip.get_aabb().size.z
		var thin := TrackDeck.STRIP_WIDTH / strip.get_aabb().size.x
		strip.global_transform = Transform3D(Basis.from_scale(Vector3(thin, 1.0, stretch)),
			Vector3(place.x, place.y, (span.x + span.y) * 0.5))
	# Metal Factory has no moving heads: its lights glow in the wall vents
	_fixtures.visible = not Settings.mixed_reality and Settings.background != "simple" and environment != "metal_factory"
	if Settings.background == "simple":
		ring_holder.hide()
		diagonal_lasers_holder.hide()
		square_lasers_holder.hide()
		left_waving_lasers_holder.hide()
		right_waving_lasers_holder.hide()
		($Level/DiagonalLasers/laser1).hide()
		($Level/DiagonalLasers/laser2).hide()
		($Level/DiagonalLasers/laser3).hide()
		($Level/DiagonalLasers/laser4).hide()
		($Level/DiagonalLasers/laser5).hide()
		($Level/DiagonalLasers/laser6).hide()
		($Level/DiagonalLasers/laser7).hide()
		($Level/DiagonalLasers/laser8).hide()
		($Level/DiagonalLasers/laser9).hide()
		($Level/DiagonalLasers/laser10).hide()
		track_lights_holder.hide()
		($Level/StageSmoke).hide()
		_dust.hide()
		set_all_off()
		turn_light_on(EventInfo.TYPE_FLOOR_LIGHTS, Color.WHITE)
		disabled = true
	else:
		ring_holder.visible = rings_enabled
		stage_smoke.visible = Settings.smoke and not Settings.mixed_reality
		_dust.visible = not Settings.mixed_reality
		diagonal_lasers_holder.show()
		square_lasers_holder.show()
		left_waving_lasers_holder.show()
		right_waving_lasers_holder.show()
		($Level/DiagonalLasers/laser1).show()
		($Level/DiagonalLasers/laser2).show()
		($Level/DiagonalLasers/laser3).show()
		($Level/DiagonalLasers/laser4).show()
		($Level/DiagonalLasers/laser5).show()
		($Level/DiagonalLasers/laser6).show()
		($Level/DiagonalLasers/laser7).show()
		($Level/DiagonalLasers/laser8).show()
		($Level/DiagonalLasers/laser9).show()
		($Level/DiagonalLasers/laser10).show()
		track_lights_holder.hide()
		if Settings.background == "dynamic":
			disabled = false
			set_all_on(Settings.color_left, Settings.color_right)
		else:
			disabled = true
			set_all_off()
			turn_light_on(EventInfo.TYPE_FLOOR_LIGHTS, Color.WHITE)

func _process(delta: float) -> void:
	_combo_pulse = maxf(_combo_pulse - delta / COMBO_PULSE_SECONDS, 0.0)
	_mistake_dip = maxf(_mistake_dip - delta / MISTAKE_DIP_SECONDS, 0.0)
	for i in 2:
		if _cut_waves[i] >= 0.0:
			_cut_waves[i] += CUT_WAVE_SPEED * delta
			if _cut_waves[i] > CUT_WAVE_REACH:
				_cut_waves[i] = -1.0
	RenderingServer.global_shader_parameter_set(&"cut_waves", _cut_waves)
	_combo_level = move_toward(_combo_level, _combo_target,
			delta / (COMBO_RISE_SECONDS if _combo_target > _combo_level else COMBO_FALL_SECONDS))
	if menu_focus:
		_breathe(delta)
	_since_event += delta
	var quiet := not menu_focus and Settings.atmosphere == "Eerie" and _since_event > QUIET_AFTER_SECONDS
	_quiet = move_toward(_quiet, 1.0 if quiet else 0.0, delta / (QUIET_FADE_SECONDS if quiet else QUIET_RISE_SECONDS))
	_update_haze()
	if track_deck.visible:
		track_deck.deck_material.set_shader_parameter(&"light_color", floor_material.albedo_color)
	if environment == "metal_factory":
		metal_factory_rig.set_vent_colors(diagonal_lasers_material.get_shader_parameter(&"light_color"),
				left_waving_lasers_material.get_shader_parameter(&"light_color"),
				right_waving_lasers_material.get_shader_parameter(&"light_color"))
	_update_show(delta)
	_update_sweep(delta)
	if environment == "night_city" and not Settings.classic_night_city:
		# the canyon's windows: the rooms the show has built light up (the menu shows a few), dimmer in quiet parts
		var level := MENU_WINDOWS if menu_focus else _built
		var glow := MENU_WINDOWS if menu_focus else lerpf(WINDOWS_QUIET, 1.0, _intensity)
		night_city_rig.set_windows(left_color, right_color, level, glow)
		# the billboards burn in the square bars' light
		if night_city_rig.billboard_material:
			night_city_rig.billboard_material.set_shader_parameter(&"light_color",
				square_lasers_material.get_shader_parameter(&"light_color"))
	if environment == "neon_grid" and neon_grid_rig.strip_material:
		_update_strips(neon_grid_rig.strip_material)
	if environment == "pulse_void" and pulse_void.seam_material:
		_update_strips(pulse_void.seam_material)
		pulse_void.drop_beam.visible = not menu_focus and _intensity > STRIP_DROP
	if environment == "classic" and classic_rig.rib_strip_material:
		_update_rib_strips(delta)
	_follow_frames()
	# update the level animations
	#procces ring rotations
	if ring_rot_speed > 0:
		for ring in ring_holder.get_children():
			if ring is Node3D:
				var rot := ring_rot_speed
				if ring_rot_inv_dir: rot *= -1
				(ring as Node3D).rotate_z((rot * delta) * (float(ring.get_index()+1)/5))
		if environment == "metal_factory":
			metal_factory_rig.spin_rings(delta, -ring_rot_speed if ring_rot_inv_dir else ring_rot_speed)

## Tints the shared haze with the light groups that are on, so a flash lights up the air around the track.
func _update_haze() -> void:
	var haze := HAZE_BASE
	# the lights' own colour, which the scenery takes on (env_light, EnvSolid.gdshader)
	var light := Color.BLACK
	for m: ShaderMaterial in [diagonal_lasers_material, square_lasers_material, left_waving_lasers_material, right_waving_lasers_material]:
		light += m.get_shader_parameter(&"light_color") as Color
	if track_lights_holder.visible:
		light += floor_material.albedo_color
	haze += light * HAZE_LIGHT_WEIGHT
	var pulse := _combo_pulse * _combo_pulse
	var level := (1.0 + COMBO_HAZE_BOOST * _combo_level + COMBO_PULSE * pulse) * (1.0 - MISTAKE_DIP * _mistake_dip) \
			* (1.0 - QUIET_DIM * _quiet)
	haze *= level
	light *= level
	var eerie := Settings.atmosphere == "Eerie"
	if eerie:
		haze *= EERIE_HAZE_DIM
		light *= EERIE_HAZE_DIM
	var grey := haze.r * 0.299 + haze.g * 0.587 + haze.b * 0.114
	haze = haze.lerp(Color(grey, grey, grey), EERIE_HAZE_NEUTRAL if eerie else HAZE_NEUTRAL)
	if eerie:
		haze *= Constants.EERIE_HAZE_TINT
	haze.a = 1.0
	RenderingServer.global_shader_parameter_set(&"env_haze", haze)
	light = light.clamp()
	light.a = 1.0
	RenderingServer.global_shader_parameter_set(&"env_light", light)
	RenderingServer.global_shader_parameter_set(&"combo_glow", COMBO_LASER_BOOST * _combo_level + COMBO_PULSE_LASER * pulse
			- QUIET_DIM * _quiet)

## Sets how lit up the scene is for the combo multiplier (1, 2, 4 or 8).
func set_combo_multiplier(multiplier: int) -> void:
	_combo_target = log(maxf(multiplier, 1)) / log(8.0)

## Starts a ring of light from the player for a good cut with the saber of this type (0 left, 1 right).
func cut_wave(saber_type: int) -> void:
	_cut_waves[saber_type] = 0.0

## Dims the air for a moment, for a miss, a bad cut or a bomb.
func mistake_dip() -> void:
	_mistake_dip = 1.0

## Brightens the air for a moment, for a combo milestone.
func combo_pulse() -> void:
	_combo_pulse = 1.0

## A song starts: work out its intensity curve and take the stage down, to be built again as the song builds.
func start_show(events: Array[EventInfo], bpm: float) -> void:
	_intensity_curve = intensity_curve(events, bpm)
	_show_bpm = bpm
	_intensity = 0.0
	_built = 0.0
	show_beat = 0.0
	classic_rig.set_built(0.0)

func _update_show(delta: float) -> void:
	if menu_focus or _intensity_curve.is_empty():
		return
	var target := _intensity_curve[clampi(int(show_beat / INTENSITY_STEP), 0, _intensity_curve.size() - 1)]
	var seconds := INTENSITY_RISE_SECONDS if target > _intensity else INTENSITY_FALL_SECONDS
	_intensity = move_toward(_intensity, target, delta / seconds)
	if _intensity > _built:
		_built = _intensity
		classic_rig.set_built(_built)
	if environment == "metal_factory":
		metal_factory_rig.slam(show_beat, _show_bpm, _intensity)
		metal_factory_rig.turn_gears(delta, _intensity)
		metal_factory_rig.breathe(show_beat, _show_bpm, _intensity)

## How close the drop after `beat` in `curve` (intensity_curve at `bpm`) is: 0 when none comes within BUILD_UP_SECONDS,
## rising to 1 as it arrives.
static func build_up(curve: PackedFloat32Array, beat: float, bpm: float) -> float:
	if curve.is_empty() or bpm <= 0.0:
		return 0.0
	var steps := maxi(1, roundi(BUILD_UP_SECONDS * bpm / 60.0 / INTENSITY_STEP))
	var now := int(beat / INTENSITY_STEP)
	for k in range(1, steps + 1):
		if now + k >= curve.size():
			break
		if curve[now + k] > STRIP_DROP:
			return 1.0 - float(k) / steps
	return 0.0

## Turns the moving heads toward the build-up sweep and back (see BUILD_UP_SECONDS), on SWEEP_STAGES.
func _update_sweep(delta: float) -> void:
	var sweeping := environment in SWEEP_STAGES and not menu_focus and _intensity <= STRIP_DROP
	var target := build_up(_intensity_curve, show_beat, _show_bpm) if sweeping else 0.0
	if environment in SWEEP_STAGES and DebugView.flags & DebugView.FORCE_SWEEP != 0:
		target = 1.0
	_sweep = move_toward(_sweep, target, delta / SWEEP_EASE_SECONDS)
	if _sweep == 0.0:
		for laser: Node3D in _sweep_rest:
			laser.global_transform = _sweep_rest[laser]
		_sweep_rest.clear()
		return
	if _sweep_rest.is_empty():
		for laser: Node3D in diagonal_lasers:
			_sweep_rest[laser] = laser.global_transform
	_sweep_phase = fmod(_sweep_phase + delta / lerpf(SWEEP_PERIOD_START, SWEEP_PERIOD_END, _sweep), 1.0)
	var turn := smoothstep(0.0, 1.0, _sweep)
	for i in diagonal_lasers.size():
		var laser: Node3D = diagonal_lasers[i]
		var rest: Transform3D = _sweep_rest[laser]
		var pan := sin(TAU * (_sweep_phase + i * SWEEP_PHASE_STEP)) * SWEEP_HALF_WIDTH
		var toward := (SWEEP_TARGET + Vector3(pan, 0.0, 0.0) - rest.origin).normalized()
		LightRig.aim(laser, rest.origin, (-rest.basis.z.normalized()).slerp(toward, turn))

## In Classic the square light bars hang on the tunnel's frames: a frame that isn't standing yet has no lights on it
## (the crew hangs them once it is up), so its bars are hidden until it stands. Lowered bars used to shine up through
## the note track (the player saw it on the headset, 2026-10-24).
func _follow_frames() -> void:
	if environment != "classic" or (classic_rig.standing() and not _bars_lowered):
		return
	for bar in _rig.square_bars():
		if bar.get_parent() == square_lasers_holder:
			bar.visible = classic_rig.drop_at(bar.global_position.z) == 0.0
	# the moving heads stand on the scaffolds too
	for laser: Node3D in diagonal_lasers:
		laser.visible = classic_rig.drop_at(laser.global_position.z) == 0.0
	_bars_lowered = not classic_rig.standing()

## The intensity, 0 to 1, every INTENSITY_STEP beats from the song's start to its last light event (see
## INTENSITY_WINDOW_SECONDS). Empty when the map has no light events.
static func intensity_curve(events: Array[EventInfo], bpm: float) -> PackedFloat32Array:
	var last := -1.0
	for e in events:
		if e.type >= EventInfo.TYPE_DIAGONAL_LASERS and e.type <= EventInfo.TYPE_FLOOR_LIGHTS:
			last = maxf(last, e.beat)
	if last < 0.0 or bpm <= 0.0:
		return PackedFloat32Array()
	var count := int(last / INTENSITY_STEP) + 1
	var per_step := PackedFloat32Array()
	per_step.resize(count)
	for e in events:
		if e.type >= EventInfo.TYPE_DIAGONAL_LASERS and e.type <= EventInfo.TYPE_FLOOR_LIGHTS and e.beat >= 0.0:
			per_step[int(e.beat / INTENSITY_STEP)] += 1.0
	# events in the window ending at each step
	var window := maxi(1, roundi(INTENSITY_WINDOW_SECONDS * bpm / 60.0 / INTENSITY_STEP))
	var rates := PackedFloat32Array()
	rates.resize(count)
	var sum := 0.0
	for i in count:
		sum += per_step[i]
		if i >= window:
			sum -= per_step[i - window]
		rates[i] = sum
	var sorted := rates.duplicate()
	sorted.sort()
	var low := sorted[int(INTENSITY_LOW * (count - 1))]
	var high := maxf(sorted[int(INTENSITY_HIGH * (count - 1))], low + 1.0)
	var curve := PackedFloat32Array()
	curve.resize(count)
	for i in count:
		curve[i] = clampf((rates[i] - low) / (high - low), 0.0, 1.0)
	return curve

## Dims the scene for the menus, fading over a second, and fills the stage with smoke; off, it clears the smoke and
## leaves the lights to the song, which sets them next.
func set_menu_focus(on: bool) -> void:
	if on == menu_focus and on:
		_apply_menu_lights()
		return
	menu_focus = on
	if not on:
		stage_smoke.dissipate()
		# the show starts: every light goes dark, the song turns its own lights on (BeepSaber_Game.start_map)
		if not disabled:
			for type in 5:
				turn_light_off(type)
		left_laser_anim_player.speed_scale = 1.0
		right_laser_anim_player.speed_scale = 1.0
		return
	_menu_time = 0.0
	# between songs the rig stands complete and the pistons rest raised
	classic_rig.set_built(1.0)
	metal_factory_rig.slam(0.0, 0.0, 0.0)
	stage_smoke.refill()
	_combo_target = 0.0
	ring_rot_speed = 0.0
	for player: AnimationPlayer in [left_laser_anim_player, right_laser_anim_player]:
		player.speed_scale = player.current_animation_length / MENU_LASER_SWEEP_SECONDS
		player.seek(randf_range(0.0, player.current_animation_length), true)
	_apply_menu_lights()

## A note colour pulled toward the house colour and dimmed to a part of itself, for the menus.
static func _menu_color(color: Color, level: float) -> Color:
	return color.lerp(HOUSE_COLOR, MENU_HOUSE_MIX).darkened(1.0 - level)

## Pre-show lighting faded in over MENU_FADE_SECONDS: static lights at MENU_BREATH_LOW, waving lasers at
## MENU_LASER_LEVEL.
func _apply_menu_lights() -> void:
	if disabled:
		return
	fade_light_from_current(EventInfo.TYPE_DIAGONAL_LASERS, _menu_color(left_color, MENU_BREATH_LOW))
	fade_light_from_current(EventInfo.TYPE_SQUARE_LASERS, _menu_color(right_color, MENU_BREATH_LOW))
	fade_light_from_current(EventInfo.TYPE_FLOOR_LIGHTS, _menu_color(right_color, MENU_BREATH_LOW))
	fade_light_from_current(EventInfo.TYPE_LEFT_WAVING_LASERS, _menu_color(left_color, MENU_LASER_LEVEL))
	fade_light_from_current(EventInfo.TYPE_RIGHT_WAVING_LASERS, _menu_color(right_color, MENU_LASER_LEVEL))

## Slowly brightens and dims the static lights between MENU_BREATH_LOW and MENU_BREATH_HIGH.
func _breathe(delta: float) -> void:
	_menu_time += delta
	if disabled or _menu_time < MENU_FADE_SECONDS:
		return
	var eerie := Settings.atmosphere == "Eerie"
	var level := lerpf(EERIE_BREATH_LOW if eerie else MENU_BREATH_LOW, EERIE_BREATH_HIGH if eerie else MENU_BREATH_HIGH,
		0.5 - 0.5 * cos(TAU * (_menu_time - MENU_FADE_SECONDS) / (EERIE_BREATH_SECONDS if eerie else MENU_BREATH_SECONDS)))
	turn_light_on(EventInfo.TYPE_DIAGONAL_LASERS, _menu_color(left_color, level))
	turn_light_on(EventInfo.TYPE_SQUARE_LASERS, _menu_color(right_color, level))
	turn_light_on(EventInfo.TYPE_FLOOR_LIGHTS, _menu_color(right_color, level))

func update_left_color(color: Color) -> void:
	left_color = color
	metal_factory_rig.set_spark_colors(left_color, right_color)
	if menu_focus:
		_apply_menu_lights()
		return
	turn_light_on(EventInfo.TYPE_DIAGONAL_LASERS, color)
	turn_light_on(EventInfo.TYPE_LEFT_WAVING_LASERS, color)
	turn_light_on(EventInfo.TYPE_RIGHT_WAVING_LASERS, color)

func update_right_color(color: Color) -> void:
	right_color = color
	metal_factory_rig.set_spark_colors(left_color, right_color)
	PLATFORM_LIGHTS.set_shader_parameter(&"light_color", color)
	if menu_focus:
		_apply_menu_lights()
		return
	turn_light_on(EventInfo.TYPE_SQUARE_LASERS, color)
	turn_light_on(EventInfo.TYPE_FLOOR_LIGHTS, color)

func set_all_off() -> void:
	if disabled:
		for i in range(1,4):
			turn_light_off(i)
		ring_holder.visible = false
	else:
		for i in range(5):
			turn_light_off(i)

func set_all_on(left: Color, right: Color) -> void:
	if !disabled:
		update_left_color(left)
		update_right_color(right)
		ring_holder.visible = rings_enabled

func process_event(data: EventInfo) -> void:
	if disabled: return
	if data.type in range(0,5):
		_since_event = 0.0
		match data.value:
			EventInfo.VALUE_LIGHTS_OFF:
				turn_light_off(data.type)
			EventInfo.VALUE_LIGHTS_RIGHT_ON:
				turn_light_on(data.type, right_color)
			EventInfo.VALUE_LIGHTS_RIGHT_FLASH:
				flash_light_on(data.type, right_color)
			EventInfo.VALUE_LIGHTS_RIGHT_FADE:
				flash_light_then_fade_off(data.type, right_color)
			EventInfo.VALUE_LIGHTS_FADE_TO_RIGHT:
				fade_light_from_current(data.type, right_color)
			EventInfo.VALUE_LIGHTS_LEFT_ON:
				turn_light_on(data.type, left_color)
			EventInfo.VALUE_LIGHTS_LEFT_FLASH:
				flash_light_on(data.type, left_color)
			EventInfo.VALUE_LIGHTS_LEFT_FADE:
				flash_light_then_fade_off(data.type, left_color)
			EventInfo.VALUE_LIGHTS_FADE_TO_LEFT:
				fade_light_from_current(data.type, left_color)
			EventInfo.VALUE_LIGHTS_WHITE_ON:
				turn_light_on(data.type, Color.WHITE)
			EventInfo.VALUE_LIGHTS_WHITE_FLASH:
				flash_light_on(data.type, Color.WHITE)
			EventInfo.VALUE_LIGHTS_WHITE_FADE:
				flash_light_then_fade_off(data.type, Color.WHITE)
			EventInfo.VALUE_LIGHTS_FADE_TO_WHITE:
				fade_light_from_current(data.type, Color.WHITE)
	else:
		match data.type:
			8:
				var ringtween := ring_holder.create_tween()
				if absf(ring_rot_speed) < 1.0:
					ring_rot_inv_dir = not ring_rot_inv_dir
				@warning_ignore("return_value_discarded")
				ringtween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(self, ^"ring_rot_speed", 0.0, 2.0).from(3.0)
				ringtween.play()
			9:
				ring_anim_player.stop(false)
				ring_anim_player.play(&"out" if rings_in else &"in")
				rings_in = not rings_in
			12:
				var val := float(data.value) * 0.125
				left_laser_anim_player.speed_scale = val
				left_laser_anim_player.seek(randf_range(0.0, left_laser_anim_player.current_animation_length), true)
			13:
				var val := float(data.value) * 0.125
				right_laser_anim_player.speed_scale = val
				right_laser_anim_player.seek(randf_range(0.0, right_laser_anim_player.current_animation_length), true)

var prev_tweeners: Array[Tween] = [null,null,null,null,null]

func stop_prev_tween(type: int) -> void:
	if prev_tweeners[type] != null:
		prev_tweeners[type].kill()
		prev_tweeners[type] = null

func turn_light_off(type: int) -> void:
	stop_prev_tween(type)
	_on_Tween_tween_step(Color.BLACK, type)
	match type:
		EventInfo.TYPE_DIAGONAL_LASERS:
			diagonal_lasers_holder.visible = false
			diagonal_lasers_material.set_shader_parameter(&"light_color", Color.BLACK)
		EventInfo.TYPE_SQUARE_LASERS:
			square_lasers_holder.visible = false
			square_lasers_material.set_shader_parameter(&"light_color", Color.BLACK)
		EventInfo.TYPE_LEFT_WAVING_LASERS:
			left_waving_lasers_holder.visible = false
			left_waving_lasers_material.set_shader_parameter(&"light_color", Color.BLACK)
		EventInfo.TYPE_RIGHT_WAVING_LASERS:
			right_waving_lasers_holder.visible = false
			right_waving_lasers_material.set_shader_parameter(&"light_color", Color.BLACK)
		EventInfo.TYPE_FLOOR_LIGHTS:
			track_lights_holder.visible = false
			track_lights_material.set_shader_parameter(&"light_color", Color.BLACK)
			floor_material.albedo_color = Color.BLACK
	
func turn_light_on(type: int, color: Color) -> void:
	_set_light_param(StringName("bg_%d_tint" % type), color)
	stop_prev_tween(type)
	_on_Tween_tween_step(color, type)
	match type:
		EventInfo.TYPE_DIAGONAL_LASERS:
			diagonal_lasers_holder.visible = true
			diagonal_lasers_material.set_shader_parameter(&"light_color", color)
		EventInfo.TYPE_SQUARE_LASERS:
			square_lasers_holder.visible = true
			square_lasers_material.set_shader_parameter(&"light_color", color)
		EventInfo.TYPE_LEFT_WAVING_LASERS:
			left_waving_lasers_holder.visible = true
			left_waving_lasers_material.set_shader_parameter(&"light_color", color)
		EventInfo.TYPE_RIGHT_WAVING_LASERS:
			right_waving_lasers_holder.visible = true
			right_waving_lasers_material.set_shader_parameter(&"light_color", color)
		EventInfo.TYPE_FLOOR_LIGHTS:
			track_lights_holder.visible = true
			track_lights_material.set_shader_parameter(&"light_color", color)
			floor_material.albedo_color = color

## At most this many flashes a second per light group (WCAG 2.3.1, three flashes, for photosensitive players);
## a map's further flashes in that second fade to their colour instead of jumping to it. Always on.
const MAX_FLASHES_PER_SECOND := 3
## When each light group's recent flashes started (msec).
var _flash_times: Array[PackedInt64Array] = [PackedInt64Array(), PackedInt64Array(), PackedInt64Array(),
		PackedInt64Array(), PackedInt64Array()]

## True (and counted) if the light group may flash now (MAX_FLASHES_PER_SECOND).
func _flash_allowed(type: int) -> bool:
	var now := Time.get_ticks_msec()
	var recent := PackedInt64Array()
	for t in _flash_times[type]:
		if now - t < 1000:
			recent.append(t)
	var allowed := recent.size() < MAX_FLASHES_PER_SECOND
	if allowed:
		recent.append(now)
	_flash_times[type] = recent
	return allowed

func flash_light_on(type: int, color: Color) -> void:
	if not _flash_allowed(type):
		fade_light_from_current(type, color)
		return
	_set_light_param(StringName("bg_%d_tint" % type), color)
	fade_light(type, color * FLASH_BOOST, color, false, Tween.TRANS_LINEAR, Tween.EASE_OUT)

func flash_light_then_fade_off(type: int, color: Color) -> void:
	_set_light_param(StringName("bg_%d_tint" % type), color)
	if not _flash_allowed(type):
		fade_light(type, _current_color(type), Color.BLACK, true, Tween.TRANS_QUAD, Tween.EASE_IN)
		return
	fade_light(type, color * FLASH_BOOST, Color.BLACK, true, Tween.TRANS_QUAD, Tween.EASE_IN)

func fade_light_from_current(type: int, to_color: Color) -> void:
	fade_light(type, _current_color(type), to_color, false, Tween.TRANS_LINEAR, Tween.EASE_IN)

## A light group's colour now.
func _current_color(type: int) -> Color:
	match type:
		EventInfo.TYPE_DIAGONAL_LASERS:
			return diagonal_lasers_material.get_shader_parameter(&"light_color")
		EventInfo.TYPE_SQUARE_LASERS:
			return square_lasers_material.get_shader_parameter(&"light_color")
		EventInfo.TYPE_LEFT_WAVING_LASERS:
			return left_waving_lasers_material.get_shader_parameter(&"light_color")
		EventInfo.TYPE_RIGHT_WAVING_LASERS:
			return right_waving_lasers_material.get_shader_parameter(&"light_color")
		_:
			return floor_material.albedo_color

func fade_light(type: int, from: Color, to: Color, turn_off_after_fade: bool, trans_type: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	stop_prev_tween(type)
	
	var group: Node3D
	var material: Array[Material] = []
	match type:
		EventInfo.TYPE_DIAGONAL_LASERS:
			group = diagonal_lasers_holder
			material = [diagonal_lasers_material]
		EventInfo.TYPE_SQUARE_LASERS:
			group = square_lasers_holder
			material = [square_lasers_material]
		EventInfo.TYPE_LEFT_WAVING_LASERS:
			group = left_waving_lasers_holder
			material = [left_waving_lasers_material]
		EventInfo.TYPE_RIGHT_WAVING_LASERS:
			group = right_waving_lasers_holder
			material = [right_waving_lasers_material]
		EventInfo.TYPE_FLOOR_LIGHTS:
			group = track_lights_holder
			material = [track_lights_material, floor_material]
	
	group.visible = true
	
	var tween := group.create_tween()
	@warning_ignore("return_value_discarded")
	tween.set_parallel().set_trans(trans_type).set_ease(ease_type)
	for m in material:
		@warning_ignore("return_value_discarded")
		tween.tween_property(m, ^"shader_parameter/light_color" if m is ShaderMaterial else ^"albedo_color", to, 1).from(from)
	@warning_ignore("return_value_discarded")
	tween.tween_method(_on_Tween_tween_step.bind(type), from, to, 1)
	tween.play()
	prev_tweeners[type] = tween
	await tween.finished
	if turn_off_after_fade:
		group.visible = false
		tween.kill()
		_on_Tween_tween_step(Color.BLACK, type)

func _on_Tween_tween_step(value: Color, id: int) -> void:
	_set_light_param(INTENSITY_PARAMS[id], value.v)

## Sets one of the sky's light parameters.
func _set_light_param(param: StringName, value: Variant) -> void:
	sphere_material.set_shader_parameter(param, value)
