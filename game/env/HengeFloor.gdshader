shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled;

// Henge's floor (HengeRig.gd): dark ground, with bands of the horizon's glow from the gaps between the slabs raking
// toward the player and the slabs' shadows between, drawn from the floor mesh's vertex colour (red: how much of a band
// lights it) rather than per pixel (budget note, doc/world/GAME_BIBLE.md). Neutral: the glow takes the haze's colour.
// On the drop every gap floods (flood, 0..1, eased by EventDriver._update_henge): the bands brighten by FLOOD_GAIN and
// take FLOOD_LEVEL of neutral grey light on top (the haze alone is too dark to read as a flood; desktop capture,
// 2026-10-29), never past FLOOR_MAX so the floor stays below the notes' brightness (AGENTS.md "Light", rule 1). BLOCKOUT, untuned.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"

// the ground's own darkness and how bright a band at its brightest is, as shares of the haze's colour
const float GROUND = 0.03;
const float BAND = 0.8;
const float FLOOD_GAIN = 2.0;
const float FLOOD_LEVEL = 0.12;
const float FLOOR_MAX = 0.35;
uniform float flood = 0.0;

varying vec3 haze_v;
void vertex() {
	haze_v = fog_lit(env_haze.rgb, (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
}

void fragment() {
	vec3 floor_light = haze_v * (GROUND + BAND * COLOR.r * (1.0 + FLOOD_GAIN * flood)) + vec3(FLOOD_LEVEL * COLOR.r * flood);
	floor_light = min(floor_light, vec3(FLOOR_MAX));
	ALBEDO = fog_dither(fog_result(floor_light, VERTEX), FRAGCOORD.xy);
}
