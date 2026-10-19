shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

// Walls to dodge, built like Beat Saber's: a thin glowing frame on every edge, a soft halo drawn around
// it instead of a bloom pass, and faint glass in between, lightened toward white (Chroma's
// ObstacleColorizer colours exactly these three parts: frame, "fake glow" and core,
// github.com/Aeroluna/Heck/blob/master/Chroma/Colorizer/ObstacleColorizer.cs). Inside the frame runs a
// faint band of diagonal hazard stripes. Edges are anti-aliased with screen-space derivatives (fwidth);
// the frame never gets thinner than MIN_FRAME_PIXELS and dims instead, so it doesn't break up in the
// distance (as NeonRibbon.gdshader does), and the stripes fade to their average once they get too fine
// to draw, so they don't shimmer. All values untuned.
uniform vec4 danger_color : source_color = vec4(1.0, 0.188, 0.188, 1.0);
// brightness of the dark stripes as a fraction of the danger colour; 0.35 keeps the
// contrast near 50%, under the 70-87% where stripes start to cause pattern glare
// (Monger, Wilkins & Allen 2015, doi:10.3389/fpsyg.2015.01651)
uniform float stripe_dark_level = 0.35;
// how far the glass leans from the danger colour toward white
uniform float core_white = 0.3;
uniform float fill_alpha = 0.1;
// width of the stripe band inside the frame, and how opaque its stripes are
uniform float edge_width = 0.08;
uniform float edge_alpha = 0.35;
// stripes per metre along the diagonal
uniform float stripe_frequency = 3.0;
// the glowing frame line, in metres
uniform float frame_width = 0.025;
uniform float frame_white = 0.35;
const float MIN_FRAME_PIXELS = 1.5;
// the halo: how far in it fades and how strong it is at the frame
uniform float glow_width = 0.12;
uniform float glow_alpha = 0.35;

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
	float px = fwidth(to_edge);
	float frame_w = max(frame_width, px * MIN_FRAME_PIXELS);
	float frame = (1.0 - smoothstep(frame_w - px, frame_w + px, to_edge)) * (frame_width / frame_w);
	float band = 1.0 - smoothstep(edge_width - px, edge_width + px, to_edge);
	// a triangle wave of the diagonal, cut at its middle, gives two stripes per
	// period; its derivative sets how wide the soft step must be to cover a pixel
	float diagonal = (pos.x + pos.y + pos.z) * stripe_frequency;
	float tri = abs(fract(diagonal) - 0.5) * 2.0;
	float aa = fwidth(diagonal) * 2.0;
	float stripe = smoothstep(0.5 - aa, 0.5 + aa, tri);
	stripe = mix(stripe, 0.5, smoothstep(0.3, 0.6, aa));
	vec3 stripe_color = danger_color.rgb * mix(stripe_dark_level, 1.0, stripe);
	float glow = exp(-max(to_edge - frame_width, 0.0) / glow_width) * glow_alpha;

	vec3 col = mix(mix(danger_color.rgb, vec3(1.0), core_white), stripe_color, band);
	float alpha = mix(fill_alpha, edge_alpha, band);
	col = mix(col, danger_color.rgb, glow);
	alpha = alpha + (1.0 - alpha) * glow;
	col = mix(col, mix(danger_color.rgb, vec3(1.0), frame_white), frame);
	alpha = mix(alpha, 1.0, frame);
	ALBEDO = col;
	ALPHA = alpha;
}
