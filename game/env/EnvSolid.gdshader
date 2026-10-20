shader_type spatial;
// Dark solid scenery (tunnel frames, floor lines). Fades into the haze with distance and more so near the floor, so
// the scene gets depth and the air takes on the colour of the lights that are on (env_haze, set by EventDriver).
// Beat Saber's lit haze works this way in spirit; this is the cheap per-object form (Quilez, "Better fog", 2010).
render_mode unshaded, fog_disabled, shadows_disabled;

global uniform vec4 env_haze;
#include "res://game/env/shadow_tone.gdshaderinc"
#include "res://game/env/height_fog.gdshaderinc"
// DebugView.RINGS leaves these out (no area, so nothing is drawn)
global uniform int debug_view;
uniform vec4 albedo : source_color = vec4(0.094, 0.094, 0.094, 1.0);
// per metre (untuned)
uniform float fog_density = 0.03;
// how fast the extra floor haze thins out going up, per metre (untuned)
uniform float floor_haze_falloff = 0.35;

varying float fog;

void vertex() {
	if ((debug_view & 8) != 0) {
		VERTEX = vec3(0.0);
	}
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(world - CAMERA_POSITION_WORLD);
	float distance_fog = 1.0 - exp(-fog_density * dist);
	float floor_haze = exp(-max(world.y, 0.0) * floor_haze_falloff);
	fog = clamp(distance_fog * mix(0.5, 1.0, floor_haze), 0.0, 1.0);
	fog = max(fog, height_fog(world, CAMERA_POSITION_WORLD));
}

void fragment() {
	ALBEDO = shadow_tone(mix(albedo.rgb, env_haze.rgb * HEIGHT_FOG_GLOW, fog));
}
