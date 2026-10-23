shader_type spatial;
render_mode unshaded, cull_back;

// The bomb body: near-black, like Beat Saber's bombs, which read as dark shapes against the bright notes
// (Chroma's BombColorizer, github.com/Aeroluna/Heck/blob/master/Chroma/Colorizer/BombColorizer.cs, colours
// one plain body that is near-black by default). The scene has no lights, so the same fake light as the
// notes (BeepCube.gdshader) gives each facet a faint glossy sheen, which shows the spiky shape. All values untuned.
const vec3 LIGHT_DIR = vec3(-0.3, 0.8, 0.5);
const vec3 BODY = vec3(0.03);
const float SHADE = 0.06;
const float SHEEN_POWER = 12.0;
const float SHEEN_STRENGTH = 0.18;

void fragment() {
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 light = normalize(LIGHT_DIR);
	float lit = clamp(dot(world_normal, light), 0.0, 1.0);
	float sheen = pow(clamp(dot(world_normal, normalize(light + view_world)), 0.0, 1.0), SHEEN_POWER);
	ALBEDO = BODY + vec3(lit * SHADE + sheen * SHEEN_STRENGTH);
}
