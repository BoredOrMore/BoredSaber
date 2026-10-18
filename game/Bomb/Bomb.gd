extends Cuttable
class_name Bomb

@export var min_speed := 0.5
@onready var collision_shape := $Area3D/CollisionShape3D as CollisionShape3D

func set_collision_disabled(value: bool) -> void:
	collision_shape.disabled = value

@warning_ignore("unused_parameter")
func cut(saber: LightSaber, cut_speed: Vector3, cut_plane: Plane, controller: BeepSaberController) -> void:
	Scoreboard.bad_cut(transform.origin, lane_rotation, "bomb")
	hide_pooled()
	release()

func on_miss() -> void:
	hide_pooled()
	release()

## Hides the bomb and stops its processing while it waits in the pool.
func hide_pooled() -> void:
	visible = false
	set_collision_disabled(true)
	($AnimationPlayer as AnimationPlayer).stop()
	process_mode = Node.PROCESS_MODE_DISABLED

# call this when clearing the track
func clear_from_track() -> void:
	hide_pooled()
	if not is_released():
		release()

func spawn(info: BombInfo, current_beat: float) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	speed = Map.beat_distance * Map.beats_per_second()
	beat = info.beat
	
	var distance: float = info.beat - current_beat
	
	transform.origin.x = Settings.LANE_DISTANCE_X * float(info.line_index) + Settings.LANE_ZERO_X
	transform.origin.y = Constants.LANE_DISTANCE_Y * float(info.line_layer) + Constants.LAYER_ZERO_Y
	transform.origin.z = -distance * Map.beat_distance
	
	add_lane_rotation(info.rotation)
	
	var anim := $AnimationPlayer as AnimationPlayer
	var anim_speed := Map.current_difficulty.note_jump_movement_speed / 9.0
	anim.speed_scale = maxf(min_speed, anim_speed)
	anim.play(&"Spawn")
