shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// The swept sheet behind a saber (tail.gd), added in the saber's colour. UV.x is the age along the sheet (0 at the
// blade, 1 the oldest), UV.y the opacity there, from how fast the blade swept (0 at rest, 1 on a full swing).
uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 2.4;

// a bright leading edge, then an even fade
float age_fade(float x) {
	if (x < 0.08) {
		return mix(1.0, 0.7, x / 0.08);
	}
	if (x < 0.5) {
		return mix(0.7, 0.3, (x - 0.08) / 0.42);
	}
	return mix(0.3, 0.0, (x - 0.5) / 0.5);
}

void fragment() {
	ALBEDO = color.rgb * age_fade(UV.x) * UV.y * energy;
}
