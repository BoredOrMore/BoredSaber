extends UIRaycastTarget
class_name SlashBlock
## A note beside the player in the song menu, on the dominant hand's side: cutting it the right way (its arrow,
## with the saber of its colour) breaks it apart and plays the selected song, as does pointing at it and pulling
## the trigger. The song menu shows what it will play ("Slash to play · ...").

## The note was cut the right way, or clicked.
signal slashed()

## Where it floats, from the player's spot (z = PLAYER_Z, facing -z): YAW to the dominant hand's side, HORIZONTAL
## metres away, BELOW_EYES under the eyes (1.1 m high for 1.6 m eyes): 23.5 degrees down, as low as the song
## menu's bottom corner (-22 degrees) and 24 degrees right of it (37 degrees), 1.25 m from the eyes and about 1.1 m
## from the shoulder for a relaxed swing with the arm out. That is as close to the corner as it gets while no saber
## reaches it during menu use (blades 1.25 m long from hands 0.3-0.5 m in front of the body, pointed anywhere on
## the menu, flicked 25 degrees up or down: 0.19 m clear). Right at the corner a saber pointing there runs through
## it (no clearance). 61 degrees is past the 55 degree comfortable head turn: a short turn for one swing. Mirrored
## for left-handed players (beside the menu's left corner).
const YAW_DEGREES := 61.0
const HORIZONTAL := 1.15
const BELOW_EYES := 0.5
const PLAYER_Z := 1.0
## Edge of the note in metres (the game's notes are 0.4 m): 13.7 degrees across at its distance.
const NOTE_SIZE := 0.3
## Eye height used when no headset camera is there (desktop runs).
const FALLBACK_EYES := 1.6
## Share of the note's size, around its centre, a saber has to cross (the player's pick: grazing an edge doesn't
## count). The pointer's hit area stays the whole note, as drawn.
const SABER_HITBOX_SHARE := 0.85
## Slowest saber tip that counts as a cut, in m/s. Untuned: check on the headset that a deliberate swing
## cuts and resting a saber against the note doesn't.
const MIN_TIP_SPEED := 2.0
## Least cosine between the swing and the arrow that counts as the right way: 60 degrees either side, Beat
## Saber's allowance.
const MIN_DIRECTION_DOT := 0.5
## Hover makes the note brighter by mixing toward white (root AGENTS.md "Light": hot core, no values over 1).
const HOVER_WHITE := 0.35
const RUMBLE_STRENGTH := 0.75
const RUMBLE_SECONDS := 0.1
const WRONG_RUMBLE_STRENGTH := 0.3
const WRONG_RUMBLE_SECONDS := 0.2
const CUT_SOUND := preload("res://game/data/cut_1.wav")
const WRONG_SOUND := preload("res://game/data/bad_cut.wav")
## The small note of the other colour: its edge in metres (40% of the big one), and the big note's corner its
## centre sits on, seen from the player (x -1 left / 1 right, y 1 top / -1 bottom, mirrored for left-handed players).
const OTHER_NOTE_SIZE := 0.12
const OTHER_NOTE_CORNER := Vector2(-1.0, 1.0)
## The words over the note: what to do, in the arrow's direction. A strip above it, so the arrow stays clear; the
## theme's Roboto Medium at 72 px with 1 mm per px is a 5 cm cap height, 2.3 degrees at 1.25 m (the menu's 28 px
## rule is 1.9 degrees), white with a dark outline.
const SLASH_DOWN_TEXT := "Slash down to play"
const SLASH_TEXT := "Slash to play"
const TEXT_FONT := preload("res://OQ_Toolkit/OQ_UI2D/theme/Roboto-Medium.ttf")
const TEXT_SIZE := 72
const TEXT_OUTLINE := 14
const TEXT_PIXEL := 0.001
const TEXT_GAP := 0.07
## Light from the note (root AGENTS.md "Light": it comes from the note's surface, hot core and coloured falloff,
## no screen reads, no real light): the note's own glow (its shader's emission) breathes GLOW_PULSE_HZ (well away
## from 0.2 Hz) between EMISSION_MIN and EMISSION_MAX; one additive halo HALO_SIZE across behind it; RAY_COUNT
## faint short rays from its edges, RAY_LENGTH long, still. All of it breathes together between LIGHT_MIN and full.
## A cut flashes it all to full for FLASH_SECONDS, then it fades with the halves over FADE_SECONDS.
const GLOW_PULSE_HZ := 1.0
const EMISSION_MIN := 0.18
const EMISSION_MAX := 0.45
const HALO_SIZE := 0.55
const HALO_ALPHA := 0.8
const RAY_COUNT := 6
const RAY_LENGTH := 0.16
const RAY_WIDTH := 0.025
const RAY_ALPHA := 0.35
const LIGHT_MIN := 0.6
const FLASH_SECONDS := 0.1
const FADE_SECONDS := 0.3
## Push that throws the two halves of a cut note apart (the game's notes use the same).
const SPLIT_IMPULSE := 2.0
## The game's note model and look.
const NOTE_SCENE := preload("res://game/notes/BeepCube/BeepCube.tscn")

