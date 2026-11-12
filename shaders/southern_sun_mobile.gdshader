shader_type sky;

// The sun is positioned south (+Z), slightly to the east (+X), above the horizon.
// Small radial highlights emulate sun shafts at low mobile rendering cost.
uniform vec3 sun_direction = vec3(0.14, 0.58, 0.80);
uniform vec4 zenith_color : source_color = vec4(0.21, 0.47, 0.71, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.77, 0.84, 0.82, 1.0);
uniform float ray_intensity : hint_range(0.0, 1.5) = 0.75;

void sky() {
    vec3 ray_dir = normalize(EYEDIR);
    float altitude = smoothstep(-0.2, 0.84, ray_dir.y);
    vec3 atmosphere = mix(horizon_color.rgb, zenith_color.rgb, altitude);
    float alignment = max(dot(ray_dir, normalize(sun_direction)), 0.0);
    float glow = pow(alignment, 18.0);
    float radial_angle = atan(ray_dir.y - sun_direction.y, ray_dir.x - sun_direction.x);
    float radial_band = pow(0.5 + 0.5 * cos(radial_angle * 13.0), 3.0);
    float shafts = pow(alignment, 31.0) * (0.38 + 0.62 * radial_band);
    float sun_disc = smoothstep(0.9990, 0.9997, alignment);
    COLOR = atmosphere +
        vec3(1.0, 0.68, 0.33) * glow * 0.28 +
        vec3(1.0, 0.82, 0.52) * shafts * ray_intensity +
        vec3(1.0, 0.92, 0.71) * sun_disc;
}