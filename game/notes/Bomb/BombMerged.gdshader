shader_type spatial;
render_mode unshaded, cull_back;

// The bomb in one draw call (Bomb.merged_mesh): its dark body (BombBody.gdshader) and its glowing outline hull
// (BombGlow.gdshader) in one mesh, the hull's triangles flagged by UV2.x = 1 and wound the other way, so cull_back
// draws the hull's back faces as BombGlow's cull_front did. The same looks, values and uniforms as those two; Bomb.classic
// brings back the two-mesh bomb to compare.
const vec3 LIGHT_DIR = vec3(-0.3, 0.8, 0.5);
const vec3 BODY = vec3(0.03);
const float SHADE = 0.06;
const float SHEEN_POWER = 12.0;
const float SHEEN_STRENGTH = 0.18;

uniform vec4 danger_color : source_color = vec4(1.0, 0.188, 0.188, 1.0);
uniform float grow_amount = 0.09;
uniform float pulse_speed = 2.0;
uniform float pulse_depth = 0.35;

varying float hull;

void vertex() {
	hull = UV2.x;
	if (hull > 0.5) {
		VERTEX += NORMAL * grow_amount;
	}
}

void fragment() {
	if (hull > 0.5) {
		ALBEDO = danger_color.rgb * (1.0 - pulse_depth * (0.5 + 0.5 * sin(TIME * pulse_speed)));
	} else {
		vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec3 light = normalize(LIGHT_DIR);
		float lit = clamp(dot(world_normal, light), 0.0, 1.0);
		float sheen = pow(clamp(dot(world_normal, normalize(light + view_world)), 0.0, 1.0), SHEEN_POWER);
		ALBEDO = BODY + vec3(lit * SHADE + sheen * SHEEN_STRENGTH);
	}
}
