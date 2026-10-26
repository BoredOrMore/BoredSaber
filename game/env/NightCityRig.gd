extends Node3D
class_name NightCityRig
## The Night City environment's structure, which its lights are mounted on (AGENTS.md "Light", rule 5).
## The default is a giant building canyon (doc/assets/night_city_canyon/spec.md, owner 2026-10-25, blockout): a wall
## of towers 150-200 m tall on one side (WALL_SIDE), low roofs stepping down on the other, a far city in the haze and
## a landmark tower beyond, so the player on their rooftop feels tiny and left and right differ (VISUAL_STYLE "Scale
## and symmetry"). Settings.classic_night_city brings back the classic layout: dark
## buildings in a row on each side of the track, their inner faces 19 m out, so the skyline straight ahead stays
## clear. Searchlights (the waving lasers) stand on the roofs, the diagonal lasers cross from the roofs' inner
## edges, and the square bars trim the roof edges facing the track. Dark boxes in one MultiMesh with the scenery's
## fog shader. Sizes in metres, untuned.

const ENV_SOLID := preload("res://game/env/EnvSolidCanyon.gdshader")
## the same without the windows, for the pieces that never show any: one shader with them cost these pixels for nothing
const ENV_SOLID_PLAIN := preload("res://game/env/EnvSolidCanyonPlain.gdshader")
## How much of the lights' colour the buildings' faces take (EnvSolid light_spill, 1 elsewhere): at 1 the near
## buildings read as flat grey boxes, brighter than the skyline (owner, 2026-10-25: too bright), as Metal Factory's
## walls did. Untuned.
const LIGHT_SPILL := 0.3
## the buildings' metal darker than EnvSolid's (0.094), and less of the haze (0.03 a metre: the near ones, 20 m out,
## went half haze-grey). Untuned.
const ALBEDO := Color(0.05, 0.05, 0.06)
const FOG_DENSITY := 0.0075
const INNER_FACE_X := 19.0
const DEPTH_X := 7.0
## [z centre, length along the track, height] of each building, left side then right side
const LEFT: Array[Vector3] = [Vector3(-20.0, 9.0, 10.0), Vector3(-32.0, 10.0, 14.0), Vector3(-44.0, 9.0, 11.0), Vector3(-56.0, 10.0, 16.0)]
## The player stands on a rooftop: a low parapet runs along each side of it.
## Near the player, out of the note lane and clear of the view ahead, a few pieces stand within a few metres so
## they move against the far scenery as the head moves (parallax), which makes the player feel they stand in the
## place rather than in front of it.
const PARAPET_X := 4.0
const PARAPET_HEIGHT := 1.0
const PARAPET_THICKNESS := 0.3
## the parapet's z from and to; the player stands at 1
const PARAPET_Z := Vector2(5.0, -5.0)
const RIGHT: Array[Vector3] = [Vector3(-20.0, 9.0, 13.0), Vector3(-32.0, 10.0, 10.0), Vector3(-44.0, 9.0, 15.0), Vector3(-56.0, 10.0, 11.0)]

## The canyon (blockout; every size a proposal). The side the tower wall stands on (-1 left, 1 right); the low roofs
## and the far city are on the other.
const WALL_SIDE := -1.0
## the street the towers and low roofs stand on, below the player's rooftop (y 0)
const STREET_Y := -45.0
## the tower wall: [inner face out from the track, z from, z to, top] of each tower
## The towers' ends on the window grid's 8 m (a pilaster's step), so each face's windows start and end with the
## building, not cut by its edge (owner on the headset, 2026-10-25: the windows read as a texture).
const TOWERS: Array[Vector4] = [Vector4(25.0, 16.0, -48.0, 170.0), Vector4(28.0, -48.0, -112.0, 200.0),
	Vector4(25.0, -112.0, -168.0, 150.0)]
