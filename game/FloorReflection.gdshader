shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_disabled, fog_disabled, shadows_disabled;

// The notes and sabers mirrored under the track's deck (FloorReflection.gd), faked without a second render or a screen
// read (AGENTS.md "Light", rule 10): each mirrored vertex keeps the place on screen a mirror would show it at, but takes
// the depth of the deck's surface where the eye's ray meets it, so the opaque deck doesn't hide it and anything above the
// deck still covers it. Among the reflections, one nearer the deck stands a hair nearer the eye (ORDER_SPAN), and they
// draw twice: a depth-only pass (prepass, from FloorReflection.gd's first material) and then the colour, which only
// lands where its depth is the nearest. So, as in a mirror, the reflection of the lower of two stacked notes hides the
// upper one's instead of showing through it (owner, 2026-10-28). It fades as it goes deeper under the deck: a dark glossy floor, not a mirror. No texture: the
// note texture's dot ring showed under each box (owner, 2026-10-28). A fainter, greyer, soft-edged try read too faint
// on the headset; the owner kept the first strength.
global uniform vec4 left_saber_color;
global uniform vec4 right_saber_color;
uniform float floor_y = 0.0;
// the depth-only pass: writes the reflections' depth and no colour
uniform bool prepass = false;
// how strong the reflection is at the deck's surface (owner, 2026-10-28: 0.3 too clear, 0.12 too faint, picked 0.275)
const float STRENGTH = 0.275;
// fade by depth: strongest where a note meets its reflection at the deck, falling off exponentially to about a fifth
// at FADE_DEPTH metres under it; off: a gentle linear fade to nothing at FADE_DEPTH_LINEAR (the first version's)
const bool DEPTH_FADE = true;
const float FADE_DEPTH = 1.2;
const float FADE_DEPTH_LINEAR = 3.5;
// fade by distance: none beyond FADE_FAR metres from the eye along the floor, full from FADE_NEAR, so far notes
// don't double up on the deck
const bool DISTANCE_FADE = true;
const float FADE_FAR = 18.0;
const float FADE_NEAR = 4.0;
// the deck's depth is taken this far above it, so the reflection wins the depth test against the deck itself
const float DEPTH_LIFT = 0.003;
// reflections down to ORDER_DEPTH metres under the deck are ordered by depth below it: the shallowest stands
// ORDER_SPAN (a share of its distance from the eye) nearer than the deepest
const float ORDER_DEPTH = 3.0;
const float ORDER_SPAN = 0.002;
// how bright the mirrored body is (the notes' own body glows at 0.55 of its colour)
const float BODY = 0.55;

varying float below;
varying float away;
varying vec4 tint;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	below = floor_y - world.y;
	away = length((world - CAMERA_POSITION_WORLD).xz);
	// custom data: rgb the note's colour, a 0 a note, 2 the left saber, 3 the right
	float kind = INSTANCE_CUSTOM.a;
	tint = kind > 2.5 ? right_saber_color : kind > 1.5 ? left_saber_color : vec4(INSTANCE_CUSTOM.rgb * BODY, 1.0);
	vec4 clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
	vec3 eye = CAMERA_POSITION_WORLD;
	float t = (eye.y - floor_y - DEPTH_LIFT) / max(eye.y - world.y, 1e-4);
	t *= 1.0 - ORDER_SPAN * (1.0 - clamp(below / ORDER_DEPTH, 0.0, 1.0));
	vec4 on_deck = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(eye + (world - eye) * t, 1.0));
	clip.z = on_deck.z / on_deck.w * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = tint.rgb;
	float depth_fade = DEPTH_FADE ? exp(-1.6 * below / FADE_DEPTH) : 1.0 - smoothstep(0.0, FADE_DEPTH_LINEAR, below);
	float distance_fade = DISTANCE_FADE ? 1.0 - smoothstep(FADE_NEAR, FADE_FAR, away) : 1.0;
	ALPHA = prepass ? 0.0 : STRENGTH * depth_fade * distance_fade;
}
