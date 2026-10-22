shader_type spatial;
// A thin layer of drifting smoke just above the floor, so the track feels like a stage in smoke. Two copies of a
// tiling noise texture drift in different directions and their average sets how thick the smoke is; it is lit by the
// scene lights through the shared haze colour, so a flash lights up the smoke. It fades out at the layer's edges, close
// to the player (see-through layers right in front of the eyes strain them in VR), far away (the haze takes over) and
// where it is seen almost edge-on, so it never shows as a flat plate; these fades are worked out per vertex, so each
// pixel only blends two noise samples. No depth texture, no extra pass. All values untuned.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform vec4 env_haze;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float opacity = 0.3;
// metres per second, one for each noise copy
uniform vec2 drift_a = vec2(0.05, 0.12);
uniform vec2 drift_b = vec2(-0.08, 0.05);

// noise tiles per metre for each copy, across (x) and along the track (z): large and stretched across, so the
// smoke lies in thin wisps rather than clumps
const vec2 SCALE_A = vec2(0.035, 0.08);
const vec2 SCALE_B = vec2(0.02, 0.05);
// a wide, gentle ramp from noise to thickness (a narrow one cut the noise into dense blobs with gaps between)
const float DENSITY_FROM = 0.3;
const float DENSITY_TO = 0.85;
// fraction of the layer's size over which its edges fade
const float EDGE_FADE = 0.25;
const float NEAR_START = 1.2;
const float NEAR_FULL = 2.5;
const float FAR_START = 18.0;
const float FAR_END = 28.0;
const vec3 SMOKE_BASE = vec3(0.05, 0.05, 0.08);
// env_haze carries about 8% of each light that is on; this brings it back up to a visible glow
const float LIGHT_GAIN = 6.0;

varying vec2 uv_a;
varying vec2 uv_b;
varying float fade;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	uv_a = (world.xz + TIME * drift_a) * SCALE_A;
	uv_b = (world.xz + TIME * drift_b) * SCALE_B;
	vec2 e = min(UV, 1.0 - UV);
	float edge = smoothstep(0.0, EDGE_FADE, min(e.x, e.y));
	vec3 to_vertex = world - CAMERA_POSITION_WORLD;
	float dist = length(to_vertex);
	float near = smoothstep(NEAR_START, NEAR_FULL, dist);
	float far = 1.0 - smoothstep(FAR_START, FAR_END, dist);
	float edge_on = smoothstep(0.03, 0.2, abs(to_vertex.y) / dist);
	fade = edge * near * far * edge_on * opacity;
}

void fragment() {
	float n = 0.5 * (texture(noise, uv_a).r + texture(noise, uv_b).r);
	ALBEDO = SMOKE_BASE + env_haze.rgb * LIGHT_GAIN;
	ALPHA = smoothstep(DENSITY_FROM, DENSITY_TO, n) * fade;
}
