extends Node3D
class_name StageSmoke
## Fog on the stage: a thin drifting layer just above the floor and four wide fog sheets standing across the view at
## increasing depth (FogSheet.gdshader), dense at the bottom and rolling sideways, so the fog has layers and mass
## instead of floating puffs; all lit by the scene lights and faded out close to the player. Drawn before the other
## see-through things, so lights and walls show on top. During a song it clears and is freed; the menus bring it back
## (dissipate/refill, from EventDriver.set_menu_focus). The height fog on the scenery (height_fog.gdshaderinc) stays
## during play. All values untuned.

const FLOOR_SMOKE := preload("res://game/env/FloorSmoke.gdshader")
const FOG_SHEET := preload("res://game/env/FogSheet.gdshader")
const RENDER_PRIORITY := -4
const NOISE_SIZE := 256
const FLOOR_SIZE := Vector2(14.0, 30.0)
const FLOOR_CENTER_Z := -12.0
## one vertex every metre or so, as the floor smoke works out its fades per vertex
const FLOOR_SUBDIVIDE := Vector2i(13, 29)
## height, opacity, and drift of each noise copy in metres per second, for each floor layer; one layer about as thick
## as the two there were
const FLOOR_LAYERS := [
	[0.12, 0.9, Vector2(0.05, 0.12), Vector2(-0.08, 0.05)],
]
## Fog sheets standing across the view, nearest first: x, y, z of the centre and width, height. Each one wider
## and taller than the one before, so the layers read as depth; their bottoms reach below the floor.
const SHEETS: Array[Rect2] = [
	Rect2(Vector2(0.0, -14.0), Vector2(40.0, 5.0)),
	Rect2(Vector2(0.0, -24.0), Vector2(50.0, 6.5)),
	Rect2(Vector2(0.0, -36.0), Vector2(62.0, 8.0)),
	Rect2(Vector2(0.0, -52.0), Vector2(80.0, 10.0)),
]
const SHEET_BOTTOM := -1.0
const SHEET_OPACITY := 0.35
## Seconds the smoke takes to clear once a song starts (then it is freed and costs nothing while playing), and to
## fill the stage again in the menus. Untuned.
const CLEAR_SECONDS := 3.0
## Settings.atmosphere Eerie: the floor layer is this much thicker, and during a song it stays at EERIE_SONG_FLOOR of
## that (it lies 12 cm up, under the notes) while the sheets still clear. Untuned.
const EERIE_FLOOR := 1.4
const EERIE_SONG_FLOOR := 0.6
const FILL_SECONDS := 4.0

var _noise: NoiseTexture2D
## smoke materials and the opacity each has at full smoke
var _materials: Array[ShaderMaterial] = []
var _full_opacity: Array[float] = []
var _amount := 1.0
var _tween: Tween
## A song is on (dissipate) rather than a menu (refill).
var _playing := false

func _ready() -> void:
	var noise := NoiseTexture2D.new()
	noise.width = NOISE_SIZE
	noise.height = NOISE_SIZE
	noise.seamless = true
	noise.generate_mipmaps = true
	var fast_noise := FastNoiseLite.new()
	fast_noise.fractal_octaves = 4
	noise.noise = fast_noise
	_noise = noise
	_spawn()

## Clears the smoke over CLEAR_SECONDS and then frees it, as a song starts (with the Eerie atmosphere the floor layer
## stays, thinner).
func dissipate() -> void:
	_playing = true
	if get_child_count() == 0:
		return
	var tween := _fade_to(0.0, CLEAR_SECONDS)
	if not _eerie():
		tween.finished.connect(_free_smoke)

## Spawns the smoke again if it was cleared and fades it in over FILL_SECONDS, for the menus.
func refill() -> void:
	_playing = false
	if get_child_count() == 0:
		_spawn()
		_set_amount(0.0)
	_fade_to(1.0, FILL_SECONDS)

## Starts fading the smoke to an amount (0 none, 1 full), replacing any fade under way.
func _fade_to(amount: float, seconds: float) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_amount, _amount, amount, seconds)
	return _tween

## Scales every smoke material's opacity to an amount of its full value (the floor layers' by the atmosphere too).
func _set_amount(amount: float) -> void:
	_amount = amount
	var eerie := _eerie()
	for i in _materials.size():
		var opacity := _full_opacity[i] * amount
		if eerie and i < FLOOR_LAYERS.size():
			opacity = _full_opacity[i] * EERIE_FLOOR * (lerpf(EERIE_SONG_FLOOR, 1.0, amount) if _playing else amount)
		_materials[i].set_shader_parameter(&"opacity", opacity)

## Puts the smoke in step with Settings.atmosphere (it may change any time).
func apply_atmosphere() -> void:
	if _eerie() and get_child_count() == 0:
		_spawn()
		_set_amount(0.0)
	_set_amount(_amount)

static func _eerie() -> bool:
	return Settings.atmosphere == "Eerie"

## Removes the smoke meshes (the noise texture stays for the next spawn).
func _free_smoke() -> void:
	for child in get_children():
		child.queue_free()
	_materials.clear()
	_full_opacity.clear()

## Builds the floor layer and the fog sheets at full density.
func _spawn() -> void:
	var noise := _noise
	var plane := PlaneMesh.new()
	plane.size = FLOOR_SIZE
	plane.subdivide_width = FLOOR_SUBDIVIDE.x
	plane.subdivide_depth = FLOOR_SUBDIVIDE.y
	for layer: Array in FLOOR_LAYERS:
		var material := ShaderMaterial.new()
		material.shader = FLOOR_SMOKE
		material.render_priority = RENDER_PRIORITY
		material.set_shader_parameter(&"noise", noise)
		material.set_shader_parameter(&"opacity", layer[1])
		_materials.append(material)
		_full_opacity.append(layer[1])
		material.set_shader_parameter(&"drift_a", layer[2])
		material.set_shader_parameter(&"drift_b", layer[3])
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = plane
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.position = Vector3(0.0, layer[0], FLOOR_CENTER_Z)
		add_child(mesh_instance)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = QuadMesh.new()
	multimesh.instance_count = SHEETS.size()
	for i in SHEETS.size():
		var sheet := SHEETS[i]
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(sheet.size.x, sheet.size.y, 1.0)),
			Vector3(sheet.position.x, SHEET_BOTTOM + sheet.size.y * 0.5, sheet.position.y)))
	var sheet_material := ShaderMaterial.new()
	sheet_material.shader = FOG_SHEET
	sheet_material.render_priority = RENDER_PRIORITY
	sheet_material.set_shader_parameter(&"noise", noise)
	sheet_material.set_shader_parameter(&"opacity", SHEET_OPACITY)
	_materials.append(sheet_material)
	_full_opacity.append(SHEET_OPACITY)
	var sheets := MultiMeshInstance3D.new()
	sheets.multimesh = multimesh
	sheets.material_override = sheet_material
	sheets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheets)
