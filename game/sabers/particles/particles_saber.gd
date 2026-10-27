extends DefaultSaber

# the node is named CPUParticles3D but is GPU particles; the scene's animations drive it by that name
@onready var particles := $CPUParticles3D as GPUParticles3D

func _ready() -> void:
	super()
	# off on the headset and the web, as before (they were freed there)
	if OS.get_name() in ["Android","Web"]:
		particles.visible = false
		particles.process_mode = Node.PROCESS_MODE_DISABLED

var last_tip_pos := Vector3.ZERO

func _process(delta: float) -> void:
	super(delta)
	var current_tip_pos := tip.global_transform.origin
	var speed := (current_tip_pos-last_tip_pos).length()
	particles.speed_scale = 2.5+(30*speed)
	last_tip_pos = current_tip_pos

func hit(time_offset: float) -> void:
	super(time_offset)
	hitsound.pitch_scale = randf_range(0.9,1.1)

func set_thickness(_value: float) -> void: #ignore set thinkness on this saber
	pass
