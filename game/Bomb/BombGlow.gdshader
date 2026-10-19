shader_type spatial;
render_mode unshaded, cull_front;

// A thin glowing outline drawn behind the dark bomb body, pulsing slowly in the danger colour, so bombs
// show up in a dark scene without glowing all over. It used to be a thick shell; Beat Saber's bombs are
// plain dark shapes (see BombBody.gdshader). All values untuned.
uniform vec4 danger_color : source_color = vec4(1.0, 0.188, 0.188, 1.0);
uniform float grow_amount = 0.09;
uniform float pulse_speed = 2.0;
uniform float pulse_depth = 0.35;

void vertex() {
	VERTEX += NORMAL * grow_amount;
}

void fragment() {
	ALBEDO = danger_color.rgb * (1.0 - pulse_depth * (0.5 + 0.5 * sin(TIME * pulse_speed)));
}
