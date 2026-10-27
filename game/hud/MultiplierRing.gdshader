shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// The ring around the multiplier on the HUD, as in Beat Saber: one segment for each hit the next multiplier needs
// (2 at x1, 4 at x2, 8 at x4), lit clockwise from the top as the hits come in; whole at x8. ComboHud.gd drives it.
uniform vec3 fill_color : source_color = vec3(1.0);
uniform vec3 empty_color : source_color = vec3(0.25);
uniform float segments = 2.0;
// lit segments, fractional while one is filling in
uniform float filled = 0.0;
// 0..1, brightens and thickens the ring for a moment when the multiplier goes up
uniform float flash = 0.0;
// 0..1, the whole ring's opacity (ComboHud's shockwave fades out with it)
uniform float fade = 1.0;
// radii as a part of the quad (0.5 is its edge)
const float INNER = 0.39;
const float OUTER = 0.46;
const float FLASH_GROWTH = 0.03;
// gap between segments, as a part of the whole circle
const float GAP = 0.015;

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p);
	float aa = fwidth(r);
	float grow = flash * FLASH_GROWTH;
	float ring = smoothstep(INNER - grow - aa, INNER - grow, r) * (1.0 - smoothstep(OUTER + grow, OUTER + grow + aa, r));
	// 0 at the top, going clockwise
	float t = fract(atan(p.x, -p.y) / TAU);
	float seg = t * segments;
	float in_seg = fract(seg);
	float half_gap = segments > 1.0 ? 0.5 * GAP * segments : 0.0;
	// pixel size along the ring, in segments (fwidth of the angle jumps where it wraps at the top)
	float seg_aa = aa / (TAU * r) * segments;
	float body = segments > 1.0 ? smoothstep(half_gap, half_gap + seg_aa, in_seg) * (1.0 - smoothstep(1.0 - half_gap - seg_aa, 1.0 - half_gap, in_seg)) : 1.0;
	float lit = step(in_seg, clamp(filled - floor(seg), 0.0, 1.0));
	ALBEDO = mix(mix(empty_color, fill_color, lit), vec3(1.0), flash * 0.6);
	ALPHA = ring * body * fade;
}
