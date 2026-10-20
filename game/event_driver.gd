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
## "breathe" between MENU_BREATH_LOW and MENU_BREATH_HIGH of their colour, thicker haze so beams show, and the
## waving lasers sweeping slowly through it at MENU_LASER_LEVEL from their fixtures at the sides. Slow and dim on
## purpose so the menu still holds the eye: no bright or busy motion in the periphery, and nothing oscillating
## near 0.2 Hz (Apple visionOS HIG, Spatial layout, Motion). All values untuned.
const MENU_BREATH_LOW := 0.3
const MENU_BREATH_HIGH := 0.4
const MENU_BREATH_SECONDS := 12.0
const MENU_LASER_LEVEL := 0.2
const MENU_LASER_SWEEP_SECONDS := 30.0
const MENU_HAZE_BOOST := 1.5
## The house light colour the menu lights lean toward, and how far (0 = note colours only): a near-neutral
## cool grey, like Beat Saber's menu, so the stage doesn't look tinted (saturation about 0.09). Untuned.
const HOUSE_COLOR := Color(0.62, 0.64, 0.68)
const MENU_HOUSE_MIX := 0.85
## Seconds the menu lights take to fade in before they start breathing.
const MENU_FADE_SECONDS := 1.0
## When a song starts every light goes dark for this long before the show's lights come on, like a concert.
const SHOW_BLACKOUT_SECONDS := 0.5
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
}

var ring_rot_speed := 0.0
var ring_rot_inv_dir := false
var rings_in := false

var left_color: Color
var right_color: Color

## The scenery around the track, one of the ids in Settings.ENVIRONMENTS other than "auto".
var environment := "classic"
## Only Classic has the tunnel rings; the others open the view.
var rings_enabled := true
var _sky_materials := {}
## 1 right after a combo milestone, falling to 0
var _combo_pulse := 0.0
## 0 at x1 to 1 at x8, and where it is heading
var _combo_level := 0.0
var _combo_target := 0.0

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
@onready var pulse_void := $Level/PulseVoid as Node3D
## materials that follow the sky's light parameters besides the sky itself
@onready var _light_followers: Array[ShaderMaterial] = [pulse_void.ring_material]
@onready var diagonal_lasers_material := ($Level/DiagonalLasers/laser1/Bar7 as MeshInstance3D).material_override as ShaderMaterial
@onready var square_lasers_material := ($Level/SquareLasers/Bar7 as MeshInstance3D).material_override as ShaderMaterial
@onready var left_waving_lasers_material := ($Level/LeftWavingLasers/laser1/Bar7 as MeshInstance3D).material_override as ShaderMaterial
@onready var right_waving_lasers_material := ($Level/RightWavingLasers/laser1/Bar7 as MeshInstance3D).material_override as ShaderMaterial
@onready var track_lights_material := ($Level/TrackLights/Bar1 as MeshInstance3D).material_override as StandardMaterial3D
@onready var floor_mesh := ($Level/floor as MeshInstance3D).mesh as PlaneMesh
@onready var floor_material := ($Level/floor as MeshInstance3D).material_override as StandardMaterial3D
@onready var track_lights_right := $Level/TrackLights/Bar1 as MeshInstance3D
@onready var track_lights_left := $Level/TrackLights/Bar2 as MeshInstance3D
@onready var end_path := $Level/Endpath as MeshInstance3D
@onready var stage_smoke := $Level/StageSmoke as StageSmoke
@onready var classic_rig := $Level/ClassicRig as ClassicRig

@onready var ring_anim_player := $Level/rings/AnimationPlayer as AnimationPlayer
@onready var left_laser_anim_player := $Level/LeftWavingLasers/AnimationPlayer as AnimationPlayer
@onready var right_laser_anim_player := $Level/RightWavingLasers/AnimationPlayer as AnimationPlayer

@export var disabled := false

func _ready() -> void:
	classic_sky_material.render_priority = SKY_RENDER_PRIORITY
	for laser: Node3D in diagonal_lasers + _waving_lasers():
		_classic_rig[laser] = laser.global_transform
	_classic_rig[square_lasers_holder] = square_lasers_holder.transform
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
	rings_enabled = id == "classic"
	_apply_rig(id)
	show_scenery_for_mixed_reality()
	set_background()

