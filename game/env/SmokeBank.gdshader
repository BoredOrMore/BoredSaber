shader_type spatial;
// A big soft puff of smoke beside or behind the track, drawn as a square that always faces the player's position
// (not the view direction, so it doesn't swing around when the head turns). Inside it a round soft falloff and a slowly
// turning, drifting noise texture make the puff; like the floor smoke it is lit through the shared haze colour and
// fades out close to the player. Meant for a MultiMesh of QuadMesh instances; each instance's position and scale place
// the puff. All values untuned.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform vec4 env_haze;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float opacity = 0.25;

// radians per second at most, each puff gets its own speed and direction
const float SPIN = 0.05;
// side-to-side sway in metres and its speed
const float SWAY = 0.4;
const float SWAY_SPEED = 0.15;
const float NOISE_SCALE = 0.8;
const float DENSITY_FROM = 0.3;
const float DENSITY_TO = 0.8;
const float NEAR_START = 2.0;
const float NEAR_FULL = 4.0;
const vec3 SMOKE_BASE = vec3(0.05, 0.05, 0.08);
const float LIGHT_GAIN = 6.0;

varying vec2 uv;
varying float seed;
varying float fade;

void vertex() {
	seed = fract(float(INSTANCE_ID) * 0.618034);
	vec3 center = MODEL_MATRIX[3].xyz + vec3(sin(TIME * SWAY_SPEED + seed * 6.2832) * SWAY, 0.0, 0.0);
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 to_cam = CAMERA_POSITION_WORLD - center;
	float dist = length(to_cam);
	vec3 forward = to_cam / dist;
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
	vec3 up = cross(forward, right);
	vec3 world = center + (right * VERTEX.x + up * VERTEX.y) * size;
	float angle = seed * 6.2832 + TIME * SPIN * (seed * 2.0 - 1.0);
	uv = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * VERTEX.xy;
	fade = smoothstep(NEAR_START, NEAR_FULL, dist);
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
}

void fragment() {
	// the quad is -0.5..0.5, so r is 1 at the middle of each side
	float r = length(uv) * 2.0;
	float soft = 1.0 - smoothstep(0.1, 1.0, r);
	float n = texture(noise, uv * NOISE_SCALE + seed * 7.0 + TIME * 0.01).r;
	float density = soft * smoothstep(DENSITY_FROM, DENSITY_TO, n);
	ALBEDO = SMOKE_BASE + env_haze.rgb * LIGHT_GAIN;
	ALPHA = density * opacity * fade;
}
