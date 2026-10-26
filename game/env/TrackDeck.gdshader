shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

// The note track's deck (TrackDeck.gd), drawn opaque, so it costs no overdraw (the old track was one see-through
// sheet 46 m long). It gives the eye surface detail a flat dark sheet didn't (owner, 2026-10-25: the track looked
// flat), while staying darker than everything in the gameplay layer. In layers:
//   1. base: dark metal
//   2. nothing runs across the deck: any line across the track reads as a beat line (the owner had them out, plate seams
//      included, 2026-10-25)
//   3. lane grooves: a groove between neighbouring lanes, lane_width apart, along the track; they never move (the floor
//      and track never move: vection)
//   3b. the stage's skin (skin, set by TrackDeck.set_skin; T3 of the track plan, neutrals only, Light rule 4):
//      0 plain plates (Classic and the stages without their own);
//      1 tread plate (Metal Factory): short raised bars at alternating diagonals, a rivet every RIVET_SPACING along
//        each lane groove, both a little lighter than the plate, fading out gradually with distance (TREAD_FADE: a
//        fade by pixel size switched over a short stretch at grazing angles and read as an edge, owner 2026-10-25);
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
#include "res://game/env/fog_light.gdshaderinc"

// 1. base: near-black, the lane grooves just visible in it (owner, 2026-10-25: the deck read too bright; it was 0.06)
uniform vec4 albedo : source_color = vec4(0.035, 0.035, 0.04, 1.0);
// 3. lane grooves: the lanes' spacing (Settings.LANE_DISTANCE_X, wider with the Wide modifiers), half width, darkness
uniform float lane_width = 0.6;
const float GROOVE_HALF_WIDTH = 0.012;
const float GROOVE_DARK = 0.5;
// 3b. skin: which one, and its knobs. Tread bars: the cell each sits in (metres), its length and width as shares of the
// cell, how much lighter it is. Rivets: spacing along a seam, radius, lightness. Glass: darkness of its base, and how
// strong its sheen is and how sharply it rises toward grazing angles. The tread and rivets fade out between TREAD_FADE.x
// and .y metres from the eye, before they would shimmer.
uniform int skin = 0;
const float TREAD_CELL = 0.12;
const float TREAD_LENGTH = 0.7;
const float TREAD_WIDTH = 0.18;
const float TREAD_LIGHT = 0.35;
const float RIVET_SPACING = 0.3;
const float RIVET_RADIUS = 0.018;
const float RIVET_LIGHT = 0.6;
const vec2 TREAD_FADE = vec2(6.0, 20.0);
const float GLASS_BASE = 0.5;
const float GLASS_SHEEN = 0.35;
const float GLASS_SHARPNESS = 5.0;

// 4. floor light: the group's colour (black when off) and how much of it the deck takes (at 0.12 a red light turned the
// whole deck maroon, and at 0.06 a blue one still read as saturated blue over the whole deck: Light rule 3)
uniform vec4 light_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
const float LIGHT_TINT = 0.025;
// 5. haze per metre, and the share of it the deck takes
const float FOG_DENSITY = 0.03;
const float DECK_HAZE = 0.3;
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

// Tread plate: 1 on a raised bar, 0 between; each cell's bar leans the other way from its neighbours'.
float tread(vec2 p) {
	vec2 cell = floor(p / TREAD_CELL);
	vec2 local = fract(p / TREAD_CELL) - 0.5;
	float lean = mod(cell.x + cell.y, 2.0) < 1.0 ? 1.0 : -1.0;
	vec2 along = normalize(vec2(1.0, lean));
	vec2 q = vec2(dot(local, along), dot(local, vec2(-along.y, along.x)));
	return step(abs(q.x), TREAD_LENGTH * 0.5) * step(abs(q.y), TREAD_WIDTH * 0.5);
}

// Rivets: 1 on a rivet head along the lane grooves, every RIVET_SPACING along the track.
float rivets(vec2 p) {
	float across = (fract(p.x / lane_width + 0.5) - 0.5) * lane_width;
	float along = (fract(p.y / RIVET_SPACING + 0.5) - 0.5) * RIVET_SPACING;
	float d = length(vec2(across, along));
	float aa = fwidth(d);
	return 1.0 - smoothstep(RIVET_RADIUS - aa, RIVET_RADIUS + aa, d);
}

void fragment() {
	// the haze lit from the stage's key light, seen this way (fog_light.gdshaderinc)
	vec3 haze = fog_lit(env_haze.rgb, (INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
	// 3 and the skin's pattern only on the deck's top (its sides are plain)
	float top = step(-0.01, world.y);
	float groove = lines(world.x, 0.0, lane_width, GROOVE_HALF_WIDTH) * top;
	vec3 base = albedo.rgb;
	vec3 sheen = vec3(0.0);
	if (skin == 1) {
		float near = 1.0 - smoothstep(TREAD_FADE.x, TREAD_FADE.y, length(world - CAMERA_POSITION_WORLD));
		base *= 1.0 + top * near * (TREAD_LIGHT * tread(world.xz) + RIVET_LIGHT * rivets(world.xz));
	} else if (skin == 2) {
		base *= GLASS_BASE;
		float grazing = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), GLASS_SHARPNESS);
		sheen = haze * GLASS_SHEEN * grazing * top;
	}
	vec3 lit = base * (1.0 - GROOVE_DARK * groove);
	lit += light_color.rgb * LIGHT_TINT + sheen;
	ALBEDO = fog_dither(mix(lit, haze, fog), FRAGCOORD.xy);
}
