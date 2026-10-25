extends Node3D
class_name TrackDeck
## The note track's deck (owner, 2026-10-25: the track looked flat, the lights beside it had no source): a solid deck
## whose top is the track (y 0) with the plate seams and lane grooves of TrackDeck.gdshader, and a curb along each side
## that houses the edge light strips (EventDriver's track lights), so they sit flush in it instead of hanging in the air
## (AGENTS.md "Light", rule 5). It stands in for the old see-through track sheet, which stays for mixed reality and as
## the Old track setting (Settings.old_track). EventDriver lays it out for the lanes' width (the Wide modifiers).
## Sizes in metres; untuned.

const DECK_SHADER := preload("res://game/env/TrackDeck.gdshader")
const ENV_SOLID := preload("res://game/env/EnvSolid.gdshader")
## the deck's length along the track (as the old sheet: from just ahead of the platform to the track's end) and depth.
## Its top is the track's surface, y 0: the notes, rows and hit plane are measured from it (game/AGENTS.md).
const DECK_Z := Vector2(-1.5, -48.0)
const DECK_DEPTH := 0.4
## each curb's width, and how far its top stands above the deck
const CURB_WIDTH := 0.3
const CURB_RISE := 0.08
const STRIP_PROUD := 0.004

var _deck: MeshInstance3D
var _curbs: MultiMesh
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
	_curbs.mesh = BoxMesh.new()
	_curbs.instance_count = 2
	var curbs := MultiMeshInstance3D.new()
	curbs.multimesh = _curbs
	var curb_material := ShaderMaterial.new()
	curb_material.shader = ENV_SOLID
	curbs.material_override = curb_material
	curbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(curbs)
	layout(Constants.DEFAULT_LANE_DISTANCE_X)

## Sizes the deck for lanes `lane_width` apart (four lanes) and puts the curbs at its sides.
func layout(lane_width: float) -> void:
	var half := 2.0 * lane_width
	var length := DECK_Z.x - DECK_Z.y
	var z := (DECK_Z.x + DECK_Z.y) * 0.5
	_deck.transform = Transform3D(Basis.from_scale(Vector3(half * 2.0, DECK_DEPTH, length)), Vector3(0.0, -DECK_DEPTH * 0.5, z))
	deck_material.set_shader_parameter(&"lane_width", lane_width)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var height := DECK_DEPTH + CURB_RISE
		_curbs.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(CURB_WIDTH, height, length)),
			Vector3(side * (half + CURB_WIDTH * 0.5), CURB_RISE - height * 0.5, z)))

## Where an edge light strip `strip_size` big sits in the curb on `side` (-1 left, 1 right): along the curb's middle,
## its top STRIP_PROUD above the curb's. Level with it, the two tops fought for depth and the strip vanished a few
## metres out (desktop capture, 2026-10-25).
static func strip_position(lane_width: float, side: float, strip_size: Vector3) -> Vector3:
	return Vector3(side * (2.0 * lane_width + CURB_WIDTH * 0.5), CURB_RISE + STRIP_PROUD - strip_size.y * 0.5, (DECK_Z.x + DECK_Z.y) * 0.5)
