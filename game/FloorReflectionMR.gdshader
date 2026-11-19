shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_disabled, fog_disabled, shadows_disabled;

// FloorReflection in mixed reality: with the portal mask (portal_mask.gdshaderinc), whose discard hides what the room's
// walls cover (FloorReflection.gdshaderinc).
#define PORTAL_MASK
#include "res://game/FloorReflection.gdshaderinc"
