extends Node
## Finds the moment each map in the game's Songs folder has the most objects alive at once, by the game's own spawn
## rules: an object spawns Map.half_jump_beats before its beat (GameStatePlaying.spawn_due) and leaves when it passes
## Constants.MISS_Z (Cuttable, Wall, Arc), the track sitting at Constants.HIT_PLANE_Z. Counts as if nothing were cut
## (the most there can be). Picks the busiest moment by triangles and, separately, by notes. Also prints the triangles of each object's mesh. Prints the top maps by total objects.
## Run: godot --headless --path . res://tools/capture/peak_objects.tscn

const STEP := 0.05 # beats between samples
## triangles per object (the MESH lines this prints; a bomb is two icospheres, an arc its mesh's own count, averaged)
const TRIS := {"notes": 300, "bombs": 272, "walls": 12, "links": 56}
var _arc_tris: Array[int] = []

func _ready() -> void:
	_meshes()
	var rows: Array = []
	var songs := Constants.APPDATA_PATH + "Songs/"
	for folder in DirAccess.get_directories_at(songs):
		var info := Map.load_map_info(songs + folder + "/")
		if info == null:
			continue
		for d: DifficultyInfo in info.difficulty_beatmaps:
			var data := Utils.binary_to_json(Utils.read_binary_file(info.filepath, d.beatmap_filename))
			if data.is_empty() or not Map.load_beatmap(info, d, data):
				continue
			rows.append(_peak(info, d))
	var arc := 0
	for n in _arc_tris: arc += n
	print("ARC tris: %d arcs, mean %.0f, max %d" % [_arc_tris.size(), float(arc) / maxi(_arc_tris.size(), 1), _arc_tris.max() if _arc_tris.size() else 0])
	for key in ["tris", "notes"]:
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a[key].tris > b[key].tris if key == "tris" else a[key].notes > b[key].notes)
		for r: Dictionary in rows.slice(0, 3):
			var b: Dictionary = r[key]
			print("BY %s: %s | %s | %d tris, %d objects (notes %d, bombs %d, walls %d, chain links %d, arcs %d) at %.1f s, NJS %.1f" % [key, r.song, r.diff, b.tris, b.total, b.notes, b.bombs, b.walls, b.links, b.arcs, b.seconds, r.njs])
	print("MAPS scanned: %d" % rows.size())
	get_tree().quit()

## Spans [spawn, leave] in beats of every object in the loaded map, by kind, then the busiest sample.
func _peak(info: MapInfo, d: DifficultyInfo) -> Dictionary:
	var lead := Map.half_jump_beats
	var tail := (Constants.MISS_Z - Constants.HIT_PLANE_Z) / Map.beat_distance
	var spans := {"notes": [], "bombs": [], "walls": [], "links": [], "arcs": []}
	for n in Map.note_stack: spans.notes.append(Vector2(n.beat - lead, n.beat + tail))
	for b in Map.bomb_stack: spans.bombs.append(Vector2(b.beat - lead, b.beat + tail))
	for w in Map.obstacle_stack: spans.walls.append(Vector2(w.beat - lead, w.beat + w.duration + tail))
	var arc_tris := {}
	for a in Map.arc_stack:
		spans.arcs.append(Vector2(a.head_beat - lead, a.tail_beat + tail))
		var tris: int = (a.mesh_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		arc_tris[spans.arcs.size() - 1] = tris
		_arc_tris.append(tris)
	for c in Map.chain_stack:
		# the head is a note already; the links spawn with it and each leaves at its own beat
		for i in range(1, c.slice_count):
			var at: float = lerpf(c.head_beat, c.tail_beat, float(i) / float(c.slice_count - 1) * c.squish_factor)
			spans.links.append(Vector2(c.head_beat - lead, at + tail))
	var last := 0.0
	for kind in spans:
		for s: Vector2 in spans[kind]:
			last = maxf(last, s.y)
	var best := {"tris": {"tris": -1}, "notes": {"notes": -1}}
	var t := 0.0
	while t <= last:
		var row := {"total": 0, "tris": 0}
		for kind in spans:
			var count := 0
			for i in (spans[kind] as Array).size():
				var s: Vector2 = spans[kind][i]
				if s.x <= t and t < s.y:
					count += 1
					row.tris += arc_tris[i] if kind == "arcs" else TRIS[kind]
			row[kind] = count
			row.total += count
		row.seconds = t * 60.0 / info.beats_per_minute
		if row.tris > best.tris.tris:
			best.tris = row
		if row.notes > best.notes.notes:
			best.notes = row
		t += STEP
	best.song = info.song_name
	best.diff = d.difficulty
	best.njs = d.note_jump_movement_speed
	return best

## Triangles of every MeshInstance3D in the objects' scenes.
func _meshes() -> void:
	for path in ["res://game/notes/BeepCube/BeepCube.tscn", "res://game/notes/Bomb/Bomb.tscn", "res://game/notes/Wall/Wall.tscn", "res://game/notes/Chain/ChainLink.tscn", "res://game/notes/Arc/Arc.tscn", "res://game/LightSaber.tscn"]:
		var node := (load(path) as PackedScene).instantiate()
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh:
				print("MESH %s %s %d tris" % [path.get_file(), mi.name, _tris(mi.mesh)])
		node.free()
	print("MESH note_round.glb %d tris" % _tris(LaserFixtures._model_mesh(load("res://game/notes/BeepCube/note_round.glb"))))

static func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var idx = arrays[Mesh.ARRAY_INDEX]
		n += (idx.size() if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n
