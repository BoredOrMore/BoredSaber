# BeepCube is the standard cube that will get cut by the sabers
extends Cuttable
class_name BeepCube

# emitted when the cube gets cutted, correct_saber is true if the right saber was used
signal cutted(correct_saber: bool)

# haptic strength for the sloppiest correct cut (a clean one is 1.0) and for a wrong-saber hit
const MIN_CUT_RUMBLE := 0.3
const WRONG_SABER_RUMBLE := 0.2
## Centre points, Beat Saber's formula (owner, 2026-10-26): the share 1 - d / CUT_CENTRE_REACH, d the cut plane's
## distance from the block's centre in metres at block size 100, full only on the centre and none from 0.3 m out
## (past the block's edge, so any cut that touches it earns some). Beat Saber gives 15 * (1 - Clamp01(d / 0.3f))
## (BeatLeader's open replay format, github.com/BeatLeader/BS-Open-Replay); ours is the same share of 20.
## It was full within 0.02 m and none at 0.19 m, much stricter further out (24% at 0.15 m, Beat Saber 50%).
const CUT_CENTRE_FULL := 0.0
const CUT_CENTRE_REACH := 0.3
## A cut counts when the swing is within 60° of the arrow (dot >= cos 60°), as Beat Saber does (owner's pick,
## 2026-10-25); it was about 46° (dot 0.7). The angle points ramp 0 to 1 across that range.
const GOOD_CUT_DOT := 0.5

@onready var mi := $BeepCubeMesh as MeshInstance3D
@onready var collision_big := $BeepCube_Big/CollisionBig as CollisionShape3D
@onready var collision_small := $BeepCube_Small/CollisionSmall as CollisionShape3D
@onready var slice_particles := $SliceParticles as BeepCubeSliceParticles

var which_saber: int
var is_dot: bool

# we store the mesh here as part of the BeepCube for easier access because we will
# reuse it when we create the cut cube pieces
var _mesh: Mesh
## the glossy default look's rounder body (tools/models/note_round.py); Classic notes keeps the scene's own mesh
const ROUND_MESH := preload("res://game/notes/BeepCube/note_round.glb")
static var _round: Mesh
var _classic: Mesh
var _mat: ShaderMaterial

var piece_left : CutPiece = null
var piece_right : CutPiece = null
var arc_head = false
var arc_tail = false
var chain_head = false

func _ready() -> void:
	_mat = mi.material_override as ShaderMaterial
	_classic = mi.mesh
	if _round == null:
		_round = LaserFixtures._model_mesh(ROUND_MESH)
	_mesh = _classic if Settings.classic_notes else _round
	mi.mesh = _mesh
	
	# init our cut pieces with unique copies of our own material for reference,
	# and enable "bouncy" physics behavior
	piece_left = CutPiece.new(self, _mesh, _mat.duplicate(true) as ShaderMaterial, true)
	piece_right = CutPiece.new(self, _mesh, _mat.duplicate(true) as ShaderMaterial, true)
	
	# slice_particles are within cube's tree, but want then to move in global space
	slice_particles.top_level = true
	
