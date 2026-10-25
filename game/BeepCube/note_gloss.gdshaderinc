// The default note look (note_style 2, Settings.classic_notes off): glossy coloured plastic as in Beat Saber, so the
// notes stop reading as painted tin cans (owner, 2026-10-25). Shared by BeepCube.gdshader and ChainLink.gdshader.
// Fake light only (AGENTS.md "Light", rule 10), a few math operations per pixel, no texture:
//   1. body: the note's colour glowing on its own, at a medium level so the colour stays clear in a dark scene
//   2. form: faces turned up brighter, faces turned down darker
//   3. clear coat: Schlick's Fresnel (Schlick 1994) with F0 0.04 (plastic) blends the body toward a reflection of the
//      scene's light colour (env_light) and part of its haze (env_haze), tinted by the body: faces seen edge-on show
//      the scene, so in a dark scene they go darker, with no bright rim
//   4. highlight: a narrow streak on the top bevels only, in the scene's light colour tinted by the body, and the body's
//      own colour when the lights are off. Never white: on Beat Saber's notes the edges are the body's colour and only
//      the arrow is white (owner's reference shots, 2026-10-25)
//   5. underside: faces turned down take a faint tint of the light below (the floor and edge strips)
// The arrow and dot (white-hot core going to the note's colour, with a halo) are drawn by the note's own shader.
// All values untuned until a headset playtest.

global uniform vec4 env_light;

const float GLOSS_BODY = 0.55;
const float GLOSS_FORM_TOP = 1.15;
const float GLOSS_FORM_BOTTOM = 0.55;
const float GLOSS_F0 = 0.04;
const float GLOSS_REFLECT_LIGHT = 0.6;
const float GLOSS_REFLECT_HAZE = 0.5;
// how far reflections and highlights take the body's colour (0 the light's own, 1 fully the body's)
const float GLOSS_TINT = 0.6;
const float GLOSS_HIGHLIGHT = 0.6;
const float GLOSS_HIGHLIGHT_BODY = 0.35;
// how far up a bevel must face to catch the highlight (world normal's y), from none to all
const vec2 GLOSS_HIGHLIGHT_UP = vec2(0.35, 0.8);
const float GLOSS_UNDER_TINT = 0.12;

// The glossy note's colour for a face: `body` the note colour (Darker Notes already applied), `n` the face's world
// normal, `v` the world direction toward the eye, `bevel` 0 on flat faces to 1 on the bevels.
vec3 note_gloss(vec3 body, vec3 n, vec3 v, float bevel) {
	vec3 lit = body * GLOSS_BODY * mix(GLOSS_FORM_BOTTOM, GLOSS_FORM_TOP, n.y * 0.5 + 0.5);
	float fresnel = GLOSS_F0 + (1.0 - GLOSS_F0) * pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 5.0);
	vec3 tint = mix(vec3(1.0), body, GLOSS_TINT);
	vec3 reflection = (env_light.rgb * GLOSS_REFLECT_LIGHT + env_haze.rgb * GLOSS_REFLECT_HAZE) * tint;
	vec3 color = mix(lit, reflection, fresnel);
	float up = smoothstep(GLOSS_HIGHLIGHT_UP.x, GLOSS_HIGHLIGHT_UP.y, n.y);
	color += (env_light.rgb * tint + body * GLOSS_HIGHLIGHT_BODY) * bevel * up * GLOSS_HIGHLIGHT;
	color += env_light.rgb * GLOSS_UNDER_TINT * clamp(-n.y, 0.0, 1.0);
	return color;
}
