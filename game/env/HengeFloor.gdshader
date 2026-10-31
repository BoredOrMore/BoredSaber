shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled;

// Henge's floor (HengeRig.gd): dark ground, with bands of the horizon's glow from the gaps between the slabs raking
// toward the player and the slabs' shadows between, drawn from the floor mesh's vertex colour (red: how much of a band
// lights it) rather than per pixel (budget note, doc/world/GAME_BIBLE.md). Neutral: the glow takes the haze's colour.
// On the drop every gap floods (flood, 0..1, eased by EventDriver._update_henge): the bands brighten by FLOOD_GAIN and
// take FLOOD_LEVEL of neutral grey light on top (the haze alone is too dark to read as a flood; desktop capture,
// 2026-10-29), never past FLOOR_MAX so the floor stays below the notes' brightness (AGENTS.md "Light", rule 1).
// The slabs' edge strips light the ground at their feet (owner, 2026-10-31): a pool in the strip's colour, brightest at
// the ring and fading over STRIP_REACH toward the player (STRIP_BEHIND beyond the slabs), taking the same left/right
// split and the same build-up as the strips (HengeStrip.gdshader), at most STRIP_LIGHT. Worked out per pixel: the
// floor's rings are 33 m apart, too coarse for the pool. BLOCKOUT, untuned.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"
#include "res://game/env/track_turn.gdshaderinc"

// the ground's own darkness and how bright a band at its brightest is, as shares of the haze's colour
const float GROUND = 0.03;
const float BAND = 0.8;
const float FLOOD_GAIN = 2.0;
const float FLOOD_LEVEL = 0.12;
const float FLOOR_MAX = 0.35;
uniform float flood = 0.0;
// the strips' light: their colours and build-up (EventDriver, as the strips'), the slabs' ring (HengeRig.RING_RADIUS)
// and slabs round it (HengeRig.SLAB_COUNT), and the pool's brightness and reach (metres) toward the player and beyond
uniform vec4 left_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 right_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float lit = 1.0;
const float RING_RADIUS = 150.0;
const float SLABS = 24.0;
const float STRIP_LIGHT = 0.2;
const float STRIP_REACH = 25.0;
const float STRIP_BEHIND = 6.0;

varying vec3 haze_v;
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	haze_v = fog_lit(env_haze.rgb, world - CAMERA_POSITION_WORLD);
}

// the slabs' edge strips' light on the ground here
vec3 strip_light() {
	vec2 from_player = vec2(world.x, world.z - TRACK_PIVOT_Z);
	float in_from_ring = RING_RADIUS - length(from_player);
	float pool = in_from_ring > 0.0 ? exp(-in_from_ring / STRIP_REACH) : exp(in_from_ring / STRIP_BEHIND);
	vec3 color = track_xz(world).x < 0.0 ? left_color.rgb : right_color.rgb;
	float around = fract(atan(world.x, TRACK_PIVOT_Z - world.z) / 6.28318530718 + 1.0);
	return color * (clamp((lit - around) * SLABS, 0.0, 1.0) * pool * STRIP_LIGHT);
}

void fragment() {
	vec3 floor_light = haze_v * (GROUND + BAND * COLOR.r * (1.0 + FLOOD_GAIN * flood)) + vec3(FLOOD_LEVEL * COLOR.r * flood);
	floor_light = min(floor_light + strip_light(), vec3(FLOOR_MAX));
	ALBEDO = fog_dither(fog_result(floor_light, VERTEX), FRAGCOORD.xy);
}
