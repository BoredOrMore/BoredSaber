shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The dark solid scenery with the metal sheen and the vents: Metal Factory and the track's edges (EnvSolid.gdshaderinc).
#define METAL
#define VENTS
#include "res://game/env/EnvSolid.gdshaderinc"
