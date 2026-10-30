// Fog round 2 (doc/research/fog.md; owner, 2026-10-25), shared by the scenery, track and sky shaders:
//   in-scattering: the haze is brighter looking toward the stage's key light and a little darker looking away, as air
//   lit from one side is (Henyey-Greenstein phase, Henyey & Greenstein 1941; the direction-coloured fog of Quilez,
//   "Better fog"). fog_key: xyz the way to the key light (world, unit length), w how strong (0 off), set per stage
//   by EventDriver. The skies use the same, so the horizon meets the fog on the far scenery.
//   dither: a tiny interleaved gradient noise (Jimenez 2014) added to the colour, under a step of 8-bit colour, so
//   the dark gradients of haze and sky don't break into bands.
// Values untuned.
global uniform vec4 fog_key;
// The result moment's air (root AGENTS.md, Colour rules' exception; EventDriver.result_mood): rgb its colour, w how
// thick (per metre; 0 off). Scenery and skies go into it the farther away they are, so near things keep their colour.
global uniform vec4 result_air;
// the dither on (1) or off (0); the benchmark's fog mode turns it off to measure it (Benchmark.gd)
global uniform float fog_dither_on;
// how much the scatter leans forward (0 even, toward 1 a tight glow round the light)
const float FOG_PHASE_G = 0.55;

// The haze's colour `haze` seen along `dir` (world, from the eye; any length).
vec3 fog_lit(vec3 haze, vec3 dir) {
	// a stage without a key light skips the work (a uniform branch costs next to nothing)
	if (fog_key.w <= 0.0) {
		return haze;
	}
	float c = dot(normalize(dir), fog_key.xyz);
	float g = FOG_PHASE_G;
	float d = 1.0 + g * g - 2.0 * g * c;
	// normalised so that air lit evenly from all round would be 1
	float phase = (1.0 - g * g) / (d * sqrt(d));
	return haze * max(1.0 + fog_key.w * (phase - 1.0), 0.0);
}

// `color` seen through the result moment's air, at `view` (the fragment's view-space position, VERTEX).
vec3 fog_result(vec3 color, vec3 view) {
	// no result moment: a uniform branch, next to nothing
	if (result_air.w <= 0.0) {
		return color;
	}
	return mix(color, result_air.rgb, 1.0 - exp(-length(view) * result_air.w));
}

// `color` with a dither under one 8-bit step, by the pixel's place on screen.
vec3 fog_dither(vec3 color, vec2 frag) {
	if (fog_dither_on <= 0.0) {
		return color;
	}
	float n = fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715))));
	return color + (n - 0.5) / 255.0;
}
