shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The dark solid scenery with Night City's canyon: its shading, fog and windows (EnvSolid.gdshaderinc).
#define CANYON
#define WINDOWS
#include "res://game/env/EnvSolid.gdshaderinc"
