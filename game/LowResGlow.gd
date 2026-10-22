extends Node
class_name LowResGlow
## Glow without Godot's glow: Godot's glow makes the Compatibility renderer draw the scene into an internal buffer and
## copy it to the screen eye by eye (about 6 ms of the Pico 4's 13.9 ms frame, measured), and makes MSAA resolve
## through it. Here the scene still draws straight to the screen; only the glow sources (GLOW_LAYER: lasers, saber
## blades) are drawn again, for each eye, by a camera matching that eye into a small SubViewport (EYE_HEIGHT px),
## blurred once into a smaller one (BLUR_SCALE), and added over the view by one full-screen quad in front of the
## XR camera that reads its eye's blurred image (VIEW_INDEX), one bilinear tap a pixel. The glow cameras take the
## eye poses at _process, a little before the frame's predicted pose, so the quad reprojects by rotation (the
## glow's view matrix is passed in). The sources keep their own materials, so the glow follows the light show
## (and its flash cap). Hidden in mixed reality.
## stage (for the benchmark): 0 off, 1 SubViewports only, 2 and blur, 3 the full glow.

## The visual layer (bit 11) glow sources carry besides their own.
const GLOW_LAYER := 1 << 10
const EYE_HEIGHT := 376
## The blur pass's size relative to an eye image.
const BLUR_SCALE := 0.5
const INTENSITY := 0.8
const NEAR := 0.05
const FAR := 1000.0

const BLUR_SHADER := """
shader_type canvas_item;
// Dual-filter (Kawase) downsample: the centre and four diagonal taps half a source texel out, each bilinear (so 16
// texels), into an image half the size.
uniform sampler2D source : filter_linear, repeat_disable;
uniform vec2 texel;
void fragment() {
	vec4 sum = texture(source, UV) * 4.0;
	sum += texture(source, UV + vec2(-texel.x, -texel.y) * 1.5);
	sum += texture(source, UV + vec2(texel.x, -texel.y) * 1.5);
	sum += texture(source, UV + vec2(-texel.x, texel.y) * 1.5);
	sum += texture(source, UV + vec2(texel.x, texel.y) * 1.5);
	COLOR = vec4(sum.rgb / 8.0, 1.0);
}
"""

