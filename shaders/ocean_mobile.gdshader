shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
uniform vec4 deep_color : source_color = vec4(0.025, 0.20, 0.32, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.065, 0.55, 0.59, 1.0);
uniform vec4 foam_color : source_color = vec4(0.62, 0.93, 0.87, 1.0);
uniform float wave_height : hint_range(0.0, 0.5) = 0.16;
uniform float wave_speed : hint_range(0.0, 3.0) = 0.65;
varying float crest;
varying vec2 sea_uv;
void vertex() {
    vec2 p = VERTEX.xz;
    float t = TIME * wave_speed;
    float a = sin(p.x * 0.32 + t);
    float b = sin(p.y * 0.44 - t * 0.73);
    float c = sin(dot(p, vec2(0.21, 0.18)) + t * 0.53);
    crest = (a + b + c) / 3.0;
    VERTEX.y += crest * wave_height;
    sea_uv = p;
}
void fragment() {
    float t = TIME;
    float n1 = sin(sea_uv.x * 2.3 + t * 1.2) * sin(sea_uv.y * 2.9 - t * 0.9);
    float n2 = sin(dot(sea_uv, vec2(4.7, -3.8)) + t * 1.7);
    float n3 = sin(dot(sea_uv, vec2(-6.2, 5.1)) - t * 1.25);
    float v = clamp(0.48 + crest * 0.38 + n1 * 0.065 + n2 * 0.025, 0.0, 1.0);
    ALBEDO = mix(deep_color.rgb, shallow_color.rgb, v);
    float foam = smoothstep(0.69, 0.90, v) * (0.17 + 0.12 * n3);
    ALBEDO = mix(ALBEDO, foam_color.rgb, foam);
    // Layered analytic surface normals: 3D water detail without texture fetches.
    vec2 slope = vec2(cos(sea_uv.x * 2.3 + t * 1.2) * 0.10 + cos(dot(sea_uv, vec2(4.7, -3.8)) + t * 1.7) * 0.06,
                      cos(sea_uv.y * 2.9 - t * 0.9) * 0.10 + cos(dot(sea_uv, vec2(-6.2, 5.1)) - t * 1.25) * 0.05);
    NORMAL_MAP = normalize(vec3(slope.x, slope.y, 1.0));
    NORMAL_MAP_DEPTH = 0.7;
    ROUGHNESS = mix(0.31, 0.19, clamp(v, 0.0, 1.0));
    SPECULAR = 0.65;
}