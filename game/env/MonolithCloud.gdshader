shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

// Monolith's clouds (MonolithRig.gd; owner, 2026-10-31: 3D cumulus banks like his reference, no two alike, drifting
// slowly): one band of banks round the player, merged into one mesh. UV.x holds a vertex's metres below its bank's
// top, UV.y the band's place among them (0 the nearest, 1 the farthest); COLOR.r is the baked occlusion (dark creases
// between puffs), COLOR.g the height share in the bank (tools/models/monolith_cloud.py). Layers:
//   1. body: a neutral grey plus the haze's colour, lightest at the bank's top and darkening downward, paler and closer
//      to the haze on farther bands so the layers stand apart (monolith_cloud.gdshaderinc, shared with what sinks into
//      the clouds)
//   2. top light: faces turned up a little brighter (TOP_LIGHT), so each puff reads round
//   3. creases: darkened by the baked occlusion (AO_STRENGTH)
//   4. rim: the puffs' upper outline brightens toward the rim tone where the surface turns away from the eye, like the
//      reference's lit edges; this also softens the outline against the haze (no see-through fringe)
// Neutral, never the lights' colours (AGENTS.md "Colour rules"). All values untuned.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"
#include "res://game/env/monolith_cloud.gdshaderinc"

// faces pointing straight up are this much brighter, falling off with this power of how far up they point
const float TOP_LIGHT = 0.9;
const float TOP_POWER = 2.0;
// how much the baked occlusion darkens the creases (0 none, 1 full)
const float AO_STRENGTH = 0.8;
// the rim: a neutral grey plus this many times the haze, how sharply it gathers at the outline (higher: thinner), and
// the height share in the bank it starts from (below it the outline keeps the body's tone)
const vec2 RIM_TONE = vec2(0.12, 2.0);
const float RIM_POWER = 2.0;
const float RIM_FROM = 0.3;

varying vec3 haze_v;
varying vec3 world_normal;
void vertex() {
	haze_v = fog_lit(env_haze.rgb, (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	float far = UV.y;
	vec3 color = cloud_tone(haze_v, UV.x, far);
	color *= 1.0 + TOP_LIGHT * pow(max(normalize(world_normal).y, 0.0), TOP_POWER);
	color *= mix(1.0, COLOR.r, AO_STRENGTH);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), VIEW)), RIM_POWER) * smoothstep(RIM_FROM, 1.0, COLOR.g);
	color = mix(color, cloud_far(vec3(RIM_TONE.x) + haze_v * RIM_TONE.y, haze_v, far), rim);
	ALBEDO = fog_dither(fog_result(color, VERTEX), FRAGCOORD.xy);
}
