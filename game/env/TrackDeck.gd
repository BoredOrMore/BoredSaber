extends Node3D
class_name TrackDeck
## The note track's deck (owner, 2026-10-25: the track looked flat, the lights beside it had no source): a solid deck
## whose top is the track (y 0) with the plate seams and lane grooves of TrackDeck.gdshader, and along each side the
## track's edge (track_edge.glb, tools/models/track_edge.py): a curb whose channel houses the edge light strip
## (EventDriver's track lights), so it sits flush in it instead of hanging in the air (AGENTS.md "Light", rule 5), and a
## skirt that carries the track down to the stage floor. It stands in for the old see-through track sheet, which stays for mixed reality and as
## the Old track setting (Settings.old_track). EventDriver lays it out for the lanes' width (the Wide modifiers).
## Sizes in metres; untuned.

const DECK_SHADER := preload("res://game/env/TrackDeck.gdshader")
const ENV_SOLID := preload("res://game/env/EnvSolid.gdshader")
const EDGE_MODEL := preload("res://game/models/track_edge.glb")
## the low block across the deck's far end the edge strips run into (track_end.glb, tools/models/track_end.py), 1 m wide
## as built, stretched across the deck and both edges (EDGE_REACH out on each side)
const END_MODEL := preload("res://game/models/track_end.glb")
const EDGE_REACH := 0.42
## the deck's length along the track (as the old sheet: from just ahead of the platform to the track's end) and depth.
## Its top is the track's surface, y 0: the notes, rows and hit plane are measured from it (game/AGENTS.md).
const DECK_Z := Vector2(-1.5, -48.0)
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
var _end: MeshInstance3D
## the deck's material, for the floor light's colour
var deck_material: ShaderMaterial

## Builds the deck and the curbs; layout() sizes them.
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
	_end = MeshInstance3D.new()
	_end.mesh = LaserFixtures._model_mesh(END_MODEL)
	_end.material_override = curb_material
	_end.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_end)
	layout(Constants.DEFAULT_LANE_DISTANCE_X)

## Sizes the deck for lanes `lane_width` apart (four lanes), puts the edges at its sides and the end stop across its end.
func layout(lane_width: float) -> void:
	var half := 2.0 * lane_width
	var length := DECK_Z.x - DECK_Z.y
	var z := (DECK_Z.x + DECK_Z.y) * 0.5
	_deck.transform = Transform3D(Basis.from_scale(Vector3(half * 2.0, DECK_DEPTH, length)), Vector3(0.0, -DECK_DEPTH * 0.5, z))
	deck_material.set_shader_parameter(&"lane_width", lane_width)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		# the model is the right edge, 1 m long; the left is it turned half round
		var turn := Basis.IDENTITY if side > 0.0 else Basis(Vector3.UP, PI)
		_curbs.set_instance_transform(i, Transform3D(turn * Basis.from_scale(Vector3(1.0, 1.0, length)), Vector3(side * half, 0.0, z)))
	_end.transform = Transform3D(Basis.from_scale(Vector3((half + EDGE_REACH) * 2.0, 1.0, 1.0)), Vector3(0.0, 0.0, DECK_Z.y))

## Dresses the deck for environment `id` (TrackDeck.gdshader's skins): Metal Factory's tread plate, Neon Grid's dark
## glass, plain plates elsewhere.
func set_skin(id: String) -> void:
	deck_material.set_shader_parameter(&"skin", SKINS.get(id, 0))

## Where an edge light strip `strip_size` big sits in the edge's channel on `side` (-1 left, 1 right), its top
## STRIP_PROUD above the curb's. Level with it, the two tops fought for depth and the strip vanished a few metres out
## (desktop capture, 2026-10-25).
static func strip_position(lane_width: float, side: float, strip_size: Vector3) -> Vector3:
	return Vector3(side * (2.0 * lane_width + STRIP_OUT), CURB_RISE + STRIP_PROUD - strip_size.y * 0.5, (DECK_Z.x + DECK_Z.y) * 0.5)
