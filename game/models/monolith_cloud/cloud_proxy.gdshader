shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;
#include "cloud_surface.gdshaderinc"
uniform float tone = 0.004;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() { ALBEDO = mcloud_output(under_cloud(vec3(tone),mcloud_haze,world_position)); }
