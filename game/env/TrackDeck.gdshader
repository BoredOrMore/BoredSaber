shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

// TrackDeck outside mixed reality: with no portal mask, so it has no discard and keeps the GPU's early depth test
// (TrackDeck.gdshaderinc; TrackDeck.gd swaps in TrackDeckMR.gdshader while mixed reality is on).
#include "res://game/env/TrackDeck.gdshaderinc"
