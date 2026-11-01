// Actual B surface lookup. Linear data texture: no source_color hint, no mipmaps.
uniform sampler2D mcloud_surface_map : filter_linear, repeat_disable;
uniform vec4 mcloud_bounds;
uniform vec2 mcloud_height_range;
uniform mat4 mcloud_world_to_local;
uniform vec3 mcloud_haze = vec3(0.018);

vec4 mcloud_sample(vec3 world) {
    vec3 local = (mcloud_world_to_local*vec4(world,1.0)).xyz;
    vec2 uv = (local.xz-mcloud_bounds.xy)/mcloud_bounds.zw;
    vec4 data = texture(mcloud_surface_map,uv);
    float inside = step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0)*step(length(local.xz),980.0);
    float value = (data.r*65280.0+data.g*255.0)/65535.0/max(data.b,0.000001);
    float height = mix(mcloud_height_range.x,mcloud_height_range.y,value);
    return vec4(height+world.y-local.y,data.b*inside,local.x,local.z);
}

vec3 mcloud_tone(vec3 haze, float depth, float radius, vec3 normal) {
    float far = smoothstep(80.0,980.0,radius);
    float key = max(dot(normalize(normal),normalize(vec3(-0.4,0.85,-0.3))),0.0);
    vec3 value = vec3(mix(0.044,0.010,clamp(depth/45.0,0.0,1.0)))*(0.55+key*0.45)+haze*0.5;
    return mix(value,haze+vec3(0.046),far*0.6);
}

vec3 mcloud_body_tone(vec3 world, vec3 normal) {
    vec4 surface = mcloud_sample(world);
    return mcloud_tone(mcloud_haze,max(surface.x-world.y,0.0),length(surface.zw),normal);
}

// Same call signature as the consumer's under_cloud(color,haze,world) helper.
vec3 under_cloud(vec3 color, vec3 haze, vec3 world) {
    vec4 surface = mcloud_sample(world);
    float depth = surface.x-world.y;
    float present = step(0.001,surface.y);
    float share = smoothstep(-8.0,8.0,depth)*present;
    return mix(color,mcloud_tone(haze,max(depth,0.0),length(surface.zw),vec3(0.0,1.0,0.0)),share);
}

vec3 mcloud_output(vec3 linear_color) {
    if (!OUTPUT_IS_SRGB) { return linear_color; }
    return mix(linear_color*12.92,1.055*pow(max(linear_color,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),linear_color));
}

// Compatibility helper retained for MonolithRidge's existing call site.
vec3 cloud_far(vec3 color, vec3 haze, float far) {
    return mix(color*mix(1.0,1.4,far),haze,0.5*far);
}
