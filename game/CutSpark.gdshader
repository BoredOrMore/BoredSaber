shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// A cut spark, as Beat Saber's (owner, 2026-10-28). The shader moves it: from where it was born or last pushed by a
// blade (CutFlash), at the velocity it had then, under a smooth drag and a little gravity:
//   v(t) = g/k + (v0 - g/k) e^(-kt),  p(t) = p0 + (g/k) t + (v0 - g/k)(1 - e^(-kt)) / k.
// Instance data: origin p0, y axis v0, x axis' x its size, z axis (when it started on the `now` clock, its life, its
// age then; kept in the transform, as the Compatibility renderer packs colour and custom data into half floats),
// COLOR its note colour, INSTANCE_CUSTOM.x its brightness.
// A crisp streak along its path as long as the distance it covers in STREAK_SECONDS at its speed, between STREAK_MIN
// point widths and streak_length, so it shortens as it slows (Beat Saber's stay short streaks to the end) and stretches
// again when a blade pushes it. White-hot inside with a thin rim of its note colour (RIM_FROM outward; the Light
// rule's hot core, coloured falloff), for its whole life, at full brightness until FADE_FROM of its life, then fading
// out. Never thinner than MIN_PIXELS on screen (dimmed by the size it gained instead), so far points don't flicker, and
// faded near the eye, so nothing hangs in the player's face. Untuned until seen on the headset.
uniform float now;
uniform float drag = 7.0;
uniform float gravity = 1.5;
uniform float streak_length = 0.096;
uniform float point_size = 0.0176;
const float STREAK_SECONDS = 0.04;
const float STREAK_MIN = 2.5;
const float RIM_FROM = 0.45;
const float FADE_FROM = 0.55;
// the smallest it gets on screen (pixels)
const float MIN_PIXELS = 1.5;
// fully gone this close to the eye, fully there from NEAR_FULL (m)
const float NEAR_GONE = 0.25;
const float NEAR_FULL = 0.4;

varying float near_fade;
varying float dim;
// the quad's length over its width, for the capsule's shape
varying float aspect;

void vertex() {
	vec3 timing = MODEL_MATRIX[2].xyz;
	float t = now - timing.x;
	float share = (timing.z + t) / max(timing.y, 1e-4);
	if (timing.y <= 0.0 || share >= 1.0) {
		// spent or unused: outside the view
		POSITION = vec4(0.0, 0.0, 2.0, 1.0);
	} else {
		vec3 fall = vec3(0.0, -gravity / drag, 0.0);
		float keep = exp(-drag * t);
		vec3 v0 = MODEL_MATRIX[1].xyz;
		vec3 at = MODEL_MATRIX[3].xyz + fall * t + (v0 - fall) * (1.0 - keep) / drag;
		vec3 v = fall + (v0 - fall) * keep;
		float speed = length(v);
		COLOR = vec4(COLOR.rgb, INSTANCE_CUSTOM.x * (1.0 - smoothstep(FADE_FROM, 1.0, share)));
		near_fade = smoothstep(NEAR_GONE, NEAR_FULL, distance(at, CAMERA_POSITION_WORLD));
		float scale = MODEL_MATRIX[0].x;
		vec3 to_eye = CAMERA_POSITION_WORLD - at;
		vec3 along = speed > 1e-4 ? v / speed : vec3(0.0, 1.0, 0.0);
		vec3 side = cross(along, to_eye);
		side = length(side) > 1e-5 ? normalize(side) : normalize(cross(vec3(0.0, 1.0, 0.0), to_eye));
		float pixel = 2.0 * length(to_eye) / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
		float width = point_size * scale;
		float widened = max(1.0, MIN_PIXELS * pixel / width);
		float length_now = clamp(speed * STREAK_SECONDS, point_size * STREAK_MIN, streak_length) * scale;
		dim = 1.0 / sqrt(widened);
		float long_side = max(length_now, width * widened);
		aspect = long_side / (width * widened);
		vec3 world = at + side * VERTEX.x * width * widened + along * VERTEX.y * long_side;
		POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
	}
}

void fragment() {
	// a crisp capsule (round at both ends): its edge over about a pixel, white-hot inside, its note colour at the rim
	vec2 p = vec2(abs(UV.x * 2.0 - 1.0), abs(UV.y * 2.0 - 1.0) * aspect);
	float d = length(vec2(p.x, max(p.y - (aspect - 1.0), 0.0)));
	float edge = 1.0 - smoothstep(1.0 - fwidth(d) * 1.5, 1.0, d);
	vec3 hot = mix(vec3(1.0), COLOR.rgb, smoothstep(RIM_FROM, 1.0, d));
	ALBEDO = hot * COLOR.a * edge * near_fade * dim;
}
