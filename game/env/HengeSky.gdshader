shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The Henge sky (HengeRig.gd): dark, with a faint neutral glow along the horizon behind the slabs, so they stand as
// black silhouettes against it (owner, 2026-10-29). It takes the haze's colour, not the lights', so the glow stays
// neutral; the bg_<type> uniforms EventDriver sets on every sky are left out on purpose. BLOCKOUT, untuned.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"
// DebugView.SKY draws the sky plain black
global uniform int debug_view;

// how much of the haze's colour the dark sky takes, the glow's peak at the horizon, and how fast it falls off upward
// (per unit of the view direction's height), above and below
const float SKY_HAZE = 0.02;
const float HORIZON_GLOW = 1.5;
const float GLOW_FALLOFF = 8.0;

varying vec3 haze_v;
varying vec3 dir;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	dir = world - CAMERA_POSITION_WORLD;
	haze_v = fog_lit(env_haze.rgb, dir);
}

void fragment() {
	float up = normalize(dir).y;
	float glow = HORIZON_GLOW * exp(-abs(up) * GLOW_FALLOFF);
	ALBEDO = (debug_view & 16) != 0 ? vec3(0.0) : fog_dither(fog_result(haze_v * (SKY_HAZE + glow), VERTEX), FRAGCOORD.xy);
}
