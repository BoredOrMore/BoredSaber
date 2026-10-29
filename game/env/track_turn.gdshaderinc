// The track turns with the notes on 90/360 maps (EventDriver.track_angle, radians) about the player's standing point
// (Constants.PLAYER_Z): track_xz gives a world point's place in the unturned track's space (x across, z along), so the
// deck's grooves and skin and the far fade of the deck, its edges and strips turn with them (TrackDeck.turn). 0 on
// Standard maps and for everything that doesn't turn.
uniform float track_angle = 0.0;
const float TRACK_PIVOT_Z = 1.0;

vec2 track_xz(vec3 world) {
	vec2 d = vec2(world.x, world.z - TRACK_PIVOT_Z);
	float c = cos(track_angle);
	float s = sin(track_angle);
	return vec2(c * d.x + s * d.y, -s * d.x + c * d.y + TRACK_PIVOT_Z);
}
