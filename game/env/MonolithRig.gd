@tool
class_name MonolithRig
extends Node3D
## Monolith (doc/world/GAME_BIBLE.md "Monolith"; owner, 2026-10-31): standing before something that was here before you.
## Abstract, no story. The player stands on a tall pillar in the middle of a valley (owner, 2026-10-31): the valley
## floor lies VALLEY_Y below, mountains rise on both sides, and low stylized clouds fill it (owner's pick B), the clouds
## and the mountains both drawn like stage flats (owner, 2026-10-31: mountains as layered silhouettes, in place of the
## first terraces) (owner's reference, 2026-10-31): upright rings round the
## player, each a band whose top is a row of round puffs, nearer rings darker, farther ones paler. One colossal black
## slab (SLAB, 1:4:9) stands on the valley floor SLAB_DISTANCE away, down the valley SLAB_YAW off straight ahead, its
## broad face turned to the player: tiny beside something massive, not inside it or at its centre. Nothing within the
## notes' fly-in (Cuttable.FLY_DISTANCE, r 320 m) rises above y -5 in any direction (mountains stand only beyond it,
## clouds stay below), so it serves 90 and 360 degree maps too. Light only on the slab (AGENTS.md "Light", rule 5),
## drawn in its face's own shader (MonolithFace.gdshader; flush strip meshes would fight for depth this far out): its
## two vertical edges in the left and right lasers' colours, horizontal seams in the square bars' colour lit from the
## foot up as the show builds, a slit up the middle in the floor lights' colour; beams up its face from fixtures on a
## ledge LEDGE_HEIGHT up, clear above the clouds (the diagonal and waving lasers, LightRig; owner, 2026-10-31: moved up
## out of the clouds, the ledge's own light strip taken off). Behind it the horizon glows faintly (MonolithSky) so it
## stands as a silhouette, and its shadow falls down the valley toward the player (MonolithFloor.gdshader, on the valley
## and the pillar). The mountains (MonolithRidge.gdshader) are dark flat silhouettes rising out of the clouds, paler with
## distance, low down the valley so the slab and the way behind stay open. The clouds are opaque meshes whose outline is the puffs themselves (MonolithCloud.gdshader) with a
## thin see-through soft edge (MonolithCloudEdge.gdshader); what lies below them sinks in (monolith_cloud.gdshaderinc).
## Far edges stay sharp in the blockout: the soft-edge layer (AGENTS.md "Soft far edges") goes on the slab's outline
## once the look is agreed, never across its per-seam lights. BLOCKOUT: one box, a flat valley floor, a pillar, the
## cloud rings and the mountain rings. A tool script, so it shows in the editor too. Sizes in metres, untuned.

