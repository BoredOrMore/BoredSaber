shader_type spatial;
render_mode unshaded, shadows_disabled;

// A light strip on a surface (the track's edge lights, the platform's border): it burns white-hot where it faces the
// eye and shows its colour on the faces turned away, so it reads as a bright tube instead of a flat saturated bar
// (AGENTS.md "Light", rule 2). Off (black) stays black. Texture-free; untuned.
uniform vec4 light_color : source_color = vec4(1.0);
const float CORE_WHITE = 0.8;
const float CORE_SHARPNESS = 2.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float peak = max(light_color.r, max(light_color.g, light_color.b));
	ALBEDO = mix(light_color.rgb, vec3(peak), CORE_WHITE * pow(facing, CORE_SHARPNESS));
}
