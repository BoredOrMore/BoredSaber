shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, cull_disabled;
// marks the holes' pixels, for the cloud sea and dust behind to draw only there (MRSpaceCloudSea, MRSpaceDust)
stencil_mode write, compare_always, 1;
// It writes depth like any opaque surface: with depth_draw_never Godot drew it in the transparent pass, sorted by its
// centre (the room) after the walls and arcs, so it painted over them (Bored, 2026-11-03: walls and arcs vanished in
// the portal; seen in tools/capture renders too).

// The sky of the mixed-reality world behind the room's portals (MRSpace.gd; owner, 2026-11-02: "the room floats in
// space", concept C, then three reference pictures): black space, stars worked out from the view direction, a faint
// neutral band of far dust with a nebula in the two note colours, two planets (one with a moon, one ringed) and
// shooting stars, all worked out per pixel from the view direction, and the source the notes come from far down the track: a white-hot core in a glow of the lights' colour
// (env_light; AGENTS.md "Light", rule 2). BLOCKOUT, untuned.
// Drawn on a window quad over each portal (MRSpace.show_windows), its corners pushed out along the rendered eye's rays
// to FAR_DISTANCE: each eye's pixels of the hole exactly, at the sky's depth, so only the portals' pixels pay for the
// sky (Bored, 2026-11-03; a sphere round the room ran this for every pixel of the view and discarded most of them).
// No discard: pushed from the head's centre the window needed a margin cut back per pixel, and that discard alone cost
// about 4 of the frame's 9.4 Mcyc (bench --only mr, 2026-11-04: every live part left out together saved nothing).
global uniform vec4 env_light;
global uniform vec4 left_saber_color;
global uniform vec4 right_saber_color;
// DebugView.MR_SKY_NO_* (bench --only mr): the live parts left out one at a time to measure each
global uniform int debug_view;

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
// the nebula: two clouds along the band, one in each note colour (where they overlap the colours mix), each
// pulled this far toward grey (large areas stay low in saturation; AGENTS.md "Light", rule 3), their brightness, and
// the noise scale of their shapes
const float NEBULA_GREY = 0.55;
const float NEBULA_GLOW = 0.16;
const float NEBULA_SCALE = 3.5;
// the planets (owner's references, 2026-11-02): spheres seen from the origin, each as (direction xyz, angular radius
// in radians); the big one with a small moon in front of it, the far one ringed. Placed beside the notes' source so a
// front portal shows them, never over it.
const vec4 PLANET_BIG = vec4(-0.42, 0.22, -0.88, 0.22);
const vec4 MOON = vec4(-0.24, 0.08, -0.97, 0.05);
const vec4 PLANET_RINGED = vec4(0.45, 0.26, -0.85, 0.09);
// the ring's tilt (its plane's normal) and its inner and outer radius in planet radii
const vec3 RING_NORMAL = vec3(0.35, 1.0, 1.1);
const vec2 RING_SPAN = vec2(1.45, 2.3);
const float RING_GLOW = 0.16;
// where the planets' light comes from, their surface tone lit and in shadow, and their rim in the lights' colour
const vec3 PLANET_LIGHT = vec3(0.7, 0.35, 0.6);
const float PLANET_TONE = 0.26;
const float PLANET_SHADOW = 0.015;
const float PLANET_RIM = 0.45;
// shooting stars: how many, how long one is seen, the time between them, how far it travels in that time (radians),
// its tail length, width (both radians) and peak
const int METEOR_COUNT = 3;
const float METEOR_SECONDS = 0.9;
const vec3 METEOR_PERIODS = vec3(7.0, 11.0, 13.0);
const float METEOR_TRAVEL = 0.35;
const float METEOR_TAIL = 0.2;
const float METEOR_WIDTH = 0.002;
const float METEOR_PEAK = 0.8;
const float METEOR_MIN_PIXELS = 1.5;
// the source: its direction (down the track), the core's and the glow's angular size (1 - cos), their brightness
const vec3 SOURCE_DIR = vec3(0.0, 0.0, -1.0);
const float CORE_SIZE = 0.00004;
const float GLOW_SIZE = 0.0025;
const float CORE_PEAK = 1.0;
const float GLOW_PEAK = 0.55;

