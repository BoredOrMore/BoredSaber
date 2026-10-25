shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

// The note track's deck (TrackDeck.gd), drawn opaque, so it costs no overdraw (the old track was one see-through
// sheet 46 m long). It gives the eye surface detail a flat dark sheet didn't (owner, 2026-10-25: the track looked
// flat), while staying darker than everything in the gameplay layer. In layers:
//   1. base: dark metal, toned to navy in the shadows like the scenery (shadow_tone)
//   2. plate seams: a groove across the deck between its plates, PLATE_LENGTH apart. Surface detail only, not tied to
//      the beat (the owner dropped beat lines, 2026-10-25). They never move: the floor and track never move (vection).
//   3. lane grooves: a groove between neighbouring lanes, lane_width apart
//   3b. the stage's skin (skin, set by TrackDeck.set_skin; T3 of the track plan, neutrals only, Light rule 4):
//      0 plain plates (Classic and the stages without their own);
//      1 tread plate (Metal Factory): short raised bars at alternating diagonals, a rivet every RIVET_SPACING along
//        each plate seam, both a little lighter than the plate;
//      2 dark glass (Neon Grid): darker than plate, with a faint sheen of the haze at grazing angles (Fresnel's rise
//        toward the edge of view, as in Schlick's approximation), as a glossy floor would show. Not the floor light's
//        colour: with it a red light turned the far deck pink, too much saturated area (Light rule 3)
//   4. floor light: the map's floor-light group (light_color, set each frame by EventDriver) tints the deck faintly,
//      as the old track did
//   5. haze: fades into the air's colour with distance; it takes DECK_HAZE of it, so the deck stays a dark ground under
//      the notes (at full haze it read as pale as the scenery, desktop capture 2026-10-25)
//   6. the far fade: from fade_z.x to fade_z.y metres out the deck goes fully into the haze, so it runs on and melts
//      away with no end to be seen (owner, 2026-10-25); its edges and strips fade over the same span
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
// 3b. skin: which one, and its knobs. Tread bars: the cell each sits in (metres), its length and width as shares of the
// cell, how much lighter it is. Rivets: spacing along a seam, radius, lightness. Glass: darkness of its base, and how
// strong its sheen is and how sharply it rises toward grazing angles. Patterns finer than a pixel fade out (no shimmer).
uniform int skin = 0;
const float TREAD_CELL = 0.12;
const float TREAD_LENGTH = 0.7;
const float TREAD_WIDTH = 0.18;
const float TREAD_LIGHT = 0.35;
const float RIVET_SPACING = 0.3;
const float RIVET_RADIUS = 0.018;
const float RIVET_LIGHT = 0.6;
const float GLASS_BASE = 0.5;
const float GLASS_SHEEN = 0.35;
const float GLASS_SHARPNESS = 5.0;

// 4. floor light: the group's colour (black when off) and how much of it the deck takes (at 0.12 a red light turned the
// whole deck maroon, too much saturated area: Light rule 3)
uniform vec4 light_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
const float LIGHT_TINT = 0.06;
// 5. haze per metre, and the share of it the deck takes
const float FOG_DENSITY = 0.03;
const float DECK_HAZE = 0.5;
// 6. the far fade's start and end, metres out along the track (-z), set by TrackDeck.gd
uniform vec2 fade_z = vec2(60.0, 140.0);

varying vec3 world;
varying float fog;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fog = (1.0 - exp(-FOG_DENSITY * length(world - CAMERA_POSITION_WORLD))) * DECK_HAZE;
	fog = max(fog, smoothstep(fade_z.x, fade_z.y, -world.z));
}

// 1 on a line every `spacing` metres through `origin` along `x`, `half_width` wide, antialiased; 0 elsewhere.
float lines(float x, float origin, float spacing, float half_width) {
	float d = abs(fract((x - origin) / spacing + 0.5) - 0.5) * spacing;
	float aa = fwidth(x);
	return 1.0 - smoothstep(half_width - aa, half_width + aa, d);
}

// Tread plate: 1 on a raised bar, 0 between; each cell's bar leans the other way from its neighbours'. Fades out where a
// cell is smaller than a few pixels.
float tread(vec2 p) {
	vec2 cell = floor(p / TREAD_CELL);
	vec2 local = fract(p / TREAD_CELL) - 0.5;
	float lean = mod(cell.x + cell.y, 2.0) < 1.0 ? 1.0 : -1.0;
	vec2 along = normalize(vec2(1.0, lean));
	vec2 q = vec2(dot(local, along), dot(local, vec2(-along.y, along.x)));
	float bar = step(abs(q.x), TREAD_LENGTH * 0.5) * step(abs(q.y), TREAD_WIDTH * 0.5);
	float pixels = TREAD_CELL / max(fwidth(p.x) + fwidth(p.y), 1e-5);
	return bar * smoothstep(3.0, 8.0, pixels);
}

// Rivets: 1 on a rivet head along the plate seams, every RIVET_SPACING across the deck.
float rivets(vec2 p) {
	float along = (fract(p.x / RIVET_SPACING + 0.5) - 0.5) * RIVET_SPACING;
	float across = (fract(p.y / PLATE_LENGTH + 0.5) - 0.5) * PLATE_LENGTH;
	float d = length(vec2(along, across));
	float aa = fwidth(d);
	return 1.0 - smoothstep(RIVET_RADIUS - aa, RIVET_RADIUS + aa, d);
}

void fragment() {
	// 2, 3 and the skin's pattern only on the deck's top (its sides are plain)
	float top = step(-0.01, world.y);
	float seam = lines(world.z, 0.0, PLATE_LENGTH, SEAM_HALF_WIDTH) * top;
	float groove = lines(world.x, 0.0, lane_width, GROOVE_HALF_WIDTH) * top;
	vec3 base = albedo.rgb;
	vec3 sheen = vec3(0.0);
	if (skin == 1) {
		base *= 1.0 + top * (TREAD_LIGHT * tread(world.xz) + RIVET_LIGHT * rivets(world.xz));
	} else if (skin == 2) {
		base *= GLASS_BASE;
		float grazing = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), GLASS_SHARPNESS);
		sheen = env_haze.rgb * GLASS_SHEEN * grazing * top;
	}
	vec3 lit = base * (1.0 - SEAM_DARK * seam) * (1.0 - GROOVE_DARK * groove);
	lit += light_color.rgb * LIGHT_TINT + sheen;
	ALBEDO = shadow_tone(mix(lit, env_haze.rgb, fog));
}
