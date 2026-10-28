shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// A cut spark, as Beat Saber's (CutFlash moves it: burst, drag, a little gravity, the blades' push; owner, 2026-10-28):
// a crisp streak along its path (the instance's y axis) as long as the distance it covers in STREAK_SECONDS at its
// speed (INSTANCE_CUSTOM.z), between STREAK_MIN point sizes and streak_length, so it shortens as it slows (Beat Saber's
// stay short streaks to the end) and stretches again when a blade pushes it. Never thinner than MIN_PIXELS on screen (dimmed by the size it gained
// instead), so far points don't flicker. Hot white cooling to its tint (COLOR) within WHITE_SHARE of its life; full
// brightness (INSTANCE_CUSTOM.x) until FADE_FROM of its life (INSTANCE_CUSTOM.y), then fading out; and faded near the
// eye, so nothing hangs in the player's face. Untuned until seen on the headset.
uniform float streak_length = 0.12;
uniform float point_size = 0.022;
const float STREAK_SECONDS = 0.04;
const float STREAK_MIN = 2.5;
const float WHITE_SHARE = 0.25;
const float FADE_FROM = 0.55;
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

void vertex() {
	float life = INSTANCE_CUSTOM.y;
	COLOR = vec4(mix(vec3(1.0), COLOR.rgb, smoothstep(0.0, WHITE_SHARE, life)),
			INSTANCE_CUSTOM.x * (1.0 - smoothstep(FADE_FROM, 1.0, life)));
	vec3 at = MODEL_MATRIX[3].xyz;
	near_fade = smoothstep(NEAR_GONE, NEAR_FULL, distance(at, CAMERA_POSITION_WORLD));
	float scale = length(MODEL_MATRIX[0].xyz);
	vec3 to_eye = CAMERA_POSITION_WORLD - at;
	vec3 along = normalize(MODEL_MATRIX[1].xyz);
	vec3 side = cross(along, to_eye);
	side = length(side) > 1e-5 ? normalize(side) : normalize(cross(vec3(0.0, 1.0, 0.0), to_eye));
	float pixel = 2.0 * length(to_eye) / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float width = point_size * scale;
	float widened = max(1.0, MIN_PIXELS * pixel / width);
	float length_now = clamp(INSTANCE_CUSTOM.z * STREAK_SECONDS, point_size * STREAK_MIN, streak_length) * scale;
	dim = 1.0 / sqrt(widened);
	float long_side = max(length_now, width * widened);
	aspect = long_side / (width * widened);
	vec3 world = at + side * VERTEX.x * width * widened + along * VERTEX.y * long_side;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
}

void fragment() {
	// a crisp capsule (round at both ends): its edge over about a pixel, a hot centre
	vec2 p = vec2(abs(UV.x * 2.0 - 1.0), abs(UV.y * 2.0 - 1.0) * aspect);
	float d = length(vec2(p.x, max(p.y - (aspect - 1.0), 0.0)));
	float edge = 1.0 - smoothstep(1.0 - fwidth(d) * 1.5, 1.0, d);
	float core = GAIN * (1.0 - 0.5 * d);
	ALBEDO = COLOR.rgb * COLOR.a * edge * core * near_fade * dim;
}
