class_name DebugView
## Switches in Settings > Advanced, shown only with Show Debug Info, that leave a part of the scene out (or draw notes
## plain) so its GPU cost can be measured on the headset. Each is a bit of the debug_view shader global; the shaders
## concerned check it. They last until the game closes and are never saved.

const WALLS := 1
const PLAIN_NOTES := 2
const LASERS := 4
const RINGS := 8
const SKY := 16
const DUST := 128
## Not read by shaders: while on, a song steps through CYCLE_STEPS by itself (cycle_tick), so one run measures
## every part; the log line "debug_view N" marks each step for matching with the headset's GPU timings.
const CYCLE := 1024
## Not read by shaders: LowResGlow draws its unblurred glow solid magenta and logs how far it lands from the light.
const GLOW_ALIGN := 2048
const CYCLE_STEPS: Array[int] = [0, WALLS, PLAIN_NOTES, LASERS, RINGS, SKY, DUST]
const CYCLE_SECONDS := 10.0
## label and bit of each switch, in the order they show
const SWITCHES := [
	["Hide walls", WALLS],
	["Plain notes", PLAIN_NOTES],
	["Hide lasers", LASERS],
	["Hide rings and floor lines", RINGS],
	["Plain black sky", SKY],
	["Hide dust", DUST],
	["Measure each part (cycles the switches)", CYCLE],
	["Glow alignment: new glow magenta, offsets in the log", GLOW_ALIGN],
]

static var flags := 0:
	set(value):
		flags = value
		RenderingServer.global_shader_parameter_set(&"debug_view", value)
		print("debug_view ", value)

## While CYCLE is on, switches to the next of CYCLE_STEPS every CYCLE_SECONDS; call it every frame of a song.
static func cycle_tick() -> void:
	if flags & CYCLE == 0:
		return
	var step := int(Time.get_ticks_msec() / 1000.0 / CYCLE_SECONDS) % CYCLE_STEPS.size()
	var wanted := CYCLE | CYCLE_STEPS[step]
	if flags != wanted:
		flags = wanted

static func set_flag(bit: int, on: bool) -> void:
	flags = flags | bit if on else flags & ~bit
