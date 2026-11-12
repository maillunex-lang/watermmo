shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
uniform vec4 deep_color : source_color = vec4(0.025, 0.24, 0.38, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.08, 0.67, 0.69, 1.0);
uniform vec4 foam_color : source_color = vec4(0.72, 0.95, 0.87, 1.0);
uniform float wave_height : hint_range(0.0, 0.5) = 0.12;
uniform float wave_speed : hint_range(0.0, 3.0) = 0.65;
varying float crest;
void vertex() {
	float a = sin(VERTEX.x * 0.31 + TIME * wave_speed);
	float b = sin(VERTEX.z * 0.42 - TIME * wave_speed * 0.72);
	float c = sin((VERTEX.x + VERTEX.z) * 0.18 + TIME * wave_speed * 0.45);
	crest = (a + b + c) / 3.0;
	VERTEX.y += crest * wave_height;
}
void fragment() {
	float ripple = sin(UV.x * 115.0 + TIME * 0.7) * sin(UV.y * 97.0 - TIME * 0.6);
	float variation = clamp(0.5 + crest * 0.5 + ripple * 0.055, 0.0, 1.0);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, variation);
	ALBEDO = mix(ALBEDO, foam_color.rgb, smoothstep(0.74, 0.97, variation) * 0.14);
	ROUGHNESS = 0.48;
	SPECULAR = 0.24;
	METALLIC = 0.0;
}
