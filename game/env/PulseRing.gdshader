shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

// Thin glowing rings around the track in Pulse Void. Each one brightens and widens a little with its band of the
// music (INSTANCE_CUSTOM.r, from PulseVoid.gd), and takes the left laser light (type 2) or the right square lasers
// (type 1; INSTANCE_CUSTOM.g picks which), so map light events still drive them. They fade out below the floor. The mesh holds a unit circle (VERTEX.xy) and which edge of the
// line each vertex is on (VERTEX.z, -1 or 1); the radius is INSTANCE_CUSTOM.b. Drawn as geometry, not as a
// full-screen quad, so only the line itself costs pixels. All values untuned.
global uniform vec4 env_haze;
#include "res://game/env/player_light.gdshaderinc"
uniform lowp vec4 bg_1_tint;
uniform lowp vec4 bg_2_tint;
uniform lowp float bg_1_intensity = 0.0;
uniform lowp float bg_2_intensity = 0.0;

// metres
const float LINE_WIDTH = 0.05;
// how much wider the line gets, and how much the ring grows, at full music level
const float PULSE_WIDEN = 1.5;
const float PULSE_GROW = 0.04;
const float BASE_GLOW = 0.5;
const float PULSE_GLOW = 1.5;
// glow from the music alone, so the rings still breathe while the lights are off
const float HAZE_PULSE = 1.5;
const float FADE_DISTANCE = 45.0;
// how bright a cut's wave lights each ring as it passes (player_light.gdshaderinc)
const float CUT_WAVE_GAIN = 2.0;
varying vec3 wave;

varying float level;
varying float side;
varying float edge;
varying float fade;
varying float height;

void vertex() {
	level = INSTANCE_CUSTOM.r;
	side = INSTANCE_CUSTOM.g;
	edge = VERTEX.z;
	float radius = INSTANCE_CUSTOM.b * (1.0 + level * PULSE_GROW);
	float half_width = LINE_WIDTH * 0.5 * (1.0 + level * PULSE_WIDEN);
	VERTEX = vec3(VERTEX.xy * (radius + VERTEX.z * half_width), 0.0);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fade = exp(-length(world - CAMERA_POSITION_WORLD) / FADE_DISTANCE);
	height = world.y;
	wave = cut_wave_light(world);
}

void fragment() {
	// bright in the middle of the line, soft toward its edges
	float profile = 1.0 - edge * edge;
	vec3 light = mix(bg_2_tint.rgb * bg_2_intensity, bg_1_tint.rgb * bg_1_intensity, side);
	vec3 col = light * (BASE_GLOW + level * PULSE_GLOW) + env_haze.rgb * level * HAZE_PULSE + wave * CUT_WAVE_GAIN;
	ALBEDO = col * profile * fade * smoothstep(-0.3, 0.5, height);
}
