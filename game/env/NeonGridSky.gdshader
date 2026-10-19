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
const float HAZE_SCALE = 1.5;
const float SUN_SCALE = 2.0;
const float RING_SCALE = 1.5;
const float BAND_SCALE = 0.25;
const float SIDE_SCALE = 0.25;

void fragment() {
	if ((debug_view & 16) != 0) {
		ALBEDO = vec3(0.0);
	} else {
		// UV.x 0.5 is straight down the track, above 0.5 is the player's left
		mediump vec2 band_uv = vec2(UV.x, (UV.y - V_TOP) / (V_BOTTOM - V_TOP));
		mediump vec3 sharp = texture(sharp_masks, band_uv).rgb;
		mediump vec2 soft = texture(soft_masks, band_uv).rg;
		mediump vec3 side_light = mix(bg_3_tint.rgb * bg_3_intensity, bg_2_tint.rgb * bg_2_intensity, step(0.5, UV.x));
		ALBEDO = env_haze.rgb * (sharp.r * HAZE_SCALE)
				+ bg_4_tint.rgb * (bg_4_intensity * sharp.g * SUN_SCALE)
				+ bg_1_tint.rgb * (bg_1_intensity * sharp.b * RING_SCALE)
				+ bg_0_tint.rgb * (bg_0_intensity * soft.r * BAND_SCALE)
				+ side_light * (soft.g * SIDE_SCALE);
	}
}
