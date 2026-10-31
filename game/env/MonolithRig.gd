@tool
class_name MonolithRig
extends Node3D
## Monolith (doc/world/GAME_BIBLE.md "Monolith"; owner, 2026-10-31): standing before something that was here before you.
## Abstract, no story. The player stands on a tall pillar in the middle of a valley (owner, 2026-10-31): the valley
## floor lies VALLEY_Y below, mountains rise on both sides, and low stylized clouds fill it (owner's pick B), both 3D
## models with no two alike (owner, 2026-10-31, in place of the flat rings): cumulus banks after the owner's reference,
## drifting slowly round the player, nearer bands darker, farther ones paler, and low-poly peaks. One colossal black
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
## and the pillar). The mountains (MonolithRidge.gdshader) are dark faceted peaks rising out of the clouds, paler with
## distance, none down the valley's line so the slab and the way behind stay open. The clouds (MonolithCloud.gdshader)
## are opaque banks with bright tops and lit upper outlines; what lies below them sinks in (monolith_cloud.gdshaderinc).
## Far edges stay sharp in the blockout: the soft-edge layer (AGENTS.md "Soft far edges") goes on the slab's outline
## once the look is agreed, never across its per-seam lights. BLOCKOUT: one box, a flat valley floor, a pillar, the
## cloud bands and the mountains. A tool script, so it shows in the editor too. Sizes in metres, untuned.

const FACE_SHADER := preload("res://game/env/MonolithFace.gdshader")
const FLOOR_SHADER := preload("res://game/env/MonolithFloor.gdshader")
const CLOUD_SHADER := preload("res://game/env/MonolithCloud.gdshader")
const RIDGE_SHADER := preload("res://game/env/MonolithRidge.gdshader")
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
## the mountains (owner, 2026-10-31: 3D models in place of the flat silhouettes, no two alike): low-poly peaks
## (tools/models/monolith_mountain.py, MOUNTAIN_MODELS) stood round one ring per entry of RIDGE_RINGS (radius, the
## peaks' height down the valley, their height at the valley's sides), all beyond the notes' fly-in (r 320 m) and clear
## of the slab (the nearest inside its face, the others behind its back corners); nearer rings lower to the eye than
## farther ones so every layer shows. Between the valley's line and its sides the height follows |sin| of the angle off
## the valley to the power RIDGE_VALLEY_POWER (higher: a wider, flatter valley floor). Each mountain is scaled to that
## height times MOUNTAIN_HEIGHT_JITTER (min, max) and turned to face the player; neighbours overlap by MOUNTAIN_OVERLAP
## of their length; none is placed where the height is under MOUNTAIN_MIN_HEIGHT above the valley floor (the valley's
## line stays open).
const RIDGE_RINGS := [Vector3(380.0, -30.0, 100.0), Vector3(650.0, -10.0, 220.0), Vector3(950.0, 10.0, 380.0)]
const RIDGE_VALLEY_POWER := 1.5
const MOUNTAIN_MODELS: Array[PackedScene] = [preload("res://game/models/monolith_mountain_0.glb"),
	preload("res://game/models/monolith_mountain_1.glb"), preload("res://game/models/monolith_mountain_2.glb"),
	preload("res://game/models/monolith_mountain_3.glb"), preload("res://game/models/monolith_mountain_4.glb"),
	preload("res://game/models/monolith_mountain_5.glb")]