const TOWER_DEPTH := 30.0
## Relief on the towers' faces, so the wall reads as buildings and not one flat sheet (owner on the headset,
## 2026-10-25: "the left towers have no depth"): pilasters standing out of the face every PILASTER_STEP metres, ledges
## running along it every LEDGE_FLOORS floors, and each tower's top stepped back (setback: the part of its height
## where the step is, and how far back), different per tower. [out, wide] of a pilaster, [out, tall] of a ledge.
## The pilasters stand on whole window cells (EnvSolid WINDOW_PITCH, 2 m: centres at PILASTER_STEP k + 1), and those
## cells' windows are left out (window_pier_cells), so windows sit between them; a ledge runs just under a floor's
## line, below its windows.
const PILASTER := Vector2(0.8, 2.0)
const PILASTER_STEP := 8.0
const LEDGE := Vector2(0.6, 0.8)
const LEDGE_FLOORS := 4
const FLOOR_HEIGHT := 3.5
## The setback's step is snapped to a ledge line, its depth to whole window cells (so its ends stay on the grid).
const SETBACKS: Array[Vector2] = [Vector2(0.7, 4.0), Vector2(0.8, 8.0), Vector2(0.65, 4.0)]
## the buildings' shading (EnvSolid): faces turned along the track (pilasters' and setbacks' sides) this much darker
## than faces turned to it, and the street end of a wall this much darker than its top (the canyon's floor in shadow)
const SIDE_SHADE := 0.45
const DEPTH_SHADE := 0.6
## the low roofs on the open side, stepping down: [inner edge out from the track, z from, z to, roof]
## (raised from 8-18 m below: from the player's roof only the water tanks' tops showed; owner, 2026-10-25)
const LOW_ROOFS: Array[Vector4] = [Vector4(8.0, 10.0, -20.0, -3.0), Vector4(10.0, -20.0, -50.0, -5.0),
	Vector4(12.0, -50.0, -85.0, -7.0), Vector4(14.0, -85.0, -120.0, -9.0)]
const LOW_ROOF_DEPTH := 22.0
## The far city on the open side is the sky's own skyline (NightCitySky.gdshader): boxes out there took the haze's
## colour and read as pale grey blocks in front of it (blockout capture, 2026-10-25). The landmark tower beyond,
## [out, z, width, top], is a dark silhouette against the sky: its own material with almost no haze (LANDMARK_FOG).
const LANDMARK := Vector4(350.0, -700.0, 40.0, 400.0)
const LANDMARK_FOG := 0.0003
## Fog with mass (doc/research/fog.md; owner, 2026-10-25: thick): a sea of cloud filling the canyon at SEA_Y, the
## towers and low roofs rising out of it (CloudSea.gdshader, opaque), over SEA_SIZE metres centred at SEA_CENTRE
## (x, z), SEA_CELLS a side; and a thick fog layer from just under it (EnvSolid canyon_fog: [level, density, thinning
## per metre up, strength]) that hides where it meets them, rolling (CANYON_FOG_ROLL). The scenery's haze is worked
## out per pixel here (the towers' faces are too big for a blend of their corners). Untuned.
const CLOUD_SEA := preload("res://game/env/CloudSea.gdshader")
const SEA_Y := -30.0
const SEA_SIZE := Vector2(320.0, 320.0)
const SEA_CENTRE := Vector2(90.0, -120.0)
const SEA_CELLS := 56
const CANYON_FOG := Vector4(SEA_Y - 2.0, 0.09, 0.22, 1.0)
const CANYON_FOG_ROLL := 0.6
## Nothing below the sea of cloud shows (it is opaque and covers the whole canyon), so the boxes stop HIDDEN_Y,
## under its lowest trough, instead of at the street: the GPU shades none of what it would hide (bench, 2026-10-25: the
## scenery is Night City's largest cost). The shading still goes by the street's height (window_span).
const HIDDEN_Y := SEA_Y - 4.0
## The billboards on the tower wall (CityBillboard.gdshader), carrying the square bars' light: [tower, along the tower
## from its near end (0-1), height, width, tall, shape (0 circle, 1 triangle, 2 stripes, 3 frames)]. Different sizes
## and heights, not a row. Standing just off the pilasters' fronts.
const BILLBOARD := preload("res://game/env/CityBillboard.gdshader")
const BILLBOARDS := [
	[0, 0.45, 26.0, 14.0, 9.0, 0], [0, 0.8, 52.0, 9.0, 16.0, 2],
	[1, 0.2, 38.0, 20.0, 12.0, 3], [1, 0.6, 70.0, 12.0, 12.0, 1],
	[2, 0.35, 30.0, 16.0, 8.0, 2], [2, 0.7, 48.0, 10.0, 10.0, 0],
]
## They stand off the pilasters' fronts on arms (owner, 2026-10-25: they must read as mounted things, not decals):
## BILLBOARD_OFF metres out, in a box frame BILLBOARD_FRAME deep and BILLBOARD_RIM wider than the face, held by two
## arms to the wall; frame and arms in the props' material.
const BILLBOARD_OFF := 2.5
const BILLBOARD_FRAME := 0.5
const BILLBOARD_RIM := 0.4
const BILLBOARD_ARM := 0.3
## Rooftop clutter on the low roofs (familiar-size cues; doc/assets/water_tank/spec.md): water tanks as [roof,
## across the roof from its inner edge (0-1), along it (0-1), turn]. In the props' material: the city's without
## windows.
const WATER_TANK := preload("res://game/models/water_tank.glb")
const WATER_TANKS := [[0, 0.55, 0.3, 0.2], [1, 0.3, 0.7, 1.1], [2, 0.65, 0.25, 0.6], [3, 0.4, 0.55, 2.0], [1, 0.8, 0.2, 0.0]]
## the player's rooftop: a stair house on the wall side [out, z, size x/y/z], an open railing on the other side
## the rooftop's surface, level with the platform's base (TrackDeck.PAD_DEPTH below the deck's top), so the track and
## platform sit on the roof; the stair house, parapet and railing stand on it
const ROOF_Y := -TrackDeck.PAD_DEPTH
const STAIR_HOUSE := Vector3(6.0, -1.0, 0.0)
const STAIR_HOUSE_SIZE := Vector3(3.0, 3.0, 4.0)
const RAILING_X := 4.0
const RAILING_HEIGHT := 1.1
const RAILING_POST_STEP := 1.5
## the railing's posts and rails thick enough to read at 4 m (they were 6 cm and looked like lines in the air)
const RAILING_POST := 0.09
const RAILING_RAIL := 0.07
## the rooftop's length along the track, from and to
const ROOF_Z := Vector2(6.0, -8.0)
## the low parapet (kick plate) along the rooftop's open edge the railing stands on: [thickness, height]
const PARAPET := Vector2(0.3, 0.35)