## The sabers that can cut it, set by the game.
var sabers: Array[LightSaber] = []
## The saber type (LightSaber.type: 0 left, 1 right) whose colour the note has, and that colour.
var _note_saber := 1
var _color := Color.WHITE
var _material: ShaderMaterial
var _other_material: ShaderMaterial
var _note_mesh: MeshInstance3D
var _other_mesh: MeshInstance3D
var _label := Label3D.new()
## The light: halo and rays, with their materials, and the time for the breathing.
var _light := Node3D.new()
var _halo_material := StandardMaterial3D.new()
var _ray_material := StandardMaterial3D.new()
var _light_time := 0.0
var _flash: Tween
## The halves a cut note breaks into (the game's CutPiece).
var _pieces: Array[CutPiece] = []
var _half_size := Vector3.ONE * 0.15
var _sound := AudioStreamPlayer3D.new()
var _shown := false
## The note was near the middle of the view at the last check (for the log marker).
var _in_view := false
## Within this cosine of straight ahead counts as looking at the note (about 40 degrees).
const IN_VIEW_COS := 0.77
## A saber already inside the note: it counts once, when it enters.
var _touching: Array[LightSaber] = []

func _ready() -> void:
	collision_mask = 0
	_note_mesh = _add_note_mesh(NOTE_SIZE)
	_material = _note_mesh.material_override as ShaderMaterial
	_half_size = Vector3.ONE * NOTE_SIZE / 2.0
	for i in 2:
		_pieces.append(CutPiece.new(self, _note_mesh.mesh, _material.duplicate(true) as ShaderMaterial, true))
	# the other colour, small, perched on a top corner: shows the song's colour pair; it can't be cut (sabers
	# only test the big note's box, no sound or rumble from it) and has no pointer target
	_other_mesh = _add_note_mesh(OTHER_NOTE_SIZE)
	_other_material = _other_mesh.material_override as ShaderMaterial
	_label.font = TEXT_FONT
	_label.font_size = TEXT_SIZE
	_label.outline_size = TEXT_OUTLINE
	_label.pixel_size = TEXT_PIXEL
	_label.modulate = Constants.UI_TEXT
	_label.outline_modulate = Constants.UI_PANEL
	# above the small note too, so the words don't run into it
	_label.position = Vector3(0.0, (NOTE_SIZE + OTHER_NOTE_SIZE) / 2.0 + TEXT_GAP, 0.0)
	add_child(_label)
	_add_light()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _half_size * 2.0
	shape.shape = box
	add_child(shape)
	add_child(_sound)
	set_shown(false)

## The halo (a radial gradient on a camera-facing quad behind the note) and the rays (linear gradients fading
## outward from the note's edges, in its plane), all additive and unshaded.
func _add_light() -> void:
	add_child(_light)
	var halo_gradient := Gradient.new()
	halo_gradient.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	halo_gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	var halo_texture := GradientTexture2D.new()
	halo_texture.gradient = halo_gradient
	halo_texture.fill = GradientTexture2D.FILL_RADIAL
	halo_texture.fill_from = Vector2(0.5, 0.5)
	halo_texture.fill_to = Vector2(1.0, 0.5)
	_setup_additive(_halo_material, halo_texture)
	_halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var halo := MeshInstance3D.new()
	var halo_quad := QuadMesh.new()
	halo_quad.size = Vector2.ONE * HALO_SIZE
	halo.mesh = halo_quad
	halo.material_override = _halo_material
	_light.add_child(halo)
	var ray_gradient := Gradient.new()
	ray_gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ray_texture := GradientTexture2D.new()
	ray_texture.gradient = ray_gradient
	ray_texture.fill_from = Vector2(0.5, 1.0)
	ray_texture.fill_to = Vector2(0.5, 0.0)
	_setup_additive(_ray_material, ray_texture)
	var ray_quad := QuadMesh.new()
	ray_quad.size = Vector2(RAY_WIDTH, RAY_LENGTH)
	for i in RAY_COUNT:
		# evenly round the note, none straight up into the words
		var angle := TAU * i / RAY_COUNT
		var outward := Vector3(cos(angle), sin(angle), 0.0)
		var ray := MeshInstance3D.new()
		ray.mesh = ray_quad
		ray.material_override = _ray_material
		ray.position = outward * (NOTE_SIZE * 0.55 + RAY_LENGTH / 2.0)
		ray.rotation.z = angle - PI / 2.0
		_light.add_child(ray)

