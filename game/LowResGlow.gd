extends Node
class_name LowResGlow
## Glow without Godot's glow: Godot's glow makes the Compatibility renderer draw the scene into an internal buffer and
## copy it to the screen eye by eye (about 5 ms of the Pico 4's 13.9 ms frame in a song, measured), and makes MSAA
## resolve through it. Here the scene still draws straight to the screen; only the glow sources (GLOW_LAYER: the
## light show's lasers and bars) are drawn again by one camera at the middle of the eyes, whose off-axis frustum
## covers both eyes' views, into a small SubViewport (height px), blurred by a dual-filter chain (BLUR_CHAIN: down
## twice, up once, each a SubViewport), and added over each eye's view by one full-screen quad in front of the XR
## camera, one bilinear tap a pixel.
## One view for both eyes (not one each) halves the extra render passes, which measured costlier than their pixels
## (a viewport per eye: +2 ms before blur); it ignores the eyes' parallax, under half a degree for lights 5 m or
## more away and hidden by the blur, which is why the saber blades (half a metre away: about 7 degrees) aren't
## glow sources. The camera takes the head pose at _process, a little before the frame's predicted pose, so the quad
## reprojects by rotation (the glow's view matrix is passed in). The sources keep their own materials, so the glow
## follows the light show (and its flash cap). Hidden in mixed reality.
## stage (for the benchmark): 0 off, 1 the SubViewport only, 2 and blur, 3 the full glow.

## The visual layer (bit 11) glow sources carry besides their own.
const GLOW_LAYER := 1 << 10
## The glow image for each Settings.glow_quality: [height px, 4x MSAA in it, short blur chain]. Measured in a song
## against no glow next to it: Soft (564, no MSAA, short) +0.2 ms, Crisp (752, no MSAA, short) +1.2 ms; 752 with
## MSAA and the full chain was +1.3 and the older 376 +1.2 (the run-to-run spread is about 1 ms). At 188 px thin
## bars broke into dashes, and at 376 a glow texel spanned about 7 eye pixels, showing as bands.
const QUALITIES := {"Soft": [564, false, true], "Crisp": [752, false, true]}

## Sets the glow image for a Settings.glow_quality name.
static func set_quality(quality: String) -> void:
	var values: Array = QUALITIES.get(quality, QUALITIES["Soft"])
	height = values[0]
	view_msaa = values[1]
	short_chain = values[2]

## The glow image's height in px (its width follows the frustum, so texels are square).
static var height := 564
## The blur passes: [size relative to the glow image, upsample]. Halving twice then doubling back keeps the glow
## wide but smooth (a single downsample read straight at full screen showed its texels as soft blotches).
## Then a B-spline (bicubic) up pass back to the glow image's size: the composite reads it with one bilinear tap,
## magnified only about twice. The B-spline at full screen (four taps for each of about 4.5 million pixels) cost
## about 2.9 ms; here it runs over the glow image's few hundred thousand.
enum Pass { DOWN, UP, BSPLINE }
const BLUR_CHAIN := [[0.5, Pass.DOWN], [0.25, Pass.DOWN], [0.5, Pass.UP], [1.0, Pass.BSPLINE]]
## Where the glow is magnified: "pass" (the BSPLINE pass, the default), "composite" (B-spline in the composite, the
## older way, for the benchmark) or "none" (one bilinear tap of the up pass; DebugView.GLOW_BICUBIC).
static var upsample := "pass"
## 4x MSAA in the glow image, and the short chain, which skips the quarter-size down and up passes (the B-spline
## pass then reads the first downsample); set by set_quality, and by the benchmark.
static var view_msaa := false
static var short_chain := true
const INTENSITY := 0.8
## The up pass: the tight halo (the first downsample) added back to the wide one, mostly tight so the glow hugs the
## bars instead of spreading like fog.
const TIGHT_HALO := 1.0
const WIDE_HALO := 0.35
## Light under this (in the glow image) doesn't glow: only the bars' bright cores do.
const THRESHOLD := 0.1
const NEAR := 0.05
const FAR := 1000.0

