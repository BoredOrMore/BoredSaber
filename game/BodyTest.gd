## Body test: timed punch, squat and lean drills that get faster until the player can't keep up,
## then charged moves held for longer and longer, to measure how fast moves can follow each other
## and how long a stance can be held before the Workout mode is built.
## Every rep is printed to the log (lines starting "BODYTEST,") and saved as a CSV.
extends Node3D
class_name BodyTest

## The test ended (finished or cancelled); the game goes back to the song menu.
signal finished()

enum Drill { REACH, GUARD, LOW_STANCE, PUNCH_HARD, PUNCH_TOUCH, PUNCH_ALTERNATE, PUNCH_SAME_HAND, SQUAT, LEAN,
	CHARGE_PUNCH, SQUAT_UPPERCUT, SQUAT_STAND, DONE }
const DRILL_NAMES := ["reach", "guard", "low_stance", "punch_hard", "punch_touch", "punch_alternate", "punch_same_hand", "squat", "lean",
	"charge_punch", "squat_uppercut", "squat_stand", "done"]
const DRILL_INSTRUCTIONS := [
	"Stretch both arms straight ahead\nand hold them there",
	"Guard: both fists up at your cheekbones,\nelbows in. Hold it",
	"Low stance: feet wide, bend your knees\nas you would to start a punch. Hold it",
	"Punch each ball as HARD as you can",
	"Now just TOUCH each ball gently",
	"Punch the balls, left and right in turn.\nThey come faster and faster",
	"Punch the balls: 4 with your right,\nthen 4 with your left. Faster and faster",
	"Squat under each bar.\nThey come faster and faster",
	"Step to the side the arrow shows,\naway from the wall. Faster and faster",
	"Power punch: hold your guard until GO,\nthen punch the ball as hard as you can",
	"Squat with your guard up until GO,\nthen rise and uppercut the ball",
	"Squat and hold until GO,\nthen stand up as fast as you can",
	"",
]
## Seconds each drill's instructions show before its first rep.
const INTRO_SECONDS := 4.0
## Seconds the arms are held out for the reach measurement; only the second half is averaged.
const REACH_HOLD_SECONDS := 3.0
## Shorter than this (metres from head to hands, straight ahead) means the arms weren't stretched out.
const REACH_MIN := 0.3
## Seconds the guard and low stance are held; only the second half is averaged, like the reach.
const STANCE_HOLD_SECONDS := 4.0
## Reps of the hard and gentle punch drills, at a fixed slow pace.
const CALIBRATION_REPS := 6
const CALIBRATION_INTERVAL := 2.0
## Ramping drills: each step is REPS_PER_STEP reps at one interval; passing PASS_REPS of them makes
## the next step STEP_FACTOR times shorter, a failed step ends the drill. Untuned starting values:
## they only decide when a drill stops, every rep's raw timing is logged.
const REPS_PER_STEP := 8
const PASS_REPS := 6
const STEP_FACTOR := 0.85
const MAX_STEPS := 12
const START_INTERVAL := {
	Drill.PUNCH_ALTERNATE: 1.2,
	Drill.PUNCH_SAME_HAND: 1.2,
	Drill.SQUAT: 3.0,
	Drill.LEAN: 2.5,
}
## Targets sit this share of the measured reach in front of the head (untuned), this far below
## the eyes (about chin height) and this far to the side of the punching hand.
const TARGET_REACH_SHARE := 0.85
const TARGET_BELOW_EYES := 0.15
const TARGET_SIDE := 0.15
const TARGET_RADIUS := 0.11
const FIST_RADIUS := 0.045
## Squat and lean use the game's own wall rules: a crouch wall starts at row 2 (1.2 m) and the
## head is a sphere of 0.07 m (PlayerHead in BeepSaber_Game.tscn); a lean wall covers one middle
## column, whose inner edge is the centre line x = 0.
const HEAD_RADIUS := 0.07
const SQUAT_WALL_BOTTOM := Constants.CROUCH_WALL_BOTTOM
const SQUAT_HEAD_Y := SQUAT_WALL_BOTTOM - HEAD_RADIUS
const LEAN_HEAD_X := HEAD_RADIUS
## How far in front of the eyes the squat bar and lean wall stand.
const WALL_DISTANCE := 0.6
const WALL_THICKNESS := 0.06
## Charged moves: one rep per hold time, held longer each rep (untuned starting values). The stance
## must be reached within STANCE_TIMEOUT, kept for the whole hold, then the move done within
## RELEASE_WINDOW of GO; REST_SECONDS between reps.
const HOLD_STEPS: Array[float] = [1.0, 2.0, 3.0, 4.0, 6.0, 8.0]
const STANCE_TIMEOUT := 5.0
const RELEASE_WINDOW := 1.5
const REST_SECONDS := 1.5
## A fist counts as in the guard while it is no more than this much further from the eyes than in
## the measured guard (untuned).
const GUARD_TOLERANCE := 0.08
## The uppercut ball sits this far in front of the eyes, at standing chin height (untuned).
const UPPERCUT_DISTANCE := 0.35
## Standing back up means the eyes are within this of the standing height again (untuned).
const STAND_MARGIN := 0.1
enum Charge { STANCE, HOLD, RELEASE, REST }
const HIT_RUMBLE := 0.6
const HIT_RUMBLE_SECONDS := 0.08
## Where the instructions stand: 1.6 m in front of the eyes and 0.4 m above them (14 degrees up).
const TEXT_POSITION := Vector3(0, 2.0, -0.6)
const TEXT_PIXEL_SIZE := 0.004
const TEXT_FONT_SIZE := 28

