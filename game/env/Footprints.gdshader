shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// Two thin footprint outlines on the standing platform that show the player where to stand, toes toward the track.
// Always the same, whatever the song or the player does (owner, 2026-10-29). The outline is a signed distance with a
// pixel floor, so it stays smooth and never breaks up at any distance (Quilez "2D distance functions").
uniform vec3 line_color : source_color = vec3(0.8);
// centre-to-centre gap between the feet, about shoulder width (owner, 2026-10-29), and each foot's outward turn
const float FEET_GAP = 0.30;
const float TOE_OUT_DEGREES = 8.0;
// one foot, in metres from its middle (+y toward the toes): the ball of the foot and the heel, blended together
const vec2 BALL_CENTER = vec2(0.0, 0.035);
const vec2 BALL_RADII = vec2(0.048, 0.095);
const vec2 HEEL_CENTER = vec2(0.0, -0.085);
const float HEEL_RADIUS = 0.04;
const float BLEND = 0.04;
// the outline's width in metres, and the fewest pixels it may cover
const float LINE_WIDTH = 0.008;
const float MIN_LINE_PIXELS = 1.5;

varying vec2 flat_pos;

void vertex() {
	// the platform's plane, with +y pointing down the track (toward -z)
	flat_pos = vec2(VERTEX.x, -VERTEX.z);
}

// approximate signed distance to an ellipse (exact on its axes, close enough for a thin line)
float ellipse(vec2 p, vec2 radii) {
	float k = length(p / radii);
	return (k - 1.0) * min(radii.x, radii.y);
}

float smooth_union(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

// signed distance to the right foot's outline at p (the left foot is its mirror)
float foot(vec2 p) {
	float turn = radians(TOE_OUT_DEGREES);
	p = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn))) * p;
	float ball = ellipse(p - BALL_CENTER, BALL_RADII);
	float heel = length(p - HEEL_CENTER) - HEEL_RADIUS;
	return abs(smooth_union(ball, heel, BLEND));
}

void fragment() {
	vec2 p = vec2(abs(flat_pos.x) - FEET_GAP * 0.5, flat_pos.y);
	float d = foot(p);
	float aa = fwidth(d);
	float half_width = max(LINE_WIDTH * 0.5, aa * MIN_LINE_PIXELS * 0.5);
	ALBEDO = line_color;
	ALPHA = 1.0 - smoothstep(half_width - aa, half_width + aa, d);
}
