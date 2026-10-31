shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
// Notes keep their own colour whatever the stage's lights do, as Beat Saber's notes do (their shaders carry their own
// fixed light, BSMG notes guide): no haze or light colour in the reflections, and no fog (owner, 2026-10-26: notes
// tinted by the stage and its haze were harder to read).

// The look is glossy plastic as in Beat Saber: note_gloss.gdshaderinc, with the arrow and dot below (the older Solid
// and Neon looks were removed, owner 2026-10-31). The scene has no lights, so the gloss fakes its own.
// Darker Notes: the body colour's HSV value is capped here, so hue and saturation stay (1.0 = off)
global uniform float note_max_value;
// DebugView.PLAIN_NOTES draws notes in their flat colour
global uniform int debug_view;
// a blurred copy of the arrow drawn under it as a faint halo, using a smaller mipmap of the same texture
const float ARROW_HALO_BLUR = 3.0;

#include "res://game/notes/BeepCube/note_gloss.gdshaderinc"
// the glossy look's arrow and dot: how far the core goes toward white, its brightness, the halo's, and the dot's disc
// (the texture's dot is a ring; Beat Saber's is solid) in the dot's UVs: its centre and radius, and its soft edge
const float MARK_WHITE = 0.75;
const float MARK_GAIN = 1.4;
const float MARK_HALO = 0.6;
const vec2 DOT_CENTRE = vec2(0.75, 0.25);
// the round mesh's bevels (tools/models/note_round.py: flat to 0.1625, rounded out to 0.25)
const float ROUND_BEVEL_START = 0.16;
const float ROUND_BEVEL_FULL = 0.21;
const float DOT_RADIUS = 0.065;
const float DOT_EDGE = 0.01;

// the middle one of the three values
float middle(vec3 v) {
	return v.x + v.y + v.z - max(v.x, max(v.y, v.z)) - min(v.x, min(v.y, v.z));
}

uniform vec4 color : source_color;
uniform sampler2D texture_emission : hint_default_black;

uniform float metallic;
uniform float roughness;
uniform float sub_emission_energy;

uniform bool cutted = false;
uniform float cut_vanish = 0.0;
uniform float cut_white_margin = 0.04;
// A cut half's cut edge glows white-hot and cools to the note's colour as the half flies off (1 to 0, CutPiece);
// the inside seen through the cut is dark, as in Beat Saber, glowing only at the cut.
uniform float cut_glow = 1.0;
const float CUT_EDGE_GAIN = 1.5;
const float CUT_INSIDE_DARK = 0.12;

uniform bool is_dot = false;
uniform bool arrows_enabled = true;
uniform bool is_chain_head = false;

uniform vec3 cut_plane_normal = vec3(0,0,0);
uniform float cut_plane_dist = 0;

varying float cut_interp;
varying float chain_interp;
varying vec3 local_pos;
void vertex() {
	local_pos = VERTEX;
	if (is_chain_head) {
		chain_interp = 0.1 + VERTEX.y;
	}
	if (cutted) {
		cut_interp = dot(VERTEX, cut_plane_normal) - cut_plane_dist - cut_vanish;
	}
}

void fragment() {
	// Discard all pixels "in the cut"
	if (
		(cutted && cut_interp < 0.0)
		|| (is_chain_head && chain_interp < 0.0)
	) {
		discard;
	}

	if ((debug_view & 2) != 0) {
		ALBEDO = color.rgb;
	} else if (FRONT_FACING) {
		vec3 body = color.rgb * min(1.0, note_max_value / max(max(color.r, color.g), max(color.b, 1e-4)));
		vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		float bevel = smoothstep(ROUND_BEVEL_START, ROUND_BEVEL_FULL, middle(abs(local_pos)));
		vec3 base = note_gloss(body, world_normal, view_world, bevel);
		if (is_dot || arrows_enabled) {
			vec2 dot_uv = vec2(UV.x+0.5, UV.y);
			vec2 mark_uv = is_dot ? dot_uv : UV;
			float mark = is_dot ? smoothstep(DOT_RADIUS + DOT_EDGE, DOT_RADIUS, distance(dot_uv, DOT_CENTRE))
				: texture(texture_emission, mark_uv).r;
			float halo = texture(texture_emission, mark_uv, ARROW_HALO_BLUR).r;
			base += body * halo * MARK_HALO;
			base = mix(base, mix(body, vec3(1.0), MARK_WHITE) * MARK_GAIN, mark);
		}

		if (is_chain_head) {
			base += vec3( smoothstep(cut_white_margin+0.01,cut_white_margin,chain_interp) );
		}

		if (cutted){
			// soft glowing margin along the cut
			base += mix(color.rgb, vec3(1.0), cut_glow) * (CUT_EDGE_GAIN * (0.5 + cut_glow))
				* smoothstep(cut_white_margin + 0.01, cut_white_margin, cut_interp);
			// hard white margin
			//base += vec3( float(cut_white_margin < cut_interp) );
		}
		ALBEDO = base;
	} else if (cutted) {
		// the inside, seen through the cut: dark, lit along the cut's edge
		float edge = smoothstep(cut_white_margin * 2.0, 0.0, cut_interp);
		ALBEDO = color.rgb * CUT_INSIDE_DARK + mix(color.rgb, vec3(1.0), cut_glow) * edge * (0.5 + cut_glow);
	} else {
		ALBEDO = vec3(1.0);
	}
}
