// A flat colour quad with round corners, for UI pieces in 3D (WarningIcon's icon and card): cut by alpha scissor and
// smoothed by alpha to coverage like the menus' canvases (OQ_UI2DCanvas.round_corners), never blended.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 color : source_color = vec4(1.0);
// the quad's size and its corners' radius, metres
uniform vec2 size = vec2(1.0);
uniform float radius = 0.05;

void fragment() {
	vec2 p = abs((UV - 0.5) * size) - (size * 0.5 - radius);
	float d = length(max(p, 0.0)) + min(max(p.x, p.y), 0.0) - radius;
	ALBEDO = color.rgb;
	ALPHA = clamp(0.5 - d / fwidth(d), 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.5;
}