const COMPOSITE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D glow_left : filter_linear, repeat_disable, source_color;
uniform sampler2D glow_right : filter_linear, repeat_disable, source_color;
// each glow camera's projection times its view rotation (no translation): reprojects by rotation only
uniform mat4 glow_left_rotation;
uniform mat4 glow_right_rotation;
uniform float intensity = 0.8;
// the view ray of each corner, in world space (linear across the screen)
varying vec3 world_dir;
void vertex() {
	// the quad covers each eye's whole view
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * vec4(VERTEX.xy, 1.0, 1.0);
	world_dir = mat3(INV_VIEW_MATRIX) * (view.xyz / view.w);
}
void fragment() {
	bool right = VIEW_INDEX == VIEW_RIGHT;
	vec4 clip = (right ? glow_right_rotation : glow_left_rotation) * vec4(world_dir, 0.0);
	vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
	uv.y = 1.0 - uv.y;
	vec3 glow = right ? texture(glow_right, uv).rgb : texture(glow_left, uv).rgb;
	// a little noise so the soft falloff doesn't band
	float noise = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	ALBEDO = glow * intensity + noise / 255.0;
}
"""

var stage := 0:
	set(value):
		stage = value
		_apply_stage()

var _game: BeepSaber_Game
var _eyes: Array[SubViewport] = []
var _cameras: Array[Camera3D] = []
var _blurs: Array[SubViewport] = []
var _blur_materials: Array[ShaderMaterial] = []
var _quad := MeshInstance3D.new()
var _quad_material := ShaderMaterial.new()

func _init(game: BeepSaber_Game) -> void:
	_game = game

func _ready() -> void:
	var black := Environment.new()
	black.background_mode = Environment.BG_COLOR
	black.background_color = Color.BLACK
	var blur_shader := Shader.new()
	blur_shader.code = BLUR_SHADER
	for eye in 2:
		var port := SubViewport.new()
		port.size = Vector2i(EYE_HEIGHT, EYE_HEIGHT)
		port.render_target_update_mode = SubViewport.UPDATE_DISABLED
		port.msaa_3d = Viewport.MSAA_DISABLED
		var camera := Camera3D.new()
		camera.cull_mask = GLOW_LAYER
		camera.environment = black
		camera.projection = Camera3D.PROJECTION_FRUSTUM
		camera.near = NEAR
		camera.far = FAR
		port.add_child(camera)
		add_child(port)
		_eyes.append(port)
		_cameras.append(camera)

		var blur := SubViewport.new()
		blur.size = Vector2i(EYE_HEIGHT * BLUR_SCALE, EYE_HEIGHT * BLUR_SCALE)
		blur.render_target_update_mode = SubViewport.UPDATE_DISABLED
		blur.disable_3d = true
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		var material := ShaderMaterial.new()
		material.shader = blur_shader
		material.set_shader_parameter(&"source", port.get_texture())
		rect.material = material
		blur.add_child(rect)
		add_child(blur)
		_blurs.append(blur)
		_blur_materials.append(material)

	var shader := Shader.new()
	shader.code = COMPOSITE_SHADER
	_quad_material.shader = shader
	_quad_material.render_priority = Material.RENDER_PRIORITY_MAX
	_quad_material.set_shader_parameter(&"intensity", INTENSITY)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_quad.mesh = quad
	_quad.material_override = _quad_material
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# never culled: the vertex shader puts it over the whole view
	_quad.extra_cull_margin = 16384.0
	_quad.visible = false
	_game.get_node(^"XROrigin3D/XRCamera3D").add_child(_quad)
	tag_sources()
	_apply_stage()

## Puts the glow sources on GLOW_LAYER: the light show's lasers and bars, and the saber blades.
func tag_sources() -> void:
	var driver := _game.event_driver
	var sources: Array[Node] = []
	for holder: Node in [driver.diagonal_lasers_holder, driver.square_lasers_holder, driver.left_waving_lasers_holder,
			driver.right_waving_lasers_holder]:
		sources.append_array(holder.find_children("*", "MeshInstance3D", true, false))
	for saber: Node in [_game.left_saber, _game.right_saber]:
		sources.append_array(saber.find_children("LightSaber_Mesh", "MeshInstance3D", true, false))
	for source: Node in sources:
		(source as VisualInstance3D).layers |= GLOW_LAYER
	# the sky sphere hides the beams' far ends in the view: a black copy of it hides them in the glow too
	var sky := driver.get_node(^"Level/Sphere") as MeshInstance3D
	var occluder := MeshInstance3D.new()
	occluder.mesh = sky.mesh
	occluder.layers = GLOW_LAYER
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	occluder.material_override = black
	occluder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.add_child(occluder)

func _apply_stage() -> void:
	if _eyes.is_empty():
		return
	var shown := stage > 0 and not Settings.mixed_reality
	for eye in 2:
		_eyes[eye].render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
		_blurs[eye].render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown and stage >= 2 else SubViewport.UPDATE_DISABLED
	_quad.visible = shown and stage >= 3
	_quad_material.set_shader_parameter(&"glow_left", _blurs[0].get_texture())
	_quad_material.set_shader_parameter(&"glow_right", _blurs[1].get_texture())

func _process(_delta: float) -> void:
	if stage == 0:
		return
	var xr := XRServer.primary_interface
	var head := _game.get_node(^"XROrigin3D/XRCamera3D") as Camera3D
	for eye in 2:
		var camera := _cameras[eye]
		var projection: Projection
		if xr and xr.is_initialized() and xr.get_view_count() == 2:
			camera.global_transform = xr.get_transform_for_view(eye, _game.xr_origin.global_transform)
			projection = xr.get_projection_for_view(eye, 1.0, NEAR, FAR)
		else:
			# no headset (the desktop simulator): both eyes see what the one camera sees
			camera.global_transform = head.global_transform
			projection = head.get_camera_projection()
		_match_frustum(eye, projection)
		var rotation := Projection(Transform3D(camera.global_basis.orthonormalized().inverse(), Vector3.ZERO))
		_quad_material.set_shader_parameter(&"glow_right_rotation" if eye == 1 else &"glow_left_rotation",
				camera.get_camera_projection() * rotation)
		_blur_materials[eye].set_shader_parameter(&"texel", Vector2.ONE / Vector2(_eyes[eye].size))

## Sets an eye camera to the off-axis frustum of projection: Camera3D can't take a matrix, but a frustum's
## height, centre offset and the viewport's aspect fix its left, right, bottom and top exactly.
func _match_frustum(eye: int, projection: Projection) -> void:
	var width := 2.0 * NEAR / projection.x.x
	var height := 2.0 * NEAR / projection.y.y
	var offset := Vector2(projection.z.x * width / 2.0, projection.z.y * height / 2.0)
	var size := Vector2i(roundi(EYE_HEIGHT * width / height), EYE_HEIGHT)
	if _eyes[eye].size != size:
		_eyes[eye].size = size
		_blurs[eye].size = Vector2i(size * BLUR_SCALE)
	_cameras[eye].set_frustum(height, offset, NEAR, FAR)
