shader_type spatial;
render_mode unshaded, cull_back;

// BombMerged outside mixed reality: with no portal mask, so it has no discard and keeps the GPU's early depth test
// (BombMerged.gdshaderinc; Bomb.gd swaps in BombMergedMR.gdshader while mixed reality is on).
#include "res://game/notes/Bomb/BombMerged.gdshaderinc"