## Each environment hangs the same five light groups (so a map's light show still drives them) on its own rig, so
## the stages don't all look alike: Classic keeps Beat Saber's layout; Neon Grid fans its diagonal lasers out from
## one point on the horizon, lines its waving lasers along the grid's edges and hangs the square bars far above
## the horizon; Night City sweeps its waving lasers like searchlights from far beside the track and crosses its
## diagonal beams from rooftop height; Pulse Void aims its diagonal lasers into a point behind the track like a
## tunnel. Every beam starts at its fixture and turns around it (game/AGENTS.md). Positions in metres, untuned.
const RIG_FAN_ORIGIN := Vector3(0.0, -1.0, -70.0)
const RIG_FAN_SPREAD_DEG := 70.0
const RIG_GRID_EDGE_X := 14.0
const RIG_CITY_SEARCH_X := 26.0
const RIG_CITY_ROOF := Vector3(20.0, 8.0, -35.0)
const RIG_VOID_RADIUS := 16.0
const RIG_VOID_CENTER := Vector3(0.0, 1.5, -45.0)
const RIG_VOID_TARGET := Vector3(0.0, 1.5, -75.0)
const RIG_WAVING_Y := -1.26
## where the square bars hang per environment: [position, scale]
const RIG_SQUARE := {
	"neon_grid": [Vector3(0.0, -4.0, -60.0), 1.6],
	"night_city": [Vector3(0.0, -2.0, -45.0), 2.0],
	"pulse_void": [Vector3(0.0, 0.0, -55.0), 1.3],
}
## each laser's and the square bars' Classic transform, put back before another rig is hung
var _classic_rig := {}

## The waving lasers' fixtures, left side first.
func _waving_lasers() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for holder: Node3D in [left_waving_lasers_holder, right_waving_lasers_holder]:
		for child in holder.get_children():
			if child is Node3D and not child is AnimationPlayer:
				out.append(child as Node3D)
	return out

## Aims a laser fixture from a point along a direction, keeping its beam length (local z scale).
static func _aim(laser: Node3D, from: Vector3, direction: Vector3) -> void:
	var length := laser.global_transform.basis.z.length()
	var aim := Basis.looking_at(direction.normalized(), Vector3.UP if absf(direction.normalized().y) < 0.99 else Vector3.FORWARD)
	laser.global_transform = Transform3D(Basis(aim.x, aim.y, aim.z * length), from)

## Hangs the lights on the environment's rig (see RIG_FAN_ORIGIN).
func _apply_rig(id: String) -> void:
	for node: Node3D in _classic_rig:
		if node == square_lasers_holder:
			node.transform = _classic_rig[node]
		else:
			node.global_transform = _classic_rig[node]
	var square: Array = RIG_SQUARE.get(id, [])
	if not square.is_empty():
		square_lasers_holder.position = square[0]
		square_lasers_holder.scale = Vector3.ONE * float(square[1])
	var waving := _waving_lasers()
	@warning_ignore("integer_division")
	var half := waving.size() / 2
	match id:
		"neon_grid":
			for i in diagonal_lasers.size():
				var a := deg_to_rad(lerpf(-RIG_FAN_SPREAD_DEG, RIG_FAN_SPREAD_DEG, float(i) / (diagonal_lasers.size() - 1)))
				_aim(diagonal_lasers[i], RIG_FAN_ORIGIN, Vector3(sin(a), cos(a), -0.15))
			for i in waving.size():
				var side := -1.0 if i < half else 1.0
				waving[i].global_position = Vector3(side * RIG_GRID_EDGE_X, RIG_WAVING_Y, -20.0 - 8.0 * (i % half))
		"night_city":
			for i in diagonal_lasers.size():
				var pairs := diagonal_lasers.size() >> 1
				var side := -1.0 if i < pairs else 1.0
				var k := i % pairs
				_aim(diagonal_lasers[i], Vector3(side * RIG_CITY_ROOF.x, RIG_CITY_ROOF.y, RIG_CITY_ROOF.z - 5.0 * k),
					Vector3(-side * 0.35, 1.0, 0.1))
			for i in waving.size():
				var side := -1.0 if i < half else 1.0
				waving[i].global_position = Vector3(side * RIG_CITY_SEARCH_X, RIG_WAVING_Y, -25.0 - 10.0 * (i % half))
		"pulse_void":
			for i in diagonal_lasers.size():
				var a := TAU * float(i) / diagonal_lasers.size()
				var from := RIG_VOID_CENTER + Vector3(cos(a), sin(a), 0.0) * RIG_VOID_RADIUS
				_aim(diagonal_lasers[i], from, RIG_VOID_TARGET - from)

## Shows the environment's own scenery (Neon Grid's floor, Pulse Void's rings, the smoke) except in mixed reality,
## where opaque scenery would cover the player's room: there only the track, notes and light beams are drawn
## (the sky is hidden by MixedReality.gd).
func show_scenery_for_mixed_reality() -> void:
	neon_grid.visible = environment == "neon_grid" and not Settings.mixed_reality
	pulse_void.visible = environment == "pulse_void" and not Settings.mixed_reality
	classic_rig.visible = environment == "classic" and not Settings.mixed_reality
	stage_smoke.visible = Settings.smoke and not Settings.mixed_reality

