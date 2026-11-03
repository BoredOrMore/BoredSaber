shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

// Monolith's hills (MonolithRig._hill_ring): flat dark rings in a grey `tone` (MonolithRig.HILL_TONE, paler for
// farther rings), sinking into the cloud sea below its surface (monolith_cloud_sea.gdshaderinc). Untuned.
global uniform vec4 env_haze;
#include "res://game/env/monolith_cloud_sea.gdshaderinc"

uniform float tone = 0.004;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = mcloud_output(under_cloud(vec3(tone), env_haze.rgb, world_position));
}
