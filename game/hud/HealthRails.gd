extends Node3D
class_name HealthRails

## Health shown as two glowing strips just outside the track, leaning toward the player, seen from the corner of the eye.
## The health bar mode shortens the strips toward the player; 4 Lives mode splits them into one pip per life.

## Gap between the outer edge of the outer lane and a strip, so the track's lights don't cover it;
## 1.75 m from the centre on the default track width.
const RAIL_MARGIN := 0.55
## Height of a strip's centre above the floor, so the floor doesn't flicker through it.
const RAIL_LIFT := 0.04
## How far each strip leans toward the player, so it reads as a band rather than a thin line.
const RAIL_TILT_DEGREES := 30.0
## Where the strips start, in front of the player, before a song has given the player's eye (start_map).
const RAIL_NEAR_Z := -1.0
## Worked out from the player's real eye (owner, 2026-10-27: further out, like the HUD, and from the eye): the strips
## start where the floor is RAIL_NEAR_DEGREES below it (they began 38 degrees down at 2 m, under a look down the
## track) and grow with that distance against RAIL_LAID_OUT_DISTANCE, so their width and the bolt keep their size
## in view.
const RAIL_NEAR_DEGREES := 22.0
const RAIL_LAID_OUT_DISTANCE := 2.0
## Length of a full strip.
const RAIL_LENGTH := 5.0
## Width of a strip; its ends are rounded with half this as the radius.
const RAIL_WIDTH := 0.05
## Must match edge_pad in HealthRail.gdshader.
const EDGE_PAD := 0.01
## Bolt icon (Energy) at the near end of the left strip, saying what the strips show: its size and how far it floats above
## the strip's start.
const ICON_SIZE := 0.1
const ICON_LIFT := 0.1
## Gap between two life pips.
const PIP_GAP := 0.25
## How much of the danger colour a lost life keeps, so it reads as an empty slot.
const LOST_BRIGHTNESS := 0.25
## Health at and above which the strips show no danger colour yet (untuned).
const DANGER_FROM := 0.8

var _how_full := 1.0
## where the strips start and how much wider they are, for the player's eye (start_map)
var _near_z := RAIL_NEAR_Z
var _grow := 1.0
var _pip_length := 0.0
var _how_full_display := 1.0
var _lives := false
var _bars: Array[MeshInstance3D] = []
var _pips: Array[MeshInstance3D] = []
const RAIL_SHADER := preload("res://game/hud/HealthRail.gdshader")

var _danger := Color.RED
var _icon := Sprite3D.new()
## the strips' and the bolt's opacity while a fail fades them (fade_out)
var _fade := 1.0
var _bar_material := _rail_material(Constants.HEALTH_FULL_COLOR)
var _lit_material := _rail_material(Constants.HEALTH_FULL_COLOR)
var _lost_material := _rail_material(Color.BLACK)

func _ready() -> void:
	_pip_length = (RAIL_LENGTH - PIP_GAP * (Constants.FAIL_LIVES - 1)) / Constants.FAIL_LIVES
	for side in [-1.0, 1.0]:
		_bars.append(_strip(side, RAIL_LENGTH, RAIL_NEAR_Z - RAIL_LENGTH / 2, _bar_material))
		for i in Constants.FAIL_LIVES:
			_pips.append(_strip(side, _pip_length, RAIL_NEAR_Z - _pip_length / 2 - i * (_pip_length + PIP_GAP), _lost_material))
	_icon.texture = preload("res://game/ui/bolt.svg")
	_icon.pixel_size = ICON_SIZE / _icon.texture.get_width()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_icon.position = Vector3(-_rail_x(), RAIL_LIFT + ICON_LIFT, RAIL_NEAR_Z)
	add_child(_icon)
	visibility_changed.connect(func() -> void: set_process(visible))
	set_process(visible)

