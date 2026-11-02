shader_type spatial;
render_mode unshaded, shadows_disabled, blend_mix, depth_draw_never, cull_disabled;

// The rim round a portal cut in a real wall in room-aware mixed reality (owner, 2026-11-02: the thin strip, picked from
// three blockouts): drawn on one unit quad per portal (QuadMesh 1 x 1, centred on the portal, facing into the room,
// +y up) that this shader stretches to the portal's size plus RIM_REACH all round, so one material fits every room.
// The hole stays clear (the world behind shows through); the rim is a light strip flush on the wall's cut edge
// (AGENTS.md "Light", rule 5b): white-hot at the edge, its colour (light_color, the lights' colour from the map) in a
// glow that fades out over the wall (rule 2). Untuned.

// the portal's width and height in metres (the room code sets it)
uniform vec2 portal_size_m = vec2(1.6, 1.4);
uniform vec4 light_color : source_color = vec4(1.0);

// how far past the hole's edge the quad reaches (m): the glow is gone by then
const float RIM_REACH = 0.3;
// the strip's half width and its glow's falloff on the wall (m), how white its core burns, the glow's peak alpha
const float STRIP_HALF = 0.012;
const float STRIP_FALL = 0.05;
const float CORE_WHITE = 0.85;
const float GLOW_ALPHA = 0.6;

varying vec2 local;

void vertex() {
	VERTEX.xy *= portal_size_m + vec2(RIM_REACH * 2.0);
	local = VERTEX.xy;
}

// Signed distance (m) from p to the hole's edge: negative inside the hole.
float hole_distance(vec2 p) {
	vec2 q = abs(p) - portal_size_m * 0.5;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

void fragment() {
	float d = hole_distance(local);
	float core = 1.0 - smoothstep(STRIP_HALF * 0.5, STRIP_HALF, abs(d));
	float glow = d > 0.0 ? exp(-d / STRIP_FALL) : 0.0;
	ALBEDO = mix(light_color.rgb * glow, vec3(1.0), core * CORE_WHITE);
	ALPHA = max(core, glow * GLOW_ALPHA);
}
