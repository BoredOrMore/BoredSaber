shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

// Night City's sea of cloud (NightCityRig): fog with mass, filling the canyon below the roofs, so the towers rise out of
// it (owner, 2026-10-25; doc/research/fog.md M2). Opaque, so it costs no blending: a subdivided plane whose vertices
// heave slowly with two drifting waves. Layers:
//   1. body: the haze's colour (env_haze, the lights that are on; dark when they're off), lighter on the crests and
//      darker in the troughs, so the surface reads as rolling cloud
//   2. light: the lights' colour (env_light) a little more on the crests, as the tops catch the show
//   3. distance: fades into the plain haze far away, where it meets the sky
// The fog layer just above it (EnvSolid 5b, canyon_fog) hides where it meets the towers. All values untuned.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"
global uniform vec4 env_light;
// how high the waves heave (metres), how wide (per metre) and how fast
const float HEAVE = 1.6;
const vec2 WAVE_SCALE = vec2(0.035, 0.05);
const float WAVE_SPEED = 0.08;
// the body: the haze this many times over, from trough to crest; the lights' share on the crests
const vec2 BODY = vec2(0.7, 1.8);
const float CREST_LIGHT = 0.12;
// far: all haze from x to y metres
const vec2 FAR_FADE = vec2(80.0, 220.0);

varying float crest;
varying float far;

// the haze lit from the key light, per vertex: the sky and the cloud sea are fine enough meshes that it looks the same
// as per pixel, for less work (fog benchmark, 2026-10-25)
varying vec3 haze_v;
void vertex() {
	haze_v = fog_lit(env_haze.rgb, (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(world.x * WAVE_SCALE.x + TIME * WAVE_SPEED) * sin(world.z * WAVE_SCALE.y - TIME * WAVE_SPEED * 0.7)
		+ 0.5 * sin((world.x + world.z) * WAVE_SCALE.y * 1.7 + TIME * WAVE_SPEED * 1.3);
	crest = clamp(w * 0.5 + 0.5, 0.0, 1.0);
	VERTEX.y += (crest - 0.5) * HEAVE * 2.0;
	far = smoothstep(FAR_FADE.x, FAR_FADE.y, length(world - CAMERA_POSITION_WORLD));
}

void fragment() {
	// the haze lit from the stage's key light, seen this way (fog_light.gdshaderinc)
	vec3 haze = haze_v;
	vec3 body = haze * mix(BODY.x, BODY.y, crest) + env_light.rgb * CREST_LIGHT * crest;
	ALBEDO = fog_dither(fog_result(mix(body, haze, far), VERTEX), FRAGCOORD.xy);
}
