shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

// Monolith's mountains (MonolithRig.gd; owner, 2026-10-31: layered silhouette flats in place of the terraces): one
// upright ring of mountains whose top is a jagged ridge (in the mesh, so no discard and no blending). UV.y holds the
// metres down from the ridge. Layers:
//   1. body: a dark neutral grey plus a little haze, flat like a paper cut-out, paler and closer to the haze on farther
//      rings (depth_share 0 near to 1 far) so the layers stand apart (aerial perspective)
//   2. rim: a thin line along the ridge, a little lighter, at least MIN_PIXELS wide, under the soft edge
//      (MonolithCloudEdge.gdshader, its tone MonolithRig.RIDGE_EDGE_TONE: keep them matching)
//   3. clouds: below the clouds' level the mountain takes the cloud's tone, so it rises out of them
//      (monolith_cloud.gdshaderinc)
// Darker than the clouds and the slab's lights (AGENTS.md "Light", rule 1). BLOCKOUT, all values untuned.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"
#include "res://game/env/monolith_cloud.gdshaderinc"

// this ring's place among them: 0 the nearest, 1 the farthest (MonolithRig)
uniform float depth_share = 0.0;
// the body and the rim: a neutral grey plus this many times the haze
const vec2 BODY_TONE = vec2(0.012, 0.3);
const vec2 RIM_TONE = vec2(0.03, 0.6);
// the rim's width in metres (never under MIN_PIXELS on screen)
const float RIM_WIDTH = 1.5;
const float MIN_PIXELS = 1.5;

varying vec3 haze_v;
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	haze_v = fog_lit(env_haze.rgb, world - CAMERA_POSITION_WORLD);
}

void fragment() {
	float down = UV.y;
	float width = max(RIM_WIDTH, fwidth(down) * MIN_PIXELS);
	float rim = 1.0 - smoothstep(width * 0.5, width, down);
	vec3 color = mix(vec3(BODY_TONE.x) + haze_v * BODY_TONE.y, vec3(RIM_TONE.x) + haze_v * RIM_TONE.y, rim);
	color = cloud_far(color, haze_v, depth_share);
	ALBEDO = fog_dither(fog_result(under_cloud(color, haze_v, world), VERTEX), FRAGCOORD.xy);
}
