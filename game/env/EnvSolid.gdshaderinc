// Dark solid scenery (tunnel frames, rings, floor lines, buildings), drawn as Beat Saber's: dark matte metal that
// takes on the colour of the lights that are on, so the whole set turns red or blue with the show. In layers:
//   1. base: the dark metal (albedo)
//   2. form: faces shaded by which way they point, as if lit from above (top lighter, bottom darker)
//   3. light spill: the lights' colour (env_light, set by EventDriver) on every face, more on faces turned toward
//      the track, where the lights are
//   4. lit edge (rings only): the hole's edge glows in the lights' colour, like the lit edge of a real ring. It is
//      light, so it goes on after the haze and the haze only dims it
//   5. haze: fades into the air's colour with distance and more so near the floor (Quilez, "Better fog", 2010).
//      Rings take less of it, so they stay dark shapes against the sky instead of turning haze-grey (headset,
//      2026-10-24: at 30 m the full haze left them flat grey and hid their lit edge)
//   6. vents (Metal Factory's wall panels only): the louvers the model marks in vertex colour (green the upper row,
//      blue the lower, tools/models/wall_kit.py) glow in their light group's colour, set each frame by the rig: the
//      upper row in vent_upper_color, the lower in vent_left_color or vent_right_color by the panel's wall (which side
//      of the track its origin is; MultiMesh custom data would do, but in the Compatibility renderer turning it on lost
//      the mesh's vertex colours, desktop capture 2026-10-25). Hot core toward white where a louver faces the eye, its colour on the
//      faces turned away, as LightStrip.gdshader (AGENTS.md "Light", rule 2). Light, so after the haze, which only
//      dims it; black on every other material (the colours default to black)
//   7. ambient occlusion: models bake it into vertex colour red (tools/models/model_export.py; green and blue are the
//      vents' marks); it darkens the metal, form, spill and sheen in creases and where pieces meet. A mesh without vertex
//      colours (plain boxes, older meshes) reads white, so it isn't darkened
//   8. metal sheen (matcap, metal > 0: Metal Factory's metal pieces): a small grey picture of a lit sphere
//      (tools/make_matcap.py) looked up by the face's view-space normal, giving a soft highlight from above and a rim
//      toward grazing angles, as polished metal shows. Grey only: tinted with a neutral grey and the lights' colour
//      (env_light), kept well under the fixtures in the brightness order (Light rules 1, 3 and 4). Off (0) elsewhere
//   2b. Night City's canyon (side_shade, depth_shade > 0; 0 elsewhere): upright faces turned along the track darker
//      than faces turned to it, so pilasters and setbacks read in relief, and walls darker toward the street than
//      at their top (window_span), as the canyon's floor in shadow
//   5b. a stage's own fog (canyon_fog.w > 0: Night City's canyon): a thick layer measured from canyon_fog.x (the
//      cloud sea's level, CloudSea.gdshader), canyon_fog.y per metre there, thinning by canyon_fog.z per metre going up,
//      so the towers' feet vanish into it where the clouds meet them; its density rolls with a slow drifting noise
//      (fog_roll), so its edge moves instead of lying flat. Per vertex like the rest of the haze: NightCityRig cuts its
//      boxes at heights close together near the clouds (FOG_CUTS), so the faces have vertices where the fog changes
//      (per pixel cost ~4 ms with the windows in real play, 2026-10-26)
//   9. windows (windows > 0: Night City's canyon, NightCityRig): real-size windows on the buildings' upright faces
//      farther than window_min_x from the track, worked out per pixel from the face's position (a texture or vertex
//      mask would need too many vertices for towers of 57 floors): WINDOW_PITCH apart, FLOOR_HEIGHT a floor, each
//      room lit or not by a hash. window_level (0-1, the show's build-up) lights the rooms in order, bottom to top and
//      near before far; window_glow dims them in quiet parts but never to dark; the colour is the map's light colour
//      on that side of the track (window_left_color, window_right_color) with a warm room tint. Where a room is
//      smaller than a pixel the windows blend into their average, so far walls don't sparkle. Light, after the haze,
//      kept well under the notes (Light rule 1)
// The scene has no real lights (AGENTS.md "Light", rule 10), so layers 2-4 are faked here. Everything but the edge's
// falloff is worked out per vertex: the faces are flat, so per pixel would give the same picture. Values untuned.
// Each stage's shader (EnvSolid*.gdshader) defines only the layers it uses, so the GPU runs none of the others: one
// shader with them all cost Night City ~4 ms and Metal Factory ~3 ms a frame (bench, 2026-10-26). RING: 4;
// VENTS: 6; METAL: 8; CANYON: 2b and 5b, with WINDOWS 9. A layer left out is the same as its uniforms at their off values.

