@tool
class_name MonolithRig
extends Node3D
## Monolith (doc/world/GAME_BIBLE.md "Monolith"; owner, 2026-10-31): standing before something that was here before you.
## Abstract, no story. The player stands on a tall pillar in the middle of a valley (owner, 2026-10-31): the valley floor
## lies VALLEY_Y below, its sides step up in terraces to ridges on both sides, and low stylized clouds drift among the
## terraces (owner's pick B), drawn like stage flats (owner's reference, 2026-10-31): upright rings round the player, each
## a band whose top is a row of round puffs, nearer rings darker, farther ones paler. One colossal black slab (SLAB, 1:4:9) stands on the valley floor SLAB_DISTANCE away, down
## the valley SLAB_YAW off straight ahead, its broad face turned to the player: tiny beside something massive, not inside
## it or at its centre. Nothing within the notes' fly-in (Cuttable.FLY_DISTANCE, r 320 m) rises above y -5 in any
## direction (terraces start high only beyond it, clouds stay below), so it serves 90 and 360 degree maps too.
## Light only on the slab (AGENTS.md "Light", rule 5), drawn in its face's own shader (MonolithFace.gdshader; flush strip
## meshes would fight for depth this far out): its two vertical edges in the left and right lasers' colours, horizontal
## seams in the square bars' colour lit from the foot up as the show builds, a slit up the middle and a strip along a
## ledge in the floor lights' colour, LEDGE_HEIGHT up, clear above the clouds; beams up its face from fixtures on that
## ledge (the diagonal and waving lasers, LightRig; owner, 2026-10-31: moved up out of the clouds). Behind it the horizon glows faintly (MonolithSky) so it stands as a silhouette, and its shadow falls down
## the valley toward the player (MonolithFloor.gdshader, on the valley and the pillar). The clouds are opaque with holes
## (MonolithCloud.gdshader), so they cost no blending.
## Far edges stay sharp in the blockout: the soft-edge layer (AGENTS.md "Soft far edges") goes on the slab's outline
## once the look is agreed, never across its per-seam lights.
## BLOCKOUT: one box, the valley mesh, a pillar and the cloud rings. A tool script, so it shows in the editor too.
## Sizes in metres, untuned.

const FACE_SHADER := preload("res://game/env/MonolithFace.gdshader")
const FLOOR_SHADER := preload("res://game/env/MonolithFloor.gdshader")
const CLOUD_SHADER := preload("res://game/env/MonolithCloud.gdshader")
const CLOUD_EDGE_SHADER := preload("res://game/env/MonolithCloudEdge.gdshader")
## the slab: its size (across, up, deep), its front face's distance from the player and its turn left of straight ahead
## (radians), which is also the way the valley runs; its top front corners stand about 950 m away, inside the camera's
## far plane (1024 m)
const SLAB := Vector3(360.0, 810.0, 90.0)
const SLAB_DISTANCE := 520.0
const SLAB_YAW := deg_to_rad(30.0)
## the ledge across the slab's face carrying the lasers' fixtures and the floor lights' strip: metres up from its foot,
## above the clouds' puffs round the slab (up to about +60 m, CLOUD_RINGS)
const LEDGE_HEIGHT := 150.0
## the pillar the player stands on: from under the platform (PILLAR_TOP) down to the valley floor, PILLAR_RADIUS wide
const PILLAR_TOP := -TrackDeck.DECK_DEPTH
const PILLAR_RADIUS := 10.0
const PILLAR_SIDES := 6
## the valley: its floor's height and half width, then terraces up both sides, each TERRACE_RISE higher than the last,
## TERRACE_TREAD deep with a TERRACE_RISER wide face; the first one above y -5 starts beyond the notes' fly-in (r 320 m)
## even where the valley bends (VALLEY_BEND metres either way, one bend every VALLEY_BEND_LENGTH metres along it)
const VALLEY_Y := -80.0
const VALLEY_HALF_WIDTH := 230.0
const TERRACE_RISE := 15.0
const TERRACE_TREAD := 30.0
const TERRACE_RISER := 4.0
const VALLEY_BEND := 25.0
const VALLEY_BEND_LENGTH := 1600.0
## the valley mesh ends VALLEY_RADIUS from the player (inside the far plane), VALLEY_ROWS rows along it
const VALLEY_RADIUS := 980.0
const VALLEY_ROWS := 120
## the clouds: one upright ring per entry of CLOUD_RINGS (radius, puffs' base height, their tallest rise above it), from
## the valley floor up to a row of round puffs CLOUD_PUFF_WIDTH wide (metres at 400 m out, wider farther away), one
## vertex per CLOUD_STEP metres along the top. Rings within the notes' fly-in (r 320 m) keep their puffs below y -5.
const CLOUD_RINGS := [Vector3(220.0, -45.0, 26.0), Vector3(360.0, -25.0, 34.0),
	Vector3(470.0, -12.0, 44.0), Vector3(760.0, 0.0, 60.0)]
