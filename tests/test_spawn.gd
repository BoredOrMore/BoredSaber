extends Node
# Headless checks for spawning notes, bombs, walls and arcs on the track (Playing.spawn_due's entities): where each one
# starts for its beat, how it moves, and that one reused from its pool starts where a fresh one would (an arc reused from
# the pool once started where the previous arc had flown to: Arc.spawn didn't reset its transform).
# Run: godot --headless --path . res://tests/test_spawn.tscn

const EPS := 1e-4

var failures := 0
var track: Node3D

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

func near(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < EPS

func near_t(a: Transform3D, b: Transform3D) -> bool:
	return near(a.origin, b.origin) and near(a.basis.x, b.basis.x) and near(a.basis.y, b.basis.y) \
		and near(a.basis.z, b.basis.z)

## A pool of `path` whose nodes go under the track, as the game's pools do (BeepSaber_Game._on_ScenePool_new_scene_instanced).
func pool_of(path: String) -> ScenePool:
	var pool := ScenePool.new()
	pool.scene = load(path) as PackedScene
	pool.new_scene_instanced.connect(func(obj: Node3D, _presizing: bool) -> void: track.add_child(obj))
	add_child(pool)
	return pool

## Where a note or bomb of lane `index`, row `layer`, beat `beat` sits at `current_beat` with no lane rotation.
func note_place(index: float, layer: float, beat: float, current_beat: float) -> Vector3:
	return Vector3(Settings.LANE_DISTANCE_X * index + Settings.LANE_ZERO_X, Constants.layer_y(layer),
		-(beat - current_beat) * Map.beat_distance)

func _ready() -> void:
	var saved_flip := Settings.flip
	var saved_gradual := Settings.gradual_rotation
	var saved_paused := Scoreboard.paused
	var saved_info := Map.current_info
	var saved_difficulty := Map.current_difficulty
	var saved_distance := Map.beat_distance
	Settings.flip = 0
	Settings.gradual_rotation = 0.0
	Scoreboard.paused = false
	Map.beat_distance = Constants.BEAT_DISTANCE
	var difficulty := DifficultyInfo.new("Expert", 7, "Expert.dat", 16.0, 0.0, {}, "", "Standard")
	Map.current_difficulty = difficulty
	Map.current_info = MapInfo.new("2.0.0", "Spawn test", "", "", "", 120.0, 0.0, 0.0, "", "", "", 0.0, {}, "",
		[difficulty] as Array[DifficultyInfo])
	track = Node3D.new()
	track.name = "Track"
	add_child(track)

	var speed := Map.beat_distance * Map.beats_per_second()
	check(speed > 0.0, "speed = beat_distance * beats_per_second is positive (%.3f m/s)" % speed)

	test_notes(speed)
	test_bombs(speed)
	test_walls(speed)
	test_arcs(speed)

	Settings.flip = saved_flip
	Settings.gradual_rotation = saved_gradual
	Scoreboard.paused = saved_paused
	Map.current_info = saved_info
	Map.current_difficulty = saved_difficulty
	Map.beat_distance = saved_distance
	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func test_notes(speed: float) -> void:
	var pool := pool_of("res://game/notes/BeepCube/BeepCube.tscn")
	var fresh_pool := pool_of("res://game/notes/BeepCube/BeepCube.tscn")
	var cube := pool.acquire() as BeepCube
	cube.spawn(ColorNoteInfo.new(8.0, 2, 1, 1, 0.0, 0.0), 2.0)
	check(near(cube.position, note_place(2, 1, 8.0, 2.0)),
		"note beat 8 at beat 2, lane 2 row 1: %s, expected %s" % [cube.position, note_place(2, 1, 8.0, 2.0)])
	cube.spawn(ColorNoteInfo.new(5.0, 0, 2, 0, 0.0, 0.0), 5.0)
	check(near(cube.position, note_place(0, 2, 5.0, 5.0)), "note on its beat sits at z 0, lane 0 row 2: %s" % cube.position)

	# movement
	cube.spawn(ColorNoteInfo.new(8.0, 1, 0, 0, 0.0, 0.0), 0.0)
	var z0 := cube.position.z
	cube._physics_process(0.25)
	cube._physics_process(0.25)
	check(absf(cube.position.z - z0 - speed * 0.5) < EPS, "note moves speed * t in z: %.4f, expected %.4f" % [
		cube.position.z - z0, speed * 0.5])
	check(near(Vector3(cube.position.x, cube.position.y, 0), Vector3(note_place(1, 0, 0, 0).x, note_place(1, 0, 0, 0).y, 0)),
		"note keeps its lane and row while moving")

	# the jump (Cuttable.start_jump): at the hit plane the note is at its row, full size, in its final direction
	cube.spawn(ColorNoteInfo.new(5.0, 2, 2, 1, PI * 0.5, 0.0), 5.0)
	check(near_t(cube.mi.transform, Transform3D.IDENTITY),
		"a note at the hit plane has jumped to its row, full size, turned (visual %s)" % cube.mi.transform)
	# where it appears it starts below its row, not yet turned
	cube.spawn(ColorNoteInfo.new(2.0 + Map.half_jump_beats, 2, 1, 1, PI * 0.5, 0.0), 2.0)
	var start_drop := (cube.mi.global_position - cube.global_position).y
	check(start_drop < -0.1, "a note where it appears starts below its row (%.2f m)" % start_drop)
	check(absf(cube.mi.global_basis.x.normalized().dot(Vector3.RIGHT) - 1.0) < 0.01,
		"a note where it appears hasn't turned yet (visual x %s)" % cube.mi.global_basis.x)

	# reuse: a note spawned on a rotated lane with a cut angle, flown, released, spawned again
	cube.spawn(ColorNoteInfo.new(10.0, 3, 2, 1, PI * 0.5, 45.0), 4.0)
	cube._physics_process(0.3)
	cube.hide_cube()
	cube.release()
	var again := pool.acquire() as BeepCube
	check(again == cube, "the pool hands back the released note")
	var info := ColorNoteInfo.new(12.0, 1, 1, 0, 0.0, 0.0)
	again.spawn(info, 6.0)
	var fresh := fresh_pool.acquire() as BeepCube
	fresh.spawn(info, 6.0)
	check(near(again.position, note_place(1, 1, 12.0, 6.0)), "reused note sits at its new place: %s, expected %s" % [
		again.position, note_place(1, 1, 12.0, 6.0)])
	check(near_t(again.transform, fresh.transform), "reused note's transform matches a fresh one's: %s vs %s" % [
		again.transform, fresh.transform])
	check(near(again._forward, fresh._forward), "reused note moves the way a fresh one does: %s vs %s" % [
		again._forward, fresh._forward])

func test_bombs(speed: float) -> void:
	var pool := pool_of("res://game/notes/Bomb/Bomb.tscn")
	var fresh_pool := pool_of("res://game/notes/Bomb/Bomb.tscn")
	var bomb := pool.acquire() as Bomb
	bomb.spawn(BombInfo.new(6.0, 3, 0, 0.0), 1.5)
	check(near(bomb.position, note_place(3, 0, 6.0, 1.5)),
		"bomb beat 6 at beat 1.5, lane 3 row 0: %s, expected %s" % [bomb.position, note_place(3, 0, 6.0, 1.5)])

	var z0 := bomb.position.z
	bomb._physics_process(0.4)
	check(absf(bomb.position.z - z0 - speed * 0.4) < EPS, "bomb moves speed * t in z: %.4f, expected %.4f" % [
		bomb.position.z - z0, speed * 0.4])

	bomb.spawn(BombInfo.new(9.0, 0, 2, -30.0), 3.0)
	bomb._physics_process(0.3)
	bomb.hide_pooled()
	bomb.release()
	var again := pool.acquire() as Bomb
	check(again == bomb, "the pool hands back the released bomb")
	var info := BombInfo.new(11.0, 2, 1, 0.0)
	again.spawn(info, 7.0)
	var fresh := fresh_pool.acquire() as Bomb
	fresh.spawn(info, 7.0)
	check(near(again.position, note_place(2, 1, 11.0, 7.0)), "reused bomb sits at its new place: %s" % again.position)
	check(near_t(again.transform, fresh.transform), "reused bomb's transform matches a fresh one's: %s vs %s" % [
		again.transform, fresh.transform])

## Checks a wall of `info` spawned at `current_beat`: its front face on the beat, its back `duration` beats behind, its
## lanes and layers across and up (its collision box, which keeps the whole height whatever its look).
func check_wall(wall: Wall, info: ObstacleInfo, current_beat: float, what: String) -> void:
	var shape := (wall.get_node("WallMeshOrientation/WallArea/CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	var size := shape.size
	var p := wall.position
	var left := Settings.LANE_DISTANCE_X * info.line_index + Settings.LANE_ZERO_X - 0.5 * Settings.LANE_DISTANCE_X
	var bottom := Constants.wall_y(info.line_layer)
	check(absf((p.z + 0.5 * size.z) - (-(info.beat - current_beat) * Map.beat_distance)) < EPS,
		"%s: front face at z = -(beat - current) * beat_distance (%.4f)" % [what, p.z + 0.5 * size.z])
	check(absf(size.z - info.duration * Map.beat_distance) < EPS, "%s: depth = duration * beat_distance (%.4f)" % [
		what, size.z])
	check(absf(size.x - info.width * Settings.LANE_DISTANCE_X) < EPS, "%s: width = lanes * LANE_DISTANCE_X (%.4f)" % [
		what, size.x])
	check(absf((p.x - 0.5 * size.x) - left) < EPS, "%s: left edge on lane %d's left edge (%.4f, expected %.4f)" % [
		what, int(info.line_index), p.x - 0.5 * size.x, left])
	check(absf((p.y - 0.5 * size.y) - bottom) < EPS and absf((p.y + 0.5 * size.y)
		- Constants.wall_y(info.line_layer + info.height)) < EPS, "%s: spans wall_y(layer) to wall_y(layer + height)" % what)

func test_walls(speed: float) -> void:
	var pool := pool_of("res://game/notes/Wall/Wall.tscn")
	var fresh_pool := pool_of("res://game/notes/Wall/Wall.tscn")
	var wall := pool.acquire() as Wall
	var info := ObstacleInfo.new(10.0, 2.0, 1, 0, 2, 5, 0.0)
	wall.spawn(info, 3.0)
	check_wall(wall, info, 3.0, "wall beat 10 for 2 beats, lanes 1-2, full height, at beat 3")
	var crouch := ObstacleInfo.new(6.0, 1.0, 0, 2, 4, 3, 0.0)
	wall.spawn(crouch, 6.0)
	check_wall(wall, crouch, 6.0, "crouch wall on its beat, all lanes")

	wall.spawn(info, 0.0)
	var z0 := wall.position.z
	wall._physics_process(0.5)
	check(absf(wall.position.z - z0 - speed * 0.5) < EPS, "wall moves speed * t in z: %.4f, expected %.4f" % [
		wall.position.z - z0, speed * 0.5])

	wall.spawn(ObstacleInfo.new(8.0, 4.0, 3, 0, 1, 5, 60.0), 2.0)
	wall._physics_process(0.3)
	wall.hide_pooled()
	wall.release()
	var again := pool.acquire() as Wall
	check(again == wall, "the pool hands back the released wall")
	var next := ObstacleInfo.new(14.0, 1.5, 2, 0, 1, 5, 0.0)
	again.spawn(next, 9.0)
	check_wall(again, next, 9.0, "reused wall")
	var fresh := fresh_pool.acquire() as Wall
	fresh.spawn(next, 9.0)
	check(near_t(again.transform, fresh.transform), "reused wall's transform matches a fresh one's: %s vs %s" % [
		again.transform, fresh.transform])
	var again_mesh := again.get_node("WallMeshOrientation/WallMesh") as MeshInstance3D
	var fresh_mesh := fresh.get_node("WallMeshOrientation/WallMesh") as MeshInstance3D
	check(near(again_mesh.position, fresh_mesh.position) and near(again_mesh.scale, fresh_mesh.scale),
		"reused wall's mesh matches a fresh one's (position %s vs %s, scale %s vs %s)" % [again_mesh.position,
		fresh_mesh.position, again_mesh.scale, fresh_mesh.scale])

## Where the arc's curve point `i` is on the track (its node's and its Path3D's transforms applied).
func arc_point(arc: Arc, i: int) -> Vector3:
	var path := arc.get_node("Path3D") as Path3D
	return arc.transform * (path.transform * arc.arc_info.curve.get_point_position(i))

func test_arcs(speed: float) -> void:
	var pool := pool_of("res://game/notes/Arc/Arc.tscn")
	var fresh_pool := pool_of("res://game/notes/Arc/Arc.tscn")
	var arc := pool.acquire() as Arc
	var info := ArcInfo.new(1, 8.0, 0, 0, 0.0, 1.0, 10.0, 3, 2, 0.0, 1.0, 1, 0.0, 0.0)
	arc.spawn(info, 2.0)
	var last := info.curve.point_count - 1
	check(near(arc_point(arc, 0), note_place(0, 0, 8.0, 2.0)), "arc starts at its head note: %s, expected %s" % [
		arc_point(arc, 0), note_place(0, 0, 8.0, 2.0)])
	check(near(arc_point(arc, last), note_place(3, 2, 10.0, 2.0)), "arc ends at its tail note: %s, expected %s" % [
		arc_point(arc, last), note_place(3, 2, 10.0, 2.0)])
	check(near(info.head_pos, note_place(0, 0, 8.0, 0.0)) and near(info.tail_pos, note_place(3, 2, 10.0, 0.0)),
		"ArcInfo head_pos/tail_pos are the head and tail notes' places at beat 0")

	var z0 := arc_point(arc, 0).z
	arc._process(0.25)
	arc._process(0.25)
	check(absf(arc_point(arc, 0).z - z0 - speed * 0.5) < EPS, "arc moves speed * t in z: %.4f, expected %.4f" % [
		arc_point(arc, 0).z - z0, speed * 0.5])

	# reuse: an arc on a rotated lane, flown, released, spawned again (the bug: it started where the last one got to)
	arc.spawn(ArcInfo.new(0, 4.0, 1, 1, 0.0, 1.0, 6.0, 2, 1, 0.0, 1.0, 0, 30.0, 30.0), 1.0)
	arc._process(0.4)
	arc.hide_pooled()
	arc.release()
	var again := pool.acquire() as Arc
	check(again == arc, "the pool hands back the released arc")
	var next := ArcInfo.new(0, 12.0, 2, 1, 0.0, 1.0, 13.0, 1, 0, 0.0, 1.0, 0, 0.0, 0.0)
	again.spawn(next, 7.0)
	var next_last := next.curve.point_count - 1
	check(near(arc_point(again, 0), note_place(2, 1, 12.0, 7.0)), "reused arc starts at its head note: %s, expected %s" % [
		arc_point(again, 0), note_place(2, 1, 12.0, 7.0)])
	check(near(arc_point(again, next_last), note_place(1, 0, 13.0, 7.0)),
		"reused arc ends at its tail note: %s, expected %s" % [arc_point(again, next_last), note_place(1, 0, 13.0, 7.0)])
	var fresh := fresh_pool.acquire() as Arc
	fresh.spawn(next, 7.0)
	check(near_t(again.transform, fresh.transform), "reused arc's transform matches a fresh one's: %s vs %s" % [
		again.transform, fresh.transform])
	check(near((again.get_node("Path3D") as Path3D).position, (fresh.get_node("Path3D") as Path3D).position),
		"reused arc's path matches a fresh one's")
	check(absf(again.despawn_z - fresh.despawn_z) < EPS, "reused arc despawns where a fresh one does")