// The fixed layers (baked_layers), baked once at load into a cube map (MRSpace.gd), so the game reads one texture per
// pixel instead of working out the noise and planets (the full shader cost the headset 40-69 ms a frame); stars, the
// source, meteors, the lights' tints and the nebula's colours stay live. bake_face 0..5 draws that face of the bake on
// a 2 x 2 quad filling the screen instead.
uniform samplerCube baked : filter_linear;
// the bake stores sqrt(layer * BAKE_GAIN) in 8 bits, so the faint band keeps its steps (stored as is it rounded to 0-3)
const float BAKE_GAIN = 2.0;
uniform int bake_face = -1;
// how far out the window's corners go: past everything behind the portals (the cloud sea reaches 980 m), inside the
// camera's 1024 m far plane
const float FAR_DISTANCE = 1000.0;

varying vec3 world_position;
varying vec2 face_uv;

void vertex() {
	face_uv = VERTEX.xy;
	// writing POSITION anywhere skips Godot's own projection, so both paths set it
	if (bake_face >= 0) {
		POSITION = vec4(VERTEX.xy, 0.0, 1.0);
	} else {
		vec3 corner = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		// the rendered eye: the point its projection (the eye's offset included) sends to w = 0 at the view's centre
		vec4 eye_view = INV_PROJECTION_MATRIX * vec4(0.0, 0.0, 1.0, 0.0);
		vec3 eye = (INV_VIEW_MATRIX * vec4(eye_view.xyz / eye_view.w, 1.0)).xyz;
		world_position = eye + normalize(corner - eye) * FAR_DISTANCE;
		POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world_position, 1.0));
	}
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

// The nearest hit of the view ray `d` (from the origin) with the sphere `planet` at distance 1, or -1 for none.
float sphere_hit(vec3 d, vec4 planet) {
	vec3 c = normalize(planet.xyz);
	float r = sin(planet.w);
	float b = dot(d, c);
	float h = b * b - 1.0 + r * r;
	return h > 0.0 ? b - sqrt(h) : -1.0;
}

// The neutral tone of `planet` where the view ray `d` hits it at `t`: lit with soft banded noise, a dark side (baked).
float planet_tone(vec3 d, vec4 planet, float t, float seed) {
	vec3 c = normalize(planet.xyz);
	vec3 n = normalize(d * t - c);
	float lit = max(dot(n, normalize(PLANET_LIGHT)), 0.0);
	float surface = 0.6 + 0.4 * noise(n * 4.0 + seed) * noise(vec3(n.y * 9.0, seed, 0.0));
	return PLANET_SHADOW + PLANET_TONE * lit * surface;
}

// The rim glow in the lights' colour on `planet` where the view ray `d` hits it at `t` (each frame, as env_light moves).
vec3 planet_rim(vec3 d, vec4 planet, float t) {
	vec3 n = normalize(d * t - normalize(planet.xyz));
	float lit = max(dot(n, normalize(PLANET_LIGHT)), 0.0);
	float rim = pow(1.0 - max(dot(n, -d), 0.0), 3.0);
	return env_light.rgb * rim * PLANET_RIM * (0.3 + 0.7 * lit);
}

// The ring's light where the view ray `d` crosses its plane, and the ray's distance there (or -1 for none).
vec2 ring(vec3 d, vec4 planet) {
	vec3 c = normalize(planet.xyz);
	vec3 axis = normalize(RING_NORMAL);
	float t = dot(c, axis) / dot(d, axis);
	float across = length(d * t - c) / sin(planet.w);
	if (t <= 0.0 || across < RING_SPAN.x || across > RING_SPAN.y) {
		return vec2(0.0, -1.0);
	}
	float bands = 0.5 + 0.5 * sin(across * 23.0) * sin(across * 7.0);
	float edge = smoothstep(RING_SPAN.x, RING_SPAN.x + 0.1, across) * (1.0 - smoothstep(RING_SPAN.y - 0.2, RING_SPAN.y, across));
	return vec2(RING_GLOW * bands * edge, t);
}

