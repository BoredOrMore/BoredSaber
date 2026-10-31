// The note look: glossy coloured plastic as in Beat Saber, so the
// notes stop reading as painted tin cans (owner, 2026-10-25). Shared by BeepCube.gdshader and ChainLink.gdshader.
// Fake light only (AGENTS.md "Light", rule 10), a few math operations per pixel, no texture:
//   1. body: the note's colour glowing on its own, at a medium level so the colour stays clear in a dark scene
//   2. form: faces turned up brighter, faces turned down darker
//   3. clear coat: Schlick's Fresnel (Schlick 1994) with F0 0.04 (plastic) blends the body toward a reflection of the
//      note's own fixed, neutral light (GLOSS_LIGHT), tinted by the body
//   4. highlight: a narrow streak on the top bevels only, in that light tinted by the body. Never white: on Beat Saber's
//      notes the edges are the body's colour and only the arrow is white (owner's reference shots, 2026-10-25)
// The light is the note's own, never the stage's: like Beat Saber's note shaders (a fixed light in the material, BSMG
// notes guide), the note keeps its colour whatever the stage's lights and haze do (owner, 2026-10-26: notes tinted
// by the stage were harder to read). It used to reflect env_light and env_haze and take an underside tint from them.
// The arrow and dot (white-hot core going to the note's colour, with a halo) are drawn by the note's own shader.
// All values untuned until a headset playtest.

const float GLOSS_BODY = 0.55;
const float GLOSS_FORM_TOP = 1.15;
const float GLOSS_FORM_BOTTOM = 0.55;
const float GLOSS_F0 = 0.04;
// the note's own light: neutral grey, the level of the stage's lights the reflections used to take at their usual
// brightness
const vec3 GLOSS_LIGHT = vec3(0.35);
// how far reflections and highlights take the body's colour (0 the light's own, 1 fully the body's)
const float GLOSS_TINT = 0.6;
const float GLOSS_HIGHLIGHT = 0.6;
const float GLOSS_HIGHLIGHT_BODY = 0.35;
// how far up a bevel must face to catch the highlight (world normal's y), from none to all
const vec2 GLOSS_HIGHLIGHT_UP = vec2(0.35, 0.8);

// The glossy note's colour for a face: `body` the note colour (Darker Notes already applied), `n` the face's world
// normal, `v` the world direction toward the eye, `bevel` 0 on flat faces to 1 on the bevels.
vec3 note_gloss(vec3 body, vec3 n, vec3 v, float bevel) {
	vec3 lit = body * GLOSS_BODY * mix(GLOSS_FORM_BOTTOM, GLOSS_FORM_TOP, n.y * 0.5 + 0.5);
	float fresnel = GLOSS_F0 + (1.0 - GLOSS_F0) * pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 5.0);
	vec3 tint = mix(vec3(1.0), body, GLOSS_TINT);
	vec3 reflection = GLOSS_LIGHT * tint;
	vec3 color = mix(lit, reflection, fresnel);
	float up = smoothstep(GLOSS_HIGHLIGHT_UP.x, GLOSS_HIGHLIGHT_UP.y, n.y);
	color += (GLOSS_LIGHT * tint + body * GLOSS_HIGHLIGHT_BODY) * bevel * up * GLOSS_HIGHLIGHT;
	return color;
}
