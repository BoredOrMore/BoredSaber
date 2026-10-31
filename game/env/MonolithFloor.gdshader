shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

// Monolith's plain (MonolithRig.gd): dark ground taking a little of the haze, brighter toward the horizon's glow behind
// the slab, with the slab's shadow falling across it toward the player: a wedge from the slab's foot, widening by
// SHADOW_SPREAD as it nears, fading over SHADOW_LENGTH. Its edges soften with distance (fwidth). Neutral: the ground
// takes the haze's colour, not the lights'. BLOCKOUT, untuned.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"

// the slab's centre on the floor (world xz), its turn left of straight ahead, half its width and its front face's
// distance from the player (MonolithRig)
uniform vec2 slab_centre = vec2(0.0, -565.0);
uniform float slab_yaw = 0.0;
uniform float slab_half_width = 180.0;
uniform float slab_distance = 520.0;
// the ground's own darkness and the glow's share of the haze toward the slab, falling off with the angle away from it
// and growing out to GLOW_DISTANCE (the horizon's glow lighting the far ground)
const float GROUND = 0.05;
const float GLOW = 0.25;
const float GLOW_FALLOFF = 2.0;
const float GLOW_DISTANCE = 1000.0;
// the shadow: how much it darkens, how it widens per metre toward the player, how far it reaches
const float SHADOW = 0.9;
const float SHADOW_SPREAD = 0.15;
const float SHADOW_LENGTH = 450.0;

varying vec3 haze_v;
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	haze_v = fog_lit(env_haze.rgb, world - CAMERA_POSITION_WORLD);
}

void fragment() {
	// the point in the slab's frame: across its face, and toward the player from its front face
	vec2 toward = vec2(sin(slab_yaw), cos(slab_yaw));
	vec2 across_dir = vec2(toward.y, -toward.x);
	vec2 p = world.xz - slab_centre;
	float near = dot(p, toward);
	float across = abs(dot(p, across_dir));
	float facing = clamp(dot(normalize(world.xz + vec2(1e-3)), -toward) * 0.5 + 0.5, 0.0, 1.0);
	float glow = GLOW * pow(facing, GLOW_FALLOFF) * clamp(length(world.xz) / GLOW_DISTANCE, 0.0, 1.0);
	float reach = max(near, 0.0);
	float half_width = slab_half_width + reach * SHADOW_SPREAD;
	float soft = fwidth(across) + 1.0;
	float inside = clamp((half_width - across) / soft, 0.0, 1.0) * step(0.0, near);
	float shadow = SHADOW * inside * (1.0 - clamp(reach / SHADOW_LENGTH, 0.0, 1.0));
	vec3 color = haze_v * (GROUND + glow) * (1.0 - shadow);
	ALBEDO = fog_dither(fog_result(color, VERTEX), FRAGCOORD.xy);
}
