shader_type spatial;
render_mode unshaded, cull_back;
// Rounded panel matching the menu theme. size is the quad size in metres.
uniform vec2 size = vec2(1.0);
// 0 idle, 1 hovered, 2 pressed
uniform float highlight = 0.0;
uniform float corner_radius = 0.04;
uniform float border_width = 0.006;
uniform vec3 fill_color : source_color;
uniform vec3 hover_color : source_color;
uniform vec3 pressed_color : source_color;
uniform vec3 border_color : source_color;
uniform vec3 hover_border_color : source_color;

void fragment() {
	vec2 q = abs((UV - 0.5) * size) - (size * 0.5 - corner_radius);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner_radius;
	if (d > 0.0) {
		discard;
	}
	vec3 fill = highlight > 1.5 ? pressed_color : (highlight > 0.5 ? hover_color : fill_color);
	vec3 border = highlight > 0.5 ? hover_border_color : border_color;
	ALBEDO = d > -border_width ? border : fill;
}