const MOUNTAIN_HEIGHT_JITTER := Vector2(0.8, 1.15)
const MOUNTAIN_OVERLAP := 0.15
const MOUNTAIN_MIN_HEIGHT := 80.0
## the clouds (owner, 2026-10-31: 3D models in place of the flat rings, no two alike, drifting slowly): cumulus banks
## (tools/models/monolith_cloud.py, CLOUD_MODELS) laid round one band per entry of CLOUD_RINGS (radius, the banks' base
## height, their tallest rise above it) in CLOUD_ROWS rows spread CLOUD_SPREAD of the gap to the next band in and out,
## so the bands join into one cloud sea. Each bank's top reaches the band's rise times CLOUD_HEIGHT_JITTER (min, max)
## above its base, its foot sunk CLOUD_SINK of the rise below the base (hidden among the others), it is stretched
## CLOUD_WIDEN times wider than tall (flatter decks, still puffy) and turned at random; neighbours overlap by
## CLOUD_OVERLAP of their length. Bands within the notes' fly-in (r 320 m) keep their tops below y -5.
## (owner, 2026-10-31: clouds closer to the player, so the two nearest bands sit 80 and 150 m out, well below)
const CLOUD_RINGS := [Vector3(80.0, -55.0, 18.0), Vector3(150.0, -48.0, 22.0), Vector3(230.0, -43.0, 26.0),
	Vector3(340.0, -25.0, 34.0), Vector3(470.0, -12.0, 44.0), Vector3(760.0, 0.0, 60.0)]
const CLOUD_MODELS: Array[PackedScene] = [preload("res://game/models/monolith_cloud_0.glb"),
	preload("res://game/models/monolith_cloud_1.glb"), preload("res://game/models/monolith_cloud_2.glb"),
	preload("res://game/models/monolith_cloud_3.glb"), preload("res://game/models/monolith_cloud_4.glb"),
	preload("res://game/models/monolith_cloud_5.glb")]
const CLOUD_ROWS := 2
const CLOUD_HEIGHT_JITTER := Vector2(0.7, 1.0)
const CLOUD_SPREAD := 0.25
const CLOUD_SINK := 0.4
const CLOUD_WIDEN := 1.3
const CLOUD_OVERLAP := 0.1
## each band drifts round the player at CLOUD_DRIFT metres a second (all one way, like one wind), CLOUD_DRIFT_SPREAD
## (min, max) times that per band so the layers slide past each other
const CLOUD_DRIFT := 1.5
const CLOUD_DRIFT_SPREAD := Vector2(0.7, 1.3)
## the notes' fly-in rule (owner, 2026-10-31): within Cuttable.FLY_DISTANCE plus NOTE_PATH_MARGIN of the player no
## cloud top rises above NOTE_PATH_FLOOR and no mountain stands
const NOTE_PATH_MARGIN := 20.0
const NOTE_PATH_FLOOR := -6.0
## the random banks and mountains come from this seed, so every load looks the same
const CLOUD_SEED := 31
## each cloud band and the mountains are cut into this many slices round the player (one mesh and draw call each), so
## the slices out of view are skipped (frustum culling)
const SECTORS := 4

## the slab face's material (light colours, build-up and slit set each frame by EventDriver) and the floor's
var face_material: ShaderMaterial
var floor_material: ShaderMaterial
## the cloud bands (CLOUD_RINGS order) and how fast each turns round the player (radians a second, CLOUD_DRIFT)
var _cloud_bands: Array[Node3D] = []
var _cloud_spins: Array[float] = []

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
	var cloud_meshes := _model_meshes(CLOUD_MODELS)
	for i in CLOUD_RINGS.size():
		var material := ShaderMaterial.new()
		material.shader = CLOUD_SHADER
		material.set_shader_parameter(&"depth_share", float(i) / (CLOUD_RINGS.size() - 1))
		var band := Node3D.new()
		band.position = _around_player(Vector3.ZERO)
		add_child(band)
		_add_sectors(band, _cloud_band(i, cloud_meshes, random), material)
		_cloud_bands.append(band)
		_cloud_spins.append(CLOUD_DRIFT * random.randf_range(CLOUD_DRIFT_SPREAD.x, CLOUD_DRIFT_SPREAD.y) / CLOUD_RINGS[i].x)
	var mountain_material := ShaderMaterial.new()
	mountain_material.shader = RIDGE_SHADER
	_sink_into_clouds(mountain_material)
	var mountains := Node3D.new()
	mountains.position = _around_player(Vector3.ZERO)
	add_child(mountains)
	_add_sectors(mountains, _mountain_rings(_model_meshes(MOUNTAIN_MODELS), random), mountain_material)

## Turns the cloud bands round the player (CLOUD_DRIFT), each at its own pace.
func _process(delta: float) -> void:
	for i in _cloud_bands.size():
		_cloud_bands[i].rotate_y(-_cloud_spins[i] * delta)

