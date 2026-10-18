shader_type spatial;
render_mode unshaded, cull_front;

// Glowing shell drawn behind the black bomb body, pulsing slowly in the danger colour.
uniform vec4 danger_color : source_color = vec4(1.0, 0.69, 0.125, 1.0);
uniform float grow_amount = 0.18;
uniform float pulse_speed = 4.0;
uniform float pulse_depth = 0.35;

void vertex() {
	VERTEX += NORMAL * grow_amount;
}

void fragment() {
	ALBEDO = danger_color.rgb * (1.0 - pulse_depth * (0.5 + 0.5 * sin(TIME * pulse_speed)));
}
