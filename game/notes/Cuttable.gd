extends PooledNode3D
class_name Cuttable

var speed: float
var beat: float
var lane_rotation := 0.
# direction of travel (the basis z without scale), set with the lane rotation
var _forward := Vector3(0, 0, 1)

## Beat Saber's note jump (owner, 2026-10-28; doc/research/note-spawn-plan.md, option C; the motion from ArcViewer,
## github.com/AllPoland/ArcViewer, NoteManager/JumpManager): the note's visual (start_jump) jumps in, its place and
## hitbox stay on the track. Driven by jump progress p, the share of the half jump it has covered (0 where it appears,
## 1 at the hit plane), so it fits every NJS. Full size from the start. Its height rises on a falling-ball arc from
## its start row to its own row, level at the hit plane: y = row - drop (1 - p)^2. The start row is JUMP_FLOOR_DROP
## under the bottom row, JUMP_ROW_STEP up for each note stacked below it on the same beat (Map.set_start_rows). It
## turns to its cut direction over the first JUMP_TURN_SHARE of the jump, easing out (sine). On 90/360 maps it also
## turns to face the player's head by p (JUMP_FACE_CHARACTERISTICS); in Standard, Beat Saber's recording showed no
## lean beyond plain perspective (doc/research/note-spawn-plan.md), so none. Untuned until seen on the headset.
const JUMP_TURN_SHARE := 0.3
const JUMP_ROW_STEP := 0.6
const JUMP_FLOOR_DROP := 0.6
const JUMP_FACE_CHARACTERISTICS: Array[String] = ["90Degree", "360Degree"]
var _jump_visual: Node3D
var _jump_drop := 0.0
var _jump_turn := 0.0
var _jump_face := false

# used to release the cube once both of it's cut pieces have died off
# Note: serves no purpose for bombs
var _piece_death_count := 0

# overridden by bombs and cubes
@warning_ignore("unused_parameter")
func set_collision_disabled(value: bool) -> void:
	return

# overriden by bombs and cubes
@warning_ignore("unused_parameter")
func cut(saber: LightSaber, cut_speed: Vector3, cut_plane: Plane, controller: BeepSaberController) -> void:
	return

# this too
func on_miss() -> void:
	return

func _on_cut_piece_died():
	_piece_death_count += 1
	if _piece_death_count >= 2:
		release()
		
func add_lane_rotation(angle):
	var c := cos(angle)
	var s := sin(angle)
	
	var x := transform.origin.x
	var z := transform.origin.z
	transform.origin.x = c * x - s * z
	transform.origin.z = s * x + c * z
	
	rotation.y = -angle
	
	lane_rotation = angle
	_forward = Vector3(-s, 0.0, c)

## How far below its row a note in row `layer` with `start_row` notes stacked below it starts its jump (metres).
static func jump_drop(layer: float, start_row: int) -> float:
	return Constants.layer_y(layer) - (Constants.layer_y(0.0) - JUMP_FLOOR_DROP + JUMP_ROW_STEP * start_row)

## Starts the jump of `visual` (the part the jump moves): it rises `drop` metres to its row and turns `turn` radians
## (the note's cut angle) to its cut direction (see JUMP_TURN_SHARE).
func start_jump(visual: Node3D, drop: float, turn: float) -> void:
	_jump_visual = visual
	_jump_drop = drop
	_jump_turn = turn
	_jump_face = Map.current_difficulty != null and Map.current_difficulty.characteristic in JUMP_FACE_CHARACTERISTICS
	_jump_visual.transform = Transform3D.IDENTITY
	_apply_jump()

## Puts the visual where its jump is now.
func _apply_jump() -> void:
	var half := Map.half_jump_beats * Map.beat_distance
	var p := clampf(1.0 - (-transform.origin.dot(_forward)) / half, 0.0, 1.0) if half > 0.0 else 1.0
	var rest := 1.0 - p
	var turned := sin(clampf(p / JUMP_TURN_SHARE, 0.0, 1.0) * PI * 0.5)
	var yaw := 0.0
	if _jump_face:
		var camera := get_viewport().get_camera_3d()
		if camera:
			var to_head := Basis(Vector3.UP, lane_rotation) * (camera.global_position - global_position)
			yaw = atan2(to_head.x, to_head.z) * p
	# the root turns by the cut angle (rotation.z) and lane; the visual undoes the part of the turn not done yet
	var basis := Basis(Vector3.BACK, -_jump_turn) * Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, _jump_turn * turned)
	_jump_visual.transform = Transform3D(basis, transform.basis.inverse() * Vector3(0.0, -_jump_drop * rest * rest, 0.0))

func _physics_process(delta: float) -> void:
	if Scoreboard.paused or not is_visible_in_tree() or not Map.current_info: return
	
	transform.origin += speed * delta * _forward
	if _jump_visual:
		_apply_jump()
	var rz := global_transform.origin.dot(_forward)
	
	if rz > -3.0:
		set_collision_disabled(false)
	if rz > Constants.MISS_Z:
		on_miss()

	# enable collisions when cuttable gets close enough to player
	#if global_transform.origin.z > -3.0:
	#	set_collision_disabled(false)
	
	# remove children that go to far
	#if global_transform.origin.z > Constants.MISS_Z:
	#	on_miss()

	#var rz := global_transform.rotated(Vector3(0,1,0), -rotation.y).origin.z