// Shooting stars' light along the view direction `d`: a white head with a tail in the lights' colour.
vec3 meteors(vec3 d, float pixel) {
	vec3 light = vec3(0.0);
	for (int i = 0; i < METEOR_COUNT; i++) {
		float period = METEOR_PERIODS[i];
		float cycle = floor(TIME / period + float(i) * 0.37);
		float age = (fract(TIME / period + float(i) * 0.37)) * period;
		if (age > METEOR_SECONDS) {
			continue;
		}
		vec3 h = hash3(vec3(cycle, float(i), 5.0));
		vec3 start = normalize(vec3(h.x * 1.4 - 0.7, 0.25 + h.y * 0.35, -1.0));
		vec3 heading = normalize(cross(start, vec3(h.z - 0.5, 1.0, 0.0)));
		float share = age / METEOR_SECONDS;
		vec3 head = normalize(start + heading * METEOR_TRAVEL * share);
		vec3 tail = normalize(head - heading * METEOR_TAIL);
		vec3 along = head - tail;
		float k = clamp(dot(d - tail, along) / dot(along, along), 0.0, 1.0);
		float dist = length(d - tail - along * k);
		float fade = sin(share * 3.14159);
		float width = max(METEOR_WIDTH * (0.4 + k), pixel * METEOR_MIN_PIXELS);
		float core = (1.0 - smoothstep(0.0, width, dist)) * min(METEOR_WIDTH * (0.4 + k) / width, 1.0);
		light += mix(env_light.rgb, vec3(1.0), k * k) * core * k * fade * METEOR_PEAK;
	}
	return light;
}

// What the bake keeps for direction `d` (all of it fixed, nothing tied to time or the lights): r the neutral light (the
// band without its tint, the ring, a planet's lit surface), g and b the share of the left and right nebula colour.
vec3 baked_layers(vec3 d) {
	float across = dot(d, normalize(BAND_AXIS));
	float band = (1.0 - smoothstep(0.0, BAND_HALF, abs(across))) * (0.4 + 0.6 * noise(d * 6.0)) * BAND_GLOW;
	vec3 cloud_a = vec3(noise(d * NEBULA_SCALE + 3.0), noise(d * NEBULA_SCALE * 2.3 + 9.0), 0.0);
	vec3 cloud_b = vec3(noise(d * NEBULA_SCALE + 17.0), noise(d * NEBULA_SCALE * 2.3 + 21.0), 0.0);
	float in_band = 1.0 - smoothstep(0.0, BAND_HALF * 1.6, abs(across));
	float left_cloud = smoothstep(0.45, 0.85, cloud_a.x * 0.7 + cloud_a.y * 0.3) * in_band;
	float right_cloud = smoothstep(0.45, 0.85, cloud_b.x * 0.7 + cloud_b.y * 0.3) * in_band;
	vec3 layers = vec3(band * (1.0 - BAND_TINT), left_cloud * NEBULA_GLOW, right_cloud * NEBULA_GLOW);
	float big = sphere_hit(d, PLANET_BIG);
	float moon = sphere_hit(d, MOON);
	float ringed = sphere_hit(d, PLANET_RINGED);
	vec2 ring_light = ring(d, PLANET_RINGED);
	bool ring_behind = ring_light.y > 0.0 && dot(d * ring_light.y - normalize(PLANET_RINGED.xyz), d) > 0.0;
	if (ring_light.y > 0.0 && ring_behind) {
		layers.r += ring_light.x;
	}
	if (ringed > 0.0) {
		layers = vec3(planet_tone(d, PLANET_RINGED, ringed, 3.0), 0.0, 0.0);
	}
	if (ring_light.y > 0.0 && !ring_behind) {
		layers.r += ring_light.x;
	}
	if (big > 0.0) {
		layers = vec3(planet_tone(d, PLANET_BIG, big, 11.0), 0.0, 0.0);
	}
	if (moon > 0.0) {
		layers = vec3(planet_tone(d, MOON, moon, 23.0), 0.0, 0.0);
	}
	return layers;
}

