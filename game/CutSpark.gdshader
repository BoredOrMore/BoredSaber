shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// A cut spark that becomes dust (CutFlash; owner, 2026-10-28): born a crisp streak streak_length long along its path
// (the particle's y, CPUParticles3D particle_flag_align_y), it shrinks within streak_seconds to a crisp point
// point_size across, turned to the eye; it swirls round the cut in a vortex the swing sets (CutFlash.flash: centre,
// axis, spin) that slows as the drag takes it (spin (1 - e^(-drag t)) / drag radians after t seconds), while the
// particle's own motion (drag, drift past the player) carries it off. Never thinner than MIN_PIXELS on screen (dimmed
// by the size it gained instead), so far points don't flicker. Fades over its life (COLOR.a from the colour ramp) and
// near the eye, so nothing hangs in the player's face. Untuned.
uniform vec3 vortex_centre;
uniform vec3 vortex_axis = vec3(0.0, 0.0, 1.0);
uniform float vortex_spin = 0.0;
uniform float vortex_drag = 2.0;
// the particles' lifetime, to turn the life share in INSTANCE_CUSTOM.y into seconds
uniform float lifetime = 1.5;
uniform float streak_length = 0.12;
uniform float streak_seconds = 0.12;
uniform float point_size = 0.022;
// a gentle sway in the air, slow noise per spark: up to SWAY metres, growing in over SWAY_IN seconds, at about
// SWAY_HZ (owner, 2026-10-28: lighter, like dust)
const float SWAY = 0.05;
const float SWAY_IN = 0.4;
const float SWAY_HZ = 0.7;
// the smallest it gets on screen (pixels), and how bright it is against its colour (additive)
const float MIN_PIXELS = 1.5;
const float GAIN = 1.8;
// fully gone this close to the eye, fully there from NEAR_FULL (m)
const float NEAR_GONE = 0.25;
const float NEAR_FULL = 0.4;

varying float near_fade;
varying float dim;
// the quad's length over its width, for the capsule's shape
varying float aspect;

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
	float seed = float(INSTANCE_ID) * 1.618;
	float w = TAU * SWAY_HZ * t;
	swirled += vec3(sin(w + seed * 3.1), sin(w * 0.83 + seed * 1.7), sin(w * 1.21 + seed * 2.3))
			* SWAY * smoothstep(0.0, SWAY_IN, t);
	near_fade = smoothstep(NEAR_GONE, NEAR_FULL, distance(swirled, CAMERA_POSITION_WORLD));
	float scale = length(MODEL_MATRIX[0].xyz);
	vec3 to_eye = CAMERA_POSITION_WORLD - swirled;
	vec3 along = normalize(MODEL_MATRIX[1].xyz);
	vec3 side = cross(along, to_eye);
	side = length(side) > 1e-5 ? normalize(side) : normalize(cross(vec3(0.0, 1.0, 0.0), to_eye));
	// as a point it faces the eye: its "along" becomes the eye's up
	vec3 up = normalize(cross(to_eye, side));
	float streak = 1.0 - smoothstep(0.0, streak_seconds, t);
	along = normalize(mix(up, along, streak));
	float pixel = 2.0 * length(to_eye) / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float width = point_size * scale;
	float widened = max(1.0, MIN_PIXELS * pixel / width);
	float length_now = mix(width, streak_length * scale, streak);
	dim = 1.0 / sqrt(widened);
	float long_side = max(length_now, width * widened);
	aspect = long_side / (width * widened);
	vec3 world = swirled + side * VERTEX.x * width * widened + along * VERTEX.y * long_side;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
}

void fragment() {
	// a crisp capsule (a round point once the streak is gone): its edge over about a pixel, a hot centre
	vec2 p = vec2(abs(UV.x * 2.0 - 1.0), abs(UV.y * 2.0 - 1.0) * aspect);
	float d = length(vec2(p.x, max(p.y - (aspect - 1.0), 0.0)));
	float edge = 1.0 - smoothstep(1.0 - fwidth(d) * 1.5, 1.0, d);
	float core = GAIN * (1.0 - 0.5 * d);
	ALBEDO = COLOR.rgb * COLOR.a * edge * core * near_fade * dim;
}
