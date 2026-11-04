class_name MRSpace
extends Node3D
## The world behind the room's portals in room-aware mixed reality (owner, 2026-11-02: concept C, "the room floats in
## space"; plan https://claude.ai/artifact/GGNL7bgEiekk4VeT4G3aVy): a starry sky with the notes' source far down the
## track (MRSpaceSky.gdshader) and near dust for depth (MRSpaceDust.gdshader). Stands alone with its root at the
## origin and nothing near it, no track or deck: the room code places it behind the portals. Below the room lies
## Monolith's cloud sea (MonolithCloudSea; owner's pick, 2026-11-02), a bowl rising toward its far rim, dropped by
## SEA_DROP so that rim stays under eye level and the notes' source and the planets show above it. The notes' path is kept
## clear (memory rule: nothing within NOTE_PATH_REACH between NOTE_PATH_Y heights). BLOCKOUT, sizes in metres, untuned.

const SKY_SHADER := preload("res://game/env/MRSpaceSky.gdshader")
const DUST_SHADER := preload("res://game/env/MRSpaceDust.gdshader")
const SEA_SHADER := preload("res://game/env/MRSpaceCloudSea.gdshader")
## how far the cloud sea sits below where Monolith puts it (its bowl's floor about 57 m down, its far rim about +30 m
## up), in metres
const SEA_DROP := 110.0
## the cloud sea's brightness against Monolith's (owner, 2026-11-02: darker than Monolith's against black space)
const SEA_BRIGHTNESS := 0.4
## the dust: how many points, their nearest and farthest distance, their size, and the seed that places them
const DUST_COUNT := 500
const DUST_NEAR := 15.0
const DUST_FAR := 260.0
const DUST_SIZE := 0.25
const DUST_SEED := 7
## the notes' path the dust stays out of: half its width round the track, its heights, how far it reaches
const NOTE_PATH_HALF_WIDTH := 6.0
const NOTE_PATH_Y := Vector2(-5.0, 30.0)
const NOTE_PATH_REACH := 320.0
## the sky's baked cube map: pixels along each face's side (a pixel spans about 0.18 degrees, the headset's about 0.05:
## only soft layers are baked, the stars stay sharp and live)
const BAKE_SIZE := 512

## The sky's material, its windows (one per portal, show_windows), the cloud sea and the dust.
var _sky_material: ShaderMaterial
## The sky cut down to a flat colour, by whether its stencil mark is left out too, made the first time DebugView asks
## for each (show_parts).
var _flat_sky_materials := {}
var _windows: Array[MeshInstance3D] = []
var _window_count := 0
var _sea: MonolithCloudSea
var _dust: MultiMeshInstance3D
## Whether the sky may show once baked (show_parts).
var _sky_wanted := true
## Whether the sky's cube map is baked.
var _baked := false

## Builds the sky, the cloud sea and the dust.
func _ready() -> void:
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = SKY_SHADER
	_bake_sky()
	var sea := MonolithCloudSea.new()
	sea.position.y = -SEA_DROP
	sea.brightness = SEA_BRIGHTNESS
	# first among the see-through things, before the portals' rims (MixedReality), the walls and the arcs
	sea.body_shader = SEA_SHADER
	sea.body_priority = Material.RENDER_PRIORITY_MIN
	add_child(sea)
	_sea = sea
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = QuadMesh.new()
	var places := _dust_places()
	multimesh.instance_count = places.size()
	for i in places.size():
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * DUST_SIZE), places[i]))
	var dust := MultiMeshInstance3D.new()
	dust.multimesh = multimesh
	var dust_material := ShaderMaterial.new()
	dust_material.shader = DUST_SHADER
	dust.material_override = dust_material
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)
	_dust = dust

## Bakes the sky's fixed layers into the cube map its shader reads (MRSpaceSky.gdshader), one face a frame, then
## shows the sky's windows.
func _bake_sky() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(BAKE_SIZE, BAKE_SIZE)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var camera := Camera3D.new()
	viewport.add_child(camera)
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	face.mesh = quad
	# in front of the camera so it isn't culled; the shader places it over the whole screen
	face.position = Vector3(0.0, 0.0, -1.0)
	var bake_material := ShaderMaterial.new()
	bake_material.shader = SKY_SHADER
	face.material_override = bake_material
	viewport.add_child(face)
	add_child(viewport)
	var images: Array[Image] = []
	for i in 6:
		bake_material.set_shader_parameter(&"bake_face", i)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		images.append(viewport.get_texture().get_image())
	viewport.queue_free()
	var cube := Cubemap.new()
	var error := cube.create_from_images(images)
	assert(error == OK, "the sky's bake makes a cube map")
	_sky_material.set_shader_parameter(&"baked", cube)
	_baked = true
	_show_sky()


## Puts a sky window over each portal: `places` are the portals' world transforms (+z out of the room), `sizes` their
## sizes in metres; the rest are hidden.
func show_windows(places: Array[Transform3D], sizes: Array[Vector2]) -> void:
	while _windows.size() < places.size():
		var window := MeshInstance3D.new()
		window.mesh = QuadMesh.new()
		window.material_override = _sky_material
		window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(window)
		_windows.append(window)
	for i in places.size():
		_windows[i].global_transform = places[i].scaled_local(Vector3(sizes[i].x, sizes[i].y, 1.0))
	_window_count = places.size()
	_show_sky()


## Shows the windows in use while the sky is baked and wanted.
func _show_sky() -> void:
	for i in _windows.size():
		_windows[i].visible = i < _window_count and _baked and _sky_wanted


## Shows or hides the sky (once baked), the cloud sea and the dust, and draws the sky flat (with or without its
## stencil mark), to measure each one's cost (DebugView).
func show_parts(sky: bool, sea: bool, dust: bool, flat_sky: bool, no_stencil: bool) -> void:
	_sky_wanted = sky
	_show_sky()
	var material := _sky_material
	if flat_sky:
		if not _flat_sky_materials.has(no_stencil):
			var flat := Shader.new()
			# the fragment is the shader's last function: its body goes under a constant false, which the compiler drops
			flat.code = SKY_SHADER.code.replace("void fragment() {", "void fragment() {\n\tALBEDO = vec3(0.05);\n\tif (false) {") + "}\n"
			if no_stencil:
				flat.code = flat.code.replace("stencil_mode write, compare_always, 1;", "")
			_flat_sky_materials[no_stencil] = ShaderMaterial.new()
			_flat_sky_materials[no_stencil].shader = flat
		material = _flat_sky_materials[no_stencil]
	for window in _windows:
		window.material_override = material
	_sea.visible = sea
	_dust.visible = dust


## Where the dust points float: spread through the shell between DUST_NEAR and DUST_FAR, none in the notes' path.
static func _dust_places() -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = DUST_SEED
	var places: Array[Vector3] = []
	while places.size() < DUST_COUNT:
		var dir := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var p := dir * lerpf(DUST_NEAR, DUST_FAR, sqrt(rng.randf()))
		var in_path := absf(p.x) < NOTE_PATH_HALF_WIDTH and p.y > NOTE_PATH_Y.x and p.y < NOTE_PATH_Y.y \
			and p.z < 0.0 and p.z > -NOTE_PATH_REACH
		if not in_path:
			places.append(p)
	return places
