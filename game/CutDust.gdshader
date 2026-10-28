shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// A mote of a cut's dust (CutFlash, doc/research/cut-dust-plan.md option 2): a soft round speck turned to the eye that
// swirls round the cut in a vortex set by the swing (CutFlash.flash sets centre, axis and spin per cut) and drifts
// away with the particles' own motion (CPUParticles3D: velocity, drag and a drift past the player). The vortex slows
// as the drag takes it: it has turned spin (1 - e^(-drag t)) / drag radians after t seconds. Fades out over its life
// (COLOR.a from the colour ramp) and near the eye, so nothing hangs in the player's face. Untuned.
uniform vec3 vortex_centre;
uniform vec3 vortex_axis = vec3(0.0, 0.0, 1.0);
// radians per second at the start, and how fast the spin dies away (per second)
uniform float vortex_spin = 0.0;
uniform float vortex_drag = 2.0;
// the particles' lifetime, to turn the life share in INSTANCE_CUSTOM.y into seconds
uniform float lifetime = 1.5;
// fully gone this close to the eye, fully there from NEAR_FULL (m)
const float NEAR_GONE = 0.25;
const float NEAR_FULL = 0.4;

varying float near_fade;

// `v` turned `angle` radians round the unit `axis` (Rodrigues).
vec3 turn(vec3 v, vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

void vertex() {
	float t = INSTANCE_CUSTOM.y * lifetime;
	float angle = vortex_spin * (1.0 - exp(-vortex_drag * t)) / vortex_drag;
	vec3 particle = MODEL_MATRIX[3].xyz;
	vec3 swirled = vortex_centre + turn(particle - vortex_centre, vortex_axis, angle);
	near_fade = smoothstep(NEAR_GONE, NEAR_FULL, distance(swirled, CAMERA_POSITION_WORLD));
	// a billboard at the swirled place, keeping the particle's own scale
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 world = swirled + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float soft = 1.0 - smoothstep(0.2, 1.0, r);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * soft * near_fade;
}
