shader_type spatial;
// A light bar drawn as a flat ribbon that turns to face the player around its own long axis, with a soft bright core
// and halo, so it reads as a glowing neon tube without the full-screen glow pass. The mesh is a 1 x 32 PlaneMesh:
// x is across the bar (-0.5..0.5), z along it (-16..16).
// Thin far lines flicker because they cover a pixel only some of the time; the ribbon never gets thinner than
// min_pixels on screen and dims by the width it lost instead (prefiltered lines: Chan & Durand, GPU Gems 2 ch. 22;
// Persson, "Phone-wire AA", GPU Pro 5). Bars far away fade into the air like distance fog.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 light_color : source_color = vec4(1.0);
// whole ribbon width in metres, halo included (untuned)
uniform float width = 0.4;
uniform float min_pixels = 2.0;
// per metre; at 50 m about 80% of the light is left (untuned)
uniform float fog_density = 0.005;
// makes up for the full-screen glow these bars used to get (untuned)
uniform float brightness = 3.5;

varying float across;
varying float along;
varying float fade;

void vertex() {
	vec3 axis = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	vec3 center = (MODEL_MATRIX * vec4(0.0, 0.0, VERTEX.z, 1.0)).xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - center;
	vec3 side = cross(axis, to_cam);
	float side_len = length(side);
	side = side_len > 1e-4 ? side / side_len : vec3(1.0, 0.0, 0.0);
	float dist = length(to_cam);
	float pixel = 2.0 * dist / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float w = max(width, min_pixels * pixel * 4.0);
	vec3 world = center + side * VERTEX.x * w;
	across = VERTEX.x * 2.0;
	along = VERTEX.z / 16.0;
	// sqrt: dimming by the full lost width made far bars look fainter than the old hard lines
	fade = sqrt(width / w) * exp(-fog_density * dist);
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
}

void fragment() {
	float d = abs(across);
	float core = exp(-d * d * 18.0);
	float halo = exp(-d * d * 4.0) * 0.6;
	float tips = 1.0 - smoothstep(0.85, 1.0, abs(along));
	ALBEDO = light_color.rgb * (core + halo) * (1.0 - d) * tips * fade * brightness;
}
