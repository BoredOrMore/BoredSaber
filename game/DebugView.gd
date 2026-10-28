class_name DebugView
## Switches in Settings > Advanced, shown only with Show Debug Info, that leave a part of the scene out (or draw notes
## plain) so its GPU cost can be measured on the headset. Each is a bit of the debug_view shader global; the shaders
## concerned check it. They last until the game closes and are never saved.

const WALLS := 1
const PLAIN_NOTES := 2
const LASERS := 4
const RINGS := 8
const SKY := 16
## The scenery (EnvSolid) drawn one flat colour: the same pixels with none of the shading, to split its cost into
## the area it covers and its shader (benchmark only, tools/bench.sh --only fog).
const FLAT_SCENERY := 32
const DUST := 128
## Not read by shaders, for measuring a real song's parts (the cycle; apply sets them each frame of a song): the
## sabers' blades and trails hidden (they still cut), the cut flash and sparks hidden, the glow off, the glow at Soft's
## size whatever the setting, the 3D view's MSAA off.
const HIDE_SABERS := 64
const HIDE_CUT_FLASH := 256
const GLOW_OFF := 512
const MSAA_OFF := 32768
const GLOW_SOFT := 65536
## Not read by shaders, benchmark only (tools/bench.sh --only reflection): the floor reflection left out
## (FloorReflection), and the build-up sweep held fully on through the song (EventDriver._update_sweep).
const NO_REFLECTION := 131072
const FORCE_SWEEP := 262144
## Not read by shaders, benchmark only (tools/bench.sh --only cut_dust): the cuts' dust left out (CutFlash).
const NO_CUT_DUST := 524288
const EXTRAS := HIDE_SABERS | HIDE_CUT_FLASH | GLOW_OFF | MSAA_OFF | GLOW_SOFT
## Not read by shaders: while on, a song steps through CYCLE_STEPS by itself (cycle_tick), so one run measures
## every part; the log line "debug_view N" marks each step for matching with the headset's GPU timings.
const CYCLE := 1024
## Not read by shaders: LowResGlow draws its unblurred glow solid magenta and logs how far it lands from the light.
const GLOW_ALIGN := 2048
## Not read by shaders, A/B tests for LowResGlow's stripes in the headset: a 4x4 Bayer dither in its composite,
## no B-spline (bicubic) upsample (one bilinear tap of the blur), and foveation off while the glow is on.
const GLOW_DITHER := 4096
const GLOW_BICUBIC := 8192
const GLOW_NO_FOVEATION := 16384
const CYCLE_STEPS: Array[int] = [0, WALLS, PLAIN_NOTES, LASERS, RINGS, FLAT_SCENERY, SKY, DUST, HIDE_SABERS, HIDE_CUT_FLASH,
	GLOW_SOFT, GLOW_OFF, MSAA_OFF]
const CYCLE_SECONDS := 10.0
## label and bit of each switch, in the order they show
const SWITCHES := [
	["Hide walls", WALLS],
	["Plain notes", PLAIN_NOTES],
	["Hide lasers", LASERS],
	["Hide rings and floor lines", RINGS],
	["Plain black sky", SKY],
	["Hide dust", DUST],
	["Flat-colour scenery", FLAT_SCENERY],
	["Hide saber blades and trails", HIDE_SABERS],
	["Hide cut flash and sparks", HIDE_CUT_FLASH],
	["Glow off", GLOW_OFF],
	["Glow at Soft size", GLOW_SOFT],
	["MSAA off", MSAA_OFF],
	["Measure each part (cycles the switches)", CYCLE],
	["Glow alignment: new glow magenta, offsets in the log", GLOW_ALIGN],
	["Glow test: dither", GLOW_DITHER],
	["Glow test: no bicubic upsample", GLOW_BICUBIC],
	["Glow test: foveation off", GLOW_NO_FOVEATION],
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

## The extras (EXTRAS) last set; 0 is the game's own state, so a game that never turns one on never touches anything.
static var _applied := 0

## Sets the extras the flags ask for, when they change; call it every frame of a song.
static func apply(game: BeepSaber_Game) -> void:
	var extras := flags & EXTRAS
	if extras == _applied:
		return
	_applied = extras
	for saber: LightSaber in [game.left_saber, game.right_saber]:
		saber.saber_visual.visible = extras & HIDE_SABERS == 0
	game.cut_flash.visible = extras & HIDE_CUT_FLASH == 0
	game._sparks.visible = extras & HIDE_CUT_FLASH == 0
	var quality: Array = LowResGlow.QUALITIES.get(Settings.glow_quality, LowResGlow.QUALITIES["Soft"])
	LowResGlow.height = LowResGlow.QUALITIES["Soft"][0] if extras & GLOW_SOFT else quality[0]
	game.glow_override = BeepSaber_Game.Glow.NONE if extras & GLOW_OFF else -1
	game._apply_glow()
	game.get_viewport().msaa_3d = Viewport.MSAA_DISABLED if extras & MSAA_OFF else Settings.msaa_mode()

## The flag file (in the app data folder, put there over adb) that starts the cycle at the next song: one real song
## measured part by part, each step logged as "debug_view N" to match with the headset's GPU timings.
const CYCLE_FLAG_FILE := "debug_cycle"

## Turns the cycle on if the flag file is there (and removes it); call at a song's start.
static func cycle_from_flag() -> void:
	var path := Constants.APPDATA_PATH + CYCLE_FLAG_FILE
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		set_flag(CYCLE, true)

## Ends a cycle, putting everything back; call when a song ends.
static func end_cycle(game: BeepSaber_Game) -> void:
	if flags & CYCLE != 0:
		flags = 0
		apply(game)

static func set_flag(bit: int, on: bool) -> void:
	flags = flags | bit if on else flags & ~bit
