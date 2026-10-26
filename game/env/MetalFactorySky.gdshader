shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The Metal Factory sky: the dark beyond the hall's far end, seen only through that opening (the ceiling and walls hide
// the rest). An underground hall has no sky, so it is the darkest thing in view (AGENTS.md "Light", rule 1): a trace of
// the haze. It takes no light colours, so the opening never brightens with the show.
// The bg_<type> uniforms EventDriver sets on every sky are left out on purpose. Value untuned.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"
// DebugView.SKY draws the sky plain black
global uniform int debug_view;

// how much of the haze's colour the dark takes: well below the hall's far, hazed faces, so it reads as depth
const float SKY_HAZE = 0.015;

// the haze lit from the key light, per vertex: the sky and the cloud sea are fine enough meshes that it looks the same
// as per pixel, for less work (fog benchmark, 2026-10-25)
varying vec3 haze_v;
void vertex() {
	haze_v = fog_lit(env_haze.rgb, (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
}

void fragment() {
	// the haze lit from the stage's key light, seen this way (fog_light.gdshaderinc)
	vec3 haze = haze_v;
	ALBEDO = (debug_view & 16) != 0 ? vec3(0.0) : fog_dither(haze * SKY_HAZE, FRAGCOORD.xy);
}
