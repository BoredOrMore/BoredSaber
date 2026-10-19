shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

// Walls to dodge, built like Beat Saber's: a thin glowing frame on every edge, a soft halo drawn around
// it instead of a bloom pass, and faint glass in between (Chroma's
// ObstacleColorizer colours exactly these three parts: frame, "fake glow" and core,
// github.com/Aeroluna/Heck/blob/master/Chroma/Colorizer/ObstacleColorizer.cs). Edges are anti-aliased
// with screen-space derivatives (fwidth); the frame never gets thinner than MIN_FRAME_PIXELS and dims
// instead, so it doesn't break up in the distance (as NeonRibbon.gdshader does). All values untuned.
uniform vec4 danger_color : source_color = vec4(1.0, 0.188, 0.188, 1.0);
// how far the glass leans from the danger colour toward white
uniform float core_white = 0.0;
uniform float fill_alpha = 0.3;
// the glowing frame line, in metres
uniform float frame_width = 0.035;
uniform float frame_white = 0.6;
const float MIN_FRAME_PIXELS = 1.5;
// the halo: how far in it fades and how strong it is at the frame
uniform float glow_width = 0.2;
uniform float glow_alpha = 0.6;

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
	float glow = exp(-max(to_edge - frame_width, 0.0) / glow_width) * glow_alpha;

	vec3 col = mix(danger_color.rgb, vec3(1.0), core_white);
	float alpha = fill_alpha;
	col = mix(col, danger_color.rgb, glow);
	alpha = alpha + (1.0 - alpha) * glow;
	col = mix(col, mix(danger_color.rgb, vec3(1.0), frame_white), frame);
	alpha = mix(alpha, 1.0, frame);
	ALBEDO = col;
	ALPHA = alpha;
}
