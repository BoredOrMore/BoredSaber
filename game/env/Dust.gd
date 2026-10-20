class_name Dust
extends MeshInstance3D
## Dust floating in the air around the player (Dust.gdshader): COUNT specks in a box around where the player
## stands, each a quad whose four corners share its start point. One draw call. Untuned.

const DUST := preload("res://game/env/Dust.gdshader")
const COUNT := 400
## metres; the player stands at (0, 0, 1)
const BOX := Vector3(8.0, 3.5, 8.0)
const CENTRE := Vector3(0.0, 1.75, 1.0)
const CORNERS: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in COUNT:
		var start := Vector3(rng.randf(), rng.randf(), rng.randf()) * BOX
		for c in CORNERS:
			vertices.append(start)
			uvs.append(c)
		var a := i * 4
		indices.append_array([a, a + 1, a + 2, a, a + 2, a + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = array_mesh
	var material := ShaderMaterial.new()
	material.shader = DUST
	material.set_shader_parameter(&"box", BOX)
	material.set_shader_parameter(&"centre", CENTRE)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the shader moves the specks, so the mesh bounds don't cover them
	custom_aabb = AABB(CENTRE - BOX * 0.5 - Vector3.ONE, BOX + Vector3.ONE * 2.0)
