shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The Pulse Void sky: dark empty space with a soft glow far down the track, worked out from the view direction.
// Its lights take the same uniforms as the Classic sky (bg_<type>_tint, bg_<type>_intensity), so EventDriver drives
// both alike, and with every light off only the haze is left. Light types: 0 back lasers -> a wide halo around the
// track end, 1 ring lights -> a faint band around the player, 2/3 left/right lasers -> glow on that side,
// 4 centre lights -> the core at the track end. All values untuned.
global uniform vec4 env_haze;
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

// less haze than the other skies: this one is meant to feel empty
const float SKY_HAZE = 0.06;
const vec3 TRACK_DIR = vec3(0.0, 0.0, -1.0);
const float CORE_WIDTH = 0.08;
const float CORE_STRENGTH = 0.8;
const float HALO_WIDTH = 0.5;
const float HALO_STRENGTH = 0.12;
const float BAND_SHARPNESS = 8.0;
const float BAND_STRENGTH = 0.15;
const float SIDE_STRENGTH = 0.08;

varying vec3 dir;

void vertex() {
	dir = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - NODE_POSITION_WORLD;
}

void fragment() {
	vec3 d = normalize(dir);
	// 0 looking straight down the track, 2 looking straight back
	float off_axis = 1.0 - dot(d, TRACK_DIR);
	vec3 sky = env_haze.rgb * (SKY_HAZE + exp(-off_axis / HALO_WIDTH) * 0.3);
	sky += bg_4_tint.rgb * bg_4_intensity * CORE_STRENGTH * exp(-off_axis / CORE_WIDTH);
	sky += bg_0_tint.rgb * bg_0_intensity * HALO_STRENGTH * exp(-off_axis / HALO_WIDTH);
	sky += bg_1_tint.rgb * bg_1_intensity * BAND_STRENGTH * exp(-abs(d.y) * BAND_SHARPNESS);
	float side_fade = exp(-off_axis) * SIDE_STRENGTH;
	sky += bg_2_tint.rgb * bg_2_intensity * smoothstep(0.2, 1.0, -d.x) * side_fade;
	sky += bg_3_tint.rgb * bg_3_intensity * smoothstep(0.2, 1.0, d.x) * side_fade;
	ALBEDO = sky;
}
