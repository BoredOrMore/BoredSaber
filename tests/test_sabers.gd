extends Node
# Headless check that every saber visual in Settings.SABER_VISUALS loads, colours and runs a frame without a script
# error stopping it part-way. Run: godot --headless --path . res://tests/test_sabers.tscn

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

func _ready() -> void:
	for visual in Settings.SABER_VISUALS:
		_try(visual[0], visual[1])
		check(visual[0] in _done, "%s loads, takes a colour and runs a frame" % visual[0])
	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
