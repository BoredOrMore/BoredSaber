shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

// Monolith's clouds (MonolithRig.gd; owner, 2026-10-31: stylized like his reference, flats with rows of round puffs):
// one upright ring of cloud whose top is the puffs' outline (in the mesh, so no discard and no blending). UV.y holds the
// metres down from the top. Layers:
//   1. body: a neutral grey plus the haze's colour, lightest just under the top and darkening toward the valley
//   2. rim: a thin bright line along the puffs' outline, at least MIN_PIXELS wide
//   3. depth: farther rings (depth_share 0 near to 1 far) paler and closer to the haze, so the layers stand apart
// Neutral, never the lights' colours (AGENTS.md "Colour rules"). BLOCKOUT, all values untuned.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"

// this ring's place among them: 0 the nearest, 1 the farthest (MonolithRig)
uniform float depth_share = 0.0;
// the body: a neutral grey plus this many times the haze, just under the top (x) and DARK_DEPTH metres down (y)
const vec2 TOP_TONE = vec2(0.05, 1.2);
const vec2 LOW_TONE = vec2(0.008, 0.25);
const float DARK_DEPTH = 45.0;
// the rim: its width in metres (never under MIN_PIXELS on screen) and brightness, a grey plus the haze
const float RIM_WIDTH = 0.8;
const float MIN_PIXELS = 1.5;
const vec2 RIM_TONE = vec2(0.12, 2.0);
// the farthest ring is this far toward the plain haze, and this much brighter
const float FAR_HAZE = 0.5;
const float FAR_LIFT = 1.4;

varying vec3 haze_v;
void vertex() {
	haze_v = fog_lit(env_haze.rgb, (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
}

void fragment() {
	float down = UV.y;
	float low = clamp(down / DARK_DEPTH, 0.0, 1.0);
	vec3 body = mix(vec3(TOP_TONE.x) + haze_v * TOP_TONE.y, vec3(LOW_TONE.x) + haze_v * LOW_TONE.y, low);
	float width = max(RIM_WIDTH, fwidth(down) * MIN_PIXELS);
	float rim = 1.0 - smoothstep(width * 0.5, width, down);
	vec3 color = mix(body, vec3(RIM_TONE.x) + haze_v * RIM_TONE.y, rim);
	color = mix(color * mix(1.0, FAR_LIFT, depth_share), haze_v, FAR_HAZE * depth_share);
	ALBEDO = fog_dither(fog_result(color, VERTEX), FRAGCOORD.xy);
}
