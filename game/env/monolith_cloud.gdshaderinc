// Monolith's cloud (MonolithRig.gd): the clouds' tones, shared by the cloud rings (MonolithCloud.gdshader) and by
// everything that sinks into them, the valley, the pillar (MonolithFloor) and the slab (MonolithFace): below the clouds'
// level a surface takes the cloud's own tone at that depth, so nothing pokes hard through a cloud or shows beneath it
// (owner, 2026-10-31). Include after fog_light.gdshaderinc. BLOCKOUT, all values untuned.

// the cloud rings round the player (cloud_centre, world xz), nearest first: their radii and their level (the puffs'
// middle height), set by MonolithRig from its CLOUD_RINGS, which must have CLOUD_RING_COUNT rings
const int CLOUD_RING_COUNT = 6;
uniform float cloud_radii[CLOUD_RING_COUNT];
uniform float cloud_levels[CLOUD_RING_COUNT];
uniform vec2 cloud_centre = vec2(0.0, 1.0);
// the body: a neutral grey plus this many times the haze, just under the top (x) and CLOUD_DARK_DEPTH metres down (y)
const vec2 CLOUD_TOP_TONE = vec2(0.05, 1.2);
const vec2 CLOUD_LOW_TONE = vec2(0.008, 0.25);
const float CLOUD_DARK_DEPTH = 45.0;
// the farthest ring is this far toward the plain haze, and this much brighter
const float CLOUD_FAR_HAZE = 0.5;
const float CLOUD_FAR_LIFT = 1.4;
// a surface fades into the cloud over this many metres either side of its level
const float CLOUD_SOFT = 8.0;

// `color` on a ring `far` of the way from the nearest to the farthest: paler and closer to the haze.
vec3 cloud_far(vec3 color, vec3 haze, float far) {
	return mix(color * mix(1.0, CLOUD_FAR_LIFT, far), haze, CLOUD_FAR_HAZE * far);
}

// The cloud's tone `down` metres under its top, `far` of the way from the nearest ring to the farthest.
vec3 cloud_tone(vec3 haze, float down, float far) {
	float low = clamp(down / CLOUD_DARK_DEPTH, 0.0, 1.0);
	vec3 body = mix(vec3(CLOUD_TOP_TONE.x) + haze * CLOUD_TOP_TONE.y, vec3(CLOUD_LOW_TONE.x) + haze * CLOUD_LOW_TONE.y, low);
	return cloud_far(body, haze, far);
}

// `color` of a surface at `world`, sunk into the clouds where it lies below their level there.
vec3 under_cloud(vec3 color, vec3 haze, vec3 world) {
	float r = length(world.xz - cloud_centre);
	// the level between the two rings either side, held flat inside the nearest and beyond the farthest
	float level = cloud_levels[0];
	for (int i = 1; i < CLOUD_RING_COUNT; i++) {
		float share = clamp((r - cloud_radii[i - 1]) / (cloud_radii[i] - cloud_radii[i - 1]), 0.0, 1.0);
		level = mix(level, cloud_levels[i], share);
	}
	float far = clamp((r - cloud_radii[0]) / (cloud_radii[CLOUD_RING_COUNT - 1] - cloud_radii[0]), 0.0, 1.0);
	float depth = level - world.y;
	float share = smoothstep(-CLOUD_SOFT, CLOUD_SOFT, depth);
	return mix(color, cloud_tone(haze, max(depth, 0.0), far), share);
}
