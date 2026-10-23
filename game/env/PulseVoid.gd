class_name PulseVoid
extends Node3D
## Pulse Void: rings of light around the track that beat with the music. One MultiMesh draws every ring, and a
## spectrum analyzer on the Music bus, added only while this environment shows, gives each ring its band.
## Bass is near the player, treble far away. All values untuned.

const PULSE_RING := preload("res://game/env/PulseRing.gdshader")
const SEGMENTS := 96
const RING_COUNT := 16
## the first ring goes round the player (who stands at z 1), so the tunnel starts where they stand
const FIRST_Z := 1.0
const RING_GAP := 3.5
## the rings' centre height and radius in metres; wide enough to stay clear of every note and wall
const CENTER_Y := 1.5
const RADIUS := 6.0
## each ring is this much wider than the one before it, so the far ones still frame the view
const RADIUS_STEP := 0.25
## frequency bands, low to high, in Hz, shared out in order from the nearest ring to the farthest
const BANDS: Array[Vector2] = [
	Vector2(30, 80), Vector2(80, 160), Vector2(160, 320), Vector2(320, 640),
	Vector2(640, 1250), Vector2(1250, 2500), Vector2(2500, 5000), Vector2(5000, 10000),
]
## quietest band level that shows, in dB
const FLOOR_DB := -60.0
## how fast a ring dims after a beat, in level per second; it brightens at once
const RELEASE := 3.0

## A point on ring `ring` (0 is the nearest) at `angle` radians from +x, counter-clockwise as the player sees it,
## where EventDriver mounts a light. At the ring's resting radius; the ring grows only 4% with the music.
static func ring_point(ring: int, angle: float) -> Vector3:
	var radius := RADIUS + ring * RADIUS_STEP
	return Vector3(cos(angle) * radius, CENTER_Y + sin(angle) * radius, FIRST_Z - ring * RING_GAP)

## takes the left and right laser lights from EventDriver
var ring_material: ShaderMaterial
var _multimesh: MultiMesh
var _levels := PackedFloat32Array()
var _analyzer: AudioEffectSpectrumAnalyzerInstance

func _init() -> void:
	ring_material = ShaderMaterial.new()
	ring_material.shader = PULSE_RING

func _ready() -> void:
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_custom_data = true
	_multimesh.mesh = _ring_mesh()
	_multimesh.instance_count = RING_COUNT
	_levels.resize(RING_COUNT)
	for i in RING_COUNT:
		_multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(0, CENTER_Y, FIRST_Z - i * RING_GAP)))
		_multimesh.set_instance_custom_data(i, Color(0, i % 2, RADIUS + i * RADIUS_STEP))
	var rings := MultiMeshInstance3D.new()
	rings.multimesh = _multimesh
	rings.material_override = ring_material
	rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the shader places the vertices, so the mesh bounds don't cover the rings
	var reach := RADIUS + RING_COUNT * RADIUS_STEP + 1.0
	rings.custom_aabb = AABB(Vector3(-reach, CENTER_Y - reach, FIRST_Z - RING_COUNT * RING_GAP), Vector3(2 * reach, 2 * reach, RING_COUNT * RING_GAP + 1.0))
	add_child(rings)
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()

## A unit circle as a strip: each vertex keeps its direction in x, y and which edge of the line it is on in z.
static func _ring_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in SEGMENTS + 1:
		var angle := TAU * i / SEGMENTS
		vertices.append(Vector3(cos(angle), sin(angle), -1.0))
		vertices.append(Vector3(cos(angle), sin(angle), 1.0))
		if i < SEGMENTS:
			var a := 2 * i
			indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _on_visibility_changed() -> void:
	var bus := AudioServer.get_bus_index(&"Music")
	if bus < 0:
		return
	if is_visible_in_tree() and not _analyzer:
		AudioServer.add_bus_effect(bus, AudioEffectSpectrumAnalyzer.new())
		_analyzer = AudioServer.get_bus_effect_instance(bus, AudioServer.get_bus_effect_count(bus) - 1)
	elif not is_visible_in_tree() and _analyzer:
		for i in AudioServer.get_bus_effect_count(bus):
			if AudioServer.get_bus_effect(bus, i) is AudioEffectSpectrumAnalyzer:
				AudioServer.remove_bus_effect(bus, i)
				break
		_analyzer = null
	set_process(_analyzer != null)

func _process(delta: float) -> void:
	for i in RING_COUNT:
		@warning_ignore("integer_division")
		var band := BANDS[i * BANDS.size() / RING_COUNT]
		var magnitude := _analyzer.get_magnitude_for_frequency_range(band.x, band.y)
		var target := clampf((linear_to_db(maxf(magnitude.x, magnitude.y)) - FLOOR_DB) / -FLOOR_DB, 0.0, 1.0)
		_levels[i] = maxf(target, _levels[i] - RELEASE * delta)
		var data := _multimesh.get_instance_custom_data(i)
		data.r = _levels[i]
		_multimesh.set_instance_custom_data(i, data)
