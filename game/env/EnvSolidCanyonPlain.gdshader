shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The dark solid scenery with Night City's canyon shading and fog but no windows: the pieces near the track that never
// show any (the rooftop, its railing and stair house, the rooftop props) (EnvSolid.gdshaderinc).
#define CANYON
#include "res://game/env/EnvSolid.gdshaderinc"
