shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// The sabers light the floor around the player: a soft pool of each blade's colour under its tip, small and bright
// near the floor, wider and dimmer higher up, as a real light would. Drawn added on top of whatever floor the
// environment has, on a square around the player that fades out at its edges. Untuned.
#include "res://game/env/player_light.gdshaderinc"
// the blade tips, set by LightSaber.gd (far below the floor while a blade is off)
global uniform vec3 left_saber;
global uniform vec3 right_saber;
const float POOL_GAIN = 0.35;
// the pool's radius on the floor, in metres, and how much it grows per metre the tip is above the floor
const float POOL_RADIUS = 0.3;
const float POOL_SPREAD = 0.5;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float pool(vec3 tip) {
	float height = tip.y - world.y;
	if (height < 0.0) {
		return 0.0;
	}
	float radius = POOL_RADIUS + POOL_SPREAD * height;
	vec2 offset = world.xz - tip.xz;
	return exp(-dot(offset, offset) / (radius * radius)) / (1.0 + height * height);
}

void fragment() {
	vec2 square = abs(UV * 2.0 - 1.0);
	float edge = 1.0 - smoothstep(0.6, 1.0, max(square.x, square.y));
	ALBEDO = (left_saber_color.rgb * pool(left_saber) + right_saber_color.rgb * pool(right_saber)) * POOL_GAIN * edge;
}
