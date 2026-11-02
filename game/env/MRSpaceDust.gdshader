shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, blend_add, depth_draw_never, cull_disabled;

// Near dust in the mixed-reality world (MRSpace.gd): small soft points at tens to hundreds of metres, turned to face
// the eye, so the space behind a portal shows depth as the player moves (the stars are too far to shift). Never
// thinner than MIN_PIXELS on screen, dimmed by the width it gained, so far points don't flicker. BLOCKOUT, untuned.

const float BRIGHTNESS = 0.5;
const float MIN_PIXELS = 1.5;

varying float dim;

void vertex() {
	vec3 centre = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	float pixel = 2.0 * -centre.z / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float grown = max(size, MIN_PIXELS * pixel);
	dim = size * size / (grown * grown);
	POSITION = PROJECTION_MATRIX * vec4(centre + vec3(VERTEX.xy * grown, 0.0), 1.0);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	ALBEDO = vec3(BRIGHTNESS * dim * (1.0 - smoothstep(0.2, 1.0, r)));
}
