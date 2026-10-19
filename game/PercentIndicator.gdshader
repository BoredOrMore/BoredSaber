shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 color;
uniform float how_full;
// a bright spot running around the ring (the score screen's top rank); 0 = off
uniform float sparkle = 0.0;
const float SPARKLE_SPEED = 0.6;
const float SPARKLE_SHARPNESS = 12.0;

void fragment() {
	if (how_full < 0.005) {
		discard;
	}
	float x = UV.x - 0.5;
	float y = UV.y - 0.5;
	float dist_from_center_squared = x*x + y*y;
	if (dist_from_center_squared <= 0.125 || dist_from_center_squared > 0.25) {
		discard;
	}
	float angle = atan(x,y) + PI;
	if (how_full < 0.995 && angle > how_full * TAU) {
		discard;
	}
	float behind = mod(TIME * SPARKLE_SPEED * TAU - angle, TAU);
	ALBEDO = color + vec3(sparkle * exp(-behind * SPARKLE_SHARPNESS));
}
