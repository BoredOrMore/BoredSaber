shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The dark solid scenery with the metal sheen and the vents: Metal Factory (EnvSolid.gdshaderinc;
// the track's edges use EnvSolidTrack, the same with the portal mask).
#define METAL
#define VENTS
#include "res://game/env/EnvSolid.gdshaderinc"
