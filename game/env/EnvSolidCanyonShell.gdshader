shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, blend_mix, cull_front, depth_draw_never;

// The soft outline around Night City's far boxes (the landmark, the towers' bodies): EnvSolid's canyon shading on a
// blown-up, see-through copy of each box that fades out away from its outline (EnvSolid.gdshaderinc layer 10).
#define CANYON
#define SHELL
#include "res://game/env/EnvSolid.gdshaderinc"
