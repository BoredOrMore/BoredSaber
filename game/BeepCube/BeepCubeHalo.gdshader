shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// Fake bloom: a pre-baked soft glow drawn behind the cube instead of full-screen glow.
uniform vec4 color : source_color;
uniform float intensity = 0.6;
uniform sampler2D falloff : hint_default_black, filter_linear;

void fragment() {
	ALBEDO = color.rgb * texture(falloff, UV).r * intensity;
}
