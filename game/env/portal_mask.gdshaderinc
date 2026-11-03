// Room-aware mixed reality: whatever lies beyond the room's walls (MRSpace, the track's far part, notes still on their
// way) shows only where the eye looks through a portal cut in a real wall (owner, 2026-11-02: virtual scenery only
// inside portals; 2026-11-03: the track and the lights too). MixedReality.gd sets the globals:
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

// Whether world lies beyond the wall of the portal `to_portal` maps into.
bool portal_mask_beyond(mat4 to_portal, vec3 world) {
	return (to_portal * vec4(world, 1.0)).z > 0.0;
}

// Whether a point at world (world space) shows from the eye at eye: on the room's side of every portal's wall, or seen
// through a portal; always with none. So the world behind shows only in the holes, and things that cross into the room
// (the track, notes) show whole once inside it.
bool portal_mask_shows(vec3 eye, vec3 world) {
	if (mr_portal_count == 0) {
		return true;
	}
	bool beyond = portal_mask_beyond(mr_portal_0, world)
		|| (mr_portal_count > 1 && portal_mask_beyond(mr_portal_1, world))
		|| (mr_portal_count > 2 && portal_mask_beyond(mr_portal_2, world))
		|| (mr_portal_count > 3 && portal_mask_beyond(mr_portal_3, world));
	return !beyond || portal_mask_through(mr_portal_0, eye, world)
		|| (mr_portal_count > 1 && portal_mask_through(mr_portal_1, eye, world))
		|| (mr_portal_count > 2 && portal_mask_through(mr_portal_2, eye, world))
		|| (mr_portal_count > 3 && portal_mask_through(mr_portal_3, eye, world));
}
