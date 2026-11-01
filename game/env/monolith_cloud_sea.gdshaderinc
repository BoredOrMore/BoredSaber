// Monolith's cloud sea (MonolithCloudSea.gd; owner, 2026-11-01: the version made with GPT in stylized-3d-agent, picked
// over the 3D banks after a headset comparison): the tones of the sea's body, and `under_cloud` for everything that
// sinks into it (the slab, the valley and pillar, the hills), all looked up in the sea's baked height map, so nothing
// pokes hard through the clouds or shows beneath them. Include after the shader's `env_haze` and fog_light.gdshaderinc.
// Untuned (values as the owner saw them on the headset, 2026-11-01).

// the sea's height map (MonolithCloudSea binds it): RG a 16-bit height share packed high byte first, B the share of
// the cell the sea covers; and where it lies: its xz bounds in the sea's space (x, z, width, depth), the heights the
// share maps to, and world to the sea's space. A linear data texture: no source_color, no mipmaps.
uniform sampler2D mcloud_surface_map : filter_linear, repeat_disable;
uniform vec4 mcloud_bounds;
uniform vec2 mcloud_height_range;
uniform mat4 mcloud_world_to_local;
// the sea reaches this far from its centre (metres; the GLB's outer edge)
const float SEA_RADIUS = 980.0;
// the body: a grey this bright just under the sea's surface (x) and DARK_DEPTH metres down (y), plus HAZE_SHARE of the
// haze; lit by KEY (a fixed direction) between KEY_FLOOR and 1
const vec2 SEA_TONE = vec2(0.044, 0.010);
const float DARK_DEPTH = 45.0;
const float HAZE_SHARE = 0.5;
const vec3 KEY = vec3(-0.4, 0.85, -0.3);
const float KEY_FLOOR = 0.55;
// with distance (FAR_FROM to SEA_RADIUS metres from the centre) the tone goes FAR_SHARE of the way to the haze plus
// FAR_LIFT
const float FAR_FROM = 80.0;
const float FAR_SHARE = 0.6;
const float FAR_LIFT = 0.046;
// a surface fades into the sea over this many metres either side of its surface
const float SINK_SOFT = 8.0;

// The sea at `world`: x its surface height there (world y), y the share of the cell it covers (0 outside the sea),
// zw the point in the sea's space (x, z).
vec4 mcloud_sample(vec3 world) {
	vec3 local = (mcloud_world_to_local * vec4(world, 1.0)).xyz;
	vec2 uv = (local.xz - mcloud_bounds.xy) / mcloud_bounds.zw;
	vec4 data = texture(mcloud_surface_map, uv);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0)
			* step(length(local.xz), SEA_RADIUS);
	float value = (data.r * 65280.0 + data.g * 255.0) / 65535.0 / max(data.b, 0.000001);
	float height = mix(mcloud_height_range.x, mcloud_height_range.y, value);
	return vec4(height + world.y - local.y, data.b * inside, local.x, local.z);
}

// The sea's tone `depth` metres under its surface, `radius` metres from its centre, on a surface facing `normal`.
vec3 mcloud_tone(vec3 haze, float depth, float radius, vec3 normal) {
	float far = smoothstep(FAR_FROM, SEA_RADIUS, radius);
	float key = max(dot(normalize(normal), normalize(KEY)), 0.0);
	float grey = mix(SEA_TONE.x, SEA_TONE.y, clamp(depth / DARK_DEPTH, 0.0, 1.0));
	vec3 value = vec3(grey) * (KEY_FLOOR + key * (1.0 - KEY_FLOOR)) + haze * HAZE_SHARE;
	return mix(value, haze + vec3(FAR_LIFT), far * FAR_SHARE);
}

// The sea's body at `world` facing `normal`.
vec3 mcloud_body_tone(vec3 haze, vec3 world, vec3 normal) {
	vec4 surface = mcloud_sample(world);
	return mcloud_tone(haze, max(surface.x - world.y, 0.0), length(surface.zw), normal);
}

// `color` of a surface at `world`, sunk into the sea where it lies below the sea's surface there.
vec3 under_cloud(vec3 color, vec3 haze, vec3 world) {
	vec4 surface = mcloud_sample(world);
	float depth = surface.x - world.y;
	float share = smoothstep(-SINK_SOFT, SINK_SOFT, depth) * step(0.001, surface.y);
	return mix(color, mcloud_tone(haze, max(depth, 0.0), length(surface.zw), vec3(0.0, 1.0, 0.0)), share);
}

// `linear_color` as the screen wants it: the sea's tones are linear, so they are encoded to sRGB where the output is.
vec3 mcloud_output(vec3 linear_color) {
	if (!OUTPUT_IS_SRGB) {
		return linear_color;
	}
	return mix(linear_color * 12.92, 1.055 * pow(max(linear_color, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055,
			step(vec3(0.0031308), linear_color));
}
