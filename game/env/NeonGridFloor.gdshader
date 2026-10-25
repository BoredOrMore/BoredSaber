shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The Neon Grid floor: glowing lines on a dark plain, lit by the air colour (env_haze) so they follow the
// map's lights. The grid stands still on purpose: a floor sliding past at the edge of view makes a standing
// player feel they are moving (vection), which goes with VR sickness (Keshavarz, Riecke, Hettinger & Campos
// 2015, doi:10.3389/fpsyg.2015.00472). Lines never get thinner than MIN_LINE_PIXELS and dim instead (as
// NeonRibbon.gdshader does), and the floor fades into the horizon haze far away. The lines themselves fade out
// between LINE_FADE_START and LINE_FADE_END: a repeating pattern that fills the view lets the eyes lock onto
// it at the wrong depth (Apple visionOS HIG, Eyes), so the grid stays only around the player. All values untuned.
global uniform vec4 env_haze;
#include "res://game/env/shadow_tone.gdshaderinc"
#include "res://game/env/height_fog.gdshaderinc"
#include "res://game/env/player_light.gdshaderinc"
// metres between lines
const float SPACING = 2.0;
const float LINE_WIDTH = 0.04;
const float MIN_LINE_PIXELS = 1.0;
// 2.5 lit the whole floor's lines brighter than the stage (owner, 2026-10-25: too bright)
const float LINE_GAIN = 1.2;
// how bright a cut's wave runs along the lines (player_light.gdshaderinc)
const float CUT_WAVE_GAIN = 2.0;
// the floor lines are a big area, so they stay part grey (AGENTS.md "Light", rule 3). Untuned.
const float LINE_DESATURATE = 0.4;
const float GROUND_SHADE = 0.3;
const float FADE_DISTANCE = 60.0;
// metres from the player where the lines start fading, and where they are gone
const float LINE_FADE_START = 8.0;
const float LINE_FADE_END = 25.0;
// the skies' haze at the horizon (SKY_HAZE + 1 in both), so the floor meets the sky without a seam
const float HORIZON_HAZE = 1.25;

varying vec3 world;
// worked out per vertex (the plane is subdivided for it), since it changes slowly across the plane
varying float fade;
// the floor sits in the densest part of the height fog
varying float ground_fog;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fade = exp(-length(world.xz - CAMERA_POSITION_WORLD.xz) / FADE_DISTANCE);
	ground_fog = height_fog(world, CAMERA_POSITION_WORLD);
}

void fragment() {
	// metres to the nearest line along each axis
	mediump vec2 to_line = abs(fract(world.xz / SPACING + 0.5) - 0.5) * SPACING;
	vec2 px = fwidth(world.xz);
	vec2 half_width = max(vec2(LINE_WIDTH * 0.5), px * MIN_LINE_PIXELS * 0.5);
	vec2 lines = (1.0 - smoothstep(half_width - px, half_width + px, to_line)) * (LINE_WIDTH * 0.5 / half_width);
	float line = max(lines.x, lines.y);
	line *= 1.0 - smoothstep(LINE_FADE_START, LINE_FADE_END, length(world.xz - CAMERA_POSITION_WORLD.xz));
	vec3 line_col = mix(env_haze.rgb, vec3(max(env_haze.r, max(env_haze.g, env_haze.b))), LINE_DESATURATE);
	vec3 near = mix(env_haze.rgb * GROUND_SHADE, line_col * LINE_GAIN + cut_wave_light(world) * CUT_WAVE_GAIN, line);
	ALBEDO = mix(env_haze.rgb * HORIZON_HAZE, near, fade);
	ALBEDO = mix(ALBEDO, env_haze.rgb * HEIGHT_FOG_GLOW, ground_fog);
	ALBEDO = shadow_tone(ALBEDO);
}