var _game: BeepSaber_Game
var _camera: XRCamera3D
var _drill := Drill.REACH
var _intro_left := INTRO_SECONDS
## Drill clock in seconds since its first rep was due.
var _clock := 0.0
var _interval := 0.0
var _step := 0
var _rep := 0
var _step_passes := 0
var _rep_open := false
var _rep_hit := false
var _rep_hit_time := 0.0
var _rep_peak_speed := 0.0
## Squat: lowest head height; lean: furthest head x on the cued side, during the rep.
var _rep_extreme := 0.0
## True once the fist left the target (punch) or the head left the wall's space (squat, lean). Squat and
## lean keep it across reps, so staying down under the next wall doesn't count twice.
var _rep_was_clear := false
var _hand_right := true
var _reach_samples: Array[float] = []
var _head_height_samples: Array[float] = []
var _reach := 0.0
var _eye_height := 0.0
## Median distance of the left (x) and right (y) fist from the eyes in the guard.
var _guard := Vector2.ZERO
## How far the eyes dropped in the low stance.
var _low_drop := 0.0
var _standing_eyes := Vector3.ZERO
var _forward := Vector3.FORWARD
var _right := Vector3.RIGHT
var _last_fist := {}
## Fastest passed interval per ramping drill, in seconds (0 = none passed).
var _fastest := {}
## Peak punch speeds of the hard and gentle drills.
var _speeds := {Drill.PUNCH_HARD: [] as Array[float], Drill.PUNCH_TOUCH: [] as Array[float]}
## Longest hold kept and median release speed of each charged move.
var _charge_best := {}
var _charge_speeds := {Drill.CHARGE_PUNCH: [] as Array[float], Drill.SQUAT_UPPERCUT: [] as Array[float],
	Drill.SQUAT_STAND: [] as Array[float]}
var _charge := Charge.STANCE
## Seconds since the current charge phase began.
var _charge_clock := 0.0
var _last_head := Vector3.ZERO
var _csv: FileAccess

var _text: Label3D
var _target: MeshInstance3D
var _bar: MeshInstance3D
var _wall: MeshInstance3D
var _fists: Array[MeshInstance3D] = []