const FACE_SHADER := preload("res://game/env/MonolithFace.gdshader")
const FLOOR_SHADER := preload("res://game/env/MonolithFloor.gdshader")
const CLOUD_SHADER := preload("res://game/env/MonolithCloud.gdshader")
const RIDGE_SHADER := preload("res://game/env/MonolithRidge.gdshader")
const CLOUD_EDGE_SHADER := preload("res://game/env/MonolithCloudEdge.gdshader")
## the slab: its size (across, up, deep), its front face's distance from the player and its turn left of straight ahead
## (radians), which is also the way the valley runs; its top front corners stand about 950 m away, inside the camera's
## far plane (1024 m)
const SLAB := Vector3(360.0, 810.0, 90.0)
const SLAB_DISTANCE := 520.0
const SLAB_YAW := deg_to_rad(30.0)
## the ledge across the slab's face carrying the lasers' fixtures: metres up from its foot,
## above the clouds' puffs round the slab (up to about +60 m, CLOUD_RINGS)
const LEDGE_HEIGHT := 150.0
## the pillar the player stands on: from under the platform (PILLAR_TOP) down to the valley floor, PILLAR_RADIUS wide
const PILLAR_TOP := -TrackDeck.DECK_DEPTH
const PILLAR_RADIUS := 10.0
const PILLAR_SIDES := 6
## the valley floor's height, under the clouds, reaching VALLEY_RADIUS from the player (past the last ridge)
const VALLEY_Y := -80.0
const VALLEY_RADIUS := 980.0
## the mountains (owner, 2026-10-31: layered silhouette flats in place of the terraces): one upright ring per entry of
## RIDGE_RINGS (radius, the ridge's height down the valley, its height at the valley's sides), all beyond the notes'
## fly-in (r 320 m) and clear of the slab (the nearest inside its face, the others behind its back corners); nearer rings
## lower to the eye than farther ones so every layer shows. Between the valley's line and its sides the height follows
## |sin| of the angle off the valley to the power RIDGE_VALLEY_POWER (higher: a wider, flatter valley floor).
const RIDGE_RINGS := [Vector3(380.0, -30.0, 100.0), Vector3(650.0, -10.0, 220.0), Vector3(950.0, 10.0, 380.0)]
const RIDGE_VALLEY_POWER := 1.5
## the ridge line: a peak or a dip every RIDGE_SPACING metres (at 400 m out, wider farther away), peaks up and dips down
## by up to RIDGE_JAG of the ring's side height range
const RIDGE_SPACING := Vector2(30.0, 80.0)
const RIDGE_JAG := 0.2
## the mountains' soft edge: the stage's far blur width (AGENTS.md "Soft far edges", radians), not smoothed at the peaks
const RIDGE_BLUR := 0.007
const RIDGE_BLUR_SMOOTH := 1
## the mountains' fringe tone (MonolithCloudEdge.gdshader `tone`: a grey plus this many times the haze); the clouds'
## is CLOUD_EDGE_TONE (MonolithCloud.gdshader RIM_TONE: keep them matching)
const RIDGE_EDGE_TONE := Vector2(0.03, 0.6)
const CLOUD_EDGE_TONE := Vector2(0.12, 2.0)
## the clouds: one upright ring per entry of CLOUD_RINGS (radius, puffs' base height, their tallest rise above it), from
## the valley floor up to a row of round puffs CLOUD_PUFF_WIDTH wide (metres at 400 m out, wider farther away), one
## vertex per CLOUD_STEP metres along the top. Rings within the notes' fly-in (r 320 m) keep their puffs below y -5.
## (owner, 2026-10-31: clouds closer to the player, so the two nearest rings sit 80 and 150 m out, well below)
const CLOUD_RINGS := [Vector3(80.0, -55.0, 18.0), Vector3(150.0, -48.0, 22.0), Vector3(230.0, -43.0, 26.0),
	Vector3(340.0, -25.0, 34.0), Vector3(470.0, -12.0, 44.0), Vector3(760.0, 0.0, 60.0)]
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
	var ground := PlaneMesh.new()
	ground.size = Vector2.ONE * VALLEY_RADIUS * 2.0
	valley.mesh = ground
	valley.position = _around_player(Vector3(0.0, VALLEY_Y, 0.0))
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
		edge_material.set_shader_parameter(&"tone", CLOUD_EDGE_TONE)
		var cloud := MeshInstance3D.new()
		cloud.mesh = _cloud_ring(CLOUD_RINGS[i], random)
		cloud.position = _around_player(Vector3.ZERO)
		cloud.set_surface_override_material(0, material)
		cloud.set_surface_override_material(1, edge_material)
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cloud)
	for i in RIDGE_RINGS.size():
		var material := ShaderMaterial.new()
		material.shader = RIDGE_SHADER
		material.set_shader_parameter(&"depth_share", float(i) / (RIDGE_RINGS.size() - 1))
		_sink_into_clouds(material)
		var edge_material := ShaderMaterial.new()
		edge_material.shader = CLOUD_EDGE_SHADER
		edge_material.set_shader_parameter(&"depth_share", float(i) / (RIDGE_RINGS.size() - 1))
		edge_material.set_shader_parameter(&"tone", RIDGE_EDGE_TONE)
		var ridge := MeshInstance3D.new()
		ridge.mesh = _ridge_ring(RIDGE_RINGS[i], random)
		ridge.position = _around_player(Vector3.ZERO)
		ridge.set_surface_override_material(0, material)
		ridge.set_surface_override_material(1, edge_material)
		ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ridge)

## Gives `material` the cloud rings' radii and levels (the puffs' middle height), so what lies below them sinks in
## (monolith_cloud.gdshaderinc).
func _sink_into_clouds(material: ShaderMaterial) -> void:
	assert(CLOUD_RINGS.size() == 6, "monolith_cloud.gdshaderinc CLOUD_RING_COUNT is 6")
	var radii := PackedFloat32Array()
	var levels := PackedFloat32Array()
	for ring: Vector3 in CLOUD_RINGS:
		radii.append(ring.x)
		levels.append(ring.y + ring.z * 0.5)
	material.set_shader_parameter(&"cloud_radii", radii)
	material.set_shader_parameter(&"cloud_levels", levels)
	material.set_shader_parameter(&"cloud_centre", Vector2(0.0, Constants.PLAYER_Z))