func set_background() -> void:
	var width_scale := 2 * Settings.LANE_DISTANCE_X / 3.
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
	for laser in diagonal_lasers:
		laser.transform.origin.x = 4.5 * width_scale * sign(laser.transform.origin.x)
	
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
		set_all_off()
		turn_light_on(EventInfo.TYPE_FLOOR_LIGHTS, Color.WHITE)
		disabled = true
	else:
		ring_holder.visible = rings_enabled
		stage_smoke.visible = Settings.smoke and not Settings.mixed_reality
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
	_combo_level = move_toward(_combo_level, _combo_target,
			delta / (COMBO_RISE_SECONDS if _combo_target > _combo_level else COMBO_FALL_SECONDS))
	if menu_focus:
		_breathe(delta)
	_update_haze()
	# update the level animations
	#procces ring rotations
	if ring_rot_speed > 0:
		for ring in ring_holder.get_children():
			if ring is Node3D:
				var rot := ring_rot_speed
				if ring_rot_inv_dir: rot *= -1
				(ring as Node3D).rotate_z((rot * delta) * (float(ring.get_index()+1)/5))

## Tints the shared haze with the light groups that are on, so a flash lights up the air around the track.
func _update_haze() -> void:
	var haze := HAZE_BASE
	for m: ShaderMaterial in [diagonal_lasers_material, square_lasers_material, left_waving_lasers_material, right_waving_lasers_material]:
		haze += (m.get_shader_parameter(&"light_color") as Color) * HAZE_LIGHT_WEIGHT
	if track_lights_holder.visible:
		haze += floor_material.albedo_color * HAZE_LIGHT_WEIGHT
	var pulse := _combo_pulse * _combo_pulse
	haze *= 1.0 + COMBO_HAZE_BOOST * _combo_level + COMBO_PULSE * pulse
	if menu_focus:
		haze *= MENU_HAZE_BOOST
	var grey := haze.r * 0.299 + haze.g * 0.587 + haze.b * 0.114
	haze = haze.lerp(Color(grey, grey, grey), HAZE_NEUTRAL)
	haze.a = 1.0
	RenderingServer.global_shader_parameter_set(&"env_haze", haze)
	RenderingServer.global_shader_parameter_set(&"combo_glow", COMBO_LASER_BOOST * _combo_level + COMBO_PULSE_LASER * pulse)

## Sets how lit up the scene is for the combo multiplier (1, 2, 4 or 8).
func set_combo_multiplier(multiplier: int) -> void:
	_combo_target = log(maxf(multiplier, 1)) / log(8.0)

## Brightens the air for a moment, for a combo milestone.
func combo_pulse() -> void:
	_combo_pulse = 1.0

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
	var level := lerpf(MENU_BREATH_LOW, MENU_BREATH_HIGH,
		0.5 - 0.5 * cos(TAU * (_menu_time - MENU_FADE_SECONDS) / MENU_BREATH_SECONDS))
	turn_light_on(EventInfo.TYPE_DIAGONAL_LASERS, _menu_color(left_color, level))
	turn_light_on(EventInfo.TYPE_SQUARE_LASERS, _menu_color(right_color, level))
	turn_light_on(EventInfo.TYPE_FLOOR_LIGHTS, _menu_color(right_color, level))

func update_left_color(color: Color) -> void:
	left_color = color
	if menu_focus:
		_apply_menu_lights()
		return
	turn_light_on(EventInfo.TYPE_DIAGONAL_LASERS, color)
	turn_light_on(EventInfo.TYPE_LEFT_WAVING_LASERS, color)
	turn_light_on(EventInfo.TYPE_RIGHT_WAVING_LASERS, color)

func update_right_color(color: Color) -> void:
	right_color = color
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
			track_lights_material.albedo_color = Color.BLACK
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
			track_lights_material.albedo_color = color
			floor_material.albedo_color = color

func flash_light_on(type: int, color: Color) -> void:
	_set_light_param(StringName("bg_%d_tint" % type), color)
	fade_light(type, color * FLASH_BOOST, color, false, Tween.TRANS_LINEAR, Tween.EASE_OUT)

func flash_light_then_fade_off(type: int, color: Color) -> void:
	_set_light_param(StringName("bg_%d_tint" % type), color)
	fade_light(type, color * FLASH_BOOST, Color.BLACK, true, Tween.TRANS_QUAD, Tween.EASE_IN)

func fade_light_from_current(type: int, to_color: Color) -> void:
	var current_color: Color
	match type:
		EventInfo.TYPE_DIAGONAL_LASERS:
			current_color = diagonal_lasers_material.get_shader_parameter(&"light_color")
		EventInfo.TYPE_SQUARE_LASERS:
			current_color = square_lasers_material.get_shader_parameter(&"light_color")
		EventInfo.TYPE_LEFT_WAVING_LASERS:
			current_color = left_waving_lasers_material.get_shader_parameter(&"light_color")
		EventInfo.TYPE_RIGHT_WAVING_LASERS:
			current_color = right_waving_lasers_material.get_shader_parameter(&"light_color")
		EventInfo.TYPE_FLOOR_LIGHTS:
			current_color = floor_material.albedo_color
	fade_light(type, current_color, to_color, false, Tween.TRANS_LINEAR, Tween.EASE_IN)

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

## Sets one of the sky's light parameters, on the sky and on everything that follows it.
func _set_light_param(param: StringName, value: Variant) -> void:
	sphere_material.set_shader_parameter(param, value)
	for material in _light_followers:
		material.set_shader_parameter(param, value)
