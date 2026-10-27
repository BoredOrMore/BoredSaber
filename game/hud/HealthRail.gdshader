shader_type spatial;
// A health strip drawn as a capsule on a flat quad (PlaneMesh, x across, z along), so the ends are rounded and
// the edge stays smooth at any distance (signed distance + fwidth, Quilez "2D distance functions"). Brighter at the
// end nearest the player, fading toward the far end. The rounding keeps its shape when the strip is scaled along z.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0);
// brightness at the far end relative to the near end (untuned)
uniform float far_brightness = 0.45;
// empty margin the quad has around the capsule, in metres, so the soft edge isn't cut off by the quad's own edge
uniform float edge_pad = 0.01;

varying vec2 pos;
varying float radius;
varying float half_length;

void vertex() {
	float scale_z = length(MODEL_MATRIX[2].xyz);
	pos = vec2(VERTEX.x, VERTEX.z * scale_z);
	// every vertex sits on the quad's edge, so these are the same at all four
	radius = abs(VERTEX.x) - edge_pad;
	half_length = abs(VERTEX.z) * scale_z - edge_pad;
}

void fragment() {
	float h = max(half_length - radius, 0.0);
	float d = length(vec2(pos.x, max(abs(pos.y) - h, 0.0))) - radius;
	float aa = fwidth(d);
	float coverage = 1.0 - smoothstep(-aa, aa, d);
	float near = clamp(pos.y / max(half_length, 1e-4) * 0.5 + 0.5, 0.0, 1.0);
	ALBEDO = color.rgb * mix(far_brightness, 1.0, near);
	ALPHA = color.a * coverage;
}
