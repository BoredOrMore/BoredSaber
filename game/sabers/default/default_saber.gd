extends Node3D
class_name DefaultSaber

var is_extended := false

@onready var _anim := $AnimationPlayer as AnimationPlayer
@onready var light_mesh := $LightSaber_Mesh as MeshInstance3D
@onready var _mat := light_mesh.material_override as ShaderMaterial
@onready var tip := $tip as Marker3D
@onready var tail := $tail as SaberTail
@onready var hitsound := $hitsound as AudioStreamPlayer3D
## the hilt's accent ring; the particle saber's scene has none
@onready var _ring := get_node_or_null(^"Hilt/Ring") as MeshInstance3D

## The blade's glow (SaberHalo.gdshader): drawn with the blade, so it sits on it in both eyes, while Glow is on with
## the Soft or Sharp style (Classic is Godot's glow, which already lights the blade) and not in mixed reality.
var _halo := MeshInstance3D.new()
var _halo_mat := ShaderMaterial.new()

func _ready() -> void:
	_halo_mat.shader = preload("res://game/sabers/default/SaberHalo.gdshader")
	_halo.mesh = QuadMesh.new()
	_halo.material_override = _halo_mat
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.layers = light_mesh.layers
	# the vertex shader places it along the blade, wider than the quad's bounds
	_halo.extra_cull_margin = 2.0
	light_mesh.add_child(_halo)
	Settings.changed.connect(func(key: StringName) -> void:
		if key in [&"glare", &"glow_quality", &"mixed_reality"]:
			_show_halo())
	_show_halo()
	quickhide()

func _show_halo() -> void:
	_halo.visible = Settings.glare and Settings.glow_quality != "Classic" and not Settings.mixed_reality

## The halo follows the blade's length as it turns on and off.
func _process(_delta: float) -> void:
	if _halo.visible:
		_halo_mat.set_shader_parameter(&"blade_length", (light_mesh.mesh as CapsuleMesh).height)

## The blade's colour.
func get_color() -> Color:
	return _mat.get_shader_parameter(&"color")

func set_color(color: Color) -> void:
	_mat.set_shader_parameter(&"color", color)
	_halo_mat.set_shader_parameter(&"color", color)
	if _ring:
		(_ring.material_override as ShaderMaterial).set_shader_parameter(&"accent", color)
	tail.set_color(color)

func set_thickness(value: float) -> void:
	light_mesh.scale.x = value
	light_mesh.scale.z = value

func set_trail(enabled: bool = true) -> void:
	tail.visible = enabled

func _show() -> void:
	#if Settings.claws:
		#$Hilt_Mesh.rotation_degrees.x = 90
		#$Hilt_Mesh.position.y = .02
		#$Hilt_Mesh.position.z = -.02
		#rotation_degrees.x = -90
	#else:
		#$Hilt_Mesh.rotation_degrees.x = 0
		#$Hilt_Mesh.position.y = -.03
		#$Hilt_Mesh.position.z = 0
		#tip.rotation_degrees.x = 0
		#rotation_degrees.x = 0
	_anim.play(&"ShowShort" if Settings.claws else &"Show")
	is_extended = true
	
func _hide() -> void:
	#$Hilt_Mesh.show()
	_anim.play(&"HideShort" if Settings.claws else &"Hide")
	is_extended = false
	
func quickhide() -> void:
	#$Hilt_Mesh.show()
	_anim.play(&"QuickHide")
	is_extended = false

func hit(time_offset: float) -> void:
	if tail.visible:
		tail.flash()
	if time_offset>0.2 or time_offset<-0.05:
		hitsound.play()
	else:
		if time_offset <= 0:
			hitsound.play(-time_offset)
		else:
			await get_tree().create_timer(time_offset).timeout
			hitsound.play()
