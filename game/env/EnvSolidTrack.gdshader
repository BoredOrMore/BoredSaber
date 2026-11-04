shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The track's pieces (TrackDeck): EnvSolidMetal's layers plus the portal mask, since mixed reality shows them through
// the portals and in the room (EnvSolid.gdshaderinc, layer 11).
#define METAL
#define VENTS
#define PORTAL_MASK
#include "res://game/env/EnvSolid.gdshaderinc"
