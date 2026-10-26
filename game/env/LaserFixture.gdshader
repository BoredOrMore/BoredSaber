shader_type spatial;
// The moving-head lights the lasers leave from: heads and yokes (game/models/laser_fixture(_yoke).glb, made by
// tools/models/laser_fixture.py). The yokes have no lens (green 0), so they draw as body only.
// One MultiMesh for all of them (LaserFixtures.gd); each copy's custom data is its beam's colour, black when off.
// In layers:
//   1. base: dark metal, a little lighter than the scenery so the fixtures read above it (AGENTS.md "Light", rule 1)
//   2. form: faces shaded by which way they point, as if lit from above, times the occlusion baked in Blender
//      (vertex colour red), so the grooves and the lens's rim are darker
//   3. light spill: the lights' colour on the body (env_light), as on the rest of the scenery
//   4. lens (vertex colour green): the bright spot where the beam leaves, white-hot in the middle of the beam's
//      colour and as bright as the beam (rule 2: brighten toward white, never past 1)
//   5. haze: fades into the air with distance (Quilez, "Better fog", 2010)
// All per vertex except the mixing: the faces are flat. Values untuned.
render_mode unshaded, fog_disabled, shadows_disabled;

global uniform vec4 env_haze;
global uniform vec4 env_light;
#include "res://game/env/fog_light.gdshaderinc"
#include "res://game/env/height_fog.gdshaderinc"

// 1. base
const vec3 METAL = vec3(0.13, 0.13, 0.14);
// 2. form: brightness of a face pointing straight up, sideways and straight down
const float FORM_TOP = 1.0;
const float FORM_SIDE = 0.7;
const float FORM_BOTTOM = 0.45;
// 3. light spill: how much of the lights' colour the body takes
const float SPILL = 0.12;
// 4. lens: how far its colour leans toward white at full brightness
const float LENS_WHITE = 0.6;
// 5. haze: per metre, and how much of the height fog the body takes
const float FOG_DENSITY = 0.03;
const float SOLID_HEIGHT_FOG = 0.55;

varying float shade;
varying float lens;
varying vec3 beam;
varying float fog;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float form = normal.y > 0.0 ? mix(FORM_SIDE, FORM_TOP, normal.y) : mix(FORM_SIDE, FORM_BOTTOM, -normal.y);
	// glTF vertex colours arrive linear; the square root brings the baked occlusion back to how it was painted
	shade = form * sqrt(COLOR.r);
	lens = COLOR.g;
	beam = INSTANCE_CUSTOM.rgb;
	float dist = length(world - CAMERA_POSITION_WORLD);
	fog = max(1.0 - exp(-FOG_DENSITY * dist), height_fog(world, CAMERA_POSITION_WORLD) * SOLID_HEIGHT_FOG);
}

void fragment() {
	// the haze lit from the stage's key light, seen this way (fog_light.gdshaderinc)
	vec3 haze = fog_lit(env_haze.rgb, (INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
	vec3 body = (METAL + env_light.rgb * SPILL) * shade;
	float level = max(beam.r, max(beam.g, beam.b));
	vec3 glow = mix(beam, vec3(level), LENS_WHITE * level);
	vec3 lit = mix(body, glow, lens * step(0.001, level));
	// the lens is a light: haze dims it less than the body
	ALBEDO = fog_dither(mix(lit, haze, fog * (1.0 - 0.5 * lens)), FRAGCOORD.xy);
}
