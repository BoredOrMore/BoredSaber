shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

// Night City's billboards on the tower wall (NightCityRig): dark panels with a geometric shape drawn in light, no text
// or brands (owner, 2026-10-25). They carry the square bars' light group: its colour (light_color, black when off) set
// each frame by EventDriver. One MultiMesh of quads, one draw call; the shape is worked out per pixel, no texture.
// Layers:
//   1. panel: a dark face, so the shape reads against it and the panel is a thing on the wall, not a hole
//   2. frame: a thin light line round the panel's edge, the light's visible source (Light rule 5)
//   3. shape: by the instance's custom data x (0 circle, 1 triangle, 2 diagonal stripes, 3 nested frames), its line a
//      white-hot core going to the group's colour at its sides (Light rule 2)
//   4. distance: lines never thinner than MIN_LINE_PIXELS on screen; widened, they dim by the width they gained
// All values untuned; kept under the notes in the brightness order (Light rule 1).
uniform vec4 light_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
global uniform vec4 env_haze;
const vec3 PANEL = vec3(0.012, 0.012, 0.02);
// line half widths in the panel's units (the quad's shorter side is 2), the core's share of white, the light's gain
const float FRAME_LINE = 0.015;
const float SHAPE_LINE = 0.035;
const float MIN_LINE_PIXELS = 1.5;
const float CORE_WHITE = 0.6;
const float GAIN = 0.8;
// the haze over far panels, per metre
const float FOG_DENSITY = 0.002;

varying float shape;
varying vec2 aspect;
varying float fog;

void vertex() {
	shape = INSTANCE_CUSTOM.x;
	vec2 size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	aspect = size / min(size.x, size.y);
	float dist = length((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
	fog = 1.0 - exp(-FOG_DENSITY * dist);
}

// how much of a line `d` from its middle, `half_width` either side, covers this pixel (`px` how much d changes across
// one, taken from a smooth source: fract's wraps would make it jump), and how bright it stays when widened to
// MIN_LINE_PIXELS
vec2 line(float d, float half_width, float px) {
	float w = max(half_width, px * MIN_LINE_PIXELS * 0.5);
	return vec2(1.0 - smoothstep(w - px, w + px, abs(d)), half_width / w);
}

void fragment() {
	// panel units: the shorter side -1..1, the longer one stretched with the quad
	vec2 p = (UV * 2.0 - 1.0) * aspect;
	float edge = min(aspect.x - abs(p.x), aspect.y - abs(p.y));
	vec2 frame = line(edge - FRAME_LINE * 2.0, FRAME_LINE, fwidth(edge));
	float d;
	float px;
	int kind = int(shape + 0.5);
	if (kind == 0) {
		d = length(p) - 0.7;
		px = fwidth(d);
	} else if (kind == 1) {
		// an upright triangle's outline
		vec2 q = vec2(abs(p.x), p.y + 0.25);
		d = max(q.x * 0.866 + q.y * 0.5, -q.y) - 0.45;
		px = fwidth(d);
	} else if (kind == 2) {
		// diagonal stripes, every 0.6 units
		d = (fract((p.x + p.y) / 0.6) - 0.5) * 0.6;
		px = fwidth(p.x + p.y);
	} else {
		// nested frames, 0.35 apart
		float r = max(abs(p.x) / aspect.x * aspect.y, abs(p.y));
		d = (fract(r / 0.35) - 0.5) * 0.35;
		px = fwidth(r);
	}
	vec2 stroke = line(d, SHAPE_LINE, px);
	float lit = max(frame.x * frame.y, stroke.x * stroke.y);
	float core = max(frame.x, stroke.x);
	float peak = max(light_color.r, max(light_color.g, light_color.b));
	vec3 light = mix(light_color.rgb, vec3(peak), CORE_WHITE * core) * lit * GAIN;
	ALBEDO = mix(PANEL + light, env_haze.rgb, fog);
}
