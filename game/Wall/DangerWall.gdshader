shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

// Walls to dodge: faint glass in the danger colour, framed by a band of
// diagonal danger/dark hazard stripes like warning tape. Stripe and band edges
// are anti-aliased with screen-space derivatives (fwidth), and the stripes fade
// to their average colour once they get too fine to draw, so they don't shimmer.
uniform vec4 danger_color : source_color = vec4(1.0, 0.69, 0.125, 1.0);
// brightness of the dark stripes as a fraction of the danger colour; 0.35 keeps the
// contrast near 50%, under the 70-87% where stripes start to cause pattern glare
// (Monger, Wilkins & Allen 2015, doi:10.3389/fpsyg.2015.01651)
uniform float stripe_dark_level = 0.35;
uniform float fill_alpha = 0.12;
uniform float edge_width = 0.06;
uniform float edge_alpha = 0.75;
// stripes per metre along the diagonal
uniform float stripe_frequency = 3.0;

varying vec3 pos;
varying vec3 half_size;

void vertex() {
	pos = VERTEX;
	// a BoxMesh without subdivisions only has corner vertices, so this is the
	// same for every vertex: half the wall's size, whatever size it spawned at
	half_size = abs(VERTEX);
}

void fragment() {
	// distance to the box edges along each axis; on a face one of them is 0,
	// and the middle one is the distance to the nearest edge of that face
	vec3 d = half_size - abs(pos);
	float to_edge = d.x + d.y + d.z - min(d.x, min(d.y, d.z)) - max(d.x, max(d.y, d.z));
	float edge_aa = fwidth(to_edge);
	float edge = 1.0 - smoothstep(edge_width - edge_aa, edge_width + edge_aa, to_edge);
	// a triangle wave of the diagonal, cut at its middle, gives two stripes per
	// period; its derivative sets how wide the soft step must be to cover a pixel
	float diagonal = (pos.x + pos.y + pos.z) * stripe_frequency;
	float tri = abs(fract(diagonal) - 0.5) * 2.0;
	float aa = fwidth(diagonal) * 2.0;
	float stripe = smoothstep(0.5 - aa, 0.5 + aa, tri);
	stripe = mix(stripe, 0.5, smoothstep(0.3, 0.6, aa));
	vec3 stripe_color = danger_color.rgb * mix(stripe_dark_level, 1.0, stripe);
	ALBEDO = mix(danger_color.rgb, stripe_color, edge);
	ALPHA = mix(fill_alpha, edge_alpha, edge);
}