const CLOUD_PUFF_WIDTH := Vector2(40.0, 110.0)
const CLOUD_STEP := 3.0
## the puffs' base rises and falls round each ring by this much, CLOUD_SWELLS times round
const CLOUD_SWELL := 8.0
const CLOUD_SWELLS := 5
## the clouds' soft edge (owner, 2026-10-31): a see-through fringe out from the puffs' outline, this wide as an angle
## seen from the player (radians, so far rings get wider fringes), its direction smoothed over this many top vertices
## either side so it doesn't fold at the dips between puffs
const CLOUD_BLUR := 0.012
const CLOUD_BLUR_SMOOTH := 3
## the random puffs come from this seed, so every load looks the same
const CLOUD_SEED := 31

## the slab face's material (light colours, build-up and slit set each frame by EventDriver) and the floor's
var face_material: ShaderMaterial
var floor_material: ShaderMaterial

func _ready() -> void:
	face_material = ShaderMaterial.new()
	face_material.shader = FACE_SHADER
	face_material.set_shader_parameter(&"size", SLAB)
	face_material.set_shader_parameter(&"ledge_height", LEDGE_HEIGHT)
	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = SLAB
	slab.mesh = box
	slab.transform = slab_place()
	slab.material_override = face_material
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(slab)
	floor_material = ShaderMaterial.new()
	floor_material.shader = FLOOR_SHADER
	floor_material.set_shader_parameter(&"slab_centre", Vector2(slab_place().origin.x, slab_place().origin.z))
	floor_material.set_shader_parameter(&"slab_yaw", SLAB_YAW)
	floor_material.set_shader_parameter(&"slab_half_width", SLAB.x * 0.5)
	floor_material.set_shader_parameter(&"slab_distance", SLAB_DISTANCE)
	_sink_into_clouds(face_material)
	_sink_into_clouds(floor_material)
	var valley := MeshInstance3D.new()
	valley.mesh = _valley_mesh()
	valley.transform = Transform3D(slab_basis(), _around_player(Vector3.ZERO))
	valley.material_override = floor_material
	valley.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(valley)
	var pillar := MeshInstance3D.new()
	var column := CylinderMesh.new()
	column.top_radius = PILLAR_RADIUS
	column.bottom_radius = PILLAR_RADIUS
	column.height = PILLAR_TOP - VALLEY_Y
	column.radial_segments = PILLAR_SIDES
	column.rings = 0
	column.cap_top = false
	column.cap_bottom = false
	pillar.mesh = column
	pillar.position = _around_player(Vector3(0.0, (PILLAR_TOP + VALLEY_Y) * 0.5, 0.0))
	pillar.material_override = floor_material
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pillar)
	var random := RandomNumberGenerator.new()
	random.seed = CLOUD_SEED
	for i in CLOUD_RINGS.size():
		var material := ShaderMaterial.new()
		material.shader = CLOUD_SHADER
		material.set_shader_parameter(&"depth_share", float(i) / (CLOUD_RINGS.size() - 1))
		var edge_material := ShaderMaterial.new()
		edge_material.shader = CLOUD_EDGE_SHADER
		edge_material.set_shader_parameter(&"depth_share", float(i) / (CLOUD_RINGS.size() - 1))
		var cloud := MeshInstance3D.new()
		cloud.mesh = _cloud_ring(CLOUD_RINGS[i], random)
		cloud.position = _around_player(Vector3.ZERO)
		cloud.set_surface_override_material(0, material)
		cloud.set_surface_override_material(1, edge_material)
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cloud)