func spawn(note_info: ColorNoteInfo, current_beat: float) -> void:
	# re-enable our process_mode first otherwise it seems like Godot-internals
	# can behave weirdly (ex. AnimationPlayer won't always play correctly)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_mesh(_classic if Settings.classic_notes else _round)
	
	var color := Map.color_left if note_info.color == 0 else Map.color_right
	speed = Map.beat_distance * Map.beats_per_second()
	beat = note_info.beat
	which_saber = note_info.color
	is_dot = note_info.cut_angle >= Constants.DIRECTION8_COMPARE
	
	if is_dot:
		(collision_big.shape as BoxShape3D).size.y = 0.8
	else:
		(collision_big.shape as BoxShape3D).size.y = 0.5
		
	scale = Vector3(Settings.block_size/100.,Settings.block_size/100.,Settings.block_size/100.)
	transform.origin.x = Settings.LANE_DISTANCE_X * float(note_info.line_index) + Settings.LANE_ZERO_X
	transform.origin.y = Constants.layer_y(float(note_info.line_layer))
	transform.origin.z = -(note_info.beat - current_beat) * Map.beat_distance
	
	add_lane_rotation(note_info.rotation)
	
	rotation.z = note_info.cut_angle
	
	# No Arrows shows every note as a dot, as Beat Saber does and as the menu's slash note already did (owner,
	# 2026-10-27: the same look in every mode); its hit box stays the note's own
	var shows_dot := is_dot or not Settings.arrows_enabled
	piece_left.set_color(color, shows_dot)
	piece_right.set_color(color, shows_dot)
	_mat.set_shader_parameter(&"color", color)
	_mat.set_shader_parameter(&"is_dot", shows_dot)
	_mat.set_shader_parameter(&"arrows_enabled", Settings.arrows_enabled)
	# since cube instances get recycled, we gotta reset cubes that were chain
	# heads in a past life
	_mat.set_shader_parameter(&"is_chain_head", false)
	piece_left.set_chain_head(false)
	piece_right.set_chain_head(false)
	chain_head = false
	# and arc ends: a recycled cube that stayed an arc head gave every later note a full approach score without a swing
	arc_head = false
	arc_tail = false
	
	# separate cube collision layers to allow a diferent collider on right/wrong cuts.
	# opposing collision layers (ie. right note & left saber) will be placed on the
	# smalling collision shape, while similar collision layers (ie right note &
	# right saber) are placed on the larger collision shape.
	var is_left_note := note_info.color == 0
	var big_coll_area := $BeepCube_Big as Area3D
	big_coll_area.collision_layer = 0x0
	big_coll_area.set_collision_layer_value(CollisionLayerConstants.LeftNote_bit, is_left_note)
	big_coll_area.set_collision_layer_value(CollisionLayerConstants.RightNote_bit, not is_left_note)
	var small_coll_area := $BeepCube_Small as Area3D
	small_coll_area.collision_layer = 0x0
	small_coll_area.set_collision_layer_value(CollisionLayerConstants.LeftNote_bit, not is_left_note)
	small_coll_area.set_collision_layer_value(CollisionLayerConstants.RightNote_bit, is_left_note)
	
	start_jump(mi, note_info.cut_angle)
	
	slice_particles.reset()
	mi.visible = true

# call this when clearing the track
func clear_from_track() -> void:
	hide_cube()
	piece_left.hide_piece()
	piece_right.hide_piece()
	if ! is_released():
		release()

func hide_cube() -> void:
	mi.visible = false
	set_collision_disabled(true)
	# disable processing on this node and all children to help with performance
	process_mode = Node.PROCESS_MODE_DISABLED

func make_chain_head() -> void:
	_mat.set_shader_parameter(&"is_chain_head", true)
	piece_left.set_chain_head(true)
	piece_right.set_chain_head(true)
	chain_head = true

func on_miss() -> void:
	Scoreboard.bad_cut(global_transform.origin+Vector3(0,0,-3.5), lane_rotation, "miss")
	hide_cube()
	release()

func set_collision_disabled(value: bool) -> void:
	collision_big.disabled = value
	collision_small.disabled = value
	
func set_arc_head() -> void:
	arc_head = true

func set_arc_tail() -> void:
	arc_tail = true

func cut(saber: LightSaber, cut_speed: Vector3, cut_plane: Plane, controller: BeepSaberController) -> void:
	# compute the angle between the cube orientation and the cut direction
	cut_speed = cut_speed.rotated(Vector3(0,1,0), -rotation.y)
	var cut_direction_xy := -Vector3(cut_speed.x, cut_speed.y, 0.0).normalized()
	var base_cut_angle_accuracy := global_transform.basis.orthonormalized().y.dot(cut_direction_xy)
	var cut_distance := cut_plane.distance_to(global_transform.origin)
	
	if right_saber(saber.type, which_saber):
		var cut_angle_accuracy := angle_accuracy(global_transform.basis.orthonormalized().y, cut_speed,
				is_dot or not Settings.arrows_enabled)
		if cut_angle_accuracy < 1e-10:
			# a bad-angle cut, for working out the angle rule (owner, 2026-10-25): how far the swing was off the
			# arrow, how fast, and which note
			print("bad_angle off %.0f deg speed %.2f m/s beat %.2f arrow %.0f deg saber %d" % [
				rad_to_deg(acos(clampf(base_cut_angle_accuracy, -1.0, 1.0))), cut_speed.length(), beat,
				rad_to_deg(rotation.z), saber.type])
		var cut_distance_accuracy := centre_accuracy(cut_distance, Settings.block_size)
		var travel_distance_factor := controller.movement_aabb.get_longest_axis_size()
		travel_distance_factor = clampf((travel_distance_factor-0.5)/0.5, 0.0, 1.0)
		var beat_accuracy := beat_accuracy_at(global_transform.origin.z)
		Scoreboard.note_cut(saber, transform.origin, lane_rotation, beat_accuracy, cut_angle_accuracy, cut_distance_accuracy, travel_distance_factor, arc_head, arc_tail, chain_head)
		# replaces the saber's flat contact rumble: cleaner cuts kick harder
		controller.simple_rumble(lerpf(MIN_CUT_RUMBLE, 1.0, cut_angle_accuracy * cut_distance_accuracy), 0.1)
		cutted.emit(true)
	else:
		Scoreboard.bad_cut(transform.origin, lane_rotation, "wrong saber")
		controller.simple_rumble(WRONG_SABER_RUMBLE, 0.2)
		cutted.emit(false)
	
	var on_cut := global_transform.origin - cut_plane.normal * cut_distance
	if Settings.cut_flash:
		GlobalReferences.main_game_scene.cut_flash.flash(on_cut, cut_speed.rotated(Vector3(0, 1, 0), rotation.y),
				Map.color_right if saber.type == 1 else Map.color_left)
	# reset the movement tracking volume for the next cut
	controller.reset_movement_aabb()
	
	hide_cube()
	if Settings.cube_cuts_falloff:
		_start_cut_pieces(cut_plane)
		# release() will be called by Cuttable class when it sees both pieces die
	else:
		release() # release now instead of waiting for cut pieces to die off

