shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

// Neon Grid's arch strips (NeonGridRig): light strips along the arches' inner edges, in the square bars' light group.
// Each segment knows its height on its arch (INSTANCE_CUSTOM.x, 0 at the footings, 1 at the top) and whether it is on
// arch B (.y): it is lit once the show has built up to its height (level), all of B on the drop. Lit, it burns
// white-hot where it faces the eye and shows its colour on its sides (LightStrip.gdshader); unlit, it is a dark line on
// the arch. Untuned.
uniform vec4 light_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float level = 0.0;
uniform float drop = 0.0;
const float CORE_WHITE = 0.8;
const float CORE_SHARPNESS = 2.0;
const vec3 UNLIT = vec3(0.01);

varying float lit;

void vertex() {
	lit = max(step(INSTANCE_CUSTOM.x, level), drop * INSTANCE_CUSTOM.y);
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float peak = max(light_color.r, max(light_color.g, light_color.b));
	vec3 light = mix(light_color.rgb, vec3(peak), CORE_WHITE * pow(facing, CORE_SHARPNESS));
	ALBEDO = mix(UNLIT, light, lit);
}