## Gives `material` the cloud bands' radii and levels (the puffs' middle height), so what lies below them sinks in
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

## The first mesh in each of `models` (the .glb scenes): [its arrays for merging (_merged), its top, its length (x),
## how far it reaches from its origin toward +z or to either side, whichever is more].
static func _model_meshes(models: Array[PackedScene]) -> Array[Array]:
	var meshes: Array[Array] = []
	for model in models:
		var mesh := LaserFixtures._model_mesh(model)
		var arrays := mesh.surface_get_arrays(0)
		var top := 0.0
		for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			top = maxf(top, v.y)
		var aabb := mesh.get_aabb()
		meshes.append([arrays, top, aabb.size.x, maxf(aabb.end.z, maxf(aabb.size.x, aabb.size.z) * 0.5)])
	return meshes

## Cloud band `index` of CLOUD_RINGS as SECTORS meshes round the player (_merged): banks picked from `meshes`, each
## scaled to the band's rise, turned at random and nudged in or out, overlapping its neighbours. UV.x of each vertex is
## its metres below its bank's top, UV.y the band's depth share (MonolithCloud.gdshader).
func _cloud_band(index: int, meshes: Array[Array], random: RandomNumberGenerator) -> Array[ArrayMesh]:
	var ring: Vector3 = CLOUD_RINGS[index]
	var gap: float = (CLOUD_RINGS[mini(index + 1, CLOUD_RINGS.size() - 1)].x - CLOUD_RINGS[maxi(index - 1, 0)].x) * 0.5
	var places: Array[Array] = []
	for row in CLOUD_ROWS:
		var radius := ring.x + (float(row) / maxi(CLOUD_ROWS - 1, 1) * 2.0 - 1.0) * CLOUD_SPREAD * gap
		var around := TAU * radius
		var along := random.randf_range(0.0, 50.0)
		while along < around:
			var pick: Array = meshes[random.randi_range(0, meshes.size() - 1)]
			var rise := ring.z * random.randf_range(CLOUD_HEIGHT_JITTER.x, CLOUD_HEIGHT_JITTER.y)
			var width_scale: float = (rise + ring.z * CLOUD_SINK) / pick[1] * CLOUD_WIDEN
			# a bank reaching into the notes' fly-in keeps its top below NOTE_PATH_FLOOR there
			if radius - pick[3] * width_scale < Cuttable.FLY_DISTANCE + NOTE_PATH_MARGIN:
				rise = minf(rise, NOTE_PATH_FLOOR - ring.y)
			var height_scale: float = (rise + ring.z * CLOUD_SINK) / pick[1]
			var length: float = pick[2] * width_scale
			var angle := (along + length * 0.5) / radius
			var origin := Vector3(sin(angle), 0.0, -cos(angle)) * radius + Vector3(0.0, ring.y - ring.z * CLOUD_SINK, 0.0)
			if _touches_slab(origin, pick[3] * width_scale):
				along += length * (1.0 - CLOUD_OVERLAP)
				continue
			var basis := Basis(Vector3.UP, random.randf_range(0.0, TAU)) * Basis.from_scale(
					Vector3(width_scale, height_scale, width_scale))
			places.append([pick, Transform3D(basis, origin), height_scale, float(index) / (CLOUD_RINGS.size() - 1),
					angle])
			along += length * (1.0 - CLOUD_OVERLAP)
	return _merged(places)

