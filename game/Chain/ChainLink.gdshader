shader_type spatial;
render_mode unshaded, cull_disabled;

// Same fake light and self-lit look as BeepCube.gdshader, since the scene has no lights; see there.
// The link has no bevelled edges, so it has no bevel highlight.
const vec3 LIGHT_DIR = vec3(-0.3, 0.8, 0.5);
const float SHADE_FLOOR = 0.45;
const float RIM_STRENGTH = 0.35;
const float REFLECT = 0.12;
const float REFLECT_WHITE = 0.2;
const float SPEC_POWER = 16.0;
const float SPEC_STRENGTH = 0.08;
const float HAZE_REFLECT = 1.0;

global uniform vec4 env_haze;

float studio(vec3 r) {
	float band = smoothstep(-0.1, 0.25, r.y) * (1.0 - smoothstep(0.25, 0.7, r.y));
	float top = pow(clamp(r.y, 0.0, 1.0), 3.0);
	return 0.15 + band * 0.5 + top * 0.5;
}

const float sub_emission_energy = 0.3;
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
		float x_centered = UV.x - 0.25;
		float y_centered = UV.y - 0.25;
		float dist_from_center_squared = x_centered * x_centered + y_centered * y_centered;
		if (dist_from_center_squared <= 0.001) {
			ALBEDO = vec3(1.0);
		} else {
			vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
			float shade = mix(SHADE_FLOOR, 1.0, clamp(dot(world_normal, normalize(LIGHT_DIR)), 0.0, 1.0));
			float n_dot_v = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
			float rim = pow(1.0 - n_dot_v, 3.0) * RIM_STRENGTH;
			vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
			vec3 r = reflect(-view_world, world_normal);
			vec3 reflection = mix(color.rgb, vec3(1.0), REFLECT_WHITE) * (studio(r) * REFLECT + env_haze.rgb * HAZE_REFLECT);
			float spec = pow(clamp(dot(world_normal, normalize(normalize(LIGHT_DIR) + view_world)), 0.0, 1.0), SPEC_POWER) * SPEC_STRENGTH;
			vec3 base = color.rgb * (shade + sub_emission_energy + rim) + reflection + vec3(spec);
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
