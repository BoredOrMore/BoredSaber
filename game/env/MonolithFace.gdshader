shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

// The Monolith slab (MonolithRig.gd): black, a silhouette against the horizon's glow, with its lights drawn on its
// front face here rather than as strip meshes (they would fight for depth 500-1000 m out): its left and right vertical
// edges in the left and right lasers' colours, SEAMS horizontal seams in the square bars' colour lit from the foot up
// (lit: the share lit, EventDriver._update_monolith, each fading in over its own step), a slit up the middle in the
// floor lights' colour open from the foot to `slit` of the height (the drop opens it all the way). Every line keeps at
// least MIN_PIXELS across so it doesn't shimmer, dimmed to keep its light; a white-hot core along its middle (AGENTS.md
// "Light", rule 2). Its foot sinks into the clouds. BLOCKOUT, untuned.
global uniform vec4 env_haze;
#include "res://game/env/fog_light.gdshaderinc"
#include "res://game/env/monolith_cloud.gdshaderinc"

uniform vec3 size = vec3(360.0, 810.0, 90.0);
uniform vec4 left_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 right_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 bar_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 floor_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float lit = 1.0;
uniform float slit = 0.0;
// widths in metres: the edge strips, the seams, and the slit; the seams' count up the face
const float EDGE_WIDTH = 3.0;
const float SEAM_WIDTH = 1.5;
const float SLIT_WIDTH = 2.0;
const float SEAMS = 8.0;
const float MIN_PIXELS = 1.5;
const float CORE_WHITE = 0.5;

varying vec3 local;
varying float front;
varying vec3 world;
varying vec3 haze_v;

void vertex() {
	local = VERTEX;
	front = step(0.5, NORMAL.z);
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	haze_v = fog_lit(env_haze.rgb, world - CAMERA_POSITION_WORLD);
}

// How much of a line `width` metres wide, `d` metres from its middle, covers this pixel, at least MIN_PIXELS wide.
float line(float d, float width) {
	float pixel = fwidth(d) + 1e-4;
	float drawn = max(width, MIN_PIXELS * pixel);
	return clamp((drawn * 0.5 - d) / pixel + 0.5, 0.0, 1.0) * width / drawn;
}

void fragment() {
	float x = local.x;
	float y = local.y + size.y * 0.5;
	float edge = line(abs(size.x * 0.5 - EDGE_WIDTH * 0.5 - abs(x)), EDGE_WIDTH);
	vec3 color = (x < 0.0 ? left_color.rgb : right_color.rgb) * edge;
	float step_height = size.y / (SEAMS + 1.0);
	float seam = round(y / step_height);
	float seam_on = seam >= 1.0 && seam <= SEAMS ? clamp(lit * SEAMS - (seam - 1.0), 0.0, 1.0) : 0.0;
	color += bar_color.rgb * line(abs(y - seam * step_height), SEAM_WIDTH) * seam_on;
	float slit_on = 1.0 - smoothstep(slit * size.y - 4.0, slit * size.y, y);
	color += floor_color.rgb * line(abs(x), SLIT_WIDTH) * slit_on;
	color *= front;
	float peak = max(color.r, max(color.g, color.b));
	// its foot sinks into the clouds (monolith_cloud.gdshaderinc)
	ALBEDO = fog_result(under_cloud(mix(color, vec3(peak), CORE_WHITE * peak), haze_v, world), VERTEX);
}
