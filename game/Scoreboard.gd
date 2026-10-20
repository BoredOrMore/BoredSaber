extends Node

signal score_changed()
signal points_awarded(position: Vector3, rotation: float, amount: String)
## a hit that kept the combo going (combo and multiplier already updated)
signal combo_hit()
## the multiplier went up to x2, x4 or x8
signal multiplier_raised(multiplier: int)
## a miss, bad cut, bomb or wall broke the combo or lowered the multiplier; lost_combo is the combo it ended
signal combo_broken(lost_combo: int)

var points: int
var combo: int
## Beat Saber's combo multiplier: x1, x2, x4, x8. It doubles after 2 x multiplier hits in a row
## and halves on a miss, a bad cut, a bomb or a wall (bsmg.wiki/ranking-guide.html).
var multiplier: int
## hits since the multiplier last changed
var _multiplier_progress: int
var in_wall: bool
## The most points the notes so far could have given: each at its best score, with an unbroken combo.
## Accuracy is points over this, as in Beat Saber (bsmg.wiki/ranking-guide.html).
var max_points: int
var _notes_scored: int
var full_combo: bool
var paused: bool
var last_in_wall_time: float

func restart() -> void:
	last_in_wall_time = -1000.
	points = 0
	multiplier = 1
	_multiplier_progress = 0
	combo = 0
	max_points = 0
	_notes_scored = 0
	full_combo = true
	in_wall = false
	score_changed.emit()

func reset_combo(_wrong_note) -> void:
	var changed = false
	var broken := combo != 0 or multiplier != 1
	var lost_combo := combo
	_multiplier_progress = 0
	if multiplier != 1:
		@warning_ignore("integer_division")
		multiplier = multiplier / 2
		changed = true
	if combo != 0:
		combo = 0
		changed = true
	if full_combo:
		full_combo = false
		changed = true
	if changed:
		score_changed.emit()
	if broken:
		combo_broken.emit(lost_combo)

## How far the hits since the last multiplier change are toward the next one, 0..1 (1 at x8).
func multiplier_progress() -> float:
	return 1.0 if multiplier >= 8 else float(_multiplier_progress) / (2 * multiplier)

func enter_wall() -> void:
	var beat : float
	var time := GlobalReferences.main_game_scene.get_current_time()
	if last_in_wall_time < 0:
		GlobalReferences.main_game_scene.update_health(Constants.HEALTH_OBSTACLE_PER_SECOND *.1, not in_wall)
		last_in_wall_time = time
	elif time > 0 and last_in_wall_time >= 0 and last_in_wall_time + 0.1 <= time:
		GlobalReferences.main_game_scene.update_health(Constants.HEALTH_OBSTACLE_PER_SECOND *(time-last_in_wall_time))
		last_in_wall_time = time
	in_wall = true
	reset_combo(false)

func exit_wall() -> void:
	in_wall = false
	last_in_wall_time = -1000.

## Points over the most the notes so far could have given (1 before any note).
func accuracy() -> float:
	return clampf(float(points) / max_points, 0.0, 1.0) if max_points > 0 else 1.0

## The best score one note can get in the current scoring mode.
func note_best_score() -> float:
	if Settings.swing_scoring:
		return Constants.SWING_ACCURACY_SCORE + Constants.SWING_PRESWING_SCORE + Constants.SWING_FOLLOWTHROUGH_SCORE
	return Constants.OPENSABER_BEAT_ACCURACY_SCORE + Constants.OPENSABER_ANGLE_ACCURACY_SCORE + Constants.OPENSABER_DISTANCE_ACCURACY_SCORE

## Counts one more note toward max_points, at the multiplier a perfect combo would have by now:
## x1 for the first note, x2 for notes 2-5, x4 for notes 6-13, then x8.
func _count_note(best: float) -> void:
	_notes_scored += 1
	var perfect_multiplier := 1 if _notes_scored == 1 else 2 if _notes_scored <= 5 else 4 if _notes_scored <= 13 else 8
	max_points += int(best) * perfect_multiplier