// The direction a cube map face's pixel looks along (OpenGL's face layout, which Cubemap uses): face 0..5 is +x, -x, +y,
// -y, +z, -z; uv is -1..1 across the face, as the bake quad's clip position (checked against the live sky).
vec3 face_direction(int face, vec2 uv) {
	if (face == 0) {
		return vec3(1.0, -uv.y, -uv.x);
	} else if (face == 1) {
		return vec3(-1.0, -uv.y, uv.x);
	} else if (face == 2) {
		return vec3(uv.x, 1.0, uv.y);
	} else if (face == 3) {
		return vec3(uv.x, -1.0, -uv.y);
	} else if (face == 4) {
		return vec3(uv.x, -uv.y, 1.0);
	}
	return vec3(-uv.x, -uv.y, -1.0);
}

void fragment() {
	if (bake_face >= 0) {
		// a face of the bake, filling the screen (MRSpace.gd); the quad's position is the face's uv as Cubemap reads the
		// viewport's image (checked against the live sky on the desktop)
		ALBEDO = sqrt(baked_layers(normalize(face_direction(bake_face, face_uv))) * BAKE_GAIN);
	} else {
		vec3 d = normalize(world_position - CAMERA_POSITION_WORLD);
		vec3 p = d * STAR_CELLS;
		float pixel = length(fwidth(p));
		float pixel_angle = length(fwidth(d));
		vec3 stored = (debug_view & 67108864) != 0 ? vec3(0.3) : texture(baked, d).rgb;
		vec3 layers = stored * stored / BAKE_GAIN;
		bool planets = (debug_view & 16777216) == 0;
		float big = planets ? sphere_hit(d, PLANET_BIG) : -1.0;
		float moon = planets ? sphere_hit(d, MOON) : -1.0;
		float ringed = planets ? sphere_hit(d, PLANET_RINGED) : -1.0;
		vec3 color;
		if (moon > 0.0) {
			color = layers.r + planet_rim(d, MOON, moon);
		} else if (big > 0.0) {
			color = layers.r + planet_rim(d, PLANET_BIG, big);
		} else if (ringed > 0.0) {
			color = layers.r + planet_rim(d, PLANET_RINGED, ringed);
		} else {
			float star = 0.0;
			if ((debug_view & 4194304) == 0) {
				vec3 cell = floor(p);
				vec3 h = hash3(cell);
				float radius = max(STAR_RADIUS, pixel * STAR_MIN_PIXELS);
				star = step(1.0 - STAR_SHARE, h.x) * (1.0 - smoothstep(0.0, radius, length(p - cell - 0.25 - h * 0.5)));
				star *= STAR_PEAK * h.y * h.y * STAR_RADIUS * STAR_RADIUS / (radius * radius) * STAR_SMALL_BOOST;
			}
			float facing = 1.0 - dot(d, SOURCE_DIR);
			bool source = (debug_view & 33554432) == 0;
			float core = source ? CORE_PEAK * exp(-facing / CORE_SIZE) : 0.0;
			float glow = source ? GLOW_PEAK * exp(-facing / GLOW_SIZE) : 0.0;
			vec3 nebula = mix(left_saber_color.rgb, vec3(0.5), NEBULA_GREY) * layers.g
				+ mix(right_saber_color.rgb, vec3(0.5), NEBULA_GREY) * layers.b;
			// the band's tinted share: the baked neutral share is band * (1 - BAND_TINT), the tint band * 4 * BAND_TINT
			vec3 band_tint = env_light.rgb * layers.r * 4.0 * BAND_TINT / (1.0 - BAND_TINT);
			color = vec3(star) + layers.r + band_tint + nebula + env_light.rgb * glow;
			color = mix(color, vec3(1.0), clamp(core, 0.0, 1.0));
			if ((debug_view & 8388608) == 0) {
				color += meteors(d, pixel_angle);
			}
		}
		ALBEDO = color;
	}
}
