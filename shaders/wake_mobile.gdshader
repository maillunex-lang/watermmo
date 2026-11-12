shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 foam : source_color = vec4(0.68, 0.98, 0.93, 0.5);
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float ripple = sin(p.y * 29.0 + TIME * 5.0 + sin(p.x * 8.0) * 1.4);
    float falloff = smoothstep(1.0, 0.15, abs(p.x)) * smoothstep(1.0, 0.10, abs(p.y));
    float streak = smoothstep(0.5, 0.95, ripple) * falloff;
    ALBEDO = foam.rgb;
    ALPHA = streak * foam.a;
}