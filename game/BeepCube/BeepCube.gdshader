shader_type spatial;
render_mode unshaded, cull_disabled;

// The scene has no lights, so real lighting only gave every face the same
// ambient brightness and the cubes looked flat. Instead this fakes a light from
// above and in front: faces turned toward it are brighter, faces turned away
// darker, and a soft rim brightens the silhouette.
const vec3 LIGHT_DIR = vec3(-0.3, 0.8, 0.5);
// brightness of a face turned fully away from the light
const float SHADE_FLOOR = 0.45;
const float RIM_STRENGTH = 0.35;
// The player picks one of two looks in the settings (note_style): 0 "Solid" is only the fake light and rim above;
// 1 "Neon" is self-lit coloured plastic, as in Beat Saber: its note shaders are "Lit Glow" kinds, a full-colour body that
// glows on its own (BSMG Custom Notes Guide, bsmg.wiki/models/notes-guide.html). On top: bright bevels, a faint
// soft reflection of a made-up studio (a band near the horizon and a soft light overhead) and a broad soft
// highlight (Blinn 1977). Reflections were strong before and the cubes read as tin cans. No reflection probe or
// texture: a few math operations per pixel. All values untuned.
// the flat faces end and the rounded bevels begin this far from the centre (the mesh is 0.5 wide)
global uniform int note_style;
// Darker Notes: the body colour's HSV value is capped here, so hue and saturation stay (1.0 = off)
global uniform float note_max_value;
// DebugView.PLAIN_NOTES draws notes in their flat colour
global uniform int debug_view;
// Neon glows this much more on its own than Solid
const float NEON_GLOW = 0.12;
const float BEVEL_START = 0.19;
const float BEVEL_FULL = 0.225;
const float BEVEL_STRENGTH = 0.55;
// how far the bevel highlight leans from the note colour toward white
const float BEVEL_WHITE = 0.35;
const float REFLECT = 0.12;
const float REFLECT_WHITE = 0.2;
const float SPEC_POWER = 16.0;
const float SPEC_STRENGTH = 0.08;
// the scene's lit haze shows up in the reflections too
const float HAZE_REFLECT = 1.0;
// a blurred copy of the arrow drawn under it as a faint halo, using a smaller mipmap of the same texture
const float ARROW_HALO_BLUR = 3.0;
const float ARROW_HALO = 0.35;

global uniform vec4 env_haze;

// brightness of the made-up studio seen along direction r
float studio(vec3 r) {
	float band = smoothstep(-0.1, 0.25, r.y) * (1.0 - smoothstep(0.25, 0.7, r.y));
	float top = pow(clamp(r.y, 0.0, 1.0), 3.0);
	return 0.15 + band * 0.5 + top * 0.5;
}

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
		float lit = clamp(dot(world_normal, normalize(LIGHT_DIR)), 0.0, 1.0);
		float shade = mix(SHADE_FLOOR, 1.0, lit);
		float n_dot_v = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float rim = pow(1.0 - n_dot_v, 3.0) * RIM_STRENGTH;
		vec3 base = body * (shade + sub_emission_energy + rim);
		bool neon = note_style == 1;
		if (neon) {
			vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
			vec3 r = reflect(-view_world, world_normal);
			vec3 reflection = mix(body, vec3(1.0), REFLECT_WHITE) * (studio(r) * REFLECT + env_haze.rgb * HAZE_REFLECT);
			float spec = pow(clamp(dot(world_normal, normalize(normalize(LIGHT_DIR) + view_world)), 0.0, 1.0), SPEC_POWER) * SPEC_STRENGTH;
			// on a bevel at least two of the three coordinates are near the edge of the cube
			float bevel = smoothstep(BEVEL_START, BEVEL_FULL, middle(abs(local_pos)));
			base += body * NEON_GLOW
				+ mix(body, vec3(1.0), BEVEL_WHITE) * bevel * BEVEL_STRENGTH * shade
				+ reflection + vec3(spec);
		}
		vec2 dot_uv = vec2(UV.x+0.5, UV.y);
		if (is_dot || arrows_enabled) {
			vec2 mark_uv = is_dot ? dot_uv : UV;
			base += texture(texture_emission, mark_uv).rgb;
			if (neon)
				base += texture(texture_emission, mark_uv, ARROW_HALO_BLUR).rgb * ARROW_HALO;
		}

		if (is_chain_head) {
			base += vec3( smoothstep(cut_white_margin+0.01,cut_white_margin,chain_interp) );
		}

		if (cutted){
			// soft white margin
			base += vec3( smoothstep(cut_white_margin+0.01,cut_white_margin,cut_interp) );
			// hard white margin
			//base += vec3( float(cut_white_margin < cut_interp) );
		}
		ALBEDO = base;
	} else {
		ALBEDO = vec3(1.0);
	}
}
