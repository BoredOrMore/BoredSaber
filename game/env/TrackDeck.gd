extends Node3D
class_name TrackDeck
## The note track's deck (owner, 2026-10-25: the track looked flat, the lights beside it had no source): a solid deck
## whose top is the track (y 0) with the plate seams and lane grooves of TrackDeck.gdshader, and along each side the
## track's edge (track_edge.glb, tools/models/track_edge.py): a curb whose channel houses the edge light strip
## (EventDriver's track lights), so it sits flush in it instead of hanging in the air (AGENTS.md "Light", rule 5), and a
## skirt that carries the track down to the stage floor. The player's platform is part of it (owner: as solid as the
## track, joined as one piece): the deck runs on under the 2 m pad (game/floor.tscn: the burn marks and border lights),
## where its top sits PAD_DEPTH lower, a frame (platform_frame.glb) rings the pad with the border lights in its channel,
## plain plates fill out to the deck's width, the edges run on along its sides and an end stop closes it behind the
## player. It stands in for the old see-through track sheet, which stays for mixed reality and as the Old track setting
## (Settings.old_track). EventDriver lays it out for the lanes' width (the Wide modifiers); the pad stays 2 m.
## Sizes in metres; untuned.

const DECK_SHADER := preload("res://game/env/TrackDeck.gdshader")
const ENV_SOLID := preload("res://game/env/EnvSolid.gdshader")
const EDGE_MODEL := preload("res://game/models/track_edge.glb")
## the low block across the deck's far end the edge strips run into (track_end.glb, tools/models/track_end.py), 1 m wide
## as built, stretched across the deck and both edges (EDGE_REACH out on each side)
const END_MODEL := preload("res://game/models/track_end.glb")
const EDGE_REACH := 0.42
## the platform: its pad's centre (the player's place, game/floor.tscn), the frame's half width (it reaches past the
## border lights), how far below the deck's top the base under the pad sits (the burn marks and lights lie on it), the
## frame model
const PLATFORM_Z := 1.0
const FRAME_HALF := 1.1
const PAD_DEPTH := 0.03
const FRAME_MODEL := preload("res://game/models/platform_frame.glb")
## the deck's length along the track, from the platform's front edge to the track's end, and its depth. Its top is the
## track's surface, y 0: the notes, rows and hit plane are measured from it (game/AGENTS.md).
const DECK_Z := Vector2(PLATFORM_Z - FRAME_HALF, -48.0)
## the back of the platform, where the edges end and the second end stop closes it
const BACK_Z := PLATFORM_Z + FRAME_HALF
const DECK_DEPTH := 0.4
## from the edge model: how far out from the deck's edge its channel's middle is, and how far the curb's top stands above
## the deck; the strip's top stands STRIP_PROUD above the curb's
const STRIP_OUT := 0.15
const CURB_RISE := 0.08
const STRIP_PROUD := 0.004
## each environment's skin (TrackDeck.gdshader); the rest get 0, plain plates
const SKINS := {"metal_factory": 1, "neon_grid": 2}

var _deck: MeshInstance3D
var _curbs: MultiMesh
var _ends: MultiMesh
var _base: MeshInstance3D
var _fillers: MultiMesh
## the deck's material, for the floor light's colour
var deck_material: ShaderMaterial

## Builds the deck, its edges and end stops and the platform; layout() sizes them.
func _ready() -> void:
	deck_material = ShaderMaterial.new()
	deck_material.shader = DECK_SHADER
	_deck = MeshInstance3D.new()
	_deck.mesh = BoxMesh.new()
	_deck.material_override = deck_material
	_deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_deck)
	_curbs = MultiMesh.new()
	_curbs.transform_format = MultiMesh.TRANSFORM_3D
	_curbs.mesh = LaserFixtures._model_mesh(EDGE_MODEL)
	_curbs.instance_count = 2
	var curbs := MultiMeshInstance3D.new()
	curbs.multimesh = _curbs
	var curb_material := ShaderMaterial.new()
	curb_material.shader = ENV_SOLID
	curbs.material_override = curb_material
	curbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(curbs)
	_ends = _add_multimesh(LaserFixtures._model_mesh(END_MODEL), 2, curb_material)
	_base = MeshInstance3D.new()
	_base.mesh = BoxMesh.new()
	_base.material_override = deck_material
	_base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_base)
	_fillers = _add_multimesh(BoxMesh.new(), 2, curb_material)
	var frame := MeshInstance3D.new()
	frame.mesh = LaserFixtures._model_mesh(FRAME_MODEL)
	frame.material_override = curb_material
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame.position = Vector3(0.0, 0.0, PLATFORM_Z)
	add_child(frame)
	layout(Constants.DEFAULT_LANE_DISTANCE_X)