## Builds the drill props and fists on the game's controllers and opens the CSV file.
func setup(game: BeepSaber_Game) -> void:
	_game = game
	_camera = game.get_node("XROrigin3D/XRCamera3D") as XRCamera3D
	_text = Label3D.new()
	_text.position = TEXT_POSITION
	_text.pixel_size = TEXT_PIXEL_SIZE
	_text.font_size = TEXT_FONT_SIZE
	_text.modulate = Constants.UI_TEXT
	_text.outline_size = 0
	add_child(_text)
	_target = _make_mesh(SphereMesh.new(), Color.WHITE)
	(_target.mesh as SphereMesh).radius = TARGET_RADIUS
	(_target.mesh as SphereMesh).height = 2 * TARGET_RADIUS
	_bar = _make_mesh(BoxMesh.new(), Constants.DANGER_COLOR)
	_wall = _make_mesh(BoxMesh.new(), Constants.DANGER_COLOR)
	for controller: XRController3D in [game.left_controller, game.right_controller]:
		var fist := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = FIST_RADIUS
		sphere.height = 2 * FIST_RADIUS
		fist.mesh = sphere
		fist.material_override = _unshaded(Settings.color_left if controller == game.left_controller else Settings.color_right)
		controller.add_child(fist)
		_fists.append(fist)
	var dir := Constants.APPDATA_PATH + "bodytest/"
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	_csv = FileAccess.open(dir + "bodytest_%s.csv" % stamp, FileAccess.WRITE)
	if _csv == null:
		push_error("Body test: can't write %s (%s)" % [dir, error_string(FileAccess.get_open_error())])
	_log("drill,step,interval_ms,rep,hand,hit,time_ms,peak_speed_mps,head_extreme_m,outcome")
	_start_drill(Drill.REACH)

## Returns a hidden mesh child with an unshaded colour.
func _make_mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _unshaded(color)
	node.visible = false
	add_child(node)
	return node

