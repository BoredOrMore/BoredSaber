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
## (head and yoke) and LaserFlare.gdshader (glow). A stage may give a laser another kind of fixture (set_kind):
## FOLLOW_SPOT, Classic's follow spots on the wall catwalks (tools/models/follow_spot.py), a long can on a tripod, its
## lens further out. Each kind is its own MultiMeshes over all the lasers; a laser's other kinds are drawn at no size.

const HEAD := preload("res://game/models/laser_fixture.glb")
const YOKE := preload("res://game/models/laser_fixture_yoke.glb")
const FOLLOW_SPOT_HEAD := preload("res://game/models/follow_spot.glb")
const FOLLOW_SPOT_STAND := preload("res://game/models/follow_spot_stand.glb")
const MOVING_HEAD := 0
const FOLLOW_SPOT := 1
const BODY_SHADER := preload("res://game/env/LaserFixture.gdshader")
const FLARE_SHADER := preload("res://game/env/LaserFlare.gdshader")
## how far in front of the head's centre the glow sits (the lens is 0.26 m out), and its size in metres; halved with the
## fixture (tools/models/laser_fixture.py SIZE). Untuned.
const FLARE_FORWARD := 0.3
## the follow spot's lens is 0.46 m out (follow_spot.py)
const FOLLOW_SPOT_FLARE_FORWARD := 0.5
const FLARE_SIZE := 0.8
## A head whose light has been off for REST_AFTER_SECONDS lowers its nose to REST_TILT_DEG below level, as a rig
## waiting for the show; it wakes and aims again when its light comes on, fast so the beam is not left behind.
## The wait keeps strobing lights from making the heads nod. Speeds are per second (exponential approach). Untuned.
const REST_AFTER_SECONDS := 2.0
const REST_TILT_DEG := -35.0
const REST_SPEED := 2.0
const WAKE_SPEED := 25.0

## how far (the sine of the angle) a beam may leave its yoke's plane before the yoke pans after it
const YOKE_PAN_SLACK := 0.01
var _lasers: Array[Node3D] = []
var _materials: Array[ShaderMaterial] = []
## per kind (MOVING_HEAD, FOLLOW_SPOT)
var _heads: Array[MultiMesh] = []
var _yokes: Array[MultiMesh] = []
var _kinds := PackedInt32Array()
## every part, for the colour
var _parts: Array[MultiMesh] = []
## per kind, its head's and yoke's nodes: hidden while no laser uses the kind (no draw calls)
var _kind_nodes: Array[Array] = []
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
	for models in [[HEAD, YOKE], [FOLLOW_SPOT_HEAD, FOLLOW_SPOT_STAND]]:
		_heads.append(_add_part(_model_mesh(models[0]), body))
		_yokes.append(_add_part(_model_mesh(models[1]), body))
		_kind_nodes.append([get_child(-2), get_child(-1)])
	_kinds.resize(lasers.size())
	set_kind(0, MOVING_HEAD)
	_flares = _add_part(quad, flare)
	_parts.assign(_heads + _yokes)
	_parts.append(_flares)
	_yoke_bases.resize(lasers.size())
	_yoke_places.resize(lasers.size())
	_yoke_places.fill(Vector3.INF)
	_tilts.resize(lasers.size())
	_dark.resize(lasers.size())

## Which fixture laser i (setup's order) stands on: MOVING_HEAD or FOLLOW_SPOT.
func set_kind(i: int, kind: int) -> void:
	_kinds[i] = kind
	for k in _kind_nodes.size():
		for node: Node3D in _kind_nodes[k]:
			node.visible = _kinds.has(k)

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
		# the yoke pans when the laser moves, or when its beam leaves the yoke's plane by more than YOKE_PAN_SLACK (the
		# build-up sweep turns the moving heads sideways, EventDriver._update_sweep); a waving laser stays in its plane
		if at.distance_squared_to(_yoke_places[i]) > 1e-4 or absf(_yoke_bases[i].x.dot(beam)) > YOKE_PAN_SLACK:
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
		for k in _heads.size():
			var shown := k == _kinds[i]
			_heads[k].set_instance_transform(i, Transform3D(head if shown else Basis.from_scale(Vector3.ZERO), at))
			_yokes[k].set_instance_transform(i, Transform3D(yoke if shown else Basis.from_scale(Vector3.ZERO), at))
		var forward := FOLLOW_SPOT_FLARE_FORWARD if _kinds[i] == FOLLOW_SPOT else FLARE_FORWARD
		_flares.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * FLARE_SIZE), at + beam * forward))
		for part in _parts:
			part.set_instance_custom_data(i, color)

## Upright, with its arms (x) across the plane the beam sweeps in: the beam's sideways axis, level. A laser that turns
## about one level axis (the waving ones) keeps that axis whatever its angle, so the head follows it exactly.
static func _yoke_basis(laser: Node3D, beam: Vector3) -> Basis:
	var across := beam.cross(Vector3.UP)
	if across.length_squared() < 1e-4:
		across = laser.global_basis.x
	across.y = 0.0
	across = across.normalized() if across.length_squared() > 1e-6 else Vector3.RIGHT
	return Basis(across, Vector3.UP, across.cross(Vector3.UP))
