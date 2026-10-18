shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

// Walls to dodge: faint glass in the danger colour, framed by a band of
// diagonal danger/black hazard stripes like warning tape.
uniform vec4 danger_color : source_color = vec4(1.0, 0.69, 0.125, 1.0);
uniform vec3 stripe_dark : source_color = vec3(0.04, 0.03, 0.02);
uniform float fill_alpha = 0.12;
uniform float edge_width = 0.06;
uniform float edge_alpha = 0.9;
uniform float stripe_frequency = 6.0;

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
	float edge = 1.0 - smoothstep(edge_width * 0.8, edge_width, to_edge);
	float stripe = step(0.5, fract((pos.x + pos.y + pos.z) * stripe_frequency));
	ALBEDO = mix(danger_color.rgb, mix(stripe_dark, danger_color.rgb, stripe), edge);
	ALPHA = mix(fill_alpha, edge_alpha, edge);
}
