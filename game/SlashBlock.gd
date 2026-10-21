extends UIRaycastTarget
class_name SlashBlock
## A note in front of the player in the song menu, below where Play was: cutting it the right way (its arrow,
## with the saber of its colour) plays the selected song, as does pointing at it and pulling the trigger. The song
## menu shows what it will play ("Slash to play · ...").

## The note was cut the right way, or clicked.
signal slashed()

## Where it floats, from the player's spot (z = PLAYER_Z, facing -z): YAW to the right, under the song menu's old
## Play button (24 degrees), HORIZONTAL metres away, BELOW_EYES under the eyes: 42 degrees down, its top 8 degrees
## under the menu's bottom edge (-24.8 degrees). The player moved it there from 20 degrees right, 39 down, one
## step at a time (tweak these two); 42 degrees is past the 40 degree limit for looking down, fine for one swing.
const YAW_DEGREES := 25.0
const HORIZONTAL := 0.9
const BELOW_EYES := 0.82
const PLAYER_Z := 1.0
## Edge of the note in metres (the game's notes are 0.4 m): smaller so its top stays under the menu's edge;
## still 19 degrees across at its distance.
const NOTE_SIZE := 0.3
## Eye height used when no headset camera is there (desktop runs).
const FALLBACK_EYES := 1.6
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
## The game's note model and look.
const NOTE_SCENE := preload("res://game/BeepCube/BeepCube.tscn")

## The sabers that can cut it, set by the game.
var sabers: Array[LightSaber] = []
## The saber type (LightSaber.type: 0 left, 1 right) whose colour the note has, and that colour.
var _note_saber := 1
var _color := Color.WHITE
var _material: ShaderMaterial
var _half_size := Vector3.ONE * 0.15
var _sound := AudioStreamPlayer3D.new()
var _shown := false
## A saber already inside the note: it counts once, when it enters.
var _touching: Array[LightSaber] = []

func _ready() -> void:
	collision_mask = 0
	# borrow the note mesh with its material from the game's note scene
	var note := NOTE_SCENE.instantiate()
	var mesh := note.get_node(^"BeepCubeMesh") as MeshInstance3D
	note.remove_child(mesh)
	note.free()
	add_child(mesh)
	_material = mesh.material_override as ShaderMaterial
	mesh.scale *= NOTE_SIZE / (mesh.get_aabb().size.x * mesh.scale.x)
	_half_size = Vector3.ONE * NOTE_SIZE / 2.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _half_size * 2.0
	shape.shape = box
	add_child(shape)
	add_child(_sound)
	set_shown(false)

## Colours the note for the selected song: the player's dominant hand's colour from colors ([left, right], the
## map's or the player's per the Map colors chip), with a down arrow, or a dot while Arrows is off.
func set_note(colors: Array[Color]) -> void:
	_note_saber = 0 if Settings.left_handed else 1
	_color = colors[_note_saber]
	_material.set_shader_parameter(&"color", _color)
	_material.set_shader_parameter(&"is_dot", not Settings.arrows_enabled)
	_material.set_shader_parameter(&"arrows_enabled", Settings.arrows_enabled)

## Shows the note (placed for the player's eye height at that moment, facing them) or hides it and its hit area.
func set_shown(shown: bool) -> void:
	if shown and not _shown:
		var eyes := vr.vrCamera.global_position.y if vr.vrCamera else FALLBACK_EYES
		var yaw := deg_to_rad(YAW_DEGREES)
		global_position = Vector3(HORIZONTAL * sin(yaw), eyes - BELOW_EYES, PLAYER_Z - HORIZONTAL * cos(yaw))
		# its front (+z) toward the player, arrow still pointing straight down
		rotation = Vector3(0.0, -yaw, 0.0)
		_touching.clear()
	_shown = shown
	visible = shown
	collision_layer = CollisionLayerConstants.Ui_mask if shown else 0
	_material.set_shader_parameter(&"color", _color)

## Pointer over the note: brighter; trigger: plays.
func ui_raycast_hit_event(_pos: Vector3, click: bool, _release: bool) -> void:
	if not _shown:
		return
	_material.set_shader_parameter(&"color", _color.lerp(Color.WHITE, HOVER_WHITE))
	if click:
		_slash(null)

func ui_raycast_exit() -> void:
	_material.set_shader_parameter(&"color", _color)

## A saber blade or tip path entering the note while the tip is fast enough is a cut: the right one plays,
## a wrong one (other saber, or not along the arrow) buzzes and leaves the note there.
func _physics_process(_delta: float) -> void:
	if not _shown:
		return
	var box := AABB(-_half_size, _half_size * 2.0)
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
			_slash(saber.controller)
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

## Hides the note with a cut sound and a rumble on the hand that cut it, and asks for the song.
func _slash(controller: BeepSaberController) -> void:
	set_shown(false)
	_sound.stream = CUT_SOUND
	_sound.play()
	if controller:
		controller.simple_rumble(RUMBLE_STRENGTH, RUMBLE_SECONDS)
	slashed.emit()
