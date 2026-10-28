extends Node3D
class_name PointsLabel

## Cut numbers and MISS use the live grade letter's font (owner, 2026-10-28, after Beat Saber's bold popped numbers).
## Rendered from a 100 px font like the HUD (TextMesh caps font_size at 127, and small sizes tessellate coarsely);
## LABEL_HEIGHT is the old 9 px label's height in metres, grown by Hud.GRADE_FONT_SCALE for Kanit's smaller capitals.
const LABEL_FONT_SIZE := 100
const LABEL_HEIGHT := 0.09
const MISS_TEXT := "MISS"
const MISS_POP_SECONDS := 0.08
const MISS_HOLD_SECONDS := 0.12
const MISS_FADE_SECONDS := 0.3
const MISS_DRIFT := Vector3(0, -0.08, 0)

var text_mesh: TextMesh
var player: AnimationPlayer
var label: MeshInstance3D
var _miss_tween: Tween

func _ready():
	player = $AnimationPlayer as AnimationPlayer
	# gotta make a new text mesh for each one, otherwise they will all ref
	# the same one.  the result of that is if you change the text of one, you
	# change the text of all.
	label = $mesh_instance as MeshInstance3D
	label.mesh = label.mesh.duplicate(true) as TextMesh
	text_mesh = label.mesh as TextMesh
	text_mesh.font = Hud.GRADE_FONT
	text_mesh.font_size = LABEL_FONT_SIZE
	text_mesh.pixel_size = LABEL_HEIGHT * Hud.GRADE_FONT_SCALE / LABEL_FONT_SIZE

## Shows value at _position facing the player: MISS_TEXT pops as a miss, anything else plays the cut number's "hit".
func show_points(_position: Vector3, _rotation:float, value: String, color: Color):
	global_position = _position
	rotation.y = -_rotation
	if _miss_tween:
		_miss_tween.kill()
	player.stop()
	label.visible = true
	text_mesh.text = value
	# the cut's points in the numbers' font, MISS in the grade's
	text_mesh.font = Hud.GRADE_FONT if value == MISS_TEXT else Hud.NUMBER_FONT
	(text_mesh.material as StandardMaterial3D).albedo_color = color
	if value == MISS_TEXT:
		_show_miss()
		return
	player.play("hit")

## Pops MISS in, holds it briefly, then fades it out while it sinks a little.
func _show_miss() -> void:
	var material := text_mesh.material as StandardMaterial3D
	label.position = Vector3.ZERO
	label.scale = Vector3.ONE * 0.6
	_miss_tween = create_tween()
	_miss_tween.tween_property(label, ^"scale", Vector3.ONE, MISS_POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_miss_tween.tween_interval(MISS_HOLD_SECONDS)
	_miss_tween.set_parallel()
	_miss_tween.tween_property(label, ^"position", MISS_DRIFT, MISS_FADE_SECONDS)
	_miss_tween.tween_property(material, ^"albedo_color:a", 0.0, MISS_FADE_SECONDS)
	_miss_tween.chain().tween_callback(label.hide)
