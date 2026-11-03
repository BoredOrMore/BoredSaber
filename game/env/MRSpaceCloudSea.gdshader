shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled, depth_draw_never;
// Only where a portal's sky window marked the stencil (MRSpaceSky.gdshader), so the GPU skips the sea's pixels
// outside the portals before shading them (Bored, 2026-11-03: the room's outside costs nothing).
stencil_mode read, compare_equal, 1;

// The cloud sea below the mixed-reality world (MRSpace.gd), Monolith's sea (MonolithCloudSea.gdshader) seen only
// through the portals. It writes no depth, so it draws among the see-through things, first of them (MRSpace sets its
// render priority), after the sky windows have marked the stencil.
global uniform vec4 env_haze;
#include "res://game/env/monolith_cloud_sea.gdshaderinc"
#include "res://game/env/portal_mask.gdshaderinc"
// the whole body's brightness (MonolithCloudSea.brightness)
uniform float brightness = 1.0;

varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	// the stencil already keeps to the holes; this keeps them exact where the headset has no stencil buffer
	if (!portal_mask_through_any(CAMERA_POSITION_WORLD, world_position)) {
		discard;
	}
	ALBEDO = mcloud_output(mcloud_body_tone(env_haze.rgb, world_position, world_normal) * brightness);
}
