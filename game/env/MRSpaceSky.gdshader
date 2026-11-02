shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, cull_front, depth_draw_never;

// The sky of the mixed-reality world behind the room's portals (MRSpace.gd; owner, 2026-11-02: "the room floats in
// space", concept C): black space, stars worked out from the view direction, a faint neutral band of far dust across
// it, and the source the notes come from far down the track: a white-hot core in a glow of the lights' colour
// (env_light; AGENTS.md "Light", rule 2). Drawn on the inside of a sphere round the world's origin. BLOCKOUT, untuned.
global uniform vec4 env_light;

// stars: cells per unit of direction (more = more, smaller stars), the share of cells that hold one, a star's radius
// in cells, the brightest star
const float STAR_CELLS = 140.0;
const float STAR_SHARE = 0.28;
const float STAR_RADIUS = 0.09;
const float STAR_PEAK = 0.85;
// stars never thinner than this many pixels, dimmed by the area they gained (no shimmer), then lifted so the
// faint ones still read
const float STAR_MIN_PIXELS = 1.2;
const float STAR_SMALL_BOOST = 6.0;
// the dust band: its axis (the band runs round the sky at right angles to it), its half width (in sin of the angle),
// its brightness, and how much of the lights' colour it takes
const vec3 BAND_AXIS = vec3(0.35, 0.9, 0.25);
const float BAND_HALF = 0.22;
const float BAND_GLOW = 0.05;
const float BAND_TINT = 0.2;
// the source: its direction (down the track), the core's and the glow's angular size (1 - cos), their brightness
const vec3 SOURCE_DIR = vec3(0.0, 0.0, -1.0);
const float CORE_SIZE = 0.00004;
const float GLOW_SIZE = 0.0025;
const float CORE_PEAK = 1.0;
const float GLOW_PEAK = 0.55;

varying vec3 dir;

void vertex() {
	dir = normalize((MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz);
}

// Three pseudo-random numbers in 0..1 for a cell.
vec3 hash3(vec3 cell) {
	vec3 p = fract(cell * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// Smooth value noise on a direction scaled by `scale`, 0..1.
float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i).x, n100 = hash3(i + vec3(1, 0, 0)).x, n010 = hash3(i + vec3(0, 1, 0)).x;
	float n110 = hash3(i + vec3(1, 1, 0)).x, n001 = hash3(i + vec3(0, 0, 1)).x, n101 = hash3(i + vec3(1, 0, 1)).x;
	float n011 = hash3(i + vec3(0, 1, 1)).x, n111 = hash3(i + vec3(1, 1, 1)).x;
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

void fragment() {
	vec3 d = normalize(dir);
	vec3 p = d * STAR_CELLS;
	vec3 cell = floor(p);
	vec3 h = hash3(cell);
	float pixel = length(fwidth(p));
	float radius = max(STAR_RADIUS, pixel * STAR_MIN_PIXELS);
	float star = step(1.0 - STAR_SHARE, h.x) * (1.0 - smoothstep(0.0, radius, length(p - cell - 0.25 - h * 0.5)));
	star *= STAR_PEAK * h.y * h.y * STAR_RADIUS * STAR_RADIUS / (radius * radius) * STAR_SMALL_BOOST;
	float across = dot(d, normalize(BAND_AXIS));
	float band = (1.0 - smoothstep(0.0, BAND_HALF, abs(across))) * (0.4 + 0.6 * noise(d * 6.0)) * BAND_GLOW;
	float facing = 1.0 - dot(d, SOURCE_DIR);
	float core = CORE_PEAK * exp(-facing / CORE_SIZE);
	float glow = GLOW_PEAK * exp(-facing / GLOW_SIZE);
	vec3 color = vec3(star) + mix(vec3(band), env_light.rgb * band * 4.0, BAND_TINT) + env_light.rgb * glow;
	ALBEDO = mix(color, vec3(1.0), clamp(core, 0.0, 1.0));
}
