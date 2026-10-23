shader_type spatial;
// A soft glow around the score screen's result ring, drawn in the shader instead of a screen glow pass.
// The quad is centred on the ring; distances are in metres. All values untuned.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec3 color;
uniform float how_full;
uniform float strength = 0.0;
uniform float quad_size = 0.7;
// the ring's middle radius and how far the glow spreads from it
const float RING_RADIUS = 0.2135;
const float SPREAD = 0.06;

void fragment() {
	vec2 p = (UV - 0.5) * quad_size;
	float r = length(p);
	float angle = atan(p.x, p.y) + PI;
	float lit = how_full >= 0.995 ? 1.0 : smoothstep(0.1, 0.0, angle - how_full * TAU);
	float d = (r - RING_RADIUS) / SPREAD;
	ALBEDO = color * exp(-d * d) * strength * lit;
}
