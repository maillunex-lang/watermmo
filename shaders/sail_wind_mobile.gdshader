shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Can be applied directly to the original ship-medium.glb sails and flags.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_atlas = false;
uniform bool use_uv_height = false;
uniform vec4 cloth_color : source_color = vec4(0.91, 0.86, 0.71, 1.0);
uniform float sail_height : hint_range(0.5, 6.0) = 4.0;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.48;

void vertex() {
    // Original sails have vertical local Y; the fallback PlaneMesh uses UV.y.
    float relative_height = use_uv_height ? (1.0 - UV.y) : (VERTEX.y / sail_height);
    float flex = smoothstep(0.06, 0.95, clamp(relative_height, 0.0, 1.0));
    float flutter = sin(TIME * 2.7 + VERTEX.x * 3.5 + relative_height * 3.0);
    float detail = sin(TIME * 5.0 - VERTEX.x * 7.0 + relative_height * 9.0);
    // Convert fixed world north (-Z) to this rotating ship mesh's local space.
    vec3 local_north = normalize(inverse(mat3(MODEL_MATRIX)) * vec3(0.0, 0.0, -1.0));
    float billow = wind_strength * flex * (0.23 + 0.15 * flutter + 0.055 * detail);
    VERTEX += local_north * billow;
}

void fragment() {
    vec3 base = cloth_color.rgb;
    if (use_atlas) {
        base = texture(albedo_texture, UV).rgb;
    }
    float weave = sin(UV.x * 125.0) * sin(UV.y * 110.0) * 0.012;
    float folds = sin(UV.x * 13.0 + TIME * 1.3 + UV.y * 4.0) * 0.03;
    ALBEDO = base * (0.97 + weave + folds);
    ROUGHNESS = 0.87;
    SPECULAR = 0.16;
}