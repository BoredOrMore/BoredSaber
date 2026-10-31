shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

// Monolith's mountains (MonolithRig.gd; owner, 2026-10-31: 3D models in place of the flat silhouettes, no two alike):
// every low-poly peak round the valley, merged into one mesh. UV.x holds a vertex's metres below its mountain's top
// (unused here), UV.y its ring's place among them (0 the nearest, 1 the farthest); COLOR.r is the baked occlusion
// (dark gullies), COLOR.g the height share in the mountain (tools/models/monolith_mountain.py); the normals are flat,
// one per facet. Layers:
//   1. body: a dark neutral grey plus a little haze
//   2. facets: those turned toward the glow behind the slab (KEY) lighter, so the facets and the ridges read
//   3. height: paler toward the summits (TOP_PALE), darker in the gullies (AO_STRENGTH)
//   4. distance: paler and closer to the haze on farther rings so the layers stand apart (aerial perspective)
//   5. clouds: below the clouds' level the mountain takes the cloud's tone, so it rises out of them
//      (monolith_cloud.gdshaderinc)
// Darker than the clouds and the slab's lights (AGENTS.md "Light", rule 1). All values untuned.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"
#include "res://game/env/monolith_cloud.gdshaderinc"

// the body and the lit facets: a neutral grey plus this many times the haze
const vec2 BODY_TONE = vec2(0.012, 0.3);
const vec2 LIT_TONE = vec2(0.035, 0.7);
// the way to the glow behind the slab and a little up (MonolithRig.SLAB_YAW, 30 degrees left of -z; keep it matching)
const vec3 KEY = vec3(-0.43, 0.5, -0.75);
// the summits are this much brighter than the foot; the baked occlusion darkens the gullies this much (0 none, 1 full)
const float TOP_PALE = 0.6;
const float AO_STRENGTH = 0.7;

varying vec3 haze_v;
varying vec3 world;
varying vec3 world_normal;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	haze_v = fog_lit(env_haze.rgb, world - CAMERA_POSITION_WORLD);
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	float lit = max(dot(normalize(world_normal), normalize(KEY)), 0.0);
	vec3 color = mix(vec3(BODY_TONE.x) + haze_v * BODY_TONE.y, vec3(LIT_TONE.x) + haze_v * LIT_TONE.y, lit);
	color *= (1.0 + TOP_PALE * COLOR.g) * mix(1.0, COLOR.r, AO_STRENGTH);
	color = cloud_far(color, haze_v, UV.y);
	ALBEDO = fog_dither(fog_result(under_cloud(color, haze_v, world), VERTEX), FRAGCOORD.xy);
}
