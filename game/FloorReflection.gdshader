shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// The notes and sabers mirrored under the track's deck (FloorReflection.gd), faked without a second render or a screen
// read (AGENTS.md "Light", rule 10): each mirrored vertex keeps the place on screen a mirror would show it at, but takes
// the depth of the deck's surface where the eye's ray meets it, so the opaque deck doesn't hide it and anything above the
// deck still covers it. It fades as it goes deeper under the deck and stays faint: a dark glossy floor, not a mirror.
global uniform vec4 left_saber_color;
global uniform vec4 right_saber_color;
uniform float floor_y = 0.0;
uniform sampler2D texture_emission : hint_default_black;
// how strong the reflection is at the deck's surface, and how deep under it it has faded out (m)
const float STRENGTH = 0.3;
const float FADE_DEPTH = 3.5;
// the deck's depth is taken this far above it, so the reflection wins the depth test against the deck itself
const float DEPTH_LIFT = 0.003;
// how bright the mirrored body is against its arrow (the notes' own body glows at about this share of its colour)
const float BODY = 0.55;

varying float below;
varying vec4 tint;
varying float marked;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	below = floor_y - world.y;
	// custom data: rgb the note's colour, a 0 a note with an arrow, 1 a dot or an arrowless note, 2 the left saber, 3 the right
	float kind = INSTANCE_CUSTOM.a;
	tint = kind > 2.5 ? right_saber_color : kind > 1.5 ? left_saber_color : vec4(INSTANCE_CUSTOM.rgb * BODY, 1.0);
	marked = kind < 0.5 ? 1.0 : 0.0;
	vec4 clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
	vec3 eye = CAMERA_POSITION_WORLD;
	float t = (eye.y - floor_y - DEPTH_LIFT) / max(eye.y - world.y, 1e-4);
	vec4 on_deck = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(eye + (world - eye) * t, 1.0));
	clip.z = on_deck.z / on_deck.w * clip.w;
	POSITION = clip;
}

void fragment() {
	vec3 color = tint.rgb;
	if (marked > 0.5) {
		color = mix(color, vec3(1.0), texture(texture_emission, UV).r);
	}
	ALBEDO = color;
	ALPHA = STRENGTH * (1.0 - smoothstep(0.0, FADE_DEPTH, below));
}
