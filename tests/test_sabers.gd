extends Node
# Headless check that every saber visual in Settings.SABER_VISUALS loads, colours and runs a frame without a script
# error stopping it part-way, and the right saber's mirrored angle. Run: godot --headless --path . res://tests/test_sabers.tscn

var failures := 0
var _done: Array[String] = []

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

## A script error inside returns early, so the saber never reaches _done.
func _try(saber_name: String, path: String) -> void:
	var saber := (load(path) as PackedScene).instantiate() as DefaultSaber
	add_child(saber)
	saber.set_color(Color.RED)
	saber._process(0.016)
	var particles: Variant = saber.get(&"particles")
	if particles != null or saber.has_node(^"CPUParticles3D"):
		check(particles is GPUParticles3D, "%s finds its particles" % saber_name)
	_done.append(saber_name)

## With mirroring on, the right saber takes the left one's angle with yaw and roll reversed; the defaults still turn
## both 5 degrees outward; off, the right saber keeps its own angle.
func _check_mirrored_rotation() -> void:
	var saved: Array = [Settings.mirror_saber_rotation, Settings.left_saber_offset_rot, Settings.right_saber_offset_rot]
	check(Settings.default_values[&"mirror_saber_rotation"] == true
			and Settings.mirrored(Settings.default_values[&"left_saber_offset_rot"]) == Settings.default_values[&"right_saber_offset_rot"],
			"mirroring is on by default and gives the right saber its default angle")
	Settings.mirror_saber_rotation = true
	Settings.left_saber_offset_rot = Vector3(10, 5, -3)
	Settings.right_saber_offset_rot = Vector3(0, 5, 0)
	check(Settings.right_saber_rotation() == Vector3(10, -5, 3),
			"mirrored, the right saber turns as the left reversed (got %s)" % Settings.right_saber_rotation())
	Settings.mirror_saber_rotation = false
	check(Settings.right_saber_rotation() == Vector3(0, 5, 0),
			"not mirrored, the right saber keeps its own angle (got %s)" % Settings.right_saber_rotation())
	Settings.mirror_saber_rotation = saved[0]
	Settings.left_saber_offset_rot = saved[1]
	Settings.right_saber_offset_rot = saved[2]

func _ready() -> void:
	for visual in Settings.SABER_VISUALS:
		_try(visual[0], visual[1])
		check(visual[0] in _done, "%s loads, takes a colour and runs a frame" % visual[0])
	_check_mirrored_rotation()
	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