global uniform vec4 env_haze;
global uniform vec4 env_light;
#include "res://game/env/fog_light.gdshaderinc"
#include "res://game/env/height_fog.gdshaderinc"
// DebugView.RINGS leaves these out (no area, so nothing is drawn); DebugView.FLAT_SCENERY draws them one flat colour
global uniform int debug_view;

// 1. base
uniform vec4 albedo : source_color = vec4(0.094, 0.094, 0.094, 1.0);

// 2. form: brightness of a face pointing straight up, sideways and straight down
const float FORM_TOP = 1.0;
const float FORM_SIDE = 0.7;
const float FORM_BOTTOM = 0.45;

// 3. light spill: how much of the lights' colour a face takes when turned away from the track and toward it.
// Kept low so scenery stays below fixtures and beams in the brightness order (AGENTS.md "Light", rule 1).
const float SPILL_AWAY = 0.04;
const float SPILL_TOWARD = 0.14;
// all of the spill, per material: lower for an environment whose large faces would otherwise read as grey sheets
uniform float light_spill = 1.0;
// the track's axis the lights gather around: x 0, this high (metres)
const float TRACK_AXIS_Y = 2.0;

#ifdef RING
// 4. lit edge: rings only. Half the size of the hole in the ring mesh's own units (game/data/ring.obj: 0.936);
// 0 leaves the edge off.
uniform float ring_hole = 0.0;
// how much of the lights' colour the very edge takes, and how tight the glow hugs it (higher = thinner)
const float EDGE_LIGHT = 0.7;
const float EDGE_TIGHTNESS = 2.0;
#endif

#ifdef VENTS
// 6. vents: the light groups' colours (black is off), how bright the louvers burn and how far their facing faces go
// toward white
uniform vec4 vent_upper_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 vent_left_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 vent_right_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
const float VENT_GLOW = 0.9;
const float VENT_CORE_WHITE = 0.6;
const float VENT_CORE_SHARPNESS = 2.0;
#endif

// 7. ambient occlusion: how much of the baked occlusion shows (0 none, 1 all)
const float AO_STRENGTH = 0.8;
#ifdef METAL
// 8. metal sheen: how much (0 off), the matcap picture, and the sheen's neutral grey and share of the lights' colour
uniform float metal = 0.0;
uniform sampler2D matcap : hint_default_black, filter_linear_mipmap;
const float METAL_GREY = 0.04;
const float METAL_LIGHT = 0.12;
#endif
#ifdef CANYON
// 9. windows: on (1) or off (0), the lights' colours either side, how far through the build-up the rooms are lit and how
// bright, the faces nearer the track than window_min_x left plain, and the street and top the rooms count up between
// 2b. the canyon's shading
uniform float side_shade = 0.0;
uniform float depth_shade = 0.0;
uniform float windows = 0.0;
uniform vec4 window_left_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 window_right_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float window_level = 0.0;
uniform float window_glow = 0.0;
uniform float window_min_x = 8.0;
uniform vec2 window_span = vec2(-45.0, 200.0);
// every this many cells along a wall a pilaster stands (Night City's canyon: cells 4k), so those cells get no window; 0 none
uniform int window_pier_cells = 0;
const float WINDOW_PITCH = 2.0;
const float FLOOR_HEIGHT = 3.5;
// the window inside its cell (parts of the cell, from the cell's corner), the rooms that ever light, the warm tint
const vec4 WINDOW_RECT = vec4(0.125, 0.25, 0.875, 0.85);
// from x to y metres the windows turn into their average (per vertex, no screen derivatives; owner 2026-10-26: from
// closer than before, which switched where a window was under about a pixel)
const vec2 WINDOW_FAR = vec2(90.0, 150.0);
const float WINDOW_OCCUPIED = 0.65;
const vec3 ROOM_WARM = vec3(1.0, 0.8, 0.6);
const float ROOM_WARMTH = 0.25;
// at most about the notes' own body (0.55, note_gloss.gdshaderinc), so they stay the brightest (Light rule 1)
const float WINDOW_LIGHT = 0.6;
// how the build-up orders the rooms: height, distance along the track (over WINDOW_REACH metres) and chance
const vec3 WINDOW_ORDER = vec3(0.6, 0.3, 0.1);
const float WINDOW_REACH = 200.0;
#endif

