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
## 1 at the hit plane), so it fits every NJS. Full size from the start, at its own row's height all the way: ArcViewer
## has notes rise from a low start row, but in the Beat Saber recording a note's height stays nearly level over its
## last second (the look of falling from above is perspective), so the owner chose no rise (2026-10-28). It
## turns to its cut direction over the first JUMP_TURN_SHARE of the jump, easing out (sine). On 90/360 maps it also
## turns to face the player's head by p (JUMP_FACE_CHARACTERISTICS); in Standard, Beat Saber's recording showed no
## lean beyond plain perspective (doc/research/note-spawn-plan.md), so none. Untuned until seen on the headset.
const JUMP_TURN_SHARE := 0.3
const JUMP_FACE_CHARACTERISTICS: Array[String] = ["90Degree", "360Degree"]
## Before its jump a note flies in, as Beat Saber's (owner, 2026-10-28; ArcViewer's moveZ 300 m and moveTime 0.975 s):
## it spawns FLY_SECONDS before its jump starts and its visual rushes in from FLY_DISTANCE beyond the jump start,
## easing out (quadratic), so it arrives before the reaction time begins; its place and hitbox move on as before.
## Bombs, chain links (start_jump) and arcs (Arc.gd, by their head) fly the same way; walls don't.
const FLY_SECONDS := 0.975
const FLY_DISTANCE := 300.0
var _jump_visual: Node3D
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
		
## Turns it onto a lane turned `angle` radians about the player's standing point (Constants.LANE_PIVOT_Z).
func add_lane_rotation(angle):
	var c := cos(angle)
	var s := sin(angle)
	
	var x := transform.origin.x
	var z := transform.origin.z - Constants.LANE_PIVOT_Z
	transform.origin.x = c * x - s * z
	transform.origin.z = s * x + c * z + Constants.LANE_PIVOT_Z
	
	rotation.y = -angle
	
	lane_rotation = angle
	_forward = Vector3(-s, 0.0, c)

## Its place along its lane in the track's space as if the lane weren't turned: 0 on the hit plane, below 0 ahead.
func lane_z() -> float:
	return (transform.origin - Vector3(0.0, 0.0, Constants.LANE_PIVOT_Z)).dot(_forward) + Constants.LANE_PIVOT_Z

## Starts the jump of `visual` (the part the jump turns): it turns `turn` radians (the note's cut angle) to its cut
## direction (see JUMP_TURN_SHARE).
func start_jump(visual: Node3D, turn: float) -> void:
	_jump_visual = visual
	_jump_turn = turn
	_jump_face = Map.current_difficulty != null and Map.current_difficulty.characteristic in JUMP_FACE_CHARACTERISTICS
	_jump_visual.transform = Transform3D.IDENTITY
	_apply_jump()

## How far beyond its real place a visual `ahead` metres from the hit plane shows while it flies in (0 once it's at the
## jump start): FLY_DISTANCE beyond the jump start at spawn, easing out to it over FLY_SECONDS.
static func fly_offset(ahead: float) -> float:
	var beyond := ahead - Map.half_jump_beats * Map.beat_distance
	var flight := FLY_SECONDS * Map.beat_distance * Map.beats_per_second()
	if beyond <= 0.0 or flight <= 0.0:
		return 0.0
	var q := minf(beyond / flight, 1.0)
	return FLY_DISTANCE * q * q - beyond

## Puts the visual where its jump is now (and, before it, where it flies in).
func _apply_jump() -> void:
	var half := Map.half_jump_beats * Map.beat_distance
	var ahead := -lane_z()
	var p := clampf(1.0 - ahead / half, 0.0, 1.0) if half > 0.0 else 1.0
	var turned := sin(clampf(p / JUMP_TURN_SHARE, 0.0, 1.0) * PI * 0.5)
	var yaw := 0.0
	if _jump_face:
		var camera := get_viewport().get_camera_3d()
		if camera:
			var to_head := Basis(Vector3.UP, lane_rotation) * (camera.global_position - global_position)
			yaw = atan2(to_head.x, to_head.z) * p
	# the root turns by the cut angle (rotation.z) and lane; the visual undoes the part of the turn not done yet
	var basis := Basis(Vector3.BACK, -_jump_turn) * Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, _jump_turn * turned)
	var fly := fly_offset(ahead)
	var back := global_transform.basis.inverse() * (-_forward * fly) if fly != 0.0 else Vector3.ZERO
	_jump_visual.transform = Transform3D(basis, back)

func _physics_process(delta: float) -> void:
	if Scoreboard.paused or not is_visible_in_tree() or not Map.current_info: return
	
	transform.origin += speed * delta * _forward
	if _jump_visual:
		_apply_jump()
	var rz := lane_z() + Constants.HIT_PLANE_Z
	
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
