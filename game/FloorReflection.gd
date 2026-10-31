extends Node3D
class_name FloorReflection
## The notes and sabers faintly mirrored in the track's dark deck, like the glossy floor of Beat Saber's PC version
## (owner, 2026-10-28). Each frame copies the notes on the track and the two blades, mirrored about the deck's top, into
## two MultiMeshes (one draw call each) drawn by FloorReflection.gdshader: no second render, no screen read. Off where
## the deck isn't (the old track, mixed reality). Untuned.

const SHADER := preload("res://game/FloorReflection.gdshader")
## at most this many notes are mirrored at once (the pool presizes 100; a dense map shows about 30 in flight)
const MAX_NOTES := 64
## the mirrored blade's thickness (m): a thin bar, as the blade's glowing core reads
const BLADE_WIDTH := 0.03
## custom data kinds the shader reads (FloorReflection.gdshader)
const KIND_NOTE := 0.0
const KIND_LEFT_SABER := 2.0
const KIND_RIGHT_SABER := 3.0

## the notes on the track: only its acquired ones are walked each frame, not the whole pool parked under the track
var _cubes: ScenePool
var _sabers: Array[LightSaber]
var _deck: Node3D
var _notes := MultiMesh.new()
var _blades := MultiMesh.new()
var _material := ShaderMaterial.new()
## the depth-only pass drawn first (FloorReflection.gdshader), with _material as its next pass
var _prepass := ShaderMaterial.new()
var _note_mesh: Mesh
## off while a fail drops the notes through the deck (BeepSaber_Game._empty_track), where a mirror would show them rise
var enabled := true

## Mirrors the notes acquired from `cubes` and the blades of `sabers` in the deck's top (`deck`'s y).
func _init(cubes: ScenePool, sabers: Array[LightSaber], deck: Node3D) -> void:
	_cubes = cubes
	_sabers = sabers
	_deck = deck
	_material.shader = SHADER
	_material.render_priority = 1
	_prepass.shader = SHADER
	_prepass.set_shader_parameter(&"prepass", true)
	_prepass.next_pass = _material
	for multimesh: MultiMesh in [_notes, _blades]:
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = _prepass
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# the instances move every frame wherever the notes are: never culled by a stale box
		instance.extra_cull_margin = 16384.0
		add_child(instance)
	_blades.mesh = BoxMesh.new()
	_blades.instance_count = _sabers.size()

func _process(_delta: float) -> void:
	# no deck to mirror in ahead of the round platform (90/360 maps)
	visible = enabled and _deck.is_visible_in_tree() and not (_deck as TrackDeck).is_round() and DebugView.flags & DebugView.NO_REFLECTION == 0
	if not visible:
		return
	var floor_y := _deck.global_position.y
	_material.set_shader_parameter(&"floor_y", floor_y)
	_prepass.set_shader_parameter(&"floor_y", floor_y)
	var mirror := Transform3D(Basis.from_scale(Vector3(1.0, -1.0, 1.0)), Vector3(0.0, 2.0 * floor_y, 0.0))
	var count := 0
	for node in _cubes.in_use:
		var cube := node as BeepCube
		if not cube.mi.is_visible_in_tree() or count == MAX_NOTES:
			continue
		if _note_mesh != cube.mi.mesh:
			_note_mesh = cube.mi.mesh
			_notes.mesh = _note_mesh
			_notes.instance_count = MAX_NOTES
		var color := (cube.mi.material_override as ShaderMaterial).get_shader_parameter(&"color") as Color
		color.a = KIND_NOTE
		_notes.set_instance_transform(count, mirror * cube.mi.global_transform)
		_notes.set_instance_custom_data(count, color)
		count += 1
	if _note_mesh != null:
		_notes.visible_instance_count = count
	for i in _sabers.size():
		var saber := _sabers[i]
		var base := saber.global_position
		var length := base.distance_to(saber.saber_end)
		if not saber.is_extended() or not saber.is_visible_in_tree() or length < 1e-3:
			_blades.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), base))
			continue
		var along := (saber.saber_end - base) / length
		var across := along.cross(Vector3.UP if absf(along.y) < 0.99 else Vector3.FORWARD).normalized()
		var blade := Basis(across * BLADE_WIDTH, along * length, along.cross(across) * BLADE_WIDTH)
		_blades.set_instance_transform(i, mirror * Transform3D(blade, (base + saber.saber_end) * 0.5))
		_blades.set_instance_custom_data(i, Color(0, 0, 0, KIND_LEFT_SABER if saber.type == 0 else KIND_RIGHT_SABER))