## A MultiMesh of `count` copies of `mesh` with `material`, without shadows, added as a child.
func _add_multimesh(mesh: Mesh, count: int, material: ShaderMaterial) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return multimesh

## Sizes the deck for lanes `lane_width` apart (four lanes): the edges at its sides, the end stops across its far end and
## behind the platform, and the platform's base and fillers out to the deck's width.
func layout(lane_width: float) -> void:
	var half := 2.0 * lane_width
	var length := DECK_Z.x - DECK_Z.y
	_deck.transform = Transform3D(Basis.from_scale(Vector3(half * 2.0, DECK_DEPTH, length)),
		Vector3(0.0, -DECK_DEPTH * 0.5, (DECK_Z.x + DECK_Z.y) * 0.5))
	deck_material.set_shader_parameter(&"lane_width", lane_width)
	var edge_length := BACK_Z - DECK_Z.y
	var edge_z := (BACK_Z + DECK_Z.y) * 0.5
	var width := (half + EDGE_REACH) * 2.0
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		# the edge model is the right edge, 1 m long; the left is it turned half round. The end stop faces the player as
		# built; the one behind the platform is turned to face the other way.
		var turn := Basis.IDENTITY if side > 0.0 else Basis(Vector3.UP, PI)
		_curbs.set_instance_transform(i, Transform3D(turn * Basis.from_scale(Vector3(1.0, 1.0, edge_length)), Vector3(side * half, 0.0, edge_z)))
		var end_turn := Basis.IDENTITY if i == 0 else Basis(Vector3.UP, PI)
		_ends.set_instance_transform(i, Transform3D(end_turn * Basis.from_scale(Vector3(width, 1.0, 1.0)),
			Vector3(0.0, 0.0, DECK_Z.y if i == 0 else BACK_Z)))
		# the plain plates from the frame out to the deck's edge (none at the narrowest width)
		var filler := maxf(half - FRAME_HALF, 0.001)
		_fillers.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(filler, PAD_DEPTH, FRAME_HALF * 2.0)),
			Vector3(side * (FRAME_HALF + filler * 0.5), -PAD_DEPTH * 0.5, PLATFORM_Z)))
	_base.transform = Transform3D(Basis.from_scale(Vector3(half * 2.0, DECK_DEPTH - PAD_DEPTH, FRAME_HALF * 2.0)),
		Vector3(0.0, -PAD_DEPTH - (DECK_DEPTH - PAD_DEPTH) * 0.5, PLATFORM_Z))

## Dresses the deck for environment `id` (TrackDeck.gdshader's skins): Metal Factory's tread plate, Neon Grid's dark
## glass, plain plates elsewhere.
func set_skin(id: String) -> void:
	deck_material.set_shader_parameter(&"skin", SKINS.get(id, 0))

## Where an edge light strip `strip_size` big sits in the edge's channel on `side` (-1 left, 1 right), its top
## STRIP_PROUD above the curb's. Level with it, the two tops fought for depth and the strip vanished a few metres out
## (desktop capture, 2026-10-25).
static func strip_position(lane_width: float, side: float, strip_size: Vector3) -> Vector3:
	return Vector3(side * (2.0 * lane_width + STRIP_OUT), CURB_RISE + STRIP_PROUD - strip_size.y * 0.5, (DECK_Z.x + DECK_Z.y) * 0.5)
