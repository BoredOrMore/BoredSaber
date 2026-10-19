extends Node3D
## Smoke around the stage, as in Beat Saber: a thin drifting layer just above the floor and big soft puffs beside
## and behind the track, all lit by the scene lights. On the Pico 4 the smoke cost about 1.7 ms of GPU a frame with two
## floor layers and ten puffs, so it is down to one layer and the six puffs that take the least of the screen. Kept below knee height or away from the note lanes, and faded out
## close to the player. Drawn before the other see-through things, so lights and walls show on top. All values untuned.

const FLOOR_SMOKE := preload("res://game/env/FloorSmoke.gdshader")
const SMOKE_BANK := preload("res://game/env/SmokeBank.gdshader")
const RENDER_PRIORITY := -4
const NOISE_SIZE := 256
const FLOOR_SIZE := Vector2(14.0, 30.0)
const FLOOR_CENTER_Z := -12.0
## one vertex every metre or so, as the floor smoke works out its fades per vertex
const FLOOR_SUBDIVIDE := Vector2i(13, 29)
## height, opacity, and drift of each noise copy in metres per second, for each floor layer; one layer about as thick
## as the two there were
const FLOOR_LAYERS := [
	[0.12, 0.45, Vector2(0.05, 0.12), Vector2(-0.08, 0.05)],
]
## x, y, z and size of each puff, beside the track further ahead (the ones close to the player filled most of the
## screen when looking sideways)
const BANKS: Array[Vector4] = [
	Vector4(-5.0, 1.2, -11.0, 4.5), Vector4(5.2, 1.0, -12.0, 4.5),
	Vector4(-4.8, 1.6, -19.0, 5.0), Vector4(5.0, 1.4, -20.0, 5.0),
	Vector4(-4.5, 2.4, -28.0, 6.0), Vector4(4.8, 2.6, -29.0, 6.0),
]
const BANK_OPACITY := 0.25

func _ready() -> void:
	var noise := NoiseTexture2D.new()
	noise.width = NOISE_SIZE
	noise.height = NOISE_SIZE
	noise.seamless = true
	noise.generate_mipmaps = true
	var fast_noise := FastNoiseLite.new()
	fast_noise.fractal_octaves = 4
	noise.noise = fast_noise

	var plane := PlaneMesh.new()
	plane.size = FLOOR_SIZE
	plane.subdivide_width = FLOOR_SUBDIVIDE.x
	plane.subdivide_depth = FLOOR_SUBDIVIDE.y
	for layer: Array in FLOOR_LAYERS:
		var material := ShaderMaterial.new()
		material.shader = FLOOR_SMOKE
		material.render_priority = RENDER_PRIORITY
		material.set_shader_parameter(&"noise", noise)
		material.set_shader_parameter(&"opacity", layer[1])
		material.set_shader_parameter(&"drift_a", layer[2])
		material.set_shader_parameter(&"drift_b", layer[3])
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = plane
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.position = Vector3(0.0, layer[0], FLOOR_CENTER_Z)
		add_child(mesh_instance)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = QuadMesh.new()
	multimesh.instance_count = BANKS.size()
	for i in BANKS.size():
		var bank := BANKS[i]
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * bank.w), Vector3(bank.x, bank.y, bank.z)))
	var bank_material := ShaderMaterial.new()
	bank_material.shader = SMOKE_BANK
	bank_material.render_priority = RENDER_PRIORITY
	bank_material.set_shader_parameter(&"noise", noise)
	bank_material.set_shader_parameter(&"opacity", BANK_OPACITY)
	var banks := MultiMeshInstance3D.new()
	banks.multimesh = multimesh
	banks.material_override = bank_material
	banks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the puffs turn to face the player, so they can reach outside the squares' own bounds
	banks.custom_aabb = AABB(Vector3(-12.0, -2.0, -40.0), Vector3(24.0, 10.0, 44.0))
	add_child(banks)
