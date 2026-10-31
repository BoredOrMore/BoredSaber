shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

// Monolith's low clouds (MonolithRig.gd; owner, 2026-10-31: stylized, drifting among the terraces): one flat layer of
// drifting noise, cut where it falls below `open` so the valley shows through the gaps, and heaved up by the same noise so
// each cloud domes up toward its middle (HEAVE). Opaque with holes (discard), so it costs no blending. Layers:
//   1. body: two flat tones like a painted cloud, a darker band round its edge and a lit top, with a crisp step between
//      them (TOP_STEP), each a neutral grey plus the haze's colour
//   2. distance: fades into the plain haze far away
// Neutral, never the lights' colours (AGENTS.md "Colour rules"). BLOCKOUT, all values untuned.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"

// the share of the layer that is open air, and an offset so layers don't repeat each other (MonolithRig)
uniform float open = 0.5;
uniform float seed = 0.0;
// cloud size (one noise cell per this many metres) and drift (metres per second)
const float CELL = 140.0;
const vec2 DRIFT = vec2(1.2, 0.5);
// how high a cloud's middle domes up above the layer (metres, at the noise's top)
const float HEAVE = 14.0;
// the two tones: a neutral grey plus this many times the haze, for the edge band and the lit top; the top starts this
// far into the noise past `open`, and the step between them is this soft
const vec2 EDGE_TONE = vec2(0.02, 0.5);
const vec2 TOP_TONE = vec2(0.06, 1.3);
const float TOP_STEP = 0.08;
const float STEP_SOFT = 0.01;
// far: all haze from x to y metres
const vec2 FAR_FADE = vec2(400.0, 950.0);

varying vec3 haze_v;
varying vec3 world;

// A random value per whole cell.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth value noise, 0 to 1.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// The cloud's density at a point on the layer: 0 to 1, open air below `open`.
float density(vec2 xz) {
	vec2 p = (xz + TIME * DRIFT) / CELL + seed;
	return value_noise(p) * 0.65 + value_noise(p * 2.3 + 17.0) * 0.35;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += max(density(world.xz) - open, 0.0) / (1.0 - open) * HEAVE;
	haze_v = fog_lit(env_haze.rgb, world - CAMERA_POSITION_WORLD);
}

void fragment() {
	float n = density(world.xz);
	if (n < open) {
		discard;
	}
	float top = smoothstep(open + TOP_STEP - STEP_SOFT, open + TOP_STEP + STEP_SOFT, n);
	vec3 body = mix(vec3(EDGE_TONE.x) + haze_v * EDGE_TONE.y, vec3(TOP_TONE.x) + haze_v * TOP_TONE.y, top);
	float far = smoothstep(FAR_FADE.x, FAR_FADE.y, length(world - CAMERA_POSITION_WORLD));
	ALBEDO = fog_dither(fog_result(mix(body, haze_v, far), VERTEX), FRAGCOORD.xy);
}