## Adds a cut's points. best is the most this note could have given (0 uses a normal note's best).
func add_points(position: Vector3, _rotation: float, amount: int, comment: String = "", best: float = 0.0) -> void:
	if amount > 0:
		GlobalReferences.main_game_scene.update_health(Constants.HEALTH_HIT)
	
	var raised := false
	if not in_wall:
		combo += 1
		_multiplier_progress += 1
		if multiplier < 8 and _multiplier_progress >= 2 * multiplier:
			multiplier *= 2
			_multiplier_progress = 0
			raised = true
	points += amount * multiplier
	
	points_awarded.emit(position, _rotation, str(amount)+(comment if Settings.explain else ""))
	_count_note(best if best > 0.0 else note_best_score())
	score_changed.emit()
	if not in_wall:
		combo_hit.emit()
	if raised:
		multiplier_raised.emit(multiplier)
	
## A chain head has no follow-through part, so its best score is lower.
func add_swing_score(position: Vector3, _rotation: float, accuracy: float, preswing: float, followthrough: float, chain_head := false) -> void:
	var score := int(roundf(accuracy + 
					clampf(preswing/Constants.TARGET_PRESWING_ANGLE,0,1.)*Constants.SWING_PRESWING_SCORE + 
					clampf(followthrough/Constants.TARGET_FOLLOWTHROUGH_ANGLE,0.,1.)*Constants.SWING_FOLLOWTHROUGH_SCORE))
	add_points(position, _rotation, score, "  (%d %d %d)" % [int(roundf(accuracy)),int(roundf(preswing)),int(roundf(followthrough))],
			note_best_score() - Constants.SWING_FOLLOWTHROUGH_SCORE if chain_head else 0.0)

func chain_link_cut(position: Vector3, _rotation: float) -> void:
	var link_score := int(chain_link_best_score())
	add_points(position, _rotation, link_score, "", link_score)

## The most a chain link can give, for a missed link.
func chain_link_best_score() -> float:
	return Constants.SWING_CHAIN_LINK_SCORE if Settings.swing_scoring else Constants.OPENSABER_CHAIN_LINK_SCORE

func note_cut(saber: LightSaber, position: Vector3, _rotation: float, beat_accuracy: float, cut_angle_accuracy: float, cut_distance_accuracy: float, 
		travel_distance_factor: float, arc_head: bool, arc_tail: bool, chain_head: bool) -> void:
	
	if cut_angle_accuracy >= 1e-10: # and cut_distance_accuracy >= 1e-10:
		GlobalReferences.main_game_scene.event_driver.cut_wave(saber.type)
		if Settings.swing_scoring:
			if chain_head:
				saber.add_chain_head_score(position, _rotation, cut_distance_accuracy * Constants.SWING_ACCURACY_SCORE)
			else:
				# unless we have arc_head, we need to wait for followthrough to finish scoring
				saber.add_score(position, _rotation, cut_distance_accuracy * Constants.SWING_ACCURACY_SCORE, arc_head, arc_tail)
		else:
			# point computation based on the accuracy of the swing
			var points_new := beat_accuracy * Constants.OPENSABER_BEAT_ACCURACY_SCORE
			points_new += cut_angle_accuracy * Constants.OPENSABER_ANGLE_ACCURACY_SCORE
			points_new += cut_distance_accuracy * Constants.OPENSABER_DISTANCE_ACCURACY_SCORE
			points_new += points_new * travel_distance_factor
			points_new = roundf(points_new)
			add_points(position, _rotation, int(points_new))
	else:
		bad_cut(position, _rotation, "bad angle")

## A note lost to a miss or a bad cut still counts toward max_points; best is what it could have given
## (0 uses a normal note's best). Bombs are not notes.
func bad_cut(position: Vector3, _rotation: float, description: String, best: float = 0.0) -> void:
	GlobalReferences.main_game_scene.event_driver.mistake_dip()
	if description != "bomb":
		_count_note(best if best > 0.0 else note_best_score())
	if description == "bomb":
		GlobalReferences.main_game_scene.play_mistake_sound(true)
		reset_combo(false)
		GlobalReferences.main_game_scene.update_health(Constants.HEALTH_BOMB, true)
	elif description == "wrong saber" or description == "miss":
		if description == "wrong saber":
			GlobalReferences.main_game_scene.play_mistake_sound(false)
		reset_combo(true)
		GlobalReferences.main_game_scene.update_health(Constants.HEALTH_MISS, true)
		if description == "miss":
			description = ""
	else:
		GlobalReferences.main_game_scene.play_mistake_sound(false)
		reset_combo(true)
		GlobalReferences.main_game_scene.update_health(Constants.HEALTH_BAD_CUT, true)
	points_awarded.emit(position, _rotation, description if Settings.explain else "x")
