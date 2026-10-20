shader_type spatial;
render_mode unshaded, shadows_disabled;

// The saber hilt: dark gunmetal with machined grip ridges and a bright rim where it turns away from the eye, so it
// reads as metal without scene lights; the ring at the blade's base glows in the saber colour (set_color), the
// fixture the blade's light comes out of (AGENTS.md "Light"). Unshaded and texture-free on purpose. Untuned.
uniform vec4 metal : source_color = vec4(0.16, 0.17, 0.19, 1.0);
// 1 on the grip: ridges every RIDGE_SPACING metres
uniform float ridges = 0.0;
// 1 on the glow ring: the saber colour instead of metal
uniform float glow = 0.0;
uniform vec4 accent : source_color = vec4(1.0);
const float RIDGE_SPACING = 0.012;
const float RIM_LIGHT = 0.5;

varying float height;

void vertex() {
	height = VERTEX.y;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float ridge = ridges * smoothstep(0.3, 0.7, 0.5 + 0.5 * sin(height * TAU / RIDGE_SPACING));
	vec3 col = metal.rgb * (1.0 - 0.45 * ridge) + vec3(RIM_LIGHT) * rim;
	// the glow ring burns white-hot at its face and shows the saber colour toward its edges
	vec3 hot = mix(accent.rgb, vec3(1.0), 0.5 * (1.0 - rim));
	ALBEDO = mix(col, hot, glow);
}
