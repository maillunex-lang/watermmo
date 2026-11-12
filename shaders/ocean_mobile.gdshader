shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// North is the world-space -Z direction. Both waves and tiny ripples move north.
uniform vec4 deep_color : source_color = vec4(0.014, 0.14, 0.25, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.054, 0.40, 0.51, 1.0);
uniform vec4 foam_color : source_color = vec4(0.77, 0.94, 0.91, 1.0);
uniform vec4 sky_reflection : source_color = vec4(0.43, 0.69, 0.80, 1.0);
uniform sampler2D ripple_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float wave_height : hint_range(0.0, 0.8) = 0.39;
uniform float wave_speed : hint_range(0.0, 3.0) = 1.08;
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.72;
uniform vec3 sun_direction = vec3(0.14, 0.58, 0.80);

varying float crest;
varying vec2 sea_uv;

void vertex() {
    vec2 p = VERTEX.xz;
    float t = TIME * wave_speed;
    float long_swell = sin(p.y * 0.42 + t);
    float cross_swell = sin(dot(p, vec2(0.18, 0.96)) * 0.75 + t * 1.2);
    float short_swell = sin(dot(p, vec2(-0.27, 0.96)) * 1.25 + t * 1.55);
    crest = long_swell * 0.52 + cross_swell * 0.30 + short_swell * 0.18;
    VERTEX.y += wave_height * crest;
    sea_uv = p;
}

void fragment() {
    // Two scrolling samples of a small generated normal map give fine wind ripples.
    // Increasing texture V moves the apparent ripple pattern toward -Z (north).
    vec2 uv_large = sea_uv * 0.085 + vec2(0.011, TIME * 0.055);
    vec2 uv_small = sea_uv * 0.31 + vec2(-0.026, TIME * 0.145);
    vec3 normal_large = texture(ripple_normal, uv_large).xyz * 2.0 - 1.0;
    vec3 normal_small = texture(ripple_normal, uv_small).xyz * 2.0 - 1.0;
    vec2 detail = (normal_large.xy * 0.66 + normal_small.xy * 0.34) * ripple_strength;
    NORMAL_MAP = normalize(vec3(detail.x, detail.y, 1.0));
    NORMAL_MAP_DEPTH = 0.65;

    float variation = normal_large.x * 0.08 + normal_small.y * 0.035;
    float depth_mix = clamp(0.47 + crest * 0.36 + variation, 0.0, 1.0);
    vec3 water_color = mix(deep_color.rgb, shallow_color.rgb, depth_mix);

    // Mobile-friendly approximation of sky reflection: no screen-space effects.
    float horizon = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.5);
    water_color = mix(water_color, sky_reflection.rgb, horizon * 0.42);
    float whitecaps = smoothstep(0.67, 0.83, depth_mix) *
                     (0.08 + 0.13 * clamp(normal_small.x * 0.5 + 0.5, 0.0, 1.0));
    ALBEDO = mix(water_color, foam_color.rgb, whitecaps);
    ROUGHNESS = mix(0.35, 0.21, depth_mix);
    SPECULAR = 0.68;
    // Warm, wind-broken highlights from the south without expensive reflections.
    vec3 sun_view = normalize((VIEW_MATRIX * vec4(normalize(sun_direction), 0.0)).xyz);
    vec3 mirror_view = reflect(-sun_view, normalize(NORMAL));
    float glint = pow(max(dot(mirror_view, normalize(VIEW)), 0.0), 62.0);
    glint *= 0.28 + 0.72 * clamp(normal_large.z * 0.5 + normal_small.z * 0.5, 0.0, 1.0);
    EMISSION = vec3(1.0, 0.73, 0.39) * glint * 0.48;
}