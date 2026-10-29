shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

// Henge's strips up the slabs' inner edges (HengeRig.gd): each takes the map's left lasers' colour when its slab stands
// left of where the track points now, the right lasers' when right (owner, 2026-10-29), so left stays left of where the
// notes come from as the track turns. Off (black) stays black. A white-hot core where it faces the eye, as LightStrip.
// BLOCKOUT, untuned.
#include "res://game/env/track_turn.gdshaderinc"
uniform vec4 left_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 right_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
const float CORE_WHITE = 0.6;
const float CORE_SHARPNESS = 2.0;

varying vec3 color;

void vertex() {
	// the strip's middle, in the unturned track's space: left of the track's line or right of it
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	color = track_xz(centre).x < 0.0 ? left_color.rgb : right_color.rgb;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float peak = max(color.r, max(color.g, color.b));
	ALBEDO = mix(color, vec3(peak), CORE_WHITE * pow(facing, CORE_SHARPNESS));
}
