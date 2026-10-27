extends Node3D
class_name PointsLabelDriver


const LABEL_COUNT := 8

var points_label := []
var current_point_label :int = 0


func _ready():
	var points_label_ref := preload("res://game/hud/points_label.tscn")
	for i in range(LABEL_COUNT):
		var instance := points_label_ref.instantiate()
		points_label.append(instance)
		add_child(instance)

func show_points(_position: Vector3, _rotation: float, value: String):
	if value == "0":
		value = "x"
	var color := Constants.MISS_COLOR if value == "x" else Color(1,1,1)
	var good := Constants.SWING_GOOD_SCORE if Settings.swing_scoring else Constants.OPENSABER_GOOD_SCORE
	if value.get_slice(" ", 0).to_int() >= good:
		# a good cut stands out from an average one
		color = Constants.UI_ACCENT
	points_label[current_point_label].show_points(_position,_rotation,value,color)
	current_point_label += 1
	current_point_label %= LABEL_COUNT
