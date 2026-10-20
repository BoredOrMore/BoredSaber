// Light the player sends into the scene: each good cut starts a ring of that saber's colour at the player that
// runs outward along the scene's own lights (cut_waves holds how far each saber's ring has travelled, in metres,
// negative when there is none; EventDriver.cut_wave). The sabers' colours are also used by PlayerLight.gdshader.
// Untuned.
global uniform vec2 cut_waves;
global uniform vec4 left_saber_color;
global uniform vec4 right_saber_color;
// where the player stands (XROrigin3D)
const vec3 PLAYER_POSITION = vec3(0.0, 0.0, 1.0);
// metres: how thick the ring is, and how far it goes before it has faded to a third
const float CUT_WAVE_WIDTH = 1.5;
const float CUT_WAVE_FADE = 25.0;

float cut_wave_at(float distance, float front) {
	float x = (distance - front) / CUT_WAVE_WIDTH;
	return front < 0.0 ? 0.0 : exp(-x * x - front / CUT_WAVE_FADE);
}

vec3 cut_wave_light(vec3 world) {
	float distance = length(world.xz - PLAYER_POSITION.xz);
	return left_saber_color.rgb * cut_wave_at(distance, cut_waves.x)
		+ right_saber_color.rgb * cut_wave_at(distance, cut_waves.y);
}
