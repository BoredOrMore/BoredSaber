extends UIRaycastTarget
class_name SlashBlock
## A note beside the player in the song menu, on the dominant hand's side: cutting it the right way (its arrow,
## with the saber of its colour) breaks it apart and plays the selected song, as does pointing at it and pulling
## the trigger. The song menu shows what it will play ("Slash to play · ...").

## The note was cut the right way, or clicked.
signal slashed()

## Where it floats, from the player's spot (z = PLAYER_Z, facing -z): YAW to the dominant hand's side, HORIZONTAL
## metres away, BELOW_EYES under the eyes (0.85 m high for 1.6 m eyes): 33 degrees down, 1.37 m from the eyes and
## 1.1 m from the shoulder, so a relaxed swing with the arm out cuts it with the middle of the blade (at 0.8 m the
## player had to pull the arm in). The player has to turn to it, and no saber reaches it while using the song menu:
## blades 1.25 m long, from hands 0.3-0.5 m in front of the body, pointed anywhere on the menu and flicked 25
## degrees up or down, stay 0.42 m clear of it. 75 degrees is past the 55 degree comfortable head turn on purpose:
## the body turns for one swing. Mirrored for left-handed players.
const YAW_DEGREES := 75.0
const HORIZONTAL := 1.15
const BELOW_EYES := 0.75
const PLAYER_Z := 1.0
## Edge of the note in metres (the game's notes are 0.4 m): 12.5 degrees across at its distance.
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
## Push that throws the two halves of a cut note apart (the game's notes use the same).
const SPLIT_IMPULSE := 2.0
## The game's note model and look.
const NOTE_SCENE := preload("res://game/BeepCube/BeepCube.tscn")

## The sabers that can cut it, set by the game.
var sabers: Array[LightSaber] = []
## The saber type (LightSaber.type: 0 left, 1 right) whose colour the note has, and that colour.
var _note_saber := 1
var _color := Color.WHITE
var _material: ShaderMaterial
var _other_material: ShaderMaterial
var _note_mesh: MeshInstance3D
var _other_mesh: MeshInstance3D
## The halves a cut note breaks into (the game's CutPiece).
var _pieces: Array[CutPiece] = []
var _half_size := Vector3.ONE * 0.15
var _sound := AudioStreamPlayer3D.new()
var _shown := false
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
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _half_size * 2.0
	shape.shape = box
	add_child(shape)
	add_child(_sound)
	set_shown(false)

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
	_sound.stream = CUT_SOUND
	_sound.play()
	if controller:
		controller.simple_rumble(RUMBLE_STRENGTH, RUMBLE_SECONDS)
	slashed.emit()

## Called by a cut half when it fades out (CutPiece); nothing to collect, the halves are reused.
func _on_cut_piece_died() -> void:
	pass
