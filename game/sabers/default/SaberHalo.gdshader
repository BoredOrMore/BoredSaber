shader_type spatial;
// The glow around a saber blade, drawn with the blade instead of by a glow pass (LowResGlow draws from one camera
// between the eyes, so a blade half a metre away would glow about 7 degrees off in each eye): a flat ribbon along
// the blade that turns to face the eye around the blade's axis, real geometry in each eye's view. The mesh is a
// 1 x 1 QuadMesh: x across the ribbon (-0.5..0.5), y along the blade (-0.5..0.5), scaled by length and width here.
// The saber's colour in a soft falloff, dimmer than the white-hot blade (AGENTS.md "Light", rule 2), ending in soft
// caps; never thinner than min_pixels on screen, dimmed by the width it gains.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
// the blade's length now (it grows and shrinks as the saber turns on and off), in metres
uniform float blade_length = 1.2;
// the whole ribbon's width, in metres (untuned)
uniform float width = 0.09;
uniform float min_pixels = 6.0;
uniform float strength = 0.55;

varying float across;
varying float along;
varying float fade;

void vertex() {
	vec3 axis = (MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	float scale = length(axis);
	axis /= max(scale, 1e-5);
	vec3 center = (MODEL_MATRIX * vec4(0.0, VERTEX.y * blade_length / max(scale, 1e-5), 0.0, 1.0)).xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - center;
	vec3 side = cross(axis, to_cam);
	float side_len = length(side);
	side = side_len > 1e-5 ? side / side_len : vec3(1.0, 0.0, 0.0);
	float pixel = 2.0 * length(to_cam) / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float w = max(width, min_pixels * pixel);
	fade = width / w;
	across = VERTEX.x * 2.0;
	along = VERTEX.y * 2.0;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(center + side * VERTEX.x * w, 1.0));
}

void fragment() {
	float d = abs(across);
	float falloff = exp(-d * d * 5.0) * (1.0 - d);
	// soft caps: fades over the last few centimetres at each end of the blade
	float caps = 1.0 - smoothstep(1.0 - 0.06 / max(blade_length, 0.06), 1.0, abs(along));
	ALBEDO = color.rgb * falloff * caps * fade * strength;
}
