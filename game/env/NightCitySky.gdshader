shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The Night City sky: two rows of dark towers all around, with lit windows, light rising from the streets and a glow
// over the city ahead. Its shapes are baked into two mask textures by tools/bake_night_city_sky.py; here each mask
// only scales its light, as the other skies do. A few windows switch on or off now and then, each on its own slow
// cycle. The lights take the same uniforms as the Classic sky. Light types: 0 back lasers -> a high band,
// 1 ring lights -> roof rims and street glow, 2/3 left/right lasers -> half the windows each, 4 centre lights ->
// the glow over the city.
global uniform vec4 env_haze;
#include "res://game/env/shadow_tone.gdshaderinc"
#include "res://game/env/fog_light.gdshaderinc"
// DebugView.SKY draws the sky plain black
global uniform int debug_view;
// r haze, g window, b the window's random number, a roof rims and street glow
uniform sampler2D sharp_masks : filter_linear, repeat_disable;
// r band of the back lasers, g glow over the city
uniform sampler2D soft_masks : filter_linear, repeat_disable;
uniform lowp vec4 bg_0_tint;
uniform lowp vec4 bg_1_tint;
uniform lowp vec4 bg_2_tint;
uniform lowp vec4 bg_3_tint;
uniform lowp vec4 bg_4_tint;
uniform lowp float bg_0_intensity = 0.0;
uniform lowp float bg_1_intensity = 0.0;
uniform lowp float bg_2_intensity = 0.0;
uniform lowp float bg_3_intensity = 0.0;
uniform lowp float bg_4_intensity = 0.0;

// must match tools/bake_night_city_sky.py
const float V_TOP = 0.5 - 75.0 / 180.0;
const float V_BOTTOM = 0.5 + 5.0 / 180.0;
const float HAZE_SCALE = 1.5;
const float RIM_SCALE = 1.0;
const float BAND_SCALE = 0.25;
const float GLOW_SCALE = 0.5;
// windows: how bright they glow with their light, how faintly with the haze alone, the share switched on, and
// how many seconds each one stays as it is
const float WINDOW_LIGHT = 0.9;
const float WINDOW_HAZE = 2.0;
const float WINDOWS_ON = 0.7;
const float WINDOW_PERIOD = 6.0;

// the haze lit from the key light, per vertex: the sky and the cloud sea are fine enough meshes that it looks the same
// as per pixel, for less work (fog benchmark, 2026-10-25)
varying vec3 haze_v;
void vertex() {
	haze_v = fog_lit(env_haze.rgb, (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
}

void fragment() {
	// the haze lit from the stage's key light, seen this way (fog_light.gdshaderinc)
	vec3 haze = haze_v;
	if ((debug_view & 16) != 0) {
		ALBEDO = vec3(0.0);
	} else {
		mediump vec2 band_uv = vec2(UV.x, (UV.y - V_TOP) / (V_BOTTOM - V_TOP));
		mediump vec4 sharp = texture(sharp_masks, band_uv);
		mediump vec2 soft = texture(soft_masks, band_uv).rg;
		// each window starts its cycle at its own time, so they never all change together
		mediump float cycle = floor(TIME / WINDOW_PERIOD + sharp.b * 8.0);
		mediump float on = step(fract(sharp.b * 91.7 + cycle * 0.618), WINDOWS_ON);
		mediump vec3 window_light = mix(bg_2_tint.rgb * bg_2_intensity, bg_3_tint.rgb * bg_3_intensity, step(0.5, fract(sharp.b * 3.7)));
		ALBEDO = haze * (sharp.r * HAZE_SCALE)
				+ (window_light * WINDOW_LIGHT + haze * WINDOW_HAZE) * (sharp.g * on)
				+ bg_1_tint.rgb * (bg_1_intensity * sharp.a * RIM_SCALE)
				+ bg_0_tint.rgb * (bg_0_intensity * soft.r * BAND_SCALE)
				+ bg_4_tint.rgb * (bg_4_intensity * soft.g * GLOW_SCALE);
		ALBEDO = fog_dither(shadow_tone(ALBEDO), FRAGCOORD.xy);
	}
}