static func _setup_additive(material: StandardMaterial3D, texture: Texture2D) -> void:
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

## Breathes the light while the note is up.
func _process(delta: float) -> void:
	if not _shown:
		return
	_light_time += delta
	_set_light(lerpf(LIGHT_MIN, 1.0, 0.5 + 0.5 * sin(TAU * GLOW_PULSE_HZ * _light_time)))
	# a marker in the log, to line performance measurements up with looking at the note
	if vr.vrCamera:
		var to_note := (global_position - vr.vrCamera.global_position).normalized()
		var in_view := -vr.vrCamera.global_transform.basis.z.dot(to_note) > IN_VIEW_COS
		if in_view != _in_view:
			_in_view = in_view
			print("Slash note %s" % ("in view" if in_view else "out of view"))

## Light strength 0..1 (1: brightest breath; above 1 only in the cut's flash).
func _set_light(strength: float) -> void:
	_material.set_shader_parameter(&"sub_emission_energy", lerpf(EMISSION_MIN, EMISSION_MAX, strength))
	_halo_material.albedo_color = Color(_color, HALO_ALPHA * minf(strength, 1.0))
	_ray_material.albedo_color = Color(_color, RAY_ALPHA * minf(strength, 1.0))

## A copy of the game's note model (with its own material) at the given edge length, added under this node.
func _add_note_mesh(edge: float) -> MeshInstance3D:
	var note := NOTE_SCENE.instantiate()
	var mesh := note.get_node(^"BeepCubeMesh") as MeshInstance3D
	note.remove_child(mesh)
	note.free()
	add_child(mesh)
	mesh.scale *= edge / (mesh.get_aabb().size.x * mesh.scale.x)
	return mesh

## Colours the note for the selected song: the player's dominant hand's colour from colors ([left, right], the
## map's or the player's per the Map colors chip), with a down arrow, or a dot while Arrows is off; the small note
## gets the other hand's colour.
func set_note(colors: Array[Color]) -> void:
	_note_saber = 0 if Settings.left_handed else 1
	_color = colors[_note_saber]
	_material.set_shader_parameter(&"color", _color)
	_material.set_shader_parameter(&"is_dot", not Settings.arrows_enabled)
	_material.set_shader_parameter(&"arrows_enabled", Settings.arrows_enabled)
	_other_material.set_shader_parameter(&"color", colors[1 - _note_saber])
	_other_material.set_shader_parameter(&"is_dot", not Settings.arrows_enabled)
	_other_material.set_shader_parameter(&"arrows_enabled", Settings.arrows_enabled)
	_label.text = SLASH_DOWN_TEXT if Settings.arrows_enabled else SLASH_TEXT

## Shows the note (placed for the player's eye height at that moment, facing them) or hides it and its hit area.
func set_shown(shown: bool) -> void:
	if shown and not _shown:
		var eyes := vr.vrCamera.global_position.y if vr.vrCamera else FALLBACK_EYES
		var side := -1.0 if Settings.left_handed else 1.0
		var yaw := deg_to_rad(YAW_DEGREES) * side
		global_position = Vector3(HORIZONTAL * sin(yaw), eyes - BELOW_EYES, PLAYER_Z - HORIZONTAL * cos(yaw))
		# its front (+z) toward the player, arrow still pointing straight down
		rotation = Vector3(0.0, -yaw, 0.0)
		_other_mesh.position = Vector3(OTHER_NOTE_CORNER.x * side, OTHER_NOTE_CORNER.y, 0.0) * NOTE_SIZE / 2.0
		_touching.clear()
	_shown = shown
	# the node stays visible so the cut halves (its children) can fly off
	_note_mesh.visible = shown
	_other_mesh.visible = shown
	_label.visible = shown
	if shown:
		if _flash:
			_flash.kill()
		_light.scale = Vector3.ONE
		_light.visible = true
	elif not _flash or not _flash.is_running():
		_light.visible = false
	collision_layer = CollisionLayerConstants.Ui_mask if shown else 0
	_material.set_shader_parameter(&"color", _color)

