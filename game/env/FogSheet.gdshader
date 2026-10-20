shader_type spatial;
// A wide sheet of stage fog standing across the view, one of several at increasing depth so the fog has layers
// and mass instead of floating puffs. Dense at the bottom and thinning out upward, soft at the sides, with two
// octaves of noise drifting sideways at each sheet's own speed so the fog rolls. Lit by the shared haze colour,
// and brighter where it is thin, as fog backlit by the stage glows at its edges. Fades out close to the player.
// Meant for a MultiMesh of QuadMesh instances; each instance's position and (x, y) scale place the sheet.
// All values untuned.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform vec4 env_haze;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float opacity = 0.35;

// noise texture repeats per metre of sheet, and its sideways drift in metres per second
const float NOISE_SCALE = 0.06;
const float DRIFT = 0.25;
// how much of the sheet's height the dense part fills, and how soft its top is
const float BODY = 0.35;
const float TOP_SOFTNESS = 0.6;
const float SIDE_SOFTNESS = 0.25;
const vec3 FOG_BASE = vec3(0.05, 0.05, 0.07);
const float LIGHT_GAIN = 6.0;
const float BACK_GLOW = 0.8;
// Without a depth read there are no soft edges where a sheet meets other geometry, so it fades out before it can:
// toward the floor (FLOOR_FADE metres above it), toward the scenery at the sides (fully gone by SIDE_FADE_TO metres
// from the track's centre, inside every environment's structure), and when seen edge-on.
const float FLOOR_FADE = 0.8;
const float SIDE_FADE_FROM = 6.0;
const float SIDE_FADE_TO = 10.5;
const float NEAR_START = 3.0;
const float NEAR_FULL = 8.0;

varying vec2 sheet_uv;
varying vec2 sheet_size;
varying float seed;
varying float fade;
varying vec3 world_pos;

void vertex() {
	seed = fract(float(INSTANCE_ID) * 0.618034);
	sheet_size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	sheet_uv = VERTEX.xy + 0.5;  // 0..1 across and up
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_pos = world;
	fade = smoothstep(NEAR_START, NEAR_FULL, length(world - CAMERA_POSITION_WORLD));
}

void fragment() {
	vec2 metres = sheet_uv * sheet_size;
	float speed = DRIFT * (0.6 + seed);
	float n = texture(noise, (metres + vec2(TIME * speed + seed * 37.0, 0.0)) * NOISE_SCALE).r * 0.65
		+ texture(noise, (metres + vec2(-TIME * speed * 0.7, seed * 13.0)) * NOISE_SCALE * 2.3).r * 0.35;
	float height = 1.0 - smoothstep(BODY, BODY + TOP_SOFTNESS, sheet_uv.y + (n - 0.5) * 0.4);
	float sides = smoothstep(0.0, SIDE_SOFTNESS, sheet_uv.x) * smoothstep(0.0, SIDE_SOFTNESS, 1.0 - sheet_uv.x);
	float density = clamp(height * sides * (0.55 + 0.9 * n), 0.0, 1.0);
	ALBEDO = FOG_BASE + env_haze.rgb * LIGHT_GAIN * (1.0 + BACK_GLOW * (1.0 - density));
	float clear = smoothstep(0.0, FLOOR_FADE, world_pos.y)
		* (1.0 - smoothstep(SIDE_FADE_FROM, SIDE_FADE_TO, abs(world_pos.x)))
		* abs(dot(NORMAL, VIEW));
	ALPHA = density * opacity * fade * clear;
}
