shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 sand : source_color = vec4(0.84, 0.71, 0.46, 1.0);
uniform vec4 highlights : source_color = vec4(0.98, 0.86, 0.62, 1.0);
void fragment() {
    float n = sin(UV.x * 19.0) * sin(UV.y * 23.0) * 0.08;
    float bands = sin(UV.y * 15.0 + sin(UV.x * 9.0) * 0.5) * 0.06;
    ALBEDO = mix(sand.rgb, highlights.rgb, clamp(0.45 + n + bands, 0.0, 1.0));
    ROUGHNESS = 0.95;
    METALLIC = 0.0;
}