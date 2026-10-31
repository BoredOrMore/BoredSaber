shader_type spatial;
render_mode unshaded, cull_back, blend_mix;

// The wall. The older wall's (DangerWall.gdshader, removed 2026-10-31) two
// blended faces, wide halo and dense frame filled the screen with red fog when a wall came near (owner, 2026-10-25).
// One mesh (Wall.frame_mesh: a unit box and twelve bars on its edges, scaled to the wall), one material, so still one
// draw call per wall. Layers:
//   1. frame: thin bars on all twelve edges, opaque, a white-hot core going to the danger colour at their sides. Their
//      width is kept in metres here (the mesh is scaled to the wall), never under MIN_FRAME_PIXELS on screen, and dimmed
//      when widened, so far walls don't break up (as the classic wall's frame)
//   2. glass: front faces only, so one layer. Dark danger colour, faint where it faces the player and denser toward
//      grazing angles (Schlick's Fresnel), so notes behind it read and it still looks like a dark slab
//   3. halo: a narrow, faint glow in the danger colour along the glass's edges (Light rule 2: small bright areas)
//   4. near fade: the glass and halo fade out within NEAR_FADE metres of the eye, so a wall at the head never fills
//      the view; the frame stays, so the player still sees where the wall is
// All values untuned until a headset playtest.
uniform vec4 danger_color : source_color = vec4(1.0, 0.188, 0.188, 1.0);
// 1. frame: half its width (metres), the core's share of white and how far across the bar it reaches
const float FRAME_HALF = 0.0125;
const float MIN_FRAME_PIXELS = 1.5;
const float FRAME_WHITE = 0.9;
const float FRAME_CORE = 0.6;
// 2. glass: its brightness (part of the danger colour) and alpha facing the player and edge-on
const float GLASS_BRIGHTNESS = 0.1;
const float GLASS_ALPHA_FACING = 0.18;
const float GLASS_ALPHA_GRAZING = 0.6;
// 3. halo: how far in it fades (metres) and its alpha at the frame
const float HALO_WIDTH = 0.09;
const float HALO_ALPHA = 0.35;
// 4. near fade: none closer than x metres, all from y
const vec2 NEAR_FADE = vec2(0.3, 1.0);

// DebugView.WALLS leaves walls out (no area, so nothing is drawn)
global uniform int debug_view;

// the box's corner this vertex sits at, in metres from the centre, and the wall's half size
varying vec3 pos;
varying vec3 half_size;
// on the bars: the vertex's offset from its edge (-1 to 1 in the bar's two cross directions, 0 along it); 0 on the glass
varying vec3 bar;
// the frame's brightness after widening to MIN_FRAME_PIXELS
varying float frame_dim;

void vertex() {
	if ((debug_view & 1) != 0) {
		VERTEX = vec3(0.0);
	}
	vec3 size = max(vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz)), vec3(1e-4));
	half_size = size * 0.5;
	// the mesh keeps the bar offset in its UVs (Wall.frame_mesh)
	bar = vec3(UV, UV2.x);
	pos = VERTEX * size;
	// how wide a pixel is at this corner, metres
	float depth = -(VIEW_MATRIX * MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
	float pixel = max(depth, 0.0) * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float half_width = max(FRAME_HALF, pixel * MIN_FRAME_PIXELS * 0.5);
	frame_dim = FRAME_HALF / half_width;
	VERTEX += bar * half_width / size;
}

// the middle one of the three values
float middle(vec3 v) {
	return v.x + v.y + v.z - max(v.x, max(v.y, v.z)) - min(v.x, min(v.y, v.z));
}

void fragment() {
	if (dot(bar, bar) > 0.0) {
		// 1. a bar: across it, 0 on the edge's line to 1 at its sides
		float across = middle(abs(bar));
		float core = 1.0 - smoothstep(FRAME_CORE * 0.5, FRAME_CORE, across);
		ALBEDO = mix(danger_color.rgb, vec3(1.0), FRAME_WHITE * core) * frame_dim;
		ALPHA = 1.0;
	} else {
		// 2. glass, 3. halo: distance to the nearest edge of this face, as the classic wall
		vec3 d = half_size - abs(pos);
		float to_edge = middle(d);
		float halo = exp(-max(to_edge - FRAME_HALF, 0.0) / HALO_WIDTH) * HALO_ALPHA;
		float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float fresnel = pow(1.0 - facing, 5.0);
		float alpha = mix(GLASS_ALPHA_FACING, GLASS_ALPHA_GRAZING, fresnel);
		vec3 col = mix(danger_color.rgb * GLASS_BRIGHTNESS, danger_color.rgb, halo);
		alpha = alpha + (1.0 - alpha) * halo;
		// 4. near fade
		alpha *= smoothstep(NEAR_FADE.x, NEAR_FADE.y, length(VERTEX));
		if (alpha < 0.01) {
			discard;
		}
		ALBEDO = col;
		ALPHA = alpha;
	}
}
