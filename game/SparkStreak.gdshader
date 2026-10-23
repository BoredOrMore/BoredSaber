shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// A spark with a trail (CutFlash.spark_mesh): the mesh runs along the particle's velocity, brightest at its head
// (UV.y 1) and fading down the tail, soft at its sides. The particle's colour (white cooling to the saber's) comes
// in COLOR, its fade in COLOR.a.
void fragment() {
	float side = 1.0 - abs(UV.x * 2.0 - 1.0);
	ALBEDO = COLOR.rgb * COLOR.a * UV.y * UV.y * side;
}
