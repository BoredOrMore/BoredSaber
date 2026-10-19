class_name DebugView
## Switches in Settings > Advanced, shown only with Show Debug Info, that leave a part of the scene out (or draw notes
## plain, or skip the colour grading) so its GPU cost can be measured on the headset. Each is a bit of the debug_view shader global; the shaders
## concerned check it. They last until the game closes and are never saved.

const WALLS := 1
const PLAIN_NOTES := 2
const LASERS := 4
const RINGS := 8
const SKY := 16
## turns off the WorldEnvironment's colour correction (the shadow tint), which may cost a full-screen pass per eye
const NO_GRADING := 32
## label and bit of each switch, in the order they show
const SWITCHES := [
	["Hide walls", WALLS],
	["Plain notes", PLAIN_NOTES],
	["Hide lasers", LASERS],
	["Hide rings and floor lines", RINGS],
	["Plain black sky", SKY],
	["No colour grading", NO_GRADING],
]

static var flags := 0:
	set(value):
		flags = value
		RenderingServer.global_shader_parameter_set(&"debug_view", value)
		var tree := Engine.get_main_loop() as SceneTree
		for node in tree.root.find_children("*", "WorldEnvironment", true, false):
			(node as WorldEnvironment).environment.adjustment_enabled = value & NO_GRADING == 0
		print("debug_view ", value)

static func set_flag(bit: int, on: bool) -> void:
	flags = flags | bit if on else flags & ~bit
