shader_type spatial;
// The glow in front of each laser fixture's lens (LaserFixtures.gd): the bright spot where the beam leaves, which
// AGENTS.md "Light" rule 5 asks for, shown from every side. In layers:
//   1. a quad that always faces the eye, pulled a little toward it so the fixture's own head doesn't hide it
//   2. a soft round falloff, white-hot at the centre and the beam's colour around it (rule 2), as bright as the beam
// Light, so added on top (blend_add) and never written to depth. The beam's colour is the copy's custom data; black
// (light off) adds nothing. Values untuned.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// 1. metres toward the eye
const float TOWARD_EYE = 0.3;
// 2. how fast the glow falls off from the centre (higher = smaller), how far the centre leans toward white, and how
// bright the glow is at most
const float FALLOFF = 9.0;
const float CORE_WHITE = 0.7;
const float GAIN = 0.9;

varying vec3 beam;

void vertex() {
	beam = INSTANCE_CUSTOM.rgb;
	vec3 centre = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 to_eye = normalize(CAMERA_POSITION_WORLD - centre);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_eye) + vec3(1e-4, 0.0, 0.0));
	vec3 up = cross(to_eye, right);
	vec3 world = centre + to_eye * TOWARD_EYE + (right * VERTEX.x + up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float glow = exp(-dot(p, p) * FALLOFF);
	float level = max(beam.r, max(beam.g, beam.b));
	ALBEDO = mix(beam, vec3(level), CORE_WHITE * glow) * glow * GAIN;
}
