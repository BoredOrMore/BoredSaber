shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

// A crisp "X" with rounded ends, drawn from its distance field so it stays sharp at any size.
uniform vec4 color : source_color = vec4(1.0, 0.3, 0.37, 1.0);
uniform float alpha = 1.0;
uniform float arm = 0.34;
uniform float thickness = 0.07;

void fragment() {
	// fold the quad into one quadrant: both strokes become the segment (0,0)-(arm,arm)
	vec2 p = abs(UV - 0.5);
	vec2 b = vec2(arm);
	float h = clamp(dot(p, b) / dot(b, b), 0.0, 1.0);
	float d = length(p - b * h);
	float aa = fwidth(d);
	ALBEDO = color.rgb;
	ALPHA = alpha * (1.0 - smoothstep(thickness - aa, thickness + aa, d));
}
