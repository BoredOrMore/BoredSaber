shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The Neon Grid sky: a retro sunset worked out from the view direction, with no textures. Its lights take
// the same uniforms as the Classic sky (bg_<type>_tint, bg_<type>_intensity), so EventDriver drives both
// alike, and with every light off only the haze is left. Light types: 0 back lasers -> a high band,
// 1 ring lights -> the horizon line and the mountain rims, 2/3 left/right lasers -> glow on that side,
// 4 centre lights -> the sun. All values untuned.
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

// same haze as the Classic sky, so both share one air colour
const float SKY_HAZE = 0.25;
const float HORIZON_SHARPNESS = 10.0;
const float BAND_ELEVATION = 0.35;
const float BAND_SHARPNESS = 12.0;
const float BAND_STRENGTH = 0.18;
const float HORIZON_LINE_SHARPNESS = 40.0;
const float HORIZON_LINE_STRENGTH = 0.8;
const float SIDE_STRENGTH = 0.2;
// straight down the track, a little above the horizon
const vec3 SUN_DIR = vec3(0.0, 0.139, -0.990);
const float SUN_RADIUS = 0.2;
const float SUN_STRENGTH = 0.9;
const float SUN_GLOW = 0.35;
const float SUN_GLOW_WIDTH = 0.15;
// horizontal cuts across the lower half of the sun, widening toward its bottom edge
const float SUN_STRIPES = 7.0;
const float SUN_STRIPE_GAP = 0.6;
const float MOUNTAIN_HEIGHT = 0.15;
// mountains are lower straight ahead, so the sun stays in view
const float MOUNTAIN_FRONT = 0.35;
const float MOUNTAIN_SHADE = 0.3;
const float RIM_WIDTH = 0.012;
const float RIM_STRENGTH = 0.6;

varying vec3 dir;

void vertex() {
	dir = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - NODE_POSITION_WORLD;
}

void fragment() {
	vec3 d = normalize(dir);
	float elev = d.y;
	// 0 straight down the track, +-PI behind the player
	float az = atan(d.x, -d.z);

	vec3 sky = env_haze.rgb * (SKY_HAZE + exp(-abs(elev) * HORIZON_SHARPNESS));
	sky += bg_0_tint.rgb * bg_0_intensity * BAND_STRENGTH * exp(-abs(elev - BAND_ELEVATION) * BAND_SHARPNESS);
	vec3 ring_light = bg_1_tint.rgb * bg_1_intensity;
	sky += ring_light * HORIZON_LINE_STRENGTH * exp(-abs(elev) * HORIZON_LINE_SHARPNESS);
	float side_fade = exp(-abs(elev) * 4.0) * SIDE_STRENGTH;
	sky += bg_2_tint.rgb * bg_2_intensity * smoothstep(0.2, 1.0, -d.x) * side_fade;
	sky += bg_3_tint.rgb * bg_3_intensity * smoothstep(0.2, 1.0, d.x) * side_fade;

	vec3 sun_color = bg_4_tint.rgb * bg_4_intensity;
	float r = distance(d, SUN_DIR);
	float px = fwidth(r);
	float disc = 1.0 - smoothstep(SUN_RADIUS - px, SUN_RADIUS + px, r);
	// -1 at the bottom of the sun, 1 at the top
	float v = (d.y - SUN_DIR.y) / SUN_RADIUS;
	float stripes = v * SUN_STRIPES;
	float spx = fwidth(stripes);
	float gap = clamp(-v, 0.0, 1.0) * SUN_STRIPE_GAP;
	float cut = v > 0.0 ? 1.0 : smoothstep(gap - spx, gap + spx, fract(stripes));
	sky += sun_color * SUN_STRENGTH * mix(0.6, 1.4, v * 0.5 + 0.5) * disc * cut;
	sky += sun_color * SUN_GLOW * exp(-max(r - SUN_RADIUS, 0.0) / SUN_GLOW_WIDTH);

	// whole-number frequencies of the azimuth, so the ridge line meets itself behind the player
	float ridge = (0.5 + 0.5 * sin(az * 3.0 + 1.0)) * (0.6 + 0.4 * sin(az * 7.0 + 2.0)) + 0.1 * sin(az * 19.0);
	float height = MOUNTAIN_HEIGHT * ridge * mix(MOUNTAIN_FRONT, 1.0, smoothstep(0.2, 1.0, abs(az)));
	float mpx = fwidth(elev);
	float mountain = 1.0 - smoothstep(height - mpx, height + mpx, elev);
	vec3 rock = env_haze.rgb * MOUNTAIN_SHADE + ring_light * RIM_STRENGTH * exp(-max(height - elev, 0.0) / RIM_WIDTH);
	ALBEDO = mix(sky, rock, mountain);
}
