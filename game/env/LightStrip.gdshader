shader_type spatial;
render_mode unshaded, shadows_disabled;

// A light strip on a surface (the track's edge lights, the platform's border): it burns white-hot where it faces the
// eye and shows its colour on the faces turned away, so it reads as a bright tube instead of a flat saturated bar
// (AGENTS.md "Light", rule 2). Off (black) stays black. Texture-free; untuned.
#include "res://game/env/player_light.gdshaderinc"
global uniform vec4 env_haze;
// Fades into the haze's colour from fade_z.x to fade_z.y metres out along the track (-z), for strips that run on into
// the distance (the track's edge lights, TrackDeck.gd); off (0, 0) for the rest.
uniform vec2 fade_z = vec2(0.0);
uniform vec4 light_color : source_color = vec4(1.0);
// For thin strips that run far out (the track's edge lines, TrackDeck.STRIP_WIDTH): never thinner than min_pixels on
// screen, dimmed by the width they gained instead, so far lines don't flicker (as NeonRibbon.gdshader); 0 is off.
uniform float min_pixels = 0.0;
// How white the strip's top face burns whatever the angle, like Beat Saber's white-hot lane lines; 0 leaves only the
// facing-the-eye core.
uniform float top_white = 0.0;
const float CORE_WHITE = 0.8;
const float CORE_SHARPNESS = 2.0;
// how bright a cut's wave runs along the strip (player_light.gdshaderinc)
const float CUT_WAVE_GAIN = 1.5;

varying vec3 world;
varying float up;
varying float widened;

void vertex() {
	widened = 1.0;
	float half_width = abs(VERTEX.x) * length(MODEL_MATRIX[0].xyz);
	if (min_pixels > 0.0 && half_width > 0.0) {
		float dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
		float pixel = 2.0 * dist / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
		widened = max(1.0, 0.5 * min_pixels * pixel / half_width);
		VERTEX.x *= widened;
	}
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up = (MODEL_MATRIX * vec4(NORMAL, 0.0)).y;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float peak = max(light_color.r, max(light_color.g, light_color.b));
	ALBEDO = mix(light_color.rgb, vec3(peak), max(CORE_WHITE * pow(facing, CORE_SHARPNESS), top_white * step(0.5, up)));
	// sqrt, as NeonRibbon: dimming by the full gained width made far lines too faint
	ALBEDO /= sqrt(widened);
	ALBEDO += cut_wave_light(world) * CUT_WAVE_GAIN;
	if (fade_z.y > fade_z.x) {
		ALBEDO = mix(ALBEDO, env_haze.rgb, smoothstep(fade_z.x, fade_z.y, -world.z));
	}
}
