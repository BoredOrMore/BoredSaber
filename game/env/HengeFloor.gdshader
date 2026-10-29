shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled;

// Henge's floor (HengeRig.gd): dark ground, with bands of the horizon's glow from the gaps between the slabs raking
// toward the player and the slabs' shadows between, drawn from the floor mesh's vertex colour (red: how much of a band
// lights it) rather than per pixel (budget note, doc/world/GAME_BIBLE.md). Neutral: the glow takes the haze's colour.
// The drop's flood comes later and must stay below the notes' brightness. BLOCKOUT, untuned.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"

// the ground's own darkness and how bright a band at its brightest is, as shares of the haze's colour
const float GROUND = 0.03;
const float BAND = 0.8;

varying vec3 haze_v;
void vertex() {
	haze_v = fog_lit(env_haze.rgb, (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
}

void fragment() {
	ALBEDO = fog_dither(fog_result(haze_v * (GROUND + BAND * COLOR.r), VERTEX), FRAGCOORD.xy);
}
