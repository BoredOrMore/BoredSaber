shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

// The note track's deck (TrackDeck.gd), drawn opaque, so it costs no overdraw (the old track was one see-through
// sheet 46 m long). It gives the eye surface detail a flat dark sheet didn't (owner, 2026-10-25: the track looked
// flat), while staying darker than everything in the gameplay layer. In layers:
//   1. base: dark metal, toned to navy in the shadows like the scenery (shadow_tone)
//   2. plate seams: a groove across the deck between its plates, PLATE_LENGTH apart. Surface detail only, not tied to
//      the beat (the owner dropped beat lines, 2026-10-25). They never move: the floor and track never move (vection).
//   3. lane grooves: a groove between neighbouring lanes, lane_width apart
//   4. floor light: the map's floor-light group (light_color, set each frame by EventDriver) tints the deck faintly,
//      as the old track did
//   5. haze: fades into the air's colour with distance, so the far end melts into the haze instead of ending in an
//      edge; it takes DECK_HAZE of it, so the deck stays a dark ground under the notes (at full haze it read as pale as
//      the scenery, desktop capture 2026-10-25)
// Grooves are thin and far away, so their width is antialiased with screen-space derivatives and they fade out with
// the haze before they shimmer. Untuned.
global uniform vec4 env_haze;
#include "res://game/env/shadow_tone.gdshaderinc"

// 1. base
uniform vec4 albedo : source_color = vec4(0.06, 0.06, 0.07, 1.0);
// 2. plate seams: metres between them, their half width in metres and how dark (0 none, 1 black)
const float PLATE_LENGTH = 2.5;
const float SEAM_HALF_WIDTH = 0.015;
const float SEAM_DARK = 0.6;
// 3. lane grooves: the lanes' spacing (Settings.LANE_DISTANCE_X, wider with the Wide modifiers), half width, darkness
uniform float lane_width = 0.6;
const float GROOVE_HALF_WIDTH = 0.012;
const float GROOVE_DARK = 0.5;
// 4. floor light: the group's colour (black when off) and how much of it the deck takes (at 0.12 a red light turned the
// whole deck maroon, too much saturated area: Light rule 3)
uniform vec4 light_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
const float LIGHT_TINT = 0.06;
// 5. haze per metre, and the share of it the deck takes
const float FOG_DENSITY = 0.03;
const float DECK_HAZE = 0.5;

varying vec3 world;
varying float fog;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fog = (1.0 - exp(-FOG_DENSITY * length(world - CAMERA_POSITION_WORLD))) * DECK_HAZE;
}

// 1 on a line every `spacing` metres through `origin` along `x`, `half_width` wide, antialiased; 0 elsewhere.
float lines(float x, float origin, float spacing, float half_width) {
	float d = abs(fract((x - origin) / spacing + 0.5) - 0.5) * spacing;
	float aa = fwidth(x);
	return 1.0 - smoothstep(half_width - aa, half_width + aa, d);
}

void fragment() {
	// 2 and 3 only on the deck's top (its sides are plain)
	float top = step(-0.01, world.y);
	float seam = lines(world.z, 0.0, PLATE_LENGTH, SEAM_HALF_WIDTH) * top;
	float groove = lines(world.x, 0.0, lane_width, GROOVE_HALF_WIDTH) * top;
	vec3 lit = albedo.rgb * (1.0 - SEAM_DARK * seam) * (1.0 - GROOVE_DARK * groove);
	lit += light_color.rgb * LIGHT_TINT;
	ALBEDO = shadow_tone(mix(lit, env_haze.rgb, fog));
}
