// The scene's shadows lean toward deep blue (Constants.SHADOW_TINT, set as the shadow_tint shader global): dark colours
// get the tint added, fading out by SHADOW_TINT_FADE_LUMA (display luma), so highlights and the note colours stay as they are. This used
// to be a colour-correction LUT on the WorldEnvironment, but in the Compatibility renderer that is a full-screen pass per
// eye, 1.3 ms of GPU a frame on the Pico 4; here each dark scenery shader tints its own pixels for a few operations.
// The LUT worked on display (sRGB) values; sqrt and squaring stand in for the sRGB curve, which is close enough here.
// Colour globals reach shaders in linear, so the tint goes through the same sqrt.
global uniform vec4 shadow_tint;
// sRGB luma at which the tint is gone
const float SHADOW_TINT_FADE_LUMA = 0.45;

vec3 shadow_tone(vec3 linear_color) {
	vec3 display = sqrt(max(linear_color, vec3(0.0)));
	float luma = dot(display, vec3(0.2126, 0.7152, 0.0722));
	display += sqrt(shadow_tint.rgb) * (1.0 - smoothstep(0.0, SHADOW_TINT_FADE_LUMA, luma));
	return display * display;
}