var _instance: MultiMeshInstance3D
## the boxes near the track, which have no windows (closer than window_min_x)
var _plain_instance: MultiMeshInstance3D
var _landmark: MeshInstance3D
var _billboards: MultiMeshInstance3D
var _props: Array[MultiMeshInstance3D] = []
## the billboards' frames and arms, drawn with the props
var _mounts: Array[Transform3D] = []
var _props_material: ShaderMaterial
var _sea: MeshInstance3D
## the billboards' material, its light colour set each frame from the square bars' (EventDriver)
var billboard_material: ShaderMaterial
var _material: ShaderMaterial

## The buildings of one side (-1 left, 1 right) as [z centre, length, height] (the classic layout).
static func buildings(side: float) -> Array[Vector3]:
	return LEFT if side < 0.0 else RIGHT

## The roof height at a point along the track on one side, or 0 between buildings.
static func roof_at(side: float, z: float) -> float:
	for b in buildings(side):
		if absf(z - b.x) <= b.y * 0.5:
			return b.z
	return 0.0

func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = ENV_SOLID
	_material.set_shader_parameter(&"light_spill", LIGHT_SPILL)
	_material.set_shader_parameter(&"albedo", ALBEDO)
	_material.set_shader_parameter(&"fog_density", FOG_DENSITY)
	build(Settings.classic_night_city)

## The canyon's windows (EnvSolid layer 9): the map's light colours either side, how far the show has built them up
## (0-1) and how bright they burn (never quite dark once lit).
func set_windows(left: Color, right: Color, level: float, glow: float) -> void:
	for material: ShaderMaterial in [_material, _landmark.material_override if _landmark else null]:
		if material == null:
			continue
		material.set_shader_parameter(&"window_left_color", left)
		material.set_shader_parameter(&"window_right_color", right)
		material.set_shader_parameter(&"window_level", level)
		material.set_shader_parameter(&"window_glow", glow)

