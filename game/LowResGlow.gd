extends Node
class_name LowResGlow
## Glow without Godot's glow: Godot's glow makes the Compatibility renderer draw the scene into an internal buffer and
## copy it to the screen eye by eye (about 5 ms of the Pico 4's 13.9 ms frame in a song, measured), and makes MSAA
## resolve through it. Here the scene still draws straight to the screen; only the glow sources (GLOW_LAYER: the
## light show's lasers and bars) are drawn again by one camera at the middle of the eyes, whose off-axis frustum
## covers both eyes' views, into a small SubViewport (HEIGHT px), blurred once into a smaller one (BLUR_SCALE), and
## added over each eye's view by one full-screen quad in front of the XR camera, one bilinear tap a pixel.
## One view for both eyes (not one each) halves the extra render passes, which measured costlier than their pixels
## (a viewport per eye: +2 ms before blur); it ignores the eyes' parallax, under half a degree for lights 5 m or
## more away and hidden by the blur, which is why the saber blades (half a metre away: about 7 degrees) aren't
## glow sources. The camera takes the head pose at _process, a little before the frame's predicted pose, so the quad
## reprojects by rotation (the glow's view matrix is passed in). The sources keep their own materials, so the glow
## follows the light show (and its flash cap). Hidden in mixed reality.
## stage (for the benchmark): 0 off, 1 the SubViewport only, 2 and blur, 3 the full glow.

