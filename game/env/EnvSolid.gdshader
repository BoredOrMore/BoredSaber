shader_type spatial;
// Dark solid scenery (tunnel frames, rings, floor lines, buildings), drawn as Beat Saber's: dark matte metal that
// takes on the colour of the lights that are on, so the whole set turns red or blue with the show. In layers:
//   1. base: the dark metal (albedo)
//   2. form: faces shaded by which way they point, as if lit from above (top lighter, bottom darker)
//   3. light spill: the lights' colour (env_light, set by EventDriver) on every face, more on faces turned toward
//      the track, where the lights are
//   4. lit edge (rings only): the hole's edge glows in the lights' colour, like the lit edge of a real ring. It is
//      light, so it goes on after the haze and the haze only dims it
//   5. haze: fades into the air's colour with distance and more so near the floor (Quilez, "Better fog", 2010).
//      Rings take less of it, so they stay dark shapes against the sky instead of turning haze-grey (headset,
//      2026-10-24: at 30 m the full haze left them flat grey and hid their lit edge)
// The scene has no real lights (AGENTS.md "Light", rule 10), so layers 2-4 are faked here. Everything but the edge's
// falloff is worked out per vertex: the faces are flat, so per pixel would give the same picture. Values untuned.
render_mode unshaded, fog_disabled, shadows_disabled;

global uniform vec4 env_haze;
global uniform vec4 env_light;
#include "res://game/env/shadow_tone.gdshaderinc"
#include "res://game/env/height_fog.gdshaderinc"
// DebugView.RINGS leaves these out (no area, so nothing is drawn)
global uniform int debug_view;

// 1. base
uniform vec4 albedo : source_color = vec4(0.094, 0.094, 0.094, 1.0);

// 2. form: brightness of a face pointing straight up, sideways and straight down
const float FORM_TOP = 1.0;
const float FORM_SIDE = 0.7;
const float FORM_BOTTOM = 0.45;

// 3. light spill: how much of the lights' colour a face takes when turned away from the track and toward it.
// Kept low so scenery stays below fixtures and beams in the brightness order (AGENTS.md "Light", rule 1).
const float SPILL_AWAY = 0.04;
const float SPILL_TOWARD = 0.14;
// the track's axis the lights gather around: x 0, this high (metres)
const float TRACK_AXIS_Y = 2.0;

// 4. lit edge: rings only. Half the size of the hole in the ring mesh's own units (game/data/ring.obj: 0.936);
// 0 leaves the edge off.
uniform float ring_hole = 0.0;
// how much of the lights' colour the very edge takes, and how tight the glow hugs it (higher = thinner)
const float EDGE_LIGHT = 0.7;
const float EDGE_TIGHTNESS = 2.0;

// 5. haze: per metre
uniform float fog_density = 0.03;
// how fast the extra floor haze thins out going up, per metre
uniform float floor_haze_falloff = 0.35;
// how much of the height fog the solids take: less than the air, so buildings and frames read as dark shapes
const float SOLID_HEIGHT_FOG = 0.55;
// the part of the haze the rings take
const float RING_FOG = 0.5;

varying float fog;
varying float form;
varying float spill;
// 1 at the ring's hole, 0 at its outside; 0 for anything that isn't a ring
varying float edge;

void vertex() {
	if ((debug_view & 8) != 0) {
		VERTEX = vec3(0.0);
	}
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);

	// 2. form
	form = normal.y > 0.0 ? mix(FORM_SIDE, FORM_TOP, normal.y) : mix(FORM_SIDE, FORM_BOTTOM, -normal.y);

	// 3. light spill: dot of the face's direction with the way to the track (1 facing it, -1 facing away)
	vec2 to_track = vec2(-world.x, TRACK_AXIS_Y - world.y);
	float facing = length(to_track) > 1e-3 ? dot(normal.xy, normalize(to_track)) : 0.0;
	spill = mix(SPILL_AWAY, SPILL_TOWARD, facing * 0.5 + 0.5);

	// 4. lit edge: the ring mesh is flat in its own xz plane; vertices around the hole are marked 1
	edge = ring_hole > 0.0 && max(abs(VERTEX.x), abs(VERTEX.z)) < ring_hole + 0.01 ? 1.0 : 0.0;

	// 5. haze
	float dist = length(world - CAMERA_POSITION_WORLD);
	float distance_fog = 1.0 - exp(-fog_density * dist);
	float floor_haze = exp(-max(world.y, 0.0) * floor_haze_falloff);
	fog = clamp(distance_fog * mix(0.5, 1.0, floor_haze), 0.0, 1.0);
	// height fog lifts the solids' bottoms into the fog, but they stay darker than the air around them (silhouettes)
	fog = max(fog, height_fog(world, CAMERA_POSITION_WORLD) * SOLID_HEIGHT_FOG);
	if (ring_hole > 0.0) {
		fog *= RING_FOG;
	}
}

void fragment() {
	// edge is interpolated linearly across the ring's band; the power pulls the glow in tight against the hole
	float glow = pow(edge, EDGE_TIGHTNESS) * EDGE_LIGHT;
	vec3 lit = albedo.rgb * form + env_light.rgb * spill * form;
	ALBEDO = shadow_tone(mix(lit, env_haze.rgb, fog) + env_light.rgb * glow * (1.0 - fog));
}
