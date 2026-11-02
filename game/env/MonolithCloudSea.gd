@tool
class_name MonolithCloudSea
extends Node3D
## Monolith's cloud sea (owner, 2026-11-01: the version made with GPT in stylized-3d-agent, picked over the 3D banks
## after a headset comparison): one continuous sheet round the player (game/models/monolith_cloud/cloud.glb) drawn by
## MonolithCloudSea.gdshader, and its baked height map (heightfield.bin, described by heightfield.json), which every
## material that sinks into the sea reads through bind_material (monolith_cloud_sea.gdshaderinc). Place it by moving or
## turning it about the vertical only: the shaders take world to the sea's space as a plain inverse.

const SEA_SCENE := preload("res://game/models/monolith_cloud/cloud.glb")
const BODY_SHADER := preload("res://game/env/MonolithCloudSea.gdshader")
const HEIGHT_MAP := "res://game/models/monolith_cloud/heightfield.bin"
const HEIGHT_INFO := "res://game/models/monolith_cloud/heightfield.json"

## the body's brightness, 1 as in Monolith; set before the sea enters the tree
var brightness := 1.0

var _height_texture: ImageTexture
var _bounds: Vector4
var _heights: Vector2
var _materials: Array[ShaderMaterial] = []

## Builds the sea's body and loads its height map.
func _ready() -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HEIGHT_INFO))
	var size: int = info.resolution
	var bytes := FileAccess.get_file_as_bytes(HEIGHT_MAP)
	assert(bytes.size() == size * size * 4, "heightfield.bin must hold resolution^2 RGBA8 cells")
	_height_texture = ImageTexture.create_from_image(Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes))
	var bounds: Array = info.bounds_xz_m
	_bounds = Vector4(bounds[0], bounds[1], bounds[2], bounds[3])
	var heights: Array = info.height_range_m
	_heights = Vector2(heights[0], heights[1])
	var scene := SEA_SCENE.instantiate()
	var bodies := scene.find_children("*", "MeshInstance3D")
	assert(bodies.size() == 1, "cloud.glb must hold one mesh")
	var body: MeshInstance3D = bodies[0]
	var material := ShaderMaterial.new()
	material.shader = BODY_SHADER
	material.set_shader_parameter(&"brightness", brightness)
	body.material_override = material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(scene)
	set_notify_transform(true)
	bind_material(material)

## Gives `material` (a shader including monolith_cloud_sea.gdshaderinc) the sea's height map and where it lies, and
## keeps it up to date when the sea moves. Call once the sea is in the tree.
func bind_material(material: ShaderMaterial) -> void:
	assert(_height_texture != null, "bind materials once the cloud sea is in the tree")
	if not _materials.has(material):
		_materials.append(material)
	_sync(material)

## Sets the sea's height map and its place on `material`.
func _sync(material: ShaderMaterial) -> void:
	var place := global_transform
	assert(place.basis.is_equal_approx(place.basis.orthonormalized()) and place.basis.y.is_equal_approx(Vector3.UP),
			"the cloud sea only moves and turns about the vertical")
	material.set_shader_parameter(&"mcloud_surface_map", _height_texture)
	material.set_shader_parameter(&"mcloud_bounds", _bounds)
	material.set_shader_parameter(&"mcloud_height_range", _heights)
	material.set_shader_parameter(&"mcloud_world_to_local", place.affine_inverse())

## Updates every bound material when the sea moves.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		for material in _materials:
			_sync(material)
