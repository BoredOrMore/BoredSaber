shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The Monolith sky (MonolithRig.gd): black, with a faint neutral glow low on the horizon behind the slab, strongest in its
// direction, so it stands as a black silhouette (owner, 2026-10-31). It takes the haze's colour, not the lights', so the
// glow stays neutral; the bg_<type> uniforms EventDriver sets on every sky are left out on purpose. BLOCKOUT, untuned.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"
// DebugView.SKY draws the sky plain black
global uniform int debug_view;

// the way to the slab on the horizon (world xz, unit; MonolithRig.SLAB_YAW, 30 degrees, left of -z), the glow's peak there, how
// fast it falls off upward and how wide it is round the horizon (larger: narrower)
const vec2 SLAB_DIR = vec2(-0.5, -0.866);
const float HORIZON_GLOW = 1.2;
const float GLOW_FALLOFF = 6.0;
const float GLOW_WIDTH = 1.5;
const float SKY_HAZE = 0.04;
// a neutral grey glow low on the horizon all round (the haze is dark away from the slab), so the valley's terraced
// ridges stand as silhouettes on every side; its peak and how fast it falls off upward
const float RIDGE_GLOW = 0.12;
const float RIDGE_FALLOFF = 3.0;

varying vec3 haze_v;
varying vec3 dir;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	dir = world - CAMERA_POSITION_WORLD;
	haze_v = fog_lit(env_haze.rgb, dir);
}

void fragment() {
	vec3 d = normalize(dir);
	float facing = clamp(dot(normalize(d.xz), SLAB_DIR) * 0.5 + 0.5, 0.0, 1.0);
	float glow = HORIZON_GLOW * exp(-abs(d.y) * GLOW_FALLOFF) * pow(facing, GLOW_WIDTH);
	vec3 ridge = vec3(RIDGE_GLOW * exp(-abs(d.y) * RIDGE_FALLOFF));
	ALBEDO = (debug_view & 16) != 0 ? vec3(0.0) : fog_dither(fog_result(ridge + haze_v * (SKY_HAZE + glow), VERTEX), FRAGCOORD.xy);
}
