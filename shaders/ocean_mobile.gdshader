shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
uniform vec4 deep_color : source_color = vec4(0.025, 0.20, 0.32, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.065, 0.55, 0.59, 1.0);
uniform vec4 foam_color : source_color = vec4(0.62, 0.93, 0.87, 1.0);
uniform float wave_height : hint_range(0.0, 0.5) = 0.15;
uniform float wave_speed : hint_range(0.0, 3.0) = 0.65;
varying float crest;
varying vec2 world_uv;
void vertex() {
    float a = sin(VERTEX.x * 0.32 + TIME * wave_speed);
    float b = sin(VERTEX.z * 0.44 - TIME * wave_speed * 0.73);
    float c = sin((VERTEX.x + VERTEX.z) * 0.21 + TIME * wave_speed * 0.53);
    crest = (a + b + c) / 3.0;
    VERTEX.y += crest * wave_height;
    world_uv = VERTEX.xz;
}
void fragment() {
    float micro = sin(world_uv.x * 2.3 + TIME * 1.2) * sin(world_uv.y * 2.9 - TIME * 0.9);
    float cross = sin(world_uv.x * 0.9 + world_uv.y * 1.2 + TIME * 0.45);
    float v = clamp(0.48 + crest * 0.38 + micro * 0.08 + cross * 0.045, 0.0, 1.0);
    ALBEDO = mix(deep_color.rgb, shallow_color.rgb, v);
    float glint = pow(max(0.0, micro * cross), 9.0) * 0.09;
    ALBEDO += vec3(0.22, 0.37, 0.34) * glint;
    ALBEDO = mix(ALBEDO, foam_color.rgb, smoothstep(0.76, 0.94, v) * 0.24);
    ROUGHNESS = 0.55;
    SPECULAR = 0.21;
    METALLIC = 0.0;
}