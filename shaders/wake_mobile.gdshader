shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 foam_color : source_color = vec4(0.73, 0.97, 0.94, 1.0);
uniform float age : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
void fragment() {
    // UV.y: 0 is the far end, 1 is the stern. Two feathered arms form a V.
    float back = 1.0 - UV.y;
    float spread = 0.12 + back * 0.64;
    float arms = abs(UV.x - 0.5);
    float left_right = 1.0 - smoothstep(0.015, 0.085 + back * 0.045, abs(arms - spread * 0.43));
    float center = (1.0 - smoothstep(0.02, 0.16 + back * 0.13, arms)) * (1.0 - back * 0.65);
    float chop = sin(UV.y * 66.0 + TIME * 5.0 + sin(UV.x * 29.0) * 2.0);
    float breakup = 0.60 + 0.24 * chop + 0.16 * sin(UV.x * 83.0 - UV.y * 91.0 + TIME * 2.0);
    float tail = smoothstep(1.0, 0.50, back);
    float front = smoothstep(0.0, 0.12, back);
    float alpha = max(left_right * 0.66, center * 0.43) * breakup * tail * front;
    alpha *= (1.0 - smoothstep(0.42, 1.0, age)) * strength;
    ALBEDO = mix(vec3(0.31, 0.77, 0.77), foam_color.rgb, clamp(left_right * 0.8 + chop * 0.13, 0.0, 1.0));
    ALPHA = clamp(alpha, 0.0, 0.78);
}