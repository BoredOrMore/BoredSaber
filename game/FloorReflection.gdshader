shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_disabled, fog_disabled, shadows_disabled;

// FloorReflection outside mixed reality: with no portal mask, so it has no discard and keeps the GPU's early depth test
// (FloorReflection.gdshaderinc; FloorReflection.gd swaps in FloorReflectionMR.gdshader while mixed reality is on).
#include "res://game/FloorReflection.gdshaderinc"
