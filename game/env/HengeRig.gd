@tool
class_name HengeRig
extends Node3D
## Henge (doc/world/GAME_BIBLE.md "90° and 360° maps"; owner, 2026-10-29), the stage built for 90 and 360 degree maps:
## held breath, then release. SLAB_COUNT black monoliths stand in a ring round the player, RING_RADIUS out, on a dark
## floor disc, as silhouettes against a faint neutral glow on the horizon (HengeSky.gdshader). Nothing moves; only light
## does. Light only on the shapes (AGENTS.md "Light", rule 5): a strip up each slab's two inner vertical edges, lit in
## the map's left lasers' colour on the slabs left of where the track points and the right lasers' on the right
## (HengeStrip.gdshader, by the track's turn); a ring strip on the floor in the floor lights' colour; beams up from the
## slab tops (the diagonal lasers, LightRig). Bands of light from the gaps between the slabs rake across the floor
## toward the player, the slabs' shadows between, drawn in the floor's vertex colour (HengeFloor.gdshader), not per pixel.
## Slabs and strips are split into QUADRANTS MultiMeshes so the ones behind the player are culled. The build-up (edges
## lighting one by one round the circle) and the drop (every gap floods) are EventDriver._update_henge's.
## BLOCKOUT: plain boxes and strips. A tool script, so it shows in the editor too. Sizes in metres, untuned.

const STRIP_SHADER := preload("res://game/env/HengeStrip.gdshader")
const FLOOR_SHADER := preload("res://game/env/HengeFloor.gdshader")
const RING_SHADER := preload("res://game/env/LightStrip.gdshader")
## a see-through copy of the slabs that softens their outlines against the sky (EnvSolid layer 10), black as they are
const SHELL_SHADER := preload("res://game/env/EnvSolidShell.gdshader")
## the monoliths: how many round the circle, their inner faces' distance from the player, their size (across, up, deep);
## the gaps between are about 27 m
const SLAB_COUNT := 24
const RING_RADIUS := 150.0
const SLAB := Vector3(12.0, 120.0, 3.0)
## each inner-edge strip's section (across, deep), standing just proud of the slab's inner face
const EDGE_STRIP := Vector2(0.4, 0.3)
## the floor: a disc FLOOR_RADIUS out, its top FLOOR_Y below the track, under the platform's base; split into wedges
## round the player (_floor_mesh: the slab's shadow, the gap's band and the fades between) and BAND_STEPS rings to its edge
const FLOOR_RADIUS := 200.0
const FLOOR_Y := -TrackDeck.DECK_DEPTH
const BAND_STEPS := 6
## how wide (radians round the player) the shadows' sides fade from shadow to band, as far edges blur in the air: the
## same angle as the slabs' soft outlines (EnvSolid.gdshaderinc SHELL_BLUR_ANGLE). Untuned.
const SHADOW_BLUR := 0.007
## the floor's ring strip in the floor lights' colour: its radius, width and height above the floor
const RING_STRIP_RADIUS := 140.0
const RING_STRIP := Vector2(0.6, 0.05)
const RING_SEGMENTS := 192
## how many MultiMeshes the slabs and strips are split into round the circle, for culling
const QUADRANTS := 4

## the strips' material (left/right colours and the track's turn set each frame by EventDriver) and the floor ring's
var strip_material: ShaderMaterial
var ring_material: ShaderMaterial
## the floor's material, its drop flood set each frame by EventDriver
var floor_material: ShaderMaterial

func _ready() -> void:
	# black, unlit: the slabs read as silhouettes against the horizon's glow (the scenery's shader lit them grey, lighter
	# than the sky behind; desktop capture, 2026-10-29)
	var slab_material := StandardMaterial3D.new()
	slab_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slab_material.albedo_color = Color.BLACK
	var shell_material := ShaderMaterial.new()
	shell_material.shader = SHELL_SHADER
	shell_material.set_shader_parameter(&"shell_color", Color.BLACK)
	strip_material = ShaderMaterial.new()
	strip_material.shader = STRIP_SHADER
	for q in QUADRANTS:
		var slabs: Array[Transform3D] = []
		var strips: Array[Transform3D] = []
		for i in range(q * SLAB_COUNT / QUADRANTS, (q + 1) * SLAB_COUNT / QUADRANTS):
			slabs.append(slab_place(i))
			for side in [-1.0, 1.0]:
				strips.append(edge_strip_place(i, side))
		_add_boxes(slabs, slab_material)
		_add_boxes(slabs, shell_material)
		_add_boxes(strips, strip_material)
	var floor_disc := MeshInstance3D.new()
	floor_disc.mesh = _floor_mesh()
	floor_material = ShaderMaterial.new()
	floor_material.shader = FLOOR_SHADER
	floor_disc.material_override = floor_material
	floor_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_disc)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RING_STRIP_RADIUS - RING_STRIP.x * 0.5
	torus.outer_radius = RING_STRIP_RADIUS + RING_STRIP.x * 0.5
	torus.rings = RING_SEGMENTS
	torus.ring_segments = 4
	ring.mesh = torus
	ring.scale = Vector3(1.0, RING_STRIP.y / RING_STRIP.x, 1.0)
	ring.position.y = FLOOR_Y
	ring_material = ShaderMaterial.new()
	ring_material.shader = RING_SHADER
	ring.material_override = ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

