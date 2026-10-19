extends Node3D
class_name HealthRails

## Health shown as two glowing strips on the floor along the track edges, seen from the corner of the eye.
## The health bar mode shortens the strips toward the player; 4 Lives mode splits them into one pip per life.

## Distance of each strip from the track centre.
const RAIL_X := 1.3
## Where the strips start, in front of the player.
const RAIL_NEAR_Z := -1.0
## Length of a full strip.
const RAIL_LENGTH := 5.0
## Width and height of a strip.
const RAIL_WIDTH := 0.05
const RAIL_HEIGHT := 0.01
## Gap between two life pips.
const PIP_GAP := 0.25
## Colour of a lost life.
const LOST_COLOR := Color(0.3, 0.06, 0.06)

var _how_full := 1.0
var _how_full_display := 1.0
var _lives := false
var _bars: Array[MeshInstance3D] = []
var _pips: Array[MeshInstance3D] = []
var _bar_material := _unshaded(Color.WHITE)
var _lit_material := _unshaded(Color.GREEN)
var _lost_material := _unshaded(LOST_COLOR)

func _ready() -> void:
	var pip_length := (RAIL_LENGTH - PIP_GAP * (Constants.FAIL_LIVES - 1)) / Constants.FAIL_LIVES
	for side in [-1.0, 1.0]:
		_bars.append(_strip(side, RAIL_LENGTH, RAIL_NEAR_Z - RAIL_LENGTH / 2, _bar_material))
		for i in Constants.FAIL_LIVES:
			_pips.append(_strip(side, pip_length, RAIL_NEAR_Z - pip_length / 2 - i * (pip_length + PIP_GAP), _lost_material))
	visibility_changed.connect(func() -> void: set_process(visible))
	set_process(visible)

## Picks bar or pip display for the coming map, starting from how_full.
func start_map(lives: bool, how_full: float) -> void:
	_lives = lives
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
		_lit_material.albedo_color = _health_color(_how_full)
		for i in _pips.size():
			_pips[i].material_override = _lit_material if i % Constants.FAIL_LIVES < lives_left else _lost_material

func _process(delta: float) -> void:
	if _lives:
		return
	_how_full_display = lerpf(_how_full_display, _how_full, delta * 8)
	var length := maxf(_how_full_display, 0.001) * RAIL_LENGTH
	for bar in _bars:
		bar.scale.z = length / RAIL_LENGTH
		bar.position.z = RAIL_NEAR_Z - length / 2
	_bar_material.albedo_color = _health_color(_how_full_display)

## Red when empty, green when full, like the old health ring.
func _health_color(how_full: float) -> Color:
	return Color(1.0 - how_full, how_full, 0.0)

func _strip(side: float, length: float, z: float, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(RAIL_WIDTH, RAIL_HEIGHT, length)
	var strip := MeshInstance3D.new()
	strip.mesh = mesh
	strip.material_override = material
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	strip.position = Vector3(side * RAIL_X, RAIL_HEIGHT / 2, z)
	add_child(strip)
	return strip

static func _unshaded(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