## Pointer over the note: brighter; trigger: plays.
func ui_raycast_hit_event(_pos: Vector3, click: bool, _release: bool) -> void:
	if not _shown:
		return
	_material.set_shader_parameter(&"color", _color.lerp(Color.WHITE, HOVER_WHITE))
	if click:
		_slash(null, global_transform.basis.x)

func ui_raycast_exit() -> void:
	_material.set_shader_parameter(&"color", _color)

## A saber blade or tip path entering the note while the tip is fast enough is a cut: the right one plays,
## a wrong one (other saber, or not along the arrow) buzzes and leaves the note there.
func _physics_process(_delta: float) -> void:
	if not _shown:
		return
	var box := AABB(-_half_size * SABER_HITBOX_SHARE, _half_size * 2.0 * SABER_HITBOX_SHARE)
	var to_local := global_transform.affine_inverse()
	for saber in sabers:
		var inside: bool = saber.is_extended() and (
				box.intersects_segment(to_local * saber.controller.global_position, to_local * saber.saber_end)
				or box.intersects_segment(to_local * saber.saber_end_past, to_local * saber.saber_end))
		if not inside:
			_touching.erase(saber)
			continue
		if saber in _touching or saber.last_dt <= 0.0:
			continue
		var velocity := (saber.saber_end - saber.saber_end_past) / saber.last_dt
		if velocity.length() < MIN_TIP_SPEED:
			continue
		_touching.append(saber)
		if _right_cut(saber, velocity):
			if Settings.cut_flash:
				GlobalReferences.main_game_scene.cut_flash.flash(global_position, velocity, _color)
			_slash(saber.controller, velocity.cross(saber.saber_end - saber.controller.global_position))
			return
		_sound.stream = WRONG_SOUND
		_sound.play()
		saber.controller.simple_rumble(WRONG_RUMBLE_STRENGTH, WRONG_RUMBLE_SECONDS)

## The note's saber (either one with Any saber, any colour) swinging along its arrow (down), or any way for a dot.
func _right_cut(saber: LightSaber, velocity: Vector3) -> bool:
	if saber.type != _note_saber and Settings.handedness != Constants.HANDEDNESS_IGNORE:
		return false
	if not Settings.arrows_enabled:
		return true
	var local := velocity.rotated(Vector3.UP, -rotation.y)
	return Vector3(local.x, local.y, 0.0).normalized().dot(Vector3.DOWN) >= MIN_DIRECTION_DOT

## Breaks the note in two along the cut (cut_normal: the cut plane's normal in world space; the pointer cuts
## it top to bottom), with a cut sound and a rumble on the hand that cut it, and asks for the song.
func _slash(controller: BeepSaberController, cut_normal: Vector3) -> void:
	set_shown(false)
	var normal := cut_normal.normalized()
	var local_normal := global_transform.basis.orthonormalized().inverse() * normal
	for i in _pieces.size():
		var piece := _pieces[i]
		var side := 1.0 if i == 0 else -1.0
		piece.mesh.material_override.set_shader_parameter(&"color", _color)
		piece.mesh.material_override.set_shader_parameter(&"is_dot", not Settings.arrows_enabled)
		piece.global_transform = global_transform
		# the cut goes through the middle of the note
		piece.start_cut_plane(local_normal * side, 0.0)
		piece.mesh.scale = _note_mesh.scale
		piece.apply_central_impulse(normal * side * SPLIT_IMPULSE)
	# the light flashes, then fades out with the halves
	_light.visible = true
	_halo_material.albedo_color = Color(_color, 1.0)
	_ray_material.albedo_color = Color(_color, 1.0)
	_flash = create_tween()
	_flash.tween_property(_light, ^"scale", Vector3.ONE * 1.5, FLASH_SECONDS)
	_flash.set_parallel(false)
	_flash.tween_method(func(fade: float) -> void:
		_halo_material.albedo_color = Color(_color, fade)
		_ray_material.albedo_color = Color(_color, fade * RAY_ALPHA / HALO_ALPHA), 1.0, 0.0, FADE_SECONDS)
	_flash.tween_callback(func() -> void: _light.visible = false)

	_sound.stream = CUT_SOUND
	_sound.play()
	if controller:
		controller.simple_rumble(RUMBLE_STRENGTH, RUMBLE_SECONDS)
	slashed.emit()

## Called by a cut half when it fades out (CutPiece); nothing to collect, the halves are reused.
func _on_cut_piece_died() -> void:
	pass