## Slab `i`'s angle round the player (0 straight ahead, -z), turning right as the lanes do.
static func slab_angle(i: int) -> float:
	return TAU * i / SLAB_COUNT

## Where slab `i` stands: its inner face RING_RADIUS from the player, facing them, its foot on the floor.
static func slab_place(i: int) -> Transform3D:
	var turn := Basis(Vector3.UP, -slab_angle(i))
	var centre := Vector3(0.0, FLOOR_Y + SLAB.y * 0.5, -RING_RADIUS - SLAB.z * 0.5)
	return Transform3D(turn * Basis.from_scale(SLAB), _around_player(turn * centre))

## Where the strip up slab `i`'s inner edge on `side` (-1 left, 1 right, as the player faces the slab) stands.
static func edge_strip_place(i: int, side: float) -> Transform3D:
	var turn := Basis(Vector3.UP, -slab_angle(i))
	var centre := Vector3(side * (SLAB.x - EDGE_STRIP.x) * 0.5, FLOOR_Y + SLAB.y * 0.5,
		-RING_RADIUS + EDGE_STRIP.y * 0.5)
	return Transform3D(turn * Basis.from_scale(Vector3(EDGE_STRIP.x, SLAB.y, EDGE_STRIP.y)), _around_player(turn * centre))

## Where a beam stands on slab `i`'s top, at the middle of its inner half (LightRig: the diagonal lasers).
static func slab_top(i: int) -> Vector3:
	var turn := Basis(Vector3.UP, -slab_angle(i))
	return _around_player(turn * Vector3(0.0, FLOOR_Y + SLAB.y, -RING_RADIUS - SLAB.z * 0.25))

## A point given round the player's standing point (Constants.PLAYER_Z) in the stage's space.
static func _around_player(offset: Vector3) -> Vector3:
	return offset + Vector3(0.0, 0.0, Constants.PLAYER_Z)

## A MultiMesh of unit boxes at these places with `material`, without shadows, added as a child.
func _add_boxes(places: Array[Transform3D], material: Material) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = places.size()
	for i in places.size():
		multimesh.set_instance_transform(i, places[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

## The floor disc: four wedges a slab, the slab's shadow (vertex colour 0), a SHADOW_BLUR wide fade into the gap's
## band of light (1 at the ring, falling off toward the player and past the slabs), the band, and a fade back, in
## BAND_STEPS rings.
static func _floor_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	var half_slab := atan2(SLAB.x * 0.5, RING_RADIUS)
	for i in SLAB_COUNT:
		var a := slab_angle(i)
		var f := SHADOW_BLUR * 0.5
		var next := slab_angle(i + 1) - half_slab
		# [from angle, to angle, band at from, band at to]
		var edges := [[a - half_slab + f, a + half_slab - f, 0.0, 0.0], [a + half_slab - f, a + half_slab + f, 0.0, 1.0],
			[a + half_slab + f, next - f, 1.0, 1.0], [next - f, next + f, 1.0, 0.0]]
		for edge: Array in edges:
			for step in BAND_STEPS:
				var r0 := FLOOR_RADIUS * step / BAND_STEPS
				var r1 := FLOOR_RADIUS * (step + 1) / BAND_STEPS
				var p := [_floor_point(r0, edge[0]), _floor_point(r0, edge[1]), _floor_point(r1, edge[0]),
					_floor_point(r1, edge[1])]
				for k: int in [0, 2, 1, 1, 2, 3]:
					var band := _band(r1 if k >= 2 else r0)
					tool.set_color(Color(band * float(edge[3] if k % 2 == 1 else edge[2]), 0.0, 0.0))
					tool.add_vertex(p[k])
	return tool.commit()

## How bright a gap's band is `r` from the player: full at the slabs' ring, fading to nothing at the player and beyond
## the floor's edge.
static func _band(r: float) -> float:
	return clampf(r / RING_RADIUS, 0.0, 1.0) * clampf((FLOOR_RADIUS - r) / (FLOOR_RADIUS - RING_RADIUS), 0.0, 1.0)

## A point on the floor `r` from the player at angle `a` (as slab_angle).
static func _floor_point(r: float, a: float) -> Vector3:
	return _around_player(Basis(Vector3.UP, -a) * Vector3(0.0, FLOOR_Y, -r))