// 5. haze: per metre
uniform float fog_density = 0.015;
// how fast the extra floor haze thins out going up, per metre
uniform float floor_haze_falloff = 0.35;
// how much of the height fog the solids take: less than the air, so buildings and frames read as dark shapes
const float SOLID_HEIGHT_FOG = 0.55;
// the most of the haze distance and height fog give anything, so far scenery stays a dark shape against a black
// background instead of turning the fog's colour (owner, 2026-10-26: halved; the black background had too much fog colour)
const float FAR_HAZE_MAX = 0.6;
#ifdef CANYON
// 5b. a stage's own fog: [level, density there, thinning per metre up, how much], how much its density rolls
uniform vec4 canyon_fog = vec4(0.0);
uniform float fog_roll = 0.0;
const float ROLL_SCALE = 0.04;
const float ROLL_SPEED = 0.12;
#endif
// the part of the haze the rings take
const float RING_FOG = 0.5;
// full haze from fade_z.x to fade_z.y metres out along the track (-z), for pieces that run on into the distance (the
// track's edges, TrackDeck.gd); off (0, 0) for the rest
uniform vec2 fade_z = vec2(0.0);

varying float fog;
varying float form;
varying float spill;
#ifdef RING
// 1 at the ring's hole, 0 at its outside; 0 for anything that isn't a ring
varying float edge;
#endif
#ifdef VENTS
// 6. this vertex's vent glow, before the hot core
varying vec3 vent;
#endif
// 7. how lit this vertex is after its baked occlusion
varying float ao;
#ifdef CANYON
// 9. the position and the face's direction in the world, for the windows
varying vec3 world_pos;
varying vec3 world_normal;
// the haze lit from the key light, per vertex (as the sky's)
varying vec3 haze_v;
#ifdef WINDOWS
// 0 near, where each window is drawn, to 1 far, where the windows' average is
varying float window_far;
#endif
#endif

// 5. how much of the haze covers a point at world, seen from cam
float fog_at(vec3 world, vec3 cam, float time) {
	float dist = length(world - cam);
	float distance_fog = 1.0 - exp(-fog_density * dist);
	float floor_haze = exp(-max(world.y, 0.0) * floor_haze_falloff);
	float f = clamp(distance_fog * mix(0.5, 1.0, floor_haze), 0.0, 1.0);
	// height fog lifts the solids' bottoms into the fog, but they stay darker than the air around them (silhouettes)
	f = min(max(f, height_fog(world, cam) * SOLID_HEIGHT_FOG), FAR_HAZE_MAX);
#ifdef CANYON
	if (canyon_fog.w > 0.0) {
		// 5b. the stage's own fog, its density rolling with two slow drifting waves
		vec3 p = world * ROLL_SCALE;
		float roll = sin(p.x * 1.3 + p.y * 0.7 + time * ROLL_SPEED) * sin(p.z * 1.1 - p.y * 0.9 - time * ROLL_SPEED * 0.8);
		float density = canyon_fog.y * max(1.0 + fog_roll * roll, 0.0);
		f = max(f, height_fog_from(world, cam, canyon_fog.x, density, canyon_fog.z) * canyon_fog.w);
	}
#endif
#ifdef RING
	if (ring_hole > 0.0) {
		f *= RING_FOG;
	}
#endif
	if (fade_z.y > fade_z.x) {
		f = max(f, smoothstep(fade_z.x, fade_z.y, -world.z));
	}
	return f;
}

void vertex() {
	if ((debug_view & 8) != 0) {
		VERTEX = vec3(0.0);
	}
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);

	// 2. form
	form = normal.y > 0.0 ? mix(FORM_SIDE, FORM_TOP, normal.y) : mix(FORM_SIDE, FORM_BOTTOM, -normal.y);
#ifdef CANYON
	// 2b. the canyon's shading
	form *= 1.0 - side_shade * abs(normal.z);
	form *= 1.0 - depth_shade * (1.0 - smoothstep(window_span.x, window_span.y, world.y));
#endif

	// 3. light spill: dot of the face's direction with the way to the track (1 facing it, -1 facing away)
	vec2 to_track = vec2(-world.x, TRACK_AXIS_Y - world.y);
	float facing = length(to_track) > 1e-3 ? dot(normal.xy, normalize(to_track)) : 0.0;
	spill = mix(SPILL_AWAY, SPILL_TOWARD, facing * 0.5 + 0.5) * light_spill;

#ifdef RING
	// 4. lit edge: the ring mesh is flat in its own xz plane; vertices around the hole are marked 1
	edge = ring_hole > 0.0 && max(abs(VERTEX.x), abs(VERTEX.z)) < ring_hole + 0.01 ? 1.0 : 0.0;
#endif

	// 5. haze
	fog = fog_at(world, CAMERA_POSITION_WORLD, TIME);
#ifdef CANYON
	haze_v = fog_lit(env_haze.rgb, world - CAMERA_POSITION_WORLD);
#ifdef WINDOWS
	window_far = smoothstep(WINDOW_FAR.x, WINDOW_FAR.y, length(world - CAMERA_POSITION_WORLD));
