extends Node3D
class_name LaserFixtures
## A moving-head light at the pivot of every laser (AGENTS.md "Light", rule 5), built like a real one: a yoke fixed to
## the pedestal, and the head as its child, tilting about the one axis through the yoke's arms (the pivot, the head's
## centre when it points straight up), its lens where the beam leaves; the beam turns around the same pivot. The yoke
## is set once, its arms across the beam's sweep, and again only when its laser moves to another place (a rig change);
## this scene never turns it. (It used to turn toward the beam's heading every frame, which flipped half a turn
## whenever a waving laser swept through straight up: the player saw it glitch.) A soft glow in the beam's colour sits in front of each lens,
## always facing the player, so the bright spot where the beam leaves shows even when the lens faces away (from the
## player's place the heads point up and away; Blender render, 2026-10-24). Each part is one MultiMesh; every frame
## they copy their laser's place and turn, and lens and glow take the beam's colour (black when the light is off).
## The heads and yokes are objects, not light: they stay when their light turns off (which hides the beam's node) and
## only go with the rest of the scenery (EventDriver: mixed reality, simple background).
## Models: game/models/laser_fixture(_yoke).glb, made by tools/models/laser_fixture.py; shaders LaserFixture.gdshader
## (head and yoke) and LaserFlare.gdshader (glow).

const HEAD := preload("res://game/models/laser_fixture.glb")
const YOKE := preload("res://game/models/laser_fixture_yoke.glb")
const BODY_SHADER := preload("res://game/env/LaserFixture.gdshader")
const FLARE_SHADER := preload("res://game/env/LaserFlare.gdshader")
## how far in front of the head's centre the glow sits (the lens is 0.26 m out), and its size in metres; halved with the
## fixture (tools/models/laser_fixture.py SIZE). Untuned.
const FLARE_FORWARD := 0.3
const FLARE_SIZE := 0.8
## A head whose light has been off for REST_AFTER_SECONDS lowers its nose to REST_TILT_DEG below level, as a rig
## waiting for the show; it wakes and aims again when its light comes on, fast so the beam is not left behind.
## The wait keeps strobing lights from making the heads nod. Speeds are per second (exponential approach). Untuned.
const REST_AFTER_SECONDS := 2.0
const REST_TILT_DEG := -35.0
const REST_SPEED := 2.0
const WAKE_SPEED := 25.0

var _lasers: Array[Node3D] = []
var _materials: Array[ShaderMaterial] = []
var _heads: MultiMesh
var _yokes: MultiMesh
var _flares: MultiMesh
## each yoke's fixed turn and the place it was set for
var _yoke_bases: Array[Basis] = []
var _yoke_places: Array[Vector3] = []
## each head's tilt now (radians about the yoke's arms) and how long its light has been off
var _tilts := PackedFloat32Array()
var _dark := PackedFloat32Array()

## One fixture per laser; `materials[i]` is the beam material whose light_color laser i shows.
func setup(lasers: Array[Node3D], materials: Array[ShaderMaterial]) -> void:
	_lasers = lasers
	_materials = materials
	var body := ShaderMaterial.new()
	body.shader = BODY_SHADER
	var flare := ShaderMaterial.new()
	flare.shader = FLARE_SHADER
	var quad := QuadMesh.new()
	_heads = _add_part(_model_mesh(HEAD), body)
	_yokes = _add_part(_model_mesh(YOKE), body)
	_flares = _add_part(quad, flare)
	_yoke_bases.resize(lasers.size())
	_yoke_places.resize(lasers.size())
	_yoke_places.fill(Vector3.INF)
	_tilts.resize(lasers.size())
	_dark.resize(lasers.size())

static func _model_mesh(scene: PackedScene) -> Mesh:
	var model: Node = scene.instantiate()
	var mesh: Mesh = (model.find_children("*", "MeshInstance3D")[0] as MeshInstance3D).mesh
	model.free()
	return mesh

func _add_part(mesh: Mesh, material: ShaderMaterial) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = _lasers.size()
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return multimesh

func _process(delta: float) -> void:
	for i in _lasers.size():
		var laser := _lasers[i]
		var at := laser.global_position
		var beam := -laser.global_basis.z.normalized()
		if at.distance_squared_to(_yoke_places[i]) > 1e-4:
			_yoke_bases[i] = _yoke_basis(laser, beam)
			_yoke_places[i] = at
		var yoke := _yoke_bases[i]
		# the head's tilt about the yoke's x axis that points its lens (-z) along the beam within the yoke's plane
		var local := yoke.inverse() * beam
		var color := _materials[i].get_shader_parameter(&"light_color") as Color
		_dark[i] = _dark[i] + delta if color.get_luminance() <= 0.0 else 0.0
		var resting := _dark[i] > REST_AFTER_SECONDS
		var aim := deg_to_rad(REST_TILT_DEG) if resting else atan2(local.y, -local.z)
		_tilts[i] = lerp_angle(_tilts[i], aim, 1.0 - exp(-delta * (REST_SPEED if resting else WAKE_SPEED)))
		var head := yoke * Basis(Vector3.RIGHT, _tilts[i])
		_heads.set_instance_transform(i, Transform3D(head, at))
		_yokes.set_instance_transform(i, Transform3D(yoke, at))
		_flares.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * FLARE_SIZE), at + beam * FLARE_FORWARD))
		for part in [_heads, _yokes, _flares]:
			(part as MultiMesh).set_instance_custom_data(i, color)

## Upright, with its arms (x) across the plane the beam sweeps in: the beam's sideways axis, level. A laser that turns
## about one level axis (the waving ones) keeps that axis whatever its angle, so the head follows it exactly.
static func _yoke_basis(laser: Node3D, beam: Vector3) -> Basis:
	var across := beam.cross(Vector3.UP)
	if across.length_squared() < 1e-4:
		across = laser.global_basis.x
	across.y = 0.0
	across = across.normalized() if across.length_squared() > 1e-6 else Vector3.RIGHT
	return Basis(across, Vector3.UP, across.cross(Vector3.UP))