## All of RIDGE_RINGS' mountains as SECTORS meshes round the player (_merged): peaks picked from `meshes`, each scaled
## to its ring's height there (low along the valley, high at its sides), turned to face the player, overlapping its
## neighbours. UV.x of each vertex is its metres below its mountain's top, UV.y the ring's depth share
## (MonolithRidge.gdshader).
func _mountain_rings(meshes: Array[Array], random: RandomNumberGenerator) -> Array[ArrayMesh]:
	var places: Array[Array] = []
	for r in RIDGE_RINGS.size():
		var ring: Vector3 = RIDGE_RINGS[r]
		var around := TAU * ring.x
		var along := random.randf_range(0.0, 100.0)
		while along < around:
			var pick: Array = meshes[random.randi_range(0, meshes.size() - 1)]
			var angle := along / ring.x
			var side := pow(absf(sin(angle + SLAB_YAW)), RIDGE_VALLEY_POWER)
			var height := (lerpf(ring.y, ring.z, side) - VALLEY_Y) * random.randf_range(MOUNTAIN_HEIGHT_JITTER.x,
					MOUNTAIN_HEIGHT_JITTER.y)
			var scale: float = height / pick[1]
			var length: float = pick[2] * scale
			if height >= MOUNTAIN_MIN_HEIGHT:
				var centre := angle + length * 0.5 / ring.x
				# its front stays out of the notes' fly-in
				var radius := maxf(ring.x, Cuttable.FLY_DISTANCE + NOTE_PATH_MARGIN + pick[3] * scale)
				var origin := Vector3(sin(centre), 0.0, -cos(centre)) * radius + Vector3(0.0, VALLEY_Y, 0.0)
				if _touches_slab(origin, pick[3] * scale):
					along += length * (1.0 - MOUNTAIN_OVERLAP)
					continue
				var basis := Basis(Vector3.UP, -centre).scaled(Vector3.ONE * scale)
				places.append([pick, Transform3D(basis, origin), scale, float(r) / (RIDGE_RINGS.size() - 1), centre])
			along += maxf(length, MOUNTAIN_MIN_HEIGHT) * (1.0 - MOUNTAIN_OVERLAP)
	return _merged(places)

## One mesh per slice round the player (SECTORS) of every model in `places` ([model arrays, its top, its length],
## transform, its height scale, depth share, angle round the player from straight ahead) at its place, keeping its normals and
## vertex colours; UV.x holds each vertex's metres below its model's top and UV.y the depth share. A slice with no
## models (the valley's open line) gets no mesh.
static func _merged(places: Array[Array]) -> Array[ArrayMesh]:
	var slices: Array[Array] = []
	for k in SECTORS:
		slices.append([])
	for place in places:
		slices[posmod(floori(place[4] / TAU * SECTORS), SECTORS)].append(place)
	var meshes: Array[ArrayMesh] = []
	for slice in slices:
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var colors := PackedColorArray()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		for p: Array in slice:
			var model: Array = p[0]
			var arrays: Array = model[0]
			var at: Transform3D = p[1]
			var scale: float = p[2]
			var share: float = p[3]
			var first := vertices.size()
			# normals take the inverse transpose, so they stay square to a surface stretched more one way than another
			var normal_basis := at.basis.inverse().transposed()
			for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				vertices.append(at * v)
				uvs.append(Vector2((model[1] - v.y) * scale, share))
			for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
				normals.append((normal_basis * n).normalized())
			colors.append_array(arrays[Mesh.ARRAY_COLOR])
			for i: int in arrays[Mesh.ARRAY_INDEX]:
				indices.append(first + i)
		if vertices.is_empty():
			continue
		var merged := []
		merged.resize(Mesh.ARRAY_MAX)
		merged[Mesh.ARRAY_VERTEX] = vertices
		merged[Mesh.ARRAY_NORMAL] = normals
		merged[Mesh.ARRAY_COLOR] = colors
		merged[Mesh.ARRAY_TEX_UV] = uvs
		merged[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged)
		meshes.append(mesh)
	return meshes

## Whether something standing at `origin` (round the player's standing point) and reaching `reach` metres from it would
## touch the slab (no cloud crosses it and no mountain touches it: owner, 2026-10-31).
static func _touches_slab(origin: Vector3, reach: float) -> bool:
	var local := slab_place().affine_inverse() * _around_player(origin)
	return absf(local.x) < SLAB.x * 0.5 + reach and absf(local.z) < SLAB.z * 0.5 + reach

## Adds one MeshInstance3D per mesh in `meshes` under `parent`, drawn with `material`.
func _add_sectors(parent: Node3D, meshes: Array[ArrayMesh], material: ShaderMaterial) -> void:
	for mesh in meshes:
		var sector := MeshInstance3D.new()
		sector.mesh = mesh
		sector.material_override = material
		sector.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(sector)

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
