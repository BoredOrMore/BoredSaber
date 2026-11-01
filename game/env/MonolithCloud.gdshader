shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

// Monolith's clouds (MonolithRig.gd; owner, 2026-10-31: stylized like his reference, flats with rows of round puffs):
// one upright ring of cloud whose top is the puffs' outline (in the mesh, so no discard and no blending). UV.y holds the
// metres down from the top, UV.x the metres down from the line of the tallest puffs. Layers:
//   1. body: a neutral grey plus the haze's colour, lightest at the tallest puffs and darkening toward the valley
//      (measured from that smooth line, not each puff's top, so no crease runs down from the dips between puffs), paler
//      and closer to the haze on farther rings (depth_share 0 near to 1 far) so the layers stand apart
//      (monolith_cloud.gdshaderinc, shared with what sinks into the clouds)
//   2. rim: a thin bright line along the puffs' outline, at least MIN_PIXELS wide, under the soft edge
//      (MonolithCloudEdge.gdshader)
// Neutral, never the lights' colours (AGENTS.md "Colour rules"). BLOCKOUT, all values untuned.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"
#include "res://game/env/monolith_cloud.gdshaderinc"

// this ring's place among them: 0 the nearest, 1 the farthest (MonolithRig)
uniform float depth_share = 0.0;
// the rim: its width in metres (never under MIN_PIXELS on screen) and brightness, a grey plus the haze
const float RIM_WIDTH = 0.8;
const float MIN_PIXELS = 1.5;
const vec2 RIM_TONE = vec2(0.12, 2.0);

varying vec3 haze_v;
void vertex() {
	haze_v = fog_lit(env_haze.rgb, (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
}

void fragment() {
	float down = UV.y;
	float width = max(RIM_WIDTH, fwidth(down) * MIN_PIXELS);
	float rim = 1.0 - smoothstep(width * 0.5, width, down);
	vec3 rim_color = cloud_far(vec3(RIM_TONE.x) + haze_v * RIM_TONE.y, haze_v, depth_share);
	vec3 color = mix(cloud_tone(haze_v, UV.x, depth_share), rim_color, rim);
	ALBEDO = fog_dither(fog_result(color, VERTEX), FRAGCOORD.xy);
}
