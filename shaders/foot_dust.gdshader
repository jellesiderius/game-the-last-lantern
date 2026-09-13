shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_disabled;
instance uniform float opacity : hint_range(0.0, 1.0) = 0.55;
uniform vec4 tint : source_color = vec4(0.93, 0.85, 0.66, 1.0);
void fragment() {
	ALBEDO = tint.rgb;
	ROUGHNESS = 1.0;
	ALPHA = opacity;
}
