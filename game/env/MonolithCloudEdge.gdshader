shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// The soft edge of Monolith's clouds and mountains (MonolithRig.gd; owner, 2026-10-31: blur the clouds' edges): a thin
// see-through fringe out from the outline, in the outline's tone (`tone`, set by MonolithRig), fading
// from solid on the outline (UV.x 0) to clear at its rim (UV.x 1). The only blending on the stage, and only on this
// strip. BLOCKOUT, untuned.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"
#include "res://game/env/monolith_cloud.gdshaderinc"

// this ring's place among them: 0 the nearest, 1 the farthest (MonolithRig)
uniform float depth_share = 0.0;
// the fringe's tone: a neutral grey plus this many times the haze
uniform vec2 tone = vec2(0.12, 2.0);
// how fast it fades out (higher: thinner)
const float FADE_POWER = 1.6;

varying vec3 haze_v;
void vertex() {
	haze_v = fog_lit(env_haze.rgb, (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
}

void fragment() {
	vec3 color = cloud_far(vec3(tone.x) + haze_v * tone.y, haze_v, depth_share);
	ALBEDO = fog_result(color, VERTEX);
	ALPHA = pow(1.0 - UV.x, FADE_POWER);
}
