shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The dark solid scenery with the rings' lit edge (EnvSolid.gdshaderinc).
#define RING
#include "res://game/env/EnvSolid.gdshaderinc"
