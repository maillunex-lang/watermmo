shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
uniform vec4 deep_color : source_color = vec4(0.018, 0.15, 0.27, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.065, 0.43, 0.52, 1.0);
uniform vec4 foam_color : source_color = vec4(0.77, 0.94, 0.91, 1.0);
uniform float wave_height : hint_range(0.0, 0.5) = 0.19;
uniform float wave_speed : hint_range(0.0, 3.0) = 0.8;
// North is world -Z. Phase p.y + t travels toward decreasing Z.
varying float crest;
varying vec2 sea_uv;
void vertex() {
    vec2 p = VERTEX.xz;
    float t = TIME * wave_speed;
    float a = sin(p.y * 0.42 + t);
    float b = sin(dot(p, vec2(0.18, 0.96)) * 0.75 + t * 1.2);
    float c = sin(dot(p, vec2(-0.27, 0.96)) * 1.25 + t * 1.55);
    crest = (a * 0.52 + b * 0.30 + c * 0.18);
    VERTEX.y += crest * wave_height;
    sea_uv = p;
}
void fragment() {
    float t = TIME;
    // Wind-aligned fine ripples: phase advances north (-Z).
    float r1 = sin(sea_uv.y * 9.2 + sea_uv.x * 0.8 + t * 4.8);
    float r2 = sin(sea_uv.y * 15.7 - sea_uv.x * 1.9 + t * 7.3);
    float r3 = sin(sea_uv.y * 24.0 + sea_uv.x * 3.1 + t * 9.1);
    float ripple = r1 * 0.55 + r2 * 0.30 + r3 * 0.15;
    float v = clamp(0.48 + crest * 0.37 + ripple * 0.045, 0.0, 1.0);
    ALBEDO = mix(deep_color.rgb, shallow_color.rgb, v);
    float foam = smoothstep(0.69, 0.86, v) * (0.10 + max(ripple, 0.0) * 0.12);
    ALBEDO = mix(ALBEDO, foam_color.rgb, foam);
    vec2 slope = vec2(cos(sea_uv.y * 9.2 + sea_uv.x * 0.8 + t * 4.8) * 0.09 + cos(sea_uv.y * 15.7 - sea_uv.x * 1.9 + t * 7.3) * 0.05,
                      cos(sea_uv.y * 9.2 + sea_uv.x * 0.8 + t * 4.8) * 0.13 + cos(sea_uv.y * 24.0 + sea_uv.x * 3.1 + t * 9.1) * 0.045);
    NORMAL_MAP = normalize(vec3(slope.x, slope.y, 1.0));
    NORMAL_MAP_DEPTH = 0.55;
    ROUGHNESS = mix(0.34, 0.20, v);
    SPECULAR = 0.65;
}