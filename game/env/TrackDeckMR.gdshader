shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

// TrackDeck in mixed reality: with the portal mask (portal_mask.gdshaderinc), whose discard hides what the room's
// walls cover (TrackDeck.gdshaderinc).
#define PORTAL_MASK
#include "res://game/env/TrackDeck.gdshaderinc"