## Returns an unshaded material of one colour (no lights needed on the Compatibility renderer).
func _unshaded(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

## Removes the fists from the controllers and closes the CSV, then reports the test as over.
func stop() -> void:
	for fist in _fists:
		fist.queue_free()
	_fists.clear()
	if _csv:
		_csv.close()
		_csv = null
	finished.emit()

## Prints one CSV line to the log and the file.
func _log(line: String) -> void:
	print("BODYTEST," + line)
	if _csv:
		_csv.store_line(line)
		_csv.flush()

## Shows a drill's instructions and resets its counters.
func _start_drill(drill: Drill) -> void:
	_drill = drill
	_intro_left = INTRO_SECONDS
	_clock = 0.0
	_step = 0
	_rep = 0
	_step_passes = 0
	_rep_open = false
	_rep_was_clear = false
	_target.visible = false
	_bar.visible = false
	_wall.visible = false
	_interval = START_INTERVAL.get(drill, CALIBRATION_INTERVAL)
	_charge = Charge.STANCE
	_charge_clock = 0.0
	if drill == Drill.DONE:
		_text.text = _summary() + "\n\nPull the trigger to go back"
		return
	_text.text = DRILL_INSTRUCTIONS[drill]

## Takes where the player stands and faces as the drill starts; targets and walls are placed from it.
func _take_stance() -> void:
	_standing_eyes = _camera.global_position
	_forward = _flat_forward()
	_right = _forward.cross(Vector3.UP)

## Returns the direction the head faces, flattened onto the floor.
func _flat_forward() -> Vector3:
	return -Vector3(_camera.global_basis.z.x, 0, _camera.global_basis.z.z).normalized()

func _process(delta: float) -> void:
	for controller: BeepSaberController in [_game.left_controller, _game.right_controller]:
		if controller.by_just_pressed() or controller.menu_just_pressed():
			stop()
			return
	if _drill == Drill.DONE:
		if _game.left_controller.trigger_just_pressed() or _game.right_controller.trigger_just_pressed():
			stop()
		return
	var velocities := _velocities(delta)
	if _intro_left > 0.0:
		_intro_left -= delta
		if _intro_left <= 0.0 and _drill > Drill.LOW_STANCE:
			_take_stance()
		return
	_clock += delta
	if _drill == Drill.REACH:
		_process_reach()
	elif _drill == Drill.GUARD or _drill == Drill.LOW_STANCE:
		_process_stance()
	elif _drill >= Drill.CHARGE_PUNCH:
		_process_charge(velocities, delta)
	else:
		_process_rep(velocities)

## Returns each fist's velocity (m/s) this frame keyed by "right" true/false, and the head's under "head".
func _velocities(delta: float) -> Dictionary:
	var velocities := {}
	for right: bool in [false, true]:
		var pos := (_game.right_controller if right else _game.left_controller).global_position
		velocities[right] = (pos - _last_fist[right]) / delta if _last_fist.has(right) and delta > 0.0 else Vector3.ZERO
		_last_fist[right] = pos
	var head := _camera.global_position
	velocities["head"] = (head - _last_head) / delta if delta > 0.0 else Vector3.ZERO
	_last_head = head
	return velocities

## Averages how far the hands reach straight ahead over the second half of the hold.
func _process_reach() -> void:
	var eyes := _camera.global_position
	var forward := _flat_forward()
	var hands := (_game.left_controller.global_position + _game.right_controller.global_position) * 0.5
	_text.text = "%s\n%d" % [DRILL_INSTRUCTIONS[Drill.REACH], ceili(REACH_HOLD_SECONDS - _clock)]
	if _clock > REACH_HOLD_SECONDS * 0.5:
		_reach_samples.append((hands - eyes).dot(forward))
		_head_height_samples.append(eyes.y)
	if _clock < REACH_HOLD_SECONDS:
		return
	_reach_samples.sort()
	_reach = _reach_samples[_reach_samples.size() >> 1]
	_reach_samples.clear()
	if _reach < REACH_MIN:
		_text.text = "Arms not straight out. Let's try again"
		_intro_left = INTRO_SECONDS
		_clock = 0.0
		return
	_head_height_samples.sort()
	_eye_height = _head_height_samples[_head_height_samples.size() >> 1]
	_head_height_samples.clear()
	_log("reach,0,0,0,,,,%.3f,%.3f" % [_reach, _eye_height])
	_start_drill(Drill.GUARD)

## Holds the guard or low stance and logs its median shape: for the guard each fist's distance from
## the eyes (in the time_ms and peak_speed columns, metres), for the low stance how far the eyes dropped.
func _process_stance() -> void:
	var eyes := _camera.global_position
	_text.text = "%s\n%d" % [DRILL_INSTRUCTIONS[_drill], ceili(STANCE_HOLD_SECONDS - _clock)]
	if _clock > STANCE_HOLD_SECONDS * 0.5:
		if _drill == Drill.GUARD:
			_reach_samples.append(_game.left_controller.global_position.distance_to(eyes))
			_head_height_samples.append(_game.right_controller.global_position.distance_to(eyes))
		else:
			_head_height_samples.append(_eye_height - eyes.y)
	if _clock < STANCE_HOLD_SECONDS:
		return
	_reach_samples.sort()
	_head_height_samples.sort()
	var median := _head_height_samples[_head_height_samples.size() >> 1]
	if _drill == Drill.GUARD:
		_guard = Vector2(_reach_samples[_reach_samples.size() >> 1], median)
		_log("guard,0,0,0,,,%.3f,%.3f," % [_guard.x, _guard.y])
	else:
		_low_drop = median
		_log("low_stance,0,0,0,,,,,%.3f" % _low_drop)
	_reach_samples.clear()
	_head_height_samples.clear()
	_start_drill((_drill + 1) as Drill)

## Opens, watches and closes the current rep of a punch, squat or lean drill.
func _process_rep(velocities: Dictionary) -> void:
	if not _rep_open:
		_open_rep()
	var elapsed := _clock - _rep * _interval
	var eyes := _camera.global_position
	match _drill:
		Drill.SQUAT:
			_rep_extreme = minf(_rep_extreme, eyes.y)
			if eyes.y > SQUAT_HEAD_Y:
				_rep_was_clear = true
			elif _rep_was_clear and not _rep_hit:
				_mark_hit(elapsed)
		Drill.LEAN:
			var x := eyes.x if _hand_right else -eyes.x
			_rep_extreme = maxf(_rep_extreme, x)
			if x < LEAN_HEAD_X:
				_rep_was_clear = true
			elif _rep_was_clear and not _rep_hit:
				_mark_hit(elapsed)
		_:
			if not _rep_hit:
				_rep_peak_speed = maxf(_rep_peak_speed, (velocities[_hand_right] as Vector3).dot(_forward))
				var fist := (_game.right_controller if _hand_right else _game.left_controller).global_position
				if fist.distance_to(_target.global_position) >= TARGET_RADIUS + FIST_RADIUS:
					_rep_was_clear = true
				elif _rep_was_clear:
					_mark_hit(elapsed)
					(_game.right_controller if _hand_right else _game.left_controller).simple_rumble(HIT_RUMBLE, HIT_RUMBLE_SECONDS)
	if elapsed >= _interval:
		_close_rep()

## Places the target, bar or wall for the next rep.
func _open_rep() -> void:
	_rep_open = true
	_rep_hit = false
	_rep_hit_time = 0.0
	_rep_peak_speed = 0.0
	if _drill != Drill.SQUAT and _drill != Drill.LEAN:
		_rep_was_clear = false
	match _drill:
		Drill.PUNCH_SAME_HAND:
			_hand_right = _rep % REPS_PER_STEP < REPS_PER_STEP >> 1
		Drill.SQUAT:
			_rep_extreme = INF
		Drill.LEAN:
			# alternate sides; true = step right (wall on the left column)
			_hand_right = _rep % 2 == 0
			_rep_extreme = -INF
		_:
			_hand_right = _rep % 2 == 0
	var ahead := _standing_eyes + _forward * WALL_DISTANCE
	match _drill:
		Drill.SQUAT:
			(_bar.mesh as BoxMesh).size = Vector3(4 * Constants.DEFAULT_LANE_DISTANCE_X * 0.5, WALL_THICKNESS, WALL_THICKNESS)
			_bar.global_position = Vector3(ahead.x, SQUAT_WALL_BOTTOM + WALL_THICKNESS * 0.5, ahead.z)
			_bar.visible = true
			_text.text = "SQUAT"
		Drill.LEAN:
			var height := _standing_eyes.y + HEAD_RADIUS
			(_wall.mesh as BoxMesh).size = Vector3(Constants.DEFAULT_LANE_DISTANCE_X, height, WALL_THICKNESS)
			var side := -0.5 if _hand_right else 0.5
			_wall.global_position = Vector3(side * Constants.DEFAULT_LANE_DISTANCE_X, height * 0.5, ahead.z)
			_wall.visible = true
			_text.text = "STEP RIGHT  >>" if _hand_right else "<<  STEP LEFT"
		_:
			_target.global_position = (_standing_eyes + _forward * _reach * TARGET_REACH_SHARE
				+ _right * (TARGET_SIDE if _hand_right else -TARGET_SIDE) + Vector3.DOWN * TARGET_BELOW_EYES)
			(_target.material_override as StandardMaterial3D).albedo_color = Settings.color_right if _hand_right else Settings.color_left
			_target.visible = true

## Records the moment the rep's move was done and hides the target, bar or wall.
func _mark_hit(elapsed: float) -> void:
	_rep_hit = true
	_rep_hit_time = elapsed
	_rep_was_clear = false
	_target.visible = false
	_bar.visible = false
	_wall.visible = false

## Logs the rep and moves on to the next rep, step or drill.
func _close_rep() -> void:
	_rep_open = false
	_target.visible = false
	_bar.visible = false
	_wall.visible = false
	var hand := ""
	if _drill != Drill.SQUAT:
		hand = ("right" if _hand_right else "left") if _drill != Drill.LEAN else ("to_right" if _hand_right else "to_left")
	var extreme := "" if _drill != Drill.SQUAT and _drill != Drill.LEAN else "%.3f" % _rep_extreme
	var speed := "" if _drill == Drill.SQUAT or _drill == Drill.LEAN else "%.2f" % _rep_peak_speed
	_log("%s,%d,%d,%d,%s,%d,%s,%s,%s," % [DRILL_NAMES[_drill], _step, roundi(_interval * 1000), _rep, hand,
		int(_rep_hit), str(roundi(_rep_hit_time * 1000)) if _rep_hit else "", speed, extreme])
	if _rep_hit:
		_step_passes += 1
		if _speeds.has(_drill):
			(_speeds[_drill] as Array[float]).append(_rep_peak_speed)
	_rep += 1
	if _drill == Drill.PUNCH_HARD or _drill == Drill.PUNCH_TOUCH:
		if _rep >= CALIBRATION_REPS:
			_start_drill((_drill + 1) as Drill)
		return
	if _rep % REPS_PER_STEP != 0:
		return
	var passed := _step_passes >= PASS_REPS
	if passed:
		_fastest[_drill] = _interval
	_step += 1
	_step_passes = 0
	if not passed or _step >= MAX_STEPS:
		_start_drill((_drill + 1) as Drill)
		return
	# restart the clock so the next step's reps fall on its own interval
	_clock -= _rep * _interval
	_rep = 0
	_interval *= STEP_FACTOR

## Returns the results the player sees at the end.
func _summary() -> String:
	var lines: Array[String] = ["Done! Your results:"]
	for drill: Drill in [Drill.PUNCH_ALTERNATE, Drill.PUNCH_SAME_HAND, Drill.SQUAT, Drill.LEAN]:
		var label: String = {
			Drill.PUNCH_ALTERNATE: "Punches, left-right",
			Drill.PUNCH_SAME_HAND: "Punches, same hand",
			Drill.SQUAT: "Squats",
			Drill.LEAN: "Side steps",
		}[drill]
		var fastest: float = _fastest.get(drill, 0.0)
		lines.append("%s: %s" % [label, "one every %.2f s" % fastest if fastest > 0.0 else "too fast from the start"])
	lines.append("Guard: fists %d and %d cm from your eyes   Low stance: %d cm lower" % [
		roundi(_guard.x * 100), roundi(_guard.y * 100), roundi(_low_drop * 100)])
	for drill: Drill in [Drill.CHARGE_PUNCH, Drill.SQUAT_UPPERCUT, Drill.SQUAT_STAND]:
		var label: String = {
			Drill.CHARGE_PUNCH: "Power punch",
			Drill.SQUAT_UPPERCUT: "Squat + uppercut",
			Drill.SQUAT_STAND: "Squat + stand up",
		}[drill]
		var best: float = _charge_best.get(drill, 0.0)
		lines.append("%s: %s, release %s" % [label, "held %d s" % roundi(best) if best > 0.0 else "no hold kept",
			_median_text(_charge_speeds[drill])])
	lines.append("Hard punch: %s   Gentle touch: %s" % [_median_text(_speeds[Drill.PUNCH_HARD]), _median_text(_speeds[Drill.PUNCH_TOUCH])])
	return "\n".join(lines)

## Returns the median speed as text, or a dash when there were no hits.
func _median_text(speeds: Array[float]) -> String:
	if speeds.is_empty():
		return "-"
	var sorted := speeds.duplicate()
	sorted.sort()
	return "%.1f m/s" % sorted[sorted.size() >> 1]

## Returns whether the player is in the stance the current charged move asks for.
func _in_charge_stance() -> bool:
	var eyes := _camera.global_position
	var guard := (_game.left_controller.global_position.distance_to(eyes) <= _guard.x + GUARD_TOLERANCE
		and _game.right_controller.global_position.distance_to(eyes) <= _guard.y + GUARD_TOLERANCE)
	var squat := eyes.y <= SQUAT_HEAD_Y
	match _drill:
		Drill.CHARGE_PUNCH:
			return guard
		Drill.SQUAT_UPPERCUT:
			return guard and squat
		_:
			return squat

## Runs one charged rep: get into the stance, hold it for this rep's time, then release on GO.
func _process_charge(velocities: Dictionary, delta: float) -> void:
	var hold := HOLD_STEPS[_rep]
	_charge_clock += delta
	match _charge:
		Charge.STANCE:
			_hand_right = _rep % 2 == 0
			_text.text = "%s\nGet into position" % DRILL_INSTRUCTIONS[_drill]
			if _in_charge_stance():
				_charge = Charge.HOLD
				_charge_clock = 0.0
			elif _charge_clock >= STANCE_TIMEOUT:
				_end_charge(hold, "no_stance")
		Charge.HOLD:
			_text.text = "HOLD  %d" % ceili(hold - _charge_clock)
			if not _in_charge_stance():
				_end_charge(hold, "broke_at_%d" % roundi(_charge_clock * 1000))
			elif _charge_clock >= hold:
				_charge = Charge.RELEASE
				_charge_clock = 0.0
				_rep_peak_speed = 0.0
				_text.text = "GO!"
				if _drill != Drill.SQUAT_STAND:
					var distance := _reach * TARGET_REACH_SHARE if _drill == Drill.CHARGE_PUNCH else UPPERCUT_DISTANCE
					_target.global_position = (_standing_eyes + _forward * distance
						+ _right * (TARGET_SIDE if _hand_right else -TARGET_SIDE) + Vector3.DOWN * TARGET_BELOW_EYES)
					(_target.material_override as StandardMaterial3D).albedo_color = Settings.color_right if _hand_right else Settings.color_left
					_target.visible = true
		Charge.RELEASE:
			var hand := _game.right_controller if _hand_right else _game.left_controller
			var done := false
			match _drill:
				Drill.CHARGE_PUNCH:
					_rep_peak_speed = maxf(_rep_peak_speed, (velocities[_hand_right] as Vector3).dot(_forward))
					done = hand.global_position.distance_to(_target.global_position) < TARGET_RADIUS + FIST_RADIUS
				Drill.SQUAT_UPPERCUT:
					_rep_peak_speed = maxf(_rep_peak_speed, (velocities[_hand_right] as Vector3).y)
					done = hand.global_position.distance_to(_target.global_position) < TARGET_RADIUS + FIST_RADIUS
				_:
					_rep_peak_speed = maxf(_rep_peak_speed, (velocities["head"] as Vector3).y)
					done = _camera.global_position.y >= _standing_eyes.y - STAND_MARGIN
			if done:
				hand.simple_rumble(HIT_RUMBLE, HIT_RUMBLE_SECONDS)
				(_charge_speeds[_drill] as Array[float]).append(_rep_peak_speed)
				_charge_best[_drill] = maxf(_charge_best.get(_drill, 0.0), hold)
				_end_charge(hold, "ok", _charge_clock)
			elif _charge_clock >= RELEASE_WINDOW:
				_end_charge(hold, "missed")
		Charge.REST:
			if _charge_clock >= REST_SECONDS:
				_rep += 1
				if _rep >= HOLD_STEPS.size():
					_start_drill((_drill + 1) as Drill)
					return
				_charge = Charge.STANCE
				_charge_clock = 0.0

## Logs the charged rep (release time and speed only when it was done) and rests before the next one.
func _end_charge(hold: float, outcome: String, release_time := -1.0) -> void:
	var ok := release_time >= 0.0
	_log("%s,0,%d,%d,%s,%d,%s,%s,,%s" % [DRILL_NAMES[_drill], roundi(hold * 1000), _rep,
		"" if _drill == Drill.SQUAT_STAND else ("right" if _hand_right else "left"), int(ok),
		str(roundi(release_time * 1000)) if ok else "", "%.2f" % _rep_peak_speed if ok else "", outcome])
	_target.visible = false
	if ok:
		_text.text = "Nice!"
	elif outcome == "no_stance":
		_text.text = "Didn't see the stance"
	elif outcome == "missed":
		_text.text = "Too late"
	else:
		_text.text = "Stance lost"
	_charge = Charge.REST
	_charge_clock = 0.0