const BLUR_SHADER := """
shader_type canvas_item;
// Dual filter (Arm, SIGGRAPH 2015). Down: the centre and four diagonal taps half a source texel out, each bilinear,
// into an image half the size. Up: a tent of four edge taps a texel out and four diagonal ones half a texel out.
uniform sampler2D source : filter_linear, repeat_disable;
uniform vec2 texel;
// Pass: 0 down, 1 up, 2 B-spline up (Sigg and Hadwiger, GPU Gems 2 ch. 20: four bilinear taps)
uniform int mode = 0;
// for an up pass: the down pass of its size, added back as a tight inner halo around the wide one
uniform sampler2D detail : filter_linear, repeat_disable;
uniform float detail_weight = 0.0;
uniform float wide_weight = 1.0;
// for the first pass: light below this doesn't glow, eased in over a knee as wide (a hard cut turned a thin bar
// whose brightness varies between texels into dashes)
uniform float threshold = 0.0;
vec3 bspline(vec2 uv, vec2 size) {
	vec2 p = uv * size - 0.5;
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 f2 = f * f;
	vec2 f3 = f2 * f;
	vec2 w0 = (-f3 + 3.0 * f2 - 3.0 * f + 1.0) / 6.0;
	vec2 w1 = (3.0 * f3 - 6.0 * f2 + 4.0) / 6.0;
	vec2 w2 = (-3.0 * f3 + 3.0 * f2 + 3.0 * f + 1.0) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 g0 = w0 + w1;
	vec2 g1 = w2 + w3;
	vec2 h0 = (i - 0.5 + w1 / g0) / size;
	vec2 h1 = (i + 1.5 + w3 / g1) / size;
	return g0.y * (g0.x * texture(source, h0).rgb + g1.x * texture(source, vec2(h1.x, h0.y)).rgb)
		+ g1.y * (g0.x * texture(source, vec2(h0.x, h1.y)).rgb + g1.x * texture(source, h1).rgb);
}
void fragment() {
	vec3 sum;
	if (mode == 2) {
		sum = bspline(UV, 1.0 / texel);
	} else if (mode == 1) {
		sum = texture(source, UV + vec2(-texel.x * 2.0, 0.0)).rgb + texture(source, UV + vec2(texel.x * 2.0, 0.0)).rgb
			+ texture(source, UV + vec2(0.0, -texel.y * 2.0)).rgb + texture(source, UV + vec2(0.0, texel.y * 2.0)).rgb
			+ (texture(source, UV + vec2(-texel.x, -texel.y)).rgb + texture(source, UV + vec2(texel.x, -texel.y)).rgb
			+ texture(source, UV + vec2(-texel.x, texel.y)).rgb + texture(source, UV + vec2(texel.x, texel.y)).rgb) * 2.0;
		sum = sum / 12.0 * wide_weight + texture(detail, UV).rgb * detail_weight;
	} else {
		sum = texture(source, UV).rgb * 4.0
			+ texture(source, UV + vec2(-texel.x, -texel.y)).rgb + texture(source, UV + vec2(texel.x, -texel.y)).rgb
			+ texture(source, UV + vec2(-texel.x, texel.y)).rgb + texture(source, UV + vec2(texel.x, texel.y)).rgb;
		sum /= 8.0;
		if (threshold > 0.0) {
			float level = max(sum.r, max(sum.g, sum.b));
			sum *= smoothstep(0.0, threshold * 2.0, level);
		}
	}
	COLOR = vec4(sum, 1.0);
}
"""

