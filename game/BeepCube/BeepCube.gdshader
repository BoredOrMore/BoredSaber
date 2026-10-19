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
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * RIM_STRENGTH;
		vec3 base = color.rgb * (shade + sub_emission_energy) + color.rgb * rim;
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
