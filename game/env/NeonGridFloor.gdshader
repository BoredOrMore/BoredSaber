shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The Neon Grid floor: glowing lines on a dark plain, lit by the air colour (env_haze) so they follow the
// map's lights. The grid stands still on purpose: a floor sliding past at the edge of view makes a standing
// player feel they are moving (vection), which goes with VR sickness (Keshavarz, Riecke, Hettinger & Campos
// 2015, doi:10.3389/fpsyg.2015.00472). Lines never get thinner than MIN_LINE_PIXELS and dim instead (as
// NeonRibbon.gdshader does), and the floor fades into the horizon haze far away. All values untuned.
global uniform vec4 env_haze;
// metres between lines
const float SPACING = 2.0;
const float LINE_WIDTH = 0.04;
const float MIN_LINE_PIXELS = 1.0;
const float LINE_GAIN = 4.0;
const float GROUND_SHADE = 0.3;
const float FADE_DISTANCE = 60.0;
// the skies' haze at the horizon (SKY_HAZE + 1 in both), so the floor meets the sky without a seam
const float HORIZON_HAZE = 1.25;

varying vec3 world;
// worked out per vertex (the plane is subdivided for it), since it changes slowly across the plane
varying float fade;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fade = exp(-length(world.xz - CAMERA_POSITION_WORLD.xz) / FADE_DISTANCE);
}

void fragment() {
	// metres to the nearest line along each axis
	mediump vec2 to_line = abs(fract(world.xz / SPACING + 0.5) - 0.5) * SPACING;
	vec2 px = fwidth(world.xz);
	vec2 half_width = max(vec2(LINE_WIDTH * 0.5), px * MIN_LINE_PIXELS * 0.5);
	vec2 lines = (1.0 - smoothstep(half_width - px, half_width + px, to_line)) * (LINE_WIDTH * 0.5 / half_width);
	float line = max(lines.x, lines.y);
	vec3 near = mix(env_haze.rgb * GROUND_SHADE, env_haze.rgb * LINE_GAIN, line);
	ALBEDO = mix(env_haze.rgb * HORIZON_HAZE, near, fade);
}