## Gives `material` the cloud rings' radii and levels (the puffs' middle height), so what lies below them sinks in
## (monolith_cloud.gdshaderinc).
func _sink_into_clouds(material: ShaderMaterial) -> void:
	assert(CLOUD_RINGS.size() == 4, "monolith_cloud.gdshaderinc takes exactly 4 rings")
	var radii := Vector4.ZERO
	var levels := Vector4.ZERO
	for i in 4:
		radii[i] = CLOUD_RINGS[i].x
		levels[i] = CLOUD_RINGS[i].y + CLOUD_RINGS[i].z * 0.5
	material.set_shader_parameter(&"cloud_radii", radii)
	material.set_shader_parameter(&"cloud_levels", levels)
	material.set_shader_parameter(&"cloud_centre", Vector2(0.0, Constants.PLAYER_Z))

## One ring of cloud (`ring`: radius, the puffs' base height, their tallest rise): a band from the valley floor up to a
## row of overlapping round puffs (surface 0; UV.y holds the metres down from the top, for the cloud's rim and shading),
## and its soft edge, a fringe CLOUD_BLUR wide out from the outline (surface 1; UV.x 0 on the outline to 1 at its rim).
func _cloud_ring(ring: Vector3, random: RandomNumberGenerator) -> ArrayMesh:
	var around := TAU * ring.x
	var scale := ring.x / 400.0
	# the puffs: centre along the ring and radius, each overlapping the last
	var puffs: Array[Vector2] = []
	var along := 0.0
	while along < around:
		var radius := random.randf_range(CLOUD_PUFF_WIDTH.x, CLOUD_PUFF_WIDTH.y) * 0.5 * scale
		puffs.append(Vector2(along + radius, radius))
		along += radius * random.randf_range(1.0, 1.6)
	var tallest := 0.0
	for puff in puffs:
		tallest = maxf(tallest, puff.y)
	var samples := ceili(around / CLOUD_STEP)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tops: Array[Vector2] = []
	var first := 0
	for i in samples + 1:
		var s := around * i / samples
		while first < puffs.size() - 1 and puffs[first].x + puffs[first].y < s:
			first += 1
		var top := 0.0
		for p in range(first, mini(first + 4, puffs.size())):
			var d := s - puffs[p].x
			if absf(d) < puffs[p].y:
				top = maxf(top, sqrt(puffs[p].y * puffs[p].y - d * d))
		var height := ring.y + CLOUD_SWELL * sin(s / ring.x * CLOUD_SWELLS) + top / tallest * ring.z
		tops.append(Vector2(s, height))
		var out := _ring_point(ring.x, s)
		vertices.append(out + Vector3(0.0, height, 0.0))
		uvs.append(Vector2(0.0, 0.0))
		vertices.append(out + Vector3(0.0, VALLEY_Y, 0.0))
		uvs.append(Vector2(0.0, height - VALLEY_Y))
	var indices := PackedInt32Array()
	for i in samples:
		var a := i * 2
		indices.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# the fringe: each top vertex and one pushed out across the outline (along the ring and up)
	var width := CLOUD_BLUR * ring.x
	var fringe := PackedVector3Array()
	var fringe_uvs := PackedVector2Array()
	for i in tops.size():
		var before := tops[maxi(i - CLOUD_BLUR_SMOOTH, 0)]
		var after := tops[mini(i + CLOUD_BLUR_SMOOTH, tops.size() - 1)]
		var tangent := (after - before).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var angle := tops[i].x / ring.x
		var along_dir := Vector3(cos(angle), 0.0, sin(angle))
		var top := _ring_point(ring.x, tops[i].x) + Vector3(0.0, tops[i].y, 0.0)
		fringe.append(top)
		fringe_uvs.append(Vector2(0.0, 0.0))
		fringe.append(top + (along_dir * normal.x + Vector3.UP * normal.y) * width)
		fringe_uvs.append(Vector2(1.0, 0.0))
	arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = fringe
	arrays[Mesh.ARRAY_TEX_UV] = fringe_uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## The point on a ring of `radius` round the player, `along` metres round it from straight ahead (-z), at y 0.
