shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Specks of dust floating around the player, 1-4 m away: they move against the far scenery as the head moves
// (parallax), which helps the player feel they stand in the place. Like real dust they show only where light
// falls on them: the lit air (env_haze), a blade passing close, a cut's wave going by (player_light.gdshaderinc).
// Each speck is a tiny quad turned to face the eye; Dust.gd gives every corner the speck's start point in VERTEX
// and the corner in UV. They rise slowly and sway, wrapping round inside the box, fading at its edges so they
// never pop. Slow on purpose (comfort). Untuned.
global uniform vec4 env_haze;
global uniform vec3 left_saber;
global uniform vec3 right_saber;
// DebugView.DUST leaves them out
global uniform int debug_view;
#include "res://game/env/player_light.gdshaderinc"
uniform vec3 box;
uniform vec3 centre;
// metres: half a speck's size, the sway, and the rise per second
const float SIZE = 0.006;
const float SWAY = 0.15;
const float RISE = 0.04;
// metres from the eye where specks fade in (too close strains the eyes) and out
const float NEAR_FADE = 0.6;
const float NEAR_FULL = 1.0;
const float FAR_FULL = 3.0;
const float FAR_FADE = 4.0;
const float HAZE_GAIN = 0.6;
const float SABER_GAIN = 1.5;
// metres around a blade tip that it lights
const float SABER_REACH = 0.6;
const float CUT_WAVE_GAIN = 1.0;

varying vec3 light;
varying vec2 corner;

float saber_light(vec3 world, vec3 tip) {
	vec3 offset = world - tip;
	return exp(-dot(offset, offset) / (SABER_REACH * SABER_REACH));
}

void vertex() {
	vec3 p = VERTEX;
	float phase = dot(p, vec3(1.7, 2.3, 3.1));
	p += vec3(sin(TIME * 0.3 + phase), RISE * TIME, cos(TIME * 0.23 + phase * 1.3)) * vec3(SWAY, 1.0, SWAY);
	// where the speck is in the box, 0 to 1 on each axis
	vec3 q = mod(p, box) / box;
	vec3 edges = smoothstep(0.0, 0.1, q) * smoothstep(0.0, 0.1, 1.0 - q);
	vec3 world = (MODEL_MATRIX * vec4(q * box + centre - box * 0.5, 1.0)).xyz;
	float dist = length(world - CAMERA_POSITION_WORLD);
	float shown = smoothstep(NEAR_FADE, NEAR_FULL, dist) * (1.0 - smoothstep(FAR_FULL, FAR_FADE, dist))
		* edges.x * edges.y * edges.z * float((debug_view & 128) == 0);
	light = (env_haze.rgb * HAZE_GAIN
		+ left_saber_color.rgb * SABER_GAIN * saber_light(world, left_saber)
		+ right_saber_color.rgb * SABER_GAIN * saber_light(world, right_saber)
		+ cut_wave_light(world) * CUT_WAVE_GAIN) * shown;
	corner = UV;
	vec4 view = VIEW_MATRIX * vec4(world, 1.0);
	view.xy += UV * SIZE;
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	ALBEDO = light * max(1.0 - dot(corner, corner), 0.0);
}
