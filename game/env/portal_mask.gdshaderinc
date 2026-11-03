// Room-aware mixed reality: the world behind the room's portals (MRSpace) shows only where the eye looks through a
// portal cut in a real wall (owner, 2026-11-02: virtual scenery only inside portals). MixedReality.gd sets the globals:
// how many portals there are, and for each the world-to-portal transform in which the hole is the square |x|, |y| <= 0.5
// on the wall's plane z = 0, with +z out of the room. With no portals (every stage outside mixed reality) everything
// shows. Include it, then discard where portal_mask_shows(world position) is false.
global uniform int mr_portal_count;
global uniform mat4 mr_portal_0;
global uniform mat4 mr_portal_1;
global uniform mat4 mr_portal_2;
global uniform mat4 mr_portal_3;

// Whether the line from the eye to world crosses the wall through the hole of the portal `to_portal` maps into.
bool portal_mask_through(mat4 to_portal, vec3 eye, vec3 world) {
	vec3 a = (to_portal * vec4(eye, 1.0)).xyz;
	vec3 b = (to_portal * vec4(world, 1.0)).xyz;
	if (a.z >= 0.0 || b.z <= 0.0) {
		return false;
	}
	vec2 hit = mix(a.xy, b.xy, -a.z / (b.z - a.z));
	return abs(hit.x) <= 0.5 && abs(hit.y) <= 0.5;
}

// Whether a point at world (world space) shows from the eye at eye: through any portal, or always with none.
bool portal_mask_shows(vec3 eye, vec3 world) {
	if (mr_portal_count == 0) {
		return true;
	}
	return portal_mask_through(mr_portal_0, eye, world)
		|| (mr_portal_count > 1 && portal_mask_through(mr_portal_1, eye, world))
		|| (mr_portal_count > 2 && portal_mask_through(mr_portal_2, eye, world))
		|| (mr_portal_count > 3 && portal_mask_through(mr_portal_3, eye, world));
}