## One ring of cloud (`ring`: radius, the puffs' base height, their tallest rise): a band from the valley floor up to a
## row of overlapping round puffs, UV.x measured from the tallest puffs' line for its shading (_upright_ring).
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
	var tops: Array[Vector2] = []
	var shade := PackedFloat32Array()
	var first := 0
	for i in samples + 1:
		var s := around * i / samples
		while first < puffs.size() - 1 and puffs[first].x + puffs[first].y < s:
			first += 1
		# the nearby puffs, and the ring's first and last ones once round, so the outline closes without a step
		var top := 0.0
		var near: Array[int] = [0, 1, 2, 3, puffs.size() - 1, puffs.size() - 2, puffs.size() - 3]
		near.append_array(range(first, mini(first + 4, puffs.size())))
		for p in near:
			for once_round in [-around, 0.0, around]:
				var d: float = s + once_round - puffs[p].x
				if absf(d) < puffs[p].y:
					top = maxf(top, sqrt(puffs[p].y * puffs[p].y - d * d))
		var swell := ring.y + CLOUD_SWELL * sin(s / ring.x * CLOUD_SWELLS)
		var height := swell + top / tallest * ring.z
		tops.append(Vector2(s, height))
		shade.append(swell + ring.z)
	return _upright_ring(ring.x, tops, shade, CLOUD_BLUR, CLOUD_BLUR_SMOOTH)

## One ring of mountains (`ring`: radius, the ridge's height down the valley, at its sides): a band from the valley floor
## up to a jagged ridge, low along the valley (the slab's line, both ways) and high at its sides (_upright_ring).
func _ridge_ring(ring: Vector3, random: RandomNumberGenerator) -> ArrayMesh:
	var around := TAU * ring.x
	var scale := ring.x / 400.0
	var jag := RIDGE_JAG * (ring.z - ring.y)
	# an even count of points, peaks and dips in turn, so the ridge closes round the ring without a step
	var spacing := (RIDGE_SPACING.x + RIDGE_SPACING.y) * 0.5 * scale
	var count := maxi(2, roundi(around / spacing / 2.0) * 2)
	var tops: Array[Vector2] = []
	var shade := PackedFloat32Array()
	for i in count:
		var s := (i + random.randf_range(-0.3, 0.3)) * around / count
		var side := pow(absf(sin(s / ring.x + SLAB_YAW)), RIDGE_VALLEY_POWER)
		var bump := random.randf_range(0.3, 1.0) * jag * (1.0 if i % 2 == 0 else -1.0)
		tops.append(Vector2(s, lerpf(ring.y, ring.z, side) + bump * side))
		shade.append(tops[i].y)
	tops.append(tops[0] + Vector2(around, 0.0))
	shade.append(shade[0])
	return _upright_ring(ring.x, tops, shade, RIDGE_BLUR, RIDGE_BLUR_SMOOTH)

## An upright ring of `radius` round the player whose outline is `tops` (metres along the ring, height; the last one is
## the first again, once round): a band from the valley floor up to the outline (surface 0; UV.y holds the metres down
## from the outline, UV.x the metres down from `shade`'s height at each top) and its soft edge, a fringe `blur` (an
## angle) wide out from the outline, its direction smoothed over `smooth` tops either side (surface 1; UV.x 0 on the
## outline to 1 at its rim).
func _upright_ring(radius: float, tops: Array[Vector2], shade: PackedFloat32Array, blur: float, smooth: int) -> ArrayMesh:
	var around := TAU * radius
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in tops.size():
		var out := _ring_point(radius, tops[i].x)
		vertices.append(out + Vector3(0.0, tops[i].y, 0.0))
		uvs.append(Vector2(shade[i] - tops[i].y, 0.0))
		vertices.append(out + Vector3(0.0, VALLEY_Y, 0.0))
		uvs.append(Vector2(shade[i] - VALLEY_Y, tops[i].y - VALLEY_Y))
	var indices := PackedInt32Array()
	for i in tops.size() - 1:
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
	var width := blur * radius
	var fringe := PackedVector3Array()
	var fringe_uvs := PackedVector2Array()
	for i in tops.size():
		# the neighbours round the closed ring (the last sample is the first again)
		var before := _round_ring(tops, i - smooth, around)
		var after := _round_ring(tops, i + smooth, around)
		var tangent := (after - before).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var angle := tops[i].x / radius
		var along_dir := Vector3(cos(angle), 0.0, sin(angle))
		var top := _ring_point(radius, tops[i].x) + Vector3(0.0, tops[i].y, 0.0)
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

## The outline sample `i` of a closed ring of `tops` (the last one is the first again), counted on round the ring
## past either end, with its place along the ring kept continuous (`around`: the ring's length).
static func _round_ring(tops: Array[Vector2], i: int, around: float) -> Vector2:
	var count := tops.size() - 1
	var turns := floori(float(i) / count)
	return tops[i - turns * count] + Vector2(turns * around, 0.0)

## The point on a ring of `radius` round the player, `along` metres round it from straight ahead (-z), at y 0.
static func _ring_point(radius: float, along: float) -> Vector3:
	var angle := along / radius
	return Vector3(sin(angle), 0.0, -cos(angle)) * radius

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
