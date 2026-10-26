shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The Neon Grid sky: a retro sunset with a striped sun, mountain silhouettes and a horizon line. Its shapes are
// baked into two mask textures by tools/bake_neon_grid_sky.py (working them out per pixel cost about 4.5 ms of
// GPU a frame on the Pico 4); here each mask only scales its light, as the Classic sky does with its bg_0..4
// maps. The lights take the same uniforms as the Classic sky (bg_<type>_tint, bg_<type>_intensity), so
// EventDriver drives both alike, and with every light off only the haze is left. Light types: 0 back lasers ->
// a high band, 1 ring lights -> the horizon line and the mountain rims, 2/3 left/right lasers -> glow on that
// side, 4 centre lights -> the sun.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"
// DebugView.SKY draws the sky plain black
global uniform int debug_view;
// r haze, g sun, b ring lights (horizon line and rims)
uniform sampler2D sharp_masks : filter_linear, repeat_disable;
// r band of the back lasers, g side glow
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

// must match tools/bake_neon_grid_sky.py: the UV.y band the masks cover, and the scale each mask is stored at
const float V_TOP = 0.5 - 50.0 / 180.0;
const float V_BOTTOM = 0.5 + 5.0 / 180.0;
const float HAZE_SCALE = 0.75;
const float SUN_SCALE = 2.0;
const float RING_SCALE = 1.5;
const float BAND_SCALE = 0.25;
const float SIDE_SCALE = 0.25;
// The horizon line and mountain rims (ring lights) and the sun (centre lights) are the shapes these lights trace:
// where a mask is strongest (the middle of a line, the sun's body) the light burns toward white, its colour stays
// in the falloff (AGENTS.md "Light", rule 2). RING_GAIN and SUN_GAIN make them read as neon outlines and a sun
// that clearly beats with its lights, now that Neon Grid keeps the view clear of other fixtures. Untuned.
const float RING_GAIN = 1.6;
const float SUN_GAIN = 1.4;
const float CORE_WHITE = 0.7;
// The sun never goes out (the player wants it kept as the scene's focal point): with the centre lights off it
// stays at SUN_FLOOR of full brightness in their last colour, and rises from there as they turn on or flash.
const float SUN_FLOOR = 0.4;

// A light's colour where it traces a shape: toward white where the mask (0..1) is strongest.
vec3 traced(vec3 tint, float mask) {
	float peak = max(tint.r, max(tint.g, tint.b));
	return mix(tint, vec3(peak), CORE_WHITE * smoothstep(0.5, 1.0, mask));
}

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
		// UV.x 0.5 is straight down the track, above 0.5 is the player's left
		mediump vec2 band_uv = vec2(UV.x, (UV.y - V_TOP) / (V_BOTTOM - V_TOP));
		mediump vec3 sharp = texture(sharp_masks, band_uv).rgb;
		mediump vec2 soft = texture(soft_masks, band_uv).rg;
		mediump vec3 side_light = mix(bg_3_tint.rgb * bg_3_intensity, bg_2_tint.rgb * bg_2_intensity, step(0.5, UV.x));
		ALBEDO = haze * (sharp.r * HAZE_SCALE)
				+ traced(bg_4_tint.rgb, sharp.g) * (mix(SUN_FLOOR, 1.0, bg_4_intensity) * sharp.g * SUN_SCALE * SUN_GAIN)
				+ traced(bg_1_tint.rgb, sharp.b) * (bg_1_intensity * sharp.b * RING_SCALE * RING_GAIN)
				+ bg_0_tint.rgb * (bg_0_intensity * soft.r * BAND_SCALE)
				+ side_light * (soft.g * SIDE_SCALE);
		ALBEDO = fog_dither(ALBEDO, FRAGCOORD.xy);
	}
}
