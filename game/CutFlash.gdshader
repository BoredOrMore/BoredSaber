shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// The streak CutFlash.gd draws where a saber cut a note: white-hot along its middle, the saber's colour at its
// edges (AGENTS.md "Light"), thinning to points at both ends. fade runs from 1 to 0.
uniform vec4 color : source_color = vec4(1.0);
uniform float fade = 0.0;
const float CORE_WHITE = 0.7;
const float GAIN = 1.6;

void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float along = abs(UV.x * 2.0 - 1.0);
	float body = (1.0 - smoothstep(0.0, 1.0, across)) * (1.0 - smoothstep(0.4, 1.0, along));
	ALBEDO = mix(color.rgb, vec3(1.0), CORE_WHITE * (1.0 - across)) * body * fade * GAIN;
}
