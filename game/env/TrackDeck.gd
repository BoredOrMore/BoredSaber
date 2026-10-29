extends Node3D
class_name TrackDeck
## The note track's deck (owner, 2026-10-25: the track looked flat, the lights beside it had no source): a solid deck
## whose top is the track (y 0) with the lane grooves of TrackDeck.gdshader, and along each side the
## track's edge (track_edge.glb, tools/models/track_edge.py): a curb whose channel houses the edge light strip
## (EventDriver's track lights), so it sits flush in it instead of hanging in the air (AGENTS.md "Light", rule 5), and a
## skirt that carries the track down to the stage floor. The player's platform is part of it (owner: as solid as the
## track, joined as one piece): the deck runs on under the 2 m pad (game/floor.tscn: the burn marks and border lights),
## where its top sits PAD_DEPTH lower, a frame (platform_frame.glb) rings the pad with the border lights in its channel,
## plain plates fill out to the deck's width, the edges run on along its sides and an end stop closes it behind the
## player. It stands in for the old see-through track sheet, which stays for mixed reality and as the Old track setting
## (Settings.old_track). EventDriver lays it out for the lanes' width (the Wide modifiers); the pad stays 2 m.
## On 90/360 maps the deck and its curbs turn with the notes about the player (turn, EventDriver.TRACK_TURN_TIME); the
## platform stays.
## Sizes in metres; untuned.

const DECK_SHADER := preload("res://game/env/TrackDeck.gdshader")
const ENV_SOLID := preload("res://game/env/EnvSolidMetal.gdshader")
const EDGE_MODEL := preload("res://game/models/track_edge.glb")
## the low block that closes the platform behind the player (track_end.glb, tools/models/track_end.py), 1 m wide as
## built, stretched across the deck and both edges (EDGE_REACH out on each side), turned to face away from the track
const END_MODEL := preload("res://game/models/track_end.glb")
const EDGE_REACH := 0.42
## the platform: its pad's centre (the player's place, game/floor.tscn), the frame's half width (it reaches past the
## border lights), how far below the deck's top the base under the pad sits (the burn marks and lights lie on it), the
## frame model
const PLATFORM_Z := 1.0
const FRAME_HALF := 1.1
const PAD_DEPTH := 0.03
const FRAME_MODEL := preload("res://game/models/platform_frame.glb")
## the deck's near end (the platform's front edge) and its depth. Its top is the track's surface, y 0: the notes, rows
## and hit plane are measured from it (game/AGENTS.md).
const DECK_NEAR := PLATFORM_Z - FRAME_HALF
## The deck has no end to be seen (owner, 2026-10-25): it runs on to FAR_Z and fades fully into the haze from FADE_START
## metres out to FADE_TAIL short of its end, edges and strips with it, past where notes and walls appear. A stage whose
## scenery is in the way stops it sooner (FAR_Z_BY_STAGE): Metal Factory's at its foundation, before the gear pit.
const FAR_Z := -150.0
const FAR_Z_BY_STAGE := {"metal_factory": -66.0}
const FADE_START := 45.0
const FADE_TAIL := 2.0
## the back of the platform, where the edges end and the second end stop closes it
const BACK_Z := PLATFORM_Z + FRAME_HALF
const DECK_DEPTH := 0.4
## from the edge model: how far out from the deck's edge its channel's middle is, and how far the curb's top stands above
## the deck; the strip's top stands STRIP_PROUD above the curb's
const STRIP_OUT := 0.15
const CURB_RISE := 0.08
const STRIP_PROUD := 0.004
## The edge strips are thin, white-hot lines like Beat Saber's lane edges (owner, 2026-10-28; its PC version's lines
## measure about 4 px about 5 m out in a 1920 px recording, roughly 1.5-2 cm wide), never under STRIP_MIN_PIXELS on
## screen, their tops STRIP_TOP_WHITE toward white with the colour in their sides. They were 10 cm, mostly flat colour.
const STRIP_WIDTH := 0.02
const STRIP_MIN_PIXELS := 1.5
const STRIP_TOP_WHITE := 0.7
## how far out from the deck's edge the curb's top reaches (the edge model's outer bevel); walls standing over it start
## above the strip (Wall.gd)
const CURB_OUT := 0.3
## each environment's skin (TrackDeck.gdshader); the rest get 0, plain plates
const SKINS := {"metal_factory": 1, "neon_grid": 2}
## the edges' metal sheen on stages whose metal shines (EnvSolid layer 8); none elsewhere
const METAL_BY_STAGE := {"metal_factory": MetalFactoryRig.METAL_SHEEN}

var _deck: MeshInstance3D
## the deck and its curbs, which turn with the notes (turn)
var _turning: Node3D
var _curbs: MultiMesh
var _ends: MultiMesh
var _base: MeshInstance3D
var _fillers: MultiMesh
var _curb_material: ShaderMaterial
## the lanes' spacing and the stage's far end the deck is laid out for
var _lane_width := Constants.DEFAULT_LANE_DISTANCE_X
var _far_z := FAR_Z
## the deck's material, for the floor light's colour
var deck_material: ShaderMaterial