## Builds the classic layout or the canyon.
func build(classic: bool) -> void:
	if _instance:
		_instance.queue_free()
	if _plain_instance:
		_plain_instance.queue_free()
		_plain_instance = null
	if _landmark:
		_landmark.queue_free()
		_landmark = null
	if _billboards:
		_billboards.queue_free()
		_billboards = null
	for props in _props:
		props.queue_free()
	_props.clear()
	if _sea:
		_sea.queue_free()
		_sea = null
	var boxes := _classic_boxes() if classic else _drawn_boxes(_canyon_boxes())
	_material.set_shader_parameter(&"windows", 0.0 if classic else 1.0)
	_material.set_shader_parameter(&"canyon_fog", Vector4.ZERO if classic else CANYON_FOG)
	_material.set_shader_parameter(&"fog_roll", CANYON_FOG_ROLL)
	_material.set_shader_parameter(&"fog_per_pixel", not classic)
	# the boxes closer to the track than the windows start show none (EnvSolid windows_light): drawn without them
	var window_min_x := RAILING_X + STAIR_HOUSE_SIZE.x + 2.0
	_material.set_shader_parameter(&"window_min_x", window_min_x)
	_material.set_shader_parameter(&"window_span", Vector2(STREET_Y, TOWERS[1].w))
	_material.set_shader_parameter(&"side_shade", 0.0 if classic else SIDE_SHADE)
	_material.set_shader_parameter(&"window_pier_cells", int(PILASTER_STEP / PILASTER.y))
	_material.set_shader_parameter(&"depth_shade", 0.0 if classic else DEPTH_SHADE)
	var windowed: Array[Transform3D] = []
	var plain: Array[Transform3D] = []
	for box in boxes:
		var far_x := absf(box.origin.x) + absf(box.basis.x.x) * 0.5
		(windowed if not classic and far_x > window_min_x else plain).append(box)
	_instance = _box_instance(windowed, _material)
	var plain_material := _material.duplicate() as ShaderMaterial
	plain_material.shader = ENV_SOLID_PLAIN
	_plain_instance = _box_instance(plain, plain_material)
	if not classic:
		var o := -WALL_SIDE
		_landmark = MeshInstance3D.new()
		_landmark.mesh = BoxMesh.new()
		_landmark.transform = _span(Vector3(o * LANDMARK.x, STREET_Y, LANDMARK.y + LANDMARK.z * 0.5),
			Vector3(o * (LANDMARK.x + LANDMARK.z), LANDMARK.w, LANDMARK.y - LANDMARK.z * 0.5))
		var far := _material.duplicate() as ShaderMaterial
		far.set_shader_parameter(&"fog_density", LANDMARK_FOG)
		_landmark.material_override = far
		_landmark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_landmark)
		_mounts.clear()
		_add_billboards()
		_add_props()
		_add_sea()

## The sea of cloud in the canyon.
func _add_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = SEA_SIZE
	plane.subdivide_width = SEA_CELLS
	plane.subdivide_depth = SEA_CELLS
	var material := ShaderMaterial.new()
	material.shader = CLOUD_SEA
	_sea = MeshInstance3D.new()
	_sea.mesh = plane
	_sea.material_override = material
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the waves heave it up and down past its plane
	_sea.extra_cull_margin = 4.0
	_sea.position = Vector3(-WALL_SIDE * SEA_CENTRE.x, SEA_Y, SEA_CENTRE.y)
	add_child(_sea)

