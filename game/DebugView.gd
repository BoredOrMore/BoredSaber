class_name DebugView
## Switches in Settings > Advanced, shown only with Show Debug Info, that leave a part of the scene out (or draw notes
## plain) so its GPU cost can be measured on the headset. Each is a bit of the debug_view shader global; the shaders
## concerned check it. They last until the game closes and are never saved.

const WALLS := 1
const PLAIN_NOTES := 2
const LASERS := 4
const RINGS := 8
const SKY := 16
## label and bit of each switch, in the order they show
const SWITCHES := [
	["Hide walls", WALLS],
	["Plain notes", PLAIN_NOTES],
	["Hide lasers", LASERS],
	["Hide rings and floor lines", RINGS],
	["Plain black sky", SKY],
]

static var flags := 0:
	set(value):
		flags = value
		RenderingServer.global_shader_parameter_set(&"debug_view", value)
		print("debug_view ", value)

static func set_flag(bit: int, on: bool) -> void:
	flags = flags | bit if on else flags & ~bit