## Builds the deck, its edges and end stops and the platform; layout() sizes them.
func _ready() -> void:
	_turning = Node3D.new()
	add_child(_turning)
	deck_material = ShaderMaterial.new()
	deck_material.shader = DECK_SHADER
	_deck = MeshInstance3D.new()
	_deck.mesh = BoxMesh.new()
	_deck.material_override = deck_material
	_deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_turning.add_child(_deck)
	_curbs = MultiMesh.new()
	_curbs.transform_format = MultiMesh.TRANSFORM_3D
	_curbs.mesh = LaserFixtures._model_mesh(EDGE_MODEL)
	_curbs.instance_count = 2
	var curbs := MultiMeshInstance3D.new()
	curbs.multimesh = _curbs
	var curb_material := ShaderMaterial.new()
	curb_material.shader = ENV_SOLID
	_curb_material = curb_material
	curbs.material_override = curb_material
	curbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_turning.add_child(curbs)
	_ends = _add_multimesh(LaserFixtures._model_mesh(END_MODEL), 1, curb_material)
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
	layout(_lane_width)

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

## Sizes the deck for lanes `lane_width` apart (four lanes): the edges at its sides out to the stage's far end, the end
## stop behind the platform, and the platform's base and fillers out to the deck's width.
func layout(lane_width: float) -> void:
	_lane_width = lane_width
	var half := 2.0 * lane_width
	var length := DECK_NEAR - _far_z
	_deck.transform = Transform3D(Basis.from_scale(Vector3(half * 2.0, DECK_DEPTH, length)),
		Vector3(0.0, -DECK_DEPTH * 0.5, (DECK_NEAR + _far_z) * 0.5))
	deck_material.set_shader_parameter(&"lane_width", lane_width)
	var edge_length := BACK_Z - _far_z
	var edge_z := (BACK_Z + _far_z) * 0.5
	_ends.set_instance_transform(0, Transform3D(Basis(Vector3.UP, PI) * Basis.from_scale(Vector3((half + EDGE_REACH) * 2.0, 1.0, 1.0)),
		Vector3(0.0, 0.0, BACK_Z)))
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		# the edge model is the right edge, 1 m long; the left is it turned half round
		var turn := Basis.IDENTITY if side > 0.0 else Basis(Vector3.UP, PI)
		_curbs.set_instance_transform(i, Transform3D(turn * Basis.from_scale(Vector3(1.0, 1.0, edge_length)), Vector3(side * half, 0.0, edge_z)))
		# the plain plates from the frame out to the deck's edge (none at the narrowest width)
		var filler := maxf(half - FRAME_HALF, 0.001)
		_fillers.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(filler, PAD_DEPTH, FRAME_HALF * 2.0)),
			Vector3(side * (FRAME_HALF + filler * 0.5), -PAD_DEPTH * 0.5, PLATFORM_Z)))
	_base.transform = Transform3D(Basis.from_scale(Vector3(half * 2.0, DECK_DEPTH - PAD_DEPTH, FRAME_HALF * 2.0)),
		Vector3(0.0, -PAD_DEPTH - (DECK_DEPTH - PAD_DEPTH) * 0.5, PLATFORM_Z))

## Turns the deck and its curbs to `place` (EventDriver's turn about the player); the platform stays.
func turn(place: Transform3D) -> void:
	_turning.transform = place

## Fits the deck to environment `id`: its skin (TrackDeck.gdshader: Metal Factory's tread plate, Neon Grid's dark glass,
## plain plates elsewhere) and its far end and fade.
func set_stage(id: String) -> void:
	deck_material.set_shader_parameter(&"skin", SKINS.get(id, 0))
	_far_z = FAR_Z_BY_STAGE.get(id, FAR_Z)
	var fade := fade_z()
	deck_material.set_shader_parameter(&"fade_z", fade)
	_curb_material.set_shader_parameter(&"fade_z", fade)
	_curb_material.set_shader_parameter(&"metal", METAL_BY_STAGE.get(id, 0.0))
	_curb_material.set_shader_parameter(&"matcap", MetalFactoryRig.MATCAP)
	layout(_lane_width)

## Where the deck fades into the haze: from and to, in metres out along the track (-z).
func fade_z() -> Vector2:
	return Vector2(minf(FADE_START, -_far_z * 0.6), -_far_z - FADE_TAIL)

## The span along the track the edge strips run over: from the deck's near end to its far end (z).
func strip_span() -> Vector2:
	return Vector2(DECK_NEAR, _far_z)

## Where an edge light strip `strip_size` big sits in the edge's channel on `side` (-1 left, 1 right), its top
## STRIP_PROUD above the curb's. Level with it, the two tops fought for depth and the strip vanished a few metres out
## (desktop capture, 2026-10-25).
static func strip_position(lane_width: float, side: float, strip_size: Vector3) -> Vector3:
	return Vector3(side * (2.0 * lane_width + STRIP_OUT), CURB_RISE + STRIP_PROUD - strip_size.y * 0.5, 0.0)
