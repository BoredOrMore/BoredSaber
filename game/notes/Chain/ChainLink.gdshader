shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
// Notes keep their own colour whatever the stage's lights do, as Beat Saber's notes do (their shaders carry their own
// fixed light, BSMG notes guide): no haze or light colour in the reflections, and no fog (owner, 2026-10-26: notes
// tinted by the stage and its haze were harder to read).

// The same glossy look as BeepCube.gdshader (note_gloss.gdshaderinc), since the scene has no lights; see there.
// The link has no bevelled edges, so it has no highlight streak.
#include "res://game/notes/BeepCube/note_gloss.gdshaderinc"
// Darker Notes: the body colour's HSV value is capped here, so hue and saturation stay (1.0 = off)
global uniform float note_max_value;
const float cut_white_margin = 0.04;

uniform vec4 color : source_color;
uniform bool cutted = false;
uniform float cut_dist_from_center = 0.0;
uniform float cut_angle = 0.0;
uniform float cut_vanish = 0.0;

// [firepal]TODO: Build matrix on CPU (I tried but couldn't')
mat3 rotation3dZ(float angle) {
	float s = sin(angle);
	float c = cos(angle);

	return mat3(
		vec3(c, s, 0.0),
		vec3(-s, c, 0.0),
		vec3(0.0, 0.0, 1.0)
	);
}

varying float cut_interp;
void vertex() {
	if (cutted) {
		float cut_line = cut_dist_from_center+(VERTEX*rotation3dZ(cut_angle)).x;
		cut_interp = cut_line - cut_vanish;
	} else {
		// not cut, ensure no discard later
		cut_interp = 1.0;
	}
}

void fragment() {
	// Discard all pixels "in the cut"
	if (cut_interp < 0.0) {
		discard;
	}

	if (FRONT_FACING) {
		vec3 body = color.rgb * min(1.0, note_max_value / max(max(color.r, color.g), max(color.b, 1e-4)));
		float x_centered = UV.x - 0.25;
		float y_centered = UV.y - 0.25;
		float dist_from_center_squared = x_centered * x_centered + y_centered * y_centered;
		if (dist_from_center_squared <= 0.001) {
			ALBEDO = vec3(1.0);
		} else {
			vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
			vec3 base = note_gloss(body, world_normal, normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz), 0.0);
			if (cutted){
				// soft white margin
				base += vec3(smoothstep(cut_white_margin+0.01,cut_white_margin,cut_interp));
				// hard white margin
				//base += vec3( float(cut_white_margin < cut_interp) );
			}
			ALBEDO = base;
		}
	} else {
		ALBEDO = vec3(1.0);
	}
}