#endif
#endif

	// 7. ambient occlusion
	ao = mix(1.0, COLOR.r, AO_STRENGTH);
#ifdef CANYON
	world_pos = world;
	world_normal = normal;
#endif

#ifdef VENTS
	// 6. vents: the model's marks pick the row; the panel's side of the track picks the wall
	vec3 lower = mix(vent_left_color.rgb, vent_right_color.rgb, step(0.0, MODEL_MATRIX[3].x));
	vent = (vent_upper_color.rgb * COLOR.g + lower * COLOR.b) * VENT_GLOW;
#endif
}

#ifdef WINDOWS
float window_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// 9. the windows' light on this pixel (black off the buildings' upright faces)
vec3 windows_light() {
	if (windows <= 0.0 || abs(world_normal.y) > 0.5 || abs(world_pos.x) < window_min_x) {
		return vec3(0.0);
	}
	float along = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
	vec2 g = vec2(along / WINDOW_PITCH, (world_pos.y - window_span.x) / FLOOR_HEIGHT);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	// which face it is goes into the hash too, so the rooms of opposite faces differ
	vec2 room = cell + sign(world_normal.xz) * 97.0;
	float occupied = step(window_hash(room), WINDOW_OCCUPIED);
	if (window_pier_cells > 0 && mod(cell.x, float(window_pier_cells)) < 0.5) {
		occupied = 0.0;
	}
	float height = clamp((world_pos.y - window_span.x) / (window_span.y - window_span.x), 0.0, 1.0);
	float order = dot(WINDOW_ORDER, vec3(height, clamp(-world_pos.z / WINDOW_REACH, 0.0, 1.0), window_hash(room + 31.0)));
	float on = occupied * step(order, window_level);
	// hard edges (no smoothing: cheaper, owner's pick 2026-10-26)
	vec2 inside = step(WINDOW_RECT.xy, f) * step(f, WINDOW_RECT.zw);
	float shape = inside.x * inside.y * on;
	// far (WINDOW_FAR): the windows' average instead (the lit share of the area the build-up has reached)
	float average = (WINDOW_RECT.z - WINDOW_RECT.x) * (WINDOW_RECT.w - WINDOW_RECT.y) * WINDOW_OCCUPIED * clamp(window_level / max(order, 1e-3), 0.0, 1.0);
	float m = mix(shape, average, window_far);
	vec3 color = world_pos.x < 0.0 ? window_left_color.rgb : window_right_color.rgb;
	return mix(color, color * ROOM_WARM, ROOM_WARMTH) * m * window_glow * WINDOW_LIGHT * windows;
}
#endif

void fragment() {
	if ((debug_view & 32) != 0) {
		ALBEDO = albedo.rgb;
	} else {
		// the haze lit from the stage's key light, seen this way (fog_light.gdshaderinc)
#ifdef CANYON
		vec3 haze = haze_v;
#else
		vec3 haze = fog_lit(env_haze.rgb, (INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
#endif
		// light on top of the haze, which only dims it: the ring's lit edge and the vents
		vec3 light = vec3(0.0);
#ifdef RING
		// edge is interpolated linearly across the ring's band; the power pulls the glow in tight against the hole
		light += env_light.rgb * (pow(edge, EDGE_TIGHTNESS) * EDGE_LIGHT);
#endif
		vec3 lit = (albedo.rgb * form + env_light.rgb * spill * form) * ao;
#ifdef METAL
		if (metal > 0.0) {
			// view-space normal to the matcap's picture: x right, y up (the picture's rows run down)
			float sheen = texture(matcap, NORMAL.xy * vec2(0.5, -0.5) + 0.5).r;
			lit += metal * sheen * ao * (vec3(METAL_GREY) + env_light.rgb * METAL_LIGHT);
		}
#endif
#ifdef VENTS
		if (max(vent.r, max(vent.g, vent.b)) > 0.0) {
			float peak = max(vent.r, max(vent.g, vent.b));
			float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
			light += mix(vent, vec3(peak), VENT_CORE_WHITE * pow(facing, VENT_CORE_SHARPNESS));
		}
#endif
#ifdef CANYON
		float haze_amount = fog;
#ifdef WINDOWS
		// the windows: light, so on top of the haze, which only dims them
		vec3 windows_on = windows_light() * (1.0 - haze_amount);
#else
		vec3 windows_on = vec3(0.0);
#endif
#else
		float haze_amount = fog;
		vec3 windows_on = vec3(0.0);
#endif
		ALBEDO = fog_dither(mix(lit, haze, haze_amount) + light * (1.0 - haze_amount) + windows_on, FRAGCOORD.xy);
	}
}
