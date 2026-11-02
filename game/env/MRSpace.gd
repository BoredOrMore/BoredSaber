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
## the sky sphere's radius (outside the cloud sea's 980 m, inside the camera's 1024 m far plane) and its segments
## round and rings up
const SKY_RADIUS := 1000.0
const SKY_SEGMENTS := 32
const SKY_RINGS := 16
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

## Builds the sky, the cloud sea and the dust.
func _ready() -> void:
	var sky := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = SKY_RADIUS
	sphere.height = SKY_RADIUS * 2.0
	sphere.radial_segments = SKY_SEGMENTS
	sphere.rings = SKY_RINGS
	sky.mesh = sphere
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky.material_override = sky_material
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.extra_cull_margin = SKY_RADIUS
	add_child(sky)
	var sea := MonolithCloudSea.new()
	sea.position.y = -SEA_DROP
	sea.brightness = SEA_BRIGHTNESS
	add_child(sea)
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