## The judgement of a cut, apart from the scene so it can be tested (tests/test_cut.gd).
## Whether a saber may cut a note of note_saber's colour: its own colour, or any with One Saber or a handedness setting.
static func right_saber(saber_type: int, note_saber: int) -> bool:
	return saber_type == note_saber or Map.one_saber or Settings.handedness != 0

## How well a swing (its velocity, in the note's lane frame) follows the arrow (note_up points against the cut): 1
## straight along it, falling to 0 where the dot of the two reaches GOOD_CUT_DOT; always 1 with any_way (dots, No
## Arrows).
static func angle_accuracy(note_up: Vector3, cut_speed: Vector3, any_way: bool) -> float:
	if any_way:
		return 1.0
	var along := note_up.dot(-Vector3(cut_speed.x, cut_speed.y, 0.0).normalized())
	return clampf((along - GOOD_CUT_DOT) / (1.0 - GOOD_CUT_DOT), 0.0, 1.0)

## Beat Saber's centre share: 1 through the middle, 0 at CUT_CENTRE_REACH (scaled with the block size) or beyond.
static func centre_accuracy(cut_distance: float, block_size: float) -> float:
	return clampf((CUT_CENTRE_REACH - absf(cut_distance * 100.0 / block_size)) / (CUT_CENTRE_REACH - CUT_CENTRE_FULL),
			0.0, 1.0)

## How near the hit plane a note was cut (OpenSaber's scoring): full within half a metre, none a metre off.
static func beat_accuracy_at(z: float) -> float:
	return clampf((1.0 - absf(z - Constants.HIT_PLANE_Z)) / 0.5, 0.0, 1.0)

# cut the cube by creating two rigid bodies and using a CSGBox to create
# the cut plane
func _start_cut_pieces(cutplane: Plane) -> void:
	piece_left.scale = Vector3(Settings.block_size,Settings.block_size,Settings.block_size)/100.
	piece_right.scale = Vector3(Settings.block_size,Settings.block_size,Settings.block_size)/100.
	piece_left.global_transform = global_transform
	piece_right.global_transform = global_transform
	
	# calculate angle and position of the cut
	#var cut_angle_abs := Vector2(cutplane.normal.x, cutplane.normal.y).angle()
	
	_piece_death_count = 0

	var p := cutplane # ARP: fix rot global_transform * 
	piece_left.start_cut_plane(-p.normal, -p.d) # ARP: scale p.d for block size?
	piece_right.start_cut_plane(p.normal, p.d)
	
	# some impulse so the cube half moves
	var split_vector := p.normal * 3.0
	piece_left.apply_central_impulse(-split_vector) #piece_left.transform * -split_vector)
	piece_right.apply_central_impulse(split_vector)#piece_right.transform * split_vector)
	
	#slice_particles.global_transform.origin = global_transform.origin
	#slice_particles.rotation.z = cut_angle_abs+TAU*0.25
	#slice_particles.fire()

## Draws the note and its cut halves with `mesh` (Classic notes switched since the pool made it).
func _set_mesh(mesh: Mesh) -> void:
	if mesh == _mesh:
		return
	_mesh = mesh
	mi.mesh = mesh
	piece_left.mesh.mesh = mesh
	piece_right.mesh.mesh = mesh
