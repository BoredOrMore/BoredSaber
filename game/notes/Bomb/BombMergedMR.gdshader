shader_type spatial;
render_mode unshaded, cull_back;

// BombMerged in mixed reality: with the portal mask (portal_mask.gdshaderinc), whose discard hides what the room's
// walls cover (BombMerged.gdshaderinc).
#define PORTAL_MASK
#include "res://game/notes/Bomb/BombMerged.gdshaderinc"
