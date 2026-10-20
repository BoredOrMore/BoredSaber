// Height fog with mass, worked out on the scenery's own vertices (no full-screen pass, no volumetric fog: the
// Pico 4's Compatibility renderer has neither to spare). The air is densest at the floor and thins out going up,
// so the bottoms of posts, frames and buildings sink into a layer of fog and distant floor dissolves into it;
// the fog takes the colour of the lights that are on (env_haze). Analytic integral of exponential height fog
// along the view ray (Quilez, "Better fog", 2010). Values untuned; shared by the scenery shaders.
// fog density at the floor (per metre), and how fast it thins out going up (per metre)
const float HEIGHT_FOG_DENSITY = 0.06;
const float HEIGHT_FOG_FALLOFF = 0.8;
// how much brighter the fog layer is than the plain haze, as it catches the stage's light
const float HEIGHT_FOG_GLOW = 1.4;

// How much of the view from cam to world is fogged (0 clear, 1 all fog).
float height_fog(vec3 world, vec3 cam) {
	vec3 ray = world - cam;
	float dist = length(ray);
	float ry = ray.y / max(dist, 1e-4);
	float start = HEIGHT_FOG_DENSITY * exp(-max(cam.y, 0.0) * HEIGHT_FOG_FALLOFF);
	float amount = abs(ry) < 1e-3
		? start * dist
		: start * (1.0 - exp(-dist * ry * HEIGHT_FOG_FALLOFF)) / (ry * HEIGHT_FOG_FALLOFF);
	return 1.0 - exp(-max(amount, 0.0));
}
