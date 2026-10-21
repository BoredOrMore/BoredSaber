extends UIRaycastTarget
class_name SlashBlock
## The cyan block in front of the player in the song menu: slashing it with either saber, or pointing at it and
## pulling the trigger, plays the selected song. The song menu shows what it will play ("Slash to play · ...").

## The block was slashed or clicked.
signal slashed()

## Edge length in metres: 16 degrees at DISTANCE, an easy target.
const SIZE := 0.25
## Where it floats: this far in front of the player's spot (z = PLAYER_Z, facing -z) and this far below their
## eyes, 35 degrees down: 0.96 m high for 1.6 m eyes, its top just under the song menu's bottom edge (-25 degrees).
const DISTANCE := 0.9
const BELOW_EYES := 0.64
const PLAYER_Z := 1.0
## Eye height used when no headset camera is there (desktop runs).
const FALLBACK_EYES := 1.6
## Slowest saber tip that counts as a slash, in m/s. Untuned: check on the headset that a deliberate swing
## cuts and resting a saber against the block doesn't.
const MIN_TIP_SPEED := 2.0
## Hover makes the block brighter by mixing toward white (root AGENTS.md "Light": hot core, no values over 1).
const HOVER_WHITE := 0.35
const RUMBLE_STRENGTH := 0.75
const RUMBLE_SECONDS := 0.1
const CUT_SOUND := preload("res://game/data/cut_1.wav")

## The sabers that can cut it, set by the game.
var sabers: Array[LightSaber] = []
var _material := StandardMaterial3D.new()
var _sound := AudioStreamPlayer3D.new()
var _shown := false

func _ready() -> void:
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * SIZE
	shape.shape = box
	add_child(shape)
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * SIZE
	var mesh := MeshInstance3D.new()
	mesh.mesh = cube
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Constants.UI_ACCENT
	mesh.material_override = _material
	add_child(mesh)
	_sound.stream = CUT_SOUND
	add_child(_sound)
	set_shown(false)

## Shows the block (placed for the player's eye height at that moment) or hides it and its hit area.
func set_shown(shown: bool) -> void:
	if shown and not _shown:
		var eyes := vr.vrCamera.global_position.y if vr.vrCamera else FALLBACK_EYES
		global_position = Vector3(0.0, eyes - BELOW_EYES, PLAYER_Z - DISTANCE)
	_shown = shown
	visible = shown
	collision_layer = CollisionLayerConstants.Ui_mask if shown else 0
	_material.albedo_color = Constants.UI_ACCENT

## Pointer over the block: brighter; trigger: a slash.
func ui_raycast_hit_event(_pos: Vector3, click: bool, _release: bool) -> void:
	if not _shown:
		return
	_material.albedo_color = Constants.UI_ACCENT.lerp(Color.WHITE, HOVER_WHITE)
	if click:
		_slash(null)

func ui_raycast_exit() -> void:
	_material.albedo_color = Constants.UI_ACCENT

## A saber blade or tip path crossing the block while the tip is fast enough is a slash.
func _physics_process(_delta: float) -> void:
	if not _shown:
		return
	var box := AABB(global_position - Vector3.ONE * SIZE / 2.0, Vector3.ONE * SIZE)
	for saber in sabers:
		if not saber.is_extended() or saber.last_dt <= 0.0:
			continue
		if (saber.saber_end - saber.saber_end_past).length() / saber.last_dt < MIN_TIP_SPEED:
			continue
		if box.intersects_segment(saber.controller.global_position, saber.saber_end) \
				or box.intersects_segment(saber.saber_end_past, saber.saber_end):
			_slash(saber.controller)
			return

## Hides the block with a cut sound and a rumble on the hand that cut it, and asks for the song.
func _slash(controller: BeepSaberController) -> void:
	set_shown(false)
	_sound.play()
	if controller:
		controller.simple_rumble(RUMBLE_STRENGTH, RUMBLE_SECONDS)
	slashed.emit()