## The rooftop clutter on the low roofs, one MultiMesh per model.
func _add_props() -> void:
	if _props_material == null:
		_props_material = _material.duplicate() as ShaderMaterial
		_props_material.shader = ENV_SOLID_PLAIN
	_props_material.set_shader_parameter(&"windows", 0.0)
	var o := -WALL_SIDE
	var tanks: Array[Transform3D] = []
	for t: Array in WATER_TANKS:
		var roof := LOW_ROOFS[int(t[0])]
		var at := Vector3(o * (roof.x + LOW_ROOF_DEPTH * float(t[1])), roof.w, lerpf(roof.y, roof.z, float(t[2])))
		tanks.append(Transform3D(Basis(Vector3.UP, float(t[3])), at))
	for pair: Array in [[LaserFixtures._model_mesh(WATER_TANK), tanks], [BoxMesh.new(), _mounts]]:
		var placed: Array[Transform3D] = []
		placed.assign(pair[1])
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = pair[0]
		multimesh.instance_count = placed.size()
		for i in placed.size():
			multimesh.set_instance_transform(i, placed[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = _props_material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		_props.append(instance)

## The billboards: one MultiMesh of quads facing the track off the tower wall's face.
func _add_billboards() -> void:
	if billboard_material == null:
		billboard_material = ShaderMaterial.new()
		billboard_material.shader = BILLBOARD
	var w := WALL_SIDE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	var quad := QuadMesh.new()
	multimesh.mesh = quad
	multimesh.instance_count = BILLBOARDS.size()
	# the quad faces +z; turned to face the track from the wall's side
	var facing := Basis(Vector3.UP, -w * PI * 0.5)
	for i in BILLBOARDS.size():
		var b: Array = BILLBOARDS[i]
		var t := TOWERS[int(b[0])]
		var origin := Vector3(w * (t.x - PILASTER.x - BILLBOARD_OFF), b[2], lerpf(t.y, t.z, b[1]))
		multimesh.set_instance_transform(i, Transform3D(facing * Basis.from_scale(Vector3(b[3], b[4], 1.0)), origin))
		multimesh.set_instance_custom_data(i, Color(float(b[5]), 0.0, 0.0, 0.0))
		# the box frame behind the face, its rim showing round it, and the arms back to the pilasters
		# just behind the face, toward the wall
		var back := origin.x + w * 0.02
		_mounts.append(_span(Vector3(back, origin.y - b[4] * 0.5 - BILLBOARD_RIM, origin.z - b[3] * 0.5 - BILLBOARD_RIM),
			Vector3(back + w * BILLBOARD_FRAME, origin.y + b[4] * 0.5 + BILLBOARD_RIM, origin.z + b[3] * 0.5 + BILLBOARD_RIM)))
		for arm_y: float in [origin.y - b[4] * 0.3, origin.y + b[4] * 0.3]:
			_mounts.append(_span(Vector3(back + w * BILLBOARD_FRAME, arm_y - BILLBOARD_ARM * 0.5, origin.z - BILLBOARD_ARM * 0.5),
				Vector3(w * (t.x - PILASTER.x), arm_y + BILLBOARD_ARM * 0.5, origin.z + BILLBOARD_ARM * 0.5)))
	_billboards = MultiMeshInstance3D.new()
	_billboards.multimesh = multimesh
	_billboards.material_override = billboard_material
	_billboards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_billboards)

## A box from corner `a` to corner `b`.
## One MultiMesh of boxes in this material, added to the rig.
func _box_instance(boxes: Array[Transform3D], material: ShaderMaterial) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = boxes.size()
	for i in boxes.size():
		multimesh.set_instance_transform(i, boxes[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

static func _span(a: Vector3, b: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale((b - a).abs()), (a + b) * 0.5)

## The canyon's boxes: the tower wall, the low roofs and the rooftop's pieces.
func _canyon_boxes() -> Array[Transform3D]:
	var boxes: Array[Transform3D] = []
	var w := WALL_SIDE
	var o := -WALL_SIDE
	for i in TOWERS.size():
		var t := TOWERS[i]
		var setback := SETBACKS[i % SETBACKS.size()]
		var band := FLOOR_HEIGHT * LEDGE_FLOORS
		var step_y := STREET_Y + roundf((lerpf(STREET_Y, t.w, setback.x) - STREET_Y) / band) * band
		boxes.append(_span(Vector3(w * t.x, STREET_Y, t.y), Vector3(w * (t.x + TOWER_DEPTH), step_y, t.z)))
		boxes.append(_span(Vector3(w * (t.x + setback.y), step_y, t.y - setback.y * 0.5),
			Vector3(w * (t.x + TOWER_DEPTH), t.w, t.z + setback.y * 0.5)))
		# pilasters and ledges on both faces, the lower one and the setback above it
		for face: Vector4 in [Vector4(t.x, t.y, t.z, STREET_Y), Vector4(t.x + setback.y, t.y - setback.y * 0.5,
				t.z + setback.y * 0.5, step_y)]:
			var top := step_y if face.w == STREET_Y else t.w
			var z := floorf((face.y - PILASTER.y) / PILASTER_STEP) * PILASTER_STEP + PILASTER.y * 0.5
			while z > face.z + PILASTER.y:
				boxes.append(_span(Vector3(w * (face.x - PILASTER.x), face.w, z + PILASTER.y * 0.5),
					Vector3(w * face.x, top, z - PILASTER.y * 0.5)))
				z -= PILASTER_STEP
			var y := face.w + band
			while y < top - FLOOR_HEIGHT:
				boxes.append(_span(Vector3(w * (face.x - LEDGE.x), y - LEDGE.y * 0.6, face.y), Vector3(w * face.x, y + LEDGE.y * 0.4, face.z)))
				y += band
	for r in LOW_ROOFS:
		boxes.append(_span(Vector3(o * r.x, STREET_Y, r.y), Vector3(o * (r.x + LOW_ROOF_DEPTH), r.w, r.z)))
	# the rooftop under the player, down to the street, and its pieces
	# the rooftop reaches under the stair house on the wall side and to the parapet on the open side
	var reach := STAIR_HOUSE.x + STAIR_HOUSE_SIZE.x
	boxes.append(_span(Vector3(w * reach, STREET_Y, ROOF_Z.x), Vector3(o * RAILING_X, ROOF_Y, ROOF_Z.y)))
	boxes.append(Transform3D(Basis.from_scale(STAIR_HOUSE_SIZE),
		Vector3(w * STAIR_HOUSE.x, ROOF_Y + STAIR_HOUSE_SIZE.y * 0.5, STAIR_HOUSE.y)))
	# the railing stands on a low parapet along the open edge, not on air (owner on the headset, 2026-10-25)
	var parapet_x := RAILING_X - PARAPET.x * 0.5
	boxes.append(_span(Vector3(o * (RAILING_X - PARAPET.x), ROOF_Y, ROOF_Z.x), Vector3(o * RAILING_X, ROOF_Y + PARAPET.y, ROOF_Z.y)))
	var top := ROOF_Y + PARAPET.y
	# posts the whole length, one at each end
	var length := ROOF_Z.x - ROOF_Z.y - RAILING_POST
	var posts := ceili(length / RAILING_POST_STEP)
	for i in posts + 1:
		var post_z := ROOF_Z.x - RAILING_POST * 0.5 - length * float(i) / posts
		boxes.append(_span(Vector3(o * parapet_x - RAILING_POST * 0.5, top, post_z + RAILING_POST * 0.5),
			Vector3(o * parapet_x + RAILING_POST * 0.5, top + RAILING_HEIGHT, post_z - RAILING_POST * 0.5)))
	# the top rail and a middle rail
	for rail_y: float in [RAILING_HEIGHT - RAILING_RAIL, RAILING_HEIGHT * 0.5]:
		boxes.append(_span(Vector3(o * parapet_x - RAILING_RAIL * 0.5, top + rail_y, ROOF_Z.x),
			Vector3(o * parapet_x + RAILING_RAIL * 0.5, top + rail_y + RAILING_RAIL, ROOF_Z.y)))
	return boxes

## The canyon's boxes as drawn: cut at HIDDEN_Y, those wholly below it left out, nearest the player first, so the
## nearer faces fill the depth buffer before the big walls behind them and those pixels are shaded once (the boxes are
## one MultiMesh, drawn in this order; opaque, so the order changes nothing that shows).
static func _drawn_boxes(boxes: Array[Transform3D]) -> Array[Transform3D]:
	var drawn: Array[Transform3D] = []
	for box in boxes:
		var low := box.origin.y - box.basis.y.y * 0.5
		var high := box.origin.y + box.basis.y.y * 0.5
		if high <= HIDDEN_Y:
			continue
		if low < HIDDEN_Y:
			box = _span(Vector3(box.origin.x - box.basis.x.x * 0.5, HIDDEN_Y, box.origin.z - box.basis.z.z * 0.5),
				Vector3(box.origin.x + box.basis.x.x * 0.5, high, box.origin.z + box.basis.z.z * 0.5))
		drawn.append(box)
	drawn.sort_custom(func(a: Transform3D, b: Transform3D) -> bool: return _nearest(a) < _nearest(b))
	return drawn

## How far a box's nearest point is from the player's head.
static func _nearest(box: Transform3D) -> float:
	var half := Vector3(box.basis.x.x, box.basis.y.y, box.basis.z.z).abs() * 0.5
	var head := Vector3(0.0, 1.7, 0.0)
	return (head - head.clamp(box.origin - half, box.origin + half)).length()

## The classic layout's boxes.
func _classic_boxes() -> Array[Transform3D]:
	var boxes: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for b in buildings(side):
			var centre := Vector3(side * (INNER_FACE_X + DEPTH_X * 0.5), b.z * 0.5 - 1.0, b.x)
			boxes.append(Transform3D(Basis.from_scale(Vector3(DEPTH_X, b.z + 2.0, b.y)), centre))
	for side in [-1.0, 1.0]:
		var length := PARAPET_Z.x - PARAPET_Z.y
		boxes.append(Transform3D(Basis.from_scale(Vector3(PARAPET_THICKNESS, PARAPET_HEIGHT + 1.0, length)),
			Vector3(side * PARAPET_X, (PARAPET_HEIGHT - 1.0) * 0.5, (PARAPET_Z.x + PARAPET_Z.y) * 0.5)))
	return boxes
