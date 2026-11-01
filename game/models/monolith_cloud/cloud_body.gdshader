shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;
#include "cloud_surface.gdshaderinc"
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
    world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal = MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment() { ALBEDO = mcloud_output(mcloud_body_tone(world_position,world_normal)); }
