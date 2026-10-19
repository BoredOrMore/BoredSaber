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
// Polished coloured metal, as in Beat Saber: a darker body, with a made-up bright studio reflected in each face
// (a band near the horizon and a soft light overhead) tinted by the note colour, since metals reflect in their own
// colour (Cook & Torrance 1982), going white at grazing angles (Schlick 1994), plus a sharp highlight from the fake
// light (Blinn 1977). No reflection probe or texture: a few math operations per pixel. All values untuned.
const float BODY = 0.6;
const float REFLECT = 0.9;
const float SPEC_POWER = 48.0;
const float SPEC_STRENGTH = 0.6;
// the scene's lit haze shows up in the reflections too
const float HAZE_REFLECT = 1.5;

global uniform vec4 env_haze;

// brightness of the made-up studio seen along direction r
float studio(vec3 r) {
	float band = smoothstep(0.0, 0.2, r.y) * (1.0 - smoothstep(0.3, 0.55, r.y));
	float top = pow(clamp(r.y, 0.0, 1.0), 6.0);
	return 0.08 + band * 0.9 + top * 0.7;
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
void vertex() {
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

	if (FRONT_FACING) {
		vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float lit = clamp(dot(world_normal, normalize(LIGHT_DIR)), 0.0, 1.0);
		float shade = mix(SHADE_FLOOR, 1.0, lit);
		float n_dot_v = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float rim = pow(1.0 - n_dot_v, 3.0) * RIM_STRENGTH;
		vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec3 r = reflect(-view_world, world_normal);
		vec3 tint = mix(color.rgb, vec3(1.0), pow(1.0 - n_dot_v, 5.0));
		vec3 reflection = tint * (studio(r) * REFLECT + env_haze.rgb * HAZE_REFLECT);
		float spec = pow(clamp(dot(world_normal, normalize(normalize(LIGHT_DIR) + view_world)), 0.0, 1.0), SPEC_POWER) * SPEC_STRENGTH;
		vec3 base = color.rgb * (shade * BODY + sub_emission_energy) + color.rgb * rim + reflection + vec3(spec);
		vec2 dot_uv = vec2(UV.x+0.5, UV.y);
		if (is_dot || arrows_enabled)
			base += texture(texture_emission, is_dot ? dot_uv : UV).rgb;

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
