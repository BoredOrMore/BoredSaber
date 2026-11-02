shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

// Monolith's cloud sea (MonolithCloudSea.gd): one continuous sheet round the player, darker the deeper below its
// surface, lit by a fixed key, paler toward the haze with distance (monolith_cloud_sea.gdshaderinc). Neutral, never the
// lights' colours (AGENTS.md "Colour rules"). Untuned.
global uniform vec4 env_haze;
#include "res://game/env/monolith_cloud_sea.gdshaderinc"

varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	ALBEDO = mcloud_output(mcloud_body_tone(env_haze.rgb, world_position, world_normal));
}
