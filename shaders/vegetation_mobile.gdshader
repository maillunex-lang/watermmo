shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 leaf_dark : source_color = vec4(0.10, 0.34, 0.23, 1.0);
uniform vec4 leaf_light : source_color = vec4(0.28, 0.61, 0.35, 1.0);
void fragment() {
    float n = sin(UV.x * 17.0) * sin(UV.y * 21.0);
    ALBEDO = mix(leaf_dark.rgb, leaf_light.rgb, clamp(0.48 + n * 0.16 + UV.y * 0.17, 0.0, 1.0));
    ROUGHNESS = 0.87;
}