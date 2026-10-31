shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, blend_mix, cull_front, depth_draw_never;

// The soft outline around a stage's far boxes (Henge's slabs, Neon Grid's arches, Pulse Void's rim): EnvSolid's shading on a blown-up, see-through copy of
// each box that fades out away from its outline (EnvSolid.gdshaderinc layer 10).
#define SHELL
#include "res://game/env/EnvSolid.gdshaderinc"