## Picks bar or pip display for the coming map, starting from how_full, placed for the player's eye.
func start_map(lives: bool, how_full: float, eye := Hud.HUD_EYE) -> void:
	var distance := (eye.y - RAIL_LIFT) / tan(deg_to_rad(RAIL_NEAR_DEGREES))
	_near_z = eye.z - distance
	_grow = distance / RAIL_LAID_OUT_DISTANCE
	for i in _pips.size():
		var k := i % Constants.FAIL_LIVES
		_pips[i].position.z = _near_z - _pip_length / 2 - k * (_pip_length + PIP_GAP)
	for strip: MeshInstance3D in _bars + _pips:
		strip.scale.x = _grow
	_icon.position.z = _near_z
	_icon.position.y = RAIL_LIFT + ICON_LIFT * _grow
	_icon.scale = Vector3.ONE * _grow
	_lives = lives
	_danger = Map.color_obstacle
	var lost := _danger * LOST_BRIGHTNESS
	lost.a = 1.0
	_lost_material.set_shader_parameter(&"color", lost)
	# the Width modifier moves the outer lanes, so follow them
	for strip: MeshInstance3D in _bars + _pips:
		strip.position.x = signf(strip.position.x) * _rail_x()
	_icon.position.x = -_rail_x()
	for bar in _bars:
		bar.visible = not lives
	for pip in _pips:
		pip.visible = lives
	_how_full_display = how_full
	update_health(how_full)

## Shows health as a fraction of the maximum.
func update_health(how_full: float) -> void:
	_how_full = clampf(how_full, 0.0, 1.0)
	if _lives:
		var lives_left := roundi(_how_full * Constants.FAIL_LIVES)
		_lit_material.set_shader_parameter(&"color", _health_color(_how_full))
		_icon.modulate = Color(_health_color(_how_full), _fade)
		for i in _pips.size():
			_pips[i].material_override = _lit_material if i % Constants.FAIL_LIVES < lives_left else _lost_material

func _process(delta: float) -> void:
	if _lives:
		return
	_how_full_display = lerpf(_how_full_display, _how_full, delta * 8)
	var length := maxf(_how_full_display, 0.001) * RAIL_LENGTH
	for bar in _bars:
		bar.scale.z = length / RAIL_LENGTH
		bar.position.z = _near_z - length / 2
	_bar_material.set_shader_parameter(&"color", _health_color(_how_full_display))
	_icon.modulate = Color(_health_color(_how_full_display), _fade)

## Fades the strips and the bolt out over `seconds`, then hides them (owner, 2026-10-29: on a fail only FAILED stays in
## view); the next song shows them whole again.
func fade_out(seconds: float) -> void:
	var tween := create_tween()
	tween.tween_method(_set_fade, 1.0, 0.0, seconds)
	tween.tween_callback(func() -> void:
		visible = false
		_set_fade(1.0))

## The strips' and the bolt's opacity, 0 to 1.
func _set_fade(share: float) -> void:
	for material: ShaderMaterial in [_bar_material, _lit_material, _lost_material]:
		material.set_shader_parameter(&"fade", share)
	_fade = share
	_icon.modulate.a = share

## The full colour while health is high, turning into the song's danger colour as it runs out.
func _health_color(how_full: float) -> Color:
	return Constants.HEALTH_FULL_COLOR.lerp(_danger, 1.0 - smoothstep(0.0, DANGER_FROM, how_full))

func _strip(side: float, length: float, z: float, material: ShaderMaterial) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	# the shader leaves EDGE_PAD empty around the capsule for its soft edge
	mesh.size = Vector2(RAIL_WIDTH + 2 * EDGE_PAD, length + 2 * EDGE_PAD)
	var strip := MeshInstance3D.new()
	strip.mesh = mesh
	strip.material_override = material
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	strip.position = Vector3(side * _rail_x(), RAIL_LIFT, z)
	strip.rotation.z = side * deg_to_rad(RAIL_TILT_DEGREES)
	add_child(strip)
	return strip

## Distance of each strip from the track centre: past the outer lane's edge by RAIL_MARGIN.
static func _rail_x() -> float:
	return absf(Settings.LANE_ZERO_X) + Settings.LANE_DISTANCE_X / 2 + RAIL_MARGIN

static func _rail_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = RAIL_SHADER
	material.set_shader_parameter(&"color", color)
	return material
