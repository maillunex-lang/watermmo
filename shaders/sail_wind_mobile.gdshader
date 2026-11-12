shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 cloth_color : source_color = vec4(0.91, 0.86, 0.71, 1.0);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.48;
void vertex() {
    // Sail bottom is fixed. Upper cloth ripples and billows north (-Z).
    float height_factor = clamp(1.0 - UV.y, 0.0, 1.0);
    float flutter = sin(TIME * 2.8 + UV.x * 8.0 + UV.y * 5.0);
    float secondary = sin(TIME * 4.7 - UV.x * 13.0 + UV.y * 8.0);
    VERTEX.z -= wind_strength * height_factor * (0.35 + 0.22 * flutter + 0.08 * secondary);
    VERTEX.x += wind_strength * height_factor * 0.08 * sin(TIME * 2.2 + UV.y * 7.0);
}
void fragment() {
    float weave = sin(UV.x * 125.0) * sin(UV.y * 110.0) * 0.018;
    float folds = sin(UV.x * 15.0 + TIME * 1.3 + UV.y * 4.0) * 0.045;
    ALBEDO = cloth_color.rgb * (0.92 + weave + folds);
    ROUGHNESS = 0.88;
    SPECULAR = 0.16;
}