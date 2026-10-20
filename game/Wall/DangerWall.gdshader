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
// the glass is the danger colour dimmed to near black-red, so the wall reads as a dark, threatening slab
// (as in Beat Saber) while the frame carries the colour
uniform float body_brightness = 0.15;
uniform float fill_alpha = 0.5;
// the glowing frame line, in metres
uniform float frame_width = 0.05;
// the frame burns white-hot in the middle, its red halo (glow) around it
uniform float frame_white = 0.95;
const float MIN_FRAME_PIXELS = 1.5;
// Fake heat distortion, computed on the wall itself (a real one would read back the screen, a full copy per eye
// per frame that the Pico's tile renderer can't afford): slow bands drifting through the glass, and the frame
// line wavering a few millimetres like an electric arc, as on Beat Saber's walls. Slow and small for comfort.
uniform float shimmer = 0.6;
uniform float shimmer_scale = 3.0;
uniform float shimmer_speed = 0.6;
uniform float arc_amplitude = 0.012;
uniform float arc_scale = 9.0;
uniform float arc_speed = 2.5;
// the halo: how far in it fades and how strong it is at the frame
uniform float glow_width = 0.25;
uniform float glow_alpha = 0.9;
// the halo burns toward white next to the frame (this part of white at the frame), red further out
uniform float glow_white = 0.35;

// DebugView.WALLS leaves walls out (no area, so nothing is drawn); DebugView.PLAIN_WALLS turns the shimmer off
global uniform int debug_view;

varying vec3 pos;
varying vec3 half_size;

void vertex() {
	if ((debug_view & 1) != 0) {
		VERTEX = vec3(0.0);
	}
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
	bool fx = (debug_view & 64) == 0;
	// position along the faces, for the moving patterns (same on every face of a box edge)
	float along = pos.x + pos.y + pos.z;
	if (fx) {
		to_edge += arc_amplitude * sin(along * arc_scale + TIME * arc_speed) * sin(along * arc_scale * 2.3 - TIME * arc_speed * 1.7);
	}
	float px = fwidth(to_edge);
	float frame_w = max(frame_width, px * MIN_FRAME_PIXELS);
	float frame = (1.0 - smoothstep(frame_w - px, frame_w + px, to_edge)) * (frame_width / frame_w);
	float glow = exp(-max(to_edge - frame_width, 0.0) / glow_width) * glow_alpha;

	float bands = fx ? 1.0 + shimmer * sin((pos.x - pos.y) * shimmer_scale + TIME * shimmer_speed) * sin((pos.y + pos.z) * shimmer_scale * 1.3 - TIME * shimmer_speed * 0.7) : 1.0;
	vec3 col = mix(danger_color.rgb * body_brightness * bands, vec3(1.0), core_white);
	float alpha = fill_alpha;
	col = mix(col, mix(danger_color.rgb, vec3(1.0), glow_white * glow), glow);
	alpha = alpha + (1.0 - alpha) * glow;
	col = mix(col, mix(danger_color.rgb, vec3(1.0), frame_white), frame);
	alpha = mix(alpha, 1.0, frame);
	ALBEDO = col;
	ALPHA = alpha;
}