## The visual layer (bit 11) glow sources carry besides their own.
const GLOW_LAYER := 1 << 10
const HEIGHT := 188
## The blur pass's size relative to the glow image.
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
uniform sampler2D glow : filter_linear, repeat_disable, source_color;
// DebugView.GLOW_ALIGN: the unblurred glow image, solid magenta, to see where it lands
uniform sampler2D raw : filter_nearest, repeat_disable, source_color;
uniform bool debug = false;
// the glow camera's projection times its view rotation (no translation): reprojects by rotation only
uniform mat4 glow_rotation;
uniform float intensity = 0.8;
// the view ray of each corner, in world space (linear across the screen)
varying vec3 world_dir;
void vertex() {
	// the quad covers each eye's whole view
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
	// In stereo, VIEW_MATRIX is a camera behind both eyes and each eye's PROJECTION_MATRIX carries that eye's
	// offset from it, so a single unprojected point (at the near plane with reversed depth) isn't on the eye's ray
	// from that camera: take the ray between two points of it instead, which the offset doesn't turn.
	vec4 a = INV_PROJECTION_MATRIX * vec4(VERTEX.xy, 1.0, 1.0);
	vec4 b = INV_PROJECTION_MATRIX * vec4(VERTEX.xy, 0.0, 1.0);
	vec3 ray = a.xyz / a.w - b.xyz / b.w;
	// forward is -z in view space, whichever end the depth puts first
	ray *= ray.z > 0.0 ? -1.0 : 1.0;
	world_dir = mat3(INV_VIEW_MATRIX) * ray;
}
void fragment() {
	vec4 clip = glow_rotation * vec4(world_dir, 0.0);
	vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
	uv.y = 1.0 - uv.y;
	// a little noise so the soft falloff doesn't band
	float noise = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	ALBEDO = texture(glow, uv).rgb * intensity + noise / 255.0;
	if (debug) {
		ALBEDO = dot(texture(raw, uv).rgb, vec3(1.0)) > 0.1 ? vec3(1.0, 0.0, 1.0) : vec3(0.0);
	}
}
"""

var stage := 0:
	set(value):
		stage = value
		_apply_stage()

var _game: BeepSaber_Game
var _view := SubViewport.new()
var _camera := Camera3D.new()
var _blur := SubViewport.new()
var _blur_material := ShaderMaterial.new()
var _quad := MeshInstance3D.new()
var _quad_material := ShaderMaterial.new()

func _init(game: BeepSaber_Game) -> void:
	_game = game

func _ready() -> void:
	var black := Environment.new()
	black.background_mode = Environment.BG_COLOR
	black.background_color = Color.BLACK
	_view.size = Vector2i(HEIGHT, HEIGHT)
	# beams thinner than a pixel at this size would come out as dashes; on a tiled GPU the resolve stays in tile memory
	_view.msaa_3d = Viewport.MSAA_4X
	_camera.cull_mask = GLOW_LAYER
	_camera.environment = black
	_camera.projection = Camera3D.PROJECTION_FRUSTUM
	_camera.near = NEAR
	_camera.far = FAR
	_view.add_child(_camera)
	add_child(_view)

	var blur_shader := Shader.new()
	blur_shader.code = BLUR_SHADER
	_blur.size = Vector2i(Vector2(HEIGHT, HEIGHT) * BLUR_SCALE)
	_blur.disable_3d = true
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur_material.shader = blur_shader
	_blur_material.set_shader_parameter(&"source", _view.get_texture())
	rect.material = _blur_material
	_blur.add_child(rect)
	add_child(_blur)

	var shader := Shader.new()
	shader.code = COMPOSITE_SHADER
	_quad_material.shader = shader
	_quad_material.render_priority = Material.RENDER_PRIORITY_MAX
	_quad_material.set_shader_parameter(&"intensity", INTENSITY)
	_quad_material.set_shader_parameter(&"glow", _blur.get_texture())
	_quad_material.set_shader_parameter(&"raw", _view.get_texture())
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_quad.mesh = quad
	_quad.material_override = _quad_material
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# never culled: the vertex shader puts it over the whole view
	_quad.extra_cull_margin = 16384.0
	_game.get_node(^"XROrigin3D/XRCamera3D").add_child(_quad)
	tag_sources()
	_apply_stage()

## Puts the glow sources on GLOW_LAYER: the light show's lasers and bars.
func tag_sources() -> void:
	var driver := _game.event_driver
	for holder: Node in [driver.diagonal_lasers_holder, driver.square_lasers_holder, driver.left_waving_lasers_holder,
			driver.right_waving_lasers_holder]:
		for source: Node in holder.find_children("*", "MeshInstance3D", true, false):
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
	if not is_node_ready():
		return
	var shown := stage > 0 and not Settings.mixed_reality
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
	_blur.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown and stage >= 2 else SubViewport.UPDATE_DISABLED
	_quad.visible = shown and stage >= 3

func _process(_delta: float) -> void:
	if stage == 0:
		return
	var xr := XRServer.primary_interface
	var head := _game.get_node(^"XROrigin3D/XRCamera3D") as Camera3D
	# the frustum's left, right, bottom and top as tangents, over both eyes
	var bounds := Rect2()
	if xr and xr.is_initialized() and xr.get_view_count() == 2:
		var left := xr.get_transform_for_view(0, _game.xr_origin.global_transform)
		var right := xr.get_transform_for_view(1, _game.xr_origin.global_transform)
		_camera.global_transform = Transform3D(left.basis, (left.origin + right.origin) / 2.0)
		bounds = _tangents(xr.get_projection_for_view(0, 1.0, NEAR, FAR)).merge(_tangents(xr.get_projection_for_view(1, 1.0, NEAR, FAR)))
	else:
		# no headset (the desktop simulator): the one camera's view
		_camera.global_transform = head.global_transform
		bounds = _tangents(head.get_camera_projection())
	_match_frustum(bounds)
	var rotation := Projection(Transform3D(_camera.global_basis.orthonormalized().inverse(), Vector3.ZERO))
	_quad_material.set_shader_parameter(&"glow_rotation", _camera.get_camera_projection() * rotation)
	_blur_material.set_shader_parameter(&"texel", Vector2.ONE / Vector2(_view.size))
	var debug := DebugView.flags & DebugView.GLOW_ALIGN != 0
	_quad_material.set_shader_parameter(&"debug", debug)
	# the log also runs during a benchmark, to have the numbers with each measurement
	if (debug or _game.has_node(^"Benchmark")) and xr and xr.is_initialized() and xr.get_view_count() == 2:
		_log_offsets(xr, head)

var _log_time := 0.0
var _last_head := Basis()

## Once a second with DebugView.GLOW_ALIGN: for a few points, how far (degrees, + to the right) from the point each
## eye's glow lands, with the composite's ray math before this fix (one unprojected point, either depth end) and
## now, and the head's turning speed. Godot's stereo matrices are rebuilt here as set_multiview_camera makes them.
func _log_offsets(xr: XRInterface, head: Camera3D) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _log_time < 1.0:
		return
	var turn := rad_to_deg(_last_head.get_rotation_quaternion().angle_to(head.global_basis.get_rotation_quaternion())) / maxf(now - _log_time, 0.001)
	_last_head = head.global_basis
	_log_time = now
	var origin := _game.xr_origin.global_transform
	var eyes: Array[Transform3D] = [xr.get_transform_for_view(0, origin), xr.get_transform_for_view(1, origin)]
	var projections: Array[Projection] = [xr.get_projection_for_view(0, 1.0, head.near, head.far),
			xr.get_projection_for_view(1, 1.0, head.near, head.far)]
	var main := _multiview_camera(eyes, projections)
	var points := {"2m ahead": head.global_position - head.global_basis.z * 2.0,
			"laser 30m": head.global_position + Vector3(0.0, 10.0, -30.0)}
	for saber: Node3D in [_game.left_saber, _game.right_saber]:
		var tip := saber.find_child("tip", true, false) as Node3D
		if tip:
			points["%s tip" % saber.name] = tip.global_position
	var lines := PackedStringArray()
	for point_name: String in points:
		var point: Vector3 = points[point_name]
		var parts := PackedStringArray()
		for v in 2:
			var stereo := projections[v] * Projection((main.affine_inverse() * eyes[v]).affine_inverse())
			var clip := stereo * Projection(main.affine_inverse()) * Vector4(point.x, point.y, point.z, 1.0)
			var ndc := Vector2(clip.x, clip.y) / clip.w
			var near := _unproject(stereo, ndc, 1.0)
			var far := _unproject(stereo, ndc, -1.0)
			var eye := eyes[v].basis.orthonormalized()
			var seen := point - _camera.global_position
			var ray := far - near
			ray *= -1.0 if ray.z > 0.0 else 1.0
			parts.append("%s old(+1) %+.2f old(-1) %+.2f new %+.2f" % ["L" if v == 0 else "R",
					_yaw(main.basis * near, eye) - _yaw(seen, eye), _yaw(main.basis * far, eye) - _yaw(seen, eye),
					_yaw(main.basis * ray, eye) - _yaw(seen, eye)])
		lines.append("%s: %s" % [point_name, " | ".join(parts)])
	print("Glow offset deg (turning %.0f deg/s): %s" % [turn, " ; ".join(lines)])

static func _unproject(projection: Projection, ndc: Vector2, depth: float) -> Vector3:
	var p := projection.inverse() * Vector4(ndc.x, ndc.y, depth, 1.0)
	return Vector3(p.x, p.y, p.z) / p.w

## A direction's angle to the right of the eye's forward, in degrees, in the eye's horizontal plane.
static func _yaw(direction: Vector3, eye: Basis) -> float:
	return rad_to_deg(atan2(direction.dot(eye.x), -direction.dot(eye.z)))

## The camera Godot renders both eyes from (RendererSceneRender::CameraData::set_multiview_camera): looking between
## the eyes' left and right frustum planes, where the first eye's left plane meets the second's right plane.
static func _multiview_camera(eyes: Array[Transform3D], projections: Array[Projection]) -> Transform3D:
	var left := eyes[0] * projections[0].get_projection_plane(Projection.PLANE_LEFT)
	var right := eyes[1] * projections[1].get_projection_plane(Projection.PLANE_RIGHT)
	var z := (left.normal + right.normal).normalized()
	# backward, as a camera's z
	z *= -1.0 if z.dot(eyes[0].basis.z) < 0.0 else 1.0
	var y := eyes[0].basis.y.normalized()
	var x := y.cross(z).normalized()
	y = z.cross(x).normalized()
	var origin := eyes[0].origin
	var horizon := Plane(y, eyes[0].origin)
	var meet: Variant = horizon.intersect_3(left, right)
	if meet != null:
		origin = meet
	return Transform3D(Basis(x, y, z), origin)

## A projection's frustum as tangents: x from left to right, y from bottom to top.
static func _tangents(projection: Projection) -> Rect2:
	var width := 2.0 / projection.x.x
	var height := 2.0 / projection.y.y
	var centre := Vector2(projection.z.x * width / 2.0, projection.z.y * height / 2.0)
	return Rect2(centre - Vector2(width, height) / 2.0, Vector2(width, height))

## Sets the camera to an off-axis frustum: Camera3D can't take a matrix, but a frustum's height, centre offset and
## the viewport's aspect fix its left, right, bottom and top exactly.
func _match_frustum(bounds: Rect2) -> void:
	var size := Vector2i(roundi(HEIGHT * bounds.size.x / bounds.size.y), HEIGHT)
	if _view.size != size:
		_view.size = size
		_blur.size = Vector2i(Vector2(size) * BLUR_SCALE)
	_camera.set_frustum(bounds.size.y * NEAR, bounds.get_center() * NEAR, NEAR, FAR)