static func _ring_point(radius: float, along: float) -> Vector3:
	var angle := along / radius
	return Vector3(sin(angle), 0.0, -cos(angle)) * radius

## The valley in its own frame (x across, -z down the valley toward the slab): one column of vertices at each edge of
## the floor and of every terrace face, so the steps stay sharp, each column reaching as far along as VALLEY_RADIUS allows.
func _valley_mesh() -> ArrayMesh:
	var profile: Array[Vector2] = [Vector2(0.0, VALLEY_Y)]
	var edge := VALLEY_HALF_WIDTH
	var step := 0
	while edge < VALLEY_RADIUS:
		profile.append(Vector2(edge, VALLEY_Y + step * TERRACE_RISE))
		step += 1
		profile.append(Vector2(minf(edge + TERRACE_RISER, VALLEY_RADIUS), VALLEY_Y + step * TERRACE_RISE))
		edge += TERRACE_TREAD
	var columns: Array[Vector2] = []
	for i in range(profile.size() - 1, 0, -1):
		columns.append(Vector2(-profile[i].x, profile[i].y))
	columns.append_array(profile)
	var vertices := PackedVector3Array()
	for column in columns:
		var reach := sqrt(maxf(VALLEY_RADIUS * VALLEY_RADIUS - column.x * column.x, 1.0))
		for row in VALLEY_ROWS + 1:
			var along := lerpf(-reach, reach, float(row) / VALLEY_ROWS)
			var bend := VALLEY_BEND * sin(along * TAU / VALLEY_BEND_LENGTH)
			vertices.append(Vector3(column.x + bend, column.y, along))
	var indices := PackedInt32Array()
	for c in columns.size() - 1:
		for row in VALLEY_ROWS:
			var a := c * (VALLEY_ROWS + 1) + row
			var b := a + VALLEY_ROWS + 1
			indices.append_array([a, b, a + 1, a + 1, b, b + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## The slab's turn round the player: straight ahead (-z) turned SLAB_YAW to the left.
static func slab_basis() -> Basis:
	return Basis(Vector3.UP, SLAB_YAW)

## Where the slab stands: its front face SLAB_DISTANCE from the player, facing them, its foot on the valley floor.
static func slab_place() -> Transform3D:
	var centre := Vector3(0.0, VALLEY_Y + SLAB.y * 0.5, -SLAB_DISTANCE - SLAB.z * 0.5)
	return Transform3D(slab_basis(), _around_player(slab_basis() * centre))

## Where a light stands on the slab's ledge, just in front of its face, `share` of the way across from its left edge to
## its right as the player sees it (LightRig: the lasers' fixtures, shining up the face).
static func ledge_spot(share: float) -> Vector3:
	var across := (share - 0.5) * SLAB.x
	return _around_player(slab_basis() * Vector3(across, VALLEY_Y + LEDGE_HEIGHT, -SLAB_DISTANCE + 2.0))

## The way up the slab's face, leaning back onto it by `lean` (0 straight up), for the beams on its ledge.
static func up_face(lean: float) -> Vector3:
	return (slab_basis() * Vector3(0.0, 1.0, -lean)).normalized()

## A point given round the player's standing point (Constants.PLAYER_Z) in the stage's space.
static func _around_player(offset: Vector3) -> Vector3:
	return offset + Vector3(0.0, 0.0, Constants.PLAYER_Z)
