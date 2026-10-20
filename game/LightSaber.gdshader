shader_type spatial;
render_mode unshaded, shadows_disabled;

// The blade burns white-hot along its middle and shows the saber colour toward its edges, like a real bright
// emitter (AGENTS.md "Light", rule 2: brighten toward white, never push a saturated colour past 1). Facing is
// how directly the surface looks at the eye: 1 down the middle of the blade, 0 at its silhouette. Untuned.
uniform vec4 color = vec4(1.0, 0.0, 0.0, 1.0);
// kept for the material's saved value; the core is white now
uniform vec4 center_color = vec4(0.0, 0.0, 0.0, 1.0);
const float CORE_WHITE = 0.85;
const float CORE_SHARPNESS = 3.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float core = pow(facing, CORE_SHARPNESS);
	ALBEDO = mix(color.rgb, vec3(1.0), CORE_WHITE * core);
}