const COMPOSITE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D glow : filter_linear, repeat_disable, source_color;
// DebugView.GLOW_ALIGN: the unblurred glow image, solid magenta, to see where it lands
uniform sampler2D raw : filter_nearest, repeat_disable, source_color;
uniform bool debug = false;
// DebugView A/B tests: a 4x4 Bayer dither of half an 8-bit step, and a B-spline upsample (Sigg and Hadwiger,
// GPU Gems 2 ch. 20: four bilinear taps) of the glow image, glow_size texels big
uniform bool dither = false;
uniform bool bicubic = false;
uniform vec2 glow_size = vec2(188.0);
vec3 bspline(vec2 uv) {
	vec2 p = uv * glow_size - 0.5;
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 f2 = f * f;
	vec2 f3 = f2 * f;
	vec2 w0 = (-f3 + 3.0 * f2 - 3.0 * f + 1.0) / 6.0;
	vec2 w1 = (3.0 * f3 - 6.0 * f2 + 4.0) / 6.0;
	vec2 w2 = (-3.0 * f3 + 3.0 * f2 + 3.0 * f + 1.0) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 g0 = w0 + w1;
	vec2 g1 = w2 + w3;
	vec2 h0 = (i - 0.5 + w1 / g0) / glow_size;
	vec2 h1 = (i + 1.5 + w3 / g1) / glow_size;
	return g0.y * (g0.x * texture(glow, h0).rgb + g1.x * texture(glow, vec2(h1.x, h0.y)).rgb)
		+ g1.y * (g0.x * texture(glow, vec2(h0.x, h1.y)).rgb + g1.x * texture(glow, h1).rgb);
}
// the glow camera's projection times its view rotation (no translation): reprojects by rotation only
uniform mat4 glow_rotation;
uniform float intensity = 0.8;
// how far away the quad sits, in metres: anything solid nearer (drawn with depth) hides the glow behind it, as the
// glow image has no occluders of its own. The quad is a plane, so towards the view's corners (about 55 degrees off
// centre) it lies 1.75 times as far: 50 m keeps it inside the 100 m sky sphere everywhere.
uniform float glow_depth = 50.0;
// the glow image's clip position of each corner's view ray (linear across the screen; divided per pixel)
varying vec4 glow_clip;
void vertex() {
	// the quad covers each eye's whole view, at glow_depth (through this eye's projection, so whichever way the
	// depth runs)
	vec4 back = PROJECTION_MATRIX * vec4(0.0, 0.0, -glow_depth, 1.0);
	POSITION = vec4(VERTEX.xy * back.w, back.z, back.w);
	// In stereo, VIEW_MATRIX is a camera behind both eyes and each eye's PROJECTION_MATRIX carries that eye's
	// offset from it, so a single unprojected point (at the near plane with reversed depth) isn't on the eye's ray
	// from that camera: take the ray between two points of it instead, which the offset doesn't turn.
	vec4 a = INV_PROJECTION_MATRIX * vec4(VERTEX.xy, 1.0, 1.0);
	vec4 b = INV_PROJECTION_MATRIX * vec4(VERTEX.xy, 0.0, 1.0);
	vec3 ray = a.xyz / a.w - b.xyz / b.w;
	// forward is -z in view space, whichever end the depth puts first
	ray *= ray.z > 0.0 ? -1.0 : 1.0;
	glow_clip = glow_rotation * vec4(mat3(INV_VIEW_MATRIX) * ray, 0.0);
}
void fragment() {
	vec2 uv = glow_clip.xy / glow_clip.w * 0.5 + 0.5;
	uv.y = 1.0 - uv.y;
	ALBEDO = (bicubic ? bspline(uv) : texture(glow, uv).rgb) * intensity;
	if (dither) {
		int x = int(FRAGCOORD.x) & 3;
		int y = int(FRAGCOORD.y) & 3;
		int bayer[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
		ALBEDO += (float(bayer[y * 4 + x]) / 16.0 - 0.5) / 255.0;
	}
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
	_view.size = Vector2i(height, height)
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
	var source: Texture2D = _view.get_texture()
	for pass_: Array in BLUR_CHAIN:
		var blur := SubViewport.new()
		blur.size = Vector2i(Vector2(height, height) * float(pass_[0]))
		blur.disable_3d = true
		# half floats: a soft falloff in 8 bits shows steps that slide as the bars move
		blur.use_hdr_2d = true
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		var material := ShaderMaterial.new()
		material.shader = blur_shader
		material.set_shader_parameter(&"source", source)
		material.set_shader_parameter(&"mode", pass_[1])
		material.set_shader_parameter(&"wide_weight", WIDE_HALO)
		if _blurs.is_empty():
			material.set_shader_parameter(&"threshold", THRESHOLD)
		if pass_[1] == Pass.UP:
			# the down pass of the same size
			for i in _blurs.size():
				if is_equal_approx(float(BLUR_CHAIN[i][0]), float(pass_[0])) and BLUR_CHAIN[i][1] == Pass.DOWN:
					material.set_shader_parameter(&"detail", _blurs[i].get_texture())
					material.set_shader_parameter(&"detail_weight", TIGHT_HALO)
		rect.material = material
		blur.add_child(rect)
		add_child(blur)
		_blurs.append(blur)
		_blur_materials.append(material)
		source = blur.get_texture()

	var shader := Shader.new()
	shader.code = COMPOSITE_SHADER
	_quad_material.shader = shader
	_quad_material.render_priority = Material.RENDER_PRIORITY_MAX
	_quad_material.set_shader_parameter(&"intensity", INTENSITY)
	_quad_material.set_shader_parameter(&"glow", _blurs[-1].get_texture())
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
	for blur in _blurs:
		blur.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown and stage >= 2 else SubViewport.UPDATE_DISABLED
	# the B-spline pass only when the composite reads it
	if _upsample_shown != "pass":
		_blurs[-1].render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _short_shown:
		_blurs[1].render_target_update_mode = SubViewport.UPDATE_DISABLED
		_blurs[2].render_target_update_mode = SubViewport.UPDATE_DISABLED
	_blur_materials[-1].set_shader_parameter(&"source", (_blurs[0] if _short_shown else _blurs[2]).get_texture())
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
	# each pass reads the one before: a texel of its source
	var source_size := Vector2(_view.size)
	for i in _blurs.size():
		_blur_materials[i].set_shader_parameter(&"texel", Vector2.ONE / source_size)
		source_size = Vector2(_blurs[i].size)
	var debug := DebugView.flags & DebugView.GLOW_ALIGN != 0
	_quad_material.set_shader_parameter(&"debug", debug)
	_quad_material.set_shader_parameter(&"dither", DebugView.flags & DebugView.GLOW_DITHER != 0)
	var mode := "none" if DebugView.flags & DebugView.GLOW_BICUBIC != 0 else upsample
	if mode != _upsample_shown or short_chain != _short_shown:
		_upsample_shown = mode
		_short_shown = short_chain
		_apply_stage()
	_view.msaa_3d = Viewport.MSAA_4X if view_msaa else Viewport.MSAA_DISABLED
	var read := _blurs[-1] if mode == "pass" else (_blurs[0] if _short_shown else _blurs[2])
	_quad_material.set_shader_parameter(&"glow", read.get_texture())
	_quad_material.set_shader_parameter(&"bicubic", mode == "composite")
	_quad_material.set_shader_parameter(&"glow_size", Vector2(read.size))
	_test_foveation(xr, DebugView.flags & DebugView.GLOW_NO_FOVEATION != 0)
	# the log also runs during a benchmark, to have the numbers with each measurement
	if (debug or _game.has_node(^"Benchmark")) and xr and xr.is_initialized() and xr.get_view_count() == 2:
		_log_offsets(xr, head)

## The foveation level before DebugView.GLOW_NO_FOVEATION turned it off (-1: not off).
var _foveation_before := -1
## The upsample in use (upsample, or "none" while DebugView.GLOW_BICUBIC is on).
var _upsample_shown := "pass"
var _short_shown := false

func _test_foveation(xr: XRInterface, off: bool) -> void:
	var openxr := xr as OpenXRInterface
	if openxr == null:
		return
	if off and _foveation_before < 0:
		_foveation_before = openxr.foveation_level
		openxr.foveation_level = 0
	elif not off and _foveation_before >= 0:
		openxr.foveation_level = _foveation_before
		_foveation_before = -1

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
	var size := Vector2i(roundi(height * bounds.size.x / bounds.size.y), height)
	if _view.size != size:
		print("Glow view %dx%d for a frustum %.3f x %.3f (tangents): texel aspect %.3f" % [size.x, size.y,
				bounds.size.x, bounds.size.y, (bounds.size.x / size.x) / (bounds.size.y / size.y)])
		_view.size = size
		for i in _blurs.size():
			_blurs[i].size = Vector2i(Vector2(size) * float(BLUR_CHAIN[i][0]))
	_camera.set_frustum(bounds.size.y * NEAR, bounds.get_center() * NEAR, NEAR, FAR)
